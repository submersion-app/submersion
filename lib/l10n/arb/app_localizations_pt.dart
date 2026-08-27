// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get universalImport_action_importFromGarmin =>
      'Importar do dispositivo Garmin';

  @override
  String diveLog_edit_flightWindowWarning(String time) {
    return 'Este mergulho termina depois do último horário seguro para emergir antes do seu voo ($time)';
  }

  @override
  String diveLog_edit_geofenceSuggestion_near(String location) {
    return 'Perto de $location';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_title => 'Sugestão de equipamento';

  @override
  String diveLog_edit_geofenceSuggestion_body(String setName) {
    return 'Aplicar o conjunto \"$setName\"?';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_apply => 'Aplicar';

  @override
  String get common_action_dismiss => 'Dispensar';

  @override
  String get equipment_setEdit_defaultSwitch_title => 'Conjunto padrão';

  @override
  String get equipment_setEdit_defaultSwitch_subtitle =>
      'Aplicado automaticamente a novos mergulhos que ainda não têm equipamento';

  @override
  String get equipment_setEdit_geofencesTitle => 'Geocercas';

  @override
  String get equipment_setEdit_geofencesSubtitle =>
      'Sugerir automaticamente este conjunto para mergulhos perto destes locais';

  @override
  String get equipment_setEdit_addGeofence => 'Adicionar geocerca';

  @override
  String get equipment_setEdit_editGeofence => 'Edit geofence';

  @override
  String get equipment_setEdit_removeGeofence => 'Remove geofence';

  @override
  String equipment_setEdit_geofenceRadius(String distance) {
    return 'Raio: $distance';
  }

  @override
  String get equipment_geofenceEditor_title => 'Geocerca';

  @override
  String get equipment_geofenceEditor_fromSite => 'Do local de mergulho';

  @override
  String get equipment_geofenceEditor_dropPin => 'Colocar um alfinete';

  @override
  String get equipment_geofenceEditor_labelLabel => 'Rótulo';

  @override
  String get equipment_geofenceEditor_noCenter => 'Escolha um ponto central';

  @override
  String get equipment_geofenceEditor_save => 'Salvar geocerca';

  @override
  String get equipment_sets_defaultBadge => 'Padrão';

  @override
  String get equipment_setDetail_setAsDefault => 'Definir como padrão';

  @override
  String equipment_setDetail_setAsDefaultSnackbar(String name) {
    return '\"$name\" agora é o seu conjunto padrão';
  }

  @override
  String get equipment_setDetail_geofencesTitle => 'Geocercas';

  @override
  String get equipment_setDetail_noGeofences => 'Sem geocercas';

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
    return 'Acima do limite maximo de densidade de $limit g/L.';
  }

  @override
  String get gasCalculators_bestMix_densityLabel =>
      'Densidade do gas na profundidade';

  @override
  String gasCalculators_bestMix_densityWarn(Object limit) {
    return 'Acima do limite de densidade recomendado de $limit g/L.';
  }

  @override
  String gasCalculators_bestMix_endExceeded(Object limit) {
    return 'A END excede o teu limite de $limit.';
  }

  @override
  String get gasCalculators_bestMix_endLabel => 'END na profundidade';

  @override
  String get gasCalculators_bestMix_endLimitLabel => 'Limite END';

  @override
  String gasCalculators_bestMix_heliumAdded(Object limit) {
    return 'Helio adicionado para manter a END dentro do teu limite de $limit.';
  }

  @override
  String get gasCalculators_bestMix_idealLabel => 'Fracao ideal';

  @override
  String get gasCalculators_bestMix_marginLabel => 'Margem abaixo da MOD';

  @override
  String gasCalculators_bestMix_modLabel(Object ppO2) {
    return 'MOD a ppO2 $ppO2';
  }

  @override
  String get gasCalculators_bestMix_nearestStandard =>
      'Mistura padrao mais proxima que cobre esta profundidade';

  @override
  String get gasCalculators_bestMix_recommendedMix => 'Mistura recomendada';

  @override
  String get gasCalculators_bestMix_withoutHelium => 'Sem helio';

  @override
  String get gasCalculators_planningCaveat =>
      'Estimativa de planeamento. Assume uma subida direta. Verifica de acordo com a tua formacao e acrescenta margem para as condicoes.';

  @override
  String gasCalculators_rockBottom_solveGas(Object depth, Object unit) {
    return 'Gas para resolver o problema a $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_solveTime =>
      'Tempo de resolucao do problema';

  @override
  String get gasCalculators_rockBottom_solveTimeHint =>
      'Tempo passado na profundidade a resolver a emergencia antes de iniciar a subida.';

  @override
  String o2Toxicity_addedThisDive(Object value) {
    return '+$value este mergulho';
  }

  @override
  String o2Toxicity_cnsProgressSemantics(Object percent) {
    return 'Progresso SNC $percent por cento';
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
    return '$label: $value de $limit OTU, $percent por cento';
  }

  @override
  String o2Toxicity_otuValueSemantics(Object label, Object value) {
    return '$label: $value OTU';
  }

  @override
  String o2Toxicity_prior(Object value) {
    return 'Anterior: $value OTU';
  }

  @override
  String o2Toxicity_start(Object value) {
    return 'Inicio: $value OTU';
  }

  @override
  String get o2Toxicity_thisDive => 'Este mergulho';

  @override
  String get o2Toxicity_weekly => 'Semanal';

  @override
  String trips_story_dayLabel(int number) {
    return 'Dia $number';
  }

  @override
  String get trips_story_surfaceDay => 'Dia de superfície';

  @override
  String get trips_story_today => 'Hoje';

  @override
  String trips_story_dayOfTrip(int current, int total) {
    return 'Dia $current de $total';
  }

  @override
  String trips_story_daysUntil(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias até a partida',
      one: '1 dia até a partida',
    );
    return '$_temp0';
  }

  @override
  String trips_story_checklistProgress(int done, int total) {
    return '$done de $total concluído';
  }

  @override
  String get trips_story_generateItinerary => 'Gerar itinerário';

  @override
  String get trips_story_openGallery => 'Abrir fotos da viagem';

  @override
  String trips_story_generateItineraryError(String error) {
    return 'Não foi possível gerar o itinerário: $error';
  }

  @override
  String get trips_dayType_diveDay => 'Dia de mergulho';

  @override
  String get trips_dayType_seaDay => 'Dia no mar';

  @override
  String get trips_dayType_portDay => 'Dia no porto';

  @override
  String get trips_dayType_embark => 'Embarque';

  @override
  String get trips_dayType_disembark => 'Desembarque';

  @override
  String get trips_story_planned => 'Planejado';

  @override
  String get trips_story_empty_title => 'Ainda sem mergulhos ou itinerário';

  @override
  String get trips_story_empty_subtitle =>
      'Adicione mergulhos ou planeje os dias para ver a história.';

  @override
  String trips_story_history_dives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos anteriores aqui',
      one: '1 mergulho anterior aqui',
    );
    return '$_temp0';
  }

  @override
  String trips_story_history_avgTemp(String value) {
    return 'média $value';
  }

  @override
  String trips_story_history_avgDepth(String value) {
    return 'prof. média $value';
  }

  @override
  String get trips_story_rhythm_semantics => 'Horários de mergulho deste dia';

  @override
  String get trips_story_map_semantics =>
      'Mapa da viagem. Os pontos do dia visível estão destacados.';

  @override
  String get diveLog_bulkEdit_groupRebreather =>
      'Modo de mergulho e rebreather';

  @override
  String get diveLog_bulkEdit_fieldSetpointLow => 'Setpoint baixo';

  @override
  String get diveLog_bulkEdit_fieldSetpointHigh => 'Setpoint alto';

  @override
  String get diveLog_bulkEdit_fieldSetpointDeco => 'Setpoint deco';

  @override
  String get diveLog_bulkEdit_fieldScrubberType => 'Tipo de cal sodada';

  @override
  String get diveLog_bulkEdit_fieldScrubberDuration => 'Duração da cal';

  @override
  String get diveLog_bulkEdit_contradiction =>
      'O modo OC não suporta ajustes de rebreather. Desative esses campos ou mude o modo.';

  @override
  String diveLog_bulkEdit_appBarTitle(int count) {
    return 'Editar $count mergulhos';
  }

  @override
  String get diveLog_bulkEdit_groupLogistics => 'Logística';

  @override
  String get diveLog_bulkEdit_groupWeather => 'Clima';

  @override
  String get diveLog_bulkEdit_groupCollections => 'Tags, equipamento e vida';

  @override
  String get diveLog_bulkEdit_fieldFavorite => 'Favorito';

  @override
  String get diveLog_bulkEdit_fieldMyRole => 'Minha função';

  @override
  String get diveLog_bulkEdit_buddyRoleMixed => 'Variado';

  @override
  String get diveLog_bulkEdit_collectionWeights => 'Lastros';

  @override
  String get diveLog_bulkEdit_collectionTanks => 'Cilindros';

  @override
  String get diveLog_bulkEdit_notesSet => 'Definir';

  @override
  String get diveLog_bulkEdit_notesAppend => 'Acrescentar';

  @override
  String get diveLog_bulkEdit_modeAdd => 'Adicionar';

  @override
  String get diveLog_bulkEdit_modeRemove => 'Remover';

  @override
  String get diveLog_bulkEdit_modeReplace => 'Substituir';

  @override
  String get diveLog_bulkEdit_modeUpdate => 'Atualizar';

  @override
  String get diveLog_bulkEdit_tankOnlyIfEmpty =>
      'Apenas mergulhos sem cilindro existente';

  @override
  String get diveLog_bulkEdit_tankSpecsHint =>
      'Escolhe quais atributos sobrescrever nos cilindros que estes mergulhos já têm. As pressões inicial e final nunca são alteradas.';

  @override
  String get diveLog_bulkEdit_tankSpecsNoFields =>
      'Escolhe pelo menos um atributo de cilindro para atualizar.';

  @override
  String get diveLog_bulkEdit_tankFieldPreset => 'Predefinição';

  @override
  String get diveLog_bulkEdit_tankFieldRole => 'Função';

  @override
  String get diveLog_bulkEdit_tankFieldVolume => 'Volume';

  @override
  String get diveLog_bulkEdit_tankFieldWorkingPressure => 'Pressão de trabalho';

  @override
  String get diveLog_bulkEdit_tankFieldMaterial => 'Material';

  @override
  String get diveLog_bulkEdit_tankFieldGasMix => 'Mistura de gás';

  @override
  String get diveLog_bulkEdit_tankFieldName => 'Nome';

  @override
  String diveLog_bulkEdit_tankSpecsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count mergulhos selecionados não têm cilindros e serão ignorados.',
      one: '1 mergulho selecionado não tem cilindros e será ignorado.',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_bulkEdit_confirmTitle => 'Aplicar alterações?';

  @override
  String get diveLog_bulkEdit_confirmApply => 'Aplicar';

  @override
  String get diveLog_bulkEdit_nothingSelected =>
      'Ative pelo menos um campo para aplicar alterações.';

  @override
  String diveLog_bulkEdit_applied(int count) {
    return '$count mergulhos atualizados';
  }

  @override
  String get settings_cloudSync_error_icloudSignedOut =>
      'O iCloud não está disponível. Inicie sessão no iCloud nas definições do seu dispositivo.';

  @override
  String get settings_cloudSync_error_icloudUnknown =>
      'Não foi possível aceder ao iCloud. Tente novamente.';

  @override
  String get settings_cloudSync_error_icloudUnsupported =>
      'A sincronização do iCloud não está disponível nesta versão do Submersion. Use a sincronização S3 ou a versão da App Store.';

  @override
  String get settings_cloudSync_provider_icloud_unsupportedSubtitle =>
      'Indisponível nesta versão — use o S3 ou a versão da App Store';

  @override
  String get settings_cloudSync_encryption_title =>
      'Criptografia de ponta a ponta';

  @override
  String get settings_cloudSync_encryption_subtitleOff =>
      'Criptografar todos os dados de sincronização e backups na nuvem antes do envio';

  @override
  String get settings_cloudSync_encryption_subtitleNeedsProvider =>
      'Selecione primeiro um provedor de nuvem';

  @override
  String get settings_cloudSync_encryption_statusOff =>
      'A criptografia está desativada';

  @override
  String get settings_cloudSync_encryption_statusOn =>
      'A criptografia está ativada';

  @override
  String get settings_cloudSync_encryption_statusOnSubtitle =>
      'Dados de sincronização e backups na nuvem são criptografados antes do envio';

  @override
  String get settings_cloudSync_encryption_statusLocked =>
      'Criptografado — senha necessária';

  @override
  String get settings_cloudSync_encryption_statusLockedSubtitle =>
      'Digite a frase-senha para sincronizar neste dispositivo';

  @override
  String get settings_cloudSync_encryption_enable => 'Ativar criptografia';

  @override
  String get settings_cloudSync_encryption_enterPassphrase =>
      'Digitar frase-senha';

  @override
  String get settings_cloudSync_encryption_passphrase => 'Frase-senha';

  @override
  String get settings_cloudSync_encryption_passphraseConfirm =>
      'Confirmar frase-senha';

  @override
  String get settings_cloudSync_encryption_passphraseMismatch =>
      'As frases-senha não coincidem';

  @override
  String get settings_cloudSync_encryption_passphraseTooShort =>
      'Use pelo menos 8 caracteres';

  @override
  String get settings_cloudSync_encryption_wrongPassphrase =>
      'Frase-senha ou código de recuperação incorretos';

  @override
  String get settings_cloudSync_encryption_warnUpdateDevices =>
      'Todos os outros dispositivos precisam ser atualizados para a versão mais recente do app e baixarão a biblioteca novamente.';

  @override
  String get settings_cloudSync_encryption_warnLoss =>
      'Se você perder a frase-senha e o código de recuperação, os dados na nuvem não poderão ser recuperados. Os dados nos seus dispositivos nunca correm risco.';

  @override
  String get settings_cloudSync_encryption_deletePlaintextBackups =>
      'Excluir backups na nuvem não criptografados existentes';

  @override
  String get settings_cloudSync_encryption_recoveryTitle =>
      'Código de recuperação';

  @override
  String get settings_cloudSync_encryption_recoveryExplain =>
      'Anote este código e guarde-o em local seguro. É a única forma de voltar a acessar se você esquecer a frase-senha.';

  @override
  String get settings_cloudSync_encryption_recoverySavedConfirm =>
      'Salvei meu código de recuperação';

  @override
  String get settings_cloudSync_encryption_changePassphrase =>
      'Alterar frase-senha';

  @override
  String get settings_cloudSync_encryption_currentPassphrase =>
      'Frase-senha atual';

  @override
  String get settings_cloudSync_encryption_newPassphrase => 'Nova frase-senha';

  @override
  String get settings_cloudSync_encryption_regenerateRecovery =>
      'Gerar novo código de recuperação';

  @override
  String get settings_cloudSync_encryption_regenerateRecoveryWarn =>
      'O código de recuperação antigo deixa de funcionar imediatamente.';

  @override
  String get settings_cloudSync_encryption_disable => 'Desativar criptografia';

  @override
  String get settings_cloudSync_encryption_disableWarn =>
      'A biblioteca será reenviada sem criptografia e os outros dispositivos a baixarão novamente. Os backups criptografados existentes continuam restauráveis com a frase-senha.';

  @override
  String get settings_cloudSync_encryption_unlockTitle =>
      'Digite sua frase-senha de criptografia';

  @override
  String get settings_cloudSync_encryption_unlockHint =>
      'Frase-senha ou código de recuperação';

  @override
  String get settings_cloudSync_encryption_unlock => 'Desbloquear';

  @override
  String get settings_cloudSync_encryption_continue => 'Continuar';

  @override
  String get settings_cloudSync_encryption_done => 'Concluído';

  @override
  String get settings_cloudSync_encryption_cancel => 'Cancelar';

  @override
  String get settings_backupEncryption_title => 'Criptografia de backup';

  @override
  String get settings_backupEncryption_subtitleOff =>
      'Proteja seus backups com uma senha';

  @override
  String get settings_backupEncryption_subtitleOn =>
      'Os backups são criptografados com sua senha';

  @override
  String get settings_backupEncryption_enable => 'Criptografar backups';

  @override
  String get settings_backupEncryption_turnOff => 'Desativar criptografia';

  @override
  String get settings_backupEncryption_turnOffTitle =>
      'Desativar criptografia de backup?';

  @override
  String get settings_backupEncryption_turnOffBody =>
      'Os novos backups deixarão de ser criptografados. Os backups criptografados existentes ainda precisam da sua senha para serem restaurados.';

  @override
  String get settings_backupEncryption_changePassword => 'Alterar senha';

  @override
  String get settings_backupEncryption_regenerateRecovery =>
      'Gerar novo código de recuperação';

  @override
  String get settings_backupEncryption_password => 'Senha';

  @override
  String get settings_backupEncryption_passwordConfirm => 'Confirmar senha';

  @override
  String get settings_backupEncryption_passwordTooShort =>
      'Use pelo menos 8 caracteres';

  @override
  String get settings_backupEncryption_passwordMismatch =>
      'As senhas não coincidem';

  @override
  String get settings_backupEncryption_currentPassword => 'Senha atual';

  @override
  String get settings_backupEncryption_newPassword => 'Nova senha';

  @override
  String get settings_backupEncryption_changePasswordWarn =>
      'Em outro dispositivo, cada backup é aberto com a senha ou o código de recuperação que estava ativo quando foi criado.';

  @override
  String get settings_backupEncryption_warnLoss =>
      'Se você esquecer a senha e perder o código de recuperação, os backups criptografados não poderão ser recuperados.';

  @override
  String get settings_backupEncryption_recoveryTitle =>
      'Seu código de recuperação';

  @override
  String get settings_backupEncryption_recoveryExplain =>
      'Guarde este código em local seguro. Ele pode desbloquear seus backups se você esquecer a senha.';

  @override
  String get settings_backupEncryption_recoverySavedConfirm =>
      'Salvei meu código de recuperação';

  @override
  String get settings_backupEncryption_unlockTitle =>
      'Digite a senha do backup';

  @override
  String get settings_backupEncryption_unlockHint =>
      'Digite a senha do backup ou o código de recuperação';

  @override
  String get settings_backupEncryption_restoreUnlockTitle =>
      'Desbloquear backup criptografado';

  @override
  String get settings_backupEncryption_restoreUnlockHint =>
      'Insira a senha ou o código de recuperação deste backup';

  @override
  String get settings_backupEncryption_continue => 'Continuar';

  @override
  String get settings_backupEncryption_cancel => 'Cancelar';

  @override
  String get settings_backupEncryption_done => 'Concluído';

  @override
  String get settings_backupEncryption_reencryptTitle =>
      'Criptografar backups existentes?';

  @override
  String get settings_backupEncryption_reencryptBody =>
      'Seus backups existentes ainda não estão criptografados. Recriptografá-los agora com sua nova senha?';

  @override
  String get settings_backupEncryption_reencryptNow => 'Recriptografar agora';

  @override
  String get settings_backupEncryption_reencryptNotNow => 'Agora não';

  @override
  String settings_backupEncryption_reencryptPartial(int done, int failed) {
    return '$done backups recriptografados; $failed não puderam ser criptografados e continuam desprotegidos';
  }

  @override
  String settings_backupEncryption_reencryptDone(int count) {
    return '$count backups recriptografados';
  }

  @override
  String get settings_backupEncryption_wrongPassword =>
      'Senha ou código de recuperação incorretos';

  @override
  String settings_cloudSync_replace_globalBanner(String deviceName) {
    return 'Sincronização em pausa — a biblioteca foi substituída a partir de uma cópia de segurança em \"$deviceName\".';
  }

  @override
  String get settings_cloudSync_postRestore_syncing =>
      'A sincronizar a sua biblioteca restaurada com a nuvem…';

  @override
  String get settings_cloudSync_postRestore_synced =>
      'Biblioteca restaurada sincronizada.';

  @override
  String get settings_cloudSync_replace_reviewAction => 'Rever';

  @override
  String get accessibility_dialog_keyboardShortcutsTitle =>
      'Atalhos de Teclado';

  @override
  String get accessibility_keyLabel_backspace => 'Backspace';

  @override
  String get accessibility_keyLabel_delete => 'Delete';

  @override
  String get accessibility_keyLabel_down => 'Baixo';

  @override
  String get accessibility_keyLabel_enter => 'Enter';

  @override
  String get accessibility_keyLabel_esc => 'Esc';

  @override
  String get accessibility_keyLabel_left => 'Esquerda';

  @override
  String get accessibility_keyLabel_right => 'Direita';

  @override
  String get accessibility_keyLabel_up => 'Cima';

  @override
  String accessibility_label_chartSummary(
    Object chartType,
    Object description,
  ) {
    return 'Grafico tipo $chartType. $description';
  }

  @override
  String get accessibility_label_createNewItem => 'Criar novo item';

  @override
  String get accessibility_label_hideList => 'Ocultar lista';

  @override
  String get accessibility_label_hideMapView => 'Ocultar Visualizacao do Mapa';

  @override
  String accessibility_label_listPane(Object title) {
    return 'Painel de lista $title';
  }

  @override
  String accessibility_label_mapPane(Object title) {
    return 'Painel do mapa $title';
  }

  @override
  String accessibility_label_mapViewTitle(Object title) {
    return 'Visualizacao do mapa $title';
  }

  @override
  String get accessibility_label_resizeMasterPane =>
      'Redimensionar painel principal';

  @override
  String get accessibility_label_sharedWithAllProfiles =>
      'Partilhado com todos os perfis de mergulho';

  @override
  String get accessibility_label_showList => 'Mostrar Lista';

  @override
  String get accessibility_label_showMapView => 'Mostrar Visualizacao do Mapa';

  @override
  String get accessibility_label_viewDetails => 'Ver detalhes';

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
  String get accessibility_shortcutCategory_editing => 'Edicao';

  @override
  String get accessibility_shortcutCategory_general => 'Geral';

  @override
  String get accessibility_shortcutCategory_help => 'Ajuda';

  @override
  String get accessibility_shortcutCategory_navigation => 'Navegacao';

  @override
  String get accessibility_shortcutCategory_search => 'Busca';

  @override
  String get accessibility_shortcut_closeCancel => 'Fechar / Cancelar';

  @override
  String get accessibility_shortcut_goBack => 'Voltar';

  @override
  String get accessibility_shortcut_goToDives => 'Ir para Mergulhos';

  @override
  String get accessibility_shortcut_goToEquipment => 'Ir para Equipamentos';

  @override
  String get accessibility_shortcut_goToSettings => 'Ir para Configuracoes';

  @override
  String get accessibility_shortcut_goToSites => 'Ir para Pontos de Mergulho';

  @override
  String get accessibility_shortcut_goToStatistics => 'Ir para Estatisticas';

  @override
  String get accessibility_shortcut_keyboardShortcuts => 'Atalhos de teclado';

  @override
  String get accessibility_shortcut_newDive => 'Novo mergulho';

  @override
  String get accessibility_shortcut_openSettings => 'Abrir configuracoes';

  @override
  String get accessibility_shortcut_searchDives => 'Buscar mergulhos';

  @override
  String accessibility_sort_selectedLabel(Object displayName) {
    return 'Ordenar por $displayName, selecionado atualmente';
  }

  @override
  String accessibility_sort_unselectedLabel(Object displayName) {
    return 'Ordenar por $displayName';
  }

  @override
  String get backup_appBar_title => 'Backup e Restauração';

  @override
  String get backup_backingUp => 'Fazendo backup...';

  @override
  String get backup_backupNow => 'Fazer Backup Agora';

  @override
  String get backup_cloud_enabled => 'Backup na nuvem';

  @override
  String get backup_cloud_enabled_subtitle =>
      'Enviar backups para o armazenamento na nuvem';

  @override
  String get backup_delete_dialog_cancel => 'Cancelar';

  @override
  String get backup_delete_dialog_content =>
      'Este backup será excluído permanentemente. Esta ação não pode ser desfeita.';

  @override
  String get backup_delete_dialog_delete => 'Excluir';

  @override
  String get backup_delete_dialog_title => 'Excluir Backup';

  @override
  String get backup_export_bottomSheet_title => 'Exportar Backup';

  @override
  String get backup_export_saveToFile => 'Salvar em Arquivo';

  @override
  String get backup_export_saveToFile_subtitle =>
      'Escolha onde salvar o arquivo de backup';

  @override
  String get backup_export_share => 'Compartilhar';

  @override
  String get backup_export_share_subtitle =>
      'Enviar por AirDrop, e-mail ou outros apps';

  @override
  String get backup_export_subtitle =>
      'Salve seus dados de mergulho em um arquivo';

  @override
  String get backup_export_success => 'Backup exportado com sucesso';

  @override
  String get backup_export_title => 'Exportar Backup';

  @override
  String get backup_frequency_daily => 'Diário';

  @override
  String get backup_frequency_monthly => 'Mensal';

  @override
  String get backup_frequency_weekly => 'Semanal';

  @override
  String get backup_history_action_delete => 'Excluir';

  @override
  String get backup_history_action_restore => 'Restaurar';

  @override
  String get backup_history_empty => 'Nenhum backup';

  @override
  String backup_history_error(Object error) {
    return 'Erro ao carregar histórico: $error';
  }

  @override
  String get backup_history_pinAction_pin => 'Fixar backup';

  @override
  String get backup_history_pinAction_unpin => 'Desafixar backup';

  @override
  String get backup_history_pinError =>
      'Nao foi possivel atualizar o estado de fixacao.';

  @override
  String backup_history_preMigrationSubtitle(String size) {
    return 'Backup pre-migracao - $size';
  }

  @override
  String get backup_import_invalidFile =>
      'Este arquivo nao parece ser um backup valido do Submersion';

  @override
  String get backup_import_subtitle => 'Importar um backup de qualquer local';

  @override
  String get backup_import_title => 'Restaurar de Arquivo';

  @override
  String get backup_import_validating => 'Validando arquivo de backup...';

  @override
  String get backup_location_change => 'Alterar';

  @override
  String get backup_location_default => 'Local padrao';

  @override
  String get backup_location_title => 'Local do Backup';

  @override
  String get backup_replaceConfirm_confirm => 'Substituir em todo lugar';

  @override
  String get backup_replaceConfirm_content =>
      'A biblioteca em todos os dispositivos sincronizados será substituída por este backup. Cada dispositivo cria primeiro um backup de segurança dos seus dados atuais. Isso não pode ser desfeito.';

  @override
  String get backup_replaceConfirm_title =>
      'Substituir a biblioteca em todo lugar?';

  @override
  String get backup_restore_dialog_cancel => 'Cancelar';

  @override
  String get backup_restore_dialog_modeMerge_subtitle =>
      'Restaurar neste dispositivo. A próxima sincronização combinará os dados restaurados com a biblioteca na nuvem.';

  @override
  String get backup_restore_dialog_modeMerge_title =>
      'Mesclar na próxima sincronização';

  @override
  String get backup_restore_dialog_modeReplace_subtitle =>
      'O backup se torna a biblioteca neste dispositivo, na nuvem e em todos os dispositivos sincronizados.';

  @override
  String get backup_restore_dialog_modeReplace_title =>
      'Substituir em todo lugar';

  @override
  String get backup_restore_dialog_restore => 'Restaurar';

  @override
  String get backup_restore_dialog_restoreReplace =>
      'Restaurar e substituir em todo lugar';

  @override
  String get backup_restore_dialog_safetyNote =>
      'Um backup de segurança dos seus dados atuais será criado automaticamente antes da restauração.';

  @override
  String get backup_restore_dialog_title => 'Restaurar Backup';

  @override
  String get backup_restore_dialog_warning =>
      'Isso substituirá TODOS os dados atuais pelos dados do backup. Esta ação não pode ser desfeita.';

  @override
  String backup_restore_safetyReview_progress(int done, int total) {
    return 'Analisados $done de $total mergulhos';
  }

  @override
  String get backup_restore_safetyReview_skip => 'Ignorar';

  @override
  String get backup_restore_safetyReview_title =>
      'Executando a revisão de segurança';

  @override
  String get backup_restoreComplete_continue => 'Continuar';

  @override
  String get backup_restoreComplete_description =>
      'Seus dados foram restaurados com sucesso. Toque em continuar para recarregar o app com seus dados restaurados.';

  @override
  String get backup_restoreComplete_title => 'Restauracao Concluida';

  @override
  String get backup_schedule_enabled => 'Backups automáticos';

  @override
  String get backup_schedule_enabled_subtitle =>
      'Fazer backup dos dados em um agendamento';

  @override
  String get backup_schedule_frequency => 'Frequência';

  @override
  String get backup_schedule_retention => 'Manter backups';

  @override
  String get backup_schedule_retention_subtitle =>
      'Backups mais antigos são removidos automaticamente';

  @override
  String get backup_section_auto => 'Backups Automaticos';

  @override
  String get backup_section_cloud => 'Nuvem';

  @override
  String get backup_section_history => 'Histórico';

  @override
  String get backup_section_schedule => 'Agendamento';

  @override
  String get backup_status_disabled => 'Backups Automáticos Desativados';

  @override
  String backup_status_lastBackup(String time) {
    return 'Último backup: $time';
  }

  @override
  String get backup_status_neverBackedUp => 'Nunca Feito Backup';

  @override
  String get backup_status_noBackupsYet =>
      'Crie seu primeiro backup para proteger seus dados';

  @override
  String get backup_status_overdue => 'Backup Atrasado';

  @override
  String get backup_status_upToDate => 'Backups Atualizados';

  @override
  String backup_time_daysAgo(int count) {
    return '${count}d atrás';
  }

  @override
  String backup_time_hoursAgo(int count) {
    return '${count}h atrás';
  }

  @override
  String get backup_time_justNow => 'Agora mesmo';

  @override
  String backup_time_minutesAgo(int count) {
    return '${count}m atrás';
  }

  @override
  String get buddies_action_add => 'Adicionar Companheiro';

  @override
  String get buddies_action_addCertification => 'Adicionar certificação';

  @override
  String get buddies_action_addFirst => 'Adicione seu primeiro companheiro';

  @override
  String get buddies_action_addTooltip =>
      'Adicionar um novo companheiro de mergulho';

  @override
  String get buddies_action_clearSearch => 'Limpar busca';

  @override
  String get buddies_action_edit => 'Editar companheiro';

  @override
  String get buddies_action_importFromContacts => 'Importar dos Contatos';

  @override
  String get buddies_action_moreOptions => 'Mais opções';

  @override
  String get buddies_action_retry => 'Tentar novamente';

  @override
  String get buddies_action_search => 'Buscar companheiros';

  @override
  String get buddies_action_shareDives => 'Compartilhar Mergulhos';

  @override
  String get buddies_action_sort => 'Ordenar';

  @override
  String get buddies_action_sortTitle => 'Ordenar Companheiros';

  @override
  String get buddies_action_update => 'Atualizar Companheiro';

  @override
  String buddies_action_viewAll(Object count) {
    return 'Ver Todos ($count)';
  }

  @override
  String buddies_detail_error(Object error) {
    return 'Erro: $error';
  }

  @override
  String get buddies_detail_noDivesTogether => 'Nenhum mergulho juntos ainda';

  @override
  String get buddies_detail_notFound => 'Companheiro não encontrado';

  @override
  String buddies_dialog_deleteMessage(Object name) {
    return 'Tem certeza de que deseja excluir $name? Esta ação não pode ser desfeita.';
  }

  @override
  String get buddies_dialog_deleteTitle => 'Excluir Companheiro?';

  @override
  String get buddies_dialog_discard => 'Descartar';

  @override
  String get buddies_dialog_discardMessage =>
      'Você tem alterações não salvas. Tem certeza de que deseja descartá-las?';

  @override
  String get buddies_dialog_discardTitle => 'Descartar Alterações?';

  @override
  String get buddies_dialog_keepEditing => 'Continuar Editando';

  @override
  String get buddies_empty_subtitle =>
      'Adicione seu primeiro companheiro de mergulho para começar';

  @override
  String get buddies_empty_title => 'Nenhum companheiro de mergulho ainda';

  @override
  String buddies_error_loading(Object error) {
    return 'Erro: $error';
  }

  @override
  String get buddies_error_unableToLoadDives =>
      'Não foi possível carregar os mergulhos';

  @override
  String get buddies_error_unableToLoadStats =>
      'Não foi possível carregar as estatísticas';

  @override
  String get buddies_field_certificationAgency => 'Agência Certificadora';

  @override
  String get buddies_field_certificationLevel => 'Nível de Certificação';

  @override
  String get buddies_field_email => 'E-mail';

  @override
  String get buddies_field_emailHint => 'email@exemplo.com';

  @override
  String get buddies_field_nameHint => 'Digite o nome do companheiro';

  @override
  String get buddies_field_nameRequired => 'Nome *';

  @override
  String get buddies_field_notes => 'Notas';

  @override
  String get buddies_field_notesHint =>
      'Adicione notas sobre este companheiro...';

  @override
  String get buddies_field_phone => 'Telefone';

  @override
  String get buddies_field_phoneHint => '+55 (11) 98765-4321';

  @override
  String get buddies_label_agency => 'Agência';

  @override
  String buddies_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos',
      one: '1 mergulho',
    );
    return '$_temp0';
  }

  @override
  String get buddies_label_level => 'Nível';

  @override
  String get buddies_label_notSpecified => 'Não especificado';

  @override
  String get buddies_label_photoComingSoon =>
      'Suporte a fotos em breve na v2.0';

  @override
  String get buddies_message_added => 'Companheiro adicionado com sucesso';

  @override
  String get buddies_message_contactImportUnavailable =>
      'Importação de contatos não está disponível nesta plataforma';

  @override
  String get buddies_message_contactLoadFailed => 'Falha ao carregar contatos';

  @override
  String get buddies_message_contactPermissionRequired =>
      'Permissão de contatos é necessária para importar companheiros';

  @override
  String get buddies_message_deleted => 'Companheiro excluído';

  @override
  String buddies_message_errorImportingContact(Object error) {
    return 'Erro ao importar contato: $error';
  }

  @override
  String buddies_message_errorLoading(Object error) {
    return 'Erro ao carregar companheiro: $error';
  }

  @override
  String buddies_message_errorSaving(Object error) {
    return 'Erro ao salvar companheiro: $error';
  }

  @override
  String buddies_message_exportFailed(Object error) {
    return 'Falha na exportação: $error';
  }

  @override
  String get buddies_message_noDivesFound =>
      'Nenhum mergulho encontrado para exportar';

  @override
  String get buddies_message_noDivesToShare =>
      'Nenhum mergulho para compartilhar com este companheiro';

  @override
  String get buddies_message_preparingExport => 'Preparando exportação...';

  @override
  String get buddies_message_updated => 'Companheiro atualizado com sucesso';

  @override
  String get buddies_picker_add => 'Adicionar';

  @override
  String get buddies_picker_addCustomRole =>
      'Adicionar função personalizada...';

  @override
  String get buddies_picker_addNew => 'Adicionar Novo Companheiro';

  @override
  String get buddies_picker_done => 'Concluir';

  @override
  String get buddies_picker_me => 'Eu';

  @override
  String get buddies_picker_noBuddiesFound => 'Nenhum companheiro encontrado';

  @override
  String get buddies_picker_noBuddiesYet => 'Nenhum companheiro ainda';

  @override
  String get buddies_picker_noRole => 'Sem função';

  @override
  String get buddies_picker_noneSelected => 'Nenhum companheiro selecionado';

  @override
  String get buddies_picker_searchHint => 'Buscar companheiros...';

  @override
  String get buddies_picker_selectBuddies => 'Selecionar Companheiros';

  @override
  String get buddies_picker_selectMyRole => 'Selecionar minha função';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Selecionar Função para $name';
  }

  @override
  String get buddies_picker_setMyRole => 'Definir minha função';

  @override
  String get buddies_picker_tapToAdd =>
      'Toque em \'Adicionar\' para selecionar companheiros de mergulho';

  @override
  String get buddies_search_hint => 'Buscar por nome, e-mail ou telefone';

  @override
  String buddies_search_noResults(Object query) {
    return 'Nenhum companheiro encontrado para \"$query\"';
  }

  @override
  String get buddies_section_certification => 'Certificação';

  @override
  String get buddies_section_certifications => 'Certificações';

  @override
  String get buddies_certifications_empty => 'Sem certificações';

  @override
  String get buddies_section_contact => 'Contato';

  @override
  String get buddies_section_diveStatistics => 'Estatísticas de Mergulho';

  @override
  String get buddies_section_notes => 'Notas';

  @override
  String get buddies_section_sharedDives => 'Mergulhos Compartilhados';

  @override
  String get buddies_stat_divesTogether => 'Mergulhos Juntos';

  @override
  String get buddies_stat_favoriteSite => 'Local Favorito';

  @override
  String get buddies_stat_firstDive => 'Primeiro Mergulho';

  @override
  String get buddies_stat_lastDive => 'Último Mergulho';

  @override
  String get buddies_summary_overview => 'Visão Geral';

  @override
  String get buddies_summary_quickActions => 'Ações Rápidas';

  @override
  String get buddies_summary_recentBuddies => 'Companheiros Recentes';

  @override
  String get buddies_summary_selectHint =>
      'Selecione um companheiro da lista para ver os detalhes';

  @override
  String get buddies_summary_title => 'Companheiros de Mergulho';

  @override
  String get buddies_summary_totalBuddies => 'Total de Companheiros';

  @override
  String get buddies_summary_withCertification => 'Com Certificação';

  @override
  String get buddies_title => 'Companheiros';

  @override
  String get buddies_title_add => 'Adicionar Companheiro';

  @override
  String get buddies_title_edit => 'Editar Companheiro';

  @override
  String get buddies_title_singular => 'Companheiro';

  @override
  String get buddies_validation_emailInvalid => 'Digite um e-mail válido';

  @override
  String get buddies_validation_nameRequired => 'Digite um nome';

  @override
  String get buddies_list_selection_closeTooltip => 'Fechar seleção';

  @override
  String buddies_list_selection_count(int count) {
    return '$count selecionado(s)';
  }

  @override
  String get buddies_list_selection_selectAllTooltip => 'Selecionar tudo';

  @override
  String get buddies_list_selection_deselectAllTooltip => 'Desmarcar tudo';

  @override
  String get buddies_list_selection_mergeTooltip => 'Mesclar selecionados';

  @override
  String get buddies_list_selection_deleteTooltip => 'Excluir selecionados';

  @override
  String buddies_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'companheiros',
      one: 'companheiro',
    );
    return '$count $_temp0 mesclado(s)';
  }

  @override
  String get buddies_list_merge_undo => 'Desfazer';

  @override
  String get buddies_list_merge_restored => 'Mesclagem desfeita';

  @override
  String get buddies_list_bulkDelete_title => 'Excluir Companheiros';

  @override
  String buddies_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'companheiros',
      one: 'companheiro',
    );
    return 'Tem certeza de que deseja excluir $count $_temp0? Esta ação não pode ser desfeita.';
  }

  @override
  String get buddies_list_bulkDelete_cancel => 'Cancelar';

  @override
  String get buddies_list_bulkDelete_confirm => 'Excluir';

  @override
  String buddies_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'companheiros',
      one: 'companheiro',
    );
    return '$count $_temp0 excluído(s)';
  }

  @override
  String get buddies_edit_merge_title => 'Mesclar Companheiros';

  @override
  String get buddies_edit_merge_fieldSourceCycleTooltip =>
      'Usar valor do próximo companheiro selecionado';

  @override
  String buddies_edit_merge_fieldSourceLabel(
    String buddyName,
    int current,
    int total,
  ) {
    return 'De $buddyName ($current/$total)';
  }

  @override
  String get buddies_edit_merge_confirmTitle => 'Mesclar Companheiros';

  @override
  String buddies_edit_merge_confirmBody(int count) {
    return 'Isso mesclará $count companheiros em um. As associações de mergulho serão combinadas sob o companheiro resultante. Os outros companheiros serão excluídos.';
  }

  @override
  String get buddies_edit_merge_loadingErrorTitle => 'Mesclar Companheiros';

  @override
  String buddies_edit_merge_loadingErrorBody(String error) {
    return 'Falha ao carregar companheiros: $error';
  }

  @override
  String get buddies_edit_merge_notEnoughTitle => 'Mesclar Companheiros';

  @override
  String get buddies_edit_merge_notEnoughBody =>
      'Companheiros insuficientes para mesclar.';

  @override
  String get buddies_instructorPicker_label =>
      'Instrutor da lista de companheiros';

  @override
  String get buddies_instructorPicker_none => 'Nenhum (entrada manual)';

  @override
  String get certifications_appBar_addCertification => 'Adicionar Certificacao';

  @override
  String get certifications_appBar_certificationWallet =>
      'Carteira de Certificacoes';

  @override
  String get certifications_appBar_editCertification => 'Editar Certificacao';

  @override
  String get certifications_appBar_title => 'Certificacoes';

  @override
  String get certifications_detail_action_delete => 'Excluir';

  @override
  String get certifications_detail_appBar_title => 'Certificacao';

  @override
  String get certifications_detail_courseCompleted => 'Concluido';

  @override
  String get certifications_detail_courseInProgress => 'Em Andamento';

  @override
  String get certifications_detail_dialog_cancel => 'Cancelar';

  @override
  String get certifications_detail_dialog_deleteConfirm => 'Excluir';

  @override
  String certifications_detail_dialog_deleteContent(Object name) {
    return 'Tem certeza de que deseja excluir \"$name\"?';
  }

  @override
  String get certifications_detail_dialog_deleteTitle =>
      'Excluir Certificacao?';

  @override
  String get certifications_detail_label_agency => 'Agencia';

  @override
  String get certifications_detail_label_cardNumber => 'Numero do Cartao';

  @override
  String get certifications_detail_label_certification => 'Certificação';

  @override
  String get certifications_detail_label_expiryDate => 'Data de Validade';

  @override
  String get certifications_detail_label_instructorName => 'Nome';

  @override
  String get certifications_detail_label_instructorNumber => 'N. do Instrutor';

  @override
  String get certifications_detail_label_issueDate => 'Data de Emissao';

  @override
  String get certifications_detail_label_type => 'Tipo';

  @override
  String get certifications_detail_label_validity => 'Validade';

  @override
  String get certifications_detail_noExpiration => 'Sem Validade';

  @override
  String get certifications_detail_notFound => 'Certificacao nao encontrada';

  @override
  String get certifications_detail_photoLabel_back => 'Verso';

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
      'Nao foi possivel carregar a imagem';

  @override
  String get certifications_detail_sectionTitle_cardPhotos => 'Fotos do Cartao';

  @override
  String get certifications_detail_sectionTitle_dates => 'Datas';

  @override
  String get certifications_detail_sectionTitle_details =>
      'Detalhes da Certificacao';

  @override
  String get certifications_detail_sectionTitle_instructor => 'Instrutor';

  @override
  String get certifications_detail_sectionTitle_notes => 'Observacoes';

  @override
  String get certifications_detail_sectionTitle_trainingCourse =>
      'Curso de Treinamento';

  @override
  String certifications_detail_semanticLabel_photoTapToView(
    Object label,
    Object name,
  ) {
    return 'Foto $label de $name. Toque para ver em tela cheia';
  }

  @override
  String get certifications_detail_snackBar_deleted => 'Certificacao excluida';

  @override
  String get certifications_detail_status_expired =>
      'Esta certificacao expirou';

  @override
  String certifications_detail_status_expiredOn(Object date) {
    return 'Expirou em $date';
  }

  @override
  String certifications_detail_status_expiresInDays(Object days) {
    return 'Expira em $days dias';
  }

  @override
  String certifications_detail_status_expiresOn(Object date) {
    return 'Expira em $date';
  }

  @override
  String get certifications_detail_tooltip_edit => 'Editar certificacao';

  @override
  String get certifications_detail_tooltip_editShort => 'Editar';

  @override
  String get certifications_detail_tooltip_moreOptions => 'Mais opcoes';

  @override
  String get certifications_ecardStack_empty_subtitle =>
      'Adicione sua primeira certificacao para ve-la aqui';

  @override
  String get certifications_ecardStack_empty_title =>
      'Nenhuma certificacao ainda';

  @override
  String get certifications_ecard_label_cardNumber => 'N.º DO CARTÃO';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Certificado por $agency';
  }

  @override
  String get certifications_ecard_label_diver => 'MERGULHADOR';

  @override
  String get certifications_ecard_label_instructor => 'INSTRUTOR';

  @override
  String get certifications_ecard_label_issued => 'EMITIDO';

  @override
  String get certifications_ecard_label_validUntil => 'VÁLIDA ATÉ';

  @override
  String get certifications_ecard_statusBadge_expired => 'EXPIRADO';

  @override
  String get certifications_ecard_statusBadge_expiring => 'EXPIRANDO';

  @override
  String get certifications_edit_appBar_add => 'Adicionar Certificacao';

  @override
  String get certifications_edit_appBar_edit => 'Editar Certificacao';

  @override
  String get certifications_edit_button_add => 'Adicionar Certificacao';

  @override
  String get certifications_edit_button_cancel => 'Cancelar';

  @override
  String get certifications_edit_button_save => 'Salvar';

  @override
  String get certifications_edit_button_update => 'Atualizar Certificacao';

  @override
  String get certifications_edit_certification_notSpecified =>
      'Não especificado';

  @override
  String certifications_edit_datePicker_clearTooltip(Object label) {
    return 'Limpar $label';
  }

  @override
  String get certifications_edit_datePicker_tapToSelect =>
      'Toque para selecionar';

  @override
  String get certifications_edit_dialog_discard => 'Descartar';

  @override
  String get certifications_edit_dialog_discardContent =>
      'Voce tem alteracoes nao salvas. Tem certeza de que deseja sair?';

  @override
  String get certifications_edit_dialog_discardTitle => 'Descartar Alteracoes?';

  @override
  String get certifications_edit_dialog_keepEditing => 'Continuar Editando';

  @override
  String get certifications_edit_group_progression => 'Progressão';

  @override
  String get certifications_edit_group_specialties => 'Especialidades';

  @override
  String get certifications_edit_help_expiryDate =>
      'Deixe vazio para certificacoes que nao expiram';

  @override
  String get certifications_edit_helper_nameOnCard => 'Opcional';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Insira o numero do cartao de certificacao';

  @override
  String get certifications_edit_hint_instructorName =>
      'Nome do instrutor certificador';

  @override
  String get certifications_edit_hint_instructorNumber =>
      'Numero de certificacao do instrutor';

  @override
  String get certifications_edit_hint_notes =>
      'Quaisquer observacoes adicionais';

  @override
  String get certifications_edit_label_agency => 'Agencia *';

  @override
  String get certifications_edit_label_cardNumber => 'Numero do Cartao';

  @override
  String get certifications_edit_label_certification => 'Certificação';

  @override
  String get certifications_edit_label_expiryDate => 'Data de Validade';

  @override
  String get certifications_edit_label_instructorName => 'Nome do Instrutor';

  @override
  String get certifications_edit_label_instructorNumber =>
      'Numero do Instrutor';

  @override
  String get certifications_edit_label_issueDate => 'Data de Emissao';

  @override
  String get certifications_edit_label_nameOnCard => 'Nome no cartão';

  @override
  String get certifications_edit_label_notes => 'Observacoes';

  @override
  String certifications_edit_photo_addSemanticLabel(Object label) {
    return 'Adicionar foto $label. Toque para selecionar';
  }

  @override
  String certifications_edit_photo_attachedSemanticLabel(Object label) {
    return 'Foto $label anexada. Toque para alterar';
  }

  @override
  String get certifications_edit_photo_chooseFromGallery =>
      'Escolher da Galeria';

  @override
  String certifications_edit_photo_removeTooltip(Object label) {
    return 'Remover foto $label';
  }

  @override
  String get certifications_edit_photo_takePhoto => 'Tirar Foto';

  @override
  String get certifications_edit_sectionTitle_cardPhotos => 'Fotos do Cartao';

  @override
  String get certifications_edit_sectionTitle_dates => 'Datas';

  @override
  String get certifications_edit_sectionTitle_instructorInfo =>
      'Informacoes do Instrutor';

  @override
  String get certifications_edit_sectionTitle_notes => 'Observacoes';

  @override
  String get certifications_edit_snackBar_added =>
      'Certificacao adicionada com sucesso';

  @override
  String certifications_edit_snackBar_errorLoading(Object error) {
    return 'Erro ao carregar certificacao: $error';
  }

  @override
  String certifications_edit_snackBar_errorPhoto(Object error) {
    return 'Erro ao selecionar foto: $error';
  }

  @override
  String certifications_edit_snackBar_errorSaving(Object error) {
    return 'Erro ao salvar certificacao: $error';
  }

  @override
  String get certifications_edit_snackBar_updated =>
      'Certificacao atualizada com sucesso';

  @override
  String get certifications_edit_validation_certificationOrNameRequired =>
      'Escolha uma certificação ou insira um nome';

  @override
  String get certifications_list_button_retry => 'Tentar novamente';

  @override
  String get certifications_list_empty_button =>
      'Adicionar Sua Primeira Certificacao';

  @override
  String get certifications_list_empty_subtitle =>
      'Adicione suas certificacoes de mergulho para acompanhar\nseu treinamento e qualificacoes';

  @override
  String get certifications_list_empty_title =>
      'Nenhuma certificacao adicionada ainda';

  @override
  String certifications_list_error_loading(Object error) {
    return 'Erro ao carregar certificacoes: $error';
  }

  @override
  String get certifications_list_fab_addCertification =>
      'Adicionar Certificacao';

  @override
  String get certifications_list_section_expired => 'Expirada';

  @override
  String get certifications_list_section_expiringSoon => 'Expirando em Breve';

  @override
  String get certifications_list_section_valid => 'Valida';

  @override
  String get certifications_list_sort_title => 'Ordenar Certificacoes';

  @override
  String get certifications_list_tile_expired => 'Expirada';

  @override
  String certifications_list_tile_expiringDays(Object days) {
    return '${days}d';
  }

  @override
  String get certifications_list_tooltip_addCertification =>
      'Adicionar Certificacao';

  @override
  String get certifications_list_tooltip_search => 'Buscar certificacoes';

  @override
  String get certifications_list_tooltip_sort => 'Ordenar';

  @override
  String get certifications_list_tooltip_walletView =>
      'Visualizacao em Carteira';

  @override
  String get certifications_picker_clearTooltip =>
      'Limpar selecao de certificacao';

  @override
  String get certifications_picker_empty_addButton => 'Adicionar Certificacao';

  @override
  String get certifications_picker_empty_title => 'Nenhuma certificacao ainda';

  @override
  String certifications_picker_error(Object error) {
    return 'Erro ao carregar certificacoes: $error';
  }

  @override
  String get certifications_picker_expired => 'Expirada';

  @override
  String get certifications_picker_hint =>
      'Toque para vincular a uma certificacao obtida';

  @override
  String get certifications_picker_newCert => 'Nova Cert.';

  @override
  String get certifications_picker_noSelection =>
      'Nenhuma certificacao selecionada';

  @override
  String get certifications_picker_sheetTitle => 'Vincular a Certificacao';

  @override
  String get certifications_renderer_footer => 'Submersion Dive Log';

  @override
  String certifications_renderer_label_cardNumber(Object number) {
    return 'Cartao #: $number';
  }

  @override
  String get certifications_renderer_label_hasCompletedTraining =>
      'completou o treinamento como';

  @override
  String certifications_renderer_label_instructor(Object name) {
    return 'Instrutor: $name';
  }

  @override
  String certifications_renderer_label_instructorWithNumber(
    Object name,
    Object number,
  ) {
    return 'Instrutor: $name ($number)';
  }

  @override
  String certifications_renderer_label_issued(Object date) {
    return 'Emissao: $date';
  }

  @override
  String get certifications_renderer_label_thisCertifies =>
      'Isto certifica que';

  @override
  String get certifications_search_empty_hint =>
      'Buscar por nome, agencia ou numero do cartao';

  @override
  String get certifications_search_fieldLabel => 'Buscar certificacoes...';

  @override
  String certifications_search_noResults(Object query) {
    return 'Nenhuma certificacao encontrada para \"$query\"';
  }

  @override
  String get certifications_search_tooltip_back => 'Voltar';

  @override
  String get certifications_search_tooltip_clear => 'Limpar busca';

  @override
  String certifications_share_error_card(Object error) {
    return 'Falha ao compartilhar cartao: $error';
  }

  @override
  String certifications_share_error_certificate(Object error) {
    return 'Falha ao compartilhar certificado: $error';
  }

  @override
  String get certifications_share_option_card_subtitle =>
      'Imagem da certificacao em formato cartao de credito';

  @override
  String get certifications_share_option_card_title =>
      'Compartilhar como Cartao';

  @override
  String get certifications_share_option_certificate_subtitle =>
      'Documento de certificado formal';

  @override
  String get certifications_share_option_certificate_title =>
      'Compartilhar como Certificado';

  @override
  String get certifications_share_title => 'Compartilhar Certificacao';

  @override
  String get certifications_summary_header_subtitle =>
      'Selecione uma certificacao da lista para ver detalhes';

  @override
  String get certifications_summary_header_title => 'Certificacoes';

  @override
  String get certifications_summary_overview_title => 'Visao Geral';

  @override
  String get certifications_summary_quickActions_add =>
      'Adicionar Certificacao';

  @override
  String get certifications_summary_quickActions_title => 'Acoes Rapidas';

  @override
  String get certifications_summary_recentTitle => 'Certificacoes Recentes';

  @override
  String get certifications_summary_stat_expired => 'Expiradas';

  @override
  String get certifications_summary_stat_expiringSoon => 'Expirando em Breve';

  @override
  String get certifications_summary_stat_total => 'Total';

  @override
  String get certifications_summary_stat_valid => 'Validas';

  @override
  String get certifications_wallet_appBar_title => 'Carteira de Certificacoes';

  @override
  String get certifications_wallet_error_retry => 'Tentar novamente';

  @override
  String get certifications_wallet_error_title =>
      'Falha ao carregar certificacoes';

  @override
  String get certifications_wallet_options_edit => 'Editar';

  @override
  String get certifications_wallet_options_share => 'Compartilhar';

  @override
  String get certifications_wallet_options_viewDetails => 'Ver Detalhes';

  @override
  String get certifications_wallet_tooltip_add => 'Adicionar certificacao';

  @override
  String get certifications_wallet_tooltip_share => 'Compartilhar certificacao';

  @override
  String get checklists_section_title => 'Lista de Verificação';

  @override
  String checklists_progress(int done, int total) {
    return '$done de $total tarefas concluídas';
  }

  @override
  String get checklists_empty_upcoming =>
      'Planeje sua viagem - adicione tarefas ou aplique um modelo';

  @override
  String get checklists_empty_past => 'Nenhum item na lista de verificação';

  @override
  String get checklists_addItem => 'Adicionar item';

  @override
  String get checklists_item_titleLabel => 'Título';

  @override
  String get checklists_item_titleRequired => 'O título é obrigatório';

  @override
  String get checklists_item_categoryLabel => 'Categoria';

  @override
  String get checklists_item_notesLabel => 'Notas';

  @override
  String get checklists_item_dueDateLabel => 'Data de vencimento';

  @override
  String get checklists_item_dueOffsetLabel => 'Dias antes do início da viagem';

  @override
  String get checklists_item_dueOffsetInvalid => 'Insira 0 ou mais dias';

  @override
  String get checklists_item_overdue => 'Atrasado';

  @override
  String get checklists_item_edit => 'Editar item';

  @override
  String get checklists_item_delete => 'Excluir item';

  @override
  String get checklists_menu_applyTemplate => 'Aplicar modelo...';

  @override
  String get checklists_menu_saveAsTemplate => 'Salvar como modelo...';

  @override
  String get checklists_applySheet_title => 'Aplicar modelo';

  @override
  String get checklists_applySheet_empty =>
      'Ainda não há modelos. Crie-os em Configurações.';

  @override
  String checklists_applySheet_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String checklists_applySheet_confirmAppend(int added, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added itens serão adicionados',
      one: '1 item será adicionado',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped duplicatas ignoradas',
      one: '1 duplicata ignorada',
      zero: 'nenhuma duplicata ignorada',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String checklists_apply_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens adicionados',
      one: '1 item adicionado',
      zero: 'Nenhum item novo adicionado',
    );
    return '$_temp0';
  }

  @override
  String get checklists_apply_templateGone => 'O modelo não existe mais';

  @override
  String get checklists_saveTemplate_title => 'Salvar como modelo';

  @override
  String get checklists_saveTemplate_nameLabel => 'Nome do modelo';

  @override
  String get checklists_saveTemplate_success => 'Modelo salvo';

  @override
  String get checklists_templates_pageTitle =>
      'Modelos de Lista de Verificação';

  @override
  String get checklists_templates_addTemplate => 'Adicionar Modelo';

  @override
  String get checklists_templates_empty => 'Ainda não há modelos';

  @override
  String get checklists_templates_deleteTitle => 'Excluir Modelo';

  @override
  String checklists_templates_deleteContent(Object name) {
    return 'Excluir \"$name\"? As viagens que já o aplicaram manterão seus itens.';
  }

  @override
  String get checklists_template_nameLabel => 'Nome';

  @override
  String get checklists_template_nameRequired => 'O nome é obrigatório';

  @override
  String get checklists_template_descriptionLabel => 'Descrição';

  @override
  String get checklists_template_itemsHeader => 'Itens';

  @override
  String get checklists_template_addItem => 'Adicionar item';

  @override
  String get preDive_templates_title => 'Listas de Verificação Pré-Mergulho';

  @override
  String get preDive_templates_empty =>
      'Ainda não há listas de verificação pré-mergulho';

  @override
  String get preDive_templates_builtInBadge => 'Integrada';

  @override
  String get preDive_templates_clone => 'Duplicar';

  @override
  String get preDive_templates_cloneSuffix => ' (cópia)';

  @override
  String get preDive_templates_delete => 'Excluir';

  @override
  String get preDive_templates_deleteConfirm =>
      'Excluir este modelo de lista de verificação?';

  @override
  String get preDive_templates_strictOrderBadge => 'Ordem estrita';

  @override
  String get preDive_edit_titleNew => 'Nova Lista de Verificação Pré-Mergulho';

  @override
  String get preDive_edit_titleEdit =>
      'Editar Lista de Verificação Pré-Mergulho';

  @override
  String get preDive_edit_name => 'Nome';

  @override
  String get preDive_edit_description => 'Descrição';

  @override
  String get preDive_edit_category => 'Categoria';

  @override
  String get preDive_edit_strictOrder => 'Ordem estrita';

  @override
  String get preDive_edit_strictOrderHelp =>
      'Os itens devem ser concluídos de cima para baixo';

  @override
  String get preDive_edit_addItem => 'Adicionar item';

  @override
  String get preDive_edit_nameRequired => 'Insira um nome';

  @override
  String get preDive_item_title => 'Título';

  @override
  String get preDive_item_section => 'Seção';

  @override
  String get preDive_item_notes => 'Notas';

  @override
  String get preDive_item_required => 'Obrigatório';

  @override
  String get preDive_item_type_check => 'Caixa de seleção';

  @override
  String get preDive_item_type_value => 'Valor registrado';

  @override
  String get preDive_item_type_equipmentSet =>
      'Itens do conjunto de equipamentos';

  @override
  String get preDive_item_valueLabel => 'Rótulo do valor';

  @override
  String get preDive_item_valueUnit => 'Unidade';

  @override
  String get preDive_item_valueMin => 'Mín (aviso)';

  @override
  String get preDive_item_valueMax => 'Máx (aviso)';

  @override
  String preDive_runner_progress(int done, int total) {
    return '$done de $total';
  }

  @override
  String get preDive_runner_complete => 'Concluir';

  @override
  String preDive_runner_completeFlagged(int count) {
    return 'Concluir com $count itens sinalizados?';
  }

  @override
  String get preDive_runner_abort => 'Interromper lista de verificação';

  @override
  String get preDive_runner_abortConfirm =>
      'Interromper esta lista de verificação? Ela será mantida no histórico como interrompida.';

  @override
  String get preDive_runner_skip => 'Pular';

  @override
  String get preDive_runner_flag => 'Sinalizar';

  @override
  String get preDive_runner_undo => 'Redefinir como pendente';

  @override
  String get preDive_runner_serviceOverdue => 'Manutenção vencida';

  @override
  String get preDive_runner_addNote => 'Adicionar nota';

  @override
  String get preDive_runner_enterValue => 'Inserir valor';

  @override
  String preDive_runner_flaggedBadge(int count) {
    return '$count sinalizados';
  }

  @override
  String get preDive_runner_locked =>
      'Esta lista de verificação está bloqueada';

  @override
  String get preDive_sessions_title => 'Listas de Verificação Pré-Mergulho';

  @override
  String get preDive_sessions_empty =>
      'Ainda não há execuções de lista de verificação';

  @override
  String get preDive_sessions_resume => 'Retomar';

  @override
  String get preDive_sessions_start => 'Iniciar lista de verificação';

  @override
  String get preDive_sessions_statusCompleted => 'Concluída';

  @override
  String get preDive_sessions_statusAborted => 'Interrompida';

  @override
  String get preDive_sessions_statusInProgress => 'Em andamento';

  @override
  String get preDive_sessions_linkedDive => 'Mergulho vinculado';

  @override
  String get preDive_link_linkToDive => 'Vincular a mergulho';

  @override
  String get preDive_link_unlinkDive => 'Desvincular mergulho';

  @override
  String get preDive_link_linkChecklist => 'Vincular lista de verificação';

  @override
  String get preDive_link_unlinkChecklist => 'Desvincular lista de verificação';

  @override
  String get preDive_link_searchDives => 'Procurar mergulhos';

  @override
  String get preDive_link_noDives => 'Não há mergulhos para vincular';

  @override
  String preDive_link_noDivesMatch(String query) {
    return 'Nenhum mergulho corresponde a \"$query\"';
  }

  @override
  String get preDive_link_noUnlinkedSessions =>
      'Não há listas de verificação sem vínculo';

  @override
  String get preDive_link_linked =>
      'Lista de verificação vinculada a este mergulho';

  @override
  String get preDive_link_unlinked =>
      'Lista de verificação desvinculada deste mergulho';

  @override
  String get preDive_sessions_delete => 'Excluir';

  @override
  String get preDive_sessions_deleteConfirm =>
      'Excluir este registro de lista de verificação?';

  @override
  String get preDive_sessions_filter => 'Filtrar';

  @override
  String get preDive_sessions_filterTitle => 'Filtrar listas realizadas';

  @override
  String get preDive_sessions_filterChecklist => 'Lista de verificação';

  @override
  String get preDive_sessions_filterStatus => 'Estado';

  @override
  String get preDive_sessions_filterFlaggedOnly => 'Apenas com ocorrências';

  @override
  String get preDive_sessions_filterDateRange => 'Intervalo de datas';

  @override
  String get preDive_sessions_filterAnyDate => 'Qualquer data';

  @override
  String get preDive_sessions_filterClearAll => 'Limpar tudo';

  @override
  String get preDive_sessions_filterApply => 'Aplicar';

  @override
  String get preDive_sessions_filterFlaggedChip => 'Apenas ocorrências';

  @override
  String get preDive_sessions_emptyFiltered =>
      'Nenhuma lista corresponde a estes filtros';

  @override
  String get preDive_sessions_export => 'Exportar para Excel';

  @override
  String get preDive_sessions_exportEmpty => 'Nenhuma lista para exportar';

  @override
  String preDive_sessions_exportFailed(String error) {
    return 'Falha na exportação: $error';
  }

  @override
  String get preDive_start_title => 'Iniciar lista de verificação pré-mergulho';

  @override
  String get preDive_start_template => 'Lista de verificação';

  @override
  String get preDive_start_equipmentSet => 'Conjunto de equipamentos';

  @override
  String get preDive_start_noEquipmentSet => 'Nenhum';

  @override
  String get preDive_start_begin => 'Começar';

  @override
  String get diveLog_listPage_bottomSheet_preDiveChecklist =>
      'Iniciar lista de verificação pré-mergulho';

  @override
  String get preDive_dashboard_title => 'Verificação Pré-Mergulho';

  @override
  String preDive_dashboard_resume(int done, int total) {
    return 'Retomar - $done de $total';
  }

  @override
  String get preDive_dashboard_start => 'Iniciar verificação pré-mergulho';

  @override
  String get trips_detail_preDive_action => 'Lista de verificação pré-mergulho';

  @override
  String get settings_manage_preDiveChecklists =>
      'Listas de Verificação Pré-Mergulho';

  @override
  String get settings_manage_preDiveChecklists_subtitle =>
      'Verificações de dupla, listas de montagem de CCR, preparação de equipamento';

  @override
  String get common_action_back => 'Voltar';

  @override
  String get common_action_cancel => 'Cancelar';

  @override
  String get common_action_close => 'Fechar';

  @override
  String get common_action_continue => 'Continuar';

  @override
  String get common_action_delete => 'Excluir';

  @override
  String get common_action_edit => 'Editar';

  @override
  String get common_action_ok => 'OK';

  @override
  String get common_action_save => 'Salvar';

  @override
  String get common_action_search => 'Buscar';

  @override
  String get common_action_share => 'Partilhar';

  @override
  String get common_label_error => 'Erro';

  @override
  String get common_label_loading => 'Carregando';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get common_error_tryAgain => 'Algo correu mal. Tenta novamente.';

  @override
  String get courses_action_add => 'Adicionar Curso';

  @override
  String get courses_action_addFromTemplate => 'Adicionar a partir de modelo';

  @override
  String get courses_action_addRequirement => 'Adicionar requisito';

  @override
  String get courses_action_create => 'Criar Curso';

  @override
  String get courses_action_deleteRequirement => 'Excluir requisito';

  @override
  String get courses_action_edit => 'Editar curso';

  @override
  String get courses_action_editRequirement => 'Editar requisito';

  @override
  String get courses_action_exportTrainingLog =>
      'Exportar Registro de Treinamento';

  @override
  String get courses_action_linkDive => 'Vincular';

  @override
  String get courses_action_markCompleted => 'Marcar como Concluído';

  @override
  String get courses_action_unlinkDive => 'Desvincular mergulho';

  @override
  String get courses_action_moreOptions => 'Mais opções';

  @override
  String get courses_action_retry => 'Tentar novamente';

  @override
  String get courses_action_saveChanges => 'Salvar Alterações';

  @override
  String get courses_action_saveSemantic => 'Salvar curso';

  @override
  String get courses_action_sort => 'Ordenar';

  @override
  String get courses_action_sortTitle => 'Ordenar Cursos';

  @override
  String courses_card_instructor(Object name) {
    return 'Instrutor: $name';
  }

  @override
  String courses_card_started(Object date) {
    return 'Iniciado em $date';
  }

  @override
  String get courses_detail_certificationNotFound =>
      'Certificação não encontrada';

  @override
  String get courses_detail_noTrainingDives =>
      'Nenhum mergulho de treinamento vinculado ainda';

  @override
  String get courses_detail_notFound => 'Curso não encontrado';

  @override
  String get courses_dialog_complete => 'Concluir';

  @override
  String courses_dialog_deleteMessage(Object name) {
    return 'Tem certeza de que deseja excluir $name? Esta ação não pode ser desfeita.';
  }

  @override
  String get courses_dialog_deleteTitle => 'Excluir Curso?';

  @override
  String get courses_dialog_markCompletedMessage =>
      'Isso marcará o curso como concluído com a data de hoje. Continuar?';

  @override
  String get courses_dialog_markCompletedTitle => 'Marcar como Concluído?';

  @override
  String get courses_empty_button =>
      'Adicione seu primeiro curso de treinamento';

  @override
  String get courses_empty_noCompleted => 'Nenhum curso concluído';

  @override
  String get courses_empty_noInProgress => 'Nenhum curso em andamento';

  @override
  String get courses_empty_subtitle =>
      'Adicione seu primeiro curso para começar';

  @override
  String get courses_empty_title => 'Nenhum curso de treinamento ainda';

  @override
  String courses_error_generic(Object error) {
    return 'Erro: $error';
  }

  @override
  String get courses_error_loadingCertification =>
      'Erro ao carregar certificação';

  @override
  String get courses_error_loadingDives => 'Erro ao carregar mergulhos';

  @override
  String get courses_field_courseName => 'Nome do Curso';

  @override
  String get courses_field_courseNameHint => 'ex: Open Water Diver';

  @override
  String get courses_field_instructorName => 'Nome do Instrutor';

  @override
  String get courses_field_instructorNumber => 'Número do Instrutor';

  @override
  String get courses_field_linkCertificationHint =>
      'Vincular uma certificação obtida neste curso';

  @override
  String get courses_field_location => 'Local';

  @override
  String get courses_field_notes => 'Notas';

  @override
  String get courses_filter_all => 'Todos';

  @override
  String get courses_label_agency => 'Agência';

  @override
  String get courses_label_completed => 'Concluído';

  @override
  String get courses_label_completionDate => 'Data de Conclusão';

  @override
  String get courses_label_courseInProgress => 'Curso em andamento';

  @override
  String get courses_label_instructorNumber => 'Instrutor nº';

  @override
  String get courses_label_location => 'Local';

  @override
  String get courses_label_name => 'Nome';

  @override
  String get courses_label_startDate => 'Data de Início';

  @override
  String courses_message_errorSaving(Object error) {
    return 'Erro ao salvar curso: $error';
  }

  @override
  String courses_message_exportFailed(Object error) {
    return 'Falha ao exportar registro de treinamento: $error';
  }

  @override
  String get courses_picker_active => 'Ativo';

  @override
  String get courses_picker_clearSelection => 'Limpar seleção';

  @override
  String get courses_picker_createCourse => 'Criar Curso';

  @override
  String courses_picker_errorLoading(Object error) {
    return 'Erro ao carregar cursos: $error';
  }

  @override
  String get courses_picker_newCourse => 'Novo Curso';

  @override
  String get courses_picker_noCourses => 'Nenhum curso ainda';

  @override
  String get courses_picker_noneSelected => 'Nenhum curso selecionado';

  @override
  String get courses_picker_selectTitle => 'Selecionar Curso de Treinamento';

  @override
  String get courses_picker_selected => 'selecionado';

  @override
  String get courses_picker_tapToLink =>
      'Toque para vincular a um curso de treinamento';

  @override
  String courses_requirement_diveProgress(int count, int target) {
    return '$count de $target mergulhos';
  }

  @override
  String get courses_requirement_field_name => 'Nome';

  @override
  String get courses_requirement_field_targetCount => 'Mergulhos necessários';

  @override
  String get courses_requirement_kind_checklist => 'Item de verificação';

  @override
  String get courses_requirement_kind_dive => 'Requisito de mergulho';

  @override
  String get courses_requirement_suggestions => 'Mergulhos sugeridos';

  @override
  String get courses_requirements_empty =>
      'Acompanhe mergulhos de aventura, pré-requisitos e itens de verificação deste curso.';

  @override
  String courses_requirements_progress(int satisfied, int total) {
    return '$satisfied de $total concluídos';
  }

  @override
  String get courses_section_details => 'Detalhes do Curso';

  @override
  String get courses_section_earnedCertification => 'Certificação Obtida';

  @override
  String get courses_section_instructor => 'Instrutor';

  @override
  String get courses_section_notes => 'Notas';

  @override
  String get courses_section_requirements => 'Requisitos';

  @override
  String get courses_section_trainingDives => 'Mergulhos de Treinamento';

  @override
  String get courses_status_completed => 'Concluído';

  @override
  String courses_status_daysSinceStart(Object days) {
    return '$days dias desde o início';
  }

  @override
  String courses_status_durationDays(Object days) {
    return '$days dias';
  }

  @override
  String get courses_status_inProgress => 'Em Andamento';

  @override
  String courses_status_semanticLabel(Object status, Object duration) {
    return '$status, $duration';
  }

  @override
  String courses_template_addsCount(int count) {
    return 'Adiciona $count requisitos';
  }

  @override
  String get courses_summary_overview => 'Visão Geral';

  @override
  String get courses_summary_quickActions => 'Ações Rápidas';

  @override
  String get courses_summary_recentCourses => 'Cursos Recentes';

  @override
  String get courses_summary_selectHint =>
      'Selecione um curso da lista para ver os detalhes';

  @override
  String get courses_summary_title => 'Cursos de Treinamento';

  @override
  String get courses_summary_total => 'Total';

  @override
  String get courses_title => 'Cursos de Treinamento';

  @override
  String get courses_title_edit => 'Editar Curso';

  @override
  String get courses_title_new => 'Novo Curso';

  @override
  String get courses_title_singular => 'Curso';

  @override
  String get courses_validation_nameRequired => 'Digite um nome para o curso';

  @override
  String get dashboard_activeCourses_title => 'Cursos em andamento';

  @override
  String get dashboard_activity_daySinceDiving => 'Dia sem mergulhar';

  @override
  String get dashboard_activity_daysSinceDiving => 'Dias sem mergulhar';

  @override
  String dashboard_activity_diveInYear(Object year) {
    return 'Mergulho em $year';
  }

  @override
  String get dashboard_activity_diveThisMonth => 'Mergulho este mes';

  @override
  String dashboard_activity_divesInYear(Object year) {
    return 'Mergulhos em $year';
  }

  @override
  String get dashboard_activity_divesThisMonth => 'Mergulhos este mes';

  @override
  String get dashboard_activity_error => 'Erro';

  @override
  String get dashboard_activity_lastDive => 'Ultimo mergulho';

  @override
  String get dashboard_activity_loading => 'Carregando';

  @override
  String get dashboard_activity_noDivesYet => 'Nenhum mergulho ainda';

  @override
  String get dashboard_activity_today => 'Hoje!';

  @override
  String get dashboard_alerts_actionUpdate => 'Atualizar';

  @override
  String get dashboard_alerts_actionView => 'Ver';

  @override
  String get dashboard_alerts_checkInsuranceExpiry =>
      'Verifique a validade do seu seguro';

  @override
  String get dashboard_alerts_daysOverdueOne => '1 dia atrasado';

  @override
  String dashboard_alerts_daysOverdueOther(Object count) {
    return '$count dias atrasados';
  }

  @override
  String get dashboard_alerts_dueInDaysOne => 'Vence em 1 dia';

  @override
  String dashboard_alerts_dueInDaysOther(Object count) {
    return 'Vence em $count dias';
  }

  @override
  String dashboard_alerts_equipmentServiceDue(Object name) {
    return 'Manutencao de $name Pendente';
  }

  @override
  String dashboard_alerts_equipmentServiceOverdue(Object name) {
    return 'Manutencao de $name Atrasada';
  }

  @override
  String get dashboard_alerts_insuranceExpired => 'Seguro Vencido';

  @override
  String get dashboard_alerts_insuranceExpiredGeneric =>
      'Seu seguro de mergulho venceu';

  @override
  String dashboard_alerts_insuranceExpiredProvider(Object provider) {
    return '$provider vencido';
  }

  @override
  String dashboard_alerts_insuranceExpiresDate(Object date) {
    return 'Vence em $date';
  }

  @override
  String get dashboard_alerts_insuranceExpiringSoon =>
      'Seguro Vencendo em Breve';

  @override
  String get dashboard_alerts_sectionTitle => 'Alertas e Lembretes';

  @override
  String get dashboard_alerts_serviceDueToday =>
      'Manutencao prevista para hoje';

  @override
  String get dashboard_alerts_serviceIntervalReached =>
      'Intervalo de manutencao atingido';

  @override
  String get dashboard_defaultDiverName => 'Mergulhador';

  @override
  String get dashboard_greeting_afternoon => 'Boa tarde';

  @override
  String get dashboard_greeting_evening => 'Boa noite';

  @override
  String get dashboard_greeting_morning => 'Bom dia';

  @override
  String dashboard_greeting_withName(Object greeting, Object name) {
    return '$greeting, $name!';
  }

  @override
  String dashboard_greeting_withoutName(Object greeting) {
    return '$greeting!';
  }

  @override
  String get dashboard_hero_divesLoggedOne => '1 mergulho registrado';

  @override
  String dashboard_hero_divesLoggedOther(Object count) {
    return '$count mergulhos registrados';
  }

  @override
  String get dashboard_hero_divesTotalOne => '1 mergulho';

  @override
  String dashboard_hero_divesTotalOther(Object count) {
    return '$count mergulhos';
  }

  @override
  String get dashboard_hero_error => 'Pronto para explorar as profundezas?';

  @override
  String dashboard_hero_hoursUnderwater(Object hours) {
    return '$hours horas submerso';
  }

  @override
  String get dashboard_hero_loading =>
      'Carregando suas estatisticas de mergulho...';

  @override
  String dashboard_hero_minutesUnderwater(Object minutes) {
    return '$minutes minutos submerso';
  }

  @override
  String get dashboard_hero_noDives =>
      'Pronto para registrar seu primeiro mergulho?';

  @override
  String get dashboard_hero_divesLoggedLabel => 'mergulhos registrados';

  @override
  String get dashboard_hero_hoursUnderwaterLabel => 'horas subaquáticas';

  @override
  String get dashboard_hero_daysSinceLabel => 'dias desde o último mergulho';

  @override
  String get dashboard_hero_thisMonthLabel => 'este mês';

  @override
  String get dashboard_hero_thisYearLabel => 'mergulhos este ano';

  @override
  String get dashboard_hero_todayLabel => 'hoje!';

  @override
  String get dashboard_hero_noDivesLabel => 'nenhum mergulho ainda';

  @override
  String get dashboard_hero_diverFallbackName => 'Mergulhador';

  @override
  String get dashboard_hero_statDives => 'mergulhos';

  @override
  String get dashboard_hero_statHours => 'horas';

  @override
  String get dashboard_hero_statSites => 'locais';

  @override
  String get dashboard_hero_statCountries => 'países';

  @override
  String dashboard_activityStats_divesInYear(String year) {
    return 'mergulhos em $year';
  }

  @override
  String get dashboard_semantics_statsBar =>
      'Resumo das estatísticas de mergulho';

  @override
  String get dashboard_gauges_addGear => 'Adicionar equipamento';

  @override
  String dashboard_gauges_gearOk(String name) {
    return '$name OK';
  }

  @override
  String dashboard_gauges_gearDueIn(String name, int days) {
    return '$name vence em ${days}d';
  }

  @override
  String dashboard_gauges_gearOverdue(String name) {
    return '$name atrasado';
  }

  @override
  String get dashboard_gauges_insuranceOk => 'Seguro OK';

  @override
  String dashboard_gauges_insuranceExpires(String date) {
    return 'Seguro expira em $date';
  }

  @override
  String get dashboard_gauges_insuranceExpired => 'Seguro expirado';

  @override
  String get dashboard_gauges_noInsurance => 'Sem seguro registado';

  @override
  String get dashboard_gauges_noFlyClear => 'Não voar 0:00';

  @override
  String dashboard_gauges_flightWindow(String hours, String minutes) {
    return 'Janela de mergulho $hours:$minutes';
  }

  @override
  String get dashboard_gauges_flightWindowClosed =>
      'Não mergulhe mais antes do voo';

  @override
  String dashboard_gauges_noFlyRemaining(String hours, String minutes) {
    return 'Não voar $hours:$minutes';
  }

  @override
  String dashboard_gauges_lastDiveDays(int days) {
    return 'Último mergulho há ${days}d';
  }

  @override
  String get dashboard_gauges_lastDiveToday => 'Mergulhou hoje';

  @override
  String get dashboard_gauges_noDivesYet => 'Ainda sem mergulhos';

  @override
  String get settings_homeChips_pageTitle => 'Ecrã inicial';

  @override
  String get settings_homeChips_description =>
      'Escolha que chips de estado aparecem no topo do separador Início.';

  @override
  String get settings_homeChips_sectionTitle => 'Chips de estado';

  @override
  String get settings_homeCards_sectionTitle => 'Cartões do Início';

  @override
  String get settings_homeCards_description =>
      'Escolha que cartões aparecem no separador Início e arraste-os para reordenar.';

  @override
  String get settings_homeCards_autoHides =>
      'Oculta-se automaticamente quando vazio';

  @override
  String get settings_homeCards_resetToDefault => 'Repor predefinições';

  @override
  String get settings_homeCards_resetDialog_title =>
      'Repor o esquema do Início?';

  @override
  String get settings_homeCards_resetDialog_message =>
      'Repõe a ordem predefinida dos cartões e volta a mostrá-los todos.';

  @override
  String get settings_homeCards_resetDialog_cancel => 'Cancelar';

  @override
  String get settings_homeCards_resetDialog_confirm => 'Repor';

  @override
  String get settings_homeCards_card_hero => 'Cabeçalho de boas-vindas';

  @override
  String get settings_homeCards_card_gaugeStrip => 'Chips de estado';

  @override
  String get settings_homeCards_card_preDive => 'Checklist pré-mergulho';

  @override
  String get settings_homeCards_card_recentDives => 'Mergulhos recentes';

  @override
  String get settings_homeCards_card_quickActions => 'Ações rápidas';

  @override
  String get settings_homeCards_card_milestones => 'Marcos';

  @override
  String get settings_homeCards_card_photoRibbon => 'Mídia recente';

  @override
  String get settings_homeCards_card_onThisDay => 'Neste dia';

  @override
  String get settings_homeCards_card_yearInReview => 'Retrospetiva do ano';

  @override
  String get settings_homeCards_card_activeCourses => 'Progresso do curso';

  @override
  String get settings_homeCards_card_recentSitesMap =>
      'Mapa de locais recentes';

  @override
  String get dashboard_allHidden_message =>
      'Todos os cartões do Início estão ocultos.';

  @override
  String get dashboard_allHidden_customize => 'Personalizar Início';

  @override
  String get settings_homeChips_flightWindow =>
      'Janela de mergulho antes do voo';

  @override
  String get settings_homeChips_gear => 'Manutenção do equipamento';

  @override
  String get settings_homeChips_insurance => 'Seguro';

  @override
  String get settings_homeChips_noFly => 'Temporizador de não voar';

  @override
  String get settings_homeChips_lastDive => 'Atualidade de mergulho';

  @override
  String get settings_homeChips_certifications => 'Expiração de certificações';

  @override
  String get settings_homeChips_trip => 'Próxima viagem';

  @override
  String get settings_homeChips_checklist => 'Lista de verificação ativa';

  @override
  String get settings_homeChips_course => 'Progresso do curso';

  @override
  String get settings_homeChips_uploads => 'Envios de média';

  @override
  String get settings_homeChips_backup => 'Idade da cópia';

  @override
  String get settings_homeChips_sync => 'Estado de sincronização';

  @override
  String get settings_homeChips_dataQuality => 'Qualidade dos dados';

  @override
  String dashboard_gauges_certsExpiring(int count) {
    return '$count certificações a expirar';
  }

  @override
  String dashboard_gauges_tripCountdown(String name, int days) {
    return '$name em ${days}d';
  }

  @override
  String get dashboard_gauges_checklistActive =>
      'Lista de verificação em curso';

  @override
  String dashboard_gauges_courseProgress(String name, int done, int total) {
    return '$name: $done/$total';
  }

  @override
  String dashboard_gauges_uploadsPending(int count) {
    return '$count envios pendentes';
  }

  @override
  String get dashboard_gauges_backupNone => 'Sem cópia de segurança';

  @override
  String get dashboard_gauges_backupToday => 'Cópia feita hoje';

  @override
  String dashboard_gauges_backupDays(int days) {
    return 'Cópia há ${days}d';
  }

  @override
  String dashboard_gauges_syncPending(int count) {
    return '$count por sincronizar';
  }

  @override
  String get dashboard_gauges_synced => 'Sincronizado';

  @override
  String dashboard_gauges_dataIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemas de dados',
      one: '1 problema de dados',
    );
    return '$_temp0';
  }

  @override
  String get dashboard_gauges_retry =>
      'Estado indisponível - toque para tentar novamente';

  @override
  String get dashboard_urgent_title => 'Requer atenção';

  @override
  String get dashboard_media_title => 'Mídia recente';

  @override
  String get dashboard_recentSites_title => 'Locais recentes';

  @override
  String get dashboard_yearInReview_title => 'Este ano';

  @override
  String dashboard_yearInReview_divesVs(int count, int previous) {
    return '$count mergulhos (vs $previous no ano passado)';
  }

  @override
  String dashboard_yearInReview_hours(String hours) {
    return '$hours horas debaixo de água';
  }

  @override
  String dashboard_yearInReview_maxDepth(String depth) {
    return 'Máxima: $depth';
  }

  @override
  String get dashboard_onThisDay_title => 'Neste dia';

  @override
  String dashboard_onThisDay_entry(String year, String site) {
    return '$year - $site';
  }

  @override
  String get dashboard_milestones_title => 'Marcos';

  @override
  String dashboard_milestones_nextDive(int remaining, int milestone) {
    return '$remaining mergulhos para o n.º $milestone';
  }

  @override
  String dashboard_milestones_certYears(String name, int years, String month) {
    return '$name: $years anos em $month';
  }

  @override
  String get dashboard_personalRecords_coldest => 'Mais Frio';

  @override
  String get dashboard_personalRecords_deepest => 'Mais Profundo';

  @override
  String get dashboard_personalRecords_longest => 'Mais Longo';

  @override
  String get dashboard_personalRecords_sectionTitle => 'Recordes Pessoais';

  @override
  String get dashboard_personalRecords_warmest => 'Mais Quente';

  @override
  String get dashboard_quickActions_addSite => 'Adicionar Ponto';

  @override
  String get dashboard_quickActions_addSiteTooltip =>
      'Adicionar um novo ponto de mergulho';

  @override
  String get dashboard_quickActions_logDive => 'Registrar Mergulho';

  @override
  String get dashboard_quickActions_logDiveTooltip =>
      'Registrar um novo mergulho';

  @override
  String get dashboard_quickActions_planDive => 'Planejar Mergulho';

  @override
  String get dashboard_quickActions_planDiveTooltip =>
      'Planejar um novo mergulho';

  @override
  String get dashboard_quickActions_sectionTitle => 'Acoes Rapidas';

  @override
  String get dashboard_quickActions_statistics => 'Estatisticas';

  @override
  String get dashboard_quickActions_statisticsTooltip =>
      'Ver estatisticas de mergulho';

  @override
  String get dashboard_quickStats_countries => 'Paises';

  @override
  String get dashboard_quickStats_countriesSubtitle => 'visitados';

  @override
  String get dashboard_quickStats_sectionTitle => 'Resumo Geral';

  @override
  String get dashboard_quickStats_species => 'Especies';

  @override
  String get dashboard_quickStats_speciesSubtitle => 'descobertas';

  @override
  String get dashboard_quickStats_topBuddy => 'Melhor Dupla';

  @override
  String dashboard_quickStats_topBuddyDives(Object count) {
    return '$count mergulhos';
  }

  @override
  String get dashboard_recentDives_empty => 'Nenhum mergulho registrado ainda';

  @override
  String get dashboard_recentDives_errorLoading =>
      'Falha ao carregar mergulhos';

  @override
  String get dashboard_recentDives_latestProfileTitle =>
      'Perfil do último mergulho';

  @override
  String get dashboard_recentDives_noProfileData =>
      'Sem dados de perfil para este mergulho';

  @override
  String get dashboard_recentDives_profileLoadError =>
      'Não foi possível carregar o perfil do mergulho';

  @override
  String dashboard_recentDives_profileMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get dashboard_recentDives_logFirst => 'Registre Seu Primeiro Mergulho';

  @override
  String get dashboard_recentDives_sectionTitle => 'Mergulhos Recentes';

  @override
  String get dashboard_recentDives_viewAll => 'Ver Todos';

  @override
  String get dashboard_recentDives_viewAllTooltip => 'Ver todos os mergulhos';

  @override
  String dashboard_semantics_activeAlerts(Object count) {
    return '$count alertas ativos';
  }

  @override
  String get dashboard_semantics_errorLoadingRecentDives =>
      'Erro: Falha ao carregar mergulhos recentes';

  @override
  String get dashboard_semantics_errorLoadingStatistics =>
      'Erro: Falha ao carregar estatisticas';

  @override
  String get dashboard_semantics_greetingBanner =>
      'Banner de saudacao do painel';

  @override
  String get dashboard_stats_errorLoadingStatistics =>
      'Falha ao carregar estatisticas';

  @override
  String get dashboard_stats_hoursLogged => 'Horas Registradas';

  @override
  String get dashboard_stats_maxDepth => 'Profundidade Maxima';

  @override
  String get dashboard_stats_sitesVisited => 'Pontos Visitados';

  @override
  String get dashboard_stats_totalDives => 'Total de Mergulhos';

  @override
  String get decoCalculator_addToPlanner => 'Adicionar ao Planejador';

  @override
  String decoCalculator_bottomTimeSemantics(Object time) {
    return 'Tempo de fundo: $time minutos';
  }

  @override
  String get decoCalculator_createPlanTooltip =>
      'Criar um plano de mergulho a partir dos parâmetros atuais';

  @override
  String decoCalculator_createdPlanSnackbar(
    Object depth,
    Object depthSymbol,
    Object time,
    Object gasMixName,
  ) {
    return 'Plano criado: $depth$depthSymbol por ${time}min em $gasMixName';
  }

  @override
  String get decoCalculator_customMixTrimix => 'Mistura Personalizada (Trimix)';

  @override
  String decoCalculator_depthSemantics(Object depth, Object depthSymbol) {
    return 'Profundidade: $depth $depthSymbol';
  }

  @override
  String get decoCalculator_diveParameters => 'Parâmetros do Mergulho';

  @override
  String get decoCalculator_endCaution => 'Cuidado';

  @override
  String get decoCalculator_endDanger => 'Perigo';

  @override
  String get decoCalculator_endSafe => 'Seguro';

  @override
  String get decoCalculator_field_bottomTime => 'Tempo de Fundo';

  @override
  String get decoCalculator_field_depth => 'Profundidade';

  @override
  String get decoCalculator_field_gasMix => 'Mistura de Gás';

  @override
  String get decoCalculator_gasSafety => 'Segurança do Gás';

  @override
  String get decoCalculator_hideCustomMix => 'Ocultar Mistura Personalizada';

  @override
  String get decoCalculator_hideCustomMixSemantics =>
      'Ocultar seletor de mistura de gás personalizada';

  @override
  String get decoCalculator_modExceeded => 'MOD Excedida';

  @override
  String get decoCalculator_modSafe => 'MOD Segura';

  @override
  String get decoCalculator_ppO2Caution => 'ppO2 Cuidado';

  @override
  String get decoCalculator_ppO2Danger => 'ppO2 Perigo';

  @override
  String get decoCalculator_ppO2Hypoxic => 'ppO2 Hipóxico';

  @override
  String get decoCalculator_ppO2Safe => 'ppO2 Seguro';

  @override
  String get decoCalculator_resetToDefaults => 'Restaurar padrões';

  @override
  String get decoCalculator_showCustomMixSemantics =>
      'Mostrar seletor de mistura de gás personalizada';

  @override
  String decoCalculator_timeValueMin(Object time) {
    return '$time min';
  }

  @override
  String get decoCalculator_title => 'Calculadora de Descompressão';

  @override
  String get decoCalculator_waterType => 'Tipo de água';

  @override
  String get decoCalculator_waterType_standard => 'Padrão';

  @override
  String diveCenters_accessibility_markerLabel(Object name) {
    return 'Centro de mergulho: $name';
  }

  @override
  String get diveCenters_accessibility_selected => 'selecionado';

  @override
  String diveCenters_accessibility_viewDetails(Object name) {
    return 'Ver detalhes de $name';
  }

  @override
  String get diveCenters_accessibility_viewDives =>
      'Ver mergulhos com este centro';

  @override
  String get diveCenters_accessibility_viewFullscreenMap =>
      'Ver mapa em tela cheia';

  @override
  String diveCenters_accessibility_viewSavedCenter(Object name) {
    return 'Ver centro de mergulho salvo $name';
  }

  @override
  String get diveCenters_action_addCenter => 'Adicionar Centro';

  @override
  String get diveCenters_action_addNew => 'Adicionar Novo';

  @override
  String get diveCenters_action_clearRating => 'Limpar';

  @override
  String get diveCenters_action_gettingLocation => 'Obtendo...';

  @override
  String get diveCenters_action_import => 'Importar';

  @override
  String get diveCenters_action_importToMyCenters =>
      'Importar para Meus Centros';

  @override
  String get diveCenters_action_lookingUp => 'Consultando...';

  @override
  String get diveCenters_action_lookupFromAddress =>
      'Consultar a partir do Endereço';

  @override
  String get diveCenters_action_pickFromMap => 'Escolher no Mapa';

  @override
  String get diveCenters_action_retry => 'Tentar novamente';

  @override
  String get diveCenters_action_settings => 'Configurações';

  @override
  String get diveCenters_action_useMyLocation => 'Usar Minha Localização';

  @override
  String get diveCenters_action_view => 'Ver';

  @override
  String diveCenters_detail_divesLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos registrados',
      one: '1 mergulho registrado',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_detail_divesWithCenter => 'Mergulhos com este Centro';

  @override
  String get diveCenters_detail_noDivesLogged =>
      'Nenhum mergulho registrado ainda';

  @override
  String diveCenters_dialog_deleteMessage(Object name) {
    return 'Tem certeza de que deseja excluir \"$name\"?';
  }

  @override
  String get diveCenters_dialog_deleteTitle => 'Excluir Centro de Mergulho';

  @override
  String get diveCenters_dialog_discard => 'Descartar';

  @override
  String get diveCenters_dialog_discardMessage =>
      'Você tem alterações não salvas. Tem certeza de que deseja descartá-las?';

  @override
  String get diveCenters_dialog_discardTitle => 'Descartar Alterações?';

  @override
  String get diveCenters_dialog_keepEditing => 'Continuar Editando';

  @override
  String get diveCenters_empty_button =>
      'Adicione seu primeiro centro de mergulho';

  @override
  String get diveCenters_empty_subtitle =>
      'Adicione suas lojas e operadores de mergulho favoritos';

  @override
  String get diveCenters_empty_title => 'Nenhum centro de mergulho ainda';

  @override
  String diveCenters_error_generic(Object error) {
    return 'Erro: $error';
  }

  @override
  String get diveCenters_error_geocodeFailed =>
      'Não foi possível encontrar as coordenadas para este endereço';

  @override
  String get diveCenters_error_importFailed =>
      'Falha ao importar centro de mergulho';

  @override
  String diveCenters_error_loading(Object error) {
    return 'Erro ao carregar centros de mergulho: $error';
  }

  @override
  String get diveCenters_error_locationPermission =>
      'Não foi possível obter a localização. Verifique as permissões.';

  @override
  String get diveCenters_error_locationUnavailable =>
      'Não foi possível obter a localização. Os serviços de localização podem não estar disponíveis.';

  @override
  String get diveCenters_error_noAddressForLookup =>
      'Digite um endereço para consultar as coordenadas';

  @override
  String get diveCenters_error_notFound => 'Centro de mergulho não encontrado';

  @override
  String diveCenters_error_saving(Object error) {
    return 'Erro ao salvar centro de mergulho: $error';
  }

  @override
  String get diveCenters_error_unknown => 'Erro desconhecido';

  @override
  String get diveCenters_field_city => 'Cidade';

  @override
  String get diveCenters_field_country => 'País';

  @override
  String get diveCenters_field_latitude => 'Latitude';

  @override
  String get diveCenters_field_longitude => 'Longitude';

  @override
  String get diveCenters_field_nameRequired => 'Nome *';

  @override
  String get diveCenters_field_postalCode => 'Código Postal';

  @override
  String get diveCenters_field_rating => 'Avaliação';

  @override
  String get diveCenters_field_stateProvince => 'Estado/Província';

  @override
  String get diveCenters_field_street => 'Endereço';

  @override
  String get diveCenters_hint_addressDescription =>
      'Endereço opcional para navegação';

  @override
  String get diveCenters_hint_affiliationsDescription =>
      'Selecione as agências de treinamento com as quais este centro é afiliado';

  @override
  String get diveCenters_hint_city => 'ex: Phuket';

  @override
  String get diveCenters_hint_country => 'ex: Tailândia';

  @override
  String get diveCenters_hint_email => 'info@centrodemergulho.com';

  @override
  String get diveCenters_hint_gpsDescription =>
      'Escolha um método de localização ou digite as coordenadas manualmente';

  @override
  String get diveCenters_hint_importSearch =>
      'Buscar centros de mergulho (ex: \"PADI\", \"Tailândia\")';

  @override
  String get diveCenters_hint_latitude => 'ex: 10.4613';

  @override
  String get diveCenters_hint_longitude => 'ex: 99.8359';

  @override
  String get diveCenters_hint_name => 'Digite o nome do centro de mergulho';

  @override
  String get diveCenters_hint_notes => 'Qualquer informação adicional...';

  @override
  String get diveCenters_hint_phone => '+55 11 98765-4321';

  @override
  String get diveCenters_hint_postalCode => 'ex: 83100';

  @override
  String get diveCenters_hint_stateProvince => 'ex: Phuket';

  @override
  String get diveCenters_hint_street => 'ex: Rua da Praia, 123';

  @override
  String get diveCenters_hint_website => 'www.centrodemergulho.com';

  @override
  String diveCenters_import_fromDatabase(Object count) {
    return 'Importar do Banco de Dados ($count)';
  }

  @override
  String diveCenters_import_myCenters(Object count) {
    return 'Meus Centros ($count)';
  }

  @override
  String get diveCenters_import_noResults => 'Nenhum Resultado';

  @override
  String diveCenters_import_noResultsMessage(Object query) {
    return 'Nenhum centro de mergulho encontrado para \"$query\". Tente um termo de busca diferente.';
  }

  @override
  String get diveCenters_import_searchDescription =>
      'Busque centros de mergulho, lojas e clubes em nosso banco de dados de operadores ao redor do mundo.';

  @override
  String get diveCenters_import_searchError => 'Erro na Busca';

  @override
  String get diveCenters_import_searchHint =>
      'Tente buscar por nome, país ou agência certificadora.';

  @override
  String get diveCenters_import_searchTitle => 'Buscar Centros de Mergulho';

  @override
  String get diveCenters_label_alreadyImported => 'Já Importado';

  @override
  String diveCenters_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos',
      one: '1 mergulho',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_label_email => 'E-mail';

  @override
  String get diveCenters_label_imported => 'Importado';

  @override
  String get diveCenters_label_locationNotSet => 'Localização não definida';

  @override
  String get diveCenters_label_locationUnknown => 'Localização desconhecida';

  @override
  String get diveCenters_label_phone => 'Telefone';

  @override
  String get diveCenters_label_saved => 'Salvo';

  @override
  String diveCenters_label_source(Object source) {
    return 'Fonte: $source';
  }

  @override
  String get diveCenters_label_website => 'Site';

  @override
  String get diveCenters_map_addCoordinatesHint =>
      'Adicione coordenadas aos seus centros de mergulho para vê-los no mapa';

  @override
  String get diveCenters_map_noCoordinates =>
      'Nenhum centro de mergulho com coordenadas';

  @override
  String get diveCenters_picker_newCenter => 'Novo Centro de Mergulho';

  @override
  String get diveCenters_picker_title => 'Selecionar Centro de Mergulho';

  @override
  String diveCenters_search_noResults(Object query) {
    return 'Nenhum resultado para \"$query\"';
  }

  @override
  String get diveCenters_search_prompt => 'Buscar centros de mergulho';

  @override
  String get diveCenters_section_address => 'Endereço';

  @override
  String get diveCenters_section_affiliations => 'Afiliações';

  @override
  String get diveCenters_section_basicInfo => 'Informações Básicas';

  @override
  String get diveCenters_section_contact => 'Contato';

  @override
  String get diveCenters_section_contactInfo => 'Informações de Contato';

  @override
  String get diveCenters_section_gpsCoordinates => 'Coordenadas GPS';

  @override
  String get diveCenters_section_notes => 'Notas';

  @override
  String get diveCenters_snackbar_coordinatesFound =>
      'Coordenadas encontradas a partir do endereço';

  @override
  String get diveCenters_snackbar_copiedToClipboard =>
      'Copiado para a área de transferência';

  @override
  String diveCenters_snackbar_imported(Object name) {
    return 'Importado \"$name\"';
  }

  @override
  String get diveCenters_snackbar_locationCaptured => 'Localização capturada';

  @override
  String diveCenters_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Localização capturada (±${accuracy}m)';
  }

  @override
  String get diveCenters_snackbar_locationSelectedFromMap =>
      'Localização selecionada no mapa';

  @override
  String get diveCenters_sort_title => 'Ordenar Centros de Mergulho';

  @override
  String get diveCenters_summary_countries => 'Países';

  @override
  String get diveCenters_summary_highestRating => 'Maior Avaliação';

  @override
  String get diveCenters_summary_overview => 'Visão Geral';

  @override
  String get diveCenters_summary_quickActions => 'Ações Rápidas';

  @override
  String get diveCenters_summary_recentCenters =>
      'Centros de Mergulho Recentes';

  @override
  String get diveCenters_summary_selectPrompt =>
      'Selecione um centro de mergulho da lista para ver os detalhes';

  @override
  String get diveCenters_summary_totalCenters => 'Total de Centros';

  @override
  String get diveCenters_summary_withGps => 'Com GPS';

  @override
  String get diveCenters_title => 'Centros de Mergulho';

  @override
  String get diveCenters_title_add => 'Adicionar Centro de Mergulho';

  @override
  String get diveCenters_title_edit => 'Editar Centro de Mergulho';

  @override
  String get diveCenters_title_import => 'Importar Centro de Mergulho';

  @override
  String get diveCenters_tooltip_addNew =>
      'Adicionar um novo centro de mergulho';

  @override
  String get diveCenters_tooltip_clearSearch => 'Limpar busca';

  @override
  String get diveCenters_tooltip_edit => 'Editar centro de mergulho';

  @override
  String get diveCenters_tooltip_fitAllCenters => 'Ajustar Todos os Centros';

  @override
  String get diveCenters_tooltip_listView => 'Visualização em Lista';

  @override
  String get diveCenters_tooltip_mapView => 'Visualização em Mapa';

  @override
  String get diveCenters_tooltip_moreOptions => 'Mais opções';

  @override
  String get diveCenters_tooltip_search => 'Buscar centros de mergulho';

  @override
  String get diveCenters_tooltip_sort => 'Ordenar';

  @override
  String get diveCenters_validation_invalidEmail => 'Digite um e-mail válido';

  @override
  String get diveCenters_validation_invalidLatitude => 'Latitude inválida';

  @override
  String get diveCenters_validation_invalidLongitude => 'Longitude inválida';

  @override
  String get diveCenters_validation_nameRequired => 'Nome é obrigatório';

  @override
  String get diveComputer_action_setFavorite => 'Definir como favorito';

  @override
  String diveComputer_error_generic(Object error) {
    return 'Ocorreu um erro: $error';
  }

  @override
  String get diveComputer_error_notFound => 'Dispositivo não encontrado';

  @override
  String get diveComputer_status_favorite => 'Computador favorito';

  @override
  String get diveComputer_title => 'Computador de Mergulho';

  @override
  String diveLog_bulkDelete_confirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mergulhos',
      one: 'mergulho',
    );
    return 'Tem certeza que deseja excluir $count $_temp0? Esta acao nao pode ser desfeita.';
  }

  @override
  String get diveLog_bulkDelete_restored => 'Mergulhos restaurados';

  @override
  String diveLog_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mergulhos excluidos',
      one: 'mergulho excluido',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_bulkDelete_title => 'Excluir Mergulhos';

  @override
  String get diveLog_bulkDelete_undo => 'Desfazer';

  @override
  String get diveLog_bulkEdit_addTags => 'Adicionar Tags';

  @override
  String get diveLog_bulkEdit_addTagsDescription =>
      'Adicionar tags aos mergulhos selecionados';

  @override
  String diveLog_bulkEdit_addedTags(int tagCount, int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      tagCount,
      locale: localeName,
      other: '$tagCount tags adicionadas',
      one: 'Tag adicionada',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'mergulhos',
      one: 'mergulho',
    );
    return '$_temp0 a $diveCount $_temp1';
  }

  @override
  String get diveLog_bulkEdit_changeTrip => 'Alterar Viagem';

  @override
  String get diveLog_bulkEdit_changeTripDescription =>
      'Mover mergulhos selecionados para uma viagem';

  @override
  String get diveLog_bulkEdit_errorLoadingTrips => 'Erro ao carregar viagens';

  @override
  String diveLog_bulkEdit_failedAddTags(Object error) {
    return 'Falha ao adicionar tags: $error';
  }

  @override
  String diveLog_bulkEdit_failedUpdateTrip(Object error) {
    return 'Falha ao atualizar viagem: $error';
  }

  @override
  String diveLog_bulkEdit_movedToTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mergulhos movidos',
      one: 'mergulho movido',
    );
    return '$count $_temp0 para a viagem';
  }

  @override
  String get diveLog_bulkEdit_noTagsAvailable => 'Nenhuma tag disponivel.';

  @override
  String get diveLog_bulkEdit_noTagsAvailableCreate =>
      'Nenhuma tag disponivel. Crie tags primeiro.';

  @override
  String get diveLog_bulkEdit_noTrip => 'Sem Viagem';

  @override
  String get diveLog_bulkEdit_removeFromTrip => 'Remover da viagem';

  @override
  String get diveLog_bulkEdit_removeTags => 'Remover Tags';

  @override
  String get diveLog_bulkEdit_removeTagsDescription =>
      'Remover tags dos mergulhos selecionados';

  @override
  String diveLog_bulkEdit_removedFromTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mergulhos removidos',
      one: 'mergulho removido',
    );
    return '$count $_temp0 da viagem';
  }

  @override
  String get diveLog_bulkEdit_selectTrip => 'Selecionar Viagem';

  @override
  String diveLog_bulkEdit_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mergulhos',
      one: 'Mergulho',
    );
    return 'Editar $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_csv => 'CSV';

  @override
  String get diveLog_bulkExport_csvDescription => 'Formato de planilha';

  @override
  String diveLog_bulkExport_failed(Object error) {
    return 'Exportacao falhou: $error';
  }

  @override
  String get diveLog_bulkExport_pdf => 'PDF Logbook';

  @override
  String get diveLog_bulkExport_pdfDescription =>
      'Paginas imprimiveis do log de mergulho';

  @override
  String diveLog_bulkExport_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mergulhos exportados',
      one: 'mergulho exportado',
    );
    return '$count $_temp0 com sucesso';
  }

  @override
  String diveLog_bulkExport_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mergulhos',
      one: 'Mergulho',
    );
    return 'Exportar $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_uddf => 'UDDF';

  @override
  String get diveLog_bulkExport_uddfDescription =>
      'Formato Universal de Dados de Mergulho';

  @override
  String get diveLog_ccr_diluent_air => 'Ar';

  @override
  String get diveLog_ccr_hint_loopVolume => 'ex., 6.0';

  @override
  String get diveLog_ccr_hint_type => 'ex., Sofnolime';

  @override
  String get diveLog_ccr_label_deco => 'Deco';

  @override
  String get diveLog_ccr_label_he => 'He';

  @override
  String get diveLog_ccr_label_highBottom => 'Alto (Fundo)';

  @override
  String get diveLog_ccr_label_loopVolume => 'Volume do Loop';

  @override
  String get diveLog_ccr_label_lowDescAsc => 'Baixo (Desc/Sub)';

  @override
  String get diveLog_ccr_label_n2 => 'N₂';

  @override
  String get diveLog_ccr_label_o2 => 'O₂';

  @override
  String get diveLog_ccr_label_rated => 'Capacidade';

  @override
  String get diveLog_ccr_label_remaining => 'Restante';

  @override
  String get diveLog_ccr_label_type => 'Tipo';

  @override
  String get diveLog_ccr_sectionDiluentGas => 'Gas Diluente';

  @override
  String get diveLog_ccr_sectionScrubber => 'Scrubber';

  @override
  String get diveLog_ccr_sectionSetpoints => 'Setpoints (bar)';

  @override
  String get diveLog_ccr_title => 'Configuracoes CCR';

  @override
  String diveLog_collapsible_semantics_collapse(Object title) {
    return 'Recolher secao $title';
  }

  @override
  String diveLog_collapsible_semantics_expand(Object title) {
    return 'Expandir secao $title';
  }

  @override
  String get diveLog_combine_confirm => 'Combinar em um mergulho';

  @override
  String get diveLog_combine_dataNote =>
      'Os detalhes vêm do mergulho mais antigo, com os espaços em branco preenchidos pelos mergulhos posteriores. As notas são combinadas. Cilindros, equipamentos, parceiros, tags e avistamentos são todos mantidos.';

  @override
  String get diveLog_combine_error =>
      'Não foi possível combinar os mergulhos. Nada foi alterado.';

  @override
  String diveLog_combine_gapLabel(String duration) {
    return 'Intervalo de superfície: $duration';
  }

  @override
  String get diveLog_combine_longSurfaceWarning =>
      'Um ou mais intervalos de superfície são maiores que 30 minutos. Podem ser mergulhos separados em vez de um único mergulho contínuo.';

  @override
  String get diveLog_combine_mixedDivers =>
      'Os mergulhos selecionados pertencem a mergulhadores diferentes e não podem ser combinados.';

  @override
  String get diveLog_combine_profilePreview => 'Perfil combinado';

  @override
  String diveLog_combine_previewIntro(int count) {
    return 'Estes $count mergulhos serão combinados em um único mergulho contínuo. Os intervalos entre eles se tornam tempo de superfície.';
  }

  @override
  String diveLog_combine_resultSummary(
    String runtime,
    String maxDepth,
    String bottomTime,
  ) {
    return 'Resultado: $runtime no total, profundidade máxima $maxDepth, tempo de fundo $bottomTime';
  }

  @override
  String diveLog_combine_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mergulhos combinados',
      one: 'mergulho combinado',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_combine_title => 'Combinar mergulhos';

  @override
  String get diveLog_combine_undoError =>
      'Não foi possível desfazer a combinação.';

  @override
  String get diveLog_combine_undone => 'Combinação desfeita';

  @override
  String get diveLog_computerSource_badge_primary => 'Principal';

  @override
  String get diveLog_consolidate_confirm =>
      'Manter como um único mergulho com os dois computadores';

  @override
  String get diveLog_consolidate_error_generic =>
      'Não foi possível mesclar os mergulhos. Nada foi alterado.';

  @override
  String get diveLog_consolidate_error_notOverlapping =>
      'Esses mergulhos não se sobrepõem no tempo, portanto não podem ser mesclados como o mesmo mergulho.';

  @override
  String get diveLog_consolidate_error_sameComputer =>
      'Esses mergulhos são do mesmo computador de mergulho e não podem ser mesclados dessa forma.';

  @override
  String get diveLog_consolidate_selectPrimary =>
      'Computador de mergulho principal';

  @override
  String get diveLog_consolidate_snackbar =>
      'Mergulho mesclado como computador adicional.';

  @override
  String get diveLog_consolidate_undoError =>
      'Não foi possível desfazer a mesclagem.';

  @override
  String get diveLog_consolidate_undone => 'Mesclagem desfeita';

  @override
  String diveLog_mergeDialog_confirmSubtitle(String time) {
    return 'O mergulho às $time será mesclado a este mergulho.';
  }

  @override
  String get diveLog_mergeDialog_confirmTitle => 'Confirmar mesclagem';

  @override
  String get diveLog_mergeDialog_empty =>
      'Nenhum outro mergulho encontrado neste dia.';

  @override
  String get diveLog_mergeDialog_explanation =>
      'O perfil, os cilindros, as pressões, os eventos, as tags, os parceiros e os avistamentos deste mergulho serão incorporados a este mergulho como uma fonte de computador adicional. Esta ação pode ser revertida com \'Desvincular computador\'.';

  @override
  String diveLog_mergeDialog_loadError(String error) {
    return 'Erro ao carregar os mergulhos: $error';
  }

  @override
  String get diveLog_mergeDialog_merge => 'Mesclar';

  @override
  String get diveLog_mergeDialog_next => 'Próximo';

  @override
  String get diveLog_mergeDialog_subtitle =>
      'Selecione um mergulho do mesmo dia para mesclar como um computador adicional.';

  @override
  String get diveLog_mergeDialog_title => 'Mesclar com outro mergulho';

  @override
  String get diveLog_mergeDialog_whatThisDoes => 'O que isso faz';

  @override
  String get diveLog_computerSheet_description =>
      'Selecione de qual perfil de computador editar.';

  @override
  String get diveLog_computerSheet_title => 'Escolher perfil inicial';

  @override
  String diveLog_cylinderSac_avgDepth(Object depth) {
    return 'Media: $depth';
  }

  @override
  String get diveLog_cylinderSac_badge_ai => 'AI';

  @override
  String get diveLog_cylinderSac_badge_basic => 'Basico';

  @override
  String get diveLog_cylinderSac_noSac => 'SAC: --';

  @override
  String get diveLog_cylinderSac_tooltip_aiData =>
      'Usando dados do transmissor AI para maior precisao';

  @override
  String get diveLog_cylinderSac_tooltip_basicData =>
      'Calculado a partir das pressoes inicial/final';

  @override
  String get diveLog_deco_badge_deco => 'DECO';

  @override
  String get diveLog_deco_badge_noDeco => 'SEM DECO';

  @override
  String get diveLog_deco_label_ceiling => 'Teto';

  @override
  String get diveLog_deco_label_leading => 'Predominante';

  @override
  String get diveLog_deco_label_gf99 => 'GF99';

  @override
  String get diveLog_deco_label_surfGf => 'SurfGF';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_time => 'Tempo';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String diveLog_deco_gf_chip(Object low, Object high) {
    return 'GF: $low/$high';
  }

  @override
  String diveLog_deco_gf_chipFromSettings(Object low, Object high) {
    return 'GF: $low/$high · as suas definições';
  }

  @override
  String diveLog_deco_gf_chipRecordedAlgorithm(
    Object algorithm,
    Object low,
    Object high,
  ) {
    return '$algorithm · analisado com GF $low/$high';
  }

  @override
  String diveLog_deco_gf_semantics(Object low, Object high) {
    return 'Fatores de gradiente: baixo $low, alto $high';
  }

  @override
  String get diveLog_deco_gf_tooltipFromSettings =>
      'Este computador de mergulho não registou os seus fatores de gradiente, por isso este mergulho é analisado com os das suas definições.';

  @override
  String diveLog_deco_gf_tooltipRecordedAlgorithm(Object algorithm) {
    return 'Este mergulho foi calculado com $algorithm, que não usa fatores de gradiente. O Submersion analisa-o com os das suas definições.';
  }

  @override
  String get diveLog_deco_sectionDecoStops => 'Paradas Deco';

  @override
  String get diveLog_deco_sectionTissueLoading => 'Carga Tecidual';

  @override
  String get diveLog_deco_semantics_notRequired =>
      'Descompressao nao necessaria';

  @override
  String get diveLog_deco_semantics_required => 'Descompressao necessaria';

  @override
  String get diveLog_deco_tissueFast => 'Rapido';

  @override
  String get diveLog_deco_tissueSlow => 'Lento';

  @override
  String get diveLog_deco_title => 'Status Deco';

  @override
  String diveLog_deco_totalDecoTime(Object time) {
    return 'Total: $time';
  }

  @override
  String get diveLog_delete_cancel => 'Cancelar';

  @override
  String get diveLog_delete_confirm =>
      'Esta acao nao pode ser desfeita. O mergulho e todos os dados associados (perfil, cilindros, avistamentos) serao excluidos permanentemente.';

  @override
  String get diveLog_delete_delete => 'Excluir';

  @override
  String get diveLog_delete_title => 'Excluir Mergulho?';

  @override
  String get diveLog_detail_appBar => 'Detalhes do Mergulho';

  @override
  String get diveLog_detail_badge_critical => 'CRITICO';

  @override
  String get diveLog_detail_badge_deco => 'DECO';

  @override
  String get diveLog_detail_badge_noDeco => 'SEM DECO';

  @override
  String get diveLog_detail_badge_warning => 'AVISO';

  @override
  String diveLog_detail_buddyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'duplas',
      one: 'dupla',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_button_playback => 'Reproducao';

  @override
  String get diveLog_detail_button_rangeAnalysis => 'Stats de Intervalo';

  @override
  String get diveLog_detail_button_showEnd => 'Mostrar final';

  @override
  String get diveLog_detail_captureSignature =>
      'Capturar Assinatura do Instrutor';

  @override
  String diveLog_detail_collapsed_atTime(Object timestamp) {
    return 'Às $timestamp';
  }

  @override
  String diveLog_detail_collapsed_atTimeInfo(
    Object timestamp,
    Object baseInfo,
  ) {
    return 'Às $timestamp • $baseInfo';
  }

  @override
  String diveLog_detail_collapsed_ceiling(Object value) {
    return 'Teto: $value';
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
    return 'CNS: $cns • Máx ppO₂: $maxPpO2 • Às $timestamp: $ppO2 bar';
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
      other: 'itens',
      one: 'item',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_errorLoading => 'Erro ao carregar mergulho';

  @override
  String get diveLog_detail_label_airTemp => 'Temp do Ar';

  @override
  String get diveLog_detail_label_avgDepth => 'Prof. Media';

  @override
  String get diveLog_detail_label_buddy => 'Dupla';

  @override
  String get diveLog_detail_label_currentDirection => 'Direcao da Corrente';

  @override
  String get diveLog_detail_label_currentStrength => 'Forca da Corrente';

  @override
  String get diveLog_detail_label_diveComputer => 'Computador de Mergulho';

  @override
  String get diveLog_detail_label_serialNumber => 'Numero de serie';

  @override
  String get diveLog_detail_label_firmwareVersion => 'Versao do firmware';

  @override
  String get diveLog_detail_label_diveMaster => 'Dive Master';

  @override
  String get diveLog_detail_label_diveType => 'Tipo de Mergulho';

  @override
  String get diveLog_detail_label_elevation => 'Elevacao';

  @override
  String get diveLog_detail_label_entry => 'Entrada:';

  @override
  String get diveLog_detail_label_entryMethod => 'Metodo de Entrada';

  @override
  String get diveLog_detail_label_exit => 'Saida:';

  @override
  String get diveLog_detail_label_exitMethod => 'Metodo de Saida';

  @override
  String get diveLog_detail_label_gradientFactors => 'Fatores de Gradiente';

  @override
  String get diveLog_detail_label_height => 'Altura';

  @override
  String get diveLog_detail_label_highTide => 'Mare Alta';

  @override
  String get diveLog_detail_label_lowTide => 'Mare Baixa';

  @override
  String get diveLog_detail_label_ppO2AtPoint => 'ppO₂ no ponto selecionado:';

  @override
  String get diveLog_detail_label_rateOfChange => 'Taxa de Variacao';

  @override
  String get diveLog_detail_label_sacRate => 'Taxa SAC';

  @override
  String get diveLog_detail_label_state => 'Estado';

  @override
  String get diveLog_detail_label_surfaceInterval => 'Intervalo de Superficie';

  @override
  String get diveLog_detail_label_surfacePressure => 'Pressao de Superficie';

  @override
  String get diveLog_detail_label_swellHeight => 'Altura da Ondulacao';

  @override
  String get diveLog_detail_label_total => 'Total:';

  @override
  String get diveLog_detail_label_visibility => 'Visibilidade';

  @override
  String get diveLog_detail_label_waterType => 'Tipo de Agua';

  @override
  String get diveLog_detail_menu_delete => 'Excluir';

  @override
  String get diveLog_detail_menu_export => 'Exportar';

  @override
  String get diveLog_detail_menu_openFullPage => 'Abrir Pagina Completa';

  @override
  String get diveLog_detail_noNotes => 'Sem anotacoes para este mergulho.';

  @override
  String get diveLog_detail_notFound => 'Mergulho nao encontrado';

  @override
  String diveLog_detail_profilePoints(Object count) {
    return '$count pontos';
  }

  @override
  String get diveLog_detail_section_altitudeDive => 'Mergulho em Altitude';

  @override
  String get diveLog_detail_section_buddies => 'Duplas';

  @override
  String get diveLog_detail_section_conditions => 'Condicoes';

  @override
  String get diveLog_detail_section_customFields => 'Custom Fields';

  @override
  String get diveLog_detail_section_decoStatus => 'Status Deco';

  @override
  String get diveLog_detail_section_details => 'Detalhes';

  @override
  String get diveLog_detail_section_diveProfile => 'Perfil do Mergulho';

  @override
  String get diveLog_detail_section_equipment => 'Equipamentos';

  @override
  String get diveLog_detail_section_marineLife => 'Vida Marinha';

  @override
  String get diveLog_detail_section_notes => 'Anotacoes';

  @override
  String get diveLog_detail_section_oxygenToxicity => 'Toxicidade de Oxigenio';

  @override
  String get diveLog_detail_section_sacRateBySegment => 'Taxa SAC por Segmento';

  @override
  String get diveLog_detail_section_tags => 'Tags';

  @override
  String get diveLog_detail_section_cylinders => 'Cilindros';

  @override
  String get diveLog_detail_section_tide => 'Mare';

  @override
  String get diveLog_detail_section_trainingSignature =>
      'Assinatura de Treinamento';

  @override
  String get diveLog_detail_section_weight => 'Lastro';

  @override
  String get diveLog_detail_signatureDescription =>
      'Toque para adicionar verificacao do instrutor para este mergulho de treinamento';

  @override
  String get diveLog_detail_soloDive =>
      'Mergulho solo ou sem duplas registradas';

  @override
  String diveLog_detail_speciesCount(Object count) {
    return '$count especies';
  }

  @override
  String get diveLog_detail_stat_bottomTime => 'Tempo de Fundo';

  @override
  String get diveLog_detail_stat_maxDepth => 'Prof. Maxima';

  @override
  String get diveLog_detail_stat_runtime => 'Tempo Total';

  @override
  String get diveLog_detail_stat_waterTemp => 'Temp da Agua';

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
  String get diveLog_detail_tideCalculated =>
      'Calculado a partir do modelo de mares';

  @override
  String get diveLog_detail_tooltip_addToFavorites => 'Adicionar aos favoritos';

  @override
  String get diveLog_detail_tooltip_edit => 'Editar';

  @override
  String get diveLog_detail_tooltip_editDive => 'Editar mergulho';

  @override
  String get diveLog_detail_tooltip_previousDive => 'Previous dive';

  @override
  String get diveLog_detail_tooltip_nextDive => 'Next dive';

  @override
  String get diveLog_detail_tooltip_exportProfileImage =>
      'Exportar perfil como imagem';

  @override
  String get diveLog_detail_tooltip_removeFromFavorites =>
      'Remover dos favoritos';

  @override
  String get diveLog_detail_tooltip_viewFullscreen => 'Ver em tela cheia';

  @override
  String get diveLog_detail_viewSite => 'Ver Ponto de Mergulho';

  @override
  String get diveLog_diveMode_ccrDescription =>
      'Rebreather de circuito fechado com ppO₂ constante';

  @override
  String get diveLog_diveMode_gaugeDescription =>
      'Apenas profundidade e tempo; sem rastreamento de gás ou descompressão';

  @override
  String get diveLog_diveMode_ocDescription =>
      'Mergulho padrao em circuito aberto com cilindros';

  @override
  String get diveLog_diveMode_scrDescription =>
      'Rebreather semi-fechado com ppO₂ variavel';

  @override
  String get diveLog_diveMode_title => 'Modo de Mergulho';

  @override
  String get diveLog_editSighting_count => 'Quantidade';

  @override
  String get diveLog_editSighting_notes => 'Anotacoes';

  @override
  String get diveLog_editSighting_notesHint =>
      'Tamanho, comportamento, localizacao...';

  @override
  String get diveLog_editSighting_remove => 'Remover';

  @override
  String diveLog_editSighting_removeConfirm(Object name) {
    return 'Remover $name deste mergulho?';
  }

  @override
  String get diveLog_editSighting_removeTitle => 'Remover Avistamento?';

  @override
  String get diveLog_editSighting_save => 'Salvar Alteracoes';

  @override
  String get diveLog_edit_add => 'Adicionar';

  @override
  String get diveLog_edit_addCustomField => 'Add Field';

  @override
  String get diveLog_edit_addTank => 'Adicionar Cilindro';

  @override
  String get diveLog_edit_addWeightEntry => 'Adicionar Entrada de Lastro';

  @override
  String diveLog_edit_addedGps(Object name) {
    return 'GPS adicionado a $name';
  }

  @override
  String get diveLog_edit_appBarEdit => 'Editar Mergulho';

  @override
  String get diveLog_edit_appBarNew => 'Registrar Mergulho';

  @override
  String get diveLog_edit_cancel => 'Cancelar';

  @override
  String get diveLog_edit_clearAllEquipment => 'Limpar Tudo';

  @override
  String diveLog_edit_createdSite(Object name) {
    return 'Ponto criado: $name';
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
    return 'Duracao: $minutes min';
  }

  @override
  String get diveLog_edit_equipmentHint =>
      'Toque em \"Usar Conjunto\" ou \"Adicionar\" para selecionar equipamentos';

  @override
  String diveLog_edit_errorLoadingDiveTypes(Object error) {
    return 'Erro ao carregar tipos de mergulho: $error';
  }

  @override
  String get diveLog_edit_gettingLocation => 'Obtendo localizacao...';

  @override
  String get diveLog_edit_group_buddies => 'Parceiros';

  @override
  String get diveLog_edit_group_conditions => 'Condições';

  @override
  String get diveLog_edit_group_experience => 'Experiência';

  @override
  String get diveLog_edit_group_gasGear => 'Gás e equipamento';

  @override
  String get diveLog_edit_group_theDive => 'O mergulho';

  @override
  String get diveLog_edit_group_trip => 'Viagem';

  @override
  String get diveLog_edit_headerNew => 'Registrar Novo Mergulho';

  @override
  String get diveLog_edit_invite_buddies => 'Adicionar parceiros';

  @override
  String get diveLog_edit_invite_conditions =>
      'Adicionar condições: água, visibilidade, clima';

  @override
  String get diveLog_edit_invite_experience =>
      'Adicionar avaliação, avistamentos, notas ou tags';

  @override
  String get diveLog_edit_invite_gasGear =>
      'Adicionar gás e equipamento: modo, cilindros, equipamento, lastro';

  @override
  String get diveLog_edit_invite_trip =>
      'Adicionar viagem ou operadora de mergulho';

  @override
  String get diveLog_edit_label_airTemp => 'Temp do Ar';

  @override
  String get diveLog_edit_label_altitude => 'Altitude';

  @override
  String get diveLog_edit_label_avgDepth => 'Prof. Media';

  @override
  String get diveLog_edit_label_bottomTime => 'Tempo de Fundo';

  @override
  String get diveLog_edit_label_currentDirection => 'Direcao da Corrente';

  @override
  String get diveLog_edit_label_currentStrength => 'Forca da Corrente';

  @override
  String get diveLog_edit_label_diveType => 'Tipo de Mergulho';

  @override
  String get diveLog_edit_label_diveTypes => 'Tipos de mergulho';

  @override
  String get diveLog_edit_label_diveNumber => 'No. do Mergulho';

  @override
  String get diveLog_edit_label_diveName => 'Nome';

  @override
  String get diveLog_edit_diveNamePlaceholder =>
      'Nome opcional para este mergulho';

  @override
  String get diveLog_edit_hint_diveNumber =>
      'Atribuido automaticamente se deixado em branco';

  @override
  String get diveLog_edit_label_entryMethod => 'Metodo de Entrada';

  @override
  String get diveLog_edit_label_exitMethod => 'Metodo de Saida';

  @override
  String get diveLog_edit_label_maxDepth => 'Prof. Maxima';

  @override
  String get diveLog_edit_label_runtime => 'Tempo Total';

  @override
  String get diveLog_edit_label_surfacePressure => 'Pressao de Superficie';

  @override
  String get diveLog_edit_label_swellHeight => 'Altura da Ondulacao';

  @override
  String get diveLog_edit_label_type => 'Tipo';

  @override
  String get diveLog_edit_label_visibility => 'Visibilidade';

  @override
  String get diveLog_edit_label_waterTemp => 'Temp da Agua';

  @override
  String get diveLog_edit_label_waterType => 'Tipo de Agua';

  @override
  String get diveLog_edit_marineLifeHint =>
      'Toque em \"Adicionar\" para registrar avistamentos';

  @override
  String get diveLog_edit_nearbySitesFirst => 'Pontos proximos primeiro';

  @override
  String get diveLog_edit_noEquipmentSelected =>
      'Nenhum equipamento selecionado';

  @override
  String get diveLog_edit_noMarineLife => 'Nenhuma vida marinha registrada';

  @override
  String get diveLog_edit_notSpecified => 'Nao especificado';

  @override
  String get diveLog_edit_notesHint =>
      'Adicione anotacoes sobre este mergulho...';

  @override
  String get diveLog_edit_overline_tanks => 'Cilindros';

  @override
  String get diveLog_edit_profile_draw => 'Desenhar um perfil';

  @override
  String get diveLog_edit_profile_none => 'Nao registrado';

  @override
  String diveLog_edit_profile_outliers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count possiveis valores atipicos detectados',
      one: '1 possivel valor atipico detectado',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_profile_points(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pontos',
      one: '1 ponto',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_row_addSite => 'Adicionar ponto';

  @override
  String get diveLog_edit_row_diveCenter => 'Operadora de mergulho';

  @override
  String get diveLog_edit_row_diveProfile => 'Perfil de mergulho';

  @override
  String get diveLog_edit_row_entry => 'Entrada';

  @override
  String get diveLog_edit_row_exit => 'Saída';

  @override
  String get diveLog_edit_row_notSet => 'Não definido';

  @override
  String get diveLog_edit_row_site => 'Ponto de mergulho';

  @override
  String get diveLog_edit_row_surfaceInterval => 'Intervalo de superfície';

  @override
  String get diveLog_edit_row_trip => 'Viagem';

  @override
  String get diveLog_edit_save => 'Salvar';

  @override
  String get diveLog_edit_saveAsSet => 'Salvar como Conjunto';

  @override
  String diveLog_edit_saveAsSetDialog_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'itens',
      one: 'item',
    );
    return 'Salvar $count $_temp0 como um novo conjunto de equipamentos.';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_description => 'Descricao (opcional)';

  @override
  String get diveLog_edit_saveAsSetDialog_descriptionHint =>
      'ex., Equipamento leve para agua quente';

  @override
  String diveLog_edit_saveAsSetDialog_error(Object error) {
    return 'Erro ao criar conjunto: $error';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_setName => 'Nome do Conjunto';

  @override
  String get diveLog_edit_saveAsSetDialog_setNameHint =>
      'ex., Mergulho Tropical';

  @override
  String diveLog_edit_saveAsSetDialog_success(Object name) {
    return 'Conjunto de equipamentos \"$name\" criado';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_title =>
      'Salvar como Conjunto de Equipamentos';

  @override
  String get diveLog_edit_saveAsSetDialog_validation =>
      'Por favor, insira um nome para o conjunto';

  @override
  String get diveLog_edit_section_conditions => 'Condicoes';

  @override
  String get diveLog_edit_section_customFields => 'Custom Fields';

  @override
  String get diveLog_edit_section_depthDuration => 'Profundidade e Duracao';

  @override
  String get diveLog_edit_section_diveCenter => 'Operadora de Mergulho';

  @override
  String get diveLog_edit_section_diveSite => 'Ponto de Mergulho';

  @override
  String get diveLog_edit_section_entryTime => 'Horario de Entrada';

  @override
  String get diveLog_edit_section_equipment => 'Equipamentos';

  @override
  String get diveLog_edit_section_exitTime => 'Horario de Saida';

  @override
  String get diveLog_edit_section_marineLife => 'Vida Marinha';

  @override
  String get diveLog_edit_section_notes => 'Anotacoes';

  @override
  String get diveLog_edit_section_rating => 'Avaliacao';

  @override
  String get diveLog_edit_section_tags => 'Tags';

  @override
  String diveLog_edit_section_tanks(Object count) {
    return 'Cilindros ($count)';
  }

  @override
  String get diveLog_edit_section_trainingCourse => 'Curso de Treinamento';

  @override
  String get diveLog_edit_section_trip => 'Viagem';

  @override
  String get diveLog_edit_section_weight => 'Lastro';

  @override
  String get diveLog_edit_select => 'Selecionar';

  @override
  String get diveLog_edit_selectDiveCenter =>
      'Selecionar Operadora de Mergulho';

  @override
  String get diveLog_edit_selectDiveSite => 'Selecionar Ponto de Mergulho';

  @override
  String get diveLog_edit_selectTrip => 'Selecionar Viagem';

  @override
  String diveLog_edit_snackbar_avgDepthCalculated(Object depth) {
    return 'Profundidade media calculada: $depth';
  }

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Tempo de fundo calculado: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Erro ao salvar mergulho: $error';
  }

  @override
  String diveLog_edit_snackbar_maxDepthCalculated(Object depth) {
    return 'Profundidade maxima calculada: $depth';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'Nenhum dado de perfil de mergulho disponivel';

  @override
  String diveLog_edit_snackbar_runtimeCalculated(Object minutes) {
    return 'Tempo de mergulho calculado: $minutes min';
  }

  @override
  String get diveLog_edit_snackbar_unableToCalculateAvgDepth =>
      'Nao foi possivel calcular a profundidade media a partir do perfil';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'Nao foi possivel calcular o tempo de fundo a partir do perfil';

  @override
  String get diveLog_edit_snackbar_unableToCalculateMaxDepth =>
      'Nao foi possivel calcular a profundidade maxima a partir do perfil';

  @override
  String get diveLog_edit_snackbar_unableToCalculateRuntime =>
      'Nao foi possivel calcular o tempo de mergulho a partir do perfil';

  @override
  String diveLog_edit_summary_items(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
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
      other: '$count espécies',
      one: '1 espécie',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_summary_tanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cilindros',
      one: '1 cilindro',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_surfaceInterval(Object interval) {
    return 'Intervalo de Superficie: $interval';
  }

  @override
  String get diveLog_edit_surfacePressureDefault => '1013';

  @override
  String get diveLog_edit_surfacePressureHint =>
      'Padrao: 1013 mbar ao nivel do mar';

  @override
  String get diveLog_edit_tankCard_done => 'Concluído';

  @override
  String get diveLog_edit_tankCard_edit => 'Editar';

  @override
  String get diveLog_edit_tankCard_mix => 'Mistura';

  @override
  String get diveLog_edit_tankCard_pressure => 'Pressão';

  @override
  String diveLog_edit_tankCard_title(int number) {
    return 'Cilindro $number';
  }

  @override
  String get diveLog_edit_tankCard_volume => 'Volume';

  @override
  String get diveLog_edit_tooltip_calculateFromProfile =>
      'Calcular a partir do perfil de mergulho';

  @override
  String get diveLog_edit_tooltip_clearDiveCenter =>
      'Limpar operadora de mergulho';

  @override
  String get diveLog_edit_tooltip_clearSite => 'Limpar ponto de mergulho';

  @override
  String get diveLog_edit_tooltip_clearTrip => 'Limpar viagem';

  @override
  String get diveLog_edit_tooltip_removeEquipment => 'Remover equipamento';

  @override
  String get diveLog_edit_tooltip_removeSighting => 'Remover avistamento';

  @override
  String get diveLog_edit_tooltip_removeWeight => 'Remover';

  @override
  String get diveLog_edit_trainingCourseHint =>
      'Vincular este mergulho a um curso de treinamento';

  @override
  String diveLog_edit_tripSuggested(Object name) {
    return 'Sugerido: $name';
  }

  @override
  String get diveLog_edit_tripUse => 'Usar';

  @override
  String get diveLog_edit_useSet => 'Usar Conjunto';

  @override
  String diveLog_edit_weightTotal(Object total) {
    return 'Total: $total';
  }

  @override
  String get diveLog_emptyFiltered_clearFilters => 'Limpar Filtros';

  @override
  String get diveLog_emptyFiltered_subtitle =>
      'Tente ajustar ou limpar seus filtros';

  @override
  String get diveLog_emptyFiltered_title =>
      'Nenhum mergulho corresponde aos seus filtros';

  @override
  String get diveLog_empty_logFirstDive => 'Registre Seu Primeiro Mergulho';

  @override
  String get diveLog_empty_subtitle =>
      'Toque no botao abaixo para registrar seu primeiro mergulho';

  @override
  String get diveLog_empty_title => 'Nenhum mergulho registrado ainda';

  @override
  String get diveLog_equipmentPicker_addFromTab =>
      'Adicione equipamentos na aba Equipamentos';

  @override
  String get diveLog_equipmentPicker_allSelected =>
      'Todos os equipamentos ja selecionados';

  @override
  String diveLog_equipmentPicker_errorLoading(Object error) {
    return 'Erro ao carregar equipamentos: $error';
  }

  @override
  String get diveLog_equipmentPicker_noEquipment => 'Nenhum equipamento ainda';

  @override
  String get diveLog_equipmentPicker_removeToAdd =>
      'Remova itens para adicionar outros';

  @override
  String get diveLog_equipmentPicker_title => 'Adicionar Equipamento';

  @override
  String get diveLog_equipmentSetPicker_createHint =>
      'Crie conjuntos em Equipamentos > Conjuntos';

  @override
  String get diveLog_equipmentSetPicker_emptySet => 'Conjunto vazio';

  @override
  String get diveLog_equipmentSetPicker_errorItems => 'Erro ao carregar itens';

  @override
  String diveLog_equipmentSetPicker_errorLoading(Object error) {
    return 'Erro ao carregar conjuntos de equipamentos: $error';
  }

  @override
  String diveLog_equipmentSetPicker_itemsSummary(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
    );
    return '$_temp0: $names';
  }

  @override
  String get diveLog_equipmentSetPicker_loading => 'Carregando...';

  @override
  String get diveLog_equipmentSetPicker_noSets =>
      'Nenhum conjunto de equipamentos ainda';

  @override
  String get diveLog_equipmentSetPicker_title =>
      'Usar Conjunto de Equipamentos';

  @override
  String get diveLog_error_loadingDives => 'Erro ao carregar mergulhos';

  @override
  String get diveLog_error_retry => 'Tentar Novamente';

  @override
  String get diveLog_exportImage_captureFailed =>
      'Nao foi possivel capturar a imagem';

  @override
  String get diveLog_exportImage_generateFailed =>
      'Nao foi possivel gerar a imagem';

  @override
  String get diveLog_exportImage_generatingPdf => 'Gerando PDF...';

  @override
  String get diveLog_exportImage_pdfSaved => 'PDF salvo';

  @override
  String get diveLog_exportImage_saveToFiles => 'Salvar em Arquivos';

  @override
  String get diveLog_exportImage_saveToFilesDescription =>
      'Escolha um local para salvar o arquivo';

  @override
  String get diveLog_exportImage_saveToPhotos => 'Salvar em Fotos';

  @override
  String get diveLog_exportImage_saveToPhotosDescription =>
      'Salvar imagem na sua biblioteca de fotos';

  @override
  String get diveLog_exportImage_savedToFiles => 'Imagem salva';

  @override
  String get diveLog_exportImage_savedToPhotos => 'Imagem salva em Fotos';

  @override
  String get diveLog_exportImage_share => 'Compartilhar';

  @override
  String get diveLog_exportImage_shareDescription =>
      'Compartilhar via outros aplicativos';

  @override
  String get diveLog_exportImage_titleDetails =>
      'Exportar Imagem dos Detalhes do Mergulho';

  @override
  String get diveLog_exportImage_titlePdf => 'Exportar PDF';

  @override
  String get diveLog_exportImage_titleProfile => 'Exportar Imagem do Perfil';

  @override
  String get diveLog_export_csv => 'CSV';

  @override
  String get diveLog_export_csvDescription => 'Formato de planilha';

  @override
  String get diveLog_export_exporting => 'Exportando...';

  @override
  String diveLog_export_failed(Object error) {
    return 'Exportacao falhou: $error';
  }

  @override
  String get diveLog_export_pageAsImage => 'Pagina como Imagem';

  @override
  String get diveLog_export_pageAsImageDescription =>
      'Captura de tela dos detalhes completos do mergulho';

  @override
  String get diveLog_export_pdfDescription =>
      'Pagina impressa do log de mergulho';

  @override
  String get diveLog_export_pdfLogbookEntry => 'Entrada PDF do Logbook';

  @override
  String get diveLog_export_success => 'Mergulho exportado com sucesso';

  @override
  String diveLog_export_titleDiveNumber(Object number) {
    return 'Exportar Mergulho #$number';
  }

  @override
  String get diveLog_export_uddf => 'UDDF';

  @override
  String get diveLog_export_uddfDescription =>
      'Formato Universal de Dados de Mergulho';

  @override
  String get diveLog_filterChip_clearAll => 'Limpar tudo';

  @override
  String get diveLog_filterChip_favorites => 'Favoritos';

  @override
  String diveLog_filterChip_from(Object date) {
    return 'De $date';
  }

  @override
  String get diveLog_filterChip_noBuddy => 'Sem Dupla';

  @override
  String diveLog_filterChip_until(Object date) {
    return 'Ate $date';
  }

  @override
  String get diveLog_filter_allSites => 'Todos os pontos';

  @override
  String get diveLog_filter_allTypes => 'Todos os tipos';

  @override
  String get diveLog_filter_apply => 'Aplicar Filtros';

  @override
  String get diveLog_filter_buddyHint => 'Buscar por nome da dupla';

  @override
  String get diveLog_filter_buddyName => 'Nome da Dupla';

  @override
  String get diveLog_filter_clearAll => 'Limpar Tudo';

  @override
  String get diveLog_filter_clearDates => 'Limpar datas';

  @override
  String get diveLog_filter_clearRating => 'Limpar filtro de avaliacao';

  @override
  String get diveLog_filter_clearWeekdays => 'Limpar dias da semana';

  @override
  String get diveLog_filter_dateSeparator => 'ate';

  @override
  String get diveLog_filter_endDate => 'Data Final';

  @override
  String get diveLog_filter_errorLoadingSites =>
      'Erro ao carregar pontos de mergulho';

  @override
  String get diveLog_filter_errorLoadingTags => 'Erro ao carregar tags';

  @override
  String get diveLog_filter_favoritesOnly => 'Apenas Favoritos';

  @override
  String get diveLog_filter_gasAir => 'Ar (21%)';

  @override
  String get diveLog_filter_gasAll => 'Todos';

  @override
  String get diveLog_filter_gasNitrox => 'Nitrox (>21%)';

  @override
  String get diveLog_filter_max => 'Max';

  @override
  String get diveLog_filter_min => 'Min';

  @override
  String get diveLog_filter_noBuddyOnly => 'Sem Dupla Atribuida';

  @override
  String get diveLog_filter_noTagsYet => 'Nenhuma tag criada ainda';

  @override
  String get diveLog_filter_presetAllTime => 'Todo o período';

  @override
  String get diveLog_filter_presetLast12Months => 'Últimos 12 meses';

  @override
  String get diveLog_filter_presetLastYear => 'Ano passado';

  @override
  String get diveLog_filter_presetThisYear => 'Este ano';

  @override
  String get diveLog_filter_sectionBuddy => 'Dupla';

  @override
  String get diveLog_filter_sectionDateRange => 'Periodo';

  @override
  String get diveLog_filter_sectionDepthRange =>
      'Faixa de Profundidade (metros)';

  @override
  String get diveLog_filter_sectionDiveSite => 'Ponto de Mergulho';

  @override
  String get diveLog_filter_sectionDiveType => 'Tipo de Mergulho';

  @override
  String get diveLog_filter_sectionDuration => 'Duracao (minutos)';

  @override
  String get diveLog_filter_sectionGasMix => 'Mistura de Gas (O₂%)';

  @override
  String get diveLog_filter_sectionMinRating => 'Avaliacao Minima';

  @override
  String get diveLog_filter_sectionTags => 'Tags';

  @override
  String get diveLog_filter_sectionWeekdays => 'Dias da semana';

  @override
  String get diveLog_filter_showOnlyFavorites =>
      'Mostrar apenas mergulhos favoritos';

  @override
  String get diveLog_filter_showOnlyNoBuddy =>
      'Mostrar apenas mergulhos sem dupla';

  @override
  String get diveLog_filter_startDate => 'Data Inicial';

  @override
  String get diveLog_filter_title => 'Filtrar Mergulhos';

  @override
  String get diveLog_filter_resizeGrip => 'Redimensionar o painel de filtros';

  @override
  String get diveLog_filter_tooltip_close => 'Fechar filtro';

  @override
  String get diveLog_fullscreenProfile_close => 'Fechar tela cheia';

  @override
  String get diveLog_fullscreenProfile_readoutHint =>
      'Passe o cursor ou deslize sobre o perfil';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Perfil do Mergulho #$number';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Taxa de Subida';

  @override
  String get diveLog_legend_label_ascentRateLine => 'Linha da Taxa de Subida';

  @override
  String get diveLog_legend_label_ceiling => 'Teto';

  @override
  String get diveLog_legend_label_decoStops => 'Deco stops';

  @override
  String get diveLog_legend_label_cns => 'CNS%';

  @override
  String get diveLog_legend_label_depth => 'Profundidade';

  @override
  String get diveLog_legend_label_events => 'Eventos';

  @override
  String get diveLog_legend_label_gasDensity => 'Densidade do Gas';

  @override
  String get diveLog_legend_label_gasSwitches => 'Trocas de Gas';

  @override
  String get diveLog_legend_label_gfPercent => 'GF%';

  @override
  String get diveLog_legend_label_heartRate => 'Frequencia Cardiaca';

  @override
  String get diveLog_legend_label_maxDepth => 'Profundidade Maxima';

  @override
  String get diveLog_legend_label_meanDepth => 'Profundidade Media';

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
  String get diveLog_legend_label_pressure => 'Pressao';

  @override
  String get diveLog_legend_label_pressureThresholds => 'Limiares de Pressao';

  @override
  String get diveLog_legend_label_sacRate => 'Taxa SAC';

  @override
  String get diveLog_legend_label_showGas => 'Gases';

  @override
  String get diveLog_legend_label_surfaceGf => 'GF de Superficie';

  @override
  String get diveLog_legend_label_temp => 'Temp';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_legend_source_dc => 'DC';

  @override
  String get diveLog_legend_source_calc => 'Calc.';

  @override
  String get diveLog_chartSection_overlays => 'Sobreposicoes';

  @override
  String get diveLog_chartSection_markers => 'Marcadores';

  @override
  String get diveLog_chartSection_decompression => 'Descompressao';

  @override
  String get diveLog_chartSection_gasAnalysis => 'Analise de gases';

  @override
  String get diveLog_chartSection_display => 'Exibição';

  @override
  String get diveLog_chartSection_other => 'Outros';

  @override
  String get diveLog_chartSection_tankPressures => 'Pressoes dos cilindros';

  @override
  String get diveLog_chartOption_metricsFollowViewport =>
      'Manter as sobreposições visíveis';

  @override
  String get diveLog_pressure_estimatedSuffix => '(est.)';

  @override
  String get diveLog_listPage_appBar_diveMap => 'Mapa de Mergulhos';

  @override
  String get diveLog_listPage_compactTitle => 'Mergulhos';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'Erro: $error';
  }

  @override
  String get diveLog_listPage_bottomSheet_importFromComputer =>
      'Importar do computador de mergulho';

  @override
  String get diveLog_listPage_bottomSheet_scanPaperLog =>
      'Digitalizar registro em papel';

  @override
  String get ocrImport_scanPage_processing => 'Lendo a página...';

  @override
  String get ocrImport_scanPage_pickPhoto => 'Escolher foto';

  @override
  String get ocrImport_scanPage_takePhoto => 'Tirar foto';

  @override
  String get ocrImport_scanPage_nothingRead =>
      'Não foi possível ler muito desta página - campos deixados em branco';

  @override
  String get ocrImport_scanPage_engineMissing =>
      'O reconhecimento de texto não está disponível. Instale o Tesseract para digitalizar registros em papel (por exemplo: sudo apt install tesseract-ocr).';

  @override
  String get ocrImport_editPage_photoAttachFailed =>
      'O mergulho foi salvo, mas não foi possível anexar a página digitalizada';

  @override
  String get diveLog_listPage_bottomSheet_logManually =>
      'Registrar mergulho manualmente';

  @override
  String get diveLog_listPage_fab_addDive => 'Adicionar mergulho';

  @override
  String get diveLog_listPage_fab_logDive => 'Registrar Mergulho';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'Busca Avancada';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'Numeracao de Mergulhos';

  @override
  String get diveLog_listPage_menuMatchSites => 'Associar mergulhos a pontos';

  @override
  String get diveLog_sighting_decreaseCount => 'Diminuir contagem';

  @override
  String get diveLog_sighting_increaseCount => 'Aumentar contagem';

  @override
  String diveLog_speciesPicker_errorLoading(String error) {
    return 'Erro ao carregar espécies: $error';
  }

  @override
  String get diveRole_builtin_buddy => 'Dupla';

  @override
  String get diveRole_builtin_diveGuide => 'Guia de Mergulho';

  @override
  String get diveRole_builtin_diveMaster => 'Divemaster';

  @override
  String get diveRole_builtin_instructor => 'Instrutor';

  @override
  String get diveRole_builtin_rearGuard => 'Retaguarda';

  @override
  String get diveRole_builtin_safetyDiver => 'Mergulhador de Segurança';

  @override
  String get diveRole_builtin_solo => 'Solo';

  @override
  String get diveRole_builtin_student => 'Aluno';

  @override
  String get diveRole_builtin_supportDiver => 'Mergulhador de Apoio';

  @override
  String get diveRoles_addDialog_addButton => 'Adicionar';

  @override
  String get diveRoles_addDialog_nameHint => 'ex: Fotógrafo';

  @override
  String get diveRoles_addDialog_nameLabel => 'Nome da Função de Mergulho';

  @override
  String get diveRoles_addDialog_nameValidation => 'Digite um nome';

  @override
  String get diveRoles_addDialog_title =>
      'Adicionar Função de Mergulho Personalizada';

  @override
  String get diveRoles_addTooltip => 'Adicionar função de mergulho';

  @override
  String get diveRoles_appBar_title => 'Funções de Mergulho';

  @override
  String get diveRoles_builtInHeader => 'Funções de Mergulho Integradas';

  @override
  String get diveRoles_customHeader => 'Funções de Mergulho Personalizadas';

  @override
  String diveRoles_deleteDialog_content(Object name) {
    return 'Tem certeza de que deseja excluir \"$name\"?';
  }

  @override
  String get diveRoles_deleteDialog_title => 'Excluir Função de Mergulho?';

  @override
  String get diveRoles_deleteTooltip => 'Excluir função de mergulho';

  @override
  String get diveRoles_renameDialog_title => 'Renomear Função de Mergulho';

  @override
  String get diveRoles_renameTooltip => 'Renomear função de mergulho';

  @override
  String diveRoles_snackbar_added(Object name) {
    return 'Função de mergulho adicionada: $name';
  }

  @override
  String diveRoles_snackbar_cannotDelete(Object name) {
    return 'Não é possível excluir \"$name\" - está sendo usada por mergulhos existentes';
  }

  @override
  String diveRoles_snackbar_deleted(Object name) {
    return 'Função de mergulho excluída: $name';
  }

  @override
  String diveRoles_snackbar_errorAdding(Object error) {
    return 'Erro ao adicionar função de mergulho: $error';
  }

  @override
  String get diveSites_edit_depth_heroMax => 'Prof. máx.';

  @override
  String get diveSites_edit_depth_heroMin => 'Prof. mín.';

  @override
  String get diveSites_edit_group_accessSafety => 'Acesso e segurança';

  @override
  String get diveSites_edit_group_diveInfo => 'Dados de mergulho';

  @override
  String get diveSites_edit_group_identity => 'Identidade';

  @override
  String get diveSites_edit_group_lifeNotes => 'Vida marinha e notas';

  @override
  String get diveSites_edit_group_location => 'Localização';

  @override
  String get diveSites_edit_invite_accessSafety =>
      'Adicionar acesso, estacionamento, poita ou perigos';

  @override
  String get diveSites_edit_invite_diveInfo =>
      'Adicionar faixa de profundidade, dificuldade ou avaliação';

  @override
  String get diveSites_edit_invite_lifeNotes =>
      'Adicionar vida marinha, notas ou compartilhamento';

  @override
  String get diveSites_edit_invite_location =>
      'Adicionar posição GPS ou altitude';

  @override
  String get diveSites_edit_summary_shared => 'compartilhado';

  @override
  String get forms_addSection_prefix => 'Adicionar:';

  @override
  String get forms_cancel => 'Cancelar';

  @override
  String get forms_discard_body =>
      'Você tem alterações não salvas. Se sair agora, elas serão perdidas.';

  @override
  String get forms_discard_discard => 'Descartar';

  @override
  String get forms_discard_keepEditing => 'Continuar editando';

  @override
  String get forms_discard_title => 'Descartar as alterações?';

  @override
  String get forms_save => 'Salvar';

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
  String get settings_manage_setupAssistant => 'Assistente de configuração';

  @override
  String get settings_manage_setupAssistant_subtitle =>
      'Reveja unidades, aparência e opções de backup';

  @override
  String get setup_backup_cloudCopy => 'Armazenar backups na nuvem';

  @override
  String get setup_backup_frequency => 'Frequência';

  @override
  String get setup_backup_frequency_daily => 'Diária';

  @override
  String get setup_backup_frequency_monthly => 'Mensal';

  @override
  String get setup_backup_frequency_weekly => 'Semanal';

  @override
  String get setup_backup_scheduleSubtitle =>
      'Faça backup dos seus dados periodicamente';

  @override
  String get setup_backup_scheduleToggle => 'Backups automáticos';

  @override
  String get setup_backup_subtitle =>
      'Proteja seus dados desde o primeiro dia.';

  @override
  String get setup_backup_title => 'Backups e sincronização';

  @override
  String get setup_common_back => 'Voltar';

  @override
  String get setup_common_next => 'Avançar';

  @override
  String get setup_common_skip => 'Ignorar';

  @override
  String get setup_existing_folder_subtitle =>
      'Aponte o Submersion para uma pasta que já contém uma biblioteca';

  @override
  String get setup_existing_folder_title => 'Abrir uma pasta existente';

  @override
  String get setup_existing_restore_subtitle =>
      'Escolha um arquivo de backup exportado do Submersion';

  @override
  String get setup_existing_restore_title => 'Restaurar um arquivo de backup';

  @override
  String get setup_existing_subtitle =>
      'Escolha como carregar sua biblioteca existente do Submersion';

  @override
  String get setup_existing_sync_subtitle =>
      'Baixe sua biblioteca do iCloud, Dropbox ou S3';

  @override
  String get setup_existing_sync_title => 'Conectar sincronização na nuvem';

  @override
  String get setup_existing_title => 'Traga seus dados';

  @override
  String get setup_finish_applying => 'Configurando...';

  @override
  String setup_finish_error(Object error) {
    return 'Não foi possível concluir a configuração: $error';
  }

  @override
  String get setup_finish_feature_diveComputer =>
      'Baixe mergulhos do seu computador de mergulho';

  @override
  String get setup_finish_feature_gear =>
      'Acompanhe equipamentos e intervalos de manutenção';

  @override
  String get setup_finish_feature_import =>
      'Importe registros de arquivos e outros aplicativos';

  @override
  String get setup_finish_feature_sites =>
      'Veja seus pontos de mergulho no mapa';

  @override
  String get setup_finish_feature_statistics =>
      'Explore estatísticas sobre seus mergulhos';

  @override
  String get setup_finish_start => 'Começar';

  @override
  String get setup_finish_subtitle => 'O Submersion também pode...';

  @override
  String get setup_finish_title => 'Tudo pronto';

  @override
  String get setup_folder_notFound_message =>
      'A pasta selecionada não contém um banco de dados do Submersion.';

  @override
  String get setup_folder_notFound_title => 'Nenhuma biblioteca nessa pasta';

  @override
  String get setup_folder_pick => 'Escolher pasta';

  @override
  String get setup_folder_switching => 'Abrindo biblioteca...';

  @override
  String get setup_folder_title => 'Abrir pasta existente';

  @override
  String get setup_profile_nameHint => 'Digite seu nome';

  @override
  String get setup_profile_nameLabel => 'Seu Nome';

  @override
  String get setup_profile_nameValidation => 'Digite seu nome';

  @override
  String get setup_profile_subtitle =>
      'Digite seu nome para começar. Você pode adicionar mais detalhes depois.';

  @override
  String get setup_profile_title => 'Crie Seu Perfil';

  @override
  String get setup_restore_inProgress => 'Restaurando...';

  @override
  String get setup_restore_pick => 'Escolher arquivo de backup';

  @override
  String get setup_restore_title => 'Restaurar backup';

  @override
  String get setup_step_backup => 'Backup';

  @override
  String get setup_step_finish => 'Concluído';

  @override
  String get setup_step_profile => 'Perfil';

  @override
  String get setup_step_units => 'Unidades';

  @override
  String get setup_syncPull_continue => 'Continuar';

  @override
  String get setup_syncPull_incomplete_message =>
      'Esta conta contém uma biblioteca do Submersion cujo envio nunca foi concluído. Deixe o seu outro dispositivo terminar a sincronização e tente novamente.';

  @override
  String get setup_syncPull_incomplete_retry => 'Verificar novamente';

  @override
  String get setup_syncPull_incomplete_title =>
      'Envio da biblioteca incompleto';

  @override
  String get setup_syncPull_locked_message =>
      'Digite a frase-senha de criptografia para desbloquear esta biblioteca e baixá-la neste dispositivo.';

  @override
  String get setup_syncPull_locked_title =>
      'Esta biblioteca está criptografada';

  @override
  String get setup_syncPull_noLibrary_message =>
      'Nenhuma biblioteca do Submersion foi encontrada nesta conta. Começar do zero? Sua conexão será mantida.';

  @override
  String get setup_syncPull_noLibrary_title => 'Nenhuma biblioteca encontrada';

  @override
  String get setup_syncPull_success => 'Biblioteca adotada';

  @override
  String get setup_syncPull_syncing => 'Baixando sua biblioteca...';

  @override
  String get setup_syncPull_title => 'Conectar e baixar';

  @override
  String get setup_sync_changeProvider => 'Alterar provedor';

  @override
  String setup_sync_connectedTo(String provider) {
    return 'Conectado a $provider';
  }

  @override
  String setup_sync_error(Object error) {
    return 'Não foi possível conectar: $error';
  }

  @override
  String get setup_sync_header => 'Sincronização na nuvem';

  @override
  String get setup_sync_libraryFound_adopt => 'Adotar biblioteca existente';

  @override
  String get setup_sync_libraryFound_keepFresh => 'Começar do zero';

  @override
  String get setup_sync_libraryFound_message =>
      'Esta conta já contém uma biblioteca do Submersion. Adotá-la em vez de começar do zero?';

  @override
  String get setup_sync_libraryFound_title => 'Biblioteca existente encontrada';

  @override
  String get setup_sync_manageInSettings => 'Gerenciar nas Configurações';

  @override
  String get setup_sync_notConnected => 'Não conectado';

  @override
  String get setup_sync_subtitle => 'Sincronize seus dados entre dispositivos';

  @override
  String get setup_units_advanced => 'Ajustar unidades';

  @override
  String get setup_units_altitude => 'Altitude';

  @override
  String get setup_units_dateFormat => 'Formato de data';

  @override
  String get setup_units_depth => 'Profundidade';

  @override
  String get setup_units_imperial => 'Imperial';

  @override
  String get setup_units_metric => 'Métrico';

  @override
  String get setup_units_pressure => 'Pressão';

  @override
  String get setup_units_sac => 'Taxa SAC';

  @override
  String get setup_units_subtitle =>
      'Escolha como as medidas são exibidas. Você pode ajustar cada unidade.';

  @override
  String get setup_units_temperature => 'Temperatura';

  @override
  String get setup_units_timeFormat => 'Formato de hora';

  @override
  String get setup_units_title => 'Unidades';

  @override
  String get setup_units_volume => 'Volume';

  @override
  String get setup_units_weight => 'Peso';

  @override
  String get setup_welcome_existingData_subtitle =>
      'Restaure um backup, conecte a sincronização ou abra uma pasta existente';

  @override
  String get setup_welcome_existingData_title => 'Já tenho dados do Submersion';

  @override
  String get setup_welcome_skipSetup => 'Ignorar configuração';

  @override
  String get setup_welcome_startFresh_subtitle =>
      'Crie seu perfil de mergulhador e configure o aplicativo';

  @override
  String get setup_welcome_startFresh_title => 'Configurar um novo perfil';

  @override
  String get setup_welcome_subtitle =>
      'Registro e análise avançada de mergulhos';

  @override
  String get setup_welcome_title => 'Bem-vindo ao Submersion';

  @override
  String get siteMatchReview_title => 'Associar pontos';

  @override
  String siteMatchReview_diveNumber(Object number) {
    return 'Mergulho #$number';
  }

  @override
  String get siteMatchReview_empty => 'Nada para associar.';

  @override
  String siteMatchReview_summary(int selected, int review, int none) {
    return '$selected selecionados · $review para revisar · $none sem correspondência';
  }

  @override
  String siteMatchReview_confirm(int count) {
    return 'Confirmar $count associações';
  }

  @override
  String get siteMatchReview_cancel => 'Cancelar';

  @override
  String get siteMatchReview_tapToChoose => 'Toque para escolher um ponto';

  @override
  String siteMatchReview_awayMeters(int meters) {
    return 'a $meters m';
  }

  @override
  String siteMatchReview_depthTo(int meters) {
    return 'até $meters m';
  }

  @override
  String siteMatchReview_depthRange(int min, int max) {
    return '$min–$max m';
  }

  @override
  String siteMatchReview_appliedSnack(int dives, int sites) {
    return '$dives mergulhos associados · $sites pontos adicionados';
  }

  @override
  String get siteMatchReview_applyError =>
      'Não foi possível aplicar as associações';

  @override
  String get siteMatchReview_discardTitle => 'Descartar associações?';

  @override
  String get siteMatchReview_discardMessage => 'Sua seleção não será salva.';

  @override
  String get siteMatchReview_discardConfirm => 'Descartar';

  @override
  String get siteMatchReview_keepReviewing => 'Continuar revisando';

  @override
  String get siteMatchReview_sourceExisting => 'seu ponto';

  @override
  String get siteMatchReview_sourceBundled => 'importado';

  @override
  String get siteMatchReview_noNearbySite => 'Nenhum ponto próximo';

  @override
  String importSummary_matchSitesButton(int count) {
    return 'Associar $count mergulhos a pontos';
  }

  @override
  String get diveLog_listPage_searchFieldLabel => 'Buscar mergulhos...';

  @override
  String diveLog_listPage_searchLimitNotice(int limit) {
    return 'Mostrando as primeiras $limit correspondências. Refine a busca para restringir os resultados.';
  }

  @override
  String diveLog_listPage_searchNoResults(Object query) {
    return 'Nenhum mergulho encontrado para \"$query\"';
  }

  @override
  String get diveLog_listPage_searchSuggestion =>
      'Buscar por ponto, dupla ou anotacoes';

  @override
  String get diveLog_listPage_title => 'Log de Mergulhos';

  @override
  String get diveLog_listPage_tooltip_back => 'Voltar';

  @override
  String get diveLog_listPage_tooltip_backToDiveList =>
      'Voltar para a lista de mergulhos';

  @override
  String get diveLog_listPage_tooltip_clearSearch => 'Limpar busca';

  @override
  String get diveLog_listPage_tooltip_filterDives => 'Filtrar mergulhos';

  @override
  String get diveLog_listPage_tooltip_listView => 'Visualizacao em Lista';

  @override
  String get diveLog_listPage_tooltip_mapView => 'Visualizacao no Mapa';

  @override
  String get diveLog_listPage_tooltip_searchDives => 'Buscar mergulhos';

  @override
  String get diveLog_listPage_tooltip_sort => 'Ordenar';

  @override
  String get diveLog_listPage_unknownSite => 'Ponto Desconhecido';

  @override
  String get diveLog_map_emptySubtitle =>
      'Registre mergulhos com dados de localizacao para ver sua atividade no mapa';

  @override
  String get diveLog_map_emptyTitle =>
      'Nenhuma atividade de mergulho para exibir';

  @override
  String diveLog_map_errorLoading(Object error) {
    return 'Erro ao carregar dados de mergulho: $error';
  }

  @override
  String get diveLog_map_tooltip_fitAllSites => 'Ajustar Todos os Pontos';

  @override
  String get diveLog_numbering_actions => 'Acoes';

  @override
  String get diveLog_numbering_allCorrect =>
      'Todos os mergulhos numerados corretamente';

  @override
  String get diveLog_numbering_assignMissing => 'Atribuir numeros faltantes';

  @override
  String get diveLog_numbering_assignMissingDesc =>
      'Numerar mergulhos sem numero a partir do ultimo mergulho numerado';

  @override
  String get diveLog_numbering_close => 'Fechar';

  @override
  String get diveLog_numbering_gapsDetected => 'Lacunas Detectadas';

  @override
  String get diveLog_numbering_issuesDetected => 'Problemas detectados';

  @override
  String diveLog_numbering_missingCount(Object count) {
    return '$count faltando';
  }

  @override
  String get diveLog_numbering_renumberAll => 'Renumerar todos os mergulhos';

  @override
  String get diveLog_numbering_renumberAllDesc =>
      'Atribuir numeros sequenciais com base na data/hora do mergulho';

  @override
  String get diveLog_numbering_renumberDialog_cancel => 'Cancelar';

  @override
  String get diveLog_numbering_renumberDialog_content =>
      'Isto renumerara todos os mergulhos sequencialmente com base na data/hora de entrada. Esta acao nao pode ser desfeita.';

  @override
  String get diveLog_numbering_renumberDialog_renumber => 'Renumerar';

  @override
  String get diveLog_numbering_renumberDialog_startFrom =>
      'Comecar a partir do numero';

  @override
  String get diveLog_numbering_renumberDialog_title =>
      'Renumerar Todos os Mergulhos';

  @override
  String get diveLog_numbering_snackbar_assigned =>
      'Numeros de mergulho faltantes atribuidos';

  @override
  String diveLog_numbering_snackbar_renumbered(Object number) {
    return 'Todos os mergulhos renumerados a partir do #$number';
  }

  @override
  String diveLog_numbering_summary(Object total, Object numbered) {
    return '$total mergulhos no total • $numbered numerados';
  }

  @override
  String get diveLog_numbering_title => 'Numeracao de Mergulhos';

  @override
  String diveLog_numbering_unnumberedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mergulhos',
      one: 'mergulho',
    );
    return '$count $_temp0 sem numero';
  }

  @override
  String get diveLog_o2tox_badge_critical => 'CRITICO';

  @override
  String get diveLog_o2tox_badge_warning => 'AVISO';

  @override
  String diveLog_o2tox_cnsBadgeLabel(Object value) {
    return 'CNS $value';
  }

  @override
  String get diveLog_o2tox_cnsOxygenClock => 'Relogio de Oxigenio CNS';

  @override
  String diveLog_o2tox_deltaDive(Object value) {
    return '+$value% neste mergulho';
  }

  @override
  String get diveLog_o2tox_details => 'Detalhes';

  @override
  String get diveLog_o2tox_label_maxPpO2 => 'ppO2 Maximo';

  @override
  String get diveLog_o2tox_label_maxPpO2Depth => 'Profundidade do ppO2 Maximo';

  @override
  String get diveLog_o2tox_label_timeAbove14 => 'Tempo acima de 1.4 bar';

  @override
  String get diveLog_o2tox_label_timeAbove16 => 'Tempo acima de 1.6 bar';

  @override
  String get diveLog_o2tox_ofDailyLimit => 'do limite diario';

  @override
  String get diveLog_o2tox_oxygenToleranceUnits =>
      'Unidades de Tolerancia ao Oxigenio';

  @override
  String diveLog_o2tox_semantics_cnsBadge(Object value) {
    return 'Toxicidade do oxigênio CNS $value';
  }

  @override
  String get diveLog_o2tox_semantics_criticalWarning =>
      'Aviso critico de toxicidade de oxigenio';

  @override
  String diveLog_o2tox_semantics_otu(Object value, Object percent) {
    return 'Unidades de Tolerância ao Oxigênio: $value, $percent porcento do limite diário';
  }

  @override
  String get diveLog_o2tox_semantics_warning =>
      'Aviso de toxicidade de oxigenio';

  @override
  String diveLog_o2tox_startPercent(Object value) {
    return 'Inicio: $value%';
  }

  @override
  String get diveLog_o2tox_title => 'Toxicidade de Oxigenio';

  @override
  String get diveLog_playbackStats_deco => 'DECO';

  @override
  String get diveLog_playbackStats_depth => 'Profundidade';

  @override
  String get diveLog_playbackStats_header => 'Estatisticas ao Vivo';

  @override
  String get diveLog_playbackStats_heartRate => 'Frequencia Cardiaca';

  @override
  String get diveLog_playbackStats_ndl => 'NDL';

  @override
  String get diveLog_playbackStats_ppO2 => 'ppO₂';

  @override
  String get diveLog_playbackStats_pressure => 'Pressao';

  @override
  String get diveLog_playbackStats_temp => 'Temp';

  @override
  String get diveLog_playback_sliderLabel => 'Posicao de reproducao';

  @override
  String diveLog_playback_speed_label(Object speed) {
    return '${speed}x';
  }

  @override
  String get diveLog_playback_stepThrough => 'Reproducao Passo a Passo';

  @override
  String get diveLog_playback_tooltip_back10 => 'Voltar 10 segundos';

  @override
  String get diveLog_playback_tooltip_exit => 'Sair do modo de reproducao';

  @override
  String get diveLog_playback_tooltip_forward10 => 'Avancar 10 segundos';

  @override
  String get diveLog_playback_tooltip_pause => 'Pausar';

  @override
  String get diveLog_playback_tooltip_play => 'Reproduzir';

  @override
  String get diveLog_playback_tooltip_skipEnd => 'Ir para o final';

  @override
  String get diveLog_playback_tooltip_skipStart => 'Ir para o inicio';

  @override
  String get diveLog_playback_tooltip_speed => 'Velocidade de reproducao';

  @override
  String diveLog_profile_axisDepth(Object unit) {
    return 'Profundidade ($unit)';
  }

  @override
  String get diveLog_profile_axisTime => 'Tempo (min)';

  @override
  String get diveLog_profile_emptyState => 'Sem dados de perfil de mergulho';

  @override
  String get diveLog_profile_rightAxis_none => 'Nenhum';

  @override
  String get diveLog_profile_semantics_changeRightAxis =>
      'Alterar metrica do eixo direito';

  @override
  String get diveLog_profile_semantics_chart =>
      'Grafico do perfil de mergulho, pince para ampliar';

  @override
  String get diveLog_profile_semantics_photoMarker => 'Marcador de foto';

  @override
  String get diveLog_profile_tooltip_moreOptions => 'Mais opcoes do grafico';

  @override
  String get diveLog_profile_tooltip_resetZoom => 'Redefinir zoom';

  @override
  String get diveLog_profile_tooltip_zoomIn => 'Ampliar';

  @override
  String get diveLog_profile_tooltip_zoomOut => 'Reduzir';

  @override
  String diveLog_profile_zoomHint(Object level) {
    return 'Zoom: ${level}x • Pince ou role para ampliar, arraste para mover';
  }

  @override
  String get diveLog_rangeSelection_exitRange => 'Sair do Intervalo';

  @override
  String get diveLog_rangeSelection_selectRange => 'Selecionar Intervalo';

  @override
  String get diveLog_rangeSelection_semantics_adjust =>
      'Ajustar selecao de intervalo';

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
  String get diveLog_rangeStats_title => 'Stats de Intervalo';

  @override
  String get diveLog_rangeStats_tooltip_close => 'Fechar analise de intervalo';

  @override
  String diveLog_scr_calculatedLoopFo2(Object value) {
    return 'FO₂ calculado do loop: $value%';
  }

  @override
  String get diveLog_scr_hint_additionRatio => 'ex., 0.33 (1:3)';

  @override
  String get diveLog_scr_label_additionRatio => 'Razao de Adicao';

  @override
  String get diveLog_scr_label_assumedVo2 => 'VO₂ Assumido';

  @override
  String get diveLog_scr_label_avg => 'Media';

  @override
  String get diveLog_scr_label_injectionRate => 'Taxa de Injecao';

  @override
  String get diveLog_scr_label_max => 'Max';

  @override
  String get diveLog_scr_label_min => 'Min';

  @override
  String get diveLog_scr_label_orificeSize => 'Tamanho do Orificio';

  @override
  String get diveLog_scr_sectionCmf => 'Parametros CMF';

  @override
  String get diveLog_scr_sectionEscr => 'Parametros ESCR';

  @override
  String get diveLog_scr_sectionMeasuredLoopO2 =>
      'O₂ Medido no Loop (opcional)';

  @override
  String get diveLog_scr_sectionPascr => 'Parametros PASCR';

  @override
  String get diveLog_scr_sectionScrType => 'Tipo de SCR';

  @override
  String get diveLog_scr_sectionSupplyGas => 'Gas de Suprimento';

  @override
  String get diveLog_scr_title => 'Configuracoes de SCR';

  @override
  String get diveLog_search_allCenters => 'Todos os centros';

  @override
  String get diveLog_search_allTrips => 'Todas as viagens';

  @override
  String get diveLog_search_appBar => 'Busca Avancada';

  @override
  String get diveLog_search_cancel => 'Cancelar';

  @override
  String get diveLog_search_clearAll => 'Limpar Tudo';

  @override
  String get diveLog_search_customFieldKey => 'Custom Field Key';

  @override
  String get diveLog_search_customFieldValue => 'Value contains...';

  @override
  String get diveLog_search_end => 'Fim';

  @override
  String get diveLog_search_errorLoadingCenters =>
      'Erro ao carregar centros de mergulho';

  @override
  String get diveLog_search_errorLoadingDiveTypes =>
      'Erro ao carregar tipos de mergulho';

  @override
  String get diveLog_search_errorLoadingTrips => 'Erro ao carregar viagens';

  @override
  String get diveLog_search_filter_any => 'Qualquer';

  @override
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

  @override
  String get diveLog_search_label_deco => 'Descompressão';

  @override
  String get diveLog_search_label_depthRange => 'Faixa de Profundidade (m)';

  @override
  String get diveLog_search_label_diveCenter => 'Centro de Mergulho';

  @override
  String get diveLog_search_label_diveSite => 'Ponto de Mergulho';

  @override
  String get diveLog_search_label_diveType => 'Tipo de Mergulho';

  @override
  String get diveLog_search_label_durationRange => 'Faixa de Duracao (min)';

  @override
  String get diveLog_search_label_trip => 'Viagem';

  @override
  String get diveLog_search_search => 'Buscar';

  @override
  String get diveLog_search_section_conditions => 'Condicoes';

  @override
  String get diveLog_search_section_dateRange => 'Periodo';

  @override
  String get diveLog_search_section_gasEquipment => 'Gas e Equipamento';

  @override
  String get diveLog_search_section_location => 'Localizacao';

  @override
  String get diveLog_search_section_organization => 'Organizacao';

  @override
  String get diveLog_search_section_social => 'Social';

  @override
  String get diveLog_search_start => 'Inicio';

  @override
  String diveLog_selection_countSelected(Object count) {
    return '$count selecionado(s)';
  }

  @override
  String get diveLog_selection_tooltip_combine => 'Combinar';

  @override
  String get diveLog_selection_tooltip_delete => 'Excluir Selecionados';

  @override
  String get diveLog_selection_tooltip_deselectAll => 'Desmarcar Todos';

  @override
  String get diveLog_selection_tooltip_edit => 'Editar Selecionados';

  @override
  String get diveLog_selection_tooltip_exit => 'Sair da selecao';

  @override
  String get diveLog_selection_tooltip_export => 'Exportar Selecionados';

  @override
  String get diveLog_selection_tooltip_selectAll => 'Selecionar Todos';

  @override
  String get diveLog_selection_tooltip_selectDateRange =>
      'Selecionar por intervalo de datas';

  @override
  String get diveLog_sighting_add => 'Adicionar';

  @override
  String get diveLog_sighting_cancel => 'Cancelar';

  @override
  String get diveLog_sighting_notesHint =>
      'ex., tamanho, comportamento, localizacao...';

  @override
  String get diveLog_sighting_notesOptional => 'Observacoes (opcional)';

  @override
  String get diveLog_sitePicker_addDiveSite => 'Adicionar Ponto de Mergulho';

  @override
  String diveLog_sitePicker_distanceKm(Object distance) {
    return '$distance km de distancia';
  }

  @override
  String diveLog_sitePicker_distanceAway(String distance) {
    return '$distance de distância';
  }

  @override
  String get diveLog_sitePicker_sortedByDiveDistance =>
      'Ordenado por distância deste mergulho';

  @override
  String diveLog_sitePicker_distanceMeters(Object distance) {
    return '$distance m de distancia';
  }

  @override
  String diveLog_sitePicker_errorLoading(Object error) {
    return 'Erro ao carregar pontos: $error';
  }

  @override
  String get diveLog_sitePicker_newDiveSite => 'Novo Ponto de Mergulho';

  @override
  String get diveLog_sitePicker_noSites => 'Nenhum ponto de mergulho ainda';

  @override
  String get diveLog_sitePicker_sortedByDistance => 'Ordenado por distancia';

  @override
  String get diveLog_sitePicker_title => 'Selecionar Ponto de Mergulho';

  @override
  String get diveLog_sort_title => 'Ordenar Mergulhos';

  @override
  String diveLog_speciesPicker_addNew(Object name) {
    return 'Adicionar \"$name\" como nova especie';
  }

  @override
  String get diveLog_speciesPicker_noResults => 'Nenhuma especie encontrada';

  @override
  String get diveLog_speciesPicker_noSpecies => 'Nenhuma especie disponivel';

  @override
  String get diveLog_speciesPicker_searchHint => 'Buscar especies...';

  @override
  String get diveLog_speciesPicker_title => 'Adicionar Vida Marinha';

  @override
  String get diveLog_speciesPicker_tooltip_clearSearch => 'Limpar busca';

  @override
  String get diveLog_summary_action_importComputer => 'Importar do Computador';

  @override
  String get diveLog_summary_action_logDive => 'Registrar Mergulho';

  @override
  String get diveLog_summary_action_viewStats => 'Ver Estatisticas';

  @override
  String diveLog_summary_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mergulhos',
      one: 'mergulho',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_summary_overview => 'Visao Geral';

  @override
  String get diveLog_summary_record_coldest => 'Mergulho Mais Frio';

  @override
  String get diveLog_summary_record_deepest => 'Mergulho Mais Profundo';

  @override
  String get diveLog_summary_record_longest => 'Mergulho Mais Longo';

  @override
  String get diveLog_summary_record_warmest => 'Mergulho Mais Quente';

  @override
  String get diveLog_summary_section_mostVisited => 'Pontos Mais Visitados';

  @override
  String get diveLog_summary_section_quickActions => 'Acoes Rapidas';

  @override
  String get diveLog_summary_section_records => 'Recordes Pessoais';

  @override
  String get diveLog_summary_selectDive =>
      'Selecione um mergulho da lista para ver detalhes';

  @override
  String get diveLog_summary_stat_avgMaxDepth => 'Prof. Max Media';

  @override
  String get diveLog_summary_stat_avgWaterTemp => 'Temp. Media da Agua';

  @override
  String get diveLog_summary_stat_diveSites => 'Pontos de Mergulho';

  @override
  String get diveLog_summary_stat_diveTime => 'Tempo de Mergulho';

  @override
  String get diveLog_summary_stat_maxDepth => 'Prof. Maxima';

  @override
  String get diveLog_summary_stat_totalDives => 'Total de Mergulhos';

  @override
  String get diveLog_summary_title => 'Resumo do Diario de Mergulho';

  @override
  String get diveLog_tank_label_endPressure => 'Pressao Final';

  @override
  String get diveLog_tank_label_he => 'He';

  @override
  String get diveLog_tank_label_material => 'Material';

  @override
  String get diveLog_tank_label_n2 => 'N2';

  @override
  String get diveLog_tank_label_o2 => 'O2';

  @override
  String get diveLog_tank_label_role => 'Funcao';

  @override
  String get diveLog_tank_label_startPressure => 'Pressao Inicial';

  @override
  String get diveLog_tank_label_tankPreset => 'Preset do Cilindro';

  @override
  String get diveLog_tank_label_volume => 'Volume';

  @override
  String get diveLog_tank_label_workingPressure => 'Pressao Trab.';

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
  String get diveLog_tank_section_gasMix => 'Mistura de Gas';

  @override
  String get diveLog_tank_selectPreset => 'Selecionar Preset...';

  @override
  String get diveLog_tank_saveAsPreset => 'Guardar como preset';

  @override
  String get diveLog_tank_saveAsPreset_needSpecs =>
      'Introduza primeiro um volume e uma pressão de trabalho';

  @override
  String get diveLog_tank_saveAsPreset_nameTitle =>
      'Guardar preset do cilindro';

  @override
  String get diveLog_tank_saveAsPreset_nameHint => 'ex. O meu AL80';

  @override
  String diveLog_tank_saveAsPreset_saved(String name) {
    return 'Preset \"$name\" guardado';
  }

  @override
  String diveLog_tank_title(Object number) {
    return 'Cilindro $number';
  }

  @override
  String get diveLog_tank_tooltip_remove => 'Remover cilindro';

  @override
  String get diveLog_tissue_label_ceiling => 'Teto';

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
  String get diveLog_tissue_title => 'Carga Tissular';

  @override
  String get diveLog_tooltip_avgCalculated => '(méd., calculado)';

  @override
  String get diveLog_tooltip_ceiling => 'Teto';

  @override
  String get diveLog_tooltip_decoStop => 'Deco stop';

  @override
  String get diveLog_tooltip_cns => 'CNS';

  @override
  String get diveLog_tooltip_density => 'Densidade';

  @override
  String get diveLog_tooltip_depth => 'Profundidade';

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
  String get diveLog_tooltip_press => 'Pressao';

  @override
  String get diveLog_tooltip_rate => 'Taxa';

  @override
  String get diveLog_tooltip_sac => 'SAC';

  @override
  String get diveLog_tooltip_sensor => 'Sensor';

  @override
  String get diveLog_legend_label_o2Cells => 'Células O2';

  @override
  String get diveLog_tooltip_o2CellsTight => 'estreita';

  @override
  String get diveLog_tooltip_o2CellsDrifting => 'em deriva';

  @override
  String get diveLog_tooltip_o2CellsWide => 'ampla';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Temp';

  @override
  String get diveLog_tooltip_time => 'Tempo';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get diveLog_sources_row_metric => 'Medida';

  @override
  String get diveLog_sources_row_maxDepth => 'Prof. Máxima';

  @override
  String get diveLog_sources_row_avgDepth => 'Prof. Média';

  @override
  String get diveLog_sources_row_duration => 'Duração';

  @override
  String get diveLog_sources_row_waterTemp => 'Temp. Água';

  @override
  String get diveLog_sources_row_cns => 'CNS';

  @override
  String get diveLog_sources_row_otu => 'OTU';

  @override
  String get diveLog_sources_row_decoAlgorithm => 'Algoritmo de Deco';

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
  String get diveLog_sources_unknownComputer => 'Computador Desconhecido';

  @override
  String get diveLog_sources_manualEntry => 'Entrada Manual';

  @override
  String get diveLog_sources_importedFile => 'Arquivo Importado';

  @override
  String get diveLog_sources_editedSuffix => ' (editado)';

  @override
  String get diveLog_sources_barLabel => 'FONTES';

  @override
  String get diveLog_sources_menu_setPrimary => 'Definir como principal';

  @override
  String get diveLog_sources_menu_split => 'Dividir em mergulho separado';

  @override
  String get diveLog_sources_overlayTooltip => 'Sobrepor no gráfico';

  @override
  String get diveLog_sources_splitDialog_title =>
      'Dividir em mergulho separado?';

  @override
  String get diveLog_sources_splitDialog_body =>
      'O perfil, os eventos e os cilindros desta fonte serão movidos para um novo mergulho. O registro do diário permanece neste mergulho.';

  @override
  String get diveLog_sources_splitDialog_confirm => 'Dividir';

  @override
  String get diveLog_sources_splitDone => 'Mergulho dividido';

  @override
  String get diveLog_sources_splitFailed => 'Falha ao dividir';

  @override
  String get divePlanner_action_addTank => 'Adicionar Cilindro';

  @override
  String get divePlanner_action_convertToDive => 'Converter em Mergulho';

  @override
  String get divePlanner_action_deletePlan => 'Excluir plano';

  @override
  String get divePlanner_action_editTank => 'Editar Cilindro';

  @override
  String get divePlanner_action_moreOptions => 'Mais opções';

  @override
  String get divePlanner_action_quickPlan => 'Plano Rápido';

  @override
  String get divePlanner_action_renamePlan => 'Renomear Plano';

  @override
  String get divePlanner_action_reset => 'Restaurar';

  @override
  String get divePlanner_action_resetPlan => 'Restaurar Plano';

  @override
  String get divePlanner_action_savePlan => 'Salvar Plano';

  @override
  String get divePlanner_error_cannotConvert =>
      'Não é possível converter: o plano tem avisos críticos';

  @override
  String get divePlanner_error_reserveExceedsTank =>
      'Excede a pressão do cilindro';

  @override
  String get divePlanner_error_reserveMustBePositive => 'Deve ser maior que 0';

  @override
  String divePlanner_info_reserveDefault(Object unit, Object value) {
    return 'Não inserido — assumindo $value $unit';
  }

  @override
  String get divePlanner_field_hePercent => 'He %';

  @override
  String get divePlanner_field_name => 'Nome';

  @override
  String get divePlanner_field_o2Percent => 'O₂ %';

  @override
  String get divePlanner_field_planName => 'Nome do Plano';

  @override
  String get divePlanner_field_role => 'Função';

  @override
  String divePlanner_field_startPressure(Object pressureSymbol) {
    return 'Inicial ($pressureSymbol)';
  }

  @override
  String get divePlanner_field_travelGas => 'Também usado como gás de viagem';

  @override
  String divePlanner_field_volume(Object volumeSymbol) {
    return 'Volume ($volumeSymbol)';
  }

  @override
  String get divePlanner_hint_tankName => 'Digite o nome do cilindro';

  @override
  String get divePlanner_label_altitude => 'Altitude:';

  @override
  String get divePlanner_label_belowMinReserve => 'Abaixo da Reserva Mínima';

  @override
  String get divePlanner_label_ceiling => 'Teto';

  @override
  String get divePlanner_label_consumption => 'Consumo';

  @override
  String get divePlanner_label_deco => 'DECO';

  @override
  String get divePlanner_label_decoSchedule => 'Programação de Descompressão';

  @override
  String get divePlanner_label_decompression => 'Descompressão';

  @override
  String divePlanner_label_depthAxis(Object depthSymbol) {
    return 'Profundidade ($depthSymbol)';
  }

  @override
  String get divePlanner_label_diveProfile => 'Perfil do Mergulho';

  @override
  String get divePlanner_label_empty => 'VAZIO';

  @override
  String get divePlanner_label_gasConsumption => 'Consumo de Gás';

  @override
  String get divePlanner_label_gfHigh => 'GF Alto';

  @override
  String get divePlanner_label_gfLow => 'GF Baixo';

  @override
  String get divePlanner_label_max => 'Máx';

  @override
  String get divePlanner_label_ndl => 'NDL';

  @override
  String get divePlanner_label_planSettings => 'Configurações do Plano';

  @override
  String get divePlanner_label_remaining => 'Restante';

  @override
  String get divePlanner_label_reserve => 'Reserva:';

  @override
  String get divePlanner_label_runtime => 'Tempo Total';

  @override
  String get divePlanner_label_sacRate => 'RMV:';

  @override
  String get divePlanner_label_status => 'Status';

  @override
  String get divePlanner_label_tanks => 'Cilindros';

  @override
  String get divePlanner_label_time => 'Tempo';

  @override
  String get divePlanner_label_timeAxis => 'Tempo (min)';

  @override
  String get divePlanner_label_tts => 'TTS';

  @override
  String get divePlanner_label_used => 'Usado';

  @override
  String get divePlanner_label_warnings => 'Avisos';

  @override
  String get divePlanner_legend_ascent => 'Subida';

  @override
  String get divePlanner_legend_bottom => 'Fundo';

  @override
  String get divePlanner_legend_deco => 'Deco';

  @override
  String get divePlanner_legend_descent => 'Descida';

  @override
  String get divePlanner_legend_safety => 'Segurança';

  @override
  String get divePlanner_message_addSegmentsForGas =>
      'Adicione segmentos para ver as projeções de gás';

  @override
  String get divePlanner_message_addSegmentsForProfile =>
      'Adicione segmentos para ver o perfil do mergulho';

  @override
  String get divePlanner_message_convertingPlan =>
      'Convertendo plano em mergulho...';

  @override
  String get divePlanner_message_noProfile => 'Nenhum perfil para exibir';

  @override
  String divePlanner_message_deleteConfirmation(String name) {
    return 'Excluir \'$name\'?';
  }

  @override
  String get divePlanner_message_planDeleted => 'Plano excluído';

  @override
  String get divePlanner_message_planSaved => 'Plano salvo';

  @override
  String get divePlanner_message_resetConfirmation =>
      'Tem certeza de que deseja restaurar o plano?';

  @override
  String divePlanner_semantics_criticalWarning(Object message) {
    return 'Aviso crítico: $message';
  }

  @override
  String divePlanner_semantics_decoStop(
    Object depth,
    Object duration,
    Object gasMix,
  ) {
    return 'Parada de deco a $depth por $duration em $gasMix';
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
    return 'Plano de mergulho, profundidade máxima $maxDepth, tempo total $totalMinutes minutos';
  }

  @override
  String divePlanner_semantics_warning(Object message) {
    return 'Aviso: $message';
  }

  @override
  String get divePlanner_tab_plan => 'Plano';

  @override
  String get divePlanner_tab_profile => 'Perfil';

  @override
  String get divePlanner_tab_results => 'Resultados';

  @override
  String get divePlanner_warning_ascentRateHigh =>
      'Taxa de subida excede o limite seguro';

  @override
  String divePlanner_warning_ascentRateHighWithRate(Object rate) {
    return 'Taxa de subida $rate/min excede o limite seguro';
  }

  @override
  String divePlanner_warning_belowMinReserve(Object reserve) {
    return 'Abaixo da reserva mínima ($reserve)';
  }

  @override
  String get divePlanner_warning_cnsCritical => 'CNS% excede 100%';

  @override
  String divePlanner_warning_cnsWarning(Object threshold) {
    return 'CNS% excede $threshold%';
  }

  @override
  String get divePlanner_warning_endHigh =>
      'Profundidade Narcótica Equivalente muito alta';

  @override
  String divePlanner_warning_endHighWithDepth(Object depth) {
    return 'END de $depth excede o limite seguro';
  }

  @override
  String divePlanner_warning_gasLow(Object threshold) {
    return 'Cilindro abaixo de $threshold de reserva';
  }

  @override
  String get divePlanner_warning_gasOut => 'Cilindro ficará vazio';

  @override
  String get divePlanner_warning_minGasViolation =>
      'Reserva mínima de gás não mantida';

  @override
  String get divePlanner_warning_modViolation =>
      'Tentativa de troca de gás acima da MOD';

  @override
  String get divePlanner_warning_ndlExceeded =>
      'Mergulho entra em obrigação de descompressão';

  @override
  String get divePlanner_warning_otuWarning => 'Acumulação de OTU alta';

  @override
  String divePlanner_warning_ppO2Critical(Object value) {
    return 'ppO₂ de $value bar excede o limite crítico';
  }

  @override
  String divePlanner_warning_ppO2High(Object value) {
    return 'ppO₂ de $value bar excede o limite de trabalho';
  }

  @override
  String get diveSites_detail_access_accessNotes => 'Notas de Acesso';

  @override
  String get diveSites_detail_access_mooring => 'Fundeadouro';

  @override
  String get diveSites_detail_access_parking => 'Estacionamento';

  @override
  String get diveSites_detail_altitude_elevation => 'Elevacao';

  @override
  String get diveSites_detail_altitude_pressure => 'Pressao';

  @override
  String get diveSites_detail_coordinatesCopied =>
      'Coordenadas copiadas para a area de transferencia';

  @override
  String get diveSites_detail_deleteDialog_cancel => 'Cancelar';

  @override
  String get diveSites_detail_deleteDialog_confirm => 'Excluir';

  @override
  String get diveSites_detail_deleteDialog_content =>
      'Tem certeza de que deseja excluir este ponto? Esta acao nao pode ser desfeita.';

  @override
  String get diveSites_detail_deleteDialog_title => 'Excluir Ponto';

  @override
  String get diveSites_detail_deleteMenu_label => 'Excluir';

  @override
  String get diveSites_detail_deleteSnackbar => 'Ponto excluido';

  @override
  String get diveSites_detail_depth_maximum => 'Maximo';

  @override
  String get diveSites_detail_depth_minimum => 'Minimo';

  @override
  String get diveSites_detail_diveCount_one => '1 mergulho registrado';

  @override
  String diveSites_detail_diveCount_other(Object count) {
    return '$count mergulhos registrados';
  }

  @override
  String get diveSites_detail_diveCount_zero =>
      'Nenhum mergulho registrado ainda';

  @override
  String get diveSites_detail_editTooltip => 'Editar Ponto';

  @override
  String get diveSites_detail_editTooltipShort => 'Editar';

  @override
  String diveSites_detail_error_body(Object error) {
    return 'Erro: $error';
  }

  @override
  String get diveSites_detail_error_title => 'Erro';

  @override
  String get diveSites_detail_loading_title => 'Carregando...';

  @override
  String get diveSites_detail_location_country => 'Pais';

  @override
  String get diveSites_detail_location_city => 'Cidade';

  @override
  String get diveSites_detail_location_island => 'Ilha';

  @override
  String get diveSites_detail_location_bodyOfWater => 'Corpo de água';

  @override
  String get diveSites_detail_location_gpsCoordinates => 'Coordenadas GPS';

  @override
  String get diveSites_detail_location_notSet => 'Nao definido';

  @override
  String get diveSites_detail_location_region => 'Regiao';

  @override
  String get diveSites_detail_noDepthInfo => 'Sem informacao de profundidade';

  @override
  String get diveSites_detail_noDescription => 'Sem descricao';

  @override
  String get diveSites_detail_noNotes => 'Sem observacoes';

  @override
  String get diveSites_detail_rating_notRated => 'Nao avaliado';

  @override
  String diveSites_detail_rating_value(Object rating) {
    return '$rating de 5';
  }

  @override
  String get diveSites_detail_section_access => 'Acesso e Logistica';

  @override
  String get diveSites_detail_section_altitude => 'Altitude';

  @override
  String get diveSites_detail_section_depthRange => 'Faixa de Profundidade';

  @override
  String get diveSites_detail_section_description => 'Descricao';

  @override
  String get diveSites_detail_section_difficultyLevel => 'Nivel de Dificuldade';

  @override
  String get diveSites_detail_section_divesAtSite => 'Mergulhos neste Ponto';

  @override
  String get diveSites_detail_section_hazards => 'Perigos e Seguranca';

  @override
  String get diveSites_detail_section_location => 'Localizacao';

  @override
  String get diveSites_detail_section_notes => 'Observacoes';

  @override
  String get diveSites_detail_section_rating => 'Avaliacao';

  @override
  String diveSites_detail_semantics_copyToClipboard(Object label) {
    return 'Copiar $label para a area de transferencia';
  }

  @override
  String get diveSites_detail_semantics_viewDivesAtSite =>
      'Ver mergulhos neste ponto';

  @override
  String get diveSites_detail_semantics_viewFullscreenMap =>
      'Ver mapa em tela cheia';

  @override
  String get diveSites_detail_siteNotFound_body =>
      'Este ponto nao existe mais.';

  @override
  String get diveSites_detail_siteNotFound_title => 'Ponto Nao Encontrado';

  @override
  String get diveSites_difficulty_advanced => 'Avancado';

  @override
  String get diveSites_difficulty_beginner => 'Iniciante';

  @override
  String get diveSites_difficulty_intermediate => 'Intermediario';

  @override
  String get diveSites_difficulty_technical => 'Tecnico';

  @override
  String get diveSites_edit_access_accessNotes_hint =>
      'Como chegar ao ponto, pontos de entrada/saida, acesso pela costa/barco';

  @override
  String get diveSites_edit_access_accessNotes_label => 'Notas de Acesso';

  @override
  String get diveSites_edit_access_mooringNumber_hint => 'ex., Boia #12';

  @override
  String get diveSites_edit_access_mooringNumber_label =>
      'Numero do Fundeadouro';

  @override
  String get diveSites_edit_access_parkingInfo_hint =>
      'Disponibilidade de estacionamento, taxas, dicas';

  @override
  String get diveSites_edit_access_parkingInfo_label =>
      'Informacoes de Estacionamento';

  @override
  String get diveSites_edit_access_entryMethod_label => 'Método de entrada';

  @override
  String get diveSites_edit_access_exitMethod_label => 'Método de saída';

  @override
  String diveSites_edit_access_entrySuggestionPair(
    int count,
    String entry,
    String exit,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Os teus $count mergulhos aqui: entrada $entry, saída $exit',
      one: 'O teu mergulho aqui: entrada $entry, saída $exit',
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
      other: 'Os teus $count mergulhos aqui: entrada $entry',
      one: 'O teu mergulho aqui: entrada $entry',
    );
    return '$_temp0';
  }

  @override
  String get diveSites_detail_access_entryMethod => 'Entrada';

  @override
  String get diveSites_detail_access_exitMethod => 'Saída';

  @override
  String get diveSites_edit_altitude_helperText =>
      'Elevacao do ponto acima do nivel do mar (para mergulho em altitude)';

  @override
  String get diveSites_edit_altitude_hint => 'ex., 2000';

  @override
  String diveSites_edit_altitude_label(Object symbol) {
    return 'Altitude ($symbol)';
  }

  @override
  String get diveSites_edit_altitude_validation => 'Altitude invalida';

  @override
  String get diveSites_edit_appBar_deleteSiteTooltip => 'Excluir Ponto';

  @override
  String get diveSites_edit_appBar_editSite => 'Editar Ponto';

  @override
  String get diveSites_edit_appBar_merge => 'Mesclar';

  @override
  String get diveSites_edit_appBar_mergeSites => 'Mesclar locais de mergulho';

  @override
  String get diveSites_edit_appBar_newSite => 'Novo Ponto';

  @override
  String get diveSites_edit_appBar_save => 'Salvar';

  @override
  String get diveSites_edit_button_addSite => 'Adicionar Ponto';

  @override
  String get diveSites_edit_button_mergeSites => 'Mesclar locais de mergulho';

  @override
  String get diveSites_edit_button_saveChanges => 'Salvar Alteracoes';

  @override
  String get diveSites_edit_cancel => 'Cancelar';

  @override
  String get diveSites_edit_depth_helperText =>
      'Do ponto mais raso ao mais profundo';

  @override
  String get diveSites_edit_depth_maxHint => 'ex., 30';

  @override
  String diveSites_edit_depth_maxLabel(Object symbol) {
    return 'Profundidade Maxima ($symbol)';
  }

  @override
  String get diveSites_edit_depth_minHint => 'ex., 5';

  @override
  String diveSites_edit_depth_minLabel(Object symbol) {
    return 'Profundidade Minima ($symbol)';
  }

  @override
  String get diveSites_edit_depth_separator => 'ate';

  @override
  String get diveSites_edit_discardDialog_content =>
      'Voce tem alteracoes nao salvas. Tem certeza de que deseja sair?';

  @override
  String get diveSites_edit_discardDialog_discard => 'Descartar';

  @override
  String get diveSites_edit_discardDialog_keepEditing => 'Continuar Editando';

  @override
  String get diveSites_edit_discardDialog_title => 'Descartar Alteracoes?';

  @override
  String get diveSites_edit_field_country_label => 'Pais';

  @override
  String get diveSites_edit_field_city_label => 'Cidade';

  @override
  String get diveSites_edit_field_island_label => 'Ilha';

  @override
  String get diveSites_edit_field_bodyOfWater_label => 'Corpo de água';

  @override
  String get diveSites_edit_field_description_hint =>
      'Breve descricao do ponto';

  @override
  String get diveSites_edit_field_description_label => 'Descricao';

  @override
  String get diveSites_edit_field_notes_hint =>
      'Qualquer outra informacao sobre este ponto';

  @override
  String get diveSites_edit_field_notes_label => 'Observacoes Gerais';

  @override
  String get diveSites_edit_field_region_label => 'Regiao';

  @override
  String get diveSites_edit_field_siteName_hint => 'ex., Blue Hole';

  @override
  String get diveSites_edit_field_siteName_label => 'Nome do Ponto *';

  @override
  String get diveSites_edit_field_siteName_validation =>
      'Por favor, insira o nome do ponto';

  @override
  String diveSites_similarSite_useHint(Object siteName) {
    return 'Semelhante a um local de mergulho existente \"$siteName\". Toque para usar.';
  }

  @override
  String diveSites_similarSite_warning(Object siteName) {
    return 'Já existe um local semelhante: \"$siteName\"';
  }

  @override
  String get diveSites_edit_gps_gettingLocation => 'Obtendo...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Escolha um método de localização ou consulte as coordenadas para preencher país, região, cidade e corpo de água';

  @override
  String get diveSites_edit_gps_latitude_hint => 'ex., 21.4225';

  @override
  String get diveSites_edit_gps_latitude_label => 'Latitude';

  @override
  String get diveSites_edit_gps_latitude_validation => 'Latitude invalida';

  @override
  String get diveSites_edit_gps_longitude_hint => 'ex., -86.7542';

  @override
  String get diveSites_edit_gps_longitude_label => 'Longitude';

  @override
  String get diveSites_edit_gps_longitude_validation => 'Longitude invalida';

  @override
  String get diveSites_edit_gps_pickFromMap => 'Escolher no Mapa';

  @override
  String get diveSites_edit_gps_lookupFromCoordinates =>
      'Consultar pelas coordenadas';

  @override
  String get diveSites_edit_snackbar_lookupNothingFound =>
      'Nenhum detalhe de localização encontrado para estas coordenadas';

  @override
  String get diveSites_edit_snackbar_lookupFailed =>
      'A consulta de localização falhou. Verifique a sua ligação e tente novamente.';

  @override
  String get diveSites_edit_lookupReplace_title =>
      'Substituir os detalhes de localização?';

  @override
  String get diveSites_edit_lookupReplace_body =>
      'A consulta encontrou valores diferentes para estes campos:';

  @override
  String get diveSites_edit_lookupReplace_replace => 'Substituir';

  @override
  String get diveSites_edit_lookupReplace_keep => 'Manter';

  @override
  String get diveSites_edit_gps_useMyLocation => 'Usar Minha Localizacao';

  @override
  String get diveSites_edit_hazards_helperText =>
      'Liste quaisquer perigos ou consideracoes de seguranca';

  @override
  String get diveSites_edit_hazards_hint =>
      'ex., Correntes fortes, trafego de embarcacoes, aguas-vivas, corais afiados';

  @override
  String get diveSites_edit_hazards_label => 'Perigos';

  @override
  String get diveSites_edit_marineLife_addButton => 'Adicionar';

  @override
  String get diveSites_edit_marineLife_empty =>
      'Nenhuma especie esperada adicionada';

  @override
  String get diveSites_edit_marineLife_helperText =>
      'Especies que voce espera ver neste ponto';

  @override
  String diveSites_edit_merge_confirmBody(int count) {
    return 'Isso mesclará $count locais em um só. Mergulhos, mídias e espécies esperadas serão combinados no local remanescente. Os outros locais serão excluídos.';
  }

  @override
  String get diveSites_edit_merge_confirmTitle => 'Mesclar locais de mergulho';

  @override
  String get diveSites_edit_merge_fieldSourceCycleTooltip =>
      'Usar valor do próximo local selecionado';

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
      'Selecionar valor do local selecionado';

  @override
  String get diveSites_edit_merge_marineLifeHelperText =>
      'Combinado de todos os locais selecionados';

  @override
  String diveSites_edit_merge_loadingErrorBody(Object error) {
    return 'Falha ao carregar locais de mergulho: $error';
  }

  @override
  String get diveSites_edit_merge_loadingErrorTitle =>
      'Mesclar locais de mergulho';

  @override
  String get diveSites_edit_merge_notEnoughBody =>
      'Não há locais de mergulho suficientes para mesclar.';

  @override
  String get diveSites_edit_merge_notEnoughTitle =>
      'Mesclar locais de mergulho';

  @override
  String get diveSites_edit_rating_clear => 'Limpar Avaliacao';

  @override
  String diveSites_edit_rating_starTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count estrela$_temp0';
  }

  @override
  String get diveSites_edit_section_access => 'Acesso e Logistica';

  @override
  String get diveSites_edit_section_altitude => 'Altitude';

  @override
  String get diveSites_edit_section_depthRange => 'Faixa de Profundidade';

  @override
  String get diveSites_edit_section_difficultyLevel => 'Nivel de Dificuldade';

  @override
  String get diveSites_edit_section_expectedMarineLife =>
      'Vida Marinha Esperada';

  @override
  String get diveSites_edit_section_gpsCoordinates => 'Coordenadas GPS';

  @override
  String get diveSites_edit_section_hazards => 'Perigos e Seguranca';

  @override
  String get diveSites_edit_section_rating => 'Avaliacao';

  @override
  String get diveSites_edit_section_waterType => 'Tipo de água';

  @override
  String diveSites_edit_snackbar_errorDeleting(Object error) {
    return 'Erro ao excluir ponto: $error';
  }

  @override
  String diveSites_edit_snackbar_errorSaving(Object error) {
    return 'Erro ao salvar ponto: $error';
  }

  @override
  String get diveSites_edit_snackbar_locationCaptured =>
      'Localizacao capturada';

  @override
  String diveSites_edit_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Localizacao capturada (${accuracy}m)';
  }

  @override
  String get diveSites_edit_snackbar_locationSelectedFromMap =>
      'Localizacao selecionada no mapa';

  @override
  String get diveSites_edit_snackbar_locationSettings => 'Configuracoes';

  @override
  String get diveSites_edit_snackbar_locationUnavailableDesktop =>
      'Nao foi possivel obter a localizacao. Os servicos de localizacao podem nao estar disponiveis.';

  @override
  String get diveSites_edit_snackbar_locationUnavailableMobile =>
      'Nao foi possivel obter a localizacao. Verifique as permissoes.';

  @override
  String get diveSites_edit_snackbar_siteAdded => 'Ponto adicionado';

  @override
  String get diveSites_edit_snackbar_sitesMerged =>
      'Locais de mergulho mesclados';

  @override
  String get diveSites_edit_snackbar_siteUpdated => 'Ponto atualizado';

  @override
  String get diveSites_fab_label => 'Adicionar Ponto';

  @override
  String get diveSites_fab_tooltip => 'Adicionar um novo ponto de mergulho';

  @override
  String get diveSites_filter_apply => 'Aplicar Filtros';

  @override
  String get diveSites_filter_cancel => 'Cancelar';

  @override
  String get diveSites_filter_clearAll => 'Limpar Tudo';

  @override
  String get diveSites_filter_country_hint => 'ex., Tailandia';

  @override
  String get diveSites_filter_country_label => 'Pais';

  @override
  String get diveSites_filter_depth_max_label => 'Max';

  @override
  String get diveSites_filter_depth_min_label => 'Min';

  @override
  String get diveSites_filter_depth_separator => 'ate';

  @override
  String get diveSites_filter_difficulty_any => 'Qualquer';

  @override
  String get diveSites_filter_option_hasCoordinates_subtitle =>
      'Mostrar apenas pontos com localizacao GPS';

  @override
  String get diveSites_filter_option_hasCoordinates_title =>
      'Possui Coordenadas';

  @override
  String get diveSites_filter_option_hasDives_subtitle =>
      'Mostrar apenas pontos com mergulhos registrados';

  @override
  String get diveSites_filter_option_hasDives_title => 'Possui Mergulhos';

  @override
  String diveSites_filter_rating_starsPlus(Object count) {
    return '$count+ estrelas';
  }

  @override
  String get diveSites_filter_region_hint => 'ex., Phuket';

  @override
  String get diveSites_filter_region_label => 'Regiao';

  @override
  String get diveSites_filter_section_depthRange =>
      'Faixa de Profundidade Maxima';

  @override
  String get diveSites_filter_section_difficulty => 'Dificuldade';

  @override
  String get diveSites_filter_section_location => 'Localizacao';

  @override
  String get diveSites_filter_section_minRating => 'Avaliacao Minima';

  @override
  String get diveSites_filter_section_options => 'Opcoes';

  @override
  String get diveSites_filter_title => 'Filtrar Pontos';

  @override
  String get diveSites_import_appBar_title => 'Importar Ponto de Mergulho';

  @override
  String get diveSites_import_badge_imported => 'Importado';

  @override
  String get diveSites_import_badge_saved => 'Salvo';

  @override
  String get diveSites_import_button_import => 'Importar';

  @override
  String get diveSites_import_detail_alreadyImported => 'Ja Importado';

  @override
  String get diveSites_import_detail_importToMySites =>
      'Importar para Meus Pontos';

  @override
  String diveSites_import_detail_source(Object source) {
    return 'Fonte: $source';
  }

  @override
  String get diveSites_import_empty_description =>
      'Busque pontos de mergulho em nosso banco de dados de\ndestinos de mergulho populares ao redor do mundo.';

  @override
  String get diveSites_import_empty_hint =>
      'Tente buscar por nome do ponto, pais ou regiao.';

  @override
  String get diveSites_import_empty_title => 'Buscar Pontos de Mergulho';

  @override
  String get diveSites_import_error_retry => 'Tentar Novamente';

  @override
  String get diveSites_import_error_title => 'Erro na Busca';

  @override
  String get diveSites_import_error_unknown => 'Erro desconhecido';

  @override
  String get diveSites_import_externalSite_locationUnknown =>
      'Localizacao desconhecida';

  @override
  String get diveSites_import_label_gps => 'GPS';

  @override
  String get diveSites_import_localSite_locationNotSet =>
      'Localizacao nao definida';

  @override
  String diveSites_import_noResults_description(Object query) {
    return 'Nenhum ponto de mergulho encontrado para \"$query\".\nTente um termo de busca diferente.';
  }

  @override
  String get diveSites_import_noResults_title => 'Sem Resultados';

  @override
  String get diveSites_import_quickSearch_caribbean => 'Caribe';

  @override
  String get diveSites_import_quickSearch_indonesia => 'Indonesia';

  @override
  String get diveSites_import_quickSearch_maldives => 'Maldivas';

  @override
  String get diveSites_import_quickSearch_philippines => 'Filipinas';

  @override
  String get diveSites_import_quickSearch_redSea => 'Mar Vermelho';

  @override
  String get diveSites_import_quickSearch_thailand => 'Tailandia';

  @override
  String get diveSites_import_search_clearTooltip => 'Limpar busca';

  @override
  String get diveSites_import_search_hint =>
      'Buscar pontos de mergulho (ex., \"Blue Hole\", \"Tailandia\")';

  @override
  String diveSites_import_section_importFromDatabase(Object count) {
    return 'Importar do Banco de Dados ($count)';
  }

  @override
  String diveSites_import_section_mySites(Object count) {
    return 'Meus Pontos ($count)';
  }

  @override
  String diveSites_import_semantics_viewDetails(Object name) {
    return 'Ver detalhes de $name';
  }

  @override
  String diveSites_import_semantics_viewSavedSite(Object name) {
    return 'Ver ponto salvo $name';
  }

  @override
  String get diveSites_import_snackbar_failed => 'Falha ao importar ponto';

  @override
  String diveSites_import_snackbar_imported(Object name) {
    return '\"$name\" importado';
  }

  @override
  String get diveSites_import_snackbar_viewAction => 'Ver';

  @override
  String get diveSites_list_activeFilter_clear => 'Limpar';

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
    return 'Até $max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '$min+';
  }

  @override
  String get diveSites_list_activeFilter_hasCoordinates => 'Possui coordenadas';

  @override
  String get diveSites_list_activeFilter_hasDives => 'Possui mergulhos';

  @override
  String diveSites_list_activeFilter_region(Object region) {
    return 'Regiao: $region';
  }

  @override
  String get diveSites_list_appBar_title => 'Pontos de Mergulho';

  @override
  String get diveSites_list_bulkDelete_cancel => 'Cancelar';

  @override
  String get diveSites_list_bulkDelete_confirm => 'Excluir';

  @override
  String diveSites_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pontos',
      one: 'ponto',
    );
    return 'Tem certeza de que deseja excluir $count $_temp0? Esta acao pode ser desfeita em ate 5 segundos.';
  }

  @override
  String get diveSites_list_bulkDelete_restored => 'Pontos restaurados';

  @override
  String diveSites_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pontos',
      one: 'ponto',
    );
    return '$count $_temp0 excluido(s)';
  }

  @override
  String get diveSites_list_bulkDelete_title => 'Excluir Pontos';

  @override
  String get diveSites_list_bulkDelete_undo => 'Desfazer';

  @override
  String get diveSites_list_merge_restored => 'Fusao desfeita';

  @override
  String diveSites_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pontos fundidos',
      one: 'ponto fundido',
    );
    return '$count $_temp0';
  }

  @override
  String get diveSites_list_merge_undo => 'Desfazer';

  @override
  String get diveSites_list_emptyFiltered_clearAll => 'Limpar Todos os Filtros';

  @override
  String get diveSites_list_emptyFiltered_subtitle =>
      'Tente ajustar ou limpar seus filtros';

  @override
  String get diveSites_list_emptyFiltered_title =>
      'Nenhum ponto corresponde aos seus filtros';

  @override
  String get diveSites_list_empty_addFirstSite =>
      'Adicionar Seu Primeiro Ponto';

  @override
  String get diveSites_list_empty_import => 'Importar';

  @override
  String get diveSites_list_empty_subtitle =>
      'Adicione pontos de mergulho para acompanhar seus locais favoritos';

  @override
  String get diveSites_list_empty_title => 'Nenhum ponto de mergulho ainda';

  @override
  String diveSites_list_error_loadingSites(Object error) {
    return 'Erro ao carregar pontos: $error';
  }

  @override
  String get diveSites_list_error_retry => 'Tentar Novamente';

  @override
  String get diveSites_list_menu_import => 'Importar';

  @override
  String get diveSites_list_menu_select => 'Selecionar pontos';

  @override
  String get diveSites_list_menu_fillLocationDetails =>
      'Preencher detalhes de localização em falta';

  @override
  String get diveSites_backfill_confirm_title =>
      'Preencher os detalhes de localização em falta?';

  @override
  String diveSites_backfill_confirm_body(int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count locais com coordenadas não têm país, região, cidade ou corpo de água.',
      one:
          '1 local com coordenadas não tem país, região, cidade ou corpo de água.',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutos',
      one: '1 minuto',
    );
    return '$_temp0 O Submersion consultará cada um no OpenStreetMap e preencherá apenas os campos vazios. Demora cerca de $_temp1.';
  }

  @override
  String get diveSites_backfill_confirm_start => 'Iniciar';

  @override
  String get diveSites_backfill_nothingToFill =>
      'Todos os locais com coordenadas já têm os seus detalhes de localização.';

  @override
  String get diveSites_backfill_progress_title =>
      'A preencher detalhes de localização';

  @override
  String diveSites_backfill_progress_count(int done, int total) {
    return '$done de $total';
  }

  @override
  String get diveSites_backfill_cancel => 'Cancelar';

  @override
  String diveSites_backfill_summary(int updated, int unchanged, int failed) {
    return 'Atualizados $updated, inalterados $unchanged, falhados $failed';
  }

  @override
  String get diveSites_backfill_offline =>
      'A consulta de localização não está disponível. Verifique a sua ligação e tente novamente.';

  @override
  String get diveSites_list_search_backTooltip => 'Voltar';

  @override
  String get diveSites_list_search_clearTooltip => 'Limpar Busca';

  @override
  String get diveSites_list_search_emptyHint =>
      'Buscar por nome do ponto, pais ou regiao';

  @override
  String diveSites_list_search_error(Object error) {
    return 'Erro: $error';
  }

  @override
  String diveSites_list_search_noResults(Object query) {
    return 'Nenhum ponto encontrado para \"$query\"';
  }

  @override
  String get diveSites_list_search_placeholder => 'Buscar pontos...';

  @override
  String get diveSites_list_selection_closeTooltip => 'Fechar Selecao';

  @override
  String diveSites_list_selection_count(Object count) {
    return '$count selecionado(s)';
  }

  @override
  String get diveSites_list_selection_deleteTooltip => 'Excluir Selecionados';

  @override
  String get diveSites_list_selection_mergeTooltip => 'Mesclar selecionados';

  @override
  String get diveSites_list_selection_deselectAllTooltip => 'Desmarcar Todos';

  @override
  String get diveSites_list_selection_selectAllTooltip => 'Selecionar Todos';

  @override
  String get diveSites_list_sort_title => 'Ordenar Pontos';

  @override
  String diveSites_list_tile_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos',
      one: '1 mergulho',
    );
    return '$_temp0';
  }

  @override
  String diveSites_list_tile_semantics(Object name) {
    return 'Ponto de mergulho: $name';
  }

  @override
  String get diveSites_list_tooltip_filterSites => 'Filtrar Pontos';

  @override
  String get diveSites_list_tooltip_mapView => 'Visualizacao no Mapa';

  @override
  String get diveSites_list_tooltip_searchSites => 'Buscar Pontos';

  @override
  String get diveSites_list_tooltip_sort => 'Ordenar';

  @override
  String get diveSites_locationPicker_appBar_title => 'Escolher Localizacao';

  @override
  String get diveSites_locationPicker_confirmButton => 'Confirmar';

  @override
  String get diveSites_locationPicker_confirmTooltip =>
      'Confirmar localizacao selecionada';

  @override
  String get diveSites_locationPicker_fab_tooltip => 'Usar minha localizacao';

  @override
  String get diveSites_locationPicker_instruction_locationSelected =>
      'Localizacao selecionada';

  @override
  String get diveSites_locationPicker_instruction_lookingUp =>
      'Buscando localizacao...';

  @override
  String get diveSites_locationPicker_instruction_tapToSelect =>
      'Toque no mapa para selecionar uma localizacao';

  @override
  String get diveSites_locationPicker_label_latitude => 'Latitude';

  @override
  String get diveSites_locationPicker_label_longitude => 'Longitude';

  @override
  String diveSites_locationPicker_semantics_coordinates(
    Object latitude,
    Object longitude,
  ) {
    return 'Coordenadas selecionadas: latitude $latitude, longitude $longitude';
  }

  @override
  String get diveSites_locationPicker_semantics_lookingUp =>
      'Buscando localizacao';

  @override
  String get diveSites_locationPicker_semantics_map =>
      'Mapa interativo para escolher a localizacao de um ponto de mergulho. Toque no mapa para selecionar uma localizacao.';

  @override
  String diveSites_mapContent_error_loadingDiveSites(Object error) {
    return 'Erro ao carregar pontos de mergulho: $error';
  }

  @override
  String get diveSites_map_appBar_title => 'Pontos de Mergulho';

  @override
  String get diveSites_map_builtInSites_add => 'Adicionar aos meus pontos';

  @override
  String get diveSites_map_builtInSites_addError =>
      'Não foi possível adicionar o ponto. Tente novamente.';

  @override
  String get diveSites_map_builtInSites_added => 'Adicionado aos seus pontos';

  @override
  String get diveSites_map_builtInSites_hide => 'Ocultar pontos integrados';

  @override
  String get diveSites_map_builtInSites_off => 'Pontos integrados ocultos';

  @override
  String get diveSites_map_builtInSites_on => 'Pontos integrados visíveis';

  @override
  String get diveSites_map_builtInSites_show => 'Mostrar pontos integrados';

  @override
  String get diveSites_map_empty_description =>
      'Adicione coordenadas aos seus pontos de mergulho para ve-los no mapa';

  @override
  String get diveSites_map_empty_title => 'Nenhum ponto com coordenadas';

  @override
  String diveSites_map_error_loadingSites(Object error) {
    return 'Erro ao carregar pontos: $error';
  }

  @override
  String get diveSites_map_error_retry => 'Tentar Novamente';

  @override
  String diveSites_map_infoCard_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos',
      one: '1 mergulho',
    );
    return '$_temp0';
  }

  @override
  String diveSites_map_semantics_builtInSiteMarker(Object name) {
    return 'Ponto de mergulho integrado: $name';
  }

  @override
  String diveSites_map_semantics_diveSiteMarker(Object name) {
    return 'Ponto de mergulho: $name';
  }

  @override
  String get diveSites_map_tooltip_fitAllSites => 'Ajustar a Todos os Pontos';

  @override
  String get diveSites_map_tooltip_listView => 'Visualizacao em Lista';

  @override
  String get diveSites_summary_action_addSite => 'Adicionar Ponto';

  @override
  String get diveSites_summary_action_import => 'Importar';

  @override
  String get diveSites_summary_action_viewMap => 'Ver Mapa';

  @override
  String diveSites_summary_countriesMore(Object count) {
    return '+ $count mais';
  }

  @override
  String get diveSites_summary_header_subtitle =>
      'Selecione um ponto da lista para ver detalhes';

  @override
  String get diveSites_summary_header_title => 'Pontos de Mergulho';

  @override
  String get diveSites_summary_section_countriesRegions => 'Paises e Regioes';

  @override
  String get diveSites_summary_section_mostDived => 'Mais Mergulhados';

  @override
  String get diveSites_summary_section_overview => 'Visao Geral';

  @override
  String get diveSites_summary_section_quickActions => 'Acoes Rapidas';

  @override
  String get diveSites_summary_section_topRated => 'Melhor Avaliados';

  @override
  String get diveSites_summary_stat_avgRating => 'Avaliacao Media';

  @override
  String get diveSites_summary_stat_totalDives => 'Total de Mergulhos';

  @override
  String get diveSites_summary_stat_totalSites => 'Total de Pontos';

  @override
  String get diveSites_summary_stat_withGps => 'Com GPS';

  @override
  String get diveType_builtin_altitude => 'Altitude';

  @override
  String get diveType_builtin_boat => 'A partir de barco';

  @override
  String get diveType_builtin_cave => 'Gruta';

  @override
  String get diveType_builtin_cavern => 'Caverna';

  @override
  String get diveType_builtin_deep => 'Profundo';

  @override
  String get diveType_builtin_drift => 'Deriva';

  @override
  String get diveType_builtin_freedive => 'Apneia';

  @override
  String get diveType_builtin_ice => 'Gelo';

  @override
  String get diveType_builtin_liveaboard => 'Cruzeiro de mergulho';

  @override
  String get diveType_builtin_night => 'Noturno';

  @override
  String get diveType_builtin_recreational => 'Recreativo';

  @override
  String get diveType_builtin_shore => 'A partir da costa';

  @override
  String get diveType_builtin_technical => 'Técnico';

  @override
  String get diveType_builtin_training => 'Treinamento';

  @override
  String get diveType_builtin_wreck => 'Naufrágio';

  @override
  String get diveTypes_addDialog_addButton => 'Adicionar';

  @override
  String get diveTypes_addDialog_nameHint => 'ex: Busca e Recuperação';

  @override
  String get diveTypes_addDialog_nameLabel => 'Nome do Tipo de Mergulho';

  @override
  String get diveTypes_addDialog_nameValidation => 'Digite um nome';

  @override
  String get diveTypes_addDialog_title =>
      'Adicionar Tipo de Mergulho Personalizado';

  @override
  String get diveTypes_addTooltip => 'Adicionar tipo de mergulho';

  @override
  String get diveTypes_appBar_title => 'Tipos de Mergulho';

  @override
  String get diveTypes_builtIn => 'Integrado';

  @override
  String get diveTypes_builtInHeader => 'Tipos de Mergulho Integrados';

  @override
  String get diveTypes_custom => 'Personalizado';

  @override
  String get diveTypes_customHeader => 'Tipos de Mergulho Personalizados';

  @override
  String diveTypes_deleteDialog_content(Object name) {
    return 'Tem certeza de que deseja excluir \"$name\"?';
  }

  @override
  String get diveTypes_deleteDialog_title => 'Excluir Tipo de Mergulho?';

  @override
  String get diveTypes_deleteTooltip => 'Excluir tipo de mergulho';

  @override
  String diveTypes_snackbar_added(Object name) {
    return 'Tipo de mergulho adicionado: $name';
  }

  @override
  String diveTypes_snackbar_cannotDelete(Object name) {
    return 'Não é possível excluir \"$name\" - está sendo usado por mergulhos existentes';
  }

  @override
  String diveTypes_snackbar_deleted(Object name) {
    return 'Excluído \"$name\"';
  }

  @override
  String diveTypes_snackbar_errorAdding(Object error) {
    return 'Erro ao adicionar tipo de mergulho: $error';
  }

  @override
  String diveTypes_snackbar_errorDeleting(Object error) {
    return 'Erro ao excluir tipo de mergulho: $error';
  }

  @override
  String get divers_detail_activeDiver => 'Mergulhador Ativo';

  @override
  String get divers_detail_allergiesLabel => 'Alergias';

  @override
  String get divers_detail_appBarTitle => 'Mergulhador';

  @override
  String get divers_detail_bloodTypeLabel => 'Tipo Sanguineo';

  @override
  String get divers_detail_bottomTimeLabel => 'Tempo de Fundo';

  @override
  String get divers_detail_cancelButton => 'Cancelar';

  @override
  String get divers_detail_contactTitle => 'Contato';

  @override
  String get divers_detail_defaultLabel => 'Padrao';

  @override
  String get divers_detail_deleteButton => 'Excluir';

  @override
  String divers_detail_deleteDialogContent(Object name) {
    return 'This will permanently delete $name and all associated data including dive logs, dive computers, equipment, certifications, and sites.';
  }

  @override
  String get divers_detail_deleteDialogTitle => 'Excluir Mergulhador?';

  @override
  String divers_detail_deleteError(Object error) {
    return 'Falha ao excluir: $error';
  }

  @override
  String get divers_detail_deleteMenuItem => 'Excluir';

  @override
  String get divers_detail_deletedSnackbar => 'Mergulhador excluido';

  @override
  String get divers_detail_diveInsuranceTitle => 'Seguro de Mergulho';

  @override
  String get divers_detail_diveStatisticsTitle => 'Estatisticas de Mergulho';

  @override
  String get divers_detail_editTooltip => 'Editar mergulhador';

  @override
  String get divers_detail_emergencyContactTitle => 'Contato de Emergencia';

  @override
  String divers_detail_errorPrefix(Object error) {
    return 'Erro: $error';
  }

  @override
  String get divers_detail_expiredBadge => 'Expirado';

  @override
  String get divers_detail_expiresLabel => 'Expira em';

  @override
  String get divers_detail_medicalInfoTitle => 'Informacoes Medicas';

  @override
  String get divers_detail_medicalNotesLabel => 'Notas';

  @override
  String get divers_detail_notFound => 'Mergulhador nao encontrado';

  @override
  String get divers_detail_notesTitle => 'Notas';

  @override
  String get divers_detail_policyNumberLabel => 'Apolice #';

  @override
  String get divers_detail_providerLabel => 'Seguradora';

  @override
  String get divers_detail_setAsDefault => 'Definir como Padrao';

  @override
  String divers_detail_setAsDefaultSnackbar(Object name) {
    return '$name definido como mergulhador padrao';
  }

  @override
  String get divers_detail_switchToTooltip => 'Alternar para este mergulhador';

  @override
  String divers_detail_switchedTo(Object name) {
    return 'Alternado para $name';
  }

  @override
  String get divers_detail_totalDivesLabel => 'Total de Mergulhos';

  @override
  String get divers_detail_unableToLoadStats =>
      'Nao foi possivel carregar estatisticas';

  @override
  String get divers_edit_addButton => 'Adicionar Mergulhador';

  @override
  String get divers_edit_addTitle => 'Adicionar Mergulhador';

  @override
  String get divers_edit_allergiesHint => 'ex., Penicilina, Frutos do mar';

  @override
  String get divers_edit_allergiesLabel => 'Alergias';

  @override
  String get divers_edit_bloodTypeHint => 'ex., O+, A-, B+';

  @override
  String get divers_edit_bloodTypeLabel => 'Tipo Sanguineo';

  @override
  String get divers_edit_cancelButton => 'Cancelar';

  @override
  String get divers_edit_clearInsuranceExpiryTooltip =>
      'Limpar data de vencimento do seguro';

  @override
  String get divers_edit_clearMedicalClearanceTooltip =>
      'Limpar data de liberacao medica';

  @override
  String get divers_edit_contactNameLabel => 'Nome do Contato';

  @override
  String get divers_edit_contactPhoneLabel => 'Telefone do Contato';

  @override
  String get divers_edit_discardButton => 'Descartar';

  @override
  String get divers_edit_discardDialogContent =>
      'Voce tem alteracoes nao salvas. Tem certeza de que deseja descarta-las?';

  @override
  String get divers_edit_discardDialogTitle => 'Descartar Alteracoes?';

  @override
  String get divers_edit_diverAdded => 'Mergulhador adicionado';

  @override
  String get divers_edit_diverUpdated => 'Mergulhador atualizado';

  @override
  String get divers_edit_editTitle => 'Editar Mergulhador';

  @override
  String get divers_edit_emailError => 'Insira um e-mail valido';

  @override
  String get divers_edit_emailLabel => 'E-mail';

  @override
  String get divers_edit_emergencyContactsSection => 'Contatos de Emergencia';

  @override
  String divers_edit_errorLoading(Object error) {
    return 'Erro ao carregar mergulhador: $error';
  }

  @override
  String divers_edit_errorSaving(Object error) {
    return 'Erro ao salvar mergulhador: $error';
  }

  @override
  String get divers_edit_expiryDateNotSet => 'Nao definida';

  @override
  String get divers_edit_expiryDateTitle => 'Data de Validade';

  @override
  String get divers_edit_insuranceProviderHint => 'ex., DAN, DiveAssure';

  @override
  String get divers_edit_insuranceProviderLabel => 'Seguradora';

  @override
  String get divers_edit_insuranceSection => 'Seguro de Mergulho';

  @override
  String get divers_edit_keepEditingButton => 'Continuar Editando';

  @override
  String get divers_edit_medicalClearanceExpired => 'Expirada';

  @override
  String get divers_edit_medicalClearanceExpiringSoon => 'Expirando em Breve';

  @override
  String get divers_edit_medicalClearanceNotSet => 'Nao definida';

  @override
  String get divers_edit_medicalClearanceTitle =>
      'Validade da Liberacao Medica';

  @override
  String get divers_edit_medicalInfoSection => 'Informacoes Medicas';

  @override
  String get divers_edit_medicalNotesLabel => 'Notas Medicas';

  @override
  String get divers_edit_medicationsHint => 'ex., Aspirina diaria, EpiPen';

  @override
  String get divers_edit_medicationsLabel => 'Medicamentos';

  @override
  String get divers_edit_nameError => 'Nome e obrigatorio';

  @override
  String get divers_edit_nameLabel => 'Nome *';

  @override
  String get divers_edit_notesLabel => 'Notas';

  @override
  String get divers_edit_notesSection => 'Notas';

  @override
  String get divers_edit_personalInfoSection => 'Informacoes Pessoais';

  @override
  String get divers_edit_phoneLabel => 'Telefone';

  @override
  String get divers_edit_policyNumberLabel => 'Numero da Apolice';

  @override
  String get divers_edit_primaryContactTitle => 'Contato Principal';

  @override
  String get divers_edit_relationshipHint => 'ex., Conjuge, Pai/Mae, Amigo';

  @override
  String get divers_edit_relationshipLabel => 'Parentesco';

  @override
  String get divers_edit_saveButton => 'Salvar';

  @override
  String get divers_edit_secondaryContactTitle => 'Contato Secundario';

  @override
  String get divers_edit_selectInsuranceExpiryTooltip =>
      'Selecionar data de vencimento do seguro';

  @override
  String get divers_edit_selectMedicalClearanceTooltip =>
      'Selecionar data de liberacao medica';

  @override
  String get divers_edit_updateButton => 'Atualizar Mergulhador';

  @override
  String get divers_list_activeBadge => 'Ativo';

  @override
  String get divers_list_addDiverButton => 'Adicionar Mergulhador';

  @override
  String get divers_list_addDiverTooltip =>
      'Adicionar um novo perfil de mergulhador';

  @override
  String get divers_list_appBarTitle => 'Perfis de Mergulhadores';

  @override
  String get divers_list_compactTitle => 'Mergulhadores';

  @override
  String divers_list_diverStats(Object diveCount, Object bottomTime) {
    return '$diveCount mergulhos$bottomTime';
  }

  @override
  String get divers_list_emptySubtitle =>
      'Adicione perfis de mergulhadores para rastrear registros de mergulho de varias pessoas';

  @override
  String get divers_list_emptyTitle => 'Nenhum mergulhador ainda';

  @override
  String divers_list_errorLoading(Object error) {
    return 'Erro ao carregar mergulhadores: $error';
  }

  @override
  String get divers_list_errorLoadingStats => 'Erro ao carregar estatisticas';

  @override
  String get divers_list_loadingStats => 'Carregando...';

  @override
  String get divers_list_retryButton => 'Tentar novamente';

  @override
  String divers_list_viewDiverLabel(Object name) {
    return 'Ver mergulhador $name';
  }

  @override
  String get divers_summary_activeDiverTitle => 'Mergulhador Ativo';

  @override
  String get divers_summary_otherDiversTitle => 'Outros Mergulhadores';

  @override
  String get divers_summary_overviewTitle => 'Visao Geral';

  @override
  String get divers_summary_quickActionsTitle => 'Acoes Rapidas';

  @override
  String get divers_summary_subtitle =>
      'Selecione um mergulhador da lista para ver detalhes';

  @override
  String get divers_summary_title => 'Perfis de Mergulhadores';

  @override
  String get divers_summary_totalDiversLabel => 'Total de Mergulhadores';

  @override
  String divers_detail_deleteDialogConfirmHint(String name) {
    return 'Type \"Delete $name\" to confirm';
  }

  @override
  String divers_detail_deleteDialogConfirmText(String name) {
    return 'Delete $name';
  }

  @override
  String get enum_altitudeGroup_extreme => 'Altitude Extrema';

  @override
  String get enum_altitudeGroup_extreme_range => '>2700m (>8858ft)';

  @override
  String get enum_altitudeGroup_group1 => 'Grupo de Altitude 1';

  @override
  String get enum_altitudeGroup_group1_range => '300-900m (984-2953ft)';

  @override
  String get enum_altitudeGroup_group2 => 'Grupo de Altitude 2';

  @override
  String get enum_altitudeGroup_group2_range => '900-1800m (2953-5906ft)';

  @override
  String get enum_altitudeGroup_group3 => 'Grupo de Altitude 3';

  @override
  String get enum_altitudeGroup_group3_range => '1800-2700m (5906-8858ft)';

  @override
  String get enum_altitudeGroup_seaLevel => 'Nivel do Mar';

  @override
  String get enum_altitudeGroup_seaLevel_range => '0-300m (0-984ft)';

  @override
  String get enum_ascentRate_danger => 'Perigo';

  @override
  String get enum_ascentRate_safe => 'Seguro';

  @override
  String get enum_ascentRate_warning => 'Alerta';

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
  String get enum_certificationAgency_other => 'Outra';

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
  String get enum_certificationLevel_advancedNitrox => 'Nitrox Avancado';

  @override
  String get enum_certificationLevel_advancedOpenWater => 'Advanced Open Water';

  @override
  String get enum_certificationLevel_cave => 'Caverna';

  @override
  String get enum_certificationLevel_cavern => 'Caverna Rasa';

  @override
  String get enum_certificationLevel_courseDirector => 'Diretor de Curso';

  @override
  String get enum_certificationLevel_decompression => 'Descompressao';

  @override
  String get enum_certificationLevel_diveGuide => 'Guia de Mergulho';

  @override
  String get enum_certificationLevel_diveMaster => 'Divemaster';

  @override
  String get enum_certificationLevel_instructor => 'Instrutor';

  @override
  String get enum_certificationLevel_masterInstructor => 'Instrutor Master';

  @override
  String get enum_certificationLevel_nitrox => 'Nitrox';

  @override
  String get enum_certificationLevel_openWater => 'Open Water';

  @override
  String get enum_certificationLevel_other => 'Outro';

  @override
  String get enum_certificationLevel_rebreather => 'Rebreather';

  @override
  String get enum_certificationLevel_rescue => 'Mergulhador de Resgate';

  @override
  String get enum_certificationLevel_sidemount => 'Sidemount';

  @override
  String get enum_certificationLevel_techDiver => 'Mergulhador Tecnico';

  @override
  String get enum_certificationLevel_trimix => 'Trimix';

  @override
  String get enum_certificationLevel_wreck => 'Naufragio';

  @override
  String get enum_currentDirection_east => 'Leste';

  @override
  String get enum_currentDirection_none => 'Nenhuma';

  @override
  String get enum_currentDirection_north => 'Norte';

  @override
  String get enum_currentDirection_northEast => 'Nordeste';

  @override
  String get enum_currentDirection_northWest => 'Noroeste';

  @override
  String get enum_currentDirection_south => 'Sul';

  @override
  String get enum_currentDirection_southEast => 'Sudeste';

  @override
  String get enum_currentDirection_southWest => 'Sudoeste';

  @override
  String get enum_currentDirection_variable => 'Variavel';

  @override
  String get enum_currentDirection_west => 'Oeste';

  @override
  String get enum_currentStrength_light => 'Fraca';

  @override
  String get enum_currentStrength_moderate => 'Moderada';

  @override
  String get enum_currentStrength_none => 'Nenhuma';

  @override
  String get enum_currentStrength_strong => 'Forte';

  @override
  String get enum_diveMode_ccr => 'Rebreather de Circuito Fechado';

  @override
  String get enum_diveMode_gauge => 'Gauge';

  @override
  String get enum_diveMode_oc => 'Circuito Aberto';

  @override
  String get enum_diveMode_scr => 'Rebreather Semi-Fechado';

  @override
  String get enum_diveType_altitude => 'Altitude';

  @override
  String get enum_diveType_boat => 'Barco';

  @override
  String get enum_diveType_cave => 'Caverna';

  @override
  String get enum_diveType_deep => 'Profundo';

  @override
  String get enum_diveType_drift => 'Deriva';

  @override
  String get enum_diveType_freedive => 'Mergulho Livre';

  @override
  String get enum_diveType_ice => 'Gelo';

  @override
  String get enum_diveType_liveaboard => 'Liveaboard';

  @override
  String get enum_diveType_night => 'Noturno';

  @override
  String get enum_diveType_recreational => 'Recreativo';

  @override
  String get enum_diveType_shore => 'Costeiro';

  @override
  String get enum_diveType_technical => 'Tecnico';

  @override
  String get enum_diveType_training => 'Treinamento';

  @override
  String get enum_diveType_wreck => 'Naufragio';

  @override
  String get enum_entryMethod_backRoll => 'Rolamento para Tras';

  @override
  String get enum_entryMethod_boat => 'Entrada pelo Barco';

  @override
  String get enum_entryMethod_giantStride => 'Passo Gigante';

  @override
  String get enum_entryMethod_jetty => 'Pier/Cais';

  @override
  String get enum_entryMethod_ladder => 'Escada';

  @override
  String get enum_entryMethod_other => 'Outro';

  @override
  String get enum_entryMethod_platform => 'Plataforma';

  @override
  String get enum_entryMethod_seatedEntry => 'Entrada Sentado';

  @override
  String get enum_entryMethod_shore => 'Entrada pela Praia';

  @override
  String get enum_equipmentStatus_active => 'Ativo';

  @override
  String get enum_equipmentStatus_inService => 'Em Manutencao';

  @override
  String get enum_equipmentStatus_loaned => 'Emprestado';

  @override
  String get enum_equipmentStatus_lost => 'Perdido';

  @override
  String get enum_equipmentStatus_needsService => 'Precisa de Manutencao';

  @override
  String get enum_equipmentStatus_retired => 'Aposentado';

  @override
  String get enum_equipmentType_bcd => 'Colete Equilibrador';

  @override
  String get enum_equipmentType_boots => 'Botinhas';

  @override
  String get enum_equipmentType_camera => 'Camera';

  @override
  String get enum_equipmentType_dpv => 'DPV';

  @override
  String get enum_equipmentType_computer => 'Computador de Mergulho';

  @override
  String get enum_equipmentType_drysuit => 'Roupa Seca';

  @override
  String get enum_equipmentType_fins => 'Nadadeiras';

  @override
  String get enum_equipmentType_gloves => 'Luvas';

  @override
  String get enum_equipmentType_hood => 'Capuz';

  @override
  String get enum_equipmentType_knife => 'Faca';

  @override
  String get enum_equipmentType_light => 'Lanterna';

  @override
  String get enum_equipmentType_mask => 'Mascara';

  @override
  String get enum_equipmentType_other => 'Outro';

  @override
  String get enum_equipmentType_reel => 'Carretilha';

  @override
  String get enum_equipmentType_regulator => 'Regulador';

  @override
  String get enum_equipmentType_smb => 'SMB';

  @override
  String get enum_equipmentType_tank => 'Cilindro';

  @override
  String get enum_equipmentType_weights => 'Lastro';

  @override
  String get enum_equipmentType_wetsuit => 'Roupa de Neoprene';

  @override
  String get enum_eventSeverity_alert => 'Alerta';

  @override
  String get enum_eventSeverity_info => 'Info';

  @override
  String get enum_eventSeverity_warning => 'Aviso';

  @override
  String get enum_pdfPageSize_a4 => 'A4';

  @override
  String get enum_pdfPageSize_a4_description => '210 x 297 mm';

  @override
  String get enum_pdfPageSize_letter => 'Carta';

  @override
  String get enum_pdfPageSize_letter_description => '8.5 x 11 in';

  @override
  String get enum_pdfTemplate_detailed => 'Detalhado';

  @override
  String get enum_pdfTemplate_detailed_description =>
      'Informacoes completas do mergulho com notas e avaliacoes';

  @override
  String get enum_pdfTemplate_nauiStyle => 'Estilo NAUI';

  @override
  String get enum_pdfTemplate_nauiStyle_description =>
      'Layout no formato do logbook NAUI';

  @override
  String get enum_pdfTemplate_padiStyle => 'Estilo PADI';

  @override
  String get enum_pdfTemplate_padiStyle_description =>
      'Layout no formato do logbook PADI';

  @override
  String get enum_pdfTemplate_professional => 'Profissional';

  @override
  String get enum_pdfTemplate_professional_description =>
      'Areas de assinatura e carimbo para verificacao';

  @override
  String get enum_pdfTemplate_simple => 'Simples';

  @override
  String get enum_pdfTemplate_simple_description =>
      'Formato de tabela compacta, muitos mergulhos por pagina';

  @override
  String get enum_profileEvent_alert => 'Alerta';

  @override
  String get enum_profileEvent_ascentRateCritical => 'Taxa de Subida Critica';

  @override
  String get enum_profileEvent_ascentRateWarning => 'Aviso de Taxa de Subida';

  @override
  String get enum_profileEvent_ascentStart => 'Inicio da Subida';

  @override
  String get enum_profileEvent_bookmark => 'Marcador';

  @override
  String get enum_profileEvent_cnsCritical => 'CNS Critico';

  @override
  String get enum_profileEvent_cnsWarning => 'Aviso de CNS';

  @override
  String get enum_profileEvent_decoStopEnd => 'Fim da Parada Deco';

  @override
  String get enum_profileEvent_decoStopStart => 'Inicio da Parada Deco';

  @override
  String get enum_profileEvent_decoViolation => 'Violacao de Deco';

  @override
  String get enum_profileEvent_gasSwitch => 'Troca de Gas';

  @override
  String get enum_profileEvent_lowGas => 'Aviso de Gas Baixo';

  @override
  String get enum_profileEvent_maxDepth => 'Profundidade Maxima';

  @override
  String get enum_profileEvent_missedStop => 'Parada Deco Perdida';

  @override
  String get enum_profileEvent_note => 'Nota';

  @override
  String get enum_profileEvent_ppO2High => 'ppO2 Alto';

  @override
  String get enum_profileEvent_ppO2Low => 'ppO2 Baixo';

  @override
  String get enum_profileEvent_safetyStopEnd => 'Fim da Parada de Seguranca';

  @override
  String get enum_profileEvent_safetyStopStart =>
      'Inicio da Parada de Seguranca';

  @override
  String get enum_profileEvent_setpointChange => 'Mudanca de Setpoint';

  @override
  String get enum_profileMetricCategory_decompression => 'Descompressao';

  @override
  String get enum_profileMetricCategory_gasAnalysis => 'Analise de Gas';

  @override
  String get enum_profileMetricCategory_gradientFactor =>
      'Fatores de Gradiente';

  @override
  String get enum_profileMetricCategory_other => 'Outros';

  @override
  String get enum_profileMetricCategory_primary => 'Metricas Principais';

  @override
  String get enum_profileMetric_gasDensity => 'Densidade do Gas';

  @override
  String get enum_profileMetric_gasDensity_short => 'Densidade';

  @override
  String get enum_profileMetric_gf => 'GF%';

  @override
  String get enum_profileMetric_gf_short => 'GF%';

  @override
  String get enum_profileMetric_heartRate => 'Frequencia Cardiaca';

  @override
  String get enum_profileMetric_heartRate_short => 'FC';

  @override
  String get enum_profileMetric_meanDepth => 'Profundidade Media';

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
  String get enum_profileMetric_pressure => 'Pressao';

  @override
  String get enum_profileMetric_pressure_short => 'Press';

  @override
  String get enum_profileMetric_sacRate => 'Taxa SAC';

  @override
  String get enum_profileMetric_sacRate_short => 'SAC';

  @override
  String get enum_profileMetric_surfaceGf => 'GF de Superficie';

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
  String get enum_scrType_cmf => 'Fluxo de Massa Constante';

  @override
  String get enum_scrType_cmf_short => 'CMF';

  @override
  String get enum_scrType_escr => 'Controlado Eletronicamente';

  @override
  String get enum_scrType_escr_short => 'ESCR';

  @override
  String get enum_scrType_pascr => 'Adicao Passiva';

  @override
  String get enum_scrType_pascr_short => 'PASCR';

  @override
  String get enum_serviceType_annual => 'Revisao Anual';

  @override
  String get enum_serviceType_calibration => 'Calibracao';

  @override
  String get enum_serviceType_cleaning => 'Limpeza';

  @override
  String get enum_serviceType_inspection => 'Inspecao';

  @override
  String get enum_serviceType_other => 'Outro';

  @override
  String get enum_serviceType_overhaul => 'Revisao Geral';

  @override
  String get enum_serviceType_recall => 'Recall/Seguranca';

  @override
  String get enum_serviceType_repair => 'Reparo';

  @override
  String get enum_serviceType_replacement => 'Substituicao de Peca';

  @override
  String get enum_serviceType_warranty => 'Servico de Garantia';

  @override
  String get enum_sortDirection_ascending => 'Crescente';

  @override
  String get enum_sortDirection_descending => 'Decrescente';

  @override
  String get enum_sortField_agency => 'Certificadora';

  @override
  String get enum_sortField_date => 'Data';

  @override
  String get enum_sortField_dateIssued => 'Data de Emissao';

  @override
  String get enum_sortField_dateTaken => 'Data da captura';

  @override
  String get enum_sortField_difficulty => 'Dificuldade';

  @override
  String get enum_sortField_diveCount => 'Numero de Mergulhos';

  @override
  String get enum_sortField_diveNumber => 'Numero do Mergulho';

  @override
  String get enum_sortField_duration => 'Duracao';

  @override
  String get enum_sortField_endDate => 'Data Final';

  @override
  String get enum_sortField_fileName => 'Nome do arquivo';

  @override
  String get enum_sortField_fileSize => 'Tamanho do arquivo';

  @override
  String get enum_sortField_lastServiceDate => 'Ultima Manutencao';

  @override
  String get enum_sortField_maxDepth => 'Profundidade Maxima';

  @override
  String get enum_sortField_name => 'Nome';

  @override
  String get enum_sortField_purchaseDate => 'Data de Compra';

  @override
  String get enum_sortField_rating => 'Avaliacao';

  @override
  String get enum_sortField_site => 'Ponto de Mergulho';

  @override
  String get enum_sortField_startDate => 'Data Inicial';

  @override
  String get enum_sortField_status => 'Status';

  @override
  String get enum_sortField_type => 'Tipo';

  @override
  String get enum_speciesCategory_coral => 'Coral';

  @override
  String get enum_speciesCategory_fish => 'Peixe';

  @override
  String get enum_speciesCategory_invertebrate => 'Invertebrado';

  @override
  String get enum_speciesCategory_mammal => 'Mamifero';

  @override
  String get enum_speciesCategory_other => 'Outro';

  @override
  String get enum_speciesCategory_plant => 'Planta/Alga';

  @override
  String get enum_speciesCategory_ray => 'Raia';

  @override
  String get enum_speciesCategory_shark => 'Tubarao';

  @override
  String get enum_speciesCategory_turtle => 'Tartaruga';

  @override
  String get enum_tankMaterial_aluminum => 'Aluminio';

  @override
  String get enum_tankMaterial_carbonFiber => 'Fibra de Carbono';

  @override
  String get enum_tankMaterial_steel => 'Aco';

  @override
  String get enum_tankRole_backGas => 'Gas Principal';

  @override
  String get enum_tankRole_bailout => 'Bailout';

  @override
  String get enum_tankRole_deco => 'Deco';

  @override
  String get enum_tankRole_diluent => 'Diluente';

  @override
  String get enum_tankRole_oxygenSupply => 'Suprimento de O₂';

  @override
  String get enum_tankRole_pony => 'Cilindro Pony';

  @override
  String get enum_tankRole_sidemountLeft => 'Sidemount Esquerdo';

  @override
  String get enum_tankRole_sidemountRight => 'Sidemount Direito';

  @override
  String get enum_tankRole_stage => 'Stage';

  @override
  String get enum_visibility_excellent => 'Excelente (>30m / >100ft)';

  @override
  String get enum_visibility_good => 'Boa (15-30m / 50-100ft)';

  @override
  String get enum_visibility_moderate => 'Moderada (5-15m / 15-50ft)';

  @override
  String get enum_visibility_poor => 'Ruim (<5m / <15ft)';

  @override
  String get enum_visibility_unknown => 'Desconhecida';

  @override
  String get enum_waterType_brackish => 'Salobra';

  @override
  String get enum_waterType_fresh => 'Agua Doce';

  @override
  String get enum_waterType_salt => 'Agua Salgada';

  @override
  String get enum_weightType_ankleWeights => 'Lastro de Tornozelo';

  @override
  String get enum_weightType_backplate => 'Lastro na Backplate';

  @override
  String get enum_weightType_belt => 'Cinto de Lastro';

  @override
  String get enum_weightType_integrated => 'Lastro Integrado';

  @override
  String get enum_weightType_mixed => 'Misto/Combinado';

  @override
  String get enum_weightType_trimWeights => 'Lastro de Trim';

  @override
  String get equipment_appBar_title => 'Equipamento';

  @override
  String get equipment_deleteDialog_cancel => 'Cancelar';

  @override
  String get equipment_deleteDialog_confirm => 'Excluir';

  @override
  String get equipment_deleteDialog_content =>
      'Tem certeza de que deseja excluir este equipamento? Esta acao nao pode ser desfeita.';

  @override
  String get equipment_deleteDialog_title => 'Excluir Equipamento';

  @override
  String get equipment_detail_brandLabel => 'Marca';

  @override
  String equipment_detail_daysOverdue(Object days) {
    return '$days dias em atraso';
  }

  @override
  String equipment_detail_daysUntilService(Object days) {
    return '$days dias ate a manutencao';
  }

  @override
  String get equipment_detail_detailsTitle => 'Detalhes';

  @override
  String equipment_detail_divesCountPlural(Object count) {
    return '$count mergulhos';
  }

  @override
  String equipment_detail_divesCountSingular(Object count) {
    return '$count mergulho';
  }

  @override
  String get equipment_detail_divesLabel => 'Mergulhos';

  @override
  String get equipment_detail_divesSemanticLabel =>
      'Ver mergulhos usando este equipamento';

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
  String get equipment_detail_editTooltip => 'Editar Equipamento';

  @override
  String get equipment_detail_editTooltipShort => 'Editar';

  @override
  String equipment_detail_errorMessage(Object error) {
    return 'Erro: $error';
  }

  @override
  String get equipment_detail_errorTitle => 'Erro';

  @override
  String get equipment_detail_lastServiceLabel => 'Ultima Manutencao';

  @override
  String get equipment_detail_loadingTitle => 'Carregando...';

  @override
  String get equipment_detail_modelLabel => 'Modelo';

  @override
  String get equipment_detail_nextServiceDueLabel => 'Proxima Manutencao';

  @override
  String get equipment_detail_notFoundMessage =>
      'Este item de equipamento nao existe mais.';

  @override
  String get equipment_detail_notFoundTitle => 'Equipamento Nao Encontrado';

  @override
  String get equipment_detail_notesTitle => 'Observacoes';

  @override
  String get equipment_detail_ownedForLabel => 'Tempo de Posse';

  @override
  String get equipment_detail_purchaseDateLabel => 'Data de Compra';

  @override
  String get equipment_detail_purchasePriceLabel => 'Preco de Compra';

  @override
  String get equipment_detail_retiredChip => 'Aposentado';

  @override
  String get equipment_detail_serialNumberLabel => 'Numero de Serie';

  @override
  String get equipment_detail_serviceInfoTitle => 'Informacoes de Manutencao';

  @override
  String get equipment_serviceClocks_title => 'Prazos de manutenção';

  @override
  String get equipment_serviceClocks_addClock => 'Adicionar prazo';

  @override
  String get equipment_serviceClocks_logService => 'Registrar manutenção';

  @override
  String get equipment_serviceClocks_edit => 'Editar intervalos';

  @override
  String get equipment_serviceClocks_pause => 'Pausar';

  @override
  String get equipment_serviceClocks_resume => 'Retomar';

  @override
  String get equipment_serviceClocks_remove => 'Remover';

  @override
  String get equipment_serviceClocks_paused => 'Pausado';

  @override
  String get equipment_serviceClocks_empty => 'Nenhum prazo de manutenção';

  @override
  String get equipment_serviceClocks_unconfigured =>
      'Nenhum intervalo definido - toque para configurar';

  @override
  String equipment_serviceClocks_dueOn(String date) {
    return 'Vence em $date';
  }

  @override
  String equipment_serviceClocks_overdueSince(String date) {
    return 'Atrasado desde $date';
  }

  @override
  String get equipment_serviceClocks_overdue => 'Atrasado';

  @override
  String equipment_serviceClocks_divesLeft(int remaining, int total) {
    return 'Restam $remaining de $total mergulhos';
  }

  @override
  String get cylinderConfigs_title => 'Configurações de garrafas';

  @override
  String get cylinderConfigs_empty => 'Ainda sem configurações';

  @override
  String get cylinderConfigs_emptyBody =>
      'Guarde uma montagem de diluente e bailout uma vez e aplique-a a qualquer mergulho.';

  @override
  String get cylinderConfigs_new => 'Nova configuração';

  @override
  String get cylinderConfigs_name => 'Nome';

  @override
  String get cylinderConfigs_nameRequired => 'Introduza um nome';

  @override
  String get cylinderConfigs_forUnit => 'Para a unidade';

  @override
  String get cylinderConfigs_noUnit => 'Plano de gás genérico';

  @override
  String get cylinderConfigs_gasPlans => 'Planos de gás';

  @override
  String get cylinderConfigs_addCylinder => 'Adicionar garrafa';

  @override
  String get cylinderConfigs_role => 'Função';

  @override
  String get cylinderConfigs_startPressure => 'Pressão inicial';

  @override
  String get cylinderConfigs_label => 'Etiqueta';

  @override
  String get cylinderConfigs_fromPreset => 'A partir de predefinição';

  @override
  String get cylinderConfigs_deleteTitle => 'Eliminar a configuração?';

  @override
  String get cylinderConfigs_deleteBody =>
      'Os mergulhos onde já foi aplicada não são alterados.';

  @override
  String get cylinderConfigs_applyAction => 'Aplicar configuração';

  @override
  String cylinderConfigs_applyAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count garrafas adicionadas',
      one: '1 garrafa adicionada',
    );
    return '$_temp0';
  }

  @override
  String cylinderConfigs_applyKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mantidas',
      one: '1 mantida',
    );
    return '$_temp0';
  }

  @override
  String get cylinderConfigs_applyNothingToDo =>
      'Este mergulho já corresponde à configuração';

  @override
  String get cylinderConfigs_sectionTitle => 'Configurações';

  @override
  String get equipment_serviceClocks_hoursSource =>
      'Calculado a partir do tempo de mergulho registado';

  @override
  String equipment_serviceClocks_hoursLeft(String remaining, String total) {
    return 'Restam $remaining de $total horas';
  }

  @override
  String get equipment_serviceClocks_manageKinds =>
      'Gerenciar tipos de manutenção';

  @override
  String get equipment_serviceClocks_appliesToClock => 'Aplica-se ao prazo';

  @override
  String get equipment_serviceClocks_noClockOption =>
      'Não vinculado a um prazo';

  @override
  String get equipment_scheduleDialog_title => 'Editar prazo';

  @override
  String get equipment_scheduleDialog_intervalDays => 'Intervalo (dias)';

  @override
  String get equipment_scheduleDialog_intervalDives => 'Intervalo (mergulhos)';

  @override
  String get equipment_scheduleDialog_intervalHours => 'Intervalo (horas)';

  @override
  String equipment_scheduleDialog_inheritHint(String value) {
    return 'Padrão: $value';
  }

  @override
  String get equipment_scheduleDialog_anchorDate => 'Data de referência';

  @override
  String get equipment_scheduleDialog_anchorHint =>
      'Usada quando ainda não existe nenhum registro de manutenção deste tipo';

  @override
  String get equipment_scheduleDialog_clearAnchor =>
      'Limpar data de referência';

  @override
  String get equipment_scheduleDialog_save => 'Salvar';

  @override
  String get equipment_scheduleDialog_cancel => 'Cancelar';

  @override
  String get equipment_serviceKinds_title => 'Tipos de manutenção';

  @override
  String get equipment_serviceKinds_builtIn => 'Integrados';

  @override
  String get equipment_serviceKinds_custom => 'Personalizados';

  @override
  String get equipment_serviceKinds_add => 'Adicionar tipo de manutenção';

  @override
  String get equipment_serviceKinds_editTitle => 'Editar tipo de manutenção';

  @override
  String get equipment_serviceKinds_nameLabel => 'Nome';

  @override
  String get equipment_serviceKinds_nameRequired => 'O nome é obrigatório';

  @override
  String get equipment_serviceKinds_appliesTo => 'Aplica-se a';

  @override
  String get equipment_serviceKinds_autoAttach =>
      'Associar automaticamente a equipamentos novos';

  @override
  String get equipment_serviceKinds_deleteConfirmTitle =>
      'Excluir tipo de manutenção?';

  @override
  String get equipment_serviceKinds_deleteConfirmBody =>
      'Os prazos que usam este tipo de manutenção serão removidos.';

  @override
  String get equipment_serviceKinds_delete => 'Excluir';

  @override
  String get equipment_serviceKinds_cancel => 'Cancelar';

  @override
  String get equipment_serviceKinds_save => 'Salvar';

  @override
  String get equipment_serviceKinds_emptyCustom =>
      'Ainda não há tipos de manutenção personalizados';

  @override
  String equipment_serviceKinds_everyDays(int days) {
    return 'a cada $days dias';
  }

  @override
  String equipment_serviceKinds_everyDives(int dives) {
    return 'a cada $dives mergulhos';
  }

  @override
  String equipment_serviceKinds_everyHours(String hours) {
    return 'a cada $hours horas';
  }

  @override
  String get dashboard_serviceDue_title => 'Manutenção pendente';

  @override
  String dashboard_serviceDue_more(int count) {
    return '+$count mais';
  }

  @override
  String dashboard_alerts_clockDue(String name, String kind) {
    return '$name: $kind pendente';
  }

  @override
  String dashboard_alerts_clockOverdue(String name, String kind) {
    return '$name: $kind em atraso';
  }

  @override
  String equipment_list_worstClock(String kind) {
    return '$kind em atraso';
  }

  @override
  String trips_serviceAlert_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count equipamentos precisam de manutenção antes desta viagem',
      one: '1 equipamento precisa de manutenção antes desta viagem',
    );
    return '$_temp0';
  }

  @override
  String trips_serviceAlert_dueBefore(String kind, String date) {
    return '$kind vence em $date';
  }

  @override
  String trips_serviceAlert_overdue(String kind) {
    return '$kind em atraso';
  }

  @override
  String get settings_notifications_tripLeadTitle =>
      'Antecedência do aviso de manutenção para viagens';

  @override
  String settings_notifications_tripLeadDays(int days) {
    return '$days dias antes de uma viagem';
  }

  @override
  String get equipment_detail_serviceIntervalLabel => 'Intervalo de Manutencao';

  @override
  String equipment_detail_serviceIntervalValue(Object days) {
    return '$days dias';
  }

  @override
  String get equipment_detail_serviceOverdue => 'Manutencao em atraso!';

  @override
  String get equipment_detail_sizeLabel => 'Tamanho';

  @override
  String get equipment_detail_thicknessLabel => 'Espessura';

  @override
  String get equipment_detail_statusLabel => 'Status';

  @override
  String equipment_detail_tripsCountPlural(Object count) {
    return '$count viagens';
  }

  @override
  String equipment_detail_tripsCountSingular(Object count) {
    return '$count viagem';
  }

  @override
  String get equipment_detail_tripsLabel => 'Viagens';

  @override
  String get equipment_detail_tripsSemanticLabel =>
      'Ver viagens usando este equipamento';

  @override
  String get equipment_edit_appBar_editTitle => 'Editar Equipamento';

  @override
  String get equipment_edit_appBar_newTitle => 'Novo Equipamento';

  @override
  String get equipment_edit_appBar_saveButton => 'Salvar';

  @override
  String get equipment_edit_appBar_saveTooltip =>
      'Salvar alteracoes do equipamento';

  @override
  String get equipment_edit_brandLabel => 'Marca';

  @override
  String get equipment_edit_clearDate => 'Limpar Data';

  @override
  String get equipment_edit_currencyLabel => 'Moeda';

  @override
  String get equipment_edit_disableReminders => 'Desativar Lembretes';

  @override
  String get equipment_edit_disableRemindersSubtitle =>
      'Desativar todas as notificacoes para este item';

  @override
  String get equipment_edit_discardDialog_content =>
      'Voce tem alteracoes nao salvas. Tem certeza de que deseja sair?';

  @override
  String get equipment_edit_discardDialog_discard => 'Descartar';

  @override
  String get equipment_edit_discardDialog_keepEditing => 'Continuar Editando';

  @override
  String get equipment_edit_discardDialog_title => 'Descartar Alteracoes?';

  @override
  String get equipment_edit_embeddedHeader_cancelButton => 'Cancelar';

  @override
  String get equipment_edit_embeddedHeader_editTitle => 'Editar Equipamento';

  @override
  String get equipment_edit_embeddedHeader_newTitle => 'Novo Equipamento';

  @override
  String get equipment_edit_embeddedHeader_saveButton => 'Salvar';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_edit =>
      'Salvar alteracoes do equipamento';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_new =>
      'Adicionar novo equipamento';

  @override
  String equipment_edit_errorMessage(Object error) {
    return 'Erro: $error';
  }

  @override
  String get equipment_edit_errorTitle => 'Erro';

  @override
  String get equipment_edit_lastServiceDateLabel => 'Data da Ultima Manutencao';

  @override
  String get equipment_edit_loadingTitle => 'Carregando...';

  @override
  String get equipment_edit_modelLabel => 'Modelo';

  @override
  String get equipment_edit_nameHint => 'ex., Meu Regulador Principal';

  @override
  String get equipment_edit_nameLabel => 'Nome *';

  @override
  String get equipment_edit_nameValidation => 'Por favor, insira um nome';

  @override
  String get equipment_edit_notFoundMessage =>
      'Este item de equipamento nao existe mais.';

  @override
  String get equipment_edit_notFoundTitle => 'Equipamento Nao Encontrado';

  @override
  String get equipment_edit_notesHint =>
      'Observacoes adicionais sobre este equipamento...';

  @override
  String get equipment_edit_notesLabel => 'Observacoes';

  @override
  String get equipment_edit_notificationsSubtitle =>
      'Substituir configuracoes globais de notificacao para este item';

  @override
  String get equipment_edit_notificationsTitle => 'Notificacoes (Opcional)';

  @override
  String get equipment_edit_purchaseDateLabel => 'Data de Compra';

  @override
  String get equipment_edit_purchaseInfoTitle => 'Informacoes de Compra';

  @override
  String get equipment_edit_purchasePriceLabel => 'Preco de Compra';

  @override
  String get equipment_edit_purchasePriceValidation => 'Insira um valor valido';

  @override
  String get equipment_edit_remindMeBeforeServiceDue =>
      'Lembrar-me antes da manutencao:';

  @override
  String equipment_edit_reminderDays(Object days) {
    return '$days dias';
  }

  @override
  String get equipment_edit_saveButton_edit => 'Salvar Alteracoes';

  @override
  String get equipment_edit_saveButton_new => 'Adicionar Equipamento';

  @override
  String get equipment_edit_saveTooltip_edit =>
      'Salvar alteracoes do equipamento';

  @override
  String get equipment_edit_saveTooltip_new =>
      'Adicionar novo item de equipamento';

  @override
  String get equipment_edit_selectDate => 'Selecionar Data';

  @override
  String get equipment_edit_serialNumberLabel => 'Numero de Serie';

  @override
  String get equipment_edit_serviceIntervalHint => 'ex., 365 para anualmente';

  @override
  String get equipment_edit_serviceIntervalLabel =>
      'Intervalo de Manutencao (dias)';

  @override
  String get equipment_edit_serviceSettingsTitle =>
      'Configuracoes de Manutencao';

  @override
  String get equipment_edit_sizeHint => 'ex., M, G, 42';

  @override
  String get equipment_edit_sizeLabel => 'Tamanho';

  @override
  String get equipment_edit_snackbar_added => 'Equipamento adicionado';

  @override
  String equipment_edit_snackbar_error(Object error) {
    return 'Erro ao salvar equipamento: $error';
  }

  @override
  String get equipment_edit_snackbar_updated => 'Equipamento atualizado';

  @override
  String get equipment_edit_statusLabel => 'Status';

  @override
  String get equipment_edit_thicknessDesignationHint => 'ex: 5, 5/4, 7/5/3';

  @override
  String get equipment_edit_thicknessHint => 'ex: 5mm, 7mm';

  @override
  String get equipment_edit_thicknessLabel => 'Espessura';

  @override
  String get equipment_edit_typeLabel => 'Tipo *';

  @override
  String get equipment_edit_useCustomReminders =>
      'Usar Lembretes Personalizados';

  @override
  String get equipment_edit_useCustomRemindersSubtitle =>
      'Definir dias de lembrete diferentes para este item';

  @override
  String get equipment_fab_addEquipment => 'Adicionar Equipamento';

  @override
  String get equipment_fab_addSet => 'Adicionar Conjunto';

  @override
  String get equipment_list_emptyState_addFirstButton =>
      'Adicionar Seu Primeiro Equipamento';

  @override
  String get equipment_list_emptyState_addPrompt =>
      'Adicione seu equipamento de mergulho para acompanhar uso e manutencao';

  @override
  String get equipment_list_emptyState_filterText_equipment => 'equipamento';

  @override
  String get equipment_list_emptyState_filterText_serviceDue =>
      'equipamento com manutencao pendente';

  @override
  String equipment_list_emptyState_filterText_status(Object status) {
    return 'equipamento $status';
  }

  @override
  String equipment_list_emptyState_noEquipment(Object filterText) {
    return 'Nenhum $filterText';
  }

  @override
  String get equipment_list_emptyState_noStatusMatch =>
      'Nenhum equipamento com este status';

  @override
  String get equipment_list_emptyState_serviceDueUpToDate =>
      'Todo o seu equipamento esta em dia com a manutencao!';

  @override
  String equipment_list_errorLoading(Object error) {
    return 'Erro ao carregar equipamento: $error';
  }

  @override
  String get equipment_list_filterAll => 'Todos os Equipamentos';

  @override
  String get equipment_list_filterLabel => 'Filtro:';

  @override
  String get equipment_list_filterServiceDue => 'Manutencao Pendente';

  @override
  String get equipment_list_retryButton => 'Tentar Novamente';

  @override
  String get equipment_list_searchTooltip => 'Buscar Equipamento';

  @override
  String get equipment_list_setsTooltip => 'Conjuntos de Equipamento';

  @override
  String get equipment_list_sortTitle => 'Ordenar Equipamento';

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
      other: 'Manutencao em $days dias',
      one: 'Manutencao em 1 dia',
    );
    return '$_temp0';
  }

  @override
  String get equipment_list_tile_serviceDueChip => 'Manutencao Pendente';

  @override
  String get equipment_list_tile_serviceIn => 'Manutencao em';

  @override
  String get equipment_menu_delete => 'Excluir';

  @override
  String get equipment_menu_markAsServiced => 'Marcar como Revisado';

  @override
  String get equipment_menu_reactivate => 'Reativar';

  @override
  String get equipment_menu_retireEquipment => 'Aposentar Equipamento';

  @override
  String get equipment_search_backTooltip => 'Voltar';

  @override
  String get equipment_search_clearTooltip => 'Limpar Busca';

  @override
  String get equipment_search_fieldLabel => 'Buscar equipamento...';

  @override
  String get equipment_search_hint =>
      'Buscar por nome, marca, modelo ou numero de serie';

  @override
  String equipment_search_noResults(Object query) {
    return 'Nenhum equipamento encontrado para \"$query\"';
  }

  @override
  String get equipment_serviceDialog_addButton => 'Adicionar';

  @override
  String get equipment_serviceDialog_addTitle =>
      'Adicionar Registro de Manutencao';

  @override
  String get equipment_serviceDialog_cancelButton => 'Cancelar';

  @override
  String get equipment_serviceDialog_clearNextServiceDateTooltip =>
      'Limpar Data da Proxima Manutencao';

  @override
  String get equipment_serviceDialog_costHint => '0,00';

  @override
  String get equipment_serviceDialog_costLabel => 'Custo';

  @override
  String get equipment_serviceDialog_currencyLabel => 'Moeda';

  @override
  String get equipment_serviceDialog_costValidation => 'Insira um valor valido';

  @override
  String get equipment_serviceDialog_editTitle =>
      'Editar Registro de Manutencao';

  @override
  String get equipment_serviceDialog_nextServiceDueLabel =>
      'Proxima Manutencao';

  @override
  String get equipment_serviceDialog_nextServiceDueSemanticLabel =>
      'Selecionar data da proxima manutencao';

  @override
  String get equipment_serviceDialog_nextServiceNotSet => 'Nao definida';

  @override
  String get equipment_serviceDialog_notesLabel => 'Observacoes';

  @override
  String get equipment_serviceDialog_providerHint =>
      'ex., Nome da Loja de Mergulho';

  @override
  String get equipment_serviceDialog_providerLabel => 'Fornecedor/Loja';

  @override
  String get equipment_serviceDialog_serviceDateLabel => 'Data da Manutencao';

  @override
  String get equipment_serviceDialog_serviceDateSemanticLabel =>
      'Selecionar data da manutencao';

  @override
  String get equipment_serviceDialog_serviceTypeLabel => 'Tipo de manutenção';

  @override
  String get equipment_serviceDialog_serviceTypeHelper =>
      'Registá-la reinicia o contador deste tipo de manutenção';

  @override
  String get equipment_serviceDialog_serviceTypeRequired =>
      'Escolha um tipo de manutenção';

  @override
  String get equipment_serviceDialog_serviceTypeNotSet => 'Não definido';

  @override
  String get equipment_serviceDialog_categoryHelper =>
      'Usada para filtrar e exportar';

  @override
  String get equipment_serviceDialog_manageServiceTypes =>
      'Gerir tipos de manutenção';

  @override
  String get equipment_serviceDialog_categoryLabel => 'Categoria';

  @override
  String get equipment_serviceDialog_snackbar_added =>
      'Registro de manutencao adicionado';

  @override
  String equipment_serviceDialog_snackbar_error(Object error) {
    return 'Erro: $error';
  }

  @override
  String get equipment_serviceDialog_snackbar_updated =>
      'Registro de manutencao atualizado';

  @override
  String get equipment_serviceDialog_updateButton => 'Atualizar';

  @override
  String get equipment_serviceCategory_annual => 'Manutenção anual';

  @override
  String get equipment_serviceCategory_repair => 'Reparação';

  @override
  String get equipment_serviceCategory_inspection => 'Inspeção';

  @override
  String get equipment_serviceCategory_overhaul => 'Revisão geral';

  @override
  String get equipment_serviceCategory_replacement => 'Substituição de peças';

  @override
  String get equipment_serviceCategory_cleaning => 'Limpeza';

  @override
  String get equipment_serviceCategory_calibration => 'Calibração';

  @override
  String get equipment_serviceCategory_warranty => 'Serviço em garantia';

  @override
  String get equipment_serviceCategory_recall => 'Recolha/Segurança';

  @override
  String get equipment_serviceCategory_other => 'Outro';

  @override
  String get equipment_service_addButton => 'Adicionar';

  @override
  String get equipment_service_deleteDialog_cancel => 'Cancelar';

  @override
  String get equipment_service_deleteDialog_confirm => 'Excluir';

  @override
  String equipment_service_deleteDialog_content(Object serviceType) {
    return 'Tem certeza de que deseja excluir este registro de $serviceType?';
  }

  @override
  String get equipment_service_deleteDialog_title =>
      'Excluir Registro de Manutencao?';

  @override
  String get equipment_service_deleteMenuItem => 'Excluir';

  @override
  String get equipment_service_editMenuItem => 'Editar';

  @override
  String get equipment_service_emptyState =>
      'Nenhum registro de manutencao ainda';

  @override
  String get equipment_service_historyTitle => 'Historico de Manutencao';

  @override
  String equipment_service_nextDueLabel(String date) {
    return 'Próximo vencimento $date';
  }

  @override
  String get equipment_service_filterTaskAll => 'Todas as tarefas';

  @override
  String get equipment_service_filterTypeAll => 'Todos os tipos';

  @override
  String get equipment_service_filterYearAll => 'Todos os anos';

  @override
  String get equipment_service_filterUntagged => 'Sem intervalo associado';

  @override
  String get equipment_service_filterClear => 'Limpar filtro';

  @override
  String get equipment_service_filterNoMatches =>
      'Nenhuma manutenção corresponde a este filtro';

  @override
  String equipment_service_filterMatchCount(int count, int total) {
    return '$count de $total exibidos';
  }

  @override
  String get equipment_serviceKinds_defaultCategoryLabel => 'Categoria padrão';

  @override
  String get equipment_serviceKinds_defaultCategoryNone => 'Sem padrão';

  @override
  String get equipment_serviceKinds_defaultCostLabel => 'Preço padrão';

  @override
  String get equipment_serviceKinds_defaultCostHint =>
      'Deixe em branco para nenhum valor padrão';

  @override
  String get equipment_scheduleDialog_defaultCostLabel =>
      'Preço padrão para este equipamento';

  @override
  String get equipment_serviceKinds_defaultCurrencyLabel => 'Moeda';

  @override
  String get equipment_service_exportMenuItem =>
      'Exportar registo de manutenção';

  @override
  String get transfer_export_maintenanceTitle => 'Registo de manutenção';

  @override
  String get transfer_export_maintenanceSubtitle =>
      'Histórico de manutenção de todo o equipamento numa folha de cálculo';

  @override
  String get settings_export_progress_maintenance =>
      'A exportar o registo de manutenção...';

  @override
  String get settings_export_success_maintenance =>
      'Registo de manutenção exportado';

  @override
  String get settings_export_saved_maintenance =>
      'Registo de manutenção guardado';

  @override
  String get equipment_serviceKinds_defaultCurrencyInherit =>
      'Usar a moeda padrão';

  @override
  String get equipment_scheduleDialog_defaultCurrencyLabel =>
      'Moeda para este equipamento';

  @override
  String get equipment_service_snackbar_deleted =>
      'Registro de manutencao excluido';

  @override
  String get equipment_service_totalCostLabel => 'Custo Total de Manutencao';

  @override
  String get equipment_setDetail_addEquipmentButton => 'Adicionar Equipamento';

  @override
  String get equipment_setDetail_deleteDialog_cancel => 'Cancelar';

  @override
  String get equipment_setDetail_deleteDialog_confirm => 'Excluir';

  @override
  String get equipment_setDetail_deleteDialog_content =>
      'Tem certeza de que deseja excluir este conjunto de equipamentos? Os itens de equipamento do conjunto nao serao excluidos.';

  @override
  String get equipment_setDetail_deleteDialog_title =>
      'Excluir Conjunto de Equipamentos';

  @override
  String get equipment_setDetail_deleteMenuItem => 'Excluir';

  @override
  String get equipment_setDetail_editTooltip => 'Editar Conjunto';

  @override
  String get equipment_setDetail_emptySet =>
      'Nenhum equipamento neste conjunto';

  @override
  String get equipment_setDetail_equipmentInSetTitle =>
      'Equipamentos neste Conjunto';

  @override
  String equipment_setDetail_errorMessage(Object error) {
    return 'Erro: $error';
  }

  @override
  String get equipment_setDetail_errorTitle => 'Erro';

  @override
  String get equipment_setDetail_loadingTitle => 'Carregando...';

  @override
  String get equipment_setDetail_notFoundMessage =>
      'Este conjunto de equipamentos nao existe mais.';

  @override
  String get equipment_setDetail_notFoundTitle => 'Conjunto Nao Encontrado';

  @override
  String get equipment_setDetail_snackbar_deleted =>
      'Conjunto de equipamentos excluido';

  @override
  String get equipment_setEdit_addEquipmentFirst =>
      'Adicione equipamentos primeiro antes de criar um conjunto.';

  @override
  String get equipment_setEdit_appBar_editTitle => 'Editar Conjunto';

  @override
  String get equipment_setEdit_appBar_newTitle =>
      'Novo Conjunto de Equipamentos';

  @override
  String get equipment_setEdit_descriptionHint => 'Descricao opcional...';

  @override
  String get equipment_setEdit_descriptionLabel => 'Descricao';

  @override
  String equipment_setEdit_errorMessage(Object error) {
    return 'Erro: $error';
  }

  @override
  String get equipment_setEdit_errorTitle => 'Erro';

  @override
  String get equipment_setEdit_loadingTitle => 'Carregando...';

  @override
  String get equipment_setEdit_nameHint => 'ex., Configuracao para Agua Quente';

  @override
  String get equipment_setEdit_nameLabel => 'Nome do Conjunto *';

  @override
  String get equipment_setEdit_nameValidation => 'Por favor, insira um nome';

  @override
  String get equipment_setEdit_noEquipmentAvailable =>
      'Nenhum equipamento disponivel';

  @override
  String get equipment_setEdit_notFoundMessage =>
      'Este conjunto de equipamentos nao existe mais.';

  @override
  String get equipment_setEdit_notFoundTitle => 'Conjunto Nao Encontrado';

  @override
  String get equipment_setEdit_saveButton_edit => 'Salvar Alteracoes';

  @override
  String get equipment_setEdit_saveButton_new => 'Criar Conjunto';

  @override
  String get equipment_setEdit_saveTooltip_edit =>
      'Salvar alteracoes do conjunto de equipamentos';

  @override
  String get equipment_setEdit_saveTooltip_new =>
      'Criar novo conjunto de equipamentos';

  @override
  String get equipment_setEdit_selectEquipmentSubtitle =>
      'Escolha os itens de equipamento para incluir neste conjunto.';

  @override
  String get equipment_setEdit_selectEquipmentTitle =>
      'Selecionar Equipamentos';

  @override
  String get equipment_setEdit_snackbar_created =>
      'Conjunto de equipamentos criado';

  @override
  String equipment_setEdit_snackbar_error(Object error) {
    return 'Erro ao salvar conjunto de equipamentos: $error';
  }

  @override
  String get equipment_setEdit_snackbar_updated =>
      'Conjunto de equipamentos atualizado';

  @override
  String get equipment_sets_appBar_title => 'Conjuntos de Equipamentos';

  @override
  String get equipment_sets_emptyState_createFirstButton =>
      'Criar Seu Primeiro Conjunto';

  @override
  String get equipment_sets_emptyState_description =>
      'Crie conjuntos de equipamentos para adicionar rapidamente combinacoes de equipamentos usados com frequencia aos seus mergulhos.';

  @override
  String get equipment_sets_emptyState_title =>
      'Nenhum Conjunto de Equipamentos';

  @override
  String equipment_sets_errorLoading(Object error) {
    return 'Erro ao carregar conjuntos: $error';
  }

  @override
  String get equipment_sets_fabTooltip =>
      'Criar um novo conjunto de equipamentos';

  @override
  String get equipment_sets_fab_createSet => 'Criar Conjunto';

  @override
  String equipment_sets_itemCountPlural(Object count) {
    return '$count itens';
  }

  @override
  String equipment_sets_itemCountSemanticLabel(Object count) {
    return '$count no conjunto';
  }

  @override
  String equipment_sets_itemCountSingular(Object count) {
    return '$count item';
  }

  @override
  String get equipment_sets_retryButton => 'Tentar Novamente';

  @override
  String get equipment_snackbar_deleted => 'Equipamento excluido';

  @override
  String get equipment_snackbar_markedAsServiced => 'Marcado como revisado';

  @override
  String get equipment_snackbar_reactivated => 'Equipamento reativado';

  @override
  String get equipment_snackbar_retired => 'Equipamento aposentado';

  @override
  String get equipment_summary_active => 'Ativo';

  @override
  String get equipment_summary_addEquipmentButton => 'Adicionar Equipamento';

  @override
  String get equipment_summary_equipmentSetsButton =>
      'Conjuntos de Equipamentos';

  @override
  String get equipment_summary_overviewTitle => 'Visao Geral';

  @override
  String get equipment_summary_quickActionsTitle => 'Acoes Rapidas';

  @override
  String get equipment_summary_recentEquipmentTitle => 'Equipamento Recente';

  @override
  String equipment_summary_recentSemanticLabel(Object name, Object type) {
    return '$name, $type';
  }

  @override
  String get equipment_summary_selectPrompt =>
      'Selecione um equipamento da lista para ver detalhes';

  @override
  String get equipment_summary_serviceDue => 'Manutencao Pendente';

  @override
  String equipment_summary_serviceDueSemanticLabel(Object name, Object type) {
    return '$name, $type, manutencao pendente';
  }

  @override
  String get equipment_summary_serviceDueTitle => 'Manutencao Pendente';

  @override
  String get equipment_summary_title => 'Equipamento';

  @override
  String get equipment_summary_totalItems => 'Total de Itens';

  @override
  String get equipment_summary_totalValue => 'Valor Total';

  @override
  String get equipment_tab_equipment => 'Equipamento';

  @override
  String get equipment_tab_sets => 'Conjuntos';

  @override
  String get formatter_approximate_prefix => '~';

  @override
  String get formatter_connector_at => 'em';

  @override
  String get formatter_connector_from => 'De';

  @override
  String get formatter_connector_until => 'Ate';

  @override
  String get gas_air_description => 'Ar padrao (21% O2)';

  @override
  String get gas_air_displayName => 'Ar';

  @override
  String get gas_diluentAir_description =>
      'Diluente de ar padrao para CCR raso';

  @override
  String get gas_diluentAir_displayName => 'Diluente Ar';

  @override
  String get gas_diluentTx1070_description =>
      'Diluente hipoxico para CCR muito profundo';

  @override
  String get gas_diluentTx1070_displayName => 'Tx 10/70';

  @override
  String get gas_diluentTx1260_description =>
      'Diluente hipoxico para CCR profundo';

  @override
  String get gas_diluentTx1260_displayName => 'Tx 12/60';

  @override
  String get gas_ean32_description => 'Nitrox Enriquecido 32%';

  @override
  String get gas_ean32_displayName => 'EAN32';

  @override
  String get gas_ean36_description => 'Nitrox Enriquecido 36%';

  @override
  String get gas_ean36_displayName => 'EAN36';

  @override
  String get gas_ean40_description => 'Nitrox Enriquecido 40%';

  @override
  String get gas_ean40_displayName => 'EAN40';

  @override
  String get gas_ean50_description => 'Gas deco - 50% O2';

  @override
  String get gas_ean50_displayName => 'EAN50';

  @override
  String get gas_helitrox2525_description =>
      'Helitrox 25/25 (tecnico recreativo)';

  @override
  String get gas_helitrox2525_displayName => 'Helitrox 25/25';

  @override
  String get gas_oxygen_description => 'Oxigenio puro (deco somente a 6m)';

  @override
  String get gas_oxygen_displayName => 'Oxigenio';

  @override
  String get gas_scrEan40_description => 'Gas de suprimento SCR - 40% O2';

  @override
  String get gas_scrEan40_displayName => 'SCR EAN40';

  @override
  String get gas_scrEan50_description => 'Gas de suprimento SCR - 50% O2';

  @override
  String get gas_scrEan50_displayName => 'SCR EAN50';

  @override
  String get gas_scrEan60_description => 'Gas de suprimento SCR - 60% O2';

  @override
  String get gas_scrEan60_displayName => 'SCR EAN60';

  @override
  String get gas_tmx1555_description =>
      'Trimix hipoxico 15/55 (muito profundo)';

  @override
  String get gas_tmx1555_displayName => 'Tx 15/55';

  @override
  String get gas_tmx1845_description => 'Trimix 18/45 (mergulho profundo)';

  @override
  String get gas_tmx1845_displayName => 'Tx 18/45';

  @override
  String get gas_tmx2135_description => 'Trimix normoxico 21/35';

  @override
  String get gas_tmx2135_displayName => 'Tx 21/35';

  @override
  String get gasCalculators_bestMix_bestOxygenMix =>
      'Melhor Mistura de Oxigênio';

  @override
  String get gasCalculators_bestMix_commonMixesRef =>
      'Referência de Misturas Comuns';

  @override
  String gasCalculators_bestMix_exceedsAirMod(Object ppO2) {
    return 'MOD do ar excedida em ppO₂ $ppO2';
  }

  @override
  String get gasCalculators_bestMix_targetDepth => 'Profundidade Alvo';

  @override
  String get gasCalculators_bestMix_targetDive => 'Mergulho Alvo';

  @override
  String gasCalculators_consumption_ambientPressure(
    Object depth,
    Object depthSymbol,
  ) {
    return 'Pressão ambiente em $depth$depthSymbol';
  }

  @override
  String get gasCalculators_consumption_avgDepth => 'Profundidade Média';

  @override
  String get gasCalculators_consumption_breakdown => 'Detalhamento do Cálculo';

  @override
  String get gasCalculators_consumption_diveTime => 'Tempo de Mergulho';

  @override
  String gasCalculators_consumption_exceedsTank(
    Object pressure,
    Object symbol,
  ) {
    return 'Excede a capacidade do cilindro ($pressure $symbol)';
  }

  @override
  String get gasCalculators_consumption_gasAtDepth =>
      'Consumo de gás em profundidade';

  @override
  String get gasCalculators_consumption_pressure => 'Pressão';

  @override
  String get gasCalculators_consumption_remainingGas => 'Gás restante';

  @override
  String gasCalculators_consumption_tankCapacity(
    Object tankSize,
    Object volumeSymbol,
    Object fillPressure,
    Object pressureSymbol,
  ) {
    return 'Capacidade do cilindro ($tankSize$volumeSymbol @ $fillPressure $pressureSymbol)';
  }

  @override
  String get gasCalculators_consumption_title => 'Consumo de Gás';

  @override
  String gasCalculators_consumption_totalGas(Object time) {
    return 'Gás total para $time minutos';
  }

  @override
  String get gasCalculators_consumption_volume => 'Volume';

  @override
  String get gasCalculators_mod_aboutMod => 'Sobre MOD';

  @override
  String get gasCalculators_mod_aboutModBody =>
      'Menos O₂ = MOD mais profunda = NDL mais curto';

  @override
  String get gasCalculators_mod_inputParameters => 'Parâmetros de Entrada';

  @override
  String get gasCalculators_mod_maximumOperatingDepth =>
      'Profundidade Máxima de Operação';

  @override
  String get gasCalculators_mod_oxygenO2 => 'Oxigênio (O₂)';

  @override
  String get gasCalculators_mod_ppO2Conservative =>
      'Limite conservador para tempo de fundo estendido';

  @override
  String get gasCalculators_mod_ppO2Maximum =>
      'Limite máximo apenas para paradas de descompressão';

  @override
  String get gasCalculators_mod_ppO2Standard =>
      'Limite de trabalho padrão para mergulho recreativo';

  @override
  String get gasCalculators_mnd_depthInput => 'Profundidade';

  @override
  String get gasCalculators_mnd_endAtDepthTitle => 'END na Profundidade';

  @override
  String get gasCalculators_mnd_endLimit => 'Limite END';

  @override
  String get gasCalculators_mnd_hePercent => 'He %';

  @override
  String get gasCalculators_mnd_infoContent =>
      'A Profundidade Narcotica Maxima (MND) e a profundidade maxima que voce pode atingir antes que a narcose exceda seu limite de END. A Profundidade Narcotica Equivalente (END) indica o efeito narcotico do seu gas em uma determinada profundidade.\n\nQuando \'O2 e narcotico\' esta ativado, tanto o oxigenio quanto o nitrogenio contribuem para a narcose (mais conservador). Quando desativado, apenas o nitrogenio e considerado narcotico.';

  @override
  String get gasCalculators_mnd_infoTitle => 'Sobre MND/END';

  @override
  String get gasCalculators_mnd_unlimited => 'ilimitado';

  @override
  String get gasCalculators_mnd_inputParameters =>
      'Mistura de Gas e Configuracoes de Narcose';

  @override
  String get gasCalculators_mnd_o2Narcotic => 'O2 e narcotico';

  @override
  String get gasCalculators_mnd_o2Percent => 'O2 %';

  @override
  String get gasCalculators_mnd_resultTitle => 'Profundidade Narcotica Maxima';

  @override
  String get gasCalculators_ppO2Limit => 'Limite ppO₂';

  @override
  String get gasCalculators_resetAll => 'Restaurar todas as calculadoras';

  @override
  String get gasCalculators_sacRate => 'RMV';

  @override
  String get gasCalculators_tab_bestMix => 'Melhor Mistura';

  @override
  String get gasCalculators_tab_consumption => 'Consumo';

  @override
  String get gasCalculators_tab_mnd => 'MND/END';

  @override
  String get gasCalculators_tab_blender => 'Misturador de trimix';

  @override
  String get gasCalculators_blender_cylinder => 'Cilindro';

  @override
  String get gasCalculators_blender_startCylinder => 'No cilindro';

  @override
  String get gasCalculators_blender_targetFill => 'Enchimento alvo';

  @override
  String get gasCalculators_blender_fillGases => 'Gases de enchimento';

  @override
  String get gasCalculators_blender_pressure => 'Pressão';

  @override
  String get gasCalculators_blender_o2 => 'O₂';

  @override
  String get gasCalculators_blender_he => 'He';

  @override
  String get gasCalculators_blender_air => 'Ar';

  @override
  String get gasCalculators_blender_helium => 'Hélio';

  @override
  String get gasCalculators_blender_procedure => 'Procedimento de enchimento';

  @override
  String get gasCalculators_blender_amounts => 'Gás a adicionar';

  @override
  String gasCalculators_blender_stepStart(String pressure, String gas) {
    return 'Começa com $pressure $gas';
  }

  @override
  String gasCalculators_blender_stepFill(
    String gas,
    String pressure,
    String mix,
  ) {
    return 'Enche $gas até $pressure → $mix';
  }

  @override
  String get gasCalculators_blender_error_targetPressure =>
      'A pressão alvo deve ser maior que a inicial.';

  @override
  String get gasCalculators_blender_error_invalidMix =>
      'O₂ + He de uma mistura não pode exceder 100%.';

  @override
  String get gasCalculators_blender_error_identicalGases =>
      'Os dois gases de enchimento são idênticos — nada para misturar.';

  @override
  String get gasCalculators_blender_error_linearlyDependent =>
      'Estes gases não conseguem produzir a mistura alvo — um alvo trimix precisa de uma fonte de hélio.';

  @override
  String get gasCalculators_blender_error_negativeAmount =>
      'Esta mistura não é possível com estes gases — seria necessário remover gás.';

  @override
  String gasCalculators_blender_error_drainTo(String pressure) {
    return 'Gás a mais no cilindro para esta mistura. Esvazie até $pressure e depois encha.';
  }

  @override
  String get gasCalculators_blender_error_drainEmpty =>
      'O gás que está no cilindro não serve para esta mistura. Esvazie-o por completo e depois encha.';

  @override
  String get gasCalculators_blender_error_cannotRemoveHelium =>
      'O cilindro contém hélio e a mistura alvo não. Atestar dilui o hélio mas não o remove: o cilindro tem de ser esvaziado primeiro.';

  @override
  String get gasCalculators_blender_error_insufficientGases =>
      'Um alvo sem hélio precisa de dois gases de enchimento sem hélio com teores de O₂ diferentes.';

  @override
  String get gasCalculators_blender_error_targetNotReached =>
      'Estes gases de enchimento não atingem exatamente a mistura alvo. Verifique os gases e a sua ordem.';

  @override
  String get gasCalculators_blender_error_implausibleStartMix =>
      'O cilindro tem pressão mas nem oxigénio nem hélio, o que seria azoto puro. Verifica a mistura que já está no cilindro.';

  @override
  String get gasCalculators_blender_about => 'Sobre a mistura';

  @override
  String get gasCalculators_blender_aboutBody =>
      'Mistura por pressões parciais para a mistura alvo. Adiciona cada gás de enchimento pela ordem, até à pressão indicada, e deixa o cilindro estabilizar. Os gases de enchimento e a sua ordem são configuráveis: se definires o último gás como 32/0, o remate é feito com EAN32 em vez de ar. Analisa sempre a mistura final antes de a mergulhares.';

  @override
  String get gasCalculators_blender_conditions => 'Condições de mistura';

  @override
  String get gasCalculators_blender_fillTemp => 'Temperatura de enchimento';

  @override
  String get gasCalculators_blender_fillTempHelp =>
      'A temperatura do cilindro enquanto o enches. Cada pressão do procedimento é a leitura do manómetro a esta temperatura.';

  @override
  String get gasCalculators_blender_settledTemp => 'Temperatura estabilizada';

  @override
  String get gasCalculators_blender_settledTempHelp =>
      'A temperatura a que o cilindro fica no fim. A pressão alvo é o que ele marca depois de estabilizar.';

  @override
  String get gasCalculators_blender_gasModel => 'Modelo de gás';

  @override
  String get gasCalculators_blender_modelIdeal => 'Gás ideal';

  @override
  String get gasCalculators_blender_modelVanDerWaals => 'Van der Waals';

  @override
  String get gasCalculators_blender_modelZFactor => 'Gás real (fator Z)';

  @override
  String get gasCalculators_blender_modelRecommended => 'Recomendado';

  @override
  String get gasCalculators_blender_modelHelp =>
      'O gás real (fator Z) é o mais rigoroso às pressões de cilindro. O gás ideal corresponde à maioria das tabelas de mistura publicadas. Van der Waals é oferecido para comparação com outro software de mistura e desvia-se vários por cento à pressão de enchimento.';

  @override
  String gasCalculators_blender_stepAdd(String gas) {
    return 'Adicionar $gas';
  }

  @override
  String get gasCalculators_blender_stepStartLabel => 'Início';

  @override
  String gasCalculators_blender_settlesTo(String pressure, String temperature) {
    return 'Estabiliza em $pressure a $temperature';
  }

  @override
  String get gasCalculators_blender_templates => 'Modelos';

  @override
  String get gasCalculators_blender_templatesTitle => 'Modelos de mistura alvo';

  @override
  String get gasCalculators_blender_saveTemplate => 'Guardar a mistura atual';

  @override
  String get gasCalculators_blender_manageTemplates => 'Gerir modelos';

  @override
  String gasCalculators_blender_templateSaved(String mix) {
    return '$mix guardada';
  }

  @override
  String get gasCalculators_blender_templateExists =>
      'Essa mistura já está guardada.';

  @override
  String get gasCalculators_blender_templateInvalid =>
      'O₂ + He não pode exceder 100%.';

  @override
  String get gasCalculators_blender_templateNeedsNumbers =>
      'Introduz O₂ e He como números.';

  @override
  String gasCalculators_blender_templateLimit(int count) {
    return 'Podes guardar até $count modelos.';
  }

  @override
  String get gasCalculators_blender_templateNone =>
      'Ainda sem modelos. Guarda uma mistura alvo para a reutilizares aqui.';

  @override
  String gasCalculators_blender_templateDelete(String mix) {
    return 'Eliminar $mix';
  }

  @override
  String get gasCalculators_blender_templateAdd => 'Adicionar modelo';

  @override
  String get gasCalculators_blender_billing => 'Custo';

  @override
  String get gasCalculators_blender_cylinderVolume =>
      'Volume de água do cilindro';

  @override
  String get gasCalculators_blender_cylinderPresets => 'Predefinições';

  @override
  String gasCalculators_blender_unitPrice(String unit) {
    return 'Preço por 100 $unit';
  }

  @override
  String get gasCalculators_blender_currency => 'Moeda';

  @override
  String get gasCalculators_blender_costTotal => 'Total';

  @override
  String get gasCalculators_blender_costBasis =>
      'Faturado sobre a pressão fornecida (volume de água do cilindro × bar adicionados), tal como uma estação de enchimento mede.';

  @override
  String get gasCalculators_blender_costMissingPrice =>
      'Introduz um preço para cada gás para veres o total.';

  @override
  String get gasCalculators_blender_saveFill => 'Guardar este enchimento';

  @override
  String get gasCalculators_blender_billed => 'Faturado';

  @override
  String get gasCalculators_blender_billedNone =>
      'Ainda nada faturado. Termina um enchimento e guarda-o aqui.';

  @override
  String get gasCalculators_blender_billedTo => 'Faturado a';

  @override
  String get gasCalculators_blender_addManualLine => 'Adicionar uma linha';

  @override
  String get gasCalculators_blender_lineDescription => 'Descrição';

  @override
  String get gasCalculators_blender_lineAmount => 'Valor';

  @override
  String get gasCalculators_blender_clearBilled => 'Limpar';

  @override
  String get gasCalculators_blender_clearBilledTitle => 'Limpar a fatura?';

  @override
  String gasCalculators_blender_clearBilledBody(int count) {
    return 'Isto remove os $count enchimentos guardados.';
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
    return '$mix adicionado à fatura';
  }

  @override
  String get gasCalculators_blender_billedIncomplete =>
      'Uma ou mais linhas não têm preço, por isso este total está incompleto.';

  @override
  String get gasCalculators_blender_billedTotal => 'Total';

  @override
  String get gasCalculators_tab_mod => 'MOD';

  @override
  String get gasCalculators_tab_rockBottom => 'Rock Bottom';

  @override
  String get gasCalculators_tankSize => 'Tamanho do Cilindro';

  @override
  String get gasCalculators_title => 'Calculadoras de Gás';

  @override
  String get marineLife_siteSection_editExpectedTooltip =>
      'Editar especies esperadas';

  @override
  String get marineLife_siteSection_errorLoadingExpected =>
      'Erro ao carregar especies esperadas';

  @override
  String get marineLife_siteSection_errorLoadingSightings =>
      'Erro ao carregar avistamentos';

  @override
  String get marineLife_siteSection_expectedSpecies => 'Especies Esperadas';

  @override
  String get marineLife_siteSection_noExpected =>
      'Nenhuma especie esperada adicionada';

  @override
  String get marineLife_siteSection_noSpotted =>
      'Nenhuma vida marinha avistada ainda';

  @override
  String marineLife_siteSection_spottedCountSemantics(
    Object name,
    Object count,
  ) {
    return '$name, avistado $count vezes';
  }

  @override
  String get marineLife_siteSection_spottedHere => 'Avistados Aqui';

  @override
  String get marineLife_siteSection_title => 'Vida Marinha';

  @override
  String get marineLife_speciesDetail_backTooltip => 'Voltar';

  @override
  String get marineLife_speciesDetail_depthRangeTitle =>
      'Faixa de Profundidade';

  @override
  String get marineLife_speciesDetail_descriptionTitle => 'Descricao';

  @override
  String get marineLife_speciesDetail_divesLabel => 'Mergulhos';

  @override
  String get marineLife_speciesDetail_editTooltip => 'Editar especie';

  @override
  String marineLife_speciesDetail_errorPrefix(Object error) {
    return 'Erro: $error';
  }

  @override
  String get marineLife_speciesDetail_noSightings =>
      'Nenhum avistamento registrado ainda';

  @override
  String get marineLife_speciesDetail_notFound => 'Especie nao encontrada';

  @override
  String marineLife_speciesDetail_sightingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'avistamentos',
      one: 'avistamento',
    );
    return '$count $_temp0';
  }

  @override
  String get marineLife_speciesDetail_sightingPeriodTitle =>
      'Periodo de Avistamento';

  @override
  String get marineLife_speciesDetail_sightingStatsTitle =>
      'Estatisticas de Avistamento';

  @override
  String get marineLife_speciesDetail_sitesLabel => 'Pontos';

  @override
  String marineLife_speciesDetail_taxonomyClassLabel(Object className) {
    return 'Classe: $className';
  }

  @override
  String get marineLife_speciesDetail_topSitesTitle => 'Principais Pontos';

  @override
  String get marineLife_speciesDetail_totalSightingsLabel =>
      'Total de Avistamentos';

  @override
  String get marineLife_speciesEdit_addTitle => 'Adicionar Especie';

  @override
  String marineLife_speciesEdit_addedSnackbar(Object name) {
    return '\"$name\" adicionada';
  }

  @override
  String get marineLife_speciesEdit_backTooltip => 'Voltar';

  @override
  String get marineLife_speciesEdit_categoryLabel => 'Categoria';

  @override
  String get marineLife_speciesEdit_commonNameError =>
      'Por favor, insira um nome comum';

  @override
  String get marineLife_speciesEdit_commonNameHint =>
      'ex., Peixe-palhaco Ocellaris';

  @override
  String get marineLife_speciesEdit_commonNameLabel => 'Nome Comum';

  @override
  String get marineLife_speciesEdit_descriptionHint =>
      'Breve descricao da especie...';

  @override
  String get marineLife_speciesEdit_descriptionLabel => 'Descricao';

  @override
  String get marineLife_speciesEdit_editTitle => 'Editar Especie';

  @override
  String marineLife_speciesEdit_errorLoading(Object error) {
    return 'Erro ao carregar especie: $error';
  }

  @override
  String marineLife_speciesEdit_errorSaving(Object error) {
    return 'Erro ao salvar especie: $error';
  }

  @override
  String get marineLife_speciesEdit_saveButton => 'Salvar';

  @override
  String get marineLife_speciesEdit_scientificNameHint =>
      'ex., Amphiprion ocellaris';

  @override
  String get marineLife_speciesEdit_scientificNameLabel => 'Nome Cientifico';

  @override
  String get marineLife_speciesEdit_taxonomyClassHint => 'ex., Actinopterygii';

  @override
  String get marineLife_speciesEdit_taxonomyClassLabel => 'Classe Taxonomica';

  @override
  String marineLife_speciesEdit_updatedSnackbar(Object name) {
    return '\"$name\" atualizada';
  }

  @override
  String get marineLife_speciesManage_allFilter => 'Todas';

  @override
  String get marineLife_speciesManage_appBarTitle => 'Especies';

  @override
  String get marineLife_speciesManage_backTooltip => 'Voltar';

  @override
  String marineLife_speciesManage_builtInSpeciesHeader(Object count) {
    return 'Especies Integradas ($count)';
  }

  @override
  String get marineLife_speciesManage_cancelButton => 'Cancelar';

  @override
  String marineLife_speciesManage_cannotDeleteInUse(Object name) {
    return 'Nao e possivel excluir \"$name\" - possui avistamentos';
  }

  @override
  String get marineLife_speciesManage_clearSearchTooltip => 'Limpar busca';

  @override
  String marineLife_speciesManage_customSpeciesHeader(Object count) {
    return 'Especies Personalizadas ($count)';
  }

  @override
  String get marineLife_speciesManage_deleteButton => 'Excluir';

  @override
  String marineLife_speciesManage_deleteDialogContent(Object name) {
    return 'Tem certeza de que deseja excluir \"$name\"?';
  }

  @override
  String get marineLife_speciesManage_deleteDialogTitle => 'Excluir Especie?';

  @override
  String get marineLife_speciesManage_deleteTooltip => 'Excluir especie';

  @override
  String marineLife_speciesManage_deletedSnackbar(Object name) {
    return '\"$name\" excluida';
  }

  @override
  String get marineLife_speciesManage_editTooltip => 'Editar especie';

  @override
  String marineLife_speciesManage_errorDeleting(Object error) {
    return 'Erro ao excluir especie: $error';
  }

  @override
  String marineLife_speciesManage_errorResetting(Object error) {
    return 'Erro ao redefinir especies: $error';
  }

  @override
  String get marineLife_speciesManage_noSpeciesFound =>
      'Nenhuma especie encontrada';

  @override
  String get marineLife_speciesManage_resetButton => 'Redefinir';

  @override
  String get marineLife_speciesManage_resetDialogContent =>
      'Isso restaurara todas as especies integradas para seus valores originais. Especies personalizadas nao serao afetadas. Especies integradas com avistamentos existentes serao atualizadas, mas preservadas.';

  @override
  String get marineLife_speciesManage_resetDialogTitle =>
      'Redefinir para Padroes?';

  @override
  String get marineLife_speciesManage_resetSuccess =>
      'Especies integradas restauradas para os padroes';

  @override
  String get marineLife_speciesManage_resetToDefaults =>
      'Redefinir para Padroes';

  @override
  String get marineLife_speciesManage_searchHint => 'Buscar especies...';

  @override
  String get marineLife_speciesPicker_allFilter => 'Todas';

  @override
  String get marineLife_speciesPicker_cancelButton => 'Cancelar';

  @override
  String get marineLife_speciesPicker_clearSearchTooltip => 'Limpar busca';

  @override
  String get marineLife_speciesPicker_closeTooltip =>
      'Fechar seletor de especies';

  @override
  String get marineLife_speciesPicker_doneButton => 'Concluido';

  @override
  String marineLife_speciesPicker_error(Object error) {
    return 'Erro: $error';
  }

  @override
  String get marineLife_speciesPicker_noSpeciesFound =>
      'Nenhuma especie encontrada';

  @override
  String get marineLife_speciesPicker_searchHint => 'Buscar especies...';

  @override
  String marineLife_speciesPicker_selectedCount(Object count) {
    return '$count selecionadas';
  }

  @override
  String get marineLife_speciesPicker_title => 'Selecionar Especies';

  @override
  String get media_diveMediaSection_addTooltip => 'Adicionar foto ou video';

  @override
  String get media_diveMediaSection_cancelButton => 'Cancelar';

  @override
  String get media_diveMediaSection_cancelSelectionButton => 'Cancelar';

  @override
  String get media_diveMediaSection_emptyState => 'Nenhuma foto ainda';

  @override
  String get media_diveMediaSection_errorLoading => 'Erro ao carregar midia';

  @override
  String get media_diveMediaSection_selectAllButton => 'Selecionar tudo';

  @override
  String media_diveMediaSection_selectedCount(int count) {
    return '$count selecionados';
  }

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'Ver foto. Pressione e segure para desvincular';

  @override
  String get media_diveMediaSection_title => 'Fotos e Video';

  @override
  String get media_diveMediaSection_replaceButton => 'Revincular';

  @override
  String get media_diveMediaSection_replaceEditedContent =>
      'O conteúdo deste arquivo difere do original. Revincular fará um novo envio para seu armazenamento de mídia.';

  @override
  String get media_diveMediaSection_replaceEditedTitle =>
      'O conteúdo do arquivo difere';

  @override
  String get media_diveMediaSection_unlinkButton => 'Desvincular';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Falha ao desvincular: $error';
  }

  @override
  String media_diveMediaSection_unlinkSelectedButton(int count) {
    return 'Desvincular $count';
  }

  @override
  String media_diveMediaSection_unlinkSelectedContent(int count) {
    return 'Remove $count itens de media da sua biblioteca, juntamente com as copias na nuvem e as miniaturas. Os itens que um ponto de mergulho ainda usa sao mantidos. Os seus ficheiros originais nao sao afetados.';
  }

  @override
  String media_diveMediaSection_unlinkSelectedSuccess(int count) {
    return '$count itens desvinculados';
  }

  @override
  String media_diveMediaSection_unlinkSelectedTitle(int count) {
    return 'Desvincular $count itens?';
  }

  @override
  String media_library_unlinkConfirmTitle(int count) {
    return 'Desvincular $count itens?';
  }

  @override
  String media_siteMediaSection_unlinkError(Object error) {
    return 'Falha ao desvincular: $error';
  }

  @override
  String get media_library_unlinkConfirmBody =>
      'Saem da sua biblioteca, juntamente com as cópias na nuvem e as miniaturas. Os seus ficheiros originais não são afetados. Não pode ser desfeito.';

  @override
  String media_library_unlinkMetadataNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count deles têm legenda ou favorito guardados no Submersion, e esses detalhes perdem-se.',
      one:
          'Um deles tem uma legenda ou favorito guardados no Submersion, e esses detalhes perdem-se.',
    );
    return '$_temp0';
  }

  @override
  String get media_siteMediaSection_title => 'Mídia do ponto de mergulho';

  @override
  String get media_siteMediaSection_addPhotos => 'Adicionar fotos ou vídeos';

  @override
  String get media_siteMediaSection_addDocument => 'Adicionar documento';

  @override
  String get media_siteMediaSection_emptyState =>
      'Nenhum mapa, foto ou documento anexado a este ponto de mergulho';

  @override
  String media_siteMediaSection_divePhotosGroup(int count) {
    return 'Fotos de mergulhos aqui ($count)';
  }

  @override
  String get media_siteMediaSection_divePhotoLabel => 'Foto de mergulho';

  @override
  String media_siteMediaSection_unlinkSelectedTitle(int count) {
    return 'Desvincular $count itens?';
  }

  @override
  String media_siteMediaSection_unlinkSelectedContent(int count) {
    return 'Remove $count itens da sua biblioteca, junto com as cópias na nuvem e miniaturas. Mídias que um mergulho ainda usa são mantidas. Seus arquivos originais não são afetados.';
  }

  @override
  String media_siteMediaSection_unlinkSelectedSuccess(int count) {
    return '$count itens desvinculados';
  }

  @override
  String get media_documentViewer_title => 'Documento';

  @override
  String get media_documentViewer_unavailable =>
      'Este documento não está disponível neste dispositivo';

  @override
  String get media_documentViewer_availableOnOriginDevice =>
      'Ele está disponível no dispositivo em que foi adicionado, ou por meio de um armazenamento de mídia configurado.';

  @override
  String media_documentViewer_attached(int count) {
    return '$count documentos anexados';
  }

  @override
  String get media_diveScan_scanTooltip => 'Pesquisar fotos na galeria';

  @override
  String get media_diveScan_noPhotosFound =>
      'Nenhuma foto nova encontrada perto deste mergulho';

  @override
  String get media_diveScan_accessDenied =>
      'E necessario acesso a biblioteca de fotos para pesquisar fotos';

  @override
  String media_diveScan_foundPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encontradas $count fotos',
      one: 'Encontrada 1 foto',
    );
    return '$_temp0 perto deste mergulho. Vincular?';
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
    return 'Erro ao pesquisar na galeria: $error';
  }

  @override
  String get media_gpsBanner_addToSiteButton => 'Adicionar ao Ponto';

  @override
  String media_gpsBanner_coordinates(Object coordinates) {
    return 'Coordenadas: $coordinates';
  }

  @override
  String get media_gpsBanner_createSiteButton => 'Criar Ponto';

  @override
  String get media_gpsBanner_dismissTooltip => 'Dispensar sugestao de GPS';

  @override
  String get media_gpsBanner_title => 'GPS encontrado nas fotos';

  @override
  String media_import_failedToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fotos',
      one: 'foto',
    );
    return 'Falha ao importar $_temp0';
  }

  @override
  String media_import_failedToImportError(Object error) {
    return 'Falha ao importar fotos: $error';
  }

  @override
  String media_import_allAlreadyLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos ja vinculadas a este mergulho',
      one: '1 foto ja vinculada a este mergulho',
    );
    return '$_temp0';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return 'Importadas $imported, falharam $failed';
  }

  @override
  String media_import_importedAndSkipped(int imported, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      imported,
      locale: localeName,
      other: '$imported fotos importadas',
      one: '1 foto importada',
    );
    return '$_temp0 ($skipped ja vinculadas)';
  }

  @override
  String media_import_importedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fotos importadas',
      one: 'foto importada',
    );
    return '$count $_temp0';
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
  String get media_lightroom_openInLightroom => 'Abrir no Lightroom';

  @override
  String get media_lightroom_suggestion_accept => 'Adicionar a este mergulho';

  @override
  String get media_lightroom_suggestion_dismiss => 'Dispensar';

  @override
  String get media_lightroom_suggestions_title => 'Sugestões do Lightroom';

  @override
  String get media_miniProfile_headerLabel => 'Perfil do Mergulho';

  @override
  String get media_miniProfile_semanticLabel =>
      'Grafico mini do perfil de mergulho';

  @override
  String get media_photoPicker_appBarTitle => 'Selecionar Fotos';

  @override
  String get media_photoPicker_tab_gallery => 'Galeria';

  @override
  String get media_photoPicker_tab_files => 'Arquivos';

  @override
  String get media_photoPicker_tab_url => 'URL';

  @override
  String get media_photoPicker_clearSelectionButton => 'Limpar';

  @override
  String get media_photoPicker_closeTooltip => 'Fechar seletor de fotos';

  @override
  String get media_photoPicker_doneButton => 'Concluido';

  @override
  String media_photoPicker_doneCountButton(Object count) {
    return 'Concluido ($count)';
  }

  @override
  String media_photoPicker_emptyMessage(
    Object startDate,
    Object startTime,
    Object endDate,
    Object endTime,
  ) {
    return 'Nenhuma foto foi encontrada entre $startDate $startTime e $endDate $endTime.';
  }

  @override
  String get media_photoPicker_emptyTitle => 'Nenhuma foto encontrada';

  @override
  String get media_photoPicker_grantAccessButton => 'Continuar';

  @override
  String get media_photoPicker_openSettingsButton => 'Abrir Configuracoes';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'O acesso a biblioteca de fotos foi negado. Habilite-o nas Configuracoes para adicionar fotos de mergulho.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'O Submersion precisa de acesso a sua biblioteca de fotos para adicionar fotos de mergulho.';

  @override
  String get media_photoPicker_permissionTitle => 'Fotos de mergulho';

  @override
  String get media_photoPicker_selectAllButton => 'Selecionar tudo';

  @override
  String media_photoPicker_selectedCount(int count) {
    return '$count selecionados';
  }

  @override
  String media_photoPicker_showingPhotosFromRange(Object rangeText) {
    return 'Mostrando fotos de $rangeText';
  }

  @override
  String get media_photoPicker_thumbnailToggleLabel =>
      'Alternar selecao da foto';

  @override
  String get media_photoPicker_thumbnailToggleSelectedLabel =>
      'Alternar selecao da foto, selecionada';

  @override
  String get media_photoPicker_files_pickFilesButton => 'Escolher arquivos…';

  @override
  String get media_photoPicker_files_pickFolderButton => 'Escolher uma pasta…';

  @override
  String get media_photoPicker_files_autoMatchLabel =>
      'Associar automaticamente fotos e vídeos aos mergulhos por data';

  @override
  String get media_photoPicker_files_emptyHint =>
      'Escolha arquivos ou uma pasta para começar.';

  @override
  String media_photoPicker_files_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vincular $count itens',
      one: 'Vincular 1 item',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachToSiteButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Anexar $count itens a este ponto',
      one: 'Anexar 1 item a este ponto',
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
      other: '$fileCount arquivos',
      one: '1 arquivo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount mergulhos',
      one: '1 mergulho',
    );
    return '$_temp0, $_temp1, $unmatchedCount sem associação';
  }

  @override
  String media_photoPicker_files_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_diveGroupTitle(String diveId) {
    return 'Mergulho $diveId';
  }

  @override
  String media_photoPicker_files_groupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos',
      one: '1 arquivo',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_unmatchedGroupTitle => 'Sem associação';

  @override
  String media_photoPicker_files_addAllToDive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Adicionar todos os $count a este mergulho',
      one: 'Adicionar 1 a este mergulho',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_addToDiveTooltip =>
      'Adicionar a este mergulho';

  @override
  String get media_photoPicker_files_chooseDiveTooltip =>
      'Escolher um mergulho';

  @override
  String get media_photoPicker_files_removeTooltip => 'Remover da seleção';

  @override
  String get media_photoPicker_files_sourceExif => 'do EXIF';

  @override
  String get media_photoPicker_files_sourceContainer =>
      'dos metadados do arquivo';

  @override
  String get media_photoPicker_files_sourceFileDate => 'da data do arquivo';

  @override
  String get media_photoPicker_files_sourceNone => 'nenhuma data encontrada';

  @override
  String media_photoPicker_files_shiftedTime(String shifted, String original) {
    return '$shifted (era $original)';
  }

  @override
  String get media_photoPicker_files_reasonNoTimestamp =>
      'Não foi possível ler a hora de captura';

  @override
  String media_photoPicker_files_reasonBeforeDive(String gap) {
    return '$gap antes do mergulho mais próximo';
  }

  @override
  String media_photoPicker_files_reasonAfterDive(String gap) {
    return '$gap depois do mergulho mais próximo';
  }

  @override
  String get media_photoPicker_files_reasonNoDives =>
      'Nenhum mergulho para comparar';

  @override
  String get media_photoPicker_files_offsetLabel =>
      'Deslocar as horas de captura em';

  @override
  String get media_photoPicker_files_offsetResetTooltip =>
      'Redefinir sem deslocamento';

  @override
  String media_photoPicker_files_offsetBackTooltip(String amount) {
    return 'Deslocar $amount antes';
  }

  @override
  String media_photoPicker_files_offsetForwardTooltip(String amount) {
    return 'Deslocar $amount depois';
  }

  @override
  String media_photoPicker_files_linkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens vinculados',
      one: '1 item vinculado',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachedToSiteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens anexados a este ponto',
      one: '1 item anexado a este ponto',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_undo => 'Desfazer';

  @override
  String get media_photoPicker_thumbnailAlreadyLinkedLabel =>
      'Foto ja vinculada a este mergulho';

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
  String get media_perdixOverlay_labelTime => 'TEMPO';

  @override
  String get media_perdixOverlay_labelTts => 'TTS';

  @override
  String get media_perdixOverlay_toggleTooltip =>
      'Sobreposição de computador de mergulho';

  @override
  String get media_photoViewer_cannotShare =>
      'Nao e possivel compartilhar esta foto';

  @override
  String get media_photoViewer_cannotWriteMetadata =>
      'Nao e possivel gravar metadados - midia nao vinculada a biblioteca';

  @override
  String get media_photoViewer_closeTooltip => 'Fechar visualizador de fotos';

  @override
  String get media_photoViewer_diveDataWrittenToPhoto =>
      'Dados do mergulho gravados na foto';

  @override
  String get media_photoViewer_diveDataWrittenToVideo =>
      'Dados do mergulho gravados no video';

  @override
  String media_photoViewer_errorLoadingPhotos(Object error) {
    return 'Erro ao carregar fotos: $error';
  }

  @override
  String get media_photoViewer_failedToLoadImage => 'Falha ao carregar imagem';

  @override
  String get media_photoViewer_failedToLoadVideo => 'Falha ao carregar video';

  @override
  String media_photoViewer_failedToShare(Object error) {
    return 'Falha ao compartilhar: $error';
  }

  @override
  String get media_photoViewer_failedToWriteMetadata =>
      'Falha ao gravar metadados';

  @override
  String media_photoViewer_failedToWriteMetadataError(Object error) {
    return 'Falha ao gravar metadados: $error';
  }

  @override
  String get media_photoViewer_nextTooltip => 'Próxima mídia';

  @override
  String get media_photoViewer_noPhotosAvailable => 'Nenhuma foto disponivel';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel =>
      'Reproduzir ou pausar video';

  @override
  String get media_photoViewer_previousTooltip => 'Mídia anterior';

  @override
  String get media_photoViewer_seekVideoLabel => 'Buscar posicao do video';

  @override
  String get media_photoViewer_shareTooltip => 'Compartilhar foto';

  @override
  String get media_photoViewer_toggleOverlayLabel =>
      'Alternar sobreposicao da foto';

  @override
  String get media_photoViewer_videoFileNotFound =>
      'Arquivo de video nao encontrado';

  @override
  String get media_photoViewer_videoNotLinked =>
      'Video nao vinculado a biblioteca';

  @override
  String get media_photoViewer_writeDiveDataTooltip =>
      'Gravar dados do mergulho na foto';

  @override
  String get media_quickSiteDialog_cancelButton => 'Cancelar';

  @override
  String get media_quickSiteDialog_createButton => 'Criar Ponto';

  @override
  String get media_quickSiteDialog_description =>
      'Crie um novo ponto de mergulho usando coordenadas GPS da sua foto.';

  @override
  String get media_quickSiteDialog_siteNameError =>
      'Por favor, insira um nome para o ponto';

  @override
  String get media_quickSiteDialog_siteNameHint =>
      'Insira um nome para este ponto';

  @override
  String get media_quickSiteDialog_siteNameLabel => 'Nome do Ponto';

  @override
  String get media_quickSiteDialog_title => 'Criar Ponto de Mergulho';

  @override
  String get media_scanResults_allPhotosLinked =>
      'Todas as fotos ja vinculadas';

  @override
  String media_scanResults_allPhotosLinkedDescription(Object count) {
    return 'Todas as $count fotos desta viagem ja estao vinculadas a mergulhos.';
  }

  @override
  String media_scanResults_alreadyLinked(Object count) {
    return '$count fotos ja vinculadas';
  }

  @override
  String get media_scanResults_cancelButton => 'Cancelar';

  @override
  String media_scanResults_diveNumber(Object number) {
    return 'Mergulho #$number';
  }

  @override
  String media_scanResults_foundNewPhotos(Object count) {
    return '$count novas fotos encontradas';
  }

  @override
  String get media_scanResults_linkButton => 'Vincular';

  @override
  String media_scanResults_linkCountButton(Object count) {
    return 'Vincular $count fotos';
  }

  @override
  String get media_scanResults_noPhotosFound => 'Nenhuma foto encontrada';

  @override
  String get media_scanResults_okButton => 'OK';

  @override
  String get media_scanResults_unknownSite => 'Ponto desconhecido';

  @override
  String media_scanResults_unmatchedWarning(Object count) {
    return '$count fotos nao puderam ser associadas a nenhum mergulho (tiradas fora dos horarios de mergulho)';
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
      'Indisponível neste dispositivo';

  @override
  String get media_unavailablePlaceholder_signInRequired => 'Sign in to view';

  @override
  String get media_writeMetadata_cancelButton => 'Cancelar';

  @override
  String get media_writeMetadata_depthLabel => 'Profundidade';

  @override
  String get media_writeMetadata_descriptionPhoto =>
      'Os seguintes metadados serao gravados na foto:';

  @override
  String get media_writeMetadata_descriptionVideo =>
      'Os seguintes metadados serao gravados no video:';

  @override
  String get media_writeMetadata_diveTimeLabel => 'Horario do mergulho';

  @override
  String get media_writeMetadata_gpsLabel => 'GPS';

  @override
  String get media_writeMetadata_keepOriginalVideo => 'Manter video original';

  @override
  String get media_writeMetadata_livePhotoUnsupported =>
      'As Live Photos ainda não são suportadas. Duplique esta como fotografia estática e escreva os dados do mergulho na cópia.';

  @override
  String get media_writeMetadata_noDataAvailable =>
      'Nenhum dado de mergulho disponivel para gravar.';

  @override
  String get media_writeMetadata_siteLabel => 'Ponto';

  @override
  String get media_writeMetadata_temperatureLabel => 'Temperatura';

  @override
  String get media_writeMetadata_titlePhoto =>
      'Gravar Dados do Mergulho na Foto';

  @override
  String get media_writeMetadata_titleVideo =>
      'Gravar Dados do Mergulho no Video';

  @override
  String get media_writeMetadata_warningPhotoText =>
      'Isso modificara a foto original.';

  @override
  String get media_writeMetadata_warningVideoText =>
      'Um novo video sera criado com os metadados. Metadados de video nao podem ser modificados diretamente.';

  @override
  String get media_writeMetadata_writeButton => 'Gravar';

  @override
  String get nav_buddies => 'Duplas';

  @override
  String get nav_certifications => 'Certificacoes';

  @override
  String get nav_courses => 'Cursos';

  @override
  String get nav_coursesSubtitle => 'Treinamento e Educacao';

  @override
  String get nav_diveCenters => 'Operadoras de Mergulho';

  @override
  String get nav_dives => 'Mergulhos';

  @override
  String get nav_equipment => 'Equipamentos';

  @override
  String get nav_gpsLog => 'Registro GPS';

  @override
  String get media_console_library => 'Biblioteca';

  @override
  String get media_console_transfers => 'Transferências';

  @override
  String get media_console_import => 'Importar';

  @override
  String get media_import_launch => 'Importar mídia...';

  @override
  String get media_import_review_title => 'Revisar importação';

  @override
  String media_import_review_confirm(int count) {
    return 'Importar $count itens';
  }

  @override
  String media_import_review_result(int linked, int skipped, int failed) {
    return '$linked vinculados, $skipped ignorados, $failed com falha';
  }

  @override
  String get media_import_review_chooseSite => 'Escolher local';

  @override
  String get media_import_review_ambiguous => 'Vários mergulhos correspondem';

  @override
  String get media_import_review_noMatch => 'Nenhum mergulho correspondente';

  @override
  String get media_import_review_skipped => 'Não importado';

  @override
  String media_import_review_linkChip(int number) {
    return 'Vincular a #$number';
  }

  @override
  String get media_import_review_linkToDive => 'Vincular a um mergulho';

  @override
  String get media_import_review_linkToSite => 'Vincular a um ponto';

  @override
  String get media_import_review_chooseDive => 'Escolher mergulho';

  @override
  String get media_import_intro =>
      'As fotos são vinculadas a um mergulho ou ponto de mergulho ao importar.';

  @override
  String get media_console_sources => 'Origens';

  @override
  String get media_sources_browseHeader => 'Navegar por origem';

  @override
  String get media_sources_watchedHeader => 'Pastas monitoradas';

  @override
  String get media_sources_addWatched => 'Adicionar pasta...';

  @override
  String get media_sources_scanFailed => 'Falha na verificação';

  @override
  String get media_sources_scanNow => 'Verificar agora';

  @override
  String get media_sources_autoApply =>
      'Revincular automaticamente correspondências exatas';

  @override
  String get media_sources_neverScanned => 'Nunca verificada';

  @override
  String get media_source_gallery => 'Fototeca';

  @override
  String get media_source_localFile => 'Arquivos locais';

  @override
  String get media_source_networkUrl => 'Links da web';

  @override
  String get media_source_manifest => 'Assinaturas';

  @override
  String get media_source_connector => 'Serviços conectados';

  @override
  String get media_source_mediaStore => 'Armazenamento de mídia na nuvem';

  @override
  String get media_source_signature => 'Assinaturas';

  @override
  String get media_repairHistory_title => 'Histórico de reparos';

  @override
  String get media_repairHistory_empty => 'Nenhum reparo ainda';

  @override
  String get media_repairHistory_action_relink => 'Revinculado';

  @override
  String get media_repairHistory_action_cloudBacked => 'Na nuvem';

  @override
  String get media_repairHistory_action_autoRelink =>
      'Revinculado automaticamente';

  @override
  String get media_smartAlbum_save => 'Salvar como álbum';

  @override
  String get media_smartAlbum_saveTitle => 'Nomeie este álbum';

  @override
  String get media_smartAlbum_albums => 'Álbuns';

  @override
  String get media_smartAlbum_delete => 'Excluir álbum';

  @override
  String get media_smartAlbum_deleteFailed =>
      'Não foi possível excluir o álbum';

  @override
  String get media_smartAlbum_saved => 'Álbum salvo';

  @override
  String media_sources_lastScanned(String date) {
    return 'Última verificação $date';
  }

  @override
  String media_sources_scanResult(int indexed, int repaired) {
    return '$indexed arquivos indexados, $repaired revinculados';
  }

  @override
  String get media_repairHistory_sourceFolder => 'verificação de pastas';

  @override
  String get media_repairHistory_sourcePhotoLibrary => 'biblioteca de fotos';

  @override
  String get media_repairHistory_sourceStore =>
      'armazenamento de mídia na nuvem';

  @override
  String get media_repairHistory_sourceWatcher => 'pastas monitoradas';

  @override
  String get media_repairHistory_sourceManual => 'revinculação manual';

  @override
  String media_repairHistory_source(String source) {
    return 'via $source';
  }

  @override
  String get media_missing_empty => 'Nenhum arquivo ausente';

  @override
  String media_missing_offlineVolumes(int count) {
    return '$count em volumes offline';
  }

  @override
  String get media_missing_repair => 'Reparar...';

  @override
  String get media_repair_title => 'Reparar arquivos ausentes';

  @override
  String get media_repair_addFolder => 'Adicionar pasta...';

  @override
  String get media_repair_usePhotoLibrary => 'Pesquisar na fototeca';

  @override
  String get media_repair_useStore => 'Usar o armazenamento de mídia na nuvem';

  @override
  String get media_repair_scan => 'Verificar';

  @override
  String media_repair_prefixMove(String from, String to, int count) {
    return 'Movimentação de pasta detectada: $from para $to cobre $count arquivos';
  }

  @override
  String get media_repair_confidence_exact => 'Exato';

  @override
  String get media_repair_confidence_probable => 'Nome e tamanho';

  @override
  String get media_repair_confidence_edited => 'Arquivo editado';

  @override
  String get media_repair_confidence_unmatched => 'Nenhum candidato';

  @override
  String get media_repair_unverified => 'Não verificado no armazenamento';

  @override
  String media_repair_apply(int count) {
    return 'Revincular $count arquivos';
  }

  @override
  String media_repair_summary(
    int relinked,
    int cloudBacked,
    int reuploads,
    int failed,
    int skipped,
  ) {
    return '$relinked revinculados, $cloudBacked na nuvem, $reuploads reenvios na fila, $failed falharam, $skipped ignorados';
  }

  @override
  String get media_library_empty => 'Nenhuma mídia ainda';

  @override
  String get media_library_filter_all => 'Tudo';

  @override
  String get media_library_filter_photos => 'Fotos';

  @override
  String get media_library_filter_videos => 'Vídeos';

  @override
  String get media_library_filter_site => 'Ponto';

  @override
  String get media_library_filter_trip => 'Viagem';

  @override
  String get media_library_filter_dates => 'Datas';

  @override
  String get media_library_filter_missing => 'Arquivos ausentes';

  @override
  String media_library_filter_missingCount(int count) {
    return 'Arquivos ausentes ($count)';
  }

  @override
  String get media_library_filter_clear => 'Limpar filtros';

  @override
  String get media_library_filter_any => 'Qualquer';

  @override
  String get media_library_filter_title => 'Filtrar mídia';

  @override
  String get media_library_filter_apply => 'Aplicar';

  @override
  String get media_library_sort_title => 'Ordenar mídia';

  @override
  String get media_smartAlbum_load => 'Carregar álbum';

  @override
  String get media_divePicker_title => 'Mover para um mergulho';

  @override
  String get media_divePicker_search => 'Pesquisar mergulhos';

  @override
  String get media_library_moveToDive => 'Mover para um mergulho';

  @override
  String get media_library_unlinkSelected => 'Desvincular';

  @override
  String media_library_selectedCount(int count) {
    return '$count selecionados';
  }

  @override
  String get media_library_unlinkedHeader => 'Sem vínculo';

  @override
  String get media_library_diveHeaderHint => 'Abrir este mergulho';

  @override
  String get media_library_untitledDiveHeader => 'Mergulho sem título';

  @override
  String get media_library_viewMode_byDive => 'Por mergulho';

  @override
  String get media_library_viewMode_grid => 'Grade';

  @override
  String get media_library_viewMode_timeline => 'Linha do tempo';

  @override
  String get media_viewer_goToDive => 'Ir para o mergulho';

  @override
  String get nav_home => 'Inicio';

  @override
  String get nav_media => 'Mídia';

  @override
  String get nav_more => 'Mais';

  @override
  String get nav_planning => 'Planejamento';

  @override
  String get nav_planningSubtitle => 'Planejador de Mergulho, Calculadoras';

  @override
  String get nav_settings => 'Configuracoes';

  @override
  String get nav_sites => 'Pontos de Mergulho';

  @override
  String get nav_statistics => 'Estatisticas';

  @override
  String get nav_tooltip_closeMenu => 'Fechar menu';

  @override
  String get nav_tooltip_collapseMenu => 'Recolher menu';

  @override
  String get nav_tooltip_expandMenu => 'Expandir menu';

  @override
  String get nav_transfer => 'Transferir';

  @override
  String get nav_trips => 'Viagens';

  @override
  String plannerCanvas_bailout_available(String liters) {
    return 'Disponível $liters';
  }

  @override
  String get plannerCanvas_bailout_insufficient =>
      'Gás de bailout insuficiente para o pior caso';

  @override
  String plannerCanvas_bailout_required(String liters) {
    return 'Necessário $liters';
  }

  @override
  String get plannerCanvas_bailout_title => 'Bailout (circuito aberto)';

  @override
  String plannerCanvas_bailout_tts(String minutes) {
    return 'TTS de bailout $minutes′';
  }

  @override
  String plannerCanvas_bailout_worstCase(String minutes, String depth) {
    return 'Pior caso aos $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_ccr_setpointHigh => 'Setpoint alto (bar)';

  @override
  String get plannerCanvas_ccr_setpointLow => 'Setpoint baixo (bar)';

  @override
  String get plannerCanvas_ccr_switchDepth =>
      'Profundidade de troca do setpoint';

  @override
  String get plannerCanvas_pscr_ratio => 'Razão pSCR';

  @override
  String get plannerCanvas_pscr_ratio_hint =>
      'Maior = mais gás fresco, menor queda de O₂';

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
      'Selecione pelo menos dois planos para comparar';

  @override
  String get plannerCanvas_compare_title => 'Comparar planos';

  @override
  String get plannerCanvas_contingency_base => 'Base';

  @override
  String get plannerCanvas_contingency_depthDelta => 'Profundidade extra';

  @override
  String plannerCanvas_contingency_lostGas(String gas) {
    return '$gas perdido';
  }

  @override
  String plannerCanvas_contingency_previewing(String label) {
    return 'Pré-visualização: $label';
  }

  @override
  String get plannerCanvas_contingency_timeDelta => 'Minutos extras';

  @override
  String plannerCanvas_chart_meanDepth(String depth) {
    return 'média $depth';
  }

  @override
  String get plannerCanvas_contingency_title => 'Contingências';

  @override
  String get plannerCanvas_contingency_turnFraction => 'Fração de retorno';

  @override
  String get plannerCanvas_contingency_turnRule =>
      'Regra de pressão de retorno';

  @override
  String get plannerCanvas_convert_success =>
      'Mergulho criado a partir do plano';

  @override
  String get plannerCanvas_convert_view => 'Ver';

  @override
  String plannerCanvas_follow_chip(String name) {
    return 'Seguindo $name';
  }

  @override
  String get plannerCanvas_follow_empty => 'Ainda não há mergulhos registrados';

  @override
  String get plannerCanvas_follow_noTissues =>
      'Sem dados de perfil nesse mergulho — intervalo de superfície definido sem saturação dos tecidos';

  @override
  String get plannerCanvas_follow_title => 'Seguir um mergulho';

  @override
  String plannerCanvas_gas_minGas(String pressure) {
    return 'gás mínimo $pressure';
  }

  @override
  String plannerCanvas_gas_turnAt(String pressure) {
    return 'retorno a $pressure';
  }

  @override
  String plannerCanvas_issue_gasDensityCritical(String value) {
    return 'Densidade do gás $value g/L acima do limite máximo';
  }

  @override
  String plannerCanvas_issue_gasDensityHigh(String value) {
    return 'Densidade do gás $value g/L acima do limite recomendado';
  }

  @override
  String plannerCanvas_issue_hypoxic(String depth, String value) {
    return 'Gás hipóxico a $depth (ppO₂ $value bar)';
  }

  @override
  String plannerCanvas_issue_minGas(String pressure) {
    return 'O cilindro termina abaixo do mínimo rock bottom de $pressure';
  }

  @override
  String get plannerCanvas_issue_noBailout =>
      'O plano de descompressão CCR não leva gás de bailout';

  @override
  String get plannerCanvas_issue_noDecoGas =>
      'Descompressão necessária mas sem gás de deco a bordo';

  @override
  String get plannerCanvas_range_base => 'Base';

  @override
  String get plannerCanvas_range_legend =>
      'As células mostram o tempo até a superfície; vermelho = não mergulhável como planejado';

  @override
  String get plannerCanvas_pane_collapse => 'Recolher painel';

  @override
  String get plannerCanvas_pane_expand => 'Expandir painel';

  @override
  String get plannerCanvas_tab_setup => 'Configuração';

  @override
  String get plannerCanvas_o2Narcotic => 'Tratar o O₂ como narcótico';

  @override
  String get plannerCanvas_rates_ascent => 'Taxa de subida';

  @override
  String get plannerCanvas_rates_descent => 'Taxa de descida';

  @override
  String get plannerCanvas_rates_title => 'Taxas';

  @override
  String get plannerCanvas_range_title => 'Tabela de variações';

  @override
  String get plannerCanvas_results_noDeco => 'Nenhuma descompressão necessária';

  @override
  String plannerCanvas_sac_useLogged(String sac) {
    return 'Usar média registrada ($sac)';
  }

  @override
  String plannerCanvas_saved_deleteConfirmBody(String name) {
    return 'Excluir permanentemente \"$name\"?';
  }

  @override
  String get plannerCanvas_saved_deleteConfirmTitle => 'Excluir plano?';

  @override
  String get plannerCanvas_saved_duplicate => 'Duplicar';

  @override
  String get plannerCanvas_saved_empty => 'Ainda não há planos salvos';

  @override
  String get plannerCanvas_saved_title => 'Planos salvos';

  @override
  String get plannerCanvas_name_dialogTitle => 'Dê um nome ao seu plano';

  @override
  String get plannerCanvas_name_defaultFallback => 'Plano de mergulho';

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
    return 'Não foi possível importar o plano: $reason';
  }

  @override
  String get plannerCanvas_share_menu => 'Compartilhar arquivo do plano';

  @override
  String get plannerCanvas_slate_menu => 'Exportar prancheta (PDF)';

  @override
  String get plannerCanvas_slate_minGas => 'Gás mínimo';

  @override
  String get plannerCanvas_slate_turn => 'Retorno';

  @override
  String get plannerCanvas_table_depth => 'Profundidade';

  @override
  String get plannerCanvas_table_gas => 'Gás';

  @override
  String get plannerCanvas_table_runtime => 'RT';

  @override
  String get plannerCanvas_table_stop => 'Parada';

  @override
  String get plannerCanvas_turnRule_allUsable => 'Tudo utilizável';

  @override
  String get plannerCanvas_turnRule_custom => 'Personalizada';

  @override
  String get plannerCanvas_turnRule_halves => 'Metades';

  @override
  String get plannerCanvas_turnRule_none => 'Nenhuma';

  @override
  String get plannerCanvas_turnRule_thirds => 'Terços';

  @override
  String get planning_appBar_title => 'Planejamento';

  @override
  String get planning_card_decoCalculator_description =>
      'Calcule limites de nao descompressao, paradas deco necessarias e exposicao CNS/OTU para perfis de mergulho multinivel.';

  @override
  String get planning_card_decoCalculator_subtitle =>
      'Planeje mergulhos com paradas de descompressao';

  @override
  String get planning_card_decoCalculator_title => 'Calculadora Deco';

  @override
  String get planning_card_divePlanner_description =>
      'Planeje mergulhos complexos com multiplos niveis de profundidade, trocas de gas e calculo automatico de paradas de descompressao.';

  @override
  String get planning_card_divePlanner_subtitle =>
      'Crie planos de mergulho multinivel';

  @override
  String get planning_card_divePlanner_title => 'Planejador de Mergulho';

  @override
  String get planning_card_gasCalculators_description =>
      'Quatro calculadoras de gas especializadas:\n• MOD - Profundidade maxima operacional para uma mistura de gas\n• Best Mix - O₂% ideal para uma profundidade alvo\n• Consumo - Estimativa de consumo de gas\n• Rock Bottom - Calculo de reserva de emergencia';

  @override
  String get planning_card_gasCalculators_subtitle =>
      'MOD, Best Mix, Consumo, Rock Bottom';

  @override
  String get planning_card_gasCalculators_title => 'Calculadoras de Gas';

  @override
  String get planning_card_surfaceInterval_description =>
      'Calcule o intervalo de superficie minimo necessario entre mergulhos com base na carga tissular. Visualize como seus 16 compartimentos teciduais liberam gas ao longo do tempo.';

  @override
  String get planning_card_surfaceInterval_subtitle =>
      'Planeje intervalos de mergulho repetitivo';

  @override
  String get planning_card_surfaceInterval_title => 'Intervalo de Superficie';

  @override
  String get planning_card_weightCalculator_description =>
      'Estime o peso necessario com base na sua roupa de exposicao, material do cilindro, tipo de agua e peso corporal.';

  @override
  String get planning_card_weightCalculator_subtitle =>
      'Peso recomendado para sua configuracao';

  @override
  String get planning_card_weightCalculator_title => 'Calculadora de Peso';

  @override
  String get planning_info_disclaimer =>
      'Estas ferramentas sao apenas para fins de planejamento. Sempre verifique os calculos e siga seu treinamento de mergulho.';

  @override
  String get planning_newPlan => 'Novo plano';

  @override
  String get planning_section_tools => 'Ferramentas';

  @override
  String get planning_summary_prompt => 'Selecione uma ferramenta para começar';

  @override
  String get planning_summary_savedPlans => 'Planos salvos';

  @override
  String get planning_summary_noPlans => 'Ainda não há planos salvos';

  @override
  String get planning_sidebar_appBar_title => 'Planejamento';

  @override
  String get planning_sidebar_decoCalculator_subtitle => 'NDL e paradas deco';

  @override
  String get planning_sidebar_decoCalculator_title => 'Calculadora Deco';

  @override
  String get planning_sidebar_divePlanner_subtitle =>
      'Planos de mergulho multinivel';

  @override
  String get planning_sidebar_divePlanner_title => 'Planejador de Mergulho';

  @override
  String get planning_sidebar_gasCalculators_subtitle => 'MOD, Best Mix, mais';

  @override
  String get planning_sidebar_gasCalculators_title => 'Calculadoras de Gas';

  @override
  String get planning_sidebar_info_disclaimer =>
      'Ferramentas de planejamento sao apenas para referencia. Sempre verifique os calculos.';

  @override
  String get planning_sidebar_surfaceInterval_subtitle =>
      'Planejamento de mergulho repetitivo';

  @override
  String get planning_sidebar_surfaceInterval_title =>
      'Intervalo de Superficie';

  @override
  String get planning_sidebar_weightCalculator_subtitle => 'Peso recomendado';

  @override
  String get planning_sidebar_weightCalculator_title => 'Calculadora de Peso';

  @override
  String get planning_welcome_quickTips_title => 'Dicas Rapidas';

  @override
  String get planning_welcome_subtitle =>
      'Selecione uma ferramenta na barra lateral para comecar';

  @override
  String get planning_welcome_tip_decoCalculator =>
      'Calculadora Deco para NDL e tempos de parada';

  @override
  String get planning_welcome_tip_divePlanner =>
      'Planejador de Mergulho para planejamento multinivel';

  @override
  String get planning_welcome_tip_gasCalculators =>
      'Calculadoras de Gas para MOD e planejamento de gas';

  @override
  String get planning_welcome_tip_weightCalculator =>
      'Calculadora de Peso para configuracao de flutuabilidade';

  @override
  String get planning_welcome_title => 'Ferramentas de Planejamento';

  @override
  String get settings_about_aboutSubmersion => 'Sobre o Submersion';

  @override
  String get settings_about_appName => 'Submersion';

  @override
  String get settings_about_description =>
      'Registre seus mergulhos, gerencie equipamentos e explore pontos de mergulho.';

  @override
  String get settings_about_header => 'Sobre';

  @override
  String get settings_about_openSourceLicenses => 'Licencas de Codigo Aberto';

  @override
  String get settings_about_reportIssue => 'Relatar um Problema';

  @override
  String get settings_about_reportIssue_copy => 'Copiar link';

  @override
  String get settings_about_reportIssue_snackbar =>
      'Acesse github.com/submersion-app/submersion/issues';

  @override
  String settings_about_version(String version) {
    return 'Versao $version';
  }

  @override
  String get settings_appBar_title => 'Configuracoes';

  @override
  String get settings_appearance_appLanguage => 'Idioma do Aplicativo';

  @override
  String get settings_appearance_displaySize => 'Tamanho de exibição';

  @override
  String settings_appearance_displaySize_value(int percent) {
    return '$percent%';
  }

  @override
  String get settings_appearance_displaySize_reset => 'Redefinir';

  @override
  String get settings_appearance_displaySize_smaller => 'Menor';

  @override
  String get settings_appearance_displaySize_larger => 'Maior';

  @override
  String get settings_appearance_depthColoredCards =>
      'Cartoes coloridos por profundidade';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'Mostrar cartoes de mergulho com fundos em cores oceanicas baseados na profundidade';

  @override
  String get settings_appearance_cardColorAttribute => 'Colorir cartoes por';

  @override
  String get settings_appearance_cardColorAttribute_subtitle =>
      'Escolher qual atributo determina a cor de fundo dos cartoes';

  @override
  String get settings_appearance_cardColorAttribute_none => 'Nenhum';

  @override
  String get settings_appearance_cardColorAttribute_depth => 'Profundidade';

  @override
  String get settings_appearance_cardColorAttribute_duration => 'Duracao';

  @override
  String get settings_appearance_cardColorAttribute_temperature =>
      'Temperatura';

  @override
  String get settings_appearance_colorGradient => 'Gradiente de cor';

  @override
  String get settings_appearance_colorGradient_subtitle =>
      'Escolher a faixa de cores para os fundos dos cartoes';

  @override
  String get settings_appearance_colorGradient_ocean => 'Oceano';

  @override
  String get settings_appearance_colorGradient_thermal => 'Thermal';

  @override
  String get settings_appearance_colorGradient_sunset => 'Por do sol';

  @override
  String get settings_appearance_colorGradient_forest => 'Floresta';

  @override
  String get settings_appearance_colorGradient_monochrome => 'Monocromatico';

  @override
  String get settings_appearance_colorGradient_custom => 'Personalizado';

  @override
  String get settings_appearance_gasSwitchMarkers =>
      'Marcadores de troca de gas';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle =>
      'Mostrar marcadores para trocas de gas';

  @override
  String get settings_appearance_gasTimeline => 'Linha do tempo do gás';

  @override
  String get settings_appearance_gasTimeline_subtitle =>
      'Exibir a faixa de consumo de gás abaixo do perfil de mergulho por padrão';

  @override
  String get settings_appearance_header_diveDetails => 'Detalhes do Mergulho';

  @override
  String get settings_appearance_header_diveLog => 'Registro de Mergulho';

  @override
  String get settings_appearance_header_diveProfile => 'Perfil de Mergulho';

  @override
  String get settings_appearance_header_diveSites => 'Pontos de Mergulho';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility =>
      'Ordem e Visibilidade das Secoes';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility_subtitle =>
      'Escolher quais secoes aparecem e sua ordem';

  @override
  String get settings_diveDetailSections_title =>
      'Ordem e Visibilidade das Secoes';

  @override
  String get settings_diveDetailSections_resetToDefault => 'Restaurar Padrao';

  @override
  String get settings_diveDetailSections_fixedSections =>
      'Secoes fixas: Cabecalho, Grafico de Perfil de Mergulho';

  @override
  String get settings_diveDetailSections_configurableSections =>
      'Secoes configuraveis (arraste para reordenar)';

  @override
  String get diveDetailSection_decoO2_name => 'Status Deco / Carga de Tecidos';

  @override
  String get diveDetailSection_decoO2_description =>
      'NDL, teto, mapa de calor de tecidos, toxicidade de O2';

  @override
  String get diveDetailSection_safetyReview_name => 'Revisão de segurança';

  @override
  String get diveDetailSection_safetyReview_description =>
      'Observações automáticas do perfil após o mergulho';

  @override
  String get safetyReview_sectionTitle => 'Revisão de segurança';

  @override
  String safetyReview_findingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observações',
      one: '1 observação',
    );
    return '$_temp0';
  }

  @override
  String safetyReview_rapidAscent_title(String rate, String duration) {
    return 'A subida excedeu $rate durante $duration';
  }

  @override
  String safetyReview_missedDecoStop_title(String excess, String duration) {
    return 'A profundidade ficou $excess acima do teto de parada exigido durante $duration';
  }

  @override
  String safetyReview_omittedSafetyStop_title(String remaining) {
    return 'A parada de segurança recomendada foi encurtada em $remaining';
  }

  @override
  String safetyReview_sawtoothProfile_title(int count) {
    return '$count variações repetidas de profundidade para cima e para baixo durante o mergulho';
  }

  @override
  String safetyReview_highSurfaceGf_title(String gf, String gfHigh) {
    return 'Chegou à superfície com fator de gradiente $gf, acima do $gfHigh configurado';
  }

  @override
  String safetyReview_timeRange(String start, String end) {
    return 'Em $start–$end';
  }

  @override
  String get safetyReview_dismiss => 'Dispensar';

  @override
  String get safetyReview_restore => 'Restaurar';

  @override
  String get safetyReview_dismissAll => 'Dispensar tudo';

  @override
  String get safetyReview_restoreAll => 'Restaurar tudo';

  @override
  String get safetySettings_dismissAll => 'Dispensar todas as observações';

  @override
  String get safetySettings_dismissAll_subtitle =>
      'Marcar como revistas todas as observações deste diário';

  @override
  String get safetySettings_dismissAll_confirmTitle =>
      'Dispensar todas as observações?';

  @override
  String get safetySettings_dismissAll_confirmBody =>
      'Todas as observações de todos os mergulhos analisados serão marcadas como revistas. Pode restaurá-las mergulho a mergulho na respetiva secção de revisão de segurança.';

  @override
  String get safetySettings_dismissAll_confirm => 'Dispensar tudo';

  @override
  String get safetySettings_dismissAll_cancel => 'Cancelar';

  @override
  String safetySettings_dismissAll_progress(int done, int total) {
    return '$done de $total mergulhos verificados';
  }

  @override
  String safetySettings_dismissAll_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observações dispensadas',
      one: '1 observação dispensada',
      zero: 'Nenhuma observação para dispensar',
    );
    return '$_temp0';
  }

  @override
  String safetySettings_dismissAll_doneWithErrors(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observações dispensadas',
      one: '1 observação dispensada',
      zero: 'Nenhuma observação dispensada',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failed mergulhos não puderam ser atualizados',
      one: '1 mergulho não pôde ser atualizado',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get safetySettings_dismissAll_failed =>
      'Não foi possível ler a lista de mergulhos. Nada foi alterado.';

  @override
  String get safetySettings_analyzeAll_failed =>
      'Não foi possível analisar os mergulhos.';

  @override
  String get safetyReview_details => 'Detalhes';

  @override
  String get safetyReview_clearHighlight => 'Limpar destaque';

  @override
  String safetyReview_findingGroupSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observações de segurança',
      one: '1 observação de segurança',
    );
    return '$_temp0';
  }

  @override
  String get safetySettings_title => 'Revisão de segurança';

  @override
  String get safetySettings_entry_subtitle =>
      'Observações e regras pós-mergulho';

  @override
  String get safetySettings_masterToggle => 'Revisão de segurança pós-mergulho';

  @override
  String get safetySettings_masterToggle_subtitle =>
      'Anotar automaticamente observações de subida, paradas e perfil nos mergulhos analisados';

  @override
  String get safetySettings_rulesHeader => 'Regras';

  @override
  String get safetySettings_rule_rapidAscent => 'Subidas rápidas';

  @override
  String get safetySettings_rule_missedDecoStop =>
      'Paradas deco perdidas ou encurtadas';

  @override
  String get safetySettings_rule_omittedSafetyStop =>
      'Paradas de segurança omitidas';

  @override
  String get safetySettings_rule_sawtoothProfile => 'Perfis em dente de serra';

  @override
  String get safetySettings_rule_highSurfaceGf =>
      'Fator de gradiente alto ao emergir';

  @override
  String get safetySettings_analyzeAll => 'Analisar todos os mergulhos';

  @override
  String get safetySettings_analyzeAll_subtitle =>
      'Executar a revisão de segurança em todos os mergulhos com perfil ainda não analisados';

  @override
  String safetySettings_analyzeAll_progress(int done, int total) {
    return 'Analisados $done de $total';
  }

  @override
  String get safetySettings_analyzeAll_done => 'Análise concluída';

  @override
  String safetySettings_analyzeAll_doneWithErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Não foi possível analisar $count mergulhos',
      one: 'Não foi possível analisar 1 mergulho',
    );
    return 'Análise concluída — $_temp0';
  }

  @override
  String safetyReview_showDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar $count dispensadas',
      one: 'Mostrar 1 dispensada',
    );
    return '$_temp0';
  }

  @override
  String get diveDetailSection_sacSegments_name => 'Taxa SAC por Segmento';

  @override
  String get diveDetailSection_sacSegments_description =>
      'Segmentacao SAC por fase/tempo';

  @override
  String get diveDetailSection_details_name => 'Detalhes';

  @override
  String get diveDetailSection_details_description =>
      'Tipo, local, viagem, centro de mergulho, intervalo';

  @override
  String get diveDetailSection_environment_name => 'Ambiente';

  @override
  String get diveDetailSection_environment_description =>
      'Temp. do ar/agua, visibilidade, corrente';

  @override
  String get diveDetailSection_altitude_name => 'Altitude';

  @override
  String get diveDetailSection_altitude_description =>
      'Valor de altitude, categoria, requisito de deco';

  @override
  String get diveDetailSection_tide_name => 'Mare';

  @override
  String get diveDetailSection_tide_description =>
      'Grafico do ciclo de mare e horarios';

  @override
  String get diveDetailSection_reefHealth_name => 'Condições da água';

  @override
  String get diveDetailSection_reefHealth_description =>
      'Condições da água por satélite na data do mergulho';

  @override
  String get diveDetailSection_surfaceGps_name => 'GPS de superfície';

  @override
  String get diveDetailSection_surfaceGps_description =>
      'Pontos de entrada/saída por GPS e deriva na superfície';

  @override
  String get diveLog_detail_section_surfaceGps => 'GPS de superfície';

  @override
  String get diveLog_detail_surfaceGps_entry => 'Entrada';

  @override
  String get diveLog_detail_surfaceGps_exit => 'Saída';

  @override
  String get diveLog_detail_label_drift => 'Deriva';

  @override
  String get diveLog_detail_surfaceGps_entryOnly =>
      'Ponto de entrada registrado';

  @override
  String get diveLog_detail_surfaceGps_exitOnly => 'Ponto de saída registrado';

  @override
  String get diveLog_detail_surfaceGps_site => 'Ponto de mergulho';

  @override
  String get diveLog_detail_surfaceGps_track => 'Trilha de superfície';

  @override
  String get diveLog_detail_surfaceGps_showFullTrack => 'Trilha completa';

  @override
  String diveLog_detail_surfaceGps_trackFixes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pontos',
      one: '1 ponto',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_detail_locationsMap_title => 'Locais de mergulho';

  @override
  String get diveLog_detail_coordinatesCopied =>
      'Coordenadas copiadas para a área de transferência';

  @override
  String get diveLog_detail_openInMaps => 'Abrir no Mapas';

  @override
  String get diveDetailSection_weights_name => 'Pesos';

  @override
  String get diveDetailSection_weights_description =>
      'Detalhamento de peso, peso total';

  @override
  String get diveDetailSection_buoyancy_name => 'Flutuabilidade';

  @override
  String get diveDetailSection_buoyancy_description =>
      'Flutuabilidade durante o mergulho, variação, lastro descartável';

  @override
  String get buoyancy_tooltip =>
      'Flutuabilidade líquida modelada durante o mergulho a partir do perfil, consumo de gás e equipamento.';

  @override
  String buoyancy_verdictBuoyant(String depth, String amount) {
    return 'Na sua última parada (~$depth) você tinha cerca de $amount de flutuabilidade';
  }

  @override
  String buoyancy_verdictHeavy(String depth, String amount) {
    return 'Na sua última parada (~$depth) você estava cerca de $amount pesado demais';
  }

  @override
  String get buoyancy_verdictNeutral =>
      'Sua configuração estava quase neutra na última parada';

  @override
  String get buoyancy_verdictConvention =>
      'Estimado pela convenção de parada de segurança a 5 m';

  @override
  String get buoyancy_breakdownTitle => 'Detalhe dos termos';

  @override
  String get buoyancy_suitTerm => 'Roupa';

  @override
  String get buoyancy_leadTerm => 'Lastro';

  @override
  String get buoyancy_beginNet => 'Início do mergulho';

  @override
  String get buoyancy_endNet => 'Fim do mergulho';

  @override
  String get buoyancy_swing => 'Variação de flutuabilidade';

  @override
  String get buoyancy_peakLift => 'Sustentação máxima necessária';

  @override
  String get buoyancy_wingWarning => 'Excede a sustentação nominal do seu wing';

  @override
  String get buoyancy_minDitchable => 'Lastro descartável mínimo';

  @override
  String get buoyancy_droppable => 'Você pode soltar';

  @override
  String get buoyancy_ditchWarning => 'Mais do que você pode soltar';

  @override
  String get buoyancy_drysuitGas => 'Gás de roupa seca adicionado';

  @override
  String get buoyancy_estimatedPressures =>
      'As pressões dos cilindros são estimadas';

  @override
  String get buoyancy_linkSuitHint =>
      'Associe uma roupa de exposição a este mergulho para um quadro mais completo';

  @override
  String get buoyancy_noLeadHint =>
      'Nenhum lastro registado: adicione lastro a este mergulho ou um peso seco ao seu equipamento de lastro';

  @override
  String get buoyancy_chartNet => 'Líquido';

  @override
  String get buoyancy_chartRig => 'Equipamento + lastro';

  @override
  String get buoyancy_chartMinutes => 'Tempo (min)';

  @override
  String get buoyancy_historyTitle => 'Histórico de lastro';

  @override
  String get buoyancy_historyCarried => 'Levado';

  @override
  String get buoyancy_historyModeled => 'Modelado';

  @override
  String buoyancy_historyMore(String delta) {
    return 'Você costuma levar $delta a mais do que o modelo sugere';
  }

  @override
  String buoyancy_historyLess(String delta) {
    return 'Você costuma levar $delta a menos do que o modelo sugere';
  }

  @override
  String get buoyancy_throughDive => 'Durante o mergulho';

  @override
  String get buoyancy_adjust => 'Ajustar';

  @override
  String get buoyancy_whatIfTitle => 'Ajustar este mergulho';

  @override
  String get buoyancy_whatIfLead => 'Lastro';

  @override
  String get buoyancy_whatIfSuit => 'Flutuabilidade da roupa';

  @override
  String get buoyancy_whatIfReset => 'Redefinir';

  @override
  String buoyancy_whatIfDelta(String delta) {
    return '$delta vs real';
  }

  @override
  String get diveDetailSection_tanks_name => 'Cilindros';

  @override
  String get diveDetailSection_tanks_description =>
      'Lista de cilindros, misturas de gas, pressoes, SAC por cilindro';

  @override
  String get diveDetailSection_buddies_name => 'Parceiros';

  @override
  String get diveDetailSection_buddies_description =>
      'Lista de parceiros com funcoes';

  @override
  String get diveDetailSection_signatures_name => 'Assinaturas';

  @override
  String get diveDetailSection_signatures_description =>
      'Exibicao e captura de assinatura do parceiro/instrutor';

  @override
  String get diveDetailSection_equipment_name => 'Equipamento';

  @override
  String get diveDetailSection_equipment_description =>
      'Equipamento utilizado no mergulho';

  @override
  String get diveDetailSection_sightings_name => 'Avistamentos de Vida Marinha';

  @override
  String get diveDetailSection_sightings_description =>
      'Especies avistadas, detalhes dos avistamentos';

  @override
  String get diveDetailSection_media_name => 'Midia';

  @override
  String get diveDetailSection_media_description => 'Galeria de fotos/videos';

  @override
  String get diveDetailSection_tags_name => 'Etiquetas';

  @override
  String get diveDetailSection_tags_description => 'Etiquetas do mergulho';

  @override
  String get diveDetailSection_notes_name => 'Notas';

  @override
  String get diveDetailSection_notes_description =>
      'Notas/descricao do mergulho';

  @override
  String get diveDetailSection_customFields_name => 'Campos Personalizados';

  @override
  String get diveDetailSection_customFields_description =>
      'Campos personalizados definidos pelo usuario';

  @override
  String get diveDetailSection_dataSources_name => 'Fontes de Dados';

  @override
  String get diveDetailSection_dataSources_description =>
      'Computadores de mergulho conectados, gerenciamento de fontes';

  @override
  String get settings_appearance_header_language => 'Idioma';

  @override
  String get settings_appearance_header_theme => 'Tema';

  @override
  String get settings_appearance_header_mode => 'Modo';

  @override
  String get settings_themes_title => 'Escolher Tema';

  @override
  String get settings_themes_current => 'Tema';

  @override
  String get theme_submersion => 'Submersao';

  @override
  String get theme_console => 'Console';

  @override
  String get theme_tropical => 'Tropical';

  @override
  String get theme_minimalist => 'Minimalista';

  @override
  String get theme_deep => 'Profundo';

  @override
  String get settings_appearance_mapBackgroundDiveCards =>
      'Fundo de mapa nos cartoes de mergulho';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitle =>
      'Mostrar mapa do ponto de mergulho como fundo nos cartoes de mergulho';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitleWithNote =>
      'Mostrar mapa do ponto de mergulho como fundo nos cartoes de mergulho (requer localizacao do ponto)';

  @override
  String get settings_appearance_mapBackgroundSiteCards =>
      'Fundo de mapa nos cartoes de ponto';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitle =>
      'Mostrar mapa como fundo nos cartoes de ponto de mergulho';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitleWithNote =>
      'Mostrar mapa como fundo nos cartoes de ponto de mergulho (requer localizacao do ponto)';

  @override
  String get settings_appearance_maxDepthMarker =>
      'Marcador de profundidade maxima';

  @override
  String get settings_appearance_maxDepthMarker_subtitle =>
      'Mostrar um marcador no ponto de profundidade maxima';

  @override
  String get settings_appearance_maxDepthMarker_subtitleFull =>
      'Mostrar um marcador no ponto de profundidade maxima nos perfis de mergulho';

  @override
  String get settings_appearance_metric_ascentRateColors =>
      'Cores da Taxa de Subida';

  @override
  String get settings_appearance_metric_ceiling => 'Teto';

  @override
  String get settings_appearance_metric_events => 'Eventos';

  @override
  String get settings_appearance_metric_estimatedTankPressure =>
      'Pressão estimada do cilindro';

  @override
  String get settings_appearance_metric_gasDensity => 'Densidade do Gas';

  @override
  String get settings_appearance_metric_gfPercent => 'GF%';

  @override
  String get settings_appearance_metric_heartRate => 'Frequencia Cardiaca';

  @override
  String get settings_appearance_metric_meanDepth => 'Profundidade Media';

  @override
  String get settings_appearance_metric_ndl => 'NDL';

  @override
  String get settings_appearance_metric_ppHe => 'ppHe';

  @override
  String get settings_appearance_metric_ppN2 => 'ppN2';

  @override
  String get settings_appearance_metric_ppO2 => 'ppO2';

  @override
  String get settings_appearance_metric_pressure => 'Pressao';

  @override
  String get settings_appearance_metric_sacRate => 'Taxa SAC';

  @override
  String get settings_appearance_metric_surfaceGf => 'GF de Superficie';

  @override
  String get settings_appearance_metric_temperature => 'Temperatura';

  @override
  String get settings_appearance_metric_tts => 'TTS (Tempo ate a Superficie)';

  @override
  String get settings_appearance_metric_cns => 'CNS% (Toxicidade de O2)';

  @override
  String get settings_appearance_metric_otu =>
      'OTU (Unidades de Tolerancia ao O2)';

  @override
  String get settings_appearance_metric_photoMarkers => 'Marcadores de fotos';

  @override
  String settings_appearance_metricsEnabledCount(int count, int total) {
    return '$count de $total ativados';
  }

  @override
  String get settings_appearance_pressureThresholdMarkers =>
      'Marcadores de limite de pressao';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'Mostrar marcadores quando a pressao do cilindro cruza limites';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'Mostrar marcadores quando a pressao do cilindro cruza os limites de 2/3, 1/2 e 1/3';

  @override
  String get settings_appearance_metricsFollowViewport =>
      'Manter as sobreposições visíveis ao ampliar';

  @override
  String get settings_appearance_metricsFollowViewport_subtitle =>
      'Ajustar as sobreposições como NDL e ppO2 à área visível em vez de ampliá-las com o eixo de profundidade';

  @override
  String get settings_appearance_rightYAxisMetric =>
      'Metrica do eixo Y direito';

  @override
  String get settings_appearance_rightYAxisMetric_subtitle =>
      'Metrica padrao exibida no eixo direito';

  @override
  String get settings_appearance_subsection_decompressionMetrics =>
      'Metricas de Descompressao';

  @override
  String get settings_appearance_subsection_defaultVisibleMetrics =>
      'Metricas Visiveis Padrao';

  @override
  String get settings_appearance_subsection_standardMetrics =>
      'Standard Metrics';

  @override
  String get settings_appearance_subsection_gasAnalysisMetrics =>
      'Metricas de Analise de Gas';

  @override
  String get settings_appearance_subsection_gradientFactorMetrics =>
      'Metricas de Fator de Gradiente';

  @override
  String get settings_appearance_theme_dark => 'Escuro';

  @override
  String get settings_appearance_theme_light => 'Claro';

  @override
  String get settings_appearance_theme_system => 'Padrao do sistema';

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
  String get settings_backToSettings_tooltip => 'Voltar para configuracoes';

  @override
  String get settings_cloudSync_appBar_title =>
      'Sincronizacao na Nuvem do Banco de Dados';

  @override
  String get settings_cloudSync_autoSync => 'Sincronizacao Automatica';

  @override
  String get settings_cloudSync_autoSync_subtitle =>
      'Sincronizar automaticamente apos alteracoes';

  @override
  String settings_cloudSync_conflictItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens precisam de atencao',
      one: '1 item precisa de atencao',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_disabledBanner_content =>
      'A sincronizacao na nuvem gerenciada pelo aplicativo esta desativada porque voce esta usando uma pasta de armazenamento personalizada. O servico de sincronizacao da sua pasta (Dropbox, Google Drive, OneDrive, etc.) gerencia a sincronizacao.';

  @override
  String get settings_cloudSync_disabledBanner_title =>
      'Sincronizacao na Nuvem Desativada';

  @override
  String get settings_cloudSync_entry_subtitle =>
      'Sincronização via armazenamento na nuvem';

  @override
  String get settings_cloudSync_adopt_confirm =>
      'Adotar a biblioteca restaurada';

  @override
  String settings_cloudSync_adopt_dialogContent(
    String deviceName,
    String date,
  ) {
    return 'A biblioteca foi substituída a partir de um backup em \"$deviceName\" ($date). Ao adotá-la, os dados deste dispositivo serão substituídos pela biblioteca restaurada. Primeiro será criado um backup de segurança dos dados atuais deste dispositivo.';
  }

  @override
  String get settings_cloudSync_adopt_dialogTitle =>
      'Adotar a biblioteca restaurada?';

  @override
  String get settings_cloudSync_adopt_notNow => 'Agora não';

  @override
  String get settings_cloudSync_dangerZone => 'Zona de perigo';

  @override
  String get settings_cloudSync_replaceLibrary_tile =>
      'Substituir biblioteca na nuvem';

  @override
  String get settings_cloudSync_replaceLibrary_tileSubtitle =>
      'Tornar a biblioteca deste dispositivo a que todos os dispositivos usam';

  @override
  String get settings_cloudSync_replaceLibrary_dialogTitle =>
      'Substituir a biblioteca na nuvem?';

  @override
  String get settings_cloudSync_replaceLibrary_dialogIntro =>
      'A biblioteca deste dispositivo passa a ser a que todos os dispositivos usam.';

  @override
  String settings_cloudSync_replaceLibrary_dialogBody(num diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other:
          'A biblioteca na nuvem é apagada e substituída pelos $diveCount mergulhos deste dispositivo.',
      one:
          'A biblioteca na nuvem é apagada e substituída pelo 1 mergulho deste dispositivo.',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_replaceLibrary_peers(num peerCount) {
    String _temp0 = intl.Intl.pluralLogic(
      peerCount,
      locale: localeName,
      other:
          'Será pedido a $peerCount outros dispositivos que a adotem; até lá, as suas alterações não são combinadas.',
      one:
          'Será pedido a 1 outro dispositivo que a adote; até lá, as suas alterações não são combinadas.',
      zero:
          'Nenhum outro dispositivo sincroniza ainda, portanto não há nada para adotar.',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_replaceLibrary_peersUnknown =>
      'Será pedido a todos os outros dispositivos que a adotem; até lá, as suas alterações não são combinadas.';

  @override
  String get settings_cloudSync_replaceLibrary_backupNote =>
      'Primeiro é criada uma cópia de segurança deste dispositivo. Esta ação não pode ser anulada.';

  @override
  String get settings_cloudSync_replaceLibrary_confirmWord => 'Substituir';

  @override
  String get settings_cloudSync_replaceLibrary_confirmHint =>
      'Digite \"Substituir\" para confirmar';

  @override
  String get settings_cloudSync_replaceLibrary_confirm => 'Substituir';

  @override
  String get settings_cloudSync_firstSync_banner =>
      'A primeira sincronização está aguardando confirmação. Toque em \'Sincronizar Agora\' para revisar o que será combinado.';

  @override
  String get settings_cloudSync_firstSync_dialogConfirm =>
      'Mesclar e Sincronizar';

  @override
  String get settings_cloudSync_firstSync_replaceHint =>
      'Se, em vez disso, a biblioteca deste dispositivo deve substituir a que está na nuvem, cancele e use Definições > Sincronização na nuvem > Substituir biblioteca na nuvem.';

  @override
  String settings_cloudSync_firstSync_dialogContent(
    int deviceCount,
    int diveCount,
  ) {
    return 'Foram encontrados dados de sincronização existentes na nuvem ($deviceCount arquivo(s) de sincronização). Sua primeira sincronização combinará esses dados com os $diveCount mergulho(s) neste dispositivo, em todos os dispositivos sincronizados.\n\nSe os mesmos mergulhos foram adicionados separadamente em cada dispositivo, eles aparecerão duas vezes.';
  }

  @override
  String get settings_cloudSync_firstSync_dialogTitle =>
      'Combinar Bibliotecas?';

  @override
  String settings_cloudSync_replace_banner(String deviceName) {
    return 'Sincronização pausada: a biblioteca foi substituída a partir de um backup em \"$deviceName\". Toque em Sincronizar agora para revisar.';
  }

  @override
  String get settings_cloudSync_switch_dialogTitle =>
      'Trocar de provedor de sincronização?';

  @override
  String settings_cloudSync_switch_dialogContent(
    String fromName,
    String toName,
  ) {
    return 'Seus dados não serão removidos de $fromName — eles permanecem lá até que você os exclua. Após a troca, a próxima sincronização deste dispositivo combinará seus dados com o que já existir em $toName. Seus outros dispositivos continuarão usando $fromName até que você troque cada um deles também.';
  }

  @override
  String get settings_cloudSync_switch_confirm => 'Trocar';

  @override
  String settings_cloudSync_moved_banner(
    String deviceName,
    String destination,
  ) {
    return '$deviceName moveu esta biblioteca para $destination. Este provedor não está mais sendo atualizado por ele. Selecione $destination abaixo para acompanhar a mudança.';
  }

  @override
  String get settings_cloudSync_moved_dismiss => 'Dispensar';

  @override
  String settings_cloudSync_cleanup_banner(String backend) {
    return 'Dados de sincronização antigos ainda estão armazenados em $backend de antes de você trocar de provedor. Eles não são mais usados.';
  }

  @override
  String get settings_cloudSync_cleanup_delete => 'Excluir dados antigos';

  @override
  String get settings_cloudSync_cleanup_keep => 'Manter';

  @override
  String get settings_cloudSync_header_advanced => 'Avancado';

  @override
  String get settings_cloudSync_signOut_backupWarning =>
      'O backup na nuvem será desativado e os backups serão salvos no local padrão.';

  @override
  String get settings_cloudSync_header_cloudProvider => 'Provedor de Nuvem';

  @override
  String settings_cloudSync_header_conflicts(Object count) {
    return 'Conflitos ($count)';
  }

  @override
  String get settings_cloudSync_header_syncBehavior =>
      'Comportamento de Sincronizacao';

  @override
  String settings_cloudSync_lastSynced(Object time) {
    return 'Ultima sincronizacao: $time';
  }

  @override
  String settings_cloudSync_pendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alteracoes pendentes',
      one: '1 alteracao pendente',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_banner(Object deviceList) {
    return '$deviceList ainda tem uma versão de biblioteca antiga ou desconhecida, portanto as suas alterações não foram combinadas. Abra o Submersion nele para adotar a biblioteca atual.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_bannerPlural(Object deviceList) {
    return '$deviceList ainda têm uma versão de biblioteca antiga ou desconhecida, portanto as suas alterações não foram combinadas. Abra o Submersion neles para adotar a biblioteca atual.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_unnamedDevice(Object shortId) {
    return 'dispositivo $shortId';
  }

  @override
  String get settings_cloudSync_peerNeedsAdopt_listSeparator => ', ';

  @override
  String get settings_cloudSync_peerNeedsAdopt_listLastSeparator => ' e ';

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamed(Object deviceList) {
    return '$deviceList sincroniza a partir de uma versão mais recente do Submersion, por isso as suas alterações mais recentes ficam retidas por agora.';
  }

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamedPlural(
    Object deviceList,
  ) {
    return '$deviceList sincronizam a partir de uma versão mais recente do Submersion, por isso as suas alterações mais recentes ficam retidas por agora.';
  }

  @override
  String get settings_cloudSync_peerRequiresUpdate_updateAction =>
      'Atualize este dispositivo para as receber.';

  @override
  String get settings_cloudSync_peerRequiresUpdate_storeAction =>
      'Serão aplicadas automaticamente quando a atualização da loja de aplicações deste dispositivo chegar; a atualização pode ainda estar em revisão.';

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
    return 'Falha na conexao com $providerName: $error';
  }

  @override
  String get settings_cloudSync_dropbox_account_title => 'Conta do Dropbox';

  @override
  String get settings_cloudSync_dropbox_connect_browserFailed =>
      'Não foi possível abrir o navegador. Tente o botão Reabrir navegador.';

  @override
  String get settings_cloudSync_dropbox_connect_codeLabel =>
      'Código de autorização';

  @override
  String get settings_cloudSync_dropbox_connect_emptyCode =>
      'Insira o código de autorização exibido no seu navegador';

  @override
  String settings_cloudSync_dropbox_connect_failed(Object error) {
    return 'Não foi possível conectar ao Dropbox: $error';
  }

  @override
  String get settings_cloudSync_dropbox_connect_instructions =>
      'Seu navegador abriu uma página de autorização do Dropbox. Aprove o acesso e cole aqui o código exibido pelo Dropbox.';

  @override
  String get settings_cloudSync_dropbox_connect_reopenBrowser =>
      'Reabrir navegador';

  @override
  String get settings_cloudSync_dropbox_connect_submit => 'Conectar';

  @override
  String get settings_cloudSync_dropbox_connect_title => 'Conectar Dropbox';

  @override
  String get settings_cloudSync_dropbox_connected => 'Conectado ao Dropbox';

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
      'Indisponível nesta versão';

  @override
  String get settings_cloudSync_googleDrive_browserWait_title =>
      'Continue no navegador';

  @override
  String get settings_cloudSync_googleDrive_browserWait_message =>
      'Conclua a autenticação com a sua conta Google no navegador e depois regresse ao Submersion.';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'Falha ao inicializar provedor $providerName';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'Nao disponivel nesta plataforma';

  @override
  String get settings_cloudSync_provider_s3_edit => 'Editar configuração do S3';

  @override
  String get settings_cloudSync_provider_s3_subtitle =>
      'Funciona com qualquer serviço de armazenamento compatível com S3';

  @override
  String get settings_cloudSync_provider_s3_title =>
      'Armazenamento compatível com S3';

  @override
  String get settings_cloudSync_resetDialog_cancel => 'Cancelar';

  @override
  String get settings_cloudSync_resetDialog_content =>
      'Isso limpara todo o historico de sincronizacao e comecara do zero. Seus dados nao serao excluidos, mas voce pode precisar resolver conflitos na proxima sincronizacao.';

  @override
  String get settings_cloudSync_resetDialog_reset => 'Redefinir';

  @override
  String get settings_cloudSync_resetDialog_title =>
      'Redefinir Estado de Sincronizacao?';

  @override
  String get settings_cloudSync_resetSuccess =>
      'Estado de sincronizacao redefinido';

  @override
  String get settings_cloudSync_resetSyncState =>
      'Redefinir Estado de Sincronizacao';

  @override
  String get settings_cloudSync_resetSyncState_subtitle =>
      'Limpar historico de sincronizacao e comecar do zero';

  @override
  String get settings_cloudSync_resolveConflicts => 'Resolver Conflitos';

  @override
  String get settings_cloudSync_selectProviderHint =>
      'Selecione um provedor de nuvem para ativar a sincronizacao';

  @override
  String get settings_cloudSync_signOut => 'Sair';

  @override
  String get settings_cloudSync_signOutDialog_cancel => 'Cancelar';

  @override
  String get settings_cloudSync_signOutDialog_content =>
      'Isso desconectara do provedor de nuvem. Seus dados locais permanecerão intactos.';

  @override
  String get settings_cloudSync_signOutDialog_signOut => 'Sair';

  @override
  String get settings_cloudSync_signOutDialog_title => 'Sair?';

  @override
  String get settings_cloudSync_signOutSuccess =>
      'Desconectado do provedor de nuvem';

  @override
  String get settings_cloudSync_signOut_subtitle =>
      'Desconectar do provedor de nuvem';

  @override
  String get settings_cloudSync_status_conflictsDetected =>
      'Conflitos detectados';

  @override
  String get settings_cloudSync_status_readyToSync => 'Pronto para sincronizar';

  @override
  String get settings_cloudSync_status_syncComplete =>
      'Sincronizacao concluida';

  @override
  String get settings_cloudSync_status_syncError => 'Erro de sincronizacao';

  @override
  String get settings_cloudSync_status_syncing => 'Sincronizando...';

  @override
  String get settings_cloudSync_storageSettings =>
      'Configuracoes de Armazenamento';

  @override
  String get settings_cloudSync_syncNow => 'Sincronizar Agora';

  @override
  String get settings_cloudSync_syncOnLaunch => 'Sincronizar ao Iniciar';

  @override
  String get settings_cloudSync_syncOnLaunch_subtitle =>
      'Verificar atualizacoes na inicializacao';

  @override
  String get settings_cloudSync_syncOnResume => 'Sincronizar ao Retomar';

  @override
  String get settings_cloudSync_syncOnResume_subtitle =>
      'Verificar atualizacoes quando o aplicativo ficar ativo';

  @override
  String settings_cloudSync_syncProgressPercent(Object percent) {
    return 'Progresso da sincronizacao: $percent por cento';
  }

  @override
  String settings_cloudSync_time_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias atras',
      one: '1 dia atras',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_time_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas atras',
      one: '1 hora atras',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_time_justNow => 'Agora mesmo';

  @override
  String settings_cloudSync_time_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutos atras',
      one: '1 minuto atras',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_applyAll => 'Aplicar Todas';

  @override
  String get settings_conflict_cancel => 'Cancelar';

  @override
  String get settings_conflict_chooseResolution => 'Escolher Resolucao';

  @override
  String get settings_conflict_close => 'Fechar';

  @override
  String get settings_conflict_close_tooltip => 'Fechar dialogo de conflito';

  @override
  String settings_conflict_counterLabel(Object current, Object total) {
    return 'Conflito $current de $total';
  }

  @override
  String settings_conflict_errorLoading(Object error) {
    return 'Erro ao carregar conflitos: $error';
  }

  @override
  String get settings_conflict_keepBoth => 'Manter Ambos';

  @override
  String get settings_conflict_keepLocal => 'Manter Local';

  @override
  String get settings_conflict_keepRemote => 'Manter Remoto';

  @override
  String get settings_conflict_localVersion => 'Versao Local';

  @override
  String settings_conflict_modified(Object time) {
    return 'Modificado: $time';
  }

  @override
  String get settings_conflict_next_tooltip => 'Proximo conflito';

  @override
  String get settings_conflict_noConflicts_message =>
      'Todos os conflitos de sincronizacao foram resolvidos.';

  @override
  String get settings_conflict_noConflicts_title => 'Sem Conflitos';

  @override
  String get settings_conflict_noDataAvailable => 'Nenhum dado disponivel';

  @override
  String get settings_conflict_previous_tooltip => 'Conflito anterior';

  @override
  String get settings_conflict_ref_buddy => 'Companheiro';

  @override
  String get settings_conflict_ref_certification => 'Certificacao';

  @override
  String get settings_conflict_ref_checklistTemplate =>
      'Modelo de lista de verificacao';

  @override
  String get settings_conflict_ref_connectedAccount => 'Conta conectada';

  @override
  String get settings_conflict_ref_course => 'Curso';

  @override
  String get settings_conflict_ref_courseRequirement => 'Requisito do curso';

  @override
  String get settings_conflict_ref_cylinderConfig =>
      'Configuracao de cilindros';

  @override
  String get settings_conflict_ref_dataSource => 'Fonte de dados';

  @override
  String get settings_conflict_ref_dive => 'Mergulho';

  @override
  String get settings_conflict_ref_diveCenter => 'Operadora de Mergulho';

  @override
  String get settings_conflict_ref_diveComputer => 'Computador de Mergulho';

  @override
  String get settings_conflict_ref_divePlan => 'Plano de mergulho';

  @override
  String get settings_conflict_ref_diveSite => 'Ponto de Mergulho';

  @override
  String get settings_conflict_ref_diveType => 'Tipo de Mergulho';

  @override
  String get settings_conflict_ref_diver => 'Mergulhador';

  @override
  String get settings_conflict_ref_equipment => 'Equipamento';

  @override
  String get settings_conflict_ref_equipmentSet => 'Conjunto de equipamentos';

  @override
  String get settings_conflict_ref_finding => 'Constatacao';

  @override
  String get settings_conflict_ref_instructor => 'Instrutor';

  @override
  String get settings_conflict_ref_linkedDive => 'Mergulho vinculado';

  @override
  String get settings_conflict_ref_media => 'Midia';

  @override
  String get settings_conflict_ref_mediaSubscription => 'Assinatura de midia';

  @override
  String get settings_conflict_ref_missing => 'Nao esta mais nesta biblioteca';

  @override
  String settings_conflict_ref_named(Object name, Object date) {
    return '$name ($date)';
  }

  @override
  String get settings_conflict_ref_plannedTank => 'Cilindro planejado';

  @override
  String get settings_conflict_ref_preDiveChecklistTemplate =>
      'Modelo de lista pre-mergulho';

  @override
  String get settings_conflict_ref_preDiveSession => 'Lista pre-mergulho';

  @override
  String get settings_conflict_ref_relatedDive => 'Mergulho relacionado';

  @override
  String get settings_conflict_ref_serviceKind => 'Tipo de manutencao';

  @override
  String get settings_conflict_ref_sighting => 'Avistamento';

  @override
  String get settings_conflict_ref_signer => 'Assinado por';

  @override
  String get settings_conflict_ref_sourceDive => 'Mergulho de origem';

  @override
  String get settings_conflict_ref_species => 'Especies';

  @override
  String get settings_conflict_ref_tag => 'Etiqueta';

  @override
  String get settings_conflict_ref_tank => 'Cilindro';

  @override
  String get settings_conflict_ref_trip => 'Viagem';

  @override
  String get settings_conflict_remoteVersion => 'Versao Remota';

  @override
  String settings_conflict_resolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conflitos resolvidos',
      one: '1 conflito resolvido',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_title => 'Resolver Conflitos';

  @override
  String get settings_data_appDefaultLocation => 'Local padrao do aplicativo';

  @override
  String get settings_data_backup => 'Backup e restauracao';

  @override
  String get settings_data_backup_subtitle => 'Criar um backup dos seus dados';

  @override
  String get settings_data_cloudSync =>
      'Sincronizacao na Nuvem do Banco de Dados';

  @override
  String get settings_data_customFolder => 'Pasta personalizada';

  @override
  String get settings_data_databaseStorage => 'Armazenamento do Banco de Dados';

  @override
  String get settings_data_export_completed => 'Exportacao concluida';

  @override
  String get settings_data_export_exporting => 'Exportando...';

  @override
  String settings_data_export_failed(Object error) {
    return 'Falha na exportacao: $error';
  }

  @override
  String get settings_data_header_backupSync => 'Backup e Sincronizacao';

  @override
  String get settings_data_header_storage => 'Armazenamento';

  @override
  String get settings_data_import_completed => 'Operacao concluida';

  @override
  String settings_data_import_failed(Object error) {
    return 'Falha na operacao: $error';
  }

  @override
  String get settings_data_offlineMaps => 'Mapas Offline';

  @override
  String get settings_data_offlineMaps_subtitle =>
      'Baixar mapas para uso offline';

  @override
  String get settings_data_restore => 'Restaurar';

  @override
  String get settings_data_restoreDialog_cancel => 'Cancelar';

  @override
  String get settings_data_restoreDialog_content =>
      'Aviso: Restaurar a partir de um backup substituira TODOS os dados atuais pelos dados do backup. Esta acao nao pode ser desfeita.\n\nTem certeza de que deseja continuar?';

  @override
  String get settings_data_restoreDialog_restore => 'Restaurar';

  @override
  String get settings_data_restoreDialog_title => 'Restaurar Backup';

  @override
  String get settings_data_restore_subtitle => 'Restaurar a partir de backup';

  @override
  String settings_data_syncTime_daysAgo(Object count) {
    return '${count}d atras';
  }

  @override
  String settings_data_syncTime_hoursAgo(Object count) {
    return '${count}h atras';
  }

  @override
  String get settings_data_syncTime_justNow => 'Agora mesmo';

  @override
  String settings_data_syncTime_minutesAgo(Object count) {
    return '${count}m atras';
  }

  @override
  String settings_data_sync_lastSynced(Object time) {
    return 'Ultima sincronizacao: $time';
  }

  @override
  String get settings_data_sync_notConfigured => 'Nao configurado';

  @override
  String get settings_data_sync_syncing => 'Sincronizando...';

  @override
  String get settings_decompression_aboutContent =>
      'Fatores de Gradiente (GF) controlam o quao conservadores sao seus calculos de descompressao. GF Low afeta paradas profundas, enquanto GF High afeta paradas rasas.\n\nValores mais baixos = mais conservador = paradas deco mais longas\nValores mais altos = menos conservador = paradas deco mais curtas';

  @override
  String get settings_decompression_aboutTitle => 'Sobre Fatores de Gradiente';

  @override
  String get settings_decompression_currentSettings => 'Configuracoes Atuais';

  @override
  String get settings_decompression_dialog_cancel => 'Cancelar';

  @override
  String get settings_decompression_dialog_conservatismHint =>
      'Valores mais baixos = mais conservador (NDL mais longo/mais deco)';

  @override
  String get settings_decompression_dialog_customValues =>
      'Valores Personalizados';

  @override
  String get settings_decompression_dialog_gfHigh => 'GF High';

  @override
  String get settings_decompression_dialog_gfLow => 'GF Low';

  @override
  String get settings_decompression_dialog_info =>
      'GF Low/High controlam o quao conservadores sao seus calculos de NDL e deco.';

  @override
  String get settings_decompression_dialog_presets => 'Predefinicoes';

  @override
  String get settings_decompression_dialog_save => 'Salvar';

  @override
  String get settings_decompression_dialog_title => 'Fatores de Gradiente';

  @override
  String settings_decompression_gfValue(Object gfLow, Object gfHigh) {
    return 'GF $gfLow/$gfHigh';
  }

  @override
  String get settings_decompression_header_gradientFactors =>
      'Fatores de Gradiente';

  @override
  String get settings_decompression_header_oxygenToxicity =>
      'Toxicidade do oxigênio';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'Selecionar predefinicao de conservadorismo $presetName';
  }

  @override
  String get settings_decompression_header_narcosis => 'Narcose';

  @override
  String get settings_decompression_o2Narcotic => 'O2 e narcotico';

  @override
  String get settings_decompression_o2Narcotic_subtitle =>
      'Quando ativado, tanto O2 quanto N2 sao considerados narcoticos (mais conservador). Quando desativado, apenas N2 contribui para a narcose.';

  @override
  String get settings_decompression_endLimit => 'Limite END';

  @override
  String get settings_decompression_endLimit_subtitle =>
      'Profundidade narcotica equivalente maxima usada para calculos de MND';

  @override
  String get settings_decompression_endLimit_dialog_title => 'Limite END';

  @override
  String get settings_decompression_cnsMethodTitle => 'Cálculo de CNS';

  @override
  String get settings_decompression_cnsMethodClassic =>
      'Tabela NOAA, em degraus (clássico)';

  @override
  String get settings_decompression_cnsMethodClassicDesc =>
      'Calcula cada faixa de 0,1 bar em sua borda mais rigorosa. Método original do Submersion.';

  @override
  String get settings_decompression_cnsMethodShearwater =>
      'Interpolação linear (estilo Shearwater)';

  @override
  String get settings_decompression_cnsMethodShearwaterDesc =>
      'Interpola entre os limites da NOAA conforme documentado pela Shearwater. Corresponde à maioria dos computadores de mergulho.';

  @override
  String get settings_decompression_cnsMethodSubsurface =>
      'Ajuste exponencial (como o Subsurface)';

  @override
  String get settings_decompression_cnsMethodSubsurfaceDesc =>
      'Ajuste de curva suave à tabela NOAA. Corresponde ao CNS calculado pelo Subsurface.';

  @override
  String get settings_decompression_cnsMethodAboutTitle =>
      'Sobre esses métodos';

  @override
  String get settings_decompression_cnsMethodAboutBody =>
      'Os três métodos se baseiam nos limites de exposição ao oxigênio do NOAA Diving Manual (300 minutos com ppO2 de 1,0 bar, 45 minutos a 1,6 bar). A tabela define limites apenas em passos de 0,1 bar: o método clássico calcula tudo o que está dentro de uma faixa na borda mais rigorosa da faixa, o que superestima sistematicamente a exposição entre as entradas. Os computadores de mergulho da Shearwater documentam uma interpolação linear entre os limites da NOAA, com um valor fixo de 15% por minuto acima de 1,65 bar. Em 2019, o Subsurface substituiu sua consulta em tabela por um ajuste exponencial suave de dois segmentos aos mesmos dados da NOAA (Robert C. Helling), que também se estende naturalmente além de 1,6 bar. Entre as entradas da tabela, os dois métodos suaves concordam dentro de cerca de um ponto de CNS; o método clássico exibe valores mais altos.';

  @override
  String get settings_decompression_cnsMethodDisclaimer =>
      'Os nomes se referem aos métodos publicados dos respectivos projetos e fabricantes; nenhuma afiliação ou endosso está implícito. Os valores calculados podem diferir das leituras reais do computador de mergulho.';

  @override
  String get settings_decompression_cnsMethodSourcesTitle => 'Fontes';

  @override
  String get settings_linkOpenFailed => 'Não foi possível abrir o link.';

  @override
  String get settings_decompression_cnsMethodSourceNoaa =>
      'NOAA: Diving Program (editora do NOAA Diving Manual)';

  @override
  String get settings_decompression_cnsMethodSourceShearwater =>
      'Shearwater: o relógio de oxigénio CNS';

  @override
  String get settings_decompression_cnsMethodSourceTheoreticalDiver =>
      'The Theoretical Diver: cálculo da toxicidade CNS do oxigénio';

  @override
  String get settings_decompression_cnsMethodSourceSubsurface =>
      'Subsurface: implementação (divelist.cpp)';

  @override
  String get settings_existingDb_cancel => 'Cancelar';

  @override
  String get settings_existingDb_continue => 'Continuar';

  @override
  String get settings_existingDb_current => 'Atual';

  @override
  String get settings_existingDb_dialog_message =>
      'Um banco de dados do Submersion ja existe nesta pasta.';

  @override
  String get settings_existingDb_dialog_title =>
      'Banco de Dados Existente Encontrado';

  @override
  String get settings_existingDb_existing => 'Existente';

  @override
  String get settings_existingDb_replaceWarning =>
      'O banco de dados existente sera copiado como backup antes de ser substituido.';

  @override
  String get settings_existingDb_replaceWithMyData =>
      'Substituir com meus dados';

  @override
  String get settings_existingDb_replaceWithMyData_subtitle =>
      'Sobrescrever com seu banco de dados atual';

  @override
  String get settings_existingDb_stat_buddies => 'Duplas';

  @override
  String get settings_existingDb_stat_dives => 'Mergulhos';

  @override
  String get settings_existingDb_stat_sites => 'Pontos';

  @override
  String get settings_existingDb_stat_trips => 'Viagens';

  @override
  String get settings_existingDb_stat_users => 'Usuarios';

  @override
  String get settings_existingDb_unknown => 'Desconhecido';

  @override
  String get settings_existingDb_useExisting => 'Usar banco de dados existente';

  @override
  String get settings_existingDb_useExisting_subtitle =>
      'Alternar para o banco de dados nesta pasta';

  @override
  String get settings_gfPreset_custom_description =>
      'Defina seus proprios valores';

  @override
  String get settings_gfPreset_custom_name => 'Personalizado';

  @override
  String get settings_gfPreset_high_description =>
      'Mais conservador, paradas deco mais longas';

  @override
  String get settings_gfPreset_high_name => 'Alto';

  @override
  String get settings_gfPreset_low_description =>
      'Menos conservador, deco mais curta';

  @override
  String get settings_gfPreset_low_name => 'Baixo';

  @override
  String get settings_gfPreset_medium_description => 'Abordagem equilibrada';

  @override
  String get settings_gfPreset_medium_name => 'Medio';

  @override
  String get settings_import_cancelButton => 'Cancelar importacao';

  @override
  String get settings_import_cancelling => 'Cancelando...';

  @override
  String get settings_import_dialog_title => 'Importando Dados';

  @override
  String get settings_import_doNotClose => 'Por favor, nao feche o aplicativo';

  @override
  String settings_import_itemCount(Object current, Object total) {
    return '$current de $total';
  }

  @override
  String get settings_import_phase_buddies => 'Importando duplas...';

  @override
  String get settings_import_phase_certifications =>
      'Importando certificacoes...';

  @override
  String get settings_import_phase_complete => 'Finalizando...';

  @override
  String get settings_import_phase_diveCenters =>
      'Importando centros de mergulho...';

  @override
  String get settings_import_phase_diveTypes =>
      'Importando tipos de mergulho...';

  @override
  String get settings_import_phase_dives => 'Importando mergulhos...';

  @override
  String get settings_import_phase_equipment => 'Importando equipamentos...';

  @override
  String get settings_import_phase_equipmentSets =>
      'Importando conjuntos de equipamentos...';

  @override
  String get settings_import_phase_parsing => 'Analisando arquivo...';

  @override
  String get settings_import_phase_preparing => 'Preparando...';

  @override
  String get settings_import_phase_sites => 'Importando pontos de mergulho...';

  @override
  String get settings_import_phase_tags => 'Importando tags...';

  @override
  String get settings_import_phase_trips => 'Importando viagens...';

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
    return 'Progresso da importacao: $percent por cento';
  }

  @override
  String get settings_language_appBar_title => 'Idioma';

  @override
  String get settings_language_selected => 'Selecionado';

  @override
  String get settings_language_systemDefault => 'Padrao do Sistema';

  @override
  String get settings_lightroom_albumFilter_all => 'Catálogo inteiro';

  @override
  String get settings_lightroom_albumFilter_title => 'Álbuns a analisar';

  @override
  String get settings_lightroom_autoPoll_title =>
      'Verificar novas fotos automaticamente';

  @override
  String settings_lightroom_clientId_help(String redirectUri) {
    return 'Crie uma integração na Adobe Developer Console com a API Lightroom Services e um tipo de credencial compatível com PKCE. Insira abaixo a URI de redirecionamento da sua credencial — as credenciais de Native App usam um esquema personalizado — ou deixe em branco para usar $redirectUri.';
  }

  @override
  String get settings_lightroom_clientId_label => 'ID de cliente da Adobe';

  @override
  String get settings_lightroom_clientSecret_label =>
      'Segredo do cliente (opcional)';

  @override
  String get settings_lightroom_redirectUri_label =>
      'URI de redirecionamento (opcional)';

  @override
  String get settings_lightroom_connect => 'Conectar Lightroom';

  @override
  String get settings_lightroom_connectEmbedded => 'Conectar com a Adobe';

  @override
  String get settings_lightroom_advancedByo =>
      'Usar suas próprias credenciais da Adobe';

  @override
  String get settings_lightroom_connect_codeLabel =>
      'URL redirecionada ou código';

  @override
  String get settings_lightroom_connect_emptyCode =>
      'Cole a URL redirecionada ou o código de autorização';

  @override
  String settings_lightroom_connect_failed(String error) {
    return 'Não foi possível conectar ao Lightroom: $error';
  }

  @override
  String get settings_lightroom_connect_instructions =>
      'Inicie sessão na Adobe na janela do navegador e cole o endereço completo da página em que você chegar (ele contém o código de autorização).';

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
      'As fotos vinculadas permanecem nos seus mergulhos e continuam sendo exibidas a partir do armazenamento de mídia. Novas fotos não serão mais vinculadas.';

  @override
  String get settings_lightroom_disconnect_confirmTitle =>
      'Desconectar o Lightroom?';

  @override
  String settings_lightroom_lastPoll(String when) {
    return 'Última verificação: $when';
  }

  @override
  String get settings_lightroom_needsReauth => 'Reconexão necessária';

  @override
  String get settings_lightroom_scanNow => 'Analisar Lightroom';

  @override
  String get settings_lightroom_scan_running => 'Analisando o Lightroom...';

  @override
  String settings_lightroom_scan_summary(
    int attached,
    int suggested,
    int skipped,
  ) {
    return '$attached vinculadas, $suggested sugeridas, $skipped já vinculadas';
  }

  @override
  String get settings_lightroom_subtitle =>
      'Vincular fotos e vídeos aos mergulhos automaticamente';

  @override
  String get settings_lightroom_title => 'Adobe Lightroom';

  @override
  String get settings_manage_checklistTemplates =>
      'Modelos de Lista de Verificação';

  @override
  String get settings_manage_checklistTemplates_subtitle =>
      'Listas de tarefas reutilizáveis para planejamento de viagens';

  @override
  String get settings_manage_diveRoles => 'Funções de Mergulho';

  @override
  String get settings_manage_diveRoles_subtitle =>
      'Gerenciar funções de mergulho personalizadas';

  @override
  String get settings_manage_diveTypes => 'Tipos de Mergulho';

  @override
  String get settings_manage_diveTypes_subtitle =>
      'Gerenciar tipos de mergulho personalizados';

  @override
  String get settings_manage_header_manageData => 'Gerenciar Dados';

  @override
  String get settings_manage_species => 'Especies';

  @override
  String get settings_manage_species_subtitle =>
      'Gerenciar catalogo de especies de vida marinha';

  @override
  String get settings_manage_tags => 'Etiquetas';

  @override
  String get settings_manage_tags_subtitle =>
      'Gerenciar, mesclar e excluir etiquetas';

  @override
  String get settings_manage_tankPresets => 'Predefinicoes de Cilindro';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Gerenciar configuracoes personalizadas de cilindro';

  @override
  String get settings_manage_serviceTypes => 'Tipos de manutenção';

  @override
  String get settings_manage_serviceTypes_subtitle =>
      'A manutenção de que o seu equipamento precisa, e com que frequência';

  @override
  String get settings_migrationProgress_doNotClose =>
      'Por favor, nao feche o aplicativo';

  @override
  String get settings_migration_backupInfo =>
      'Um backup sera criado antes da movimentacao. Seus dados nao serao perdidos.';

  @override
  String get settings_migration_cancel => 'Cancelar';

  @override
  String get settings_migration_cloudSyncWarning =>
      'A sincronizacao na nuvem gerenciada pelo aplicativo sera desativada. O servico de sincronizacao da sua pasta gerenciara a sincronizacao.';

  @override
  String get settings_migration_dialog_message =>
      'Seu banco de dados sera movido:';

  @override
  String get settings_migration_dialog_title => 'Mover Banco de Dados?';

  @override
  String get settings_migration_from => 'De';

  @override
  String get settings_migration_moveDatabase => 'Mover Banco de Dados';

  @override
  String get settings_migration_to => 'Para';

  @override
  String settings_notifications_days(Object count) {
    return '$count dias';
  }

  @override
  String get settings_notifications_disabled_continueButton => 'Continuar';

  @override
  String get settings_notifications_disabled_openSettingsButton =>
      'Abrir Configuracoes';

  @override
  String get settings_notifications_disabled_subtitleUnrequested =>
      'Os lembretes de servico precisam de permissao para enviar notificacoes';

  @override
  String get settings_notifications_disabled_subtitle =>
      'Ative nas configuracoes do sistema para receber lembretes';

  @override
  String get settings_notifications_disabled_title =>
      'Notificacoes Desativadas';

  @override
  String get settings_notifications_enableServiceReminders =>
      'Ativar Lembretes de Manutencao';

  @override
  String get settings_notifications_enableServiceReminders_subtitle =>
      'Receba notificacoes quando a manutencao de equipamentos estiver vencida';

  @override
  String get settings_notifications_header_reminderSchedule =>
      'Agenda de Lembretes';

  @override
  String get settings_notifications_header_serviceReminders =>
      'Lembretes de Manutencao';

  @override
  String get settings_notifications_howItWorks_content =>
      'As notificacoes sao agendadas quando o aplicativo e iniciado e atualizadas periodicamente em segundo plano. Voce pode personalizar lembretes para itens de equipamento individuais na tela de edicao.';

  @override
  String get settings_notifications_howItWorks_title => 'Como funciona';

  @override
  String get settings_notifications_permissionRequired =>
      'Ative as notificacoes nas configuracoes do sistema';

  @override
  String get settings_notifications_remindBeforeDue =>
      'Lembrar-me antes da manutencao:';

  @override
  String get settings_notifications_reminderTime => 'Horario do Lembrete';

  @override
  String get settings_profile_activeDiver_subtitle =>
      'Mergulhador ativo - toque para alternar';

  @override
  String get settings_profile_addNewDiver => 'Adicionar Novo Mergulhador';

  @override
  String get settings_profile_error_loadingDiver =>
      'Erro ao carregar mergulhador';

  @override
  String get settings_profile_header_activeDiver => 'Mergulhador Ativo';

  @override
  String get settings_profile_header_manageDivers => 'Gerenciar Mergulhadores';

  @override
  String get settings_profile_noDiverProfile => 'Nenhum perfil de mergulhador';

  @override
  String get settings_profile_noDiverProfile_subtitle =>
      'Toque para criar seu perfil';

  @override
  String get settings_profile_switchDiver_title => 'Alternar Mergulhador';

  @override
  String settings_profile_switchedTo(Object diverName) {
    return 'Alternado para $diverName';
  }

  @override
  String get settings_profile_viewAllDivers => 'Ver Todos os Mergulhadores';

  @override
  String get settings_profile_viewAllDivers_subtitle =>
      'Adicionar ou editar perfis de mergulhadores';

  @override
  String get settings_profileHub_addNewDiver => 'Adicionar Novo Mergulhador';

  @override
  String get settings_profileHub_cannotDeleteOnly =>
      'Nao e possivel excluir o unico perfil de mergulhador';

  @override
  String get settings_profileHub_createDiverTitle => 'Criar Mergulhador';

  @override
  String settings_profileHub_deleteConfirmContent(String name) {
    return 'Tem certeza de que deseja excluir $name? Todos os registros de mergulho associados ficarao sem atribuicao.';
  }

  @override
  String get settings_profileHub_deleteConfirmTitle => 'Excluir Mergulhador?';

  @override
  String get settings_profileHub_deleteDiver => 'Excluir Mergulhador';

  @override
  String get settings_profileHub_deleted => 'Mergulhador excluido';

  @override
  String get settings_profileHub_emergencyContacts => 'Contatos de Emergencia';

  @override
  String settings_profileHub_emergencyContacts_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contatos configurados',
      one: '1 contato configurado',
      zero: 'Nao configurado',
    );
    return '$_temp0';
  }

  @override
  String get settings_profileHub_insurance => 'Seguro';

  @override
  String get settings_profileHub_insurance_expired => 'Expirado';

  @override
  String get settings_profileHub_insurance_notSet => 'Nao configurado';

  @override
  String get settings_profileHub_medicalInfo => 'Informacoes Medicas';

  @override
  String get settings_profileHub_medicalInfo_notSet => 'Nao configurado';

  @override
  String get settings_profileHub_notes => 'Notas';

  @override
  String get settings_profileHub_notes_notSet => 'Nao configurado';

  @override
  String get settings_profileHub_personalInfo => 'Informacoes Pessoais';

  @override
  String get settings_profileHub_personalInfo_notSet => 'Nao configurado';

  @override
  String get settings_profileHub_saved => 'Alteracoes salvas';

  @override
  String get settings_profileHub_switchDiver => 'Trocar de Mergulhador';

  @override
  String get settings_s3Config_action_remove => 'Remover configuração';

  @override
  String get settings_s3Config_action_testConnection => 'Testar conexão';

  @override
  String get settings_s3Config_advanced_title => 'Avançado';

  @override
  String get settings_s3Config_appBar_title =>
      'Armazenamento compatível com S3';

  @override
  String get settings_s3Config_error_secureStorage =>
      'Não foi possível acessar o armazenamento seguro';

  @override
  String get settings_s3Config_field_accessKeyId_label => 'Access Key ID';

  @override
  String get settings_s3Config_field_bucket_label => 'Bucket';

  @override
  String get settings_s3Config_field_endpoint_helper =>
      'Por exemplo: https://s3.example.com';

  @override
  String get settings_s3Config_field_endpoint_label => 'URL do endpoint';

  @override
  String get settings_s3Config_field_pathStyle_label =>
      'Usar endereçamento path-style';

  @override
  String get settings_s3Config_field_pathStyle_subtitle =>
      'Exigido pela maioria dos servidores auto-hospedados';

  @override
  String get settings_s3Config_field_prefix_label => 'Prefixo de chaves';

  @override
  String settings_s3Config_field_region_helperAuto(String region) {
    return 'Detectado automaticamente: $region';
  }

  @override
  String get settings_s3Config_field_region_label => 'Região';

  @override
  String get settings_s3Config_field_secretAccessKey_label =>
      'Secret Access Key';

  @override
  String get settings_s3Config_remove_confirm_action => 'Remover';

  @override
  String get settings_s3Config_remove_confirm_body =>
      'A sincronização via S3 será interrompida neste dispositivo. Seus dados no bucket não são excluídos.';

  @override
  String get settings_s3Config_remove_confirm_title =>
      'Remover a configuração do S3?';

  @override
  String get settings_s3Config_removed => 'Configuração do S3 removida';

  @override
  String get settings_s3Config_saved => 'Configuração do S3 salva';

  @override
  String settings_s3Config_test_regionDetected(String region) {
    return 'Região detectada: $region';
  }

  @override
  String get settings_s3Config_test_success => 'Conexão bem-sucedida';

  @override
  String get settings_s3Config_validation_endpointInvalid =>
      'Insira um URL http:// ou https:// válido';

  @override
  String get settings_s3Config_validation_endpointPath =>
      'O URL do endpoint não deve incluir um caminho';

  @override
  String get settings_s3Config_validation_required => 'Obrigatório';

  @override
  String get settings_s3Config_warning_http =>
      'Este endpoint usa HTTP sem criptografia. Credenciais e dados de mergulho trafegarão sem criptografia; use apenas em uma rede confiável.';

  @override
  String get settings_section_about_subtitle =>
      'Informacoes e licencas do aplicativo';

  @override
  String get settings_section_about_title => 'Sobre';

  @override
  String get settings_section_appearance_subtitle => 'Tema e exibicao';

  @override
  String get settings_section_appearance_title => 'Aparencia';

  @override
  String get settings_section_data_subtitle =>
      'Backup, restauracao e armazenamento';

  @override
  String get settings_section_data_title => 'Dados';

  @override
  String get settings_section_decompression_subtitle => 'Fatores de gradiente';

  @override
  String get settings_section_decompression_title => 'Descompressao';

  @override
  String get settings_section_diverProfile_subtitle =>
      'Mergulhador ativo e perfis';

  @override
  String get settings_section_diverProfile_title => 'Perfil do Mergulhador';

  @override
  String get settings_section_manage_subtitle =>
      'Tipos de mergulho e predefinicoes de cilindro';

  @override
  String get settings_section_manage_title => 'Gerenciar';

  @override
  String get settings_section_notifications_subtitle =>
      'Lembretes de manutencao';

  @override
  String get settings_section_notifications_title => 'Notificacoes';

  @override
  String get settings_section_units_subtitle => 'Preferencias de medicao';

  @override
  String get settings_section_units_title => 'Unidades';

  @override
  String get settings_storage_appBar_title => 'Armazenamento do Banco de Dados';

  @override
  String get settings_storage_appDefault => 'Padrao do Aplicativo';

  @override
  String get settings_storage_appDefaultLocation =>
      'Local padrao do aplicativo';

  @override
  String get settings_storage_appDefault_subtitle =>
      'Local de armazenamento padrao do aplicativo';

  @override
  String get settings_storage_currentLocation => 'Localizacao Atual';

  @override
  String get settings_storage_currentLocation_label => 'Localizacao atual';

  @override
  String get settings_storage_customFolder => 'Pasta Personalizada';

  @override
  String get settings_storage_customFolder_change => 'Alterar';

  @override
  String get settings_storage_customFolder_subtitle =>
      'Escolha uma pasta sincronizada (Dropbox, Google Drive, etc.)';

  @override
  String get settings_storage_customFolder_subtitleDeviceOnly =>
      'Mova o banco de dados para o armazenamento interno ou o cartão SD';

  @override
  String get settings_storage_customFolder_deviceOnly_noCloudSync =>
      'A sincronização na nuvem gerenciada pelo app fica desativada enquanto o banco de dados está em um volume de armazenamento do dispositivo. Nenhum serviço de sincronização consegue acessar essa pasta no Android, então use Backup e Restauração para manter cópias em outro lugar.';

  @override
  String settings_storage_dbStats(
    Object fileSize,
    Object diveCount,
    Object siteCount,
  ) {
    return '$fileSize • $diveCount mergulhos • $siteCount pontos';
  }

  @override
  String get settings_storage_dismissError_tooltip => 'Dispensar erro';

  @override
  String get settings_storage_dismissSuccess_tooltip =>
      'Dispensar mensagem de sucesso';

  @override
  String get settings_storage_header_storageLocation =>
      'Local de Armazenamento';

  @override
  String get settings_storage_info_customActive =>
      'A sincronizacao na nuvem gerenciada pelo aplicativo esta desativada. O servico de sincronizacao da sua pasta (Dropbox, Google Drive, etc.) gerencia a sincronizacao.';

  @override
  String get settings_storage_info_customAvailable =>
      'Usar uma pasta personalizada desativa a sincronizacao na nuvem gerenciada pelo aplicativo. O servico de sincronizacao da sua pasta gerenciara a sincronizacao.';

  @override
  String get settings_storage_loading => 'Carregando...';

  @override
  String get settings_storage_migrating_doNotClose =>
      'Por favor, nao feche o aplicativo';

  @override
  String get settings_storage_migrating_movingDatabase =>
      'Movendo banco de dados...';

  @override
  String get settings_storage_migrating_movingToAppDefault =>
      'Movendo para o local padrao...';

  @override
  String get settings_storage_migrating_replacingExisting =>
      'Substituindo banco de dados existente...';

  @override
  String get settings_storage_migrating_switchingToExisting =>
      'Alternando para banco de dados existente...';

  @override
  String get settings_storage_notSet => 'Nao definido';

  @override
  String settings_storage_success_backupAt(Object path) {
    return 'Original mantido como backup em:\n$path';
  }

  @override
  String get settings_storage_success_moved =>
      'Banco de dados movido com sucesso';

  @override
  String get settings_storage_dangerZone => 'Zona de Perigo';

  @override
  String get settings_storage_resetDatabase => 'Redefinir Banco de Dados';

  @override
  String get settings_storage_resetDatabase_subtitle =>
      'Excluir todos os dados deste dispositivo e começar do zero';

  @override
  String get settings_storage_resetDialog_title => 'Redefinir Banco de Dados?';

  @override
  String get settings_storage_resetDialog_body =>
      'Isso exclui permanentemente todos os dados DESTE dispositivo, incluindo mergulhos, pontos, equipamentos e configurações. Um backup é criado automaticamente antes da redefinição.\n\nA sua biblioteca na nuvem não é excluída e os outros dispositivos mantêm os seus dados. A sincronização na nuvem será desconectada para que a redefinição não seja desfeita; pode reconectá-la em Definições > Sincronização na nuvem.';

  @override
  String get settings_storage_resetDialog_confirmWord => 'Excluir';

  @override
  String get settings_storage_resetDialog_confirmHint =>
      'Digite \"Excluir\" para confirmar';

  @override
  String get settings_storage_resetDialog_confirmButton => 'Redefinir';

  @override
  String get settings_storage_resetDialog_backupFailed =>
      'O backup falhou. A redefinicao foi abortada para proteger seus dados.';

  @override
  String settings_storage_resetDialog_resetFailed(Object error) {
    return 'A redefinicao falhou: $error';
  }

  @override
  String get settings_storage_resetComplete_title =>
      'Banco de Dados Redefinido';

  @override
  String get settings_storage_resetComplete_description =>
      'Os dados deste dispositivo foram apagados e um backup foi salvo. A sincronização na nuvem está agora desconectada para que a redefinição não seja desfeita; pode reconectá-la em Definições > Sincronização na nuvem. Toque em continuar para recarregar o app.';

  @override
  String get settings_summary_activeDiver => 'Mergulhador Ativo';

  @override
  String get settings_summary_currentConfiguration => 'Configuracao Atual';

  @override
  String get settings_summary_depth => 'Profundidade';

  @override
  String get settings_summary_error => 'Erro';

  @override
  String get settings_summary_gradientFactors => 'Fatores de Gradiente';

  @override
  String get settings_summary_loading => 'Carregando...';

  @override
  String get settings_summary_notSet => 'Nao definido';

  @override
  String get settings_summary_pressure => 'Pressao';

  @override
  String get settings_summary_subtitle =>
      'Selecione uma categoria para configurar';

  @override
  String get settings_summary_temperature => 'Temperatura';

  @override
  String get settings_summary_theme => 'Tema';

  @override
  String get settings_summary_theme_dark => 'Escuro';

  @override
  String get settings_summary_theme_light => 'Claro';

  @override
  String get settings_summary_theme_system => 'Sistema';

  @override
  String get settings_summary_tip =>
      'Dica: Use a secao Dados para fazer backup dos seus registros de mergulho regularmente.';

  @override
  String get settings_summary_title => 'Configuracoes';

  @override
  String get settings_summary_unitPreferences => 'Preferencias de Unidade';

  @override
  String get settings_summary_units => 'Unidades';

  @override
  String get settings_summary_volume => 'Volume';

  @override
  String get settings_summary_weight => 'Peso';

  @override
  String get settings_units_custom => 'Personalizado';

  @override
  String get settings_units_dateFormat => 'Formato de Data';

  @override
  String get settings_units_depth => 'Profundidade';

  @override
  String get settings_units_depth_feet => 'Pes (ft)';

  @override
  String get settings_units_depth_meters => 'Metros (m)';

  @override
  String get settings_units_dialog_dateFormat => 'Formato de Data';

  @override
  String get settings_units_dialog_depthUnit => 'Unidade de Profundidade';

  @override
  String get settings_units_dialog_pressureUnit => 'Unidade de Pressao';

  @override
  String get settings_units_dialog_sacRateUnit => 'Unidade de Taxa SAC';

  @override
  String get settings_units_gasModel => 'Cálculos de gás';

  @override
  String get settings_units_gasModel_real => 'Gás real';

  @override
  String get settings_units_gasModel_real_subtitle =>
      'Considera a compressibilidade. Um cilindro de 12 L a 200 bar contém cerca de 2317 L.';

  @override
  String get settings_units_gasModel_ideal => 'Gás ideal';

  @override
  String get settings_units_gasModel_ideal_subtitle =>
      'Corresponde ao cálculo manual e às tabelas. Um cilindro de 12 L a 200 bar contém 2400 L.';

  @override
  String get settings_units_gasModel_explanation =>
      'Como a pressão do cilindro é convertida em volume de gás. Afeta o RMV, as estatísticas de gás, o planeador e as calculadoras. O gás ideal corresponde ao cálculo ensinado pelas agências; o gás real é fisicamente exato e apresenta um RMV cerca de 5% mais baixo.';

  @override
  String get settings_units_dialog_gasModel => 'Cálculos de gás';

  @override
  String get settings_units_dialog_temperatureUnit => 'Unidade de Temperatura';

  @override
  String get settings_units_dialog_timeFormat => 'Formato de Hora';

  @override
  String get settings_units_dialog_volumeUnit => 'Unidade de Volume';

  @override
  String get settings_units_dialog_weightUnit => 'Unidade de Peso';

  @override
  String get settings_units_header_individualUnits => 'Unidades Individuais';

  @override
  String get settings_units_header_timeDateFormat => 'Formato de Hora e Data';

  @override
  String get settings_units_header_unitSystem => 'Sistema de Unidades';

  @override
  String get settings_units_imperial => 'Imperial';

  @override
  String get settings_units_metric => 'Metrico';

  @override
  String get settings_units_pressure => 'Pressao';

  @override
  String get settings_units_pressure_bar => 'Bar';

  @override
  String get settings_units_pressure_psi => 'PSI';

  @override
  String get settings_units_quickSelect => 'Selecao Rapida';

  @override
  String get settings_units_sacRate => 'Taxa SAC';

  @override
  String get settings_units_defaultCurrency => 'Moeda padrão';

  @override
  String get settings_units_dialog_defaultCurrency => 'Moeda padrão';

  @override
  String get settings_units_sac_pressurePerMinute => 'Pressao por minuto';

  @override
  String get settings_units_sac_pressurePerMinute_subtitle =>
      'Nao requer volume do cilindro (bar/min ou psi/min)';

  @override
  String get settings_units_sac_volumePerMinute => 'Volume por minuto';

  @override
  String get settings_units_sac_volumePerMinute_subtitle =>
      'Requer volume do cilindro (L/min ou cuft/min)';

  @override
  String get settings_units_temperature => 'Temperatura';

  @override
  String get settings_units_temperature_celsius => 'Celsius (°C)';

  @override
  String get settings_units_temperature_fahrenheit => 'Fahrenheit (°F)';

  @override
  String get settings_units_timeFormat => 'Formato de Hora';

  @override
  String get settings_units_volume => 'Volume';

  @override
  String get settings_units_volume_cubicFeet => 'Pes Cubicos (cuft)';

  @override
  String get settings_units_volume_liters => 'Litros (L)';

  @override
  String get settings_units_weight => 'Peso';

  @override
  String get settings_units_weight_kilograms => 'Quilogramas (kg)';

  @override
  String get settings_units_weight_pounds => 'Libras (lbs)';

  @override
  String get settings_updates_automaticUpdates => 'Atualizações automáticas';

  @override
  String get settings_updates_automaticUpdatesSubtitle =>
      'Verificar atualizações periodicamente';

  @override
  String get settings_updates_betaDialogBody =>
      'As versões beta são publicadas a cada alteração e podem atualizar o banco de dados do seu registro de mergulhos antes da versão estável. Voltar depois para o canal estável não fará downgrade do app, e todos os dispositivos que sincronizam entre si devem usar o mesmo canal. Um backup é feito automaticamente antes de qualquer atualização do banco de dados.';

  @override
  String get settings_updates_betaDialogConfirm => 'Mudar para Beta';

  @override
  String get settings_updates_betaDialogTitle => 'Receber atualizações beta?';

  @override
  String get settings_updates_channel => 'Canal de atualização';

  @override
  String settings_updates_channelBadgeBeta(String version) {
    return '$version (Beta)';
  }

  @override
  String get settings_updates_channelBeta => 'Beta';

  @override
  String get settings_updates_channelBetaSubtitle =>
      'Novas versões a cada alteração, antes da estável';

  @override
  String get settings_updates_channelStable => 'Estável';

  @override
  String get settings_updates_channelStableSubtitle =>
      'Apenas versões testadas';

  @override
  String get settings_updates_checkForUpdates => 'Verificar atualizações';

  @override
  String get settings_updates_checking => 'Verificando...';

  @override
  String settings_updates_downloading(String progress) {
    return 'Baixando... $progress%';
  }

  @override
  String settings_updates_error(String message) {
    return 'Erro: $message';
  }

  @override
  String get settings_updates_header => 'Atualizações';

  @override
  String get settings_updates_joinBeta => 'Participar do Beta';

  @override
  String get settings_updates_joinBetaSubtitle =>
      'Receba novos recursos antes através do programa beta';

  @override
  String get settings_updates_lastChecked => 'Última verificação';

  @override
  String get settings_updates_never => 'Nunca';

  @override
  String settings_updates_readyToInstall(String version) {
    return 'Versão $version pronta para instalar';
  }

  @override
  String get settings_updates_stableSwitchNotice =>
      'Você permanecerá nesta beta até que a próxima versão estável seja mais recente que ela.';

  @override
  String get settings_updates_upToDate => 'Atualizado';

  @override
  String settings_updates_versionAvailable(String version) {
    return 'Versão $version disponível';
  }

  @override
  String get signatures_action_clear => 'Limpar';

  @override
  String get signatures_action_closeSignatureView =>
      'Fechar visualização de assinatura';

  @override
  String get signatures_action_deleteSignature => 'Excluir assinatura';

  @override
  String get signatures_action_done => 'Concluir';

  @override
  String get signatures_action_readyToSign => 'Pronto para Assinar';

  @override
  String get signatures_action_request => 'Solicitar';

  @override
  String get signatures_action_saveSignature => 'Salvar Assinatura';

  @override
  String signatures_buddyCard_notSignedSemantics(Object name) {
    return 'Assinatura de $name, não assinado';
  }

  @override
  String signatures_buddyCard_signedSemantics(Object name) {
    return 'Assinatura de $name, assinado';
  }

  @override
  String get signatures_captureInstructorSignature =>
      'Capturar Assinatura do Instrutor';

  @override
  String signatures_deleteDialog_message(Object name) {
    return 'Tem certeza de que deseja excluir a assinatura de $name? Isso não pode ser desfeito.';
  }

  @override
  String get signatures_deleteDialog_title => 'Excluir Assinatura?';

  @override
  String get signatures_drawSignatureHint => 'Desenhe sua assinatura acima';

  @override
  String get signatures_drawSignatureHintDetailed =>
      'Desenhe a assinatura acima usando o dedo ou caneta stylus';

  @override
  String get signatures_drawSignatureSemantics => 'Desenhar assinatura';

  @override
  String get signatures_error_drawSignature => 'Desenhe uma assinatura';

  @override
  String get signatures_error_enterSignerName => 'Digite o nome do signatário';

  @override
  String get signatures_field_instructorName => 'Nome do Instrutor';

  @override
  String get signatures_field_instructorNameHint =>
      'Digite o nome do instrutor';

  @override
  String get signatures_handoff_title => 'Entregue seu dispositivo para';

  @override
  String get signatures_instructorSignature => 'Assinatura do Instrutor';

  @override
  String get signatures_noSignatureImage => 'Sem imagem de assinatura';

  @override
  String signatures_signHere(Object name) {
    return '$name - Assine Aqui';
  }

  @override
  String get signatures_signed => 'Assinado';

  @override
  String signatures_signedCountSemantics(Object signed, Object total) {
    return '$signed de $total companheiros assinaram';
  }

  @override
  String signatures_signedDate(Object date) {
    return 'Assinado em $date';
  }

  @override
  String get signatures_title => 'Assinaturas';

  @override
  String get signatures_viewSignature => 'Ver assinatura';

  @override
  String signatures_viewSignatureSemantics(Object name) {
    return 'Ver assinatura de $name';
  }

  @override
  String get statistics_appBar_title => 'Estatisticas';

  @override
  String statistics_categoryCard_semanticLabel(Object title) {
    return 'Categoria de estatisticas: $title';
  }

  @override
  String get statistics_category_conditions_subtitle =>
      'Visibilidade e temperatura';

  @override
  String get statistics_category_conditions_title => 'Condicoes';

  @override
  String get statistics_category_equipment_subtitle =>
      'Uso de equipamento e peso';

  @override
  String get statistics_category_equipment_title => 'Equipamento';

  @override
  String get statistics_category_gas_subtitle => 'Taxas SAC e misturas de gas';

  @override
  String get statistics_category_gas_title => 'Consumo de Ar';

  @override
  String get statistics_category_geographic_subtitle => 'Paises e regioes';

  @override
  String get statistics_category_geographic_title => 'Geografico';

  @override
  String get statistics_category_marineLife_subtitle =>
      'Avistamentos de especies';

  @override
  String get statistics_category_marineLife_title => 'Vida Marinha';

  @override
  String get statistics_category_overview_title => 'Overview';

  @override
  String get statistics_category_overview_subtitle =>
      'Totals, records, and breakdowns at a glance';

  @override
  String get statistics_category_profile_subtitle => 'Taxas de subida e deco';

  @override
  String get statistics_category_profile_title => 'Analise de Perfil';

  @override
  String get statistics_category_progression_subtitle =>
      'Tendencias de profundidade e tempo';

  @override
  String get statistics_category_progression_title => 'Progressao';

  @override
  String get statistics_category_social_subtitle =>
      'Duplas e centros de mergulho';

  @override
  String get statistics_category_social_title => 'Social';

  @override
  String get statistics_category_timePatterns_subtitle =>
      'Quando voce mergulha';

  @override
  String get statistics_category_timePatterns_title => 'Padroes de Horario';

  @override
  String statistics_chart_barSemanticLabel(Object count) {
    return 'Grafico de barras com $count categorias';
  }

  @override
  String statistics_chart_distributionSemanticLabel(Object count) {
    return 'Grafico de pizza de distribuicao com $count segmentos';
  }

  @override
  String statistics_chart_multiTrendSemanticLabel(Object seriesNames) {
    return 'Grafico de linhas multi-tendencia comparando $seriesNames';
  }

  @override
  String get statistics_chart_noBarData => 'Nenhum dado disponivel';

  @override
  String get statistics_chart_noDistributionData =>
      'Nenhum dado de distribuicao disponivel';

  @override
  String get statistics_chart_noTrendData =>
      'Nenhum dado de tendencia disponivel';

  @override
  String statistics_chart_trendSemanticLabel(Object count) {
    return 'Grafico de linhas de tendencia mostrando $count pontos de dados';
  }

  @override
  String statistics_chart_trendSemanticLabelWithAxis(
    Object count,
    Object yAxisLabel,
  ) {
    return 'Grafico de linhas de tendencia mostrando $count pontos de dados para $yAxisLabel';
  }

  @override
  String get statistics_conditions_appBar_title => 'Condicoes';

  @override
  String get statistics_conditions_entryMethod_empty =>
      'Nenhum dado de metodo de entrada disponivel';

  @override
  String get statistics_conditions_entryMethod_error =>
      'Falha ao carregar dados de metodo de entrada';

  @override
  String get statistics_conditions_entryMethod_subtitle => 'Costa, barco, etc.';

  @override
  String get statistics_conditions_entryMethod_title => 'Metodo de Entrada';

  @override
  String get statistics_conditions_temperature_empty =>
      'Nenhum dado de temperatura disponivel';

  @override
  String get statistics_conditions_temperature_error =>
      'Falha ao carregar dados de temperatura';

  @override
  String get statistics_conditions_temperature_seriesAvg => 'Media';

  @override
  String get statistics_conditions_temperature_seriesMax => 'Max';

  @override
  String get statistics_conditions_temperature_seriesMin => 'Min';

  @override
  String get statistics_conditions_temperature_subtitle =>
      'Temperaturas min/media/max';

  @override
  String get statistics_conditions_temperature_title =>
      'Temperatura da Agua por Mes';

  @override
  String get statistics_conditions_visibility_error =>
      'Falha ao carregar dados de visibilidade';

  @override
  String get statistics_conditions_visibility_subtitle =>
      'Mergulhos por condicao de visibilidade';

  @override
  String get statistics_conditions_visibility_title =>
      'Distribuicao de Visibilidade';

  @override
  String get statistics_conditions_waterType_error =>
      'Falha ao carregar dados de tipo de agua';

  @override
  String get statistics_conditions_waterType_subtitle =>
      'Mergulhos em agua salgada vs doce';

  @override
  String get statistics_conditions_waterType_title => 'Tipo de Agua';

  @override
  String get statistics_equipment_appBar_title => 'Equipamento';

  @override
  String get statistics_equipment_mostUsedGear_error =>
      'Falha ao carregar dados de equipamento';

  @override
  String get statistics_equipment_mostUsedGear_subtitle =>
      'Equipamento por numero de mergulhos';

  @override
  String get statistics_equipment_mostUsedGear_title =>
      'Equipamento Mais Usado';

  @override
  String get statistics_equipment_weightTrend_error =>
      'Falha ao carregar tendencia de peso';

  @override
  String get statistics_equipment_weightTrend_subtitle =>
      'Peso medio ao longo do tempo';

  @override
  String get statistics_equipment_weightTrend_title => 'Tendencia de Peso';

  @override
  String get statistics_error_loadingStatistics =>
      'Erro ao carregar estatisticas';

  @override
  String get statistics_filterBar_clear => 'Limpar filtro';

  @override
  String statistics_filterBar_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos',
      one: '1 mergulho',
    );
    return '$_temp0';
  }

  @override
  String get statistics_gas_appBar_title => 'Consumo de Ar';

  @override
  String get statistics_gas_gasMix_error =>
      'Falha ao carregar dados de mistura de gas';

  @override
  String get statistics_gas_gasMix_subtitle => 'Mergulhos por tipo de gas';

  @override
  String get statistics_gas_gasMix_title => 'Distribuicao de Mistura de Gas';

  @override
  String get statistics_gas_sacByRole_empty =>
      'Nenhum dado de multi-cilindro disponivel';

  @override
  String get statistics_gas_sacByRole_error =>
      'Falha ao carregar SAC por funcao';

  @override
  String get statistics_gas_sacByRole_subtitle =>
      'Consumo medio por tipo de cilindro';

  @override
  String get statistics_gas_sacByRole_title => 'SAC por Funcao do Cilindro';

  @override
  String get statistics_gas_sacRecords_best => 'Melhor Taxa SAC';

  @override
  String get statistics_gas_sacRecords_empty =>
      'Nenhum dado de SAC disponivel ainda';

  @override
  String get statistics_gas_sacRecords_error =>
      'Falha ao carregar registros de SAC';

  @override
  String get statistics_gas_sacRecords_highest => 'Maior Taxa SAC';

  @override
  String get statistics_gas_sacRecords_subtitle =>
      'Melhor e pior consumo de ar';

  @override
  String get statistics_gas_sacRecords_title => 'Registros de Taxa SAC';

  @override
  String get statistics_gas_sacTrend_error =>
      'Falha ao carregar tendencia de SAC';

  @override
  String get statistics_gas_sacTrend_subtitle =>
      'Media mensal ao longo de 5 anos';

  @override
  String get statistics_gas_sacTrend_title => 'Tendencia da Taxa SAC';

  @override
  String get statistics_gas_tankRole_backGas => 'Gas Principal';

  @override
  String get statistics_gas_tankRole_bailout => 'Bailout';

  @override
  String get statistics_gas_tankRole_deco => 'Deco';

  @override
  String get statistics_gas_tankRole_diluent => 'Diluente';

  @override
  String get statistics_gas_tankRole_oxygenSupply => 'Suprimento de O₂';

  @override
  String get statistics_gas_tankRole_pony => 'Pony';

  @override
  String get statistics_gas_tankRole_sidemountLeft => 'Sidemount E';

  @override
  String get statistics_gas_tankRole_sidemountRight => 'Sidemount D';

  @override
  String get statistics_gas_tankRole_stage => 'Stage';

  @override
  String get statistics_geographic_appBar_title => 'Geografico';

  @override
  String get statistics_geographic_countries_empty => 'Nenhum pais visitado';

  @override
  String get statistics_geographic_countries_error =>
      'Falha ao carregar dados de paises';

  @override
  String get statistics_geographic_countries_subtitle => 'Mergulhos por pais';

  @override
  String statistics_geographic_countries_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count paises. Destaque: $topName com $topCount mergulhos';
  }

  @override
  String get statistics_geographic_countries_title => 'Paises Visitados';

  @override
  String get statistics_geographic_regions_empty => 'Nenhuma regiao explorada';

  @override
  String get statistics_geographic_regions_error =>
      'Falha ao carregar dados de regioes';

  @override
  String get statistics_geographic_regions_subtitle => 'Mergulhos por regiao';

  @override
  String statistics_geographic_regions_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count regioes. Destaque: $topName com $topCount mergulhos';
  }

  @override
  String get statistics_geographic_regions_title => 'Regioes Exploradas';

  @override
  String get statistics_geographic_trips_empty => 'Nenhum dado de viagem';

  @override
  String get statistics_geographic_trips_error =>
      'Falha ao carregar dados de viagens';

  @override
  String get statistics_geographic_trips_subtitle => 'Viagens mais produtivas';

  @override
  String statistics_geographic_trips_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count viagens. Destaque: $topName com $topCount mergulhos';
  }

  @override
  String get statistics_geographic_trips_title => 'Mergulhos por Viagem';

  @override
  String get statistics_listContent_selectedSuffix => ', selecionado';

  @override
  String get statistics_marineLife_appBar_title => 'Vida Marinha';

  @override
  String get statistics_marineLife_bestSites_empty => 'Nenhum dado de ponto';

  @override
  String get statistics_marineLife_bestSites_error =>
      'Falha ao carregar dados de pontos';

  @override
  String get statistics_marineLife_bestSites_subtitle =>
      'Pontos com maior variedade de especies';

  @override
  String statistics_marineLife_bestSites_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count pontos. Melhor: $topName com $topCount especies';
  }

  @override
  String get statistics_marineLife_bestSites_title =>
      'Melhores Pontos para Vida Marinha';

  @override
  String get statistics_marineLife_mostCommon_empty =>
      'Nenhum dado de avistamento';

  @override
  String get statistics_marineLife_mostCommon_error =>
      'Falha ao carregar dados de avistamentos';

  @override
  String get statistics_marineLife_mostCommon_subtitle =>
      'Especies avistadas com mais frequencia';

  @override
  String statistics_marineLife_mostCommon_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count especies. Mais comum: $topName com $topCount avistamentos';
  }

  @override
  String get statistics_marineLife_mostCommon_title =>
      'Avistamentos Mais Comuns';

  @override
  String get statistics_marineLife_speciesSpotted => 'Especies Avistadas';

  @override
  String get statistics_profile_appBar_title => 'Analise de Perfil';

  @override
  String get statistics_profile_ascentDescent_empty =>
      'Nenhum dado de perfil disponivel';

  @override
  String get statistics_profile_ascentDescent_error =>
      'Falha ao carregar dados de taxa';

  @override
  String get statistics_profile_ascentDescent_subtitle =>
      'A partir dos dados de perfil de mergulho';

  @override
  String get statistics_profile_ascentDescent_title =>
      'Taxas Medias de Subida e Descida';

  @override
  String get statistics_profile_avgAscent => 'Subida Media';

  @override
  String get statistics_profile_avgDescent => 'Descida Media';

  @override
  String get statistics_profile_deco_decoDives => 'Mergulhos Deco';

  @override
  String get statistics_profile_deco_decoLabel => 'Deco';

  @override
  String get statistics_profile_deco_decoRate => 'Taxa Deco';

  @override
  String get statistics_profile_deco_empty => 'Nenhum dado de deco disponivel';

  @override
  String get statistics_profile_deco_error => 'Falha ao carregar dados de deco';

  @override
  String get statistics_profile_deco_noDeco => 'Sem Deco';

  @override
  String get statistics_profile_deco_notRecorded => 'Não registado';

  @override
  String statistics_profile_deco_notRecordedHint(int count) {
    return '$count mergulhos não têm dados de descompressão registados ou calculáveis e são excluídos da taxa';
  }

  @override
  String statistics_profile_deco_semanticLabel(Object percentage) {
    return 'Taxa de descompressao: $percentage% dos mergulhos exigiram paradas de deco';
  }

  @override
  String get statistics_profile_deco_subtitle =>
      'Mergulhos que exigiram paradas de deco';

  @override
  String get statistics_profile_deco_title => 'Obrigacao de Descompressao';

  @override
  String get statistics_profile_timeAtDepth_empty =>
      'Nenhum dado de profundidade disponivel';

  @override
  String get statistics_profile_timeAtDepth_error =>
      'Falha ao carregar dados de faixa de profundidade';

  @override
  String get statistics_profile_timeAtDepth_subtitle =>
      'Tempo aproximado em cada profundidade';

  @override
  String get statistics_profile_timeAtDepth_title =>
      'Tempo por Faixa de Profundidade';

  @override
  String statistics_profile_timeAtDepth_valueFormat(Object value) {
    return '$value min';
  }

  @override
  String get statistics_progression_appBar_title => 'Progressao de Mergulho';

  @override
  String get statistics_progression_bottomTime_error =>
      'Falha ao carregar tendencia de tempo de fundo';

  @override
  String get statistics_progression_bottomTime_subtitle =>
      'Duracao media por mes';

  @override
  String get statistics_progression_bottomTime_title =>
      'Tendencia de Tempo de Fundo';

  @override
  String get statistics_progression_cumulative_error =>
      'Falha ao carregar dados cumulativos';

  @override
  String get statistics_progression_cumulative_subtitle =>
      'Total de mergulhos ao longo do tempo';

  @override
  String get statistics_progression_cumulative_title =>
      'Contagem Cumulativa de Mergulhos';

  @override
  String get statistics_progression_depthProgression_error =>
      'Falha ao carregar progressao de profundidade';

  @override
  String get statistics_progression_depthProgression_subtitle =>
      'Profundidade maxima mensal ao longo de 5 anos';

  @override
  String get statistics_progression_depthProgression_title =>
      'Progressao de Profundidade Maxima';

  @override
  String get statistics_progression_divesPerYear_empty =>
      'Nenhum dado anual disponivel';

  @override
  String get statistics_progression_divesPerYear_error =>
      'Falha ao carregar dados anuais';

  @override
  String get statistics_progression_divesPerYear_subtitle =>
      'Comparacao anual de mergulhos';

  @override
  String get statistics_progression_divesPerYear_title => 'Mergulhos por Ano';

  @override
  String get statistics_ranking_countLabel_dives => 'mergulhos';

  @override
  String get statistics_ranking_countLabel_sightings => 'avistamentos';

  @override
  String get statistics_ranking_countLabel_species => 'especies';

  @override
  String get statistics_ranking_emptyState => 'Nenhum dado ainda';

  @override
  String statistics_ranking_itemCount(Object count, Object label) {
    return '$count $label';
  }

  @override
  String statistics_ranking_moreItems(Object count) {
    return 'e mais $count';
  }

  @override
  String statistics_ranking_semanticLabel(
    Object name,
    Object rank,
    Object count,
    Object label,
  ) {
    return '$name, posicao $rank, $count $label';
  }

  @override
  String get statistics_records_appBar_title => 'Recordes de Mergulho';

  @override
  String get statistics_records_coldestDive => 'Mergulho Mais Frio';

  @override
  String get statistics_records_deepestDive => 'Mergulho Mais Profundo';

  @override
  String statistics_records_diveNumber(Object number) {
    return 'Mergulho #$number';
  }

  @override
  String get statistics_records_emptySubtitle =>
      'Comece a registrar mergulhos para ver seus recordes aqui';

  @override
  String get statistics_records_emptyTitle => 'Nenhum Recorde Ainda';

  @override
  String get statistics_records_error => 'Erro ao carregar recordes';

  @override
  String get statistics_records_firstDive => 'Primeiro Mergulho';

  @override
  String get statistics_records_longestDive => 'Mergulho Mais Longo';

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
  String get statistics_records_milestones => 'Marcos';

  @override
  String get statistics_records_mostRecentDive => 'Mergulho Mais Recente';

  @override
  String statistics_records_recordSemanticLabel(
    Object title,
    Object value,
    Object siteName,
  ) {
    return '$title: $value em $siteName';
  }

  @override
  String get statistics_records_retry => 'Tentar Novamente';

  @override
  String get statistics_records_shallowestDive => 'Mergulho Mais Raso';

  @override
  String get statistics_records_unknownSite => 'Ponto Desconhecido';

  @override
  String get statistics_records_warmestDive => 'Mergulho Mais Quente';

  @override
  String statistics_sectionCard_semanticLabel(Object title) {
    return 'Secao $title';
  }

  @override
  String get statistics_social_appBar_title => 'Social e Duplas';

  @override
  String get statistics_social_soloVsBuddy_empty =>
      'Nenhum dado de mergulho disponivel';

  @override
  String get statistics_social_soloVsBuddy_error =>
      'Falha ao carregar dados de duplas';

  @override
  String get statistics_social_soloVsBuddy_solo => 'Solo';

  @override
  String get statistics_social_soloVsBuddy_subtitle =>
      'Mergulhando com ou sem companheiros';

  @override
  String get statistics_social_soloVsBuddy_title =>
      'Mergulhos Solo vs com Dupla';

  @override
  String get statistics_social_soloVsBuddy_withBuddy => 'Com Dupla';

  @override
  String get statistics_social_topBuddies_error =>
      'Falha ao carregar ranking de duplas';

  @override
  String get statistics_social_topBuddies_subtitle =>
      'Companheiros de mergulho mais frequentes';

  @override
  String get statistics_social_topBuddies_title =>
      'Melhores Duplas de Mergulho';

  @override
  String get statistics_social_topDiveCenters_error =>
      'Falha ao carregar ranking de centros de mergulho';

  @override
  String get statistics_social_topDiveCenters_subtitle =>
      'Operadoras mais visitadas';

  @override
  String get statistics_social_topDiveCenters_title =>
      'Melhores Centros de Mergulho';

  @override
  String get statistics_summary_avgDepth => 'Prof. Media';

  @override
  String get statistics_summary_avgTemp => 'Temp. Media';

  @override
  String get statistics_summary_depthDistribution_empty =>
      'O grafico aparecera quando voce registrar mergulhos';

  @override
  String get statistics_summary_depthDistribution_semanticLabel =>
      'Grafico de pizza mostrando distribuicao de profundidade';

  @override
  String get statistics_summary_depthDistribution_title =>
      'Distribuicao de Profundidade';

  @override
  String get statistics_summary_diveTypes_empty =>
      'O grafico aparecera quando voce registrar mergulhos';

  @override
  String statistics_summary_diveTypes_moreTypes(Object count) {
    return 'e mais $count tipos';
  }

  @override
  String get statistics_summary_diveTypes_semanticLabel =>
      'Grafico de pizza mostrando distribuicao de tipos de mergulho';

  @override
  String get statistics_summary_diveTypes_title => 'Tipos de Mergulho';

  @override
  String get statistics_summary_divesByMonth_empty =>
      'O grafico aparecera quando voce registrar mergulhos';

  @override
  String get statistics_summary_divesByMonth_semanticLabel =>
      'Grafico de barras mostrando mergulhos por mes';

  @override
  String get statistics_summary_divesByMonth_title => 'Mergulhos por Mes';

  @override
  String statistics_summary_divesByMonth_tooltip(
    Object fullLabel,
    Object count,
  ) {
    return '$fullLabel\n$count mergulhos';
  }

  @override
  String get statistics_summary_header_subtitle =>
      'Selecione uma categoria para explorar estatisticas detalhadas';

  @override
  String get statistics_summary_header_title => 'Visao Geral das Estatisticas';

  @override
  String get statistics_summary_maxDepth => 'Prof. Maxima';

  @override
  String get statistics_summary_sitesVisited => 'Pontos Visitados';

  @override
  String statistics_summary_tagUsage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos',
      one: '1 mergulho',
    );
    return '$_temp0';
  }

  @override
  String get statistics_summary_tagUsage_empty => 'Nenhuma tag criada ainda';

  @override
  String get statistics_summary_tagUsage_emptyHint =>
      'Adicione tags aos mergulhos para ver estatisticas';

  @override
  String statistics_summary_tagUsage_moreTags(Object count) {
    return 'e mais $count tags';
  }

  @override
  String statistics_summary_tagUsage_tagCount(Object count) {
    return '$count tags';
  }

  @override
  String get statistics_summary_tagUsage_title => 'Uso de Tags';

  @override
  String statistics_summary_topDiveSites_diveCount(Object count) {
    return '$count mergulhos';
  }

  @override
  String get statistics_summary_topDiveSites_empty =>
      'Nenhum ponto de mergulho ainda';

  @override
  String get statistics_summary_topDiveSites_title =>
      'Melhores Pontos de Mergulho';

  @override
  String statistics_summary_topDiveSites_totalCount(Object count) {
    return '$count no total';
  }

  @override
  String get statistics_summary_totalDives => 'Total de Mergulhos';

  @override
  String get statistics_summary_totalTime => 'Tempo Total';

  @override
  String get statistics_timePatterns_appBar_title => 'Padroes de Horario';

  @override
  String get statistics_timePatterns_dayOfWeek_empty =>
      'Nenhum dado disponivel';

  @override
  String get statistics_timePatterns_dayOfWeek_error =>
      'Falha ao carregar dados por dia da semana';

  @override
  String get statistics_timePatterns_dayOfWeek_fri => 'Sex';

  @override
  String get statistics_timePatterns_dayOfWeek_mon => 'Seg';

  @override
  String get statistics_timePatterns_dayOfWeek_sat => 'Sab';

  @override
  String get statistics_timePatterns_dayOfWeek_subtitle =>
      'Quando voce mais mergulha?';

  @override
  String get statistics_timePatterns_dayOfWeek_sun => 'Dom';

  @override
  String get statistics_timePatterns_dayOfWeek_thu => 'Qui';

  @override
  String get statistics_timePatterns_dayOfWeek_title =>
      'Mergulhos por Dia da Semana';

  @override
  String get statistics_timePatterns_dayOfWeek_tue => 'Ter';

  @override
  String get statistics_timePatterns_dayOfWeek_wed => 'Qua';

  @override
  String get statistics_timePatterns_month_apr => 'Abr';

  @override
  String get statistics_timePatterns_month_aug => 'Ago';

  @override
  String get statistics_timePatterns_month_dec => 'Dez';

  @override
  String get statistics_timePatterns_month_feb => 'Fev';

  @override
  String get statistics_timePatterns_month_jan => 'Jan';

  @override
  String get statistics_timePatterns_month_jul => 'Jul';

  @override
  String get statistics_timePatterns_month_jun => 'Jun';

  @override
  String get statistics_timePatterns_month_mar => 'Mar';

  @override
  String get statistics_timePatterns_month_may => 'Mai';

  @override
  String get statistics_timePatterns_month_nov => 'Nov';

  @override
  String get statistics_timePatterns_month_oct => 'Out';

  @override
  String get statistics_timePatterns_month_sep => 'Set';

  @override
  String get statistics_timePatterns_seasonal_empty => 'Nenhum dado disponivel';

  @override
  String get statistics_timePatterns_seasonal_error =>
      'Falha ao carregar dados sazonais';

  @override
  String get statistics_timePatterns_seasonal_subtitle =>
      'Mergulhos por mes (todos os anos)';

  @override
  String get statistics_timePatterns_seasonal_title => 'Padroes Sazonais';

  @override
  String get statistics_timePatterns_surfaceInterval_average => 'Media';

  @override
  String get statistics_timePatterns_surfaceInterval_empty =>
      'Nenhum dado de intervalo de superficie disponivel';

  @override
  String get statistics_timePatterns_surfaceInterval_error =>
      'Falha ao carregar dados de intervalo de superficie';

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
      'Tempo entre mergulhos';

  @override
  String get statistics_timePatterns_surfaceInterval_title =>
      'Estatisticas de Intervalo de Superficie';

  @override
  String get statistics_timePatterns_timeOfDay_error =>
      'Falha ao carregar dados por horario do dia';

  @override
  String get statistics_timePatterns_timeOfDay_subtitle =>
      'Manha, tarde, entardecer ou noite';

  @override
  String get statistics_timePatterns_timeOfDay_title =>
      'Mergulhos por Horario do Dia';

  @override
  String get statistics_tooltip_diveRecords => 'Recordes de Mergulho';

  @override
  String get statistics_tooltip_filter => 'Filtrar estatísticas';

  @override
  String get statistics_tooltip_refreshRecords => 'Atualizar recordes';

  @override
  String get statistics_tooltip_refreshStatistics => 'Atualizar estatisticas';

  @override
  String statistics_valueCard_semanticLabel(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String get surfaceInterval_aboutTissueLoading_body =>
      'Seu corpo possui 16 compartimentos de tecido que absorvem e liberam nitrogênio em taxas diferentes. Tecidos rápidos (como sangue) saturam rapidamente, mas também liberam gás rapidamente. Tecidos lentos (como osso e gordura) levam mais tempo para carregar e descarregar. O \"compartimento líder\" é aquele tecido que está mais saturado e normalmente controla seu limite de não descompressão (NDL). Durante um intervalo de superfície, todos os tecidos liberam gás em direção aos níveis de saturação de superfície (~40% de carregamento).';

  @override
  String get surfaceInterval_aboutTissueLoading_title =>
      'Sobre Carregamento de Tecidos';

  @override
  String get surfaceInterval_action_resetDefaults => 'Restaurar padrões';

  @override
  String get surfaceInterval_disclaimer =>
      'Esta ferramenta é apenas para fins de planejamento. Sempre use um computador de mergulho e siga seu treinamento. Os resultados são baseados no algoritmo Buhlmann ZH-L16C e podem diferir do seu computador.';

  @override
  String get surfaceInterval_field_depth => 'Profundidade';

  @override
  String get surfaceInterval_field_gasMix => 'Mistura de Gás: ';

  @override
  String get surfaceInterval_field_he => 'He';

  @override
  String get surfaceInterval_field_o2 => 'O₂';

  @override
  String get surfaceInterval_field_time => 'Tempo';

  @override
  String surfaceInterval_firstDive_depthSemantics(Object depth, Object unit) {
    return 'Profundidade do primeiro mergulho: $depth $unit';
  }

  @override
  String surfaceInterval_firstDive_timeSemantics(Object time) {
    return 'Tempo do primeiro mergulho: $time minutos';
  }

  @override
  String get surfaceInterval_firstDive_title => 'Primeiro Mergulho';

  @override
  String surfaceInterval_format_hours(Object count) {
    return '$count horas';
  }

  @override
  String surfaceInterval_format_minutes(Object count) {
    return '$count min';
  }

  @override
  String get surfaceInterval_gasMix_air => 'Ar';

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
    return 'ppO₂ $ppO2 a $depth excede $limit. A MOD desta mistura é $mod.';
  }

  @override
  String surfaceInterval_heSemantics(Object percent) {
    return 'Hélio: $percent%';
  }

  @override
  String surfaceInterval_o2Semantics(Object percent) {
    return 'O2: $percent%';
  }

  @override
  String surfaceInterval_result_beyondHorizon(Object hours) {
    return 'A espera ultrapassa as $hours horas que este planeador procura. A desaturação continua, por isso um intervalo de superfície mais longo será suficiente.';
  }

  @override
  String surfaceInterval_result_beyondHorizonShort(Object hours) {
    return 'Mais de $hours horas';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Intervalo Atual';

  @override
  String get surfaceInterval_result_gasUnsafe =>
      'Gás inseguro nesta profundidade';

  @override
  String get surfaceInterval_result_inDeco => 'Em deco';

  @override
  String get surfaceInterval_result_increaseInterval =>
      'Aumente o intervalo de superfície ou reduza a profundidade/tempo do segundo mergulho';

  @override
  String get surfaceInterval_result_minimumInterval =>
      'Intervalo de Superfície Mínimo';

  @override
  String get surfaceInterval_result_ndlForSecondDive => 'NDL para 2º Mergulho';

  @override
  String surfaceInterval_result_ndlMinutes(Object minutes) {
    return '$minutes min NDL';
  }

  @override
  String surfaceInterval_result_noIntervalHelps(Object minutes) {
    return 'Nenhum intervalo de superfície é suficiente. O mergulho sem descompressão mais longo a esta profundidade com esta mistura é de $minutes min. Encurte o segundo mergulho ou reduza a sua profundidade.';
  }

  @override
  String get surfaceInterval_result_notAchievable =>
      'Não alcançável com nenhum intervalo de superfície';

  @override
  String get surfaceInterval_result_notYetSafe =>
      'Ainda não é seguro, aumente o intervalo de superfície';

  @override
  String get surfaceInterval_result_safeToDive => 'Seguro para mergulhar';

  @override
  String surfaceInterval_result_semantics(
    Object interval,
    Object current,
    Object ndl,
    Object status,
  ) {
    return 'Intervalo de superfície mínimo: $interval. Intervalo atual: $current. NDL para segundo mergulho: $ndl. $status';
  }

  @override
  String surfaceInterval_secondDive_depthSemantics(Object depth, Object unit) {
    return 'Profundidade do segundo mergulho: $depth $unit';
  }

  @override
  String surfaceInterval_secondDive_heSemantics(Object percent) {
    return 'Hélio do segundo mergulho: $percent%';
  }

  @override
  String surfaceInterval_secondDive_o2Semantics(Object percent) {
    return 'O2 do segundo mergulho: $percent%';
  }

  @override
  String surfaceInterval_secondDive_timeSemantics(Object time) {
    return 'Tempo do segundo mergulho: $time minutos';
  }

  @override
  String get surfaceInterval_secondDive_title => 'Segundo Mergulho';

  @override
  String surfaceInterval_tissueRecovery_chartSemantics(Object interval) {
    return 'Gráfico de recuperação de tecidos mostrando a liberação de gás de 16 compartimentos durante um intervalo de superfície de $interval';
  }

  @override
  String get surfaceInterval_tissueRecovery_compartmentsLabel =>
      'Compartimentos (por velocidade de meia-vida)';

  @override
  String get surfaceInterval_tissueRecovery_description =>
      'Mostrando como cada um dos 16 compartimentos de tecido liberam gás durante o intervalo de superfície';

  @override
  String get surfaceInterval_tissueRecovery_fast => 'Rápido (C1-5)';

  @override
  String surfaceInterval_tissueRecovery_leadingCompartment(Object number) {
    return 'Compartimento líder: C$number';
  }

  @override
  String get surfaceInterval_tissueRecovery_loadingPercent => 'Carregamento %';

  @override
  String get surfaceInterval_tissueRecovery_medium => 'Médio (C6-10)';

  @override
  String get surfaceInterval_tissueRecovery_min => 'Mín';

  @override
  String get surfaceInterval_tissueRecovery_now => 'Agora';

  @override
  String get surfaceInterval_tissueRecovery_slow => 'Lento (C11-16)';

  @override
  String get surfaceInterval_tissueRecovery_title => 'Recuperação de Tecidos';

  @override
  String get surfaceInterval_title => 'Intervalo de Superfície';

  @override
  String tags_action_createNamed(Object tagName) {
    return 'Criar \"$tagName\"';
  }

  @override
  String get tags_action_createTag => 'Criar tag';

  @override
  String get tags_action_browse => 'Explorar';

  @override
  String get tags_picker_title => 'Escolher etiquetas';

  @override
  String get tags_picker_empty =>
      'Ainda não há etiquetas. Escreva um nome para criar a primeira.';

  @override
  String tags_picker_errorLoading(String error) {
    return 'Erro ao carregar as etiquetas: $error';
  }

  @override
  String get tags_picker_allAdded => 'Todas as etiquetas já foram adicionadas.';

  @override
  String get tags_picker_noMatches =>
      'Nenhuma etiqueta corresponde à sua pesquisa.';

  @override
  String tags_picker_addCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Adicionar $count etiquetas',
      one: 'Adicionar 1 etiqueta',
      zero: 'Adicionar etiquetas',
    );
    return '$_temp0';
  }

  @override
  String get tags_action_deleteTag => 'Excluir tag';

  @override
  String tags_dialog_deleteMessage(Object tagName) {
    return 'Tem certeza de que deseja excluir \"$tagName\"? Isso irá removê-la de todos os mergulhos.';
  }

  @override
  String get tags_dialog_deleteTitle => 'Excluir Tag?';

  @override
  String get tags_empty => 'Nenhuma tag ainda. Crie tags ao editar mergulhos.';

  @override
  String get tags_hint_addMoreTags => 'Adicionar mais tags...';

  @override
  String get importWizard_tagsLabel => 'Tags';

  @override
  String get importWizard_photos_stepLabel => 'Fotos';

  @override
  String importWizard_photos_foundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos referenciadas neste diário',
      one: '1 foto referenciada neste diário',
    );
    return '$_temp0';
  }

  @override
  String get importWizard_photos_chooseFolder => 'Escolher pasta de fotos...';

  @override
  String get importWizard_photos_scanning => 'A analisar a pasta...';

  @override
  String importWizard_photos_matchSummary(
    int matched,
    int byName,
    int missing,
  ) {
    return '$matched correspondidas, $byName apenas pelo nome do ficheiro, $missing não encontradas';
  }

  @override
  String get importWizard_photos_skip => 'Ignorar fotos';

  @override
  String get importWizard_photos_mobileUnsupported =>
      'Importar fotos requer uma pasta no disco deste dispositivo. Execute esta importação num computador para as incluir. Os mergulhos e locais são importados normalmente.';

  @override
  String importWizard_review_olderDivesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count mergulhos mais antigos ignorados — já estão no seu registo',
      one: '1 mergulho mais antigo ignorado — já está no seu registo',
    );
    return '$_temp0';
  }

  @override
  String get tags_hint_addTags => 'Adicionar tags...';

  @override
  String get tags_manage_title => 'Etiquetas';

  @override
  String get tags_manage_searchHint => 'Buscar etiquetas...';

  @override
  String tags_manage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos',
      one: '1 mergulho',
      zero: '0 mergulhos',
    );
    return '$_temp0';
  }

  @override
  String get tags_manage_emptyState =>
      'Nenhuma etiqueta ainda. Crie uma para comecar.';

  @override
  String tags_manage_selectedCount(int count) {
    return '$count selecionadas';
  }

  @override
  String get tags_manage_createTitle => 'Criar Etiqueta';

  @override
  String get tags_manage_editTitle => 'Editar Etiqueta';

  @override
  String get tags_manage_nameLabel => 'Nome da Etiqueta';

  @override
  String get tags_manage_colorLabel => 'Cor';

  @override
  String get tags_manage_nameRequired => 'O nome da etiqueta e obrigatorio';

  @override
  String get tags_manage_deleteTitle => 'Excluir Etiqueta?';

  @override
  String tags_manage_deleteMessage(String tagName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos',
      one: '1 mergulho',
      zero: '0 mergulhos',
    );
    return '\"$tagName\" sera removida de $_temp0. Esta acao nao pode ser desfeita.';
  }

  @override
  String tags_manage_bulkDeleteTitle(int count) {
    return 'Excluir $count Etiquetas?';
  }

  @override
  String tags_manage_bulkDeleteMessage(int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount mergulhos',
      one: '1 mergulho',
      zero: '0 mergulhos',
    );
    return 'Estas etiquetas serao removidas de $_temp0 no total. Esta acao nao pode ser desfeita.';
  }

  @override
  String tags_manage_mergeTitle(int count) {
    return 'Mesclar $count Etiquetas';
  }

  @override
  String get tags_manage_mergeResultName => 'Nome resultante da etiqueta:';

  @override
  String get tags_manage_mergeKeepFrom => 'Ou manter nome de:';

  @override
  String tags_manage_mergeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos',
      one: '1 mergulho',
      zero: '0 mergulhos',
    );
    return 'Isso afetara $_temp0 no total.';
  }

  @override
  String get tags_manage_mergeAction => 'Mesclar';

  @override
  String get tags_title_manageTags => 'Gerenciar Tags';

  @override
  String get tank_al30Stage_description =>
      'Cilindro stage de aluminio 30 cu ft';

  @override
  String get tank_al30Stage_displayName => 'AL30 Stage';

  @override
  String get tank_al40Stage_description =>
      'Cilindro stage de aluminio 40 cu ft';

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
  String get tank_al80_description => 'Aluminio 80 cu ft (mais comum)';

  @override
  String get tank_al80_displayName => 'AL80';

  @override
  String get tank_hp100_description => 'Aco Alta Pressao 100 cu ft';

  @override
  String get tank_hp100_displayName => 'HP100';

  @override
  String get tank_hp120_description => 'Aco Alta Pressao 120 cu ft';

  @override
  String get tank_hp120_displayName => 'HP120';

  @override
  String get tank_hp80_description => 'Aco Alta Pressao 80 cu ft';

  @override
  String get tank_hp80_displayName => 'HP80';

  @override
  String get tank_lp85_description => 'Aco Baixa Pressao 85 cu ft';

  @override
  String get tank_lp85_displayName => 'LP85';

  @override
  String get tank_steel10_description => 'Aco 10 litros (Europa)';

  @override
  String get tank_steel10_displayName => 'Aco 10L';

  @override
  String get tank_steel12_description => 'Aco 12 litros (Europa)';

  @override
  String get tank_steel12_displayName => 'Aco 12L';

  @override
  String get tank_steel15_description => 'Aco 15 litros (Europa)';

  @override
  String get tank_steel15_displayName => 'Aco 15L';

  @override
  String get tides_action_refresh => 'Atualizar dados de maré';

  @override
  String get tides_chart_24hourForecast => 'Previsão de 24 Horas';

  @override
  String tides_chart_heightAxis(Object depthSymbol) {
    return 'Altura ($depthSymbol)';
  }

  @override
  String get tides_chart_msl => 'NMM';

  @override
  String tides_chart_nowLabel(Object nowHeightStr, Object nowTimeStr) {
    return ' Agora $nowTimeStr $nowHeightStr';
  }

  @override
  String get tides_error_unableToLoad =>
      'Não foi possível carregar os dados de maré';

  @override
  String get tides_error_unableToLoadChart =>
      'Não foi possível carregar o gráfico';

  @override
  String tides_label_ago(Object duration) {
    return '$duration atrás';
  }

  @override
  String tides_label_currentHeight(Object height, Object depthSymbol) {
    return 'Atual: $height$depthSymbol';
  }

  @override
  String tides_label_fromNow(Object duration) {
    return 'em $duration';
  }

  @override
  String get tides_label_high => 'Alta';

  @override
  String get tides_label_highIn => 'Alta em';

  @override
  String get tides_label_highTide => 'Maré Alta';

  @override
  String get tides_label_low => 'Baixa';

  @override
  String get tides_label_lowIn => 'Baixa em';

  @override
  String get tides_label_lowTide => 'Maré Baixa';

  @override
  String tides_label_tideIn(Object duration) {
    return 'em $duration';
  }

  @override
  String get tides_label_tideTimes => 'Horários das Marés';

  @override
  String get tides_label_today => 'Hoje';

  @override
  String get tides_label_tomorrow => 'Amanhã';

  @override
  String get tides_label_upcomingTides => 'Próximas Marés';

  @override
  String get tides_legend_highTide => 'Maré Alta';

  @override
  String get tides_legend_lowTide => 'Maré Baixa';

  @override
  String get tides_legend_now => 'Agora';

  @override
  String get tides_legend_tideLevel => 'Nível da Maré';

  @override
  String get tides_noDataAvailable => 'Nenhum dado de maré disponível';

  @override
  String get tides_noDataForLocation =>
      'Dados de maré não disponíveis para este local';

  @override
  String get tides_noExtremesData => 'Sem dados de extremos';

  @override
  String get tides_noTideTimesAvailable => 'Nenhum horário de maré disponível';

  @override
  String tides_semantic_currentTide(
    Object tideState,
    Object height,
    Object depthSymbol,
    Object nextExtreme,
  ) {
    return 'Maré $tideState, $height$depthSymbol$nextExtreme';
  }

  @override
  String tides_semantic_extremeItem(
    Object typeLabel,
    Object time,
    Object height,
    Object depthSymbol,
  ) {
    return 'Maré $typeLabel às $time, $height$depthSymbol';
  }

  @override
  String tides_semantic_tideChart(Object extremesSummary) {
    return 'Gráfico de marés. $extremesSummary';
  }

  @override
  String tides_semantic_tideState(Object state) {
    return 'Estado da maré: $state';
  }

  @override
  String tides_source_noaaStation(String name, String distance) {
    return 'Estação NOAA: $name ($distance)';
  }

  @override
  String get tides_source_modelEstimate => 'Estimativa de modelo oceânico';

  @override
  String get tides_source_modelCaveat =>
      'Modelado a partir de dados de satélite. Horários e alturas podem diferir perto de costas complexas.';

  @override
  String get tides_source_sheetTitle => 'Fonte dos dados de maré';

  @override
  String get tides_source_datumMllw =>
      'Alturas relativas ao MLLW (datum da estação)';

  @override
  String get tides_source_datumMsl => 'Alturas relativas ao nível médio do mar';

  @override
  String get tides_title => 'Marés';

  @override
  String get transfer_appBar_title => 'Transferencia';

  @override
  String get transfer_computers_aboutContent =>
      'Conecte seu computador de mergulho via Bluetooth para baixar registros de mergulho diretamente no aplicativo. Computadores compativeis incluem Suunto, Shearwater, Garmin, Mares e muitas outras marcas populares.\n\nUsuarios do Apple Watch Ultra podem importar dados de mergulho diretamente do app Saude, incluindo profundidade, duracao e frequencia cardiaca.';

  @override
  String get transfer_computers_aboutTitle => 'Sobre Computadores de Mergulho';

  @override
  String get transfer_computers_appleWatchHeader => 'Apple Watch';

  @override
  String get transfer_computers_appleWatchSubtitle =>
      'Import dives via Apple HealthKit';

  @override
  String get transfer_computers_appleWatchTitle => 'Importar do Apple Watch';

  @override
  String get transfer_computers_connectSubtitle =>
      'Descobrir e parear um computador de mergulho';

  @override
  String get transfer_computers_connectTitle => 'Conectar Novo Computador';

  @override
  String get transfer_computers_errorLoading => 'Erro ao carregar computadores';

  @override
  String get transfer_computers_loading => 'Carregando...';

  @override
  String get transfer_computers_manageTitle => 'Gerenciar Computadores';

  @override
  String get transfer_computers_noComputersSaved => 'Nenhum computador salvo';

  @override
  String transfer_computers_diveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos',
      one: '1 mergulho',
    );
    return '$_temp0';
  }

  @override
  String get transfer_computers_downloadTooltip => 'Baixar mergulhos';

  @override
  String get transfer_computers_knownComputersHeader =>
      'Computadores conhecidos';

  @override
  String transfer_computers_lastDownloadDaysAgo(int days) {
    return 'há $days dias';
  }

  @override
  String transfer_computers_lastDownloadHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'há $hours horas',
      one: 'há 1 hora',
    );
    return '$_temp0';
  }

  @override
  String transfer_computers_lastDownloadMinutesAgo(int minutes) {
    return 'há $minutes min';
  }

  @override
  String get transfer_computers_lastDownloadNever => 'Nunca';

  @override
  String get transfer_computers_lastDownloadYesterday => 'Ontem';

  @override
  String transfer_computers_savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'computadores salvos',
      one: 'computador salvo',
    );
    return '$count $_temp0';
  }

  @override
  String get transfer_computers_sectionHeader => 'Computadores de Mergulho';

  @override
  String get transfer_csvExport_cancelButton => 'Cancelar';

  @override
  String get transfer_csvExport_dataTypeHeader => 'Tipo de Dados';

  @override
  String get transfer_csvExport_descriptionDives =>
      'Exportar todos os registros de mergulho como planilha';

  @override
  String get transfer_csvExport_descriptionEquipment =>
      'Exportar inventario de equipamentos e informacoes de manutencao';

  @override
  String get transfer_csvExport_descriptionSites =>
      'Exportar localizacoes e detalhes dos pontos de mergulho';

  @override
  String get transfer_csvExport_dialogTitle => 'Exportar CSV';

  @override
  String get transfer_csvExport_exportButton => 'Exportar CSV';

  @override
  String get transfer_csvExport_optionDivesTitle => 'CSV de Mergulhos';

  @override
  String get transfer_csvExport_optionEquipmentTitle => 'CSV de Equipamentos';

  @override
  String get transfer_csvExport_optionSitesTitle => 'CSV de Pontos';

  @override
  String transfer_csvExport_semanticLabel(Object typeName) {
    return 'Exportar $typeName';
  }

  @override
  String get transfer_csvExport_typeDives => 'Mergulhos';

  @override
  String get transfer_csvExport_typeEquipment => 'Equipamentos';

  @override
  String get transfer_csvExport_typeSites => 'Pontos';

  @override
  String get transfer_detail_backTooltip => 'Voltar para transferencia';

  @override
  String get transfer_export_aboutContent =>
      'Exporte seus dados de mergulho em varios formatos. PDF cria um logbook imprimivel. UDDF e um formato universal compativel com a maioria dos softwares de registro de mergulho. Arquivos CSV podem ser abertos em aplicativos de planilha.';

  @override
  String get transfer_export_backupLink => 'Ir para Backup e restauração';

  @override
  String get transfer_export_aboutTitle => 'Sobre Exportacao';

  @override
  String get transfer_export_completed => 'Exportacao concluida';

  @override
  String get transfer_export_csvSubtitle => 'Formato de planilha';

  @override
  String get transfer_export_csvTitle => 'Exportacao CSV';

  @override
  String get transfer_export_excelSubtitle =>
      'Todos os dados em um arquivo (mergulhos, pontos, equipamentos, estatisticas)';

  @override
  String get transfer_export_excelTitle => 'Planilha Excel';

  @override
  String transfer_export_failed(Object error) {
    return 'Falha na exportacao: $error';
  }

  @override
  String get transfer_export_kmlSubtitle =>
      'Visualizar pontos de mergulho em um globo 3D';

  @override
  String get transfer_export_kmlTitle => 'Google Earth KML';

  @override
  String get transfer_export_multiFormatHeader => 'Exportacao Multi-Formato';

  @override
  String get transfer_export_optionSaveSubtitle =>
      'Escolha onde salvar no seu dispositivo';

  @override
  String get transfer_export_optionSaveTitle => 'Salvar em Arquivo';

  @override
  String get transfer_export_optionShareSubtitle =>
      'Enviar por e-mail, mensagens ou outros aplicativos';

  @override
  String get transfer_export_optionShareTitle => 'Compartilhar';

  @override
  String get transfer_export_pdfSubtitle => 'Logbook de mergulho imprimivel';

  @override
  String get transfer_export_pdfTitle => 'Logbook PDF';

  @override
  String get transfer_export_progressExporting => 'Exportando...';

  @override
  String get transfer_export_sectionHeader => 'Exportar Dados';

  @override
  String get transfer_export_uddfSubtitle => 'Universal Dive Data Format';

  @override
  String get transfer_export_uddfTitle => 'Exportacao UDDF';

  @override
  String get transfer_import_aboutContent =>
      'Use \"Importar Dados\" para a melhor experiencia -- ele detecta automaticamente o formato do arquivo e o aplicativo de origem. As opcoes de formato individual abaixo tambem estao disponiveis para acesso direto.';

  @override
  String get transfer_import_aboutTitle => 'Sobre Importacao';

  @override
  String get transfer_import_fileImportSemanticLabel =>
      'Importar dados com deteccao automatica';

  @override
  String get transfer_import_fileImportSubtitle =>
      'Detecta automaticamente CSV, UDDF, FIT e mais';

  @override
  String get transfer_import_fileImportTitle => 'Importar Dados';

  @override
  String get transfer_import_sectionHeader => 'Importar Dados';

  @override
  String get transfer_pdfExport_cancelButton => 'Cancelar';

  @override
  String get transfer_pdfExport_dialogTitle => 'Exportar Logbook PDF';

  @override
  String get transfer_pdfExport_exportButton => 'Exportar PDF';

  @override
  String get transfer_pdfExport_includeCertCards =>
      'Incluir Cartoes de Certificacao';

  @override
  String get transfer_pdfExport_includeCertCardsSubtitle =>
      'Adicionar imagens de cartoes de certificacao escaneados ao PDF';

  @override
  String get transfer_pdfExport_pageSizeA4 => 'A4';

  @override
  String get transfer_pdfExport_pageSizeA4Desc => '210 x 297 mm';

  @override
  String get transfer_pdfExport_pageSizeHeader => 'Tamanho da Pagina';

  @override
  String get transfer_pdfExport_pageSizeLetter => 'Carta';

  @override
  String get transfer_pdfExport_pageSizeLetterDesc => '8.5 x 11 in';

  @override
  String get transfer_pdfExport_templateDetailed => 'Detalhado';

  @override
  String get transfer_pdfExport_templateDetailedDesc =>
      'Informacoes completas do mergulho com notas e avaliacoes';

  @override
  String get transfer_pdfExport_templateHeader => 'Modelo';

  @override
  String get transfer_pdfExport_templateNauiStyle => 'Estilo NAUI';

  @override
  String get transfer_pdfExport_templateNauiStyleDesc =>
      'Layout correspondente ao formato do logbook NAUI';

  @override
  String get transfer_pdfExport_templatePadiStyle => 'Estilo PADI';

  @override
  String get transfer_pdfExport_templatePadiStyleDesc =>
      'Layout correspondente ao formato do logbook PADI';

  @override
  String get transfer_pdfExport_templateProfessional => 'Profissional';

  @override
  String get transfer_pdfExport_templateProfessionalDesc =>
      'Areas de assinatura e carimbo para verificacao';

  @override
  String transfer_pdfExport_templateSemanticLabel(Object templateName) {
    return 'Selecionar modelo $templateName';
  }

  @override
  String get transfer_pdfExport_templateSimple => 'Simples';

  @override
  String get transfer_pdfExport_templateSimpleDesc =>
      'Formato de tabela compacto, muitos mergulhos por pagina';

  @override
  String get transfer_section_computersSubtitle => 'Baixar do dispositivo';

  @override
  String get transfer_section_computersTitle => 'Computadores de Mergulho';

  @override
  String get transfer_section_exportSubtitle => 'CSV, UDDF, logbook PDF';

  @override
  String get transfer_section_exportTitle => 'Exportar';

  @override
  String get transfer_section_importSubtitle => 'Arquivos CSV, UDDF';

  @override
  String get transfer_section_importTitle => 'Importar';

  @override
  String get transfer_summary_description =>
      'Importar e exportar dados de mergulho';

  @override
  String get transfer_summary_selectSection => 'Selecione uma secao da lista';

  @override
  String get transfer_summary_title => 'Transferencia';

  @override
  String transfer_unknownSection(Object sectionId) {
    return 'Secao desconhecida: $sectionId';
  }

  @override
  String get trips_appBar_title => 'Viagens';

  @override
  String get trips_appBar_tripPhotos => 'Fotos da Viagem';

  @override
  String get trips_detail_action_delete => 'Excluir';

  @override
  String get trips_detail_action_export => 'Exportar';

  @override
  String get trips_detail_appBar_title => 'Viagem';

  @override
  String get trips_detail_dialog_cancel => 'Cancelar';

  @override
  String get trips_detail_dialog_deleteConfirm => 'Excluir';

  @override
  String trips_detail_dialog_deleteContent(Object name) {
    return 'Tem certeza de que deseja excluir \"$name\"? Isso removera a viagem, mas mantera os mergulhos.';
  }

  @override
  String get trips_detail_dialog_deleteTitle => 'Excluir Viagem?';

  @override
  String get trips_detail_dives_empty => 'Nenhum mergulho nesta viagem ainda';

  @override
  String get trips_detail_dives_errorLoading =>
      'Nao foi possivel carregar os mergulhos';

  @override
  String get trips_detail_dives_unknownSite => 'Ponto Desconhecido';

  @override
  String trips_detail_dives_viewAll(Object count) {
    return 'Ver Todos ($count)';
  }

  @override
  String trips_detail_durationDays(Object days) {
    return '$days dias';
  }

  @override
  String get trips_detail_export_csv_comingSoon => 'Exportacao CSV em breve';

  @override
  String get trips_detail_export_csv_subtitle =>
      'Todos os mergulhos desta viagem';

  @override
  String get trips_detail_export_csv_title => 'Exportar para CSV';

  @override
  String get trips_detail_export_pdf_comingSoon => 'Exportacao PDF em breve';

  @override
  String get trips_detail_export_pdf_subtitle =>
      'Resumo da viagem com detalhes dos mergulhos';

  @override
  String get trips_detail_export_pdf_title => 'Exportar para PDF';

  @override
  String get trips_detail_label_liveaboard => 'Liveaboard';

  @override
  String get trips_detail_label_location => 'Localizacao';

  @override
  String get trips_detail_label_resort => 'Resort';

  @override
  String get trips_detail_scan_accessDenied =>
      'Acesso a biblioteca de fotos negado';

  @override
  String get trips_detail_scan_addDivesFirst =>
      'Adicione mergulhos primeiro para vincular fotos';

  @override
  String trips_detail_scan_errorLinking(Object error) {
    return 'Erro ao vincular fotos: $error';
  }

  @override
  String trips_detail_scan_errorScanning(Object error) {
    return 'Erro ao escanear: $error';
  }

  @override
  String trips_detail_scan_linkedPhotos(Object count) {
    return '$count fotos vinculadas';
  }

  @override
  String get trips_detail_scan_linkingPhotos => 'Vinculando fotos...';

  @override
  String get trips_detail_sectionTitle_details => 'Detalhes da Viagem';

  @override
  String get trips_detail_sectionTitle_dives => 'Mergulhos';

  @override
  String get trips_detail_sectionTitle_notes => 'Notas';

  @override
  String get trips_detail_sectionTitle_statistics => 'Estatisticas da Viagem';

  @override
  String get trips_detail_snackBar_deleted => 'Viagem excluida';

  @override
  String get trips_detail_stat_avgDepth => 'Prof. Media';

  @override
  String get trips_detail_stat_maxDepth => 'Prof. Maxima';

  @override
  String get trips_detail_stat_totalRuntime => 'Tempo Total';

  @override
  String get trips_detail_stat_totalDives => 'Total de Mergulhos';

  @override
  String get trips_detail_tab_checklist => 'Lista de Verificação';

  @override
  String get trips_detail_tooltip_edit => 'Editar viagem';

  @override
  String get trips_detail_tooltip_editShort => 'Editar';

  @override
  String get trips_detail_tooltip_moreOptions => 'Mais opcoes';

  @override
  String get trips_detail_tooltip_viewOnMap => 'Ver no Mapa';

  @override
  String trips_diveScan_addButton(int count) {
    return 'Adicionar $count mergulhos';
  }

  @override
  String trips_diveScan_added(int count) {
    return '$count mergulhos adicionados a viagem';
  }

  @override
  String get trips_diveScan_cancel => 'Cancelar';

  @override
  String trips_diveScan_currentTrip(String tripName) {
    return 'Atualmente em: $tripName';
  }

  @override
  String get trips_diveScan_deselectAll => 'Desmarcar tudo';

  @override
  String trips_diveScan_error(String error) {
    return 'Erro ao procurar mergulhos: $error';
  }

  @override
  String get trips_diveScan_findButton => 'Encontrar mergulhos correspondentes';

  @override
  String trips_diveScan_groupOtherTrips(int count) {
    return 'Em outras viagens ($count)';
  }

  @override
  String trips_diveScan_groupUnassigned(int count) {
    return 'Nao atribuidos ($count)';
  }

  @override
  String get trips_diveScan_noMatches =>
      'Nenhum mergulho correspondente encontrado';

  @override
  String get trips_diveScan_noDiver =>
      'Selecione um mergulhador ativo para procurar mergulhos';

  @override
  String get trips_diveScan_selectAll => 'Selecionar tudo';

  @override
  String trips_diveScan_subtitle(int count) {
    return '$count mergulhos encontrados no intervalo de datas';
  }

  @override
  String get trips_diveScan_title => 'Adicionar mergulhos a viagem';

  @override
  String get trips_diveScan_unknownSite => 'Local desconhecido';

  @override
  String get trips_edit_appBar_add => 'Adicionar Viagem';

  @override
  String get trips_edit_appBar_edit => 'Editar Viagem';

  @override
  String get trips_edit_button_add => 'Adicionar Viagem';

  @override
  String get trips_edit_button_cancel => 'Cancelar';

  @override
  String get trips_edit_button_save => 'Salvar';

  @override
  String get trips_edit_button_update => 'Atualizar Viagem';

  @override
  String get trips_edit_dialog_discard => 'Descartar';

  @override
  String get trips_edit_dialog_discardContent =>
      'Voce tem alteracoes nao salvas. Tem certeza de que deseja sair?';

  @override
  String get trips_edit_dialog_discardTitle => 'Descartar Alteracoes?';

  @override
  String get trips_edit_dialog_keepEditing => 'Continuar Editando';

  @override
  String trips_edit_durationDays(Object days) {
    return '$days dias';
  }

  @override
  String get trips_edit_hint_liveaboardName => 'ex., MY Blue Force One';

  @override
  String get trips_edit_hint_location => 'ex., Egito, Mar Vermelho';

  @override
  String get trips_edit_hint_notes => 'Notas adicionais sobre esta viagem';

  @override
  String get trips_edit_hint_resortName => 'ex., Marsa Shagra';

  @override
  String get trips_edit_hint_tripName => 'ex., Safari Mar Vermelho 2024';

  @override
  String get trips_edit_label_endDate => 'Data Final';

  @override
  String get trips_edit_label_liveaboardName => 'Nome do Liveaboard';

  @override
  String get trips_edit_label_location => 'Localizacao';

  @override
  String get trips_edit_label_notes => 'Notas';

  @override
  String get trips_edit_label_resortName => 'Nome do Resort';

  @override
  String get trips_edit_label_returnFlight => 'Voo de volta';

  @override
  String get trips_edit_returnFlightClear => 'Limpar voo de volta';

  @override
  String get trips_edit_returnFlightNotSet => 'Não definido';

  @override
  String get trips_edit_label_startDate => 'Data de Inicio';

  @override
  String get trips_edit_label_tripName => 'Nome da Viagem *';

  @override
  String get trips_edit_sectionTitle_dates => 'Datas da Viagem';

  @override
  String get trips_edit_sectionTitle_location => 'Localizacao';

  @override
  String get trips_edit_sectionTitle_notes => 'Notas';

  @override
  String get trips_edit_semanticLabel_save => 'Salvar viagem';

  @override
  String get trips_edit_snackBar_added => 'Viagem adicionada com sucesso';

  @override
  String trips_edit_snackBar_errorLoading(Object error) {
    return 'Erro ao carregar viagem: $error';
  }

  @override
  String trips_edit_snackBar_errorSaving(Object error) {
    return 'Erro ao salvar viagem: $error';
  }

  @override
  String get trips_edit_snackBar_updated => 'Viagem atualizada com sucesso';

  @override
  String get trips_edit_validation_nameRequired =>
      'Por favor, insira um nome para a viagem';

  @override
  String get trips_gallery_accessDenied =>
      'Acesso a biblioteca de fotos negado';

  @override
  String get trips_gallery_addDivesFirst =>
      'Adicione mergulhos primeiro para vincular fotos';

  @override
  String get trips_gallery_appBar_title => 'Fotos da Viagem';

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
    return 'Mergulho #$number - $site';
  }

  @override
  String get trips_gallery_empty_subtitle =>
      'Toque no icone da camera para escanear sua galeria';

  @override
  String get trips_gallery_empty_title => 'Nenhuma foto nesta viagem';

  @override
  String trips_gallery_errorLinking(Object error) {
    return 'Erro ao vincular fotos: $error';
  }

  @override
  String trips_gallery_errorScanning(Object error) {
    return 'Erro ao escanear: $error';
  }

  @override
  String trips_gallery_error_loading(Object error) {
    return 'Erro ao carregar fotos: $error';
  }

  @override
  String trips_gallery_linkedPhotos(Object count) {
    return '$count fotos vinculadas';
  }

  @override
  String get trips_gallery_linkingPhotos => 'Vinculando fotos...';

  @override
  String get trips_gallery_tooltip_scan => 'Escanear galeria do dispositivo';

  @override
  String get trips_gallery_tripNotFound => 'Viagem nao encontrada';

  @override
  String get trips_list_button_retry => 'Tentar novamente';

  @override
  String trips_list_countdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Em $days dias',
      one: 'Em 1 dia',
      zero: 'Começa hoje',
    );
    return '$_temp0';
  }

  @override
  String get trips_list_empty_button => 'Adicionar Sua Primeira Viagem';

  @override
  String get trips_list_empty_filtered_subtitle =>
      'Tente ajustar ou limpar seus filtros';

  @override
  String get trips_list_empty_filtered_title =>
      'Nenhuma viagem corresponde aos seus filtros';

  @override
  String get trips_list_empty_subtitle =>
      'Crie viagens para agrupar seus mergulhos por destino';

  @override
  String get trips_list_empty_title => 'Nenhuma viagem adicionada ainda';

  @override
  String trips_list_error_loading(Object error) {
    return 'Erro ao carregar viagens: $error';
  }

  @override
  String get trips_list_fab_addTrip => 'Adicionar Viagem';

  @override
  String get trips_list_filters_clearAll => 'Limpar tudo';

  @override
  String get trips_list_inProgress => 'Em andamento';

  @override
  String get trips_list_pastSection => 'Viagens Passadas';

  @override
  String get trips_list_sort_title => 'Ordenar Viagens';

  @override
  String trips_list_tile_diveCount(Object count) {
    return '$count mergulhos';
  }

  @override
  String get trips_list_tooltip_addTrip => 'Adicionar Viagem';

  @override
  String get trips_list_tooltip_search => 'Buscar viagens';

  @override
  String get trips_list_tooltip_sort => 'Ordenar';

  @override
  String get trips_list_upcomingSection => 'Próximas';

  @override
  String get trips_photos_empty_scanButton => 'Escanear galeria do dispositivo';

  @override
  String get trips_photos_empty_title => 'Nenhuma foto ainda';

  @override
  String get trips_photos_error_loading => 'Erro ao carregar fotos';

  @override
  String trips_photos_moreIndicator(Object count) {
    return '+$count';
  }

  @override
  String trips_photos_moreIndicator_semanticLabel(Object count) {
    return '$count fotos a mais';
  }

  @override
  String get trips_photos_sectionTitle => 'Fotos';

  @override
  String get trips_photos_tooltip_scan => 'Escanear galeria do dispositivo';

  @override
  String get trips_photos_viewAll => 'Ver Todas';

  @override
  String get trips_picker_clearTooltip => 'Limpar selecao';

  @override
  String get trips_picker_empty_createButton => 'Criar Viagem';

  @override
  String get trips_picker_empty_title => 'Nenhuma viagem ainda';

  @override
  String trips_picker_error(Object error) {
    return 'Erro ao carregar viagens: $error';
  }

  @override
  String get trips_picker_hint => 'Toque para selecionar uma viagem';

  @override
  String get trips_picker_newTrip => 'Nova Viagem';

  @override
  String get trips_picker_noSelection => 'Nenhuma viagem selecionada';

  @override
  String get trips_picker_sheetTitle => 'Selecionar Viagem';

  @override
  String trips_picker_suggestedPrefix(Object name) {
    return 'Sugerida: $name';
  }

  @override
  String get trips_picker_suggestedUse => 'Usar';

  @override
  String get trips_search_empty_hint =>
      'Buscar por nome, localizacao ou resort';

  @override
  String get trips_search_fieldLabel => 'Buscar viagens...';

  @override
  String trips_search_noResults(Object query) {
    return 'Nenhuma viagem encontrada para \"$query\"';
  }

  @override
  String get trips_search_tooltip_back => 'Voltar';

  @override
  String get trips_search_tooltip_clear => 'Limpar busca';

  @override
  String get trips_summary_header_subtitle =>
      'Selecione uma viagem da lista para ver detalhes';

  @override
  String get trips_summary_header_title => 'Viagens';

  @override
  String get trips_summary_overview_title => 'Visao Geral';

  @override
  String get trips_summary_quickActions_add => 'Adicionar Viagem';

  @override
  String get trips_summary_quickActions_title => 'Acoes Rapidas';

  @override
  String trips_summary_recentSubtitle(Object date, Object count) {
    return '$date • $count mergulhos';
  }

  @override
  String get trips_summary_recentTitle => 'Viagens Recentes';

  @override
  String get trips_summary_stat_daysDiving => 'Dias de Mergulho';

  @override
  String get trips_summary_stat_liveaboards => 'Liveaboards';

  @override
  String get trips_summary_stat_totalDives => 'Total de Mergulhos';

  @override
  String get trips_summary_stat_totalTrips => 'Total de Viagens';

  @override
  String trips_summary_upcomingSubtitle(Object date, Object days) {
    return '$date • Em $days dias';
  }

  @override
  String get trips_summary_upcomingTitle => 'Proximas';

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
  String get units_sac_pressurePerMin => 'pressao/min';

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
      'Consolidar como computador adicional';

  @override
  String get universalImport_action_continue => 'Continuar';

  @override
  String get universalImport_action_deselectAll => 'Desmarcar Todos';

  @override
  String get universalImport_action_done => 'Concluir';

  @override
  String get universalImport_action_import => 'Importar';

  @override
  String get universalImport_action_selectAll => 'Selecionar Todos';

  @override
  String get universalImport_action_changeFile => 'Alterar arquivo';

  @override
  String get universalImport_action_selectFile => 'Selecionar Arquivo';

  @override
  String get universalImport_action_selectFiles => 'Selecionar arquivos';

  @override
  String get universalImport_action_chooseFolder => 'Escolher pasta';

  @override
  String get universalImport_triage_title => 'Arquivos a importar';

  @override
  String universalImport_triage_readyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos prontos para importar',
      one: '1 arquivo pronto para importar',
    );
    return '$_temp0';
  }

  @override
  String universalImport_label_filesSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos selecionados',
      one: '1 arquivo selecionado',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_triage_excludedCsv =>
      'Importar individualmente (CSV)';

  @override
  String get universalImport_triage_unsupported => 'Formato não suportado';

  @override
  String get universalImport_triage_parseFailed => 'Não foi possível ler';

  @override
  String universalImport_triage_parsing(int current, int total) {
    return 'Analisando arquivo $current de $total…';
  }

  @override
  String get universalImport_triage_cancelParsing => 'Cancelar';

  @override
  String get universalImport_triage_allExcluded =>
      'Nenhum dos arquivos selecionados pode ser importado em conjunto. Arquivos CSV devem ser importados um de cada vez.';

  @override
  String get universalImport_triage_noneImportable =>
      'Nenhum dos arquivos selecionados pode ser importado.';

  @override
  String get universalImport_review_inBatchDuplicate =>
      'Duplicata de outro mergulho neste lote de importação.';

  @override
  String get universalImport_summary_filesTitle => 'Arquivos';

  @override
  String get universalImport_summary_noticesTitle => 'Não está no ficheiro';

  @override
  String get universalImport_summary_noticeNoTankPressureTitle =>
      'Pressão do cilindro não registada';

  @override
  String get universalImport_summary_noticeNoTankPressureBody =>
      'Não é possível calcular o consumo de ar nem o SAC. Pode adicionar a pressão inicial e final ao editar o mergulho.';

  @override
  String universalImport_summary_noticeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Afeta $count mergulhos',
      one: 'Afeta 1 mergulho',
    );
    return '$_temp0';
  }

  @override
  String universalImport_summary_fileImported(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos importados',
      one: '1 mergulho importado',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_summary_fileNeedsIndividualImport =>
      'Requer importação individual';

  @override
  String get universalImport_summary_fileUnsupported => 'Formato não suportado';

  @override
  String get universalImport_summary_fileParseFailed => 'Falha na leitura';

  @override
  String universalImport_bulk_consolidateMatched(int count) {
    return 'Consolidar correspondentes ($count)';
  }

  @override
  String universalImport_bulk_importAll(int count) {
    return 'Importar tudo ($count)';
  }

  @override
  String universalImport_bulk_importAllAsNew(int count) {
    return 'Importar tudo como novo ($count)';
  }

  @override
  String universalImport_bulk_skipAll(int count) {
    return 'Ignorar tudo ($count)';
  }

  @override
  String universalImport_bulk_replaceSourceAll(int count) {
    return 'Substituir todos ($count)';
  }

  @override
  String get universalImport_description_supportedFormats =>
      'Selecione um arquivo de registro de mergulho para importar. Os formatos suportados incluem CSV, UDDF, Subsurface XML e Garmin FIT.';

  @override
  String get universalImport_dive_decideAction => 'Decidir';

  @override
  String get universalImport_error_unsupportedFormat =>
      'Este formato ainda não é suportado. Exporte como UDDF ou CSV.';

  @override
  String get universalImport_label_columnMapping => 'Mapeamento de Colunas';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped de $total colunas mapeadas';
  }

  @override
  String get universalImport_label_consolidate => 'Consolidar';

  @override
  String get universalImport_label_detecting => 'Detectando...';

  @override
  String universalImport_label_diveNumber(Object number) {
    return 'Mergulho nº$number';
  }

  @override
  String get universalImport_label_duplicate => 'Duplicado';

  @override
  String universalImport_label_duplicatesFound(Object count) {
    return '$count duplicados encontrados e desmarcados automaticamente.';
  }

  @override
  String get universalImport_label_importAsNew => 'Importar como novo';

  @override
  String get universalImport_label_importComplete => 'Importação Concluída';

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
    return '$percent% de correspondência';
  }

  @override
  String get universalImport_label_possibleMatch => 'Possível correspondência';

  @override
  String get universalImport_label_selectCorrectSource =>
      'Não está certo? Selecione a fonte correta:';

  @override
  String universalImport_label_selected(Object count) {
    return '$count selecionado';
  }

  @override
  String get universalImport_label_skip => 'Pular';

  @override
  String universalImport_label_taggedAs(Object tag) {
    return 'Marcado como: $tag';
  }

  @override
  String get universalImport_label_unknownDate => 'Data desconhecida';

  @override
  String get universalImport_label_unnamed => 'Sem nome';

  @override
  String universalImport_label_xOfY(Object current, Object total) {
    return '$current de $total';
  }

  @override
  String universalImport_label_xOfYSelected(Object selected, Object total) {
    return '$selected de $total selecionado';
  }

  @override
  String get universalImport_entityAction_linkBadge => 'VINCULAR';

  @override
  String get universalImport_entityAction_linkExisting =>
      'Vincular ao existente';

  @override
  String get universalImport_entityAction_linkExistingSubtitle =>
      'Usar o registro correspondente';

  @override
  String get universalImport_entityAction_replaceBadge => 'SUBSTITUIR';

  @override
  String get universalImport_entityAction_replaceExisting =>
      'Substituir existente';

  @override
  String get universalImport_entityAction_replaceExistingSubtitle =>
      'Sobrescrever com os dados importados';

  @override
  String get universalImport_entityAction_skip => 'Pular';

  @override
  String get universalImport_entityAction_skipSubtitle =>
      'Descartar esta importação';

  @override
  String get universalImport_entityAction_importAsNew => 'Importar como novo';

  @override
  String get universalImport_entityAction_importAsNewSubtitle =>
      'Criar entrada separada';

  @override
  String get universalImport_pending_chooseAction => 'Escolher uma acao';

  @override
  String universalImport_pending_gateHint(int count) {
    return '$count duplicado(s) precisam de uma decisao';
  }

  @override
  String get universalImport_pending_needsDecision => 'Decisao necessaria';

  @override
  String get universalImport_pending_reviewAction => 'Rever';

  @override
  String get universalImport_rowHint_tapCompareToDecide =>
      'Toque em Decidir para escolher';

  @override
  String universalImport_semantics_entitySelection(
    Object selected,
    Object total,
    Object entityType,
  ) {
    return '$selected de $total $entityType selecionado';
  }

  @override
  String universalImport_semantics_importError(Object error) {
    return 'Erro de importação: $error';
  }

  @override
  String universalImport_semantics_importProgress(Object percent) {
    return 'Progresso da importação: $percent porcento';
  }

  @override
  String universalImport_semantics_itemsSelected(Object count) {
    return '$count itens selecionados para importação';
  }

  @override
  String get universalImport_semantics_needsDecision =>
      'Duplicado suspeito, decisao necessaria';

  @override
  String get universalImport_semantics_possibleDuplicate =>
      'Possível duplicado';

  @override
  String get universalImport_semantics_probableDuplicate =>
      'Provável duplicado';

  @override
  String universalImport_semantics_sourceDetected(Object description) {
    return 'Fonte detectada: $description';
  }

  @override
  String universalImport_semantics_sourceUncertain(Object description) {
    return 'Fonte incerta: $description';
  }

  @override
  String universalImport_semantics_toggleSelection(Object name) {
    return 'Alternar seleção para $name';
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
  String get universalImport_step_select => 'Selecionar';

  @override
  String get universalImport_summary_decidesRequired =>
      'Cada um precisa de uma decisao antes de importar.';

  @override
  String get universalImport_title => 'Importar Dados';

  @override
  String get universalImport_tooltip_closeWizard =>
      'Fechar assistente de importação';

  @override
  String weather_windFromDirection(Object wind, Object direction) {
    return '$wind de $direction';
  }

  @override
  String get weather_wind_calm => 'calmo';

  @override
  String get weather_wind_highWind => 'vento forte';

  @override
  String get weather_wind_lightBreeze => 'brisa leve';

  @override
  String get weather_wind_moderateBreeze => 'brisa moderada';

  @override
  String get weather_wind_strongBreeze => 'brisa forte';

  @override
  String get weather_wmo_clear => 'Ceu limpo';

  @override
  String get weather_wmo_drizzle => 'Chuvisco';

  @override
  String get weather_wmo_fog => 'Nevoeiro';

  @override
  String get weather_wmo_freezingDrizzle => 'Chuvisco gelado';

  @override
  String get weather_wmo_freezingRain => 'Chuva gelada';

  @override
  String get weather_wmo_mainlyClear => 'Maioritariamente limpo';

  @override
  String get weather_wmo_overcast => 'Encoberto';

  @override
  String get weather_wmo_partlyCloudy => 'Parcialmente nublado';

  @override
  String get weather_wmo_rain => 'Chuva';

  @override
  String get weather_wmo_rainShowers => 'Aguaceiros';

  @override
  String get weather_wmo_snow => 'Neve';

  @override
  String get weather_wmo_snowGrains => 'Graos de neve';

  @override
  String get weather_wmo_snowShowers => 'Aguaceiros de neve';

  @override
  String get weather_wmo_thunderstorm => 'Trovoada';

  @override
  String get weather_wmo_thunderstormHail => 'Trovoada com granizo';

  @override
  String weightCalc_baseLine(Object suitType, Object weight) {
    return 'Base ($suitType): $weight kg';
  }

  @override
  String weightCalc_bodyWeightAdjustment(Object adjustment) {
    return 'Ajuste de peso corporal: +$adjustment kg';
  }

  @override
  String get weightCalc_suit_drysuit => 'Roupa Seca';

  @override
  String get weightCalc_suit_none => 'Sem Roupa';

  @override
  String get weightCalc_suit_rashguard => 'Apenas Rashguard';

  @override
  String get weightCalc_suit_semidry => 'Roupa Semi-seca';

  @override
  String get weightCalc_suit_shorty3mm => 'Shorty 3mm';

  @override
  String get weightCalc_suit_wetsuit3mm => 'Roupa de Neoprene 3mm Longa';

  @override
  String get weightCalc_suit_wetsuit5mm => 'Roupa de Neoprene 5mm';

  @override
  String get weightCalc_suit_wetsuit7mm => 'Roupa de Neoprene 7mm';

  @override
  String weightCalc_tankLine(Object tankMaterial, Object adjustment) {
    return 'Cilindro ($tankMaterial): $adjustment kg';
  }

  @override
  String get weightCalc_title => 'Calculo de Lastro:';

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
    return 'Resultados, $count avisos';
  }

  @override
  String tides_semantic_tideCycle(Object state, Object height) {
    return 'Ciclo de maré, estado: $state, altura: $height';
  }

  @override
  String get tides_label_agoSuffix => 'atrás';

  @override
  String get tides_label_fromNowSuffix => 'a partir de agora';

  @override
  String get certifications_card_issued => 'EMITIDO';

  @override
  String certifications_certificate_cardNumber(Object number) {
    return 'Numero do Cartao: $number';
  }

  @override
  String get certifications_certificate_footer =>
      'Certificacao Oficial de Mergulho';

  @override
  String get certifications_certificate_hasCompletedTraining =>
      'concluiu o treinamento como';

  @override
  String certifications_certificate_instructor(Object name) {
    return 'Instrutor: $name';
  }

  @override
  String certifications_certificate_issued(Object date) {
    return 'Emitido: $date';
  }

  @override
  String get certifications_certificate_thisCertifies => 'Isto certifica que';

  @override
  String get diveComputer_connectionType_ble => 'Bluetooth LE';

  @override
  String get diveComputer_connectionType_bluetooth => 'Bluetooth';

  @override
  String get diveComputer_connectionType_infrared => 'Infravermelho';

  @override
  String get diveComputer_connectionType_unknown => 'Desconhecido';

  @override
  String get diveComputer_connectionType_usb => 'USB';

  @override
  String get diveComputer_connectionType_wifi => 'Wi-Fi';

  @override
  String diveComputer_detail_deleteDialogContent(String name) {
    return 'Tem certeza de que deseja remover \"$name\"? Isto nao excluira os mergulhos importados deste computador.';
  }

  @override
  String get diveComputer_detail_deleteDialogTitle => 'Excluir computador?';

  @override
  String get diveComputer_detail_divesImported => 'Mergulhos importados';

  @override
  String get diveComputer_detail_downloadDivesButton => 'Baixar mergulhos';

  @override
  String get diveComputer_detail_editDialogTitle => 'Editar computador';

  @override
  String get diveComputer_detail_editNameHint => 'Por exemplo, Meu Perdix';

  @override
  String get diveComputer_detail_editNotesHint => 'Notas opcionais';

  @override
  String get diveComputer_detail_labelConnection => 'Conexao';

  @override
  String get diveComputer_detail_labelManufacturer => 'Fabricante';

  @override
  String get diveComputer_detail_labelModel => 'Modelo';

  @override
  String get diveComputer_detail_labelName => 'Nome';

  @override
  String get diveComputer_detail_lastDownload => 'Ultimo download';

  @override
  String get diveComputer_detail_notesTitle => 'Notas';

  @override
  String get diveComputer_detail_reimportAllButton =>
      'Reimportar todos os mergulhos';

  @override
  String diveComputer_detail_reimportDialogBody(String computerName) {
    return 'Baixe todos os mergulhos de $computerName e compare-os com o seu log. Isso pode levar vários minutos.';
  }

  @override
  String get diveComputer_detail_reimportDialogTitle =>
      'Reimportar todos os mergulhos?';

  @override
  String get diveComputer_detail_statisticsTitle => 'Estatisticas';

  @override
  String get diveComputer_detail_unknown => 'Desconhecido';

  @override
  String get diveComputer_detail_viewDivesButton =>
      'Ver mergulhos deste computador';

  @override
  String get diveComputer_discovery_chooseDifferentDevice =>
      'Escolher Outro Dispositivo';

  @override
  String get diveComputer_discovery_computer => 'Computador';

  @override
  String get diveComputer_discovery_connectAndDownload => 'Conectar e Baixar';

  @override
  String get diveComputer_discovery_connectingToDevice =>
      'Conectando ao dispositivo...';

  @override
  String diveComputer_discovery_deviceNameHint(Object model) {
    return 'ex., Meu $model';
  }

  @override
  String get diveComputer_discovery_deviceNameLabel => 'Nome do Dispositivo';

  @override
  String get diveComputer_discovery_exitDialogCancel => 'Cancelar';

  @override
  String get diveComputer_discovery_exitDialogConfirm => 'Sair';

  @override
  String get diveComputer_discovery_exitDialogContent =>
      'Tem certeza que deseja sair? Seu progresso sera perdido.';

  @override
  String get diveComputer_discovery_exitDialogTitle => 'Sair da Configuracao?';

  @override
  String get diveComputer_discovery_exitTooltip => 'Sair da configuracao';

  @override
  String get diveComputer_discovery_noDeviceSelected =>
      'Nenhum dispositivo selecionado';

  @override
  String get diveComputer_discovery_pleaseWaitConnection =>
      'Aguarde enquanto estabelecemos a conexao';

  @override
  String get diveComputer_discovery_recognizedDevice =>
      'Dispositivo Reconhecido';

  @override
  String get diveComputer_discovery_recognizedDeviceDescription =>
      'Este dispositivo esta na nossa biblioteca de dispositivos suportados. O download dos mergulhos deve funcionar automaticamente.';

  @override
  String get diveComputer_discovery_stepConnect => 'Conectar';

  @override
  String get diveComputer_discovery_stepDone => 'Concluido';

  @override
  String get diveComputer_discovery_stepDownload => 'Baixar';

  @override
  String get diveComputer_discovery_stepScan => 'Buscar';

  @override
  String get diveComputer_discovery_titleComplete => 'Completo';

  @override
  String get diveComputer_discovery_titleConfirmDevice =>
      'Confirmar Dispositivo';

  @override
  String get diveComputer_discovery_titleConnecting => 'Conectando';

  @override
  String get diveComputer_discovery_titleDownloading => 'Baixando';

  @override
  String get diveComputer_discovery_titleFindDevice => 'Encontrar Dispositivo';

  @override
  String get diveComputer_discovery_unknownDevice => 'Dispositivo Desconhecido';

  @override
  String get diveComputer_discovery_unknownDeviceDescription =>
      'Este dispositivo nao esta na nossa biblioteca. Tentaremos conectar, mas o download pode nao funcionar.';

  @override
  String get diveComputer_discovery_usbInstructions =>
      'Conecte seu computador de mergulho via cabo USB e selecione-o abaixo.';

  @override
  String diveComputer_discovery_usbNoResults(String query) {
    return 'Nenhum dispositivo correspondente a \"$query\"';
  }

  @override
  String get diveComputer_discovery_usbSearchHint =>
      'Pesquisar por fabricante ou modelo...';

  @override
  String get diveComputer_downloadExit_content =>
      'Sair cancelara o download atual do seu computador de mergulho. Tem certeza?';

  @override
  String get diveComputer_downloadExit_leave => 'Sair';

  @override
  String get diveComputer_downloadExit_stay => 'Ficar';

  @override
  String get diveComputer_downloadExit_title => 'Download em andamento';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... e mais $count';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'Cancelar';

  @override
  String get diveComputer_downloadStep_cancelled => 'Download cancelado';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadAll =>
      'Baixar todos os mergulhos';

  @override
  String get diveComputer_downloadStep_downloadFailed => 'Falha no download';

  @override
  String get diveComputer_downloadStep_downloadNew => 'Baixar novos mergulhos';

  @override
  String get diveComputer_downloadStep_downloadedDives => 'Mergulhos Baixados';

  @override
  String diveComputer_downloadStep_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_downloadStep_errorOccurred => 'Ocorreu um erro';

  @override
  String diveComputer_downloadStep_errorSemanticLabel(Object error) {
    return 'Erro no download: $error';
  }

  @override
  String get diveComputer_downloadStep_firstSyncBody =>
      'Seu diário já tem mergulhos. Você pode pular o download de mergulhos que já possui.';

  @override
  String get diveComputer_downloadStep_firstSyncTitle =>
      'Primeiro download deste computador de mergulho';

  @override
  String diveComputer_downloadStep_onlyAfterDate(String date) {
    return 'Baixar apenas mergulhos após $date';
  }

  @override
  String diveComputer_downloadStep_percentAccessibility(Object percent) {
    return ', $percent por cento';
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
    return 'Progresso do download: $status$percent';
  }

  @override
  String get diveComputer_downloadStep_retry => 'Tentar Novamente';

  @override
  String diveComputer_downloadStep_importPartialCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importar $count mergulhos baixados',
      one: 'Importar 1 mergulho baixado',
    );
    return '$_temp0';
  }

  @override
  String get diveComputer_download_cancel => 'Cancelar';

  @override
  String get diveComputer_download_closeTooltip => 'Fechar';

  @override
  String get diveComputer_download_computerNotFound =>
      'Computador nao encontrado';

  @override
  String diveComputer_download_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String diveComputer_download_deviceNotFoundError(Object name) {
    return 'Dispositivo nao encontrado. Certifique-se de que o $name esta proximo e em modo de transferencia.';
  }

  @override
  String get diveComputer_download_deviceNotFoundTitle =>
      'Dispositivo Nao Encontrado';

  @override
  String get diveComputer_download_divesUpdated => 'Mergulhos atualizados';

  @override
  String get diveComputer_download_done => 'Concluido';

  @override
  String get diveComputer_download_downloadedDives => 'Mergulhos Baixados';

  @override
  String get diveComputer_download_duplicatesSkipped => 'Duplicados ignorados';

  @override
  String diveComputer_download_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_download_errorOccurred => 'Ocorreu um erro';

  @override
  String get diveComputer_download_noSerialPortsFound =>
      'Nenhuma porta serial USB encontrada. O computador de mergulho está conectado e ligado?';

  @override
  String get diveComputer_download_stalePairing =>
      'O emparelhamento Bluetooth deste computador de mergulho está desatualizado. Esqueça o computador de mergulho nas definições de Bluetooth do seu dispositivo e emparelhe-o novamente a partir do menu Bluetooth do computador de mergulho.';

  @override
  String get diveComputer_download_discoveryStalled =>
      'Ligou-se ao computador de mergulho, mas ele deixou de responder antes de a transferência começar. Normalmente isto significa que o emparelhamento Bluetooth está desatualizado: esqueça o computador de mergulho nas definições de Bluetooth do seu dispositivo e tente novamente.';

  @override
  String diveComputer_download_serialConnectFailedWithDetails(Object details) {
    return 'Não foi possível conectar ao computador de mergulho.\n\nDetalhes de diagnóstico (compartilhe com os desenvolvedores):\n$details';
  }

  @override
  String diveComputer_download_errorWithMessage(Object error) {
    return 'Erro: $error';
  }

  @override
  String get diveComputer_download_goBack => 'Voltar';

  @override
  String get diveComputer_download_importFailed => 'Falha na importacao';

  @override
  String get diveComputer_download_importResults => 'Resultados da Importacao';

  @override
  String get diveComputer_download_importedDives => 'Mergulhos Importados';

  @override
  String diveComputer_download_importingCountDives(int count) {
    return 'Importando $count mergulhos...';
  }

  @override
  String diveComputer_download_importingCountNewDives(int count) {
    return 'Importando $count novos mergulhos...';
  }

  @override
  String get diveComputer_download_newDivesImported =>
      'Novos mergulhos importados';

  @override
  String get diveComputer_download_newDivesOnlySubtitle =>
      'Baixa apenas mergulhos adicionados desde a última sincronização';

  @override
  String get diveComputer_download_newDivesOnlyTitle =>
      'Baixar apenas novos mergulhos';

  @override
  String get diveComputer_download_preparing => 'Preparando...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_reimportHint =>
      'Procurando mergulhos antigos ou excluídos? Reimportar todos';

  @override
  String get diveComputer_download_retry => 'Tentar Novamente';

  @override
  String diveComputer_download_scanError(Object error) {
    return 'Erro na busca: $error';
  }

  @override
  String diveComputer_download_searchingForDevice(Object name) {
    return 'Buscando $name...';
  }

  @override
  String get diveComputer_download_searchingInstructions =>
      'Certifique-se de que o dispositivo esta proximo e em modo de transferencia';

  @override
  String get diveComputer_download_title => 'Baixar Mergulhos';

  @override
  String get diveComputer_download_tryAgain => 'Tentar Novamente';

  @override
  String get diveComputer_download_upToDate =>
      'Nenhum mergulho novo encontrado -- seu registro está atualizado';

  @override
  String get diveComputer_list_addComputer => 'Adicionar Computador';

  @override
  String diveComputer_list_cardSemanticLabel(Object name) {
    return 'Computador de mergulho: $name';
  }

  @override
  String diveComputer_list_diveCount(Object count) {
    return '$count mergulhos';
  }

  @override
  String get diveComputer_list_downloadTooltip => 'Baixar mergulhos';

  @override
  String get diveComputer_list_emptyMessage =>
      'Conecte seu computador de mergulho para baixar mergulhos diretamente no aplicativo.';

  @override
  String get diveComputer_list_emptyTitle => 'Nenhum Computador de Mergulho';

  @override
  String get diveComputer_list_findComputers => 'Buscar Computadores';

  @override
  String get diveComputer_list_helpBluetooth =>
      '- Bluetooth LE (computadores mais recentes)';

  @override
  String get diveComputer_list_helpBluetoothClassic =>
      '- Bluetooth Classic (modelos antigos)';

  @override
  String get diveComputer_list_helpBrandsList =>
      'Shearwater, Suunto, Garmin, Mares, Scubapro, Oceanic, Aqualung, Cressi e mais de 50 modelos.';

  @override
  String get diveComputer_list_helpBrandsTitle => 'Marcas Suportadas';

  @override
  String get diveComputer_list_helpConnectionsTitle => 'Conexoes Suportadas';

  @override
  String get diveComputer_list_helpDialogTitle =>
      'Ajuda - Computador de Mergulho';

  @override
  String get diveComputer_list_helpDismiss => 'Entendi';

  @override
  String get diveComputer_list_helpTip1 =>
      '- Certifique-se de que o computador esta em modo de transferencia';

  @override
  String get diveComputer_list_helpTip2 =>
      '- Mantenha os dispositivos proximos durante o download';

  @override
  String get diveComputer_list_helpTip3 =>
      '- Certifique-se de que o Bluetooth esta ativado';

  @override
  String get diveComputer_list_helpTipsTitle => 'Dicas';

  @override
  String get diveComputer_list_helpTooltip => 'Ajuda';

  @override
  String get diveComputer_list_helpUsb => '- USB (apenas desktop)';

  @override
  String get diveComputer_list_loadFailed =>
      'Falha ao carregar computadores de mergulho';

  @override
  String get diveComputer_list_retry => 'Tentar Novamente';

  @override
  String get diveComputer_list_title => 'Computadores de Mergulho';

  @override
  String get diveComputer_pinCode_instructions =>
      'Insira o codigo exibido no seu computador de mergulho.';

  @override
  String get diveComputer_pinCode_label => 'Codigo PIN';

  @override
  String get diveComputer_pinCode_submit => 'Enviar';

  @override
  String get diveComputer_pinCode_title => 'Codigo PIN necessario';

  @override
  String get diveComputer_pinEntry_connectButton => 'Conectar';

  @override
  String get diveComputer_pinEntry_helperText =>
      'Insira o PIN de 4 a 6 digitos exibido no seu dispositivo';

  @override
  String get diveComputer_pinEntry_instructionsGeneric =>
      'Verifique o visor do seu computador de mergulho para o codigo PIN.';

  @override
  String diveComputer_pinEntry_instructionsWithDevice(String deviceName) {
    return 'Verifique o visor do seu $deviceName para o codigo PIN.';
  }

  @override
  String get diveComputer_pinEntry_semanticLabel =>
      'Entrada de codigo PIN, 4 a 6 digitos';

  @override
  String get diveComputer_pinEntry_title => 'Inserir codigo PIN';

  @override
  String diveComputer_scan_bluetoothSemanticLabel(String name) {
    return 'Dispositivo Bluetooth: $name';
  }

  @override
  String get diveComputer_scan_emptyStateInstructions =>
      'Certifique-se de que seu computador de mergulho:\n• Esta ligado\n• Esta no modo de emparelhamento Bluetooth\n• Esta perto do seu dispositivo';

  @override
  String get diveComputer_scan_knownBadge => 'Conhecido';

  @override
  String get diveComputer_scan_lookingForDevicesTitle =>
      'Procurando dispositivos';

  @override
  String get diveComputer_scan_noUsbDevicesAvailable =>
      'Nenhum dispositivo USB disponivel';

  @override
  String get diveComputer_scan_retry => 'Tentar novamente';

  @override
  String get diveComputer_scan_scanAgain => 'Procurar novamente';

  @override
  String get diveComputer_scan_scanningStatus =>
      'Procurando computadores de mergulho...';

  @override
  String get diveComputer_scan_stopScanning => 'Parar busca';

  @override
  String get diveComputer_scan_supportedBadge => 'Suportado';

  @override
  String get diveComputer_scan_tabBluetooth => 'Bluetooth';

  @override
  String get diveComputer_scan_tabUsb => 'Cabo USB';

  @override
  String get diveComputer_scan_usbCableLabel => 'Cabo USB';

  @override
  String diveComputer_scan_usbSemanticLabel(String model) {
    return 'Dispositivo USB: $model';
  }

  @override
  String get diveComputer_summary_diveComputer => 'computador de mergulho';

  @override
  String diveComputer_summary_divesDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mergulhos',
      one: 'mergulho',
    );
    return '$count $_temp0 baixado(s)';
  }

  @override
  String get diveComputer_summary_done => 'Concluido';

  @override
  String get diveComputer_summary_imported => 'Importados';

  @override
  String diveComputer_summary_semanticLabel(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mergulhos',
      one: 'mergulho',
    );
    return '$count $_temp0 baixado(s) de $name';
  }

  @override
  String get diveComputer_summary_skippedDuplicates => 'Ignorados (duplicados)';

  @override
  String get diveComputer_summary_title => 'Download Concluido!';

  @override
  String get diveComputer_summary_updated => 'Atualizados';

  @override
  String get diveComputer_summary_viewDives => 'Ver Mergulhos';

  @override
  String get diveImport_alreadyImported => 'Ja importado';

  @override
  String get diveImport_avgHR => 'FC Media';

  @override
  String get diveImport_back => 'Voltar';

  @override
  String get diveImport_deselectAll => 'Desmarcar Todos';

  @override
  String get diveImport_divesImported => 'Mergulhos importados';

  @override
  String get diveImport_divesMerged => 'Mergulhos mesclados';

  @override
  String get diveImport_divesSkipped => 'Mergulhos ignorados';

  @override
  String get diveImport_done => 'Concluido';

  @override
  String get diveImport_duration => 'Duracao';

  @override
  String get diveImport_error => 'Erro';

  @override
  String get diveImport_fit_closeTooltip => 'Fechar importacao FIT';

  @override
  String get diveImport_fit_noDivesDescription =>
      'Selecione um ou mais ficheiros .fit exportados do Garmin Connect ou copiados de um dispositivo Garmin Descent.';

  @override
  String get diveImport_fit_noDivesLoaded => 'Nenhum Mergulho Carregado';

  @override
  String diveImport_fit_parsed(int diveCount, int fileCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'mergulhos',
      one: 'mergulho',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'ficheiros',
      one: 'ficheiro',
    );
    return '$diveCount $_temp0 analisado(s) de $fileCount $_temp1';
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
      other: 'mergulhos',
      one: 'mergulho',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'ficheiros',
      one: 'ficheiro',
    );
    return '$diveCount $_temp0 analisado(s) de $fileCount $_temp1 ($skippedCount ignorados)';
  }

  @override
  String get diveImport_fit_parsing => 'Analisando...';

  @override
  String get diveImport_fit_selectFiles => 'Selecionar Ficheiros FIT';

  @override
  String get diveImport_fit_title => 'Importar de Ficheiro FIT';

  @override
  String get diveImport_healthkit_accessDescription =>
      'Submersion uses Apple HealthKit to read underwater diving workout data, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get diveImport_healthkit_accessRequired => 'Apple HealthKit';

  @override
  String get diveImport_healthkit_attribution =>
      'Fornecido por Apple HealthKit';

  @override
  String get diveImport_healthkit_closeTooltip =>
      'Fechar importacao do Apple Watch';

  @override
  String get diveImport_healthkit_dataUsage =>
      'Le atividades de mergulho subaquatico do Apple Health, incluindo profundidade, duracao, temperatura da agua e frequencia cardiaca. Esses dados sao armazenados localmente no seu registro de mergulho e nunca sao compartilhados com terceiros.';

  @override
  String get diveImport_healthkit_dateFrom => 'De';

  @override
  String diveImport_healthkit_dateSelectorLabel(Object label) {
    return 'Seletor de data $label';
  }

  @override
  String get diveImport_healthkit_dateTo => 'Ate';

  @override
  String get diveImport_healthkit_fetchDives => 'Obter Mergulhos';

  @override
  String get diveImport_healthkit_fetching => 'Obtendo...';

  @override
  String get diveImport_healthkit_grantAccess => 'Continuar';

  @override
  String get diveImport_healthkit_noDivesFound => 'Nenhum Mergulho Encontrado';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'Nenhuma atividade de mergulho subaquatico encontrada no periodo selecionado.';

  @override
  String get diveImport_healthkit_notAvailable => 'Nao Disponivel';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'A importação do Apple Watch precisa de um iPhone com a app Saúde.';

  @override
  String get diveImport_healthkit_permissionCheckFailed =>
      'Falha ao verificar permissoes';

  @override
  String get diveImport_healthkit_title => 'Importar do Apple Watch';

  @override
  String get diveImport_healthkit_watchTitle => 'Importar do Relogio';

  @override
  String get diveImport_import => 'Importar';

  @override
  String get diveImport_importComplete => 'Importacao Concluida';

  @override
  String get diveImport_likelyDuplicate => 'Provavel duplicado';

  @override
  String get diveImport_maxDepth => 'Prof. Max.';

  @override
  String get diveImport_newDive => 'Novo mergulho';

  @override
  String get diveImport_next => 'Proximo';

  @override
  String get diveImport_possibleDuplicate => 'Possivel duplicado';

  @override
  String get diveImport_reviewSelectedDives => 'Revisar Mergulhos Selecionados';

  @override
  String diveImport_reviewSummary(
    Object newCount,
    int possibleCount,
    int skipCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      possibleCount,
      locale: localeName,
      other: ', $possibleCount possiveis duplicados',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipCount,
      locale: localeName,
      other: ', $skipCount serao ignorados',
      zero: '',
    );
    return '$newCount novos$_temp0$_temp1';
  }

  @override
  String get diveImport_selectAll => 'Selecionar Todos';

  @override
  String diveImport_selectedCount(Object count) {
    return '$count selecionados';
  }

  @override
  String get diveImport_sourceGarmin => 'Garmin';

  @override
  String get diveImport_sourceSuunto => 'Suunto';

  @override
  String get diveImport_sourceUDDF => 'UDDF';

  @override
  String get diveImport_sourceWatch => 'Relogio';

  @override
  String get diveImport_step_done => 'Concluido';

  @override
  String get diveImport_step_review => 'Revisar';

  @override
  String get diveImport_step_select => 'Selecionar';

  @override
  String get diveImport_temp => 'Temp';

  @override
  String get diveImport_toggleDiveSelection => 'Alternar selecao do mergulho';

  @override
  String get diveImport_uddf_buddies => 'Companheiros';

  @override
  String get diveImport_uddf_certifications => 'Certificacoes';

  @override
  String get diveImport_uddf_closeTooltip => 'Fechar importacao UDDF';

  @override
  String get diveImport_uddf_diveCenters => 'Centros de Mergulho';

  @override
  String get diveImport_uddf_diveTypes => 'Tipos de Mergulho';

  @override
  String get diveImport_uddf_dives => 'Mergulhos';

  @override
  String get diveImport_uddf_duplicate => 'Duplicado';

  @override
  String diveImport_uddf_duplicatesFound(Object count) {
    return '$count duplicados encontrados e desmarcados automaticamente.';
  }

  @override
  String get diveImport_uddf_equipment => 'Equipamento';

  @override
  String get diveImport_uddf_equipmentSets => 'Conjuntos de Equipamento';

  @override
  String diveImport_uddf_importProgress(Object current, Object total) {
    return '$current de $total';
  }

  @override
  String get diveImport_uddf_importing => 'Importando...';

  @override
  String get diveImport_uddf_likelyDuplicate => 'Provavel duplicado';

  @override
  String get diveImport_uddf_noFileDescription =>
      'Selecione um ficheiro .uddf ou .xml exportado de outro aplicativo de registro de mergulhos.';

  @override
  String get diveImport_uddf_noFileSelected => 'Nenhum Ficheiro Selecionado';

  @override
  String get diveImport_uddf_parsing => 'Analisando...';

  @override
  String get diveImport_uddf_possibleDuplicate => 'Possivel duplicado';

  @override
  String get diveImport_uddf_selectFile => 'Selecionar Ficheiro UDDF';

  @override
  String diveImport_uddf_selectedOfTotal(Object selected, Object total) {
    return '$selected de $total selecionados';
  }

  @override
  String get diveImport_uddf_sites => 'Locais';

  @override
  String get diveImport_uddf_stepImport => 'Importar';

  @override
  String get diveImport_uddf_tabBuddies => 'Companheiros';

  @override
  String get diveImport_uddf_tabCenters => 'Centros';

  @override
  String get diveImport_uddf_tabCerts => 'Certs';

  @override
  String get diveImport_uddf_tabCourses => 'Cursos';

  @override
  String get diveImport_uddf_tabDives => 'Mergulhos';

  @override
  String get diveImport_uddf_tabEquipment => 'Equipamento';

  @override
  String get diveImport_uddf_tabSets => 'Conjuntos';

  @override
  String get diveImport_uddf_tabSites => 'Locais';

  @override
  String get diveImport_uddf_tabTags => 'Tags';

  @override
  String get diveImport_uddf_tabTrips => 'Viagens';

  @override
  String get diveImport_uddf_tabTypes => 'Tipos';

  @override
  String get diveImport_uddf_tags => 'Tags';

  @override
  String get diveImport_uddf_media => 'Fotos';

  @override
  String get diveImport_uddf_title => 'Importar de UDDF';

  @override
  String get diveImport_uddf_toggleDiveSelection =>
      'Alternar selecao do mergulho';

  @override
  String diveImport_uddf_toggleEntitySelection(Object name) {
    return 'Alternar selecao de $name';
  }

  @override
  String get diveImport_uddf_trips => 'Viagens';

  @override
  String get divePlanner_segmentEditor_addTitle => 'Adicionar Segmento';

  @override
  String divePlanner_segmentEditor_ascentRate(Object unit) {
    return 'Taxa de Subida ($unit/min)';
  }

  @override
  String divePlanner_segmentEditor_descentRate(Object unit) {
    return 'Taxa de Descida ($unit/min)';
  }

  @override
  String get divePlanner_segmentEditor_duration => 'Duracao (min)';

  @override
  String get divePlanner_segmentEditor_editTitle => 'Editar Segmento';

  @override
  String divePlanner_segmentEditor_endDepth(Object unit) {
    return 'Profundidade Final ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_gasSwitchTime => 'Tempo de troca de gas';

  @override
  String get divePlanner_segmentEditor_segmentType => 'Tipo de Segmento';

  @override
  String divePlanner_segmentEditor_startDepth(Object unit) {
    return 'Profundidade Inicial ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_tankGas => 'Cilindro / Gas';

  @override
  String get divePlanner_segmentList_addSegment => 'Adicionar Segmento';

  @override
  String divePlanner_segmentList_ascent(Object startDepth, Object endDepth) {
    return 'Subida $startDepth -> $endDepth';
  }

  @override
  String divePlanner_segmentList_bottom(Object depth, Object minutes) {
    return 'Fundo $depth por $minutes min';
  }

  @override
  String divePlanner_segmentList_deco(Object depth, Object minutes) {
    return 'Deco $depth por $minutes min';
  }

  @override
  String get divePlanner_segmentList_deleteSegment => 'Excluir segmento';

  @override
  String divePlanner_segmentList_descent(Object startDepth, Object endDepth) {
    return 'Descida $startDepth -> $endDepth';
  }

  @override
  String get divePlanner_segmentList_editSegment => 'Editar segmento';

  @override
  String get divePlanner_segmentList_emptyMessage =>
      'Adicione segmentos manualmente ou crie um plano rapido';

  @override
  String get divePlanner_segmentList_emptyTitle => 'Nenhum segmento ainda';

  @override
  String divePlanner_segmentList_gasSwitch(Object gasName) {
    return 'Troca de gas para $gasName';
  }

  @override
  String get divePlanner_segmentList_quickPlan => 'Plano Rapido';

  @override
  String divePlanner_segmentList_safetyStop(Object depth, Object minutes) {
    return 'Parada de seguranca $depth por $minutes min';
  }

  @override
  String get divePlanner_segmentList_title => 'Segmentos do Mergulho';

  @override
  String get divePlanner_segmentType_ascent => 'Subida';

  @override
  String get divePlanner_segmentType_bottomTime => 'Tempo de Fundo';

  @override
  String get divePlanner_segmentType_decoStop => 'Parada Deco';

  @override
  String get divePlanner_segmentType_descent => 'Descida';

  @override
  String get divePlanner_segmentType_gasSwitch => 'Troca de Gas';

  @override
  String get divePlanner_segmentType_safetyStop => 'Parada de Seguranca';

  @override
  String get divePlanner_undo => 'Desfazer';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'Rock bottom e a reserva minima de gas para uma subida de emergencia partilhando ar com o seu companheiro.\n\n- Utiliza taxas RMV sob stress (2-3x o normal)\n- Assume ambos os mergulhadores num unico cilindro\n- Inclui parada de seguranca quando ativada\n\nVire sempre o mergulho ANTES de atingir o rock bottom!';

  @override
  String get gasCalculators_rockBottom_aboutTitle => 'Sobre Rock Bottom';

  @override
  String get gasCalculators_rockBottom_ascentGasRequired =>
      'Gas necessario para subida';

  @override
  String get gasCalculators_rockBottom_ascentRate => 'Taxa de Subida';

  @override
  String gasCalculators_rockBottom_ascentTimeToDepth(
    Object depth,
    Object unit,
  ) {
    return 'Tempo de subida ate $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_ascentTimeToSurface =>
      'Tempo de subida ate a superficie';

  @override
  String get gasCalculators_rockBottom_buddySac => 'RMV do Companheiro';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'RMV combinado sob stress';

  @override
  String get gasCalculators_rockBottom_emergencyAscentBreakdown =>
      'Detalhes da Subida de Emergencia';

  @override
  String get gasCalculators_rockBottom_emergencyScenario =>
      'Cenario de Emergencia';

  @override
  String get gasCalculators_rockBottom_includeSafetyStop =>
      'Incluir Parada de Seguranca';

  @override
  String get gasCalculators_rockBottom_maximumDepth => 'Profundidade Maxima';

  @override
  String get gasCalculators_rockBottom_minimumReserve => 'Reserva Minima';

  @override
  String gasCalculators_rockBottom_resultSemantics(
    Object pressure,
    Object pressureUnit,
    Object volume,
    Object volumeUnit,
  ) {
    return 'Reserva minima: $pressure $pressureUnit, $volume $volumeUnit. Vire o mergulho ao atingir $pressure $pressureUnit restantes';
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
    return 'Gas da parada de seguranca (3 min @ $depth$unit)';
  }

  @override
  String get gasCalculators_rockBottom_stressedSacHint =>
      'Use um RMV mais alto para compensar o stress durante emergencias';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => 'RMV sob Stress';

  @override
  String get gasCalculators_rockBottom_tankSize => 'Tamanho do Cilindro';

  @override
  String get gasCalculators_rockBottom_totalReserveNeeded =>
      'Reserva total necessaria';

  @override
  String gasCalculators_rockBottom_turnDive(
    Object pressure,
    Object pressureUnit,
  ) {
    return 'Vire o mergulho ao atingir $pressure $pressureUnit restantes';
  }

  @override
  String get gasCalculators_rockBottom_yourSac => 'Seu RMV';

  @override
  String get gpsLogger_androidNotificationText =>
      'Gravando sua trilha de superfície';

  @override
  String get gpsLogger_androidNotificationTitle =>
      'Registrador GPS do Submersion';

  @override
  String get gpsLogger_deleteTrackMessage =>
      'Remove a trilha GPS gravada. As posições já atribuídas aos mergulhos são mantidas.';

  @override
  String get gpsLogger_deleteTrackTitle => 'Excluir trilha?';

  @override
  String get gpsLogger_interruptedNotice =>
      'Uma gravação anterior foi interrompida. A trilha foi salva.';

  @override
  String gpsLogger_lastFix(String age, String accuracy) {
    return 'Última posição há $age ($accuracy)';
  }

  @override
  String get gpsLogger_locationOff =>
      'Os serviços de localização estão desativados.';

  @override
  String get gpsLogger_matchButton => 'Associar mergulhos aos registros GPS';

  @override
  String gpsLogger_matchResult(int count) {
    return '$count mergulhos posicionados';
  }

  @override
  String get gpsLogger_matchResultNone =>
      'Nenhum mergulho corresponde a uma trilha gravada';

  @override
  String get gpsLogger_noFixYet => 'Aguardando sinal de GPS';

  @override
  String get gpsLogger_noTracks => 'Nenhuma trilha GPS gravada ainda';

  @override
  String get gpsLogger_permissionDenied =>
      'A permissão de localização é necessária para gravar uma trilha GPS. Ative-a nas configurações do sistema.';

  @override
  String gpsLogger_recordingStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pontos',
      one: '$count ponto',
    );
    return 'Gravando - $_temp0';
  }

  @override
  String get gpsLogger_reviewSites =>
      'Revisar correspondências de pontos de mergulho';

  @override
  String get gpsLogger_startButton => 'Iniciar registro';

  @override
  String get gpsLogger_stopButton => 'Parar registro';

  @override
  String gpsLogger_stripStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pontos',
      one: '$count ponto',
    );
    return 'Gravando trilha GPS · $_temp0';
  }

  @override
  String get gpsLogger_summary_tracks => 'Trilhas';

  @override
  String get gpsLogger_summary_recordedTime => 'Tempo gravado';

  @override
  String get gpsLogger_summary_divesCovered => 'Mergulhos cobertos';

  @override
  String gpsLogger_trackSubtitle(num count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pontos',
      one: '$count ponto',
    );
    return '$_temp0, $duration';
  }

  @override
  String gpsLogger_trackSubtitleTrimmed(String duration) {
    return 'Recortada, $duration';
  }

  @override
  String get gpsLogger_tracksHeader => 'Trilhas gravadas';

  @override
  String get gpsTrack_action_trim => 'Recortar...';

  @override
  String get gpsTrack_action_split => 'Dividir...';

  @override
  String get gpsTrack_action_resetTrim => 'Remover recorte';

  @override
  String get gpsTrack_edit_applyTrim => 'Aplicar recorte';

  @override
  String get gpsTrack_edit_confirmSplit => 'Dividir aqui';

  @override
  String get gpsTrack_edit_splitWarning =>
      'Dividir cria duas trilhas e remove a original. Não é possível desfazer.';

  @override
  String get gpsTrack_edit_cancel => 'Cancelar';

  @override
  String get gpsTrack_import_action => 'Importar trilha...';

  @override
  String get gpsTrack_import_reviewTitle => 'Rever importação';

  @override
  String get gpsTrack_import_timezone => 'Gravada em';

  @override
  String get gpsTrack_import_timezoneHint =>
      'As horas no ficheiro estão em UTC. Defina o fuso em que a trilha foi gravada para coincidir com os seus mergulhos.';

  @override
  String get gpsTrack_import_duplicate =>
      'Isto parece um duplicado de uma trilha existente.';

  @override
  String get gpsTrack_import_confirm => 'Importar';

  @override
  String get gpsTrack_import_csvMapping => 'Associar colunas';

  @override
  String get gpsTrack_import_firstFix => 'Primeiro ponto';

  @override
  String gpsTrack_import_fixCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pontos',
      one: '1 ponto',
    );
    return '$_temp0';
  }

  @override
  String gpsTrack_import_failed(String reason) {
    return 'Não foi possível ler o ficheiro: $reason';
  }

  @override
  String get gpsTrack_importError_unsupportedFormat =>
      'Esse tipo de arquivo não é compatível. Importe um arquivo GPX, KML, CSV ou FIT.';

  @override
  String get gpsTrack_importError_unreadable =>
      'Não foi possível ler esse arquivo. Ele pode estar danificado ou incompleto.';

  @override
  String get gpsTrack_importError_noPositions =>
      'Esse arquivo não tem posições GPS com data e hora.';

  @override
  String get gpsTrack_importError_badData =>
      'Esse arquivo tem uma posição ou data e hora que o app não consegue ler.';

  @override
  String get gpsTrack_export_saved => 'Trilha guardada';

  @override
  String get gpsTrack_action_export => 'Exportar';

  @override
  String get gpsTrack_action_shareGpx => 'Partilhar como GPX';

  @override
  String get gpsTrack_action_saveGpx => 'Guardar como GPX...';

  @override
  String get gpsTrack_action_shareKml => 'Partilhar como KML';

  @override
  String get gpsTrack_action_saveKml => 'Guardar como KML...';

  @override
  String get gpsTrack_export_failed => 'Falha na exportação.';

  @override
  String get gpsTrack_map_title => 'Mapa de trilhas';

  @override
  String gpsTrack_map_truncated(int count) {
    return 'Mostrando as $count trilhas mais recentes. Ajuste o filtro de datas para ver as outras.';
  }

  @override
  String get gpsTrack_map_noTracks => 'Não há trilhas gravadas para mostrar.';

  @override
  String get gpsTrack_map_showMap => 'Mostrar mapa';

  @override
  String get gpsTrack_filter_all => 'Todas as datas';

  @override
  String get gpsTrack_filter_clear => 'Limpar filtro de datas';

  @override
  String get gpsTrack_inspect_speed => 'Velocidade';

  @override
  String get gpsTrack_inspect_accuracy => 'Precisão';

  @override
  String get gpsTrack_stats_distance => 'Distância';

  @override
  String get gpsTrack_stats_duration => 'Duração';

  @override
  String get gpsTrack_stats_avgSpeed => 'Vel. média';

  @override
  String get gpsTrack_stats_maxSpeed => 'Vel. máx.';

  @override
  String get gpsTrack_stats_fixes => 'Pontos';

  @override
  String get gpsTrack_stats_dives => 'Mergulhos';

  @override
  String get gpsTrack_colorMode_uniform => 'Simples';

  @override
  String get gpsTrack_colorMode_speed => 'Velocidade';

  @override
  String get gpsTrack_colorMode_elapsed => 'Tempo';

  @override
  String get gpsTrack_legend_slower => 'Mais lento';

  @override
  String get gpsTrack_legend_faster => 'Mais rápido';

  @override
  String get gpsTrack_legend_start => 'Início';

  @override
  String get gpsTrack_legend_end => 'Fim';

  @override
  String get gpsTrack_detail_title => 'Trilha GPS';

  @override
  String get gpsTrack_detail_notFound => 'Esta trilha já não está disponível.';

  @override
  String get gpsTrack_detail_unreadable =>
      'Não foi possível ler os dados da trilha.';

  @override
  String get gpsTrack_detail_noPoints =>
      'Esta trilha não tem posições registadas.';

  @override
  String get maps_compass_resetLabel =>
      'Redefinir a orientação do mapa para o norte';

  @override
  String get maps_compass_resetTooltip => 'Norte para cima';

  @override
  String get maps_heatMap_hide => 'Ocultar Mapa de Calor';

  @override
  String get maps_heatMap_overlayOff =>
      'Sobreposicao do mapa de calor desativada';

  @override
  String get maps_depthOverlay_show => 'Mostrar camada de profundidade';

  @override
  String get maps_depthOverlay_hide => 'Ocultar camada de profundidade';

  @override
  String get maps_heatMap_overlayOn => 'Sobreposicao do mapa de calor ativada';

  @override
  String get maps_heatMap_show => 'Mostrar Mapa de Calor';

  @override
  String get maps_offline_bounds => 'Limites';

  @override
  String maps_offline_cacheHitRateAccessibility(Object rate) {
    return 'Taxa de acerto do cache: $rate por cento';
  }

  @override
  String get maps_offline_cacheHits => 'Acertos do Cache';

  @override
  String get maps_offline_cacheMisses => 'Falhas do Cache';

  @override
  String get maps_offline_cacheStatistics => 'Estatisticas do Cache';

  @override
  String get maps_offline_cancelDownload => 'Cancelar Download';

  @override
  String get maps_offline_clearAll => 'Limpar Tudo';

  @override
  String get maps_offline_clearAllCache => 'Limpar Todo o Cache';

  @override
  String get maps_offline_clearAllCacheMessage =>
      'Excluir todas as regioes de mapa baixadas e tiles em cache?';

  @override
  String get maps_offline_clearAllCacheTitle => 'Limpar Todo o Cache?';

  @override
  String maps_offline_clearCacheStats(Object count, Object size) {
    return 'Isto excluira $count tiles ($size).';
  }

  @override
  String get maps_offline_created => 'Criado';

  @override
  String maps_offline_deleteRegion(Object name) {
    return 'Excluir regiao $name';
  }

  @override
  String maps_offline_deleteRegionMessage(
    Object name,
    Object count,
    Object size,
  ) {
    return 'Excluir \"$name\" e seus $count tiles em cache?\n\nIsto liberara $size de armazenamento.';
  }

  @override
  String get maps_offline_deleteRegionTitle => 'Excluir Regiao?';

  @override
  String get maps_offline_downloadNewRegion => 'Baixar nova regiao';

  @override
  String get maps_offline_downloadedRegions => 'Regioes Baixadas';

  @override
  String maps_offline_downloading(Object regionName) {
    return 'Baixando: $regionName';
  }

  @override
  String maps_offline_downloadingAccessibility(
    Object regionName,
    Object percent,
    Object downloaded,
    Object total,
  ) {
    return 'Baixando $regionName, $percent por cento concluido, $downloaded de $total tiles';
  }

  @override
  String maps_offline_error(Object error) {
    return 'Erro: $error';
  }

  @override
  String maps_offline_errorLoadingStats(Object error) {
    return 'Erro ao carregar estatisticas: $error';
  }

  @override
  String maps_offline_failedTiles(Object count) {
    return '$count falharam';
  }

  @override
  String maps_offline_hitRate(Object rate) {
    return 'Taxa de Acerto: $rate%';
  }

  @override
  String get maps_offline_lastAccessed => 'Ultimo Acesso';

  @override
  String get maps_offline_noRegions => 'Nenhuma Regiao Offline';

  @override
  String get maps_offline_noRegionsDescription =>
      'Baixe regioes de mapa na pagina de detalhes do local para usar mapas offline.';

  @override
  String get maps_offline_refresh => 'Atualizar';

  @override
  String get maps_offline_region => 'Regiao';

  @override
  String maps_offline_regionInfo(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size | $count tiles | Zoom $minZoom-$maxZoom';
  }

  @override
  String maps_offline_regionSubtitle(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size, $count tiles, zoom $minZoom a $maxZoom';
  }

  @override
  String get maps_offline_size => 'Tamanho';

  @override
  String get maps_offline_tiles => 'Tiles';

  @override
  String maps_offline_tilesPerSecond(Object rate) {
    return '$rate tiles/seg';
  }

  @override
  String maps_offline_tilesProgress(Object downloaded, Object total) {
    return '$downloaded / $total tiles';
  }

  @override
  String get maps_offline_title => 'Mapas Offline';

  @override
  String get maps_offline_zoomRange => 'Intervalo de Zoom';

  @override
  String get maps_regionSelector_dragToAdjust =>
      'Arraste para ajustar a selecao';

  @override
  String get maps_regionSelector_dragToSelect =>
      'Arraste no mapa para selecionar uma regiao';

  @override
  String get maps_regionSelector_selectRegion => 'Selecionar regiao no mapa';

  @override
  String get maps_regionSelector_selectRegionButton => 'Selecionar Regiao';

  @override
  String get tankPresets_addPreset => 'Adicionar preset de cilindro';

  @override
  String get tankPresets_builtInPresets => 'Presets Integrados';

  @override
  String get tankPresets_currentDefault => 'Padrão atual';

  @override
  String get tankPresets_customPresets => 'Presets Personalizados';

  @override
  String get tankPresets_defaultSettings => 'Cilindro padrão';

  @override
  String get tankPresets_defaultSettings_description =>
      'O preset marcado com estrela é usado como cilindro padrão ao registrar novos mergulhos.';

  @override
  String tankPresets_deleteDefaultMessage(String name) {
    return 'Tem certeza de que deseja excluir \"$name\"? Este é seu preset de cilindro padrão atual e será redefinido para AL80.';
  }

  @override
  String tankPresets_deleteMessage(Object name) {
    return 'Tem certeza que deseja excluir \"$name\"?';
  }

  @override
  String get tankPresets_deletePreset => 'Excluir preset';

  @override
  String get tankPresets_deleteTitle => 'Excluir Preset de Cilindro?';

  @override
  String tankPresets_deleted(Object name) {
    return '\"$name\" excluido';
  }

  @override
  String get tankPresets_editPreset => 'Editar preset';

  @override
  String tankPresets_edit_created(Object name) {
    return '\"$name\" criado';
  }

  @override
  String get tankPresets_edit_descriptionHint =>
      'ex., Meu cilindro alugado da loja de mergulho';

  @override
  String get tankPresets_edit_descriptionOptional => 'Descricao (opcional)';

  @override
  String tankPresets_edit_errorLoading(Object error) {
    return 'Erro ao carregar preset: $error';
  }

  @override
  String tankPresets_edit_errorSaving(Object error) {
    return 'Erro ao salvar preset: $error';
  }

  @override
  String tankPresets_edit_gasCapacity(Object capacity) {
    return '- Capacidade de gas: $capacity cuft';
  }

  @override
  String get tankPresets_edit_material => 'Material';

  @override
  String get tankPresets_edit_name => 'Nome';

  @override
  String get tankPresets_edit_nameHelper =>
      'Um nome amigavel para este preset de cilindro';

  @override
  String get tankPresets_edit_nameHint => 'ex., Meu AL80';

  @override
  String get tankPresets_edit_nameRequired => 'Por favor, insira um nome';

  @override
  String get tankPresets_edit_ratedPressure => 'Pressao nominal';

  @override
  String get tankPresets_edit_required => 'Obrigatorio';

  @override
  String get tankPresets_edit_tankSpecifications =>
      'Especificacoes do Cilindro';

  @override
  String get tankPresets_edit_title => 'Editar Preset de Cilindro';

  @override
  String tankPresets_edit_updated(Object name) {
    return '\"$name\" atualizado';
  }

  @override
  String get tankPresets_edit_validPressure => 'Insira uma pressao valida';

  @override
  String get tankPresets_edit_validVolume => 'Insira um volume valido';

  @override
  String get tankPresets_edit_volume => 'Volume';

  @override
  String get tankPresets_edit_volumeHelperCuft => 'Capacidade de gas (cuft)';

  @override
  String get tankPresets_edit_volumeHelperLiters => 'Volume de agua (L)';

  @override
  String tankPresets_edit_waterVolume(Object volume) {
    return '- Volume de agua: $volume L';
  }

  @override
  String get tankPresets_edit_workingPressure => 'Pressao de Trabalho';

  @override
  String tankPresets_edit_workingPressureBar(Object pressure) {
    return '- Pressao de trabalho: $pressure bar';
  }

  @override
  String tankPresets_error(Object error) {
    return 'Erro: $error';
  }

  @override
  String tankPresets_errorDeleting(Object error) {
    return 'Erro ao excluir preset: $error';
  }

  @override
  String get tankPresets_applyToImports =>
      'Aplicar também a mergulhos importados';

  @override
  String get tankPresets_applyToImports_subtitle =>
      'Preencher dados de cilindro ausentes em mergulhos importados usando o preset padrão';

  @override
  String get tankPresets_new_title => 'Novo Preset de Cilindro';

  @override
  String get tankPresets_noPresets => 'Nenhum preset de cilindro disponivel';

  @override
  String get tankPresets_setAsDefault => 'Definir como padrão';

  @override
  String get tankPresets_title => 'Presets de Cilindro';

  @override
  String get tools_gpsLogger_description =>
      'Grave sua posição durante um dia de mergulho e associe automaticamente os mergulhos importados a localizações GPS.';

  @override
  String get tools_gpsLogger_subtitle => 'Grave uma trilha de superfície';

  @override
  String get tools_gpsLogger_title => 'Registrador GPS';

  @override
  String get tools_weight_aluminumImperial =>
      'Mais flutuante quando vazio (+4 lbs)';

  @override
  String get tools_weight_aluminumMetric =>
      'Mais flutuante quando vazio (+2 kg)';

  @override
  String get tools_weight_bodyWeightOptional => 'Peso Corporal (opcional)';

  @override
  String get tools_weight_carbonFiberImperial => 'Muito flutuante (+7 lbs)';

  @override
  String get tools_weight_carbonFiberMetric => 'Muito flutuante (+3 kg)';

  @override
  String get tools_weight_disclaimer =>
      'Isto e apenas uma estimativa. Sempre faca uma verificacao de flutuabilidade no inicio do mergulho e ajuste conforme necessario. Fatores como colete, flutuabilidade pessoal e padroes respiratorios afetarao os seus requisitos reais de lastro.';

  @override
  String get tools_weight_exposureSuit => 'Roupa de Mergulho';

  @override
  String tools_weight_gasCapacity(Object capacity) {
    return '- Capacidade de gas: $capacity cuft';
  }

  @override
  String get tools_weight_helperImperial =>
      'Adiciona ~2 lbs por 22 lbs acima de 154 lbs';

  @override
  String get tools_weight_helperMetric =>
      'Adiciona ~1 kg por 10 kg acima de 70 kg';

  @override
  String get tools_weight_notSpecified => 'Nao especificado';

  @override
  String get tools_weight_recommendedWeight => 'Lastro Recomendado';

  @override
  String tools_weight_resultAccessibility(Object weight, Object unit) {
    return 'Lastro recomendado: $weight $unit';
  }

  @override
  String get tools_weight_steelImperial => 'Flutuabilidade negativa (-4 lbs)';

  @override
  String get tools_weight_steelMetric => 'Flutuabilidade negativa (-2 kg)';

  @override
  String get tools_weight_tankMaterial => 'Material do Cilindro';

  @override
  String get tools_weight_tankSpecifications => 'Especificacoes do Cilindro';

  @override
  String get tools_weight_title => 'Calculadora de Lastro';

  @override
  String get tools_weight_waterType => 'Tipo de Agua';

  @override
  String tools_weight_waterVolume(Object volume) {
    return '- Volume de agua: $volume L';
  }

  @override
  String tools_weight_workingPressure(Object pressure) {
    return '- Pressao de trabalho: $pressure bar';
  }

  @override
  String get tools_weight_yourWeight => 'Seu peso';

  @override
  String get settings_section_dataSources_title => 'Data Sources';

  @override
  String get settings_section_dataSources_subtitle =>
      'Connected services & integrations';

  @override
  String get settings_siteMatch_title => 'Associação automática de pontos';

  @override
  String get settings_siteMatch_subtitle =>
      'Com que intensidade os mergulhos baixados são associados aos pontos';

  @override
  String get settings_siteMatch_strict => 'Rigoroso';

  @override
  String get settings_siteMatch_balanced => 'Equilibrado';

  @override
  String get settings_siteMatch_relaxed => 'Flexível';

  @override
  String get settings_dataSources_header => 'Data Sources';

  @override
  String get settings_dataSources_appleHealth_title => 'Apple Health';

  @override
  String get settings_dataSources_appleHealth_subtitle =>
      'Dados de mergulho subaquatico';

  @override
  String get settings_dataSources_appleHealth_description =>
      'Submersion reads underwater diving workout data from Apple Health, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get settings_dataSources_appleHealth_dataTypesHeader =>
      'Dados lidos do HealthKit';

  @override
  String get settings_dataSources_appleHealth_dataTypeWorkouts =>
      'Treinos de mergulho subaquatico - hora de inicio, duracao e dados de atividade do mergulho';

  @override
  String get settings_dataSources_appleHealth_dataTypeHeartRate =>
      'Frequencia cardiaca - amostras de frequencia cardiaca registradas durante os mergulhos';

  @override
  String get settings_dataSources_appleHealth_permissionGranted =>
      'Acesso ao HealthKit concedido';

  @override
  String get settings_dataSources_appleHealth_permissionNotGranted =>
      'Acesso ao HealthKit nao concedido';

  @override
  String get settings_dataSources_appleHealth_permissionChecking =>
      'Verificando acesso ao HealthKit...';

  @override
  String get settings_dataSources_appleHealth_importAction =>
      'Import from Apple Watch';

  @override
  String get settings_dataSources_appleHealth_privacy =>
      'Your health data is stored locally and is never shared with third parties.';

  @override
  String get settings_dataSources_appleHealth_poweredBy =>
      'Fornecido por Apple HealthKit';

  @override
  String get settings_dataSources_noSources =>
      'No data source integrations are available on this platform.';

  @override
  String get diveLog_edit_section_environment => 'Ambiente';

  @override
  String get diveLog_edit_subsection_autofill => 'Preenchimento automático';

  @override
  String get diveLog_edit_subsection_weather => 'Clima';

  @override
  String get diveLog_edit_subsection_diveConditions => 'Condições de mergulho';

  @override
  String get diveLog_edit_label_windSpeed => 'Velocidade do vento';

  @override
  String get diveLog_edit_label_windDirection => 'Direção do vento';

  @override
  String get diveLog_edit_label_cloudCover => 'Cobertura de nuvens';

  @override
  String get diveLog_edit_label_precipitation => 'Precipitação';

  @override
  String get diveLog_edit_label_humidity => 'Umidade';

  @override
  String get diveLog_edit_label_weatherDescription => 'Descrição do clima';

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
  String get diveLog_detail_section_environment => 'Ambiente';

  @override
  String get diveLog_detail_subsection_weather => 'Clima';

  @override
  String get diveLog_detail_subsection_diveConditions =>
      'Condições de mergulho';

  @override
  String get diveLog_detail_label_windSpeed => 'Velocidade do vento';

  @override
  String get diveLog_detail_label_windDirection => 'Direção do vento';

  @override
  String get diveLog_detail_label_cloudCover => 'Cobertura de nuvens';

  @override
  String get diveLog_detail_label_precipitation => 'Precipitação';

  @override
  String get diveLog_detail_label_humidity => 'Umidade';

  @override
  String get diveLog_detail_label_weatherDescription => 'Descrição';

  @override
  String get diveLog_detail_weatherSourceOpenMeteo => 'via Open-Meteo';

  @override
  String get dropTarget_title => 'Solte para importar';

  @override
  String get dropTarget_subtitle =>
      'Solte para abrir o assistente de importação';

  @override
  String get dropTarget_error_unsupportedFile =>
      'Tipo de arquivo não suportado';

  @override
  String get dropTarget_error_wizardActive =>
      'Conclua a importação atual primeiro';

  @override
  String get dropTarget_error_readFailed => 'Não foi possível ler o arquivo';

  @override
  String get enum_cloudCover_clear => 'Limpo';

  @override
  String get enum_cloudCover_partlyCloudy => 'Parcialmente nublado';

  @override
  String get enum_cloudCover_mostlyCloudy => 'Predominantemente nublado';

  @override
  String get enum_cloudCover_overcast => 'Encoberto';

  @override
  String get enum_precipitation_none => 'Nenhuma';

  @override
  String get enum_precipitation_drizzle => 'Chuvisco';

  @override
  String get enum_precipitation_lightRain => 'Chuva fraca';

  @override
  String get enum_precipitation_rain => 'Chuva';

  @override
  String get enum_precipitation_heavyRain => 'Chuva forte';

  @override
  String get enum_precipitation_snow => 'Neve';

  @override
  String get enum_precipitation_sleet => 'Granizo miúdo';

  @override
  String get enum_precipitation_hail => 'Granizo';

  @override
  String get columnConfig_title => 'Campos da lista de detalhes de mergulhos';

  @override
  String get columnConfig_viewMode => 'Modo de visualização';

  @override
  String get columnConfig_visibleColumns => 'Colunas visíveis';

  @override
  String get columnConfig_availableFields => 'Campos disponíveis';

  @override
  String get columnConfig_extraFields => 'Campos extras';

  @override
  String get columnConfig_extraFields_description =>
      'Exibidos abaixo do conteúdo principal do cartão';

  @override
  String get columnConfig_slotAssignments => 'Atribuições de posições';

  @override
  String get columnConfig_resetToDefault => 'Redefinir para o padrão';

  @override
  String get columnConfig_preset => 'Predefinição';

  @override
  String get columnConfig_presetSaveAs => 'Salvar como';

  @override
  String get columnConfig_presetName => 'Nome da predefinição';

  @override
  String get columnConfig_presetNameHint => 'ex.: Mergulho técnico';

  @override
  String get columnConfig_presetSave => 'Salvar';

  @override
  String get columnConfig_presetCancel => 'Cancelar';

  @override
  String get columnConfig_columns => 'Colunas';

  @override
  String get columnConfig_done => 'Concluído';

  @override
  String get settings_appearance_columnConfig =>
      'Campos da lista de detalhes de mergulhos';

  @override
  String get settings_appearance_columnConfig_subtitle =>
      'Personalizar os campos exibidos nas visualizações de lista de mergulhos';

  @override
  String get diveField_category_core => 'Essencial';

  @override
  String get diveField_category_environment => 'Ambiente';

  @override
  String get diveField_category_gas => 'Gás';

  @override
  String get diveField_category_tank => 'Cilindro';

  @override
  String get diveField_category_weight => 'Lastro';

  @override
  String get diveField_category_equipment => 'Equipamento';

  @override
  String get diveField_category_deco => 'Descompressão';

  @override
  String get diveField_category_physiology => 'Fisiologia';

  @override
  String get diveField_category_rebreather => 'Rebreather';

  @override
  String get diveField_category_people => 'Pessoas';

  @override
  String get diveField_category_location => 'Localização';

  @override
  String get diveField_category_trip => 'Viagem';

  @override
  String get diveField_category_rating => 'Avaliação';

  @override
  String get diveField_category_metadata => 'Metadados';

  @override
  String get listViewMode_table => 'Tabela';

  @override
  String get settings_appearance_general => 'Geral';

  @override
  String get settings_appearance_sections => 'Seções';

  @override
  String get settings_appearance_colorAccents => 'Acentos de cor';

  @override
  String get settings_appearance_accentNavIcons =>
      'Ícones de navegação coloridos';

  @override
  String get settings_appearance_accentNavIcons_subtitle =>
      'Colorir os ícones do menu principal com a cor de cada seção';

  @override
  String get settings_appearance_accentSectionHeaders =>
      'Cabeçalhos de seção coloridos';

  @override
  String get settings_appearance_accentSectionHeaders_subtitle =>
      'Mostrar um ícone de seção colorido ao lado dos títulos das páginas';

  @override
  String get settings_appearance_accentListIcons => 'Ícones de lista coloridos';

  @override
  String get settings_appearance_accentListIcons_subtitle =>
      'Colorir os ícones nas listas e nas páginas de configurações';

  @override
  String get settings_appearance_showDetailsPane =>
      'Mostrar painel de detalhes';

  @override
  String get settings_appearance_showDetailsPane_subtitle =>
      'Exibir painel de detalhes ao lado da tabela';

  @override
  String get settings_appearance_showProfilePanel =>
      'Mostrar painel de perfil na visualização de tabela';

  @override
  String get settings_appearance_showProfilePanel_subtitle =>
      'Exibir gráfico de perfil de mergulho acima da tabela por padrão';

  @override
  String get settings_appearance_mapStyle => 'Estilo do Mapa';

  @override
  String get settings_appearance_mapStyle_openStreetMap => 'Mapa de Ruas';

  @override
  String get settings_appearance_mapStyle_openTopoMap => 'Topográfico';

  @override
  String get settings_appearance_mapStyle_esriSatellite => 'Satélite';

  @override
  String get common_action_reparse => 'Reanalisar';

  @override
  String get diveComputer_detail_reparseAllButton =>
      'Reanalisar todos os mergulhos';

  @override
  String get diveComputer_detail_reparseAllTitle =>
      'Reanalisar todos os mergulhos';

  @override
  String diveComputer_detail_reparseAllMessage(int count) {
    return 'Reexecute o analisador de mergulhos em $count mergulhos com dados brutos armazenados. Isso atualiza os dados de perfil e de sensores, mas preserva suas notas, locais, parceiros e outras edições.';
  }

  @override
  String diveComputer_detail_reparseAllProgress(int count) {
    return 'Reanalisando $count mergulhos...';
  }

  @override
  String diveComputer_detail_reparseAllSuccess(int count) {
    return '$count mergulhos reanalisados com sucesso';
  }

  @override
  String diveComputer_detail_reparseAllPartial(
    int succeeded,
    int total,
    int failed,
  ) {
    return 'Reanalisados $succeeded de $total mergulhos. $failed falharam.';
  }

  @override
  String diveComputer_detail_reparseRawDataCount(int count) {
    return '$count mergulhos com dados brutos';
  }

  @override
  String diveComputer_detail_reparseRawDataCountWithout(
    int count,
    int without,
  ) {
    return '$count mergulhos com dados brutos ($without sem)';
  }

  @override
  String get diveLog_detail_menu_reparseRawData => 'Reanalisar dados brutos';

  @override
  String get diveLog_detail_reparseSuccess =>
      'Mergulho reanalisado com sucesso';

  @override
  String get diveLog_detail_reparseProfilePreserved =>
      'Detalhes da fonte atualizados. Este mergulho foi combinado a partir de outros mergulhos, por isso o seu perfil não foi alterado.';

  @override
  String diveLog_detail_reparseFailed(String error) {
    return 'Falha na reanálise: $error';
  }

  @override
  String get universalImport_label_replaceSource => 'Substituir Fonte';

  @override
  String get universalImport_label_replaceSourceSubtitle =>
      'Atualizar a partir do mesmo computador';

  @override
  String get universalImport_title_importOptions => 'Opções de Importação';

  @override
  String get universalImport_label_options => 'Opções';

  @override
  String get universalImport_label_retainDiveNumbers =>
      'Manter números de mergulho da origem';

  @override
  String get universalImport_label_retainDiveNumbersSubtitle =>
      'Usar os números de mergulho do arquivo importado em vez de atribuí-los automaticamente';

  @override
  String get universalImport_title_successImported => 'Importados com Sucesso';

  @override
  String get universalImport_title_successUpdated => 'Atualizados com Sucesso';

  @override
  String get universalImport_title_successConsolidated =>
      'Consolidados com Sucesso';

  @override
  String get universalImport_title_noDivesImported =>
      'Nenhum Mergulho Importado';

  @override
  String get universalImport_label_allDivesSkipped =>
      'Todos os mergulhos foram ignorados.';

  @override
  String get universalImport_label_replacedSourceData =>
      'Dados de origem substituídos';

  @override
  String get universalImport_label_consolidated => 'Consolidados';

  @override
  String get universalImport_label_photosAttached => 'Fotos anexadas';

  @override
  String get universalImport_label_photosUnmatched =>
      'Fotos sem mergulho correspondente';

  @override
  String get common_label_shareWithAllProfiles =>
      'Partilhar com todos os perfis de mergulho';

  @override
  String get settings_shareByDefault_title =>
      'Partilhar novos locais e viagens por predefinição';

  @override
  String get settings_shareAllSites_title => 'Partilhar todos os meus locais';

  @override
  String get settings_shareAllTrips_title =>
      'Partilhar todas as minhas viagens';

  @override
  String settings_shareAllSites_confirm(int count) {
    return 'Tornar os teus $count locais visíveis a todos os perfis de mergulho desta app? Poderás deixar de partilhar locais individuais mais tarde.';
  }

  @override
  String settings_shareAllTrips_confirm(int count) {
    return 'Tornar as tuas $count viagens visíveis a todos os perfis de mergulho desta app? Poderás deixar de partilhar viagens individuais mais tarde.';
  }

  @override
  String settings_shareAllSites_snackbar(int count) {
    return '$count locais partilhados com todos os perfis de mergulho.';
  }

  @override
  String settings_shareAllTrips_snackbar(int count) {
    return '$count viagens partilhadas com todos os perfis de mergulho.';
  }

  @override
  String get settings_shareAll_noneToShare => 'Nada para partilhar.';

  @override
  String get settings_sharedData_sectionTitle => 'Dados partilhados';

  @override
  String get settings_sharedData_sectionSubtitle =>
      'Partilhar locais e viagens entre perfis';

  @override
  String get common_action_unshare => 'Deixar de partilhar';

  @override
  String get trips_unshareConfirm_title => 'Deixar de partilhar esta viagem?';

  @override
  String trips_unshareConfirm_body(String name) {
    return 'Isto irá remover «$name» das vistas dos outros perfis de mergulho. Poderás voltar a partilhar mais tarde.';
  }

  @override
  String get sites_unshareConfirm_title => 'Deixar de partilhar este local?';

  @override
  String sites_unshareConfirm_body(String name) {
    return 'Isto irá remover «$name» das vistas dos outros perfis de mergulho. Poderás voltar a partilhar mais tarde.';
  }

  @override
  String get trips_deleteShared_title => 'Eliminar viagem partilhada?';

  @override
  String trips_deleteShared_body(String name) {
    return '«$name» está partilhada com outros perfis de mergulho. Eliminá-la aqui remove-a para todos.';
  }

  @override
  String get sites_deleteShared_title => 'Eliminar local partilhado?';

  @override
  String sites_deleteShared_body(String name) {
    return '«$name» está partilhado com outros perfis de mergulho. Eliminá-lo aqui remove-o para todos.';
  }

  @override
  String divers_delete_reassigned_snackbar(int trips, int sites, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      trips,
      locale: localeName,
      other: 'viagens partilhadas',
      one: 'viagem partilhada',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sites,
      locale: localeName,
      other: 'locais partilhados',
      one: 'local partilhado',
    );
    return 'Mergulhador eliminado. $trips $_temp0 e $sites $_temp1 reatribuídos a $name.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_title =>
      'Perfis de mergulhador duplicados';

  @override
  String get settings_cloudSync_duplicateDivers_description =>
      'A sincronização encontrou mais de um perfil com o mesmo nome. Isso acontece normalmente quando cada dispositivo criou o seu próprio perfil antes de sincronizar. A fusão move todos os mergulhos e dados para um único perfil.';

  @override
  String settings_cloudSync_duplicateDivers_groupLabel(String name, int count) {
    return '$name ($count perfis)';
  }

  @override
  String get settings_cloudSync_duplicateDivers_mergeButton => 'Mesclar';

  @override
  String get settings_cloudSync_duplicateDivers_confirmTitle =>
      'Mesclar perfis de mergulhador?';

  @override
  String settings_cloudSync_duplicateDivers_confirmBody(
    int count,
    String name,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perfis duplicados',
      one: 'um perfil duplicado',
    );
    return 'Todos os mergulhos, certificações, equipamento e outros dados de $_temp0 serão movidos para \"$name\". Esta ação não pode ser desfeita automaticamente.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_confirmCancel => 'Cancelar';

  @override
  String get settings_cloudSync_duplicateDivers_confirmAction => 'Mesclar';

  @override
  String settings_cloudSync_duplicateDivers_successSnack(String name) {
    return 'Mesclado em $name';
  }

  @override
  String settings_cloudSync_duplicateDivers_failureSnack(String error) {
    return 'Falha ao mesclar: $error';
  }

  @override
  String get settings_cloudSync_duplicateDivers_undo => 'Desfazer';

  @override
  String get divers_edit_priorExperienceSection => 'Experiência Anterior';

  @override
  String get divers_edit_priorExperienceHelp =>
      'Mergulhos e tempo de antes de começar a registar no Submersion.';

  @override
  String get divers_edit_priorDivesLabel => 'Mergulhos anteriores';

  @override
  String get divers_edit_priorHoursLabel => 'Horas anteriores';

  @override
  String get divers_edit_priorMinutesLabel => 'Minutos';

  @override
  String get divers_edit_divingSinceLabel => 'Mergulha desde';

  @override
  String get divers_edit_divingSinceNotSet => 'Não definido';

  @override
  String get divers_edit_clearDivingSinceTooltip => 'Limpar mergulha desde';

  @override
  String get divers_edit_priorInvalidNumber => 'Introduza um número válido';

  @override
  String statistics_priorBreakdown(String logged, String prior) {
    return '$logged registados + $prior anteriores';
  }

  @override
  String statistics_divingSince(int year) {
    return 'Mergulha desde $year';
  }

  @override
  String get db_location_choose_volume => 'Escolher local de armazenamento';

  @override
  String get db_location_internal => 'Armazenamento interno';

  @override
  String get db_location_sd_card => 'Cartão SD';

  @override
  String get db_location_external_note =>
      'Os arquivos aqui são removidos se você desinstalar o aplicativo.';

  @override
  String get db_location_backup_note =>
      'O Android não consegue executar o banco de dados a partir de uma pasta sincronizada na nuvem. Para manter uma cópia no Dropbox, Nextcloud ou Google Drive, defina o Local do Backup em Backup e Restauração.';

  @override
  String diveLog_bulkEdit_membership_onAll(int count) {
    return 'em todos os $count';
  }

  @override
  String diveLog_bulkEdit_membership_onSome(int count, int total) {
    return 'em $count de $total';
  }

  @override
  String diveLog_bulkEdit_membership_adding(int total) {
    return 'adicionando a todos os $total';
  }

  @override
  String get diveLog_bulkEdit_membership_removing => 'removendo de todos';

  @override
  String get diveLog_bulkEdit_membership_empty =>
      'Ainda não há itens nos mergulhos selecionados';

  @override
  String get settings_mediaStorage_entry_title => 'Armazenamento de mídia';

  @override
  String get settings_mediaStorage_entry_subtitle =>
      'Guarde os originais de fotos e vídeos no seu próprio armazenamento em nuvem';

  @override
  String get settings_mediaStorage_status_notConfigured =>
      'Nenhum armazenamento de mídia conectado neste dispositivo';

  @override
  String settings_mediaStorage_status_connected(String hint) {
    return 'Conectado a $hint';
  }

  @override
  String get settings_mediaStorage_test_success => 'Conexão bem-sucedida';

  @override
  String get settings_mediaStorage_saved => 'Armazenamento de mídia conectado';

  @override
  String get settings_mediaStorage_action_disconnect => 'Desconectar';

  @override
  String get settings_mediaStorage_disconnect_confirm_title =>
      'Desconectar o armazenamento de mídia?';

  @override
  String get settings_mediaStorage_disconnect_confirm_body =>
      'Este dispositivo deixa de enviar e buscar mídia. Nada é excluído do seu bucket.';

  @override
  String get settings_mediaStorage_action_copyFromSync =>
      'Copiar configurações do Sync';

  @override
  String get settings_mediaStorage_transfers_title => 'Transferências';

  @override
  String get settings_mediaStorage_transfers_entry => 'Ver transferências';

  @override
  String get settings_mediaStorage_transfers_empty => 'Sem transferências';

  @override
  String get settings_mediaStorage_transfers_retry => 'Tentar novamente';

  @override
  String get settings_mediaStorage_transfers_clearCompleted =>
      'Limpar concluídas';

  @override
  String get settings_mediaStorage_transfers_state_pending => 'Aguardando';

  @override
  String get settings_mediaStorage_transfers_state_transferring => 'Enviando';

  @override
  String get settings_mediaStorage_transfers_state_deleting =>
      'Removendo da nuvem';

  @override
  String get settings_mediaStorage_transfers_state_done => 'Concluído';

  @override
  String get settings_mediaStorage_transfers_state_failed => 'Falhou';

  @override
  String settings_mediaStorage_transfers_queued(int count) {
    return '$count na fila';
  }

  @override
  String settings_mediaStorage_transfers_waitingRetry(int count) {
    return '$count aguardando nova tentativa';
  }

  @override
  String get settings_mediaStorage_verify_action => 'Verificar biblioteca';

  @override
  String get settings_mediaStorage_verify_running =>
      'Verificando a biblioteca de mídia...';

  @override
  String settings_mediaStorage_verify_summary(
    int checked,
    int removed,
    int repaired,
    int aborted,
  ) {
    return '$checked objetos verificados: $removed órfãos removidos, $repaired reparos na fila, $aborted envios obsoletos cancelados';
  }

  @override
  String get settings_mediaStorage_backfill_action =>
      'Enviar biblioteca existente';

  @override
  String settings_mediaStorage_backfill_enqueued(int count) {
    return '$count envios na fila';
  }

  @override
  String get settings_mediaStorage_policy_autoUpload =>
      'Enviar fotos automaticamente';

  @override
  String get settings_mediaStorage_policy_photosOnCellular =>
      'Enviar fotos pela rede móvel';

  @override
  String get settings_mediaStorage_provider_label => 'Provedor';

  @override
  String get settings_mediaStorage_connect_dropbox_hint =>
      'Usa sua conexão do Dropbox da sincronização na nuvem. As mídias ficam na pasta do app no Dropbox.';

  @override
  String get settings_mediaStorage_connect_gdrive_hint =>
      'Entra com o Google. As mídias ficam no espaço privado do Drive deste app.';

  @override
  String get settings_mediaStorage_connect_icloud_hint =>
      'As mídias ficam no contêiner do iCloud deste app e sincronizam pelo seu ID Apple.';

  @override
  String settings_mediaStorage_connect_action(String provider) {
    return 'Conectar $provider';
  }

  @override
  String get bodyWeight_addEntry => 'Adicionar medição';

  @override
  String get bodyWeight_dateLabel => 'Data';

  @override
  String get bodyWeight_deleteTooltip => 'Excluir entrada';

  @override
  String get bodyWeight_heightLabel => 'Altura (cm)';

  @override
  String get bodyWeight_heightFeetLabel => 'Altura (ft)';

  @override
  String get bodyWeight_heightInchesLabel => 'Polegadas';

  @override
  String bodyWeight_weightLabel(String unit) {
    return 'Peso ($unit)';
  }

  @override
  String diveLog_edit_weightFeedback_amount(String unit) {
    return 'Por quanto, aproximadamente ($unit)';
  }

  @override
  String get diveLog_edit_weightFeedback_correct => 'Adequado';

  @override
  String get diveLog_edit_weightFeedback_label => 'Como estava sua lastragem?';

  @override
  String get diveLog_edit_weightFeedback_over => 'Lastro excessivo';

  @override
  String get diveLog_edit_weightFeedback_under => 'Lastro insuficiente';

  @override
  String get diverProfile_bodyWeight_empty => 'Não registrado';

  @override
  String get diverProfile_bodyWeight_title => 'Peso corporal';

  @override
  String get equipment_edit_advanced_title => 'Avançado';

  @override
  String get equipment_edit_buoyancyHint_exposure => 'Positivo: quanto flutua';

  @override
  String get equipment_edit_buoyancyHint_generic => 'Negativo se afunda';

  @override
  String get equipment_edit_buoyancyHint_tank =>
      'Deixe vazio - cilindros usam suas próprias especificações';

  @override
  String equipment_edit_buoyancyLabel(String unit) {
    return 'Flutuabilidade ($unit)';
  }

  @override
  String equipment_edit_dryWeightLabel(String unit) {
    return 'Peso seco ($unit)';
  }

  @override
  String equipment_edit_liftCapacityLabel(String unit) {
    return 'Capacidade de sustentação ($unit)';
  }

  @override
  String get equipment_edit_liftCapacityHint =>
      'Sustentação nominal do wing ou colete';

  @override
  String get planner_gearWeights_accept => 'Usar como lastro planejado';

  @override
  String get planner_gearWeights_addGear => 'Adicionar equipamento';

  @override
  String get planner_gearWeights_empty =>
      'Adicione equipamento para prever seu lastro';

  @override
  String planner_gearWeights_planned(String weight) {
    return 'Planejado: $weight';
  }

  @override
  String planner_gearWeights_predicted(String weight) {
    return 'Previsto: $weight';
  }

  @override
  String get planner_gearWeights_title => 'Equipamento e lastro';

  @override
  String get planner_gearWeights_useSet => 'Usar conjunto';

  @override
  String get tools_weight_addGear => 'Adicionar equipamento';

  @override
  String get tools_weight_addTank => 'Adicionar cilindro';

  @override
  String tools_weight_basedOnDives(int count) {
    return 'Com base em $count mergulhos registrados';
  }

  @override
  String get tools_weight_breakdownTitle => 'Como isso foi calculado';

  @override
  String get tools_weight_confidence_high => 'Alta confiança';

  @override
  String get tools_weight_confidence_low => 'Baixa confiança - estimativa';

  @override
  String get tools_weight_confidence_medium => 'Confiança média';

  @override
  String tools_weight_deltaVsPrevious(String delta) {
    return '$delta em relação ao conjunto anterior';
  }

  @override
  String get tools_weight_noGear =>
      'Adicione o equipamento com que vai mergulhar para personalizar a previsão.';

  @override
  String get tools_weight_personalTerm => 'Base pessoal';

  @override
  String get tools_weight_placementTitle => 'Distribuição sugerida';

  @override
  String get tools_weight_predictedWeight => 'Lastro previsto';

  @override
  String get tools_weight_saveToProfile => 'Salvar peso no perfil';

  @override
  String get tools_weight_source_measured => 'medido dos seus mergulhos';

  @override
  String get tools_weight_source_physics => 'física';

  @override
  String get tools_weight_source_typeDefault => 'estimativa padrão';

  @override
  String get tools_weight_source_userSpec =>
      'das especificações do seu equipamento';

  @override
  String get tools_weight_tanks => 'Cilindros';

  @override
  String get tools_weight_useSet => 'Usar conjunto';

  @override
  String get tools_weight_waterTerm => 'Tipo de água';

  @override
  String get dive3d_previewTitle => 'Visualização 3D';

  @override
  String get dive3d_previewHint => 'Toque para explorar em 3D';

  @override
  String get dive3d_resetView => 'Redefinir visualização';

  @override
  String get dive3d_zoomIn => 'Ampliar';

  @override
  String get dive3d_zoomOut => 'Reduzir';

  @override
  String get dive3d_play => 'Reproduzir';

  @override
  String get dive3d_pause => 'Pausar';

  @override
  String get dive3d_overlays => 'Sobreposições';

  @override
  String get dive3d_overlay_strata => 'Camadas de temperatura';

  @override
  String get dive3d_overlay_ceiling => 'Teto de deco';

  @override
  String get dive3d_overlay_curtain => 'Cortina de profundidade';

  @override
  String get dive3d_overlay_markers => 'Marcadores';

  @override
  String get dive3d_seascape_overlay_paths => 'Trajetos de mergulho';

  @override
  String get dive3d_seascape_overlay_contours => 'Isóbatas';

  @override
  String get dive3d_seascape_overlay_walls => 'Paredes íngremes';

  @override
  String get dive3d_overlay_water => 'Superfície da água';

  @override
  String get dive3d_seascape_legend_land => 'Terra';

  @override
  String get dive3d_seascape_appearance => 'Aparência do terreno';

  @override
  String get dive3d_seascape_chartView => 'Vista de carta';

  @override
  String get dive3d_seascape_orbitView => 'Vista 3D';

  @override
  String get dive3d_seascape_appearance_surface => 'Superfície do terreno';

  @override
  String get dive3d_seascape_appearance_surfaceDepth => 'Cores de profundidade';

  @override
  String get dive3d_seascape_appearance_surfaceImagery => 'Imagens do mapa';

  @override
  String get dive3d_seascape_appearance_surfaceBlend => 'Mistura';

  @override
  String get siteFeature_type_wreck => 'Naufrágio';

  @override
  String get siteFeature_type_mooring => 'Boia de amarração';

  @override
  String get siteFeature_type_entry => 'Ponto de entrada';

  @override
  String get siteFeature_type_exit => 'Ponto de saída';

  @override
  String get siteFeature_type_swimThrough => 'Passagem';

  @override
  String get siteFeature_type_hazard => 'Perigo';

  @override
  String get siteFeature_type_current => 'Correnteza';

  @override
  String get siteFeature_sectionTitle => 'Características';

  @override
  String get siteFeature_addAction => 'Adicionar característica';

  @override
  String get siteFeature_placeHint =>
      'Toque no mapa para posicionar a característica';

  @override
  String get siteFeature_addTitle => 'Adicionar característica';

  @override
  String get siteFeature_editTitle => 'Editar característica';

  @override
  String get siteFeature_field_name => 'Nome';

  @override
  String get siteFeature_field_bearing => 'Rumo (°)';

  @override
  String get siteFeature_field_depth => 'Profundidade';

  @override
  String get siteFeature_field_notes => 'Notas';

  @override
  String get siteFeature_deleteAction => 'Excluir';

  @override
  String siteFeature_deleteConfirm(String name) {
    return 'Excluir $name?';
  }

  @override
  String get siteScape_mode2d => 'Mapa';

  @override
  String get siteScape_mode3d => '3D';

  @override
  String get dive3d_seascape_appearance_rampRange =>
      'Limitar intervalo de profundidade das cores';

  @override
  String get dive3d_seascape_appearance_rampMax => 'Cor mais escura em';

  @override
  String get dive3d_seascape_appearance_banded => 'Gradiente em faixas';

  @override
  String get dive3d_seascape_appearance_contours => 'Níveis de isóbatas';

  @override
  String get dive3d_seascape_appearance_contourAuto => 'Automático';

  @override
  String get dive3d_seascape_appearance_contourCustom => 'Personalizado';

  @override
  String get dive3d_seascape_appearance_addLevel => 'Adicionar nível';

  @override
  String get dive3d_seascape_appearance_defaultColor => 'Padrão';

  @override
  String get dive3d_seascape_appearance_wallAngle => 'Ângulo de parede íngreme';

  @override
  String get dive3d_seascape_appearance_wallAngleNote =>
      'As células batimétricas fazem a média do declive interno, então paredes reais parecem menos íngremes. Mantenha bem abaixo de 45 graus.';

  @override
  String get dive3d_seascape_siteTitle => 'Paisagem marinha do local';

  @override
  String dive3d_seascape_seafloorSource(String source, String resolution) {
    return 'Fundo do mar: $source (~$resolution m)';
  }

  @override
  String get dive3d_seascape_noCoordinates =>
      'Este local não tem coordenadas GPS';

  @override
  String get dive3d_seascape_noData =>
      'Nenhuma batimetria disponível para este local';

  @override
  String dive3d_seascape_axis_distance(String unitSymbol) {
    return 'Distância ($unitSymbol)';
  }

  @override
  String get settings_about_bathymetryCredit =>
      'Dados de batimetria: GMRT (CC BY 4.0) · EMODnet Bathymetry (CC BY 4.0) · NOAA ETOPO 2022';

  @override
  String get dive3d_metric_depth => 'Profundidade';

  @override
  String get dive3d_metric_temperature => 'Temp';

  @override
  String get dive3d_metric_ascentRate => 'Subida';

  @override
  String get dive3d_metric_ppO2 => 'ppO2';

  @override
  String get dive3d_metric_cns => 'SNC';

  @override
  String get dive3d_metric_heartRate => 'FC';

  @override
  String get dive3d_metric_tankPressure => 'Pressão';

  @override
  String get dive3d_zAxis => 'Eixo Z';

  @override
  String get dive3d_zAxis_none => 'Nenhum';

  @override
  String get dive3d_overlay_shadows => 'Sombras nas paredes';

  @override
  String get dive3d_metric_tts => 'TTS';

  @override
  String dive3d_axis_depth(String unitSymbol) {
    return 'Profundidade ($unitSymbol)';
  }

  @override
  String get dive3d_axis_time => 'Tempo de mergulho (min)';

  @override
  String get dive3d_pose_menu => 'Câmera';

  @override
  String get dive3d_pose_default => 'Vista padrão';

  @override
  String get dive3d_pose_front => 'Frente (profundidade vs. tempo)';

  @override
  String get dive3d_pose_side => 'Lado (profundidade vs. métrica)';

  @override
  String get dive3d_pose_top => 'Topo (métrica vs. tempo)';

  @override
  String get dive3d_readout_runTime => 'Tempo de mergulho';

  @override
  String get dive3d_readout_ceiling => 'Teto';

  @override
  String dive3d_readout_tank(int n) {
    return 'Cilindro $n';
  }

  @override
  String get dive3d_scene_dive => 'Mergulho';

  @override
  String get dive3d_scene_tissue => 'Tecidos';

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
  String get dive3d_tissue_surfaceInterval => 'Intervalo de superfície';

  @override
  String get dive3d_career_title => 'Histórico 3D';

  @override
  String get dive3d_career_colorRecency => 'Recência';

  @override
  String get dive3d_career_colorDepth => 'Profundidade';

  @override
  String get dive3d_career_empty => 'Nenhum mergulho com perfis';

  @override
  String get dive3d_spatial_title => 'Paisagem marinha 3D';

  @override
  String get dive3d_spatial_estimatedPath =>
      'Trajeto estimado (navegação estimada)';

  @override
  String get dive3d_spatial_synthesizedSeafloor => 'Fundo do mar sintetizado';

  @override
  String get dive3d_spatial_noPath =>
      'Dados insuficientes para reconstruir o trajeto';

  @override
  String get dive3d_tissue_legendHeight =>
      'Altura e cor: % do limite do valor M';

  @override
  String get dive3d_tissue_legendLimit => 'Plano vermelho = limite de deco';

  @override
  String get dive3d_tissue_legendAxes =>
      'Esq→dir: tempo · Frente→trás: tecidos rápidos→lentos';

  @override
  String get dive3d_tissue_legendDepth => 'Curva azul: sua profundidade';

  @override
  String get dive3d_tissue_onGassing => 'Absorção';

  @override
  String get dive3d_tissue_offGassing => 'Liberação';

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
    return 'Saturação $percent%';
  }

  @override
  String dive3d_tissue_tooltipProgress(int percent) {
    return '$percent% do mergulho';
  }

  @override
  String get dive3d_tissue_stateEquilibrium => 'Equilíbrio';

  @override
  String get dive3d_tissue_statePastMValue => 'Acima do valor M';

  @override
  String get dive3d_tissue_axisTime => 'Tempo';

  @override
  String get dive3d_tissue_axisSaturation => 'Saturação %';

  @override
  String get dive3d_tissue_axisCompartment => 'Compartimento';

  @override
  String get dive3d_compare_computers_title => 'Comparar computadores';

  @override
  String get dive3d_compare_dives_title => 'Comparar mergulhos';

  @override
  String get dive3d_scene_computers => 'Computadores';

  @override
  String get dive3d_compare_layout_sideBySide => 'Lado a lado';

  @override
  String get dive3d_compare_layout_overlay => 'Sobrepor';

  @override
  String get dive3d_compare_empty =>
      'São necessários pelo menos 2 perfis com dados de profundidade para comparar';

  @override
  String dive3d_compare_showing(Object shown, Object total) {
    return 'A mostrar $shown de $total';
  }

  @override
  String get dive3d_compare_setReference => 'Definir como referência';

  @override
  String get diveLog_selection_tooltip_compare3d => 'Comparar em 3D';

  @override
  String get diveLog_sources_compareIn3d => 'Comparar em 3D';

  @override
  String get settings_setup_pendingTitle =>
      'Conclua a configuração deste dispositivo';

  @override
  String settings_setup_mediaStoreAttach(String hint) {
    return 'Conectar armazenamento de mídia ($hint)';
  }

  @override
  String settings_setup_accountSignIn(String label) {
    return 'Entrar em $label';
  }

  @override
  String get settings_setup_dismiss => 'Dispensar';

  @override
  String get settings_photosMedia_title => 'Fotos e mídia';

  @override
  String get settings_photosMedia_subtitle => 'Fontes, armazenamento e contas';

  @override
  String get settings_photosMedia_sourcesHeader => 'De onde vêm as fotos';

  @override
  String get settings_photosMedia_storageHeader =>
      'Onde as cópias são mantidas';

  @override
  String get settings_photosMedia_accountsHeader => 'Contas';

  @override
  String get settings_photosMedia_displayHeader => 'Exibição';

  @override
  String get settings_photosMedia_guidedSetup => 'Configuração guiada';

  @override
  String get settings_photosMedia_photoSources_title =>
      'Biblioteca de fotos e fontes';

  @override
  String get settings_photosMedia_photoSources_subtitle =>
      'Galeria, arquivos e opções de importação';

  @override
  String get settings_photosMedia_networkSources_title => 'Fontes de rede';

  @override
  String get settings_photosMedia_networkSources_subtitle =>
      'URLs e feeds de manifesto (avançado)';

  @override
  String get settings_connectedAccounts_title => 'Contas conectadas';

  @override
  String get settings_connectedAccounts_subtitle =>
      'Logins de nuvem e serviços';

  @override
  String get settings_connectedAccounts_empty =>
      'Nenhuma conta conectada ainda';

  @override
  String get settings_connectedAccounts_status_signedIn => 'Conectado';

  @override
  String get settings_connectedAccounts_status_needsSignIn => 'Requer login';

  @override
  String get settings_connectedAccounts_status_unavailable =>
      'Indisponível neste dispositivo';

  @override
  String get settings_connectedAccounts_disconnectDevice =>
      'Sair neste dispositivo';

  @override
  String get settings_connectedAccounts_removeFromLibrary =>
      'Remover da biblioteca';

  @override
  String get settings_connectedAccounts_removeConfirmTitle => 'Remover conta?';

  @override
  String get settings_connectedAccounts_removeConfirmBody =>
      'A conta é removida de todos os dispositivos sincronizados. Credenciais armazenadas em outros dispositivos não são excluídas.';

  @override
  String get settings_setupGuide_title => 'Configurar fotos e mídia';

  @override
  String get settings_setupGuide_intro =>
      'Conecte de onde vêm suas fotos e onde as cópias são mantidas. Você pode executar isso novamente a qualquer momento.';

  @override
  String get settings_setupGuide_stepSources => 'Fontes de fotos';

  @override
  String get settings_setupGuide_stepSources_desc =>
      'Anexe fotos da sua biblioteca, de arquivos ou do Lightroom.';

  @override
  String get settings_setupGuide_stepStorage => 'Armazenamento de mídia';

  @override
  String get settings_setupGuide_stepStorage_desc =>
      'Mantenha cópias de suas fotos na sua própria nuvem para que todos os dispositivos possam exibi-las.';

  @override
  String get settings_setupGuide_stepSync => 'Sincronização na nuvem';

  @override
  String get settings_setupGuide_stepSync_desc =>
      'Sincronize dados de mergulho entre dispositivos.';

  @override
  String get settings_setupGuide_statusDone => 'Configurado';

  @override
  String get settings_setupGuide_statusTodo => 'Não configurado';

  @override
  String get settings_setupGuide_open => 'Abrir';

  @override
  String get settings_connectedAccounts_loadError =>
      'Não foi possível carregar as contas';

  @override
  String get media_unavailablePlaceholder_volumeOffline => 'Volume não montado';

  @override
  String get media_unavailablePlaceholder_stillFetching =>
      'Ainda a carregar. Toque para tentar novamente.';

  @override
  String get media_unavailablePlaceholder_accessDenied =>
      'Sem acesso à biblioteca de fotos';

  @override
  String get attrLabel_size => 'Tamanho';

  @override
  String get attrLabel_thickness_mm => 'Espessura (mm)';

  @override
  String get attrLabel_suit_style => 'Tipo de roupa';

  @override
  String get attrLabel_shell_material => 'Material externo';

  @override
  String get attrLabel_seal_type => 'Tipo de vedação';

  @override
  String get attrLabel_volume_l => 'Volume';

  @override
  String get attrLabel_working_pressure_bar => 'Pressão de trabalho';

  @override
  String get attrLabel_tank_material => 'Material';

  @override
  String get attrLabel_valve_type => 'Válvula';

  @override
  String get attrLabel_tank_identifier => 'Identificador';

  @override
  String get attrLabel_last_visual_inspection => 'Última inspeção visual';

  @override
  String get attrLabel_last_hydro_test => 'Último teste hidrostático';

  @override
  String get attrLabel_connection => 'Conexão';

  @override
  String get attrLabel_cold_water_rated => 'Adequado para água fria';

  @override
  String get attrLabel_bcd_style => 'Estilo';

  @override
  String get attrLabel_lift_capacity_kg => 'Capacidade de elevação';

  @override
  String get attrLabel_heel_type => 'Calcanhar';

  @override
  String get attrLabel_blade_style => 'Lâmina';

  @override
  String get attrLabel_mount => 'Fixação';

  @override
  String get attrLabel_connectivity => 'Conectividade';

  @override
  String get attrLabel_lens_config => 'Lente';

  @override
  String get attrLabel_prescription => 'Lentes graduadas';

  @override
  String get attrLabel_weight_style => 'Estilo';

  @override
  String get attrLabel_lumens => 'Lúmens';

  @override
  String get attrLabel_beam_type => 'Feixe';

  @override
  String get attrLabel_depth_rating_m => 'Profundidade máxima';

  @override
  String get attrLabel_smb_type => 'Tipo';

  @override
  String get attrLabel_length_m => 'Comprimento';

  @override
  String get attrLabel_reel_type => 'Tipo';

  @override
  String get attrLabel_line_length_m => 'Comprimento da linha';

  @override
  String get attrLabel_blade_material => 'Material da lâmina';

  @override
  String get attrLabel_tip_type => 'Ponta';

  @override
  String get attrLabel_glove_type => 'Tipo';

  @override
  String get attrLabel_sole_type => 'Sola';

  @override
  String get attrLabel_buoyancy_kg => 'Flutuabilidade';

  @override
  String get attrLabel_dry_weight_kg => 'Peso seco';

  @override
  String get attrLabel_unit_type => 'Tipo de unidade';

  @override
  String get attrLabel_mount_configuration => 'Montagem';

  @override
  String get attrLabel_scrubber_type => 'Tipo de cal';

  @override
  String get attrLabel_scrubber_duration_h => 'Duração da cal (h)';

  @override
  String get attrLabel_o2_cell_count => 'Células de O2';

  @override
  String get attrLabel_diluent_cylinder_l => 'Cilindro de diluente';

  @override
  String get attrLabel_o2_cylinder_l => 'Cilindro de O2';

  @override
  String get attrLabel_dpv_style => 'Estilo';

  @override
  String get attrLabel_burn_time_h => 'Autonomia';

  @override
  String get attrLabel_battery_type => 'Bateria';

  @override
  String get attrLabel_battery_capacity_wh => 'Capacidade da bateria (Wh)';

  @override
  String get attrLabel_motor_type => 'Motor';

  @override
  String get attrLabel_speed_mps => 'Velocidade máxima';

  @override
  String get attrChoice_unit_type_eccr => 'CCR eletrónico (eCCR)';

  @override
  String get attrChoice_unit_type_mccr => 'CCR manual (mCCR)';

  @override
  String get attrChoice_unit_type_hccr => 'CCR híbrido (hCCR)';

  @override
  String get attrChoice_unit_type_scr_cmf => 'SCR - fluxo mássico constante';

  @override
  String get attrChoice_unit_type_scr_pascr => 'SCR - adição passiva';

  @override
  String get attrChoice_unit_type_scr_escr => 'SCR - controlo eletrónico';

  @override
  String get attrChoice_mount_configuration_back => 'Montagem dorsal';

  @override
  String get attrChoice_mount_configuration_chest => 'Montagem frontal';

  @override
  String get attrChoice_mount_configuration_sidemount => 'Sidemount';

  @override
  String get attrChoice_scrubber_type_axial => 'Axial';

  @override
  String get attrChoice_scrubber_type_radial => 'Radial';

  @override
  String get attrChoice_suit_style_full => 'Roupa inteira';

  @override
  String get attrChoice_suit_style_shorty => 'Shorty';

  @override
  String get attrChoice_suit_style_two_piece => 'Duas peças';

  @override
  String get attrChoice_suit_style_semi_dry => 'Semisseca';

  @override
  String get attrChoice_shell_material_trilaminate => 'Trilaminado';

  @override
  String get attrChoice_shell_material_neoprene => 'Neoprene';

  @override
  String get attrChoice_shell_material_crushed_neoprene =>
      'Neoprene comprimido';

  @override
  String get attrChoice_shell_material_vulcanized_rubber =>
      'Borracha vulcanizada';

  @override
  String get attrChoice_seal_type_latex => 'Látex';

  @override
  String get attrChoice_seal_type_silicone => 'Silicone';

  @override
  String get attrChoice_seal_type_neoprene => 'Neoprene';

  @override
  String get attrChoice_tank_material_aluminum => 'Alumínio';

  @override
  String get attrChoice_tank_material_steel => 'Aço';

  @override
  String get attrChoice_tank_material_carbon_composite =>
      'Compósito de carbono';

  @override
  String get attrChoice_valve_type_din => 'DIN';

  @override
  String get attrChoice_valve_type_yoke => 'Garra (INT)';

  @override
  String get attrChoice_valve_type_convertible => 'Convertível';

  @override
  String get attrChoice_connection_din => 'DIN';

  @override
  String get attrChoice_connection_yoke => 'Garra (INT)';

  @override
  String get attrChoice_bcd_style_jacket => 'Colete';

  @override
  String get attrChoice_bcd_style_back_inflate => 'Inflagem traseira';

  @override
  String get attrChoice_bcd_style_wing => 'Asa';

  @override
  String get attrChoice_bcd_style_sidemount => 'Sidemount';

  @override
  String get attrChoice_heel_type_open_heel => 'Calcanhar aberto';

  @override
  String get attrChoice_heel_type_full_foot => 'Pé inteiro';

  @override
  String get attrChoice_blade_style_paddle => 'Pá';

  @override
  String get attrChoice_blade_style_split => 'Dividida';

  @override
  String get attrChoice_blade_style_vented => 'Ventilada';

  @override
  String get attrChoice_mount_wrist => 'Pulso';

  @override
  String get attrChoice_mount_console => 'Console';

  @override
  String get attrChoice_mount_hud => 'HUD';

  @override
  String get attrChoice_connectivity_ble => 'Bluetooth (BLE)';

  @override
  String get attrChoice_connectivity_usb => 'USB';

  @override
  String get attrChoice_connectivity_infrared => 'Infravermelho';

  @override
  String get attrChoice_connectivity_none => 'Nenhuma';

  @override
  String get attrChoice_lens_config_single => 'Lente única';

  @override
  String get attrChoice_lens_config_twin => 'Lentes duplas';

  @override
  String get attrChoice_lens_config_frameless => 'Sem armação';

  @override
  String get attrChoice_weight_style_belt => 'Cinto';

  @override
  String get attrChoice_weight_style_integrated => 'Integrado';

  @override
  String get attrChoice_weight_style_trim => 'Trim';

  @override
  String get attrChoice_weight_style_ankle => 'Tornozelo';

  @override
  String get attrChoice_beam_type_spot => 'Foco';

  @override
  String get attrChoice_beam_type_flood => 'Difuso';

  @override
  String get attrChoice_beam_type_adjustable => 'Ajustável';

  @override
  String get attrChoice_smb_type_open => 'Aberta';

  @override
  String get attrChoice_smb_type_closed => 'Fechada';

  @override
  String get attrChoice_reel_type_spool => 'Carretel simples';

  @override
  String get attrChoice_reel_type_ratchet => 'Carretilha com catraca';

  @override
  String get attrChoice_blade_material_stainless => 'Aço inoxidável';

  @override
  String get attrChoice_blade_material_titanium => 'Titânio';

  @override
  String get attrChoice_tip_type_pointed => 'Pontiaguda';

  @override
  String get attrChoice_tip_type_blunt => 'Romba';

  @override
  String get attrChoice_tip_type_line_cutter => 'Cortador de linha';

  @override
  String get attrChoice_glove_type_five_finger => 'Cinco dedos';

  @override
  String get attrChoice_glove_type_mitt => 'Mitene';

  @override
  String get attrChoice_glove_type_dry => 'Seco';

  @override
  String get attrChoice_sole_type_hard => 'Sola rígida';

  @override
  String get attrChoice_sole_type_soft => 'Sola macia';

  @override
  String get attrChoice_dpv_style_tow_behind => 'De reboque';

  @override
  String get attrChoice_dpv_style_ride_on => 'De montar';

  @override
  String get attrChoice_dpv_style_handheld => 'De mão';

  @override
  String get attrChoice_battery_type_lithium_ion => 'Iões de lítio';

  @override
  String get attrChoice_battery_type_nimh => 'NiMH';

  @override
  String get attrChoice_battery_type_lead_acid => 'Chumbo-ácido';

  @override
  String get attrChoice_motor_type_brushless => 'Sem escovas';

  @override
  String get attrChoice_motor_type_brushed => 'Com escovas';

  @override
  String get equipment_edit_customFieldsTitle => 'Campos personalizados';

  @override
  String get equipment_edit_addCustomField => 'Adicionar campo personalizado';

  @override
  String get attr_flagYes => 'Sim';

  @override
  String get attr_flagNo => 'Não';

  @override
  String get equipment_edit_invalidThickness => 'Use 5, 5/4 ou 7/5/3';

  @override
  String get statistics_progression_divesBySuitThickness_title =>
      'Mergulhos por espessura da roupa';

  @override
  String get statistics_progression_divesBySuitThickness_subtitle =>
      'Espessura principal da roupa nos seus mergulhos';

  @override
  String get statistics_progression_divesBySuitThickness_empty =>
      'Nenhum mergulho com espessura de roupa registrada';

  @override
  String get statistics_progression_divesBySuitThickness_error =>
      'Não foi possível carregar os dados de espessura';

  @override
  String get diveLog_filter_sectionSuitThickness => 'Espessura da roupa (mm)';

  @override
  String get diveLog_filter_thicknessMin => 'Mín';

  @override
  String get diveLog_filter_thicknessMax => 'Máx';

  @override
  String get safetySettings_noFlyHeader => 'Voar depois de mergulhar';

  @override
  String get safetySettings_noFlyPreset_standard => 'Padrão (12/18/24 h)';

  @override
  String get safetySettings_noFlyPreset_strict => 'Rigoroso (18/24/48 h)';

  @override
  String get safetySettings_noFlyPreset_subtitle =>
      'Intervalos orientativos após um único mergulho sem deco, mergulhos repetitivos e mergulhos com deco';

  @override
  String get flightWindow_closed => 'Não mergulhe mais antes do seu voo';

  @override
  String get flightWindow_conflict =>
      'Seu tempo de não voar ultrapassa a partida do voo';

  @override
  String flightWindow_departs(String time) {
    return 'O voo parte $time';
  }

  @override
  String flightWindow_openTitle(String remaining) {
    return 'Tempo restante para mergulhar: $remaining';
  }

  @override
  String flightWindow_surfaceBy(String time) {
    return 'Emergir até $time';
  }

  @override
  String safetyHub_noFly_active_title(String remaining) {
    return 'Não voar: faltam $remaining';
  }

  @override
  String safetyHub_noFly_until(String time) {
    return 'Até $time';
  }

  @override
  String get safetyHub_noFly_clear_title => 'Sem restrição de voo';

  @override
  String get safetyHub_noFly_clear_subtitle => 'Nenhuma restrição de voo ativa';

  @override
  String safetyHub_noFly_category_single(int hours) {
    return 'Após um único mergulho sem deco: orientação de $hours h';
  }

  @override
  String safetyHub_noFly_category_repetitive(int hours) {
    return 'Após mergulhos repetitivos: orientação de $hours h';
  }

  @override
  String safetyHub_noFly_category_deco(int hours) {
    return 'Após um mergulho com descompressão: orientação de $hours h';
  }

  @override
  String get safetyHub_noFly_disclaimer =>
      'Orientações DAN/UHMS desde o último mergulho. Não substitui o tempo de não voar do seu computador de mergulho.';

  @override
  String get diveLog_detail_altitudeMismatch_title =>
      'O ponto de mergulho fica em altitude';

  @override
  String get diveLog_detail_altitudeMismatch_subtitle =>
      'Este ponto registra uma altitude, mas o mergulho não tem nenhuma, então a análise de descompressão assumiu o nível do mar. Defina a altitude do mergulho para corrigir.';

  @override
  String diveLog_detail_sacVolumeHint(String unit) {
    return 'Adicione o volume do cilindro para mostrar a taxa SAC em $unit/min';
  }

  @override
  String safetyHub_alert_noFly(String remaining) {
    return 'Não voar: faltam $remaining';
  }

  @override
  String get emergencyCard_title => 'Emergência';

  @override
  String emergencyCard_callDan(String name) {
    return 'Ligar para $name';
  }

  @override
  String get emergencyCard_callDan_subtitle =>
      'Linha de emergência para mergulhadores. Ligue primeiro: eles coordenam a evacuação e o encaminhamento para câmara.';

  @override
  String emergencyCard_ems(String number) {
    return 'Emergência local: $number';
  }

  @override
  String get emergencyCard_diverSection => 'Mergulhador';

  @override
  String emergencyCard_bloodType(String value) {
    return 'Tipo sanguíneo: $value';
  }

  @override
  String emergencyCard_allergies(String value) {
    return 'Alergias: $value';
  }

  @override
  String emergencyCard_medications(String value) {
    return 'Medicamentos: $value';
  }

  @override
  String get emergencyCard_contactsSection => 'Contatos de emergência';

  @override
  String get emergencyCard_insuranceSection => 'Seguro de mergulho';

  @override
  String emergencyCard_insurancePolicy(String number) {
    return 'Apólice $number';
  }

  @override
  String get emergencyCard_chambersSection => 'Câmaras hiperbáricas';

  @override
  String get emergencyCard_chambersNote =>
      'A disponibilidade muda. Ligue sempre primeiro para a linha de emergência de mergulhadores para encaminhamento.';

  @override
  String emergencyCard_chamberVerified(String date) {
    return 'Dados verificados em $date';
  }

  @override
  String get emergencyCard_chambersNearby => 'Câmaras mais próximas';

  @override
  String emergencyCard_chamberViewAll(int count) {
    return 'Ver todas as $count câmaras';
  }

  @override
  String get emergencyCard_chambersNoneNearby =>
      'Nenhuma câmara listada dentro do alcance. Ligue para a linha de emergência para mergulhadores: eles encaminharão você para a unidade mais próxima capaz de tratá-lo.';

  @override
  String get emergencyCard_chamberCapability_divingEmergency =>
      'Trata acidentes de mergulho';

  @override
  String get emergencyCard_chamberCapability_hyperbaricUnit =>
      'Unidade hiperbárica hospitalar';

  @override
  String get emergencyCard_chamberCapability_elective =>
      'Apenas terapia eletiva';

  @override
  String get emergencyCard_chamberCapability_unknown =>
      'Capacidade não confirmada';

  @override
  String get emergencyCard_chamberAvailability_h24 => '24 h';

  @override
  String get emergencyCard_chamberAvailability_onCall => 'De sobreaviso';

  @override
  String get emergencyCard_chamberAvailability_businessHours =>
      'Horário comercial';

  @override
  String get emergencyCard_chamberUnverified => 'Não confirmado com a unidade';

  @override
  String get chambersDirectory_title => 'Câmaras hiperbáricas';

  @override
  String get chambersDirectory_search => 'Pesquisar por nome, cidade ou país';

  @override
  String get chambersDirectory_empty =>
      'Nenhuma câmara corresponde a essa pesquisa.';

  @override
  String chambersDirectory_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count câmaras',
      one: '1 câmara',
    );
    return '$_temp0';
  }

  @override
  String get emergencyCard_hideChamber => 'Ocultar';

  @override
  String get emergencyCard_chamberHidden => 'Câmara ocultada';

  @override
  String get emergencyCard_undo => 'Desfazer';

  @override
  String get emergencyCard_addChamber => 'Adicionar câmara';

  @override
  String get emergencyCard_deleteChamber => 'Excluir';

  @override
  String emergencyCard_regionLabel(String region) {
    return 'Região: $region';
  }

  @override
  String get emergencyCard_regionUnknown =>
      'Região desconhecida - usando a linha mundial';

  @override
  String get emergencyCard_noDiverData =>
      'Sem dados do perfil do mergulhador. Adicione contatos de emergência, dados médicos e seguro no perfil do mergulhador.';

  @override
  String get addChamber_title => 'Adicionar câmara';

  @override
  String get addChamber_name => 'Nome';

  @override
  String get addChamber_country => 'Código do país (ex. BR)';

  @override
  String get addChamber_city => 'Cidade';

  @override
  String get addChamber_phone => 'Telefone';

  @override
  String get addChamber_notes => 'Notas';

  @override
  String get addChamber_save => 'Salvar';

  @override
  String get addChamber_nameRequired => 'O nome é obrigatório';

  @override
  String get addChamber_countryRequired => 'O código do país é obrigatório';

  @override
  String get addChamber_phoneRequired => 'O número de telefone é obrigatório';

  @override
  String get safetyHub_emergencyCardLink => 'Cartão de emergência';

  @override
  String get safetyHub_emergencyCardLink_subtitle =>
      'Offline: linha direta, emergência, câmaras, seus dados médicos e de seguro';

  @override
  String get dashboard_quickAction_emergency => 'Cartão de emergência';

  @override
  String get incidents_title => 'Registro de quase acidentes';

  @override
  String get incidents_empty =>
      'Nenhum quase acidente registrado. Anotar o que quase deu errado - sem julgamento - torna os padrões visíveis antes que virem acidentes.';

  @override
  String get incidents_add => 'Registrar quase acidente';

  @override
  String get incidents_linkedDive => 'Vinculado a um mergulho';

  @override
  String get incidents_delete_confirm =>
      'Excluir este relato de quase acidente?';

  @override
  String get incidents_notFound => 'Relatório de quase acidente não encontrado';

  @override
  String get incidentEdit_title_new => 'Registrar quase acidente';

  @override
  String get incidentEdit_title_edit => 'Editar quase acidente';

  @override
  String get incidentEdit_category => 'Categoria';

  @override
  String get incidentEdit_severity => 'Gravidade';

  @override
  String get incidentEdit_severity_minor => 'Leve';

  @override
  String get incidentEdit_severity_moderate => 'Moderado';

  @override
  String get incidentEdit_severity_serious => 'Sério';

  @override
  String get incidentEdit_date => 'Quando aconteceu';

  @override
  String get incidentEdit_narrative => 'O que aconteceu';

  @override
  String get incidentEdit_narrative_hint =>
      'Apenas os fatos, com suas palavras. Isto permanece privado.';

  @override
  String get incidentEdit_narrative_required => 'Descreva o que aconteceu';

  @override
  String get incidentEdit_contributingFactors => 'O que contribuiu (opcional)';

  @override
  String get incidentEdit_lessonsLearned =>
      'O que ajudaria da próxima vez (opcional)';

  @override
  String get incidentEdit_save => 'Salvar';

  @override
  String get incidentEdit_privacyNote =>
      'Relatos de quase acidentes sincronizam entre seus dispositivos e entram nos backups, mas nunca em exportações ou páginas compartilhadas do logbook.';

  @override
  String get incidentCategory_buoyancy => 'Flutuabilidade';

  @override
  String get incidentCategory_gasSupply => 'Suprimento de gás';

  @override
  String get incidentCategory_equipment => 'Equipamento';

  @override
  String get incidentCategory_buddySeparation => 'Separação do dupla';

  @override
  String get incidentCategory_marineLife => 'Vida marinha';

  @override
  String get incidentCategory_boatSurface => 'Barco / superfície';

  @override
  String get incidentCategory_medical => 'Médico';

  @override
  String get incidentCategory_planning => 'Planejamento';

  @override
  String get incidentCategory_other => 'Outro';

  @override
  String get safetyHub_incidentsLink => 'Registro de quase acidentes';

  @override
  String get safetyHub_incidentsLink_subtitle =>
      'Notas de incidentes privadas e não punitivas';

  @override
  String get diveLog_detail_menu_logNearMiss => 'Registrar quase acidente';

  @override
  String diveLog_detail_linkedIncidents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quase acidentes vinculados a este mergulho',
      one: '1 quase acidente vinculado a este mergulho',
    );
    return '$_temp0';
  }

  @override
  String get planning_card_noFly_subtitle =>
      'Contagem orientativa desde seus últimos mergulhos';

  @override
  String get settings_section_safety_title => 'Segurança';

  @override
  String get settings_section_safety_subtitle =>
      'Regras de revisão e voar após mergulhar';

  @override
  String get settings_section_security_title => 'Segurança do app';

  @override
  String get settings_section_security_subtitle =>
      'Bloqueio do app e criptografia do banco de dados';

  @override
  String get settings_security_appLock => 'Bloqueio do app';

  @override
  String get settings_security_appLock_subtitle =>
      'Exigir sua senha ou biometria para abrir o app';

  @override
  String get settings_security_biometrics => 'Desbloquear com biometria';

  @override
  String get settings_security_autoLock => 'Bloqueio automático';

  @override
  String get settings_security_autoLock_immediately => 'Imediatamente';

  @override
  String settings_security_autoLock_minutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Após $minutes minutos',
      one: 'Após 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get settings_security_autoLock_never => 'Nunca';

  @override
  String get settings_security_encryption => 'Criptografar banco de dados';

  @override
  String get settings_security_encryption_subtitle =>
      'Proteja o arquivo do seu registro de mergulhos com criptografia em repouso. A criptografia pode afetar o desempenho.';

  @override
  String get settings_security_encryption_progress_backup =>
      'Criando backup de segurança...';

  @override
  String get settings_security_encryption_progress_encrypt =>
      'Criptografando banco de dados...';

  @override
  String get settings_security_encryption_progress_decrypt =>
      'Descriptografando banco de dados...';

  @override
  String get settings_security_encryption_progress_reopen =>
      'Reabrindo banco de dados...';

  @override
  String get settings_security_changePassword => 'Alterar senha';

  @override
  String get settings_security_regenerateRecovery =>
      'Novo código de recuperação';

  @override
  String get settings_security_setPassword => 'Definir senha do app';

  @override
  String get settings_security_password => 'Senha';

  @override
  String get settings_security_confirmPassword => 'Confirmar senha';

  @override
  String get settings_security_currentPassword => 'Senha atual';

  @override
  String get settings_security_newPassword => 'Nova senha';

  @override
  String get settings_security_passwordTooShort =>
      'A senha deve ter pelo menos 4 caracteres.';

  @override
  String get settings_security_passwordMismatch => 'As senhas não coincidem.';

  @override
  String get settings_security_wrongPassword => 'Senha incorreta.';

  @override
  String get settings_security_recoveryCode_title =>
      'Seu código de recuperação';

  @override
  String get settings_security_recoveryCode_explain =>
      'Anote-o e guarde-o em local seguro. É a única forma de desbloquear o app se você esquecer sua senha, e ele substitui qualquer código de recuperação anterior.';

  @override
  String get settings_security_recoveryCode_savedConfirm =>
      'Salvei meu código de recuperação';

  @override
  String get settings_security_disableBlockedByEncryption_title =>
      'A criptografia está ativada';

  @override
  String get settings_security_disableBlockedByEncryption_body =>
      'Desative a criptografia do banco de dados antes de desativar o bloqueio do app. O banco criptografado precisa de uma credencial.';

  @override
  String get settings_security_enableEncryption_title =>
      'Criptografar o banco de dados?';

  @override
  String get settings_security_enableEncryption_body =>
      'Primeiro é criado um backup de segurança e depois o arquivo do banco é recriptografado no local. Pode demorar com registros grandes. A criptografia pode afetar o desempenho.';

  @override
  String get settings_security_disableEncryption_title =>
      'Desativar a criptografia?';

  @override
  String get settings_security_disableEncryption_body =>
      'O arquivo do banco de dados voltará a ser armazenado sem criptografia no disco.';

  @override
  String get settings_security_turnOffAppLock_title =>
      'Desativar o bloqueio do app?';

  @override
  String get settings_security_turnOffAppLock_body =>
      'O app abrirá sem pedir sua senha.';

  @override
  String get settings_security_unlock_title => 'Digite sua senha';

  @override
  String get settings_security_cancel => 'Cancelar';

  @override
  String get settings_security_continue => 'Continuar';

  @override
  String get settings_security_done => 'Concluído';

  @override
  String get settings_security_turnOff => 'Desativar';

  @override
  String get dataQuality_inbox_title => 'Qualidade dos dados';

  @override
  String get dataQuality_badge_tooltip => 'Revisão da qualidade dos dados';

  @override
  String get dataQuality_scan_start => 'Analisar biblioteca';

  @override
  String dataQuality_scan_progress(int done, int total) {
    return '$done de $total mergulhos verificados';
  }

  @override
  String get dataQuality_scan_cancel => 'Cancelar';

  @override
  String dataQuality_scan_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Análise concluída - $count itens para revisar',
      one: 'Análise concluída - 1 item para revisar',
      zero: 'Análise concluída - nenhuma nova constatação',
    );
    return '$_temp0';
  }

  @override
  String dataQuality_scan_errors(int count) {
    return 'Não foi possível verificar completamente $count mergulhos';
  }

  @override
  String dataQuality_lastScan(String when) {
    return 'Última análise: $when';
  }

  @override
  String get dataQuality_neverScanned =>
      'O seu diário de mergulho ainda não foi analisado';

  @override
  String get dataQuality_empty_title => 'Tudo em ordem';

  @override
  String get dataQuality_empty_subtitle =>
      'Sem constatações de qualidade dos dados. Analise a sua biblioteca para verificar problemas nos mergulhos importados.';

  @override
  String get dataQuality_banner_newChecks =>
      'Há novas verificações de qualidade disponíveis';

  @override
  String get dataQuality_banner_rescan => 'Analisar novamente';

  @override
  String get dataQuality_action_dismiss => 'Dispensar';

  @override
  String get dataQuality_action_dismissFiltered =>
      'Dispensar tudo o que é mostrado';

  @override
  String get dataQuality_action_goToDive => 'Ir para o mergulho';

  @override
  String get dataQuality_action_undo => 'Desfazer';

  @override
  String get dataQuality_repair_applied => 'Correção aplicada';

  @override
  String get dataQuality_repair_noChange => 'Não há nada a corrigir aqui';

  @override
  String get dataQuality_repair_needsReview =>
      'Sem correção automática. Abra o mergulho para corrigir.';

  @override
  String get dataQuality_repair_failed => 'Falha na correção';

  @override
  String get dataQuality_chip_all => 'Todos';

  @override
  String get dataQuality_chip_time => 'Hora';

  @override
  String get dataQuality_chip_profile => 'Perfil';

  @override
  String get dataQuality_chip_gas => 'Gás';

  @override
  String get dataQuality_chip_tanks => 'Cilindros';

  @override
  String get dataQuality_chip_duplicates => 'Duplicados';

  @override
  String get dataQuality_chip_sources => 'Fontes';

  @override
  String get dataQuality_detector_clock_offset => 'Relógio e fuso horário';

  @override
  String get dataQuality_detector_duplicate => 'Provável duplicado';

  @override
  String get dataQuality_detector_split_pair => 'Divisão acidental';

  @override
  String get dataQuality_detector_sample_gap => 'Lacunas nas amostras';

  @override
  String get dataQuality_detector_depth_spike => 'Pico de profundidade';

  @override
  String get dataQuality_detector_impossible_rate => 'Velocidade impossível';

  @override
  String get dataQuality_detector_temp_anomaly => 'Anomalia de temperatura';

  @override
  String get dataQuality_detector_pressure_anomaly => 'Anomalia de pressão';

  @override
  String get dataQuality_detector_gas_mod => 'Inconsistência de gás/MOD';

  @override
  String get dataQuality_detector_tank_assignment => 'Cilindro incorreto';

  @override
  String get dataQuality_detector_source_conflict => 'Fontes em conflito';

  @override
  String dataQuality_msg_clock_future(String date) {
    return 'O mergulho está datado no futuro ($date)';
  }

  @override
  String dataQuality_msg_clock_ancient(String date) {
    return 'O mergulho está datado antes de 1950 ($date)';
  }

  @override
  String dataQuality_msg_clock_offset(int hours) {
    return 'O relógio de uma fonte difere em $hours horas';
  }

  @override
  String dataQuality_msg_clock_overlap(int minutes) {
    return 'Sobrepõe-se a outro mergulho em $minutes min';
  }

  @override
  String dataQuality_msg_duplicate(int percent, int minutes) {
    return '$percent% de correspondência com um mergulho a $minutes min de distância';
  }

  @override
  String dataQuality_msg_split(int minutes) {
    return 'O mesmo computador foi retomado após um intervalo de superfície de $minutes min';
  }

  @override
  String dataQuality_msg_gap(int count, String longest) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lacunas nas amostras',
      one: '1 lacuna nas amostras',
    );
    return '$_temp0, a maior $longest';
  }

  @override
  String dataQuality_msg_spike(String depth, String time) {
    return 'Pico de profundidade até $depth às $time';
  }

  @override
  String dataQuality_msg_negativeDepth(int count) {
    return '$count amostras de profundidade negativa';
  }

  @override
  String dataQuality_msg_maxDepthMismatch(String stored, String profile) {
    return 'Profundidade máxima registada $stored, mas o perfil mostra $profile';
  }

  @override
  String dataQuality_msg_rate(String rate, int seconds) {
    return 'Velocidade vertical de $rate mantida durante $seconds s';
  }

  @override
  String dataQuality_msg_tempRange(String min, String max) {
    return 'Temperatura da água fora do intervalo plausível ($min a $max)';
  }

  @override
  String get dataQuality_msg_tempUnitBug =>
      'Os valores parecem um erro de unidade de temperatura';

  @override
  String dataQuality_msg_tempJump(String delta) {
    return 'A temperatura saltou $delta numa única amostra';
  }

  @override
  String dataQuality_msg_tempScalar(String temp) {
    return 'A temperatura da água registada $temp é implausível';
  }

  @override
  String dataQuality_msg_pressureSwap(String end, String start) {
    return 'A pressão final $end é superior à pressão inicial $start';
  }

  @override
  String dataQuality_msg_pressureEndpoint(String record, String series) {
    return 'O registo do cilindro indica $record, mas a série do sensor mostra $series';
  }

  @override
  String dataQuality_msg_pressureRise(String rise) {
    return 'A pressão subiu $rise a meio do mergulho sem troca de gás';
  }

  @override
  String dataQuality_msg_sac(String sac) {
    return 'O consumo à superfície implícito de $sac é implausível';
  }

  @override
  String dataQuality_msg_ppo2(String ppo2, String gas, String depth) {
    return 'A ppO2 atingiu $ppo2 com $gas a $depth';
  }

  @override
  String dataQuality_msg_hypoxic(String gas) {
    return 'Mistura hipóxica ($gas) indicada em uso à superfície';
  }

  @override
  String dataQuality_msg_switchMod(String depth, String mod) {
    return 'A troca de gás a $depth ultrapassa a MOD desse gás de $mod';
  }

  @override
  String dataQuality_msg_tankInactive(String drop) {
    return 'Este cilindro perdeu $drop enquanto a linha temporal de gás indica que não estava em uso';
  }

  @override
  String get dataQuality_msg_twinTanks =>
      'Dois cilindros apresentam uma série de pressão quase idêntica';

  @override
  String dataQuality_msg_sourceDepth(String primary, String source) {
    return 'As fontes divergem sobre a profundidade máxima: $primary vs. $source';
  }

  @override
  String get dataQuality_msg_salinityHint =>
      'A proporção constante sugere uma diferença na definição de água salgada/doce';

  @override
  String get dataQuality_msg_sourceDuration =>
      'As fontes divergem sobre a duração do mergulho';

  @override
  String get dataQuality_msg_sourceTemp =>
      'As fontes divergem sobre a temperatura da água';

  @override
  String dataQuality_repairLabel_shiftTime(String offset) {
    return 'Deslocar a hora em $offset';
  }

  @override
  String get dataQuality_repairLabel_shiftImport =>
      'Deslocar todos os mergulhos desta importação';

  @override
  String get dataQuality_repairLabel_consolidate => 'Consolidar';

  @override
  String get dataQuality_repairLabel_combine => 'Combinar em um mergulho';

  @override
  String get dataQuality_repairLabel_despike => 'Remover pico';

  @override
  String get dataQuality_repairLabel_clampNegative =>
      'Limitar profundidades acima da superfície';

  @override
  String get dataQuality_repairLabel_smoothRates =>
      'Suavizar taxas impossíveis';

  @override
  String get dataQuality_repairLabel_fillGaps => 'Preencher lacunas';

  @override
  String get dataQuality_repairLabel_smoothTemp => 'Suavizar temperatura';

  @override
  String get dataQuality_repairLabel_convertTemp => 'Converter temperatura';

  @override
  String get dataQuality_repairLabel_recompute =>
      'Recalcular a partir do perfil';

  @override
  String get dataQuality_repairLabel_swapPressures =>
      'Trocar pressão inicial/final';

  @override
  String get dataQuality_repairLabel_setFromSeries => 'Usar valores do sensor';

  @override
  String get dataQuality_repairLabel_swapSeries => 'Trocar séries de cilindros';

  @override
  String get dataQuality_repairLabel_reassignSeries =>
      'Mover a série para outro cilindro';

  @override
  String get dataQuality_repairLabel_setPrimary =>
      'Tornar esta fonte principal';

  @override
  String get dataQuality_repairLabel_split => 'Dividir em mergulhos separados';

  @override
  String get dataQuality_repairLabel_compare => 'Comparar perfis';

  @override
  String get dataQuality_settings_title => 'Qualidade dos dados';

  @override
  String get dataQuality_settings_subtitle =>
      'Escolher que verificações são executadas durante a análise';

  @override
  String dataQuality_summary_flagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens assinalados para revisão',
      one: '1 item assinalado para revisão',
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
  String get settings_mediaStorage_quality_section => 'Qualidade de envio';

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
  String get settings_mediaStorage_quality_small => 'Pequena';

  @override
  String get settings_mediaStorage_quality_caveat =>
      'Com um nível de compressão definido, os originais em resolução total não são enviados; permanecem apenas neste dispositivo.';

  @override
  String get settings_mediaStorage_quality_reuploadQueued =>
      'Novo envio na fila';

  @override
  String get settings_mediaStorage_quality_linuxFfmpegHint =>
      'Instale o ffmpeg para ativar a compressão de vídeo. Até lá, os originais são enviados.';

  @override
  String get settings_mediaStorage_quality_saveFailed =>
      'Não foi possível guardar a qualidade de envio. Tente novamente.';

  @override
  String get settings_mediaStorage_quality_noTranscoderHint =>
      'Este dispositivo não consegue comprimir vídeo. A partir dele são enviados os originais.';

  @override
  String get reef_section_title => 'Ecossistema';

  @override
  String get reef_section_sourcesTooltip => 'Fontes de dados';

  @override
  String get reef_section_loadError =>
      'Não foi possível carregar os dados do ecossistema agora';

  @override
  String get reef_habitat_title => 'Hábitat do recife';

  @override
  String get reef_habitat_onReef => 'Em um recife de coral';

  @override
  String reef_habitat_onReefWithThreat(String threat) {
    return 'Em um recife de coral, nível de ameaça $threat';
  }

  @override
  String get reef_habitat_noReef =>
      'Nenhum recife de coral mapeado nesta localização';

  @override
  String get reef_habitat_unavailable =>
      'Não foi possível verificar o hábitat do recife agora';

  @override
  String get water_conditions_title => 'Condições da água';

  @override
  String get water_conditions_unavailable =>
      'Não foi possível verificar as condições da água agora';

  @override
  String get water_conditions_noData =>
      'Sem dados de satélite da água para este local';

  @override
  String get water_conditions_freshwater =>
      'A temperatura da água por satélite cobre apenas os oceanos';

  @override
  String water_conditions_anomaly(String value) {
    return 'Anomalia $value';
  }

  @override
  String reef_health_degreeHeatingWeeks(String value) {
    return 'Semanas de aquecimento $value C-semanas';
  }

  @override
  String reef_health_seaSurface(String value) {
    return 'Superfície do mar $value';
  }

  @override
  String reef_health_asOf(String date) {
    return 'Em $date';
  }

  @override
  String get reef_health_levelNoStress => 'Sem estresse térmico';

  @override
  String get reef_health_levelWatch => 'Vigilância de branqueamento';

  @override
  String get reef_health_levelWarning => 'Aviso de branqueamento';

  @override
  String get reef_health_levelAlert1 => 'Alerta de branqueamento nível 1';

  @override
  String get reef_health_levelAlert2 => 'Alerta de branqueamento nível 2';

  @override
  String get reef_health_levelAlert3 => 'Alerta de branqueamento nível 3';

  @override
  String get reef_health_levelAlert4 => 'Alerta de branqueamento nível 4';

  @override
  String get reef_health_levelAlert5 => 'Alerta de branqueamento nível 5';

  @override
  String get reef_protection_title => 'Área protegida';

  @override
  String get reef_protection_none => 'Fora de área marinha protegida';

  @override
  String get reef_protection_unavailable =>
      'Não foi possível verificar o estado de proteção agora';

  @override
  String get reef_protection_viewRegulations => 'Ver regulamentos';

  @override
  String reef_protection_iucn(String category) {
    return 'IUCN $category';
  }

  @override
  String get reef_species_recordedNearby => 'Registrado nas proximidades';

  @override
  String get reef_species_addToExpected => 'Adicionar às espécies esperadas';

  @override
  String reef_species_showAll(int count) {
    return 'Mostrar todas as $count';
  }

  @override
  String get reef_species_showFewer => 'Mostrar menos';

  @override
  String get reef_attribution_title => 'Fontes de dados do recife';

  @override
  String get reef_attribution_wri =>
      'Presença de recife e nível de ameaça. CC BY 3.0.';

  @override
  String get reef_attribution_noaa =>
      'Temperatura da superfície do mar e estresse térmico. Domínio público.';

  @override
  String get reef_attribution_gbif =>
      'Registros de ocorrência de espécies, filtrados para CC0 e CC BY 4.0.';

  @override
  String get reef_attribution_protectedSeas =>
      'Limites de áreas marinhas protegidas. CC BY 4.0.';

  @override
  String get enum_visibilityBand_excellent => 'Excelente';

  @override
  String get enum_visibilityBand_good => 'Boa';

  @override
  String get enum_visibilityBand_moderate => 'Moderada';

  @override
  String get enum_visibilityBand_poor => 'Fraca';

  @override
  String visibility_range_between(String min, String max, String unit) {
    return '$min-$max $unit';
  }

  @override
  String visibility_range_over(String min, String unit) {
    return 'mais de $min $unit';
  }

  @override
  String visibility_range_under(String max, String unit) {
    return 'menos de $max $unit';
  }

  @override
  String get settings_coordinateFormat_title => 'Formato das coordenadas';

  @override
  String get settings_coordinateFormat_subtitle =>
      'Como as posições GPS são apresentadas e introduzidas';

  @override
  String get settings_placeNameLanguage_title => 'Idioma dos nomes de lugares';

  @override
  String get settings_placeNameLanguage_subtitle =>
      'Usado quando país, região, cidade e corpo de água são obtidos a partir das coordenadas. Os locais existentes não são alterados.';

  @override
  String get settings_coordinateFormat_decimalDegrees => 'Graus decimais';

  @override
  String get settings_coordinateFormat_degreesDecimalMinutes =>
      'Graus e minutos decimais';

  @override
  String get settings_coordinateFormat_degreesMinutesSeconds =>
      'Graus, minutos, segundos';

  @override
  String get settings_coordinateFormat_utm => 'UTM';

  @override
  String get settings_coordinateFormat_mgrs => 'MGRS';

  @override
  String get settings_visibilityScale_title => 'Escala de visibilidade';

  @override
  String get settings_visibilityScale_subtitle =>
      'Que distâncias contam como boa visibilidade onde mergulha';

  @override
  String get settings_visibilityScale_preset_tropical => 'Tropical';

  @override
  String get settings_visibilityScale_preset_temperate => 'Temperada';

  @override
  String get settings_visibilityScale_preset_coldWater =>
      'Água fria / Interior';

  @override
  String get settings_visibilityScale_preset_custom => 'Personalizada';

  @override
  String get settings_visibilityScale_customExcellent =>
      'Excelente a partir de';

  @override
  String get settings_visibilityScale_customGood => 'Boa a partir de';

  @override
  String get settings_visibilityScale_customModerate => 'Moderada a partir de';

  @override
  String get settings_visibilityScale_invalidOrder =>
      'Cada valor deve ser menor que o acima e maior que zero';

  @override
  String statistics_conditions_visibility_legacySuffix(String band) {
    return '$band (registado antes da medição)';
  }

  @override
  String common_selection_countSelected(Object count) {
    return '$count selecionados';
  }

  @override
  String get common_selection_enterTooltip => 'Selecionar itens';

  @override
  String get common_selection_exitTooltip => 'Sair da seleção';

  @override
  String get common_selection_selectAllTooltip => 'Selecionar tudo';

  @override
  String get common_selection_deselectAllTooltip => 'Desmarcar tudo';

  @override
  String common_bulkDelete_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminar $count itens?',
      one: 'Eliminar $count item?',
    );
    return '$_temp0';
  }

  @override
  String get common_bulkDelete_body => 'Esta ação não pode ser anulada.';

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
  String get marineLife_species_delete_confirmTitle => 'Eliminar espécie?';

  @override
  String marineLife_species_delete_confirmBody(String name) {
    return 'Tem a certeza de que quer eliminar \"$name\"?';
  }

  @override
  String marineLife_species_delete_inUseError(String name) {
    return 'Não é possível eliminar \"$name\" - tem avistamentos';
  }

  @override
  String marineLife_species_delete_snackbar(String name) {
    return '\"$name\" eliminada';
  }

  @override
  String marineLife_species_delete_error(String error) {
    return 'Erro ao eliminar a espécie: $error';
  }

  @override
  String get enum_diveField_diveNumber => 'Número do Mergulho';

  @override
  String get enum_diveField_dateTime => 'Data e Hora';

  @override
  String get enum_diveField_siteName => 'Nome do Ponto';

  @override
  String get enum_diveField_diveName => 'Nome do Mergulho';

  @override
  String get enum_diveField_maxDepth => 'Profundidade Máxima';

  @override
  String get enum_diveField_avgDepth => 'Profundidade Média';

  @override
  String get enum_diveField_bottomTime => 'Tempo de Fundo';

  @override
  String get enum_diveField_runtime => 'Tempo Total';

  @override
  String get enum_diveField_waterTemp => 'Temperatura da Água';

  @override
  String get enum_diveField_airTemp => 'Temperatura do Ar';

  @override
  String get enum_diveField_visibility => 'Visibilidade';

  @override
  String get enum_diveField_currentDirection => 'Direção da Corrente';

  @override
  String get enum_diveField_currentStrength => 'Força da Corrente';

  @override
  String get enum_diveField_swellHeight => 'Altura da Ondulação';

  @override
  String get enum_diveField_entryMethod => 'Método de Entrada';

  @override
  String get enum_diveField_exitMethod => 'Método de Saída';

  @override
  String get enum_diveField_waterType => 'Tipo de Água';

  @override
  String get enum_diveField_altitude => 'Altitude';

  @override
  String get enum_diveField_surfacePressure => 'Pressão de Superfície';

  @override
  String get enum_diveField_windSpeed => 'Velocidade do Vento';

  @override
  String get enum_diveField_cloudCover => 'Cobertura de Nuvens';

  @override
  String get enum_diveField_precipitation => 'Precipitação';

  @override
  String get enum_diveField_humidity => 'Umidade';

  @override
  String get enum_diveField_weatherDescription => 'Clima';

  @override
  String get enum_diveField_primaryGas => 'Gás Principal';

  @override
  String get enum_diveField_diluentGas => 'Gás Diluente';

  @override
  String get enum_diveField_tankCount => 'Número de Cilindros';

  @override
  String get enum_diveField_startPressure => 'Pressão Inicial';

  @override
  String get enum_diveField_endPressure => 'Pressão Final';

  @override
  String get enum_diveField_sacRate => 'Taxa SAC';

  @override
  String get enum_diveField_gasConsumed => 'Gás Consumido';

  @override
  String get enum_diveField_totalWeight => 'Lastro Total';

  @override
  String get enum_diveField_diveComputerModel => 'Computador de Mergulho';

  @override
  String get enum_diveField_gradientFactorLow => 'GF Baixo';

  @override
  String get enum_diveField_gradientFactorHigh => 'GF Alto';

  @override
  String get enum_diveField_decoAlgorithm => 'Algoritmo de Deco';

  @override
  String get enum_diveField_decoConservatism => 'Conservadorismo';

  @override
  String get enum_diveField_cnsStart => 'CNS Inicial';

  @override
  String get enum_diveField_cnsEnd => 'CNS Final';

  @override
  String get enum_diveField_otu => 'OTU';

  @override
  String get enum_diveField_diveMode => 'Modo de Mergulho';

  @override
  String get enum_diveField_setpointLow => 'Setpoint Baixo';

  @override
  String get enum_diveField_setpointHigh => 'Setpoint Alto';

  @override
  String get enum_diveField_setpointDeco => 'Setpoint Deco';

  @override
  String get enum_diveField_buddy => 'Dupla';

  @override
  String get enum_diveField_diveMaster => 'Divemaster';

  @override
  String get enum_diveField_siteLocation => 'Local do Ponto';

  @override
  String get enum_diveField_diveCenterName => 'Centro de Mergulho';

  @override
  String get enum_diveField_siteLatitude => 'Latitude';

  @override
  String get enum_diveField_siteLongitude => 'Longitude';

  @override
  String get enum_diveField_tripName => 'Viagem';

  @override
  String get enum_diveField_ratingStars => 'Avaliação';

  @override
  String get enum_diveField_isFavorite => 'Favorito';

  @override
  String get enum_diveField_notes => 'Notas';

  @override
  String get enum_diveField_tags => 'Tags';

  @override
  String get enum_diveField_importSource => 'Origem da Importação';

  @override
  String get enum_diveField_diveTypeName => 'Tipo de Mergulho';

  @override
  String get enum_diveField_surfaceInterval => 'Intervalo de Superfície';

  @override
  String get enum_diveField_diveNumber_short => '#';

  @override
  String get enum_diveField_dateTime_short => 'Data';

  @override
  String get enum_diveField_siteName_short => 'Ponto';

  @override
  String get enum_diveField_diveName_short => 'Nome';

  @override
  String get enum_diveField_maxDepth_short => 'P. Máx';

  @override
  String get enum_diveField_avgDepth_short => 'P. Méd';

  @override
  String get enum_diveField_bottomTime_short => 'TF';

  @override
  String get enum_diveField_runtime_short => 'TT';

  @override
  String get enum_diveField_waterTemp_short => 'T Água';

  @override
  String get enum_diveField_airTemp_short => 'T Ar';

  @override
  String get enum_diveField_visibility_short => 'Vis';

  @override
  String get enum_diveField_currentDirection_short => 'Dir Corr';

  @override
  String get enum_diveField_currentStrength_short => 'Corr';

  @override
  String get enum_diveField_swellHeight_short => 'Onda';

  @override
  String get enum_diveField_entryMethod_short => 'Entr.';

  @override
  String get enum_diveField_exitMethod_short => 'Saída';

  @override
  String get enum_diveField_waterType_short => 'Água';

  @override
  String get enum_diveField_altitude_short => 'Alt';

  @override
  String get enum_diveField_surfacePressure_short => 'P Sup';

  @override
  String get enum_diveField_windSpeed_short => 'Vento';

  @override
  String get enum_diveField_cloudCover_short => 'Nuvens';

  @override
  String get enum_diveField_precipitation_short => 'Precip';

  @override
  String get enum_diveField_humidity_short => 'Umid.';

  @override
  String get enum_diveField_weatherDescription_short => 'Clima';

  @override
  String get enum_diveField_primaryGas_short => 'Gás';

  @override
  String get enum_diveField_diluentGas_short => 'Dil';

  @override
  String get enum_diveField_tankCount_short => 'Cil.';

  @override
  String get enum_diveField_startPressure_short => 'P Ini';

  @override
  String get enum_diveField_endPressure_short => 'P Fim';

  @override
  String get enum_diveField_sacRate_short => 'SAC';

  @override
  String get enum_diveField_gasConsumed_short => 'Gás Cons';

  @override
  String get enum_diveField_totalWeight_short => 'Lastro';

  @override
  String get enum_diveField_diveComputerModel_short => 'Comput.';

  @override
  String get enum_diveField_gradientFactorLow_short => 'GFL';

  @override
  String get enum_diveField_gradientFactorHigh_short => 'GFH';

  @override
  String get enum_diveField_decoAlgorithm_short => 'Algo';

  @override
  String get enum_diveField_decoConservatism_short => 'Conserv';

  @override
  String get enum_diveField_cnsStart_short => 'CNS Ini';

  @override
  String get enum_diveField_cnsEnd_short => 'CNS Fim';

  @override
  String get enum_diveField_otu_short => 'OTU';

  @override
  String get enum_diveField_diveMode_short => 'Modo';

  @override
  String get enum_diveField_setpointLow_short => 'SP Baixo';

  @override
  String get enum_diveField_setpointHigh_short => 'SP Alto';

  @override
  String get enum_diveField_setpointDeco_short => 'SP Deco';

  @override
  String get enum_diveField_buddy_short => 'Dupla';

  @override
  String get enum_diveField_diveMaster_short => 'DM';

  @override
  String get enum_diveField_siteLocation_short => 'Local';

  @override
  String get enum_diveField_diveCenterName_short => 'Centro';

  @override
  String get enum_diveField_siteLatitude_short => 'Lat';

  @override
  String get enum_diveField_siteLongitude_short => 'Lng';

  @override
  String get enum_diveField_tripName_short => 'Viagem';

  @override
  String get enum_diveField_ratingStars_short => 'Aval.';

  @override
  String get enum_diveField_isFavorite_short => 'Fav';

  @override
  String get enum_diveField_notes_short => 'Notas';

  @override
  String get enum_diveField_tags_short => 'Tags';

  @override
  String get enum_diveField_importSource_short => 'Origem';

  @override
  String get enum_diveField_diveTypeName_short => 'Tipo';

  @override
  String get enum_diveField_surfaceInterval_short => 'IS';

  @override
  String get enum_siteField_siteName => 'Nome';

  @override
  String get enum_siteField_location => 'Localização';

  @override
  String get enum_siteField_country => 'País';

  @override
  String get enum_siteField_region => 'Região';

  @override
  String get enum_siteField_city => 'Cidade';

  @override
  String get enum_siteField_island => 'Ilha';

  @override
  String get enum_siteField_bodyOfWater => 'Corpo de Água';

  @override
  String get enum_siteField_diveCount => 'Número de Mergulhos';

  @override
  String get enum_siteField_maxDepth => 'Profundidade Máxima';

  @override
  String get enum_siteField_minDepth => 'Profundidade Mínima';

  @override
  String get enum_siteField_altitude => 'Altitude';

  @override
  String get enum_siteField_waterType => 'Tipo de Água';

  @override
  String get enum_siteField_typicalVisibility => 'Visibilidade Típica';

  @override
  String get enum_siteField_typicalCurrent => 'Corrente Típica';

  @override
  String get enum_siteField_difficulty => 'Dificuldade';

  @override
  String get enum_siteField_entryType => 'Tipo de Entrada';

  @override
  String get enum_siteField_bestSeason => 'Melhor Época';

  @override
  String get enum_siteField_mooringNumber => 'Número do Fundeadouro';

  @override
  String get enum_siteField_hazards => 'Perigos';

  @override
  String get enum_siteField_rating => 'Avaliação';

  @override
  String get enum_siteField_notes => 'Notas';

  @override
  String get enum_siteField_latitude => 'Latitude';

  @override
  String get enum_siteField_longitude => 'Longitude';

  @override
  String get enum_siteField_siteName_short => 'Nome';

  @override
  String get enum_siteField_location_short => 'Local';

  @override
  String get enum_siteField_country_short => 'País';

  @override
  String get enum_siteField_region_short => 'Região';

  @override
  String get enum_siteField_city_short => 'Cidade';

  @override
  String get enum_siteField_island_short => 'Ilha';

  @override
  String get enum_siteField_bodyOfWater_short => 'Corpo Água';

  @override
  String get enum_siteField_diveCount_short => 'Merg.';

  @override
  String get enum_siteField_maxDepth_short => 'P. Máx';

  @override
  String get enum_siteField_minDepth_short => 'P. Mín';

  @override
  String get enum_siteField_altitude_short => 'Alt';

  @override
  String get enum_siteField_waterType_short => 'Água';

  @override
  String get enum_siteField_typicalVisibility_short => 'Vis';

  @override
  String get enum_siteField_typicalCurrent_short => 'Corrente';

  @override
  String get enum_siteField_difficulty_short => 'Dific.';

  @override
  String get enum_siteField_entryType_short => 'Entr.';

  @override
  String get enum_siteField_exitMethod => 'Método de saída';

  @override
  String get enum_siteField_exitMethod_short => 'Saída';

  @override
  String get enum_siteField_bestSeason_short => 'Época';

  @override
  String get enum_siteField_mooringNumber_short => 'Fundead.';

  @override
  String get enum_siteField_hazards_short => 'Perigos';

  @override
  String get enum_siteField_rating_short => 'Aval.';

  @override
  String get enum_siteField_notes_short => 'Notas';

  @override
  String get enum_siteField_latitude_short => 'Lat';

  @override
  String get enum_siteField_longitude_short => 'Lon';

  @override
  String get enum_siteField_depthRange => 'Faixa de profundidade';

  @override
  String get enum_siteField_depthRange_short => 'Prof.';

  @override
  String get enum_siteField_lastDived => 'Último mergulho';

  @override
  String get enum_siteField_lastDived_short => 'Último';

  @override
  String get enum_siteField_maxDepthReached => 'Sua prof. máxima';

  @override
  String get enum_siteField_maxDepthReached_short => 'Seu máx.';

  @override
  String get enum_buddyField_buddyName => 'Nome';

  @override
  String get enum_buddyField_email => 'E-mail';

  @override
  String get enum_buddyField_phone => 'Telefone';

  @override
  String get enum_buddyField_certificationLevel => 'Nível de Certificação';

  @override
  String get enum_buddyField_certificationAgency => 'Agência Certificadora';

  @override
  String get enum_buddyField_diveCount => 'Número de Mergulhos';

  @override
  String get enum_buddyField_notes => 'Notas';

  @override
  String get enum_buddyField_buddyName_short => 'Nome';

  @override
  String get enum_buddyField_email_short => 'E-mail';

  @override
  String get enum_buddyField_phone_short => 'Tel.';

  @override
  String get enum_buddyField_certificationLevel_short => 'Nível Cert';

  @override
  String get enum_buddyField_certificationAgency_short => 'Agência';

  @override
  String get enum_buddyField_diveCount_short => 'Merg.';

  @override
  String get enum_buddyField_notes_short => 'Notas';

  @override
  String get enum_buddyField_lastDive => 'Último mergulho';

  @override
  String get enum_buddyField_lastDive_short => 'Último';

  @override
  String get enum_tripField_tripName => 'Nome';

  @override
  String get enum_tripField_startDate => 'Data de Início';

  @override
  String get enum_tripField_endDate => 'Data de Término';

  @override
  String get enum_tripField_durationDays => 'Duração';

  @override
  String get enum_tripField_location => 'Localização';

  @override
  String get enum_tripField_tripType => 'Tipo de Viagem';

  @override
  String get enum_tripField_resortName => 'Resort';

  @override
  String get enum_tripField_liveaboardName => 'Liveaboard';

  @override
  String get enum_tripField_diveCount => 'Número de Mergulhos';

  @override
  String get enum_tripField_totalRuntime => 'Tempo Total Acumulado';

  @override
  String get enum_tripField_maxDepth => 'Profundidade Máxima';

  @override
  String get enum_tripField_avgDepth => 'Profundidade Média';

  @override
  String get enum_tripField_notes => 'Notas';

  @override
  String get enum_tripField_tripName_short => 'Nome';

  @override
  String get enum_tripField_startDate_short => 'Início';

  @override
  String get enum_tripField_endDate_short => 'Fim';

  @override
  String get enum_tripField_durationDays_short => 'Dias';

  @override
  String get enum_tripField_location_short => 'Local';

  @override
  String get enum_tripField_tripType_short => 'Tipo';

  @override
  String get enum_tripField_resortName_short => 'Resort';

  @override
  String get enum_tripField_liveaboardName_short => 'Liveaboard';

  @override
  String get enum_tripField_diveCount_short => 'Merg.';

  @override
  String get enum_tripField_totalRuntime_short => 'TT Acum.';

  @override
  String get enum_tripField_maxDepth_short => 'P. Máx';

  @override
  String get enum_tripField_avgDepth_short => 'P. Méd';

  @override
  String get enum_tripField_notes_short => 'Notas';

  @override
  String get enum_equipmentField_itemName => 'Nome';

  @override
  String get enum_equipmentField_fullName => 'Nome Completo';

  @override
  String get enum_equipmentField_type => 'Tipo';

  @override
  String get enum_equipmentField_brand => 'Marca';

  @override
  String get enum_equipmentField_model => 'Modelo';

  @override
  String get enum_equipmentField_serialNumber => 'Número de Série';

  @override
  String get enum_equipmentField_size => 'Tamanho';

  @override
  String get enum_equipmentField_status => 'Status';

  @override
  String get enum_equipmentField_isActive => 'Ativo';

  @override
  String get enum_equipmentField_purchaseDate => 'Data de Compra';

  @override
  String get enum_equipmentField_purchasePrice => 'Preço de Compra';

  @override
  String get enum_equipmentField_lastServiceDate => 'Última Manutenção';

  @override
  String get enum_equipmentField_nextServiceDue => 'Próxima Manutenção';

  @override
  String get enum_equipmentField_daysUntilService => 'Dias Até a Manutenção';

  @override
  String get enum_equipmentField_serviceIntervalDays =>
      'Intervalo de Manutenção';

  @override
  String get enum_equipmentField_notes => 'Notas';

  @override
  String get enum_equipmentField_itemName_short => 'Nome';

  @override
  String get enum_equipmentField_fullName_short => 'Nome Compl';

  @override
  String get enum_equipmentField_type_short => 'Tipo';

  @override
  String get enum_equipmentField_brand_short => 'Marca';

  @override
  String get enum_equipmentField_model_short => 'Modelo';

  @override
  String get enum_equipmentField_serialNumber_short => 'Série #';

  @override
  String get enum_equipmentField_size_short => 'Tam.';

  @override
  String get enum_equipmentField_status_short => 'Status';

  @override
  String get enum_equipmentField_isActive_short => 'Ativo';

  @override
  String get enum_equipmentField_purchaseDate_short => 'Comprado';

  @override
  String get enum_equipmentField_purchasePrice_short => 'Preço';

  @override
  String get enum_equipmentField_lastServiceDate_short => 'Últ Manut';

  @override
  String get enum_equipmentField_nextServiceDue_short => 'Próx Manut';

  @override
  String get enum_equipmentField_daysUntilService_short => 'Dias Rest';

  @override
  String get enum_equipmentField_serviceIntervalDays_short => 'Intervalo';

  @override
  String get enum_equipmentField_notes_short => 'Notas';

  @override
  String get enum_diveCenterField_centerName => 'Nome';

  @override
  String get enum_diveCenterField_city => 'Cidade';

  @override
  String get enum_diveCenterField_country => 'País';

  @override
  String get enum_diveCenterField_stateProvince => 'Estado / Província';

  @override
  String get enum_diveCenterField_street => 'Rua';

  @override
  String get enum_diveCenterField_postalCode => 'CEP';

  @override
  String get enum_diveCenterField_phone => 'Telefone';

  @override
  String get enum_diveCenterField_email => 'E-mail';

  @override
  String get enum_diveCenterField_website => 'Site';

  @override
  String get enum_diveCenterField_affiliations => 'Afiliações';

  @override
  String get enum_diveCenterField_rating => 'Avaliação';

  @override
  String get enum_diveCenterField_latitude => 'Latitude';

  @override
  String get enum_diveCenterField_longitude => 'Longitude';

  @override
  String get enum_diveCenterField_diveCount => 'Número de Mergulhos';

  @override
  String get enum_diveCenterField_notes => 'Notas';

  @override
  String get enum_diveCenterField_centerName_short => 'Nome';

  @override
  String get enum_diveCenterField_city_short => 'Cidade';

  @override
  String get enum_diveCenterField_country_short => 'País';

  @override
  String get enum_diveCenterField_stateProvince_short => 'Estado';

  @override
  String get enum_diveCenterField_street_short => 'Rua';

  @override
  String get enum_diveCenterField_postalCode_short => 'CEP';

  @override
  String get enum_diveCenterField_phone_short => 'Tel.';

  @override
  String get enum_diveCenterField_email_short => 'E-mail';

  @override
  String get enum_diveCenterField_website_short => 'Site';

  @override
  String get enum_diveCenterField_affiliations_short => 'Afiliações';

  @override
  String get enum_diveCenterField_rating_short => 'Aval.';

  @override
  String get enum_diveCenterField_latitude_short => 'Lat';

  @override
  String get enum_diveCenterField_longitude_short => 'Lon';

  @override
  String get enum_diveCenterField_diveCount_short => 'Merg.';

  @override
  String get enum_diveCenterField_notes_short => 'Notas';

  @override
  String get enum_certificationField_certName => 'Nome';

  @override
  String get enum_certificationField_agency => 'Agência';

  @override
  String get enum_certificationField_level => 'Certificação';

  @override
  String get enum_certificationField_cardNumber => 'Número do Cartão';

  @override
  String get enum_certificationField_issueDate => 'Data de Emissão';

  @override
  String get enum_certificationField_expiryDate => 'Data de Validade';

  @override
  String get enum_certificationField_instructorName => 'Nome do Instrutor';

  @override
  String get enum_certificationField_instructorNumber => 'Número do Instrutor';

  @override
  String get enum_certificationField_expiryStatus => 'Status de Validade';

  @override
  String get enum_certificationField_notes => 'Notas';

  @override
  String get enum_certificationField_certName_short => 'Nome';

  @override
  String get enum_certificationField_agency_short => 'Agência';

  @override
  String get enum_certificationField_level_short => 'Certificação';

  @override
  String get enum_certificationField_cardNumber_short => 'Cartão #';

  @override
  String get enum_certificationField_issueDate_short => 'Emissão';

  @override
  String get enum_certificationField_expiryDate_short => 'Validade';

  @override
  String get enum_certificationField_instructorName_short => 'Instrutor';

  @override
  String get enum_certificationField_instructorNumber_short => 'Instr. #';

  @override
  String get enum_certificationField_expiryStatus_short => 'Status';

  @override
  String get enum_certificationField_notes_short => 'Notas';

  @override
  String get enum_courseField_courseName => 'Nome';

  @override
  String get enum_courseField_agency => 'Agência';

  @override
  String get enum_courseField_startDate => 'Data de Início';

  @override
  String get enum_courseField_completionDate => 'Data de Conclusão';

  @override
  String get enum_courseField_durationDays => 'Duração';

  @override
  String get enum_courseField_instructorName => 'Nome do Instrutor';

  @override
  String get enum_courseField_instructorNumber => 'Número do Instrutor';

  @override
  String get enum_courseField_location => 'Local';

  @override
  String get enum_courseField_isCompleted => 'Concluído';

  @override
  String get enum_courseField_notes => 'Notas';

  @override
  String get enum_courseField_courseName_short => 'Nome';

  @override
  String get enum_courseField_agency_short => 'Agência';

  @override
  String get enum_courseField_startDate_short => 'Início';

  @override
  String get enum_courseField_completionDate_short => 'Concluído';

  @override
  String get enum_courseField_durationDays_short => 'Duração';

  @override
  String get enum_courseField_instructorName_short => 'Instrutor';

  @override
  String get enum_courseField_instructorNumber_short => 'Instr. #';

  @override
  String get enum_courseField_location_short => 'Local';

  @override
  String get enum_courseField_isCompleted_short => 'Concl.';

  @override
  String get enum_courseField_notes_short => 'Notas';

  @override
  String get enum_fieldCategory_accommodation => 'Hospedagem';

  @override
  String get enum_fieldCategory_address => 'Endereço';

  @override
  String get enum_fieldCategory_certification => 'Certificação';

  @override
  String get enum_fieldCategory_conditions => 'Condições';

  @override
  String get enum_fieldCategory_contact => 'Contato';

  @override
  String get enum_fieldCategory_coordinates => 'Coordenadas';

  @override
  String get enum_fieldCategory_dates => 'Datas';

  @override
  String get enum_fieldCategory_depth => 'Profundidade';

  @override
  String get enum_fieldCategory_details => 'Detalhes';

  @override
  String get enum_fieldCategory_instructor => 'Instrutor';

  @override
  String get enum_fieldCategory_other => 'Outros';

  @override
  String get enum_fieldCategory_purchase => 'Compra';

  @override
  String get enum_fieldCategory_service => 'Manutenção';

  @override
  String get enum_fieldCategory_statistics => 'Estatísticas';

  @override
  String get species_whale_shark_name => 'Tubarão-baleia';

  @override
  String get species_whale_shark_desc =>
      'O maior peixe do oceano, um filtrador dócil com um padrão de manchas inconfundível.';

  @override
  String get species_great_white_shark_name => 'Tubarão-branco';

  @override
  String get species_great_white_shark_desc =>
      'Predador de topo icónico, avistado ocasionalmente por mergulhadores em gaiola em águas temperadas.';

  @override
  String get species_great_hammerhead_shark_name => 'Tubarão-martelo-gigante';

  @override
  String get species_great_hammerhead_shark_desc =>
      'A maior das espécies de tubarão-martelo, com cabeça larga e achatada e barbatana dorsal alta.';

  @override
  String get species_scalloped_hammerhead_shark_name =>
      'Tubarão-martelo-recortado';

  @override
  String get species_scalloped_hammerhead_shark_desc =>
      'Visto muitas vezes em grandes cardumes junto a montes submarinos e estações de limpeza.';

  @override
  String get species_smooth_hammerhead_shark_name => 'Tubarão-martelo-liso';

  @override
  String get species_smooth_hammerhead_shark_desc =>
      'Tubarão-martelo com o bordo da cabeça liso e arredondado, presente em mares temperados.';

  @override
  String get species_whitetip_reef_shark_name =>
      'Tubarão-de-pontas-brancas-do-recife';

  @override
  String get species_whitetip_reef_shark_desc =>
      'Habitante dócil dos recifes, encontrado muitas vezes a repousar em grutas e sob saliências durante o dia.';

  @override
  String get species_blacktip_reef_shark_name =>
      'Tubarão-de-pontas-negras-do-recife';

  @override
  String get species_blacktip_reef_shark_desc =>
      'Tubarão de recife comum em águas pouco profundas, com as pontas das barbatanas nitidamente negras.';

  @override
  String get species_grey_reef_shark_name => 'Tubarão-cinzento-do-recife';

  @override
  String get species_grey_reef_shark_desc =>
      'Predador ativo dos recifes, encontrado com frequência em grupo ao longo de paredes e canais.';

  @override
  String get species_caribbean_reef_shark_name =>
      'Tubarão-do-recife-das-Caraíbas';

  @override
  String get species_caribbean_reef_shark_desc =>
      'O tubarão de recife mais frequente nas Caraíbas, robusto e curioso.';

  @override
  String get species_nurse_shark_name => 'Tubarão-lixa';

  @override
  String get species_nurse_shark_desc =>
      'Habitante lento do fundo, encontrado muitas vezes a repousar sob saliências de coral.';

  @override
  String get species_tawny_nurse_shark_name => 'Tubarão-lixa-fulvo';

  @override
  String get species_tawny_nurse_shark_desc =>
      'Habitante do fundo do Indo-Pacífico, encontrado a repousar em grutas do recife e zonas arenosas.';

  @override
  String get species_bull_shark_name => 'Tubarão-touro';

  @override
  String get species_bull_shark_desc =>
      'Tubarão robusto e poderoso, presente em ambientes costeiros e de água doce em todo o mundo.';

  @override
  String get species_tiger_shark_name => 'Tubarão-tigre';

  @override
  String get species_tiger_shark_desc =>
      'Grande predador com um padrão listado característico, encontrado em mergulhos em recifes profundos.';

  @override
  String get species_oceanic_whitetip_shark_name =>
      'Tubarão-de-pontas-brancas-oceânico';

  @override
  String get species_oceanic_whitetip_shark_desc =>
      'Tubarão pelágico com barbatanas arredondadas de pontas brancas, avistado em mergulhos em mar aberto.';

  @override
  String get species_thresher_shark_name => 'Tubarão-raposo';

  @override
  String get species_thresher_shark_desc =>
      'Reconhecível pela barbatana caudal extremamente longa, por vezes avistado em estações de limpeza.';

  @override
  String get species_pelagic_thresher_shark_name => 'Tubarão-raposo-pelágico';

  @override
  String get species_pelagic_thresher_shark_desc =>
      'A mais pequena das espécies de tubarão-raposo, célebre pelos avistamentos em Monad Shoal, nas Filipinas.';

  @override
  String get species_shortfin_mako_shark_name => 'Tubarão-anequim';

  @override
  String get species_shortfin_mako_shark_desc =>
      'O tubarão mais rápido do oceano, um predador esguio de mar aberto com coloração azul metálica.';

  @override
  String get species_blue_shark_name => 'Tubarão-azul';

  @override
  String get species_blue_shark_desc =>
      'Tubarão pelágico esguio e de azul intenso, encontrado com frequência em mergulhos em água azul.';

  @override
  String get species_spotted_wobbegong_name => 'Tubarão-tapete-malhado';

  @override
  String get species_spotted_wobbegong_desc =>
      'Tubarão-tapete achatado e camuflado que fica imóvel sobre os recifes rochosos da Austrália.';

  @override
  String get species_tasselled_wobbegong_name => 'Tubarão-tapete-franjado';

  @override
  String get species_tasselled_wobbegong_desc =>
      'Tubarão-tapete ornamentado, com lobos franjados em redor da cabeça, presente em recifes de coral.';

  @override
  String get species_epaulette_shark_name => 'Tubarão-charreteira';

  @override
  String get species_epaulette_shark_desc =>
      'Pequeno tubarão que caminha pelo fundo do recife apoiado nas barbatanas peitorais.';

  @override
  String get species_horn_shark_name => 'Tubarão-corno';

  @override
  String get species_horn_shark_desc =>
      'Habitante noturno do fundo, com cristas por cima dos olhos, presente ao largo da Califórnia.';

  @override
  String get species_leopard_shark_name => 'Tubarão-leopardo';

  @override
  String get species_leopard_shark_desc =>
      'Tubarão de padrão belíssimo, encontrado em baías pouco profundas da costa do Pacífico dos EUA.';

  @override
  String get species_pacific_angel_shark_name => 'Anjo-do-mar-do-Pacífico';

  @override
  String get species_pacific_angel_shark_desc =>
      'Predador de emboscada de corpo achatado que fica enterrado na areia do fundo.';

  @override
  String get species_sand_tiger_shark_name => 'Tubarão-de-areia';

  @override
  String get species_sand_tiger_shark_desc =>
      'Tubarão de aspeto feroz mas dócil, avistado muitas vezes a pairar em grutas e destroços.';

  @override
  String get species_zebra_shark_name => 'Tubarão-zebra';

  @override
  String get species_zebra_shark_desc =>
      'Tubarão de recife pintalgado que repousa sobre fundos arenosos, comum no Indo-Pacífico.';

  @override
  String get species_blacktip_shark_name => 'Tubarão-de-pontas-negras';

  @override
  String get species_blacktip_shark_desc =>
      'Tubarão costeiro veloz, conhecido pelos saltos em espiral, presente em águas quentes de todo o mundo.';

  @override
  String get species_silvertip_shark_name => 'Tubarão-de-pontas-prateadas';

  @override
  String get species_silvertip_shark_desc =>
      'Tubarão de recife audaz, com as barbatanas orladas de branco, presente junto a grandes paredes e atóis.';

  @override
  String get species_silky_shark_name => 'Tubarão-lombo-preto';

  @override
  String get species_silky_shark_desc =>
      'Tubarão pelágico esguio de pele lisa, encontrado muitas vezes junto a recifes ao largo.';

  @override
  String get species_lemon_shark_name => 'Tubarão-limão';

  @override
  String get species_lemon_shark_desc =>
      'Tubarão de tom castanho-amarelado, visto com frequência em mangais e planícies arenosas pouco profundas.';

  @override
  String get species_galapagos_shark_name => 'Tubarão-dos-Galápagos';

  @override
  String get species_galapagos_shark_desc =>
      'Grande tubarão de recife encontrado em redor de ilhas oceânicas, curioso perante os mergulhadores.';

  @override
  String get species_port_jackson_shark_name => 'Tubarão-de-Port Jackson';

  @override
  String get species_port_jackson_shark_desc =>
      'Habitante noturno do fundo, com marcas semelhantes a um arnês, endémico da Austrália.';

  @override
  String get species_bamboo_shark_name => 'Tubarão-bambu-de-bandas-castanhas';

  @override
  String get species_bamboo_shark_desc =>
      'Pequeno tubarão de fundo, dócil e comum nos recifes de coral do Indo-Pacífico.';

  @override
  String get species_basking_shark_name => 'Tubarão-frade';

  @override
  String get species_basking_shark_desc =>
      'O segundo maior peixe do mundo, um filtrador avistado à superfície em águas temperadas.';

  @override
  String get species_greenland_shark_name => 'Tubarão-da-Gronelândia';

  @override
  String get species_greenland_shark_desc =>
      'Tubarão lento de águas profundas, um dos vertebrados mais longevos da Terra.';

  @override
  String get species_cookiecutter_shark_name => 'Tubarão-charuto';

  @override
  String get species_cookiecutter_shark_desc =>
      'Pequeno tubarão de profundidade que arranca dentadas circulares a animais marinhos maiores.';

  @override
  String get species_sevengill_shark_name =>
      'Tubarão-de-sete-guelras-de-focinho-largo';

  @override
  String get species_sevengill_shark_desc =>
      'Tubarão primitivo com sete fendas branquiais, encontrado em mergulhos temperados em florestas de kelp.';

  @override
  String get species_pyjama_shark_name => 'Tubarão-pijama';

  @override
  String get species_pyjama_shark_desc =>
      'Pata-roxa listada endémica da África do Sul, presente em recifes rochosos e florestas de kelp.';

  @override
  String get species_spiny_dogfish_name => 'Galhudo-malhado';

  @override
  String get species_spiny_dogfish_desc =>
      'Tubarão pequeno e abundante, com espinhos dorsais venenosos, presente em águas temperadas.';

  @override
  String get species_swell_shark_name => 'Tubarão-balão';

  @override
  String get species_swell_shark_desc =>
      'Pata-roxa noturna que insufla o corpo quando ameaçada, presente ao largo da Califórnia.';

  @override
  String get species_giant_oceanic_manta_ray_name => 'Manta-gigante-oceânica';

  @override
  String get species_giant_oceanic_manta_ray_desc =>
      'A maior espécie de raia, um filtrador majestoso com até 7 metros de envergadura.';

  @override
  String get species_reef_manta_ray_name => 'Manta-de-recife';

  @override
  String get species_reef_manta_ray_desc =>
      'Espécie de manta mais pequena, vista com frequência em estações de limpeza nos recifes tropicais.';

  @override
  String get species_spotted_eagle_ray_name => 'Raia-águia-pintada';

  @override
  String get species_spotted_eagle_ray_desc =>
      'Raia elegante com pintas brancas e uma cauda longa em chicote, avistada muitas vezes a meia-água.';

  @override
  String get species_common_eagle_ray_name => 'Raia-águia-comum';

  @override
  String get species_common_eagle_ray_desc =>
      'Raia em forma de losango, presente em águas temperadas do Atlântico oriental e do Mediterrâneo.';

  @override
  String get species_blue_spotted_ribbontail_ray_name =>
      'Raia-fita-de-pintas-azuis';

  @override
  String get species_blue_spotted_ribbontail_ray_desc =>
      'Raia de cores vivas com pintas de azul intenso, comum nos recifes do Indo-Pacífico.';

  @override
  String get species_blue_spotted_stingray_name => 'Uge-de-pintas-azuis';

  @override
  String get species_blue_spotted_stingray_desc =>
      'Pequena uge de recife com pintas azuis dispersas, muitas vezes enterrada em manchas de areia.';

  @override
  String get species_southern_stingray_name => 'Uge-do-sul';

  @override
  String get species_southern_stingray_desc =>
      'Grande uge dos fundos arenosos das Caraíbas, célebre em Stingray City.';

  @override
  String get species_round_stingray_name => 'Uge-redonda';

  @override
  String get species_round_stingray_desc =>
      'Pequena uge circular, comum em zonas arenosas pouco profundas do Pacífico oriental.';

  @override
  String get species_short_tail_stingray_name => 'Uge-de-cauda-curta';

  @override
  String get species_short_tail_stingray_desc =>
      'Uma das maiores raias-uge, presente em águas temperadas do hemisfério sul.';

  @override
  String get species_cowtail_stingray_name => 'Uge-rabo-de-vaca';

  @override
  String get species_cowtail_stingray_desc =>
      'Grande uge escura com uma prega caudal característica em forma de bandeira, presente em recifes arenosos.';

  @override
  String get species_atlantic_torpedo_ray_name => 'Tremelga-do-Atlântico';

  @override
  String get species_atlantic_torpedo_ray_desc =>
      'Raia elétrica capaz de produzir descargas fortes, presente em fundos arenosos do Atlântico.';

  @override
  String get species_marbled_electric_ray_name => 'Tremelga-marmoreada';

  @override
  String get species_marbled_electric_ray_desc =>
      'Tremelga do Mediterrâneo com padrão marmoreado, capaz de aplicar um choque elétrico notável.';

  @override
  String get species_giant_guitarfish_name => 'Peixe-viola-gigante';

  @override
  String get species_giant_guitarfish_desc =>
      'Raia com forma de tubarão, presente em fundos arenosos do Indo-Pacífico junto a recifes de coral.';

  @override
  String get species_shovelnose_guitarfish_name =>
      'Peixe-viola-de-focinho-de-pá';

  @override
  String get species_shovelnose_guitarfish_desc =>
      'Silhueta achatada, entre raia e tubarão, comum nos baixios arenosos do Pacífico oriental.';

  @override
  String get species_smalltooth_sawfish_name =>
      'Peixe-serra-de-dentes-pequenos';

  @override
  String get species_smalltooth_sawfish_desc =>
      'Raia criticamente ameaçada, com um rostro dentado, presente em águas costeiras tropicais.';

  @override
  String get species_green_sawfish_name => 'Peixe-serra-verde';

  @override
  String get species_green_sawfish_desc =>
      'Grande peixe-serra de corpo verde-azeitona, que habita estuários do Indo-Pacífico ocidental.';

  @override
  String get species_devil_ray_name => 'Jamanta';

  @override
  String get species_devil_ray_desc =>
      'Grande mobula com barbatanas cefálicas, vista a saltar fora de água em grupo.';

  @override
  String get species_spinetail_devil_ray_name => 'Jamanta-de-cauda-espinhosa';

  @override
  String get species_spinetail_devil_ray_desc =>
      'Jamanta pelágica, avistada muitas vezes em grandes agregações junto à superfície.';

  @override
  String get species_lesser_devil_ray_name => 'Jamanta-pigmeia';

  @override
  String get species_lesser_devil_ray_desc =>
      'A mais pequena das mobulas, forma grandes cardumes no golfo da Califórnia.';

  @override
  String get species_bat_ray_name => 'Raia-morcego';

  @override
  String get species_bat_ray_desc =>
      'Raia em forma de losango, comum nas florestas de kelp e nas baías arenosas da Califórnia.';

  @override
  String get species_undulate_ray_name => 'Raia-curva';

  @override
  String get species_undulate_ray_desc =>
      'Raia de padrão belíssimo, com linhas onduladas, presente no Atlântico oriental.';

  @override
  String get species_thornback_ray_name => 'Raia-lenga';

  @override
  String get species_thornback_ray_desc =>
      'Raia europeia comum, com espinhos ao longo do dorso e da cauda.';

  @override
  String get species_cownose_ray_name => 'Raia-nariz-de-vaca';

  @override
  String get species_cownose_ray_desc =>
      'Cabeça com um entalhe característico; vista muitas vezes em grandes cardumes durante as migrações sazonais.';

  @override
  String get species_marble_ray_name => 'Uge-marmoreada';

  @override
  String get species_marble_ray_desc =>
      'Grande uge escura com pintas brancas, avistada com frequência em estações de limpeza do Indo-Pacífico.';

  @override
  String get species_ocellate_river_stingray_name => 'Raia-motoro';

  @override
  String get species_ocellate_river_stingray_desc =>
      'Raia de água doce com marcantes manchas de anel alaranjado, nativa dos rios da América do Sul.';

  @override
  String get species_ocellaris_clownfish_name => 'Peixe-palhaço-ocelar';

  @override
  String get species_ocellaris_clownfish_desc =>
      'Pequeno peixe laranja com riscas brancas, encontrado a viver em simbiose com anémonas nos recifes de coral.';

  @override
  String get species_clarkii_clownfish_name => 'Peixe-palhaço-de-Clark';

  @override
  String get species_clarkii_clownfish_desc =>
      'Peixe-palhaço resistente, de corpo escuro e duas barras brancas, presente em todo o Indo-Pacífico em várias espécies de anémona.';

  @override
  String get species_tomato_clownfish_name => 'Peixe-palhaço-tomate';

  @override
  String get species_tomato_clownfish_desc =>
      'Peixe-palhaço vermelho-alaranjado vivo, com uma única barra branca na cabeça, comum nos recifes do Indo-Pacífico.';

  @override
  String get species_regal_blue_tang_name => 'Cirurgião-azul-real';

  @override
  String get species_regal_blue_tang_desc =>
      'Peixe-cirurgião de azul intenso, com uma marca negra em forma de paleta e cauda amarela, presente nos recifes de coral do Indo-Pacífico.';

  @override
  String get species_yellow_tang_name => 'Cirurgião-amarelo';

  @override
  String get species_yellow_tang_desc =>
      'Peixe-cirurgião amarelo-vivo, comum nos recifes do Havai e do Pacífico, visto muitas vezes a pastar algas em grupo.';

  @override
  String get species_powder_blue_surgeonfish_name => 'Cirurgião-azul-celeste';

  @override
  String get species_powder_blue_surgeonfish_desc =>
      'Peixe-cirurgião de azul-claro marcante, com a face negra e a barbatana dorsal amarela, presente no oceano Índico.';

  @override
  String get species_sohal_surgeonfish_name => 'Cirurgião-sohal';

  @override
  String get species_sohal_surgeonfish_desc =>
      'Peixe-cirurgião listado e audaz, com o bisturi caudal alaranjado, endémico dos recifes do mar Vermelho e do golfo Arábico.';

  @override
  String get species_blue_tang_name => 'Cirurgião-azul-das-Caraíbas';

  @override
  String get species_blue_tang_desc =>
      'Peixe-cirurgião de azul profundo, comum nos recifes das Caraíbas; os juvenis são amarelo-vivos.';

  @override
  String get species_emperor_angelfish_name => 'Peixe-anjo-imperador';

  @override
  String get species_emperor_angelfish_desc =>
      'Grande peixe-anjo com marcantes riscas horizontais azuis e amarelas. Os juvenis exibem círculos concêntricos azuis e brancos.';

  @override
  String get species_french_angelfish_name => 'Peixe-anjo-francês';

  @override
  String get species_french_angelfish_desc =>
      'Grande peixe-anjo escuro, com escamas orladas a dourado, visto normalmente aos pares nos recifes das Caraíbas e do Atlântico ocidental.';

  @override
  String get species_queen_angelfish_name => 'Peixe-anjo-rainha';

  @override
  String get species_queen_angelfish_desc =>
      'Espetacular peixe-anjo azul e amarelo, com uma coroa distintiva na fronte, presente nos recifes de coral das Caraíbas.';

  @override
  String get species_regal_angelfish_name => 'Peixe-anjo-real';

  @override
  String get species_regal_angelfish_desc =>
      'Peixe-anjo elegante, com bandas verticais alternadas em laranja, branco e azul, presente nos recifes do Indo-Pacífico.';

  @override
  String get species_rock_beauty_name => 'Peixe-anjo-tricolor';

  @override
  String get species_rock_beauty_desc =>
      'Peixe-anjo marcante das Caraíbas, com a metade dianteira amarela e a traseira negra, presente junto a recifes rochosos e saliências.';

  @override
  String get species_gray_angelfish_name => 'Peixe-anjo-cinzento';

  @override
  String get species_gray_angelfish_desc =>
      'Grande peixe-anjo cinzento, com a face pálida e o interior da barbatana peitoral amarelo, comum nos recifes das Caraíbas.';

  @override
  String get species_copperband_butterflyfish_name =>
      'Peixe-borboleta-de-bandas-de-cobre';

  @override
  String get species_copperband_butterflyfish_desc =>
      'Peixe-borboleta inconfundível, com bandas verticais alaranjadas e focinho alongado, presente nos recifes do Indo-Pacífico.';

  @override
  String get species_raccoon_butterflyfish_name => 'Peixe-borboleta-guaxinim';

  @override
  String get species_raccoon_butterflyfish_desc =>
      'Peixe-borboleta amarelo com uma máscara escura à volta dos olhos, comum nos recifes do Indo-Pacífico e do Havai.';

  @override
  String get species_longnose_butterflyfish_name =>
      'Peixe-borboleta-de-focinho-comprido';

  @override
  String get species_longnose_butterflyfish_desc =>
      'Peixe-borboleta amarelo-vivo, com um focinho muito comprido que usa para retirar alimento das fendas dos recifes do Indo-Pacífico.';

  @override
  String get species_threadfin_butterflyfish_name =>
      'Peixe-borboleta-de-filamento';

  @override
  String get species_threadfin_butterflyfish_desc =>
      'Peixe-borboleta branco com padrão em galões e um filamento dorsal a arrastar, muito difundido pelo Indo-Pacífico.';

  @override
  String get species_foureye_butterflyfish_name =>
      'Peixe-borboleta-de-quatro-olhos';

  @override
  String get species_foureye_butterflyfish_desc =>
      'Peixe-borboleta pálido, com um falso olho bem visível junto à cauda, comum nos recifes das Caraíbas.';

  @override
  String get species_spotfin_butterflyfish_name =>
      'Peixe-borboleta-de-barbatana-manchada';

  @override
  String get species_spotfin_butterflyfish_desc =>
      'Peixe-borboleta branco e amarelo, com uma pequena mancha escura na barbatana dorsal, presente no Atlântico ocidental.';

  @override
  String get species_banner_butterflyfish_name =>
      'Peixe-bandeira-do-mar-Vermelho';

  @override
  String get species_banner_butterflyfish_desc =>
      'Peixe-bandeira preto e branco, com barbatana dorsal alongada e ventre amarelo, endémico do mar Vermelho.';

  @override
  String get species_moorish_idol_name => 'Ídolo-mourisco';

  @override
  String get species_moorish_idol_desc =>
      'Peixe de recife icónico, com bandas marcadas a preto, branco e amarelo e um longo filamento dorsal.';

  @override
  String get species_green_moray_eel_name => 'Moreia-verde';

  @override
  String get species_green_moray_eel_desc =>
      'Grande moreia verde que chega aos 2,5 m, vista muitas vezes de boca aberta nas fendas dos recifes do Atlântico ocidental.';

  @override
  String get species_giant_moray_eel_name => 'Moreia-gigante';

  @override
  String get species_giant_moray_eel_desc =>
      'A maior espécie de moreia, com mais de 3 m e manchas semelhantes às de um leopardo. Presente nos recifes de coral do Indo-Pacífico.';

  @override
  String get species_spotted_moray_eel_name => 'Moreia-pintada';

  @override
  String get species_spotted_moray_eel_desc =>
      'Moreia branca com manchas castanho-escuras, encontrada normalmente a espreitar de buracos do recife nas Caraíbas.';

  @override
  String get species_ribbon_eel_name => 'Moreia-fita';

  @override
  String get species_ribbon_eel_desc =>
      'Moreia esguia de narinas em leque; os machos são azul-vivos e as fêmeas amarelas. Presente em lagunas arenosas do Indo-Pacífico.';

  @override
  String get species_spotted_garden_eel_name => 'Enguia-de-jardim-pintada';

  @override
  String get species_spotted_garden_eel_desc =>
      'Enguia branca e fina com pintas negras que vive em colónias na areia, ondulando na corrente para capturar plâncton.';

  @override
  String get species_splendid_garden_eel_name => 'Enguia-de-jardim-esplêndida';

  @override
  String get species_splendid_garden_eel_desc =>
      'Enguia-de-jardim com bandas laranja e brancas, presente em grandes colónias arenosas do Pacífico ocidental.';

  @override
  String get species_snowflake_moray_name => 'Moreia-floco-de-neve';

  @override
  String get species_snowflake_moray_desc =>
      'Pequena moreia de corpo branco com marcas negras em forma de floco de neve, comum nos cascalhos de recife do Indo-Pacífico.';

  @override
  String get species_mandarin_dragonet_name => 'Peixe-mandarim';

  @override
  String get species_mandarin_dragonet_desc =>
      'Peixe minúsculo de cores brilhantes, com padrões psicadélicos em azul e laranja, presente nas zonas de cascalho do Pacífico ocidental.';

  @override
  String get species_common_lionfish_name => 'Peixe-leão-comum';

  @override
  String get species_common_lionfish_desc =>
      'Peixe-escorpião venenoso, com barbatanas peitorais em leque e riscas vermelhas e brancas. Invasor nas Caraíbas.';

  @override
  String get species_leaf_scorpionfish_name => 'Peixe-escorpião-folha';

  @override
  String get species_leaf_scorpionfish_desc =>
      'Peixe-escorpião muito comprimido, em forma de folha, que baloiça com a corrente para imitar detritos nos recifes do Indo-Pacífico.';

  @override
  String get species_stonefish_name => 'Peixe-pedra';

  @override
  String get species_stonefish_desc =>
      'O peixe mais venenoso do mundo, camuflado na perfeição como uma rocha nos fundos de recife do Indo-Pacífico. Extremamente perigoso.';

  @override
  String get species_painted_frogfish_name => 'Peixe-sapo-pintado';

  @override
  String get species_painted_frogfish_desc =>
      'Predador de emboscada atarracado, com um engodo na cabeça e cor muito variável. Presente nos recifes do Indo-Pacífico.';

  @override
  String get species_giant_frogfish_name => 'Peixe-sapo-gigante';

  @override
  String get species_giant_frogfish_desc =>
      'A maior espécie de peixe-sapo, com até 40 cm, e uma camuflagem excelente entre esponjas e cascalho de coral.';

  @override
  String get species_hairy_frogfish_name => 'Peixe-sapo-peludo';

  @override
  String get species_hairy_frogfish_desc =>
      'Peixe-sapo coberto de apêndices carnudos semelhantes a vermes que imitam algas, um achado cobiçado pelos fotógrafos subaquáticos.';

  @override
  String get species_clown_triggerfish_name => 'Peixe-porco-palhaço';

  @override
  String get species_clown_triggerfish_desc =>
      'Peixe-porco de padrão marcante, com grandes pintas brancas sobre corpo escuro e lábios amarelos, presente nos recifes do Indo-Pacífico.';

  @override
  String get species_titan_triggerfish_name => 'Peixe-porco-titã';

  @override
  String get species_titan_triggerfish_desc =>
      'Grande peixe-porco agressivo, conhecido por investir contra os mergulhadores junto ao ninho. Comum nos recifes de coral do Indo-Pacífico.';

  @override
  String get species_queen_triggerfish_name => 'Peixe-porco-rainha';

  @override
  String get species_queen_triggerfish_desc =>
      'Peixe-porco colorido das Caraíbas, com marcas azuis na face e longos filamentos caudais.';

  @override
  String get species_picasso_triggerfish_name => 'Peixe-porco-picasso';

  @override
  String get species_picasso_triggerfish_desc =>
      'Peixe-porco com um padrão abstrato de riscas azuis, amarelas e negras, comum nos planaltos de recife do Indo-Pacífico.';

  @override
  String get species_yellowmargin_triggerfish_name =>
      'Peixe-porco-de-margem-amarela';

  @override
  String get species_yellowmargin_triggerfish_desc =>
      'Grande peixe-porco de tom castanho-claro, com as barbatanas orladas de amarelo, conhecido por defender o ninho com agressividade nos recifes do Indo-Pacífico.';

  @override
  String get species_porcupinefish_name => 'Peixe-ouriço';

  @override
  String get species_porcupinefish_desc =>
      'Grande peixe espinhoso que se insufla como uma bola quando ameaçado, presente em recifes tropicais de todo o mundo.';

  @override
  String get species_guineafowl_pufferfish_name =>
      'Peixe-balão-de-pintas-brancas';

  @override
  String get species_guineafowl_pufferfish_desc =>
      'Peixe-balão escuro coberto de pequenas pintas brancas, por vezes numa fase de cor amarelo-dourada, nos recifes do Indo-Pacífico.';

  @override
  String get species_map_pufferfish_name => 'Peixe-balão-mapa';

  @override
  String get species_map_pufferfish_desc =>
      'Grande peixe-balão pálido, com marcas escuras intrincadas semelhantes a um mapa, presente nos recifes do Indo-Pacífico.';

  @override
  String get species_sharpnose_pufferfish_name =>
      'Peixe-balão-de-focinho-afiado';

  @override
  String get species_sharpnose_pufferfish_desc =>
      'Peixe-balão minúsculo, com linhas azuis na face e cauda alaranjada, visto com frequência nos recifes das Caraíbas.';

  @override
  String get species_boxfish_name => 'Peixe-cofre-amarelo';

  @override
  String get species_boxfish_desc =>
      'Os juvenis são cubos amarelo-vivos com pintas negras. Os adultos escurecem para cinzento-azulado. Presente em todo o Indo-Pacífico.';

  @override
  String get species_cowfish_name => 'Peixe-vaca-de-chifres-longos';

  @override
  String get species_cowfish_desc =>
      'Peixe amarelo de corpo cúbico, com projeções em forma de chifre sobre cada olho, presente nos recifes do Indo-Pacífico.';

  @override
  String get species_napoleon_wrasse_name => 'Bodião-napoleão';

  @override
  String get species_napoleon_wrasse_desc =>
      'Bodião enorme, com até 2 m e uma protuberância frontal proeminente. Ameaçado e protegido, presente nos recifes do Indo-Pacífico.';

  @override
  String get species_cleaner_wrasse_name => 'Bodião-limpador';

  @override
  String get species_cleaner_wrasse_desc =>
      'Pequeno bodião de riscas azuis que gere estações de limpeza, retirando parasitas a peixes maiores nos recifes do Indo-Pacífico.';

  @override
  String get species_yellowtail_coris_name => 'Coris-de-cauda-amarela';

  @override
  String get species_yellowtail_coris_desc =>
      'Bodião colorido, de corpo pintalgado e cauda amarela; os juvenis são laranja-avermelhados com marcas brancas.';

  @override
  String get species_bluehead_wrasse_name => 'Bodião-de-cabeça-azul';

  @override
  String get species_bluehead_wrasse_desc =>
      'Bodião abundante nas Caraíbas; os machos terminais têm a cabeça azul-viva e o corpo verde com barras pretas e brancas.';

  @override
  String get species_spanish_hogfish_name => 'Bodião-espanhol';

  @override
  String get species_spanish_hogfish_desc =>
      'Bodião roxo e amarelo, comum nos recifes das Caraíbas; os juvenis atuam como peixes-limpadores.';

  @override
  String get species_bumphead_parrotfish_name =>
      'Peixe-papagaio-de-cabeça-gibosa';

  @override
  String get species_bumphead_parrotfish_desc =>
      'A maior espécie de peixe-papagaio, com até 1,3 m e uma enorme protuberância frontal. Desloca-se em cardumes nos recifes do Indo-Pacífico.';

  @override
  String get species_stoplight_parrotfish_name => 'Peixe-papagaio-semáforo';

  @override
  String get species_stoplight_parrotfish_desc =>
      'Peixe-papagaio comum das Caraíbas, com mudanças de cor dramáticas entre a fase inicial e a terminal.';

  @override
  String get species_queen_parrotfish_name => 'Peixe-papagaio-rainha';

  @override
  String get species_queen_parrotfish_desc =>
      'Grande peixe-papagaio azul-esverdeado dos recifes das Caraíbas, visto muitas vezes a morder o coral para se alimentar de algas.';

  @override
  String get species_yellowtail_damselfish_name => 'Donzela-de-cauda-amarela';

  @override
  String get species_yellowtail_damselfish_desc =>
      'Donzela azul-escura com a cauda amarelo-viva, comum nos topos e cristas dos recifes das Caraíbas.';

  @override
  String get species_sergeant_major_name => 'Sargento';

  @override
  String get species_sergeant_major_desc =>
      'Donzela prateada e amarela, com cinco barras negras bem marcadas, presente em grandes agregações nos recifes do Atlântico tropical.';

  @override
  String get species_three_spot_damselfish_name => 'Donzela-de-três-manchas';

  @override
  String get species_three_spot_damselfish_desc =>
      'Donzela castanho-escura e territorial, que defende com agressividade o seu jardim de algas nos recifes das Caraíbas.';

  @override
  String get species_chromis_viridis_name => 'Castanheta-verde-azulada';

  @override
  String get species_chromis_viridis_desc =>
      'Pequena castanheta verde iridescente, vista em grandes cardumes a pairar sobre corais ramificados nos recifes do Indo-Pacífico.';

  @override
  String get species_blue_chromis_name => 'Castanheta-azul';

  @override
  String get species_blue_chromis_desc =>
      'Castanheta planctívora de azul brilhante, encontrada em grandes agregações a meia-água sobre as paredes de recife das Caraíbas.';

  @override
  String get species_nassau_grouper_name => 'Garoupa-de-Nassau';

  @override
  String get species_nassau_grouper_desc =>
      'Grande garoupa das Caraíbas, com uma risca ocular escura e padrão de bandas, hoje ameaçada devido à sobrepesca.';

  @override
  String get species_giant_grouper_name => 'Mero-gigante';

  @override
  String get species_giant_grouper_desc =>
      'O maior peixe ósseo de recife, com até 2,7 m e 400 kg. Presente em grutas e destroços de todo o Indo-Pacífico.';

  @override
  String get species_coral_grouper_name => 'Garoupa-de-coral';

  @override
  String get species_coral_grouper_desc =>
      'Garoupa vermelho-alaranjada viva coberta de pintas azuis, uma espécie emblemática dos recifes de coral do Indo-Pacífico.';

  @override
  String get species_goliath_grouper_name => 'Mero-golias';

  @override
  String get species_goliath_grouper_desc =>
      'Mero atlântico enorme, com até 2,5 m, encontrado muitas vezes junto a destroços e saliências na Florida e nas Caraíbas.';

  @override
  String get species_potato_grouper_name => 'Garoupa-batata';

  @override
  String get species_potato_grouper_desc =>
      'Garoupa grande e sociável, com manchas escuras em forma de batata, célebre no Cod Hole da Grande Barreira de Coral.';

  @override
  String get species_peacock_grouper_name => 'Garoupa-pavão';

  @override
  String get species_peacock_grouper_desc =>
      'Garoupa castanho-escura com pintas azuis vivas e barras verticais claras na parte traseira, comum nos recifes do Indo-Pacífico.';

  @override
  String get species_yellowfin_tuna_name => 'Atum-albacora';

  @override
  String get species_yellowfin_tuna_desc =>
      'Predador pelágico veloz, com longas barbatanas dorsal e anal amarelas, avistado ocasionalmente pelos mergulhadores em locais ao largo.';

  @override
  String get species_dogtooth_tuna_name => 'Atum-dentudo';

  @override
  String get species_dogtooth_tuna_desc =>
      'Atum potente associado aos recifes, de dentes bem visíveis, encontrado em paredes profundas do Indo-Pacífico.';

  @override
  String get species_great_barracuda_name => 'Barracuda-gigante';

  @override
  String get species_great_barracuda_desc =>
      'Predador prateado e esguio, com até 1,8 m e dentes bem visíveis, visto muitas vezes a pairar imóvel junto aos recifes tropicais.';

  @override
  String get species_blackfin_barracuda_name =>
      'Barracuda-de-barbatanas-negras';

  @override
  String get species_blackfin_barracuda_desc =>
      'Barracuda do Indo-Pacífico conhecida por formar enormes cardumes em espiral em locais como Barracuda Point.';

  @override
  String get species_mahi_mahi_name => 'Dourado';

  @override
  String get species_mahi_mahi_desc =>
      'Peixe pelágico deslumbrante em verde-azulado e dourado, de fronte alta, avistado ocasionalmente em locais de mergulho ao largo.';

  @override
  String get species_giant_trevally_name => 'Xaréu-gigante';

  @override
  String get species_giant_trevally_desc =>
      'Predador prateado poderoso, com até 1,7 m, conhecido por caçar em canais e paredes de recife de todo o Indo-Pacífico.';

  @override
  String get species_bluefin_trevally_name => 'Xaréu-de-barbatanas-azuis';

  @override
  String get species_bluefin_trevally_desc =>
      'Xaréu esguio com pintas azuis, visto com frequência a patrulhar em pequenos grupos de caça os bordos dos recifes do Indo-Pacífico.';

  @override
  String get species_bigeye_trevally_name => 'Xaréu-olhudo';

  @override
  String get species_bigeye_trevally_desc =>
      'Xaréu prateado de olhos grandes que forma cardumes impressionantes em redemoinho junto a paredes e estações de limpeza.';

  @override
  String get species_bar_jack_name => 'Xaréu-de-barra';

  @override
  String get species_bar_jack_desc =>
      'Xaréu prateado e esguio das Caraíbas, com uma risca azul-escura marcante ao longo do dorso que se prolonga até ao lobo inferior da cauda.';

  @override
  String get species_horse_eye_jack_name => 'Xaréu-olho-de-boi';

  @override
  String get species_horse_eye_jack_desc =>
      'Xaréu prateado de olhos grandes que forma cardumes junto a recifes e destroços nas Caraíbas e no Atlântico ocidental.';

  @override
  String get species_yellowtail_snapper_name => 'Luciano-de-cauda-amarela';

  @override
  String get species_yellowtail_snapper_desc =>
      'Luciano esguio com uma risca lateral e cauda amarelas, visto muitas vezes em cardumes a meia-água nos recifes das Caraíbas.';

  @override
  String get species_schoolmaster_snapper_name => 'Luciano-mestre-escola';

  @override
  String get species_schoolmaster_snapper_desc =>
      'Luciano amarelo e prateado, com linhas azuis sob o olho, encontrado em grupo sob saliências nos recifes das Caraíbas.';

  @override
  String get species_bluestripe_snapper_name => 'Luciano-de-riscas-azuis';

  @override
  String get species_bluestripe_snapper_desc =>
      'Luciano amarelo-vivo com quatro riscas azuis horizontais, que forma cardumes densos nos recifes do Indo-Pacífico.';

  @override
  String get species_twinspot_snapper_name => 'Luciano-de-duas-manchas';

  @override
  String get species_twinspot_snapper_desc =>
      'Grande luciano vermelho dos recifes exteriores do Indo-Pacífico, por vezes em cardumes em paredes profundas e canais.';

  @override
  String get species_humphead_snapper_name => 'Luciano-da-meia-noite';

  @override
  String get species_humphead_snapper_desc =>
      'Grande luciano escuro encontrado em cardumes junto a paredes íngremes do Indo-Pacífico; os juvenis são vistosamente pretos e brancos.';

  @override
  String get species_longfin_bannerfish_name =>
      'Peixe-bandeira-de-barbatana-longa';

  @override
  String get species_longfin_bannerfish_desc =>
      'Peixe preto e branco com uma longa barbatana dorsal a arrastar e cauda amarela, visto muitas vezes aos pares nos recifes do Indo-Pacífico.';

  @override
  String get species_batfish_orbicular_name => 'Peixe-morcego-orbicular';

  @override
  String get species_batfish_orbicular_desc =>
      'Peixe prateado em forma de disco, de barbatanas altas, que se aproxima dos mergulhadores por curiosidade. Comum em destroços e recifes do Indo-Pacífico.';

  @override
  String get species_batfish_teira_name => 'Peixe-morcego-de-barbatana-longa';

  @override
  String get species_batfish_teira_desc =>
      'Peixe-morcego de barbatanas altas, com uma mancha escura junto à barbatana peitoral, visto muitas vezes em estações de limpeza e destroços.';

  @override
  String get species_batfish_pinnatus_name => 'Peixe-morcego-pinado';

  @override
  String get species_batfish_pinnatus_desc =>
      'Os juvenis são negros com bordos laranja vivos, lembrando um platelminte tóxico. Presente no Pacífico ocidental.';

  @override
  String get species_banggai_cardinalfish_name => 'Peixe-cardeal-de-Banggai';

  @override
  String get species_banggai_cardinalfish_desc =>
      'Peixe-cardeal marcante, prateado e negro, de barbatanas alongadas, endémico das ilhas Banggai, na Indonésia.';

  @override
  String get species_pajama_cardinalfish_name => 'Peixe-cardeal-pijama';

  @override
  String get species_pajama_cardinalfish_desc =>
      'Peixe-cardeal invulgar, com a face amarela, uma faixa escura a meio e a traseira pintalgada, encontrado entre corais no Indo-Pacífico.';

  @override
  String get species_longnose_hawkfish_name =>
      'Peixe-falcão-de-focinho-comprido';

  @override
  String get species_longnose_hawkfish_desc =>
      'Peixe pequeno e branco, com um padrão vermelho quadriculado e focinho alongado, que pousa em gorgónias e corais negros.';

  @override
  String get species_arc_eye_hawkfish_name => 'Peixe-falcão-de-arco-ocular';

  @override
  String get species_arc_eye_hawkfish_desc =>
      'Pequeno peixe-falcão com um arco laranja distintivo atrás do olho, muitas vezes pousado em cabeços de coral nos recifes do Indo-Pacífico.';

  @override
  String get species_flame_hawkfish_name => 'Peixe-falcão-chama';

  @override
  String get species_flame_hawkfish_desc =>
      'Peixe-falcão vermelho brilhante, com marcas escuras à volta dos olhos, que pousa em corais Pocillopora por todo o Pacífico ocidental.';

  @override
  String get species_fire_goby_name => 'Góbio-de-fogo';

  @override
  String get species_fire_goby_desc =>
      'Góbio branco e elegante, com a primeira barbatana dorsal alta e a cauda vermelho-alaranjada, paira sobre o cascalho dos recifes do Indo-Pacífico.';

  @override
  String get species_purple_firefish_name => 'Peixe-de-fogo-roxo';

  @override
  String get species_purple_firefish_desc =>
      'Góbio delicado, de barbatanas roxas e espinho dorsal alto, que paira junto às tocas nos recifes exteriores do Indo-Pacífico.';

  @override
  String get species_yellownose_goby_name => 'Góbio-de-focinho-amarelo';

  @override
  String get species_yellownose_goby_desc =>
      'Minúsculo góbio-limpador das Caraíbas, com o focinho amarelo e uma risca lateral azul, encontrado em esponjas e cabeços de coral.';

  @override
  String get species_citron_goby_name => 'Góbio-citrino';

  @override
  String get species_citron_goby_desc =>
      'Góbio minúsculo, de amarelo vivo, que vive entre os ramos dos corais Acropora nos recifes do Indo-Pacífico.';

  @override
  String get species_shrimp_goby_name => 'Góbio-de-camarão-de-Steinitz';

  @override
  String get species_shrimp_goby_desc =>
      'Góbio cor de areia que partilha uma toca com camarões alfeídeos numa relação mutualista, nas planícies arenosas do Indo-Pacífico.';

  @override
  String get species_neon_goby_name => 'Góbio-néon';

  @override
  String get species_neon_goby_desc =>
      'Góbio minúsculo e escuro, com uma risca azul-néon brilhante, que gere estações de limpeza em cabeços de coral das Caraíbas.';

  @override
  String get species_bluestriped_fangblenny_name =>
      'Caboz-de-presas-de-riscas-azuis';

  @override
  String get species_bluestriped_fangblenny_desc =>
      'Pequeno caboz de riscas azuis que imita os bodiões-limpadores para arrancar escamas a peixes desprevenidos.';

  @override
  String get species_sailfin_blenny_name => 'Caboz-de-vela';

  @override
  String get species_sailfin_blenny_desc =>
      'Minúsculo caboz das Caraíbas que ergue uma grande barbatana dorsal em forma de vela à saída do seu tubo para atrair parceiras.';

  @override
  String get species_bicolor_blenny_name => 'Caboz-bicolor';

  @override
  String get species_bicolor_blenny_desc =>
      'Pequeno caboz com a metade dianteira castanho-escura e a traseira laranja, que espreita de buracos nos recifes do Indo-Pacífico.';

  @override
  String get species_redlip_blenny_name => 'Caboz-de-lábios-vermelhos';

  @override
  String get species_redlip_blenny_desc =>
      'Caboz escuro, de lábios vermelho-alaranjados bem visíveis, que defende manchas de algas nas cristas dos recifes das Caraíbas.';

  @override
  String get species_pygmy_seahorse_name =>
      'Cavalo-marinho-pigmeu-de-Bargibant';

  @override
  String get species_pygmy_seahorse_desc =>
      'Cavalo-marinho minúsculo, com menos de 2 cm, que iguala na perfeição a gorgónia onde vive, um objeto cobiçado da fotografia macro.';

  @override
  String get species_common_seahorse_name => 'Cavalo-marinho-comum';

  @override
  String get species_common_seahorse_desc =>
      'Cavalo-marinho de tamanho médio, presente em pradarias marinhas e cascalho de coral de todo o Indo-Pacífico, de cor variável.';

  @override
  String get species_thorny_seahorse_name => 'Cavalo-marinho-espinhoso';

  @override
  String get species_thorny_seahorse_desc =>
      'Cavalo-marinho coberto de espinhos longos, presente em pradarias marinhas e fundos moles de todo o Indo-Pacífico.';

  @override
  String get species_ornate_ghost_pipefish_name =>
      'Peixe-cachimbo-fantasma-ornamentado';

  @override
  String get species_ornate_ghost_pipefish_desc =>
      'Peixe-cachimbo de camuflagem elaborada, que paira de cabeça para baixo junto a crinoides e corais moles no Indo-Pacífico.';

  @override
  String get species_robust_ghost_pipefish_name =>
      'Peixe-cachimbo-fantasma-robusto';

  @override
  String get species_robust_ghost_pipefish_desc =>
      'Grande peixe-cachimbo-fantasma que imita ervas marinhas ou algas, encontrado muitas vezes aos pares em águas costeiras do Indo-Pacífico.';

  @override
  String get species_trumpetfish_name => 'Peixe-trombeta';

  @override
  String get species_trumpetfish_desc =>
      'Peixe comprido e esguio que caça acompanhando a sombra de peixes maiores, presente em várias cores nos recifes das Caraíbas e do Atlântico.';

  @override
  String get species_cornetfish_name => 'Peixe-corneta';

  @override
  String get species_cornetfish_desc =>
      'Peixe extremamente alongado, com até 1,5 m e um filamento caudal a arrastar, visto muitas vezes a planar sobre os planaltos de recife.';

  @override
  String get species_yellowhead_jawfish_name =>
      'Peixe-mandíbula-de-cabeça-amarela';

  @override
  String get species_yellowhead_jawfish_desc =>
      'Peixe pequeno de corpo azul e cabeça amarela, que paira sobre a sua toca de areia nos recifes das Caraíbas. Os machos incubam os ovos na boca.';

  @override
  String get species_flamefish_name => 'Peixe-cardeal-chama';

  @override
  String get species_flamefish_desc =>
      'Pequeno peixe-cardeal vermelho-vivo, com uma mancha escura sob a segunda barbatana dorsal, que se esconde de dia nas fendas dos recifes das Caraíbas.';

  @override
  String get species_longspine_squirrelfish_name =>
      'Peixe-esquilo-de-espinho-longo';

  @override
  String get species_longspine_squirrelfish_desc =>
      'Peixe noturno vermelho, de olhos grandes e espinho dorsal comprido, encontrado de dia sob saliências nos recifes das Caraíbas.';

  @override
  String get species_soldierfish_name => 'Peixe-soldado-de-escamas-grandes';

  @override
  String get species_soldierfish_desc =>
      'Peixe noturno vermelho, de olhos escuros enormes e escamas grandes, que forma grupos em grutas e abrigos durante o dia.';

  @override
  String get species_flame_angelfish_name => 'Peixe-anjo-chama';

  @override
  String get species_flame_angelfish_desc =>
      'Peixe-anjo anão de vermelho-alaranjado brilhante, com barras verticais negras e barbatanas de pontas azuis, presente em todo o Pacífico.';

  @override
  String get species_royal_gramma_name => 'Gramma-real';

  @override
  String get species_royal_gramma_desc =>
      'Pequeno peixe bicolor das Caraíbas, com a metade dianteira roxa e a traseira amarela, encontrado sob saliências.';

  @override
  String get species_anthias_lyretail_name => 'Antias-de-cauda-de-lira';

  @override
  String get species_anthias_lyretail_desc =>
      'Peixe de recife abundante que forma grandes nuvens laranja e rosa sobre as formações de coral do Indo-Pacífico. Os machos são roxos.';

  @override
  String get species_mediterranean_grouper_name => 'Mero';

  @override
  String get species_mediterranean_grouper_desc =>
      'Grande garoupa castanho-escura com manchas claras, o predador emblemático dos recifes rochosos do Mediterrâneo.';

  @override
  String get species_mediterranean_moray_name => 'Moreia-do-Mediterrâneo';

  @override
  String get species_mediterranean_moray_desc =>
      'Moreia castanho-escura com manchas amareladas, vista com frequência a espreitar das fendas rochosas do Mediterrâneo.';

  @override
  String get species_ornate_wrasse_name => 'Peixe-verde';

  @override
  String get species_ornate_wrasse_desc =>
      'Bodião verde e colorido, com marcas vermelhas na cabeça, um dos bodiões mais comuns dos recifes do Mediterrâneo.';

  @override
  String get species_red_sea_bannerfish_name => 'Peixe-borboleta-mascarado';

  @override
  String get species_red_sea_bannerfish_desc =>
      'Peixe-borboleta amarelo-vivo com uma máscara escura sobre os olhos, endémico do mar Vermelho. Visto muitas vezes aos pares.';

  @override
  String get species_red_sea_anemonefish_name =>
      'Peixe-palhaço-do-mar-Vermelho';

  @override
  String get species_red_sea_anemonefish_desc =>
      'Peixe-palhaço amarelo-alaranjado com duas barras brancas, endémico do mar Vermelho e do golfo de Áden.';

  @override
  String get species_arabian_angelfish_name => 'Peixe-anjo-arábico';

  @override
  String get species_arabian_angelfish_desc =>
      'Grande peixe-anjo azul-escuro com uma barra vertical e cauda amarelas bem marcadas, endémico do oceano Índico ocidental.';

  @override
  String get species_king_angelfish_name => 'Peixe-anjo-rei';

  @override
  String get species_king_angelfish_desc =>
      'Grande peixe-anjo azul-escuro com uma barra vertical branca e cauda amarela, presente no Pacífico oriental e nos Galápagos.';

  @override
  String get species_ocean_sunfish_name => 'Peixe-lua';

  @override
  String get species_ocean_sunfish_desc =>
      'O peixe ósseo mais pesado do mundo, com mais de 2 toneladas. Avistado ocasionalmente em estações de limpeza em Bali e nos Galápagos.';

  @override
  String get species_lingcod_name => 'Lingcod';

  @override
  String get species_lingcod_desc =>
      'Grande predador malhado dos recifes rochosos do noroeste do Pacífico, encontrado muitas vezes a guardar massas de ovos.';

  @override
  String get species_wolf_eel_name => 'Peixe-lobo-do-Pacífico';

  @override
  String get species_wolf_eel_desc =>
      'Grande peixe-lobo cinzento, de cabeça bolbosa e mandíbulas potentes, encontrado em covis rochosos no noroeste do Pacífico.';

  @override
  String get species_giant_sea_bass_name => 'Robalo-gigante';

  @override
  String get species_giant_sea_bass_desc =>
      'Robalo enorme, com mais de 2 m e 250 kg, presente em recifes rochosos e florestas de kelp ao largo do sul da Califórnia.';

  @override
  String get species_garibaldi_name => 'Garibaldi';

  @override
  String get species_garibaldi_desc =>
      'Donzela laranja-viva e peixe marinho oficial da Califórnia, territorial nos recifes das florestas de kelp.';

  @override
  String get species_sheephead_name => 'Bodião-da-Califórnia';

  @override
  String get species_sheephead_desc =>
      'Grande bodião com a cabeça e a cauda negras, o meio vermelho e o queixo branco. Presente nas florestas de kelp da Califórnia.';

  @override
  String get species_copper_rockfish_name => 'Cantarilho-cobre';

  @override
  String get species_copper_rockfish_desc =>
      'Cantarilho laranja-acobreado com manchas claras, presença comum nos recifes rochosos e florestas de kelp do noroeste do Pacífico.';

  @override
  String get species_oriental_sweetlips_name => 'Peixe-lábios-doces-oriental';

  @override
  String get species_oriental_sweetlips_desc =>
      'Grande peixe de recife do Indo-Pacífico, com riscas pretas e brancas marcadas e barbatanas amarelas. Os juvenis fazem uma dança ondulante.';

  @override
  String get species_harlequin_sweetlips_name => 'Peixe-lábios-doces-arlequim';

  @override
  String get species_harlequin_sweetlips_desc =>
      'Os adultos são cinzentos com manchas escuras; os juvenis são castanhos com grandes pintas brancas e nadam com um movimento ondulante.';

  @override
  String get species_blue_ringed_angelfish_name => 'Peixe-anjo-de-anel-azul';

  @override
  String get species_blue_ringed_angelfish_desc =>
      'Grande peixe-anjo castanho com linhas azuis curvas e um anel azul distintivo por cima do opérculo.';

  @override
  String get species_yellowbar_angelfish_name => 'Peixe-anjo-de-barra-amarela';

  @override
  String get species_yellowbar_angelfish_desc =>
      'Grande peixe-anjo cinzento-azulado com uma mancha amarela bem visível no corpo, presente no mar Vermelho e no oceano Índico ocidental.';

  @override
  String get species_filefish_scrawled_name => 'Peixe-lima-rabiscado';

  @override
  String get species_filefish_scrawled_desc =>
      'Grande peixe-lima castanho-azeitona, com marcas azuis semelhantes a rabiscos e barbela laranja, presente em recifes tropicais de todo o mundo.';

  @override
  String get species_clown_filefish_name => 'Peixe-lima-de-pintas-laranja';

  @override
  String get species_clown_filefish_desc =>
      'Pequeno peixe-lima verde com pintas laranja e focinho comprido, que se alimenta exclusivamente de pólipos de coral Acropora.';

  @override
  String get species_unicornfish_name => 'Peixe-unicórnio-de-espinho-azul';

  @override
  String get species_unicornfish_desc =>
      'Peixe-cirurgião cinzento com um corno frontal proeminente e dois espinhos caudais azuis, comum nos planaltos de recife do Indo-Pacífico.';

  @override
  String get species_surgeonfish_sailfin_name => 'Cirurgião-de-vela';

  @override
  String get species_surgeonfish_sailfin_desc =>
      'Peixe-cirurgião de bandas marcadas, com as barbatanas dorsal e anal muito desenvolvidas, presente em todo o Indo-Pacífico.';

  @override
  String get species_achilles_tang_name => 'Cirurgião-de-Aquiles';

  @override
  String get species_achilles_tang_desc =>
      'Peixe-cirurgião castanho-escuro com uma marcante lágrima laranja junto à cauda, presente nas zonas de rebentação do Pacífico central.';

  @override
  String get species_doctorfish_name => 'Cirurgião-doutor';

  @override
  String get species_doctorfish_desc =>
      'Peixe-cirurgião castanho-acinzentado com barras escuras ténues e um bisturi caudal bem visível, comum nos recifes das Caraíbas.';

  @override
  String get species_checkerboard_wrasse_name => 'Bodião-xadrez';

  @override
  String get species_checkerboard_wrasse_desc =>
      'Bodião colorido com um padrão axadrezado de quadrados verdes, rosa e negros por todo o corpo.';

  @override
  String get species_bird_wrasse_name => 'Bodião-pássaro';

  @override
  String get species_bird_wrasse_desc =>
      'Bodião de focinho extremamente alongado, semelhante a um bico de ave; os machos são verde-escuros e as fêmeas castanhas.';

  @override
  String get species_sling_jaw_wrasse_name => 'Bodião-de-mandíbula-projetável';

  @override
  String get species_sling_jaw_wrasse_desc =>
      'Bodião com uma mandíbula extensível que dispara para a frente para capturar presas, existente em variantes amarela ou castanha.';

  @override
  String get species_peacock_flounder_name => 'Linguado-pavão';

  @override
  String get species_peacock_flounder_desc =>
      'Peixe achatado de fundo, com anéis e pintas azuis, capaz de mudar de cor para se igualar ao substrato.';

  @override
  String get species_hogfish_name => 'Bodião-porco';

  @override
  String get species_hogfish_desc =>
      'Grande bodião do Atlântico ocidental, com focinho de porco e espinhos dorsais alongados, encontrado junto a recifes e destroços.';

  @override
  String get species_tarpon_name => 'Tarpão-do-Atlântico';

  @override
  String get species_tarpon_desc =>
      'Peixe prateado enorme, de escamas grandes como espelhos, encontrado por vezes pelos mergulhadores em grutas e canais das Caraíbas.';

  @override
  String get species_permit_name => 'Pampo-real';

  @override
  String get species_permit_desc =>
      'Xaréu prateado de corpo alto e cauda escura bifurcada, presente nas planícies arenosas e junto aos recifes das Caraíbas.';

  @override
  String get species_spotted_drum_name => 'Peixe-tambor-pintado';

  @override
  String get species_spotted_drum_desc =>
      'Peixe marcante das Caraíbas, com uma barbatana dorsal alta e alongada e um padrão vistoso de pintas pretas e brancas.';

  @override
  String get species_jackknife_fish_name => 'Peixe-canivete';

  @override
  String get species_jackknife_fish_desc =>
      'Peixe elegante das Caraíbas, com uma risca dorsal negra alta e uma banda diagonal no corpo, encontrado sob saliências.';

  @override
  String get species_bigeye_name => 'Olho-de-vidro';

  @override
  String get species_bigeye_desc =>
      'Peixe noturno vermelho-vivo, de olhos grandes e refletores, encontrado escondido em grutas nos recifes das Caraíbas e do Atlântico.';

  @override
  String get species_remora_name => 'Rémora';

  @override
  String get species_remora_desc =>
      'Peixe esguio com um disco de sucção na cabeça, que se faz transportar por tubarões, raias, tartarugas e outros animais grandes.';

  @override
  String get species_tilefish_sand_name => 'Peixe-azulejo-da-areia';

  @override
  String get species_tilefish_sand_desc =>
      'Peixe alongado de azul-claro que constrói montículos de cascalho sobre as zonas arenosas dos recifes das Caraíbas.';

  @override
  String get species_weedy_seadragon_name => 'Dragão-marinho-comum';

  @override
  String get species_weedy_seadragon_desc =>
      'Parente ornamentado dos cavalos-marinhos, com apêndices em forma de folha, endémico das águas temperadas do sul da Austrália.';

  @override
  String get species_leafy_seadragon_name => 'Dragão-marinho-folhado';

  @override
  String get species_leafy_seadragon_desc =>
      'Dragão-marinho espetacular, coberto de elaboradas projeções em forma de folha, endémico do sul da Austrália. Um avistamento de sonho.';

  @override
  String get species_sailfin_snapper_name => 'Luciano-de-vela';

  @override
  String get species_sailfin_snapper_desc =>
      'Luciano elegante, amarelo e azul, com as barbatanas dorsal e anal alongadas, presente nas encostas de recife do Indo-Pacífico.';

  @override
  String get species_sweetlip_emperor_name => 'Imperador-salpicado';

  @override
  String get species_sweetlip_emperor_desc =>
      'Grande imperador prateado, com linhas azuis na face e bordos das barbatanas amarelos, comum nas zonas arenosas de recife do Indo-Pacífico.';

  @override
  String get species_crocodilefish_name => 'Peixe-crocodilo';

  @override
  String get species_crocodilefish_desc =>
      'Predador de emboscada de cabeça achatada, com franjas elaboradas nos olhos, que fica perfeitamente camuflado nos fundos de recife do Indo-Pacífico.';

  @override
  String get species_devil_scorpionfish_name => 'Peixe-escorpião-diabo';

  @override
  String get species_devil_scorpionfish_desc =>
      'Peixe-escorpião robusto e camuflado, que exibe o interior colorido das barbatanas peitorais como aviso aos predadores.';

  @override
  String get species_spiny_devilfish_name => 'Peixe-diabo-espinhoso';

  @override
  String get species_spiny_devilfish_desc =>
      'Habitante venenoso do fundo que caminha sobre raios modificados das barbatanas e exibe peitorais garridas quando incomodado.';

  @override
  String get species_waspfish_name => 'Peixe-vespa-cacatua';

  @override
  String get species_waspfish_desc =>
      'Pequeno peixe-escorpião comprimido que baloiça na corrente como uma folha morta, nos fundos lodosos do Indo-Pacífico.';

  @override
  String get species_stargazer_name => 'Peixe-olha-estrelas-de-bordo-branco';

  @override
  String get species_stargazer_desc =>
      'Predador de emboscada que se enterra na areia deixando apenas os olhos de fora e pode aplicar choques elétricos. Presente no Indo-Pacífico.';

  @override
  String get species_striped_catfish_name => 'Bagre-listado';

  @override
  String get species_striped_catfish_desc =>
      'Bagre de espinhos venenosos; os juvenis formam cardumes densos em bola que rolam pelos fundos de recife do Indo-Pacífico.';

  @override
  String get species_red_emperor_name => 'Imperador-vermelho';

  @override
  String get species_red_emperor_desc =>
      'Grande luciano; os adultos são rosa-avermelhados e os juvenis têm bandas vermelhas e brancas marcadas. Presente nos recifes do Indo-Pacífico.';

  @override
  String get species_mangrove_snapper_name => 'Luciano-do-mangal';

  @override
  String get species_mangrove_snapper_desc =>
      'Luciano cinzento presente nos mangais, pradarias marinhas e recifes das Caraíbas, muitas vezes agregado junto a estruturas.';

  @override
  String get species_dottyback_orchid_name => 'Pseudocromis-orquídea';

  @override
  String get species_dottyback_orchid_desc =>
      'Pequeno peixe de roxo vivo, endémico do mar Vermelho, que entra e sai das fendas das paredes de recife mais íngremes.';

  @override
  String get species_dottyback_royal_name => 'Pseudocromis-real';

  @override
  String get species_dottyback_royal_desc =>
      'Pequeno peixe bicolor, com a frente magenta e a traseira amarelo-viva, presente nas paredes de recife do Indo-Pacífico.';

  @override
  String get species_coral_trout_name => 'Truta-de-coral';

  @override
  String get species_coral_trout_desc =>
      'Predador cobiçado da Grande Barreira de Coral, de corpo vermelho-alaranjado coberto de pintas azuis.';

  @override
  String get species_barramundi_cod_name => 'Garoupa-barramundi';

  @override
  String get species_barramundi_cod_desc =>
      'Garoupa inconfundível, de cabeça pequena, corpo arqueado e pintas escuras sobre fundo claro.';

  @override
  String get species_spadefish_atlantic_name => 'Peixe-enxada-do-Atlântico';

  @override
  String get species_spadefish_atlantic_desc =>
      'Peixe prateado em forma de disco, com barras verticais escuras, visto muitas vezes em grandes cardumes à volta de destroços nas Caraíbas.';

  @override
  String get species_fusilier_yellowback_name => 'Fuzileiro-de-dorso-amarelo';

  @override
  String get species_fusilier_yellowback_desc =>
      'Peixe planctívoro azul e esguio, de dorso amarelo, que forma cardumes enormes sobre as encostas de recife do Indo-Pacífico.';

  @override
  String get species_fusilier_bluestreak_name => 'Fuzileiro-de-risca-azul';

  @override
  String get species_fusilier_bluestreak_desc =>
      'Pequeno fuzileiro azul com uma risca lateral escura, visto em cardumes velozes ao longo das paredes de recife do Indo-Pacífico.';

  @override
  String get species_porkfish_name => 'Roncador-porco';

  @override
  String get species_porkfish_desc =>
      'Roncador colorido das Caraíbas, com riscas azuis e amarelas e duas barras negras na cabeça, encontrado junto a recifes e destroços.';

  @override
  String get species_blue_striped_grunt_name => 'Roncador-de-riscas-azuis';

  @override
  String get species_blue_striped_grunt_desc =>
      'Roncador amarelo das Caraíbas com riscas horizontais de azul vivo, que forma grandes cardumes em repouso sob saliências durante o dia.';

  @override
  String get species_french_grunt_name => 'Roncador-francês';

  @override
  String get species_french_grunt_desc =>
      'Pequeno roncador de riscas amarelas que forma cardumes densos em repouso nos recifes das Caraíbas durante as horas de luz.';

  @override
  String get species_convict_tang_name => 'Cirurgião-condenado';

  @override
  String get species_convict_tang_desc =>
      'Peixe-cirurgião claro com seis barras verticais negras, visto muitas vezes a pastar em grandes cardumes nos planaltos de recife do Indo-Pacífico.';

  @override
  String get species_great_hammerhead_name => 'Tubarão-martelo-recortado';

  @override
  String get species_great_hammerhead_desc =>
      'Tubarão inconfundível, de cabeça em martelo recortado, que forma grandes cardumes em montes submarinos e ilhas ao largo.';

  @override
  String get species_wobbegong_name => 'Tubarão-tapete-malhado';

  @override
  String get species_wobbegong_desc =>
      'Tubarão-tapete achatado e bem camuflado, com lobos franjados em redor da boca, presente nos recifes temperados da Austrália.';

  @override
  String get species_manta_ray_name => 'Manta-de-recife';

  @override
  String get species_manta_ray_desc =>
      'Gigante gracioso de até 5 m de envergadura, que visita estações de limpeza e se alimenta de plâncton nos recifes do Indo-Pacífico.';

  @override
  String get species_oceanic_manta_name => 'Manta-oceânica';

  @override
  String get species_oceanic_manta_desc =>
      'A maior espécie de raia, com envergaduras superiores a 7 m, encontrada em montes submarinos ao largo e em estações de limpeza.';

  @override
  String get species_undulated_moray_name => 'Moreia-ondulada';

  @override
  String get species_undulated_moray_desc =>
      'Moreia verde-amarelada com marcas escuras onduladas, vista com frequência a caçar de noite nos recifes do Indo-Pacífico.';

  @override
  String get species_whitemouth_moray_name => 'Moreia-de-boca-branca';

  @override
  String get species_whitemouth_moray_desc =>
      'Moreia castanho-escura com pequenas pintas brancas e o interior da boca nitidamente branco, presente em todo o Indo-Pacífico.';

  @override
  String get species_dragon_moray_name => 'Moreia-dragão';

  @override
  String get species_dragon_moray_desc =>
      'Moreia impressionante, com cornos de dragão sobre as narinas e manchas laranja-avermelhadas de leopardo, presente no Indo-Pacífico.';

  @override
  String get species_lyretail_grouper_name => 'Garoupa-de-cauda-de-lira';

  @override
  String get species_lyretail_grouper_desc =>
      'Garoupa rosa-avermelhada com pintas azuis e uma cauda em crescente inconfundível, presente nas paredes exteriores de recife do Indo-Pacífico.';

  @override
  String get species_banded_butterflyfish_name => 'Peixe-borboleta-de-bandas';

  @override
  String get species_banded_butterflyfish_desc =>
      'Peixe-borboleta branco com quatro bandas verticais negras bem marcadas, um dos mais comuns dos recifes das Caraíbas.';

  @override
  String get species_ringed_pipefish_name => 'Peixe-cachimbo-anelado';

  @override
  String get species_ringed_pipefish_desc =>
      'Peixe-cachimbo esguio, com anéis alternados vermelhos e brancos, encontrado em grutas e sob saliências nos recifes do Indo-Pacífico.';

  @override
  String get species_razorfish_name => 'Peixe-navalha';

  @override
  String get species_razorfish_desc =>
      'Peixe minúsculo que nada na vertical, de cabeça para baixo e em grupo, muitas vezes escondido entre espinhos de ouriço nos recifes do Indo-Pacífico.';

  @override
  String get species_harlequin_tuskfish_name => 'Bodião-arlequim-de-presas';

  @override
  String get species_harlequin_tuskfish_desc =>
      'Bodião colorido, com presas azul-vivas, barras vermelho-alaranjadas e manchas brancas, presente nos recifes do Pacífico ocidental.';

  @override
  String get species_blue_groper_name => 'Bodião-azul-australiano';

  @override
  String get species_blue_groper_desc =>
      'Grande bodião azul endémico do leste da Austrália, sociável e habitualmente aproxima-se dos mergulhadores nos recifes temperados.';

  @override
  String get species_red_lipped_batfish_name =>
      'Peixe-morcego-de-lábios-vermelhos';

  @override
  String get species_red_lipped_batfish_desc =>
      'Peixe bizarro de corpo achatado, com lábios vermelho-vivos, que caminha sobre barbatanas modificadas no fundo dos Galápagos.';

  @override
  String get species_orangeband_surgeonfish_name =>
      'Cirurgião-de-banda-laranja';

  @override
  String get species_orangeband_surgeonfish_desc =>
      'Peixe-cirurgião castanho-acinzentado com uma banda horizontal laranja atrás do olho, presente nas encostas de recife do Pacífico.';

  @override
  String get species_maori_wrasse_name => 'Bodião-maori';

  @override
  String get species_maori_wrasse_desc =>
      'Bodião de tamanho médio, com uma banda escura atrás da barbatana peitoral, comum nos recifes do Pacífico e do oceano Índico.';

  @override
  String get species_blue_ringed_octopus_name => 'Polvo-de-anéis-azuis';

  @override
  String get species_blue_ringed_octopus_desc =>
      'Polvo pequeno mas extremamente venenoso, com anéis azuis vivos que se acendem quando ameaçado.';

  @override
  String get species_common_octopus_name => 'Polvo-comum';

  @override
  String get species_common_octopus_desc =>
      'Polvo muito inteligente, conhecido pelas mudanças rápidas de cor e pela capacidade de resolver problemas.';

  @override
  String get species_giant_pacific_octopus_name => 'Polvo-gigante-do-Pacífico';

  @override
  String get species_giant_pacific_octopus_desc =>
      'A maior espécie de polvo, com braços que ultrapassam os 4 metros de envergadura nas águas frias do Pacífico.';

  @override
  String get species_mimic_octopus_name => 'Polvo-mímico';

  @override
  String get species_mimic_octopus_desc =>
      'Polvo notável que imita o aspeto e o comportamento de outras espécies marinhas.';

  @override
  String get species_coconut_octopus_name => 'Polvo-do-coco';

  @override
  String get species_coconut_octopus_desc =>
      'Pequeno polvo célebre por transportar cascas de coco e usá-las como abrigo portátil.';

  @override
  String get species_day_octopus_name => 'Polvo-diurno';

  @override
  String get species_day_octopus_desc =>
      'Caçador ativo durante o dia, comum nos recifes do Indo-Pacífico e com uma camuflagem impressionante.';

  @override
  String get species_wonderpus_octopus_name => 'Polvo-wonderpus';

  @override
  String get species_wonderpus_octopus_desc =>
      'Polvo marcante, com bandas brancas e castanhas únicas, encontrado em locais de mergulho de fundo arenoso.';

  @override
  String get species_broadclub_cuttlefish_name => 'Choco-de-clava-larga';

  @override
  String get species_broadclub_cuttlefish_desc =>
      'Choco grande, de exibições de cor hipnotizantes, visto com frequência nos recifes do Indo-Pacífico.';

  @override
  String get species_pharaoh_cuttlefish_name => 'Choco-faraó';

  @override
  String get species_pharaoh_cuttlefish_desc =>
      'Choco grande presente em todo o oceano Índico, conhecido pelos padrões de cor pulsantes.';

  @override
  String get species_flamboyant_cuttlefish_name => 'Choco-flamejante';

  @override
  String get species_flamboyant_cuttlefish_desc =>
      'Choco minúsculo que caminha pelo fundo exibindo pulsos vivos de roxo, rosa e amarelo.';

  @override
  String get species_giant_cuttlefish_name => 'Choco-gigante';

  @override
  String get species_giant_cuttlefish_desc =>
      'O maior choco do mundo, célebre pelas agregações de desova em massa no sul da Austrália.';

  @override
  String get species_bigfin_reef_squid_name =>
      'Lula-de-recife-de-barbatanas-grandes';

  @override
  String get species_bigfin_reef_squid_desc =>
      'Lula gregária encontrada com frequência em mergulhos noturnos, atraída pelas luzes de mergulho.';

  @override
  String get species_caribbean_reef_squid_name => 'Lula-de-recife-das-Caraíbas';

  @override
  String get species_caribbean_reef_squid_desc =>
      'Lula curiosa, muitas vezes a pairar em pequenos grupos junto aos bordos do recife nas Caraíbas.';

  @override
  String get species_bobtail_squid_name => 'Sépiola';

  @override
  String get species_bobtail_squid_desc =>
      'Lula minúscula e noturna que se enterra na areia de dia, um achado cobiçado no mergulho em fundos lodosos.';

  @override
  String get species_chambered_nautilus_name => 'Náutilo';

  @override
  String get species_chambered_nautilus_desc =>
      'Fóssil vivo ancestral, de concha enrolada, raramente visto pelos mergulhadores em água profunda ao amanhecer.';

  @override
  String get species_spanish_dancer_name => 'Bailarina-espanhola';

  @override
  String get species_spanish_dancer_desc =>
      'A maior espécie de nudibrânquio, que nada ondulando o manto vermelho como uma bailarina de flamenco.';

  @override
  String get species_chromodoris_willani_name => 'Cromodóris-de-Willan';

  @override
  String get species_chromodoris_willani_desc =>
      'Nudibrânquio marcante, azul e negro com margem branca, comum no Indo-Pacífico.';

  @override
  String get species_chromodoris_lochi_name => 'Cromodóris-de-Loch';

  @override
  String get species_chromodoris_lochi_desc =>
      'Nudibrânquio azul com linhas escuras e bordo branco, presente em todo o Pacífico tropical.';

  @override
  String get species_chromodoris_magnifica_name => 'Cromodóris-magnífica';

  @override
  String get species_chromodoris_magnifica_desc =>
      'Nudibrânquio de azul, branco e laranja brilhantes, presente nos recifes de coral do Indo-Pacífico.';

  @override
  String get species_chromodoris_annae_name => 'Cromodóris-de-Anna';

  @override
  String get species_chromodoris_annae_desc =>
      'Nudibrânquio de azul profundo, com linhas negras e rinóforos e brânquias de pontas laranja.';

  @override
  String get species_nembrotha_kubaryana_name => 'Lesma-néon-variável';

  @override
  String get species_nembrotha_kubaryana_desc =>
      'Nudibrânquio verde-escuro com marcas laranja ou vermelhas vivas, que se alimenta de tunicados.';

  @override
  String get species_nembrotha_cristata_name => 'Nembrota-crista';

  @override
  String get species_nembrotha_cristata_desc =>
      'Nudibrânquio negro com pústulas e riscas verde-vivas, encontrado nos recifes do Indo-Pacífico.';

  @override
  String get species_phyllidia_varicosa_name => 'Filídia-varicosa';

  @override
  String get species_phyllidia_varicosa_desc =>
      'Nudibrânquio cinzento-azulado com tubérculos salientes de pontas amarelas, tóxico para os predadores.';

  @override
  String get species_phyllidia_ocellata_name => 'Filídia-ocelada';

  @override
  String get species_phyllidia_ocellata_desc =>
      'Nudibrânquio branco com tubérculos salientes rodeados de rosa, encontrado em recifes tropicais.';

  @override
  String get species_pikachu_nudibranch_name => 'Nudibrânquio-pikachu';

  @override
  String get species_pikachu_nudibranch_desc =>
      'Lesma do mar minúscula, amarela e negra, parecida com uma personagem de desenhos animados, presente no Pacífico.';

  @override
  String get species_anna_rosefieldi_name => 'Nudibrânquio-roboastra';

  @override
  String get species_anna_rosefieldi_desc =>
      'Nudibrânquio predador de corpo escuro e riscas longitudinais vivas, que caça outras lesmas.';

  @override
  String get species_lettuce_sea_slug_name => 'Lesma-do-mar-alface';

  @override
  String get species_lettuce_sea_slug_desc =>
      'Lesma do mar verde e franzida que retém os cloroplastos das algas para fazer fotossíntese.';

  @override
  String get species_blue_dragon_nudibranch_name => 'Nudibrânquio-dragão-azul';

  @override
  String get species_blue_dragon_nudibranch_desc =>
      'Nudibrânquio eólido comprido, com cerata de pontas azuis, que aloja zooxantelas simbióticas.';

  @override
  String get species_gloomy_nudibranch_name => 'Nudibrânquio-sombrio';

  @override
  String get species_gloomy_nudibranch_desc =>
      'Nudibrânquio verde-azulado escuro, com cristas orladas de azul, comum nos recifes do Indo-Pacífico.';

  @override
  String get species_ocellined_nudibranch_name =>
      'Nudibrânquio-de-linhas-oceladas';

  @override
  String get species_ocellined_nudibranch_desc =>
      'Nudibrânquio branco com cristas orladas de laranja que formam padrões geométricos no manto.';

  @override
  String get species_glossodoris_cincta_name => 'Nudibrânquio-glossodóris';

  @override
  String get species_glossodoris_cincta_desc =>
      'Nudibrânquio cor de creme, com bordo castanho-escuro e margem laranja no manto.';

  @override
  String get species_jorunna_funebris_name => 'Nudibrânquio-pontilhado';

  @override
  String get species_jorunna_funebris_desc =>
      'Nudibrânquio branco coberto de carifilídias de pontas negras, com o aspeto de um coelhinho felpudo.';

  @override
  String get species_ceratosoma_trilobatum_name => 'Nudibrânquio-trilobado';

  @override
  String get species_ceratosoma_trilobatum_desc =>
      'Nudibrânquio grande, com um corno dorsal alto e lobos laterais em tons de roxo e amarelo.';

  @override
  String get species_hypselodoris_apolegma_name => 'Hipselodóris-roxa';

  @override
  String get species_hypselodoris_apolegma_desc =>
      'Nudibrânquio roxo e elegante, com bordo do manto branco, presente nos recifes do Indo-Pacífico.';

  @override
  String get species_hypselodoris_bullockii_name => 'Hipselodóris-de-Bullock';

  @override
  String get species_hypselodoris_bullockii_desc =>
      'Nudibrânquio rosa e roxo, com rinóforos de pontas amarelas, nos recifes do Indo-Pacífico.';

  @override
  String get species_flabellina_exoptata_name => 'Flabelina-desejável';

  @override
  String get species_flabellina_exoptata_desc =>
      'Nudibrânquio eólido translúcido, com cerata laranja de pontas roxas, presente em águas tropicais.';

  @override
  String get species_risbecia_tryoni_name => 'Risbécia-de-Tryon';

  @override
  String get species_risbecia_tryoni_desc =>
      'Nudibrânquio grande, castanho e azul, encontrado muitas vezes em pares de acasalamento nos recifes do Indo-Pacífico.';

  @override
  String get species_goniobranchus_kuniei_name => 'Nudibrânquio-de-Kunie';

  @override
  String get species_goniobranchus_kuniei_desc =>
      'Nudibrânquio branco com pintas laranja e margem do manto roxa, presente no Pacífico ocidental.';

  @override
  String get species_mexichromis_multituberculata_name =>
      'Nudibrânquio-multituberculado';

  @override
  String get species_mexichromis_multituberculata_desc =>
      'Nudibrânquio roxo e branco, com tubérculos salientes e apêndices de pontas laranja.';

  @override
  String get species_chromodoris_dianae_name => 'Cromodóris-de-Diana';

  @override
  String get species_chromodoris_dianae_desc =>
      'Nudibrânquio azul-vivo com riscas negras e brânquias laranja, presente no Pacífico ocidental.';

  @override
  String get species_phyllodesmium_poindimiei_name => 'Nudibrânquio-solar';

  @override
  String get species_phyllodesmium_poindimiei_desc =>
      'Nudibrânquio eólido translúcido, de cerata ramificados, que aloja zooxantelas.';

  @override
  String get species_chromodoris_elisabethina_name => 'Cromodóris-de-Elizabeth';

  @override
  String get species_chromodoris_elisabethina_desc =>
      'Nudibrânquio com linhas azuis e amarelas e bordo do manto branco, comum no Sudeste Asiático.';

  @override
  String get species_doridella_batava_name => 'Dórido-de-Batávia';

  @override
  String get species_doridella_batava_desc =>
      'Nudibrânquio dórido de cor variável, do negro ao castanho, encontrado sob pedras e cascalho nos recifes do Indo-Pacífico.';

  @override
  String get species_tiger_cowrie_name => 'Búzio-tigre';

  @override
  String get species_tiger_cowrie_desc =>
      'Búzio grande e pintalgado dos recifes tropicais, muitas vezes parcialmente coberto pelo próprio manto.';

  @override
  String get species_tritons_trumpet_name => 'Trombeta-de-tritão';

  @override
  String get species_tritons_trumpet_desc =>
      'Grande caracol predador e inimigo natural da estrela-do-mar coroa-de-espinhos.';

  @override
  String get species_queen_conch_name => 'Búzio-rainha';

  @override
  String get species_queen_conch_desc =>
      'Búzio grande e icónico das pradarias marinhas das Caraíbas, com o lábio interior de um rosa característico.';

  @override
  String get species_banded_coral_shrimp_name => 'Camarão-limpador-de-bandas';

  @override
  String get species_banded_coral_shrimp_desc =>
      'Camarão-limpador de bandas vermelhas e brancas, com longas antenas brancas, encontrado nas fendas do recife.';

  @override
  String get species_mantis_shrimp_name => 'Camarão-louva-a-deus-pavão';

  @override
  String get species_mantis_shrimp_desc =>
      'Predador colorido com apêndices potentes em forma de maça, capazes de partir conchas.';

  @override
  String get species_cleaner_shrimp_name => 'Camarão-limpador-escarlate';

  @override
  String get species_cleaner_shrimp_desc =>
      'Camarão vermelho e branco vivo que monta estações de limpeza para atender os peixes do recife.';

  @override
  String get species_pederson_cleaner_shrimp_name =>
      'Camarão-limpador-de-Pederson';

  @override
  String get species_pederson_cleaner_shrimp_desc =>
      'Camarão-limpador translúcido das Caraíbas, que vive entre os tentáculos das anémonas.';

  @override
  String get species_harlequin_shrimp_name => 'Camarão-arlequim';

  @override
  String get species_harlequin_shrimp_desc =>
      'Camarão de padrão espetacular, com pinças achatadas, que se alimenta exclusivamente de estrelas-do-mar.';

  @override
  String get species_coleman_shrimp_name => 'Camarão-de-Coleman';

  @override
  String get species_coleman_shrimp_desc =>
      'Camarão minúsculo que vive aos pares sobre ouriços-de-fogo, muito cobiçado pelos fotógrafos subaquáticos.';

  @override
  String get species_emperor_shrimp_name => 'Camarão-imperador';

  @override
  String get species_emperor_shrimp_desc =>
      'Camarão comensal e colorido que viaja sobre pepinos-do-mar e nudibrânquios.';

  @override
  String get species_sexy_shrimp_name => 'Camarão-sensual';

  @override
  String get species_sexy_shrimp_desc =>
      'Camarão de anémona minúsculo, conhecido pela dança em que agita a cauda, muito popular na fotografia macro.';

  @override
  String get species_marble_shrimp_name => 'Camarão-marmoreado';

  @override
  String get species_marble_shrimp_desc =>
      'Camarão noturno e malhado, de patas plumosas, encontrado escondido nas fendas do recife durante o dia.';

  @override
  String get species_spiny_lobster_name => 'Lagosta-das-Caraíbas';

  @override
  String get species_spiny_lobster_desc =>
      'Lagosta grande e sem pinças, de antenas compridas, encontrada abrigada sob as saliências do recife.';

  @override
  String get species_painted_spiny_lobster_name => 'Lagosta-pintada';

  @override
  String get species_painted_spiny_lobster_desc =>
      'Lagosta de cores vibrantes, com as patas listadas a azul, verde e branco, nos recifes do Indo-Pacífico.';

  @override
  String get species_slipper_lobster_name => 'Cavaco';

  @override
  String get species_slipper_lobster_desc =>
      'Lagosta noturna de corpo achatado, com placas antenais largas em vez de longos chicotes.';

  @override
  String get species_squat_lobster_name => 'Galateia';

  @override
  String get species_squat_lobster_desc =>
      'Crustáceo minúsculo rosa-arroxeado que vive nas grandes esponjas-barril, um dos preferidos da fotografia macro.';

  @override
  String get species_hermit_crab_name => 'Ermita-de-patas-azuis';

  @override
  String get species_hermit_crab_desc =>
      'Pequeno caranguejo-ermita de patas azul-vivas, visto com frequência nos recifes das Caraíbas.';

  @override
  String get species_orangutan_crab_name => 'Caranguejo-orangotango';

  @override
  String get species_orangutan_crab_desc =>
      'Caranguejo minúsculo e peludo que vive no coral-bolha, batizado pela semelhança com um orangotango.';

  @override
  String get species_decorator_crab_name => 'Caranguejo-decorador';

  @override
  String get species_decorator_crab_desc =>
      'Mestre do disfarce, que prende esponjas, algas e hidrozoários à sua carapaça.';

  @override
  String get species_porcelain_crab_name => 'Caranguejo-porcelana-de-anémona';

  @override
  String get species_porcelain_crab_desc =>
      'Caranguejo achatado e pintalgado que vive em anémonas e filtra alimento com peças bucais plumosas.';

  @override
  String get species_arrow_crab_name => 'Caranguejo-flecha';

  @override
  String get species_arrow_crab_desc =>
      'Caranguejo esguio das Caraíbas, com um rostro longo e pontiagudo e patas listadas.';

  @override
  String get species_channel_clinging_crab_name =>
      'Caranguejo-aranha-das-Caraíbas';

  @override
  String get species_channel_clinging_crab_desc =>
      'Grande caranguejo de recife das Caraíbas, de corpo escuro e pinças vermelho-alaranjadas, encontrado em fendas.';

  @override
  String get species_coral_crab_name => 'Caranguejo-guarda-do-coral';

  @override
  String get species_coral_crab_desc =>
      'Pequeno caranguejo pintalgado que vive em simbiose nos corais Pocillopora, defendendo o seu hospedeiro.';

  @override
  String get species_crown_of_thorns_starfish_name =>
      'Estrela-do-mar-coroa-de-espinhos';

  @override
  String get species_crown_of_thorns_starfish_desc =>
      'Estrela-do-mar venenosa de muitos braços, que se alimenta de coral e pode devastar recifes durante as suas explosões populacionais.';

  @override
  String get species_blue_linckia_starfish_name => 'Líncia-azul';

  @override
  String get species_blue_linckia_starfish_desc =>
      'Estrela-do-mar de azul vivo, vista com frequência nos planaltos e encostas de recife do Indo-Pacífico.';

  @override
  String get species_red_knob_starfish_name =>
      'Estrela-do-mar-de-nódulos-vermelhos';

  @override
  String get species_red_knob_starfish_desc =>
      'Grande estrela-do-mar cinzenta, com espinhos de pontas vermelhas bem visíveis, encontrada em zonas arenosas do recife.';

  @override
  String get species_chocolate_chip_starfish_name =>
      'Estrela-do-mar-pepita-de-chocolate';

  @override
  String get species_chocolate_chip_starfish_desc =>
      'Estrela-do-mar bege com nódulos escuros salientes que lembram pepitas de chocolate, sobre substratos arenosos.';

  @override
  String get species_cushion_star_name => 'Estrela-almofada';

  @override
  String get species_cushion_star_desc =>
      'Estrela-do-mar pentagonal e roliça, de braços reduzidos, encontrada nos planaltos de recife do Indo-Pacífico.';

  @override
  String get species_fromia_starfish_name => 'Estrela-do-mar-elegante';

  @override
  String get species_fromia_starfish_desc =>
      'Pequena estrela-do-mar laranja-avermelhada com as margens das placas claras, criando um padrão de mosaico.';

  @override
  String get species_basket_star_name => 'Estrela-cesto';

  @override
  String get species_basket_star_desc =>
      'Os braços muito ramificados abrem-se à noite para filtrar alimento na corrente.';

  @override
  String get species_brittle_star_name => 'Ofiúra-de-bandas';

  @override
  String get species_brittle_star_desc =>
      'Ofiúra listada encontrada sob pedras e em fendas, com braços ágeis e serpenteantes.';

  @override
  String get species_feather_star_name => 'Estrela-pena';

  @override
  String get species_feather_star_desc =>
      'Crinoide de muitos braços, empoleirado nas saliências do recife, que filtra alimento com os braços plumosos.';

  @override
  String get species_black_feather_star_name => 'Estrela-pena-negra';

  @override
  String get species_black_feather_star_desc =>
      'Crinoide escuro capaz de nadar por breves instantes, agitando ritmadamente os seus muitos braços.';

  @override
  String get species_long_spined_sea_urchin_name => 'Ouriço-de-espinhos-longos';

  @override
  String get species_long_spined_sea_urchin_desc =>
      'Ouriço negro de espinhos longos e venenosos, um pastador essencial dos recifes das Caraíbas.';

  @override
  String get species_fire_urchin_name => 'Ouriço-de-fogo';

  @override
  String get species_fire_urchin_desc =>
      'Ouriço de corpo mole com espinhos venenosos que provocam picadas dolorosas ao contacto.';

  @override
  String get species_pencil_urchin_name => 'Ouriço-lápis';

  @override
  String get species_pencil_urchin_desc =>
      'Ouriço robusto, de espinhos grossos e rombos, encontrado encaixado nas fendas do recife.';

  @override
  String get species_collector_urchin_name => 'Ouriço-coletor';

  @override
  String get species_collector_urchin_desc =>
      'Ouriço que se cobre de detritos e fragmentos de algas para se camuflar.';

  @override
  String get species_sea_apple_name => 'Maçã-do-mar';

  @override
  String get species_sea_apple_desc =>
      'Pepino-do-mar de cores vivas, com tentáculos orais usados para filtrar alimento.';

  @override
  String get species_pineapple_sea_cucumber_name => 'Pepino-do-mar-ananás';

  @override
  String get species_pineapple_sea_cucumber_desc =>
      'Grande pepino-do-mar vermelho-alaranjado, com papilas em forma de estrela, encontrado nas encostas de recife.';

  @override
  String get species_black_sea_cucumber_name => 'Pepino-do-mar-negro';

  @override
  String get species_black_sea_cucumber_desc =>
      'Pepino-do-mar negro e comum, encontrado nos planaltos arenosos de recife de todo o Indo-Pacífico.';

  @override
  String get species_leopard_sea_cucumber_name => 'Pepino-do-mar-leopardo';

  @override
  String get species_leopard_sea_cucumber_desc =>
      'Pepino-do-mar pintalgado que expele túbulos de Cuvier brancos e pegajosos quando incomodado.';

  @override
  String get species_sand_dollar_name => 'Bolacha-do-mar';

  @override
  String get species_sand_dollar_desc =>
      'Ouriço achatado em forma de disco, encontrado parcialmente enterrado em substratos arenosos.';

  @override
  String get species_moon_jellyfish_name => 'Alforreca-da-lua';

  @override
  String get species_moon_jellyfish_desc =>
      'Alforreca translúcida em forma de sino, com quatro gónadas em ferradura visíveis através do corpo.';

  @override
  String get species_lions_mane_jellyfish_name => 'Alforreca-juba-de-leão';

  @override
  String get species_lions_mane_jellyfish_desc =>
      'Uma das maiores espécies de alforreca, com longos tentáculos a arrastar, presente em águas frias.';

  @override
  String get species_box_jellyfish_name => 'Alforreca-caixa';

  @override
  String get species_box_jellyfish_desc =>
      'Alforreca extremamente perigosa, de veneno potente, presente nas águas tropicais do Indo-Pacífico.';

  @override
  String get species_upside_down_jellyfish_name => 'Alforreca-invertida';

  @override
  String get species_upside_down_jellyfish_desc =>
      'Alforreca invulgar que repousa com o sino virado para baixo em fundos arenosos, para que as suas algas façam fotossíntese.';

  @override
  String get species_blue_blubber_jellyfish_name => 'Alforreca-azul';

  @override
  String get species_blue_blubber_jellyfish_desc =>
      'Alforreca azul e branca, de sino firme e braços orais franjados, comum nas águas australianas.';

  @override
  String get species_fried_egg_jellyfish_name => 'Alforreca-ovo-estrelado';

  @override
  String get species_fried_egg_jellyfish_desc =>
      'Alforreca do Mediterrâneo com uma cúpula amarela parecida com um ovo estrelado e picada ligeira.';

  @override
  String get species_pacific_sea_nettle_name => 'Urtiga-do-mar-do-Pacífico';

  @override
  String get species_pacific_sea_nettle_desc =>
      'Alforreca castanho-dourada com longos tentáculos a arrastar, presente ao longo da costa do Pacífico.';

  @override
  String get species_compass_jellyfish_name => 'Alforreca-bússola';

  @override
  String get species_compass_jellyfish_desc =>
      'Alforreca castanha e branca com marcas em V que irradiam como uma rosa dos ventos.';

  @override
  String get species_spotted_jellyfish_name => 'Alforreca-pintada';

  @override
  String get species_spotted_jellyfish_desc =>
      'Alforreca dourada com pintas brancas, célebre por encher o Lago das Medusas, em Palau.';

  @override
  String get species_barrel_jellyfish_name => 'Alforreca-barril';

  @override
  String get species_barrel_jellyfish_desc =>
      'Alforreca grande em forma de cúpula, com braços orais franjados e picada ligeira, comum no Atlântico.';

  @override
  String get species_persian_carpet_flatworm_name => 'Platelminte-tapete-persa';

  @override
  String get species_persian_carpet_flatworm_desc =>
      'Platelminte negro e ornamentado, de margens amarelo-alaranjadas, muitas vezes confundido com um nudibrânquio.';

  @override
  String get species_leopard_flatworm_name => 'Platelminte-leopardo';

  @override
  String get species_leopard_flatworm_desc =>
      'Platelminte translúcido com manchas de leopardo, que desliza sobre os substratos do recife.';

  @override
  String get species_divided_flatworm_name => 'Platelminte-dividido';

  @override
  String get species_divided_flatworm_desc =>
      'Platelminte marcante, negro e laranja, que imita nudibrânquios tóxicos como forma de proteção.';

  @override
  String get species_blue_pseudoceros_flatworm_name =>
      'Platelminte-pseudoceros-azul';

  @override
  String get species_blue_pseudoceros_flatworm_desc =>
      'Platelminte de azul profundo com margem laranja, visto a deslizar sobre as superfícies dos recifes do Indo-Pacífico.';

  @override
  String get species_racing_stripe_flatworm_name =>
      'Platelminte-de-risca-central';

  @override
  String get species_racing_stripe_flatworm_desc =>
      'Platelminte cor de creme, com uma risca central escura bem definida e margem franzida.';

  @override
  String get species_christmas_tree_worm_name => 'Verme-árvore-de-Natal';

  @override
  String get species_christmas_tree_worm_desc =>
      'Verme colorido de coroas em espiral, embutido no coral, que se recolhe instantaneamente à aproximação.';

  @override
  String get species_feather_duster_worm_name => 'Verme-espanador';

  @override
  String get species_feather_duster_worm_desc =>
      'Verme tubícola com uma coroa em leque de radíolos plumosos usada para filtrar alimento.';

  @override
  String get species_fire_worm_name => 'Verme-de-fogo-barbudo';

  @override
  String get species_fire_worm_desc =>
      'Poliqueta com cerdas urticantes brancas que provocam uma irritação dolorosa ao contacto.';

  @override
  String get species_bobbit_worm_name => 'Verme-bobbit';

  @override
  String get species_bobbit_worm_desc =>
      'Predador de emboscada escondido na areia, com mandíbulas potentes que atacam à velocidade de um relâmpago.';

  @override
  String get species_social_feather_duster_name => 'Verme-espanador-social';

  @override
  String get species_social_feather_duster_desc =>
      'Verme tubícola colonial que forma agrupamentos de coroas delicadas e listadas nos recifes das Caraíbas.';

  @override
  String get species_giant_clam_name => 'Tridacna-gigante';

  @override
  String get species_giant_clam_desc =>
      'O maior bivalve vivo, com tecido do manto iridescente que aloja algas simbióticas.';

  @override
  String get species_boring_clam_name => 'Tridacna-perfuradora';

  @override
  String get species_boring_clam_desc =>
      'Pequeno bivalve colorido que perfura a rocha coralina, deixando à vista apenas o seu manto vivo.';

  @override
  String get species_maxima_clam_name => 'Tridacna-maxima';

  @override
  String get species_maxima_clam_desc =>
      'Bivalve de cores brilhantes, embutido na rocha do recife, com mantos de azul e verde elétricos.';

  @override
  String get species_flame_scallop_name => 'Vieira-de-chama';

  @override
  String get species_flame_scallop_desc =>
      'Bivalve vermelho com uma luz branca intermitente ao longo do bordo do manto, encontrado nas fendas do recife.';

  @override
  String get species_thorny_oyster_name => 'Ostra-espinhosa';

  @override
  String get species_thorny_oyster_desc =>
      'Bivalve de concha espinhosa cimentado à rocha do recife, muitas vezes incrustado de esponjas e algas.';

  @override
  String get species_magnificent_sea_anemone_name => 'Anémona-magnífica';

  @override
  String get species_magnificent_sea_anemone_desc =>
      'Grande anémona colorida que acolhe peixes-palhaço, com uma coluna proeminente e tentáculos ondulantes.';

  @override
  String get species_bubble_tip_anemone_name => 'Anémona-de-pontas-em-bolha';

  @override
  String get species_bubble_tip_anemone_desc =>
      'Hospedeira popular dos peixes-palhaço, com tentáculos de pontas bolbosas em verde, castanho ou rosa.';

  @override
  String get species_giant_carpet_anemone_name => 'Anémona-tapete-gigante';

  @override
  String get species_giant_carpet_anemone_desc =>
      'Anémona enorme, de tentáculos curtos e pegajosos, que pode ultrapassar um metro de diâmetro.';

  @override
  String get species_haddon_carpet_anemone_name => 'Anémona-tapete-de-Haddon';

  @override
  String get species_haddon_carpet_anemone_desc =>
      'Anémona-tapete achatada, sobre substratos arenosos, que acolhe vários peixes-palhaço e caranguejos-porcelana.';

  @override
  String get species_long_tentacle_anemone_name =>
      'Anémona-de-tentáculos-longos';

  @override
  String get species_long_tentacle_anemone_desc =>
      'Anémona de fundo arenoso, com tentáculos longos e ondulantes, muitas vezes a acolher peixes-palhaço.';

  @override
  String get species_tube_anemone_name => 'Anémona-de-tubo';

  @override
  String get species_tube_anemone_desc =>
      'Anémona elegante que vive num tubo de pergaminho enterrado na areia, com duas coroas de tentáculos.';

  @override
  String get species_hell_fire_anemone_name => 'Anémona-fogo-do-inferno';

  @override
  String get species_hell_fire_anemone_desc =>
      'Anémona fortemente urticante, com tentáculos ramificados semelhantes a coral mole.';

  @override
  String get species_beaded_sea_anemone_name => 'Anémona-de-contas';

  @override
  String get species_beaded_sea_anemone_desc =>
      'Anémona com as pontas dos tentáculos dilatadas em forma de conta, encontrada em zonas arenosas de recife do Indo-Pacífico.';

  @override
  String get species_condylactis_anemone_name => 'Anémona-gigante-das-Caraíbas';

  @override
  String get species_condylactis_anemone_desc =>
      'Grande anémona das Caraíbas, com tentáculos de pontas roxas, encontrada em substratos rochosos de recife.';

  @override
  String get species_sand_anemone_name => 'Anémona-da-areia';

  @override
  String get species_sand_anemone_desc =>
      'Anémona delicada, parcialmente enterrada na areia, com tentáculos de pontas roxas.';

  @override
  String get species_barrel_sponge_name => 'Esponja-barril-gigante';

  @override
  String get species_barrel_sponge_desc =>
      'Esponja enorme em forma de barril, capaz de viver séculos nas paredes de recife das Caraíbas.';

  @override
  String get species_azure_vase_sponge_name => 'Esponja-vaso-azul';

  @override
  String get species_azure_vase_sponge_desc =>
      'Esponja vibrante em forma de vaso, de azul-arroxeado, encontrada nas paredes de recife das Caraíbas.';

  @override
  String get species_yellow_tube_sponge_name => 'Esponja-tubo-amarela';

  @override
  String get species_yellow_tube_sponge_desc =>
      'Esponja tubular amarelo-viva que cresce em grupos nas paredes de recife das Caraíbas.';

  @override
  String get species_elephant_ear_sponge_name => 'Esponja-orelha-de-elefante';

  @override
  String get species_elephant_ear_sponge_desc =>
      'Grande esponja laranja em forma de leque, que cresce em paredes e abrigos nas Caraíbas.';

  @override
  String get species_rope_sponge_name => 'Esponja-corda';

  @override
  String get species_rope_sponge_desc =>
      'Esponja vermelha ereta e ramificada, que cresce em formações semelhantes a cordas nos recifes das Caraíbas.';

  @override
  String get species_portuguese_man_o_war_name => 'Caravela-portuguesa';

  @override
  String get species_portuguese_man_o_war_desc =>
      'Hidrozoário colonial com um flutuador cheio de gás e tentáculos pendentes de picada extremamente dolorosa.';

  @override
  String get species_fire_coral_name => 'Coral-de-fogo';

  @override
  String get species_fire_coral_desc =>
      'Não é um coral verdadeiro mas um hidrozoário, que provoca picadas dolorosas nos mergulhadores ao contacto.';

  @override
  String get species_by_the_wind_sailor_name => 'Veleiro-do-vento';

  @override
  String get species_by_the_wind_sailor_desc =>
      'Colónia flutuante de hidrozoários azuis, com uma vela diagonal que apanha o vento.';

  @override
  String get species_blue_button_name => 'Botão-azul';

  @override
  String get species_blue_button_desc =>
      'Hidrozoário colonial flutuante, com um disco achatado e hidroides azuis semelhantes a tentáculos.';

  @override
  String get species_giant_sea_hare_name => 'Lebre-do-mar-gigante';

  @override
  String get species_giant_sea_hare_desc =>
      'Uma das maiores lesmas do mar, de castanho-escuro a negro, encontrada nos bosques de kelp.';

  @override
  String get species_sea_hare_name => 'Lebre-do-mar-pintada';

  @override
  String get species_sea_hare_desc =>
      'Grande lebre-do-mar de pintas verdes que liberta tinta roxa quando incomodada.';

  @override
  String get species_nudibranch_berghia_name => 'Nudibrânquio-bérghia';

  @override
  String get species_nudibranch_berghia_desc =>
      'Nudibrânquio eólido translúcido, com cerata de pontas brancas, que se alimenta de anémonas.';

  @override
  String get species_sea_pen_name => 'Pena-do-mar';

  @override
  String get species_sea_pen_desc =>
      'Octocoral colonial em forma de pena, ancorado na areia, que se recolhe quando incomodado.';

  @override
  String get species_blue_sea_star_name => 'Estrela-do-mar-azul';

  @override
  String get species_blue_sea_star_desc =>
      'Estrela-do-mar multicolor que se regenera a partir de fragmentos de um único braço, nos recifes do Indo-Pacífico.';

  @override
  String get species_reef_squid_name => 'Lula-de-recife';

  @override
  String get species_reef_squid_desc =>
      'Lula de recife do sul, encontrada com frequência nas águas temperadas da Austrália.';

  @override
  String get species_tiger_shrimp_name => 'Camarão-tigre';

  @override
  String get species_tiger_shrimp_desc =>
      'Camarão grande e listado, encontrado em fundos arenosos e pradarias marinhas do Indo-Pacífico.';

  @override
  String get species_candy_crab_name => 'Caranguejo-rebuçado';

  @override
  String get species_candy_crab_desc =>
      'Caranguejo minúsculo e colorido que iguala o coral mole onde vive, com projeções espinhosas rosa ou amarelas.';

  @override
  String get species_spider_crab_name => 'Caranguejo-aranha-decorador';

  @override
  String get species_spider_crab_desc =>
      'Caranguejo de movimentos lentos, coberto de esponjas e algas que agarra ao corpo para se camuflar.';

  @override
  String get species_anemone_shrimp_name => 'Camarão-de-anémona-magnífico';

  @override
  String get species_anemone_shrimp_desc =>
      'Camarão transparente com marcas brancas e roxas, que vive entre os tentáculos das anémonas.';

  @override
  String get species_snapping_shrimp_name => 'Camarão-de-estalo';

  @override
  String get species_snapping_shrimp_desc =>
      'Pequeno camarão que produz um estalo sonoro com a sua pinça sobredimensionada, muitas vezes emparelhado com góbios.';

  @override
  String get species_glass_sponge_name => 'Cesto-de-flores-de-Vénus';

  @override
  String get species_glass_sponge_desc =>
      'Esponja de vidro delicada, com um esqueleto de sílica intrincado, encontrada em água profunda.';

  @override
  String get species_toxic_sea_urchin_name => 'Ouriço-flor';

  @override
  String get species_toxic_sea_urchin_desc =>
      'Ouriço enganadoramente belo, coberto de pedicelárias em forma de flor com veneno potente.';

  @override
  String get species_slate_pencil_urchin_name => 'Ouriço-lápis-de-ardósia';

  @override
  String get species_slate_pencil_urchin_desc =>
      'Ouriço de espinhos grossos e arredondados, encontrado nos substratos de recife das Caraíbas e do Atlântico.';

  @override
  String get species_spiny_sea_star_name => 'Estrela-do-mar-espinhosa';

  @override
  String get species_spiny_sea_star_desc =>
      'Grande estrela-do-mar temperada, de espinhos bem visíveis, presente em águas europeias e atlânticas.';

  @override
  String get species_bat_star_name => 'Estrela-morcego';

  @override
  String get species_bat_star_desc =>
      'Estrela-do-mar do Pacífico com braços membranosos, em laranja, vermelho ou roxo, encontrada nas florestas de kelp.';

  @override
  String get species_sunflower_star_name => 'Estrela-girassol';

  @override
  String get species_sunflower_star_desc =>
      'Estrela-do-mar enorme e veloz, com até 24 braços, encontrada nas florestas de kelp do Pacífico.';

  @override
  String get species_blood_star_name => 'Estrela-sangue';

  @override
  String get species_blood_star_desc =>
      'Estrela-do-mar de braços finos e vermelho-alaranjado vivo, presente em águas temperadas do Pacífico.';

  @override
  String get species_common_cuttlefish_name => 'Choco-comum';

  @override
  String get species_common_cuttlefish_desc =>
      'Mestre da camuflagem, presente nas águas europeias e do Mediterrâneo, com pupilas em forma de W.';

  @override
  String get species_blue_spotted_crab_name =>
      'Caranguejo-nadador-de-pintas-azuis';

  @override
  String get species_blue_spotted_crab_desc =>
      'Caranguejo nadador ativo, com pintas azuis na carapaça, encontrado em substratos arenosos do Indo-Pacífico.';

  @override
  String get species_sponge_crab_name => 'Caranguejo-esponja';

  @override
  String get species_sponge_crab_desc =>
      'Caranguejo que recorta e transporta uma esponja viva às costas para se camuflar.';

  @override
  String get species_horseshoe_crab_name => 'Límulo';

  @override
  String get species_horseshoe_crab_desc =>
      'Artrópode quelicerado ancestral, de carapaça em forma de capacete, encontrado em fundos arenosos do Atlântico.';

  @override
  String get species_sea_spider_name => 'Aranha-do-mar';

  @override
  String get species_sea_spider_desc =>
      'Artrópode marinho delicado, de patas compridas, encontrado a rastejar sobre hidroides e briozoários.';

  @override
  String get species_sea_lily_name => 'Lírio-do-mar';

  @override
  String get species_sea_lily_desc =>
      'Crinoide pedunculado, um fóssil vivo de águas mais profundas, que filtra alimento com os braços plumosos.';

  @override
  String get species_mantis_shrimp_lysiosquilla_name =>
      'Camarão-louva-a-deus-arpoador';

  @override
  String get species_mantis_shrimp_lysiosquilla_desc =>
      'Grande camarão-louva-a-deus cavador, com apêndices de arpoar, encontrado em substratos arenosos.';

  @override
  String get species_purple_sea_urchin_name => 'Ouriço-do-mar-roxo';

  @override
  String get species_purple_sea_urchin_desc =>
      'Ouriço roxo e abundante, encontrado nas florestas de kelp e poças de maré rochosas do Pacífico.';

  @override
  String get species_crown_jellyfish_name => 'Alforreca-coroa';

  @override
  String get species_crown_jellyfish_desc =>
      'Alforreca de roxo profundo, com um sino elevado em forma de coroa, presente no Indo-Pacífico.';

  @override
  String get species_comb_jelly_name => 'Groselha-do-mar';

  @override
  String get species_comb_jelly_desc =>
      'Pequeno ctenóforo bioluminescente, com fileiras de pentes iridescentes e dois longos tentáculos.';

  @override
  String get species_warty_sea_slug_name => 'Lesma-do-mar-verrugosa';

  @override
  String get species_warty_sea_slug_desc =>
      'Nudibrânquio azul e negro com tubérculos de topo amarelo, visto com frequência nos recifes do Indo-Pacífico.';

  @override
  String get species_doris_nudibranch_name => 'Limão-do-mar';

  @override
  String get species_doris_nudibranch_desc =>
      'Nudibrânquio dórido amarelo e pintalgado, presente em águas temperadas do Pacífico, onde se alimenta de esponjas.';

  @override
  String get species_opalescent_nudibranch_name => 'Nudibrânquio-opalescente';

  @override
  String get species_opalescent_nudibranch_desc =>
      'Eólido translúcido, com cerata laranja vivos e linhas dorsais azuis, presente em águas do Pacífico.';

  @override
  String get species_clown_nudibranch_name => 'Nudibrânquio-palhaço';

  @override
  String get species_clown_nudibranch_desc =>
      'Nudibrânquio rosa-alaranjado com pintas azuis e brancas, presente em águas temperadas da Austrália.';

  @override
  String get species_bottlenose_dolphin_name => 'Golfinho-roaz';

  @override
  String get species_bottlenose_dolphin_desc =>
      'Golfinho curioso e brincalhão, encontrado com frequência pelos mergulhadores em águas tropicais e temperadas.';

  @override
  String get species_spinner_dolphin_name => 'Golfinho-rotador';

  @override
  String get species_spinner_dolphin_desc =>
      'Golfinho acrobático, conhecido pelos saltos com rotação, visto muitas vezes em grandes grupos junto aos recifes de coral.';

  @override
  String get species_common_dolphin_name => 'Golfinho-comum';

  @override
  String get species_common_dolphin_desc =>
      'Golfinho veloz, com um padrão distintivo em ampulheta, presente em mar aberto e em águas costeiras.';

  @override
  String get species_spotted_dolphin_name => 'Golfinho-pintado-do-Atlântico';

  @override
  String get species_spotted_dolphin_desc =>
      'Golfinho pintado e sociável, que se aproxima com frequência dos mergulhadores nas Baamas e nas Caraíbas.';

  @override
  String get species_rissos_dolphin_name => 'Golfinho-de-Risso';

  @override
  String get species_rissos_dolphin_desc =>
      'Golfinho grande, de corpo cinzento coberto de cicatrizes, presente em águas profundas ao largo em todo o mundo.';

  @override
  String get species_humpback_whale_name => 'Baleia-de-bossa';

  @override
  String get species_humpback_whale_desc =>
      'Baleia majestosa, conhecida pelos saltos e pelos cantos complexos, avistada durante as migrações sazonais.';

  @override
  String get species_grey_whale_name => 'Baleia-cinzenta';

  @override
  String get species_grey_whale_desc =>
      'Baleia de barbas que se alimenta no fundo e migra ao longo da costa do Pacífico, muitas vezes coberta de cracas.';

  @override
  String get species_blue_whale_name => 'Baleia-azul';

  @override
  String get species_blue_whale_desc =>
      'O maior animal que alguma vez existiu, encontrado ocasionalmente pelos mergulhadores em água azul profunda.';

  @override
  String get species_sperm_whale_name => 'Cachalote';

  @override
  String get species_sperm_whale_desc =>
      'Baleia de mergulho profundo, de cabeça enorme, por vezes vista a repousar à superfície entre mergulhos.';

  @override
  String get species_orca_name => 'Orca';

  @override
  String get species_orca_desc =>
      'Predador de topo com marcas pretas e brancas inconfundíveis, presente em todas as bacias oceânicas.';

  @override
  String get species_minke_whale_name => 'Baleia-anã';

  @override
  String get species_minke_whale_desc =>
      'Baleia de barbas mais pequena e curiosa perante os mergulhadores, sobretudo na Grande Barreira de Coral.';

  @override
  String get species_beluga_whale_name => 'Beluga';

  @override
  String get species_beluga_whale_desc =>
      'Baleia branca do Ártico, conhecida pelas vocalizações e pelo comportamento sociável em águas frias.';

  @override
  String get species_pilot_whale_name => 'Baleia-piloto-de-barbatanas-curtas';

  @override
  String get species_pilot_whale_desc =>
      'Baleia social e de mergulho profundo, vista muitas vezes em grandes grupos em mares tropicais e temperados quentes.';

  @override
  String get species_false_killer_whale_name => 'Falsa-orca';

  @override
  String get species_false_killer_whale_desc =>
      'Grande golfinho oceânico que se aproxima ocasionalmente dos mergulhadores em mar aberto.';

  @override
  String get species_dugong_name => 'Dugongo';

  @override
  String get species_dugong_desc =>
      'Herbívoro pacífico que pasta nas pradarias marinhas do Indo-Pacífico, parente próximo dos peixes-boi.';

  @override
  String get species_west_indian_manatee_name => 'Peixe-boi-das-Caraíbas';

  @override
  String get species_west_indian_manatee_desc =>
      'Herbívoro lento presente em águas quentes pouco profundas, estuários e nascentes das Caraíbas.';

  @override
  String get species_sea_otter_name => 'Lontra-marinha';

  @override
  String get species_sea_otter_desc =>
      'Mamífero marinho carismático, presente nas florestas de kelp ao longo da costa do Pacífico Norte.';

  @override
  String get species_california_sea_lion_name => 'Leão-marinho-da-Califórnia';

  @override
  String get species_california_sea_lion_desc =>
      'Pinípede ágil e brincalhão, que interage muitas vezes com os mergulhadores ao longo da costa do Pacífico.';

  @override
  String get species_steller_sea_lion_name => 'Leão-marinho-de-Steller';

  @override
  String get species_steller_sea_lion_desc =>
      'A maior espécie de leão-marinho, presente nas águas frias do Pacífico Norte junto a costas rochosas.';

  @override
  String get species_harbor_seal_name => 'Foca-comum';

  @override
  String get species_harbor_seal_desc =>
      'Foca curiosa, vista com frequência em águas costeiras temperadas, muitas vezes a repousar em rochas junto aos locais de mergulho.';

  @override
  String get species_grey_seal_name => 'Foca-cinzenta';

  @override
  String get species_grey_seal_desc =>
      'Foca grande e brincalhona do Atlântico Norte, conhecida por se aproximar dos mergulhadores debaixo de água.';

  @override
  String get species_northern_elephant_seal_name => 'Elefante-marinho-do-norte';

  @override
  String get species_northern_elephant_seal_desc =>
      'Foca enorme e de mergulho profundo; os machos têm uma grande probóscide. Presente ao longo da costa oriental do Pacífico.';

  @override
  String get species_hawaiian_monk_seal_name => 'Foca-monge-do-Havai';

  @override
  String get species_hawaiian_monk_seal_desc =>
      'Foca criticamente ameaçada e endémica do Havai, avistada ocasionalmente pelos mergulhadores nos recifes.';

  @override
  String get species_leopard_seal_name => 'Foca-leopardo';

  @override
  String get species_leopard_seal_desc =>
      'Predador poderoso da Antártida, de pelagem malhada, encontrado por mergulhadores de águas frias.';

  @override
  String get species_narwhal_name => 'Narval';

  @override
  String get species_narwhal_desc =>
      'Baleia do Ártico com uma longa presa em espiral, raramente vista mas icónica entre os mamíferos marinhos.';

  @override
  String get species_green_sea_turtle_name => 'Tartaruga-verde';

  @override
  String get species_green_sea_turtle_desc =>
      'Grande tartaruga marinha, vista com frequência a pastar nas pradarias marinhas de águas tropicais.';

  @override
  String get species_hawksbill_sea_turtle_name => 'Tartaruga-de-pente';

  @override
  String get species_hawksbill_sea_turtle_desc =>
      'Tartaruga de recife com um bico pontiagudo, que se alimenta de esponjas entre as formações de coral.';

  @override
  String get species_loggerhead_sea_turtle_name => 'Tartaruga-comum';

  @override
  String get species_loggerhead_sea_turtle_desc =>
      'Tartaruga de cabeça grande, presente em mares temperados e tropicais, muitas vezes junto a recifes rochosos.';

  @override
  String get species_leatherback_sea_turtle_name => 'Tartaruga-de-couro';

  @override
  String get species_leatherback_sea_turtle_desc =>
      'A maior tartaruga viva, com uma carapaça flexível e coriácea, capaz de mergulhos a profundidades extremas.';

  @override
  String get species_olive_ridley_sea_turtle_name => 'Tartaruga-oliva';

  @override
  String get species_olive_ridley_sea_turtle_desc =>
      'A mais pequena das tartarugas marinhas, conhecida pelas desovas em massa sincronizadas a que se chama arribadas.';

  @override
  String get species_kemps_ridley_sea_turtle_name => 'Tartaruga-de-Kemp';

  @override
  String get species_kemps_ridley_sea_turtle_desc =>
      'Tartaruga marinha criticamente ameaçada, presente sobretudo no golfo do México.';

  @override
  String get species_flatback_sea_turtle_name => 'Tartaruga-de-dorso-plano';

  @override
  String get species_flatback_sea_turtle_desc =>
      'Endémica das águas australianas, distingue-se pela carapaça achatada e pelo habitat costeiro.';

  @override
  String get species_brain_coral_name => 'Coral-cérebro';

  @override
  String get species_brain_coral_desc =>
      'Coral construtor de recife maciço, de superfície sulcada semelhante a um cérebro, comum nos recifes das Caraíbas.';

  @override
  String get species_staghorn_coral_name => 'Coral-chifre-de-veado';

  @override
  String get species_staghorn_coral_desc =>
      'Coral ramificado de crescimento rápido que forma matas densas, um habitat essencial para os peixes de recife.';

  @override
  String get species_elkhorn_coral_name => 'Coral-chifre-de-alce';

  @override
  String get species_elkhorn_coral_desc =>
      'Grande coral ramificado, de ramos achatados e palmados, um construtor de recife fundamental nas Caraíbas.';

  @override
  String get species_table_coral_name => 'Coral-mesa';

  @override
  String get species_table_coral_desc =>
      'Coral achatado em forma de placa, presente nos recifes do Indo-Pacífico, que dá abrigo a muitas espécies de peixes.';

  @override
  String get species_mushroom_coral_name => 'Coral-cogumelo';

  @override
  String get species_mushroom_coral_desc =>
      'Coral solitário e de vida livre, em forma de disco, encontrado em zonas arenosas junto aos recifes do Indo-Pacífico.';

  @override
  String get species_bubble_coral_name => 'Coral-bolha';

  @override
  String get species_bubble_coral_desc =>
      'Coral inconfundível, com vesículas semelhantes a bagos de uva que se insuflam de dia para captar luz.';

  @override
  String get species_plate_coral_name => 'Coral-prato';

  @override
  String get species_plate_coral_desc =>
      'Coral de placas finas que forma prateleiras em espiral, comum nas encostas de recife do Indo-Pacífico.';

  @override
  String get species_pillar_coral_name => 'Coral-pilar';

  @override
  String get species_pillar_coral_desc =>
      'Coral raro de crescimento vertical, que forma colunas altas, presente nas Caraíbas.';

  @override
  String get species_star_coral_name => 'Coral-estrela';

  @override
  String get species_star_coral_desc =>
      'Grande construtor de recife das Caraíbas, que forma colónias em forma de blocos com pólipos estrelados.';

  @override
  String get species_lettuce_coral_name => 'Coral-alface';

  @override
  String get species_lettuce_coral_desc =>
      'Coral de placas finas com dobras semelhantes a folhas, comum nas paredes e encostas de recife das Caraíbas.';

  @override
  String get species_finger_coral_name => 'Coral-dedo';

  @override
  String get species_finger_coral_desc =>
      'Coral ramificado e robusto, com projeções grossas em forma de dedo, encontrado em recifes pouco profundos.';

  @override
  String get species_massive_porites_name => 'Coral-porites-maciço';

  @override
  String get species_massive_porites_desc =>
      'Grande coral em bloco que pode crescer durante séculos, um construtor de recife dominante no Indo-Pacífico.';

  @override
  String get species_cauliflower_coral_name => 'Coral-couve-flor';

  @override
  String get species_cauliflower_coral_desc =>
      'Coral ramificado e compacto, com forma de couve-flor, muito difundido nos recifes tropicais pouco profundos.';

  @override
  String get species_flower_pot_coral_name => 'Coral-vaso-de-flores';

  @override
  String get species_flower_pot_coral_desc =>
      'Colónia de pólipos de tentáculos longos que se estendem durante o dia, lembrando um ramo de flores.';

  @override
  String get species_cup_coral_name => 'Coral-taça-laranja';

  @override
  String get species_cup_coral_desc =>
      'Coral laranja-vivo e não fotossintético, encontrado em paredes e abrigos de águas tropicais.';

  @override
  String get species_scroll_coral_name => 'Coral-pergaminho';

  @override
  String get species_scroll_coral_desc =>
      'Coral que forma grandes placas enroladas, comum nas encostas de recife e lagunas do Indo-Pacífico.';

  @override
  String get species_cabbage_coral_name => 'Coral-couve';

  @override
  String get species_cabbage_coral_desc =>
      'Coral de placas em forma de disco, semelhante a folhas de couve, encontrado em zonas abrigadas do recife.';

  @override
  String get species_hammer_coral_name => 'Coral-martelo';

  @override
  String get species_hammer_coral_desc =>
      'Coral de pólipos grandes, com pontas dos tentáculos em forma de âncora ou martelo, muito apreciado nos recifes do Indo-Pacífico.';

  @override
  String get species_torch_coral_name => 'Coral-tocha';

  @override
  String get species_torch_coral_desc =>
      'Coral ramificado com tentáculos longos e ondulantes rematados por bolbos luminosos.';

  @override
  String get species_frogspawn_coral_name => 'Coral-ovas-de-rã';

  @override
  String get species_frogspawn_coral_desc =>
      'Coral de pólipos grandes, com pontas dos tentáculos ramificadas que lembram ovos de rã.';

  @override
  String get species_sea_fan_name => 'Gorgónia-leque-comum';

  @override
  String get species_sea_fan_desc =>
      'Gorgónia achatada em forma de leque, orientada perpendicularmente às correntes, um ícone dos recifes das Caraíbas.';

  @override
  String get species_venus_sea_fan_name => 'Leque-do-mar-de-Vénus';

  @override
  String get species_venus_sea_fan_desc =>
      'Gorgónia delicada em forma de leque, presente em recifes pouco profundos das Caraíbas com corrente moderada.';

  @override
  String get species_deepwater_sea_fan_name => 'Gorgónia-de-águas-profundas';

  @override
  String get species_deepwater_sea_fan_desc =>
      'Gorgónia grande e ramosa, encontrada em paredes de recife profundas nas Caraíbas.';

  @override
  String get species_sea_whip_name => 'Gorgónia-chicote';

  @override
  String get species_sea_whip_desc =>
      'Gorgónia esguia em forma de vara, encontrada a baloiçar nas correntes dos recifes do Atlântico e das Caraíbas.';

  @override
  String get species_sea_plume_name => 'Gorgónia-pluma';

  @override
  String get species_sea_plume_desc =>
      'Gorgónia alta e plumosa, que forma colónias em forma de pluma nos topos dos recifes das Caraíbas.';

  @override
  String get species_organ_pipe_coral_name => 'Coral-tubo-de-órgão';

  @override
  String get species_organ_pipe_coral_desc =>
      'Tubos esqueléticos vermelho-vivos com pólipos delicados, encontrados em recifes abrigados do Indo-Pacífico.';

  @override
  String get species_leather_coral_name => 'Coral-couro';

  @override
  String get species_leather_coral_desc =>
      'Coral mole de superfície lisa e coriácea, que forma grandes colónias em forma de cogumelo.';

  @override
  String get species_toadstool_leather_coral_name => 'Coral-couro-cogumelo';

  @override
  String get species_toadstool_leather_coral_desc =>
      'Coral mole com um pé espesso e um chapéu achatado, comum nos planaltos de recife do Indo-Pacífico.';

  @override
  String get species_pulsing_xenia_name => 'Xénia-pulsante';

  @override
  String get species_pulsing_xenia_desc =>
      'Coral mole com pólipos que pulsam ritmadamente, presente em águas abrigadas do Indo-Pacífico.';

  @override
  String get species_tree_coral_name => 'Coral-árvore';

  @override
  String get species_tree_coral_desc =>
      'Coral mole vibrante que forma grupos em forma de árvore em paredes e abrigos do mar Vermelho.';

  @override
  String get species_blue_coral_name => 'Coral-azul';

  @override
  String get species_blue_coral_desc =>
      'Octocoral singular, de esqueleto azul, encontrado nos planaltos de recife pouco profundos do Indo-Pacífico.';

  @override
  String get species_black_coral_name => 'Coral-negro';

  @override
  String get species_black_coral_desc =>
      'Coral de água profunda, de esqueleto escuro, encontrado em paredes e escarpas abaixo dos 30 metros.';

  @override
  String get species_carnation_coral_name => 'Coral-cravo';

  @override
  String get species_carnation_coral_desc =>
      'Coral mole de cores vivas, encontrado sob saliências e em paredes do Indo-Pacífico.';

  @override
  String get species_wire_coral_name => 'Coral-arame';

  @override
  String get species_wire_coral_desc =>
      'Coral negro comprido e espiralado, que forma chicotes enrolados, hospedeiro de góbios e camarões.';

  @override
  String get species_dead_mans_fingers_name => 'Dedos-de-defunto';

  @override
  String get species_dead_mans_fingers_desc =>
      'Coral mole e carnudo, de lobos em forma de dedo, comum nos recifes temperados do Atlântico Norte.';

  @override
  String get species_sun_coral_name => 'Coral-sol';

  @override
  String get species_sun_coral_desc =>
      'Coral amarelo-alaranjado e não fotossintético, que abre os pólipos à noite nas paredes do Indo-Pacífico.';

  @override
  String get species_lace_coral_name => 'Coral-renda';

  @override
  String get species_lace_coral_desc =>
      'Hidrocoral rosa delicado, de ramos rendilhados, encontrado em fendas e sob saliências.';

  @override
  String get species_kenya_tree_coral_name => 'Coral-árvore-do-Quénia';

  @override
  String get species_kenya_tree_coral_desc =>
      'Coral mole resistente, de ramos em forma de árvore, comum no Indo-Pacífico.';

  @override
  String get species_colt_coral_name => 'Coral-colt';

  @override
  String get species_colt_coral_desc =>
      'Coral mole de ramos espessos e emborrachados, cobertos de pequenos pólipos, nos recifes do Indo-Pacífico.';

  @override
  String get species_turtle_grass_name => 'Erva-de-tartaruga';

  @override
  String get species_turtle_grass_desc =>
      'Erva marinha dominante nas Caraíbas, de lâminas largas e achatadas, alimento vital para as tartarugas marinhas.';

  @override
  String get species_eelgrass_name => 'Zostera';

  @override
  String get species_eelgrass_desc =>
      'Erva marinha temperada que forma pradarias submersas densas, servindo de habitat de berçário.';

  @override
  String get species_manatee_grass_name => 'Erva-de-peixe-boi';

  @override
  String get species_manatee_grass_desc =>
      'Erva marinha de lâminas cilíndricas, presente em zonas arenosas das Caraíbas, muitas vezes junto a pradarias de erva-de-tartaruga.';

  @override
  String get species_shoal_grass_name => 'Erva-de-baixio';

  @override
  String get species_shoal_grass_desc =>
      'Erva marinha pioneira, de lâminas estreitas, que coloniza zonas arenosas perturbadas nas Caraíbas.';

  @override
  String get species_paddle_grass_name => 'Erva-remo';

  @override
  String get species_paddle_grass_desc =>
      'Erva marinha pequena e delicada, de folhas ovais, encontrada em águas mais profundas de todos os trópicos.';

  @override
  String get species_neptune_grass_name => 'Posidónia';

  @override
  String get species_neptune_grass_desc =>
      'Erva marinha do Mediterrâneo que forma vastas pradarias essenciais para os ecossistemas marinhos costeiros.';

  @override
  String get species_giant_kelp_name => 'Kelp-gigante';

  @override
  String get species_giant_kelp_desc =>
      'Espécie que forma florestas submersas imponentes, com até 60 metros de altura, um ícone do mergulho na Califórnia.';

  @override
  String get species_bull_kelp_name => 'Kelp-touro';

  @override
  String get species_bull_kelp_desc =>
      'Kelp do Pacífico com um único estipe comprido e um flutuador bolboso, que forma florestas de copado denso.';

  @override
  String get species_bladder_wrack_name => 'Bodelha';

  @override
  String get species_bladder_wrack_desc =>
      'Alga castanha comum, com vesículas de ar aos pares, encontrada nas zonas intertidais do Atlântico Norte.';

  @override
  String get species_sargassum_name => 'Sargaço';

  @override
  String get species_sargassum_desc =>
      'Alga castanha flutuante que forma jangadas onde se abrigam peixes juvenis e invertebrados.';

  @override
  String get species_kelp_forest_ecklonia_name => 'Kelp-ecklonia';

  @override
  String get species_kelp_forest_ecklonia_desc =>
      'Kelp dominante nas águas do hemisfério sul, onde forma florestas submersas importantes.';

  @override
  String get species_coralline_algae_name => 'Algas-coralinas';

  @override
  String get species_coralline_algae_desc =>
      'Alga vermelha incrustante e dura que cimenta as estruturas do recife e lhe dá um tom rosado.';

  @override
  String get species_irish_moss_name => 'Musgo-da-Irlanda';

  @override
  String get species_irish_moss_desc =>
      'Alga vermelha em forma de leque, encontrada nas costas rochosas da zona intertidal do Atlântico Norte.';

  @override
  String get species_dulse_name => 'Dulse';

  @override
  String get species_dulse_desc =>
      'Alga achatada de tom vermelho-arroxeado, que cresce sobre rochas e estipes de kelp em águas frias do norte.';

  @override
  String get species_halimeda_name => 'Halimeda';

  @override
  String get species_halimeda_desc =>
      'Alga verde calcificada, de segmentos em forma de disco, grande responsável pela areia dos recifes.';

  @override
  String get species_sea_lettuce_name => 'Alface-do-mar';

  @override
  String get species_sea_lettuce_desc =>
      'Alga verde-viva em lâminas finas, encontrada em águas costeiras pouco profundas de todo o mundo.';

  @override
  String get species_caulerpa_name => 'Alga-uva-verde';

  @override
  String get species_caulerpa_desc =>
      'Alga verde rastejante, de frondes semelhantes a cachos de uvas, encontrada em cascalho e areia de recifes tropicais.';

  @override
  String get species_mermaid_fan_name => 'Leque-de-sereia';

  @override
  String get species_mermaid_fan_desc =>
      'Alga verde calcificada com a forma de um pequeno leque, comum nos fundos arenosos das Caraíbas.';

  @override
  String get species_shaving_brush_algae_name => 'Alga-pincel-de-barba';

  @override
  String get species_shaving_brush_algae_desc =>
      'Alga verde calcificada, com um tufo em forma de pincel sobre um pé, encontrada nos fundos arenosos das Caraíbas.';

  @override
  String get species_finger_kelp_name => 'Laminária-digitada';

  @override
  String get species_finger_kelp_desc =>
      'Alga castanha de frondes em forma de dedos, que forma bosques de kelp nas águas costeiras do Atlântico Norte.';

  @override
  String get species_banded_sea_krait_name => 'Serpente-marinha-de-bandas';

  @override
  String get species_banded_sea_krait_desc =>
      'Serpente marinha venenosa, com bandas azul-acinzentadas e negras, dócil e vista com frequência nos recifes do Indo-Pacífico.';

  @override
  String get species_olive_sea_snake_name => 'Serpente-marinha-oliva';

  @override
  String get species_olive_sea_snake_desc =>
      'Serpente marinha curiosa dos recifes australianos, conhecida por se aproximar dos mergulhadores.';

  @override
  String get species_yellow_bellied_sea_snake_name =>
      'Serpente-marinha-de-ventre-amarelo';

  @override
  String get species_yellow_bellied_sea_snake_desc =>
      'Serpente marinha pelágica de ventre amarelo, a espécie de serpente com maior distribuição no planeta.';

  @override
  String get species_marine_iguana_name => 'Iguana-marinha';

  @override
  String get species_marine_iguana_desc =>
      'Endémica dos Galápagos, é o único lagarto que se alimenta de algas debaixo de água.';

  @override
  String get species_saltwater_crocodile_name => 'Crocodilo-de-água-salgada';

  @override
  String get species_saltwater_crocodile_desc =>
      'O maior réptil vivo, presente em águas costeiras e estuarinas do Indo-Pacífico.';

  @override
  String get common_action_done => 'Concluído';

  @override
  String get common_action_more => 'Mais';

  @override
  String get common_label_displayName => 'Nome de exibição';

  @override
  String common_relativeTime_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}d atrás',
      one: '${count}d atrás',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}h atrás',
      one: '${count}h atrás',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'em ${count}d',
      one: 'em ${count}d',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'em ${count}h',
      one: 'em ${count}h',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_inLessThanMinute => 'em <1min';

  @override
  String common_relativeTime_inMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'em ${count}min',
      one: 'em ${count}min',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_justNow => 'agora mesmo';

  @override
  String common_relativeTime_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${count}min atrás',
      one: '${count}min atrás',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meses atrás',
      one: '$count mês atrás',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_overdue => 'atrasado';

  @override
  String get media_cache_calculating => 'Calculando o tamanho do cache…';

  @override
  String get media_cache_cardTitle => 'Gerenciamento de cache';

  @override
  String get media_cache_clearAction => 'Limpar cache';

  @override
  String get media_cache_clearBody =>
      'Remove miniaturas e imagens de rede em tamanho completo já baixadas. As mídias vinculadas são mantidas; as imagens serão baixadas novamente na próxima visualização.';

  @override
  String get media_cache_clearConfirm => 'Limpar';

  @override
  String media_cache_clearError(String error) {
    return 'Falha ao limpar: $error';
  }

  @override
  String get media_cache_clearTitle => 'Limpar o cache de imagens de rede?';

  @override
  String get media_cache_cleared => 'Cache limpo';

  @override
  String get media_cache_diskCache => 'Cache em disco';

  @override
  String media_cache_error(String error) {
    return 'Erro: $error';
  }

  @override
  String get media_credentials_actionTest => 'Testar credenciais';

  @override
  String media_credentials_authLabel(String authType) {
    return 'Autenticação: $authType';
  }

  @override
  String get media_credentials_deleteBody =>
      'Remove as credenciais salvas. Os itens vinculados por meio deste host passarão a exibir \"Requer login\" até que você os adicione novamente.';

  @override
  String media_credentials_deleteError(String error) {
    return 'Falha ao excluir: $error';
  }

  @override
  String media_credentials_deleteTitle(String host) {
    return 'Excluir $host?';
  }

  @override
  String media_credentials_deleted(String host) {
    return '$host excluído';
  }

  @override
  String media_credentials_editTitle(String host) {
    return 'Editar $host';
  }

  @override
  String get media_credentials_emptySubtitle =>
      'As credenciais por host adicionadas durante importações por URL ou manifesto aparecem aqui.';

  @override
  String get media_credentials_emptyTitle => 'Nenhuma credencial salva';

  @override
  String media_credentials_lastUsed(String when) {
    return 'Último uso $when';
  }

  @override
  String get media_credentials_loadError =>
      'Não foi possível carregar os hosts salvos';

  @override
  String get media_credentials_loading => 'Carregando hosts salvos...';

  @override
  String media_credentials_saveError(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get media_credentials_savedHostsTitle => 'Hosts salvos';

  @override
  String media_credentials_testError(String error) {
    return 'Falha no teste: $error';
  }

  @override
  String media_credentials_testFailed(String host) {
    return 'Falha nas credenciais de $host';
  }

  @override
  String media_credentials_testOk(String host) {
    return 'Credenciais OK para $host';
  }

  @override
  String get media_manifest_actionPollNow => 'Consultar agora';

  @override
  String get media_manifest_cardTitle => 'Assinaturas de manifesto';

  @override
  String get media_manifest_deleteBody =>
      'Remove a assinatura. As entradas já importadas permanecerão (você pode limpá-las pela fila de órfãos).';

  @override
  String media_manifest_deleteError(String error) {
    return 'Falha ao excluir: $error';
  }

  @override
  String media_manifest_deleteTitle(String name) {
    return 'Excluir $name?';
  }

  @override
  String get media_manifest_editTitle => 'Editar assinatura';

  @override
  String get media_manifest_emptySubtitle =>
      'Assine um manifesto Atom/RSS, JSON ou CSV na aba URL para manter sua biblioteca sincronizada.';

  @override
  String get media_manifest_emptyTitle => 'Nenhuma assinatura de manifesto';

  @override
  String media_manifest_lastError(String error) {
    return 'Último erro: $error';
  }

  @override
  String media_manifest_lastPolled(String when) {
    return 'Última consulta $when';
  }

  @override
  String get media_manifest_loadError =>
      'Não foi possível carregar as assinaturas';

  @override
  String get media_manifest_loading => 'Carregando assinaturas...';

  @override
  String get media_manifest_neverPolled => 'Nunca consultado';

  @override
  String media_manifest_nextPoll(String when) {
    return 'Próxima $when';
  }

  @override
  String get media_manifest_notFound => 'Assinatura não encontrada';

  @override
  String media_manifest_pollError(String error) {
    return 'Falha na consulta: $error';
  }

  @override
  String media_manifest_polled(String name) {
    return '$name consultado';
  }

  @override
  String media_manifest_polling(String name) {
    return 'Consultando $name...';
  }

  @override
  String media_manifest_saveError(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String media_manifest_updateError(String error) {
    return 'Não foi possível atualizar: $error';
  }

  @override
  String get media_manifest_urlLabel => 'URL do manifesto';

  @override
  String media_scan_failed(String error) {
    return 'Falha na verificação: $error';
  }

  @override
  String media_scan_progressItems(int done, int total) {
    return '$done / $total itens';
  }

  @override
  String media_scan_progressReachability(int available, int unreachable) {
    return '$available acessíveis  ·  $unreachable inacessíveis';
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
          '$total itens verificados em ${seconds}s: $available acessíveis, $unreachable inacessíveis',
      one:
          '$total item verificado em ${seconds}s: $available acessível, $unreachable inacessível',
    );
    return '$_temp0';
  }

  @override
  String media_scan_summarySkipped(String base, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ignorados (sem URL)',
      one: '$count ignorado (sem URL)',
    );
    return '$base, $_temp0';
  }

  @override
  String get media_scan_title => 'Verificar todas as mídias de rede';

  @override
  String get settings_mediaSources_androidUriTitle =>
      'Permissões de URI do Android';

  @override
  String settings_mediaSources_androidUriUsage(int used, int limit) {
    return '$used / $limit URIs persistentes em uso';
  }

  @override
  String get settings_mediaSources_counting => 'Contando…';

  @override
  String settings_mediaSources_error(String error) {
    return 'Erro: $error';
  }

  @override
  String get settings_mediaSources_loading => 'Carregando…';

  @override
  String settings_mediaSources_localFilesCounts(
    int available,
    int unavailable,
  ) {
    return '$available disponíveis, $unavailable indisponíveis';
  }

  @override
  String get settings_mediaSources_photoLibrarySubtitle =>
      'Apple Photos / Google Photos / iCloud';

  @override
  String get settings_mediaSources_reverifyAll =>
      'Reverificar todos os arquivos locais';

  @override
  String settings_mediaSources_reverifyFailed(String error) {
    return 'Falha na reverificação: $error';
  }

  @override
  String settings_mediaSources_reverifyResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens atualizados',
      one: '$count item atualizado',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_checkAll => 'Verificar todas as mídias';

  @override
  String settings_mediaSources_checkAllResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens atualizados',
      one: '$count item atualizado',
    );
    return '$_temp0';
  }

  @override
  String settings_mediaSources_checkAllBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Não foi possível verificar nenhum dos $count itens. As origens deles não estão acessíveis no momento.',
      one:
          'Não foi possível verificar o item. A origem dele não está acessível no momento.',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_title => 'Fontes de mídia';

  @override
  String get settings_networkSources_scanDescription =>
      'Verifica novamente cada foto importada por URL ou manifesto junto ao seu host. Marca os itens inacessíveis para que apareçam como \"ausentes\" na sua biblioteca e possam ser removidos.';

  @override
  String statistics_conditions_entryMethod_semanticLabel(String description) {
    return 'Gráfico de barras. Métodos de entrada. $description';
  }

  @override
  String statistics_conditions_visibility_semanticLabel(String description) {
    return 'Gráfico de pizza. Distribuição de visibilidade. $description';
  }

  @override
  String statistics_conditions_waterType_semanticLabel(String description) {
    return 'Gráfico de pizza. Distribuição de tipo de água. $description';
  }

  @override
  String statistics_progression_divesBySuitThickness_semanticLabel(
    String description,
  ) {
    return 'Gráfico de barras. Mergulhos por espessura da roupa. $description';
  }

  @override
  String statistics_progression_divesPerYear_countInYear(
    int count,
    String year,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos em $year',
      one: '1 mergulho em $year',
    );
    return '$_temp0';
  }

  @override
  String statistics_progression_divesPerYear_semanticLabel(String description) {
    return 'Gráfico de barras. Mergulhos por ano. $description';
  }

  @override
  String get statistics_records_unavailable => 'Recordes indisponíveis';

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
  String get statistics_summary_distributions_title => 'Distribuições';

  @override
  String get statistics_summary_diveTypes_error =>
      'Não foi possível carregar os dados de tipo de mergulho';

  @override
  String get statistics_summary_diveTypes_unknown => 'Desconhecido';

  @override
  String get statistics_summary_divesPerMonth => 'Mergulhos / Mês';

  @override
  String get statistics_summary_divesPerYear => 'Mergulhos / Ano';

  @override
  String statistics_timePatterns_dayOfWeek_semanticLabel(String description) {
    return 'Gráfico de barras. Mergulhos por dia da semana. $description';
  }

  @override
  String statistics_timePatterns_seasonal_semanticLabel(String description) {
    return 'Gráfico de barras. Mergulhos por mês. $description';
  }

  @override
  String statistics_timePatterns_surfaceInterval_statLabel(
    String label,
    String value,
  ) {
    return 'Intervalo de superfície $label: $value';
  }

  @override
  String get statistics_timePatterns_timeOfDay_afternoon => 'Tarde';

  @override
  String get statistics_timePatterns_timeOfDay_evening => 'Noite';

  @override
  String get statistics_timePatterns_timeOfDay_morning => 'Manhã';

  @override
  String get statistics_timePatterns_timeOfDay_night => 'Madrugada';

  @override
  String statistics_timePatterns_timeOfDay_semanticLabel(String description) {
    return 'Gráfico de pizza. Mergulhos por hora do dia. $description';
  }

  @override
  String get columnConfig_displayOptions => 'Opções de exibição';

  @override
  String get columnConfig_noExtraFields =>
      'Nenhum campo extra configurado. Adicione campos abaixo.';

  @override
  String get columnConfig_savePresetTitle => 'Salvar predefinição';

  @override
  String get columnConfig_section => 'Seção';

  @override
  String get columnConfig_showTags => 'Mostrar tags';

  @override
  String get columnConfig_showTags_subtitle =>
      'Exibir chips de tags nos cartões de mergulho detalhados';

  @override
  String get columnConfig_slot_date => 'Data / Subtítulo';

  @override
  String get columnConfig_slot_slot1 => 'Posição 1';

  @override
  String get columnConfig_slot_slot2 => 'Posição 2';

  @override
  String get columnConfig_slot_slot3 => 'Posição 3';

  @override
  String get columnConfig_slot_slot4 => 'Posição 4';

  @override
  String get columnConfig_slot_stat1 => 'Estatística 1';

  @override
  String get columnConfig_slot_stat2 => 'Estatística 2';

  @override
  String get columnConfig_slot_subtitle => 'Subtítulo';

  @override
  String get columnConfig_slot_title => 'Título';

  @override
  String get columnConfig_tooltip_columnSettings => 'Configurações de colunas';

  @override
  String get common_action_add => 'Adicionar';

  @override
  String get common_action_pin => 'Fixar';

  @override
  String get common_action_remove => 'Remover';

  @override
  String get common_action_unpin => 'Desafixar';

  @override
  String diveLog_filterChip_dateRange(String end, String start) {
    return '$start a $end';
  }

  @override
  String diveLog_filterChip_equipmentCount(int count) {
    return '$count equipamentos';
  }

  @override
  String get diveLog_filter_allComputers => 'Todos os computadores';

  @override
  String get diveLog_filter_noComputersRegistered =>
      'Nenhum computador de mergulho registrado';

  @override
  String diveLog_filter_sectionDepthRangeUnit(String unit) {
    return 'Faixa de profundidade ($unit)';
  }

  @override
  String get diveLog_filter_sectionDiveComputer => 'Computador de Mergulho';

  @override
  String diveLog_listPage_semanticsDiveAtSite(int diveNumber, String siteName) {
    return 'Mergulho $diveNumber em $siteName';
  }

  @override
  String get enum_listViewMode_compact => 'Compacto';

  @override
  String get enum_listViewMode_dense => 'Denso';

  @override
  String get enum_listViewMode_detailed => 'Detalhado';

  @override
  String get enum_listViewMode_table => 'Tabela';

  @override
  String get enum_profileMetric_ascentRate => 'Taxa de Subida';

  @override
  String get enum_profileMetric_cns => 'CNS%';

  @override
  String get enum_profileMetric_otu => 'OTU';

  @override
  String get enum_sortField_bottomTime => 'Tempo de Fundo';

  @override
  String get enum_sortField_serviceDue => 'Manutenção Pendente';

  @override
  String get listViewMode_tooltip => 'Modo de visualização';

  @override
  String marineLife_speciesManage_errorLoading(Object error) {
    return 'Erro ao carregar espécies: $error';
  }

  @override
  String get settings_appearance_header_cards => 'Cartões';

  @override
  String get settings_appearance_header_listView => 'Visualização em lista';

  @override
  String get settings_appearance_header_tableMode => 'Modo tabela';

  @override
  String get settings_appearance_listFields_buddies =>
      'Campos da lista de companheiros';

  @override
  String get settings_appearance_listFields_certifications =>
      'Campos da lista de certificações';

  @override
  String get settings_appearance_listFields_courses =>
      'Campos da lista de cursos';

  @override
  String get settings_appearance_listFields_diveCenters =>
      'Campos da lista de centros de mergulho';

  @override
  String get settings_appearance_listFields_dives =>
      'Campos da lista de mergulhos';

  @override
  String get settings_appearance_listFields_equipment =>
      'Campos da lista de equipamentos';

  @override
  String get settings_appearance_listFields_sites =>
      'Campos da lista de pontos de mergulho';

  @override
  String get settings_appearance_listFields_subtitle =>
      'Personalize os campos exibidos nas visualizações em lista';

  @override
  String get settings_appearance_listFields_trips =>
      'Campos da lista de viagens';

  @override
  String get settings_appearance_listView_buddies =>
      'Visualização da lista de companheiros';

  @override
  String get settings_appearance_listView_buddies_subtitle =>
      'Layout padrão para a lista de companheiros';

  @override
  String get settings_appearance_listView_certifications =>
      'Visualização da lista de certificações';

  @override
  String get settings_appearance_listView_certifications_subtitle =>
      'Layout padrão para a lista de certificações';

  @override
  String get settings_appearance_listView_courses =>
      'Visualização da lista de cursos';

  @override
  String get settings_appearance_listView_courses_subtitle =>
      'Layout padrão para a lista de cursos';

  @override
  String get settings_appearance_listView_diveCenters =>
      'Visualização da lista de centros de mergulho';

  @override
  String get settings_appearance_listView_diveCenters_subtitle =>
      'Layout padrão para a lista de centros de mergulho';

  @override
  String get settings_appearance_listView_dives =>
      'Visualização da lista de mergulhos';

  @override
  String get settings_appearance_listView_dives_subtitle =>
      'Layout padrão para a lista de mergulhos';

  @override
  String get settings_appearance_listView_equipment =>
      'Visualização da lista de equipamentos';

  @override
  String get settings_appearance_listView_equipment_subtitle =>
      'Layout padrão para a lista de equipamentos';

  @override
  String get settings_appearance_listView_sites =>
      'Visualização da lista de pontos de mergulho';

  @override
  String get settings_appearance_listView_sites_subtitle =>
      'Layout padrão para a lista de pontos de mergulho';

  @override
  String get settings_appearance_listView_trips =>
      'Visualização da lista de viagens';

  @override
  String get settings_appearance_listView_trips_subtitle =>
      'Layout padrão para a lista de viagens';

  @override
  String get settings_appearance_showDataSourceBadges =>
      'Mostrar selos de fonte de dados';

  @override
  String get settings_appearance_showDataSourceBadges_subtitle =>
      'Exibir a atribuição de fonte nas métricas de mergulho';

  @override
  String get settings_appearance_title_buddies => 'Aparência dos companheiros';

  @override
  String get settings_appearance_title_certifications =>
      'Aparência das certificações';

  @override
  String get settings_appearance_title_courses => 'Aparência dos cursos';

  @override
  String get settings_appearance_title_diveCenters =>
      'Aparência dos centros de mergulho';

  @override
  String get settings_appearance_title_dives => 'Aparência dos mergulhos';

  @override
  String get settings_appearance_title_equipment =>
      'Aparência dos equipamentos';

  @override
  String get settings_appearance_title_sites =>
      'Aparência dos pontos de mergulho';

  @override
  String get settings_appearance_title_trips => 'Aparência das viagens';

  @override
  String get settings_cloudSync_troubleshoot_tileSubtitle =>
      'Corrija uma sincronização travada ou libere espaço na nuvem';

  @override
  String get settings_data_header_dataTools => 'Ferramentas de dados';

  @override
  String get settings_decompression_ascentGasLabel => 'Planejar a subida com';

  @override
  String get settings_decompression_ascentGas_allCarried =>
      'Todos os cilindros transportados';

  @override
  String get settings_decompression_ascentGas_decoStage =>
      'Deco/estágio + gás de fundo';

  @override
  String get settings_decompression_cnsSource => 'Fonte do CNS';

  @override
  String get settings_decompression_decoStopSource =>
      'Fonte das paradas de deco';

  @override
  String get settings_decompression_header_ascent => 'Planejamento da subida';

  @override
  String get settings_decompression_header_ascent_subtitle =>
      'Quais cilindros transportados a subida simulada (TTS, teto e paradas) pode usar em cada profundidade. Somente os gases registrados no mergulho são considerados.';

  @override
  String get settings_decompression_header_dataSources =>
      'Preferências de fonte de dados';

  @override
  String get settings_decompression_header_dataSources_subtitle =>
      'Quando definido como Computador de Mergulho, o aplicativo usa os dados informados pelo computador de mergulho quando disponíveis. Recorre aos valores calculados quando não há dados do computador.';

  @override
  String get settings_decompression_ndlSource => 'Fonte do NDL';

  @override
  String get settings_decompression_sourceCalculated => 'Calculado';

  @override
  String get settings_decompression_sourceComputer => 'Computador de Mergulho';

  @override
  String get settings_decompression_ttsSource => 'Fonte do TTS';

  @override
  String settings_fixDiveTimes_applied(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mergulhos atualizados',
      one: 'mergulho atualizado',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'horas',
      one: 'hora',
    );
    return '$count $_temp0 em $hours $_temp1.';
  }

  @override
  String settings_fixDiveTimes_apply(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mergulhos',
      one: 'mergulho',
    );
    return 'Aplicar a $count $_temp0';
  }

  @override
  String get settings_fixDiveTimes_clearRange => 'Limpar intervalo de datas';

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
      other: 'mergulhos',
      one: 'mergulho',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'horas',
      one: 'hora',
    );
    return 'Isto vai deslocar $count $_temp0 em $hours $_temp1. Isto não pode ser desfeito automaticamente.';
  }

  @override
  String get settings_fixDiveTimes_confirmTitle =>
      'Aplicar deslocamento de horário';

  @override
  String get settings_fixDiveTimes_dateRangeFilter =>
      'Filtro de intervalo de datas';

  @override
  String get settings_fixDiveTimes_deselectAll => 'Desmarcar todos';

  @override
  String get settings_fixDiveTimes_diveFallback => 'Mergulho';

  @override
  String settings_fixDiveTimes_diveNumber(int number) {
    return 'Mergulho nº $number';
  }

  @override
  String get settings_fixDiveTimes_empty => 'Nenhum mergulho encontrado.';

  @override
  String get settings_fixDiveTimes_emptyFiltered =>
      'Nenhum mergulho encontrado neste intervalo de datas.';

  @override
  String get settings_fixDiveTimes_enterOffsetHint =>
      'Informe um deslocamento em horas';

  @override
  String get settings_fixDiveTimes_from => 'De';

  @override
  String get settings_fixDiveTimes_hourOffset => 'Deslocamento de horas';

  @override
  String get settings_fixDiveTimes_hoursField => 'Horas (ex.: +7, -5)';

  @override
  String settings_fixDiveTimes_loadError(String error) {
    return 'Falha ao carregar os mergulhos: $error';
  }

  @override
  String get settings_fixDiveTimes_noSelection =>
      'Nenhum mergulho selecionado.';

  @override
  String get settings_fixDiveTimes_offsetHint =>
      'Informe um número inteiro positivo ou negativo para deslocar os horários dos mergulhos.';

  @override
  String settings_fixDiveTimes_preview(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mergulhos serão deslocados',
      one: 'mergulho será deslocado',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'horas',
      one: 'hora',
    );
    return 'Prévia: $count $_temp0 em $hours $_temp1.';
  }

  @override
  String get settings_fixDiveTimes_selectAll => 'Selecionar todos';

  @override
  String get settings_fixDiveTimes_selectDivesHint =>
      'Selecione os mergulhos a aplicar';

  @override
  String get settings_fixDiveTimes_subtitle =>
      'Ajuste os horários de mergulhos importados';

  @override
  String get settings_fixDiveTimes_title => 'Corrigir horários de mergulho';

  @override
  String get settings_fixDiveTimes_to => 'Até';

  @override
  String get settings_fixDiveTimes_zeroOffset =>
      'O deslocamento de horas é 0, nada a alterar.';

  @override
  String get settings_syncDevices_appBar_refreshTooltip => 'Atualizar';

  @override
  String get settings_syncDevices_appBar_title => 'Dispositivos neste provedor';

  @override
  String get settings_syncDevices_empty =>
      'Nenhum arquivo de sincronização neste provedor.';

  @override
  String settings_syncDevices_readError(String error) {
    return 'Não foi possível ler o provedor.\n$error';
  }

  @override
  String get settings_syncDevices_removal_noBackend =>
      'Nenhum provedor de nuvem está configurado';

  @override
  String get settings_syncDevices_removal_unreachable =>
      'Não foi possível acessar o provedor. Nada foi removido.';

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
          'Isto exclui $count arquivos ($size) pertencentes a $name.\n\nEsse dispositivo ainda faz parte desta sincronização. Se voltar a ficar online, ele será reconstruído a partir do provedor em vez de ressuscitar dados antigos, mas quaisquer alterações que ele ainda não tenha publicado serão perdidas. Seus dados de mergulho NESTE dispositivo não são afetados.',
      one:
          'Isto exclui 1 arquivo ($size) pertencentes a $name.\n\nEsse dispositivo ainda faz parte desta sincronização. Se voltar a ficar online, ele será reconstruído a partir do provedor em vez de ressuscitar dados antigos, mas quaisquer alterações que ele ainda não tenha publicado serão perdidas. Seus dados de mergulho NESTE dispositivo não são afetados.',
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
          'Isto exclui $count arquivos ($size) pertencentes a $name. São restos de uma biblioteca da qual nenhum dispositivo sincroniza mais. Seus dados de mergulho não são afetados.',
      one:
          'Isto exclui 1 arquivo ($size) pertencentes a $name. São restos de uma biblioteca da qual nenhum dispositivo sincroniza mais. Seus dados de mergulho não são afetados.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_removeDialog_title(String name) {
    return 'Remover os arquivos de $name?';
  }

  @override
  String settings_syncDevices_removeProgressTitle(String name) {
    return 'Removendo os arquivos de $name';
  }

  @override
  String get settings_syncDevices_removeTooltip =>
      'Remover os arquivos deste dispositivo';

  @override
  String get settings_syncDevices_state_active => 'Sincronizando normalmente';

  @override
  String get settings_syncDevices_state_retired => 'Aposentado';

  @override
  String get settings_syncDevices_state_staleEpoch =>
      'Resto de uma biblioteca anterior; nenhum dispositivo lê isto';

  @override
  String get settings_syncDevices_state_thisDevice => 'Este dispositivo';

  @override
  String get settings_syncDevices_state_unreadable =>
      'Sem manifesto legível; um envio incompleto ou criptografado';

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
      other: '$fileCount arquivos',
      one: '1 arquivo',
    );
    return '$_temp0, $_temp1, $size';
  }

  @override
  String settings_syncDevices_summary_removable(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count restantes de uma biblioteca substituída ou aposentada, ocupando $size.',
      one:
          '1 restante de uma biblioteca substituída ou aposentada, ocupando $size.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_tile_filesSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos',
      one: '1 arquivo',
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
      other: '$count arquivos',
      one: '1 arquivo',
    );
    return '$_temp0, $size · $when';
  }

  @override
  String settings_syncDevices_unnamedDevice(String shortId) {
    return 'Dispositivo $shortId';
  }

  @override
  String get settings_syncMaintenance_keepAppOpen =>
      'Mantenha o aplicativo aberto até que isto termine. Fechá-lo agora deixa o provedor parcialmente limpo, e a próxima sincronização terá que começar do zero.';

  @override
  String get settings_syncMaintenance_phase_clearingOldFiles =>
      'Limpando arquivos antigos';

  @override
  String get settings_syncMaintenance_phase_deleting => 'Excluindo';

  @override
  String get settings_syncMaintenance_phase_publishingLibrary =>
      'Publicando a biblioteca';

  @override
  String get settings_cloudSync_adopt_progressTitle =>
      'Adotando a biblioteca restaurada';

  @override
  String get settings_cloudSync_replaceLibrary_progressTitle =>
      'Substituindo a biblioteca na nuvem';

  @override
  String settings_syncDevices_nameWithId(String name, String shortId) {
    return '$name ($shortId)';
  }

  @override
  String get settings_syncMaintenance_phase_applyingLibrary =>
      'Aplicando a biblioteca';

  @override
  String get settings_syncMaintenance_phase_backingUp =>
      'Fazendo backup deste dispositivo';

  @override
  String get settings_syncMaintenance_phase_repairing =>
      'Limpando o estado de sincronização local';

  @override
  String get settings_troubleshootSync_repair_progressTitle =>
      'Reparando a sincronização';

  @override
  String get settings_syncMaintenance_phase_working => 'Trabalhando...';

  @override
  String settings_syncMaintenance_progress_filesOfTotal(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done de $total arquivos',
      one: '$done de 1 arquivo',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_removedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos removidos',
      one: '1 arquivo removido',
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
          '$count arquivos removidos, mas $trouble. Tente novamente enquanto estiver online.',
      one:
          '1 arquivo removido, mas $trouble. Tente novamente enquanto estiver online.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_trouble_failed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count não puderam ser excluídos',
      one: '1 não pôde ser excluído',
    );
    return '$_temp0';
  }

  @override
  String get settings_syncMaintenance_trouble_listIncomplete =>
      'não foi possível listar alguns arquivos';

  @override
  String settings_syncMaintenance_wipedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos apagados',
      one: '1 arquivo apagado',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_wipedFilesPartial(int count, String trouble) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count arquivos apagados, mas $trouble. Tente novamente enquanto estiver online.',
      one:
          '1 arquivo apagado, mas $trouble. Tente novamente enquanto estiver online.',
    );
    return '$_temp0';
  }

  @override
  String get settings_troubleshootSync_appBar_title =>
      'Solucionar problemas de sincronização';

  @override
  String get settings_troubleshootSync_devices_subtitle =>
      'Veja todos os dispositivos que mantêm arquivos aqui, quanto espaço cada um usa, e remova os restos de bibliotecas das quais nenhum dispositivo sincroniza mais. Seus dados de mergulho não são afetados.';

  @override
  String get settings_troubleshootSync_rebuild_confirm => 'Reconstruir';

  @override
  String get settings_troubleshootSync_rebuild_confirmBody =>
      'Isto torna a biblioteca deste dispositivo a atual no provedor e a publica novamente, para que os outros dispositivos sincronizem a partir de você. Use quando uma substituição vinda de outro dispositivo estiver travada. Seus dados de mergulho não são afetados.';

  @override
  String get settings_troubleshootSync_rebuild_confirmTitle =>
      'Reconstruir o provedor a partir deste dispositivo?';

  @override
  String get settings_troubleshootSync_rebuild_doneSnack =>
      'Provedor reconstruído a partir deste dispositivo';

  @override
  String get settings_troubleshootSync_rebuild_failedSnack =>
      'Falha na reconstrução';

  @override
  String get settings_troubleshootSync_rebuild_progressTitle =>
      'Reconstruindo o provedor';

  @override
  String get settings_troubleshootSync_rebuild_subtitle =>
      'Use se a sincronização estiver travada esperando por uma biblioteca que outro dispositivo substituiu mas nunca terminou de enviar (esse dispositivo pode estar offline). Publica a biblioteca deste dispositivo como a atual.';

  @override
  String get settings_troubleshootSync_rebuild_title =>
      'Reconstruir o provedor a partir deste dispositivo';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmBody =>
      'Isto exclui do provedor apenas os arquivos de sincronização deste dispositivo. Os outros dispositivos continuam sincronizando, e seus dados de mergulho não são afetados.';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmTitle =>
      'Remover os arquivos na nuvem deste dispositivo?';

  @override
  String get settings_troubleshootSync_removeThisDevice_progressTitle =>
      'Removendo os arquivos na nuvem deste dispositivo';

  @override
  String get settings_troubleshootSync_removeThisDevice_subtitle =>
      'Libere o espaço deste dispositivo no provedor. Os outros dispositivos continuam sincronizando. Seus dados de mergulho não são afetados.';

  @override
  String get settings_troubleshootSync_removeThisDevice_title =>
      'Remover os arquivos na nuvem deste dispositivo';

  @override
  String get settings_troubleshootSync_repair_confirm => 'Reparar';

  @override
  String get settings_troubleshootSync_repair_confirmBody =>
      'Isto limpa todo o estado local de sincronização e dá a este dispositivo uma nova identidade de sincronização, reconectando do zero na próxima sincronização. Seus dados de mergulho estão seguros e não são excluídos.';

  @override
  String get settings_troubleshootSync_repair_confirmTitle =>
      'Reparar a sincronização?';

  @override
  String get settings_troubleshootSync_repair_doneSnack =>
      'Sincronização reparada';

  @override
  String get settings_troubleshootSync_repair_subtitle =>
      'Corrija uma sincronização travada. Limpa o estado de sincronização deste dispositivo e lhe dá uma nova identidade de sincronização, reconectando na próxima sincronização. Seus dados de mergulho não são afetados.';

  @override
  String get settings_troubleshootSync_repair_title => 'Reparar sincronização';

  @override
  String get settings_troubleshootSync_wipeAll_confirm => 'Apagar tudo';

  @override
  String settings_troubleshootSync_wipeAll_confirmBody(String word) {
    return 'Isto exclui os dados de sincronização de TODOS os dispositivos deste provedor, incluindo os marcadores de biblioteca. Todos os dispositivos terão que restabelecer a sincronização do zero. Seus dados de mergulho não são afetados.\n\nDigite exatamente $word para confirmar.';
  }

  @override
  String get settings_troubleshootSync_wipeAll_confirmTitle =>
      'Apagar todos os dados de sincronização?';

  @override
  String get settings_troubleshootSync_wipeAll_progressTitle =>
      'Apagando os dados de sincronização';

  @override
  String get settings_troubleshootSync_wipeAll_subtitle =>
      'Exclua os dados de sincronização de todos os dispositivos deste provedor, incluindo os marcadores de biblioteca. Todos os dispositivos restabelecem a sincronização do zero. Seus dados de mergulho não são afetados.';

  @override
  String get settings_troubleshootSync_wipeAll_title =>
      'Apagar todos os dados de sincronização neste provedor';

  @override
  String get tableMode_tooltip_toggleDetailPane =>
      'Alternar painel de detalhes';

  @override
  String get tableMode_tooltip_toggleProfilePanel =>
      'Alternar painel do perfil';

  @override
  String get maps_regionDownload_title => 'Baixar Região';

  @override
  String get maps_regionDownload_nameRequired =>
      'Insira um nome para esta região';

  @override
  String get maps_regionDownload_nameLabel => 'Nome da Região';

  @override
  String get maps_regionDownload_nameHint => 'ex.: Cozumel, México';

  @override
  String get maps_regionDownload_zoomLevels => 'Níveis de Zoom';

  @override
  String get maps_regionDownload_zoomHint =>
      'Zoom maior = mais detalhes, download maior';

  @override
  String maps_regionDownload_minZoom(int zoom) {
    return 'Mín: $zoom';
  }

  @override
  String maps_regionDownload_minZoomSemantics(int zoom) {
    return 'Zoom mínimo: $zoom';
  }

  @override
  String maps_regionDownload_maxZoom(int zoom) {
    return 'Máx: $zoom';
  }

  @override
  String maps_regionDownload_maxZoomSemantics(int zoom) {
    return 'Zoom máximo: $zoom';
  }

  @override
  String get maps_regionDownload_estimatingSemantics =>
      'Estimando o tamanho do download';

  @override
  String maps_regionDownload_estimateSemantics(int count, Object size) {
    return 'Download estimado: $count tiles, $size';
  }

  @override
  String get maps_regionDownload_estimateUnavailableSemantics =>
      'Não foi possível estimar o tamanho do download';

  @override
  String get maps_regionDownload_estimating => 'Estimando...';

  @override
  String maps_regionDownload_tileCount(int count) {
    return '~$count tiles';
  }

  @override
  String get maps_regionDownload_estimateUnavailable =>
      'Não foi possível estimar';

  @override
  String get maps_regionDownload_largeWarningSemantics =>
      'Aviso: download grande. Considere reduzir os níveis de zoom ou selecionar uma região menor.';

  @override
  String get maps_regionDownload_largeWarning =>
      'Download grande. Considere reduzir os níveis de zoom ou selecionar uma região menor.';

  @override
  String get maps_regionDownload_downloadButton => 'Baixar';

  @override
  String get diveLog_map_title => 'Atividade de Mergulho';

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
      'Miniatura de foto. Toque para ver em tela cheia';

  @override
  String get trips_gallery_thumbnail_video =>
      'Miniatura de vídeo. Toque para ver em tela cheia';

  @override
  String get trips_gallery_thumbnail_photoMissing =>
      'Miniatura de foto, ausente no dispositivo. Toque para ver em tela cheia';

  @override
  String get trips_gallery_thumbnail_videoMissing =>
      'Miniatura de vídeo, ausente no dispositivo. Toque para ver em tela cheia';

  @override
  String get trips_photos_thumbnail_photo =>
      'Miniatura de foto. Toque para abrir a galeria';

  @override
  String get trips_photos_thumbnail_video =>
      'Miniatura de vídeo. Toque para abrir a galeria';

  @override
  String trips_picker_suggestedSemantics(Object name) {
    return 'Viagem sugerida: $name. Toque para usar';
  }

  @override
  String trips_picker_tileSemantics(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, de $startDate a $endDate';
  }

  @override
  String trips_picker_tileSemanticsSelected(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, de $startDate a $endDate, selecionada';
  }

  @override
  String get divePlanner_quickPlan_subtitle =>
      'Crie um perfil de mergulho retangular simples';

  @override
  String get divePlanner_quickPlan_depthLabel => 'Profundidade:';

  @override
  String divePlanner_quickPlan_depthSemantics(Object depth) {
    return 'Profundidade: $depth';
  }

  @override
  String get divePlanner_quickPlan_timeLabel => 'Tempo:';

  @override
  String divePlanner_quickPlan_bottomTimeSemantics(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Tempo de fundo: $minutes minutos',
      one: 'Tempo de fundo: 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String divePlanner_quickPlan_minutes(int minutes) {
    return '$minutes min';
  }

  @override
  String divePlanner_quickPlan_previewSemantics(Object depth, int minutes) {
    return 'Prévia do plano: descida até $depth, tempo de fundo de $minutes minutos, subida com parada de segurança';
  }

  @override
  String get divePlanner_quickPlan_previewTitle => 'Prévia do Plano:';

  @override
  String divePlanner_quickPlan_previewDescent(Object depth) {
    return 'Descida até $depth';
  }

  @override
  String divePlanner_quickPlan_previewBottomTime(int minutes) {
    return 'Tempo de fundo: $minutes min';
  }

  @override
  String get divePlanner_quickPlan_previewAscent =>
      'Subida com parada de segurança';

  @override
  String get divePlanner_quickPlan_create => 'Criar';

  @override
  String divePlanner_semantics_sacRate(Object value, Object volumeSymbol) {
    return 'RMV: $value $volumeSymbol por minuto';
  }

  @override
  String divePlanner_semantics_reservePressure(Object pressureSymbol) {
    return 'Pressão de reserva em $pressureSymbol';
  }

  @override
  String divePlanner_semantics_altitudeGroup(Object group) {
    return 'Grupo de altitude: $group';
  }

  @override
  String diveSites_import_detail_maxDepth(Object depth) {
    return 'Máx $depth';
  }

  @override
  String get autoUpdate_banner_download => 'Baixar';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Sincronizar via Apple iCloud';

  @override
  String get settings_debugLog_search_hint => 'Buscar nos logs...';

  @override
  String get settings_debugLog_appBar_title => 'Logs de Depuração';

  @override
  String get settings_debugLog_disableDebugMode =>
      'Desativar Modo de Depuração';

  @override
  String get settings_debugLog_clearLogs => 'Limpar Logs';

  @override
  String get settings_debugLog_empty =>
      'Nenhuma entrada de log corresponde aos filtros atuais';

  @override
  String settings_debugLog_loadError(Object error) {
    return 'Erro ao carregar os logs: $error';
  }

  @override
  String get settings_debugLog_copiedSnack =>
      'Logs filtrados copiados para a área de transferência';

  @override
  String settings_debugLog_savedSnack(String path) {
    return 'Logs salvos em $path';
  }

  @override
  String get common_action_copy => 'Copiar';

  @override
  String get settings_appearance_customGradient_title =>
      'Gradiente Personalizado';

  @override
  String get settings_appearance_customGradient_start => 'Início';

  @override
  String get settings_appearance_customGradient_end => 'Fim';

  @override
  String get settings_appearance_customGradient_hue => 'Matiz';

  @override
  String get settings_appearance_customGradient_saturation => 'Saturação';

  @override
  String get settings_appearance_customGradient_brightness => 'Brilho';

  @override
  String get settings_appearance_customGradient_preview => 'Prévia';

  @override
  String get common_action_apply => 'Aplicar';

  @override
  String settings_cloudSync_message_loadStateFailed(Object error) {
    return 'Falha ao carregar o estado de sincronização: $error';
  }

  @override
  String get settings_cloudSync_message_noProviderConfigured =>
      'Nenhum provedor de nuvem configurado';

  @override
  String get settings_cloudSync_message_adopting =>
      'Adotando a biblioteca restaurada...';

  @override
  String get settings_cloudSync_message_adoptFailed =>
      'Falha ao adotar a biblioteca restaurada';

  @override
  String get settings_cloudSync_message_firstSyncNeedsConfirm =>
      'A primeira sincronização precisa de confirmação. Toque em Sincronizar Agora para revisar.';

  @override
  String get settings_cloudSync_message_startingSync =>
      'Iniciando sincronização...';

  @override
  String get settings_cloudSync_message_replacePaused =>
      'Sincronização pausada: a biblioteca foi substituída a partir de um backup. Toque em Sincronizar Agora para revisar.';

  @override
  String get settings_cloudSync_message_encryptedPaused =>
      'Sincronização pausada: esta biblioteca está criptografada. Digite a frase-senha para continuar.';

  @override
  String get settings_cloudSync_message_completedWithConflicts =>
      'Sincronização concluída com conflitos';

  @override
  String get settings_cloudSync_message_completedSuccessfully =>
      'Sincronização concluída com sucesso';

  @override
  String get settings_cloudSync_message_syncFailed => 'Falha na sincronização';

  @override
  String get settings_cloudSync_message_phaseDefault => 'sincronização';

  @override
  String settings_cloudSync_message_syncErrorDuring(
    String phase,
    Object error,
  ) {
    return 'Erro de sincronização durante $phase: $error';
  }

  @override
  String get settings_section_debug_title => 'Depuração';

  @override
  String get settings_section_debug_subtitle => 'Logs e diagnósticos';

  @override
  String get settings_debugLog_minSeverityLabel => 'Severidade mín.:';

  @override
  String get settings_debugLog_shareSubject =>
      'Logs de Depuração do Submersion';

  @override
  String get settings_debugLog_saveDialogTitle => 'Salvar Logs de Depuração';

  @override
  String get universalImport_preset_saveTitle => 'Salvar como Preset';

  @override
  String get universalImport_preset_nameLabel => 'Nome do Preset';

  @override
  String get universalImport_preset_nameHint =>
      'ex.: CSV do Meu Registro de Mergulho';

  @override
  String get universalImport_preset_nameRequired => 'O nome é obrigatório';

  @override
  String get universalImport_preset_sourceAppLabel => 'Aplicativo de Origem';

  @override
  String get universalImport_preset_sourceAppNone => 'Nenhum';

  @override
  String get universalImport_preset_entityTypesLabel => 'Tipos de Entidade';

  @override
  String get universalImport_preset_matchThresholdLabel =>
      'Limiar de Correspondência';

  @override
  String get universalImport_preset_matchThresholdHelp =>
      'Quão parecidos os cabeçalhos CSV devem ser para a detecção automática';

  @override
  String universalImport_preset_signatureHeaders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cabeçalhos de assinatura do arquivo atual',
      one: '1 cabeçalho de assinatura do arquivo atual',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_preset_selectTitle => 'Selecionar Preset';

  @override
  String universalImport_preset_loadFailed(String error) {
    return 'Falha ao carregar os presets: $error';
  }

  @override
  String get universalImport_preset_sectionSaved => 'Presets Salvos';

  @override
  String get universalImport_preset_sectionBuiltIn => 'Presets Integrados';

  @override
  String get universalImport_preset_deleteTitle => 'Excluir Preset';

  @override
  String universalImport_preset_deleteConfirm(String name) {
    return 'Excluir \"$name\"? Isso não pode ser desfeito.';
  }

  @override
  String universalImport_preset_headersMatched(
    int matched,
    int total,
    int percent,
  ) {
    return '$matched/$total cabeçalhos correspondentes ($percent%)';
  }

  @override
  String get universalImport_preset_noSignatureHeaders =>
      'Nenhum cabeçalho de assinatura';

  @override
  String get universalImport_preset_deleteTooltip => 'Excluir preset';

  @override
  String get universalImport_preset_presetsButton => 'Presets';

  @override
  String universalImport_preset_savedSnackbar(String name) {
    return 'Preset \"$name\" salvo';
  }

  @override
  String get universalImport_step_done => 'Concluído';

  @override
  String get universalImport_cancel_inProgressTitle => 'Cancelando';

  @override
  String get universalImport_cancel_inProgressBody =>
      'Finalizando o mergulho atual antes de parar. Os mergulhos já importados serão mantidos.';

  @override
  String get universalImport_cancel_confirmTitle => 'Cancelar importação?';

  @override
  String get universalImport_cancel_confirmBody =>
      'Parar depois que o mergulho atual terminar. Os mergulhos já importados serão mantidos.';

  @override
  String get universalImport_cancel_keepImporting => 'Continuar importando';

  @override
  String get universalImport_cancel_confirmAction => 'Cancelar importação';

  @override
  String get universalImport_cancel_discardSelections =>
      'Descartar seleções e cancelar?';

  @override
  String get universalImport_action_importSelected => 'Importar Selecionados';

  @override
  String get universalImport_action_next => 'Avançar';

  @override
  String get common_action_yes => 'Sim';

  @override
  String get common_action_no => 'Não';

  @override
  String universalImport_counts_new(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novos',
      one: '$count novo',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_merging(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesclando',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_replacing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count substituindo',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_skipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pulados',
      one: '$count pulado',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_counts_nothingSelected => 'Nada selecionado';

  @override
  String get universalImport_section_potentialDuplicates =>
      'Duplicatas Potenciais';

  @override
  String get universalImport_section_possibleDuplicates =>
      'Duplicatas Possíveis';

  @override
  String universalImport_count_duplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicatas',
      one: '1 duplicata',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_entityAction_importBadge => 'IMPORTAR';

  @override
  String get universalImport_entityAction_skipBadge => 'PULAR';

  @override
  String get universalImport_compare_existing => 'Existente';

  @override
  String get universalImport_compare_incoming => 'Recebido';

  @override
  String get universalImport_label_skipped => 'Pulado';

  @override
  String get universalImport_action_viewDives => 'Ver Mergulhos';

  @override
  String get diveImport_healthkit_accessGranted =>
      'Acesso ao HealthKit Concedido';

  @override
  String get diveImport_healthkit_accessGrantedBody =>
      'Você pode prosseguir para a próxima etapa.';

  @override
  String get diveImport_healthkit_requesting => 'Solicitando...';

  @override
  String get diveImport_healthkit_selectDateRange => 'Selecionar Período';

  @override
  String get diveImport_healthkit_selectDateRangeBody =>
      'Escolha o período para buscar mergulhos no Apple Health.';

  @override
  String get diveImport_healthkit_fetchingDives =>
      'Buscando mergulhos no Apple Health...';

  @override
  String get diveImport_healthkit_fetchFailed => 'Falha na Busca';

  @override
  String diveImport_healthkit_fetchFailedBody(String error) {
    return 'Falha ao buscar mergulhos: $error';
  }

  @override
  String diveImport_healthkit_foundDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mergulhos encontrados',
      one: '1 mergulho encontrado',
    );
    return '$_temp0';
  }

  @override
  String get diveImport_healthkit_proceedingToReview =>
      'Prosseguindo para a revisão...';

  @override
  String get importWizard_dc_knownComputer => 'Computador Conhecido';

  @override
  String importWizard_dc_knownComputerBody(String name) {
    return 'Salvo como \"$name\". Somente mergulhos novos serão baixados.';
  }

  @override
  String get importWizard_dc_noNewDives => 'Nenhum mergulho novo para baixar';

  @override
  String get importWizard_dc_noNewDivesBody =>
      'Todos os mergulhos deste computador já foram importados.';

  @override
  String get universalImport_compare_noDiveData =>
      'Dados do mergulho não disponíveis para comparação.';

  @override
  String get universalImport_entityAction_consolidateBadge => 'CONSOLIDAR';

  @override
  String get diveCenters_import_quickSearch_egypt => 'Egito';

  @override
  String get diveCenters_import_quickSearch_mexico => 'México';

  @override
  String get accessibility_shortcut_switchDiver => 'Trocar de mergulhador';

  @override
  String get lock_recoveryCode_title => 'Usar código de recuperação';

  @override
  String get lock_recoveryCode_body =>
      'Digite o código de recuperação de 8 palavras que você salvou ao definir a senha do app.';

  @override
  String get lock_recoveryCode_error => 'Código de recuperação incorreto.';

  @override
  String get lock_forcedReset_title => 'Defina uma nova senha';

  @override
  String get lock_forcedReset_body =>
      'Você desbloqueou com o código de recuperação, portanto sua senha antiga não é mais confiável. Escolha uma nova agora.';

  @override
  String get lock_forcedReset_submit => 'Definir senha';

  @override
  String get lock_forcedReset_error =>
      'Não foi possível definir a nova senha. Tente novamente.';

  @override
  String get lock_sidecarRepair_title =>
      'Reparar arquivo de chave de segurança';

  @override
  String get lock_sidecarRepair_body =>
      'Seu arquivo de chave de segurança estava faltando e o chaveiro deste dispositivo ainda contém a chave. Confirme sua senha para gravar um novo arquivo de chave. Observação: a senha que você digitar aqui passa a ser a senha do app daqui em diante, e você receberá um novo código de recuperação.';

  @override
  String get lock_sidecarRepair_submit => 'Reparar';

  @override
  String get lock_sidecarRepair_error => 'Falha no reparo. Tente novamente.';

  @override
  String get lock_newRecoveryCode_title => 'Seu novo código de recuperação';

  @override
  String get lock_startFresh_title => 'Abrir outro banco de dados';

  @override
  String lock_startFresh_body(Object token) {
    return 'Seu banco de dados atual permanece no disco, renomeado com o sufixo .locked; nada é excluído. Você pode recuperá-lo depois com sua senha ou entrando em contato com o suporte. A sincronização na nuvem será desativada para que o novo banco de dados não se misture com o antigo.\n\nO app começará com um banco de dados novo e vazio. Você pode restaurar a partir de um backup no assistente de configuração.\n\nDigite $token para confirmar.';
  }

  @override
  String get lock_startFresh_confirm => 'Deixar de lado e começar do zero';

  @override
  String get lock_biometric_reason => 'Desbloquear seu log de mergulhos';

  @override
  String startup_migrating_progress(Object currentStep, Object totalSteps) {
    return 'Atualizando o banco de dados... etapa $currentStep de $totalSteps';
  }

  @override
  String get startup_error_title => 'O Submersion não conseguiu iniciar';

  @override
  String get startup_error_body =>
      'Algo correu mal antes de o seu diário de mergulho acabar de abrir. Os seus dados continuam no disco e não é necessária uma reinstalação. Tente reiniciar a aplicação; se o problema persistir, contacte o suporte.';

  @override
  String get startup_engineUnavailable_title =>
      'Esta compilação não consegue abrir uma base de dados';

  @override
  String get startup_engineUnavailable_body =>
      'Falta o motor de base de dados do Submersion nesta compilação, por isso o seu diário de mergulho nunca chegou a ser aberto. Nada mudou no disco e nenhum dado está em risco.';

  @override
  String get startup_engineUnavailable_guidance =>
      'Reinstalar ou restaurar uma cópia de segurança não vai ajudar. Instale uma compilação funcional do Submersion e comunique-nos isto: é uma falha no pacote da aplicação, não nos seus dados.';

  @override
  String get startup_migrationFailed_title =>
      'Falha na atualização da base de dados';

  @override
  String get startup_migrationFailed_body =>
      'Não foi possível atualizar o seu diário de mergulho para o formato de que esta versão precisa. Foi criada uma cópia de segurança antes de a atualização começar, por isso nada se perdeu.';

  @override
  String get startup_dataUnreadable_title =>
      'Não foi possível ler o seu diário de mergulho';

  @override
  String get startup_dataUnreadable_body =>
      'O ficheiro da base de dados está lá, mas o Submersion não consegue lê-lo. Normalmente isto significa que o ficheiro está danificado. Restaurar uma cópia de segurança é a forma mais rápida de recomeçar.';

  @override
  String get startup_databaseBusy_title =>
      'O seu diário de mergulho estava ocupado';

  @override
  String get startup_databaseBusy_body =>
      'Algo ainda estava a usar o ficheiro da base de dados, por isso o Submersion parou em vez de escrever nele. Nada foi alterado e nada está danificado. Feche o Submersion por completo e volte a abri-lo.';

  @override
  String get startup_failure_technicalDetails => 'Detalhes técnicos';

  @override
  String get startup_failure_backupAvailable_title =>
      'Está disponível uma cópia de segurança';

  @override
  String startup_failure_backupAvailable_taken(Object timestamp) {
    return 'Criada a $timestamp';
  }

  @override
  String startup_failure_backupAvailable_preMigration(
    Object fromVersion,
    Object toVersion,
  ) {
    return 'Cópia de segurança criada antes da atualização do esquema v$fromVersion para v$toVersion.';
  }

  @override
  String get startup_failure_restoreAction =>
      'Restaurar esta cópia de segurança';

  @override
  String get startup_failure_restoring =>
      'A restaurar o seu diário de mergulho...';

  @override
  String get startup_failure_restoreFailed =>
      'Não foi possível restaurar a cópia de segurança. O seu diário de mergulho ficou exatamente como estava.';

  @override
  String get startup_failure_backupsFolder =>
      'As suas cópias de segurança estão em:';

  @override
  String get startup_failure_showBackupsFolder => 'Mostrar pasta das cópias';

  @override
  String get startup_failure_downgrade_title => 'Voltar à versão anterior';

  @override
  String get startup_failure_downgrade_body =>
      'Se a atualização continuar a falhar, instale a versão do Submersion que usava antes e restaure a cópia de segurança a partir dessa versão. Restaurá-la aqui apenas voltaria a executar a mesma atualização. O Submersion nunca regride sozinho: passá-lo automaticamente para compilações antigas mantê-lo-ia em silêncio em versões com problemas conhecidos.';

  @override
  String get startup_failure_downgrade_action => 'Ver versões anteriores';

  @override
  String get startup_recovering_title => 'Recuperando o banco de dados...';

  @override
  String get startup_recovering_body =>
      'Revertendo a transação interrompida. Isso normalmente leva alguns segundos.';

  @override
  String get startup_recoveryFailed_title => 'A recuperação não foi concluída';

  @override
  String get startup_recoveryFailed_body =>
      'Não foi possível reverter o banco de dados automaticamente. Seus dados continuam no disco; entre em contato com o suporte antes de reinstalar para que possamos ajudar a recuperá-los.';

  @override
  String get startup_recoveryRequired_title =>
      'O banco de dados precisa de recuperação';

  @override
  String get startup_recoveryRequired_body =>
      'Uma sessão anterior foi interrompida enquanto gravava no banco de dados. Seus dados continuam no disco; só precisamos terminar de reverter a alteração cancelada antes que o app possa abrir.';

  @override
  String startup_recovery_sqliteCode(Object code) {
    return 'Código SQLite $code';
  }

  @override
  String get startup_recovery_action => 'Recuperar banco de dados';

  @override
  String get startup_recovery_closeWithoutRecovering => 'Fechar sem recuperar';

  @override
  String get common_action_tryAgain => 'Tentar novamente';

  @override
  String get lock_screen_title => 'O Submersion está bloqueado';

  @override
  String get lock_screen_forgotPassword => 'Esqueceu a senha?';

  @override
  String get lock_incorrectPassword => 'Senha incorreta. Tente novamente.';

  @override
  String get startup_backup_semanticsLabel => 'Fazendo backup';

  @override
  String get startup_backup_title => 'Fazendo backup dos seus dados';

  @override
  String get startup_backup_body =>
      'Estamos salvando uma cópia do seu log de mergulhos antes de atualizar seu banco de dados.';

  @override
  String get startup_backupFailed_title =>
      'Não foi possível fazer backup dos seus dados';

  @override
  String get startup_backupFailed_body =>
      'Seu log de mergulhos não foi alterado; não o atualizamos. Libere espaço (ou resolva o problema) e tente novamente.';

  @override
  String get startup_backupFailed_quit => 'Sair';

  @override
  String get startup_backupFailed_technicalDetails => 'Detalhes técnicos';

  @override
  String get common_action_retry => 'Tentar novamente';

  @override
  String get startup_versionMismatch_title => 'Atualização necessária';

  @override
  String startup_versionMismatch_body(
    Object databaseVersion,
    Object appVersion,
  ) {
    return 'Seus dados de mergulho foram salvos por uma versão mais recente do Submersion (esquema v$databaseVersion). Esta versão suporta apenas até o esquema v$appVersion.';
  }

  @override
  String get startup_versionMismatch_instructions =>
      'Atualize o Submersion para a versão mais recente. Seus dados estão seguros e não foram modificados. Se um backup foi feito antes da atualização, ele está na sua pasta Backups e pode ser restaurado após a atualização.';

  @override
  String get startup_versionMismatch_storeInstructions =>
      'Esta app foi instalada a partir de uma loja de aplicações e é mais antiga do que a versão que criou os seus dados. Os seus dados estão seguros e não foram modificados. Atualize o Submersion quando a nova versão aparecer na loja e volte a abri-lo.';

  @override
  String get startup_versionMismatch_download => 'Baixar versão mais recente';

  @override
  String get startup_versionMismatch_manualLink =>
      'Se isso não abrir um navegador, acesse:';

  @override
  String get universalImport_compare_downloaded => 'Baixado';

  @override
  String get universalImport_compare_errorLoading =>
      'Erro ao carregar os dados do mergulho';

  @override
  String get universalImport_compare_diveNotFound =>
      'Mergulho existente não encontrado';

  @override
  String universalImport_compare_sameFields(Object fields) {
    return 'Iguais: $fields';
  }

  @override
  String get universalImport_compare_differences => 'DIFERENÇAS';

  @override
  String get universalImport_compare_notRecorded => 'não registrado';

  @override
  String universalImport_compare_serial(Object serial) {
    return 'S/N: $serial';
  }

  @override
  String get universalImport_compare_skipSubtitle => 'Descartar este download';

  @override
  String get universalImport_compare_importAsNewSubtitle =>
      'Salvar como mergulho separado';

  @override
  String get universalImport_compare_consolidateSubtitle =>
      'Adicionar como leitura do 2º computador';

  @override
  String get diveLog_tooltip_ndlOverMax => '>60 min';

  @override
  String diveLog_tooltip_interpolated(String value) {
    return '$value (interpolado)';
  }

  @override
  String get enum_profileMetric_ascentRate_short => 'Taxa';

  @override
  String get enum_profileMetric_cns_short => 'CNS';

  @override
  String get enum_profileMetric_otu_short => 'OTU';

  @override
  String get diveLog_profileEditor_rangeOperations => 'Operações de intervalo';

  @override
  String get diveLog_profileEditor_selectRangeHint =>
      'Selecione um intervalo no gráfico para habilitar as operações';

  @override
  String get diveLog_profileEditor_depthPlusOneMeter => 'Profundidade +1m';

  @override
  String get diveLog_profileEditor_depthMinusOneMeter => 'Profundidade -1m';

  @override
  String get diveLog_profileEditor_timePlusFiveSeconds => 'Tempo +5s';

  @override
  String get diveLog_profileEditor_timeMinusFiveSeconds => 'Tempo -5s';

  @override
  String get diveLog_profileEditor_smoothing => 'Suavização';

  @override
  String get diveLog_profileEditor_smoothLight => 'Leve';

  @override
  String get diveLog_profileEditor_smoothMedium => 'Média';

  @override
  String get diveLog_profileEditor_smoothHeavy => 'Forte';

  @override
  String get diveLog_profileEditor_applyToAll => 'Aplicar a tudo';

  @override
  String get diveLog_profileEditor_applyToSelection => 'Aplicar à seleção';

  @override
  String get diveLog_profileEditor_outlierDetection => 'Detecção de anomalias';

  @override
  String get diveLog_profileEditor_detect => 'Detectar';

  @override
  String get diveLog_profileEditor_removeAll => 'Remover todas';

  @override
  String diveLog_profileEditor_outliersDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count possíveis anomalias detectadas',
      one: '$count possível anomalia detectada',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_profileEditor_manualDrawing => 'Desenho manual';

  @override
  String get diveLog_profileEditor_drawHint =>
      'Toque no gráfico para posicionar os pontos';

  @override
  String get diveLog_profileEditor_clearWaypoints => 'Limpar';

  @override
  String get diveLog_profileEditor_generateProfile => 'Gerar perfil';

  @override
  String get diveLog_profileEditor_trimMode => 'Modo de corte';

  @override
  String get diveLog_profileEditor_trimHint =>
      'Cortar as extremidades do perfil';

  @override
  String get diveLog_profileEditor_trimEnd => 'Cortar o fim';

  @override
  String get diveLog_profileEditor_mode_smooth => 'Suavizar';

  @override
  String get diveLog_profileEditor_title => 'Editar perfil';

  @override
  String get diveLog_profileEditor_discardBody =>
      'Você tem alterações não salvas neste perfil de mergulho. Tem certeza de que deseja descartá-las?';

  @override
  String get diveLog_profileEditor_saveTitle => 'Salvar perfil?';

  @override
  String get diveLog_profileEditor_saveBody =>
      'Isso salvará o perfil editado como o perfil principal deste mergulho. O perfil original será preservado e poderá ser restaurado depois.';

  @override
  String diveLog_profileEditor_saveFailed(String error) {
    return 'Falha ao salvar o perfil: $error';
  }

  @override
  String diveLog_profileEditor_errorLoadingDive(String error) {
    return 'Erro ao carregar o mergulho: $error';
  }

  @override
  String get diveLog_profileEditor_noProfileData =>
      'Nenhum dado de perfil disponível';

  @override
  String get diveLog_profileEditor_undo => 'Desfazer';

  @override
  String get diveLog_profileEditor_mode_select => 'Selecionar';

  @override
  String get diveLog_profileEditor_mode_outlier => 'Anomalia';

  @override
  String get diveLog_profileEditor_mode_draw => 'Desenhar';

  @override
  String get diveLog_profileEditor_mode_trim => 'Cortar';

  @override
  String diveLog_sources_sectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fontes de Dados',
      one: 'Fonte de Dados',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_badge_manual => 'Manual';

  @override
  String get diveLog_sources_badge_viewing => 'Visualizando';

  @override
  String get diveLog_sources_badge_secondary => 'Secundária';

  @override
  String diveLog_sources_created(String date) {
    return 'Criado em $date';
  }

  @override
  String get diveLog_sources_detail_serial => 'Número de série';

  @override
  String get diveLog_sources_detail_format => 'Formato';

  @override
  String get diveLog_sources_detail_imported => 'Importado';

  @override
  String diveLog_detail_semantics_viewDiveComputer(String name) {
    return 'Ver computador de mergulho $name';
  }

  @override
  String diveLog_detail_semantics_viewTrip(String name) {
    return 'Ver viagem $name';
  }

  @override
  String diveLog_detail_semantics_viewDiveCenter(String name) {
    return 'Ver operadora de mergulho $name';
  }

  @override
  String diveLog_detail_semantics_viewSpecies(String name) {
    return 'Ver espécie $name';
  }

  @override
  String diveLog_detail_semantics_viewCourse(String name) {
    return 'Ver curso $name';
  }

  @override
  String diveLog_detail_serialNumber(String serial) {
    return 'S/N $serial';
  }

  @override
  String diveLog_detail_errorLoadingSignature(String error) {
    return 'Erro ao carregar a assinatura: $error';
  }

  @override
  String get diveLog_profilePanel_selectDive =>
      'Selecione um mergulho para ver seu perfil';

  @override
  String get diveLog_profilePanel_noProfileData =>
      'Sem dados de perfil para este mergulho';

  @override
  String get settings_export_progress_divesCsv =>
      'Exportando mergulhos para CSV...';

  @override
  String get settings_export_progress_sitesCsv =>
      'Exportando pontos para CSV...';

  @override
  String get settings_export_progress_equipmentCsv =>
      'Exportando equipamentos para CSV...';

  @override
  String get settings_export_progress_pdf =>
      'Gerando diário de mergulho em PDF...';

  @override
  String get settings_export_progress_loadingSignatures =>
      'Carregando assinaturas...';

  @override
  String get settings_export_progress_loadingCertifications =>
      'Carregando certificações...';

  @override
  String get settings_export_progress_loadingFonts => 'Carregando fontes...';

  @override
  String settings_export_progress_templatePdf(String template) {
    return 'Gerando PDF $template...';
  }

  @override
  String get settings_export_progress_uddf => 'Gerando arquivo UDDF...';

  @override
  String get settings_export_progress_collectingData =>
      'Coletando todos os dados...';

  @override
  String get settings_export_progress_excel => 'Gerando arquivo Excel...';

  @override
  String get settings_export_progress_buildingExcel =>
      'Montando a pasta de trabalho do Excel...';

  @override
  String get settings_export_progress_kml => 'Gerando arquivo KML...';

  @override
  String get settings_export_progress_buildingKml =>
      'Montando o arquivo KML...';

  @override
  String get settings_export_progress_preparingExcel =>
      'Preparando arquivo Excel...';

  @override
  String get settings_export_progress_preparingKml =>
      'Preparando arquivo KML...';

  @override
  String get settings_export_progress_chooseLocation =>
      'Escolha o local para salvar...';

  @override
  String get settings_export_progress_preparingDivesCsv =>
      'Preparando CSV de mergulhos...';

  @override
  String get settings_export_progress_preparingSitesCsv =>
      'Preparando CSV de pontos...';

  @override
  String get settings_export_progress_preparingEquipmentCsv =>
      'Preparando CSV de equipamentos...';

  @override
  String get settings_export_progress_preparingUddf =>
      'Preparando arquivo UDDF...';

  @override
  String get settings_export_progress_preparingPdf => 'Preparando PDF...';

  @override
  String get settings_export_progress_selectingBackup =>
      'Selecionando arquivo de backup...';

  @override
  String get settings_export_progress_restoringBackup =>
      'Restaurando a partir do backup...';

  @override
  String get settings_export_empty_dives => 'Nenhum mergulho para exportar';

  @override
  String get settings_export_empty_sites => 'Nenhum ponto para exportar';

  @override
  String get settings_export_empty_equipment =>
      'Nenhum equipamento para exportar';

  @override
  String get settings_export_empty_data => 'Nenhum dado para exportar';

  @override
  String get settings_export_empty_diveSites =>
      'Nenhum ponto de mergulho para exportar';

  @override
  String settings_export_saveFailed(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String settings_export_backupFailed(String error) {
    return 'Falha no backup: $error';
  }

  @override
  String settings_export_restoreFailed(String error) {
    return 'Falha na restauração: $error';
  }

  @override
  String get settings_export_fileUnreadable =>
      'Não foi possível acessar o arquivo';

  @override
  String get settings_export_notADbFile => 'Selecione um arquivo de backup .db';

  @override
  String get settings_export_success_dives =>
      'Mergulhos exportados com sucesso';

  @override
  String get settings_export_success_sites => 'Pontos exportados com sucesso';

  @override
  String get settings_export_success_equipment =>
      'Equipamentos exportados com sucesso';

  @override
  String get settings_export_success_pdf =>
      'Diário de mergulho em PDF gerado com sucesso';

  @override
  String get settings_export_success_uddf => 'Arquivo UDDF gerado com sucesso';

  @override
  String get settings_export_success_excel =>
      'Arquivo Excel exportado com sucesso';

  @override
  String settings_export_success_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Arquivo KML exportado com sucesso ($count pontos sem coordenadas ignorados)',
      one:
          'Arquivo KML exportado com sucesso (1 ponto sem coordenadas ignorado)',
      zero: 'Arquivo KML exportado com sucesso',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_excel => 'Arquivo Excel salvo com sucesso';

  @override
  String settings_export_saved_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Arquivo KML salvo com sucesso ($count pontos sem coordenadas ignorados)',
      one: 'Arquivo KML salvo com sucesso (1 ponto sem coordenadas ignorado)',
      zero: 'Arquivo KML salvo com sucesso',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_divesCsv =>
      'CSV de mergulhos salvo com sucesso';

  @override
  String get settings_export_saved_sitesCsv =>
      'CSV de pontos salvo com sucesso';

  @override
  String get settings_export_saved_equipmentCsv =>
      'CSV de equipamentos salvo com sucesso';

  @override
  String get settings_export_saved_uddf => 'Arquivo UDDF salvo com sucesso';

  @override
  String get settings_export_saved_pdf => 'PDF salvo com sucesso';

  @override
  String get settings_export_saved_backup => 'Backup salvo com sucesso';

  @override
  String get settings_export_restoreComplete => 'Restauração concluída';

  @override
  String get settings_export_cancelled_save => 'Salvamento cancelado';

  @override
  String get settings_export_cancelled_backup => 'Backup cancelado';

  @override
  String get settings_export_cancelled_restore => 'Restauração cancelada';

  @override
  String get settings_export_pdfDocumentTitle => 'Diário de Mergulho';

  @override
  String get settings_export_saveBackupDialogTitle => 'Salvar Backup';

  @override
  String backup_operation_created(String size) {
    return 'Backup criado: $size';
  }

  @override
  String backup_operation_backupFailed(String error) {
    return 'Falha no backup: $error';
  }

  @override
  String get backup_operation_restoring => 'Restaurando backup...';

  @override
  String backup_operation_restoreFailed(String error) {
    return 'Falha na restauração: $error';
  }

  @override
  String get backup_operation_deleting => 'Excluindo backup...';

  @override
  String get backup_operation_deleted => 'Backup excluído';

  @override
  String backup_operation_deleteFailed(String error) {
    return 'Falha ao excluir: $error';
  }

  @override
  String get backup_operation_exporting => 'Exportando backup...';

  @override
  String backup_operation_exported(String size) {
    return 'Backup exportado: $size';
  }

  @override
  String backup_operation_exportFailed(String error) {
    return 'Falha na exportação: $error';
  }

  @override
  String get backup_operation_preparingShare =>
      'Preparando o backup para compartilhamento...';

  @override
  String get backup_operation_shareReady => 'Backup pronto para compartilhar';

  @override
  String backup_operation_upgrading(int step, int total) {
    return 'Atualizando o banco de dados (etapa $step de $total)...';
  }

  @override
  String backup_restore_dialog_counts(int diveCount, int siteCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount mergulhos',
      one: '1 mergulho',
    );
    String _temp1 = intl.Intl.pluralLogic(
      siteCount,
      locale: localeName,
      other: '$siteCount pontos',
      one: '1 ponto',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get backup_restore_preMigration_title =>
      'Restaurar backup pré-migração';

  @override
  String get backup_restore_preMigration_unknownVersion =>
      'versão desconhecida';

  @override
  String get backup_restore_preMigration_restoreAnyway =>
      'Restaurar mesmo assim';

  @override
  String backup_restore_preMigration_incompleteMetadata(
    String timestamp,
    String appVersion,
  ) {
    return 'Este backup foi feito em $timestamp pelo app $appVersion, mas os metadados de migração do banco de dados dele estão incompletos.\n\nO app não consegue verificar se restaurar este backup é seguro, portanto a restauração está desativada.';
  }

  @override
  String backup_restore_preMigration_newerApp(
    String timestamp,
    String appVersion,
    int fromVersion,
  ) {
    return 'Este backup é mais recente que o seu app. Instale uma versão mais nova do app para restaurá-lo.\n\nBackup feito em $timestamp pelo app $appVersion (banco de dados v$fromVersion).';
  }

  @override
  String backup_restore_preMigration_safe(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
  ) {
    return 'Este backup foi feito em $timestamp pelo app $appVersion, logo antes de atualizar o banco de dados da v$fromVersion para a v$toVersion.\n\nO esquema do banco de dados do seu app corresponde a este backup, portanto a restauração é segura.';
  }

  @override
  String backup_restore_preMigration_warning(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
    int currentVersion,
  ) {
    return 'Este backup foi feito em $timestamp pelo app $appVersion, logo antes de atualizar o banco de dados da v$fromVersion para a v$toVersion.\n\nVocê está usando um app mais recente (banco de dados v$currentVersion).\n\nRestaurar agora executará de novo a atualização de banco de dados v$fromVersion → v$toVersion sobre os dados restaurados: exatamente a mesma atualização que estava prestes a ser executada originalmente. Se foi essa atualização que causou o problema, você terá o mesmo problema outra vez.\n\nPara restaurar com segurança: instale o app $appVersion ou anterior e restaure este backup a partir desse app mais antigo.';
  }

  @override
  String get settings_cloudSync_progress_preparing =>
      'Preparando a sincronização...';

  @override
  String get settings_cloudSync_progress_pulling => 'Baixando alterações...';

  @override
  String get settings_cloudSync_progress_publishing =>
      'Publicando alterações...';

  @override
  String settings_cloudSync_progress_uploadingLibrary(int uploaded, int total) {
    return 'Enviando a biblioteca ($uploaded de $total)';
  }

  @override
  String get settings_cloudSync_result_noProvider =>
      'Nenhum provedor de nuvem configurado';

  @override
  String get settings_cloudSync_result_notAuthenticated =>
      'Sem autenticação no provedor de nuvem';

  @override
  String get settings_cloudSync_result_timedOut =>
      'Tempo esgotado na sincronização';

  @override
  String get settings_cloudSync_result_epochMarkerUnreadable =>
      'Não foi possível ler o marcador de época da biblioteca';

  @override
  String get settings_cloudSync_result_epochMarkerEncrypted =>
      'O marcador de época da biblioteca está criptografado';

  @override
  String get settings_cloudSync_result_libraryReplacedRemotely =>
      'A biblioteca na nuvem foi substituída a partir de um backup';

  @override
  String get settings_cloudSync_result_noReplacementToRebuild =>
      'Nenhuma substituição de biblioteca a partir da qual reconstruir';

  @override
  String get settings_cloudSync_result_rebuiltFromThisDevice =>
      'Este provedor foi reconstruído a partir da biblioteca deste dispositivo';

  @override
  String settings_cloudSync_result_rebuildFailed(String error) {
    return 'Falha na reconstrução: $error';
  }

  @override
  String get settings_cloudSync_result_libraryReplaced =>
      'Biblioteca substituída';

  @override
  String settings_cloudSync_result_libraryReplaceFailed(String error) {
    return 'Falha ao substituir a biblioteca: $error';
  }

  @override
  String get settings_cloudSync_result_noReplacementMarker =>
      'Nenhum marcador de substituição de biblioteca encontrado';

  @override
  String get settings_cloudSync_result_adoptedRestoredLibrary =>
      'Biblioteca restaurada adotada';

  @override
  String settings_cloudSync_result_adoptFailed(String error) {
    return 'Falha ao adotar a biblioteca restaurada: $error';
  }

  @override
  String get settings_cloudSync_result_previousLibraryUnreadable =>
      'Não foi possível ler a biblioteca anterior; este provedor foi restabelecido a partir da biblioteca deste dispositivo.';

  @override
  String get settings_cloudSync_result_replacementStillUploading =>
      'A biblioteca substituída ainda está sendo enviada. Tente novamente em instantes.';

  @override
  String settings_cloudSync_result_recordsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count registros não puderam ser aplicados',
      one: '1 registro não pôde ser aplicado',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_result_adoptedFreshIdentity =>
      'Outro dispositivo estava sincronizando com a identidade deste dispositivo. Este dispositivo adotou uma nova identidade e mesclou os dados da nuvem.';

  @override
  String settings_cloudSync_launchCheck_unavailable(String provider) {
    return '$provider não está disponível neste dispositivo';
  }

  @override
  String settings_cloudSync_launchCheck_notSignedIn(String provider) {
    return 'Sem login em $provider';
  }

  @override
  String settings_cloudSync_launchCheck_localChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alterações locais para enviar',
      one: '1 alteração local para enviar',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_launchCheck_noRemoteData =>
      'Nenhum dado de sincronização encontrado na nuvem';

  @override
  String get settings_cloudSync_launchCheck_cloudDataAvailable =>
      'Dados da nuvem disponíveis';

  @override
  String get settings_cloudSync_launchCheck_updatesAvailable =>
      'Atualizações disponíveis na nuvem';

  @override
  String get settings_cloudSync_launchCheck_upToDate => 'Tudo está atualizado';

  @override
  String settings_cloudSync_launchCheck_failed(String error) {
    return 'Falha na verificação de sincronização: $error';
  }

  @override
  String get diveLog_detail_viewMap => 'Mapa';

  @override
  String get diveLog_detail_view3d => '3D';

  @override
  String get setup_sync_icloudUnavailable =>
      'O iCloud não está disponível neste dispositivo';

  @override
  String get media_info_title => 'Informações da mídia';

  @override
  String get media_info_fileSection => 'Arquivo';

  @override
  String get media_info_filename => 'Nome do arquivo';

  @override
  String get media_info_type => 'Tipo';

  @override
  String get media_info_dimensions => 'Dimensões';

  @override
  String get media_info_size => 'Tamanho';

  @override
  String get media_info_taken => 'Capturada';

  @override
  String get media_info_coordinates => 'Coordenadas';

  @override
  String get media_info_unknown => 'Desconhecido';

  @override
  String get media_info_originSection => 'Origem';

  @override
  String get media_info_source => 'Fonte';

  @override
  String get media_info_reference => 'Referência';

  @override
  String get media_info_linkedOn => 'Vinculada em';

  @override
  String get media_info_thisDevice => 'Este dispositivo';

  @override
  String get media_info_otherDevice => 'Outro dispositivo';

  @override
  String get media_info_status => 'Estado';

  @override
  String get media_info_statusFound => 'Encontrada neste dispositivo';

  @override
  String get media_info_statusMissing => 'Ausente neste dispositivo';

  @override
  String get media_info_statusUnchecked => 'Ainda não verificada';

  @override
  String media_info_lastChecked(String date) {
    return 'Última verificação $date';
  }

  @override
  String get media_timeInDive_label => 'Momento do mergulho';

  @override
  String get media_timeInDive_unknown => 'Momento do mergulho desconhecido';

  @override
  String get media_timeInDive_setAction => 'Definir momento do mergulho';

  @override
  String media_timeInDive_manual(String time) {
    return '$time (definido manualmente)';
  }

  @override
  String get media_timeInDive_fieldLabel => 'Tempo desde o início do mergulho';

  @override
  String get media_timeInDive_fieldHint => 'mm:ss';

  @override
  String media_timeInDive_range(String max) {
    return 'Entre 0:00 e $max';
  }

  @override
  String media_timeInDive_invalid(String max) {
    return 'Insira um tempo entre 0:00 e $max';
  }

  @override
  String get media_timeInDive_save => 'Salvar';

  @override
  String get media_timeInDive_cancel => 'Cancelar';

  @override
  String get media_timeInDive_reset => 'Redefinir para automático';

  @override
  String get media_info_backupSection => 'Backup';

  @override
  String get media_info_store => 'Armazenamento na nuvem';

  @override
  String get media_info_storeNotConnected =>
      'Nenhum armazenamento na nuvem conectado';

  @override
  String get media_info_notEligible => 'Esta fonte não pode ser copiada';

  @override
  String get media_info_backupFull => 'Original enviado';

  @override
  String get media_info_backupThumbOnly =>
      'Apenas miniatura, original não enviado';

  @override
  String get media_info_backupRenditionOnly => 'Versão comprimida enviada';

  @override
  String get media_info_backupNone => 'Sem backup';

  @override
  String media_info_uploadedOn(String date) {
    return 'Enviada $date';
  }

  @override
  String get media_info_queuePending => 'Aguardando envio';

  @override
  String get media_info_queueTransferring => 'Enviando agora';

  @override
  String media_info_queueFailed(Object error) {
    return 'Falha no envio: $error';
  }

  @override
  String get media_info_servingSection => 'Servindo agora';

  @override
  String get media_info_servingUnobserved => 'Ainda não carregada';

  @override
  String get media_info_servingFailed => 'Não foi possível carregar';

  @override
  String get media_info_servedLocalDisk => 'Arquivo local neste dispositivo';

  @override
  String get media_info_servedGallery => 'Biblioteca de fotos';

  @override
  String get media_info_servedStoreCache =>
      'Cache local, do armazenamento na nuvem';

  @override
  String get media_info_servedStoreNetwork =>
      'Baixada do armazenamento na nuvem';

  @override
  String get media_info_servedNetworkUrl => 'Transmitindo de uma URL';

  @override
  String get media_info_servedConnectorCache =>
      'Cache local, do serviço conectado';

  @override
  String get media_info_servedConnectorNetwork =>
      'Baixada do serviço conectado';

  @override
  String get media_info_servedEmbedded => 'Armazenada neste diário';

  @override
  String get media_info_servingFallbackNote =>
      'A fonte original não pôde ser acessada, então o armazenamento na nuvem forneceu isto.';

  @override
  String get media_info_servingTierThumbnail => 'Miniatura';

  @override
  String get media_info_servingTierRendition => 'Versão comprimida';

  @override
  String get media_info_typePhoto => 'Foto';

  @override
  String get media_info_typeVideo => 'Vídeo';

  @override
  String get media_info_typeDocument => 'Documento';

  @override
  String get media_info_typeSignature => 'Assinatura';

  @override
  String get media_info_actionCheckNow => 'Verificar agora';

  @override
  String get media_info_actionLocate => 'Localizar arquivo...';

  @override
  String get media_info_actionBackUpNow => 'Fazer backup agora';

  @override
  String get media_info_actionRetryUpload => 'Tentar envio novamente';

  @override
  String get media_info_actionReveal => 'Mostrar no gerenciador de arquivos';

  @override
  String get media_info_actionCopyPath => 'Copiar referência';

  @override
  String get media_info_referenceCopied => 'Referência copiada';

  @override
  String get media_info_checkFound => 'Fonte encontrada';

  @override
  String get media_info_checkMissing => 'A fonte está ausente';

  @override
  String get media_info_checkUnavailable => 'Não foi possível verificar agora';

  @override
  String get media_info_backupQueued => 'Na fila para envio';

  @override
  String get enum_profileMetric_o2CellMv => 'Células O2';

  @override
  String get enum_profileMetric_o2CellMv_short => 'Células';

  @override
  String get diveLog_o2CellSpread_label => 'Dispersão das células O2';

  @override
  String get media_status_broken => 'Ausente e sem backup';

  @override
  String get media_servedFrom_localDisk => 'Neste dispositivo';

  @override
  String get media_servedFrom_platformGallery => 'Biblioteca de fotos';

  @override
  String get media_servedFrom_storeCache =>
      'Armazenamento na nuvem, em cache aqui';

  @override
  String get media_servedFrom_storeNetwork => 'Armazenamento na nuvem';

  @override
  String get media_servedFrom_networkUrl => 'Link da web';

  @override
  String get media_servedFrom_connectorCache =>
      'Serviço conectado, em cache aqui';

  @override
  String get media_servedFrom_connectorNetwork => 'Serviço conectado';

  @override
  String get media_servedFrom_embedded => 'Salvo neste diário';

  @override
  String get settings_media_provenanceBadges =>
      'Mostrar selos de origem nas miniaturas';

  @override
  String get settings_media_provenanceBadgesSubtitle =>
      'Um pequeno ícone que mostra de onde cada item vem. Os selos de problema sempre aparecem.';

  @override
  String get media_status_transferFailed => 'Falha no envio';

  @override
  String get media_status_transferring => 'Enviando';

  @override
  String get media_status_queued => 'Aguardando envio';

  @override
  String get media_status_cloudOnly => 'Armazenado apenas na nuvem';

  @override
  String get media_status_notBackedUp => 'Sem backup';

  @override
  String get media_tile_infoMenuItem => 'Informações da mídia';

  @override
  String get diveImport_healthkit_accessGrantedHint =>
      'O Apple Saúde nunca informa às apps se o acesso de leitura foi concedido. Se nenhum mergulho aparecer, abra Saúde, depois Partilha, Apps, Submersion, e ative Treinos, Profundidade subaquática, Temperatura da água e Frequência cardíaca.';

  @override
  String get diveImport_healthkit_foundNoDivesHint =>
      'Sem treinos de mergulho neste intervalo. Confirme que as datas cobrem o mergulho e que em Saúde, Partilha, Apps, Submersion estão ativos Treinos e Profundidade subaquática.';

  @override
  String get settings_dataSources_appleHealth_dataTypeDepth =>
      'Profundidade subaquática - amostras de profundidade registadas durante os mergulhos';

  @override
  String get settings_dataSources_appleHealth_dataTypeWaterTemp =>
      'Temperatura da água - amostras de temperatura registadas durante os mergulhos';

  @override
  String get settings_dataSources_appleHealth_permissionManagedInHealth =>
      'O acesso ao HealthKit é gerido na app Saúde';

  @override
  String get settings_dataSources_appleHealth_permissionUnsupported =>
      'O HealthKit não está disponível neste dispositivo';
}
