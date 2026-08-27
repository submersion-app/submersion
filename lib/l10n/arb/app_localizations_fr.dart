// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get universalImport_action_importFromGarmin =>
      'Importer depuis l\'appareil Garmin';

  @override
  String diveLog_edit_flightWindowWarning(String time) {
    return 'Cette plongée se termine après l\'heure limite de remontée pour votre vol ($time)';
  }

  @override
  String diveLog_edit_geofenceSuggestion_near(String location) {
    return 'Près de $location';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_title =>
      'Suggestion d\'équipement';

  @override
  String diveLog_edit_geofenceSuggestion_body(String setName) {
    return 'Appliquer l\'ensemble \"$setName\" ?';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_apply => 'Appliquer';

  @override
  String get common_action_dismiss => 'Ignorer';

  @override
  String get equipment_setEdit_defaultSwitch_title => 'Ensemble par défaut';

  @override
  String get equipment_setEdit_defaultSwitch_subtitle =>
      'Appliqué automatiquement aux nouvelles plongées sans équipement';

  @override
  String get equipment_setEdit_geofencesTitle => 'Géorepères';

  @override
  String get equipment_setEdit_geofencesSubtitle =>
      'Suggérer automatiquement cet ensemble pour les plongées près de ces lieux';

  @override
  String get equipment_setEdit_addGeofence => 'Ajouter un géorepère';

  @override
  String get equipment_setEdit_editGeofence => 'Edit geofence';

  @override
  String get equipment_setEdit_removeGeofence => 'Remove geofence';

  @override
  String equipment_setEdit_geofenceRadius(String distance) {
    return 'Rayon : $distance';
  }

  @override
  String get equipment_geofenceEditor_title => 'Géorepère';

  @override
  String get equipment_geofenceEditor_fromSite => 'Depuis le site de plongée';

  @override
  String get equipment_geofenceEditor_dropPin => 'Placer un repère';

  @override
  String get equipment_geofenceEditor_labelLabel => 'Étiquette';

  @override
  String get equipment_geofenceEditor_noCenter => 'Choisir un point central';

  @override
  String get equipment_geofenceEditor_save => 'Enregistrer le géorepère';

  @override
  String get equipment_sets_defaultBadge => 'Par défaut';

  @override
  String get equipment_setDetail_setAsDefault => 'Définir par défaut';

  @override
  String equipment_setDetail_setAsDefaultSnackbar(String name) {
    return '\"$name\" est désormais votre ensemble par défaut';
  }

  @override
  String get equipment_setDetail_geofencesTitle => 'Géorepères';

  @override
  String get equipment_setDetail_noGeofences => 'Aucun géorepère';

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
    return 'Au-dessus du plafond de densite de $limit g/L.';
  }

  @override
  String get gasCalculators_bestMix_densityLabel =>
      'Densite du gaz a la profondeur';

  @override
  String gasCalculators_bestMix_densityWarn(Object limit) {
    return 'Au-dessus de la limite de densite recommandee de $limit g/L.';
  }

  @override
  String gasCalculators_bestMix_endExceeded(Object limit) {
    return 'L\'END depasse votre limite de $limit.';
  }

  @override
  String get gasCalculators_bestMix_endLabel => 'END a la profondeur';

  @override
  String get gasCalculators_bestMix_endLimitLabel => 'Limite END';

  @override
  String gasCalculators_bestMix_heliumAdded(Object limit) {
    return 'Helium ajoute pour maintenir l\'END dans votre limite de $limit.';
  }

  @override
  String get gasCalculators_bestMix_idealLabel => 'Fraction ideale';

  @override
  String get gasCalculators_bestMix_marginLabel => 'Marge sous la MOD';

  @override
  String gasCalculators_bestMix_modLabel(Object ppO2) {
    return 'MOD a ppO2 $ppO2';
  }

  @override
  String get gasCalculators_bestMix_nearestStandard =>
      'Melange standard le plus proche couvrant cette profondeur';

  @override
  String get gasCalculators_bestMix_recommendedMix => 'Melange recommande';

  @override
  String get gasCalculators_bestMix_withoutHelium => 'Sans helium';

  @override
  String get gasCalculators_planningCaveat =>
      'Estimation de planification. Suppose une remontee directe. Verifiez selon votre formation et ajoutez une marge pour les conditions.';

  @override
  String gasCalculators_rockBottom_solveGas(Object depth, Object unit) {
    return 'Gaz de resolution du probleme a $depth$unit';
  }

  @override
  String get gasCalculators_rockBottom_solveTime =>
      'Temps de resolution du probleme';

  @override
  String get gasCalculators_rockBottom_solveTimeHint =>
      'Temps passe au fond a resoudre l\'urgence avant d\'entamer la remontee.';

  @override
  String o2Toxicity_addedThisDive(Object value) {
    return '+$value cette plongee';
  }

  @override
  String o2Toxicity_cnsProgressSemantics(Object percent) {
    return 'Progression SNC $percent pour cent';
  }

  @override
  String get o2Toxicity_daily => 'Quotidien';

  @override
  String o2Toxicity_otuSemantics(
    Object label,
    Object value,
    Object limit,
    Object percent,
  ) {
    return '$label : $value sur $limit OTU, $percent pour cent';
  }

  @override
  String o2Toxicity_otuValueSemantics(Object label, Object value) {
    return '$label : $value OTU';
  }

  @override
  String o2Toxicity_prior(Object value) {
    return 'Anterieur : $value OTU';
  }

  @override
  String o2Toxicity_start(Object value) {
    return 'Debut : $value OTU';
  }

  @override
  String get o2Toxicity_thisDive => 'Cette plongee';

  @override
  String get o2Toxicity_weekly => 'Hebdomadaire';

  @override
  String trips_story_dayLabel(int number) {
    return 'Jour $number';
  }

  @override
  String get trips_story_surfaceDay => 'Journée en surface';

  @override
  String get trips_story_today => 'Aujourd\'hui';

  @override
  String trips_story_dayOfTrip(int current, int total) {
    return 'Jour $current sur $total';
  }

  @override
  String trips_story_daysUntil(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours avant le départ',
      one: '1 jour avant le départ',
    );
    return '$_temp0';
  }

  @override
  String trips_story_checklistProgress(int done, int total) {
    return '$done sur $total fait';
  }

  @override
  String get trips_story_generateItinerary => 'Générer l\'itinéraire';

  @override
  String get trips_story_openGallery => 'Ouvrir les photos du voyage';

  @override
  String trips_story_generateItineraryError(String error) {
    return 'Impossible de générer l\'itinéraire : $error';
  }

  @override
  String get trips_dayType_diveDay => 'Jour de plongée';

  @override
  String get trips_dayType_seaDay => 'Jour en mer';

  @override
  String get trips_dayType_portDay => 'Jour au port';

  @override
  String get trips_dayType_embark => 'Embarquement';

  @override
  String get trips_dayType_disembark => 'Débarquement';

  @override
  String get trips_story_planned => 'Prévu';

  @override
  String get trips_story_empty_title =>
      'Pas encore de plongées ni d\'itinéraire';

  @override
  String get trips_story_empty_subtitle =>
      'Ajoutez des plongées ou planifiez les jours pour voir le récit.';

  @override
  String trips_story_history_dives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongées passées ici',
      one: '1 plongée passée ici',
    );
    return '$_temp0';
  }

  @override
  String trips_story_history_avgTemp(String value) {
    return 'moy. $value';
  }

  @override
  String trips_story_history_avgDepth(String value) {
    return 'prof. moy. $value';
  }

  @override
  String get trips_story_rhythm_semantics =>
      'Heures de plongée de cette journée';

  @override
  String get trips_story_map_semantics =>
      'Carte du voyage. Les sites du jour affiché sont mis en évidence.';

  @override
  String get diveLog_bulkEdit_groupRebreather => 'Mode de plongée et recycleur';

  @override
  String get diveLog_bulkEdit_fieldSetpointLow => 'Consigne basse';

  @override
  String get diveLog_bulkEdit_fieldSetpointHigh => 'Consigne haute';

  @override
  String get diveLog_bulkEdit_fieldSetpointDeco => 'Consigne déco';

  @override
  String get diveLog_bulkEdit_fieldScrubberType => 'Type de cartouche';

  @override
  String get diveLog_bulkEdit_fieldScrubberDuration => 'Durée de la cartouche';

  @override
  String get diveLog_bulkEdit_contradiction =>
      'Le mode circuit ouvert n\'accepte pas les réglages de recycleur. Désactivez ces champs ou changez de mode.';

  @override
  String diveLog_bulkEdit_appBarTitle(int count) {
    return 'Modifier $count plongées';
  }

  @override
  String get diveLog_bulkEdit_groupLogistics => 'Logistique';

  @override
  String get diveLog_bulkEdit_groupWeather => 'Météo';

  @override
  String get diveLog_bulkEdit_groupCollections => 'Tags, équipement et faune';

  @override
  String get diveLog_bulkEdit_fieldFavorite => 'Favori';

  @override
  String get diveLog_bulkEdit_fieldMyRole => 'Mon rôle';

  @override
  String get diveLog_bulkEdit_buddyRoleMixed => 'Variable';

  @override
  String get diveLog_bulkEdit_collectionWeights => 'Lestage';

  @override
  String get diveLog_bulkEdit_collectionTanks => 'Blocs';

  @override
  String get diveLog_bulkEdit_notesSet => 'Définir';

  @override
  String get diveLog_bulkEdit_notesAppend => 'Ajouter à la fin';

  @override
  String get diveLog_bulkEdit_modeAdd => 'Ajouter';

  @override
  String get diveLog_bulkEdit_modeRemove => 'Retirer';

  @override
  String get diveLog_bulkEdit_modeReplace => 'Remplacer';

  @override
  String get diveLog_bulkEdit_modeUpdate => 'Mettre à jour';

  @override
  String get diveLog_bulkEdit_tankOnlyIfEmpty =>
      'Seulement les plongées sans bloc existant';

  @override
  String get diveLog_bulkEdit_tankSpecsHint =>
      'Choisis les attributs à écraser sur les blocs que ces plongées possèdent déjà. Les pressions de début et de fin ne sont jamais modifiées.';

  @override
  String get diveLog_bulkEdit_tankSpecsNoFields =>
      'Choisis au moins un attribut de bloc à mettre à jour.';

  @override
  String get diveLog_bulkEdit_tankFieldPreset => 'Préréglage';

  @override
  String get diveLog_bulkEdit_tankFieldRole => 'Rôle';

  @override
  String get diveLog_bulkEdit_tankFieldVolume => 'Volume';

  @override
  String get diveLog_bulkEdit_tankFieldWorkingPressure => 'Pression de service';

  @override
  String get diveLog_bulkEdit_tankFieldMaterial => 'Matériau';

  @override
  String get diveLog_bulkEdit_tankFieldGasMix => 'Mélange gazeux';

  @override
  String get diveLog_bulkEdit_tankFieldName => 'Nom';

  @override
  String diveLog_bulkEdit_tankSpecsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count plongées sélectionnées n\'ont pas de bloc et seront ignorées.',
      one: '1 plongée sélectionnée n\'a pas de bloc et sera ignorée.',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_bulkEdit_confirmTitle => 'Appliquer les modifications ?';

  @override
  String get diveLog_bulkEdit_confirmApply => 'Appliquer';

  @override
  String get diveLog_bulkEdit_nothingSelected =>
      'Activez au moins un champ pour appliquer les modifications.';

  @override
  String diveLog_bulkEdit_applied(int count) {
    return '$count plongées mises à jour';
  }

  @override
  String get settings_cloudSync_error_icloudSignedOut =>
      'iCloud n\'est pas disponible. Connectez-vous à iCloud dans les réglages de votre appareil.';

  @override
  String get settings_cloudSync_error_icloudUnknown =>
      'Impossible de joindre iCloud. Veuillez réessayer.';

  @override
  String get settings_cloudSync_error_icloudUnsupported =>
      'La synchronisation iCloud n\'est pas disponible dans cette version de Submersion. Utilisez la synchronisation S3 ou la version de l\'App Store.';

  @override
  String get settings_cloudSync_provider_icloud_unsupportedSubtitle =>
      'Indisponible dans cette version — utilisez S3 ou la version de l\'App Store';

  @override
  String get settings_cloudSync_encryption_title =>
      'Chiffrement de bout en bout';

  @override
  String get settings_cloudSync_encryption_subtitleOff =>
      'Chiffrer toutes les données de synchronisation et les sauvegardes cloud avant l\'envoi';

  @override
  String get settings_cloudSync_encryption_subtitleNeedsProvider =>
      'Sélectionnez d\'abord un fournisseur cloud';

  @override
  String get settings_cloudSync_encryption_statusOff =>
      'Le chiffrement est désactivé';

  @override
  String get settings_cloudSync_encryption_statusOn =>
      'Le chiffrement est activé';

  @override
  String get settings_cloudSync_encryption_statusOnSubtitle =>
      'Les données de synchronisation et les sauvegardes cloud sont chiffrées avant l\'envoi';

  @override
  String get settings_cloudSync_encryption_statusLocked =>
      'Chiffré — phrase secrète requise';

  @override
  String get settings_cloudSync_encryption_statusLockedSubtitle =>
      'Saisissez la phrase secrète pour synchroniser sur cet appareil';

  @override
  String get settings_cloudSync_encryption_enable => 'Activer le chiffrement';

  @override
  String get settings_cloudSync_encryption_enterPassphrase =>
      'Saisir la phrase secrète';

  @override
  String get settings_cloudSync_encryption_passphrase => 'Phrase secrète';

  @override
  String get settings_cloudSync_encryption_passphraseConfirm =>
      'Confirmer la phrase secrète';

  @override
  String get settings_cloudSync_encryption_passphraseMismatch =>
      'Les phrases secrètes ne correspondent pas';

  @override
  String get settings_cloudSync_encryption_passphraseTooShort =>
      'Utilisez au moins 8 caractères';

  @override
  String get settings_cloudSync_encryption_wrongPassphrase =>
      'Phrase secrète ou code de récupération incorrect';

  @override
  String get settings_cloudSync_encryption_warnUpdateDevices =>
      'Tous les autres appareils doivent être mis à jour vers la dernière version de l\'application et retélechargeront la bibliothèque.';

  @override
  String get settings_cloudSync_encryption_warnLoss =>
      'Si vous perdez la phrase secrète et le code de récupération, les données dans le cloud seront irrécupérables. Les données sur vos appareils ne sont jamais menacées.';

  @override
  String get settings_cloudSync_encryption_deletePlaintextBackups =>
      'Supprimer les sauvegardes cloud non chiffrées existantes';

  @override
  String get settings_cloudSync_encryption_recoveryTitle =>
      'Code de récupération';

  @override
  String get settings_cloudSync_encryption_recoveryExplain =>
      'Notez ce code et conservez-le en lieu sûr. C\'est le seul moyen de récupérer l\'accès si vous oubliez la phrase secrète.';

  @override
  String get settings_cloudSync_encryption_recoverySavedConfirm =>
      'J\'ai enregistré mon code de récupération';

  @override
  String get settings_cloudSync_encryption_changePassphrase =>
      'Changer la phrase secrète';

  @override
  String get settings_cloudSync_encryption_currentPassphrase =>
      'Phrase secrète actuelle';

  @override
  String get settings_cloudSync_encryption_newPassphrase =>
      'Nouvelle phrase secrète';

  @override
  String get settings_cloudSync_encryption_regenerateRecovery =>
      'Générer un nouveau code de récupération';

  @override
  String get settings_cloudSync_encryption_regenerateRecoveryWarn =>
      'L\'ancien code de récupération cesse immédiatement de fonctionner.';

  @override
  String get settings_cloudSync_encryption_disable =>
      'Désactiver le chiffrement';

  @override
  String get settings_cloudSync_encryption_disableWarn =>
      'La bibliothèque sera renvoyée non chiffrée et les autres appareils la retéléchargeront. Les sauvegardes chiffrées existantes restent restaurables avec la phrase secrète.';

  @override
  String get settings_cloudSync_encryption_unlockTitle =>
      'Saisissez votre phrase secrète de chiffrement';

  @override
  String get settings_cloudSync_encryption_unlockHint =>
      'Phrase secrète ou code de récupération';

  @override
  String get settings_cloudSync_encryption_unlock => 'Déverrouiller';

  @override
  String get settings_cloudSync_encryption_continue => 'Continuer';

  @override
  String get settings_cloudSync_encryption_done => 'Terminé';

  @override
  String get settings_cloudSync_encryption_cancel => 'Annuler';

  @override
  String get settings_backupEncryption_title => 'Chiffrement des sauvegardes';

  @override
  String get settings_backupEncryption_subtitleOff =>
      'Protégez vos sauvegardes avec un mot de passe';

  @override
  String get settings_backupEncryption_subtitleOn =>
      'Les sauvegardes sont chiffrées avec votre mot de passe';

  @override
  String get settings_backupEncryption_enable => 'Chiffrer les sauvegardes';

  @override
  String get settings_backupEncryption_turnOff => 'Désactiver le chiffrement';

  @override
  String get settings_backupEncryption_turnOffTitle =>
      'Désactiver le chiffrement des sauvegardes ?';

  @override
  String get settings_backupEncryption_turnOffBody =>
      'Les nouvelles sauvegardes ne seront plus chiffrées. Les sauvegardes chiffrées existantes nécessitent toujours votre mot de passe pour être restaurées.';

  @override
  String get settings_backupEncryption_changePassword =>
      'Changer le mot de passe';

  @override
  String get settings_backupEncryption_regenerateRecovery =>
      'Générer un nouveau code de récupération';

  @override
  String get settings_backupEncryption_password => 'Mot de passe';

  @override
  String get settings_backupEncryption_passwordConfirm =>
      'Confirmer le mot de passe';

  @override
  String get settings_backupEncryption_passwordTooShort =>
      'Utilisez au moins 8 caractères';

  @override
  String get settings_backupEncryption_passwordMismatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get settings_backupEncryption_currentPassword => 'Mot de passe actuel';

  @override
  String get settings_backupEncryption_newPassword => 'Nouveau mot de passe';

  @override
  String get settings_backupEncryption_changePasswordWarn =>
      'Sur un autre appareil, chaque sauvegarde s\'ouvre avec le mot de passe ou le code de récupération actif au moment de sa création.';

  @override
  String get settings_backupEncryption_warnLoss =>
      'Si vous oubliez votre mot de passe et perdez le code de récupération, les sauvegardes chiffrées ne pourront pas être récupérées.';

  @override
  String get settings_backupEncryption_recoveryTitle =>
      'Votre code de récupération';

  @override
  String get settings_backupEncryption_recoveryExplain =>
      'Conservez ce code en lieu sûr. Il peut déverrouiller vos sauvegardes si vous oubliez votre mot de passe.';

  @override
  String get settings_backupEncryption_recoverySavedConfirm =>
      'J\'ai enregistré mon code de récupération';

  @override
  String get settings_backupEncryption_unlockTitle =>
      'Saisissez le mot de passe de sauvegarde';

  @override
  String get settings_backupEncryption_unlockHint =>
      'Saisissez votre mot de passe de sauvegarde ou code de récupération';

  @override
  String get settings_backupEncryption_restoreUnlockTitle =>
      'Déverrouiller la sauvegarde chiffrée';

  @override
  String get settings_backupEncryption_restoreUnlockHint =>
      'Saisissez le mot de passe ou le code de récupération de cette sauvegarde';

  @override
  String get settings_backupEncryption_continue => 'Continuer';

  @override
  String get settings_backupEncryption_cancel => 'Annuler';

  @override
  String get settings_backupEncryption_done => 'Terminé';

  @override
  String get settings_backupEncryption_reencryptTitle =>
      'Chiffrer les sauvegardes existantes ?';

  @override
  String get settings_backupEncryption_reencryptBody =>
      'Vos sauvegardes existantes ne sont toujours pas chiffrées. Les rechiffrer maintenant avec votre nouveau mot de passe ?';

  @override
  String get settings_backupEncryption_reencryptNow => 'Rechiffrer maintenant';

  @override
  String get settings_backupEncryption_reencryptNotNow => 'Pas maintenant';

  @override
  String settings_backupEncryption_reencryptPartial(int done, int failed) {
    return '$done sauvegardes rechiffrées ; $failed n\'ont pas pu être chiffrées et restent non protégées';
  }

  @override
  String settings_backupEncryption_reencryptDone(int count) {
    return '$count sauvegardes rechiffrées';
  }

  @override
  String get settings_backupEncryption_wrongPassword =>
      'Mot de passe ou code de récupération incorrect';

  @override
  String settings_cloudSync_replace_globalBanner(String deviceName) {
    return 'Synchronisation en pause — la bibliothèque a été remplacée depuis une sauvegarde sur \"$deviceName\".';
  }

  @override
  String get settings_cloudSync_postRestore_syncing =>
      'Synchronisation de votre bibliothèque restaurée avec le cloud…';

  @override
  String get settings_cloudSync_postRestore_synced =>
      'Bibliothèque restaurée synchronisée.';

  @override
  String get settings_cloudSync_replace_reviewAction => 'Examiner';

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
  String get accessibility_label_resizeMasterPane =>
      'Redimensionner le panneau principal';

  @override
  String get accessibility_label_sharedWithAllProfiles =>
      'Partagé avec tous les profils de plongée';

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
  String get backup_export_bottomSheet_title => 'Exporter la sauvegarde';

  @override
  String get backup_export_saveToFile => 'Enregistrer dans un fichier';

  @override
  String get backup_export_saveToFile_subtitle =>
      'Choisissez ou enregistrer le fichier de sauvegarde';

  @override
  String get backup_export_share => 'Partager';

  @override
  String get backup_export_share_subtitle =>
      'Envoyer via AirDrop, e-mail ou autres applications';

  @override
  String get backup_export_subtitle =>
      'Enregistrez vos donnees de plongee dans un fichier';

  @override
  String get backup_export_success => 'Sauvegarde exportee avec succes';

  @override
  String get backup_export_title => 'Exporter la sauvegarde';

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
  String get backup_history_pinAction_pin => 'Epingler la sauvegarde';

  @override
  String get backup_history_pinAction_unpin => 'Desepingler la sauvegarde';

  @override
  String get backup_history_pinError =>
      'Impossible de mettre a jour l\'etat d\'epinglage.';

  @override
  String backup_history_preMigrationSubtitle(String size) {
    return 'Sauvegarde avant migration - $size';
  }

  @override
  String get backup_import_invalidFile =>
      'Ce fichier ne semble pas etre une sauvegarde Submersion valide';

  @override
  String get backup_import_subtitle =>
      'Importer une sauvegarde depuis n\'importe quel emplacement';

  @override
  String get backup_import_title => 'Restaurer depuis un fichier';

  @override
  String get backup_import_validating =>
      'Validation du fichier de sauvegarde...';

  @override
  String get backup_location_change => 'Modifier';

  @override
  String get backup_location_default => 'Emplacement par defaut';

  @override
  String get backup_location_title => 'Emplacement de sauvegarde';

  @override
  String get backup_replaceConfirm_confirm => 'Remplacer partout';

  @override
  String get backup_replaceConfirm_content =>
      'La bibliothèque de tous les appareils synchronisés sera remplacée par cette sauvegarde. Chaque appareil crée d\'abord une sauvegarde de sécurité de ses données actuelles. Cette action est irréversible.';

  @override
  String get backup_replaceConfirm_title =>
      'Remplacer la bibliothèque partout ?';

  @override
  String get backup_restore_dialog_cancel => 'Annuler';

  @override
  String get backup_restore_dialog_modeMerge_subtitle =>
      'Restaurer sur cet appareil. La prochaine synchronisation combinera les données restaurées avec la bibliothèque dans le cloud.';

  @override
  String get backup_restore_dialog_modeMerge_title =>
      'Fusionner à la prochaine synchronisation';

  @override
  String get backup_restore_dialog_modeReplace_subtitle =>
      'La sauvegarde devient la bibliothèque sur cet appareil, dans le cloud et sur chaque appareil synchronisé.';

  @override
  String get backup_restore_dialog_modeReplace_title => 'Remplacer partout';

  @override
  String get backup_restore_dialog_restore => 'Restaurer';

  @override
  String get backup_restore_dialog_restoreReplace =>
      'Restaurer et remplacer partout';

  @override
  String get backup_restore_dialog_safetyNote =>
      'Une sauvegarde de sécurité de vos données actuelles sera créée automatiquement avant la restauration.';

  @override
  String get backup_restore_dialog_title => 'Restaurer la Sauvegarde';

  @override
  String get backup_restore_dialog_warning =>
      'Cela remplacera TOUTES les données actuelles par les données de la sauvegarde. Cette action est irréversible.';

  @override
  String backup_restore_safetyReview_progress(int done, int total) {
    return '$done plongées sur $total analysées';
  }

  @override
  String get backup_restore_safetyReview_skip => 'Ignorer';

  @override
  String get backup_restore_safetyReview_title =>
      'Analyse de sécurité en cours';

  @override
  String get backup_restoreComplete_continue => 'Continuer';

  @override
  String get backup_restoreComplete_description =>
      'Vos donnees ont ete restaurees avec succes. Appuyez sur continuer pour recharger l\'application avec vos donnees restaurees.';

  @override
  String get backup_restoreComplete_title => 'Restauration terminee';

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
  String get backup_section_auto => 'Sauvegardes automatiques';

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
  String get buddies_action_addCertification => 'Ajouter une certification';

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
  String get buddies_picker_addCustomRole => 'Ajouter un rôle personnalisé...';

  @override
  String get buddies_picker_addNew => 'Ajouter un nouveau binôme';

  @override
  String get buddies_picker_done => 'Terminé';

  @override
  String get buddies_picker_me => 'Moi';

  @override
  String get buddies_picker_noBuddiesFound => 'Aucun binôme trouvé';

  @override
  String get buddies_picker_noBuddiesYet => 'Aucun binôme pour le moment';

  @override
  String get buddies_picker_noRole => 'Aucun rôle';

  @override
  String get buddies_picker_noneSelected => 'Aucun binôme sélectionné';

  @override
  String get buddies_picker_searchHint => 'Rechercher des binômes...';

  @override
  String get buddies_picker_selectBuddies => 'Sélectionner les binômes';

  @override
  String get buddies_picker_selectMyRole => 'Sélectionner mon rôle';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Sélectionner le rôle pour $name';
  }

  @override
  String get buddies_picker_setMyRole => 'Définir mon rôle';

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
  String get buddies_section_certifications => 'Certifications';

  @override
  String get buddies_certifications_empty => 'Aucune certification';

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
  String get buddies_list_selection_closeTooltip => 'Fermer la sélection';

  @override
  String buddies_list_selection_count(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String get buddies_list_selection_selectAllTooltip => 'Tout sélectionner';

  @override
  String get buddies_list_selection_deselectAllTooltip => 'Tout désélectionner';

  @override
  String get buddies_list_selection_mergeTooltip => 'Fusionner la sélection';

  @override
  String get buddies_list_selection_deleteTooltip => 'Supprimer la sélection';

  @override
  String buddies_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'binômes',
      one: 'binôme',
    );
    return '$count $_temp0 fusionné(s)';
  }

  @override
  String get buddies_list_merge_undo => 'Annuler';

  @override
  String get buddies_list_merge_restored => 'Fusion annulée';

  @override
  String get buddies_list_bulkDelete_title => 'Supprimer les binômes';

  @override
  String buddies_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'binômes',
      one: 'binôme',
    );
    return 'Voulez-vous vraiment supprimer $count $_temp0 ? Cette action est irréversible.';
  }

  @override
  String get buddies_list_bulkDelete_cancel => 'Annuler';

  @override
  String get buddies_list_bulkDelete_confirm => 'Supprimer';

  @override
  String buddies_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'binômes',
      one: 'binôme',
    );
    return '$count $_temp0 supprimé(s)';
  }

  @override
  String get buddies_edit_merge_title => 'Fusionner les binômes';

  @override
  String get buddies_edit_merge_fieldSourceCycleTooltip =>
      'Utiliser la valeur du binôme sélectionné suivant';

  @override
  String buddies_edit_merge_fieldSourceLabel(
    String buddyName,
    int current,
    int total,
  ) {
    return 'De $buddyName ($current/$total)';
  }

  @override
  String get buddies_edit_merge_confirmTitle => 'Fusionner les binômes';

  @override
  String buddies_edit_merge_confirmBody(int count) {
    return 'Cela fusionnera $count binômes en un seul. Les associations de plongées seront regroupées sous le binôme survivant. Les autres binômes seront supprimés.';
  }

  @override
  String get buddies_edit_merge_loadingErrorTitle => 'Fusionner les binômes';

  @override
  String buddies_edit_merge_loadingErrorBody(String error) {
    return 'Échec du chargement des binômes : $error';
  }

  @override
  String get buddies_edit_merge_notEnoughTitle => 'Fusionner les binômes';

  @override
  String get buddies_edit_merge_notEnoughBody =>
      'Pas assez de binômes à fusionner.';

  @override
  String get buddies_instructorPicker_label => 'Moniteur parmi les binômes';

  @override
  String get buddies_instructorPicker_none => 'Aucun (saisie manuelle)';

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
  String get certifications_detail_label_certification => 'Certification';

  @override
  String get certifications_detail_label_expiryDate => 'Date d\'expiration';

  @override
  String get certifications_detail_label_instructorName => 'Nom';

  @override
  String get certifications_detail_label_instructorNumber => 'N° du moniteur';

  @override
  String get certifications_detail_label_issueDate => 'Date de delivrance';

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
  String get certifications_ecard_label_cardNumber => 'N° DE CARTE';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Certifie par $agency';
  }

  @override
  String get certifications_ecard_label_diver => 'PLONGEUR';

  @override
  String get certifications_ecard_label_instructor => 'MONITEUR';

  @override
  String get certifications_ecard_label_issued => 'DELIVRE';

  @override
  String get certifications_ecard_label_validUntil => 'VALABLE JUSQU\'AU';

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
  String get certifications_edit_certification_notSpecified => 'Non spécifié';

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
  String get certifications_edit_group_progression => 'Progression';

  @override
  String get certifications_edit_group_specialties => 'Spécialités';

  @override
  String get certifications_edit_help_expiryDate =>
      'Laisse vide pour les certifications sans expiration';

  @override
  String get certifications_edit_helper_nameOnCard => 'Facultatif';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Entrez le numero de carte de certification';

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
  String get certifications_edit_label_certification => 'Certification';

  @override
  String get certifications_edit_label_expiryDate => 'Date d\'expiration';

  @override
  String get certifications_edit_label_instructorName => 'Nom du moniteur';

  @override
  String get certifications_edit_label_instructorNumber => 'Numero du moniteur';

  @override
  String get certifications_edit_label_issueDate => 'Date de delivrance';

  @override
  String get certifications_edit_label_nameOnCard => 'Nom sur la carte';

  @override
  String get certifications_edit_label_notes => 'Notes';

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
  String get certifications_edit_validation_certificationOrNameRequired =>
      'Choisissez une certification ou saisissez un nom';

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
  String get checklists_section_title => 'Liste de contrôle';

  @override
  String checklists_progress(int done, int total) {
    return '$done sur $total tâches effectuées';
  }

  @override
  String get checklists_empty_upcoming =>
      'Planifiez votre voyage - ajoutez des tâches ou appliquez un modèle';

  @override
  String get checklists_empty_past => 'Aucun élément de liste de contrôle';

  @override
  String get checklists_addItem => 'Ajouter un élément';

  @override
  String get checklists_item_titleLabel => 'Titre';

  @override
  String get checklists_item_titleRequired => 'Le titre est requis';

  @override
  String get checklists_item_categoryLabel => 'Catégorie';

  @override
  String get checklists_item_notesLabel => 'Notes';

  @override
  String get checklists_item_dueDateLabel => 'Date d\'échéance';

  @override
  String get checklists_item_dueOffsetLabel => 'Jours avant le début du voyage';

  @override
  String get checklists_item_dueOffsetInvalid => 'Saisissez 0 jour ou plus';

  @override
  String get checklists_item_overdue => 'En retard';

  @override
  String get checklists_item_edit => 'Modifier l\'élément';

  @override
  String get checklists_item_delete => 'Supprimer l\'élément';

  @override
  String get checklists_menu_applyTemplate => 'Appliquer un modèle...';

  @override
  String get checklists_menu_saveAsTemplate => 'Enregistrer comme modèle...';

  @override
  String get checklists_applySheet_title => 'Appliquer un modèle';

  @override
  String get checklists_applySheet_empty =>
      'Aucun modèle pour l\'instant. Créez-en dans les Paramètres.';

  @override
  String checklists_applySheet_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String checklists_applySheet_confirmAppend(int added, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added éléments seront ajoutés',
      one: '1 élément sera ajouté',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped doublons ignorés',
      one: '1 doublon ignoré',
      zero: 'aucun doublon ignoré',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String checklists_apply_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments ajoutés',
      one: '1 élément ajouté',
      zero: 'Aucun nouvel élément ajouté',
    );
    return '$_temp0';
  }

  @override
  String get checklists_apply_templateGone => 'Le modèle n\'existe plus';

  @override
  String get checklists_saveTemplate_title => 'Enregistrer comme modèle';

  @override
  String get checklists_saveTemplate_nameLabel => 'Nom du modèle';

  @override
  String get checklists_saveTemplate_success => 'Modèle enregistré';

  @override
  String get checklists_templates_pageTitle => 'Modèles de liste de contrôle';

  @override
  String get checklists_templates_addTemplate => 'Ajouter un modèle';

  @override
  String get checklists_templates_empty => 'Aucun modèle pour l\'instant';

  @override
  String get checklists_templates_deleteTitle => 'Supprimer le modèle';

  @override
  String checklists_templates_deleteContent(Object name) {
    return 'Supprimer « $name » ? Les voyages qui l\'ont déjà appliqué conservent leurs éléments.';
  }

  @override
  String get checklists_template_nameLabel => 'Nom';

  @override
  String get checklists_template_nameRequired => 'Le nom est requis';

  @override
  String get checklists_template_descriptionLabel => 'Description';

  @override
  String get checklists_template_itemsHeader => 'Éléments';

  @override
  String get checklists_template_addItem => 'Ajouter un élément';

  @override
  String get preDive_templates_title => 'Checklists pré-plongée';

  @override
  String get preDive_templates_empty =>
      'Aucune checklist pré-plongée pour le moment';

  @override
  String get preDive_templates_builtInBadge => 'Intégrée';

  @override
  String get preDive_templates_clone => 'Dupliquer';

  @override
  String get preDive_templates_cloneSuffix => ' (copie)';

  @override
  String get preDive_templates_delete => 'Supprimer';

  @override
  String get preDive_templates_deleteConfirm =>
      'Supprimer ce modèle de checklist ?';

  @override
  String get preDive_templates_strictOrderBadge => 'Ordre strict';

  @override
  String get preDive_edit_titleNew => 'Nouvelle checklist pré-plongée';

  @override
  String get preDive_edit_titleEdit => 'Modifier la checklist pré-plongée';

  @override
  String get preDive_edit_name => 'Nom';

  @override
  String get preDive_edit_description => 'Description';

  @override
  String get preDive_edit_category => 'Catégorie';

  @override
  String get preDive_edit_strictOrder => 'Ordre strict';

  @override
  String get preDive_edit_strictOrderHelp =>
      'Les éléments doivent être complétés de haut en bas';

  @override
  String get preDive_edit_addItem => 'Ajouter un élément';

  @override
  String get preDive_edit_nameRequired => 'Saisissez un nom';

  @override
  String get preDive_item_title => 'Titre';

  @override
  String get preDive_item_section => 'Section';

  @override
  String get preDive_item_notes => 'Notes';

  @override
  String get preDive_item_required => 'Obligatoire';

  @override
  String get preDive_item_type_check => 'Case à cocher';

  @override
  String get preDive_item_type_value => 'Valeur enregistrée';

  @override
  String get preDive_item_type_equipmentSet =>
      'Éléments de l\'ensemble d\'équipement';

  @override
  String get preDive_item_valueLabel => 'Libellé de la valeur';

  @override
  String get preDive_item_valueUnit => 'Unité';

  @override
  String get preDive_item_valueMin => 'Min (avertissement)';

  @override
  String get preDive_item_valueMax => 'Max (avertissement)';

  @override
  String preDive_runner_progress(int done, int total) {
    return '$done sur $total';
  }

  @override
  String get preDive_runner_complete => 'Terminer';

  @override
  String preDive_runner_completeFlagged(int count) {
    return 'Terminer avec $count éléments signalés ?';
  }

  @override
  String get preDive_runner_abort => 'Abandonner la checklist';

  @override
  String get preDive_runner_abortConfirm =>
      'Abandonner cette checklist ? Elle sera conservée dans l\'historique comme abandonnée.';

  @override
  String get preDive_runner_skip => 'Passer';

  @override
  String get preDive_runner_flag => 'Signaler';

  @override
  String get preDive_runner_undo => 'Remettre en attente';

  @override
  String get preDive_runner_serviceOverdue => 'Entretien en retard';

  @override
  String get preDive_runner_addNote => 'Ajouter une note';

  @override
  String get preDive_runner_enterValue => 'Saisir une valeur';

  @override
  String preDive_runner_flaggedBadge(int count) {
    return '$count signalés';
  }

  @override
  String get preDive_runner_locked => 'Cette checklist est verrouillée';

  @override
  String get preDive_sessions_title => 'Checklists pré-plongée';

  @override
  String get preDive_sessions_empty =>
      'Aucune checklist effectuée pour le moment';

  @override
  String get preDive_sessions_resume => 'Reprendre';

  @override
  String get preDive_sessions_start => 'Démarrer la checklist';

  @override
  String get preDive_sessions_statusCompleted => 'Terminée';

  @override
  String get preDive_sessions_statusAborted => 'Abandonnée';

  @override
  String get preDive_sessions_statusInProgress => 'En cours';

  @override
  String get preDive_sessions_linkedDive => 'Plongée liée';

  @override
  String get preDive_link_linkToDive => 'Lier à une plongée';

  @override
  String get preDive_link_unlinkDive => 'Dissocier la plongée';

  @override
  String get preDive_link_linkChecklist => 'Lier une checklist pré-plongée';

  @override
  String get preDive_link_unlinkChecklist =>
      'Dissocier la checklist pré-plongée';

  @override
  String get preDive_link_searchDives => 'Rechercher des plongées';

  @override
  String get preDive_link_noDives => 'Aucune plongée à lier';

  @override
  String preDive_link_noDivesMatch(String query) {
    return 'Aucune plongée ne correspond à «$query»';
  }

  @override
  String get preDive_link_noUnlinkedSessions => 'Aucune checklist non liée';

  @override
  String get preDive_link_linked => 'Checklist liée à cette plongée';

  @override
  String get preDive_link_unlinked => 'Checklist dissociée de cette plongée';

  @override
  String get preDive_sessions_delete => 'Supprimer';

  @override
  String get preDive_sessions_deleteConfirm =>
      'Supprimer cet enregistrement de checklist ?';

  @override
  String get preDive_sessions_filter => 'Filtrer';

  @override
  String get preDive_sessions_filterTitle =>
      'Filtrer les checklists effectuées';

  @override
  String get preDive_sessions_filterChecklist => 'Checklist';

  @override
  String get preDive_sessions_filterStatus => 'Statut';

  @override
  String get preDive_sessions_filterFlaggedOnly => 'Uniquement les anomalies';

  @override
  String get preDive_sessions_filterDateRange => 'Période';

  @override
  String get preDive_sessions_filterAnyDate => 'Toutes les dates';

  @override
  String get preDive_sessions_filterClearAll => 'Tout effacer';

  @override
  String get preDive_sessions_filterApply => 'Appliquer';

  @override
  String get preDive_sessions_filterFlaggedChip => 'Anomalies uniquement';

  @override
  String get preDive_sessions_emptyFiltered =>
      'Aucune checklist ne correspond à ces filtres';

  @override
  String get preDive_sessions_export => 'Exporter vers Excel';

  @override
  String get preDive_sessions_exportEmpty => 'Aucune checklist à exporter';

  @override
  String preDive_sessions_exportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String get preDive_start_title => 'Démarrer la checklist pré-plongée';

  @override
  String get preDive_start_template => 'Checklist';

  @override
  String get preDive_start_equipmentSet => 'Ensemble d\'équipement';

  @override
  String get preDive_start_noEquipmentSet => 'Aucun';

  @override
  String get preDive_start_begin => 'Commencer';

  @override
  String get diveLog_listPage_bottomSheet_preDiveChecklist =>
      'Démarrer la checklist pré-plongée';

  @override
  String get preDive_dashboard_title => 'Vérification pré-plongée';

  @override
  String preDive_dashboard_resume(int done, int total) {
    return 'Reprendre - $done sur $total';
  }

  @override
  String get preDive_dashboard_start => 'Démarrer la vérification pré-plongée';

  @override
  String get trips_detail_preDive_action => 'Checklist pré-plongée';

  @override
  String get settings_manage_preDiveChecklists => 'Checklists pré-plongée';

  @override
  String get settings_manage_preDiveChecklists_subtitle =>
      'Vérifications entre binômes, listes de montage CCR, préparation du matériel';

  @override
  String get common_action_back => 'Retour';

  @override
  String get common_action_cancel => 'Annuler';

  @override
  String get common_action_close => 'Fermer';

  @override
  String get common_action_continue => 'Continuer';

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
  String get common_action_share => 'Partager';

  @override
  String get common_label_error => 'Erreur';

  @override
  String get common_label_loading => 'Chargement';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get common_error_tryAgain =>
      'Une erreur s\'est produite. Veuillez réessayer.';

  @override
  String get courses_action_add => 'Ajouter un cours';

  @override
  String get courses_action_addFromTemplate => 'Ajouter depuis un modèle';

  @override
  String get courses_action_addRequirement => 'Ajouter une exigence';

  @override
  String get courses_action_create => 'Créer un cours';

  @override
  String get courses_action_deleteRequirement => 'Supprimer l\'exigence';

  @override
  String get courses_action_edit => 'Modifier le cours';

  @override
  String get courses_action_editRequirement => 'Modifier l\'exigence';

  @override
  String get courses_action_exportTrainingLog =>
      'Exporter le carnet de formation';

  @override
  String get courses_action_linkDive => 'Associer';

  @override
  String get courses_action_markCompleted => 'Marquer comme terminé';

  @override
  String get courses_action_unlinkDive => 'Dissocier la plongée';

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
  String get courses_empty_button => 'Ajoutez votre premier cours de formation';

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
  String courses_requirement_diveProgress(int count, int target) {
    return '$count sur $target plongées';
  }

  @override
  String get courses_requirement_field_name => 'Nom';

  @override
  String get courses_requirement_field_targetCount => 'Plongées requises';

  @override
  String get courses_requirement_kind_checklist => 'Élément à cocher';

  @override
  String get courses_requirement_kind_dive => 'Exigence de plongée';

  @override
  String get courses_requirement_suggestions => 'Plongées suggérées';

  @override
  String get courses_requirements_empty =>
      'Suivez les plongées aventure, les prérequis et les éléments à cocher pour ce cours.';

  @override
  String courses_requirements_progress(int satisfied, int total) {
    return '$satisfied sur $total terminés';
  }

  @override
  String get courses_section_details => 'Détails du cours';

  @override
  String get courses_section_earnedCertification => 'Certification obtenue';

  @override
  String get courses_section_instructor => 'Instructeur';

  @override
  String get courses_section_notes => 'Notes';

  @override
  String get courses_section_requirements => 'Exigences';

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
  String courses_template_addsCount(int count) {
    return 'Ajoute $count exigences';
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
  String get dashboard_activeCourses_title => 'Cours en cours';

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
  String get dashboard_hero_divesTotalOne => '1 plongee';

  @override
  String dashboard_hero_divesTotalOther(Object count) {
    return '$count plongees';
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
  String get dashboard_hero_divesLoggedLabel => 'plongées enregistrées';

  @override
  String get dashboard_hero_hoursUnderwaterLabel => 'heures sous l\'eau';

  @override
  String get dashboard_hero_daysSinceLabel =>
      'jours depuis la dernière plongée';

  @override
  String get dashboard_hero_thisMonthLabel => 'ce mois';

  @override
  String get dashboard_hero_thisYearLabel => 'plongées cette année';

  @override
  String get dashboard_hero_todayLabel => 'aujourd\'hui !';

  @override
  String get dashboard_hero_noDivesLabel => 'aucune plongée';

  @override
  String get dashboard_hero_diverFallbackName => 'Plongeur';

  @override
  String get dashboard_hero_statDives => 'plongées';

  @override
  String get dashboard_hero_statHours => 'heures';

  @override
  String get dashboard_hero_statSites => 'sites';

  @override
  String get dashboard_hero_statCountries => 'pays';

  @override
  String dashboard_activityStats_divesInYear(String year) {
    return 'plongées en $year';
  }

  @override
  String get dashboard_semantics_statsBar =>
      'Résumé des statistiques de plongée';

  @override
  String get dashboard_gauges_addGear => 'Ajouter du matériel';

  @override
  String dashboard_gauges_gearOk(String name) {
    return '$name OK';
  }

  @override
  String dashboard_gauges_gearDueIn(String name, int days) {
    return '$name à réviser dans ${days}j';
  }

  @override
  String dashboard_gauges_gearOverdue(String name) {
    return '$name en retard de révision';
  }

  @override
  String get dashboard_gauges_insuranceOk => 'Assurance OK';

  @override
  String dashboard_gauges_insuranceExpires(String date) {
    return 'Assurance expire le $date';
  }

  @override
  String get dashboard_gauges_insuranceExpired => 'Assurance expirée';

  @override
  String get dashboard_gauges_noInsurance => 'Aucune assurance enregistrée';

  @override
  String get dashboard_gauges_noFlyClear => 'Délai avant vol 0:00';

  @override
  String dashboard_gauges_flightWindow(String hours, String minutes) {
    return 'Fenêtre de plongée $hours:$minutes';
  }

  @override
  String get dashboard_gauges_flightWindowClosed =>
      'Plus de plongée avant le vol';

  @override
  String dashboard_gauges_noFlyRemaining(String hours, String minutes) {
    return 'Délai avant vol $hours:$minutes';
  }

  @override
  String dashboard_gauges_lastDiveDays(int days) {
    return 'Dernière plongée il y a ${days}j';
  }

  @override
  String get dashboard_gauges_lastDiveToday => 'Plongé aujourd\'hui';

  @override
  String get dashboard_gauges_noDivesYet => 'Aucune plongée';

  @override
  String get settings_homeChips_pageTitle => 'Écran d\'accueil';

  @override
  String get settings_homeChips_description =>
      'Choisissez les pastilles d\'état affichées en haut de l\'onglet Accueil.';

  @override
  String get settings_homeChips_sectionTitle => 'Pastilles d\'état';

  @override
  String get settings_homeCards_sectionTitle => 'Cartes de l\'accueil';

  @override
  String get settings_homeCards_description =>
      'Choisissez les cartes affichées dans l\'onglet Accueil et faites-les glisser pour les réordonner.';

  @override
  String get settings_homeCards_autoHides =>
      'Masquée automatiquement lorsqu\'elle est vide';

  @override
  String get settings_homeCards_resetToDefault => 'Réinitialiser par défaut';

  @override
  String get settings_homeCards_resetDialog_title =>
      'Réinitialiser la disposition de l\'accueil ?';

  @override
  String get settings_homeCards_resetDialog_message =>
      'Restaure l\'ordre par défaut des cartes et les affiche toutes à nouveau.';

  @override
  String get settings_homeCards_resetDialog_cancel => 'Annuler';

  @override
  String get settings_homeCards_resetDialog_confirm => 'Réinitialiser';

  @override
  String get settings_homeCards_card_hero => 'En-tête de bienvenue';

  @override
  String get settings_homeCards_card_gaugeStrip => 'Pastilles d\'état';

  @override
  String get settings_homeCards_card_preDive => 'Check-list pré-plongée';

  @override
  String get settings_homeCards_card_recentDives => 'Plongées récentes';

  @override
  String get settings_homeCards_card_quickActions => 'Actions rapides';

  @override
  String get settings_homeCards_card_milestones => 'Jalons';

  @override
  String get settings_homeCards_card_photoRibbon => 'Médias récents';

  @override
  String get settings_homeCards_card_onThisDay => 'Ce jour-là';

  @override
  String get settings_homeCards_card_yearInReview =>
      'Rétrospective de l\'année';

  @override
  String get settings_homeCards_card_activeCourses => 'Progression des cours';

  @override
  String get settings_homeCards_card_recentSitesMap =>
      'Carte des sites récents';

  @override
  String get dashboard_allHidden_message =>
      'Toutes les cartes de l\'accueil sont masquées.';

  @override
  String get dashboard_allHidden_customize => 'Personnaliser l\'accueil';

  @override
  String get settings_homeChips_flightWindow => 'Fenêtre de plongée avant vol';

  @override
  String get settings_homeChips_gear => 'Entretien du matériel';

  @override
  String get settings_homeChips_insurance => 'Assurance';

  @override
  String get settings_homeChips_noFly => 'Délai avant vol';

  @override
  String get settings_homeChips_lastDive => 'Récence de plongée';

  @override
  String get settings_homeChips_certifications =>
      'Expiration des certifications';

  @override
  String get settings_homeChips_trip => 'Voyage à venir';

  @override
  String get settings_homeChips_checklist => 'Liste de contrôle active';

  @override
  String get settings_homeChips_course => 'Progression du cours';

  @override
  String get settings_homeChips_uploads => 'Envois de médias';

  @override
  String get settings_homeChips_backup => 'Âge de la sauvegarde';

  @override
  String get settings_homeChips_sync => 'État de synchronisation';

  @override
  String get settings_homeChips_dataQuality => 'Qualité des données';

  @override
  String dashboard_gauges_certsExpiring(int count) {
    return '$count certifications expirent bientôt';
  }

  @override
  String dashboard_gauges_tripCountdown(String name, int days) {
    return '$name dans ${days}j';
  }

  @override
  String get dashboard_gauges_checklistActive => 'Liste de contrôle en cours';

  @override
  String dashboard_gauges_courseProgress(String name, int done, int total) {
    return '$name : $done/$total';
  }

  @override
  String dashboard_gauges_uploadsPending(int count) {
    return '$count envois en attente';
  }

  @override
  String get dashboard_gauges_backupNone => 'Aucune sauvegarde';

  @override
  String get dashboard_gauges_backupToday => 'Sauvegardé aujourd\'hui';

  @override
  String dashboard_gauges_backupDays(int days) {
    return 'Sauvegarde il y a ${days}j';
  }

  @override
  String dashboard_gauges_syncPending(int count) {
    return '$count non synchronisés';
  }

  @override
  String get dashboard_gauges_synced => 'Synchronisé';

  @override
  String dashboard_gauges_dataIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problèmes de données',
      one: '1 problème de données',
    );
    return '$_temp0';
  }

  @override
  String get dashboard_gauges_retry =>
      'Statut indisponible - touchez pour réessayer';

  @override
  String get dashboard_urgent_title => 'Attention requise';

  @override
  String get dashboard_media_title => 'Médias récents';

  @override
  String get dashboard_recentSites_title => 'Sites récents';

  @override
  String get dashboard_yearInReview_title => 'Cette année';

  @override
  String dashboard_yearInReview_divesVs(int count, int previous) {
    return '$count plongées (contre $previous l\'an dernier)';
  }

  @override
  String dashboard_yearInReview_hours(String hours) {
    return '$hours heures sous l\'eau';
  }

  @override
  String dashboard_yearInReview_maxDepth(String depth) {
    return 'Prof. max : $depth';
  }

  @override
  String get dashboard_onThisDay_title => 'Ce jour-là';

  @override
  String dashboard_onThisDay_entry(String year, String site) {
    return '$year - $site';
  }

  @override
  String get dashboard_milestones_title => 'Étapes';

  @override
  String dashboard_milestones_nextDive(int remaining, int milestone) {
    return '$remaining plongées avant la n°$milestone';
  }

  @override
  String dashboard_milestones_certYears(String name, int years, String month) {
    return '$name : $years ans en $month';
  }

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
  String get dashboard_recentDives_latestProfileTitle =>
      'Profil de la dernière plongée';

  @override
  String get dashboard_recentDives_noProfileData =>
      'Aucune donnée de profil pour cette plongée';

  @override
  String get dashboard_recentDives_profileLoadError =>
      'Impossible de charger le profil de plongée';

  @override
  String dashboard_recentDives_profileMinutes(int minutes) {
    return '$minutes min';
  }

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
  String get decoCalculator_waterType => 'Type d\'eau';

  @override
  String get decoCalculator_waterType_standard => 'Standard';

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
  String get diveCenters_empty_button =>
      'Ajoutez votre premier centre de plongée';

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
  String get diveLog_combine_confirm => 'Combiner en une seule plongée';

  @override
  String get diveLog_combine_dataNote =>
      'Les détails proviennent de la plongée la plus ancienne, les champs vides étant complétés par les plongées suivantes. Les notes sont combinées. Les blocs, le matériel, les binômes, les tags et les observations sont tous conservés.';

  @override
  String get diveLog_combine_error =>
      'Impossible de combiner les plongées. Rien n\'a été modifié.';

  @override
  String diveLog_combine_gapLabel(String duration) {
    return 'Intervalle de surface : $duration';
  }

  @override
  String get diveLog_combine_longSurfaceWarning =>
      'Un ou plusieurs intervalles de surface dépassent 30 minutes. Il pourrait s\'agir de plongées distinctes plutôt que d\'une seule plongée continue.';

  @override
  String get diveLog_combine_mixedDivers =>
      'Les plongées sélectionnées appartiennent à des plongeurs différents et ne peuvent pas être combinées.';

  @override
  String get diveLog_combine_profilePreview => 'Profil combiné';

  @override
  String diveLog_combine_previewIntro(int count) {
    return 'Ces $count plongées seront combinées en une seule plongée continue. Les intervalles entre elles deviennent du temps de surface.';
  }

  @override
  String diveLog_combine_resultSummary(
    String runtime,
    String maxDepth,
    String bottomTime,
  ) {
    return 'Résultat : $runtime au total, profondeur max $maxDepth, temps au fond $bottomTime';
  }

  @override
  String diveLog_combine_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongées combinées',
      one: 'plongée combinée',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_combine_title => 'Combiner des plongées';

  @override
  String get diveLog_combine_undoError =>
      'Impossible d\'annuler la combinaison.';

  @override
  String get diveLog_combine_undone => 'Combinaison annulée';

  @override
  String get diveLog_computerSource_badge_primary => 'Principal';

  @override
  String get diveLog_consolidate_confirm =>
      'Conserver comme une seule plongée avec les deux ordinateurs';

  @override
  String get diveLog_consolidate_error_generic =>
      'Impossible de fusionner les plongées. Rien n\'a été modifié.';

  @override
  String get diveLog_consolidate_error_notOverlapping =>
      'Ces plongées ne se chevauchent pas dans le temps et ne peuvent donc pas être fusionnées en une seule plongée.';

  @override
  String get diveLog_consolidate_error_sameComputer =>
      'Ces plongées proviennent du même ordinateur de plongée et ne peuvent pas être fusionnées de cette façon.';

  @override
  String get diveLog_consolidate_selectPrimary =>
      'Ordinateur de plongée principal';

  @override
  String get diveLog_consolidate_snackbar =>
      'Plongée fusionnée en tant qu\'ordinateur supplémentaire.';

  @override
  String get diveLog_consolidate_undoError =>
      'Impossible d\'annuler la fusion.';

  @override
  String get diveLog_consolidate_undone => 'Fusion annulée';

  @override
  String diveLog_mergeDialog_confirmSubtitle(String time) {
    return 'La plongée de $time sera fusionnée avec cette plongée.';
  }

  @override
  String get diveLog_mergeDialog_confirmTitle => 'Confirmer la fusion';

  @override
  String get diveLog_mergeDialog_empty =>
      'Aucune autre plongée trouvée ce jour-là.';

  @override
  String get diveLog_mergeDialog_explanation =>
      'Le profil, les blocs, les pressions, les événements, les tags, les binômes et les observations de cette plongée seront intégrés à cette plongée en tant qu\'ordinateur supplémentaire. Cette action peut être annulée avec « Dissocier l\'ordinateur ».';

  @override
  String diveLog_mergeDialog_loadError(String error) {
    return 'Erreur lors du chargement des plongées : $error';
  }

  @override
  String get diveLog_mergeDialog_merge => 'Fusionner';

  @override
  String get diveLog_mergeDialog_next => 'Suivant';

  @override
  String get diveLog_mergeDialog_subtitle =>
      'Sélectionnez une plongée du même jour à fusionner en tant qu\'ordinateur supplémentaire.';

  @override
  String get diveLog_mergeDialog_title => 'Fusionner avec une autre plongée';

  @override
  String get diveLog_mergeDialog_whatThisDoes => 'Ce que cela fait';

  @override
  String get diveLog_computerSheet_description =>
      'Sélectionnez le profil d\'ordinateur à partir duquel modifier.';

  @override
  String get diveLog_computerSheet_title => 'Choisir le profil de départ';

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
  String get diveLog_deco_label_gf99 => 'GF99';

  @override
  String get diveLog_deco_label_surfGf => 'SurfGF';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_time => 'Temps';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String diveLog_deco_gf_chip(Object low, Object high) {
    return 'GF : $low/$high';
  }

  @override
  String diveLog_deco_gf_chipFromSettings(Object low, Object high) {
    return 'GF : $low/$high · vos réglages';
  }

  @override
  String diveLog_deco_gf_chipRecordedAlgorithm(
    Object algorithm,
    Object low,
    Object high,
  ) {
    return '$algorithm · analysé avec GF $low/$high';
  }

  @override
  String diveLog_deco_gf_semantics(Object low, Object high) {
    return 'Facteurs de gradient : bas $low, haut $high';
  }

  @override
  String get diveLog_deco_gf_tooltipFromSettings =>
      'Cet ordinateur de plongée n\'a pas enregistré ses facteurs de gradient ; cette plongée est donc analysée avec ceux de vos réglages.';

  @override
  String diveLog_deco_gf_tooltipRecordedAlgorithm(Object algorithm) {
    return 'Cette plongée a été calculée avec $algorithm, qui n\'utilise pas de facteurs de gradient. Submersion l\'analyse avec ceux de vos réglages.';
  }

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
  String get diveLog_deco_title => 'Statut deco';

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
  String get diveLog_detail_button_rangeAnalysis => 'Stats plage';

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
  String get diveLog_detail_label_serialNumber => 'Numero de serie';

  @override
  String get diveLog_detail_label_firmwareVersion => 'Version du firmware';

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
  String get diveLog_detail_section_decoStatus => 'Statut deco';

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
  String get diveLog_detail_section_sacRateBySegment =>
      'Consommation SAC par segment';

  @override
  String get diveLog_detail_section_tags => 'Tags';

  @override
  String get diveLog_detail_section_cylinders => 'Blocs';

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
  String get diveLog_detail_tideCalculated =>
      'Calcule a partir du modele de maree';

  @override
  String get diveLog_detail_tooltip_addToFavorites => 'Ajouter aux favoris';

  @override
  String get diveLog_detail_tooltip_edit => 'Modifier';

  @override
  String get diveLog_detail_tooltip_editDive => 'Modifier la plongee';

  @override
  String get diveLog_detail_tooltip_previousDive => 'Previous dive';

  @override
  String get diveLog_detail_tooltip_nextDive => 'Next dive';

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
  String get diveLog_diveMode_gaugeDescription =>
      'Profondeur et temps uniquement; aucun suivi du gaz ni de la décompression';

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
  String get diveLog_edit_group_buddies => 'Binômes';

  @override
  String get diveLog_edit_group_conditions => 'Conditions';

  @override
  String get diveLog_edit_group_experience => 'Expérience';

  @override
  String get diveLog_edit_group_gasGear => 'Gaz et matériel';

  @override
  String get diveLog_edit_group_theDive => 'La plongée';

  @override
  String get diveLog_edit_group_trip => 'Voyage';

  @override
  String get diveLog_edit_headerNew => 'Nouvelle plongee';

  @override
  String get diveLog_edit_invite_buddies => 'Ajouter des binômes';

  @override
  String get diveLog_edit_invite_conditions =>
      'Ajouter les conditions : eau, visibilité, météo';

  @override
  String get diveLog_edit_invite_experience =>
      'Ajouter note, observations, commentaires ou tags';

  @override
  String get diveLog_edit_invite_gasGear =>
      'Ajouter gaz et matériel : mode, blocs, équipement, lestage';

  @override
  String get diveLog_edit_invite_trip =>
      'Ajouter un voyage ou un centre de plongée';

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
  String get diveLog_edit_label_diveTypes => 'Types de plongée';

  @override
  String get diveLog_edit_label_diveNumber => 'No. de plongee';

  @override
  String get diveLog_edit_label_diveName => 'Nom';

  @override
  String get diveLog_edit_diveNamePlaceholder =>
      'Nom facultatif pour cette plongée';

  @override
  String get diveLog_edit_hint_diveNumber =>
      'Attribue automatiquement si laisse vide';

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
  String get diveLog_edit_overline_tanks => 'Blocs';

  @override
  String get diveLog_edit_profile_draw => 'Dessiner un profil';

  @override
  String get diveLog_edit_profile_none => 'Non enregistre';

  @override
  String diveLog_edit_profile_outliers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valeurs aberrantes potentielles detectees',
      one: '1 valeur aberrante potentielle detectee',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_profile_points(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_row_addSite => 'Ajouter un site';

  @override
  String get diveLog_edit_row_diveCenter => 'Centre de plongée';

  @override
  String get diveLog_edit_row_diveProfile => 'Profil de plongee';

  @override
  String get diveLog_edit_row_entry => 'Mise à l\'eau';

  @override
  String get diveLog_edit_row_exit => 'Sortie';

  @override
  String get diveLog_edit_row_notSet => 'Non défini';

  @override
  String get diveLog_edit_row_site => 'Site';

  @override
  String get diveLog_edit_row_surfaceInterval => 'Intervalle de surface';

  @override
  String get diveLog_edit_row_trip => 'Voyage';

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
  String diveLog_edit_snackbar_avgDepthCalculated(Object depth) {
    return 'Profondeur moyenne calculee : $depth';
  }

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Temps au fond calcule : $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Erreur lors de l\'enregistrement de la plongee : $error';
  }

  @override
  String diveLog_edit_snackbar_maxDepthCalculated(Object depth) {
    return 'Profondeur max calculee : $depth';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'Aucune donnee de profil de plongee disponible';

  @override
  String diveLog_edit_snackbar_runtimeCalculated(Object minutes) {
    return 'Duree calculee : $minutes min';
  }

  @override
  String get diveLog_edit_snackbar_unableToCalculateAvgDepth =>
      'Impossible de calculer la profondeur moyenne a partir du profil';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'Impossible de calculer le temps au fond a partir du profil';

  @override
  String get diveLog_edit_snackbar_unableToCalculateMaxDepth =>
      'Impossible de calculer la profondeur max a partir du profil';

  @override
  String get diveLog_edit_snackbar_unableToCalculateRuntime =>
      'Impossible de calculer la duree a partir du profil';

  @override
  String diveLog_edit_summary_items(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_summary_notes => 'commentaires';

  @override
  String diveLog_edit_summary_species(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count espèces',
      one: '1 espèce',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_summary_tanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocs',
      one: '1 bloc',
    );
    return '$_temp0';
  }

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
  String get diveLog_edit_tankCard_done => 'Terminé';

  @override
  String get diveLog_edit_tankCard_edit => 'Modifier';

  @override
  String get diveLog_edit_tankCard_mix => 'Mélange';

  @override
  String get diveLog_edit_tankCard_pressure => 'Pression';

  @override
  String diveLog_edit_tankCard_title(int number) {
    return 'Bloc $number';
  }

  @override
  String get diveLog_edit_tankCard_volume => 'Volume';

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
  String diveLog_equipmentSetPicker_itemsSummary(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0 : $names';
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
  String get diveLog_filterChip_noBuddy => 'Sans binome';

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
  String get diveLog_filter_clearWeekdays => 'Effacer les jours de la semaine';

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
  String get diveLog_filter_noBuddyOnly => 'Aucun binome assigne';

  @override
  String get diveLog_filter_noTagsYet => 'Aucun tag cree pour le moment';

  @override
  String get diveLog_filter_presetAllTime => 'Toute la période';

  @override
  String get diveLog_filter_presetLast12Months => '12 derniers mois';

  @override
  String get diveLog_filter_presetLastYear => 'Année dernière';

  @override
  String get diveLog_filter_presetThisYear => 'Cette année';

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
  String get diveLog_filter_sectionWeekdays => 'Jours de la semaine';

  @override
  String get diveLog_filter_showOnlyFavorites =>
      'Afficher uniquement les plongees favorites';

  @override
  String get diveLog_filter_showOnlyNoBuddy =>
      'Afficher uniquement les plongees sans binome';

  @override
  String get diveLog_filter_startDate => 'Date de debut';

  @override
  String get diveLog_filter_title => 'Filtrer les plongees';

  @override
  String get diveLog_filter_resizeGrip =>
      'Redimensionner le panneau de filtres';

  @override
  String get diveLog_filter_tooltip_close => 'Fermer le filtre';

  @override
  String get diveLog_fullscreenProfile_close => 'Fermer le plein ecran';

  @override
  String get diveLog_fullscreenProfile_readoutHint =>
      'Survolez ou faites glisser sur le profil';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Profil de la plongee n$number';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Vitesse de remontee';

  @override
  String get diveLog_legend_label_ascentRateLine =>
      'Courbe de vitesse de remontee';

  @override
  String get diveLog_legend_label_ceiling => 'Plafond';

  @override
  String get diveLog_legend_label_decoStops => 'Deco stops';

  @override
  String get diveLog_legend_label_cns => 'CNS%';

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
  String get diveLog_legend_label_otu => 'OTU';

  @override
  String get diveLog_legend_label_photoMarkers => 'Photos';

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
  String get diveLog_legend_label_showGas => 'Gaz';

  @override
  String get diveLog_legend_label_surfaceGf => 'GF surface';

  @override
  String get diveLog_legend_label_temp => 'Temp';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_legend_source_dc => 'DC';

  @override
  String get diveLog_legend_source_calc => 'Calc.';

  @override
  String get diveLog_chartSection_overlays => 'Superpositions';

  @override
  String get diveLog_chartSection_markers => 'Marqueurs';

  @override
  String get diveLog_chartSection_decompression => 'Decompression';

  @override
  String get diveLog_chartSection_gasAnalysis => 'Analyse des gaz';

  @override
  String get diveLog_chartSection_display => 'Affichage';

  @override
  String get diveLog_chartSection_other => 'Autre';

  @override
  String get diveLog_chartSection_tankPressures => 'Pressions des blocs';

  @override
  String get diveLog_chartOption_metricsFollowViewport =>
      'Garder les superpositions visibles';

  @override
  String get diveLog_pressure_estimatedSuffix => '(est.)';

  @override
  String get diveLog_listPage_appBar_diveMap => 'Carte des plongees';

  @override
  String get diveLog_listPage_compactTitle => 'Plongees';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get diveLog_listPage_bottomSheet_importFromComputer =>
      'Importer depuis l\'ordinateur';

  @override
  String get diveLog_listPage_bottomSheet_scanPaperLog =>
      'Scanner un carnet papier';

  @override
  String get ocrImport_scanPage_processing => 'Lecture de la page...';

  @override
  String get ocrImport_scanPage_pickPhoto => 'Choisir une photo';

  @override
  String get ocrImport_scanPage_takePhoto => 'Prendre une photo';

  @override
  String get ocrImport_scanPage_nothingRead =>
      'Peu de texte lisible sur cette page - champs laissés vides';

  @override
  String get ocrImport_scanPage_engineMissing =>
      'La reconnaissance de texte n\'est pas disponible. Installez Tesseract pour scanner les carnets papier (par exemple : sudo apt install tesseract-ocr).';

  @override
  String get ocrImport_editPage_photoAttachFailed =>
      'La plongée a été enregistrée, mais l\'ajout de la page scannée a échoué';

  @override
  String get diveLog_listPage_bottomSheet_logManually =>
      'Enregistrer manuellement';

  @override
  String get diveLog_listPage_fab_addDive => 'Ajouter une plongee';

  @override
  String get diveLog_listPage_fab_logDive => 'Enregistrer';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'Recherche avancee';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'Numerotation des plongees';

  @override
  String get diveLog_listPage_menuMatchSites =>
      'Associer les plongées aux sites';

  @override
  String get diveLog_sighting_decreaseCount => 'Diminuer le nombre';

  @override
  String get diveLog_sighting_increaseCount => 'Augmenter le nombre';

  @override
  String diveLog_speciesPicker_errorLoading(String error) {
    return 'Erreur de chargement des espèces : $error';
  }

  @override
  String get diveRole_builtin_buddy => 'Binôme';

  @override
  String get diveRole_builtin_diveGuide => 'Guide de plongée';

  @override
  String get diveRole_builtin_diveMaster => 'Directeur de plongée';

  @override
  String get diveRole_builtin_instructor => 'Moniteur';

  @override
  String get diveRole_builtin_rearGuard => 'Serre-file';

  @override
  String get diveRole_builtin_safetyDiver => 'Plongeur de sécurité';

  @override
  String get diveRole_builtin_solo => 'Solo';

  @override
  String get diveRole_builtin_student => 'Élève';

  @override
  String get diveRole_builtin_supportDiver => 'Plongeur de soutien';

  @override
  String get diveRoles_addDialog_addButton => 'Ajouter';

  @override
  String get diveRoles_addDialog_nameHint => 'ex. Photographe';

  @override
  String get diveRoles_addDialog_nameLabel => 'Nom du rôle de plongée';

  @override
  String get diveRoles_addDialog_nameValidation => 'Veuillez entrer un nom';

  @override
  String get diveRoles_addDialog_title =>
      'Ajouter un rôle de plongée personnalisé';

  @override
  String get diveRoles_addTooltip => 'Ajouter un rôle de plongée';

  @override
  String get diveRoles_appBar_title => 'Rôles de plongée';

  @override
  String get diveRoles_builtInHeader => 'Rôles de plongée intégrés';

  @override
  String get diveRoles_customHeader => 'Rôles de plongée personnalisés';

  @override
  String diveRoles_deleteDialog_content(Object name) {
    return 'Voulez-vous vraiment supprimer « $name » ?';
  }

  @override
  String get diveRoles_deleteDialog_title => 'Supprimer le rôle de plongée ?';

  @override
  String get diveRoles_deleteTooltip => 'Supprimer le rôle de plongée';

  @override
  String get diveRoles_renameDialog_title => 'Renommer le rôle de plongée';

  @override
  String get diveRoles_renameTooltip => 'Renommer le rôle de plongée';

  @override
  String diveRoles_snackbar_added(Object name) {
    return 'Rôle de plongée ajouté : $name';
  }

  @override
  String diveRoles_snackbar_cannotDelete(Object name) {
    return 'Impossible de supprimer « $name » - il est utilisé par des plongées existantes';
  }

  @override
  String diveRoles_snackbar_deleted(Object name) {
    return 'Rôle de plongée supprimé : $name';
  }

  @override
  String diveRoles_snackbar_errorAdding(Object error) {
    return 'Erreur lors de l\'ajout du rôle de plongée : $error';
  }

  @override
  String get diveSites_edit_depth_heroMax => 'Prof. max';

  @override
  String get diveSites_edit_depth_heroMin => 'Prof. min';

  @override
  String get diveSites_edit_group_accessSafety => 'Accès et sécurité';

  @override
  String get diveSites_edit_group_diveInfo => 'Infos plongée';

  @override
  String get diveSites_edit_group_identity => 'Identité';

  @override
  String get diveSites_edit_group_lifeNotes => 'Vie marine et notes';

  @override
  String get diveSites_edit_group_location => 'Position';

  @override
  String get diveSites_edit_invite_accessSafety =>
      'Ajouter accès, parking, mouillage ou dangers';

  @override
  String get diveSites_edit_invite_diveInfo =>
      'Ajouter profondeurs, difficulté ou note';

  @override
  String get diveSites_edit_invite_lifeNotes =>
      'Ajouter vie marine, notes ou partage';

  @override
  String get diveSites_edit_invite_location =>
      'Ajouter une position GPS ou une altitude';

  @override
  String get diveSites_edit_summary_shared => 'partagé';

  @override
  String get forms_addSection_prefix => 'Ajouter :';

  @override
  String get forms_cancel => 'Annuler';

  @override
  String get forms_discard_body =>
      'Vous avez des modifications non enregistrées. Si vous quittez maintenant, elles seront perdues.';

  @override
  String get forms_discard_discard => 'Abandonner';

  @override
  String get forms_discard_keepEditing => 'Continuer la modification';

  @override
  String get forms_discard_title => 'Abandonner les modifications ?';

  @override
  String get forms_save => 'Enregistrer';

  @override
  String forms_section_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problèmes',
      one: '1 problème',
    );
    return '$_temp0';
  }

  @override
  String get settings_manage_setupAssistant => 'Assistant de configuration';

  @override
  String get settings_manage_setupAssistant_subtitle =>
      'Revoir les unités, l\'apparence et les choix de sauvegarde';

  @override
  String get setup_backup_cloudCopy => 'Stocker les sauvegardes dans le cloud';

  @override
  String get setup_backup_frequency => 'Fréquence';

  @override
  String get setup_backup_frequency_daily => 'Quotidienne';

  @override
  String get setup_backup_frequency_monthly => 'Mensuelle';

  @override
  String get setup_backup_frequency_weekly => 'Hebdomadaire';

  @override
  String get setup_backup_scheduleSubtitle =>
      'Sauvegardez vos données selon un calendrier';

  @override
  String get setup_backup_scheduleToggle => 'Sauvegardes automatiques';

  @override
  String get setup_backup_subtitle =>
      'Protégez vos données dès le premier jour.';

  @override
  String get setup_backup_title => 'Sauvegardes et synchronisation';

  @override
  String get setup_common_back => 'Retour';

  @override
  String get setup_common_next => 'Suivant';

  @override
  String get setup_common_skip => 'Ignorer';

  @override
  String get setup_existing_folder_subtitle =>
      'Pointez Submersion vers un dossier contenant déjà une bibliothèque';

  @override
  String get setup_existing_folder_title => 'Ouvrir un dossier existant';

  @override
  String get setup_existing_restore_subtitle =>
      'Choisissez un fichier de sauvegarde exporté depuis Submersion';

  @override
  String get setup_existing_restore_title =>
      'Restaurer un fichier de sauvegarde';

  @override
  String get setup_existing_subtitle =>
      'Choisissez comment charger votre bibliothèque Submersion existante';

  @override
  String get setup_existing_sync_subtitle =>
      'Récupérez votre bibliothèque depuis iCloud, Dropbox ou S3';

  @override
  String get setup_existing_sync_title => 'Connecter la synchronisation cloud';

  @override
  String get setup_existing_title => 'Récupérez vos données';

  @override
  String get setup_finish_applying => 'Configuration...';

  @override
  String setup_finish_error(Object error) {
    return 'Impossible de terminer la configuration : $error';
  }

  @override
  String get setup_finish_feature_diveComputer =>
      'Téléchargez vos plongées depuis votre ordinateur de plongée';

  @override
  String get setup_finish_feature_gear =>
      'Suivez votre matériel et ses entretiens';

  @override
  String get setup_finish_feature_import =>
      'Importez des carnets depuis des fichiers et d\'autres applications';

  @override
  String get setup_finish_feature_sites => 'Cartographiez vos sites de plongée';

  @override
  String get setup_finish_feature_statistics =>
      'Explorez les statistiques de vos plongées';

  @override
  String get setup_finish_start => 'Commencer';

  @override
  String get setup_finish_subtitle => 'Submersion peut aussi...';

  @override
  String get setup_finish_title => 'Tout est prêt';

  @override
  String get setup_folder_notFound_message =>
      'Le dossier sélectionné ne contient pas de base de données Submersion.';

  @override
  String get setup_folder_notFound_title =>
      'Aucune bibliothèque dans ce dossier';

  @override
  String get setup_folder_pick => 'Choisir un dossier';

  @override
  String get setup_folder_switching => 'Ouverture de la bibliothèque...';

  @override
  String get setup_folder_title => 'Ouvrir un dossier existant';

  @override
  String get setup_profile_nameHint => 'Entrez votre nom';

  @override
  String get setup_profile_nameLabel => 'Votre nom';

  @override
  String get setup_profile_nameValidation => 'Veuillez entrer votre nom';

  @override
  String get setup_profile_subtitle =>
      'Entrez votre nom pour commencer. Vous pourrez ajouter plus de détails plus tard.';

  @override
  String get setup_profile_title => 'Créer votre profil';

  @override
  String get setup_restore_inProgress => 'Restauration...';

  @override
  String get setup_restore_pick => 'Choisir un fichier de sauvegarde';

  @override
  String get setup_restore_title => 'Restaurer la sauvegarde';

  @override
  String get setup_step_backup => 'Sauvegarde';

  @override
  String get setup_step_finish => 'Terminé';

  @override
  String get setup_step_profile => 'Profil';

  @override
  String get setup_step_units => 'Unités';

  @override
  String get setup_syncPull_continue => 'Continuer';

  @override
  String get setup_syncPull_incomplete_message =>
      'Ce compte contient une bibliothèque Submersion dont l\'envoi n\'a jamais été terminé. Laissez votre autre appareil finir la synchronisation, puis réessayez.';

  @override
  String get setup_syncPull_incomplete_retry => 'Vérifier à nouveau';

  @override
  String get setup_syncPull_incomplete_title =>
      'Envoi de la bibliothèque inachevé';

  @override
  String get setup_syncPull_locked_message =>
      'Saisissez la phrase secrète de chiffrement pour déverrouiller cette bibliothèque et la télécharger sur cet appareil.';

  @override
  String get setup_syncPull_locked_title => 'Cette bibliothèque est chiffrée';

  @override
  String get setup_syncPull_noLibrary_message =>
      'Aucune bibliothèque Submersion n\'a été trouvée sur ce compte. Repartir de zéro ? Votre connexion sera conservée.';

  @override
  String get setup_syncPull_noLibrary_title => 'Aucune bibliothèque trouvée';

  @override
  String get setup_syncPull_success => 'Bibliothèque adoptée';

  @override
  String get setup_syncPull_syncing => 'Récupération de votre bibliothèque...';

  @override
  String get setup_syncPull_title => 'Connecter et récupérer';

  @override
  String get setup_sync_changeProvider => 'Changer de fournisseur';

  @override
  String setup_sync_connectedTo(String provider) {
    return 'Connecté à $provider';
  }

  @override
  String setup_sync_error(Object error) {
    return 'Connexion impossible : $error';
  }

  @override
  String get setup_sync_header => 'Synchronisation cloud';

  @override
  String get setup_sync_libraryFound_adopt =>
      'Adopter la bibliothèque existante';

  @override
  String get setup_sync_libraryFound_keepFresh => 'Repartir de zéro';

  @override
  String get setup_sync_libraryFound_message =>
      'Ce compte contient déjà une bibliothèque Submersion. L\'adopter plutôt que de repartir de zéro ?';

  @override
  String get setup_sync_libraryFound_title => 'Bibliothèque existante trouvée';

  @override
  String get setup_sync_manageInSettings => 'Gérer dans les réglages';

  @override
  String get setup_sync_notConnected => 'Non connecté';

  @override
  String get setup_sync_subtitle =>
      'Synchronisez vos données entre vos appareils';

  @override
  String get setup_units_advanced => 'Ajuster les unités';

  @override
  String get setup_units_altitude => 'Altitude';

  @override
  String get setup_units_dateFormat => 'Format de date';

  @override
  String get setup_units_depth => 'Profondeur';

  @override
  String get setup_units_imperial => 'Impérial';

  @override
  String get setup_units_metric => 'Métrique';

  @override
  String get setup_units_pressure => 'Pression';

  @override
  String get setup_units_sac => 'Taux SAC';

  @override
  String get setup_units_subtitle =>
      'Choisissez l\'affichage des mesures. Chaque unité peut être ajustée.';

  @override
  String get setup_units_temperature => 'Température';

  @override
  String get setup_units_timeFormat => 'Format de l\'heure';

  @override
  String get setup_units_title => 'Unités';

  @override
  String get setup_units_volume => 'Volume';

  @override
  String get setup_units_weight => 'Poids';

  @override
  String get setup_welcome_existingData_subtitle =>
      'Restaurez une sauvegarde, connectez la synchronisation ou ouvrez un dossier existant';

  @override
  String get setup_welcome_existingData_title =>
      'J\'ai déjà des données Submersion';

  @override
  String get setup_welcome_skipSetup => 'Ignorer la configuration';

  @override
  String get setup_welcome_startFresh_subtitle =>
      'Créez votre profil de plongeur et configurez l\'application';

  @override
  String get setup_welcome_startFresh_title => 'Créer un nouveau profil';

  @override
  String get setup_welcome_subtitle =>
      'Enregistrement et analyse avancés de plongée';

  @override
  String get setup_welcome_title => 'Bienvenue dans Submersion';

  @override
  String get siteMatchReview_title => 'Associer les sites';

  @override
  String siteMatchReview_diveNumber(Object number) {
    return 'Plongee n°$number';
  }

  @override
  String get siteMatchReview_empty => 'Rien à associer.';

  @override
  String siteMatchReview_summary(int selected, int review, int none) {
    return '$selected sélectionnées · $review à vérifier · $none sans correspondance';
  }

  @override
  String siteMatchReview_confirm(int count) {
    return 'Confirmer $count associations';
  }

  @override
  String get siteMatchReview_cancel => 'Annuler';

  @override
  String get siteMatchReview_tapToChoose => 'Appuyez pour choisir un site';

  @override
  String siteMatchReview_awayMeters(int meters) {
    return 'à $meters m';
  }

  @override
  String siteMatchReview_depthTo(int meters) {
    return 'jusqu\'à $meters m';
  }

  @override
  String siteMatchReview_depthRange(int min, int max) {
    return '$min–$max m';
  }

  @override
  String siteMatchReview_appliedSnack(int dives, int sites) {
    return '$dives plongées associées · $sites sites ajoutés';
  }

  @override
  String get siteMatchReview_applyError =>
      'Impossible d\'appliquer les associations';

  @override
  String get siteMatchReview_discardTitle => 'Abandonner les associations ?';

  @override
  String get siteMatchReview_discardMessage =>
      'Votre sélection ne sera pas enregistrée.';

  @override
  String get siteMatchReview_discardConfirm => 'Abandonner';

  @override
  String get siteMatchReview_keepReviewing => 'Continuer la vérification';

  @override
  String get siteMatchReview_sourceExisting => 'votre site';

  @override
  String get siteMatchReview_sourceBundled => 'import';

  @override
  String get siteMatchReview_noNearbySite => 'Aucun site à proximité';

  @override
  String importSummary_matchSitesButton(int count) {
    return 'Associer $count plongées aux sites';
  }

  @override
  String get diveLog_listPage_searchFieldLabel => 'Rechercher des plongees...';

  @override
  String diveLog_listPage_searchLimitNotice(int limit) {
    return 'Affichage des $limit premières correspondances. Affinez votre recherche pour réduire les résultats.';
  }

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
  String get diveLog_profile_semantics_photoMarker => 'Marqueur de photo';

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
  String get diveLog_rangeStats_title => 'Stats plage';

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
  String get diveLog_search_filter_any => 'Indifférent';

  @override
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

  @override
  String get diveLog_search_label_deco => 'Décompression';

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
  String get diveLog_selection_tooltip_combine => 'Combiner';

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
  String get diveLog_selection_tooltip_selectDateRange =>
      'Sélectionner par plage de dates';

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
  String diveLog_sitePicker_distanceAway(String distance) {
    return 'à $distance';
  }

  @override
  String get diveLog_sitePicker_sortedByDiveDistance =>
      'Trié par distance à cette plongée';

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
  String get diveLog_tank_mndHelper =>
      'Regler pour calculer automatiquement He%';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'PMU : $depth (ppO₂ 1.4)';
  }

  @override
  String diveLog_tank_modMndInfo(Object mod, Object mnd) {
    return 'PMU : $mod (ppO₂ 1.4) | PNM : $mnd';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Melange gazeux';

  @override
  String get diveLog_tank_selectPreset => 'Selectionner un preset...';

  @override
  String get diveLog_tank_saveAsPreset => 'Enregistrer comme preset';

  @override
  String get diveLog_tank_saveAsPreset_needSpecs =>
      'Saisissez d\'abord un volume et une pression de service';

  @override
  String get diveLog_tank_saveAsPreset_nameTitle =>
      'Enregistrer le preset de bloc';

  @override
  String get diveLog_tank_saveAsPreset_nameHint => 'p. ex. Mon AL80';

  @override
  String diveLog_tank_saveAsPreset_saved(String name) {
    return 'Preset \"$name\" enregistré';
  }

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
  String get diveLog_tooltip_avgCalculated => '(moy., calculé)';

  @override
  String get diveLog_tooltip_ceiling => 'Plafond';

  @override
  String get diveLog_tooltip_decoStop => 'Deco stop';

  @override
  String get diveLog_tooltip_cns => 'CNS';

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
  String get diveLog_tooltip_otu => 'OTU';

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
  String get diveLog_tooltip_sensor => 'Capteur';

  @override
  String get diveLog_legend_label_o2Cells => 'Cellules O2';

  @override
  String get diveLog_tooltip_o2CellsTight => 'serrée';

  @override
  String get diveLog_tooltip_o2CellsDrifting => 'en dérive';

  @override
  String get diveLog_tooltip_o2CellsWide => 'large';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Temp';

  @override
  String get diveLog_tooltip_time => 'Temps';

  @override
  String get diveLog_tooltip_tts => 'TDR';

  @override
  String get diveLog_sources_row_metric => 'Mesure';

  @override
  String get diveLog_sources_row_maxDepth => 'Prof. max';

  @override
  String get diveLog_sources_row_avgDepth => 'Prof. moy.';

  @override
  String get diveLog_sources_row_duration => 'Durée';

  @override
  String get diveLog_sources_row_waterTemp => 'Temp. eau';

  @override
  String get diveLog_sources_row_cns => 'CNS';

  @override
  String get diveLog_sources_row_otu => 'OTU';

  @override
  String get diveLog_sources_row_decoAlgorithm => 'Algorithme déco';

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
  String get diveLog_sources_unknownComputer => 'Ordinateur inconnu';

  @override
  String get diveLog_sources_manualEntry => 'Saisie manuelle';

  @override
  String get diveLog_sources_importedFile => 'Fichier importé';

  @override
  String get diveLog_sources_editedSuffix => ' (modifié)';

  @override
  String get diveLog_sources_barLabel => 'SOURCES';

  @override
  String get diveLog_sources_menu_setPrimary => 'Définir comme principal';

  @override
  String get diveLog_sources_menu_split => 'Scinder en une plongée séparée';

  @override
  String get diveLog_sources_overlayTooltip => 'Superposer sur le graphique';

  @override
  String get diveLog_sources_splitDialog_title =>
      'Scinder en une plongée séparée ?';

  @override
  String get diveLog_sources_splitDialog_body =>
      'Le profil, les événements et les blocs de cette source seront déplacés vers une nouvelle plongée. L\'entrée du carnet reste sur cette plongée.';

  @override
  String get diveLog_sources_splitDialog_confirm => 'Scinder';

  @override
  String get diveLog_sources_splitDone => 'Plongée scindée';

  @override
  String get diveLog_sources_splitFailed => 'Échec de la scission';

  @override
  String get divePlanner_action_addTank => 'Ajouter une bouteille';

  @override
  String get divePlanner_action_convertToDive => 'Convertir en plongée';

  @override
  String get divePlanner_action_deletePlan => 'Supprimer le plan';

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
  String get divePlanner_error_reserveExceedsTank =>
      'Dépasse la pression du bloc';

  @override
  String get divePlanner_error_reserveMustBePositive =>
      'Doit être supérieur à 0';

  @override
  String divePlanner_info_reserveDefault(Object unit, Object value) {
    return 'Non saisi — valeur par défaut $value $unit';
  }

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
  String get divePlanner_field_travelGas =>
      'Également utilisé comme gaz de voyage';

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
  String get divePlanner_label_reserve => 'Réserve :';

  @override
  String get divePlanner_label_runtime => 'Durée totale';

  @override
  String get divePlanner_label_sacRate => 'RMV :';

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
  String divePlanner_message_deleteConfirmation(String name) {
    return 'Supprimer \'$name\' ?';
  }

  @override
  String get divePlanner_message_planDeleted => 'Plan supprimé';

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
  String get diveSites_detail_location_city => 'Ville';

  @override
  String get diveSites_detail_location_island => 'Île';

  @override
  String get diveSites_detail_location_bodyOfWater => 'Plan d\'eau';

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
  String get diveSites_edit_access_entryMethod_label => 'Méthode d\'entrée';

  @override
  String get diveSites_edit_access_exitMethod_label => 'Méthode de sortie';

  @override
  String diveSites_edit_access_entrySuggestionPair(
    int count,
    String entry,
    String exit,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vos $count plongées ici : entrée $entry, sortie $exit',
      one: 'Votre plongée ici : entrée $entry, sortie $exit',
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
      other: 'Vos $count plongées ici : entrée $entry',
      one: 'Votre plongée ici : entrée $entry',
    );
    return '$_temp0';
  }

  @override
  String get diveSites_detail_access_entryMethod => 'Entrée';

  @override
  String get diveSites_detail_access_exitMethod => 'Sortie';

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
  String get diveSites_edit_appBar_merge => 'Fusionner';

  @override
  String get diveSites_edit_appBar_mergeSites =>
      'Fusionner les sites de plongée';

  @override
  String get diveSites_edit_appBar_newSite => 'Nouveau site';

  @override
  String get diveSites_edit_appBar_save => 'Enregistrer';

  @override
  String get diveSites_edit_button_addSite => 'Ajouter le site';

  @override
  String get diveSites_edit_button_mergeSites =>
      'Fusionner les sites de plongée';

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
  String get diveSites_edit_field_city_label => 'Ville';

  @override
  String get diveSites_edit_field_island_label => 'Île';

  @override
  String get diveSites_edit_field_bodyOfWater_label => 'Plan d\'eau';

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
  String diveSites_similarSite_useHint(Object siteName) {
    return 'Similaire à un site de plongée existant « $siteName ». Appuyez pour l\'utiliser.';
  }

  @override
  String diveSites_similarSite_warning(Object siteName) {
    return 'Un site similaire existe déjà : « $siteName »';
  }

  @override
  String get diveSites_edit_gps_gettingLocation => 'Obtention...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Choisissez une méthode de localisation ou recherchez les coordonnées pour remplir le pays, la région, la ville et le plan d\'eau';

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
  String get diveSites_edit_gps_lookupFromCoordinates =>
      'Rechercher depuis les coordonnées';

  @override
  String get diveSites_edit_snackbar_lookupNothingFound =>
      'Aucune information de lieu trouvée pour ces coordonnées';

  @override
  String get diveSites_edit_snackbar_lookupFailed =>
      'La recherche de lieu a échoué. Vérifiez votre connexion et réessayez.';

  @override
  String get diveSites_edit_lookupReplace_title =>
      'Remplacer les informations de lieu ?';

  @override
  String get diveSites_edit_lookupReplace_body =>
      'La recherche a trouvé des valeurs différentes pour ces champs :';

  @override
  String get diveSites_edit_lookupReplace_replace => 'Remplacer';

  @override
  String get diveSites_edit_lookupReplace_keep => 'Conserver';

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
  String diveSites_edit_merge_confirmBody(int count) {
    return 'Cela fusionnera $count sites en un seul. Les plongées, les médias et les espèces attendues seront regroupés sous le site conservé. Les autres sites seront supprimés.';
  }

  @override
  String get diveSites_edit_merge_confirmTitle =>
      'Fusionner les sites de plongée';

  @override
  String get diveSites_edit_merge_fieldSourceCycleTooltip =>
      'Utiliser la valeur du prochain site sélectionné';

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
      'Sélectionner la valeur du site sélectionné';

  @override
  String get diveSites_edit_merge_marineLifeHelperText =>
      'Combiné à partir de tous les sites sélectionnés';

  @override
  String diveSites_edit_merge_loadingErrorBody(Object error) {
    return 'Échec du chargement des sites : $error';
  }

  @override
  String get diveSites_edit_merge_loadingErrorTitle =>
      'Fusionner les sites de plongée';

  @override
  String get diveSites_edit_merge_notEnoughBody =>
      'Pas assez de sites à fusionner.';

  @override
  String get diveSites_edit_merge_notEnoughTitle =>
      'Fusionner les sites de plongée';

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
  String get diveSites_edit_section_waterType => 'Type d\'eau';

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
  String get diveSites_edit_snackbar_sitesMerged =>
      'Sites de plongée fusionnés';

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
    return '$min-$max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'Jusqu\'à $max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '$min+';
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
  String get diveSites_list_merge_restored => 'Fusion annulee';

  @override
  String diveSites_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sites fusionnes',
      one: 'site fusionne',
    );
    return '$count $_temp0';
  }

  @override
  String get diveSites_list_merge_undo => 'Annuler';

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
  String get diveSites_list_menu_select => 'Sélectionner des sites';

  @override
  String get diveSites_list_menu_fillLocationDetails =>
      'Compléter les informations de lieu manquantes';

  @override
  String get diveSites_backfill_confirm_title =>
      'Compléter les informations de lieu manquantes ?';

  @override
  String diveSites_backfill_confirm_body(int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count sites avec coordonnées n\'ont pas de pays, de région, de ville ou de plan d\'eau.',
      one:
          '1 site avec coordonnées n\'a pas de pays, de région, de ville ou de plan d\'eau.',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0 Submersion recherchera chacun sur OpenStreetMap et ne remplira que les champs vides. Cela prend environ $_temp1.';
  }

  @override
  String get diveSites_backfill_confirm_start => 'Démarrer';

  @override
  String get diveSites_backfill_nothingToFill =>
      'Tous les sites avec coordonnées ont déjà leurs informations de lieu.';

  @override
  String get diveSites_backfill_progress_title =>
      'Complément des informations de lieu';

  @override
  String diveSites_backfill_progress_count(int done, int total) {
    return '$done sur $total';
  }

  @override
  String get diveSites_backfill_cancel => 'Annuler';

  @override
  String diveSites_backfill_summary(int updated, int unchanged, int failed) {
    return 'Mis à jour $updated, inchangés $unchanged, échoués $failed';
  }

  @override
  String get diveSites_backfill_offline =>
      'La recherche de lieu est indisponible. Vérifiez votre connexion et réessayez.';

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
  String get diveSites_list_selection_mergeTooltip => 'Fusionner la sélection';

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
  String get diveSites_map_builtInSites_add => 'Ajouter à mes sites';

  @override
  String get diveSites_map_builtInSites_addError =>
      'Impossible d\'ajouter le site. Veuillez réessayer.';

  @override
  String get diveSites_map_builtInSites_added => 'Ajouté à vos sites';

  @override
  String get diveSites_map_builtInSites_hide => 'Masquer les sites intégrés';

  @override
  String get diveSites_map_builtInSites_off => 'Sites intégrés masqués';

  @override
  String get diveSites_map_builtInSites_on => 'Sites intégrés affichés';

  @override
  String get diveSites_map_builtInSites_show => 'Afficher les sites intégrés';

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
  String diveSites_map_semantics_builtInSiteMarker(Object name) {
    return 'Site de plongée intégré : $name';
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
  String get diveType_builtin_altitude => 'Altitude';

  @override
  String get diveType_builtin_boat => 'Depuis un bateau';

  @override
  String get diveType_builtin_cave => 'Grotte';

  @override
  String get diveType_builtin_cavern => 'Caverne';

  @override
  String get diveType_builtin_deep => 'Profonde';

  @override
  String get diveType_builtin_drift => 'Dérive';

  @override
  String get diveType_builtin_freedive => 'Apnée';

  @override
  String get diveType_builtin_ice => 'Sous glace';

  @override
  String get diveType_builtin_liveaboard => 'Croisière plongée';

  @override
  String get diveType_builtin_night => 'Nuit';

  @override
  String get diveType_builtin_recreational => 'Loisir';

  @override
  String get diveType_builtin_shore => 'Depuis la côte';

  @override
  String get diveType_builtin_technical => 'Technique';

  @override
  String get diveType_builtin_training => 'Formation';

  @override
  String get diveType_builtin_wreck => 'Épave';

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
    return 'This will permanently delete $name and all associated data including dive logs, dive computers, equipment, certifications, and sites.';
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
  String divers_detail_deleteDialogConfirmHint(String name) {
    return 'Type \"Delete $name\" to confirm';
  }

  @override
  String divers_detail_deleteDialogConfirmText(String name) {
    return 'Delete $name';
  }

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
  String get enum_certificationLevel_diveGuide => 'Guide de plongée';

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
  String get enum_diveMode_gauge => 'Profondimètre';

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
  String get enum_equipmentType_dpv => 'DPV';

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
  String get enum_sortField_dateTaken => 'Date de prise de vue';

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
  String get enum_sortField_fileName => 'Nom du fichier';

  @override
  String get enum_sortField_fileSize => 'Taille du fichier';

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
  String get equipment_serviceClocks_title => 'Compteurs d\'entretien';

  @override
  String get equipment_serviceClocks_addClock => 'Ajouter un compteur';

  @override
  String get equipment_serviceClocks_logService => 'Enregistrer un entretien';

  @override
  String get equipment_serviceClocks_edit => 'Modifier les intervalles';

  @override
  String get equipment_serviceClocks_pause => 'Suspendre';

  @override
  String get equipment_serviceClocks_resume => 'Reprendre';

  @override
  String get equipment_serviceClocks_remove => 'Supprimer';

  @override
  String get equipment_serviceClocks_paused => 'Suspendu';

  @override
  String get equipment_serviceClocks_empty => 'Aucun compteur d\'entretien';

  @override
  String get equipment_serviceClocks_unconfigured =>
      'Aucun intervalle défini - appuyez pour configurer';

  @override
  String equipment_serviceClocks_dueOn(String date) {
    return 'Échéance le $date';
  }

  @override
  String equipment_serviceClocks_overdueSince(String date) {
    return 'En retard depuis le $date';
  }

  @override
  String get equipment_serviceClocks_overdue => 'En retard';

  @override
  String equipment_serviceClocks_divesLeft(int remaining, int total) {
    return '$remaining plongées restantes sur $total';
  }

  @override
  String get cylinderConfigs_title => 'Configurations de bouteilles';

  @override
  String get cylinderConfigs_empty => 'Aucune configuration';

  @override
  String get cylinderConfigs_emptyBody =>
      'Enregistrez un montage diluant et bailout une fois, puis appliquez-le à n\'importe quelle plongée.';

  @override
  String get cylinderConfigs_new => 'Nouvelle configuration';

  @override
  String get cylinderConfigs_name => 'Nom';

  @override
  String get cylinderConfigs_nameRequired => 'Saisissez un nom';

  @override
  String get cylinderConfigs_forUnit => 'Pour l\'appareil';

  @override
  String get cylinderConfigs_noUnit => 'Plan de gaz générique';

  @override
  String get cylinderConfigs_gasPlans => 'Plans de gaz';

  @override
  String get cylinderConfigs_addCylinder => 'Ajouter une bouteille';

  @override
  String get cylinderConfigs_role => 'Rôle';

  @override
  String get cylinderConfigs_startPressure => 'Pression de départ';

  @override
  String get cylinderConfigs_label => 'Libellé';

  @override
  String get cylinderConfigs_fromPreset => 'Depuis un préréglage';

  @override
  String get cylinderConfigs_deleteTitle => 'Supprimer la configuration ?';

  @override
  String get cylinderConfigs_deleteBody =>
      'Les plongées déjà concernées ne sont pas modifiées.';

  @override
  String get cylinderConfigs_applyAction => 'Appliquer une configuration';

  @override
  String cylinderConfigs_applyAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bouteilles ajoutées',
      one: '1 bouteille ajoutée',
    );
    return '$_temp0';
  }

  @override
  String cylinderConfigs_applyKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conservées',
      one: '1 conservée',
    );
    return '$_temp0';
  }

  @override
  String get cylinderConfigs_applyNothingToDo =>
      'Cette plongée correspond déjà à la configuration';

  @override
  String get cylinderConfigs_sectionTitle => 'Configurations';

  @override
  String get equipment_serviceClocks_hoursSource =>
      'Calculé à partir du temps de plongée enregistré';

  @override
  String equipment_serviceClocks_hoursLeft(String remaining, String total) {
    return '$remaining heures restantes sur $total';
  }

  @override
  String get equipment_serviceClocks_manageKinds =>
      'Gérer les types d\'entretien';

  @override
  String get equipment_serviceClocks_appliesToClock =>
      'S\'applique au compteur';

  @override
  String get equipment_serviceClocks_noClockOption => 'Non lié à un compteur';

  @override
  String get equipment_scheduleDialog_title => 'Modifier le compteur';

  @override
  String get equipment_scheduleDialog_intervalDays => 'Intervalle (jours)';

  @override
  String get equipment_scheduleDialog_intervalDives => 'Intervalle (plongées)';

  @override
  String get equipment_scheduleDialog_intervalHours => 'Intervalle (heures)';

  @override
  String equipment_scheduleDialog_inheritHint(String value) {
    return 'Par défaut : $value';
  }

  @override
  String get equipment_scheduleDialog_anchorDate => 'Date de référence';

  @override
  String get equipment_scheduleDialog_anchorHint =>
      'Utilisée lorsqu\'aucun entretien de ce type n\'a encore été enregistré';

  @override
  String get equipment_scheduleDialog_clearAnchor =>
      'Effacer la date de référence';

  @override
  String get equipment_scheduleDialog_save => 'Enregistrer';

  @override
  String get equipment_scheduleDialog_cancel => 'Annuler';

  @override
  String get equipment_serviceKinds_title => 'Types d\'entretien';

  @override
  String get equipment_serviceKinds_builtIn => 'Intégrés';

  @override
  String get equipment_serviceKinds_custom => 'Personnalisés';

  @override
  String get equipment_serviceKinds_add => 'Ajouter un type d\'entretien';

  @override
  String get equipment_serviceKinds_editTitle =>
      'Modifier le type d\'entretien';

  @override
  String get equipment_serviceKinds_nameLabel => 'Nom';

  @override
  String get equipment_serviceKinds_nameRequired => 'Un nom est requis';

  @override
  String get equipment_serviceKinds_appliesTo => 'S\'applique à';

  @override
  String get equipment_serviceKinds_autoAttach =>
      'Associer automatiquement au nouvel équipement';

  @override
  String get equipment_serviceKinds_deleteConfirmTitle =>
      'Supprimer ce type d\'entretien ?';

  @override
  String get equipment_serviceKinds_deleteConfirmBody =>
      'Les compteurs utilisant ce type d\'entretien seront supprimés.';

  @override
  String get equipment_serviceKinds_delete => 'Supprimer';

  @override
  String get equipment_serviceKinds_cancel => 'Annuler';

  @override
  String get equipment_serviceKinds_save => 'Enregistrer';

  @override
  String get equipment_serviceKinds_emptyCustom =>
      'Aucun type d\'entretien personnalisé pour le moment';

  @override
  String equipment_serviceKinds_everyDays(int days) {
    return 'tous les $days jours';
  }

  @override
  String equipment_serviceKinds_everyDives(int dives) {
    return 'toutes les $dives plongées';
  }

  @override
  String equipment_serviceKinds_everyHours(String hours) {
    return 'toutes les $hours heures';
  }

  @override
  String get dashboard_serviceDue_title => 'Entretien à prévoir';

  @override
  String dashboard_serviceDue_more(int count) {
    return '+$count de plus';
  }

  @override
  String dashboard_alerts_clockDue(String name, String kind) {
    return '$name : $kind à échéance';
  }

  @override
  String dashboard_alerts_clockOverdue(String name, String kind) {
    return '$name : $kind en retard';
  }

  @override
  String equipment_list_worstClock(String kind) {
    return '$kind en retard';
  }

  @override
  String trips_serviceAlert_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count équipements nécessitent un entretien avant ce voyage',
      one: '1 équipement nécessite un entretien avant ce voyage',
    );
    return '$_temp0';
  }

  @override
  String trips_serviceAlert_dueBefore(String kind, String date) {
    return '$kind à échéance le $date';
  }

  @override
  String trips_serviceAlert_overdue(String kind) {
    return '$kind en retard';
  }

  @override
  String get settings_notifications_tripLeadTitle =>
      'Délai d\'alerte d\'entretien avant un voyage';

  @override
  String settings_notifications_tripLeadDays(int days) {
    return '$days jours avant un voyage';
  }

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
  String get equipment_detail_thicknessLabel => 'Épaisseur';

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
  String get equipment_edit_purchasePriceValidation =>
      'Entrez un montant valide';

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
  String get equipment_edit_thicknessDesignationHint => 'ex: 5, 5/4, 7/5/3';

  @override
  String get equipment_edit_thicknessHint => 'ex: 5mm, 7mm';

  @override
  String get equipment_edit_thicknessLabel => 'Épaisseur';

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
  String get equipment_fab_addSet => 'Ajouter un ensemble';

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
  String equipment_list_tile_serviceInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Revision dans $days jours',
      one: 'Revision dans 1 jour',
    );
    return '$_temp0';
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
  String get equipment_serviceDialog_currencyLabel => 'Devise';

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
  String get equipment_serviceDialog_serviceTypeLabel => 'Type de révision';

  @override
  String get equipment_serviceDialog_serviceTypeHelper =>
      'L\'enregistrer réinitialise le compteur de ce type de révision';

  @override
  String get equipment_serviceDialog_serviceTypeRequired =>
      'Choisissez un type de révision';

  @override
  String get equipment_serviceDialog_serviceTypeNotSet => 'Non défini';

  @override
  String get equipment_serviceDialog_categoryHelper =>
      'Utilisée pour le filtrage et l\'export';

  @override
  String get equipment_serviceDialog_manageServiceTypes =>
      'Gérer les types de révision';

  @override
  String get equipment_serviceDialog_categoryLabel => 'Catégorie';

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
  String get equipment_serviceCategory_annual => 'Révision annuelle';

  @override
  String get equipment_serviceCategory_repair => 'Réparation';

  @override
  String get equipment_serviceCategory_inspection => 'Inspection';

  @override
  String get equipment_serviceCategory_overhaul => 'Révision complète';

  @override
  String get equipment_serviceCategory_replacement => 'Remplacement de pièces';

  @override
  String get equipment_serviceCategory_cleaning => 'Nettoyage';

  @override
  String get equipment_serviceCategory_calibration => 'Étalonnage';

  @override
  String get equipment_serviceCategory_warranty => 'Service sous garantie';

  @override
  String get equipment_serviceCategory_recall => 'Rappel/Sécurité';

  @override
  String get equipment_serviceCategory_other => 'Autre';

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
  String equipment_service_nextDueLabel(String date) {
    return 'Prochaine échéance $date';
  }

  @override
  String get equipment_service_filterTaskAll => 'Toutes les tâches';

  @override
  String get equipment_service_filterTypeAll => 'Tous les types';

  @override
  String get equipment_service_filterYearAll => 'Toutes les années';

  @override
  String get equipment_service_filterUntagged => 'Sans intervalle associé';

  @override
  String get equipment_service_filterClear => 'Réinitialiser le filtre';

  @override
  String get equipment_service_filterNoMatches =>
      'Aucun entretien ne correspond à ce filtre';

  @override
  String equipment_service_filterMatchCount(int count, int total) {
    return '$count sur $total affichés';
  }

  @override
  String get equipment_serviceKinds_defaultCategoryLabel =>
      'Catégorie par défaut';

  @override
  String get equipment_serviceKinds_defaultCategoryNone => 'Aucune par défaut';

  @override
  String get equipment_serviceKinds_defaultCostLabel => 'Prix par défaut';

  @override
  String get equipment_serviceKinds_defaultCostHint =>
      'Laisser vide pour aucune valeur par défaut';

  @override
  String get equipment_scheduleDialog_defaultCostLabel =>
      'Prix par défaut pour cet équipement';

  @override
  String get equipment_serviceKinds_defaultCurrencyLabel => 'Devise';

  @override
  String get equipment_service_exportMenuItem =>
      'Exporter le journal d\'entretien';

  @override
  String get transfer_export_maintenanceTitle => 'Journal d\'entretien';

  @override
  String get transfer_export_maintenanceSubtitle =>
      'Historique d\'entretien de tout l\'équipement en tableur';

  @override
  String get settings_export_progress_maintenance =>
      'Exportation du journal d\'entretien...';

  @override
  String get settings_export_success_maintenance =>
      'Journal d\'entretien exporté';

  @override
  String get settings_export_saved_maintenance =>
      'Journal d\'entretien enregistré';

  @override
  String get equipment_serviceKinds_defaultCurrencyInherit =>
      'Utiliser la devise par défaut';

  @override
  String get equipment_scheduleDialog_defaultCurrencyLabel =>
      'Devise pour cet équipement';

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
  String get equipment_tab_equipment => 'Equipement';

  @override
  String get equipment_tab_sets => 'Ensembles';

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
  String get gasCalculators_mnd_depthInput => 'Profondeur';

  @override
  String get gasCalculators_mnd_endAtDepthTitle => 'END a la profondeur';

  @override
  String get gasCalculators_mnd_endLimit => 'Limite END';

  @override
  String get gasCalculators_mnd_hePercent => 'He %';

  @override
  String get gasCalculators_mnd_infoContent =>
      'La profondeur narcotique maximale (MND) est la profondeur maximale a laquelle vous pouvez descendre avant que la narcose ne depasse votre limite END. La profondeur narcotique equivalente (END) indique l\'effet narcotique de votre gaz a une profondeur donnee.\n\nLorsque \"O2 est narcotique\" est active, l\'oxygene et l\'azote contribuent tous deux a la narcose (plus conservateur). Lorsque desactive, seul l\'azote est considere comme narcotique.';

  @override
  String get gasCalculators_mnd_infoTitle => 'A propos de MND/END';

  @override
  String get gasCalculators_mnd_unlimited => 'illimitee';

  @override
  String get gasCalculators_mnd_inputParameters =>
      'Melange gazeux et reglages de narcose';

  @override
  String get gasCalculators_mnd_o2Narcotic => 'O2 est narcotique';

  @override
  String get gasCalculators_mnd_o2Percent => 'O2 %';

  @override
  String get gasCalculators_mnd_resultTitle => 'Profondeur narcotique maximale';

  @override
  String get gasCalculators_ppO2Limit => 'Limite ppO₂';

  @override
  String get gasCalculators_resetAll => 'Réinitialiser tous les calculateurs';

  @override
  String get gasCalculators_sacRate => 'RMV';

  @override
  String get gasCalculators_tab_bestMix => 'Meilleur mélange';

  @override
  String get gasCalculators_tab_consumption => 'Consommation';

  @override
  String get gasCalculators_tab_mnd => 'MND/END';

  @override
  String get gasCalculators_tab_blender => 'Mélangeur trimix';

  @override
  String get gasCalculators_blender_cylinder => 'Bloc';

  @override
  String get gasCalculators_blender_startCylinder => 'Dans le bloc';

  @override
  String get gasCalculators_blender_targetFill => 'Remplissage cible';

  @override
  String get gasCalculators_blender_fillGases => 'Gaz de remplissage';

  @override
  String get gasCalculators_blender_pressure => 'Pression';

  @override
  String get gasCalculators_blender_o2 => 'O₂';

  @override
  String get gasCalculators_blender_he => 'He';

  @override
  String get gasCalculators_blender_air => 'Air';

  @override
  String get gasCalculators_blender_helium => 'Hélium';

  @override
  String get gasCalculators_blender_procedure => 'Procédure de remplissage';

  @override
  String get gasCalculators_blender_amounts => 'Gaz à ajouter';

  @override
  String gasCalculators_blender_stepStart(String pressure, String gas) {
    return 'Commencer avec $pressure $gas';
  }

  @override
  String gasCalculators_blender_stepFill(
    String gas,
    String pressure,
    String mix,
  ) {
    return 'Remplir $gas jusqu\'à $pressure → $mix';
  }

  @override
  String get gasCalculators_blender_error_targetPressure =>
      'La pression cible doit être supérieure à la pression de départ.';

  @override
  String get gasCalculators_blender_error_invalidMix =>
      'L\'O₂ + He d\'un mélange ne peut pas dépasser 100 %.';

  @override
  String get gasCalculators_blender_error_identicalGases =>
      'Les deux gaz de remplissage sont identiques — rien à mélanger.';

  @override
  String get gasCalculators_blender_error_linearlyDependent =>
      'Ces gaz ne peuvent pas produire le mélange cible — une cible trimix nécessite une source d\'hélium.';

  @override
  String get gasCalculators_blender_error_negativeAmount =>
      'Ce mélange n\'est pas réalisable avec ces gaz — il faudrait retirer du gaz.';

  @override
  String gasCalculators_blender_error_drainTo(String pressure) {
    return 'Trop de gaz dans le bloc pour ce mélange. Vidangez d\'abord à $pressure, puis remplissez.';
  }

  @override
  String get gasCalculators_blender_error_drainEmpty =>
      'Le gaz présent dans le bloc ne peut pas servir à ce mélange. Videz-le complètement, puis remplissez.';

  @override
  String get gasCalculators_blender_error_cannotRemoveHelium =>
      'Le bloc contient de l\'hélium alors que le mélange cible n\'en contient pas. Le remplissage dilue l\'hélium mais ne l\'élimine pas : le bloc doit d\'abord être vidé.';

  @override
  String get gasCalculators_blender_error_insufficientGases =>
      'Une cible sans hélium nécessite deux gaz de remplissage sans hélium de teneurs en O₂ différentes.';

  @override
  String get gasCalculators_blender_error_targetNotReached =>
      'Ces gaz de remplissage n\'atteignent pas exactement le mélange cible. Vérifiez les gaz et leur ordre.';

  @override
  String get gasCalculators_blender_error_implausibleStartMix =>
      'Le bloc est sous pression mais ne contient ni oxygène ni hélium, ce qui serait de l\'azote pur. Vérifiez le mélange déjà présent dans le bloc.';

  @override
  String get gasCalculators_blender_about => 'À propos du mélange';

  @override
  String get gasCalculators_blender_aboutBody =>
      'Mélange par pressions partielles pour le mélange cible. Ajoutez chaque gaz de remplissage dans l\'ordre, jusqu\'à la pression indiquée, puis laissez le bloc se stabiliser. Les gaz de remplissage et leur ordre sont configurables : en réglant le dernier gaz sur 32/0, le complément se fait à l\'EAN32 au lieu de l\'air. Analysez toujours le mélange final avant de le plonger.';

  @override
  String get gasCalculators_blender_conditions => 'Conditions de mélange';

  @override
  String get gasCalculators_blender_fillTemp => 'Température de remplissage';

  @override
  String get gasCalculators_blender_fillTempHelp =>
      'La température du bloc pendant le remplissage. Chaque pression de la procédure est la valeur au manomètre à cette température.';

  @override
  String get gasCalculators_blender_settledTemp => 'Température stabilisée';

  @override
  String get gasCalculators_blender_settledTempHelp =>
      'La température que le bloc atteint au repos. La pression cible est ce qu\'il indique une fois stabilisé.';

  @override
  String get gasCalculators_blender_gasModel => 'Modèle de gaz';

  @override
  String get gasCalculators_blender_modelIdeal => 'Gaz parfait';

  @override
  String get gasCalculators_blender_modelVanDerWaals => 'Van der Waals';

  @override
  String get gasCalculators_blender_modelZFactor => 'Gaz réel (facteur Z)';

  @override
  String get gasCalculators_blender_modelRecommended => 'Recommandé';

  @override
  String get gasCalculators_blender_modelHelp =>
      'Le gaz réel (facteur Z) est le plus précis aux pressions de bloc. Le gaz parfait correspond à la plupart des tables de mélange publiées. Van der Waals est proposé pour comparaison avec d\'autres logiciels de mélange et s\'écarte de plusieurs pour cent à la pression de remplissage.';

  @override
  String gasCalculators_blender_stepAdd(String gas) {
    return 'Ajouter $gas';
  }

  @override
  String get gasCalculators_blender_stepStartLabel => 'Départ';

  @override
  String gasCalculators_blender_settlesTo(String pressure, String temperature) {
    return 'Se stabilise à $pressure à $temperature';
  }

  @override
  String get gasCalculators_blender_templates => 'Modèles';

  @override
  String get gasCalculators_blender_templatesTitle =>
      'Modèles de mélange cible';

  @override
  String get gasCalculators_blender_saveTemplate =>
      'Enregistrer le mélange actuel';

  @override
  String get gasCalculators_blender_manageTemplates => 'Gérer les modèles';

  @override
  String gasCalculators_blender_templateSaved(String mix) {
    return '$mix enregistré';
  }

  @override
  String get gasCalculators_blender_templateExists =>
      'Ce mélange est déjà enregistré.';

  @override
  String get gasCalculators_blender_templateInvalid =>
      'O₂ + He ne peut pas dépasser 100 %.';

  @override
  String get gasCalculators_blender_templateNeedsNumbers =>
      'Saisissez O₂ et He sous forme de nombres.';

  @override
  String gasCalculators_blender_templateLimit(int count) {
    return 'Vous pouvez enregistrer jusqu\'à $count modèles.';
  }

  @override
  String get gasCalculators_blender_templateNone =>
      'Aucun modèle pour l\'instant. Enregistrez un mélange cible pour le réutiliser ici.';

  @override
  String gasCalculators_blender_templateDelete(String mix) {
    return 'Supprimer $mix';
  }

  @override
  String get gasCalculators_blender_templateAdd => 'Ajouter un modèle';

  @override
  String get gasCalculators_blender_billing => 'Coût';

  @override
  String get gasCalculators_blender_cylinderVolume => 'Volume d\'eau du bloc';

  @override
  String get gasCalculators_blender_cylinderPresets => 'Préréglages';

  @override
  String gasCalculators_blender_unitPrice(String unit) {
    return 'Prix pour 100 $unit';
  }

  @override
  String get gasCalculators_blender_currency => 'Devise';

  @override
  String get gasCalculators_blender_costTotal => 'Total';

  @override
  String get gasCalculators_blender_costBasis =>
      'Facturé sur la pression délivrée (volume d\'eau du bloc × bars ajoutés), comme le mesure une station de gonflage.';

  @override
  String get gasCalculators_blender_costMissingPrice =>
      'Saisissez un prix pour chaque gaz afin de voir le total.';

  @override
  String get gasCalculators_blender_saveFill => 'Enregistrer ce remplissage';

  @override
  String get gasCalculators_blender_billed => 'Facturé';

  @override
  String get gasCalculators_blender_billedNone =>
      'Rien de facturé pour l\'instant. Terminez un remplissage et enregistrez-le ici.';

  @override
  String get gasCalculators_blender_billedTo => 'Facturé à';

  @override
  String get gasCalculators_blender_addManualLine => 'Ajouter une ligne';

  @override
  String get gasCalculators_blender_lineDescription => 'Désignation';

  @override
  String get gasCalculators_blender_lineAmount => 'Montant';

  @override
  String get gasCalculators_blender_clearBilled => 'Vider';

  @override
  String get gasCalculators_blender_clearBilledTitle => 'Vider la facture ?';

  @override
  String gasCalculators_blender_clearBilledBody(int count) {
    return 'Cela supprime les $count remplissages enregistrés.';
  }

  @override
  String gasCalculators_blender_editLine(String label) {
    return 'Modifier $label';
  }

  @override
  String gasCalculators_blender_deleteLine(String label) {
    return 'Supprimer $label';
  }

  @override
  String gasCalculators_blender_fillAdded(String mix) {
    return '$mix ajouté à la facture';
  }

  @override
  String get gasCalculators_blender_billedIncomplete =>
      'Au moins une ligne n\'a pas de prix, le total est donc incomplet.';

  @override
  String get gasCalculators_blender_billedTotal => 'Total';

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
  String get media_diveMediaSection_cancelSelectionButton => 'Annuler';

  @override
  String get media_diveMediaSection_emptyState => 'Aucune photo';

  @override
  String get media_diveMediaSection_errorLoading =>
      'Erreur lors du chargement des medias';

  @override
  String get media_diveMediaSection_selectAllButton => 'Tout selectionner';

  @override
  String media_diveMediaSection_selectedCount(int count) {
    return '$count selectionne(s)';
  }

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'Voir la photo. Appui long pour dissocier';

  @override
  String get media_diveMediaSection_title => 'Photos et video';

  @override
  String get media_diveMediaSection_replaceButton => 'Relier';

  @override
  String get media_diveMediaSection_replaceEditedContent =>
      'Le contenu de ce fichier diffère de l\'original. Le relier entraînera son renvoi vers votre stockage multimédia.';

  @override
  String get media_diveMediaSection_replaceEditedTitle =>
      'Le contenu du fichier diffère';

  @override
  String get media_diveMediaSection_unlinkButton => 'Dissocier';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Echec de la dissociation : $error';
  }

  @override
  String media_diveMediaSection_unlinkSelectedButton(int count) {
    return 'Dissocier $count';
  }

  @override
  String media_diveMediaSection_unlinkSelectedContent(int count) {
    return 'Retire $count medias de votre bibliotheque, ainsi que leurs copies cloud et miniatures. Les medias encore utilises par un site de plongee sont conserves. Vos fichiers originaux ne sont pas affectes.';
  }

  @override
  String media_diveMediaSection_unlinkSelectedSuccess(int count) {
    return '$count elements dissocies';
  }

  @override
  String media_diveMediaSection_unlinkSelectedTitle(int count) {
    return 'Dissocier $count elements ?';
  }

  @override
  String media_library_unlinkConfirmTitle(int count) {
    return 'Dissocier $count elements ?';
  }

  @override
  String media_siteMediaSection_unlinkError(Object error) {
    return 'Echec de la dissociation : $error';
  }

  @override
  String get media_library_unlinkConfirmBody =>
      'Ils quittent votre bibliothèque, ainsi que leurs copies cloud et leurs miniatures. Vos fichiers originaux ne sont pas affectés. Cette action est irréversible.';

  @override
  String media_library_unlinkMetadataNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count d\'entre eux possèdent une légende ou un favori enregistré dans Submersion, et ces détails sont perdus.',
      one:
          'L\'un d\'eux possède une légende ou un favori enregistré dans Submersion, et ces détails sont perdus.',
    );
    return '$_temp0';
  }

  @override
  String get media_siteMediaSection_title => 'Médias du site';

  @override
  String get media_siteMediaSection_addPhotos => 'Ajouter des photos ou vidéos';

  @override
  String get media_siteMediaSection_addDocument => 'Ajouter un document';

  @override
  String get media_siteMediaSection_emptyState =>
      'Aucune carte, photo ou document attaché à ce site';

  @override
  String media_siteMediaSection_divePhotosGroup(int count) {
    return 'Photos des plongées ici ($count)';
  }

  @override
  String get media_siteMediaSection_divePhotoLabel => 'Photo de plongée';

  @override
  String media_siteMediaSection_unlinkSelectedTitle(int count) {
    return 'Dissocier $count elements ?';
  }

  @override
  String media_siteMediaSection_unlinkSelectedContent(int count) {
    return 'Supprime $count éléments de votre bibliothèque, ainsi que leurs copies cloud et vignettes. Les médias encore utilisés par une plongée sont conservés. Vos fichiers d\'origine ne sont pas affectés.';
  }

  @override
  String media_siteMediaSection_unlinkSelectedSuccess(int count) {
    return '$count elements dissocies';
  }

  @override
  String get media_documentViewer_title => 'Document';

  @override
  String get media_documentViewer_unavailable =>
      'Ce document n\'est pas disponible sur cet appareil';

  @override
  String get media_documentViewer_availableOnOriginDevice =>
      'Il est disponible sur l\'appareil depuis lequel il a été ajouté, ou via un stockage multimédia configuré.';

  @override
  String media_documentViewer_attached(int count) {
    return '$count documents attachés';
  }

  @override
  String get media_diveScan_scanTooltip =>
      'Rechercher des photos dans la galerie';

  @override
  String get media_diveScan_noPhotosFound =>
      'Aucune nouvelle photo trouvee pres de cette plongee';

  @override
  String get media_diveScan_accessDenied =>
      'L\'acces a la phototeque est requis pour rechercher des photos';

  @override
  String media_diveScan_foundPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos trouvees',
      one: '1 photo trouvee',
    );
    return '$_temp0 pres de cette plongee. Les lier ?';
  }

  @override
  String get media_diveScan_foundTitle => 'Photos trouvees';

  @override
  String media_diveScan_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'les photos',
      one: 'la photo',
    );
    return 'Lier $_temp0';
  }

  @override
  String get media_diveScan_cancelButton => 'Annuler';

  @override
  String media_diveScan_error(String error) {
    return 'Erreur lors de la recherche dans la galerie : $error';
  }

  @override
  String get media_gpsBanner_addToSiteButton => 'Ajouter au site';

  @override
  String media_gpsBanner_coordinates(Object coordinates) {
    return 'Coordonnees : $coordinates';
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
  String media_import_allAlreadyLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos deja associees a cette plongee',
      one: '1 photo deja associee a cette plongee',
    );
    return '$_temp0';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return '$imported importees, $failed echouees';
  }

  @override
  String media_import_importedAndSkipped(int imported, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      imported,
      locale: localeName,
      other: '$imported photos importees',
      one: '1 photo importee',
    );
    return '$_temp0 ($skipped deja associees)';
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
  String get media_lightroom_openInLightroom => 'Ouvrir dans Lightroom';

  @override
  String get media_lightroom_suggestion_accept => 'Ajouter à cette plongée';

  @override
  String get media_lightroom_suggestion_dismiss => 'Ignorer';

  @override
  String get media_lightroom_suggestions_title => 'Suggestions de Lightroom';

  @override
  String get media_miniProfile_headerLabel => 'Profil de plongee';

  @override
  String get media_miniProfile_semanticLabel =>
      'Mini graphique du profil de plongee';

  @override
  String get media_photoPicker_appBarTitle => 'Selectionner des photos';

  @override
  String get media_photoPicker_tab_gallery => 'Galerie';

  @override
  String get media_photoPicker_tab_files => 'Fichiers';

  @override
  String get media_photoPicker_tab_url => 'URL';

  @override
  String get media_photoPicker_clearSelectionButton => 'Effacer';

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
  String get media_photoPicker_grantAccessButton => 'Continuer';

  @override
  String get media_photoPicker_openSettingsButton => 'Ouvrir les reglages';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'L\'acces a la phototheque a ete refuse. Veuillez l\'activer dans les Reglages pour ajouter des photos de plongee.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'Submersion a besoin d\'acceder a votre phototheque pour ajouter des photos de plongee.';

  @override
  String get media_photoPicker_permissionTitle => 'Photos de plongee';

  @override
  String get media_photoPicker_selectAllButton => 'Tout selectionner';

  @override
  String media_photoPicker_selectedCount(int count) {
    return '$count selectionne(s)';
  }

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
  String get media_photoPicker_files_pickFilesButton => 'Choisir des fichiers…';

  @override
  String get media_photoPicker_files_pickFolderButton => 'Choisir un dossier…';

  @override
  String get media_photoPicker_files_autoMatchLabel =>
      'Associer automatiquement les photos et vidéos aux plongées par date';

  @override
  String get media_photoPicker_files_emptyHint =>
      'Choisissez des fichiers ou un dossier pour commencer.';

  @override
  String media_photoPicker_files_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lier $count éléments',
      one: 'Lier 1 élément',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachToSiteButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Joindre $count éléments à ce site',
      one: 'Joindre 1 élément à ce site',
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
      other: '$fileCount fichiers',
      one: '1 fichier',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount plongées',
      one: '1 plongée',
    );
    return '$_temp0, $_temp1, $unmatchedCount non associés';
  }

  @override
  String media_photoPicker_files_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_diveGroupTitle(String diveId) {
    return 'Plongée $diveId';
  }

  @override
  String media_photoPicker_files_groupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_unmatchedGroupTitle => 'Non associés';

  @override
  String media_photoPicker_files_addAllToDive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouter les $count à cette plongée',
      one: 'Ajouter 1 à cette plongée',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_addToDiveTooltip =>
      'Ajouter à cette plongée';

  @override
  String get media_photoPicker_files_chooseDiveTooltip => 'Choisir une plongée';

  @override
  String get media_photoPicker_files_removeTooltip => 'Retirer de la sélection';

  @override
  String get media_photoPicker_files_sourceExif => 'depuis EXIF';

  @override
  String get media_photoPicker_files_sourceContainer =>
      'depuis les métadonnées du fichier';

  @override
  String get media_photoPicker_files_sourceFileDate =>
      'depuis la date du fichier';

  @override
  String get media_photoPicker_files_sourceNone => 'aucune date trouvée';

  @override
  String media_photoPicker_files_shiftedTime(String shifted, String original) {
    return '$shifted (était $original)';
  }

  @override
  String get media_photoPicker_files_reasonNoTimestamp =>
      'Heure de prise de vue illisible';

  @override
  String media_photoPicker_files_reasonBeforeDive(String gap) {
    return '$gap avant la plongée la plus proche';
  }

  @override
  String media_photoPicker_files_reasonAfterDive(String gap) {
    return '$gap après la plongée la plus proche';
  }

  @override
  String get media_photoPicker_files_reasonNoDives =>
      'Aucune plongée à comparer';

  @override
  String get media_photoPicker_files_offsetLabel =>
      'Décaler les heures de prise de vue de';

  @override
  String get media_photoPicker_files_offsetResetTooltip =>
      'Annuler le décalage';

  @override
  String media_photoPicker_files_offsetBackTooltip(String amount) {
    return 'Décaler de $amount plus tôt';
  }

  @override
  String media_photoPicker_files_offsetForwardTooltip(String amount) {
    return 'Décaler de $amount plus tard';
  }

  @override
  String media_photoPicker_files_linkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments liés',
      one: '1 élément lié',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachedToSiteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments joints à ce site',
      one: '1 élément joint à ce site',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_undo => 'Annuler';

  @override
  String get media_photoPicker_thumbnailAlreadyLinkedLabel =>
      'Photo deja associee a cette plongee';

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
  String get media_perdixOverlay_labelTime => 'TEMPS';

  @override
  String get media_perdixOverlay_labelTts => 'TTS';

  @override
  String get media_perdixOverlay_toggleTooltip =>
      'Superposition ordinateur de plongée';

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
  String get media_photoViewer_nextTooltip => 'Média suivant';

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
  String get media_photoViewer_previousTooltip => 'Média précédent';

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
      'Non disponible sur cet appareil';

  @override
  String get media_unavailablePlaceholder_signInRequired => 'Sign in to view';

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
  String get media_writeMetadata_livePhotoUnsupported =>
      'Les Live Photos ne sont pas encore prises en charge. Dupliquez cette photo en image fixe, puis écrivez les données de plongée sur la copie.';

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
  String get nav_gpsLog => 'Journal GPS';

  @override
  String get media_console_library => 'Bibliothèque';

  @override
  String get media_console_transfers => 'Transferts';

  @override
  String get media_console_import => 'Importer';

  @override
  String get media_import_launch => 'Importer des médias...';

  @override
  String get media_import_review_title => 'Vérifier l\'import';

  @override
  String media_import_review_confirm(int count) {
    return 'Importer $count éléments';
  }

  @override
  String media_import_review_result(int linked, int skipped, int failed) {
    return '$linked liés, $skipped ignorés, $failed en échec';
  }

  @override
  String get media_import_review_chooseSite => 'Choisir un site';

  @override
  String get media_import_review_ambiguous =>
      'Plusieurs plongées correspondent';

  @override
  String get media_import_review_noMatch => 'Aucune plongée correspondante';

  @override
  String get media_import_review_skipped => 'Non importé';

  @override
  String media_import_review_linkChip(int number) {
    return 'Lier à #$number';
  }

  @override
  String get media_import_review_linkToDive => 'Lier à une plongée';

  @override
  String get media_import_review_linkToSite => 'Lier à un site';

  @override
  String get media_import_review_chooseDive => 'Choisir la plongée';

  @override
  String get media_import_intro =>
      'Les photos sont liées à une plongée ou à un site au moment de l\'import.';

  @override
  String get media_console_sources => 'Sources';

  @override
  String get media_sources_browseHeader => 'Parcourir par source';

  @override
  String get media_sources_watchedHeader => 'Dossiers surveillés';

  @override
  String get media_sources_addWatched => 'Ajouter un dossier...';

  @override
  String get media_sources_scanFailed => 'Échec de l\'analyse';

  @override
  String get media_sources_scanNow => 'Analyser maintenant';

  @override
  String get media_sources_autoApply =>
      'Relier automatiquement les correspondances exactes';

  @override
  String get media_sources_neverScanned => 'Jamais analysé';

  @override
  String get media_source_gallery => 'Photothèque';

  @override
  String get media_source_localFile => 'Fichiers locaux';

  @override
  String get media_source_networkUrl => 'Liens web';

  @override
  String get media_source_manifest => 'Abonnements';

  @override
  String get media_source_connector => 'Services connectés';

  @override
  String get media_source_mediaStore => 'Stockage multimédia cloud';

  @override
  String get media_source_signature => 'Signatures';

  @override
  String get media_repairHistory_title => 'Historique des réparations';

  @override
  String get media_repairHistory_empty => 'Aucune réparation';

  @override
  String get media_repairHistory_action_relink => 'Relié';

  @override
  String get media_repairHistory_action_cloudBacked => 'Sur le cloud';

  @override
  String get media_repairHistory_action_autoRelink => 'Relié automatiquement';

  @override
  String get media_smartAlbum_save => 'Enregistrer comme album';

  @override
  String get media_smartAlbum_saveTitle => 'Nommer cet album';

  @override
  String get media_smartAlbum_albums => 'Albums';

  @override
  String get media_smartAlbum_delete => 'Supprimer l\'album';

  @override
  String get media_smartAlbum_deleteFailed =>
      'Impossible de supprimer l\'album';

  @override
  String get media_smartAlbum_saved => 'Album enregistré';

  @override
  String media_sources_lastScanned(String date) {
    return 'Dernière analyse $date';
  }

  @override
  String media_sources_scanResult(int indexed, int repaired) {
    return '$indexed fichiers indexés, $repaired reliés';
  }

  @override
  String get media_repairHistory_sourceFolder => 'analyse de dossier';

  @override
  String get media_repairHistory_sourcePhotoLibrary => 'photothèque';

  @override
  String get media_repairHistory_sourceStore => 'stockage multimédia cloud';

  @override
  String get media_repairHistory_sourceWatcher => 'dossiers surveillés';

  @override
  String get media_repairHistory_sourceManual => 'reliaison manuelle';

  @override
  String media_repairHistory_source(String source) {
    return 'via $source';
  }

  @override
  String get media_missing_empty => 'Aucun fichier manquant';

  @override
  String media_missing_offlineVolumes(int count) {
    return '$count sur des volumes hors ligne';
  }

  @override
  String get media_missing_repair => 'Réparer...';

  @override
  String get media_repair_title => 'Réparer les fichiers manquants';

  @override
  String get media_repair_addFolder => 'Ajouter un dossier...';

  @override
  String get media_repair_usePhotoLibrary => 'Rechercher dans la photothèque';

  @override
  String get media_repair_useStore => 'Utiliser le stockage multimédia cloud';

  @override
  String get media_repair_scan => 'Analyser';

  @override
  String media_repair_prefixMove(String from, String to, int count) {
    return 'Déplacement de dossier détecté : $from vers $to couvre $count fichiers';
  }

  @override
  String get media_repair_confidence_exact => 'Exact';

  @override
  String get media_repair_confidence_probable => 'Nom et taille';

  @override
  String get media_repair_confidence_edited => 'Fichier modifié';

  @override
  String get media_repair_confidence_unmatched => 'Aucun candidat';

  @override
  String get media_repair_unverified => 'Non vérifié auprès du stockage';

  @override
  String media_repair_apply(int count) {
    return 'Relier $count fichiers';
  }

  @override
  String media_repair_summary(
    int relinked,
    int cloudBacked,
    int reuploads,
    int failed,
    int skipped,
  ) {
    return '$relinked reliés, $cloudBacked sur le cloud, $reuploads renvois en file, $failed échoués, $skipped ignorés';
  }

  @override
  String get media_library_empty => 'Aucun média pour le moment';

  @override
  String get media_library_filter_all => 'Tous';

  @override
  String get media_library_filter_photos => 'Photos';

  @override
  String get media_library_filter_videos => 'Vidéos';

  @override
  String get media_library_filter_site => 'Site';

  @override
  String get media_library_filter_trip => 'Voyage';

  @override
  String get media_library_filter_dates => 'Dates';

  @override
  String get media_library_filter_missing => 'Fichiers manquants';

  @override
  String media_library_filter_missingCount(int count) {
    return 'Fichiers manquants ($count)';
  }

  @override
  String get media_library_filter_clear => 'Effacer les filtres';

  @override
  String get media_library_filter_any => 'Indifférent';

  @override
  String get media_library_filter_title => 'Filtrer les médias';

  @override
  String get media_library_filter_apply => 'Appliquer';

  @override
  String get media_library_sort_title => 'Trier les médias';

  @override
  String get media_smartAlbum_load => 'Charger l\'album';

  @override
  String get media_divePicker_title => 'Déplacer vers une plongée';

  @override
  String get media_divePicker_search => 'Rechercher des plongées';

  @override
  String get media_library_moveToDive => 'Déplacer vers une plongée';

  @override
  String get media_library_unlinkSelected => 'Dissocier';

  @override
  String media_library_selectedCount(int count) {
    return '$count sélectionnés';
  }

  @override
  String get media_library_unlinkedHeader => 'Non liés';

  @override
  String get media_library_diveHeaderHint => 'Ouvrir cette plongée';

  @override
  String get media_library_untitledDiveHeader => 'Plongée sans titre';

  @override
  String get media_library_viewMode_byDive => 'Par plongée';

  @override
  String get media_library_viewMode_grid => 'Grille';

  @override
  String get media_library_viewMode_timeline => 'Chronologie';

  @override
  String get media_viewer_goToDive => 'Aller à la plongée';

  @override
  String get nav_home => 'Accueil';

  @override
  String get nav_media => 'Médias';

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
  String plannerCanvas_bailout_available(String liters) {
    return 'Disponible $liters';
  }

  @override
  String get plannerCanvas_bailout_insufficient =>
      'Gaz de bailout insuffisant pour le pire cas';

  @override
  String plannerCanvas_bailout_required(String liters) {
    return 'Nécessaire $liters';
  }

  @override
  String get plannerCanvas_bailout_title => 'Bailout (circuit ouvert)';

  @override
  String plannerCanvas_bailout_tts(String minutes) {
    return 'TTS bailout $minutes′';
  }

  @override
  String plannerCanvas_bailout_worstCase(String minutes, String depth) {
    return 'Pire cas à $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_ccr_setpointHigh => 'Setpoint haut (bar)';

  @override
  String get plannerCanvas_ccr_setpointLow => 'Setpoint bas (bar)';

  @override
  String get plannerCanvas_ccr_switchDepth =>
      'Profondeur de bascule du setpoint';

  @override
  String get plannerCanvas_pscr_ratio => 'Ratio pSCR';

  @override
  String get plannerCanvas_pscr_ratio_hint =>
      'Plus grand = plus de gaz frais, chute d\'O₂ plus faible';

  @override
  String plannerCanvas_chip_cns(String value) {
    return 'CNS $value%';
  }

  @override
  String plannerCanvas_chip_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problèmes',
      one: '1 problème',
    );
    return '$_temp0';
  }

  @override
  String get plannerCanvas_compare_action => 'Comparer';

  @override
  String get plannerCanvas_compare_needTwo =>
      'Sélectionnez au moins deux plans à comparer';

  @override
  String get plannerCanvas_compare_title => 'Comparer les plans';

  @override
  String get plannerCanvas_contingency_base => 'Base';

  @override
  String get plannerCanvas_contingency_depthDelta => 'Profondeur en plus';

  @override
  String plannerCanvas_contingency_lostGas(String gas) {
    return '$gas perdu';
  }

  @override
  String plannerCanvas_contingency_previewing(String label) {
    return 'Aperçu : $label';
  }

  @override
  String get plannerCanvas_contingency_timeDelta => 'Minutes en plus';

  @override
  String plannerCanvas_chart_meanDepth(String depth) {
    return 'moyenne $depth';
  }

  @override
  String get plannerCanvas_contingency_title => 'Plans de secours';

  @override
  String get plannerCanvas_contingency_turnFraction => 'Fraction de demi-tour';

  @override
  String get plannerCanvas_contingency_turnRule =>
      'Règle de pression de demi-tour';

  @override
  String get plannerCanvas_convert_success => 'Plongée créée à partir du plan';

  @override
  String get plannerCanvas_convert_view => 'Voir';

  @override
  String plannerCanvas_follow_chip(String name) {
    return 'Suit $name';
  }

  @override
  String get plannerCanvas_follow_empty =>
      'Aucune plongée enregistrée pour l\'instant';

  @override
  String get plannerCanvas_follow_noTissues =>
      'Pas de données de profil pour cette plongée — intervalle de surface défini sans saturation des tissus';

  @override
  String get plannerCanvas_follow_title => 'Suivre une plongée';

  @override
  String plannerCanvas_gas_minGas(String pressure) {
    return 'gaz mini $pressure';
  }

  @override
  String plannerCanvas_gas_turnAt(String pressure) {
    return 'demi-tour à $pressure';
  }

  @override
  String plannerCanvas_issue_gasDensityCritical(String value) {
    return 'Densité du gaz $value g/L au-dessus de la limite stricte';
  }

  @override
  String plannerCanvas_issue_gasDensityHigh(String value) {
    return 'Densité du gaz $value g/L au-dessus de la limite recommandée';
  }

  @override
  String plannerCanvas_issue_hypoxic(String depth, String value) {
    return 'Gaz hypoxique à $depth (ppO₂ $value bar)';
  }

  @override
  String plannerCanvas_issue_minGas(String pressure) {
    return 'Le bloc finit sous le minimum rock bottom de $pressure';
  }

  @override
  String get plannerCanvas_issue_noBailout =>
      'Le plan de décompression CCR n\'emporte aucun gaz de bailout';

  @override
  String get plannerCanvas_issue_noDecoGas =>
      'Décompression requise mais aucun gaz de déco emporté';

  @override
  String get plannerCanvas_range_base => 'Base';

  @override
  String get plannerCanvas_range_legend =>
      'Les cellules indiquent le temps de remontée ; rouge = non plongeable comme prévu';

  @override
  String get plannerCanvas_pane_collapse => 'Réduire le panneau';

  @override
  String get plannerCanvas_pane_expand => 'Développer le panneau';

  @override
  String get plannerCanvas_tab_setup => 'Réglages';

  @override
  String get plannerCanvas_o2Narcotic => 'Traiter l\'O₂ comme narcotique';

  @override
  String get plannerCanvas_rates_ascent => 'Vitesse de remontée';

  @override
  String get plannerCanvas_rates_descent => 'Vitesse de descente';

  @override
  String get plannerCanvas_rates_title => 'Vitesses';

  @override
  String get plannerCanvas_range_title => 'Table de variations';

  @override
  String get plannerCanvas_results_noDeco => 'Aucune décompression requise';

  @override
  String plannerCanvas_sac_useLogged(String sac) {
    return 'Utiliser la moyenne enregistrée ($sac)';
  }

  @override
  String plannerCanvas_saved_deleteConfirmBody(String name) {
    return 'Supprimer définitivement « $name » ?';
  }

  @override
  String get plannerCanvas_saved_deleteConfirmTitle => 'Supprimer le plan ?';

  @override
  String get plannerCanvas_saved_duplicate => 'Dupliquer';

  @override
  String get plannerCanvas_saved_empty => 'Aucun plan enregistré';

  @override
  String get plannerCanvas_saved_title => 'Plans enregistrés';

  @override
  String get plannerCanvas_name_dialogTitle => 'Nommez votre plan';

  @override
  String get plannerCanvas_name_defaultFallback => 'Plan de plongée';

  @override
  String plannerCanvas_scrub_bailout(String minutes) {
    return 'BO $minutes′';
  }

  @override
  String plannerCanvas_scrub_readout(String minutes, String depth) {
    return 'RT $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_share_import => 'Importer';

  @override
  String plannerCanvas_share_importFailed(String reason) {
    return 'Impossible d\'importer le plan : $reason';
  }

  @override
  String get plannerCanvas_share_menu => 'Partager le fichier du plan';

  @override
  String get plannerCanvas_slate_menu => 'Exporter la plaquette (PDF)';

  @override
  String get plannerCanvas_slate_minGas => 'Gaz minimum';

  @override
  String get plannerCanvas_slate_turn => 'Demi-tour';

  @override
  String get plannerCanvas_table_depth => 'Profondeur';

  @override
  String get plannerCanvas_table_gas => 'Gaz';

  @override
  String get plannerCanvas_table_runtime => 'RT';

  @override
  String get plannerCanvas_table_stop => 'Palier';

  @override
  String get plannerCanvas_turnRule_allUsable => 'Tout utilisable';

  @override
  String get plannerCanvas_turnRule_custom => 'Personnalisée';

  @override
  String get plannerCanvas_turnRule_halves => 'Moitiés';

  @override
  String get plannerCanvas_turnRule_none => 'Aucune';

  @override
  String get plannerCanvas_turnRule_thirds => 'Tiers';

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
  String get planning_newPlan => 'Nouveau plan';

  @override
  String get planning_section_tools => 'Outils';

  @override
  String get planning_summary_prompt => 'Sélectionnez un outil pour commencer';

  @override
  String get planning_summary_savedPlans => 'Plans enregistrés';

  @override
  String get planning_summary_noPlans => 'Aucun plan enregistré';

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
  String get settings_about_reportIssue_copy => 'Copier le lien';

  @override
  String get settings_about_reportIssue_snackbar =>
      'Rendez-vous sur github.com/submersion-app/submersion/issues';

  @override
  String settings_about_version(String version) {
    return 'Version $version';
  }

  @override
  String get settings_appBar_title => 'Reglages';

  @override
  String get settings_appearance_appLanguage => 'Langue de l\'application';

  @override
  String get settings_appearance_displaySize => 'Taille d\'affichage';

  @override
  String settings_appearance_displaySize_value(int percent) {
    return '$percent%';
  }

  @override
  String get settings_appearance_displaySize_reset => 'Réinitialiser';

  @override
  String get settings_appearance_displaySize_smaller => 'Plus petit';

  @override
  String get settings_appearance_displaySize_larger => 'Plus grand';

  @override
  String get settings_appearance_depthColoredCards =>
      'Cartes de plongee colorees par profondeur';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'Afficher les cartes de plongee avec des fonds colores selon la profondeur';

  @override
  String get settings_appearance_cardColorAttribute => 'Colorer les cartes par';

  @override
  String get settings_appearance_cardColorAttribute_subtitle =>
      'Choisir quel attribut determine la couleur de fond des cartes';

  @override
  String get settings_appearance_cardColorAttribute_none => 'Aucun';

  @override
  String get settings_appearance_cardColorAttribute_depth => 'Profondeur';

  @override
  String get settings_appearance_cardColorAttribute_duration => 'Duree';

  @override
  String get settings_appearance_cardColorAttribute_temperature =>
      'Temperature';

  @override
  String get settings_appearance_colorGradient => 'Degrade de couleur';

  @override
  String get settings_appearance_colorGradient_subtitle =>
      'Choisir la gamme de couleurs pour les fonds de cartes';

  @override
  String get settings_appearance_colorGradient_ocean => 'Ocean';

  @override
  String get settings_appearance_colorGradient_thermal => 'Thermal';

  @override
  String get settings_appearance_colorGradient_sunset => 'Coucher de soleil';

  @override
  String get settings_appearance_colorGradient_forest => 'Foret';

  @override
  String get settings_appearance_colorGradient_monochrome => 'Monochrome';

  @override
  String get settings_appearance_colorGradient_custom => 'Personnalise';

  @override
  String get settings_appearance_gasSwitchMarkers =>
      'Marqueurs de changement de gaz';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle =>
      'Afficher les marqueurs de changement de gaz';

  @override
  String get settings_appearance_gasTimeline => 'Chronologie du gaz';

  @override
  String get settings_appearance_gasTimeline_subtitle =>
      'Afficher la bande de consommation de gaz sous le profil de plongée par défaut';

  @override
  String get settings_appearance_header_diveDetails => 'Details de la plongee';

  @override
  String get settings_appearance_header_diveLog => 'Carnet de plongee';

  @override
  String get settings_appearance_header_diveProfile => 'Profil de plongee';

  @override
  String get settings_appearance_header_diveSites => 'Sites de plongee';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility =>
      'Ordre et visibilite des sections';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility_subtitle =>
      'Choisir quelles sections s\'affichent et leur ordre';

  @override
  String get settings_diveDetailSections_title =>
      'Ordre et visibilite des sections';

  @override
  String get settings_diveDetailSections_resetToDefault =>
      'Reinitialiser par defaut';

  @override
  String get settings_diveDetailSections_fixedSections =>
      'Sections fixes : En-tete, Graphique du profil de plongee';

  @override
  String get settings_diveDetailSections_configurableSections =>
      'Sections configurables (glisser pour reordonner)';

  @override
  String get diveDetailSection_decoO2_name =>
      'Statut deco / Saturation des tissues';

  @override
  String get diveDetailSection_decoO2_description =>
      'NDL, plafond, carte thermique des tissues, toxicite O2';

  @override
  String get diveDetailSection_safetyReview_name => 'Bilan de sécurité';

  @override
  String get diveDetailSection_safetyReview_description =>
      'Observations automatiques du profil après la plongée';

  @override
  String get safetyReview_sectionTitle => 'Bilan de sécurité';

  @override
  String safetyReview_findingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observations',
      one: '1 observation',
    );
    return '$_temp0';
  }

  @override
  String safetyReview_rapidAscent_title(String rate, String duration) {
    return 'La remontée a dépassé $rate pendant $duration';
  }

  @override
  String safetyReview_missedDecoStop_title(String excess, String duration) {
    return 'La profondeur est restée $excess au-dessus du plafond de palier requis pendant $duration';
  }

  @override
  String safetyReview_omittedSafetyStop_title(String remaining) {
    return 'Le palier de sécurité recommandé a été écourté de $remaining';
  }

  @override
  String safetyReview_sawtoothProfile_title(int count) {
    return '$count variations répétées de profondeur en montée et descente pendant la plongée';
  }

  @override
  String safetyReview_highSurfaceGf_title(String gf, String gfHigh) {
    return 'Surface atteinte avec un facteur de gradient de $gf, au-dessus du $gfHigh configuré';
  }

  @override
  String safetyReview_timeRange(String start, String end) {
    return 'À $start–$end';
  }

  @override
  String get safetyReview_dismiss => 'Ignorer';

  @override
  String get safetyReview_restore => 'Restaurer';

  @override
  String get safetyReview_dismissAll => 'Tout ignorer';

  @override
  String get safetyReview_restoreAll => 'Tout restaurer';

  @override
  String get safetySettings_dismissAll => 'Ignorer toutes les observations';

  @override
  String get safetySettings_dismissAll_subtitle =>
      'Marquer comme relues toutes les observations de ce carnet';

  @override
  String get safetySettings_dismissAll_confirmTitle =>
      'Ignorer toutes les observations ?';

  @override
  String get safetySettings_dismissAll_confirmBody =>
      'Toutes les observations de toutes les plongées analysées seront marquées comme relues. Vous pouvez les restaurer plongée par plongée depuis sa section bilan de sécurité.';

  @override
  String get safetySettings_dismissAll_confirm => 'Tout ignorer';

  @override
  String get safetySettings_dismissAll_cancel => 'Annuler';

  @override
  String safetySettings_dismissAll_progress(int done, int total) {
    return '$done plongées sur $total vérifiées';
  }

  @override
  String safetySettings_dismissAll_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observations ignorées',
      one: '1 observation ignorée',
      zero: 'Aucune observation à ignorer',
    );
    return '$_temp0';
  }

  @override
  String safetySettings_dismissAll_doneWithErrors(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observations ignorées',
      one: '1 observation ignorée',
      zero: 'Aucune observation ignorée',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failed plongées n’ont pas pu être mises à jour',
      one: '1 plongée n’a pas pu être mise à jour',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get safetySettings_dismissAll_failed =>
      'Impossible de lire la liste des plongées. Rien n’a été modifié.';

  @override
  String get safetySettings_analyzeAll_failed =>
      'Impossible d’analyser les plongées.';

  @override
  String get safetyReview_details => 'Détails';

  @override
  String get safetyReview_clearHighlight => 'Effacer la surbrillance';

  @override
  String safetyReview_findingGroupSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observations de sécurité',
      one: '1 observation de sécurité',
    );
    return '$_temp0';
  }

  @override
  String get safetySettings_title => 'Bilan de sécurité';

  @override
  String get safetySettings_entry_subtitle =>
      'Observations et règles après la plongée';

  @override
  String get safetySettings_masterToggle =>
      'Bilan de sécurité après la plongée';

  @override
  String get safetySettings_masterToggle_subtitle =>
      'Noter automatiquement les observations de remontée, de paliers et de profil sur les plongées analysées';

  @override
  String get safetySettings_rulesHeader => 'Règles';

  @override
  String get safetySettings_rule_rapidAscent => 'Remontées rapides';

  @override
  String get safetySettings_rule_missedDecoStop =>
      'Paliers de déco manqués ou écourtés';

  @override
  String get safetySettings_rule_omittedSafetyStop =>
      'Paliers de sécurité omis';

  @override
  String get safetySettings_rule_sawtoothProfile => 'Profils en dents de scie';

  @override
  String get safetySettings_rule_highSurfaceGf =>
      'Facteur de gradient élevé en surface';

  @override
  String get safetySettings_analyzeAll => 'Analyser toutes les plongées';

  @override
  String get safetySettings_analyzeAll_subtitle =>
      'Exécuter le bilan de sécurité sur toutes les plongées avec profil pas encore analysées';

  @override
  String safetySettings_analyzeAll_progress(int done, int total) {
    return '$done sur $total analysées';
  }

  @override
  String get safetySettings_analyzeAll_done => 'Analyse terminée';

  @override
  String safetySettings_analyzeAll_doneWithErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongées n\'ont pas pu être analysées',
      one: '1 plongée n\'a pas pu être analysée',
    );
    return 'Analyse terminée — $_temp0';
  }

  @override
  String safetyReview_showDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Afficher $count ignorées',
      one: 'Afficher 1 ignorée',
    );
    return '$_temp0';
  }

  @override
  String get diveDetailSection_sacSegments_name => 'SAC par segment';

  @override
  String get diveDetailSection_sacSegments_description =>
      'Segmentation SAC par phase/temps';

  @override
  String get diveDetailSection_details_name => 'Details';

  @override
  String get diveDetailSection_details_description =>
      'Type, lieu, voyage, centre de plongee, intervalle';

  @override
  String get diveDetailSection_environment_name => 'Environnement';

  @override
  String get diveDetailSection_environment_description =>
      'Temperature air/eau, visibilite, courant';

  @override
  String get diveDetailSection_altitude_name => 'Altitude';

  @override
  String get diveDetailSection_altitude_description =>
      'Valeur d\'altitude, categorie, exigence deco';

  @override
  String get diveDetailSection_tide_name => 'Maree';

  @override
  String get diveDetailSection_tide_description =>
      'Graphique du cycle de maree et horaires';

  @override
  String get diveDetailSection_reefHealth_name => 'Conditions de l\'eau';

  @override
  String get diveDetailSection_reefHealth_description =>
      'Conditions de l\'eau par satellite à la date de la plongée';

  @override
  String get diveDetailSection_surfaceGps_name => 'GPS de surface';

  @override
  String get diveDetailSection_surfaceGps_description =>
      'Points GPS de mise à l\'eau/sortie et dérive en surface';

  @override
  String get diveLog_detail_section_surfaceGps => 'GPS de surface';

  @override
  String get diveLog_detail_surfaceGps_entry => 'Mise à l\'eau';

  @override
  String get diveLog_detail_surfaceGps_exit => 'Sortie';

  @override
  String get diveLog_detail_label_drift => 'Dérive';

  @override
  String get diveLog_detail_surfaceGps_entryOnly =>
      'Point de mise à l\'eau enregistré';

  @override
  String get diveLog_detail_surfaceGps_exitOnly => 'Point de sortie enregistré';

  @override
  String get diveLog_detail_surfaceGps_site => 'Site';

  @override
  String get diveLog_detail_surfaceGps_track => 'Trace de surface';

  @override
  String get diveLog_detail_surfaceGps_showFullTrack => 'Trace complète';

  @override
  String diveLog_detail_surfaceGps_trackFixes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_detail_locationsMap_title => 'Lieux de plongée';

  @override
  String get diveLog_detail_coordinatesCopied =>
      'Coordonnées copiées dans le presse-papiers';

  @override
  String get diveLog_detail_openInMaps => 'Ouvrir dans Plans';

  @override
  String get diveDetailSection_weights_name => 'Lestage';

  @override
  String get diveDetailSection_weights_description =>
      'Repartition des lests, poids total';

  @override
  String get diveDetailSection_buoyancy_name => 'Flottabilité';

  @override
  String get diveDetailSection_buoyancy_description =>
      'Flottabilité pendant la plongée, variation, lest largable';

  @override
  String get buoyancy_tooltip =>
      'Flottabilité nette modélisée pendant la plongée d\'après le profil, la consommation de gaz et l\'équipement.';

  @override
  String buoyancy_verdictBuoyant(String depth, String amount) {
    return 'À votre dernier palier (~$depth), vous aviez environ $amount de portance';
  }

  @override
  String buoyancy_verdictHeavy(String depth, String amount) {
    return 'À votre dernier palier (~$depth), vous étiez environ $amount trop lourd';
  }

  @override
  String get buoyancy_verdictNeutral =>
      'Votre configuration était proche de la neutralité au dernier palier';

  @override
  String get buoyancy_verdictConvention =>
      'Estimé selon la convention du palier de sécurité à 5 m';

  @override
  String get buoyancy_breakdownTitle => 'Détail des termes';

  @override
  String get buoyancy_suitTerm => 'Combinaison';

  @override
  String get buoyancy_leadTerm => 'Lest';

  @override
  String get buoyancy_beginNet => 'Début de plongée';

  @override
  String get buoyancy_endNet => 'Fin de plongée';

  @override
  String get buoyancy_swing => 'Variation de flottabilité';

  @override
  String get buoyancy_peakLift => 'Portance maximale requise';

  @override
  String get buoyancy_wingWarning =>
      'Dépasse la portance nominale de votre wing';

  @override
  String get buoyancy_minDitchable => 'Lest largable minimal';

  @override
  String get buoyancy_droppable => 'Largable';

  @override
  String get buoyancy_ditchWarning => 'Plus que ce que vous pouvez larguer';

  @override
  String get buoyancy_drysuitGas => 'Gaz d\'étanche ajouté';

  @override
  String get buoyancy_estimatedPressures =>
      'Les pressions des blocs sont estimées';

  @override
  String get buoyancy_linkSuitHint =>
      'Associez une combinaison à cette plongée pour un tableau plus complet';

  @override
  String get buoyancy_noLeadHint =>
      'Aucun lest enregistré : ajoutez du lest à cette plongée ou un poids à sec à votre équipement de lestage';

  @override
  String get buoyancy_chartNet => 'Net';

  @override
  String get buoyancy_chartRig => 'Équipement + lest';

  @override
  String get buoyancy_chartMinutes => 'Temps (min)';

  @override
  String get buoyancy_historyTitle => 'Historique de lestage';

  @override
  String get buoyancy_historyCarried => 'Porté';

  @override
  String get buoyancy_historyModeled => 'Modélisé';

  @override
  String buoyancy_historyMore(String delta) {
    return 'Vous portez généralement $delta de plus que ce que le modèle suggère';
  }

  @override
  String buoyancy_historyLess(String delta) {
    return 'Vous portez généralement $delta de moins que ce que le modèle suggère';
  }

  @override
  String get buoyancy_throughDive => 'Pendant la plongée';

  @override
  String get buoyancy_adjust => 'Ajuster';

  @override
  String get buoyancy_whatIfTitle => 'Ajuster cette plongée';

  @override
  String get buoyancy_whatIfLead => 'Lest';

  @override
  String get buoyancy_whatIfSuit => 'Flottabilité de la combinaison';

  @override
  String get buoyancy_whatIfReset => 'Réinitialiser';

  @override
  String buoyancy_whatIfDelta(String delta) {
    return '$delta vs réel';
  }

  @override
  String get diveDetailSection_tanks_name => 'Bouteilles';

  @override
  String get diveDetailSection_tanks_description =>
      'Liste des bouteilles, melanges gazeux, pressions, SAC par bouteille';

  @override
  String get diveDetailSection_buddies_name => 'Binomes';

  @override
  String get diveDetailSection_buddies_description =>
      'Liste des binomes avec leurs roles';

  @override
  String get diveDetailSection_signatures_name => 'Signatures';

  @override
  String get diveDetailSection_signatures_description =>
      'Affichage et capture de signatures binome/instructeur';

  @override
  String get diveDetailSection_equipment_name => 'Equipement';

  @override
  String get diveDetailSection_equipment_description =>
      'Equipement utilise lors de la plongee';

  @override
  String get diveDetailSection_sightings_name => 'Observations de vie marine';

  @override
  String get diveDetailSection_sightings_description =>
      'Especes observees, details des observations';

  @override
  String get diveDetailSection_media_name => 'Medias';

  @override
  String get diveDetailSection_media_description => 'Galerie photos/videos';

  @override
  String get diveDetailSection_tags_name => 'Tags';

  @override
  String get diveDetailSection_tags_description => 'Tags de la plongee';

  @override
  String get diveDetailSection_notes_name => 'Notes';

  @override
  String get diveDetailSection_notes_description =>
      'Notes/description de la plongee';

  @override
  String get diveDetailSection_customFields_name => 'Champs personnalises';

  @override
  String get diveDetailSection_customFields_description =>
      'Champs personnalises definis par l\'utilisateur';

  @override
  String get diveDetailSection_dataSources_name => 'Sources de donnees';

  @override
  String get diveDetailSection_dataSources_description =>
      'Ordinateurs de plongee connectes, gestion des sources';

  @override
  String get settings_appearance_header_language => 'Langue';

  @override
  String get settings_appearance_header_theme => 'Theme';

  @override
  String get settings_appearance_header_mode => 'Mode';

  @override
  String get settings_themes_title => 'Choisir le theme';

  @override
  String get settings_themes_current => 'Theme';

  @override
  String get theme_submersion => 'Submersion';

  @override
  String get theme_console => 'Console';

  @override
  String get theme_tropical => 'Tropical';

  @override
  String get theme_minimalist => 'Minimaliste';

  @override
  String get theme_deep => 'Abyssal';

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
  String get settings_appearance_metric_estimatedTankPressure =>
      'Pression estimée du bloc';

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
  String get settings_appearance_metric_cns => 'CNS% (Toxicite O2)';

  @override
  String get settings_appearance_metric_otu => 'OTU (Unites de tolerance O2)';

  @override
  String get settings_appearance_metric_photoMarkers => 'Marqueurs de photos';

  @override
  String settings_appearance_metricsEnabledCount(int count, int total) {
    return '$count sur $total actives';
  }

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
  String get settings_appearance_metricsFollowViewport =>
      'Garder les superpositions visibles lors du zoom';

  @override
  String get settings_appearance_metricsFollowViewport_subtitle =>
      'Ajuster les superpositions telles que NDL et ppO2 à la zone visible au lieu de les agrandir avec l\'axe de profondeur';

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
  String get settings_appearance_subsection_standardMetrics =>
      'Standard Metrics';

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
  String get settings_backToSettings_tooltip => 'Retour aux reglages';

  @override
  String get settings_cloudSync_appBar_title =>
      'Synchronisation cloud de la base de donnees';

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
  String get settings_cloudSync_entry_subtitle =>
      'Synchronisation via le stockage cloud';

  @override
  String get settings_cloudSync_adopt_confirm =>
      'Adopter la bibliothèque restaurée';

  @override
  String settings_cloudSync_adopt_dialogContent(
    String deviceName,
    String date,
  ) {
    return 'La bibliothèque a été remplacée à partir d\'une sauvegarde sur « $deviceName » ($date). En l\'adoptant, les données de cet appareil seront remplacées par la bibliothèque restaurée. Une sauvegarde de sécurité des données actuelles de cet appareil sera d\'abord créée.';
  }

  @override
  String get settings_cloudSync_adopt_dialogTitle =>
      'Adopter la bibliothèque restaurée ?';

  @override
  String get settings_cloudSync_adopt_notNow => 'Pas maintenant';

  @override
  String get settings_cloudSync_dangerZone => 'Zone sensible';

  @override
  String get settings_cloudSync_replaceLibrary_tile =>
      'Remplacer la bibliothèque cloud';

  @override
  String get settings_cloudSync_replaceLibrary_tileSubtitle =>
      'Faire de la bibliothèque de cet appareil celle que tous les appareils utilisent';

  @override
  String get settings_cloudSync_replaceLibrary_dialogTitle =>
      'Remplacer la bibliothèque cloud ?';

  @override
  String get settings_cloudSync_replaceLibrary_dialogIntro =>
      'La bibliothèque de cet appareil devient celle que tous les appareils utilisent.';

  @override
  String settings_cloudSync_replaceLibrary_dialogBody(num diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other:
          'La bibliothèque cloud est effacée et remplacée par les $diveCount plongées de cet appareil.',
      one:
          'La bibliothèque cloud est effacée et remplacée par la 1 plongée de cet appareil.',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_replaceLibrary_peers(num peerCount) {
    String _temp0 = intl.Intl.pluralLogic(
      peerCount,
      locale: localeName,
      other:
          '$peerCount autres appareils devront l\'adopter ; d\'ici là, leurs modifications ne sont pas fusionnées.',
      one:
          '1 autre appareil devra l\'adopter ; d\'ici là, ses modifications ne sont pas fusionnées.',
      zero:
          'Aucun autre appareil ne se synchronise encore, il n\'y a donc rien à adopter.',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_replaceLibrary_peersUnknown =>
      'Tous les autres appareils devront l\'adopter ; d\'ici là, leurs modifications ne sont pas fusionnées.';

  @override
  String get settings_cloudSync_replaceLibrary_backupNote =>
      'Une sauvegarde de cet appareil est créée au préalable. Cette action est irréversible.';

  @override
  String get settings_cloudSync_replaceLibrary_confirmWord => 'Remplacer';

  @override
  String get settings_cloudSync_replaceLibrary_confirmHint =>
      'Tapez \"Remplacer\" pour confirmer';

  @override
  String get settings_cloudSync_replaceLibrary_confirm => 'Remplacer';

  @override
  String get settings_cloudSync_firstSync_banner =>
      'La première synchronisation attend votre confirmation. Appuyez sur « Synchroniser maintenant » pour vérifier ce qui sera combiné.';

  @override
  String get settings_cloudSync_firstSync_dialogConfirm =>
      'Fusionner et synchroniser';

  @override
  String get settings_cloudSync_firstSync_replaceHint =>
      'Si au contraire la bibliothèque de cet appareil doit remplacer celle du cloud, annulez et utilisez Réglages > Synchronisation cloud > Remplacer la bibliothèque cloud.';

  @override
  String settings_cloudSync_firstSync_dialogContent(
    int deviceCount,
    int diveCount,
  ) {
    return 'Des données de synchronisation existantes ont été trouvées dans le cloud ($deviceCount fichier(s) de synchronisation). Votre première synchronisation combinera ces données avec les $diveCount plongée(s) de cet appareil, sur tous les appareils synchronisés.\n\nSi les mêmes plongées ont été ajoutées séparément sur chaque appareil, elles apparaîtront en double.';
  }

  @override
  String get settings_cloudSync_firstSync_dialogTitle =>
      'Combiner les bibliothèques ?';

  @override
  String settings_cloudSync_replace_banner(String deviceName) {
    return 'Synchronisation en pause : la bibliothèque a été remplacée à partir d\'une sauvegarde sur « $deviceName ». Touchez Synchroniser maintenant pour vérifier.';
  }

  @override
  String get settings_cloudSync_switch_dialogTitle =>
      'Changer de service de synchronisation ?';

  @override
  String settings_cloudSync_switch_dialogContent(
    String fromName,
    String toName,
  ) {
    return 'Vos données ne seront pas retirées de $fromName : elles y restent jusqu\'à ce que vous les supprimiez. Après le changement, la prochaine synchronisation de cet appareil combine ses données avec ce qui existe déjà sur $toName. Vos autres appareils continuent d\'utiliser $fromName jusqu\'à ce que vous changiez chacun d\'eux également.';
  }

  @override
  String get settings_cloudSync_switch_confirm => 'Changer';

  @override
  String settings_cloudSync_moved_banner(
    String deviceName,
    String destination,
  ) {
    return '$deviceName a déplacé cette bibliothèque vers $destination. Ce service n\'est plus mis à jour par celui-ci. Sélectionnez $destination ci-dessous pour suivre le déplacement.';
  }

  @override
  String get settings_cloudSync_moved_dismiss => 'Ignorer';

  @override
  String settings_cloudSync_cleanup_banner(String backend) {
    return 'D\'anciennes données de synchronisation, datant d\'avant votre changement de service, sont toujours stockées sur $backend. Elles ne sont plus utilisées.';
  }

  @override
  String get settings_cloudSync_cleanup_delete =>
      'Supprimer les anciennes données';

  @override
  String get settings_cloudSync_cleanup_keep => 'Conserver';

  @override
  String get settings_cloudSync_header_advanced => 'Avance';

  @override
  String get settings_cloudSync_signOut_backupWarning =>
      'La sauvegarde cloud sera désactivée et les sauvegardes seront enregistrées à l\'emplacement par défaut.';

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
  String settings_cloudSync_peerNeedsAdopt_banner(Object deviceList) {
    return '$deviceList a encore une version de bibliothèque plus ancienne ou inconnue, ses modifications n\'ont donc pas été fusionnées. Ouvrez Submersion dessus pour adopter la bibliothèque actuelle.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_bannerPlural(Object deviceList) {
    return '$deviceList ont encore une version de bibliothèque plus ancienne ou inconnue, leurs modifications n\'ont donc pas été fusionnées. Ouvrez Submersion dessus pour adopter la bibliothèque actuelle.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_unnamedDevice(Object shortId) {
    return 'appareil $shortId';
  }

  @override
  String get settings_cloudSync_peerNeedsAdopt_listSeparator => ', ';

  @override
  String get settings_cloudSync_peerNeedsAdopt_listLastSeparator => ' et ';

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamed(Object deviceList) {
    return '$deviceList se synchronise depuis une version plus récente de Submersion, ses derniers changements sont donc retenus pour le moment.';
  }

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamedPlural(
    Object deviceList,
  ) {
    return '$deviceList se synchronisent depuis une version plus récente de Submersion, leurs derniers changements sont donc retenus pour le moment.';
  }

  @override
  String get settings_cloudSync_peerRequiresUpdate_updateAction =>
      'Mettez à jour cet appareil pour les recevoir.';

  @override
  String get settings_cloudSync_peerRequiresUpdate_storeAction =>
      'Ils seront appliqués automatiquement dès que la mise à jour arrivera sur la boutique d\'applications de cet appareil ; elle est peut-être encore en cours d\'examen.';

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
  String get settings_cloudSync_dropbox_account_title => 'Compte Dropbox';

  @override
  String get settings_cloudSync_dropbox_connect_browserFailed =>
      'Impossible d\'ouvrir le navigateur. Essayez le bouton Rouvrir le navigateur.';

  @override
  String get settings_cloudSync_dropbox_connect_codeLabel =>
      'Code d\'autorisation';

  @override
  String get settings_cloudSync_dropbox_connect_emptyCode =>
      'Saisissez le code d\'autorisation affiché dans votre navigateur';

  @override
  String settings_cloudSync_dropbox_connect_failed(Object error) {
    return 'Impossible de se connecter à Dropbox : $error';
  }

  @override
  String get settings_cloudSync_dropbox_connect_instructions =>
      'Votre navigateur a ouvert une page d\'autorisation Dropbox. Approuvez l\'accès, puis collez ici le code affiché par Dropbox.';

  @override
  String get settings_cloudSync_dropbox_connect_reopenBrowser =>
      'Rouvrir le navigateur';

  @override
  String get settings_cloudSync_dropbox_connect_submit => 'Connecter';

  @override
  String get settings_cloudSync_dropbox_connect_title => 'Connecter Dropbox';

  @override
  String get settings_cloudSync_dropbox_connected => 'Connecté à Dropbox';

  @override
  String settings_cloudSync_dropbox_connectedAs(Object account) {
    return 'Connecté en tant que $account';
  }

  @override
  String get settings_cloudSync_dropbox_disconnect => 'Déconnecter';

  @override
  String get settings_cloudSync_provider_dropbox_subtitle =>
      'Synchroniser via Dropbox (Apps/Submersion)';

  @override
  String get settings_cloudSync_provider_dropbox_title => 'Dropbox';

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'Synchroniser via Google Drive';

  @override
  String get settings_cloudSync_googleDrive_desktopNotConfigured =>
      'Indisponible dans cette version';

  @override
  String get settings_cloudSync_googleDrive_browserWait_title =>
      'Continuez dans votre navigateur';

  @override
  String get settings_cloudSync_googleDrive_browserWait_message =>
      'Terminez la connexion à Google dans votre navigateur web, puis revenez à Submersion.';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'Echec de l\'initialisation du fournisseur $providerName';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'Non disponible sur cette plateforme';

  @override
  String get settings_cloudSync_provider_s3_edit =>
      'Modifier la configuration S3';

  @override
  String get settings_cloudSync_provider_s3_subtitle =>
      'Fonctionne avec tout service de stockage compatible S3';

  @override
  String get settings_cloudSync_provider_s3_title => 'Stockage compatible S3';

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
  String get settings_conflict_ref_buddy => 'Binome';

  @override
  String get settings_conflict_ref_certification => 'Certification';

  @override
  String get settings_conflict_ref_checklistTemplate =>
      'Modele de liste de controle';

  @override
  String get settings_conflict_ref_connectedAccount => 'Compte connecte';

  @override
  String get settings_conflict_ref_course => 'Cours';

  @override
  String get settings_conflict_ref_courseRequirement => 'Exigence du cours';

  @override
  String get settings_conflict_ref_cylinderConfig => 'Configuration de blocs';

  @override
  String get settings_conflict_ref_dataSource => 'Source de donnees';

  @override
  String get settings_conflict_ref_dive => 'Plongee';

  @override
  String get settings_conflict_ref_diveCenter => 'Centre de plongee';

  @override
  String get settings_conflict_ref_diveComputer => 'Ordinateur de plongee';

  @override
  String get settings_conflict_ref_divePlan => 'Plan de plongee';

  @override
  String get settings_conflict_ref_diveSite => 'Site de plongee';

  @override
  String get settings_conflict_ref_diveType => 'Type de plongee';

  @override
  String get settings_conflict_ref_diver => 'Plongeur';

  @override
  String get settings_conflict_ref_equipment => 'Equipement';

  @override
  String get settings_conflict_ref_equipmentSet => 'Ensemble d\'equipement';

  @override
  String get settings_conflict_ref_finding => 'Anomalie';

  @override
  String get settings_conflict_ref_instructor => 'Moniteur';

  @override
  String get settings_conflict_ref_linkedDive => 'Plongee liee';

  @override
  String get settings_conflict_ref_media => 'Medias';

  @override
  String get settings_conflict_ref_mediaSubscription => 'Abonnement media';

  @override
  String get settings_conflict_ref_missing =>
      'N\'est plus dans cette bibliotheque';

  @override
  String settings_conflict_ref_named(Object name, Object date) {
    return '$name ($date)';
  }

  @override
  String get settings_conflict_ref_plannedTank => 'Bloc planifie';

  @override
  String get settings_conflict_ref_preDiveChecklistTemplate =>
      'Modele de liste avant plongee';

  @override
  String get settings_conflict_ref_preDiveSession => 'Liste avant plongee';

  @override
  String get settings_conflict_ref_relatedDive => 'Plongee associee';

  @override
  String get settings_conflict_ref_serviceKind => 'Type de revision';

  @override
  String get settings_conflict_ref_sighting => 'Observation';

  @override
  String get settings_conflict_ref_signer => 'Signe par';

  @override
  String get settings_conflict_ref_sourceDive => 'Plongee source';

  @override
  String get settings_conflict_ref_species => 'Especes';

  @override
  String get settings_conflict_ref_tag => 'Etiquette';

  @override
  String get settings_conflict_ref_tank => 'Bloc';

  @override
  String get settings_conflict_ref_trip => 'Voyage';

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
  String get settings_data_backup => 'Sauvegarde et restauration';

  @override
  String get settings_data_backup_subtitle =>
      'Creer une sauvegarde de vos donnees';

  @override
  String get settings_data_cloudSync =>
      'Synchronisation cloud de la base de donnees';

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
  String get settings_decompression_header_oxygenToxicity =>
      'Toxicité de l\'oxygène';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return 'Selectionner le niveau de conservatisme $presetName';
  }

  @override
  String get settings_decompression_header_narcosis => 'Narcose';

  @override
  String get settings_decompression_o2Narcotic => 'O2 est narcotique';

  @override
  String get settings_decompression_o2Narcotic_subtitle =>
      'Lorsque active, O2 et N2 sont consideres comme narcotiques (plus conservateur). Lorsque desactive, seul N2 contribue a la narcose.';

  @override
  String get settings_decompression_endLimit => 'Limite END';

  @override
  String get settings_decompression_endLimit_subtitle =>
      'Profondeur narcotique equivalente maximale utilisee pour les calculs de MND';

  @override
  String get settings_decompression_endLimit_dialog_title => 'Limite END';

  @override
  String get settings_decompression_cnsMethodTitle => 'Calcul du CNS';

  @override
  String get settings_decompression_cnsMethodClassic =>
      'Table NOAA, par paliers (classique)';

  @override
  String get settings_decompression_cnsMethodClassicDesc =>
      'Calcule chaque plage de 0,1 bar à sa limite la plus stricte. Méthode d\'origine de Submersion.';

  @override
  String get settings_decompression_cnsMethodShearwater =>
      'Interpolation linéaire (style Shearwater)';

  @override
  String get settings_decompression_cnsMethodShearwaterDesc =>
      'Interpole entre les limites NOAA telles que documentées par Shearwater. Correspond à la plupart des ordinateurs de plongée.';

  @override
  String get settings_decompression_cnsMethodSubsurface =>
      'Ajustement exponentiel (comme Subsurface)';

  @override
  String get settings_decompression_cnsMethodSubsurfaceDesc =>
      'Ajustement de courbe lisse sur la table NOAA. Correspond au CNS calculé par Subsurface.';

  @override
  String get settings_decompression_cnsMethodAboutTitle =>
      'À propos de ces méthodes';

  @override
  String get settings_decompression_cnsMethodAboutBody =>
      'Les trois méthodes reposent sur les limites d\'exposition à l\'oxygène du NOAA Diving Manual (300 minutes à un ppO2 de 1,0 bar, 45 minutes à 1,6 bar). La table ne définit des limites que par pas de 0,1 bar : la méthode classique calcule tout ce qui se trouve dans une plage à la limite la plus stricte de celle-ci, ce qui surestime systématiquement l\'exposition entre les valeurs. Les ordinateurs de plongée Shearwater documentent une interpolation linéaire entre les limites NOAA, avec un taux fixe de 15 % par minute au-dessus de 1,65 bar. En 2019, Subsurface a remplacé sa recherche par table par un ajustement exponentiel lisse en deux segments sur les mêmes données NOAA (Robert C. Helling), qui s\'étend aussi naturellement au-delà de 1,6 bar. Entre les valeurs de la table, les deux méthodes lisses concordent à environ un point de CNS près ; la méthode classique affiche des valeurs plus élevées.';

  @override
  String get settings_decompression_cnsMethodDisclaimer =>
      'Les noms font référence aux méthodes publiées des projets et fabricants respectifs ; aucune affiliation ni approbation n\'est sous-entendue. Les valeurs calculées peuvent différer des relevés réels de l\'ordinateur de plongée.';

  @override
  String get settings_decompression_cnsMethodSourcesTitle => 'Sources';

  @override
  String get settings_linkOpenFailed => 'Impossible d\'ouvrir le lien.';

  @override
  String get settings_decompression_cnsMethodSourceNoaa =>
      'NOAA : Diving Program (éditeur du NOAA Diving Manual)';

  @override
  String get settings_decompression_cnsMethodSourceShearwater =>
      'Shearwater : l\'horloge à oxygène CNS';

  @override
  String get settings_decompression_cnsMethodSourceTheoreticalDiver =>
      'The Theoretical Diver : calcul de la toxicité CNS de l\'oxygène';

  @override
  String get settings_decompression_cnsMethodSourceSubsurface =>
      'Subsurface : implémentation (divelist.cpp)';

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
  String get settings_import_cancelButton => 'Annuler l\'importation';

  @override
  String get settings_import_cancelling => 'Annulation...';

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
  String get settings_import_phase_courses => 'Importing courses...';

  @override
  String get settings_import_phase_applyingTags => 'Applying tags...';

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
  String get settings_lightroom_albumFilter_all => 'Catalogue entier';

  @override
  String get settings_lightroom_albumFilter_title => 'Albums à analyser';

  @override
  String get settings_lightroom_autoPoll_title =>
      'Rechercher automatiquement les nouvelles photos';

  @override
  String settings_lightroom_clientId_help(String redirectUri) {
    return 'Créez une intégration dans l\'Adobe Developer Console avec l\'API Lightroom Services et un type d\'identifiant compatible PKCE. Saisissez ci-dessous l\'URI de redirection de votre identifiant — les identifiants Native App utilisent un schéma personnalisé — ou laissez le champ vide pour utiliser $redirectUri.';
  }

  @override
  String get settings_lightroom_clientId_label => 'ID client Adobe';

  @override
  String get settings_lightroom_clientSecret_label =>
      'Secret client (facultatif)';

  @override
  String get settings_lightroom_redirectUri_label =>
      'URI de redirection (facultatif)';

  @override
  String get settings_lightroom_connect => 'Connecter Lightroom';

  @override
  String get settings_lightroom_connectEmbedded => 'Se connecter avec Adobe';

  @override
  String get settings_lightroom_advancedByo =>
      'Utiliser vos propres identifiants Adobe';

  @override
  String get settings_lightroom_connect_codeLabel => 'URL redirigée ou code';

  @override
  String get settings_lightroom_connect_emptyCode =>
      'Collez l\'URL redirigée ou le code d\'autorisation';

  @override
  String settings_lightroom_connect_failed(String error) {
    return 'Impossible de se connecter à Lightroom : $error';
  }

  @override
  String get settings_lightroom_connect_instructions =>
      'Connectez-vous à Adobe dans la fenêtre du navigateur, puis collez l\'adresse complète de la page sur laquelle vous arrivez (elle contient le code d\'autorisation).';

  @override
  String get settings_lightroom_connect_reopenBrowser =>
      'Rouvrir le navigateur';

  @override
  String get settings_lightroom_connect_submit => 'Connecter';

  @override
  String get settings_lightroom_connect_title => 'Connecter Lightroom';

  @override
  String settings_lightroom_connected(String name) {
    return 'Connecté en tant que $name';
  }

  @override
  String get settings_lightroom_disconnect => 'Déconnecter';

  @override
  String get settings_lightroom_disconnect_confirmBody =>
      'Les photos liées restent sur vos plongées et continuent de s\'afficher depuis le stockage multimédia. Les nouvelles photos ne seront plus associées.';

  @override
  String get settings_lightroom_disconnect_confirmTitle =>
      'Déconnecter Lightroom ?';

  @override
  String settings_lightroom_lastPoll(String when) {
    return 'Dernière vérification : $when';
  }

  @override
  String get settings_lightroom_needsReauth => 'Reconnexion requise';

  @override
  String get settings_lightroom_scanNow => 'Analyser Lightroom';

  @override
  String get settings_lightroom_scan_running => 'Analyse de Lightroom...';

  @override
  String settings_lightroom_scan_summary(
    int attached,
    int suggested,
    int skipped,
  ) {
    return '$attached liées, $suggested suggérées, $skipped déjà liées';
  }

  @override
  String get settings_lightroom_subtitle =>
      'Associer automatiquement photos et vidéos aux plongées';

  @override
  String get settings_lightroom_title => 'Adobe Lightroom';

  @override
  String get settings_manage_checklistTemplates =>
      'Modèles de liste de contrôle';

  @override
  String get settings_manage_checklistTemplates_subtitle =>
      'Listes de tâches réutilisables pour la planification de voyages';

  @override
  String get settings_manage_diveRoles => 'Rôles de plongée';

  @override
  String get settings_manage_diveRoles_subtitle =>
      'Gérer les rôles de plongée personnalisés';

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
  String get settings_manage_tags => 'Etiquettes';

  @override
  String get settings_manage_tags_subtitle =>
      'Gerer, fusionner et supprimer les etiquettes';

  @override
  String get settings_manage_tankPresets => 'Preselections de blocs';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Gerer les configurations de blocs personnalisees';

  @override
  String get settings_manage_serviceTypes => 'Types de révision';

  @override
  String get settings_manage_serviceTypes_subtitle =>
      'L\'entretien dont votre matériel a besoin, et à quelle fréquence';

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
  String get settings_notifications_disabled_continueButton => 'Continuer';

  @override
  String get settings_notifications_disabled_openSettingsButton =>
      'Ouvrir les reglages';

  @override
  String get settings_notifications_disabled_subtitleUnrequested =>
      'Les rappels d\'entretien necessitent l\'autorisation d\'envoyer des notifications';

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
  String get settings_profileHub_addNewDiver => 'Ajouter un nouveau plongeur';

  @override
  String get settings_profileHub_cannotDeleteOnly =>
      'Impossible de supprimer le seul profil de plongeur';

  @override
  String get settings_profileHub_createDiverTitle => 'Creer un plongeur';

  @override
  String settings_profileHub_deleteConfirmContent(String name) {
    return 'Etes-vous sur de vouloir supprimer $name ? Tous les carnets de plongee associes seront desassignes.';
  }

  @override
  String get settings_profileHub_deleteConfirmTitle =>
      'Supprimer le plongeur ?';

  @override
  String get settings_profileHub_deleteDiver => 'Supprimer le plongeur';

  @override
  String get settings_profileHub_deleted => 'Plongeur supprime';

  @override
  String get settings_profileHub_emergencyContacts => 'Contacts d\'urgence';

  @override
  String settings_profileHub_emergencyContacts_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts definis',
      one: '1 contact defini',
      zero: 'Non defini',
    );
    return '$_temp0';
  }

  @override
  String get settings_profileHub_insurance => 'Assurance';

  @override
  String get settings_profileHub_insurance_expired => 'Expiree';

  @override
  String get settings_profileHub_insurance_notSet => 'Non defini';

  @override
  String get settings_profileHub_medicalInfo => 'Informations medicales';

  @override
  String get settings_profileHub_medicalInfo_notSet => 'Non defini';

  @override
  String get settings_profileHub_notes => 'Notes';

  @override
  String get settings_profileHub_notes_notSet => 'Non defini';

  @override
  String get settings_profileHub_personalInfo => 'Informations personnelles';

  @override
  String get settings_profileHub_personalInfo_notSet => 'Non defini';

  @override
  String get settings_profileHub_saved => 'Modifications enregistrees';

  @override
  String get settings_profileHub_switchDiver => 'Changer de plongeur';

  @override
  String get settings_s3Config_action_remove => 'Supprimer la configuration';

  @override
  String get settings_s3Config_action_testConnection => 'Tester la connexion';

  @override
  String get settings_s3Config_advanced_title => 'Avancé';

  @override
  String get settings_s3Config_appBar_title => 'Stockage compatible S3';

  @override
  String get settings_s3Config_error_secureStorage =>
      'Impossible d\'accéder au stockage sécurisé';

  @override
  String get settings_s3Config_field_accessKeyId_label => 'Access Key ID';

  @override
  String get settings_s3Config_field_bucket_label => 'Bucket';

  @override
  String get settings_s3Config_field_endpoint_helper =>
      'Par exemple : https://s3.example.com';

  @override
  String get settings_s3Config_field_endpoint_label =>
      'URL du point de terminaison';

  @override
  String get settings_s3Config_field_pathStyle_label =>
      'Utiliser l\'adressage path-style';

  @override
  String get settings_s3Config_field_pathStyle_subtitle =>
      'Requis par la plupart des serveurs auto-hébergés';

  @override
  String get settings_s3Config_field_prefix_label => 'Préfixe de clés';

  @override
  String settings_s3Config_field_region_helperAuto(String region) {
    return 'Détection automatique : $region';
  }

  @override
  String get settings_s3Config_field_region_label => 'Région';

  @override
  String get settings_s3Config_field_secretAccessKey_label =>
      'Secret Access Key';

  @override
  String get settings_s3Config_remove_confirm_action => 'Supprimer';

  @override
  String get settings_s3Config_remove_confirm_body =>
      'La synchronisation via S3 s\'arrêtera sur cet appareil. Vos données dans le bucket ne sont pas supprimées.';

  @override
  String get settings_s3Config_remove_confirm_title =>
      'Supprimer la configuration S3 ?';

  @override
  String get settings_s3Config_removed => 'Configuration S3 supprimée';

  @override
  String get settings_s3Config_saved => 'Configuration S3 enregistrée';

  @override
  String settings_s3Config_test_regionDetected(String region) {
    return 'Région détectée : $region';
  }

  @override
  String get settings_s3Config_test_success => 'Connexion réussie';

  @override
  String get settings_s3Config_validation_endpointInvalid =>
      'Saisissez une URL http:// ou https:// valide';

  @override
  String get settings_s3Config_validation_endpointPath =>
      'L\'URL du point de terminaison ne doit pas inclure de chemin';

  @override
  String get settings_s3Config_validation_required => 'Obligatoire';

  @override
  String get settings_s3Config_warning_http =>
      'Ce point de terminaison utilise HTTP non chiffré. Les identifiants et les données de plongée transiteront en clair ; à n\'utiliser que sur un réseau de confiance.';

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
  String get settings_storage_customFolder_subtitleDeviceOnly =>
      'Déplacez la base de données vers le stockage interne ou la carte SD';

  @override
  String get settings_storage_customFolder_deviceOnly_noCloudSync =>
      'La synchronisation cloud gérée par l\'application est désactivée tant que la base de données se trouve sur un volume de stockage de l\'appareil. Sur Android, aucun service de synchronisation ne peut atteindre ce dossier : utilisez Sauvegarde et Restauration pour conserver des copies ailleurs.';

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
  String get settings_storage_dangerZone => 'Zone dangereuse';

  @override
  String get settings_storage_resetDatabase =>
      'Reinitialiser la base de donnees';

  @override
  String get settings_storage_resetDatabase_subtitle =>
      'Supprimer toutes les données de cet appareil et repartir à zéro';

  @override
  String get settings_storage_resetDialog_title =>
      'Reinitialiser la base de donnees ?';

  @override
  String get settings_storage_resetDialog_body =>
      'Cela supprime définitivement toutes les données de CET appareil, y compris les plongées, les sites, l\'équipement et les réglages. Une sauvegarde est créée automatiquement avant la réinitialisation.\n\nVotre bibliothèque cloud n\'est pas supprimée et les autres appareils conservent leurs données. La synchronisation cloud sera déconnectée afin que la réinitialisation ne soit pas annulée ; vous pouvez la reconnecter dans Réglages > Synchronisation cloud.';

  @override
  String get settings_storage_resetDialog_confirmWord => 'Supprimer';

  @override
  String get settings_storage_resetDialog_confirmHint =>
      'Tapez \"Supprimer\" pour confirmer';

  @override
  String get settings_storage_resetDialog_confirmButton => 'Reinitialiser';

  @override
  String get settings_storage_resetDialog_backupFailed =>
      'La sauvegarde a echoue. La reinitialisation a ete annulee pour proteger vos donnees.';

  @override
  String settings_storage_resetDialog_resetFailed(Object error) {
    return 'Echec de la reinitialisation : $error';
  }

  @override
  String get settings_storage_resetComplete_title =>
      'Reinitialisation de la base de donnees';

  @override
  String get settings_storage_resetComplete_description =>
      'Les données de cet appareil ont été effacées et une sauvegarde a été enregistrée. La synchronisation cloud est maintenant déconnectée afin que la réinitialisation ne soit pas annulée ; vous pouvez la reconnecter dans Réglages > Synchronisation cloud. Appuyez sur continuer pour recharger l\'application.';

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
  String get settings_units_gasModel => 'Calculs de gaz';

  @override
  String get settings_units_gasModel_real => 'Gaz réel';

  @override
  String get settings_units_gasModel_real_subtitle =>
      'Tient compte de la compressibilité. Un bloc de 12 L à 200 bar contient environ 2317 L.';

  @override
  String get settings_units_gasModel_ideal => 'Gaz parfait';

  @override
  String get settings_units_gasModel_ideal_subtitle =>
      'Correspond au calcul manuel et aux tables. Un bloc de 12 L à 200 bar contient 2400 L.';

  @override
  String get settings_units_gasModel_explanation =>
      'Comment la pression du bloc est convertie en volume de gaz. Cela concerne la consommation (RMV), les statistiques de gaz, le planificateur et les calculatrices. Le gaz parfait correspond au calcul enseigné par les fédérations ; le gaz réel est physiquement exact et donne un RMV environ 5 % plus bas.';

  @override
  String get settings_units_dialog_gasModel => 'Calculs de gaz';

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
  String get settings_units_defaultCurrency => 'Devise par défaut';

  @override
  String get settings_units_dialog_defaultCurrency => 'Devise par défaut';

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
  String get settings_updates_automaticUpdates => 'Mises à jour automatiques';

  @override
  String get settings_updates_automaticUpdatesSubtitle =>
      'Rechercher les mises à jour périodiquement';

  @override
  String get settings_updates_betaDialogBody =>
      'Les versions bêta sont publiées à chaque modification et peuvent mettre à niveau la base de données de votre carnet de plongée avant la version stable. Revenir ensuite au canal stable ne rétrogradera pas l\'application, et tous les appareils qui se synchronisent ensemble devraient utiliser le même canal. Une sauvegarde est effectuée automatiquement avant toute mise à niveau de la base de données.';

  @override
  String get settings_updates_betaDialogConfirm => 'Passer à la bêta';

  @override
  String get settings_updates_betaDialogTitle =>
      'Recevoir les mises à jour bêta ?';

  @override
  String get settings_updates_channel => 'Canal de mise à jour';

  @override
  String settings_updates_channelBadgeBeta(String version) {
    return '$version (Bêta)';
  }

  @override
  String get settings_updates_channelBeta => 'Bêta';

  @override
  String get settings_updates_channelBetaSubtitle =>
      'Nouvelles versions à chaque modification, en avance sur la stable';

  @override
  String get settings_updates_channelStable => 'Stable';

  @override
  String get settings_updates_channelStableSubtitle =>
      'Versions testées uniquement';

  @override
  String get settings_updates_checkForUpdates => 'Rechercher les mises à jour';

  @override
  String get settings_updates_checking => 'Vérification...';

  @override
  String settings_updates_downloading(String progress) {
    return 'Téléchargement... $progress%';
  }

  @override
  String settings_updates_error(String message) {
    return 'Erreur : $message';
  }

  @override
  String get settings_updates_header => 'Mises à jour';

  @override
  String get settings_updates_joinBeta => 'Rejoindre la bêta';

  @override
  String get settings_updates_joinBetaSubtitle =>
      'Recevez les nouvelles fonctionnalités en avant-première grâce au programme bêta';

  @override
  String get settings_updates_lastChecked => 'Dernière vérification';

  @override
  String get settings_updates_never => 'Jamais';

  @override
  String settings_updates_readyToInstall(String version) {
    return 'Version $version prête à installer';
  }

  @override
  String get settings_updates_stableSwitchNotice =>
      'Vous resterez sur cette bêta jusqu\'à ce que la prochaine version stable soit plus récente qu\'elle.';

  @override
  String get settings_updates_upToDate => 'À jour';

  @override
  String settings_updates_versionAvailable(String version) {
    return 'Version $version disponible';
  }

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
  String get statistics_category_overview_title => 'Overview';

  @override
  String get statistics_category_overview_subtitle =>
      'Totals, records, and breakdowns at a glance';

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
  String get statistics_filterBar_clear => 'Effacer le filtre';

  @override
  String statistics_filterBar_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongées',
      one: '1 plongée',
    );
    return '$_temp0';
  }

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
  String get statistics_profile_deco_notRecorded => 'Non enregistré';

  @override
  String statistics_profile_deco_notRecordedHint(int count) {
    return '$count plongées n\'ont aucune donnée de décompression enregistrée ou calculable et sont exclues du taux';
  }

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
  String get statistics_tooltip_filter => 'Filtrer les statistiques';

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
  String surfaceInterval_gasWarning_modExceeded(
    Object ppO2,
    Object depth,
    Object limit,
    Object mod,
  ) {
    return 'ppO₂ $ppO2 à $depth dépasse $limit. La MOD de ce mélange est $mod.';
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
  String surfaceInterval_result_beyondHorizon(Object hours) {
    return 'L\'attente dépasse les $hours heures explorées par ce planificateur. La désaturation se poursuit, un intervalle de surface plus long suffira donc.';
  }

  @override
  String surfaceInterval_result_beyondHorizonShort(Object hours) {
    return 'Plus de $hours heures';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Intervalle actuel';

  @override
  String get surfaceInterval_result_gasUnsafe =>
      'Gaz dangereux à cette profondeur';

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
  String surfaceInterval_result_noIntervalHelps(Object minutes) {
    return 'Aucun intervalle de surface ne suffit. La plongée sans palier la plus longue à cette profondeur avec ce mélange est de $minutes min. Raccourcissez la deuxième plongée ou réduisez sa profondeur.';
  }

  @override
  String get surfaceInterval_result_notAchievable =>
      'Impossible quel que soit l\'intervalle de surface';

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
  String surfaceInterval_secondDive_heSemantics(Object percent) {
    return 'Hélium de la deuxième plongée : $percent%';
  }

  @override
  String surfaceInterval_secondDive_o2Semantics(Object percent) {
    return 'O2 de la deuxième plongée : $percent%';
  }

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
  String get tags_action_browse => 'Parcourir';

  @override
  String get tags_picker_title => 'Choisir des tags';

  @override
  String get tags_picker_empty =>
      'Aucun tag pour le moment. Saisissez un nom de tag pour créer le premier.';

  @override
  String tags_picker_errorLoading(String error) {
    return 'Erreur lors du chargement des tags : $error';
  }

  @override
  String get tags_picker_allAdded => 'Tous les tags sont déjà ajoutés.';

  @override
  String get tags_picker_noMatches =>
      'Aucun tag ne correspond à votre recherche.';

  @override
  String tags_picker_addCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouter $count tags',
      one: 'Ajouter 1 tag',
      zero: 'Ajouter des tags',
    );
    return '$_temp0';
  }

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
  String get importWizard_tagsLabel => 'Tags';

  @override
  String get importWizard_photos_stepLabel => 'Photos';

  @override
  String importWizard_photos_foundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos référencées dans ce carnet',
      one: '1 photo référencée dans ce carnet',
    );
    return '$_temp0';
  }

  @override
  String get importWizard_photos_chooseFolder =>
      'Choisir un dossier de photos...';

  @override
  String get importWizard_photos_scanning => 'Analyse du dossier...';

  @override
  String importWizard_photos_matchSummary(
    int matched,
    int byName,
    int missing,
  ) {
    return '$matched associées, $byName par nom de fichier uniquement, $missing introuvables';
  }

  @override
  String get importWizard_photos_skip => 'Ignorer les photos';

  @override
  String get importWizard_photos_mobileUnsupported =>
      'L\'import de photos nécessite un dossier sur le disque de cet appareil. Lancez cet import sur un ordinateur pour les inclure. Les plongées et les sites s\'importent normalement.';

  @override
  String importWizard_review_olderDivesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongées plus anciennes ignorées — déjà dans votre carnet',
      one: '1 plongée plus ancienne ignorée — déjà dans votre carnet',
    );
    return '$_temp0';
  }

  @override
  String get tags_hint_addTags => 'Ajouter des étiquettes...';

  @override
  String get tags_manage_title => 'Etiquettes';

  @override
  String get tags_manage_searchHint => 'Rechercher des etiquettes...';

  @override
  String tags_manage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongees',
      one: '1 plongee',
      zero: '0 plongees',
    );
    return '$_temp0';
  }

  @override
  String get tags_manage_emptyState =>
      'Aucune etiquette. Creez-en une pour commencer.';

  @override
  String tags_manage_selectedCount(int count) {
    return '$count selectionne(s)';
  }

  @override
  String get tags_manage_createTitle => 'Creer une etiquette';

  @override
  String get tags_manage_editTitle => 'Modifier l\'etiquette';

  @override
  String get tags_manage_nameLabel => 'Nom de l\'etiquette';

  @override
  String get tags_manage_colorLabel => 'Couleur';

  @override
  String get tags_manage_nameRequired => 'Le nom de l\'etiquette est requis';

  @override
  String get tags_manage_deleteTitle => 'Supprimer l\'etiquette ?';

  @override
  String tags_manage_deleteMessage(String tagName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongees',
      one: '1 plongee',
      zero: '0 plongees',
    );
    return '\"$tagName\" sera retiree de $_temp0. Cette action est irreversible.';
  }

  @override
  String tags_manage_bulkDeleteTitle(int count) {
    return 'Supprimer $count etiquettes ?';
  }

  @override
  String tags_manage_bulkDeleteMessage(int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount plongees',
      one: '1 plongee',
      zero: '0 plongees',
    );
    return 'Ces etiquettes seront retirees de $_temp0 au total. Cette action est irreversible.';
  }

  @override
  String tags_manage_mergeTitle(int count) {
    return 'Fusionner $count etiquettes';
  }

  @override
  String get tags_manage_mergeResultName => 'Nom de l\'etiquette resultante :';

  @override
  String get tags_manage_mergeKeepFrom => 'Ou conserver le nom de :';

  @override
  String tags_manage_mergeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongees',
      one: '1 plongee',
      zero: '0 plongees',
    );
    return 'Cela affectera $_temp0 au total.';
  }

  @override
  String get tags_manage_mergeAction => 'Fusionner';

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
  String tides_source_noaaStation(String name, String distance) {
    return 'Station NOAA : $name ($distance)';
  }

  @override
  String get tides_source_modelEstimate => 'Estimation par modèle océanique';

  @override
  String get tides_source_modelCaveat =>
      'Modélisé à partir de données satellitaires. Les heures et hauteurs peuvent différer près des côtes complexes.';

  @override
  String get tides_source_sheetTitle => 'Source des données de marée';

  @override
  String get tides_source_datumMllw =>
      'Hauteurs par rapport au MLLW (datum de la station)';

  @override
  String get tides_source_datumMsl =>
      'Hauteurs par rapport au niveau moyen de la mer';

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
      'Import dives via Apple HealthKit';

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
  String transfer_computers_diveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongées',
      one: '1 plongée',
    );
    return '$_temp0';
  }

  @override
  String get transfer_computers_downloadTooltip => 'Télécharger les plongées';

  @override
  String get transfer_computers_knownComputersHeader => 'Ordinateurs connus';

  @override
  String transfer_computers_lastDownloadDaysAgo(int days) {
    return 'il y a $days jours';
  }

  @override
  String transfer_computers_lastDownloadHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'il y a $hours heures',
      one: 'il y a 1 heure',
    );
    return '$_temp0';
  }

  @override
  String transfer_computers_lastDownloadMinutesAgo(int minutes) {
    return 'il y a $minutes min';
  }

  @override
  String get transfer_computers_lastDownloadNever => 'Jamais';

  @override
  String get transfer_computers_lastDownloadYesterday => 'Hier';

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
  String get transfer_export_backupLink => 'Aller à Sauvegarde et restauration';

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
  String get transfer_import_fileImportSemanticLabel =>
      'Importer des donnees avec detection automatique';

  @override
  String get transfer_import_fileImportSubtitle =>
      'Detection automatique CSV, UDDF, FIT, et plus';

  @override
  String get transfer_import_fileImportTitle => 'Importer des donnees';

  @override
  String get transfer_import_sectionHeader => 'Importer des donnees';

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
  String get trips_detail_stat_totalRuntime => 'Duree totale';

  @override
  String get trips_detail_stat_totalDives => 'Total des plongees';

  @override
  String get trips_detail_tab_checklist => 'Liste de contrôle';

  @override
  String get trips_detail_tooltip_edit => 'Modifier le voyage';

  @override
  String get trips_detail_tooltip_editShort => 'Modifier';

  @override
  String get trips_detail_tooltip_moreOptions => 'Plus d\'options';

  @override
  String get trips_detail_tooltip_viewOnMap => 'Voir sur la carte';

  @override
  String trips_diveScan_addButton(int count) {
    return 'Ajouter $count plongees';
  }

  @override
  String trips_diveScan_added(int count) {
    return '$count plongees ajoutees au voyage';
  }

  @override
  String get trips_diveScan_cancel => 'Annuler';

  @override
  String trips_diveScan_currentTrip(String tripName) {
    return 'Actuellement dans : $tripName';
  }

  @override
  String get trips_diveScan_deselectAll => 'Tout deselectionner';

  @override
  String trips_diveScan_error(String error) {
    return 'Erreur lors de la recherche de plongees : $error';
  }

  @override
  String get trips_diveScan_findButton =>
      'Rechercher les plongees correspondantes';

  @override
  String trips_diveScan_groupOtherTrips(int count) {
    return 'Dans d\'autres voyages ($count)';
  }

  @override
  String trips_diveScan_groupUnassigned(int count) {
    return 'Non assignees ($count)';
  }

  @override
  String get trips_diveScan_noMatches =>
      'Aucune plongee correspondante trouvee';

  @override
  String get trips_diveScan_noDiver =>
      'Sélectionnez un plongeur actif pour rechercher des plongées';

  @override
  String get trips_diveScan_selectAll => 'Tout selectionner';

  @override
  String trips_diveScan_subtitle(int count) {
    return '$count plongees trouvees dans la plage de dates';
  }

  @override
  String get trips_diveScan_title => 'Ajouter des plongees au voyage';

  @override
  String get trips_diveScan_unknownSite => 'Site inconnu';

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
  String get trips_edit_label_returnFlight => 'Vol retour';

  @override
  String get trips_edit_returnFlightClear => 'Effacer le vol retour';

  @override
  String get trips_edit_returnFlightNotSet => 'Non défini';

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
  String trips_list_countdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Dans $days jours',
      one: 'Dans 1 jour',
      zero: 'Départ aujourd\'hui',
    );
    return '$_temp0';
  }

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
  String get trips_list_inProgress => 'En cours';

  @override
  String get trips_list_pastSection => 'Voyages passés';

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
  String get trips_list_upcomingSection => 'À venir';

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
  String get universalImport_action_consolidate =>
      'Consolider comme ordinateur supplementaire';

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
  String get universalImport_action_changeFile => 'Changer de fichier';

  @override
  String get universalImport_action_selectFile => 'Sélectionner un fichier';

  @override
  String get universalImport_action_selectFiles => 'Sélectionner des fichiers';

  @override
  String get universalImport_action_chooseFolder => 'Choisir un dossier';

  @override
  String get universalImport_triage_title => 'Fichiers à importer';

  @override
  String universalImport_triage_readyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers prêts à importer',
      one: '1 fichier prêt à importer',
    );
    return '$_temp0';
  }

  @override
  String universalImport_label_filesSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers sélectionnés',
      one: '1 fichier sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_triage_excludedCsv =>
      'Importer individuellement (CSV)';

  @override
  String get universalImport_triage_unsupported => 'Format non pris en charge';

  @override
  String get universalImport_triage_parseFailed => 'Lecture impossible';

  @override
  String universalImport_triage_parsing(int current, int total) {
    return 'Analyse du fichier $current sur $total…';
  }

  @override
  String get universalImport_triage_cancelParsing => 'Annuler';

  @override
  String get universalImport_triage_allExcluded =>
      'Aucun des fichiers sélectionnés ne peut être importé ensemble. Les fichiers CSV doivent être importés un par un.';

  @override
  String get universalImport_triage_noneImportable =>
      'Aucun des fichiers sélectionnés ne peut être importé.';

  @override
  String get universalImport_review_inBatchDuplicate =>
      'Doublon d\'une autre plongée dans ce lot d\'importation.';

  @override
  String get universalImport_summary_filesTitle => 'Fichiers';

  @override
  String get universalImport_summary_noticesTitle => 'Absent du fichier';

  @override
  String get universalImport_summary_noticeNoTankPressureTitle =>
      'Pression de bloc non enregistrée';

  @override
  String get universalImport_summary_noticeNoTankPressureBody =>
      'La consommation d\'air et le SAC ne peuvent pas être calculés. Vous pouvez saisir les pressions de début et de fin en modifiant la plongée.';

  @override
  String universalImport_summary_noticeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Concerne $count plongées',
      one: 'Concerne 1 plongée',
    );
    return '$_temp0';
  }

  @override
  String universalImport_summary_fileImported(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongées importées',
      one: '1 plongée importée',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_summary_fileNeedsIndividualImport =>
      'Import individuel requis';

  @override
  String get universalImport_summary_fileUnsupported =>
      'Format non pris en charge';

  @override
  String get universalImport_summary_fileParseFailed => 'Échec de lecture';

  @override
  String universalImport_bulk_consolidateMatched(int count) {
    return 'Consolider les correspondances ($count)';
  }

  @override
  String universalImport_bulk_importAll(int count) {
    return 'Tout importer ($count)';
  }

  @override
  String universalImport_bulk_importAllAsNew(int count) {
    return 'Tout importer comme nouveau ($count)';
  }

  @override
  String universalImport_bulk_skipAll(int count) {
    return 'Tout ignorer ($count)';
  }

  @override
  String universalImport_bulk_replaceSourceAll(int count) {
    return 'Tout remplacer ($count)';
  }

  @override
  String get universalImport_description_supportedFormats =>
      'Sélectionnez un fichier de carnet de plongée à importer. Les formats pris en charge incluent CSV, UDDF, Subsurface XML et Garmin FIT.';

  @override
  String get universalImport_dive_decideAction => 'Decider';

  @override
  String get universalImport_error_unsupportedFormat =>
      'Ce format n\'est pas encore pris en charge. Veuillez exporter en UDDF ou CSV.';

  @override
  String get universalImport_label_columnMapping => 'Mappage des colonnes';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped sur $total colonnes mappées';
  }

  @override
  String get universalImport_label_consolidate => 'Consolider';

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
  String get universalImport_label_importAsNew => 'Importer comme nouveau';

  @override
  String get universalImport_label_importComplete => 'Import terminé';

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
  String get universalImport_entityAction_linkBadge => 'LIER';

  @override
  String get universalImport_entityAction_linkExisting => 'Lier à l\'existant';

  @override
  String get universalImport_entityAction_linkExistingSubtitle =>
      'Utiliser la fiche correspondante';

  @override
  String get universalImport_entityAction_replaceBadge => 'REMPLACER';

  @override
  String get universalImport_entityAction_replaceExisting =>
      'Remplacer l\'existant';

  @override
  String get universalImport_entityAction_replaceExistingSubtitle =>
      'Écraser avec les données importées';

  @override
  String get universalImport_entityAction_skip => 'Ignorer';

  @override
  String get universalImport_entityAction_skipSubtitle =>
      'Abandonner cet import';

  @override
  String get universalImport_entityAction_importAsNew =>
      'Importer comme nouveau';

  @override
  String get universalImport_entityAction_importAsNewSubtitle =>
      'Créer une fiche distincte';

  @override
  String get universalImport_pending_chooseAction => 'Choisir une action';

  @override
  String universalImport_pending_gateHint(int count) {
    return '$count doublon(s) necessitent une decision';
  }

  @override
  String get universalImport_pending_needsDecision => 'Decision requise';

  @override
  String get universalImport_pending_reviewAction => 'Examiner';

  @override
  String get universalImport_rowHint_tapCompareToDecide =>
      'Touchez Decider pour choisir';

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
  String get universalImport_semantics_needsDecision =>
      'Doublon presume, decision requise';

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
  String universalImport_snackbar_bulkMarkedAs(int count, String action) {
    return '$count marques comme $action';
  }

  @override
  String universalImport_snackbar_markedAs(String action) {
    return 'Marque comme $action';
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
  String get universalImport_summary_decidesRequired =>
      'Chacun necessite une decision avant l\'import.';

  @override
  String get universalImport_title => 'Importer des données';

  @override
  String get universalImport_tooltip_closeWizard =>
      'Fermer l\'assistant d\'import';

  @override
  String weather_windFromDirection(Object wind, Object direction) {
    return '$wind de $direction';
  }

  @override
  String get weather_wind_calm => 'calme';

  @override
  String get weather_wind_highWind => 'vent fort';

  @override
  String get weather_wind_lightBreeze => 'brise legere';

  @override
  String get weather_wind_moderateBreeze => 'brise moderee';

  @override
  String get weather_wind_strongBreeze => 'brise forte';

  @override
  String get weather_wmo_clear => 'Ciel degage';

  @override
  String get weather_wmo_drizzle => 'Bruine';

  @override
  String get weather_wmo_fog => 'Brouillard';

  @override
  String get weather_wmo_freezingDrizzle => 'Bruine verglacante';

  @override
  String get weather_wmo_freezingRain => 'Pluie verglacante';

  @override
  String get weather_wmo_mainlyClear => 'Principalement degage';

  @override
  String get weather_wmo_overcast => 'Couvert';

  @override
  String get weather_wmo_partlyCloudy => 'Partiellement nuageux';

  @override
  String get weather_wmo_rain => 'Pluie';

  @override
  String get weather_wmo_rainShowers => 'Averses de pluie';

  @override
  String get weather_wmo_snow => 'Neige';

  @override
  String get weather_wmo_snowGrains => 'Neige en grains';

  @override
  String get weather_wmo_snowShowers => 'Averses de neige';

  @override
  String get weather_wmo_thunderstorm => 'Orage';

  @override
  String get weather_wmo_thunderstormHail => 'Orage avec grele';

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
  String get diveComputer_connectionType_ble => 'Bluetooth LE';

  @override
  String get diveComputer_connectionType_bluetooth => 'Bluetooth';

  @override
  String get diveComputer_connectionType_infrared => 'Infrarouge';

  @override
  String get diveComputer_connectionType_unknown => 'Inconnu';

  @override
  String get diveComputer_connectionType_usb => 'USB';

  @override
  String get diveComputer_connectionType_wifi => 'Wi-Fi';

  @override
  String diveComputer_detail_deleteDialogContent(String name) {
    return 'Voulez-vous vraiment supprimer \"$name\" ? Les plongees importees depuis cet ordinateur ne seront pas supprimees.';
  }

  @override
  String get diveComputer_detail_deleteDialogTitle =>
      'Supprimer l\'ordinateur ?';

  @override
  String get diveComputer_detail_divesImported => 'Plongees importees';

  @override
  String get diveComputer_detail_downloadDivesButton =>
      'Telecharger les plongees';

  @override
  String get diveComputer_detail_editDialogTitle => 'Modifier l\'ordinateur';

  @override
  String get diveComputer_detail_editNameHint => 'Par exemple, Mon Perdix';

  @override
  String get diveComputer_detail_editNotesHint => 'Notes facultatives';

  @override
  String get diveComputer_detail_labelConnection => 'Connexion';

  @override
  String get diveComputer_detail_labelManufacturer => 'Fabricant';

  @override
  String get diveComputer_detail_labelModel => 'Modele';

  @override
  String get diveComputer_detail_labelName => 'Nom';

  @override
  String get diveComputer_detail_lastDownload => 'Dernier telechargement';

  @override
  String get diveComputer_detail_notesTitle => 'Notes';

  @override
  String get diveComputer_detail_reimportAllButton =>
      'Réimporter toutes les plongées';

  @override
  String diveComputer_detail_reimportDialogBody(String computerName) {
    return 'Télécharge chaque plongée depuis $computerName et les compare à votre carnet. Cela peut prendre plusieurs minutes.';
  }

  @override
  String get diveComputer_detail_reimportDialogTitle =>
      'Réimporter toutes les plongées ?';

  @override
  String get diveComputer_detail_statisticsTitle => 'Statistiques';

  @override
  String get diveComputer_detail_unknown => 'Inconnu';

  @override
  String get diveComputer_detail_viewDivesButton =>
      'Voir les plongees de cet ordinateur';

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
  String get diveComputer_discovery_usbInstructions =>
      'Connectez votre ordinateur de plongée par câble USB, puis sélectionnez-le ci-dessous.';

  @override
  String diveComputer_discovery_usbNoResults(String query) {
    return 'Aucun appareil correspondant à \"$query\"';
  }

  @override
  String get diveComputer_discovery_usbSearchHint =>
      'Rechercher par fabricant ou modèle...';

  @override
  String get diveComputer_downloadExit_content =>
      'Quitter annulera le telechargement en cours depuis votre ordinateur de plongee. Etes-vous sur ?';

  @override
  String get diveComputer_downloadExit_leave => 'Quitter';

  @override
  String get diveComputer_downloadExit_stay => 'Rester';

  @override
  String get diveComputer_downloadExit_title => 'Telechargement en cours';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... et $count de plus';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'Annuler';

  @override
  String get diveComputer_downloadStep_cancelled => 'Telechargement annule';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadAll =>
      'Télécharger toutes les plongées';

  @override
  String get diveComputer_downloadStep_downloadFailed =>
      'Echec du telechargement';

  @override
  String get diveComputer_downloadStep_downloadNew =>
      'Télécharger les nouvelles plongées';

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
  String get diveComputer_downloadStep_firstSyncBody =>
      'Votre carnet de plongée contient déjà des plongées. Vous pouvez éviter de télécharger les plongées que vous avez déjà.';

  @override
  String get diveComputer_downloadStep_firstSyncTitle =>
      'Premier téléchargement depuis cet ordinateur de plongée';

  @override
  String diveComputer_downloadStep_onlyAfterDate(String date) {
    return 'Télécharger uniquement les plongées après le $date';
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
  String diveComputer_downloadStep_importPartialCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importer $count plongées téléchargées',
      one: 'Importer 1 plongée téléchargée',
    );
    return '$_temp0';
  }

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
  String get diveComputer_download_noSerialPortsFound =>
      'Aucun port série USB trouvé. L\'ordinateur de plongée est-il connecté et allumé ?';

  @override
  String get diveComputer_download_stalePairing =>
      'L\'appairage Bluetooth de cet ordinateur de plongée n\'est plus valide. Oubliez l\'ordinateur de plongée dans les réglages Bluetooth de votre appareil, puis appairez-le à nouveau depuis le menu Bluetooth de l\'ordinateur de plongée.';

  @override
  String get diveComputer_download_discoveryStalled =>
      'Connexion établie avec l\'ordinateur de plongée, mais il a cessé de répondre avant le début du téléchargement. Cela signifie généralement que l\'appairage Bluetooth n\'est plus valide : oubliez l\'ordinateur de plongée dans les réglages Bluetooth de votre appareil, puis réessayez.';

  @override
  String diveComputer_download_serialConnectFailedWithDetails(Object details) {
    return 'Impossible de se connecter à l\'ordinateur de plongée.\n\nDétails de diagnostic (à partager avec les développeurs) :\n$details';
  }

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
  String diveComputer_download_importingCountDives(int count) {
    return 'Importation de $count plongees...';
  }

  @override
  String diveComputer_download_importingCountNewDives(int count) {
    return 'Importation de $count nouvelles plongees...';
  }

  @override
  String get diveComputer_download_newDivesImported =>
      'Nouvelles plongees importees';

  @override
  String get diveComputer_download_newDivesOnlySubtitle =>
      'Telecharge uniquement les plongees ajoutees depuis votre derniere synchronisation';

  @override
  String get diveComputer_download_newDivesOnlyTitle =>
      'Telecharger uniquement les nouvelles plongees';

  @override
  String get diveComputer_download_preparing => 'Preparation...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_reimportHint =>
      'Vous cherchez des plongées anciennes ou supprimées ? Tout réimporter';

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
  String get diveComputer_download_upToDate =>
      'Aucune nouvelle plongee trouvee -- votre carnet est a jour';

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
  String get diveComputer_pinCode_instructions =>
      'Saisissez le code affiche sur votre ordinateur de plongee.';

  @override
  String get diveComputer_pinCode_label => 'Code PIN';

  @override
  String get diveComputer_pinCode_submit => 'Envoyer';

  @override
  String get diveComputer_pinCode_title => 'Code PIN requis';

  @override
  String get diveComputer_pinEntry_connectButton => 'Se connecter';

  @override
  String get diveComputer_pinEntry_helperText =>
      'Saisissez le PIN a 4 a 6 chiffres affiche sur votre appareil';

  @override
  String get diveComputer_pinEntry_instructionsGeneric =>
      'Consultez l\'ecran de votre ordinateur de plongee pour le code PIN.';

  @override
  String diveComputer_pinEntry_instructionsWithDevice(String deviceName) {
    return 'Consultez l\'ecran de votre $deviceName pour le code PIN.';
  }

  @override
  String get diveComputer_pinEntry_semanticLabel =>
      'Saisie du code PIN, 4 a 6 chiffres';

  @override
  String get diveComputer_pinEntry_title => 'Saisir le code PIN';

  @override
  String diveComputer_scan_bluetoothSemanticLabel(String name) {
    return 'Appareil Bluetooth : $name';
  }

  @override
  String get diveComputer_scan_emptyStateInstructions =>
      'Assurez-vous que votre ordinateur de plongee est :\n• Allume\n• En mode d\'appairage Bluetooth\n• Proche de votre appareil';

  @override
  String get diveComputer_scan_knownBadge => 'Connu';

  @override
  String get diveComputer_scan_lookingForDevicesTitle =>
      'Recherche d\'appareils';

  @override
  String get diveComputer_scan_noUsbDevicesAvailable =>
      'Aucun appareil USB disponible';

  @override
  String get diveComputer_scan_retry => 'Reessayer';

  @override
  String get diveComputer_scan_scanAgain => 'Relancer la recherche';

  @override
  String get diveComputer_scan_scanningStatus =>
      'Recherche d\'ordinateurs de plongee...';

  @override
  String get diveComputer_scan_stopScanning => 'Arreter la recherche';

  @override
  String get diveComputer_scan_supportedBadge => 'Pris en charge';

  @override
  String get diveComputer_scan_tabBluetooth => 'Bluetooth';

  @override
  String get diveComputer_scan_tabUsb => 'Cable USB';

  @override
  String get diveComputer_scan_usbCableLabel => 'Cable USB';

  @override
  String diveComputer_scan_usbSemanticLabel(String model) {
    return 'Appareil USB : $model';
  }

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
      'Submersion uses Apple HealthKit to read underwater diving workout data, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get diveImport_healthkit_accessRequired => 'Apple HealthKit';

  @override
  String get diveImport_healthkit_attribution => 'Fourni par Apple HealthKit';

  @override
  String get diveImport_healthkit_closeTooltip =>
      'Fermer l\'import Apple Watch';

  @override
  String get diveImport_healthkit_dataUsage =>
      'Lit les activites de plongee sous-marine depuis Apple Health, y compris la profondeur, la duree, la temperature de l\'eau et la frequence cardiaque. Ces donnees sont stockees localement dans votre carnet de plongee et ne sont jamais partagees avec des tiers.';

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
  String get diveImport_healthkit_grantAccess => 'Continuer';

  @override
  String get diveImport_healthkit_noDivesFound => 'Aucune plongee trouvee';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'Aucune activite de plongee sous-marine trouvee dans la periode selectionnee.';

  @override
  String get diveImport_healthkit_notAvailable => 'Non disponible';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'L\'importation depuis l\'Apple Watch nécessite un iPhone avec l\'app Santé.';

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
  String get diveImport_uddf_media => 'Photos';

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
  String get divePlanner_undo => 'Annuler';

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
  String get gasCalculators_rockBottom_buddySac => 'RMV du binome';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'RMV majore combine';

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
      'Utilisez un RMV majore pour tenir compte du stress en urgence';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => 'RMV majore';

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
  String get gasCalculators_rockBottom_yourSac => 'Votre RMV';

  @override
  String get gpsLogger_androidNotificationText =>
      'Enregistrement de votre trace de surface';

  @override
  String get gpsLogger_androidNotificationTitle =>
      'Enregistreur GPS Submersion';

  @override
  String get gpsLogger_deleteTrackMessage =>
      'Supprime la trace GPS enregistrée. Les positions déjà attribuées aux plongées sont conservées.';

  @override
  String get gpsLogger_deleteTrackTitle => 'Supprimer la trace ?';

  @override
  String get gpsLogger_interruptedNotice =>
      'Un enregistrement précédent a été interrompu. La trace a été sauvegardée.';

  @override
  String gpsLogger_lastFix(String age, String accuracy) {
    return 'Dernière position il y a $age ($accuracy)';
  }

  @override
  String get gpsLogger_locationOff =>
      'Les services de localisation sont désactivés.';

  @override
  String get gpsLogger_matchButton => 'Associer les plongées aux journaux GPS';

  @override
  String gpsLogger_matchResult(int count) {
    return '$count plongées positionnées';
  }

  @override
  String get gpsLogger_matchResultNone =>
      'Aucune plongée ne correspond à une trace enregistrée';

  @override
  String get gpsLogger_noFixYet => 'En attente du signal GPS';

  @override
  String get gpsLogger_noTracks =>
      'Aucune trace GPS enregistrée pour le moment';

  @override
  String get gpsLogger_permissionDenied =>
      'L\'autorisation de localisation est requise pour enregistrer une trace GPS. Activez-la dans les réglages du système.';

  @override
  String gpsLogger_recordingStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '$count point',
    );
    return 'Enregistrement - $_temp0';
  }

  @override
  String get gpsLogger_reviewSites => 'Vérifier les correspondances de sites';

  @override
  String get gpsLogger_startButton => 'Démarrer l\'enregistrement';

  @override
  String get gpsLogger_stopButton => 'Arrêter l\'enregistrement';

  @override
  String gpsLogger_stripStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '$count point',
    );
    return 'Enregistrement du tracé GPS · $_temp0';
  }

  @override
  String get gpsLogger_summary_tracks => 'Traces';

  @override
  String get gpsLogger_summary_recordedTime => 'Temps enregistré';

  @override
  String get gpsLogger_summary_divesCovered => 'Plongées couvertes';

  @override
  String gpsLogger_trackSubtitle(num count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '$count point',
    );
    return '$_temp0, $duration';
  }

  @override
  String gpsLogger_trackSubtitleTrimmed(String duration) {
    return 'Rognée, $duration';
  }

  @override
  String get gpsLogger_tracksHeader => 'Traces enregistrées';

  @override
  String get gpsTrack_action_trim => 'Rogner...';

  @override
  String get gpsTrack_action_split => 'Diviser...';

  @override
  String get gpsTrack_action_resetTrim => 'Annuler le rognage';

  @override
  String get gpsTrack_edit_applyTrim => 'Appliquer le rognage';

  @override
  String get gpsTrack_edit_confirmSplit => 'Diviser ici';

  @override
  String get gpsTrack_edit_splitWarning =>
      'La division crée deux traces et supprime l\'originale. Cette action est irréversible.';

  @override
  String get gpsTrack_edit_cancel => 'Annuler';

  @override
  String get gpsTrack_import_action => 'Importer une trace...';

  @override
  String get gpsTrack_import_reviewTitle => 'Vérifier l\'import';

  @override
  String get gpsTrack_import_timezone => 'Enregistrée en';

  @override
  String get gpsTrack_import_timezoneHint =>
      'Les heures du fichier sont en UTC. Indiquez le fuseau d\'enregistrement pour qu\'elles correspondent à vos plongées.';

  @override
  String get gpsTrack_import_duplicate =>
      'Cela ressemble à un doublon d\'une trace existante.';

  @override
  String get gpsTrack_import_confirm => 'Importer';

  @override
  String get gpsTrack_import_csvMapping => 'Associer les colonnes';

  @override
  String get gpsTrack_import_firstFix => 'Premier point';

  @override
  String gpsTrack_import_fixCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String gpsTrack_import_failed(String reason) {
    return 'Impossible de lire ce fichier : $reason';
  }

  @override
  String get gpsTrack_importError_unsupportedFormat =>
      'Ce type de fichier n\'est pas pris en charge. Importez un fichier GPX, KML, CSV ou FIT.';

  @override
  String get gpsTrack_importError_unreadable =>
      'Ce fichier n\'a pas pu être lu. Il est peut-être endommagé ou incomplet.';

  @override
  String get gpsTrack_importError_noPositions =>
      'Ce fichier ne contient aucune position GPS horodatée.';

  @override
  String get gpsTrack_importError_badData =>
      'Ce fichier contient une position ou un horodatage que l\'application ne peut pas lire.';

  @override
  String get gpsTrack_export_saved => 'Trace enregistrée';

  @override
  String get gpsTrack_action_export => 'Exporter';

  @override
  String get gpsTrack_action_shareGpx => 'Partager en GPX';

  @override
  String get gpsTrack_action_saveGpx => 'Enregistrer en GPX...';

  @override
  String get gpsTrack_action_shareKml => 'Partager en KML';

  @override
  String get gpsTrack_action_saveKml => 'Enregistrer en KML...';

  @override
  String get gpsTrack_export_failed => 'Échec de l\'exportation.';

  @override
  String get gpsTrack_map_title => 'Carte des traces';

  @override
  String gpsTrack_map_truncated(int count) {
    return 'Affichage des $count traces les plus récentes. Affinez le filtre de dates pour voir les autres.';
  }

  @override
  String get gpsTrack_map_noTracks => 'Aucune trace enregistrée à afficher.';

  @override
  String get gpsTrack_map_showMap => 'Afficher la carte';

  @override
  String get gpsTrack_filter_all => 'Toutes les dates';

  @override
  String get gpsTrack_filter_clear => 'Effacer le filtre de dates';

  @override
  String get gpsTrack_inspect_speed => 'Vitesse';

  @override
  String get gpsTrack_inspect_accuracy => 'Précision';

  @override
  String get gpsTrack_stats_distance => 'Distance';

  @override
  String get gpsTrack_stats_duration => 'Durée';

  @override
  String get gpsTrack_stats_avgSpeed => 'Vitesse moy.';

  @override
  String get gpsTrack_stats_maxSpeed => 'Vitesse max.';

  @override
  String get gpsTrack_stats_fixes => 'Points';

  @override
  String get gpsTrack_stats_dives => 'Plongées';

  @override
  String get gpsTrack_colorMode_uniform => 'Uni';

  @override
  String get gpsTrack_colorMode_speed => 'Vitesse';

  @override
  String get gpsTrack_colorMode_elapsed => 'Temps';

  @override
  String get gpsTrack_legend_slower => 'Plus lent';

  @override
  String get gpsTrack_legend_faster => 'Plus rapide';

  @override
  String get gpsTrack_legend_start => 'Début';

  @override
  String get gpsTrack_legend_end => 'Fin';

  @override
  String get gpsTrack_detail_title => 'Trace GPS';

  @override
  String get gpsTrack_detail_notFound => 'Cette trace n\'est plus disponible.';

  @override
  String get gpsTrack_detail_unreadable =>
      'Impossible de lire les données de la trace.';

  @override
  String get gpsTrack_detail_noPoints =>
      'Cette trace ne contient aucune position enregistrée.';

  @override
  String get maps_compass_resetLabel =>
      'Réinitialiser l\'orientation de la carte vers le nord';

  @override
  String get maps_compass_resetTooltip => 'Nord en haut';

  @override
  String get maps_heatMap_hide => 'Masquer la carte de chaleur';

  @override
  String get maps_heatMap_overlayOff => 'La carte de chaleur est desactivee';

  @override
  String get maps_depthOverlay_show => 'Afficher la surcouche de profondeur';

  @override
  String get maps_depthOverlay_hide => 'Masquer la surcouche de profondeur';

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
  String get maps_offline_downloadNewRegion =>
      'Telecharger une nouvelle region';

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
  String get tankPresets_currentDefault => 'Par défaut actuel';

  @override
  String get tankPresets_customPresets => 'Presets personnalises';

  @override
  String get tankPresets_defaultSettings => 'Bloc par défaut';

  @override
  String get tankPresets_defaultSettings_description =>
      'Le preset marqué d\'une étoile est utilisé comme bloc par défaut lors de l\'enregistrement de nouvelles plongées.';

  @override
  String tankPresets_deleteDefaultMessage(String name) {
    return 'Voulez-vous vraiment supprimer \"$name\" ? C\'est votre preset de bloc par défaut actuel et il sera réinitialisé à AL80.';
  }

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
  String get tankPresets_applyToImports =>
      'Appliquer aussi aux plongées importées';

  @override
  String get tankPresets_applyToImports_subtitle =>
      'Compléter les données de bloc manquantes des plongées importées avec le preset par défaut';

  @override
  String get tankPresets_new_title => 'Nouveau preset de bloc';

  @override
  String get tankPresets_noPresets => 'Aucun preset de bloc disponible';

  @override
  String get tankPresets_setAsDefault => 'Définir par défaut';

  @override
  String get tankPresets_title => 'Presets de blocs';

  @override
  String get tools_gpsLogger_description =>
      'Enregistrez votre position pendant une journée de plongée et associez automatiquement les plongées importées à des positions GPS.';

  @override
  String get tools_gpsLogger_subtitle => 'Enregistrer une trace de surface';

  @override
  String get tools_gpsLogger_title => 'Enregistreur GPS';

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

  @override
  String get settings_section_dataSources_title => 'Data Sources';

  @override
  String get settings_section_dataSources_subtitle =>
      'Connected services & integrations';

  @override
  String get settings_siteMatch_title => 'Association automatique des sites';

  @override
  String get settings_siteMatch_subtitle =>
      'À quel point les plongées téléchargées sont associées aux sites';

  @override
  String get settings_siteMatch_strict => 'Strict';

  @override
  String get settings_siteMatch_balanced => 'Équilibré';

  @override
  String get settings_siteMatch_relaxed => 'Souple';

  @override
  String get settings_dataSources_header => 'Data Sources';

  @override
  String get settings_dataSources_appleHealth_title => 'Apple Health';

  @override
  String get settings_dataSources_appleHealth_subtitle =>
      'Donnees de plongee sous-marine';

  @override
  String get settings_dataSources_appleHealth_description =>
      'Submersion reads underwater diving workout data from Apple Health, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get settings_dataSources_appleHealth_dataTypesHeader =>
      'Donnees lues depuis HealthKit';

  @override
  String get settings_dataSources_appleHealth_dataTypeWorkouts =>
      'Entrainements de plongee sous-marine - heure de debut, duree et donnees d\'activite de la plongee';

  @override
  String get settings_dataSources_appleHealth_dataTypeHeartRate =>
      'Frequence cardiaque - echantillons de frequence cardiaque enregistres pendant les plongees';

  @override
  String get settings_dataSources_appleHealth_permissionGranted =>
      'Acces a HealthKit accorde';

  @override
  String get settings_dataSources_appleHealth_permissionNotGranted =>
      'Acces a HealthKit non accorde';

  @override
  String get settings_dataSources_appleHealth_permissionChecking =>
      'Verification de l\'acces a HealthKit...';

  @override
  String get settings_dataSources_appleHealth_importAction =>
      'Import from Apple Watch';

  @override
  String get settings_dataSources_appleHealth_privacy =>
      'Your health data is stored locally and is never shared with third parties.';

  @override
  String get settings_dataSources_appleHealth_poweredBy =>
      'Fourni par Apple HealthKit';

  @override
  String get settings_dataSources_noSources =>
      'No data source integrations are available on this platform.';

  @override
  String get diveLog_edit_section_environment => 'Environnement';

  @override
  String get diveLog_edit_subsection_autofill => 'Remplissage automatique';

  @override
  String get diveLog_edit_subsection_weather => 'Météo';

  @override
  String get diveLog_edit_subsection_diveConditions => 'Conditions de plongée';

  @override
  String get diveLog_edit_label_windSpeed => 'Vitesse du vent';

  @override
  String get diveLog_edit_label_windDirection => 'Direction du vent';

  @override
  String get diveLog_edit_label_cloudCover => 'Couverture nuageuse';

  @override
  String get diveLog_edit_label_precipitation => 'Précipitations';

  @override
  String get diveLog_edit_label_humidity => 'Humidité';

  @override
  String get diveLog_edit_label_weatherDescription => 'Description météo';

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
  String get diveLog_detail_section_environment => 'Environnement';

  @override
  String get diveLog_detail_subsection_weather => 'Météo';

  @override
  String get diveLog_detail_subsection_diveConditions =>
      'Conditions de plongée';

  @override
  String get diveLog_detail_label_windSpeed => 'Vitesse du vent';

  @override
  String get diveLog_detail_label_windDirection => 'Direction du vent';

  @override
  String get diveLog_detail_label_cloudCover => 'Couverture nuageuse';

  @override
  String get diveLog_detail_label_precipitation => 'Précipitations';

  @override
  String get diveLog_detail_label_humidity => 'Humidité';

  @override
  String get diveLog_detail_label_weatherDescription => 'Description';

  @override
  String get diveLog_detail_weatherSourceOpenMeteo => 'via Open-Meteo';

  @override
  String get dropTarget_title => 'Déposer pour importer';

  @override
  String get dropTarget_subtitle =>
      'Relâchez pour ouvrir l\'assistant d\'importation';

  @override
  String get dropTarget_error_unsupportedFile =>
      'Type de fichier non pris en charge';

  @override
  String get dropTarget_error_wizardActive =>
      'Terminez l\'importation en cours d\'abord';

  @override
  String get dropTarget_error_readFailed => 'Impossible de lire le fichier';

  @override
  String get enum_cloudCover_clear => 'Dégagé';

  @override
  String get enum_cloudCover_partlyCloudy => 'Partiellement nuageux';

  @override
  String get enum_cloudCover_mostlyCloudy => 'Très nuageux';

  @override
  String get enum_cloudCover_overcast => 'Couvert';

  @override
  String get enum_precipitation_none => 'Aucun';

  @override
  String get enum_precipitation_drizzle => 'Bruine';

  @override
  String get enum_precipitation_lightRain => 'Pluie légère';

  @override
  String get enum_precipitation_rain => 'Pluie';

  @override
  String get enum_precipitation_heavyRain => 'Forte pluie';

  @override
  String get enum_precipitation_snow => 'Neige';

  @override
  String get enum_precipitation_sleet => 'Grésil';

  @override
  String get enum_precipitation_hail => 'Grêle';

  @override
  String get columnConfig_title => 'Champs de la liste des plongées';

  @override
  String get columnConfig_viewMode => 'Mode d\'affichage';

  @override
  String get columnConfig_visibleColumns => 'Colonnes visibles';

  @override
  String get columnConfig_availableFields => 'Champs disponibles';

  @override
  String get columnConfig_extraFields => 'Champs supplémentaires';

  @override
  String get columnConfig_extraFields_description =>
      'Affichés sous le contenu principal de la carte';

  @override
  String get columnConfig_slotAssignments => 'Affectation des emplacements';

  @override
  String get columnConfig_resetToDefault => 'Réinitialiser par défaut';

  @override
  String get columnConfig_preset => 'Préréglage';

  @override
  String get columnConfig_presetSaveAs => 'Enregistrer sous';

  @override
  String get columnConfig_presetName => 'Nom du préréglage';

  @override
  String get columnConfig_presetNameHint => 'ex. : Plongée technique';

  @override
  String get columnConfig_presetSave => 'Enregistrer';

  @override
  String get columnConfig_presetCancel => 'Annuler';

  @override
  String get columnConfig_columns => 'Colonnes';

  @override
  String get columnConfig_done => 'Terminé';

  @override
  String get settings_appearance_columnConfig =>
      'Champs de la liste des plongées';

  @override
  String get settings_appearance_columnConfig_subtitle =>
      'Personnaliser les champs affichés dans les vues de liste des plongées';

  @override
  String get diveField_category_core => 'Essentiel';

  @override
  String get diveField_category_environment => 'Environnement';

  @override
  String get diveField_category_gas => 'Gaz';

  @override
  String get diveField_category_tank => 'Bloc';

  @override
  String get diveField_category_weight => 'Lestage';

  @override
  String get diveField_category_equipment => 'Équipement';

  @override
  String get diveField_category_deco => 'Décompression';

  @override
  String get diveField_category_physiology => 'Physiologie';

  @override
  String get diveField_category_rebreather => 'Recycleur';

  @override
  String get diveField_category_people => 'Personnes';

  @override
  String get diveField_category_location => 'Lieu';

  @override
  String get diveField_category_trip => 'Voyage';

  @override
  String get diveField_category_rating => 'Évaluation';

  @override
  String get diveField_category_metadata => 'Métadonnées';

  @override
  String get listViewMode_table => 'Tableau';

  @override
  String get settings_appearance_general => 'Général';

  @override
  String get settings_appearance_sections => 'Sections';

  @override
  String get settings_appearance_colorAccents => 'Accents de couleur';

  @override
  String get settings_appearance_accentNavIcons =>
      'Icônes de navigation colorées';

  @override
  String get settings_appearance_accentNavIcons_subtitle =>
      'Colorer les icônes du menu principal avec la couleur de chaque section';

  @override
  String get settings_appearance_accentSectionHeaders =>
      'En-têtes de section colorés';

  @override
  String get settings_appearance_accentSectionHeaders_subtitle =>
      'Afficher une icône de section colorée à côté des titres de page';

  @override
  String get settings_appearance_accentListIcons => 'Icônes de liste colorées';

  @override
  String get settings_appearance_accentListIcons_subtitle =>
      'Colorer les icônes des listes et des pages de réglages';

  @override
  String get settings_appearance_showDetailsPane =>
      'Afficher le volet de détails';

  @override
  String get settings_appearance_showDetailsPane_subtitle =>
      'Afficher le volet de détails à côté du tableau';

  @override
  String get settings_appearance_showProfilePanel =>
      'Afficher le panneau de profil en vue tableau';

  @override
  String get settings_appearance_showProfilePanel_subtitle =>
      'Afficher le graphique de profil de plongée au-dessus du tableau par défaut';

  @override
  String get settings_appearance_mapStyle => 'Style de carte';

  @override
  String get settings_appearance_mapStyle_openStreetMap => 'Plan des rues';

  @override
  String get settings_appearance_mapStyle_openTopoMap => 'Topographique';

  @override
  String get settings_appearance_mapStyle_esriSatellite => 'Satellite';

  @override
  String get common_action_reparse => 'Réanalyser';

  @override
  String get diveComputer_detail_reparseAllButton =>
      'Réanalyser toutes les plongées';

  @override
  String get diveComputer_detail_reparseAllTitle =>
      'Réanalyser toutes les plongées';

  @override
  String diveComputer_detail_reparseAllMessage(int count) {
    return 'Relance l\'analyseur de plongées pour $count plongées disposant de données brutes stockées. Cela met à jour les profils et données de capteurs, mais préserve vos notes, sites, équipiers et autres modifications.';
  }

  @override
  String diveComputer_detail_reparseAllProgress(int count) {
    return 'Réanalyse de $count plongées...';
  }

  @override
  String diveComputer_detail_reparseAllSuccess(int count) {
    return '$count plongées réanalysées avec succès';
  }

  @override
  String diveComputer_detail_reparseAllPartial(
    int succeeded,
    int total,
    int failed,
  ) {
    return '$succeeded plongées sur $total réanalysées. $failed ont échoué.';
  }

  @override
  String diveComputer_detail_reparseRawDataCount(int count) {
    return '$count plongées avec données brutes';
  }

  @override
  String diveComputer_detail_reparseRawDataCountWithout(
    int count,
    int without,
  ) {
    return '$count plongées avec données brutes ($without sans)';
  }

  @override
  String get diveLog_detail_menu_reparseRawData =>
      'Réanalyser les données brutes';

  @override
  String get diveLog_detail_reparseSuccess => 'Plongée réanalysée avec succès';

  @override
  String get diveLog_detail_reparseProfilePreserved =>
      'Détails de la source actualisés. Cette plongée a été combinée à partir d\'autres plongées, son profil est donc resté inchangé.';

  @override
  String diveLog_detail_reparseFailed(String error) {
    return 'Échec de la réanalyse : $error';
  }

  @override
  String get universalImport_label_replaceSource => 'Remplacer la source';

  @override
  String get universalImport_label_replaceSourceSubtitle =>
      'Mettre à jour depuis le même ordinateur';

  @override
  String get universalImport_title_importOptions => 'Options d\'importation';

  @override
  String get universalImport_label_options => 'Options';

  @override
  String get universalImport_label_retainDiveNumbers =>
      'Conserver les numéros de plongée source';

  @override
  String get universalImport_label_retainDiveNumbersSubtitle =>
      'Utiliser les numéros de plongée du fichier importé au lieu de les attribuer automatiquement';

  @override
  String get universalImport_title_successImported => 'Importation réussie';

  @override
  String get universalImport_title_successUpdated => 'Mise à jour réussie';

  @override
  String get universalImport_title_successConsolidated =>
      'Consolidation réussie';

  @override
  String get universalImport_title_noDivesImported => 'Aucune plongée importée';

  @override
  String get universalImport_label_allDivesSkipped =>
      'Toutes les plongées ont été ignorées.';

  @override
  String get universalImport_label_replacedSourceData =>
      'Données source remplacées';

  @override
  String get universalImport_label_consolidated => 'Consolidées';

  @override
  String get universalImport_label_photosAttached => 'Photos jointes';

  @override
  String get universalImport_label_photosUnmatched =>
      'Photos sans plongée correspondante';

  @override
  String get common_label_shareWithAllProfiles =>
      'Partager avec tous les profils de plongée';

  @override
  String get settings_shareByDefault_title =>
      'Partager les nouveaux sites et voyages par défaut';

  @override
  String get settings_shareAllSites_title => 'Partager tous mes sites';

  @override
  String get settings_shareAllTrips_title => 'Partager tous mes voyages';

  @override
  String settings_shareAllSites_confirm(int count) {
    return 'Rendre vos $count sites visibles pour tous les profils de plongée de cette app ? Vous pourrez annuler le partage de sites individuels plus tard.';
  }

  @override
  String settings_shareAllTrips_confirm(int count) {
    return 'Rendre vos $count voyages visibles pour tous les profils de plongée de cette app ? Vous pourrez annuler le partage de voyages individuels plus tard.';
  }

  @override
  String settings_shareAllSites_snackbar(int count) {
    return '$count sites partagés avec tous les profils de plongée.';
  }

  @override
  String settings_shareAllTrips_snackbar(int count) {
    return '$count voyages partagés avec tous les profils de plongée.';
  }

  @override
  String get settings_shareAll_noneToShare => 'Rien à partager.';

  @override
  String get settings_sharedData_sectionTitle => 'Données partagées';

  @override
  String get settings_sharedData_sectionSubtitle =>
      'Partager sites et voyages entre profils';

  @override
  String get common_action_unshare => 'Ne plus partager';

  @override
  String get trips_unshareConfirm_title => 'Ne plus partager ce voyage ?';

  @override
  String trips_unshareConfirm_body(String name) {
    return '« $name » sera retiré des vues des autres profils de plongée. Vous pourrez le partager à nouveau plus tard.';
  }

  @override
  String get sites_unshareConfirm_title => 'Ne plus partager ce site ?';

  @override
  String sites_unshareConfirm_body(String name) {
    return '« $name » sera retiré des vues des autres profils de plongée. Vous pourrez le partager à nouveau plus tard.';
  }

  @override
  String get trips_deleteShared_title => 'Supprimer le voyage partagé ?';

  @override
  String trips_deleteShared_body(String name) {
    return '« $name » est partagé avec d\'autres profils de plongée. Le supprimer ici le retire pour tout le monde.';
  }

  @override
  String get sites_deleteShared_title => 'Supprimer le site partagé ?';

  @override
  String sites_deleteShared_body(String name) {
    return '« $name » est partagé avec d\'autres profils de plongée. Le supprimer ici le retire pour tout le monde.';
  }

  @override
  String divers_delete_reassigned_snackbar(int trips, int sites, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      trips,
      locale: localeName,
      other: 'voyages partagés',
      one: 'voyage partagé',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sites,
      locale: localeName,
      other: 'sites partagés',
      one: 'site partagé',
    );
    return 'Plongeur supprimé. $trips $_temp0 et $sites $_temp1 réattribués à $name.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_title =>
      'Profils de plongeur en double';

  @override
  String get settings_cloudSync_duplicateDivers_description =>
      'La synchronisation a trouvé plus d\'un profil portant le même nom. Cela se produit généralement lorsque chaque appareil a créé son propre profil avant la synchronisation. La fusion déplace toutes les plongées et les données vers un seul profil.';

  @override
  String settings_cloudSync_duplicateDivers_groupLabel(String name, int count) {
    return '$name ($count profils)';
  }

  @override
  String get settings_cloudSync_duplicateDivers_mergeButton => 'Fusionner';

  @override
  String get settings_cloudSync_duplicateDivers_confirmTitle =>
      'Fusionner les profils de plongeur ?';

  @override
  String settings_cloudSync_duplicateDivers_confirmBody(
    int count,
    String name,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profils en double',
      one: 'un profil en double',
    );
    return 'Toutes les plongées, certifications, équipements et autres données de $_temp0 seront déplacés vers \"$name\". Cette action ne peut pas être annulée automatiquement.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_confirmCancel => 'Annuler';

  @override
  String get settings_cloudSync_duplicateDivers_confirmAction => 'Fusionner';

  @override
  String settings_cloudSync_duplicateDivers_successSnack(String name) {
    return 'Fusionné dans $name';
  }

  @override
  String settings_cloudSync_duplicateDivers_failureSnack(String error) {
    return 'Échec de la fusion : $error';
  }

  @override
  String get settings_cloudSync_duplicateDivers_undo => 'Annuler';

  @override
  String get divers_edit_priorExperienceSection => 'Expérience Antérieure';

  @override
  String get divers_edit_priorExperienceHelp =>
      'Plongées et temps d\'avant votre utilisation de Submersion.';

  @override
  String get divers_edit_priorDivesLabel => 'Plongées antérieures';

  @override
  String get divers_edit_priorHoursLabel => 'Heures antérieures';

  @override
  String get divers_edit_priorMinutesLabel => 'Minutes';

  @override
  String get divers_edit_divingSinceLabel => 'Plonge depuis';

  @override
  String get divers_edit_divingSinceNotSet => 'Non défini';

  @override
  String get divers_edit_clearDivingSinceTooltip => 'Effacer plonge depuis';

  @override
  String get divers_edit_priorInvalidNumber => 'Saisissez un nombre valide';

  @override
  String statistics_priorBreakdown(String logged, String prior) {
    return '$logged enregistrées + $prior antérieures';
  }

  @override
  String statistics_divingSince(int year) {
    return 'Plonge depuis $year';
  }

  @override
  String get db_location_choose_volume => 'Choisir l\'emplacement de stockage';

  @override
  String get db_location_internal => 'Stockage interne';

  @override
  String get db_location_sd_card => 'Carte SD';

  @override
  String get db_location_external_note =>
      'Les fichiers ici sont supprimés si vous désinstallez l\'application.';

  @override
  String get db_location_backup_note =>
      'Android ne peut pas exécuter la base de données depuis un dossier synchronisé dans le cloud. Pour en conserver une copie dans Dropbox, Nextcloud ou Google Drive, définissez un Emplacement de sauvegarde dans Sauvegarde et Restauration.';

  @override
  String diveLog_bulkEdit_membership_onAll(int count) {
    return 'sur toutes les $count';
  }

  @override
  String diveLog_bulkEdit_membership_onSome(int count, int total) {
    return 'sur $count sur $total';
  }

  @override
  String diveLog_bulkEdit_membership_adding(int total) {
    return 'ajout à toutes les $total';
  }

  @override
  String get diveLog_bulkEdit_membership_removing => 'retrait de toutes';

  @override
  String get diveLog_bulkEdit_membership_empty =>
      'Aucun élément sur les plongées sélectionnées pour l\'instant';

  @override
  String get settings_mediaStorage_entry_title => 'Stockage des médias';

  @override
  String get settings_mediaStorage_entry_subtitle =>
      'Stockez les originaux photo et vidéo dans votre propre espace cloud';

  @override
  String get settings_mediaStorage_status_notConfigured =>
      'Aucun stockage de médias connecté sur cet appareil';

  @override
  String settings_mediaStorage_status_connected(String hint) {
    return 'Connecté à $hint';
  }

  @override
  String get settings_mediaStorage_test_success => 'Connexion réussie';

  @override
  String get settings_mediaStorage_saved => 'Stockage des médias connecté';

  @override
  String get settings_mediaStorage_action_disconnect => 'Déconnecter';

  @override
  String get settings_mediaStorage_disconnect_confirm_title =>
      'Déconnecter le stockage des médias ?';

  @override
  String get settings_mediaStorage_disconnect_confirm_body =>
      'Cet appareil cesse d\'envoyer et de récupérer des médias. Rien n\'est supprimé de votre bucket.';

  @override
  String get settings_mediaStorage_action_copyFromSync =>
      'Copier les réglages de Sync';

  @override
  String get settings_mediaStorage_transfers_title => 'Transferts';

  @override
  String get settings_mediaStorage_transfers_entry => 'Voir les transferts';

  @override
  String get settings_mediaStorage_transfers_empty => 'Aucun transfert';

  @override
  String get settings_mediaStorage_transfers_retry => 'Réessayer';

  @override
  String get settings_mediaStorage_transfers_clearCompleted =>
      'Effacer les terminés';

  @override
  String get settings_mediaStorage_transfers_state_pending => 'En attente';

  @override
  String get settings_mediaStorage_transfers_state_transferring =>
      'Envoi en cours';

  @override
  String get settings_mediaStorage_transfers_state_deleting =>
      'Suppression du cloud';

  @override
  String get settings_mediaStorage_transfers_state_done => 'Terminé';

  @override
  String get settings_mediaStorage_transfers_state_failed => 'Échec';

  @override
  String settings_mediaStorage_transfers_queued(int count) {
    return '$count en file';
  }

  @override
  String settings_mediaStorage_transfers_waitingRetry(int count) {
    return '$count en attente de nouvelle tentative';
  }

  @override
  String get settings_mediaStorage_verify_action => 'Vérifier la bibliothèque';

  @override
  String get settings_mediaStorage_verify_running =>
      'Vérification de la médiathèque...';

  @override
  String settings_mediaStorage_verify_summary(
    int checked,
    int removed,
    int repaired,
    int aborted,
  ) {
    return '$checked objets vérifiés : $removed orphelins supprimés, $repaired réparations en file, $aborted envois périmés annulés';
  }

  @override
  String get settings_mediaStorage_backfill_action =>
      'Envoyer la bibliothèque existante';

  @override
  String settings_mediaStorage_backfill_enqueued(int count) {
    return '$count envois en file';
  }

  @override
  String get settings_mediaStorage_policy_autoUpload =>
      'Envoyer les photos automatiquement';

  @override
  String get settings_mediaStorage_policy_photosOnCellular =>
      'Envoyer les photos en cellulaire';

  @override
  String get settings_mediaStorage_provider_label => 'Fournisseur';

  @override
  String get settings_mediaStorage_connect_dropbox_hint =>
      'Utilise votre connexion Dropbox de la synchronisation cloud. Les médias sont stockés dans le dossier d\'application Dropbox.';

  @override
  String get settings_mediaStorage_connect_gdrive_hint =>
      'Connexion avec Google. Les médias sont stockés dans l\'espace Drive privé de cette application.';

  @override
  String get settings_mediaStorage_connect_icloud_hint =>
      'Les médias sont stockés dans le conteneur iCloud de cette application et se synchronisent via votre identifiant Apple.';

  @override
  String settings_mediaStorage_connect_action(String provider) {
    return 'Connecter $provider';
  }

  @override
  String get bodyWeight_addEntry => 'Ajouter une mesure';

  @override
  String get bodyWeight_dateLabel => 'Date';

  @override
  String get bodyWeight_deleteTooltip => 'Supprimer l\'entrée';

  @override
  String get bodyWeight_heightLabel => 'Taille (cm)';

  @override
  String get bodyWeight_heightFeetLabel => 'Taille (ft)';

  @override
  String get bodyWeight_heightInchesLabel => 'Pouces';

  @override
  String bodyWeight_weightLabel(String unit) {
    return 'Poids ($unit)';
  }

  @override
  String diveLog_edit_weightFeedback_amount(String unit) {
    return 'D\'environ combien ($unit)';
  }

  @override
  String get diveLog_edit_weightFeedback_correct => 'Correct';

  @override
  String get diveLog_edit_weightFeedback_label =>
      'Comment était votre lestage ?';

  @override
  String get diveLog_edit_weightFeedback_over => 'Trop lesté';

  @override
  String get diveLog_edit_weightFeedback_under => 'Pas assez lesté';

  @override
  String get diverProfile_bodyWeight_empty => 'Non enregistré';

  @override
  String get diverProfile_bodyWeight_title => 'Poids corporel';

  @override
  String get equipment_edit_advanced_title => 'Avancé';

  @override
  String get equipment_edit_buoyancyHint_exposure =>
      'Positif : à quel point il flotte';

  @override
  String get equipment_edit_buoyancyHint_generic => 'Négatif s\'il coule';

  @override
  String get equipment_edit_buoyancyHint_tank =>
      'Laisser vide - les blocs utilisent leurs propres spécifications';

  @override
  String equipment_edit_buoyancyLabel(String unit) {
    return 'Flottabilité ($unit)';
  }

  @override
  String equipment_edit_dryWeightLabel(String unit) {
    return 'Poids à sec ($unit)';
  }

  @override
  String equipment_edit_liftCapacityLabel(String unit) {
    return 'Capacité de portance ($unit)';
  }

  @override
  String get equipment_edit_liftCapacityHint =>
      'Portance nominale du wing ou gilet';

  @override
  String get planner_gearWeights_accept => 'Utiliser comme lestage prévu';

  @override
  String get planner_gearWeights_addGear => 'Ajouter équipement';

  @override
  String get planner_gearWeights_empty =>
      'Ajoutez de l\'équipement pour prédire votre lestage';

  @override
  String planner_gearWeights_planned(String weight) {
    return 'Prévu : $weight';
  }

  @override
  String planner_gearWeights_predicted(String weight) {
    return 'Prédit : $weight';
  }

  @override
  String get planner_gearWeights_title => 'Équipement et lestage';

  @override
  String get planner_gearWeights_useSet => 'Utiliser un kit';

  @override
  String get tools_weight_addGear => 'Ajouter équipement';

  @override
  String get tools_weight_addTank => 'Ajouter un bloc';

  @override
  String tools_weight_basedOnDives(int count) {
    return 'Basé sur $count plongées enregistrées';
  }

  @override
  String get tools_weight_breakdownTitle => 'Comment cela a été calculé';

  @override
  String get tools_weight_confidence_high => 'Confiance élevée';

  @override
  String get tools_weight_confidence_low => 'Confiance faible - estimation';

  @override
  String get tools_weight_confidence_medium => 'Confiance moyenne';

  @override
  String tools_weight_deltaVsPrevious(String delta) {
    return '$delta par rapport à la config précédente';
  }

  @override
  String get tools_weight_noGear =>
      'Ajoutez l\'équipement prévu pour personnaliser la prédiction.';

  @override
  String get tools_weight_personalTerm => 'Base personnelle';

  @override
  String get tools_weight_placementTitle => 'Répartition suggérée';

  @override
  String get tools_weight_predictedWeight => 'Lestage prédit';

  @override
  String get tools_weight_saveToProfile =>
      'Enregistrer le poids dans le profil';

  @override
  String get tools_weight_source_measured => 'mesuré à partir de vos plongées';

  @override
  String get tools_weight_source_physics => 'physique';

  @override
  String get tools_weight_source_typeDefault => 'estimation par défaut';

  @override
  String get tools_weight_source_userSpec =>
      'd\'après les spécifications de votre équipement';

  @override
  String get tools_weight_tanks => 'Blocs';

  @override
  String get tools_weight_useSet => 'Utiliser un kit';

  @override
  String get tools_weight_waterTerm => 'Type d\'eau';

  @override
  String get dive3d_previewTitle => 'Vue 3D';

  @override
  String get dive3d_previewHint => 'Touchez pour explorer en 3D';

  @override
  String get dive3d_resetView => 'Réinitialiser la vue';

  @override
  String get dive3d_zoomIn => 'Zoom avant';

  @override
  String get dive3d_zoomOut => 'Zoom arrière';

  @override
  String get dive3d_play => 'Lire';

  @override
  String get dive3d_pause => 'Pause';

  @override
  String get dive3d_overlays => 'Superpositions';

  @override
  String get dive3d_overlay_strata => 'Couches de température';

  @override
  String get dive3d_overlay_ceiling => 'Plafond de déco';

  @override
  String get dive3d_overlay_curtain => 'Rideau de profondeur';

  @override
  String get dive3d_overlay_markers => 'Marqueurs';

  @override
  String get dive3d_seascape_overlay_paths => 'Trajets de plongée';

  @override
  String get dive3d_seascape_overlay_contours => 'Isobathes';

  @override
  String get dive3d_seascape_overlay_walls => 'Tombants';

  @override
  String get dive3d_overlay_water => 'Surface de l\'eau';

  @override
  String get dive3d_seascape_legend_land => 'Terre';

  @override
  String get dive3d_seascape_appearance => 'Apparence du terrain';

  @override
  String get dive3d_seascape_chartView => 'Vue carte';

  @override
  String get dive3d_seascape_orbitView => 'Vue 3D';

  @override
  String get dive3d_seascape_appearance_surface => 'Surface du terrain';

  @override
  String get dive3d_seascape_appearance_surfaceDepth =>
      'Couleurs de profondeur';

  @override
  String get dive3d_seascape_appearance_surfaceImagery =>
      'Imagerie de la carte';

  @override
  String get dive3d_seascape_appearance_surfaceBlend => 'Mélange';

  @override
  String get siteFeature_type_wreck => 'Épave';

  @override
  String get siteFeature_type_mooring => 'Bouée d\'amarrage';

  @override
  String get siteFeature_type_entry => 'Point d\'entrée';

  @override
  String get siteFeature_type_exit => 'Point de sortie';

  @override
  String get siteFeature_type_swimThrough => 'Passage';

  @override
  String get siteFeature_type_hazard => 'Danger';

  @override
  String get siteFeature_type_current => 'Courant';

  @override
  String get siteFeature_sectionTitle => 'Éléments';

  @override
  String get siteFeature_addAction => 'Ajouter un élément';

  @override
  String get siteFeature_placeHint => 'Touchez la carte pour placer l\'élément';

  @override
  String get siteFeature_addTitle => 'Ajouter un élément';

  @override
  String get siteFeature_editTitle => 'Modifier l\'élément';

  @override
  String get siteFeature_field_name => 'Nom';

  @override
  String get siteFeature_field_bearing => 'Cap (°)';

  @override
  String get siteFeature_field_depth => 'Profondeur';

  @override
  String get siteFeature_field_notes => 'Remarques';

  @override
  String get siteFeature_deleteAction => 'Supprimer';

  @override
  String siteFeature_deleteConfirm(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get siteScape_mode2d => 'Carte';

  @override
  String get siteScape_mode3d => '3D';

  @override
  String get dive3d_seascape_appearance_rampRange =>
      'Limiter la plage de profondeur des couleurs';

  @override
  String get dive3d_seascape_appearance_rampMax => 'Couleur la plus foncée à';

  @override
  String get dive3d_seascape_appearance_banded => 'Dégradé par paliers';

  @override
  String get dive3d_seascape_appearance_contours => 'Niveaux d\'isobathes';

  @override
  String get dive3d_seascape_appearance_contourAuto => 'Automatique';

  @override
  String get dive3d_seascape_appearance_contourCustom => 'Personnalisé';

  @override
  String get dive3d_seascape_appearance_addLevel => 'Ajouter un niveau';

  @override
  String get dive3d_seascape_appearance_defaultColor => 'Par défaut';

  @override
  String get dive3d_seascape_appearance_wallAngle => 'Angle de tombant';

  @override
  String get dive3d_seascape_appearance_wallAngleNote =>
      'Les cellules bathymétriques moyennent la pente interne : les vrais tombants paraissent moins raides. Rester bien en dessous de 45 degrés.';

  @override
  String get dive3d_seascape_siteTitle => 'Paysage marin du site';

  @override
  String dive3d_seascape_seafloorSource(String source, String resolution) {
    return 'Fond marin : $source (~$resolution m)';
  }

  @override
  String get dive3d_seascape_noCoordinates =>
      'Ce site n\'a pas de coordonnées GPS';

  @override
  String get dive3d_seascape_noData =>
      'Aucune bathymétrie disponible pour cet endroit';

  @override
  String dive3d_seascape_axis_distance(String unitSymbol) {
    return 'Distance ($unitSymbol)';
  }

  @override
  String get settings_about_bathymetryCredit =>
      'Données bathymétriques : GMRT (CC BY 4.0) · EMODnet Bathymetry (CC BY 4.0) · NOAA ETOPO 2022';

  @override
  String get dive3d_metric_depth => 'Profondeur';

  @override
  String get dive3d_metric_temperature => 'Temp';

  @override
  String get dive3d_metric_ascentRate => 'Remontée';

  @override
  String get dive3d_metric_ppO2 => 'ppO2';

  @override
  String get dive3d_metric_cns => 'SNC';

  @override
  String get dive3d_metric_heartRate => 'FC';

  @override
  String get dive3d_metric_tankPressure => 'Pression';

  @override
  String get dive3d_zAxis => 'Axe Z';

  @override
  String get dive3d_zAxis_none => 'Aucun';

  @override
  String get dive3d_overlay_shadows => 'Ombres sur les parois';

  @override
  String get dive3d_metric_tts => 'TTS';

  @override
  String dive3d_axis_depth(String unitSymbol) {
    return 'Profondeur ($unitSymbol)';
  }

  @override
  String get dive3d_axis_time => 'Temps de plongée (min)';

  @override
  String get dive3d_pose_menu => 'Caméra';

  @override
  String get dive3d_pose_default => 'Vue par défaut';

  @override
  String get dive3d_pose_front => 'Face (profondeur / temps)';

  @override
  String get dive3d_pose_side => 'Côté (profondeur / mesure)';

  @override
  String get dive3d_pose_top => 'Dessus (mesure / temps)';

  @override
  String get dive3d_readout_runTime => 'Temps de plongée';

  @override
  String get dive3d_readout_ceiling => 'Plafond';

  @override
  String dive3d_readout_tank(int n) {
    return 'Bloc $n';
  }

  @override
  String get dive3d_scene_dive => 'Plongée';

  @override
  String get dive3d_scene_tissue => 'Tissus';

  @override
  String get dive3d_tissue_gasCombined => 'Combiné';

  @override
  String get dive3d_tissue_gasN2 => 'N2';

  @override
  String get dive3d_tissue_gasHe => 'He';

  @override
  String get dive3d_tissue_colorMValue => '% valeur M';

  @override
  String get dive3d_tissue_colorAbsolute => 'Charge';

  @override
  String get dive3d_tissue_controlling => 'Directeur';

  @override
  String get dive3d_tissue_surfaceInterval => 'Intervalle de surface';

  @override
  String get dive3d_career_title => 'Historique 3D';

  @override
  String get dive3d_career_colorRecency => 'Récence';

  @override
  String get dive3d_career_colorDepth => 'Profondeur';

  @override
  String get dive3d_career_empty => 'Aucune plongée avec profil';

  @override
  String get dive3d_spatial_title => 'Paysage marin 3D';

  @override
  String get dive3d_spatial_estimatedPath =>
      'Trajet estimé (navigation à l\'estime)';

  @override
  String get dive3d_spatial_synthesizedSeafloor => 'Fond marin synthétisé';

  @override
  String get dive3d_spatial_noPath =>
      'Données insuffisantes pour reconstruire le trajet';

  @override
  String get dive3d_tissue_legendHeight =>
      'Hauteur et couleur : % de la limite de valeur M';

  @override
  String get dive3d_tissue_legendLimit => 'Plan rouge = limite déco';

  @override
  String get dive3d_tissue_legendAxes =>
      'Gauche→droite : temps · Avant→arrière : tissus rapides→lents';

  @override
  String get dive3d_tissue_legendDepth => 'Courbe bleue : votre profondeur';

  @override
  String get dive3d_tissue_onGassing => 'Absorption';

  @override
  String get dive3d_tissue_offGassing => 'Élimination';

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
    return 'Saturation $percent%';
  }

  @override
  String dive3d_tissue_tooltipProgress(int percent) {
    return '$percent% de la plongée';
  }

  @override
  String get dive3d_tissue_stateEquilibrium => 'Équilibre';

  @override
  String get dive3d_tissue_statePastMValue => 'Au-delà de la valeur M';

  @override
  String get dive3d_tissue_axisTime => 'Temps';

  @override
  String get dive3d_tissue_axisSaturation => 'Saturation %';

  @override
  String get dive3d_tissue_axisCompartment => 'Compartiment';

  @override
  String get dive3d_compare_computers_title => 'Comparer les ordinateurs';

  @override
  String get dive3d_compare_dives_title => 'Comparer les plongées';

  @override
  String get dive3d_scene_computers => 'Ordinateurs';

  @override
  String get dive3d_compare_layout_sideBySide => 'Côte à côte';

  @override
  String get dive3d_compare_layout_overlay => 'Superposer';

  @override
  String get dive3d_compare_empty =>
      'Au moins 2 profils avec données de profondeur sont nécessaires pour comparer';

  @override
  String dive3d_compare_showing(Object shown, Object total) {
    return 'Affichage de $shown sur $total';
  }

  @override
  String get dive3d_compare_setReference => 'Définir comme référence';

  @override
  String get diveLog_selection_tooltip_compare3d => 'Comparer en 3D';

  @override
  String get diveLog_sources_compareIn3d => 'Comparer en 3D';

  @override
  String get settings_setup_pendingTitle =>
      'Terminez la configuration de cet appareil';

  @override
  String settings_setup_mediaStoreAttach(String hint) {
    return 'Connecter le stockage multimédia ($hint)';
  }

  @override
  String settings_setup_accountSignIn(String label) {
    return 'Se connecter à $label';
  }

  @override
  String get settings_setup_dismiss => 'Ignorer';

  @override
  String get settings_photosMedia_title => 'Photos et médias';

  @override
  String get settings_photosMedia_subtitle => 'Sources, stockage et comptes';

  @override
  String get settings_photosMedia_sourcesHeader => 'D\'où viennent les photos';

  @override
  String get settings_photosMedia_storageHeader =>
      'Où sont conservées les copies';

  @override
  String get settings_photosMedia_accountsHeader => 'Comptes';

  @override
  String get settings_photosMedia_displayHeader => 'Affichage';

  @override
  String get settings_photosMedia_guidedSetup => 'Configuration guidée';

  @override
  String get settings_photosMedia_photoSources_title =>
      'Photothèque et sources';

  @override
  String get settings_photosMedia_photoSources_subtitle =>
      'Galerie, fichiers et options d\'import';

  @override
  String get settings_photosMedia_networkSources_title => 'Sources réseau';

  @override
  String get settings_photosMedia_networkSources_subtitle =>
      'URL et flux de manifeste (avancé)';

  @override
  String get settings_connectedAccounts_title => 'Comptes connectés';

  @override
  String get settings_connectedAccounts_subtitle =>
      'Connexions cloud et services';

  @override
  String get settings_connectedAccounts_empty =>
      'Aucun compte connecté pour le moment';

  @override
  String get settings_connectedAccounts_status_signedIn => 'Connecté';

  @override
  String get settings_connectedAccounts_status_needsSignIn =>
      'Connexion requise';

  @override
  String get settings_connectedAccounts_status_unavailable =>
      'Indisponible sur cet appareil';

  @override
  String get settings_connectedAccounts_disconnectDevice =>
      'Se déconnecter sur cet appareil';

  @override
  String get settings_connectedAccounts_removeFromLibrary =>
      'Retirer de la bibliothèque';

  @override
  String get settings_connectedAccounts_removeConfirmTitle =>
      'Retirer le compte ?';

  @override
  String get settings_connectedAccounts_removeConfirmBody =>
      'Le compte est retiré de tous les appareils synchronisés. Les identifiants stockés sur les autres appareils ne sont pas supprimés.';

  @override
  String get settings_setupGuide_title => 'Configurer photos et médias';

  @override
  String get settings_setupGuide_intro =>
      'Connectez la provenance de vos photos et l\'emplacement des copies. Vous pouvez relancer cet assistant à tout moment.';

  @override
  String get settings_setupGuide_stepSources => 'Sources de photos';

  @override
  String get settings_setupGuide_stepSources_desc =>
      'Joignez des photos depuis votre photothèque, vos fichiers ou Lightroom.';

  @override
  String get settings_setupGuide_stepStorage => 'Stockage multimédia';

  @override
  String get settings_setupGuide_stepStorage_desc =>
      'Conservez des copies de vos photos dans votre propre cloud pour que chaque appareil puisse les afficher.';

  @override
  String get settings_setupGuide_stepSync => 'Synchronisation cloud';

  @override
  String get settings_setupGuide_stepSync_desc =>
      'Synchronisez les données de plongée entre appareils.';

  @override
  String get settings_setupGuide_statusDone => 'Configuré';

  @override
  String get settings_setupGuide_statusTodo => 'Non configuré';

  @override
  String get settings_setupGuide_open => 'Ouvrir';

  @override
  String get settings_connectedAccounts_loadError =>
      'Impossible de charger les comptes';

  @override
  String get media_unavailablePlaceholder_volumeOffline => 'Volume non monté';

  @override
  String get media_unavailablePlaceholder_stillFetching =>
      'Chargement en cours. Touchez pour réessayer.';

  @override
  String get media_unavailablePlaceholder_accessDenied =>
      'Aucun accès à la photothèque';

  @override
  String get attrLabel_size => 'Taille';

  @override
  String get attrLabel_thickness_mm => 'Épaisseur (mm)';

  @override
  String get attrLabel_suit_style => 'Type de combinaison';

  @override
  String get attrLabel_shell_material => 'Matériau extérieur';

  @override
  String get attrLabel_seal_type => 'Type de manchons';

  @override
  String get attrLabel_volume_l => 'Volume';

  @override
  String get attrLabel_working_pressure_bar => 'Pression de service';

  @override
  String get attrLabel_tank_material => 'Matériau';

  @override
  String get attrLabel_valve_type => 'Robinet';

  @override
  String get attrLabel_tank_identifier => 'Identifiant';

  @override
  String get attrLabel_last_visual_inspection => 'Dernière inspection visuelle';

  @override
  String get attrLabel_last_hydro_test => 'Dernier test hydrostatique';

  @override
  String get attrLabel_connection => 'Raccord';

  @override
  String get attrLabel_cold_water_rated => 'Adapté à l\'eau froide';

  @override
  String get attrLabel_bcd_style => 'Style';

  @override
  String get attrLabel_lift_capacity_kg => 'Capacité de levage';

  @override
  String get attrLabel_heel_type => 'Talon';

  @override
  String get attrLabel_blade_style => 'Voilure';

  @override
  String get attrLabel_mount => 'Fixation';

  @override
  String get attrLabel_connectivity => 'Connectivité';

  @override
  String get attrLabel_lens_config => 'Verre';

  @override
  String get attrLabel_prescription => 'Verres correcteurs';

  @override
  String get attrLabel_weight_style => 'Style';

  @override
  String get attrLabel_lumens => 'Lumens';

  @override
  String get attrLabel_beam_type => 'Faisceau';

  @override
  String get attrLabel_depth_rating_m => 'Profondeur maximale';

  @override
  String get attrLabel_smb_type => 'Type';

  @override
  String get attrLabel_length_m => 'Longueur';

  @override
  String get attrLabel_reel_type => 'Type';

  @override
  String get attrLabel_line_length_m => 'Longueur de fil';

  @override
  String get attrLabel_blade_material => 'Matériau de la lame';

  @override
  String get attrLabel_tip_type => 'Pointe';

  @override
  String get attrLabel_glove_type => 'Type';

  @override
  String get attrLabel_sole_type => 'Semelle';

  @override
  String get attrLabel_buoyancy_kg => 'Flottabilité';

  @override
  String get attrLabel_dry_weight_kg => 'Poids à sec';

  @override
  String get attrLabel_unit_type => 'Type d\'appareil';

  @override
  String get attrLabel_mount_configuration => 'Montage';

  @override
  String get attrLabel_scrubber_type => 'Type de cartouche';

  @override
  String get attrLabel_scrubber_duration_h => 'Autonomie cartouche (h)';

  @override
  String get attrLabel_o2_cell_count => 'Cellules O2';

  @override
  String get attrLabel_diluent_cylinder_l => 'Bouteille de diluant';

  @override
  String get attrLabel_o2_cylinder_l => 'Bouteille d\'O2';

  @override
  String get attrLabel_dpv_style => 'Style';

  @override
  String get attrLabel_burn_time_h => 'Autonomie';

  @override
  String get attrLabel_battery_type => 'Batterie';

  @override
  String get attrLabel_battery_capacity_wh => 'Capacité de la batterie (Wh)';

  @override
  String get attrLabel_motor_type => 'Moteur';

  @override
  String get attrLabel_speed_mps => 'Vitesse maximale';

  @override
  String get attrChoice_unit_type_eccr => 'CCR électronique (eCCR)';

  @override
  String get attrChoice_unit_type_mccr => 'CCR manuel (mCCR)';

  @override
  String get attrChoice_unit_type_hccr => 'CCR hybride (hCCR)';

  @override
  String get attrChoice_unit_type_scr_cmf => 'SCR - débit massique constant';

  @override
  String get attrChoice_unit_type_scr_pascr => 'SCR - addition passive';

  @override
  String get attrChoice_unit_type_scr_escr => 'SCR - régulé électroniquement';

  @override
  String get attrChoice_mount_configuration_back => 'Montage dorsal';

  @override
  String get attrChoice_mount_configuration_chest => 'Montage ventral';

  @override
  String get attrChoice_mount_configuration_sidemount => 'Sidemount';

  @override
  String get attrChoice_scrubber_type_axial => 'Axiale';

  @override
  String get attrChoice_scrubber_type_radial => 'Radiale';

  @override
  String get attrChoice_suit_style_full => 'Combinaison intégrale';

  @override
  String get attrChoice_suit_style_shorty => 'Shorty';

  @override
  String get attrChoice_suit_style_two_piece => 'Deux pièces';

  @override
  String get attrChoice_suit_style_semi_dry => 'Semi-étanche';

  @override
  String get attrChoice_shell_material_trilaminate => 'Trilaminé';

  @override
  String get attrChoice_shell_material_neoprene => 'Néoprène';

  @override
  String get attrChoice_shell_material_crushed_neoprene => 'Néoprène compressé';

  @override
  String get attrChoice_shell_material_vulcanized_rubber =>
      'Caoutchouc vulcanisé';

  @override
  String get attrChoice_seal_type_latex => 'Latex';

  @override
  String get attrChoice_seal_type_silicone => 'Silicone';

  @override
  String get attrChoice_seal_type_neoprene => 'Néoprène';

  @override
  String get attrChoice_tank_material_aluminum => 'Aluminium';

  @override
  String get attrChoice_tank_material_steel => 'Acier';

  @override
  String get attrChoice_tank_material_carbon_composite => 'Composite carbone';

  @override
  String get attrChoice_valve_type_din => 'DIN';

  @override
  String get attrChoice_valve_type_yoke => 'Étrier (INT)';

  @override
  String get attrChoice_valve_type_convertible => 'Convertible';

  @override
  String get attrChoice_connection_din => 'DIN';

  @override
  String get attrChoice_connection_yoke => 'Étrier (INT)';

  @override
  String get attrChoice_bcd_style_jacket => 'Gilet';

  @override
  String get attrChoice_bcd_style_back_inflate => 'Back-inflate';

  @override
  String get attrChoice_bcd_style_wing => 'Wing';

  @override
  String get attrChoice_bcd_style_sidemount => 'Sidemount';

  @override
  String get attrChoice_heel_type_open_heel => 'Talon ouvert';

  @override
  String get attrChoice_heel_type_full_foot => 'Chaussant';

  @override
  String get attrChoice_blade_style_paddle => 'Classique';

  @override
  String get attrChoice_blade_style_split => 'Fendue';

  @override
  String get attrChoice_blade_style_vented => 'Ajourée';

  @override
  String get attrChoice_mount_wrist => 'Poignet';

  @override
  String get attrChoice_mount_console => 'Console';

  @override
  String get attrChoice_mount_hud => 'HUD';

  @override
  String get attrChoice_connectivity_ble => 'Bluetooth (BLE)';

  @override
  String get attrChoice_connectivity_usb => 'USB';

  @override
  String get attrChoice_connectivity_infrared => 'Infrarouge';

  @override
  String get attrChoice_connectivity_none => 'Aucune';

  @override
  String get attrChoice_lens_config_single => 'Monoverre';

  @override
  String get attrChoice_lens_config_twin => 'Bi-verre';

  @override
  String get attrChoice_lens_config_frameless => 'Sans cadre';

  @override
  String get attrChoice_weight_style_belt => 'Ceinture';

  @override
  String get attrChoice_weight_style_integrated => 'Intégré';

  @override
  String get attrChoice_weight_style_trim => 'Trim';

  @override
  String get attrChoice_weight_style_ankle => 'Cheville';

  @override
  String get attrChoice_beam_type_spot => 'Spot';

  @override
  String get attrChoice_beam_type_flood => 'Large';

  @override
  String get attrChoice_beam_type_adjustable => 'Réglable';

  @override
  String get attrChoice_smb_type_open => 'Ouverte';

  @override
  String get attrChoice_smb_type_closed => 'Fermée';

  @override
  String get attrChoice_reel_type_spool => 'Spool';

  @override
  String get attrChoice_reel_type_ratchet => 'Moulinet à cliquet';

  @override
  String get attrChoice_blade_material_stainless => 'Acier inoxydable';

  @override
  String get attrChoice_blade_material_titanium => 'Titane';

  @override
  String get attrChoice_tip_type_pointed => 'Pointue';

  @override
  String get attrChoice_tip_type_blunt => 'Émoussée';

  @override
  String get attrChoice_tip_type_line_cutter => 'Coupe-fil';

  @override
  String get attrChoice_glove_type_five_finger => 'Cinq doigts';

  @override
  String get attrChoice_glove_type_mitt => 'Moufle';

  @override
  String get attrChoice_glove_type_dry => 'Étanche';

  @override
  String get attrChoice_sole_type_hard => 'Semelle rigide';

  @override
  String get attrChoice_sole_type_soft => 'Semelle souple';

  @override
  String get attrChoice_dpv_style_tow_behind => 'Tracté';

  @override
  String get attrChoice_dpv_style_ride_on => 'À chevaucher';

  @override
  String get attrChoice_dpv_style_handheld => 'À main';

  @override
  String get attrChoice_battery_type_lithium_ion => 'Lithium-ion';

  @override
  String get attrChoice_battery_type_nimh => 'NiMH';

  @override
  String get attrChoice_battery_type_lead_acid => 'Plomb-acide';

  @override
  String get attrChoice_motor_type_brushless => 'Sans balais';

  @override
  String get attrChoice_motor_type_brushed => 'À balais';

  @override
  String get equipment_edit_customFieldsTitle => 'Champs personnalisés';

  @override
  String get equipment_edit_addCustomField => 'Ajouter un champ personnalisé';

  @override
  String get attr_flagYes => 'Oui';

  @override
  String get attr_flagNo => 'Non';

  @override
  String get equipment_edit_invalidThickness => 'Utilisez 5, 5/4 ou 7/5/3';

  @override
  String get statistics_progression_divesBySuitThickness_title =>
      'Plongées par épaisseur de combinaison';

  @override
  String get statistics_progression_divesBySuitThickness_subtitle =>
      'Épaisseur principale de la combinaison sur vos plongées';

  @override
  String get statistics_progression_divesBySuitThickness_empty =>
      'Aucune plongée avec une épaisseur de combinaison enregistrée';

  @override
  String get statistics_progression_divesBySuitThickness_error =>
      'Impossible de charger les données d\'épaisseur';

  @override
  String get diveLog_filter_sectionSuitThickness =>
      'Épaisseur de combinaison (mm)';

  @override
  String get diveLog_filter_thicknessMin => 'Min';

  @override
  String get diveLog_filter_thicknessMax => 'Max';

  @override
  String get safetySettings_noFlyHeader => 'Voler après la plongée';

  @override
  String get safetySettings_noFlyPreset_standard => 'Standard (12/18/24 h)';

  @override
  String get safetySettings_noFlyPreset_strict => 'Strict (18/24/48 h)';

  @override
  String get safetySettings_noFlyPreset_subtitle =>
      'Intervalles indicatifs après une plongée unique sans déco, des plongées successives et des plongées avec déco';

  @override
  String get flightWindow_closed => 'Plus de plongée avant votre vol';

  @override
  String get flightWindow_conflict =>
      'Votre délai avant vol dépasse le départ de votre vol';

  @override
  String flightWindow_departs(String time) {
    return 'Le vol part $time';
  }

  @override
  String flightWindow_openTitle(String remaining) {
    return 'Temps de plongée restant : $remaining';
  }

  @override
  String flightWindow_surfaceBy(String time) {
    return 'Remonter avant $time';
  }

  @override
  String safetyHub_noFly_active_title(String remaining) {
    return 'Interdiction de vol : $remaining restant';
  }

  @override
  String safetyHub_noFly_until(String time) {
    return 'Jusqu\'à $time';
  }

  @override
  String get safetyHub_noFly_clear_title => 'Aucune restriction de vol';

  @override
  String get safetyHub_noFly_clear_subtitle =>
      'Aucune restriction de vol active';

  @override
  String safetyHub_noFly_category_single(int hours) {
    return 'Après une plongée unique sans déco : recommandation de $hours h';
  }

  @override
  String safetyHub_noFly_category_repetitive(int hours) {
    return 'Après des plongées successives : recommandation de $hours h';
  }

  @override
  String safetyHub_noFly_category_deco(int hours) {
    return 'Après une plongée avec décompression : recommandation de $hours h';
  }

  @override
  String get safetyHub_noFly_disclaimer =>
      'Recommandations DAN/UHMS depuis votre dernière plongée. Ne remplace pas le temps d\'interdiction de vol de votre ordinateur de plongée.';

  @override
  String get diveLog_detail_altitudeMismatch_title => 'Le site est en altitude';

  @override
  String get diveLog_detail_altitudeMismatch_subtitle =>
      'Ce site indique une altitude mais la plongée n\'en a aucune : l\'analyse de décompression a supposé le niveau de la mer. Définissez l\'altitude de la plongée pour corriger.';

  @override
  String diveLog_detail_sacVolumeHint(String unit) {
    return 'Ajoutez le volume du bloc pour afficher la consommation SAC en $unit/min';
  }

  @override
  String safetyHub_alert_noFly(String remaining) {
    return 'Interdiction de vol : $remaining restant';
  }

  @override
  String get emergencyCard_title => 'Urgence';

  @override
  String emergencyCard_callDan(String name) {
    return 'Appeler $name';
  }

  @override
  String get emergencyCard_callDan_subtitle =>
      'Ligne d\'urgence plongeurs. Appelez d\'abord : ils coordonnent l\'évacuation et l\'orientation vers un caisson.';

  @override
  String emergencyCard_ems(String number) {
    return 'Secours locaux : $number';
  }

  @override
  String get emergencyCard_diverSection => 'Plongeur';

  @override
  String emergencyCard_bloodType(String value) {
    return 'Groupe sanguin : $value';
  }

  @override
  String emergencyCard_allergies(String value) {
    return 'Allergies : $value';
  }

  @override
  String emergencyCard_medications(String value) {
    return 'Médicaments : $value';
  }

  @override
  String get emergencyCard_contactsSection => 'Contacts d\'urgence';

  @override
  String get emergencyCard_insuranceSection => 'Assurance plongée';

  @override
  String emergencyCard_insurancePolicy(String number) {
    return 'Police $number';
  }

  @override
  String get emergencyCard_chambersSection => 'Caissons hyperbares';

  @override
  String get emergencyCard_chambersNote =>
      'La disponibilité évolue. Appelez toujours d\'abord la ligne d\'urgence plongeurs pour l\'orientation.';

  @override
  String emergencyCard_chamberVerified(String date) {
    return 'Coordonnées vérifiées $date';
  }

  @override
  String get emergencyCard_chambersNearby => 'Caissons les plus proches';

  @override
  String emergencyCard_chamberViewAll(int count) {
    return 'Voir les $count caissons';
  }

  @override
  String get emergencyCard_chambersNoneNearby =>
      'Aucun caisson listé à proximité. Appelez la ligne d\'urgence plongée : elle vous orientera vers l\'établissement le plus proche capable de vous traiter.';

  @override
  String get emergencyCard_chamberCapability_divingEmergency =>
      'Traite les accidents de plongée';

  @override
  String get emergencyCard_chamberCapability_hyperbaricUnit =>
      'Unité hyperbare hospitalière';

  @override
  String get emergencyCard_chamberCapability_elective =>
      'Thérapie programmée uniquement';

  @override
  String get emergencyCard_chamberCapability_unknown =>
      'Capacité non confirmée';

  @override
  String get emergencyCard_chamberAvailability_h24 => '24 h/24';

  @override
  String get emergencyCard_chamberAvailability_onCall => 'Astreinte';

  @override
  String get emergencyCard_chamberAvailability_businessHours =>
      'Heures ouvrables';

  @override
  String get emergencyCard_chamberUnverified =>
      'Non confirmé auprès de l\'établissement';

  @override
  String get chambersDirectory_title => 'Caissons hyperbares';

  @override
  String get chambersDirectory_search => 'Rechercher par nom, ville ou pays';

  @override
  String get chambersDirectory_empty =>
      'Aucun caisson ne correspond à cette recherche.';

  @override
  String chambersDirectory_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count caissons',
      one: '1 caisson',
    );
    return '$_temp0';
  }

  @override
  String get emergencyCard_hideChamber => 'Masquer';

  @override
  String get emergencyCard_chamberHidden => 'Caisson masqué';

  @override
  String get emergencyCard_undo => 'Annuler';

  @override
  String get emergencyCard_addChamber => 'Ajouter un caisson';

  @override
  String get emergencyCard_deleteChamber => 'Supprimer';

  @override
  String emergencyCard_regionLabel(String region) {
    return 'Région : $region';
  }

  @override
  String get emergencyCard_regionUnknown =>
      'Région inconnue : ligne mondiale utilisée';

  @override
  String get emergencyCard_noDiverData =>
      'Aucune donnée de profil plongeur. Ajoutez contacts d\'urgence, données médicales et assurance dans le profil plongeur.';

  @override
  String get addChamber_title => 'Ajouter un caisson';

  @override
  String get addChamber_name => 'Nom';

  @override
  String get addChamber_country => 'Code pays (ex. FR)';

  @override
  String get addChamber_city => 'Ville';

  @override
  String get addChamber_phone => 'Téléphone';

  @override
  String get addChamber_notes => 'Notes';

  @override
  String get addChamber_save => 'Enregistrer';

  @override
  String get addChamber_nameRequired => 'Le nom est requis';

  @override
  String get addChamber_countryRequired => 'Le code pays est requis';

  @override
  String get addChamber_phoneRequired => 'Le numéro de téléphone est requis';

  @override
  String get safetyHub_emergencyCardLink => 'Carte d\'urgence';

  @override
  String get safetyHub_emergencyCardLink_subtitle =>
      'Hors ligne : ligne directe, secours, caissons, vos données médicales et d\'assurance';

  @override
  String get dashboard_quickAction_emergency => 'Carte d\'urgence';

  @override
  String get incidents_title => 'Journal des presque-accidents';

  @override
  String get incidents_empty =>
      'Aucun presque-accident enregistré. Noter ce qui a failli mal tourner - sans jugement - rend les schémas visibles avant qu\'ils ne deviennent des accidents.';

  @override
  String get incidents_add => 'Consigner un presque-accident';

  @override
  String get incidents_linkedDive => 'Lié à une plongée';

  @override
  String get incidents_delete_confirm =>
      'Supprimer ce rapport de presque-accident ?';

  @override
  String get incidents_notFound => 'Rapport de presque-accident introuvable';

  @override
  String get incidentEdit_title_new => 'Consigner un presque-accident';

  @override
  String get incidentEdit_title_edit => 'Modifier le presque-accident';

  @override
  String get incidentEdit_category => 'Catégorie';

  @override
  String get incidentEdit_severity => 'Gravité';

  @override
  String get incidentEdit_severity_minor => 'Mineur';

  @override
  String get incidentEdit_severity_moderate => 'Modéré';

  @override
  String get incidentEdit_severity_serious => 'Sérieux';

  @override
  String get incidentEdit_date => 'Quand c\'est arrivé';

  @override
  String get incidentEdit_narrative => 'Ce qui s\'est passé';

  @override
  String get incidentEdit_narrative_hint =>
      'Juste les faits, avec vos mots. Cela reste privé.';

  @override
  String get incidentEdit_narrative_required => 'Décrivez ce qui s\'est passé';

  @override
  String get incidentEdit_contributingFactors =>
      'Facteurs contributifs (facultatif)';

  @override
  String get incidentEdit_lessonsLearned =>
      'Ce qui aiderait la prochaine fois (facultatif)';

  @override
  String get incidentEdit_save => 'Enregistrer';

  @override
  String get incidentEdit_privacyNote =>
      'Les rapports de presque-accidents se synchronisent entre vos appareils et figurent dans vos sauvegardes, mais jamais dans les exports ni les pages de carnet partagées.';

  @override
  String get incidentCategory_buoyancy => 'Flottabilité';

  @override
  String get incidentCategory_gasSupply => 'Alimentation en gaz';

  @override
  String get incidentCategory_equipment => 'Équipement';

  @override
  String get incidentCategory_buddySeparation => 'Séparation du binôme';

  @override
  String get incidentCategory_marineLife => 'Vie marine';

  @override
  String get incidentCategory_boatSurface => 'Bateau / surface';

  @override
  String get incidentCategory_medical => 'Médical';

  @override
  String get incidentCategory_planning => 'Planification';

  @override
  String get incidentCategory_other => 'Autre';

  @override
  String get safetyHub_incidentsLink => 'Journal des presque-accidents';

  @override
  String get safetyHub_incidentsLink_subtitle =>
      'Notes d\'incidents privées et non punitives';

  @override
  String get diveLog_detail_menu_logNearMiss => 'Consigner un presque-accident';

  @override
  String diveLog_detail_linkedIncidents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presque-accidents liés à cette plongée',
      one: '1 presque-accident lié à cette plongée',
    );
    return '$_temp0';
  }

  @override
  String get planning_card_noFly_subtitle =>
      'Compte à rebours indicatif depuis vos dernières plongées';

  @override
  String get settings_section_safety_title => 'Sécurité';

  @override
  String get settings_section_safety_subtitle =>
      'Règles du bilan et vol après la plongée';

  @override
  String get settings_section_security_title => 'Sécurité de l\'application';

  @override
  String get settings_section_security_subtitle =>
      'Verrouillage de l\'app et chiffrement de la base de données';

  @override
  String get settings_security_appLock => 'Verrouillage de l\'app';

  @override
  String get settings_security_appLock_subtitle =>
      'Exiger votre mot de passe ou la biométrie pour ouvrir l\'app';

  @override
  String get settings_security_biometrics => 'Déverrouiller par biométrie';

  @override
  String get settings_security_autoLock => 'Verrouillage automatique';

  @override
  String get settings_security_autoLock_immediately => 'Immédiatement';

  @override
  String settings_security_autoLock_minutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Après $minutes minutes',
      one: 'Après 1 minute',
    );
    return '$_temp0';
  }

  @override
  String get settings_security_autoLock_never => 'Jamais';

  @override
  String get settings_security_encryption => 'Chiffrer la base de données';

  @override
  String get settings_security_encryption_subtitle =>
      'Protégez votre carnet de plongée avec un chiffrement au repos. Le chiffrement peut affecter les performances.';

  @override
  String get settings_security_encryption_progress_backup =>
      'Création de la sauvegarde de sécurité...';

  @override
  String get settings_security_encryption_progress_encrypt =>
      'Chiffrement de la base de données...';

  @override
  String get settings_security_encryption_progress_decrypt =>
      'Déchiffrement de la base de données...';

  @override
  String get settings_security_encryption_progress_reopen =>
      'Réouverture de la base de données...';

  @override
  String get settings_security_changePassword => 'Changer le mot de passe';

  @override
  String get settings_security_regenerateRecovery =>
      'Nouveau code de récupération';

  @override
  String get settings_security_setPassword =>
      'Définir le mot de passe de l\'app';

  @override
  String get settings_security_password => 'Mot de passe';

  @override
  String get settings_security_confirmPassword => 'Confirmer le mot de passe';

  @override
  String get settings_security_currentPassword => 'Mot de passe actuel';

  @override
  String get settings_security_newPassword => 'Nouveau mot de passe';

  @override
  String get settings_security_passwordTooShort =>
      'Le mot de passe doit comporter au moins 4 caractères.';

  @override
  String get settings_security_passwordMismatch =>
      'Les mots de passe ne correspondent pas.';

  @override
  String get settings_security_wrongPassword => 'Mot de passe incorrect.';

  @override
  String get settings_security_recoveryCode_title =>
      'Votre code de récupération';

  @override
  String get settings_security_recoveryCode_explain =>
      'Notez-le et conservez-le en lieu sûr. C\'est le seul moyen de déverrouiller l\'app si vous oubliez votre mot de passe, et il remplace tout code de récupération précédent.';

  @override
  String get settings_security_recoveryCode_savedConfirm =>
      'J\'ai enregistré mon code de récupération';

  @override
  String get settings_security_disableBlockedByEncryption_title =>
      'Le chiffrement est activé';

  @override
  String get settings_security_disableBlockedByEncryption_body =>
      'Désactivez d\'abord le chiffrement de la base de données avant de désactiver le verrouillage de l\'app. La base chiffrée nécessite un identifiant.';

  @override
  String get settings_security_enableEncryption_title =>
      'Chiffrer la base de données ?';

  @override
  String get settings_security_enableEncryption_body =>
      'Une sauvegarde de sécurité est d\'abord créée, puis le fichier de la base est rechiffré sur place. Cela peut prendre du temps pour les gros carnets. Le chiffrement peut affecter les performances.';

  @override
  String get settings_security_disableEncryption_title =>
      'Désactiver le chiffrement ?';

  @override
  String get settings_security_disableEncryption_body =>
      'Le fichier de la base de données sera de nouveau stocké non chiffré sur le disque.';

  @override
  String get settings_security_turnOffAppLock_title =>
      'Désactiver le verrouillage de l\'app ?';

  @override
  String get settings_security_turnOffAppLock_body =>
      'L\'app s\'ouvrira sans demander votre mot de passe.';

  @override
  String get settings_security_unlock_title => 'Saisissez votre mot de passe';

  @override
  String get settings_security_cancel => 'Annuler';

  @override
  String get settings_security_continue => 'Continuer';

  @override
  String get settings_security_done => 'Terminé';

  @override
  String get settings_security_turnOff => 'Désactiver';

  @override
  String get dataQuality_inbox_title => 'Qualité des données';

  @override
  String get dataQuality_badge_tooltip => 'Contrôle de la qualité des données';

  @override
  String get dataQuality_scan_start => 'Analyser la bibliothèque';

  @override
  String dataQuality_scan_progress(int done, int total) {
    return '$done plongées vérifiées sur $total';
  }

  @override
  String get dataQuality_scan_cancel => 'Annuler';

  @override
  String dataQuality_scan_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Analyse terminée - $count éléments à vérifier',
      one: 'Analyse terminée - 1 élément à vérifier',
      zero: 'Analyse terminée - aucune nouvelle anomalie',
    );
    return '$_temp0';
  }

  @override
  String dataQuality_scan_errors(int count) {
    return '$count plongées n\'ont pas pu être entièrement vérifiées';
  }

  @override
  String dataQuality_lastScan(String when) {
    return 'Dernière analyse : $when';
  }

  @override
  String get dataQuality_neverScanned =>
      'Votre carnet de plongée n\'a pas encore été analysé';

  @override
  String get dataQuality_empty_title => 'Tout est en ordre';

  @override
  String get dataQuality_empty_subtitle =>
      'Aucune anomalie de qualité des données. Analysez votre bibliothèque pour vérifier les plongées importées.';

  @override
  String get dataQuality_banner_newChecks =>
      'De nouveaux contrôles de qualité sont disponibles';

  @override
  String get dataQuality_banner_rescan => 'Relancer l\'analyse';

  @override
  String get dataQuality_action_dismiss => 'Ignorer';

  @override
  String get dataQuality_action_dismissFiltered =>
      'Ignorer tout ce qui est affiché';

  @override
  String get dataQuality_action_goToDive => 'Aller à la plongée';

  @override
  String get dataQuality_action_undo => 'Annuler';

  @override
  String get dataQuality_repair_applied => 'Correction appliquée';

  @override
  String get dataQuality_repair_noChange => 'Rien à corriger ici';

  @override
  String get dataQuality_repair_needsReview =>
      'Pas de correction automatique. Ouvrez la plongée pour la corriger.';

  @override
  String get dataQuality_repair_failed => 'Échec de la correction';

  @override
  String get dataQuality_chip_all => 'Tous';

  @override
  String get dataQuality_chip_time => 'Heure';

  @override
  String get dataQuality_chip_profile => 'Profil';

  @override
  String get dataQuality_chip_gas => 'Gaz';

  @override
  String get dataQuality_chip_tanks => 'Blocs';

  @override
  String get dataQuality_chip_duplicates => 'Doublons';

  @override
  String get dataQuality_chip_sources => 'Sources';

  @override
  String get dataQuality_detector_clock_offset => 'Horloge et fuseau horaire';

  @override
  String get dataQuality_detector_duplicate => 'Doublon probable';

  @override
  String get dataQuality_detector_split_pair => 'Scission accidentelle';

  @override
  String get dataQuality_detector_sample_gap => 'Trous dans les échantillons';

  @override
  String get dataQuality_detector_depth_spike => 'Pic de profondeur';

  @override
  String get dataQuality_detector_impossible_rate => 'Vitesse impossible';

  @override
  String get dataQuality_detector_temp_anomaly => 'Anomalie de température';

  @override
  String get dataQuality_detector_pressure_anomaly => 'Anomalie de pression';

  @override
  String get dataQuality_detector_gas_mod => 'Incohérence gaz/MOD';

  @override
  String get dataQuality_detector_tank_assignment => 'Mauvais bloc';

  @override
  String get dataQuality_detector_source_conflict => 'Sources contradictoires';

  @override
  String dataQuality_msg_clock_future(String date) {
    return 'La plongée est datée dans le futur ($date)';
  }

  @override
  String dataQuality_msg_clock_ancient(String date) {
    return 'La plongée est datée avant 1950 ($date)';
  }

  @override
  String dataQuality_msg_clock_offset(int hours) {
    return 'L\'horloge d\'une source diffère de $hours heures';
  }

  @override
  String dataQuality_msg_clock_overlap(int minutes) {
    return 'Chevauche une autre plongée de $minutes min';
  }

  @override
  String dataQuality_msg_duplicate(int percent, int minutes) {
    return '$percent % de correspondance avec une plongée espacée de $minutes min';
  }

  @override
  String dataQuality_msg_split(int minutes) {
    return 'Le même ordinateur a repris après un intervalle de surface de $minutes min';
  }

  @override
  String dataQuality_msg_gap(int count, String longest) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trous dans les échantillons',
      one: '1 trou dans les échantillons',
    );
    return '$_temp0, le plus long $longest';
  }

  @override
  String dataQuality_msg_spike(String depth, String time) {
    return 'Pic de profondeur à $depth à $time';
  }

  @override
  String dataQuality_msg_negativeDepth(int count) {
    return '$count échantillons de profondeur négative';
  }

  @override
  String dataQuality_msg_maxDepthMismatch(String stored, String profile) {
    return 'Profondeur maximale enregistrée $stored, mais le profil indique $profile';
  }

  @override
  String dataQuality_msg_rate(String rate, int seconds) {
    return 'Vitesse verticale de $rate maintenue pendant $seconds s';
  }

  @override
  String dataQuality_msg_tempRange(String min, String max) {
    return 'Température de l\'eau hors de la plage plausible ($min à $max)';
  }

  @override
  String get dataQuality_msg_tempUnitBug =>
      'Les valeurs ressemblent à une erreur d\'unité de température';

  @override
  String dataQuality_msg_tempJump(String delta) {
    return 'La température a bondi de $delta en un seul échantillon';
  }

  @override
  String dataQuality_msg_tempScalar(String temp) {
    return 'La température de l\'eau enregistrée $temp est invraisemblable';
  }

  @override
  String dataQuality_msg_pressureSwap(String end, String start) {
    return 'La pression de fin $end est supérieure à la pression de début $start';
  }

  @override
  String dataQuality_msg_pressureEndpoint(String record, String series) {
    return 'L\'enregistrement du bloc indique $record, mais la série du capteur montre $series';
  }

  @override
  String dataQuality_msg_pressureRise(String rise) {
    return 'La pression a augmenté de $rise en cours de plongée sans changement de gaz';
  }

  @override
  String dataQuality_msg_sac(String sac) {
    return 'La consommation en surface implicite de $sac est invraisemblable';
  }

  @override
  String dataQuality_msg_ppo2(String ppo2, String gas, String depth) {
    return 'La ppO2 a atteint $ppo2 avec $gas à $depth';
  }

  @override
  String dataQuality_msg_hypoxic(String gas) {
    return 'Mélange hypoxique ($gas) indiqué comme utilisé en surface';
  }

  @override
  String dataQuality_msg_switchMod(String depth, String mod) {
    return 'Le changement de gaz à $depth dépasse la MOD de $mod de ce gaz';
  }

  @override
  String dataQuality_msg_tankInactive(String drop) {
    return 'Ce bloc a perdu $drop alors que la chronologie des gaz indique qu\'il n\'était pas utilisé';
  }

  @override
  String get dataQuality_msg_twinTanks =>
      'Deux blocs présentent une série de pression quasi identique';

  @override
  String dataQuality_msg_sourceDepth(String primary, String source) {
    return 'Les sources divergent sur la profondeur maximale : $primary contre $source';
  }

  @override
  String get dataQuality_msg_salinityHint =>
      'Le rapport constant suggère une différence de réglage eau salée/eau douce';

  @override
  String get dataQuality_msg_sourceDuration =>
      'Les sources divergent sur la durée de la plongée';

  @override
  String get dataQuality_msg_sourceTemp =>
      'Les sources divergent sur la température de l\'eau';

  @override
  String dataQuality_repairLabel_shiftTime(String offset) {
    return 'Décaler l\'heure de $offset';
  }

  @override
  String get dataQuality_repairLabel_shiftImport =>
      'Décaler toutes les plongées de cet import';

  @override
  String get dataQuality_repairLabel_consolidate => 'Consolider';

  @override
  String get dataQuality_repairLabel_combine => 'Combiner en une seule plongée';

  @override
  String get dataQuality_repairLabel_despike => 'Supprimer le pic';

  @override
  String get dataQuality_repairLabel_clampNegative =>
      'Ramener les profondeurs négatives à zéro';

  @override
  String get dataQuality_repairLabel_smoothRates =>
      'Lisser les vitesses impossibles';

  @override
  String get dataQuality_repairLabel_fillGaps => 'Combler les trous';

  @override
  String get dataQuality_repairLabel_smoothTemp => 'Lisser la température';

  @override
  String get dataQuality_repairLabel_convertTemp => 'Convertir la température';

  @override
  String get dataQuality_repairLabel_recompute =>
      'Recalculer à partir du profil';

  @override
  String get dataQuality_repairLabel_swapPressures =>
      'Intervertir pression de début/fin';

  @override
  String get dataQuality_repairLabel_setFromSeries =>
      'Utiliser les valeurs du capteur';

  @override
  String get dataQuality_repairLabel_swapSeries =>
      'Intervertir les séries de blocs';

  @override
  String get dataQuality_repairLabel_reassignSeries =>
      'Déplacer la série vers un autre bloc';

  @override
  String get dataQuality_repairLabel_setPrimary =>
      'Définir cette source comme principale';

  @override
  String get dataQuality_repairLabel_split => 'Diviser en plongées distinctes';

  @override
  String get dataQuality_repairLabel_compare => 'Comparer les profils';

  @override
  String get dataQuality_settings_title => 'Qualité des données';

  @override
  String get dataQuality_settings_subtitle =>
      'Choisir les contrôles exécutés lors de l\'analyse';

  @override
  String dataQuality_summary_flagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments signalés à vérifier',
      one: '1 élément signalé à vérifier',
    );
    return '$_temp0';
  }

  @override
  String get dataQuality_summary_review => 'Vérifier';

  @override
  String get dataQuality_detail_chip => 'Vérifier';

  @override
  String dataQuality_detail_chipCount(int count) {
    return 'Vérifier ($count)';
  }

  @override
  String get settings_mediaStorage_quality_section =>
      'Qualité de téléversement';

  @override
  String get settings_mediaStorage_quality_photos => 'Photos';

  @override
  String get settings_mediaStorage_quality_video => 'Vidéo';

  @override
  String get settings_mediaStorage_quality_original => 'Original';

  @override
  String get settings_mediaStorage_quality_high => 'Élevée';

  @override
  String get settings_mediaStorage_quality_balanced => 'Équilibrée';

  @override
  String get settings_mediaStorage_quality_small => 'Petite';

  @override
  String get settings_mediaStorage_quality_caveat =>
      'Lorsqu\'un niveau de compression est défini, les originaux en pleine résolution ne sont pas téléversés ; ils restent uniquement sur cet appareil.';

  @override
  String get settings_mediaStorage_quality_reuploadQueued =>
      'Nouveau téléversement en file d\'attente';

  @override
  String get settings_mediaStorage_quality_linuxFfmpegHint =>
      'Installez ffmpeg pour activer la compression vidéo. Les originaux sont téléversés d\'ici là.';

  @override
  String get settings_mediaStorage_quality_saveFailed =>
      'Impossible d\'enregistrer la qualité de téléversement. Réessayez.';

  @override
  String get settings_mediaStorage_quality_noTranscoderHint =>
      'Cet appareil ne peut pas compresser la vidéo. Les originaux sont téléversés depuis celui-ci.';

  @override
  String get reef_section_title => 'Écosystème';

  @override
  String get reef_section_sourcesTooltip => 'Sources de données';

  @override
  String get reef_section_loadError =>
      'Impossible de charger les données de l\'écosystème pour le moment';

  @override
  String get reef_habitat_title => 'Habitat du récif';

  @override
  String get reef_habitat_onReef => 'Sur un récif corallien';

  @override
  String reef_habitat_onReefWithThreat(String threat) {
    return 'Sur un récif corallien, niveau de menace $threat';
  }

  @override
  String get reef_habitat_noReef =>
      'Aucun récif corallien cartographié à cet endroit';

  @override
  String get reef_habitat_unavailable =>
      'Impossible de vérifier l\'habitat du récif pour le moment';

  @override
  String get water_conditions_title => 'Conditions de l\'eau';

  @override
  String get water_conditions_unavailable =>
      'Impossible de vérifier les conditions de l\'eau pour le moment';

  @override
  String get water_conditions_noData =>
      'Aucune donnée satellite sur l\'eau pour cet emplacement';

  @override
  String get water_conditions_freshwater =>
      'La température de l\'eau par satellite ne couvre que les océans';

  @override
  String water_conditions_anomaly(String value) {
    return 'Anomalie $value';
  }

  @override
  String reef_health_degreeHeatingWeeks(String value) {
    return 'Degrés-semaines de chaleur $value C-semaines';
  }

  @override
  String reef_health_seaSurface(String value) {
    return 'Surface de la mer $value';
  }

  @override
  String reef_health_asOf(String date) {
    return 'Au $date';
  }

  @override
  String get reef_health_levelNoStress => 'Aucun stress thermique';

  @override
  String get reef_health_levelWatch => 'Veille de blanchissement';

  @override
  String get reef_health_levelWarning => 'Alerte de blanchissement';

  @override
  String get reef_health_levelAlert1 => 'Alerte de blanchissement niveau 1';

  @override
  String get reef_health_levelAlert2 => 'Alerte de blanchissement niveau 2';

  @override
  String get reef_health_levelAlert3 => 'Alerte de blanchissement niveau 3';

  @override
  String get reef_health_levelAlert4 => 'Alerte de blanchissement niveau 4';

  @override
  String get reef_health_levelAlert5 => 'Alerte de blanchissement niveau 5';

  @override
  String get reef_protection_title => 'Aire protégée';

  @override
  String get reef_protection_none => 'Hors aire marine protégée';

  @override
  String get reef_protection_unavailable =>
      'Impossible de vérifier le statut de protection pour le moment';

  @override
  String get reef_protection_viewRegulations => 'Voir la réglementation';

  @override
  String reef_protection_iucn(String category) {
    return 'IUCN $category';
  }

  @override
  String get reef_species_recordedNearby => 'Observé à proximité';

  @override
  String get reef_species_addToExpected => 'Ajouter aux espèces attendues';

  @override
  String reef_species_showAll(int count) {
    return 'Afficher les $count';
  }

  @override
  String get reef_species_showFewer => 'Afficher moins';

  @override
  String get reef_attribution_title => 'Sources de données du récif';

  @override
  String get reef_attribution_wri =>
      'Présence de récif et niveau de menace. CC BY 3.0.';

  @override
  String get reef_attribution_noaa =>
      'Température de surface et stress thermique. Domaine public.';

  @override
  String get reef_attribution_gbif =>
      'Données d\'occurrence d\'espèces, filtrées en CC0 et CC BY 4.0.';

  @override
  String get reef_attribution_protectedSeas =>
      'Limites des aires marines protégées. CC BY 4.0.';

  @override
  String get enum_visibilityBand_excellent => 'Excellente';

  @override
  String get enum_visibilityBand_good => 'Bonne';

  @override
  String get enum_visibilityBand_moderate => 'Moyenne';

  @override
  String get enum_visibilityBand_poor => 'Mauvaise';

  @override
  String visibility_range_between(String min, String max, String unit) {
    return '$min-$max $unit';
  }

  @override
  String visibility_range_over(String min, String unit) {
    return 'plus de $min $unit';
  }

  @override
  String visibility_range_under(String max, String unit) {
    return 'moins de $max $unit';
  }

  @override
  String get settings_coordinateFormat_title => 'Format des coordonnées';

  @override
  String get settings_coordinateFormat_subtitle =>
      'Comment les positions GPS sont affichées et saisies';

  @override
  String get settings_placeNameLanguage_title => 'Langue des noms de lieux';

  @override
  String get settings_placeNameLanguage_subtitle =>
      'Utilisée lorsque le pays, la région, la ville et le plan d\'eau sont déduits des coordonnées. Les sites existants ne sont pas modifiés.';

  @override
  String get settings_coordinateFormat_decimalDegrees => 'Degrés décimaux';

  @override
  String get settings_coordinateFormat_degreesDecimalMinutes =>
      'Degrés et minutes décimales';

  @override
  String get settings_coordinateFormat_degreesMinutesSeconds =>
      'Degrés, minutes, secondes';

  @override
  String get settings_coordinateFormat_utm => 'UTM';

  @override
  String get settings_coordinateFormat_mgrs => 'MGRS';

  @override
  String get settings_visibilityScale_title => 'Échelle de visibilité';

  @override
  String get settings_visibilityScale_subtitle =>
      'Les distances qui comptent comme une bonne visibilité là où vous plongez';

  @override
  String get settings_visibilityScale_preset_tropical => 'Tropicale';

  @override
  String get settings_visibilityScale_preset_temperate => 'Tempérée';

  @override
  String get settings_visibilityScale_preset_coldWater =>
      'Eau froide / Intérieure';

  @override
  String get settings_visibilityScale_preset_custom => 'Personnalisée';

  @override
  String get settings_visibilityScale_customExcellent =>
      'Excellente à partir de';

  @override
  String get settings_visibilityScale_customGood => 'Bonne à partir de';

  @override
  String get settings_visibilityScale_customModerate => 'Moyenne à partir de';

  @override
  String get settings_visibilityScale_invalidOrder =>
      'Chaque valeur doit être inférieure à celle du dessus et supérieure à zéro';

  @override
  String statistics_conditions_visibility_legacySuffix(String band) {
    return '$band (enregistré avant la mesure)';
  }

  @override
  String common_selection_countSelected(Object count) {
    return '$count sélectionnés';
  }

  @override
  String get common_selection_enterTooltip => 'Sélectionner des éléments';

  @override
  String get common_selection_exitTooltip => 'Quitter la sélection';

  @override
  String get common_selection_selectAllTooltip => 'Tout sélectionner';

  @override
  String get common_selection_deselectAllTooltip => 'Tout désélectionner';

  @override
  String common_bulkDelete_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count éléments ?',
      one: 'Supprimer $count élément ?',
    );
    return '$_temp0';
  }

  @override
  String get common_bulkDelete_body => 'Cette action est irréversible.';

  @override
  String common_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count supprimés',
      one: '$count supprimé',
    );
    return '$_temp0';
  }

  @override
  String get marineLife_species_delete_confirmTitle => 'Supprimer l\'espèce ?';

  @override
  String marineLife_species_delete_confirmBody(String name) {
    return 'Voulez-vous vraiment supprimer \"$name\" ?';
  }

  @override
  String marineLife_species_delete_inUseError(String name) {
    return 'Impossible de supprimer \"$name\" - elle a des observations';
  }

  @override
  String marineLife_species_delete_snackbar(String name) {
    return '\"$name\" supprimée';
  }

  @override
  String marineLife_species_delete_error(String error) {
    return 'Erreur lors de la suppression de l\'espèce : $error';
  }

  @override
  String get enum_diveField_diveNumber => 'Numéro de plongée';

  @override
  String get enum_diveField_dateTime => 'Date et heure';

  @override
  String get enum_diveField_siteName => 'Nom du site';

  @override
  String get enum_diveField_diveName => 'Nom de la plongée';

  @override
  String get enum_diveField_maxDepth => 'Profondeur max';

  @override
  String get enum_diveField_avgDepth => 'Profondeur moyenne';

  @override
  String get enum_diveField_bottomTime => 'Temps au fond';

  @override
  String get enum_diveField_runtime => 'Durée totale';

  @override
  String get enum_diveField_waterTemp => 'Température de l\'eau';

  @override
  String get enum_diveField_airTemp => 'Température de l\'air';

  @override
  String get enum_diveField_visibility => 'Visibilité';

  @override
  String get enum_diveField_currentDirection => 'Direction du courant';

  @override
  String get enum_diveField_currentStrength => 'Force du courant';

  @override
  String get enum_diveField_swellHeight => 'Hauteur de houle';

  @override
  String get enum_diveField_entryMethod => 'Méthode d\'entrée';

  @override
  String get enum_diveField_exitMethod => 'Méthode de sortie';

  @override
  String get enum_diveField_waterType => 'Type d\'eau';

  @override
  String get enum_diveField_altitude => 'Altitude';

  @override
  String get enum_diveField_surfacePressure => 'Pression de surface';

  @override
  String get enum_diveField_windSpeed => 'Vitesse du vent';

  @override
  String get enum_diveField_cloudCover => 'Couverture nuageuse';

  @override
  String get enum_diveField_precipitation => 'Précipitations';

  @override
  String get enum_diveField_humidity => 'Humidité';

  @override
  String get enum_diveField_weatherDescription => 'Météo';

  @override
  String get enum_diveField_primaryGas => 'Gaz principal';

  @override
  String get enum_diveField_diluentGas => 'Gaz diluant';

  @override
  String get enum_diveField_tankCount => 'Nombre de blocs';

  @override
  String get enum_diveField_startPressure => 'Pression initiale';

  @override
  String get enum_diveField_endPressure => 'Pression finale';

  @override
  String get enum_diveField_sacRate => 'Consommation SAC';

  @override
  String get enum_diveField_gasConsumed => 'Gaz consommé';

  @override
  String get enum_diveField_totalWeight => 'Lestage total';

  @override
  String get enum_diveField_diveComputerModel => 'Ordinateur de plongée';

  @override
  String get enum_diveField_gradientFactorLow => 'GF bas';

  @override
  String get enum_diveField_gradientFactorHigh => 'GF haut';

  @override
  String get enum_diveField_decoAlgorithm => 'Algorithme déco';

  @override
  String get enum_diveField_decoConservatism => 'Conservatisme';

  @override
  String get enum_diveField_cnsStart => 'CNS début';

  @override
  String get enum_diveField_cnsEnd => 'CNS fin';

  @override
  String get enum_diveField_otu => 'OTU';

  @override
  String get enum_diveField_diveMode => 'Mode de plongée';

  @override
  String get enum_diveField_setpointLow => 'Consigne basse';

  @override
  String get enum_diveField_setpointHigh => 'Consigne haute';

  @override
  String get enum_diveField_setpointDeco => 'Consigne déco';

  @override
  String get enum_diveField_buddy => 'Binôme';

  @override
  String get enum_diveField_diveMaster => 'Directeur de plongée';

  @override
  String get enum_diveField_siteLocation => 'Lieu du site';

  @override
  String get enum_diveField_diveCenterName => 'Centre de plongée';

  @override
  String get enum_diveField_siteLatitude => 'Latitude';

  @override
  String get enum_diveField_siteLongitude => 'Longitude';

  @override
  String get enum_diveField_tripName => 'Voyage';

  @override
  String get enum_diveField_ratingStars => 'Évaluation';

  @override
  String get enum_diveField_isFavorite => 'Favori';

  @override
  String get enum_diveField_notes => 'Notes';

  @override
  String get enum_diveField_tags => 'Tags';

  @override
  String get enum_diveField_importSource => 'Source d\'import';

  @override
  String get enum_diveField_diveTypeName => 'Type de plongée';

  @override
  String get enum_diveField_surfaceInterval => 'Intervalle de surface';

  @override
  String get enum_diveField_diveNumber_short => '#';

  @override
  String get enum_diveField_dateTime_short => 'Date';

  @override
  String get enum_diveField_siteName_short => 'Site';

  @override
  String get enum_diveField_diveName_short => 'Nom';

  @override
  String get enum_diveField_maxDepth_short => 'P max';

  @override
  String get enum_diveField_avgDepth_short => 'P moy';

  @override
  String get enum_diveField_bottomTime_short => 'TF';

  @override
  String get enum_diveField_runtime_short => 'DT';

  @override
  String get enum_diveField_waterTemp_short => 'T eau';

  @override
  String get enum_diveField_airTemp_short => 'T air';

  @override
  String get enum_diveField_visibility_short => 'Vis';

  @override
  String get enum_diveField_currentDirection_short => 'Dir cour.';

  @override
  String get enum_diveField_currentStrength_short => 'Cour.';

  @override
  String get enum_diveField_swellHeight_short => 'Houle';

  @override
  String get enum_diveField_entryMethod_short => 'Entrée';

  @override
  String get enum_diveField_exitMethod_short => 'Sortie';

  @override
  String get enum_diveField_waterType_short => 'Eau';

  @override
  String get enum_diveField_altitude_short => 'Alt';

  @override
  String get enum_diveField_surfacePressure_short => 'P surf.';

  @override
  String get enum_diveField_windSpeed_short => 'Vent';

  @override
  String get enum_diveField_cloudCover_short => 'Nuages';

  @override
  String get enum_diveField_precipitation_short => 'Précip.';

  @override
  String get enum_diveField_humidity_short => 'Humid.';

  @override
  String get enum_diveField_weatherDescription_short => 'Météo';

  @override
  String get enum_diveField_primaryGas_short => 'Gaz';

  @override
  String get enum_diveField_diluentGas_short => 'Dil';

  @override
  String get enum_diveField_tankCount_short => 'Blocs';

  @override
  String get enum_diveField_startPressure_short => 'P début';

  @override
  String get enum_diveField_endPressure_short => 'P fin';

  @override
  String get enum_diveField_sacRate_short => 'SAC';

  @override
  String get enum_diveField_gasConsumed_short => 'Gaz cons.';

  @override
  String get enum_diveField_totalWeight_short => 'Lest';

  @override
  String get enum_diveField_diveComputerModel_short => 'Ordi.';

  @override
  String get enum_diveField_gradientFactorLow_short => 'GFL';

  @override
  String get enum_diveField_gradientFactorHigh_short => 'GFH';

  @override
  String get enum_diveField_decoAlgorithm_short => 'Algo';

  @override
  String get enum_diveField_decoConservatism_short => 'Conserv.';

  @override
  String get enum_diveField_cnsStart_short => 'CNS début';

  @override
  String get enum_diveField_cnsEnd_short => 'CNS fin';

  @override
  String get enum_diveField_otu_short => 'OTU';

  @override
  String get enum_diveField_diveMode_short => 'Mode';

  @override
  String get enum_diveField_setpointLow_short => 'SP bas';

  @override
  String get enum_diveField_setpointHigh_short => 'SP haut';

  @override
  String get enum_diveField_setpointDeco_short => 'SP déco';

  @override
  String get enum_diveField_buddy_short => 'Binôme';

  @override
  String get enum_diveField_diveMaster_short => 'DP';

  @override
  String get enum_diveField_siteLocation_short => 'Lieu';

  @override
  String get enum_diveField_diveCenterName_short => 'Centre';

  @override
  String get enum_diveField_siteLatitude_short => 'Lat';

  @override
  String get enum_diveField_siteLongitude_short => 'Long';

  @override
  String get enum_diveField_tripName_short => 'Voyage';

  @override
  String get enum_diveField_ratingStars_short => 'Éval.';

  @override
  String get enum_diveField_isFavorite_short => 'Fav';

  @override
  String get enum_diveField_notes_short => 'Notes';

  @override
  String get enum_diveField_tags_short => 'Tags';

  @override
  String get enum_diveField_importSource_short => 'Source';

  @override
  String get enum_diveField_diveTypeName_short => 'Type';

  @override
  String get enum_diveField_surfaceInterval_short => 'IS';

  @override
  String get enum_siteField_siteName => 'Nom';

  @override
  String get enum_siteField_location => 'Lieu';

  @override
  String get enum_siteField_country => 'Pays';

  @override
  String get enum_siteField_region => 'Région';

  @override
  String get enum_siteField_city => 'Ville';

  @override
  String get enum_siteField_island => 'Île';

  @override
  String get enum_siteField_bodyOfWater => 'Plan d\'eau';

  @override
  String get enum_siteField_diveCount => 'Nombre de plongées';

  @override
  String get enum_siteField_maxDepth => 'Profondeur max';

  @override
  String get enum_siteField_minDepth => 'Profondeur min';

  @override
  String get enum_siteField_altitude => 'Altitude';

  @override
  String get enum_siteField_waterType => 'Type d\'eau';

  @override
  String get enum_siteField_typicalVisibility => 'Visibilité typique';

  @override
  String get enum_siteField_typicalCurrent => 'Courant typique';

  @override
  String get enum_siteField_difficulty => 'Difficulté';

  @override
  String get enum_siteField_entryType => 'Type de mise à l\'eau';

  @override
  String get enum_siteField_bestSeason => 'Meilleure saison';

  @override
  String get enum_siteField_mooringNumber => 'Numéro de mouillage';

  @override
  String get enum_siteField_hazards => 'Dangers';

  @override
  String get enum_siteField_rating => 'Évaluation';

  @override
  String get enum_siteField_notes => 'Notes';

  @override
  String get enum_siteField_latitude => 'Latitude';

  @override
  String get enum_siteField_longitude => 'Longitude';

  @override
  String get enum_siteField_siteName_short => 'Nom';

  @override
  String get enum_siteField_location_short => 'Lieu';

  @override
  String get enum_siteField_country_short => 'Pays';

  @override
  String get enum_siteField_region_short => 'Région';

  @override
  String get enum_siteField_city_short => 'Ville';

  @override
  String get enum_siteField_island_short => 'Île';

  @override
  String get enum_siteField_bodyOfWater_short => 'Plan d\'eau';

  @override
  String get enum_siteField_diveCount_short => 'Plong.';

  @override
  String get enum_siteField_maxDepth_short => 'P max';

  @override
  String get enum_siteField_minDepth_short => 'P min';

  @override
  String get enum_siteField_altitude_short => 'Alt';

  @override
  String get enum_siteField_waterType_short => 'Eau';

  @override
  String get enum_siteField_typicalVisibility_short => 'Vis';

  @override
  String get enum_siteField_typicalCurrent_short => 'Courant';

  @override
  String get enum_siteField_difficulty_short => 'Diff.';

  @override
  String get enum_siteField_entryType_short => 'Entrée';

  @override
  String get enum_siteField_exitMethod => 'Méthode de sortie';

  @override
  String get enum_siteField_exitMethod_short => 'Sortie';

  @override
  String get enum_siteField_bestSeason_short => 'Saison';

  @override
  String get enum_siteField_mooringNumber_short => 'Mouill.';

  @override
  String get enum_siteField_hazards_short => 'Dangers';

  @override
  String get enum_siteField_rating_short => 'Éval.';

  @override
  String get enum_siteField_notes_short => 'Notes';

  @override
  String get enum_siteField_latitude_short => 'Lat';

  @override
  String get enum_siteField_longitude_short => 'Long';

  @override
  String get enum_siteField_depthRange => 'Plage de profondeur';

  @override
  String get enum_siteField_depthRange_short => 'Prof.';

  @override
  String get enum_siteField_lastDived => 'Dernière plongée';

  @override
  String get enum_siteField_lastDived_short => 'Dernière';

  @override
  String get enum_siteField_maxDepthReached => 'Votre prof. max';

  @override
  String get enum_siteField_maxDepthReached_short => 'Votre max';

  @override
  String get enum_buddyField_buddyName => 'Nom';

  @override
  String get enum_buddyField_email => 'E-mail';

  @override
  String get enum_buddyField_phone => 'Téléphone';

  @override
  String get enum_buddyField_certificationLevel => 'Niveau de certification';

  @override
  String get enum_buddyField_certificationAgency =>
      'Organisme de certification';

  @override
  String get enum_buddyField_diveCount => 'Nombre de plongées';

  @override
  String get enum_buddyField_notes => 'Notes';

  @override
  String get enum_buddyField_buddyName_short => 'Nom';

  @override
  String get enum_buddyField_email_short => 'E-mail';

  @override
  String get enum_buddyField_phone_short => 'Tél.';

  @override
  String get enum_buddyField_certificationLevel_short => 'Niveau';

  @override
  String get enum_buddyField_certificationAgency_short => 'Orga.';

  @override
  String get enum_buddyField_diveCount_short => 'Plong.';

  @override
  String get enum_buddyField_notes_short => 'Notes';

  @override
  String get enum_buddyField_lastDive => 'Dernière plongée';

  @override
  String get enum_buddyField_lastDive_short => 'Dernière';

  @override
  String get enum_tripField_tripName => 'Nom';

  @override
  String get enum_tripField_startDate => 'Date de début';

  @override
  String get enum_tripField_endDate => 'Date de fin';

  @override
  String get enum_tripField_durationDays => 'Durée';

  @override
  String get enum_tripField_location => 'Lieu';

  @override
  String get enum_tripField_tripType => 'Type de voyage';

  @override
  String get enum_tripField_resortName => 'Resort';

  @override
  String get enum_tripField_liveaboardName => 'Croisière';

  @override
  String get enum_tripField_diveCount => 'Nombre de plongées';

  @override
  String get enum_tripField_totalRuntime => 'Durée totale cumulée';

  @override
  String get enum_tripField_maxDepth => 'Profondeur max';

  @override
  String get enum_tripField_avgDepth => 'Profondeur moyenne';

  @override
  String get enum_tripField_notes => 'Notes';

  @override
  String get enum_tripField_tripName_short => 'Nom';

  @override
  String get enum_tripField_startDate_short => 'Début';

  @override
  String get enum_tripField_endDate_short => 'Fin';

  @override
  String get enum_tripField_durationDays_short => 'Jours';

  @override
  String get enum_tripField_location_short => 'Lieu';

  @override
  String get enum_tripField_tripType_short => 'Type';

  @override
  String get enum_tripField_resortName_short => 'Resort';

  @override
  String get enum_tripField_liveaboardName_short => 'Croisière';

  @override
  String get enum_tripField_diveCount_short => 'Plong.';

  @override
  String get enum_tripField_totalRuntime_short => 'DT cumul.';

  @override
  String get enum_tripField_maxDepth_short => 'P max';

  @override
  String get enum_tripField_avgDepth_short => 'P moy';

  @override
  String get enum_tripField_notes_short => 'Notes';

  @override
  String get enum_equipmentField_itemName => 'Nom';

  @override
  String get enum_equipmentField_fullName => 'Nom complet';

  @override
  String get enum_equipmentField_type => 'Type';

  @override
  String get enum_equipmentField_brand => 'Marque';

  @override
  String get enum_equipmentField_model => 'Modèle';

  @override
  String get enum_equipmentField_serialNumber => 'Numéro de série';

  @override
  String get enum_equipmentField_size => 'Taille';

  @override
  String get enum_equipmentField_status => 'Statut';

  @override
  String get enum_equipmentField_isActive => 'Actif';

  @override
  String get enum_equipmentField_purchaseDate => 'Date d\'achat';

  @override
  String get enum_equipmentField_purchasePrice => 'Prix d\'achat';

  @override
  String get enum_equipmentField_lastServiceDate => 'Dernière révision';

  @override
  String get enum_equipmentField_nextServiceDue => 'Prochaine révision';

  @override
  String get enum_equipmentField_daysUntilService => 'Jours avant révision';

  @override
  String get enum_equipmentField_serviceIntervalDays =>
      'Intervalle de révision';

  @override
  String get enum_equipmentField_notes => 'Notes';

  @override
  String get enum_equipmentField_itemName_short => 'Nom';

  @override
  String get enum_equipmentField_fullName_short => 'Nom compl.';

  @override
  String get enum_equipmentField_type_short => 'Type';

  @override
  String get enum_equipmentField_brand_short => 'Marque';

  @override
  String get enum_equipmentField_model_short => 'Modèle';

  @override
  String get enum_equipmentField_serialNumber_short => 'N° série';

  @override
  String get enum_equipmentField_size_short => 'Taille';

  @override
  String get enum_equipmentField_status_short => 'Statut';

  @override
  String get enum_equipmentField_isActive_short => 'Actif';

  @override
  String get enum_equipmentField_purchaseDate_short => 'Acheté';

  @override
  String get enum_equipmentField_purchasePrice_short => 'Prix';

  @override
  String get enum_equipmentField_lastServiceDate_short => 'Révisé';

  @override
  String get enum_equipmentField_nextServiceDue_short => 'Échéance';

  @override
  String get enum_equipmentField_daysUntilService_short => 'J. rest.';

  @override
  String get enum_equipmentField_serviceIntervalDays_short => 'Interv.';

  @override
  String get enum_equipmentField_notes_short => 'Notes';

  @override
  String get enum_diveCenterField_centerName => 'Nom';

  @override
  String get enum_diveCenterField_city => 'Ville';

  @override
  String get enum_diveCenterField_country => 'Pays';

  @override
  String get enum_diveCenterField_stateProvince => 'État / Province';

  @override
  String get enum_diveCenterField_street => 'Rue';

  @override
  String get enum_diveCenterField_postalCode => 'Code postal';

  @override
  String get enum_diveCenterField_phone => 'Téléphone';

  @override
  String get enum_diveCenterField_email => 'E-mail';

  @override
  String get enum_diveCenterField_website => 'Site web';

  @override
  String get enum_diveCenterField_affiliations => 'Affiliations';

  @override
  String get enum_diveCenterField_rating => 'Évaluation';

  @override
  String get enum_diveCenterField_latitude => 'Latitude';

  @override
  String get enum_diveCenterField_longitude => 'Longitude';

  @override
  String get enum_diveCenterField_diveCount => 'Nombre de plongées';

  @override
  String get enum_diveCenterField_notes => 'Notes';

  @override
  String get enum_diveCenterField_centerName_short => 'Nom';

  @override
  String get enum_diveCenterField_city_short => 'Ville';

  @override
  String get enum_diveCenterField_country_short => 'Pays';

  @override
  String get enum_diveCenterField_stateProvince_short => 'État';

  @override
  String get enum_diveCenterField_street_short => 'Rue';

  @override
  String get enum_diveCenterField_postalCode_short => 'CP';

  @override
  String get enum_diveCenterField_phone_short => 'Tél.';

  @override
  String get enum_diveCenterField_email_short => 'E-mail';

  @override
  String get enum_diveCenterField_website_short => 'Site web';

  @override
  String get enum_diveCenterField_affiliations_short => 'Affiliations';

  @override
  String get enum_diveCenterField_rating_short => 'Éval.';

  @override
  String get enum_diveCenterField_latitude_short => 'Lat';

  @override
  String get enum_diveCenterField_longitude_short => 'Long';

  @override
  String get enum_diveCenterField_diveCount_short => 'Plong.';

  @override
  String get enum_diveCenterField_notes_short => 'Notes';

  @override
  String get enum_certificationField_certName => 'Nom';

  @override
  String get enum_certificationField_agency => 'Organisme';

  @override
  String get enum_certificationField_level => 'Certification';

  @override
  String get enum_certificationField_cardNumber => 'Numéro de carte';

  @override
  String get enum_certificationField_issueDate => 'Date de délivrance';

  @override
  String get enum_certificationField_expiryDate => 'Date d\'expiration';

  @override
  String get enum_certificationField_instructorName => 'Nom de l\'instructeur';

  @override
  String get enum_certificationField_instructorNumber =>
      'Numéro d\'instructeur';

  @override
  String get enum_certificationField_expiryStatus => 'Statut d\'expiration';

  @override
  String get enum_certificationField_notes => 'Notes';

  @override
  String get enum_certificationField_certName_short => 'Nom';

  @override
  String get enum_certificationField_agency_short => 'Orga.';

  @override
  String get enum_certificationField_level_short => 'Certification';

  @override
  String get enum_certificationField_cardNumber_short => 'N° carte';

  @override
  String get enum_certificationField_issueDate_short => 'Délivrée';

  @override
  String get enum_certificationField_expiryDate_short => 'Expire';

  @override
  String get enum_certificationField_instructorName_short => 'Instructeur';

  @override
  String get enum_certificationField_instructorNumber_short => 'N° instr.';

  @override
  String get enum_certificationField_expiryStatus_short => 'Statut';

  @override
  String get enum_certificationField_notes_short => 'Notes';

  @override
  String get enum_courseField_courseName => 'Nom';

  @override
  String get enum_courseField_agency => 'Organisme';

  @override
  String get enum_courseField_startDate => 'Date de début';

  @override
  String get enum_courseField_completionDate => 'Date de fin';

  @override
  String get enum_courseField_durationDays => 'Durée';

  @override
  String get enum_courseField_instructorName => 'Nom de l\'instructeur';

  @override
  String get enum_courseField_instructorNumber => 'Numéro d\'instructeur';

  @override
  String get enum_courseField_location => 'Lieu';

  @override
  String get enum_courseField_isCompleted => 'Terminé';

  @override
  String get enum_courseField_notes => 'Notes';

  @override
  String get enum_courseField_courseName_short => 'Nom';

  @override
  String get enum_courseField_agency_short => 'Orga.';

  @override
  String get enum_courseField_startDate_short => 'Début';

  @override
  String get enum_courseField_completionDate_short => 'Terminé';

  @override
  String get enum_courseField_durationDays_short => 'Durée';

  @override
  String get enum_courseField_instructorName_short => 'Instructeur';

  @override
  String get enum_courseField_instructorNumber_short => 'N° instr.';

  @override
  String get enum_courseField_location_short => 'Lieu';

  @override
  String get enum_courseField_isCompleted_short => 'Fait';

  @override
  String get enum_courseField_notes_short => 'Notes';

  @override
  String get enum_fieldCategory_accommodation => 'Hébergement';

  @override
  String get enum_fieldCategory_address => 'Adresse';

  @override
  String get enum_fieldCategory_certification => 'Certification';

  @override
  String get enum_fieldCategory_conditions => 'Conditions';

  @override
  String get enum_fieldCategory_contact => 'Contact';

  @override
  String get enum_fieldCategory_coordinates => 'Coordonnées';

  @override
  String get enum_fieldCategory_dates => 'Dates';

  @override
  String get enum_fieldCategory_depth => 'Profondeur';

  @override
  String get enum_fieldCategory_details => 'Détails';

  @override
  String get enum_fieldCategory_instructor => 'Instructeur';

  @override
  String get enum_fieldCategory_other => 'Autre';

  @override
  String get enum_fieldCategory_purchase => 'Achat';

  @override
  String get enum_fieldCategory_service => 'Révision';

  @override
  String get enum_fieldCategory_statistics => 'Statistiques';

  @override
  String get species_whale_shark_name => 'Requin-baleine';

  @override
  String get species_whale_shark_desc =>
      'Le plus grand poisson de l\'océan, filtreur paisible au motif tacheté caractéristique.';

  @override
  String get species_great_white_shark_name => 'Grand requin blanc';

  @override
  String get species_great_white_shark_desc =>
      'Prédateur emblématique parfois observé depuis une cage dans les eaux tempérées.';

  @override
  String get species_great_hammerhead_shark_name => 'Grand requin-marteau';

  @override
  String get species_great_hammerhead_shark_desc =>
      'La plus grande espèce de requin-marteau, à la tête large et plate et à la haute nageoire dorsale.';

  @override
  String get species_scalloped_hammerhead_shark_name =>
      'Requin-marteau halicorne';

  @override
  String get species_scalloped_hammerhead_shark_desc =>
      'Souvent observé en grands bancs autour des monts sous-marins et des stations de nettoyage.';

  @override
  String get species_smooth_hammerhead_shark_name => 'Requin-marteau lisse';

  @override
  String get species_smooth_hammerhead_shark_desc =>
      'Requin-marteau à la tête au bord lisse et arrondi, présent dans les mers tempérées.';

  @override
  String get species_whitetip_reef_shark_name => 'Requin corail';

  @override
  String get species_whitetip_reef_shark_desc =>
      'Requin de récif placide, souvent au repos dans les grottes et sous les surplombs pendant la journée.';

  @override
  String get species_blacktip_reef_shark_name => 'Requin pointes noires';

  @override
  String get species_blacktip_reef_shark_desc =>
      'Requin de récif commun en eau peu profonde, reconnaissable aux extrémités noires de ses nageoires.';

  @override
  String get species_grey_reef_shark_name => 'Requin gris de récif';

  @override
  String get species_grey_reef_shark_desc =>
      'Prédateur de récif actif, souvent rencontré en groupe le long des tombants et dans les passes.';

  @override
  String get species_caribbean_reef_shark_name =>
      'Requin de récif des Caraïbes';

  @override
  String get species_caribbean_reef_shark_desc =>
      'Le requin de récif le plus fréquemment rencontré dans les Caraïbes, robuste et curieux.';

  @override
  String get species_nurse_shark_name => 'Requin nourrice';

  @override
  String get species_nurse_shark_desc =>
      'Poisson de fond au déplacement lent, souvent au repos sous les surplombs coralliens.';

  @override
  String get species_tawny_nurse_shark_name => 'Requin nourrice fauve';

  @override
  String get species_tawny_nurse_shark_desc =>
      'Requin de fond indo-pacifique que l\'on trouve au repos dans les grottes du récif et sur les zones sableuses.';

  @override
  String get species_bull_shark_name => 'Requin bouledogue';

  @override
  String get species_bull_shark_desc =>
      'Requin trapu et puissant, présent dans les milieux côtiers et d\'eau douce du monde entier.';

  @override
  String get species_tiger_shark_name => 'Requin-tigre';

  @override
  String get species_tiger_shark_desc =>
      'Grand prédateur au motif rayé caractéristique, rencontré lors de plongées profondes sur récif.';

  @override
  String get species_oceanic_whitetip_shark_name => 'Requin longimane';

  @override
  String get species_oceanic_whitetip_shark_desc =>
      'Requin pélagique aux nageoires arrondies à pointes blanches, observé lors des plongées en pleine eau.';

  @override
  String get species_thresher_shark_name => 'Requin-renard';

  @override
  String get species_thresher_shark_desc =>
      'Reconnaissable à sa nageoire caudale extrêmement longue, parfois observé aux stations de nettoyage.';

  @override
  String get species_pelagic_thresher_shark_name => 'Requin-renard pélagique';

  @override
  String get species_pelagic_thresher_shark_desc =>
      'La plus petite espèce de requin-renard, célèbre sur le site de Monad Shoal aux Philippines.';

  @override
  String get species_shortfin_mako_shark_name => 'Requin-taupe bleu';

  @override
  String get species_shortfin_mako_shark_desc =>
      'Le requin le plus rapide de l\'océan, prédateur de pleine eau élancé à la robe bleu métallique.';

  @override
  String get species_blue_shark_name => 'Requin bleu';

  @override
  String get species_blue_shark_desc =>
      'Requin pélagique élancé d\'un bleu profond, souvent rencontré lors des plongées en pleine eau.';

  @override
  String get species_spotted_wobbegong_name => 'Requin-tapis tacheté';

  @override
  String get species_spotted_wobbegong_desc =>
      'Requin-tapis aplati et camouflé qui reste immobile sur les récifs rocheux d\'Australie.';

  @override
  String get species_tasselled_wobbegong_name => 'Requin-tapis barbu';

  @override
  String get species_tasselled_wobbegong_desc =>
      'Requin-tapis orné de lobes frangés autour de la tête, présent sur les récifs coralliens.';

  @override
  String get species_epaulette_shark_name => 'Requin-chabot à épaulettes';

  @override
  String get species_epaulette_shark_desc =>
      'Petit requin qui marche sur le fond du récif en s\'aidant de ses nageoires pectorales.';

  @override
  String get species_horn_shark_name => 'Requin dormeur cornu';

  @override
  String get species_horn_shark_desc =>
      'Poisson de fond nocturne portant des crêtes au-dessus des yeux, présent au large de la Californie.';

  @override
  String get species_leopard_shark_name => 'Requin-léopard';

  @override
  String get species_leopard_shark_desc =>
      'Requin au magnifique motif, présent dans les baies peu profondes de la côte pacifique des États-Unis.';

  @override
  String get species_pacific_angel_shark_name => 'Ange de mer du Pacifique';

  @override
  String get species_pacific_angel_shark_desc =>
      'Prédateur embusqué au corps aplati qui reste enfoui dans le sable du fond.';

  @override
  String get species_sand_tiger_shark_name => 'Requin taureau';

  @override
  String get species_sand_tiger_shark_desc =>
      'Requin à l\'allure féroce mais placide, souvent vu en suspension dans les grottes et les épaves.';

  @override
  String get species_zebra_shark_name => 'Requin-zèbre';

  @override
  String get species_zebra_shark_desc =>
      'Requin de récif tacheté qui se repose sur les fonds sableux, commun dans l\'Indo-Pacifique.';

  @override
  String get species_blacktip_shark_name => 'Requin bordé';

  @override
  String get species_blacktip_shark_desc =>
      'Requin côtier rapide connu pour ses sauts en vrille, présent dans les eaux chaudes du monde entier.';

  @override
  String get species_silvertip_shark_name => 'Requin pointe blanche';

  @override
  String get species_silvertip_shark_desc =>
      'Requin de récif audacieux aux nageoires bordées de blanc, présent près des tombants profonds et des atolls.';

  @override
  String get species_silky_shark_name => 'Requin soyeux';

  @override
  String get species_silky_shark_desc =>
      'Requin pélagique élancé à la peau lisse, souvent présent près des récifs du large.';

  @override
  String get species_lemon_shark_name => 'Requin citron';

  @override
  String get species_lemon_shark_desc =>
      'Requin brun jaunâtre couramment observé dans les mangroves peu profondes et sur les fonds sableux.';

  @override
  String get species_galapagos_shark_name => 'Requin des Galapagos';

  @override
  String get species_galapagos_shark_desc =>
      'Grand requin de récif présent autour des îles océaniques, curieux envers les plongeurs.';

  @override
  String get species_port_jackson_shark_name => 'Requin de Port Jackson';

  @override
  String get species_port_jackson_shark_desc =>
      'Poisson de fond nocturne aux marques en forme de harnais, endémique d\'Australie.';

  @override
  String get species_bamboo_shark_name => 'Requin bambou à bandes brunes';

  @override
  String get species_bamboo_shark_desc =>
      'Petit requin de fond placide, commun sur les récifs coralliens indo-pacifiques.';

  @override
  String get species_basking_shark_name => 'Requin pèlerin';

  @override
  String get species_basking_shark_desc =>
      'Deuxième plus grand poisson du monde, filtreur observé près de la surface dans les eaux tempérées.';

  @override
  String get species_greenland_shark_name => 'Requin du Groenland';

  @override
  String get species_greenland_shark_desc =>
      'Requin d\'eau profonde très lent, l\'un des vertébrés les plus longévifs de la planète.';

  @override
  String get species_cookiecutter_shark_name => 'Squalelet féroce';

  @override
  String get species_cookiecutter_shark_desc =>
      'Petit requin des profondeurs qui prélève des morsures circulaires sur de plus grands animaux marins.';

  @override
  String get species_sevengill_shark_name => 'Requin plat-nez';

  @override
  String get species_sevengill_shark_desc =>
      'Requin primitif à sept fentes branchiales, rencontré lors des plongées tempérées dans les forêts de laminaires.';

  @override
  String get species_pyjama_shark_name => 'Roussette pyjama';

  @override
  String get species_pyjama_shark_desc =>
      'Roussette rayée endémique d\'Afrique du Sud, présente sur les récifs rocheux et dans les forêts de kelp.';

  @override
  String get species_spiny_dogfish_name => 'Aiguillat commun';

  @override
  String get species_spiny_dogfish_desc =>
      'Petit requin abondant portant des épines dorsales venimeuses, présent dans les eaux tempérées.';

  @override
  String get species_swell_shark_name => 'Roussette gonflable';

  @override
  String get species_swell_shark_desc =>
      'Roussette nocturne qui gonfle son corps lorsqu\'elle est menacée, présente au large de la Californie.';

  @override
  String get species_giant_oceanic_manta_ray_name => 'Raie manta géante';

  @override
  String get species_giant_oceanic_manta_ray_desc =>
      'La plus grande espèce de raie, filtreur majestueux dont l\'envergure atteint 7 mètres.';

  @override
  String get species_reef_manta_ray_name => 'Raie manta de récif';

  @override
  String get species_reef_manta_ray_desc =>
      'Espèce de manta plus petite, couramment observée aux stations de nettoyage des récifs tropicaux.';

  @override
  String get species_spotted_eagle_ray_name => 'Raie léopard';

  @override
  String get species_spotted_eagle_ray_desc =>
      'Raie élégante aux taches blanches et à la longue queue en fouet, souvent vue en pleine eau.';

  @override
  String get species_common_eagle_ray_name => 'Aigle de mer commun';

  @override
  String get species_common_eagle_ray_desc =>
      'Raie en forme de losange présente dans l\'Atlantique Est tempéré et en Méditerranée.';

  @override
  String get species_blue_spotted_ribbontail_ray_name =>
      'Raie pastenague à queue rubanée';

  @override
  String get species_blue_spotted_ribbontail_ray_desc =>
      'Raie aux couleurs vives parsemée de points bleus éclatants, commune sur les récifs indo-pacifiques.';

  @override
  String get species_blue_spotted_stingray_name => 'Pastenague à points bleus';

  @override
  String get species_blue_spotted_stingray_desc =>
      'Petite pastenague de récif aux points bleus épars, souvent enfouie dans les zones sableuses.';

  @override
  String get species_southern_stingray_name => 'Pastenague américaine';

  @override
  String get species_southern_stingray_desc =>
      'Grande pastenague des fonds sableux des Caraïbes, célèbre sur le site de Stingray City.';

  @override
  String get species_round_stingray_name => 'Raie ronde';

  @override
  String get species_round_stingray_desc =>
      'Petite pastenague circulaire commune sur les fonds sableux peu profonds du Pacifique Est.';

  @override
  String get species_short_tail_stingray_name => 'Pastenague à queue courte';

  @override
  String get species_short_tail_stingray_desc =>
      'L\'une des plus grandes pastenagues, présente dans les eaux tempérées de l\'hémisphère sud.';

  @override
  String get species_cowtail_stingray_name => 'Pastenague à queue de vache';

  @override
  String get species_cowtail_stingray_desc =>
      'Grande pastenague sombre au repli caudal caractéristique en forme de drapeau, présente sur les récifs sableux.';

  @override
  String get species_atlantic_torpedo_ray_name => 'Torpille noire';

  @override
  String get species_atlantic_torpedo_ray_desc =>
      'Raie électrique capable de produire de fortes décharges, présente sur les fonds sableux de l\'Atlantique.';

  @override
  String get species_marbled_electric_ray_name => 'Torpille marbrée';

  @override
  String get species_marbled_electric_ray_desc =>
      'Raie électrique méditerranéenne au motif marbré, capable d\'une décharge électrique notable.';

  @override
  String get species_giant_guitarfish_name => 'Poisson-guitare géant';

  @override
  String get species_giant_guitarfish_desc =>
      'Raie en forme de requin présente sur les fonds sableux indo-pacifiques, près des récifs coralliens.';

  @override
  String get species_shovelnose_guitarfish_name =>
      'Poisson-guitare à nez de pelle';

  @override
  String get species_shovelnose_guitarfish_desc =>
      'Silhouette aplatie intermédiaire entre la raie et le requin, commune sur les fonds sableux du Pacifique Est.';

  @override
  String get species_smalltooth_sawfish_name => 'Poisson-scie à petites dents';

  @override
  String get species_smalltooth_sawfish_desc =>
      'Raie en danger critique dotée d\'un rostre denté, présente dans les eaux côtières tropicales.';

  @override
  String get species_green_sawfish_name => 'Poisson-scie vert';

  @override
  String get species_green_sawfish_desc =>
      'Grand poisson-scie au corps vert olive, qui fréquente les estuaires de l\'Indo-Pacifique Ouest.';

  @override
  String get species_devil_ray_name => 'Diable de mer géant';

  @override
  String get species_devil_ray_desc =>
      'Grande raie mobula pourvue de cornes céphaliques, que l\'on voit bondir hors de l\'eau en groupe.';

  @override
  String get species_spinetail_devil_ray_name =>
      'Diable de mer à queue épineuse';

  @override
  String get species_spinetail_devil_ray_desc =>
      'Raie mobula pélagique souvent observée en grands rassemblements près de la surface.';

  @override
  String get species_lesser_devil_ray_name => 'Petit diable de mer';

  @override
  String get species_lesser_devil_ray_desc =>
      'La plus petite espèce de mobula, qui forme de grands bancs dans le golfe de Californie.';

  @override
  String get species_bat_ray_name => 'Raie chauve-souris';

  @override
  String get species_bat_ray_desc =>
      'Raie en forme de losange commune dans les forêts de laminaires et les baies sableuses de Californie.';

  @override
  String get species_undulate_ray_name => 'Raie brunette';

  @override
  String get species_undulate_ray_desc =>
      'Raie magnifiquement ornée de lignes ondulées, présente dans l\'Atlantique Est.';

  @override
  String get species_thornback_ray_name => 'Raie bouclée';

  @override
  String get species_thornback_ray_desc =>
      'Raie européenne commune portant des épines sur le dos et la queue.';

  @override
  String get species_cownose_ray_name => 'Raie à nez de vache';

  @override
  String get species_cownose_ray_desc =>
      'Tête à l\'échancrure caractéristique, souvent observée en grands bancs lors des migrations saisonnières.';

  @override
  String get species_marble_ray_name => 'Pastenague marbrée';

  @override
  String get species_marble_ray_desc =>
      'Grande pastenague sombre tachetée de blanc, fréquemment observée aux stations de nettoyage indo-pacifiques.';

  @override
  String get species_ocellate_river_stingray_name => 'Raie de rivière ocellée';

  @override
  String get species_ocellate_river_stingray_desc =>
      'Raie d\'eau douce aux taches cerclées d\'orange saisissantes, originaire des fleuves d\'Amérique du Sud.';

  @override
  String get species_ocellaris_clownfish_name => 'Poisson-clown à trois bandes';

  @override
  String get species_ocellaris_clownfish_desc =>
      'Petit poisson rayé orange et blanc qui vit couramment en symbiose avec les anémones de mer sur les récifs coralliens.';

  @override
  String get species_clarkii_clownfish_name => 'Poisson-clown de Clark';

  @override
  String get species_clarkii_clownfish_desc =>
      'Poisson-clown robuste au corps sombre barré de deux bandes blanches, présent dans tout l\'Indo-Pacifique sur diverses anémones.';

  @override
  String get species_tomato_clownfish_name => 'Poisson-clown tomate';

  @override
  String get species_tomato_clownfish_desc =>
      'Poisson-clown rouge orangé vif portant une seule bande blanche sur la tête, commun sur les récifs indo-pacifiques.';

  @override
  String get species_regal_blue_tang_name => 'Poisson-chirurgien bleu';

  @override
  String get species_regal_blue_tang_desc =>
      'Chirurgien d\'un bleu vif marqué d\'une palette noire et à la queue jaune, présent sur les récifs coralliens indo-pacifiques.';

  @override
  String get species_yellow_tang_name => 'Poisson-chirurgien jaune';

  @override
  String get species_yellow_tang_desc =>
      'Chirurgien jaune vif commun sur les récifs d\'Hawaï et du Pacifique, souvent vu brouter les algues en groupe.';

  @override
  String get species_powder_blue_surgeonfish_name =>
      'Chirurgien à poitrine blanche';

  @override
  String get species_powder_blue_surgeonfish_desc =>
      'Chirurgien d\'un bleu pâle saisissant, à la face noire et à la dorsale jaune, présent dans l\'océan Indien.';

  @override
  String get species_sohal_surgeonfish_name => 'Chirurgien sohal';

  @override
  String get species_sohal_surgeonfish_desc =>
      'Chirurgien rayé au scalpel orange, endémique des récifs de la mer Rouge et du golfe Persique.';

  @override
  String get species_blue_tang_name => 'Chirurgien bleu des Caraïbes';

  @override
  String get species_blue_tang_desc =>
      'Chirurgien d\'un bleu profond commun sur les récifs des Caraïbes; les juvéniles sont jaune vif.';

  @override
  String get species_emperor_angelfish_name => 'Poisson-ange empereur';

  @override
  String get species_emperor_angelfish_desc =>
      'Grand poisson-ange aux bandes horizontales bleues et jaunes saisissantes. Les juvéniles arborent des cercles concentriques bleus et blancs.';

  @override
  String get species_french_angelfish_name => 'Poisson-ange français';

  @override
  String get species_french_angelfish_desc =>
      'Grand poisson-ange sombre aux écailles bordées d\'or, souvent observé en couple sur les récifs des Caraïbes et de l\'Atlantique Ouest.';

  @override
  String get species_queen_angelfish_name => 'Poisson-ange royal';

  @override
  String get species_queen_angelfish_desc =>
      'Spectaculaire poisson-ange bleu et jaune portant une tache en forme de couronne, présent sur les récifs coralliens des Caraïbes.';

  @override
  String get species_regal_angelfish_name => 'Poisson-ange duc';

  @override
  String get species_regal_angelfish_desc =>
      'Élégant poisson-ange aux bandes verticales alternées orange, blanches et bleues, présent sur les récifs indo-pacifiques.';

  @override
  String get species_rock_beauty_name => 'Poisson-ange demi-deuil';

  @override
  String get species_rock_beauty_desc =>
      'Poisson-ange des Caraïbes saisissant, jaune sur la moitié avant et noir sur la moitié arrière, présent près des récifs rocheux et des surplombs.';

  @override
  String get species_gray_angelfish_name => 'Poisson-ange gris';

  @override
  String get species_gray_angelfish_desc =>
      'Grand poisson-ange gris à la face pâle et à l\'intérieur des pectorales jaune, commun sur les récifs des Caraïbes.';

  @override
  String get species_copperband_butterflyfish_name =>
      'Poisson-papillon à bandes cuivrées';

  @override
  String get species_copperband_butterflyfish_desc =>
      'Poisson-papillon caractéristique aux bandes verticales orange et au museau allongé, présent sur les récifs indo-pacifiques.';

  @override
  String get species_raccoon_butterflyfish_name =>
      'Poisson-papillon raton laveur';

  @override
  String get species_raccoon_butterflyfish_desc =>
      'Poisson-papillon jaune portant un masque oculaire sombre, commun sur les récifs indo-pacifiques et hawaïens.';

  @override
  String get species_longnose_butterflyfish_name =>
      'Poisson-papillon à long bec';

  @override
  String get species_longnose_butterflyfish_desc =>
      'Poisson-papillon jaune vif au museau très allongé qui lui sert à extraire sa nourriture des anfractuosités des récifs indo-pacifiques.';

  @override
  String get species_threadfin_butterflyfish_name => 'Chétodon à filament';

  @override
  String get species_threadfin_butterflyfish_desc =>
      'Poisson-papillon blanc au motif en chevrons prolongé par un filament dorsal, largement répandu dans l\'Indo-Pacifique.';

  @override
  String get species_foureye_butterflyfish_name =>
      'Poisson-papillon à quatre yeux';

  @override
  String get species_foureye_butterflyfish_desc =>
      'Poisson-papillon pâle portant un net faux oeil près de la queue, commun sur les récifs des Caraïbes.';

  @override
  String get species_spotfin_butterflyfish_name =>
      'Poisson-papillon à tache dorsale';

  @override
  String get species_spotfin_butterflyfish_desc =>
      'Poisson-papillon blanc et jaune marqué d\'un petit point sombre sur la nageoire dorsale, présent dans l\'Atlantique Ouest.';

  @override
  String get species_banner_butterflyfish_name =>
      'Poisson-cocher de la mer Rouge';

  @override
  String get species_banner_butterflyfish_desc =>
      'Poisson-cocher noir et blanc à la nageoire dorsale allongée et au ventre jaune, endémique de la mer Rouge.';

  @override
  String get species_moorish_idol_name => 'Idole des Maures';

  @override
  String get species_moorish_idol_desc =>
      'Poisson de récif emblématique aux larges bandes noires, blanches et jaunes et au long filament dorsal.';

  @override
  String get species_green_moray_eel_name => 'Murène verte';

  @override
  String get species_green_moray_eel_desc =>
      'Grande murène verte atteignant 2,5 m, souvent vue gueule ouverte dans les anfractuosités des récifs de l\'Atlantique Ouest.';

  @override
  String get species_giant_moray_eel_name => 'Murène géante';

  @override
  String get species_giant_moray_eel_desc =>
      'La plus grande espèce de murène, dépassant 3 m, au motif léopard. Présente sur les récifs coralliens indo-pacifiques.';

  @override
  String get species_spotted_moray_eel_name => 'Murène tachetée';

  @override
  String get species_spotted_moray_eel_desc =>
      'Murène blanche parsemée de taches brun foncé, couramment observée à l\'entrée des trous du récif dans les Caraïbes.';

  @override
  String get species_ribbon_eel_name => 'Murène ruban';

  @override
  String get species_ribbon_eel_desc =>
      'Murène élancée aux narines évasées; les mâles sont d\'un bleu vif, les femelles jaunes. Présente dans les lagons sableux indo-pacifiques.';

  @override
  String get species_spotted_garden_eel_name => 'Anguille-jardinière tachetée';

  @override
  String get species_spotted_garden_eel_desc =>
      'Fine anguille blanche à points noirs qui vit en colonies dans le sable et ondule dans le courant pour capturer le plancton.';

  @override
  String get species_splendid_garden_eel_name =>
      'Anguille-jardinière splendide';

  @override
  String get species_splendid_garden_eel_desc =>
      'Anguille-jardinière annelée d\'orange et de blanc, formant de vastes colonies sableuses dans le Pacifique Ouest.';

  @override
  String get species_snowflake_moray_name => 'Murène flocon de neige';

  @override
  String get species_snowflake_moray_desc =>
      'Petite murène au corps blanc marqué de motifs noirs en flocons, commune dans les débris coralliens indo-pacifiques.';

  @override
  String get species_mandarin_dragonet_name => 'Poisson-mandarin';

  @override
  String get species_mandarin_dragonet_desc =>
      'Minuscule poisson aux couleurs éclatantes, orné de motifs psychédéliques bleus et orange, présent dans les zones de débris du Pacifique Ouest.';

  @override
  String get species_common_lionfish_name => 'Rascasse volante';

  @override
  String get species_common_lionfish_desc =>
      'Scorpénidé venimeux aux spectaculaires pectorales en éventail et aux rayures rouges et blanches. Invasive dans les Caraïbes.';

  @override
  String get species_leaf_scorpionfish_name => 'Rascasse-feuille';

  @override
  String get species_leaf_scorpionfish_desc =>
      'Rascasse très comprimée en forme de feuille qui ondule dans le courant pour imiter un débris sur les récifs indo-pacifiques.';

  @override
  String get species_stonefish_name => 'Poisson-pierre';

  @override
  String get species_stonefish_desc =>
      'Le poisson le plus venimeux du monde, parfaitement camouflé en rocher sur les fonds récifaux indo-pacifiques. Extrêmement dangereux.';

  @override
  String get species_painted_frogfish_name => 'Antennaire peint';

  @override
  String get species_painted_frogfish_desc =>
      'Prédateur embusqué trapu portant un leurre sur la tête, de coloration très variable. Présent sur les récifs indo-pacifiques.';

  @override
  String get species_giant_frogfish_name => 'Antennaire géant';

  @override
  String get species_giant_frogfish_desc =>
      'La plus grande espèce d\'antennaire, atteignant 40 cm, au camouflage parfait dans les éponges et les débris coralliens.';

  @override
  String get species_hairy_frogfish_name => 'Antennaire poilu';

  @override
  String get species_hairy_frogfish_desc =>
      'Antennaire couvert d\'appendices charnus en forme de vers qui imitent les algues, une trouvaille prisée des photographes sous-marins.';

  @override
  String get species_clown_triggerfish_name => 'Baliste clown';

  @override
  String get species_clown_triggerfish_desc =>
      'Baliste au motif marqué, au corps sombre orné de grandes taches blanches et aux lèvres jaunes, présent sur les récifs indo-pacifiques.';

  @override
  String get species_titan_triggerfish_name => 'Baliste titan';

  @override
  String get species_titan_triggerfish_desc =>
      'Grand baliste agressif connu pour charger les plongeurs près de son nid. Commun sur les récifs coralliens indo-pacifiques.';

  @override
  String get species_queen_triggerfish_name => 'Baliste royal';

  @override
  String get species_queen_triggerfish_desc =>
      'Baliste coloré des Caraïbes aux marques faciales bleues et aux longs filaments caudaux.';

  @override
  String get species_picasso_triggerfish_name => 'Baliste picasso';

  @override
  String get species_picasso_triggerfish_desc =>
      'Baliste au motif abstrait de rayures bleues, jaunes et noires, commun sur les platiers récifaux indo-pacifiques.';

  @override
  String get species_yellowmargin_triggerfish_name => 'Baliste à bordure jaune';

  @override
  String get species_yellowmargin_triggerfish_desc =>
      'Grand baliste beige aux nageoires bordées de jaune, connu pour défendre agressivement son nid sur les récifs indo-pacifiques.';

  @override
  String get species_porcupinefish_name => 'Poisson-porc-épic';

  @override
  String get species_porcupinefish_desc =>
      'Grand poisson épineux qui se gonfle en boule lorsqu\'il est menacé, présent sur les récifs tropicaux du monde entier.';

  @override
  String get species_guineafowl_pufferfish_name => 'Poisson-ballon pintade';

  @override
  String get species_guineafowl_pufferfish_desc =>
      'Poisson-ballon sombre couvert de petits points blancs, parfois observé dans une phase jaune doré sur les récifs indo-pacifiques.';

  @override
  String get species_map_pufferfish_name => 'Poisson-ballon carte géographique';

  @override
  String get species_map_pufferfish_desc =>
      'Grand poisson-ballon clair parcouru de marques sombres évoquant une carte, présent sur les récifs indo-pacifiques.';

  @override
  String get species_sharpnose_pufferfish_name => 'Poisson-ballon à nez pointu';

  @override
  String get species_sharpnose_pufferfish_desc =>
      'Minuscule poisson-ballon aux lignes bleues sur la face et à la queue orange, couramment observé sur les récifs des Caraïbes.';

  @override
  String get species_boxfish_name => 'Poisson-coffre jaune';

  @override
  String get species_boxfish_desc =>
      'Les juvéniles sont de petits cubes jaune vif à points noirs. Les adultes virent au gris-bleu. Présent dans tout l\'Indo-Pacifique.';

  @override
  String get species_cowfish_name => 'Poisson-vache à longues cornes';

  @override
  String get species_cowfish_desc =>
      'Poisson cubique jaune portant une corne caractéristique au-dessus de chaque oeil, présent sur les récifs indo-pacifiques.';

  @override
  String get species_napoleon_wrasse_name => 'Napoléon';

  @override
  String get species_napoleon_wrasse_desc =>
      'Labre massif atteignant 2 m, à la bosse frontale proéminente. Espèce menacée et protégée, présente sur les récifs indo-pacifiques.';

  @override
  String get species_cleaner_wrasse_name => 'Labre nettoyeur';

  @override
  String get species_cleaner_wrasse_desc =>
      'Petit labre rayé de bleu qui tient des stations de nettoyage et débarrasse les grands poissons de leurs parasites sur les récifs indo-pacifiques.';

  @override
  String get species_yellowtail_coris_name => 'Girelle à queue jaune';

  @override
  String get species_yellowtail_coris_desc =>
      'Labre coloré au corps tacheté et à la queue jaune; les juvéniles sont rouge orangé vif avec des marques blanches.';

  @override
  String get species_bluehead_wrasse_name => 'Labre à tête bleue';

  @override
  String get species_bluehead_wrasse_desc =>
      'Labre abondant des Caraïbes; les mâles terminaux ont la tête d\'un bleu vif et le corps vert barré de noir et de blanc.';

  @override
  String get species_spanish_hogfish_name => 'Labre espagnol';

  @override
  String get species_spanish_hogfish_desc =>
      'Labre violet et jaune commun sur les récifs des Caraïbes; les juvéniles font office de poissons nettoyeurs.';

  @override
  String get species_bumphead_parrotfish_name => 'Poisson-perroquet à bosse';

  @override
  String get species_bumphead_parrotfish_desc =>
      'La plus grande espèce de poisson-perroquet, atteignant 1,3 m, avec une énorme bosse frontale. Se déplace en bancs sur les récifs indo-pacifiques.';

  @override
  String get species_stoplight_parrotfish_name => 'Poisson-perroquet feu';

  @override
  String get species_stoplight_parrotfish_desc =>
      'Poisson-perroquet commun des Caraïbes, aux changements de couleur spectaculaires entre la phase initiale et la phase terminale.';

  @override
  String get species_queen_parrotfish_name => 'Poisson-perroquet royal';

  @override
  String get species_queen_parrotfish_desc =>
      'Grand poisson-perroquet bleu-vert des récifs des Caraïbes, souvent vu mordre le corail pour se nourrir d\'algues.';

  @override
  String get species_yellowtail_damselfish_name => 'Demoiselle à queue jaune';

  @override
  String get species_yellowtail_damselfish_desc =>
      'Demoiselle bleu foncé à la queue jaune vif, commune sur les sommets et les crêtes des récifs des Caraïbes.';

  @override
  String get species_sergeant_major_name => 'Sergent-major';

  @override
  String get species_sergeant_major_desc =>
      'Demoiselle argentée et jaune barrée de cinq bandes noires marquées, présente en grands rassemblements sur les récifs de l\'Atlantique tropical.';

  @override
  String get species_three_spot_damselfish_name => 'Demoiselle à trois taches';

  @override
  String get species_three_spot_damselfish_desc =>
      'Demoiselle territoriale brun foncé qui défend agressivement son jardin d\'algues sur les récifs des Caraïbes.';

  @override
  String get species_chromis_viridis_name => 'Chromis vert';

  @override
  String get species_chromis_viridis_desc =>
      'Petite demoiselle d\'un vert irisé, observée en bancs denses au-dessus des coraux branchus des récifs indo-pacifiques.';

  @override
  String get species_blue_chromis_name => 'Chromis bleu';

  @override
  String get species_blue_chromis_desc =>
      'Demoiselle planctonophage d\'un bleu éclatant, formant de grands rassemblements en pleine eau au-dessus des tombants des Caraïbes.';

  @override
  String get species_nassau_grouper_name => 'Mérou de Nassau';

  @override
  String get species_nassau_grouper_desc =>
      'Grand mérou des Caraïbes reconnaissable à sa bande oculaire sombre et à son motif barré, aujourd\'hui menacé par la surpêche.';

  @override
  String get species_giant_grouper_name => 'Mérou géant';

  @override
  String get species_giant_grouper_desc =>
      'Le plus grand poisson osseux de récif, atteignant 2,7 m et 400 kg. Présent dans les grottes et les épaves de tout l\'Indo-Pacifique.';

  @override
  String get species_coral_grouper_name => 'Mérou corail';

  @override
  String get species_coral_grouper_desc =>
      'Mérou rouge orangé vif couvert de points bleus, espèce emblématique des récifs coralliens indo-pacifiques.';

  @override
  String get species_goliath_grouper_name => 'Mérou goliath';

  @override
  String get species_goliath_grouper_desc =>
      'Mérou atlantique massif atteignant 2,5 m, souvent rencontré près des épaves et des surplombs en Floride et dans les Caraïbes.';

  @override
  String get species_potato_grouper_name => 'Mérou patate';

  @override
  String get species_potato_grouper_desc =>
      'Grand mérou sociable orné de taches sombres en forme de patate, célèbre au Cod Hole de la Grande Barrière de corail.';

  @override
  String get species_peacock_grouper_name => 'Mérou paon';

  @override
  String get species_peacock_grouper_desc =>
      'Mérou brun foncé constellé de points bleus vifs et barré de bandes claires à l\'arrière, commun sur les récifs indo-pacifiques.';

  @override
  String get species_yellowfin_tuna_name => 'Thon à nageoires jaunes';

  @override
  String get species_yellowfin_tuna_desc =>
      'Prédateur pélagique rapide aux longues nageoires dorsale et anale jaunes, parfois observé par les plongeurs sur les sites du large.';

  @override
  String get species_dogtooth_tuna_name => 'Thon à dents de chien';

  @override
  String get species_dogtooth_tuna_desc =>
      'Thon puissant inféodé aux récifs, aux dents proéminentes, rencontré sur les tombants profonds de l\'Indo-Pacifique.';

  @override
  String get species_great_barracuda_name => 'Grand barracuda';

  @override
  String get species_great_barracuda_desc =>
      'Prédateur argenté élancé atteignant 1,8 m, aux dents proéminentes, souvent vu immobile près des récifs tropicaux.';

  @override
  String get species_blackfin_barracuda_name => 'Barracuda à nageoires noires';

  @override
  String get species_blackfin_barracuda_desc =>
      'Barracuda indo-pacifique connu pour former d\'immenses bancs en tornade sur des sites comme Barracuda Point.';

  @override
  String get species_mahi_mahi_name => 'Coryphène';

  @override
  String get species_mahi_mahi_desc =>
      'Poisson pélagique éblouissant, bleu-vert et or, au front busqué, parfois observé sur les sites de plongée du large.';

  @override
  String get species_giant_trevally_name => 'Carangue géante';

  @override
  String get species_giant_trevally_desc =>
      'Prédateur argenté puissant atteignant 1,7 m, connu pour chasser dans les passes et sur les tombants de tout l\'Indo-Pacifique.';

  @override
  String get species_bluefin_trevally_name => 'Carangue bleue';

  @override
  String get species_bluefin_trevally_desc =>
      'Carangue élancée mouchetée de bleu, souvent vue patrouiller en petits groupes de chasse le long des bordures récifales indo-pacifiques.';

  @override
  String get species_bigeye_trevally_name => 'Carangue à gros yeux';

  @override
  String get species_bigeye_trevally_desc =>
      'Carangue argentée aux grands yeux qui forme d\'impressionnants bancs tourbillonnants près des tombants et des stations de nettoyage.';

  @override
  String get species_bar_jack_name => 'Carangue à barre';

  @override
  String get species_bar_jack_desc =>
      'Carangue argentée élancée des Caraïbes, marquée d\'une bande bleu foncé le long du dos qui se prolonge sur le bas de la queue.';

  @override
  String get species_horse_eye_jack_name => 'Carangue mayole';

  @override
  String get species_horse_eye_jack_desc =>
      'Carangue argentée aux grands yeux qui forme des bancs près des récifs et des épaves dans les Caraïbes et l\'Atlantique Ouest.';

  @override
  String get species_yellowtail_snapper_name => 'Vivaneau queue jaune';

  @override
  String get species_yellowtail_snapper_desc =>
      'Vivaneau élancé à la bande latérale et à la queue jaunes, souvent observé en bancs en pleine eau sur les récifs des Caraïbes.';

  @override
  String get species_schoolmaster_snapper_name => 'Vivaneau dents de chien';

  @override
  String get species_schoolmaster_snapper_desc =>
      'Vivaneau jaune et argent portant des lignes bleues sous l\'oeil, observé en groupes sous les surplombs des récifs des Caraïbes.';

  @override
  String get species_bluestripe_snapper_name => 'Vivaneau à raies bleues';

  @override
  String get species_bluestripe_snapper_desc =>
      'Vivaneau jaune vif orné de quatre raies horizontales bleues, formant des bancs denses sur les récifs indo-pacifiques.';

  @override
  String get species_twinspot_snapper_name => 'Vivaneau à deux taches';

  @override
  String get species_twinspot_snapper_desc =>
      'Grand vivaneau rouge des récifs externes indo-pacifiques, formant parfois des bancs sur les tombants profonds et dans les passes.';

  @override
  String get species_humphead_snapper_name => 'Vivaneau de minuit';

  @override
  String get species_humphead_snapper_desc =>
      'Grand vivaneau sombre observé en bancs près des tombants abrupts indo-pacifiques; les juvéniles sont nettement noir et blanc.';

  @override
  String get species_longfin_bannerfish_name =>
      'Poisson-cocher à longue nageoire';

  @override
  String get species_longfin_bannerfish_desc =>
      'Poisson noir et blanc à la longue nageoire dorsale filamenteuse et à la queue jaune, souvent vu en couple sur les récifs indo-pacifiques.';

  @override
  String get species_batfish_orbicular_name =>
      'Poisson chauve-souris orbiculaire';

  @override
  String get species_batfish_orbicular_desc =>
      'Poisson argenté en forme de disque, aux nageoires hautes, qui s\'approche des plongeurs par curiosité. Commun sur les épaves et les récifs indo-pacifiques.';

  @override
  String get species_batfish_teira_name =>
      'Poisson chauve-souris à longues nageoires';

  @override
  String get species_batfish_teira_desc =>
      'Poisson chauve-souris aux nageoires hautes portant une tache sombre près de la pectorale, souvent vu aux stations de nettoyage et sur les épaves.';

  @override
  String get species_batfish_pinnatus_name => 'Poisson chauve-souris pinnatus';

  @override
  String get species_batfish_pinnatus_desc =>
      'Les juvéniles sont noir de jais bordés d\'orange vif et ressemblent à un ver plat toxique. Présent dans le Pacifique Ouest.';

  @override
  String get species_banggai_cardinalfish_name => 'Apogon des Banggai';

  @override
  String get species_banggai_cardinalfish_desc =>
      'Apogon saisissant, argenté et noir, aux nageoires allongées, endémique des îles Banggai en Indonésie.';

  @override
  String get species_pajama_cardinalfish_name => 'Apogon pyjama';

  @override
  String get species_pajama_cardinalfish_desc =>
      'Apogon original à la face jaune, à la bande sombre médiane et à l\'arrière tacheté, présent parmi les coraux de l\'Indo-Pacifique.';

  @override
  String get species_longnose_hawkfish_name => 'Poisson-faucon à long nez';

  @override
  String get species_longnose_hawkfish_desc =>
      'Petit poisson blanc au quadrillage rouge et au museau allongé, perché sur les gorgones et les coraux noirs.';

  @override
  String get species_arc_eye_hawkfish_name => 'Poisson-faucon à arc oculaire';

  @override
  String get species_arc_eye_hawkfish_desc =>
      'Petit poisson-faucon reconnaissable à l\'arc orange derrière l\'oeil, souvent perché sur les massifs coralliens des récifs indo-pacifiques.';

  @override
  String get species_flame_hawkfish_name => 'Poisson-faucon flamme';

  @override
  String get species_flame_hawkfish_desc =>
      'Poisson-faucon rouge éclatant aux marques sombres autour de l\'oeil, perché dans les coraux Pocillopora du Pacifique Ouest.';

  @override
  String get species_fire_goby_name => 'Gobie de feu';

  @override
  String get species_fire_goby_desc =>
      'Élégant gobie blanc à la haute première nageoire dorsale et à la queue rouge orangé, en suspension au-dessus des débris coralliens indo-pacifiques.';

  @override
  String get species_purple_firefish_name => 'Gobie de feu pourpre';

  @override
  String get species_purple_firefish_desc =>
      'Gobie délicat aux nageoires violettes et à la longue épine dorsale, en suspension près de son terrier sur les récifs externes indo-pacifiques.';

  @override
  String get species_yellownose_goby_name => 'Gobie à nez jaune';

  @override
  String get species_yellownose_goby_desc =>
      'Minuscule gobie nettoyeur des Caraïbes au museau jaune et à la bande latérale bleue, présent sur les éponges et les massifs coralliens.';

  @override
  String get species_citron_goby_name => 'Gobie citron';

  @override
  String get species_citron_goby_desc =>
      'Minuscule gobie jaune vif qui vit parmi les branches des coraux Acropora sur les récifs indo-pacifiques.';

  @override
  String get species_shrimp_goby_name => 'Gobie crevette de Steinitz';

  @override
  String get species_shrimp_goby_desc =>
      'Gobie couleur sable qui partage un terrier avec une crevette alphéidé dans une relation mutualiste sur les fonds sableux indo-pacifiques.';

  @override
  String get species_neon_goby_name => 'Gobie néon';

  @override
  String get species_neon_goby_desc =>
      'Minuscule gobie sombre orné d\'une éclatante bande bleu néon, qui tient des stations de nettoyage sur les massifs coralliens des Caraïbes.';

  @override
  String get species_bluestriped_fangblenny_name => 'Blennie à raie bleue';

  @override
  String get species_bluestriped_fangblenny_desc =>
      'Petite blennie rayée de bleu qui imite les labres nettoyeurs pour arracher les écailles des poissons imprudents.';

  @override
  String get species_sailfin_blenny_name => 'Blennie voilière';

  @override
  String get species_sailfin_blenny_desc =>
      'Minuscule blennie des Caraïbes qui déploie une grande nageoire dorsale en forme de voile depuis son tube pour attirer les femelles.';

  @override
  String get species_bicolor_blenny_name => 'Blennie bicolore';

  @override
  String get species_bicolor_blenny_desc =>
      'Petite blennie à l\'avant brun foncé et à l\'arrière orange, qui pointe la tête hors des trous des récifs indo-pacifiques.';

  @override
  String get species_redlip_blenny_name => 'Blennie à lèvres rouges';

  @override
  String get species_redlip_blenny_desc =>
      'Blennie sombre aux lèvres rouge orangé marquées, qui défend ses plaques d\'algues sur les crêtes récifales des Caraïbes.';

  @override
  String get species_pygmy_seahorse_name => 'Hippocampe pygmée de Bargibant';

  @override
  String get species_pygmy_seahorse_desc =>
      'Minuscule hippocampe de moins de 2 cm qui se confond parfaitement avec sa gorgone hôte, sujet macro très prisé.';

  @override
  String get species_common_seahorse_name => 'Hippocampe commun';

  @override
  String get species_common_seahorse_desc =>
      'Hippocampe de taille moyenne présent dans les herbiers et les débris coralliens de tout l\'Indo-Pacifique, de couleur variable.';

  @override
  String get species_thorny_seahorse_name => 'Hippocampe épineux';

  @override
  String get species_thorny_seahorse_desc =>
      'Hippocampe couvert de longues épines, présent dans les herbiers et sur les fonds meubles de tout l\'Indo-Pacifique.';

  @override
  String get species_ornate_ghost_pipefish_name => 'Poisson-fantôme orné';

  @override
  String get species_ornate_ghost_pipefish_desc =>
      'Syngnathe fantôme au camouflage élaboré, en suspension tête en bas près des crinoïdes et des coraux mous de l\'Indo-Pacifique.';

  @override
  String get species_robust_ghost_pipefish_name => 'Poisson-fantôme robuste';

  @override
  String get species_robust_ghost_pipefish_desc =>
      'Grand poisson-fantôme qui imite un brin d\'herbier ou une algue, souvent trouvé en couple dans les eaux côtières indo-pacifiques.';

  @override
  String get species_trumpetfish_name => 'Poisson-trompette';

  @override
  String get species_trumpetfish_desc =>
      'Poisson long et élancé qui chasse en se dissimulant derrière de plus gros poissons, présent sur les récifs des Caraïbes et de l\'Atlantique dans des coloris variés.';

  @override
  String get species_cornetfish_name => 'Poisson-flûte';

  @override
  String get species_cornetfish_desc =>
      'Poisson extrêmement allongé atteignant 1,5 m, prolongé par un filament caudal, souvent vu glisser au-dessus des platiers.';

  @override
  String get species_yellowhead_jawfish_name => 'Poisson-bâilleur à tête jaune';

  @override
  String get species_yellowhead_jawfish_desc =>
      'Petit poisson au corps bleu et à la tête jaune, en suspension au-dessus de son terrier sableux sur les récifs des Caraïbes. Les mâles incubent les oeufs dans leur bouche.';

  @override
  String get species_flamefish_name => 'Apogon flamme';

  @override
  String get species_flamefish_desc =>
      'Petit apogon rouge vif portant une tache sombre sous la seconde nageoire dorsale, caché le jour dans les anfractuosités des récifs des Caraïbes.';

  @override
  String get species_longspine_squirrelfish_name =>
      'Poisson-écureuil à longue épine';

  @override
  String get species_longspine_squirrelfish_desc =>
      'Poisson rouge nocturne aux grands yeux et à la longue épine dorsale, réfugié le jour sous les surplombs des récifs des Caraïbes.';

  @override
  String get species_soldierfish_name => 'Poisson-soldat à grandes écailles';

  @override
  String get species_soldierfish_desc =>
      'Poisson rouge nocturne aux énormes yeux sombres et aux grandes écailles, qui forme des groupes dans les grottes et sous les surplombs pendant la journée.';

  @override
  String get species_flame_angelfish_name => 'Poisson-ange flamme';

  @override
  String get species_flame_angelfish_desc =>
      'Poisson-ange nain rouge orangé éclatant, barré de noir et aux nageoires bordées de bleu, présent dans tout le Pacifique.';

  @override
  String get species_royal_gramma_name => 'Gramma royal';

  @override
  String get species_royal_gramma_desc =>
      'Petit poisson bicolore des Caraïbes, violet sur la moitié avant et jaune sur la moitié arrière, présent sous les surplombs.';

  @override
  String get species_anthias_lyretail_name => 'Anthias à queue de lyre';

  @override
  String get species_anthias_lyretail_desc =>
      'Poisson de récif abondant qui forme de grands nuages orange et roses au-dessus des formations coralliennes indo-pacifiques. Les mâles sont violets.';

  @override
  String get species_mediterranean_grouper_name => 'Mérou brun';

  @override
  String get species_mediterranean_grouper_desc =>
      'Grand mérou brun foncé marbré de clair, prédateur emblématique des récifs rocheux de Méditerranée.';

  @override
  String get species_mediterranean_moray_name => 'Murène de Méditerranée';

  @override
  String get species_mediterranean_moray_desc =>
      'Murène brun foncé marbrée de jaune, couramment observée à l\'affût dans les anfractuosités rocheuses de Méditerranée.';

  @override
  String get species_ornate_wrasse_name => 'Girelle paon';

  @override
  String get species_ornate_wrasse_desc =>
      'Labre vert coloré aux marques rouges sur la tête, l\'un des labres les plus communs des récifs de Méditerranée.';

  @override
  String get species_red_sea_bannerfish_name => 'Poisson-papillon masqué';

  @override
  String get species_red_sea_bannerfish_desc =>
      'Poisson-papillon jaune vif portant une tache oculaire sombre, endémique de la mer Rouge. Souvent observé en couple.';

  @override
  String get species_red_sea_anemonefish_name =>
      'Poisson-clown de la mer Rouge';

  @override
  String get species_red_sea_anemonefish_desc =>
      'Poisson-clown jaune orangé barré de deux bandes blanches, endémique de la mer Rouge et du golfe d\'Aden.';

  @override
  String get species_arabian_angelfish_name => 'Poisson-ange arabe';

  @override
  String get species_arabian_angelfish_desc =>
      'Grand poisson-ange bleu foncé portant une large bande verticale jaune et une queue jaune, endémique de l\'ouest de l\'océan Indien.';

  @override
  String get species_king_angelfish_name => 'Poisson-ange roi';

  @override
  String get species_king_angelfish_desc =>
      'Grand poisson-ange bleu foncé portant une bande verticale blanche et une queue jaune, présent dans le Pacifique Est et aux Galapagos.';

  @override
  String get species_ocean_sunfish_name => 'Poisson-lune';

  @override
  String get species_ocean_sunfish_desc =>
      'Le poisson osseux le plus lourd, dépassant 2 tonnes. Parfois observé par les plongeurs aux stations de nettoyage de Bali et des Galapagos.';

  @override
  String get species_lingcod_name => 'Morue-lingue';

  @override
  String get species_lingcod_desc =>
      'Grand prédateur marbré des récifs rocheux du Nord-Ouest Pacifique, souvent vu en train de garder ses pontes.';

  @override
  String get species_wolf_eel_name => 'Loup-anguille';

  @override
  String get species_wolf_eel_desc =>
      'Grand loup-anguille gris à la tête bulbeuse et aux mâchoires puissantes, présent dans les tanières rocheuses du Nord-Ouest Pacifique.';

  @override
  String get species_giant_sea_bass_name => 'Bar géant';

  @override
  String get species_giant_sea_bass_desc =>
      'Bar massif dépassant 2 m et 250 kg, présent sur les récifs rocheux et dans les forêts de laminaires du sud de la Californie.';

  @override
  String get species_garibaldi_name => 'Garibaldi';

  @override
  String get species_garibaldi_desc =>
      'Demoiselle orange vif et poisson marin emblème de la Californie, territoriale sur les récifs des forêts de laminaires.';

  @override
  String get species_sheephead_name => 'Labre californien';

  @override
  String get species_sheephead_desc =>
      'Grand labre à la tête et à la queue noires, au milieu du corps rouge et au menton blanc. Présent dans les forêts de laminaires de Californie.';

  @override
  String get species_copper_rockfish_name => 'Sébaste cuivré';

  @override
  String get species_copper_rockfish_desc =>
      'Sébaste orange cuivré marqué de plages claires, courant sur les récifs rocheux et dans les forêts de laminaires du Nord-Ouest Pacifique.';

  @override
  String get species_oriental_sweetlips_name => 'Gaterin oriental';

  @override
  String get species_oriental_sweetlips_desc =>
      'Grand poisson de récif indo-pacifique rayé de noir et de blanc, aux nageoires jaunes. Les juvéniles exécutent une danse ondulante.';

  @override
  String get species_harlequin_sweetlips_name => 'Gaterin arlequin';

  @override
  String get species_harlequin_sweetlips_desc =>
      'Les adultes sont gris tachetés de sombre; les juvéniles sont bruns à grandes taches blanches et nagent en ondulant.';

  @override
  String get species_blue_ringed_angelfish_name => 'Poisson-ange à anneau bleu';

  @override
  String get species_blue_ringed_angelfish_desc =>
      'Grand poisson-ange brun parcouru de lignes bleues courbes et portant un anneau bleu caractéristique au-dessus de l\'opercule.';

  @override
  String get species_yellowbar_angelfish_name => 'Poisson-ange à bande jaune';

  @override
  String get species_yellowbar_angelfish_desc =>
      'Grand poisson-ange gris-bleu marqué d\'une large plage jaune, présent en mer Rouge et dans l\'ouest de l\'océan Indien.';

  @override
  String get species_filefish_scrawled_name => 'Poisson-lime griffonné';

  @override
  String get species_filefish_scrawled_desc =>
      'Grand poisson-lime brun olive aux marques bleues en gribouillis et au fanon orange, présent sur les récifs tropicaux du monde entier.';

  @override
  String get species_clown_filefish_name => 'Poisson-lime à points orange';

  @override
  String get species_clown_filefish_desc =>
      'Petit poisson-lime vert à points orange et au museau allongé, qui se nourrit exclusivement de polypes de coraux Acropora.';

  @override
  String get species_unicornfish_name => 'Poisson-licorne à épines bleues';

  @override
  String get species_unicornfish_desc =>
      'Chirurgien gris portant une corne frontale proéminente et deux épines caudales bleues, commun sur les platiers récifaux indo-pacifiques.';

  @override
  String get species_surgeonfish_sailfin_name => 'Chirurgien voilier';

  @override
  String get species_surgeonfish_sailfin_desc =>
      'Chirurgien aux bandes marquées et aux nageoires dorsale et anale très développées, présent dans tout l\'Indo-Pacifique.';

  @override
  String get species_achilles_tang_name => 'Chirurgien d\'Achille';

  @override
  String get species_achilles_tang_desc =>
      'Chirurgien brun foncé portant une nette larme orange près de la queue, présent dans les zones de ressac du Pacifique central.';

  @override
  String get species_doctorfish_name => 'Chirurgien docteur';

  @override
  String get species_doctorfish_desc =>
      'Chirurgien brun grisâtre aux bandes sombres discrètes et au scalpel caudal marqué, commun sur les récifs des Caraïbes.';

  @override
  String get species_checkerboard_wrasse_name => 'Labre damier';

  @override
  String get species_checkerboard_wrasse_desc =>
      'Labre coloré au motif en damier de carrés verts, roses et noirs sur tout le corps.';

  @override
  String get species_bird_wrasse_name => 'Labre oiseau';

  @override
  String get species_bird_wrasse_desc =>
      'Labre au museau extrêmement allongé évoquant un bec d\'oiseau; les mâles sont vert foncé, les femelles brunes.';

  @override
  String get species_sling_jaw_wrasse_name => 'Labre à mâchoire projetable';

  @override
  String get species_sling_jaw_wrasse_desc =>
      'Labre doté d\'une mâchoire extensible qui se projette vers l\'avant pour capturer ses proies, présent en formes jaune ou brune.';

  @override
  String get species_peacock_flounder_name => 'Turbot paon';

  @override
  String get species_peacock_flounder_desc =>
      'Poisson plat de fond orné d\'anneaux et de points bleus, capable de changer de couleur pour se fondre dans le substrat.';

  @override
  String get species_hogfish_name => 'Labre capitaine';

  @override
  String get species_hogfish_desc =>
      'Grand labre de l\'Atlantique Ouest au museau en groin et aux épines dorsales allongées, présent près des récifs et des épaves.';

  @override
  String get species_tarpon_name => 'Tarpon atlantique';

  @override
  String get species_tarpon_desc =>
      'Énorme poisson argenté aux grandes écailles réfléchissantes, parfois rencontré par les plongeurs dans les grottes et les passes des Caraïbes.';

  @override
  String get species_permit_name => 'Pompaneau permit';

  @override
  String get species_permit_desc =>
      'Carangidé argenté au corps haut et à la queue fourchue sombre, présent sur les fonds sableux des Caraïbes et près des récifs.';

  @override
  String get species_spotted_drum_name => 'Tambour tacheté';

  @override
  String get species_spotted_drum_desc =>
      'Poisson des Caraïbes saisissant, à la haute nageoire dorsale allongée et au motif tacheté noir et blanc marqué.';

  @override
  String get species_jackknife_fish_name => 'Tambour lancéolé';

  @override
  String get species_jackknife_fish_desc =>
      'Élégant poisson des Caraïbes à la haute nageoire dorsale rayée de noir et à la bande corporelle oblique, présent sous les surplombs.';

  @override
  String get species_bigeye_name => 'Beauclaire de roche';

  @override
  String get species_bigeye_desc =>
      'Poisson nocturne rouge vif aux grands yeux réfléchissants, caché dans les grottes des récifs des Caraïbes et de l\'Atlantique.';

  @override
  String get species_remora_name => 'Rémora';

  @override
  String get species_remora_desc =>
      'Poisson élancé pourvu d\'un disque adhésif sur la tête, qui se fait transporter par les requins, les raies, les tortues et d\'autres grands animaux.';

  @override
  String get species_tilefish_sand_name => 'Matajuelo blanc';

  @override
  String get species_tilefish_sand_desc =>
      'Poisson allongé bleu pâle qui édifie des monticules de débris sur les zones sableuses des récifs des Caraïbes.';

  @override
  String get species_weedy_seadragon_name => 'Dragon de mer commun';

  @override
  String get species_weedy_seadragon_desc =>
      'Cousin orné des hippocampes portant des appendices en forme de feuilles, endémique des eaux tempérées du sud de l\'Australie.';

  @override
  String get species_leafy_seadragon_name => 'Dragon de mer feuillu';

  @override
  String get species_leafy_seadragon_desc =>
      'Spectaculaire dragon de mer couvert d\'expansions foliacées élaborées, endémique du sud de l\'Australie. Une observation de rêve pour les plongeurs.';

  @override
  String get species_sailfin_snapper_name => 'Vivaneau voilier';

  @override
  String get species_sailfin_snapper_desc =>
      'Élégant vivaneau jaune et bleu aux nageoires dorsale et anale allongées, présent sur les pentes récifales indo-pacifiques.';

  @override
  String get species_sweetlip_emperor_name => 'Empereur moucheté';

  @override
  String get species_sweetlip_emperor_desc =>
      'Grand empereur argenté aux lignes bleues sur la face et aux nageoires bordées de jaune, commun sur les zones sableuses des récifs indo-pacifiques.';

  @override
  String get species_crocodilefish_name => 'Poisson-crocodile';

  @override
  String get species_crocodilefish_desc =>
      'Prédateur embusqué à la tête aplatie et aux franges oculaires élaborées, parfaitement camouflé sur les fonds récifaux indo-pacifiques.';

  @override
  String get species_devil_scorpionfish_name => 'Rascasse diable';

  @override
  String get species_devil_scorpionfish_desc =>
      'Rascasse trapue et camouflée qui déploie ses pectorales aux couleurs vives en signal d\'avertissement.';

  @override
  String get species_spiny_devilfish_name => 'Poisson-diable épineux';

  @override
  String get species_spiny_devilfish_desc =>
      'Poisson de fond venimeux qui marche sur des rayons de nageoires modifiés et déploie ses pectorales colorées quand on le dérange.';

  @override
  String get species_waspfish_name => 'Poisson-guêpe cacatoès';

  @override
  String get species_waspfish_desc =>
      'Petite rascasse comprimée qui ondule dans le courant comme une feuille morte sur les fonds vaseux indo-pacifiques.';

  @override
  String get species_stargazer_name => 'Uranoscope à marge blanche';

  @override
  String get species_stargazer_desc =>
      'Prédateur embusqué qui s\'enfouit dans le sable en ne laissant dépasser que les yeux et peut délivrer des décharges électriques. Présent dans l\'Indo-Pacifique.';

  @override
  String get species_striped_catfish_name => 'Poisson-chat rayé';

  @override
  String get species_striped_catfish_desc =>
      'Poisson-chat aux épines venimeuses; les juvéniles forment des bancs denses en boule qui roulent sur les fonds récifaux indo-pacifiques.';

  @override
  String get species_red_emperor_name => 'Empereur rouge';

  @override
  String get species_red_emperor_desc =>
      'Grand vivaneau; les adultes sont rouge rosé, les juvéniles portent des bandes rouges et blanches marquées. Présent sur les récifs indo-pacifiques.';

  @override
  String get species_mangrove_snapper_name => 'Vivaneau des mangroves';

  @override
  String get species_mangrove_snapper_desc =>
      'Vivaneau gris présent dans les mangroves, les herbiers et les récifs des Caraïbes, souvent rassemblé près des structures.';

  @override
  String get species_dottyback_orchid_name => 'Pseudochromis orchidée';

  @override
  String get species_dottyback_orchid_desc =>
      'Petit poisson d\'un violet intense endémique de la mer Rouge, qui file d\'une anfractuosité à l\'autre sur les tombants abrupts.';

  @override
  String get species_dottyback_royal_name => 'Pseudochromis royal';

  @override
  String get species_dottyback_royal_desc =>
      'Petit poisson bicolore, magenta à l\'avant et jaune vif à l\'arrière, présent sur les tombants indo-pacifiques.';

  @override
  String get species_coral_trout_name => 'Loche saumonée';

  @override
  String get species_coral_trout_desc =>
      'Prédateur prisé de la Grande Barrière de corail, au corps rouge orangé couvert de points bleus.';

  @override
  String get species_barramundi_cod_name => 'Mérou barramundi';

  @override
  String get species_barramundi_cod_desc =>
      'Mérou caractéristique à la petite tête, au corps bossu et aux gros pois sombres sur fond clair.';

  @override
  String get species_spadefish_atlantic_name => 'Disque portugais';

  @override
  String get species_spadefish_atlantic_desc =>
      'Poisson argenté en forme de disque barré de bandes verticales sombres, souvent observé en grands bancs autour des épaves des Caraïbes.';

  @override
  String get species_fusilier_yellowback_name => 'Fusilier à dos jaune';

  @override
  String get species_fusilier_yellowback_desc =>
      'Poisson planctonophage bleu et élancé au dos jaune, formant d\'immenses bancs au-dessus des pentes récifales indo-pacifiques.';

  @override
  String get species_fusilier_bluestreak_name => 'Fusilier à raie bleue';

  @override
  String get species_fusilier_bluestreak_desc =>
      'Petit fusilier bleu marqué d\'une bande latérale sombre, observé en bancs rapides le long des tombants indo-pacifiques.';

  @override
  String get species_porkfish_name => 'Grondeur porc';

  @override
  String get species_porkfish_desc =>
      'Grondeur coloré des Caraïbes rayé de bleu et de jaune, avec deux barres noires sur la tête, présent près des récifs et des épaves.';

  @override
  String get species_blue_striped_grunt_name => 'Grondeur à raies bleues';

  @override
  String get species_blue_striped_grunt_desc =>
      'Grondeur jaune des Caraïbes aux raies horizontales bleu vif, qui forme de grands bancs au repos sous les surplombs pendant la journée.';

  @override
  String get species_french_grunt_name => 'Grondeur français';

  @override
  String get species_french_grunt_desc =>
      'Petit grondeur rayé de jaune qui forme des bancs denses au repos sur les récifs des Caraïbes pendant la journée.';

  @override
  String get species_convict_tang_name => 'Chirurgien bagnard';

  @override
  String get species_convict_tang_desc =>
      'Chirurgien clair barré de six bandes noires verticales, souvent vu brouter en grands bancs sur les platiers récifaux indo-pacifiques.';

  @override
  String get species_great_hammerhead_name => 'Requin-marteau halicorne';

  @override
  String get species_great_hammerhead_desc =>
      'Requin caractéristique à la tête en marteau festonné, formant de grands bancs autour des monts sous-marins et des îles du large.';

  @override
  String get species_wobbegong_name => 'Requin-tapis tacheté';

  @override
  String get species_wobbegong_desc =>
      'Requin-tapis aplati et bien camouflé, orné de lobes frangés autour de la bouche, présent sur les récifs tempérés australiens.';

  @override
  String get species_manta_ray_name => 'Raie manta de récif';

  @override
  String get species_manta_ray_desc =>
      'Géant gracieux atteignant 5 m d\'envergure, qui fréquente les stations de nettoyage et se nourrit de plancton sur les récifs indo-pacifiques.';

  @override
  String get species_oceanic_manta_name => 'Raie manta océanique';

  @override
  String get species_oceanic_manta_desc =>
      'La plus grande espèce de raie, dont l\'envergure dépasse 7 m, rencontrée sur les monts sous-marins du large et aux stations de nettoyage.';

  @override
  String get species_undulated_moray_name => 'Murène ondulée';

  @override
  String get species_undulated_moray_desc =>
      'Murène vert jaunâtre aux marques sombres ondulées, couramment vue chasser de nuit sur les récifs indo-pacifiques.';

  @override
  String get species_whitemouth_moray_name => 'Murène à bouche blanche';

  @override
  String get species_whitemouth_moray_desc =>
      'Murène brun foncé à petits points blancs, reconnaissable à l\'intérieur blanc de sa gueule, présente dans tout l\'Indo-Pacifique.';

  @override
  String get species_dragon_moray_name => 'Murène dragon';

  @override
  String get species_dragon_moray_desc =>
      'Murène saisissante portant des cornes au-dessus des narines et des taches léopard rouge orangé, présente dans l\'Indo-Pacifique.';

  @override
  String get species_lyretail_grouper_name => 'Mérou à queue en lyre';

  @override
  String get species_lyretail_grouper_desc =>
      'Mérou rouge rosé à points bleus et à la queue en croissant caractéristique, présent sur les tombants récifaux externes indo-pacifiques.';

  @override
  String get species_banded_butterflyfish_name => 'Poisson-papillon rubané';

  @override
  String get species_banded_butterflyfish_desc =>
      'Poisson-papillon blanc barré de quatre bandes verticales noires marquées, l\'un des papillons les plus communs des récifs des Caraïbes.';

  @override
  String get species_ringed_pipefish_name => 'Syngnathe annelé';

  @override
  String get species_ringed_pipefish_desc =>
      'Syngnathe élancé aux anneaux alternés rouges et blancs, présent dans les grottes et sous les surplombs des récifs indo-pacifiques.';

  @override
  String get species_razorfish_name => 'Poisson-rasoir';

  @override
  String get species_razorfish_desc =>
      'Minuscule poisson qui nage à la verticale, tête en bas, en petits groupes, souvent réfugié entre les épines des oursins sur les récifs indo-pacifiques.';

  @override
  String get species_harlequin_tuskfish_name => 'Labre arlequin';

  @override
  String get species_harlequin_tuskfish_desc =>
      'Labre coloré aux défenses bleu vif, aux barres rouge orangé et aux plages blanches, présent sur les récifs du Pacifique Ouest.';

  @override
  String get species_blue_groper_name => 'Labre bleu d\'Australie';

  @override
  String get species_blue_groper_desc =>
      'Grand labre bleu endémique de l\'est de l\'Australie, sociable et qui s\'approche souvent des plongeurs sur les récifs tempérés.';

  @override
  String get species_red_lipped_batfish_name =>
      'Poisson chauve-souris à lèvres rouges';

  @override
  String get species_red_lipped_batfish_desc =>
      'Étrange poisson au corps aplati et aux lèvres rouge vif, qui marche sur des nageoires modifiées sur les fonds des Galapagos.';

  @override
  String get species_orangeband_surgeonfish_name => 'Chirurgien à bande orange';

  @override
  String get species_orangeband_surgeonfish_desc =>
      'Chirurgien gris-brun marqué d\'une bande horizontale orange derrière l\'oeil, présent sur les pentes récifales du Pacifique.';

  @override
  String get species_maori_wrasse_name => 'Labre maori';

  @override
  String get species_maori_wrasse_desc =>
      'Labre de taille moyenne portant une bande sombre derrière la nageoire pectorale, commun sur les récifs du Pacifique et de l\'océan Indien.';

  @override
  String get species_blue_ringed_octopus_name => 'Pieuvre à anneaux bleus';

  @override
  String get species_blue_ringed_octopus_desc =>
      'Petite pieuvre extrêmement venimeuse dont les anneaux bleu vif s\'illuminent lorsqu\'elle se sent menacée.';

  @override
  String get species_common_octopus_name => 'Pieuvre commune';

  @override
  String get species_common_octopus_desc =>
      'Pieuvre très intelligente, connue pour ses changements de couleur rapides et ses capacités à résoudre des problèmes.';

  @override
  String get species_giant_pacific_octopus_name =>
      'Pieuvre géante du Pacifique';

  @override
  String get species_giant_pacific_octopus_desc =>
      'La plus grande espèce de pieuvre, dont l\'envergure des bras dépasse 4 mètres dans les eaux froides du Pacifique.';

  @override
  String get species_mimic_octopus_name => 'Pieuvre mimétique';

  @override
  String get species_mimic_octopus_desc =>
      'Pieuvre remarquable qui imite l\'apparence et le comportement d\'autres espèces marines.';

  @override
  String get species_coconut_octopus_name => 'Pieuvre noix de coco';

  @override
  String get species_coconut_octopus_desc =>
      'Petite pieuvre célèbre pour transporter des coques de noix de coco et s\'en servir comme abris portatifs.';

  @override
  String get species_day_octopus_name => 'Pieuvre diurne';

  @override
  String get species_day_octopus_desc =>
      'Chasseuse diurne active, commune sur les récifs indo-pacifiques, aux impressionnantes capacités de camouflage.';

  @override
  String get species_wonderpus_octopus_name => 'Pieuvre wonderpus';

  @override
  String get species_wonderpus_octopus_desc =>
      'Pieuvre saisissante aux bandes blanches et brunes uniques, présente sur les sites sableux de muck diving.';

  @override
  String get species_broadclub_cuttlefish_name => 'Seiche à larges massues';

  @override
  String get species_broadclub_cuttlefish_desc =>
      'Grande seiche aux jeux de couleurs hypnotiques, couramment observée sur les récifs indo-pacifiques.';

  @override
  String get species_pharaoh_cuttlefish_name => 'Seiche pharaon';

  @override
  String get species_pharaoh_cuttlefish_desc =>
      'Grande seiche présente dans tout l\'océan Indien, connue pour ses motifs de couleurs pulsantes.';

  @override
  String get species_flamboyant_cuttlefish_name => 'Seiche flamboyante';

  @override
  String get species_flamboyant_cuttlefish_desc =>
      'Minuscule seiche qui marche sur le fond en affichant des pulsations violettes, roses et jaunes éclatantes.';

  @override
  String get species_giant_cuttlefish_name => 'Seiche géante';

  @override
  String get species_giant_cuttlefish_desc =>
      'La plus grande seiche du monde, célèbre pour ses rassemblements massifs de reproduction en Australie-Méridionale.';

  @override
  String get species_bigfin_reef_squid_name => 'Calmar à grandes nageoires';

  @override
  String get species_bigfin_reef_squid_desc =>
      'Calmar grégaire fréquemment rencontré en plongée de nuit, attiré par les phares des plongeurs.';

  @override
  String get species_caribbean_reef_squid_name =>
      'Calmar de récif des Caraïbes';

  @override
  String get species_caribbean_reef_squid_desc =>
      'Calmar curieux souvent en suspension par petits groupes près des bordures récifales des Caraïbes.';

  @override
  String get species_bobtail_squid_name => 'Sépiole';

  @override
  String get species_bobtail_squid_desc =>
      'Minuscule céphalopode nocturne qui s\'enfouit dans le sable le jour, une trouvaille prisée en muck diving.';

  @override
  String get species_chambered_nautilus_name => 'Nautile';

  @override
  String get species_chambered_nautilus_desc =>
      'Fossile vivant à la coquille enroulée, rarement observé par les plongeurs en eau profonde à l\'aube.';

  @override
  String get species_spanish_dancer_name => 'Danseuse espagnole';

  @override
  String get species_spanish_dancer_desc =>
      'La plus grande espèce de nudibranche, qui nage en ondulant son manteau rouge comme une danseuse de flamenco.';

  @override
  String get species_chromodoris_willani_name => 'Chromodoris de Willan';

  @override
  String get species_chromodoris_willani_desc =>
      'Nudibranche bleu et noir saisissant à la marge blanche, commun dans l\'Indo-Pacifique.';

  @override
  String get species_chromodoris_lochi_name => 'Chromodoris de Loch';

  @override
  String get species_chromodoris_lochi_desc =>
      'Nudibranche bleu aux lignes sombres et à la bordure blanche, présent dans tout le Pacifique tropical.';

  @override
  String get species_chromodoris_magnifica_name => 'Chromodoris magnifique';

  @override
  String get species_chromodoris_magnifica_desc =>
      'Nudibranche d\'un bleu éclatant, blanc et orange, présent sur les récifs coralliens indo-pacifiques.';

  @override
  String get species_chromodoris_annae_name => 'Chromodoris d\'Anna';

  @override
  String get species_chromodoris_annae_desc =>
      'Nudibranche bleu profond aux lignes noires, aux rhinophores et aux branchies à pointe orange.';

  @override
  String get species_nembrotha_kubaryana_name => 'Nembrotha variable';

  @override
  String get species_nembrotha_kubaryana_desc =>
      'Nudibranche vert foncé aux marques orange ou rouges vives, qui se nourrit de tuniciers.';

  @override
  String get species_nembrotha_cristata_name => 'Nembrotha à crête';

  @override
  String get species_nembrotha_cristata_desc =>
      'Nudibranche noir aux pustules et aux rayures vert vif, présent sur les récifs indo-pacifiques.';

  @override
  String get species_phyllidia_varicosa_name => 'Phyllidia variqueuse';

  @override
  String get species_phyllidia_varicosa_desc =>
      'Nudibranche gris-bleu aux tubercules saillants à pointe jaune, toxique pour les prédateurs.';

  @override
  String get species_phyllidia_ocellata_name => 'Phyllidia ocellée';

  @override
  String get species_phyllidia_ocellata_desc =>
      'Nudibranche blanc aux tubercules saillants cerclés de rose, présent sur les récifs tropicaux.';

  @override
  String get species_pikachu_nudibranch_name => 'Nudibranche Pikachu';

  @override
  String get species_pikachu_nudibranch_desc =>
      'Minuscule limace de mer jaune et noire qui évoque un personnage de dessin animé, présente dans le Pacifique.';

  @override
  String get species_anna_rosefieldi_name => 'Nudibranche Roboastra';

  @override
  String get species_anna_rosefieldi_desc =>
      'Nudibranche prédateur au corps sombre et aux rayures longitudinales vives, qui chasse d\'autres limaces.';

  @override
  String get species_lettuce_sea_slug_name => 'Limace de mer laitue';

  @override
  String get species_lettuce_sea_slug_desc =>
      'Limace de mer verte aux replis frisés, qui conserve les chloroplastes des algues pour photosynthétiser.';

  @override
  String get species_blue_dragon_nudibranch_name => 'Nudibranche dragon bleu';

  @override
  String get species_blue_dragon_nudibranch_desc =>
      'Long nudibranche éolidien aux cérates à pointe bleue, qui héberge des zooxanthelles symbiotiques.';

  @override
  String get species_gloomy_nudibranch_name => 'Nudibranche sombre';

  @override
  String get species_gloomy_nudibranch_desc =>
      'Nudibranche vert-bleu foncé aux crêtes bordées de bleu, commun sur les récifs indo-pacifiques.';

  @override
  String get species_ocellined_nudibranch_name => 'Nudibranche ocelliné';

  @override
  String get species_ocellined_nudibranch_desc =>
      'Nudibranche blanc aux crêtes soulignées d\'orange formant des motifs géométriques sur son manteau.';

  @override
  String get species_glossodoris_cincta_name => 'Nudibranche Glossodoris';

  @override
  String get species_glossodoris_cincta_desc =>
      'Nudibranche crème à la bordure brun foncé et à la marge orange sur le manteau.';

  @override
  String get species_jorunna_funebris_name => 'Nudibranche pointillé';

  @override
  String get species_jorunna_funebris_desc =>
      'Nudibranche blanc couvert de caryophyllidies à pointe noire, qui évoque un lapin duveteux.';

  @override
  String get species_ceratosoma_trilobatum_name => 'Nudibranche trilobé';

  @override
  String get species_ceratosoma_trilobatum_desc =>
      'Grand nudibranche à la haute corne dorsale et aux lobes latéraux dans des tons violets et jaunes.';

  @override
  String get species_hypselodoris_apolegma_name => 'Hypselodoris pourpre';

  @override
  String get species_hypselodoris_apolegma_desc =>
      'Élégant nudibranche violet à la bordure de manteau blanche, présent sur les récifs indo-pacifiques.';

  @override
  String get species_hypselodoris_bullockii_name => 'Hypselodoris de Bullock';

  @override
  String get species_hypselodoris_bullockii_desc =>
      'Nudibranche rose et violet aux rhinophores à pointe jaune, sur les récifs indo-pacifiques.';

  @override
  String get species_flabellina_exoptata_name => 'Flabellina désirable';

  @override
  String get species_flabellina_exoptata_desc =>
      'Nudibranche éolidien translucide aux cérates orange à pointe violette, présent dans les eaux tropicales.';

  @override
  String get species_risbecia_tryoni_name => 'Risbecia de Tryon';

  @override
  String get species_risbecia_tryoni_desc =>
      'Grand nudibranche brun et bleu, souvent trouvé en couple d\'accouplement sur les récifs indo-pacifiques.';

  @override
  String get species_goniobranchus_kuniei_name => 'Nudibranche de Kunié';

  @override
  String get species_goniobranchus_kuniei_desc =>
      'Nudibranche blanc à points orange et à la marge du manteau violette, présent dans le Pacifique Ouest.';

  @override
  String get species_mexichromis_multituberculata_name =>
      'Nudibranche multituberculé';

  @override
  String get species_mexichromis_multituberculata_desc =>
      'Nudibranche violet et blanc aux tubercules saillants et aux appendices à pointe orange.';

  @override
  String get species_chromodoris_dianae_name => 'Chromodoris de Diana';

  @override
  String get species_chromodoris_dianae_desc =>
      'Nudibranche bleu vif aux rayures noires et aux branchies orange, présent dans le Pacifique Ouest.';

  @override
  String get species_phyllodesmium_poindimiei_name => 'Nudibranche solaire';

  @override
  String get species_phyllodesmium_poindimiei_desc =>
      'Nudibranche éolidien translucide aux cérates ramifiés, qui héberge des zooxanthelles.';

  @override
  String get species_chromodoris_elisabethina_name =>
      'Chromodoris d\'Élisabeth';

  @override
  String get species_chromodoris_elisabethina_desc =>
      'Nudibranche bleu souligné de jaune à la bordure de manteau blanche, commun en Asie du Sud-Est.';

  @override
  String get species_doridella_batava_name => 'Doris de Batavia';

  @override
  String get species_doridella_batava_desc =>
      'Doris variable, du noir au brun, trouvé sous les roches et les débris des récifs indo-pacifiques.';

  @override
  String get species_tiger_cowrie_name => 'Porcelaine tigre';

  @override
  String get species_tiger_cowrie_desc =>
      'Grande porcelaine tachetée des récifs tropicaux, souvent partiellement recouverte par son manteau.';

  @override
  String get species_tritons_trumpet_name => 'Triton géant';

  @override
  String get species_tritons_trumpet_desc =>
      'Grand gastéropode prédateur, ennemi naturel de l\'étoile de mer couronne d\'épines.';

  @override
  String get species_queen_conch_name => 'Lambi';

  @override
  String get species_queen_conch_desc =>
      'Grand strombe emblématique des herbiers des Caraïbes, reconnaissable à sa lèvre interne rose.';

  @override
  String get species_banded_coral_shrimp_name =>
      'Crevette nettoyeuse à bandes rouges';

  @override
  String get species_banded_coral_shrimp_desc =>
      'Crevette nettoyeuse annelée de rouge et de blanc, aux longues antennes blanches, présente dans les anfractuosités du récif.';

  @override
  String get species_mantis_shrimp_name => 'Squille paon';

  @override
  String get species_mantis_shrimp_desc =>
      'Prédateur coloré doté d\'appendices en massue capables de briser des coquilles.';

  @override
  String get species_cleaner_shrimp_name => 'Crevette nettoyeuse écarlate';

  @override
  String get species_cleaner_shrimp_desc =>
      'Crevette rouge et blanche éclatante qui installe des stations de nettoyage au service des poissons de récif.';

  @override
  String get species_pederson_cleaner_shrimp_name =>
      'Crevette nettoyeuse de Pederson';

  @override
  String get species_pederson_cleaner_shrimp_desc =>
      'Crevette nettoyeuse translucide des Caraïbes qui vit parmi les tentacules des anémones.';

  @override
  String get species_harlequin_shrimp_name => 'Crevette arlequin';

  @override
  String get species_harlequin_shrimp_desc =>
      'Crevette au motif saisissant et aux pinces aplaties, qui se nourrit exclusivement d\'étoiles de mer.';

  @override
  String get species_coleman_shrimp_name => 'Crevette de Coleman';

  @override
  String get species_coleman_shrimp_desc =>
      'Minuscule crevette vivant en couple sur les oursins de feu, très prisée des photographes sous-marins.';

  @override
  String get species_emperor_shrimp_name => 'Crevette empereur';

  @override
  String get species_emperor_shrimp_desc =>
      'Crevette commensale colorée qui se déplace sur les concombres de mer et les nudibranches.';

  @override
  String get species_sexy_shrimp_name => 'Crevette sexy';

  @override
  String get species_sexy_shrimp_desc =>
      'Minuscule crevette d\'anémone connue pour sa danse de l\'abdomen, très photographiée en macro.';

  @override
  String get species_marble_shrimp_name => 'Crevette marbrée';

  @override
  String get species_marble_shrimp_desc =>
      'Crevette nocturne marbrée aux pattes plumeuses, cachée le jour dans les anfractuosités du récif.';

  @override
  String get species_spiny_lobster_name => 'Langouste des Caraïbes';

  @override
  String get species_spiny_lobster_desc =>
      'Grande langouste sans pinces aux longues antennes, abritée sous les surplombs du récif.';

  @override
  String get species_painted_spiny_lobster_name => 'Langouste peinte';

  @override
  String get species_painted_spiny_lobster_desc =>
      'Langouste aux couleurs vives, aux pattes rayées de bleu, de vert et de blanc, sur les récifs indo-pacifiques.';

  @override
  String get species_slipper_lobster_name => 'Cigale de mer';

  @override
  String get species_slipper_lobster_desc =>
      'Crustacé nocturne au corps aplati, doté de larges plaques antennaires au lieu de longs fouets.';

  @override
  String get species_squat_lobster_name => 'Galathée';

  @override
  String get species_squat_lobster_desc =>
      'Minuscule crustacé rose-violet vivant sur les éponges barriques géantes, un classique de la photo macro.';

  @override
  String get species_hermit_crab_name => 'Bernard-l\'ermite à pattes bleues';

  @override
  String get species_hermit_crab_desc =>
      'Petit bernard-l\'ermite aux pattes bleu vif, couramment observé sur les récifs des Caraïbes.';

  @override
  String get species_orangutan_crab_name => 'Crabe orang-outan';

  @override
  String get species_orangutan_crab_desc =>
      'Minuscule crabe poilu vivant dans les coraux bulles, ainsi nommé pour sa ressemblance avec un orang-outan.';

  @override
  String get species_decorator_crab_name => 'Crabe décorateur';

  @override
  String get species_decorator_crab_desc =>
      'Maître du déguisement qui fixe éponges, algues et hydraires sur sa carapace.';

  @override
  String get species_porcelain_crab_name => 'Crabe porcelaine des anémones';

  @override
  String get species_porcelain_crab_desc =>
      'Crabe plat et tacheté vivant dans les anémones, qui filtre l\'eau avec ses pièces buccales plumeuses.';

  @override
  String get species_arrow_crab_name => 'Crabe flèche';

  @override
  String get species_arrow_crab_desc =>
      'Crabe grêle des Caraïbes au long rostre pointu et aux pattes rayées.';

  @override
  String get species_channel_clinging_crab_name =>
      'Crabe araignée des Caraïbes';

  @override
  String get species_channel_clinging_crab_desc =>
      'Grand crabe de récif des Caraïbes au corps sombre et aux pinces rouge orangé, présent dans les anfractuosités.';

  @override
  String get species_coral_crab_name => 'Crabe gardien du corail';

  @override
  String get species_coral_crab_desc =>
      'Petit crabe tacheté vivant en symbiose dans les coraux Pocillopora, dont il défend l\'hôte.';

  @override
  String get species_crown_of_thorns_starfish_name =>
      'Étoile de mer couronne d\'épines';

  @override
  String get species_crown_of_thorns_starfish_desc =>
      'Étoile de mer venimeuse à bras multiples qui se nourrit de corail et peut ravager les récifs lors de pullulations.';

  @override
  String get species_blue_linckia_starfish_name => 'Étoile de mer bleue';

  @override
  String get species_blue_linckia_starfish_desc =>
      'Étoile de mer d\'un bleu vif, couramment observée sur les platiers et les pentes récifales indo-pacifiques.';

  @override
  String get species_red_knob_starfish_name => 'Étoile de mer à boutons rouges';

  @override
  String get species_red_knob_starfish_desc =>
      'Grande étoile de mer grise aux épines proéminentes à pointe rouge, présente sur les zones sableuses du récif.';

  @override
  String get species_chocolate_chip_starfish_name =>
      'Étoile de mer pépites de chocolat';

  @override
  String get species_chocolate_chip_starfish_desc =>
      'Étoile de mer beige aux nodules sombres saillants évoquant des pépites de chocolat, sur les fonds sableux.';

  @override
  String get species_cushion_star_name => 'Étoile coussin';

  @override
  String get species_cushion_star_desc =>
      'Étoile de mer pentagonale bombée aux bras réduits, présente sur les platiers récifaux indo-pacifiques.';

  @override
  String get species_fromia_starfish_name => 'Étoile de mer élégante';

  @override
  String get species_fromia_starfish_desc =>
      'Petite étoile de mer rouge orangé aux plaques bordées de clair, formant un motif de carrelage.';

  @override
  String get species_basket_star_name => 'Gorgonocéphale';

  @override
  String get species_basket_star_desc =>
      'Ses bras finement ramifiés se déploient la nuit pour filtrer le courant.';

  @override
  String get species_brittle_star_name => 'Ophiure annelée';

  @override
  String get species_brittle_star_desc =>
      'Ophiure rayée présente sous les roches et dans les anfractuosités, aux bras agiles et serpentiformes.';

  @override
  String get species_feather_star_name => 'Comatule';

  @override
  String get species_feather_star_desc =>
      'Crinoïde à bras multiples perché sur les reliefs du récif, qui filtre l\'eau avec ses bras plumeux.';

  @override
  String get species_black_feather_star_name => 'Comatule noire';

  @override
  String get species_black_feather_star_desc =>
      'Crinoïde sombre capable de nager brièvement en agitant rythmiquement ses nombreux bras.';

  @override
  String get species_long_spined_sea_urchin_name => 'Oursin diadème';

  @override
  String get species_long_spined_sea_urchin_desc =>
      'Oursin noir aux longues épines venimeuses, brouteur essentiel des récifs des Caraïbes.';

  @override
  String get species_fire_urchin_name => 'Oursin de feu';

  @override
  String get species_fire_urchin_desc =>
      'Oursin au corps mou et aux épines venimeuses qui provoquent des piqûres douloureuses au contact.';

  @override
  String get species_pencil_urchin_name => 'Oursin crayon';

  @override
  String get species_pencil_urchin_desc =>
      'Oursin robuste aux épines épaisses et émoussées, coincé dans les anfractuosités du récif.';

  @override
  String get species_collector_urchin_name => 'Oursin collectionneur';

  @override
  String get species_collector_urchin_desc =>
      'Oursin qui se couvre de débris et de fragments d\'algues pour se camoufler.';

  @override
  String get species_sea_apple_name => 'Pomme de mer';

  @override
  String get species_sea_apple_desc =>
      'Concombre de mer aux couleurs vives dont les tentacules buccaux servent à filtrer l\'eau.';

  @override
  String get species_pineapple_sea_cucumber_name => 'Concombre de mer ananas';

  @override
  String get species_pineapple_sea_cucumber_desc =>
      'Grand concombre de mer rouge orangé aux papilles étoilées, présent sur les pentes récifales.';

  @override
  String get species_black_sea_cucumber_name => 'Concombre de mer noir';

  @override
  String get species_black_sea_cucumber_desc =>
      'Concombre de mer noir commun sur les platiers sableux de tout l\'Indo-Pacifique.';

  @override
  String get species_leopard_sea_cucumber_name => 'Concombre de mer léopard';

  @override
  String get species_leopard_sea_cucumber_desc =>
      'Concombre de mer tacheté qui éjecte des tubules de Cuvier blancs et collants lorsqu\'on le dérange.';

  @override
  String get species_sand_dollar_name => 'Dollar des sables';

  @override
  String get species_sand_dollar_desc =>
      'Oursin plat en forme de disque, partiellement enfoui dans les fonds sableux.';

  @override
  String get species_moon_jellyfish_name => 'Méduse lune';

  @override
  String get species_moon_jellyfish_desc =>
      'Méduse translucide en forme de cloche dont les quatre gonades en fer à cheval sont visibles par transparence.';

  @override
  String get species_lions_mane_jellyfish_name => 'Méduse crinière de lion';

  @override
  String get species_lions_mane_jellyfish_desc =>
      'L\'une des plus grandes espèces de méduses, aux longs tentacules traînants, dans les eaux froides.';

  @override
  String get species_box_jellyfish_name => 'Méduse-boîte';

  @override
  String get species_box_jellyfish_desc =>
      'Méduse extrêmement dangereuse au venin puissant, présente dans les eaux tropicales indo-pacifiques.';

  @override
  String get species_upside_down_jellyfish_name => 'Méduse à l\'envers';

  @override
  String get species_upside_down_jellyfish_desc =>
      'Méduse insolite qui repose cloche vers le bas sur les fonds sableux pour permettre à ses algues de photosynthétiser.';

  @override
  String get species_blue_blubber_jellyfish_name => 'Méduse bleue d\'Australie';

  @override
  String get species_blue_blubber_jellyfish_desc =>
      'Méduse bleu et blanc à la cloche ferme et aux bras oraux frisés, commune dans les eaux australiennes.';

  @override
  String get species_fried_egg_jellyfish_name => 'Méduse oeuf au plat';

  @override
  String get species_fried_egg_jellyfish_desc =>
      'Méduse méditerranéenne au dôme jaune évoquant un oeuf au plat, à la piqûre légère.';

  @override
  String get species_pacific_sea_nettle_name => 'Ortie de mer du Pacifique';

  @override
  String get species_pacific_sea_nettle_desc =>
      'Méduse brun doré aux longs tentacules traînants, présente le long de la côte pacifique.';

  @override
  String get species_compass_jellyfish_name => 'Méduse boussole';

  @override
  String get species_compass_jellyfish_desc =>
      'Méduse brune et blanche aux marques en V rayonnant comme une rose des vents.';

  @override
  String get species_spotted_jellyfish_name => 'Méduse tachetée';

  @override
  String get species_spotted_jellyfish_desc =>
      'Méduse dorée à points blancs, célèbre pour remplir le lac aux méduses des Palaos.';

  @override
  String get species_barrel_jellyfish_name => 'Méduse poumon de mer';

  @override
  String get species_barrel_jellyfish_desc =>
      'Grande méduse en dôme aux bras oraux frisés et à la piqûre légère, commune dans l\'Atlantique.';

  @override
  String get species_persian_carpet_flatworm_name => 'Ver plat tapis persan';

  @override
  String get species_persian_carpet_flatworm_desc =>
      'Ver plat noir orné de marges jaune orangé, souvent confondu avec un nudibranche.';

  @override
  String get species_leopard_flatworm_name => 'Ver plat léopard';

  @override
  String get species_leopard_flatworm_desc =>
      'Ver plat translucide aux taches léopard, qui glisse sur les substrats du récif.';

  @override
  String get species_divided_flatworm_name => 'Ver plat divisé';

  @override
  String get species_divided_flatworm_desc =>
      'Ver plat noir et orange saisissant qui imite les nudibranches toxiques pour se protéger.';

  @override
  String get species_blue_pseudoceros_flatworm_name =>
      'Ver plat Pseudoceros bleu';

  @override
  String get species_blue_pseudoceros_flatworm_desc =>
      'Ver plat bleu profond à la marge orange, qui glisse sur les surfaces des récifs indo-pacifiques.';

  @override
  String get species_racing_stripe_flatworm_name =>
      'Ver plat à bande longitudinale';

  @override
  String get species_racing_stripe_flatworm_desc =>
      'Ver plat crème marqué d\'une nette bande centrale sombre et à la marge ondulée.';

  @override
  String get species_christmas_tree_worm_name => 'Ver arbre de Noël';

  @override
  String get species_christmas_tree_worm_desc =>
      'Ver coloré à la couronne spiralée, incrusté dans le corail, qui se rétracte instantanément à l\'approche.';

  @override
  String get species_feather_duster_worm_name => 'Ver plumeau';

  @override
  String get species_feather_duster_worm_desc =>
      'Ver tubicole dont la couronne de radioles plumeuses en éventail sert à filtrer l\'eau.';

  @override
  String get species_fire_worm_name => 'Ver de feu barbu';

  @override
  String get species_fire_worm_desc =>
      'Ver polychète aux soies urticantes blanches qui provoquent une irritation douloureuse au contact.';

  @override
  String get species_bobbit_worm_name => 'Ver Bobbit';

  @override
  String get species_bobbit_worm_desc =>
      'Prédateur embusqué caché dans le sable, dont les mâchoires puissantes frappent à la vitesse de l\'éclair.';

  @override
  String get species_social_feather_duster_name => 'Ver plumeau social';

  @override
  String get species_social_feather_duster_desc =>
      'Ver tubicole colonial formant des bouquets de délicates couronnes annelées sur les récifs des Caraïbes.';

  @override
  String get species_giant_clam_name => 'Bénitier géant';

  @override
  String get species_giant_clam_desc =>
      'Le plus grand bivalve vivant, dont le manteau irisé héberge des algues symbiotiques.';

  @override
  String get species_boring_clam_name => 'Bénitier perforant';

  @override
  String get species_boring_clam_desc =>
      'Petit bénitier coloré qui creuse la roche corallienne et ne laisse voir que son manteau éclatant.';

  @override
  String get species_maxima_clam_name => 'Bénitier maxima';

  @override
  String get species_maxima_clam_desc =>
      'Bénitier aux couleurs éclatantes, encastré dans la roche récifale, au manteau bleu et vert électrique.';

  @override
  String get species_flame_scallop_name => 'Peigne de feu';

  @override
  String get species_flame_scallop_desc =>
      'Bivalve rouge dont la bordure du manteau émet des éclairs de lumière blanche, présent dans les anfractuosités du récif.';

  @override
  String get species_thorny_oyster_name => 'Huître épineuse';

  @override
  String get species_thorny_oyster_desc =>
      'Bivalve à la coquille épineuse, cimenté à la roche récifale, souvent recouvert d\'éponges et d\'algues.';

  @override
  String get species_magnificent_sea_anemone_name => 'Anémone magnifique';

  @override
  String get species_magnificent_sea_anemone_desc =>
      'Grande anémone colorée qui héberge des poissons-clowns, à la colonne bien visible et aux tentacules flottants.';

  @override
  String get species_bubble_tip_anemone_name => 'Anémone à tentacules bulbeux';

  @override
  String get species_bubble_tip_anemone_desc =>
      'Hôte apprécié des poissons-clowns, aux tentacules à extrémité renflée, verte, brune ou rose.';

  @override
  String get species_giant_carpet_anemone_name => 'Anémone tapis géante';

  @override
  String get species_giant_carpet_anemone_desc =>
      'Anémone massive aux tentacules courts et collants, pouvant dépasser un mètre de diamètre.';

  @override
  String get species_haddon_carpet_anemone_name => 'Anémone tapis de Haddon';

  @override
  String get species_haddon_carpet_anemone_desc =>
      'Anémone tapis plate des fonds sableux, hôte de divers poissons-clowns et crabes porcelaine.';

  @override
  String get species_long_tentacle_anemone_name => 'Anémone à longs tentacules';

  @override
  String get species_long_tentacle_anemone_desc =>
      'Anémone des fonds sableux aux longs tentacules flottants, souvent hôte de poissons-clowns.';

  @override
  String get species_tube_anemone_name => 'Cérianthe';

  @override
  String get species_tube_anemone_desc =>
      'Élégante anémone qui vit dans un tube parcheminé enfoncé dans le sable, avec deux couronnes de tentacules.';

  @override
  String get species_hell_fire_anemone_name => 'Anémone feu de l\'enfer';

  @override
  String get species_hell_fire_anemone_desc =>
      'Anémone très urticante aux tentacules ramifiés qui évoquent un corail mou.';

  @override
  String get species_beaded_sea_anemone_name => 'Anémone perlée';

  @override
  String get species_beaded_sea_anemone_desc =>
      'Anémone aux extrémités de tentacules renflées en perles, présente sur les zones sableuses des récifs indo-pacifiques.';

  @override
  String get species_condylactis_anemone_name => 'Anémone géante des Caraïbes';

  @override
  String get species_condylactis_anemone_desc =>
      'Grande anémone des Caraïbes aux tentacules à pointe violette, présente sur les substrats rocheux du récif.';

  @override
  String get species_sand_anemone_name => 'Anémone des sables';

  @override
  String get species_sand_anemone_desc =>
      'Anémone délicate à demi enfouie dans le sable, aux tentacules à pointe violette.';

  @override
  String get species_barrel_sponge_name => 'Éponge barrique géante';

  @override
  String get species_barrel_sponge_desc =>
      'Éponge massive en forme de barrique qui peut vivre plusieurs siècles sur les tombants des Caraïbes.';

  @override
  String get species_azure_vase_sponge_name => 'Éponge vase azur';

  @override
  String get species_azure_vase_sponge_desc =>
      'Éponge en forme de vase d\'un bleu-violet éclatant, présente sur les tombants des Caraïbes.';

  @override
  String get species_yellow_tube_sponge_name => 'Éponge tube jaune';

  @override
  String get species_yellow_tube_sponge_desc =>
      'Éponge tubulaire jaune vif qui pousse en bouquets sur les tombants des Caraïbes.';

  @override
  String get species_elephant_ear_sponge_name => 'Éponge oreille d\'éléphant';

  @override
  String get species_elephant_ear_sponge_desc =>
      'Grande éponge orange en forme d\'éventail qui pousse sur les parois et sous les surplombs des Caraïbes.';

  @override
  String get species_rope_sponge_name => 'Éponge corde';

  @override
  String get species_rope_sponge_desc =>
      'Éponge rouge dressée et ramifiée qui pousse en formations cordées sur les récifs des Caraïbes.';

  @override
  String get species_portuguese_man_o_war_name => 'Galère portugaise';

  @override
  String get species_portuguese_man_o_war_desc =>
      'Colonie d\'hydrozoaires dotée d\'un flotteur rempli de gaz et de tentacules traînants extrêmement douloureux.';

  @override
  String get species_fire_coral_name => 'Corail de feu';

  @override
  String get species_fire_coral_desc =>
      'Ce n\'est pas un vrai corail mais un hydrozoaire, dont le contact inflige aux plongeurs des brûlures douloureuses.';

  @override
  String get species_by_the_wind_sailor_name => 'Vélelle';

  @override
  String get species_by_the_wind_sailor_desc =>
      'Colonie flottante d\'hydrozoaires bleue, munie d\'une voile diagonale qui capte le vent.';

  @override
  String get species_blue_button_name => 'Porpite bleue';

  @override
  String get species_blue_button_desc =>
      'Colonie flottante d\'hydrozoaires à disque plat, entourée d\'hydraires bleus en forme de tentacules.';

  @override
  String get species_giant_sea_hare_name => 'Lièvre de mer géant';

  @override
  String get species_giant_sea_hare_desc =>
      'L\'une des plus grandes limaces de mer, brun foncé à noire, présente dans les champs de laminaires.';

  @override
  String get species_sea_hare_name => 'Lièvre de mer tacheté';

  @override
  String get species_sea_hare_desc =>
      'Grand lièvre de mer aux taches vertes, qui libère une encre violette lorsqu\'on le dérange.';

  @override
  String get species_nudibranch_berghia_name => 'Nudibranche Berghia';

  @override
  String get species_nudibranch_berghia_desc =>
      'Nudibranche éolidien translucide aux cérates à pointe blanche, qui se nourrit d\'anémones.';

  @override
  String get species_sea_pen_name => 'Pennatule';

  @override
  String get species_sea_pen_desc =>
      'Octocorail colonial en forme de plume, ancré dans le sable, qui se rétracte quand on le dérange.';

  @override
  String get species_blue_sea_star_name => 'Étoile de mer bleue multicolore';

  @override
  String get species_blue_sea_star_desc =>
      'Étoile de mer aux couleurs variées qui se régénère à partir d\'un seul fragment de bras sur les récifs indo-pacifiques.';

  @override
  String get species_reef_squid_name => 'Calmar de récif';

  @override
  String get species_reef_squid_desc =>
      'Calmar de récif austral couramment rencontré dans les eaux tempérées australiennes.';

  @override
  String get species_tiger_shrimp_name => 'Crevette tigre';

  @override
  String get species_tiger_shrimp_desc =>
      'Grande crevette annelée présente sur les fonds sableux et dans les herbiers de l\'Indo-Pacifique.';

  @override
  String get species_candy_crab_name => 'Crabe bonbon';

  @override
  String get species_candy_crab_desc =>
      'Minuscule crabe coloré assorti à son corail mou hôte, aux expansions épineuses roses ou jaunes.';

  @override
  String get species_spider_crab_name => 'Crabe araignée décorateur';

  @override
  String get species_spider_crab_desc =>
      'Crabe au déplacement lent, recouvert d\'éponges et d\'algues fixées pour se camoufler.';

  @override
  String get species_anemone_shrimp_name => 'Crevette de l\'anémone magnifique';

  @override
  String get species_anemone_shrimp_desc =>
      'Crevette transparente aux marques blanches et violettes, qui vit parmi les tentacules des anémones.';

  @override
  String get species_snapping_shrimp_name => 'Crevette pistolet';

  @override
  String get species_snapping_shrimp_desc =>
      'Petite crevette qui produit un claquement sonore avec sa pince surdimensionnée, souvent associée à un gobie.';

  @override
  String get species_glass_sponge_name => 'Corbeille de Vénus';

  @override
  String get species_glass_sponge_desc =>
      'Délicate éponge de verre au squelette de silice complexe, présente en eau profonde.';

  @override
  String get species_toxic_sea_urchin_name => 'Oursin fleur';

  @override
  String get species_toxic_sea_urchin_desc =>
      'Oursin trompeusement joli, couvert de pédicellaires en forme de fleurs au venin puissant.';

  @override
  String get species_slate_pencil_urchin_name => 'Oursin crayon d\'ardoise';

  @override
  String get species_slate_pencil_urchin_desc =>
      'Oursin aux épines épaisses et arrondies, présent sur les substrats récifaux des Caraïbes et de l\'Atlantique.';

  @override
  String get species_spiny_sea_star_name => 'Étoile de mer épineuse';

  @override
  String get species_spiny_sea_star_desc =>
      'Grande étoile de mer tempérée aux épines proéminentes, présente dans les eaux européennes et atlantiques.';

  @override
  String get species_bat_star_name => 'Étoile chauve-souris';

  @override
  String get species_bat_star_desc =>
      'Étoile de mer du Pacifique aux bras palmés, orange, rouge ou violette, présente dans les forêts de laminaires.';

  @override
  String get species_sunflower_star_name => 'Étoile tournesol';

  @override
  String get species_sunflower_star_desc =>
      'Étoile de mer massive et rapide, pourvue de jusqu\'à 24 bras, présente dans les forêts de laminaires du Pacifique.';

  @override
  String get species_blood_star_name => 'Étoile de sang';

  @override
  String get species_blood_star_desc =>
      'Étoile de mer rouge orangé vif aux bras grêles, présente dans les eaux tempérées du Pacifique.';

  @override
  String get species_common_cuttlefish_name => 'Seiche commune';

  @override
  String get species_common_cuttlefish_desc =>
      'Maîtresse du camouflage présente dans les eaux européennes et méditerranéennes, aux pupilles en forme de W.';

  @override
  String get species_blue_spotted_crab_name => 'Crabe nageur à points bleus';

  @override
  String get species_blue_spotted_crab_desc =>
      'Crabe nageur actif portant des points bleus sur la carapace, présent sur les substrats sableux indo-pacifiques.';

  @override
  String get species_sponge_crab_name => 'Crabe éponge';

  @override
  String get species_sponge_crab_desc =>
      'Crabe qui découpe et transporte une éponge vivante sur son dos pour se camoufler.';

  @override
  String get species_horseshoe_crab_name => 'Limule';

  @override
  String get species_horseshoe_crab_desc =>
      'Arthropode chélicérate ancien à la carapace en forme de casque, présent sur les fonds sableux de l\'Atlantique.';

  @override
  String get species_sea_spider_name => 'Pycnogonide';

  @override
  String get species_sea_spider_desc =>
      'Délicat arthropode marin aux longues pattes, que l\'on voit ramper sur les hydraires et les bryozoaires.';

  @override
  String get species_sea_lily_name => 'Lis de mer';

  @override
  String get species_sea_lily_desc =>
      'Crinoïde pédonculé, fossile vivant des eaux profondes, qui filtre l\'eau avec ses bras plumeux.';

  @override
  String get species_mantis_shrimp_lysiosquilla_name => 'Squille harponneuse';

  @override
  String get species_mantis_shrimp_lysiosquilla_desc =>
      'Grande squille fouisseuse aux appendices harponneurs, présente sur les substrats sableux.';

  @override
  String get species_purple_sea_urchin_name => 'Oursin violet';

  @override
  String get species_purple_sea_urchin_desc =>
      'Oursin violet abondant dans les forêts de laminaires et les cuvettes rocheuses du Pacifique.';

  @override
  String get species_crown_jellyfish_name => 'Méduse couronne';

  @override
  String get species_crown_jellyfish_desc =>
      'Méduse violet foncé à l\'ombrelle surmontée d\'une couronne, présente dans l\'Indo-Pacifique.';

  @override
  String get species_comb_jelly_name => 'Groseille de mer';

  @override
  String get species_comb_jelly_desc =>
      'Petit cténophore bioluminescent aux rangées de peignes irisées et aux deux longs tentacules.';

  @override
  String get species_warty_sea_slug_name => 'Limace de mer verruqueuse';

  @override
  String get species_warty_sea_slug_desc =>
      'Nudibranche bleu et noir aux tubercules coiffés de jaune, couramment observé sur les récifs indo-pacifiques.';

  @override
  String get species_doris_nudibranch_name => 'Citron de mer';

  @override
  String get species_doris_nudibranch_desc =>
      'Doris jaune tacheté des eaux tempérées du Pacifique, qui se nourrit d\'éponges.';

  @override
  String get species_opalescent_nudibranch_name => 'Nudibranche opalescent';

  @override
  String get species_opalescent_nudibranch_desc =>
      'Éolidien translucide aux cérates orange vif et aux lignes dorsales bleues, dans les eaux du Pacifique.';

  @override
  String get species_clown_nudibranch_name => 'Nudibranche clown';

  @override
  String get species_clown_nudibranch_desc =>
      'Nudibranche rose orangé à points bleus et blancs, présent dans les eaux tempérées australiennes.';

  @override
  String get species_bottlenose_dolphin_name => 'Grand dauphin';

  @override
  String get species_bottlenose_dolphin_desc =>
      'Dauphin curieux et joueur, fréquemment rencontré par les plongeurs dans les eaux tropicales et tempérées.';

  @override
  String get species_spinner_dolphin_name => 'Dauphin à long bec';

  @override
  String get species_spinner_dolphin_desc =>
      'Dauphin acrobate connu pour ses vrilles aériennes, souvent observé en grands groupes près des récifs coralliens.';

  @override
  String get species_common_dolphin_name => 'Dauphin commun';

  @override
  String get species_common_dolphin_desc =>
      'Dauphin rapide au motif caractéristique en sablier, présent en haute mer et dans les eaux côtières.';

  @override
  String get species_spotted_dolphin_name => 'Dauphin tacheté de l\'Atlantique';

  @override
  String get species_spotted_dolphin_desc =>
      'Dauphin tacheté sociable qui s\'approche fréquemment des plongeurs aux Bahamas et dans les Caraïbes.';

  @override
  String get species_rissos_dolphin_name => 'Dauphin de Risso';

  @override
  String get species_rissos_dolphin_desc =>
      'Grand dauphin au corps gris fortement balafré, présent dans les eaux profondes du large du monde entier.';

  @override
  String get species_humpback_whale_name => 'Baleine à bosse';

  @override
  String get species_humpback_whale_desc =>
      'Baleine majestueuse connue pour ses sauts et ses chants complexes, observée lors des migrations saisonnières.';

  @override
  String get species_grey_whale_name => 'Baleine grise';

  @override
  String get species_grey_whale_desc =>
      'Baleine à fanons qui se nourrit sur le fond et migre le long de la côte pacifique, souvent couverte de balanes.';

  @override
  String get species_blue_whale_name => 'Baleine bleue';

  @override
  String get species_blue_whale_desc =>
      'Le plus grand animal ayant jamais vécu, parfois rencontré par les plongeurs en pleine eau bleue.';

  @override
  String get species_sperm_whale_name => 'Cachalot';

  @override
  String get species_sperm_whale_desc =>
      'Cétacé plongeur des grands fonds à l\'énorme tête, parfois vu au repos en surface entre deux plongées.';

  @override
  String get species_orca_name => 'Orque';

  @override
  String get species_orca_desc =>
      'Prédateur au sommet de la chaîne alimentaire, aux marques noires et blanches caractéristiques, présent dans tous les océans.';

  @override
  String get species_minke_whale_name => 'Petit rorqual';

  @override
  String get species_minke_whale_desc =>
      'Baleine à fanons de plus petite taille, curieuse envers les plongeurs, notamment sur la Grande Barrière de corail.';

  @override
  String get species_beluga_whale_name => 'Béluga';

  @override
  String get species_beluga_whale_desc =>
      'Baleine blanche de l\'Arctique connue pour ses vocalises et son comportement sociable dans les eaux froides.';

  @override
  String get species_pilot_whale_name => 'Globicéphale tropical';

  @override
  String get species_pilot_whale_desc =>
      'Cétacé social et grand plongeur, souvent observé en grands groupes dans les mers tropicales et tempérées chaudes.';

  @override
  String get species_false_killer_whale_name => 'Pseudorque';

  @override
  String get species_false_killer_whale_desc =>
      'Grand dauphin océanique qui s\'approche parfois des plongeurs en pleine eau.';

  @override
  String get species_dugong_name => 'Dugong';

  @override
  String get species_dugong_desc =>
      'Herbivore paisible qui broute les herbiers de l\'Indo-Pacifique, proche parent des lamantins.';

  @override
  String get species_west_indian_manatee_name => 'Lamantin des Caraïbes';

  @override
  String get species_west_indian_manatee_desc =>
      'Herbivore au déplacement lent, présent dans les eaux chaudes peu profondes, les estuaires et les sources des Caraïbes.';

  @override
  String get species_sea_otter_name => 'Loutre de mer';

  @override
  String get species_sea_otter_desc =>
      'Mammifère marin attachant, présent dans les forêts de laminaires de la côte du Pacifique Nord.';

  @override
  String get species_california_sea_lion_name => 'Otarie de Californie';

  @override
  String get species_california_sea_lion_desc =>
      'Pinnipède joueur et agile qui interagit souvent avec les plongeurs le long de la côte pacifique.';

  @override
  String get species_steller_sea_lion_name => 'Otarie de Steller';

  @override
  String get species_steller_sea_lion_desc =>
      'La plus grande espèce d\'otarie, présente dans les eaux froides du Pacifique Nord près des côtes rocheuses.';

  @override
  String get species_harbor_seal_name => 'Phoque commun';

  @override
  String get species_harbor_seal_desc =>
      'Phoque curieux couramment observé dans les eaux côtières tempérées, souvent au repos sur les rochers près des sites de plongée.';

  @override
  String get species_grey_seal_name => 'Phoque gris';

  @override
  String get species_grey_seal_desc =>
      'Grand phoque joueur de l\'Atlantique Nord, connu pour s\'approcher des plongeurs sous l\'eau.';

  @override
  String get species_northern_elephant_seal_name => 'Éléphant de mer du Nord';

  @override
  String get species_northern_elephant_seal_desc =>
      'Phoque massif et grand plongeur; les mâles portent une large trompe. Présent le long de la côte est du Pacifique.';

  @override
  String get species_hawaiian_monk_seal_name => 'Phoque moine de Hawaï';

  @override
  String get species_hawaiian_monk_seal_desc =>
      'Phoque en danger critique endémique de Hawaï, parfois observé par les plongeurs sur les récifs.';

  @override
  String get species_leopard_seal_name => 'Léopard de mer';

  @override
  String get species_leopard_seal_desc =>
      'Puissant prédateur antarctique au pelage tacheté, rencontré par les plongeurs en eau froide.';

  @override
  String get species_narwhal_name => 'Narval';

  @override
  String get species_narwhal_desc =>
      'Cétacé arctique doté d\'une longue défense en spirale, rarement observé mais emblématique parmi les mammifères marins.';

  @override
  String get species_green_sea_turtle_name => 'Tortue verte';

  @override
  String get species_green_sea_turtle_desc =>
      'Grande tortue marine couramment observée en train de brouter les herbiers dans les eaux tropicales.';

  @override
  String get species_hawksbill_sea_turtle_name => 'Tortue imbriquée';

  @override
  String get species_hawksbill_sea_turtle_desc =>
      'Tortue inféodée aux récifs, au bec pointu, qui se nourrit d\'éponges parmi les formations coralliennes.';

  @override
  String get species_loggerhead_sea_turtle_name => 'Tortue caouanne';

  @override
  String get species_loggerhead_sea_turtle_desc =>
      'Tortue à la grosse tête, présente dans les mers tempérées et tropicales, souvent près des récifs rocheux.';

  @override
  String get species_leatherback_sea_turtle_name => 'Tortue luth';

  @override
  String get species_leatherback_sea_turtle_desc =>
      'La plus grande tortue actuelle, à la carapace souple et coriace, capable de plonger à des profondeurs extrêmes.';

  @override
  String get species_olive_ridley_sea_turtle_name => 'Tortue olivâtre';

  @override
  String get species_olive_ridley_sea_turtle_desc =>
      'La plus petite espèce de tortue marine, connue pour ses pontes massives synchronisées appelées arribadas.';

  @override
  String get species_kemps_ridley_sea_turtle_name => 'Tortue de Kemp';

  @override
  String get species_kemps_ridley_sea_turtle_desc =>
      'Tortue marine en danger critique, présente principalement dans le golfe du Mexique.';

  @override
  String get species_flatback_sea_turtle_name => 'Tortue à dos plat';

  @override
  String get species_flatback_sea_turtle_desc =>
      'Endémique des eaux australiennes, reconnaissable à sa carapace plate et à son habitat côtier.';

  @override
  String get species_brain_coral_name => 'Corail cerveau';

  @override
  String get species_brain_coral_desc =>
      'Corail bâtisseur massif à la surface sillonnée évoquant un cerveau, commun sur les récifs des Caraïbes.';

  @override
  String get species_staghorn_coral_name => 'Corail corne de cerf';

  @override
  String get species_staghorn_coral_desc =>
      'Corail branchu à croissance rapide qui forme des fourrés denses, habitat essentiel pour les poissons de récif.';

  @override
  String get species_elkhorn_coral_name => 'Corail corne d\'élan';

  @override
  String get species_elkhorn_coral_desc =>
      'Grand corail branchu aux rameaux palmés et aplatis, bâtisseur clé des récifs des Caraïbes.';

  @override
  String get species_table_coral_name => 'Corail table';

  @override
  String get species_table_coral_desc =>
      'Corail formant de larges plateaux, présent sur les récifs indo-pacifiques, il abrite de nombreuses espèces de poissons.';

  @override
  String get species_mushroom_coral_name => 'Corail champignon';

  @override
  String get species_mushroom_coral_desc =>
      'Corail solitaire libre en forme de disque, présent sur les zones sableuses proches des récifs indo-pacifiques.';

  @override
  String get species_bubble_coral_name => 'Corail bulle';

  @override
  String get species_bubble_coral_desc =>
      'Corail caractéristique aux vésicules en grappe qui se gonflent le jour pour capter la lumière.';

  @override
  String get species_plate_coral_name => 'Corail plateau';

  @override
  String get species_plate_coral_desc =>
      'Corail en fines plaques formant des étagères enroulées, commun sur les pentes récifales indo-pacifiques.';

  @override
  String get species_pillar_coral_name => 'Corail pilier';

  @override
  String get species_pillar_coral_desc =>
      'Corail rare à croissance verticale formant de hautes colonnes, présent dans les Caraïbes.';

  @override
  String get species_star_coral_name => 'Corail étoilé';

  @override
  String get species_star_coral_desc =>
      'Bâtisseur majeur des récifs des Caraïbes, formant de grosses colonies en boule aux polypes étoilés.';

  @override
  String get species_lettuce_coral_name => 'Corail laitue';

  @override
  String get species_lettuce_coral_desc =>
      'Corail en fines plaques aux replis foliacés, commun sur les tombants et les pentes des Caraïbes.';

  @override
  String get species_finger_coral_name => 'Corail doigt';

  @override
  String get species_finger_coral_desc =>
      'Corail branchu robuste aux extensions épaisses en forme de doigts, présent sur les récifs peu profonds.';

  @override
  String get species_massive_porites_name => 'Corail Porites massif';

  @override
  String get species_massive_porites_desc =>
      'Gros corail en boule qui peut croître pendant des siècles, bâtisseur dominant des récifs indo-pacifiques.';

  @override
  String get species_cauliflower_coral_name => 'Corail chou-fleur';

  @override
  String get species_cauliflower_coral_desc =>
      'Corail branchu compact en forme de chou-fleur, répandu sur les récifs tropicaux peu profonds.';

  @override
  String get species_flower_pot_coral_name => 'Corail pot de fleurs';

  @override
  String get species_flower_pot_coral_desc =>
      'Colonie de polypes à longs tentacules qui se déploient le jour et évoquent un bouquet de fleurs.';

  @override
  String get species_cup_coral_name => 'Corail coupe orange';

  @override
  String get species_cup_coral_desc =>
      'Corail orange vif non photosynthétique, présent sur les parois et sous les surplombs des eaux tropicales.';

  @override
  String get species_scroll_coral_name => 'Corail volute';

  @override
  String get species_scroll_coral_desc =>
      'Corail formant de grandes plaques enroulées, commun sur les pentes récifales et dans les lagons indo-pacifiques.';

  @override
  String get species_cabbage_coral_name => 'Corail chou';

  @override
  String get species_cabbage_coral_desc =>
      'Corail en plaques discoïdes évoquant des feuilles de chou, présent dans les zones récifales abritées.';

  @override
  String get species_hammer_coral_name => 'Corail marteau';

  @override
  String get species_hammer_coral_desc =>
      'Corail à gros polypes dont les tentacules se terminent en ancre ou en marteau, apprécié sur les récifs indo-pacifiques.';

  @override
  String get species_torch_coral_name => 'Corail torche';

  @override
  String get species_torch_coral_desc =>
      'Corail branchu aux longs tentacules flottants terminés par des bulbes lumineux.';

  @override
  String get species_frogspawn_coral_name => 'Corail frai de grenouille';

  @override
  String get species_frogspawn_coral_desc =>
      'Corail à gros polypes dont les extrémités de tentacules ramifiées évoquent des oeufs de grenouille.';

  @override
  String get species_sea_fan_name => 'Gorgone éventail commune';

  @override
  String get species_sea_fan_desc =>
      'Gorgone plate en éventail orientée perpendiculairement aux courants, emblématique des récifs des Caraïbes.';

  @override
  String get species_venus_sea_fan_name => 'Gorgone éventail de Vénus';

  @override
  String get species_venus_sea_fan_desc =>
      'Délicate gorgone en éventail présente sur les récifs peu profonds des Caraïbes, dans les zones à courant modéré.';

  @override
  String get species_deepwater_sea_fan_name => 'Gorgone des eaux profondes';

  @override
  String get species_deepwater_sea_fan_desc =>
      'Grande gorgone buissonnante présente sur les tombants profonds des Caraïbes.';

  @override
  String get species_sea_whip_name => 'Gorgone fouet';

  @override
  String get species_sea_whip_desc =>
      'Gorgone élancée en forme de tige, que l\'on voit onduler dans le courant sur les récifs de l\'Atlantique et des Caraïbes.';

  @override
  String get species_sea_plume_name => 'Gorgone plumeuse';

  @override
  String get species_sea_plume_desc =>
      'Haute gorgone plumeuse formant des colonies en panache sur les sommets récifaux des Caraïbes.';

  @override
  String get species_organ_pipe_coral_name => 'Corail orgue';

  @override
  String get species_organ_pipe_coral_desc =>
      'Tubes squelettiques rouge vif garnis de polypes délicats, présents sur les récifs abrités indo-pacifiques.';

  @override
  String get species_leather_coral_name => 'Corail cuir';

  @override
  String get species_leather_coral_desc =>
      'Corail mou à la surface lisse et coriace, qui forme de grandes colonies en forme de champignon.';

  @override
  String get species_toadstool_leather_coral_name => 'Corail cuir champignon';

  @override
  String get species_toadstool_leather_coral_desc =>
      'Corail mou au pied épais et au chapeau plat, commun sur les platiers récifaux indo-pacifiques.';

  @override
  String get species_pulsing_xenia_name => 'Xénia pulsante';

  @override
  String get species_pulsing_xenia_desc =>
      'Corail mou aux polypes qui pulsent en rythme, présent dans les eaux abritées indo-pacifiques.';

  @override
  String get species_tree_coral_name => 'Corail arbre';

  @override
  String get species_tree_coral_desc =>
      'Corail mou éclatant formant des bouquets arborescents sur les parois et sous les surplombs de la mer Rouge.';

  @override
  String get species_blue_coral_name => 'Corail bleu';

  @override
  String get species_blue_coral_desc =>
      'Octocorail singulier au squelette bleu, présent sur les platiers récifaux peu profonds indo-pacifiques.';

  @override
  String get species_black_coral_name => 'Corail noir';

  @override
  String get species_black_coral_desc =>
      'Corail d\'eau profonde au squelette sombre, présent sur les parois et les tombants au-delà de 30 mètres.';

  @override
  String get species_carnation_coral_name => 'Corail oeillet';

  @override
  String get species_carnation_coral_desc =>
      'Corail mou aux couleurs vives, présent sous les surplombs et sur les parois de l\'Indo-Pacifique.';

  @override
  String get species_wire_coral_name => 'Corail fil de fer';

  @override
  String get species_wire_coral_desc =>
      'Long corail noir en spirale formant des fouets enroulés, hôte de gobies et de crevettes.';

  @override
  String get species_dead_mans_fingers_name => 'Doigts de mort';

  @override
  String get species_dead_mans_fingers_desc =>
      'Corail mou charnu aux lobes en forme de doigts, commun sur les récifs tempérés de l\'Atlantique Nord.';

  @override
  String get species_sun_coral_name => 'Corail soleil';

  @override
  String get species_sun_coral_desc =>
      'Corail jaune orangé non photosynthétique qui ouvre ses polypes la nuit sur les parois indo-pacifiques.';

  @override
  String get species_lace_coral_name => 'Corail dentelle';

  @override
  String get species_lace_coral_desc =>
      'Délicat hydrocorail rose aux ramifications en dentelle, présent dans les anfractuosités et sous les surplombs.';

  @override
  String get species_kenya_tree_coral_name => 'Corail arbre du Kenya';

  @override
  String get species_kenya_tree_coral_desc =>
      'Corail mou robuste aux ramifications arborescentes, commun dans l\'Indo-Pacifique.';

  @override
  String get species_colt_coral_name => 'Corail colt';

  @override
  String get species_colt_coral_desc =>
      'Corail mou aux branches épaisses et caoutchouteuses couvertes de petits polypes, sur les récifs indo-pacifiques.';

  @override
  String get species_turtle_grass_name => 'Herbe à tortue';

  @override
  String get species_turtle_grass_desc =>
      'Herbier dominant des Caraïbes aux larges feuilles plates, ressource alimentaire vitale pour les tortues marines.';

  @override
  String get species_eelgrass_name => 'Zostère marine';

  @override
  String get species_eelgrass_desc =>
      'Herbier tempéré formant de denses prairies sous-marines qui servent de nurserie.';

  @override
  String get species_manatee_grass_name => 'Herbe à lamantin';

  @override
  String get species_manatee_grass_desc =>
      'Herbier aux feuilles cylindriques présent sur les zones sableuses des Caraïbes, souvent près des herbiers à tortue.';

  @override
  String get species_shoal_grass_name => 'Herbe des bancs';

  @override
  String get species_shoal_grass_desc =>
      'Herbier pionnier aux feuilles étroites, qui colonise les zones sableuses perturbées des Caraïbes.';

  @override
  String get species_paddle_grass_name => 'Herbe pagaie';

  @override
  String get species_paddle_grass_desc =>
      'Petit herbier délicat aux feuilles ovales, présent en eau plus profonde sous les tropiques.';

  @override
  String get species_neptune_grass_name => 'Posidonie';

  @override
  String get species_neptune_grass_desc =>
      'Herbier méditerranéen formant de vastes prairies essentielles aux écosystèmes marins côtiers.';

  @override
  String get species_giant_kelp_name => 'Laminaire géante';

  @override
  String get species_giant_kelp_desc =>
      'Espèce formant d\'immenses forêts sous-marines, jusqu\'à 60 mètres de haut, emblématique de la plongée en Californie.';

  @override
  String get species_bull_kelp_name => 'Laminaire à bulbe';

  @override
  String get species_bull_kelp_desc =>
      'Laminaire du Pacifique à long stipe unique et à flotteur bulbeux, qui forme des canopées forestières denses.';

  @override
  String get species_bladder_wrack_name => 'Fucus vésiculeux';

  @override
  String get species_bladder_wrack_desc =>
      'Algue brune commune aux vésicules d\'air appariées, présente dans les zones intertidales de l\'Atlantique Nord.';

  @override
  String get species_sargassum_name => 'Sargasse';

  @override
  String get species_sargassum_desc =>
      'Algue brune flottante formant des radeaux qui abritent poissons juvéniles et invertébrés.';

  @override
  String get species_kelp_forest_ecklonia_name => 'Laminaire Ecklonia';

  @override
  String get species_kelp_forest_ecklonia_desc =>
      'Laminaire dominante des eaux de l\'hémisphère sud, qui forme d\'importantes forêts sous-marines.';

  @override
  String get species_coralline_algae_name => 'Algues corallines';

  @override
  String get species_coralline_algae_desc =>
      'Algue rouge encroûtante et dure qui cimente les structures récifales et donne aux récifs leur teinte rosée.';

  @override
  String get species_irish_moss_name => 'Mousse d\'Irlande';

  @override
  String get species_irish_moss_desc =>
      'Algue rouge en éventail présente sur les rivages rocheux de la zone intertidale de l\'Atlantique Nord.';

  @override
  String get species_dulse_name => 'Dulse';

  @override
  String get species_dulse_desc =>
      'Algue plate rouge violacé qui pousse sur les roches et les stipes de laminaires des eaux froides du nord.';

  @override
  String get species_halimeda_name => 'Halimeda';

  @override
  String get species_halimeda_desc =>
      'Algue verte calcifiée aux segments en forme de disques, contributrice majeure au sable des récifs.';

  @override
  String get species_sea_lettuce_name => 'Laitue de mer';

  @override
  String get species_sea_lettuce_desc =>
      'Algue vert vif en lames minces, présente dans les eaux côtières peu profondes du monde entier.';

  @override
  String get species_caulerpa_name => 'Raisin de mer';

  @override
  String get species_caulerpa_desc =>
      'Algue verte rampante aux frondes en grappes de raisin, présente sur les débris coralliens et le sable des récifs tropicaux.';

  @override
  String get species_mermaid_fan_name => 'Éventail de sirène';

  @override
  String get species_mermaid_fan_desc =>
      'Algue verte calcifiée en forme de petit éventail, commune sur les fonds sableux des Caraïbes.';

  @override
  String get species_shaving_brush_algae_name => 'Algue blaireau';

  @override
  String get species_shaving_brush_algae_desc =>
      'Algue verte calcifiée formant une touffe en blaireau au sommet d\'un pédoncule, présente sur les fonds sableux des Caraïbes.';

  @override
  String get species_finger_kelp_name => 'Laminaire digitée';

  @override
  String get species_finger_kelp_desc =>
      'Algue brune aux frondes digitées qui forme des champs de laminaires dans les eaux côtières de l\'Atlantique Nord.';

  @override
  String get species_banded_sea_krait_name => 'Tricot rayé';

  @override
  String get species_banded_sea_krait_desc =>
      'Serpent marin venimeux aux anneaux gris-bleu et noirs, placide et couramment observé sur les récifs indo-pacifiques.';

  @override
  String get species_olive_sea_snake_name => 'Serpent marin olive';

  @override
  String get species_olive_sea_snake_desc =>
      'Serpent marin curieux des récifs australiens, connu pour s\'approcher des plongeurs.';

  @override
  String get species_yellow_bellied_sea_snake_name =>
      'Serpent marin à ventre jaune';

  @override
  String get species_yellow_bellied_sea_snake_desc =>
      'Serpent marin pélagique au ventre jaune, l\'espèce de serpent la plus répandue de la planète.';

  @override
  String get species_marine_iguana_name => 'Iguane marin';

  @override
  String get species_marine_iguana_desc =>
      'Endémique des Galapagos, le seul lézard qui broute des algues sous l\'eau.';

  @override
  String get species_saltwater_crocodile_name => 'Crocodile marin';

  @override
  String get species_saltwater_crocodile_desc =>
      'Le plus grand reptile actuel, présent dans les eaux côtières et les estuaires de l\'Indo-Pacifique.';

  @override
  String get common_action_done => 'Terminé';

  @override
  String get common_action_more => 'Plus';

  @override
  String get common_label_displayName => 'Nom affiché';

  @override
  String common_relativeTime_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a ${count}j',
      one: 'il y a ${count}j',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a ${count}h',
      one: 'il y a ${count}h',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans ${count}j',
      one: 'dans ${count}j',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans ${count}h',
      one: 'dans ${count}h',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_inLessThanMinute => 'dans <1m';

  @override
  String common_relativeTime_inMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans ${count}m',
      one: 'dans ${count}m',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_justNow => 'à l’instant';

  @override
  String common_relativeTime_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a ${count}m',
      one: 'il y a ${count}m',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a ${count}mois',
      one: 'il y a ${count}mois',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_overdue => 'en retard';

  @override
  String get media_cache_calculating => 'Calcul de la taille du cache…';

  @override
  String get media_cache_cardTitle => 'Gestion du cache';

  @override
  String get media_cache_clearAction => 'Vider le cache';

  @override
  String get media_cache_clearBody =>
      'Supprime les miniatures et les images réseau en pleine taille téléchargées. Les médias liés sont conservés ; les images seront de nouveau téléchargées à la prochaine consultation.';

  @override
  String get media_cache_clearConfirm => 'Vider';

  @override
  String media_cache_clearError(String error) {
    return 'Échec du vidage : $error';
  }

  @override
  String get media_cache_clearTitle => 'Vider le cache des images réseau ?';

  @override
  String get media_cache_cleared => 'Cache vidé';

  @override
  String get media_cache_diskCache => 'Cache disque';

  @override
  String media_cache_error(String error) {
    return 'Erreur : $error';
  }

  @override
  String get media_credentials_actionTest => 'Tester les identifiants';

  @override
  String media_credentials_authLabel(String authType) {
    return 'Auth : $authType';
  }

  @override
  String get media_credentials_deleteBody =>
      'Supprime les identifiants enregistrés. Les éléments liés via cet hôte afficheront « Connectez-vous pour voir » jusqu’à ce que vous les rajoutiez.';

  @override
  String media_credentials_deleteError(String error) {
    return 'Échec de la suppression : $error';
  }

  @override
  String media_credentials_deleteTitle(String host) {
    return 'Supprimer $host ?';
  }

  @override
  String media_credentials_deleted(String host) {
    return '$host supprimé';
  }

  @override
  String media_credentials_editTitle(String host) {
    return 'Modifier $host';
  }

  @override
  String get media_credentials_emptySubtitle =>
      'Les identifiants par hôte ajoutés lors des imports d’URL ou de manifeste apparaissent ici.';

  @override
  String get media_credentials_emptyTitle => 'Aucun identifiant enregistré';

  @override
  String media_credentials_lastUsed(String when) {
    return 'Dernière utilisation $when';
  }

  @override
  String get media_credentials_loadError =>
      'Impossible de charger les hôtes enregistrés';

  @override
  String get media_credentials_loading => 'Chargement des hôtes enregistrés...';

  @override
  String media_credentials_saveError(String error) {
    return 'Échec de l’enregistrement : $error';
  }

  @override
  String get media_credentials_savedHostsTitle => 'Hôtes enregistrés';

  @override
  String media_credentials_testError(String error) {
    return 'Échec du test : $error';
  }

  @override
  String media_credentials_testFailed(String host) {
    return 'Identifiants refusés pour $host';
  }

  @override
  String media_credentials_testOk(String host) {
    return 'Identifiants valides pour $host';
  }

  @override
  String get media_manifest_actionPollNow => 'Interroger maintenant';

  @override
  String get media_manifest_cardTitle => 'Abonnements aux manifestes';

  @override
  String get media_manifest_deleteBody =>
      'Supprime l’abonnement. Les entrées déjà importées sont conservées (vous pouvez les nettoyer via la file des orphelins).';

  @override
  String media_manifest_deleteError(String error) {
    return 'Échec de la suppression : $error';
  }

  @override
  String media_manifest_deleteTitle(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get media_manifest_editTitle => 'Modifier l’abonnement';

  @override
  String get media_manifest_emptySubtitle =>
      'Abonnez-vous à un manifeste Atom/RSS, JSON ou CSV depuis l’onglet URL pour garder votre photothèque synchronisée.';

  @override
  String get media_manifest_emptyTitle => 'Aucun abonnement aux manifestes';

  @override
  String media_manifest_lastError(String error) {
    return 'Dernière erreur : $error';
  }

  @override
  String media_manifest_lastPolled(String when) {
    return 'Dernière interrogation $when';
  }

  @override
  String get media_manifest_loadError =>
      'Impossible de charger les abonnements';

  @override
  String get media_manifest_loading => 'Chargement des abonnements...';

  @override
  String get media_manifest_neverPolled => 'Jamais interrogé';

  @override
  String media_manifest_nextPoll(String when) {
    return 'Prochaine $when';
  }

  @override
  String get media_manifest_notFound => 'Abonnement introuvable';

  @override
  String media_manifest_pollError(String error) {
    return 'Échec de l’interrogation : $error';
  }

  @override
  String media_manifest_polled(String name) {
    return '$name interrogé';
  }

  @override
  String media_manifest_polling(String name) {
    return 'Interrogation de $name...';
  }

  @override
  String media_manifest_saveError(String error) {
    return 'Échec de l’enregistrement : $error';
  }

  @override
  String media_manifest_updateError(String error) {
    return 'Mise à jour impossible : $error';
  }

  @override
  String get media_manifest_urlLabel => 'URL du manifeste';

  @override
  String media_scan_failed(String error) {
    return 'Échec de l’analyse : $error';
  }

  @override
  String media_scan_progressItems(int done, int total) {
    return '$done / $total éléments';
  }

  @override
  String media_scan_progressReachability(int available, int unreachable) {
    return '$available accessibles  ·  $unreachable inaccessibles';
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
          '$total éléments analysés en ${seconds}s : $available accessibles, $unreachable inaccessibles',
      one:
          '$total élément analysé en ${seconds}s : $available accessible, $unreachable inaccessible',
    );
    return '$_temp0';
  }

  @override
  String media_scan_summarySkipped(String base, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ignorés (pas d’URL)',
      one: '$count ignoré (pas d’URL)',
    );
    return '$base, $_temp0';
  }

  @override
  String get media_scan_title => 'Analyser tous les médias réseau';

  @override
  String get settings_mediaSources_androidUriTitle =>
      'Autorisations d’URI Android';

  @override
  String settings_mediaSources_androidUriUsage(int used, int limit) {
    return '$used / $limit URI persistants utilisés';
  }

  @override
  String get settings_mediaSources_counting => 'Comptage…';

  @override
  String settings_mediaSources_error(String error) {
    return 'Erreur : $error';
  }

  @override
  String get settings_mediaSources_loading => 'Chargement…';

  @override
  String settings_mediaSources_localFilesCounts(
    int available,
    int unavailable,
  ) {
    return '$available disponibles, $unavailable indisponibles';
  }

  @override
  String get settings_mediaSources_photoLibrarySubtitle =>
      'Apple Photos / Google Photos / iCloud';

  @override
  String get settings_mediaSources_reverifyAll =>
      'Revérifier tous les fichiers locaux';

  @override
  String settings_mediaSources_reverifyFailed(String error) {
    return 'Échec de la revérification : $error';
  }

  @override
  String settings_mediaSources_reverifyResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments mis à jour',
      one: '$count élément mis à jour',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_checkAll => 'Vérifier tous les médias';

  @override
  String settings_mediaSources_checkAllResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments mis à jour',
      one: '$count élément mis à jour',
    );
    return '$_temp0';
  }

  @override
  String settings_mediaSources_checkAllBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Impossible de vérifier les $count éléments. Leurs sources sont actuellement inaccessibles.',
      one:
          'Impossible de vérifier cet élément. Sa source est actuellement inaccessible.',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_title => 'Sources de médias';

  @override
  String get settings_networkSources_scanDescription =>
      'Revérifie auprès de son hôte chaque photo importée par URL ou par manifeste. Marque les éléments inaccessibles afin qu’ils apparaissent comme « manquants » dans votre photothèque et puissent être nettoyés.';

  @override
  String statistics_conditions_entryMethod_semanticLabel(String description) {
    return 'Diagramme en barres. Méthodes d’entrée. $description';
  }

  @override
  String statistics_conditions_visibility_semanticLabel(String description) {
    return 'Diagramme circulaire. Distribution de la visibilité. $description';
  }

  @override
  String statistics_conditions_waterType_semanticLabel(String description) {
    return 'Diagramme circulaire. Distribution des types d’eau. $description';
  }

  @override
  String statistics_progression_divesBySuitThickness_semanticLabel(
    String description,
  ) {
    return 'Diagramme en barres. Plongées par épaisseur de combinaison. $description';
  }

  @override
  String statistics_progression_divesPerYear_countInYear(
    int count,
    String year,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongées en $year',
      one: '1 plongée en $year',
    );
    return '$_temp0';
  }

  @override
  String statistics_progression_divesPerYear_semanticLabel(String description) {
    return 'Diagramme en barres. Plongées par an. $description';
  }

  @override
  String get statistics_records_unavailable => 'Records indisponibles';

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
  String get statistics_summary_distributions_title => 'Distributions';

  @override
  String get statistics_summary_diveTypes_error =>
      'Impossible de charger les données de types de plongée';

  @override
  String get statistics_summary_diveTypes_unknown => 'Inconnu';

  @override
  String get statistics_summary_divesPerMonth => 'Plongées / mois';

  @override
  String get statistics_summary_divesPerYear => 'Plongées / an';

  @override
  String statistics_timePatterns_dayOfWeek_semanticLabel(String description) {
    return 'Diagramme en barres. Plongées par jour de la semaine. $description';
  }

  @override
  String statistics_timePatterns_seasonal_semanticLabel(String description) {
    return 'Diagramme en barres. Plongées par mois. $description';
  }

  @override
  String statistics_timePatterns_surfaceInterval_statLabel(
    String label,
    String value,
  ) {
    return 'Intervalle de surface $label : $value';
  }

  @override
  String get statistics_timePatterns_timeOfDay_afternoon => 'Après-midi';

  @override
  String get statistics_timePatterns_timeOfDay_evening => 'Soir';

  @override
  String get statistics_timePatterns_timeOfDay_morning => 'Matin';

  @override
  String get statistics_timePatterns_timeOfDay_night => 'Nuit';

  @override
  String statistics_timePatterns_timeOfDay_semanticLabel(String description) {
    return 'Diagramme circulaire. Plongées par moment de la journée. $description';
  }

  @override
  String get columnConfig_displayOptions => 'Options d’affichage';

  @override
  String get columnConfig_noExtraFields =>
      'Aucun champ supplémentaire configuré. Ajoutez des champs ci-dessous.';

  @override
  String get columnConfig_savePresetTitle => 'Enregistrer le préréglage';

  @override
  String get columnConfig_section => 'Section';

  @override
  String get columnConfig_showTags => 'Afficher les tags';

  @override
  String get columnConfig_showTags_subtitle =>
      'Afficher les tags sur les fiches de plongée détaillées';

  @override
  String get columnConfig_slot_date => 'Date / Sous-titre';

  @override
  String get columnConfig_slot_slot1 => 'Emplacement 1';

  @override
  String get columnConfig_slot_slot2 => 'Emplacement 2';

  @override
  String get columnConfig_slot_slot3 => 'Emplacement 3';

  @override
  String get columnConfig_slot_slot4 => 'Emplacement 4';

  @override
  String get columnConfig_slot_stat1 => 'Statistique 1';

  @override
  String get columnConfig_slot_stat2 => 'Statistique 2';

  @override
  String get columnConfig_slot_subtitle => 'Sous-titre';

  @override
  String get columnConfig_slot_title => 'Titre';

  @override
  String get columnConfig_tooltip_columnSettings => 'Réglages des colonnes';

  @override
  String get common_action_add => 'Ajouter';

  @override
  String get common_action_pin => 'Épingler';

  @override
  String get common_action_remove => 'Retirer';

  @override
  String get common_action_unpin => 'Désépingler';

  @override
  String diveLog_filterChip_dateRange(String end, String start) {
    return '$start - $end';
  }

  @override
  String diveLog_filterChip_equipmentCount(int count) {
    return '$count équipements';
  }

  @override
  String get diveLog_filter_allComputers => 'Tous les ordinateurs';

  @override
  String get diveLog_filter_noComputersRegistered =>
      'Aucun ordinateur de plongée enregistré';

  @override
  String diveLog_filter_sectionDepthRangeUnit(String unit) {
    return 'Plage de profondeur ($unit)';
  }

  @override
  String get diveLog_filter_sectionDiveComputer => 'Ordinateur de plongée';

  @override
  String diveLog_listPage_semanticsDiveAtSite(int diveNumber, String siteName) {
    return 'Plongée $diveNumber sur $siteName';
  }

  @override
  String get enum_listViewMode_compact => 'Compact';

  @override
  String get enum_listViewMode_dense => 'Dense';

  @override
  String get enum_listViewMode_detailed => 'Détaillé';

  @override
  String get enum_listViewMode_table => 'Tableau';

  @override
  String get enum_profileMetric_ascentRate => 'Vitesse de remontée';

  @override
  String get enum_profileMetric_cns => 'CNS %';

  @override
  String get enum_profileMetric_otu => 'OTU';

  @override
  String get enum_sortField_bottomTime => 'Temps au fond';

  @override
  String get enum_sortField_serviceDue => 'Révision due';

  @override
  String get listViewMode_tooltip => 'Mode d’affichage';

  @override
  String marineLife_speciesManage_errorLoading(Object error) {
    return 'Erreur lors du chargement des espèces : $error';
  }

  @override
  String get settings_appearance_header_cards => 'Fiches';

  @override
  String get settings_appearance_header_listView => 'Vue liste';

  @override
  String get settings_appearance_header_tableMode => 'Mode tableau';

  @override
  String get settings_appearance_listFields_buddies =>
      'Champs de la liste des binômes';

  @override
  String get settings_appearance_listFields_certifications =>
      'Champs de la liste des certifications';

  @override
  String get settings_appearance_listFields_courses =>
      'Champs de la liste des cours';

  @override
  String get settings_appearance_listFields_diveCenters =>
      'Champs de la liste des centres de plongée';

  @override
  String get settings_appearance_listFields_dives =>
      'Champs de la liste des plongées';

  @override
  String get settings_appearance_listFields_equipment =>
      'Champs de la liste de l’équipement';

  @override
  String get settings_appearance_listFields_sites =>
      'Champs de la liste des sites';

  @override
  String get settings_appearance_listFields_subtitle =>
      'Personnaliser les champs affichés dans les vues liste';

  @override
  String get settings_appearance_listFields_trips =>
      'Champs de la liste des voyages';

  @override
  String get settings_appearance_listView_buddies => 'Vue liste des binômes';

  @override
  String get settings_appearance_listView_buddies_subtitle =>
      'Disposition par défaut de la liste des binômes';

  @override
  String get settings_appearance_listView_certifications =>
      'Vue liste des certifications';

  @override
  String get settings_appearance_listView_certifications_subtitle =>
      'Disposition par défaut de la liste des certifications';

  @override
  String get settings_appearance_listView_courses => 'Vue liste des cours';

  @override
  String get settings_appearance_listView_courses_subtitle =>
      'Disposition par défaut de la liste des cours';

  @override
  String get settings_appearance_listView_diveCenters =>
      'Vue liste des centres de plongée';

  @override
  String get settings_appearance_listView_diveCenters_subtitle =>
      'Disposition par défaut de la liste des centres de plongée';

  @override
  String get settings_appearance_listView_dives => 'Vue liste des plongées';

  @override
  String get settings_appearance_listView_dives_subtitle =>
      'Disposition par défaut de la liste des plongées';

  @override
  String get settings_appearance_listView_equipment =>
      'Vue liste de l’équipement';

  @override
  String get settings_appearance_listView_equipment_subtitle =>
      'Disposition par défaut de la liste de l’équipement';

  @override
  String get settings_appearance_listView_sites => 'Vue liste des sites';

  @override
  String get settings_appearance_listView_sites_subtitle =>
      'Disposition par défaut de la liste des sites';

  @override
  String get settings_appearance_listView_trips => 'Vue liste des voyages';

  @override
  String get settings_appearance_listView_trips_subtitle =>
      'Disposition par défaut de la liste des voyages';

  @override
  String get settings_appearance_showDataSourceBadges =>
      'Afficher les badges de source des données';

  @override
  String get settings_appearance_showDataSourceBadges_subtitle =>
      'Afficher l’origine des données sur les mesures de plongée';

  @override
  String get settings_appearance_title_buddies => 'Apparence des binômes';

  @override
  String get settings_appearance_title_certifications =>
      'Apparence des certifications';

  @override
  String get settings_appearance_title_courses => 'Apparence des cours';

  @override
  String get settings_appearance_title_diveCenters =>
      'Apparence des centres de plongée';

  @override
  String get settings_appearance_title_dives => 'Apparence des plongées';

  @override
  String get settings_appearance_title_equipment => 'Apparence de l’équipement';

  @override
  String get settings_appearance_title_sites => 'Apparence des sites';

  @override
  String get settings_appearance_title_trips => 'Apparence des voyages';

  @override
  String get settings_cloudSync_troubleshoot_tileSubtitle =>
      'Réparer une synchronisation bloquée ou libérer de l’espace dans le cloud';

  @override
  String get settings_data_header_dataTools => 'Outils de données';

  @override
  String get settings_decompression_ascentGasLabel =>
      'Planifier la remontée avec';

  @override
  String get settings_decompression_ascentGas_allCarried =>
      'Tous les blocs emportés';

  @override
  String get settings_decompression_ascentGas_decoStage =>
      'Bloc déco/relais + gaz dorsal';

  @override
  String get settings_decompression_cnsSource => 'Source CNS';

  @override
  String get settings_decompression_decoStopSource =>
      'Source des paliers de décompression';

  @override
  String get settings_decompression_header_ascent =>
      'Planification de la remontée';

  @override
  String get settings_decompression_header_ascent_subtitle =>
      'Les blocs emportés vers lesquels la remontée simulée (TTS, plafond et paliers) peut basculer à chaque profondeur. Seuls les gaz enregistrés sur la plongée sont pris en compte.';

  @override
  String get settings_decompression_header_dataSources =>
      'Préférences de source des données';

  @override
  String get settings_decompression_header_dataSources_subtitle =>
      'Réglée sur Ordinateur de plongée, l’application utilise les données rapportées par l’ordinateur de plongée lorsqu’elles sont disponibles. À défaut, elle utilise les valeurs calculées.';

  @override
  String get settings_decompression_ndlSource => 'Source NDL';

  @override
  String get settings_decompression_sourceCalculated => 'Calculé';

  @override
  String get settings_decompression_sourceComputer => 'Ordinateur de plongée';

  @override
  String get settings_decompression_ttsSource => 'Source TTS';

  @override
  String settings_fixDiveTimes_applied(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongées mises à jour',
      one: 'plongée mise à jour',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'heures',
      one: 'heure',
    );
    return '$count $_temp0 de $hours $_temp1.';
  }

  @override
  String settings_fixDiveTimes_apply(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongées',
      one: 'plongée',
    );
    return 'Appliquer à $count $_temp0';
  }

  @override
  String get settings_fixDiveTimes_clearRange => 'Effacer la plage de dates';

  @override
  String get settings_fixDiveTimes_confirmApply => 'Appliquer';

  @override
  String settings_fixDiveTimes_confirmBody(
    int count,
    String hours,
    int hoursAbs,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongées',
      one: 'plongée',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'heures',
      one: 'heure',
    );
    return 'Cette action décalera $count $_temp0 de $hours $_temp1. Elle ne peut pas être annulée automatiquement.';
  }

  @override
  String get settings_fixDiveTimes_confirmTitle =>
      'Appliquer le décalage horaire';

  @override
  String get settings_fixDiveTimes_dateRangeFilter =>
      'Filtre de plage de dates';

  @override
  String get settings_fixDiveTimes_deselectAll => 'Tout désélectionner';

  @override
  String get settings_fixDiveTimes_diveFallback => 'Plongée';

  @override
  String settings_fixDiveTimes_diveNumber(int number) {
    return 'Plongée n° $number';
  }

  @override
  String get settings_fixDiveTimes_empty => 'Aucune plongée trouvée.';

  @override
  String get settings_fixDiveTimes_emptyFiltered =>
      'Aucune plongée trouvée dans cette plage de dates.';

  @override
  String get settings_fixDiveTimes_enterOffsetHint =>
      'Saisissez un décalage en heures';

  @override
  String get settings_fixDiveTimes_from => 'Du';

  @override
  String get settings_fixDiveTimes_hourOffset => 'Décalage horaire';

  @override
  String get settings_fixDiveTimes_hoursField => 'Heures (ex. +7, -5)';

  @override
  String settings_fixDiveTimes_loadError(String error) {
    return 'Échec du chargement des plongées : $error';
  }

  @override
  String get settings_fixDiveTimes_noSelection =>
      'Aucune plongée sélectionnée.';

  @override
  String get settings_fixDiveTimes_offsetHint =>
      'Saisissez un entier positif ou négatif pour décaler les heures de plongée.';

  @override
  String settings_fixDiveTimes_preview(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'plongées seront décalées',
      one: 'plongée sera décalée',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'heures',
      one: 'heure',
    );
    return 'Aperçu : $count $_temp0 de $hours $_temp1.';
  }

  @override
  String get settings_fixDiveTimes_selectAll => 'Tout sélectionner';

  @override
  String get settings_fixDiveTimes_selectDivesHint =>
      'Sélectionnez les plongées à modifier';

  @override
  String get settings_fixDiveTimes_subtitle =>
      'Ajuster les heures des plongées importées';

  @override
  String get settings_fixDiveTimes_title => 'Corriger les heures de plongée';

  @override
  String get settings_fixDiveTimes_to => 'Au';

  @override
  String get settings_fixDiveTimes_zeroOffset =>
      'Le décalage horaire est de 0, il n’y a rien à modifier.';

  @override
  String get settings_syncDevices_appBar_refreshTooltip => 'Actualiser';

  @override
  String get settings_syncDevices_appBar_title => 'Appareils sur ce service';

  @override
  String get settings_syncDevices_empty =>
      'Aucun fichier de synchronisation sur ce service.';

  @override
  String settings_syncDevices_readError(String error) {
    return 'Impossible de lire le service.\n$error';
  }

  @override
  String get settings_syncDevices_removal_noBackend =>
      'Aucun service cloud n’est configuré';

  @override
  String get settings_syncDevices_removal_unreachable =>
      'Impossible de joindre le service. Rien n’a été supprimé.';

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
          'Cette action supprime $count fichiers ($size) appartenant à $name.\n\nCet appareil fait toujours partie de cette synchronisation. S’il revient en ligne, il se reconstruira à partir du service au lieu de ressusciter d’anciennes données, mais toutes les modifications qu’il n’a pas encore publiées seront perdues. Vos données de plongée sur CET appareil ne sont pas affectées.',
      one:
          'Cette action supprime 1 fichier ($size) appartenant à $name.\n\nCet appareil fait toujours partie de cette synchronisation. S’il revient en ligne, il se reconstruira à partir du service au lieu de ressusciter d’anciennes données, mais toutes les modifications qu’il n’a pas encore publiées seront perdues. Vos données de plongée sur CET appareil ne sont pas affectées.',
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
          'Cette action supprime $count fichiers ($size) appartenant à $name. Ils subsistent d’une bibliothèque avec laquelle plus aucun appareil ne se synchronise. Vos données de plongée ne sont pas affectées.',
      one:
          'Cette action supprime 1 fichier ($size) appartenant à $name. Il subsiste d’une bibliothèque avec laquelle plus aucun appareil ne se synchronise. Vos données de plongée ne sont pas affectées.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_removeDialog_title(String name) {
    return 'Supprimer les fichiers de $name ?';
  }

  @override
  String settings_syncDevices_removeProgressTitle(String name) {
    return 'Suppression des fichiers de $name';
  }

  @override
  String get settings_syncDevices_removeTooltip =>
      'Supprimer les fichiers de cet appareil';

  @override
  String get settings_syncDevices_state_active => 'Synchronisation normale';

  @override
  String get settings_syncDevices_state_retired => 'Réformé';

  @override
  String get settings_syncDevices_state_staleEpoch =>
      'Vestige d’une bibliothèque antérieure, aucun appareil ne la lit';

  @override
  String get settings_syncDevices_state_thisDevice => 'Cet appareil';

  @override
  String get settings_syncDevices_state_unreadable =>
      'Aucun manifeste lisible : un envoi inachevé, ou chiffré';

  @override
  String settings_syncDevices_summary(
    int deviceCount,
    int fileCount,
    String size,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      deviceCount,
      locale: localeName,
      other: '$deviceCount appareils',
      one: '1 appareil',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: '$fileCount fichiers',
      one: '1 fichier',
    );
    return '$_temp0, $_temp1, $size';
  }

  @override
  String settings_syncDevices_summary_removable(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count vestiges de bibliothèques remplacées ou retirées, occupant $size.',
      one: '1 vestige d’une bibliothèque remplacée ou retirée, occupant $size.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_tile_filesSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers',
      one: '1 fichier',
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
      other: '$count fichiers',
      one: '1 fichier',
    );
    return '$_temp0, $size, $when';
  }

  @override
  String settings_syncDevices_unnamedDevice(String shortId) {
    return 'Appareil $shortId';
  }

  @override
  String get settings_syncMaintenance_keepAppOpen =>
      'Laissez l’application ouverte jusqu’à la fin de l’opération. La fermer maintenant laisse le service partiellement vidé, et la synchronisation suivante devra tout recommencer.';

  @override
  String get settings_syncMaintenance_phase_clearingOldFiles =>
      'Suppression des anciens fichiers';

  @override
  String get settings_syncMaintenance_phase_deleting => 'Suppression';

  @override
  String get settings_syncMaintenance_phase_publishingLibrary =>
      'Publication de la bibliothèque';

  @override
  String get settings_cloudSync_adopt_progressTitle =>
      'Adoption de la bibliothèque restaurée';

  @override
  String get settings_cloudSync_replaceLibrary_progressTitle =>
      'Remplacement de la bibliothèque cloud';

  @override
  String settings_syncDevices_nameWithId(String name, String shortId) {
    return '$name ($shortId)';
  }

  @override
  String get settings_syncMaintenance_phase_applyingLibrary =>
      'Application de la bibliothèque';

  @override
  String get settings_syncMaintenance_phase_backingUp =>
      'Sauvegarde de cet appareil';

  @override
  String get settings_syncMaintenance_phase_repairing =>
      'Suppression de l\'état de synchronisation local';

  @override
  String get settings_troubleshootSync_repair_progressTitle =>
      'Réparation de la synchronisation';

  @override
  String get settings_syncMaintenance_phase_working => 'Traitement en cours...';

  @override
  String settings_syncMaintenance_progress_filesOfTotal(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done sur $total fichiers',
      one: '$done sur 1 fichier',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_removedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers supprimés',
      one: '1 fichier supprimé',
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
          '$count fichiers supprimés, mais $trouble. Réessayez lorsque vous êtes en ligne.',
      one:
          '1 fichier supprimé, mais $trouble. Réessayez lorsque vous êtes en ligne.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_trouble_failed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count n’ont pas pu être supprimés',
      one: '1 n’a pas pu être supprimé',
    );
    return '$_temp0';
  }

  @override
  String get settings_syncMaintenance_trouble_listIncomplete =>
      'certains fichiers n’ont pas pu être listés';

  @override
  String settings_syncMaintenance_wipedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers effacés',
      one: '1 fichier effacé',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_wipedFilesPartial(int count, String trouble) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count fichiers effacés, mais $trouble. Réessayez lorsque vous êtes en ligne.',
      one:
          '1 fichier effacé, mais $trouble. Réessayez lorsque vous êtes en ligne.',
    );
    return '$_temp0';
  }

  @override
  String get settings_troubleshootSync_appBar_title =>
      'Dépanner la synchronisation';

  @override
  String get settings_troubleshootSync_devices_subtitle =>
      'Voyez chaque appareil qui conserve des fichiers ici, l’espace occupé par chacun, et supprimez les vestiges de bibliothèques avec lesquelles plus aucun appareil ne se synchronise. Vos données de plongée ne sont pas affectées.';

  @override
  String get settings_troubleshootSync_rebuild_confirm => 'Reconstruire';

  @override
  String get settings_troubleshootSync_rebuild_confirmBody =>
      'Cette action fait de la bibliothèque de cet appareil la bibliothèque actuelle sur le service et la republie, afin que les autres appareils se synchronisent depuis vous. Utilisez-la lorsqu’un remplacement provenant d’un autre appareil est bloqué. Vos données de plongée ne sont pas affectées.';

  @override
  String get settings_troubleshootSync_rebuild_confirmTitle =>
      'Reconstruire le service à partir de cet appareil ?';

  @override
  String get settings_troubleshootSync_rebuild_doneSnack =>
      'Service reconstruit à partir de cet appareil';

  @override
  String get settings_troubleshootSync_rebuild_failedSnack =>
      'Échec de la reconstruction';

  @override
  String get settings_troubleshootSync_rebuild_progressTitle =>
      'Reconstruction du service';

  @override
  String get settings_troubleshootSync_rebuild_subtitle =>
      'À utiliser si la synchronisation est bloquée en attente d’une bibliothèque qu’un autre appareil a remplacée mais n’a jamais fini d’envoyer (cet appareil est peut-être hors ligne). Publie la bibliothèque de cet appareil comme bibliothèque actuelle.';

  @override
  String get settings_troubleshootSync_rebuild_title =>
      'Reconstruire le service à partir de cet appareil';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmBody =>
      'Cette action supprime du service uniquement les fichiers de synchronisation de cet appareil. Les autres appareils continuent de se synchroniser, et vos données de plongée ne sont pas affectées.';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmTitle =>
      'Supprimer les fichiers cloud de cet appareil ?';

  @override
  String get settings_troubleshootSync_removeThisDevice_progressTitle =>
      'Suppression des fichiers cloud de cet appareil';

  @override
  String get settings_troubleshootSync_removeThisDevice_subtitle =>
      'Libérez l’espace occupé par cet appareil sur le service. Les autres appareils continuent de se synchroniser. Vos données de plongée ne sont pas affectées.';

  @override
  String get settings_troubleshootSync_removeThisDevice_title =>
      'Supprimer les fichiers cloud de cet appareil';

  @override
  String get settings_troubleshootSync_repair_confirm => 'Réparer';

  @override
  String get settings_troubleshootSync_repair_confirmBody =>
      'Cette action efface tout l’état de synchronisation local et attribue une nouvelle identité de synchronisation à cet appareil, puis rétablit une connexion neuve lors de la prochaine synchronisation. Vos données de plongée sont en sécurité et ne sont pas supprimées.';

  @override
  String get settings_troubleshootSync_repair_confirmTitle =>
      'Réparer la synchronisation ?';

  @override
  String get settings_troubleshootSync_repair_doneSnack =>
      'Synchronisation réparée';

  @override
  String get settings_troubleshootSync_repair_subtitle =>
      'Réparer une synchronisation bloquée. Efface l’état de synchronisation de cet appareil et lui attribue une nouvelle identité de synchronisation, puis se reconnecte lors de la prochaine synchronisation. Vos données de plongée ne sont pas affectées.';

  @override
  String get settings_troubleshootSync_repair_title =>
      'Réparer la synchronisation';

  @override
  String get settings_troubleshootSync_wipeAll_confirm => 'Tout effacer';

  @override
  String settings_troubleshootSync_wipeAll_confirmBody(String word) {
    return 'Cette action supprime les données de synchronisation de CHAQUE appareil de ce service, y compris les marqueurs de bibliothèque. Chaque appareil devra rétablir la synchronisation depuis zéro. Vos données de plongée ne sont pas affectées.\n\nSaisissez $word pour confirmer.';
  }

  @override
  String get settings_troubleshootSync_wipeAll_confirmTitle =>
      'Effacer toutes les données de synchronisation ?';

  @override
  String get settings_troubleshootSync_wipeAll_progressTitle =>
      'Effacement des données de synchronisation';

  @override
  String get settings_troubleshootSync_wipeAll_subtitle =>
      'Supprimez les données de synchronisation de chaque appareil de ce service, y compris les marqueurs de bibliothèque. Chaque appareil rétablit la synchronisation depuis zéro. Vos données de plongée ne sont pas affectées.';

  @override
  String get settings_troubleshootSync_wipeAll_title =>
      'Effacer toutes les données de synchronisation sur ce service';

  @override
  String get tableMode_tooltip_toggleDetailPane =>
      'Afficher ou masquer le volet de détail';

  @override
  String get tableMode_tooltip_toggleProfilePanel =>
      'Afficher ou masquer le panneau de profil';

  @override
  String get maps_regionDownload_title => 'Télécharger la région';

  @override
  String get maps_regionDownload_nameRequired =>
      'Veuillez saisir un nom pour cette région';

  @override
  String get maps_regionDownload_nameLabel => 'Nom de la région';

  @override
  String get maps_regionDownload_nameHint => 'ex. Cozumel, Mexique';

  @override
  String get maps_regionDownload_zoomLevels => 'Niveaux de zoom';

  @override
  String get maps_regionDownload_zoomHint =>
      'Zoom plus élevé = plus de détails, téléchargement plus volumineux';

  @override
  String maps_regionDownload_minZoom(int zoom) {
    return 'Min : $zoom';
  }

  @override
  String maps_regionDownload_minZoomSemantics(int zoom) {
    return 'Zoom minimum : $zoom';
  }

  @override
  String maps_regionDownload_maxZoom(int zoom) {
    return 'Max : $zoom';
  }

  @override
  String maps_regionDownload_maxZoomSemantics(int zoom) {
    return 'Zoom maximum : $zoom';
  }

  @override
  String get maps_regionDownload_estimatingSemantics =>
      'Estimation de la taille du téléchargement';

  @override
  String maps_regionDownload_estimateSemantics(int count, Object size) {
    return 'Téléchargement estimé : $count tuiles, $size';
  }

  @override
  String get maps_regionDownload_estimateUnavailableSemantics =>
      'Impossible d’estimer la taille du téléchargement';

  @override
  String get maps_regionDownload_estimating => 'Estimation...';

  @override
  String maps_regionDownload_tileCount(int count) {
    return '~$count tuiles';
  }

  @override
  String get maps_regionDownload_estimateUnavailable => 'Estimation impossible';

  @override
  String get maps_regionDownload_largeWarningSemantics =>
      'Attention : téléchargement volumineux. Réduisez les niveaux de zoom ou sélectionnez une région plus petite.';

  @override
  String get maps_regionDownload_largeWarning =>
      'Téléchargement volumineux. Réduisez les niveaux de zoom ou sélectionnez une région plus petite.';

  @override
  String get maps_regionDownload_downloadButton => 'Télécharger';

  @override
  String get diveLog_map_title => 'Activité de plongée';

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
      'Miniature de photo. Appuyez pour voir en plein écran';

  @override
  String get trips_gallery_thumbnail_video =>
      'Miniature de vidéo. Appuyez pour voir en plein écran';

  @override
  String get trips_gallery_thumbnail_photoMissing =>
      'Miniature de photo, absente de l’appareil. Appuyez pour voir en plein écran';

  @override
  String get trips_gallery_thumbnail_videoMissing =>
      'Miniature de vidéo, absente de l’appareil. Appuyez pour voir en plein écran';

  @override
  String get trips_photos_thumbnail_photo =>
      'Miniature de photo. Appuyez pour ouvrir la galerie';

  @override
  String get trips_photos_thumbnail_video =>
      'Miniature de vidéo. Appuyez pour ouvrir la galerie';

  @override
  String trips_picker_suggestedSemantics(Object name) {
    return 'Voyage suggéré : $name. Appuyez pour l’utiliser';
  }

  @override
  String trips_picker_tileSemantics(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, du $startDate au $endDate';
  }

  @override
  String trips_picker_tileSemanticsSelected(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, du $startDate au $endDate, sélectionné';
  }

  @override
  String get divePlanner_quickPlan_subtitle =>
      'Créer un profil de plongée rectangulaire simple';

  @override
  String get divePlanner_quickPlan_depthLabel => 'Profondeur :';

  @override
  String divePlanner_quickPlan_depthSemantics(Object depth) {
    return 'Profondeur : $depth';
  }

  @override
  String get divePlanner_quickPlan_timeLabel => 'Temps :';

  @override
  String divePlanner_quickPlan_bottomTimeSemantics(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Temps au fond : $minutes minutes',
      one: 'Temps au fond : 1 minute',
    );
    return '$_temp0';
  }

  @override
  String divePlanner_quickPlan_minutes(int minutes) {
    return '$minutes min';
  }

  @override
  String divePlanner_quickPlan_previewSemantics(Object depth, int minutes) {
    return 'Aperçu du plan : descente à $depth, temps au fond $minutes minutes, remontée avec palier de sécurité';
  }

  @override
  String get divePlanner_quickPlan_previewTitle => 'Aperçu du plan :';

  @override
  String divePlanner_quickPlan_previewDescent(Object depth) {
    return 'Descente à $depth';
  }

  @override
  String divePlanner_quickPlan_previewBottomTime(int minutes) {
    return 'Temps au fond : $minutes min';
  }

  @override
  String get divePlanner_quickPlan_previewAscent =>
      'Remontée avec palier de sécurité';

  @override
  String get divePlanner_quickPlan_create => 'Créer';

  @override
  String divePlanner_semantics_sacRate(Object value, Object volumeSymbol) {
    return 'RMV : $value $volumeSymbol par minute';
  }

  @override
  String divePlanner_semantics_reservePressure(Object pressureSymbol) {
    return 'Pression de réserve en $pressureSymbol';
  }

  @override
  String divePlanner_semantics_altitudeGroup(Object group) {
    return 'Groupe d’altitude : $group';
  }

  @override
  String diveSites_import_detail_maxDepth(Object depth) {
    return 'Max $depth';
  }

  @override
  String get autoUpdate_banner_download => 'Télécharger';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Synchroniser via Apple iCloud';

  @override
  String get settings_debugLog_search_hint => 'Rechercher dans les journaux...';

  @override
  String get settings_debugLog_appBar_title => 'Journaux de débogage';

  @override
  String get settings_debugLog_disableDebugMode =>
      'Désactiver le mode débogage';

  @override
  String get settings_debugLog_clearLogs => 'Effacer les journaux';

  @override
  String get settings_debugLog_empty =>
      'Aucune entrée de journal ne correspond aux filtres actuels';

  @override
  String settings_debugLog_loadError(Object error) {
    return 'Erreur lors du chargement des journaux : $error';
  }

  @override
  String get settings_debugLog_copiedSnack =>
      'Journaux filtrés copiés dans le presse-papiers';

  @override
  String settings_debugLog_savedSnack(String path) {
    return 'Journaux enregistrés dans $path';
  }

  @override
  String get common_action_copy => 'Copier';

  @override
  String get settings_appearance_customGradient_title => 'Dégradé personnalisé';

  @override
  String get settings_appearance_customGradient_start => 'Début';

  @override
  String get settings_appearance_customGradient_end => 'Fin';

  @override
  String get settings_appearance_customGradient_hue => 'Teinte';

  @override
  String get settings_appearance_customGradient_saturation => 'Saturation';

  @override
  String get settings_appearance_customGradient_brightness => 'Luminosité';

  @override
  String get settings_appearance_customGradient_preview => 'Aperçu';

  @override
  String get common_action_apply => 'Appliquer';

  @override
  String settings_cloudSync_message_loadStateFailed(Object error) {
    return 'Échec du chargement de l’état de synchronisation : $error';
  }

  @override
  String get settings_cloudSync_message_noProviderConfigured =>
      'Aucun fournisseur cloud configuré';

  @override
  String get settings_cloudSync_message_adopting =>
      'Adoption de la bibliothèque restaurée...';

  @override
  String get settings_cloudSync_message_adoptFailed =>
      'Échec de l’adoption de la bibliothèque restaurée';

  @override
  String get settings_cloudSync_message_firstSyncNeedsConfirm =>
      'La première synchronisation doit être confirmée. Appuyez sur « Synchroniser maintenant » pour la vérifier.';

  @override
  String get settings_cloudSync_message_startingSync =>
      'Démarrage de la synchronisation...';

  @override
  String get settings_cloudSync_message_replacePaused =>
      'Synchronisation en pause : la bibliothèque a été remplacée depuis une sauvegarde. Appuyez sur « Synchroniser maintenant » pour la vérifier.';

  @override
  String get settings_cloudSync_message_encryptedPaused =>
      'Synchronisation en pause : cette bibliothèque est chiffrée. Saisissez la phrase secrète pour continuer.';

  @override
  String get settings_cloudSync_message_completedWithConflicts =>
      'Synchronisation terminée avec des conflits';

  @override
  String get settings_cloudSync_message_completedSuccessfully =>
      'Synchronisation terminée avec succès';

  @override
  String get settings_cloudSync_message_syncFailed =>
      'Échec de la synchronisation';

  @override
  String get settings_cloudSync_message_phaseDefault => 'synchronisation';

  @override
  String settings_cloudSync_message_syncErrorDuring(
    String phase,
    Object error,
  ) {
    return 'Erreur de synchronisation pendant $phase : $error';
  }

  @override
  String get settings_section_debug_title => 'Débogage';

  @override
  String get settings_section_debug_subtitle => 'Journaux et diagnostics';

  @override
  String get settings_debugLog_minSeverityLabel => 'Gravité min. :';

  @override
  String get settings_debugLog_shareSubject =>
      'Journaux de débogage Submersion';

  @override
  String get settings_debugLog_saveDialogTitle =>
      'Enregistrer les journaux de débogage';

  @override
  String get universalImport_preset_saveTitle => 'Enregistrer comme preset';

  @override
  String get universalImport_preset_nameLabel => 'Nom du preset';

  @override
  String get universalImport_preset_nameHint => 'ex. Mon carnet de plongée CSV';

  @override
  String get universalImport_preset_nameRequired => 'Le nom est requis';

  @override
  String get universalImport_preset_sourceAppLabel => 'Application source';

  @override
  String get universalImport_preset_sourceAppNone => 'Aucune';

  @override
  String get universalImport_preset_entityTypesLabel => 'Types d’entités';

  @override
  String get universalImport_preset_matchThresholdLabel =>
      'Seuil de correspondance';

  @override
  String get universalImport_preset_matchThresholdHelp =>
      'Degré de correspondance requis des en-têtes CSV pour la détection automatique';

  @override
  String universalImport_preset_signatureHeaders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count en-têtes de signature du fichier actuel',
      one: '1 en-tête de signature du fichier actuel',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_preset_selectTitle => 'Sélectionner un preset';

  @override
  String universalImport_preset_loadFailed(String error) {
    return 'Échec du chargement des presets : $error';
  }

  @override
  String get universalImport_preset_sectionSaved => 'Presets enregistrés';

  @override
  String get universalImport_preset_sectionBuiltIn => 'Presets intégrés';

  @override
  String get universalImport_preset_deleteTitle => 'Supprimer le preset';

  @override
  String universalImport_preset_deleteConfirm(String name) {
    return 'Supprimer « $name » ? Cette action est irréversible.';
  }

  @override
  String universalImport_preset_headersMatched(
    int matched,
    int total,
    int percent,
  ) {
    return '$matched/$total en-têtes correspondants ($percent%)';
  }

  @override
  String get universalImport_preset_noSignatureHeaders =>
      'Aucun en-tête de signature';

  @override
  String get universalImport_preset_deleteTooltip => 'Supprimer le preset';

  @override
  String get universalImport_preset_presetsButton => 'Presets';

  @override
  String universalImport_preset_savedSnackbar(String name) {
    return 'Preset « $name » enregistré';
  }

  @override
  String get universalImport_step_done => 'Terminé';

  @override
  String get universalImport_cancel_inProgressTitle => 'Annulation';

  @override
  String get universalImport_cancel_inProgressBody =>
      'La plongée en cours est terminée avant l’arrêt. Les plongées déjà importées sont conservées.';

  @override
  String get universalImport_cancel_confirmTitle => 'Annuler l’importation ?';

  @override
  String get universalImport_cancel_confirmBody =>
      'Arrêter une fois la plongée en cours terminée. Les plongées déjà importées seront conservées.';

  @override
  String get universalImport_cancel_keepImporting => 'Continuer l’importation';

  @override
  String get universalImport_cancel_confirmAction => 'Annuler l’importation';

  @override
  String get universalImport_cancel_discardSelections =>
      'Abandonner les sélections et annuler ?';

  @override
  String get universalImport_action_importSelected => 'Importer la sélection';

  @override
  String get universalImport_action_next => 'Suivant';

  @override
  String get common_action_yes => 'Oui';

  @override
  String get common_action_no => 'Non';

  @override
  String universalImport_counts_new(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux',
      one: '$count nouveau',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_merging(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count à consolider',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_replacing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count à remplacer',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_skipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ignorés',
      one: '$count ignoré',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_counts_nothingSelected => 'Aucune sélection';

  @override
  String get universalImport_section_potentialDuplicates =>
      'Doublons potentiels';

  @override
  String get universalImport_section_possibleDuplicates => 'Doublons possibles';

  @override
  String universalImport_count_duplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doublons',
      one: '1 doublon',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_entityAction_importBadge => 'IMPORTER';

  @override
  String get universalImport_entityAction_skipBadge => 'IGNORER';

  @override
  String get universalImport_compare_existing => 'Existant';

  @override
  String get universalImport_compare_incoming => 'Entrant';

  @override
  String get universalImport_label_skipped => 'Ignoré';

  @override
  String get universalImport_action_viewDives => 'Voir les plongées';

  @override
  String get diveImport_healthkit_accessGranted => 'Accès HealthKit accordé';

  @override
  String get diveImport_healthkit_accessGrantedBody =>
      'Vous pouvez passer à l’étape suivante.';

  @override
  String get diveImport_healthkit_requesting => 'Demande en cours...';

  @override
  String get diveImport_healthkit_selectDateRange => 'Sélectionner la période';

  @override
  String get diveImport_healthkit_selectDateRangeBody =>
      'Choisissez la période de recherche des plongées dans Apple Health.';

  @override
  String get diveImport_healthkit_fetchingDives =>
      'Récupération des plongées depuis Apple Health...';

  @override
  String get diveImport_healthkit_fetchFailed => 'Échec de la récupération';

  @override
  String diveImport_healthkit_fetchFailedBody(String error) {
    return 'Échec de la récupération des plongées : $error';
  }

  @override
  String diveImport_healthkit_foundDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plongées trouvées',
      one: '1 plongée trouvée',
    );
    return '$_temp0';
  }

  @override
  String get diveImport_healthkit_proceedingToReview =>
      'Passage à la vérification...';

  @override
  String get importWizard_dc_knownComputer => 'Ordinateur connu';

  @override
  String importWizard_dc_knownComputerBody(String name) {
    return 'Enregistré sous « $name ». Seules les nouvelles plongées seront téléchargées.';
  }

  @override
  String get importWizard_dc_noNewDives =>
      'Aucune nouvelle plongée à télécharger';

  @override
  String get importWizard_dc_noNewDivesBody =>
      'Toutes les plongées de cet ordinateur ont déjà été importées.';

  @override
  String get universalImport_compare_noDiveData =>
      'Données de plongée non disponibles pour la comparaison.';

  @override
  String get universalImport_entityAction_consolidateBadge => 'CONSOLIDER';

  @override
  String get diveCenters_import_quickSearch_egypt => 'Égypte';

  @override
  String get diveCenters_import_quickSearch_mexico => 'Mexique';

  @override
  String get accessibility_shortcut_switchDiver => 'Changer de plongeur';

  @override
  String get lock_recoveryCode_title => 'Utiliser le code de récupération';

  @override
  String get lock_recoveryCode_body =>
      'Saisissez le code de récupération de 8 mots que vous avez enregistré lors de la configuration du mot de passe de l’app.';

  @override
  String get lock_recoveryCode_error => 'Code de récupération incorrect.';

  @override
  String get lock_forcedReset_title => 'Définir un nouveau mot de passe';

  @override
  String get lock_forcedReset_body =>
      'Vous avez déverrouillé avec votre code de récupération : votre ancien mot de passe n’est donc plus fiable. Choisissez-en un nouveau maintenant.';

  @override
  String get lock_forcedReset_submit => 'Définir le mot de passe';

  @override
  String get lock_forcedReset_error =>
      'Impossible de définir le nouveau mot de passe. Réessayez.';

  @override
  String get lock_sidecarRepair_title =>
      'Réparer le fichier de clé de sécurité';

  @override
  String get lock_sidecarRepair_body =>
      'Votre fichier de clé de sécurité était manquant et le trousseau de cet appareil contient encore la clé. Confirmez votre mot de passe pour écrire un nouveau fichier de clé. Remarque : le mot de passe que vous saisissez ici devient désormais le mot de passe de l’app, et vous recevrez un nouveau code de récupération.';

  @override
  String get lock_sidecarRepair_submit => 'Réparer';

  @override
  String get lock_sidecarRepair_error => 'Échec de la réparation. Réessayez.';

  @override
  String get lock_newRecoveryCode_title => 'Votre nouveau code de récupération';

  @override
  String get lock_startFresh_title => 'Ouvrir une autre base de données';

  @override
  String lock_startFresh_body(Object token) {
    return 'Votre base de données actuelle reste sur le disque, renommée avec le suffixe .locked ; rien n’est supprimé. Vous pourrez la récupérer plus tard avec votre mot de passe ou en contactant l’assistance. La synchronisation cloud sera désactivée afin que la nouvelle base de données ne puisse pas se mélanger à l’ancienne.\n\nL’application démarrera avec une base de données neuve et vide. Vous pouvez restaurer une sauvegarde dans l’assistant de configuration.\n\nSaisissez $token pour confirmer.';
  }

  @override
  String get lock_startFresh_confirm => 'Mettre de côté et repartir de zéro';

  @override
  String get lock_biometric_reason => 'Déverrouillez votre carnet de plongée';

  @override
  String startup_migrating_progress(Object currentStep, Object totalSteps) {
    return 'Mise à niveau de la base de données... étape $currentStep sur $totalSteps';
  }

  @override
  String get startup_error_title => 'Submersion n’a pas pu démarrer';

  @override
  String get startup_error_body =>
      'Un problème est survenu avant l’ouverture complète de votre carnet de plongée. Vos données sont toujours sur le disque et une réinstallation n’est pas nécessaire. Essayez de redémarrer l’application ; si le problème persiste, contactez l’assistance.';

  @override
  String get startup_engineUnavailable_title =>
      'Cette version ne peut ouvrir aucune base de données';

  @override
  String get startup_engineUnavailable_body =>
      'Le moteur de base de données de Submersion est absent de cette version, votre carnet de plongée n’a donc jamais été ouvert. Rien n’a changé sur le disque et aucune donnée n’est en danger.';

  @override
  String get startup_engineUnavailable_guidance =>
      'Réinstaller ou restaurer une sauvegarde n’y changera rien. Installez une version fonctionnelle de Submersion et signalez-nous ce problème : il vient du paquet de l’application, pas de vos données.';

  @override
  String get startup_migrationFailed_title =>
      'Échec de la mise à niveau de la base de données';

  @override
  String get startup_migrationFailed_body =>
      'Votre carnet de plongée n’a pas pu être mis à niveau vers le format requis par cette version. Une copie de sécurité a été créée avant le début de la mise à niveau : rien n’est perdu.';

  @override
  String get startup_dataUnreadable_title =>
      'Votre carnet de plongée n’a pas pu être lu';

  @override
  String get startup_dataUnreadable_body =>
      'Le fichier de base de données est bien là, mais Submersion ne parvient pas à le lire. Cela signifie généralement qu’il est endommagé. Restaurer une sauvegarde est le moyen le plus rapide de repartir.';

  @override
  String get startup_databaseBusy_title =>
      'Votre carnet de plongée était occupé';

  @override
  String get startup_databaseBusy_body =>
      'Quelque chose utilisait encore le fichier de base de données ; Submersion s’est donc arrêté au lieu d’y écrire. Rien n’a été modifié ni endommagé. Fermez complètement Submersion, puis rouvrez-le.';

  @override
  String get startup_failure_technicalDetails => 'Détails techniques';

  @override
  String get startup_failure_backupAvailable_title =>
      'Une sauvegarde est disponible';

  @override
  String startup_failure_backupAvailable_taken(Object timestamp) {
    return 'Créée le $timestamp';
  }

  @override
  String startup_failure_backupAvailable_preMigration(
    Object fromVersion,
    Object toVersion,
  ) {
    return 'Copie de sécurité créée avant la mise à niveau du schéma v$fromVersion vers v$toVersion.';
  }

  @override
  String get startup_failure_restoreAction => 'Restaurer cette sauvegarde';

  @override
  String get startup_failure_restoring =>
      'Restauration de votre carnet de plongée...';

  @override
  String get startup_failure_restoreFailed =>
      'La sauvegarde n’a pas pu être restaurée. Votre carnet de plongée a été laissé exactement en l’état.';

  @override
  String get startup_failure_backupsFolder =>
      'Vos sauvegardes se trouvent dans :';

  @override
  String get startup_failure_showBackupsFolder =>
      'Afficher le dossier des sauvegardes';

  @override
  String get startup_failure_downgrade_title =>
      'Revenir à la version précédente';

  @override
  String get startup_failure_downgrade_body =>
      'Si la mise à niveau échoue systématiquement, installez la version de Submersion que vous utilisiez auparavant, puis restaurez la copie de sécurité depuis cette version. La restaurer ici ne ferait que relancer la même mise à niveau. Submersion ne revient jamais tout seul à une version antérieure : vous basculer automatiquement sur d’anciennes versions vous maintiendrait discrètement sur des versions présentant des problèmes connus.';

  @override
  String get startup_failure_downgrade_action =>
      'Voir les versions précédentes';

  @override
  String get startup_recovering_title =>
      'Récupération de la base de données...';

  @override
  String get startup_recovering_body =>
      'Annulation de la transaction interrompue. Cela prend généralement quelques secondes.';

  @override
  String get startup_recoveryFailed_title =>
      'La récupération ne s’est pas terminée';

  @override
  String get startup_recoveryFailed_body =>
      'La base de données n’a pas pu être annulée automatiquement. Vos données sont toujours sur le disque ; contactez l’assistance avant de réinstaller afin que nous puissions vous aider à les récupérer.';

  @override
  String get startup_recoveryRequired_title =>
      'La base de données doit être récupérée';

  @override
  String get startup_recoveryRequired_body =>
      'Une session précédente a été interrompue pendant l’écriture dans la base de données. Vos données sont toujours sur le disque ; il nous suffit de terminer l’annulation de la modification interrompue avant que l’app puisse s’ouvrir.';

  @override
  String startup_recovery_sqliteCode(Object code) {
    return 'Code SQLite $code';
  }

  @override
  String get startup_recovery_action => 'Récupérer la base de données';

  @override
  String get startup_recovery_closeWithoutRecovering => 'Fermer sans récupérer';

  @override
  String get common_action_tryAgain => 'Réessayer';

  @override
  String get lock_screen_title => 'Submersion est verrouillé';

  @override
  String get lock_screen_forgotPassword => 'Mot de passe oublié ?';

  @override
  String get lock_incorrectPassword => 'Mot de passe incorrect. Réessayez.';

  @override
  String get startup_backup_semanticsLabel => 'Sauvegarde en cours';

  @override
  String get startup_backup_title => 'Sauvegarde de vos données';

  @override
  String get startup_backup_body =>
      'Nous enregistrons une copie de votre carnet de plongée avant de mettre à niveau votre base de données.';

  @override
  String get startup_backupFailed_title =>
      'Impossible de sauvegarder vos données';

  @override
  String get startup_backupFailed_body =>
      'Votre carnet de plongée n’a pas changé : nous ne l’avons pas mis à jour. Libérez de l’espace (ou corrigez le problème) puis réessayez.';

  @override
  String get startup_backupFailed_quit => 'Quitter';

  @override
  String get startup_backupFailed_technicalDetails => 'Détails techniques';

  @override
  String get common_action_retry => 'Réessayer';

  @override
  String get startup_versionMismatch_title => 'Mise à jour requise';

  @override
  String startup_versionMismatch_body(
    Object databaseVersion,
    Object appVersion,
  ) {
    return 'Vos données de plongée ont été enregistrées par une version plus récente de Submersion (schéma v$databaseVersion). Cette version ne prend en charge le schéma que jusqu’à v$appVersion.';
  }

  @override
  String get startup_versionMismatch_instructions =>
      'Veuillez mettre à jour Submersion vers la dernière version. Vos données sont intactes et n’ont pas été modifiées. Si une sauvegarde a été effectuée avant la mise à niveau, elle se trouve dans votre dossier Backups et peut être restaurée après la mise à jour.';

  @override
  String get startup_versionMismatch_storeInstructions =>
      'Cette application a été installée depuis une boutique d\'applications et est plus ancienne que la version qui a créé vos données. Vos données sont en sécurité et n\'ont pas été modifiées. Mettez à jour Submersion dès que la nouvelle version apparaît dans la boutique, puis rouvrez l\'application.';

  @override
  String get startup_versionMismatch_download =>
      'Télécharger la dernière version';

  @override
  String get startup_versionMismatch_manualLink =>
      'Si cela n’ouvre pas de navigateur, rendez-vous sur :';

  @override
  String get universalImport_compare_downloaded => 'Téléchargée';

  @override
  String get universalImport_compare_errorLoading =>
      'Erreur lors du chargement des données de plongée';

  @override
  String get universalImport_compare_diveNotFound =>
      'Plongée existante introuvable';

  @override
  String universalImport_compare_sameFields(Object fields) {
    return 'Identique : $fields';
  }

  @override
  String get universalImport_compare_differences => 'DIFFÉRENCES';

  @override
  String get universalImport_compare_notRecorded => 'non enregistré';

  @override
  String universalImport_compare_serial(Object serial) {
    return 'N° série : $serial';
  }

  @override
  String get universalImport_compare_skipSubtitle =>
      'Ignorer ce téléchargement';

  @override
  String get universalImport_compare_importAsNewSubtitle =>
      'Enregistrer comme plongée distincte';

  @override
  String get universalImport_compare_consolidateSubtitle =>
      'Ajouter comme 2e relevé d’ordinateur';

  @override
  String get diveLog_tooltip_ndlOverMax => '>60 min';

  @override
  String diveLog_tooltip_interpolated(String value) {
    return '$value (interpolé)';
  }

  @override
  String get enum_profileMetric_ascentRate_short => 'Vitesse';

  @override
  String get enum_profileMetric_cns_short => 'CNS';

  @override
  String get enum_profileMetric_otu_short => 'OTU';

  @override
  String get diveLog_profileEditor_rangeOperations => 'Opérations sur la plage';

  @override
  String get diveLog_profileEditor_selectRangeHint =>
      'Sélectionnez une plage sur le graphique pour activer les opérations';

  @override
  String get diveLog_profileEditor_depthPlusOneMeter => 'Prof. +1 m';

  @override
  String get diveLog_profileEditor_depthMinusOneMeter => 'Prof. -1 m';

  @override
  String get diveLog_profileEditor_timePlusFiveSeconds => 'Temps +5 s';

  @override
  String get diveLog_profileEditor_timeMinusFiveSeconds => 'Temps -5 s';

  @override
  String get diveLog_profileEditor_smoothing => 'Lissage';

  @override
  String get diveLog_profileEditor_smoothLight => 'Léger';

  @override
  String get diveLog_profileEditor_smoothMedium => 'Moyen';

  @override
  String get diveLog_profileEditor_smoothHeavy => 'Fort';

  @override
  String get diveLog_profileEditor_applyToAll => 'Appliquer à tout';

  @override
  String get diveLog_profileEditor_applyToSelection =>
      'Appliquer à la sélection';

  @override
  String get diveLog_profileEditor_outlierDetection =>
      'Détection des valeurs aberrantes';

  @override
  String get diveLog_profileEditor_detect => 'Détecter';

  @override
  String get diveLog_profileEditor_removeAll => 'Tout supprimer';

  @override
  String diveLog_profileEditor_outliersDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valeurs aberrantes potentielles détectées',
      one: '$count valeur aberrante potentielle détectée',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_profileEditor_manualDrawing => 'Dessin manuel';

  @override
  String get diveLog_profileEditor_drawHint =>
      'Touchez le graphique pour placer des points de repère';

  @override
  String get diveLog_profileEditor_clearWaypoints => 'Effacer';

  @override
  String get diveLog_profileEditor_generateProfile => 'Générer le profil';

  @override
  String get diveLog_profileEditor_trimMode => 'Mode rognage';

  @override
  String get diveLog_profileEditor_trimHint =>
      'Rogner les extrémités du profil';

  @override
  String get diveLog_profileEditor_trimEnd => 'Rogner la fin';

  @override
  String get diveLog_profileEditor_mode_smooth => 'Lisser';

  @override
  String get diveLog_profileEditor_title => 'Modifier le profil';

  @override
  String get diveLog_profileEditor_discardBody =>
      'Vous avez des modifications non enregistrées sur ce profil de plongée. Voulez-vous vraiment les abandonner ?';

  @override
  String get diveLog_profileEditor_saveTitle => 'Enregistrer le profil ?';

  @override
  String get diveLog_profileEditor_saveBody =>
      'Le profil modifié sera enregistré comme profil principal de cette plongée. Le profil d’origine sera conservé et pourra être restauré ultérieurement.';

  @override
  String diveLog_profileEditor_saveFailed(String error) {
    return 'Échec de l’enregistrement du profil : $error';
  }

  @override
  String diveLog_profileEditor_errorLoadingDive(String error) {
    return 'Erreur lors du chargement de la plongée : $error';
  }

  @override
  String get diveLog_profileEditor_noProfileData =>
      'Aucune donnée de profil disponible';

  @override
  String get diveLog_profileEditor_undo => 'Annuler';

  @override
  String get diveLog_profileEditor_mode_select => 'Sélectionner';

  @override
  String get diveLog_profileEditor_mode_outlier => 'Aberrant';

  @override
  String get diveLog_profileEditor_mode_draw => 'Dessiner';

  @override
  String get diveLog_profileEditor_mode_trim => 'Rogner';

  @override
  String diveLog_sources_sectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sources de données',
      one: 'Source de données',
      zero: 'Source de données',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_badge_manual => 'Manuel';

  @override
  String get diveLog_sources_badge_viewing => 'Affichée';

  @override
  String get diveLog_sources_badge_secondary => 'Secondaire';

  @override
  String diveLog_sources_created(String date) {
    return 'Créée le $date';
  }

  @override
  String get diveLog_sources_detail_serial => 'Numéro de série';

  @override
  String get diveLog_sources_detail_format => 'Format';

  @override
  String get diveLog_sources_detail_imported => 'Importé';

  @override
  String diveLog_detail_semantics_viewDiveComputer(String name) {
    return 'Voir l’ordinateur de plongée $name';
  }

  @override
  String diveLog_detail_semantics_viewTrip(String name) {
    return 'Voir le voyage $name';
  }

  @override
  String diveLog_detail_semantics_viewDiveCenter(String name) {
    return 'Voir le centre de plongée $name';
  }

  @override
  String diveLog_detail_semantics_viewSpecies(String name) {
    return 'Voir l’espèce $name';
  }

  @override
  String diveLog_detail_semantics_viewCourse(String name) {
    return 'Voir le cours $name';
  }

  @override
  String diveLog_detail_serialNumber(String serial) {
    return 'N° série $serial';
  }

  @override
  String diveLog_detail_errorLoadingSignature(String error) {
    return 'Erreur lors du chargement de la signature : $error';
  }

  @override
  String get diveLog_profilePanel_selectDive =>
      'Sélectionnez une plongée pour voir son profil';

  @override
  String get diveLog_profilePanel_noProfileData =>
      'Aucune donnée de profil pour cette plongée';

  @override
  String get settings_export_progress_divesCsv =>
      'Export des plongées vers CSV...';

  @override
  String get settings_export_progress_sitesCsv =>
      'Export des sites vers CSV...';

  @override
  String get settings_export_progress_equipmentCsv =>
      'Export de l’équipement vers CSV...';

  @override
  String get settings_export_progress_pdf => 'Génération du carnet PDF...';

  @override
  String get settings_export_progress_loadingSignatures =>
      'Chargement des signatures...';

  @override
  String get settings_export_progress_loadingCertifications =>
      'Chargement des certifications...';

  @override
  String get settings_export_progress_loadingFonts =>
      'Chargement des polices...';

  @override
  String settings_export_progress_templatePdf(String template) {
    return 'Génération du PDF $template...';
  }

  @override
  String get settings_export_progress_uddf => 'Génération du fichier UDDF...';

  @override
  String get settings_export_progress_collectingData =>
      'Collecte de toutes les données...';

  @override
  String get settings_export_progress_excel => 'Génération du fichier Excel...';

  @override
  String get settings_export_progress_buildingExcel =>
      'Construction du classeur Excel...';

  @override
  String get settings_export_progress_kml => 'Génération du fichier KML...';

  @override
  String get settings_export_progress_buildingKml =>
      'Construction du fichier KML...';

  @override
  String get settings_export_progress_preparingExcel =>
      'Préparation du fichier Excel...';

  @override
  String get settings_export_progress_preparingKml =>
      'Préparation du fichier KML...';

  @override
  String get settings_export_progress_chooseLocation =>
      'Choix de l’emplacement d’enregistrement...';

  @override
  String get settings_export_progress_preparingDivesCsv =>
      'Préparation du CSV des plongées...';

  @override
  String get settings_export_progress_preparingSitesCsv =>
      'Préparation du CSV des sites...';

  @override
  String get settings_export_progress_preparingEquipmentCsv =>
      'Préparation du CSV de l’équipement...';

  @override
  String get settings_export_progress_preparingUddf =>
      'Préparation du fichier UDDF...';

  @override
  String get settings_export_progress_preparingPdf => 'Préparation du PDF...';

  @override
  String get settings_export_progress_selectingBackup =>
      'Sélection du fichier de sauvegarde...';

  @override
  String get settings_export_progress_restoringBackup =>
      'Restauration depuis la sauvegarde...';

  @override
  String get settings_export_empty_dives => 'Aucune plongée à exporter';

  @override
  String get settings_export_empty_sites => 'Aucun site à exporter';

  @override
  String get settings_export_empty_equipment => 'Aucun équipement à exporter';

  @override
  String get settings_export_empty_data => 'Aucune donnée à exporter';

  @override
  String get settings_export_empty_diveSites =>
      'Aucun site de plongée à exporter';

  @override
  String settings_export_saveFailed(String error) {
    return 'Échec de l’enregistrement : $error';
  }

  @override
  String settings_export_backupFailed(String error) {
    return 'Échec de la sauvegarde : $error';
  }

  @override
  String settings_export_restoreFailed(String error) {
    return 'Échec de la restauration : $error';
  }

  @override
  String get settings_export_fileUnreadable =>
      'Impossible d’accéder au fichier';

  @override
  String get settings_export_notADbFile =>
      'Veuillez sélectionner un fichier de sauvegarde .db';

  @override
  String get settings_export_success_dives => 'Plongées exportées avec succès';

  @override
  String get settings_export_success_sites => 'Sites exportés avec succès';

  @override
  String get settings_export_success_equipment =>
      'Équipement exporté avec succès';

  @override
  String get settings_export_success_pdf => 'Carnet PDF généré avec succès';

  @override
  String get settings_export_success_uddf => 'Fichier UDDF généré avec succès';

  @override
  String get settings_export_success_excel =>
      'Fichier Excel exporté avec succès';

  @override
  String settings_export_success_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Fichier KML exporté avec succès ($count sites sans coordonnées ignorés)',
      one: 'Fichier KML exporté avec succès (1 site sans coordonnées ignoré)',
      zero: 'Fichier KML exporté avec succès',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_excel =>
      'Fichier Excel enregistré avec succès';

  @override
  String settings_export_saved_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Fichier KML enregistré avec succès ($count sites sans coordonnées ignorés)',
      one:
          'Fichier KML enregistré avec succès (1 site sans coordonnées ignoré)',
      zero: 'Fichier KML enregistré avec succès',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_divesCsv =>
      'CSV des plongées enregistré avec succès';

  @override
  String get settings_export_saved_sitesCsv =>
      'CSV des sites enregistré avec succès';

  @override
  String get settings_export_saved_equipmentCsv =>
      'CSV de l’équipement enregistré avec succès';

  @override
  String get settings_export_saved_uddf =>
      'Fichier UDDF enregistré avec succès';

  @override
  String get settings_export_saved_pdf => 'PDF enregistré avec succès';

  @override
  String get settings_export_saved_backup =>
      'Sauvegarde enregistrée avec succès';

  @override
  String get settings_export_restoreComplete => 'Restauration terminée';

  @override
  String get settings_export_cancelled_save => 'Enregistrement annulé';

  @override
  String get settings_export_cancelled_backup => 'Sauvegarde annulée';

  @override
  String get settings_export_cancelled_restore => 'Restauration annulée';

  @override
  String get settings_export_pdfDocumentTitle => 'Carnet de plongée';

  @override
  String get settings_export_saveBackupDialogTitle =>
      'Enregistrer la sauvegarde';

  @override
  String backup_operation_created(String size) {
    return 'Sauvegarde créée : $size';
  }

  @override
  String backup_operation_backupFailed(String error) {
    return 'Échec de la sauvegarde : $error';
  }

  @override
  String get backup_operation_restoring => 'Restauration de la sauvegarde...';

  @override
  String backup_operation_restoreFailed(String error) {
    return 'Échec de la restauration : $error';
  }

  @override
  String get backup_operation_deleting => 'Suppression de la sauvegarde...';

  @override
  String get backup_operation_deleted => 'Sauvegarde supprimée';

  @override
  String backup_operation_deleteFailed(String error) {
    return 'Échec de la suppression : $error';
  }

  @override
  String get backup_operation_exporting => 'Export de la sauvegarde...';

  @override
  String backup_operation_exported(String size) {
    return 'Sauvegarde exportée : $size';
  }

  @override
  String backup_operation_exportFailed(String error) {
    return 'Échec de l’export : $error';
  }

  @override
  String get backup_operation_preparingShare =>
      'Préparation de la sauvegarde pour le partage...';

  @override
  String get backup_operation_shareReady => 'Sauvegarde prête à être partagée';

  @override
  String backup_operation_upgrading(int step, int total) {
    return 'Mise à niveau de la base de données (étape $step sur $total)...';
  }

  @override
  String backup_restore_dialog_counts(int diveCount, int siteCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount plongées',
      one: '1 plongée',
    );
    String _temp1 = intl.Intl.pluralLogic(
      siteCount,
      locale: localeName,
      other: '$siteCount sites',
      one: '1 site',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get backup_restore_preMigration_title =>
      'Restaurer la sauvegarde avant migration';

  @override
  String get backup_restore_preMigration_unknownVersion => 'version inconnue';

  @override
  String get backup_restore_preMigration_restoreAnyway =>
      'Restaurer quand même';

  @override
  String backup_restore_preMigration_incompleteMetadata(
    String timestamp,
    String appVersion,
  ) {
    return 'Cette sauvegarde a été créée le $timestamp par l’application $appVersion, mais ses métadonnées de migration de base de données sont incomplètes.\n\nL’application ne peut pas vérifier si la restauration de cette sauvegarde est sûre, la restauration est donc désactivée.';
  }

  @override
  String backup_restore_preMigration_newerApp(
    String timestamp,
    String appVersion,
    int fromVersion,
  ) {
    return 'Cette sauvegarde est plus récente que votre application. Installez une version plus récente de l’application pour la restaurer.\n\nSauvegarde créée le $timestamp par l’application $appVersion (base de données v$fromVersion).';
  }

  @override
  String backup_restore_preMigration_safe(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
  ) {
    return 'Cette sauvegarde a été créée le $timestamp par l’application $appVersion, juste avant la mise à niveau de la base de données de v$fromVersion vers v$toVersion.\n\nLe schéma de base de données de votre application correspond à cette sauvegarde, la restauration est donc sûre.';
  }

  @override
  String backup_restore_preMigration_warning(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
    int currentVersion,
  ) {
    return 'Cette sauvegarde a été créée le $timestamp par l’application $appVersion, juste avant la mise à niveau de la base de données de v$fromVersion vers v$toVersion.\n\nVous utilisez une application plus récente (base de données v$currentVersion).\n\nRestaurer maintenant relancera la mise à niveau de la base de données de v$fromVersion vers v$toVersion sur vos données restaurées, c’est-à-dire exactement la mise à niveau qui devait s’exécuter à l’origine. Si cette mise à niveau est à l’origine du problème, vous le rencontrerez à nouveau.\n\nPour restaurer en toute sécurité : installez l’application $appVersion ou une version antérieure, puis restaurez cette sauvegarde depuis cette application plus ancienne.';
  }

  @override
  String get settings_cloudSync_progress_preparing =>
      'Préparation de la synchronisation...';

  @override
  String get settings_cloudSync_progress_pulling =>
      'Récupération des modifications...';

  @override
  String get settings_cloudSync_progress_publishing =>
      'Publication des modifications...';

  @override
  String settings_cloudSync_progress_uploadingLibrary(int uploaded, int total) {
    return 'Envoi de la bibliothèque ($uploaded sur $total)';
  }

  @override
  String get settings_cloudSync_result_noProvider =>
      'Aucun fournisseur cloud configuré';

  @override
  String get settings_cloudSync_result_notAuthenticated =>
      'Non authentifié auprès du fournisseur cloud';

  @override
  String get settings_cloudSync_result_timedOut =>
      'Délai de synchronisation dépassé';

  @override
  String get settings_cloudSync_result_epochMarkerUnreadable =>
      'Impossible de lire le marqueur d’époque de la bibliothèque';

  @override
  String get settings_cloudSync_result_epochMarkerEncrypted =>
      'Le marqueur d’époque de la bibliothèque est chiffré';

  @override
  String get settings_cloudSync_result_libraryReplacedRemotely =>
      'La bibliothèque cloud a été remplacée depuis une sauvegarde';

  @override
  String get settings_cloudSync_result_noReplacementToRebuild =>
      'Aucun remplacement de bibliothèque à partir duquel reconstruire';

  @override
  String get settings_cloudSync_result_rebuiltFromThisDevice =>
      'Ce service a été reconstruit à partir de la bibliothèque de cet appareil';

  @override
  String settings_cloudSync_result_rebuildFailed(String error) {
    return 'Échec de la reconstruction : $error';
  }

  @override
  String get settings_cloudSync_result_libraryReplaced =>
      'Bibliothèque remplacée';

  @override
  String settings_cloudSync_result_libraryReplaceFailed(String error) {
    return 'Échec du remplacement de la bibliothèque : $error';
  }

  @override
  String get settings_cloudSync_result_noReplacementMarker =>
      'Aucun marqueur de remplacement de bibliothèque trouvé';

  @override
  String get settings_cloudSync_result_adoptedRestoredLibrary =>
      'Bibliothèque restaurée adoptée';

  @override
  String settings_cloudSync_result_adoptFailed(String error) {
    return 'Échec de l’adoption de la bibliothèque restaurée : $error';
  }

  @override
  String get settings_cloudSync_result_previousLibraryUnreadable =>
      'La bibliothèque précédente n’a pas pu être lue ; ce service a été rétabli à partir de la bibliothèque de cet appareil.';

  @override
  String get settings_cloudSync_result_replacementStillUploading =>
      'La bibliothèque remplacée est encore en cours d’envoi. Réessayez dans un instant.';

  @override
  String settings_cloudSync_result_recordsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enregistrements n’ont pas pu être appliqués',
      one: '1 enregistrement n’a pas pu être appliqué',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_result_adoptedFreshIdentity =>
      'Un autre appareil se synchronisait avec l’identité de cet appareil. Cet appareil a adopté une nouvelle identité et a fusionné les données du cloud.';

  @override
  String settings_cloudSync_launchCheck_unavailable(String provider) {
    return '$provider n’est pas disponible sur cet appareil';
  }

  @override
  String settings_cloudSync_launchCheck_notSignedIn(String provider) {
    return 'Non connecté à $provider';
  }

  @override
  String settings_cloudSync_launchCheck_localChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications locales à envoyer',
      one: '1 modification locale à envoyer',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_launchCheck_noRemoteData =>
      'Aucune donnée de synchronisation trouvée dans le cloud';

  @override
  String get settings_cloudSync_launchCheck_cloudDataAvailable =>
      'Données cloud disponibles';

  @override
  String get settings_cloudSync_launchCheck_updatesAvailable =>
      'Mises à jour disponibles depuis le cloud';

  @override
  String get settings_cloudSync_launchCheck_upToDate => 'Tout est à jour';

  @override
  String settings_cloudSync_launchCheck_failed(String error) {
    return 'Échec de la vérification de synchronisation : $error';
  }

  @override
  String get diveLog_detail_viewMap => 'Carte';

  @override
  String get diveLog_detail_view3d => '3D';

  @override
  String get setup_sync_icloudUnavailable =>
      'iCloud n\'est pas disponible sur cet appareil';

  @override
  String get media_info_title => 'Infos du média';

  @override
  String get media_info_fileSection => 'Fichier';

  @override
  String get media_info_filename => 'Nom du fichier';

  @override
  String get media_info_type => 'Type';

  @override
  String get media_info_dimensions => 'Dimensions';

  @override
  String get media_info_size => 'Taille';

  @override
  String get media_info_taken => 'Prise le';

  @override
  String get media_info_coordinates => 'Coordonnées';

  @override
  String get media_info_unknown => 'Inconnu';

  @override
  String get media_info_originSection => 'Origine';

  @override
  String get media_info_source => 'Source';

  @override
  String get media_info_reference => 'Référence';

  @override
  String get media_info_linkedOn => 'Liée sur';

  @override
  String get media_info_thisDevice => 'Cet appareil';

  @override
  String get media_info_otherDevice => 'Un autre appareil';

  @override
  String get media_info_status => 'État';

  @override
  String get media_info_statusFound => 'Trouvée sur cet appareil';

  @override
  String get media_info_statusMissing => 'Absente de cet appareil';

  @override
  String get media_info_statusUnchecked => 'Pas encore vérifiée';

  @override
  String media_info_lastChecked(String date) {
    return 'Dernière vérification $date';
  }

  @override
  String get media_timeInDive_label => 'Moment dans la plongée';

  @override
  String get media_timeInDive_unknown => 'Moment dans la plongée inconnu';

  @override
  String get media_timeInDive_setAction => 'Définir le moment dans la plongée';

  @override
  String media_timeInDive_manual(String time) {
    return '$time (défini manuellement)';
  }

  @override
  String get media_timeInDive_fieldLabel =>
      'Temps depuis le début de la plongée';

  @override
  String get media_timeInDive_fieldHint => 'mm:ss';

  @override
  String media_timeInDive_range(String max) {
    return 'Entre 0:00 et $max';
  }

  @override
  String media_timeInDive_invalid(String max) {
    return 'Saisissez un temps entre 0:00 et $max';
  }

  @override
  String get media_timeInDive_save => 'Enregistrer';

  @override
  String get media_timeInDive_cancel => 'Annuler';

  @override
  String get media_timeInDive_reset => 'Rétablir le mode automatique';

  @override
  String get media_info_backupSection => 'Sauvegarde';

  @override
  String get media_info_store => 'Stockage cloud';

  @override
  String get media_info_storeNotConnected => 'Aucun stockage cloud connecté';

  @override
  String get media_info_notEligible =>
      'Cette source ne peut pas être sauvegardée';

  @override
  String get media_info_backupFull => 'Original téléversé';

  @override
  String get media_info_backupThumbOnly =>
      'Miniature seulement, original non envoyé';

  @override
  String get media_info_backupRenditionOnly => 'Version compressée téléversée';

  @override
  String get media_info_backupNone => 'Non sauvegardée';

  @override
  String media_info_uploadedOn(String date) {
    return 'Téléversée $date';
  }

  @override
  String get media_info_queuePending => 'En attente de téléversement';

  @override
  String get media_info_queueTransferring => 'Téléversement en cours';

  @override
  String media_info_queueFailed(Object error) {
    return 'Échec du téléversement : $error';
  }

  @override
  String get media_info_servingSection => 'Source actuelle';

  @override
  String get media_info_servingUnobserved => 'Pas encore chargée';

  @override
  String get media_info_servingFailed => 'Impossible à charger';

  @override
  String get media_info_servedLocalDisk => 'Fichier local sur cet appareil';

  @override
  String get media_info_servedGallery => 'Photheque';

  @override
  String get media_info_servedStoreCache =>
      'Cache local, depuis le stockage cloud';

  @override
  String get media_info_servedStoreNetwork =>
      'Téléchargée depuis le stockage cloud';

  @override
  String get media_info_servedNetworkUrl => 'Diffusion depuis une URL';

  @override
  String get media_info_servedConnectorCache =>
      'Cache local, depuis le service connecté';

  @override
  String get media_info_servedConnectorNetwork =>
      'Téléchargée depuis le service connecté';

  @override
  String get media_info_servedEmbedded => 'Stockée dans ce carnet';

  @override
  String get media_info_servingFallbackNote =>
      'La source d\'origine était inaccessible, le stockage cloud a donc pris le relais.';

  @override
  String get media_info_servingTierThumbnail => 'Miniature';

  @override
  String get media_info_servingTierRendition => 'Version compressée';

  @override
  String get media_info_typePhoto => 'Photo';

  @override
  String get media_info_typeVideo => 'Vidéo';

  @override
  String get media_info_typeDocument => 'Document';

  @override
  String get media_info_typeSignature => 'Signature';

  @override
  String get media_info_actionCheckNow => 'Vérifier maintenant';

  @override
  String get media_info_actionLocate => 'Localiser le fichier...';

  @override
  String get media_info_actionBackUpNow => 'Sauvegarder maintenant';

  @override
  String get media_info_actionRetryUpload => 'Réessayer le téléversement';

  @override
  String get media_info_actionReveal =>
      'Afficher dans le gestionnaire de fichiers';

  @override
  String get media_info_actionCopyPath => 'Copier la référence';

  @override
  String get media_info_referenceCopied => 'Référence copiée';

  @override
  String get media_info_checkFound => 'Source trouvée';

  @override
  String get media_info_checkMissing => 'Source introuvable';

  @override
  String get media_info_checkUnavailable =>
      'Vérification impossible pour le moment';

  @override
  String get media_info_backupQueued => 'Mis en file pour téléversement';

  @override
  String get enum_profileMetric_o2CellMv => 'Cellules O2';

  @override
  String get enum_profileMetric_o2CellMv_short => 'Cellules';

  @override
  String get diveLog_o2CellSpread_label => 'Écart des cellules O2';

  @override
  String get media_status_broken => 'Absent et non sauvegardé';

  @override
  String get media_servedFrom_localDisk => 'Sur cet appareil';

  @override
  String get media_servedFrom_platformGallery => 'Photothèque';

  @override
  String get media_servedFrom_storeCache => 'Stockage cloud, en cache ici';

  @override
  String get media_servedFrom_storeNetwork => 'Stockage cloud';

  @override
  String get media_servedFrom_networkUrl => 'Lien web';

  @override
  String get media_servedFrom_connectorCache =>
      'Service connecté, en cache ici';

  @override
  String get media_servedFrom_connectorNetwork => 'Service connecté';

  @override
  String get media_servedFrom_embedded => 'Enregistré dans ce carnet';

  @override
  String get settings_media_provenanceBadges =>
      'Afficher les badges de source sur les vignettes';

  @override
  String get settings_media_provenanceBadgesSubtitle =>
      'Une petite icône indiquant d\'où provient chaque élément. Les badges de problème restent toujours visibles.';

  @override
  String get media_status_transferFailed => 'Échec du téléversement';

  @override
  String get media_status_transferring => 'Téléversement en cours';

  @override
  String get media_status_queued => 'En attente de téléversement';

  @override
  String get media_status_cloudOnly => 'Stocké uniquement dans le cloud';

  @override
  String get media_status_notBackedUp => 'Non sauvegardé';

  @override
  String get media_tile_infoMenuItem => 'Infos du média';

  @override
  String get diveImport_healthkit_accessGrantedHint =>
      'Apple Santé n\'indique jamais aux apps si l\'accès en lecture a été accordé. Si aucune plongée n\'apparaît, ouvrez Santé, puis Partage, Apps, Submersion, et activez Entraînements, Profondeur sous l\'eau, Température de l\'eau et Fréquence cardiaque.';

  @override
  String get diveImport_healthkit_foundNoDivesHint =>
      'Aucun entraînement de plongée sur cette période. Vérifiez que les dates couvrent la plongée et que Santé, Partage, Apps, Submersion autorise Entraînements et Profondeur sous l\'eau.';

  @override
  String get settings_dataSources_appleHealth_dataTypeDepth =>
      'Profondeur sous l\'eau - mesures de profondeur enregistrées pendant les plongées';

  @override
  String get settings_dataSources_appleHealth_dataTypeWaterTemp =>
      'Température de l\'eau - mesures de température enregistrées pendant les plongées';

  @override
  String get settings_dataSources_appleHealth_permissionManagedInHealth =>
      'L\'accès à HealthKit se gère dans l\'app Santé';

  @override
  String get settings_dataSources_appleHealth_permissionUnsupported =>
      'HealthKit n\'est pas disponible sur cet appareil';
}
