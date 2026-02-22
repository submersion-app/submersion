// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

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
  String get backup_restore_dialog_cancel => 'Cancelar';

  @override
  String get backup_restore_dialog_restore => 'Restaurar';

  @override
  String get backup_restore_dialog_safetyNote =>
      'Um backup de segurança dos seus dados atuais será criado automaticamente antes da restauração.';

  @override
  String get backup_restore_dialog_title => 'Restaurar Backup';

  @override
  String get backup_restore_dialog_warning =>
      'Isso substituirá TODOS os dados atuais pelos dados do backup. Esta ação não pode ser desfeita.';

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
  String get buddies_picker_addNew => 'Adicionar Novo Companheiro';

  @override
  String get buddies_picker_done => 'Concluir';

  @override
  String get buddies_picker_noBuddiesFound => 'Nenhum companheiro encontrado';

  @override
  String get buddies_picker_noBuddiesYet => 'Nenhum companheiro ainda';

  @override
  String get buddies_picker_noneSelected => 'Nenhum companheiro selecionado';

  @override
  String get buddies_picker_searchHint => 'Buscar companheiros...';

  @override
  String get buddies_picker_selectBuddies => 'Selecionar Companheiros';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Selecionar Função para $name';
  }

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
  String get certifications_detail_label_expiryDate => 'Data de Validade';

  @override
  String get certifications_detail_label_instructorName => 'Nome';

  @override
  String get certifications_detail_label_instructorNumber => 'N. do Instrutor';

  @override
  String get certifications_detail_label_issueDate => 'Data de Emissao';

  @override
  String get certifications_detail_label_level => 'Nivel';

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
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Certificado por $agency';
  }

  @override
  String get certifications_ecard_label_instructor => 'INSTRUTOR';

  @override
  String get certifications_ecard_label_issued => 'EMITIDO';

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
  String get certifications_edit_help_expiryDate =>
      'Deixe vazio para certificacoes que nao expiram';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Insira o numero do cartao de certificacao';

  @override
  String get certifications_edit_hint_certificationName =>
      'ex., Open Water Diver';

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
  String get certifications_edit_label_certificationName =>
      'Nome da Certificacao *';

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
  String get certifications_edit_label_level => 'Nivel';

  @override
  String get certifications_edit_label_notes => 'Observacoes';

  @override
  String get certifications_edit_level_notSpecified => 'Nao especificado';

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
  String get certifications_edit_validation_nameRequired =>
      'Por favor, insira um nome de certificacao';

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
  String certifications_walletCard_countPlural(Object count) {
    return '$count certificacoes';
  }

  @override
  String certifications_walletCard_countSingular(Object count) {
    return '$count certificacao';
  }

  @override
  String get certifications_walletCard_emptyFooter =>
      'Adicione sua primeira certificacao';

  @override
  String get certifications_walletCard_error =>
      'Falha ao carregar certificacoes';

  @override
  String get certifications_walletCard_semanticLabel =>
      'Carteira de Certificacoes. Toque para ver todas as certificacoes';

  @override
  String get certifications_walletCard_tapToAdd => 'Toque para adicionar';

  @override
  String get certifications_walletCard_title => 'Carteira de Certificacoes';

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
  String get common_action_back => 'Voltar';

  @override
  String get common_action_cancel => 'Cancelar';

  @override
  String get common_action_close => 'Fechar';

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
  String get common_label_error => 'Erro';

  @override
  String get common_label_loading => 'Carregando';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get courses_action_add => 'Adicionar Curso';

  @override
  String get courses_action_create => 'Criar Curso';

  @override
  String get courses_action_edit => 'Editar curso';

  @override
  String get courses_action_exportTrainingLog =>
      'Exportar Registro de Treinamento';

  @override
  String get courses_action_markCompleted => 'Marcar como Concluído';

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
  String get courses_field_selectFromBuddies =>
      'Selecionar dos Companheiros (Opcional)';

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
  String get courses_label_none => '-- Nenhum --';

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
  String get courses_section_details => 'Detalhes do Curso';

  @override
  String get courses_section_earnedCertification => 'Certificação Obtida';

  @override
  String get courses_section_instructor => 'Instrutor';

  @override
  String get courses_section_notes => 'Notas';

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
  String get diveCenters_summary_topRated => 'Mais Bem Avaliados';

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
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_tts => 'TTS';

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
  String get diveLog_deco_title => 'Status de Descompressao';

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
  String get diveLog_detail_button_rangeAnalysis => 'Analise de Intervalo';

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
  String get diveLog_detail_fullscreen_sampleData => 'Dados de Amostra';

  @override
  String get diveLog_detail_fullscreen_tapChartCompact =>
      'Toque no gráfico para visualização compacta';

  @override
  String get diveLog_detail_fullscreen_tapChartFull =>
      'Toque no gráfico para visualização em tela cheia';

  @override
  String get diveLog_detail_fullscreen_touchChart =>
      'Toque no gráfico para ver os dados naquele ponto';

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
  String get diveLog_detail_section_decoStatus => 'Status de Descompressao';

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
  String get diveLog_detail_section_sacByCylinder => 'SAC por Cilindro';

  @override
  String get diveLog_detail_section_sacRateBySegment => 'Taxa SAC por Segmento';

  @override
  String get diveLog_detail_section_tags => 'Tags';

  @override
  String get diveLog_detail_section_tanks => 'Cilindros';

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
  String diveLog_detail_tankCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'cilindros',
      one: 'cilindro',
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
  String get diveLog_edit_headerNew => 'Registrar Novo Mergulho';

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
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Tempo de fundo calculado: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Erro ao salvar mergulho: $error';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'Nenhum dado de perfil de mergulho disponivel';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'Nao foi possivel calcular o tempo de fundo a partir do perfil';

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
  String get diveLog_filter_noTagsYet => 'Nenhuma tag criada ainda';

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
  String get diveLog_filter_showOnlyFavorites =>
      'Mostrar apenas mergulhos favoritos';

  @override
  String get diveLog_filter_startDate => 'Data Inicial';

  @override
  String get diveLog_filter_title => 'Filtrar Mergulhos';

  @override
  String get diveLog_filter_tooltip_close => 'Fechar filtro';

  @override
  String get diveLog_fullscreenProfile_close => 'Fechar tela cheia';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Perfil do Mergulho #$number';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Taxa de Subida';

  @override
  String get diveLog_legend_label_ceiling => 'Teto';

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
  String get diveLog_legend_label_surfaceGf => 'GF de Superficie';

  @override
  String get diveLog_legend_label_temp => 'Temp';

  @override
  String get diveLog_legend_label_tts => 'TTS';

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
  String get diveLog_listPage_searchFieldLabel => 'Buscar mergulhos...';

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
  String get diveLog_profileSelector_badge_primary => 'Principal';

  @override
  String get diveLog_profileSelector_label_diveComputers =>
      'Computadores de Mergulho';

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
  String get diveLog_rangeStats_header_avg => 'Media';

  @override
  String get diveLog_rangeStats_header_max => 'Max';

  @override
  String get diveLog_rangeStats_header_min => 'Min';

  @override
  String get diveLog_rangeStats_label_depth => 'Profundidade';

  @override
  String get diveLog_rangeStats_label_heartRate => 'Frequencia Cardiaca';

  @override
  String get diveLog_rangeStats_label_pressure => 'Pressao';

  @override
  String get diveLog_rangeStats_label_temp => 'Temp';

  @override
  String get diveLog_rangeStats_title => 'Analise de Intervalo';

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
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

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
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1.4)';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Mistura de Gas';

  @override
  String get diveLog_tank_selectPreset => 'Selecionar Preset...';

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
  String get diveLog_tooltip_ceiling => 'Teto';

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
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Temp';

  @override
  String get diveLog_tooltip_time => 'Tempo';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get divePlanner_action_addTank => 'Adicionar Cilindro';

  @override
  String get divePlanner_action_convertToDive => 'Converter em Mergulho';

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
  String get divePlanner_label_runtime => 'Tempo Total';

  @override
  String get divePlanner_label_sacRate => 'Taxa SAC:';

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
  String get diveSites_edit_appBar_newSite => 'Novo Ponto';

  @override
  String get diveSites_edit_appBar_save => 'Salvar';

  @override
  String get diveSites_edit_button_addSite => 'Adicionar Ponto';

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
  String get diveSites_edit_gps_gettingLocation => 'Obtendo...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Escolha um metodo de localizacao - as coordenadas preencherao automaticamente pais e regiao';

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
    return '$min-${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'Até ${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '${min}m+';
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
    return 'Tem certeza de que deseja excluir $name? Todos os registros de mergulho associados serao desvinculados.';
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
  String get enum_buddyRole_buddy => 'Dupla';

  @override
  String get enum_buddyRole_diveGuide => 'Guia de Mergulho';

  @override
  String get enum_buddyRole_diveMaster => 'Divemaster';

  @override
  String get enum_buddyRole_instructor => 'Instrutor';

  @override
  String get enum_buddyRole_solo => 'Solo';

  @override
  String get enum_buddyRole_student => 'Aluno';

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
  String get enum_profileEvent_descentEnd => 'Fim da Descida';

  @override
  String get enum_profileEvent_descentStart => 'Inicio da Descida';

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
  String get equipment_addSheet_brandHint => 'ex., Scubapro';

  @override
  String get equipment_addSheet_brandLabel => 'Marca';

  @override
  String get equipment_addSheet_closeTooltip => 'Fechar';

  @override
  String get equipment_addSheet_currencyLabel => 'Moeda';

  @override
  String get equipment_addSheet_dateLabel => 'Data';

  @override
  String equipment_addSheet_errorSnackbar(Object error) {
    return 'Erro ao adicionar equipamento: $error';
  }

  @override
  String get equipment_addSheet_modelHint => 'ex., MK25 EVO';

  @override
  String get equipment_addSheet_modelLabel => 'Modelo';

  @override
  String get equipment_addSheet_nameHint => 'ex., Meu Regulador Principal';

  @override
  String get equipment_addSheet_nameLabel => 'Nome';

  @override
  String get equipment_addSheet_nameValidation => 'Por favor, insira um nome';

  @override
  String get equipment_addSheet_notesHint => 'Observacoes adicionais...';

  @override
  String get equipment_addSheet_notesLabel => 'Observacoes';

  @override
  String get equipment_addSheet_priceLabel => 'Preco';

  @override
  String get equipment_addSheet_purchaseInfoTitle => 'Informacoes de Compra';

  @override
  String get equipment_addSheet_serialNumberLabel => 'Numero de Serie';

  @override
  String get equipment_addSheet_serviceIntervalHint =>
      'ex., 365 para anualmente';

  @override
  String get equipment_addSheet_serviceIntervalLabel =>
      'Intervalo de Manutencao (dias)';

  @override
  String get equipment_addSheet_sizeHint => 'ex., M, G, 42';

  @override
  String get equipment_addSheet_sizeLabel => 'Tamanho';

  @override
  String get equipment_addSheet_submitButton => 'Adicionar Equipamento';

  @override
  String get equipment_addSheet_successSnackbar =>
      'Equipamento adicionado com sucesso';

  @override
  String get equipment_addSheet_title => 'Adicionar Equipamento';

  @override
  String get equipment_addSheet_typeLabel => 'Tipo';

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
  String get equipment_serviceDialog_serviceTypeLabel => 'Tipo de Manutencao';

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
  String get gasCalculators_ppO2Limit => 'Limite ppO₂';

  @override
  String get gasCalculators_resetAll => 'Restaurar todas as calculadoras';

  @override
  String get gasCalculators_sacRate => 'Taxa SAC';

  @override
  String get gasCalculators_tab_bestMix => 'Melhor Mistura';

  @override
  String get gasCalculators_tab_consumption => 'Consumo';

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
  String get media_diveMediaSection_emptyState => 'Nenhuma foto ainda';

  @override
  String get media_diveMediaSection_errorLoading => 'Erro ao carregar midia';

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'Ver foto. Pressione e segure para desvincular';

  @override
  String get media_diveMediaSection_title => 'Fotos e Video';

  @override
  String get media_diveMediaSection_unlinkButton => 'Desvincular';

  @override
  String get media_diveMediaSection_unlinkDialogContent =>
      'Remover esta foto do mergulho? A foto permanecera na sua galeria.';

  @override
  String get media_diveMediaSection_unlinkDialogTitle => 'Desvincular Foto';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Falha ao desvincular: $error';
  }

  @override
  String get media_diveMediaSection_unlinkSuccess => 'Foto desvinculada';

  @override
  String get media_gpsBanner_addToSiteButton => 'Adicionar ao Ponto';

  @override
  String media_gpsBanner_coordinates(Object latitude, Object longitude) {
    return 'Coordenadas: $latitude, $longitude';
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
  String media_import_importedAndFailed(Object imported, Object failed) {
    return 'Importadas $imported, falharam $failed';
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
  String get media_miniProfile_headerLabel => 'Perfil do Mergulho';

  @override
  String get media_miniProfile_semanticLabel =>
      'Grafico mini do perfil de mergulho';

  @override
  String get media_photoPicker_appBarTitle => 'Selecionar Fotos';

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
  String get media_photoPicker_grantAccessButton => 'Conceder Acesso';

  @override
  String get media_photoPicker_openSettingsButton => 'Abrir Configuracoes';

  @override
  String get media_photoPicker_openSettingsSnackbar =>
      'Abra as Configuracoes e habilite o acesso a fotos';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'O acesso a biblioteca de fotos foi negado. Habilite-o nas Configuracoes para adicionar fotos de mergulho.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'O Submersion precisa de acesso a sua biblioteca de fotos para adicionar fotos de mergulho.';

  @override
  String get media_photoPicker_permissionTitle => 'Acesso a Fotos Necessario';

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
  String get media_photoViewer_noPhotosAvailable => 'Nenhuma foto disponivel';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel =>
      'Reproduzir ou pausar video';

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
  String get nav_home => 'Inicio';

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
  String get onboarding_welcome_createProfile => 'Crie Seu Perfil';

  @override
  String get onboarding_welcome_createProfileSubtitle =>
      'Digite seu nome para começar. Você pode adicionar mais detalhes depois.';

  @override
  String get onboarding_welcome_creating => 'Criando...';

  @override
  String onboarding_welcome_errorCreatingProfile(Object error) {
    return 'Erro ao criar perfil: $error';
  }

  @override
  String get onboarding_welcome_getStarted => 'Começar';

  @override
  String get onboarding_welcome_nameHint => 'Digite seu nome';

  @override
  String get onboarding_welcome_nameLabel => 'Seu Nome';

  @override
  String get onboarding_welcome_nameValidation => 'Digite seu nome';

  @override
  String get onboarding_welcome_subtitle =>
      'Registro e análise avançada de mergulhos';

  @override
  String get onboarding_welcome_title => 'Bem-vindo ao Submersion';

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
  String get settings_about_reportIssue_snackbar =>
      'Acesse github.com/submersion/submersion';

  @override
  String settings_about_version(String version, String buildNumber) {
    return 'Versao $version ($buildNumber)';
  }

  @override
  String get settings_appBar_title => 'Configuracoes';

  @override
  String get settings_appearance_appLanguage => 'Idioma do Aplicativo';

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
  String get settings_appearance_header_diveLog => 'Registro de Mergulho';

  @override
  String get settings_appearance_header_diveProfile => 'Perfil de Mergulho';

  @override
  String get settings_appearance_header_diveSites => 'Pontos de Mergulho';

  @override
  String get settings_appearance_header_language => 'Idioma';

  @override
  String get settings_appearance_header_theme => 'Tema';

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
  String get settings_appearance_pressureThresholdMarkers =>
      'Marcadores de limite de pressao';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'Mostrar marcadores quando a pressao do cilindro cruza limites';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'Mostrar marcadores quando a pressao do cilindro cruza os limites de 2/3, 1/2 e 1/3';

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
  String get settings_backToSettings_tooltip => 'Voltar para configuracoes';

  @override
  String get settings_cloudSync_appBar_title => 'Sincronizacao na Nuvem';

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
  String get settings_cloudSync_header_advanced => 'Avancado';

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
    return 'Falha ao inicializar provedor $providerName';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'Nao disponivel nesta plataforma';

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
  String get settings_data_backup => 'Backup';

  @override
  String get settings_data_backup_subtitle => 'Criar um backup dos seus dados';

  @override
  String get settings_data_cloudSync => 'Sincronizacao na Nuvem';

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
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'Selecionar predefinicao de conservadorismo $presetName';
  }

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
  String get settings_manage_tankPresets => 'Predefinicoes de Cilindro';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Gerenciar configuracoes personalizadas de cilindro';

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
  String get settings_notifications_disabled_enableButton => 'Ativar';

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
  String surfaceInterval_heSemantics(Object percent) {
    return 'Hélio: $percent%';
  }

  @override
  String surfaceInterval_o2Semantics(Object percent) {
    return 'O2: $percent%';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Intervalo Atual';

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
  String get surfaceInterval_secondDive_gasAir => '(Ar)';

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
  String get tags_hint_addTags => 'Adicionar tags...';

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
      'Importar mergulhos gravados no Apple Watch Ultra';

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
  String get transfer_import_autoDetectSemanticLabel =>
      'Importar dados com deteccao automatica';

  @override
  String get transfer_import_autoDetectSubtitle =>
      'Detecta automaticamente CSV, UDDF, FIT e mais';

  @override
  String get transfer_import_autoDetectTitle => 'Importar Dados';

  @override
  String get transfer_import_byFormatHeader => 'Importar por Formato';

  @override
  String get transfer_import_csvSubtitle => 'Importar mergulhos de arquivo CSV';

  @override
  String get transfer_import_csvTitle => 'Importar de CSV';

  @override
  String get transfer_import_fitSubtitle =>
      'Importar mergulhos de arquivos de exportacao Garmin Descent';

  @override
  String get transfer_import_fitTitle => 'Importar de Arquivo FIT';

  @override
  String get transfer_import_operationCompleted => 'Operacao concluida';

  @override
  String transfer_import_operationFailed(Object error) {
    return 'Falha na operacao: $error';
  }

  @override
  String get transfer_import_sectionHeader => 'Importar Dados';

  @override
  String get transfer_import_uddfSubtitle => 'Universal Dive Data Format';

  @override
  String get transfer_import_uddfTitle => 'Importar de UDDF';

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
  String get trips_detail_stat_totalBottomTime => 'Tempo de Fundo Total';

  @override
  String get trips_detail_stat_totalDives => 'Total de Mergulhos';

  @override
  String get trips_detail_tooltip_edit => 'Editar viagem';

  @override
  String get trips_detail_tooltip_editShort => 'Editar';

  @override
  String get trips_detail_tooltip_moreOptions => 'Mais opcoes';

  @override
  String get trips_detail_tooltip_viewOnMap => 'Ver no Mapa';

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
  String get universalImport_action_selectFile => 'Selecionar Arquivo';

  @override
  String get universalImport_description_supportedFormats =>
      'Selecione um arquivo de registro de mergulho para importar. Os formatos suportados incluem CSV, UDDF, Subsurface XML e Garmin FIT.';

  @override
  String get universalImport_error_unsupportedFormat =>
      'Este formato ainda não é suportado. Exporte como UDDF ou CSV.';

  @override
  String get universalImport_hint_tagDescription =>
      'Marque todos os mergulhos importados para facilitar a filtragem';

  @override
  String get universalImport_hint_tagExample =>
      'ex: Importação MacDive 2026-02-09';

  @override
  String get universalImport_label_columnMapping => 'Mapeamento de Colunas';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped de $total colunas mapeadas';
  }

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
  String get universalImport_label_importComplete => 'Importação Concluída';

  @override
  String get universalImport_label_importTag => 'Tag de Importação';

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
  String get universalImport_step_import => 'Importar';

  @override
  String get universalImport_step_map => 'Mapear';

  @override
  String get universalImport_step_review => 'Revisar';

  @override
  String get universalImport_step_select => 'Selecionar';

  @override
  String get universalImport_title => 'Importar Dados';

  @override
  String get universalImport_tooltip_clearTag => 'Limpar tag';

  @override
  String get universalImport_tooltip_closeWizard =>
      'Fechar assistente de importação';

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
  String get diveComputer_downloadStep_downloadFailed => 'Falha no download';

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
  String get diveComputer_download_newDivesImported =>
      'Novos mergulhos importados';

  @override
  String get diveComputer_download_preparing => 'Preparando...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

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
      'O Submersion precisa de acesso aos dados de mergulho do Apple Watch para importar mergulhos.';

  @override
  String get diveImport_healthkit_accessRequired =>
      'Acesso ao HealthKit Necessario';

  @override
  String get diveImport_healthkit_closeTooltip =>
      'Fechar importacao do Apple Watch';

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
  String get diveImport_healthkit_grantAccess => 'Conceder Acesso';

  @override
  String get diveImport_healthkit_noDivesFound => 'Nenhum Mergulho Encontrado';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'Nenhuma atividade de mergulho subaquatico encontrada no periodo selecionado.';

  @override
  String get diveImport_healthkit_notAvailable => 'Nao Disponivel';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'A importacao do Apple Watch esta disponivel apenas em dispositivos iOS e macOS.';

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
  String get gasCalculators_rockBottom_aboutDescription =>
      'Rock bottom e a reserva minima de gas para uma subida de emergencia partilhando ar com o seu companheiro.\n\n- Utiliza taxas SAC sob stress (2-3x o normal)\n- Assume ambos os mergulhadores num unico cilindro\n- Inclui parada de seguranca quando ativada\n\nVire sempre o mergulho ANTES de atingir o rock bottom!';

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
  String get gasCalculators_rockBottom_buddySac => 'SAC do Companheiro';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'SAC combinado sob stress';

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
      'Use taxas SAC mais altas para compensar o stress durante emergencias';

  @override
  String get gasCalculators_rockBottom_stressedSacRates =>
      'Taxas SAC sob Stress';

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
  String get gasCalculators_rockBottom_yourSac => 'Seu SAC';

  @override
  String get maps_heatMap_hide => 'Ocultar Mapa de Calor';

  @override
  String get maps_heatMap_overlayOff =>
      'Sobreposicao do mapa de calor desativada';

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
  String get tankPresets_customPresets => 'Presets Personalizados';

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
  String get tankPresets_new_title => 'Novo Preset de Cilindro';

  @override
  String get tankPresets_noPresets => 'Nenhum preset de cilindro disponivel';

  @override
  String get tankPresets_title => 'Presets de Cilindro';

  @override
  String get tools_deco_description =>
      'Calcule limites de nao descompressao, paradas deco necessarias e exposicao CNS/OTU para perfis de mergulho multinivel.';

  @override
  String get tools_deco_subtitle =>
      'Planeje mergulhos com paradas de descompressao';

  @override
  String get tools_deco_title => 'Calculadora Deco';

  @override
  String get tools_disclaimer =>
      'Estas calculadoras sao apenas para fins de planeamento. Sempre verifique os calculos e siga o seu treinamento de mergulho.';

  @override
  String get tools_gas_description =>
      'Quatro calculadoras de gas especializadas:\n- MOD - Profundidade maxima operacional para uma mistura\n- Best Mix - O2% ideal para uma profundidade alvo\n- Consumo - Estimativa de uso de gas\n- Rock Bottom - Calculo de reserva de emergencia';

  @override
  String get tools_gas_subtitle => 'MOD, Best Mix, Consumo, Rock Bottom';

  @override
  String get tools_gas_title => 'Calculadoras de Gas';

  @override
  String get tools_title => 'Ferramentas';

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
  String get tools_weight_description =>
      'Estime o lastro necessario com base na sua roupa, material do cilindro, tipo de agua e peso corporal.';

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
  String get tools_weight_subtitle =>
      'Lastro recomendado para o seu equipamento';

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
}
