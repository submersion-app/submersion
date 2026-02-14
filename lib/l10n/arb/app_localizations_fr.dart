// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get accessibility_dialog_keyboardShortcutsTitle =>
      'Raccourcis clavier';

  @override
  String get accessibility_keyLabel_backspace => 'Retour arriere';

  @override
  String get accessibility_keyLabel_delete => 'Suppr';

  @override
  String get accessibility_keyLabel_down => 'Bas';

  @override
  String get accessibility_keyLabel_enter => 'Entree';

  @override
  String get accessibility_keyLabel_esc => 'Echap';

  @override
  String get accessibility_keyLabel_left => 'Gauche';

  @override
  String get accessibility_keyLabel_right => 'Droite';

  @override
  String get accessibility_keyLabel_up => 'Haut';

  @override
  String accessibility_label_chartSummary(
    Object chartType,
    Object description,
  ) {
    return 'Graphique $chartType. $description';
  }

  @override
  String get accessibility_label_createNewItem => 'Creer un nouvel element';

  @override
  String get accessibility_label_hideList => 'Masquer la liste';

  @override
  String get accessibility_label_hideMapView => 'Masquer la vue carte';

  @override
  String accessibility_label_listPane(Object title) {
    return 'Volet liste $title';
  }

  @override
  String accessibility_label_mapPane(Object title) {
    return 'Volet carte $title';
  }

  @override
  String accessibility_label_mapViewTitle(Object title) {
    return 'Vue carte $title';
  }

  @override
  String get accessibility_label_showList => 'Afficher la liste';

  @override
  String get accessibility_label_showMapView => 'Afficher la vue carte';

  @override
  String get accessibility_label_viewDetails => 'Voir les details';

  @override
  String get accessibility_modifierKey_alt => 'Alt+';

  @override
  String get accessibility_modifierKey_cmd => 'Cmd+';

  @override
  String get accessibility_modifierKey_ctrl => 'Ctrl+';

  @override
  String get accessibility_modifierKey_option => 'Option+';

  @override
  String get accessibility_modifierKey_shift => 'Maj+';

  @override
  String get accessibility_modifierKey_super => 'Super+';

  @override
  String get accessibility_shortcutCategory_editing => 'Edition';

  @override
  String get accessibility_shortcutCategory_general => 'General';

  @override
  String get accessibility_shortcutCategory_help => 'Aide';

  @override
  String get accessibility_shortcutCategory_navigation => 'Navigation';

  @override
  String get accessibility_shortcutCategory_search => 'Recherche';

  @override
  String get accessibility_shortcut_closeCancel => 'Fermer / Annuler';

  @override
  String get accessibility_shortcut_goBack => 'Revenir en arriere';

  @override
  String get accessibility_shortcut_goToDives => 'Aller aux plongees';

  @override
  String get accessibility_shortcut_goToEquipment => 'Aller a l\'equipement';

  @override
  String get accessibility_shortcut_goToSettings => 'Aller aux reglages';

  @override
  String get accessibility_shortcut_goToSites => 'Aller aux sites';

  @override
  String get accessibility_shortcut_goToStatistics => 'Aller aux statistiques';

  @override
  String get accessibility_shortcut_keyboardShortcuts => 'Raccourcis clavier';

  @override
  String get accessibility_shortcut_newDive => 'Nouvelle plongee';

  @override
  String get accessibility_shortcut_openSettings => 'Ouvrir les reglages';

  @override
  String get accessibility_shortcut_searchDives => 'Rechercher des plongees';

  @override
  String accessibility_sort_selectedLabel(Object displayName) {
    return 'Trier par $displayName, actuellement selectionne';
  }

  @override
  String accessibility_sort_unselectedLabel(Object displayName) {
    return 'Trier par $displayName';
  }

  @override
  String get backup_appBar_title => 'Sauvegarde et Restauration';

  @override
  String get backup_backingUp => 'Sauvegarde en cours...';

  @override
  String get backup_backupNow => 'Sauvegarder Maintenant';

  @override
  String get backup_cloud_enabled => 'Sauvegarde cloud';

  @override
  String get backup_cloud_enabled_subtitle =>
      'Téléverser les sauvegardes vers le cloud';

  @override
  String get backup_delete_dialog_cancel => 'Annuler';

  @override
  String get backup_delete_dialog_content =>
      'Cette sauvegarde sera supprimée définitivement. Cette action est irréversible.';

  @override
  String get backup_delete_dialog_delete => 'Supprimer';

  @override
  String get backup_delete_dialog_title => 'Supprimer la Sauvegarde';

  @override
  String get backup_frequency_daily => 'Quotidienne';

  @override
  String get backup_frequency_monthly => 'Mensuelle';

  @override
  String get backup_frequency_weekly => 'Hebdomadaire';

  @override
  String get backup_history_action_delete => 'Supprimer';

  @override
  String get backup_history_action_restore => 'Restaurer';

  @override
  String get backup_history_empty => 'Aucune sauvegarde';

  @override
  String backup_history_error(Object error) {
    return 'Échec du chargement de l\'historique : $error';
  }

  @override
  String get backup_restore_dialog_cancel => 'Annuler';

  @override
  String get backup_restore_dialog_restore => 'Restaurer';

  @override
  String get backup_restore_dialog_safetyNote =>
      'Une sauvegarde de sécurité de vos données actuelles sera créée automatiquement avant la restauration.';

  @override
  String get backup_restore_dialog_title => 'Restaurer la Sauvegarde';

  @override
  String get backup_restore_dialog_warning =>
      'Cela remplacera TOUTES les données actuelles par les données de la sauvegarde. Cette action est irréversible.';

  @override
  String get backup_schedule_enabled => 'Sauvegardes automatiques';

  @override
  String get backup_schedule_enabled_subtitle =>
      'Sauvegarder vos données selon un calendrier';

  @override
  String get backup_schedule_frequency => 'Fréquence';

  @override
  String get backup_schedule_retention => 'Conserver les sauvegardes';

  @override
  String get backup_schedule_retention_subtitle =>
      'Les anciennes sauvegardes sont supprimées automatiquement';

  @override
  String get backup_section_cloud => 'Cloud';

  @override
  String get backup_section_history => 'Historique';

  @override
  String get backup_section_schedule => 'Planification';

  @override
  String get backup_status_disabled => 'Sauvegardes Automatiques Désactivées';

  @override
  String backup_status_lastBackup(String time) {
    return 'Dernière sauvegarde : $time';
  }

  @override
  String get backup_status_neverBackedUp => 'Jamais Sauvegardé';

  @override
  String get backup_status_noBackupsYet =>
      'Créez votre première sauvegarde pour protéger vos données';

  @override
  String get backup_status_overdue => 'Sauvegarde en Retard';

  @override
  String get backup_status_upToDate => 'Sauvegardes à Jour';

  @override
  String backup_time_daysAgo(int count) {
    return 'il y a ${count}j';
  }

  @override
  String backup_time_hoursAgo(int count) {
    return 'il y a ${count}h';
  }

  @override
  String get backup_time_justNow => 'À l\'instant';

  @override
  String backup_time_minutesAgo(int count) {
    return 'il y a ${count}m';
  }

  @override
  String get buddies_action_add => 'Ajouter un binôme';

  @override
  String get buddies_action_addFirst => 'Ajouter votre premier binôme';

  @override
  String get buddies_action_addTooltip =>
      'Ajouter un nouveau binôme de plongée';

  @override
  String get buddies_action_clearSearch => 'Effacer la recherche';

  @override
  String get buddies_action_edit => 'Modifier le binôme';

  @override
  String get buddies_action_importFromContacts =>
      'Importer depuis les contacts';

  @override
  String get buddies_action_moreOptions => 'Plus d\'options';

  @override
  String get buddies_action_retry => 'Réessayer';

  @override
  String get buddies_action_search => 'Rechercher des binômes';

  @override
  String get buddies_action_shareDives => 'Partager les plongées';

  @override
  String get buddies_action_sort => 'Trier';

  @override
  String get buddies_action_sortTitle => 'Trier les binômes';

  @override
  String get buddies_action_update => 'Mettre à jour le binôme';

  @override
  String buddies_action_viewAll(Object count) {
    return 'Voir tout ($count)';
  }

  @override
  String buddies_detail_error(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get buddies_detail_noDivesTogether =>
      'Aucune plongée ensemble pour le moment';

  @override
  String get buddies_detail_notFound => 'Binôme introuvable';

  @override
  String buddies_dialog_deleteMessage(Object name) {
    return 'Voulez-vous vraiment supprimer $name ? Cette action est irréversible.';
  }

  @override
  String get buddies_dialog_deleteTitle => 'Supprimer le binôme ?';

  @override
  String get buddies_dialog_discard => 'Abandonner';

  @override
  String get buddies_dialog_discardMessage =>
      'Vous avez des modifications non enregistrées. Voulez-vous vraiment les abandonner ?';

  @override
  String get buddies_dialog_discardTitle => 'Abandonner les modifications ?';

  @override
  String get buddies_dialog_keepEditing => 'Continuer à modifier';

  @override
  String get buddies_empty_subtitle =>
      'Ajoutez votre premier binôme de plongée pour commencer';

  @override
  String get buddies_empty_title => 'Aucun binôme de plongée pour le moment';

  @override
  String buddies_error_loading(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get buddies_error_unableToLoadDives =>
      'Impossible de charger les plongées';

  @override
  String get buddies_error_unableToLoadStats =>
      'Impossible de charger les statistiques';

  @override
  String get buddies_field_certificationAgency => 'Organisme de certification';

  @override
  String get buddies_field_certificationLevel => 'Niveau de certification';

  @override
  String get buddies_field_email => 'E-mail';

  @override
  String get buddies_field_emailHint => 'email@exemple.com';

  @override
  String get buddies_field_nameHint => 'Entrer le nom du binôme';

  @override
  String get buddies_field_nameRequired => 'Nom *';

  @override
  String get buddies_field_notes => 'Notes';

  @override
  String get buddies_field_notesHint => 'Ajouter des notes sur ce binôme...';

  @override
  String get buddies_field_phone => 'Téléphone';

  @override
  String get buddies_field_phoneHint => '+33 6 12 34 56 78';

  @override
  String get buddies_label_agency => 'Organisme';

  @override
  String buddies_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongées',
      one: '1 plongée',
    );
    return '$_temp0';
  }

  @override
  String get buddies_label_level => 'Niveau';

  @override
  String get buddies_label_notSpecified => 'Non spécifié';

  @override
  String get buddies_label_photoComingSoon =>
      'Support photo disponible dans la v2.0';

  @override
  String get buddies_message_added => 'Binôme ajouté avec succès';

  @override
  String get buddies_message_contactImportUnavailable =>
      'L\'import de contacts n\'est pas disponible sur cette plateforme';

  @override
  String get buddies_message_contactLoadFailed =>
      'Échec du chargement des contacts';

  @override
  String get buddies_message_contactPermissionRequired =>
      'L\'autorisation d\'accès aux contacts est requise pour importer des binômes';

  @override
  String get buddies_message_deleted => 'Binôme supprimé';

  @override
  String buddies_message_errorImportingContact(Object error) {
    return 'Erreur lors de l\'import du contact : $error';
  }

  @override
  String buddies_message_errorLoading(Object error) {
    return 'Erreur lors du chargement du binôme : $error';
  }

  @override
  String buddies_message_errorSaving(Object error) {
    return 'Erreur lors de l\'enregistrement du binôme : $error';
  }

  @override
  String buddies_message_exportFailed(Object error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String get buddies_message_noDivesFound =>
      'Aucune plongée trouvée à exporter';

  @override
  String get buddies_message_noDivesToShare =>
      'Aucune plongée à partager avec ce binôme';

  @override
  String get buddies_message_preparingExport => 'Préparation de l\'export...';

  @override
  String get buddies_message_updated => 'Binôme mis à jour avec succès';

  @override
  String get buddies_picker_add => 'Ajouter';

  @override
  String get buddies_picker_addNew => 'Ajouter un nouveau binôme';

  @override
  String get buddies_picker_done => 'Terminé';

  @override
  String get buddies_picker_noBuddiesFound => 'Aucun binôme trouvé';

  @override
  String get buddies_picker_noBuddiesYet => 'Aucun binôme pour le moment';

  @override
  String get buddies_picker_noneSelected => 'Aucun binôme sélectionné';

  @override
  String get buddies_picker_searchHint => 'Rechercher des binômes...';

  @override
  String get buddies_picker_selectBuddies => 'Sélectionner les binômes';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Sélectionner le rôle pour $name';
  }

  @override
  String get buddies_picker_tapToAdd =>
      'Appuyez sur « Ajouter » pour sélectionner des binômes de plongée';

  @override
  String get buddies_search_hint => 'Rechercher par nom, e-mail ou téléphone';

  @override
  String buddies_search_noResults(Object query) {
    return 'Aucun binôme trouvé pour « $query »';
  }

  @override
  String get buddies_section_certification => 'Certification';

  @override
  String get buddies_section_contact => 'Contact';

  @override
  String get buddies_section_diveStatistics => 'Statistiques de plongée';

  @override
  String get buddies_section_notes => 'Notes';

  @override
  String get buddies_section_sharedDives => 'Plongées partagées';

  @override
  String get buddies_stat_divesTogether => 'Plongées ensemble';

  @override
  String get buddies_stat_favoriteSite => 'Site préféré';

  @override
  String get buddies_stat_firstDive => 'Première plongée';

  @override
  String get buddies_stat_lastDive => 'Dernière plongée';

  @override
  String get buddies_summary_overview => 'Vue d\'ensemble';

  @override
  String get buddies_summary_quickActions => 'Actions rapides';

  @override
  String get buddies_summary_recentBuddies => 'Binômes récents';

  @override
  String get buddies_summary_selectHint =>
      'Sélectionnez un binôme dans la liste pour afficher les détails';

  @override
  String get buddies_summary_title => 'Binômes de plongée';

  @override
  String get buddies_summary_totalBuddies => 'Total binômes';

  @override
  String get buddies_summary_withCertification => 'Avec certification';

  @override
  String get buddies_title => 'Binômes';

  @override
  String get buddies_title_add => 'Ajouter un binôme';

  @override
  String get buddies_title_edit => 'Modifier le binôme';

  @override
  String get buddies_title_singular => 'Binôme';

  @override
  String get buddies_validation_emailInvalid =>
      'Veuillez entrer une adresse e-mail valide';

  @override
  String get buddies_validation_nameRequired => 'Veuillez entrer un nom';

  @override
  String get certifications_appBar_addCertification =>
      'Ajouter une certification';

  @override
  String get certifications_appBar_certificationWallet =>
      'Portefeuille de certifications';

  @override
  String get certifications_appBar_editCertification =>
      'Modifier la certification';

  @override
  String get certifications_appBar_title => 'Certifications';

  @override
  String get certifications_detail_action_delete => 'Supprimer';

  @override
  String get certifications_detail_appBar_title => 'Certification';

  @override
  String get certifications_detail_courseCompleted => 'Termine';

  @override
  String get certifications_detail_courseInProgress => 'En cours';

  @override
  String get certifications_detail_dialog_cancel => 'Annuler';

  @override
  String get certifications_detail_dialog_deleteConfirm => 'Supprimer';

  @override
  String certifications_detail_dialog_deleteContent(Object name) {
    return 'Es-tu sur de vouloir supprimer \"$name\" ?';
  }

  @override
  String get certifications_detail_dialog_deleteTitle =>
      'Supprimer la certification ?';

  @override
  String get certifications_detail_label_agency => 'Organisme';

  @override
  String get certifications_detail_label_cardNumber => 'Numero de carte';

  @override
  String get certifications_detail_label_expiryDate => 'Date d\'expiration';

  @override
  String get certifications_detail_label_instructorName => 'Nom';

  @override
  String get certifications_detail_label_instructorNumber => 'N° du moniteur';

  @override
  String get certifications_detail_label_issueDate => 'Date de delivrance';

  @override
  String get certifications_detail_label_level => 'Niveau';

  @override
  String get certifications_detail_label_type => 'Type';

  @override
  String get certifications_detail_label_validity => 'Validite';

  @override
  String get certifications_detail_noExpiration => 'Sans expiration';

  @override
  String get certifications_detail_notFound => 'Certification introuvable';

  @override
  String get certifications_detail_photoLabel_back => 'Verso';

  @override
  String get certifications_detail_photoLabel_front => 'Recto';

  @override
  String certifications_detail_photo_fullscreenTitle(
    Object label,
    Object name,
  ) {
    return '$label - $name';
  }

  @override
  String get certifications_detail_photo_unableToLoad =>
      'Impossible de charger l\'image';

  @override
  String get certifications_detail_sectionTitle_cardPhotos =>
      'Photos de la carte';

  @override
  String get certifications_detail_sectionTitle_dates => 'Dates';

  @override
  String get certifications_detail_sectionTitle_details =>
      'Details de la certification';

  @override
  String get certifications_detail_sectionTitle_instructor => 'Moniteur';

  @override
  String get certifications_detail_sectionTitle_notes => 'Notes';

  @override
  String get certifications_detail_sectionTitle_trainingCourse => 'Formation';

  @override
  String certifications_detail_semanticLabel_photoTapToView(
    Object label,
    Object name,
  ) {
    return 'Photo $label de $name. Appuie pour voir en plein ecran';
  }

  @override
  String get certifications_detail_snackBar_deleted =>
      'Certification supprimee';

  @override
  String get certifications_detail_status_expired =>
      'Cette certification a expire';

  @override
  String certifications_detail_status_expiredOn(Object date) {
    return 'Expiree le $date';
  }

  @override
  String certifications_detail_status_expiresInDays(Object days) {
    return 'Expire dans $days jours';
  }

  @override
  String certifications_detail_status_expiresOn(Object date) {
    return 'Expire le $date';
  }

  @override
  String get certifications_detail_tooltip_edit => 'Modifier la certification';

  @override
  String get certifications_detail_tooltip_editShort => 'Modifier';

  @override
  String get certifications_detail_tooltip_moreOptions => 'Plus d\'options';

  @override
  String get certifications_ecardStack_empty_subtitle =>
      'Ajoute ta premiere certification pour la voir ici';

  @override
  String get certifications_ecardStack_empty_title => 'Aucune certification';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Certifie par $agency';
  }

  @override
  String get certifications_ecard_label_instructor => 'MONITEUR';

  @override
  String get certifications_ecard_label_issued => 'DELIVRE';

  @override
  String get certifications_ecard_statusBadge_expired => 'EXPIRE';

  @override
  String get certifications_ecard_statusBadge_expiring => 'BIENTOT EXPIRE';

  @override
  String get certifications_edit_appBar_add => 'Ajouter une certification';

  @override
  String get certifications_edit_appBar_edit => 'Modifier la certification';

  @override
  String get certifications_edit_button_add => 'Ajouter la certification';

  @override
  String get certifications_edit_button_cancel => 'Annuler';

  @override
  String get certifications_edit_button_save => 'Enregistrer';

  @override
  String get certifications_edit_button_update =>
      'Mettre a jour la certification';

  @override
  String certifications_edit_datePicker_clearTooltip(Object label) {
    return 'Effacer $label';
  }

  @override
  String get certifications_edit_datePicker_tapToSelect =>
      'Appuie pour selectionner';

  @override
  String get certifications_edit_dialog_discard => 'Abandonner';

  @override
  String get certifications_edit_dialog_discardContent =>
      'Tu as des modifications non enregistrees. Es-tu sur de vouloir quitter ?';

  @override
  String get certifications_edit_dialog_discardTitle =>
      'Abandonner les modifications ?';

  @override
  String get certifications_edit_dialog_keepEditing => 'Continuer l\'edition';

  @override
  String get certifications_edit_help_expiryDate =>
      'Laisse vide pour les certifications sans expiration';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Entrez le numero de carte de certification';

  @override
  String get certifications_edit_hint_certificationName =>
      'ex. Open Water Diver';

  @override
  String get certifications_edit_hint_instructorName =>
      'Nom du moniteur certificateur';

  @override
  String get certifications_edit_hint_instructorNumber =>
      'Numero de certification du moniteur';

  @override
  String get certifications_edit_hint_notes => 'Notes supplementaires';

  @override
  String get certifications_edit_label_agency => 'Organisme *';

  @override
  String get certifications_edit_label_cardNumber => 'Numero de carte';

  @override
  String get certifications_edit_label_certificationName =>
      'Nom de la certification *';

  @override
  String get certifications_edit_label_expiryDate => 'Date d\'expiration';

  @override
  String get certifications_edit_label_instructorName => 'Nom du moniteur';

  @override
  String get certifications_edit_label_instructorNumber => 'Numero du moniteur';

  @override
  String get certifications_edit_label_issueDate => 'Date de delivrance';

  @override
  String get certifications_edit_label_level => 'Niveau';

  @override
  String get certifications_edit_label_notes => 'Notes';

  @override
  String get certifications_edit_level_notSpecified => 'Non specifie';

  @override
  String certifications_edit_photo_addSemanticLabel(Object label) {
    return 'Ajouter une photo $label. Appuie pour selectionner';
  }

  @override
  String certifications_edit_photo_attachedSemanticLabel(Object label) {
    return 'Photo $label jointe. Appuie pour changer';
  }

  @override
  String get certifications_edit_photo_chooseFromGallery =>
      'Choisir dans la galerie';

  @override
  String certifications_edit_photo_removeTooltip(Object label) {
    return 'Supprimer la photo $label';
  }

  @override
  String get certifications_edit_photo_takePhoto => 'Prendre une photo';

  @override
  String get certifications_edit_sectionTitle_cardPhotos =>
      'Photos de la carte';

  @override
  String get certifications_edit_sectionTitle_dates => 'Dates';

  @override
  String get certifications_edit_sectionTitle_instructorInfo =>
      'Informations du moniteur';

  @override
  String get certifications_edit_sectionTitle_notes => 'Notes';

  @override
  String get certifications_edit_snackBar_added =>
      'Certification ajoutee avec succes';

  @override
  String certifications_edit_snackBar_errorLoading(Object error) {
    return 'Erreur de chargement de la certification : $error';
  }

  @override
  String certifications_edit_snackBar_errorPhoto(Object error) {
    return 'Erreur de selection de la photo : $error';
  }

  @override
  String certifications_edit_snackBar_errorSaving(Object error) {
    return 'Erreur d\'enregistrement de la certification : $error';
  }

  @override
  String get certifications_edit_snackBar_updated =>
      'Certification mise a jour avec succes';

  @override
  String get certifications_edit_validation_nameRequired =>
      'Veuillez entrer un nom de certification';

  @override
  String get certifications_list_button_retry => 'Reessayer';

  @override
  String get certifications_list_empty_button =>
      'Ajouter votre premiere certification';

  @override
  String get certifications_list_empty_subtitle =>
      'Ajoutez vos certifications de plongee pour suivre\nvotre formation et vos qualifications';

  @override
  String get certifications_list_empty_title => 'Aucune certification ajoutee';

  @override
  String certifications_list_error_loading(Object error) {
    return 'Erreur lors du chargement des certifications : $error';
  }

  @override
  String get certifications_list_fab_addCertification =>
      'Ajouter une certification';

  @override
  String get certifications_list_section_expired => 'Expiree';

  @override
  String get certifications_list_section_expiringSoon => 'Expire bientot';

  @override
  String get certifications_list_section_valid => 'Valide';

  @override
  String get certifications_list_sort_title => 'Trier les certifications';

  @override
  String get certifications_list_tile_expired => 'Expiree';

  @override
  String certifications_list_tile_expiringDays(Object days) {
    return '${days}j';
  }

  @override
  String get certifications_list_tooltip_addCertification =>
      'Ajouter une certification';

  @override
  String get certifications_list_tooltip_search =>
      'Rechercher des certifications';

  @override
  String get certifications_list_tooltip_sort => 'Trier';

  @override
  String get certifications_list_tooltip_walletView => 'Vue portefeuille';

  @override
  String get certifications_picker_clearTooltip =>
      'Effacer la selection de certification';

  @override
  String get certifications_picker_empty_addButton =>
      'Ajouter une certification';

  @override
  String get certifications_picker_empty_title => 'Aucune certification';

  @override
  String certifications_picker_error(Object error) {
    return 'Erreur lors du chargement des certifications : $error';
  }

  @override
  String get certifications_picker_expired => 'Expiree';

  @override
  String get certifications_picker_hint =>
      'Appuie pour associer a une certification obtenue';

  @override
  String get certifications_picker_newCert => 'Nouvelle cert.';

  @override
  String get certifications_picker_noSelection =>
      'Aucune certification selectionnee';

  @override
  String get certifications_picker_sheetTitle => 'Associer a une certification';

  @override
  String get certifications_renderer_footer => 'Carnet de plongee Submersion';

  @override
  String certifications_renderer_label_cardNumber(Object number) {
    return 'N de carte : $number';
  }

  @override
  String get certifications_renderer_label_hasCompletedTraining =>
      'a termine la formation en tant que';

  @override
  String certifications_renderer_label_instructor(Object name) {
    return 'Instructeur : $name';
  }

  @override
  String certifications_renderer_label_instructorWithNumber(
    Object name,
    Object number,
  ) {
    return 'Instructeur : $name ($number)';
  }

  @override
  String certifications_renderer_label_issued(Object date) {
    return 'Delivree le : $date';
  }

  @override
  String get certifications_renderer_label_thisCertifies => 'Ceci certifie que';

  @override
  String get certifications_search_empty_hint =>
      'Rechercher par nom, organisme ou numero de carte';

  @override
  String get certifications_search_fieldLabel =>
      'Rechercher des certifications...';

  @override
  String certifications_search_noResults(Object query) {
    return 'Aucune certification trouvee pour \"$query\"';
  }

  @override
  String get certifications_search_tooltip_back => 'Retour';

  @override
  String get certifications_search_tooltip_clear => 'Effacer la recherche';

  @override
  String certifications_share_error_card(Object error) {
    return 'Echec du partage de la carte : $error';
  }

  @override
  String certifications_share_error_certificate(Object error) {
    return 'Echec du partage du certificat : $error';
  }

  @override
  String get certifications_share_option_card_subtitle =>
      'Image de certification au format carte de credit';

  @override
  String get certifications_share_option_card_title => 'Partager en carte';

  @override
  String get certifications_share_option_certificate_subtitle =>
      'Document de certificat officiel';

  @override
  String get certifications_share_option_certificate_title =>
      'Partager en certificat';

  @override
  String get certifications_share_title => 'Partager la certification';

  @override
  String get certifications_summary_header_subtitle =>
      'Selectionnez une certification dans la liste pour voir les details';

  @override
  String get certifications_summary_header_title => 'Certifications';

  @override
  String get certifications_summary_overview_title => 'Apercu';

  @override
  String get certifications_summary_quickActions_add =>
      'Ajouter une certification';

  @override
  String get certifications_summary_quickActions_title => 'Actions rapides';

  @override
  String get certifications_summary_recentTitle => 'Certifications recentes';

  @override
  String get certifications_summary_stat_expired => 'Expirees';

  @override
  String get certifications_summary_stat_expiringSoon => 'Expirent bientot';

  @override
  String get certifications_summary_stat_total => 'Total';

  @override
  String get certifications_summary_stat_valid => 'Valides';

  @override
  String certifications_walletCard_countPlural(Object count) {
    return '$count certifications';
  }

  @override
  String certifications_walletCard_countSingular(Object count) {
    return '$count certification';
  }

  @override
  String get certifications_walletCard_emptyFooter =>
      'Ajoutez votre premiere certification';

  @override
  String get certifications_walletCard_error =>
      'Echec du chargement des certifications';

  @override
  String get certifications_walletCard_semanticLabel =>
      'Portefeuille de certifications. Appuyez pour voir toutes les certifications';

  @override
  String get certifications_walletCard_tapToAdd => 'Appuie pour ajouter';

  @override
  String get certifications_walletCard_title =>
      'Portefeuille de certifications';

  @override
  String get certifications_wallet_appBar_title =>
      'Portefeuille de certifications';

  @override
  String get certifications_wallet_error_retry => 'Reessayer';

  @override
  String get certifications_wallet_error_title =>
      'Echec du chargement des certifications';

  @override
  String get certifications_wallet_options_edit => 'Modifier';

  @override
  String get certifications_wallet_options_share => 'Partager';

  @override
  String get certifications_wallet_options_viewDetails => 'Voir les details';

  @override
  String get certifications_wallet_tooltip_add => 'Ajouter une certification';

  @override
  String get certifications_wallet_tooltip_share => 'Partager la certification';

  @override
  String get common_action_back => 'Retour';

  @override
  String get common_action_cancel => 'Annuler';

  @override
  String get common_action_close => 'Fermer';

  @override
  String get common_action_delete => 'Supprimer';

  @override
  String get common_action_edit => 'Modifier';

  @override
  String get common_action_ok => 'OK';

  @override
  String get common_action_save => 'Enregistrer';

  @override
  String get common_action_search => 'Rechercher';

  @override
  String get common_label_error => 'Erreur';

  @override
  String get common_label_loading => 'Chargement';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get courses_action_add => 'Ajouter un cours';

  @override
  String get courses_action_create => 'Créer un cours';

  @override
  String get courses_action_edit => 'Modifier le cours';

  @override
  String get courses_action_exportTrainingLog =>
      'Exporter le carnet de formation';

  @override
  String get courses_action_markCompleted => 'Marquer comme terminé';

  @override
  String get courses_action_moreOptions => 'Plus d\'options';

  @override
  String get courses_action_retry => 'Réessayer';

  @override
  String get courses_action_saveChanges => 'Enregistrer les modifications';

  @override
  String get courses_action_saveSemantic => 'Enregistrer le cours';

  @override
  String get courses_action_sort => 'Trier';

  @override
  String get courses_action_sortTitle => 'Trier les cours';

  @override
  String courses_card_instructor(Object name) {
    return 'Instructeur : $name';
  }

  @override
  String courses_card_started(Object date) {
    return 'Commencé le $date';
  }

  @override
  String get courses_detail_certificationNotFound =>
      'Certification introuvable';

  @override
  String get courses_detail_noTrainingDives =>
      'Aucune plongée de formation associée pour le moment';

  @override
  String get courses_detail_notFound => 'Cours introuvable';

  @override
  String get courses_dialog_complete => 'Terminer';

  @override
  String courses_dialog_deleteMessage(Object name) {
    return 'Voulez-vous vraiment supprimer $name ? Cette action est irréversible.';
  }

  @override
  String get courses_dialog_deleteTitle => 'Supprimer le cours ?';

  @override
  String get courses_dialog_markCompletedMessage =>
      'Ceci marquera le cours comme terminé à la date d\'aujourd\'hui. Continuer ?';

  @override
  String get courses_dialog_markCompletedTitle => 'Marquer comme terminé ?';

  @override
  String get courses_empty_noCompleted => 'Aucun cours terminé';

  @override
  String get courses_empty_noInProgress => 'Aucun cours en cours';

  @override
  String get courses_empty_subtitle =>
      'Ajoutez votre premier cours pour commencer';

  @override
  String get courses_empty_title => 'Aucun cours de formation pour le moment';

  @override
  String courses_error_generic(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get courses_error_loadingCertification =>
      'Erreur lors du chargement de la certification';

  @override
  String get courses_error_loadingDives =>
      'Erreur lors du chargement des plongées';

  @override
  String get courses_field_courseName => 'Nom du cours';

  @override
  String get courses_field_courseNameHint => 'ex. Open Water Diver';

  @override
  String get courses_field_instructorName => 'Nom de l\'instructeur';

  @override
  String get courses_field_instructorNumber => 'Numéro d\'instructeur';

  @override
  String get courses_field_linkCertificationHint =>
      'Associer une certification obtenue lors de ce cours';

  @override
  String get courses_field_location => 'Lieu';

  @override
  String get courses_field_notes => 'Notes';

  @override
  String get courses_field_selectFromBuddies =>
      'Sélectionner parmi les binômes (facultatif)';

  @override
  String get courses_filter_all => 'Tous';

  @override
  String get courses_label_agency => 'Organisme';

  @override
  String get courses_label_completed => 'Terminé';

  @override
  String get courses_label_completionDate => 'Date de fin';

  @override
  String get courses_label_courseInProgress => 'Cours en cours';

  @override
  String get courses_label_instructorNumber => 'N° instructeur';

  @override
  String get courses_label_location => 'Lieu';

  @override
  String get courses_label_name => 'Nom';

  @override
  String get courses_label_none => '-- Aucun --';

  @override
  String get courses_label_startDate => 'Date de début';

  @override
  String courses_message_errorSaving(Object error) {
    return 'Erreur lors de l\'enregistrement du cours : $error';
  }

  @override
  String courses_message_exportFailed(Object error) {
    return 'Échec de l\'export du carnet de formation : $error';
  }

  @override
  String get courses_picker_active => 'Actif';

  @override
  String get courses_picker_clearSelection => 'Effacer la sélection';

  @override
  String get courses_picker_createCourse => 'Créer un cours';

  @override
  String courses_picker_errorLoading(Object error) {
    return 'Erreur lors du chargement des cours : $error';
  }

  @override
  String get courses_picker_newCourse => 'Nouveau cours';

  @override
  String get courses_picker_noCourses => 'Aucun cours pour le moment';

  @override
  String get courses_picker_noneSelected => 'Aucun cours sélectionné';

  @override
  String get courses_picker_selectTitle => 'Sélectionner un cours de formation';

  @override
  String get courses_picker_selected => 'sélectionné';

  @override
  String get courses_picker_tapToLink =>
      'Appuyez pour associer à un cours de formation';

  @override
  String get courses_section_details => 'Détails du cours';

  @override
  String get courses_section_earnedCertification => 'Certification obtenue';

  @override
  String get courses_section_instructor => 'Instructeur';

  @override
  String get courses_section_notes => 'Notes';

  @override
  String get courses_section_trainingDives => 'Plongées de formation';

  @override
  String get courses_status_completed => 'Terminé';

  @override
  String courses_status_daysSinceStart(Object days) {
    return '$days jours depuis le début';
  }

  @override
  String courses_status_durationDays(Object days) {
    return '$days jours';
  }

  @override
  String get courses_status_inProgress => 'En cours';

  @override
  String courses_status_semanticLabel(Object status, Object duration) {
    return '$status, $duration';
  }

  @override
  String get courses_summary_overview => 'Vue d\'ensemble';

  @override
  String get courses_summary_quickActions => 'Actions rapides';

  @override
  String get courses_summary_recentCourses => 'Cours récents';

  @override
  String get courses_summary_selectHint =>
      'Sélectionnez un cours dans la liste pour afficher les détails';

  @override
  String get courses_summary_title => 'Cours de formation';

  @override
  String get courses_summary_total => 'Total';

  @override
  String get courses_title => 'Cours de formation';

  @override
  String get courses_title_edit => 'Modifier le cours';

  @override
  String get courses_title_new => 'Nouveau cours';

  @override
  String get courses_title_singular => 'Cours';

  @override
  String get courses_validation_nameRequired =>
      'Veuillez entrer un nom de cours';

  @override
  String get dashboard_activity_daySinceDiving =>
      'Jour depuis la derniere plongee';

  @override
  String get dashboard_activity_daysSinceDiving =>
      'Jours depuis la derniere plongee';

  @override
  String dashboard_activity_diveInYear(Object year) {
    return 'Plongee en $year';
  }

  @override
  String get dashboard_activity_diveThisMonth => 'Plongee ce mois-ci';

  @override
  String dashboard_activity_divesInYear(Object year) {
    return 'Plongees en $year';
  }

  @override
  String get dashboard_activity_divesThisMonth => 'Plongees ce mois-ci';

  @override
  String get dashboard_activity_error => 'Erreur';

  @override
  String get dashboard_activity_lastDive => 'Derniere plongee';

  @override
  String get dashboard_activity_loading => 'Chargement';

  @override
  String get dashboard_activity_noDivesYet => 'Aucune plongee pour le moment';

  @override
  String get dashboard_activity_today => 'Aujourd\'hui !';

  @override
  String get dashboard_alerts_actionUpdate => 'Mettre a jour';

  @override
  String get dashboard_alerts_actionView => 'Voir';

  @override
  String get dashboard_alerts_checkInsuranceExpiry =>
      'Verifiez la date d\'expiration de votre assurance';

  @override
  String get dashboard_alerts_daysOverdueOne => '1 jour de retard';

  @override
  String dashboard_alerts_daysOverdueOther(Object count) {
    return '$count jours de retard';
  }

  @override
  String get dashboard_alerts_dueInDaysOne => 'Dans 1 jour';

  @override
  String dashboard_alerts_dueInDaysOther(Object count) {
    return 'Dans $count jours';
  }

  @override
  String dashboard_alerts_equipmentServiceDue(Object name) {
    return 'Revision de $name a prevoir';
  }

  @override
  String dashboard_alerts_equipmentServiceOverdue(Object name) {
    return 'Revision de $name en retard';
  }

  @override
  String get dashboard_alerts_insuranceExpired => 'Assurance expiree';

  @override
  String get dashboard_alerts_insuranceExpiredGeneric =>
      'Ton assurance plongee a expire';

  @override
  String dashboard_alerts_insuranceExpiredProvider(Object provider) {
    return '$provider expiree';
  }

  @override
  String dashboard_alerts_insuranceExpiresDate(Object date) {
    return 'Expire le $date';
  }

  @override
  String get dashboard_alerts_insuranceExpiringSoon =>
      'Assurance bientot expiree';

  @override
  String get dashboard_alerts_sectionTitle => 'Alertes et rappels';

  @override
  String get dashboard_alerts_serviceDueToday => 'Revision prevue aujourd\'hui';

  @override
  String get dashboard_alerts_serviceIntervalReached =>
      'Intervalle de revision atteint';

  @override
  String get dashboard_defaultDiverName => 'Plongeur';

  @override
  String get dashboard_greeting_afternoon => 'Bon apres-midi';

  @override
  String get dashboard_greeting_evening => 'Bonsoir';

  @override
  String get dashboard_greeting_morning => 'Bonjour';

  @override
  String dashboard_greeting_withName(Object greeting, Object name) {
    return '$greeting, $name !';
  }

  @override
  String dashboard_greeting_withoutName(Object greeting) {
    return '$greeting !';
  }

  @override
  String get dashboard_hero_divesLoggedOne => '1 plongee enregistree';

  @override
  String dashboard_hero_divesLoggedOther(Object count) {
    return '$count plongees enregistrees';
  }

  @override
  String get dashboard_hero_error => 'Pret a explorer les profondeurs ?';

  @override
  String dashboard_hero_hoursUnderwater(Object hours) {
    return '$hours heures sous l\'eau';
  }

  @override
  String get dashboard_hero_loading =>
      'Chargement de tes statistiques de plongee...';

  @override
  String dashboard_hero_minutesUnderwater(Object minutes) {
    return '$minutes minutes sous l\'eau';
  }

  @override
  String get dashboard_hero_noDives =>
      'Pret a enregistrer ta premiere plongee ?';

  @override
  String get dashboard_personalRecords_coldest => 'La plus froide';

  @override
  String get dashboard_personalRecords_deepest => 'La plus profonde';

  @override
  String get dashboard_personalRecords_longest => 'La plus longue';

  @override
  String get dashboard_personalRecords_sectionTitle => 'Records personnels';

  @override
  String get dashboard_personalRecords_warmest => 'La plus chaude';

  @override
  String get dashboard_quickActions_addSite => 'Ajouter un site';

  @override
  String get dashboard_quickActions_addSiteTooltip =>
      'Ajouter un nouveau site de plongee';

  @override
  String get dashboard_quickActions_logDive => 'Enregistrer';

  @override
  String get dashboard_quickActions_logDiveTooltip =>
      'Enregistrer une nouvelle plongee';

  @override
  String get dashboard_quickActions_planDive => 'Planifier';

  @override
  String get dashboard_quickActions_planDiveTooltip =>
      'Planifier une nouvelle plongee';

  @override
  String get dashboard_quickActions_sectionTitle => 'Actions rapides';

  @override
  String get dashboard_quickActions_statistics => 'Statistiques';

  @override
  String get dashboard_quickActions_statisticsTooltip =>
      'Voir les statistiques de plongee';

  @override
  String get dashboard_quickStats_countries => 'Pays';

  @override
  String get dashboard_quickStats_countriesSubtitle => 'visites';

  @override
  String get dashboard_quickStats_sectionTitle => 'En un coup d\'oeil';

  @override
  String get dashboard_quickStats_species => 'Especes';

  @override
  String get dashboard_quickStats_speciesSubtitle => 'decouvertes';

  @override
  String get dashboard_quickStats_topBuddy => 'Binome prefere';

  @override
  String dashboard_quickStats_topBuddyDives(Object count) {
    return '$count plongees';
  }

  @override
  String get dashboard_recentDives_empty => 'Aucune plongee enregistree';

  @override
  String get dashboard_recentDives_errorLoading =>
      'Impossible de charger les plongees';

  @override
  String get dashboard_recentDives_logFirst => 'Enregistre ta premiere plongee';

  @override
  String get dashboard_recentDives_sectionTitle => 'Plongees recentes';

  @override
  String get dashboard_recentDives_viewAll => 'Tout voir';

  @override
  String get dashboard_recentDives_viewAllTooltip => 'Voir toutes les plongees';

  @override
  String dashboard_semantics_activeAlerts(Object count) {
    return '$count alertes actives';
  }

  @override
  String get dashboard_semantics_errorLoadingRecentDives =>
      'Erreur : impossible de charger les plongees recentes';

  @override
  String get dashboard_semantics_errorLoadingStatistics =>
      'Erreur : impossible de charger les statistiques';

  @override
  String get dashboard_semantics_greetingBanner =>
      'Banniere d\'accueil du tableau de bord';

  @override
  String get dashboard_stats_errorLoadingStatistics =>
      'Impossible de charger les statistiques';

  @override
  String get dashboard_stats_hoursLogged => 'Heures enregistrees';

  @override
  String get dashboard_stats_maxDepth => 'Profondeur max';

  @override
  String get dashboard_stats_sitesVisited => 'Sites visites';

  @override
  String get dashboard_stats_totalDives => 'Total des plongees';

  @override
  String get decoCalculator_addToPlanner => 'Ajouter au planificateur';

  @override
  String decoCalculator_bottomTimeSemantics(Object time) {
    return 'Temps au fond : $time minutes';
  }

  @override
  String get decoCalculator_createPlanTooltip =>
      'Créer un plan de plongée à partir des paramètres actuels';

  @override
  String decoCalculator_createdPlanSnackbar(
    Object depth,
    Object depthSymbol,
    Object time,
    Object gasMixName,
  ) {
    return 'Plan créé : $depth$depthSymbol pendant ${time}min sur $gasMixName';
  }

  @override
  String get decoCalculator_customMixTrimix => 'Mélange personnalisé (Trimix)';

  @override
  String decoCalculator_depthSemantics(Object depth, Object depthSymbol) {
    return 'Profondeur : $depth $depthSymbol';
  }

  @override
  String get decoCalculator_diveParameters => 'Paramètres de plongée';

  @override
  String get decoCalculator_endCaution => 'Attention';

  @override
  String get decoCalculator_endDanger => 'Danger';

  @override
  String get decoCalculator_endSafe => 'Sûr';

  @override
  String get decoCalculator_field_bottomTime => 'Temps au fond';

  @override
  String get decoCalculator_field_depth => 'Profondeur';

  @override
  String get decoCalculator_field_gasMix => 'Mélange gazeux';

  @override
  String get decoCalculator_gasSafety => 'Sécurité du gaz';

  @override
  String get decoCalculator_hideCustomMix => 'Masquer le mélange personnalisé';

  @override
  String get decoCalculator_hideCustomMixSemantics =>
      'Masquer le sélecteur de mélange gazeux personnalisé';

  @override
  String get decoCalculator_modExceeded => 'MOD dépassée';

  @override
  String get decoCalculator_modSafe => 'MOD sûre';

  @override
  String get decoCalculator_ppO2Caution => 'ppO2 attention';

  @override
  String get decoCalculator_ppO2Danger => 'ppO2 danger';

  @override
  String get decoCalculator_ppO2Hypoxic => 'ppO2 hypoxique';

  @override
  String get decoCalculator_ppO2Safe => 'ppO2 sûr';

  @override
  String get decoCalculator_resetToDefaults =>
      'Réinitialiser aux valeurs par défaut';

  @override
  String get decoCalculator_showCustomMixSemantics =>
      'Afficher le sélecteur de mélange gazeux personnalisé';

  @override
  String decoCalculator_timeValueMin(Object time) {
    return '$time min';
  }

  @override
  String get decoCalculator_title => 'Calculateur de décompression';

  @override
  String diveCenters_accessibility_markerLabel(Object name) {
    return 'Centre de plongée : $name';
  }

  @override
  String get diveCenters_accessibility_selected => 'sélectionné';

  @override
  String diveCenters_accessibility_viewDetails(Object name) {
    return 'Afficher les détails de $name';
  }

  @override
  String get diveCenters_accessibility_viewDives =>
      'Voir les plongées avec ce centre';

  @override
  String get diveCenters_accessibility_viewFullscreenMap =>
      'Voir la carte en plein écran';

  @override
  String diveCenters_accessibility_viewSavedCenter(Object name) {
    return 'Voir le centre de plongée enregistré $name';
  }

  @override
  String get diveCenters_action_addCenter => 'Ajouter un centre';

  @override
  String get diveCenters_action_addNew => 'Ajouter';

  @override
  String get diveCenters_action_clearRating => 'Effacer';

  @override
  String get diveCenters_action_gettingLocation => 'Récupération...';

  @override
  String get diveCenters_action_import => 'Importer';

  @override
  String get diveCenters_action_importToMyCenters =>
      'Importer dans mes centres';

  @override
  String get diveCenters_action_lookingUp => 'Recherche...';

  @override
  String get diveCenters_action_lookupFromAddress =>
      'Rechercher depuis l\'adresse';

  @override
  String get diveCenters_action_pickFromMap => 'Choisir sur la carte';

  @override
  String get diveCenters_action_retry => 'Réessayer';

  @override
  String get diveCenters_action_settings => 'Paramètres';

  @override
  String get diveCenters_action_useMyLocation => 'Utiliser ma position';

  @override
  String get diveCenters_action_view => 'Voir';

  @override
  String diveCenters_detail_divesLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongées enregistrées',
      one: '1 plongée enregistrée',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_detail_divesWithCenter => 'Plongées avec ce centre';

  @override
  String get diveCenters_detail_noDivesLogged =>
      'Aucune plongée enregistrée pour le moment';

  @override
  String diveCenters_dialog_deleteMessage(Object name) {
    return 'Voulez-vous vraiment supprimer « $name » ?';
  }

  @override
  String get diveCenters_dialog_deleteTitle => 'Supprimer le centre de plongée';

  @override
  String get diveCenters_dialog_discard => 'Abandonner';

  @override
  String get diveCenters_dialog_discardMessage =>
      'Vous avez des modifications non enregistrées. Voulez-vous vraiment les abandonner ?';

  @override
  String get diveCenters_dialog_discardTitle =>
      'Abandonner les modifications ?';

  @override
  String get diveCenters_dialog_keepEditing => 'Continuer à modifier';

  @override
  String get diveCenters_empty_subtitle =>
      'Ajoutez vos boutiques de plongée et opérateurs préférés';

  @override
  String get diveCenters_empty_title =>
      'Aucun centre de plongée pour le moment';

  @override
  String diveCenters_error_generic(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get diveCenters_error_geocodeFailed =>
      'Impossible de trouver les coordonnées pour cette adresse';

  @override
  String get diveCenters_error_importFailed =>
      'Échec de l\'import du centre de plongée';

  @override
  String diveCenters_error_loading(Object error) {
    return 'Erreur lors du chargement des centres de plongée : $error';
  }

  @override
  String get diveCenters_error_locationPermission =>
      'Impossible d\'obtenir la position. Veuillez vérifier les autorisations.';

  @override
  String get diveCenters_error_locationUnavailable =>
      'Impossible d\'obtenir la position. Les services de localisation peuvent ne pas être disponibles.';

  @override
  String get diveCenters_error_noAddressForLookup =>
      'Veuillez entrer une adresse pour rechercher les coordonnées';

  @override
  String get diveCenters_error_notFound => 'Centre de plongée introuvable';

  @override
  String diveCenters_error_saving(Object error) {
    return 'Erreur lors de l\'enregistrement du centre de plongée : $error';
  }

  @override
  String get diveCenters_error_unknown => 'Erreur inconnue';

  @override
  String get diveCenters_field_city => 'Ville';

  @override
  String get diveCenters_field_country => 'Pays';

  @override
  String get diveCenters_field_latitude => 'Latitude';

  @override
  String get diveCenters_field_longitude => 'Longitude';

  @override
  String get diveCenters_field_nameRequired => 'Nom *';

  @override
  String get diveCenters_field_postalCode => 'Code postal';

  @override
  String get diveCenters_field_rating => 'Évaluation';

  @override
  String get diveCenters_field_stateProvince => 'État/Province';

  @override
  String get diveCenters_field_street => 'Adresse';

  @override
  String get diveCenters_hint_addressDescription =>
      'Adresse facultative pour la navigation';

  @override
  String get diveCenters_hint_affiliationsDescription =>
      'Sélectionnez les organismes de formation auxquels ce centre est affilié';

  @override
  String get diveCenters_hint_city => 'ex. Marseille';

  @override
  String get diveCenters_hint_country => 'ex. France';

  @override
  String get diveCenters_hint_email => 'info@centredeplongee.com';

  @override
  String get diveCenters_hint_gpsDescription =>
      'Choisissez une méthode de localisation ou entrez les coordonnées manuellement';

  @override
  String get diveCenters_hint_importSearch =>
      'Rechercher des centres de plongée (ex. « PADI », « Thaïlande »)';

  @override
  String get diveCenters_hint_latitude => 'ex. 43.2965';

  @override
  String get diveCenters_hint_longitude => 'ex. 5.3698';

  @override
  String get diveCenters_hint_name => 'Entrer le nom du centre de plongée';

  @override
  String get diveCenters_hint_notes => 'Toute information complémentaire...';

  @override
  String get diveCenters_hint_phone => '+33 4 91 12 34 56';

  @override
  String get diveCenters_hint_postalCode => 'ex. 13008';

  @override
  String get diveCenters_hint_stateProvince => 'ex. Bouches-du-Rhône';

  @override
  String get diveCenters_hint_street => 'ex. 123 Rue de la Corniche';

  @override
  String get diveCenters_hint_website => 'www.centredeplongee.com';

  @override
  String diveCenters_import_fromDatabase(Object count) {
    return 'Importer depuis la base de données ($count)';
  }

  @override
  String diveCenters_import_myCenters(Object count) {
    return 'Mes centres ($count)';
  }

  @override
  String get diveCenters_import_noResults => 'Aucun résultat';

  @override
  String diveCenters_import_noResultsMessage(Object query) {
    return 'Aucun centre de plongée trouvé pour « $query ». Essayez un autre terme de recherche.';
  }

  @override
  String get diveCenters_import_searchDescription =>
      'Recherchez des centres de plongée, boutiques et clubs dans notre base de données d\'opérateurs du monde entier.';

  @override
  String get diveCenters_import_searchError => 'Erreur de recherche';

  @override
  String get diveCenters_import_searchHint =>
      'Essayez de rechercher par nom, pays ou organisme de certification.';

  @override
  String get diveCenters_import_searchTitle =>
      'Rechercher des centres de plongée';

  @override
  String get diveCenters_label_alreadyImported => 'Déjà importé';

  @override
  String diveCenters_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongées',
      one: '1 plongée',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_label_email => 'E-mail';

  @override
  String get diveCenters_label_imported => 'Importé';

  @override
  String get diveCenters_label_locationNotSet => 'Position non définie';

  @override
  String get diveCenters_label_locationUnknown => 'Position inconnue';

  @override
  String get diveCenters_label_phone => 'Téléphone';

  @override
  String get diveCenters_label_saved => 'Enregistré';

  @override
  String diveCenters_label_source(Object source) {
    return 'Source : $source';
  }

  @override
  String get diveCenters_label_website => 'Site web';

  @override
  String get diveCenters_map_addCoordinatesHint =>
      'Ajoutez des coordonnées à vos centres de plongée pour les voir sur la carte';

  @override
  String get diveCenters_map_noCoordinates =>
      'Aucun centre de plongée avec coordonnées';

  @override
  String get diveCenters_picker_newCenter => 'Nouveau centre de plongée';

  @override
  String get diveCenters_picker_title => 'Sélectionner un centre de plongée';

  @override
  String diveCenters_search_noResults(Object query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get diveCenters_search_prompt => 'Rechercher des centres de plongée';

  @override
  String get diveCenters_section_address => 'Adresse';

  @override
  String get diveCenters_section_affiliations => 'Affiliations';

  @override
  String get diveCenters_section_basicInfo => 'Informations de base';

  @override
  String get diveCenters_section_contact => 'Contact';

  @override
  String get diveCenters_section_contactInfo => 'Informations de contact';

  @override
  String get diveCenters_section_gpsCoordinates => 'Coordonnées GPS';

  @override
  String get diveCenters_section_notes => 'Notes';

  @override
  String get diveCenters_snackbar_coordinatesFound =>
      'Coordonnées trouvées depuis l\'adresse';

  @override
  String get diveCenters_snackbar_copiedToClipboard =>
      'Copié dans le presse-papiers';

  @override
  String diveCenters_snackbar_imported(Object name) {
    return '« $name » importé';
  }

  @override
  String get diveCenters_snackbar_locationCaptured => 'Position capturée';

  @override
  String diveCenters_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Position capturée (±${accuracy}m)';
  }

  @override
  String get diveCenters_snackbar_locationSelectedFromMap =>
      'Position sélectionnée depuis la carte';

  @override
  String get diveCenters_sort_title => 'Trier les centres de plongée';

  @override
  String get diveCenters_summary_countries => 'Pays';

  @override
  String get diveCenters_summary_highestRating => 'Meilleure évaluation';

  @override
  String get diveCenters_summary_overview => 'Vue d\'ensemble';

  @override
  String get diveCenters_summary_quickActions => 'Actions rapides';

  @override
  String get diveCenters_summary_recentCenters => 'Centres récents';

  @override
  String get diveCenters_summary_selectPrompt =>
      'Sélectionnez un centre de plongée dans la liste pour afficher les détails';

  @override
  String get diveCenters_summary_topRated => 'Mieux notés';

  @override
  String get diveCenters_summary_totalCenters => 'Total centres';

  @override
  String get diveCenters_summary_withGps => 'Avec GPS';

  @override
  String get diveCenters_title => 'Centres de plongée';

  @override
  String get diveCenters_title_add => 'Ajouter un centre de plongée';

  @override
  String get diveCenters_title_edit => 'Modifier le centre de plongée';

  @override
  String get diveCenters_title_import => 'Importer un centre de plongée';

  @override
  String get diveCenters_tooltip_addNew =>
      'Ajouter un nouveau centre de plongée';

  @override
  String get diveCenters_tooltip_clearSearch => 'Effacer la recherche';

  @override
  String get diveCenters_tooltip_edit => 'Modifier le centre de plongée';

  @override
  String get diveCenters_tooltip_fitAllCenters => 'Ajuster tous les centres';

  @override
  String get diveCenters_tooltip_listView => 'Vue liste';

  @override
  String get diveCenters_tooltip_mapView => 'Vue carte';

  @override
  String get diveCenters_tooltip_moreOptions => 'Plus d\'options';

  @override
  String get diveCenters_tooltip_search => 'Rechercher des centres de plongée';

  @override
  String get diveCenters_tooltip_sort => 'Trier';

  @override
  String get diveCenters_validation_invalidEmail =>
      'Veuillez entrer une adresse e-mail valide';

  @override
  String get diveCenters_validation_invalidLatitude => 'Latitude invalide';

  @override
  String get diveCenters_validation_invalidLongitude => 'Longitude invalide';

  @override
  String get diveCenters_validation_nameRequired => 'Le nom est requis';

  @override
  String get diveComputer_action_setFavorite => 'Définir comme favori';

  @override
  String diveComputer_error_generic(Object error) {
    return 'Une erreur s\'est produite : $error';
  }

  @override
  String get diveComputer_error_notFound => 'Appareil introuvable';

  @override
  String get diveComputer_status_favorite => 'Ordinateur favori';

  @override
  String get diveComputer_title => 'Ordinateur de plongée';

  @override
  String diveLog_bulkDelete_confirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongees',
      one: 'plongee',
    );
    return 'Es-tu sur de vouloir supprimer $count $_temp0 ? Cette action est irreversible.';
  }

  @override
  String get diveLog_bulkDelete_restored => 'Plongees restaurees';

  @override
  String diveLog_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongees supprimees',
      one: 'plongee supprimee',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_bulkDelete_title => 'Supprimer des plongees';

  @override
  String get diveLog_bulkDelete_undo => 'Annuler';

  @override
  String get diveLog_bulkEdit_addTags => 'Ajouter des tags';

  @override
  String get diveLog_bulkEdit_addTagsDescription =>
      'Ajouter des tags aux plongees selectionnees';

  @override
  String diveLog_bulkEdit_addedTags(int tagCount, int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      tagCount,
      locale: localeName,
      other: 'tags ajoutes',
      one: 'tag ajoute',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'plongees',
      one: 'plongee',
    );
    return '$tagCount $_temp0 a $diveCount $_temp1';
  }

  @override
  String get diveLog_bulkEdit_changeTrip => 'Changer de voyage';

  @override
  String get diveLog_bulkEdit_changeTripDescription =>
      'Deplacer les plongees selectionnees vers un voyage';

  @override
  String get diveLog_bulkEdit_errorLoadingTrips =>
      'Erreur lors du chargement des voyages';

  @override
  String diveLog_bulkEdit_failedAddTags(Object error) {
    return 'Impossible d\'ajouter les tags : $error';
  }

  @override
  String diveLog_bulkEdit_failedUpdateTrip(Object error) {
    return 'Impossible de mettre a jour le voyage : $error';
  }

  @override
  String diveLog_bulkEdit_movedToTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongees deplacees',
      one: 'plongee deplacee',
    );
    return '$count $_temp0 vers le voyage';
  }

  @override
  String get diveLog_bulkEdit_noTagsAvailable => 'Aucun tag disponible.';

  @override
  String get diveLog_bulkEdit_noTagsAvailableCreate =>
      'Aucun tag disponible. Cree d\'abord des tags.';

  @override
  String get diveLog_bulkEdit_noTrip => 'Aucun voyage';

  @override
  String get diveLog_bulkEdit_removeFromTrip => 'Retirer du voyage';

  @override
  String get diveLog_bulkEdit_removeTags => 'Retirer des tags';

  @override
  String get diveLog_bulkEdit_removeTagsDescription =>
      'Retirer des tags des plongees selectionnees';

  @override
  String diveLog_bulkEdit_removedFromTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongees retirees',
      one: 'plongee retiree',
    );
    return '$count $_temp0 du voyage';
  }

  @override
  String get diveLog_bulkEdit_selectTrip => 'Selectionner un voyage';

  @override
  String diveLog_bulkEdit_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongees',
      one: 'plongee',
    );
    return 'Modifier $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_csv => 'CSV';

  @override
  String get diveLog_bulkExport_csvDescription => 'Format tableur';

  @override
  String diveLog_bulkExport_failed(Object error) {
    return 'Echec de l\'export : $error';
  }

  @override
  String get diveLog_bulkExport_pdf => 'Carnet PDF';

  @override
  String get diveLog_bulkExport_pdfDescription =>
      'Pages de carnet de plongee imprimables';

  @override
  String diveLog_bulkExport_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongees exportees',
      one: 'plongee exportee',
    );
    return '$count $_temp0 avec succes';
  }

  @override
  String diveLog_bulkExport_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongees',
      one: 'plongee',
    );
    return 'Exporter $count $_temp0';
  }

  @override
  String get diveLog_bulkExport_uddf => 'UDDF';

  @override
  String get diveLog_bulkExport_uddfDescription =>
      'Format universel de donnees de plongee';

  @override
  String get diveLog_ccr_diluent_air => 'Air';

  @override
  String get diveLog_ccr_hint_loopVolume => 'ex. 6,0';

  @override
  String get diveLog_ccr_hint_type => 'ex. Sofnolime';

  @override
  String get diveLog_ccr_label_deco => 'Deco';

  @override
  String get diveLog_ccr_label_he => 'He';

  @override
  String get diveLog_ccr_label_highBottom => 'Haute (fond)';

  @override
  String get diveLog_ccr_label_loopVolume => 'Volume de boucle';

  @override
  String get diveLog_ccr_label_lowDescAsc => 'Basse (desc/rem)';

  @override
  String get diveLog_ccr_label_n2 => 'N₂';

  @override
  String get diveLog_ccr_label_o2 => 'O₂';

  @override
  String get diveLog_ccr_label_rated => 'Nominal';

  @override
  String get diveLog_ccr_label_remaining => 'Restant';

  @override
  String get diveLog_ccr_label_type => 'Type';

  @override
  String get diveLog_ccr_sectionDiluentGas => 'Gaz diluant';

  @override
  String get diveLog_ccr_sectionScrubber => 'Chaux';

  @override
  String get diveLog_ccr_sectionSetpoints => 'Consignes (bar)';

  @override
  String get diveLog_ccr_title => 'Reglages CCR';

  @override
  String diveLog_collapsible_semantics_collapse(Object title) {
    return 'Reduire la section $title';
  }

  @override
  String diveLog_collapsible_semantics_expand(Object title) {
    return 'Developper la section $title';
  }

  @override
  String diveLog_cylinderSac_avgDepth(Object depth) {
    return 'Moy : $depth';
  }

  @override
  String get diveLog_cylinderSac_badge_ai => 'AI';

  @override
  String get diveLog_cylinderSac_badge_basic => 'Base';

  @override
  String get diveLog_cylinderSac_noSac => 'SAC : --';

  @override
  String get diveLog_cylinderSac_tooltip_aiData =>
      'Donnees du transmetteur AI pour une meilleure precision';

  @override
  String get diveLog_cylinderSac_tooltip_basicData =>
      'Calcule a partir des pressions de debut et de fin';

  @override
  String get diveLog_deco_badge_deco => 'DECO';

  @override
  String get diveLog_deco_badge_noDeco => 'SANS PALIER';

  @override
  String get diveLog_deco_label_ceiling => 'Plafond';

  @override
  String get diveLog_deco_label_leading => 'Dominant';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String get diveLog_deco_sectionDecoStops => 'Paliers de decompression';

  @override
  String get diveLog_deco_sectionTissueLoading => 'Saturation des tissus';

  @override
  String get diveLog_deco_semantics_notRequired =>
      'Pas de decompression requise';

  @override
  String get diveLog_deco_semantics_required => 'Decompression requise';

  @override
  String get diveLog_deco_tissueFast => 'Rapide';

  @override
  String get diveLog_deco_tissueSlow => 'Lent';

  @override
  String get diveLog_deco_title => 'Statut de decompression';

  @override
  String diveLog_deco_totalDecoTime(Object time) {
    return 'Total : $time';
  }

  @override
  String get diveLog_delete_cancel => 'Annuler';

  @override
  String get diveLog_delete_confirm =>
      'Cette action est irreversible. La plongee et toutes les donnees associees (profil, blocs, observations) seront definitivement supprimees.';

  @override
  String get diveLog_delete_delete => 'Supprimer';

  @override
  String get diveLog_delete_title => 'Supprimer la plongee ?';

  @override
  String get diveLog_detail_appBar => 'Details de la plongee';

  @override
  String get diveLog_detail_badge_critical => 'CRITIQUE';

  @override
  String get diveLog_detail_badge_deco => 'DECO';

  @override
  String get diveLog_detail_badge_noDeco => 'SANS PALIER';

  @override
  String get diveLog_detail_badge_warning => 'ATTENTION';

  @override
  String diveLog_detail_buddyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'binomes',
      one: 'binome',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_button_playback => 'Lecture';

  @override
  String get diveLog_detail_button_rangeAnalysis => 'Analyse de plage';

  @override
  String get diveLog_detail_button_showEnd => 'Voir la fin';

  @override
  String get diveLog_detail_captureSignature =>
      'Capturer la signature du moniteur';

  @override
  String diveLog_detail_collapsed_atTime(Object timestamp) {
    return 'À $timestamp';
  }

  @override
  String diveLog_detail_collapsed_atTimeInfo(
    Object timestamp,
    Object baseInfo,
  ) {
    return 'À $timestamp • $baseInfo';
  }

  @override
  String diveLog_detail_collapsed_ceiling(Object value) {
    return 'Plafond : $value';
  }

  @override
  String diveLog_detail_collapsed_cnsMaxPpO2(Object cns, Object maxPpO2) {
    return 'CNS : $cns • Max ppO₂ : $maxPpO2';
  }

  @override
  String diveLog_detail_collapsed_cnsMaxPpO2AtTime(
    Object cns,
    Object maxPpO2,
    Object timestamp,
    Object ppO2,
  ) {
    return 'CNS : $cns • Max ppO₂ : $maxPpO2 • À $timestamp : $ppO2 bar';
  }

  @override
  String diveLog_detail_collapsed_ndl(Object value) {
    return 'DTR : $value';
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
      other: 'equipements',
      one: 'equipement',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_errorLoading =>
      'Erreur lors du chargement de la plongee';

  @override
  String get diveLog_detail_fullscreen_sampleData => 'Données d\'échantillon';

  @override
  String get diveLog_detail_fullscreen_tapChartCompact =>
      'Appuyez sur le graphique pour une vue compacte';

  @override
  String get diveLog_detail_fullscreen_tapChartFull =>
      'Appuyez sur le graphique pour une vue plein écran';

  @override
  String get diveLog_detail_fullscreen_touchChart =>
      'Touchez le graphique pour voir les données à ce point';

  @override
  String get diveLog_detail_label_airTemp => 'Temp air';

  @override
  String get diveLog_detail_label_avgDepth => 'Profondeur moy';

  @override
  String get diveLog_detail_label_buddy => 'Binome';

  @override
  String get diveLog_detail_label_currentDirection => 'Direction du courant';

  @override
  String get diveLog_detail_label_currentStrength => 'Force du courant';

  @override
  String get diveLog_detail_label_diveComputer => 'Ordinateur de plongee';

  @override
  String get diveLog_detail_label_diveMaster => 'Directeur de plongee';

  @override
  String get diveLog_detail_label_diveType => 'Type de plongee';

  @override
  String get diveLog_detail_label_elevation => 'Altitude';

  @override
  String get diveLog_detail_label_entry => 'Entree :';

  @override
  String get diveLog_detail_label_entryMethod => 'Methode d\'entree';

  @override
  String get diveLog_detail_label_exit => 'Sortie :';

  @override
  String get diveLog_detail_label_exitMethod => 'Methode de sortie';

  @override
  String get diveLog_detail_label_gradientFactors => 'Facteurs de gradient';

  @override
  String get diveLog_detail_label_height => 'Hauteur';

  @override
  String get diveLog_detail_label_highTide => 'Maree haute';

  @override
  String get diveLog_detail_label_lowTide => 'Maree basse';

  @override
  String get diveLog_detail_label_ppO2AtPoint => 'ppO₂ au point selectionne :';

  @override
  String get diveLog_detail_label_rateOfChange => 'Taux de variation';

  @override
  String get diveLog_detail_label_sacRate => 'Consommation SAC';

  @override
  String get diveLog_detail_label_state => 'Etat';

  @override
  String get diveLog_detail_label_surfaceInterval => 'Intervalle de surface';

  @override
  String get diveLog_detail_label_surfacePressure => 'Pression de surface';

  @override
  String get diveLog_detail_label_swellHeight => 'Hauteur de houle';

  @override
  String get diveLog_detail_label_total => 'Total :';

  @override
  String get diveLog_detail_label_visibility => 'Visibilite';

  @override
  String get diveLog_detail_label_waterType => 'Type d\'eau';

  @override
  String get diveLog_detail_menu_delete => 'Supprimer';

  @override
  String get diveLog_detail_menu_export => 'Exporter';

  @override
  String get diveLog_detail_menu_openFullPage => 'Ouvrir en pleine page';

  @override
  String get diveLog_detail_noNotes => 'Aucune note pour cette plongee.';

  @override
  String get diveLog_detail_notFound => 'Plongee introuvable';

  @override
  String diveLog_detail_profilePoints(Object count) {
    return '$count points';
  }

  @override
  String get diveLog_detail_section_altitudeDive => 'Plongee en altitude';

  @override
  String get diveLog_detail_section_buddies => 'Binomes';

  @override
  String get diveLog_detail_section_conditions => 'Conditions';

  @override
  String get diveLog_detail_section_customFields => 'Custom Fields';

  @override
  String get diveLog_detail_section_decoStatus => 'Statut de decompression';

  @override
  String get diveLog_detail_section_details => 'Details';

  @override
  String get diveLog_detail_section_diveProfile => 'Profil de plongee';

  @override
  String get diveLog_detail_section_equipment => 'Equipement';

  @override
  String get diveLog_detail_section_marineLife => 'Vie marine';

  @override
  String get diveLog_detail_section_notes => 'Notes';

  @override
  String get diveLog_detail_section_oxygenToxicity => 'Toxicite de l\'oxygene';

  @override
  String get diveLog_detail_section_sacByCylinder => 'SAC par bloc';

  @override
  String get diveLog_detail_section_sacRateBySegment =>
      'Consommation SAC par segment';

  @override
  String get diveLog_detail_section_tags => 'Tags';

  @override
  String get diveLog_detail_section_tanks => 'Blocs';

  @override
  String get diveLog_detail_section_tide => 'Maree';

  @override
  String get diveLog_detail_section_trainingSignature =>
      'Signature de formation';

  @override
  String get diveLog_detail_section_weight => 'Lestage';

  @override
  String get diveLog_detail_signatureDescription =>
      'Appuie pour ajouter la verification du moniteur pour cette plongee de formation';

  @override
  String get diveLog_detail_soloDive =>
      'Plongee solo ou aucun binome enregistre';

  @override
  String diveLog_detail_speciesCount(Object count) {
    return '$count especes';
  }

  @override
  String get diveLog_detail_stat_bottomTime => 'Temps au fond';

  @override
  String get diveLog_detail_stat_maxDepth => 'Profondeur max';

  @override
  String get diveLog_detail_stat_runtime => 'Duree totale';

  @override
  String get diveLog_detail_stat_waterTemp => 'Temp eau';

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
      other: 'blocs',
      one: 'bloc',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_tideCalculated =>
      'Calcule a partir du modele de maree';

  @override
  String get diveLog_detail_tooltip_addToFavorites => 'Ajouter aux favoris';

  @override
  String get diveLog_detail_tooltip_edit => 'Modifier';

  @override
  String get diveLog_detail_tooltip_editDive => 'Modifier la plongee';

  @override
  String get diveLog_detail_tooltip_exportProfileImage =>
      'Exporter le profil en image';

  @override
  String get diveLog_detail_tooltip_removeFromFavorites =>
      'Retirer des favoris';

  @override
  String get diveLog_detail_tooltip_viewFullscreen => 'Voir en plein ecran';

  @override
  String get diveLog_detail_viewSite => 'Voir le site';

  @override
  String get diveLog_diveMode_ccrDescription =>
      'Recycleur a circuit ferme avec ppO₂ constante';

  @override
  String get diveLog_diveMode_ocDescription =>
      'Plongee en circuit ouvert standard avec blocs';

  @override
  String get diveLog_diveMode_scrDescription =>
      'Recycleur semi-ferme avec ppO₂ variable';

  @override
  String get diveLog_diveMode_title => 'Mode de plongee';

  @override
  String get diveLog_editSighting_count => 'Nombre';

  @override
  String get diveLog_editSighting_notes => 'Notes';

  @override
  String get diveLog_editSighting_notesHint =>
      'Taille, comportement, emplacement...';

  @override
  String get diveLog_editSighting_remove => 'Retirer';

  @override
  String diveLog_editSighting_removeConfirm(Object name) {
    return 'Retirer $name de cette plongee ?';
  }

  @override
  String get diveLog_editSighting_removeTitle => 'Retirer l\'observation ?';

  @override
  String get diveLog_editSighting_save => 'Enregistrer les modifications';

  @override
  String get diveLog_edit_add => 'Ajouter';

  @override
  String get diveLog_edit_addCustomField => 'Add Field';

  @override
  String get diveLog_edit_addTank => 'Ajouter un bloc';

  @override
  String get diveLog_edit_addWeightEntry => 'Ajouter un lest';

  @override
  String diveLog_edit_addedGps(Object name) {
    return 'GPS ajoute a $name';
  }

  @override
  String get diveLog_edit_appBarEdit => 'Modifier la plongee';

  @override
  String get diveLog_edit_appBarNew => 'Enregistrer une plongee';

  @override
  String get diveLog_edit_cancel => 'Annuler';

  @override
  String get diveLog_edit_clearAllEquipment => 'Tout effacer';

  @override
  String diveLog_edit_createdSite(Object name) {
    return 'Site cree : $name';
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
    return 'Duree : $minutes min';
  }

  @override
  String get diveLog_edit_equipmentHint =>
      'Appuie sur \"Utiliser un set\" ou \"Ajouter\" pour selectionner l\'equipement';

  @override
  String diveLog_edit_errorLoadingDiveTypes(Object error) {
    return 'Erreur lors du chargement des types de plongee : $error';
  }

  @override
  String get diveLog_edit_gettingLocation => 'Obtention de la position...';

  @override
  String get diveLog_edit_headerNew => 'Nouvelle plongee';

  @override
  String get diveLog_edit_label_airTemp => 'Temp air';

  @override
  String get diveLog_edit_label_altitude => 'Altitude';

  @override
  String get diveLog_edit_label_avgDepth => 'Profondeur moy';

  @override
  String get diveLog_edit_label_bottomTime => 'Temps au fond';

  @override
  String get diveLog_edit_label_currentDirection => 'Direction du courant';

  @override
  String get diveLog_edit_label_currentStrength => 'Force du courant';

  @override
  String get diveLog_edit_label_diveType => 'Type de plongee';

  @override
  String get diveLog_edit_label_entryMethod => 'Methode d\'entree';

  @override
  String get diveLog_edit_label_exitMethod => 'Methode de sortie';

  @override
  String get diveLog_edit_label_maxDepth => 'Profondeur max';

  @override
  String get diveLog_edit_label_runtime => 'Duree totale';

  @override
  String get diveLog_edit_label_surfacePressure => 'Pression de surface';

  @override
  String get diveLog_edit_label_swellHeight => 'Hauteur de houle';

  @override
  String get diveLog_edit_label_type => 'Type';

  @override
  String get diveLog_edit_label_visibility => 'Visibilite';

  @override
  String get diveLog_edit_label_waterTemp => 'Temp eau';

  @override
  String get diveLog_edit_label_waterType => 'Type d\'eau';

  @override
  String get diveLog_edit_marineLifeHint =>
      'Appuie sur \"Ajouter\" pour enregistrer des observations';

  @override
  String get diveLog_edit_nearbySitesFirst => 'Sites a proximite en premier';

  @override
  String get diveLog_edit_noEquipmentSelected => 'Aucun equipement selectionne';

  @override
  String get diveLog_edit_noMarineLife => 'Aucune vie marine enregistree';

  @override
  String get diveLog_edit_notSpecified => 'Non specifie';

  @override
  String get diveLog_edit_notesHint => 'Ajoute des notes sur cette plongee...';

  @override
  String get diveLog_edit_save => 'Enregistrer';

  @override
  String get diveLog_edit_saveAsSet => 'Enregistrer comme set';

  @override
  String diveLog_edit_saveAsSetDialog_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'equipements',
      one: 'equipement',
    );
    return 'Enregistrer $count $_temp0 comme nouveau set d\'equipement.';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_description =>
      'Description (facultatif)';

  @override
  String get diveLog_edit_saveAsSetDialog_descriptionHint =>
      'ex. Equipement leger pour eau chaude';

  @override
  String diveLog_edit_saveAsSetDialog_error(Object error) {
    return 'Erreur lors de la creation du set : $error';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_setName => 'Nom du set';

  @override
  String get diveLog_edit_saveAsSetDialog_setNameHint =>
      'ex. Plongee tropicale';

  @override
  String diveLog_edit_saveAsSetDialog_success(Object name) {
    return 'Set d\'equipement \"$name\" cree';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_title =>
      'Enregistrer comme set d\'equipement';

  @override
  String get diveLog_edit_saveAsSetDialog_validation =>
      'Veuillez entrer un nom de set';

  @override
  String get diveLog_edit_section_conditions => 'Conditions';

  @override
  String get diveLog_edit_section_customFields => 'Custom Fields';

  @override
  String get diveLog_edit_section_depthDuration => 'Profondeur et duree';

  @override
  String get diveLog_edit_section_diveCenter => 'Centre de plongee';

  @override
  String get diveLog_edit_section_diveSite => 'Site de plongee';

  @override
  String get diveLog_edit_section_entryTime => 'Heure d\'entree';

  @override
  String get diveLog_edit_section_equipment => 'Equipement';

  @override
  String get diveLog_edit_section_exitTime => 'Heure de sortie';

  @override
  String get diveLog_edit_section_marineLife => 'Vie marine';

  @override
  String get diveLog_edit_section_notes => 'Notes';

  @override
  String get diveLog_edit_section_rating => 'Evaluation';

  @override
  String get diveLog_edit_section_tags => 'Tags';

  @override
  String diveLog_edit_section_tanks(Object count) {
    return 'Blocs ($count)';
  }

  @override
  String get diveLog_edit_section_trainingCourse => 'Cours de formation';

  @override
  String get diveLog_edit_section_trip => 'Voyage';

  @override
  String get diveLog_edit_section_weight => 'Lestage';

  @override
  String get diveLog_edit_select => 'Selectionner';

  @override
  String get diveLog_edit_selectDiveCenter =>
      'Selectionner un centre de plongee';

  @override
  String get diveLog_edit_selectDiveSite => 'Selectionner un site de plongee';

  @override
  String get diveLog_edit_selectTrip => 'Selectionner un voyage';

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Temps au fond calcule : $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Erreur lors de l\'enregistrement de la plongee : $error';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'Aucune donnee de profil de plongee disponible';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'Impossible de calculer le temps au fond a partir du profil';

  @override
  String diveLog_edit_surfaceInterval(Object interval) {
    return 'Intervalle de surface : $interval';
  }

  @override
  String get diveLog_edit_surfacePressureDefault => '1013';

  @override
  String get diveLog_edit_surfacePressureHint =>
      'Standard : 1013 mbar au niveau de la mer';

  @override
  String get diveLog_edit_tooltip_calculateFromProfile =>
      'Calculer a partir du profil de plongee';

  @override
  String get diveLog_edit_tooltip_clearDiveCenter =>
      'Effacer le centre de plongee';

  @override
  String get diveLog_edit_tooltip_clearSite => 'Effacer le site';

  @override
  String get diveLog_edit_tooltip_clearTrip => 'Effacer le voyage';

  @override
  String get diveLog_edit_tooltip_removeEquipment => 'Retirer l\'equipement';

  @override
  String get diveLog_edit_tooltip_removeSighting => 'Retirer l\'observation';

  @override
  String get diveLog_edit_tooltip_removeWeight => 'Retirer';

  @override
  String get diveLog_edit_trainingCourseHint =>
      'Associer cette plongee a un cours de formation';

  @override
  String diveLog_edit_tripSuggested(Object name) {
    return 'Suggestion : $name';
  }

  @override
  String get diveLog_edit_tripUse => 'Utiliser';

  @override
  String get diveLog_edit_useSet => 'Utiliser un set';

  @override
  String diveLog_edit_weightTotal(Object total) {
    return 'Total : $total';
  }

  @override
  String get diveLog_emptyFiltered_clearFilters => 'Effacer les filtres';

  @override
  String get diveLog_emptyFiltered_subtitle =>
      'Essaie d\'ajuster ou d\'effacer tes filtres';

  @override
  String get diveLog_emptyFiltered_title =>
      'Aucune plongee ne correspond a tes filtres';

  @override
  String get diveLog_empty_logFirstDive => 'Enregistre ta premiere plongee';

  @override
  String get diveLog_empty_subtitle =>
      'Appuie sur le bouton ci-dessous pour enregistrer ta premiere plongee';

  @override
  String get diveLog_empty_title => 'Aucune plongee enregistree';

  @override
  String get diveLog_equipmentPicker_addFromTab =>
      'Ajoute de l\'equipement depuis l\'onglet Equipement';

  @override
  String get diveLog_equipmentPicker_allSelected =>
      'Tout l\'equipement est deja selectionne';

  @override
  String diveLog_equipmentPicker_errorLoading(Object error) {
    return 'Erreur lors du chargement de l\'equipement : $error';
  }

  @override
  String get diveLog_equipmentPicker_noEquipment => 'Pas encore d\'equipement';

  @override
  String get diveLog_equipmentPicker_removeToAdd =>
      'Retire des elements pour en ajouter d\'autres';

  @override
  String get diveLog_equipmentPicker_title => 'Ajouter de l\'equipement';

  @override
  String get diveLog_equipmentSetPicker_createHint =>
      'Cree des sets dans Equipement > Sets';

  @override
  String get diveLog_equipmentSetPicker_emptySet => 'Set vide';

  @override
  String get diveLog_equipmentSetPicker_errorItems =>
      'Erreur lors du chargement des elements';

  @override
  String diveLog_equipmentSetPicker_errorLoading(Object error) {
    return 'Erreur lors du chargement des sets d\'equipement : $error';
  }

  @override
  String get diveLog_equipmentSetPicker_loading => 'Chargement...';

  @override
  String get diveLog_equipmentSetPicker_noSets =>
      'Pas encore de sets d\'equipement';

  @override
  String get diveLog_equipmentSetPicker_title =>
      'Utiliser un set d\'equipement';

  @override
  String get diveLog_error_loadingDives =>
      'Erreur lors du chargement des plongees';

  @override
  String get diveLog_error_retry => 'Reessayer';

  @override
  String get diveLog_exportImage_captureFailed =>
      'Impossible de capturer l\'image';

  @override
  String get diveLog_exportImage_generateFailed =>
      'Impossible de generer l\'image';

  @override
  String get diveLog_exportImage_generatingPdf => 'Generation du PDF...';

  @override
  String get diveLog_exportImage_pdfSaved => 'PDF enregistre';

  @override
  String get diveLog_exportImage_saveToFiles => 'Enregistrer dans les fichiers';

  @override
  String get diveLog_exportImage_saveToFilesDescription =>
      'Choisis un emplacement pour enregistrer le fichier';

  @override
  String get diveLog_exportImage_saveToPhotos => 'Enregistrer dans les photos';

  @override
  String get diveLog_exportImage_saveToPhotosDescription =>
      'Enregistrer l\'image dans ta phototheque';

  @override
  String get diveLog_exportImage_savedToFiles => 'Image enregistree';

  @override
  String get diveLog_exportImage_savedToPhotos =>
      'Image enregistree dans les photos';

  @override
  String get diveLog_exportImage_share => 'Partager';

  @override
  String get diveLog_exportImage_shareDescription =>
      'Partager via d\'autres applications';

  @override
  String get diveLog_exportImage_titleDetails =>
      'Exporter l\'image des details de plongee';

  @override
  String get diveLog_exportImage_titlePdf => 'Exporter en PDF';

  @override
  String get diveLog_exportImage_titleProfile => 'Exporter l\'image du profil';

  @override
  String get diveLog_export_csv => 'CSV';

  @override
  String get diveLog_export_csvDescription => 'Format tableur';

  @override
  String get diveLog_export_exporting => 'Export en cours...';

  @override
  String diveLog_export_failed(Object error) {
    return 'Echec de l\'export : $error';
  }

  @override
  String get diveLog_export_pageAsImage => 'Page en image';

  @override
  String get diveLog_export_pageAsImageDescription =>
      'Capture d\'ecran de la page complete des details';

  @override
  String get diveLog_export_pdfDescription =>
      'Page de carnet de plongee imprimable';

  @override
  String get diveLog_export_pdfLogbookEntry => 'Entree de carnet PDF';

  @override
  String get diveLog_export_success => 'Plongee exportee avec succes';

  @override
  String diveLog_export_titleDiveNumber(Object number) {
    return 'Exporter la plongee n$number';
  }

  @override
  String get diveLog_export_uddf => 'UDDF';

  @override
  String get diveLog_export_uddfDescription =>
      'Format universel de donnees de plongee';

  @override
  String get diveLog_filterChip_clearAll => 'Tout effacer';

  @override
  String get diveLog_filterChip_favorites => 'Favoris';

  @override
  String diveLog_filterChip_from(Object date) {
    return 'Du $date';
  }

  @override
  String diveLog_filterChip_until(Object date) {
    return 'Jusqu\'au $date';
  }

  @override
  String get diveLog_filter_allSites => 'Tous les sites';

  @override
  String get diveLog_filter_allTypes => 'Tous les types';

  @override
  String get diveLog_filter_apply => 'Appliquer les filtres';

  @override
  String get diveLog_filter_buddyHint => 'Rechercher par nom de binome';

  @override
  String get diveLog_filter_buddyName => 'Nom du binome';

  @override
  String get diveLog_filter_clearAll => 'Tout effacer';

  @override
  String get diveLog_filter_clearDates => 'Effacer les dates';

  @override
  String get diveLog_filter_clearRating => 'Effacer le filtre d\'evaluation';

  @override
  String get diveLog_filter_dateSeparator => 'au';

  @override
  String get diveLog_filter_endDate => 'Date de fin';

  @override
  String get diveLog_filter_errorLoadingSites =>
      'Erreur lors du chargement des sites';

  @override
  String get diveLog_filter_errorLoadingTags =>
      'Erreur lors du chargement des tags';

  @override
  String get diveLog_filter_favoritesOnly => 'Favoris uniquement';

  @override
  String get diveLog_filter_gasAir => 'Air (21%)';

  @override
  String get diveLog_filter_gasAll => 'Tous';

  @override
  String get diveLog_filter_gasNitrox => 'Nitrox (>21%)';

  @override
  String get diveLog_filter_max => 'Max';

  @override
  String get diveLog_filter_min => 'Min';

  @override
  String get diveLog_filter_noTagsYet => 'Aucun tag cree pour le moment';

  @override
  String get diveLog_filter_sectionBuddy => 'Binome';

  @override
  String get diveLog_filter_sectionDateRange => 'Plage de dates';

  @override
  String get diveLog_filter_sectionDepthRange => 'Plage de profondeur (metres)';

  @override
  String get diveLog_filter_sectionDiveSite => 'Site de plongee';

  @override
  String get diveLog_filter_sectionDiveType => 'Type de plongee';

  @override
  String get diveLog_filter_sectionDuration => 'Duree (minutes)';

  @override
  String get diveLog_filter_sectionGasMix => 'Melange gazeux (O₂%)';

  @override
  String get diveLog_filter_sectionMinRating => 'Evaluation minimum';

  @override
  String get diveLog_filter_sectionTags => 'Tags';

  @override
  String get diveLog_filter_showOnlyFavorites =>
      'Afficher uniquement les plongees favorites';

  @override
  String get diveLog_filter_startDate => 'Date de debut';

  @override
  String get diveLog_filter_title => 'Filtrer les plongees';

  @override
  String get diveLog_filter_tooltip_close => 'Fermer le filtre';

  @override
  String get diveLog_fullscreenProfile_close => 'Fermer le plein ecran';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Profil de la plongee n$number';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Vitesse de remontee';

  @override
  String get diveLog_legend_label_ceiling => 'Plafond';

  @override
  String get diveLog_legend_label_depth => 'Profondeur';

  @override
  String get diveLog_legend_label_events => 'Evenements';

  @override
  String get diveLog_legend_label_gasDensity => 'Densite du gaz';

  @override
  String get diveLog_legend_label_gasSwitches => 'Changements de gaz';

  @override
  String get diveLog_legend_label_gfPercent => 'GF%';

  @override
  String get diveLog_legend_label_heartRate => 'Frequence cardiaque';

  @override
  String get diveLog_legend_label_maxDepth => 'Profondeur max';

  @override
  String get diveLog_legend_label_meanDepth => 'Profondeur moyenne';

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
  String get diveLog_legend_label_pressure => 'Pression';

  @override
  String get diveLog_legend_label_pressureThresholds => 'Seuils de pression';

  @override
  String get diveLog_legend_label_sacRate => 'Consommation SAC';

  @override
  String get diveLog_legend_label_surfaceGf => 'GF surface';

  @override
  String get diveLog_legend_label_temp => 'Temp';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_listPage_appBar_diveMap => 'Carte des plongees';

  @override
  String get diveLog_listPage_compactTitle => 'Plongees';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get diveLog_listPage_fab_logDive => 'Enregistrer';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'Recherche avancee';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'Numerotation des plongees';

  @override
  String get diveLog_listPage_searchFieldLabel => 'Rechercher des plongees...';

  @override
  String diveLog_listPage_searchNoResults(Object query) {
    return 'Aucune plongee trouvee pour \"$query\"';
  }

  @override
  String get diveLog_listPage_searchSuggestion =>
      'Rechercher par site, binome ou notes';

  @override
  String get diveLog_listPage_title => 'Carnet de plongee';

  @override
  String get diveLog_listPage_tooltip_back => 'Retour';

  @override
  String get diveLog_listPage_tooltip_backToDiveList =>
      'Retour a la liste des plongees';

  @override
  String get diveLog_listPage_tooltip_clearSearch => 'Effacer la recherche';

  @override
  String get diveLog_listPage_tooltip_filterDives => 'Filtrer les plongees';

  @override
  String get diveLog_listPage_tooltip_listView => 'Vue liste';

  @override
  String get diveLog_listPage_tooltip_mapView => 'Vue carte';

  @override
  String get diveLog_listPage_tooltip_searchDives => 'Rechercher des plongees';

  @override
  String get diveLog_listPage_tooltip_sort => 'Trier';

  @override
  String get diveLog_listPage_unknownSite => 'Site inconnu';

  @override
  String get diveLog_map_emptySubtitle =>
      'Enregistre des plongees avec des donnees de localisation pour voir ton activite sur la carte';

  @override
  String get diveLog_map_emptyTitle => 'Aucune activite de plongee a afficher';

  @override
  String diveLog_map_errorLoading(Object error) {
    return 'Erreur lors du chargement des donnees de plongee : $error';
  }

  @override
  String get diveLog_map_tooltip_fitAllSites => 'Ajuster a tous les sites';

  @override
  String get diveLog_numbering_actions => 'Actions';

  @override
  String get diveLog_numbering_allCorrect =>
      'Toutes les plongees sont correctement numerotees';

  @override
  String get diveLog_numbering_assignMissing =>
      'Attribuer les numeros manquants';

  @override
  String get diveLog_numbering_assignMissingDesc =>
      'Numeroter les plongees non numerotees a partir de la derniere plongee numerotee';

  @override
  String get diveLog_numbering_close => 'Fermer';

  @override
  String get diveLog_numbering_gapsDetected => 'Ecarts detectes';

  @override
  String get diveLog_numbering_issuesDetected => 'Problemes detectes';

  @override
  String diveLog_numbering_missingCount(Object count) {
    return '$count manquant(s)';
  }

  @override
  String get diveLog_numbering_renumberAll => 'Renumeroter toutes les plongees';

  @override
  String get diveLog_numbering_renumberAllDesc =>
      'Attribuer des numeros sequentiels selon la date/heure de plongee';

  @override
  String get diveLog_numbering_renumberDialog_cancel => 'Annuler';

  @override
  String get diveLog_numbering_renumberDialog_content =>
      'Toutes les plongees seront renumerotees sequentiellement selon leur date/heure d\'entree. Cette action est irreversible.';

  @override
  String get diveLog_numbering_renumberDialog_renumber => 'Renumeroter';

  @override
  String get diveLog_numbering_renumberDialog_startFrom =>
      'Commencer a partir du numero';

  @override
  String get diveLog_numbering_renumberDialog_title =>
      'Renumeroter toutes les plongees';

  @override
  String get diveLog_numbering_snackbar_assigned =>
      'Numeros de plongee manquants attribues';

  @override
  String diveLog_numbering_snackbar_renumbered(Object number) {
    return 'Toutes les plongees renumerotees a partir du n$number';
  }

  @override
  String diveLog_numbering_summary(Object total, Object numbered) {
    return '$total plongees au total - $numbered numerotees';
  }

  @override
  String get diveLog_numbering_title => 'Numerotation des plongees';

  @override
  String diveLog_numbering_unnumberedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongees',
      one: 'plongee',
    );
    return '$count $_temp0 sans numero';
  }

  @override
  String get diveLog_o2tox_badge_critical => 'CRITIQUE';

  @override
  String get diveLog_o2tox_badge_warning => 'ATTENTION';

  @override
  String diveLog_o2tox_cnsBadgeLabel(Object value) {
    return 'CNS $value';
  }

  @override
  String get diveLog_o2tox_cnsOxygenClock => 'Horloge oxygene CNS';

  @override
  String diveLog_o2tox_deltaDive(Object value) {
    return '+$value% cette plongee';
  }

  @override
  String get diveLog_o2tox_details => 'Details';

  @override
  String get diveLog_o2tox_label_maxPpO2 => 'ppO2 max';

  @override
  String get diveLog_o2tox_label_maxPpO2Depth => 'Profondeur ppO2 max';

  @override
  String get diveLog_o2tox_label_timeAbove14 => 'Temps au-dessus de 1,4 bar';

  @override
  String get diveLog_o2tox_label_timeAbove16 => 'Temps au-dessus de 1,6 bar';

  @override
  String get diveLog_o2tox_ofDailyLimit => 'de la limite journaliere';

  @override
  String get diveLog_o2tox_oxygenToleranceUnits =>
      'Unites de tolerance a l\'oxygene';

  @override
  String diveLog_o2tox_semantics_cnsBadge(Object value) {
    return 'Toxicité CNS de l\'oxygène $value';
  }

  @override
  String get diveLog_o2tox_semantics_criticalWarning =>
      'Avertissement critique de toxicite de l\'oxygene';

  @override
  String diveLog_o2tox_semantics_otu(Object value, Object percent) {
    return 'Unités de tolérance à l\'oxygène : $value, $percent pour cent de la limite quotidienne';
  }

  @override
  String get diveLog_o2tox_semantics_warning =>
      'Avertissement de toxicite de l\'oxygene';

  @override
  String diveLog_o2tox_startPercent(Object value) {
    return 'Debut : $value%';
  }

  @override
  String get diveLog_o2tox_title => 'Toxicite de l\'oxygene';

  @override
  String get diveLog_playbackStats_deco => 'DECO';

  @override
  String get diveLog_playbackStats_depth => 'Profondeur';

  @override
  String get diveLog_playbackStats_header => 'Stats en direct';

  @override
  String get diveLog_playbackStats_heartRate => 'Frequence cardiaque';

  @override
  String get diveLog_playbackStats_ndl => 'NDL';

  @override
  String get diveLog_playbackStats_ppO2 => 'ppO₂';

  @override
  String get diveLog_playbackStats_pressure => 'Pression';

  @override
  String get diveLog_playbackStats_temp => 'Temp';

  @override
  String get diveLog_playback_sliderLabel => 'Position de lecture';

  @override
  String diveLog_playback_speed_label(Object speed) {
    return '${speed}x';
  }

  @override
  String get diveLog_playback_stepThrough => 'Lecture pas a pas';

  @override
  String get diveLog_playback_tooltip_back10 => 'Reculer de 10 secondes';

  @override
  String get diveLog_playback_tooltip_exit => 'Quitter le mode lecture';

  @override
  String get diveLog_playback_tooltip_forward10 => 'Avancer de 10 secondes';

  @override
  String get diveLog_playback_tooltip_pause => 'Pause';

  @override
  String get diveLog_playback_tooltip_play => 'Lecture';

  @override
  String get diveLog_playback_tooltip_skipEnd => 'Aller a la fin';

  @override
  String get diveLog_playback_tooltip_skipStart => 'Aller au debut';

  @override
  String get diveLog_playback_tooltip_speed => 'Vitesse de lecture';

  @override
  String get diveLog_profileSelector_badge_primary => 'Principal';

  @override
  String get diveLog_profileSelector_label_diveComputers =>
      'Ordinateurs de plongee';

  @override
  String diveLog_profile_axisDepth(Object unit) {
    return 'Profondeur ($unit)';
  }

  @override
  String get diveLog_profile_axisTime => 'Temps (min)';

  @override
  String get diveLog_profile_emptyState => 'Aucune donnee de profil de plongee';

  @override
  String get diveLog_profile_rightAxis_none => 'Aucun';

  @override
  String get diveLog_profile_semantics_changeRightAxis =>
      'Changer la metrique de l\'axe droit';

  @override
  String get diveLog_profile_semantics_chart =>
      'Graphique du profil de plongee, pincer pour zoomer';

  @override
  String get diveLog_profile_tooltip_moreOptions =>
      'Plus d\'options de graphique';

  @override
  String get diveLog_profile_tooltip_resetZoom => 'Reinitialiser le zoom';

  @override
  String get diveLog_profile_tooltip_zoomIn => 'Zoom avant';

  @override
  String get diveLog_profile_tooltip_zoomOut => 'Zoom arriere';

  @override
  String diveLog_profile_zoomHint(Object level) {
    return 'Zoom : ${level}x - Pincer ou defiler pour zoomer, glisser pour deplacer';
  }

  @override
  String get diveLog_rangeSelection_exitRange => 'Quitter la plage';

  @override
  String get diveLog_rangeSelection_selectRange => 'Selectionner une plage';

  @override
  String get diveLog_rangeSelection_semantics_adjust =>
      'Ajuster la selection de plage';

  @override
  String get diveLog_rangeStats_header_avg => 'Moy';

  @override
  String get diveLog_rangeStats_header_max => 'Max';

  @override
  String get diveLog_rangeStats_header_min => 'Min';

  @override
  String get diveLog_rangeStats_label_depth => 'Profondeur';

  @override
  String get diveLog_rangeStats_label_heartRate => 'Frequence cardiaque';

  @override
  String get diveLog_rangeStats_label_pressure => 'Pression';

  @override
  String get diveLog_rangeStats_label_temp => 'Temp';

  @override
  String get diveLog_rangeStats_title => 'Analyse de plage';

  @override
  String get diveLog_rangeStats_tooltip_close => 'Fermer l\'analyse de plage';

  @override
  String diveLog_scr_calculatedLoopFo2(Object value) {
    return 'FO₂ de boucle calcule : $value%';
  }

  @override
  String get diveLog_scr_hint_additionRatio => 'ex. 0,33 (1:3)';

  @override
  String get diveLog_scr_label_additionRatio => 'Ratio d\'addition';

  @override
  String get diveLog_scr_label_assumedVo2 => 'VO₂ suppose';

  @override
  String get diveLog_scr_label_avg => 'Moy';

  @override
  String get diveLog_scr_label_injectionRate => 'Debit d\'injection';

  @override
  String get diveLog_scr_label_max => 'Max';

  @override
  String get diveLog_scr_label_min => 'Min';

  @override
  String get diveLog_scr_label_orificeSize => 'Taille de l\'orifice';

  @override
  String get diveLog_scr_sectionCmf => 'Parametres CMF';

  @override
  String get diveLog_scr_sectionEscr => 'Parametres ESCR';

  @override
  String get diveLog_scr_sectionMeasuredLoopO2 =>
      'O₂ de boucle mesure (optionnel)';

  @override
  String get diveLog_scr_sectionPascr => 'Parametres PASCR';

  @override
  String get diveLog_scr_sectionScrType => 'Type de SCR';

  @override
  String get diveLog_scr_sectionSupplyGas => 'Gaz d\'alimentation';

  @override
  String get diveLog_scr_title => 'Reglages SCR';

  @override
  String get diveLog_search_allCenters => 'Tous les centres';

  @override
  String get diveLog_search_allTrips => 'Tous les voyages';

  @override
  String get diveLog_search_appBar => 'Recherche avancee';

  @override
  String get diveLog_search_cancel => 'Annuler';

  @override
  String get diveLog_search_clearAll => 'Tout effacer';

  @override
  String get diveLog_search_customFieldKey => 'Custom Field Key';

  @override
  String get diveLog_search_customFieldValue => 'Value contains...';

  @override
  String get diveLog_search_end => 'Fin';

  @override
  String get diveLog_search_errorLoadingCenters =>
      'Erreur de chargement des centres de plongee';

  @override
  String get diveLog_search_errorLoadingDiveTypes =>
      'Erreur lors du chargement des types de plongée';

  @override
  String get diveLog_search_errorLoadingTrips =>
      'Erreur de chargement des voyages';

  @override
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

  @override
  String get diveLog_search_label_depthRange => 'Plage de profondeur (m)';

  @override
  String get diveLog_search_label_diveCenter => 'Centre de plongee';

  @override
  String get diveLog_search_label_diveSite => 'Site de plongee';

  @override
  String get diveLog_search_label_diveType => 'Type de plongee';

  @override
  String get diveLog_search_label_durationRange => 'Plage de duree (min)';

  @override
  String get diveLog_search_label_trip => 'Voyage';

  @override
  String get diveLog_search_search => 'Rechercher';

  @override
  String get diveLog_search_section_conditions => 'Conditions';

  @override
  String get diveLog_search_section_dateRange => 'Plage de dates';

  @override
  String get diveLog_search_section_gasEquipment => 'Gaz et equipement';

  @override
  String get diveLog_search_section_location => 'Lieu';

  @override
  String get diveLog_search_section_organization => 'Organisation';

  @override
  String get diveLog_search_section_social => 'Social';

  @override
  String get diveLog_search_start => 'Debut';

  @override
  String diveLog_selection_countSelected(Object count) {
    return '$count selectionne(s)';
  }

  @override
  String get diveLog_selection_tooltip_delete => 'Supprimer la selection';

  @override
  String get diveLog_selection_tooltip_deselectAll => 'Tout deselectionner';

  @override
  String get diveLog_selection_tooltip_edit => 'Modifier la selection';

  @override
  String get diveLog_selection_tooltip_exit => 'Quitter la selection';

  @override
  String get diveLog_selection_tooltip_export => 'Exporter la selection';

  @override
  String get diveLog_selection_tooltip_selectAll => 'Tout selectionner';

  @override
  String get diveLog_sighting_add => 'Ajouter';

  @override
  String get diveLog_sighting_cancel => 'Annuler';

  @override
  String get diveLog_sighting_notesHint =>
      'ex. taille, comportement, emplacement...';

  @override
  String get diveLog_sighting_notesOptional => 'Notes (optionnel)';

  @override
  String get diveLog_sitePicker_addDiveSite => 'Ajouter un site de plongee';

  @override
  String diveLog_sitePicker_distanceKm(Object distance) {
    return '$distance km';
  }

  @override
  String diveLog_sitePicker_distanceMeters(Object distance) {
    return '$distance m';
  }

  @override
  String diveLog_sitePicker_errorLoading(Object error) {
    return 'Erreur de chargement des sites : $error';
  }

  @override
  String get diveLog_sitePicker_newDiveSite => 'Nouveau site de plongee';

  @override
  String get diveLog_sitePicker_noSites => 'Aucun site de plongee';

  @override
  String get diveLog_sitePicker_sortedByDistance => 'Trie par distance';

  @override
  String get diveLog_sitePicker_title => 'Selectionner un site de plongee';

  @override
  String get diveLog_sort_title => 'Trier les plongees';

  @override
  String diveLog_speciesPicker_addNew(Object name) {
    return 'Ajouter \"$name\" comme nouvelle espece';
  }

  @override
  String get diveLog_speciesPicker_noResults => 'Aucune espece trouvee';

  @override
  String get diveLog_speciesPicker_noSpecies => 'Aucune espece disponible';

  @override
  String get diveLog_speciesPicker_searchHint => 'Rechercher des especes...';

  @override
  String get diveLog_speciesPicker_title => 'Ajouter de la vie marine';

  @override
  String get diveLog_speciesPicker_tooltip_clearSearch =>
      'Effacer la recherche';

  @override
  String get diveLog_summary_action_importComputer =>
      'Importer depuis un ordinateur';

  @override
  String get diveLog_summary_action_logDive => 'Enregistrer une plongee';

  @override
  String get diveLog_summary_action_viewStats => 'Voir les statistiques';

  @override
  String diveLog_summary_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongees',
      one: 'plongee',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_summary_overview => 'Apercu';

  @override
  String get diveLog_summary_record_coldest => 'Plongee la plus froide';

  @override
  String get diveLog_summary_record_deepest => 'Plongee la plus profonde';

  @override
  String get diveLog_summary_record_longest => 'Plongee la plus longue';

  @override
  String get diveLog_summary_record_warmest => 'Plongee la plus chaude';

  @override
  String get diveLog_summary_section_mostVisited => 'Sites les plus visites';

  @override
  String get diveLog_summary_section_quickActions => 'Actions rapides';

  @override
  String get diveLog_summary_section_records => 'Records personnels';

  @override
  String get diveLog_summary_selectDive =>
      'Selectionne une plongee dans la liste pour voir les details';

  @override
  String get diveLog_summary_stat_avgMaxDepth => 'Prof. max moyenne';

  @override
  String get diveLog_summary_stat_avgWaterTemp => 'Temp. eau moyenne';

  @override
  String get diveLog_summary_stat_diveSites => 'Sites de plongee';

  @override
  String get diveLog_summary_stat_diveTime => 'Temps de plongee';

  @override
  String get diveLog_summary_stat_maxDepth => 'Prof. max';

  @override
  String get diveLog_summary_stat_totalDives => 'Total plongees';

  @override
  String get diveLog_summary_title => 'Resume du carnet de plongee';

  @override
  String get diveLog_tank_label_endPressure => 'Pression finale';

  @override
  String get diveLog_tank_label_he => 'He';

  @override
  String get diveLog_tank_label_material => 'Materiau';

  @override
  String get diveLog_tank_label_n2 => 'N2';

  @override
  String get diveLog_tank_label_o2 => 'O2';

  @override
  String get diveLog_tank_label_role => 'Role';

  @override
  String get diveLog_tank_label_startPressure => 'Pression initiale';

  @override
  String get diveLog_tank_label_tankPreset => 'Preset de bloc';

  @override
  String get diveLog_tank_label_volume => 'Volume';

  @override
  String get diveLog_tank_label_workingPressure => 'Pression de service';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'PMU : $depth (ppO₂ 1.4)';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Melange gazeux';

  @override
  String get diveLog_tank_selectPreset => 'Selectionner un preset...';

  @override
  String diveLog_tank_title(Object number) {
    return 'Bloc $number';
  }

  @override
  String get diveLog_tank_tooltip_remove => 'Retirer le bloc';

  @override
  String get diveLog_tissue_label_ceiling => 'Plafond';

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
  String get diveLog_tissue_title => 'Charge tissulaire';

  @override
  String get diveLog_tooltip_ceiling => 'Plafond';

  @override
  String get diveLog_tooltip_density => 'Densite';

  @override
  String get diveLog_tooltip_depth => 'Profondeur';

  @override
  String get diveLog_tooltip_gfPercent => 'GF%';

  @override
  String get diveLog_tooltip_hr => 'FC';

  @override
  String get diveLog_tooltip_marker => 'Marqueur';

  @override
  String get diveLog_tooltip_mean => 'Moyenne';

  @override
  String get diveLog_tooltip_mod => 'MOD';

  @override
  String get diveLog_tooltip_ndl => 'DTR';

  @override
  String get diveLog_tooltip_ppHe => 'ppHe';

  @override
  String get diveLog_tooltip_ppN2 => 'ppN2';

  @override
  String get diveLog_tooltip_ppO2 => 'ppO2';

  @override
  String get diveLog_tooltip_press => 'Pression';

  @override
  String get diveLog_tooltip_rate => 'Vitesse';

  @override
  String get diveLog_tooltip_sac => 'CAS';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Temp';

  @override
  String get diveLog_tooltip_time => 'Temps';

  @override
  String get diveLog_tooltip_tts => 'TDR';

  @override
  String get divePlanner_action_addTank => 'Ajouter une bouteille';

  @override
  String get divePlanner_action_convertToDive => 'Convertir en plongée';

  @override
  String get divePlanner_action_editTank => 'Modifier la bouteille';

  @override
  String get divePlanner_action_moreOptions => 'Plus d\'options';

  @override
  String get divePlanner_action_quickPlan => 'Plan rapide';

  @override
  String get divePlanner_action_renamePlan => 'Renommer le plan';

  @override
  String get divePlanner_action_reset => 'Réinitialiser';

  @override
  String get divePlanner_action_resetPlan => 'Réinitialiser le plan';

  @override
  String get divePlanner_action_savePlan => 'Enregistrer le plan';

  @override
  String get divePlanner_error_cannotConvert =>
      'Impossible de convertir : le plan comporte des avertissements critiques';

  @override
  String get divePlanner_field_hePercent => 'He %';

  @override
  String get divePlanner_field_name => 'Nom';

  @override
  String get divePlanner_field_o2Percent => 'O₂ %';

  @override
  String get divePlanner_field_planName => 'Nom du plan';

  @override
  String get divePlanner_field_role => 'Rôle';

  @override
  String divePlanner_field_startPressure(Object pressureSymbol) {
    return 'Début ($pressureSymbol)';
  }

  @override
  String divePlanner_field_volume(Object volumeSymbol) {
    return 'Volume ($volumeSymbol)';
  }

  @override
  String get divePlanner_hint_tankName => 'Entrer le nom de la bouteille';

  @override
  String get divePlanner_label_altitude => 'Altitude :';

  @override
  String get divePlanner_label_belowMinReserve =>
      'En dessous de la réserve minimale';

  @override
  String get divePlanner_label_ceiling => 'Plafond';

  @override
  String get divePlanner_label_consumption => 'Consommation';

  @override
  String get divePlanner_label_deco => 'DÉCO';

  @override
  String get divePlanner_label_decoSchedule => 'Programme de décompression';

  @override
  String get divePlanner_label_decompression => 'Décompression';

  @override
  String divePlanner_label_depthAxis(Object depthSymbol) {
    return 'Profondeur ($depthSymbol)';
  }

  @override
  String get divePlanner_label_diveProfile => 'Profil de plongée';

  @override
  String get divePlanner_label_empty => 'VIDE';

  @override
  String get divePlanner_label_gasConsumption => 'Consommation de gaz';

  @override
  String get divePlanner_label_gfHigh => 'GF haut';

  @override
  String get divePlanner_label_gfLow => 'GF bas';

  @override
  String get divePlanner_label_max => 'Max';

  @override
  String get divePlanner_label_ndl => 'DTR';

  @override
  String get divePlanner_label_planSettings => 'Paramètres du plan';

  @override
  String get divePlanner_label_remaining => 'Restant';

  @override
  String get divePlanner_label_runtime => 'Durée totale';

  @override
  String get divePlanner_label_sacRate => 'Taux CAS :';

  @override
  String get divePlanner_label_status => 'État';

  @override
  String get divePlanner_label_tanks => 'Bouteilles';

  @override
  String get divePlanner_label_time => 'Temps';

  @override
  String get divePlanner_label_timeAxis => 'Temps (min)';

  @override
  String get divePlanner_label_tts => 'TDR';

  @override
  String get divePlanner_label_used => 'Utilisé';

  @override
  String get divePlanner_label_warnings => 'Avertissements';

  @override
  String get divePlanner_legend_ascent => 'Remontée';

  @override
  String get divePlanner_legend_bottom => 'Fond';

  @override
  String get divePlanner_legend_deco => 'Déco';

  @override
  String get divePlanner_legend_descent => 'Descente';

  @override
  String get divePlanner_legend_safety => 'Sécurité';

  @override
  String get divePlanner_message_addSegmentsForGas =>
      'Ajoutez des segments pour voir les projections de gaz';

  @override
  String get divePlanner_message_addSegmentsForProfile =>
      'Ajoutez des segments pour voir le profil de plongée';

  @override
  String get divePlanner_message_convertingPlan =>
      'Conversion du plan en plongée...';

  @override
  String get divePlanner_message_noProfile => 'Aucun profil à afficher';

  @override
  String get divePlanner_message_planSaved => 'Plan enregistré';

  @override
  String get divePlanner_message_resetConfirmation =>
      'Voulez-vous vraiment réinitialiser le plan ?';

  @override
  String divePlanner_semantics_criticalWarning(Object message) {
    return 'Avertissement critique : $message';
  }

  @override
  String divePlanner_semantics_decoStop(
    Object depth,
    Object duration,
    Object gasMix,
  ) {
    return 'Palier de déco à $depth pendant $duration sur $gasMix';
  }

  @override
  String divePlanner_semantics_gasConsumption(
    Object tankName,
    Object gasUsed,
    Object remaining,
    Object percent,
    Object warning,
  ) {
    return '$tankName : $gasUsed utilisé, $remaining restant, $percent utilisé$warning';
  }

  @override
  String divePlanner_semantics_profileChart(
    Object maxDepth,
    Object totalMinutes,
  ) {
    return 'Plan de plongée, profondeur max $maxDepth, temps total $totalMinutes minutes';
  }

  @override
  String divePlanner_semantics_warning(Object message) {
    return 'Avertissement : $message';
  }

  @override
  String get divePlanner_tab_plan => 'Plan';

  @override
  String get divePlanner_tab_profile => 'Profil';

  @override
  String get divePlanner_tab_results => 'Résultats';

  @override
  String get divePlanner_warning_ascentRateHigh =>
      'La vitesse de remontée dépasse la limite de sécurité';

  @override
  String divePlanner_warning_ascentRateHighWithRate(Object rate) {
    return 'La vitesse de remontée $rate/min dépasse la limite de sécurité';
  }

  @override
  String divePlanner_warning_belowMinReserve(Object reserve) {
    return 'En dessous de la réserve minimale ($reserve)';
  }

  @override
  String get divePlanner_warning_cnsCritical => 'CNS% dépasse 100%';

  @override
  String divePlanner_warning_cnsWarning(Object threshold) {
    return 'CNS% dépasse $threshold%';
  }

  @override
  String get divePlanner_warning_endHigh =>
      'Profondeur narcotique équivalente trop élevée';

  @override
  String divePlanner_warning_endHighWithDepth(Object depth) {
    return 'END de $depth dépasse la limite de sécurité';
  }

  @override
  String divePlanner_warning_gasLow(Object threshold) {
    return 'Bouteille en dessous de la réserve de $threshold';
  }

  @override
  String get divePlanner_warning_gasOut => 'La bouteille sera vide';

  @override
  String get divePlanner_warning_minGasViolation =>
      'Réserve minimale de gaz non maintenue';

  @override
  String get divePlanner_warning_modViolation =>
      'Changement de gaz tenté au-dessus de la MOD';

  @override
  String get divePlanner_warning_ndlExceeded =>
      'La plongée entre en obligation de décompression';

  @override
  String get divePlanner_warning_otuWarning => 'Accumulation d\'OTU élevée';

  @override
  String divePlanner_warning_ppO2Critical(Object value) {
    return 'ppO₂ de $value bar dépasse la limite critique';
  }

  @override
  String divePlanner_warning_ppO2High(Object value) {
    return 'ppO₂ de $value bar dépasse la limite de travail';
  }

  @override
  String get diveSites_detail_access_accessNotes => 'Notes d\'acces';

  @override
  String get diveSites_detail_access_mooring => 'Mouillage';

  @override
  String get diveSites_detail_access_parking => 'Stationnement';

  @override
  String get diveSites_detail_altitude_elevation => 'Altitude';

  @override
  String get diveSites_detail_altitude_pressure => 'Pression';

  @override
  String get diveSites_detail_coordinatesCopied =>
      'Coordonnees copiees dans le presse-papiers';

  @override
  String get diveSites_detail_deleteDialog_cancel => 'Annuler';

  @override
  String get diveSites_detail_deleteDialog_confirm => 'Supprimer';

  @override
  String get diveSites_detail_deleteDialog_content =>
      'Es-tu sur de vouloir supprimer ce site ? Cette action est irreversible.';

  @override
  String get diveSites_detail_deleteDialog_title => 'Supprimer le site';

  @override
  String get diveSites_detail_deleteMenu_label => 'Supprimer';

  @override
  String get diveSites_detail_deleteSnackbar => 'Site supprime';

  @override
  String get diveSites_detail_depth_maximum => 'Maximum';

  @override
  String get diveSites_detail_depth_minimum => 'Minimum';

  @override
  String get diveSites_detail_diveCount_one => '1 plongee enregistree';

  @override
  String diveSites_detail_diveCount_other(Object count) {
    return '$count plongees enregistrees';
  }

  @override
  String get diveSites_detail_diveCount_zero => 'Aucune plongee enregistree';

  @override
  String get diveSites_detail_editTooltip => 'Modifier le site';

  @override
  String get diveSites_detail_editTooltipShort => 'Modifier';

  @override
  String diveSites_detail_error_body(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get diveSites_detail_error_title => 'Erreur';

  @override
  String get diveSites_detail_loading_title => 'Chargement...';

  @override
  String get diveSites_detail_location_country => 'Pays';

  @override
  String get diveSites_detail_location_gpsCoordinates => 'Coordonnees GPS';

  @override
  String get diveSites_detail_location_notSet => 'Non defini';

  @override
  String get diveSites_detail_location_region => 'Region';

  @override
  String get diveSites_detail_noDepthInfo => 'Aucune information de profondeur';

  @override
  String get diveSites_detail_noDescription => 'Aucune description';

  @override
  String get diveSites_detail_noNotes => 'Aucune note';

  @override
  String get diveSites_detail_rating_notRated => 'Non note';

  @override
  String diveSites_detail_rating_value(Object rating) {
    return '$rating sur 5';
  }

  @override
  String get diveSites_detail_section_access => 'Acces et logistique';

  @override
  String get diveSites_detail_section_altitude => 'Altitude';

  @override
  String get diveSites_detail_section_depthRange => 'Plage de profondeur';

  @override
  String get diveSites_detail_section_description => 'Description';

  @override
  String get diveSites_detail_section_difficultyLevel => 'Niveau de difficulte';

  @override
  String get diveSites_detail_section_divesAtSite => 'Plongees sur ce site';

  @override
  String get diveSites_detail_section_hazards => 'Dangers et securite';

  @override
  String get diveSites_detail_section_location => 'Lieu';

  @override
  String get diveSites_detail_section_notes => 'Notes';

  @override
  String get diveSites_detail_section_rating => 'Evaluation';

  @override
  String diveSites_detail_semantics_copyToClipboard(Object label) {
    return 'Copier $label dans le presse-papiers';
  }

  @override
  String get diveSites_detail_semantics_viewDivesAtSite =>
      'Voir les plongees sur ce site';

  @override
  String get diveSites_detail_semantics_viewFullscreenMap =>
      'Voir la carte en plein ecran';

  @override
  String get diveSites_detail_siteNotFound_body => 'Ce site n\'existe plus.';

  @override
  String get diveSites_detail_siteNotFound_title => 'Site introuvable';

  @override
  String get diveSites_difficulty_advanced => 'Avance';

  @override
  String get diveSites_difficulty_beginner => 'Debutant';

  @override
  String get diveSites_difficulty_intermediate => 'Intermediaire';

  @override
  String get diveSites_difficulty_technical => 'Technique';

  @override
  String get diveSites_edit_access_accessNotes_hint =>
      'Comment acceder au site, points d\'entree/sortie, acces depuis la rive/le bateau';

  @override
  String get diveSites_edit_access_accessNotes_label => 'Notes d\'acces';

  @override
  String get diveSites_edit_access_mooringNumber_hint => 'ex. Bouee n°12';

  @override
  String get diveSites_edit_access_mooringNumber_label => 'Numero de mouillage';

  @override
  String get diveSites_edit_access_parkingInfo_hint =>
      'Disponibilite du stationnement, tarifs, conseils';

  @override
  String get diveSites_edit_access_parkingInfo_label =>
      'Informations de stationnement';

  @override
  String get diveSites_edit_altitude_helperText =>
      'Altitude du site au-dessus du niveau de la mer (pour la plongee en altitude)';

  @override
  String get diveSites_edit_altitude_hint => 'ex. 2000';

  @override
  String diveSites_edit_altitude_label(Object symbol) {
    return 'Altitude ($symbol)';
  }

  @override
  String get diveSites_edit_altitude_validation => 'Altitude invalide';

  @override
  String get diveSites_edit_appBar_deleteSiteTooltip => 'Supprimer le site';

  @override
  String get diveSites_edit_appBar_editSite => 'Modifier le site';

  @override
  String get diveSites_edit_appBar_newSite => 'Nouveau site';

  @override
  String get diveSites_edit_appBar_save => 'Enregistrer';

  @override
  String get diveSites_edit_button_addSite => 'Ajouter le site';

  @override
  String get diveSites_edit_button_saveChanges =>
      'Enregistrer les modifications';

  @override
  String get diveSites_edit_cancel => 'Annuler';

  @override
  String get diveSites_edit_depth_helperText =>
      'Du point le moins profond au point le plus profond';

  @override
  String get diveSites_edit_depth_maxHint => 'ex. 30';

  @override
  String diveSites_edit_depth_maxLabel(Object symbol) {
    return 'Profondeur maximale ($symbol)';
  }

  @override
  String get diveSites_edit_depth_minHint => 'ex. 5';

  @override
  String diveSites_edit_depth_minLabel(Object symbol) {
    return 'Profondeur minimale ($symbol)';
  }

  @override
  String get diveSites_edit_depth_separator => 'a';

  @override
  String get diveSites_edit_discardDialog_content =>
      'Tu as des modifications non enregistrees. Es-tu sur de vouloir quitter ?';

  @override
  String get diveSites_edit_discardDialog_discard => 'Abandonner';

  @override
  String get diveSites_edit_discardDialog_keepEditing => 'Continuer l\'edition';

  @override
  String get diveSites_edit_discardDialog_title =>
      'Abandonner les modifications ?';

  @override
  String get diveSites_edit_field_country_label => 'Pays';

  @override
  String get diveSites_edit_field_description_hint =>
      'Breve description du site';

  @override
  String get diveSites_edit_field_description_label => 'Description';

  @override
  String get diveSites_edit_field_notes_hint =>
      'Toute autre information sur ce site';

  @override
  String get diveSites_edit_field_notes_label => 'Notes generales';

  @override
  String get diveSites_edit_field_region_label => 'Region';

  @override
  String get diveSites_edit_field_siteName_hint => 'ex. Blue Hole';

  @override
  String get diveSites_edit_field_siteName_label => 'Nom du site *';

  @override
  String get diveSites_edit_field_siteName_validation =>
      'Veuillez entrer un nom de site';

  @override
  String get diveSites_edit_gps_gettingLocation => 'Obtention...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Choisissez une methode de localisation - les coordonnees rempliront automatiquement le pays et la region';

  @override
  String get diveSites_edit_gps_latitude_hint => 'ex. 21.4225';

  @override
  String get diveSites_edit_gps_latitude_label => 'Latitude';

  @override
  String get diveSites_edit_gps_latitude_validation => 'Latitude invalide';

  @override
  String get diveSites_edit_gps_longitude_hint => 'ex. -86.7542';

  @override
  String get diveSites_edit_gps_longitude_label => 'Longitude';

  @override
  String get diveSites_edit_gps_longitude_validation => 'Longitude invalide';

  @override
  String get diveSites_edit_gps_pickFromMap => 'Choisir sur la carte';

  @override
  String get diveSites_edit_gps_useMyLocation => 'Utiliser ma position';

  @override
  String get diveSites_edit_hazards_helperText =>
      'Listez les dangers ou les considerations de securite';

  @override
  String get diveSites_edit_hazards_hint =>
      'ex. Courants forts, trafic maritime, meduses, corail tranchant';

  @override
  String get diveSites_edit_hazards_label => 'Dangers';

  @override
  String get diveSites_edit_marineLife_addButton => 'Ajouter';

  @override
  String get diveSites_edit_marineLife_empty =>
      'Aucune espece attendue ajoutee';

  @override
  String get diveSites_edit_marineLife_helperText =>
      'Especes que tu t\'attends a voir sur ce site';

  @override
  String get diveSites_edit_rating_clear => 'Effacer l\'evaluation';

  @override
  String diveSites_edit_rating_starTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count etoile$_temp0';
  }

  @override
  String get diveSites_edit_section_access => 'Acces et logistique';

  @override
  String get diveSites_edit_section_altitude => 'Altitude';

  @override
  String get diveSites_edit_section_depthRange => 'Plage de profondeur';

  @override
  String get diveSites_edit_section_difficultyLevel => 'Niveau de difficulte';

  @override
  String get diveSites_edit_section_expectedMarineLife => 'Vie marine attendue';

  @override
  String get diveSites_edit_section_gpsCoordinates => 'Coordonnees GPS';

  @override
  String get diveSites_edit_section_hazards => 'Dangers et securite';

  @override
  String get diveSites_edit_section_rating => 'Evaluation';

  @override
  String diveSites_edit_snackbar_errorDeleting(Object error) {
    return 'Erreur de suppression du site : $error';
  }

  @override
  String diveSites_edit_snackbar_errorSaving(Object error) {
    return 'Erreur d\'enregistrement du site : $error';
  }

  @override
  String get diveSites_edit_snackbar_locationCaptured => 'Position capturee';

  @override
  String diveSites_edit_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Position capturee (${accuracy}m)';
  }

  @override
  String get diveSites_edit_snackbar_locationSelectedFromMap =>
      'Position selectionnee sur la carte';

  @override
  String get diveSites_edit_snackbar_locationSettings => 'Parametres';

  @override
  String get diveSites_edit_snackbar_locationUnavailableDesktop =>
      'Impossible d\'obtenir la position. Les services de localisation peuvent ne pas etre disponibles.';

  @override
  String get diveSites_edit_snackbar_locationUnavailableMobile =>
      'Impossible d\'obtenir la position. Veuillez verifier les autorisations.';

  @override
  String get diveSites_edit_snackbar_siteAdded => 'Site ajoute';

  @override
  String get diveSites_edit_snackbar_siteUpdated => 'Site mis a jour';

  @override
  String get diveSites_fab_label => 'Ajouter un site';

  @override
  String get diveSites_fab_tooltip => 'Ajouter un nouveau site de plongee';

  @override
  String get diveSites_filter_apply => 'Appliquer les filtres';

  @override
  String get diveSites_filter_cancel => 'Annuler';

  @override
  String get diveSites_filter_clearAll => 'Tout effacer';

  @override
  String get diveSites_filter_country_hint => 'ex. Thailande';

  @override
  String get diveSites_filter_country_label => 'Pays';

  @override
  String get diveSites_filter_depth_max_label => 'Max';

  @override
  String get diveSites_filter_depth_min_label => 'Min';

  @override
  String get diveSites_filter_depth_separator => 'a';

  @override
  String get diveSites_filter_difficulty_any => 'Tous';

  @override
  String get diveSites_filter_option_hasCoordinates_subtitle =>
      'Afficher uniquement les sites avec position GPS';

  @override
  String get diveSites_filter_option_hasCoordinates_title => 'Avec coordonnees';

  @override
  String get diveSites_filter_option_hasDives_subtitle =>
      'Afficher uniquement les sites avec des plongees enregistrees';

  @override
  String get diveSites_filter_option_hasDives_title => 'Avec plongees';

  @override
  String diveSites_filter_rating_starsPlus(Object count) {
    return '$count+ etoiles';
  }

  @override
  String get diveSites_filter_region_hint => 'ex. Phuket';

  @override
  String get diveSites_filter_region_label => 'Region';

  @override
  String get diveSites_filter_section_depthRange => 'Plage de profondeur max';

  @override
  String get diveSites_filter_section_difficulty => 'Difficulte';

  @override
  String get diveSites_filter_section_location => 'Lieu';

  @override
  String get diveSites_filter_section_minRating => 'Evaluation minimale';

  @override
  String get diveSites_filter_section_options => 'Options';

  @override
  String get diveSites_filter_title => 'Filtrer les sites';

  @override
  String get diveSites_import_appBar_title => 'Importer un site de plongee';

  @override
  String get diveSites_import_badge_imported => 'Importe';

  @override
  String get diveSites_import_badge_saved => 'Enregistre';

  @override
  String get diveSites_import_button_import => 'Importer';

  @override
  String get diveSites_import_detail_alreadyImported => 'Deja importe';

  @override
  String get diveSites_import_detail_importToMySites =>
      'Importer dans mes sites';

  @override
  String diveSites_import_detail_source(Object source) {
    return 'Source : $source';
  }

  @override
  String get diveSites_import_empty_description =>
      'Recherche des sites de plongee dans notre base de donnees\nde destinations populaires a travers le monde.';

  @override
  String get diveSites_import_empty_hint =>
      'Essaie de rechercher par nom de site, pays ou region.';

  @override
  String get diveSites_import_empty_title => 'Rechercher des sites de plongee';

  @override
  String get diveSites_import_error_retry => 'Reessayer';

  @override
  String get diveSites_import_error_title => 'Erreur de recherche';

  @override
  String get diveSites_import_error_unknown => 'Erreur inconnue';

  @override
  String get diveSites_import_externalSite_locationUnknown => 'Lieu inconnu';

  @override
  String get diveSites_import_label_gps => 'GPS';

  @override
  String get diveSites_import_localSite_locationNotSet =>
      'Position non definie';

  @override
  String diveSites_import_noResults_description(Object query) {
    return 'Aucun site de plongee trouve pour \"$query\".\nEssaie un autre terme de recherche.';
  }

  @override
  String get diveSites_import_noResults_title => 'Aucun resultat';

  @override
  String get diveSites_import_quickSearch_caribbean => 'Caraibes';

  @override
  String get diveSites_import_quickSearch_indonesia => 'Indonesie';

  @override
  String get diveSites_import_quickSearch_maldives => 'Maldives';

  @override
  String get diveSites_import_quickSearch_philippines => 'Philippines';

  @override
  String get diveSites_import_quickSearch_redSea => 'Mer Rouge';

  @override
  String get diveSites_import_quickSearch_thailand => 'Thailande';

  @override
  String get diveSites_import_search_clearTooltip => 'Effacer la recherche';

  @override
  String get diveSites_import_search_hint =>
      'Rechercher des sites de plongee (ex. \"Blue Hole\", \"Thailande\")';

  @override
  String diveSites_import_section_importFromDatabase(Object count) {
    return 'Importer depuis la base de donnees ($count)';
  }

  @override
  String diveSites_import_section_mySites(Object count) {
    return 'Mes sites ($count)';
  }

  @override
  String diveSites_import_semantics_viewDetails(Object name) {
    return 'Voir les details de $name';
  }

  @override
  String diveSites_import_semantics_viewSavedSite(Object name) {
    return 'Voir le site enregistre $name';
  }

  @override
  String get diveSites_import_snackbar_failed =>
      'Echec de l\'importation du site';

  @override
  String diveSites_import_snackbar_imported(Object name) {
    return '\"$name\" importe';
  }

  @override
  String get diveSites_import_snackbar_viewAction => 'Voir';

  @override
  String get diveSites_list_activeFilter_clear => 'Effacer';

  @override
  String diveSites_list_activeFilter_country(Object country) {
    return 'Pays : $country';
  }

  @override
  String diveSites_list_activeFilter_depthRangeBoth(Object min, Object max) {
    return '$min-${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'Jusqu\'à ${max}m';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '${min}m+';
  }

  @override
  String get diveSites_list_activeFilter_hasCoordinates => 'Avec coordonnees';

  @override
  String get diveSites_list_activeFilter_hasDives => 'Avec plongees';

  @override
  String diveSites_list_activeFilter_region(Object region) {
    return 'Region : $region';
  }

  @override
  String get diveSites_list_appBar_title => 'Sites de plongee';

  @override
  String get diveSites_list_bulkDelete_cancel => 'Annuler';

  @override
  String get diveSites_list_bulkDelete_confirm => 'Supprimer';

  @override
  String diveSites_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sites',
      one: 'site',
    );
    return 'Es-tu sur de vouloir supprimer $count $_temp0 ? Cette action peut etre annulee dans les 5 secondes.';
  }

  @override
  String get diveSites_list_bulkDelete_restored => 'Sites restaures';

  @override
  String diveSites_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sites supprimes',
      one: 'site supprime',
    );
    return '$count $_temp0';
  }

  @override
  String get diveSites_list_bulkDelete_title => 'Supprimer les sites';

  @override
  String get diveSites_list_bulkDelete_undo => 'Annuler';

  @override
  String get diveSites_list_emptyFiltered_clearAll =>
      'Effacer tous les filtres';

  @override
  String get diveSites_list_emptyFiltered_subtitle =>
      'Essaie d\'ajuster ou d\'effacer tes filtres';

  @override
  String get diveSites_list_emptyFiltered_title =>
      'Aucun site ne correspond a tes filtres';

  @override
  String get diveSites_list_empty_addFirstSite => 'Ajouter ton premier site';

  @override
  String get diveSites_list_empty_import => 'Importer';

  @override
  String get diveSites_list_empty_subtitle =>
      'Ajoute des sites de plongee pour suivre tes lieux preferes';

  @override
  String get diveSites_list_empty_title => 'Aucun site de plongee';

  @override
  String diveSites_list_error_loadingSites(Object error) {
    return 'Erreur de chargement des sites : $error';
  }

  @override
  String get diveSites_list_error_retry => 'Reessayer';

  @override
  String get diveSites_list_menu_import => 'Importer';

  @override
  String get diveSites_list_search_backTooltip => 'Retour';

  @override
  String get diveSites_list_search_clearTooltip => 'Effacer la recherche';

  @override
  String get diveSites_list_search_emptyHint =>
      'Rechercher par nom de site, pays ou region';

  @override
  String diveSites_list_search_error(Object error) {
    return 'Erreur : $error';
  }

  @override
  String diveSites_list_search_noResults(Object query) {
    return 'Aucun site trouve pour \"$query\"';
  }

  @override
  String get diveSites_list_search_placeholder => 'Rechercher des sites...';

  @override
  String get diveSites_list_selection_closeTooltip => 'Fermer la selection';

  @override
  String diveSites_list_selection_count(Object count) {
    return '$count selectionne(s)';
  }

  @override
  String get diveSites_list_selection_deleteTooltip => 'Supprimer la selection';

  @override
  String get diveSites_list_selection_deselectAllTooltip =>
      'Tout deselectionner';

  @override
  String get diveSites_list_selection_selectAllTooltip => 'Tout selectionner';

  @override
  String get diveSites_list_sort_title => 'Trier les sites';

  @override
  String diveSites_list_tile_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongees',
      one: '1 plongee',
    );
    return '$_temp0';
  }

  @override
  String diveSites_list_tile_semantics(Object name) {
    return 'Site de plongee : $name';
  }

  @override
  String get diveSites_list_tooltip_filterSites => 'Filtrer les sites';

  @override
  String get diveSites_list_tooltip_mapView => 'Vue carte';

  @override
  String get diveSites_list_tooltip_searchSites => 'Rechercher des sites';

  @override
  String get diveSites_list_tooltip_sort => 'Trier';

  @override
  String get diveSites_locationPicker_appBar_title => 'Choisir un emplacement';

  @override
  String get diveSites_locationPicker_confirmButton => 'Confirmer';

  @override
  String get diveSites_locationPicker_confirmTooltip =>
      'Confirmer l\'emplacement selectionne';

  @override
  String get diveSites_locationPicker_fab_tooltip => 'Utiliser ma position';

  @override
  String get diveSites_locationPicker_instruction_locationSelected =>
      'Emplacement selectionne';

  @override
  String get diveSites_locationPicker_instruction_lookingUp =>
      'Recherche de l\'emplacement...';

  @override
  String get diveSites_locationPicker_instruction_tapToSelect =>
      'Appuie sur la carte pour selectionner un emplacement';

  @override
  String get diveSites_locationPicker_label_latitude => 'Latitude';

  @override
  String get diveSites_locationPicker_label_longitude => 'Longitude';

  @override
  String diveSites_locationPicker_semantics_coordinates(
    Object latitude,
    Object longitude,
  ) {
    return 'Coordonnees selectionnees : latitude $latitude, longitude $longitude';
  }

  @override
  String get diveSites_locationPicker_semantics_lookingUp =>
      'Recherche de l\'emplacement';

  @override
  String get diveSites_locationPicker_semantics_map =>
      'Carte interactive pour choisir l\'emplacement d\'un site de plongee. Appuie sur la carte pour selectionner un emplacement.';

  @override
  String diveSites_mapContent_error_loadingDiveSites(Object error) {
    return 'Erreur de chargement des sites de plongee : $error';
  }

  @override
  String get diveSites_map_appBar_title => 'Sites de plongee';

  @override
  String get diveSites_map_empty_description =>
      'Ajoute des coordonnees a tes sites de plongee pour les voir sur la carte';

  @override
  String get diveSites_map_empty_title => 'Aucun site avec coordonnees';

  @override
  String diveSites_map_error_loadingSites(Object error) {
    return 'Erreur de chargement des sites : $error';
  }

  @override
  String get diveSites_map_error_retry => 'Reessayer';

  @override
  String diveSites_map_infoCard_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongees',
      one: '1 plongee',
    );
    return '$_temp0';
  }

  @override
  String diveSites_map_semantics_diveSiteMarker(Object name) {
    return 'Site de plongee : $name';
  }

  @override
  String get diveSites_map_tooltip_fitAllSites => 'Afficher tous les sites';

  @override
  String get diveSites_map_tooltip_listView => 'Vue liste';

  @override
  String get diveSites_summary_action_addSite => 'Ajouter un site';

  @override
  String get diveSites_summary_action_import => 'Importer';

  @override
  String get diveSites_summary_action_viewMap => 'Voir la carte';

  @override
  String diveSites_summary_countriesMore(Object count) {
    return '+ $count de plus';
  }

  @override
  String get diveSites_summary_header_subtitle =>
      'Selectionne un site dans la liste pour voir les details';

  @override
  String get diveSites_summary_header_title => 'Sites de plongee';

  @override
  String get diveSites_summary_section_countriesRegions => 'Pays et regions';

  @override
  String get diveSites_summary_section_mostDived => 'Les plus plonges';

  @override
  String get diveSites_summary_section_overview => 'Apercu';

  @override
  String get diveSites_summary_section_quickActions => 'Actions rapides';

  @override
  String get diveSites_summary_section_topRated => 'Mieux notes';

  @override
  String get diveSites_summary_stat_avgRating => 'Note moyenne';

  @override
  String get diveSites_summary_stat_totalDives => 'Total plongees';

  @override
  String get diveSites_summary_stat_totalSites => 'Total sites';

  @override
  String get diveSites_summary_stat_withGps => 'Avec GPS';

  @override
  String get diveTypes_addDialog_addButton => 'Ajouter';

  @override
  String get diveTypes_addDialog_nameHint => 'ex. Recherche et récupération';

  @override
  String get diveTypes_addDialog_nameLabel => 'Nom du type de plongée';

  @override
  String get diveTypes_addDialog_nameValidation => 'Veuillez entrer un nom';

  @override
  String get diveTypes_addDialog_title =>
      'Ajouter un type de plongée personnalisé';

  @override
  String get diveTypes_addTooltip => 'Ajouter un type de plongée';

  @override
  String get diveTypes_appBar_title => 'Types de plongée';

  @override
  String get diveTypes_builtIn => 'Intégré';

  @override
  String get diveTypes_builtInHeader => 'Types de plongée intégrés';

  @override
  String get diveTypes_custom => 'Personnalisé';

  @override
  String get diveTypes_customHeader => 'Types de plongée personnalisés';

  @override
  String diveTypes_deleteDialog_content(Object name) {
    return 'Voulez-vous vraiment supprimer « $name » ?';
  }

  @override
  String get diveTypes_deleteDialog_title => 'Supprimer le type de plongée ?';

  @override
  String get diveTypes_deleteTooltip => 'Supprimer le type de plongée';

  @override
  String diveTypes_snackbar_added(Object name) {
    return 'Type de plongée ajouté : $name';
  }

  @override
  String diveTypes_snackbar_cannotDelete(Object name) {
    return 'Impossible de supprimer « $name » - il est utilisé par des plongées existantes';
  }

  @override
  String diveTypes_snackbar_deleted(Object name) {
    return '« $name » supprimé';
  }

  @override
  String diveTypes_snackbar_errorAdding(Object error) {
    return 'Erreur lors de l\'ajout du type de plongée : $error';
  }

  @override
  String diveTypes_snackbar_errorDeleting(Object error) {
    return 'Erreur lors de la suppression du type de plongée : $error';
  }

  @override
  String get divers_detail_activeDiver => 'Plongeur actif';

  @override
  String get divers_detail_allergiesLabel => 'Allergies';

  @override
  String get divers_detail_appBarTitle => 'Plongeur';

  @override
  String get divers_detail_bloodTypeLabel => 'Groupe sanguin';

  @override
  String get divers_detail_bottomTimeLabel => 'Temps au fond';

  @override
  String get divers_detail_cancelButton => 'Annuler';

  @override
  String get divers_detail_contactTitle => 'Contact';

  @override
  String get divers_detail_defaultLabel => 'Par defaut';

  @override
  String get divers_detail_deleteButton => 'Supprimer';

  @override
  String divers_detail_deleteDialogContent(Object name) {
    return 'Voulez-vous vraiment supprimer $name ? Tous les carnets de plongee associes seront desaffectes.';
  }

  @override
  String get divers_detail_deleteDialogTitle => 'Supprimer le plongeur ?';

  @override
  String divers_detail_deleteError(Object error) {
    return 'Echec de la suppression : $error';
  }

  @override
  String get divers_detail_deleteMenuItem => 'Supprimer';

  @override
  String get divers_detail_deletedSnackbar => 'Plongeur supprime';

  @override
  String get divers_detail_diveInsuranceTitle => 'Assurance plongee';

  @override
  String get divers_detail_diveStatisticsTitle => 'Statistiques de plongee';

  @override
  String get divers_detail_editTooltip => 'Modifier le plongeur';

  @override
  String get divers_detail_emergencyContactTitle => 'Contact d\'urgence';

  @override
  String divers_detail_errorPrefix(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get divers_detail_expiredBadge => 'Expire';

  @override
  String get divers_detail_expiresLabel => 'Expire le';

  @override
  String get divers_detail_medicalInfoTitle => 'Informations medicales';

  @override
  String get divers_detail_medicalNotesLabel => 'Notes';

  @override
  String get divers_detail_notFound => 'Plongeur introuvable';

  @override
  String get divers_detail_notesTitle => 'Notes';

  @override
  String get divers_detail_policyNumberLabel => 'N de police';

  @override
  String get divers_detail_providerLabel => 'Assureur';

  @override
  String get divers_detail_setAsDefault => 'Definir par defaut';

  @override
  String divers_detail_setAsDefaultSnackbar(Object name) {
    return '$name defini comme plongeur par defaut';
  }

  @override
  String get divers_detail_switchToTooltip => 'Basculer vers ce plongeur';

  @override
  String divers_detail_switchedTo(Object name) {
    return 'Bascule vers $name';
  }

  @override
  String get divers_detail_totalDivesLabel => 'Total des plongees';

  @override
  String get divers_detail_unableToLoadStats =>
      'Impossible de charger les statistiques';

  @override
  String get divers_edit_addButton => 'Ajouter un plongeur';

  @override
  String get divers_edit_addTitle => 'Ajouter un plongeur';

  @override
  String get divers_edit_allergiesHint => 'ex. Penicilline, Fruits de mer';

  @override
  String get divers_edit_allergiesLabel => 'Allergies';

  @override
  String get divers_edit_bloodTypeHint => 'ex. O+, A-, B+';

  @override
  String get divers_edit_bloodTypeLabel => 'Groupe sanguin';

  @override
  String get divers_edit_cancelButton => 'Annuler';

  @override
  String get divers_edit_clearInsuranceExpiryTooltip =>
      'Effacer la date d\'expiration de l\'assurance';

  @override
  String get divers_edit_clearMedicalClearanceTooltip =>
      'Effacer la date de certificat medical';

  @override
  String get divers_edit_contactNameLabel => 'Nom du contact';

  @override
  String get divers_edit_contactPhoneLabel => 'Telephone du contact';

  @override
  String get divers_edit_discardButton => 'Abandonner';

  @override
  String get divers_edit_discardDialogContent =>
      'Tu as des modifications non enregistrees. Veux-tu vraiment les abandonner ?';

  @override
  String get divers_edit_discardDialogTitle => 'Abandonner les modifications ?';

  @override
  String get divers_edit_diverAdded => 'Plongeur ajoute';

  @override
  String get divers_edit_diverUpdated => 'Plongeur mis a jour';

  @override
  String get divers_edit_editTitle => 'Modifier le plongeur';

  @override
  String get divers_edit_emailError => 'Entrez un e-mail valide';

  @override
  String get divers_edit_emailLabel => 'E-mail';

  @override
  String get divers_edit_emergencyContactsSection => 'Contacts d\'urgence';

  @override
  String divers_edit_errorLoading(Object error) {
    return 'Erreur lors du chargement du plongeur : $error';
  }

  @override
  String divers_edit_errorSaving(Object error) {
    return 'Erreur lors de l\'enregistrement du plongeur : $error';
  }

  @override
  String get divers_edit_expiryDateNotSet => 'Non defini';

  @override
  String get divers_edit_expiryDateTitle => 'Date d\'expiration';

  @override
  String get divers_edit_insuranceProviderHint => 'ex. DAN, DiveAssure';

  @override
  String get divers_edit_insuranceProviderLabel => 'Assureur';

  @override
  String get divers_edit_insuranceSection => 'Assurance plongee';

  @override
  String get divers_edit_keepEditingButton => 'Continuer a modifier';

  @override
  String get divers_edit_medicalClearanceExpired => 'Expire';

  @override
  String get divers_edit_medicalClearanceExpiringSoon => 'Expire bientot';

  @override
  String get divers_edit_medicalClearanceNotSet => 'Non defini';

  @override
  String get divers_edit_medicalClearanceTitle =>
      'Expiration du certificat medical';

  @override
  String get divers_edit_medicalInfoSection => 'Informations medicales';

  @override
  String get divers_edit_medicalNotesLabel => 'Notes medicales';

  @override
  String get divers_edit_medicationsHint => 'ex. Aspirine quotidienne, EpiPen';

  @override
  String get divers_edit_medicationsLabel => 'Medicaments';

  @override
  String get divers_edit_nameError => 'Le nom est requis';

  @override
  String get divers_edit_nameLabel => 'Nom *';

  @override
  String get divers_edit_notesLabel => 'Notes';

  @override
  String get divers_edit_notesSection => 'Notes';

  @override
  String get divers_edit_personalInfoSection => 'Informations personnelles';

  @override
  String get divers_edit_phoneLabel => 'Telephone';

  @override
  String get divers_edit_policyNumberLabel => 'Numero de police';

  @override
  String get divers_edit_primaryContactTitle => 'Contact principal';

  @override
  String get divers_edit_relationshipHint => 'ex. Conjoint, Parent, Ami';

  @override
  String get divers_edit_relationshipLabel => 'Lien de parente';

  @override
  String get divers_edit_saveButton => 'Enregistrer';

  @override
  String get divers_edit_secondaryContactTitle => 'Contact secondaire';

  @override
  String get divers_edit_selectInsuranceExpiryTooltip =>
      'Selectionner la date d\'expiration de l\'assurance';

  @override
  String get divers_edit_selectMedicalClearanceTooltip =>
      'Selectionner la date du certificat medical';

  @override
  String get divers_edit_updateButton => 'Mettre a jour le plongeur';

  @override
  String get divers_list_activeBadge => 'Actif';

  @override
  String get divers_list_addDiverButton => 'Ajouter un plongeur';

  @override
  String get divers_list_addDiverTooltip =>
      'Ajouter un nouveau profil de plongeur';

  @override
  String get divers_list_appBarTitle => 'Profils de plongeurs';

  @override
  String get divers_list_compactTitle => 'Plongeurs';

  @override
  String divers_list_diverStats(Object diveCount, Object bottomTime) {
    return '$diveCount plongees$bottomTime';
  }

  @override
  String get divers_list_emptySubtitle =>
      'Ajoutez des profils de plongeurs pour suivre les carnets de plongee de plusieurs personnes';

  @override
  String get divers_list_emptyTitle => 'Aucun plongeur';

  @override
  String divers_list_errorLoading(Object error) {
    return 'Erreur lors du chargement des plongeurs : $error';
  }

  @override
  String get divers_list_errorLoadingStats =>
      'Erreur lors du chargement des statistiques';

  @override
  String get divers_list_loadingStats => 'Chargement...';

  @override
  String get divers_list_retryButton => 'Reessayer';

  @override
  String divers_list_viewDiverLabel(Object name) {
    return 'Voir le plongeur $name';
  }

  @override
  String get divers_summary_activeDiverTitle => 'Plongeur actif';

  @override
  String get divers_summary_otherDiversTitle => 'Autres plongeurs';

  @override
  String get divers_summary_overviewTitle => 'Apercu';

  @override
  String get divers_summary_quickActionsTitle => 'Actions rapides';

  @override
  String get divers_summary_subtitle =>
      'Selectionnez un plongeur dans la liste pour voir les details';

  @override
  String get divers_summary_title => 'Profils de plongeurs';

  @override
  String get divers_summary_totalDiversLabel => 'Total des plongeurs';

  @override
  String get enum_altitudeGroup_extreme => 'Altitude extreme';

  @override
  String get enum_altitudeGroup_extreme_range => '>2700m (>8858ft)';

  @override
  String get enum_altitudeGroup_group1 => 'Groupe d\'altitude 1';

  @override
  String get enum_altitudeGroup_group1_range => '300-900m (984-2953ft)';

  @override
  String get enum_altitudeGroup_group2 => 'Groupe d\'altitude 2';

  @override
  String get enum_altitudeGroup_group2_range => '900-1800m (2953-5906ft)';

  @override
  String get enum_altitudeGroup_group3 => 'Groupe d\'altitude 3';

  @override
  String get enum_altitudeGroup_group3_range => '1800-2700m (5906-8858ft)';

  @override
  String get enum_altitudeGroup_seaLevel => 'Niveau de la mer';

  @override
  String get enum_altitudeGroup_seaLevel_range => '0-300m (0-984ft)';

  @override
  String get enum_ascentRate_danger => 'Danger';

  @override
  String get enum_ascentRate_safe => 'Normal';

  @override
  String get enum_ascentRate_warning => 'Attention';

  @override
  String get enum_buddyRole_buddy => 'Binome';

  @override
  String get enum_buddyRole_diveGuide => 'Guide de plongee';

  @override
  String get enum_buddyRole_diveMaster => 'Directeur de plongee';

  @override
  String get enum_buddyRole_instructor => 'Moniteur';

  @override
  String get enum_buddyRole_solo => 'Solo';

  @override
  String get enum_buddyRole_student => 'Eleve';

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
  String get enum_certificationAgency_other => 'Autre';

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
  String get enum_certificationLevel_advancedNitrox => 'Nitrox avance';

  @override
  String get enum_certificationLevel_advancedOpenWater =>
      'Plongeur autonome avance';

  @override
  String get enum_certificationLevel_cave => 'Plongee souterraine';

  @override
  String get enum_certificationLevel_cavern => 'Plongee en caverne';

  @override
  String get enum_certificationLevel_courseDirector => 'Directeur de cours';

  @override
  String get enum_certificationLevel_decompression => 'Decompression';

  @override
  String get enum_certificationLevel_diveMaster => 'Directeur de plongee';

  @override
  String get enum_certificationLevel_instructor => 'Moniteur';

  @override
  String get enum_certificationLevel_masterInstructor => 'Moniteur principal';

  @override
  String get enum_certificationLevel_nitrox => 'Nitrox';

  @override
  String get enum_certificationLevel_openWater => 'Plongeur autonome';

  @override
  String get enum_certificationLevel_other => 'Autre';

  @override
  String get enum_certificationLevel_rebreather => 'Recycleur';

  @override
  String get enum_certificationLevel_rescue => 'Plongeur sauveteur';

  @override
  String get enum_certificationLevel_sidemount => 'Sidemount';

  @override
  String get enum_certificationLevel_techDiver => 'Plongeur technique';

  @override
  String get enum_certificationLevel_trimix => 'Trimix';

  @override
  String get enum_certificationLevel_wreck => 'Epave';

  @override
  String get enum_currentDirection_east => 'Est';

  @override
  String get enum_currentDirection_none => 'Aucun';

  @override
  String get enum_currentDirection_north => 'Nord';

  @override
  String get enum_currentDirection_northEast => 'Nord-Est';

  @override
  String get enum_currentDirection_northWest => 'Nord-Ouest';

  @override
  String get enum_currentDirection_south => 'Sud';

  @override
  String get enum_currentDirection_southEast => 'Sud-Est';

  @override
  String get enum_currentDirection_southWest => 'Sud-Ouest';

  @override
  String get enum_currentDirection_variable => 'Variable';

  @override
  String get enum_currentDirection_west => 'Ouest';

  @override
  String get enum_currentStrength_light => 'Faible';

  @override
  String get enum_currentStrength_moderate => 'Modere';

  @override
  String get enum_currentStrength_none => 'Aucun';

  @override
  String get enum_currentStrength_strong => 'Fort';

  @override
  String get enum_diveMode_ccr => 'Recycleur a circuit ferme';

  @override
  String get enum_diveMode_oc => 'Circuit ouvert';

  @override
  String get enum_diveMode_scr => 'Recycleur semi-ferme';

  @override
  String get enum_diveType_altitude => 'Altitude';

  @override
  String get enum_diveType_boat => 'Bateau';

  @override
  String get enum_diveType_cave => 'Grotte';

  @override
  String get enum_diveType_deep => 'Profonde';

  @override
  String get enum_diveType_drift => 'Derivante';

  @override
  String get enum_diveType_freedive => 'Apnee';

  @override
  String get enum_diveType_ice => 'Sous glace';

  @override
  String get enum_diveType_liveaboard => 'Croisiere';

  @override
  String get enum_diveType_night => 'Nuit';

  @override
  String get enum_diveType_recreational => 'Loisir';

  @override
  String get enum_diveType_shore => 'Du bord';

  @override
  String get enum_diveType_technical => 'Technique';

  @override
  String get enum_diveType_training => 'Formation';

  @override
  String get enum_diveType_wreck => 'Epave';

  @override
  String get enum_entryMethod_backRoll => 'Bascule arriere';

  @override
  String get enum_entryMethod_boat => 'Mise a l\'eau depuis le bateau';

  @override
  String get enum_entryMethod_giantStride => 'Pas de geant';

  @override
  String get enum_entryMethod_jetty => 'Ponton/Quai';

  @override
  String get enum_entryMethod_ladder => 'Echelle';

  @override
  String get enum_entryMethod_other => 'Autre';

  @override
  String get enum_entryMethod_platform => 'Plateforme';

  @override
  String get enum_entryMethod_seatedEntry => 'Mise a l\'eau assise';

  @override
  String get enum_entryMethod_shore => 'Mise a l\'eau du bord';

  @override
  String get enum_equipmentStatus_active => 'Actif';

  @override
  String get enum_equipmentStatus_inService => 'En revision';

  @override
  String get enum_equipmentStatus_loaned => 'Prete';

  @override
  String get enum_equipmentStatus_lost => 'Perdu';

  @override
  String get enum_equipmentStatus_needsService => 'Revision necessaire';

  @override
  String get enum_equipmentStatus_retired => 'Reforme';

  @override
  String get enum_equipmentType_bcd => 'Gilet stabilisateur';

  @override
  String get enum_equipmentType_boots => 'Bottillons';

  @override
  String get enum_equipmentType_camera => 'Camera';

  @override
  String get enum_equipmentType_computer => 'Ordinateur de plongee';

  @override
  String get enum_equipmentType_drysuit => 'Combinaison etanche';

  @override
  String get enum_equipmentType_fins => 'Palmes';

  @override
  String get enum_equipmentType_gloves => 'Gants';

  @override
  String get enum_equipmentType_hood => 'Cagoule';

  @override
  String get enum_equipmentType_knife => 'Couteau';

  @override
  String get enum_equipmentType_light => 'Phare';

  @override
  String get enum_equipmentType_mask => 'Masque';

  @override
  String get enum_equipmentType_other => 'Autre';

  @override
  String get enum_equipmentType_reel => 'Devidoir';

  @override
  String get enum_equipmentType_regulator => 'Detendeur';

  @override
  String get enum_equipmentType_smb => 'Parachute de palier';

  @override
  String get enum_equipmentType_tank => 'Bloc';

  @override
  String get enum_equipmentType_weights => 'Lest';

  @override
  String get enum_equipmentType_wetsuit => 'Combinaison';

  @override
  String get enum_eventSeverity_alert => 'Alerte';

  @override
  String get enum_eventSeverity_info => 'Info';

  @override
  String get enum_eventSeverity_warning => 'Avertissement';

  @override
  String get enum_pdfPageSize_a4 => 'A4';

  @override
  String get enum_pdfPageSize_a4_description => '210 x 297 mm';

  @override
  String get enum_pdfPageSize_letter => 'Letter';

  @override
  String get enum_pdfPageSize_letter_description => '8.5 x 11 in';

  @override
  String get enum_pdfTemplate_detailed => 'Detaille';

  @override
  String get enum_pdfTemplate_detailed_description =>
      'Informations completes avec notes et evaluations';

  @override
  String get enum_pdfTemplate_nauiStyle => 'Style NAUI';

  @override
  String get enum_pdfTemplate_nauiStyle_description =>
      'Mise en page au format carnet NAUI';

  @override
  String get enum_pdfTemplate_padiStyle => 'Style PADI';

  @override
  String get enum_pdfTemplate_padiStyle_description =>
      'Mise en page au format carnet PADI';

  @override
  String get enum_pdfTemplate_professional => 'Professionnel';

  @override
  String get enum_pdfTemplate_professional_description =>
      'Zones de signature et de tampon pour verification';

  @override
  String get enum_pdfTemplate_simple => 'Simple';

  @override
  String get enum_pdfTemplate_simple_description =>
      'Format tableau compact, plusieurs plongees par page';

  @override
  String get enum_profileEvent_alert => 'Alerte';

  @override
  String get enum_profileEvent_ascentRateCritical =>
      'Vitesse de remontee critique';

  @override
  String get enum_profileEvent_ascentRateWarning =>
      'Avertissement vitesse de remontee';

  @override
  String get enum_profileEvent_ascentStart => 'Debut de remontee';

  @override
  String get enum_profileEvent_bookmark => 'Signet';

  @override
  String get enum_profileEvent_cnsCritical => 'CNS critique';

  @override
  String get enum_profileEvent_cnsWarning => 'Avertissement CNS';

  @override
  String get enum_profileEvent_decoStopEnd => 'Fin du palier de decompression';

  @override
  String get enum_profileEvent_decoStopStart =>
      'Debut du palier de decompression';

  @override
  String get enum_profileEvent_decoViolation => 'Violation de palier';

  @override
  String get enum_profileEvent_descentEnd => 'Fin de descente';

  @override
  String get enum_profileEvent_descentStart => 'Debut de descente';

  @override
  String get enum_profileEvent_gasSwitch => 'Changement de gaz';

  @override
  String get enum_profileEvent_lowGas => 'Alerte gaz faible';

  @override
  String get enum_profileEvent_maxDepth => 'Profondeur max';

  @override
  String get enum_profileEvent_missedStop => 'Palier de decompression manque';

  @override
  String get enum_profileEvent_note => 'Note';

  @override
  String get enum_profileEvent_ppO2High => 'ppO2 elevee';

  @override
  String get enum_profileEvent_ppO2Low => 'ppO2 basse';

  @override
  String get enum_profileEvent_safetyStopEnd => 'Fin du palier de securite';

  @override
  String get enum_profileEvent_safetyStopStart => 'Debut du palier de securite';

  @override
  String get enum_profileEvent_setpointChange => 'Changement de consigne';

  @override
  String get enum_profileMetricCategory_decompression => 'Decompression';

  @override
  String get enum_profileMetricCategory_gasAnalysis => 'Analyse des gaz';

  @override
  String get enum_profileMetricCategory_gradientFactor =>
      'Facteurs de gradient';

  @override
  String get enum_profileMetricCategory_other => 'Autre';

  @override
  String get enum_profileMetricCategory_primary => 'Metriques principales';

  @override
  String get enum_profileMetric_gasDensity => 'Densite du gaz';

  @override
  String get enum_profileMetric_gasDensity_short => 'Densite';

  @override
  String get enum_profileMetric_gf => 'GF%';

  @override
  String get enum_profileMetric_gf_short => 'GF%';

  @override
  String get enum_profileMetric_heartRate => 'Frequence cardiaque';

  @override
  String get enum_profileMetric_heartRate_short => 'FC';

  @override
  String get enum_profileMetric_meanDepth => 'Profondeur moyenne';

  @override
  String get enum_profileMetric_meanDepth_short => 'Moy';

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
  String get enum_profileMetric_pressure => 'Pression';

  @override
  String get enum_profileMetric_pressure_short => 'Press';

  @override
  String get enum_profileMetric_sacRate => 'Consommation SAC';

  @override
  String get enum_profileMetric_sacRate_short => 'SAC';

  @override
  String get enum_profileMetric_surfaceGf => 'GF surface';

  @override
  String get enum_profileMetric_surfaceGf_short => 'SrfGF';

  @override
  String get enum_profileMetric_temperature => 'Temperature';

  @override
  String get enum_profileMetric_temperature_short => 'Temp';

  @override
  String get enum_profileMetric_tts => 'TTS';

  @override
  String get enum_profileMetric_tts_short => 'TTS';

  @override
  String get enum_scrType_cmf => 'Debit massique constant';

  @override
  String get enum_scrType_cmf_short => 'CMF';

  @override
  String get enum_scrType_escr => 'Controle electronique';

  @override
  String get enum_scrType_escr_short => 'ESCR';

  @override
  String get enum_scrType_pascr => 'Addition passive';

  @override
  String get enum_scrType_pascr_short => 'PASCR';

  @override
  String get enum_serviceType_annual => 'Revision annuelle';

  @override
  String get enum_serviceType_calibration => 'Calibration';

  @override
  String get enum_serviceType_cleaning => 'Nettoyage';

  @override
  String get enum_serviceType_inspection => 'Inspection';

  @override
  String get enum_serviceType_other => 'Autre';

  @override
  String get enum_serviceType_overhaul => 'Revision complete';

  @override
  String get enum_serviceType_recall => 'Rappel/Securite';

  @override
  String get enum_serviceType_repair => 'Reparation';

  @override
  String get enum_serviceType_replacement => 'Remplacement de piece';

  @override
  String get enum_serviceType_warranty => 'Service garantie';

  @override
  String get enum_sortDirection_ascending => 'Croissant';

  @override
  String get enum_sortDirection_descending => 'Decroissant';

  @override
  String get enum_sortField_agency => 'Organisme';

  @override
  String get enum_sortField_date => 'Date';

  @override
  String get enum_sortField_dateIssued => 'Date de delivrance';

  @override
  String get enum_sortField_difficulty => 'Difficulte';

  @override
  String get enum_sortField_diveCount => 'Nombre de plongees';

  @override
  String get enum_sortField_diveNumber => 'Numero de plongee';

  @override
  String get enum_sortField_duration => 'Duree';

  @override
  String get enum_sortField_endDate => 'Date de fin';

  @override
  String get enum_sortField_lastServiceDate => 'Derniere revision';

  @override
  String get enum_sortField_maxDepth => 'Profondeur max';

  @override
  String get enum_sortField_name => 'Nom';

  @override
  String get enum_sortField_purchaseDate => 'Date d\'achat';

  @override
  String get enum_sortField_rating => 'Evaluation';

  @override
  String get enum_sortField_site => 'Site';

  @override
  String get enum_sortField_startDate => 'Date de debut';

  @override
  String get enum_sortField_status => 'Statut';

  @override
  String get enum_sortField_type => 'Type';

  @override
  String get enum_speciesCategory_coral => 'Corail';

  @override
  String get enum_speciesCategory_fish => 'Poisson';

  @override
  String get enum_speciesCategory_invertebrate => 'Invertebre';

  @override
  String get enum_speciesCategory_mammal => 'Mammifere';

  @override
  String get enum_speciesCategory_other => 'Autre';

  @override
  String get enum_speciesCategory_plant => 'Plante/Algue';

  @override
  String get enum_speciesCategory_ray => 'Raie';

  @override
  String get enum_speciesCategory_shark => 'Requin';

  @override
  String get enum_speciesCategory_turtle => 'Tortue';

  @override
  String get enum_tankMaterial_aluminum => 'Aluminium';

  @override
  String get enum_tankMaterial_carbonFiber => 'Fibre de carbone';

  @override
  String get enum_tankMaterial_steel => 'Acier';

  @override
  String get enum_tankRole_backGas => 'Gaz dorsal';

  @override
  String get enum_tankRole_bailout => 'Bailout';

  @override
  String get enum_tankRole_deco => 'Deco';

  @override
  String get enum_tankRole_diluent => 'Diluant';

  @override
  String get enum_tankRole_oxygenSupply => 'Alimentation O₂';

  @override
  String get enum_tankRole_pony => 'Pony bottle';

  @override
  String get enum_tankRole_sidemountLeft => 'Sidemount gauche';

  @override
  String get enum_tankRole_sidemountRight => 'Sidemount droit';

  @override
  String get enum_tankRole_stage => 'Stage';

  @override
  String get enum_visibility_excellent => 'Excellente (>30m / >100ft)';

  @override
  String get enum_visibility_good => 'Bonne (15-30m / 50-100ft)';

  @override
  String get enum_visibility_moderate => 'Moyenne (5-15m / 15-50ft)';

  @override
  String get enum_visibility_poor => 'Mauvaise (<5m / <15ft)';

  @override
  String get enum_visibility_unknown => 'Inconnue';

  @override
  String get enum_waterType_brackish => 'Saumatre';

  @override
  String get enum_waterType_fresh => 'Eau douce';

  @override
  String get enum_waterType_salt => 'Eau salee';

  @override
  String get enum_weightType_ankleWeights => 'Lest de chevilles';

  @override
  String get enum_weightType_backplate => 'Lest de plaque dorsale';

  @override
  String get enum_weightType_belt => 'Ceinture de lest';

  @override
  String get enum_weightType_integrated => 'Lest integre';

  @override
  String get enum_weightType_mixed => 'Mixte/Combine';

  @override
  String get enum_weightType_trimWeights => 'Lest de trim';

  @override
  String get equipment_addSheet_brandHint => 'ex. Scubapro';

  @override
  String get equipment_addSheet_brandLabel => 'Marque';

  @override
  String get equipment_addSheet_closeTooltip => 'Fermer';

  @override
  String get equipment_addSheet_currencyLabel => 'Devise';

  @override
  String get equipment_addSheet_dateLabel => 'Date';

  @override
  String equipment_addSheet_errorSnackbar(Object error) {
    return 'Erreur lors de l\'ajout de l\'equipement : $error';
  }

  @override
  String get equipment_addSheet_modelHint => 'ex. MK25 EVO';

  @override
  String get equipment_addSheet_modelLabel => 'Modele';

  @override
  String get equipment_addSheet_nameHint => 'ex. Mon detendeur principal';

  @override
  String get equipment_addSheet_nameLabel => 'Nom';

  @override
  String get equipment_addSheet_nameValidation => 'Veuillez entrer un nom';

  @override
  String get equipment_addSheet_notesHint => 'Notes supplementaires...';

  @override
  String get equipment_addSheet_notesLabel => 'Notes';

  @override
  String get equipment_addSheet_priceLabel => 'Prix';

  @override
  String get equipment_addSheet_purchaseInfoTitle => 'Informations d\'achat';

  @override
  String get equipment_addSheet_serialNumberLabel => 'Numero de serie';

  @override
  String get equipment_addSheet_serviceIntervalHint => 'ex. 365 pour annuel';

  @override
  String get equipment_addSheet_serviceIntervalLabel =>
      'Intervalle de revision (jours)';

  @override
  String get equipment_addSheet_sizeHint => 'ex. M, L, 42';

  @override
  String get equipment_addSheet_sizeLabel => 'Taille';

  @override
  String get equipment_addSheet_submitButton => 'Ajouter l\'equipement';

  @override
  String get equipment_addSheet_successSnackbar =>
      'Equipement ajoute avec succes';

  @override
  String get equipment_addSheet_title => 'Ajouter un equipement';

  @override
  String get equipment_addSheet_typeLabel => 'Type';

  @override
  String get equipment_appBar_title => 'Equipement';

  @override
  String get equipment_deleteDialog_cancel => 'Annuler';

  @override
  String get equipment_deleteDialog_confirm => 'Supprimer';

  @override
  String get equipment_deleteDialog_content =>
      'Es-tu sur de vouloir supprimer cet equipement ? Cette action est irreversible.';

  @override
  String get equipment_deleteDialog_title => 'Supprimer l\'equipement';

  @override
  String get equipment_detail_brandLabel => 'Marque';

  @override
  String equipment_detail_daysOverdue(Object days) {
    return '$days jours de retard';
  }

  @override
  String equipment_detail_daysUntilService(Object days) {
    return '$days jours avant la revision';
  }

  @override
  String get equipment_detail_detailsTitle => 'Details';

  @override
  String equipment_detail_divesCountPlural(Object count) {
    return '$count plongees';
  }

  @override
  String equipment_detail_divesCountSingular(Object count) {
    return '$count plongee';
  }

  @override
  String get equipment_detail_divesLabel => 'Plongees';

  @override
  String get equipment_detail_divesSemanticLabel =>
      'Voir les plongees utilisant cet equipement';

  @override
  String equipment_detail_durationDays(Object days) {
    return '$days jours';
  }

  @override
  String equipment_detail_durationMonths(Object months) {
    return '$months mois';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralPlural(
    Object years,
    Object months,
  ) {
    return '$years ans, $months mois';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralSingular(
    Object years,
    Object months,
  ) {
    return '$years ans, $months mois';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularPlural(
    Object years,
    Object months,
  ) {
    return '$years an, $months mois';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularSingular(
    Object years,
    Object months,
  ) {
    return '$years an, $months mois';
  }

  @override
  String equipment_detail_durationYearsPlural(Object years) {
    return '$years ans';
  }

  @override
  String equipment_detail_durationYearsSingular(Object years) {
    return '$years an';
  }

  @override
  String get equipment_detail_editTooltip => 'Modifier l\'equipement';

  @override
  String get equipment_detail_editTooltipShort => 'Modifier';

  @override
  String equipment_detail_errorMessage(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get equipment_detail_errorTitle => 'Erreur';

  @override
  String get equipment_detail_lastServiceLabel => 'Derniere revision';

  @override
  String get equipment_detail_loadingTitle => 'Chargement...';

  @override
  String get equipment_detail_modelLabel => 'Modele';

  @override
  String get equipment_detail_nextServiceDueLabel => 'Prochaine revision';

  @override
  String get equipment_detail_notFoundMessage =>
      'Cet equipement n\'existe plus.';

  @override
  String get equipment_detail_notFoundTitle => 'Equipement introuvable';

  @override
  String get equipment_detail_notesTitle => 'Notes';

  @override
  String get equipment_detail_ownedForLabel => 'Possede depuis';

  @override
  String get equipment_detail_purchaseDateLabel => 'Date d\'achat';

  @override
  String get equipment_detail_purchasePriceLabel => 'Prix d\'achat';

  @override
  String get equipment_detail_retiredChip => 'Retire';

  @override
  String get equipment_detail_serialNumberLabel => 'Numero de serie';

  @override
  String get equipment_detail_serviceInfoTitle => 'Informations de revision';

  @override
  String get equipment_detail_serviceIntervalLabel => 'Intervalle de revision';

  @override
  String equipment_detail_serviceIntervalValue(Object days) {
    return '$days jours';
  }

  @override
  String get equipment_detail_serviceOverdue => 'La revision est en retard !';

  @override
  String get equipment_detail_sizeLabel => 'Taille';

  @override
  String get equipment_detail_statusLabel => 'Statut';

  @override
  String equipment_detail_tripsCountPlural(Object count) {
    return '$count voyages';
  }

  @override
  String equipment_detail_tripsCountSingular(Object count) {
    return '$count voyage';
  }

  @override
  String get equipment_detail_tripsLabel => 'Voyages';

  @override
  String get equipment_detail_tripsSemanticLabel =>
      'Voir les voyages utilisant cet equipement';

  @override
  String get equipment_edit_appBar_editTitle => 'Modifier l\'equipement';

  @override
  String get equipment_edit_appBar_newTitle => 'Nouvel equipement';

  @override
  String get equipment_edit_appBar_saveButton => 'Enregistrer';

  @override
  String get equipment_edit_appBar_saveTooltip =>
      'Enregistrer les modifications de l\'equipement';

  @override
  String get equipment_edit_brandLabel => 'Marque';

  @override
  String get equipment_edit_clearDate => 'Effacer la date';

  @override
  String get equipment_edit_currencyLabel => 'Devise';

  @override
  String get equipment_edit_disableReminders => 'Desactiver les rappels';

  @override
  String get equipment_edit_disableRemindersSubtitle =>
      'Desactiver toutes les notifications pour cet element';

  @override
  String get equipment_edit_discardDialog_content =>
      'Tu as des modifications non enregistrees. Es-tu sur de vouloir quitter ?';

  @override
  String get equipment_edit_discardDialog_discard => 'Abandonner';

  @override
  String get equipment_edit_discardDialog_keepEditing => 'Continuer l\'edition';

  @override
  String get equipment_edit_discardDialog_title =>
      'Abandonner les modifications ?';

  @override
  String get equipment_edit_embeddedHeader_cancelButton => 'Annuler';

  @override
  String get equipment_edit_embeddedHeader_editTitle =>
      'Modifier l\'equipement';

  @override
  String get equipment_edit_embeddedHeader_newTitle => 'Nouvel equipement';

  @override
  String get equipment_edit_embeddedHeader_saveButton => 'Enregistrer';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_edit =>
      'Enregistrer les modifications de l\'equipement';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_new =>
      'Ajouter un nouvel equipement';

  @override
  String equipment_edit_errorMessage(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get equipment_edit_errorTitle => 'Erreur';

  @override
  String get equipment_edit_lastServiceDateLabel => 'Date de derniere revision';

  @override
  String get equipment_edit_loadingTitle => 'Chargement...';

  @override
  String get equipment_edit_modelLabel => 'Modele';

  @override
  String get equipment_edit_nameHint => 'ex. Mon detendeur principal';

  @override
  String get equipment_edit_nameLabel => 'Nom *';

  @override
  String get equipment_edit_nameValidation => 'Veuillez entrer un nom';

  @override
  String get equipment_edit_notFoundMessage => 'Cet equipement n\'existe plus.';

  @override
  String get equipment_edit_notFoundTitle => 'Equipement introuvable';

  @override
  String get equipment_edit_notesHint =>
      'Notes supplementaires sur cet equipement...';

  @override
  String get equipment_edit_notesLabel => 'Notes';

  @override
  String get equipment_edit_notificationsSubtitle =>
      'Remplacer les parametres de notification globaux pour cet element';

  @override
  String get equipment_edit_notificationsTitle => 'Notifications (optionnel)';

  @override
  String get equipment_edit_purchaseDateLabel => 'Date d\'achat';

  @override
  String get equipment_edit_purchaseInfoTitle => 'Informations d\'achat';

  @override
  String get equipment_edit_purchasePriceLabel => 'Prix d\'achat';

  @override
  String get equipment_edit_remindMeBeforeServiceDue =>
      'Me rappeler avant l\'echeance de revision :';

  @override
  String equipment_edit_reminderDays(Object days) {
    return '$days jours';
  }

  @override
  String get equipment_edit_saveButton_edit => 'Enregistrer les modifications';

  @override
  String get equipment_edit_saveButton_new => 'Ajouter l\'equipement';

  @override
  String get equipment_edit_saveTooltip_edit =>
      'Enregistrer les modifications de l\'equipement';

  @override
  String get equipment_edit_saveTooltip_new => 'Ajouter un nouvel equipement';

  @override
  String get equipment_edit_selectDate => 'Selectionner une date';

  @override
  String get equipment_edit_serialNumberLabel => 'Numero de serie';

  @override
  String get equipment_edit_serviceIntervalHint => 'ex. 365 pour annuel';

  @override
  String get equipment_edit_serviceIntervalLabel =>
      'Intervalle de revision (jours)';

  @override
  String get equipment_edit_serviceSettingsTitle => 'Parametres de revision';

  @override
  String get equipment_edit_sizeHint => 'ex. M, L, 42';

  @override
  String get equipment_edit_sizeLabel => 'Taille';

  @override
  String get equipment_edit_snackbar_added => 'Equipement ajoute';

  @override
  String equipment_edit_snackbar_error(Object error) {
    return 'Erreur d\'enregistrement de l\'equipement : $error';
  }

  @override
  String get equipment_edit_snackbar_updated => 'Equipement mis a jour';

  @override
  String get equipment_edit_statusLabel => 'Statut';

  @override
  String get equipment_edit_typeLabel => 'Type *';

  @override
  String get equipment_edit_useCustomReminders =>
      'Utiliser des rappels personnalises';

  @override
  String get equipment_edit_useCustomRemindersSubtitle =>
      'Definir des jours de rappel differents pour cet element';

  @override
  String get equipment_fab_addEquipment => 'Ajouter un equipement';

  @override
  String get equipment_list_emptyState_addFirstButton =>
      'Ajouter ton premier equipement';

  @override
  String get equipment_list_emptyState_addPrompt =>
      'Ajoute ton equipement de plongee pour suivre l\'utilisation et la revision';

  @override
  String get equipment_list_emptyState_filterText_equipment => 'equipement';

  @override
  String get equipment_list_emptyState_filterText_serviceDue =>
      'equipement necessitant une revision';

  @override
  String equipment_list_emptyState_filterText_status(Object status) {
    return 'equipement $status';
  }

  @override
  String equipment_list_emptyState_noEquipment(Object filterText) {
    return 'Aucun $filterText';
  }

  @override
  String get equipment_list_emptyState_noStatusMatch =>
      'Aucun equipement avec ce statut';

  @override
  String get equipment_list_emptyState_serviceDueUpToDate =>
      'Tout ton equipement est a jour en matiere de revision !';

  @override
  String equipment_list_errorLoading(Object error) {
    return 'Erreur de chargement de l\'equipement : $error';
  }

  @override
  String get equipment_list_filterAll => 'Tout l\'equipement';

  @override
  String get equipment_list_filterLabel => 'Filtre :';

  @override
  String get equipment_list_filterServiceDue => 'Revision due';

  @override
  String get equipment_list_retryButton => 'Reessayer';

  @override
  String get equipment_list_searchTooltip => 'Rechercher de l\'equipement';

  @override
  String get equipment_list_setsTooltip => 'Ensembles d\'equipement';

  @override
  String get equipment_list_sortTitle => 'Trier l\'equipement';

  @override
  String get equipment_list_sortTooltip => 'Trier';

  @override
  String equipment_list_tile_daysCount(Object days) {
    return '$days jours';
  }

  @override
  String get equipment_list_tile_serviceDueChip => 'Revision due';

  @override
  String get equipment_list_tile_serviceIn => 'Revision dans';

  @override
  String get equipment_menu_delete => 'Supprimer';

  @override
  String get equipment_menu_markAsServiced => 'Marquer comme revise';

  @override
  String get equipment_menu_reactivate => 'Reactiver';

  @override
  String get equipment_menu_retireEquipment => 'Retirer l\'equipement';

  @override
  String get equipment_search_backTooltip => 'Retour';

  @override
  String get equipment_search_clearTooltip => 'Effacer la recherche';

  @override
  String get equipment_search_fieldLabel => 'Rechercher de l\'equipement...';

  @override
  String get equipment_search_hint =>
      'Rechercher par nom, marque, modele ou numero de serie';

  @override
  String equipment_search_noResults(Object query) {
    return 'Aucun equipement trouve pour \"$query\"';
  }

  @override
  String get equipment_serviceDialog_addButton => 'Ajouter';

  @override
  String get equipment_serviceDialog_addTitle =>
      'Ajouter un enregistrement de revision';

  @override
  String get equipment_serviceDialog_cancelButton => 'Annuler';

  @override
  String get equipment_serviceDialog_clearNextServiceDateTooltip =>
      'Effacer la date de prochaine revision';

  @override
  String get equipment_serviceDialog_costHint => '0.00';

  @override
  String get equipment_serviceDialog_costLabel => 'Cout';

  @override
  String get equipment_serviceDialog_costValidation =>
      'Entrez un montant valide';

  @override
  String get equipment_serviceDialog_editTitle =>
      'Modifier l\'enregistrement de revision';

  @override
  String get equipment_serviceDialog_nextServiceDueLabel =>
      'Prochaine revision';

  @override
  String get equipment_serviceDialog_nextServiceDueSemanticLabel =>
      'Choisir la date de prochaine revision';

  @override
  String get equipment_serviceDialog_nextServiceNotSet => 'Non defini';

  @override
  String get equipment_serviceDialog_notesLabel => 'Notes';

  @override
  String get equipment_serviceDialog_providerHint =>
      'ex. Nom du magasin de plongee';

  @override
  String get equipment_serviceDialog_providerLabel => 'Prestataire/Magasin';

  @override
  String get equipment_serviceDialog_serviceDateLabel => 'Date de revision';

  @override
  String get equipment_serviceDialog_serviceDateSemanticLabel =>
      'Choisir la date de revision';

  @override
  String get equipment_serviceDialog_serviceTypeLabel => 'Type de revision';

  @override
  String get equipment_serviceDialog_snackbar_added =>
      'Enregistrement de revision ajoute';

  @override
  String equipment_serviceDialog_snackbar_error(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get equipment_serviceDialog_snackbar_updated =>
      'Enregistrement de revision mis a jour';

  @override
  String get equipment_serviceDialog_updateButton => 'Mettre a jour';

  @override
  String get equipment_service_addButton => 'Ajouter';

  @override
  String get equipment_service_deleteDialog_cancel => 'Annuler';

  @override
  String get equipment_service_deleteDialog_confirm => 'Supprimer';

  @override
  String equipment_service_deleteDialog_content(Object serviceType) {
    return 'Es-tu sur de vouloir supprimer cet enregistrement de $serviceType ?';
  }

  @override
  String get equipment_service_deleteDialog_title =>
      'Supprimer l\'enregistrement de revision ?';

  @override
  String get equipment_service_deleteMenuItem => 'Supprimer';

  @override
  String get equipment_service_editMenuItem => 'Modifier';

  @override
  String get equipment_service_emptyState => 'Aucun enregistrement de revision';

  @override
  String get equipment_service_historyTitle => 'Historique de revision';

  @override
  String get equipment_service_snackbar_deleted =>
      'Enregistrement de revision supprime';

  @override
  String get equipment_service_totalCostLabel => 'Cout total de revision';

  @override
  String get equipment_setDetail_addEquipmentButton => 'Ajouter un equipement';

  @override
  String get equipment_setDetail_deleteDialog_cancel => 'Annuler';

  @override
  String get equipment_setDetail_deleteDialog_confirm => 'Supprimer';

  @override
  String get equipment_setDetail_deleteDialog_content =>
      'Es-tu sur de vouloir supprimer cet ensemble d\'equipement ? Les equipements de l\'ensemble ne seront pas supprimes.';

  @override
  String get equipment_setDetail_deleteDialog_title =>
      'Supprimer l\'ensemble d\'equipement';

  @override
  String get equipment_setDetail_deleteMenuItem => 'Supprimer';

  @override
  String get equipment_setDetail_editTooltip => 'Modifier l\'ensemble';

  @override
  String get equipment_setDetail_emptySet =>
      'Aucun equipement dans cet ensemble';

  @override
  String get equipment_setDetail_equipmentInSetTitle =>
      'Equipement dans cet ensemble';

  @override
  String equipment_setDetail_errorMessage(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get equipment_setDetail_errorTitle => 'Erreur';

  @override
  String get equipment_setDetail_loadingTitle => 'Chargement...';

  @override
  String get equipment_setDetail_notFoundMessage =>
      'Cet ensemble d\'equipement n\'existe plus.';

  @override
  String get equipment_setDetail_notFoundTitle => 'Ensemble introuvable';

  @override
  String get equipment_setDetail_snackbar_deleted =>
      'Ensemble d\'equipement supprime';

  @override
  String get equipment_setEdit_addEquipmentFirst =>
      'Ajoute d\'abord de l\'equipement avant de creer un ensemble.';

  @override
  String get equipment_setEdit_appBar_editTitle => 'Modifier l\'ensemble';

  @override
  String get equipment_setEdit_appBar_newTitle =>
      'Nouvel ensemble d\'equipement';

  @override
  String get equipment_setEdit_descriptionHint => 'Description optionnelle...';

  @override
  String get equipment_setEdit_descriptionLabel => 'Description';

  @override
  String equipment_setEdit_errorMessage(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get equipment_setEdit_errorTitle => 'Erreur';

  @override
  String get equipment_setEdit_loadingTitle => 'Chargement...';

  @override
  String get equipment_setEdit_nameHint => 'ex. Configuration eaux chaudes';

  @override
  String get equipment_setEdit_nameLabel => 'Nom de l\'ensemble *';

  @override
  String get equipment_setEdit_nameValidation => 'Veuillez entrer un nom';

  @override
  String get equipment_setEdit_noEquipmentAvailable =>
      'Aucun equipement disponible';

  @override
  String get equipment_setEdit_notFoundMessage =>
      'Cet ensemble d\'equipement n\'existe plus.';

  @override
  String get equipment_setEdit_notFoundTitle => 'Ensemble introuvable';

  @override
  String get equipment_setEdit_saveButton_edit =>
      'Enregistrer les modifications';

  @override
  String get equipment_setEdit_saveButton_new => 'Creer l\'ensemble';

  @override
  String get equipment_setEdit_saveTooltip_edit =>
      'Enregistrer les modifications de l\'ensemble';

  @override
  String get equipment_setEdit_saveTooltip_new =>
      'Creer un nouvel ensemble d\'equipement';

  @override
  String get equipment_setEdit_selectEquipmentSubtitle =>
      'Choisis les equipements a inclure dans cet ensemble.';

  @override
  String get equipment_setEdit_selectEquipmentTitle =>
      'Selectionner l\'equipement';

  @override
  String get equipment_setEdit_snackbar_created =>
      'Ensemble d\'equipement cree';

  @override
  String equipment_setEdit_snackbar_error(Object error) {
    return 'Erreur d\'enregistrement de l\'ensemble : $error';
  }

  @override
  String get equipment_setEdit_snackbar_updated =>
      'Ensemble d\'equipement mis a jour';

  @override
  String get equipment_sets_appBar_title => 'Ensembles d\'equipement';

  @override
  String get equipment_sets_emptyState_createFirstButton =>
      'Creer ton premier ensemble';

  @override
  String get equipment_sets_emptyState_description =>
      'Cree des ensembles d\'equipement pour ajouter rapidement des combinaisons d\'equipement courantes a tes plongees.';

  @override
  String get equipment_sets_emptyState_title => 'Aucun ensemble d\'equipement';

  @override
  String equipment_sets_errorLoading(Object error) {
    return 'Erreur de chargement des ensembles : $error';
  }

  @override
  String get equipment_sets_fabTooltip =>
      'Creer un nouvel ensemble d\'equipement';

  @override
  String get equipment_sets_fab_createSet => 'Creer un ensemble';

  @override
  String equipment_sets_itemCountPlural(Object count) {
    return '$count elements';
  }

  @override
  String equipment_sets_itemCountSemanticLabel(Object count) {
    return '$count dans l\'ensemble';
  }

  @override
  String equipment_sets_itemCountSingular(Object count) {
    return '$count element';
  }

  @override
  String get equipment_sets_retryButton => 'Reessayer';

  @override
  String get equipment_snackbar_deleted => 'Equipement supprime';

  @override
  String get equipment_snackbar_markedAsServiced => 'Marque comme revise';

  @override
  String get equipment_snackbar_reactivated => 'Equipement reactive';

  @override
  String get equipment_snackbar_retired => 'Equipement retire';

  @override
  String get equipment_summary_active => 'Actif';

  @override
  String get equipment_summary_addEquipmentButton => 'Ajouter un equipement';

  @override
  String get equipment_summary_equipmentSetsButton => 'Ensembles d\'equipement';

  @override
  String get equipment_summary_overviewTitle => 'Apercu';

  @override
  String get equipment_summary_quickActionsTitle => 'Actions rapides';

  @override
  String get equipment_summary_recentEquipmentTitle => 'Equipement recent';

  @override
  String equipment_summary_recentSemanticLabel(Object name, Object type) {
    return '$name, $type';
  }

  @override
  String get equipment_summary_selectPrompt =>
      'Selectionne un equipement dans la liste pour voir les details';

  @override
  String get equipment_summary_serviceDue => 'Revision due';

  @override
  String equipment_summary_serviceDueSemanticLabel(Object name, Object type) {
    return '$name, $type, revision due';
  }

  @override
  String get equipment_summary_serviceDueTitle => 'Revision due';

  @override
  String get equipment_summary_title => 'Equipement';

  @override
  String get equipment_summary_totalItems => 'Total elements';

  @override
  String get equipment_summary_totalValue => 'Valeur totale';

  @override
  String get formatter_approximate_prefix => '~';

  @override
  String get formatter_connector_at => 'a';

  @override
  String get formatter_connector_from => 'Du';

  @override
  String get formatter_connector_until => 'Jusqu\'au';

  @override
  String get gas_air_description => 'Air standard (21% O2)';

  @override
  String get gas_air_displayName => 'Air';

  @override
  String get gas_diluentAir_description =>
      'Diluant air standard pour recycleur peu profond';

  @override
  String get gas_diluentAir_displayName => 'Diluant air';

  @override
  String get gas_diluentTx1070_description =>
      'Diluant hypoxique pour recycleur tres profond';

  @override
  String get gas_diluentTx1070_displayName => 'Tx 10/70';

  @override
  String get gas_diluentTx1260_description =>
      'Diluant hypoxique pour recycleur profond';

  @override
  String get gas_diluentTx1260_displayName => 'Tx 12/60';

  @override
  String get gas_ean32_description => 'Nitrox enrichi 32%';

  @override
  String get gas_ean32_displayName => 'EAN32';

  @override
  String get gas_ean36_description => 'Nitrox enrichi 36%';

  @override
  String get gas_ean36_displayName => 'EAN36';

  @override
  String get gas_ean40_description => 'Nitrox enrichi 40%';

  @override
  String get gas_ean40_displayName => 'EAN40';

  @override
  String get gas_ean50_description => 'Gaz de decompression - 50% O2';

  @override
  String get gas_ean50_displayName => 'EAN50';

  @override
  String get gas_helitrox2525_description =>
      'Helitrox 25/25 (technique loisir)';

  @override
  String get gas_helitrox2525_displayName => 'Helitrox 25/25';

  @override
  String get gas_oxygen_description => 'Oxygene pur (palier 6m uniquement)';

  @override
  String get gas_oxygen_displayName => 'Oxygene';

  @override
  String get gas_scrEan40_description => 'Gaz d\'alimentation SCR - 40% O2';

  @override
  String get gas_scrEan40_displayName => 'SCR EAN40';

  @override
  String get gas_scrEan50_description => 'Gaz d\'alimentation SCR - 50% O2';

  @override
  String get gas_scrEan50_displayName => 'SCR EAN50';

  @override
  String get gas_scrEan60_description => 'Gaz d\'alimentation SCR - 60% O2';

  @override
  String get gas_scrEan60_displayName => 'SCR EAN60';

  @override
  String get gas_tmx1555_description => 'Trimix hypoxique 15/55 (tres profond)';

  @override
  String get gas_tmx1555_displayName => 'Tx 15/55';

  @override
  String get gas_tmx1845_description => 'Trimix 18/45 (plongee profonde)';

  @override
  String get gas_tmx1845_displayName => 'Tx 18/45';

  @override
  String get gas_tmx2135_description => 'Trimix normoxique 21/35';

  @override
  String get gas_tmx2135_displayName => 'Tx 21/35';

  @override
  String get gasCalculators_bestMix_bestOxygenMix =>
      'Meilleur mélange d\'oxygène';

  @override
  String get gasCalculators_bestMix_commonMixesRef =>
      'Référence des mélanges courants';

  @override
  String gasCalculators_bestMix_exceedsAirMod(Object ppO2) {
    return 'MOD de l\'air dépassée à ppO₂ $ppO2';
  }

  @override
  String get gasCalculators_bestMix_targetDepth => 'Profondeur cible';

  @override
  String get gasCalculators_bestMix_targetDive => 'Plongée cible';

  @override
  String gasCalculators_consumption_ambientPressure(
    Object depth,
    Object depthSymbol,
  ) {
    return 'Pression ambiante à $depth$depthSymbol';
  }

  @override
  String get gasCalculators_consumption_avgDepth => 'Profondeur moyenne';

  @override
  String get gasCalculators_consumption_breakdown => 'Détail du calcul';

  @override
  String get gasCalculators_consumption_diveTime => 'Temps de plongée';

  @override
  String gasCalculators_consumption_exceedsTank(
    Object pressure,
    Object symbol,
  ) {
    return 'Dépasse la capacité de la bouteille ($pressure $symbol)';
  }

  @override
  String get gasCalculators_consumption_gasAtDepth =>
      'Consommation de gaz en profondeur';

  @override
  String get gasCalculators_consumption_pressure => 'Pression';

  @override
  String get gasCalculators_consumption_remainingGas => 'Gaz restant';

  @override
  String gasCalculators_consumption_tankCapacity(
    Object tankSize,
    Object volumeSymbol,
    Object fillPressure,
    Object pressureSymbol,
  ) {
    return 'Capacité de la bouteille ($tankSize$volumeSymbol @ $fillPressure $pressureSymbol)';
  }

  @override
  String get gasCalculators_consumption_title => 'Consommation de gaz';

  @override
  String gasCalculators_consumption_totalGas(Object time) {
    return 'Gaz total pour $time minutes';
  }

  @override
  String get gasCalculators_consumption_volume => 'Volume';

  @override
  String get gasCalculators_mod_aboutMod => 'À propos de la MOD';

  @override
  String get gasCalculators_mod_aboutModBody =>
      'Moins d\'O₂ = MOD plus profonde = DTR plus courte';

  @override
  String get gasCalculators_mod_inputParameters => 'Paramètres d\'entrée';

  @override
  String get gasCalculators_mod_maximumOperatingDepth =>
      'Profondeur maximale d\'utilisation';

  @override
  String get gasCalculators_mod_oxygenO2 => 'Oxygène (O₂)';

  @override
  String get gasCalculators_mod_ppO2Conservative =>
      'Limite conservatrice pour temps au fond prolongé';

  @override
  String get gasCalculators_mod_ppO2Maximum =>
      'Limite maximale pour paliers de décompression uniquement';

  @override
  String get gasCalculators_mod_ppO2Standard =>
      'Limite de travail standard pour la plongée récréative';

  @override
  String get gasCalculators_ppO2Limit => 'Limite ppO₂';

  @override
  String get gasCalculators_resetAll => 'Réinitialiser tous les calculateurs';

  @override
  String get gasCalculators_sacRate => 'Taux CAS';

  @override
  String get gasCalculators_tab_bestMix => 'Meilleur mélange';

  @override
  String get gasCalculators_tab_consumption => 'Consommation';

  @override
  String get gasCalculators_tab_mod => 'MOD';

  @override
  String get gasCalculators_tab_rockBottom => 'Rock Bottom';

  @override
  String get gasCalculators_tankSize => 'Taille de bouteille';

  @override
  String get gasCalculators_title => 'Calculateurs de gaz';

  @override
  String get marineLife_siteSection_editExpectedTooltip =>
      'Modifier les especes attendues';

  @override
  String get marineLife_siteSection_errorLoadingExpected =>
      'Erreur lors du chargement des especes attendues';

  @override
  String get marineLife_siteSection_errorLoadingSightings =>
      'Erreur lors du chargement des observations';

  @override
  String get marineLife_siteSection_expectedSpecies => 'Especes attendues';

  @override
  String get marineLife_siteSection_noExpected =>
      'Aucune espece attendue ajoutee';

  @override
  String get marineLife_siteSection_noSpotted => 'Aucune vie marine observee';

  @override
  String marineLife_siteSection_spottedCountSemantics(
    Object name,
    Object count,
  ) {
    return '$name, observé $count fois';
  }

  @override
  String get marineLife_siteSection_spottedHere => 'Observees ici';

  @override
  String get marineLife_siteSection_title => 'Vie marine';

  @override
  String get marineLife_speciesDetail_backTooltip => 'Retour';

  @override
  String get marineLife_speciesDetail_depthRangeTitle => 'Plage de profondeur';

  @override
  String get marineLife_speciesDetail_descriptionTitle => 'Description';

  @override
  String get marineLife_speciesDetail_divesLabel => 'Plongees';

  @override
  String get marineLife_speciesDetail_editTooltip => 'Modifier l\'espece';

  @override
  String marineLife_speciesDetail_errorPrefix(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get marineLife_speciesDetail_noSightings =>
      'Aucune observation enregistree';

  @override
  String get marineLife_speciesDetail_notFound => 'Espece introuvable';

  @override
  String marineLife_speciesDetail_sightingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'observations',
      one: 'observation',
    );
    return '$count $_temp0';
  }

  @override
  String get marineLife_speciesDetail_sightingPeriodTitle =>
      'Periode d\'observation';

  @override
  String get marineLife_speciesDetail_sightingStatsTitle =>
      'Statistiques d\'observation';

  @override
  String get marineLife_speciesDetail_sitesLabel => 'Sites';

  @override
  String marineLife_speciesDetail_taxonomyClassLabel(Object className) {
    return 'Classe : $className';
  }

  @override
  String get marineLife_speciesDetail_topSitesTitle => 'Meilleurs sites';

  @override
  String get marineLife_speciesDetail_totalSightingsLabel =>
      'Total des observations';

  @override
  String get marineLife_speciesEdit_addTitle => 'Ajouter une espece';

  @override
  String marineLife_speciesEdit_addedSnackbar(Object name) {
    return '\"$name\" ajoutee';
  }

  @override
  String get marineLife_speciesEdit_backTooltip => 'Retour';

  @override
  String get marineLife_speciesEdit_categoryLabel => 'Categorie';

  @override
  String get marineLife_speciesEdit_commonNameError =>
      'Veuillez entrer un nom commun';

  @override
  String get marineLife_speciesEdit_commonNameHint =>
      'ex. Poisson-clown a trois bandes';

  @override
  String get marineLife_speciesEdit_commonNameLabel => 'Nom commun';

  @override
  String get marineLife_speciesEdit_descriptionHint =>
      'Breve description de l\'espece...';

  @override
  String get marineLife_speciesEdit_descriptionLabel => 'Description';

  @override
  String get marineLife_speciesEdit_editTitle => 'Modifier l\'espece';

  @override
  String marineLife_speciesEdit_errorLoading(Object error) {
    return 'Erreur lors du chargement de l\'espece : $error';
  }

  @override
  String marineLife_speciesEdit_errorSaving(Object error) {
    return 'Erreur lors de l\'enregistrement de l\'espece : $error';
  }

  @override
  String get marineLife_speciesEdit_saveButton => 'Enregistrer';

  @override
  String get marineLife_speciesEdit_scientificNameHint =>
      'ex. Amphiprion ocellaris';

  @override
  String get marineLife_speciesEdit_scientificNameLabel => 'Nom scientifique';

  @override
  String get marineLife_speciesEdit_taxonomyClassHint => 'ex. Actinopterygii';

  @override
  String get marineLife_speciesEdit_taxonomyClassLabel => 'Classe taxonomique';

  @override
  String marineLife_speciesEdit_updatedSnackbar(Object name) {
    return '\"$name\" mise a jour';
  }

  @override
  String get marineLife_speciesManage_allFilter => 'Tout';

  @override
  String get marineLife_speciesManage_appBarTitle => 'Especes';

  @override
  String get marineLife_speciesManage_backTooltip => 'Retour';

  @override
  String marineLife_speciesManage_builtInSpeciesHeader(Object count) {
    return 'Especes integrees ($count)';
  }

  @override
  String get marineLife_speciesManage_cancelButton => 'Annuler';

  @override
  String marineLife_speciesManage_cannotDeleteInUse(Object name) {
    return 'Impossible de supprimer \"$name\" - elle a des observations';
  }

  @override
  String get marineLife_speciesManage_clearSearchTooltip =>
      'Effacer la recherche';

  @override
  String marineLife_speciesManage_customSpeciesHeader(Object count) {
    return 'Especes personnalisees ($count)';
  }

  @override
  String get marineLife_speciesManage_deleteButton => 'Supprimer';

  @override
  String marineLife_speciesManage_deleteDialogContent(Object name) {
    return 'Voulez-vous vraiment supprimer \"$name\" ?';
  }

  @override
  String get marineLife_speciesManage_deleteDialogTitle =>
      'Supprimer l\'espece ?';

  @override
  String get marineLife_speciesManage_deleteTooltip => 'Supprimer l\'espece';

  @override
  String marineLife_speciesManage_deletedSnackbar(Object name) {
    return '\"$name\" supprimee';
  }

  @override
  String get marineLife_speciesManage_editTooltip => 'Modifier l\'espece';

  @override
  String marineLife_speciesManage_errorDeleting(Object error) {
    return 'Erreur lors de la suppression de l\'espece : $error';
  }

  @override
  String marineLife_speciesManage_errorResetting(Object error) {
    return 'Erreur lors de la reinitialisation des especes : $error';
  }

  @override
  String get marineLife_speciesManage_noSpeciesFound => 'Aucune espece trouvee';

  @override
  String get marineLife_speciesManage_resetButton => 'Reinitialiser';

  @override
  String get marineLife_speciesManage_resetDialogContent =>
      'Ceci restaurera toutes les especes integrees a leurs valeurs d\'origine. Les especes personnalisees ne seront pas affectees. Les especes integrees ayant des observations existantes seront mises a jour mais conservees.';

  @override
  String get marineLife_speciesManage_resetDialogTitle =>
      'Reinitialiser aux valeurs par defaut ?';

  @override
  String get marineLife_speciesManage_resetSuccess =>
      'Especes integrees restaurees aux valeurs par defaut';

  @override
  String get marineLife_speciesManage_resetToDefaults =>
      'Reinitialiser aux valeurs par defaut';

  @override
  String get marineLife_speciesManage_searchHint => 'Rechercher des especes...';

  @override
  String get marineLife_speciesPicker_allFilter => 'Tout';

  @override
  String get marineLife_speciesPicker_cancelButton => 'Annuler';

  @override
  String get marineLife_speciesPicker_clearSearchTooltip =>
      'Effacer la recherche';

  @override
  String get marineLife_speciesPicker_closeTooltip =>
      'Fermer le selecteur d\'especes';

  @override
  String get marineLife_speciesPicker_doneButton => 'Termine';

  @override
  String marineLife_speciesPicker_error(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get marineLife_speciesPicker_noSpeciesFound => 'Aucune espece trouvee';

  @override
  String get marineLife_speciesPicker_searchHint => 'Rechercher des especes...';

  @override
  String marineLife_speciesPicker_selectedCount(Object count) {
    return '$count selectionnees';
  }

  @override
  String get marineLife_speciesPicker_title => 'Selectionner des especes';

  @override
  String get media_diveMediaSection_addTooltip =>
      'Ajouter une photo ou une video';

  @override
  String get media_diveMediaSection_cancelButton => 'Annuler';

  @override
  String get media_diveMediaSection_emptyState => 'Aucune photo';

  @override
  String get media_diveMediaSection_errorLoading =>
      'Erreur lors du chargement des medias';

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'Voir la photo. Appui long pour dissocier';

  @override
  String get media_diveMediaSection_title => 'Photos et video';

  @override
  String get media_diveMediaSection_unlinkButton => 'Dissocier';

  @override
  String get media_diveMediaSection_unlinkDialogContent =>
      'Retirer cette photo de la plongee ? La photo restera dans ta galerie.';

  @override
  String get media_diveMediaSection_unlinkDialogTitle => 'Dissocier la photo';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Echec de la dissociation : $error';
  }

  @override
  String get media_diveMediaSection_unlinkSuccess => 'Photo dissociee';

  @override
  String get media_gpsBanner_addToSiteButton => 'Ajouter au site';

  @override
  String media_gpsBanner_coordinates(Object latitude, Object longitude) {
    return 'Coordonnees : $latitude, $longitude';
  }

  @override
  String get media_gpsBanner_createSiteButton => 'Creer un site';

  @override
  String get media_gpsBanner_dismissTooltip => 'Ignorer la suggestion GPS';

  @override
  String get media_gpsBanner_title => 'GPS trouve dans les photos';

  @override
  String media_import_failedToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'photos',
      one: 'photo',
    );
    return 'Echec de l\'importation de $_temp0';
  }

  @override
  String media_import_failedToImportError(Object error) {
    return 'Echec de l\'importation des photos : $error';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return '$imported importees, $failed echouees';
  }

  @override
  String media_import_importedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'photos importees',
      one: 'photo importee',
    );
    return '$count $_temp0';
  }

  @override
  String media_import_importingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'photos',
      one: 'photo',
    );
    return 'Importation de $count $_temp0...';
  }

  @override
  String get media_miniProfile_headerLabel => 'Profil de plongee';

  @override
  String get media_miniProfile_semanticLabel =>
      'Mini graphique du profil de plongee';

  @override
  String get media_photoPicker_appBarTitle => 'Selectionner des photos';

  @override
  String get media_photoPicker_closeTooltip => 'Fermer le selecteur de photos';

  @override
  String get media_photoPicker_doneButton => 'Termine';

  @override
  String media_photoPicker_doneCountButton(Object count) {
    return 'Termine ($count)';
  }

  @override
  String media_photoPicker_emptyMessage(
    Object startDate,
    Object startTime,
    Object endDate,
    Object endTime,
  ) {
    return 'Aucune photo trouvee entre le $startDate $startTime et le $endDate $endTime.';
  }

  @override
  String get media_photoPicker_emptyTitle => 'Aucune photo trouvee';

  @override
  String get media_photoPicker_grantAccessButton => 'Autoriser l\'acces';

  @override
  String get media_photoPicker_openSettingsButton => 'Ouvrir les reglages';

  @override
  String get media_photoPicker_openSettingsSnackbar =>
      'Veuillez ouvrir les Reglages et activer l\'acces aux photos';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'L\'acces a la phototheque a ete refuse. Veuillez l\'activer dans les Reglages pour ajouter des photos de plongee.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion a besoin d\'acceder a votre phototheque pour ajouter des photos de plongee.';

  @override
  String get media_photoPicker_permissionTitle => 'Acces aux photos requis';

  @override
  String media_photoPicker_showingPhotosFromRange(Object rangeText) {
    return 'Photos de la periode $rangeText';
  }

  @override
  String get media_photoPicker_thumbnailToggleLabel =>
      'Basculer la selection de la photo';

  @override
  String get media_photoPicker_thumbnailToggleSelectedLabel =>
      'Basculer la selection de la photo, selectionnee';

  @override
  String get media_photoViewer_cannotShare =>
      'Impossible de partager cette photo';

  @override
  String get media_photoViewer_cannotWriteMetadata =>
      'Impossible d\'ecrire les metadonnees - media non lie a la bibliotheque';

  @override
  String get media_photoViewer_closeTooltip => 'Fermer la visionneuse';

  @override
  String get media_photoViewer_diveDataWrittenToPhoto =>
      'Donnees de plongee ecrites sur la photo';

  @override
  String get media_photoViewer_diveDataWrittenToVideo =>
      'Donnees de plongee ecrites sur la video';

  @override
  String media_photoViewer_errorLoadingPhotos(Object error) {
    return 'Erreur lors du chargement des photos : $error';
  }

  @override
  String get media_photoViewer_failedToLoadImage =>
      'Echec du chargement de l\'image';

  @override
  String get media_photoViewer_failedToLoadVideo =>
      'Echec du chargement de la video';

  @override
  String media_photoViewer_failedToShare(Object error) {
    return 'Echec du partage : $error';
  }

  @override
  String get media_photoViewer_failedToWriteMetadata =>
      'Echec de l\'ecriture des metadonnees';

  @override
  String media_photoViewer_failedToWriteMetadataError(Object error) {
    return 'Echec de l\'ecriture des metadonnees : $error';
  }

  @override
  String get media_photoViewer_noPhotosAvailable => 'Aucune photo disponible';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel =>
      'Lire ou mettre en pause la video';

  @override
  String get media_photoViewer_seekVideoLabel =>
      'Deplacer la position de la video';

  @override
  String get media_photoViewer_shareTooltip => 'Partager la photo';

  @override
  String get media_photoViewer_toggleOverlayLabel =>
      'Basculer la superposition photo';

  @override
  String get media_photoViewer_videoFileNotFound => 'Fichier video introuvable';

  @override
  String get media_photoViewer_videoNotLinked =>
      'Video non liee a la bibliotheque';

  @override
  String get media_photoViewer_writeDiveDataTooltip =>
      'Ecrire les donnees de plongee sur la photo';

  @override
  String get media_quickSiteDialog_cancelButton => 'Annuler';

  @override
  String get media_quickSiteDialog_createButton => 'Creer le site';

  @override
  String get media_quickSiteDialog_description =>
      'Creez un nouveau site de plongee a partir des coordonnees GPS de votre photo.';

  @override
  String get media_quickSiteDialog_siteNameError =>
      'Veuillez entrer un nom de site';

  @override
  String get media_quickSiteDialog_siteNameHint => 'Entrez un nom pour ce site';

  @override
  String get media_quickSiteDialog_siteNameLabel => 'Nom du site';

  @override
  String get media_quickSiteDialog_title => 'Creer un site de plongee';

  @override
  String get media_scanResults_allPhotosLinked =>
      'Toutes les photos sont deja associees';

  @override
  String media_scanResults_allPhotosLinkedDescription(Object count) {
    return 'Les $count photos de ce voyage sont deja associees a des plongees.';
  }

  @override
  String media_scanResults_alreadyLinked(Object count) {
    return '$count photos deja associees';
  }

  @override
  String get media_scanResults_cancelButton => 'Annuler';

  @override
  String media_scanResults_diveNumber(Object number) {
    return 'Plongee n$number';
  }

  @override
  String media_scanResults_foundNewPhotos(Object count) {
    return '$count nouvelles photos trouvees';
  }

  @override
  String get media_scanResults_linkButton => 'Associer';

  @override
  String media_scanResults_linkCountButton(Object count) {
    return 'Associer $count photos';
  }

  @override
  String get media_scanResults_noPhotosFound => 'Aucune photo trouvee';

  @override
  String get media_scanResults_okButton => 'OK';

  @override
  String get media_scanResults_unknownSite => 'Site inconnu';

  @override
  String media_scanResults_unmatchedWarning(Object count) {
    return '$count photos n\'ont pu etre associees a aucune plongee (prises en dehors des horaires de plongee)';
  }

  @override
  String get media_writeMetadata_cancelButton => 'Annuler';

  @override
  String get media_writeMetadata_depthLabel => 'Profondeur';

  @override
  String get media_writeMetadata_descriptionPhoto =>
      'Les metadonnees suivantes seront ecrites sur la photo :';

  @override
  String get media_writeMetadata_descriptionVideo =>
      'Les metadonnees suivantes seront ecrites sur la video :';

  @override
  String get media_writeMetadata_diveTimeLabel => 'Heure de plongee';

  @override
  String get media_writeMetadata_gpsLabel => 'GPS';

  @override
  String get media_writeMetadata_keepOriginalVideo =>
      'Conserver la video originale';

  @override
  String get media_writeMetadata_noDataAvailable =>
      'Aucune donnee de plongee disponible a ecrire.';

  @override
  String get media_writeMetadata_siteLabel => 'Site';

  @override
  String get media_writeMetadata_temperatureLabel => 'Temperature';

  @override
  String get media_writeMetadata_titlePhoto =>
      'Ecrire les donnees de plongee sur la photo';

  @override
  String get media_writeMetadata_titleVideo =>
      'Ecrire les donnees de plongee sur la video';

  @override
  String get media_writeMetadata_warningPhotoText =>
      'Ceci modifiera la photo originale.';

  @override
  String get media_writeMetadata_warningVideoText =>
      'Une nouvelle video sera creee avec les metadonnees. Les metadonnees video ne peuvent pas etre modifiees sur place.';

  @override
  String get media_writeMetadata_writeButton => 'Ecrire';

  @override
  String get nav_buddies => 'Binomes';

  @override
  String get nav_certifications => 'Certifications';

  @override
  String get nav_courses => 'Cours';

  @override
  String get nav_coursesSubtitle => 'Formation et enseignement';

  @override
  String get nav_diveCenters => 'Centres de plongee';

  @override
  String get nav_dives => 'Plongees';

  @override
  String get nav_equipment => 'Equipement';

  @override
  String get nav_home => 'Accueil';

  @override
  String get nav_more => 'Plus';

  @override
  String get nav_planning => 'Planification';

  @override
  String get nav_planningSubtitle => 'Planificateur de plongee, calculateurs';

  @override
  String get nav_settings => 'Reglages';

  @override
  String get nav_sites => 'Sites';

  @override
  String get nav_statistics => 'Statistiques';

  @override
  String get nav_tooltip_closeMenu => 'Fermer le menu';

  @override
  String get nav_tooltip_collapseMenu => 'Reduire le menu';

  @override
  String get nav_tooltip_expandMenu => 'Developper le menu';

  @override
  String get nav_transfer => 'Transfert';

  @override
  String get nav_trips => 'Voyages';

  @override
  String get onboarding_welcome_createProfile => 'Créer votre profil';

  @override
  String get onboarding_welcome_createProfileSubtitle =>
      'Entrez votre nom pour commencer. Vous pourrez ajouter plus de détails plus tard.';

  @override
  String get onboarding_welcome_creating => 'Création...';

  @override
  String onboarding_welcome_errorCreatingProfile(Object error) {
    return 'Erreur lors de la création du profil : $error';
  }

  @override
  String get onboarding_welcome_getStarted => 'Commencer';

  @override
  String get onboarding_welcome_nameHint => 'Entrez votre nom';

  @override
  String get onboarding_welcome_nameLabel => 'Votre nom';

  @override
  String get onboarding_welcome_nameValidation => 'Veuillez entrer votre nom';

  @override
  String get onboarding_welcome_subtitle =>
      'Enregistrement et analyse avancés de plongée';

  @override
  String get onboarding_welcome_title => 'Bienvenue dans Submersion';

  @override
  String get planning_appBar_title => 'Planification';

  @override
  String get planning_card_decoCalculator_description =>
      'Calculez les limites de non-decompression, les paliers de decompression requis et l\'exposition CNS/OTU pour des profils de plongee multi-niveaux.';

  @override
  String get planning_card_decoCalculator_subtitle =>
      'Planifiez des plongees avec paliers de decompression';

  @override
  String get planning_card_decoCalculator_title => 'Calculateur deco';

  @override
  String get planning_card_divePlanner_description =>
      'Planifiez des plongees complexes avec plusieurs niveaux de profondeur, des changements de gaz et le calcul automatique des paliers de decompression.';

  @override
  String get planning_card_divePlanner_subtitle =>
      'Creez des plans de plongee multi-niveaux';

  @override
  String get planning_card_divePlanner_title => 'Planificateur de plongee';

  @override
  String get planning_card_gasCalculators_description =>
      'Quatre calculateurs de gaz specialises :\n- MOD - Profondeur maximale d\'utilisation pour un melange\n- Best Mix - O₂% ideal pour une profondeur cible\n- Consommation - Estimation de la consommation de gaz\n- Reserve de securite - Calcul de la reserve d\'urgence';

  @override
  String get planning_card_gasCalculators_subtitle =>
      'MOD, Best Mix, Consommation, Reserve de securite';

  @override
  String get planning_card_gasCalculators_title => 'Calculateurs de gaz';

  @override
  String get planning_card_surfaceInterval_description =>
      'Calculez l\'intervalle de surface minimum necessaire entre les plongees en fonction de la saturation tissulaire. Visualisez comment vos 16 compartiments tissulaires desaturent au fil du temps.';

  @override
  String get planning_card_surfaceInterval_subtitle =>
      'Planifiez les intervalles de plongees successives';

  @override
  String get planning_card_surfaceInterval_title => 'Intervalle de surface';

  @override
  String get planning_card_weightCalculator_description =>
      'Estimez le lestage necessaire en fonction de votre combinaison, du materiau du bloc, du type d\'eau et de votre poids corporel.';

  @override
  String get planning_card_weightCalculator_subtitle =>
      'Lestage recommande pour votre configuration';

  @override
  String get planning_card_weightCalculator_title => 'Calculateur de lestage';

  @override
  String get planning_info_disclaimer =>
      'Ces outils sont destines a la planification uniquement. Verifiez toujours les calculs et suivez votre formation de plongee.';

  @override
  String get planning_sidebar_appBar_title => 'Planification';

  @override
  String get planning_sidebar_decoCalculator_subtitle => 'NDL et paliers deco';

  @override
  String get planning_sidebar_decoCalculator_title => 'Calculateur deco';

  @override
  String get planning_sidebar_divePlanner_subtitle =>
      'Plans de plongee multi-niveaux';

  @override
  String get planning_sidebar_divePlanner_title => 'Planificateur de plongee';

  @override
  String get planning_sidebar_gasCalculators_subtitle =>
      'MOD, Best Mix, et plus';

  @override
  String get planning_sidebar_gasCalculators_title => 'Calculateurs de gaz';

  @override
  String get planning_sidebar_info_disclaimer =>
      'Les outils de planification sont fournis a titre indicatif. Verifiez toujours les calculs.';

  @override
  String get planning_sidebar_surfaceInterval_subtitle =>
      'Planification de plongees successives';

  @override
  String get planning_sidebar_surfaceInterval_title => 'Intervalle de surface';

  @override
  String get planning_sidebar_weightCalculator_subtitle => 'Lestage recommande';

  @override
  String get planning_sidebar_weightCalculator_title =>
      'Calculateur de lestage';

  @override
  String get planning_welcome_quickTips_title => 'Astuces rapides';

  @override
  String get planning_welcome_subtitle =>
      'Selectionnez un outil dans la barre laterale pour commencer';

  @override
  String get planning_welcome_tip_decoCalculator =>
      'Calculateur deco pour les NDL et les temps de palier';

  @override
  String get planning_welcome_tip_divePlanner =>
      'Planificateur de plongee pour la planification multi-niveaux';

  @override
  String get planning_welcome_tip_gasCalculators =>
      'Calculateurs de gaz pour la MOD et la planification des gaz';

  @override
  String get planning_welcome_tip_weightCalculator =>
      'Calculateur de lestage pour la configuration de la flottabilite';

  @override
  String get planning_welcome_title => 'Outils de planification';

  @override
  String get settings_about_aboutSubmersion => 'A propos de Submersion';

  @override
  String get settings_about_appName => 'Submersion';

  @override
  String get settings_about_description =>
      'Suivez vos plongees, gerez votre equipement et explorez les sites de plongee.';

  @override
  String get settings_about_header => 'A propos';

  @override
  String get settings_about_openSourceLicenses => 'Licences open source';

  @override
  String get settings_about_reportIssue => 'Signaler un probleme';

  @override
  String get settings_about_reportIssue_snackbar =>
      'Rendez-vous sur github.com/submersion/submersion';

  @override
  String get settings_about_version => 'Version 0.1.0';

  @override
  String get settings_appBar_title => 'Reglages';

  @override
  String get settings_appearance_appLanguage => 'Langue de l\'application';

  @override
  String get settings_appearance_depthColoredCards =>
      'Cartes de plongee colorees par profondeur';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'Afficher les cartes de plongee avec des fonds colores selon la profondeur';

  @override
  String get settings_appearance_gasSwitchMarkers =>
      'Marqueurs de changement de gaz';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle =>
      'Afficher les marqueurs de changement de gaz';

  @override
  String get settings_appearance_header_diveLog => 'Carnet de plongee';

  @override
  String get settings_appearance_header_diveProfile => 'Profil de plongee';

  @override
  String get settings_appearance_header_diveSites => 'Sites de plongee';

  @override
  String get settings_appearance_header_language => 'Langue';

  @override
  String get settings_appearance_header_theme => 'Theme';

  @override
  String get settings_appearance_mapBackgroundDiveCards =>
      'Fond cartographique sur les cartes de plongee';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitle =>
      'Afficher la carte du site de plongee en fond sur les cartes de plongee';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitleWithNote =>
      'Afficher la carte du site de plongee en fond sur les cartes de plongee (localisation du site requise)';

  @override
  String get settings_appearance_mapBackgroundSiteCards =>
      'Fond cartographique sur les cartes de site';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitle =>
      'Afficher la carte en fond sur les cartes de site de plongee';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitleWithNote =>
      'Afficher la carte en fond sur les cartes de site de plongee (localisation du site requise)';

  @override
  String get settings_appearance_maxDepthMarker =>
      'Marqueur de profondeur max.';

  @override
  String get settings_appearance_maxDepthMarker_subtitle =>
      'Afficher un marqueur au point de profondeur maximale';

  @override
  String get settings_appearance_maxDepthMarker_subtitleFull =>
      'Afficher un marqueur au point de profondeur maximale sur les profils de plongee';

  @override
  String get settings_appearance_metric_ascentRateColors =>
      'Couleurs de vitesse de remontee';

  @override
  String get settings_appearance_metric_ceiling => 'Plafond';

  @override
  String get settings_appearance_metric_events => 'Evenements';

  @override
  String get settings_appearance_metric_gasDensity => 'Densite du gaz';

  @override
  String get settings_appearance_metric_gfPercent => 'GF%';

  @override
  String get settings_appearance_metric_heartRate => 'Frequence cardiaque';

  @override
  String get settings_appearance_metric_meanDepth => 'Profondeur moyenne';

  @override
  String get settings_appearance_metric_ndl => 'NDL';

  @override
  String get settings_appearance_metric_ppHe => 'ppHe';

  @override
  String get settings_appearance_metric_ppN2 => 'ppN2';

  @override
  String get settings_appearance_metric_ppO2 => 'ppO2';

  @override
  String get settings_appearance_metric_pressure => 'Pression';

  @override
  String get settings_appearance_metric_sacRate => 'SAC Rate';

  @override
  String get settings_appearance_metric_surfaceGf => 'GF surface';

  @override
  String get settings_appearance_metric_temperature => 'Temperature';

  @override
  String get settings_appearance_metric_tts => 'TTS (Temps vers la surface)';

  @override
  String get settings_appearance_pressureThresholdMarkers =>
      'Marqueurs de seuil de pression';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'Afficher les marqueurs lorsque la pression du bloc franchit les seuils';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'Afficher les marqueurs lorsque la pression du bloc franchit les seuils de 2/3, 1/2 et 1/3';

  @override
  String get settings_appearance_rightYAxisMetric =>
      'Metrique de l\'axe Y droit';

  @override
  String get settings_appearance_rightYAxisMetric_subtitle =>
      'Metrique par defaut affichee sur l\'axe droit';

  @override
  String get settings_appearance_subsection_decompressionMetrics =>
      'Metriques de decompression';

  @override
  String get settings_appearance_subsection_defaultVisibleMetrics =>
      'Metriques visibles par defaut';

  @override
  String get settings_appearance_subsection_gasAnalysisMetrics =>
      'Metriques d\'analyse de gaz';

  @override
  String get settings_appearance_subsection_gradientFactorMetrics =>
      'Metriques de gradient factor';

  @override
  String get settings_appearance_theme_dark => 'Sombre';

  @override
  String get settings_appearance_theme_light => 'Clair';

  @override
  String get settings_appearance_theme_system => 'Defaut du systeme';

  @override
  String get settings_backToSettings_tooltip => 'Retour aux reglages';

  @override
  String get settings_cloudSync_appBar_title => 'Synchronisation cloud';

  @override
  String get settings_cloudSync_autoSync => 'Synchronisation automatique';

  @override
  String get settings_cloudSync_autoSync_subtitle =>
      'Synchroniser automatiquement apres les modifications';

  @override
  String settings_cloudSync_conflictItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elements necessitent votre attention',
      one: '1 element necessite votre attention',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_disabledBanner_content =>
      'La synchronisation cloud geree par l\'application est desactivee car vous utilisez un dossier de stockage personnalise. Le service de synchronisation de votre dossier (Dropbox, Google Drive, OneDrive, etc.) gere la synchronisation.';

  @override
  String get settings_cloudSync_disabledBanner_title =>
      'Synchronisation cloud desactivee';

  @override
  String get settings_cloudSync_header_advanced => 'Avance';

  @override
  String get settings_cloudSync_header_cloudProvider => 'Fournisseur cloud';

  @override
  String settings_cloudSync_header_conflicts(Object count) {
    return 'Conflits ($count)';
  }

  @override
  String get settings_cloudSync_header_syncBehavior =>
      'Comportement de synchronisation';

  @override
  String settings_cloudSync_lastSynced(Object time) {
    return 'Derniere synchronisation : $time';
  }

  @override
  String settings_cloudSync_pendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications en attente',
      one: '1 modification en attente',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_provider_connected => 'Connecte';

  @override
  String settings_cloudSync_provider_connectedTo(Object providerName) {
    return 'Connecte a $providerName';
  }

  @override
  String settings_cloudSync_provider_connectionFailed(
    Object providerName,
    Object error,
  ) {
    return 'Echec de la connexion a $providerName : $error';
  }

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'Synchroniser via Google Drive';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Synchroniser via Apple iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'Echec de l\'initialisation du fournisseur $providerName';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'Non disponible sur cette plateforme';

  @override
  String get settings_cloudSync_resetDialog_cancel => 'Annuler';

  @override
  String get settings_cloudSync_resetDialog_content =>
      'Ceci effacera tout l\'historique de synchronisation et recommencera a zero. Vos donnees ne seront pas supprimees, mais vous devrez peut-etre resoudre des conflits lors de la prochaine synchronisation.';

  @override
  String get settings_cloudSync_resetDialog_reset => 'Reinitialiser';

  @override
  String get settings_cloudSync_resetDialog_title =>
      'Reinitialiser l\'etat de synchronisation ?';

  @override
  String get settings_cloudSync_resetSuccess =>
      'Etat de synchronisation reinitialise';

  @override
  String get settings_cloudSync_resetSyncState =>
      'Reinitialiser l\'etat de synchronisation';

  @override
  String get settings_cloudSync_resetSyncState_subtitle =>
      'Effacer l\'historique de synchronisation et recommencer';

  @override
  String get settings_cloudSync_resolveConflicts => 'Resoudre les conflits';

  @override
  String get settings_cloudSync_selectProviderHint =>
      'Selectionnez un fournisseur cloud pour activer la synchronisation';

  @override
  String get settings_cloudSync_signOut => 'Deconnexion';

  @override
  String get settings_cloudSync_signOutDialog_cancel => 'Annuler';

  @override
  String get settings_cloudSync_signOutDialog_content =>
      'Ceci vous deconnectera du fournisseur cloud. Vos donnees locales resteront intactes.';

  @override
  String get settings_cloudSync_signOutDialog_signOut => 'Deconnexion';

  @override
  String get settings_cloudSync_signOutDialog_title => 'Se deconnecter ?';

  @override
  String get settings_cloudSync_signOutSuccess =>
      'Deconnecte du fournisseur cloud';

  @override
  String get settings_cloudSync_signOut_subtitle =>
      'Se deconnecter du fournisseur cloud';

  @override
  String get settings_cloudSync_status_conflictsDetected => 'Conflits detectes';

  @override
  String get settings_cloudSync_status_readyToSync => 'Pret a synchroniser';

  @override
  String get settings_cloudSync_status_syncComplete =>
      'Synchronisation terminee';

  @override
  String get settings_cloudSync_status_syncError => 'Erreur de synchronisation';

  @override
  String get settings_cloudSync_status_syncing => 'Synchronisation...';

  @override
  String get settings_cloudSync_storageSettings => 'Parametres de stockage';

  @override
  String get settings_cloudSync_syncNow => 'Synchroniser maintenant';

  @override
  String get settings_cloudSync_syncOnLaunch => 'Synchroniser au lancement';

  @override
  String get settings_cloudSync_syncOnLaunch_subtitle =>
      'Verifier les mises a jour au demarrage';

  @override
  String get settings_cloudSync_syncOnResume => 'Synchroniser a la reprise';

  @override
  String get settings_cloudSync_syncOnResume_subtitle =>
      'Verifier les mises a jour quand l\'application redevient active';

  @override
  String settings_cloudSync_syncProgressPercent(Object percent) {
    return 'Progression de la synchronisation : $percent pour cent';
  }

  @override
  String settings_cloudSync_time_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count jours',
      one: 'Il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_time_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count heures',
      one: 'Il y a 1 heure',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_time_justNow => 'A l\'instant';

  @override
  String settings_cloudSync_time_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count minutes',
      one: 'Il y a 1 minute',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_applyAll => 'Tout appliquer';

  @override
  String get settings_conflict_cancel => 'Annuler';

  @override
  String get settings_conflict_chooseResolution => 'Choisir la resolution';

  @override
  String get settings_conflict_close => 'Fermer';

  @override
  String get settings_conflict_close_tooltip =>
      'Fermer la boite de dialogue des conflits';

  @override
  String settings_conflict_counterLabel(Object current, Object total) {
    return 'Conflit $current sur $total';
  }

  @override
  String settings_conflict_errorLoading(Object error) {
    return 'Erreur lors du chargement des conflits : $error';
  }

  @override
  String get settings_conflict_keepBoth => 'Conserver les deux';

  @override
  String get settings_conflict_keepLocal => 'Conserver le local';

  @override
  String get settings_conflict_keepRemote => 'Conserver le distant';

  @override
  String get settings_conflict_localVersion => 'Version locale';

  @override
  String settings_conflict_modified(Object time) {
    return 'Modifie le : $time';
  }

  @override
  String get settings_conflict_next_tooltip => 'Conflit suivant';

  @override
  String get settings_conflict_noConflicts_message =>
      'Tous les conflits de synchronisation ont ete resolus.';

  @override
  String get settings_conflict_noConflicts_title => 'Aucun conflit';

  @override
  String get settings_conflict_noDataAvailable => 'Aucune donnee disponible';

  @override
  String get settings_conflict_previous_tooltip => 'Conflit precedent';

  @override
  String get settings_conflict_remoteVersion => 'Version distante';

  @override
  String settings_conflict_resolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conflits resolus',
      one: '1 conflit resolu',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_title => 'Resoudre les conflits';

  @override
  String get settings_data_appDefaultLocation =>
      'Emplacement par defaut de l\'application';

  @override
  String get settings_data_backup => 'Sauvegarde';

  @override
  String get settings_data_backup_subtitle =>
      'Creer une sauvegarde de vos donnees';

  @override
  String get settings_data_cloudSync => 'Synchronisation cloud';

  @override
  String get settings_data_customFolder => 'Dossier personnalise';

  @override
  String get settings_data_databaseStorage => 'Stockage de la base de donnees';

  @override
  String get settings_data_export_completed => 'Export termine';

  @override
  String get settings_data_export_exporting => 'Exportation...';

  @override
  String settings_data_export_failed(Object error) {
    return 'Echec de l\'export : $error';
  }

  @override
  String get settings_data_header_backupSync => 'Sauvegarde et synchronisation';

  @override
  String get settings_data_header_storage => 'Stockage';

  @override
  String get settings_data_import_completed => 'Operation terminee';

  @override
  String settings_data_import_failed(Object error) {
    return 'Echec de l\'operation : $error';
  }

  @override
  String get settings_data_offlineMaps => 'Cartes hors ligne';

  @override
  String get settings_data_offlineMaps_subtitle =>
      'Telecharger des cartes pour une utilisation hors ligne';

  @override
  String get settings_data_restore => 'Restaurer';

  @override
  String get settings_data_restoreDialog_cancel => 'Annuler';

  @override
  String get settings_data_restoreDialog_content =>
      'Attention : la restauration depuis une sauvegarde remplacera TOUTES les donnees actuelles par les donnees de la sauvegarde. Cette action est irreversible.\n\nVoulez-vous vraiment continuer ?';

  @override
  String get settings_data_restoreDialog_restore => 'Restaurer';

  @override
  String get settings_data_restoreDialog_title => 'Restaurer la sauvegarde';

  @override
  String get settings_data_restore_subtitle =>
      'Restaurer depuis une sauvegarde';

  @override
  String settings_data_syncTime_daysAgo(Object count) {
    return 'Il y a ${count}j';
  }

  @override
  String settings_data_syncTime_hoursAgo(Object count) {
    return 'Il y a ${count}h';
  }

  @override
  String get settings_data_syncTime_justNow => 'A l\'instant';

  @override
  String settings_data_syncTime_minutesAgo(Object count) {
    return 'Il y a ${count}min';
  }

  @override
  String settings_data_sync_lastSynced(Object time) {
    return 'Derniere synchronisation : $time';
  }

  @override
  String get settings_data_sync_notConfigured => 'Non configure';

  @override
  String get settings_data_sync_syncing => 'Synchronisation...';

  @override
  String get settings_decompression_aboutContent =>
      'Les Gradient Factors (GF) controlent le niveau de conservatisme de vos calculs de decompression. Le GF Low affecte les paliers profonds, tandis que le GF High affecte les paliers peu profonds.\n\nValeurs plus basses = plus conservateur = paliers deco plus longs\nValeurs plus hautes = moins conservateur = paliers deco plus courts';

  @override
  String get settings_decompression_aboutTitle =>
      'A propos des Gradient Factors';

  @override
  String get settings_decompression_currentSettings => 'Reglages actuels';

  @override
  String get settings_decompression_dialog_cancel => 'Annuler';

  @override
  String get settings_decompression_dialog_conservatismHint =>
      'Valeurs plus basses = plus conservateur (NDL plus longue / plus de deco)';

  @override
  String get settings_decompression_dialog_customValues =>
      'Valeurs personnalisees';

  @override
  String get settings_decompression_dialog_gfHigh => 'GF High';

  @override
  String get settings_decompression_dialog_gfLow => 'GF Low';

  @override
  String get settings_decompression_dialog_info =>
      'GF Low/High controlent le niveau de conservatisme de vos calculs de NDL et de decompression.';

  @override
  String get settings_decompression_dialog_presets => 'Preselections';

  @override
  String get settings_decompression_dialog_save => 'Enregistrer';

  @override
  String get settings_decompression_dialog_title => 'Gradient Factors';

  @override
  String settings_decompression_gfValue(Object gfLow, Object gfHigh) {
    return 'GF $gfLow/$gfHigh';
  }

  @override
  String get settings_decompression_header_gradientFactors =>
      'Gradient Factors';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'Selectionner le niveau de conservatisme $presetName';
  }

  @override
  String get settings_existingDb_cancel => 'Annuler';

  @override
  String get settings_existingDb_continue => 'Continuer';

  @override
  String get settings_existingDb_current => 'Actuelle';

  @override
  String get settings_existingDb_dialog_message =>
      'Une base de donnees Submersion existe deja dans ce dossier.';

  @override
  String get settings_existingDb_dialog_title =>
      'Base de donnees existante trouvee';

  @override
  String get settings_existingDb_existing => 'Existante';

  @override
  String get settings_existingDb_replaceWarning =>
      'La base de donnees existante sera sauvegardee avant d\'etre remplacee.';

  @override
  String get settings_existingDb_replaceWithMyData =>
      'Remplacer par mes donnees';

  @override
  String get settings_existingDb_replaceWithMyData_subtitle =>
      'Ecraser avec votre base de donnees actuelle';

  @override
  String get settings_existingDb_stat_buddies => 'Binomes';

  @override
  String get settings_existingDb_stat_dives => 'Plongees';

  @override
  String get settings_existingDb_stat_sites => 'Sites';

  @override
  String get settings_existingDb_stat_trips => 'Voyages';

  @override
  String get settings_existingDb_stat_users => 'Utilisateurs';

  @override
  String get settings_existingDb_unknown => 'Inconnu';

  @override
  String get settings_existingDb_useExisting => 'Utiliser la base existante';

  @override
  String get settings_existingDb_useExisting_subtitle =>
      'Basculer vers la base de donnees de ce dossier';

  @override
  String get settings_gfPreset_custom_description =>
      'Definissez vos propres valeurs';

  @override
  String get settings_gfPreset_custom_name => 'Personnalise';

  @override
  String get settings_gfPreset_high_description =>
      'Le plus conservateur, paliers deco plus longs';

  @override
  String get settings_gfPreset_high_name => 'Eleve';

  @override
  String get settings_gfPreset_low_description =>
      'Le moins conservateur, deco plus courte';

  @override
  String get settings_gfPreset_low_name => 'Faible';

  @override
  String get settings_gfPreset_medium_description => 'Approche equilibree';

  @override
  String get settings_gfPreset_medium_name => 'Moyen';

  @override
  String get settings_import_dialog_title => 'Importation des donnees';

  @override
  String get settings_import_doNotClose =>
      'Veuillez ne pas fermer l\'application';

  @override
  String settings_import_itemCount(Object current, Object total) {
    return '$current sur $total';
  }

  @override
  String get settings_import_phase_buddies => 'Importation des binomes...';

  @override
  String get settings_import_phase_certifications =>
      'Importation des certifications...';

  @override
  String get settings_import_phase_complete => 'Finalisation...';

  @override
  String get settings_import_phase_diveCenters =>
      'Importation des centres de plongee...';

  @override
  String get settings_import_phase_diveTypes =>
      'Importation des types de plongee...';

  @override
  String get settings_import_phase_dives => 'Importation des plongees...';

  @override
  String get settings_import_phase_equipment =>
      'Importation de l\'equipement...';

  @override
  String get settings_import_phase_equipmentSets =>
      'Importation des kits d\'equipement...';

  @override
  String get settings_import_phase_parsing => 'Analyse du fichier...';

  @override
  String get settings_import_phase_preparing => 'Preparation...';

  @override
  String get settings_import_phase_sites =>
      'Importation des sites de plongee...';

  @override
  String get settings_import_phase_tags => 'Importation des etiquettes...';

  @override
  String get settings_import_phase_trips => 'Importation des voyages...';

  @override
  String settings_import_progressLabel(
    Object phase,
    Object current,
    Object total,
  ) {
    return '$phase, $current sur $total';
  }

  @override
  String settings_import_progressPercent(Object percent) {
    return 'Progression de l\'importation : $percent pour cent';
  }

  @override
  String get settings_language_appBar_title => 'Langue';

  @override
  String get settings_language_selected => 'Selectionnee';

  @override
  String get settings_language_systemDefault => 'Defaut du systeme';

  @override
  String get settings_manage_diveTypes => 'Types de plongee';

  @override
  String get settings_manage_diveTypes_subtitle =>
      'Gerer les types de plongee personnalises';

  @override
  String get settings_manage_header_manageData => 'Gestion des donnees';

  @override
  String get settings_manage_species => 'Especes';

  @override
  String get settings_manage_species_subtitle =>
      'Gerer le catalogue d\'especes marines';

  @override
  String get settings_manage_tankPresets => 'Preselections de blocs';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Gerer les configurations de blocs personnalisees';

  @override
  String get settings_migrationProgress_doNotClose =>
      'Veuillez ne pas fermer l\'application';

  @override
  String get settings_migration_backupInfo =>
      'Une sauvegarde sera creee avant le deplacement. Vos donnees ne seront pas perdues.';

  @override
  String get settings_migration_cancel => 'Annuler';

  @override
  String get settings_migration_cloudSyncWarning =>
      'La synchronisation cloud geree par l\'application sera desactivee. Le service de synchronisation de votre dossier gerera la synchronisation.';

  @override
  String get settings_migration_dialog_message =>
      'Votre base de donnees sera deplacee :';

  @override
  String get settings_migration_dialog_title => 'Deplacer la base de donnees ?';

  @override
  String get settings_migration_from => 'De';

  @override
  String get settings_migration_moveDatabase => 'Deplacer la base de donnees';

  @override
  String get settings_migration_to => 'Vers';

  @override
  String settings_notifications_days(Object count) {
    return '$count jours';
  }

  @override
  String get settings_notifications_disabled_enableButton => 'Activer';

  @override
  String get settings_notifications_disabled_subtitle =>
      'Activez dans les reglages systeme pour recevoir des rappels';

  @override
  String get settings_notifications_disabled_title =>
      'Notifications desactivees';

  @override
  String get settings_notifications_enableServiceReminders =>
      'Activer les rappels d\'entretien';

  @override
  String get settings_notifications_enableServiceReminders_subtitle =>
      'Etre notifie lorsque l\'entretien de l\'equipement est du';

  @override
  String get settings_notifications_header_reminderSchedule =>
      'Calendrier des rappels';

  @override
  String get settings_notifications_header_serviceReminders =>
      'Rappels d\'entretien';

  @override
  String get settings_notifications_howItWorks_content =>
      'Les notifications sont programmees au lancement de l\'application et se rafraichissent periodiquement en arriere-plan. Vous pouvez personnaliser les rappels pour chaque equipement dans son ecran de modification.';

  @override
  String get settings_notifications_howItWorks_title => 'Comment ca fonctionne';

  @override
  String get settings_notifications_permissionRequired =>
      'Veuillez activer les notifications dans les reglages systeme';

  @override
  String get settings_notifications_remindBeforeDue =>
      'Me rappeler avant l\'echeance de l\'entretien :';

  @override
  String get settings_notifications_reminderTime => 'Heure du rappel';

  @override
  String get settings_profile_activeDiver_subtitle =>
      'Plongeur actif - appuyez pour changer';

  @override
  String get settings_profile_addNewDiver => 'Ajouter un nouveau plongeur';

  @override
  String get settings_profile_error_loadingDiver =>
      'Erreur lors du chargement du plongeur';

  @override
  String get settings_profile_header_activeDiver => 'Plongeur actif';

  @override
  String get settings_profile_header_manageDivers => 'Gerer les plongeurs';

  @override
  String get settings_profile_noDiverProfile => 'Aucun profil de plongeur';

  @override
  String get settings_profile_noDiverProfile_subtitle =>
      'Appuyez pour creer votre profil';

  @override
  String get settings_profile_switchDiver_title => 'Changer de plongeur';

  @override
  String settings_profile_switchedTo(Object diverName) {
    return 'Bascule vers $diverName';
  }

  @override
  String get settings_profile_viewAllDivers => 'Voir tous les plongeurs';

  @override
  String get settings_profile_viewAllDivers_subtitle =>
      'Ajouter ou modifier les profils de plongeurs';

  @override
  String get settings_section_about_subtitle =>
      'Infos et licences de l\'application';

  @override
  String get settings_section_about_title => 'A propos';

  @override
  String get settings_section_appearance_subtitle => 'Theme et affichage';

  @override
  String get settings_section_appearance_title => 'Apparence';

  @override
  String get settings_section_data_subtitle =>
      'Sauvegarde, restauration et stockage';

  @override
  String get settings_section_data_title => 'Donnees';

  @override
  String get settings_section_decompression_subtitle => 'Gradient factors';

  @override
  String get settings_section_decompression_title => 'Decompression';

  @override
  String get settings_section_diverProfile_subtitle =>
      'Plongeur actif et profils';

  @override
  String get settings_section_diverProfile_title => 'Profil du plongeur';

  @override
  String get settings_section_manage_subtitle =>
      'Types de plongee et preselections de blocs';

  @override
  String get settings_section_manage_title => 'Gestion';

  @override
  String get settings_section_notifications_subtitle => 'Rappels d\'entretien';

  @override
  String get settings_section_notifications_title => 'Notifications';

  @override
  String get settings_section_units_subtitle => 'Preferences de mesure';

  @override
  String get settings_section_units_title => 'Unites';

  @override
  String get settings_storage_appBar_title => 'Stockage de la base de donnees';

  @override
  String get settings_storage_appDefault => 'Defaut de l\'application';

  @override
  String get settings_storage_appDefaultLocation =>
      'Emplacement par defaut de l\'application';

  @override
  String get settings_storage_appDefault_subtitle =>
      'Emplacement de stockage standard de l\'application';

  @override
  String get settings_storage_currentLocation => 'Emplacement actuel';

  @override
  String get settings_storage_currentLocation_label => 'Emplacement actuel';

  @override
  String get settings_storage_customFolder => 'Dossier personnalise';

  @override
  String get settings_storage_customFolder_change => 'Modifier';

  @override
  String get settings_storage_customFolder_subtitle =>
      'Choisissez un dossier synchronise (Dropbox, Google Drive, etc.)';

  @override
  String settings_storage_dbStats(
    Object fileSize,
    Object diveCount,
    Object siteCount,
  ) {
    return '$fileSize - $diveCount plongees - $siteCount sites';
  }

  @override
  String get settings_storage_dismissError_tooltip => 'Ignorer l\'erreur';

  @override
  String get settings_storage_dismissSuccess_tooltip =>
      'Ignorer le message de succes';

  @override
  String get settings_storage_header_storageLocation =>
      'Emplacement de stockage';

  @override
  String get settings_storage_info_customActive =>
      'La synchronisation cloud geree par l\'application est desactivee. Le service de synchronisation de votre dossier (Dropbox, Google Drive, etc.) gere la synchronisation.';

  @override
  String get settings_storage_info_customAvailable =>
      'L\'utilisation d\'un dossier personnalise desactive la synchronisation cloud geree par l\'application. Le service de synchronisation de votre dossier gerera la synchronisation a la place.';

  @override
  String get settings_storage_loading => 'Chargement...';

  @override
  String get settings_storage_migrating_doNotClose =>
      'Veuillez ne pas fermer l\'application';

  @override
  String get settings_storage_migrating_movingDatabase =>
      'Deplacement de la base de donnees...';

  @override
  String get settings_storage_migrating_movingToAppDefault =>
      'Deplacement vers l\'emplacement par defaut...';

  @override
  String get settings_storage_migrating_replacingExisting =>
      'Remplacement de la base de donnees existante...';

  @override
  String get settings_storage_migrating_switchingToExisting =>
      'Basculement vers la base de donnees existante...';

  @override
  String get settings_storage_notSet => 'Non defini';

  @override
  String settings_storage_success_backupAt(Object path) {
    return 'L\'original est conserve en sauvegarde a :\n$path';
  }

  @override
  String get settings_storage_success_moved =>
      'Base de donnees deplacee avec succes';

  @override
  String get settings_summary_activeDiver => 'Plongeur actif';

  @override
  String get settings_summary_currentConfiguration => 'Configuration actuelle';

  @override
  String get settings_summary_depth => 'Profondeur';

  @override
  String get settings_summary_error => 'Erreur';

  @override
  String get settings_summary_gradientFactors => 'Gradient Factors';

  @override
  String get settings_summary_loading => 'Chargement...';

  @override
  String get settings_summary_notSet => 'Non defini';

  @override
  String get settings_summary_pressure => 'Pression';

  @override
  String get settings_summary_subtitle =>
      'Selectionnez une categorie a configurer';

  @override
  String get settings_summary_temperature => 'Temperature';

  @override
  String get settings_summary_theme => 'Theme';

  @override
  String get settings_summary_theme_dark => 'Sombre';

  @override
  String get settings_summary_theme_light => 'Clair';

  @override
  String get settings_summary_theme_system => 'Systeme';

  @override
  String get settings_summary_tip =>
      'Conseil : utilisez la section Donnees pour sauvegarder regulierement vos carnets de plongee.';

  @override
  String get settings_summary_title => 'Reglages';

  @override
  String get settings_summary_unitPreferences => 'Preferences d\'unites';

  @override
  String get settings_summary_units => 'Unites';

  @override
  String get settings_summary_volume => 'Volume';

  @override
  String get settings_summary_weight => 'Poids';

  @override
  String get settings_units_custom => 'Personnalise';

  @override
  String get settings_units_dateFormat => 'Format de date';

  @override
  String get settings_units_depth => 'Profondeur';

  @override
  String get settings_units_depth_feet => 'Pieds (ft)';

  @override
  String get settings_units_depth_meters => 'Metres (m)';

  @override
  String get settings_units_dialog_dateFormat => 'Format de date';

  @override
  String get settings_units_dialog_depthUnit => 'Unite de profondeur';

  @override
  String get settings_units_dialog_pressureUnit => 'Unite de pression';

  @override
  String get settings_units_dialog_sacRateUnit => 'Unite de SAC Rate';

  @override
  String get settings_units_dialog_temperatureUnit => 'Unite de temperature';

  @override
  String get settings_units_dialog_timeFormat => 'Format d\'heure';

  @override
  String get settings_units_dialog_volumeUnit => 'Unite de volume';

  @override
  String get settings_units_dialog_weightUnit => 'Unite de poids';

  @override
  String get settings_units_header_individualUnits => 'Unites individuelles';

  @override
  String get settings_units_header_timeDateFormat => 'Format heure et date';

  @override
  String get settings_units_header_unitSystem => 'Systeme d\'unites';

  @override
  String get settings_units_imperial => 'Imperial';

  @override
  String get settings_units_metric => 'Metrique';

  @override
  String get settings_units_pressure => 'Pression';

  @override
  String get settings_units_pressure_bar => 'Bar';

  @override
  String get settings_units_pressure_psi => 'PSI';

  @override
  String get settings_units_quickSelect => 'Selection rapide';

  @override
  String get settings_units_sacRate => 'SAC Rate';

  @override
  String get settings_units_sac_pressurePerMinute => 'Pression par minute';

  @override
  String get settings_units_sac_pressurePerMinute_subtitle =>
      'Pas de volume de bloc necessaire (bar/min ou psi/min)';

  @override
  String get settings_units_sac_volumePerMinute => 'Volume par minute';

  @override
  String get settings_units_sac_volumePerMinute_subtitle =>
      'Necessite le volume du bloc (L/min ou cuft/min)';

  @override
  String get settings_units_temperature => 'Temperature';

  @override
  String get settings_units_temperature_celsius => 'Celsius (°C)';

  @override
  String get settings_units_temperature_fahrenheit => 'Fahrenheit (°F)';

  @override
  String get settings_units_timeFormat => 'Format d\'heure';

  @override
  String get settings_units_volume => 'Volume';

  @override
  String get settings_units_volume_cubicFeet => 'Pieds cubes (cuft)';

  @override
  String get settings_units_volume_liters => 'Litres (L)';

  @override
  String get settings_units_weight => 'Poids';

  @override
  String get settings_units_weight_kilograms => 'Kilogrammes (kg)';

  @override
  String get settings_units_weight_pounds => 'Livres (lbs)';

  @override
  String get signatures_action_clear => 'Effacer';

  @override
  String get signatures_action_closeSignatureView => 'Fermer la vue signature';

  @override
  String get signatures_action_deleteSignature => 'Supprimer la signature';

  @override
  String get signatures_action_done => 'Terminé';

  @override
  String get signatures_action_readyToSign => 'Prêt à signer';

  @override
  String get signatures_action_request => 'Demander';

  @override
  String get signatures_action_saveSignature => 'Enregistrer la signature';

  @override
  String signatures_buddyCard_notSignedSemantics(Object name) {
    return 'Signature de $name, non signée';
  }

  @override
  String signatures_buddyCard_signedSemantics(Object name) {
    return 'Signature de $name, signée';
  }

  @override
  String get signatures_captureInstructorSignature =>
      'Capturer la signature de l\'instructeur';

  @override
  String signatures_deleteDialog_message(Object name) {
    return 'Voulez-vous vraiment supprimer la signature de $name ? Cette action est irréversible.';
  }

  @override
  String get signatures_deleteDialog_title => 'Supprimer la signature ?';

  @override
  String get signatures_drawSignatureHint =>
      'Dessinez votre signature ci-dessus';

  @override
  String get signatures_drawSignatureHintDetailed =>
      'Dessinez la signature ci-dessus avec le doigt ou un stylet';

  @override
  String get signatures_drawSignatureSemantics => 'Dessiner la signature';

  @override
  String get signatures_error_drawSignature =>
      'Veuillez dessiner une signature';

  @override
  String get signatures_error_enterSignerName =>
      'Veuillez entrer le nom du signataire';

  @override
  String get signatures_field_instructorName => 'Nom de l\'instructeur';

  @override
  String get signatures_field_instructorNameHint =>
      'Entrer le nom de l\'instructeur';

  @override
  String get signatures_handoff_title => 'Passez votre appareil à';

  @override
  String get signatures_instructorSignature => 'Signature de l\'instructeur';

  @override
  String get signatures_noSignatureImage => 'Aucune image de signature';

  @override
  String signatures_signHere(Object name) {
    return '$name - Signez ici';
  }

  @override
  String get signatures_signed => 'Signé';

  @override
  String signatures_signedCountSemantics(Object signed, Object total) {
    return '$signed sur $total binômes ont signé';
  }

  @override
  String signatures_signedDate(Object date) {
    return 'Signé le $date';
  }

  @override
  String get signatures_title => 'Signatures';

  @override
  String get signatures_viewSignature => 'Voir la signature';

  @override
  String signatures_viewSignatureSemantics(Object name) {
    return 'Voir la signature de $name';
  }

  @override
  String get statistics_appBar_title => 'Statistiques';

  @override
  String statistics_categoryCard_semanticLabel(Object title) {
    return 'Categorie de statistiques $title';
  }

  @override
  String get statistics_category_conditions_subtitle =>
      'Visibilite et temperature';

  @override
  String get statistics_category_conditions_title => 'Conditions';

  @override
  String get statistics_category_equipment_subtitle =>
      'Utilisation de l\'equipement et lestage';

  @override
  String get statistics_category_equipment_title => 'Equipement';

  @override
  String get statistics_category_gas_subtitle => 'Taux SAC et melanges gazeux';

  @override
  String get statistics_category_gas_title => 'Consommation d\'air';

  @override
  String get statistics_category_geographic_subtitle => 'Pays et regions';

  @override
  String get statistics_category_geographic_title => 'Geographie';

  @override
  String get statistics_category_marineLife_subtitle =>
      'Observations d\'especes';

  @override
  String get statistics_category_marineLife_title => 'Vie marine';

  @override
  String get statistics_category_profile_subtitle =>
      'Vitesses de remontee et deco';

  @override
  String get statistics_category_profile_title => 'Analyse de profil';

  @override
  String get statistics_category_progression_subtitle =>
      'Tendances de profondeur et de temps';

  @override
  String get statistics_category_progression_title => 'Progression';

  @override
  String get statistics_category_social_subtitle =>
      'Binomes et centres de plongee';

  @override
  String get statistics_category_social_title => 'Social';

  @override
  String get statistics_category_timePatterns_subtitle => 'Quand tu plonges';

  @override
  String get statistics_category_timePatterns_title => 'Repartition temporelle';

  @override
  String statistics_chart_barSemanticLabel(Object count) {
    return 'Diagramme en barres avec $count categories';
  }

  @override
  String statistics_chart_distributionSemanticLabel(Object count) {
    return 'Diagramme circulaire de distribution avec $count segments';
  }

  @override
  String statistics_chart_multiTrendSemanticLabel(Object seriesNames) {
    return 'Graphique de tendances multiples comparant $seriesNames';
  }

  @override
  String get statistics_chart_noBarData => 'Aucune donnee disponible';

  @override
  String get statistics_chart_noDistributionData =>
      'Aucune donnee de distribution disponible';

  @override
  String get statistics_chart_noTrendData =>
      'Aucune donnee de tendance disponible';

  @override
  String statistics_chart_trendSemanticLabel(Object count) {
    return 'Graphique de tendance montrant $count points de donnees';
  }

  @override
  String statistics_chart_trendSemanticLabelWithAxis(
    Object count,
    Object yAxisLabel,
  ) {
    return 'Graphique de tendance montrant $count points de donnees pour $yAxisLabel';
  }

  @override
  String get statistics_conditions_appBar_title => 'Conditions';

  @override
  String get statistics_conditions_entryMethod_empty =>
      'Aucune donnee de methode d\'entree disponible';

  @override
  String get statistics_conditions_entryMethod_error =>
      'Echec du chargement des donnees de methode d\'entree';

  @override
  String get statistics_conditions_entryMethod_subtitle => 'Bord, bateau, etc.';

  @override
  String get statistics_conditions_entryMethod_title => 'Methode d\'entree';

  @override
  String get statistics_conditions_temperature_empty =>
      'Aucune donnee de temperature disponible';

  @override
  String get statistics_conditions_temperature_error =>
      'Echec du chargement des donnees de temperature';

  @override
  String get statistics_conditions_temperature_seriesAvg => 'Moy';

  @override
  String get statistics_conditions_temperature_seriesMax => 'Max';

  @override
  String get statistics_conditions_temperature_seriesMin => 'Min';

  @override
  String get statistics_conditions_temperature_subtitle =>
      'Temperatures Min/Moy/Max';

  @override
  String get statistics_conditions_temperature_title =>
      'Temperature de l\'eau par mois';

  @override
  String get statistics_conditions_visibility_error =>
      'Echec du chargement des donnees de visibilite';

  @override
  String get statistics_conditions_visibility_subtitle =>
      'Plongees par condition de visibilite';

  @override
  String get statistics_conditions_visibility_title =>
      'Distribution de la visibilite';

  @override
  String get statistics_conditions_waterType_error =>
      'Echec du chargement des donnees de type d\'eau';

  @override
  String get statistics_conditions_waterType_subtitle =>
      'Plongees en eau salee vs eau douce';

  @override
  String get statistics_conditions_waterType_title => 'Type d\'eau';

  @override
  String get statistics_equipment_appBar_title => 'Equipement';

  @override
  String get statistics_equipment_mostUsedGear_error =>
      'Echec du chargement des donnees d\'equipement';

  @override
  String get statistics_equipment_mostUsedGear_subtitle =>
      'Equipement par nombre de plongees';

  @override
  String get statistics_equipment_mostUsedGear_title =>
      'Equipement le plus utilise';

  @override
  String get statistics_equipment_weightTrend_error =>
      'Echec du chargement de la tendance de lestage';

  @override
  String get statistics_equipment_weightTrend_subtitle =>
      'Lestage moyen dans le temps';

  @override
  String get statistics_equipment_weightTrend_title => 'Tendance de lestage';

  @override
  String get statistics_error_loadingStatistics =>
      'Erreur de chargement des statistiques';

  @override
  String get statistics_gas_appBar_title => 'Consommation d\'air';

  @override
  String get statistics_gas_gasMix_error =>
      'Echec du chargement des donnees de melange gazeux';

  @override
  String get statistics_gas_gasMix_subtitle => 'Plongees par type de gaz';

  @override
  String get statistics_gas_gasMix_title => 'Distribution des melanges gazeux';

  @override
  String get statistics_gas_sacByRole_empty =>
      'Aucune donnee multi-blocs disponible';

  @override
  String get statistics_gas_sacByRole_error =>
      'Echec du chargement du SAC par role';

  @override
  String get statistics_gas_sacByRole_subtitle =>
      'Consommation moyenne par type de bloc';

  @override
  String get statistics_gas_sacByRole_title => 'SAC par role du bloc';

  @override
  String get statistics_gas_sacRecords_best => 'Meilleur taux SAC';

  @override
  String get statistics_gas_sacRecords_empty => 'Aucune donnee SAC disponible';

  @override
  String get statistics_gas_sacRecords_error =>
      'Echec du chargement des records SAC';

  @override
  String get statistics_gas_sacRecords_highest => 'Taux SAC le plus eleve';

  @override
  String get statistics_gas_sacRecords_subtitle =>
      'Meilleure et pire consommation d\'air';

  @override
  String get statistics_gas_sacRecords_title => 'Records de taux SAC';

  @override
  String get statistics_gas_sacTrend_error =>
      'Echec du chargement de la tendance SAC';

  @override
  String get statistics_gas_sacTrend_subtitle => 'Moyenne mensuelle sur 5 ans';

  @override
  String get statistics_gas_sacTrend_title => 'Tendance du taux SAC';

  @override
  String get statistics_gas_tankRole_backGas => 'Gaz dorsal';

  @override
  String get statistics_gas_tankRole_bailout => 'Bailout';

  @override
  String get statistics_gas_tankRole_deco => 'Deco';

  @override
  String get statistics_gas_tankRole_diluent => 'Diluant';

  @override
  String get statistics_gas_tankRole_oxygenSupply => 'Alimentation O₂';

  @override
  String get statistics_gas_tankRole_pony => 'Pony';

  @override
  String get statistics_gas_tankRole_sidemountLeft => 'Sidemount G';

  @override
  String get statistics_gas_tankRole_sidemountRight => 'Sidemount D';

  @override
  String get statistics_gas_tankRole_stage => 'Stage';

  @override
  String get statistics_geographic_appBar_title => 'Geographie';

  @override
  String get statistics_geographic_countries_empty => 'Aucun pays visite';

  @override
  String get statistics_geographic_countries_error =>
      'Echec du chargement des donnees par pays';

  @override
  String get statistics_geographic_countries_subtitle => 'Plongees par pays';

  @override
  String statistics_geographic_countries_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count pays. En tete : $topName avec $topCount plongees';
  }

  @override
  String get statistics_geographic_countries_title => 'Pays visites';

  @override
  String get statistics_geographic_regions_empty => 'Aucune region exploree';

  @override
  String get statistics_geographic_regions_error =>
      'Echec du chargement des donnees par region';

  @override
  String get statistics_geographic_regions_subtitle => 'Plongees par region';

  @override
  String statistics_geographic_regions_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count regions. En tete : $topName avec $topCount plongees';
  }

  @override
  String get statistics_geographic_regions_title => 'Regions explorees';

  @override
  String get statistics_geographic_trips_empty => 'Aucune donnee de voyage';

  @override
  String get statistics_geographic_trips_error =>
      'Echec du chargement des donnees de voyage';

  @override
  String get statistics_geographic_trips_subtitle =>
      'Voyages les plus productifs';

  @override
  String statistics_geographic_trips_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count voyages. En tete : $topName avec $topCount plongees';
  }

  @override
  String get statistics_geographic_trips_title => 'Plongees par voyage';

  @override
  String get statistics_listContent_selectedSuffix => ', selectionne';

  @override
  String get statistics_marineLife_appBar_title => 'Vie marine';

  @override
  String get statistics_marineLife_bestSites_empty => 'Aucune donnee de site';

  @override
  String get statistics_marineLife_bestSites_error =>
      'Echec du chargement des donnees de site';

  @override
  String get statistics_marineLife_bestSites_subtitle =>
      'Sites avec la plus grande variete d\'especes';

  @override
  String statistics_marineLife_bestSites_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count sites. Meilleur : $topName avec $topCount especes';
  }

  @override
  String get statistics_marineLife_bestSites_title =>
      'Meilleurs sites pour la vie marine';

  @override
  String get statistics_marineLife_mostCommon_empty =>
      'Aucune donnee d\'observation';

  @override
  String get statistics_marineLife_mostCommon_error =>
      'Echec du chargement des donnees d\'observation';

  @override
  String get statistics_marineLife_mostCommon_subtitle =>
      'Especes observees le plus souvent';

  @override
  String statistics_marineLife_mostCommon_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count especes. La plus courante : $topName avec $topCount observations';
  }

  @override
  String get statistics_marineLife_mostCommon_title =>
      'Observations les plus courantes';

  @override
  String get statistics_marineLife_speciesSpotted => 'Especes observees';

  @override
  String get statistics_profile_appBar_title => 'Analyse de profil';

  @override
  String get statistics_profile_ascentDescent_empty =>
      'Aucune donnee de profil disponible';

  @override
  String get statistics_profile_ascentDescent_error =>
      'Echec du chargement des donnees de vitesse';

  @override
  String get statistics_profile_ascentDescent_subtitle =>
      'A partir des donnees de profil de plongee';

  @override
  String get statistics_profile_ascentDescent_title =>
      'Vitesses moyennes de remontee et de descente';

  @override
  String get statistics_profile_avgAscent => 'Remontee moy.';

  @override
  String get statistics_profile_avgDescent => 'Descente moy.';

  @override
  String get statistics_profile_deco_decoDives => 'Plongees deco';

  @override
  String get statistics_profile_deco_decoLabel => 'Deco';

  @override
  String get statistics_profile_deco_decoRate => 'Taux deco';

  @override
  String get statistics_profile_deco_empty => 'Aucune donnee deco disponible';

  @override
  String get statistics_profile_deco_error =>
      'Echec du chargement des donnees deco';

  @override
  String get statistics_profile_deco_noDeco => 'Sans deco';

  @override
  String statistics_profile_deco_semanticLabel(Object percentage) {
    return 'Taux de decompression : $percentage% des plongees ont necessite des paliers de decompression';
  }

  @override
  String get statistics_profile_deco_subtitle =>
      'Plongees ayant necessite des paliers de decompression';

  @override
  String get statistics_profile_deco_title => 'Obligation de decompression';

  @override
  String get statistics_profile_timeAtDepth_empty =>
      'Aucune donnee de profondeur disponible';

  @override
  String get statistics_profile_timeAtDepth_error =>
      'Echec du chargement des donnees de plage de profondeur';

  @override
  String get statistics_profile_timeAtDepth_subtitle =>
      'Temps approximatif passe a chaque profondeur';

  @override
  String get statistics_profile_timeAtDepth_title =>
      'Temps par plage de profondeur';

  @override
  String statistics_profile_timeAtDepth_valueFormat(Object value) {
    return '$value min';
  }

  @override
  String get statistics_progression_appBar_title => 'Progression de plongee';

  @override
  String get statistics_progression_bottomTime_error =>
      'Echec du chargement de la tendance de temps au fond';

  @override
  String get statistics_progression_bottomTime_subtitle =>
      'Duree moyenne par mois';

  @override
  String get statistics_progression_bottomTime_title =>
      'Tendance du temps au fond';

  @override
  String get statistics_progression_cumulative_error =>
      'Echec du chargement des donnees cumulees';

  @override
  String get statistics_progression_cumulative_subtitle =>
      'Total de plongees dans le temps';

  @override
  String get statistics_progression_cumulative_title =>
      'Nombre cumule de plongees';

  @override
  String get statistics_progression_depthProgression_error =>
      'Echec du chargement de la progression de profondeur';

  @override
  String get statistics_progression_depthProgression_subtitle =>
      'Profondeur max mensuelle sur 5 ans';

  @override
  String get statistics_progression_depthProgression_title =>
      'Progression de la profondeur maximale';

  @override
  String get statistics_progression_divesPerYear_empty =>
      'Aucune donnee annuelle disponible';

  @override
  String get statistics_progression_divesPerYear_error =>
      'Echec du chargement des donnees annuelles';

  @override
  String get statistics_progression_divesPerYear_subtitle =>
      'Comparaison annuelle du nombre de plongees';

  @override
  String get statistics_progression_divesPerYear_title => 'Plongees par an';

  @override
  String get statistics_ranking_countLabel_dives => 'plongees';

  @override
  String get statistics_ranking_countLabel_sightings => 'observations';

  @override
  String get statistics_ranking_countLabel_species => 'especes';

  @override
  String get statistics_ranking_emptyState => 'Aucune donnee';

  @override
  String statistics_ranking_itemCount(Object count, Object label) {
    return '$count $label';
  }

  @override
  String statistics_ranking_moreItems(Object count) {
    return 'et $count de plus';
  }

  @override
  String statistics_ranking_semanticLabel(
    Object name,
    Object rank,
    Object count,
    Object label,
  ) {
    return '$name, rang $rank, $count $label';
  }

  @override
  String get statistics_records_appBar_title => 'Records de plongee';

  @override
  String get statistics_records_coldestDive => 'Plongee la plus froide';

  @override
  String get statistics_records_deepestDive => 'Plongee la plus profonde';

  @override
  String statistics_records_diveNumber(Object number) {
    return 'Plongee n°$number';
  }

  @override
  String get statistics_records_emptySubtitle =>
      'Commence a enregistrer des plongees pour voir tes records ici';

  @override
  String get statistics_records_emptyTitle => 'Aucun record';

  @override
  String get statistics_records_error => 'Erreur de chargement des records';

  @override
  String get statistics_records_firstDive => 'Premiere plongee';

  @override
  String get statistics_records_longestDive => 'Plongee la plus longue';

  @override
  String statistics_records_longestDiveValue(Object minutes) {
    return '$minutes min';
  }

  @override
  String statistics_records_milestoneSemanticLabel(
    Object title,
    Object siteName,
  ) {
    return '$title : $siteName';
  }

  @override
  String get statistics_records_milestones => 'Jalons';

  @override
  String get statistics_records_mostRecentDive => 'Plongee la plus recente';

  @override
  String statistics_records_recordSemanticLabel(
    Object title,
    Object value,
    Object siteName,
  ) {
    return '$title : $value a $siteName';
  }

  @override
  String get statistics_records_retry => 'Reessayer';

  @override
  String get statistics_records_shallowestDive => 'Plongee la moins profonde';

  @override
  String get statistics_records_unknownSite => 'Site inconnu';

  @override
  String get statistics_records_warmestDive => 'Plongee la plus chaude';

  @override
  String statistics_sectionCard_semanticLabel(Object title) {
    return 'Section $title';
  }

  @override
  String get statistics_social_appBar_title => 'Social et binomes';

  @override
  String get statistics_social_soloVsBuddy_empty =>
      'Aucune donnee de plongee disponible';

  @override
  String get statistics_social_soloVsBuddy_error =>
      'Echec du chargement des donnees de binome';

  @override
  String get statistics_social_soloVsBuddy_solo => 'Solo';

  @override
  String get statistics_social_soloVsBuddy_subtitle =>
      'Plonger avec ou sans compagnon';

  @override
  String get statistics_social_soloVsBuddy_title =>
      'Plongees solo vs en binome';

  @override
  String get statistics_social_soloVsBuddy_withBuddy => 'Avec binome';

  @override
  String get statistics_social_topBuddies_error =>
      'Echec du chargement du classement des binomes';

  @override
  String get statistics_social_topBuddies_subtitle =>
      'Compagnons de plongee les plus frequents';

  @override
  String get statistics_social_topBuddies_title =>
      'Meilleurs binomes de plongee';

  @override
  String get statistics_social_topDiveCenters_error =>
      'Echec du chargement du classement des centres de plongee';

  @override
  String get statistics_social_topDiveCenters_subtitle =>
      'Operateurs les plus visites';

  @override
  String get statistics_social_topDiveCenters_title =>
      'Meilleurs centres de plongee';

  @override
  String get statistics_summary_avgDepth => 'Prof. moyenne';

  @override
  String get statistics_summary_avgTemp => 'Temp. moyenne';

  @override
  String get statistics_summary_depthDistribution_empty =>
      'Le graphique apparaitra lorsque tu enregistreras des plongees';

  @override
  String get statistics_summary_depthDistribution_semanticLabel =>
      'Diagramme circulaire montrant la distribution de profondeur';

  @override
  String get statistics_summary_depthDistribution_title =>
      'Distribution de la profondeur';

  @override
  String get statistics_summary_diveTypes_empty =>
      'Le graphique apparaitra lorsque tu enregistreras des plongees';

  @override
  String statistics_summary_diveTypes_moreTypes(Object count) {
    return 'et $count types de plus';
  }

  @override
  String get statistics_summary_diveTypes_semanticLabel =>
      'Diagramme circulaire montrant la distribution des types de plongee';

  @override
  String get statistics_summary_diveTypes_title => 'Types de plongee';

  @override
  String get statistics_summary_divesByMonth_empty =>
      'Le graphique apparaitra lorsque tu enregistreras des plongees';

  @override
  String get statistics_summary_divesByMonth_semanticLabel =>
      'Diagramme en barres montrant les plongees par mois';

  @override
  String get statistics_summary_divesByMonth_title => 'Plongees par mois';

  @override
  String statistics_summary_divesByMonth_tooltip(
    Object fullLabel,
    Object count,
  ) {
    return '$fullLabel\n$count plongees';
  }

  @override
  String get statistics_summary_header_subtitle =>
      'Selectionne une categorie pour explorer les statistiques detaillees';

  @override
  String get statistics_summary_header_title => 'Apercu des statistiques';

  @override
  String get statistics_summary_maxDepth => 'Prof. max';

  @override
  String get statistics_summary_sitesVisited => 'Sites visites';

  @override
  String statistics_summary_tagUsage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongees',
      one: '1 plongee',
    );
    return '$_temp0';
  }

  @override
  String get statistics_summary_tagUsage_empty => 'Aucun tag cree';

  @override
  String get statistics_summary_tagUsage_emptyHint =>
      'Ajoute des tags aux plongees pour voir les statistiques';

  @override
  String statistics_summary_tagUsage_moreTags(Object count) {
    return 'et $count tags de plus';
  }

  @override
  String statistics_summary_tagUsage_tagCount(Object count) {
    return '$count tags';
  }

  @override
  String get statistics_summary_tagUsage_title => 'Utilisation des tags';

  @override
  String statistics_summary_topDiveSites_diveCount(Object count) {
    return '$count plongees';
  }

  @override
  String get statistics_summary_topDiveSites_empty => 'Aucun site de plongee';

  @override
  String get statistics_summary_topDiveSites_title =>
      'Meilleurs sites de plongee';

  @override
  String statistics_summary_topDiveSites_totalCount(Object count) {
    return '$count au total';
  }

  @override
  String get statistics_summary_totalDives => 'Total plongees';

  @override
  String get statistics_summary_totalTime => 'Temps total';

  @override
  String get statistics_timePatterns_appBar_title => 'Repartition temporelle';

  @override
  String get statistics_timePatterns_dayOfWeek_empty =>
      'Aucune donnee disponible';

  @override
  String get statistics_timePatterns_dayOfWeek_error =>
      'Echec du chargement des donnees par jour de la semaine';

  @override
  String get statistics_timePatterns_dayOfWeek_fri => 'Ven';

  @override
  String get statistics_timePatterns_dayOfWeek_mon => 'Lun';

  @override
  String get statistics_timePatterns_dayOfWeek_sat => 'Sam';

  @override
  String get statistics_timePatterns_dayOfWeek_subtitle =>
      'Quand plonges-tu le plus ?';

  @override
  String get statistics_timePatterns_dayOfWeek_sun => 'Dim';

  @override
  String get statistics_timePatterns_dayOfWeek_thu => 'Jeu';

  @override
  String get statistics_timePatterns_dayOfWeek_title =>
      'Plongees par jour de la semaine';

  @override
  String get statistics_timePatterns_dayOfWeek_tue => 'Mar';

  @override
  String get statistics_timePatterns_dayOfWeek_wed => 'Mer';

  @override
  String get statistics_timePatterns_month_apr => 'Avr';

  @override
  String get statistics_timePatterns_month_aug => 'Aou';

  @override
  String get statistics_timePatterns_month_dec => 'Dec';

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
  String get statistics_timePatterns_month_oct => 'Oct';

  @override
  String get statistics_timePatterns_month_sep => 'Sep';

  @override
  String get statistics_timePatterns_seasonal_empty =>
      'Aucune donnee disponible';

  @override
  String get statistics_timePatterns_seasonal_error =>
      'Echec du chargement des donnees saisonnieres';

  @override
  String get statistics_timePatterns_seasonal_subtitle =>
      'Plongees par mois (toutes annees)';

  @override
  String get statistics_timePatterns_seasonal_title => 'Tendances saisonnieres';

  @override
  String get statistics_timePatterns_surfaceInterval_average => 'Moyenne';

  @override
  String get statistics_timePatterns_surfaceInterval_empty =>
      'Aucune donnee d\'intervalle de surface disponible';

  @override
  String get statistics_timePatterns_surfaceInterval_error =>
      'Echec du chargement des donnees d\'intervalle de surface';

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
  String get statistics_timePatterns_surfaceInterval_maximum => 'Maximum';

  @override
  String get statistics_timePatterns_surfaceInterval_minimum => 'Minimum';

  @override
  String get statistics_timePatterns_surfaceInterval_subtitle =>
      'Temps entre les plongees';

  @override
  String get statistics_timePatterns_surfaceInterval_title =>
      'Statistiques d\'intervalle de surface';

  @override
  String get statistics_timePatterns_timeOfDay_error =>
      'Echec du chargement des donnees par heure de la journee';

  @override
  String get statistics_timePatterns_timeOfDay_subtitle =>
      'Matin, apres-midi, soir ou nuit';

  @override
  String get statistics_timePatterns_timeOfDay_title =>
      'Plongees par heure de la journee';

  @override
  String get statistics_tooltip_diveRecords => 'Records de plongee';

  @override
  String get statistics_tooltip_refreshRecords => 'Actualiser les records';

  @override
  String get statistics_tooltip_refreshStatistics =>
      'Actualiser les statistiques';

  @override
  String statistics_valueCard_semanticLabel(Object label, Object value) {
    return '$label : $value';
  }

  @override
  String get surfaceInterval_aboutTissueLoading_body =>
      'Votre corps possède 16 compartiments tissulaires qui absorbent et libèrent l\'azote à des vitesses différentes. Les tissus rapides (comme le sang) se saturent rapidement mais se désaturent aussi rapidement. Les tissus lents (comme les os et la graisse) mettent plus de temps à se charger et à se décharger. Le « compartiment directeur » est celui qui est le plus saturé et contrôle généralement votre durée totale de remontée (DTR). Pendant un intervalle de surface, tous les tissus se désaturent vers les niveaux de saturation de surface (~40% de charge).';

  @override
  String get surfaceInterval_aboutTissueLoading_title =>
      'À propos du chargement tissulaire';

  @override
  String get surfaceInterval_action_resetDefaults =>
      'Réinitialiser aux valeurs par défaut';

  @override
  String get surfaceInterval_disclaimer =>
      'Cet outil est uniquement à des fins de planification. Utilisez toujours un ordinateur de plongée et suivez votre formation. Les résultats sont basés sur l\'algorithme Buhlmann ZH-L16C et peuvent différer de votre ordinateur.';

  @override
  String get surfaceInterval_field_depth => 'Profondeur';

  @override
  String get surfaceInterval_field_gasMix => 'Mélange gazeux : ';

  @override
  String get surfaceInterval_field_he => 'He';

  @override
  String get surfaceInterval_field_o2 => 'O₂';

  @override
  String get surfaceInterval_field_time => 'Temps';

  @override
  String surfaceInterval_firstDive_depthSemantics(Object depth, Object unit) {
    return 'Profondeur de la première plongée : $depth $unit';
  }

  @override
  String surfaceInterval_firstDive_timeSemantics(Object time) {
    return 'Temps de la première plongée : $time minutes';
  }

  @override
  String get surfaceInterval_firstDive_title => 'Première plongée';

  @override
  String surfaceInterval_format_hours(Object count) {
    return '$count heures';
  }

  @override
  String surfaceInterval_format_minutes(Object count) {
    return '$count min';
  }

  @override
  String get surfaceInterval_gasMix_air => 'Air';

  @override
  String surfaceInterval_gasMix_ean(Object percent) {
    return 'Nitrox $percent';
  }

  @override
  String surfaceInterval_gasMix_trimix(Object o2, Object he) {
    return 'Trimix $o2/$he';
  }

  @override
  String surfaceInterval_heSemantics(Object percent) {
    return 'Hélium : $percent%';
  }

  @override
  String surfaceInterval_o2Semantics(Object percent) {
    return 'O2 : $percent%';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Intervalle actuel';

  @override
  String get surfaceInterval_result_inDeco => 'En déco';

  @override
  String get surfaceInterval_result_increaseInterval =>
      'Augmentez l\'intervalle de surface ou réduisez la profondeur/durée de la deuxième plongée';

  @override
  String get surfaceInterval_result_minimumInterval =>
      'Intervalle de surface minimum';

  @override
  String get surfaceInterval_result_ndlForSecondDive =>
      'DTR pour la 2e plongée';

  @override
  String surfaceInterval_result_ndlMinutes(Object minutes) {
    return '$minutes min DTR';
  }

  @override
  String get surfaceInterval_result_notYetSafe =>
      'Pas encore sûr, augmentez l\'intervalle de surface';

  @override
  String get surfaceInterval_result_safeToDive => 'Sûr pour plonger';

  @override
  String surfaceInterval_result_semantics(
    Object interval,
    Object current,
    Object ndl,
    Object status,
  ) {
    return 'Intervalle de surface minimum : $interval. Intervalle actuel : $current. DTR pour la deuxième plongée : $ndl. $status';
  }

  @override
  String surfaceInterval_secondDive_depthSemantics(Object depth, Object unit) {
    return 'Profondeur de la deuxième plongée : $depth $unit';
  }

  @override
  String get surfaceInterval_secondDive_gasAir => '(Air)';

  @override
  String surfaceInterval_secondDive_timeSemantics(Object time) {
    return 'Temps de la deuxième plongée : $time minutes';
  }

  @override
  String get surfaceInterval_secondDive_title => 'Deuxième plongée';

  @override
  String surfaceInterval_tissueRecovery_chartSemantics(Object interval) {
    return 'Graphique de récupération tissulaire montrant la désaturation des 16 compartiments pendant un intervalle de surface de $interval';
  }

  @override
  String get surfaceInterval_tissueRecovery_compartmentsLabel =>
      'Compartiments (par vitesse de demi-période)';

  @override
  String get surfaceInterval_tissueRecovery_description =>
      'Affichage de la désaturation de chacun des 16 compartiments tissulaires pendant l\'intervalle de surface';

  @override
  String get surfaceInterval_tissueRecovery_fast => 'Rapide (C1-5)';

  @override
  String surfaceInterval_tissueRecovery_leadingCompartment(Object number) {
    return 'Compartiment directeur : C$number';
  }

  @override
  String get surfaceInterval_tissueRecovery_loadingPercent => 'Charge %';

  @override
  String get surfaceInterval_tissueRecovery_medium => 'Moyen (C6-10)';

  @override
  String get surfaceInterval_tissueRecovery_min => 'Min';

  @override
  String get surfaceInterval_tissueRecovery_now => 'Maintenant';

  @override
  String get surfaceInterval_tissueRecovery_slow => 'Lent (C11-16)';

  @override
  String get surfaceInterval_tissueRecovery_title => 'Récupération tissulaire';

  @override
  String get surfaceInterval_title => 'Intervalle de surface';

  @override
  String tags_action_createNamed(Object tagName) {
    return 'Créer « $tagName »';
  }

  @override
  String get tags_action_createTag => 'Créer une étiquette';

  @override
  String get tags_action_deleteTag => 'Supprimer l\'étiquette';

  @override
  String tags_dialog_deleteMessage(Object tagName) {
    return 'Voulez-vous vraiment supprimer « $tagName » ? Cela la supprimera de toutes les plongées.';
  }

  @override
  String get tags_dialog_deleteTitle => 'Supprimer l\'étiquette ?';

  @override
  String get tags_empty =>
      'Aucune étiquette pour le moment. Créez des étiquettes lors de la modification des plongées.';

  @override
  String get tags_hint_addMoreTags => 'Ajouter plus d\'étiquettes...';

  @override
  String get tags_hint_addTags => 'Ajouter des étiquettes...';

  @override
  String get tags_title_manageTags => 'Gérer les étiquettes';

  @override
  String get tank_al30Stage_description => 'Bloc aluminium 30 cu ft stage';

  @override
  String get tank_al30Stage_displayName => 'AL30 Stage';

  @override
  String get tank_al40Stage_description => 'Bloc aluminium 40 cu ft stage';

  @override
  String get tank_al40Stage_displayName => 'AL40 Stage';

  @override
  String get tank_al40_description => 'Bloc aluminium 40 cu ft (pony)';

  @override
  String get tank_al40_displayName => 'AL40';

  @override
  String get tank_al63_description => 'Bloc aluminium 63 cu ft';

  @override
  String get tank_al63_displayName => 'AL63';

  @override
  String get tank_al80_description =>
      'Bloc aluminium 80 cu ft (le plus courant)';

  @override
  String get tank_al80_displayName => 'AL80';

  @override
  String get tank_hp100_description => 'Bloc acier haute pression 100 cu ft';

  @override
  String get tank_hp100_displayName => 'HP100';

  @override
  String get tank_hp120_description => 'Bloc acier haute pression 120 cu ft';

  @override
  String get tank_hp120_displayName => 'HP120';

  @override
  String get tank_hp80_description => 'Bloc acier haute pression 80 cu ft';

  @override
  String get tank_hp80_displayName => 'HP80';

  @override
  String get tank_lp85_description => 'Bloc acier basse pression 85 cu ft';

  @override
  String get tank_lp85_displayName => 'LP85';

  @override
  String get tank_steel10_description => 'Bloc acier 10 litres (Europe)';

  @override
  String get tank_steel10_displayName => 'Acier 10L';

  @override
  String get tank_steel12_description => 'Bloc acier 12 litres (Europe)';

  @override
  String get tank_steel12_displayName => 'Acier 12L';

  @override
  String get tank_steel15_description => 'Bloc acier 15 litres (Europe)';

  @override
  String get tank_steel15_displayName => 'Acier 15L';

  @override
  String get tides_action_refresh => 'Actualiser les données de marée';

  @override
  String get tides_chart_24hourForecast => 'Prévisions 24 heures';

  @override
  String tides_chart_heightAxis(Object depthSymbol) {
    return 'Hauteur ($depthSymbol)';
  }

  @override
  String get tides_chart_msl => 'NMM';

  @override
  String tides_chart_nowLabel(Object nowHeightStr, Object nowTimeStr) {
    return ' Maintenant $nowTimeStr $nowHeightStr';
  }

  @override
  String get tides_error_unableToLoad =>
      'Impossible de charger les données de marée';

  @override
  String get tides_error_unableToLoadChart =>
      'Impossible de charger le graphique';

  @override
  String tides_label_ago(Object duration) {
    return 'il y a $duration';
  }

  @override
  String tides_label_currentHeight(Object height, Object depthSymbol) {
    return 'Actuel : $height$depthSymbol';
  }

  @override
  String tides_label_fromNow(Object duration) {
    return 'dans $duration';
  }

  @override
  String get tides_label_high => 'Haute';

  @override
  String get tides_label_highIn => 'Haute dans';

  @override
  String get tides_label_highTide => 'Marée haute';

  @override
  String get tides_label_low => 'Basse';

  @override
  String get tides_label_lowIn => 'Basse dans';

  @override
  String get tides_label_lowTide => 'Marée basse';

  @override
  String tides_label_tideIn(Object duration) {
    return 'dans $duration';
  }

  @override
  String get tides_label_tideTimes => 'Horaires des marées';

  @override
  String get tides_label_today => 'Aujourd\'hui';

  @override
  String get tides_label_tomorrow => 'Demain';

  @override
  String get tides_label_upcomingTides => 'Marées à venir';

  @override
  String get tides_legend_highTide => 'Marée haute';

  @override
  String get tides_legend_lowTide => 'Marée basse';

  @override
  String get tides_legend_now => 'Maintenant';

  @override
  String get tides_legend_tideLevel => 'Niveau de marée';

  @override
  String get tides_noDataAvailable => 'Aucune donnée de marée disponible';

  @override
  String get tides_noDataForLocation =>
      'Données de marée non disponibles pour cette position';

  @override
  String get tides_noExtremesData => 'Aucune donnée d\'extrêmes';

  @override
  String get tides_noTideTimesAvailable => 'Aucun horaire de marée disponible';

  @override
  String tides_semantic_currentTide(
    Object tideState,
    Object height,
    Object depthSymbol,
    Object nextExtreme,
  ) {
    return 'Marée $tideState, $height$depthSymbol$nextExtreme';
  }

  @override
  String tides_semantic_extremeItem(
    Object typeLabel,
    Object time,
    Object height,
    Object depthSymbol,
  ) {
    return 'Marée $typeLabel à $time, $height$depthSymbol';
  }

  @override
  String tides_semantic_tideChart(Object extremesSummary) {
    return 'Graphique de marée. $extremesSummary';
  }

  @override
  String tides_semantic_tideState(Object state) {
    return 'État de la marée : $state';
  }

  @override
  String get tides_title => 'Marées';

  @override
  String get transfer_appBar_title => 'Transfert';

  @override
  String get transfer_computers_aboutContent =>
      'Connectez votre ordinateur de plongee via Bluetooth pour telecharger les carnets de plongee directement dans l\'application. Les ordinateurs compatibles incluent Suunto, Shearwater, Garmin, Mares et de nombreuses autres marques populaires.\n\nLes utilisateurs d\'Apple Watch Ultra peuvent importer les donnees de plongee directement depuis l\'app Sante, y compris la profondeur, la duree et la frequence cardiaque.';

  @override
  String get transfer_computers_aboutTitle =>
      'A propos des ordinateurs de plongee';

  @override
  String get transfer_computers_appleWatchHeader => 'Apple Watch';

  @override
  String get transfer_computers_appleWatchSubtitle =>
      'Importer les plongees enregistrees sur Apple Watch Ultra';

  @override
  String get transfer_computers_appleWatchTitle =>
      'Importer depuis l\'Apple Watch';

  @override
  String get transfer_computers_connectSubtitle =>
      'Decouvrir et associer un ordinateur de plongee';

  @override
  String get transfer_computers_connectTitle =>
      'Connecter un nouvel ordinateur';

  @override
  String get transfer_computers_errorLoading =>
      'Erreur lors du chargement des ordinateurs';

  @override
  String get transfer_computers_loading => 'Chargement...';

  @override
  String get transfer_computers_manageTitle => 'Gerer les ordinateurs';

  @override
  String get transfer_computers_noComputersSaved =>
      'Aucun ordinateur enregistre';

  @override
  String transfer_computers_savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ordinateurs enregistres',
      one: 'ordinateur enregistre',
    );
    return '$count $_temp0';
  }

  @override
  String get transfer_computers_sectionHeader => 'Ordinateurs de plongee';

  @override
  String get transfer_csvExport_cancelButton => 'Annuler';

  @override
  String get transfer_csvExport_dataTypeHeader => 'Type de donnees';

  @override
  String get transfer_csvExport_descriptionDives =>
      'Exporter tous les carnets de plongee en tableur';

  @override
  String get transfer_csvExport_descriptionEquipment =>
      'Exporter l\'inventaire d\'equipement et les informations de service';

  @override
  String get transfer_csvExport_descriptionSites =>
      'Exporter les sites de plongee et leurs details';

  @override
  String get transfer_csvExport_dialogTitle => 'Exporter en CSV';

  @override
  String get transfer_csvExport_exportButton => 'Exporter en CSV';

  @override
  String get transfer_csvExport_optionDivesTitle => 'CSV Plongees';

  @override
  String get transfer_csvExport_optionEquipmentTitle => 'CSV Equipement';

  @override
  String get transfer_csvExport_optionSitesTitle => 'CSV Sites';

  @override
  String transfer_csvExport_semanticLabel(Object typeName) {
    return 'Exporter $typeName';
  }

  @override
  String get transfer_csvExport_typeDives => 'Plongees';

  @override
  String get transfer_csvExport_typeEquipment => 'Equipement';

  @override
  String get transfer_csvExport_typeSites => 'Sites';

  @override
  String get transfer_detail_backTooltip => 'Retour au transfert';

  @override
  String get transfer_export_aboutContent =>
      'Exportez vos donnees de plongee dans differents formats. Le PDF cree un carnet de plongee imprimable. L\'UDDF est un format universel compatible avec la plupart des logiciels de carnet de plongee. Les fichiers CSV peuvent etre ouverts dans des applications de tableur.';

  @override
  String get transfer_export_aboutTitle => 'A propos de l\'export';

  @override
  String get transfer_export_completed => 'Export termine';

  @override
  String get transfer_export_csvSubtitle => 'Format tableur';

  @override
  String get transfer_export_csvTitle => 'Export CSV';

  @override
  String get transfer_export_excelSubtitle =>
      'Toutes les donnees dans un fichier (plongees, sites, equipement, statistiques)';

  @override
  String get transfer_export_excelTitle => 'Classeur Excel';

  @override
  String transfer_export_failed(Object error) {
    return 'Echec de l\'export : $error';
  }

  @override
  String get transfer_export_kmlSubtitle =>
      'Voir les sites de plongee sur un globe 3D';

  @override
  String get transfer_export_kmlTitle => 'Google Earth KML';

  @override
  String get transfer_export_multiFormatHeader => 'Export multi-format';

  @override
  String get transfer_export_optionSaveSubtitle =>
      'Choisissez ou enregistrer sur votre appareil';

  @override
  String get transfer_export_optionSaveTitle => 'Enregistrer dans un fichier';

  @override
  String get transfer_export_optionShareSubtitle =>
      'Envoyer par e-mail, messages ou autres applications';

  @override
  String get transfer_export_optionShareTitle => 'Partager';

  @override
  String get transfer_export_pdfSubtitle => 'Carnet de plongee imprimable';

  @override
  String get transfer_export_pdfTitle => 'Carnet PDF';

  @override
  String get transfer_export_progressExporting => 'Exportation...';

  @override
  String get transfer_export_sectionHeader => 'Exporter les donnees';

  @override
  String get transfer_export_uddfSubtitle => 'Universal Dive Data Format';

  @override
  String get transfer_export_uddfTitle => 'Export UDDF';

  @override
  String get transfer_import_aboutContent =>
      'Utilisez \"Importer des donnees\" pour la meilleure experience -- la detection du format de fichier et de l\'application source est automatique. Les options par format ci-dessous sont egalement disponibles pour un acces direct.';

  @override
  String get transfer_import_aboutTitle => 'A propos de l\'import';

  @override
  String get transfer_import_autoDetectSemanticLabel =>
      'Importer des donnees avec detection automatique';

  @override
  String get transfer_import_autoDetectSubtitle =>
      'Detection automatique CSV, UDDF, FIT, et plus';

  @override
  String get transfer_import_autoDetectTitle => 'Importer des donnees';

  @override
  String get transfer_import_byFormatHeader => 'Importer par format';

  @override
  String get transfer_import_csvSubtitle =>
      'Importer des plongees depuis un fichier CSV';

  @override
  String get transfer_import_csvTitle => 'Importer depuis CSV';

  @override
  String get transfer_import_fitSubtitle =>
      'Importer des plongees depuis des fichiers d\'export Garmin Descent';

  @override
  String get transfer_import_fitTitle => 'Importer depuis un fichier FIT';

  @override
  String get transfer_import_operationCompleted => 'Operation terminee';

  @override
  String transfer_import_operationFailed(Object error) {
    return 'Echec de l\'operation : $error';
  }

  @override
  String get transfer_import_sectionHeader => 'Importer des donnees';

  @override
  String get transfer_import_uddfSubtitle => 'Universal Dive Data Format';

  @override
  String get transfer_import_uddfTitle => 'Importer depuis UDDF';

  @override
  String get transfer_pdfExport_cancelButton => 'Annuler';

  @override
  String get transfer_pdfExport_dialogTitle => 'Exporter le carnet PDF';

  @override
  String get transfer_pdfExport_exportButton => 'Exporter en PDF';

  @override
  String get transfer_pdfExport_includeCertCards =>
      'Inclure les cartes de certification';

  @override
  String get transfer_pdfExport_includeCertCardsSubtitle =>
      'Ajouter les images de cartes de certification scannees au PDF';

  @override
  String get transfer_pdfExport_pageSizeA4 => 'A4';

  @override
  String get transfer_pdfExport_pageSizeA4Desc => '210 x 297 mm';

  @override
  String get transfer_pdfExport_pageSizeHeader => 'Format de page';

  @override
  String get transfer_pdfExport_pageSizeLetter => 'Letter';

  @override
  String get transfer_pdfExport_pageSizeLetterDesc => '8.5 x 11 in';

  @override
  String get transfer_pdfExport_templateDetailed => 'Detaille';

  @override
  String get transfer_pdfExport_templateDetailedDesc =>
      'Informations completes avec notes et evaluations';

  @override
  String get transfer_pdfExport_templateHeader => 'Modele';

  @override
  String get transfer_pdfExport_templateNauiStyle => 'Style NAUI';

  @override
  String get transfer_pdfExport_templateNauiStyleDesc =>
      'Mise en page conforme au format du carnet NAUI';

  @override
  String get transfer_pdfExport_templatePadiStyle => 'Style PADI';

  @override
  String get transfer_pdfExport_templatePadiStyleDesc =>
      'Mise en page conforme au format du carnet PADI';

  @override
  String get transfer_pdfExport_templateProfessional => 'Professionnel';

  @override
  String get transfer_pdfExport_templateProfessionalDesc =>
      'Zones de signature et de tampon pour verification';

  @override
  String transfer_pdfExport_templateSemanticLabel(Object templateName) {
    return 'Selectionner le modele $templateName';
  }

  @override
  String get transfer_pdfExport_templateSimple => 'Simple';

  @override
  String get transfer_pdfExport_templateSimpleDesc =>
      'Format tableau compact, nombreuses plongees par page';

  @override
  String get transfer_section_computersSubtitle =>
      'Telecharger depuis l\'appareil';

  @override
  String get transfer_section_computersTitle => 'Ordinateurs de plongee';

  @override
  String get transfer_section_exportSubtitle => 'CSV, UDDF, carnet PDF';

  @override
  String get transfer_section_exportTitle => 'Exporter';

  @override
  String get transfer_section_importSubtitle => 'Fichiers CSV, UDDF';

  @override
  String get transfer_section_importTitle => 'Importer';

  @override
  String get transfer_summary_description =>
      'Importer et exporter les donnees de plongee';

  @override
  String get transfer_summary_selectSection =>
      'Selectionnez une section dans la liste';

  @override
  String get transfer_summary_title => 'Transfert';

  @override
  String transfer_unknownSection(Object sectionId) {
    return 'Section inconnue : $sectionId';
  }

  @override
  String get trips_appBar_title => 'Voyages';

  @override
  String get trips_appBar_tripPhotos => 'Photos du voyage';

  @override
  String get trips_detail_action_delete => 'Supprimer';

  @override
  String get trips_detail_action_export => 'Exporter';

  @override
  String get trips_detail_appBar_title => 'Voyage';

  @override
  String get trips_detail_dialog_cancel => 'Annuler';

  @override
  String get trips_detail_dialog_deleteConfirm => 'Supprimer';

  @override
  String trips_detail_dialog_deleteContent(Object name) {
    return 'Voulez-vous vraiment supprimer \"$name\" ? Le voyage sera supprime mais les plongees seront conservees.';
  }

  @override
  String get trips_detail_dialog_deleteTitle => 'Supprimer le voyage ?';

  @override
  String get trips_detail_dives_empty =>
      'Aucune plongee dans ce voyage pour le moment';

  @override
  String get trips_detail_dives_errorLoading =>
      'Impossible de charger les plongees';

  @override
  String get trips_detail_dives_unknownSite => 'Site inconnu';

  @override
  String trips_detail_dives_viewAll(Object count) {
    return 'Voir tout ($count)';
  }

  @override
  String trips_detail_durationDays(Object days) {
    return '$days jours';
  }

  @override
  String get trips_detail_export_csv_comingSoon =>
      'Export CSV bientot disponible';

  @override
  String get trips_detail_export_csv_subtitle =>
      'Toutes les plongees de ce voyage';

  @override
  String get trips_detail_export_csv_title => 'Exporter en CSV';

  @override
  String get trips_detail_export_pdf_comingSoon =>
      'Export PDF bientot disponible';

  @override
  String get trips_detail_export_pdf_subtitle =>
      'Resume du voyage avec details des plongees';

  @override
  String get trips_detail_export_pdf_title => 'Exporter en PDF';

  @override
  String get trips_detail_label_liveaboard => 'Croisiere';

  @override
  String get trips_detail_label_location => 'Lieu';

  @override
  String get trips_detail_label_resort => 'Resort';

  @override
  String get trips_detail_scan_accessDenied => 'Acces a la phothotheque refuse';

  @override
  String get trips_detail_scan_addDivesFirst =>
      'Ajoutez d\'abord des plongees pour associer des photos';

  @override
  String trips_detail_scan_errorLinking(Object error) {
    return 'Erreur lors de l\'association des photos : $error';
  }

  @override
  String trips_detail_scan_errorScanning(Object error) {
    return 'Erreur lors du scan : $error';
  }

  @override
  String trips_detail_scan_linkedPhotos(Object count) {
    return '$count photos associees';
  }

  @override
  String get trips_detail_scan_linkingPhotos => 'Association des photos...';

  @override
  String get trips_detail_sectionTitle_details => 'Details du voyage';

  @override
  String get trips_detail_sectionTitle_dives => 'Plongees';

  @override
  String get trips_detail_sectionTitle_notes => 'Notes';

  @override
  String get trips_detail_sectionTitle_statistics => 'Statistiques du voyage';

  @override
  String get trips_detail_snackBar_deleted => 'Voyage supprime';

  @override
  String get trips_detail_stat_avgDepth => 'Profondeur moy.';

  @override
  String get trips_detail_stat_maxDepth => 'Profondeur max.';

  @override
  String get trips_detail_stat_totalBottomTime => 'Temps au fond total';

  @override
  String get trips_detail_stat_totalDives => 'Total des plongees';

  @override
  String get trips_detail_tooltip_edit => 'Modifier le voyage';

  @override
  String get trips_detail_tooltip_editShort => 'Modifier';

  @override
  String get trips_detail_tooltip_moreOptions => 'Plus d\'options';

  @override
  String get trips_detail_tooltip_viewOnMap => 'Voir sur la carte';

  @override
  String get trips_edit_appBar_add => 'Ajouter un voyage';

  @override
  String get trips_edit_appBar_edit => 'Modifier le voyage';

  @override
  String get trips_edit_button_add => 'Ajouter un voyage';

  @override
  String get trips_edit_button_cancel => 'Annuler';

  @override
  String get trips_edit_button_save => 'Enregistrer';

  @override
  String get trips_edit_button_update => 'Mettre a jour le voyage';

  @override
  String get trips_edit_dialog_discard => 'Abandonner';

  @override
  String get trips_edit_dialog_discardContent =>
      'Tu as des modifications non enregistrees. Veux-tu vraiment quitter ?';

  @override
  String get trips_edit_dialog_discardTitle => 'Abandonner les modifications ?';

  @override
  String get trips_edit_dialog_keepEditing => 'Continuer a modifier';

  @override
  String trips_edit_durationDays(Object days) {
    return '$days jours';
  }

  @override
  String get trips_edit_hint_liveaboardName => 'ex. MY Blue Force One';

  @override
  String get trips_edit_hint_location => 'ex. Egypte, Mer Rouge';

  @override
  String get trips_edit_hint_notes => 'Notes supplementaires sur ce voyage';

  @override
  String get trips_edit_hint_resortName => 'ex. Marsa Shagra';

  @override
  String get trips_edit_hint_tripName => 'ex. Safari Mer Rouge 2024';

  @override
  String get trips_edit_label_endDate => 'Date de fin';

  @override
  String get trips_edit_label_liveaboardName => 'Nom de la croisiere';

  @override
  String get trips_edit_label_location => 'Lieu';

  @override
  String get trips_edit_label_notes => 'Notes';

  @override
  String get trips_edit_label_resortName => 'Nom du resort';

  @override
  String get trips_edit_label_startDate => 'Date de debut';

  @override
  String get trips_edit_label_tripName => 'Nom du voyage *';

  @override
  String get trips_edit_sectionTitle_dates => 'Dates du voyage';

  @override
  String get trips_edit_sectionTitle_location => 'Lieu';

  @override
  String get trips_edit_sectionTitle_notes => 'Notes';

  @override
  String get trips_edit_semanticLabel_save => 'Enregistrer le voyage';

  @override
  String get trips_edit_snackBar_added => 'Voyage ajoute avec succes';

  @override
  String trips_edit_snackBar_errorLoading(Object error) {
    return 'Erreur lors du chargement du voyage : $error';
  }

  @override
  String trips_edit_snackBar_errorSaving(Object error) {
    return 'Erreur lors de l\'enregistrement du voyage : $error';
  }

  @override
  String get trips_edit_snackBar_updated => 'Voyage mis a jour avec succes';

  @override
  String get trips_edit_validation_nameRequired =>
      'Veuillez entrer un nom de voyage';

  @override
  String get trips_gallery_accessDenied => 'Acces a la phototheque refuse';

  @override
  String get trips_gallery_addDivesFirst =>
      'Ajoutez d\'abord des plongees pour associer des photos';

  @override
  String get trips_gallery_appBar_title => 'Photos du voyage';

  @override
  String trips_gallery_diveSection_photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'photos',
      one: 'photo',
    );
    return '$_temp0';
  }

  @override
  String trips_gallery_diveSection_title(Object number, Object site) {
    return 'Plongee n$number - $site';
  }

  @override
  String get trips_gallery_empty_subtitle =>
      'Appuie sur l\'icone appareil photo pour scanner ta galerie';

  @override
  String get trips_gallery_empty_title => 'Aucune photo dans ce voyage';

  @override
  String trips_gallery_errorLinking(Object error) {
    return 'Erreur lors de l\'association des photos : $error';
  }

  @override
  String trips_gallery_errorScanning(Object error) {
    return 'Erreur lors du scan : $error';
  }

  @override
  String trips_gallery_error_loading(Object error) {
    return 'Erreur lors du chargement des photos : $error';
  }

  @override
  String trips_gallery_linkedPhotos(Object count) {
    return '$count photos associees';
  }

  @override
  String get trips_gallery_linkingPhotos => 'Association des photos...';

  @override
  String get trips_gallery_tooltip_scan => 'Scanner la galerie de l\'appareil';

  @override
  String get trips_gallery_tripNotFound => 'Voyage introuvable';

  @override
  String get trips_list_button_retry => 'Reessayer';

  @override
  String get trips_list_empty_button => 'Ajouter votre premier voyage';

  @override
  String get trips_list_empty_filtered_subtitle =>
      'Essayez d\'ajuster ou de reinitialiser vos filtres';

  @override
  String get trips_list_empty_filtered_title =>
      'Aucun voyage ne correspond a vos filtres';

  @override
  String get trips_list_empty_subtitle =>
      'Creez des voyages pour regrouper vos plongees par destination';

  @override
  String get trips_list_empty_title => 'Aucun voyage ajoute';

  @override
  String trips_list_error_loading(Object error) {
    return 'Erreur lors du chargement des voyages : $error';
  }

  @override
  String get trips_list_fab_addTrip => 'Ajouter un voyage';

  @override
  String get trips_list_filters_clearAll => 'Tout effacer';

  @override
  String get trips_list_sort_title => 'Trier les voyages';

  @override
  String trips_list_tile_diveCount(Object count) {
    return '$count plongees';
  }

  @override
  String get trips_list_tooltip_addTrip => 'Ajouter un voyage';

  @override
  String get trips_list_tooltip_search => 'Rechercher des voyages';

  @override
  String get trips_list_tooltip_sort => 'Trier';

  @override
  String get trips_photos_empty_scanButton =>
      'Scanner la galerie de l\'appareil';

  @override
  String get trips_photos_empty_title => 'Aucune photo';

  @override
  String get trips_photos_error_loading =>
      'Erreur lors du chargement des photos';

  @override
  String trips_photos_moreIndicator(Object count) {
    return '+$count';
  }

  @override
  String trips_photos_moreIndicator_semanticLabel(Object count) {
    return '$count photos supplementaires';
  }

  @override
  String get trips_photos_sectionTitle => 'Photos';

  @override
  String get trips_photos_tooltip_scan => 'Scanner la galerie de l\'appareil';

  @override
  String get trips_photos_viewAll => 'Voir tout';

  @override
  String get trips_picker_clearTooltip => 'Effacer la selection';

  @override
  String get trips_picker_empty_createButton => 'Creer un voyage';

  @override
  String get trips_picker_empty_title => 'Aucun voyage';

  @override
  String trips_picker_error(Object error) {
    return 'Erreur lors du chargement des voyages : $error';
  }

  @override
  String get trips_picker_hint => 'Appuie pour selectionner un voyage';

  @override
  String get trips_picker_newTrip => 'Nouveau voyage';

  @override
  String get trips_picker_noSelection => 'Aucun voyage selectionne';

  @override
  String get trips_picker_sheetTitle => 'Selectionner un voyage';

  @override
  String trips_picker_suggestedPrefix(Object name) {
    return 'Suggere : $name';
  }

  @override
  String get trips_picker_suggestedUse => 'Utiliser';

  @override
  String get trips_search_empty_hint => 'Rechercher par nom, lieu ou resort';

  @override
  String get trips_search_fieldLabel => 'Rechercher des voyages...';

  @override
  String trips_search_noResults(Object query) {
    return 'Aucun voyage trouve pour \"$query\"';
  }

  @override
  String get trips_search_tooltip_back => 'Retour';

  @override
  String get trips_search_tooltip_clear => 'Effacer la recherche';

  @override
  String get trips_summary_header_subtitle =>
      'Selectionnez un voyage dans la liste pour voir les details';

  @override
  String get trips_summary_header_title => 'Voyages';

  @override
  String get trips_summary_overview_title => 'Apercu';

  @override
  String get trips_summary_quickActions_add => 'Ajouter un voyage';

  @override
  String get trips_summary_quickActions_title => 'Actions rapides';

  @override
  String trips_summary_recentSubtitle(Object date, Object count) {
    return '$date - $count plongees';
  }

  @override
  String get trips_summary_recentTitle => 'Voyages recents';

  @override
  String get trips_summary_stat_daysDiving => 'Jours de plongee';

  @override
  String get trips_summary_stat_liveaboards => 'Croisieres';

  @override
  String get trips_summary_stat_totalDives => 'Total des plongees';

  @override
  String get trips_summary_stat_totalTrips => 'Total des voyages';

  @override
  String trips_summary_upcomingSubtitle(Object date, Object days) {
    return '$date - Dans $days jours';
  }

  @override
  String get trips_summary_upcomingTitle => 'A venir';

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
  String get units_sac_pressurePerMin => 'pression/min';

  @override
  String get units_temperature_celsius => 'C';

  @override
  String get units_temperature_fahrenheit => 'F';

  @override
  String get units_timeFormat_twelveHour => '12 heures';

  @override
  String get units_timeFormat_twentyFourHour => '24 heures';

  @override
  String get units_volume_cubicFeet => 'cuft';

  @override
  String get units_volume_liters => 'L';

  @override
  String get units_weight_kilograms => 'kg';

  @override
  String get units_weight_pounds => 'lbs';

  @override
  String get universalImport_action_continue => 'Continuer';

  @override
  String get universalImport_action_deselectAll => 'Tout désélectionner';

  @override
  String get universalImport_action_done => 'Terminé';

  @override
  String get universalImport_action_import => 'Importer';

  @override
  String get universalImport_action_selectAll => 'Tout sélectionner';

  @override
  String get universalImport_action_selectFile => 'Sélectionner un fichier';

  @override
  String get universalImport_description_supportedFormats =>
      'Sélectionnez un fichier de carnet de plongée à importer. Les formats pris en charge incluent CSV, UDDF, Subsurface XML et Garmin FIT.';

  @override
  String get universalImport_error_unsupportedFormat =>
      'Ce format n\'est pas encore pris en charge. Veuillez exporter en UDDF ou CSV.';

  @override
  String get universalImport_hint_tagDescription =>
      'Étiquetez toutes les plongées importées pour un filtrage facile';

  @override
  String get universalImport_hint_tagExample => 'ex. Import MacDive 2026-02-09';

  @override
  String get universalImport_label_columnMapping => 'Mappage des colonnes';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped sur $total colonnes mappées';
  }

  @override
  String get universalImport_label_detecting => 'Détection...';

  @override
  String universalImport_label_diveNumber(Object number) {
    return 'Plongée n°$number';
  }

  @override
  String get universalImport_label_duplicate => 'Doublon';

  @override
  String universalImport_label_duplicatesFound(Object count) {
    return '$count doublons trouvés et désélectionnés automatiquement.';
  }

  @override
  String get universalImport_label_importComplete => 'Import terminé';

  @override
  String get universalImport_label_importTag => 'Étiquette d\'import';

  @override
  String get universalImport_label_importing => 'Import';

  @override
  String get universalImport_label_importingEllipsis => 'Import...';

  @override
  String universalImport_label_importingProgress(Object current, Object total) {
    return 'Import de $current sur $total';
  }

  @override
  String universalImport_label_percentMatch(Object percent) {
    return '$percent% de correspondance';
  }

  @override
  String get universalImport_label_possibleMatch => 'Correspondance possible';

  @override
  String get universalImport_label_selectCorrectSource =>
      'Pas correct ? Sélectionnez la bonne source :';

  @override
  String universalImport_label_selected(Object count) {
    return '$count sélectionné';
  }

  @override
  String get universalImport_label_skip => 'Ignorer';

  @override
  String universalImport_label_taggedAs(Object tag) {
    return 'Étiqueté comme : $tag';
  }

  @override
  String get universalImport_label_unknownDate => 'Date inconnue';

  @override
  String get universalImport_label_unnamed => 'Sans nom';

  @override
  String universalImport_label_xOfY(Object current, Object total) {
    return '$current sur $total';
  }

  @override
  String universalImport_label_xOfYSelected(Object selected, Object total) {
    return '$selected sur $total sélectionné';
  }

  @override
  String universalImport_semantics_entitySelection(
    Object selected,
    Object total,
    Object entityType,
  ) {
    return '$selected sur $total $entityType sélectionné';
  }

  @override
  String universalImport_semantics_importError(Object error) {
    return 'Erreur d\'import : $error';
  }

  @override
  String universalImport_semantics_importProgress(Object percent) {
    return 'Progression de l\'import : $percent pour cent';
  }

  @override
  String universalImport_semantics_itemsSelected(Object count) {
    return '$count éléments sélectionnés pour l\'import';
  }

  @override
  String get universalImport_semantics_possibleDuplicate => 'Doublon possible';

  @override
  String get universalImport_semantics_probableDuplicate => 'Doublon probable';

  @override
  String universalImport_semantics_sourceDetected(Object description) {
    return 'Source détectée : $description';
  }

  @override
  String universalImport_semantics_sourceUncertain(Object description) {
    return 'Source incertaine : $description';
  }

  @override
  String universalImport_semantics_toggleSelection(Object name) {
    return 'Basculer la sélection pour $name';
  }

  @override
  String get universalImport_step_import => 'Importer';

  @override
  String get universalImport_step_map => 'Mapper';

  @override
  String get universalImport_step_review => 'Vérifier';

  @override
  String get universalImport_step_select => 'Sélectionner';

  @override
  String get universalImport_title => 'Importer des données';

  @override
  String get universalImport_tooltip_clearTag => 'Effacer l\'étiquette';

  @override
  String get universalImport_tooltip_closeWizard =>
      'Fermer l\'assistant d\'import';

  @override
  String weightCalc_baseLine(Object suitType, Object weight) {
    return 'Base ($suitType) : $weight kg';
  }

  @override
  String weightCalc_bodyWeightAdjustment(Object adjustment) {
    return 'Ajustement poids corporel : +$adjustment kg';
  }

  @override
  String get weightCalc_suit_drysuit => 'Combinaison etanche';

  @override
  String get weightCalc_suit_none => 'Sans combinaison';

  @override
  String get weightCalc_suit_rashguard => 'Lycra uniquement';

  @override
  String get weightCalc_suit_semidry => 'Combinaison semi-etanche';

  @override
  String get weightCalc_suit_shorty3mm => 'Shorty 3mm';

  @override
  String get weightCalc_suit_wetsuit3mm => 'Combinaison 3mm integrale';

  @override
  String get weightCalc_suit_wetsuit5mm => 'Combinaison 5mm';

  @override
  String get weightCalc_suit_wetsuit7mm => 'Combinaison 7mm';

  @override
  String weightCalc_tankLine(Object tankMaterial, Object adjustment) {
    return 'Bloc ($tankMaterial) : $adjustment kg';
  }

  @override
  String get weightCalc_title => 'Calcul du lestage :';

  @override
  String weightCalc_total(Object total) {
    return 'Total : $total kg';
  }

  @override
  String weightCalc_waterLine(Object waterType, Object adjustment) {
    return 'Eau ($waterType) : $adjustment kg';
  }

  @override
  String divePlanner_label_resultsWithWarnings(Object count) {
    return 'Résultats, $count avertissements';
  }

  @override
  String tides_semantic_tideCycle(Object state, Object height) {
    return 'Cycle de marée, état : $state, hauteur : $height';
  }

  @override
  String get tides_label_agoSuffix => 'il y a';

  @override
  String get tides_label_fromNowSuffix => 'à partir de maintenant';

  @override
  String get certifications_card_issued => 'DELIVREE';

  @override
  String certifications_certificate_cardNumber(Object number) {
    return 'Numero de carte : $number';
  }

  @override
  String get certifications_certificate_footer =>
      'Certification officielle de plongee sous-marine';

  @override
  String get certifications_certificate_hasCompletedTraining =>
      'a termine la formation en tant que';

  @override
  String certifications_certificate_instructor(Object name) {
    return 'Instructeur : $name';
  }

  @override
  String certifications_certificate_issued(Object date) {
    return 'Delivree le : $date';
  }

  @override
  String get certifications_certificate_thisCertifies => 'Ceci certifie que';

  @override
  String get diveComputer_discovery_chooseDifferentDevice =>
      'Choisir un autre appareil';

  @override
  String get diveComputer_discovery_computer => 'Ordinateur';

  @override
  String get diveComputer_discovery_connectAndDownload =>
      'Connecter et telecharger';

  @override
  String get diveComputer_discovery_connectingToDevice =>
      'Connexion a l\'appareil...';

  @override
  String diveComputer_discovery_deviceNameHint(Object model) {
    return 'ex. Mon $model';
  }

  @override
  String get diveComputer_discovery_deviceNameLabel => 'Nom de l\'appareil';

  @override
  String get diveComputer_discovery_exitDialogCancel => 'Annuler';

  @override
  String get diveComputer_discovery_exitDialogConfirm => 'Quitter';

  @override
  String get diveComputer_discovery_exitDialogContent =>
      'Voulez-vous vraiment quitter ? Votre progression sera perdue.';

  @override
  String get diveComputer_discovery_exitDialogTitle =>
      'Quitter la configuration ?';

  @override
  String get diveComputer_discovery_exitTooltip => 'Quitter la configuration';

  @override
  String get diveComputer_discovery_noDeviceSelected =>
      'Aucun appareil selectionne';

  @override
  String get diveComputer_discovery_pleaseWaitConnection =>
      'Veuillez patienter pendant l\'etablissement de la connexion';

  @override
  String get diveComputer_discovery_recognizedDevice => 'Appareil reconnu';

  @override
  String get diveComputer_discovery_recognizedDeviceDescription =>
      'Cet appareil fait partie de notre bibliotheque d\'appareils compatibles. Le telechargement des plongees devrait fonctionner automatiquement.';

  @override
  String get diveComputer_discovery_stepConnect => 'Connecter';

  @override
  String get diveComputer_discovery_stepDone => 'Termine';

  @override
  String get diveComputer_discovery_stepDownload => 'Telecharger';

  @override
  String get diveComputer_discovery_stepScan => 'Rechercher';

  @override
  String get diveComputer_discovery_titleComplete => 'Termine';

  @override
  String get diveComputer_discovery_titleConfirmDevice =>
      'Confirmer l\'appareil';

  @override
  String get diveComputer_discovery_titleConnecting => 'Connexion';

  @override
  String get diveComputer_discovery_titleDownloading => 'Telechargement';

  @override
  String get diveComputer_discovery_titleFindDevice => 'Rechercher un appareil';

  @override
  String get diveComputer_discovery_unknownDevice => 'Appareil inconnu';

  @override
  String get diveComputer_discovery_unknownDeviceDescription =>
      'Cet appareil n\'est pas dans notre bibliotheque. Nous tenterons de nous connecter, mais le telechargement pourrait ne pas fonctionner.';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... et $count de plus';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'Annuler';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadFailed =>
      'Echec du telechargement';

  @override
  String get diveComputer_downloadStep_downloadedDives =>
      'Plongees telechargees';

  @override
  String diveComputer_downloadStep_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_downloadStep_errorOccurred =>
      'Une erreur est survenue';

  @override
  String diveComputer_downloadStep_errorSemanticLabel(Object error) {
    return 'Erreur de telechargement : $error';
  }

  @override
  String diveComputer_downloadStep_percentAccessibility(Object percent) {
    return ', $percent pour cent';
  }

  @override
  String get diveComputer_downloadStep_preparing => 'Preparation...';

  @override
  String diveComputer_downloadStep_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String diveComputer_downloadStep_progressSemanticLabel(
    Object status,
    Object percent,
  ) {
    return 'Progression du telechargement : $status$percent';
  }

  @override
  String get diveComputer_downloadStep_retry => 'Reessayer';

  @override
  String get diveComputer_download_cancel => 'Annuler';

  @override
  String get diveComputer_download_closeTooltip => 'Fermer';

  @override
  String get diveComputer_download_computerNotFound => 'Ordinateur introuvable';

  @override
  String diveComputer_download_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String diveComputer_download_deviceNotFoundError(Object name) {
    return 'Appareil introuvable. Assurez-vous que votre $name est a proximite et en mode transfert.';
  }

  @override
  String get diveComputer_download_deviceNotFoundTitle =>
      'Appareil introuvable';

  @override
  String get diveComputer_download_divesUpdated => 'Plongees mises a jour';

  @override
  String get diveComputer_download_done => 'Termine';

  @override
  String get diveComputer_download_downloadedDives => 'Plongees telechargees';

  @override
  String get diveComputer_download_duplicatesSkipped => 'Doublons ignores';

  @override
  String diveComputer_download_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_download_errorOccurred => 'Une erreur est survenue';

  @override
  String diveComputer_download_errorWithMessage(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get diveComputer_download_goBack => 'Retour';

  @override
  String get diveComputer_download_importFailed => 'Echec de l\'import';

  @override
  String get diveComputer_download_importResults => 'Resultats de l\'import';

  @override
  String get diveComputer_download_importedDives => 'Plongees importees';

  @override
  String get diveComputer_download_newDivesImported =>
      'Nouvelles plongees importees';

  @override
  String get diveComputer_download_preparing => 'Preparation...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_retry => 'Reessayer';

  @override
  String diveComputer_download_scanError(Object error) {
    return 'Erreur de recherche : $error';
  }

  @override
  String diveComputer_download_searchingForDevice(Object name) {
    return 'Recherche de $name...';
  }

  @override
  String get diveComputer_download_searchingInstructions =>
      'Assurez-vous que l\'appareil est a proximite et en mode transfert';

  @override
  String get diveComputer_download_title => 'Telecharger les plongees';

  @override
  String get diveComputer_download_tryAgain => 'Reessayer';

  @override
  String get diveComputer_list_addComputer => 'Ajouter un ordinateur';

  @override
  String diveComputer_list_cardSemanticLabel(Object name) {
    return 'Ordinateur de plongee : $name';
  }

  @override
  String diveComputer_list_diveCount(Object count) {
    return '$count plongees';
  }

  @override
  String get diveComputer_list_downloadTooltip => 'Telecharger les plongees';

  @override
  String get diveComputer_list_emptyMessage =>
      'Connectez votre ordinateur de plongee pour telecharger vos plongees directement dans l\'application.';

  @override
  String get diveComputer_list_emptyTitle => 'Aucun ordinateur de plongee';

  @override
  String get diveComputer_list_findComputers => 'Rechercher des ordinateurs';

  @override
  String get diveComputer_list_helpBluetooth =>
      '- Bluetooth LE (ordinateurs modernes)';

  @override
  String get diveComputer_list_helpBluetoothClassic =>
      '- Bluetooth Classic (anciens modeles)';

  @override
  String get diveComputer_list_helpBrandsList =>
      'Shearwater, Suunto, Garmin, Mares, Scubapro, Oceanic, Aqualung, Cressi, et plus de 50 autres modeles.';

  @override
  String get diveComputer_list_helpBrandsTitle => 'Marques compatibles';

  @override
  String get diveComputer_list_helpConnectionsTitle => 'Connexions compatibles';

  @override
  String get diveComputer_list_helpDialogTitle => 'Aide ordinateur de plongee';

  @override
  String get diveComputer_list_helpDismiss => 'Compris';

  @override
  String get diveComputer_list_helpTip1 =>
      '- Assurez-vous que votre ordinateur est en mode transfert';

  @override
  String get diveComputer_list_helpTip2 =>
      '- Gardez les appareils proches pendant le telechargement';

  @override
  String get diveComputer_list_helpTip3 =>
      '- Verifiez que le Bluetooth est active';

  @override
  String get diveComputer_list_helpTipsTitle => 'Conseils';

  @override
  String get diveComputer_list_helpTooltip => 'Aide';

  @override
  String get diveComputer_list_helpUsb =>
      '- USB (ordinateur de bureau uniquement)';

  @override
  String get diveComputer_list_loadFailed =>
      'Echec du chargement des ordinateurs de plongee';

  @override
  String get diveComputer_list_retry => 'Reessayer';

  @override
  String get diveComputer_list_title => 'Ordinateurs de plongee';

  @override
  String get diveComputer_summary_diveComputer => 'ordinateur de plongee';

  @override
  String diveComputer_summary_divesDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongees telechargees',
      one: 'plongee telechargee',
    );
    return '$count $_temp0';
  }

  @override
  String get diveComputer_summary_done => 'Termine';

  @override
  String get diveComputer_summary_imported => 'Importees';

  @override
  String diveComputer_summary_semanticLabel(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongees telechargees',
      one: 'plongee telechargee',
    );
    return '$count $_temp0 depuis $name';
  }

  @override
  String get diveComputer_summary_skippedDuplicates => 'Ignores (doublons)';

  @override
  String get diveComputer_summary_title => 'Telechargement termine !';

  @override
  String get diveComputer_summary_updated => 'Mises a jour';

  @override
  String get diveComputer_summary_viewDives => 'Voir les plongees';

  @override
  String get diveImport_alreadyImported => 'Deja importee';

  @override
  String get diveImport_avgHR => 'FC moy.';

  @override
  String get diveImport_back => 'Retour';

  @override
  String get diveImport_deselectAll => 'Tout deselectionner';

  @override
  String get diveImport_divesImported => 'Plongees importees';

  @override
  String get diveImport_divesMerged => 'Plongees fusionnees';

  @override
  String get diveImport_divesSkipped => 'Plongees ignorees';

  @override
  String get diveImport_done => 'Termine';

  @override
  String get diveImport_duration => 'Duree';

  @override
  String get diveImport_error => 'Erreur';

  @override
  String get diveImport_fit_closeTooltip => 'Fermer l\'import FIT';

  @override
  String get diveImport_fit_noDivesDescription =>
      'Selectionnez un ou plusieurs fichiers .fit exportes depuis Garmin Connect ou copies depuis un appareil Garmin Descent.';

  @override
  String get diveImport_fit_noDivesLoaded => 'Aucune plongee chargee';

  @override
  String diveImport_fit_parsed(int diveCount, int fileCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'plongees analysees',
      one: 'plongee analysee',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'fichiers',
      one: 'fichier',
    );
    return '$diveCount $_temp0 depuis $fileCount $_temp1';
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
      other: 'plongees analysees',
      one: 'plongee analysee',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'fichiers',
      one: 'fichier',
    );
    return '$diveCount $_temp0 depuis $fileCount $_temp1 ($skippedCount ignorees)';
  }

  @override
  String get diveImport_fit_parsing => 'Analyse...';

  @override
  String get diveImport_fit_selectFiles => 'Selectionner les fichiers FIT';

  @override
  String get diveImport_fit_title => 'Import depuis un fichier FIT';

  @override
  String get diveImport_healthkit_accessDescription =>
      'Submersion a besoin d\'acceder aux donnees de plongee de votre Apple Watch pour importer les plongees.';

  @override
  String get diveImport_healthkit_accessRequired => 'Acces HealthKit requis';

  @override
  String get diveImport_healthkit_closeTooltip =>
      'Fermer l\'import Apple Watch';

  @override
  String get diveImport_healthkit_dateFrom => 'Du';

  @override
  String diveImport_healthkit_dateSelectorLabel(Object label) {
    return 'Selecteur de date $label';
  }

  @override
  String get diveImport_healthkit_dateTo => 'Au';

  @override
  String get diveImport_healthkit_fetchDives => 'Recuperer les plongees';

  @override
  String get diveImport_healthkit_fetching => 'Recuperation...';

  @override
  String get diveImport_healthkit_grantAccess => 'Autoriser l\'acces';

  @override
  String get diveImport_healthkit_noDivesFound => 'Aucune plongee trouvee';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'Aucune activite de plongee sous-marine trouvee dans la periode selectionnee.';

  @override
  String get diveImport_healthkit_notAvailable => 'Non disponible';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'L\'import depuis l\'Apple Watch est disponible uniquement sur les appareils iOS et macOS.';

  @override
  String get diveImport_healthkit_permissionCheckFailed =>
      'Echec de la verification des autorisations';

  @override
  String get diveImport_healthkit_title => 'Import depuis l\'Apple Watch';

  @override
  String get diveImport_healthkit_watchTitle => 'Import depuis la montre';

  @override
  String get diveImport_import => 'Importer';

  @override
  String get diveImport_importComplete => 'Import termine';

  @override
  String get diveImport_likelyDuplicate => 'Doublon probable';

  @override
  String get diveImport_maxDepth => 'Prof. max';

  @override
  String get diveImport_newDive => 'Nouvelle plongee';

  @override
  String get diveImport_next => 'Suivant';

  @override
  String get diveImport_possibleDuplicate => 'Doublon possible';

  @override
  String get diveImport_reviewSelectedDives =>
      'Verifier les plongees selectionnees';

  @override
  String diveImport_reviewSummary(
    Object newCount,
    int possibleCount,
    int skipCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      possibleCount,
      locale: localeName,
      other: ', $possibleCount doublons possibles',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipCount,
      locale: localeName,
      other: ', $skipCount seront ignorees',
      zero: '',
    );
    return '$newCount nouvelles$_temp0$_temp1';
  }

  @override
  String get diveImport_selectAll => 'Tout selectionner';

  @override
  String diveImport_selectedCount(Object count) {
    return '$count selectionnees';
  }

  @override
  String get diveImport_sourceGarmin => 'Garmin';

  @override
  String get diveImport_sourceSuunto => 'Suunto';

  @override
  String get diveImport_sourceUDDF => 'UDDF';

  @override
  String get diveImport_sourceWatch => 'Montre';

  @override
  String get diveImport_step_done => 'Termine';

  @override
  String get diveImport_step_review => 'Verifier';

  @override
  String get diveImport_step_select => 'Selectionner';

  @override
  String get diveImport_temp => 'Temp';

  @override
  String get diveImport_toggleDiveSelection =>
      'Basculer la selection de la plongee';

  @override
  String get diveImport_uddf_buddies => 'Binomes';

  @override
  String get diveImport_uddf_certifications => 'Certifications';

  @override
  String get diveImport_uddf_closeTooltip => 'Fermer l\'import UDDF';

  @override
  String get diveImport_uddf_diveCenters => 'Centres de plongee';

  @override
  String get diveImport_uddf_diveTypes => 'Types de plongee';

  @override
  String get diveImport_uddf_dives => 'Plongees';

  @override
  String get diveImport_uddf_duplicate => 'Doublon';

  @override
  String diveImport_uddf_duplicatesFound(Object count) {
    return '$count doublons trouves et deselectionnes automatiquement.';
  }

  @override
  String get diveImport_uddf_equipment => 'Equipement';

  @override
  String get diveImport_uddf_equipmentSets => 'Kits d\'equipement';

  @override
  String diveImport_uddf_importProgress(Object current, Object total) {
    return '$current sur $total';
  }

  @override
  String get diveImport_uddf_importing => 'Import en cours...';

  @override
  String get diveImport_uddf_likelyDuplicate => 'Doublon probable';

  @override
  String get diveImport_uddf_noFileDescription =>
      'Selectionnez un fichier .uddf ou .xml exporte depuis une autre application de carnet de plongee.';

  @override
  String get diveImport_uddf_noFileSelected => 'Aucun fichier selectionne';

  @override
  String get diveImport_uddf_parsing => 'Analyse...';

  @override
  String get diveImport_uddf_possibleDuplicate => 'Doublon possible';

  @override
  String get diveImport_uddf_selectFile => 'Selectionner un fichier UDDF';

  @override
  String diveImport_uddf_selectedOfTotal(Object selected, Object total) {
    return '$selected sur $total selectionnes';
  }

  @override
  String get diveImport_uddf_sites => 'Sites';

  @override
  String get diveImport_uddf_stepImport => 'Importer';

  @override
  String get diveImport_uddf_tabBuddies => 'Binomes';

  @override
  String get diveImport_uddf_tabCenters => 'Centres';

  @override
  String get diveImport_uddf_tabCerts => 'Certifs';

  @override
  String get diveImport_uddf_tabCourses => 'Cours';

  @override
  String get diveImport_uddf_tabDives => 'Plongees';

  @override
  String get diveImport_uddf_tabEquipment => 'Equipement';

  @override
  String get diveImport_uddf_tabSets => 'Kits';

  @override
  String get diveImport_uddf_tabSites => 'Sites';

  @override
  String get diveImport_uddf_tabTags => 'Tags';

  @override
  String get diveImport_uddf_tabTrips => 'Voyages';

  @override
  String get diveImport_uddf_tabTypes => 'Types';

  @override
  String get diveImport_uddf_tags => 'Tags';

  @override
  String get diveImport_uddf_title => 'Import depuis UDDF';

  @override
  String get diveImport_uddf_toggleDiveSelection =>
      'Basculer la selection de la plongee';

  @override
  String diveImport_uddf_toggleEntitySelection(Object name) {
    return 'Basculer la selection de $name';
  }

  @override
  String get diveImport_uddf_trips => 'Voyages';

  @override
  String get divePlanner_segmentEditor_addTitle => 'Ajouter un segment';

  @override
  String divePlanner_segmentEditor_ascentRate(Object unit) {
    return 'Vitesse de remontee ($unit/min)';
  }

  @override
  String divePlanner_segmentEditor_descentRate(Object unit) {
    return 'Vitesse de descente ($unit/min)';
  }

  @override
  String get divePlanner_segmentEditor_duration => 'Duree (min)';

  @override
  String get divePlanner_segmentEditor_editTitle => 'Modifier le segment';

  @override
  String divePlanner_segmentEditor_endDepth(Object unit) {
    return 'Profondeur finale ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_gasSwitchTime =>
      'Temps de changement de gaz';

  @override
  String get divePlanner_segmentEditor_segmentType => 'Type de segment';

  @override
  String divePlanner_segmentEditor_startDepth(Object unit) {
    return 'Profondeur initiale ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_tankGas => 'Bloc / Gaz';

  @override
  String get divePlanner_segmentList_addSegment => 'Ajouter un segment';

  @override
  String divePlanner_segmentList_ascent(Object startDepth, Object endDepth) {
    return 'Remontee $startDepth -> $endDepth';
  }

  @override
  String divePlanner_segmentList_bottom(Object depth, Object minutes) {
    return 'Fond $depth pendant $minutes min';
  }

  @override
  String divePlanner_segmentList_deco(Object depth, Object minutes) {
    return 'Deco $depth pendant $minutes min';
  }

  @override
  String get divePlanner_segmentList_deleteSegment => 'Supprimer le segment';

  @override
  String divePlanner_segmentList_descent(Object startDepth, Object endDepth) {
    return 'Descente $startDepth -> $endDepth';
  }

  @override
  String get divePlanner_segmentList_editSegment => 'Modifier le segment';

  @override
  String get divePlanner_segmentList_emptyMessage =>
      'Ajoutez des segments manuellement ou creez un plan rapide';

  @override
  String get divePlanner_segmentList_emptyTitle => 'Aucun segment';

  @override
  String divePlanner_segmentList_gasSwitch(Object gasName) {
    return 'Changement de gaz vers $gasName';
  }

  @override
  String get divePlanner_segmentList_quickPlan => 'Plan rapide';

  @override
  String divePlanner_segmentList_safetyStop(Object depth, Object minutes) {
    return 'Palier de securite $depth pendant $minutes min';
  }

  @override
  String get divePlanner_segmentList_title => 'Segments de plongee';

  @override
  String get divePlanner_segmentType_ascent => 'Remontee';

  @override
  String get divePlanner_segmentType_bottomTime => 'Temps au fond';

  @override
  String get divePlanner_segmentType_decoStop => 'Palier de deco';

  @override
  String get divePlanner_segmentType_descent => 'Descente';

  @override
  String get divePlanner_segmentType_gasSwitch => 'Changement de gaz';

  @override
  String get divePlanner_segmentType_safetyStop => 'Palier de securite';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'Le rock bottom est la reserve de gaz minimale pour une remontee d\'urgence en partageant l\'air avec votre binome.\n\n- Utilise des consommations majorees (2-3x la normale)\n- Suppose les deux plongeurs sur un seul bloc\n- Inclut le palier de securite si active\n\nFaites toujours demi-tour AVANT d\'atteindre le rock bottom !';

  @override
  String get gasCalculators_rockBottom_aboutTitle => 'A propos du Rock Bottom';

  @override
  String get gasCalculators_rockBottom_ascentGasRequired =>
      'Gaz necessaire pour la remontee';

  @override
  String get gasCalculators_rockBottom_ascentRate => 'Vitesse de remontee';

  @override
  String gasCalculators_rockBottom_ascentTimeToDepth(
    Object depth,
    Object unit,
  ) {
    return 'Temps de remontee jusqu\'a $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_ascentTimeToSurface =>
      'Temps de remontee jusqu\'a la surface';

  @override
  String get gasCalculators_rockBottom_buddySac => 'SAC du binome';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'SAC majoree combinee';

  @override
  String get gasCalculators_rockBottom_emergencyAscentBreakdown =>
      'Detail de la remontee d\'urgence';

  @override
  String get gasCalculators_rockBottom_emergencyScenario =>
      'Scenario d\'urgence';

  @override
  String get gasCalculators_rockBottom_includeSafetyStop =>
      'Inclure le palier de securite';

  @override
  String get gasCalculators_rockBottom_maximumDepth => 'Profondeur maximale';

  @override
  String get gasCalculators_rockBottom_minimumReserve => 'Reserve minimale';

  @override
  String gasCalculators_rockBottom_resultSemantics(
    Object pressure,
    Object pressureUnit,
    Object volume,
    Object volumeUnit,
  ) {
    return 'Reserve minimale : $pressure $pressureUnit, $volume $volumeUnit. Faites demi-tour a $pressure $pressureUnit restants';
  }

  @override
  String gasCalculators_rockBottom_safetyStopDuration(
    Object depth,
    Object unit,
  ) {
    return '3 minutes a $depth$unit';
  }

  @override
  String gasCalculators_rockBottom_safetyStopGas(Object depth, Object unit) {
    return 'Gaz du palier de securite (3 min @ $depth$unit)';
  }

  @override
  String get gasCalculators_rockBottom_stressedSacHint =>
      'Utilisez des consommations majorees pour tenir compte du stress en urgence';

  @override
  String get gasCalculators_rockBottom_stressedSacRates =>
      'Consommations majorees';

  @override
  String get gasCalculators_rockBottom_tankSize => 'Taille du bloc';

  @override
  String get gasCalculators_rockBottom_totalReserveNeeded =>
      'Reserve totale necessaire';

  @override
  String gasCalculators_rockBottom_turnDive(
    Object pressure,
    Object pressureUnit,
  ) {
    return 'Faites demi-tour a $pressure $pressureUnit restants';
  }

  @override
  String get gasCalculators_rockBottom_yourSac => 'Votre SAC';

  @override
  String get maps_heatMap_hide => 'Masquer la carte de chaleur';

  @override
  String get maps_heatMap_overlayOff => 'La carte de chaleur est desactivee';

  @override
  String get maps_heatMap_overlayOn => 'La carte de chaleur est activee';

  @override
  String get maps_heatMap_show => 'Afficher la carte de chaleur';

  @override
  String get maps_offline_bounds => 'Limites';

  @override
  String maps_offline_cacheHitRateAccessibility(Object rate) {
    return 'Taux de succes du cache : $rate pour cent';
  }

  @override
  String get maps_offline_cacheHits => 'Succes du cache';

  @override
  String get maps_offline_cacheMisses => 'Echecs du cache';

  @override
  String get maps_offline_cacheStatistics => 'Statistiques du cache';

  @override
  String get maps_offline_cancelDownload => 'Annuler le telechargement';

  @override
  String get maps_offline_clearAll => 'Tout effacer';

  @override
  String get maps_offline_clearAllCache => 'Vider tout le cache';

  @override
  String get maps_offline_clearAllCacheMessage =>
      'Supprimer toutes les regions de carte telechargees et les tuiles en cache ?';

  @override
  String get maps_offline_clearAllCacheTitle => 'Vider tout le cache ?';

  @override
  String maps_offline_clearCacheStats(Object count, Object size) {
    return 'Cela supprimera $count tuiles ($size).';
  }

  @override
  String get maps_offline_created => 'Creee le';

  @override
  String maps_offline_deleteRegion(Object name) {
    return 'Supprimer la region $name';
  }

  @override
  String maps_offline_deleteRegionMessage(
    Object name,
    Object count,
    Object size,
  ) {
    return 'Supprimer \"$name\" et ses $count tuiles en cache ?\n\nCela liberera $size d\'espace de stockage.';
  }

  @override
  String get maps_offline_deleteRegionTitle => 'Supprimer la region ?';

  @override
  String get maps_offline_downloadedRegions => 'Regions telechargees';

  @override
  String maps_offline_downloading(Object regionName) {
    return 'Telechargement : $regionName';
  }

  @override
  String maps_offline_downloadingAccessibility(
    Object regionName,
    Object percent,
    Object downloaded,
    Object total,
  ) {
    return 'Telechargement de $regionName, $percent pour cent termine, $downloaded sur $total tuiles';
  }

  @override
  String maps_offline_error(Object error) {
    return 'Erreur : $error';
  }

  @override
  String maps_offline_errorLoadingStats(Object error) {
    return 'Erreur de chargement des statistiques : $error';
  }

  @override
  String maps_offline_failedTiles(Object count) {
    return '$count echouees';
  }

  @override
  String maps_offline_hitRate(Object rate) {
    return 'Taux de succes : $rate%';
  }

  @override
  String get maps_offline_lastAccessed => 'Dernier acces';

  @override
  String get maps_offline_noRegions => 'Aucune region hors ligne';

  @override
  String get maps_offline_noRegionsDescription =>
      'Telechargez des regions de carte depuis la page de detail du site pour utiliser les cartes hors ligne.';

  @override
  String get maps_offline_refresh => 'Actualiser';

  @override
  String get maps_offline_region => 'Region';

  @override
  String maps_offline_regionInfo(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size | $count tuiles | Zoom $minZoom-$maxZoom';
  }

  @override
  String maps_offline_regionSubtitle(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size, $count tuiles, zoom $minZoom a $maxZoom';
  }

  @override
  String get maps_offline_size => 'Taille';

  @override
  String get maps_offline_tiles => 'Tuiles';

  @override
  String maps_offline_tilesPerSecond(Object rate) {
    return '$rate tuiles/sec';
  }

  @override
  String maps_offline_tilesProgress(Object downloaded, Object total) {
    return '$downloaded / $total tuiles';
  }

  @override
  String get maps_offline_title => 'Cartes hors ligne';

  @override
  String get maps_offline_zoomRange => 'Plage de zoom';

  @override
  String get maps_regionSelector_dragToAdjust =>
      'Faites glisser pour ajuster la selection';

  @override
  String get maps_regionSelector_dragToSelect =>
      'Faites glisser sur la carte pour selectionner une region';

  @override
  String get maps_regionSelector_selectRegion =>
      'Selectionner une region sur la carte';

  @override
  String get maps_regionSelector_selectRegionButton => 'Selectionner la region';

  @override
  String get tankPresets_addPreset => 'Ajouter un preset de bloc';

  @override
  String get tankPresets_builtInPresets => 'Presets integres';

  @override
  String get tankPresets_customPresets => 'Presets personnalises';

  @override
  String tankPresets_deleteMessage(Object name) {
    return 'Voulez-vous vraiment supprimer \"$name\" ?';
  }

  @override
  String get tankPresets_deletePreset => 'Supprimer le preset';

  @override
  String get tankPresets_deleteTitle => 'Supprimer le preset de bloc ?';

  @override
  String tankPresets_deleted(Object name) {
    return '\"$name\" supprime';
  }

  @override
  String get tankPresets_editPreset => 'Modifier le preset';

  @override
  String tankPresets_edit_created(Object name) {
    return '\"$name\" cree';
  }

  @override
  String get tankPresets_edit_descriptionHint =>
      'ex. Mon bloc de location du centre de plongee';

  @override
  String get tankPresets_edit_descriptionOptional => 'Description (facultatif)';

  @override
  String tankPresets_edit_errorLoading(Object error) {
    return 'Erreur de chargement du preset : $error';
  }

  @override
  String tankPresets_edit_errorSaving(Object error) {
    return 'Erreur d\'enregistrement du preset : $error';
  }

  @override
  String tankPresets_edit_gasCapacity(Object capacity) {
    return '- Capacite de gaz : $capacity cuft';
  }

  @override
  String get tankPresets_edit_material => 'Materiau';

  @override
  String get tankPresets_edit_name => 'Nom';

  @override
  String get tankPresets_edit_nameHelper =>
      'Un nom convivial pour ce preset de bloc';

  @override
  String get tankPresets_edit_nameHint => 'ex. Mon AL80';

  @override
  String get tankPresets_edit_nameRequired => 'Veuillez saisir un nom';

  @override
  String get tankPresets_edit_ratedPressure => 'Pression nominale';

  @override
  String get tankPresets_edit_required => 'Obligatoire';

  @override
  String get tankPresets_edit_tankSpecifications => 'Specifications du bloc';

  @override
  String get tankPresets_edit_title => 'Modifier le preset de bloc';

  @override
  String tankPresets_edit_updated(Object name) {
    return '\"$name\" mis a jour';
  }

  @override
  String get tankPresets_edit_validPressure => 'Saisissez une pression valide';

  @override
  String get tankPresets_edit_validVolume => 'Saisissez un volume valide';

  @override
  String get tankPresets_edit_volume => 'Volume';

  @override
  String get tankPresets_edit_volumeHelperCuft => 'Capacite de gaz (cuft)';

  @override
  String get tankPresets_edit_volumeHelperLiters => 'Volume d\'eau (L)';

  @override
  String tankPresets_edit_waterVolume(Object volume) {
    return '- Volume d\'eau : $volume L';
  }

  @override
  String get tankPresets_edit_workingPressure => 'Pression de service';

  @override
  String tankPresets_edit_workingPressureBar(Object pressure) {
    return '- Pression de service : $pressure bar';
  }

  @override
  String tankPresets_error(Object error) {
    return 'Erreur : $error';
  }

  @override
  String tankPresets_errorDeleting(Object error) {
    return 'Erreur de suppression du preset : $error';
  }

  @override
  String get tankPresets_new_title => 'Nouveau preset de bloc';

  @override
  String get tankPresets_noPresets => 'Aucun preset de bloc disponible';

  @override
  String get tankPresets_title => 'Presets de blocs';

  @override
  String get tools_deco_description =>
      'Calculez les limites de non-decompression, les paliers de deco requis et l\'exposition CNS/OTU pour les profils de plongee multi-niveaux.';

  @override
  String get tools_deco_subtitle =>
      'Planifiez vos plongees avec paliers de deco';

  @override
  String get tools_deco_title => 'Calculateur de deco';

  @override
  String get tools_disclaimer =>
      'Ces calculateurs sont fournis a titre indicatif uniquement. Verifiez toujours les calculs et suivez votre formation de plongee.';

  @override
  String get tools_gas_description =>
      'Quatre calculateurs de gaz specialises :\n- MOD - Profondeur maximale d\'utilisation d\'un melange\n- Best Mix - O2% ideal pour une profondeur cible\n- Consommation - Estimation de la consommation de gaz\n- Rock Bottom - Calcul de la reserve d\'urgence';

  @override
  String get tools_gas_subtitle => 'MOD, Best Mix, Consommation, Rock Bottom';

  @override
  String get tools_gas_title => 'Calculateurs de gaz';

  @override
  String get tools_title => 'Outils';

  @override
  String get tools_weight_aluminumImperial => 'Plus flottant a vide (+4 lbs)';

  @override
  String get tools_weight_aluminumMetric => 'Plus flottant a vide (+2 kg)';

  @override
  String get tools_weight_bodyWeightOptional => 'Poids corporel (facultatif)';

  @override
  String get tools_weight_carbonFiberImperial => 'Tres flottant (+7 lbs)';

  @override
  String get tools_weight_carbonFiberMetric => 'Tres flottant (+3 kg)';

  @override
  String get tools_weight_description =>
      'Estimez le lestage necessaire en fonction de votre combinaison, du materiau du bloc, du type d\'eau et de votre poids.';

  @override
  String get tools_weight_disclaimer =>
      'Ceci est une estimation uniquement. Effectuez toujours un controle de flottabilite au debut de votre plongee et ajustez si necessaire. Le gilet, la flottabilite personnelle et les habitudes respiratoires influencent vos besoins reels en lestage.';

  @override
  String get tools_weight_exposureSuit => 'Combinaison';

  @override
  String tools_weight_gasCapacity(Object capacity) {
    return '- Capacite de gaz : $capacity cuft';
  }

  @override
  String get tools_weight_helperImperial =>
      'Ajoute ~2 lbs par 22 lbs au-dessus de 154 lbs';

  @override
  String get tools_weight_helperMetric =>
      'Ajoute ~1 kg par 10 kg au-dessus de 70 kg';

  @override
  String get tools_weight_notSpecified => 'Non specifie';

  @override
  String get tools_weight_recommendedWeight => 'Lestage recommande';

  @override
  String tools_weight_resultAccessibility(Object weight, Object unit) {
    return 'Lestage recommande : $weight $unit';
  }

  @override
  String get tools_weight_steelImperial => 'Flottabilite negative (-4 lbs)';

  @override
  String get tools_weight_steelMetric => 'Flottabilite negative (-2 kg)';

  @override
  String get tools_weight_subtitle =>
      'Lestage recommande pour votre configuration';

  @override
  String get tools_weight_tankMaterial => 'Materiau du bloc';

  @override
  String get tools_weight_tankSpecifications => 'Specifications du bloc';

  @override
  String get tools_weight_title => 'Calculateur de lestage';

  @override
  String get tools_weight_waterType => 'Type d\'eau';

  @override
  String tools_weight_waterVolume(Object volume) {
    return '- Volume d\'eau : $volume L';
  }

  @override
  String tools_weight_workingPressure(Object pressure) {
    return '- Pression de service : $pressure bar';
  }

  @override
  String get tools_weight_yourWeight => 'Votre poids';
}
