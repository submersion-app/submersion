// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get universalImport_action_importFromGarmin =>
      'Importálás Garmin eszközről';

  @override
  String diveLog_edit_flightWindowWarning(String time) {
    return 'Ez a merülés a járatod előtti utolsó biztonságos felszínre érési idő után ér véget ($time)';
  }

  @override
  String diveLog_edit_geofenceSuggestion_near(String location) {
    return '$location közelében';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_title => 'Felszerelési javaslat';

  @override
  String diveLog_edit_geofenceSuggestion_body(String setName) {
    return 'Alkalmazza a(z) \"$setName\" készletet?';
  }

  @override
  String get diveLog_edit_geofenceSuggestion_apply => 'Alkalmaz';

  @override
  String get common_action_dismiss => 'Elvetés';

  @override
  String get equipment_setEdit_defaultSwitch_title => 'Alapértelmezett készlet';

  @override
  String get equipment_setEdit_defaultSwitch_subtitle =>
      'Automatikusan alkalmazza az új, még felszerelés nélküli merülésekre';

  @override
  String get equipment_setEdit_geofencesTitle => 'Geokerítések';

  @override
  String get equipment_setEdit_geofencesSubtitle =>
      'Automatikusan javasolja ezt a készletet az e helyek közelében végzett merülésekhez';

  @override
  String get equipment_setEdit_addGeofence => 'Geokerítés hozzáadása';

  @override
  String get equipment_setEdit_editGeofence => 'Edit geofence';

  @override
  String get equipment_setEdit_removeGeofence => 'Remove geofence';

  @override
  String equipment_setEdit_geofenceRadius(String distance) {
    return 'Sugár: $distance';
  }

  @override
  String get equipment_geofenceEditor_title => 'Geokerítés';

  @override
  String get equipment_geofenceEditor_fromSite => 'Merülőhelyről';

  @override
  String get equipment_geofenceEditor_dropPin => 'Gombostű elhelyezése';

  @override
  String get equipment_geofenceEditor_labelLabel => 'Címke';

  @override
  String get equipment_geofenceEditor_noCenter => 'Válasszon középpontot';

  @override
  String get equipment_geofenceEditor_save => 'Geokerítés mentése';

  @override
  String get equipment_sets_defaultBadge => 'Alapértelmezett';

  @override
  String get equipment_setDetail_setAsDefault =>
      'Beállítás alapértelmezettként';

  @override
  String equipment_setDetail_setAsDefaultSnackbar(String name) {
    return 'A(z) \"$name\" mostantól az alapértelmezett készleted';
  }

  @override
  String get equipment_setDetail_geofencesTitle => 'Geokerítések';

  @override
  String get equipment_setDetail_noGeofences => 'Nincsenek geokerítések';

  @override
  String formatter_duration_minutes(Object minutes) {
    return '$minutes perc';
  }

  @override
  String formatter_duration_minutesSeconds(Object minutes, Object seconds) {
    return '$minutes perc $seconds mp';
  }

  @override
  String formatter_duration_seconds(Object seconds) {
    return '$seconds mp';
  }

  @override
  String gasCalculators_bestMix_densityCritical(Object limit) {
    return 'A $limit g/L abszolut suruseghatar felett.';
  }

  @override
  String get gasCalculators_bestMix_densityLabel => 'Gazsuruseg a melysegben';

  @override
  String gasCalculators_bestMix_densityWarn(Object limit) {
    return 'Az ajanlott $limit g/L suruseghatar felett.';
  }

  @override
  String gasCalculators_bestMix_endExceeded(Object limit) {
    return 'Az END meghaladja a $limit korlatodat.';
  }

  @override
  String get gasCalculators_bestMix_endLabel => 'END a melysegben';

  @override
  String get gasCalculators_bestMix_endLimitLabel => 'END-korlat';

  @override
  String gasCalculators_bestMix_heliumAdded(Object limit) {
    return 'Helium hozzaadva, hogy az END a $limit korlaton belul maradjon.';
  }

  @override
  String get gasCalculators_bestMix_idealLabel => 'Idealis arany';

  @override
  String get gasCalculators_bestMix_marginLabel => 'Tartalek a MOD alatt';

  @override
  String gasCalculators_bestMix_modLabel(Object ppO2) {
    return 'MOD ppO2 $ppO2 mellett';
  }

  @override
  String get gasCalculators_bestMix_nearestStandard =>
      'A legkozelebbi szabvanykeverek erre a melysegre';

  @override
  String get gasCalculators_bestMix_recommendedMix => 'Ajanlott keverek';

  @override
  String get gasCalculators_bestMix_withoutHelium => 'Helium nelkul';

  @override
  String get gasCalculators_planningCaveat =>
      'Tervezesi becsles. Kozvetlen felmerulest feltetelez. Vesd ossze a kepzeseddel, es szamolj tartalekkal a korulmenyekre.';

  @override
  String gasCalculators_rockBottom_solveGas(Object depth, Object unit) {
    return 'Problemamegoldo gaz $depth$unit melysegben';
  }

  @override
  String get gasCalculators_rockBottom_solveTime => 'Problemamegoldasi ido';

  @override
  String get gasCalculators_rockBottom_solveTimeHint =>
      'A melysegben toltott ido a veszhelyzet megoldasara, mielott a felmerules elkezdodik.';

  @override
  String o2Toxicity_addedThisDive(Object value) {
    return '+$value ezen a merulesen';
  }

  @override
  String o2Toxicity_cnsProgressSemantics(Object percent) {
    return 'CNS elorehalads $percent szazalek';
  }

  @override
  String get o2Toxicity_daily => 'Napi';

  @override
  String o2Toxicity_otuSemantics(
    Object label,
    Object value,
    Object limit,
    Object percent,
  ) {
    return '$label: $value / $limit OTU, $percent szazalek';
  }

  @override
  String o2Toxicity_otuValueSemantics(Object label, Object value) {
    return '$label: $value OTU';
  }

  @override
  String o2Toxicity_prior(Object value) {
    return 'Korabbi: $value OTU';
  }

  @override
  String o2Toxicity_start(Object value) {
    return 'Kezdet: $value OTU';
  }

  @override
  String get o2Toxicity_thisDive => 'Ez a merules';

  @override
  String get o2Toxicity_weekly => 'Heti';

  @override
  String trips_story_dayLabel(int number) {
    return '$number. nap';
  }

  @override
  String get trips_story_surfaceDay => 'Felszíni nap';

  @override
  String get trips_story_today => 'Ma';

  @override
  String trips_story_dayOfTrip(int current, int total) {
    return '$current. nap a(z) $total napból';
  }

  @override
  String trips_story_daysUntil(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days nap az indulásig',
      one: '1 nap az indulásig',
    );
    return '$_temp0';
  }

  @override
  String trips_story_checklistProgress(int done, int total) {
    return '$done/$total kész';
  }

  @override
  String get trips_story_generateItinerary => 'Útiterv létrehozása';

  @override
  String get trips_story_openGallery => 'Utazási fotók megnyitása';

  @override
  String trips_story_generateItineraryError(String error) {
    return 'Nem sikerült létrehozni az útitervet: $error';
  }

  @override
  String get trips_dayType_diveDay => 'Merülőnap';

  @override
  String get trips_dayType_seaDay => 'Tengeri nap';

  @override
  String get trips_dayType_portDay => 'Kikötői nap';

  @override
  String get trips_dayType_embark => 'Beszállás';

  @override
  String get trips_dayType_disembark => 'Kiszállás';

  @override
  String get trips_story_planned => 'Tervezett';

  @override
  String get trips_story_empty_title => 'Még nincs merülés vagy útiterv';

  @override
  String get trips_story_empty_subtitle =>
      'Adj hozzá merüléseket vagy tervezd meg a napokat a történethez.';

  @override
  String trips_story_history_dives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count korábbi merülés itt',
      one: '1 korábbi merülés itt',
    );
    return '$_temp0';
  }

  @override
  String trips_story_history_avgTemp(String value) {
    return 'átlag $value';
  }

  @override
  String trips_story_history_avgDepth(String value) {
    return 'átl. mélység $value';
  }

  @override
  String get trips_story_rhythm_semantics => 'A nap merülési idői';

  @override
  String get trips_story_map_semantics =>
      'Úti térkép. A látható nap helyszínei kiemelve.';

  @override
  String get diveLog_bulkEdit_groupRebreather => 'Merülési mód és rebreather';

  @override
  String get diveLog_bulkEdit_fieldSetpointLow => 'Alacsony alapérték';

  @override
  String get diveLog_bulkEdit_fieldSetpointHigh => 'Magas alapérték';

  @override
  String get diveLog_bulkEdit_fieldSetpointDeco => 'Dekó alapérték';

  @override
  String get diveLog_bulkEdit_fieldScrubberType => 'Abszorber típusa';

  @override
  String get diveLog_bulkEdit_fieldScrubberDuration => 'Abszorber időtartama';

  @override
  String get diveLog_bulkEdit_contradiction =>
      'Az OC mód nem tartalmazhat rebreather beállításokat. Kapcsold ki ezeket a mezőket, vagy változtasd meg a módot.';

  @override
  String diveLog_bulkEdit_appBarTitle(int count) {
    return '$count merülés szerkesztése';
  }

  @override
  String get diveLog_bulkEdit_groupLogistics => 'Logisztika';

  @override
  String get diveLog_bulkEdit_groupWeather => 'Időjárás';

  @override
  String get diveLog_bulkEdit_groupCollections =>
      'Címkék, felszerelés és élővilág';

  @override
  String get diveLog_bulkEdit_fieldFavorite => 'Kedvenc';

  @override
  String get diveLog_bulkEdit_fieldMyRole => 'Saját szerep';

  @override
  String get diveLog_bulkEdit_buddyRoleMixed => 'Vegyes';

  @override
  String get diveLog_bulkEdit_collectionWeights => 'Súlyok';

  @override
  String get diveLog_bulkEdit_collectionTanks => 'Palackok';

  @override
  String get diveLog_bulkEdit_notesSet => 'Beállítás';

  @override
  String get diveLog_bulkEdit_notesAppend => 'Hozzáfűzés';

  @override
  String get diveLog_bulkEdit_modeAdd => 'Hozzáadás';

  @override
  String get diveLog_bulkEdit_modeRemove => 'Eltávolítás';

  @override
  String get diveLog_bulkEdit_modeReplace => 'Csere';

  @override
  String get diveLog_bulkEdit_modeUpdate => 'Frissítés';

  @override
  String get diveLog_bulkEdit_tankOnlyIfEmpty =>
      'Csak a meglévő palack nélküli merülések';

  @override
  String get diveLog_bulkEdit_tankSpecsHint =>
      'Válaszd ki, mely tulajdonságok íródjanak felül a merülésekhez már tartozó palackokon. A kezdő és a záró nyomás soha nem változik.';

  @override
  String get diveLog_bulkEdit_tankSpecsNoFields =>
      'Válassz legalább egy palacktulajdonságot a frissítéshez.';

  @override
  String get diveLog_bulkEdit_tankFieldPreset => 'Előbeállítás';

  @override
  String get diveLog_bulkEdit_tankFieldRole => 'Szerep';

  @override
  String get diveLog_bulkEdit_tankFieldVolume => 'Térfogat';

  @override
  String get diveLog_bulkEdit_tankFieldWorkingPressure => 'Üzemi nyomás';

  @override
  String get diveLog_bulkEdit_tankFieldMaterial => 'Anyag';

  @override
  String get diveLog_bulkEdit_tankFieldGasMix => 'Gázkeverék';

  @override
  String get diveLog_bulkEdit_tankFieldName => 'Név';

  @override
  String diveLog_bulkEdit_tankSpecsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kiválasztott merüléshez nincs palack, ezért kimaradnak.',
      one: '1 kiválasztott merüléshez nincs palack, ezért kimarad.',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_bulkEdit_confirmTitle => 'Alkalmazza a módosításokat?';

  @override
  String get diveLog_bulkEdit_confirmApply => 'Alkalmaz';

  @override
  String get diveLog_bulkEdit_nothingSelected =>
      'Engedélyezzen legalább egy mezőt a módosítások alkalmazásához.';

  @override
  String diveLog_bulkEdit_applied(int count) {
    return '$count merülés frissítve';
  }

  @override
  String get settings_cloudSync_error_icloudSignedOut =>
      'Az iCloud nem érhető el. Jelentkezz be az iCloudba a készülék beállításaiban.';

  @override
  String get settings_cloudSync_error_icloudUnknown =>
      'Nem sikerült elérni az iCloudot. Próbáld újra.';

  @override
  String get settings_cloudSync_error_icloudUnsupported =>
      'Az iCloud-szinkronizálás nem érhető el a Submersion ezen buildjében. Használd az S3-szinkronizálást vagy az App Store-verziót.';

  @override
  String get settings_cloudSync_provider_icloud_unsupportedSubtitle =>
      'Ebben a buildben nem érhető el – használj S3-at vagy az App Store-verziót';

  @override
  String get settings_cloudSync_encryption_title =>
      'Végpontok közötti titkosítás';

  @override
  String get settings_cloudSync_encryption_subtitleOff =>
      'Minden szinkronizálási adat és felhőmentés titkosítása feltöltés előtt';

  @override
  String get settings_cloudSync_encryption_subtitleNeedsProvider =>
      'Előbb válasszon felhőszolgáltatót';

  @override
  String get settings_cloudSync_encryption_statusOff =>
      'A titkosítás ki van kapcsolva';

  @override
  String get settings_cloudSync_encryption_statusOn =>
      'A titkosítás be van kapcsolva';

  @override
  String get settings_cloudSync_encryption_statusOnSubtitle =>
      'A szinkronizálási adatok és a felhőmentések feltöltés előtt titkosítva lesznek';

  @override
  String get settings_cloudSync_encryption_statusLocked =>
      'Titkosítva — jelmondat szükséges';

  @override
  String get settings_cloudSync_encryption_statusLockedSubtitle =>
      'Adja meg a jelmondatot a szinkronizáláshoz ezen az eszközön';

  @override
  String get settings_cloudSync_encryption_enable => 'Titkosítás bekapcsolása';

  @override
  String get settings_cloudSync_encryption_enterPassphrase =>
      'Jelmondat megadása';

  @override
  String get settings_cloudSync_encryption_passphrase => 'Jelmondat';

  @override
  String get settings_cloudSync_encryption_passphraseConfirm =>
      'Jelmondat megerősítése';

  @override
  String get settings_cloudSync_encryption_passphraseMismatch =>
      'A jelmondatok nem egyeznek';

  @override
  String get settings_cloudSync_encryption_passphraseTooShort =>
      'Legalább 8 karaktert használjon';

  @override
  String get settings_cloudSync_encryption_wrongPassphrase =>
      'Hibás jelmondat vagy helyreállítási kód';

  @override
  String get settings_cloudSync_encryption_warnUpdateDevices =>
      'Minden más eszközt a legújabb alkalmazásverzióra kell frissíteni, és újra letöltik a könyvtárat.';

  @override
  String get settings_cloudSync_encryption_warnLoss =>
      'Ha a jelmondat és a helyreállítási kód is elvész, a felhőben lévő adatok nem állíthatók helyre. Az eszközein lévő adatok soha nincsenek veszélyben.';

  @override
  String get settings_cloudSync_encryption_deletePlaintextBackups =>
      'Meglévő titkosítatlan felhőmentések törlése';

  @override
  String get settings_cloudSync_encryption_recoveryTitle =>
      'Helyreállítási kód';

  @override
  String get settings_cloudSync_encryption_recoveryExplain =>
      'Írja fel ezt a kódot, és őrizze biztonságos helyen. Ez az egyetlen visszaút, ha elfelejti a jelmondatot.';

  @override
  String get settings_cloudSync_encryption_recoverySavedConfirm =>
      'Elmentettem a helyreállítási kódomat';

  @override
  String get settings_cloudSync_encryption_changePassphrase =>
      'Jelmondat módosítása';

  @override
  String get settings_cloudSync_encryption_currentPassphrase =>
      'Jelenlegi jelmondat';

  @override
  String get settings_cloudSync_encryption_newPassphrase => 'Új jelmondat';

  @override
  String get settings_cloudSync_encryption_regenerateRecovery =>
      'Új helyreállítási kód létrehozása';

  @override
  String get settings_cloudSync_encryption_regenerateRecoveryWarn =>
      'A régi helyreállítási kód azonnal érvénytelenné válik.';

  @override
  String get settings_cloudSync_encryption_disable => 'Titkosítás kikapcsolása';

  @override
  String get settings_cloudSync_encryption_disableWarn =>
      'A könyvtár titkosítatlanul lesz újra feltöltve, és a többi eszköz újra letölti. A meglévő titkosított mentések a jelmondattal továbbra is visszaállíthatók.';

  @override
  String get settings_cloudSync_encryption_unlockTitle =>
      'Adja meg a titkosítási jelmondatot';

  @override
  String get settings_cloudSync_encryption_unlockHint =>
      'Jelmondat vagy helyreállítási kód';

  @override
  String get settings_cloudSync_encryption_unlock => 'Feloldás';

  @override
  String get settings_cloudSync_encryption_continue => 'Folytatás';

  @override
  String get settings_cloudSync_encryption_done => 'Kész';

  @override
  String get settings_cloudSync_encryption_cancel => 'Mégse';

  @override
  String get settings_backupEncryption_title => 'Biztonsági mentés titkosítása';

  @override
  String get settings_backupEncryption_subtitleOff =>
      'Védje a biztonsági mentéseit jelszóval';

  @override
  String get settings_backupEncryption_subtitleOn =>
      'A biztonsági mentések a jelszavával vannak titkosítva';

  @override
  String get settings_backupEncryption_enable =>
      'Biztonsági mentések titkosítása';

  @override
  String get settings_backupEncryption_turnOff => 'Titkosítás kikapcsolása';

  @override
  String get settings_backupEncryption_turnOffTitle =>
      'Kikapcsolja a biztonsági mentés titkosítását?';

  @override
  String get settings_backupEncryption_turnOffBody =>
      'Az új biztonsági mentések többé nem lesznek titkosítva. A meglévő titkosított mentések visszaállításához továbbra is szükség van a jelszavára.';

  @override
  String get settings_backupEncryption_changePassword => 'Jelszó módosítása';

  @override
  String get settings_backupEncryption_regenerateRecovery =>
      'Új helyreállítási kód létrehozása';

  @override
  String get settings_backupEncryption_password => 'Jelszó';

  @override
  String get settings_backupEncryption_passwordConfirm => 'Jelszó megerősítése';

  @override
  String get settings_backupEncryption_passwordTooShort =>
      'Legalább 8 karaktert használjon';

  @override
  String get settings_backupEncryption_passwordMismatch =>
      'A jelszavak nem egyeznek';

  @override
  String get settings_backupEncryption_currentPassword => 'Jelenlegi jelszó';

  @override
  String get settings_backupEncryption_newPassword => 'Új jelszó';

  @override
  String get settings_backupEncryption_changePasswordWarn =>
      'Másik eszközön minden biztonsági mentés azzal a jelszóval vagy helyreállítási kóddal nyílik meg, amely a létrehozásakor aktív volt.';

  @override
  String get settings_backupEncryption_warnLoss =>
      'Ha elfelejti a jelszavát és elveszíti a helyreállítási kódot, a titkosított biztonsági mentések nem állíthatók helyre.';

  @override
  String get settings_backupEncryption_recoveryTitle =>
      'A helyreállítási kódja';

  @override
  String get settings_backupEncryption_recoveryExplain =>
      'Mentse el ezt a kódot biztonságos helyre. Feloldhatja vele a biztonsági mentéseit, ha elfelejti a jelszavát.';

  @override
  String get settings_backupEncryption_recoverySavedConfirm =>
      'Elmentettem a helyreállítási kódomat';

  @override
  String get settings_backupEncryption_unlockTitle =>
      'Adja meg a biztonsági mentés jelszavát';

  @override
  String get settings_backupEncryption_unlockHint =>
      'Adja meg a biztonsági mentés jelszavát vagy a helyreállítási kódot';

  @override
  String get settings_backupEncryption_restoreUnlockTitle =>
      'Titkosított biztonsági mentés feloldása';

  @override
  String get settings_backupEncryption_restoreUnlockHint =>
      'Add meg a biztonsági mentés jelszavát vagy helyreállítási kódját';

  @override
  String get settings_backupEncryption_continue => 'Folytatás';

  @override
  String get settings_backupEncryption_cancel => 'Mégse';

  @override
  String get settings_backupEncryption_done => 'Kész';

  @override
  String get settings_backupEncryption_reencryptTitle =>
      'Titkosítja a meglévő biztonsági mentéseket?';

  @override
  String get settings_backupEncryption_reencryptBody =>
      'A meglévő biztonsági mentései még titkosítatlanok. Titkosítja őket most az új jelszavával?';

  @override
  String get settings_backupEncryption_reencryptNow => 'Titkosítás most';

  @override
  String get settings_backupEncryption_reencryptNotNow => 'Most nem';

  @override
  String settings_backupEncryption_reencryptPartial(int done, int failed) {
    return '$done biztonsági mentés újratitkosítva; $failed nem sikerült titkosítani, ezek továbbra is védtelenek';
  }

  @override
  String settings_backupEncryption_reencryptDone(int count) {
    return '$count biztonsági mentés újratitkosítva';
  }

  @override
  String get settings_backupEncryption_wrongPassword =>
      'Hibás jelszó vagy helyreállítási kód';

  @override
  String settings_cloudSync_replace_globalBanner(String deviceName) {
    return 'A szinkronizálás szünetel — a könyvtárat egy biztonsági másolatból cserélték itt: \"$deviceName\".';
  }

  @override
  String get settings_cloudSync_postRestore_syncing =>
      'A visszaállított könyvtár szinkronizálása a felhővel…';

  @override
  String get settings_cloudSync_postRestore_synced =>
      'A visszaállított könyvtár szinkronizálva.';

  @override
  String get settings_cloudSync_replace_reviewAction => 'Áttekintés';

  @override
  String get accessibility_dialog_keyboardShortcutsTitle =>
      'Billentyuparancsok';

  @override
  String get accessibility_keyLabel_backspace => 'Backspace';

  @override
  String get accessibility_keyLabel_delete => 'Delete';

  @override
  String get accessibility_keyLabel_down => 'Le';

  @override
  String get accessibility_keyLabel_enter => 'Enter';

  @override
  String get accessibility_keyLabel_esc => 'Esc';

  @override
  String get accessibility_keyLabel_left => 'Bal';

  @override
  String get accessibility_keyLabel_right => 'Jobb';

  @override
  String get accessibility_keyLabel_up => 'Fel';

  @override
  String accessibility_label_chartSummary(
    Object chartType,
    Object description,
  ) {
    return '$chartType diagram. $description';
  }

  @override
  String get accessibility_label_createNewItem => 'Uj elem letrehozasa';

  @override
  String get accessibility_label_hideList => 'Lista elrejtese';

  @override
  String get accessibility_label_hideMapView => 'Terkepi nezet elrejtese';

  @override
  String accessibility_label_listPane(Object title) {
    return '$title lista panel';
  }

  @override
  String accessibility_label_mapPane(Object title) {
    return '$title terkep panel';
  }

  @override
  String accessibility_label_mapViewTitle(Object title) {
    return '$title terkepi nezet';
  }

  @override
  String get accessibility_label_resizeMasterPane => 'Fo panel atmeretezese';

  @override
  String get accessibility_label_sharedWithAllProfiles =>
      'Megosztva az összes búvárprofillal';

  @override
  String get accessibility_label_showList => 'Lista megjelenitese';

  @override
  String get accessibility_label_showMapView => 'Terkepi nezet megjelenitese';

  @override
  String get accessibility_label_viewDetails => 'Reszletek megtekintese';

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
  String get accessibility_shortcutCategory_editing => 'Szerkesztes';

  @override
  String get accessibility_shortcutCategory_general => 'Altalanos';

  @override
  String get accessibility_shortcutCategory_help => 'Sugo';

  @override
  String get accessibility_shortcutCategory_navigation => 'Navigacio';

  @override
  String get accessibility_shortcutCategory_search => 'Kereses';

  @override
  String get accessibility_shortcut_closeCancel => 'Bezaras / Megse';

  @override
  String get accessibility_shortcut_goBack => 'Vissza';

  @override
  String get accessibility_shortcut_goToDives => 'Ugras a merulesekhez';

  @override
  String get accessibility_shortcut_goToEquipment => 'Ugras a felszereleshez';

  @override
  String get accessibility_shortcut_goToSettings => 'Ugras a beallitasokhoz';

  @override
  String get accessibility_shortcut_goToSites => 'Ugras a merulohelyekhez';

  @override
  String get accessibility_shortcut_goToStatistics => 'Ugras a statisztikakhoz';

  @override
  String get accessibility_shortcut_keyboardShortcuts => 'Billentyuparancsok';

  @override
  String get accessibility_shortcut_newDive => 'Uj merules';

  @override
  String get accessibility_shortcut_openSettings => 'Beallitasok megnyitasa';

  @override
  String get accessibility_shortcut_searchDives => 'Merulesek keresese';

  @override
  String accessibility_sort_selectedLabel(Object displayName) {
    return 'Rendezes: $displayName, jelenleg kivalasztva';
  }

  @override
  String accessibility_sort_unselectedLabel(Object displayName) {
    return 'Rendezes: $displayName';
  }

  @override
  String get backup_appBar_title => 'Biztonsági Mentés és Visszaállítás';

  @override
  String get backup_backingUp => 'Mentés folyamatban...';

  @override
  String get backup_backupNow => 'Mentés Most';

  @override
  String get backup_cloud_enabled => 'Felhő mentés';

  @override
  String get backup_cloud_enabled_subtitle =>
      'Mentések feltöltése a felhőtárhelyre';

  @override
  String get backup_delete_dialog_cancel => 'Mégse';

  @override
  String get backup_delete_dialog_content =>
      'Ez a biztonsági mentés véglegesen törlésre kerül. Ez a művelet nem vonható vissza.';

  @override
  String get backup_delete_dialog_delete => 'Törlés';

  @override
  String get backup_delete_dialog_title => 'Mentés Törlése';

  @override
  String get backup_export_bottomSheet_title => 'Mentés exportálása';

  @override
  String get backup_export_saveToFile => 'Mentés fájlba';

  @override
  String get backup_export_saveToFile_subtitle =>
      'Válassza ki, hová mentse a biztonsági mentés fájlt';

  @override
  String get backup_export_share => 'Megosztás';

  @override
  String get backup_export_share_subtitle =>
      'Küldés AirDrop, e-mail vagy más alkalmazáson keresztül';

  @override
  String get backup_export_subtitle => 'Merülési adatok mentése fájlba';

  @override
  String get backup_export_success => 'Biztonsági mentés sikeresen exportálva';

  @override
  String get backup_export_title => 'Mentés exportálása';

  @override
  String get backup_frequency_daily => 'Napi';

  @override
  String get backup_frequency_monthly => 'Havi';

  @override
  String get backup_frequency_weekly => 'Heti';

  @override
  String get backup_history_action_delete => 'Törlés';

  @override
  String get backup_history_action_restore => 'Visszaállítás';

  @override
  String get backup_history_empty => 'Nincsenek mentések';

  @override
  String backup_history_error(Object error) {
    return 'Hiba az előzmények betöltésekor: $error';
  }

  @override
  String get backup_history_pinAction_pin => 'Biztonsagi mentes rogzitese';

  @override
  String get backup_history_pinAction_unpin => 'Rogzites megszuntetese';

  @override
  String get backup_history_pinError =>
      'Nem sikerult a rogzites allapotat frissiteni.';

  @override
  String backup_history_preMigrationSubtitle(String size) {
    return 'Migracio elotti mentes - $size';
  }

  @override
  String get backup_import_invalidFile =>
      'Ez a fájl nem tűnik érvényes Submersion biztonsági mentésnek';

  @override
  String get backup_import_subtitle =>
      'Biztonsági mentés importálása bármely helyről';

  @override
  String get backup_import_title => 'Visszaállítás fájlból';

  @override
  String get backup_import_validating =>
      'Biztonsági mentés fájl ellenőrzése...';

  @override
  String get backup_location_change => 'Módosítás';

  @override
  String get backup_location_default => 'Alapértelmezett hely';

  @override
  String get backup_location_title => 'Mentés helye';

  @override
  String get backup_replaceConfirm_confirm => 'Csere mindenhol';

  @override
  String get backup_replaceConfirm_content =>
      'Az összes szinkronizált eszközön lévő könyvtár erre a biztonsági mentésre cserélődik. Minden eszköz először biztonsági mentést készít a jelenlegi adatairól. Ez nem vonható vissza.';

  @override
  String get backup_replaceConfirm_title => 'Könyvtár cseréje mindenhol?';

  @override
  String get backup_restore_dialog_cancel => 'Mégse';

  @override
  String get backup_restore_dialog_modeMerge_subtitle =>
      'Visszaállítás erre az eszközre. A következő szinkronizálás egyesíti a visszaállított adatokat a felhőkönyvtárral.';

  @override
  String get backup_restore_dialog_modeMerge_title =>
      'Egyesítés a következő szinkronizáláskor';

  @override
  String get backup_restore_dialog_modeReplace_subtitle =>
      'A biztonsági mentés lesz a könyvtár ezen az eszközön, a felhőben és minden szinkronizált eszközön.';

  @override
  String get backup_restore_dialog_modeReplace_title => 'Csere mindenhol';

  @override
  String get backup_restore_dialog_restore => 'Visszaállítás';

  @override
  String get backup_restore_dialog_restoreReplace =>
      'Visszaállítás és csere mindenhol';

  @override
  String get backup_restore_dialog_safetyNote =>
      'A jelenlegi adatokról automatikusan biztonsági mentés készül a visszaállítás előtt.';

  @override
  String get backup_restore_dialog_title => 'Mentés Visszaállítása';

  @override
  String get backup_restore_dialog_warning =>
      'Ez MINDEN jelenlegi adatot lecserél a mentés adataival. Ez a művelet nem vonható vissza.';

  @override
  String backup_restore_safetyReview_progress(int done, int total) {
    return '$done / $total merülés elemezve';
  }

  @override
  String get backup_restore_safetyReview_skip => 'Kihagyás';

  @override
  String get backup_restore_safetyReview_title =>
      'Biztonsági ellenőrzés folyamatban';

  @override
  String get backup_restoreComplete_continue => 'Tovabb';

  @override
  String get backup_restoreComplete_description =>
      'Az adatok sikeresen visszaallitva. Koppintson a Tovabb gombra az alkalmazas ujratoltésehez a visszaallitott adatokkal.';

  @override
  String get backup_restoreComplete_title => 'Visszaallitas befejezve';

  @override
  String get backup_schedule_enabled => 'Automatikus mentések';

  @override
  String get backup_schedule_enabled_subtitle =>
      'Adatok mentése ütemezés szerint';

  @override
  String get backup_schedule_frequency => 'Gyakoriság';

  @override
  String get backup_schedule_retention => 'Mentések megőrzése';

  @override
  String get backup_schedule_retention_subtitle =>
      'A régebbi mentések automatikusan eltávolításra kerülnek';

  @override
  String get backup_section_auto => 'Automatikus mentések';

  @override
  String get backup_section_cloud => 'Felhő';

  @override
  String get backup_section_history => 'Előzmények';

  @override
  String get backup_section_schedule => 'Ütemezés';

  @override
  String get backup_status_disabled => 'Automatikus Mentések Kikapcsolva';

  @override
  String backup_status_lastBackup(String time) {
    return 'Utolsó mentés: $time';
  }

  @override
  String get backup_status_neverBackedUp => 'Még Nem Készült Mentés';

  @override
  String get backup_status_noBackupsYet =>
      'Hozza létre az első mentést az adatok védelméhez';

  @override
  String get backup_status_overdue => 'Mentés Késésben';

  @override
  String get backup_status_upToDate => 'Mentések Naprakészek';

  @override
  String backup_time_daysAgo(int count) {
    return '$count napja';
  }

  @override
  String backup_time_hoursAgo(int count) {
    return '$count órája';
  }

  @override
  String get backup_time_justNow => 'Éppen most';

  @override
  String backup_time_minutesAgo(int count) {
    return '$count perce';
  }

  @override
  String get buddies_action_add => 'Búvártárs hozzáadása';

  @override
  String get buddies_action_addCertification => 'Képesítés hozzáadása';

  @override
  String get buddies_action_addFirst => 'Add hozzá az első búvártársad';

  @override
  String get buddies_action_addTooltip => 'Új búvártárs hozzáadása';

  @override
  String get buddies_action_clearSearch => 'Keresés törlése';

  @override
  String get buddies_action_edit => 'Búvártárs szerkesztése';

  @override
  String get buddies_action_importFromContacts => 'Importálás névjegyekből';

  @override
  String get buddies_action_moreOptions => 'További lehetőségek';

  @override
  String get buddies_action_retry => 'Újra';

  @override
  String get buddies_action_search => 'Búvártársak keresése';

  @override
  String get buddies_action_shareDives => 'Merülések megosztása';

  @override
  String get buddies_action_sort => 'Rendezés';

  @override
  String get buddies_action_sortTitle => 'Búvártársak rendezése';

  @override
  String get buddies_action_update => 'Búvártárs frissítése';

  @override
  String buddies_action_viewAll(Object count) {
    return 'Összes megtekintése ($count)';
  }

  @override
  String buddies_detail_error(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get buddies_detail_noDivesTogether => 'Még nem merültetek együtt';

  @override
  String get buddies_detail_notFound => 'Búvártárs nem található';

  @override
  String buddies_dialog_deleteMessage(Object name) {
    return 'Biztosan törölni szeretnéd: $name? Ez a művelet nem vonható vissza.';
  }

  @override
  String get buddies_dialog_deleteTitle => 'Búvártárs törlése?';

  @override
  String get buddies_dialog_discard => 'Elvetés';

  @override
  String get buddies_dialog_discardMessage =>
      'Nem mentett módosításaid vannak. Biztosan elveted őket?';

  @override
  String get buddies_dialog_discardTitle => 'Módosítások elvetése?';

  @override
  String get buddies_dialog_keepEditing => 'Szerkesztés folytatása';

  @override
  String get buddies_empty_subtitle =>
      'Add hozzá az első búvártársad a kezdéshez';

  @override
  String get buddies_empty_title => 'Még nincsenek búvártársak';

  @override
  String buddies_error_loading(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get buddies_error_unableToLoadDives =>
      'Nem lehet betölteni a merüléseket';

  @override
  String get buddies_error_unableToLoadStats =>
      'Nem lehet betölteni a statisztikákat';

  @override
  String get buddies_field_certificationAgency => 'Képesítő szervezet';

  @override
  String get buddies_field_certificationLevel => 'Képesítési szint';

  @override
  String get buddies_field_email => 'E-mail';

  @override
  String get buddies_field_emailHint => 'pelda@email.hu';

  @override
  String get buddies_field_nameHint => 'Add meg a búvártárs nevét';

  @override
  String get buddies_field_nameRequired => 'Név *';

  @override
  String get buddies_field_notes => 'Jegyzetek';

  @override
  String get buddies_field_notesHint =>
      'Írj jegyzeteket erről a búvártársról...';

  @override
  String get buddies_field_phone => 'Telefon';

  @override
  String get buddies_field_phoneHint => '+36 30 123 4567';

  @override
  String get buddies_label_agency => 'Szervezet';

  @override
  String buddies_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merülés',
      one: '1 merülés',
    );
    return '$_temp0';
  }

  @override
  String get buddies_label_level => 'Szint';

  @override
  String get buddies_label_notSpecified => 'Nincs megadva';

  @override
  String get buddies_label_photoComingSoon => 'Fotó támogatás a v2.0-ban';

  @override
  String get buddies_message_added => 'Búvártárs sikeresen hozzáadva';

  @override
  String get buddies_message_contactImportUnavailable =>
      'Névjegy importálás nem elérhető ezen a platformon';

  @override
  String get buddies_message_contactLoadFailed =>
      'Névjegyek betöltése sikertelen';

  @override
  String get buddies_message_contactPermissionRequired =>
      'Névjegy engedély szükséges a búvártársak importálásához';

  @override
  String get buddies_message_deleted => 'Búvártárs törölve';

  @override
  String buddies_message_errorImportingContact(Object error) {
    return 'Hiba a névjegy importálásakor: $error';
  }

  @override
  String buddies_message_errorLoading(Object error) {
    return 'Hiba a búvártárs betöltésekor: $error';
  }

  @override
  String buddies_message_errorSaving(Object error) {
    return 'Hiba a búvártárs mentésekor: $error';
  }

  @override
  String buddies_message_exportFailed(Object error) {
    return 'Exportálás sikertelen: $error';
  }

  @override
  String get buddies_message_noDivesFound =>
      'Nem találhatók exportálandó merülések';

  @override
  String get buddies_message_noDivesToShare =>
      'Nincsenek megosztható merülések ezzel a búvártárssal';

  @override
  String get buddies_message_preparingExport => 'Exportálás előkészítése...';

  @override
  String get buddies_message_updated => 'Búvártárs sikeresen frissítve';

  @override
  String get buddies_picker_add => 'Hozzáadás';

  @override
  String get buddies_picker_addCustomRole => 'Egyedi szerep hozzáadása...';

  @override
  String get buddies_picker_addNew => 'Új búvártárs hozzáadása';

  @override
  String get buddies_picker_done => 'Kész';

  @override
  String get buddies_picker_me => 'Én';

  @override
  String get buddies_picker_noBuddiesFound => 'Nem találhatók búvártársak';

  @override
  String get buddies_picker_noBuddiesYet => 'Még nincsenek búvártársak';

  @override
  String get buddies_picker_noRole => 'Nincs szerep';

  @override
  String get buddies_picker_noneSelected => 'Nincs kiválasztott búvártárs';

  @override
  String get buddies_picker_searchHint => 'Búvártársak keresése...';

  @override
  String get buddies_picker_selectBuddies => 'Búvártársak kiválasztása';

  @override
  String get buddies_picker_selectMyRole => 'Saját szerep kiválasztása';

  @override
  String buddies_picker_selectRole(Object name) {
    return 'Szerep kiválasztása: $name';
  }

  @override
  String get buddies_picker_setMyRole => 'Saját szerep beállítása';

  @override
  String get buddies_picker_tapToAdd =>
      'Koppints a \'Hozzáadás\'-ra a búvártársak kiválasztásához';

  @override
  String get buddies_search_hint => 'Keresés név, e-mail vagy telefon alapján';

  @override
  String buddies_search_noResults(Object query) {
    return 'Nincs találat erre: \"$query\"';
  }

  @override
  String get buddies_section_certification => 'Képesítés';

  @override
  String get buddies_section_certifications => 'Képesítések';

  @override
  String get buddies_certifications_empty => 'Nincsenek képesítések';

  @override
  String get buddies_section_contact => 'Kapcsolat';

  @override
  String get buddies_section_diveStatistics => 'Merülési statisztikák';

  @override
  String get buddies_section_notes => 'Jegyzetek';

  @override
  String get buddies_section_sharedDives => 'Közös merülések';

  @override
  String get buddies_stat_divesTogether => 'Közös merülések';

  @override
  String get buddies_stat_favoriteSite => 'Kedvenc hely';

  @override
  String get buddies_stat_firstDive => 'Első merülés';

  @override
  String get buddies_stat_lastDive => 'Utolsó merülés';

  @override
  String get buddies_summary_overview => 'Áttekintés';

  @override
  String get buddies_summary_quickActions => 'Gyors műveletek';

  @override
  String get buddies_summary_recentBuddies => 'Legutóbbi búvártársak';

  @override
  String get buddies_summary_selectHint =>
      'Válassz ki egy búvártársat a listából a részletek megtekintéséhez';

  @override
  String get buddies_summary_title => 'Búvártársak';

  @override
  String get buddies_summary_totalBuddies => 'Összes búvártárs';

  @override
  String get buddies_summary_withCertification => 'Képesítéssel';

  @override
  String get buddies_title => 'Búvártársak';

  @override
  String get buddies_title_add => 'Búvártárs hozzáadása';

  @override
  String get buddies_title_edit => 'Búvártárs szerkesztése';

  @override
  String get buddies_title_singular => 'Búvártárs';

  @override
  String get buddies_validation_emailInvalid => 'Adj meg érvényes e-mail címet';

  @override
  String get buddies_validation_nameRequired => 'Adj meg egy nevet';

  @override
  String get buddies_list_selection_closeTooltip => 'Kijelölés bezárása';

  @override
  String buddies_list_selection_count(int count) {
    return '$count kijelölve';
  }

  @override
  String get buddies_list_selection_selectAllTooltip => 'Összes kijelölése';

  @override
  String get buddies_list_selection_deselectAllTooltip =>
      'Összes kijelölés megszüntetése';

  @override
  String get buddies_list_selection_mergeTooltip => 'Kijelöltek összevonása';

  @override
  String get buddies_list_selection_deleteTooltip => 'Kijelöltek törlése';

  @override
  String buddies_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'búvártárs',
      one: 'búvártárs',
    );
    return '$count $_temp0 összevonva';
  }

  @override
  String get buddies_list_merge_undo => 'Visszavonás';

  @override
  String get buddies_list_merge_restored => 'Összevonás visszavonva';

  @override
  String get buddies_list_bulkDelete_title => 'Búvártársak törlése';

  @override
  String buddies_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'búvártársat',
      one: 'búvártársat',
    );
    return 'Biztosan törölni szeretnéd ezt a(z) $count $_temp0? Ez a művelet nem vonható vissza.';
  }

  @override
  String get buddies_list_bulkDelete_cancel => 'Mégse';

  @override
  String get buddies_list_bulkDelete_confirm => 'Törlés';

  @override
  String buddies_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'búvártárs',
      one: 'búvártárs',
    );
    return '$count $_temp0 törölve';
  }

  @override
  String get buddies_edit_merge_title => 'Búvártársak összevonása';

  @override
  String get buddies_edit_merge_fieldSourceCycleTooltip =>
      'Érték használata a következő kijelölt búvártárstól';

  @override
  String buddies_edit_merge_fieldSourceLabel(
    String buddyName,
    int current,
    int total,
  ) {
    return '$buddyName ($current/$total)';
  }

  @override
  String get buddies_edit_merge_confirmTitle => 'Búvártársak összevonása';

  @override
  String buddies_edit_merge_confirmBody(int count) {
    return 'Ez $count búvártársat von össze eggyé. A merülés-társítások az életben maradó búvártárs alá kerülnek. A többi búvártárs törlésre kerül.';
  }

  @override
  String get buddies_edit_merge_loadingErrorTitle => 'Búvártársak összevonása';

  @override
  String buddies_edit_merge_loadingErrorBody(String error) {
    return 'Nem sikerült betölteni a búvártársakat: $error';
  }

  @override
  String get buddies_edit_merge_notEnoughTitle => 'Búvártársak összevonása';

  @override
  String get buddies_edit_merge_notEnoughBody =>
      'Nincs elég búvártárs az összevonáshoz.';

  @override
  String get buddies_instructorPicker_label => 'Oktató a búvártársak közül';

  @override
  String get buddies_instructorPicker_none => 'Nincs (kézi bevitel)';

  @override
  String get certifications_appBar_addCertification => 'Kepesites hozzaadasa';

  @override
  String get certifications_appBar_certificationWallet => 'Kepesites tarca';

  @override
  String get certifications_appBar_editCertification =>
      'Kepesites szerkesztese';

  @override
  String get certifications_appBar_title => 'Kepesitesek';

  @override
  String get certifications_detail_action_delete => 'Torles';

  @override
  String get certifications_detail_appBar_title => 'Kepesites';

  @override
  String get certifications_detail_courseCompleted => 'Befejezett';

  @override
  String get certifications_detail_courseInProgress => 'Folyamatban';

  @override
  String get certifications_detail_dialog_cancel => 'Megse';

  @override
  String get certifications_detail_dialog_deleteConfirm => 'Torles';

  @override
  String certifications_detail_dialog_deleteContent(Object name) {
    return 'Biztosan torli a kovetkezot: \"$name\"?';
  }

  @override
  String get certifications_detail_dialog_deleteTitle => 'Kepesites torlese?';

  @override
  String get certifications_detail_label_agency => 'Szervezet';

  @override
  String get certifications_detail_label_cardNumber => 'Kartyaszam';

  @override
  String get certifications_detail_label_certification => 'Képesítés';

  @override
  String get certifications_detail_label_expiryDate => 'Lejarat datuma';

  @override
  String get certifications_detail_label_instructorName => 'Nev';

  @override
  String get certifications_detail_label_instructorNumber => 'Oktato #';

  @override
  String get certifications_detail_label_issueDate => 'Kiadas datuma';

  @override
  String get certifications_detail_label_type => 'Tipus';

  @override
  String get certifications_detail_label_validity => 'Ervenyesseg';

  @override
  String get certifications_detail_noExpiration => 'Nincs lejaarat';

  @override
  String get certifications_detail_notFound => 'Kepesites nem talalhato';

  @override
  String get certifications_detail_photoLabel_back => 'Hatlap';

  @override
  String get certifications_detail_photoLabel_front => 'Elolap';

  @override
  String certifications_detail_photo_fullscreenTitle(
    Object label,
    Object name,
  ) {
    return '$label - $name';
  }

  @override
  String get certifications_detail_photo_unableToLoad =>
      'Nem sikerult a kep betoltese';

  @override
  String get certifications_detail_sectionTitle_cardPhotos => 'Kartya fotok';

  @override
  String get certifications_detail_sectionTitle_dates => 'Datumok';

  @override
  String get certifications_detail_sectionTitle_details =>
      'Kepesites reszletek';

  @override
  String get certifications_detail_sectionTitle_instructor => 'Oktato';

  @override
  String get certifications_detail_sectionTitle_notes => 'Megjegyzesek';

  @override
  String get certifications_detail_sectionTitle_trainingCourse =>
      'Kepzesi tanfolyam';

  @override
  String certifications_detail_semanticLabel_photoTapToView(
    Object label,
    Object name,
  ) {
    return '$name $label fotoja. Koppintson a teljes kepernyon torteno megtekinteshez';
  }

  @override
  String get certifications_detail_snackBar_deleted => 'Kepesites torolve';

  @override
  String get certifications_detail_status_expired => 'Ez a kepesites lejart';

  @override
  String certifications_detail_status_expiredOn(Object date) {
    return 'Lejart $date-kor';
  }

  @override
  String certifications_detail_status_expiresInDays(Object days) {
    return '$days nap mulva jar le';
  }

  @override
  String certifications_detail_status_expiresOn(Object date) {
    return 'Lejar $date-kor';
  }

  @override
  String get certifications_detail_tooltip_edit => 'Kepesites szerkesztese';

  @override
  String get certifications_detail_tooltip_editShort => 'Szerkesztes';

  @override
  String get certifications_detail_tooltip_moreOptions => 'Tovabbi lehetosegek';

  @override
  String get certifications_ecardStack_empty_subtitle =>
      'Adja hozza elso kepesiteset, hogy itt megjelenjen';

  @override
  String get certifications_ecardStack_empty_title =>
      'Meg nincsenek kepesitesek';

  @override
  String get certifications_ecard_label_cardNumber => 'KARTYASZAM';

  @override
  String certifications_ecard_label_certifiedBy(Object agency) {
    return 'Kepesitette: $agency';
  }

  @override
  String get certifications_ecard_label_diver => 'BUVAR';

  @override
  String get certifications_ecard_label_instructor => 'OKTATO';

  @override
  String get certifications_ecard_label_issued => 'KIADAS';

  @override
  String get certifications_ecard_label_validUntil => 'LEJARAT';

  @override
  String get certifications_ecard_statusBadge_expired => 'LEJART';

  @override
  String get certifications_ecard_statusBadge_expiring => 'LEJAROBAN';

  @override
  String get certifications_edit_appBar_add => 'Kepesites hozzaadasa';

  @override
  String get certifications_edit_appBar_edit => 'Kepesites szerkesztese';

  @override
  String get certifications_edit_button_add => 'Kepesites hozzaadasa';

  @override
  String get certifications_edit_button_cancel => 'Megse';

  @override
  String get certifications_edit_button_save => 'Mentes';

  @override
  String get certifications_edit_button_update => 'Kepesites frissitese';

  @override
  String get certifications_edit_certification_notSpecified => 'Nincs megadva';

  @override
  String certifications_edit_datePicker_clearTooltip(Object label) {
    return '$label torlese';
  }

  @override
  String get certifications_edit_datePicker_tapToSelect =>
      'Koppintson a kivalasztashoz';

  @override
  String get certifications_edit_dialog_discard => 'Eldobas';

  @override
  String get certifications_edit_dialog_discardContent =>
      'Mentetlen valtozasai vannak. Biztosan el akar tavozni?';

  @override
  String get certifications_edit_dialog_discardTitle => 'Valtozasok eldobasa?';

  @override
  String get certifications_edit_dialog_keepEditing => 'Szerkesztes folytatasa';

  @override
  String get certifications_edit_group_progression => 'Fokozatok';

  @override
  String get certifications_edit_group_specialties => 'Specialitások';

  @override
  String get certifications_edit_help_expiryDate =>
      'Hagyja uresen a le nem jaro kepesiteseknel';

  @override
  String get certifications_edit_helper_nameOnCard => 'Nem kötelező';

  @override
  String get certifications_edit_hint_cardNumber =>
      'Adja meg a kepesitesi kartyaszamot';

  @override
  String get certifications_edit_hint_instructorName =>
      'A kepesito oktato neve';

  @override
  String get certifications_edit_hint_instructorNumber =>
      'Oktato kepesitesi szama';

  @override
  String get certifications_edit_hint_notes => 'Barmilyen tovabbi megjegyzes';

  @override
  String get certifications_edit_label_agency => 'Szervezet *';

  @override
  String get certifications_edit_label_cardNumber => 'Kartyaszam';

  @override
  String get certifications_edit_label_certification => 'Képesítés';

  @override
  String get certifications_edit_label_expiryDate => 'Lejarat datuma';

  @override
  String get certifications_edit_label_instructorName => 'Oktato neve';

  @override
  String get certifications_edit_label_instructorNumber => 'Oktato szama';

  @override
  String get certifications_edit_label_issueDate => 'Kiadas datuma';

  @override
  String get certifications_edit_label_nameOnCard => 'Név a kártyán';

  @override
  String get certifications_edit_label_notes => 'Megjegyzesek';

  @override
  String certifications_edit_photo_addSemanticLabel(Object label) {
    return '$label foto hozzaadasa. Koppintson a kivalasztashoz';
  }

  @override
  String certifications_edit_photo_attachedSemanticLabel(Object label) {
    return '$label foto csatolva. Koppintson a modositashoz';
  }

  @override
  String get certifications_edit_photo_chooseFromGallery =>
      'Valasszon a galeriabol';

  @override
  String certifications_edit_photo_removeTooltip(Object label) {
    return '$label foto eltavolitasa';
  }

  @override
  String get certifications_edit_photo_takePhoto => 'Foto keszitese';

  @override
  String get certifications_edit_sectionTitle_cardPhotos => 'Kartya fotok';

  @override
  String get certifications_edit_sectionTitle_dates => 'Datumok';

  @override
  String get certifications_edit_sectionTitle_instructorInfo =>
      'Oktato informaciok';

  @override
  String get certifications_edit_sectionTitle_notes => 'Megjegyzesek';

  @override
  String get certifications_edit_snackBar_added =>
      'Kepesites sikeresen hozzaadva';

  @override
  String certifications_edit_snackBar_errorLoading(Object error) {
    return 'Hiba a kepesites betoltesekor: $error';
  }

  @override
  String certifications_edit_snackBar_errorPhoto(Object error) {
    return 'Hiba a foto kivalasztasakor: $error';
  }

  @override
  String certifications_edit_snackBar_errorSaving(Object error) {
    return 'Hiba a kepesites mentesekor: $error';
  }

  @override
  String get certifications_edit_snackBar_updated =>
      'Tanusitvany sikeresen frissitve';

  @override
  String get certifications_edit_validation_certificationOrNameRequired =>
      'Válasszon képesítést, vagy adjon meg egy nevet';

  @override
  String get certifications_list_button_retry => 'Ujraproba';

  @override
  String get certifications_list_empty_button =>
      'Adja hozza az elso tanusitvanyt';

  @override
  String get certifications_list_empty_subtitle =>
      'Adja hozza merulesi tanusitványait a kepzesek\nes kepesitesek nyomon kovetésehez';

  @override
  String get certifications_list_empty_title =>
      'Meg nincsenek tanusitványok hozzaadva';

  @override
  String certifications_list_error_loading(Object error) {
    return 'Hiba a tanusitványok betoltesekor: $error';
  }

  @override
  String get certifications_list_fab_addCertification =>
      'Tanusitvany hozzaadasa';

  @override
  String get certifications_list_section_expired => 'Lejart';

  @override
  String get certifications_list_section_expiringSoon => 'Hamarosan lejar';

  @override
  String get certifications_list_section_valid => 'Ervenyes';

  @override
  String get certifications_list_sort_title => 'Tanusitványok rendezese';

  @override
  String get certifications_list_tile_expired => 'Lejart';

  @override
  String certifications_list_tile_expiringDays(Object days) {
    return '${days}n';
  }

  @override
  String get certifications_list_tooltip_addCertification =>
      'Tanusitvany hozzaadasa';

  @override
  String get certifications_list_tooltip_search => 'Tanusitványok keresese';

  @override
  String get certifications_list_tooltip_sort => 'Rendezes';

  @override
  String get certifications_list_tooltip_walletView => 'Kartya nezet';

  @override
  String get certifications_picker_clearTooltip =>
      'Tanusitvany kivalasztas torlese';

  @override
  String get certifications_picker_empty_addButton => 'Tanusitvany hozzaadasa';

  @override
  String get certifications_picker_empty_title => 'Meg nincsenek tanusitványok';

  @override
  String certifications_picker_error(Object error) {
    return 'Hiba a tanusitványok betoltesekor: $error';
  }

  @override
  String get certifications_picker_expired => 'Lejart';

  @override
  String get certifications_picker_hint =>
      'Koppintson egy megszerzett tanusitvany csatolasahoz';

  @override
  String get certifications_picker_newCert => 'Uj tanusitvany';

  @override
  String get certifications_picker_noSelection =>
      'Nincs tanusitvany kivalasztva';

  @override
  String get certifications_picker_sheetTitle => 'Csatolas tanusitványhoz';

  @override
  String get certifications_renderer_footer => 'Submersion merulesi naplo';

  @override
  String certifications_renderer_label_cardNumber(Object number) {
    return 'Kartyaszam: $number';
  }

  @override
  String get certifications_renderer_label_hasCompletedTraining =>
      'elvégezte a kepzest mint';

  @override
  String certifications_renderer_label_instructor(Object name) {
    return 'Oktato: $name';
  }

  @override
  String certifications_renderer_label_instructorWithNumber(
    Object name,
    Object number,
  ) {
    return 'Oktato: $name ($number)';
  }

  @override
  String certifications_renderer_label_issued(Object date) {
    return 'Kiallitva: $date';
  }

  @override
  String get certifications_renderer_label_thisCertifies =>
      'Ezuton igazoljuk, hogy';

  @override
  String get certifications_search_empty_hint =>
      'Kereses nev, szervezet vagy kartyaszam alapjan';

  @override
  String get certifications_search_fieldLabel => 'Tanusitványok keresese...';

  @override
  String certifications_search_noResults(Object query) {
    return 'Nem talalhato tanusitvany a kovetkezore: \"$query\"';
  }

  @override
  String get certifications_search_tooltip_back => 'Vissza';

  @override
  String get certifications_search_tooltip_clear => 'Kereses torlese';

  @override
  String certifications_share_error_card(Object error) {
    return 'Nem sikerult a kartya megosztasa: $error';
  }

  @override
  String certifications_share_error_certificate(Object error) {
    return 'Nem sikerult a tanusitvany megosztasa: $error';
  }

  @override
  String get certifications_share_option_card_subtitle =>
      'Bankkartya meretu tanusitvany kep';

  @override
  String get certifications_share_option_card_title => 'Megosztas kartyakent';

  @override
  String get certifications_share_option_certificate_subtitle =>
      'Hivatalos tanusitvany dokumentum';

  @override
  String get certifications_share_option_certificate_title =>
      'Megosztas oklevélkent';

  @override
  String get certifications_share_title => 'Tanusitvany megosztasa';

  @override
  String get certifications_summary_header_subtitle =>
      'Valasszon egy tanusitvanyt a listabol a reszletek megtekintésehez';

  @override
  String get certifications_summary_header_title => 'Tanusitványok';

  @override
  String get certifications_summary_overview_title => 'Attekintes';

  @override
  String get certifications_summary_quickActions_add =>
      'Tanusitvany hozzaadasa';

  @override
  String get certifications_summary_quickActions_title => 'Gyorsmuveletek';

  @override
  String get certifications_summary_recentTitle => 'Legutobbi tanusitványok';

  @override
  String get certifications_summary_stat_expired => 'Lejart';

  @override
  String get certifications_summary_stat_expiringSoon => 'Hamarosan lejar';

  @override
  String get certifications_summary_stat_total => 'Osszes';

  @override
  String get certifications_summary_stat_valid => 'Ervenyes';

  @override
  String get certifications_wallet_appBar_title => 'Tanusitvany tarca';

  @override
  String get certifications_wallet_error_retry => 'Ujraproba';

  @override
  String get certifications_wallet_error_title =>
      'Nem sikerult a tanusitványok betoltese';

  @override
  String get certifications_wallet_options_edit => 'Szerkesztes';

  @override
  String get certifications_wallet_options_share => 'Megosztas';

  @override
  String get certifications_wallet_options_viewDetails =>
      'Reszletek megtekintese';

  @override
  String get certifications_wallet_tooltip_add => 'Tanusitvany hozzaadasa';

  @override
  String get certifications_wallet_tooltip_share => 'Tanusitvany megosztasa';

  @override
  String get checklists_section_title => 'Ellenőrzőlista';

  @override
  String checklists_progress(int done, int total) {
    return '$done/$total tétel kész';
  }

  @override
  String get checklists_empty_upcoming =>
      'Tervezze meg útját - adjon hozzá tételeket, vagy alkalmazzon sablont';

  @override
  String get checklists_empty_past => 'Nincsenek ellenőrzőlista-tételek';

  @override
  String get checklists_addItem => 'Tétel hozzáadása';

  @override
  String get checklists_item_titleLabel => 'Cím';

  @override
  String get checklists_item_titleRequired => 'A cím megadása kötelező';

  @override
  String get checklists_item_categoryLabel => 'Kategória';

  @override
  String get checklists_item_notesLabel => 'Megjegyzések';

  @override
  String get checklists_item_dueDateLabel => 'Határidő';

  @override
  String get checklists_item_dueOffsetLabel => 'Nappal az út kezdete előtt';

  @override
  String get checklists_item_dueOffsetInvalid => 'Adjon meg 0 vagy több napot';

  @override
  String get checklists_item_overdue => 'Lejárt';

  @override
  String get checklists_item_edit => 'Tétel szerkesztése';

  @override
  String get checklists_item_delete => 'Tétel törlése';

  @override
  String get checklists_menu_applyTemplate => 'Sablon alkalmazása...';

  @override
  String get checklists_menu_saveAsTemplate => 'Mentés sablonként...';

  @override
  String get checklists_applySheet_title => 'Sablon alkalmazása';

  @override
  String get checklists_applySheet_empty =>
      'Még nincsenek sablonok. Hozza létre őket a Beállításokban.';

  @override
  String checklists_applySheet_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tétel',
      one: '1 tétel',
    );
    return '$_temp0';
  }

  @override
  String checklists_applySheet_confirmAppend(int added, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added tétel kerül hozzáadásra',
      one: '1 tétel kerül hozzáadásra',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '$skipped duplikátum kihagyva',
      one: '1 duplikátum kihagyva',
      zero: 'nincs kihagyott duplikátum',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String checklists_apply_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tétel hozzáadva',
      one: '1 tétel hozzáadva',
      zero: 'Nem került új tétel hozzáadásra',
    );
    return '$_temp0';
  }

  @override
  String get checklists_apply_templateGone => 'A sablon már nem létezik';

  @override
  String get checklists_saveTemplate_title => 'Mentés sablonként';

  @override
  String get checklists_saveTemplate_nameLabel => 'Sablon neve';

  @override
  String get checklists_saveTemplate_success => 'Sablon mentve';

  @override
  String get checklists_templates_pageTitle => 'Ellenőrzőlista-sablonok';

  @override
  String get checklists_templates_addTemplate => 'Sablon hozzáadása';

  @override
  String get checklists_templates_empty => 'Még nincsenek sablonok';

  @override
  String get checklists_templates_deleteTitle => 'Sablon törlése';

  @override
  String checklists_templates_deleteContent(Object name) {
    return 'Törli a(z) \"$name\" sablont? Az utak, amelyek már alkalmazták, megtartják a tételeiket.';
  }

  @override
  String get checklists_template_nameLabel => 'Név';

  @override
  String get checklists_template_nameRequired => 'A név megadása kötelező';

  @override
  String get checklists_template_descriptionLabel => 'Leírás';

  @override
  String get checklists_template_itemsHeader => 'Tételek';

  @override
  String get checklists_template_addItem => 'Tétel hozzáadása';

  @override
  String get preDive_templates_title => 'Merülés előtti ellenőrzőlisták';

  @override
  String get preDive_templates_empty =>
      'Még nincsenek merülés előtti ellenőrzőlisták';

  @override
  String get preDive_templates_builtInBadge => 'Beépített';

  @override
  String get preDive_templates_clone => 'Duplikálás';

  @override
  String get preDive_templates_cloneSuffix => ' (másolat)';

  @override
  String get preDive_templates_delete => 'Törlés';

  @override
  String get preDive_templates_deleteConfirm =>
      'Törli ezt az ellenőrzőlista-sablont?';

  @override
  String get preDive_templates_strictOrderBadge => 'Kötött sorrend';

  @override
  String get preDive_edit_titleNew => 'Új merülés előtti ellenőrzőlista';

  @override
  String get preDive_edit_titleEdit =>
      'Merülés előtti ellenőrzőlista szerkesztése';

  @override
  String get preDive_edit_name => 'Név';

  @override
  String get preDive_edit_description => 'Leírás';

  @override
  String get preDive_edit_category => 'Kategória';

  @override
  String get preDive_edit_strictOrder => 'Kötött sorrend';

  @override
  String get preDive_edit_strictOrderHelp =>
      'A tételeket fentről lefelé haladva kell elvégezni';

  @override
  String get preDive_edit_addItem => 'Tétel hozzáadása';

  @override
  String get preDive_edit_nameRequired => 'Adjon meg egy nevet';

  @override
  String get preDive_item_title => 'Cím';

  @override
  String get preDive_item_section => 'Szakasz';

  @override
  String get preDive_item_notes => 'Megjegyzések';

  @override
  String get preDive_item_required => 'Kötelező';

  @override
  String get preDive_item_type_check => 'Jelölőnégyzet';

  @override
  String get preDive_item_type_value => 'Rögzített érték';

  @override
  String get preDive_item_type_equipmentSet => 'Felszereléskészlet tételei';

  @override
  String get preDive_item_valueLabel => 'Érték címkéje';

  @override
  String get preDive_item_valueUnit => 'Mértékegység';

  @override
  String get preDive_item_valueMin => 'Minimum (figyelmeztetés)';

  @override
  String get preDive_item_valueMax => 'Maximum (figyelmeztetés)';

  @override
  String preDive_runner_progress(int done, int total) {
    return '$done / $total';
  }

  @override
  String get preDive_runner_complete => 'Befejezés';

  @override
  String preDive_runner_completeFlagged(int count) {
    return 'Befejezi $count megjelölt tétellel?';
  }

  @override
  String get preDive_runner_abort => 'Ellenőrzőlista megszakítása';

  @override
  String get preDive_runner_abortConfirm =>
      'Megszakítja ezt az ellenőrzőlistát? Megszakítottként megmarad az előzményekben.';

  @override
  String get preDive_runner_skip => 'Kihagyás';

  @override
  String get preDive_runner_flag => 'Megjelölés';

  @override
  String get preDive_runner_undo => 'Visszaállítás függő állapotba';

  @override
  String get preDive_runner_serviceOverdue => 'A karbantartás lejárt';

  @override
  String get preDive_runner_addNote => 'Megjegyzés hozzáadása';

  @override
  String get preDive_runner_enterValue => 'Érték megadása';

  @override
  String preDive_runner_flaggedBadge(int count) {
    return '$count megjelölve';
  }

  @override
  String get preDive_runner_locked => 'Ez az ellenőrzőlista zárolva van';

  @override
  String get preDive_sessions_title => 'Merülés előtti ellenőrzőlisták';

  @override
  String get preDive_sessions_empty =>
      'Még nincsenek ellenőrzőlista-futtatások';

  @override
  String get preDive_sessions_resume => 'Folytatás';

  @override
  String get preDive_sessions_start => 'Ellenőrzőlista indítása';

  @override
  String get preDive_sessions_statusCompleted => 'Befejezve';

  @override
  String get preDive_sessions_statusAborted => 'Megszakítva';

  @override
  String get preDive_sessions_statusInProgress => 'Folyamatban';

  @override
  String get preDive_sessions_linkedDive => 'Kapcsolt merülés';

  @override
  String get preDive_link_linkToDive => 'Merüléshez kapcsolás';

  @override
  String get preDive_link_unlinkDive => 'Merülés leválasztása';

  @override
  String get preDive_link_linkChecklist => 'Ellenőrzőlista kapcsolása';

  @override
  String get preDive_link_unlinkChecklist => 'Ellenőrzőlista leválasztása';

  @override
  String get preDive_link_searchDives => 'Merülések keresése';

  @override
  String get preDive_link_noDives => 'Nincs kapcsolható merülés';

  @override
  String preDive_link_noDivesMatch(String query) {
    return 'Nincs a következőre illeszkedő merülés: „$query”';
  }

  @override
  String get preDive_link_noUnlinkedSessions =>
      'Nincs kapcsolatlan ellenőrzőlista-futtatás';

  @override
  String get preDive_link_linked =>
      'Ellenőrzőlista ehhez a merüléshez kapcsolva';

  @override
  String get preDive_link_unlinked =>
      'Ellenőrzőlista leválasztva erről a merülésről';

  @override
  String get preDive_sessions_delete => 'Törlés';

  @override
  String get preDive_sessions_deleteConfirm =>
      'Törli ezt az ellenőrzőlista-bejegyzést?';

  @override
  String get preDive_sessions_filter => 'Szűrés';

  @override
  String get preDive_sessions_filterTitle =>
      'Ellenőrzőlista-futtatások szűrése';

  @override
  String get preDive_sessions_filterChecklist => 'Ellenőrzőlista';

  @override
  String get preDive_sessions_filterStatus => 'Állapot';

  @override
  String get preDive_sessions_filterFlaggedOnly => 'Csak megjelölt futtatások';

  @override
  String get preDive_sessions_filterDateRange => 'Dátumtartomány';

  @override
  String get preDive_sessions_filterAnyDate => 'Bármely dátum';

  @override
  String get preDive_sessions_filterClearAll => 'Összes törlése';

  @override
  String get preDive_sessions_filterApply => 'Alkalmaz';

  @override
  String get preDive_sessions_filterFlaggedChip => 'Csak megjelölt';

  @override
  String get preDive_sessions_emptyFiltered =>
      'Nincs a szűrőknek megfelelő ellenőrzőlista-futtatás';

  @override
  String get preDive_sessions_export => 'Exportálás Excelbe';

  @override
  String get preDive_sessions_exportEmpty => 'Nincs exportálható futtatás';

  @override
  String preDive_sessions_exportFailed(String error) {
    return 'Az exportálás sikertelen: $error';
  }

  @override
  String get preDive_start_title => 'Merülés előtti ellenőrzőlista indítása';

  @override
  String get preDive_start_template => 'Ellenőrzőlista';

  @override
  String get preDive_start_equipmentSet => 'Felszereléskészlet';

  @override
  String get preDive_start_noEquipmentSet => 'Nincs';

  @override
  String get preDive_start_begin => 'Kezdés';

  @override
  String get diveLog_listPage_bottomSheet_preDiveChecklist =>
      'Merülés előtti ellenőrzőlista indítása';

  @override
  String get preDive_dashboard_title => 'Merülés előtti ellenőrzés';

  @override
  String preDive_dashboard_resume(int done, int total) {
    return 'Folytatás - $done / $total';
  }

  @override
  String get preDive_dashboard_start => 'Merülés előtti ellenőrzés indítása';

  @override
  String get trips_detail_preDive_action => 'Merülés előtti ellenőrzőlista';

  @override
  String get settings_manage_preDiveChecklists =>
      'Merülés előtti ellenőrzőlisták';

  @override
  String get settings_manage_preDiveChecklists_subtitle =>
      'Társellenőrzések, CCR összeszerelési listák, felszereléscsomagolás';

  @override
  String get common_action_back => 'Vissza';

  @override
  String get common_action_cancel => 'Megse';

  @override
  String get common_action_close => 'Bezaras';

  @override
  String get common_action_continue => 'Folytatás';

  @override
  String get common_action_delete => 'Torles';

  @override
  String get common_action_edit => 'Szerkesztes';

  @override
  String get common_action_ok => 'OK';

  @override
  String get common_action_save => 'Mentes';

  @override
  String get common_action_search => 'Kereses';

  @override
  String get common_action_share => 'Megosztás';

  @override
  String get common_label_error => 'Hiba';

  @override
  String get common_label_loading => 'Betoltes';

  @override
  String get common_placeholder_noValue => '--';

  @override
  String get common_error_tryAgain =>
      'Valami hiba történt. Kérjük, próbáld újra.';

  @override
  String get courses_action_add => 'Tanfolyam hozzáadása';

  @override
  String get courses_action_addFromTemplate => 'Hozzáadás sablonból';

  @override
  String get courses_action_addRequirement => 'Követelmény hozzáadása';

  @override
  String get courses_action_create => 'Tanfolyam létrehozása';

  @override
  String get courses_action_deleteRequirement => 'Követelmény törlése';

  @override
  String get courses_action_edit => 'Tanfolyam szerkesztése';

  @override
  String get courses_action_editRequirement => 'Követelmény szerkesztése';

  @override
  String get courses_action_exportTrainingLog => 'Képzési napló exportálása';

  @override
  String get courses_action_linkDive => 'Csatolás';

  @override
  String get courses_action_markCompleted => 'Megjelölés befejezettként';

  @override
  String get courses_action_unlinkDive => 'Merülés leválasztása';

  @override
  String get courses_action_moreOptions => 'További lehetőségek';

  @override
  String get courses_action_retry => 'Újra';

  @override
  String get courses_action_saveChanges => 'Módosítások mentése';

  @override
  String get courses_action_saveSemantic => 'Tanfolyam mentése';

  @override
  String get courses_action_sort => 'Rendezés';

  @override
  String get courses_action_sortTitle => 'Tanfolyamok rendezése';

  @override
  String courses_card_instructor(Object name) {
    return 'Oktató: $name';
  }

  @override
  String courses_card_started(Object date) {
    return 'Kezdés: $date';
  }

  @override
  String get courses_detail_certificationNotFound => 'Képesítés nem található';

  @override
  String get courses_detail_noTrainingDives =>
      'Még nincsenek hozzákapcsolt képzési merülések';

  @override
  String get courses_detail_notFound => 'Tanfolyam nem található';

  @override
  String get courses_dialog_complete => 'Befejezés';

  @override
  String courses_dialog_deleteMessage(Object name) {
    return 'Biztosan törölni szeretnéd: $name? Ez a művelet nem vonható vissza.';
  }

  @override
  String get courses_dialog_deleteTitle => 'Tanfolyam törlése?';

  @override
  String get courses_dialog_markCompletedMessage =>
      'Ez befejezettként jelöli meg a tanfolyamot a mai dátummal. Folytatod?';

  @override
  String get courses_dialog_markCompletedTitle => 'Megjelölés befejezettként?';

  @override
  String get courses_empty_button => 'Első képzési tanfolyam hozzáadása';

  @override
  String get courses_empty_noCompleted => 'Nincsenek befejezett tanfolyamok';

  @override
  String get courses_empty_noInProgress =>
      'Nincsenek folyamatban lévő tanfolyamok';

  @override
  String get courses_empty_subtitle =>
      'Add hozzá az első tanfolyamod a kezdéshez';

  @override
  String get courses_empty_title => 'Még nincsenek képzési tanfolyamok';

  @override
  String courses_error_generic(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get courses_error_loadingCertification =>
      'Hiba a képesítés betöltésekor';

  @override
  String get courses_error_loadingDives => 'Hiba a merülések betöltésekor';

  @override
  String get courses_field_courseName => 'Tanfolyam neve';

  @override
  String get courses_field_courseNameHint => 'pl. Nyíltvízi búvár';

  @override
  String get courses_field_instructorName => 'Oktató neve';

  @override
  String get courses_field_instructorNumber => 'Oktató száma';

  @override
  String get courses_field_linkCertificationHint =>
      'Csatolj egy tanfolyamból szerzett képesítést';

  @override
  String get courses_field_location => 'Helyszín';

  @override
  String get courses_field_notes => 'Jegyzetek';

  @override
  String get courses_filter_all => 'Összes';

  @override
  String get courses_label_agency => 'Szervezet';

  @override
  String get courses_label_completed => 'Befejezve';

  @override
  String get courses_label_completionDate => 'Befejezés dátuma';

  @override
  String get courses_label_courseInProgress => 'Tanfolyam folyamatban';

  @override
  String get courses_label_instructorNumber => 'Oktató sz.';

  @override
  String get courses_label_location => 'Helyszín';

  @override
  String get courses_label_name => 'Név';

  @override
  String get courses_label_startDate => 'Kezdés dátuma';

  @override
  String courses_message_errorSaving(Object error) {
    return 'Hiba a tanfolyam mentésekor: $error';
  }

  @override
  String courses_message_exportFailed(Object error) {
    return 'Képzési napló exportálása sikertelen: $error';
  }

  @override
  String get courses_picker_active => 'Aktív';

  @override
  String get courses_picker_clearSelection => 'Kijelölés törlése';

  @override
  String get courses_picker_createCourse => 'Tanfolyam létrehozása';

  @override
  String courses_picker_errorLoading(Object error) {
    return 'Hiba a tanfolyamok betöltésekor: $error';
  }

  @override
  String get courses_picker_newCourse => 'Új tanfolyam';

  @override
  String get courses_picker_noCourses => 'Még nincsenek tanfolyamok';

  @override
  String get courses_picker_noneSelected => 'Nincs kiválasztott tanfolyam';

  @override
  String get courses_picker_selectTitle => 'Képzési tanfolyam kiválasztása';

  @override
  String get courses_picker_selected => 'kiválasztva';

  @override
  String get courses_picker_tapToLink =>
      'Koppints a képzési tanfolyamhoz való csatoláshoz';

  @override
  String courses_requirement_diveProgress(int count, int target) {
    return '$count / $target merülés';
  }

  @override
  String get courses_requirement_field_name => 'Név';

  @override
  String get courses_requirement_field_targetCount => 'Szükséges merülések';

  @override
  String get courses_requirement_kind_checklist => 'Kipipálandó elem';

  @override
  String get courses_requirement_kind_dive => 'Merülési követelmény';

  @override
  String get courses_requirement_suggestions => 'Javasolt merülések';

  @override
  String get courses_requirements_empty =>
      'Kövesd nyomon a kalandmerüléseket, előfeltételeket és kipipálandó elemeket ehhez a tanfolyamhoz.';

  @override
  String courses_requirements_progress(int satisfied, int total) {
    return '$satisfied / $total teljesítve';
  }

  @override
  String get courses_section_details => 'Tanfolyam részletei';

  @override
  String get courses_section_earnedCertification => 'Megszerzett képesítés';

  @override
  String get courses_section_instructor => 'Oktató';

  @override
  String get courses_section_notes => 'Jegyzetek';

  @override
  String get courses_section_requirements => 'Követelmények';

  @override
  String get courses_section_trainingDives => 'Képzési merülések';

  @override
  String get courses_status_completed => 'Befejezve';

  @override
  String courses_status_daysSinceStart(Object days) {
    return '$days nap a kezdés óta';
  }

  @override
  String courses_status_durationDays(Object days) {
    return '$days nap';
  }

  @override
  String get courses_status_inProgress => 'Folyamatban';

  @override
  String courses_status_semanticLabel(Object status, Object duration) {
    return '$status, $duration';
  }

  @override
  String courses_template_addsCount(int count) {
    return '$count követelményt ad hozzá';
  }

  @override
  String get courses_summary_overview => 'Áttekintés';

  @override
  String get courses_summary_quickActions => 'Gyors műveletek';

  @override
  String get courses_summary_recentCourses => 'Legutóbbi tanfolyamok';

  @override
  String get courses_summary_selectHint =>
      'Válassz ki egy tanfolyamot a listából a részletek megtekintéséhez';

  @override
  String get courses_summary_title => 'Képzési tanfolyamok';

  @override
  String get courses_summary_total => 'Összesen';

  @override
  String get courses_title => 'Képzési tanfolyamok';

  @override
  String get courses_title_edit => 'Tanfolyam szerkesztése';

  @override
  String get courses_title_new => 'Új tanfolyam';

  @override
  String get courses_title_singular => 'Tanfolyam';

  @override
  String get courses_validation_nameRequired => 'Adj meg tanfolyamnevet';

  @override
  String get dashboard_activeCourses_title => 'Folyamatban lévő tanfolyamok';

  @override
  String get dashboard_activity_daySinceDiving => 'Napja nem merult';

  @override
  String get dashboard_activity_daysSinceDiving => 'Napja nem merult';

  @override
  String dashboard_activity_diveInYear(Object year) {
    return 'Merules $year-ben';
  }

  @override
  String get dashboard_activity_diveThisMonth => 'Merules ebben a honapban';

  @override
  String dashboard_activity_divesInYear(Object year) {
    return 'Merules $year-ben';
  }

  @override
  String get dashboard_activity_divesThisMonth => 'Merules ebben a honapban';

  @override
  String get dashboard_activity_error => 'Hiba';

  @override
  String get dashboard_activity_lastDive => 'Utolso merules';

  @override
  String get dashboard_activity_loading => 'Betoltes';

  @override
  String get dashboard_activity_noDivesYet => 'Meg nincs merules';

  @override
  String get dashboard_activity_today => 'Ma!';

  @override
  String get dashboard_alerts_actionUpdate => 'Frissites';

  @override
  String get dashboard_alerts_actionView => 'Megtekintes';

  @override
  String get dashboard_alerts_checkInsuranceExpiry =>
      'Ellenorizze a biztositas lejarati datumat';

  @override
  String get dashboard_alerts_daysOverdueOne => '1 napja lejaart';

  @override
  String dashboard_alerts_daysOverdueOther(Object count) {
    return '$count napja lejaart';
  }

  @override
  String get dashboard_alerts_dueInDaysOne => '1 nap mulva esedékes';

  @override
  String dashboard_alerts_dueInDaysOther(Object count) {
    return '$count nap mulva esedékes';
  }

  @override
  String dashboard_alerts_equipmentServiceDue(Object name) {
    return '$name szerviz esedékes';
  }

  @override
  String dashboard_alerts_equipmentServiceOverdue(Object name) {
    return '$name szerviz lejaart';
  }

  @override
  String get dashboard_alerts_insuranceExpired => 'Biztositas lejaart';

  @override
  String get dashboard_alerts_insuranceExpiredGeneric =>
      'A merulesi biztositasa lejaart';

  @override
  String dashboard_alerts_insuranceExpiredProvider(Object provider) {
    return '$provider lejaart';
  }

  @override
  String dashboard_alerts_insuranceExpiresDate(Object date) {
    return 'Lejar: $date';
  }

  @override
  String get dashboard_alerts_insuranceExpiringSoon =>
      'Biztositas hamarosan lejar';

  @override
  String get dashboard_alerts_sectionTitle =>
      'Figyelmeztetesek es emlekeztetok';

  @override
  String get dashboard_alerts_serviceDueToday => 'Szerviz ma esedékes';

  @override
  String get dashboard_alerts_serviceIntervalReached => 'Szerviz idokoz elerve';

  @override
  String get dashboard_defaultDiverName => 'Buvar';

  @override
  String get dashboard_greeting_afternoon => 'Jo delutant';

  @override
  String get dashboard_greeting_evening => 'Jo estet';

  @override
  String get dashboard_greeting_morning => 'Jo reggelt';

  @override
  String dashboard_greeting_withName(Object greeting, Object name) {
    return '$greeting, $name!';
  }

  @override
  String dashboard_greeting_withoutName(Object greeting) {
    return '$greeting!';
  }

  @override
  String get dashboard_hero_divesLoggedOne => '1 merules rogzitve';

  @override
  String dashboard_hero_divesLoggedOther(Object count) {
    return '$count merules rogzitve';
  }

  @override
  String get dashboard_hero_divesTotalOne => '1 merules';

  @override
  String dashboard_hero_divesTotalOther(Object count) {
    return '$count merules';
  }

  @override
  String get dashboard_hero_error => 'Kesz felfedezni a melyseget?';

  @override
  String dashboard_hero_hoursUnderwater(Object hours) {
    return '$hours ora viz alatt';
  }

  @override
  String get dashboard_hero_loading => 'Merulesi statisztikak betoltese...';

  @override
  String dashboard_hero_minutesUnderwater(Object minutes) {
    return '$minutes perc viz alatt';
  }

  @override
  String get dashboard_hero_noDives => 'Kesz rogziteni az elso meruleset?';

  @override
  String get dashboard_hero_divesLoggedLabel => 'rögzített merülés';

  @override
  String get dashboard_hero_hoursUnderwaterLabel => 'óra a víz alatt';

  @override
  String get dashboard_hero_daysSinceLabel => 'napja volt az utolsó merülés';

  @override
  String get dashboard_hero_thisMonthLabel => 'ebben a hónapban';

  @override
  String get dashboard_hero_thisYearLabel => 'merülés idén';

  @override
  String get dashboard_hero_todayLabel => 'ma!';

  @override
  String get dashboard_hero_noDivesLabel => 'még nincs merülés';

  @override
  String get dashboard_hero_diverFallbackName => 'Búvár';

  @override
  String get dashboard_hero_statDives => 'merülés';

  @override
  String get dashboard_hero_statHours => 'óra';

  @override
  String get dashboard_hero_statSites => 'helyszín';

  @override
  String get dashboard_hero_statCountries => 'ország';

  @override
  String dashboard_activityStats_divesInYear(String year) {
    return 'merülések $year-ben';
  }

  @override
  String get dashboard_semantics_statsBar =>
      'Merülési statisztika összefoglaló';

  @override
  String get dashboard_gauges_addGear => 'Felszerelés hozzáadása';

  @override
  String dashboard_gauges_gearOk(String name) {
    return '$name rendben';
  }

  @override
  String dashboard_gauges_gearDueIn(String name, int days) {
    return '$name szervize $days nap múlva esedékes';
  }

  @override
  String dashboard_gauges_gearOverdue(String name) {
    return '$name szervize lejárt';
  }

  @override
  String get dashboard_gauges_insuranceOk => 'Biztosítás rendben';

  @override
  String dashboard_gauges_insuranceExpires(String date) {
    return 'A biztosítás lejár: $date';
  }

  @override
  String get dashboard_gauges_insuranceExpired => 'A biztosítás lejárt';

  @override
  String get dashboard_gauges_noInsurance => 'Nincs rögzített biztosítás';

  @override
  String get dashboard_gauges_noFlyClear => 'Repülési tilalom 0:00';

  @override
  String dashboard_gauges_flightWindow(String hours, String minutes) {
    return 'Merülési ablak $hours:$minutes';
  }

  @override
  String get dashboard_gauges_flightWindowClosed =>
      'A repülés előtt már nincs merülés';

  @override
  String dashboard_gauges_noFlyRemaining(String hours, String minutes) {
    return 'Repülési tilalom $hours:$minutes';
  }

  @override
  String dashboard_gauges_lastDiveDays(int days) {
    return 'Utolsó merülés $days napja';
  }

  @override
  String get dashboard_gauges_lastDiveToday => 'Ma merültél';

  @override
  String get dashboard_gauges_noDivesYet => 'Még nincs merülés';

  @override
  String get settings_homeChips_pageTitle => 'Kezdőképernyő';

  @override
  String get settings_homeChips_description =>
      'Válaszd ki, mely állapotjelzők jelenjenek meg a Kezdőlap tetején.';

  @override
  String get settings_homeChips_sectionTitle => 'Állapotjelzők';

  @override
  String get settings_homeCards_sectionTitle => 'Kezdőlap kártyái';

  @override
  String get settings_homeCards_description =>
      'Válaszd ki, mely kártyák jelenjenek meg a Kezdőlapon, és húzással rendezd át őket.';

  @override
  String get settings_homeCards_autoHides =>
      'Automatikusan elrejtőzik, ha üres';

  @override
  String get settings_homeCards_resetToDefault =>
      'Alapértelmezés visszaállítása';

  @override
  String get settings_homeCards_resetDialog_title =>
      'Visszaállítod a Kezdőlap elrendezését?';

  @override
  String get settings_homeCards_resetDialog_message =>
      'Visszaállítja a kártyák alapértelmezett sorrendjét, és újra megjeleníti mindet.';

  @override
  String get settings_homeCards_resetDialog_cancel => 'Mégse';

  @override
  String get settings_homeCards_resetDialog_confirm => 'Visszaállítás';

  @override
  String get settings_homeCards_card_hero => 'Üdvözlő fejléc';

  @override
  String get settings_homeCards_card_gaugeStrip => 'Állapotjelzők';

  @override
  String get settings_homeCards_card_preDive => 'Merülés előtti ellenőrzőlista';

  @override
  String get settings_homeCards_card_recentDives => 'Legutóbbi merülések';

  @override
  String get settings_homeCards_card_quickActions => 'Gyorsműveletek';

  @override
  String get settings_homeCards_card_milestones => 'Mérföldkövek';

  @override
  String get settings_homeCards_card_photoRibbon => 'Legutóbbi médiaelemek';

  @override
  String get settings_homeCards_card_onThisDay => 'Ezen a napon';

  @override
  String get settings_homeCards_card_yearInReview => 'Éves visszatekintés';

  @override
  String get settings_homeCards_card_activeCourses => 'Tanfolyam előrehaladása';

  @override
  String get settings_homeCards_card_recentSitesMap =>
      'Legutóbbi merülőhelyek térképe';

  @override
  String get dashboard_allHidden_message =>
      'Minden kezdőlapi kártya el van rejtve.';

  @override
  String get dashboard_allHidden_customize => 'Kezdőlap testreszabása';

  @override
  String get settings_homeChips_flightWindow => 'Merülési ablak repülés előtt';

  @override
  String get settings_homeChips_gear => 'Felszerelés szervize';

  @override
  String get settings_homeChips_insurance => 'Biztosítás';

  @override
  String get settings_homeChips_noFly => 'Repülési tilalom időzítő';

  @override
  String get settings_homeChips_lastDive => 'Merülési naprakészség';

  @override
  String get settings_homeChips_certifications => 'Minősítések lejárata';

  @override
  String get settings_homeChips_trip => 'Közelgő utazás';

  @override
  String get settings_homeChips_checklist => 'Aktív ellenőrzőlista';

  @override
  String get settings_homeChips_course => 'Tanfolyam haladása';

  @override
  String get settings_homeChips_uploads => 'Médiafeltöltések';

  @override
  String get settings_homeChips_backup => 'Mentés kora';

  @override
  String get settings_homeChips_sync => 'Szinkronizálási állapot';

  @override
  String get settings_homeChips_dataQuality => 'Adatminőség';

  @override
  String dashboard_gauges_certsExpiring(int count) {
    return '$count minősítés hamarosan lejár';
  }

  @override
  String dashboard_gauges_tripCountdown(String name, int days) {
    return '$name $days nap múlva';
  }

  @override
  String get dashboard_gauges_checklistActive => 'Ellenőrzőlista folyamatban';

  @override
  String dashboard_gauges_courseProgress(String name, int done, int total) {
    return '$name: $done/$total';
  }

  @override
  String dashboard_gauges_uploadsPending(int count) {
    return '$count feltöltés függőben';
  }

  @override
  String get dashboard_gauges_backupNone => 'Még nincs biztonsági mentés';

  @override
  String get dashboard_gauges_backupToday => 'Ma mentve';

  @override
  String dashboard_gauges_backupDays(int days) {
    return 'Mentés $days napja';
  }

  @override
  String dashboard_gauges_syncPending(int count) {
    return '$count nem szinkronizált';
  }

  @override
  String get dashboard_gauges_synced => 'Szinkronizálva';

  @override
  String dashboard_gauges_dataIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count adatprobléma',
      one: '1 adatprobléma',
    );
    return '$_temp0';
  }

  @override
  String get dashboard_gauges_retry =>
      'Az állapot nem érhető el - koppints az újrapróbáláshoz';

  @override
  String get dashboard_urgent_title => 'Figyelmet igényel';

  @override
  String get dashboard_media_title => 'Legutóbbi médiaelemek';

  @override
  String get dashboard_recentSites_title => 'Legutóbbi helyszínek';

  @override
  String get dashboard_yearInReview_title => 'Idén';

  @override
  String dashboard_yearInReview_divesVs(int count, int previous) {
    return '$count merülés (tavaly: $previous)';
  }

  @override
  String dashboard_yearInReview_hours(String hours) {
    return '$hours óra a víz alatt';
  }

  @override
  String dashboard_yearInReview_maxDepth(String depth) {
    return 'Legmélyebb: $depth';
  }

  @override
  String get dashboard_onThisDay_title => 'Ezen a napon';

  @override
  String dashboard_onThisDay_entry(String year, String site) {
    return '$year - $site';
  }

  @override
  String get dashboard_milestones_title => 'Mérföldkövek';

  @override
  String dashboard_milestones_nextDive(int remaining, int milestone) {
    return 'Még $remaining merülés a(z) $milestone. eléréséig';
  }

  @override
  String dashboard_milestones_certYears(String name, int years, String month) {
    return '$name: $years év $month hónapban';
  }

  @override
  String get dashboard_personalRecords_coldest => 'Leghidegebb';

  @override
  String get dashboard_personalRecords_deepest => 'Legmelyebb';

  @override
  String get dashboard_personalRecords_longest => 'Leghosszabb';

  @override
  String get dashboard_personalRecords_sectionTitle => 'Szemelyes rekordok';

  @override
  String get dashboard_personalRecords_warmest => 'Legmelegebb';

  @override
  String get dashboard_quickActions_addSite => 'Merulohely hozzaadasa';

  @override
  String get dashboard_quickActions_addSiteTooltip =>
      'Uj merulohely hozzaadasa';

  @override
  String get dashboard_quickActions_logDive => 'Merules rogzitese';

  @override
  String get dashboard_quickActions_logDiveTooltip => 'Uj merules rogzitese';

  @override
  String get dashboard_quickActions_planDive => 'Merules tervezese';

  @override
  String get dashboard_quickActions_planDiveTooltip => 'Uj merules tervezese';

  @override
  String get dashboard_quickActions_sectionTitle => 'Gyors muveletek';

  @override
  String get dashboard_quickActions_statistics => 'Statisztikak';

  @override
  String get dashboard_quickActions_statisticsTooltip =>
      'Merulesi statisztikak megtekintese';

  @override
  String get dashboard_quickStats_countries => 'Orszagok';

  @override
  String get dashboard_quickStats_countriesSubtitle => 'meglátogatott';

  @override
  String get dashboard_quickStats_sectionTitle => 'Attekintes';

  @override
  String get dashboard_quickStats_species => 'Fajok';

  @override
  String get dashboard_quickStats_speciesSubtitle => 'felfedezett';

  @override
  String get dashboard_quickStats_topBuddy => 'Legjobb buddy';

  @override
  String dashboard_quickStats_topBuddyDives(Object count) {
    return '$count merules';
  }

  @override
  String get dashboard_recentDives_empty => 'Meg nincs rogzitett merules';

  @override
  String get dashboard_recentDives_errorLoading =>
      'Nem sikerult betolteni a meruleseket';

  @override
  String get dashboard_recentDives_latestProfileTitle =>
      'Legutóbbi merülési profil';

  @override
  String get dashboard_recentDives_noProfileData =>
      'Nincs profiladat ehhez a merüléshez';

  @override
  String get dashboard_recentDives_profileLoadError =>
      'A merülési profil betöltése sikertelen';

  @override
  String dashboard_recentDives_profileMinutes(int minutes) {
    return '$minutes perc';
  }

  @override
  String get dashboard_recentDives_logFirst => 'Rogzitse az elso meruleset';

  @override
  String get dashboard_recentDives_sectionTitle => 'Legutobbi merulesek';

  @override
  String get dashboard_recentDives_viewAll => 'Osszes megtekintese';

  @override
  String get dashboard_recentDives_viewAllTooltip =>
      'Osszes merules megtekintese';

  @override
  String dashboard_semantics_activeAlerts(Object count) {
    return '$count aktiv figyelmeztetés';
  }

  @override
  String get dashboard_semantics_errorLoadingRecentDives =>
      'Hiba: Nem sikerult betolteni a legutobbi meruleseket';

  @override
  String get dashboard_semantics_errorLoadingStatistics =>
      'Hiba: Nem sikerult betolteni a statisztikakat';

  @override
  String get dashboard_semantics_greetingBanner =>
      'Iranyitopult udvozlo banner';

  @override
  String get dashboard_stats_errorLoadingStatistics =>
      'Nem sikerult betolteni a statisztikakat';

  @override
  String get dashboard_stats_hoursLogged => 'Rogzitett orak';

  @override
  String get dashboard_stats_maxDepth => 'Max melyseg';

  @override
  String get dashboard_stats_sitesVisited => 'Meglátogatott helyek';

  @override
  String get dashboard_stats_totalDives => 'Osszes merules';

  @override
  String get decoCalculator_addToPlanner => 'Hozzáadás a tervezőhöz';

  @override
  String decoCalculator_bottomTimeSemantics(Object time) {
    return 'Fenéken töltött idő: $time perc';
  }

  @override
  String get decoCalculator_createPlanTooltip =>
      'Merülési terv létrehozása a jelenlegi paraméterekből';

  @override
  String decoCalculator_createdPlanSnackbar(
    Object depth,
    Object depthSymbol,
    Object time,
    Object gasMixName,
  ) {
    return 'Létrehozott terv: $depth$depthSymbol $time percre $gasMixName keverékkel';
  }

  @override
  String get decoCalculator_customMixTrimix => 'Egyedi keverék (Trimix)';

  @override
  String decoCalculator_depthSemantics(Object depth, Object depthSymbol) {
    return 'Mélység: $depth $depthSymbol';
  }

  @override
  String get decoCalculator_diveParameters => 'Merülési paraméterek';

  @override
  String get decoCalculator_endCaution => 'Óvatosan';

  @override
  String get decoCalculator_endDanger => 'Veszély';

  @override
  String get decoCalculator_endSafe => 'Biztonságos';

  @override
  String get decoCalculator_field_bottomTime => 'Fenéken töltött idő';

  @override
  String get decoCalculator_field_depth => 'Mélység';

  @override
  String get decoCalculator_field_gasMix => 'Gázkeverék';

  @override
  String get decoCalculator_gasSafety => 'Gáz biztonság';

  @override
  String get decoCalculator_hideCustomMix => 'Egyedi keverék elrejtése';

  @override
  String get decoCalculator_hideCustomMixSemantics =>
      'Egyedi gázkeverék választó elrejtése';

  @override
  String get decoCalculator_modExceeded => 'MOD túllépve';

  @override
  String get decoCalculator_modSafe => 'MOD biztonságos';

  @override
  String get decoCalculator_ppO2Caution => 'ppO2 óvatosan';

  @override
  String get decoCalculator_ppO2Danger => 'ppO2 veszély';

  @override
  String get decoCalculator_ppO2Hypoxic => 'ppO2 hipoxikus';

  @override
  String get decoCalculator_ppO2Safe => 'ppO2 biztonságos';

  @override
  String get decoCalculator_resetToDefaults =>
      'Alapértelmezések visszaállítása';

  @override
  String get decoCalculator_showCustomMixSemantics =>
      'Egyedi gázkeverék választó megjelenítése';

  @override
  String decoCalculator_timeValueMin(Object time) {
    return '$time perc';
  }

  @override
  String get decoCalculator_title => 'Dekompressziós kalkulátor';

  @override
  String get decoCalculator_waterType => 'Víztípus';

  @override
  String get decoCalculator_waterType_standard => 'Normál';

  @override
  String diveCenters_accessibility_markerLabel(Object name) {
    return 'Búvárközpont: $name';
  }

  @override
  String get diveCenters_accessibility_selected => 'kiválasztva';

  @override
  String diveCenters_accessibility_viewDetails(Object name) {
    return 'Részletek megtekintése: $name';
  }

  @override
  String get diveCenters_accessibility_viewDives =>
      'Merülések megtekintése ezzel a központtal';

  @override
  String get diveCenters_accessibility_viewFullscreenMap =>
      'Teljes képernyős térkép megtekintése';

  @override
  String diveCenters_accessibility_viewSavedCenter(Object name) {
    return 'Mentett búvárközpont megtekintése: $name';
  }

  @override
  String get diveCenters_action_addCenter => 'Központ hozzáadása';

  @override
  String get diveCenters_action_addNew => 'Új hozzáadása';

  @override
  String get diveCenters_action_clearRating => 'Törlés';

  @override
  String get diveCenters_action_gettingLocation => 'Lekérés...';

  @override
  String get diveCenters_action_import => 'Importálás';

  @override
  String get diveCenters_action_importToMyCenters =>
      'Importálás a központjaimhoz';

  @override
  String get diveCenters_action_lookingUp => 'Keresés...';

  @override
  String get diveCenters_action_lookupFromAddress => 'Keresés cím alapján';

  @override
  String get diveCenters_action_pickFromMap => 'Kiválasztás térképről';

  @override
  String get diveCenters_action_retry => 'Újra';

  @override
  String get diveCenters_action_settings => 'Beállítások';

  @override
  String get diveCenters_action_useMyLocation => 'Saját helyzetem használata';

  @override
  String get diveCenters_action_view => 'Megtekintés';

  @override
  String diveCenters_detail_divesLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rögzített merülés',
      one: '1 rögzített merülés',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_detail_divesWithCenter =>
      'Merülések ezzel a központtal';

  @override
  String get diveCenters_detail_noDivesLogged =>
      'Még nincsenek rögzített merülések';

  @override
  String diveCenters_dialog_deleteMessage(Object name) {
    return 'Biztosan törölni szeretnéd: \"$name\"?';
  }

  @override
  String get diveCenters_dialog_deleteTitle => 'Búvárközpont törlése';

  @override
  String get diveCenters_dialog_discard => 'Elvetés';

  @override
  String get diveCenters_dialog_discardMessage =>
      'Nem mentett módosításaid vannak. Biztosan elveted őket?';

  @override
  String get diveCenters_dialog_discardTitle => 'Módosítások elvetése?';

  @override
  String get diveCenters_dialog_keepEditing => 'Szerkesztés folytatása';

  @override
  String get diveCenters_empty_button => 'Első búvárközpont hozzáadása';

  @override
  String get diveCenters_empty_subtitle =>
      'Add hozzá kedvenc búvárüzleteid és szolgáltatóid';

  @override
  String get diveCenters_empty_title => 'Még nincsenek búvárközpontok';

  @override
  String diveCenters_error_generic(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get diveCenters_error_geocodeFailed =>
      'Nem sikerült koordinátákat találni ehhez a címhez';

  @override
  String get diveCenters_error_importFailed =>
      'Búvárközpont importálása sikertelen';

  @override
  String diveCenters_error_loading(Object error) {
    return 'Hiba a búvárközpontok betöltésekor: $error';
  }

  @override
  String get diveCenters_error_locationPermission =>
      'Nem lehet lekérni a helyzetet. Ellenőrizd az engedélyeket.';

  @override
  String get diveCenters_error_locationUnavailable =>
      'Nem lehet lekérni a helyzetet. A helymeghatározás lehet, hogy nem elérhető.';

  @override
  String get diveCenters_error_noAddressForLookup =>
      'Adj meg egy címet a koordináták kereséséhez';

  @override
  String get diveCenters_error_notFound => 'Búvárközpont nem található';

  @override
  String diveCenters_error_saving(Object error) {
    return 'Hiba a búvárközpont mentésekor: $error';
  }

  @override
  String get diveCenters_error_unknown => 'Ismeretlen hiba';

  @override
  String get diveCenters_field_city => 'Város';

  @override
  String get diveCenters_field_country => 'Ország';

  @override
  String get diveCenters_field_latitude => 'Földrajzi szélesség';

  @override
  String get diveCenters_field_longitude => 'Földrajzi hosszúság';

  @override
  String get diveCenters_field_nameRequired => 'Név *';

  @override
  String get diveCenters_field_postalCode => 'Irányítószám';

  @override
  String get diveCenters_field_rating => 'Értékelés';

  @override
  String get diveCenters_field_stateProvince => 'Állam/Megye';

  @override
  String get diveCenters_field_street => 'Utca, házszám';

  @override
  String get diveCenters_hint_addressDescription =>
      'Opcionális utca, házszám navigációhoz';

  @override
  String get diveCenters_hint_affiliationsDescription =>
      'Válaszd ki a képzési szervezeteket, amelyekkel ez a központ kapcsolatban áll';

  @override
  String get diveCenters_hint_city => 'pl. Balaton';

  @override
  String get diveCenters_hint_country => 'pl. Magyarország';

  @override
  String get diveCenters_hint_email => 'info@buvariskola.hu';

  @override
  String get diveCenters_hint_gpsDescription =>
      'Válassz helymeghatározási módszert vagy add meg manuálisan a koordinátákat';

  @override
  String get diveCenters_hint_importSearch =>
      'Búvárközpontok keresése (pl. \"PADI\", \"Thaiföld\")';

  @override
  String get diveCenters_hint_latitude => 'pl. 47.4979';

  @override
  String get diveCenters_hint_longitude => 'pl. 19.0402';

  @override
  String get diveCenters_hint_name => 'Add meg a búvárközpont nevét';

  @override
  String get diveCenters_hint_notes => 'Bármilyen további információ...';

  @override
  String get diveCenters_hint_phone => '+36 30 123 4567';

  @override
  String get diveCenters_hint_postalCode => 'pl. 1234';

  @override
  String get diveCenters_hint_stateProvince => 'pl. Veszprém';

  @override
  String get diveCenters_hint_street => 'pl. Fő utca 123';

  @override
  String get diveCenters_hint_website => 'www.buvariskola.hu';

  @override
  String diveCenters_import_fromDatabase(Object count) {
    return 'Importálás adatbázisból ($count)';
  }

  @override
  String diveCenters_import_myCenters(Object count) {
    return 'Központjaim ($count)';
  }

  @override
  String get diveCenters_import_noResults => 'Nincs találat';

  @override
  String diveCenters_import_noResultsMessage(Object query) {
    return 'Nem találhatók búvárközpontok erre: \"$query\". Próbálj más keresési kifejezést.';
  }

  @override
  String get diveCenters_import_searchDescription =>
      'Keress búvárközpontokat, üzleteket és klubokat a világ körüli szolgáltatók adatbázisából.';

  @override
  String get diveCenters_import_searchError => 'Keresési hiba';

  @override
  String get diveCenters_import_searchHint =>
      'Próbálj név, ország vagy képesítő szervezet alapján keresni.';

  @override
  String get diveCenters_import_searchTitle => 'Búvárközpontok keresése';

  @override
  String get diveCenters_label_alreadyImported => 'Már importálva';

  @override
  String diveCenters_label_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merülés',
      one: '1 merülés',
    );
    return '$_temp0';
  }

  @override
  String get diveCenters_label_email => 'E-mail';

  @override
  String get diveCenters_label_imported => 'Importálva';

  @override
  String get diveCenters_label_locationNotSet => 'Helyszín nincs beállítva';

  @override
  String get diveCenters_label_locationUnknown => 'Ismeretlen helyszín';

  @override
  String get diveCenters_label_phone => 'Telefon';

  @override
  String get diveCenters_label_saved => 'Mentve';

  @override
  String diveCenters_label_source(Object source) {
    return 'Forrás: $source';
  }

  @override
  String get diveCenters_label_website => 'Weboldal';

  @override
  String get diveCenters_map_addCoordinatesHint =>
      'Add hozzá a koordinátákat a búvárközpontjaidhoz, hogy lásd őket a térképen';

  @override
  String get diveCenters_map_noCoordinates =>
      'Nincsenek koordinátákkal rendelkező búvárközpontok';

  @override
  String get diveCenters_picker_newCenter => 'Új búvárközpont';

  @override
  String get diveCenters_picker_title => 'Búvárközpont kiválasztása';

  @override
  String diveCenters_search_noResults(Object query) {
    return 'Nincs találat erre: \"$query\"';
  }

  @override
  String get diveCenters_search_prompt => 'Búvárközpontok keresése';

  @override
  String get diveCenters_section_address => 'Cím';

  @override
  String get diveCenters_section_affiliations => 'Kapcsolatok';

  @override
  String get diveCenters_section_basicInfo => 'Alapvető információk';

  @override
  String get diveCenters_section_contact => 'Kapcsolat';

  @override
  String get diveCenters_section_contactInfo => 'Kapcsolati információk';

  @override
  String get diveCenters_section_gpsCoordinates => 'GPS koordináták';

  @override
  String get diveCenters_section_notes => 'Jegyzetek';

  @override
  String get diveCenters_snackbar_coordinatesFound =>
      'Koordináták megtalálva a címből';

  @override
  String get diveCenters_snackbar_copiedToClipboard => 'Vágólapra másolva';

  @override
  String diveCenters_snackbar_imported(Object name) {
    return 'Importálva: \"$name\"';
  }

  @override
  String get diveCenters_snackbar_locationCaptured => 'Helyszín rögzítve';

  @override
  String diveCenters_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Helyszín rögzítve (±${accuracy}m)';
  }

  @override
  String get diveCenters_snackbar_locationSelectedFromMap =>
      'Helyszín kiválasztva térképről';

  @override
  String get diveCenters_sort_title => 'Búvárközpontok rendezése';

  @override
  String get diveCenters_summary_countries => 'Országok';

  @override
  String get diveCenters_summary_highestRating => 'Legmagasabb értékelés';

  @override
  String get diveCenters_summary_overview => 'Áttekintés';

  @override
  String get diveCenters_summary_quickActions => 'Gyors műveletek';

  @override
  String get diveCenters_summary_recentCenters => 'Legutóbbi búvárközpontok';

  @override
  String get diveCenters_summary_selectPrompt =>
      'Válassz ki egy búvárközpontot a listából a részletek megtekintéséhez';

  @override
  String get diveCenters_summary_totalCenters => 'Összes központ';

  @override
  String get diveCenters_summary_withGps => 'GPS-szel';

  @override
  String get diveCenters_title => 'Búvárközpontok';

  @override
  String get diveCenters_title_add => 'Búvárközpont hozzáadása';

  @override
  String get diveCenters_title_edit => 'Búvárközpont szerkesztése';

  @override
  String get diveCenters_title_import => 'Búvárközpont importálása';

  @override
  String get diveCenters_tooltip_addNew => 'Új búvárközpont hozzáadása';

  @override
  String get diveCenters_tooltip_clearSearch => 'Keresés törlése';

  @override
  String get diveCenters_tooltip_edit => 'Búvárközpont szerkesztése';

  @override
  String get diveCenters_tooltip_fitAllCenters => 'Összes központ mutatása';

  @override
  String get diveCenters_tooltip_listView => 'Lista nézet';

  @override
  String get diveCenters_tooltip_mapView => 'Térkép nézet';

  @override
  String get diveCenters_tooltip_moreOptions => 'További lehetőségek';

  @override
  String get diveCenters_tooltip_search => 'Búvárközpontok keresése';

  @override
  String get diveCenters_tooltip_sort => 'Rendezés';

  @override
  String get diveCenters_validation_invalidEmail =>
      'Adj meg érvényes e-mail címet';

  @override
  String get diveCenters_validation_invalidLatitude =>
      'Érvénytelen földrajzi szélesség';

  @override
  String get diveCenters_validation_invalidLongitude =>
      'Érvénytelen földrajzi hosszúság';

  @override
  String get diveCenters_validation_nameRequired => 'Név megadása kötelező';

  @override
  String get diveComputer_action_setFavorite => 'Beállítás kedvencként';

  @override
  String diveComputer_error_generic(Object error) {
    return 'Hiba történt: $error';
  }

  @override
  String get diveComputer_error_notFound => 'Eszköz nem található';

  @override
  String get diveComputer_status_favorite => 'Kedvenc számítógép';

  @override
  String get diveComputer_title => 'Búvárcomputer';

  @override
  String diveLog_bulkDelete_confirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merulest',
      one: 'merulest',
    );
    return 'Biztosan torolni szeretne $count $_temp0? Ez a muvelet nem vonhato vissza.';
  }

  @override
  String get diveLog_bulkDelete_restored => 'Merulesek visszaallitva';

  @override
  String diveLog_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 torolve';
  }

  @override
  String get diveLog_bulkDelete_title => 'Merulesek torlese';

  @override
  String get diveLog_bulkDelete_undo => 'Visszavonas';

  @override
  String get diveLog_bulkEdit_addTags => 'Cimkek hozzaadasa';

  @override
  String get diveLog_bulkEdit_addTagsDescription =>
      'Cimkek hozzaadasa a kivalasztott merulesekhez';

  @override
  String diveLog_bulkEdit_addedTags(int tagCount, int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      tagCount,
      locale: localeName,
      other: 'cimke',
      one: 'cimke',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'meruleshez',
      one: 'meruleshez',
    );
    return '$tagCount $_temp0 hozzaadva $diveCount $_temp1';
  }

  @override
  String get diveLog_bulkEdit_changeTrip => 'Ut modositasa';

  @override
  String get diveLog_bulkEdit_changeTripDescription =>
      'Kivalasztott merulesek athelyezese egy utra';

  @override
  String get diveLog_bulkEdit_errorLoadingTrips => 'Hiba az utak betoltesekor';

  @override
  String diveLog_bulkEdit_failedAddTags(Object error) {
    return 'Nem sikerult hozzaadni a cimkeket: $error';
  }

  @override
  String diveLog_bulkEdit_failedUpdateTrip(Object error) {
    return 'Nem sikerult frissiteni az utat: $error';
  }

  @override
  String diveLog_bulkEdit_movedToTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 athelyezve az utra';
  }

  @override
  String get diveLog_bulkEdit_noTagsAvailable => 'Nincsenek elerheto cimkek.';

  @override
  String get diveLog_bulkEdit_noTagsAvailableCreate =>
      'Nincsenek elerheto cimkek. Eloszor hozzon letre cimkeket.';

  @override
  String get diveLog_bulkEdit_noTrip => 'Nincs ut';

  @override
  String get diveLog_bulkEdit_removeFromTrip => 'Eltavolitas az utrol';

  @override
  String get diveLog_bulkEdit_removeTags => 'Cimkek eltavolitasa';

  @override
  String get diveLog_bulkEdit_removeTagsDescription =>
      'Cimkek eltavolitasa a kivalasztott merulesekrol';

  @override
  String diveLog_bulkEdit_removedFromTrip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 eltavolitva az utrol';
  }

  @override
  String get diveLog_bulkEdit_selectTrip => 'Ut kivalasztasa';

  @override
  String diveLog_bulkEdit_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 szerkesztese';
  }

  @override
  String get diveLog_bulkExport_csv => 'CSV';

  @override
  String get diveLog_bulkExport_csvDescription => 'Tablazatkezelo formatum';

  @override
  String diveLog_bulkExport_failed(Object error) {
    return 'Exportalas sikertelen: $error';
  }

  @override
  String get diveLog_bulkExport_pdf => 'PDF naplo';

  @override
  String get diveLog_bulkExport_pdfDescription =>
      'Nyomtathato merulesi naplo oldalak';

  @override
  String diveLog_bulkExport_success(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 sikeresen exportalva';
  }

  @override
  String diveLog_bulkExport_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 exportalasa';
  }

  @override
  String get diveLog_bulkExport_uddf => 'UDDF';

  @override
  String get diveLog_bulkExport_uddfDescription =>
      'Univerzalis merulesi adatformatum';

  @override
  String get diveLog_ccr_diluent_air => 'Levego';

  @override
  String get diveLog_ccr_hint_loopVolume => 'pl. 6.0';

  @override
  String get diveLog_ccr_hint_type => 'pl. Sofnolime';

  @override
  String get diveLog_ccr_label_deco => 'Deko';

  @override
  String get diveLog_ccr_label_he => 'He';

  @override
  String get diveLog_ccr_label_highBottom => 'Magas (Also)';

  @override
  String get diveLog_ccr_label_loopVolume => 'Hurokban levo terfogat';

  @override
  String get diveLog_ccr_label_lowDescAsc => 'Alacsony (Le/Fel)';

  @override
  String get diveLog_ccr_label_n2 => 'N₂';

  @override
  String get diveLog_ccr_label_o2 => 'O₂';

  @override
  String get diveLog_ccr_label_rated => 'Nevleges';

  @override
  String get diveLog_ccr_label_remaining => 'Maradek';

  @override
  String get diveLog_ccr_label_type => 'Tipus';

  @override
  String get diveLog_ccr_sectionDiluentGas => 'Higigaz';

  @override
  String get diveLog_ccr_sectionScrubber => 'Szorokeszulek';

  @override
  String get diveLog_ccr_sectionSetpoints => 'Setpointok (bar)';

  @override
  String get diveLog_ccr_title => 'CCR beallitasok';

  @override
  String diveLog_collapsible_semantics_collapse(Object title) {
    return '$title szekció osszecsuklasa';
  }

  @override
  String diveLog_collapsible_semantics_expand(Object title) {
    return '$title szekció kinyitasa';
  }

  @override
  String get diveLog_combine_confirm => 'Összevonás egy merüléssé';

  @override
  String get diveLog_combine_dataNote =>
      'A részletek a legkorábbi merülésből származnak, az üres mezőket a későbbi merülések töltik ki. A jegyzetek összevonásra kerülnek. Az összes palack, felszerelés, búvártárs, cimke és megfigyelés megmarad.';

  @override
  String get diveLog_combine_error =>
      'Nem sikerült összevonni a merüléseket. Semmi sem változott.';

  @override
  String diveLog_combine_gapLabel(String duration) {
    return 'Felszíni szünet: $duration';
  }

  @override
  String get diveLog_combine_longSurfaceWarning =>
      'Egy vagy több felszíni szünet meghaladja a 30 percet. Ezek lehet, hogy külön merülések, nem pedig egyetlen folyamatos merülés.';

  @override
  String get diveLog_combine_mixedDivers =>
      'A kiválasztott merülések különböző búvárokhoz tartoznak, ezért nem vonhatók össze.';

  @override
  String get diveLog_combine_profilePreview => 'Összevont profil';

  @override
  String diveLog_combine_previewIntro(int count) {
    return 'Ez a $count merülés egyetlen folyamatos merüléssé lesz összevonva. A köztük lévő szünetek felszíni idővé válnak.';
  }

  @override
  String diveLog_combine_resultSummary(
    String runtime,
    String maxDepth,
    String bottomTime,
  ) {
    return 'Eredmény: összesen $runtime, legnagyobb mélység $maxDepth, fenékidő $bottomTime';
  }

  @override
  String diveLog_combine_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merülés',
      one: 'merülés',
    );
    return '$count $_temp0 összevonva';
  }

  @override
  String get diveLog_combine_title => 'Merülések összevonása';

  @override
  String get diveLog_combine_undoError =>
      'Nem sikerült visszavonni az összevonást.';

  @override
  String get diveLog_combine_undone => 'Összevonás visszavonva';

  @override
  String get diveLog_computerSource_badge_primary => 'Elsodleges';

  @override
  String get diveLog_consolidate_confirm =>
      'Megtartás egyetlen merülésként mindkét számítógéppel';

  @override
  String get diveLog_consolidate_error_generic =>
      'Nem sikerült összevonni a merüléseket. Semmi sem változott.';

  @override
  String get diveLog_consolidate_error_notOverlapping =>
      'Ezek a merülések időben nem fedik egymást, ezért nem vonhatók össze egyetlen merülésként.';

  @override
  String get diveLog_consolidate_error_sameComputer =>
      'Ezek a merülések ugyanattól a búvárszámítógéptől származnak, ezért így nem vonhatók össze.';

  @override
  String get diveLog_consolidate_selectPrimary => 'Elsődleges búvárszámítógép';

  @override
  String get diveLog_consolidate_snackbar =>
      'A merülés összevonva egy további számítógépként.';

  @override
  String get diveLog_consolidate_undoError =>
      'Nem sikerült visszavonni az összevonást.';

  @override
  String get diveLog_consolidate_undone => 'Összevonás visszavonva';

  @override
  String diveLog_mergeDialog_confirmSubtitle(String time) {
    return 'A(z) $time időpontban indult merülés összevonásra kerül ezzel a merüléssel.';
  }

  @override
  String get diveLog_mergeDialog_confirmTitle => 'Összevonás megerősítése';

  @override
  String get diveLog_mergeDialog_empty =>
      'Nem található más merülés ezen a napon.';

  @override
  String get diveLog_mergeDialog_explanation =>
      'Ennek a merülésnek a profilja, palackjai, nyomásai, eseményei, cimkéi, búvártársai és megfigyelései bekerülnek ebbe a merülésbe mint további számítógépes forrás. Ez a művelet visszavonható a „Számítógép leválasztása” funkcióval.';

  @override
  String diveLog_mergeDialog_loadError(String error) {
    return 'Hiba a merülések betöltésekor: $error';
  }

  @override
  String get diveLog_mergeDialog_merge => 'Összevonás';

  @override
  String get diveLog_mergeDialog_next => 'Tovább';

  @override
  String get diveLog_mergeDialog_subtitle =>
      'Válassz egy merülést ugyanarról a napról, hogy további számítógépként vond össze.';

  @override
  String get diveLog_mergeDialog_title => 'Összevonás egy másik merüléssel';

  @override
  String get diveLog_mergeDialog_whatThisDoes => 'Mit csinál ez';

  @override
  String get diveLog_computerSheet_description =>
      'Válaszd ki, melyik számítógép profiljából szerkesztesz.';

  @override
  String get diveLog_computerSheet_title => 'Kiindulási profil kiválasztása';

  @override
  String diveLog_cylinderSac_avgDepth(Object depth) {
    return 'Atlag: $depth';
  }

  @override
  String get diveLog_cylinderSac_badge_ai => 'AI';

  @override
  String get diveLog_cylinderSac_badge_basic => 'Alap';

  @override
  String get diveLog_cylinderSac_noSac => 'SAC: --';

  @override
  String get diveLog_cylinderSac_tooltip_aiData =>
      'AI adó adatait hasznalja a nagyobb pontossaghoz';

  @override
  String get diveLog_cylinderSac_tooltip_basicData =>
      'Kezdo/veg nyomasokbol szamitva';

  @override
  String get diveLog_deco_badge_deco => 'DEKO';

  @override
  String get diveLog_deco_badge_noDeco => 'NINCS DEKO';

  @override
  String get diveLog_deco_label_ceiling => 'Plafon';

  @override
  String get diveLog_deco_label_leading => 'Vezeto';

  @override
  String get diveLog_deco_label_gf99 => 'GF99';

  @override
  String get diveLog_deco_label_surfGf => 'SurfGF';

  @override
  String get diveLog_deco_label_ndl => 'NDL';

  @override
  String get diveLog_deco_label_time => 'Idő';

  @override
  String get diveLog_deco_label_tts => 'TTS';

  @override
  String diveLog_deco_gf_chip(Object low, Object high) {
    return 'GF: $low/$high';
  }

  @override
  String diveLog_deco_gf_chipFromSettings(Object low, Object high) {
    return 'GF: $low/$high · a te beállításaid';
  }

  @override
  String diveLog_deco_gf_chipRecordedAlgorithm(
    Object algorithm,
    Object low,
    Object high,
  ) {
    return '$algorithm · GF $low/$high értékkel elemezve';
  }

  @override
  String diveLog_deco_gf_semantics(Object low, Object high) {
    return 'Gradiensfaktorok: alacsony $low, magas $high';
  }

  @override
  String get diveLog_deco_gf_tooltipFromSettings =>
      'Ez a búvárkomputer nem rögzítette a gradiensfaktorait, ezért ezt a merülést a beállításaidban szereplő értékekkel elemezzük.';

  @override
  String diveLog_deco_gf_tooltipRecordedAlgorithm(Object algorithm) {
    return 'Ezt a merülést $algorithm algoritmussal számolták, amely nem használ gradiensfaktorokat. A Submersion a beállításaidban szereplő értékekkel elemzi.';
  }

  @override
  String get diveLog_deco_sectionDecoStops => 'Deko megallok';

  @override
  String get diveLog_deco_sectionTissueLoading => 'Szovetterheltseg';

  @override
  String get diveLog_deco_semantics_notRequired =>
      'Dekompresszio nem szukseges';

  @override
  String get diveLog_deco_semantics_required => 'Dekompresszio szukseges';

  @override
  String get diveLog_deco_tissueFast => 'Gyors';

  @override
  String get diveLog_deco_tissueSlow => 'Lassu';

  @override
  String get diveLog_deco_title => 'Deko allapot';

  @override
  String diveLog_deco_totalDecoTime(Object time) {
    return 'Osszes: $time';
  }

  @override
  String get diveLog_delete_cancel => 'Megse';

  @override
  String get diveLog_delete_confirm =>
      'Ez a muvelet nem vonhato vissza. A merules es az osszes kapcsolodo adat (profil, palackok, eszlelesek) veglegesen torlodik.';

  @override
  String get diveLog_delete_delete => 'Torles';

  @override
  String get diveLog_delete_title => 'Merules torlese?';

  @override
  String get diveLog_detail_appBar => 'Merules reszletei';

  @override
  String get diveLog_detail_badge_critical => 'KRITIKUS';

  @override
  String get diveLog_detail_badge_deco => 'DEKO';

  @override
  String get diveLog_detail_badge_noDeco => 'NINCS DEKO';

  @override
  String get diveLog_detail_badge_warning => 'FIGYELMEZTETÉS';

  @override
  String diveLog_detail_buddyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'buddy',
      one: 'buddy',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_button_playback => 'Lejatszas';

  @override
  String get diveLog_detail_button_rangeAnalysis => 'Tartomany stat.';

  @override
  String get diveLog_detail_button_showEnd => 'Veg mutatasa';

  @override
  String get diveLog_detail_captureSignature => 'Oktatoi alairas rogzitese';

  @override
  String diveLog_detail_collapsed_atTime(Object timestamp) {
    return '$timestamp időpontban';
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
    return 'Plafon: $value';
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
    return 'CNS: $cns • Max ppO₂: $maxPpO2 • $timestamp időpontban: $ppO2 bar';
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
      other: 'targy',
      one: 'targy',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_errorLoading => 'Hiba a merules betoltesekor';

  @override
  String get diveLog_detail_label_airTemp => 'Levego hom.';

  @override
  String get diveLog_detail_label_avgDepth => 'Atlag melyseg';

  @override
  String get diveLog_detail_label_buddy => 'Buddy';

  @override
  String get diveLog_detail_label_currentDirection => 'Aramlat iranya';

  @override
  String get diveLog_detail_label_currentStrength => 'Aramlat erossege';

  @override
  String get diveLog_detail_label_diveComputer => 'Merulesszamitogep';

  @override
  String get diveLog_detail_label_serialNumber => 'Sorozatszam';

  @override
  String get diveLog_detail_label_firmwareVersion => 'Firmware verzio';

  @override
  String get diveLog_detail_label_diveMaster => 'Divemaster';

  @override
  String get diveLog_detail_label_diveType => 'Merules tipusa';

  @override
  String get diveLog_detail_label_elevation => 'Magassag';

  @override
  String get diveLog_detail_label_entry => 'Beszallas:';

  @override
  String get diveLog_detail_label_entryMethod => 'Beszallasi mod';

  @override
  String get diveLog_detail_label_exit => 'Kiszallas:';

  @override
  String get diveLog_detail_label_exitMethod => 'Kiszallasi mod';

  @override
  String get diveLog_detail_label_gradientFactors => 'Gradiens faktorok';

  @override
  String get diveLog_detail_label_height => 'Magassag';

  @override
  String get diveLog_detail_label_highTide => 'Dagaly';

  @override
  String get diveLog_detail_label_lowTide => 'Apaly';

  @override
  String get diveLog_detail_label_ppO2AtPoint => 'ppO₂ a kivalasztott pontban:';

  @override
  String get diveLog_detail_label_rateOfChange => 'Valtozasi sebesseg';

  @override
  String get diveLog_detail_label_sacRate => 'SAC ertek';

  @override
  String get diveLog_detail_label_state => 'Allapot';

  @override
  String get diveLog_detail_label_surfaceInterval => 'Felszini szunet';

  @override
  String get diveLog_detail_label_surfacePressure => 'Felszini nyomas';

  @override
  String get diveLog_detail_label_swellHeight => 'Hullammagassag';

  @override
  String get diveLog_detail_label_total => 'Osszes:';

  @override
  String get diveLog_detail_label_visibility => 'Latasvisszonyok';

  @override
  String get diveLog_detail_label_waterType => 'Viz tipusa';

  @override
  String get diveLog_detail_menu_delete => 'Torles';

  @override
  String get diveLog_detail_menu_export => 'Exportalas';

  @override
  String get diveLog_detail_menu_openFullPage => 'Megnyitas teljes oldalon';

  @override
  String get diveLog_detail_noNotes =>
      'Nincsenek jegyzetek ehhez a meruleshez.';

  @override
  String get diveLog_detail_notFound => 'Merules nem talalhato';

  @override
  String diveLog_detail_profilePoints(Object count) {
    return '$count pont';
  }

  @override
  String get diveLog_detail_section_altitudeDive => 'Magassagi merules';

  @override
  String get diveLog_detail_section_buddies => 'Buddyk';

  @override
  String get diveLog_detail_section_conditions => 'Korulmenyek';

  @override
  String get diveLog_detail_section_customFields => 'Custom Fields';

  @override
  String get diveLog_detail_section_decoStatus => 'Deko allapot';

  @override
  String get diveLog_detail_section_details => 'Reszletek';

  @override
  String get diveLog_detail_section_diveProfile => 'Merulesi profil';

  @override
  String get diveLog_detail_section_equipment => 'Felszereles';

  @override
  String get diveLog_detail_section_marineLife => 'Tengeri elet';

  @override
  String get diveLog_detail_section_notes => 'Jegyzetek';

  @override
  String get diveLog_detail_section_oxygenToxicity => 'Oxigen toxicitas';

  @override
  String get diveLog_detail_section_sacRateBySegment =>
      'SAC ertek szakaszonkent';

  @override
  String get diveLog_detail_section_tags => 'Cimkek';

  @override
  String get diveLog_detail_section_cylinders => 'Palackok';

  @override
  String get diveLog_detail_section_tide => 'Arapaly';

  @override
  String get diveLog_detail_section_trainingSignature => 'Kepzesi alairas';

  @override
  String get diveLog_detail_section_weight => 'Suly';

  @override
  String get diveLog_detail_signatureDescription =>
      'Koppintson az oktatoi ellenorzes hozzaadasahoz ehhez a kepzesi meruleshez';

  @override
  String get diveLog_detail_soloDive =>
      'Solo merules vagy nincsenek buddy-k rogzitve';

  @override
  String diveLog_detail_speciesCount(Object count) {
    return '$count faj';
  }

  @override
  String get diveLog_detail_stat_bottomTime => 'Fenekido';

  @override
  String get diveLog_detail_stat_maxDepth => 'Max melyseg';

  @override
  String get diveLog_detail_stat_runtime => 'Futasido';

  @override
  String get diveLog_detail_stat_waterTemp => 'Viz hom.';

  @override
  String diveLog_detail_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'cimke',
      one: 'cimke',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_detail_tideCalculated => 'Arapaly modellbol szamitva';

  @override
  String get diveLog_detail_tooltip_addToFavorites =>
      'Hozzaadas a kedvencekhez';

  @override
  String get diveLog_detail_tooltip_edit => 'Szerkesztes';

  @override
  String get diveLog_detail_tooltip_editDive => 'Merules szerkesztese';

  @override
  String get diveLog_detail_tooltip_previousDive => 'Previous dive';

  @override
  String get diveLog_detail_tooltip_nextDive => 'Next dive';

  @override
  String get diveLog_detail_tooltip_exportProfileImage =>
      'Profil exportalasa kepkent';

  @override
  String get diveLog_detail_tooltip_removeFromFavorites =>
      'Eltavolitas a kedvencekbol';

  @override
  String get diveLog_detail_tooltip_viewFullscreen => 'Teljes kepernyo';

  @override
  String get diveLog_detail_viewSite => 'Merulohely megtekintese';

  @override
  String get diveLog_diveMode_ccrDescription =>
      'Zart koru visszalelegezteto allando ppO₂-vel';

  @override
  String get diveLog_diveMode_gaugeDescription =>
      'Csak mélység és idő; nincs gáz- vagy dekompressziókövetés';

  @override
  String get diveLog_diveMode_ocDescription =>
      'Standard nyilt koru buvarmerules palackokkal';

  @override
  String get diveLog_diveMode_scrDescription =>
      'Felig zart visszalelegezteto valtozo ppO₂-vel';

  @override
  String get diveLog_diveMode_title => 'Merulesi mod';

  @override
  String get diveLog_editSighting_count => 'Darab';

  @override
  String get diveLog_editSighting_notes => 'Jegyzetek';

  @override
  String get diveLog_editSighting_notesHint => 'Meret, viselkedes, helyszin...';

  @override
  String get diveLog_editSighting_remove => 'Eltavolitas';

  @override
  String diveLog_editSighting_removeConfirm(Object name) {
    return '$name eltavolitasa errol a merulesrol?';
  }

  @override
  String get diveLog_editSighting_removeTitle => 'Eszleles eltavolitasa?';

  @override
  String get diveLog_editSighting_save => 'Valtozasok mentese';

  @override
  String get diveLog_edit_add => 'Hozzaadas';

  @override
  String get diveLog_edit_addCustomField => 'Add Field';

  @override
  String get diveLog_edit_addTank => 'Palack hozzaadasa';

  @override
  String get diveLog_edit_addWeightEntry => 'Suly bevetel hozzaadasa';

  @override
  String diveLog_edit_addedGps(Object name) {
    return 'GPS hozzaadva: $name';
  }

  @override
  String get diveLog_edit_appBarEdit => 'Merules szerkesztese';

  @override
  String get diveLog_edit_appBarNew => 'Merules rogzitese';

  @override
  String get diveLog_edit_cancel => 'Megse';

  @override
  String get diveLog_edit_clearAllEquipment => 'Osszes torlese';

  @override
  String diveLog_edit_createdSite(Object name) {
    return 'Letrehozott merulohely: $name';
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
    return 'Idotartam: $minutes min';
  }

  @override
  String get diveLog_edit_equipmentHint =>
      'Koppintson a \"Keszlet hasznalata\" vagy \"Hozzaadas\" gombra a felszereles kivalasztasahoz';

  @override
  String diveLog_edit_errorLoadingDiveTypes(Object error) {
    return 'Hiba a merules tipusok betoltesekor: $error';
  }

  @override
  String get diveLog_edit_gettingLocation => 'Helymeghatározás...';

  @override
  String get diveLog_edit_group_buddies => 'Merülőtársak';

  @override
  String get diveLog_edit_group_conditions => 'Körülmények';

  @override
  String get diveLog_edit_group_experience => 'Élmény';

  @override
  String get diveLog_edit_group_gasGear => 'Gáz és felszerelés';

  @override
  String get diveLog_edit_group_theDive => 'A merülés';

  @override
  String get diveLog_edit_group_trip => 'Utazás';

  @override
  String get diveLog_edit_headerNew => 'Uj merules rogzitese';

  @override
  String get diveLog_edit_invite_buddies => 'Merülőtársak hozzáadása';

  @override
  String get diveLog_edit_invite_conditions =>
      'Körülmények hozzáadása - víz, látótávolság, időjárás';

  @override
  String get diveLog_edit_invite_experience =>
      'Értékelés, észlelések, jegyzetek vagy címkék hozzáadása';

  @override
  String get diveLog_edit_invite_gasGear =>
      'Gáz és felszerelés hozzáadása - mód, palackok, felszerelés, súly';

  @override
  String get diveLog_edit_invite_trip => 'Utazás vagy búvárközpont hozzáadása';

  @override
  String get diveLog_edit_label_airTemp => 'Levego hom.';

  @override
  String get diveLog_edit_label_altitude => 'Magassag';

  @override
  String get diveLog_edit_label_avgDepth => 'Atlag melyseg';

  @override
  String get diveLog_edit_label_bottomTime => 'Fenekido';

  @override
  String get diveLog_edit_label_currentDirection => 'Aramlat iranya';

  @override
  String get diveLog_edit_label_currentStrength => 'Aramlat erossege';

  @override
  String get diveLog_edit_label_diveType => 'Merules tipusa';

  @override
  String get diveLog_edit_label_diveTypes => 'Merülés típusok';

  @override
  String get diveLog_edit_label_diveNumber => 'Merules sz.';

  @override
  String get diveLog_edit_label_diveName => 'Név';

  @override
  String get diveLog_edit_diveNamePlaceholder =>
      'Opcionális név ehhez a merüléshez';

  @override
  String get diveLog_edit_hint_diveNumber =>
      'Automatikusan kiosztva, ha ures marad';

  @override
  String get diveLog_edit_label_entryMethod => 'Beszallasi mod';

  @override
  String get diveLog_edit_label_exitMethod => 'Kiszallasi mod';

  @override
  String get diveLog_edit_label_maxDepth => 'Max melyseg';

  @override
  String get diveLog_edit_label_runtime => 'Futasido';

  @override
  String get diveLog_edit_label_surfacePressure => 'Felszini nyomas';

  @override
  String get diveLog_edit_label_swellHeight => 'Hullammagassag';

  @override
  String get diveLog_edit_label_type => 'Tipus';

  @override
  String get diveLog_edit_label_visibility => 'Latasvisszonyok';

  @override
  String get diveLog_edit_label_waterTemp => 'Viz hom.';

  @override
  String get diveLog_edit_label_waterType => 'Viz tipusa';

  @override
  String get diveLog_edit_marineLifeHint =>
      'Koppintson a \"Hozzaadas\" gombra az eszlelesek rogzitesehez';

  @override
  String get diveLog_edit_nearbySitesFirst => 'Kozeli helyek elol';

  @override
  String get diveLog_edit_noEquipmentSelected =>
      'Nincs kivalasztott felszereles';

  @override
  String get diveLog_edit_noMarineLife => 'Nincs rogzitett tengeri elet';

  @override
  String get diveLog_edit_notSpecified => 'Nincs megadva';

  @override
  String get diveLog_edit_notesHint =>
      'Jegyzetek hozzaadasa ehhez a meruleshez...';

  @override
  String get diveLog_edit_overline_tanks => 'Palackok';

  @override
  String get diveLog_edit_profile_draw => 'Profil rajzolása';

  @override
  String get diveLog_edit_profile_none => 'Nincs rögzítve';

  @override
  String diveLog_edit_profile_outliers(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lehetséges kiugró érték észlelve',
      one: '1 lehetséges kiugró érték észlelve',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_profile_points(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pont',
      one: '1 pont',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_row_addSite => 'Merülőhely hozzáadása';

  @override
  String get diveLog_edit_row_diveCenter => 'Búvárközpont';

  @override
  String get diveLog_edit_row_diveProfile => 'Merülési profil';

  @override
  String get diveLog_edit_row_entry => 'Beszállás';

  @override
  String get diveLog_edit_row_exit => 'Kiszállás';

  @override
  String get diveLog_edit_row_notSet => 'Nincs megadva';

  @override
  String get diveLog_edit_row_site => 'Merülőhely';

  @override
  String get diveLog_edit_row_surfaceInterval => 'Felszíni idő';

  @override
  String get diveLog_edit_row_trip => 'Utazás';

  @override
  String get diveLog_edit_save => 'Mentes';

  @override
  String get diveLog_edit_saveAsSet => 'Mentes keszletkent';

  @override
  String diveLog_edit_saveAsSetDialog_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'targy',
      one: 'targy',
    );
    return '$count $_temp0 mentese uj felszereléskészletként.';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_description => 'Leiras (opcionalis)';

  @override
  String get diveLog_edit_saveAsSetDialog_descriptionHint =>
      'pl. Konnyu felszereles meleg vizhez';

  @override
  String diveLog_edit_saveAsSetDialog_error(Object error) {
    return 'Hiba a keszlet letrehozasakor: $error';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_setName => 'Keszlet neve';

  @override
  String get diveLog_edit_saveAsSetDialog_setNameHint => 'pl. Tropusi merules';

  @override
  String diveLog_edit_saveAsSetDialog_success(Object name) {
    return '\"$name\" felszereléskészlet letrehozva';
  }

  @override
  String get diveLog_edit_saveAsSetDialog_title =>
      'Mentes felszereléskészletként';

  @override
  String get diveLog_edit_saveAsSetDialog_validation =>
      'Kerjuk adjon meg egy keszletnevet';

  @override
  String get diveLog_edit_section_conditions => 'Korulmenyek';

  @override
  String get diveLog_edit_section_customFields => 'Custom Fields';

  @override
  String get diveLog_edit_section_depthDuration => 'Melyseg es idotartam';

  @override
  String get diveLog_edit_section_diveCenter => 'Merulocentrum';

  @override
  String get diveLog_edit_section_diveSite => 'Merulohely';

  @override
  String get diveLog_edit_section_entryTime => 'Beszallas ideje';

  @override
  String get diveLog_edit_section_equipment => 'Felszereles';

  @override
  String get diveLog_edit_section_exitTime => 'Kiszallas ideje';

  @override
  String get diveLog_edit_section_marineLife => 'Tengeri elet';

  @override
  String get diveLog_edit_section_notes => 'Jegyzetek';

  @override
  String get diveLog_edit_section_rating => 'Ertekeles';

  @override
  String get diveLog_edit_section_tags => 'Cimkek';

  @override
  String diveLog_edit_section_tanks(Object count) {
    return 'Palackok ($count)';
  }

  @override
  String get diveLog_edit_section_trainingCourse => 'Kepzesi tanfolyam';

  @override
  String get diveLog_edit_section_trip => 'Ut';

  @override
  String get diveLog_edit_section_weight => 'Suly';

  @override
  String get diveLog_edit_select => 'Kivalasztas';

  @override
  String get diveLog_edit_selectDiveCenter => 'Merulocentrum kivalasztasa';

  @override
  String get diveLog_edit_selectDiveSite => 'Merulohely kivalasztasa';

  @override
  String get diveLog_edit_selectTrip => 'Ut kivalasztasa';

  @override
  String diveLog_edit_snackbar_avgDepthCalculated(Object depth) {
    return 'Átlagos mélység kiszámítva: $depth';
  }

  @override
  String diveLog_edit_snackbar_bottomTimeCalculated(Object minutes) {
    return 'Fenekido kiszamitva: $minutes min';
  }

  @override
  String diveLog_edit_snackbar_errorSaving(Object error) {
    return 'Hiba a merules mentesekor: $error';
  }

  @override
  String diveLog_edit_snackbar_maxDepthCalculated(Object depth) {
    return 'Maximális mélység kiszámítva: $depth';
  }

  @override
  String get diveLog_edit_snackbar_noProfileData =>
      'Nincs elerheto merulesi profil adat';

  @override
  String diveLog_edit_snackbar_runtimeCalculated(Object minutes) {
    return 'Futásidő kiszámítva: $minutes perc';
  }

  @override
  String get diveLog_edit_snackbar_unableToCalculateAvgDepth =>
      'Az átlagos mélység nem számítható ki a profilból';

  @override
  String get diveLog_edit_snackbar_unableToCalculate =>
      'Nem sikerult a fenekidot kiszamitani a profilbol';

  @override
  String get diveLog_edit_snackbar_unableToCalculateMaxDepth =>
      'A maximális mélység nem számítható ki a profilból';

  @override
  String get diveLog_edit_snackbar_unableToCalculateRuntime =>
      'A futásidő nem számítható ki a profilból';

  @override
  String diveLog_edit_summary_items(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elem',
      one: '1 elem',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_edit_summary_notes => 'jegyzetek';

  @override
  String diveLog_edit_summary_species(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faj',
      one: '1 faj',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_summary_tanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palack',
      one: '1 palack',
    );
    return '$_temp0';
  }

  @override
  String diveLog_edit_surfaceInterval(Object interval) {
    return 'Felszini szunet: $interval';
  }

  @override
  String get diveLog_edit_surfacePressureDefault => '1013';

  @override
  String get diveLog_edit_surfacePressureHint =>
      'Standard: 1013 mbar tengerszinten';

  @override
  String get diveLog_edit_tankCard_done => 'Kész';

  @override
  String get diveLog_edit_tankCard_edit => 'Szerkesztés';

  @override
  String get diveLog_edit_tankCard_mix => 'Keverék';

  @override
  String get diveLog_edit_tankCard_pressure => 'Nyomás';

  @override
  String diveLog_edit_tankCard_title(int number) {
    return '$number. palack';
  }

  @override
  String get diveLog_edit_tankCard_volume => 'Térfogat';

  @override
  String get diveLog_edit_tooltip_calculateFromProfile =>
      'Szamitas a merulesi profilbol';

  @override
  String get diveLog_edit_tooltip_clearDiveCenter => 'Merulocentrum torlese';

  @override
  String get diveLog_edit_tooltip_clearSite => 'Merulohely torlese';

  @override
  String get diveLog_edit_tooltip_clearTrip => 'Ut torlese';

  @override
  String get diveLog_edit_tooltip_removeEquipment => 'Felszereles eltavolitasa';

  @override
  String get diveLog_edit_tooltip_removeSighting => 'Eszleles eltavolitasa';

  @override
  String get diveLog_edit_tooltip_removeWeight => 'Eltavolitas';

  @override
  String get diveLog_edit_trainingCourseHint =>
      'Merules osszekapcsolasa egy kepzesi tanfolyammal';

  @override
  String diveLog_edit_tripSuggested(Object name) {
    return 'Javasolt: $name';
  }

  @override
  String get diveLog_edit_tripUse => 'Hasznalas';

  @override
  String get diveLog_edit_useSet => 'Keszlet hasznalata';

  @override
  String diveLog_edit_weightTotal(Object total) {
    return 'Osszes: $total';
  }

  @override
  String get diveLog_emptyFiltered_clearFilters => 'Szurok torlese';

  @override
  String get diveLog_emptyFiltered_subtitle =>
      'Probalja modositani vagy torolni a szuroket';

  @override
  String get diveLog_emptyFiltered_title =>
      'Nincs a szuroknek megfelelo merules';

  @override
  String get diveLog_empty_logFirstDive => 'Rogzitse az elso meruleset';

  @override
  String get diveLog_empty_subtitle =>
      'Koppintson az alabbi gombra az elso merules rogzitesehez';

  @override
  String get diveLog_empty_title => 'Meg nincs rogzitett merules';

  @override
  String get diveLog_equipmentPicker_addFromTab =>
      'Adjon hozza felszerelest a Felszereles fulon';

  @override
  String get diveLog_equipmentPicker_allSelected =>
      'Minden felszereles mar ki van valasztva';

  @override
  String diveLog_equipmentPicker_errorLoading(Object error) {
    return 'Hiba a felszereles betoltesekor: $error';
  }

  @override
  String get diveLog_equipmentPicker_noEquipment => 'Meg nincs felszereles';

  @override
  String get diveLog_equipmentPicker_removeToAdd =>
      'Tavolitson el elemeket masok hozzaadasahoz';

  @override
  String get diveLog_equipmentPicker_title => 'Felszereles hozzaadasa';

  @override
  String get diveLog_equipmentSetPicker_createHint =>
      'Keszleteket a Felszereles > Keszletek menuben hozhat letre';

  @override
  String get diveLog_equipmentSetPicker_emptySet => 'Ures keszlet';

  @override
  String get diveLog_equipmentSetPicker_errorItems =>
      'Hiba az elemek betoltesekor';

  @override
  String diveLog_equipmentSetPicker_errorLoading(Object error) {
    return 'Hiba a felszereléskészletek betoltesekor: $error';
  }

  @override
  String diveLog_equipmentSetPicker_itemsSummary(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elem',
      one: '1 elem',
    );
    return '$_temp0: $names';
  }

  @override
  String get diveLog_equipmentSetPicker_loading => 'Betoltes...';

  @override
  String get diveLog_equipmentSetPicker_noSets =>
      'Meg nincsenek felszereléskészletek';

  @override
  String get diveLog_equipmentSetPicker_title =>
      'Felszereléskészlet hasznalata';

  @override
  String get diveLog_error_loadingDives => 'Hiba a merulesek betoltesekor';

  @override
  String get diveLog_error_retry => 'Ujra';

  @override
  String get diveLog_exportImage_captureFailed =>
      'Nem sikerult a kep rogzitese';

  @override
  String get diveLog_exportImage_generateFailed =>
      'Nem sikerult a kep letrehozasa';

  @override
  String get diveLog_exportImage_generatingPdf => 'PDF letrehozasa...';

  @override
  String get diveLog_exportImage_pdfSaved => 'PDF mentve';

  @override
  String get diveLog_exportImage_saveToFiles => 'Mentes fajlokba';

  @override
  String get diveLog_exportImage_saveToFilesDescription =>
      'Valasszon helyet a fajl mentesehez';

  @override
  String get diveLog_exportImage_saveToPhotos => 'Mentes fotokba';

  @override
  String get diveLog_exportImage_saveToPhotosDescription =>
      'Kep mentese a fotokonyvarba';

  @override
  String get diveLog_exportImage_savedToFiles => 'Kep mentve';

  @override
  String get diveLog_exportImage_savedToPhotos => 'Kep mentve a Fotokba';

  @override
  String get diveLog_exportImage_share => 'Megosztas';

  @override
  String get diveLog_exportImage_shareDescription =>
      'Megosztas mas alkalmazasokon keresztul';

  @override
  String get diveLog_exportImage_titleDetails =>
      'Merulesi reszletek kep exportalasa';

  @override
  String get diveLog_exportImage_titlePdf => 'PDF exportalas';

  @override
  String get diveLog_exportImage_titleProfile => 'Profil kep exportalasa';

  @override
  String get diveLog_export_csv => 'CSV';

  @override
  String get diveLog_export_csvDescription => 'Tablazatkezelo formatum';

  @override
  String get diveLog_export_exporting => 'Exportalas...';

  @override
  String diveLog_export_failed(Object error) {
    return 'Exportalas sikertelen: $error';
  }

  @override
  String get diveLog_export_pageAsImage => 'Oldal kepkent';

  @override
  String get diveLog_export_pageAsImageDescription =>
      'Kepernyokep a teljes merulesi reszletekrol';

  @override
  String get diveLog_export_pdfDescription =>
      'Nyomtathato merulesi naplo oldal';

  @override
  String get diveLog_export_pdfLogbookEntry => 'PDF naplo bejegyzes';

  @override
  String get diveLog_export_success => 'Merules sikeresen exportalva';

  @override
  String diveLog_export_titleDiveNumber(Object number) {
    return 'Merules #$number exportalasa';
  }

  @override
  String get diveLog_export_uddf => 'UDDF';

  @override
  String get diveLog_export_uddfDescription =>
      'Univerzalis merulesi adatformatum';

  @override
  String get diveLog_filterChip_clearAll => 'Osszes torlese';

  @override
  String get diveLog_filterChip_favorites => 'Kedvencek';

  @override
  String diveLog_filterChip_from(Object date) {
    return 'Ettol: $date';
  }

  @override
  String get diveLog_filterChip_noBuddy => 'Nincs buddy';

  @override
  String diveLog_filterChip_until(Object date) {
    return 'Eddig: $date';
  }

  @override
  String get diveLog_filter_allSites => 'Osszes merulohely';

  @override
  String get diveLog_filter_allTypes => 'Osszes tipus';

  @override
  String get diveLog_filter_apply => 'Szurok alkalmazasa';

  @override
  String get diveLog_filter_buddyHint => 'Kereses buddy nev alapjan';

  @override
  String get diveLog_filter_buddyName => 'Buddy neve';

  @override
  String get diveLog_filter_clearAll => 'Osszes torlese';

  @override
  String get diveLog_filter_clearDates => 'Datumok torlese';

  @override
  String get diveLog_filter_clearRating => 'Ertekeles szuro torlese';

  @override
  String get diveLog_filter_clearWeekdays => 'Het napjai torlese';

  @override
  String get diveLog_filter_dateSeparator => 'tol';

  @override
  String get diveLog_filter_endDate => 'Zaras datuma';

  @override
  String get diveLog_filter_errorLoadingSites =>
      'Hiba a merulohelyek betoltesekor';

  @override
  String get diveLog_filter_errorLoadingTags => 'Hiba a cimkek betoltesekor';

  @override
  String get diveLog_filter_favoritesOnly => 'Csak kedvencek';

  @override
  String get diveLog_filter_gasAir => 'Levego (21%)';

  @override
  String get diveLog_filter_gasAll => 'Osszes';

  @override
  String get diveLog_filter_gasNitrox => 'Nitrox (>21%)';

  @override
  String get diveLog_filter_max => 'Max';

  @override
  String get diveLog_filter_min => 'Min';

  @override
  String get diveLog_filter_noBuddyOnly => 'Nincs buddy hozzarendelve';

  @override
  String get diveLog_filter_noTagsYet => 'Meg nincsenek letrehozott cimkek';

  @override
  String get diveLog_filter_presetAllTime => 'Teljes időszak';

  @override
  String get diveLog_filter_presetLast12Months => 'Elmúlt 12 hónap';

  @override
  String get diveLog_filter_presetLastYear => 'Tavaly';

  @override
  String get diveLog_filter_presetThisYear => 'Idén';

  @override
  String get diveLog_filter_sectionBuddy => 'Buddy';

  @override
  String get diveLog_filter_sectionDateRange => 'Datumtartomany';

  @override
  String get diveLog_filter_sectionDepthRange => 'Melyseg tartomany (meter)';

  @override
  String get diveLog_filter_sectionDiveSite => 'Merulohely';

  @override
  String get diveLog_filter_sectionDiveType => 'Merules tipusa';

  @override
  String get diveLog_filter_sectionDuration => 'Idotartam (perc)';

  @override
  String get diveLog_filter_sectionGasMix => 'Gazkeverek (O₂%)';

  @override
  String get diveLog_filter_sectionMinRating => 'Minimum ertekeles';

  @override
  String get diveLog_filter_sectionTags => 'Cimkek';

  @override
  String get diveLog_filter_sectionWeekdays => 'Het napjai';

  @override
  String get diveLog_filter_showOnlyFavorites =>
      'Csak kedvenc merulesek mutatasa';

  @override
  String get diveLog_filter_showOnlyNoBuddy =>
      'Csak buddy nelkuli merulesek mutatasa';

  @override
  String get diveLog_filter_startDate => 'Kezdes datuma';

  @override
  String get diveLog_filter_title => 'Merulesek szurese';

  @override
  String get diveLog_filter_resizeGrip => 'Szűrőpanel átméretezése';

  @override
  String get diveLog_filter_tooltip_close => 'Szuro bezarasa';

  @override
  String get diveLog_fullscreenProfile_close => 'Teljes kepernyo bezarasa';

  @override
  String get diveLog_fullscreenProfile_readoutHint =>
      'Vigye az egermutatot a profil fole, vagy huzza rajta az ujjat';

  @override
  String diveLog_fullscreenProfile_title(Object number) {
    return 'Merules #$number profil';
  }

  @override
  String get diveLog_legend_label_ascentRate => 'Felszallasi sebesseg';

  @override
  String get diveLog_legend_label_ascentRateLine =>
      'Felszallasi sebesseg vonal';

  @override
  String get diveLog_legend_label_ceiling => 'Plafon';

  @override
  String get diveLog_legend_label_decoStops => 'Deco stops';

  @override
  String get diveLog_legend_label_cns => 'CNS%';

  @override
  String get diveLog_legend_label_depth => 'Melyseg';

  @override
  String get diveLog_legend_label_events => 'Esemenyek';

  @override
  String get diveLog_legend_label_gasDensity => 'Gaz suruseg';

  @override
  String get diveLog_legend_label_gasSwitches => 'Gazcserelesek';

  @override
  String get diveLog_legend_label_gfPercent => 'GF%';

  @override
  String get diveLog_legend_label_heartRate => 'Pulzus';

  @override
  String get diveLog_legend_label_maxDepth => 'Max melyseg';

  @override
  String get diveLog_legend_label_meanDepth => 'Atlag melyseg';

  @override
  String get diveLog_legend_label_mod => 'MOD';

  @override
  String get diveLog_legend_label_ndl => 'NDL';

  @override
  String get diveLog_legend_label_otu => 'OTU';

  @override
  String get diveLog_legend_label_photoMarkers => 'Fotók';

  @override
  String get diveLog_legend_label_ppHe => 'ppHe';

  @override
  String get diveLog_legend_label_ppN2 => 'ppN2';

  @override
  String get diveLog_legend_label_ppO2 => 'ppO2';

  @override
  String get diveLog_legend_label_pressure => 'Nyomas';

  @override
  String get diveLog_legend_label_pressureThresholds => 'Nyomas kuszobertek';

  @override
  String get diveLog_legend_label_sacRate => 'SAC ertek';

  @override
  String get diveLog_legend_label_showGas => 'Gazok';

  @override
  String get diveLog_legend_label_surfaceGf => 'Felszini GF';

  @override
  String get diveLog_legend_label_temp => 'Hom.';

  @override
  String get diveLog_legend_label_tts => 'TTS';

  @override
  String get diveLog_legend_source_dc => 'DC';

  @override
  String get diveLog_legend_source_calc => 'Szam.';

  @override
  String get diveLog_chartSection_overlays => 'Rategek';

  @override
  String get diveLog_chartSection_markers => 'Jelolok';

  @override
  String get diveLog_chartSection_decompression => 'Dekompresszio';

  @override
  String get diveLog_chartSection_gasAnalysis => 'Gazelemzes';

  @override
  String get diveLog_chartSection_display => 'Megjelenítés';

  @override
  String get diveLog_chartSection_other => 'Egyeb';

  @override
  String get diveLog_chartSection_tankPressures => 'Palacknyomasok';

  @override
  String get diveLog_chartOption_metricsFollowViewport =>
      'Rétegek nézetben tartása';

  @override
  String get diveLog_pressure_estimatedSuffix => '(becs.)';

  @override
  String get diveLog_listPage_appBar_diveMap => 'Merulesi terkep';

  @override
  String get diveLog_listPage_compactTitle => 'Merulesek';

  @override
  String diveLog_listPage_errorLoading(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get diveLog_listPage_bottomSheet_importFromComputer =>
      'Importalas meruloszamitogebol';

  @override
  String get diveLog_listPage_bottomSheet_scanPaperLog =>
      'Papir naplo beolvasasa';

  @override
  String get ocrImport_scanPage_processing => 'Oldal beolvasasa...';

  @override
  String get ocrImport_scanPage_pickPhoto => 'Foto kivalasztasa';

  @override
  String get ocrImport_scanPage_takePhoto => 'Foto keszitese';

  @override
  String get ocrImport_scanPage_nothingRead =>
      'Nem sikerult sokat kiolvasni az oldalbol - a mezok uresen maradtak';

  @override
  String get ocrImport_scanPage_engineMissing =>
      'A szovegfelismeres nem erheto el. Telepitse a Tesseract-ot a papir naplok beolvasasahoz (peldaul: sudo apt install tesseract-ocr).';

  @override
  String get ocrImport_editPage_photoAttachFailed =>
      'A merules mentve, de a beolvasott oldal csatolasa nem sikerult';

  @override
  String get diveLog_listPage_bottomSheet_logManually =>
      'Merules manualis rogzitese';

  @override
  String get diveLog_listPage_fab_addDive => 'Merules hozzaadasa';

  @override
  String get diveLog_listPage_fab_logDive => 'Merules rogzitese';

  @override
  String get diveLog_listPage_menuAdvancedSearch => 'Specialis kereses';

  @override
  String get diveLog_listPage_menuDiveNumbering => 'Merules szamozas';

  @override
  String get diveLog_listPage_menuMatchSites =>
      'Merülések hozzárendelése helyekhez';

  @override
  String get diveLog_sighting_decreaseCount => 'Darabszám csökkentése';

  @override
  String get diveLog_sighting_increaseCount => 'Darabszám növelése';

  @override
  String diveLog_speciesPicker_errorLoading(String error) {
    return 'Hiba a fajok betöltésekor: $error';
  }

  @override
  String get diveRole_builtin_buddy => 'Búvártárs';

  @override
  String get diveRole_builtin_diveGuide => 'Merülésvezető';

  @override
  String get diveRole_builtin_diveMaster => 'Divemaster';

  @override
  String get diveRole_builtin_instructor => 'Oktató';

  @override
  String get diveRole_builtin_rearGuard => 'Sereghajtó';

  @override
  String get diveRole_builtin_safetyDiver => 'Biztosító búvár';

  @override
  String get diveRole_builtin_solo => 'Szóló';

  @override
  String get diveRole_builtin_student => 'Tanuló';

  @override
  String get diveRole_builtin_supportDiver => 'Támogató búvár';

  @override
  String get diveRoles_addDialog_addButton => 'Hozzáadás';

  @override
  String get diveRoles_addDialog_nameHint => 'pl. Fotós';

  @override
  String get diveRoles_addDialog_nameLabel => 'Merülési szerep neve';

  @override
  String get diveRoles_addDialog_nameValidation => 'Adj meg egy nevet';

  @override
  String get diveRoles_addDialog_title => 'Egyedi merülési szerep hozzáadása';

  @override
  String get diveRoles_addTooltip => 'Merülési szerep hozzáadása';

  @override
  String get diveRoles_appBar_title => 'Merülési szerepek';

  @override
  String get diveRoles_builtInHeader => 'Beépített merülési szerepek';

  @override
  String get diveRoles_customHeader => 'Egyedi merülési szerepek';

  @override
  String diveRoles_deleteDialog_content(Object name) {
    return 'Biztosan törölni szeretnéd: \"$name\"?';
  }

  @override
  String get diveRoles_deleteDialog_title => 'Merülési szerep törlése?';

  @override
  String get diveRoles_deleteTooltip => 'Merülési szerep törlése';

  @override
  String get diveRoles_renameDialog_title => 'Merülési szerep átnevezése';

  @override
  String get diveRoles_renameTooltip => 'Merülési szerep átnevezése';

  @override
  String diveRoles_snackbar_added(Object name) {
    return 'Merülési szerep hozzáadva: $name';
  }

  @override
  String diveRoles_snackbar_cannotDelete(Object name) {
    return 'Nem lehet törölni \"$name\" - meglévő merülések használják';
  }

  @override
  String diveRoles_snackbar_deleted(Object name) {
    return 'Merülési szerep törölve: $name';
  }

  @override
  String diveRoles_snackbar_errorAdding(Object error) {
    return 'Hiba a merülési szerep hozzáadásakor: $error';
  }

  @override
  String get diveSites_edit_depth_heroMax => 'Max. mélység';

  @override
  String get diveSites_edit_depth_heroMin => 'Min. mélység';

  @override
  String get diveSites_edit_group_accessSafety => 'Megközelítés és biztonság';

  @override
  String get diveSites_edit_group_diveInfo => 'Merülési adatok';

  @override
  String get diveSites_edit_group_identity => 'Azonosítás';

  @override
  String get diveSites_edit_group_lifeNotes => 'Élővilág és jegyzetek';

  @override
  String get diveSites_edit_group_location => 'Helyzet';

  @override
  String get diveSites_edit_invite_accessSafety =>
      'Megközelítés, parkolás, kikötés vagy veszélyek hozzáadása';

  @override
  String get diveSites_edit_invite_diveInfo =>
      'Mélységtartomány, nehézség vagy értékelés hozzáadása';

  @override
  String get diveSites_edit_invite_lifeNotes =>
      'Élővilág, jegyzetek vagy megosztás hozzáadása';

  @override
  String get diveSites_edit_invite_location =>
      'GPS-pozíció vagy magasság hozzáadása';

  @override
  String get diveSites_edit_summary_shared => 'megosztva';

  @override
  String get forms_addSection_prefix => 'Hozzáadás:';

  @override
  String get forms_cancel => 'Mégse';

  @override
  String get forms_discard_body =>
      'Nem mentett módosításai vannak. Ha most kilép, elvesznek.';

  @override
  String get forms_discard_discard => 'Elvetés';

  @override
  String get forms_discard_keepEditing => 'Szerkesztés folytatása';

  @override
  String get forms_discard_title => 'Elveti a módosításokat?';

  @override
  String get forms_save => 'Mentés';

  @override
  String forms_section_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count probléma',
      one: '1 probléma',
    );
    return '$_temp0';
  }

  @override
  String get settings_manage_setupAssistant => 'Beállítási varázsló';

  @override
  String get settings_manage_setupAssistant_subtitle =>
      'Mértékegységek, megjelenés és biztonsági mentés áttekintése';

  @override
  String get setup_backup_cloudCopy =>
      'Biztonsági mentések tárolása a felhőben';

  @override
  String get setup_backup_frequency => 'Gyakoriság';

  @override
  String get setup_backup_frequency_daily => 'Naponta';

  @override
  String get setup_backup_frequency_monthly => 'Havonta';

  @override
  String get setup_backup_frequency_weekly => 'Hetente';

  @override
  String get setup_backup_scheduleSubtitle =>
      'Adatok rendszeres biztonsági mentése';

  @override
  String get setup_backup_scheduleToggle => 'Automatikus biztonsági mentés';

  @override
  String get setup_backup_subtitle => 'Védje adatait az első naptól kezdve.';

  @override
  String get setup_backup_title => 'Biztonsági mentés és szinkronizálás';

  @override
  String get setup_common_back => 'Vissza';

  @override
  String get setup_common_next => 'Tovább';

  @override
  String get setup_common_skip => 'Kihagyás';

  @override
  String get setup_existing_folder_subtitle =>
      'Irányítsa a Submersiont egy olyan mappára, amely már tartalmaz könyvtárat';

  @override
  String get setup_existing_folder_title => 'Meglévő mappa megnyitása';

  @override
  String get setup_existing_restore_subtitle =>
      'Válasszon egy Submersionból exportált biztonságimentés-fájlt';

  @override
  String get setup_existing_restore_title => 'Biztonsági mentés visszaállítása';

  @override
  String get setup_existing_subtitle =>
      'Válassza ki, hogyan töltse be meglévő Submersion-könyvtárát';

  @override
  String get setup_existing_sync_subtitle =>
      'Könyvtár letöltése iCloudból, Dropboxból vagy S3-ból';

  @override
  String get setup_existing_sync_title => 'Felhőszinkronizálás csatlakoztatása';

  @override
  String get setup_existing_title => 'Adatok áthozása';

  @override
  String get setup_finish_applying => 'Beállítás...';

  @override
  String setup_finish_error(Object error) {
    return 'A beállítás nem fejeződött be: $error';
  }

  @override
  String get setup_finish_feature_diveComputer =>
      'Merülések letöltése a búvárkomputerről';

  @override
  String get setup_finish_feature_gear =>
      'Felszerelés és szervizintervallumok nyomon követése';

  @override
  String get setup_finish_feature_import =>
      'Naplók importálása fájlokból és más alkalmazásokból';

  @override
  String get setup_finish_feature_sites =>
      'Merülőhelyek megjelenítése térképen';

  @override
  String get setup_finish_feature_statistics =>
      'Merülési statisztikák felfedezése';

  @override
  String get setup_finish_start => 'Kezdés';

  @override
  String get setup_finish_subtitle => 'A Submersion ezenkívül...';

  @override
  String get setup_finish_title => 'Minden készen áll';

  @override
  String get setup_folder_notFound_message =>
      'A kiválasztott mappa nem tartalmaz Submersion-adatbázist.';

  @override
  String get setup_folder_notFound_title => 'Nincs könyvtár ebben a mappában';

  @override
  String get setup_folder_pick => 'Mappa kiválasztása';

  @override
  String get setup_folder_switching => 'Könyvtár megnyitása...';

  @override
  String get setup_folder_title => 'Meglévő mappa megnyitása';

  @override
  String get setup_profile_nameHint => 'Add meg a neved';

  @override
  String get setup_profile_nameLabel => 'Neved';

  @override
  String get setup_profile_nameValidation => 'Add meg a neved';

  @override
  String get setup_profile_subtitle =>
      'Add meg a neved a kezdéshez. Később további részleteket adhatsz hozzá.';

  @override
  String get setup_profile_title => 'Profil létrehozása';

  @override
  String get setup_restore_inProgress => 'Visszaállítás...';

  @override
  String get setup_restore_pick => 'Biztonságimentés-fájl kiválasztása';

  @override
  String get setup_restore_title => 'Biztonsági mentés visszaállítása';

  @override
  String get setup_step_backup => 'Mentés';

  @override
  String get setup_step_finish => 'Kész';

  @override
  String get setup_step_profile => 'Profil';

  @override
  String get setup_step_units => 'Egységek';

  @override
  String get setup_syncPull_continue => 'Folytatás';

  @override
  String get setup_syncPull_incomplete_message =>
      'Ezen a fiókon egy Submersion-könyvtár található, amelynek feltöltése soha nem fejeződött be. Hagyja, hogy a másik eszköz befejezze a szinkronizálást, majd próbálja újra.';

  @override
  String get setup_syncPull_incomplete_retry => 'Ellenőrzés újra';

  @override
  String get setup_syncPull_incomplete_title =>
      'A könyvtár feltöltése befejezetlen';

  @override
  String get setup_syncPull_locked_message =>
      'Adja meg a titkosítási jelmondatot a könyvtár feloldásához és az eszközre töltéséhez.';

  @override
  String get setup_syncPull_locked_title => 'Ez a könyvtár titkosítva van';

  @override
  String get setup_syncPull_noLibrary_message =>
      'Ezen a fiókon nem található Submersion-könyvtár. Új kezdés? A kapcsolat megmarad.';

  @override
  String get setup_syncPull_noLibrary_title => 'Nem található könyvtár';

  @override
  String get setup_syncPull_success => 'Könyvtár átvéve';

  @override
  String get setup_syncPull_syncing => 'Könyvtár letöltése...';

  @override
  String get setup_syncPull_title => 'Csatlakozás és letöltés';

  @override
  String get setup_sync_changeProvider => 'Szolgáltató módosítása';

  @override
  String setup_sync_connectedTo(String provider) {
    return 'Csatlakoztatva: $provider';
  }

  @override
  String setup_sync_error(Object error) {
    return 'Nem sikerült csatlakozni: $error';
  }

  @override
  String get setup_sync_header => 'Felhőszinkronizálás';

  @override
  String get setup_sync_libraryFound_adopt => 'Meglévő könyvtár átvétele';

  @override
  String get setup_sync_libraryFound_keepFresh => 'Új kezdés';

  @override
  String get setup_sync_libraryFound_message =>
      'Ez a fiók már tartalmaz Submersion-könyvtárat. Átveszi ahelyett, hogy újat kezdene?';

  @override
  String get setup_sync_libraryFound_title => 'Meglévő könyvtár található';

  @override
  String get setup_sync_manageInSettings => 'Kezelés a beállításokban';

  @override
  String get setup_sync_notConnected => 'Nincs csatlakoztatva';

  @override
  String get setup_sync_subtitle => 'Adatok szinkronizálása az eszközök között';

  @override
  String get setup_units_advanced => 'Egységek finomhangolása';

  @override
  String get setup_units_altitude => 'Magasság';

  @override
  String get setup_units_dateFormat => 'Dátumformátum';

  @override
  String get setup_units_depth => 'Mélység';

  @override
  String get setup_units_imperial => 'Angolszász';

  @override
  String get setup_units_metric => 'Metrikus';

  @override
  String get setup_units_pressure => 'Nyomás';

  @override
  String get setup_units_sac => 'SAC-érték';

  @override
  String get setup_units_subtitle =>
      'Válassza ki a mértékegységek megjelenítését. Minden egység külön beállítható.';

  @override
  String get setup_units_temperature => 'Hőmérséklet';

  @override
  String get setup_units_timeFormat => 'Időformátum';

  @override
  String get setup_units_title => 'Egységek';

  @override
  String get setup_units_volume => 'Térfogat';

  @override
  String get setup_units_weight => 'Súly';

  @override
  String get setup_welcome_existingData_subtitle =>
      'Biztonsági mentés visszaállítása, felhőszinkronizálás vagy meglévő mappa megnyitása';

  @override
  String get setup_welcome_existingData_title =>
      'Már vannak Submersion-adataim';

  @override
  String get setup_welcome_skipSetup => 'Beállítás kihagyása';

  @override
  String get setup_welcome_startFresh_subtitle =>
      'Búvárprofil létrehozása és az alkalmazás beállítása';

  @override
  String get setup_welcome_startFresh_title => 'Új profil beállítása';

  @override
  String get setup_welcome_subtitle => 'Fejlett merülés napló és elemzés';

  @override
  String get setup_welcome_title => 'Üdvözöl a Submersion';

  @override
  String get siteMatchReview_title => 'Helyek hozzárendelése';

  @override
  String siteMatchReview_diveNumber(Object number) {
    return '#$number. merules';
  }

  @override
  String get siteMatchReview_empty => 'Nincs mit hozzárendelni.';

  @override
  String siteMatchReview_summary(int selected, int review, int none) {
    return '$selected kiválasztva · $review ellenőrzendő · $none nincs találat';
  }

  @override
  String siteMatchReview_confirm(int count) {
    return '$count hozzárendelés megerősítése';
  }

  @override
  String get siteMatchReview_cancel => 'Mégse';

  @override
  String get siteMatchReview_tapToChoose => 'Koppints egy hely kiválasztásához';

  @override
  String siteMatchReview_awayMeters(int meters) {
    return '$meters m távolságra';
  }

  @override
  String siteMatchReview_depthTo(int meters) {
    return '$meters m-ig';
  }

  @override
  String siteMatchReview_depthRange(int min, int max) {
    return '$min–$max m';
  }

  @override
  String siteMatchReview_appliedSnack(int dives, int sites) {
    return '$dives merülés összekapcsolva · $sites hely hozzáadva';
  }

  @override
  String get siteMatchReview_applyError =>
      'A hozzárendelések nem alkalmazhatók';

  @override
  String get siteMatchReview_discardTitle => 'Elveted a hozzárendeléseket?';

  @override
  String get siteMatchReview_discardMessage =>
      'A kiválasztásod nem lesz mentve.';

  @override
  String get siteMatchReview_discardConfirm => 'Elvetés';

  @override
  String get siteMatchReview_keepReviewing => 'Ellenőrzés folytatása';

  @override
  String get siteMatchReview_sourceExisting => 'saját hely';

  @override
  String get siteMatchReview_sourceBundled => 'importált';

  @override
  String get siteMatchReview_noNearbySite => 'Nincs közeli hely';

  @override
  String importSummary_matchSitesButton(int count) {
    return '$count merülés hozzárendelése helyekhez';
  }

  @override
  String get diveLog_listPage_searchFieldLabel => 'Merulesek keresese...';

  @override
  String diveLog_listPage_searchLimitNotice(int limit) {
    return 'Az első $limit találat látható. Pontosítsa a keresést az eredmények szűkítéséhez.';
  }

  @override
  String diveLog_listPage_searchNoResults(Object query) {
    return 'Nem talalhato merules: \"$query\"';
  }

  @override
  String get diveLog_listPage_searchSuggestion =>
      'Kereses merulohely, buddy vagy jegyzetek alapjan';

  @override
  String get diveLog_listPage_title => 'Merulesi naplo';

  @override
  String get diveLog_listPage_tooltip_back => 'Vissza';

  @override
  String get diveLog_listPage_tooltip_backToDiveList =>
      'Vissza a merulesek listajahoz';

  @override
  String get diveLog_listPage_tooltip_clearSearch => 'Kereses torlese';

  @override
  String get diveLog_listPage_tooltip_filterDives => 'Merulesek szurese';

  @override
  String get diveLog_listPage_tooltip_listView => 'Lista nezet';

  @override
  String get diveLog_listPage_tooltip_mapView => 'Terkep nezet';

  @override
  String get diveLog_listPage_tooltip_searchDives => 'Merulesek keresese';

  @override
  String get diveLog_listPage_tooltip_sort => 'Rendezes';

  @override
  String get diveLog_listPage_unknownSite => 'Ismeretlen merulohely';

  @override
  String get diveLog_map_emptySubtitle =>
      'Rogzitsen meruleseket helyadatokkal, hogy lasson tevekenyseget a terkepen';

  @override
  String get diveLog_map_emptyTitle =>
      'Nincs megjelenitendo merulesi tevekenyseg';

  @override
  String diveLog_map_errorLoading(Object error) {
    return 'Hiba a merulesi adatok betoltesekor: $error';
  }

  @override
  String get diveLog_map_tooltip_fitAllSites => 'Osszes merulohely mutatasa';

  @override
  String get diveLog_numbering_actions => 'Muveletek';

  @override
  String get diveLog_numbering_allCorrect =>
      'Minden merules helyesen szamozott';

  @override
  String get diveLog_numbering_assignMissing => 'Hianyzo szamok kiosztasa';

  @override
  String get diveLog_numbering_assignMissingDesc =>
      'Szamozatlan merulesek szamozasa az utolso szamozott merules utan';

  @override
  String get diveLog_numbering_close => 'Bezaras';

  @override
  String get diveLog_numbering_gapsDetected => 'Hezagok eszlelve';

  @override
  String get diveLog_numbering_issuesDetected => 'Problemak eszlelve';

  @override
  String diveLog_numbering_missingCount(Object count) {
    return '$count hianyzik';
  }

  @override
  String get diveLog_numbering_renumberAll => 'Osszes merules ujraszamozasa';

  @override
  String get diveLog_numbering_renumberAllDesc =>
      'Sorszamok kiosztasa datum/ido alapjan';

  @override
  String get diveLog_numbering_renumberDialog_cancel => 'Megse';

  @override
  String get diveLog_numbering_renumberDialog_content =>
      'Ez az osszes merulest idorendben ujraszamozza a beszallasi datum/ido alapjan. Ez a muvelet nem vonhato vissza.';

  @override
  String get diveLog_numbering_renumberDialog_renumber => 'Ujraszamozas';

  @override
  String get diveLog_numbering_renumberDialog_startFrom => 'Kezdo szam';

  @override
  String get diveLog_numbering_renumberDialog_title =>
      'Osszes merules ujraszamozasa';

  @override
  String get diveLog_numbering_snackbar_assigned =>
      'Hianyzo merulesi szamok kiosztva';

  @override
  String diveLog_numbering_snackbar_renumbered(Object number) {
    return 'Minden merules ujraszamozva #$number-tol';
  }

  @override
  String diveLog_numbering_summary(Object total, Object numbered) {
    return '$total osszes merules - $numbered szamozott';
  }

  @override
  String get diveLog_numbering_title => 'Merules szamozas';

  @override
  String diveLog_numbering_unnumberedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 szam nelkul';
  }

  @override
  String get diveLog_o2tox_badge_critical => 'KRITIKUS';

  @override
  String get diveLog_o2tox_badge_warning => 'FIGYELMEZTETÉS';

  @override
  String diveLog_o2tox_cnsBadgeLabel(Object value) {
    return 'CNS $value';
  }

  @override
  String get diveLog_o2tox_cnsOxygenClock => 'CNS oxigen ora';

  @override
  String diveLog_o2tox_deltaDive(Object value) {
    return '+$value% ezen a merulesen';
  }

  @override
  String get diveLog_o2tox_details => 'Reszletek';

  @override
  String get diveLog_o2tox_label_maxPpO2 => 'Max ppO2';

  @override
  String get diveLog_o2tox_label_maxPpO2Depth => 'Max ppO2 melyseg';

  @override
  String get diveLog_o2tox_label_timeAbove14 => '1,4 bar feletti ido';

  @override
  String get diveLog_o2tox_label_timeAbove16 => '1,6 bar feletti ido';

  @override
  String get diveLog_o2tox_ofDailyLimit => 'a napi limitbol';

  @override
  String get diveLog_o2tox_oxygenToleranceUnits => 'Oxigen tolerancia egysegek';

  @override
  String diveLog_o2tox_semantics_cnsBadge(Object value) {
    return 'CNS oxigén toxicitás $value';
  }

  @override
  String get diveLog_o2tox_semantics_criticalWarning =>
      'Kritikus oxigen toxicitas figyelmeztetés';

  @override
  String diveLog_o2tox_semantics_otu(Object value, Object percent) {
    return 'Oxigén tolerancia egységek: $value, $percent százalék a napi limitből';
  }

  @override
  String get diveLog_o2tox_semantics_warning =>
      'Oxigen toxicitas figyelmeztetés';

  @override
  String diveLog_o2tox_startPercent(Object value) {
    return 'Kezdet: $value%';
  }

  @override
  String get diveLog_o2tox_title => 'Oxigen toxicitas';

  @override
  String get diveLog_playbackStats_deco => 'DEKO';

  @override
  String get diveLog_playbackStats_depth => 'Melyseg';

  @override
  String get diveLog_playbackStats_header => 'Elo statisztikak';

  @override
  String get diveLog_playbackStats_heartRate => 'Pulzus';

  @override
  String get diveLog_playbackStats_ndl => 'NDL';

  @override
  String get diveLog_playbackStats_ppO2 => 'ppO₂';

  @override
  String get diveLog_playbackStats_pressure => 'Nyomas';

  @override
  String get diveLog_playbackStats_temp => 'Hom.';

  @override
  String get diveLog_playback_sliderLabel => 'Lejatszasi pozicio';

  @override
  String diveLog_playback_speed_label(Object speed) {
    return '${speed}x';
  }

  @override
  String get diveLog_playback_stepThrough => 'Leptetett lejatszas';

  @override
  String get diveLog_playback_tooltip_back10 => 'Vissza 10 masodpercet';

  @override
  String get diveLog_playback_tooltip_exit => 'Kilépés a lejatszas modbol';

  @override
  String get diveLog_playback_tooltip_forward10 => 'Elore 10 masodpercet';

  @override
  String get diveLog_playback_tooltip_pause => 'Szunet';

  @override
  String get diveLog_playback_tooltip_play => 'Lejatszas';

  @override
  String get diveLog_playback_tooltip_skipEnd => 'Ugras a vegere';

  @override
  String get diveLog_playback_tooltip_skipStart => 'Ugras az elejere';

  @override
  String get diveLog_playback_tooltip_speed => 'Lejatszasi sebesseg';

  @override
  String diveLog_profile_axisDepth(Object unit) {
    return 'Melyseg ($unit)';
  }

  @override
  String get diveLog_profile_axisTime => 'Ido (min)';

  @override
  String get diveLog_profile_emptyState => 'Nincs merulesi profil adat';

  @override
  String get diveLog_profile_rightAxis_none => 'Nincs';

  @override
  String get diveLog_profile_semantics_changeRightAxis =>
      'Jobb tengely metrika valtoztatasa';

  @override
  String get diveLog_profile_semantics_chart =>
      'Merulesi profil diagram, csipje ossze a nagyitashoz';

  @override
  String get diveLog_profile_semantics_photoMarker => 'Fotójelölő';

  @override
  String get diveLog_profile_tooltip_moreOptions =>
      'Tovabbi diagram lehetosegek';

  @override
  String get diveLog_profile_tooltip_resetZoom => 'Nagyitas visszaallitasa';

  @override
  String get diveLog_profile_tooltip_zoomIn => 'Nagyitas';

  @override
  String get diveLog_profile_tooltip_zoomOut => 'Kicsinyites';

  @override
  String diveLog_profile_zoomHint(Object level) {
    return 'Nagyitas: ${level}x - Csipje ossze vagy gorgetjen a nagyitashoz, huzza a panoramazashoz';
  }

  @override
  String get diveLog_rangeSelection_exitRange => 'Tartomany bezarasa';

  @override
  String get diveLog_rangeSelection_selectRange => 'Tartomany kivalasztasa';

  @override
  String get diveLog_rangeSelection_semantics_adjust =>
      'Tartomany kivalasztas modositasa';

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
  String get diveLog_rangeStats_title => 'Tartomany stat.';

  @override
  String get diveLog_rangeStats_tooltip_close => 'Tartomany elemzes bezarasa';

  @override
  String diveLog_scr_calculatedLoopFo2(Object value) {
    return 'Szamitott hurok FO₂: $value%';
  }

  @override
  String get diveLog_scr_hint_additionRatio => 'pl. 0,33 (1:3)';

  @override
  String get diveLog_scr_label_additionRatio => 'Adagolasi arany';

  @override
  String get diveLog_scr_label_assumedVo2 => 'Feltételezett VO₂';

  @override
  String get diveLog_scr_label_avg => 'Atlag';

  @override
  String get diveLog_scr_label_injectionRate => 'Adagolasi sebesseg';

  @override
  String get diveLog_scr_label_max => 'Max';

  @override
  String get diveLog_scr_label_min => 'Min';

  @override
  String get diveLog_scr_label_orificeSize => 'Fuvoka meret';

  @override
  String get diveLog_scr_sectionCmf => 'CMF parameterek';

  @override
  String get diveLog_scr_sectionEscr => 'ESCR parameterek';

  @override
  String get diveLog_scr_sectionMeasuredLoopO2 => 'Mert hurok O₂ (opcionalis)';

  @override
  String get diveLog_scr_sectionPascr => 'PASCR parameterek';

  @override
  String get diveLog_scr_sectionScrType => 'SCR tipus';

  @override
  String get diveLog_scr_sectionSupplyGas => 'Ellato gaz';

  @override
  String get diveLog_scr_title => 'SCR beallitasok';

  @override
  String get diveLog_search_allCenters => 'Osszes kozpont';

  @override
  String get diveLog_search_allTrips => 'Osszes utazas';

  @override
  String get diveLog_search_appBar => 'Reszletes kereses';

  @override
  String get diveLog_search_cancel => 'Megse';

  @override
  String get diveLog_search_clearAll => 'Osszes torlese';

  @override
  String get diveLog_search_customFieldKey => 'Custom Field Key';

  @override
  String get diveLog_search_customFieldValue => 'Value contains...';

  @override
  String get diveLog_search_end => 'Vege';

  @override
  String get diveLog_search_errorLoadingCenters =>
      'Hiba a merulokozpontok betoltesekor';

  @override
  String get diveLog_search_errorLoadingDiveTypes =>
      'Hiba a merülés típusok betöltésekor';

  @override
  String get diveLog_search_errorLoadingTrips =>
      'Hiba az utazasok betoltesekor';

  @override
  String get diveLog_search_filter_any => 'Bármely';

  @override
  String get diveLog_search_gasTrimix => 'Trimix (<21% O₂)';

  @override
  String get diveLog_search_label_deco => 'Dekompresszio';

  @override
  String get diveLog_search_label_depthRange => 'Melyseg tartomany (m)';

  @override
  String get diveLog_search_label_diveCenter => 'Merulokozpont';

  @override
  String get diveLog_search_label_diveSite => 'Merulohely';

  @override
  String get diveLog_search_label_diveType => 'Merules tipus';

  @override
  String get diveLog_search_label_durationRange => 'Idotartam tartomany (min)';

  @override
  String get diveLog_search_label_trip => 'Utazas';

  @override
  String get diveLog_search_search => 'Kereses';

  @override
  String get diveLog_search_section_conditions => 'Korulmenyek';

  @override
  String get diveLog_search_section_dateRange => 'Datumtartomany';

  @override
  String get diveLog_search_section_gasEquipment => 'Gaz es felszereles';

  @override
  String get diveLog_search_section_location => 'Helyszin';

  @override
  String get diveLog_search_section_organization => 'Szervezet';

  @override
  String get diveLog_search_section_social => 'Kozossegi';

  @override
  String get diveLog_search_start => 'Kezdes';

  @override
  String diveLog_selection_countSelected(Object count) {
    return '$count kivalasztva';
  }

  @override
  String get diveLog_selection_tooltip_combine => 'Összevonás';

  @override
  String get diveLog_selection_tooltip_delete => 'Kivalasztottak torlese';

  @override
  String get diveLog_selection_tooltip_deselectAll =>
      'Osszes kivalasztas megszuntetese';

  @override
  String get diveLog_selection_tooltip_edit => 'Kivalasztottak szerkesztese';

  @override
  String get diveLog_selection_tooltip_exit => 'Kivalasztas bezarasa';

  @override
  String get diveLog_selection_tooltip_export => 'Kivalasztottak exportalasa';

  @override
  String get diveLog_selection_tooltip_selectAll => 'Osszes kivalasztasa';

  @override
  String get diveLog_selection_tooltip_selectDateRange =>
      'Kijelölés dátumtartomány szerint';

  @override
  String get diveLog_sighting_add => 'Hozzaadas';

  @override
  String get diveLog_sighting_cancel => 'Megse';

  @override
  String get diveLog_sighting_notesHint => 'pl. meret, viselkedes, helyszin...';

  @override
  String get diveLog_sighting_notesOptional => 'Megjegyzesek (opcionalis)';

  @override
  String get diveLog_sitePicker_addDiveSite => 'Merulohely hozzaadasa';

  @override
  String diveLog_sitePicker_distanceKm(Object distance) {
    return '$distance km tavolsagra';
  }

  @override
  String diveLog_sitePicker_distanceAway(String distance) {
    return '$distance távolságra';
  }

  @override
  String get diveLog_sitePicker_sortedByDiveDistance =>
      'Távolság szerint rendezve ettől a merüléstől';

  @override
  String diveLog_sitePicker_distanceMeters(Object distance) {
    return '$distance m tavolsagra';
  }

  @override
  String diveLog_sitePicker_errorLoading(Object error) {
    return 'Hiba a helyszinek betoltesekor: $error';
  }

  @override
  String get diveLog_sitePicker_newDiveSite => 'Uj merulohely';

  @override
  String get diveLog_sitePicker_noSites => 'Meg nincsenek merulohelyek';

  @override
  String get diveLog_sitePicker_sortedByDistance => 'Tavolsag szerint rendezve';

  @override
  String get diveLog_sitePicker_title => 'Merulohely kivalasztasa';

  @override
  String get diveLog_sort_title => 'Merulesek rendezese';

  @override
  String diveLog_speciesPicker_addNew(Object name) {
    return '\"$name\" hozzaadasa uj fajkent';
  }

  @override
  String get diveLog_speciesPicker_noResults => 'Nem talalhato faj';

  @override
  String get diveLog_speciesPicker_noSpecies => 'Nincsenek elerheto fajok';

  @override
  String get diveLog_speciesPicker_searchHint => 'Fajok keresese...';

  @override
  String get diveLog_speciesPicker_title => 'Tengeri elet hozzaadasa';

  @override
  String get diveLog_speciesPicker_tooltip_clearSearch => 'Kereses torlese';

  @override
  String get diveLog_summary_action_importComputer =>
      'Importalas szamitogeproL';

  @override
  String get diveLog_summary_action_logDive => 'Merules rogzitese';

  @override
  String get diveLog_summary_action_viewStats => 'Statisztikak megtekintese';

  @override
  String diveLog_summary_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0';
  }

  @override
  String get diveLog_summary_overview => 'Attekintes';

  @override
  String get diveLog_summary_record_coldest => 'Leghidegebb merules';

  @override
  String get diveLog_summary_record_deepest => 'Legmelyebb merules';

  @override
  String get diveLog_summary_record_longest => 'Leghosszabb merules';

  @override
  String get diveLog_summary_record_warmest => 'Legmelegebb merules';

  @override
  String get diveLog_summary_section_mostVisited =>
      'Leglátogatottabb helyszinek';

  @override
  String get diveLog_summary_section_quickActions => 'Gyorsmuveletek';

  @override
  String get diveLog_summary_section_records => 'Szemelyes rekordok';

  @override
  String get diveLog_summary_selectDive =>
      'Valasszon egy merulest a listabol a reszletek megtekIntesehez';

  @override
  String get diveLog_summary_stat_avgMaxDepth => 'Atl. max melyseg';

  @override
  String get diveLog_summary_stat_avgWaterTemp => 'Atl. vizhomerseklet';

  @override
  String get diveLog_summary_stat_diveSites => 'Merulohelyek';

  @override
  String get diveLog_summary_stat_diveTime => 'Merulesido';

  @override
  String get diveLog_summary_stat_maxDepth => 'Max melyseg';

  @override
  String get diveLog_summary_stat_totalDives => 'Osszes merules';

  @override
  String get diveLog_summary_title => 'Merulesnaplo osszefoglalo';

  @override
  String get diveLog_tank_label_endPressure => 'Vegnyomas';

  @override
  String get diveLog_tank_label_he => 'He';

  @override
  String get diveLog_tank_label_material => 'Anyag';

  @override
  String get diveLog_tank_label_n2 => 'N2';

  @override
  String get diveLog_tank_label_o2 => 'O2';

  @override
  String get diveLog_tank_label_role => 'Szerep';

  @override
  String get diveLog_tank_label_startPressure => 'Kezdonyomas';

  @override
  String get diveLog_tank_label_tankPreset => 'Palack elore beallitas';

  @override
  String get diveLog_tank_label_volume => 'Terfogat';

  @override
  String get diveLog_tank_label_workingPressure => 'Uzemi ny.';

  @override
  String get diveLog_tank_mndHelper =>
      'Állítsa automatikusra a He% kiszámításához';

  @override
  String diveLog_tank_modInfo(Object depth) {
    return 'MOD: $depth (ppO₂ 1.4)';
  }

  @override
  String diveLog_tank_modMndInfo(Object mod, Object mnd) {
    return 'MOD: $mod (ppO₂ 1.4) | MND: $mnd';
  }

  @override
  String get diveLog_tank_section_gasMix => 'Gazkeverek';

  @override
  String get diveLog_tank_selectPreset => 'Valasszon elore beallitast...';

  @override
  String get diveLog_tank_saveAsPreset => 'Mentés előre beállításként';

  @override
  String get diveLog_tank_saveAsPreset_needSpecs =>
      'Először adjon meg térfogatot és üzemi nyomást';

  @override
  String get diveLog_tank_saveAsPreset_nameTitle =>
      'Palack előre beállítás mentése';

  @override
  String get diveLog_tank_saveAsPreset_nameHint => 'pl. Az én AL80-am';

  @override
  String diveLog_tank_saveAsPreset_saved(String name) {
    return '\"$name\" előre beállítás mentve';
  }

  @override
  String diveLog_tank_title(Object number) {
    return '$number. palack';
  }

  @override
  String get diveLog_tank_tooltip_remove => 'Palack eltavolitasa';

  @override
  String get diveLog_tissue_label_ceiling => 'Plafon';

  @override
  String get diveLog_tissue_label_gf => 'GF';

  @override
  String get diveLog_tissue_label_ndl => 'NDL';

  @override
  String get diveLog_tissue_label_tts => 'TTS';

  @override
  String get diveLog_tissue_legend_he => 'He';

  @override
  String get diveLog_tissue_legend_mValue => '100% M-ertek';

  @override
  String get diveLog_tissue_legend_n2 => 'N₂';

  @override
  String get diveLog_tissue_title => 'Szovettelitodes';

  @override
  String get diveLog_tooltip_avgCalculated => '(átl., számított)';

  @override
  String get diveLog_tooltip_ceiling => 'Plafon';

  @override
  String get diveLog_tooltip_decoStop => 'Deco stop';

  @override
  String get diveLog_tooltip_cns => 'CNS';

  @override
  String get diveLog_tooltip_density => 'Suruseg';

  @override
  String get diveLog_tooltip_depth => 'Melyseg';

  @override
  String get diveLog_tooltip_gfPercent => 'GF%';

  @override
  String get diveLog_tooltip_hr => 'Pulzus';

  @override
  String get diveLog_tooltip_marker => 'Jelolo';

  @override
  String get diveLog_tooltip_mean => 'Atlag';

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
  String get diveLog_tooltip_press => 'Nyomas';

  @override
  String get diveLog_tooltip_rate => 'Sebessg';

  @override
  String get diveLog_tooltip_sac => 'SAC';

  @override
  String get diveLog_tooltip_sensor => 'Érzékelő';

  @override
  String get diveLog_legend_label_o2Cells => 'O2 cellák';

  @override
  String get diveLog_tooltip_o2CellsTight => 'szoros';

  @override
  String get diveLog_tooltip_o2CellsDrifting => 'elsodródó';

  @override
  String get diveLog_tooltip_o2CellsWide => 'széles';

  @override
  String get diveLog_tooltip_srfGf => 'SrfGF';

  @override
  String get diveLog_tooltip_temp => 'Hom.';

  @override
  String get diveLog_tooltip_time => 'Ido';

  @override
  String get diveLog_tooltip_tts => 'TTS';

  @override
  String get diveLog_sources_row_metric => 'Adat';

  @override
  String get diveLog_sources_row_maxDepth => 'Max mélység';

  @override
  String get diveLog_sources_row_avgDepth => 'Átl. mélység';

  @override
  String get diveLog_sources_row_duration => 'Időtartam';

  @override
  String get diveLog_sources_row_waterTemp => 'Víz hőm.';

  @override
  String get diveLog_sources_row_cns => 'CNS';

  @override
  String get diveLog_sources_row_otu => 'OTU';

  @override
  String get diveLog_sources_row_decoAlgorithm => 'Dekó algoritmus';

  @override
  String get diveLog_sources_row_gf => 'GF';

  @override
  String diveLog_sources_minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perc',
      one: '1 perc',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_unknownComputer => 'Ismeretlen számítógép';

  @override
  String get diveLog_sources_manualEntry => 'Kézi bejegyzés';

  @override
  String get diveLog_sources_importedFile => 'Importált fájl';

  @override
  String get diveLog_sources_editedSuffix => ' (szerkesztett)';

  @override
  String get diveLog_sources_barLabel => 'FORRÁSOK';

  @override
  String get diveLog_sources_menu_setPrimary => 'Beállítás elsődlegesként';

  @override
  String get diveLog_sources_menu_split => 'Szétválasztás külön merülésbe';

  @override
  String get diveLog_sources_overlayTooltip => 'Rávetítés a grafikonra';

  @override
  String get diveLog_sources_splitDialog_title =>
      'Szétválasztás külön merülésbe?';

  @override
  String get diveLog_sources_splitDialog_body =>
      'A forrás profilja, eseményei és palackjai új merülésbe kerülnek. A naplóbejegyzés ennél a merülésnél marad.';

  @override
  String get diveLog_sources_splitDialog_confirm => 'Szétválasztás';

  @override
  String get diveLog_sources_splitDone => 'Merülés szétválasztva';

  @override
  String get diveLog_sources_splitFailed => 'A szétválasztás sikertelen';

  @override
  String get divePlanner_action_addTank => 'Palack hozzáadása';

  @override
  String get divePlanner_action_convertToDive => 'Átalakítás merüléssé';

  @override
  String get divePlanner_action_deletePlan => 'Terv törlése';

  @override
  String get divePlanner_action_editTank => 'Palack szerkesztése';

  @override
  String get divePlanner_action_moreOptions => 'További lehetőségek';

  @override
  String get divePlanner_action_quickPlan => 'Gyors tervezés';

  @override
  String get divePlanner_action_renamePlan => 'Terv átnevezése';

  @override
  String get divePlanner_action_reset => 'Visszaállítás';

  @override
  String get divePlanner_action_resetPlan => 'Terv visszaállítása';

  @override
  String get divePlanner_action_savePlan => 'Terv mentése';

  @override
  String get divePlanner_error_cannotConvert =>
      'Nem lehet átalakítani: a tervnek kritikus figyelmeztetései vannak';

  @override
  String get divePlanner_error_reserveExceedsTank =>
      'Meghaladja a palack nyomását';

  @override
  String get divePlanner_error_reserveMustBePositive =>
      'Nullánál nagyobbnak kell lennie';

  @override
  String divePlanner_info_reserveDefault(Object unit, Object value) {
    return 'Nincs megadva — alapértelmezett $value $unit';
  }

  @override
  String get divePlanner_field_hePercent => 'He %';

  @override
  String get divePlanner_field_name => 'Név';

  @override
  String get divePlanner_field_o2Percent => 'O₂ %';

  @override
  String get divePlanner_field_planName => 'Terv neve';

  @override
  String get divePlanner_field_role => 'Szerep';

  @override
  String divePlanner_field_startPressure(Object pressureSymbol) {
    return 'Kezdő ($pressureSymbol)';
  }

  @override
  String get divePlanner_field_travelGas => 'Utazógázként is használva';

  @override
  String divePlanner_field_volume(Object volumeSymbol) {
    return 'Térfogat ($volumeSymbol)';
  }

  @override
  String get divePlanner_hint_tankName => 'Add meg a palack nevét';

  @override
  String get divePlanner_label_altitude => 'Magasság:';

  @override
  String get divePlanner_label_belowMinReserve => 'Minimum tartalék alatt';

  @override
  String get divePlanner_label_ceiling => 'Plafon';

  @override
  String get divePlanner_label_consumption => 'Fogyasztás';

  @override
  String get divePlanner_label_deco => 'DEKO';

  @override
  String get divePlanner_label_decoSchedule => 'Dekompressziós menetrend';

  @override
  String get divePlanner_label_decompression => 'Dekompresszió';

  @override
  String divePlanner_label_depthAxis(Object depthSymbol) {
    return 'Mélység ($depthSymbol)';
  }

  @override
  String get divePlanner_label_diveProfile => 'Merülési profil';

  @override
  String get divePlanner_label_empty => 'ÜRES';

  @override
  String get divePlanner_label_gasConsumption => 'Gázfogyasztás';

  @override
  String get divePlanner_label_gfHigh => 'GF magas';

  @override
  String get divePlanner_label_gfLow => 'GF alacsony';

  @override
  String get divePlanner_label_max => 'Max';

  @override
  String get divePlanner_label_ndl => 'NDL';

  @override
  String get divePlanner_label_planSettings => 'Terv beállításai';

  @override
  String get divePlanner_label_remaining => 'Maradt';

  @override
  String get divePlanner_label_reserve => 'Tartalék:';

  @override
  String get divePlanner_label_runtime => 'Futási idő';

  @override
  String get divePlanner_label_sacRate => 'RMV:';

  @override
  String get divePlanner_label_status => 'Státusz';

  @override
  String get divePlanner_label_tanks => 'Palackok';

  @override
  String get divePlanner_label_time => 'Idő';

  @override
  String get divePlanner_label_timeAxis => 'Idő (perc)';

  @override
  String get divePlanner_label_tts => 'TTS';

  @override
  String get divePlanner_label_used => 'Felhasznált';

  @override
  String get divePlanner_label_warnings => 'Figyelmeztetések';

  @override
  String get divePlanner_legend_ascent => 'Feljövés';

  @override
  String get divePlanner_legend_bottom => 'Fenék';

  @override
  String get divePlanner_legend_deco => 'Dekó';

  @override
  String get divePlanner_legend_descent => 'Leereszkedés';

  @override
  String get divePlanner_legend_safety => 'Biztonsági';

  @override
  String get divePlanner_message_addSegmentsForGas =>
      'Adj hozzá szakaszokat a gázvetítések megtekintéséhez';

  @override
  String get divePlanner_message_addSegmentsForProfile =>
      'Adj hozzá szakaszokat a merülési profil megtekintéséhez';

  @override
  String get divePlanner_message_convertingPlan =>
      'Terv átalakítása merüléssé...';

  @override
  String get divePlanner_message_noProfile => 'Nincs megjeleníthető profil';

  @override
  String divePlanner_message_deleteConfirmation(String name) {
    return 'Törli a(z) \'$name\' tervet?';
  }

  @override
  String get divePlanner_message_planDeleted => 'Terv törölve';

  @override
  String get divePlanner_message_planSaved => 'Terv mentve';

  @override
  String get divePlanner_message_resetConfirmation =>
      'Biztosan vissza szeretnéd állítani a tervet?';

  @override
  String divePlanner_semantics_criticalWarning(Object message) {
    return 'Kritikus figyelmeztetés: $message';
  }

  @override
  String divePlanner_semantics_decoStop(
    Object depth,
    Object duration,
    Object gasMix,
  ) {
    return 'Dekó megálló $depth mélységben $duration időtartamra $gasMix keverékkel';
  }

  @override
  String divePlanner_semantics_gasConsumption(
    Object tankName,
    Object gasUsed,
    Object remaining,
    Object percent,
    Object warning,
  ) {
    return '$tankName: $gasUsed felhasznált, $remaining maradt, $percent használva$warning';
  }

  @override
  String divePlanner_semantics_profileChart(
    Object maxDepth,
    Object totalMinutes,
  ) {
    return 'Merülési terv, max mélység $maxDepth, összes idő $totalMinutes perc';
  }

  @override
  String divePlanner_semantics_warning(Object message) {
    return 'Figyelmeztetés: $message';
  }

  @override
  String get divePlanner_tab_plan => 'Terv';

  @override
  String get divePlanner_tab_profile => 'Profil';

  @override
  String get divePlanner_tab_results => 'Eredmények';

  @override
  String get divePlanner_warning_ascentRateHigh =>
      'Feljövési sebesség meghaladja a biztonságos limitet';

  @override
  String divePlanner_warning_ascentRateHighWithRate(Object rate) {
    return 'Feljövési sebesség $rate/perc meghaladja a biztonságos limitet';
  }

  @override
  String divePlanner_warning_belowMinReserve(Object reserve) {
    return 'Minimum tartalék alatt ($reserve)';
  }

  @override
  String get divePlanner_warning_cnsCritical => 'CNS% meghaladja a 100%-ot';

  @override
  String divePlanner_warning_cnsWarning(Object threshold) {
    return 'CNS% meghaladja a $threshold%-ot';
  }

  @override
  String get divePlanner_warning_endHigh =>
      'Ekvivalens narkotikus mélység túl magas';

  @override
  String divePlanner_warning_endHighWithDepth(Object depth) {
    return 'END $depth meghaladja a biztonságos limitet';
  }

  @override
  String divePlanner_warning_gasLow(Object threshold) {
    return 'Palack $threshold tartalék alatt';
  }

  @override
  String get divePlanner_warning_gasOut => 'Palack ki fog ürülni';

  @override
  String get divePlanner_warning_minGasViolation =>
      'Minimum gáz tartalék nem tartható fenn';

  @override
  String get divePlanner_warning_modViolation =>
      'Gázváltás kísérlet MOD felett';

  @override
  String get divePlanner_warning_ndlExceeded =>
      'Merülés dekompressziós kötelezettséggel jár';

  @override
  String get divePlanner_warning_otuWarning => 'OTU felhalmozódás magas';

  @override
  String divePlanner_warning_ppO2Critical(Object value) {
    return 'ppO₂ $value bar meghaladja a kritikus limitet';
  }

  @override
  String divePlanner_warning_ppO2High(Object value) {
    return 'ppO₂ $value bar meghaladja a munkálati limitet';
  }

  @override
  String get diveSites_detail_access_accessNotes =>
      'Megkozelitesi megjegyzesek';

  @override
  String get diveSites_detail_access_mooring => 'Kikotos';

  @override
  String get diveSites_detail_access_parking => 'Parkolas';

  @override
  String get diveSites_detail_altitude_elevation =>
      'Tengerszint feletti magassag';

  @override
  String get diveSites_detail_altitude_pressure => 'Nyomas';

  @override
  String get diveSites_detail_coordinatesCopied =>
      'Koordinatak masolva a vagolapra';

  @override
  String get diveSites_detail_deleteDialog_cancel => 'Megse';

  @override
  String get diveSites_detail_deleteDialog_confirm => 'Torles';

  @override
  String get diveSites_detail_deleteDialog_content =>
      'Biztosan torli ezt a helyszint? Ez a muvelet nem vonhato vissza.';

  @override
  String get diveSites_detail_deleteDialog_title => 'Helyszin torlese';

  @override
  String get diveSites_detail_deleteMenu_label => 'Torles';

  @override
  String get diveSites_detail_deleteSnackbar => 'Helyszin torolve';

  @override
  String get diveSites_detail_depth_maximum => 'Maximum';

  @override
  String get diveSites_detail_depth_minimum => 'Minimum';

  @override
  String get diveSites_detail_diveCount_one => '1 rogzitett merules';

  @override
  String diveSites_detail_diveCount_other(Object count) {
    return '$count rogzitett merules';
  }

  @override
  String get diveSites_detail_diveCount_zero => 'Meg nincs rogzitett merules';

  @override
  String get diveSites_detail_editTooltip => 'Helyszin szerkesztese';

  @override
  String get diveSites_detail_editTooltipShort => 'Szerkesztes';

  @override
  String diveSites_detail_error_body(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get diveSites_detail_error_title => 'Hiba';

  @override
  String get diveSites_detail_loading_title => 'Betoltes...';

  @override
  String get diveSites_detail_location_country => 'Orszag';

  @override
  String get diveSites_detail_location_city => 'Város';

  @override
  String get diveSites_detail_location_island => 'Sziget';

  @override
  String get diveSites_detail_location_bodyOfWater => 'Víztest';

  @override
  String get diveSites_detail_location_gpsCoordinates => 'GPS koordinatak';

  @override
  String get diveSites_detail_location_notSet => 'Nincs megadva';

  @override
  String get diveSites_detail_location_region => 'Regio';

  @override
  String get diveSites_detail_noDepthInfo => 'Nincs melyseg informacio';

  @override
  String get diveSites_detail_noDescription => 'Nincs leiras';

  @override
  String get diveSites_detail_noNotes => 'Nincsenek megjegyzesek';

  @override
  String get diveSites_detail_rating_notRated => 'Nincs ertekelesve';

  @override
  String diveSites_detail_rating_value(Object rating) {
    return '$rating az 5-bol';
  }

  @override
  String get diveSites_detail_section_access => 'Megkozelites es logisztika';

  @override
  String get diveSites_detail_section_altitude =>
      'Tengerszint feletti magassag';

  @override
  String get diveSites_detail_section_depthRange => 'Melyseg tartomany';

  @override
  String get diveSites_detail_section_description => 'Leiras';

  @override
  String get diveSites_detail_section_difficultyLevel => 'Nehezssgi szint';

  @override
  String get diveSites_detail_section_divesAtSite =>
      'Merulesek ezen a helyszinen';

  @override
  String get diveSites_detail_section_hazards => 'Veszelyek es biztonsag';

  @override
  String get diveSites_detail_section_location => 'Helyszin';

  @override
  String get diveSites_detail_section_notes => 'Megjegyzesek';

  @override
  String get diveSites_detail_section_rating => 'Ertekeles';

  @override
  String diveSites_detail_semantics_copyToClipboard(Object label) {
    return '$label masolasa a vagolapra';
  }

  @override
  String get diveSites_detail_semantics_viewDivesAtSite =>
      'Merulesek megtekintese ezen a helyszinen';

  @override
  String get diveSites_detail_semantics_viewFullscreenMap =>
      'Teljes kepernyon terkep megtekintese';

  @override
  String get diveSites_detail_siteNotFound_body =>
      'Ez a helyszin mar nem letezik.';

  @override
  String get diveSites_detail_siteNotFound_title => 'Helyszin nem talalhato';

  @override
  String get diveSites_difficulty_advanced => 'Halado';

  @override
  String get diveSites_difficulty_beginner => 'Kezdo';

  @override
  String get diveSites_difficulty_intermediate => 'Kozepes';

  @override
  String get diveSites_difficulty_technical => 'Technikai';

  @override
  String get diveSites_edit_access_accessNotes_hint =>
      'Hogyan lehet eljutni a helyszinre, be-/kijarat, parti/hajos megkozelites';

  @override
  String get diveSites_edit_access_accessNotes_label =>
      'Megkozelitesi megjegyzesek';

  @override
  String get diveSites_edit_access_mooringNumber_hint => 'pl. Boja #12';

  @override
  String get diveSites_edit_access_mooringNumber_label => 'Kikoto szam';

  @override
  String get diveSites_edit_access_parkingInfo_hint =>
      'Parkolas elerheto, dijak, tippek';

  @override
  String get diveSites_edit_access_parkingInfo_label => 'Parkolasi informaciok';

  @override
  String get diveSites_edit_access_entryMethod_label => 'Belépés módja';

  @override
  String get diveSites_edit_access_exitMethod_label => 'Kilépés módja';

  @override
  String diveSites_edit_access_entrySuggestionPair(
    int count,
    String entry,
    String exit,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Az itteni $count merülésed: belépés $entry, kilépés $exit',
      one: 'Az itteni merülésed: belépés $entry, kilépés $exit',
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
      other: 'Az itteni $count merülésed: belépés $entry',
      one: 'Az itteni merülésed: belépés $entry',
    );
    return '$_temp0';
  }

  @override
  String get diveSites_detail_access_entryMethod => 'Belépés';

  @override
  String get diveSites_detail_access_exitMethod => 'Kilépés';

  @override
  String get diveSites_edit_altitude_helperText =>
      'Helyszin tengerszint feletti magassaga (magassagi meruleshez)';

  @override
  String get diveSites_edit_altitude_hint => 'pl. 2000';

  @override
  String diveSites_edit_altitude_label(Object symbol) {
    return 'Magassag ($symbol)';
  }

  @override
  String get diveSites_edit_altitude_validation => 'Ervenytelen magassag';

  @override
  String get diveSites_edit_appBar_deleteSiteTooltip => 'Helyszin torlese';

  @override
  String get diveSites_edit_appBar_editSite => 'Helyszin szerkesztese';

  @override
  String get diveSites_edit_appBar_merge => 'Egyesítés';

  @override
  String get diveSites_edit_appBar_mergeSites => 'Merülőhelyek egyesítése';

  @override
  String get diveSites_edit_appBar_newSite => 'Uj helyszin';

  @override
  String get diveSites_edit_appBar_save => 'Mentes';

  @override
  String get diveSites_edit_button_addSite => 'Helyszin hozzaadasa';

  @override
  String get diveSites_edit_button_mergeSites => 'Merülőhelyek egyesítése';

  @override
  String get diveSites_edit_button_saveChanges => 'Valtozasok mentese';

  @override
  String get diveSites_edit_cancel => 'Megse';

  @override
  String get diveSites_edit_depth_helperText =>
      'A legseklyebb ponttol a legmelyebb pontig';

  @override
  String get diveSites_edit_depth_maxHint => 'pl. 30';

  @override
  String diveSites_edit_depth_maxLabel(Object symbol) {
    return 'Maximalis melyseg ($symbol)';
  }

  @override
  String get diveSites_edit_depth_minHint => 'pl. 5';

  @override
  String diveSites_edit_depth_minLabel(Object symbol) {
    return 'Minimalis melyseg ($symbol)';
  }

  @override
  String get diveSites_edit_depth_separator => '-ig';

  @override
  String get diveSites_edit_discardDialog_content =>
      'Mentetlen valtozasai vannak. Biztosan el akar tavozni?';

  @override
  String get diveSites_edit_discardDialog_discard => 'Eldobas';

  @override
  String get diveSites_edit_discardDialog_keepEditing =>
      'Szerkesztes folytatas';

  @override
  String get diveSites_edit_discardDialog_title => 'Valtozasok eldobasa?';

  @override
  String get diveSites_edit_field_country_label => 'Orszag';

  @override
  String get diveSites_edit_field_city_label => 'Város';

  @override
  String get diveSites_edit_field_island_label => 'Sziget';

  @override
  String get diveSites_edit_field_bodyOfWater_label => 'Víztest';

  @override
  String get diveSites_edit_field_description_hint =>
      'A helyszin rovid leirasa';

  @override
  String get diveSites_edit_field_description_label => 'Leiras';

  @override
  String get diveSites_edit_field_notes_hint =>
      'Barmilyen egyeb informacio errol a helyszinrol';

  @override
  String get diveSites_edit_field_notes_label => 'Altalanos megjegyzesek';

  @override
  String get diveSites_edit_field_region_label => 'Regio';

  @override
  String get diveSites_edit_field_siteName_hint => 'pl. Blue Hole';

  @override
  String get diveSites_edit_field_siteName_label => 'Helyszin neve *';

  @override
  String get diveSites_edit_field_siteName_validation =>
      'Kerem adjon meg egy helyszinnevet';

  @override
  String diveSites_similarSite_useHint(Object siteName) {
    return 'Hasonló egy meglévő merülőhelyhez: „$siteName“. Koppintson a használathoz.';
  }

  @override
  String diveSites_similarSite_warning(Object siteName) {
    return 'Már létezik hasonló merülőhely: „$siteName“';
  }

  @override
  String get diveSites_edit_gps_gettingLocation => 'Lekeres...';

  @override
  String get diveSites_edit_gps_helperText =>
      'Válasszon helymeghatározási módot, vagy kérdezze le a koordinátákat az ország, régió, település és víztest automatikus kitöltéséhez';

  @override
  String get diveSites_edit_gps_latitude_hint => 'pl. 21.4225';

  @override
  String get diveSites_edit_gps_latitude_label => 'Szelesseg';

  @override
  String get diveSites_edit_gps_latitude_validation => 'Ervenytelen szelesseg';

  @override
  String get diveSites_edit_gps_longitude_hint => 'pl. -86.7542';

  @override
  String get diveSites_edit_gps_longitude_label => 'Hosszusag';

  @override
  String get diveSites_edit_gps_longitude_validation => 'Ervenytelen hosszusag';

  @override
  String get diveSites_edit_gps_pickFromMap => 'Kivalasztas terkeprol';

  @override
  String get diveSites_edit_gps_lookupFromCoordinates =>
      'Lekérdezés a koordinátákból';

  @override
  String get diveSites_edit_snackbar_lookupNothingFound =>
      'Nem található helyadat ezekhez a koordinátákhoz';

  @override
  String get diveSites_edit_snackbar_lookupFailed =>
      'A helylekérdezés nem sikerült. Ellenőrizze a kapcsolatot, és próbálja újra.';

  @override
  String get diveSites_edit_lookupReplace_title => 'Lecseréli a helyadatokat?';

  @override
  String get diveSites_edit_lookupReplace_body =>
      'A lekérdezés eltérő értékeket talált ezekhez a mezőkhöz:';

  @override
  String get diveSites_edit_lookupReplace_replace => 'Csere';

  @override
  String get diveSites_edit_lookupReplace_keep => 'Megtartás';

  @override
  String get diveSites_edit_gps_useMyLocation => 'Sajat helyzet hasznalata';

  @override
  String get diveSites_edit_hazards_helperText =>
      'Soroljon fel veszelyeket vagy biztonsagi megfontolasokat';

  @override
  String get diveSites_edit_hazards_hint =>
      'pl. Eros aramlatok, hajoforgalom, meduzak, eles korallok';

  @override
  String get diveSites_edit_hazards_label => 'Veszelyek';

  @override
  String get diveSites_edit_marineLife_addButton => 'Hozzaadas';

  @override
  String get diveSites_edit_marineLife_empty =>
      'Nincsenek vart fajok hozzaadva';

  @override
  String get diveSites_edit_marineLife_helperText =>
      'Fajok, amelyeket varhatoan lathat ezen a helyszinen';

  @override
  String diveSites_edit_merge_confirmBody(int count) {
    return 'Ez $count helyszínt egyesít egybe. A merülések, médiák és várt fajok a megmaradó helyszín alá kerülnek. A többi helyszín törlődik.';
  }

  @override
  String get diveSites_edit_merge_confirmTitle => 'Merülőhelyek egyesítése';

  @override
  String get diveSites_edit_merge_fieldSourceCycleTooltip =>
      'Érték használata a következő kiválasztott oldalról';

  @override
  String diveSites_edit_merge_fieldSourceLabel(
    Object siteName,
    int current,
    int total,
  ) {
    return '$siteName ($current/$total) -ról/ről';
  }

  @override
  String get diveSites_edit_merge_fieldSourceMenuTooltip =>
      'Érték kiválasztása a kiválasztott oldalról';

  @override
  String get diveSites_edit_merge_marineLifeHelperText =>
      'Az összes kiválasztott helyszínről összesítve';

  @override
  String diveSites_edit_merge_loadingErrorBody(Object error) {
    return 'Nem sikerült betölteni a helyszíneket: $error';
  }

  @override
  String get diveSites_edit_merge_loadingErrorTitle =>
      'Merülőhelyek egyesítése';

  @override
  String get diveSites_edit_merge_notEnoughBody =>
      'Nincs elég helyszín az egyesítéshez.';

  @override
  String get diveSites_edit_merge_notEnoughTitle => 'Merülőhelyek egyesítése';

  @override
  String get diveSites_edit_rating_clear => 'Ertekeles torlese';

  @override
  String diveSites_edit_rating_starTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '',
      one: '',
    );
    return '$count csillag$_temp0';
  }

  @override
  String get diveSites_edit_section_access => 'Megkozelites es logisztika';

  @override
  String get diveSites_edit_section_altitude => 'Tengerszint feletti magassag';

  @override
  String get diveSites_edit_section_depthRange => 'Melyseg tartomany';

  @override
  String get diveSites_edit_section_difficultyLevel => 'Nehezssgi szint';

  @override
  String get diveSites_edit_section_expectedMarineLife =>
      'Varhato tengeri elet';

  @override
  String get diveSites_edit_section_gpsCoordinates => 'GPS koordinatak';

  @override
  String get diveSites_edit_section_hazards => 'Veszelyek es biztonsag';

  @override
  String get diveSites_edit_section_rating => 'Ertekeles';

  @override
  String get diveSites_edit_section_waterType => 'Víztípus';

  @override
  String diveSites_edit_snackbar_errorDeleting(Object error) {
    return 'Hiba a helyszin torlesekor: $error';
  }

  @override
  String diveSites_edit_snackbar_errorSaving(Object error) {
    return 'Hiba a helyszin mentesekor: $error';
  }

  @override
  String get diveSites_edit_snackbar_locationCaptured => 'Helyzet rogzitve';

  @override
  String diveSites_edit_snackbar_locationCapturedWithAccuracy(Object accuracy) {
    return 'Helyzet rogzitve (${accuracy}m)';
  }

  @override
  String get diveSites_edit_snackbar_locationSelectedFromMap =>
      'Helyszin kivalasztva a terkeprol';

  @override
  String get diveSites_edit_snackbar_locationSettings => 'Beallitasok';

  @override
  String get diveSites_edit_snackbar_locationUnavailableDesktop =>
      'Nem sikerult a helyzet lekerdezes. A helymeghatarozoasi szolgaltatasok nem lehetnek elerhetoek.';

  @override
  String get diveSites_edit_snackbar_locationUnavailableMobile =>
      'Nem sikerult a helyzet lekerdezes. Kerem ellenorizze az engedelyeket.';

  @override
  String get diveSites_edit_snackbar_siteAdded => 'Helyszin hozzaadva';

  @override
  String get diveSites_edit_snackbar_sitesMerged => 'Merülőhelyek egyesítve';

  @override
  String get diveSites_edit_snackbar_siteUpdated => 'Helyszin frissitve';

  @override
  String get diveSites_fab_label => 'Helyszin hozzaadasa';

  @override
  String get diveSites_fab_tooltip => 'Uj merulohely hozzaadasa';

  @override
  String get diveSites_filter_apply => 'Szurok alkalmazasa';

  @override
  String get diveSites_filter_cancel => 'Megse';

  @override
  String get diveSites_filter_clearAll => 'Osszes torlese';

  @override
  String get diveSites_filter_country_hint => 'pl. Thaifold';

  @override
  String get diveSites_filter_country_label => 'Orszag';

  @override
  String get diveSites_filter_depth_max_label => 'Max';

  @override
  String get diveSites_filter_depth_min_label => 'Min';

  @override
  String get diveSites_filter_depth_separator => '-ig';

  @override
  String get diveSites_filter_difficulty_any => 'Barmely';

  @override
  String get diveSites_filter_option_hasCoordinates_subtitle =>
      'Csak GPS hellyel rendelkezo helyszinek mutatasa';

  @override
  String get diveSites_filter_option_hasCoordinates_title => 'Van koordinata';

  @override
  String get diveSites_filter_option_hasDives_subtitle =>
      'Csak rogzitett merulesekkel rendelkezo helyszinek mutatasa';

  @override
  String get diveSites_filter_option_hasDives_title => 'Vannak merulesek';

  @override
  String diveSites_filter_rating_starsPlus(Object count) {
    return '$count+ csillag';
  }

  @override
  String get diveSites_filter_region_hint => 'pl. Phuket';

  @override
  String get diveSites_filter_region_label => 'Regio';

  @override
  String get diveSites_filter_section_depthRange => 'Max melyseg tartomany';

  @override
  String get diveSites_filter_section_difficulty => 'Nehezsseg';

  @override
  String get diveSites_filter_section_location => 'Helyszin';

  @override
  String get diveSites_filter_section_minRating => 'Minimalis ertekeles';

  @override
  String get diveSites_filter_section_options => 'Opciok';

  @override
  String get diveSites_filter_title => 'Helyszinek szurese';

  @override
  String get diveSites_import_appBar_title => 'Merulohely importalasa';

  @override
  String get diveSites_import_badge_imported => 'Importalt';

  @override
  String get diveSites_import_badge_saved => 'Mentett';

  @override
  String get diveSites_import_button_import => 'Importalas';

  @override
  String get diveSites_import_detail_alreadyImported => 'Mar importalva';

  @override
  String get diveSites_import_detail_importToMySites =>
      'Importalas a helyszineimhez';

  @override
  String diveSites_import_detail_source(Object source) {
    return 'Forras: $source';
  }

  @override
  String get diveSites_import_empty_description =>
      'Keressen merulohelyeket a nepszeru\nmerulesi celpontok adatbazisunkbol vilagszerte.';

  @override
  String get diveSites_import_empty_hint =>
      'Probaljon keresni helyszinnev, orszag vagy regio alapjan.';

  @override
  String get diveSites_import_empty_title => 'Merulohelyek keresese';

  @override
  String get diveSites_import_error_retry => 'Ujra';

  @override
  String get diveSites_import_error_title => 'Keresesi hiba';

  @override
  String get diveSites_import_error_unknown => 'Ismeretlen hiba';

  @override
  String get diveSites_import_externalSite_locationUnknown =>
      'Ismeretlen helyszin';

  @override
  String get diveSites_import_label_gps => 'GPS';

  @override
  String get diveSites_import_localSite_locationNotSet =>
      'Helyszin nincs megadva';

  @override
  String diveSites_import_noResults_description(Object query) {
    return 'Nem talalhato merulohely \"$query\" keresesi kifejezesre.\nProbaljon mas keresesi kifejezest.';
  }

  @override
  String get diveSites_import_noResults_title => 'Nincs talalat';

  @override
  String get diveSites_import_quickSearch_caribbean => 'Karib-tenger';

  @override
  String get diveSites_import_quickSearch_indonesia => 'Indonezia';

  @override
  String get diveSites_import_quickSearch_maldives => 'Maldiv-szigetek';

  @override
  String get diveSites_import_quickSearch_philippines => 'Fulop-szigetek';

  @override
  String get diveSites_import_quickSearch_redSea => 'Voros-tenger';

  @override
  String get diveSites_import_quickSearch_thailand => 'Thaifold';

  @override
  String get diveSites_import_search_clearTooltip => 'Kereses torlese';

  @override
  String get diveSites_import_search_hint =>
      'Merulohelyek keresese (pl. \"Blue Hole\", \"Thaifold\")';

  @override
  String diveSites_import_section_importFromDatabase(Object count) {
    return 'Importalas adatbazisbol ($count)';
  }

  @override
  String diveSites_import_section_mySites(Object count) {
    return 'Helyszineim ($count)';
  }

  @override
  String diveSites_import_semantics_viewDetails(Object name) {
    return '$name reszleteinek megtekintese';
  }

  @override
  String diveSites_import_semantics_viewSavedSite(Object name) {
    return 'Mentett helyszin megtekintese: $name';
  }

  @override
  String get diveSites_import_snackbar_failed =>
      'Nem sikerult a helyszin importalasa';

  @override
  String diveSites_import_snackbar_imported(Object name) {
    return '\"$name\" importalva';
  }

  @override
  String get diveSites_import_snackbar_viewAction => 'Megtekintes';

  @override
  String get diveSites_list_activeFilter_clear => 'Torles';

  @override
  String diveSites_list_activeFilter_country(Object country) {
    return 'Orszag: $country';
  }

  @override
  String diveSites_list_activeFilter_depthRangeBoth(Object min, Object max) {
    return '$min-$max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMax(Object max) {
    return 'Legfeljebb $max';
  }

  @override
  String diveSites_list_activeFilter_depthRangeMin(Object min) {
    return '$min+';
  }

  @override
  String get diveSites_list_activeFilter_hasCoordinates => 'Van koordinata';

  @override
  String get diveSites_list_activeFilter_hasDives => 'Vannak merulesek';

  @override
  String diveSites_list_activeFilter_region(Object region) {
    return 'Regio: $region';
  }

  @override
  String get diveSites_list_appBar_title => 'Merulohelyek';

  @override
  String get diveSites_list_bulkDelete_cancel => 'Megse';

  @override
  String get diveSites_list_bulkDelete_confirm => 'Torles';

  @override
  String diveSites_list_bulkDelete_content(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'helyszint',
      one: 'helyszint',
    );
    return 'Biztosan torolni akarja a(z) $count $_temp0? Ez a muvelet 5 masodpercen belul visszavonhato.';
  }

  @override
  String get diveSites_list_bulkDelete_restored => 'Helyszinek visszaallitva';

  @override
  String diveSites_list_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'helyszin',
      one: 'helyszin',
    );
    return '$count $_temp0 torolve';
  }

  @override
  String get diveSites_list_bulkDelete_title => 'Helyszinek torlese';

  @override
  String get diveSites_list_bulkDelete_undo => 'Visszavonas';

  @override
  String get diveSites_list_merge_restored => 'Osszevonás visszavonva';

  @override
  String diveSites_list_merge_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'helyszin',
      one: 'helyszin',
    );
    return '$count $_temp0 osszevonva';
  }

  @override
  String get diveSites_list_merge_undo => 'Visszavonas';

  @override
  String get diveSites_list_emptyFiltered_clearAll => 'Osszes szuro torlese';

  @override
  String get diveSites_list_emptyFiltered_subtitle =>
      'Probalja modositani vagy torolni a szuroket';

  @override
  String get diveSites_list_emptyFiltered_title =>
      'Nincs a szuroknek megfelelo helyszin';

  @override
  String get diveSites_list_empty_addFirstSite => 'Elso helyszin hozzaadasa';

  @override
  String get diveSites_list_empty_import => 'Importalas';

  @override
  String get diveSites_list_empty_subtitle =>
      'Adjon hozza merulohelyeket kedvenc helyszinei koveTesehez';

  @override
  String get diveSites_list_empty_title => 'Meg nincsenek merulohelyek';

  @override
  String diveSites_list_error_loadingSites(Object error) {
    return 'Hiba a helyszinek betoltesekor: $error';
  }

  @override
  String get diveSites_list_error_retry => 'Ujra';

  @override
  String get diveSites_list_menu_import => 'Importalas';

  @override
  String get diveSites_list_menu_select => 'Merülőhelyek kiválasztása';

  @override
  String get diveSites_list_menu_fillLocationDetails =>
      'Hiányzó helyadatok kitöltése';

  @override
  String get diveSites_backfill_confirm_title =>
      'Kitölti a hiányzó helyadatokat?';

  @override
  String diveSites_backfill_confirm_body(int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count koordinátával rendelkező merülőhelynek üres az országa, régiója, települése vagy víztestje.',
      one:
          '1 koordinátával rendelkező merülőhelynek üres az országa, régiója, települése vagy víztestje.',
    );
    return '$_temp0 A Submersion mindegyiket lekérdezi az OpenStreetMapról, és csak az üres mezőket tölti ki. Ez körülbelül $minutes percet vesz igénybe.';
  }

  @override
  String get diveSites_backfill_confirm_start => 'Indítás';

  @override
  String get diveSites_backfill_nothingToFill =>
      'Minden koordinátával rendelkező merülőhelynek megvannak a helyadatai.';

  @override
  String get diveSites_backfill_progress_title => 'Helyadatok kitöltése';

  @override
  String diveSites_backfill_progress_count(int done, int total) {
    return '$done / $total';
  }

  @override
  String get diveSites_backfill_cancel => 'Mégse';

  @override
  String diveSites_backfill_summary(int updated, int unchanged, int failed) {
    return 'Frissítve $updated, változatlan $unchanged, sikertelen $failed';
  }

  @override
  String get diveSites_backfill_offline =>
      'A helylekérdezés nem érhető el. Ellenőrizze a kapcsolatot, és próbálja újra.';

  @override
  String get diveSites_list_search_backTooltip => 'Vissza';

  @override
  String get diveSites_list_search_clearTooltip => 'Kereses torlese';

  @override
  String get diveSites_list_search_emptyHint =>
      'Kereses helyszinnev, orszag vagy regio alapjan';

  @override
  String diveSites_list_search_error(Object error) {
    return 'Hiba: $error';
  }

  @override
  String diveSites_list_search_noResults(Object query) {
    return 'Nem talalhato helyszin \"$query\" keresesi kifejezesre';
  }

  @override
  String get diveSites_list_search_placeholder => 'Helyszinek keresese...';

  @override
  String get diveSites_list_selection_closeTooltip => 'Kivalasztas bezarasa';

  @override
  String diveSites_list_selection_count(Object count) {
    return '$count kivalasztva';
  }

  @override
  String get diveSites_list_selection_deleteTooltip => 'Kivalasztottak torlese';

  @override
  String get diveSites_list_selection_mergeTooltip => 'Kijelöltek egyesítése';

  @override
  String get diveSites_list_selection_deselectAllTooltip =>
      'Osszes kivalasztas megszuntetese';

  @override
  String get diveSites_list_selection_selectAllTooltip => 'Osszes kivalasztasa';

  @override
  String get diveSites_list_sort_title => 'Helyszinek rendezese';

  @override
  String diveSites_list_tile_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merules',
      one: '1 merules',
    );
    return '$_temp0';
  }

  @override
  String diveSites_list_tile_semantics(Object name) {
    return 'Merulohely: $name';
  }

  @override
  String get diveSites_list_tooltip_filterSites => 'Helyszinek szurese';

  @override
  String get diveSites_list_tooltip_mapView => 'Terkep nezet';

  @override
  String get diveSites_list_tooltip_searchSites => 'Helyszinek keresese';

  @override
  String get diveSites_list_tooltip_sort => 'Rendezes';

  @override
  String get diveSites_locationPicker_appBar_title => 'Helyszin kivalasztasa';

  @override
  String get diveSites_locationPicker_confirmButton => 'Megerosites';

  @override
  String get diveSites_locationPicker_confirmTooltip =>
      'Kivalasztott helyszin megerositese';

  @override
  String get diveSites_locationPicker_fab_tooltip => 'Sajat helyzet hasznalata';

  @override
  String get diveSites_locationPicker_instruction_locationSelected =>
      'Helyszin kivalasztva';

  @override
  String get diveSites_locationPicker_instruction_lookingUp =>
      'Helyszin keresese...';

  @override
  String get diveSites_locationPicker_instruction_tapToSelect =>
      'Koppintson a terkepre a helyszin kivalasztasahoz';

  @override
  String get diveSites_locationPicker_label_latitude => 'Szelesseg';

  @override
  String get diveSites_locationPicker_label_longitude => 'Hosszusag';

  @override
  String diveSites_locationPicker_semantics_coordinates(
    Object latitude,
    Object longitude,
  ) {
    return 'Kivalasztott koordinatak: szelesseg $latitude, hosszusag $longitude';
  }

  @override
  String get diveSites_locationPicker_semantics_lookingUp =>
      'Helyszin keresese';

  @override
  String get diveSites_locationPicker_semantics_map =>
      'Interaktiv terkep merulohely kivalasztasahoz. Koppintson a terkepre a helyszin kivalasztasahoz.';

  @override
  String diveSites_mapContent_error_loadingDiveSites(Object error) {
    return 'Hiba a merulohelyek betoltesekor: $error';
  }

  @override
  String get diveSites_map_appBar_title => 'Merulohelyek';

  @override
  String get diveSites_map_builtInSites_add => 'Hozzáadás a merülőhelyeimhez';

  @override
  String get diveSites_map_builtInSites_addError =>
      'Nem sikerült hozzáadni a helyet. Kérjük, próbálja újra.';

  @override
  String get diveSites_map_builtInSites_added => 'Hozzáadva a merülőhelyeihez';

  @override
  String get diveSites_map_builtInSites_hide =>
      'Beépített merülőhelyek elrejtése';

  @override
  String get diveSites_map_builtInSites_off =>
      'Beépített merülőhelyek elrejtve';

  @override
  String get diveSites_map_builtInSites_on =>
      'Beépített merülőhelyek megjelenítve';

  @override
  String get diveSites_map_builtInSites_show =>
      'Beépített merülőhelyek megjelenítése';

  @override
  String get diveSites_map_empty_description =>
      'Adjon hozza koordinatakat a merulohelyeihez, hogy lassa oket a terkepen';

  @override
  String get diveSites_map_empty_title =>
      'Nincsenek koordinataval rendelkezo helyszinek';

  @override
  String diveSites_map_error_loadingSites(Object error) {
    return 'Hiba a helyszinek betoltesekor: $error';
  }

  @override
  String get diveSites_map_error_retry => 'Ujra';

  @override
  String diveSites_map_infoCard_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merules',
      one: '1 merules',
    );
    return '$_temp0';
  }

  @override
  String diveSites_map_semantics_builtInSiteMarker(Object name) {
    return 'Beépített merülőhely: $name';
  }

  @override
  String diveSites_map_semantics_diveSiteMarker(Object name) {
    return 'Merulohely: $name';
  }

  @override
  String get diveSites_map_tooltip_fitAllSites => 'Osszes helyszin illesztese';

  @override
  String get diveSites_map_tooltip_listView => 'Lista nezet';

  @override
  String get diveSites_summary_action_addSite => 'Helyszin hozzaadasa';

  @override
  String get diveSites_summary_action_import => 'Importalas';

  @override
  String get diveSites_summary_action_viewMap => 'Terkep megtekintese';

  @override
  String diveSites_summary_countriesMore(Object count) {
    return '+ $count tovabb';
  }

  @override
  String get diveSites_summary_header_subtitle =>
      'Valasszon helyszint a listabol a reszletek megtekIntesehez';

  @override
  String get diveSites_summary_header_title => 'Merulohelyek';

  @override
  String get diveSites_summary_section_countriesRegions => 'Orszagok es regiok';

  @override
  String get diveSites_summary_section_mostDived => 'Legtobbet merult';

  @override
  String get diveSites_summary_section_overview => 'Attekintes';

  @override
  String get diveSites_summary_section_quickActions => 'Gyorsmuveletek';

  @override
  String get diveSites_summary_section_topRated => 'Legjobban ertekelt';

  @override
  String get diveSites_summary_stat_avgRating => 'Atl. ertekeles';

  @override
  String get diveSites_summary_stat_totalDives => 'Osszes merules';

  @override
  String get diveSites_summary_stat_totalSites => 'Osszes helyszin';

  @override
  String get diveSites_summary_stat_withGps => 'GPS-szel';

  @override
  String get diveType_builtin_altitude => 'Magaslati';

  @override
  String get diveType_builtin_boat => 'Hajóról';

  @override
  String get diveType_builtin_cave => 'Barlang';

  @override
  String get diveType_builtin_cavern => 'Barlangbejárat';

  @override
  String get diveType_builtin_deep => 'Mély';

  @override
  String get diveType_builtin_drift => 'Sodrásos';

  @override
  String get diveType_builtin_freedive => 'Szabadtüdős';

  @override
  String get diveType_builtin_ice => 'Jég';

  @override
  String get diveType_builtin_liveaboard => 'Búvárhajós';

  @override
  String get diveType_builtin_night => 'Éjszakai';

  @override
  String get diveType_builtin_recreational => 'Szabadidős';

  @override
  String get diveType_builtin_shore => 'Partról';

  @override
  String get diveType_builtin_technical => 'Technikai';

  @override
  String get diveType_builtin_training => 'Képzés';

  @override
  String get diveType_builtin_wreck => 'Roncs';

  @override
  String get diveTypes_addDialog_addButton => 'Hozzáadás';

  @override
  String get diveTypes_addDialog_nameHint => 'pl. Kutatás és mentés';

  @override
  String get diveTypes_addDialog_nameLabel => 'Merülés típus neve';

  @override
  String get diveTypes_addDialog_nameValidation => 'Adj meg egy nevet';

  @override
  String get diveTypes_addDialog_title => 'Egyedi merülés típus hozzáadása';

  @override
  String get diveTypes_addTooltip => 'Merülés típus hozzáadása';

  @override
  String get diveTypes_appBar_title => 'Merülés típusok';

  @override
  String get diveTypes_builtIn => 'Beépített';

  @override
  String get diveTypes_builtInHeader => 'Beépített merülés típusok';

  @override
  String get diveTypes_custom => 'Egyedi';

  @override
  String get diveTypes_customHeader => 'Egyedi merülés típusok';

  @override
  String diveTypes_deleteDialog_content(Object name) {
    return 'Biztosan törölni szeretnéd: \"$name\"?';
  }

  @override
  String get diveTypes_deleteDialog_title => 'Merülés típus törlése?';

  @override
  String get diveTypes_deleteTooltip => 'Merülés típus törlése';

  @override
  String diveTypes_snackbar_added(Object name) {
    return 'Merülés típus hozzáadva: $name';
  }

  @override
  String diveTypes_snackbar_cannotDelete(Object name) {
    return 'Nem lehet törölni \"$name\" - meglévő merülések használják';
  }

  @override
  String diveTypes_snackbar_deleted(Object name) {
    return 'Törölve: \"$name\"';
  }

  @override
  String diveTypes_snackbar_errorAdding(Object error) {
    return 'Hiba a merülés típus hozzáadásakor: $error';
  }

  @override
  String diveTypes_snackbar_errorDeleting(Object error) {
    return 'Hiba a merülés típus törlésekor: $error';
  }

  @override
  String get divers_detail_activeDiver => 'Aktiv merülo';

  @override
  String get divers_detail_allergiesLabel => 'Allergiak';

  @override
  String get divers_detail_appBarTitle => 'Merülo';

  @override
  String get divers_detail_bloodTypeLabel => 'Vercsoport';

  @override
  String get divers_detail_bottomTimeLabel => 'Fenekido';

  @override
  String get divers_detail_cancelButton => 'Megse';

  @override
  String get divers_detail_contactTitle => 'Kapcsolat';

  @override
  String get divers_detail_defaultLabel => 'Alapertelmezett';

  @override
  String get divers_detail_deleteButton => 'Torles';

  @override
  String divers_detail_deleteDialogContent(Object name) {
    return 'This will permanently delete $name and all associated data including dive logs, dive computers, equipment, certifications, and sites.';
  }

  @override
  String get divers_detail_deleteDialogTitle => 'Merülo torlese?';

  @override
  String divers_detail_deleteError(Object error) {
    return 'Nem sikerult a torles: $error';
  }

  @override
  String get divers_detail_deleteMenuItem => 'Torles';

  @override
  String get divers_detail_deletedSnackbar => 'Merülo torolve';

  @override
  String get divers_detail_diveInsuranceTitle => 'Merülesi biztositas';

  @override
  String get divers_detail_diveStatisticsTitle => 'Merülesi statisztikak';

  @override
  String get divers_detail_editTooltip => 'Merülo szerkesztese';

  @override
  String get divers_detail_emergencyContactTitle =>
      'Veszhelyzeti kapcsolattarto';

  @override
  String divers_detail_errorPrefix(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get divers_detail_expiredBadge => 'Lejart';

  @override
  String get divers_detail_expiresLabel => 'Lejar';

  @override
  String get divers_detail_medicalInfoTitle => 'Orvosi informaciok';

  @override
  String get divers_detail_medicalNotesLabel => 'Megjegyzesek';

  @override
  String get divers_detail_notFound => 'Merülo nem talalhato';

  @override
  String get divers_detail_notesTitle => 'Megjegyzesek';

  @override
  String get divers_detail_policyNumberLabel => 'Kotveny szama';

  @override
  String get divers_detail_providerLabel => 'Biztosito';

  @override
  String get divers_detail_setAsDefault => 'Beallitas alapertelmezettkent';

  @override
  String divers_detail_setAsDefaultSnackbar(Object name) {
    return '$name beallitva alapertelmezett merülokent';
  }

  @override
  String get divers_detail_switchToTooltip => 'Valtas erre a merülore';

  @override
  String divers_detail_switchedTo(Object name) {
    return 'Valtas: $name';
  }

  @override
  String get divers_detail_totalDivesLabel => 'Osszes merüles';

  @override
  String get divers_detail_unableToLoadStats =>
      'Nem sikerult a statisztikak betoltese';

  @override
  String get divers_edit_addButton => 'Merülo hozzaadasa';

  @override
  String get divers_edit_addTitle => 'Merülo hozzaadasa';

  @override
  String get divers_edit_allergiesHint => 'pl. Penicillin, kagylofele';

  @override
  String get divers_edit_allergiesLabel => 'Allergiak';

  @override
  String get divers_edit_bloodTypeHint => 'pl. 0+, A-, B+';

  @override
  String get divers_edit_bloodTypeLabel => 'Vercsoport';

  @override
  String get divers_edit_cancelButton => 'Megse';

  @override
  String get divers_edit_clearInsuranceExpiryTooltip =>
      'Biztositasi lejarat torlese';

  @override
  String get divers_edit_clearMedicalClearanceTooltip =>
      'Orvosi engedelylejarat torlese';

  @override
  String get divers_edit_contactNameLabel => 'Kapcsolattarto neve';

  @override
  String get divers_edit_contactPhoneLabel => 'Kapcsolattarto telefonszama';

  @override
  String get divers_edit_discardButton => 'Elvetés';

  @override
  String get divers_edit_discardDialogContent =>
      'Nem mentett valtoztatasai vannak. Biztosan elveti oket?';

  @override
  String get divers_edit_discardDialogTitle => 'Valtoztatasok elvetese?';

  @override
  String get divers_edit_diverAdded => 'Merülo hozzaadva';

  @override
  String get divers_edit_diverUpdated => 'Merülo frissitve';

  @override
  String get divers_edit_editTitle => 'Merülo szerkesztese';

  @override
  String get divers_edit_emailError => 'Adjon meg ervenyes e-mail cimet';

  @override
  String get divers_edit_emailLabel => 'E-mail';

  @override
  String get divers_edit_emergencyContactsSection =>
      'Veszhelyzeti kapcsolattartok';

  @override
  String divers_edit_errorLoading(Object error) {
    return 'Hiba a merülo betoltesekor: $error';
  }

  @override
  String divers_edit_errorSaving(Object error) {
    return 'Hiba a merülo mentesekor: $error';
  }

  @override
  String get divers_edit_expiryDateNotSet => 'Nincs megadva';

  @override
  String get divers_edit_expiryDateTitle => 'Lejarat datuma';

  @override
  String get divers_edit_insuranceProviderHint => 'pl. DAN, DiveAssure';

  @override
  String get divers_edit_insuranceProviderLabel => 'Biztosito';

  @override
  String get divers_edit_insuranceSection => 'Merülesi biztositas';

  @override
  String get divers_edit_keepEditingButton => 'Szerkesztes folytatasa';

  @override
  String get divers_edit_medicalClearanceExpired => 'Lejart';

  @override
  String get divers_edit_medicalClearanceExpiringSoon => 'Hamarosan lejar';

  @override
  String get divers_edit_medicalClearanceNotSet => 'Nincs megadva';

  @override
  String get divers_edit_medicalClearanceTitle => 'Orvosi engedelylejarat';

  @override
  String get divers_edit_medicalInfoSection => 'Orvosi informaciok';

  @override
  String get divers_edit_medicalNotesLabel => 'Orvosi megjegyzesek';

  @override
  String get divers_edit_medicationsHint => 'pl. Napi aszpirin, EpiPen';

  @override
  String get divers_edit_medicationsLabel => 'Gyogyszerek';

  @override
  String get divers_edit_nameError => 'A nev megadasa kotelezo';

  @override
  String get divers_edit_nameLabel => 'Nev *';

  @override
  String get divers_edit_notesLabel => 'Megjegyzesek';

  @override
  String get divers_edit_notesSection => 'Megjegyzesek';

  @override
  String get divers_edit_personalInfoSection => 'Szemelyes adatok';

  @override
  String get divers_edit_phoneLabel => 'Telefon';

  @override
  String get divers_edit_policyNumberLabel => 'Kotveny szama';

  @override
  String get divers_edit_primaryContactTitle => 'Elsodleges kapcsolattarto';

  @override
  String get divers_edit_relationshipHint => 'pl. Hazastars, Szülo, Barat';

  @override
  String get divers_edit_relationshipLabel => 'Kapcsolat';

  @override
  String get divers_edit_saveButton => 'Mentes';

  @override
  String get divers_edit_secondaryContactTitle => 'Masodlagos kapcsolattarto';

  @override
  String get divers_edit_selectInsuranceExpiryTooltip =>
      'Biztositasi lejarat valasztasa';

  @override
  String get divers_edit_selectMedicalClearanceTooltip =>
      'Orvosi engedelylejarat valasztasa';

  @override
  String get divers_edit_updateButton => 'Merülo frissitese';

  @override
  String get divers_list_activeBadge => 'Aktiv';

  @override
  String get divers_list_addDiverButton => 'Merülo hozzaadasa';

  @override
  String get divers_list_addDiverTooltip => 'Uj merülo profil hozzaadasa';

  @override
  String get divers_list_appBarTitle => 'Merülo profilok';

  @override
  String get divers_list_compactTitle => 'Merülok';

  @override
  String divers_list_diverStats(Object diveCount, Object bottomTime) {
    return '$diveCount merüles$bottomTime';
  }

  @override
  String get divers_list_emptySubtitle =>
      'Adjon hozza merülo profilokat tobb szemely merülesi naploinak követesehez';

  @override
  String get divers_list_emptyTitle => 'Meg nincsenek merülok';

  @override
  String divers_list_errorLoading(Object error) {
    return 'Hiba a merülok betoltesekor: $error';
  }

  @override
  String get divers_list_errorLoadingStats =>
      'Hiba a statisztikak betoltesekor';

  @override
  String get divers_list_loadingStats => 'Betoltes...';

  @override
  String get divers_list_retryButton => 'Ujraproba';

  @override
  String divers_list_viewDiverLabel(Object name) {
    return '$name merülo megtekintese';
  }

  @override
  String get divers_summary_activeDiverTitle => 'Aktiv merülo';

  @override
  String get divers_summary_otherDiversTitle => 'Tobbi merülo';

  @override
  String get divers_summary_overviewTitle => 'Attekintes';

  @override
  String get divers_summary_quickActionsTitle => 'Gyorsmuveletek';

  @override
  String get divers_summary_subtitle =>
      'Valasszon egy merülot a listabol a reszletek megtekintésehez';

  @override
  String get divers_summary_title => 'Merülo profilok';

  @override
  String get divers_summary_totalDiversLabel => 'Osszes merülo';

  @override
  String divers_detail_deleteDialogConfirmHint(String name) {
    return 'Type \"Delete $name\" to confirm';
  }

  @override
  String divers_detail_deleteDialogConfirmText(String name) {
    return 'Delete $name';
  }

  @override
  String get enum_altitudeGroup_extreme => 'Extrem magassag';

  @override
  String get enum_altitudeGroup_extreme_range => '>2700m (>8858ft)';

  @override
  String get enum_altitudeGroup_group1 => '1. magassagi csoport';

  @override
  String get enum_altitudeGroup_group1_range => '300-900m (984-2953ft)';

  @override
  String get enum_altitudeGroup_group2 => '2. magassagi csoport';

  @override
  String get enum_altitudeGroup_group2_range => '900-1800m (2953-5906ft)';

  @override
  String get enum_altitudeGroup_group3 => '3. magassagi csoport';

  @override
  String get enum_altitudeGroup_group3_range => '1800-2700m (5906-8858ft)';

  @override
  String get enum_altitudeGroup_seaLevel => 'Tengerszint';

  @override
  String get enum_altitudeGroup_seaLevel_range => '0-300m (0-984ft)';

  @override
  String get enum_ascentRate_danger => 'Veszelyes';

  @override
  String get enum_ascentRate_safe => 'Biztonsagos';

  @override
  String get enum_ascentRate_warning => 'Figyelmeztetés';

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
  String get enum_certificationAgency_other => 'Egyeb';

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
  String get enum_certificationLevel_advancedNitrox => 'Halado Nitrox';

  @override
  String get enum_certificationLevel_advancedOpenWater => 'Halado nyiltvizi';

  @override
  String get enum_certificationLevel_cave => 'Barlang';

  @override
  String get enum_certificationLevel_cavern => 'Barlangi eloszoba';

  @override
  String get enum_certificationLevel_courseDirector => 'Tanfolyamigazgato';

  @override
  String get enum_certificationLevel_decompression => 'Dekompresszio';

  @override
  String get enum_certificationLevel_diveGuide => 'Búvárvezető';

  @override
  String get enum_certificationLevel_diveMaster => 'Divemaster';

  @override
  String get enum_certificationLevel_instructor => 'Oktato';

  @override
  String get enum_certificationLevel_masterInstructor => 'Mesteroktato';

  @override
  String get enum_certificationLevel_nitrox => 'Nitrox';

  @override
  String get enum_certificationLevel_openWater => 'Nyiltvizi';

  @override
  String get enum_certificationLevel_other => 'Egyeb';

  @override
  String get enum_certificationLevel_rebreather => 'Visszalelegezteto';

  @override
  String get enum_certificationLevel_rescue => 'Mento buvar';

  @override
  String get enum_certificationLevel_sidemount => 'Sidemount';

  @override
  String get enum_certificationLevel_techDiver => 'Technikai buvar';

  @override
  String get enum_certificationLevel_trimix => 'Trimix';

  @override
  String get enum_certificationLevel_wreck => 'Roncs';

  @override
  String get enum_currentDirection_east => 'Kelet';

  @override
  String get enum_currentDirection_none => 'Nincs';

  @override
  String get enum_currentDirection_north => 'Eszak';

  @override
  String get enum_currentDirection_northEast => 'Eszakkelet';

  @override
  String get enum_currentDirection_northWest => 'Eszaknyugat';

  @override
  String get enum_currentDirection_south => 'Del';

  @override
  String get enum_currentDirection_southEast => 'Delkelet';

  @override
  String get enum_currentDirection_southWest => 'Delnyugat';

  @override
  String get enum_currentDirection_variable => 'Valtozo';

  @override
  String get enum_currentDirection_west => 'Nyugat';

  @override
  String get enum_currentStrength_light => 'Gyenge';

  @override
  String get enum_currentStrength_moderate => 'Mersekelt';

  @override
  String get enum_currentStrength_none => 'Nincs';

  @override
  String get enum_currentStrength_strong => 'Eros';

  @override
  String get enum_diveMode_ccr => 'Zart koru visszalelegezteto';

  @override
  String get enum_diveMode_gauge => 'Gauge';

  @override
  String get enum_diveMode_oc => 'Nyilt koru';

  @override
  String get enum_diveMode_scr => 'Felig zart visszalelegezteto';

  @override
  String get enum_diveType_altitude => 'Magassagi';

  @override
  String get enum_diveType_boat => 'Hajos';

  @override
  String get enum_diveType_cave => 'Barlang';

  @override
  String get enum_diveType_deep => 'Mely';

  @override
  String get enum_diveType_drift => 'Sodrodas';

  @override
  String get enum_diveType_freedive => 'Szabadmerules';

  @override
  String get enum_diveType_ice => 'Jeg';

  @override
  String get enum_diveType_liveaboard => 'Hajo szallas';

  @override
  String get enum_diveType_night => 'Ejszakai';

  @override
  String get enum_diveType_recreational => 'Rekreaccios';

  @override
  String get enum_diveType_shore => 'Parti';

  @override
  String get enum_diveType_technical => 'Technikai';

  @override
  String get enum_diveType_training => 'Kepzes';

  @override
  String get enum_diveType_wreck => 'Roncs';

  @override
  String get enum_entryMethod_backRoll => 'Hatragurulas';

  @override
  String get enum_entryMethod_boat => 'Hajos beszallas';

  @override
  String get enum_entryMethod_giantStride => 'Orias lepes';

  @override
  String get enum_entryMethod_jetty => 'Steg/Molo';

  @override
  String get enum_entryMethod_ladder => 'Letra';

  @override
  String get enum_entryMethod_other => 'Egyeb';

  @override
  String get enum_entryMethod_platform => 'Platform';

  @override
  String get enum_entryMethod_seatedEntry => 'Ulos beszallas';

  @override
  String get enum_entryMethod_shore => 'Parti beszallas';

  @override
  String get enum_equipmentStatus_active => 'Aktiv';

  @override
  String get enum_equipmentStatus_inService => 'Szervizben';

  @override
  String get enum_equipmentStatus_loaned => 'Kolcsonadva';

  @override
  String get enum_equipmentStatus_lost => 'Elveszett';

  @override
  String get enum_equipmentStatus_needsService => 'Szerviz szukseges';

  @override
  String get enum_equipmentStatus_retired => 'Kivonva';

  @override
  String get enum_equipmentType_bcd => 'Jacket';

  @override
  String get enum_equipmentType_boots => 'Cipok';

  @override
  String get enum_equipmentType_camera => 'Kamera';

  @override
  String get enum_equipmentType_dpv => 'DPV';

  @override
  String get enum_equipmentType_computer => 'Merulesszamitogep';

  @override
  String get enum_equipmentType_drysuit => 'Szaraz ruha';

  @override
  String get enum_equipmentType_fins => 'Uszonyok';

  @override
  String get enum_equipmentType_gloves => 'Kesztyuk';

  @override
  String get enum_equipmentType_hood => 'Csuklya';

  @override
  String get enum_equipmentType_knife => 'Kes';

  @override
  String get enum_equipmentType_light => 'Lampa';

  @override
  String get enum_equipmentType_mask => 'Maszk';

  @override
  String get enum_equipmentType_other => 'Egyeb';

  @override
  String get enum_equipmentType_reel => 'Orsó';

  @override
  String get enum_equipmentType_regulator => 'Automata';

  @override
  String get enum_equipmentType_smb => 'SMB';

  @override
  String get enum_equipmentType_tank => 'Palack';

  @override
  String get enum_equipmentType_weights => 'Sulyok';

  @override
  String get enum_equipmentType_wetsuit => 'Neopren ruha';

  @override
  String get enum_eventSeverity_alert => 'Riasztas';

  @override
  String get enum_eventSeverity_info => 'Info';

  @override
  String get enum_eventSeverity_warning => 'Figyelmeztetés';

  @override
  String get enum_pdfPageSize_a4 => 'A4';

  @override
  String get enum_pdfPageSize_a4_description => '210 x 297 mm';

  @override
  String get enum_pdfPageSize_letter => 'Letter';

  @override
  String get enum_pdfPageSize_letter_description => '8.5 x 11 in';

  @override
  String get enum_pdfTemplate_detailed => 'Reszletes';

  @override
  String get enum_pdfTemplate_detailed_description =>
      'Teljes merulesi informacio jegyzetekkel es ertekelesekkel';

  @override
  String get enum_pdfTemplate_nauiStyle => 'NAUI stilusu';

  @override
  String get enum_pdfTemplate_nauiStyle_description =>
      'NAUI naplo formatumnak megfelelo elrendezes';

  @override
  String get enum_pdfTemplate_padiStyle => 'PADI stilusu';

  @override
  String get enum_pdfTemplate_padiStyle_description =>
      'PADI naplo formatumnak megfelelo elrendezes';

  @override
  String get enum_pdfTemplate_professional => 'Professzionalis';

  @override
  String get enum_pdfTemplate_professional_description =>
      'Alairas es pecsethely az ellenorzeshez';

  @override
  String get enum_pdfTemplate_simple => 'Egyszeru';

  @override
  String get enum_pdfTemplate_simple_description =>
      'Tomor tablazatos formatum, sok merules oldalankent';

  @override
  String get enum_profileEvent_alert => 'Riasztas';

  @override
  String get enum_profileEvent_ascentRateCritical =>
      'Felszallasi sebesseg kritikus';

  @override
  String get enum_profileEvent_ascentRateWarning =>
      'Felszallasi sebesseg figyelmeztetés';

  @override
  String get enum_profileEvent_ascentStart => 'Felszallas kezdete';

  @override
  String get enum_profileEvent_bookmark => 'Konyvjelzo';

  @override
  String get enum_profileEvent_cnsCritical => 'CNS kritikus';

  @override
  String get enum_profileEvent_cnsWarning => 'CNS figyelmeztetés';

  @override
  String get enum_profileEvent_decoStopEnd => 'Deko megallo vege';

  @override
  String get enum_profileEvent_decoStopStart => 'Deko megallo kezdete';

  @override
  String get enum_profileEvent_decoViolation => 'Deko megszeges';

  @override
  String get enum_profileEvent_gasSwitch => 'Gazcsereles';

  @override
  String get enum_profileEvent_lowGas => 'Alacsony gaz figyelmeztetés';

  @override
  String get enum_profileEvent_maxDepth => 'Max melyseg';

  @override
  String get enum_profileEvent_missedStop => 'Kihagyott deko megallo';

  @override
  String get enum_profileEvent_note => 'Jegyzet';

  @override
  String get enum_profileEvent_ppO2High => 'Magas ppO2';

  @override
  String get enum_profileEvent_ppO2Low => 'Alacsony ppO2';

  @override
  String get enum_profileEvent_safetyStopEnd => 'Biztonsagi megallas vege';

  @override
  String get enum_profileEvent_safetyStopStart => 'Biztonsagi megallas kezdete';

  @override
  String get enum_profileEvent_setpointChange => 'Setpoint valtozas';

  @override
  String get enum_profileMetricCategory_decompression => 'Dekompresszio';

  @override
  String get enum_profileMetricCategory_gasAnalysis => 'Gazelemzes';

  @override
  String get enum_profileMetricCategory_gradientFactor => 'Gradiens faktorok';

  @override
  String get enum_profileMetricCategory_other => 'Egyeb';

  @override
  String get enum_profileMetricCategory_primary => 'Elsodleges mutatók';

  @override
  String get enum_profileMetric_gasDensity => 'Gaz suruseg';

  @override
  String get enum_profileMetric_gasDensity_short => 'Suruseg';

  @override
  String get enum_profileMetric_gf => 'GF%';

  @override
  String get enum_profileMetric_gf_short => 'GF%';

  @override
  String get enum_profileMetric_heartRate => 'Pulzus';

  @override
  String get enum_profileMetric_heartRate_short => 'Pulzus';

  @override
  String get enum_profileMetric_meanDepth => 'Atlag melyseg';

  @override
  String get enum_profileMetric_meanDepth_short => 'Atlag';

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
  String get enum_profileMetric_pressure => 'Nyomas';

  @override
  String get enum_profileMetric_pressure_short => 'Nyom';

  @override
  String get enum_profileMetric_sacRate => 'SAC ertek';

  @override
  String get enum_profileMetric_sacRate_short => 'SAC';

  @override
  String get enum_profileMetric_surfaceGf => 'Felszini GF';

  @override
  String get enum_profileMetric_surfaceGf_short => 'FelszGF';

  @override
  String get enum_profileMetric_temperature => 'Homerseklet';

  @override
  String get enum_profileMetric_temperature_short => 'Hom';

  @override
  String get enum_profileMetric_tts => 'TTS';

  @override
  String get enum_profileMetric_tts_short => 'TTS';

  @override
  String get enum_scrType_cmf => 'Allando tomegaram';

  @override
  String get enum_scrType_cmf_short => 'CMF';

  @override
  String get enum_scrType_escr => 'Elektronikusan szabalyozott';

  @override
  String get enum_scrType_escr_short => 'ESCR';

  @override
  String get enum_scrType_pascr => 'Passziv adagolas';

  @override
  String get enum_scrType_pascr_short => 'PASCR';

  @override
  String get enum_serviceType_annual => 'Eves szerviz';

  @override
  String get enum_serviceType_calibration => 'Kalibralas';

  @override
  String get enum_serviceType_cleaning => 'Tisztitas';

  @override
  String get enum_serviceType_inspection => 'Ellenorzes';

  @override
  String get enum_serviceType_other => 'Egyeb';

  @override
  String get enum_serviceType_overhaul => 'Nagyjavitas';

  @override
  String get enum_serviceType_recall => 'Visszahivas/Biztonsag';

  @override
  String get enum_serviceType_repair => 'Javitas';

  @override
  String get enum_serviceType_replacement => 'Alkatresz csere';

  @override
  String get enum_serviceType_warranty => 'Garancialis szerviz';

  @override
  String get enum_sortDirection_ascending => 'Novekvo';

  @override
  String get enum_sortDirection_descending => 'Csokkeno';

  @override
  String get enum_sortField_agency => 'Szervezet';

  @override
  String get enum_sortField_date => 'Datum';

  @override
  String get enum_sortField_dateIssued => 'Kiallitas datuma';

  @override
  String get enum_sortField_dateTaken => 'Készítés dátuma';

  @override
  String get enum_sortField_difficulty => 'Nehezsegi szint';

  @override
  String get enum_sortField_diveCount => 'Merulesszam';

  @override
  String get enum_sortField_diveNumber => 'Merules szama';

  @override
  String get enum_sortField_duration => 'Idotartam';

  @override
  String get enum_sortField_endDate => 'Zaras datuma';

  @override
  String get enum_sortField_fileName => 'Fájlnév';

  @override
  String get enum_sortField_fileSize => 'Fájlméret';

  @override
  String get enum_sortField_lastServiceDate => 'Utolso szerviz';

  @override
  String get enum_sortField_maxDepth => 'Max melyseg';

  @override
  String get enum_sortField_name => 'Nev';

  @override
  String get enum_sortField_purchaseDate => 'Vasarlas datuma';

  @override
  String get enum_sortField_rating => 'Ertekeles';

  @override
  String get enum_sortField_site => 'Merulohely';

  @override
  String get enum_sortField_startDate => 'Kezdes datuma';

  @override
  String get enum_sortField_status => 'Allapot';

  @override
  String get enum_sortField_type => 'Tipus';

  @override
  String get enum_speciesCategory_coral => 'Korall';

  @override
  String get enum_speciesCategory_fish => 'Hal';

  @override
  String get enum_speciesCategory_invertebrate => 'Gerinctelen';

  @override
  String get enum_speciesCategory_mammal => 'Emlos';

  @override
  String get enum_speciesCategory_other => 'Egyeb';

  @override
  String get enum_speciesCategory_plant => 'Noveny/Alga';

  @override
  String get enum_speciesCategory_ray => 'Raja';

  @override
  String get enum_speciesCategory_shark => 'Capa';

  @override
  String get enum_speciesCategory_turtle => 'Teknosbeka';

  @override
  String get enum_tankMaterial_aluminum => 'Aluminium';

  @override
  String get enum_tankMaterial_carbonFiber => 'Szenalas';

  @override
  String get enum_tankMaterial_steel => 'Acel';

  @override
  String get enum_tankRole_backGas => 'Fo gaz';

  @override
  String get enum_tankRole_bailout => 'Bailout';

  @override
  String get enum_tankRole_deco => 'Deko';

  @override
  String get enum_tankRole_diluent => 'Higigaz';

  @override
  String get enum_tankRole_oxygenSupply => 'O₂ ellatas';

  @override
  String get enum_tankRole_pony => 'Pony palack';

  @override
  String get enum_tankRole_sidemountLeft => 'Sidemount bal';

  @override
  String get enum_tankRole_sidemountRight => 'Sidemount jobb';

  @override
  String get enum_tankRole_stage => 'Stage';

  @override
  String get enum_visibility_excellent => 'Kituno (>30m / >100ft)';

  @override
  String get enum_visibility_good => 'Jo (15-30m / 50-100ft)';

  @override
  String get enum_visibility_moderate => 'Kozepes (5-15m / 15-50ft)';

  @override
  String get enum_visibility_poor => 'Gyenge (<5m / <15ft)';

  @override
  String get enum_visibility_unknown => 'Ismeretlen';

  @override
  String get enum_waterType_brackish => 'Felsos';

  @override
  String get enum_waterType_fresh => 'Edesviz';

  @override
  String get enum_waterType_salt => 'Sosviz';

  @override
  String get enum_weightType_ankleWeights => 'Boka sulyok';

  @override
  String get enum_weightType_backplate => 'Hatlap sulyok';

  @override
  String get enum_weightType_belt => 'Sulyoev';

  @override
  String get enum_weightType_integrated => 'Beepitett sulyok';

  @override
  String get enum_weightType_mixed => 'Vegyes/Kombinalt';

  @override
  String get enum_weightType_trimWeights => 'Trim sulyok';

  @override
  String get equipment_appBar_title => 'Felszereles';

  @override
  String get equipment_deleteDialog_cancel => 'Megse';

  @override
  String get equipment_deleteDialog_confirm => 'Torles';

  @override
  String get equipment_deleteDialog_content =>
      'Biztosan torli ezt a felszerelest? Ez a muvelet nem vonhato vissza.';

  @override
  String get equipment_deleteDialog_title => 'Felszereles torlese';

  @override
  String get equipment_detail_brandLabel => 'Marka';

  @override
  String equipment_detail_daysOverdue(Object days) {
    return '$days napja lejartt';
  }

  @override
  String equipment_detail_daysUntilService(Object days) {
    return '$days nap a szerviz';
  }

  @override
  String get equipment_detail_detailsTitle => 'Reszletek';

  @override
  String equipment_detail_divesCountPlural(Object count) {
    return '$count merules';
  }

  @override
  String equipment_detail_divesCountSingular(Object count) {
    return '$count merules';
  }

  @override
  String get equipment_detail_divesLabel => 'Merulesek';

  @override
  String get equipment_detail_divesSemanticLabel =>
      'Merulesek megtekintese ezzel a felszerelessel';

  @override
  String equipment_detail_durationDays(Object days) {
    return '$days nap';
  }

  @override
  String equipment_detail_durationMonths(Object months) {
    return '$months honap';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralPlural(
    Object years,
    Object months,
  ) {
    return '$years ev, $months honap';
  }

  @override
  String equipment_detail_durationYearsMonthsPluralSingular(
    Object years,
    Object months,
  ) {
    return '$years ev, $months honap';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularPlural(
    Object years,
    Object months,
  ) {
    return '$years ev, $months honap';
  }

  @override
  String equipment_detail_durationYearsMonthsSingularSingular(
    Object years,
    Object months,
  ) {
    return '$years ev, $months honap';
  }

  @override
  String equipment_detail_durationYearsPlural(Object years) {
    return '$years ev';
  }

  @override
  String equipment_detail_durationYearsSingular(Object years) {
    return '$years ev';
  }

  @override
  String get equipment_detail_editTooltip => 'Felszereles szerkesztese';

  @override
  String get equipment_detail_editTooltipShort => 'Szerkesztes';

  @override
  String equipment_detail_errorMessage(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get equipment_detail_errorTitle => 'Hiba';

  @override
  String get equipment_detail_lastServiceLabel => 'Utolso szerviz';

  @override
  String get equipment_detail_loadingTitle => 'Betoltes...';

  @override
  String get equipment_detail_modelLabel => 'Modell';

  @override
  String get equipment_detail_nextServiceDueLabel =>
      'Kovetkezo szerviz esedekesseg';

  @override
  String get equipment_detail_notFoundMessage =>
      'Ez a felszereles mar nem letezik.';

  @override
  String get equipment_detail_notFoundTitle => 'Felszereles nem talalhato';

  @override
  String get equipment_detail_notesTitle => 'Megjegyzesek';

  @override
  String get equipment_detail_ownedForLabel => 'Birtoklasi ido';

  @override
  String get equipment_detail_purchaseDateLabel => 'Vasarlas datuma';

  @override
  String get equipment_detail_purchasePriceLabel => 'Vasarlasi ar';

  @override
  String get equipment_detail_retiredChip => 'Kivont';

  @override
  String get equipment_detail_serialNumberLabel => 'Sorozatszam';

  @override
  String get equipment_detail_serviceInfoTitle => 'Szerviz informaciok';

  @override
  String get equipment_serviceClocks_title => 'Szervizintervallumok';

  @override
  String get equipment_serviceClocks_addClock => 'Intervallum hozzáadása';

  @override
  String get equipment_serviceClocks_logService => 'Szerviz rögzítése';

  @override
  String get equipment_serviceClocks_edit => 'Intervallumok szerkesztése';

  @override
  String get equipment_serviceClocks_pause => 'Szüneteltetés';

  @override
  String get equipment_serviceClocks_resume => 'Folytatás';

  @override
  String get equipment_serviceClocks_remove => 'Eltávolítás';

  @override
  String get equipment_serviceClocks_paused => 'Szüneteltetve';

  @override
  String get equipment_serviceClocks_empty => 'Nincsenek szervizintervallumok';

  @override
  String get equipment_serviceClocks_unconfigured =>
      'Nincs beállított időköz - koppintson a beállításhoz';

  @override
  String equipment_serviceClocks_dueOn(String date) {
    return 'Esedékes: $date';
  }

  @override
  String equipment_serviceClocks_overdueSince(String date) {
    return '$date óta esedékes';
  }

  @override
  String get equipment_serviceClocks_overdue => 'Lejárt';

  @override
  String equipment_serviceClocks_divesLeft(int remaining, int total) {
    return '$remaining / $total merülés van hátra';
  }

  @override
  String get cylinderConfigs_title => 'Palackkonfigurációk';

  @override
  String get cylinderConfigs_empty => 'Még nincs konfiguráció';

  @override
  String get cylinderConfigs_emptyBody =>
      'Mentsd el egyszer a diluent- és bailout-összeállítást, majd alkalmazd bármelyik merülésre.';

  @override
  String get cylinderConfigs_new => 'Új konfiguráció';

  @override
  String get cylinderConfigs_name => 'Név';

  @override
  String get cylinderConfigs_nameRequired => 'Adj meg egy nevet';

  @override
  String get cylinderConfigs_forUnit => 'Készülékhez';

  @override
  String get cylinderConfigs_noUnit => 'Általános gázterv';

  @override
  String get cylinderConfigs_gasPlans => 'Gáztervek';

  @override
  String get cylinderConfigs_addCylinder => 'Palack hozzáadása';

  @override
  String get cylinderConfigs_role => 'Szerep';

  @override
  String get cylinderConfigs_startPressure => 'Kezdőnyomás';

  @override
  String get cylinderConfigs_label => 'Címke';

  @override
  String get cylinderConfigs_fromPreset => 'Sablonból';

  @override
  String get cylinderConfigs_deleteTitle => 'Törlöd a konfigurációt?';

  @override
  String get cylinderConfigs_deleteBody =>
      'A már alkalmazott merülések nem változnak.';

  @override
  String get cylinderConfigs_applyAction => 'Konfiguráció alkalmazása';

  @override
  String cylinderConfigs_applyAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palack hozzáadva',
    );
    return '$_temp0';
  }

  @override
  String cylinderConfigs_applyKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count megtartva',
    );
    return '$_temp0';
  }

  @override
  String get cylinderConfigs_applyNothingToDo =>
      'Ez a merülés már megegyezik a konfigurációval';

  @override
  String get cylinderConfigs_sectionTitle => 'Konfigurációk';

  @override
  String get equipment_serviceClocks_hoursSource =>
      'A naplózott merülési idő alapján számolva';

  @override
  String equipment_serviceClocks_hoursLeft(String remaining, String total) {
    return '$remaining / $total óra van hátra';
  }

  @override
  String get equipment_serviceClocks_manageKinds => 'Szerviztípusok kezelése';

  @override
  String get equipment_serviceClocks_appliesToClock => 'Kapcsolódó intervallum';

  @override
  String get equipment_serviceClocks_noClockOption =>
      'Nem tartozik intervallumhoz';

  @override
  String get equipment_scheduleDialog_title => 'Intervallum szerkesztése';

  @override
  String get equipment_scheduleDialog_intervalDays => 'Intervallum (nap)';

  @override
  String get equipment_scheduleDialog_intervalDives => 'Intervallum (merülés)';

  @override
  String get equipment_scheduleDialog_intervalHours => 'Intervallum (óra)';

  @override
  String equipment_scheduleDialog_inheritHint(String value) {
    return 'Alapértelmezés: $value';
  }

  @override
  String get equipment_scheduleDialog_anchorDate => 'Kiindulási dátum';

  @override
  String get equipment_scheduleDialog_anchorHint =>
      'Akkor használjuk, ha még nincs ilyen típusú szervizbejegyzés';

  @override
  String get equipment_scheduleDialog_clearAnchor => 'Kiindulási dátum törlése';

  @override
  String get equipment_scheduleDialog_save => 'Mentés';

  @override
  String get equipment_scheduleDialog_cancel => 'Mégse';

  @override
  String get equipment_serviceKinds_title => 'Szerviztípusok';

  @override
  String get equipment_serviceKinds_builtIn => 'Beépített';

  @override
  String get equipment_serviceKinds_custom => 'Egyéni';

  @override
  String get equipment_serviceKinds_add => 'Szerviztípus hozzáadása';

  @override
  String get equipment_serviceKinds_editTitle => 'Szerviztípus szerkesztése';

  @override
  String get equipment_serviceKinds_nameLabel => 'Név';

  @override
  String get equipment_serviceKinds_nameRequired => 'A név megadása kötelező';

  @override
  String get equipment_serviceKinds_appliesTo => 'Vonatkozik erre';

  @override
  String get equipment_serviceKinds_autoAttach =>
      'Automatikus hozzáadás új felszereléshez';

  @override
  String get equipment_serviceKinds_deleteConfirmTitle =>
      'Törli a szerviztípust?';

  @override
  String get equipment_serviceKinds_deleteConfirmBody =>
      'Az ezt a szerviztípust használó intervallumok eltávolításra kerülnek.';

  @override
  String get equipment_serviceKinds_delete => 'Törlés';

  @override
  String get equipment_serviceKinds_cancel => 'Mégse';

  @override
  String get equipment_serviceKinds_save => 'Mentés';

  @override
  String get equipment_serviceKinds_emptyCustom =>
      'Még nincsenek egyéni szerviztípusok';

  @override
  String equipment_serviceKinds_everyDays(int days) {
    return '$days naponta';
  }

  @override
  String equipment_serviceKinds_everyDives(int dives) {
    return '$dives merülésenként';
  }

  @override
  String equipment_serviceKinds_everyHours(String hours) {
    return '$hours óránként';
  }

  @override
  String get dashboard_serviceDue_title => 'Esedékes szerviz';

  @override
  String dashboard_serviceDue_more(int count) {
    return '+$count további';
  }

  @override
  String dashboard_alerts_clockDue(String name, String kind) {
    return '$name: $kind esedékes';
  }

  @override
  String dashboard_alerts_clockOverdue(String name, String kind) {
    return '$name: $kind lejárt';
  }

  @override
  String equipment_list_worstClock(String kind) {
    return '$kind lejárt';
  }

  @override
  String trips_serviceAlert_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count felszerelés szervizt igényel az utazás előtt',
      one: '1 felszerelés szervizt igényel az utazás előtt',
    );
    return '$_temp0';
  }

  @override
  String trips_serviceAlert_dueBefore(String kind, String date) {
    return '$kind esedékes: $date';
  }

  @override
  String trips_serviceAlert_overdue(String kind) {
    return '$kind lejárt';
  }

  @override
  String get settings_notifications_tripLeadTitle =>
      'Utazás előtti szervizértesítési idő';

  @override
  String settings_notifications_tripLeadDays(int days) {
    return '$days nappal az utazás előtt';
  }

  @override
  String get equipment_detail_serviceIntervalLabel => 'Szerviz intervallum';

  @override
  String equipment_detail_serviceIntervalValue(Object days) {
    return '$days nap';
  }

  @override
  String get equipment_detail_serviceOverdue => 'A szerviz lejartt!';

  @override
  String get equipment_detail_sizeLabel => 'Meret';

  @override
  String get equipment_detail_thicknessLabel => 'Vastagság';

  @override
  String get equipment_detail_statusLabel => 'Allapot';

  @override
  String equipment_detail_tripsCountPlural(Object count) {
    return '$count utazas';
  }

  @override
  String equipment_detail_tripsCountSingular(Object count) {
    return '$count utazas';
  }

  @override
  String get equipment_detail_tripsLabel => 'Utazasok';

  @override
  String get equipment_detail_tripsSemanticLabel =>
      'Utazasok megtekintese ezzel a felszerelessel';

  @override
  String get equipment_edit_appBar_editTitle => 'Felszereles szerkesztese';

  @override
  String get equipment_edit_appBar_newTitle => 'Uj felszereles';

  @override
  String get equipment_edit_appBar_saveButton => 'Mentes';

  @override
  String get equipment_edit_appBar_saveTooltip =>
      'Felszereles valtozasainak mentese';

  @override
  String get equipment_edit_brandLabel => 'Marka';

  @override
  String get equipment_edit_clearDate => 'Datum torlese';

  @override
  String get equipment_edit_currencyLabel => 'Penznem';

  @override
  String get equipment_edit_disableReminders => 'Emlekeztetsek kikapcsolasa';

  @override
  String get equipment_edit_disableRemindersSubtitle =>
      'Osszes ertesites kikapcsolasa ehhez az elemhez';

  @override
  String get equipment_edit_discardDialog_content =>
      'Mentetlen valtozasai vannak. Biztosan el akar tavozni?';

  @override
  String get equipment_edit_discardDialog_discard => 'Eldobas';

  @override
  String get equipment_edit_discardDialog_keepEditing =>
      'Szerkesztes folytatasa';

  @override
  String get equipment_edit_discardDialog_title => 'Valtozasok eldobasa?';

  @override
  String get equipment_edit_embeddedHeader_cancelButton => 'Megse';

  @override
  String get equipment_edit_embeddedHeader_editTitle =>
      'Felszereles szerkesztese';

  @override
  String get equipment_edit_embeddedHeader_newTitle => 'Uj felszereles';

  @override
  String get equipment_edit_embeddedHeader_saveButton => 'Mentes';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_edit =>
      'Felszereles valtozasainak mentese';

  @override
  String get equipment_edit_embeddedHeader_saveTooltip_new =>
      'Uj felszereles hozzaadasa';

  @override
  String equipment_edit_errorMessage(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get equipment_edit_errorTitle => 'Hiba';

  @override
  String get equipment_edit_lastServiceDateLabel => 'Utolso szerviz datuma';

  @override
  String get equipment_edit_loadingTitle => 'Betoltes...';

  @override
  String get equipment_edit_modelLabel => 'Modell';

  @override
  String get equipment_edit_nameHint => 'pl. Elsodleges automata';

  @override
  String get equipment_edit_nameLabel => 'Nev *';

  @override
  String get equipment_edit_nameValidation => 'Kerem adjon meg egy nevet';

  @override
  String get equipment_edit_notFoundMessage =>
      'Ez a felszereles mar nem letezik.';

  @override
  String get equipment_edit_notFoundTitle => 'Felszereles nem talalhato';

  @override
  String get equipment_edit_notesHint =>
      'Tovabbi megjegyzesek a felszerelesrol...';

  @override
  String get equipment_edit_notesLabel => 'Megjegyzesek';

  @override
  String get equipment_edit_notificationsSubtitle =>
      'Globalis ertesitesi beallitasok felulbiralasa ehhez az elemhez';

  @override
  String get equipment_edit_notificationsTitle => 'Ertesitesek (opcionalis)';

  @override
  String get equipment_edit_purchaseDateLabel => 'Vasarlas datuma';

  @override
  String get equipment_edit_purchaseInfoTitle => 'Vasarlasi informaciok';

  @override
  String get equipment_edit_purchasePriceLabel => 'Vasarlasi ar';

  @override
  String get equipment_edit_purchasePriceValidation =>
      'Adjon meg ervenyes osszeget';

  @override
  String get equipment_edit_remindMeBeforeServiceDue =>
      'Emlekeztetss a szerviz esedekesseg elott:';

  @override
  String equipment_edit_reminderDays(Object days) {
    return '$days nap';
  }

  @override
  String get equipment_edit_saveButton_edit => 'Valtozasok mentese';

  @override
  String get equipment_edit_saveButton_new => 'Felszereles hozzaadasa';

  @override
  String get equipment_edit_saveTooltip_edit =>
      'Felszereles valtozasainak mentese';

  @override
  String get equipment_edit_saveTooltip_new => 'Uj felszereles hozzaadasa';

  @override
  String get equipment_edit_selectDate => 'Datum kivalasztasa';

  @override
  String get equipment_edit_serialNumberLabel => 'Sorozatszam';

  @override
  String get equipment_edit_serviceIntervalHint => 'pl. 365 az eves szervizhez';

  @override
  String get equipment_edit_serviceIntervalLabel => 'Szerviz intervallum (nap)';

  @override
  String get equipment_edit_serviceSettingsTitle => 'Szerviz beallitasok';

  @override
  String get equipment_edit_sizeHint => 'pl. M, L, 42';

  @override
  String get equipment_edit_sizeLabel => 'Meret';

  @override
  String get equipment_edit_snackbar_added => 'Felszereles hozzaadva';

  @override
  String equipment_edit_snackbar_error(Object error) {
    return 'Hiba a felszereles mentesekor: $error';
  }

  @override
  String get equipment_edit_snackbar_updated => 'Felszereles frissitve';

  @override
  String get equipment_edit_statusLabel => 'Allapot';

  @override
  String get equipment_edit_thicknessDesignationHint => 'pl. 5, 5/4, 7/5/3';

  @override
  String get equipment_edit_thicknessHint => 'pl. 5mm, 7mm';

  @override
  String get equipment_edit_thicknessLabel => 'Vastagság';

  @override
  String get equipment_edit_typeLabel => 'Tipus *';

  @override
  String get equipment_edit_useCustomReminders =>
      'Egyedi emlekeztetsek hasznalata';

  @override
  String get equipment_edit_useCustomRemindersSubtitle =>
      'Eltero emlekeztetesi napok beallitasa ehhez az elemhez';

  @override
  String get equipment_fab_addEquipment => 'Felszereles hozzaadasa';

  @override
  String get equipment_fab_addSet => 'Készlet hozzáadása';

  @override
  String get equipment_list_emptyState_addFirstButton =>
      'Elso felszereles hozzaadasa';

  @override
  String get equipment_list_emptyState_addPrompt =>
      'Adja hozza buvarfelszereleset a hasznalat es szerviz koveTesehez';

  @override
  String get equipment_list_emptyState_filterText_equipment => 'felszereles';

  @override
  String get equipment_list_emptyState_filterText_serviceDue =>
      'szervizre szorulo felszereles';

  @override
  String equipment_list_emptyState_filterText_status(Object status) {
    return '$status felszereles';
  }

  @override
  String equipment_list_emptyState_noEquipment(Object filterText) {
    return 'Nincs $filterText';
  }

  @override
  String get equipment_list_emptyState_noStatusMatch =>
      'Nincs ilyen allapotu felszereles';

  @override
  String get equipment_list_emptyState_serviceDueUpToDate =>
      'Minden felszerelese naprakesz a szervizzel!';

  @override
  String equipment_list_errorLoading(Object error) {
    return 'Hiba a felszereles betoltesekor: $error';
  }

  @override
  String get equipment_list_filterAll => 'Osszes felszereles';

  @override
  String get equipment_list_filterLabel => 'Szuro:';

  @override
  String get equipment_list_filterServiceDue => 'Szerviz esedek';

  @override
  String get equipment_list_retryButton => 'Ujra';

  @override
  String get equipment_list_searchTooltip => 'Felszereles keresese';

  @override
  String get equipment_list_setsTooltip => 'Felszereles csoportok';

  @override
  String get equipment_list_sortTitle => 'Felszereles rendezese';

  @override
  String get equipment_list_sortTooltip => 'Rendezes';

  @override
  String equipment_list_tile_daysCount(Object days) {
    return '$days nap';
  }

  @override
  String equipment_list_tile_serviceInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Szerviz $days nap',
      one: 'Szerviz 1 nap',
    );
    return '$_temp0';
  }

  @override
  String get equipment_list_tile_serviceDueChip => 'Szerviz esedek';

  @override
  String get equipment_list_tile_serviceIn => 'Szerviz';

  @override
  String get equipment_menu_delete => 'Torles';

  @override
  String get equipment_menu_markAsServiced => 'Megjeloles szervizeltkentt';

  @override
  String get equipment_menu_reactivate => 'Ujraaktivalas';

  @override
  String get equipment_menu_retireEquipment => 'Felszereles kivonas';

  @override
  String get equipment_search_backTooltip => 'Vissza';

  @override
  String get equipment_search_clearTooltip => 'Kereses torlese';

  @override
  String get equipment_search_fieldLabel => 'Felszereles keresese...';

  @override
  String get equipment_search_hint =>
      'Kereses nev, marka, modell vagy sorozatszam alapjan';

  @override
  String equipment_search_noResults(Object query) {
    return 'Nem talalhato felszereles \"$query\" keresesi kifejezesre';
  }

  @override
  String get equipment_serviceDialog_addButton => 'Hozzaadas';

  @override
  String get equipment_serviceDialog_addTitle => 'Szervizrekord hozzaadasa';

  @override
  String get equipment_serviceDialog_cancelButton => 'Megse';

  @override
  String get equipment_serviceDialog_clearNextServiceDateTooltip =>
      'Kovetkezo szerviz datum torlese';

  @override
  String get equipment_serviceDialog_costHint => '0.00';

  @override
  String get equipment_serviceDialog_costLabel => 'Koltseg';

  @override
  String get equipment_serviceDialog_currencyLabel => 'Penznem';

  @override
  String get equipment_serviceDialog_costValidation =>
      'Adjon meg ervenyes osszeget';

  @override
  String get equipment_serviceDialog_editTitle => 'Szervizrekord szerkesztese';

  @override
  String get equipment_serviceDialog_nextServiceDueLabel =>
      'Kovetkezo szerviz esedekesseg';

  @override
  String get equipment_serviceDialog_nextServiceDueSemanticLabel =>
      'Kovetkezo szerviz datum kivalasztasa';

  @override
  String get equipment_serviceDialog_nextServiceNotSet => 'Nincs megadva';

  @override
  String get equipment_serviceDialog_notesLabel => 'Megjegyzesek';

  @override
  String get equipment_serviceDialog_providerHint => 'pl. Buvaruzlet neve';

  @override
  String get equipment_serviceDialog_providerLabel => 'Szolgaltato/Uzlet';

  @override
  String get equipment_serviceDialog_serviceDateLabel => 'Szerviz datuma';

  @override
  String get equipment_serviceDialog_serviceDateSemanticLabel =>
      'Szerviz datum kivalasztasa';

  @override
  String get equipment_serviceDialog_serviceTypeLabel => 'Szerviz típus';

  @override
  String get equipment_serviceDialog_serviceTypeHelper =>
      'A rögzítés nullázza ennek a szerviz típusnak az óráját';

  @override
  String get equipment_serviceDialog_serviceTypeRequired =>
      'Válassz szerviz típust';

  @override
  String get equipment_serviceDialog_serviceTypeNotSet => 'Nincs beállítva';

  @override
  String get equipment_serviceDialog_categoryHelper =>
      'Szűréshez és exportáláshoz használt';

  @override
  String get equipment_serviceDialog_manageServiceTypes =>
      'Szerviz típusok kezelése';

  @override
  String get equipment_serviceDialog_categoryLabel => 'Kategória';

  @override
  String get equipment_serviceDialog_snackbar_added =>
      'Szervizrekord hozzaadva';

  @override
  String equipment_serviceDialog_snackbar_error(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get equipment_serviceDialog_snackbar_updated =>
      'Szervizrekord frissitve';

  @override
  String get equipment_serviceDialog_updateButton => 'Frissites';

  @override
  String get equipment_serviceCategory_annual => 'Éves szerviz';

  @override
  String get equipment_serviceCategory_repair => 'Javítás';

  @override
  String get equipment_serviceCategory_inspection => 'Ellenőrzés';

  @override
  String get equipment_serviceCategory_overhaul => 'Nagyjavítás';

  @override
  String get equipment_serviceCategory_replacement => 'Alkatrészcsere';

  @override
  String get equipment_serviceCategory_cleaning => 'Tisztítás';

  @override
  String get equipment_serviceCategory_calibration => 'Kalibrálás';

  @override
  String get equipment_serviceCategory_warranty => 'Garanciális szerviz';

  @override
  String get equipment_serviceCategory_recall => 'Visszahívás/Biztonság';

  @override
  String get equipment_serviceCategory_other => 'Egyéb';

  @override
  String get equipment_service_addButton => 'Hozzaadas';

  @override
  String get equipment_service_deleteDialog_cancel => 'Megse';

  @override
  String get equipment_service_deleteDialog_confirm => 'Torles';

  @override
  String equipment_service_deleteDialog_content(Object serviceType) {
    return 'Biztosan torli ezt a(z) $serviceType rekordot?';
  }

  @override
  String get equipment_service_deleteDialog_title => 'Szervizrekord torlese?';

  @override
  String get equipment_service_deleteMenuItem => 'Torles';

  @override
  String get equipment_service_editMenuItem => 'Szerkesztes';

  @override
  String get equipment_service_emptyState => 'Meg nincsenek szervizrekordok';

  @override
  String get equipment_service_historyTitle => 'Szerviz elozmeny';

  @override
  String equipment_service_nextDueLabel(String date) {
    return 'Következő esedékesség $date';
  }

  @override
  String get equipment_service_filterTaskAll => 'Minden feladat';

  @override
  String get equipment_service_filterTypeAll => 'Minden típus';

  @override
  String get equipment_service_filterYearAll => 'Minden év';

  @override
  String get equipment_service_filterUntagged => 'Nincs intervallumhoz kötve';

  @override
  String get equipment_service_filterClear => 'Szűrő törlése';

  @override
  String get equipment_service_filterNoMatches =>
      'Nincs a szűrőnek megfelelő karbantartás';

  @override
  String equipment_service_filterMatchCount(int count, int total) {
    return '$count / $total megjelenítve';
  }

  @override
  String get equipment_serviceKinds_defaultCategoryLabel =>
      'Alapértelmezett kategória';

  @override
  String get equipment_serviceKinds_defaultCategoryNone =>
      'Nincs alapértelmezés';

  @override
  String get equipment_serviceKinds_defaultCostLabel => 'Alapértelmezett ár';

  @override
  String get equipment_serviceKinds_defaultCostHint =>
      'Hagyja üresen, ha nincs alapértelmezés';

  @override
  String get equipment_scheduleDialog_defaultCostLabel =>
      'Alapértelmezett ár ehhez a felszereléshez';

  @override
  String get equipment_serviceKinds_defaultCurrencyLabel => 'Pénznem';

  @override
  String get equipment_service_exportMenuItem =>
      'Karbantartási napló exportálása';

  @override
  String get transfer_export_maintenanceTitle => 'Karbantartási napló';

  @override
  String get transfer_export_maintenanceSubtitle =>
      'A teljes felszerelés szerviztörténete táblázatként';

  @override
  String get settings_export_progress_maintenance =>
      'Karbantartási napló exportálása...';

  @override
  String get settings_export_success_maintenance =>
      'Karbantartási napló exportálva';

  @override
  String get settings_export_saved_maintenance => 'Karbantartási napló mentve';

  @override
  String get equipment_serviceKinds_defaultCurrencyInherit =>
      'Alapértelmezett pénznem használata';

  @override
  String get equipment_scheduleDialog_defaultCurrencyLabel =>
      'Pénznem ehhez a felszereléshez';

  @override
  String get equipment_service_snackbar_deleted => 'Szervizrekord torolve';

  @override
  String get equipment_service_totalCostLabel => 'Osszes szerviz koltseg';

  @override
  String get equipment_setDetail_addEquipmentButton => 'Felszereles hozzaadasa';

  @override
  String get equipment_setDetail_deleteDialog_cancel => 'Megse';

  @override
  String get equipment_setDetail_deleteDialog_confirm => 'Torles';

  @override
  String get equipment_setDetail_deleteDialog_content =>
      'Biztosan torli ezt a felszereles csoportot? A csoportban levo felszerelesek nem lesznek torolve.';

  @override
  String get equipment_setDetail_deleteDialog_title =>
      'Felszereles csoport torlese';

  @override
  String get equipment_setDetail_deleteMenuItem => 'Torles';

  @override
  String get equipment_setDetail_editTooltip => 'Csoport szerkesztese';

  @override
  String get equipment_setDetail_emptySet =>
      'Nincs felszereles ebben a csoportban';

  @override
  String get equipment_setDetail_equipmentInSetTitle =>
      'Felszerelesek ebben a csoportban';

  @override
  String equipment_setDetail_errorMessage(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get equipment_setDetail_errorTitle => 'Hiba';

  @override
  String get equipment_setDetail_loadingTitle => 'Betoltes...';

  @override
  String get equipment_setDetail_notFoundMessage =>
      'Ez a felszereles csoport mar nem letezik.';

  @override
  String get equipment_setDetail_notFoundTitle => 'Csoport nem talalhato';

  @override
  String get equipment_setDetail_snackbar_deleted =>
      'Felszereles csoport torolve';

  @override
  String get equipment_setEdit_addEquipmentFirst =>
      'Elobb adjon hozza felszerelest a csoport letrehozasa elott.';

  @override
  String get equipment_setEdit_appBar_editTitle => 'Csoport szerkesztese';

  @override
  String get equipment_setEdit_appBar_newTitle => 'Uj felszereles csoport';

  @override
  String get equipment_setEdit_descriptionHint => 'Opcionalis leiras...';

  @override
  String get equipment_setEdit_descriptionLabel => 'Leiras';

  @override
  String equipment_setEdit_errorMessage(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get equipment_setEdit_errorTitle => 'Hiba';

  @override
  String get equipment_setEdit_loadingTitle => 'Betoltes...';

  @override
  String get equipment_setEdit_nameHint => 'pl. Meleg vizi felszereles';

  @override
  String get equipment_setEdit_nameLabel => 'Csoport neve *';

  @override
  String get equipment_setEdit_nameValidation => 'Kerem adjon meg egy nevet';

  @override
  String get equipment_setEdit_noEquipmentAvailable =>
      'Nem erheto el felszereles';

  @override
  String get equipment_setEdit_notFoundMessage =>
      'Ez a felszereles csoport mar nem letezik.';

  @override
  String get equipment_setEdit_notFoundTitle => 'Csoport nem talalhato';

  @override
  String get equipment_setEdit_saveButton_edit => 'Valtozasok mentese';

  @override
  String get equipment_setEdit_saveButton_new => 'Csoport letrehozasa';

  @override
  String get equipment_setEdit_saveTooltip_edit =>
      'Felszereles csoport valtozasainak mentese';

  @override
  String get equipment_setEdit_saveTooltip_new =>
      'Uj felszereles csoport letrehozasa';

  @override
  String get equipment_setEdit_selectEquipmentSubtitle =>
      'Valassza ki a csoportba felveendo felszereleseket.';

  @override
  String get equipment_setEdit_selectEquipmentTitle =>
      'Felszereles kivalasztasa';

  @override
  String get equipment_setEdit_snackbar_created =>
      'Felszereles csoport letrehozva';

  @override
  String equipment_setEdit_snackbar_error(Object error) {
    return 'Hiba a felszereles csoport mentesekor: $error';
  }

  @override
  String get equipment_setEdit_snackbar_updated =>
      'Felszereles csoport frissitve';

  @override
  String get equipment_sets_appBar_title => 'Felszereles csoportok';

  @override
  String get equipment_sets_emptyState_createFirstButton =>
      'Elso csoport letrehozasa';

  @override
  String get equipment_sets_emptyState_description =>
      'Hozzon letre felszereles csoportokat, hogy gyorsan hozzaadhassa a gyakran hasznalt felszereleseket a meruleseihez.';

  @override
  String get equipment_sets_emptyState_title =>
      'Nincsenek felszereles csoportok';

  @override
  String equipment_sets_errorLoading(Object error) {
    return 'Hiba a csoportok betoltesekor: $error';
  }

  @override
  String get equipment_sets_fabTooltip => 'Uj felszereles csoport letrehozasa';

  @override
  String get equipment_sets_fab_createSet => 'Csoport letrehozasa';

  @override
  String equipment_sets_itemCountPlural(Object count) {
    return '$count elem';
  }

  @override
  String equipment_sets_itemCountSemanticLabel(Object count) {
    return '$count a csoportban';
  }

  @override
  String equipment_sets_itemCountSingular(Object count) {
    return '$count elem';
  }

  @override
  String get equipment_sets_retryButton => 'Ujra';

  @override
  String get equipment_snackbar_deleted => 'Felszereles torolve';

  @override
  String get equipment_snackbar_markedAsServiced => 'Szervizeltnek jelolve';

  @override
  String get equipment_snackbar_reactivated => 'Felszereles ujraaktivalva';

  @override
  String get equipment_snackbar_retired => 'Felszereles kivonva';

  @override
  String get equipment_summary_active => 'Aktiv';

  @override
  String get equipment_summary_addEquipmentButton => 'Felszereles hozzaadasa';

  @override
  String get equipment_summary_equipmentSetsButton => 'Felszereles csoportok';

  @override
  String get equipment_summary_overviewTitle => 'Attekintes';

  @override
  String get equipment_summary_quickActionsTitle => 'Gyorsmuveletek';

  @override
  String get equipment_summary_recentEquipmentTitle => 'Legutobbl felszereles';

  @override
  String equipment_summary_recentSemanticLabel(Object name, Object type) {
    return '$name, $type';
  }

  @override
  String get equipment_summary_selectPrompt =>
      'Valasszon felszerelest a listabol a reszletek megtekIntesehez';

  @override
  String get equipment_summary_serviceDue => 'Szerviz esedek';

  @override
  String equipment_summary_serviceDueSemanticLabel(Object name, Object type) {
    return '$name, $type, szerviz esedek';
  }

  @override
  String get equipment_summary_serviceDueTitle => 'Szerviz esedek';

  @override
  String get equipment_summary_title => 'Felszereles';

  @override
  String get equipment_summary_totalItems => 'Osszes elem';

  @override
  String get equipment_summary_totalValue => 'Osszes ertek';

  @override
  String get equipment_tab_equipment => 'Felszerelés';

  @override
  String get equipment_tab_sets => 'Készletek';

  @override
  String get formatter_approximate_prefix => '~';

  @override
  String get formatter_connector_at => 'helyen';

  @override
  String get formatter_connector_from => 'Ettol';

  @override
  String get formatter_connector_until => 'Eddig';

  @override
  String get gas_air_description => 'Standard levego (21% O2)';

  @override
  String get gas_air_displayName => 'Levego';

  @override
  String get gas_diluentAir_description =>
      'Standard levego higigaz sekely CCR-hez';

  @override
  String get gas_diluentAir_displayName => 'Levego higigaz';

  @override
  String get gas_diluentTx1070_description =>
      'Hipoxikus higigaz nagyon mely CCR-hez';

  @override
  String get gas_diluentTx1070_displayName => 'Tx 10/70';

  @override
  String get gas_diluentTx1260_description => 'Hipoxikus higigaz mely CCR-hez';

  @override
  String get gas_diluentTx1260_displayName => 'Tx 12/60';

  @override
  String get gas_ean32_description => 'Dusitott levego Nitrox 32%';

  @override
  String get gas_ean32_displayName => 'EAN32';

  @override
  String get gas_ean36_description => 'Dusitott levego Nitrox 36%';

  @override
  String get gas_ean36_displayName => 'EAN36';

  @override
  String get gas_ean40_description => 'Dusitott levego Nitrox 40%';

  @override
  String get gas_ean40_displayName => 'EAN40';

  @override
  String get gas_ean50_description => 'Deko gaz - 50% O2';

  @override
  String get gas_ean50_displayName => 'EAN50';

  @override
  String get gas_helitrox2525_description =>
      'Helitrox 25/25 (rekreaccios tech)';

  @override
  String get gas_helitrox2525_displayName => 'Helitrox 25/25';

  @override
  String get gas_oxygen_description => 'Tiszta oxigen (csak 6m deko)';

  @override
  String get gas_oxygen_displayName => 'Oxigen';

  @override
  String get gas_scrEan40_description => 'SCR torlogaz - 40% O2';

  @override
  String get gas_scrEan40_displayName => 'SCR EAN40';

  @override
  String get gas_scrEan50_description => 'SCR torlogaz - 50% O2';

  @override
  String get gas_scrEan50_displayName => 'SCR EAN50';

  @override
  String get gas_scrEan60_description => 'SCR torlogaz - 60% O2';

  @override
  String get gas_scrEan60_displayName => 'SCR EAN60';

  @override
  String get gas_tmx1555_description => 'Hipoxikus trimix 15/55 (nagyon mely)';

  @override
  String get gas_tmx1555_displayName => 'Tx 15/55';

  @override
  String get gas_tmx1845_description => 'Trimix 18/45 (melymerules)';

  @override
  String get gas_tmx1845_displayName => 'Tx 18/45';

  @override
  String get gas_tmx2135_description => 'Normoxikus trimix 21/35';

  @override
  String get gas_tmx2135_displayName => 'Tx 21/35';

  @override
  String get gasCalculators_bestMix_bestOxygenMix => 'Legjobb oxigén keverék';

  @override
  String get gasCalculators_bestMix_commonMixesRef =>
      'Általános keverékek referencia';

  @override
  String gasCalculators_bestMix_exceedsAirMod(Object ppO2) {
    return 'Levegő MOD túllépve ppO₂ $ppO2 mellett';
  }

  @override
  String get gasCalculators_bestMix_targetDepth => 'Célmélység';

  @override
  String get gasCalculators_bestMix_targetDive => 'Célmerülés';

  @override
  String gasCalculators_consumption_ambientPressure(
    Object depth,
    Object depthSymbol,
  ) {
    return 'Környezeti nyomás $depth$depthSymbol mélységben';
  }

  @override
  String get gasCalculators_consumption_avgDepth => 'Átlagos mélység';

  @override
  String get gasCalculators_consumption_breakdown => 'Számítás részletezése';

  @override
  String get gasCalculators_consumption_diveTime => 'Merülési idő';

  @override
  String gasCalculators_consumption_exceedsTank(
    Object pressure,
    Object symbol,
  ) {
    return 'Meghaladja a palack kapacitását ($pressure $symbol)';
  }

  @override
  String get gasCalculators_consumption_gasAtDepth =>
      'Gázfogyasztás mélységben';

  @override
  String get gasCalculators_consumption_pressure => 'Nyomás';

  @override
  String get gasCalculators_consumption_remainingGas => 'Maradék gáz';

  @override
  String gasCalculators_consumption_tankCapacity(
    Object tankSize,
    Object volumeSymbol,
    Object fillPressure,
    Object pressureSymbol,
  ) {
    return 'Palack kapacitás ($tankSize$volumeSymbol @ $fillPressure $pressureSymbol)';
  }

  @override
  String get gasCalculators_consumption_title => 'Gázfogyasztás';

  @override
  String gasCalculators_consumption_totalGas(Object time) {
    return 'Összes gáz $time percre';
  }

  @override
  String get gasCalculators_consumption_volume => 'Térfogat';

  @override
  String get gasCalculators_mod_aboutMod => 'A MOD-ról';

  @override
  String get gasCalculators_mod_aboutModBody =>
      'Alacsonyabb O₂ = mélyebb MOD = rövidebb NDL';

  @override
  String get gasCalculators_mod_inputParameters => 'Bemeneti paraméterek';

  @override
  String get gasCalculators_mod_maximumOperatingDepth =>
      'Maximum működési mélység';

  @override
  String get gasCalculators_mod_oxygenO2 => 'Oxigén (O₂)';

  @override
  String get gasCalculators_mod_ppO2Conservative =>
      'Konzervatív limit hosszabb fenék időhöz';

  @override
  String get gasCalculators_mod_ppO2Maximum =>
      'Maximum limit csak dekompressziós megállókhoz';

  @override
  String get gasCalculators_mod_ppO2Standard =>
      'Standard munkálati limit szabadidős merüléshez';

  @override
  String get gasCalculators_mnd_depthInput => 'Mélység';

  @override
  String get gasCalculators_mnd_endAtDepthTitle => 'END adott mélységben';

  @override
  String get gasCalculators_mnd_endLimit => 'END határ';

  @override
  String get gasCalculators_mnd_hePercent => 'He %';

  @override
  String get gasCalculators_mnd_infoContent =>
      'A Maximum Narkotikus Mélység (MND) az a legnagyobb mélység, ameddig a narkózis nem haladja meg az END határt. Az Ekvivalens Narkotikus Mélység (END) megmutatja a gázkeverék narkotikus hatását adott mélységben.\n\nHa az \'O2 narkotikus\' be van kapcsolva, az oxigén és a nitrogén egyaránt hozzájárul a narkózishoz (konzervatívabb). Ha ki van kapcsolva, csak a nitrogén számít narkotikusnak.';

  @override
  String get gasCalculators_mnd_infoTitle => 'MND/END névjegy';

  @override
  String get gasCalculators_mnd_unlimited => 'korlátlan';

  @override
  String get gasCalculators_mnd_inputParameters =>
      'Gázkeverék és narkózis beállítások';

  @override
  String get gasCalculators_mnd_o2Narcotic => 'O2 narkotikus';

  @override
  String get gasCalculators_mnd_o2Percent => 'O2 %';

  @override
  String get gasCalculators_mnd_resultTitle => 'Maximum Narkotikus Mélység';

  @override
  String get gasCalculators_ppO2Limit => 'ppO₂ limit';

  @override
  String get gasCalculators_resetAll => 'Összes kalkulátor visszaállítása';

  @override
  String get gasCalculators_sacRate => 'RMV';

  @override
  String get gasCalculators_tab_bestMix => 'Legjobb keverék';

  @override
  String get gasCalculators_tab_consumption => 'Fogyasztás';

  @override
  String get gasCalculators_tab_mnd => 'MND/END';

  @override
  String get gasCalculators_tab_blender => 'Trimix keverő';

  @override
  String get gasCalculators_blender_cylinder => 'Palack';

  @override
  String get gasCalculators_blender_startCylinder => 'A palackban';

  @override
  String get gasCalculators_blender_targetFill => 'Cél töltés';

  @override
  String get gasCalculators_blender_fillGases => 'Töltőgázok';

  @override
  String get gasCalculators_blender_pressure => 'Nyomás';

  @override
  String get gasCalculators_blender_o2 => 'O₂';

  @override
  String get gasCalculators_blender_he => 'He';

  @override
  String get gasCalculators_blender_air => 'Levegő';

  @override
  String get gasCalculators_blender_helium => 'Hélium';

  @override
  String get gasCalculators_blender_procedure => 'Töltési sorrend';

  @override
  String get gasCalculators_blender_amounts => 'Hozzáadandó gáz';

  @override
  String gasCalculators_blender_stepStart(String pressure, String gas) {
    return 'Kezdd $pressure $gas gázzal';
  }

  @override
  String gasCalculators_blender_stepFill(
    String gas,
    String pressure,
    String mix,
  ) {
    return 'Tölts $gas-t $pressure-ig → $mix';
  }

  @override
  String get gasCalculators_blender_error_targetPressure =>
      'A célnyomásnak magasabbnak kell lennie a kiindulási nyomásnál.';

  @override
  String get gasCalculators_blender_error_invalidMix =>
      'Egy keverék O₂ + He aránya nem haladhatja meg a 100%-ot.';

  @override
  String get gasCalculators_blender_error_identicalGases =>
      'A két töltőgáz azonos — nincs mit keverni.';

  @override
  String get gasCalculators_blender_error_linearlyDependent =>
      'Ezekkel a gázokkal a célkeverék nem állítható elő — a trimix célhoz héliumforrás kell.';

  @override
  String get gasCalculators_blender_error_negativeAmount =>
      'Ez a keverék ezekkel a gázokkal nem érhető el — gázt kellene eltávolítani.';

  @override
  String gasCalculators_blender_error_drainTo(String pressure) {
    return 'Túl sok gáz van a palackban ehhez a keverékhez. Előbb engedd le $pressure nyomásra, majd tölts.';
  }

  @override
  String get gasCalculators_blender_error_drainEmpty =>
      'A palackban lévő gáz nem használható ehhez a keverékhez. Előbb ürítsd ki teljesen, majd tölts.';

  @override
  String get gasCalculators_blender_error_cannotRemoveHelium =>
      'A palack héliumot tartalmaz, a célkeverék viszont nem. A rátöltés hígítja a héliumot, de nem távolítja el: a palackot előbb ki kell üríteni.';

  @override
  String get gasCalculators_blender_error_insufficientGases =>
      'A hélium nélküli célhoz két hélium nélküli töltőgáz kell, eltérő O₂-tartalommal.';

  @override
  String get gasCalculators_blender_error_targetNotReached =>
      'Ezekkel a töltőgázokkal a célkeverék nem érhető el pontosan. Ellenőrizd a töltőgázokat és a sorrendjüket.';

  @override
  String get gasCalculators_blender_error_implausibleStartMix =>
      'A palack nyomás alatt van, de sem oxigént, sem héliumot nem tartalmaz, ami tiszta nitrogén lenne. Ellenőrizd a palackban lévő keveréket.';

  @override
  String get gasCalculators_blender_about => 'A keverésről';

  @override
  String get gasCalculators_blender_aboutBody =>
      'Parciális nyomású keverés a cél keverékhez. Add hozzá a töltőgázokat sorrendben, a megadott nyomásig, majd hagyd a palackot kiegyenlítődni. A töltőgázok és a sorrendjük állítható: ha az utolsó gázt 32/0-ra állítod, levegő helyett EAN32-vel tölt fel. A kész keveréket mindig elemezd, mielőtt lemerülnél vele.';

  @override
  String get gasCalculators_blender_conditions => 'Keverési körülmények';

  @override
  String get gasCalculators_blender_fillTemp => 'Töltési hőmérséklet';

  @override
  String get gasCalculators_blender_fillTempHelp =>
      'A palack hőmérséklete töltés közben. A sorrend minden nyomásértéke az ezen a hőmérsékleten leolvasott manométerérték.';

  @override
  String get gasCalculators_blender_settledTemp => 'Kiegyenlített hőmérséklet';

  @override
  String get gasCalculators_blender_settledTempHelp =>
      'Az a hőmérséklet, amelyre a palack végül beáll. A célnyomás az az érték, amit ekkor mutat.';

  @override
  String get gasCalculators_blender_gasModel => 'Gázmodell';

  @override
  String get gasCalculators_blender_modelIdeal => 'Ideális gáz';

  @override
  String get gasCalculators_blender_modelVanDerWaals => 'Van der Waals';

  @override
  String get gasCalculators_blender_modelZFactor => 'Valós gáz (Z-tényező)';

  @override
  String get gasCalculators_blender_modelRecommended => 'Ajánlott';

  @override
  String get gasCalculators_blender_modelHelp =>
      'A valós gáz (Z-tényező) a legpontosabb palacknyomásokon. Az ideális gáz a legtöbb közzétett keverési táblázattal egyezik. A Van der Waals más keverőprogramokkal való összehasonlításhoz érhető el, és töltési nyomáson több százalékkal eltér.';

  @override
  String gasCalculators_blender_stepAdd(String gas) {
    return '$gas hozzáadása';
  }

  @override
  String get gasCalculators_blender_stepStartLabel => 'Kezdés';

  @override
  String gasCalculators_blender_settlesTo(String pressure, String temperature) {
    return '$temperature hőmérsékleten $pressure lesz';
  }

  @override
  String get gasCalculators_blender_templates => 'Sablonok';

  @override
  String get gasCalculators_blender_templatesTitle => 'Cél gázkeverék sablonok';

  @override
  String get gasCalculators_blender_saveTemplate => 'Aktuális keverék mentése';

  @override
  String get gasCalculators_blender_manageTemplates => 'Sablonok kezelése';

  @override
  String gasCalculators_blender_templateSaved(String mix) {
    return '$mix elmentve';
  }

  @override
  String get gasCalculators_blender_templateExists =>
      'Ez a keverék már mentve van.';

  @override
  String get gasCalculators_blender_templateInvalid =>
      'Az O₂ + He nem haladhatja meg a 100%-ot.';

  @override
  String get gasCalculators_blender_templateNeedsNumbers =>
      'Az O₂ és a He értékét is számként add meg.';

  @override
  String gasCalculators_blender_templateLimit(int count) {
    return 'Legfeljebb $count sablont menthetsz.';
  }

  @override
  String get gasCalculators_blender_templateNone =>
      'Még nincs sablon. Ments el egy cél keveréket, hogy itt újra használhasd.';

  @override
  String gasCalculators_blender_templateDelete(String mix) {
    return '$mix törlése';
  }

  @override
  String get gasCalculators_blender_templateAdd => 'Sablon hozzáadása';

  @override
  String get gasCalculators_blender_billing => 'Költség';

  @override
  String get gasCalculators_blender_cylinderVolume => 'A palack víztérfogata';

  @override
  String get gasCalculators_blender_cylinderPresets => 'Előbeállítások';

  @override
  String gasCalculators_blender_unitPrice(String unit) {
    return 'Ár 100 $unit egységenként';
  }

  @override
  String get gasCalculators_blender_currency => 'Pénznem';

  @override
  String get gasCalculators_blender_costTotal => 'Összesen';

  @override
  String get gasCalculators_blender_costBasis =>
      'A számlázás a betöltött nyomás alapján történik (palack víztérfogata × hozzáadott bar), ahogy a töltőállomás is méri.';

  @override
  String get gasCalculators_blender_costMissingPrice =>
      'Adj meg árat minden gázhoz, hogy lásd az összeget.';

  @override
  String get gasCalculators_blender_saveFill => 'Töltés mentése';

  @override
  String get gasCalculators_blender_billed => 'Számlázva';

  @override
  String get gasCalculators_blender_billedNone =>
      'Még nincs semmi számlázva. Fejezz be egy töltést, és mentsd ide.';

  @override
  String get gasCalculators_blender_billedTo => 'Számla címzettje';

  @override
  String get gasCalculators_blender_addManualLine => 'Tétel hozzáadása';

  @override
  String get gasCalculators_blender_lineDescription => 'Megnevezés';

  @override
  String get gasCalculators_blender_lineAmount => 'Összeg';

  @override
  String get gasCalculators_blender_clearBilled => 'Ürítés';

  @override
  String get gasCalculators_blender_clearBilledTitle => 'Üríted a számlát?';

  @override
  String gasCalculators_blender_clearBilledBody(int count) {
    return 'Ezzel mind a(z) $count mentett töltés törlődik.';
  }

  @override
  String gasCalculators_blender_editLine(String label) {
    return '$label szerkesztése';
  }

  @override
  String gasCalculators_blender_deleteLine(String label) {
    return '$label törlése';
  }

  @override
  String gasCalculators_blender_fillAdded(String mix) {
    return '$mix felkerült a számlára';
  }

  @override
  String get gasCalculators_blender_billedIncomplete =>
      'Legalább egy tételnek nincs ára, ezért az összeg hiányos.';

  @override
  String get gasCalculators_blender_billedTotal => 'Összesen';

  @override
  String get gasCalculators_tab_mod => 'MOD';

  @override
  String get gasCalculators_tab_rockBottom => 'Tartalék minimum';

  @override
  String get gasCalculators_tankSize => 'Palack méret';

  @override
  String get gasCalculators_title => 'Gáz kalkulátorok';

  @override
  String get marineLife_siteSection_editExpectedTooltip =>
      'Vart fajok szerkesztese';

  @override
  String get marineLife_siteSection_errorLoadingExpected =>
      'Hiba a vart fajok betoltesekor';

  @override
  String get marineLife_siteSection_errorLoadingSightings =>
      'Hiba az eszlelesek betoltesekor';

  @override
  String get marineLife_siteSection_expectedSpecies => 'Vart fajok';

  @override
  String get marineLife_siteSection_noExpected =>
      'Nincsenek vart fajok hozzaadva';

  @override
  String get marineLife_siteSection_noSpotted =>
      'Meg nem eszleltek tengeri elolenyt';

  @override
  String marineLife_siteSection_spottedCountSemantics(
    Object name,
    Object count,
  ) {
    return '$name, $count alkalommal észlelve';
  }

  @override
  String get marineLife_siteSection_spottedHere => 'Itt eszlelve';

  @override
  String get marineLife_siteSection_title => 'Tengeri elet';

  @override
  String get marineLife_speciesDetail_backTooltip => 'Vissza';

  @override
  String get marineLife_speciesDetail_depthRangeTitle => 'Melyseg tartomany';

  @override
  String get marineLife_speciesDetail_descriptionTitle => 'Leiras';

  @override
  String get marineLife_speciesDetail_divesLabel => 'Merülesek';

  @override
  String get marineLife_speciesDetail_editTooltip => 'Faj szerkesztese';

  @override
  String marineLife_speciesDetail_errorPrefix(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get marineLife_speciesDetail_noSightings =>
      'Meg nincsenek rogzitett eszlelesek';

  @override
  String get marineLife_speciesDetail_notFound => 'Faj nem talalhato';

  @override
  String marineLife_speciesDetail_sightingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'eszleles',
      one: 'eszleles',
    );
    return '$count $_temp0';
  }

  @override
  String get marineLife_speciesDetail_sightingPeriodTitle =>
      'Eszlelesi idoszak';

  @override
  String get marineLife_speciesDetail_sightingStatsTitle =>
      'Eszlelesi statisztikak';

  @override
  String get marineLife_speciesDetail_sitesLabel => 'Merülohelyek';

  @override
  String marineLife_speciesDetail_taxonomyClassLabel(Object className) {
    return 'Osztaly: $className';
  }

  @override
  String get marineLife_speciesDetail_topSitesTitle => 'Legjobb merülohelyek';

  @override
  String get marineLife_speciesDetail_totalSightingsLabel => 'Osszes eszleles';

  @override
  String get marineLife_speciesEdit_addTitle => 'Faj hozzaadasa';

  @override
  String marineLife_speciesEdit_addedSnackbar(Object name) {
    return '\"$name\" hozzaadva';
  }

  @override
  String get marineLife_speciesEdit_backTooltip => 'Vissza';

  @override
  String get marineLife_speciesEdit_categoryLabel => 'Kategoria';

  @override
  String get marineLife_speciesEdit_commonNameError =>
      'Kerem, adja meg a köznapi nevet';

  @override
  String get marineLife_speciesEdit_commonNameHint => 'pl. Bohochal';

  @override
  String get marineLife_speciesEdit_commonNameLabel => 'Köznapi nev';

  @override
  String get marineLife_speciesEdit_descriptionHint => 'A faj rovid leirasa...';

  @override
  String get marineLife_speciesEdit_descriptionLabel => 'Leiras';

  @override
  String get marineLife_speciesEdit_editTitle => 'Faj szerkesztese';

  @override
  String marineLife_speciesEdit_errorLoading(Object error) {
    return 'Hiba a faj betoltesekor: $error';
  }

  @override
  String marineLife_speciesEdit_errorSaving(Object error) {
    return 'Hiba a faj mentesekor: $error';
  }

  @override
  String get marineLife_speciesEdit_saveButton => 'Mentes';

  @override
  String get marineLife_speciesEdit_scientificNameHint =>
      'pl. Amphiprion ocellaris';

  @override
  String get marineLife_speciesEdit_scientificNameLabel => 'Tudomanyos nev';

  @override
  String get marineLife_speciesEdit_taxonomyClassHint => 'pl. Actinopterygii';

  @override
  String get marineLife_speciesEdit_taxonomyClassLabel => 'Taxonómiai osztaly';

  @override
  String marineLife_speciesEdit_updatedSnackbar(Object name) {
    return '\"$name\" frissitve';
  }

  @override
  String get marineLife_speciesManage_allFilter => 'Mind';

  @override
  String get marineLife_speciesManage_appBarTitle => 'Fajok';

  @override
  String get marineLife_speciesManage_backTooltip => 'Vissza';

  @override
  String marineLife_speciesManage_builtInSpeciesHeader(Object count) {
    return 'Beepitett fajok ($count)';
  }

  @override
  String get marineLife_speciesManage_cancelButton => 'Megse';

  @override
  String marineLife_speciesManage_cannotDeleteInUse(Object name) {
    return 'Nem torolheto \"$name\" - vannak eszlelesek hozza';
  }

  @override
  String get marineLife_speciesManage_clearSearchTooltip => 'Kereses torlese';

  @override
  String marineLife_speciesManage_customSpeciesHeader(Object count) {
    return 'Egyedi fajok ($count)';
  }

  @override
  String get marineLife_speciesManage_deleteButton => 'Torles';

  @override
  String marineLife_speciesManage_deleteDialogContent(Object name) {
    return 'Biztosan torli a(z) \"$name\" fajt?';
  }

  @override
  String get marineLife_speciesManage_deleteDialogTitle => 'Faj torlese?';

  @override
  String get marineLife_speciesManage_deleteTooltip => 'Faj torlese';

  @override
  String marineLife_speciesManage_deletedSnackbar(Object name) {
    return '\"$name\" torolve';
  }

  @override
  String get marineLife_speciesManage_editTooltip => 'Faj szerkesztese';

  @override
  String marineLife_speciesManage_errorDeleting(Object error) {
    return 'Hiba a faj torlesekor: $error';
  }

  @override
  String marineLife_speciesManage_errorResetting(Object error) {
    return 'Hiba a fajok visszaallitasakor: $error';
  }

  @override
  String get marineLife_speciesManage_noSpeciesFound => 'Nem talalhato faj';

  @override
  String get marineLife_speciesManage_resetButton => 'Visszaallitas';

  @override
  String get marineLife_speciesManage_resetDialogContent =>
      'Ez visszaallitja az osszes beepitett fajt az eredeti ertekekre. Az egyedi fajokat nem erinti. Az eszlelesekkel rendelkezo beepitett fajok frissitesre kerülnek, de megmaradnak.';

  @override
  String get marineLife_speciesManage_resetDialogTitle =>
      'Visszaallitas az alapertekekre?';

  @override
  String get marineLife_speciesManage_resetSuccess =>
      'Beepitett fajok visszaallitva az alapertekekre';

  @override
  String get marineLife_speciesManage_resetToDefaults =>
      'Visszaallitas az alapertekekre';

  @override
  String get marineLife_speciesManage_searchHint => 'Fajok keresese...';

  @override
  String get marineLife_speciesPicker_allFilter => 'Mind';

  @override
  String get marineLife_speciesPicker_cancelButton => 'Megse';

  @override
  String get marineLife_speciesPicker_clearSearchTooltip => 'Kereses torlese';

  @override
  String get marineLife_speciesPicker_closeTooltip => 'Fajvalaszto bezarasa';

  @override
  String get marineLife_speciesPicker_doneButton => 'Kesz';

  @override
  String marineLife_speciesPicker_error(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get marineLife_speciesPicker_noSpeciesFound => 'Nem talalhato faj';

  @override
  String get marineLife_speciesPicker_searchHint => 'Fajok keresese...';

  @override
  String marineLife_speciesPicker_selectedCount(Object count) {
    return '$count kivalasztva';
  }

  @override
  String get marineLife_speciesPicker_title => 'Fajok kivalasztasa';

  @override
  String get media_diveMediaSection_addTooltip => 'Foto vagy video hozzaadasa';

  @override
  String get media_diveMediaSection_cancelButton => 'Megse';

  @override
  String get media_diveMediaSection_cancelSelectionButton => 'Mégse';

  @override
  String get media_diveMediaSection_emptyState => 'Meg nincsenek fotok';

  @override
  String get media_diveMediaSection_errorLoading => 'Hiba a media betoltesekor';

  @override
  String get media_diveMediaSection_selectAllButton => 'Összes kijelölése';

  @override
  String media_diveMediaSection_selectedCount(int count) {
    return '$count kijelölve';
  }

  @override
  String get media_diveMediaSection_thumbnailLabel =>
      'Foto megtekintese. Hosszu nyomas a levalasztashoz';

  @override
  String get media_diveMediaSection_title => 'Fotok es videok';

  @override
  String get media_diveMediaSection_replaceButton => 'Újracsatolás';

  @override
  String get media_diveMediaSection_replaceEditedContent =>
      'A fájl tartalma eltér az eredetitől. Az újracsatolás újra feltölti a médiatárba.';

  @override
  String get media_diveMediaSection_replaceEditedTitle =>
      'A fájl tartalma eltér';

  @override
  String get media_diveMediaSection_unlinkButton => 'Leválasztás';

  @override
  String media_diveMediaSection_unlinkError(Object error) {
    return 'Nem sikerult a levalasztas: $error';
  }

  @override
  String media_diveMediaSection_unlinkSelectedButton(int count) {
    return '$count leválasztása';
  }

  @override
  String media_diveMediaSection_unlinkSelectedContent(int count) {
    return 'Eltávolít $count médiaelemet a médiatárból, a felhőmásolatokkal és bélyegképekkel együtt. A merülőhely által még használt elemek megmaradnak. Az eredeti fájlok érintetlenek maradnak.';
  }

  @override
  String media_diveMediaSection_unlinkSelectedSuccess(int count) {
    return '$count elem leválasztva';
  }

  @override
  String media_diveMediaSection_unlinkSelectedTitle(int count) {
    return '$count elem leválasztása?';
  }

  @override
  String media_library_unlinkConfirmTitle(int count) {
    return '$count elem leválasztása?';
  }

  @override
  String media_siteMediaSection_unlinkError(Object error) {
    return 'Nem sikerult a levalasztas: $error';
  }

  @override
  String get media_library_unlinkConfirmBody =>
      'Kikerülnek a médiatárból, a felhőmásolatokkal és bélyegképekkel együtt. Az eredeti fájlok érintetlenek maradnak. Nem vonható vissza.';

  @override
  String media_library_unlinkMetadataNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Közülük $count elemhez felirat vagy kedvenc jelölés tartozik a Submersionben, és ezek a részletek elvesznek.',
      one:
          'Egyikükhöz felirat vagy kedvenc jelölés tartozik a Submersionben, és ezek a részletek elvesznek.',
    );
    return '$_temp0';
  }

  @override
  String get media_siteMediaSection_title => 'Merülőhely médiafájljai';

  @override
  String get media_siteMediaSection_addPhotos => 'Fotók vagy videók hozzáadása';

  @override
  String get media_siteMediaSection_addDocument => 'Dokumentum hozzáadása';

  @override
  String get media_siteMediaSection_emptyState =>
      'Ehhez a merülőhelyhez nincs csatolva térkép, fotó vagy dokumentum';

  @override
  String media_siteMediaSection_divePhotosGroup(int count) {
    return 'Fotók az itteni merülésekről ($count)';
  }

  @override
  String get media_siteMediaSection_divePhotoLabel => 'Merülésfotó';

  @override
  String media_siteMediaSection_unlinkSelectedTitle(int count) {
    return '$count elem leválasztása?';
  }

  @override
  String media_siteMediaSection_unlinkSelectedContent(int count) {
    return 'Eltávolít $count elemet a könyvtárból, a felhőmásolatokkal és bélyegképekkel együtt. A merülés által még használt médiák megmaradnak. Az eredeti fájlok nem változnak.';
  }

  @override
  String media_siteMediaSection_unlinkSelectedSuccess(int count) {
    return '$count elem leválasztva';
  }

  @override
  String get media_documentViewer_title => 'Dokumentum';

  @override
  String get media_documentViewer_unavailable =>
      'Ez a dokumentum nem érhető el ezen az eszközön';

  @override
  String get media_documentViewer_availableOnOriginDevice =>
      'Azon az eszközön érhető el, amelyről hozzáadták, vagy egy beállított médiatárolón keresztül.';

  @override
  String media_documentViewer_attached(int count) {
    return '$count dokumentum csatolva';
  }

  @override
  String get media_diveScan_scanTooltip => 'Galeria keresese fotokert';

  @override
  String get media_diveScan_noPhotosFound =>
      'Nem talalhatok uj fotok ezen a merules kozeleben';

  @override
  String get media_diveScan_accessDenied =>
      'A fotokonyvtar hozzaferese szukseges a fotok keresesehez';

  @override
  String media_diveScan_foundPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foto',
      one: '1 foto',
    );
    return '$_temp0 talalhato ezen a merules kozeleben. Osszekotes?';
  }

  @override
  String get media_diveScan_foundTitle => 'Fotok talalva';

  @override
  String media_diveScan_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fotok',
      one: 'Foto',
    );
    return '$_temp0 osszekapcsolasa';
  }

  @override
  String get media_diveScan_cancelButton => 'Megse';

  @override
  String media_diveScan_error(String error) {
    return 'Hiba a galeria keresesekor: $error';
  }

  @override
  String get media_gpsBanner_addToSiteButton => 'Hozzaadas a merülohelyhez';

  @override
  String media_gpsBanner_coordinates(Object coordinates) {
    return 'Koordinatak: $coordinates';
  }

  @override
  String get media_gpsBanner_createSiteButton => 'Merülohely letrehozasa';

  @override
  String get media_gpsBanner_dismissTooltip => 'GPS javaslat elvetese';

  @override
  String get media_gpsBanner_title => 'GPS adat talalhato a fotokban';

  @override
  String media_import_failedToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fotot',
      one: 'fotot',
    );
    return 'Nem sikerult importalni $_temp0';
  }

  @override
  String media_import_failedToImportError(Object error) {
    return 'Nem sikerult a fotok importalasa: $error';
  }

  @override
  String media_import_allAlreadyLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotó már hozzá van kapcsolva ehhez a merüléshez',
      one: '1 fotó már hozzá van kapcsolva ehhez a merüléshez',
    );
    return '$_temp0';
  }

  @override
  String media_import_importedAndFailed(Object imported, Object failed) {
    return '$imported importalva, $failed sikertelen';
  }

  @override
  String media_import_importedAndSkipped(int imported, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      imported,
      locale: localeName,
      other: '$imported fotó importálva',
      one: '1 fotó importálva',
    );
    return '$_temp0 ($skipped már hozzákapcsolva)';
  }

  @override
  String media_import_importedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'foto',
      one: 'foto',
    );
    return '$count $_temp0 importalva';
  }

  @override
  String media_import_importingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'foto',
      one: 'foto',
    );
    return '$count $_temp0 importalasa...';
  }

  @override
  String get media_lightroom_openInLightroom => 'Megnyitás a Lightroomban';

  @override
  String get media_lightroom_suggestion_accept =>
      'Hozzáadás ehhez a merüléshez';

  @override
  String get media_lightroom_suggestion_dismiss => 'Elvetés';

  @override
  String get media_lightroom_suggestions_title => 'Javaslatok a Lightroomból';

  @override
  String get media_miniProfile_headerLabel => 'Merülesi profil';

  @override
  String get media_miniProfile_semanticLabel => 'Mini merülesi profil diagram';

  @override
  String get media_photoPicker_appBarTitle => 'Fotok kivalasztasa';

  @override
  String get media_photoPicker_tab_gallery => 'Galeria';

  @override
  String get media_photoPicker_tab_files => 'Fajlok';

  @override
  String get media_photoPicker_tab_url => 'URL';

  @override
  String get media_photoPicker_clearSelectionButton => 'Törlés';

  @override
  String get media_photoPicker_closeTooltip => 'Fotoválaszto bezarasa';

  @override
  String get media_photoPicker_doneButton => 'Kesz';

  @override
  String media_photoPicker_doneCountButton(Object count) {
    return 'Kesz ($count)';
  }

  @override
  String media_photoPicker_emptyMessage(
    Object startDate,
    Object startTime,
    Object endDate,
    Object endTime,
  ) {
    return 'Nem talalhatok fotok $startDate $startTime es $endDate $endTime kozott.';
  }

  @override
  String get media_photoPicker_emptyTitle => 'Nincsenek fotok';

  @override
  String get media_photoPicker_grantAccessButton => 'Tovább';

  @override
  String get media_photoPicker_openSettingsButton => 'Beallitasok megnyitasa';

  @override
  String get media_photoPicker_permissionDeniedMessage =>
      'A fotogaleriahoz valo hozzaferes megtagadva. Kerem, engedelyezze a Beallitasokban a merülesi fotok hozzaadasahoz.';

  @override
  String get media_photoPicker_permissionRequestMessage =>
      'A Submersion hozzaferest igenyel a fotogaleriajahoz merülesi fotok hozzaadasahoz.';

  @override
  String get media_photoPicker_permissionTitle => 'Merulesi fotok';

  @override
  String get media_photoPicker_selectAllButton => 'Összes kijelölése';

  @override
  String media_photoPicker_selectedCount(int count) {
    return '$count kijelölve';
  }

  @override
  String media_photoPicker_showingPhotosFromRange(Object rangeText) {
    return 'Fotok megjelenites: $rangeText';
  }

  @override
  String get media_photoPicker_thumbnailToggleLabel =>
      'Foto kivalasztasanak valtoztatas';

  @override
  String get media_photoPicker_thumbnailToggleSelectedLabel =>
      'Foto kivalasztasanak valtoztatas, kivalasztva';

  @override
  String get media_photoPicker_files_pickFilesButton => 'Fájlok kiválasztása…';

  @override
  String get media_photoPicker_files_pickFolderButton => 'Mappa kiválasztása…';

  @override
  String get media_photoPicker_files_autoMatchLabel =>
      'Fényképek és videók automatikus hozzárendelése merülésekhez dátum alapján';

  @override
  String get media_photoPicker_files_emptyHint =>
      'Válassz fájlokat vagy egy mappát a kezdéshez.';

  @override
  String media_photoPicker_files_linkButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elem összekapcsolása',
      one: '1 elem összekapcsolása',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachToSiteButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elem csatolása ehhez a helyszínhez',
      one: '1 elem csatolása ehhez a helyszínhez',
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
      other: '$fileCount fájl',
      one: '1 fájl',
    );
    String _temp1 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount merülés',
      one: '1 merülés',
    );
    return '$_temp0, $_temp1, $unmatchedCount nincs hozzárendelve';
  }

  @override
  String media_photoPicker_files_itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elem',
      one: '1 elem',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_diveGroupTitle(String diveId) {
    return 'Merülés $diveId';
  }

  @override
  String media_photoPicker_files_groupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fájl',
      one: '1 fájl',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_unmatchedGroupTitle =>
      'Nincs hozzárendelve';

  @override
  String media_photoPicker_files_addAllToDive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mind a $count hozzáadása ehhez a merüléshez',
      one: '1 hozzáadása ehhez a merüléshez',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_addToDiveTooltip =>
      'Hozzáadás ehhez a merüléshez';

  @override
  String get media_photoPicker_files_chooseDiveTooltip =>
      'Merülés kiválasztása';

  @override
  String get media_photoPicker_files_removeTooltip =>
      'Eltávolítás a kijelölésből';

  @override
  String get media_photoPicker_files_sourceExif => 'EXIF-ből';

  @override
  String get media_photoPicker_files_sourceContainer => 'fájl metaadatokból';

  @override
  String get media_photoPicker_files_sourceFileDate => 'fájl dátumából';

  @override
  String get media_photoPicker_files_sourceNone => 'nincs dátum';

  @override
  String media_photoPicker_files_shiftedTime(String shifted, String original) {
    return '$shifted (eredetileg $original)';
  }

  @override
  String get media_photoPicker_files_reasonNoTimestamp =>
      'A felvétel ideje nem olvasható';

  @override
  String media_photoPicker_files_reasonBeforeDive(String gap) {
    return '$gap a legközelebbi merülés előtt';
  }

  @override
  String media_photoPicker_files_reasonAfterDive(String gap) {
    return '$gap a legközelebbi merülés után';
  }

  @override
  String get media_photoPicker_files_reasonNoDives =>
      'Nincs merülés az összevetéshez';

  @override
  String get media_photoPicker_files_offsetLabel =>
      'Felvételi idők eltolása ennyivel:';

  @override
  String get media_photoPicker_files_offsetResetTooltip =>
      'Eltolás visszaállítása';

  @override
  String media_photoPicker_files_offsetBackTooltip(String amount) {
    return 'Eltolás $amount korábbra';
  }

  @override
  String media_photoPicker_files_offsetForwardTooltip(String amount) {
    return 'Eltolás $amount későbbre';
  }

  @override
  String media_photoPicker_files_linkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elem összekapcsolva',
      one: '1 elem összekapcsolva',
    );
    return '$_temp0';
  }

  @override
  String media_photoPicker_files_attachedToSiteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elem csatolva ehhez a helyszínhez',
      one: '1 elem csatolva ehhez a helyszínhez',
    );
    return '$_temp0';
  }

  @override
  String get media_photoPicker_files_undo => 'Visszavonás';

  @override
  String get media_photoPicker_thumbnailAlreadyLinkedLabel =>
      'A fotó már hozzá van kapcsolva ehhez a merüléshez';

  @override
  String get media_perdixOverlay_labelCns => 'CNS';

  @override
  String get media_perdixOverlay_labelDepth => 'MÉLYS';

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
  String get media_perdixOverlay_labelTemp => 'HŐM';

  @override
  String get media_perdixOverlay_labelTime => 'IDŐ';

  @override
  String get media_perdixOverlay_labelTts => 'TTS';

  @override
  String get media_perdixOverlay_toggleTooltip => 'Búvárszámítógép-réteg';

  @override
  String get media_photoViewer_cannotShare => 'Nem oszthato meg ez a foto';

  @override
  String get media_photoViewer_cannotWriteMetadata =>
      'Nem irhato metaadat - a media nincs a konyvtarhoz csatolva';

  @override
  String get media_photoViewer_closeTooltip => 'Foto megtekintobezerarasa';

  @override
  String get media_photoViewer_diveDataWrittenToPhoto =>
      'Merülesi adatok irva a fotora';

  @override
  String get media_photoViewer_diveDataWrittenToVideo =>
      'Merülesi adatok irva a videora';

  @override
  String media_photoViewer_errorLoadingPhotos(Object error) {
    return 'Hiba a fotok betoltesekor: $error';
  }

  @override
  String get media_photoViewer_failedToLoadImage =>
      'Nem sikerult a kep betoltese';

  @override
  String get media_photoViewer_failedToLoadVideo =>
      'Nem sikerult a video betoltese';

  @override
  String media_photoViewer_failedToShare(Object error) {
    return 'Nem sikerult a megosztas: $error';
  }

  @override
  String get media_photoViewer_failedToWriteMetadata =>
      'Nem sikerult a metaadat irasa';

  @override
  String media_photoViewer_failedToWriteMetadataError(Object error) {
    return 'Nem sikerult a metaadat irasa: $error';
  }

  @override
  String get media_photoViewer_nextTooltip => 'Következő médiaelem';

  @override
  String get media_photoViewer_noPhotosAvailable => 'Nincsenek elerheto fotok';

  @override
  String media_photoViewer_pageIndicator(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get media_photoViewer_playPauseVideoLabel =>
      'Video lejatszasa vagy szüneteltetese';

  @override
  String get media_photoViewer_previousTooltip => 'Előző médiaelem';

  @override
  String get media_photoViewer_seekVideoLabel => 'Video pozicio keresese';

  @override
  String get media_photoViewer_shareTooltip => 'Foto megosztasa';

  @override
  String get media_photoViewer_toggleOverlayLabel =>
      'Foto feliratok ki/be kapcsolasa';

  @override
  String get media_photoViewer_videoFileNotFound => 'Video fajl nem talalhato';

  @override
  String get media_photoViewer_videoNotLinked =>
      'A video nincs a konyvtarhoz csatolva';

  @override
  String get media_photoViewer_writeDiveDataTooltip =>
      'Merülesi adatok irasa a fotora';

  @override
  String get media_quickSiteDialog_cancelButton => 'Megse';

  @override
  String get media_quickSiteDialog_createButton => 'Merülohely letrehozasa';

  @override
  String get media_quickSiteDialog_description =>
      'Uj merülohely letrehozasa a foto GPS koordinatai alapjan.';

  @override
  String get media_quickSiteDialog_siteNameError =>
      'Kerem, adja meg a merülohely nevet';

  @override
  String get media_quickSiteDialog_siteNameHint =>
      'Adjon meg egy nevet ehhez a merülohelyhez';

  @override
  String get media_quickSiteDialog_siteNameLabel => 'Merülohely neve';

  @override
  String get media_quickSiteDialog_title => 'Merülohely letrehozasa';

  @override
  String get media_scanResults_allPhotosLinked =>
      'Minden foto mar csatolva van';

  @override
  String media_scanResults_allPhotosLinkedDescription(Object count) {
    return 'Az ut mind a(z) $count fotoja mar csatolva van merülesekhez.';
  }

  @override
  String media_scanResults_alreadyLinked(Object count) {
    return '$count foto mar csatolva';
  }

  @override
  String get media_scanResults_cancelButton => 'Megse';

  @override
  String media_scanResults_diveNumber(Object number) {
    return '#$number. merüles';
  }

  @override
  String media_scanResults_foundNewPhotos(Object count) {
    return '$count uj foto talalva';
  }

  @override
  String get media_scanResults_linkButton => 'Csatolas';

  @override
  String media_scanResults_linkCountButton(Object count) {
    return '$count foto csatolasa';
  }

  @override
  String get media_scanResults_noPhotosFound => 'Nem talalhatok fotok';

  @override
  String get media_scanResults_okButton => 'OK';

  @override
  String get media_scanResults_unknownSite => 'Ismeretlen merülohely';

  @override
  String media_scanResults_unmatchedWarning(Object count) {
    return '$count foto nem volt hozzarendelheto egyetlen merüleshez sem (a merülesi idokon kivul keszült)';
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
  String get media_unavailablePlaceholder_notOnDevice => 'Nem ezen az eszközön';

  @override
  String get media_unavailablePlaceholder_signInRequired => 'Sign in to view';

  @override
  String get media_writeMetadata_cancelButton => 'Megse';

  @override
  String get media_writeMetadata_depthLabel => 'Melyseg';

  @override
  String get media_writeMetadata_descriptionPhoto =>
      'A kovetkezo metaadatok kerülnek a fotora:';

  @override
  String get media_writeMetadata_descriptionVideo =>
      'A kovetkezo metaadatok kerülnek a videora:';

  @override
  String get media_writeMetadata_diveTimeLabel => 'Merülesi ido';

  @override
  String get media_writeMetadata_gpsLabel => 'GPS';

  @override
  String get media_writeMetadata_keepOriginalVideo =>
      'Eredeti video megtartasa';

  @override
  String get media_writeMetadata_livePhotoUnsupported =>
      'A Live Photo még nem támogatott. Készíts róla állóképes másolatot, majd a merülési adatokat a másolatba írd.';

  @override
  String get media_writeMetadata_noDataAvailable =>
      'Nincs elerheto merülesi adat az irashoz.';

  @override
  String get media_writeMetadata_siteLabel => 'Merülohely';

  @override
  String get media_writeMetadata_temperatureLabel => 'Homerseklet';

  @override
  String get media_writeMetadata_titlePhoto => 'Merülesi adatok irasa a fotora';

  @override
  String get media_writeMetadata_titleVideo =>
      'Merülesi adatok irasa a videora';

  @override
  String get media_writeMetadata_warningPhotoText =>
      'Ez modositja az eredeti fotot.';

  @override
  String get media_writeMetadata_warningVideoText =>
      'Egy uj video keszül a metaadatokkal. A video metaadatok nem modosithatok helyben.';

  @override
  String get media_writeMetadata_writeButton => 'Iras';

  @override
  String get nav_buddies => 'Buddyk';

  @override
  String get nav_certifications => 'Kepesitesek';

  @override
  String get nav_courses => 'Tanfolyamok';

  @override
  String get nav_coursesSubtitle => 'Kepzes es oktatas';

  @override
  String get nav_diveCenters => 'Merulocentrumok';

  @override
  String get nav_dives => 'Merulesek';

  @override
  String get nav_equipment => 'Felszereles';

  @override
  String get nav_gpsLog => 'GPS-napló';

  @override
  String get media_console_library => 'Könyvtár';

  @override
  String get media_console_transfers => 'Átvitelek';

  @override
  String get media_console_import => 'Importálás';

  @override
  String get media_import_launch => 'Média importálása...';

  @override
  String get media_import_review_title => 'Importálás ellenőrzése';

  @override
  String media_import_review_confirm(int count) {
    return '$count elem importálása';
  }

  @override
  String media_import_review_result(int linked, int skipped, int failed) {
    return '$linked összekapcsolva, $skipped kihagyva, $failed sikertelen';
  }

  @override
  String get media_import_review_chooseSite => 'Merülőhely kiválasztása';

  @override
  String get media_import_review_ambiguous => 'Több merülés is egyezik';

  @override
  String get media_import_review_noMatch => 'Nincs egyező merülés';

  @override
  String get media_import_review_skipped => 'Nincs importálva';

  @override
  String media_import_review_linkChip(int number) {
    return 'Csatolás: #$number';
  }

  @override
  String get media_import_review_linkToDive => 'Csatolás merüléshez';

  @override
  String get media_import_review_linkToSite => 'Csatolás merülőhelyhez';

  @override
  String get media_import_review_chooseDive => 'Merülés kiválasztása';

  @override
  String get media_import_intro =>
      'A fotók importáláskor egy merüléshez vagy merülőhelyhez kapcsolódnak.';

  @override
  String get media_console_sources => 'Források';

  @override
  String get media_sources_browseHeader => 'Böngészés forrás szerint';

  @override
  String get media_sources_watchedHeader => 'Figyelt mappák';

  @override
  String get media_sources_addWatched => 'Mappa hozzáadása...';

  @override
  String get media_sources_scanFailed => 'A keresés sikertelen';

  @override
  String get media_sources_scanNow => 'Keresés most';

  @override
  String get media_sources_autoApply =>
      'Pontos egyezések automatikus újracsatolása';

  @override
  String get media_sources_neverScanned => 'Még nem vizsgált';

  @override
  String get media_source_gallery => 'Fotókönyvtár';

  @override
  String get media_source_localFile => 'Helyi fájlok';

  @override
  String get media_source_networkUrl => 'Webhivatkozások';

  @override
  String get media_source_manifest => 'Feliratkozások';

  @override
  String get media_source_connector => 'Csatlakoztatott szolgáltatások';

  @override
  String get media_source_mediaStore => 'Felhő médiatár';

  @override
  String get media_source_signature => 'Aláírások';

  @override
  String get media_repairHistory_title => 'Javítási előzmények';

  @override
  String get media_repairHistory_empty => 'Még nincs javítás';

  @override
  String get media_repairHistory_action_relink => 'Újracsatolva';

  @override
  String get media_repairHistory_action_cloudBacked => 'Felhőalapú';

  @override
  String get media_repairHistory_action_autoRelink =>
      'Automatikusan újracsatolva';

  @override
  String get media_smartAlbum_save => 'Mentés albumként';

  @override
  String get media_smartAlbum_saveTitle => 'Album elnevezése';

  @override
  String get media_smartAlbum_albums => 'Albumok';

  @override
  String get media_smartAlbum_delete => 'Album törlése';

  @override
  String get media_smartAlbum_deleteFailed => 'Az album törlése nem sikerült';

  @override
  String get media_smartAlbum_saved => 'Album mentve';

  @override
  String media_sources_lastScanned(String date) {
    return 'Utoljára vizsgálva: $date';
  }

  @override
  String media_sources_scanResult(int indexed, int repaired) {
    return '$indexed fájl indexelve, $repaired újracsatolva';
  }

  @override
  String get media_repairHistory_sourceFolder => 'mappavizsgálat';

  @override
  String get media_repairHistory_sourcePhotoLibrary => 'fotókönyvtár';

  @override
  String get media_repairHistory_sourceStore => 'felhőalapú médiatár';

  @override
  String get media_repairHistory_sourceWatcher => 'figyelt mappák';

  @override
  String get media_repairHistory_sourceManual => 'kézi újracsatolás';

  @override
  String media_repairHistory_source(String source) {
    return 'forrás: $source';
  }

  @override
  String get media_missing_empty => 'Nincs hiányzó fájl';

  @override
  String media_missing_offlineVolumes(int count) {
    return '$count offline köteten';
  }

  @override
  String get media_missing_repair => 'Javítás...';

  @override
  String get media_repair_title => 'Hiányzó fájlok javítása';

  @override
  String get media_repair_addFolder => 'Mappa hozzáadása...';

  @override
  String get media_repair_usePhotoLibrary => 'Keresés a fotókönyvtárban';

  @override
  String get media_repair_useStore => 'Felhő médiatár használata';

  @override
  String get media_repair_scan => 'Keresés';

  @override
  String media_repair_prefixMove(String from, String to, int count) {
    return 'Mappaáthelyezés észlelve: $from -> $to, $count fájlt fed le';
  }

  @override
  String get media_repair_confidence_exact => 'Pontos';

  @override
  String get media_repair_confidence_probable => 'Név és méret';

  @override
  String get media_repair_confidence_edited => 'Szerkesztett fájl';

  @override
  String get media_repair_confidence_unmatched => 'Nincs jelölt';

  @override
  String get media_repair_unverified => 'Nincs ellenőrizve a tár ellen';

  @override
  String media_repair_apply(int count) {
    return '$count fájl újracsatolása';
  }

  @override
  String media_repair_summary(
    int relinked,
    int cloudBacked,
    int reuploads,
    int failed,
    int skipped,
  ) {
    return '$relinked újracsatolva, $cloudBacked felhőalapú, $reuploads újrafeltöltés sorban, $failed sikertelen, $skipped kihagyva';
  }

  @override
  String get media_library_empty => 'Még nincs média';

  @override
  String get media_library_filter_all => 'Összes';

  @override
  String get media_library_filter_photos => 'Fotók';

  @override
  String get media_library_filter_videos => 'Videók';

  @override
  String get media_library_filter_site => 'Merülőhely';

  @override
  String get media_library_filter_trip => 'Utazás';

  @override
  String get media_library_filter_dates => 'Dátumok';

  @override
  String get media_library_filter_missing => 'Hiányzó fájlok';

  @override
  String media_library_filter_missingCount(int count) {
    return 'Hiányzó fájlok ($count)';
  }

  @override
  String get media_library_filter_clear => 'Szűrők törlése';

  @override
  String get media_library_filter_any => 'Bármely';

  @override
  String get media_library_filter_title => 'Média szűrése';

  @override
  String get media_library_filter_apply => 'Alkalmaz';

  @override
  String get media_library_sort_title => 'Média rendezése';

  @override
  String get media_smartAlbum_load => 'Album betöltése';

  @override
  String get media_divePicker_title => 'Áthelyezés merüléshez';

  @override
  String get media_divePicker_search => 'Merülések keresése';

  @override
  String get media_library_moveToDive => 'Áthelyezés merüléshez';

  @override
  String get media_library_unlinkSelected => 'Leválasztás';

  @override
  String media_library_selectedCount(int count) {
    return '$count kiválasztva';
  }

  @override
  String get media_library_unlinkedHeader => 'Nem csatolt';

  @override
  String get media_library_diveHeaderHint => 'Merülés megnyitása';

  @override
  String get media_library_untitledDiveHeader => 'Névtelen merülés';

  @override
  String get media_library_viewMode_byDive => 'Merülés szerint';

  @override
  String get media_library_viewMode_grid => 'Rács';

  @override
  String get media_library_viewMode_timeline => 'Idővonal';

  @override
  String get media_viewer_goToDive => 'Ugrás a merüléshez';

  @override
  String get nav_home => 'Fooldal';

  @override
  String get nav_media => 'Média';

  @override
  String get nav_more => 'Tovabb';

  @override
  String get nav_planning => 'Tervezes';

  @override
  String get nav_planningSubtitle => 'Merulestervezo, szamologepek';

  @override
  String get nav_settings => 'Beallitasok';

  @override
  String get nav_sites => 'Merulohelyek';

  @override
  String get nav_statistics => 'Statisztikak';

  @override
  String get nav_tooltip_closeMenu => 'Menu bezarasa';

  @override
  String get nav_tooltip_collapseMenu => 'Menu osszecsuklasa';

  @override
  String get nav_tooltip_expandMenu => 'Menu kinyitasa';

  @override
  String get nav_transfer => 'Atvitel';

  @override
  String get nav_trips => 'Utak';

  @override
  String plannerCanvas_bailout_available(String liters) {
    return 'Elérhető $liters';
  }

  @override
  String get plannerCanvas_bailout_insufficient =>
      'A bailout gáz nem elegendő a legrosszabb esethez';

  @override
  String plannerCanvas_bailout_required(String liters) {
    return 'Szükséges $liters';
  }

  @override
  String get plannerCanvas_bailout_title => 'Bailout (nyitott rendszer)';

  @override
  String plannerCanvas_bailout_tts(String minutes) {
    return 'Bailout TTS $minutes′';
  }

  @override
  String plannerCanvas_bailout_worstCase(String minutes, String depth) {
    return 'Legrosszabb eset $minutes′-nél · $depth';
  }

  @override
  String get plannerCanvas_ccr_setpointHigh => 'Magas setpoint (bar)';

  @override
  String get plannerCanvas_ccr_setpointLow => 'Alacsony setpoint (bar)';

  @override
  String get plannerCanvas_ccr_switchDepth => 'Setpoint váltási mélység';

  @override
  String get plannerCanvas_pscr_ratio => 'pSCR arány';

  @override
  String get plannerCanvas_pscr_ratio_hint =>
      'Nagyobb = több friss gáz, kisebb O₂-esés';

  @override
  String plannerCanvas_chip_cns(String value) {
    return 'CNS $value%';
  }

  @override
  String plannerCanvas_chip_issues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count probléma',
      one: '1 probléma',
    );
    return '$_temp0';
  }

  @override
  String get plannerCanvas_compare_action => 'Összehasonlítás';

  @override
  String get plannerCanvas_compare_needTwo =>
      'Válassz ki legalább két tervet az összehasonlításhoz';

  @override
  String get plannerCanvas_compare_title => 'Tervek összehasonlítása';

  @override
  String get plannerCanvas_contingency_base => 'Alap';

  @override
  String get plannerCanvas_contingency_depthDelta => 'Extra mélység';

  @override
  String plannerCanvas_contingency_lostGas(String gas) {
    return '$gas elveszett';
  }

  @override
  String plannerCanvas_contingency_previewing(String label) {
    return 'Előnézet: $label';
  }

  @override
  String get plannerCanvas_contingency_timeDelta => 'Extra percek';

  @override
  String plannerCanvas_chart_meanDepth(String depth) {
    return 'átlag $depth';
  }

  @override
  String get plannerCanvas_contingency_title => 'Vészhelyzeti tervek';

  @override
  String get plannerCanvas_contingency_turnFraction => 'Fordulási hányad';

  @override
  String get plannerCanvas_contingency_turnRule => 'Fordulónyomás-szabály';

  @override
  String get plannerCanvas_convert_success => 'Merülés létrehozva a tervből';

  @override
  String get plannerCanvas_convert_view => 'Megtekintés';

  @override
  String plannerCanvas_follow_chip(String name) {
    return '$name követése';
  }

  @override
  String get plannerCanvas_follow_empty => 'Még nincsenek naplózott merülések';

  @override
  String get plannerCanvas_follow_noTissues =>
      'Nincs profiladat ehhez a merüléshez — a felszíni intervallum szövettelítés nélkül lett beállítva';

  @override
  String get plannerCanvas_follow_title => 'Merülés követése';

  @override
  String plannerCanvas_gas_minGas(String pressure) {
    return 'min. gáz $pressure';
  }

  @override
  String plannerCanvas_gas_turnAt(String pressure) {
    return 'fordulás $pressure-nál';
  }

  @override
  String plannerCanvas_issue_gasDensityCritical(String value) {
    return 'Gázsűrűség $value g/L a szigorú határ felett';
  }

  @override
  String plannerCanvas_issue_gasDensityHigh(String value) {
    return 'Gázsűrűség $value g/L az ajánlott határ felett';
  }

  @override
  String plannerCanvas_issue_hypoxic(String depth, String value) {
    return 'Hipoxiás gáz $depth mélységben (ppO₂ $value bar)';
  }

  @override
  String plannerCanvas_issue_minGas(String pressure) {
    return 'A palack a rock-bottom minimum ($pressure) alatt végez';
  }

  @override
  String get plannerCanvas_issue_noBailout =>
      'A CCR dekompressziós terv nem tartalmaz bailout gázt';

  @override
  String get plannerCanvas_issue_noDecoGas =>
      'Dekompresszió szükséges, de nincs deco gáz';

  @override
  String get plannerCanvas_range_base => 'Alap';

  @override
  String get plannerCanvas_range_legend =>
      'A cellák a felszínre érés idejét mutatják; piros = a terv szerint nem merülhető';

  @override
  String get plannerCanvas_pane_collapse => 'Panel összecsukása';

  @override
  String get plannerCanvas_pane_expand => 'Panel kibontása';

  @override
  String get plannerCanvas_tab_setup => 'Beállítás';

  @override
  String get plannerCanvas_o2Narcotic => 'O₂ kezelése kábítóként';

  @override
  String get plannerCanvas_rates_ascent => 'Emelkedési ütem';

  @override
  String get plannerCanvas_rates_descent => 'Merülési ütem';

  @override
  String get plannerCanvas_rates_title => 'Ütemek';

  @override
  String get plannerCanvas_range_title => 'Tartománytáblázat';

  @override
  String get plannerCanvas_results_noDeco => 'Nincs szükség dekompresszióra';

  @override
  String plannerCanvas_sac_useLogged(String sac) {
    return 'Naplózott átlag használata ($sac)';
  }

  @override
  String plannerCanvas_saved_deleteConfirmBody(String name) {
    return 'Véglegesen törli a(z) „$name” tervet?';
  }

  @override
  String get plannerCanvas_saved_deleteConfirmTitle => 'Törli a tervet?';

  @override
  String get plannerCanvas_saved_duplicate => 'Duplikálás';

  @override
  String get plannerCanvas_saved_empty => 'Még nincsenek mentett tervek';

  @override
  String get plannerCanvas_saved_title => 'Mentett tervek';

  @override
  String get plannerCanvas_name_dialogTitle => 'Nevezze el a tervet';

  @override
  String get plannerCanvas_name_defaultFallback => 'Merülési terv';

  @override
  String plannerCanvas_scrub_bailout(String minutes) {
    return 'BO $minutes′';
  }

  @override
  String plannerCanvas_scrub_readout(String minutes, String depth) {
    return 'RT $minutes′ · $depth';
  }

  @override
  String get plannerCanvas_share_import => 'Importálás';

  @override
  String plannerCanvas_share_importFailed(String reason) {
    return 'A terv importálása nem sikerült: $reason';
  }

  @override
  String get plannerCanvas_share_menu => 'Tervfájl megosztása';

  @override
  String get plannerCanvas_slate_menu => 'Tábla exportálása (PDF)';

  @override
  String get plannerCanvas_slate_minGas => 'Minimális gáz';

  @override
  String get plannerCanvas_slate_turn => 'Forduló';

  @override
  String get plannerCanvas_table_depth => 'Mélység';

  @override
  String get plannerCanvas_table_gas => 'Gáz';

  @override
  String get plannerCanvas_table_runtime => 'RT';

  @override
  String get plannerCanvas_table_stop => 'Megálló';

  @override
  String get plannerCanvas_turnRule_allUsable => 'Minden felhasználható';

  @override
  String get plannerCanvas_turnRule_custom => 'Egyéni';

  @override
  String get plannerCanvas_turnRule_halves => 'Felek';

  @override
  String get plannerCanvas_turnRule_none => 'Nincs';

  @override
  String get plannerCanvas_turnRule_thirds => 'Harmadok';

  @override
  String get planning_appBar_title => 'Tervezes';

  @override
  String get planning_card_decoCalculator_description =>
      'Szamitsa ki a dekompresszios limiteket, a szükseges deko megalloket es a CNS/OTU terhelest többszintu merülesi profilokhoz.';

  @override
  String get planning_card_decoCalculator_subtitle =>
      'Merülesek tervezese dekompressziós megallokkal';

  @override
  String get planning_card_decoCalculator_title => 'Deko kalkulator';

  @override
  String get planning_card_divePlanner_description =>
      'Tervezzen összetett merüleseket több melysegi szinttel, gazvaltas lehetoseggel es automatikus dekompresszios megallo szamitassal.';

  @override
  String get planning_card_divePlanner_subtitle =>
      'Többszintu merülesi tervek keszitese';

  @override
  String get planning_card_divePlanner_title => 'Merüles tervezo';

  @override
  String get planning_card_gasCalculators_description =>
      'Negy specialis gaz kalkulator:\n• MOD - Maximalis üzemi melyseg egy gazkeverekhez\n• Legjobb keverek - Idealis O₂% egy cel melyseghez\n• Fogyasztas - Gaz felhasznalás becsles\n• Rock Bottom - Veszhelyzeti tartalek szamitas';

  @override
  String get planning_card_gasCalculators_subtitle =>
      'MOD, Legjobb keverek, Fogyasztas, Rock Bottom';

  @override
  String get planning_card_gasCalculators_title => 'Gaz kalkulatorok';

  @override
  String get planning_card_surfaceInterval_description =>
      'Szamitsa ki a merülesek közötti minimalis felszini idot a szöveti terhelés alapjan. Vizualizalja, hogyan gaztalanitodik a 16 szoveti rekesz az ido függvenyében.';

  @override
  String get planning_card_surfaceInterval_subtitle =>
      'Ismetelt merülesek idointervallumainak tervezese';

  @override
  String get planning_card_surfaceInterval_title => 'Felszini idoköz';

  @override
  String get planning_card_weightCalculator_description =>
      'Becsülje meg a szükseges sulyt a merülesi ruha, palack anyag, viztipus es testsuly alapjan.';

  @override
  String get planning_card_weightCalculator_subtitle =>
      'Ajanlott suly az adott felszereleshez';

  @override
  String get planning_card_weightCalculator_title => 'Suly kalkulator';

  @override
  String get planning_info_disclaimer =>
      'Ezek az eszkozök kizarolag tervezesi celokat szolgalnak. Mindig ellenorizze a szamitasokat es kövesse merülesi kepzesenek iranyelveit.';

  @override
  String get planning_newPlan => 'Új terv';

  @override
  String get planning_section_tools => 'Eszközök';

  @override
  String get planning_summary_prompt => 'Válassz egy eszközt a kezdéshez';

  @override
  String get planning_summary_savedPlans => 'Mentett tervek';

  @override
  String get planning_summary_noPlans => 'Még nincsenek mentett tervek';

  @override
  String get planning_sidebar_appBar_title => 'Tervezes';

  @override
  String get planning_sidebar_decoCalculator_subtitle => 'NDL es deko megallok';

  @override
  String get planning_sidebar_decoCalculator_title => 'Deko kalkulator';

  @override
  String get planning_sidebar_divePlanner_subtitle =>
      'Többszintu merülesi tervek';

  @override
  String get planning_sidebar_divePlanner_title => 'Merüles tervezo';

  @override
  String get planning_sidebar_gasCalculators_subtitle =>
      'MOD, Legjobb keverek, tobb';

  @override
  String get planning_sidebar_gasCalculators_title => 'Gaz kalkulatorok';

  @override
  String get planning_sidebar_info_disclaimer =>
      'A tervezo eszkozök csak tajekoztatasi celokat szolgalnak. Mindig ellenorizze a szamitasokat.';

  @override
  String get planning_sidebar_surfaceInterval_subtitle =>
      'Ismetelt merüles tervezes';

  @override
  String get planning_sidebar_surfaceInterval_title => 'Felszini idoköz';

  @override
  String get planning_sidebar_weightCalculator_subtitle => 'Ajanlott suly';

  @override
  String get planning_sidebar_weightCalculator_title => 'Suly kalkulator';

  @override
  String get planning_welcome_quickTips_title => 'Gyors tippek';

  @override
  String get planning_welcome_subtitle =>
      'Valasszon egy eszkozöt az oldalsavbol a kezdeshez';

  @override
  String get planning_welcome_tip_decoCalculator =>
      'Deko kalkulator NDL es megallasi idok szamitasahoz';

  @override
  String get planning_welcome_tip_divePlanner =>
      'Merüles tervezo többszintu merülesek tervezesehez';

  @override
  String get planning_welcome_tip_gasCalculators =>
      'Gaz kalkulatorok MOD es gaz tervezeshez';

  @override
  String get planning_welcome_tip_weightCalculator =>
      'Suly kalkulator a trimm beallitasahoz';

  @override
  String get planning_welcome_title => 'Tervezo eszkozök';

  @override
  String get settings_about_aboutSubmersion => 'A Submersion-rol';

  @override
  String get settings_about_appName => 'Submersion';

  @override
  String get settings_about_description =>
      'Kövesse nyomon merüleseit, kezelje felszereleset es fedezze fel a merülohelyeket.';

  @override
  String get settings_about_header => 'Rolunk';

  @override
  String get settings_about_openSourceLicenses => 'Nyilt forrasu licencek';

  @override
  String get settings_about_reportIssue => 'Hiba bejelentese';

  @override
  String get settings_about_reportIssue_copy => 'Link másolása';

  @override
  String get settings_about_reportIssue_snackbar =>
      'Latogasson el: github.com/submersion-app/submersion/issues';

  @override
  String settings_about_version(String version) {
    return 'Verzio $version';
  }

  @override
  String get settings_appBar_title => 'Beallitasok';

  @override
  String get settings_appearance_appLanguage => 'Alkalmazas nyelve';

  @override
  String get settings_appearance_displaySize => 'Megjelenítési méret';

  @override
  String settings_appearance_displaySize_value(int percent) {
    return '$percent%';
  }

  @override
  String get settings_appearance_displaySize_reset => 'Visszaállítás';

  @override
  String get settings_appearance_displaySize_smaller => 'Kisebb';

  @override
  String get settings_appearance_displaySize_larger => 'Nagyobb';

  @override
  String get settings_appearance_depthColoredCards =>
      'Melyseg szerint szinezett merülesi kartyak';

  @override
  String get settings_appearance_depthColoredCards_subtitle =>
      'Merülesi kartyak megjelenites ocean-szinu hatterrel a melyseg alapjan';

  @override
  String get settings_appearance_cardColorAttribute => 'Kartyak szinezese';

  @override
  String get settings_appearance_cardColorAttribute_subtitle =>
      'Valassza ki, melyik jellemzo hatarozza meg a kartya hatterszinet';

  @override
  String get settings_appearance_cardColorAttribute_none => 'Nincs';

  @override
  String get settings_appearance_cardColorAttribute_depth => 'Melyseg';

  @override
  String get settings_appearance_cardColorAttribute_duration => 'Idotartam';

  @override
  String get settings_appearance_cardColorAttribute_temperature =>
      'Homerseklet';

  @override
  String get settings_appearance_colorGradient => 'Szinatlenet';

  @override
  String get settings_appearance_colorGradient_subtitle =>
      'Valassza ki a szintartomanyt a kartya hatterekhez';

  @override
  String get settings_appearance_colorGradient_ocean => 'Ocean';

  @override
  String get settings_appearance_colorGradient_thermal => 'Termikus';

  @override
  String get settings_appearance_colorGradient_sunset => 'Naplemente';

  @override
  String get settings_appearance_colorGradient_forest => 'Erdo';

  @override
  String get settings_appearance_colorGradient_monochrome => 'Monokrom';

  @override
  String get settings_appearance_colorGradient_custom => 'Egyeni';

  @override
  String get settings_appearance_gasSwitchMarkers => 'Gazvaltas jelolok';

  @override
  String get settings_appearance_gasSwitchMarkers_subtitle =>
      'Gazvaltas jelolok megjelenites';

  @override
  String get settings_appearance_gasTimeline => 'Gáz idővonal';

  @override
  String get settings_appearance_gasTimeline_subtitle =>
      'Gázfogyasztási sáv megjelenítése a merülési profil alatt alapértelmezetten';

  @override
  String get settings_appearance_header_diveDetails => 'Merülés részletek';

  @override
  String get settings_appearance_header_diveLog => 'Merülesi naplo';

  @override
  String get settings_appearance_header_diveProfile => 'Merülesi profil';

  @override
  String get settings_appearance_header_diveSites => 'Merülohelyek';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility =>
      'Szekció sorrend és láthatóság';

  @override
  String get settings_appearance_diveDetails_sectionOrderVisibility_subtitle =>
      'Válassza ki, mely szekciók jelenjenek meg és milyen sorrendben';

  @override
  String get settings_diveDetailSections_title =>
      'Szekció sorrend és láthatóság';

  @override
  String get settings_diveDetailSections_resetToDefault =>
      'Visszaállítás alapértelmezettre';

  @override
  String get settings_diveDetailSections_fixedSections =>
      'Rögzített szekciók: Fejléc, Merülési profil grafikon';

  @override
  String get settings_diveDetailSections_configurableSections =>
      'Konfigurálható szekciók (húzással rendezhető)';

  @override
  String get diveDetailSection_decoO2_name => 'Deko állapot / Szövetterhelés';

  @override
  String get diveDetailSection_decoO2_description =>
      'NDL, plafon, szövet hőtérkép, O2 toxicitás';

  @override
  String get diveDetailSection_safetyReview_name => 'Biztonsági áttekintés';

  @override
  String get diveDetailSection_safetyReview_description =>
      'Automatikus profilmegfigyelések a merülés után';

  @override
  String get safetyReview_sectionTitle => 'Biztonsági áttekintés';

  @override
  String safetyReview_findingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count megfigyelés',
      one: '1 megfigyelés',
    );
    return '$_temp0';
  }

  @override
  String safetyReview_rapidAscent_title(String rate, String duration) {
    return 'A felemelkedés $duration ideig meghaladta a(z) $rate értéket';
  }

  @override
  String safetyReview_missedDecoStop_title(String excess, String duration) {
    return 'A mélység $duration ideig $excess értékkel az előírt megállási plafon felett volt';
  }

  @override
  String safetyReview_omittedSafetyStop_title(String remaining) {
    return 'Az ajánlott biztonsági megálló $remaining idővel rövidült';
  }

  @override
  String safetyReview_sawtoothProfile_title(int count) {
    return '$count ismételt fel-le mélységváltozás a merülés során';
  }

  @override
  String safetyReview_highSurfaceGf_title(String gf, String gfHigh) {
    return 'Felszínre érkezés $gf gradiens faktorral, a beállított $gfHigh felett';
  }

  @override
  String safetyReview_timeRange(String start, String end) {
    return '$start–$end időpontban';
  }

  @override
  String get safetyReview_dismiss => 'Elvetés';

  @override
  String get safetyReview_restore => 'Visszaállítás';

  @override
  String get safetyReview_dismissAll => 'Összes elvetése';

  @override
  String get safetyReview_restoreAll => 'Összes visszaállítása';

  @override
  String get safetySettings_dismissAll => 'Összes megfigyelés elvetése';

  @override
  String get safetySettings_dismissAll_subtitle =>
      'A naplóban szereplő összes megfigyelés megjelölése átnézettként';

  @override
  String get safetySettings_dismissAll_confirmTitle =>
      'Elveted az összes megfigyelést?';

  @override
  String get safetySettings_dismissAll_confirmBody =>
      'Minden elemzett merülés minden megfigyelése átnézettként lesz megjelölve. Merülésenként visszaállíthatod őket az adott merülés biztonsági áttekintés szakaszában.';

  @override
  String get safetySettings_dismissAll_confirm => 'Összes elvetése';

  @override
  String get safetySettings_dismissAll_cancel => 'Mégse';

  @override
  String safetySettings_dismissAll_progress(int done, int total) {
    return '$done / $total merülés ellenőrizve';
  }

  @override
  String safetySettings_dismissAll_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count megfigyelés elvetve',
      one: '1 megfigyelés elvetve',
      zero: 'Nincs elvetendő megfigyelés',
    );
    return '$_temp0';
  }

  @override
  String safetySettings_dismissAll_doneWithErrors(int count, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count megfigyelés elvetve',
      one: '1 megfigyelés elvetve',
      zero: 'Nem lett megfigyelés elvetve',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failed merülést nem sikerült frissíteni',
      one: '1 merülést nem sikerült frissíteni',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get safetySettings_dismissAll_failed =>
      'A merüléslista nem olvasható. Semmi sem változott.';

  @override
  String get safetySettings_analyzeAll_failed =>
      'A merüléseket nem sikerült elemezni.';

  @override
  String get safetyReview_details => 'Részletek';

  @override
  String get safetyReview_clearHighlight => 'Kiemelés törlése';

  @override
  String safetyReview_findingGroupSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count biztonsági megállapítás',
      one: '1 biztonsági megállapítás',
    );
    return '$_temp0';
  }

  @override
  String get safetySettings_title => 'Biztonsági áttekintés';

  @override
  String get safetySettings_entry_subtitle =>
      'Merülés utáni megfigyelések és szabályok';

  @override
  String get safetySettings_masterToggle =>
      'Merülés utáni biztonsági áttekintés';

  @override
  String get safetySettings_masterToggle_subtitle =>
      'Felemelkedési, megállási és profilmegfigyelések automatikus rögzítése az elemzett merüléseknél';

  @override
  String get safetySettings_rulesHeader => 'Szabályok';

  @override
  String get safetySettings_rule_rapidAscent => 'Gyors felemelkedések';

  @override
  String get safetySettings_rule_missedDecoStop =>
      'Kihagyott vagy lerövidített deko megállók';

  @override
  String get safetySettings_rule_omittedSafetyStop =>
      'Kihagyott biztonsági megállók';

  @override
  String get safetySettings_rule_sawtoothProfile => 'Fűrészfog-profilok';

  @override
  String get safetySettings_rule_highSurfaceGf =>
      'Magas gradiens faktor felszínre érkezéskor';

  @override
  String get safetySettings_analyzeAll => 'Összes merülés elemzése';

  @override
  String get safetySettings_analyzeAll_subtitle =>
      'A biztonsági áttekintés futtatása minden olyan profillal rendelkező merülésen, amely még nincs elemezve';

  @override
  String safetySettings_analyzeAll_progress(int done, int total) {
    return '$done / $total elemezve';
  }

  @override
  String get safetySettings_analyzeAll_done => 'Elemzés kész';

  @override
  String safetySettings_analyzeAll_doneWithErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merülést nem sikerült elemezni',
      one: '1 merülést nem sikerült elemezni',
    );
    return 'Elemzés kész — $_temp0';
  }

  @override
  String safetyReview_showDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elvetett megjelenítése',
      one: '1 elvetett megjelenítése',
    );
    return '$_temp0';
  }

  @override
  String get diveDetailSection_sacSegments_name => 'SAC arány szegmensenként';

  @override
  String get diveDetailSection_sacSegments_description =>
      'SAC szegmentálás fázis/idő szerint';

  @override
  String get diveDetailSection_details_name => 'Részletek';

  @override
  String get diveDetailSection_details_description =>
      'Típus, helyszín, út, búvárközpont, intervallum';

  @override
  String get diveDetailSection_environment_name => 'Környezet';

  @override
  String get diveDetailSection_environment_description =>
      'Levegő/víz hőmérséklet, látótávolság, áramlat';

  @override
  String get diveDetailSection_altitude_name => 'Magasság';

  @override
  String get diveDetailSection_altitude_description =>
      'Magassági érték, kategória, deko követelmény';

  @override
  String get diveDetailSection_tide_name => 'Árapály';

  @override
  String get diveDetailSection_tide_description =>
      'Árapály-ciklus grafikon és időzítés';

  @override
  String get diveDetailSection_reefHealth_name => 'Vízviszonyok';

  @override
  String get diveDetailSection_reefHealth_description =>
      'Műholdas vízviszonyok a merülés napján';

  @override
  String get diveDetailSection_surfaceGps_name => 'Felszíni GPS';

  @override
  String get diveDetailSection_surfaceGps_description =>
      'GPS be-/kiszállási pontok és felszíni sodródás';

  @override
  String get diveLog_detail_section_surfaceGps => 'Felszíni GPS';

  @override
  String get diveLog_detail_surfaceGps_entry => 'Beszállás';

  @override
  String get diveLog_detail_surfaceGps_exit => 'Kiszállás';

  @override
  String get diveLog_detail_label_drift => 'Sodródás';

  @override
  String get diveLog_detail_surfaceGps_entryOnly => 'Beszállási pont rögzítve';

  @override
  String get diveLog_detail_surfaceGps_exitOnly => 'Kiszállási pont rögzítve';

  @override
  String get diveLog_detail_surfaceGps_site => 'Merülőhely';

  @override
  String get diveLog_detail_surfaceGps_track => 'Felszíni nyomvonal';

  @override
  String get diveLog_detail_surfaceGps_showFullTrack => 'Teljes nyomvonal';

  @override
  String diveLog_detail_surfaceGps_trackFixes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pont',
      one: '1 pont',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_detail_locationsMap_title => 'Merülési helyszínek';

  @override
  String get diveLog_detail_coordinatesCopied =>
      'Koordináták a vágólapra másolva';

  @override
  String get diveLog_detail_openInMaps => 'Megnyitás a Térképekben';

  @override
  String get diveDetailSection_weights_name => 'Súlyok';

  @override
  String get diveDetailSection_weights_description =>
      'Súly lebontás, teljes súly';

  @override
  String get diveDetailSection_buoyancy_name => 'Felhajtóerő';

  @override
  String get diveDetailSection_buoyancy_description =>
      'Felhajtóerő a merülés során, ingadozás, ledobható ólom';

  @override
  String get buoyancy_tooltip =>
      'Modellezett nettó felhajtóerő a merülés során a profilból, gázfogyasztásból és felszerelésből.';

  @override
  String buoyancy_verdictBuoyant(String depth, String amount) {
    return 'Az utolsó megállónál (~$depth) körülbelül $amount felhajtóerőd volt';
  }

  @override
  String buoyancy_verdictHeavy(String depth, String amount) {
    return 'Az utolsó megállónál (~$depth) körülbelül $amount-mal nehezebb voltál';
  }

  @override
  String get buoyancy_verdictNeutral =>
      'A konfigurációd közel semleges volt az utolsó megállónál';

  @override
  String get buoyancy_verdictConvention =>
      'Az 5 m-es biztonsági megálló konvenciója szerint becsülve';

  @override
  String get buoyancy_breakdownTitle => 'Tételek részletezése';

  @override
  String get buoyancy_suitTerm => 'Ruha';

  @override
  String get buoyancy_leadTerm => 'Ólom';

  @override
  String get buoyancy_beginNet => 'Merülés kezdete';

  @override
  String get buoyancy_endNet => 'Merülés vége';

  @override
  String get buoyancy_swing => 'Felhajtóerő-ingadozás';

  @override
  String get buoyancy_peakLift => 'Max. szükséges felhajtóerő';

  @override
  String get buoyancy_wingWarning =>
      'Meghaladja a szárnyad névleges felhajtóerejét';

  @override
  String get buoyancy_minDitchable => 'Min. ledobható ólom';

  @override
  String get buoyancy_droppable => 'Ledobható';

  @override
  String get buoyancy_ditchWarning => 'Több, mint amennyit ledobhatsz';

  @override
  String get buoyancy_drysuitGas => 'Hozzáadott szárazruha-gáz';

  @override
  String get buoyancy_estimatedPressures => 'A palacknyomások becsültek';

  @override
  String get buoyancy_linkSuitHint =>
      'Kapcsolj egy búvárruhát ehhez a merüléshez a teljesebb képért';

  @override
  String get buoyancy_noLeadHint =>
      'Nincs rögzített ólom: adj ólmot ehhez a merüléshez, vagy száraz tömeget az ólomfelszerelésedhez';

  @override
  String get buoyancy_chartNet => 'Nettó';

  @override
  String get buoyancy_chartRig => 'Felszerelés + ólom';

  @override
  String get buoyancy_chartMinutes => 'Idő (perc)';

  @override
  String get buoyancy_historyTitle => 'Ólomelőzmények';

  @override
  String get buoyancy_historyCarried => 'Vitt';

  @override
  String get buoyancy_historyModeled => 'Modellezett';

  @override
  String buoyancy_historyMore(String delta) {
    return 'Általában $delta-mal többet viszel, mint amit a modell javasol';
  }

  @override
  String buoyancy_historyLess(String delta) {
    return 'Általában $delta-mal kevesebbet viszel, mint amit a modell javasol';
  }

  @override
  String get buoyancy_throughDive => 'A merülés során';

  @override
  String get buoyancy_adjust => 'Módosítás';

  @override
  String get buoyancy_whatIfTitle => 'Merülés módosítása';

  @override
  String get buoyancy_whatIfLead => 'Ólom';

  @override
  String get buoyancy_whatIfSuit => 'Ruha felhajtóereje';

  @override
  String get buoyancy_whatIfReset => 'Visszaállítás';

  @override
  String buoyancy_whatIfDelta(String delta) {
    return '$delta a ténylegeshez';
  }

  @override
  String get diveDetailSection_tanks_name => 'Palackok';

  @override
  String get diveDetailSection_tanks_description =>
      'Palack lista, gázkeverékek, nyomások, palackonkénti SAC';

  @override
  String get diveDetailSection_buddies_name => 'Merülőpartnerek';

  @override
  String get diveDetailSection_buddies_description =>
      'Merülőpartner lista szerepekkel';

  @override
  String get diveDetailSection_signatures_name => 'Aláírások';

  @override
  String get diveDetailSection_signatures_description =>
      'Partner/oktató aláírás megjelenítése és rögzítése';

  @override
  String get diveDetailSection_equipment_name => 'Felszerelés';

  @override
  String get diveDetailSection_equipment_description =>
      'A merülésen használt felszerelés';

  @override
  String get diveDetailSection_sightings_name =>
      'Tengeri élőlény megfigyelések';

  @override
  String get diveDetailSection_sightings_description =>
      'Megfigyelt fajok, megfigyelési adatok';

  @override
  String get diveDetailSection_media_name => 'Média';

  @override
  String get diveDetailSection_media_description => 'Fotók/videók galériája';

  @override
  String get diveDetailSection_tags_name => 'Címkék';

  @override
  String get diveDetailSection_tags_description => 'Merülési címkék';

  @override
  String get diveDetailSection_notes_name => 'Jegyzetek';

  @override
  String get diveDetailSection_notes_description => 'Merülési jegyzetek/leírás';

  @override
  String get diveDetailSection_customFields_name => 'Egyéni mezők';

  @override
  String get diveDetailSection_customFields_description =>
      'Felhasználó által definiált egyéni mezők';

  @override
  String get diveDetailSection_dataSources_name => 'Adatforrások';

  @override
  String get diveDetailSection_dataSources_description =>
      'Csatlakoztatott merülőszámítógépek, forráskezelés';

  @override
  String get settings_appearance_header_language => 'Nyelv';

  @override
  String get settings_appearance_header_theme => 'Tema';

  @override
  String get settings_appearance_header_mode => 'Mod';

  @override
  String get settings_themes_title => 'Téma kiválasztása';

  @override
  String get settings_themes_current => 'Téma';

  @override
  String get theme_submersion => 'Elmerülés';

  @override
  String get theme_console => 'Konzol';

  @override
  String get theme_tropical => 'Trópusi';

  @override
  String get theme_minimalist => 'Minimalista';

  @override
  String get theme_deep => 'Mély';

  @override
  String get settings_appearance_mapBackgroundDiveCards =>
      'Terkep hatter a merülesi kartyakon';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitle =>
      'Merülohely terkep megjelenites hatterkent a merülesi kartyakon';

  @override
  String get settings_appearance_mapBackgroundDiveCards_subtitleWithNote =>
      'Merülohely terkep megjelenites hatterkent a merülesi kartyakon (merülohely szükseges)';

  @override
  String get settings_appearance_mapBackgroundSiteCards =>
      'Terkep hatter a merülohely kartyakon';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitle =>
      'Terkep megjelenites hatterkent a merülohely kartyakon';

  @override
  String get settings_appearance_mapBackgroundSiteCards_subtitleWithNote =>
      'Terkep megjelenites hatterkent a merülohely kartyakon (merülohely szükseges)';

  @override
  String get settings_appearance_maxDepthMarker => 'Max. melyseg jelolo';

  @override
  String get settings_appearance_maxDepthMarker_subtitle =>
      'Jelolo megjelenites a maximalis melyseg pontjan';

  @override
  String get settings_appearance_maxDepthMarker_subtitleFull =>
      'Jelolo megjelenites a maximalis melyseg pontjan a merülesi profilokon';

  @override
  String get settings_appearance_metric_ascentRateColors =>
      'Felszallasi sebesseg szinek';

  @override
  String get settings_appearance_metric_ceiling => 'Plafon';

  @override
  String get settings_appearance_metric_events => 'Esemenyek';

  @override
  String get settings_appearance_metric_estimatedTankPressure =>
      'Becsült palacknyomás';

  @override
  String get settings_appearance_metric_gasDensity => 'Gaz suruseg';

  @override
  String get settings_appearance_metric_gfPercent => 'GF%';

  @override
  String get settings_appearance_metric_heartRate => 'Szivfrekvencia';

  @override
  String get settings_appearance_metric_meanDepth => 'Atlagmelyseg';

  @override
  String get settings_appearance_metric_ndl => 'NDL';

  @override
  String get settings_appearance_metric_ppHe => 'ppHe';

  @override
  String get settings_appearance_metric_ppN2 => 'ppN2';

  @override
  String get settings_appearance_metric_ppO2 => 'ppO2';

  @override
  String get settings_appearance_metric_pressure => 'Nyomas';

  @override
  String get settings_appearance_metric_sacRate => 'SAC ertek';

  @override
  String get settings_appearance_metric_surfaceGf => 'Felszini GF';

  @override
  String get settings_appearance_metric_temperature => 'Homerseklet';

  @override
  String get settings_appearance_metric_tts => 'TTS (Ido a felszinig)';

  @override
  String get settings_appearance_metric_cns => 'CNS% (O2 toxicitás)';

  @override
  String get settings_appearance_metric_otu => 'OTU (O2 tolerancia egységek)';

  @override
  String get settings_appearance_metric_photoMarkers => 'Fotójelölők';

  @override
  String settings_appearance_metricsEnabledCount(int count, int total) {
    return '$count / $total engedelyezve';
  }

  @override
  String get settings_appearance_pressureThresholdMarkers =>
      'Nyomas küszöbértek jelolok';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitle =>
      'Jelolok megjelenites, amikor a palack nyomas atlepi a küszöbértekeket';

  @override
  String get settings_appearance_pressureThresholdMarkers_subtitleFull =>
      'Jelolok megjelenites, amikor a palack nyomas atlepi a 2/3, 1/2 es 1/3 küszöbértekeket';

  @override
  String get settings_appearance_metricsFollowViewport =>
      'Rétegek nézetben tartása nagyításkor';

  @override
  String get settings_appearance_metricsFollowViewport_subtitle =>
      'Az olyan rétegek, mint az NDL és a ppO2, a látható területhez igazodjanak, ahelyett hogy a mélységtengellyel együtt nagyítódnának';

  @override
  String get settings_appearance_rightYAxisMetric => 'Jobb Y-tengely metrika';

  @override
  String get settings_appearance_rightYAxisMetric_subtitle =>
      'Alapertelmezett metrika a jobb tengelyen';

  @override
  String get settings_appearance_subsection_decompressionMetrics =>
      'Dekompresszios metrikak';

  @override
  String get settings_appearance_subsection_defaultVisibleMetrics =>
      'Alapertelmezett lathato metrikak';

  @override
  String get settings_appearance_subsection_standardMetrics =>
      'Standard Metrics';

  @override
  String get settings_appearance_subsection_gasAnalysisMetrics =>
      'Gaz elemzesi metrikak';

  @override
  String get settings_appearance_subsection_gradientFactorMetrics =>
      'Gradiens faktor metrikak';

  @override
  String get settings_appearance_theme_dark => 'Sötet';

  @override
  String get settings_appearance_theme_light => 'Vilagos';

  @override
  String get settings_appearance_theme_system => 'Rendszer alapertelmezett';

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
  String get settings_backToSettings_tooltip => 'Vissza a beallitasokhoz';

  @override
  String get settings_cloudSync_appBar_title =>
      'Adatbazis felho szinkronizalas';

  @override
  String get settings_cloudSync_autoSync => 'Automatikus szinkronizalas';

  @override
  String get settings_cloudSync_autoSync_subtitle =>
      'Automatikus szinkronizalas valtoztatasok utan';

  @override
  String settings_cloudSync_conflictItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elem figyelmet igenyel',
      one: '1 elem figyelmet igenyel',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_disabledBanner_content =>
      'Az alkalmazas altal kezelt felho szinkronizalas le van tiltva, mert egyedi tarolasi mappat hasznal. A mappa szinkronizaciós szolgaltatasa (Dropbox, Google Drive, OneDrive stb.) kezeli a szinkronizalast.';

  @override
  String get settings_cloudSync_disabledBanner_title =>
      'Felho szinkronizalas letiltva';

  @override
  String get settings_cloudSync_entry_subtitle =>
      'Szinkronizálás felhőtárhelyen keresztül';

  @override
  String get settings_cloudSync_adopt_confirm =>
      'Visszaállított könyvtár átvétele';

  @override
  String settings_cloudSync_adopt_dialogContent(
    String deviceName,
    String date,
  ) {
    return 'A könyvtárat egy biztonsági mentésből cserélték le a(z) \"$deviceName\" eszközön ($date). Az átvétellel ennek az eszköznek az adatai a visszaállított könyvtárra cserélődnek. Először biztonsági mentés készül az eszköz jelenlegi adatairól.';
  }

  @override
  String get settings_cloudSync_adopt_dialogTitle =>
      'Átveszi a visszaállított könyvtárat?';

  @override
  String get settings_cloudSync_adopt_notNow => 'Most nem';

  @override
  String get settings_cloudSync_dangerZone => 'Veszélyes műveletek';

  @override
  String get settings_cloudSync_replaceLibrary_tile => 'Felhőkönyvtár cseréje';

  @override
  String get settings_cloudSync_replaceLibrary_tileSubtitle =>
      'Ennek az eszköznek a könyvtára legyen az, amelyet minden eszköz használ';

  @override
  String get settings_cloudSync_replaceLibrary_dialogTitle =>
      'Lecseréli a felhőkönyvtárat?';

  @override
  String get settings_cloudSync_replaceLibrary_dialogIntro =>
      'Ennek az eszköznek a könyvtára lesz az, amelyet minden eszköz használ.';

  @override
  String settings_cloudSync_replaceLibrary_dialogBody(num diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other:
          'A felhőkönyvtár törlődik, és az eszköz $diveCount merülése lép a helyébe.',
      one: 'A felhőkönyvtár törlődik, és az eszköz 1 merülése lép a helyébe.',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_replaceLibrary_peers(num peerCount) {
    String _temp0 = intl.Intl.pluralLogic(
      peerCount,
      locale: localeName,
      other:
          '$peerCount másik eszköz kap felkérést az átvételre; addig a változásaik nem egyesülnek.',
      one:
          '1 másik eszköz kap felkérést az átvételre; addig a változásai nem egyesülnek.',
      zero:
          'Még egyetlen másik eszköz sem szinkronizál, így nincs mit átvenni.',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_replaceLibrary_peersUnknown =>
      'Minden másik eszköz felkérést kap az átvételre; addig a változásaik nem egyesülnek.';

  @override
  String get settings_cloudSync_replaceLibrary_backupNote =>
      'Előbb biztonsági mentés készül erről az eszközről. A művelet nem vonható vissza.';

  @override
  String get settings_cloudSync_replaceLibrary_confirmWord => 'Csere';

  @override
  String get settings_cloudSync_replaceLibrary_confirmHint =>
      'Írja be: \"Csere\" a megerősítéshez';

  @override
  String get settings_cloudSync_replaceLibrary_confirm => 'Csere';

  @override
  String get settings_cloudSync_firstSync_banner =>
      'Az első szinkronizálás megerősítésre vár. Koppintson a \'Szinkronizálás most\' gombra, hogy átnézze, mi kerül összevonásra.';

  @override
  String get settings_cloudSync_firstSync_dialogConfirm =>
      'Összevonás és szinkronizálás';

  @override
  String get settings_cloudSync_firstSync_replaceHint =>
      'Ha ehelyett ennek az eszköznek a könyvtára írja felül a felhőben lévőt, szakítsa meg, és használja a Beállítások > Felhőszinkronizálás > Felhőkönyvtár cseréje lehetőséget.';

  @override
  String settings_cloudSync_firstSync_dialogContent(
    int deviceCount,
    int diveCount,
  ) {
    return 'Meglévő szinkronizálási adatok találhatók a felhőben ($deviceCount szinkronizálási fájl). Az első szinkronizálás ezeket az adatokat összevonja az ezen az eszközön található $diveCount merüléssel, minden szinkronizált eszközön.\n\nHa ugyanazokat a merüléseket minden eszközön külön adták hozzá, kétszer fognak megjelenni.';
  }

  @override
  String get settings_cloudSync_firstSync_dialogTitle =>
      'Könyvtárak összevonása?';

  @override
  String settings_cloudSync_replace_banner(String deviceName) {
    return 'A szinkronizálás szünetel: a könyvtárat egy biztonsági mentésből cserélték le a(z) \"$deviceName\" eszközön. Koppintson a Szinkronizálás most gombra az áttekintéshez.';
  }

  @override
  String get settings_cloudSync_switch_dialogTitle =>
      'Vált a szinkronizálási szolgáltatón?';

  @override
  String settings_cloudSync_switch_dialogContent(
    String fromName,
    String toName,
  ) {
    return 'Az adatai nem kerülnek el a(z) $fromName szolgáltatóról – ott maradnak, amíg nem törli őket. A váltás után ennek az eszköznek a következő szinkronizálása összevonja az adatait azzal, ami már a(z) $toName szolgáltatón található. A többi eszköze továbbra is a(z) $fromName szolgáltatót használja, amíg azokon is át nem vált.';
  }

  @override
  String get settings_cloudSync_switch_confirm => 'Váltás';

  @override
  String settings_cloudSync_moved_banner(
    String deviceName,
    String destination,
  ) {
    return 'A(z) $deviceName áthelyezte ezt a könyvtárat ide: $destination. Ezt a szolgáltatót már nem frissíti. Válassza a(z) $destination lehetőséget alább a költözés követéséhez.';
  }

  @override
  String get settings_cloudSync_moved_dismiss => 'Elvetés';

  @override
  String settings_cloudSync_cleanup_banner(String backend) {
    return 'Régi szinkronizálási adatok vannak még tárolva a(z) $backend szolgáltatón a szolgáltatóváltás előttről. Ezeket már nem használja a rendszer.';
  }

  @override
  String get settings_cloudSync_cleanup_delete => 'Régi adatok törlése';

  @override
  String get settings_cloudSync_cleanup_keep => 'Megtartás';

  @override
  String get settings_cloudSync_header_advanced => 'Halado';

  @override
  String get settings_cloudSync_signOut_backupWarning =>
      'A felhőalapú biztonsági mentés kikapcsol, és a mentések az alapértelmezett helyre kerülnek.';

  @override
  String get settings_cloudSync_header_cloudProvider => 'Felho szolgaltato';

  @override
  String settings_cloudSync_header_conflicts(Object count) {
    return 'Ütközesek ($count)';
  }

  @override
  String get settings_cloudSync_header_syncBehavior =>
      'Szinkronizalasi viselkedes';

  @override
  String settings_cloudSync_lastSynced(Object time) {
    return 'Utolso szinkronizalas: $time';
  }

  @override
  String settings_cloudSync_pendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count függo valtoztatas',
      one: '1 függo valtoztatas',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_banner(Object deviceList) {
    return '$deviceList még régebbi vagy ismeretlen könyvtárverziót használ, ezért a változásai nem lettek egyesítve. Nyissa meg rajta a Submersiont az aktuális könyvtár átvételéhez.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_bannerPlural(Object deviceList) {
    return '$deviceList még régebbi vagy ismeretlen könyvtárverziót használnak, ezért a változásaik nem lettek egyesítve. Nyissa meg rajtuk a Submersiont az aktuális könyvtár átvételéhez.';
  }

  @override
  String settings_cloudSync_peerNeedsAdopt_unnamedDevice(Object shortId) {
    return '$shortId eszköz';
  }

  @override
  String get settings_cloudSync_peerNeedsAdopt_listSeparator => ', ';

  @override
  String get settings_cloudSync_peerNeedsAdopt_listLastSeparator => ' és ';

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamed(Object deviceList) {
    return '$deviceList a Submersion újabb verziójából szinkronizál, ezért a legújabb változtatásai egyelőre visszatartva maradnak.';
  }

  @override
  String settings_cloudSync_peerRequiresUpdate_bannerNamedPlural(
    Object deviceList,
  ) {
    return '$deviceList a Submersion újabb verziójából szinkronizálnak, ezért a legújabb változtatásaik egyelőre visszatartva maradnak.';
  }

  @override
  String get settings_cloudSync_peerRequiresUpdate_updateAction =>
      'Frissítsd ezt az eszközt, hogy megkapd őket.';

  @override
  String get settings_cloudSync_peerRequiresUpdate_storeAction =>
      'Automatikusan érvénybe lépnek, amint megérkezik az eszköz alkalmazásbolti frissítése; a frissítés még ellenőrzés alatt állhat.';

  @override
  String get settings_cloudSync_provider_connected => 'Csatlakoztatva';

  @override
  String settings_cloudSync_provider_connectedTo(Object providerName) {
    return 'Csatlakoztatva: $providerName';
  }

  @override
  String settings_cloudSync_provider_connectionFailed(
    Object providerName,
    Object error,
  ) {
    return '$providerName csatlakozas sikertelen: $error';
  }

  @override
  String get settings_cloudSync_dropbox_account_title => 'Dropbox-fiók';

  @override
  String get settings_cloudSync_dropbox_connect_browserFailed =>
      'Nem sikerült megnyitni a böngészőt. Próbáld a Böngésző újranyitása gombot.';

  @override
  String get settings_cloudSync_dropbox_connect_codeLabel =>
      'Engedélyezési kód';

  @override
  String get settings_cloudSync_dropbox_connect_emptyCode =>
      'Add meg a böngésződben megjelenő engedélyezési kódot';

  @override
  String settings_cloudSync_dropbox_connect_failed(Object error) {
    return 'Nem sikerült csatlakozni a Dropboxhoz: $error';
  }

  @override
  String get settings_cloudSync_dropbox_connect_instructions =>
      'A böngésződ megnyitott egy Dropbox engedélyezési oldalt. Engedélyezd a hozzáférést, majd illeszd be ide a Dropbox által mutatott kódot.';

  @override
  String get settings_cloudSync_dropbox_connect_reopenBrowser =>
      'Böngésző újranyitása';

  @override
  String get settings_cloudSync_dropbox_connect_submit => 'Csatlakozás';

  @override
  String get settings_cloudSync_dropbox_connect_title =>
      'Dropbox csatlakoztatása';

  @override
  String get settings_cloudSync_dropbox_connected =>
      'Csatlakoztatva a Dropboxhoz';

  @override
  String settings_cloudSync_dropbox_connectedAs(Object account) {
    return 'Csatlakoztatva mint $account';
  }

  @override
  String get settings_cloudSync_dropbox_disconnect => 'Leválasztás';

  @override
  String get settings_cloudSync_provider_dropbox_subtitle =>
      'Szinkronizálás Dropboxon keresztül (Apps/Submersion)';

  @override
  String get settings_cloudSync_provider_dropbox_title => 'Dropbox';

  @override
  String get settings_cloudSync_provider_googleDrive => 'Google Drive';

  @override
  String get settings_cloudSync_provider_googleDrive_subtitle =>
      'Szinkronizalas Google Drive-on keresztül';

  @override
  String get settings_cloudSync_googleDrive_desktopNotConfigured =>
      'Ebben a buildben nem érhető el';

  @override
  String get settings_cloudSync_googleDrive_browserWait_title =>
      'Folytassa a böngészőjében';

  @override
  String get settings_cloudSync_googleDrive_browserWait_message =>
      'Fejezze be a Google-bejelentkezést a webböngészőjében, majd térjen vissza a Submersionbe.';

  @override
  String get settings_cloudSync_provider_icloud => 'iCloud';

  @override
  String settings_cloudSync_provider_initFailed(Object providerName) {
    return 'Nem sikerült a(z) $providerName szolgaltato inicializalasa';
  }

  @override
  String get settings_cloudSync_provider_notAvailable =>
      'Nem erheto el ezen a platformon';

  @override
  String get settings_cloudSync_provider_s3_edit =>
      'S3-konfiguráció szerkesztése';

  @override
  String get settings_cloudSync_provider_s3_subtitle =>
      'Bármely S3-kompatibilis tárolószolgáltatással működik';

  @override
  String get settings_cloudSync_provider_s3_title => 'S3-kompatibilis tároló';

  @override
  String get settings_cloudSync_resetDialog_cancel => 'Megse';

  @override
  String get settings_cloudSync_resetDialog_content =>
      'Ez torli az osszes szinkronizalas-elozmenyeket es ujrakezdi. Az adatok nem törlodnek, de a kovetkezo szinkronizalaskor ütközeseket kell feloldania.';

  @override
  String get settings_cloudSync_resetDialog_reset => 'Visszaallitas';

  @override
  String get settings_cloudSync_resetDialog_title =>
      'Szinkronizalas allapot visszaallitasa?';

  @override
  String get settings_cloudSync_resetSuccess =>
      'Szinkronizalas allapot visszaallitva';

  @override
  String get settings_cloudSync_resetSyncState =>
      'Szinkronizalas allapot visszaallitasa';

  @override
  String get settings_cloudSync_resetSyncState_subtitle =>
      'Szinkronizalas elozmenyeinek torlese es ujrakezdés';

  @override
  String get settings_cloudSync_resolveConflicts => 'Ütközesek feloldasa';

  @override
  String get settings_cloudSync_selectProviderHint =>
      'Valasszon felho szolgaltatot a szinkronizalas engedelyezesehez';

  @override
  String get settings_cloudSync_signOut => 'Kijelentkezes';

  @override
  String get settings_cloudSync_signOutDialog_cancel => 'Megse';

  @override
  String get settings_cloudSync_signOutDialog_content =>
      'Ez levalasztja a felho szolgaltatorol. A helyi adatok sertetetlenek maradnak.';

  @override
  String get settings_cloudSync_signOutDialog_signOut => 'Kijelentkezes';

  @override
  String get settings_cloudSync_signOutDialog_title => 'Kijelentkezes?';

  @override
  String get settings_cloudSync_signOutSuccess =>
      'Kijelentkezve a felho szolgaltatobol';

  @override
  String get settings_cloudSync_signOut_subtitle =>
      'Levalasztas a felho szolgaltatorol';

  @override
  String get settings_cloudSync_status_conflictsDetected =>
      'Ütközesek eszlelve';

  @override
  String get settings_cloudSync_status_readyToSync =>
      'Keszen all a szinkronizalasra';

  @override
  String get settings_cloudSync_status_syncComplete =>
      'Szinkronizalas befejezve';

  @override
  String get settings_cloudSync_status_syncError => 'Szinkronizalasi hiba';

  @override
  String get settings_cloudSync_status_syncing => 'Szinkronizalas...';

  @override
  String get settings_cloudSync_storageSettings => 'Tarolasi beallitasok';

  @override
  String get settings_cloudSync_syncNow => 'Szinkronizálás most';

  @override
  String get settings_cloudSync_syncOnLaunch => 'Szinkronizalas inditaskor';

  @override
  String get settings_cloudSync_syncOnLaunch_subtitle =>
      'Frissitesek ellenorzese inditaskor';

  @override
  String get settings_cloudSync_syncOnResume => 'Szinkronizalas folytatáskor';

  @override
  String get settings_cloudSync_syncOnResume_subtitle =>
      'Frissitesek ellenorzése az alkalmazas aktivalasakor';

  @override
  String settings_cloudSync_syncProgressPercent(Object percent) {
    return 'Szinkronizalas haladasa: $percent szazalek';
  }

  @override
  String settings_cloudSync_time_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count napja',
      one: '1 napja',
    );
    return '$_temp0';
  }

  @override
  String settings_cloudSync_time_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oraja',
      one: '1 oraja',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_time_justNow => 'Most';

  @override
  String settings_cloudSync_time_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perce',
      one: '1 perce',
    );
    return '$_temp0';
  }

  @override
  String get settings_conflict_applyAll => 'Alkalmaz mindet';

  @override
  String get settings_conflict_cancel => 'Megse';

  @override
  String get settings_conflict_chooseResolution => 'Feloldas valasztasa';

  @override
  String get settings_conflict_close => 'Bezaras';

  @override
  String get settings_conflict_close_tooltip => 'Ütközes párbeszed bezarasa';

  @override
  String settings_conflict_counterLabel(Object current, Object total) {
    return '$current. ütközes a(z) $total közül';
  }

  @override
  String settings_conflict_errorLoading(Object error) {
    return 'Hiba az ütközesek betoltesekor: $error';
  }

  @override
  String get settings_conflict_keepBoth => 'Mindketto megtartasa';

  @override
  String get settings_conflict_keepLocal => 'Helyi megtartasa';

  @override
  String get settings_conflict_keepRemote => 'Tavoli megtartasa';

  @override
  String get settings_conflict_localVersion => 'Helyi valtozat';

  @override
  String settings_conflict_modified(Object time) {
    return 'Modositva: $time';
  }

  @override
  String get settings_conflict_next_tooltip => 'Kovetkezo ütközes';

  @override
  String get settings_conflict_noConflicts_message =>
      'Minden szinkronizalasi ütközes feloldva.';

  @override
  String get settings_conflict_noConflicts_title => 'Nincsenek ütközesek';

  @override
  String get settings_conflict_noDataAvailable => 'Nincs elerheto adat';

  @override
  String get settings_conflict_previous_tooltip => 'Elozo ütközes';

  @override
  String get settings_conflict_ref_buddy => 'Buvartars';

  @override
  String get settings_conflict_ref_certification => 'Kepesites';

  @override
  String get settings_conflict_ref_checklistTemplate => 'Ellenorzolista sablon';

  @override
  String get settings_conflict_ref_connectedAccount => 'Csatlakoztatott fiok';

  @override
  String get settings_conflict_ref_course => 'Tanfolyam';

  @override
  String get settings_conflict_ref_courseRequirement =>
      'Tanfolyami kovetelmeny';

  @override
  String get settings_conflict_ref_cylinderConfig => 'Palackkonfiguracio';

  @override
  String get settings_conflict_ref_dataSource => 'Adatforras';

  @override
  String get settings_conflict_ref_dive => 'Merules';

  @override
  String get settings_conflict_ref_diveCenter => 'Merulocentrum';

  @override
  String get settings_conflict_ref_diveComputer => 'Merulesszamitogep';

  @override
  String get settings_conflict_ref_divePlan => 'Merulesi terv';

  @override
  String get settings_conflict_ref_diveSite => 'Merulohely';

  @override
  String get settings_conflict_ref_diveType => 'Merules tipusa';

  @override
  String get settings_conflict_ref_diver => 'Merulo';

  @override
  String get settings_conflict_ref_equipment => 'Felszereles';

  @override
  String get settings_conflict_ref_equipmentSet => 'Felszereleskeszlet';

  @override
  String get settings_conflict_ref_finding => 'Eszrevetel';

  @override
  String get settings_conflict_ref_instructor => 'Oktato';

  @override
  String get settings_conflict_ref_linkedDive => 'Kapcsolt merules';

  @override
  String get settings_conflict_ref_media => 'Media';

  @override
  String get settings_conflict_ref_mediaSubscription => 'Media-elofizetes';

  @override
  String get settings_conflict_ref_missing => 'Mar nincs ebben a konyvtarban';

  @override
  String settings_conflict_ref_named(Object name, Object date) {
    return '$name ($date)';
  }

  @override
  String get settings_conflict_ref_plannedTank => 'Tervezett palack';

  @override
  String get settings_conflict_ref_preDiveChecklistTemplate =>
      'Merules elotti ellenorzolista sablon';

  @override
  String get settings_conflict_ref_preDiveSession =>
      'Merules elotti ellenorzolista';

  @override
  String get settings_conflict_ref_relatedDive => 'Kapcsolodo merules';

  @override
  String get settings_conflict_ref_serviceKind => 'Szerviz tipusa';

  @override
  String get settings_conflict_ref_sighting => 'Eszleles';

  @override
  String get settings_conflict_ref_signer => 'Alairta';

  @override
  String get settings_conflict_ref_sourceDive => 'Forras merules';

  @override
  String get settings_conflict_ref_species => 'Fajok';

  @override
  String get settings_conflict_ref_tag => 'Cimke';

  @override
  String get settings_conflict_ref_tank => 'Palack';

  @override
  String get settings_conflict_ref_trip => 'Utazas';

  @override
  String get settings_conflict_remoteVersion => 'Tavoli valtozat';

  @override
  String settings_conflict_resolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ütközes',
      one: '1 ütközes',
    );
    return '$_temp0 feloldva';
  }

  @override
  String get settings_conflict_title => 'Ütközesek feloldasa';

  @override
  String get settings_data_appDefaultLocation =>
      'Alkalmazas alapertelmezett helye';

  @override
  String get settings_data_backup => 'Biztonsagi mentes es visszaallitas';

  @override
  String get settings_data_backup_subtitle =>
      'Biztonsagi mentes keszitese az adatokrol';

  @override
  String get settings_data_cloudSync => 'Adatbazis felho szinkronizalas';

  @override
  String get settings_data_customFolder => 'Egyedi mappa';

  @override
  String get settings_data_databaseStorage => 'Adatbazis tarolas';

  @override
  String get settings_data_export_completed => 'Exportalas befejezve';

  @override
  String get settings_data_export_exporting => 'Exportalas...';

  @override
  String settings_data_export_failed(Object error) {
    return 'Exportalas sikertelen: $error';
  }

  @override
  String get settings_data_header_backupSync =>
      'Biztonsagi mentes es szinkronizalas';

  @override
  String get settings_data_header_storage => 'Tarolas';

  @override
  String get settings_data_import_completed => 'Muvelet befejezve';

  @override
  String settings_data_import_failed(Object error) {
    return 'Muvelet sikertelen: $error';
  }

  @override
  String get settings_data_offlineMaps => 'Offline terkepek';

  @override
  String get settings_data_offlineMaps_subtitle =>
      'Terkepek letöltese offline hasznalathoz';

  @override
  String get settings_data_restore => 'Visszaallitas';

  @override
  String get settings_data_restoreDialog_cancel => 'Megse';

  @override
  String get settings_data_restoreDialog_content =>
      'Figyelmeztetés: A biztonsagi mentesbol valo visszaallitas MINDEN jelenlegi adatot felülir a mentett adatokkal. Ez a muvelet nem vonhato vissza.\n\nBiztosan folytatja?';

  @override
  String get settings_data_restoreDialog_restore => 'Visszaallitas';

  @override
  String get settings_data_restoreDialog_title =>
      'Biztonsagi mentes visszaallitasa';

  @override
  String get settings_data_restore_subtitle =>
      'Visszaallitas biztonsagi mentesbol';

  @override
  String settings_data_syncTime_daysAgo(Object count) {
    return '$count napja';
  }

  @override
  String settings_data_syncTime_hoursAgo(Object count) {
    return '$count oraja';
  }

  @override
  String get settings_data_syncTime_justNow => 'Most';

  @override
  String settings_data_syncTime_minutesAgo(Object count) {
    return '$count perce';
  }

  @override
  String settings_data_sync_lastSynced(Object time) {
    return 'Utolso szinkronizalas: $time';
  }

  @override
  String get settings_data_sync_notConfigured => 'Nincs konfigurálva';

  @override
  String get settings_data_sync_syncing => 'Szinkronizalas...';

  @override
  String get settings_decompression_aboutContent =>
      'A Gradiens Faktorok (GF) szabalyozzak, mennyire konzervatív a dekompressziós szamitas. A GF Low a mely megallokra, mig a GF High a sekely megallokra hat.\n\nAlacsonyabb ertekek = konzervativabb = hosszabb deko megallok\nMagasabb ertekek = kevesbe konzervatív = rovidebb deko megallok';

  @override
  String get settings_decompression_aboutTitle => 'Gradiens Faktorokrol';

  @override
  String get settings_decompression_currentSettings => 'Jelenlegi beallitasok';

  @override
  String get settings_decompression_dialog_cancel => 'Megse';

  @override
  String get settings_decompression_dialog_conservatismHint =>
      'Alacsonyabb ertekek = konzervativabb (hosszabb NDL/tobb deko)';

  @override
  String get settings_decompression_dialog_customValues => 'Egyedi ertekek';

  @override
  String get settings_decompression_dialog_gfHigh => 'GF High';

  @override
  String get settings_decompression_dialog_gfLow => 'GF Low';

  @override
  String get settings_decompression_dialog_info =>
      'A GF Low/High szabalyozza, mennyire konzervativak az NDL es deko szamitasok.';

  @override
  String get settings_decompression_dialog_presets =>
      'Elore beallitott ertekek';

  @override
  String get settings_decompression_dialog_save => 'Mentes';

  @override
  String get settings_decompression_dialog_title => 'Gradiens Faktorok';

  @override
  String settings_decompression_gfValue(Object gfLow, Object gfHigh) {
    return 'GF $gfLow/$gfHigh';
  }

  @override
  String get settings_decompression_header_gradientFactors =>
      'Gradiens Faktorok';

  @override
  String get settings_decompression_header_oxygenToxicity => 'Oxigéntoxicitás';

  @override
  String settings_decompression_preset_selectLabel(Object presetName) {
    return '$presetName konzervativizmus elore beallitott ertek kivalasztasa';
  }

  @override
  String get settings_decompression_header_narcosis => 'Narkózis';

  @override
  String get settings_decompression_o2Narcotic => 'O2 narkotikus';

  @override
  String get settings_decompression_o2Narcotic_subtitle =>
      'Ha be van kapcsolva, az O2 és az N2 egyaránt narkotikusnak számít (konzervatívabb). Ha ki van kapcsolva, csak az N2 járul hozzá a narkózishoz.';

  @override
  String get settings_decompression_endLimit => 'END határ';

  @override
  String get settings_decompression_endLimit_subtitle =>
      'MND számításokhoz használt maximális ekvivalens narkotikus mélység';

  @override
  String get settings_decompression_endLimit_dialog_title => 'END határ';

  @override
  String get settings_decompression_cnsMethodTitle => 'CNS-számítás';

  @override
  String get settings_decompression_cnsMethodClassic =>
      'NOAA-táblázat, lépcsős (klasszikus)';

  @override
  String get settings_decompression_cnsMethodClassicDesc =>
      'Minden 0,1 bar-os sávot a szigorúbb szélén számol. A Submersion eredeti módszere.';

  @override
  String get settings_decompression_cnsMethodShearwater =>
      'Lineáris interpoláció (Shearwater-stílus)';

  @override
  String get settings_decompression_cnsMethodShearwaterDesc =>
      'A NOAA-határértékek között lineárisan interpolál, ahogyan a Shearwater dokumentálja. A legtöbb búvárcomputerrel megegyezik.';

  @override
  String get settings_decompression_cnsMethodSubsurface =>
      'Exponenciális illesztés (mint a Subsurface)';

  @override
  String get settings_decompression_cnsMethodSubsurfaceDesc =>
      'Sima görbeillesztés a NOAA-táblázatra. Megegyezik a Subsurface által számított CNS-értékkel.';

  @override
  String get settings_decompression_cnsMethodAboutTitle =>
      'Ezekről a módszerekről';

  @override
  String get settings_decompression_cnsMethodAboutBody =>
      'Mindhárom módszer a NOAA Diving Manual oxigénterhelési határértékein alapul (300 perc 1,0 bar ppO2 mellett, 45 perc 1,6 bar mellett). A táblázat csak 0,1 bar-os lépésekben határoz meg határértékeket: a klasszikus módszer egy sávon belül mindent a sáv szigorúbb szélén számol, ami a bejegyzések közötti terhelést rendszeresen túlbecsüli. A Shearwater búvárcomputerei a NOAA-határértékek közötti lineáris interpolációt dokumentálják, 1,65 bar felett rögzített, percenkénti 15%-kal. A Subsurface 2019-ben a táblázatos kikeresést egy sima, kétszakaszos exponenciális illesztésre cserélte ugyanazokra a NOAA-adatokra (Robert C. Helling), amely 1,6 bar felett is természetesen kiterjed. A táblázat bejegyzései között a két sima módszer körülbelül egy CNS-ponton belül megegyezik; a klasszikus módszer magasabb értéket mutat.';

  @override
  String get settings_decompression_cnsMethodDisclaimer =>
      'A nevek a megfelelő projektek és gyártók közzétett módszereire utalnak; ez nem jelent semmilyen kapcsolatot vagy támogatást. A számított értékek eltérhetnek a búvárcomputer tényleges kijelzéseitől.';

  @override
  String get settings_decompression_cnsMethodSourcesTitle => 'Források';

  @override
  String get settings_linkOpenFailed => 'A hivatkozást nem sikerült megnyitni.';

  @override
  String get settings_decompression_cnsMethodSourceNoaa =>
      'NOAA: Diving Program (a NOAA Diving Manual kiadója)';

  @override
  String get settings_decompression_cnsMethodSourceShearwater =>
      'Shearwater: A CNS oxigénórája';

  @override
  String get settings_decompression_cnsMethodSourceTheoreticalDiver =>
      'The Theoretical Diver: A CNS oxigéntoxicitás számítása';

  @override
  String get settings_decompression_cnsMethodSourceSubsurface =>
      'Subsurface: megvalósítás (divelist.cpp)';

  @override
  String get settings_existingDb_cancel => 'Megse';

  @override
  String get settings_existingDb_continue => 'Folytatas';

  @override
  String get settings_existingDb_current => 'Jelenlegi';

  @override
  String get settings_existingDb_dialog_message =>
      'Egy Submersion adatbazis mar letezik ebben a mappaban.';

  @override
  String get settings_existingDb_dialog_title => 'Letezo adatbazis talalva';

  @override
  String get settings_existingDb_existing => 'Letezo';

  @override
  String get settings_existingDb_replaceWarning =>
      'A letezo adatbazisrol biztonsagi mentes keszül a csere elott.';

  @override
  String get settings_existingDb_replaceWithMyData =>
      'Csere a sajat adataimmal';

  @override
  String get settings_existingDb_replaceWithMyData_subtitle =>
      'Felüliras a jelenlegi adatbazissal';

  @override
  String get settings_existingDb_stat_buddies => 'Merülopartnerek';

  @override
  String get settings_existingDb_stat_dives => 'Merülesek';

  @override
  String get settings_existingDb_stat_sites => 'Merülohelyek';

  @override
  String get settings_existingDb_stat_trips => 'Utak';

  @override
  String get settings_existingDb_stat_users => 'Felhasznalok';

  @override
  String get settings_existingDb_unknown => 'Ismeretlen';

  @override
  String get settings_existingDb_useExisting => 'Letezo adatbazis hasznalata';

  @override
  String get settings_existingDb_useExisting_subtitle =>
      'Valtas az ebben a mappaban levo adatbazisra';

  @override
  String get settings_gfPreset_custom_description => 'Sajat ertekek megadasa';

  @override
  String get settings_gfPreset_custom_name => 'Egyedi';

  @override
  String get settings_gfPreset_high_description =>
      'Legkonzervativabb, hosszabb deko megallok';

  @override
  String get settings_gfPreset_high_name => 'Magas';

  @override
  String get settings_gfPreset_low_description =>
      'Legkevesbe konzervatív, rovidebb deko';

  @override
  String get settings_gfPreset_low_name => 'Alacsony';

  @override
  String get settings_gfPreset_medium_description =>
      'Kiegyensulyozott megközelites';

  @override
  String get settings_gfPreset_medium_name => 'Közepes';

  @override
  String get settings_import_cancelButton => 'Importalas megszakitasa';

  @override
  String get settings_import_cancelling => 'Megszakitas...';

  @override
  String get settings_import_dialog_title => 'Adatok importalasa';

  @override
  String get settings_import_doNotClose => 'Kerem, ne zarja be az alkalmazast';

  @override
  String settings_import_itemCount(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get settings_import_phase_buddies => 'Merülopartnerek importalasa...';

  @override
  String get settings_import_phase_certifications =>
      'Tanusitványok importalasa...';

  @override
  String get settings_import_phase_complete => 'Befejez...';

  @override
  String get settings_import_phase_diveCenters =>
      'Merülokozpontok importalasa...';

  @override
  String get settings_import_phase_diveTypes =>
      'Merüles tipusok importalasa...';

  @override
  String get settings_import_phase_dives => 'Merülesek importalasa...';

  @override
  String get settings_import_phase_equipment => 'Felszereles importalasa...';

  @override
  String get settings_import_phase_equipmentSets =>
      'Felszereles szettek importalasa...';

  @override
  String get settings_import_phase_parsing => 'Fajl elemzese...';

  @override
  String get settings_import_phase_preparing => 'Elokeszites...';

  @override
  String get settings_import_phase_sites => 'Merülohelyek importalasa...';

  @override
  String get settings_import_phase_tags => 'Cimkek importalasa...';

  @override
  String get settings_import_phase_trips => 'Utak importalasa...';

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
    return '$phase, $current / $total';
  }

  @override
  String settings_import_progressPercent(Object percent) {
    return 'Importalas haladasa: $percent szazalek';
  }

  @override
  String get settings_language_appBar_title => 'Nyelv';

  @override
  String get settings_language_selected => 'Kivalasztva';

  @override
  String get settings_language_systemDefault => 'Rendszer alapertelmezett';

  @override
  String get settings_lightroom_albumFilter_all => 'Teljes katalógus';

  @override
  String get settings_lightroom_albumFilter_title => 'Vizsgálandó albumok';

  @override
  String get settings_lightroom_autoPoll_title =>
      'Új fotók automatikus keresése';

  @override
  String settings_lightroom_clientId_help(String redirectUri) {
    return 'Hozz létre egy integrációt az Adobe Developer Console-ban a Lightroom Services API-val és egy PKCE-t támogató hitelesítőtípussal. Add meg alább a hitelesítő adatod átirányítási URI-jét — a Native App hitelesítők egyedi sémát használnak —, vagy hagyd üresen a(z) $redirectUri használatához.';
  }

  @override
  String get settings_lightroom_clientId_label => 'Adobe kliensazonosító';

  @override
  String get settings_lightroom_clientSecret_label =>
      'Klienstitok (nem kötelező)';

  @override
  String get settings_lightroom_redirectUri_label =>
      'Átirányítási URI (nem kötelező)';

  @override
  String get settings_lightroom_connect => 'Lightroom csatlakoztatása';

  @override
  String get settings_lightroom_connectEmbedded => 'Csatlakozás az Adobe-hoz';

  @override
  String get settings_lightroom_advancedByo =>
      'Saját Adobe hitelesítő adatok használata';

  @override
  String get settings_lightroom_connect_codeLabel =>
      'Átirányított URL vagy kód';

  @override
  String get settings_lightroom_connect_emptyCode =>
      'Illeszd be az átirányított URL-t vagy az engedélyezési kódot';

  @override
  String settings_lightroom_connect_failed(String error) {
    return 'Nem sikerült csatlakozni a Lightroomhoz: $error';
  }

  @override
  String get settings_lightroom_connect_instructions =>
      'Jelentkezz be az Adobe-fiókodba a böngészőablakban, majd illeszd be annak az oldalnak a teljes címét, ahová érkezel (ez tartalmazza az engedélyezési kódot).';

  @override
  String get settings_lightroom_connect_reopenBrowser => 'Böngésző újranyitása';

  @override
  String get settings_lightroom_connect_submit => 'Csatlakozás';

  @override
  String get settings_lightroom_connect_title => 'Lightroom csatlakoztatása';

  @override
  String settings_lightroom_connected(String name) {
    return 'Csatlakozva mint $name';
  }

  @override
  String get settings_lightroom_disconnect => 'Leválasztás';

  @override
  String get settings_lightroom_disconnect_confirmBody =>
      'A összekapcsolt fotók a merüléseidnél maradnak, és továbbra is a médiatárolóból jelennek meg. Az új fotók már nem lesznek párosítva.';

  @override
  String get settings_lightroom_disconnect_confirmTitle =>
      'Leválasztod a Lightroomot?';

  @override
  String settings_lightroom_lastPoll(String when) {
    return 'Utolsó ellenőrzés: $when';
  }

  @override
  String get settings_lightroom_needsReauth => 'Újracsatlakozás szükséges';

  @override
  String get settings_lightroom_scanNow => 'Lightroom átvizsgálása';

  @override
  String get settings_lightroom_scan_running => 'Lightroom vizsgálata...';

  @override
  String settings_lightroom_scan_summary(
    int attached,
    int suggested,
    int skipped,
  ) {
    return '$attached összekapcsolva, $suggested javasolva, $skipped már összekapcsolva';
  }

  @override
  String get settings_lightroom_subtitle =>
      'Fotók és videók automatikus hozzárendelése a merülésekhez';

  @override
  String get settings_lightroom_title => 'Adobe Lightroom';

  @override
  String get settings_manage_checklistTemplates => 'Ellenőrzőlista-sablonok';

  @override
  String get settings_manage_checklistTemplates_subtitle =>
      'Újrafelhasználható tennivalólisták az utak tervezéséhez';

  @override
  String get settings_manage_diveRoles => 'Merülési szerepek';

  @override
  String get settings_manage_diveRoles_subtitle =>
      'Egyedi merülési szerepek kezelése';

  @override
  String get settings_manage_diveTypes => 'Merüles tipusok';

  @override
  String get settings_manage_diveTypes_subtitle =>
      'Egyedi merüles tipusok kezelese';

  @override
  String get settings_manage_header_manageData => 'Adatok kezelese';

  @override
  String get settings_manage_species => 'Fajok';

  @override
  String get settings_manage_species_subtitle =>
      'Tengeri elolenyek fajkatalogusanak kezelese';

  @override
  String get settings_manage_tags => 'Címkék';

  @override
  String get settings_manage_tags_subtitle =>
      'Címkék kezelése, összevonása és törlése';

  @override
  String get settings_manage_tankPresets => 'Palack elore beallitott ertekek';

  @override
  String get settings_manage_tankPresets_subtitle =>
      'Egyedi palack konfiguraciok kezelese';

  @override
  String get settings_manage_serviceTypes => 'Szerviz típusok';

  @override
  String get settings_manage_serviceTypes_subtitle =>
      'Milyen karbantartást igényel a felszerelésed, és milyen gyakran';

  @override
  String get settings_migrationProgress_doNotClose =>
      'Kerem, ne zarja be az alkalmazast';

  @override
  String get settings_migration_backupInfo =>
      'Az athelyezes elott biztonsagi mentes keszül. Az adatok nem vesznek el.';

  @override
  String get settings_migration_cancel => 'Megse';

  @override
  String get settings_migration_cloudSyncWarning =>
      'Az alkalmazas altal kezelt felho szinkronizalas letiltasra kerül. A mappa szinkronizacios szolgaltatasa kezeli a szinkronizalast.';

  @override
  String get settings_migration_dialog_message =>
      'Az adatbazis athelyezesre kerül:';

  @override
  String get settings_migration_dialog_title => 'Adatbazis athelyezese?';

  @override
  String get settings_migration_from => 'Innen';

  @override
  String get settings_migration_moveDatabase => 'Adatbazis athelyezese';

  @override
  String get settings_migration_to => 'Ide';

  @override
  String settings_notifications_days(Object count) {
    return '$count nap';
  }

  @override
  String get settings_notifications_disabled_continueButton => 'Tovább';

  @override
  String get settings_notifications_disabled_openSettingsButton =>
      'Beallitasok megnyitasa';

  @override
  String get settings_notifications_disabled_subtitleUnrequested =>
      'A szervizemlekeztetokhoz ertesitesi engedely szukseges';

  @override
  String get settings_notifications_disabled_subtitle =>
      'Engedelyezze a rendszerbeallitasokban az emlekeztetok fogadasahoz';

  @override
  String get settings_notifications_disabled_title => 'Ertesitesek letiltva';

  @override
  String get settings_notifications_enableServiceReminders =>
      'Szerviz emlekeztetok engedelyezese';

  @override
  String get settings_notifications_enableServiceReminders_subtitle =>
      'Ertesites, ha felszereles szerviz esedékes';

  @override
  String get settings_notifications_header_reminderSchedule =>
      'Emlekeztetok idoezitese';

  @override
  String get settings_notifications_header_serviceReminders =>
      'Szerviz emlekeztetok';

  @override
  String get settings_notifications_howItWorks_content =>
      'Az ertesitesek az alkalmazas inditasakor kerülnek ütemezeresre, es rendszeresen frissülnek a hatterben. Az egyes felszerelesek emlekeztetoit a szerkesztesi képernyojükön szabhatja testre.';

  @override
  String get settings_notifications_howItWorks_title => 'Hogyan mukodik';

  @override
  String get settings_notifications_permissionRequired =>
      'Kerem, engedelyezze az ertesiteseket a rendszerbeallitasokban';

  @override
  String get settings_notifications_remindBeforeDue =>
      'Emlekeztetés a szerviz esedekessege elott:';

  @override
  String get settings_notifications_reminderTime => 'Emlekeztetesi idopont';

  @override
  String get settings_profile_activeDiver_subtitle =>
      'Aktiv merülo - koppintson a valtashoz';

  @override
  String get settings_profile_addNewDiver => 'Uj merülo hozzaadasa';

  @override
  String get settings_profile_error_loadingDiver =>
      'Hiba a merülo betoltesekor';

  @override
  String get settings_profile_header_activeDiver => 'Aktiv merülo';

  @override
  String get settings_profile_header_manageDivers => 'Merülok kezelese';

  @override
  String get settings_profile_noDiverProfile => 'Nincs merülo profil';

  @override
  String get settings_profile_noDiverProfile_subtitle =>
      'Koppintson a profil letrehozasahoz';

  @override
  String get settings_profile_switchDiver_title => 'Merülo valtas';

  @override
  String settings_profile_switchedTo(Object diverName) {
    return 'Valtas: $diverName';
  }

  @override
  String get settings_profile_viewAllDivers => 'Osszes merülo megtekintese';

  @override
  String get settings_profile_viewAllDivers_subtitle =>
      'Merülo profilok hozzaadasa vagy szerkesztese';

  @override
  String get settings_profileHub_addNewDiver => 'Új búvár hozzáadása';

  @override
  String get settings_profileHub_cannotDeleteOnly =>
      'Az egyetlen búvárprofil nem törölhető';

  @override
  String get settings_profileHub_createDiverTitle => 'Búvár létrehozása';

  @override
  String settings_profileHub_deleteConfirmContent(String name) {
    return 'Biztosan törölni szeretné: $name? Minden hozzárendelt merülési napló hozzárendelése megszűnik.';
  }

  @override
  String get settings_profileHub_deleteConfirmTitle => 'Búvár törlése?';

  @override
  String get settings_profileHub_deleteDiver => 'Búvár törlése';

  @override
  String get settings_profileHub_deleted => 'Búvár törölve';

  @override
  String get settings_profileHub_emergencyContacts =>
      'Vészhelyzeti kapcsolattartók';

  @override
  String settings_profileHub_emergencyContacts_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kapcsolattartó beállítva',
      one: '1 kapcsolattartó beállítva',
      zero: 'Nincs beállítva',
    );
    return '$_temp0';
  }

  @override
  String get settings_profileHub_insurance => 'Biztosítás';

  @override
  String get settings_profileHub_insurance_expired => 'Lejárt';

  @override
  String get settings_profileHub_insurance_notSet => 'Nincs beállítva';

  @override
  String get settings_profileHub_medicalInfo => 'Orvosi információk';

  @override
  String get settings_profileHub_medicalInfo_notSet => 'Nincs beállítva';

  @override
  String get settings_profileHub_notes => 'Megjegyzések';

  @override
  String get settings_profileHub_notes_notSet => 'Nincs beállítva';

  @override
  String get settings_profileHub_personalInfo => 'Személyes adatok';

  @override
  String get settings_profileHub_personalInfo_notSet => 'Nincs beállítva';

  @override
  String get settings_profileHub_saved => 'Módosítások mentve';

  @override
  String get settings_profileHub_switchDiver => 'Búvár váltása';

  @override
  String get settings_s3Config_action_remove => 'Konfiguráció eltávolítása';

  @override
  String get settings_s3Config_action_testConnection => 'Kapcsolat tesztelése';

  @override
  String get settings_s3Config_advanced_title => 'Speciális';

  @override
  String get settings_s3Config_appBar_title => 'S3-kompatibilis tároló';

  @override
  String get settings_s3Config_error_secureStorage =>
      'Nem sikerült hozzáférni a biztonságos tárolóhoz';

  @override
  String get settings_s3Config_field_accessKeyId_label => 'Access Key ID';

  @override
  String get settings_s3Config_field_bucket_label => 'Bucket';

  @override
  String get settings_s3Config_field_endpoint_helper =>
      'Például: https://s3.example.com';

  @override
  String get settings_s3Config_field_endpoint_label => 'Végpont URL';

  @override
  String get settings_s3Config_field_pathStyle_label =>
      'Path-style címzés használata';

  @override
  String get settings_s3Config_field_pathStyle_subtitle =>
      'A legtöbb saját üzemeltetésű kiszolgálóhoz szükséges';

  @override
  String get settings_s3Config_field_prefix_label => 'Kulcs-előtag';

  @override
  String settings_s3Config_field_region_helperAuto(String region) {
    return 'Automatikusan észlelve: $region';
  }

  @override
  String get settings_s3Config_field_region_label => 'Régió';

  @override
  String get settings_s3Config_field_secretAccessKey_label =>
      'Secret Access Key';

  @override
  String get settings_s3Config_remove_confirm_action => 'Eltávolítás';

  @override
  String get settings_s3Config_remove_confirm_body =>
      'Az S3-on keresztüli szinkronizálás leáll ezen az eszközön. A bucketben lévő adatok nem törlődnek.';

  @override
  String get settings_s3Config_remove_confirm_title =>
      'Eltávolítja az S3-konfigurációt?';

  @override
  String get settings_s3Config_removed => 'S3-konfiguráció eltávolítva';

  @override
  String get settings_s3Config_saved => 'S3-konfiguráció mentve';

  @override
  String settings_s3Config_test_regionDetected(String region) {
    return 'Észlelt régió: $region';
  }

  @override
  String get settings_s3Config_test_success => 'Sikeres kapcsolat';

  @override
  String get settings_s3Config_validation_endpointInvalid =>
      'Adjon meg érvényes http:// vagy https:// URL-t';

  @override
  String get settings_s3Config_validation_endpointPath =>
      'A végpont URL-je nem tartalmazhat elérési utat';

  @override
  String get settings_s3Config_validation_required => 'Kötelező';

  @override
  String get settings_s3Config_warning_http =>
      'Ez a végpont titkosítatlan HTTP-t használ. A hitelesítő adatok és a merülési adatok titkosítatlanul utaznak; csak megbízható hálózaton használja.';

  @override
  String get settings_section_about_subtitle => 'Alkalmazas info es licencek';

  @override
  String get settings_section_about_title => 'Rolunk';

  @override
  String get settings_section_appearance_subtitle => 'Tema es megjelenes';

  @override
  String get settings_section_appearance_title => 'Megjelenes';

  @override
  String get settings_section_data_subtitle =>
      'Biztonsagi mentes, visszaallitas es tarolas';

  @override
  String get settings_section_data_title => 'Adatok';

  @override
  String get settings_section_decompression_subtitle => 'Gradiens faktorok';

  @override
  String get settings_section_decompression_title => 'Dekompresszio';

  @override
  String get settings_section_diverProfile_subtitle =>
      'Aktiv merülo es profilok';

  @override
  String get settings_section_diverProfile_title => 'Merülo profil';

  @override
  String get settings_section_manage_subtitle =>
      'Merüles tipusok es palack elore beallitott ertekek';

  @override
  String get settings_section_manage_title => 'Kezeles';

  @override
  String get settings_section_notifications_subtitle => 'Szerviz emlekeztetok';

  @override
  String get settings_section_notifications_title => 'Ertesitesek';

  @override
  String get settings_section_units_subtitle => 'Mertekegyseg beallitasok';

  @override
  String get settings_section_units_title => 'Mertekegysegek';

  @override
  String get settings_storage_appBar_title => 'Adatbazis tarolas';

  @override
  String get settings_storage_appDefault => 'Alkalmazas alapertelmezett';

  @override
  String get settings_storage_appDefaultLocation =>
      'Alkalmazas alapertelmezett helye';

  @override
  String get settings_storage_appDefault_subtitle =>
      'Szabvanyos alkalmazas tarolasi hely';

  @override
  String get settings_storage_currentLocation => 'Jelenlegi hely';

  @override
  String get settings_storage_currentLocation_label => 'Jelenlegi hely';

  @override
  String get settings_storage_customFolder => 'Egyedi mappa';

  @override
  String get settings_storage_customFolder_change => 'Valtoztatas';

  @override
  String get settings_storage_customFolder_subtitle =>
      'Valasszon szinkronizalt mappat (Dropbox, Google Drive stb.)';

  @override
  String get settings_storage_customFolder_subtitleDeviceOnly =>
      'Az adatbázis áthelyezése a belső tárhelyre vagy az SD-kártyára';

  @override
  String get settings_storage_customFolder_deviceOnly_noCloudSync =>
      'Az alkalmazás által kezelt felhőszinkronizálás ki van kapcsolva, amíg az adatbázis az eszköz tárhelyén van. Android rendszeren egyetlen szinkronizálási szolgáltatás sem éri el ezt a mappát, ezért a Biztonsági Mentés és Visszaállítás segítségével tartson máshol másolatokat.';

  @override
  String settings_storage_dbStats(
    Object fileSize,
    Object diveCount,
    Object siteCount,
  ) {
    return '$fileSize • $diveCount merüles • $siteCount merülohely';
  }

  @override
  String get settings_storage_dismissError_tooltip => 'Hibaüzenet elvetese';

  @override
  String get settings_storage_dismissSuccess_tooltip => 'Sikerüzenet elvetese';

  @override
  String get settings_storage_header_storageLocation => 'Tarolasi hely';

  @override
  String get settings_storage_info_customActive =>
      'Az alkalmazas altal kezelt felho szinkronizalas le van tiltva. A mappa szinkronizaciós szolgaltatasa (Dropbox, Google Drive stb.) kezeli a szinkronizalast.';

  @override
  String get settings_storage_info_customAvailable =>
      'Egyedi mappa hasznalata letiltja az alkalmazas altal kezelt felho szinkronizalast. A mappa szinkronizaciós szolgaltatasa kezeli helyette a szinkronizalast.';

  @override
  String get settings_storage_loading => 'Betoltes...';

  @override
  String get settings_storage_migrating_doNotClose =>
      'Kerem, ne zarja be az alkalmazast';

  @override
  String get settings_storage_migrating_movingDatabase =>
      'Adatbazis athelyezese...';

  @override
  String get settings_storage_migrating_movingToAppDefault =>
      'Athelyezes az alkalmazas alapertelmezett helyere...';

  @override
  String get settings_storage_migrating_replacingExisting =>
      'Letezo adatbazis csereje...';

  @override
  String get settings_storage_migrating_switchingToExisting =>
      'Valtas a letezo adatbazisra...';

  @override
  String get settings_storage_notSet => 'Nincs megadva';

  @override
  String settings_storage_success_backupAt(Object path) {
    return 'Az eredeti biztonsagi menteskent megmarad:\n$path';
  }

  @override
  String get settings_storage_success_moved => 'Adatbazis sikeresen athelyezve';

  @override
  String get settings_storage_dangerZone => 'Veszélyes zóna';

  @override
  String get settings_storage_resetDatabase => 'Adatbázis visszaállítása';

  @override
  String get settings_storage_resetDatabase_subtitle =>
      'Az eszközön lévő összes adat törlése és újrakezdés';

  @override
  String get settings_storage_resetDialog_title => 'Adatbázis visszaállítása?';

  @override
  String get settings_storage_resetDialog_body =>
      'Ez véglegesen törli az EZEN az eszközön lévő összes adatot, beleértve a merüléseket, helyszíneket, felszereléseket és beállításokat. A visszaállítás előtt automatikusan biztonsági mentés készül.\n\nA felhőkönyvtár nem törlődik, és a többi eszköz megtartja az adatait. A felhőszinkronizálás leválasztásra kerül, hogy a visszaállítás ne vonódjon vissza; a Beállítások > Felhőszinkronizálás menüben csatlakoztathatja újra.';

  @override
  String get settings_storage_resetDialog_confirmWord => 'Törlés';

  @override
  String get settings_storage_resetDialog_confirmHint =>
      'Írja be: \"Törlés\" a megerősítéshez';

  @override
  String get settings_storage_resetDialog_confirmButton => 'Visszaállítás';

  @override
  String get settings_storage_resetDialog_backupFailed =>
      'A biztonsági mentés sikertelen. A visszaállítás megszakítva az adatok védelme érdekében.';

  @override
  String settings_storage_resetDialog_resetFailed(Object error) {
    return 'Visszaállítás sikertelen: $error';
  }

  @override
  String get settings_storage_resetComplete_title => 'Adatbázis visszaállítva';

  @override
  String get settings_storage_resetComplete_description =>
      'Ennek az eszköznek az adatai törölve lettek és biztonsági mentés készült. A felhőszinkronizálás most le van választva, hogy a visszaállítás ne vonódjon vissza; a Beállítások > Felhőszinkronizálás menüben csatlakoztathatja újra. Koppintson a Tovább gombra az alkalmazás újratöltéséhez.';

  @override
  String get settings_summary_activeDiver => 'Aktiv merülo';

  @override
  String get settings_summary_currentConfiguration => 'Jelenlegi konfiguracoo';

  @override
  String get settings_summary_depth => 'Melyseg';

  @override
  String get settings_summary_error => 'Hiba';

  @override
  String get settings_summary_gradientFactors => 'Gradiens Faktorok';

  @override
  String get settings_summary_loading => 'Betoltes...';

  @override
  String get settings_summary_notSet => 'Nincs megadva';

  @override
  String get settings_summary_pressure => 'Nyomas';

  @override
  String get settings_summary_subtitle =>
      'Valasszon egy kategoriat a konfigurálashoz';

  @override
  String get settings_summary_temperature => 'Homerseklet';

  @override
  String get settings_summary_theme => 'Tema';

  @override
  String get settings_summary_theme_dark => 'Sötet';

  @override
  String get settings_summary_theme_light => 'Vilagos';

  @override
  String get settings_summary_theme_system => 'Rendszer';

  @override
  String get settings_summary_tip =>
      'Tipp: Hasznaja az Adatok szekciót a merülesi naploi rendszeres biztonsagi mentesehez.';

  @override
  String get settings_summary_title => 'Beallitasok';

  @override
  String get settings_summary_unitPreferences => 'Mertekegyseg beallitasok';

  @override
  String get settings_summary_units => 'Mertekegysegek';

  @override
  String get settings_summary_volume => 'Terfogat';

  @override
  String get settings_summary_weight => 'Suly';

  @override
  String get settings_units_custom => 'Egyedi';

  @override
  String get settings_units_dateFormat => 'Datum formatum';

  @override
  String get settings_units_depth => 'Melyseg';

  @override
  String get settings_units_depth_feet => 'Lab (ft)';

  @override
  String get settings_units_depth_meters => 'Meter (m)';

  @override
  String get settings_units_dialog_dateFormat => 'Datum formatum';

  @override
  String get settings_units_dialog_depthUnit => 'Melyseg egyseg';

  @override
  String get settings_units_dialog_pressureUnit => 'Nyomas egyseg';

  @override
  String get settings_units_dialog_sacRateUnit => 'SAC ertek egyseg';

  @override
  String get settings_units_gasModel => 'Gázszámítások';

  @override
  String get settings_units_gasModel_real => 'Valós gáz';

  @override
  String get settings_units_gasModel_real_subtitle =>
      'Figyelembe veszi az összenyomhatóságot. Egy 12 literes palack 200 baron kb. 2317 litert tartalmaz.';

  @override
  String get settings_units_gasModel_ideal => 'Ideális gáz';

  @override
  String get settings_units_gasModel_ideal_subtitle =>
      'Megegyezik a kézi számítással és a merüléstáblákkal. Egy 12 literes palack 200 baron 2400 litert tartalmaz.';

  @override
  String get settings_units_gasModel_explanation =>
      'Hogyan váltja át az alkalmazás a palacknyomást gáztérfogattá. Ez érinti az RMV-értéket, a gázstatisztikákat, a tervezőt és a gázkalkulátorokat. Az ideális gáz a képzőszervezetek által tanított számítást követi; a valós gáz fizikailag pontos, és az RMV nála kb. 5%-kal alacsonyabb.';

  @override
  String get settings_units_dialog_gasModel => 'Gázszámítások';

  @override
  String get settings_units_dialog_temperatureUnit => 'Homerseklet egyseg';

  @override
  String get settings_units_dialog_timeFormat => 'Ido formatum';

  @override
  String get settings_units_dialog_volumeUnit => 'Terfogat egyseg';

  @override
  String get settings_units_dialog_weightUnit => 'Suly egyseg';

  @override
  String get settings_units_header_individualUnits => 'Egyedi egysegek';

  @override
  String get settings_units_header_timeDateFormat => 'Ido es datum formatum';

  @override
  String get settings_units_header_unitSystem => 'Mertekegyseg rendszer';

  @override
  String get settings_units_imperial => 'Angolszasz';

  @override
  String get settings_units_metric => 'Metrikus';

  @override
  String get settings_units_pressure => 'Nyomas';

  @override
  String get settings_units_pressure_bar => 'Bar';

  @override
  String get settings_units_pressure_psi => 'PSI';

  @override
  String get settings_units_quickSelect => 'Gyors valasztas';

  @override
  String get settings_units_sacRate => 'SAC ertek';

  @override
  String get settings_units_defaultCurrency => 'Alapértelmezett pénznem';

  @override
  String get settings_units_dialog_defaultCurrency => 'Alapértelmezett pénznem';

  @override
  String get settings_units_sac_pressurePerMinute => 'Nyomas percenként';

  @override
  String get settings_units_sac_pressurePerMinute_subtitle =>
      'Nem szükseges palack terfogat (bar/min vagy psi/min)';

  @override
  String get settings_units_sac_volumePerMinute => 'Terfogat percenként';

  @override
  String get settings_units_sac_volumePerMinute_subtitle =>
      'Palack terfogat szükseges (L/min vagy cuft/min)';

  @override
  String get settings_units_temperature => 'Homerseklet';

  @override
  String get settings_units_temperature_celsius => 'Celsius (°C)';

  @override
  String get settings_units_temperature_fahrenheit => 'Fahrenheit (°F)';

  @override
  String get settings_units_timeFormat => 'Ido formatum';

  @override
  String get settings_units_volume => 'Terfogat';

  @override
  String get settings_units_volume_cubicFeet => 'Köblab (cuft)';

  @override
  String get settings_units_volume_liters => 'Liter (L)';

  @override
  String get settings_units_weight => 'Suly';

  @override
  String get settings_units_weight_kilograms => 'Kilogramm (kg)';

  @override
  String get settings_units_weight_pounds => 'Font (lbs)';

  @override
  String get settings_updates_automaticUpdates => 'Automatikus frissítések';

  @override
  String get settings_updates_automaticUpdatesSubtitle =>
      'Frissítések rendszeres keresése';

  @override
  String get settings_updates_betaDialogBody =>
      'A béta buildek minden változtatásból megjelennek, és a merülési napló adatbázisát a stabil kiadás előtt frissíthetik. Ha később visszaváltasz a stabil csatornára, az alkalmazás nem áll vissza korábbi verzióra, és az együtt szinkronizáló eszközöknek ugyanazt a csatornát érdemes használniuk. Minden adatbázis-frissítés előtt automatikusan biztonsági mentés készül.';

  @override
  String get settings_updates_betaDialogConfirm => 'Váltás bétára';

  @override
  String get settings_updates_betaDialogTitle =>
      'Szeretnél béta frissítéseket kapni?';

  @override
  String get settings_updates_channel => 'Frissítési csatorna';

  @override
  String settings_updates_channelBadgeBeta(String version) {
    return '$version (Béta)';
  }

  @override
  String get settings_updates_channelBeta => 'Béta';

  @override
  String get settings_updates_channelBetaSubtitle =>
      'Új buildek minden változtatásból, a stabil előtt';

  @override
  String get settings_updates_channelStable => 'Stabil';

  @override
  String get settings_updates_channelStableSubtitle => 'Csak tesztelt kiadások';

  @override
  String get settings_updates_checkForUpdates => 'Frissítések keresése';

  @override
  String get settings_updates_checking => 'Keresés...';

  @override
  String settings_updates_downloading(String progress) {
    return 'Letöltés... $progress%';
  }

  @override
  String settings_updates_error(String message) {
    return 'Hiba: $message';
  }

  @override
  String get settings_updates_header => 'Frissítések';

  @override
  String get settings_updates_joinBeta => 'Csatlakozz a bétához';

  @override
  String get settings_updates_joinBetaSubtitle =>
      'Kapd meg korábban az új funkciókat a bétaprogramon keresztül';

  @override
  String get settings_updates_lastChecked => 'Utolsó ellenőrzés';

  @override
  String get settings_updates_never => 'Soha';

  @override
  String settings_updates_readyToInstall(String version) {
    return 'A(z) $version verzió telepítésre kész';
  }

  @override
  String get settings_updates_stableSwitchNotice =>
      'Ezen a bétán maradsz, amíg a következő stabil kiadás nem lesz nála újabb.';

  @override
  String get settings_updates_upToDate => 'Naprakész';

  @override
  String settings_updates_versionAvailable(String version) {
    return 'A(z) $version verzió elérhető';
  }

  @override
  String get signatures_action_clear => 'Törlés';

  @override
  String get signatures_action_closeSignatureView => 'Aláírás nézet bezárása';

  @override
  String get signatures_action_deleteSignature => 'Aláírás törlése';

  @override
  String get signatures_action_done => 'Kész';

  @override
  String get signatures_action_readyToSign => 'Kész az aláírásra';

  @override
  String get signatures_action_request => 'Kérés';

  @override
  String get signatures_action_saveSignature => 'Aláírás mentése';

  @override
  String signatures_buddyCard_notSignedSemantics(Object name) {
    return '$name aláírás, nincs aláírva';
  }

  @override
  String signatures_buddyCard_signedSemantics(Object name) {
    return '$name aláírás, aláírva';
  }

  @override
  String get signatures_captureInstructorSignature =>
      'Oktató aláírás rögzítése';

  @override
  String signatures_deleteDialog_message(Object name) {
    return 'Biztosan törölni szeretnéd $name aláírását? Ez nem vonható vissza.';
  }

  @override
  String get signatures_deleteDialog_title => 'Aláírás törlése?';

  @override
  String get signatures_drawSignatureHint => 'Rajzold meg az aláírásodat fent';

  @override
  String get signatures_drawSignatureHintDetailed =>
      'Rajzold meg az aláírást fent ujjal vagy tollal';

  @override
  String get signatures_drawSignatureSemantics => 'Aláírás rajzolása';

  @override
  String get signatures_error_drawSignature => 'Rajzolj egy aláírást';

  @override
  String get signatures_error_enterSignerName => 'Add meg az aláíró nevét';

  @override
  String get signatures_field_instructorName => 'Oktató neve';

  @override
  String get signatures_field_instructorNameHint => 'Add meg az oktató nevét';

  @override
  String get signatures_handoff_title => 'Add át az eszközt';

  @override
  String get signatures_instructorSignature => 'Oktató aláírása';

  @override
  String get signatures_noSignatureImage => 'Nincs aláírás kép';

  @override
  String signatures_signHere(Object name) {
    return '$name - Írj alá itt';
  }

  @override
  String get signatures_signed => 'Aláírva';

  @override
  String signatures_signedCountSemantics(Object signed, Object total) {
    return '$signed búvártárs írt alá a(z) $total-ból';
  }

  @override
  String signatures_signedDate(Object date) {
    return 'Aláírva: $date';
  }

  @override
  String get signatures_title => 'Aláírások';

  @override
  String get signatures_viewSignature => 'Aláírás megtekintése';

  @override
  String signatures_viewSignatureSemantics(Object name) {
    return 'Aláírás megtekintése $name-től';
  }

  @override
  String get statistics_appBar_title => 'Statisztikak';

  @override
  String statistics_categoryCard_semanticLabel(Object title) {
    return '$title statisztikai kategoria';
  }

  @override
  String get statistics_category_conditions_subtitle =>
      'Latasi viszonyok es homerseklet';

  @override
  String get statistics_category_conditions_title => 'Korulmenyek';

  @override
  String get statistics_category_equipment_subtitle =>
      'Felszereles hasznalat es suly';

  @override
  String get statistics_category_equipment_title => 'Felszereles';

  @override
  String get statistics_category_gas_subtitle => 'SAC raatak es gazkeverekek';

  @override
  String get statistics_category_gas_title => 'Levegofelhasznalas';

  @override
  String get statistics_category_geographic_subtitle => 'Orszagok es regiok';

  @override
  String get statistics_category_geographic_title => 'Foldrajzi';

  @override
  String get statistics_category_marineLife_subtitle => 'Fajok eszlelesek';

  @override
  String get statistics_category_marineLife_title => 'Tengeri elet';

  @override
  String get statistics_category_overview_title => 'Overview';

  @override
  String get statistics_category_overview_subtitle =>
      'Totals, records, and breakdowns at a glance';

  @override
  String get statistics_category_profile_subtitle =>
      'Felszallasi sebessg es deko';

  @override
  String get statistics_category_profile_title => 'Profil elemzes';

  @override
  String get statistics_category_progression_subtitle =>
      'Melyseg es ido trendek';

  @override
  String get statistics_category_progression_title => 'Fejlodes';

  @override
  String get statistics_category_social_subtitle =>
      'Merulotarsak es merulokozpontok';

  @override
  String get statistics_category_social_title => 'Kozossegi';

  @override
  String get statistics_category_timePatterns_subtitle => 'Mikor merul';

  @override
  String get statistics_category_timePatterns_title => 'Idomintak';

  @override
  String statistics_chart_barSemanticLabel(Object count) {
    return 'Oszlopdiagram $count kategoriaval';
  }

  @override
  String statistics_chart_distributionSemanticLabel(Object count) {
    return 'Megoszlasi kordiagram $count szegmenssel';
  }

  @override
  String statistics_chart_multiTrendSemanticLabel(Object seriesNames) {
    return 'Tobbszoros trend vonaldiagram, $seriesNames osszehasonlitasa';
  }

  @override
  String get statistics_chart_noBarData => 'Nincsenek elerheto adatok';

  @override
  String get statistics_chart_noDistributionData =>
      'Nincsenek megoszlasi adatok';

  @override
  String get statistics_chart_noTrendData => 'Nincsenek trend adatok';

  @override
  String statistics_chart_trendSemanticLabel(Object count) {
    return 'Trend vonaldiagram $count adatponttal';
  }

  @override
  String statistics_chart_trendSemanticLabelWithAxis(
    Object count,
    Object yAxisLabel,
  ) {
    return 'Trend vonaldiagram $count adatponttal a(z) $yAxisLabel szamara';
  }

  @override
  String get statistics_conditions_appBar_title => 'Korulmenyek';

  @override
  String get statistics_conditions_entryMethod_empty =>
      'Nincsenek belepesi modszer adatok';

  @override
  String get statistics_conditions_entryMethod_error =>
      'Nem sikerult a belepesi modszer adatok betoltese';

  @override
  String get statistics_conditions_entryMethod_subtitle => 'Parti, hajos stb.';

  @override
  String get statistics_conditions_entryMethod_title => 'Belepesi modszer';

  @override
  String get statistics_conditions_temperature_empty =>
      'Nincsenek homerseklet adatok';

  @override
  String get statistics_conditions_temperature_error =>
      'Nem sikerult a homerseklet adatok betoltese';

  @override
  String get statistics_conditions_temperature_seriesAvg => 'Atl.';

  @override
  String get statistics_conditions_temperature_seriesMax => 'Max';

  @override
  String get statistics_conditions_temperature_seriesMin => 'Min';

  @override
  String get statistics_conditions_temperature_subtitle =>
      'Min/Atl/Max homersekletek';

  @override
  String get statistics_conditions_temperature_title =>
      'Vizhomerseklet honaponkent';

  @override
  String get statistics_conditions_visibility_error =>
      'Nem sikerult a latasi adatok betoltese';

  @override
  String get statistics_conditions_visibility_subtitle =>
      'Merulesek latasi viszonyok szerint';

  @override
  String get statistics_conditions_visibility_title => 'Lathato megoszlas';

  @override
  String get statistics_conditions_waterType_error =>
      'Nem sikerult a viztipus adatok betoltese';

  @override
  String get statistics_conditions_waterType_subtitle =>
      'Sos es edesvizi merulesek';

  @override
  String get statistics_conditions_waterType_title => 'Viztipus';

  @override
  String get statistics_equipment_appBar_title => 'Felszereles';

  @override
  String get statistics_equipment_mostUsedGear_error =>
      'Nem sikerult a felszereles adatok betoltese';

  @override
  String get statistics_equipment_mostUsedGear_subtitle =>
      'Felszereles merulesek szama szerint';

  @override
  String get statistics_equipment_mostUsedGear_title =>
      'Legtobbet hasznalt felszereles';

  @override
  String get statistics_equipment_weightTrend_error =>
      'Nem sikerult a suly trend betoltese';

  @override
  String get statistics_equipment_weightTrend_subtitle =>
      'Atlagos suly az ido fuggvenyeben';

  @override
  String get statistics_equipment_weightTrend_title => 'Suly trend';

  @override
  String get statistics_error_loadingStatistics =>
      'Hiba a statisztikak betoltesekor';

  @override
  String get statistics_filterBar_clear => 'Szűrő törlése';

  @override
  String statistics_filterBar_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merülés',
      one: '1 merülés',
    );
    return '$_temp0';
  }

  @override
  String get statistics_gas_appBar_title => 'Levegofelhasznalas';

  @override
  String get statistics_gas_gasMix_error =>
      'Nem sikerult a gazkeverek adatok betoltese';

  @override
  String get statistics_gas_gasMix_subtitle => 'Merulesek gaztipus szerint';

  @override
  String get statistics_gas_gasMix_title => 'Gazkeverek megoszlas';

  @override
  String get statistics_gas_sacByRole_empty => 'Nincsenek tobbpalackos adatok';

  @override
  String get statistics_gas_sacByRole_error =>
      'Nem sikerult a SAC szerep szerinti betoltese';

  @override
  String get statistics_gas_sacByRole_subtitle =>
      'Atlagos felhasznalas palack tipus szerint';

  @override
  String get statistics_gas_sacByRole_title => 'SAC palack szerep szerint';

  @override
  String get statistics_gas_sacRecords_best => 'Legjobb SAC rata';

  @override
  String get statistics_gas_sacRecords_empty => 'Meg nincsenek SAC adatok';

  @override
  String get statistics_gas_sacRecords_error =>
      'Nem sikerult a SAC rekordok betoltese';

  @override
  String get statistics_gas_sacRecords_highest => 'Legmagasabb SAC rata';

  @override
  String get statistics_gas_sacRecords_subtitle =>
      'Legjobb es legrosszabb levegofelhasznalas';

  @override
  String get statistics_gas_sacRecords_title => 'SAC rata rekordok';

  @override
  String get statistics_gas_sacTrend_error =>
      'Nem sikerult a SAC trend betoltese';

  @override
  String get statistics_gas_sacTrend_subtitle => 'Havi atlag 5 even at';

  @override
  String get statistics_gas_sacTrend_title => 'SAC rata trend';

  @override
  String get statistics_gas_tankRole_backGas => 'Hattergaz';

  @override
  String get statistics_gas_tankRole_bailout => 'Bailout';

  @override
  String get statistics_gas_tankRole_deco => 'Deko';

  @override
  String get statistics_gas_tankRole_diluent => 'Higito';

  @override
  String get statistics_gas_tankRole_oxygenSupply => 'O₂ ellatas';

  @override
  String get statistics_gas_tankRole_pony => 'Pony';

  @override
  String get statistics_gas_tankRole_sidemountLeft => 'Sidemount B';

  @override
  String get statistics_gas_tankRole_sidemountRight => 'Sidemount J';

  @override
  String get statistics_gas_tankRole_stage => 'Stage';

  @override
  String get statistics_geographic_appBar_title => 'Foldrajzi';

  @override
  String get statistics_geographic_countries_empty =>
      'Nincsenek latogatott orszagok';

  @override
  String get statistics_geographic_countries_error =>
      'Nem sikerult az orszag adatok betoltese';

  @override
  String get statistics_geographic_countries_subtitle =>
      'Merulesek orszagonkent';

  @override
  String statistics_geographic_countries_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count orszag. Elso: $topName, $topCount merulessel';
  }

  @override
  String get statistics_geographic_countries_title => 'Latogatott orszagok';

  @override
  String get statistics_geographic_regions_empty =>
      'Nincsenek felfedezett regiok';

  @override
  String get statistics_geographic_regions_error =>
      'Nem sikerult a regio adatok betoltese';

  @override
  String get statistics_geographic_regions_subtitle => 'Merulesek regiokent';

  @override
  String statistics_geographic_regions_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count regio. Elso: $topName, $topCount merulessel';
  }

  @override
  String get statistics_geographic_regions_title => 'Felfedezett regiok';

  @override
  String get statistics_geographic_trips_empty => 'Nincsenek utazasi adatok';

  @override
  String get statistics_geographic_trips_error =>
      'Nem sikerult az utazasi adatok betoltese';

  @override
  String get statistics_geographic_trips_subtitle => 'Legproduktivabb utazasok';

  @override
  String statistics_geographic_trips_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count utazas. Elso: $topName, $topCount merulessel';
  }

  @override
  String get statistics_geographic_trips_title => 'Merulesek utazasonkent';

  @override
  String get statistics_listContent_selectedSuffix => ', kivalasztva';

  @override
  String get statistics_marineLife_appBar_title => 'Tengeri elet';

  @override
  String get statistics_marineLife_bestSites_empty =>
      'Nincsenek helyszin adatok';

  @override
  String get statistics_marineLife_bestSites_error =>
      'Nem sikerult a helyszin adatok betoltese';

  @override
  String get statistics_marineLife_bestSites_subtitle =>
      'Legtobb fajvalaszteku helyszinek';

  @override
  String statistics_marineLife_bestSites_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count helyszin. Legjobb: $topName, $topCount fajjal';
  }

  @override
  String get statistics_marineLife_bestSites_title =>
      'Legjobb tengeri elet helyszinek';

  @override
  String get statistics_marineLife_mostCommon_empty =>
      'Nincsenek eszlelesi adatok';

  @override
  String get statistics_marineLife_mostCommon_error =>
      'Nem sikerult az eszlelesi adatok betoltese';

  @override
  String get statistics_marineLife_mostCommon_subtitle =>
      'Leggyakrabban lathato fajok';

  @override
  String statistics_marineLife_mostCommon_summary(
    Object count,
    Object topName,
    Object topCount,
  ) {
    return '$count faj. Leggyakoribb: $topName, $topCount eszlelessel';
  }

  @override
  String get statistics_marineLife_mostCommon_title =>
      'Leggyakoribb eszlelesek';

  @override
  String get statistics_marineLife_speciesSpotted => 'Eszlelt fajok';

  @override
  String get statistics_profile_appBar_title => 'Profil elemzes';

  @override
  String get statistics_profile_ascentDescent_empty =>
      'Nincsenek elerheto profil adatok';

  @override
  String get statistics_profile_ascentDescent_error =>
      'Nem sikerult a sebessg adatok betoltese';

  @override
  String get statistics_profile_ascentDescent_subtitle =>
      'Merulesi profil adatokbol';

  @override
  String get statistics_profile_ascentDescent_title =>
      'Atlagos felszallasi es lesullyedesi sebesseg';

  @override
  String get statistics_profile_avgAscent => 'Atl. felszallas';

  @override
  String get statistics_profile_avgDescent => 'Atl. lesullyedes';

  @override
  String get statistics_profile_deco_decoDives => 'Deko merulesek';

  @override
  String get statistics_profile_deco_decoLabel => 'Deko';

  @override
  String get statistics_profile_deco_decoRate => 'Deko arany';

  @override
  String get statistics_profile_deco_empty => 'Nincsenek deko adatok';

  @override
  String get statistics_profile_deco_error =>
      'Nem sikerult a deko adatok betoltese';

  @override
  String get statistics_profile_deco_noDeco => 'Nincs deko';

  @override
  String get statistics_profile_deco_notRecorded => 'Nincs rögzítve';

  @override
  String statistics_profile_deco_notRecordedHint(int count) {
    return '$count merülés nem tartalmaz rögzített vagy számítható dekompressziós adatot, ezért kimarad az arányból';
  }

  @override
  String statistics_profile_deco_semanticLabel(Object percentage) {
    return 'Dekompresszios arany: $percentage% a meruleseknek deko megalloast igenyelt';
  }

  @override
  String get statistics_profile_deco_subtitle =>
      'Merulesek amelyek deko megalloast igenyeltek';

  @override
  String get statistics_profile_deco_title => 'Dekompresszios kotelezetseg';

  @override
  String get statistics_profile_timeAtDepth_empty => 'Nincsenek melyseg adatok';

  @override
  String get statistics_profile_timeAtDepth_error =>
      'Nem sikerult a melyseg tartomany adatok betoltese';

  @override
  String get statistics_profile_timeAtDepth_subtitle =>
      'Kozelito ido az egyes melysegekben';

  @override
  String get statistics_profile_timeAtDepth_title =>
      'Ido melyseg tartomanyokent';

  @override
  String statistics_profile_timeAtDepth_valueFormat(Object value) {
    return '$value min';
  }

  @override
  String get statistics_progression_appBar_title => 'Merulesi fejlodes';

  @override
  String get statistics_progression_bottomTime_error =>
      'Nem sikerult a fenekido trend betoltese';

  @override
  String get statistics_progression_bottomTime_subtitle =>
      'Atlagos idotartam honaponkent';

  @override
  String get statistics_progression_bottomTime_title => 'Fenekido trend';

  @override
  String get statistics_progression_cumulative_error =>
      'Nem sikerult a kumulativ adatok betoltese';

  @override
  String get statistics_progression_cumulative_subtitle =>
      'Osszes merules az ido fuggvenyeben';

  @override
  String get statistics_progression_cumulative_title =>
      'Kumulativ merulesi szam';

  @override
  String get statistics_progression_depthProgression_error =>
      'Nem sikerult a melyseg fejlodes betoltese';

  @override
  String get statistics_progression_depthProgression_subtitle =>
      'Havi max melyseg 5 even at';

  @override
  String get statistics_progression_depthProgression_title =>
      'Maximalis melyseg fejlodes';

  @override
  String get statistics_progression_divesPerYear_empty =>
      'Nincsenek eves adatok';

  @override
  String get statistics_progression_divesPerYear_error =>
      'Nem sikerult az eves adatok betoltese';

  @override
  String get statistics_progression_divesPerYear_subtitle =>
      'Eves merulesszam osszehasonlitas';

  @override
  String get statistics_progression_divesPerYear_title => 'Merulesek evente';

  @override
  String get statistics_ranking_countLabel_dives => 'merules';

  @override
  String get statistics_ranking_countLabel_sightings => 'eszleles';

  @override
  String get statistics_ranking_countLabel_species => 'faj';

  @override
  String get statistics_ranking_emptyState => 'Meg nincsenek adatok';

  @override
  String statistics_ranking_itemCount(Object count, Object label) {
    return '$count $label';
  }

  @override
  String statistics_ranking_moreItems(Object count) {
    return 'es $count tovabbi';
  }

  @override
  String statistics_ranking_semanticLabel(
    Object name,
    Object rank,
    Object count,
    Object label,
  ) {
    return '$name, $rank. helyezes, $count $label';
  }

  @override
  String get statistics_records_appBar_title => 'Merulesi rekordok';

  @override
  String get statistics_records_coldestDive => 'Leghidegebb merules';

  @override
  String get statistics_records_deepestDive => 'Legmelyebb merules';

  @override
  String statistics_records_diveNumber(Object number) {
    return '#$number. merules';
  }

  @override
  String get statistics_records_emptySubtitle =>
      'Kezdjen el meruleseket rogziteni, hogy lassa rekordJait';

  @override
  String get statistics_records_emptyTitle => 'Meg nincsenek rekordok';

  @override
  String get statistics_records_error => 'Hiba a rekordok betoltesekor';

  @override
  String get statistics_records_firstDive => 'Elso merules';

  @override
  String get statistics_records_longestDive => 'Leghosszabb merules';

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
  String get statistics_records_milestones => 'Merfoldk9vek';

  @override
  String get statistics_records_mostRecentDive => 'Legutobbl merules';

  @override
  String statistics_records_recordSemanticLabel(
    Object title,
    Object value,
    Object siteName,
  ) {
    return '$title: $value, $siteName';
  }

  @override
  String get statistics_records_retry => 'Ujra';

  @override
  String get statistics_records_shallowestDive => 'Legsekelyebb merules';

  @override
  String get statistics_records_unknownSite => 'Ismeretlen helyszin';

  @override
  String get statistics_records_warmestDive => 'Legmelegebb merules';

  @override
  String statistics_sectionCard_semanticLabel(Object title) {
    return '$title szekcio';
  }

  @override
  String get statistics_social_appBar_title => 'Kozossegi es merulotarsak';

  @override
  String get statistics_social_soloVsBuddy_empty => 'Nincsenek merulesi adatok';

  @override
  String get statistics_social_soloVsBuddy_error =>
      'Nem sikerult a merulotars adatok betoltese';

  @override
  String get statistics_social_soloVsBuddy_solo => 'Egyedulli';

  @override
  String get statistics_social_soloVsBuddy_subtitle =>
      'Merules tarsakkal vagy nelkuluk';

  @override
  String get statistics_social_soloVsBuddy_title => 'Egyedulli vs. tarsakkal';

  @override
  String get statistics_social_soloVsBuddy_withBuddy => 'Merulotarssal';

  @override
  String get statistics_social_topBuddies_error =>
      'Nem sikerult a merulotars rangsor betoltese';

  @override
  String get statistics_social_topBuddies_subtitle =>
      'Leggyakoribb merulotarsak';

  @override
  String get statistics_social_topBuddies_title => 'Legjobb merulotarsak';

  @override
  String get statistics_social_topDiveCenters_error =>
      'Nem sikerult a merulokozpont rangsor betoltese';

  @override
  String get statistics_social_topDiveCenters_subtitle =>
      'Leglátogatottabb szolgaltatok';

  @override
  String get statistics_social_topDiveCenters_title =>
      'Legjobb merulokozpontok';

  @override
  String get statistics_summary_avgDepth => 'Atl. melyseg';

  @override
  String get statistics_summary_avgTemp => 'Atl. homerseklet';

  @override
  String get statistics_summary_depthDistribution_empty =>
      'A diagram megjelenik, ha rogzit meruleseket';

  @override
  String get statistics_summary_depthDistribution_semanticLabel =>
      'Kordiagram a melyseg megoszlasrol';

  @override
  String get statistics_summary_depthDistribution_title => 'Melyseg megoszlas';

  @override
  String get statistics_summary_diveTypes_empty =>
      'A diagram megjelenik, ha rogzit meruleseket';

  @override
  String statistics_summary_diveTypes_moreTypes(Object count) {
    return 'es $count tovabbi tipus';
  }

  @override
  String get statistics_summary_diveTypes_semanticLabel =>
      'Kordiagram a merulesi tipusok megoszlasarol';

  @override
  String get statistics_summary_diveTypes_title => 'Merulesi tipusok';

  @override
  String get statistics_summary_divesByMonth_empty =>
      'A diagram megjelenik, ha rogzit meruleseket';

  @override
  String get statistics_summary_divesByMonth_semanticLabel =>
      'Oszlopdiagram a hayl merulesekrol';

  @override
  String get statistics_summary_divesByMonth_title => 'Merulesek honaponkent';

  @override
  String statistics_summary_divesByMonth_tooltip(
    Object fullLabel,
    Object count,
  ) {
    return '$fullLabel\n$count merules';
  }

  @override
  String get statistics_summary_header_subtitle =>
      'Valasszon kategoriat a reszletes statisztikak megtekIntesehez';

  @override
  String get statistics_summary_header_title => 'Statisztikak attekintese';

  @override
  String get statistics_summary_maxDepth => 'Max melyseg';

  @override
  String get statistics_summary_sitesVisited => 'Latogatott helyszinek';

  @override
  String statistics_summary_tagUsage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merules',
      one: '1 merules',
    );
    return '$_temp0';
  }

  @override
  String get statistics_summary_tagUsage_empty => 'Meg nincsenek cimkek';

  @override
  String get statistics_summary_tagUsage_emptyHint =>
      'Adjon cimkeket a merulesekhez a statisztikak megtekIntesehez';

  @override
  String statistics_summary_tagUsage_moreTags(Object count) {
    return 'es $count tovabbi cimke';
  }

  @override
  String statistics_summary_tagUsage_tagCount(Object count) {
    return '$count cimke';
  }

  @override
  String get statistics_summary_tagUsage_title => 'Cimke hasznalat';

  @override
  String statistics_summary_topDiveSites_diveCount(Object count) {
    return '$count merules';
  }

  @override
  String get statistics_summary_topDiveSites_empty =>
      'Meg nincsenek merulohelyek';

  @override
  String get statistics_summary_topDiveSites_title => 'Legjobb merulohelyek';

  @override
  String statistics_summary_topDiveSites_totalCount(Object count) {
    return '$count osszesen';
  }

  @override
  String get statistics_summary_totalDives => 'Osszes merules';

  @override
  String get statistics_summary_totalTime => 'Osszes ido';

  @override
  String get statistics_timePatterns_appBar_title => 'Idomintak';

  @override
  String get statistics_timePatterns_dayOfWeek_empty =>
      'Nincsenek elerheto adatok';

  @override
  String get statistics_timePatterns_dayOfWeek_error =>
      'Nem sikerult a heti nap adatok betoltese';

  @override
  String get statistics_timePatterns_dayOfWeek_fri => 'Pe';

  @override
  String get statistics_timePatterns_dayOfWeek_mon => 'He';

  @override
  String get statistics_timePatterns_dayOfWeek_sat => 'Szo';

  @override
  String get statistics_timePatterns_dayOfWeek_subtitle =>
      'Mikor merul a legtobbet?';

  @override
  String get statistics_timePatterns_dayOfWeek_sun => 'V';

  @override
  String get statistics_timePatterns_dayOfWeek_thu => 'Cs';

  @override
  String get statistics_timePatterns_dayOfWeek_title =>
      'Merulesek a het napjai szerint';

  @override
  String get statistics_timePatterns_dayOfWeek_tue => 'K';

  @override
  String get statistics_timePatterns_dayOfWeek_wed => 'Sze';

  @override
  String get statistics_timePatterns_month_apr => 'Apr.';

  @override
  String get statistics_timePatterns_month_aug => 'Aug.';

  @override
  String get statistics_timePatterns_month_dec => 'Dec.';

  @override
  String get statistics_timePatterns_month_feb => 'Feb.';

  @override
  String get statistics_timePatterns_month_jan => 'Jan.';

  @override
  String get statistics_timePatterns_month_jul => 'Jul.';

  @override
  String get statistics_timePatterns_month_jun => 'Jun.';

  @override
  String get statistics_timePatterns_month_mar => 'Mar.';

  @override
  String get statistics_timePatterns_month_may => 'Maj.';

  @override
  String get statistics_timePatterns_month_nov => 'Nov.';

  @override
  String get statistics_timePatterns_month_oct => 'Okt.';

  @override
  String get statistics_timePatterns_month_sep => 'Szept.';

  @override
  String get statistics_timePatterns_seasonal_empty =>
      'Nincsenek elerheto adatok';

  @override
  String get statistics_timePatterns_seasonal_error =>
      'Nem sikerult az evszakos adatok betoltese';

  @override
  String get statistics_timePatterns_seasonal_subtitle =>
      'Merulesek honaponkent (minden ev)';

  @override
  String get statistics_timePatterns_seasonal_title => 'Evszakos mintak';

  @override
  String get statistics_timePatterns_surfaceInterval_average => 'Atlag';

  @override
  String get statistics_timePatterns_surfaceInterval_empty =>
      'Nincsenek felszini intervallum adatok';

  @override
  String get statistics_timePatterns_surfaceInterval_error =>
      'Nem sikerult a felszini intervallum adatok betoltese';

  @override
  String statistics_timePatterns_surfaceInterval_formatHoursMinutes(
    Object hours,
    Object minutes,
  ) {
    return '${hours}o ${minutes}p';
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
      'Ido a merulesek kozott';

  @override
  String get statistics_timePatterns_surfaceInterval_title =>
      'Felszini intervallum statisztikak';

  @override
  String get statistics_timePatterns_timeOfDay_error =>
      'Nem sikerult a napszak adatok betoltese';

  @override
  String get statistics_timePatterns_timeOfDay_subtitle =>
      'Reggel, delutan, este vagy ejszaka';

  @override
  String get statistics_timePatterns_timeOfDay_title =>
      'Merulesek napszak szerint';

  @override
  String get statistics_tooltip_diveRecords => 'Merulesi rekordok';

  @override
  String get statistics_tooltip_filter => 'Statisztikák szűrése';

  @override
  String get statistics_tooltip_refreshRecords => 'Rekordok frissitese';

  @override
  String get statistics_tooltip_refreshStatistics => 'Statisztikak frissitese';

  @override
  String statistics_valueCard_semanticLabel(Object label, Object value) {
    return '$label: $value';
  }

  @override
  String get surfaceInterval_aboutTissueLoading_body =>
      'A testednek 16 szövetkamrája van, amelyek különböző sebességgel nyelik el és adják le a nitrogént. A gyors szövetek (mint a vér) gyorsan telítődnek, de gyorsan is ürülnek. A lassú szövetek (mint a csont és a zsír) tovább tart, hogy mindkettőt betöltsék és kiürüljenek. A \"vezető kamra\" az a szövet, amelyik a legtelítettebb, és általában ez szabályozza a dekompresszió nélküli határidőt (NDL). A felszíni intervallum alatt minden szövet kiürül a felszíni telítettségi szintek felé (~40% telítettség).';

  @override
  String get surfaceInterval_aboutTissueLoading_title =>
      'A szövet telítettségről';

  @override
  String get surfaceInterval_action_resetDefaults =>
      'Alapértelmezések visszaállítása';

  @override
  String get surfaceInterval_disclaimer =>
      'Ez az eszköz csak tervezési célokat szolgál. Mindig használj búvárcomputert és kövesd a képzésed. Az eredmények a Buhlmann ZH-L16C algoritmuson alapulnak és eltérhetnek a computeredétől.';

  @override
  String get surfaceInterval_field_depth => 'Mélység';

  @override
  String get surfaceInterval_field_gasMix => 'Gázkeverék: ';

  @override
  String get surfaceInterval_field_he => 'He';

  @override
  String get surfaceInterval_field_o2 => 'O₂';

  @override
  String get surfaceInterval_field_time => 'Idő';

  @override
  String surfaceInterval_firstDive_depthSemantics(Object depth, Object unit) {
    return 'Első merülés mélysége: $depth $unit';
  }

  @override
  String surfaceInterval_firstDive_timeSemantics(Object time) {
    return 'Első merülés ideje: $time perc';
  }

  @override
  String get surfaceInterval_firstDive_title => 'Első merülés';

  @override
  String surfaceInterval_format_hours(Object count) {
    return '$count óra';
  }

  @override
  String surfaceInterval_format_minutes(Object count) {
    return '$count perc';
  }

  @override
  String get surfaceInterval_gasMix_air => 'Levegő';

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
    return 'ppO₂ $ppO2 $depth mélységben meghaladja a $limit értéket. A keverék MOD-ja $mod.';
  }

  @override
  String surfaceInterval_heSemantics(Object percent) {
    return 'Hélium: $percent%';
  }

  @override
  String surfaceInterval_o2Semantics(Object percent) {
    return 'O2: $percent%';
  }

  @override
  String surfaceInterval_result_beyondHorizon(Object hours) {
    return 'A várakozás túllépi azt a $hours órát, ameddig ez a tervező keres. A kitelítődés folytatódik, így egy hosszabb felszíni intervallum elegendő lesz.';
  }

  @override
  String surfaceInterval_result_beyondHorizonShort(Object hours) {
    return 'Több mint $hours óra';
  }

  @override
  String get surfaceInterval_result_currentInterval => 'Jelenlegi intervallum';

  @override
  String get surfaceInterval_result_gasUnsafe =>
      'A gáz nem biztonságos ezen a mélységen';

  @override
  String get surfaceInterval_result_inDeco => 'Dekóban';

  @override
  String get surfaceInterval_result_increaseInterval =>
      'Növeld a felszíni intervallumot vagy csökkentsd a második merülés mélységét/idejét';

  @override
  String get surfaceInterval_result_minimumInterval =>
      'Minimum felszíni intervallum';

  @override
  String get surfaceInterval_result_ndlForSecondDive => 'NDL a 2. merüléshez';

  @override
  String surfaceInterval_result_ndlMinutes(Object minutes) {
    return '$minutes perc NDL';
  }

  @override
  String surfaceInterval_result_noIntervalHelps(Object minutes) {
    return 'Semmilyen felszíni intervallum nem elegendő. A leghosszabb dekompresszió nélküli merülés ezen a mélységen ezzel a keverékkel $minutes perc. Rövidítsd le a második merülést vagy csökkentsd a mélységét.';
  }

  @override
  String get surfaceInterval_result_notAchievable =>
      'Semmilyen felszíni intervallummal nem érhető el';

  @override
  String get surfaceInterval_result_notYetSafe =>
      'Még nem biztonságos, növeld a felszíni intervallumot';

  @override
  String get surfaceInterval_result_safeToDive => 'Biztonságos merülni';

  @override
  String surfaceInterval_result_semantics(
    Object interval,
    Object current,
    Object ndl,
    Object status,
  ) {
    return 'Minimum felszíni intervallum: $interval. Jelenlegi intervallum: $current. NDL a második merüléshez: $ndl. $status';
  }

  @override
  String surfaceInterval_secondDive_depthSemantics(Object depth, Object unit) {
    return 'Második merülés mélysége: $depth $unit';
  }

  @override
  String surfaceInterval_secondDive_heSemantics(Object percent) {
    return 'Második merülés hélium: $percent%';
  }

  @override
  String surfaceInterval_secondDive_o2Semantics(Object percent) {
    return 'Második merülés O2: $percent%';
  }

  @override
  String surfaceInterval_secondDive_timeSemantics(Object time) {
    return 'Második merülés ideje: $time perc';
  }

  @override
  String get surfaceInterval_secondDive_title => 'Második merülés';

  @override
  String surfaceInterval_tissueRecovery_chartSemantics(Object interval) {
    return 'Szövet helyreállítási grafikon, amely 16 kamra kiürülését mutatja $interval felszíni intervallum alatt';
  }

  @override
  String get surfaceInterval_tissueRecovery_compartmentsLabel =>
      'Kamrák (felezési idő sebesség szerint)';

  @override
  String get surfaceInterval_tissueRecovery_description =>
      '16 szövetkamra kiürülésének mutatása a felszíni intervallum alatt';

  @override
  String get surfaceInterval_tissueRecovery_fast => 'Gyors (C1-5)';

  @override
  String surfaceInterval_tissueRecovery_leadingCompartment(Object number) {
    return 'Vezető kamra: C$number';
  }

  @override
  String get surfaceInterval_tissueRecovery_loadingPercent => 'Telítettség %';

  @override
  String get surfaceInterval_tissueRecovery_medium => 'Közepes (C6-10)';

  @override
  String get surfaceInterval_tissueRecovery_min => 'Perc';

  @override
  String get surfaceInterval_tissueRecovery_now => 'Most';

  @override
  String get surfaceInterval_tissueRecovery_slow => 'Lassú (C11-16)';

  @override
  String get surfaceInterval_tissueRecovery_title => 'Szövet helyreállítás';

  @override
  String get surfaceInterval_title => 'Felszíni intervallum';

  @override
  String tags_action_createNamed(Object tagName) {
    return '\"$tagName\" létrehozása';
  }

  @override
  String get tags_action_createTag => 'Címke létrehozása';

  @override
  String get tags_action_browse => 'Tallózás';

  @override
  String get tags_picker_title => 'Címkék kiválasztása';

  @override
  String get tags_picker_empty =>
      'Még nincsenek címkék. Írj be egy címkenevet az első létrehozásához.';

  @override
  String tags_picker_errorLoading(String error) {
    return 'Hiba a címkék betöltésekor: $error';
  }

  @override
  String get tags_picker_allAdded => 'Minden címke már hozzá van adva.';

  @override
  String get tags_picker_noMatches => 'Nincs a keresésnek megfelelő címke.';

  @override
  String tags_picker_addCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count címke hozzáadása',
      one: '1 címke hozzáadása',
      zero: 'Címkék hozzáadása',
    );
    return '$_temp0';
  }

  @override
  String get tags_action_deleteTag => 'Címke törlése';

  @override
  String tags_dialog_deleteMessage(Object tagName) {
    return 'Biztosan törölni szeretnéd: \"$tagName\"? Ez eltávolítja az összes merülésről.';
  }

  @override
  String get tags_dialog_deleteTitle => 'Címke törlése?';

  @override
  String get tags_empty =>
      'Még nincsenek címkék. Hozz létre címkéket a merülések szerkesztésekor.';

  @override
  String get tags_hint_addMoreTags => 'További címkék hozzáadása...';

  @override
  String get importWizard_tagsLabel => 'Tags';

  @override
  String get importWizard_photos_stepLabel => 'Fényképek';

  @override
  String importWizard_photos_foundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fénykép szerepel ebben a naplóban',
      one: '1 fénykép szerepel ebben a naplóban',
    );
    return '$_temp0';
  }

  @override
  String get importWizard_photos_chooseFolder => 'Fényképmappa kiválasztása...';

  @override
  String get importWizard_photos_scanning => 'Mappa vizsgálata...';

  @override
  String importWizard_photos_matchSummary(
    int matched,
    int byName,
    int missing,
  ) {
    return '$matched párosítva, $byName csak fájlnév alapján, $missing nem található';
  }

  @override
  String get importWizard_photos_skip => 'Fényképek kihagyása';

  @override
  String get importWizard_photos_mobileUnsupported =>
      'A fényképek importálásához az eszköz lemezén lévő mappa szükséges. Futtasd ezt az importálást számítógépen, hogy a fényképek is bekerüljenek. A merülések és a merülőhelyek normálisan importálódnak.';

  @override
  String importWizard_review_olderDivesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count régebbi merülés kihagyva — már szerepel a naplódban',
      one: '1 régebbi merülés kihagyva — már szerepel a naplódban',
    );
    return '$_temp0';
  }

  @override
  String get tags_hint_addTags => 'Címkék hozzáadása...';

  @override
  String get tags_manage_title => 'Címkék';

  @override
  String get tags_manage_searchHint => 'Címkék keresése...';

  @override
  String tags_manage_diveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merülés',
      one: '1 merülés',
      zero: '0 merülés',
    );
    return '$_temp0';
  }

  @override
  String get tags_manage_emptyState =>
      'Még nincsenek címkék. Hozzon létre egyet a kezdéshez.';

  @override
  String tags_manage_selectedCount(int count) {
    return '$count kijelölve';
  }

  @override
  String get tags_manage_createTitle => 'Címke létrehozása';

  @override
  String get tags_manage_editTitle => 'Címke szerkesztése';

  @override
  String get tags_manage_nameLabel => 'Címke neve';

  @override
  String get tags_manage_colorLabel => 'Szín';

  @override
  String get tags_manage_nameRequired => 'A címke neve kötelező';

  @override
  String get tags_manage_deleteTitle => 'Címke törlése?';

  @override
  String tags_manage_deleteMessage(String tagName, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merülésből',
      one: '1 merülésből',
      zero: '0 merülésből',
    );
    return 'A(z) \"$tagName\" eltávolításra kerül $_temp0. Ez nem vonható vissza.';
  }

  @override
  String tags_manage_bulkDeleteTitle(int count) {
    return '$count címke törlése?';
  }

  @override
  String tags_manage_bulkDeleteMessage(int diveCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount merülésből',
      one: '1 merülésből',
      zero: '0 merülésből',
    );
    return 'Ezek a címkék eltávolításra kerülnek összesen $_temp0. Ez nem vonható vissza.';
  }

  @override
  String tags_manage_mergeTitle(int count) {
    return '$count címke összevonása';
  }

  @override
  String get tags_manage_mergeResultName => 'Eredmény címke neve:';

  @override
  String get tags_manage_mergeKeepFrom => 'Vagy tartsa meg a nevet innen:';

  @override
  String tags_manage_mergeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merülést',
      one: '1 merülést',
      zero: '0 merülést',
    );
    return 'Ez összesen $_temp0 érint.';
  }

  @override
  String get tags_manage_mergeAction => 'Összevonás';

  @override
  String get tags_title_manageTags => 'Címkék kezelése';

  @override
  String get tank_al30Stage_description => 'Aluminium 30 cu ft stage palack';

  @override
  String get tank_al30Stage_displayName => 'AL30 Stage';

  @override
  String get tank_al40Stage_description => 'Aluminium 40 cu ft stage palack';

  @override
  String get tank_al40Stage_displayName => 'AL40 Stage';

  @override
  String get tank_al40_description => 'Aluminium 40 cu ft (pony)';

  @override
  String get tank_al40_displayName => 'AL40';

  @override
  String get tank_al63_description => 'Aluminium 63 cu ft';

  @override
  String get tank_al63_displayName => 'AL63';

  @override
  String get tank_al80_description => 'Aluminium 80 cu ft (legelterjedtebb)';

  @override
  String get tank_al80_displayName => 'AL80';

  @override
  String get tank_hp100_description => 'Nagynyomasu acel 100 cu ft';

  @override
  String get tank_hp100_displayName => 'HP100';

  @override
  String get tank_hp120_description => 'Nagynyomasu acel 120 cu ft';

  @override
  String get tank_hp120_displayName => 'HP120';

  @override
  String get tank_hp80_description => 'Nagynyomasu acel 80 cu ft';

  @override
  String get tank_hp80_displayName => 'HP80';

  @override
  String get tank_lp85_description => 'Kisnyomasu acel 85 cu ft';

  @override
  String get tank_lp85_displayName => 'LP85';

  @override
  String get tank_steel10_description => 'Acel 10 literes (Europa)';

  @override
  String get tank_steel10_displayName => 'Steel 10L';

  @override
  String get tank_steel12_description => 'Acel 12 literes (Europa)';

  @override
  String get tank_steel12_displayName => 'Steel 12L';

  @override
  String get tank_steel15_description => 'Acel 15 literes (Europa)';

  @override
  String get tank_steel15_displayName => 'Steel 15L';

  @override
  String get tides_action_refresh => 'Árapály adatok frissítése';

  @override
  String get tides_chart_24hourForecast => '24 órás előrejelzés';

  @override
  String tides_chart_heightAxis(Object depthSymbol) {
    return 'Magasság ($depthSymbol)';
  }

  @override
  String get tides_chart_msl => 'Tengerszint';

  @override
  String tides_chart_nowLabel(Object nowHeightStr, Object nowTimeStr) {
    return ' Most $nowTimeStr $nowHeightStr';
  }

  @override
  String get tides_error_unableToLoad =>
      'Nem lehet betölteni az árapály adatokat';

  @override
  String get tides_error_unableToLoadChart => 'Nem lehet betölteni a grafikont';

  @override
  String tides_label_ago(Object duration) {
    return '$duration ezelőtt';
  }

  @override
  String tides_label_currentHeight(Object height, Object depthSymbol) {
    return 'Jelenlegi: $height$depthSymbol';
  }

  @override
  String tides_label_fromNow(Object duration) {
    return '$duration múlva';
  }

  @override
  String get tides_label_high => 'Dagály';

  @override
  String get tides_label_highIn => 'Dagály';

  @override
  String get tides_label_highTide => 'Dagály';

  @override
  String get tides_label_low => 'Apály';

  @override
  String get tides_label_lowIn => 'Apály';

  @override
  String get tides_label_lowTide => 'Apály';

  @override
  String tides_label_tideIn(Object duration) {
    return '$duration múlva';
  }

  @override
  String get tides_label_tideTimes => 'Árapály időpontok';

  @override
  String get tides_label_today => 'Ma';

  @override
  String get tides_label_tomorrow => 'Holnap';

  @override
  String get tides_label_upcomingTides => 'Közelgő árapályok';

  @override
  String get tides_legend_highTide => 'Dagály';

  @override
  String get tides_legend_lowTide => 'Apály';

  @override
  String get tides_legend_now => 'Most';

  @override
  String get tides_legend_tideLevel => 'Árapály szint';

  @override
  String get tides_noDataAvailable => 'Nincs elérhető árapály adat';

  @override
  String get tides_noDataForLocation =>
      'Árapály adat nem elérhető erre a helyszínre';

  @override
  String get tides_noExtremesData => 'Nincs szélső érték adat';

  @override
  String get tides_noTideTimesAvailable =>
      'Nincsenek elérhető árapály időpontok';

  @override
  String tides_semantic_currentTide(
    Object tideState,
    Object height,
    Object depthSymbol,
    Object nextExtreme,
  ) {
    return '$tideState árapály, $height$depthSymbol$nextExtreme';
  }

  @override
  String tides_semantic_extremeItem(
    Object typeLabel,
    Object time,
    Object height,
    Object depthSymbol,
  ) {
    return '$typeLabel árapály $time időpontban, $height$depthSymbol';
  }

  @override
  String tides_semantic_tideChart(Object extremesSummary) {
    return 'Árapály grafikon. $extremesSummary';
  }

  @override
  String tides_semantic_tideState(Object state) {
    return 'Árapály állapot: $state';
  }

  @override
  String tides_source_noaaStation(String name, String distance) {
    return 'NOAA állomás: $name ($distance)';
  }

  @override
  String get tides_source_modelEstimate => 'Óceánmodell-becslés';

  @override
  String get tides_source_modelCaveat =>
      'Műholdadatok alapján modellezve. Az időpontok és magasságok eltérhetnek összetett partvonalak közelében.';

  @override
  String get tides_source_sheetTitle => 'Árapályadatok forrása';

  @override
  String get tides_source_datumMllw =>
      'Magasságok az MLLW-hez képest (állomási alapszint)';

  @override
  String get tides_source_datumMsl =>
      'Magasságok a közepes tengerszinthez képest';

  @override
  String get tides_title => 'Árapály';

  @override
  String get transfer_appBar_title => 'Atvitel';

  @override
  String get transfer_computers_aboutContent =>
      'Csatlakoztassa merülesi szamitogepejet Bluetooth-on keresztül, es toltse le a merülesi naplokat kozvetlenül az alkalmazasba. Tamogatott szamitogepek: Suunto, Shearwater, Garmin, Mares es sok mas nepszeru marka.\n\nAz Apple Watch Ultra felhasznalok kozvetlenül importalhatjak a merülesi adatokat a Health alkalmazasbol, beleertve a melyseg, idotartam es szivfrekvencia adatokat.';

  @override
  String get transfer_computers_aboutTitle => 'Merülesi szamitogepek';

  @override
  String get transfer_computers_appleWatchHeader => 'Apple Watch';

  @override
  String get transfer_computers_appleWatchSubtitle =>
      'Import dives via Apple HealthKit';

  @override
  String get transfer_computers_appleWatchTitle => 'Importalas Apple Watch-rol';

  @override
  String get transfer_computers_connectSubtitle =>
      'Merülesi szamitogep felderitese es parositas';

  @override
  String get transfer_computers_connectTitle => 'Uj szamitogep csatlakoztatasa';

  @override
  String get transfer_computers_errorLoading =>
      'Hiba a szamitogepek betoltesekor';

  @override
  String get transfer_computers_loading => 'Betoltes...';

  @override
  String get transfer_computers_manageTitle => 'Szamitogepek kezelese';

  @override
  String get transfer_computers_noComputersSaved =>
      'Nincsenek mentett szamitogepek';

  @override
  String transfer_computers_diveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merülés',
      one: '1 merülés',
    );
    return '$_temp0';
  }

  @override
  String get transfer_computers_downloadTooltip => 'Merülések letöltése';

  @override
  String get transfer_computers_knownComputersHeader => 'Ismert számítógépek';

  @override
  String transfer_computers_lastDownloadDaysAgo(int days) {
    return '$days napja';
  }

  @override
  String transfer_computers_lastDownloadHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours órája',
    );
    return '$_temp0';
  }

  @override
  String transfer_computers_lastDownloadMinutesAgo(int minutes) {
    return '$minutes perce';
  }

  @override
  String get transfer_computers_lastDownloadNever => 'Soha';

  @override
  String get transfer_computers_lastDownloadYesterday => 'Tegnap';

  @override
  String transfer_computers_savedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'szamitogep',
      one: 'szamitogep',
    );
    return '$count mentett $_temp0';
  }

  @override
  String get transfer_computers_sectionHeader => 'Merülesi szamitogepek';

  @override
  String get transfer_csvExport_cancelButton => 'Megse';

  @override
  String get transfer_csvExport_dataTypeHeader => 'Adattipus';

  @override
  String get transfer_csvExport_descriptionDives =>
      'Az osszes merülesi naplo exportalasa tablazatkent';

  @override
  String get transfer_csvExport_descriptionEquipment =>
      'Felszereles leltarazasa es szervizinformaciok exportalasa';

  @override
  String get transfer_csvExport_descriptionSites =>
      'Merülohelyek es reszleteik exportalasa';

  @override
  String get transfer_csvExport_dialogTitle => 'CSV exportalas';

  @override
  String get transfer_csvExport_exportButton => 'CSV exportalas';

  @override
  String get transfer_csvExport_optionDivesTitle => 'Merülesek CSV';

  @override
  String get transfer_csvExport_optionEquipmentTitle => 'Felszereles CSV';

  @override
  String get transfer_csvExport_optionSitesTitle => 'Merülohelyek CSV';

  @override
  String transfer_csvExport_semanticLabel(Object typeName) {
    return '$typeName exportalasa';
  }

  @override
  String get transfer_csvExport_typeDives => 'Merülesek';

  @override
  String get transfer_csvExport_typeEquipment => 'Felszereles';

  @override
  String get transfer_csvExport_typeSites => 'Merülohelyek';

  @override
  String get transfer_detail_backTooltip => 'Vissza az atvitelhez';

  @override
  String get transfer_export_aboutContent =>
      'Merülesi adatok exportalasa különbozo formatumokban. A PDF nyomtathato naplokonyvet keszit. Az UDDF egy univerzalis formatum, amely kompatibilis a legtobb merülesi naplo szoftverrel. A CSV fajlokat tablazatkezelo alkalmazasokban nyithatja meg.';

  @override
  String get transfer_export_backupLink => 'Mentés és visszaállítás';

  @override
  String get transfer_export_aboutTitle => 'Az exportalasrol';

  @override
  String get transfer_export_completed => 'Exportalas befejezve';

  @override
  String get transfer_export_csvSubtitle => 'Tablazat formatum';

  @override
  String get transfer_export_csvTitle => 'CSV exportalas';

  @override
  String get transfer_export_excelSubtitle =>
      'Minden adat egy fajlban (merülesek, merülohelyek, felszereles, statisztikak)';

  @override
  String get transfer_export_excelTitle => 'Excel munkafuzet';

  @override
  String transfer_export_failed(Object error) {
    return 'Exportalas sikertelen: $error';
  }

  @override
  String get transfer_export_kmlSubtitle =>
      'Merülohelyek megtekintese 3D foldgombon';

  @override
  String get transfer_export_kmlTitle => 'Google Earth KML';

  @override
  String get transfer_export_multiFormatHeader => 'Tobb formatum exportalas';

  @override
  String get transfer_export_optionSaveSubtitle =>
      'Valassza ki a mentesi helyet az eszkozön';

  @override
  String get transfer_export_optionSaveTitle => 'Mentes fajlba';

  @override
  String get transfer_export_optionShareSubtitle =>
      'Küldes e-mailben, üzenetben vagy mas alkalmazassal';

  @override
  String get transfer_export_optionShareTitle => 'Megosztas';

  @override
  String get transfer_export_pdfSubtitle => 'Nyomtathato merülesi naplo';

  @override
  String get transfer_export_pdfTitle => 'PDF naplokonyv';

  @override
  String get transfer_export_progressExporting => 'Exportalas...';

  @override
  String get transfer_export_sectionHeader => 'Adatok exportalasa';

  @override
  String get transfer_export_uddfSubtitle =>
      'Univerzalis merülesi adat formatum';

  @override
  String get transfer_export_uddfTitle => 'UDDF exportalas';

  @override
  String get transfer_import_aboutContent =>
      'Az \"Adatok importalasa\" hasznalata a legjobb elmeny -- automatikusan felismeri a fajlformatumot es a forras alkalmazast. Az egyes formatumok opcio alabb kozvetlenül is elerhetok.';

  @override
  String get transfer_import_aboutTitle => 'Az importalasrol';

  @override
  String get transfer_import_fileImportSemanticLabel =>
      'Adatok importalasa automatikus falismeréssel';

  @override
  String get transfer_import_fileImportSubtitle =>
      'Automatikusan felismeri a CSV, UDDF, FIT es mas formatumokat';

  @override
  String get transfer_import_fileImportTitle => 'Adatok importalasa';

  @override
  String get transfer_import_sectionHeader => 'Adatok importalasa';

  @override
  String get transfer_pdfExport_cancelButton => 'Megse';

  @override
  String get transfer_pdfExport_dialogTitle => 'PDF naplokonyv exportalasa';

  @override
  String get transfer_pdfExport_exportButton => 'PDF exportalas';

  @override
  String get transfer_pdfExport_includeCertCards =>
      'Tanusitvany kartyak beillesztese';

  @override
  String get transfer_pdfExport_includeCertCardsSubtitle =>
      'Beolvasott tanusitvany kartya kepek hozzaadasa a PDF-hez';

  @override
  String get transfer_pdfExport_pageSizeA4 => 'A4';

  @override
  String get transfer_pdfExport_pageSizeA4Desc => '210 x 297 mm';

  @override
  String get transfer_pdfExport_pageSizeHeader => 'Oldalmerret';

  @override
  String get transfer_pdfExport_pageSizeLetter => 'Letter';

  @override
  String get transfer_pdfExport_pageSizeLetterDesc => '8.5 x 11 in';

  @override
  String get transfer_pdfExport_templateDetailed => 'Reszletes';

  @override
  String get transfer_pdfExport_templateDetailedDesc =>
      'Teljes merülesi informacio jegyzetekkel es ertekelesekkel';

  @override
  String get transfer_pdfExport_templateHeader => 'Sablon';

  @override
  String get transfer_pdfExport_templateNauiStyle => 'NAUI stilusu';

  @override
  String get transfer_pdfExport_templateNauiStyleDesc =>
      'NAUI naplokonyv formatumnak megfelelo elrendezes';

  @override
  String get transfer_pdfExport_templatePadiStyle => 'PADI stilusu';

  @override
  String get transfer_pdfExport_templatePadiStyleDesc =>
      'PADI naplokonyv formatumnak megfelelo elrendezes';

  @override
  String get transfer_pdfExport_templateProfessional => 'Professzionalis';

  @override
  String get transfer_pdfExport_templateProfessionalDesc =>
      'Alairas es pecsethely a hitelesiteshez';

  @override
  String transfer_pdfExport_templateSemanticLabel(Object templateName) {
    return '$templateName sablon kivalasztasa';
  }

  @override
  String get transfer_pdfExport_templateSimple => 'Egyszeru';

  @override
  String get transfer_pdfExport_templateSimpleDesc =>
      'Tömor tablazatos formatum, sok merüles oldalankent';

  @override
  String get transfer_section_computersSubtitle => 'Letoltes eszkozrol';

  @override
  String get transfer_section_computersTitle => 'Merülesi szamitogepek';

  @override
  String get transfer_section_exportSubtitle => 'CSV, UDDF, PDF naplokonyv';

  @override
  String get transfer_section_exportTitle => 'Exportalas';

  @override
  String get transfer_section_importSubtitle => 'CSV, UDDF fajlok';

  @override
  String get transfer_section_importTitle => 'Importalas';

  @override
  String get transfer_summary_description =>
      'Merülesi adatok importalasa es exportalasa';

  @override
  String get transfer_summary_selectSection =>
      'Valasszon egy szekciót a listabol';

  @override
  String get transfer_summary_title => 'Atvitel';

  @override
  String transfer_unknownSection(Object sectionId) {
    return 'Ismeretlen szekció: $sectionId';
  }

  @override
  String get trips_appBar_title => 'Utak';

  @override
  String get trips_appBar_tripPhotos => 'Utifotok';

  @override
  String get trips_detail_action_delete => 'Torles';

  @override
  String get trips_detail_action_export => 'Exportalas';

  @override
  String get trips_detail_appBar_title => 'Ut';

  @override
  String get trips_detail_dialog_cancel => 'Megse';

  @override
  String get trips_detail_dialog_deleteConfirm => 'Torles';

  @override
  String trips_detail_dialog_deleteContent(Object name) {
    return 'Biztosan torli a(z) \"$name\" utat? Az ut torlodik, de a merülesek megmaradnak.';
  }

  @override
  String get trips_detail_dialog_deleteTitle => 'Ut torlese?';

  @override
  String get trips_detail_dives_empty => 'Meg nincsenek merülesek ezen az uton';

  @override
  String get trips_detail_dives_errorLoading =>
      'Nem sikerult a merülesek betoltese';

  @override
  String get trips_detail_dives_unknownSite => 'Ismeretlen merülohely';

  @override
  String trips_detail_dives_viewAll(Object count) {
    return 'Osszes megtekintese ($count)';
  }

  @override
  String trips_detail_durationDays(Object days) {
    return '$days nap';
  }

  @override
  String get trips_detail_export_csv_comingSoon => 'CSV exportalas hamarosan';

  @override
  String get trips_detail_export_csv_subtitle => 'Az ut osszes merülese';

  @override
  String get trips_detail_export_csv_title => 'Exportalas CSV-be';

  @override
  String get trips_detail_export_pdf_comingSoon => 'PDF exportalas hamarosan';

  @override
  String get trips_detail_export_pdf_subtitle =>
      'Ut osszefoglalo merülesi reszletekkel';

  @override
  String get trips_detail_export_pdf_title => 'Exportalas PDF-be';

  @override
  String get trips_detail_label_liveaboard => 'Hajoszallas';

  @override
  String get trips_detail_label_location => 'Helyszin';

  @override
  String get trips_detail_label_resort => 'Udulohely';

  @override
  String get trips_detail_scan_accessDenied =>
      'Fotogaleriahoz valo hozzaferes megtagadva';

  @override
  String get trips_detail_scan_addDivesFirst =>
      'Elobb adjon hozza merüleseket a fotok csatolasahoz';

  @override
  String trips_detail_scan_errorLinking(Object error) {
    return 'Hiba a fotok csatolasakor: $error';
  }

  @override
  String trips_detail_scan_errorScanning(Object error) {
    return 'Hiba a keresés soran: $error';
  }

  @override
  String trips_detail_scan_linkedPhotos(Object count) {
    return '$count foto csatolva';
  }

  @override
  String get trips_detail_scan_linkingPhotos => 'Fotok csatolasa...';

  @override
  String get trips_detail_sectionTitle_details => 'Ut reszletei';

  @override
  String get trips_detail_sectionTitle_dives => 'Merülesek';

  @override
  String get trips_detail_sectionTitle_notes => 'Jegyzetek';

  @override
  String get trips_detail_sectionTitle_statistics => 'Ut statisztikak';

  @override
  String get trips_detail_snackBar_deleted => 'Ut torolve';

  @override
  String get trips_detail_stat_avgDepth => 'Atl. melyseg';

  @override
  String get trips_detail_stat_maxDepth => 'Max. melyseg';

  @override
  String get trips_detail_stat_totalRuntime => 'Osszes futasido';

  @override
  String get trips_detail_stat_totalDives => 'Osszes merüles';

  @override
  String get trips_detail_tab_checklist => 'Ellenőrzőlista';

  @override
  String get trips_detail_tooltip_edit => 'Ut szerkesztese';

  @override
  String get trips_detail_tooltip_editShort => 'Szerkesztes';

  @override
  String get trips_detail_tooltip_moreOptions => 'Tobb lehetoseg';

  @override
  String get trips_detail_tooltip_viewOnMap => 'Megtekindes a terkepen';

  @override
  String trips_diveScan_addButton(int count) {
    return '$count merules hozzaadasa';
  }

  @override
  String trips_diveScan_added(int count) {
    return '$count merules hozzaadva az uthoz';
  }

  @override
  String get trips_diveScan_cancel => 'Megse';

  @override
  String trips_diveScan_currentTrip(String tripName) {
    return 'Jelenleg: $tripName';
  }

  @override
  String get trips_diveScan_deselectAll => 'Osszes kivalasztas torlese';

  @override
  String trips_diveScan_error(String error) {
    return 'Hiba a merulesek keresesekor: $error';
  }

  @override
  String get trips_diveScan_findButton => 'Egyezo merulesek keresese';

  @override
  String trips_diveScan_groupOtherTrips(int count) {
    return 'Mas utakon ($count)';
  }

  @override
  String trips_diveScan_groupUnassigned(int count) {
    return 'Nem hozzarendelt ($count)';
  }

  @override
  String get trips_diveScan_noMatches => 'Nem talalhatok egyezo merulesek';

  @override
  String get trips_diveScan_noDiver =>
      'Válassz ki egy aktív búvárt a merülések kereséséhez';

  @override
  String get trips_diveScan_selectAll => 'Osszes kivalasztasa';

  @override
  String trips_diveScan_subtitle(int count) {
    return '$count merules talalhato a datumtartomanyban';
  }

  @override
  String get trips_diveScan_title => 'Merulesek hozzaadasa az uthoz';

  @override
  String get trips_diveScan_unknownSite => 'Ismeretlen helyszin';

  @override
  String get trips_edit_appBar_add => 'Ut hozzaadasa';

  @override
  String get trips_edit_appBar_edit => 'Ut szerkesztese';

  @override
  String get trips_edit_button_add => 'Ut hozzaadasa';

  @override
  String get trips_edit_button_cancel => 'Megse';

  @override
  String get trips_edit_button_save => 'Mentes';

  @override
  String get trips_edit_button_update => 'Ut frissitese';

  @override
  String get trips_edit_dialog_discard => 'Elvetés';

  @override
  String get trips_edit_dialog_discardContent =>
      'Nem mentett valtoztatasai vannak. Biztosan el akar tavozni?';

  @override
  String get trips_edit_dialog_discardTitle => 'Valtoztatasok elvetese?';

  @override
  String get trips_edit_dialog_keepEditing => 'Szerkesztes folytatasa';

  @override
  String trips_edit_durationDays(Object days) {
    return '$days nap';
  }

  @override
  String get trips_edit_hint_liveaboardName => 'pl. MY Blue Force One';

  @override
  String get trips_edit_hint_location => 'pl. Egyiptom, Voros-tenger';

  @override
  String get trips_edit_hint_notes => 'Barmilyen megjegyzes errol az utrol';

  @override
  String get trips_edit_hint_resortName => 'pl. Marsa Shagra';

  @override
  String get trips_edit_hint_tripName => 'pl. Voros-tengeri szafari 2024';

  @override
  String get trips_edit_label_endDate => 'Befejezes datuma';

  @override
  String get trips_edit_label_liveaboardName => 'Hajoszallas neve';

  @override
  String get trips_edit_label_location => 'Helyszin';

  @override
  String get trips_edit_label_notes => 'Jegyzetek';

  @override
  String get trips_edit_label_resortName => 'Udulohely neve';

  @override
  String get trips_edit_label_returnFlight => 'Visszaúti járat';

  @override
  String get trips_edit_returnFlightClear => 'Visszaúti járat törlése';

  @override
  String get trips_edit_returnFlightNotSet => 'Nincs megadva';

  @override
  String get trips_edit_label_startDate => 'Kezdes datuma';

  @override
  String get trips_edit_label_tripName => 'Ut neve *';

  @override
  String get trips_edit_sectionTitle_dates => 'Ut datumai';

  @override
  String get trips_edit_sectionTitle_location => 'Helyszin';

  @override
  String get trips_edit_sectionTitle_notes => 'Jegyzetek';

  @override
  String get trips_edit_semanticLabel_save => 'Ut mentese';

  @override
  String get trips_edit_snackBar_added => 'Ut sikeresen hozzaadva';

  @override
  String trips_edit_snackBar_errorLoading(Object error) {
    return 'Hiba az ut betoltesekor: $error';
  }

  @override
  String trips_edit_snackBar_errorSaving(Object error) {
    return 'Hiba az ut mentesekor: $error';
  }

  @override
  String get trips_edit_snackBar_updated => 'Ut sikeresen frissitve';

  @override
  String get trips_edit_validation_nameRequired =>
      'Kerem, adja meg az ut nevet';

  @override
  String get trips_gallery_accessDenied =>
      'Fotogaleriahoz valo hozzaferes megtagadva';

  @override
  String get trips_gallery_addDivesFirst =>
      'Elobb adjon hozza merüleseket a fotok csatolasahoz';

  @override
  String get trips_gallery_appBar_title => 'Utifotok';

  @override
  String trips_gallery_diveSection_photoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'foto',
      one: 'foto',
    );
    return '$_temp0';
  }

  @override
  String trips_gallery_diveSection_title(Object number, Object site) {
    return '#$number. merüles - $site';
  }

  @override
  String get trips_gallery_empty_subtitle =>
      'Koppintson a kamera ikonra a galeria atnezesehez';

  @override
  String get trips_gallery_empty_title => 'Nincsenek fotok ezen az uton';

  @override
  String trips_gallery_errorLinking(Object error) {
    return 'Hiba a fotok csatolasakor: $error';
  }

  @override
  String trips_gallery_errorScanning(Object error) {
    return 'Hiba a keresés soran: $error';
  }

  @override
  String trips_gallery_error_loading(Object error) {
    return 'Hiba a fotok betoltesekor: $error';
  }

  @override
  String trips_gallery_linkedPhotos(Object count) {
    return '$count foto csatolva';
  }

  @override
  String get trips_gallery_linkingPhotos => 'Fotok csatolasa...';

  @override
  String get trips_gallery_tooltip_scan => 'Eszköz galeria atnezes';

  @override
  String get trips_gallery_tripNotFound => 'Ut nem talalhato';

  @override
  String get trips_list_button_retry => 'Ujraproba';

  @override
  String trips_list_countdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days nap múlva',
      one: '1 nap múlva',
      zero: 'Ma indul',
    );
    return '$_temp0';
  }

  @override
  String get trips_list_empty_button => 'Adja hozza az elso utat';

  @override
  String get trips_list_empty_filtered_subtitle =>
      'Probalja meg modositani vagy torolni a szuroket';

  @override
  String get trips_list_empty_filtered_title =>
      'Nincs a szuroknek megfelelo ut';

  @override
  String get trips_list_empty_subtitle =>
      'Hozzon letre utakat a merülesek cel szerinti csoportositasahoz';

  @override
  String get trips_list_empty_title => 'Meg nincsenek utak hozzaadva';

  @override
  String trips_list_error_loading(Object error) {
    return 'Hiba az utak betoltesekor: $error';
  }

  @override
  String get trips_list_fab_addTrip => 'Ut hozzaadasa';

  @override
  String get trips_list_filters_clearAll => 'Osszes torles';

  @override
  String get trips_list_inProgress => 'Folyamatban';

  @override
  String get trips_list_pastSection => 'Korábbi utak';

  @override
  String get trips_list_sort_title => 'Utak rendezese';

  @override
  String trips_list_tile_diveCount(Object count) {
    return '$count merüles';
  }

  @override
  String get trips_list_tooltip_addTrip => 'Ut hozzaadasa';

  @override
  String get trips_list_tooltip_search => 'Utak keresese';

  @override
  String get trips_list_tooltip_sort => 'Rendezes';

  @override
  String get trips_list_upcomingSection => 'Közelgő';

  @override
  String get trips_photos_empty_scanButton => 'Eszköz galeria atnezes';

  @override
  String get trips_photos_empty_title => 'Meg nincsenek fotok';

  @override
  String get trips_photos_error_loading => 'Hiba a fotok betoltesekor';

  @override
  String trips_photos_moreIndicator(Object count) {
    return '+$count';
  }

  @override
  String trips_photos_moreIndicator_semanticLabel(Object count) {
    return '$count tovabbi foto';
  }

  @override
  String get trips_photos_sectionTitle => 'Fotok';

  @override
  String get trips_photos_tooltip_scan => 'Eszköz galeria atnezes';

  @override
  String get trips_photos_viewAll => 'Osszes megtekintese';

  @override
  String get trips_picker_clearTooltip => 'Kivalasztas torlese';

  @override
  String get trips_picker_empty_createButton => 'Ut letrehozasa';

  @override
  String get trips_picker_empty_title => 'Meg nincsenek utak';

  @override
  String trips_picker_error(Object error) {
    return 'Hiba az utak betoltesekor: $error';
  }

  @override
  String get trips_picker_hint => 'Koppintson egy ut kivalasztasahoz';

  @override
  String get trips_picker_newTrip => 'Uj ut';

  @override
  String get trips_picker_noSelection => 'Nincs ut kivalasztva';

  @override
  String get trips_picker_sheetTitle => 'Ut kivalasztasa';

  @override
  String trips_picker_suggestedPrefix(Object name) {
    return 'Javasolt: $name';
  }

  @override
  String get trips_picker_suggestedUse => 'Hasznalat';

  @override
  String get trips_search_empty_hint =>
      'Kereses nev, helyszin vagy udulohely alapjan';

  @override
  String get trips_search_fieldLabel => 'Utak keresese...';

  @override
  String trips_search_noResults(Object query) {
    return 'Nem talalhato ut a kovetkezore: \"$query\"';
  }

  @override
  String get trips_search_tooltip_back => 'Vissza';

  @override
  String get trips_search_tooltip_clear => 'Kereses torlese';

  @override
  String get trips_summary_header_subtitle =>
      'Valasszon egy utat a listabol a reszletek megtekintésehez';

  @override
  String get trips_summary_header_title => 'Utak';

  @override
  String get trips_summary_overview_title => 'Attekintes';

  @override
  String get trips_summary_quickActions_add => 'Ut hozzaadasa';

  @override
  String get trips_summary_quickActions_title => 'Gyorsmuveletek';

  @override
  String trips_summary_recentSubtitle(Object date, Object count) {
    return '$date • $count merüles';
  }

  @override
  String get trips_summary_recentTitle => 'Legutobbi utak';

  @override
  String get trips_summary_stat_daysDiving => 'Merülesi napok';

  @override
  String get trips_summary_stat_liveaboards => 'Hajoszallasok';

  @override
  String get trips_summary_stat_totalDives => 'Osszes merüles';

  @override
  String get trips_summary_stat_totalTrips => 'Osszes ut';

  @override
  String trips_summary_upcomingSubtitle(Object date, Object days) {
    return '$date • $days nap mulva';
  }

  @override
  String get trips_summary_upcomingTitle => 'Kozelgo';

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
  String get units_sac_pressurePerMin => 'nyomas/min';

  @override
  String get units_temperature_celsius => 'C';

  @override
  String get units_temperature_fahrenheit => 'F';

  @override
  String get units_timeFormat_twelveHour => '12 oras';

  @override
  String get units_timeFormat_twentyFourHour => '24 oras';

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
      'Egyesietes masodik szamitogepi adatkent';

  @override
  String get universalImport_action_continue => 'Folytatás';

  @override
  String get universalImport_action_deselectAll => 'Összes kijelölés törlése';

  @override
  String get universalImport_action_done => 'Kész';

  @override
  String get universalImport_action_import => 'Importálás';

  @override
  String get universalImport_action_selectAll => 'Összes kijelölése';

  @override
  String get universalImport_action_changeFile => 'Fajl valtas';

  @override
  String get universalImport_action_selectFile => 'Fájl kiválasztása';

  @override
  String get universalImport_action_selectFiles => 'Fájlok kiválasztása';

  @override
  String get universalImport_action_chooseFolder => 'Mappa kiválasztása';

  @override
  String get universalImport_triage_title => 'Importálandó fájlok';

  @override
  String universalImport_triage_readyCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fájl importálásra kész',
      one: '1 fájl importálásra kész',
    );
    return '$_temp0';
  }

  @override
  String universalImport_label_filesSelected(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fájl kiválasztva',
      one: '1 fájl kiválasztva',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_triage_excludedCsv =>
      'Egyenkénti importálás (CSV)';

  @override
  String get universalImport_triage_unsupported => 'Nem támogatott formátum';

  @override
  String get universalImport_triage_parseFailed => 'Nem sikerült beolvasni';

  @override
  String universalImport_triage_parsing(int current, int total) {
    return 'Fájl feldolgozása: $current/$total…';
  }

  @override
  String get universalImport_triage_cancelParsing => 'Mégse';

  @override
  String get universalImport_triage_allExcluded =>
      'A kiválasztott fájlok együtt nem importálhatók. A CSV-fájlokat egyenként kell importálni.';

  @override
  String get universalImport_triage_noneImportable =>
      'A kiválasztott fájlok egyike sem importálható.';

  @override
  String get universalImport_review_inBatchDuplicate =>
      'Egy másik merülés duplikátuma ebben az importálási kötegben.';

  @override
  String get universalImport_summary_filesTitle => 'Fájlok';

  @override
  String get universalImport_summary_noticesTitle => 'Nincs a fájlban';

  @override
  String get universalImport_summary_noticeNoTankPressureTitle =>
      'A palack nyomása nincs rögzítve';

  @override
  String get universalImport_summary_noticeNoTankPressureBody =>
      'A levegőfogyasztás és a SAC nem számítható ki. A kezdő és záró nyomást a merülés szerkesztésével adhatod meg.';

  @override
  String universalImport_summary_noticeAffectedDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merülést érint',
      one: '1 merülést érint',
    );
    return '$_temp0';
  }

  @override
  String universalImport_summary_fileImported(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merülés importálva',
      one: '1 merülés importálva',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_summary_fileNeedsIndividualImport =>
      'Egyenkénti importálás szükséges';

  @override
  String get universalImport_summary_fileUnsupported =>
      'Nem támogatott formátum';

  @override
  String get universalImport_summary_fileParseFailed => 'Beolvasás sikertelen';

  @override
  String universalImport_bulk_consolidateMatched(int count) {
    return 'Egyezoek osszevonasa ($count)';
  }

  @override
  String universalImport_bulk_importAll(int count) {
    return 'Mind importalasa ($count)';
  }

  @override
  String universalImport_bulk_importAllAsNew(int count) {
    return 'Mind importalasa ujkent ($count)';
  }

  @override
  String universalImport_bulk_skipAll(int count) {
    return 'Mind kihagyasa ($count)';
  }

  @override
  String universalImport_bulk_replaceSourceAll(int count) {
    return 'Mind cseréje ($count)';
  }

  @override
  String get universalImport_description_supportedFormats =>
      'Válassz egy merülési napló fájlt az importáláshoz. Támogatott formátumok: CSV, UDDF, Subsurface XML és Garmin FIT.';

  @override
  String get universalImport_dive_decideAction => 'Dontes';

  @override
  String get universalImport_error_unsupportedFormat =>
      'Ez a formátum még nem támogatott. Exportálj UDDF vagy CSV formátumban.';

  @override
  String get universalImport_label_columnMapping => 'Oszlop leképezés';

  @override
  String universalImport_label_columnsMapped(Object mapped, Object total) {
    return '$mapped oszlop leképezve a(z) $total-ból';
  }

  @override
  String get universalImport_label_consolidate => 'Osszevonas';

  @override
  String get universalImport_label_detecting => 'Észlelés...';

  @override
  String universalImport_label_diveNumber(Object number) {
    return 'Merülés #$number';
  }

  @override
  String get universalImport_label_duplicate => 'Duplikátum';

  @override
  String universalImport_label_duplicatesFound(Object count) {
    return '$count duplikátum találva és automatikusan kijelölés törölve.';
  }

  @override
  String get universalImport_label_importAsNew => 'Importalas ujkent';

  @override
  String get universalImport_label_importComplete => 'Importálás kész';

  @override
  String get universalImport_label_importing => 'Importálás';

  @override
  String get universalImport_label_importingEllipsis => 'Importálás...';

  @override
  String universalImport_label_importingProgress(Object current, Object total) {
    return '$current importálása a(z) $total-ból';
  }

  @override
  String universalImport_label_percentMatch(Object percent) {
    return '$percent% egyezés';
  }

  @override
  String get universalImport_label_possibleMatch => 'Lehetséges egyezés';

  @override
  String get universalImport_label_selectCorrectSource =>
      'Nem helyes? Válaszd ki a megfelelő forrást:';

  @override
  String universalImport_label_selected(Object count) {
    return '$count kiválasztva';
  }

  @override
  String get universalImport_label_skip => 'Kihagyás';

  @override
  String universalImport_label_taggedAs(Object tag) {
    return 'Címkézve mint: $tag';
  }

  @override
  String get universalImport_label_unknownDate => 'Ismeretlen dátum';

  @override
  String get universalImport_label_unnamed => 'Névtelen';

  @override
  String universalImport_label_xOfY(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String universalImport_label_xOfYSelected(Object selected, Object total) {
    return '$selected kiválasztva a(z) $total-ból';
  }

  @override
  String get universalImport_entityAction_linkBadge => 'CSATOL';

  @override
  String get universalImport_entityAction_linkExisting =>
      'Összekapcsolás a meglévővel';

  @override
  String get universalImport_entityAction_linkExistingSubtitle =>
      'A talált rekord használata';

  @override
  String get universalImport_entityAction_replaceBadge => 'CSERE';

  @override
  String get universalImport_entityAction_replaceExisting => 'Meglévő cseréje';

  @override
  String get universalImport_entityAction_replaceExistingSubtitle =>
      'Felülírás az importált adatokkal';

  @override
  String get universalImport_entityAction_skip => 'Kihagyás';

  @override
  String get universalImport_entityAction_skipSubtitle => 'Az import elvetése';

  @override
  String get universalImport_entityAction_importAsNew => 'Importálás újként';

  @override
  String get universalImport_entityAction_importAsNewSubtitle =>
      'Külön bejegyzés létrehozása';

  @override
  String get universalImport_pending_chooseAction => 'Valassz muveletet';

  @override
  String universalImport_pending_gateHint(int count) {
    return '$count duplikatum dontest igenyel';
  }

  @override
  String get universalImport_pending_needsDecision => 'Dontes szukseges';

  @override
  String get universalImport_pending_reviewAction => 'Attekintes';

  @override
  String get universalImport_rowHint_tapCompareToDecide =>
      'Koppints a Dontes gombra a valasztashoz';

  @override
  String universalImport_semantics_entitySelection(
    Object selected,
    Object total,
    Object entityType,
  ) {
    return '$selected kiválasztva a(z) $total $entityType-ból';
  }

  @override
  String universalImport_semantics_importError(Object error) {
    return 'Import hiba: $error';
  }

  @override
  String universalImport_semantics_importProgress(Object percent) {
    return 'Import előrehaladás: $percent százalék';
  }

  @override
  String universalImport_semantics_itemsSelected(Object count) {
    return '$count elem kiválasztva importálásra';
  }

  @override
  String get universalImport_semantics_needsDecision =>
      'Valoszinu duplikatum, dontes szukseges';

  @override
  String get universalImport_semantics_possibleDuplicate =>
      'Lehetséges duplikátum';

  @override
  String get universalImport_semantics_probableDuplicate =>
      'Valószínű duplikátum';

  @override
  String universalImport_semantics_sourceDetected(Object description) {
    return 'Forrás észlelve: $description';
  }

  @override
  String universalImport_semantics_sourceUncertain(Object description) {
    return 'Forrás bizonytalan: $description';
  }

  @override
  String universalImport_semantics_toggleSelection(Object name) {
    return 'Kijelölés váltása: $name';
  }

  @override
  String universalImport_snackbar_bulkMarkedAs(int count, String action) {
    return '$count megjelolve mint $action';
  }

  @override
  String universalImport_snackbar_markedAs(String action) {
    return 'Megjelolve mint $action';
  }

  @override
  String get universalImport_step_import => 'Importálás';

  @override
  String get universalImport_step_map => 'Leképezés';

  @override
  String get universalImport_step_review => 'Áttekintés';

  @override
  String get universalImport_step_select => 'Kiválasztás';

  @override
  String get universalImport_summary_decidesRequired =>
      'Mindegyik dontest igenyel az importalas elott.';

  @override
  String get universalImport_title => 'Adatok importálása';

  @override
  String get universalImport_tooltip_closeWizard => 'Import varázsló bezárása';

  @override
  String weather_windFromDirection(Object wind, Object direction) {
    return '$wind $direction felol';
  }

  @override
  String get weather_wind_calm => 'szelcsend';

  @override
  String get weather_wind_highWind => 'eros szel';

  @override
  String get weather_wind_lightBreeze => 'gyenge szello';

  @override
  String get weather_wind_moderateBreeze => 'mersekelt szello';

  @override
  String get weather_wind_strongBreeze => 'elenk szello';

  @override
  String get weather_wmo_clear => 'Derult eg';

  @override
  String get weather_wmo_drizzle => 'Szitalo eso';

  @override
  String get weather_wmo_fog => 'Kod';

  @override
  String get weather_wmo_freezingDrizzle => 'Onodo szitalo eso';

  @override
  String get weather_wmo_freezingRain => 'Onodo eso';

  @override
  String get weather_wmo_mainlyClear => 'Tulnyomoan derult';

  @override
  String get weather_wmo_overcast => 'Borult';

  @override
  String get weather_wmo_partlyCloudy => 'Reszben felhos';

  @override
  String get weather_wmo_rain => 'Eso';

  @override
  String get weather_wmo_rainShowers => 'Zaporeso';

  @override
  String get weather_wmo_snow => 'Ho';

  @override
  String get weather_wmo_snowGrains => 'Hodara';

  @override
  String get weather_wmo_snowShowers => 'Hozapor';

  @override
  String get weather_wmo_thunderstorm => 'Zivatar';

  @override
  String get weather_wmo_thunderstormHail => 'Zivatar jegesovel';

  @override
  String weightCalc_baseLine(Object suitType, Object weight) {
    return 'Alap ($suitType): $weight kg';
  }

  @override
  String weightCalc_bodyWeightAdjustment(Object adjustment) {
    return 'Testsuly korrekció: +$adjustment kg';
  }

  @override
  String get weightCalc_suit_drysuit => 'Szaraz ruha';

  @override
  String get weightCalc_suit_none => 'Ruha nelkul';

  @override
  String get weightCalc_suit_rashguard => 'Csak rashguard';

  @override
  String get weightCalc_suit_semidry => 'Felig szaraz ruha';

  @override
  String get weightCalc_suit_shorty3mm => '3mm shorty';

  @override
  String get weightCalc_suit_wetsuit3mm => '3mm teljes neopren ruha';

  @override
  String get weightCalc_suit_wetsuit5mm => '5mm neopren ruha';

  @override
  String get weightCalc_suit_wetsuit7mm => '7mm neopren ruha';

  @override
  String weightCalc_tankLine(Object tankMaterial, Object adjustment) {
    return 'Palack ($tankMaterial): $adjustment kg';
  }

  @override
  String get weightCalc_title => 'Sulyszamitas:';

  @override
  String weightCalc_total(Object total) {
    return 'Osszes: $total kg';
  }

  @override
  String weightCalc_waterLine(Object waterType, Object adjustment) {
    return 'Viz ($waterType): $adjustment kg';
  }

  @override
  String divePlanner_label_resultsWithWarnings(Object count) {
    return 'Eredmények, $count figyelmeztetés';
  }

  @override
  String tides_semantic_tideCycle(Object state, Object height) {
    return 'Árapály ciklus, állapot: $state, magasság: $height';
  }

  @override
  String get tides_label_agoSuffix => 'ezelőtt';

  @override
  String get tides_label_fromNowSuffix => 'múlva';

  @override
  String get certifications_card_issued => 'KIALLITVA';

  @override
  String certifications_certificate_cardNumber(Object number) {
    return 'Kartyaszam: $number';
  }

  @override
  String get certifications_certificate_footer =>
      'Hivatalos buvarkepesite tanusitvany';

  @override
  String get certifications_certificate_hasCompletedTraining =>
      'sikeresen elvégezte a kepzest mint';

  @override
  String certifications_certificate_instructor(Object name) {
    return 'Oktato: $name';
  }

  @override
  String certifications_certificate_issued(Object date) {
    return 'Kiallitva: $date';
  }

  @override
  String get certifications_certificate_thisCertifies =>
      'Ezennel tanusitjuk, hogy';

  @override
  String get diveComputer_connectionType_ble => 'Bluetooth LE';

  @override
  String get diveComputer_connectionType_bluetooth => 'Bluetooth';

  @override
  String get diveComputer_connectionType_infrared => 'Infravoros';

  @override
  String get diveComputer_connectionType_unknown => 'Ismeretlen';

  @override
  String get diveComputer_connectionType_usb => 'USB';

  @override
  String get diveComputer_connectionType_wifi => 'Wi-Fi';

  @override
  String diveComputer_detail_deleteDialogContent(String name) {
    return 'Biztosan eltavolitod a(z) \"$name\" eszkozt? Ez nem torli az errol a szamitogeprol importalt merulseket.';
  }

  @override
  String get diveComputer_detail_deleteDialogTitle => 'Szamitogep torlese?';

  @override
  String get diveComputer_detail_divesImported => 'Importalt merulesek';

  @override
  String get diveComputer_detail_downloadDivesButton => 'Merulesek letoltese';

  @override
  String get diveComputer_detail_editDialogTitle => 'Szamitogep szerkesztese';

  @override
  String get diveComputer_detail_editNameHint => 'Peldaul Perdixem';

  @override
  String get diveComputer_detail_editNotesHint => 'Opcionalis megjegyzesek';

  @override
  String get diveComputer_detail_labelConnection => 'Kapcsolat';

  @override
  String get diveComputer_detail_labelManufacturer => 'Gyarto';

  @override
  String get diveComputer_detail_labelModel => 'Modell';

  @override
  String get diveComputer_detail_labelName => 'Nev';

  @override
  String get diveComputer_detail_lastDownload => 'Utolso letoltes';

  @override
  String get diveComputer_detail_notesTitle => 'Megjegyzesek';

  @override
  String get diveComputer_detail_reimportAllButton =>
      'Összes merülés újraimportálása';

  @override
  String diveComputer_detail_reimportDialogBody(String computerName) {
    return 'Minden merülés letöltése a(z) $computerName eszközről és összevetése a naplóddal. Ez több percig is eltarthat.';
  }

  @override
  String get diveComputer_detail_reimportDialogTitle =>
      'Összes merülés újraimportálása?';

  @override
  String get diveComputer_detail_statisticsTitle => 'Statisztikak';

  @override
  String get diveComputer_detail_unknown => 'Ismeretlen';

  @override
  String get diveComputer_detail_viewDivesButton =>
      'Errol a szamitogeprol szarmazo merulesek';

  @override
  String get diveComputer_discovery_chooseDifferentDevice =>
      'Masik eszkoz valasztasa';

  @override
  String get diveComputer_discovery_computer => 'Szamitogep';

  @override
  String get diveComputer_discovery_connectAndDownload =>
      'Csatlakozas es letoltes';

  @override
  String get diveComputer_discovery_connectingToDevice =>
      'Csatlakozas az eszkozhoz...';

  @override
  String diveComputer_discovery_deviceNameHint(Object model) {
    return 'pl. Az en $model';
  }

  @override
  String get diveComputer_discovery_deviceNameLabel => 'Eszkoz neve';

  @override
  String get diveComputer_discovery_exitDialogCancel => 'Megse';

  @override
  String get diveComputer_discovery_exitDialogConfirm => 'Kilepes';

  @override
  String get diveComputer_discovery_exitDialogContent =>
      'Biztosan ki szeretne lepni? A haladas elveszik.';

  @override
  String get diveComputer_discovery_exitDialogTitle =>
      'Kilepes a beallitasbol?';

  @override
  String get diveComputer_discovery_exitTooltip => 'Kilepes a beallitasbol';

  @override
  String get diveComputer_discovery_noDeviceSelected =>
      'Nincs eszkoz kivalasztva';

  @override
  String get diveComputer_discovery_pleaseWaitConnection =>
      'Kerem, varjon, amig letrehozzuk a kapcsolatot';

  @override
  String get diveComputer_discovery_recognizedDevice => 'Felismert eszkoz';

  @override
  String get diveComputer_discovery_recognizedDeviceDescription =>
      'Ez az eszkoz szerepel a tamogatott eszkozok konyvtaraban. A merulesek letoltese automatikusan mukodik.';

  @override
  String get diveComputer_discovery_stepConnect => 'Csatlakozas';

  @override
  String get diveComputer_discovery_stepDone => 'Kesz';

  @override
  String get diveComputer_discovery_stepDownload => 'Letoltes';

  @override
  String get diveComputer_discovery_stepScan => 'Kereses';

  @override
  String get diveComputer_discovery_titleComplete => 'Kesz';

  @override
  String get diveComputer_discovery_titleConfirmDevice => 'Eszkoz megerositese';

  @override
  String get diveComputer_discovery_titleConnecting => 'Csatlakozas';

  @override
  String get diveComputer_discovery_titleDownloading => 'Letoltes';

  @override
  String get diveComputer_discovery_titleFindDevice => 'Eszkoz keresese';

  @override
  String get diveComputer_discovery_unknownDevice => 'Ismeretlen eszkoz';

  @override
  String get diveComputer_discovery_unknownDeviceDescription =>
      'Ez az eszkoz nem szerepel a konyvtarunkban. Megprobaljuk csatlakoztatni, de a letoltes nem feltetlen mukodik.';

  @override
  String get diveComputer_discovery_usbInstructions =>
      'Csatlakoztassa búvárszámítógépét USB-kábellel, majd válassza ki alább.';

  @override
  String diveComputer_discovery_usbNoResults(String query) {
    return 'Nincs találat erre: \"$query\"';
  }

  @override
  String get diveComputer_discovery_usbSearchHint =>
      'Keresés gyártó vagy modell alapján...';

  @override
  String get diveComputer_downloadExit_content =>
      'A kilepes megszakitja a folyamatban levo letoltest a merulo szamitogeprol. Biztos vagy benne?';

  @override
  String get diveComputer_downloadExit_leave => 'Kilepes';

  @override
  String get diveComputer_downloadExit_stay => 'Maradas';

  @override
  String get diveComputer_downloadExit_title => 'Letoltes folyamatban';

  @override
  String diveComputer_downloadStep_andMoreDives(Object count) {
    return '... es meg $count tovabbi';
  }

  @override
  String get diveComputer_downloadStep_cancel => 'Megse';

  @override
  String get diveComputer_downloadStep_cancelled => 'Letoltes megszakitva';

  @override
  String diveComputer_downloadStep_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String get diveComputer_downloadStep_downloadAll =>
      'Összes merülés letöltése';

  @override
  String get diveComputer_downloadStep_downloadFailed =>
      'A letoltes sikertelen';

  @override
  String get diveComputer_downloadStep_downloadNew => 'Új merülések letöltése';

  @override
  String get diveComputer_downloadStep_downloadedDives => 'Letoltott merulesek';

  @override
  String diveComputer_downloadStep_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_downloadStep_errorOccurred => 'Hiba tortent';

  @override
  String diveComputer_downloadStep_errorSemanticLabel(Object error) {
    return 'Letoltesi hiba: $error';
  }

  @override
  String get diveComputer_downloadStep_firstSyncBody =>
      'A naplód már tartalmaz merüléseket. Kihagyhatod a már meglévő merülések letöltését.';

  @override
  String get diveComputer_downloadStep_firstSyncTitle =>
      'Első letöltés erről a merülésszámítógépről';

  @override
  String diveComputer_downloadStep_onlyAfterDate(String date) {
    return 'Csak a $date utáni merülések letöltése';
  }

  @override
  String diveComputer_downloadStep_percentAccessibility(Object percent) {
    return ', $percent szazalek';
  }

  @override
  String get diveComputer_downloadStep_preparing => 'Elokeszites...';

  @override
  String diveComputer_downloadStep_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String diveComputer_downloadStep_progressSemanticLabel(
    Object status,
    Object percent,
  ) {
    return 'Letoltesi folyamat: $status$percent';
  }

  @override
  String get diveComputer_downloadStep_retry => 'Ujraproba';

  @override
  String diveComputer_downloadStep_importPartialCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count letöltött merülés importálása',
      one: '1 letöltött merülés importálása',
    );
    return '$_temp0';
  }

  @override
  String get diveComputer_download_cancel => 'Megse';

  @override
  String get diveComputer_download_closeTooltip => 'Bezaras';

  @override
  String get diveComputer_download_computerNotFound =>
      'A szamitogep nem talalhato';

  @override
  String diveComputer_download_depthMeters(Object depth) {
    return '${depth}m';
  }

  @override
  String diveComputer_download_deviceNotFoundError(Object name) {
    return 'Az eszkoz nem talalhato. Gyozodjon meg rola, hogy a(z) $name a kozelben van es atviteli modban.';
  }

  @override
  String get diveComputer_download_deviceNotFoundTitle =>
      'Az eszkoz nem talalhato';

  @override
  String get diveComputer_download_divesUpdated => 'Merulesek frissitve';

  @override
  String get diveComputer_download_done => 'Kesz';

  @override
  String get diveComputer_download_downloadedDives => 'Letoltott merulesek';

  @override
  String get diveComputer_download_duplicatesSkipped => 'Duplikatumok kihagyva';

  @override
  String diveComputer_download_durationMin(Object duration) {
    return '$duration min';
  }

  @override
  String get diveComputer_download_errorOccurred => 'Hiba tortent';

  @override
  String get diveComputer_download_noSerialPortsFound =>
      'Nem található USB soros port. A búvárszámítógép csatlakoztatva van és be van kapcsolva?';

  @override
  String get diveComputer_download_stalePairing =>
      'Ennek a merülőkomputernek a Bluetooth-párosítása elavult. Felejtesd el a merülőkomputert az eszközöd Bluetooth-beállításaiban, majd párosítsd újra a merülőkomputer Bluetooth menüjéből.';

  @override
  String get diveComputer_download_discoveryStalled =>
      'A merülőkomputer csatlakozott, de a letöltés megkezdése előtt nem válaszolt tovább. Ez általában azt jelenti, hogy a Bluetooth-párosítás elavult: felejtesd el a merülőkomputert az eszközöd Bluetooth-beállításaiban, majd próbáld újra.';

  @override
  String diveComputer_download_serialConnectFailedWithDetails(Object details) {
    return 'Nem sikerült csatlakozni a búvárszámítógéphez.\n\nDiagnosztikai részletek (ossza meg a fejlesztőkkel):\n$details';
  }

  @override
  String diveComputer_download_errorWithMessage(Object error) {
    return 'Hiba: $error';
  }

  @override
  String get diveComputer_download_goBack => 'Vissza';

  @override
  String get diveComputer_download_importFailed => 'Az importalas sikertelen';

  @override
  String get diveComputer_download_importResults => 'Importalasi eredmenyek';

  @override
  String get diveComputer_download_importedDives => 'Importalt merulesek';

  @override
  String diveComputer_download_importingCountDives(int count) {
    return '$count merülés importálása...';
  }

  @override
  String diveComputer_download_importingCountNewDives(int count) {
    return '$count új merülés importálása...';
  }

  @override
  String get diveComputer_download_newDivesImported =>
      'Uj merulesek importalva';

  @override
  String get diveComputer_download_newDivesOnlySubtitle =>
      'Csak az utolsó szinkronizálás óta hozzáadott merüléseket tölti le';

  @override
  String get diveComputer_download_newDivesOnlyTitle =>
      'Csak új merülések letöltése';

  @override
  String get diveComputer_download_preparing => 'Elokeszites...';

  @override
  String diveComputer_download_progressPercent(Object percent) {
    return '$percent%';
  }

  @override
  String get diveComputer_download_reimportHint =>
      'Régebbi vagy törölt merüléseket keresel? Mindet újraimportálni';

  @override
  String get diveComputer_download_retry => 'Ujraproba';

  @override
  String diveComputer_download_scanError(Object error) {
    return 'Keresesi hiba: $error';
  }

  @override
  String diveComputer_download_searchingForDevice(Object name) {
    return 'Kereses: $name...';
  }

  @override
  String get diveComputer_download_searchingInstructions =>
      'Gyozodjon meg rola, hogy az eszkoz a kozelben van es atviteli modban';

  @override
  String get diveComputer_download_title => 'Merulesek letoltese';

  @override
  String get diveComputer_download_tryAgain => 'Probald ujra';

  @override
  String get diveComputer_download_upToDate =>
      'Nem található új merülés -- a naplód naprakész';

  @override
  String get diveComputer_list_addComputer => 'Szamitogep hozzaadasa';

  @override
  String diveComputer_list_cardSemanticLabel(Object name) {
    return 'Merulesszamitogep: $name';
  }

  @override
  String diveComputer_list_diveCount(Object count) {
    return '$count merules';
  }

  @override
  String get diveComputer_list_downloadTooltip => 'Merulesek letoltese';

  @override
  String get diveComputer_list_emptyMessage =>
      'Csatlakoztassa merulesszamitogepet, hogy kozvetlenul letolthesse a meruleseket az alkalmazasba.';

  @override
  String get diveComputer_list_emptyTitle => 'Nincsenek merulesszamitogepek';

  @override
  String get diveComputer_list_findComputers => 'Szamitogepek keresese';

  @override
  String get diveComputer_list_helpBluetooth =>
      '- Bluetooth LE (legtobb modern szamitogep)';

  @override
  String get diveComputer_list_helpBluetoothClassic =>
      '- Bluetooth Classic (regebbi modellek)';

  @override
  String get diveComputer_list_helpBrandsList =>
      'Shearwater, Suunto, Garmin, Mares, Scubapro, Oceanic, Aqualung, Cressi es 50+ tovabbi modell.';

  @override
  String get diveComputer_list_helpBrandsTitle => 'Tamogatott markak';

  @override
  String get diveComputer_list_helpConnectionsTitle => 'Tamogatott kapcsolatok';

  @override
  String get diveComputer_list_helpDialogTitle => 'Merulesszamitogep segitseg';

  @override
  String get diveComputer_list_helpDismiss => 'Rendben';

  @override
  String get diveComputer_list_helpTip1 =>
      '- Gyozodjon meg rola, hogy a szamitogep atviteli modban van';

  @override
  String get diveComputer_list_helpTip2 =>
      '- Tartsa kozel az eszkozoket letoltes kozben';

  @override
  String get diveComputer_list_helpTip3 =>
      '- Gyozodjon meg rola, hogy a Bluetooth be van kapcsolva';

  @override
  String get diveComputer_list_helpTipsTitle => 'Tippek';

  @override
  String get diveComputer_list_helpTooltip => 'Segitseg';

  @override
  String get diveComputer_list_helpUsb => '- USB (csak asztali gep)';

  @override
  String get diveComputer_list_loadFailed =>
      'Nem sikerult a merulesszamitogepek betoltese';

  @override
  String get diveComputer_list_retry => 'Ujraproba';

  @override
  String get diveComputer_list_title => 'Merulesszamitogepek';

  @override
  String get diveComputer_pinCode_instructions =>
      'Add meg a merulo szamitogepen megjelenitett kodot.';

  @override
  String get diveComputer_pinCode_label => 'PIN-kod';

  @override
  String get diveComputer_pinCode_submit => 'Kuldes';

  @override
  String get diveComputer_pinCode_title => 'PIN-kod szukseges';

  @override
  String get diveComputer_pinEntry_connectButton => 'Csatlakozas';

  @override
  String get diveComputer_pinEntry_helperText =>
      'Add meg az eszkozon megjelenitett 4-6 jegyu PIN-kodot';

  @override
  String get diveComputer_pinEntry_instructionsGeneric =>
      'Ellenorizd a merulo szamitogep kijelzojet a PIN-kodhoz.';

  @override
  String diveComputer_pinEntry_instructionsWithDevice(String deviceName) {
    return 'Ellenorizd a(z) $deviceName kijelzojet a PIN-kodhoz.';
  }

  @override
  String get diveComputer_pinEntry_semanticLabel =>
      'PIN-kod bevitel, 4-6 szamjegy';

  @override
  String get diveComputer_pinEntry_title => 'PIN-kod megadasa';

  @override
  String diveComputer_scan_bluetoothSemanticLabel(String name) {
    return 'Bluetooth eszkoz: $name';
  }

  @override
  String get diveComputer_scan_emptyStateInstructions =>
      'Gyozodj meg arrol, hogy a merulo szamitogeped:\n• Be van kapcsolva\n• Bluetooth parositasi modban van\n• Kozel van az eszkozodhoz';

  @override
  String get diveComputer_scan_knownBadge => 'Ismert';

  @override
  String get diveComputer_scan_lookingForDevicesTitle => 'Eszkozok keresese';

  @override
  String get diveComputer_scan_noUsbDevicesAvailable =>
      'Nincs elerheto USB-eszkoz';

  @override
  String get diveComputer_scan_retry => 'Ujra';

  @override
  String get diveComputer_scan_scanAgain => 'Ujra keres';

  @override
  String get diveComputer_scan_scanningStatus =>
      'Merulo szamitogepek keresese...';

  @override
  String get diveComputer_scan_stopScanning => 'Keres leallitasa';

  @override
  String get diveComputer_scan_supportedBadge => 'Tamogatott';

  @override
  String get diveComputer_scan_tabBluetooth => 'Bluetooth';

  @override
  String get diveComputer_scan_tabUsb => 'USB-kabel';

  @override
  String get diveComputer_scan_usbCableLabel => 'USB-kabel';

  @override
  String diveComputer_scan_usbSemanticLabel(String model) {
    return 'USB-eszkoz: $model';
  }

  @override
  String get diveComputer_summary_diveComputer => 'merulesszamitogep';

  @override
  String diveComputer_summary_divesDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 letoltve';
  }

  @override
  String get diveComputer_summary_done => 'Kesz';

  @override
  String get diveComputer_summary_imported => 'Importalt';

  @override
  String diveComputer_summary_semanticLabel(int count, Object name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    return '$count $_temp0 letoltve innen: $name';
  }

  @override
  String get diveComputer_summary_skippedDuplicates =>
      'Kihagyva (duplikatumok)';

  @override
  String get diveComputer_summary_title => 'Letoltes kesz!';

  @override
  String get diveComputer_summary_updated => 'Frissitve';

  @override
  String get diveComputer_summary_viewDives => 'Merulesek megtekintese';

  @override
  String get diveImport_alreadyImported => 'Mar importalva';

  @override
  String get diveImport_avgHR => 'Atl. szivfrekvencia';

  @override
  String get diveImport_back => 'Vissza';

  @override
  String get diveImport_deselectAll => 'Osszes kijeloles torlese';

  @override
  String get diveImport_divesImported => 'Merulesek importalva';

  @override
  String get diveImport_divesMerged => 'Merulesek osszefuzve';

  @override
  String get diveImport_divesSkipped => 'Merulesek kihagyva';

  @override
  String get diveImport_done => 'Kesz';

  @override
  String get diveImport_duration => 'Idotartam';

  @override
  String get diveImport_error => 'Hiba';

  @override
  String get diveImport_fit_closeTooltip => 'FIT importalas bezarasa';

  @override
  String get diveImport_fit_noDivesDescription =>
      'Valasszon ki egy vagy tobb .fit fajlt, amelyet a Garmin Connect-bol exportalt vagy Garmin Descent eszkozrol masolt.';

  @override
  String get diveImport_fit_noDivesLoaded => 'Nincsenek betoltott merulesek';

  @override
  String diveImport_fit_parsed(int diveCount, int fileCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: 'merules',
      one: 'merules',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'fajlbol',
      one: 'fajlbol',
    );
    return '$diveCount $_temp0 feldolgozva $fileCount $_temp1';
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
      other: 'merules',
      one: 'merules',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: 'fajlbol',
      one: 'fajlbol',
    );
    return '$diveCount $_temp0 feldolgozva $fileCount $_temp1 ($skippedCount kihagyva)';
  }

  @override
  String get diveImport_fit_parsing => 'Feldolgozas...';

  @override
  String get diveImport_fit_selectFiles => 'FIT fajlok kivalasztasa';

  @override
  String get diveImport_fit_title => 'Importalas FIT fajlbol';

  @override
  String get diveImport_healthkit_accessDescription =>
      'Submersion uses Apple HealthKit to read underwater diving workout data, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get diveImport_healthkit_accessRequired => 'Apple HealthKit';

  @override
  String get diveImport_healthkit_attribution =>
      'Az Apple HealthKit altal biztositva';

  @override
  String get diveImport_healthkit_closeTooltip =>
      'Apple Watch importalas bezarasa';

  @override
  String get diveImport_healthkit_dataUsage =>
      'Vizalatti meruleseket olvas az Apple Health-bol, beleertve a melyseg, idotartam, vizhomerseklet es pulzusszam adatokat. Ezek az adatok helyben tarolodnak a merulesnaplobajaban, es soha nem kerulnek megosztasra harmadik felekkel.';

  @override
  String get diveImport_healthkit_dateFrom => 'Ettol';

  @override
  String diveImport_healthkit_dateSelectorLabel(Object label) {
    return '$label datum valaszto';
  }

  @override
  String get diveImport_healthkit_dateTo => 'Eddig';

  @override
  String get diveImport_healthkit_fetchDives => 'Merulesek lekerese';

  @override
  String get diveImport_healthkit_fetching => 'Lekeres...';

  @override
  String get diveImport_healthkit_grantAccess => 'Tovább';

  @override
  String get diveImport_healthkit_noDivesFound => 'Nem talalhato merules';

  @override
  String get diveImport_healthkit_noDivesFoundDescription =>
      'A kivalasztott idoszakban nem talalhato vizalatti merulesi tevekenyse.';

  @override
  String get diveImport_healthkit_notAvailable => 'Nem elerheto';

  @override
  String get diveImport_healthkit_notAvailableDescription =>
      'Az Apple Watch importáláshoz iPhone szükséges a Health alkalmazással.';

  @override
  String get diveImport_healthkit_permissionCheckFailed =>
      'Nem sikerult az engedelyek ellenorzese';

  @override
  String get diveImport_healthkit_title => 'Importalas Apple Watch-rol';

  @override
  String get diveImport_healthkit_watchTitle => 'Importalas orarol';

  @override
  String get diveImport_import => 'Importalas';

  @override
  String get diveImport_importComplete => 'Importalas kesz';

  @override
  String get diveImport_likelyDuplicate => 'Valoszinuleg duplikatum';

  @override
  String get diveImport_maxDepth => 'Max. melyseg';

  @override
  String get diveImport_newDive => 'Uj merules';

  @override
  String get diveImport_next => 'Kovetkezo';

  @override
  String get diveImport_possibleDuplicate => 'Lehetseges duplikatum';

  @override
  String get diveImport_reviewSelectedDives =>
      'Kivalasztott merulesek attekintese';

  @override
  String diveImport_reviewSummary(
    Object newCount,
    int possibleCount,
    int skipCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      possibleCount,
      locale: localeName,
      other: ', $possibleCount lehetseges duplikatum',
      zero: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipCount,
      locale: localeName,
      other: ', $skipCount kihagyasra kerul',
      zero: '',
    );
    return '$newCount uj$_temp0$_temp1';
  }

  @override
  String get diveImport_selectAll => 'Osszes kijelolese';

  @override
  String diveImport_selectedCount(Object count) {
    return '$count kivalasztva';
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
  String get diveImport_step_done => 'Kesz';

  @override
  String get diveImport_step_review => 'Attekintes';

  @override
  String get diveImport_step_select => 'Kivalasztas';

  @override
  String get diveImport_temp => 'Hom.';

  @override
  String get diveImport_toggleDiveSelection => 'Merules kijelolesenek valtasa';

  @override
  String get diveImport_uddf_buddies => 'Buddyk';

  @override
  String get diveImport_uddf_certifications => 'Tanusitvanyok';

  @override
  String get diveImport_uddf_closeTooltip => 'UDDF importalas bezarasa';

  @override
  String get diveImport_uddf_diveCenters => 'Buvarkoezpontok';

  @override
  String get diveImport_uddf_diveTypes => 'Merulestipusok';

  @override
  String get diveImport_uddf_dives => 'Merulesek';

  @override
  String get diveImport_uddf_duplicate => 'Duplikatum';

  @override
  String diveImport_uddf_duplicatesFound(Object count) {
    return '$count duplikatum talalva es automatikusan kijeloles megszuntetve.';
  }

  @override
  String get diveImport_uddf_equipment => 'Felszereles';

  @override
  String get diveImport_uddf_equipmentSets => 'Felszerelesszettek';

  @override
  String diveImport_uddf_importProgress(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get diveImport_uddf_importing => 'Importalas...';

  @override
  String get diveImport_uddf_likelyDuplicate => 'Valoszinuleg duplikatum';

  @override
  String get diveImport_uddf_noFileDescription =>
      'Valasszon ki egy .uddf vagy .xml fajlt, amelyet masik merulesi naplo alkalmazasbol exportalt.';

  @override
  String get diveImport_uddf_noFileSelected => 'Nincs fajl kivalasztva';

  @override
  String get diveImport_uddf_parsing => 'Feldolgozas...';

  @override
  String get diveImport_uddf_possibleDuplicate => 'Lehetseges duplikatum';

  @override
  String get diveImport_uddf_selectFile => 'UDDF fajl kivalasztasa';

  @override
  String diveImport_uddf_selectedOfTotal(Object selected, Object total) {
    return '$selected / $total kivalasztva';
  }

  @override
  String get diveImport_uddf_sites => 'Helyszinek';

  @override
  String get diveImport_uddf_stepImport => 'Importalas';

  @override
  String get diveImport_uddf_tabBuddies => 'Buddyk';

  @override
  String get diveImport_uddf_tabCenters => 'Kozpontok';

  @override
  String get diveImport_uddf_tabCerts => 'Kepesitesek';

  @override
  String get diveImport_uddf_tabCourses => 'Tanfolyamok';

  @override
  String get diveImport_uddf_tabDives => 'Merulesek';

  @override
  String get diveImport_uddf_tabEquipment => 'Felszereles';

  @override
  String get diveImport_uddf_tabSets => 'Szettek';

  @override
  String get diveImport_uddf_tabSites => 'Helyszinek';

  @override
  String get diveImport_uddf_tabTags => 'Cimkek';

  @override
  String get diveImport_uddf_tabTrips => 'Utak';

  @override
  String get diveImport_uddf_tabTypes => 'Tipusok';

  @override
  String get diveImport_uddf_tags => 'Cimkek';

  @override
  String get diveImport_uddf_media => 'Fényképek';

  @override
  String get diveImport_uddf_title => 'Importalas UDDF-bol';

  @override
  String get diveImport_uddf_toggleDiveSelection =>
      'Merules kijelolesenek valtasa';

  @override
  String diveImport_uddf_toggleEntitySelection(Object name) {
    return '$name kijelolesenek valtasa';
  }

  @override
  String get diveImport_uddf_trips => 'Utak';

  @override
  String get divePlanner_segmentEditor_addTitle => 'Szegmens hozzaadasa';

  @override
  String divePlanner_segmentEditor_ascentRate(Object unit) {
    return 'Emelkedesi sebesseg ($unit/min)';
  }

  @override
  String divePlanner_segmentEditor_descentRate(Object unit) {
    return 'Süllyedesi sebesseg ($unit/min)';
  }

  @override
  String get divePlanner_segmentEditor_duration => 'Idotartam (min)';

  @override
  String get divePlanner_segmentEditor_editTitle => 'Szegmens szerkesztese';

  @override
  String divePlanner_segmentEditor_endDepth(Object unit) {
    return 'Vegmelyseg ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_gasSwitchTime => 'Gazcsere ideje';

  @override
  String get divePlanner_segmentEditor_segmentType => 'Szegmens tipusa';

  @override
  String divePlanner_segmentEditor_startDepth(Object unit) {
    return 'Kezdo melyseg ($unit)';
  }

  @override
  String get divePlanner_segmentEditor_tankGas => 'Palack / Gaz';

  @override
  String get divePlanner_segmentList_addSegment => 'Szegmens hozzaadasa';

  @override
  String divePlanner_segmentList_ascent(Object startDepth, Object endDepth) {
    return 'Emelkedes $startDepth -> $endDepth';
  }

  @override
  String divePlanner_segmentList_bottom(Object depth, Object minutes) {
    return 'Fenek $depth, $minutes min';
  }

  @override
  String divePlanner_segmentList_deco(Object depth, Object minutes) {
    return 'Deko $depth, $minutes min';
  }

  @override
  String get divePlanner_segmentList_deleteSegment => 'Szegmens torlese';

  @override
  String divePlanner_segmentList_descent(Object startDepth, Object endDepth) {
    return 'Süllyedes $startDepth -> $endDepth';
  }

  @override
  String get divePlanner_segmentList_editSegment => 'Szegmens szerkesztese';

  @override
  String get divePlanner_segmentList_emptyMessage =>
      'Adjon hozza szegmenseket kezzel, vagy hozzon letre egy gyors tervet';

  @override
  String get divePlanner_segmentList_emptyTitle => 'Meg nincsenek szegmensek';

  @override
  String divePlanner_segmentList_gasSwitch(Object gasName) {
    return 'Gazcsere erre: $gasName';
  }

  @override
  String get divePlanner_segmentList_quickPlan => 'Gyors terv';

  @override
  String divePlanner_segmentList_safetyStop(Object depth, Object minutes) {
    return 'Biztonsagi megallo $depth, $minutes min';
  }

  @override
  String get divePlanner_segmentList_title => 'Merulesi szegmensek';

  @override
  String get divePlanner_segmentType_ascent => 'Emelkedes';

  @override
  String get divePlanner_segmentType_bottomTime => 'Fenekido';

  @override
  String get divePlanner_segmentType_decoStop => 'Deko megallo';

  @override
  String get divePlanner_segmentType_descent => 'Süllyedes';

  @override
  String get divePlanner_segmentType_gasSwitch => 'Gazcsere';

  @override
  String get divePlanner_segmentType_safetyStop => 'Biztonsagi megallo';

  @override
  String get divePlanner_undo => 'Visszavonás';

  @override
  String get gasCalculators_rockBottom_aboutDescription =>
      'A Rock Bottom az a minimalis gaztartalek, ami egy veszelyes helyzetben szukseges a felszinre ereshez, mikozben levegot oszt meg a buddyjaval.\n\n- Stresszes RMV ertekeket hasznal (2-3x normalis)\n- Feltetelezi, hogy mindket merulo egy palackrol sziv\n- Tartalmazza a biztonsagi megallot, ha engedelyezve van\n\nMindig forduljon vissza, mielott eleri a Rock Bottom erteket!';

  @override
  String get gasCalculators_rockBottom_aboutTitle => 'A Rock Bottom-rol';

  @override
  String get gasCalculators_rockBottom_ascentGasRequired =>
      'Emelkedeshez szukseges gaz';

  @override
  String get gasCalculators_rockBottom_ascentRate => 'Emelkedesi sebesseg';

  @override
  String gasCalculators_rockBottom_ascentTimeToDepth(
    Object depth,
    Object unit,
  ) {
    return 'Emelkedesi ido $depth$unit-ig';
  }

  @override
  String get gasCalculators_rockBottom_ascentTimeToSurface =>
      'Emelkedesi ido a felszinig';

  @override
  String get gasCalculators_rockBottom_buddySac => 'Buddy RMV';

  @override
  String get gasCalculators_rockBottom_combinedStressedSac =>
      'Kombinalt stresszes RMV';

  @override
  String get gasCalculators_rockBottom_emergencyAscentBreakdown =>
      'Veszelyzeti emelkedes reszletei';

  @override
  String get gasCalculators_rockBottom_emergencyScenario =>
      'Veszhelyzeti szcenario';

  @override
  String get gasCalculators_rockBottom_includeSafetyStop =>
      'Biztonsagi megallo beszamitasa';

  @override
  String get gasCalculators_rockBottom_maximumDepth => 'Maximalis melyseg';

  @override
  String get gasCalculators_rockBottom_minimumReserve => 'Minimalis tartalek';

  @override
  String gasCalculators_rockBottom_resultSemantics(
    Object pressure,
    Object pressureUnit,
    Object volume,
    Object volumeUnit,
  ) {
    return 'Minimalis tartalek: $pressure $pressureUnit, $volume $volumeUnit. Forduljon vissza, ha a hatralevo gaz eleri a(z) $pressure $pressureUnit erteket';
  }

  @override
  String gasCalculators_rockBottom_safetyStopDuration(
    Object depth,
    Object unit,
  ) {
    return '3 perc $depth$unit-on';
  }

  @override
  String gasCalculators_rockBottom_safetyStopGas(Object depth, Object unit) {
    return 'Biztonsagi megallo gaz (3 perc @ $depth$unit)';
  }

  @override
  String get gasCalculators_rockBottom_stressedSacHint =>
      'Hasznaljon magasabb RMV erteket a veszhelyzeti stressz figyelembevetelere';

  @override
  String get gasCalculators_rockBottom_stressedSacRates => 'Stresszes RMV';

  @override
  String get gasCalculators_rockBottom_tankSize => 'Palack meret';

  @override
  String get gasCalculators_rockBottom_totalReserveNeeded =>
      'Osszes szukseges tartalek';

  @override
  String gasCalculators_rockBottom_turnDive(
    Object pressure,
    Object pressureUnit,
  ) {
    return 'Forduljon vissza, ha a hatralevo gaz eleri a(z) $pressure $pressureUnit erteket';
  }

  @override
  String get gasCalculators_rockBottom_yourSac => 'Sajat RMV';

  @override
  String get gpsLogger_androidNotificationText =>
      'Felszíni útvonal rögzítése folyamatban';

  @override
  String get gpsLogger_androidNotificationTitle => 'Submersion GPS-naplózó';

  @override
  String get gpsLogger_deleteTrackMessage =>
      'Törli a rögzített GPS-útvonalat. A merülésekhez már hozzárendelt pozíciók megmaradnak.';

  @override
  String get gpsLogger_deleteTrackTitle => 'Útvonal törlése?';

  @override
  String get gpsLogger_interruptedNotice =>
      'Egy korábbi rögzítés megszakadt. Az útvonal mentésre került.';

  @override
  String gpsLogger_lastFix(String age, String accuracy) {
    return 'Utolsó pozíció $age ezelőtt ($accuracy)';
  }

  @override
  String get gpsLogger_locationOff => 'A helymeghatározás ki van kapcsolva.';

  @override
  String get gpsLogger_matchButton => 'Merülések párosítása GPS-naplókkal';

  @override
  String gpsLogger_matchResult(int count) {
    return '$count merülés pozicionálva';
  }

  @override
  String get gpsLogger_matchResultNone =>
      'Egyik merülés sem illeszkedik rögzített útvonalhoz';

  @override
  String get gpsLogger_noFixYet => 'Várakozás GPS-jelre';

  @override
  String get gpsLogger_noTracks => 'Még nincs rögzített GPS-útvonal';

  @override
  String get gpsLogger_permissionDenied =>
      'GPS-útvonal rögzítéséhez helymeghatározási engedély szükséges. Engedélyezd a rendszerbeállításokban.';

  @override
  String gpsLogger_recordingStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pont',
      one: '$count pont',
    );
    return 'Rögzítés - $_temp0';
  }

  @override
  String get gpsLogger_reviewSites => 'Merülőhely-párosítások áttekintése';

  @override
  String get gpsLogger_startButton => 'Rögzítés indítása';

  @override
  String get gpsLogger_stopButton => 'Rögzítés leállítása';

  @override
  String gpsLogger_stripStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pont',
      one: '$count pont',
    );
    return 'GPS-útvonal rögzítése · $_temp0';
  }

  @override
  String get gpsLogger_summary_tracks => 'Útvonalak';

  @override
  String get gpsLogger_summary_recordedTime => 'Rögzített idő';

  @override
  String get gpsLogger_summary_divesCovered => 'Lefedett merülések';

  @override
  String gpsLogger_trackSubtitle(num count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pont',
      one: '$count pont',
    );
    return '$_temp0, $duration';
  }

  @override
  String gpsLogger_trackSubtitleTrimmed(String duration) {
    return 'Levágva, $duration';
  }

  @override
  String get gpsLogger_tracksHeader => 'Rögzített útvonalak';

  @override
  String get gpsTrack_action_trim => 'Vágás...';

  @override
  String get gpsTrack_action_split => 'Felosztás...';

  @override
  String get gpsTrack_action_resetTrim => 'Vágás visszaállítása';

  @override
  String get gpsTrack_edit_applyTrim => 'Vágás alkalmazása';

  @override
  String get gpsTrack_edit_confirmSplit => 'Felosztás itt';

  @override
  String get gpsTrack_edit_splitWarning =>
      'A felosztás két nyomvonalat hoz létre és törli az eredetit. Ezt nem lehet visszavonni.';

  @override
  String get gpsTrack_edit_cancel => 'Mégse';

  @override
  String get gpsTrack_import_action => 'Nyomvonal importálása...';

  @override
  String get gpsTrack_import_reviewTitle => 'Importálás ellenőrzése';

  @override
  String get gpsTrack_import_timezone => 'Rögzítés helye';

  @override
  String get gpsTrack_import_timezoneHint =>
      'A fájlban szereplő idők UTC szerintiek. Add meg a rögzítés időzónáját, hogy illeszkedjen a merüléseidhez.';

  @override
  String get gpsTrack_import_duplicate =>
      'Ez egy meglévő nyomvonal másolatának tűnik.';

  @override
  String get gpsTrack_import_confirm => 'Importálás';

  @override
  String get gpsTrack_import_csvMapping => 'Oszlopok megfeleltetése';

  @override
  String get gpsTrack_import_firstFix => 'Első pont';

  @override
  String gpsTrack_import_fixCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pont',
      one: '1 pont',
    );
    return '$_temp0';
  }

  @override
  String gpsTrack_import_failed(String reason) {
    return 'A fájl nem olvasható: $reason';
  }

  @override
  String get gpsTrack_importError_unsupportedFormat =>
      'Ez a fájltípus nem támogatott. Importálj GPX-, KML-, CSV- vagy FIT-fájlt.';

  @override
  String get gpsTrack_importError_unreadable =>
      'A fájl nem olvasható. Sérült vagy hiányos lehet.';

  @override
  String get gpsTrack_importError_noPositions =>
      'A fájl nem tartalmaz időbélyeggel ellátott GPS-pozíciókat.';

  @override
  String get gpsTrack_importError_badData =>
      'A fájl olyan pozíciót vagy időbélyeget tartalmaz, amelyet az alkalmazás nem tud beolvasni.';

  @override
  String get gpsTrack_export_saved => 'Nyomvonal mentve';

  @override
  String get gpsTrack_action_export => 'Exportálás';

  @override
  String get gpsTrack_action_shareGpx => 'Megosztás GPX-ként';

  @override
  String get gpsTrack_action_saveGpx => 'Mentés GPX-ként...';

  @override
  String get gpsTrack_action_shareKml => 'Megosztás KML-ként';

  @override
  String get gpsTrack_action_saveKml => 'Mentés KML-ként...';

  @override
  String get gpsTrack_export_failed => 'Az exportálás sikertelen.';

  @override
  String get gpsTrack_map_title => 'Nyomvonaltérkép';

  @override
  String gpsTrack_map_truncated(int count) {
    return 'A(z) $count legutóbbi nyomvonal látható. Szűkítsd a dátumszűrőt a többi megtekintéséhez.';
  }

  @override
  String get gpsTrack_map_noTracks =>
      'Nincs megjeleníthető rögzített nyomvonal.';

  @override
  String get gpsTrack_map_showMap => 'Térkép megjelenítése';

  @override
  String get gpsTrack_filter_all => 'Minden dátum';

  @override
  String get gpsTrack_filter_clear => 'Dátumszűrő törlése';

  @override
  String get gpsTrack_inspect_speed => 'Sebesség';

  @override
  String get gpsTrack_inspect_accuracy => 'Pontosság';

  @override
  String get gpsTrack_stats_distance => 'Távolság';

  @override
  String get gpsTrack_stats_duration => 'Időtartam';

  @override
  String get gpsTrack_stats_avgSpeed => 'Átl. sebesség';

  @override
  String get gpsTrack_stats_maxSpeed => 'Max. sebesség';

  @override
  String get gpsTrack_stats_fixes => 'Pontok';

  @override
  String get gpsTrack_stats_dives => 'Merülések';

  @override
  String get gpsTrack_colorMode_uniform => 'Egyszínű';

  @override
  String get gpsTrack_colorMode_speed => 'Sebesség';

  @override
  String get gpsTrack_colorMode_elapsed => 'Idő';

  @override
  String get gpsTrack_legend_slower => 'Lassabb';

  @override
  String get gpsTrack_legend_faster => 'Gyorsabb';

  @override
  String get gpsTrack_legend_start => 'Kezdet';

  @override
  String get gpsTrack_legend_end => 'Vég';

  @override
  String get gpsTrack_detail_title => 'GPS-nyomvonal';

  @override
  String get gpsTrack_detail_notFound => 'Ez a nyomvonal már nem érhető el.';

  @override
  String get gpsTrack_detail_unreadable => 'A nyomvonal adatai nem olvashatók.';

  @override
  String get gpsTrack_detail_noPoints =>
      'Ez a nyomvonal nem tartalmaz rögzített pozíciókat.';

  @override
  String get maps_compass_resetLabel =>
      'Terkep tajolasanak visszaallitasa eszakra';

  @override
  String get maps_compass_resetTooltip => 'Eszak felul';

  @override
  String get maps_heatMap_hide => 'Hoterkep elrejtese';

  @override
  String get maps_heatMap_overlayOff => 'A hoterkep reteg ki van kapcsolva';

  @override
  String get maps_depthOverlay_show => 'Mélységréteg megjelenítése';

  @override
  String get maps_depthOverlay_hide => 'Mélységréteg elrejtése';

  @override
  String get maps_heatMap_overlayOn => 'A hoterkep reteg be van kapcsolva';

  @override
  String get maps_heatMap_show => 'Hoterkep megjelenitese';

  @override
  String get maps_offline_bounds => 'Hatarok';

  @override
  String maps_offline_cacheHitRateAccessibility(Object rate) {
    return 'Gyorstar talalati arany: $rate szazalek';
  }

  @override
  String get maps_offline_cacheHits => 'Gyorstar talalatok';

  @override
  String get maps_offline_cacheMisses => 'Gyorstar hianyok';

  @override
  String get maps_offline_cacheStatistics => 'Gyorstar statisztikak';

  @override
  String get maps_offline_cancelDownload => 'Letoltes megszakitasa';

  @override
  String get maps_offline_clearAll => 'Osszes torlese';

  @override
  String get maps_offline_clearAllCache => 'Teljes gyorstar torlese';

  @override
  String get maps_offline_clearAllCacheMessage =>
      'Torli az osszes letoltott terkepregiit es gyorsitott csempet?';

  @override
  String get maps_offline_clearAllCacheTitle => 'Teljes gyorstar torlese?';

  @override
  String maps_offline_clearCacheStats(Object count, Object size) {
    return 'Ez $count csempet ($size) fog torolni.';
  }

  @override
  String get maps_offline_created => 'Letrehozva';

  @override
  String maps_offline_deleteRegion(Object name) {
    return '$name regio torlese';
  }

  @override
  String maps_offline_deleteRegionMessage(
    Object name,
    Object count,
    Object size,
  ) {
    return 'Torli a(z) \"$name\" regiot es a(z) $count gyorsitott csempejeet?\n\nEz $size tarolot szabadit fel.';
  }

  @override
  String get maps_offline_deleteRegionTitle => 'Regio torlese?';

  @override
  String get maps_offline_downloadNewRegion => 'Uj regio letoltese';

  @override
  String get maps_offline_downloadedRegions => 'Letoltott regiok';

  @override
  String maps_offline_downloading(Object regionName) {
    return 'Letoltes: $regionName';
  }

  @override
  String maps_offline_downloadingAccessibility(
    Object regionName,
    Object percent,
    Object downloaded,
    Object total,
  ) {
    return '$regionName letoltese, $percent szazalek kesz, $downloaded / $total csempe';
  }

  @override
  String maps_offline_error(Object error) {
    return 'Hiba: $error';
  }

  @override
  String maps_offline_errorLoadingStats(Object error) {
    return 'Hiba a statisztikak betoltesekor: $error';
  }

  @override
  String maps_offline_failedTiles(Object count) {
    return '$count sikertelen';
  }

  @override
  String maps_offline_hitRate(Object rate) {
    return 'Talalati arany: $rate%';
  }

  @override
  String get maps_offline_lastAccessed => 'Utolso hozzaferes';

  @override
  String get maps_offline_noRegions => 'Nincsenek offline regiok';

  @override
  String get maps_offline_noRegionsDescription =>
      'Toltson le terkepregiokat a helyszin reszletes oldalrol, hogy terkepeket hasznalhasson offline.';

  @override
  String get maps_offline_refresh => 'Frissites';

  @override
  String get maps_offline_region => 'Regio';

  @override
  String maps_offline_regionInfo(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size | $count csempe | Zoom $minZoom-$maxZoom';
  }

  @override
  String maps_offline_regionSubtitle(
    Object size,
    Object count,
    Object minZoom,
    Object maxZoom,
  ) {
    return '$size, $count csempe, zoom $minZoom-tol $maxZoom-ig';
  }

  @override
  String get maps_offline_size => 'Meret';

  @override
  String get maps_offline_tiles => 'Csempek';

  @override
  String maps_offline_tilesPerSecond(Object rate) {
    return '$rate csempe/mp';
  }

  @override
  String maps_offline_tilesProgress(Object downloaded, Object total) {
    return '$downloaded / $total csempe';
  }

  @override
  String get maps_offline_title => 'Offline terkepek';

  @override
  String get maps_offline_zoomRange => 'Zoom tartomany';

  @override
  String get maps_regionSelector_dragToAdjust =>
      'Huzza a kivalasztas modositasahoz';

  @override
  String get maps_regionSelector_dragToSelect =>
      'Huzza a terkepen egy regio kivalasztasahoz';

  @override
  String get maps_regionSelector_selectRegion =>
      'Regio kivalasztasa a terkepen';

  @override
  String get maps_regionSelector_selectRegionButton => 'Regio kivalasztasa';

  @override
  String get tankPresets_addPreset => 'Palacksablon hozzaadasa';

  @override
  String get tankPresets_builtInPresets => 'Beepitett sablonok';

  @override
  String get tankPresets_currentDefault => 'Jelenlegi alapértelmezett';

  @override
  String get tankPresets_customPresets => 'Egyedi sablonok';

  @override
  String get tankPresets_defaultSettings => 'Alapértelmezett palack';

  @override
  String get tankPresets_defaultSettings_description =>
      'A csillaggal jelölt sablon lesz az alapértelmezett palack új merülések naplózásakor.';

  @override
  String tankPresets_deleteDefaultMessage(String name) {
    return 'Biztosan törölni szeretnéd a(z) \"$name\" sablont? Ez a jelenlegi alapértelmezett palacksablon, és visszaáll AL80-ra.';
  }

  @override
  String tankPresets_deleteMessage(Object name) {
    return 'Biztosan torolni szeretne a(z) \"$name\" sablont?';
  }

  @override
  String get tankPresets_deletePreset => 'Sablon torlese';

  @override
  String get tankPresets_deleteTitle => 'Palacksablon torlese?';

  @override
  String tankPresets_deleted(Object name) {
    return '\"$name\" torolve';
  }

  @override
  String get tankPresets_editPreset => 'Sablon szerkesztese';

  @override
  String tankPresets_edit_created(Object name) {
    return '\"$name\" letrehozva';
  }

  @override
  String get tankPresets_edit_descriptionHint =>
      'pl. Berelt palack a buvaruzletbol';

  @override
  String get tankPresets_edit_descriptionOptional => 'Leiras (opcionalis)';

  @override
  String tankPresets_edit_errorLoading(Object error) {
    return 'Hiba a sablon betoltesekor: $error';
  }

  @override
  String tankPresets_edit_errorSaving(Object error) {
    return 'Hiba a sablon mentesekor: $error';
  }

  @override
  String tankPresets_edit_gasCapacity(Object capacity) {
    return '- Gaz kapacitas: $capacity cuft';
  }

  @override
  String get tankPresets_edit_material => 'Anyag';

  @override
  String get tankPresets_edit_name => 'Nev';

  @override
  String get tankPresets_edit_nameHelper =>
      'Baratságos nev ennek a palacksablonnak';

  @override
  String get tankPresets_edit_nameHint => 'pl. Az en AL80-am';

  @override
  String get tankPresets_edit_nameRequired => 'Kerem, adjon meg egy nevet';

  @override
  String get tankPresets_edit_ratedPressure => 'Nevleges nyomas';

  @override
  String get tankPresets_edit_required => 'Kotelezo';

  @override
  String get tankPresets_edit_tankSpecifications => 'Palack specifikaciok';

  @override
  String get tankPresets_edit_title => 'Palacksablon szerkesztese';

  @override
  String tankPresets_edit_updated(Object name) {
    return '\"$name\" frissitve';
  }

  @override
  String get tankPresets_edit_validPressure => 'Adjon meg ervenyes nyomast';

  @override
  String get tankPresets_edit_validVolume => 'Adjon meg ervenyes terfogatot';

  @override
  String get tankPresets_edit_volume => 'Terfogat';

  @override
  String get tankPresets_edit_volumeHelperCuft => 'Gaz kapacitas (cuft)';

  @override
  String get tankPresets_edit_volumeHelperLiters => 'Vizterfogat (L)';

  @override
  String tankPresets_edit_waterVolume(Object volume) {
    return '- Vizterfogat: $volume L';
  }

  @override
  String get tankPresets_edit_workingPressure => 'Üzemi nyomas';

  @override
  String tankPresets_edit_workingPressureBar(Object pressure) {
    return '- Üzemi nyomas: $pressure bar';
  }

  @override
  String tankPresets_error(Object error) {
    return 'Hiba: $error';
  }

  @override
  String tankPresets_errorDeleting(Object error) {
    return 'Hiba a sablon torlesekor: $error';
  }

  @override
  String get tankPresets_applyToImports => 'Importált merülésekre is alkalmaz';

  @override
  String get tankPresets_applyToImports_subtitle =>
      'Hiányzó palackadatok kitöltése importált merüléseknél az alapértelmezett sablon alapján';

  @override
  String get tankPresets_new_title => 'Uj palacksablon';

  @override
  String get tankPresets_noPresets => 'Nincsenek elerheto palacksablonok';

  @override
  String get tankPresets_setAsDefault => 'Beállítás alapértelmezettként';

  @override
  String get tankPresets_title => 'Palacksablonok';

  @override
  String get tools_gpsLogger_description =>
      'Rögzítsd a pozíciódat a merülőnap során, és párosítsd automatikusan az importált merüléseket GPS-helyekhez.';

  @override
  String get tools_gpsLogger_subtitle => 'Felszíni útvonal rögzítése';

  @override
  String get tools_gpsLogger_title => 'GPS-naplózó';

  @override
  String get tools_weight_aluminumImperial => 'Uresbben pozitivabb (+4 lbs)';

  @override
  String get tools_weight_aluminumMetric => 'Uresbben pozitivabb (+2 kg)';

  @override
  String get tools_weight_bodyWeightOptional => 'Testtomeg (opcionalis)';

  @override
  String get tools_weight_carbonFiberImperial => 'Nagyon pozitiv (+7 lbs)';

  @override
  String get tools_weight_carbonFiberMetric => 'Nagyon pozitiv (+3 kg)';

  @override
  String get tools_weight_disclaimer =>
      'Ez csak becsles. Mindig vegezzen felhajtoeroprobat a merules elejen, es szukseg szerint modositsa. A BCD, egyeni felhajtoeroe es legzesi szokasok befolyasolhatjak a tenyleges sulyigenyeket.';

  @override
  String get tools_weight_exposureSuit => 'Merulesi ruha';

  @override
  String tools_weight_gasCapacity(Object capacity) {
    return '- Gaz kapacitas: $capacity cuft';
  }

  @override
  String get tools_weight_helperImperial =>
      '~2 lbs hozzaadasa minden 22 lbs utan 154 lbs felett';

  @override
  String get tools_weight_helperMetric =>
      '~1 kg hozzaadasa minden 10 kg utan 70 kg felett';

  @override
  String get tools_weight_notSpecified => 'Nincs megadva';

  @override
  String get tools_weight_recommendedWeight => 'Ajanlott suly';

  @override
  String tools_weight_resultAccessibility(Object weight, Object unit) {
    return 'Ajanlott suly: $weight $unit';
  }

  @override
  String get tools_weight_steelImperial => 'Negativ felhajtoeroe (-4 lbs)';

  @override
  String get tools_weight_steelMetric => 'Negativ felhajtoeroe (-2 kg)';

  @override
  String get tools_weight_tankMaterial => 'Palack anyag';

  @override
  String get tools_weight_tankSpecifications => 'Palack specifikaciok';

  @override
  String get tools_weight_title => 'Sulyszamologep';

  @override
  String get tools_weight_waterType => 'Viz tipusa';

  @override
  String tools_weight_waterVolume(Object volume) {
    return '- Vizterfogat: $volume L';
  }

  @override
  String tools_weight_workingPressure(Object pressure) {
    return '- Üzemi nyomas: $pressure bar';
  }

  @override
  String get tools_weight_yourWeight => 'Az Ön sulya';

  @override
  String get settings_section_dataSources_title => 'Data Sources';

  @override
  String get settings_section_dataSources_subtitle =>
      'Connected services & integrations';

  @override
  String get settings_siteMatch_title => 'Automatikus helyhozzárendelés';

  @override
  String get settings_siteMatch_subtitle =>
      'Mennyire agresszíven rendelődnek a letöltött merülések a helyekhez';

  @override
  String get settings_siteMatch_strict => 'Szigorú';

  @override
  String get settings_siteMatch_balanced => 'Kiegyensúlyozott';

  @override
  String get settings_siteMatch_relaxed => 'Laza';

  @override
  String get settings_dataSources_header => 'Data Sources';

  @override
  String get settings_dataSources_appleHealth_title => 'Apple Health';

  @override
  String get settings_dataSources_appleHealth_subtitle =>
      'Vizalatti merulesi adatok';

  @override
  String get settings_dataSources_appleHealth_description =>
      'Submersion reads underwater diving workout data from Apple Health, including depth, duration, water temperature, and heart rate, to create detailed dive logs.';

  @override
  String get settings_dataSources_appleHealth_dataTypesHeader =>
      'A HealthKit-bol olvasott adatok';

  @override
  String get settings_dataSources_appleHealth_dataTypeWorkouts =>
      'Vizalatti merulesi edzeseek - merules kezdesi ideje, idotartama es tevekenysegeadatai';

  @override
  String get settings_dataSources_appleHealth_dataTypeHeartRate =>
      'Pulzusszam - merulesek soran rogzitett pulzusszam-mintak';

  @override
  String get settings_dataSources_appleHealth_permissionGranted =>
      'HealthKit hozzaferes megadva';

  @override
  String get settings_dataSources_appleHealth_permissionNotGranted =>
      'HealthKit hozzaferes nem megadva';

  @override
  String get settings_dataSources_appleHealth_permissionChecking =>
      'HealthKit hozzaferes ellenorzese...';

  @override
  String get settings_dataSources_appleHealth_importAction =>
      'Import from Apple Watch';

  @override
  String get settings_dataSources_appleHealth_privacy =>
      'Your health data is stored locally and is never shared with third parties.';

  @override
  String get settings_dataSources_appleHealth_poweredBy =>
      'Az Apple HealthKit altal biztositva';

  @override
  String get settings_dataSources_noSources =>
      'No data source integrations are available on this platform.';

  @override
  String get diveLog_edit_section_environment => 'Környezet';

  @override
  String get diveLog_edit_subsection_autofill => 'Automatikus kitöltés';

  @override
  String get diveLog_edit_subsection_weather => 'Időjárás';

  @override
  String get diveLog_edit_subsection_diveConditions => 'Merülési körülmények';

  @override
  String get diveLog_edit_label_windSpeed => 'Szélsebesség';

  @override
  String get diveLog_edit_label_windDirection => 'Szélirány';

  @override
  String get diveLog_edit_label_cloudCover => 'Felhőzet';

  @override
  String get diveLog_edit_label_precipitation => 'Csapadék';

  @override
  String get diveLog_edit_label_humidity => 'Páratartalom';

  @override
  String get diveLog_edit_label_weatherDescription => 'Időjárás leírása';

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
  String get diveLog_detail_section_environment => 'Környezet';

  @override
  String get diveLog_detail_subsection_weather => 'Időjárás';

  @override
  String get diveLog_detail_subsection_diveConditions => 'Merülési körülmények';

  @override
  String get diveLog_detail_label_windSpeed => 'Szélsebesség';

  @override
  String get diveLog_detail_label_windDirection => 'Szélirány';

  @override
  String get diveLog_detail_label_cloudCover => 'Felhőzet';

  @override
  String get diveLog_detail_label_precipitation => 'Csapadék';

  @override
  String get diveLog_detail_label_humidity => 'Páratartalom';

  @override
  String get diveLog_detail_label_weatherDescription => 'Leírás';

  @override
  String get diveLog_detail_weatherSourceOpenMeteo => 'via Open-Meteo';

  @override
  String get dropTarget_title => 'Ejtsd ide az importáláshoz';

  @override
  String get dropTarget_subtitle =>
      'Engedd el az importálási varázsló megnyitásához';

  @override
  String get dropTarget_error_unsupportedFile => 'Nem támogatott fájltípus';

  @override
  String get dropTarget_error_wizardActive =>
      'Előbb fejezd be a jelenlegi importálást';

  @override
  String get dropTarget_error_readFailed => 'A fájl nem olvasható';

  @override
  String get enum_cloudCover_clear => 'Tiszta';

  @override
  String get enum_cloudCover_partlyCloudy => 'Részben felhős';

  @override
  String get enum_cloudCover_mostlyCloudy => 'Többnyire felhős';

  @override
  String get enum_cloudCover_overcast => 'Borult';

  @override
  String get enum_precipitation_none => 'Nincs';

  @override
  String get enum_precipitation_drizzle => 'Szitálás';

  @override
  String get enum_precipitation_lightRain => 'Gyenge eső';

  @override
  String get enum_precipitation_rain => 'Eső';

  @override
  String get enum_precipitation_heavyRain => 'Erős eső';

  @override
  String get enum_precipitation_snow => 'Hó';

  @override
  String get enum_precipitation_sleet => 'Ónos eső';

  @override
  String get enum_precipitation_hail => 'Jégeső';

  @override
  String get columnConfig_title => 'Merülési lista mezői';

  @override
  String get columnConfig_viewMode => 'Nézet mód';

  @override
  String get columnConfig_visibleColumns => 'Látható oszlopok';

  @override
  String get columnConfig_availableFields => 'Elérhető mezők';

  @override
  String get columnConfig_extraFields => 'Extra mezők';

  @override
  String get columnConfig_extraFields_description =>
      'A kártya fő tartalma alatt jelenik meg';

  @override
  String get columnConfig_slotAssignments => 'Helykiosztások';

  @override
  String get columnConfig_resetToDefault => 'Visszaállítás alapértelmezettre';

  @override
  String get columnConfig_preset => 'Előbeállítás';

  @override
  String get columnConfig_presetSaveAs => 'Mentés másként';

  @override
  String get columnConfig_presetName => 'Előbeállítás neve';

  @override
  String get columnConfig_presetNameHint => 'pl. Technikai merülés';

  @override
  String get columnConfig_presetSave => 'Mentés';

  @override
  String get columnConfig_presetCancel => 'Mégse';

  @override
  String get columnConfig_columns => 'Oszlopok';

  @override
  String get columnConfig_done => 'Kész';

  @override
  String get settings_appearance_columnConfig => 'Merülési lista mezői';

  @override
  String get settings_appearance_columnConfig_subtitle =>
      'Merülési listanézetekben megjelenő mezők testreszabása';

  @override
  String get diveField_category_core => 'Alapvető';

  @override
  String get diveField_category_environment => 'Környezet';

  @override
  String get diveField_category_gas => 'Gáz';

  @override
  String get diveField_category_tank => 'Palack';

  @override
  String get diveField_category_weight => 'Súlyozás';

  @override
  String get diveField_category_equipment => 'Felszerelés';

  @override
  String get diveField_category_deco => 'Dekompresszió';

  @override
  String get diveField_category_physiology => 'Fiziológia';

  @override
  String get diveField_category_rebreather => 'Visszalégző';

  @override
  String get diveField_category_people => 'Személyek';

  @override
  String get diveField_category_location => 'Helyszín';

  @override
  String get diveField_category_trip => 'Utazás';

  @override
  String get diveField_category_rating => 'Értékelés';

  @override
  String get diveField_category_metadata => 'Metaadatok';

  @override
  String get listViewMode_table => 'Táblázat';

  @override
  String get settings_appearance_general => 'Általános';

  @override
  String get settings_appearance_sections => 'Szekciók';

  @override
  String get settings_appearance_colorAccents => 'Színes kiemelések';

  @override
  String get settings_appearance_accentNavIcons => 'Színes navigációs ikonok';

  @override
  String get settings_appearance_accentNavIcons_subtitle =>
      'A főmenü ikonjainak színezése az egyes területek színével';

  @override
  String get settings_appearance_accentSectionHeaders =>
      'Színes szekciófejlécek';

  @override
  String get settings_appearance_accentSectionHeaders_subtitle =>
      'Színes szekcióikon megjelenítése az oldalcímek mellett';

  @override
  String get settings_appearance_accentListIcons => 'Színes listaikonok';

  @override
  String get settings_appearance_accentListIcons_subtitle =>
      'Ikonok színezése a listákban és a beállítási oldalakon';

  @override
  String get settings_appearance_showDetailsPane =>
      'Részletek panel megjelenítése';

  @override
  String get settings_appearance_showDetailsPane_subtitle =>
      'Részletek panel megjelenítése a táblázat mellett';

  @override
  String get settings_appearance_showProfilePanel =>
      'Profil panel megjelenítése táblázat nézetben';

  @override
  String get settings_appearance_showProfilePanel_subtitle =>
      'Merülési profil diagram megjelenítése a táblázat felett alapértelmezetten';

  @override
  String get settings_appearance_mapStyle => 'Térképstílus';

  @override
  String get settings_appearance_mapStyle_openStreetMap => 'Utcatérkép';

  @override
  String get settings_appearance_mapStyle_openTopoMap => 'Topográfiai';

  @override
  String get settings_appearance_mapStyle_esriSatellite => 'Műhold';

  @override
  String get common_action_reparse => 'Újraelemzés';

  @override
  String get diveComputer_detail_reparseAllButton =>
      'Összes merülés újraelemzése';

  @override
  String get diveComputer_detail_reparseAllTitle =>
      'Összes merülés újraelemzése';

  @override
  String diveComputer_detail_reparseAllMessage(int count) {
    return 'A merüléselemző újrafuttatása $count merülésre, amelyekhez nyers adat tartozik. Ez frissíti a profil- és érzékelőadatokat, de megőrzi a jegyzeteket, helyszíneket, búvártársakat és egyéb szerkesztéseket.';
  }

  @override
  String diveComputer_detail_reparseAllProgress(int count) {
    return '$count merülés újraelemzése folyamatban...';
  }

  @override
  String diveComputer_detail_reparseAllSuccess(int count) {
    return '$count merülés sikeresen újraelemezve';
  }

  @override
  String diveComputer_detail_reparseAllPartial(
    int succeeded,
    int total,
    int failed,
  ) {
    return '$succeeded / $total merülés újraelemezve. $failed sikertelen.';
  }

  @override
  String diveComputer_detail_reparseRawDataCount(int count) {
    return '$count merülés nyers adattal';
  }

  @override
  String diveComputer_detail_reparseRawDataCountWithout(
    int count,
    int without,
  ) {
    return '$count merülés nyers adattal ($without anélkül)';
  }

  @override
  String get diveLog_detail_menu_reparseRawData => 'Nyers adatok újraelemzése';

  @override
  String get diveLog_detail_reparseSuccess => 'Merülés sikeresen újraelemezve';

  @override
  String get diveLog_detail_reparseProfilePreserved =>
      'A forrás adatai frissítve. Ez a merülés több merülésből lett összevonva, ezért a profilja változatlan maradt.';

  @override
  String diveLog_detail_reparseFailed(String error) {
    return 'Újraelemzés sikertelen: $error';
  }

  @override
  String get universalImport_label_replaceSource => 'Forrás cseréje';

  @override
  String get universalImport_label_replaceSourceSubtitle =>
      'Frissítés ugyanarról a számítógépről';

  @override
  String get universalImport_title_importOptions => 'Importálási beállítások';

  @override
  String get universalImport_label_options => 'Beállítások';

  @override
  String get universalImport_label_retainDiveNumbers =>
      'Eredeti merülésszámok megtartása';

  @override
  String get universalImport_label_retainDiveNumbersSubtitle =>
      'Az importált fájl merülésszámainak használata az automatikus kiosztás helyett';

  @override
  String get universalImport_title_successImported => 'Sikeresen importálva';

  @override
  String get universalImport_title_successUpdated => 'Sikeresen frissítve';

  @override
  String get universalImport_title_successConsolidated =>
      'Sikeresen összevonva';

  @override
  String get universalImport_title_noDivesImported =>
      'Nem lett merülés importálva';

  @override
  String get universalImport_label_allDivesSkipped =>
      'Minden merülés ki lett hagyva.';

  @override
  String get universalImport_label_replacedSourceData =>
      'Forrásadat lecserélve';

  @override
  String get universalImport_label_consolidated => 'Összevont';

  @override
  String get universalImport_label_photosAttached => 'Csatolt fényképek';

  @override
  String get universalImport_label_photosUnmatched =>
      'Merüléshez nem társított fényképek';

  @override
  String get common_label_shareWithAllProfiles =>
      'Megosztás az összes búvárprofillal';

  @override
  String get settings_shareByDefault_title =>
      'Új helyszínek és túrák megosztása alapértelmezetten';

  @override
  String get settings_shareAllSites_title => 'Az összes helyszínem megosztása';

  @override
  String get settings_shareAllTrips_title => 'Az összes túrám megosztása';

  @override
  String settings_shareAllSites_confirm(int count) {
    return 'Mind a(z) $count helyszínedet láthatóvá teszed minden búvárprofilnak az alkalmazásban? Később egyesével megszüntetheted a megosztást.';
  }

  @override
  String settings_shareAllTrips_confirm(int count) {
    return 'Mind a(z) $count túrádat láthatóvá teszed minden búvárprofilnak az alkalmazásban? Később egyesével megszüntetheted a megosztást.';
  }

  @override
  String settings_shareAllSites_snackbar(int count) {
    return '$count helyszín megosztva minden búvárprofillal.';
  }

  @override
  String settings_shareAllTrips_snackbar(int count) {
    return '$count túra megosztva minden búvárprofillal.';
  }

  @override
  String get settings_shareAll_noneToShare => 'Nincs mit megosztani.';

  @override
  String get settings_sharedData_sectionTitle => 'Megosztott adatok';

  @override
  String get settings_sharedData_sectionSubtitle =>
      'Helyszínek és túrák megosztása profilok között';

  @override
  String get common_action_unshare => 'Megosztás megszüntetése';

  @override
  String get trips_unshareConfirm_title => 'Megszünteted a túra megosztását?';

  @override
  String trips_unshareConfirm_body(String name) {
    return 'Ez eltávolítja a(z) „$name\" elemet a többi búvárprofil nézetéből. Később újra megoszthatod.';
  }

  @override
  String get sites_unshareConfirm_title =>
      'Megszünteted a helyszín megosztását?';

  @override
  String sites_unshareConfirm_body(String name) {
    return 'Ez eltávolítja a(z) „$name\" elemet a többi búvárprofil nézetéből. Később újra megoszthatod.';
  }

  @override
  String get trips_deleteShared_title => 'Megosztott túra törlése?';

  @override
  String trips_deleteShared_body(String name) {
    return 'A(z) „$name\" meg van osztva más búvárprofilokkal. Ha itt törlöd, mindenkinél eltávolítódik.';
  }

  @override
  String get sites_deleteShared_title => 'Megosztott helyszín törlése?';

  @override
  String sites_deleteShared_body(String name) {
    return 'A(z) „$name\" meg van osztva más búvárprofilokkal. Ha itt törlöd, mindenkinél eltávolítódik.';
  }

  @override
  String divers_delete_reassigned_snackbar(int trips, int sites, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      trips,
      locale: localeName,
      other: 'túra',
      one: 'túra',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sites,
      locale: localeName,
      other: 'helyszín',
      one: 'helyszín',
    );
    return 'Búvár törölve. $trips megosztott $_temp0 és $sites megosztott $_temp1 átrendelve ehhez: $name.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_title =>
      'Duplikált búvárprofilok';

  @override
  String get settings_cloudSync_duplicateDivers_description =>
      'A szinkronizálás több profilt talált ugyanazzal a névvel. Ez általában akkor fordul elő, amikor minden eszköz létrehozta a saját profilját a szinkronizálás előtt. Az összevonás az összes merülést és adatot egyetlen profilba helyezi át.';

  @override
  String settings_cloudSync_duplicateDivers_groupLabel(String name, int count) {
    return '$name ($count profil)';
  }

  @override
  String get settings_cloudSync_duplicateDivers_mergeButton => 'Összevon';

  @override
  String get settings_cloudSync_duplicateDivers_confirmTitle =>
      'Búvárprofilok összevonása?';

  @override
  String settings_cloudSync_duplicateDivers_confirmBody(
    int count,
    String name,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplikált profilból',
      one: 'egy duplikált profilból',
    );
    return 'Az összes merülés, tanúsítvány, felszerelés és egyéb adat $_temp0 áthelyezésre kerül ide: \"$name\". Ez nem vonható vissza automatikusan.';
  }

  @override
  String get settings_cloudSync_duplicateDivers_confirmCancel => 'Mégse';

  @override
  String get settings_cloudSync_duplicateDivers_confirmAction => 'Összevon';

  @override
  String settings_cloudSync_duplicateDivers_successSnack(String name) {
    return 'Összevonva ide: $name';
  }

  @override
  String settings_cloudSync_duplicateDivers_failureSnack(String error) {
    return 'Összevonás sikertelen: $error';
  }

  @override
  String get settings_cloudSync_duplicateDivers_undo => 'Visszavonás';

  @override
  String get divers_edit_priorExperienceSection => 'Korábbi Tapasztalat';

  @override
  String get divers_edit_priorExperienceHelp =>
      'Merülések és idő azelőttről, hogy elkezdted naplózni a Submersionben.';

  @override
  String get divers_edit_priorDivesLabel => 'Korábbi merülések';

  @override
  String get divers_edit_priorHoursLabel => 'Korábbi órák';

  @override
  String get divers_edit_priorMinutesLabel => 'Perc';

  @override
  String get divers_edit_divingSinceLabel => 'Merül azóta';

  @override
  String get divers_edit_divingSinceNotSet => 'Nincs beállítva';

  @override
  String get divers_edit_clearDivingSinceTooltip => 'Merül azóta törlése';

  @override
  String get divers_edit_priorInvalidNumber => 'Adjon meg egy érvényes számot';

  @override
  String statistics_priorBreakdown(String logged, String prior) {
    return '$logged naplózva + $prior korábbi';
  }

  @override
  String statistics_divingSince(int year) {
    return '$year óta merül';
  }

  @override
  String get db_location_choose_volume => 'Tárhely kiválasztása';

  @override
  String get db_location_internal => 'Belső tárhely';

  @override
  String get db_location_sd_card => 'SD-kártya';

  @override
  String get db_location_external_note =>
      'Az itt tárolt fájlok törlődnek, ha eltávolítja az alkalmazást.';

  @override
  String get db_location_backup_note =>
      'Az Android nem tudja az adatbázist felhőben szinkronizált mappából futtatni. Ha másolatot szeretne tartani a Dropboxban, a Nextcloudban vagy a Google Drive-on, állítsa be a Mentés helyét a Biztonsági Mentés és Visszaállítás alatt.';

  @override
  String diveLog_bulkEdit_membership_onAll(int count) {
    return 'mind a $count merülésen';
  }

  @override
  String diveLog_bulkEdit_membership_onSome(int count, int total) {
    return '$count/$total merülésen';
  }

  @override
  String diveLog_bulkEdit_membership_adding(int total) {
    return 'hozzáadás mind a $total merüléshez';
  }

  @override
  String get diveLog_bulkEdit_membership_removing => 'eltávolítás az összesből';

  @override
  String get diveLog_bulkEdit_membership_empty =>
      'Még nincsenek elemek a kiválasztott merüléseken';

  @override
  String get settings_mediaStorage_entry_title => 'Médiatárhely';

  @override
  String get settings_mediaStorage_entry_subtitle =>
      'Fotó- és videóeredetik tárolása saját felhőtárhelyen';

  @override
  String get settings_mediaStorage_status_notConfigured =>
      'Nincs médiatár csatlakoztatva ezen az eszközön';

  @override
  String settings_mediaStorage_status_connected(String hint) {
    return 'Csatlakoztatva: $hint';
  }

  @override
  String get settings_mediaStorage_test_success => 'Sikeres kapcsolat';

  @override
  String get settings_mediaStorage_saved => 'Médiatár csatlakoztatva';

  @override
  String get settings_mediaStorage_action_disconnect => 'Leválasztás';

  @override
  String get settings_mediaStorage_disconnect_confirm_title =>
      'Leválasztja a médiatárat?';

  @override
  String get settings_mediaStorage_disconnect_confirm_body =>
      'Az eszköz nem tölt fel és nem tölt le több médiát. A bucketből semmi sem törlődik.';

  @override
  String get settings_mediaStorage_action_copyFromSync =>
      'Beállítások átvétele a szinkronizálásból';

  @override
  String get settings_mediaStorage_transfers_title => 'Átvitelek';

  @override
  String get settings_mediaStorage_transfers_entry => 'Átvitelek megtekintése';

  @override
  String get settings_mediaStorage_transfers_empty => 'Nincs átvitel';

  @override
  String get settings_mediaStorage_transfers_retry => 'Újra';

  @override
  String get settings_mediaStorage_transfers_clearCompleted =>
      'Befejezettek törlése';

  @override
  String get settings_mediaStorage_transfers_state_pending => 'Várakozik';

  @override
  String get settings_mediaStorage_transfers_state_transferring => 'Feltöltés';

  @override
  String get settings_mediaStorage_transfers_state_deleting =>
      'Eltávolítás a felhőből';

  @override
  String get settings_mediaStorage_transfers_state_done => 'Kész';

  @override
  String get settings_mediaStorage_transfers_state_failed => 'Sikertelen';

  @override
  String settings_mediaStorage_transfers_queued(int count) {
    return '$count sorban áll';
  }

  @override
  String settings_mediaStorage_transfers_waitingRetry(int count) {
    return '$count újrapróbálkozásra vár';
  }

  @override
  String get settings_mediaStorage_verify_action => 'Könyvtár ellenőrzése';

  @override
  String get settings_mediaStorage_verify_running => 'Médiatár ellenőrzése...';

  @override
  String settings_mediaStorage_verify_summary(
    int checked,
    int removed,
    int repaired,
    int aborted,
  ) {
    return '$checked objektum ellenőrizve: $removed árva eltávolítva, $repaired javítás sorba állítva, $aborted elavult feltöltés megszakítva';
  }

  @override
  String get settings_mediaStorage_backfill_action =>
      'Meglévő könyvtár feltöltése';

  @override
  String settings_mediaStorage_backfill_enqueued(int count) {
    return '$count feltöltés sorban';
  }

  @override
  String get settings_mediaStorage_policy_autoUpload =>
      'Fotók automatikus feltöltése';

  @override
  String get settings_mediaStorage_policy_photosOnCellular =>
      'Fotók feltöltése mobilhálózaton';

  @override
  String get settings_mediaStorage_provider_label => 'Szolgáltató';

  @override
  String get settings_mediaStorage_connect_dropbox_hint =>
      'A felhőszinkronizálás Dropbox-kapcsolatát használja. A média a Dropbox alkalmazásmappájában tárolódik.';

  @override
  String get settings_mediaStorage_connect_gdrive_hint =>
      'Google-fiókkal jelentkezik be. A média az alkalmazás privát Drive-területén tárolódik.';

  @override
  String get settings_mediaStorage_connect_icloud_hint =>
      'A média az alkalmazás iCloud-tárolójában tárolódik, és az Apple ID-n keresztül szinkronizálódik.';

  @override
  String settings_mediaStorage_connect_action(String provider) {
    return '$provider csatlakoztatása';
  }

  @override
  String get bodyWeight_addEntry => 'Mérés hozzáadása';

  @override
  String get bodyWeight_dateLabel => 'Dátum';

  @override
  String get bodyWeight_deleteTooltip => 'Bejegyzés törlése';

  @override
  String get bodyWeight_heightLabel => 'Magasság (cm)';

  @override
  String get bodyWeight_heightFeetLabel => 'Magasság (ft)';

  @override
  String get bodyWeight_heightInchesLabel => 'Hüvelyk';

  @override
  String bodyWeight_weightLabel(String unit) {
    return 'Testsúly ($unit)';
  }

  @override
  String diveLog_edit_weightFeedback_amount(String unit) {
    return 'Körülbelül mennyivel ($unit)';
  }

  @override
  String get diveLog_edit_weightFeedback_correct => 'Megfelelő volt';

  @override
  String get diveLog_edit_weightFeedback_label => 'Milyen volt a súlyozásod?';

  @override
  String get diveLog_edit_weightFeedback_over => 'Túlsúlyozott';

  @override
  String get diveLog_edit_weightFeedback_under => 'Alulsúlyozott';

  @override
  String get diverProfile_bodyWeight_empty => 'Nincs rögzítve';

  @override
  String get diverProfile_bodyWeight_title => 'Testsúly';

  @override
  String get equipment_edit_advanced_title => 'Speciális';

  @override
  String get equipment_edit_buoyancyHint_exposure =>
      'Pozitív: mennyire úszik fel';

  @override
  String get equipment_edit_buoyancyHint_generic => 'Negatív, ha süllyed';

  @override
  String get equipment_edit_buoyancyHint_tank =>
      'Hagyd üresen - a palackok saját adataikat használják';

  @override
  String equipment_edit_buoyancyLabel(String unit) {
    return 'Felhajtóerő ($unit)';
  }

  @override
  String equipment_edit_dryWeightLabel(String unit) {
    return 'Száraz tömeg ($unit)';
  }

  @override
  String equipment_edit_liftCapacityLabel(String unit) {
    return 'Emelőkapacitás ($unit)';
  }

  @override
  String get equipment_edit_liftCapacityHint =>
      'A szárny vagy BCD névleges felhajtóereje';

  @override
  String get planner_gearWeights_accept => 'Használat tervezett súlyként';

  @override
  String get planner_gearWeights_addGear => 'Felszerelés hozzáadása';

  @override
  String get planner_gearWeights_empty =>
      'Adj hozzá felszerelést a súlyozás előrejelzéséhez';

  @override
  String planner_gearWeights_planned(String weight) {
    return 'Tervezett: $weight';
  }

  @override
  String planner_gearWeights_predicted(String weight) {
    return 'Előrejelzett: $weight';
  }

  @override
  String get planner_gearWeights_title => 'Felszerelés és súlyok';

  @override
  String get planner_gearWeights_useSet => 'Készlet használata';

  @override
  String get tools_weight_addGear => 'Felszerelés hozzáadása';

  @override
  String get tools_weight_addTank => 'Palack hozzáadása';

  @override
  String tools_weight_basedOnDives(int count) {
    return '$count naplózott merülés alapján';
  }

  @override
  String get tools_weight_breakdownTitle => 'Hogyan számoltuk ki';

  @override
  String get tools_weight_confidence_high => 'Nagy megbízhatóság';

  @override
  String get tools_weight_confidence_low => 'Alacsony megbízhatóság - becslés';

  @override
  String get tools_weight_confidence_medium => 'Közepes megbízhatóság';

  @override
  String tools_weight_deltaVsPrevious(String delta) {
    return '$delta az előző felszereléshez képest';
  }

  @override
  String get tools_weight_noGear =>
      'Add hozzá a merüléshez tervezett felszerelést az előrejelzés személyre szabásához.';

  @override
  String get tools_weight_personalTerm => 'Személyes alap';

  @override
  String get tools_weight_placementTitle => 'Javasolt elosztás';

  @override
  String get tools_weight_predictedWeight => 'Előrejelzett súly';

  @override
  String get tools_weight_saveToProfile => 'Súly mentése a profilba';

  @override
  String get tools_weight_source_measured => 'a merüléseidből mérve';

  @override
  String get tools_weight_source_physics => 'fizika';

  @override
  String get tools_weight_source_typeDefault => 'alapértelmezett becslés';

  @override
  String get tools_weight_source_userSpec => 'a felszerelésed adataiból';

  @override
  String get tools_weight_tanks => 'Palackok';

  @override
  String get tools_weight_useSet => 'Készlet használata';

  @override
  String get tools_weight_waterTerm => 'Víztípus';

  @override
  String get dive3d_previewTitle => '3D nézet';

  @override
  String get dive3d_previewHint => 'Koppints a 3D felfedezéshez';

  @override
  String get dive3d_resetView => 'Nézet visszaállítása';

  @override
  String get dive3d_zoomIn => 'Nagyítás';

  @override
  String get dive3d_zoomOut => 'Kicsinyítés';

  @override
  String get dive3d_play => 'Lejátszás';

  @override
  String get dive3d_pause => 'Szünet';

  @override
  String get dive3d_overlays => 'Rétegek';

  @override
  String get dive3d_overlay_strata => 'Hőmérsékleti rétegek';

  @override
  String get dive3d_overlay_ceiling => 'Dekó plafon';

  @override
  String get dive3d_overlay_curtain => 'Mélységi függöny';

  @override
  String get dive3d_overlay_markers => 'Jelölők';

  @override
  String get dive3d_seascape_overlay_paths => 'Merülési útvonalak';

  @override
  String get dive3d_seascape_overlay_contours => 'Mélységvonalak';

  @override
  String get dive3d_seascape_overlay_walls => 'Meredek falak';

  @override
  String get dive3d_overlay_water => 'Vízfelszín';

  @override
  String get dive3d_seascape_legend_land => 'Szárazföld';

  @override
  String get dive3d_seascape_appearance => 'Terep megjelenése';

  @override
  String get dive3d_seascape_chartView => 'Térképnézet';

  @override
  String get dive3d_seascape_orbitView => '3D nézet';

  @override
  String get dive3d_seascape_appearance_surface => 'Terepfelszín';

  @override
  String get dive3d_seascape_appearance_surfaceDepth => 'Mélységszínek';

  @override
  String get dive3d_seascape_appearance_surfaceImagery => 'Térképi felvétel';

  @override
  String get dive3d_seascape_appearance_surfaceBlend => 'Keverék';

  @override
  String get siteFeature_type_wreck => 'Roncs';

  @override
  String get siteFeature_type_mooring => 'Kikötőbója';

  @override
  String get siteFeature_type_entry => 'Beszállási pont';

  @override
  String get siteFeature_type_exit => 'Kiszállási pont';

  @override
  String get siteFeature_type_swimThrough => 'Átúszó';

  @override
  String get siteFeature_type_hazard => 'Veszély';

  @override
  String get siteFeature_type_current => 'Áramlás';

  @override
  String get siteFeature_sectionTitle => 'Jellemzők';

  @override
  String get siteFeature_addAction => 'Jellemző hozzáadása';

  @override
  String get siteFeature_placeHint =>
      'Koppintson a térképre a jellemző elhelyezéséhez';

  @override
  String get siteFeature_addTitle => 'Jellemző hozzáadása';

  @override
  String get siteFeature_editTitle => 'Jellemző szerkesztése';

  @override
  String get siteFeature_field_name => 'Név';

  @override
  String get siteFeature_field_bearing => 'Irány (°)';

  @override
  String get siteFeature_field_depth => 'Mélység';

  @override
  String get siteFeature_field_notes => 'Jegyzetek';

  @override
  String get siteFeature_deleteAction => 'Törlés';

  @override
  String siteFeature_deleteConfirm(String name) {
    return 'Törli: $name?';
  }

  @override
  String get siteScape_mode2d => 'Térkép';

  @override
  String get siteScape_mode3d => '3D';

  @override
  String get dive3d_seascape_appearance_rampRange =>
      'Színmélység-tartomány korlátozása';

  @override
  String get dive3d_seascape_appearance_rampMax => 'Legsötétebb szín ennél';

  @override
  String get dive3d_seascape_appearance_banded => 'Sávos színátmenet';

  @override
  String get dive3d_seascape_appearance_contours => 'Mélységvonal-szintek';

  @override
  String get dive3d_seascape_appearance_contourAuto => 'Automatikus';

  @override
  String get dive3d_seascape_appearance_contourCustom => 'Egyéni';

  @override
  String get dive3d_seascape_appearance_addLevel => 'Szint hozzáadása';

  @override
  String get dive3d_seascape_appearance_defaultColor => 'Alapértelmezett';

  @override
  String get dive3d_seascape_appearance_wallAngle => 'Meredek fal szöge';

  @override
  String get dive3d_seascape_appearance_wallAngleNote =>
      'A batimetriai cellák átlagolják a bennük lévő lejtést, így a valódi falak laposabbnak tűnnek. Maradjon jóval 45 fok alatt.';

  @override
  String get dive3d_seascape_siteTitle => 'Helyszíni tengertáj';

  @override
  String dive3d_seascape_seafloorSource(String source, String resolution) {
    return 'Tengerfenék: $source (~$resolution m)';
  }

  @override
  String get dive3d_seascape_noCoordinates =>
      'Ennek a helyszínnek nincsenek GPS-koordinátái';

  @override
  String get dive3d_seascape_noData =>
      'Ehhez a helyhez nem érhető el batimetria';

  @override
  String dive3d_seascape_axis_distance(String unitSymbol) {
    return 'Távolság ($unitSymbol)';
  }

  @override
  String get settings_about_bathymetryCredit =>
      'Batimetriai adatok: GMRT (CC BY 4.0) · EMODnet Bathymetry (CC BY 4.0) · NOAA ETOPO 2022';

  @override
  String get dive3d_metric_depth => 'Mélység';

  @override
  String get dive3d_metric_temperature => 'Hőm';

  @override
  String get dive3d_metric_ascentRate => 'Emelkedés';

  @override
  String get dive3d_metric_ppO2 => 'ppO2';

  @override
  String get dive3d_metric_cns => 'CNS';

  @override
  String get dive3d_metric_heartRate => 'Pulzus';

  @override
  String get dive3d_metric_tankPressure => 'Nyomás';

  @override
  String get dive3d_zAxis => 'Z tengely';

  @override
  String get dive3d_zAxis_none => 'Nincs';

  @override
  String get dive3d_overlay_shadows => 'Falárnyékok';

  @override
  String get dive3d_metric_tts => 'TTS';

  @override
  String dive3d_axis_depth(String unitSymbol) {
    return 'Mélység ($unitSymbol)';
  }

  @override
  String get dive3d_axis_time => 'Merülési idő (perc)';

  @override
  String get dive3d_pose_menu => 'Kamera';

  @override
  String get dive3d_pose_default => 'Alapnézet';

  @override
  String get dive3d_pose_front => 'Elölnézet (mélység / idő)';

  @override
  String get dive3d_pose_side => 'Oldalnézet (mélység / mérőszám)';

  @override
  String get dive3d_pose_top => 'Felülnézet (mérőszám / idő)';

  @override
  String get dive3d_readout_runTime => 'Merülési idő';

  @override
  String get dive3d_readout_ceiling => 'Plafon';

  @override
  String dive3d_readout_tank(int n) {
    return 'Palack $n';
  }

  @override
  String get dive3d_scene_dive => 'Merülés';

  @override
  String get dive3d_scene_tissue => 'Szövetek';

  @override
  String get dive3d_tissue_gasCombined => 'Együtt';

  @override
  String get dive3d_tissue_gasN2 => 'N2';

  @override
  String get dive3d_tissue_gasHe => 'He';

  @override
  String get dive3d_tissue_colorMValue => '% M-érték';

  @override
  String get dive3d_tissue_colorAbsolute => 'Telítettség';

  @override
  String get dive3d_tissue_controlling => 'Vezérlő';

  @override
  String get dive3d_tissue_surfaceInterval => 'Felszíni szünet';

  @override
  String get dive3d_career_title => '3D előzmények';

  @override
  String get dive3d_career_colorRecency => 'Frissesség';

  @override
  String get dive3d_career_colorDepth => 'Mélység';

  @override
  String get dive3d_career_empty => 'Nincs profillal rendelkező merülés';

  @override
  String get dive3d_spatial_title => '3D tengeri táj';

  @override
  String get dive3d_spatial_estimatedPath => 'Becsült útvonal (holtszámítás)';

  @override
  String get dive3d_spatial_synthesizedSeafloor => 'Szintetizált tengerfenék';

  @override
  String get dive3d_spatial_noPath =>
      'Nincs elég adat az útvonal rekonstruálásához';

  @override
  String get dive3d_tissue_legendHeight =>
      'Magasság és szín: az M-érték határának %-a';

  @override
  String get dive3d_tissue_legendLimit => 'Piros sík = dekó határ';

  @override
  String get dive3d_tissue_legendAxes =>
      'Balra→jobbra: idő · Elöl→hátul: gyors→lassú szövetek';

  @override
  String get dive3d_tissue_legendDepth => 'Kék görbe: a mélységed';

  @override
  String get dive3d_tissue_onGassing => 'Feltöltődés';

  @override
  String get dive3d_tissue_offGassing => 'Leürülés';

  @override
  String dive3d_tissue_tooltipCompartment(int number) {
    return '$number. komp.';
  }

  @override
  String dive3d_tissue_tooltipHalfTime(int minutes) {
    return '$minutes perc N2';
  }

  @override
  String dive3d_tissue_tooltipSaturation(int percent) {
    return 'Telítettség $percent%';
  }

  @override
  String dive3d_tissue_tooltipProgress(int percent) {
    return 'A merülés $percent%-a';
  }

  @override
  String get dive3d_tissue_stateEquilibrium => 'Egyensúly';

  @override
  String get dive3d_tissue_statePastMValue => 'M-érték felett';

  @override
  String get dive3d_tissue_axisTime => 'Idő';

  @override
  String get dive3d_tissue_axisSaturation => 'Telítettség %';

  @override
  String get dive3d_tissue_axisCompartment => 'Kompartiment';

  @override
  String get dive3d_compare_computers_title => 'Számítógépek összehasonlítása';

  @override
  String get dive3d_compare_dives_title => 'Merülések összehasonlítása';

  @override
  String get dive3d_scene_computers => 'Számítógépek';

  @override
  String get dive3d_compare_layout_sideBySide => 'Egymás mellett';

  @override
  String get dive3d_compare_layout_overlay => 'Egymásra helyezve';

  @override
  String get dive3d_compare_empty =>
      'Az összehasonlításhoz legalább 2, mélységadatokkal rendelkező profil szükséges';

  @override
  String dive3d_compare_showing(Object shown, Object total) {
    return 'Megjelenítve: $shown / $total';
  }

  @override
  String get dive3d_compare_setReference => 'Beállítás referenciaként';

  @override
  String get diveLog_selection_tooltip_compare3d => 'Összehasonlítás 3D-ben';

  @override
  String get diveLog_sources_compareIn3d => 'Összehasonlítás 3D-ben';

  @override
  String get settings_setup_pendingTitle => 'Fejezze be az eszköz beállítását';

  @override
  String settings_setup_mediaStoreAttach(String hint) {
    return 'Médiatároló csatlakoztatása ($hint)';
  }

  @override
  String settings_setup_accountSignIn(String label) {
    return 'Bejelentkezés: $label';
  }

  @override
  String get settings_setup_dismiss => 'Elvetés';

  @override
  String get settings_photosMedia_title => 'Fotók és média';

  @override
  String get settings_photosMedia_subtitle => 'Források, tárolás és fiókok';

  @override
  String get settings_photosMedia_sourcesHeader => 'Honnan érkeznek a fotók';

  @override
  String get settings_photosMedia_storageHeader => 'Hol tároljuk a másolatokat';

  @override
  String get settings_photosMedia_accountsHeader => 'Fiókok';

  @override
  String get settings_photosMedia_displayHeader => 'Megjelenítés';

  @override
  String get settings_photosMedia_guidedSetup => 'Vezetett beállítás';

  @override
  String get settings_photosMedia_photoSources_title => 'Fotótár és források';

  @override
  String get settings_photosMedia_photoSources_subtitle =>
      'Galéria, fájlok és importálási beállítások';

  @override
  String get settings_photosMedia_networkSources_title => 'Hálózati források';

  @override
  String get settings_photosMedia_networkSources_subtitle =>
      'URL-ek és manifeszt-hírcsatornák (haladó)';

  @override
  String get settings_connectedAccounts_title => 'Csatlakoztatott fiókok';

  @override
  String get settings_connectedAccounts_subtitle =>
      'Felhő- és szolgáltatásfiókok';

  @override
  String get settings_connectedAccounts_empty =>
      'Még nincs csatlakoztatott fiók';

  @override
  String get settings_connectedAccounts_status_signedIn => 'Bejelentkezve';

  @override
  String get settings_connectedAccounts_status_needsSignIn =>
      'Bejelentkezés szükséges';

  @override
  String get settings_connectedAccounts_status_unavailable =>
      'Ezen az eszközön nem érhető el';

  @override
  String get settings_connectedAccounts_disconnectDevice =>
      'Kijelentkezés ezen az eszközön';

  @override
  String get settings_connectedAccounts_removeFromLibrary =>
      'Eltávolítás a könyvtárból';

  @override
  String get settings_connectedAccounts_removeConfirmTitle =>
      'Eltávolítja a fiókot?';

  @override
  String get settings_connectedAccounts_removeConfirmBody =>
      'A fiók minden szinkronizált eszközről eltávolításra kerül. A más eszközökön tárolt hitelesítő adatok nem törlődnek.';

  @override
  String get settings_setupGuide_title => 'Fotók és média beállítása';

  @override
  String get settings_setupGuide_intro =>
      'Kapcsold össze, honnan érkeznek a fotóid és hol tárolod a másolatokat. Bármikor újrafuttathatod.';

  @override
  String get settings_setupGuide_stepSources => 'Fotóforrások';

  @override
  String get settings_setupGuide_stepSources_desc =>
      'Csatolj fotókat a fotótáradból, fájlokból vagy a Lightroomból.';

  @override
  String get settings_setupGuide_stepStorage => 'Médiatároló';

  @override
  String get settings_setupGuide_stepStorage_desc =>
      'Tárold fotóid másolatait a saját felhődben, hogy minden eszköz megjeleníthesse őket.';

  @override
  String get settings_setupGuide_stepSync => 'Felhőszinkronizálás';

  @override
  String get settings_setupGuide_stepSync_desc =>
      'Merülési adatok szinkronizálása eszközök között.';

  @override
  String get settings_setupGuide_statusDone => 'Beállítva';

  @override
  String get settings_setupGuide_statusTodo => 'Nincs beállítva';

  @override
  String get settings_setupGuide_open => 'Megnyitás';

  @override
  String get settings_connectedAccounts_loadError =>
      'A fiókok nem tölthetők be';

  @override
  String get media_unavailablePlaceholder_volumeOffline =>
      'A kötet nincs csatlakoztatva';

  @override
  String get media_unavailablePlaceholder_stillFetching =>
      'Még töltődik. Koppintson az újrapróbálkozáshoz.';

  @override
  String get media_unavailablePlaceholder_accessDenied =>
      'Nincs hozzáférés a fotókönyvtárhoz';

  @override
  String get attrLabel_size => 'Méret';

  @override
  String get attrLabel_thickness_mm => 'Vastagság (mm)';

  @override
  String get attrLabel_suit_style => 'Ruha fazonja';

  @override
  String get attrLabel_shell_material => 'Külső anyag';

  @override
  String get attrLabel_seal_type => 'Mandzsetta típusa';

  @override
  String get attrLabel_volume_l => 'Térfogat';

  @override
  String get attrLabel_working_pressure_bar => 'Üzemi nyomás';

  @override
  String get attrLabel_tank_material => 'Anyag';

  @override
  String get attrLabel_valve_type => 'Szelep';

  @override
  String get attrLabel_tank_identifier => 'Azonosító';

  @override
  String get attrLabel_last_visual_inspection => 'Utolsó szemrevételezés';

  @override
  String get attrLabel_last_hydro_test => 'Utolsó hidrosztatikai vizsgálat';

  @override
  String get attrLabel_connection => 'Csatlakozás';

  @override
  String get attrLabel_cold_water_rated => 'Hidegvízre minősített';

  @override
  String get attrLabel_bcd_style => 'Fazon';

  @override
  String get attrLabel_lift_capacity_kg => 'Emelőkapacitás';

  @override
  String get attrLabel_heel_type => 'Sarok';

  @override
  String get attrLabel_blade_style => 'Lapát';

  @override
  String get attrLabel_mount => 'Rögzítés';

  @override
  String get attrLabel_connectivity => 'Kapcsolat';

  @override
  String get attrLabel_lens_config => 'Lencse';

  @override
  String get attrLabel_prescription => 'Dioptriás lencsék';

  @override
  String get attrLabel_weight_style => 'Fazon';

  @override
  String get attrLabel_lumens => 'Lumen';

  @override
  String get attrLabel_beam_type => 'Fénysugár';

  @override
  String get attrLabel_depth_rating_m => 'Mélységi besorolás';

  @override
  String get attrLabel_smb_type => 'Típus';

  @override
  String get attrLabel_length_m => 'Hossz';

  @override
  String get attrLabel_reel_type => 'Típus';

  @override
  String get attrLabel_line_length_m => 'Zsinór hossza';

  @override
  String get attrLabel_blade_material => 'Penge anyaga';

  @override
  String get attrLabel_tip_type => 'Hegy';

  @override
  String get attrLabel_glove_type => 'Típus';

  @override
  String get attrLabel_sole_type => 'Talp';

  @override
  String get attrLabel_buoyancy_kg => 'Felhajtóerő';

  @override
  String get attrLabel_dry_weight_kg => 'Száraz tömeg';

  @override
  String get attrLabel_unit_type => 'Készülék típusa';

  @override
  String get attrLabel_mount_configuration => 'Rögzítés';

  @override
  String get attrLabel_scrubber_type => 'Abszorber típusa';

  @override
  String get attrLabel_scrubber_duration_h => 'Abszorber élettartama (ó)';

  @override
  String get attrLabel_o2_cell_count => 'O2-cellák';

  @override
  String get attrLabel_diluent_cylinder_l => 'Diluent palack';

  @override
  String get attrLabel_o2_cylinder_l => 'O2 palack';

  @override
  String get attrLabel_dpv_style => 'Fazon';

  @override
  String get attrLabel_burn_time_h => 'Üzemidő';

  @override
  String get attrLabel_battery_type => 'Akkumulátor';

  @override
  String get attrLabel_battery_capacity_wh => 'Akkukapacitás (Wh)';

  @override
  String get attrLabel_motor_type => 'Motor';

  @override
  String get attrLabel_speed_mps => 'Végsebesség';

  @override
  String get attrChoice_unit_type_eccr => 'Elektronikus CCR (eCCR)';

  @override
  String get attrChoice_unit_type_mccr => 'Manuális CCR (mCCR)';

  @override
  String get attrChoice_unit_type_hccr => 'Hibrid CCR (hCCR)';

  @override
  String get attrChoice_unit_type_scr_cmf => 'SCR - állandó tömegáram';

  @override
  String get attrChoice_unit_type_scr_pascr => 'SCR - passzív adagolás';

  @override
  String get attrChoice_unit_type_scr_escr => 'SCR - elektronikus szabályozás';

  @override
  String get attrChoice_mount_configuration_back => 'Háti rögzítés';

  @override
  String get attrChoice_mount_configuration_chest => 'Mellkasi rögzítés';

  @override
  String get attrChoice_mount_configuration_sidemount => 'Oldalra szerelt';

  @override
  String get attrChoice_scrubber_type_axial => 'Axiális';

  @override
  String get attrChoice_scrubber_type_radial => 'Radiális';

  @override
  String get attrChoice_suit_style_full => 'Egész ruha';

  @override
  String get attrChoice_suit_style_shorty => 'Shorty';

  @override
  String get attrChoice_suit_style_two_piece => 'Kétrészes';

  @override
  String get attrChoice_suit_style_semi_dry => 'Félszáraz';

  @override
  String get attrChoice_shell_material_trilaminate => 'Trilaminát';

  @override
  String get attrChoice_shell_material_neoprene => 'Neoprén';

  @override
  String get attrChoice_shell_material_crushed_neoprene => 'Préselt neoprén';

  @override
  String get attrChoice_shell_material_vulcanized_rubber => 'Vulkanizált gumi';

  @override
  String get attrChoice_seal_type_latex => 'Latex';

  @override
  String get attrChoice_seal_type_silicone => 'Szilikon';

  @override
  String get attrChoice_seal_type_neoprene => 'Neoprén';

  @override
  String get attrChoice_tank_material_aluminum => 'Alumínium';

  @override
  String get attrChoice_tank_material_steel => 'Acél';

  @override
  String get attrChoice_tank_material_carbon_composite => 'Karbon kompozit';

  @override
  String get attrChoice_valve_type_din => 'DIN';

  @override
  String get attrChoice_valve_type_yoke => 'Kengyel (INT)';

  @override
  String get attrChoice_valve_type_convertible => 'Átalakítható';

  @override
  String get attrChoice_connection_din => 'DIN';

  @override
  String get attrChoice_connection_yoke => 'Kengyel (INT)';

  @override
  String get attrChoice_bcd_style_jacket => 'Mellény';

  @override
  String get attrChoice_bcd_style_back_inflate => 'Háti kamrás';

  @override
  String get attrChoice_bcd_style_wing => 'Wing';

  @override
  String get attrChoice_bcd_style_sidemount => 'Sidemount';

  @override
  String get attrChoice_heel_type_open_heel => 'Nyitott sarkú';

  @override
  String get attrChoice_heel_type_full_foot => 'Zárt sarkú';

  @override
  String get attrChoice_blade_style_paddle => 'Lapátos';

  @override
  String get attrChoice_blade_style_split => 'Osztott';

  @override
  String get attrChoice_blade_style_vented => 'Szellőzős';

  @override
  String get attrChoice_mount_wrist => 'Csukló';

  @override
  String get attrChoice_mount_console => 'Konzol';

  @override
  String get attrChoice_mount_hud => 'HUD';

  @override
  String get attrChoice_connectivity_ble => 'Bluetooth (BLE)';

  @override
  String get attrChoice_connectivity_usb => 'USB';

  @override
  String get attrChoice_connectivity_infrared => 'Infravörös';

  @override
  String get attrChoice_connectivity_none => 'Nincs';

  @override
  String get attrChoice_lens_config_single => 'Egylencsés';

  @override
  String get attrChoice_lens_config_twin => 'Kétlencsés';

  @override
  String get attrChoice_lens_config_frameless => 'Keret nélküli';

  @override
  String get attrChoice_weight_style_belt => 'Öv';

  @override
  String get attrChoice_weight_style_integrated => 'Integrált';

  @override
  String get attrChoice_weight_style_trim => 'Trimm';

  @override
  String get attrChoice_weight_style_ankle => 'Boka';

  @override
  String get attrChoice_beam_type_spot => 'Pont';

  @override
  String get attrChoice_beam_type_flood => 'Széles';

  @override
  String get attrChoice_beam_type_adjustable => 'Állítható';

  @override
  String get attrChoice_smb_type_open => 'Nyitott';

  @override
  String get attrChoice_smb_type_closed => 'Zárt';

  @override
  String get attrChoice_reel_type_spool => 'Orsó';

  @override
  String get attrChoice_reel_type_ratchet => 'Racsnis';

  @override
  String get attrChoice_blade_material_stainless => 'Rozsdamentes acél';

  @override
  String get attrChoice_blade_material_titanium => 'Titán';

  @override
  String get attrChoice_tip_type_pointed => 'Hegyes';

  @override
  String get attrChoice_tip_type_blunt => 'Tompa';

  @override
  String get attrChoice_tip_type_line_cutter => 'Zsinórvágó';

  @override
  String get attrChoice_glove_type_five_finger => 'Ötujjas';

  @override
  String get attrChoice_glove_type_mitt => 'Egyujjas';

  @override
  String get attrChoice_glove_type_dry => 'Száraz';

  @override
  String get attrChoice_sole_type_hard => 'Kemény talp';

  @override
  String get attrChoice_sole_type_soft => 'Puha talp';

  @override
  String get attrChoice_dpv_style_tow_behind => 'Vontatott';

  @override
  String get attrChoice_dpv_style_ride_on => 'Ráülős';

  @override
  String get attrChoice_dpv_style_handheld => 'Kézi';

  @override
  String get attrChoice_battery_type_lithium_ion => 'Lítium-ion';

  @override
  String get attrChoice_battery_type_nimh => 'NiMH';

  @override
  String get attrChoice_battery_type_lead_acid => 'Ólom-savas';

  @override
  String get attrChoice_motor_type_brushless => 'Szénkefe nélküli';

  @override
  String get attrChoice_motor_type_brushed => 'Szénkefés';

  @override
  String get equipment_edit_customFieldsTitle => 'Egyéni mezők';

  @override
  String get equipment_edit_addCustomField => 'Egyéni mező hozzáadása';

  @override
  String get attr_flagYes => 'Igen';

  @override
  String get attr_flagNo => 'Nem';

  @override
  String get equipment_edit_invalidThickness => 'Formátum: 5, 5/4 vagy 7/5/3';

  @override
  String get statistics_progression_divesBySuitThickness_title =>
      'Merülések ruhavastagság szerint';

  @override
  String get statistics_progression_divesBySuitThickness_subtitle =>
      'A ruha fő vastagsága a merüléseid során';

  @override
  String get statistics_progression_divesBySuitThickness_empty =>
      'Nincs merülés rögzített ruhavastagsággal';

  @override
  String get statistics_progression_divesBySuitThickness_error =>
      'Nem sikerült betölteni a vastagsági adatokat';

  @override
  String get diveLog_filter_sectionSuitThickness => 'Ruhavastagság (mm)';

  @override
  String get diveLog_filter_thicknessMin => 'Min';

  @override
  String get diveLog_filter_thicknessMax => 'Max';

  @override
  String get safetySettings_noFlyHeader => 'Repülés merülés után';

  @override
  String get safetySettings_noFlyPreset_standard => 'Normál (12/18/24 ó)';

  @override
  String get safetySettings_noFlyPreset_strict => 'Szigorú (18/24/48 ó)';

  @override
  String get safetySettings_noFlyPreset_subtitle =>
      'Irányadó időközök egyetlen nullidős merülés, ismétlő merülések és dekós merülések után';

  @override
  String get flightWindow_closed => 'A repülés előtt már ne merülj';

  @override
  String get flightWindow_conflict =>
      'A repülési tilalmad túlnyúlik a járat indulásán';

  @override
  String flightWindow_departs(String time) {
    return 'A járat indul: $time';
  }

  @override
  String flightWindow_openTitle(String remaining) {
    return 'Hátralévő merülési idő: $remaining';
  }

  @override
  String flightWindow_surfaceBy(String time) {
    return 'Felszínre érés eddig: $time';
  }

  @override
  String safetyHub_noFly_active_title(String remaining) {
    return 'Repülési tilalom: $remaining van hátra';
  }

  @override
  String safetyHub_noFly_until(String time) {
    return 'Eddig: $time';
  }

  @override
  String get safetyHub_noFly_clear_title => 'Nincs repülési korlátozás';

  @override
  String get safetyHub_noFly_clear_subtitle =>
      'Nincs aktív repülési korlátozás';

  @override
  String safetyHub_noFly_category_single(int hours) {
    return 'Egyetlen nullidős merülés után: $hours ó irányelv';
  }

  @override
  String safetyHub_noFly_category_repetitive(int hours) {
    return 'Ismétlő merülések után: $hours ó irányelv';
  }

  @override
  String safetyHub_noFly_category_deco(int hours) {
    return 'Dekompressziós merülés után: $hours ó irányelv';
  }

  @override
  String get safetyHub_noFly_disclaimer =>
      'DAN/UHMS irányelvek az utolsó merüléstől számítva. Nem helyettesíti a búvárkomputer no-fly idejét.';

  @override
  String get diveLog_detail_altitudeMismatch_title =>
      'A merülőhely magaslaton fekszik';

  @override
  String get diveLog_detail_altitudeMismatch_subtitle =>
      'Ehhez a helyhez magasság van rögzítve, a merüléshez azonban nincs, így a dekompressziós elemzés tengerszintet feltételezett. A javításhoz állítsd be a merülés magasságát.';

  @override
  String diveLog_detail_sacVolumeHint(String unit) {
    return 'Add meg a palack térfogatát, hogy a SAC érték $unit/min-ben jelenjen meg';
  }

  @override
  String safetyHub_alert_noFly(String remaining) {
    return 'Repülési tilalom: $remaining van hátra';
  }

  @override
  String get emergencyCard_title => 'Vészhelyzet';

  @override
  String emergencyCard_callDan(String name) {
    return '$name hívása';
  }

  @override
  String get emergencyCard_callDan_subtitle =>
      'Búvár segélyvonal. Először ezt hívd: ők koordinálják az evakuálást és a kamrába irányítást.';

  @override
  String emergencyCard_ems(String number) {
    return 'Helyi segélyhívó: $number';
  }

  @override
  String get emergencyCard_diverSection => 'Búvár';

  @override
  String emergencyCard_bloodType(String value) {
    return 'Vércsoport: $value';
  }

  @override
  String emergencyCard_allergies(String value) {
    return 'Allergiák: $value';
  }

  @override
  String emergencyCard_medications(String value) {
    return 'Gyógyszerek: $value';
  }

  @override
  String get emergencyCard_contactsSection => 'Vészhelyzeti kapcsolatok';

  @override
  String get emergencyCard_insuranceSection => 'Búvárbiztosítás';

  @override
  String emergencyCard_insurancePolicy(String number) {
    return 'Kötvény: $number';
  }

  @override
  String get emergencyCard_chambersSection => 'Hiperbárikus kamrák';

  @override
  String get emergencyCard_chambersNote =>
      'Az elérhetőség változik. Irányításért mindig először a búvár segélyvonalat hívd.';

  @override
  String emergencyCard_chamberVerified(String date) {
    return 'Adatok ellenőrizve: $date';
  }

  @override
  String get emergencyCard_chambersNearby => 'Legközelebbi kamrák';

  @override
  String emergencyCard_chamberViewAll(int count) {
    return 'Mind a(z) $count kamra megtekintése';
  }

  @override
  String get emergencyCard_chambersNoneNearby =>
      'Nincs kamra a közelben. Hívja a búvár vészhelyzeti vonalat: a legközelebbi ellátásra képes intézménybe irányítják.';

  @override
  String get emergencyCard_chamberCapability_divingEmergency =>
      'Búvárbaleseteket lát el';

  @override
  String get emergencyCard_chamberCapability_hyperbaricUnit =>
      'Kórházi hiperbár egység';

  @override
  String get emergencyCard_chamberCapability_elective =>
      'Csak tervezett kezelés';

  @override
  String get emergencyCard_chamberCapability_unknown =>
      'Ellátási kör nem megerősített';

  @override
  String get emergencyCard_chamberAvailability_h24 => '24 óra';

  @override
  String get emergencyCard_chamberAvailability_onCall => 'Készenlét';

  @override
  String get emergencyCard_chamberAvailability_businessHours => 'Munkaidőben';

  @override
  String get emergencyCard_chamberUnverified =>
      'Az intézmény nem erősítette meg';

  @override
  String get chambersDirectory_title => 'Hiperbár kamrák';

  @override
  String get chambersDirectory_search =>
      'Keresés név, város vagy ország szerint';

  @override
  String get chambersDirectory_empty => 'Nincs a keresésnek megfelelő kamra.';

  @override
  String chambersDirectory_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kamra',
      one: '1 kamra',
    );
    return '$_temp0';
  }

  @override
  String get emergencyCard_hideChamber => 'Elrejtés';

  @override
  String get emergencyCard_chamberHidden => 'Kamra elrejtve';

  @override
  String get emergencyCard_undo => 'Visszavonás';

  @override
  String get emergencyCard_addChamber => 'Kamra hozzáadása';

  @override
  String get emergencyCard_deleteChamber => 'Törlés';

  @override
  String emergencyCard_regionLabel(String region) {
    return 'Régió: $region';
  }

  @override
  String get emergencyCard_regionUnknown =>
      'Ismeretlen régió - a világméretű segélyvonal használata';

  @override
  String get emergencyCard_noDiverData =>
      'Nincsenek búvárprofil-adatok. Add meg a vészhelyzeti kapcsolatokat, egészségügyi és biztosítási adatokat a búvárprofilban.';

  @override
  String get addChamber_title => 'Kamra hozzáadása';

  @override
  String get addChamber_name => 'Név';

  @override
  String get addChamber_country => 'Országkód (pl. HU)';

  @override
  String get addChamber_city => 'Város';

  @override
  String get addChamber_phone => 'Telefon';

  @override
  String get addChamber_notes => 'Jegyzetek';

  @override
  String get addChamber_save => 'Mentés';

  @override
  String get addChamber_nameRequired => 'A név megadása kötelező';

  @override
  String get addChamber_countryRequired => 'Az országkód megadása kötelező';

  @override
  String get addChamber_phoneRequired => 'A telefonszám megadása kötelező';

  @override
  String get safetyHub_emergencyCardLink => 'Vészhelyzeti kártya';

  @override
  String get safetyHub_emergencyCardLink_subtitle =>
      'Offline: segélyvonal, segélyhívó, kamrák, egészségügyi és biztosítási adataid';

  @override
  String get dashboard_quickAction_emergency => 'Vészhelyzeti kártya';

  @override
  String get incidents_title => 'Kvázibaleset-napló';

  @override
  String get incidents_empty =>
      'Nincs rögzített kvázibaleset. Annak feljegyzése, ami majdnem balul sült el - ítélkezés nélkül - láthatóvá teszi a mintázatokat, mielőtt balesetté válnának.';

  @override
  String get incidents_add => 'Kvázibaleset rögzítése';

  @override
  String get incidents_linkedDive => 'Merüléshez kapcsolva';

  @override
  String get incidents_delete_confirm => 'Törlöd ezt a kvázibaleset-jelentést?';

  @override
  String get incidents_notFound => 'Kvázibaleset-jelentés nem található';

  @override
  String get incidentEdit_title_new => 'Kvázibaleset rögzítése';

  @override
  String get incidentEdit_title_edit => 'Kvázibaleset szerkesztése';

  @override
  String get incidentEdit_category => 'Kategória';

  @override
  String get incidentEdit_severity => 'Súlyosság';

  @override
  String get incidentEdit_severity_minor => 'Enyhe';

  @override
  String get incidentEdit_severity_moderate => 'Közepes';

  @override
  String get incidentEdit_severity_serious => 'Súlyos';

  @override
  String get incidentEdit_date => 'Mikor történt';

  @override
  String get incidentEdit_narrative => 'Mi történt';

  @override
  String get incidentEdit_narrative_hint =>
      'Csak a tények, a saját szavaiddal. Ez privát marad.';

  @override
  String get incidentEdit_narrative_required => 'Írja le, mi történt';

  @override
  String get incidentEdit_contributingFactors =>
      'Mi játszott közre (opcionális)';

  @override
  String get incidentEdit_lessonsLearned =>
      'Mi segítene legközelebb (opcionális)';

  @override
  String get incidentEdit_save => 'Mentés';

  @override
  String get incidentEdit_privacyNote =>
      'A kvázibaleset-jelentések szinkronizálódnak az eszközeid között és a mentésekben is szerepelnek, de exportokba vagy megosztott naplóoldalakra soha nem kerülnek.';

  @override
  String get incidentCategory_buoyancy => 'Lebegés';

  @override
  String get incidentCategory_gasSupply => 'Gázellátás';

  @override
  String get incidentCategory_equipment => 'Felszerelés';

  @override
  String get incidentCategory_buddySeparation => 'Elszakadás a társtól';

  @override
  String get incidentCategory_marineLife => 'Tengeri élővilág';

  @override
  String get incidentCategory_boatSurface => 'Hajó / felszín';

  @override
  String get incidentCategory_medical => 'Egészségügyi';

  @override
  String get incidentCategory_planning => 'Tervezés';

  @override
  String get incidentCategory_other => 'Egyéb';

  @override
  String get safetyHub_incidentsLink => 'Kvázibaleset-napló';

  @override
  String get safetyHub_incidentsLink_subtitle =>
      'Privát, nem büntető jellegű eseményjegyzetek';

  @override
  String get diveLog_detail_menu_logNearMiss => 'Kvázibaleset rögzítése';

  @override
  String diveLog_detail_linkedIncidents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kvázibaleset kapcsolódik ehhez a merüléshez',
      one: '1 kvázibaleset kapcsolódik ehhez a merüléshez',
    );
    return '$_temp0';
  }

  @override
  String get planning_card_noFly_subtitle =>
      'Irányadó visszaszámlálás az utolsó merüléseidtől';

  @override
  String get settings_section_safety_title => 'Biztonság';

  @override
  String get settings_section_safety_subtitle =>
      'Áttekintési szabályok és repülés merülés után';

  @override
  String get settings_section_security_title => 'Alkalmazásbiztonság';

  @override
  String get settings_section_security_subtitle =>
      'Alkalmazászár és adatbázis-titkosítás';

  @override
  String get settings_security_appLock => 'Alkalmazászár';

  @override
  String get settings_security_appLock_subtitle =>
      'Jelszó vagy biometria szükséges az alkalmazás megnyitásához';

  @override
  String get settings_security_biometrics => 'Feloldás biometriával';

  @override
  String get settings_security_autoLock => 'Automatikus zárolás';

  @override
  String get settings_security_autoLock_immediately => 'Azonnal';

  @override
  String settings_security_autoLock_minutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes perc után',
      one: '1 perc után',
    );
    return '$_temp0';
  }

  @override
  String get settings_security_autoLock_never => 'Soha';

  @override
  String get settings_security_encryption => 'Adatbázis titkosítása';

  @override
  String get settings_security_encryption_subtitle =>
      'Védje merülési naplófájlját nyugalmi titkosítással. A titkosítás hatással lehet a teljesítményre.';

  @override
  String get settings_security_encryption_progress_backup =>
      'Biztonsági mentés készítése...';

  @override
  String get settings_security_encryption_progress_encrypt =>
      'Adatbázis titkosítása...';

  @override
  String get settings_security_encryption_progress_decrypt =>
      'Adatbázis visszafejtése...';

  @override
  String get settings_security_encryption_progress_reopen =>
      'Adatbázis újranyitása...';

  @override
  String get settings_security_changePassword => 'Jelszó módosítása';

  @override
  String get settings_security_regenerateRecovery => 'Új helyreállítási kód';

  @override
  String get settings_security_setPassword => 'Alkalmazásjelszó beállítása';

  @override
  String get settings_security_password => 'Jelszó';

  @override
  String get settings_security_confirmPassword => 'Jelszó megerősítése';

  @override
  String get settings_security_currentPassword => 'Jelenlegi jelszó';

  @override
  String get settings_security_newPassword => 'Új jelszó';

  @override
  String get settings_security_passwordTooShort =>
      'A jelszónak legalább 4 karakterből kell állnia.';

  @override
  String get settings_security_passwordMismatch => 'A jelszavak nem egyeznek.';

  @override
  String get settings_security_wrongPassword => 'Hibás jelszó.';

  @override
  String get settings_security_recoveryCode_title =>
      'Az Ön helyreállítási kódja';

  @override
  String get settings_security_recoveryCode_explain =>
      'Írja fel és őrizze biztonságos helyen. Ez az egyetlen módja az alkalmazás feloldásának, ha elfelejti a jelszavát, és minden korábbi helyreállítási kódot érvénytelenít.';

  @override
  String get settings_security_recoveryCode_savedConfirm =>
      'Elmentettem a helyreállítási kódomat';

  @override
  String get settings_security_disableBlockedByEncryption_title =>
      'A titkosítás be van kapcsolva';

  @override
  String get settings_security_disableBlockedByEncryption_body =>
      'Először kapcsolja ki az adatbázis-titkosítást, mielőtt kikapcsolná az alkalmazászárat. A titkosított adatbázishoz hitelesítő adat szükséges.';

  @override
  String get settings_security_enableEncryption_title =>
      'Titkosítja az adatbázist?';

  @override
  String get settings_security_enableEncryption_body =>
      'Először biztonsági mentés készül, majd az adatbázisfájl helyben újratitkosítódik. Nagy naplóknál ez eltarthat egy ideig. A titkosítás hatással lehet a teljesítményre.';

  @override
  String get settings_security_disableEncryption_title =>
      'Kikapcsolja a titkosítást?';

  @override
  String get settings_security_disableEncryption_body =>
      'Az adatbázisfájl ismét titkosítás nélkül tárolódik a lemezen.';

  @override
  String get settings_security_turnOffAppLock_title =>
      'Kikapcsolja az alkalmazászárat?';

  @override
  String get settings_security_turnOffAppLock_body =>
      'Az alkalmazás jelszókérés nélkül nyílik meg.';

  @override
  String get settings_security_unlock_title => 'Adja meg a jelszavát';

  @override
  String get settings_security_cancel => 'Mégse';

  @override
  String get settings_security_continue => 'Folytatás';

  @override
  String get settings_security_done => 'Kész';

  @override
  String get settings_security_turnOff => 'Kikapcsolás';

  @override
  String get dataQuality_inbox_title => 'Adatminőség';

  @override
  String get dataQuality_badge_tooltip => 'Adatminőség-ellenőrzés';

  @override
  String get dataQuality_scan_start => 'Könyvtár átvizsgálása';

  @override
  String dataQuality_scan_progress(int done, int total) {
    return '$done / $total merülés ellenőrizve';
  }

  @override
  String get dataQuality_scan_cancel => 'Mégse';

  @override
  String dataQuality_scan_done(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Az átvizsgálás kész - $count elem ellenőrzésre vár',
      one: 'Az átvizsgálás kész - 1 elem ellenőrzésre vár',
      zero: 'Az átvizsgálás kész - nincs új észlelés',
    );
    return '$_temp0';
  }

  @override
  String dataQuality_scan_errors(int count) {
    return '$count merülést nem sikerült teljesen ellenőrizni';
  }

  @override
  String dataQuality_lastScan(String when) {
    return 'Utolsó átvizsgálás: $when';
  }

  @override
  String get dataQuality_neverScanned =>
      'A merülési naplódat még nem vizsgáltuk át';

  @override
  String get dataQuality_empty_title => 'Minden rendben';

  @override
  String get dataQuality_empty_subtitle =>
      'Nincs adatminőségi észlelés. Vizsgáld át a könyvtáradat, hogy ellenőrizd az importált merüléseket.';

  @override
  String get dataQuality_banner_newChecks =>
      'Új minőségi ellenőrzések érhetők el';

  @override
  String get dataQuality_banner_rescan => 'Újraellenőrzés';

  @override
  String get dataQuality_action_dismiss => 'Elvetés';

  @override
  String get dataQuality_action_dismissFiltered =>
      'Az összes megjelenített elvetése';

  @override
  String get dataQuality_action_goToDive => 'Ugrás a merüléshez';

  @override
  String get dataQuality_action_undo => 'Visszavonás';

  @override
  String get dataQuality_repair_applied => 'Javítás alkalmazva';

  @override
  String get dataQuality_repair_noChange => 'Itt nincs mit javítani';

  @override
  String get dataQuality_repair_needsReview =>
      'Nincs automatikus javítás. Nyisd meg a merülést a javításhoz.';

  @override
  String get dataQuality_repair_failed => 'A javítás sikertelen';

  @override
  String get dataQuality_chip_all => 'Mind';

  @override
  String get dataQuality_chip_time => 'Idő';

  @override
  String get dataQuality_chip_profile => 'Profil';

  @override
  String get dataQuality_chip_gas => 'Gáz';

  @override
  String get dataQuality_chip_tanks => 'Palackok';

  @override
  String get dataQuality_chip_duplicates => 'Duplikátumok';

  @override
  String get dataQuality_chip_sources => 'Források';

  @override
  String get dataQuality_detector_clock_offset => 'Óra és időzóna';

  @override
  String get dataQuality_detector_duplicate => 'Valószínű duplikátum';

  @override
  String get dataQuality_detector_split_pair => 'Véletlen szétválás';

  @override
  String get dataQuality_detector_sample_gap => 'Hézagok a mintákban';

  @override
  String get dataQuality_detector_depth_spike => 'Mélységi kiugrás';

  @override
  String get dataQuality_detector_impossible_rate => 'Lehetetlen sebesség';

  @override
  String get dataQuality_detector_temp_anomaly => 'Hőmérsékleti rendellenesség';

  @override
  String get dataQuality_detector_pressure_anomaly => 'Nyomásrendellenesség';

  @override
  String get dataQuality_detector_gas_mod => 'Gáz/MOD-ellentmondás';

  @override
  String get dataQuality_detector_tank_assignment => 'Rossz palack';

  @override
  String get dataQuality_detector_source_conflict => 'Ütköző források';

  @override
  String dataQuality_msg_clock_future(String date) {
    return 'A merülés dátuma a jövőben van ($date)';
  }

  @override
  String dataQuality_msg_clock_ancient(String date) {
    return 'A merülés dátuma 1950 előtti ($date)';
  }

  @override
  String dataQuality_msg_clock_offset(int hours) {
    return 'Az egyik forrás órája $hours órával eltér';
  }

  @override
  String dataQuality_msg_clock_overlap(int minutes) {
    return '$minutes perccel átfed egy másik merülést';
  }

  @override
  String dataQuality_msg_duplicate(int percent, int minutes) {
    return '$percent%-os egyezés egy $minutes perccel eltérő merüléssel';
  }

  @override
  String dataQuality_msg_split(int minutes) {
    return 'Ugyanaz a számítógép $minutes perces felszíni szünet után folytatódott';
  }

  @override
  String dataQuality_msg_gap(int count, String longest) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hézag a mintákban',
      one: '1 hézag a mintákban',
    );
    return '$_temp0, a leghosszabb $longest';
  }

  @override
  String dataQuality_msg_spike(String depth, String time) {
    return 'Mélységi kiugrás $depth értékig $time időpontban';
  }

  @override
  String dataQuality_msg_negativeDepth(int count) {
    return '$count negatív mélységű minta';
  }

  @override
  String dataQuality_msg_maxDepthMismatch(String stored, String profile) {
    return 'A rögzített maximális mélység $stored, de a profil $profile értéket mutat';
  }

  @override
  String dataQuality_msg_rate(String rate, int seconds) {
    return '$rate függőleges sebesség $seconds másodpercen át fennmaradt';
  }

  @override
  String dataQuality_msg_tempRange(String min, String max) {
    return 'A vízhőmérséklet a hihető tartományon kívül esik ($min - $max)';
  }

  @override
  String get dataQuality_msg_tempUnitBug =>
      'Az értékek hőmérséklet-mértékegységi hibára utalnak';

  @override
  String dataQuality_msg_tempJump(String delta) {
    return 'A hőmérséklet $delta értéket ugrott egyetlen mintában';
  }

  @override
  String dataQuality_msg_tempScalar(String temp) {
    return 'A rögzített vízhőmérséklet $temp nem hihető';
  }

  @override
  String dataQuality_msg_pressureSwap(String end, String start) {
    return 'A $end végnyomás magasabb, mint a $start kezdőnyomás';
  }

  @override
  String dataQuality_msg_pressureEndpoint(String record, String series) {
    return 'A palack rekordja $record értéket jelez, de az érzékelősorozat $series értéket mutat';
  }

  @override
  String dataQuality_msg_pressureRise(String rise) {
    return 'A nyomás $rise értékkel emelkedett a merülés közben gázcsere nélkül';
  }

  @override
  String dataQuality_msg_sac(String sac) {
    return 'A becsült felszíni fogyasztás ($sac) nem hihető';
  }

  @override
  String dataQuality_msg_ppo2(String ppo2, String gas, String depth) {
    return 'A ppO2 elérte a(z) $ppo2 értéket $gas gázzal $depth mélységben';
  }

  @override
  String dataQuality_msg_hypoxic(String gas) {
    return 'Hipoxikus keverék ($gas) használatban a felszínen';
  }

  @override
  String dataQuality_msg_switchMod(String depth, String mod) {
    return 'A gázcsere $depth mélységben meghaladja az adott gáz $mod MOD-értékét';
  }

  @override
  String dataQuality_msg_tankInactive(String drop) {
    return 'Ez a palack $drop nyomást veszített, miközben a gáz-idővonal szerint nem volt használatban';
  }

  @override
  String get dataQuality_msg_twinTanks =>
      'Két palack majdnem azonos nyomássorozatot mutat';

  @override
  String dataQuality_msg_sourceDepth(String primary, String source) {
    return 'A források nem egyeznek a maximális mélységben: $primary vs. $source';
  }

  @override
  String get dataQuality_msg_salinityHint =>
      'Az állandó arány a sós/édesvíz beállítás eltérésére utal';

  @override
  String get dataQuality_msg_sourceDuration =>
      'A források nem egyeznek a merülés időtartamában';

  @override
  String get dataQuality_msg_sourceTemp =>
      'A források nem egyeznek a vízhőmérsékletben';

  @override
  String dataQuality_repairLabel_shiftTime(String offset) {
    return 'Idő eltolása ennyivel: $offset';
  }

  @override
  String get dataQuality_repairLabel_shiftImport =>
      'Az import összes merülésének eltolása';

  @override
  String get dataQuality_repairLabel_consolidate => 'Konszolidálás';

  @override
  String get dataQuality_repairLabel_combine => 'Összevonás egy merüléssé';

  @override
  String get dataQuality_repairLabel_despike => 'Kiugrás eltávolítása';

  @override
  String get dataQuality_repairLabel_clampNegative =>
      'Felszín feletti mélységek korlátozása';

  @override
  String get dataQuality_repairLabel_smoothRates =>
      'Lehetetlen sebességek simítása';

  @override
  String get dataQuality_repairLabel_fillGaps => 'Hézagok kitöltése';

  @override
  String get dataQuality_repairLabel_smoothTemp => 'Hőmérséklet simítása';

  @override
  String get dataQuality_repairLabel_convertTemp => 'Hőmérséklet átváltása';

  @override
  String get dataQuality_repairLabel_recompute => 'Újraszámítás a profilból';

  @override
  String get dataQuality_repairLabel_swapPressures =>
      'Kezdő-/végnyomás felcserélése';

  @override
  String get dataQuality_repairLabel_setFromSeries =>
      'Érzékelőértékek használata';

  @override
  String get dataQuality_repairLabel_swapSeries =>
      'Palacksorozatok felcserélése';

  @override
  String get dataQuality_repairLabel_reassignSeries =>
      'Sorozat áthelyezése másik palackra';

  @override
  String get dataQuality_repairLabel_setPrimary =>
      'Beállítás elsődleges forrásként';

  @override
  String get dataQuality_repairLabel_split => 'Szétválasztás külön merülésekre';

  @override
  String get dataQuality_repairLabel_compare => 'Profilok összehasonlítása';

  @override
  String get dataQuality_settings_title => 'Adatminőség';

  @override
  String get dataQuality_settings_subtitle =>
      'Válaszd ki, mely ellenőrzések fussanak átvizsgáláskor';

  @override
  String dataQuality_summary_flagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elem megjelölve ellenőrzésre',
      one: '1 elem megjelölve ellenőrzésre',
    );
    return '$_temp0';
  }

  @override
  String get dataQuality_summary_review => 'Áttekintés';

  @override
  String get dataQuality_detail_chip => 'Áttekintés';

  @override
  String dataQuality_detail_chipCount(int count) {
    return 'Áttekintés ($count)';
  }

  @override
  String get settings_mediaStorage_quality_section => 'Feltöltési minőség';

  @override
  String get settings_mediaStorage_quality_photos => 'Fényképek';

  @override
  String get settings_mediaStorage_quality_video => 'Videó';

  @override
  String get settings_mediaStorage_quality_original => 'Eredeti';

  @override
  String get settings_mediaStorage_quality_high => 'Magas';

  @override
  String get settings_mediaStorage_quality_balanced => 'Kiegyensúlyozott';

  @override
  String get settings_mediaStorage_quality_small => 'Kicsi';

  @override
  String get settings_mediaStorage_quality_caveat =>
      'Ha be van állítva tömörítési szint, a teljes felbontású eredetik nem töltődnek fel — csak ezen az eszközön maradnak meg.';

  @override
  String get settings_mediaStorage_quality_reuploadQueued =>
      'Újratöltés sorba állítva';

  @override
  String get settings_mediaStorage_quality_linuxFfmpegHint =>
      'Telepítse az ffmpeg-et a videótömörítés engedélyezéséhez. Addig az eredetik kerülnek feltöltésre.';

  @override
  String get settings_mediaStorage_quality_saveFailed =>
      'A feltöltési minőség mentése nem sikerült. Próbáld újra.';

  @override
  String get settings_mediaStorage_quality_noTranscoderHint =>
      'Ez az eszköz nem tud videót tömöríteni. Róla az eredetik töltődnek fel.';

  @override
  String get reef_section_title => 'Ökoszisztéma';

  @override
  String get reef_section_sourcesTooltip => 'Adatforrások';

  @override
  String get reef_section_loadError =>
      'Az ökoszisztéma-adatok jelenleg nem tölthetők be';

  @override
  String get reef_habitat_title => 'Zátony élőhely';

  @override
  String get reef_habitat_onReef => 'Korallzátonyon';

  @override
  String reef_habitat_onReefWithThreat(String threat) {
    return 'Korallzátonyon, veszélyeztetettségi szint: $threat';
  }

  @override
  String get reef_habitat_noReef =>
      'Nincs térképezett korallzátony ezen a helyen';

  @override
  String get reef_habitat_unavailable =>
      'A zátony élőhelye most nem ellenőrizhető';

  @override
  String get water_conditions_title => 'Vízviszonyok';

  @override
  String get water_conditions_unavailable =>
      'A vízviszonyok jelenleg nem ellenőrizhetők';

  @override
  String get water_conditions_noData =>
      'Nincsenek műholdas vízadatok ehhez a helyhez';

  @override
  String get water_conditions_freshwater =>
      'A műholdas vízhőmérséklet csak az óceánokat fedi le';

  @override
  String water_conditions_anomaly(String value) {
    return 'Anomália $value';
  }

  @override
  String reef_health_degreeHeatingWeeks(String value) {
    return 'Hőterhelési hetek $value C-hét';
  }

  @override
  String reef_health_seaSurface(String value) {
    return 'Tengerfelszín $value';
  }

  @override
  String reef_health_asOf(String date) {
    return 'Dátum: $date';
  }

  @override
  String get reef_health_levelNoStress => 'Nincs hőstressz';

  @override
  String get reef_health_levelWatch => 'Fehéredési megfigyelés';

  @override
  String get reef_health_levelWarning => 'Fehéredési figyelmeztetés';

  @override
  String get reef_health_levelAlert1 => 'Fehéredési riasztás 1. szint';

  @override
  String get reef_health_levelAlert2 => 'Fehéredési riasztás 2. szint';

  @override
  String get reef_health_levelAlert3 => 'Fehéredési riasztás 3. szint';

  @override
  String get reef_health_levelAlert4 => 'Fehéredési riasztás 4. szint';

  @override
  String get reef_health_levelAlert5 => 'Fehéredési riasztás 5. szint';

  @override
  String get reef_protection_title => 'Védett terület';

  @override
  String get reef_protection_none => 'Nem védett tengeri területen';

  @override
  String get reef_protection_unavailable =>
      'A védettségi állapot most nem ellenőrizhető';

  @override
  String get reef_protection_viewRegulations => 'Szabályok megtekintése';

  @override
  String reef_protection_iucn(String category) {
    return 'IUCN $category';
  }

  @override
  String get reef_species_recordedNearby => 'Közelben rögzítve';

  @override
  String get reef_species_addToExpected => 'Hozzáadás a várható fajokhoz';

  @override
  String reef_species_showAll(int count) {
    return 'Mind a(z) $count megjelenítése';
  }

  @override
  String get reef_species_showFewer => 'Kevesebb megjelenítése';

  @override
  String get reef_attribution_title => 'Zátony adatforrásai';

  @override
  String get reef_attribution_wri =>
      'Zátony jelenléte és veszélyeztetettsége. CC BY 3.0.';

  @override
  String get reef_attribution_noaa =>
      'Tengerfelszíni hőmérséklet és hőstressz. Közkincs.';

  @override
  String get reef_attribution_gbif =>
      'Fajelőfordulási adatok, CC0 és CC BY 4.0 szűrve.';

  @override
  String get reef_attribution_protectedSeas =>
      'Védett tengeri területek határai. CC BY 4.0.';

  @override
  String get enum_visibilityBand_excellent => 'Kiváló';

  @override
  String get enum_visibilityBand_good => 'Jó';

  @override
  String get enum_visibilityBand_moderate => 'Közepes';

  @override
  String get enum_visibilityBand_poor => 'Gyenge';

  @override
  String visibility_range_between(String min, String max, String unit) {
    return '$min-$max $unit';
  }

  @override
  String visibility_range_over(String min, String unit) {
    return 'több mint $min $unit';
  }

  @override
  String visibility_range_under(String max, String unit) {
    return 'kevesebb mint $max $unit';
  }

  @override
  String get settings_coordinateFormat_title => 'Koordináta-formátum';

  @override
  String get settings_coordinateFormat_subtitle =>
      'Hogyan jelennek meg és hogyan adhatók meg a GPS-pozíciók';

  @override
  String get settings_placeNameLanguage_title => 'Helynevek nyelve';

  @override
  String get settings_placeNameLanguage_subtitle =>
      'Akkor használjuk, amikor az ország, régió, település és víztest a koordinátákból kerül lekérdezésre. A meglévő merülőhelyek nem változnak.';

  @override
  String get settings_coordinateFormat_decimalDegrees => 'Tizedes fok';

  @override
  String get settings_coordinateFormat_degreesDecimalMinutes =>
      'Fok és tizedes perc';

  @override
  String get settings_coordinateFormat_degreesMinutesSeconds =>
      'Fok, perc, másodperc';

  @override
  String get settings_coordinateFormat_utm => 'UTM';

  @override
  String get settings_coordinateFormat_mgrs => 'MGRS';

  @override
  String get settings_visibilityScale_title => 'Látótávolság-skála';

  @override
  String get settings_visibilityScale_subtitle =>
      'Mekkora távolság számít jó látásnak ott, ahol merülsz';

  @override
  String get settings_visibilityScale_preset_tropical => 'Trópusi';

  @override
  String get settings_visibilityScale_preset_temperate => 'Mérsékelt';

  @override
  String get settings_visibilityScale_preset_coldWater => 'Hidegvízi / Belvízi';

  @override
  String get settings_visibilityScale_preset_custom => 'Egyéni';

  @override
  String get settings_visibilityScale_customExcellent => 'Kiváló ettől';

  @override
  String get settings_visibilityScale_customGood => 'Jó ettől';

  @override
  String get settings_visibilityScale_customModerate => 'Közepes ettől';

  @override
  String get settings_visibilityScale_invalidOrder =>
      'Minden értéknek kisebbnek kell lennie a felette lévőnél és nagyobbnak nullánál';

  @override
  String statistics_conditions_visibility_legacySuffix(String band) {
    return '$band (mérés előtt rögzítve)';
  }

  @override
  String common_selection_countSelected(Object count) {
    return '$count kijelölve';
  }

  @override
  String get common_selection_enterTooltip => 'Elemek kijelölése';

  @override
  String get common_selection_exitTooltip => 'Kijelölés befejezése';

  @override
  String get common_selection_selectAllTooltip => 'Összes kijelölése';

  @override
  String get common_selection_deselectAllTooltip => 'Kijelölés megszüntetése';

  @override
  String common_bulkDelete_title(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elem törlése?',
      one: '$count elem törlése?',
    );
    return '$_temp0';
  }

  @override
  String get common_bulkDelete_body => 'Ez a művelet nem vonható vissza.';

  @override
  String common_bulkDelete_snackbar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count törölve',
      one: '$count törölve',
    );
    return '$_temp0';
  }

  @override
  String get marineLife_species_delete_confirmTitle => 'Törli a fajt?';

  @override
  String marineLife_species_delete_confirmBody(String name) {
    return 'Biztosan törli a következőt: \"$name\"?';
  }

  @override
  String marineLife_species_delete_inUseError(String name) {
    return 'A(z) \"$name\" nem törölhető - vannak észlelései';
  }

  @override
  String marineLife_species_delete_snackbar(String name) {
    return '\"$name\" törölve';
  }

  @override
  String marineLife_species_delete_error(String error) {
    return 'Hiba a faj törlésekor: $error';
  }

  @override
  String get enum_diveField_diveNumber => 'Merülés száma';

  @override
  String get enum_diveField_dateTime => 'Dátum és idő';

  @override
  String get enum_diveField_siteName => 'Merülőhely neve';

  @override
  String get enum_diveField_diveName => 'Merülés neve';

  @override
  String get enum_diveField_maxDepth => 'Max mélység';

  @override
  String get enum_diveField_avgDepth => 'Átlagos mélység';

  @override
  String get enum_diveField_bottomTime => 'Fenékidő';

  @override
  String get enum_diveField_runtime => 'Futásidő';

  @override
  String get enum_diveField_waterTemp => 'Vízhőmérséklet';

  @override
  String get enum_diveField_airTemp => 'Léghőmérséklet';

  @override
  String get enum_diveField_visibility => 'Látótávolság';

  @override
  String get enum_diveField_currentDirection => 'Áramlat iránya';

  @override
  String get enum_diveField_currentStrength => 'Áramlat erőssége';

  @override
  String get enum_diveField_swellHeight => 'Hullámmagasság';

  @override
  String get enum_diveField_entryMethod => 'Beszállási mód';

  @override
  String get enum_diveField_exitMethod => 'Kiszállási mód';

  @override
  String get enum_diveField_waterType => 'Víz típusa';

  @override
  String get enum_diveField_altitude => 'Magasság';

  @override
  String get enum_diveField_surfacePressure => 'Felszíni nyomás';

  @override
  String get enum_diveField_windSpeed => 'Szélsebesség';

  @override
  String get enum_diveField_cloudCover => 'Felhőzet';

  @override
  String get enum_diveField_precipitation => 'Csapadék';

  @override
  String get enum_diveField_humidity => 'Páratartalom';

  @override
  String get enum_diveField_weatherDescription => 'Időjárás';

  @override
  String get enum_diveField_primaryGas => 'Fő gáz';

  @override
  String get enum_diveField_diluentGas => 'Hígítógáz';

  @override
  String get enum_diveField_tankCount => 'Palackok száma';

  @override
  String get enum_diveField_startPressure => 'Kezdőnyomás';

  @override
  String get enum_diveField_endPressure => 'Végnyomás';

  @override
  String get enum_diveField_sacRate => 'SAC érték';

  @override
  String get enum_diveField_gasConsumed => 'Elhasznált gáz';

  @override
  String get enum_diveField_totalWeight => 'Összsúly';

  @override
  String get enum_diveField_diveComputerModel => 'Merülésszámítógép';

  @override
  String get enum_diveField_gradientFactorLow => 'GF alacsony';

  @override
  String get enum_diveField_gradientFactorHigh => 'GF magas';

  @override
  String get enum_diveField_decoAlgorithm => 'Dekó algoritmus';

  @override
  String get enum_diveField_decoConservatism => 'Konzervativizmus';

  @override
  String get enum_diveField_cnsStart => 'CNS kezdet';

  @override
  String get enum_diveField_cnsEnd => 'CNS vég';

  @override
  String get enum_diveField_otu => 'OTU';

  @override
  String get enum_diveField_diveMode => 'Merülési mód';

  @override
  String get enum_diveField_setpointLow => 'Alsó alapérték';

  @override
  String get enum_diveField_setpointHigh => 'Felső alapérték';

  @override
  String get enum_diveField_setpointDeco => 'Dekó alapérték';

  @override
  String get enum_diveField_buddy => 'Búvártárs';

  @override
  String get enum_diveField_diveMaster => 'Divemaster';

  @override
  String get enum_diveField_siteLocation => 'Merülőhely helyszíne';

  @override
  String get enum_diveField_diveCenterName => 'Búvárközpont';

  @override
  String get enum_diveField_siteLatitude => 'Szélesség';

  @override
  String get enum_diveField_siteLongitude => 'Hosszúság';

  @override
  String get enum_diveField_tripName => 'Utazás';

  @override
  String get enum_diveField_ratingStars => 'Értékelés';

  @override
  String get enum_diveField_isFavorite => 'Kedvenc';

  @override
  String get enum_diveField_notes => 'Jegyzetek';

  @override
  String get enum_diveField_tags => 'Címkék';

  @override
  String get enum_diveField_importSource => 'Importálás forrása';

  @override
  String get enum_diveField_diveTypeName => 'Merülés típusa';

  @override
  String get enum_diveField_surfaceInterval => 'Felszíni szünet';

  @override
  String get enum_diveField_diveNumber_short => '#';

  @override
  String get enum_diveField_dateTime_short => 'Dátum';

  @override
  String get enum_diveField_siteName_short => 'Hely';

  @override
  String get enum_diveField_diveName_short => 'Név';

  @override
  String get enum_diveField_maxDepth_short => 'Max mély';

  @override
  String get enum_diveField_avgDepth_short => 'Átl mély';

  @override
  String get enum_diveField_bottomTime_short => 'FI';

  @override
  String get enum_diveField_runtime_short => 'Fut.';

  @override
  String get enum_diveField_waterTemp_short => 'Vízhő';

  @override
  String get enum_diveField_airTemp_short => 'Léghő';

  @override
  String get enum_diveField_visibility_short => 'Látás';

  @override
  String get enum_diveField_currentDirection_short => 'Ár irány';

  @override
  String get enum_diveField_currentStrength_short => 'Áram.';

  @override
  String get enum_diveField_swellHeight_short => 'Hullám';

  @override
  String get enum_diveField_entryMethod_short => 'Besz.';

  @override
  String get enum_diveField_exitMethod_short => 'Kisz.';

  @override
  String get enum_diveField_waterType_short => 'Víz';

  @override
  String get enum_diveField_altitude_short => 'Mag.';

  @override
  String get enum_diveField_surfacePressure_short => 'F nyomás';

  @override
  String get enum_diveField_windSpeed_short => 'Szél';

  @override
  String get enum_diveField_cloudCover_short => 'Felhő';

  @override
  String get enum_diveField_precipitation_short => 'Csap.';

  @override
  String get enum_diveField_humidity_short => 'Pára';

  @override
  String get enum_diveField_weatherDescription_short => 'Időjárás';

  @override
  String get enum_diveField_primaryGas_short => 'Gáz';

  @override
  String get enum_diveField_diluentGas_short => 'Híg';

  @override
  String get enum_diveField_tankCount_short => 'Palack';

  @override
  String get enum_diveField_startPressure_short => 'Kezdő ny';

  @override
  String get enum_diveField_endPressure_short => 'Vég ny';

  @override
  String get enum_diveField_sacRate_short => 'SAC';

  @override
  String get enum_diveField_gasConsumed_short => 'Gázfogy';

  @override
  String get enum_diveField_totalWeight_short => 'Súly';

  @override
  String get enum_diveField_diveComputerModel_short => 'Komputer';

  @override
  String get enum_diveField_gradientFactorLow_short => 'GFL';

  @override
  String get enum_diveField_gradientFactorHigh_short => 'GFH';

  @override
  String get enum_diveField_decoAlgorithm_short => 'Algo';

  @override
  String get enum_diveField_decoConservatism_short => 'Konzerv';

  @override
  String get enum_diveField_cnsStart_short => 'CNS kezd';

  @override
  String get enum_diveField_cnsEnd_short => 'CNS vég';

  @override
  String get enum_diveField_otu_short => 'OTU';

  @override
  String get enum_diveField_diveMode_short => 'Mód';

  @override
  String get enum_diveField_setpointLow_short => 'SP alsó';

  @override
  String get enum_diveField_setpointHigh_short => 'SP felső';

  @override
  String get enum_diveField_setpointDeco_short => 'SP dekó';

  @override
  String get enum_diveField_buddy_short => 'Társ';

  @override
  String get enum_diveField_diveMaster_short => 'DM';

  @override
  String get enum_diveField_siteLocation_short => 'Helyszín';

  @override
  String get enum_diveField_diveCenterName_short => 'Központ';

  @override
  String get enum_diveField_siteLatitude_short => 'Lat';

  @override
  String get enum_diveField_siteLongitude_short => 'Hossz';

  @override
  String get enum_diveField_tripName_short => 'Utazás';

  @override
  String get enum_diveField_ratingStars_short => 'Ért.';

  @override
  String get enum_diveField_isFavorite_short => 'Kedv.';

  @override
  String get enum_diveField_notes_short => 'Jegyz.';

  @override
  String get enum_diveField_tags_short => 'Címkék';

  @override
  String get enum_diveField_importSource_short => 'Forrás';

  @override
  String get enum_diveField_diveTypeName_short => 'Típus';

  @override
  String get enum_diveField_surfaceInterval_short => 'FSZ';

  @override
  String get enum_siteField_siteName => 'Név';

  @override
  String get enum_siteField_location => 'Helyszín';

  @override
  String get enum_siteField_country => 'Ország';

  @override
  String get enum_siteField_region => 'Régió';

  @override
  String get enum_siteField_city => 'Város';

  @override
  String get enum_siteField_island => 'Sziget';

  @override
  String get enum_siteField_bodyOfWater => 'Víztest';

  @override
  String get enum_siteField_diveCount => 'Merülésszám';

  @override
  String get enum_siteField_maxDepth => 'Max mélység';

  @override
  String get enum_siteField_minDepth => 'Min mélység';

  @override
  String get enum_siteField_altitude => 'Magasság';

  @override
  String get enum_siteField_waterType => 'Víz típusa';

  @override
  String get enum_siteField_typicalVisibility => 'Jellemző látótávolság';

  @override
  String get enum_siteField_typicalCurrent => 'Jellemző áramlat';

  @override
  String get enum_siteField_difficulty => 'Nehézségi szint';

  @override
  String get enum_siteField_entryType => 'Beszállás típusa';

  @override
  String get enum_siteField_bestSeason => 'Legjobb évszak';

  @override
  String get enum_siteField_mooringNumber => 'Kikötőszám';

  @override
  String get enum_siteField_hazards => 'Veszélyek';

  @override
  String get enum_siteField_rating => 'Értékelés';

  @override
  String get enum_siteField_notes => 'Jegyzetek';

  @override
  String get enum_siteField_latitude => 'Szélesség';

  @override
  String get enum_siteField_longitude => 'Hosszúság';

  @override
  String get enum_siteField_siteName_short => 'Név';

  @override
  String get enum_siteField_location_short => 'Hely';

  @override
  String get enum_siteField_country_short => 'Ország';

  @override
  String get enum_siteField_region_short => 'Régió';

  @override
  String get enum_siteField_city_short => 'Város';

  @override
  String get enum_siteField_island_short => 'Sziget';

  @override
  String get enum_siteField_bodyOfWater_short => 'Víztest';

  @override
  String get enum_siteField_diveCount_short => 'Mer.';

  @override
  String get enum_siteField_maxDepth_short => 'Max mély';

  @override
  String get enum_siteField_minDepth_short => 'Min mély';

  @override
  String get enum_siteField_altitude_short => 'Mag.';

  @override
  String get enum_siteField_waterType_short => 'Víz';

  @override
  String get enum_siteField_typicalVisibility_short => 'Látás';

  @override
  String get enum_siteField_typicalCurrent_short => 'Áramlat';

  @override
  String get enum_siteField_difficulty_short => 'Neh.';

  @override
  String get enum_siteField_entryType_short => 'Besz.';

  @override
  String get enum_siteField_exitMethod => 'Kilépés módja';

  @override
  String get enum_siteField_exitMethod_short => 'Kilépés';

  @override
  String get enum_siteField_bestSeason_short => 'Évszak';

  @override
  String get enum_siteField_mooringNumber_short => 'Kikötő';

  @override
  String get enum_siteField_hazards_short => 'Veszély';

  @override
  String get enum_siteField_rating_short => 'Ért.';

  @override
  String get enum_siteField_notes_short => 'Jegyz.';

  @override
  String get enum_siteField_latitude_short => 'Lat';

  @override
  String get enum_siteField_longitude_short => 'Hossz';

  @override
  String get enum_siteField_depthRange => 'Mélységtartomány';

  @override
  String get enum_siteField_depthRange_short => 'Mélység';

  @override
  String get enum_siteField_lastDived => 'Utolsó merülés';

  @override
  String get enum_siteField_lastDived_short => 'Utolsó';

  @override
  String get enum_siteField_maxDepthReached => 'Saját max. mélység';

  @override
  String get enum_siteField_maxDepthReached_short => 'Saját max.';

  @override
  String get enum_buddyField_buddyName => 'Név';

  @override
  String get enum_buddyField_email => 'E-mail';

  @override
  String get enum_buddyField_phone => 'Telefon';

  @override
  String get enum_buddyField_certificationLevel => 'Képesítési szint';

  @override
  String get enum_buddyField_certificationAgency => 'Képesítő szervezet';

  @override
  String get enum_buddyField_diveCount => 'Merülésszám';

  @override
  String get enum_buddyField_notes => 'Jegyzetek';

  @override
  String get enum_buddyField_buddyName_short => 'Név';

  @override
  String get enum_buddyField_email_short => 'E-mail';

  @override
  String get enum_buddyField_phone_short => 'Tel.';

  @override
  String get enum_buddyField_certificationLevel_short => 'Kép. szint';

  @override
  String get enum_buddyField_certificationAgency_short => 'Szerv.';

  @override
  String get enum_buddyField_diveCount_short => 'Mer.';

  @override
  String get enum_buddyField_notes_short => 'Jegyz.';

  @override
  String get enum_buddyField_lastDive => 'Utolsó merülés';

  @override
  String get enum_buddyField_lastDive_short => 'Utolsó';

  @override
  String get enum_tripField_tripName => 'Név';

  @override
  String get enum_tripField_startDate => 'Kezdés dátuma';

  @override
  String get enum_tripField_endDate => 'Befejezés dátuma';

  @override
  String get enum_tripField_durationDays => 'Időtartam';

  @override
  String get enum_tripField_location => 'Helyszín';

  @override
  String get enum_tripField_tripType => 'Utazás típusa';

  @override
  String get enum_tripField_resortName => 'Üdülőhely';

  @override
  String get enum_tripField_liveaboardName => 'Hajószállás';

  @override
  String get enum_tripField_diveCount => 'Merülésszám';

  @override
  String get enum_tripField_totalRuntime => 'Összes futásidő';

  @override
  String get enum_tripField_maxDepth => 'Max mélység';

  @override
  String get enum_tripField_avgDepth => 'Átlagos mélység';

  @override
  String get enum_tripField_notes => 'Jegyzetek';

  @override
  String get enum_tripField_tripName_short => 'Név';

  @override
  String get enum_tripField_startDate_short => 'Kezdés';

  @override
  String get enum_tripField_endDate_short => 'Vége';

  @override
  String get enum_tripField_durationDays_short => 'Nap';

  @override
  String get enum_tripField_location_short => 'Hely';

  @override
  String get enum_tripField_tripType_short => 'Típus';

  @override
  String get enum_tripField_resortName_short => 'Üdülő';

  @override
  String get enum_tripField_liveaboardName_short => 'Hajó';

  @override
  String get enum_tripField_diveCount_short => 'Mer.';

  @override
  String get enum_tripField_totalRuntime_short => 'Össz fut.';

  @override
  String get enum_tripField_maxDepth_short => 'Max mély';

  @override
  String get enum_tripField_avgDepth_short => 'Átl mély';

  @override
  String get enum_tripField_notes_short => 'Jegyz.';

  @override
  String get enum_equipmentField_itemName => 'Név';

  @override
  String get enum_equipmentField_fullName => 'Teljes név';

  @override
  String get enum_equipmentField_type => 'Típus';

  @override
  String get enum_equipmentField_brand => 'Márka';

  @override
  String get enum_equipmentField_model => 'Modell';

  @override
  String get enum_equipmentField_serialNumber => 'Sorozatszám';

  @override
  String get enum_equipmentField_size => 'Méret';

  @override
  String get enum_equipmentField_status => 'Állapot';

  @override
  String get enum_equipmentField_isActive => 'Aktív';

  @override
  String get enum_equipmentField_purchaseDate => 'Vásárlás dátuma';

  @override
  String get enum_equipmentField_purchasePrice => 'Vásárlási ár';

  @override
  String get enum_equipmentField_lastServiceDate => 'Utolsó szerviz';

  @override
  String get enum_equipmentField_nextServiceDue => 'Következő szerviz';

  @override
  String get enum_equipmentField_daysUntilService => 'Napok a szervizig';

  @override
  String get enum_equipmentField_serviceIntervalDays => 'Szerviz intervallum';

  @override
  String get enum_equipmentField_notes => 'Jegyzetek';

  @override
  String get enum_equipmentField_itemName_short => 'Név';

  @override
  String get enum_equipmentField_fullName_short => 'Teljes név';

  @override
  String get enum_equipmentField_type_short => 'Típus';

  @override
  String get enum_equipmentField_brand_short => 'Márka';

  @override
  String get enum_equipmentField_model_short => 'Modell';

  @override
  String get enum_equipmentField_serialNumber_short => 'Sorozat #';

  @override
  String get enum_equipmentField_size_short => 'Méret';

  @override
  String get enum_equipmentField_status_short => 'Állapot';

  @override
  String get enum_equipmentField_isActive_short => 'Aktív';

  @override
  String get enum_equipmentField_purchaseDate_short => 'Vásárolt';

  @override
  String get enum_equipmentField_purchasePrice_short => 'Ár';

  @override
  String get enum_equipmentField_lastServiceDate_short => 'Szervizelt';

  @override
  String get enum_equipmentField_nextServiceDue_short => 'Köv. szerv';

  @override
  String get enum_equipmentField_daysUntilService_short => 'Hátra nap';

  @override
  String get enum_equipmentField_serviceIntervalDays_short => 'Interv.';

  @override
  String get enum_equipmentField_notes_short => 'Jegyz.';

  @override
  String get enum_diveCenterField_centerName => 'Név';

  @override
  String get enum_diveCenterField_city => 'Város';

  @override
  String get enum_diveCenterField_country => 'Ország';

  @override
  String get enum_diveCenterField_stateProvince => 'Állam / megye';

  @override
  String get enum_diveCenterField_street => 'Utca';

  @override
  String get enum_diveCenterField_postalCode => 'Irányítószám';

  @override
  String get enum_diveCenterField_phone => 'Telefon';

  @override
  String get enum_diveCenterField_email => 'E-mail';

  @override
  String get enum_diveCenterField_website => 'Weboldal';

  @override
  String get enum_diveCenterField_affiliations => 'Tagságok';

  @override
  String get enum_diveCenterField_rating => 'Értékelés';

  @override
  String get enum_diveCenterField_latitude => 'Szélesség';

  @override
  String get enum_diveCenterField_longitude => 'Hosszúság';

  @override
  String get enum_diveCenterField_diveCount => 'Merülésszám';

  @override
  String get enum_diveCenterField_notes => 'Jegyzetek';

  @override
  String get enum_diveCenterField_centerName_short => 'Név';

  @override
  String get enum_diveCenterField_city_short => 'Város';

  @override
  String get enum_diveCenterField_country_short => 'Ország';

  @override
  String get enum_diveCenterField_stateProvince_short => 'Állam';

  @override
  String get enum_diveCenterField_street_short => 'Utca';

  @override
  String get enum_diveCenterField_postalCode_short => 'Irsz.';

  @override
  String get enum_diveCenterField_phone_short => 'Tel.';

  @override
  String get enum_diveCenterField_email_short => 'E-mail';

  @override
  String get enum_diveCenterField_website_short => 'Web';

  @override
  String get enum_diveCenterField_affiliations_short => 'Tagságok';

  @override
  String get enum_diveCenterField_rating_short => 'Ért.';

  @override
  String get enum_diveCenterField_latitude_short => 'Lat';

  @override
  String get enum_diveCenterField_longitude_short => 'Hossz';

  @override
  String get enum_diveCenterField_diveCount_short => 'Mer.';

  @override
  String get enum_diveCenterField_notes_short => 'Jegyz.';

  @override
  String get enum_certificationField_certName => 'Név';

  @override
  String get enum_certificationField_agency => 'Szervezet';

  @override
  String get enum_certificationField_level => 'Képesítés';

  @override
  String get enum_certificationField_cardNumber => 'Kártyaszám';

  @override
  String get enum_certificationField_issueDate => 'Kiadás dátuma';

  @override
  String get enum_certificationField_expiryDate => 'Lejárat dátuma';

  @override
  String get enum_certificationField_instructorName => 'Oktató neve';

  @override
  String get enum_certificationField_instructorNumber => 'Oktató száma';

  @override
  String get enum_certificationField_expiryStatus => 'Érvényesség';

  @override
  String get enum_certificationField_notes => 'Jegyzetek';

  @override
  String get enum_certificationField_certName_short => 'Név';

  @override
  String get enum_certificationField_agency_short => 'Szerv.';

  @override
  String get enum_certificationField_level_short => 'Képesítés';

  @override
  String get enum_certificationField_cardNumber_short => 'Kártya #';

  @override
  String get enum_certificationField_issueDate_short => 'Kiadva';

  @override
  String get enum_certificationField_expiryDate_short => 'Lejár';

  @override
  String get enum_certificationField_instructorName_short => 'Oktató';

  @override
  String get enum_certificationField_instructorNumber_short => 'Oktató #';

  @override
  String get enum_certificationField_expiryStatus_short => 'Állapot';

  @override
  String get enum_certificationField_notes_short => 'Jegyz.';

  @override
  String get enum_courseField_courseName => 'Név';

  @override
  String get enum_courseField_agency => 'Szervezet';

  @override
  String get enum_courseField_startDate => 'Kezdés dátuma';

  @override
  String get enum_courseField_completionDate => 'Befejezés dátuma';

  @override
  String get enum_courseField_durationDays => 'Időtartam';

  @override
  String get enum_courseField_instructorName => 'Oktató neve';

  @override
  String get enum_courseField_instructorNumber => 'Oktató száma';

  @override
  String get enum_courseField_location => 'Helyszín';

  @override
  String get enum_courseField_isCompleted => 'Befejezve';

  @override
  String get enum_courseField_notes => 'Jegyzetek';

  @override
  String get enum_courseField_courseName_short => 'Név';

  @override
  String get enum_courseField_agency_short => 'Szerv.';

  @override
  String get enum_courseField_startDate_short => 'Kezdve';

  @override
  String get enum_courseField_completionDate_short => 'Befejezve';

  @override
  String get enum_courseField_durationDays_short => 'Időtart.';

  @override
  String get enum_courseField_instructorName_short => 'Oktató';

  @override
  String get enum_courseField_instructorNumber_short => 'Oktató #';

  @override
  String get enum_courseField_location_short => 'Hely';

  @override
  String get enum_courseField_isCompleted_short => 'Kész';

  @override
  String get enum_courseField_notes_short => 'Jegyz.';

  @override
  String get enum_fieldCategory_accommodation => 'Szállás';

  @override
  String get enum_fieldCategory_address => 'Cím';

  @override
  String get enum_fieldCategory_certification => 'Képesítés';

  @override
  String get enum_fieldCategory_conditions => 'Körülmények';

  @override
  String get enum_fieldCategory_contact => 'Kapcsolat';

  @override
  String get enum_fieldCategory_coordinates => 'Koordináták';

  @override
  String get enum_fieldCategory_dates => 'Dátumok';

  @override
  String get enum_fieldCategory_depth => 'Mélység';

  @override
  String get enum_fieldCategory_details => 'Részletek';

  @override
  String get enum_fieldCategory_instructor => 'Oktató';

  @override
  String get enum_fieldCategory_other => 'Egyéb';

  @override
  String get enum_fieldCategory_purchase => 'Vásárlás';

  @override
  String get enum_fieldCategory_service => 'Szerviz';

  @override
  String get enum_fieldCategory_statistics => 'Statisztikák';

  @override
  String get species_whale_shark_name => 'Cetcápa';

  @override
  String get species_whale_shark_desc =>
      'Az óceán legnagyobb hala, békés planktonszűrő, jellegzetes pettyes mintázattal.';

  @override
  String get species_great_white_shark_name => 'Nagy fehércápa';

  @override
  String get species_great_white_shark_desc =>
      'Ikonikus csúcsragadozó, amelyet mérsékelt övi vizekben olykor ketrecből merülők látnak.';

  @override
  String get species_great_hammerhead_shark_name => 'Nagy pörölycápa';

  @override
  String get species_great_hammerhead_shark_desc =>
      'A legnagyobb pörölycápafaj, széles, lapos fejjel és magas hátúszóval.';

  @override
  String get species_scalloped_hammerhead_shark_name => 'Csipkés pörölycápa';

  @override
  String get species_scalloped_hammerhead_shark_desc =>
      'Gyakran látható nagy rajokban tenger alatti hegyek és tisztogatóállomások körül.';

  @override
  String get species_smooth_hammerhead_shark_name => 'Sima pörölycápa';

  @override
  String get species_smooth_hammerhead_shark_desc =>
      'Sima, lekerekített fejszegélyű pörölycápa, amely mérsékelt övi tengerekben él.';

  @override
  String get species_whitetip_reef_shark_name => 'Fehérfoltú zátonycápa';

  @override
  String get species_whitetip_reef_shark_desc =>
      'Szelíd zátonylakó, amely nappal gyakran barlangokban és sziklapárkányok alatt pihen.';

  @override
  String get species_blacktip_reef_shark_name => 'Feketeúszójú zátonycápa';

  @override
  String get species_blacktip_reef_shark_desc =>
      'Gyakori sekélyvízi zátonycápa, jellegzetes fekete úszóvégekkel.';

  @override
  String get species_grey_reef_shark_name => 'Szürke zátonycápa';

  @override
  String get species_grey_reef_shark_desc =>
      'Aktív zátonyi ragadozó, amellyel gyakran csoportosan találkozni a letöréseknél és csatornákban.';

  @override
  String get species_caribbean_reef_shark_name => 'Karibi zátonycápa';

  @override
  String get species_caribbean_reef_shark_desc =>
      'A Karib-tenger leggyakrabban látott zátonycápája, zömök testű és kíváncsi természetű.';

  @override
  String get species_nurse_shark_name => 'Dajkacápa';

  @override
  String get species_nurse_shark_desc =>
      'Lassú mozgású fenéklakó, amely gyakran korallpárkányok alatt pihen.';

  @override
  String get species_tawny_nurse_shark_name => 'Barna dajkacápa';

  @override
  String get species_tawny_nurse_shark_desc =>
      'Indo-csendes-óceáni fenéklakó, amely zátonybarlangokban és homokos területeken pihen.';

  @override
  String get species_bull_shark_name => 'Bikacápa';

  @override
  String get species_bull_shark_desc =>
      'Zömök, erőteljes cápa, amely világszerte part menti és édesvízi élőhelyeken is előfordul.';

  @override
  String get species_tiger_shark_name => 'Tigriscápa';

  @override
  String get species_tiger_shark_desc =>
      'Nagy testű ragadozó jellegzetes csíkos mintázattal, mély zátonymerüléseken találkozni vele.';

  @override
  String get species_oceanic_whitetip_shark_name => 'Fehérfoltú óceáni cápa';

  @override
  String get species_oceanic_whitetip_shark_desc =>
      'Nyíltvízi cápa lekerekített, fehér végű úszókkal, nyílt óceáni merüléseken látható.';

  @override
  String get species_thresher_shark_name => 'Rókacápa';

  @override
  String get species_thresher_shark_desc =>
      'Rendkívül hosszú farokúszójáról ismerhető fel, olykor tisztogatóállomásoknál bukkan fel.';

  @override
  String get species_pelagic_thresher_shark_name => 'Nyíltvízi rókacápa';

  @override
  String get species_pelagic_thresher_shark_desc =>
      'A legkisebb rókacápafaj, leghíresebben a Fülöp-szigeteki Monad Shoalnál figyelhető meg.';

  @override
  String get species_shortfin_mako_shark_name => 'Rövidúszójú makócápa';

  @override
  String get species_shortfin_mako_shark_desc =>
      'Az óceán leggyorsabb cápája, áramvonalas nyíltvízi ragadozó fémesen kék színnel.';

  @override
  String get species_blue_shark_name => 'Kékcápa';

  @override
  String get species_blue_shark_desc =>
      'Karcsú, mélykék nyíltvízi cápa, amellyel gyakran kékvízi merüléseken találkozni.';

  @override
  String get species_spotted_wobbegong_name => 'Foltos szőnyegcápa';

  @override
  String get species_spotted_wobbegong_desc =>
      'Lapos, rejtőszínű szőnyegcápa, amely mozdulatlanul fekszik Ausztrália sziklás zátonyain.';

  @override
  String get species_tasselled_wobbegong_name => 'Rojtos szőnyegcápa';

  @override
  String get species_tasselled_wobbegong_desc =>
      'Díszes szőnyegcápa a feje körül rojtos bőrlebenyekkel, korallzátonyokon él.';

  @override
  String get species_epaulette_shark_name => 'Vállfoltos cápa';

  @override
  String get species_epaulette_shark_desc =>
      'Kis termetű cápa, amely mellúszóival lépegetve halad a zátony alján.';

  @override
  String get species_horn_shark_name => 'Szarvascápa';

  @override
  String get species_horn_shark_desc =>
      'Éjszakai fenéklakó a szeme fölött futó tarajokkal, Kalifornia partjainál él.';

  @override
  String get species_leopard_shark_name => 'Leopárdcápa';

  @override
  String get species_leopard_shark_desc =>
      'Gyönyörű mintázatú cápa az Egyesült Államok csendes-óceáni partjainak sekély öbleiben.';

  @override
  String get species_pacific_angel_shark_name => 'Csendes-óceáni angyalcápa';

  @override
  String get species_pacific_angel_shark_desc =>
      'Lapos testű leshelyről támadó ragadozó, amely a tengerfenék homokjába ásva rejtőzik.';

  @override
  String get species_sand_tiger_shark_name => 'Homoki tigriscápa';

  @override
  String get species_sand_tiger_shark_desc =>
      'Ijesztő külsejű, de szelíd cápa, amely gyakran lebeg barlangokban és hajóroncsokban.';

  @override
  String get species_zebra_shark_name => 'Zebracápa';

  @override
  String get species_zebra_shark_desc =>
      'Pettyes zátonycápa, amely homokos aljzaton pihen, az Indo-csendes-óceánon gyakori.';

  @override
  String get species_blacktip_shark_name => 'Feketeúszójú cápa';

  @override
  String get species_blacktip_shark_desc =>
      'Gyors part menti cápa, amely pörgő ugrásairól ismert, világszerte meleg vizekben él.';

  @override
  String get species_silvertip_shark_name => 'Ezüstcsúcsú cápa';

  @override
  String get species_silvertip_shark_desc =>
      'Magabiztos zátonycápa fehér szegélyű úszókkal, mély letöréseknél és atolloknál él.';

  @override
  String get species_silky_shark_name => 'Selyemcápa';

  @override
  String get species_silky_shark_desc =>
      'Áramvonalas nyíltvízi cápa sima bőrrel, gyakran part menti zátonyok közelében.';

  @override
  String get species_lemon_shark_name => 'Citromcápa';

  @override
  String get species_lemon_shark_desc =>
      'Sárgásbarna cápa, amelyet gyakran látni sekély mangrovékban és homokpadokon.';

  @override
  String get species_galapagos_shark_name => 'Galápagosi cápa';

  @override
  String get species_galapagos_shark_desc =>
      'Nagy testű zátonycápa óceáni szigetek körül, a búvárok iránt érdeklődő természetű.';

  @override
  String get species_port_jackson_shark_name => 'Port Jackson-cápa';

  @override
  String get species_port_jackson_shark_desc =>
      'Éjszakai fenéklakó hámszerű rajzolattal, Ausztrália endemikus faja.';

  @override
  String get species_bamboo_shark_name => 'Barnasávos bambuszcápa';

  @override
  String get species_bamboo_shark_desc =>
      'Kis termetű, szelíd fenéklakó cápa, gyakori az Indo-csendes-óceán korallzátonyain.';

  @override
  String get species_basking_shark_name => 'Óriáscápa';

  @override
  String get species_basking_shark_desc =>
      'A második legnagyobb hal, planktonszűrő faj, mérsékelt övi felszíni vizekben látható.';

  @override
  String get species_greenland_shark_name => 'Grönlandi cápa';

  @override
  String get species_greenland_shark_desc =>
      'Lassú mozgású mélyvízi cápa, a Föld egyik leghosszabb életű gerince.';

  @override
  String get species_cookiecutter_shark_name => 'Szivarcápa';

  @override
  String get species_cookiecutter_shark_desc =>
      'Kis mélyvízi cápa, amely kör alakú harapásokat vág ki nagyobb tengeri állatokból.';

  @override
  String get species_sevengill_shark_name => 'Széles orrú hétkopoltyús cápa';

  @override
  String get species_sevengill_shark_desc =>
      'Ősi felépítésű cápa hét kopoltyúréssel, mérsékelt övi moszaterdei merüléseken látható.';

  @override
  String get species_pyjama_shark_name => 'Pizsamacápa';

  @override
  String get species_pyjama_shark_desc =>
      'Dél-afrikai endemikus csíkos macskacápa, sziklás zátonyokon és moszaterdőkben él.';

  @override
  String get species_spiny_dogfish_name => 'Tüskéscápa';

  @override
  String get species_spiny_dogfish_desc =>
      'Kis termetű, nagy számban előforduló cápa mérgező hátúszótüskékkel, mérsékelt övi vizekben.';

  @override
  String get species_swell_shark_name => 'Duzzadó macskacápa';

  @override
  String get species_swell_shark_desc =>
      'Éjszakai macskacápa, amely veszély esetén felfújja testét, Kalifornia partjainál él.';

  @override
  String get species_giant_oceanic_manta_ray_name => 'Óriás óceáni manta';

  @override
  String get species_giant_oceanic_manta_ray_desc =>
      'A legnagyobb rájafaj, fenséges planktonszűrő akár 7 méteres szárnyfesztávval.';

  @override
  String get species_reef_manta_ray_name => 'Zátonymanta';

  @override
  String get species_reef_manta_ray_desc =>
      'Kisebb mantafaj, amelyet gyakran látni trópusi zátonyok tisztogatóállomásain.';

  @override
  String get species_spotted_eagle_ray_name => 'Foltos sasrája';

  @override
  String get species_spotted_eagle_ray_desc =>
      'Elegáns rája fehér pettyekkel és hosszú, ostorszerű farokkal, gyakran a középvízben úszik.';

  @override
  String get species_common_eagle_ray_name => 'Közönséges sasrája';

  @override
  String get species_common_eagle_ray_desc =>
      'Rombusz alakú rája a mérsékelt övi kelet-atlanti és földközi-tengeri vizekben.';

  @override
  String get species_blue_spotted_ribbontail_ray_name =>
      'Kékfoltos szalagfarkú rája';

  @override
  String get species_blue_spotted_ribbontail_ray_desc =>
      'Élénk színű rája ragyogó kék pettyekkel, gyakori az Indo-csendes-óceán zátonyain.';

  @override
  String get species_blue_spotted_stingray_name => 'Kékfoltos tüskésrája';

  @override
  String get species_blue_spotted_stingray_desc =>
      'Kis zátonyi tüskésrája szórt kék pettyekkel, gyakran homokfoltokba ásva rejtőzik.';

  @override
  String get species_southern_stingray_name => 'Déli tüskésrája';

  @override
  String get species_southern_stingray_desc =>
      'Nagy testű tüskésrája a karibi homokpadokon, a Stingray City híres lakója.';

  @override
  String get species_round_stingray_name => 'Kerek tüskésrája';

  @override
  String get species_round_stingray_desc =>
      'Kis, kör alakú tüskésrája, gyakori a Csendes-óceán keleti részének sekély homokos területein.';

  @override
  String get species_short_tail_stingray_name => 'Rövidfarkú tüskésrája';

  @override
  String get species_short_tail_stingray_desc =>
      'Az egyik legnagyobb tüskésrája, a déli félteke mérsékelt övi vizeiben él.';

  @override
  String get species_cowtail_stingray_name => 'Tehénfarkú tüskésrája';

  @override
  String get species_cowtail_stingray_desc =>
      'Nagy, sötét tüskésrája jellegzetes zászlószerű farokredővel, homokos zátonyokon él.';

  @override
  String get species_atlantic_torpedo_ray_name => 'Atlanti zsibbasztórája';

  @override
  String get species_atlantic_torpedo_ray_desc =>
      'Erős áramütésre képes elektromos rája az Atlanti-óceán homokos fenekén.';

  @override
  String get species_marbled_electric_ray_name => 'Márványos zsibbasztórája';

  @override
  String get species_marbled_electric_ray_desc =>
      'Márványos mintázatú földközi-tengeri elektromos rája, amely érezhető áramütést ad le.';

  @override
  String get species_giant_guitarfish_name => 'Óriás gitárrája';

  @override
  String get species_giant_guitarfish_desc =>
      'Cápa alakú rája az Indo-csendes-óceán korallzátonyai melletti homokos fenéken.';

  @override
  String get species_shovelnose_guitarfish_name => 'Lapátorrú gitárrája';

  @override
  String get species_shovelnose_guitarfish_desc =>
      'Lapított, félig cápa, félig rája alakú hal, gyakori a Csendes-óceán keleti sekély homokjában.';

  @override
  String get species_smalltooth_sawfish_name => 'Kisfogú fűrészhal';

  @override
  String get species_smalltooth_sawfish_desc =>
      'Súlyosan veszélyeztetett rája fogazott orrnyúlvánnyal, trópusi part menti vizekben él.';

  @override
  String get species_green_sawfish_name => 'Zöld fűrészhal';

  @override
  String get species_green_sawfish_desc =>
      'Nagy testű fűrészhal olívzöld testtel, az Indo-nyugat-csendes-óceáni torkolatok lakója.';

  @override
  String get species_devil_ray_name => 'Óriás ördögrája';

  @override
  String get species_devil_ray_desc =>
      'Nagy mobula rája fejlebenyekkel, amelyet csoportosan látni kiugrani a vízből.';

  @override
  String get species_spinetail_devil_ray_name => 'Tüskésfarkú ördögrája';

  @override
  String get species_spinetail_devil_ray_desc =>
      'Nyíltvízi ördögrája, amely gyakran nagy csapatokban gyűlik össze a felszín közelében.';

  @override
  String get species_lesser_devil_ray_name => 'Törpe ördögrája';

  @override
  String get species_lesser_devil_ray_desc =>
      'A legkisebb mobula faj, amely nagy rajokat alkot a Kaliforniai-öbölben.';

  @override
  String get species_bat_ray_name => 'Denevérrája';

  @override
  String get species_bat_ray_desc =>
      'Rombusz alakú rája, gyakori Kalifornia moszaterdeiben és homokos öbleiben.';

  @override
  String get species_undulate_ray_name => 'Hullámos rája';

  @override
  String get species_undulate_ray_desc =>
      'Gyönyörű, hullámos vonalakkal mintázott rája az Atlanti-óceán keleti részén.';

  @override
  String get species_thornback_ray_name => 'Tüskés rája';

  @override
  String get species_thornback_ray_desc =>
      'Gyakori európai rája, hátán és farkán tövises tüskékkel.';

  @override
  String get species_cownose_ray_name => 'Tehénorrú rája';

  @override
  String get species_cownose_ray_desc =>
      'Jellegzetes bemetszett fejéről ismerhető fel, a szezonális vándorlások idején nagy rajokban látható.';

  @override
  String get species_marble_ray_name => 'Márványos tüskésrája';

  @override
  String get species_marble_ray_desc =>
      'Nagy, sötét tüskésrája fehér pettyekkel, gyakran látható indo-csendes-óceáni tisztogatóállomásokon.';

  @override
  String get species_ocellate_river_stingray_name => 'Szemfoltos folyami rája';

  @override
  String get species_ocellate_river_stingray_desc =>
      'Édesvízi tüskésrája feltűnő, narancssárga gyűrűs pettyekkel, dél-amerikai folyók őshonos faja.';

  @override
  String get species_ocellaris_clownfish_name => 'Közönséges bohóchal';

  @override
  String get species_ocellaris_clownfish_desc =>
      'Kis narancssárga-fehér csíkos hal, amely korallzátonyokon tengeri rózsákkal együtt élve fordul elő.';

  @override
  String get species_clarkii_clownfish_name => 'Clark-bohóchal';

  @override
  String get species_clarkii_clownfish_desc =>
      'Szívós bohóchal sötét testtel és két fehér sávval, az Indo-csendes-óceánon többféle tengeri rózsában él.';

  @override
  String get species_tomato_clownfish_name => 'Paradicsom bohóchal';

  @override
  String get species_tomato_clownfish_desc =>
      'Élénk vörösnarancs bohóchal egyetlen fehér fejsávval, gyakori az Indo-csendes-óceán zátonyain.';

  @override
  String get species_regal_blue_tang_name => 'Paletta doktorhal';

  @override
  String get species_regal_blue_tang_desc =>
      'Ragyogó kék doktorhal fekete palettarajzolattal és sárga farokkal, indo-csendes-óceáni korallzátonyokon él.';

  @override
  String get species_yellow_tang_name => 'Sárga doktorhal';

  @override
  String get species_yellow_tang_desc =>
      'Élénksárga doktorhal, gyakori a hawaii és csendes-óceáni zátonyokon, gyakran csoportosan legeli az algát.';

  @override
  String get species_powder_blue_surgeonfish_name => 'Világoskék doktorhal';

  @override
  String get species_powder_blue_surgeonfish_desc =>
      'Feltűnő halványkék doktorhal fekete arccal és sárga hátúszóval, az Indiai-óceánban él.';

  @override
  String get species_sohal_surgeonfish_name => 'Szohál doktorhal';

  @override
  String get species_sohal_surgeonfish_desc =>
      'Markáns csíkozású doktorhal narancssárga sziketüskével, a Vörös-tenger és az Arab-öböl zátonyainak endemikus faja.';

  @override
  String get species_blue_tang_name => 'Kék doktorhal';

  @override
  String get species_blue_tang_desc =>
      'Mélykék doktorhal, gyakori a karibi zátonyokon, a fiatal példányok élénksárgák.';

  @override
  String get species_emperor_angelfish_name => 'Császár-angyalhal';

  @override
  String get species_emperor_angelfish_desc =>
      'Nagy testű angyalhal feltűnő kék és sárga vízszintes csíkokkal. A fiatal példányokat koncentrikus kék-fehér körök díszítik.';

  @override
  String get species_french_angelfish_name => 'Francia angyalhal';

  @override
  String get species_french_angelfish_desc =>
      'Nagy, sötét angyalhal aranyszegélyű pikkelyekkel, karibi és nyugat-atlanti zátonyokon gyakran párban látható.';

  @override
  String get species_queen_angelfish_name => 'Királynő angyalhal';

  @override
  String get species_queen_angelfish_desc =>
      'Látványos kék-sárga angyalhal jellegzetes koronafolttal, karibi korallzátonyokon él.';

  @override
  String get species_regal_angelfish_name => 'Pompás angyalhal';

  @override
  String get species_regal_angelfish_desc =>
      'Elegáns angyalhal váltakozó narancs-fehér és kék függőleges sávokkal, indo-csendes-óceáni zátonyokon él.';

  @override
  String get species_rock_beauty_name => 'Háromszínű angyalhal';

  @override
  String get species_rock_beauty_desc =>
      'Feltűnő karibi angyalhal sárga elülső és fekete hátsó testfélével, sziklás zátonyok és párkányok közelében él.';

  @override
  String get species_gray_angelfish_name => 'Szürke angyalhal';

  @override
  String get species_gray_angelfish_desc =>
      'Nagy, szürke angyalhal halvány arccal és sárga mellúszóbelsővel, gyakori a karibi zátonyokon.';

  @override
  String get species_copperband_butterflyfish_name => 'Rézsávos pillangóhal';

  @override
  String get species_copperband_butterflyfish_desc =>
      'Jellegzetes pillangóhal narancssárga függőleges sávokkal és megnyúlt ormánnyal, indo-csendes-óceáni zátonyokon él.';

  @override
  String get species_raccoon_butterflyfish_name => 'Mosómedve-pillangóhal';

  @override
  String get species_raccoon_butterflyfish_desc =>
      'Sárga pillangóhal sötét, mosómedvére emlékeztető szemálarccal, gyakori az indo-csendes-óceáni és hawaii zátonyokon.';

  @override
  String get species_longnose_butterflyfish_name => 'Hosszúorrú pillangóhal';

  @override
  String get species_longnose_butterflyfish_desc =>
      'Élénksárga pillangóhal rendkívül hosszú ormánnyal, amellyel a repedésekből szedi ki táplálékát az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_threadfin_butterflyfish_name =>
      'Fonalasúszójú pillangóhal';

  @override
  String get species_threadfin_butterflyfish_desc =>
      'Fehér pillangóhal ékmintázattal és hátúszóból induló fonállal, az Indo-csendes-óceánon széles körben elterjedt.';

  @override
  String get species_foureye_butterflyfish_name => 'Négyszemű pillangóhal';

  @override
  String get species_foureye_butterflyfish_desc =>
      'Halvány pillangóhal feltűnő álszemfolttal a farok közelében, gyakori a karibi zátonyokon.';

  @override
  String get species_spotfin_butterflyfish_name => 'Foltosúszójú pillangóhal';

  @override
  String get species_spotfin_butterflyfish_desc =>
      'Fehér-sárga pillangóhal apró sötét folttal a hátúszón, a Nyugat-Atlanti-óceánban él.';

  @override
  String get species_banner_butterflyfish_name => 'Vörös-tengeri zászlóshal';

  @override
  String get species_banner_butterflyfish_desc =>
      'Fekete-fehér zászlóshal megnyúlt hátúszóval és sárga hassal, a Vörös-tenger endemikus faja.';

  @override
  String get species_moorish_idol_name => 'Mór bálványhal';

  @override
  String get species_moorish_idol_desc =>
      'Ikonikus zátonyi hal markáns fekete, fehér és sárga sávokkal, valamint hosszú, elnyúló hátúszófonállal.';

  @override
  String get species_green_moray_eel_name => 'Zöld muréna';

  @override
  String get species_green_moray_eel_desc =>
      'Nagy, 2,5 métert is elérő zöld muréna, amely a Nyugat-Atlanti-óceán zátonyrepedéseiben gyakran tátott szájjal figyel.';

  @override
  String get species_giant_moray_eel_name => 'Óriásmuréna';

  @override
  String get species_giant_moray_eel_desc =>
      'A legnagyobb murénafaj, több mint 3 méteres, leopárdszerű foltokkal. Az Indo-csendes-óceán korallzátonyain él.';

  @override
  String get species_spotted_moray_eel_name => 'Foltos muréna';

  @override
  String get species_spotted_moray_eel_desc =>
      'Fehér muréna sötétbarna pettyekkel, a Karib-tengeren gyakran kandikál ki a zátony üregeiből.';

  @override
  String get species_ribbon_eel_name => 'Szalagmuréna';

  @override
  String get species_ribbon_eel_desc =>
      'Karcsú muréna kiszélesedő orrnyílásokkal; a hímek élénkkékek, a nőstények sárgák. Indo-csendes-óceáni homokos lagúnákban él.';

  @override
  String get species_spotted_garden_eel_name => 'Foltos kertiangolna';

  @override
  String get species_spotted_garden_eel_desc =>
      'Vékony, fehér, fekete pettyes angolna, amely homokos telepekben él és az áramlatban hullámozva szűri ki a planktont.';

  @override
  String get species_splendid_garden_eel_name => 'Pompás kertiangolna';

  @override
  String get species_splendid_garden_eel_desc =>
      'Narancs-fehér sávos kertiangolna, amely nagy homokos telepeket alkot a Csendes-óceán nyugati részén.';

  @override
  String get species_snowflake_moray_name => 'Hópehely muréna';

  @override
  String get species_snowflake_moray_desc =>
      'Kis muréna fehér testtel és fekete, hópehelyszerű rajzolattal, gyakori az indo-csendes-óceáni zátonytörmelékben.';

  @override
  String get species_mandarin_dragonet_name => 'Mandarinhal';

  @override
  String get species_mandarin_dragonet_desc =>
      'Apró, ragyogó színű hal pszichedelikus kék és narancssárga mintázattal, a nyugat-csendes-óceáni törmelékzónákban él.';

  @override
  String get species_common_lionfish_name => 'Közönséges oroszlánhal';

  @override
  String get species_common_lionfish_desc =>
      'Mérgező skorpióhal látványos, legyezőszerű mellúszókkal és vörös-fehér csíkokkal. A Karib-tengeren invazív faj.';

  @override
  String get species_leaf_scorpionfish_name => 'Levél-skorpióhal';

  @override
  String get species_leaf_scorpionfish_desc =>
      'Erősen lapított, levél alakú skorpióhal, amely az áramlattal ringatózva utánozza a hordalékot az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_stonefish_name => 'Zátonyi kőhal';

  @override
  String get species_stonefish_desc =>
      'A világ legmérgezőbb hala, tökéletesen kőnek álcázva lapul az indo-csendes-óceáni zátonyok alján. Rendkívül veszélyes.';

  @override
  String get species_painted_frogfish_name => 'Festett békahal';

  @override
  String get species_painted_frogfish_desc =>
      'Zömök, leshelyről támadó ragadozó a fején csalétekkel, színe rendkívül változatos. Indo-csendes-óceáni zátonyokon él.';

  @override
  String get species_giant_frogfish_name => 'Óriás békahal';

  @override
  String get species_giant_frogfish_desc =>
      'A legnagyobb békahalfaj, 40 centiméteres, kiválóan álcázza magát szivacsok és korall törmelék között.';

  @override
  String get species_hairy_frogfish_name => 'Szőrös békahal';

  @override
  String get species_hairy_frogfish_desc =>
      'Féregszerű húsos nyúlványokkal borított békahal, amely algát utánoz, a víz alatti fotósok nagy kedvence.';

  @override
  String get species_clown_triggerfish_name => 'Bohóc-ravaszhal';

  @override
  String get species_clown_triggerfish_desc =>
      'Feltűnő mintázatú ravaszhal nagy fehér pettyekkel sötét testen és sárga ajakkal, indo-csendes-óceáni zátonyokon él.';

  @override
  String get species_titan_triggerfish_name => 'Titán ravaszhal';

  @override
  String get species_titan_triggerfish_desc =>
      'Nagy testű, agresszív ravaszhal, amely a fészke közelében a búvárokra is rátámad. Gyakori az Indo-csendes-óceán korallzátonyain.';

  @override
  String get species_queen_triggerfish_name => 'Királynő ravaszhal';

  @override
  String get species_queen_triggerfish_desc =>
      'Színpompás karibi ravaszhal kék arcrajzolattal és hosszú farokúszószálakkal.';

  @override
  String get species_picasso_triggerfish_name => 'Picasso-ravaszhal';

  @override
  String get species_picasso_triggerfish_desc =>
      'Ravaszhal absztrakt kék, sárga és fekete csíkmintázattal, gyakori az indo-csendes-óceáni zátonylapokon.';

  @override
  String get species_yellowmargin_triggerfish_name => 'Sárgaszegélyű ravaszhal';

  @override
  String get species_yellowmargin_triggerfish_desc =>
      'Nagy, homokszínű ravaszhal sárga szegélyű úszókkal, az indo-csendes-óceáni zátonyokon hevesen védi a fészkét.';

  @override
  String get species_porcupinefish_name => 'Sünhal';

  @override
  String get species_porcupinefish_desc =>
      'Nagy, tüskés hal, amely veszély esetén gömbbé fújja magát, világszerte trópusi zátonyokon él.';

  @override
  String get species_guineafowl_pufferfish_name => 'Gyöngytyúk gömbhal';

  @override
  String get species_guineafowl_pufferfish_desc =>
      'Sötét gömbhal apró fehér pettyekkel, az indo-csendes-óceáni zátonyokon néha aranysárga színváltozatban is előfordul.';

  @override
  String get species_map_pufferfish_name => 'Térképes gömbhal';

  @override
  String get species_map_pufferfish_desc =>
      'Nagy, halvány gömbhal bonyolult, térképszerű sötét rajzolattal, indo-csendes-óceáni zátonyokon él.';

  @override
  String get species_sharpnose_pufferfish_name => 'Hegyesorrú gömbhal';

  @override
  String get species_sharpnose_pufferfish_desc =>
      'Apró gömbhal kék vonalakkal az arcán és narancssárga farokkal, gyakran látható a karibi zátonyokon.';

  @override
  String get species_boxfish_name => 'Sárga ládahal';

  @override
  String get species_boxfish_desc =>
      'A fiatal példányok élénksárga, fekete pettyes kockák. A kifejlett halak kékesszürkére sötétednek. Az Indo-csendes-óceánon él.';

  @override
  String get species_cowfish_name => 'Hosszúszarvú tehénhal';

  @override
  String get species_cowfish_desc =>
      'Szögletes, sárga hal jellegzetes szarvszerű nyúlványokkal a szemei fölött, indo-csendes-óceáni zátonyokon él.';

  @override
  String get species_napoleon_wrasse_name => 'Napóleon-hal';

  @override
  String get species_napoleon_wrasse_desc =>
      'Hatalmas, 2 métert is elérő ajakoshal jellegzetes homlokdudorral. Veszélyeztetett és védett faj, indo-csendes-óceáni zátonyokon él.';

  @override
  String get species_cleaner_wrasse_name => 'Kékcsíkos tisztogatóhal';

  @override
  String get species_cleaner_wrasse_desc =>
      'Kis, kék csíkos ajakoshal, amely tisztogatóállomásokat működtet, és a nagyobb halakról szedi le az élősködőket az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_yellowtail_coris_name => 'Sárgafarkú ajakoshal';

  @override
  String get species_yellowtail_coris_desc =>
      'Színpompás ajakoshal pettyes testtel és sárga farokkal, a fiatal példányok élénk narancsvörösek fehér rajzolattal.';

  @override
  String get species_bluehead_wrasse_name => 'Kékfejű ajakoshal';

  @override
  String get species_bluehead_wrasse_desc =>
      'Gyakori karibi ajakoshal; a kifejlett hímek feje élénkkék, testük zöld fekete-fehér sávokkal.';

  @override
  String get species_spanish_hogfish_name => 'Spanyol disznóhal';

  @override
  String get species_spanish_hogfish_desc =>
      'Lila és sárga ajakoshal, gyakori a karibi zátonyokon; fiatal példányai tisztogatóhalként működnek.';

  @override
  String get species_bumphead_parrotfish_name => 'Búbos papagájhal';

  @override
  String get species_bumphead_parrotfish_desc =>
      'A legnagyobb papagájhalfaj, 1,3 méteres, hatalmas homlokdudorral. Az Indo-csendes-óceán zátonyain rajokban vonul.';

  @override
  String get species_stoplight_parrotfish_name => 'Jelzőlámpa papagájhal';

  @override
  String get species_stoplight_parrotfish_desc =>
      'Gyakori karibi papagájhal, amely látványosan színt vált a kezdeti és a végleges életszakasz között.';

  @override
  String get species_queen_parrotfish_name => 'Királynő papagájhal';

  @override
  String get species_queen_parrotfish_desc =>
      'Nagy, kékeszöld papagájhal a karibi zátonyokon, gyakran látni, ahogy a korallt harapdálva legeli az algát.';

  @override
  String get species_yellowtail_damselfish_name => 'Sárgafarkú korallhal';

  @override
  String get species_yellowtail_damselfish_desc =>
      'Sötétkék korallhal élénksárga farokkal, gyakori a karibi zátonytetőkön és zátonytarajokon.';

  @override
  String get species_sergeant_major_name => 'Őrmesterhal';

  @override
  String get species_sergeant_major_desc =>
      'Ezüstös-sárga korallhal öt markáns fekete sávval, nagy csapatokban él a trópusi atlanti zátonyokon.';

  @override
  String get species_three_spot_damselfish_name => 'Hármasfoltú korallhal';

  @override
  String get species_three_spot_damselfish_desc =>
      'Sötétbarna, territoriális korallhal, amely agresszíven védi algakertjét a karibi zátonyokon.';

  @override
  String get species_chromis_viridis_name => 'Kékeszöld chromis';

  @override
  String get species_chromis_viridis_desc =>
      'Kis, irizáló zöld korallhal, amely nagy rajokban lebeg az indo-csendes-óceáni zátonyok elágazó korallja fölött.';

  @override
  String get species_blue_chromis_name => 'Kék chromis';

  @override
  String get species_blue_chromis_desc =>
      'Ragyogó kék, planktonevő korallhal, amely nagy csapatokban gyűlik a karibi zátonyfalak fölé a középvízbe.';

  @override
  String get species_nassau_grouper_name => 'Nassaui sügér';

  @override
  String get species_nassau_grouper_desc =>
      'Nagy karibi sügér jellegzetes sötét szemsávval és sávos mintázattal, a túlhalászás miatt mára veszélyeztetett.';

  @override
  String get species_giant_grouper_name => 'Óriássügér';

  @override
  String get species_giant_grouper_desc =>
      'A legnagyobb csontos zátonyi hal, 2,7 métert és 400 kilogrammot is elér. Az Indo-csendes-óceán barlangjaiban és roncsain él.';

  @override
  String get species_coral_grouper_name => 'Korallsügér';

  @override
  String get species_coral_grouper_desc =>
      'Élénk vörösnarancs, kék pettyekkel borított sügér, az Indo-csendes-óceán korallzátonyainak jellegzetes faja.';

  @override
  String get species_goliath_grouper_name => 'Góliátsügér';

  @override
  String get species_goliath_grouper_desc =>
      'Hatalmas, 2,5 métert is elérő atlanti sügér, amellyel gyakran roncsok és sziklapárkányok közelében találkozni Floridában és a Karib-tengeren.';

  @override
  String get species_potato_grouper_name => 'Burgonyasügér';

  @override
  String get species_potato_grouper_desc =>
      'Nagy testű, barátságos sügér sötét, burgonya alakú foltokkal, a Nagy-korallzátony Cod Hole nevű helyszínének híres lakója.';

  @override
  String get species_peacock_grouper_name => 'Pávasügér';

  @override
  String get species_peacock_grouper_desc =>
      'Sötétbarna sügér élénkkék pettyekkel és halvány függőleges sávokkal a test hátulján, gyakori az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_yellowfin_tuna_name => 'Sárgaúszójú tonhal';

  @override
  String get species_yellowfin_tuna_desc =>
      'Gyors nyíltvízi ragadozó hosszú, sárga hát- és farok alatti úszóval, part menti helyszíneken olykor búvárok is látják.';

  @override
  String get species_dogtooth_tuna_name => 'Kutyafogú tonhal';

  @override
  String get species_dogtooth_tuna_desc =>
      'Erőteljes, zátonyokhoz kötődő tonhal feltűnő fogakkal, az Indo-csendes-óceán mély zátonyletöréseinél találkozni vele.';

  @override
  String get species_great_barracuda_name => 'Nagy barrakuda';

  @override
  String get species_great_barracuda_desc =>
      'Áramvonalas, akár 1,8 méteres ezüstös ragadozó feltűnő fogsorral, gyakran mozdulatlanul lebeg a trópusi zátonyok közelében.';

  @override
  String get species_blackfin_barracuda_name => 'Feketeúszójú barrakuda';

  @override
  String get species_blackfin_barracuda_desc =>
      'Indo-csendes-óceáni barrakuda, amely hatalmas, tornádószerű rajokat alkot olyan helyszíneken, mint a Barracuda Point.';

  @override
  String get species_mahi_mahi_name => 'Aranymakréla';

  @override
  String get species_mahi_mahi_desc =>
      'Káprázatos kékeszöld és arany nyíltvízi hal tompa homlokkal, olykor part menti merülőhelyeken is felbukkan.';

  @override
  String get species_giant_trevally_name => 'Óriás fattyúmakréla';

  @override
  String get species_giant_trevally_desc =>
      'Erőteljes, akár 1,7 méteres ezüstös ragadozó, amely az Indo-csendes-óceán zátonycsatornáiban és letöréseinél vadászik.';

  @override
  String get species_bluefin_trevally_name => 'Kékúszójú fattyúmakréla';

  @override
  String get species_bluefin_trevally_desc =>
      'Áramvonalas, kékpettyes fattyúmakréla, amely kis vadászcsoportokban járőrözik az indo-csendes-óceáni zátonyperemeken.';

  @override
  String get species_bigeye_trevally_name => 'Nagyszemű fattyúmakréla';

  @override
  String get species_bigeye_trevally_desc =>
      'Nagy szemű ezüstös fattyúmakréla, amely lenyűgöző, örvénylő rajokat alkot a zátonyfalak és tisztogatóállomások közelében.';

  @override
  String get species_bar_jack_name => 'Sávos fattyúmakréla';

  @override
  String get species_bar_jack_desc =>
      'Áramvonalas ezüstös karibi fattyúmakréla jellegzetes sötétkék sávval a háta mentén és a farok alsó lebenyén.';

  @override
  String get species_horse_eye_jack_name => 'Lószemű fattyúmakréla';

  @override
  String get species_horse_eye_jack_desc =>
      'Nagy szemű ezüstös fattyúmakréla, amely rajokat alkot a karibi és nyugat-atlanti zátonyok és roncsok közelében.';

  @override
  String get species_yellowtail_snapper_name => 'Sárgafarkú csattogóhal';

  @override
  String get species_yellowtail_snapper_desc =>
      'Áramvonalas csattogóhal sárga oldalsávval és farokkal, gyakran látható középvízi rajokban a karibi zátonyokon.';

  @override
  String get species_schoolmaster_snapper_name => 'Iskolamester csattogóhal';

  @override
  String get species_schoolmaster_snapper_desc =>
      'Sárgás-ezüstös csattogóhal kék vonalakkal a szeme alatt, csoportosan él a karibi zátonyok párkányai alatt.';

  @override
  String get species_bluestripe_snapper_name => 'Kékcsíkos csattogóhal';

  @override
  String get species_bluestripe_snapper_desc =>
      'Élénksárga csattogóhal négy kék vízszintes csíkkal, sűrű rajokat alkot az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_twinspot_snapper_name => 'Kétfoltos csattogóhal';

  @override
  String get species_twinspot_snapper_desc =>
      'Nagy, vörös csattogóhal az Indo-csendes-óceán külső zátonyain, olykor rajokat alkot a mély falaknál és csatornákban.';

  @override
  String get species_humphead_snapper_name => 'Éjféli csattogóhal';

  @override
  String get species_humphead_snapper_desc =>
      'Nagy, sötét csattogóhal, amely rajokban él a meredek indo-csendes-óceáni letöréseknél; a fiatal példányok markánsan fekete-fehérek.';

  @override
  String get species_longfin_bannerfish_name => 'Hosszúúszójú zászlóshal';

  @override
  String get species_longfin_bannerfish_desc =>
      'Fekete-fehér hal hosszú, elnyúló hátúszóval és sárga farokkal, az indo-csendes-óceáni zátonyokon gyakran párban látható.';

  @override
  String get species_batfish_orbicular_name => 'Kerek denevérhal';

  @override
  String get species_batfish_orbicular_desc =>
      'Ezüstös, korong alakú hal magas úszókkal, amely kíváncsian közelít a búvárokhoz. Gyakori az indo-csendes-óceáni roncsokon és zátonyokon.';

  @override
  String get species_batfish_teira_name => 'Hosszúúszójú denevérhal';

  @override
  String get species_batfish_teira_desc =>
      'Magas úszójú denevérhal sötét folttal a mellúszó közelében, gyakran látható tisztogatóállomásokon és roncsokon.';

  @override
  String get species_batfish_pinnatus_name => 'Szárnyas denevérhal';

  @override
  String get species_batfish_pinnatus_desc =>
      'A fiatal példányok koromfeketék, élénk narancssárga szegéllyel, egy mérgező laposféreghez hasonlóan. A Csendes-óceán nyugati részén él.';

  @override
  String get species_banggai_cardinalfish_name => 'Banggai kardinálishal';

  @override
  String get species_banggai_cardinalfish_desc =>
      'Feltűnő ezüst-fekete kardinálishal megnyúlt úszókkal, az indonéziai Banggai-szigetek endemikus faja.';

  @override
  String get species_pajama_cardinalfish_name => 'Pizsamás kardinálishal';

  @override
  String get species_pajama_cardinalfish_desc =>
      'Szokatlan kardinálishal sárga arccal, sötét derékpánttal és pettyes hátsó testfélével, az Indo-csendes-óceán korallja között él.';

  @override
  String get species_longnose_hawkfish_name => 'Hosszúorrú sólyomhal';

  @override
  String get species_longnose_hawkfish_desc =>
      'Kis fehér hal vörös rácsmintázattal és megnyúlt ormánnyal, amely gorgóniákon és feketekorallokon üldögél.';

  @override
  String get species_arc_eye_hawkfish_name => 'Ívesszemű sólyomhal';

  @override
  String get species_arc_eye_hawkfish_desc =>
      'Kis sólyomhal jellegzetes narancssárga ívvel a szeme mögött, gyakran korallfejeken pihen az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_flame_hawkfish_name => 'Lángvörös sólyomhal';

  @override
  String get species_flame_hawkfish_desc =>
      'Ragyogó vörös sólyomhal sötét szemrajzolattal, a Csendes-óceán nyugati részén Pocillopora korallokon üldögél.';

  @override
  String get species_fire_goby_name => 'Tűzgéb';

  @override
  String get species_fire_goby_desc =>
      'Elegáns fehér géb magas első hátúszóval és vörösnarancs farokkal, az indo-csendes-óceáni zátonytörmelék fölött lebeg.';

  @override
  String get species_purple_firefish_name => 'Lila tűzgéb';

  @override
  String get species_purple_firefish_desc =>
      'Finom testű géb lila úszókkal és magas hátúszótüskével, az indo-csendes-óceáni külső zátonyokon üregei közelében lebeg.';

  @override
  String get species_yellownose_goby_name => 'Sárgaorrú géb';

  @override
  String get species_yellownose_goby_desc =>
      'Apró karibi tisztogató géb sárga ormánnyal és kék oldalsávval, szivacsokon és korallfejeken él.';

  @override
  String get species_citron_goby_name => 'Citromgéb';

  @override
  String get species_citron_goby_desc =>
      'Apró, élénksárga géb, amely az indo-csendes-óceáni zátonyok Acropora korallágai között él.';

  @override
  String get species_shrimp_goby_name => 'Steinitz-garnélagéb';

  @override
  String get species_shrimp_goby_desc =>
      'Homokszínű géb, amely az indo-csendes-óceáni homokpadokon kölcsönösen előnyös kapcsolatban osztozik üregén egy Alpheus garnélával.';

  @override
  String get species_neon_goby_name => 'Neongéb';

  @override
  String get species_neon_goby_desc =>
      'Apró, sötét géb ragyogó neonkék sávval, tisztogatóállomásokat működtet a karibi korallfejeken.';

  @override
  String get species_bluestriped_fangblenny_name =>
      'Kékcsíkos agyaras nyálkáshal';

  @override
  String get species_bluestriped_fangblenny_desc =>
      'Kis, kék csíkos nyálkáshal, amely a tisztogatóhalakat utánozva harap ki pikkelyeket a gyanútlan halakból.';

  @override
  String get species_sailfin_blenny_name => 'Vitorlás nyálkáshal';

  @override
  String get species_sailfin_blenny_desc =>
      'Apró karibi nyálkáshal, amely csőotthonából kiemelkedve nagy, vitorlaszerű hátúszóval csalogatja a párját.';

  @override
  String get species_bicolor_blenny_name => 'Kétszínű nyálkáshal';

  @override
  String get species_bicolor_blenny_desc =>
      'Kis nyálkáshal sötétbarna elülső és narancssárga hátsó testfélével, az indo-csendes-óceáni zátonyok üregeiből kandikál ki.';

  @override
  String get species_redlip_blenny_name => 'Vörösajkú nyálkáshal';

  @override
  String get species_redlip_blenny_desc =>
      'Sötét nyálkáshal feltűnő vörösnarancs ajakkal, amely algafoltjait védi a karibi zátonytarajokon.';

  @override
  String get species_pygmy_seahorse_name => 'Bargibant-törpecsikóhal';

  @override
  String get species_pygmy_seahorse_desc =>
      'Két centiméternél is kisebb csikóhal, amely tökéletesen illeszkedik gazdanövényéhez, a gorgóniakorallhoz, a makrofotósok kedvelt célpontja.';

  @override
  String get species_common_seahorse_name => 'Közönséges csikóhal';

  @override
  String get species_common_seahorse_desc =>
      'Közepes méretű csikóhal, amely tengerifűmezőkben és korall törmelékben él az Indo-csendes-óceánon, színe változatos.';

  @override
  String get species_thorny_seahorse_name => 'Tüskés csikóhal';

  @override
  String get species_thorny_seahorse_desc =>
      'Hosszú tüskékkel borított csikóhal, amely tengerifűmezőkben és puha aljzatú élőhelyeken él az Indo-csendes-óceánon.';

  @override
  String get species_ornate_ghost_pipefish_name => 'Díszes szellemtűhal';

  @override
  String get species_ornate_ghost_pipefish_desc =>
      'Kifinomultan álcázott tűhal, amely fejjel lefelé lebeg a tengerililiomok és lágykorallok mellett az Indo-csendes-óceánon.';

  @override
  String get species_robust_ghost_pipefish_name => 'Robusztus szellemtűhal';

  @override
  String get species_robust_ghost_pipefish_desc =>
      'Nagy termetű szellemtűhal, amely tengerifüvet vagy algát utánoz, az indo-csendes-óceáni part menti vizekben gyakran párban látható.';

  @override
  String get species_trumpetfish_name => 'Trombitahal';

  @override
  String get species_trumpetfish_desc =>
      'Hosszú, karcsú hal, amely nagyobb halak árnyékában vadászik, a karibi és atlanti zátonyokon többféle színben fordul elő.';

  @override
  String get species_cornetfish_name => 'Síposhal';

  @override
  String get species_cornetfish_desc =>
      'Rendkívül megnyúlt, akár 1,5 méteres hal farokszállal a végén, gyakran siklik a zátonylapok fölött.';

  @override
  String get species_yellowhead_jawfish_name => 'Sárgafejű állkapocshal';

  @override
  String get species_yellowhead_jawfish_desc =>
      'Kis, kék testű, sárga fejű hal, amely homokjárata fölött lebeg a karibi zátonyokon. A hímek a szájukban keltetik az ikrákat.';

  @override
  String get species_flamefish_name => 'Lángvörös kardinálishal';

  @override
  String get species_flamefish_desc =>
      'Kis, élénkvörös kardinálishal sötét folttal a második hátúszó alatt, nappal a karibi zátonyrepedésekben rejtőzik.';

  @override
  String get species_longspine_squirrelfish_name => 'Hosszútüskéjű mókushal';

  @override
  String get species_longspine_squirrelfish_desc =>
      'Vörös, éjszakai hal nagy szemekkel és hosszú hátúszótüskével, nappal a karibi zátonyok párkányai alatt tartózkodik.';

  @override
  String get species_soldierfish_name => 'Nagypikkelyű katonahal';

  @override
  String get species_soldierfish_desc =>
      'Vörös, éjszakai hal hatalmas sötét szemekkel és nagy pikkelyekkel, nappal csoportokban áll a barlangokban és túlnyúlások alatt.';

  @override
  String get species_flame_angelfish_name => 'Lángangyalhal';

  @override
  String get species_flame_angelfish_desc =>
      'Ragyogó vörösnarancs törpe angyalhal fekete függőleges sávokkal és kék úszóvégekkel, a Csendes-óceánon él.';

  @override
  String get species_royal_gramma_name => 'Királyi gramma';

  @override
  String get species_royal_gramma_desc =>
      'Kis, kétszínű karibi hal lila elülső és sárga hátsó testfélével, a sziklapárkányok alatt él.';

  @override
  String get species_anthias_lyretail_name => 'Lantfarkú anthiász';

  @override
  String get species_anthias_lyretail_desc =>
      'Nagy számban előforduló zátonyi hal, amely narancssárga és rózsaszín felhőket alkot az indo-csendes-óceáni korallképződmények fölött. A hímek lilás színűek.';

  @override
  String get species_mediterranean_grouper_name => 'Barna sügér';

  @override
  String get species_mediterranean_grouper_desc =>
      'Nagy, sötétbarna sügér halvány márványozással, a földközi-tengeri sziklás zátonyok ikonikus ragadozója.';

  @override
  String get species_mediterranean_moray_name => 'Földközi-tengeri muréna';

  @override
  String get species_mediterranean_moray_desc =>
      'Sötétbarna muréna sárga márványozással, a Földközi-tengeren gyakran kandikál ki a sziklarepedésekből.';

  @override
  String get species_ornate_wrasse_name => 'Díszes ajakoshal';

  @override
  String get species_ornate_wrasse_desc =>
      'Színpompás zöld ajakoshal vörös fejrajzolattal, a földközi-tengeri zátonyok egyik leggyakoribb ajakoshala.';

  @override
  String get species_red_sea_bannerfish_name => 'Álarcos pillangóhal';

  @override
  String get species_red_sea_bannerfish_desc =>
      'Élénksárga pillangóhal sötét szemfolttal, a Vörös-tenger endemikus faja. Gyakran párban látható.';

  @override
  String get species_red_sea_anemonefish_name => 'Vörös-tengeri bohóchal';

  @override
  String get species_red_sea_anemonefish_desc =>
      'Narancssárga bohóchal két fehér sávval, a Vörös-tenger és az Ádeni-öböl endemikus faja.';

  @override
  String get species_arabian_angelfish_name => 'Arab angyalhal';

  @override
  String get species_arabian_angelfish_desc =>
      'Nagy, sötétkék angyalhal markáns sárga függőleges sávval és farokkal, az Indiai-óceán nyugati részének endemikus faja.';

  @override
  String get species_king_angelfish_name => 'Király angyalhal';

  @override
  String get species_king_angelfish_desc =>
      'Nagy, sötétkék angyalhal fehér függőleges sávval és sárga farokkal, a Csendes-óceán keleti részén és a Galápagosnál él.';

  @override
  String get species_ocean_sunfish_name => 'Holdhal';

  @override
  String get species_ocean_sunfish_desc =>
      'A legnehezebb csontos hal, amely a 2 tonnát is meghaladja. Bali és a Galápagos tisztogatóállomásainál olykor búvárok is látják.';

  @override
  String get species_lingcod_name => 'Csendes-óceáni zöldhal';

  @override
  String get species_lingcod_desc =>
      'Nagy, márványozott ragadozó a Csendes-óceán északnyugati részének sziklás zátonyain, gyakran ikracsomóit őrizve látható.';

  @override
  String get species_wolf_eel_name => 'Farkasangolna';

  @override
  String get species_wolf_eel_desc =>
      'Nagy, szürke farkasangolna dudoros fejjel és erős állkapoccsal, a Csendes-óceán északnyugati részének sziklaüregeiben él.';

  @override
  String get species_giant_sea_bass_name => 'Óriás tengeri sügér';

  @override
  String get species_giant_sea_bass_desc =>
      'Hatalmas, 2 méter és 250 kilogramm fölé növő sügér Dél-Kalifornia sziklás zátonyain és moszaterdeiben.';

  @override
  String get species_garibaldi_name => 'Garibaldihal';

  @override
  String get species_garibaldi_desc =>
      'Élénk narancssárga korallhal, Kalifornia hivatalos tengeri hala, territoriális a moszaterdei zátonyokon.';

  @override
  String get species_sheephead_name => 'Kaliforniai kosfejű ajakoshal';

  @override
  String get species_sheephead_desc =>
      'Nagy ajakoshal fekete fejjel és farokkal, vörös középső testtájjal és fehér állal. Kalifornia moszaterdeiben él.';

  @override
  String get species_copper_rockfish_name => 'Rézszínű sziklahal';

  @override
  String get species_copper_rockfish_desc =>
      'Rezes-narancssárga sziklahal halvány foltokkal, gyakori látvány a Csendes-óceán északnyugati sziklás zátonyain és moszaterdeiben.';

  @override
  String get species_oriental_sweetlips_name => 'Keleti édesajkúhal';

  @override
  String get species_oriental_sweetlips_desc =>
      'Nagy indo-csendes-óceáni zátonyi hal markáns fekete-fehér csíkokkal és sárga úszókkal. A fiatal példányok tekergő táncot járnak.';

  @override
  String get species_harlequin_sweetlips_name => 'Harlekin édesajkúhal';

  @override
  String get species_harlequin_sweetlips_desc =>
      'A kifejlett példányok szürkék, sötét pettyekkel; a fiatalok barnák, nagy fehér foltokkal, és hullámzó mozgással úsznak.';

  @override
  String get species_blue_ringed_angelfish_name => 'Kékgyűrűs angyalhal';

  @override
  String get species_blue_ringed_angelfish_desc =>
      'Nagy, barna angyalhal kék ívelt vonalakkal és jellegzetes kék gyűrűvel a kopoltyúfedő fölött.';

  @override
  String get species_yellowbar_angelfish_name => 'Sárgasávos angyalhal';

  @override
  String get species_yellowbar_angelfish_desc =>
      'Nagy, szürkéskék angyalhal feltűnő sárga testfolttal, a Vörös-tengerben és az Indiai-óceán nyugati részén él.';

  @override
  String get species_filefish_scrawled_name => 'Firkált reszelőhal';

  @override
  String get species_filefish_scrawled_desc =>
      'Nagy, olívbarna reszelőhal kék firkaszerű rajzolattal és narancssárga toroklebennyel, világszerte trópusi zátonyokon él.';

  @override
  String get species_clown_filefish_name => 'Narancsfoltos reszelőhal';

  @override
  String get species_clown_filefish_desc =>
      'Kis, zöld reszelőhal narancssárga pettyekkel és hosszú ormánnyal, kizárólag Acropora korallpolipokkal táplálkozik.';

  @override
  String get species_unicornfish_name => 'Kéktüskés egyszarvúhal';

  @override
  String get species_unicornfish_desc =>
      'Szürke doktorhal feltűnő homlokszarvval és két kék faroktüskével, gyakori az indo-csendes-óceáni zátonylapokon.';

  @override
  String get species_surgeonfish_sailfin_name => 'Vitorlás doktorhal';

  @override
  String get species_surgeonfish_sailfin_desc =>
      'Markáns sávozású doktorhal erősen kiterjeszthető hát- és farok alatti úszóval, az Indo-csendes-óceánon él.';

  @override
  String get species_achilles_tang_name => 'Achilles-doktorhal';

  @override
  String get species_achilles_tang_desc =>
      'Sötétbarna doktorhal markáns narancssárga könnycsepp alakú folttal a farok közelében, a Csendes-óceán középső részének hullámzónáiban él.';

  @override
  String get species_doctorfish_name => 'Karibi doktorhal';

  @override
  String get species_doctorfish_desc =>
      'Szürkésbarna doktorhal halvány sötét sávokkal és feltűnő farokszikével, gyakori a karibi zátonyokon.';

  @override
  String get species_checkerboard_wrasse_name => 'Sakktáblás ajakoshal';

  @override
  String get species_checkerboard_wrasse_desc =>
      'Színpompás ajakoshal, testén zöld, rózsaszín és fekete négyzetekből álló sakktáblamintázattal.';

  @override
  String get species_bird_wrasse_name => 'Madárajakoshal';

  @override
  String get species_bird_wrasse_desc =>
      'Rendkívül megnyúlt, madárcsőrre emlékeztető ormányú ajakoshal; a hímek sötétzöldek, a nőstények barnák.';

  @override
  String get species_sling_jaw_wrasse_name => 'Nyújtható állkapcsú ajakoshal';

  @override
  String get species_sling_jaw_wrasse_desc =>
      'Kinyújtható állkapcsú ajakoshal, amely előrelökve kapja el a zsákmányát, sárga és barna színváltozatban is előfordul.';

  @override
  String get species_peacock_flounder_name => 'Pávalepényhal';

  @override
  String get species_peacock_flounder_desc =>
      'Lapos fenéklakó hal kék gyűrűkkel és pettyekkel, amely a tengerfenékhez igazítva változtatja a színét.';

  @override
  String get species_hogfish_name => 'Disznóhal';

  @override
  String get species_hogfish_desc =>
      'Nagy nyugat-atlanti ajakoshal disznóormányra emlékeztető orral és megnyúlt hátúszótüskékkel, zátonyok és roncsok közelében él.';

  @override
  String get species_tarpon_name => 'Atlanti tarpon';

  @override
  String get species_tarpon_desc =>
      'Hatalmas ezüstös hal nagy, tükörszerű pikkelyekkel, olykor karibi barlangokban és csatornákban találkoznak vele a búvárok.';

  @override
  String get species_permit_name => 'Karibi pompánó';

  @override
  String get species_permit_desc =>
      'Magas testű ezüstös fattyúmakréla sötét, villás farokkal, a karibi homokpadokon és zátonyok közelében él.';

  @override
  String get species_spotted_drum_name => 'Foltos dobhal';

  @override
  String get species_spotted_drum_desc =>
      'Feltűnő karibi hal magas, megnyúlt hátúszóval és markáns fekete-fehér pettyes mintázattal.';

  @override
  String get species_jackknife_fish_name => 'Bicskahal';

  @override
  String get species_jackknife_fish_desc =>
      'Elegáns karibi hal magas fekete hátúszócsíkkal és átlós testsávval, sziklapárkányok alatt él.';

  @override
  String get species_bigeye_name => 'Üvegszemű hal';

  @override
  String get species_bigeye_desc =>
      'Élénkvörös, éjszakai hal nagy, fényvisszaverő szemekkel, a karibi és atlanti zátonyok barlangjaiban rejtőzik.';

  @override
  String get species_remora_name => 'Tapadóhal';

  @override
  String get species_remora_desc =>
      'Karcsú hal a fején tapadókoronggal, amellyel cápákra, rájákra, teknősökre és más nagy állatokra tapadva utazik.';

  @override
  String get species_tilefish_sand_name => 'Homoki tilehal';

  @override
  String get species_tilefish_sand_desc =>
      'Megnyúlt, halványkék hal, amely törmelékhalmokat épít a karibi zátonyok homokos területein.';

  @override
  String get species_weedy_seadragon_name => 'Moszatos tengeri sárkány';

  @override
  String get species_weedy_seadragon_desc =>
      'A csikóhalak díszes rokona levélszerű nyúlványokkal, Dél-Ausztrália mérsékelt övi vizeinek endemikus faja.';

  @override
  String get species_leafy_seadragon_name => 'Leveles tengeri sárkány';

  @override
  String get species_leafy_seadragon_desc =>
      'Látványos tengeri sárkány kifinomult, levélszerű nyúlványokkal, Dél-Ausztrália endemikus faja. Igazi álommerülés élménye.';

  @override
  String get species_sailfin_snapper_name => 'Vitorlásúszójú csattogóhal';

  @override
  String get species_sailfin_snapper_desc =>
      'Elegáns sárga-kék csattogóhal megnyúlt hát- és farok alatti úszóval, az indo-csendes-óceáni zátonylejtőkön él.';

  @override
  String get species_sweetlip_emperor_name => 'Pettyes császárhal';

  @override
  String get species_sweetlip_emperor_desc =>
      'Nagy, ezüstös császárhal kék vonalakkal az arcán és sárga úszószegéllyel, gyakori az indo-csendes-óceáni homokos zátonyterületeken.';

  @override
  String get species_crocodilefish_name => 'Krokodilhal';

  @override
  String get species_crocodilefish_desc =>
      'Lapos fejű, leshelyről támadó ragadozó díszes szemrojtokkal, tökéletesen álcázva fekszik az indo-csendes-óceáni zátonyok alján.';

  @override
  String get species_devil_scorpionfish_name => 'Ördög-skorpióhal';

  @override
  String get species_devil_scorpionfish_desc =>
      'Zömök, rejtőszínű skorpióhal, amely színes mellúszóbelsejét villantva figyelmezteti a ragadozókat.';

  @override
  String get species_spiny_devilfish_name => 'Démoni tüskéshal';

  @override
  String get species_spiny_devilfish_desc =>
      'Mérgező fenéklakó, amely átalakult úszósugarain lépeget, és zavarás esetén élénk mellúszóit villantja fel.';

  @override
  String get species_waspfish_name => 'Kakadu darázshal';

  @override
  String get species_waspfish_desc =>
      'Kis, oldalról lapított skorpióhal, amely száraz levélként ringatózik az áramlatban az indo-csendes-óceáni iszapos fenéken.';

  @override
  String get species_stargazer_name => 'Fehérszegélyű csillagnéző';

  @override
  String get species_stargazer_desc =>
      'Leshelyről támadó ragadozó, amely a homokba ásva csak a szemét hagyja kint, és áramütést is képes leadni. Az Indo-csendes-óceánon él.';

  @override
  String get species_striped_catfish_name => 'Csíkos tengeri harcsa';

  @override
  String get species_striped_catfish_desc =>
      'Mérgező tüskéjű harcsa; a fiatal példányok sűrű, gömb alakú rajokat alkotva gördülnek végig az indo-csendes-óceáni zátonyok alján.';

  @override
  String get species_red_emperor_name => 'Vörös császár csattogóhal';

  @override
  String get species_red_emperor_desc =>
      'Nagy csattogóhal; a kifejlett példányok rózsásvörösek, a fiatalok markáns vörös-fehér sávozásúak. Indo-csendes-óceáni zátonyokon él.';

  @override
  String get species_mangrove_snapper_name => 'Mangrove csattogóhal';

  @override
  String get species_mangrove_snapper_desc =>
      'Szürke csattogóhal a karibi mangrovékban, tengerifűmezőkön és zátonyokon, gyakran struktúrák közelében gyülekezik.';

  @override
  String get species_dottyback_orchid_name => 'Orchidealila álsügér';

  @override
  String get species_dottyback_orchid_desc =>
      'Kis, élénklila hal, a Vörös-tenger endemikus faja, amely a meredek zátonyfalak repedéseibe ki-be cikázik.';

  @override
  String get species_dottyback_royal_name => 'Királyi álsügér';

  @override
  String get species_dottyback_royal_desc =>
      'Kis, kétszínű hal bíborvörös elülső és élénksárga hátsó testfélével, az indo-csendes-óceáni zátonyfalakon él.';

  @override
  String get species_coral_trout_name => 'Korallpisztráng';

  @override
  String get species_coral_trout_desc =>
      'A Nagy-korallzátony nagyra tartott ragadozója, narancsvörös testét kék pettyek borítják.';

  @override
  String get species_barramundi_cod_name => 'Barramundi sügér';

  @override
  String get species_barramundi_cod_desc =>
      'Jellegzetes sügér apró fejjel, púpos háttal és világos alapon sötét pöttyökkel.';

  @override
  String get species_spadefish_atlantic_name => 'Atlanti ásóhal';

  @override
  String get species_spadefish_atlantic_desc =>
      'Ezüstös, korong alakú hal sötét függőleges sávokkal, gyakran nagy rajokban látható a karibi roncsok körül.';

  @override
  String get species_fusilier_yellowback_name => 'Sárgahátú fuzilérhal';

  @override
  String get species_fusilier_yellowback_desc =>
      'Áramvonalas kék, planktonevő hal sárga háttal, amely hatalmas rajokat alkot az indo-csendes-óceáni zátonylejtők fölött.';

  @override
  String get species_fusilier_bluestreak_name => 'Kékcsíkos fuzilérhal';

  @override
  String get species_fusilier_bluestreak_desc =>
      'Kis, kék fuzilérhal sötét oldalsávval, gyorsan mozgó rajokban látható az indo-csendes-óceáni zátonyfalak mentén.';

  @override
  String get species_porkfish_name => 'Karibi morgóhal';

  @override
  String get species_porkfish_desc =>
      'Színpompás karibi morgóhal kék és sárga csíkokkal és két fekete fejsávval, zátonyok és roncsok közelében él.';

  @override
  String get species_blue_striped_grunt_name => 'Kékcsíkos morgóhal';

  @override
  String get species_blue_striped_grunt_desc =>
      'Sárga karibi morgóhal élénkkék vízszintes csíkokkal, nappal nagy, pihenő rajokat alkot a sziklapárkányok alatt.';

  @override
  String get species_french_grunt_name => 'Francia morgóhal';

  @override
  String get species_french_grunt_desc =>
      'Kis, sárga csíkos morgóhal, amely a nappali órákban sűrű, pihenő rajokat alkot a karibi zátonyokon.';

  @override
  String get species_convict_tang_name => 'Fegyenc doktorhal';

  @override
  String get species_convict_tang_desc =>
      'Halvány doktorhal hat függőleges fekete sávval, gyakran nagy rajokban legel az indo-csendes-óceáni zátonylapokon.';

  @override
  String get species_great_hammerhead_name => 'Csipkés pörölycápa';

  @override
  String get species_great_hammerhead_desc =>
      'Jellegzetes cápa csipkés szegélyű, kalapács alakú fejjel, nagy rajokat alkot tenger alatti hegyeknél és part menti szigeteknél.';

  @override
  String get species_wobbegong_name => 'Foltos szőnyegcápa';

  @override
  String get species_wobbegong_desc =>
      'Lapos, kiválóan álcázott szőnyegcápa a szája körül rojtos bőrlebenyekkel, Ausztrália mérsékelt övi zátonyain él.';

  @override
  String get species_manta_ray_name => 'Zátonymanta';

  @override
  String get species_manta_ray_desc =>
      'Kecses óriás akár 5 méteres szárnyfesztávval, amely tisztogatóállomásokat látogat és planktonnal táplálkozik az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_oceanic_manta_name => 'Óceáni manta';

  @override
  String get species_oceanic_manta_desc =>
      'A legnagyobb rájafaj, szárnyfesztávja meghaladja a 7 métert, part menti tenger alatti hegyeknél és tisztogatóállomásoknál találkozni vele.';

  @override
  String get species_undulated_moray_name => 'Hullámos muréna';

  @override
  String get species_undulated_moray_desc =>
      'Sárgászöld muréna sötét, hullámos rajzolattal, gyakran látható éjszaka vadászni az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_whitemouth_moray_name => 'Fehérszájú muréna';

  @override
  String get species_whitemouth_moray_desc =>
      'Sötétbarna muréna apró fehér pettyekkel és jellegzetes fehér szájbelsővel, az Indo-csendes-óceánon él.';

  @override
  String get species_dragon_moray_name => 'Sárkánymuréna';

  @override
  String get species_dragon_moray_desc =>
      'Feltűnő muréna sárkányszerű szarvakkal az orrnyílásai fölött és narancsvörös leopárdfoltokkal, az Indo-csendes-óceánon él.';

  @override
  String get species_lyretail_grouper_name => 'Lantfarkú sügér';

  @override
  String get species_lyretail_grouper_desc =>
      'Vörösesrózsaszín sügér kék pettyekkel és jellegzetes sarló alakú farokkal, az indo-csendes-óceáni külső zátonyfalakon él.';

  @override
  String get species_banded_butterflyfish_name => 'Sávos pillangóhal';

  @override
  String get species_banded_butterflyfish_desc =>
      'Fehér pillangóhal négy markáns fekete függőleges sávval, a karibi zátonyok egyik leggyakoribb pillangóhala.';

  @override
  String get species_ringed_pipefish_name => 'Gyűrűs tűhal';

  @override
  String get species_ringed_pipefish_desc =>
      'Karcsú tűhal váltakozó vörös és fehér gyűrűkkel, az indo-csendes-óceáni zátonyok barlangjaiban és párkányai alatt él.';

  @override
  String get species_razorfish_name => 'Borotvahal';

  @override
  String get species_razorfish_desc =>
      'Apró hal, amely fejjel lefelé, függőlegesen úszik csoportosan, gyakran tengerisünök tüskéi közé rejtőzve az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_harlequin_tuskfish_name => 'Harlekin agyarashal';

  @override
  String get species_harlequin_tuskfish_desc =>
      'Színpompás ajakoshal élénkkék agyarakkal, vörösnarancs sávokkal és fehér foltokkal, a nyugat-csendes-óceáni zátonyokon él.';

  @override
  String get species_blue_groper_name => 'Kék ajakoshal';

  @override
  String get species_blue_groper_desc =>
      'Nagy, kék ajakoshal Kelet-Ausztrália endemikus faja, barátságos, és a mérsékelt övi zátonyokon gyakran megközelíti a búvárokat.';

  @override
  String get species_red_lipped_batfish_name => 'Vörösajkú denevérhal';

  @override
  String get species_red_lipped_batfish_desc =>
      'Bizarr, lapos testű hal élénkvörös ajakkal, amely átalakult úszóin lépeget a Galápagos tengerfenekén.';

  @override
  String get species_orangeband_surgeonfish_name => 'Narancssávos doktorhal';

  @override
  String get species_orangeband_surgeonfish_desc =>
      'Szürkésbarna doktorhal narancssárga vízszintes sávval a szeme mögött, a csendes-óceáni zátonylejtőkön él.';

  @override
  String get species_maori_wrasse_name => 'Maori ajakoshal';

  @override
  String get species_maori_wrasse_desc =>
      'Közepes méretű ajakoshal sötét sávval a mellúszó mögött, gyakori a csendes-óceáni és indiai-óceáni zátonyokon.';

  @override
  String get species_blue_ringed_octopus_name => 'Kékgyűrűs polip';

  @override
  String get species_blue_ringed_octopus_desc =>
      'Kis termetű, de rendkívül mérgező polip, amely veszély esetén élénkkék gyűrűket villant fel.';

  @override
  String get species_common_octopus_name => 'Közönséges polip';

  @override
  String get species_common_octopus_desc =>
      'Rendkívül intelligens polip, amely villámgyors színváltásáról és problémamegoldó képességéről ismert.';

  @override
  String get species_giant_pacific_octopus_name => 'Óriás csendes-óceáni polip';

  @override
  String get species_giant_pacific_octopus_desc =>
      'A legnagyobb polipfaj, karjainak fesztávja a hideg csendes-óceáni vizekben meghaladja a 4 métert.';

  @override
  String get species_mimic_octopus_name => 'Utánzó polip';

  @override
  String get species_mimic_octopus_desc =>
      'Rendkívüli polip, amely más tengeri fajok külsejét és viselkedését utánozza.';

  @override
  String get species_coconut_octopus_name => 'Kókuszpolip';

  @override
  String get species_coconut_octopus_desc =>
      'Kis polip, amely arról híres, hogy kókuszhéjakat hordoz magával, és hordozható búvóhelyként használja őket.';

  @override
  String get species_day_octopus_name => 'Nappali polip';

  @override
  String get species_day_octopus_desc =>
      'Nappal aktív vadász, gyakori az indo-csendes-óceáni zátonyokon, lenyűgöző álcázóképességgel.';

  @override
  String get species_wonderpus_octopus_name => 'Csodapolip';

  @override
  String get species_wonderpus_octopus_desc =>
      'Feltűnő polip egyedi fehér és barna sávozással, homokos, iszapos merülőhelyeken él.';

  @override
  String get species_broadclub_cuttlefish_name => 'Széleskarú szépia';

  @override
  String get species_broadclub_cuttlefish_desc =>
      'Nagy szépia lenyűgöző színjátékkal, gyakran látható az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_pharaoh_cuttlefish_name => 'Fáraószépia';

  @override
  String get species_pharaoh_cuttlefish_desc =>
      'Nagy szépia az Indiai-óceán térségében, lüktető színmintázatairól ismert.';

  @override
  String get species_flamboyant_cuttlefish_name => 'Pompás szépia';

  @override
  String get species_flamboyant_cuttlefish_desc =>
      'Apró szépia, amely a tengerfenéken lépegetve élénk lila, rózsaszín és sárga hullámokat villant.';

  @override
  String get species_giant_cuttlefish_name => 'Óriásszépia';

  @override
  String get species_giant_cuttlefish_desc =>
      'A világ legnagyobb szépiája, amely dél-ausztráliai tömeges ívási gyülekezéseiről híres.';

  @override
  String get species_bigfin_reef_squid_name => 'Nagyúszójú zátonyi kalmár';

  @override
  String get species_bigfin_reef_squid_desc =>
      'Rajokban élő kalmár, amellyel gyakran éjszakai merüléseken találkozni, a búvárlámpák vonzzák.';

  @override
  String get species_caribbean_reef_squid_name => 'Karibi zátonyi kalmár';

  @override
  String get species_caribbean_reef_squid_desc =>
      'Kíváncsi kalmár, amely a Karib-tengeren gyakran kis csoportokban lebeg a zátonyperemek közelében.';

  @override
  String get species_bobtail_squid_name => 'Törpe tintahal';

  @override
  String get species_bobtail_squid_desc =>
      'Apró, éjszakai tintahal, amely nappal a homokba ássa magát, az iszapmerülések nagy fogása.';

  @override
  String get species_chambered_nautilus_name => 'Kamrás nautilusz';

  @override
  String get species_chambered_nautilus_desc =>
      'Ősi élő kövület csavart házzal, amelyet búvárok ritkán, hajnalban, mély vízben látnak.';

  @override
  String get species_spanish_dancer_name => 'Spanyol táncosnő';

  @override
  String get species_spanish_dancer_desc =>
      'A legnagyobb csupaszkopoltyús csigafaj, amely vörös köpenyét hullámoztatva úszik, akár egy flamencotáncos.';

  @override
  String get species_chromodoris_willani_name => 'Willan-chromodorisz';

  @override
  String get species_chromodoris_willani_desc =>
      'Feltűnő kék-fekete csupaszkopoltyús csiga fehér szegéllyel, gyakori az Indo-csendes-óceánon.';

  @override
  String get species_chromodoris_lochi_name => 'Loch-chromodorisz';

  @override
  String get species_chromodoris_lochi_desc =>
      'Kék csupaszkopoltyús csiga sötét vonalakkal és fehér szegéllyel, a trópusi Csendes-óceánon mindenütt előfordul.';

  @override
  String get species_chromodoris_magnifica_name => 'Pompás chromodorisz';

  @override
  String get species_chromodoris_magnifica_desc =>
      'Ragyogó kék, fehér és narancssárga csupaszkopoltyús csiga az Indo-csendes-óceán korallzátonyain.';

  @override
  String get species_chromodoris_annae_name => 'Anna-chromodorisz';

  @override
  String get species_chromodoris_annae_desc =>
      'Mélykék csupaszkopoltyús csiga fekete vonalakkal, valamint narancssárga végű tapogatókkal és kopoltyúkkal.';

  @override
  String get species_nembrotha_kubaryana_name => 'Változékony neoncsiga';

  @override
  String get species_nembrotha_kubaryana_desc =>
      'Sötétzöld csupaszkopoltyús csiga élénk narancssárga vagy vörös rajzolattal, zsákállatokkal táplálkozik.';

  @override
  String get species_nembrotha_cristata_name => 'Taréjos nembrotha';

  @override
  String get species_nembrotha_cristata_desc =>
      'Fekete csupaszkopoltyús csiga élénkzöld dudorokkal és csíkozással, az indo-csendes-óceáni zátonyokon él.';

  @override
  String get species_phyllidia_varicosa_name => 'Bibircses phyllidia';

  @override
  String get species_phyllidia_varicosa_desc =>
      'Kékesszürke csupaszkopoltyús csiga sárga végű kiemelkedő dudorokkal, a ragadozók számára mérgező.';

  @override
  String get species_phyllidia_ocellata_name => 'Szemfoltos phyllidia';

  @override
  String get species_phyllidia_ocellata_desc =>
      'Fehér csupaszkopoltyús csiga rózsaszín gyűrűs, kiemelkedő dudorokkal, trópusi zátonyokon él.';

  @override
  String get species_pikachu_nudibranch_name => 'Pikachu-csupaszkopoltyús';

  @override
  String get species_pikachu_nudibranch_desc =>
      'Apró sárga-fekete tengeri csiga, amely egy rajzfilmfigurára emlékeztet, a Csendes-óceánon él.';

  @override
  String get species_anna_rosefieldi_name => 'Roboastra csupaszkopoltyús';

  @override
  String get species_anna_rosefieldi_desc =>
      'Ragadozó csupaszkopoltyús csiga sötét testtel és élénk hosszanti csíkokkal, amely más csigákra vadászik.';

  @override
  String get species_lettuce_sea_slug_name => 'Salátacsiga';

  @override
  String get species_lettuce_sea_slug_desc =>
      'Fodros zöld tengeri csiga, amely az algákból származó kloroplasztiszokat megőrizve fotoszintetizál.';

  @override
  String get species_blue_dragon_nudibranch_name =>
      'Kék sárkány csupaszkopoltyús';

  @override
  String get species_blue_dragon_nudibranch_desc =>
      'Hosszú, aeolida típusú csupaszkopoltyús csiga kék végű nyúlványokkal, amely szimbionta zooxantellákat hordoz.';

  @override
  String get species_gloomy_nudibranch_name => 'Komor csupaszkopoltyús';

  @override
  String get species_gloomy_nudibranch_desc =>
      'Sötét kékeszöld csupaszkopoltyús csiga kék szegélyű bordákkal, gyakori az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_ocellined_nudibranch_name =>
      'Narancsvonalas csupaszkopoltyús';

  @override
  String get species_ocellined_nudibranch_desc =>
      'Fehér csupaszkopoltyús csiga narancssárga szegélyű bordákkal, amelyek mértani mintázatot rajzolnak a köpenyére.';

  @override
  String get species_glossodoris_cincta_name => 'Glossodorisz csupaszkopoltyús';

  @override
  String get species_glossodoris_cincta_desc =>
      'Krémszínű csupaszkopoltyús csiga sötétbarna szegéllyel és narancssárga peremmel a köpenyén.';

  @override
  String get species_jorunna_funebris_name => 'Pettyes csupaszkopoltyús';

  @override
  String get species_jorunna_funebris_desc =>
      'Fehér csupaszkopoltyús csiga fekete végű bolyhos szemölcsökkel, amely egy pihe-puha nyuszira emlékeztet.';

  @override
  String get species_ceratosoma_trilobatum_name =>
      'Háromkaréjú csupaszkopoltyús';

  @override
  String get species_ceratosoma_trilobatum_desc =>
      'Nagy csupaszkopoltyús csiga magas háti nyúlvánnyal és oldalsó karéjokkal, lila és sárga árnyalatokban.';

  @override
  String get species_hypselodoris_apolegma_name => 'Lila hypselodorisz';

  @override
  String get species_hypselodoris_apolegma_desc =>
      'Elegáns lila csupaszkopoltyús csiga fehér köpenyszegéllyel, az indo-csendes-óceáni zátonyokon él.';

  @override
  String get species_hypselodoris_bullockii_name => 'Bullock-hypselodorisz';

  @override
  String get species_hypselodoris_bullockii_desc =>
      'Rózsaszín és lila csupaszkopoltyús csiga sárga végű tapogatókkal az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_flabellina_exoptata_name => 'Pompás flabellina';

  @override
  String get species_flabellina_exoptata_desc =>
      'Áttetsző, aeolida típusú csupaszkopoltyús csiga lila végű narancssárga nyúlványokkal, trópusi vizekben él.';

  @override
  String get species_risbecia_tryoni_name => 'Tryon-risbecia';

  @override
  String get species_risbecia_tryoni_desc =>
      'Nagy, barna és kék csupaszkopoltyús csiga, amelyet az indo-csendes-óceáni zátonyokon gyakran párzó párokban látni.';

  @override
  String get species_goniobranchus_kuniei_name => 'Kunie-csupaszkopoltyús';

  @override
  String get species_goniobranchus_kuniei_desc =>
      'Narancsfoltos fehér csupaszkopoltyús csiga lila köpenyszegéllyel, a Csendes-óceán nyugati részén él.';

  @override
  String get species_mexichromis_multituberculata_name =>
      'Sokgumós csupaszkopoltyús';

  @override
  String get species_mexichromis_multituberculata_desc =>
      'Lila-fehér csupaszkopoltyús csiga kiemelkedő dudorokkal és narancssárga végű függelékekkel.';

  @override
  String get species_chromodoris_dianae_name => 'Diana-chromodorisz';

  @override
  String get species_chromodoris_dianae_desc =>
      'Élénkkék csupaszkopoltyús csiga fekete csíkokkal és narancssárga kopoltyúkkal, a Csendes-óceán nyugati részén él.';

  @override
  String get species_phyllodesmium_poindimiei_name =>
      'Napenergiával működő csupaszkopoltyús';

  @override
  String get species_phyllodesmium_poindimiei_desc =>
      'Áttetsző, aeolida típusú csupaszkopoltyús csiga elágazó nyúlványokkal, amelyekben zooxantellák élnek.';

  @override
  String get species_chromodoris_elisabethina_name => 'Erzsébet-chromodorisz';

  @override
  String get species_chromodoris_elisabethina_desc =>
      'Kék és sárga vonalas csupaszkopoltyús csiga fehér köpenyszegéllyel, gyakori Délkelet-Ázsiában.';

  @override
  String get species_doridella_batava_name => 'Batáviai doridacsiga';

  @override
  String get species_doridella_batava_desc =>
      'Feketétől barnáig változó színű doridacsiga, amely kövek és törmelék alatt él az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_tiger_cowrie_name => 'Tigrisporceláncsiga';

  @override
  String get species_tiger_cowrie_desc =>
      'Nagy, pettyes porceláncsiga a trópusi zátonyokon, házát gyakran részben befedi a köpenye.';

  @override
  String get species_tritons_trumpet_name => 'Tritonkürt';

  @override
  String get species_tritons_trumpet_desc =>
      'Nagy testű ragadozó csiga, a töviskoronás tengericsillag természetes ellensége.';

  @override
  String get species_queen_conch_name => 'Királyi szárnyascsiga';

  @override
  String get species_queen_conch_desc =>
      'A karibi tengerifűmezők ikonikus, nagy termetű csigája, jellegzetes rózsaszín házbelsővel.';

  @override
  String get species_banded_coral_shrimp_name => 'Sávos korallgarnéla';

  @override
  String get species_banded_coral_shrimp_desc =>
      'Vörös-fehér sávos tisztogató garnéla hosszú fehér csápokkal, zátonyrepedésekben él.';

  @override
  String get species_mantis_shrimp_name => 'Pávás sáskarák';

  @override
  String get species_mantis_shrimp_desc =>
      'Színpompás ragadozó erős, bunkószerű végtagokkal, amelyekkel kagylóhéjakat is szétzúz.';

  @override
  String get species_cleaner_shrimp_name => 'Skarlát tisztogató garnéla';

  @override
  String get species_cleaner_shrimp_desc =>
      'Élénkvörös-fehér garnéla, amely tisztogatóállomásokat rendez be a zátonyi halak kiszolgálására.';

  @override
  String get species_pederson_cleaner_shrimp_name =>
      'Pederson-tisztogató garnéla';

  @override
  String get species_pederson_cleaner_shrimp_desc =>
      'Áttetsző karibi tisztogató garnéla, amely tengeri rózsák csápjai között él.';

  @override
  String get species_harlequin_shrimp_name => 'Harlekingarnéla';

  @override
  String get species_harlequin_shrimp_desc =>
      'Feltűnő mintázatú garnéla lapos ollókkal, amely kizárólag tengericsillagokkal táplálkozik.';

  @override
  String get species_coleman_shrimp_name => 'Coleman-garnéla';

  @override
  String get species_coleman_shrimp_desc =>
      'Apró, párban élő garnéla tűzsünökön, a víz alatti fotósok nagy kedvence.';

  @override
  String get species_emperor_shrimp_name => 'Császárgarnéla';

  @override
  String get species_emperor_shrimp_desc =>
      'Színpompás együttélő garnéla, amely tengeri uborkákon és csupaszkopoltyús csigákon utazik.';

  @override
  String get species_sexy_shrimp_name => 'Szexi garnéla';

  @override
  String get species_sexy_shrimp_desc =>
      'Apró anemónagarnéla, amely farokcsóváló táncáról ismert, a makrofotózás közkedvelt témája.';

  @override
  String get species_marble_shrimp_name => 'Márványgarnéla';

  @override
  String get species_marble_shrimp_desc =>
      'Éjszakai életmódú, márványos garnéla tollas lábakkal, nappal a zátonyrepedésekben rejtőzik.';

  @override
  String get species_spiny_lobster_name => 'Karibi languszta';

  @override
  String get species_spiny_lobster_desc =>
      'Nagy testű, olló nélküli languszta hosszú csápokkal, a zátonypárkányok alatt húzódik meg.';

  @override
  String get species_painted_spiny_lobster_name => 'Festett languszta';

  @override
  String get species_painted_spiny_lobster_desc =>
      'Élénk színű languszta kék, zöld és fehér csíkos lábakkal az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_slipper_lobster_name => 'Medverák';

  @override
  String get species_slipper_lobster_desc =>
      'Lapos testű, éjszakai rák, amelynek hosszú ostorcsápok helyett széles csáplemezei vannak.';

  @override
  String get species_squat_lobster_name => 'Tömzsirák';

  @override
  String get species_squat_lobster_desc =>
      'Apró, rózsaszínes-lila rákféle, amely óriás hordószivacsokon él, a makrofotósok kedvence.';

  @override
  String get species_hermit_crab_name => 'Kéklábú remeterák';

  @override
  String get species_hermit_crab_desc =>
      'Kis remeterák élénkkék lábakkal, gyakran látható a karibi zátonyokon.';

  @override
  String get species_orangutan_crab_name => 'Orangutánrák';

  @override
  String get species_orangutan_crab_desc =>
      'Apró, szőrös rák, amely buborékkorallban él, és egy orangutánra emlékeztető megjelenéséről kapta a nevét.';

  @override
  String get species_decorator_crab_name => 'Díszítőrák';

  @override
  String get species_decorator_crab_desc =>
      'Az álcázás mestere, amely szivacsokat, algákat és hidraállatokat rögzít a páncéljára.';

  @override
  String get species_porcelain_crab_name => 'Porcelánrák';

  @override
  String get species_porcelain_crab_desc =>
      'Lapos, pettyes rák, amely tengeri rózsákban él, és tollas szájszervével szűri ki a táplálékot.';

  @override
  String get species_arrow_crab_name => 'Nyílrák';

  @override
  String get species_arrow_crab_desc =>
      'Pókszerű, hosszú lábú karibi rák hegyes homloknyúlvánnyal és csíkos lábakkal.';

  @override
  String get species_channel_clinging_crab_name => 'Karibi sziklarák';

  @override
  String get species_channel_clinging_crab_desc =>
      'Nagy karibi zátonyi rák sötét testtel és vörösnarancs ollókkal, repedésekben él.';

  @override
  String get species_coral_crab_name => 'Korallőrző rák';

  @override
  String get species_coral_crab_desc =>
      'Kis, pettyes rák, amely Pocillopora korallokban él szimbiózisban, és megvédi a gazdaállatát.';

  @override
  String get species_crown_of_thorns_starfish_name =>
      'Töviskoronás tengericsillag';

  @override
  String get species_crown_of_thorns_starfish_desc =>
      'Mérgező, sokkarú tengericsillag, amely korallal táplálkozik, és tömeges elszaporodásakor egész zátonyokat pusztíthat el.';

  @override
  String get species_blue_linckia_starfish_name => 'Kék tengericsillag';

  @override
  String get species_blue_linckia_starfish_desc =>
      'Élénkkék tengericsillag, gyakran látható az indo-csendes-óceáni zátonylapokon és lejtőkön.';

  @override
  String get species_red_knob_starfish_name => 'Vörös bütykös tengericsillag';

  @override
  String get species_red_knob_starfish_desc =>
      'Nagy, szürke tengericsillag feltűnő vörös végű tüskékkel, homokos zátonyterületeken él.';

  @override
  String get species_chocolate_chip_starfish_name =>
      'Csokidarabos tengericsillag';

  @override
  String get species_chocolate_chip_starfish_desc =>
      'Homokszínű tengericsillag sötét, kiemelkedő dudorokkal, homokos aljzaton él.';

  @override
  String get species_cushion_star_name => 'Párnacsillag';

  @override
  String get species_cushion_star_desc =>
      'Duzzadt, ötszögletű tengericsillag rövid karokkal, az indo-csendes-óceáni zátonylapokon él.';

  @override
  String get species_fromia_starfish_name => 'Elegáns tengericsillag';

  @override
  String get species_fromia_starfish_desc =>
      'Kis, narancsvörös tengericsillag halvány lemezszegélyekkel, amelyek csempeszerű mintázatot alkotnak.';

  @override
  String get species_basket_star_name => 'Kosárcsillag';

  @override
  String get species_basket_star_desc =>
      'Gazdagon elágazó karjait éjszaka bontja ki, hogy az áramlatból szűrje ki a táplálékot.';

  @override
  String get species_brittle_star_name => 'Sávos kígyókarú csillag';

  @override
  String get species_brittle_star_desc =>
      'Csíkos kígyókarú csillag, amely kövek alatt és repedésekben él, karjai fürgék és kígyószerűek.';

  @override
  String get species_feather_star_name => 'Tollascsillag';

  @override
  String get species_feather_star_desc =>
      'Sokkarú tengerililiom, amely a zátony kiemelkedésein ülve tollas karjaival szűri ki a táplálékot.';

  @override
  String get species_black_feather_star_name => 'Fekete tollascsillag';

  @override
  String get species_black_feather_star_desc =>
      'Sötét tengerililiom, amely számos karját ütemesen mozgatva rövid ideig úszni is képes.';

  @override
  String get species_long_spined_sea_urchin_name => 'Hosszútüskéjű tengeri sün';

  @override
  String get species_long_spined_sea_urchin_desc =>
      'Fekete tengeri sün hosszú, mérgező tüskékkel, a karibi zátonyok egyik legfontosabb algalegelője.';

  @override
  String get species_fire_urchin_name => 'Tűzsün';

  @override
  String get species_fire_urchin_desc =>
      'Puha testű tengeri sün mérgező tüskékkel, amelyek érintésre fájdalmas szúrást okoznak.';

  @override
  String get species_pencil_urchin_name => 'Ceruzatüskés tengeri sün';

  @override
  String get species_pencil_urchin_desc =>
      'Robusztus tengeri sün vastag, tompa tüskékkel, amely a zátonyrepedésekbe ékelődve él.';

  @override
  String get species_collector_urchin_name => 'Gyűjtögető tengeri sün';

  @override
  String get species_collector_urchin_desc =>
      'Tengeri sün, amely törmelékkel és algadarabokkal fedi be magát az álcázás kedvéért.';

  @override
  String get species_sea_apple_name => 'Tengeri alma';

  @override
  String get species_sea_apple_desc =>
      'Élénk színű tengeri uborka, amely szájcsápjaival szűri ki a táplálékot a vízből.';

  @override
  String get species_pineapple_sea_cucumber_name => 'Ananász tengeri uborka';

  @override
  String get species_pineapple_sea_cucumber_desc =>
      'Nagy, narancsvörös tengeri uborka csillag alakú bőrnyúlványokkal, zátonylejtőkön él.';

  @override
  String get species_black_sea_cucumber_name => 'Fekete tengeri uborka';

  @override
  String get species_black_sea_cucumber_desc =>
      'Gyakori fekete tengeri uborka az Indo-csendes-óceán homokos zátonylapjain.';

  @override
  String get species_leopard_sea_cucumber_name => 'Leopárd tengeri uborka';

  @override
  String get species_leopard_sea_cucumber_desc =>
      'Pettyes tengeri uborka, amely zavarás esetén ragadós fehér Cuvier-csöveket lövell ki.';

  @override
  String get species_sand_dollar_name => 'Homokdollár';

  @override
  String get species_sand_dollar_desc =>
      'Lapos, korong alakú tengeri sün, amely részben a homokos aljzatba ásva él.';

  @override
  String get species_moon_jellyfish_name => 'Füles medúza';

  @override
  String get species_moon_jellyfish_desc =>
      'Áttetsző, harang alakú medúza, testén átlátszik négy patkó alakú ivarmirigye.';

  @override
  String get species_lions_mane_jellyfish_name => 'Oroszlánsörényű medúza';

  @override
  String get species_lions_mane_jellyfish_desc =>
      'Az egyik legnagyobb medúzafaj, hosszan úszó csápokkal, hideg vizekben él.';

  @override
  String get species_box_jellyfish_name => 'Kockamedúza';

  @override
  String get species_box_jellyfish_desc =>
      'Rendkívül veszélyes, erős méreganyagú medúza az Indo-csendes-óceán trópusi vizeiben.';

  @override
  String get species_upside_down_jellyfish_name => 'Fejjel lefelé úszó medúza';

  @override
  String get species_upside_down_jellyfish_desc =>
      'Különös medúza, amely harangjával lefelé fekszik a homokos aljzaton, hogy algái fotoszintetizálhassanak.';

  @override
  String get species_blue_blubber_jellyfish_name => 'Kék kocsonyamedúza';

  @override
  String get species_blue_blubber_jellyfish_desc =>
      'Kékesfehér medúza feszes haranggal és fodros szájkarokkal, gyakori az ausztrál vizekben.';

  @override
  String get species_fried_egg_jellyfish_name => 'Tükörtojás medúza';

  @override
  String get species_fried_egg_jellyfish_desc =>
      'Földközi-tengeri medúza sárga kupolával, amely tükörtojásra emlékeztet, csalánozása enyhe.';

  @override
  String get species_pacific_sea_nettle_name => 'Csendes-óceáni csalánmedúza';

  @override
  String get species_pacific_sea_nettle_desc =>
      'Aranybarna medúza hosszan úszó csápokkal, a Csendes-óceán partjai mentén él.';

  @override
  String get species_compass_jellyfish_name => 'Iránytű medúza';

  @override
  String get species_compass_jellyfish_desc =>
      'Barna-fehér medúza V alakú rajzolattal, amely iránytűrózsaként sugárzik szét.';

  @override
  String get species_spotted_jellyfish_name => 'Pettyes medúza';

  @override
  String get species_spotted_jellyfish_desc =>
      'Fehérpettyes, aranyszínű medúza, amely a palaui Medúza-tavat megtöltve vált híressé.';

  @override
  String get species_barrel_jellyfish_name => 'Hordómedúza';

  @override
  String get species_barrel_jellyfish_desc =>
      'Nagy, kupola alakú medúza fodros szájkarokkal és enyhe csalánozással, gyakori az Atlanti-óceánban.';

  @override
  String get species_persian_carpet_flatworm_name => 'Perzsaszőnyeg laposféreg';

  @override
  String get species_persian_carpet_flatworm_desc =>
      'Díszes fekete laposféreg sárgásnarancs szegéllyel, gyakran összetévesztik csupaszkopoltyús csigával.';

  @override
  String get species_leopard_flatworm_name => 'Leopárd laposféreg';

  @override
  String get species_leopard_flatworm_desc =>
      'Áttetsző laposféreg leopárdszerű pettyekkel, a zátony aljzatán siklik végig.';

  @override
  String get species_divided_flatworm_name => 'Osztott laposféreg';

  @override
  String get species_divided_flatworm_desc =>
      'Feltűnő fekete-narancssárga laposféreg, amely védelmül mérgező csupaszkopoltyús csigákat utánoz.';

  @override
  String get species_blue_pseudoceros_flatworm_name =>
      'Kék pseudoceros laposféreg';

  @override
  String get species_blue_pseudoceros_flatworm_desc =>
      'Mélykék laposféreg narancssárga szegéllyel, az indo-csendes-óceáni zátonyfelületeken siklik.';

  @override
  String get species_racing_stripe_flatworm_name => 'Versenycsíkos laposféreg';

  @override
  String get species_racing_stripe_flatworm_desc =>
      'Krémszínű laposféreg határozott sötét középcsíkkal és fodros szegéllyel.';

  @override
  String get species_christmas_tree_worm_name => 'Karácsonyfaféreg';

  @override
  String get species_christmas_tree_worm_desc =>
      'Színpompás, spirális koronájú féreg a korallba ágyazva, amely közeledésre azonnal visszahúzódik.';

  @override
  String get species_feather_duster_worm_name => 'Tollseprűféreg';

  @override
  String get species_feather_duster_worm_desc =>
      'Csőlakó féreg legyező alakú, tollas sugárkoronával, amellyel a táplálékot szűri.';

  @override
  String get species_fire_worm_name => 'Szakállas tűzféreg';

  @override
  String get species_fire_worm_desc =>
      'Sertésféreg fehér csalánsertékkel, amelyek érintésre fájdalmas irritációt okoznak.';

  @override
  String get species_bobbit_worm_name => 'Bobbit-féreg';

  @override
  String get species_bobbit_worm_desc =>
      'A homokban rejtőző, leshelyről támadó ragadozó, amely erős rágóival villámgyorsan csap le.';

  @override
  String get species_social_feather_duster_name => 'Társas tollseprűféreg';

  @override
  String get species_social_feather_duster_desc =>
      'Telepes csőlakó féreg, amely finom, sávozott koronákból álló csoportokat alkot a karibi zátonyokon.';

  @override
  String get species_giant_clam_name => 'Óriáskagyló';

  @override
  String get species_giant_clam_desc =>
      'A legnagyobb élő kagyló, irizáló köpenyszövetében szimbionta algák élnek.';

  @override
  String get species_boring_clam_name => 'Fúrókagyló';

  @override
  String get species_boring_clam_desc =>
      'Kis, színpompás kagyló, amely a korallsziklába fúrja magát, és csak élénk köpenye látszik ki.';

  @override
  String get species_maxima_clam_name => 'Maxima óriáskagyló';

  @override
  String get species_maxima_clam_desc =>
      'Ragyogó színű kagyló a zátony kőzetébe ágyazva, elektromoskék és zöld köpennyel.';

  @override
  String get species_flame_scallop_name => 'Lángkagyló';

  @override
  String get species_flame_scallop_desc =>
      'Vörös kagyló, amely köpenyszegélye mentén fehér fényt villant, zátonyrepedésekben él.';

  @override
  String get species_thorny_oyster_name => 'Tüskés osztriga';

  @override
  String get species_thorny_oyster_desc =>
      'Tüskés héjú kagyló a zátony kőzetéhez nőve, gyakran szivacsok és algák borítják.';

  @override
  String get species_magnificent_sea_anemone_name => 'Pompás tengeri rózsa';

  @override
  String get species_magnificent_sea_anemone_desc =>
      'Nagy, színpompás tengeri rózsa, amely bohóchalaknak ad otthont, feltűnő törzzsel és hullámzó csápokkal.';

  @override
  String get species_bubble_tip_anemone_name => 'Buborékcsúcsú tengeri rózsa';

  @override
  String get species_bubble_tip_anemone_desc =>
      'Kedvelt bohóchal-gazdaállat gömbölyű csápvégekkel, zöld, barna vagy rózsaszín színben.';

  @override
  String get species_giant_carpet_anemone_name => 'Óriás szőnyeganemóna';

  @override
  String get species_giant_carpet_anemone_desc =>
      'Hatalmas tengeri rózsa rövid, ragadós csápokkal, amely akár egy méteres átmérőt is elérhet.';

  @override
  String get species_haddon_carpet_anemone_name => 'Haddon-szőnyeganemóna';

  @override
  String get species_haddon_carpet_anemone_desc =>
      'Lapos szőnyeganemóna homokos aljzaton, amely többféle bohóchalnak és porcelánráknak ad otthont.';

  @override
  String get species_long_tentacle_anemone_name => 'Hosszú csápú tengeri rózsa';

  @override
  String get species_long_tentacle_anemone_desc =>
      'Homokos aljzaton élő tengeri rózsa hosszú, hullámzó csápokkal, gyakran bohóchalakkal együtt.';

  @override
  String get species_tube_anemone_name => 'Csöves tengeri rózsa';

  @override
  String get species_tube_anemone_desc =>
      'Elegáns tengeri rózsa, amely a homokba ágyazott pergamenszerű csőben él, két csápkoszorúval.';

  @override
  String get species_hell_fire_anemone_name => 'Pokoltűz anemóna';

  @override
  String get species_hell_fire_anemone_desc =>
      'Erősen csalánozó tengeri rózsa elágazó csápokkal, amelyek lágykorallra emlékeztetnek.';

  @override
  String get species_beaded_sea_anemone_name => 'Gyöngyös tengeri rózsa';

  @override
  String get species_beaded_sea_anemone_desc =>
      'Duzzadt, gyöngyszerű csápvégű tengeri rózsa az indo-csendes-óceáni zátonyok homokos részein.';

  @override
  String get species_condylactis_anemone_name => 'Óriás karibi tengeri rózsa';

  @override
  String get species_condylactis_anemone_desc =>
      'Nagy karibi tengeri rózsa lila végű csápokkal, sziklás zátonyaljzaton él.';

  @override
  String get species_sand_anemone_name => 'Homoki tengeri rózsa';

  @override
  String get species_sand_anemone_desc =>
      'Finom testű tengeri rózsa részben a homokba ásva, lila végű csápokkal.';

  @override
  String get species_barrel_sponge_name => 'Óriás hordószivacs';

  @override
  String get species_barrel_sponge_desc =>
      'Hatalmas, hordó alakú szivacs, amely évszázadokig is elélhet a karibi zátonyfalakon.';

  @override
  String get species_azure_vase_sponge_name => 'Azúrkék vázaszivacs';

  @override
  String get species_azure_vase_sponge_desc =>
      'Élénk kékeslila, váza alakú szivacs a karibi zátonyfalakon.';

  @override
  String get species_yellow_tube_sponge_name => 'Sárga csőszivacs';

  @override
  String get species_yellow_tube_sponge_desc =>
      'Élénksárga, csöves szivacs, amely csoportokban nő a karibi zátonyfalakon.';

  @override
  String get species_elephant_ear_sponge_name => 'Elefántfül-szivacs';

  @override
  String get species_elephant_ear_sponge_desc =>
      'Nagy, narancssárga, legyező alakú szivacs a karibi falakon és túlnyúlások alatt.';

  @override
  String get species_rope_sponge_name => 'Kötélszivacs';

  @override
  String get species_rope_sponge_desc =>
      'Vörös, felálló, elágazó szivacs, amely kötélszerű képződményeket alkot a karibi zátonyokon.';

  @override
  String get species_portuguese_man_o_war_name => 'Portugál gálya';

  @override
  String get species_portuguese_man_o_war_desc =>
      'Telepes hidraállat gázzal töltött úszóhólyaggal és rendkívül fájdalmasan csalánozó, hosszan úszó csápokkal.';

  @override
  String get species_fire_coral_name => 'Tűzkorall';

  @override
  String get species_fire_coral_desc =>
      'Nem valódi korall, hanem hidraállat, amely érintésre fájdalmas csalánozást okoz a búvároknak.';

  @override
  String get species_by_the_wind_sailor_name => 'Vitorlás medúza';

  @override
  String get species_by_the_wind_sailor_desc =>
      'Kék, lebegő hidraállat-telep átlós vitorlával, amely fogja a szelet.';

  @override
  String get species_blue_button_name => 'Kékgomb medúza';

  @override
  String get species_blue_button_desc =>
      'Lebegő telepes hidraállat lapos koronggal és kék, csápszerű polipokkal.';

  @override
  String get species_giant_sea_hare_name => 'Óriás tengeri nyúl';

  @override
  String get species_giant_sea_hare_desc =>
      'Az egyik legnagyobb tengeri csiga, sötétbarnától feketéig terjedő színben, moszatágyakban él.';

  @override
  String get species_sea_hare_name => 'Foltos tengeri nyúl';

  @override
  String get species_sea_hare_desc =>
      'Nagy, zöldpettyes tengeri nyúl, amely zavarás esetén lila festéket bocsát ki.';

  @override
  String get species_nudibranch_berghia_name => 'Berghia csupaszkopoltyús';

  @override
  String get species_nudibranch_berghia_desc =>
      'Áttetsző, aeolida típusú csupaszkopoltyús csiga fehér végű nyúlványokkal, amely tengeri rózsákkal táplálkozik.';

  @override
  String get species_sea_pen_name => 'Tengeritoll';

  @override
  String get species_sea_pen_desc =>
      'Toll alakú telepes lágykorall a homokba horgonyozva, amely zavarásra visszahúzódik.';

  @override
  String get species_blue_sea_star_name => 'Kék tengericsillag';

  @override
  String get species_blue_sea_star_desc =>
      'Többszínű tengericsillag, amely az indo-csendes-óceáni zátonyokon egyetlen kartöredékből is újra képes növekedni.';

  @override
  String get species_reef_squid_name => 'Zátonyi kalmár';

  @override
  String get species_reef_squid_desc =>
      'Déli zátonyi kalmár, amellyel gyakran találkozni Ausztrália mérsékelt övi vizeiben.';

  @override
  String get species_tiger_shrimp_name => 'Tigrisgarnéla';

  @override
  String get species_tiger_shrimp_desc =>
      'Nagy, sávos garnéla az Indo-csendes-óceán homokos fenekén és tengerifűmezőin.';

  @override
  String get species_candy_crab_name => 'Cukorkarák';

  @override
  String get species_candy_crab_desc =>
      'Apró, színpompás rák, amely rózsaszín vagy sárga tüskés nyúlványaival gazdanövényéhez, a lágykorallhoz illeszkedik.';

  @override
  String get species_spider_crab_name => 'Pókszerű díszítőrák';

  @override
  String get species_spider_crab_desc =>
      'Lassú mozgású rák, amelyet álcázás céljából ráragasztott szivacsok és algák borítanak.';

  @override
  String get species_anemone_shrimp_name => 'Pompás anemónagarnéla';

  @override
  String get species_anemone_shrimp_desc =>
      'Átlátszó garnéla fehér és lila rajzolattal, amely tengeri rózsák csápjai között él.';

  @override
  String get species_snapping_shrimp_name => 'Pisztolyrák';

  @override
  String get species_snapping_shrimp_desc =>
      'Kis garnéla, amely túlméretezett ollójával hangos csattanást kelt, gyakran gébekkel él együtt.';

  @override
  String get species_glass_sponge_name => 'Vénusz virágkosara';

  @override
  String get species_glass_sponge_desc =>
      'Finom üvegszivacs bonyolult kovavázzal, mély vízben él.';

  @override
  String get species_toxic_sea_urchin_name => 'Virágsün';

  @override
  String get species_toxic_sea_urchin_desc =>
      'Megtévesztően szép tengeri sün, amelyet virágszerű, erősen mérgező fogócskák borítanak.';

  @override
  String get species_slate_pencil_urchin_name => 'Palaceruza tengeri sün';

  @override
  String get species_slate_pencil_urchin_desc =>
      'Vastag, lekerekített tüskéjű tengeri sün a karibi és atlanti zátonyok aljzatán.';

  @override
  String get species_spiny_sea_star_name => 'Tüskés tengericsillag';

  @override
  String get species_spiny_sea_star_desc =>
      'Nagy, mérsékelt övi tengericsillag feltűnő tüskékkel, európai és atlanti vizekben él.';

  @override
  String get species_bat_star_name => 'Denevércsillag';

  @override
  String get species_bat_star_desc =>
      'Hártyás karú csendes-óceáni tengericsillag narancssárga, vörös vagy lila színben, moszaterdőkben él.';

  @override
  String get species_sunflower_star_name => 'Napraforgócsillag';

  @override
  String get species_sunflower_star_desc =>
      'Hatalmas, gyorsan mozgó tengericsillag akár 24 karral, a csendes-óceáni moszaterdőkben él.';

  @override
  String get species_blood_star_name => 'Vércsillag';

  @override
  String get species_blood_star_desc =>
      'Élénk vörösnarancs, karcsú karú tengericsillag a Csendes-óceán mérsékelt övi vizeiben.';

  @override
  String get species_common_cuttlefish_name => 'Közönséges szépia';

  @override
  String get species_common_cuttlefish_desc =>
      'Az álcázás mestere W alakú pupillával, az európai és földközi-tengeri vizekben él.';

  @override
  String get species_blue_spotted_crab_name => 'Kékfoltos úszórák';

  @override
  String get species_blue_spotted_crab_desc =>
      'Aktívan úszó rák kék pettyekkel a páncélján, az Indo-csendes-óceán homokos aljzatán él.';

  @override
  String get species_sponge_crab_name => 'Szivacsrák';

  @override
  String get species_sponge_crab_desc =>
      'Rák, amely álcázásul élő szivacsot farag ki és hordoz a hátán.';

  @override
  String get species_horseshoe_crab_name => 'Tőrfarkú rák';

  @override
  String get species_horseshoe_crab_desc =>
      'Ősi csáprágós ízeltlábú sisak alakú páncéllal, az Atlanti-óceán homokos fenekén él.';

  @override
  String get species_sea_spider_name => 'Tengeri pók';

  @override
  String get species_sea_spider_desc =>
      'Finom testű, hosszú lábú tengeri ízeltlábú, amely hidraállatokon és mohaállatokon mászik.';

  @override
  String get species_sea_lily_name => 'Tengeri liliom';

  @override
  String get species_sea_lily_desc =>
      'Nyeles tengerililiom, élő kövület a mélyebb vizekben, amely tollas karjaival szűri ki a táplálékot.';

  @override
  String get species_mantis_shrimp_lysiosquilla_name => 'Szigonyos sáskarák';

  @override
  String get species_mantis_shrimp_lysiosquilla_desc =>
      'Nagy, üregásó sáskarák szigonyszerű ragadólábakkal, homokos aljzaton él.';

  @override
  String get species_purple_sea_urchin_name => 'Lila tengeri sün';

  @override
  String get species_purple_sea_urchin_desc =>
      'Nagy számban előforduló lila tengeri sün a csendes-óceáni moszaterdőkben és sziklás apálytócsákban.';

  @override
  String get species_crown_jellyfish_name => 'Koronás medúza';

  @override
  String get species_crown_jellyfish_desc =>
      'Mélylila medúza kiemelkedő, koronaszerű haranggal, az Indo-csendes-óceánon él.';

  @override
  String get species_comb_jelly_name => 'Tengeri egres';

  @override
  String get species_comb_jelly_desc =>
      'Kis, biolumineszkáló bordásmedúza irizáló fésűsorokkal és két hosszú csáppal.';

  @override
  String get species_warty_sea_slug_name => 'Bibircses tengeri csiga';

  @override
  String get species_warty_sea_slug_desc =>
      'Kék-fekete csupaszkopoltyús csiga sárga sapkájú dudorokkal, gyakran látható az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_doris_nudibranch_name => 'Tengeri citrom';

  @override
  String get species_doris_nudibranch_desc =>
      'Sárga, pettyes doridacsiga, amely a Csendes-óceán mérsékelt övi vizeiben szivacsokkal táplálkozik.';

  @override
  String get species_opalescent_nudibranch_name => 'Opálos csupaszkopoltyús';

  @override
  String get species_opalescent_nudibranch_desc =>
      'Áttetsző, aeolida típusú csiga élénk narancssárga nyúlványokkal és kék hátvonalakkal a csendes-óceáni vizekben.';

  @override
  String get species_clown_nudibranch_name => 'Bohóc csupaszkopoltyús';

  @override
  String get species_clown_nudibranch_desc =>
      'Rózsásnarancs csupaszkopoltyús csiga kék és fehér pettyekkel, Ausztrália mérsékelt övi vizeiben él.';

  @override
  String get species_bottlenose_dolphin_name => 'Palackorrú delfin';

  @override
  String get species_bottlenose_dolphin_desc =>
      'Kíváncsi és játékos delfin, amellyel a búvárok gyakran találkoznak trópusi és mérsékelt övi vizekben.';

  @override
  String get species_spinner_dolphin_name => 'Pörgő delfin';

  @override
  String get species_spinner_dolphin_desc =>
      'Akrobatikus delfin, amely levegőben végzett pörgéseiről ismert, gyakran nagy csapatokban látható korallzátonyok közelében.';

  @override
  String get species_common_dolphin_name => 'Közönséges delfin';

  @override
  String get species_common_dolphin_desc =>
      'Gyorsan úszó delfin jellegzetes homokóra alakú mintázattal, nyílt óceáni és part menti vizekben egyaránt él.';

  @override
  String get species_spotted_dolphin_name => 'Atlanti foltos delfin';

  @override
  String get species_spotted_dolphin_desc =>
      'Barátságos, pettyes delfin, amely a Bahamákon és a Karib-tengeren gyakran közelíti meg a búvárokat.';

  @override
  String get species_rissos_dolphin_name => 'Risso-delfin';

  @override
  String get species_rissos_dolphin_desc =>
      'Nagy testű delfin erősen sebhelyes szürke testtel, világszerte mély, part menti vizeken kívül él.';

  @override
  String get species_humpback_whale_name => 'Hosszúszárnyú bálna';

  @override
  String get species_humpback_whale_desc =>
      'Fenséges bálna, amely kiugrásairól és összetett énekeiről ismert, szezonális vándorlásai idején látható.';

  @override
  String get species_grey_whale_name => 'Szürke bálna';

  @override
  String get species_grey_whale_desc =>
      'Fenéken táplálkozó sziláscet, amely a Csendes-óceán partja mentén vándorol, testét gyakran kacsakagylók borítják.';

  @override
  String get species_blue_whale_name => 'Kék bálna';

  @override
  String get species_blue_whale_desc =>
      'A valaha élt legnagyobb állat, amellyel búvárok olykor a mély kék vízben találkoznak.';

  @override
  String get species_sperm_whale_name => 'Ámbráscet';

  @override
  String get species_sperm_whale_desc =>
      'Mélyre merülő cet hatalmas fejjel, amely olykor a merülései között a felszínen pihenve látható.';

  @override
  String get species_orca_name => 'Kardszárnyú delfin';

  @override
  String get species_orca_desc =>
      'Csúcsragadozó jellegzetes fekete-fehér rajzolattal, minden óceáni medencében előfordul.';

  @override
  String get species_minke_whale_name => 'Csukabálna';

  @override
  String get species_minke_whale_desc =>
      'Kisebb sziláscet, amely kíváncsian közelít a búvárokhoz, különösen a Nagy-korallzátonynál.';

  @override
  String get species_beluga_whale_name => 'Fehér delfin';

  @override
  String get species_beluga_whale_desc =>
      'Fehér sarkvidéki cet, amely hangadásáról és társas viselkedéséről ismert a hideg vizekben.';

  @override
  String get species_pilot_whale_name => 'Rövidúszójú gömbölyűfejű delfin';

  @override
  String get species_pilot_whale_desc =>
      'Társas, mélyre merülő cet, amely trópusi és meleg mérsékelt övi tengerekben gyakran nagy csapatokban látható.';

  @override
  String get species_false_killer_whale_name => 'Kis kardszárnyú delfin';

  @override
  String get species_false_killer_whale_desc =>
      'Nagy testű óceáni delfin, amely nyílt vízben olykor megközelíti a búvárokat.';

  @override
  String get species_dugong_name => 'Dugong';

  @override
  String get species_dugong_desc =>
      'Szelíd növényevő, amely az Indo-csendes-óceán tengerifűmezőin legel, a lamantinok közeli rokona.';

  @override
  String get species_west_indian_manatee_name => 'Karibi lamantin';

  @override
  String get species_west_indian_manatee_desc =>
      'Lassú mozgású növényevő a Karib-térség meleg, sekély vizeiben, torkolataiban és forrásaiban.';

  @override
  String get species_sea_otter_name => 'Tengeri vidra';

  @override
  String get species_sea_otter_desc =>
      'Megnyerő tengeri emlős, amely az Észak-Csendes-óceán partja menti moszaterdőkben él.';

  @override
  String get species_california_sea_lion_name => 'Kaliforniai oroszlánfóka';

  @override
  String get species_california_sea_lion_desc =>
      'Játékos és fürge fókaféle, amely a csendes-óceáni partok mentén gyakran barátkozik a búvárokkal.';

  @override
  String get species_steller_sea_lion_name => 'Steller-oroszlánfóka';

  @override
  String get species_steller_sea_lion_desc =>
      'A legnagyobb oroszlánfókafaj, az Észak-Csendes-óceán hideg vizeiben, sziklás partok közelében él.';

  @override
  String get species_harbor_seal_name => 'Borjúfóka';

  @override
  String get species_harbor_seal_desc =>
      'Kíváncsi fóka, gyakran látható mérsékelt övi part menti vizekben, sokszor a merülőhelyek melletti sziklákon pihen.';

  @override
  String get species_grey_seal_name => 'Kúpos fóka';

  @override
  String get species_grey_seal_desc =>
      'Nagy, játékos fóka az Atlanti-óceán északi részén, amely a víz alatt is gyakran megközelíti a búvárokat.';

  @override
  String get species_northern_elephant_seal_name => 'Északi elefántfóka';

  @override
  String get species_northern_elephant_seal_desc =>
      'Hatalmas, mélyre merülő fóka, a hímeknek nagy ormányuk van. A Csendes-óceán keleti partja mentén él.';

  @override
  String get species_hawaiian_monk_seal_name => 'Hawaii barátfóka';

  @override
  String get species_hawaiian_monk_seal_desc =>
      'Súlyosan veszélyeztetett, Hawaii endemikus fókája, amelyet búvárok olykor a zátonyokon látnak.';

  @override
  String get species_leopard_seal_name => 'Leopárdfóka';

  @override
  String get species_leopard_seal_desc =>
      'Erőteljes antarktiszi ragadozó pettyes bundával, hidegvízi búvárok találkoznak vele.';

  @override
  String get species_narwhal_name => 'Narvál';

  @override
  String get species_narwhal_desc =>
      'Sarkvidéki cet hosszú, csavart agyarral, ritkán látható, mégis a tengeri emlősök ikonikus faja.';

  @override
  String get species_green_sea_turtle_name => 'Levesteknős';

  @override
  String get species_green_sea_turtle_desc =>
      'Nagy tengeri teknős, gyakran látható tengerifüvet legelni a trópusi vizekben.';

  @override
  String get species_hawksbill_sea_turtle_name => 'Cserepesteknős';

  @override
  String get species_hawksbill_sea_turtle_desc =>
      'Zátonylakó teknős hegyes csőrrel, amely a korallképződmények között szivacsokkal táplálkozik.';

  @override
  String get species_loggerhead_sea_turtle_name => 'Álcserepesteknős';

  @override
  String get species_loggerhead_sea_turtle_desc =>
      'Nagy fejű teknős a mérsékelt övi és trópusi tengerekben, gyakran sziklás zátonyok közelében.';

  @override
  String get species_leatherback_sea_turtle_name => 'Kérgesteknős';

  @override
  String get species_leatherback_sea_turtle_desc =>
      'A legnagyobb élő teknős rugalmas, bőrszerű páncéllal, amely rendkívüli mélységekbe is lemerül.';

  @override
  String get species_olive_ridley_sea_turtle_name => 'Olajzöld teknős';

  @override
  String get species_olive_ridley_sea_turtle_desc =>
      'A legkisebb tengeriteknős-faj, amely az arribada néven ismert összehangolt tömeges fészkeléseiről híres.';

  @override
  String get species_kemps_ridley_sea_turtle_name => 'Kemp-teknős';

  @override
  String get species_kemps_ridley_sea_turtle_desc =>
      'Súlyosan veszélyeztetett tengeri teknős, amely elsősorban a Mexikói-öbölben él.';

  @override
  String get species_flatback_sea_turtle_name => 'Laposhátú teknős';

  @override
  String get species_flatback_sea_turtle_desc =>
      'Az ausztrál vizek endemikus faja, amelyet lapos páncélja és part menti élőhelye különböztet meg.';

  @override
  String get species_brain_coral_name => 'Agykorall';

  @override
  String get species_brain_coral_desc =>
      'Hatalmas zátonyépítő korall barázdált felszínnel, amely egy agyra emlékeztet, gyakori a karibi zátonyokon.';

  @override
  String get species_staghorn_coral_name => 'Agancskorall';

  @override
  String get species_staghorn_coral_desc =>
      'Gyorsan növő, elágazó korall, amely sűrű bozótokat alkot, a zátonyi halak létfontosságú élőhelye.';

  @override
  String get species_elkhorn_coral_name => 'Jávorszarvas-korall';

  @override
  String get species_elkhorn_coral_desc =>
      'Nagy, elágazó korall lapos, tenyeres ágakkal, a Karib-tenger egyik kulcsfontosságú zátonyépítője.';

  @override
  String get species_table_coral_name => 'Asztalkorall';

  @override
  String get species_table_coral_desc =>
      'Lapos, táblát formáló korall az indo-csendes-óceáni zátonyokon, számos halfajnak nyújt menedéket.';

  @override
  String get species_mushroom_coral_name => 'Gombakorall';

  @override
  String get species_mushroom_coral_desc =>
      'Szabadon élő, magányos, korong alakú korall az indo-csendes-óceáni zátonyok melletti homokos részeken.';

  @override
  String get species_bubble_coral_name => 'Buborékkorall';

  @override
  String get species_bubble_coral_desc =>
      'Jellegzetes korall szőlőszemre emlékeztető hólyagokkal, amelyek nappal felfúvódva gyűjtik a fényt.';

  @override
  String get species_plate_coral_name => 'Tányérkorall';

  @override
  String get species_plate_coral_desc =>
      'Vékony, lemezes korall, amely örvénylő polcokat alkot, gyakori az indo-csendes-óceáni zátonylejtőkön.';

  @override
  String get species_pillar_coral_name => 'Oszlopkorall';

  @override
  String get species_pillar_coral_desc =>
      'Ritka, felfelé növő korall, amely magas oszlopokat alkot, a Karib-tengeren él.';

  @override
  String get species_star_coral_name => 'Csillagkorall';

  @override
  String get species_star_coral_desc =>
      'A Karib-tenger egyik fő zátonyépítője, nagy, sziklatömb alakú telepeket alkot csillag alakú polipokkal.';

  @override
  String get species_lettuce_coral_name => 'Salátakorall';

  @override
  String get species_lettuce_coral_desc =>
      'Vékony, lemezes korall levélszerű redőkkel, gyakori a karibi zátonyfalakon és lejtőkön.';

  @override
  String get species_finger_coral_name => 'Ujjkorall';

  @override
  String get species_finger_coral_desc =>
      'Erős, elágazó korall vastag, ujjszerű nyúlványokkal, sekély zátonyokon él.';

  @override
  String get species_massive_porites_name => 'Tömör Porites korall';

  @override
  String get species_massive_porites_desc =>
      'Nagy, sziklatömb alakú korall, amely évszázadokig növekedhet, az Indo-csendes-óceán meghatározó zátonyépítője.';

  @override
  String get species_cauliflower_coral_name => 'Karfiolkorall';

  @override
  String get species_cauliflower_coral_desc =>
      'Tömör, elágazó korall karfiolszerű alakkal, széles körben elterjedt a trópusi zátonyok sekély vizeiben.';

  @override
  String get species_flower_pot_coral_name => 'Virágcserép korall';

  @override
  String get species_flower_pot_coral_desc =>
      'Hosszú csápú polipokból álló telep, amelyek nappal kinyúlva egy virágcsokorra emlékeztetnek.';

  @override
  String get species_cup_coral_name => 'Narancssárga kehelykorall';

  @override
  String get species_cup_coral_desc =>
      'Élénk narancssárga, nem fotoszintetizáló korall a trópusi vizek falain és túlnyúlásai alatt.';

  @override
  String get species_scroll_coral_name => 'Tekercskorall';

  @override
  String get species_scroll_coral_desc =>
      'Nagy, tekercsszerű lemezeket alkotó korall, gyakori az indo-csendes-óceáni zátonylejtőkön és lagúnákban.';

  @override
  String get species_cabbage_coral_name => 'Káposztakorall';

  @override
  String get species_cabbage_coral_desc =>
      'Korong alakú, lemezes korall, amely káposztalevelekre emlékeztet, védett zátonyterületeken él.';

  @override
  String get species_hammer_coral_name => 'Kalapácskorall';

  @override
  String get species_hammer_coral_desc =>
      'Nagy polipú korall horgony vagy kalapács alakú csápvégekkel, kedvelt látvány az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_torch_coral_name => 'Fáklyakorall';

  @override
  String get species_torch_coral_desc =>
      'Elágazó korall hosszú, hullámzó csápokkal, amelyek végén világító gömbök ülnek.';

  @override
  String get species_frogspawn_coral_name => 'Békaikra-korall';

  @override
  String get species_frogspawn_coral_desc =>
      'Nagy polipú korall elágazó csápvégekkel, amelyek békaikrára emlékeztetnek.';

  @override
  String get species_sea_fan_name => 'Közönséges tengeri legyező';

  @override
  String get species_sea_fan_desc =>
      'Lapos, legyező alakú gorgónia, amely az áramlásra merőlegesen áll, a karibi zátonyok ikonikus látványa.';

  @override
  String get species_venus_sea_fan_name => 'Vénusz tengeri legyező';

  @override
  String get species_venus_sea_fan_desc =>
      'Finom, legyező alakú gorgónia a sekély karibi zátonyokon, mérsékelt áramlású területeken.';

  @override
  String get species_deepwater_sea_fan_name => 'Mélyvízi tengeri legyező';

  @override
  String get species_deepwater_sea_fan_desc =>
      'Nagy, bokros gorgónia a Karib-tenger mély zátonyfalain.';

  @override
  String get species_sea_whip_name => 'Tengeri ostor';

  @override
  String get species_sea_whip_desc =>
      'Karcsú, pálca alakú gorgónia, amely az atlanti és karibi zátonyokon az áramlatban ring.';

  @override
  String get species_sea_plume_name => 'Tengeri tollbokréta';

  @override
  String get species_sea_plume_desc =>
      'Magas, tollas gorgónia, amely bokrétaszerű telepeket alkot a karibi zátonytetőkön.';

  @override
  String get species_organ_pipe_coral_name => 'Orgonasípkorall';

  @override
  String get species_organ_pipe_coral_desc =>
      'Élénkvörös vázcsövek finom polipokkal, védett indo-csendes-óceáni zátonyokon él.';

  @override
  String get species_leather_coral_name => 'Bőrkorall';

  @override
  String get species_leather_coral_desc =>
      'Lágykorall sima, bőrszerű felszínnel, amely nagy, gomba alakú telepeket alkot.';

  @override
  String get species_toadstool_leather_coral_name => 'Gombakalapos bőrkorall';

  @override
  String get species_toadstool_leather_coral_desc =>
      'Lágykorall vastag nyéllel és lapos kalappal, gyakori az indo-csendes-óceáni zátonylapokon.';

  @override
  String get species_pulsing_xenia_name => 'Lüktető xenia';

  @override
  String get species_pulsing_xenia_desc =>
      'Lágykorall ütemesen lüktető polipokkal, védett indo-csendes-óceáni vizekben él.';

  @override
  String get species_tree_coral_name => 'Fakorall';

  @override
  String get species_tree_coral_desc =>
      'Élénk színű lágykorall, amely fa alakú csoportokat alkot a Vörös-tenger falain és túlnyúlásai alatt.';

  @override
  String get species_blue_coral_name => 'Kékkorall';

  @override
  String get species_blue_coral_desc =>
      'Egyedülálló nyolcosztatú korall kék vázzal, a sekély indo-csendes-óceáni zátonylapokon él.';

  @override
  String get species_black_coral_name => 'Feketekorall';

  @override
  String get species_black_coral_desc =>
      'Mélyvízi korall sötét vázzal, falakon és letöréseken, 30 méter alatt található.';

  @override
  String get species_carnation_coral_name => 'Szegfűkorall';

  @override
  String get species_carnation_coral_desc =>
      'Élénk színű lágykorall, amely az Indo-csendes-óceánon a sziklapárkányok alatt és a falakon él.';

  @override
  String get species_wire_coral_name => 'Drótkorall';

  @override
  String get species_wire_coral_desc =>
      'Hosszú, spirális feketekorall, amely csavart ostorokat alkot, gébeknek és garnéláknak ad otthont.';

  @override
  String get species_dead_mans_fingers_name => 'Halottujj-korall';

  @override
  String get species_dead_mans_fingers_desc =>
      'Húsos lágykorall ujjszerű karéjokkal, gyakori az Atlanti-óceán északi részének mérsékelt övi zátonyain.';

  @override
  String get species_sun_coral_name => 'Napkorall';

  @override
  String get species_sun_coral_desc =>
      'Sárgásnarancs, nem fotoszintetizáló korall, amely éjszaka nyitja ki polipjait az indo-csendes-óceáni falakon.';

  @override
  String get species_lace_coral_name => 'Csipkekorall';

  @override
  String get species_lace_coral_desc =>
      'Finom rózsaszín hidrakorall csipkeszerű ágakkal, repedésekben és sziklapárkányok alatt él.';

  @override
  String get species_kenya_tree_coral_name => 'Kenyai fakorall';

  @override
  String get species_kenya_tree_coral_desc =>
      'Szívós lágykorall fa alakú ágakkal, gyakori az Indo-csendes-óceánon.';

  @override
  String get species_colt_coral_name => 'Csikókorall';

  @override
  String get species_colt_coral_desc =>
      'Lágykorall vastag, gumiszerű ágakkal, amelyeket apró polipok borítanak az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_turtle_grass_name => 'Teknősfű';

  @override
  String get species_turtle_grass_desc =>
      'A Karib-tenger meghatározó tengerifüve széles, lapos levelekkel, a tengeri teknősök létfontosságú tápláléka.';

  @override
  String get species_eelgrass_name => 'Tengeri angolnafű';

  @override
  String get species_eelgrass_desc =>
      'Mérsékelt övi tengerifű, amely sűrű víz alatti réteket alkot, és fontos ivadéknevelő élőhely.';

  @override
  String get species_manatee_grass_name => 'Lamantinfű';

  @override
  String get species_manatee_grass_desc =>
      'Hengeres levelű tengerifű a Karib-tenger homokos részein, gyakran teknősfűmezők közelében.';

  @override
  String get species_shoal_grass_name => 'Zátonyfű';

  @override
  String get species_shoal_grass_desc =>
      'Úttörő tengerifű keskeny levelekkel, amely a Karib-tengeren a bolygatott homokos területeket népesíti be.';

  @override
  String get species_paddle_grass_name => 'Lapátfű';

  @override
  String get species_paddle_grass_desc =>
      'Kis, finom tengerifű ovális levelekkel, a trópusokon mélyebb vizekben fordul elő.';

  @override
  String get species_neptune_grass_name => 'Neptunfű';

  @override
  String get species_neptune_grass_desc =>
      'Földközi-tengeri tengerifű, amely hatalmas réteket alkot, és létfontosságú a part menti tengeri ökoszisztémák számára.';

  @override
  String get species_giant_kelp_name => 'Óriásmoszat';

  @override
  String get species_giant_kelp_desc =>
      'Akár 60 méter magasra növő víz alatti erdőalkotó faj, a kaliforniai merülések ikonikus növénye.';

  @override
  String get species_bull_kelp_name => 'Bikamoszat';

  @override
  String get species_bull_kelp_desc =>
      'Csendes-óceáni moszat egyetlen hosszú nyéllel és gömbölyű úszóhólyaggal, sűrű lombkoronaerdőket alkot.';

  @override
  String get species_bladder_wrack_name => 'Hólyagos moszat';

  @override
  String get species_bladder_wrack_desc =>
      'Gyakori barnamoszat páros léghólyagokkal, az Atlanti-óceán északi részének árapályzónájában él.';

  @override
  String get species_sargassum_name => 'Szargasszumhínár';

  @override
  String get species_sargassum_desc =>
      'Szabadon lebegő barnamoszat, amely tutajokat alkot, és menedéket nyújt a fiatal halaknak és gerincteleneknek.';

  @override
  String get species_kelp_forest_ecklonia_name => 'Ecklonia moszat';

  @override
  String get species_kelp_forest_ecklonia_desc =>
      'A déli félteke vizeinek meghatározó moszatja, amely fontos víz alatti erdőket alkot.';

  @override
  String get species_coralline_algae_name => 'Korallmoszat';

  @override
  String get species_coralline_algae_desc =>
      'Kemény, bevonatot képző vörösmoszat, amely összecementezi a zátony szerkezetét, és rózsaszín árnyalatot ad neki.';

  @override
  String get species_irish_moss_name => 'Ír moszat';

  @override
  String get species_irish_moss_desc =>
      'Legyező alakú vörösmoszat az Atlanti-óceán északi részének sziklás partjain, az árapályzónában.';

  @override
  String get species_dulse_name => 'Tenyeres vörösmoszat';

  @override
  String get species_dulse_desc =>
      'Lapos, vörösesbíbor moszat, amely sziklákon és moszatnyeleken nő a hideg északi vizekben.';

  @override
  String get species_halimeda_name => 'Halimeda';

  @override
  String get species_halimeda_desc =>
      'Meszes zöldmoszat korong alakú szelvényekkel, jelentős mértékben hozzájárul a zátonyhomok képződéséhez.';

  @override
  String get species_sea_lettuce_name => 'Tengeri saláta';

  @override
  String get species_sea_lettuce_desc =>
      'Élénkzöld, lemezes moszat, világszerte sekély part menti vizekben él.';

  @override
  String get species_caulerpa_name => 'Zöld szőlőmoszat';

  @override
  String get species_caulerpa_desc =>
      'Kúszó zöldmoszat szőlőszemre emlékeztető ágakkal, trópusi zátonytörmeléken és homokon él.';

  @override
  String get species_mermaid_fan_name => 'Sellőlegyező';

  @override
  String get species_mermaid_fan_desc =>
      'Meszes zöldmoszat kis legyező alakjával, gyakori a karibi homokos fenéken.';

  @override
  String get species_shaving_brush_algae_name => 'Borotvapamacs moszat';

  @override
  String get species_shaving_brush_algae_desc =>
      'Meszes zöldmoszat nyélen ülő, ecsetszerű bojttal, a karibi homokos fenéken él.';

  @override
  String get species_finger_kelp_name => 'Ujjas moszat';

  @override
  String get species_finger_kelp_desc =>
      'Barnamoszat ujjszerű levelekkel, amely moszatágyakat alkot az Atlanti-óceán északi részének part menti vizeiben.';

  @override
  String get species_banded_sea_krait_name => 'Sávos tengeri krajt';

  @override
  String get species_banded_sea_krait_desc =>
      'Mérges tengeri kígyó kékesszürke és fekete sávokkal, szelíd természetű, gyakran látható az indo-csendes-óceáni zátonyokon.';

  @override
  String get species_olive_sea_snake_name => 'Olívzöld tengeri kígyó';

  @override
  String get species_olive_sea_snake_desc =>
      'Kíváncsi tengeri kígyó az ausztrál zátonyokon, amely gyakran közelít a búvárokhoz.';

  @override
  String get species_yellow_bellied_sea_snake_name => 'Sárgahasú tengeri kígyó';

  @override
  String get species_yellow_bellied_sea_snake_desc =>
      'Nyíltvízi tengeri kígyó sárga hassal, a Föld legelterjedtebb kígyófaja.';

  @override
  String get species_marine_iguana_name => 'Tengeri leguán';

  @override
  String get species_marine_iguana_desc =>
      'A Galápagos endemikus faja, az egyetlen gyík, amely a víz alatt algával táplálkozik.';

  @override
  String get species_saltwater_crocodile_name => 'Bordás krokodil';

  @override
  String get species_saltwater_crocodile_desc =>
      'A legnagyobb élő hüllő, amely az Indo-csendes-óceán part menti és torkolati vizeiben él.';

  @override
  String get common_action_done => 'Kész';

  @override
  String get common_action_more => 'Továbbiak';

  @override
  String get common_label_displayName => 'Megjelenítendő név';

  @override
  String common_relativeTime_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count napja',
      one: '$count napja',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count órája',
      one: '$count órája',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nap múlva',
      one: '$count nap múlva',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_inHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count óra múlva',
      one: '$count óra múlva',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_inLessThanMinute => '<1 perc múlva';

  @override
  String common_relativeTime_inMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perc múlva',
      one: '$count perc múlva',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_justNow => 'éppen most';

  @override
  String common_relativeTime_minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perce',
      one: '$count perce',
    );
    return '$_temp0';
  }

  @override
  String common_relativeTime_monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hónapja',
      one: '$count hónapja',
    );
    return '$_temp0';
  }

  @override
  String get common_relativeTime_overdue => 'lejárt';

  @override
  String get media_cache_calculating => 'Gyorsítótár méretének kiszámítása…';

  @override
  String get media_cache_cardTitle => 'Gyorsítótár kezelése';

  @override
  String get media_cache_clearAction => 'Gyorsítótár törlése';

  @override
  String get media_cache_clearBody =>
      'Törli a letöltött indexképeket és a teljes méretű hálózati képeket. A csatolt médiabejegyzések megmaradnak; a képek a következő megtekintéskor újra letöltődnek.';

  @override
  String get media_cache_clearConfirm => 'Törlés';

  @override
  String media_cache_clearError(String error) {
    return 'A törlés sikertelen: $error';
  }

  @override
  String get media_cache_clearTitle => 'Törli a hálózati képek gyorsítótárát?';

  @override
  String get media_cache_cleared => 'A gyorsítótár törölve';

  @override
  String get media_cache_diskCache => 'Lemezes gyorsítótár';

  @override
  String media_cache_error(String error) {
    return 'Hiba: $error';
  }

  @override
  String get media_credentials_actionTest => 'Hitelesítő adatok tesztelése';

  @override
  String media_credentials_authLabel(String authType) {
    return 'Hitelesítés: $authType';
  }

  @override
  String get media_credentials_deleteBody =>
      'Törli a mentett hitelesítő adatokat. Az ezen a kiszolgálón keresztül csatolt elemeknél a „Bejelentkezés szükséges” felirat jelenik meg, amíg újra hozzá nem adja őket.';

  @override
  String media_credentials_deleteError(String error) {
    return 'A törlés sikertelen: $error';
  }

  @override
  String media_credentials_deleteTitle(String host) {
    return 'Törli a következőt: $host?';
  }

  @override
  String media_credentials_deleted(String host) {
    return '$host törölve';
  }

  @override
  String media_credentials_editTitle(String host) {
    return '$host szerkesztése';
  }

  @override
  String get media_credentials_emptySubtitle =>
      'Az URL- vagy manifeszt-importálás során hozzáadott, kiszolgálónkénti hitelesítő adatok itt jelennek meg.';

  @override
  String get media_credentials_emptyTitle =>
      'Nincsenek mentett hitelesítő adatok';

  @override
  String media_credentials_lastUsed(String when) {
    return 'Utoljára használva: $when';
  }

  @override
  String get media_credentials_loadError =>
      'Nem sikerült betölteni a mentett kiszolgálókat';

  @override
  String get media_credentials_loading => 'Mentett kiszolgálók betöltése...';

  @override
  String media_credentials_saveError(String error) {
    return 'A mentés sikertelen: $error';
  }

  @override
  String get media_credentials_savedHostsTitle => 'Mentett kiszolgálók';

  @override
  String media_credentials_testError(String error) {
    return 'A teszt sikertelen: $error';
  }

  @override
  String media_credentials_testFailed(String host) {
    return 'A hitelesítő adatok nem működnek ehhez: $host';
  }

  @override
  String media_credentials_testOk(String host) {
    return 'A hitelesítő adatok rendben vannak ehhez: $host';
  }

  @override
  String get media_manifest_actionPollNow => 'Lekérdezés most';

  @override
  String get media_manifest_cardTitle => 'Manifeszt-feliratkozások';

  @override
  String get media_manifest_deleteBody =>
      'Törli a feliratkozást. A már importált bejegyzések megmaradnak (az árva elemek sorában takaríthatja ki őket).';

  @override
  String media_manifest_deleteError(String error) {
    return 'A törlés sikertelen: $error';
  }

  @override
  String media_manifest_deleteTitle(String name) {
    return 'Törli a következőt: $name?';
  }

  @override
  String get media_manifest_editTitle => 'Feliratkozás szerkesztése';

  @override
  String get media_manifest_emptySubtitle =>
      'Iratkozzon fel egy Atom/RSS, JSON vagy CSV manifesztre az URL lapon, hogy a könyvtára szinkronban maradjon.';

  @override
  String get media_manifest_emptyTitle => 'Nincsenek manifeszt-feliratkozások';

  @override
  String media_manifest_lastError(String error) {
    return 'Utolsó hiba: $error';
  }

  @override
  String media_manifest_lastPolled(String when) {
    return 'Utolsó lekérdezés: $when';
  }

  @override
  String get media_manifest_loadError =>
      'Nem sikerült betölteni a feliratkozásokat';

  @override
  String get media_manifest_loading => 'Feliratkozások betöltése...';

  @override
  String get media_manifest_neverPolled => 'Még nem volt lekérdezve';

  @override
  String media_manifest_nextPoll(String when) {
    return 'Következő: $when';
  }

  @override
  String get media_manifest_notFound => 'A feliratkozás nem található';

  @override
  String media_manifest_pollError(String error) {
    return 'A lekérdezés sikertelen: $error';
  }

  @override
  String media_manifest_polled(String name) {
    return '$name lekérdezve';
  }

  @override
  String media_manifest_polling(String name) {
    return '$name lekérdezése...';
  }

  @override
  String media_manifest_saveError(String error) {
    return 'A mentés sikertelen: $error';
  }

  @override
  String media_manifest_updateError(String error) {
    return 'Nem sikerült frissíteni: $error';
  }

  @override
  String get media_manifest_urlLabel => 'Manifeszt URL';

  @override
  String media_scan_failed(String error) {
    return 'Az átvizsgálás sikertelen: $error';
  }

  @override
  String media_scan_progressItems(int done, int total) {
    return '$done / $total elem';
  }

  @override
  String media_scan_progressReachability(int available, int unreachable) {
    return '$available elérhető  ·  $unreachable nem érhető el';
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
          '$total elem átvizsgálva $seconds mp alatt: $available elérhető, $unreachable nem érhető el',
      one:
          '$total elem átvizsgálva $seconds mp alatt: $available elérhető, $unreachable nem érhető el',
    );
    return '$_temp0';
  }

  @override
  String media_scan_summarySkipped(String base, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kihagyva (nincs URL)',
      one: '$count kihagyva (nincs URL)',
    );
    return '$base, $_temp0';
  }

  @override
  String get media_scan_title => 'Az összes hálózati média átvizsgálása';

  @override
  String get settings_mediaSources_androidUriTitle => 'Android URI-engedélyek';

  @override
  String settings_mediaSources_androidUriUsage(int used, int limit) {
    return '$used / $limit tartós URI használatban';
  }

  @override
  String get settings_mediaSources_counting => 'Számlálás…';

  @override
  String settings_mediaSources_error(String error) {
    return 'Hiba: $error';
  }

  @override
  String get settings_mediaSources_loading => 'Betöltés…';

  @override
  String settings_mediaSources_localFilesCounts(
    int available,
    int unavailable,
  ) {
    return '$available elérhető, $unavailable nem érhető el';
  }

  @override
  String get settings_mediaSources_photoLibrarySubtitle =>
      'Apple Photos / Google Photos / iCloud';

  @override
  String get settings_mediaSources_reverifyAll =>
      'Az összes helyi fájl újraellenőrzése';

  @override
  String settings_mediaSources_reverifyFailed(String error) {
    return 'Az újraellenőrzés sikertelen: $error';
  }

  @override
  String settings_mediaSources_reverifyResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elem frissítve',
      one: '$count elem frissítve',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_checkAll => 'Az összes média ellenőrzése';

  @override
  String settings_mediaSources_checkAllResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elem frissítve',
      one: '$count elem frissítve',
    );
    return '$_temp0';
  }

  @override
  String settings_mediaSources_checkAllBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'A(z) $count elem egyikét sem sikerült ellenőrizni. A forrásaik jelenleg nem érhetők el.',
      one:
          'Az elemet nem sikerült ellenőrizni. A forrása jelenleg nem érhető el.',
    );
    return '$_temp0';
  }

  @override
  String get settings_mediaSources_title => 'Médiaforrások';

  @override
  String get settings_networkSources_scanDescription =>
      'Újra ellenőrzi minden URL-ről vagy manifesztből importált fotót a kiszolgálójánál. A nem elérhető elemeket megjelöli, így a könyvtárban „hiányzó” állapotban jelennek meg, és kitakaríthatók.';

  @override
  String statistics_conditions_entryMethod_semanticLabel(String description) {
    return 'Oszlopdiagram. Belépési módszerek. $description';
  }

  @override
  String statistics_conditions_visibility_semanticLabel(String description) {
    return 'Kördiagram. A látási viszonyok megoszlása. $description';
  }

  @override
  String statistics_conditions_waterType_semanticLabel(String description) {
    return 'Kördiagram. A víztípus megoszlása. $description';
  }

  @override
  String statistics_progression_divesBySuitThickness_semanticLabel(
    String description,
  ) {
    return 'Oszlopdiagram. Merülések ruhavastagság szerint. $description';
  }

  @override
  String statistics_progression_divesPerYear_countInYear(
    int count,
    String year,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$year: $count merülés',
      one: '$year: 1 merülés',
    );
    return '$_temp0';
  }

  @override
  String statistics_progression_divesPerYear_semanticLabel(String description) {
    return 'Oszlopdiagram. Merülések évenként. $description';
  }

  @override
  String get statistics_records_unavailable => 'A rekordok nem érhetők el';

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
  String get statistics_summary_distributions_title => 'Megoszlások';

  @override
  String get statistics_summary_diveTypes_error =>
      'Nem sikerült betölteni a merülési típusok adatait';

  @override
  String get statistics_summary_diveTypes_unknown => 'Ismeretlen';

  @override
  String get statistics_summary_divesPerMonth => 'Merülés / hónap';

  @override
  String get statistics_summary_divesPerYear => 'Merülés / év';

  @override
  String statistics_timePatterns_dayOfWeek_semanticLabel(String description) {
    return 'Oszlopdiagram. Merülések a hét napjai szerint. $description';
  }

  @override
  String statistics_timePatterns_seasonal_semanticLabel(String description) {
    return 'Oszlopdiagram. Merülések havonta. $description';
  }

  @override
  String statistics_timePatterns_surfaceInterval_statLabel(
    String label,
    String value,
  ) {
    return '$label felszíni szünet: $value';
  }

  @override
  String get statistics_timePatterns_timeOfDay_afternoon => 'Délután';

  @override
  String get statistics_timePatterns_timeOfDay_evening => 'Este';

  @override
  String get statistics_timePatterns_timeOfDay_morning => 'Reggel';

  @override
  String get statistics_timePatterns_timeOfDay_night => 'Éjszaka';

  @override
  String statistics_timePatterns_timeOfDay_semanticLabel(String description) {
    return 'Kördiagram. Merülések napszak szerint. $description';
  }

  @override
  String get columnConfig_displayOptions => 'Megjelenítési beállítások';

  @override
  String get columnConfig_noExtraFields =>
      'Nincsenek extra mezők beállítva. Adjon hozzá mezőket alább.';

  @override
  String get columnConfig_savePresetTitle => 'Előbeállítás mentése';

  @override
  String get columnConfig_section => 'Szakasz';

  @override
  String get columnConfig_showTags => 'Címkék megjelenítése';

  @override
  String get columnConfig_showTags_subtitle =>
      'Címkejelölők megjelenítése a részletes merülési kártyákon';

  @override
  String get columnConfig_slot_date => 'Dátum / Alcím';

  @override
  String get columnConfig_slot_slot1 => '1. hely';

  @override
  String get columnConfig_slot_slot2 => '2. hely';

  @override
  String get columnConfig_slot_slot3 => '3. hely';

  @override
  String get columnConfig_slot_slot4 => '4. hely';

  @override
  String get columnConfig_slot_stat1 => '1. statisztika';

  @override
  String get columnConfig_slot_stat2 => '2. statisztika';

  @override
  String get columnConfig_slot_subtitle => 'Alcím';

  @override
  String get columnConfig_slot_title => 'Cím';

  @override
  String get columnConfig_tooltip_columnSettings => 'Oszlopbeállítások';

  @override
  String get common_action_add => 'Hozzáadás';

  @override
  String get common_action_pin => 'Rögzítés';

  @override
  String get common_action_remove => 'Eltávolítás';

  @override
  String get common_action_unpin => 'Rögzítés feloldása';

  @override
  String diveLog_filterChip_dateRange(String end, String start) {
    return '$start - $end';
  }

  @override
  String diveLog_filterChip_equipmentCount(int count) {
    return '$count felszerelés';
  }

  @override
  String get diveLog_filter_allComputers => 'Minden búvárcomputer';

  @override
  String get diveLog_filter_noComputersRegistered =>
      'Nincs regisztrált búvárcomputer';

  @override
  String diveLog_filter_sectionDepthRangeUnit(String unit) {
    return 'Mélységtartomány ($unit)';
  }

  @override
  String get diveLog_filter_sectionDiveComputer => 'Búvárcomputer';

  @override
  String diveLog_listPage_semanticsDiveAtSite(int diveNumber, String siteName) {
    return '$diveNumber. merülés itt: $siteName';
  }

  @override
  String get enum_listViewMode_compact => 'Tömör';

  @override
  String get enum_listViewMode_dense => 'Sűrű';

  @override
  String get enum_listViewMode_detailed => 'Részletes';

  @override
  String get enum_listViewMode_table => 'Táblázat';

  @override
  String get enum_profileMetric_ascentRate => 'Emelkedési sebesség';

  @override
  String get enum_profileMetric_cns => 'CNS%';

  @override
  String get enum_profileMetric_otu => 'OTU';

  @override
  String get enum_sortField_bottomTime => 'Fenéken töltött idő';

  @override
  String get enum_sortField_serviceDue => 'Esedékes szerviz';

  @override
  String get listViewMode_tooltip => 'Nézet mód';

  @override
  String marineLife_speciesManage_errorLoading(Object error) {
    return 'Hiba a fajok betöltésekor: $error';
  }

  @override
  String get settings_appearance_header_cards => 'Kártyák';

  @override
  String get settings_appearance_header_listView => 'Listanézet';

  @override
  String get settings_appearance_header_tableMode => 'Táblázat mód';

  @override
  String get settings_appearance_listFields_buddies => 'Búvártárs-lista mezői';

  @override
  String get settings_appearance_listFields_certifications =>
      'Képesítéslista mezői';

  @override
  String get settings_appearance_listFields_courses => 'Tanfolyamlista mezői';

  @override
  String get settings_appearance_listFields_diveCenters =>
      'Búvárközpont-lista mezői';

  @override
  String get settings_appearance_listFields_dives => 'Merülési lista mezői';

  @override
  String get settings_appearance_listFields_equipment =>
      'Felszereléslista mezői';

  @override
  String get settings_appearance_listFields_sites => 'Merülőhely-lista mezői';

  @override
  String get settings_appearance_listFields_subtitle =>
      'A listanézetekben megjelenő mezők testreszabása';

  @override
  String get settings_appearance_listFields_trips => 'Utazáslista mezői';

  @override
  String get settings_appearance_listView_buddies => 'Búvártársak listanézete';

  @override
  String get settings_appearance_listView_buddies_subtitle =>
      'A búvártársak listájának alapértelmezett elrendezése';

  @override
  String get settings_appearance_listView_certifications =>
      'Képesítések listanézete';

  @override
  String get settings_appearance_listView_certifications_subtitle =>
      'A képesítések listájának alapértelmezett elrendezése';

  @override
  String get settings_appearance_listView_courses => 'Tanfolyamok listanézete';

  @override
  String get settings_appearance_listView_courses_subtitle =>
      'A tanfolyamok listájának alapértelmezett elrendezése';

  @override
  String get settings_appearance_listView_diveCenters =>
      'Búvárközpontok listanézete';

  @override
  String get settings_appearance_listView_diveCenters_subtitle =>
      'A búvárközpontok listájának alapértelmezett elrendezése';

  @override
  String get settings_appearance_listView_dives => 'Merülések listanézete';

  @override
  String get settings_appearance_listView_dives_subtitle =>
      'A merülések listájának alapértelmezett elrendezése';

  @override
  String get settings_appearance_listView_equipment =>
      'Felszerelés listanézete';

  @override
  String get settings_appearance_listView_equipment_subtitle =>
      'A felszereléslista alapértelmezett elrendezése';

  @override
  String get settings_appearance_listView_sites => 'Merülőhelyek listanézete';

  @override
  String get settings_appearance_listView_sites_subtitle =>
      'A merülőhelyek listájának alapértelmezett elrendezése';

  @override
  String get settings_appearance_listView_trips => 'Utazások listanézete';

  @override
  String get settings_appearance_listView_trips_subtitle =>
      'Az utazások listájának alapértelmezett elrendezése';

  @override
  String get settings_appearance_showDataSourceBadges =>
      'Adatforrás-jelvények megjelenítése';

  @override
  String get settings_appearance_showDataSourceBadges_subtitle =>
      'Forrásmegjelölés megjelenítése a merülési mutatókon';

  @override
  String get settings_appearance_title_buddies => 'Búvártársak megjelenése';

  @override
  String get settings_appearance_title_certifications =>
      'Képesítések megjelenése';

  @override
  String get settings_appearance_title_courses => 'Tanfolyamok megjelenése';

  @override
  String get settings_appearance_title_diveCenters =>
      'Búvárközpontok megjelenése';

  @override
  String get settings_appearance_title_dives => 'Merülések megjelenése';

  @override
  String get settings_appearance_title_equipment => 'Felszerelés megjelenése';

  @override
  String get settings_appearance_title_sites => 'Merülőhelyek megjelenése';

  @override
  String get settings_appearance_title_trips => 'Utazások megjelenése';

  @override
  String get settings_cloudSync_troubleshoot_tileSubtitle =>
      'Elakadt szinkronizálás javítása vagy felhőtárhely felszabadítása';

  @override
  String get settings_data_header_dataTools => 'Adateszközök';

  @override
  String get settings_decompression_ascentGasLabel =>
      'Emelkedés tervezése ezzel';

  @override
  String get settings_decompression_ascentGas_allCarried =>
      'Az összes magunkkal vitt palack';

  @override
  String get settings_decompression_ascentGas_decoStage =>
      'Deko/stage + háti gáz';

  @override
  String get settings_decompression_cnsSource => 'CNS forrása';

  @override
  String get settings_decompression_decoStopSource => 'Dekóstop forrása';

  @override
  String get settings_decompression_header_ascent => 'Emelkedés tervezése';

  @override
  String get settings_decompression_header_ascent_subtitle =>
      'Mely magunkkal vitt palackokra válthat a szimulált emelkedés (TTS, plafon és megállók) az egyes mélységekben. Csak a merülésnél rögzített gázokat veszi figyelembe.';

  @override
  String get settings_decompression_header_dataSources =>
      'Adatforrás-beállítások';

  @override
  String get settings_decompression_header_dataSources_subtitle =>
      'Ha a Búvárcomputer beállítás aktív, az alkalmazás a búvárcomputer által jelentett adatokat használja, amikor elérhetők. Ha nincs computeradat, a számított értékekre vált.';

  @override
  String get settings_decompression_ndlSource => 'NDL forrása';

  @override
  String get settings_decompression_sourceCalculated => 'Számított';

  @override
  String get settings_decompression_sourceComputer => 'Búvárcomputer';

  @override
  String get settings_decompression_ttsSource => 'TTS forrása';

  @override
  String settings_fixDiveTimes_applied(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merülés',
      one: 'merülés',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'órával',
      one: 'órával',
    );
    return '$count $_temp0 frissítve $hours $_temp1.';
  }

  @override
  String settings_fixDiveTimes_apply(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merülésre',
      one: 'merülésre',
    );
    return 'Alkalmazás $count $_temp0';
  }

  @override
  String get settings_fixDiveTimes_clearRange => 'Dátumtartomány törlése';

  @override
  String get settings_fixDiveTimes_confirmApply => 'Alkalmaz';

  @override
  String settings_fixDiveTimes_confirmBody(
    int count,
    String hours,
    int hoursAbs,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merülés',
      one: 'merülés',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'órával',
      one: 'órával',
    );
    return 'Ez $count $_temp0 időpontját tolja el $hours $_temp1. Ezt nem lehet automatikusan visszavonni.';
  }

  @override
  String get settings_fixDiveTimes_confirmTitle => 'Időeltolás alkalmazása';

  @override
  String get settings_fixDiveTimes_dateRangeFilter => 'Dátumtartomány-szűrő';

  @override
  String get settings_fixDiveTimes_deselectAll =>
      'Összes kijelölés megszüntetése';

  @override
  String get settings_fixDiveTimes_diveFallback => 'Merülés';

  @override
  String settings_fixDiveTimes_diveNumber(int number) {
    return '$number. merülés';
  }

  @override
  String get settings_fixDiveTimes_empty => 'Nem található merülés.';

  @override
  String get settings_fixDiveTimes_emptyFiltered =>
      'Nem található merülés ebben a dátumtartományban.';

  @override
  String get settings_fixDiveTimes_enterOffsetHint =>
      'Adjon meg egy óraeltolást';

  @override
  String get settings_fixDiveTimes_from => 'Ettől';

  @override
  String get settings_fixDiveTimes_hourOffset => 'Óraeltolás';

  @override
  String get settings_fixDiveTimes_hoursField => 'Órák (pl. +7, -5)';

  @override
  String settings_fixDiveTimes_loadError(String error) {
    return 'Nem sikerült betölteni a merüléseket: $error';
  }

  @override
  String get settings_fixDiveTimes_noSelection => 'Nincs kijelölt merülés.';

  @override
  String get settings_fixDiveTimes_offsetHint =>
      'Adjon meg egy pozitív vagy negatív egész számot a merülési időpontok eltolásához.';

  @override
  String settings_fixDiveTimes_preview(int count, String hours, int hoursAbs) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'merülés',
      one: 'merülés',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hoursAbs,
      locale: localeName,
      other: 'órával',
      one: 'órával',
    );
    return 'Előnézet: $count $_temp0 tolódik el $hours $_temp1.';
  }

  @override
  String get settings_fixDiveTimes_selectAll => 'Összes kijelölése';

  @override
  String get settings_fixDiveTimes_selectDivesHint =>
      'Válassza ki az érintett merüléseket';

  @override
  String get settings_fixDiveTimes_subtitle =>
      'Importált merülések időpontjainak módosítása';

  @override
  String get settings_fixDiveTimes_title => 'Merülési időpontok javítása';

  @override
  String get settings_fixDiveTimes_to => 'Eddig';

  @override
  String get settings_fixDiveTimes_zeroOffset =>
      'Az óraeltolás 0, nincs mit módosítani.';

  @override
  String get settings_syncDevices_appBar_refreshTooltip => 'Frissítés';

  @override
  String get settings_syncDevices_appBar_title =>
      'Eszközök ezen a szolgáltatón';

  @override
  String get settings_syncDevices_empty =>
      'Nincsenek szinkronizálási fájlok ezen a szolgáltatón.';

  @override
  String settings_syncDevices_readError(String error) {
    return 'Nem sikerült olvasni a szolgáltatót.\n$error';
  }

  @override
  String get settings_syncDevices_removal_noBackend =>
      'Nincs beállítva felhőszolgáltató';

  @override
  String get settings_syncDevices_removal_unreachable =>
      'A szolgáltató nem érhető el. Semmi sem lett eltávolítva.';

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
          'Ez törli a(z) $name eszközhöz tartozó $count fájlt ($size).\n\nAz az eszköz továbbra is része ennek a szinkronizálásnak. Ha újra online lesz, a szolgáltatóból építi újra magát, nem támasztja fel a régi adatokat, de minden még nem publikált módosítása elveszik. Az EZEN az eszközön lévő merülési adatait ez nem érinti.',
      one:
          'Ez törli a(z) $name eszközhöz tartozó 1 fájlt ($size).\n\nAz az eszköz továbbra is része ennek a szinkronizálásnak. Ha újra online lesz, a szolgáltatóból építi újra magát, nem támasztja fel a régi adatokat, de minden még nem publikált módosítása elveszik. Az EZEN az eszközön lévő merülési adatait ez nem érinti.',
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
          'Ez törli a(z) $name eszközhöz tartozó $count fájlt ($size). Ezek egy olyan könyvtárból maradtak vissza, amelyből már egyetlen eszköz sem szinkronizál. A merülési adatait ez nem érinti.',
      one:
          'Ez törli a(z) $name eszközhöz tartozó 1 fájlt ($size). Ezek egy olyan könyvtárból maradtak vissza, amelyből már egyetlen eszköz sem szinkronizál. A merülési adatait ez nem érinti.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_removeDialog_title(String name) {
    return '$name fájljainak eltávolítása?';
  }

  @override
  String settings_syncDevices_removeProgressTitle(String name) {
    return '$name fájljainak eltávolítása folyamatban';
  }

  @override
  String get settings_syncDevices_removeTooltip =>
      'Ezen eszköz fájljainak eltávolítása';

  @override
  String get settings_syncDevices_state_active => 'Normálisan szinkronizál';

  @override
  String get settings_syncDevices_state_retired => 'Kivonva';

  @override
  String get settings_syncDevices_state_staleEpoch =>
      'Egy korábbi könyvtárból maradt vissza; egyetlen eszköz sem olvassa';

  @override
  String get settings_syncDevices_state_thisDevice => 'Ez az eszköz';

  @override
  String get settings_syncDevices_state_unreadable =>
      'Nincs olvasható jegyzék; befejezetlen feltöltés vagy titkosított';

  @override
  String settings_syncDevices_summary(
    int deviceCount,
    int fileCount,
    String size,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      deviceCount,
      locale: localeName,
      other: '$deviceCount eszköz',
      one: '1 eszköz',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fileCount,
      locale: localeName,
      other: '$fileCount fájl',
      one: '1 fájl',
    );
    return '$_temp0, $_temp1, $size';
  }

  @override
  String settings_syncDevices_summary_removable(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count maradvány egy lecserélt vagy kivont könyvtárból, $size méretben.',
      one: '1 maradvány egy lecserélt vagy kivont könyvtárból, $size méretben.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncDevices_tile_filesSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fájl',
      one: '1 fájl',
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
      other: '$count fájl',
      one: '1 fájl',
    );
    return '$_temp0, $size · $when';
  }

  @override
  String settings_syncDevices_unnamedDevice(String shortId) {
    return '$shortId eszköz';
  }

  @override
  String get settings_syncMaintenance_keepAppOpen =>
      'Tartsa nyitva az alkalmazást, amíg ez be nem fejeződik. Ha most bezárja, a szolgáltató csak részben lesz kitakarítva, és a következő szinkronizálásnak elölről kell kezdenie.';

  @override
  String get settings_syncMaintenance_phase_clearingOldFiles =>
      'Régi fájlok törlése';

  @override
  String get settings_syncMaintenance_phase_deleting => 'Törlés';

  @override
  String get settings_syncMaintenance_phase_publishingLibrary =>
      'Könyvtár közzététele';

  @override
  String get settings_cloudSync_adopt_progressTitle =>
      'A visszaállított könyvtár átvétele';

  @override
  String get settings_cloudSync_replaceLibrary_progressTitle =>
      'A felhőkönyvtár cseréje';

  @override
  String settings_syncDevices_nameWithId(String name, String shortId) {
    return '$name ($shortId)';
  }

  @override
  String get settings_syncMaintenance_phase_applyingLibrary =>
      'Könyvtár alkalmazása';

  @override
  String get settings_syncMaintenance_phase_backingUp =>
      'Az eszköz biztonsági mentése';

  @override
  String get settings_syncMaintenance_phase_repairing =>
      'Helyi szinkronizálási állapot törlése';

  @override
  String get settings_troubleshootSync_repair_progressTitle =>
      'A szinkronizálás javítása';

  @override
  String get settings_syncMaintenance_phase_working => 'Feldolgozás...';

  @override
  String settings_syncMaintenance_progress_filesOfTotal(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done / $total fájl',
      one: '$done / 1 fájl',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_removedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fájl eltávolítva',
      one: '1 fájl eltávolítva',
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
          '$count fájl eltávolítva, de $trouble. Próbálja újra online állapotban.',
      one: '1 fájl eltávolítva, de $trouble. Próbálja újra online állapotban.',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_trouble_failed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nem volt törölhető',
      one: '1 nem volt törölhető',
    );
    return '$_temp0';
  }

  @override
  String get settings_syncMaintenance_trouble_listIncomplete =>
      'néhány fájlt nem sikerült listázni';

  @override
  String settings_syncMaintenance_wipedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fájl kitörölve',
      one: '1 fájl kitörölve',
    );
    return '$_temp0';
  }

  @override
  String settings_syncMaintenance_wipedFilesPartial(int count, String trouble) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count fájl kitörölve, de $trouble. Próbálja újra online állapotban.',
      one: '1 fájl kitörölve, de $trouble. Próbálja újra online állapotban.',
    );
    return '$_temp0';
  }

  @override
  String get settings_troubleshootSync_appBar_title =>
      'Szinkronizálási hibaelhárítás';

  @override
  String get settings_troubleshootSync_devices_subtitle =>
      'Nézze meg, mely eszközök tárolnak itt fájlokat, mennyi helyet foglal mindegyik, és távolítsa el az olyan könyvtárak maradványait, amelyekből már egyetlen eszköz sem szinkronizál. A merülési adatait ez nem érinti.';

  @override
  String get settings_troubleshootSync_rebuild_confirm => 'Újraépítés';

  @override
  String get settings_troubleshootSync_rebuild_confirmBody =>
      'Ez az eszköz könyvtárát teszi az aktuálissá a szolgáltatón, és újra közzéteszi, így a többi eszköz Öntől szinkronizál. Akkor használja, ha egy másik eszköztől érkező csere elakadt. A merülési adatait ez nem érinti.';

  @override
  String get settings_troubleshootSync_rebuild_confirmTitle =>
      'Újraépíti a szolgáltatót erről az eszközről?';

  @override
  String get settings_troubleshootSync_rebuild_doneSnack =>
      'A szolgáltató újraépítve erről az eszközről';

  @override
  String get settings_troubleshootSync_rebuild_failedSnack =>
      'Az újraépítés sikertelen';

  @override
  String get settings_troubleshootSync_rebuild_progressTitle =>
      'A szolgáltató újraépítése';

  @override
  String get settings_troubleshootSync_rebuild_subtitle =>
      'Akkor használja, ha a szinkronizálás elakadt egy olyan könyvtárra várva, amelyet egy másik eszköz lecserélt, de a feltöltést sosem fejezte be (lehet, hogy az az eszköz offline). Ennek az eszköznek a könyvtárát teszi közzé aktuálisként.';

  @override
  String get settings_troubleshootSync_rebuild_title =>
      'A szolgáltató újraépítése erről az eszközről';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmBody =>
      'Ez csak ennek az eszköznek a szinkronizálási fájljait törli a szolgáltatóról. A többi eszköz tovább szinkronizál, és a merülési adatait ez nem érinti.';

  @override
  String get settings_troubleshootSync_removeThisDevice_confirmTitle =>
      'Eltávolítja ennek az eszköznek a felhőfájljait?';

  @override
  String get settings_troubleshootSync_removeThisDevice_progressTitle =>
      'Ennek az eszköznek a felhőfájljai eltávolítás alatt';

  @override
  String get settings_troubleshootSync_removeThisDevice_subtitle =>
      'Szabadítsa fel ennek az eszköznek a helyét a szolgáltatón. A többi eszköz tovább szinkronizál. A merülési adatait ez nem érinti.';

  @override
  String get settings_troubleshootSync_removeThisDevice_title =>
      'Ennek az eszköznek a felhőfájljainak eltávolítása';

  @override
  String get settings_troubleshootSync_repair_confirm => 'Javítás';

  @override
  String get settings_troubleshootSync_repair_confirmBody =>
      'Ez törli az összes helyi szinkronizálási állapotot, és új szinkronizálási azonosítót ad ennek az eszköznek, majd a következő szinkronizáláskor tiszta lappal csatlakozik újra. A merülési adatai biztonságban vannak, és nem törlődnek.';

  @override
  String get settings_troubleshootSync_repair_confirmTitle =>
      'Javítja a szinkronizálást?';

  @override
  String get settings_troubleshootSync_repair_doneSnack =>
      'A szinkronizálás megjavítva';

  @override
  String get settings_troubleshootSync_repair_subtitle =>
      'Elakadt szinkronizálás javítása. Törli ennek az eszköznek a szinkronizálási állapotát, új szinkronizálási azonosítót ad neki, majd a következő szinkronizáláskor újracsatlakozik. A merülési adatait ez nem érinti.';

  @override
  String get settings_troubleshootSync_repair_title =>
      'Szinkronizálás javítása';

  @override
  String get settings_troubleshootSync_wipeAll_confirm => 'Minden törlése';

  @override
  String settings_troubleshootSync_wipeAll_confirmBody(String word) {
    return 'Ez MINDEN eszköz szinkronizálási adatát törli erről a szolgáltatóról, beleértve a könyvtárjelölőket is. Minden eszköznek a nulláról kell újra létrehoznia a szinkronizálást. A merülési adatait ez nem érinti.\n\nÍrja be pontosan a(z) $word szót a megerősítéshez.';
  }

  @override
  String get settings_troubleshootSync_wipeAll_confirmTitle =>
      'Törli az összes szinkronizálási adatot?';

  @override
  String get settings_troubleshootSync_wipeAll_progressTitle =>
      'Szinkronizálási adatok törlése';

  @override
  String get settings_troubleshootSync_wipeAll_subtitle =>
      'Törli minden eszköz szinkronizálási adatát erről a szolgáltatóról, beleértve a könyvtárjelölőket is. Minden eszköz a nulláról hozza létre újra a szinkronizálást. A merülési adatait ez nem érinti.';

  @override
  String get settings_troubleshootSync_wipeAll_title =>
      'Az összes szinkronizálási adat törlése ezen a szolgáltatón';

  @override
  String get tableMode_tooltip_toggleDetailPane => 'Részletek panel ki/be';

  @override
  String get tableMode_tooltip_toggleProfilePanel => 'Profilpanel ki/be';

  @override
  String get maps_regionDownload_title => 'Régió letöltése';

  @override
  String get maps_regionDownload_nameRequired =>
      'Adj meg egy nevet ehhez a régióhoz';

  @override
  String get maps_regionDownload_nameLabel => 'Régió neve';

  @override
  String get maps_regionDownload_nameHint => 'pl. Cozumel, Mexikó';

  @override
  String get maps_regionDownload_zoomLevels => 'Nagyítási szintek';

  @override
  String get maps_regionDownload_zoomHint =>
      'Nagyobb nagyítás = több részlet, nagyobb letöltés';

  @override
  String maps_regionDownload_minZoom(int zoom) {
    return 'Min.: $zoom';
  }

  @override
  String maps_regionDownload_minZoomSemantics(int zoom) {
    return 'Legkisebb nagyítás: $zoom';
  }

  @override
  String maps_regionDownload_maxZoom(int zoom) {
    return 'Max.: $zoom';
  }

  @override
  String maps_regionDownload_maxZoomSemantics(int zoom) {
    return 'Legnagyobb nagyítás: $zoom';
  }

  @override
  String get maps_regionDownload_estimatingSemantics =>
      'A letöltés méretének becslése';

  @override
  String maps_regionDownload_estimateSemantics(int count, Object size) {
    return 'Becsült letöltés: $count csempe, $size';
  }

  @override
  String get maps_regionDownload_estimateUnavailableSemantics =>
      'A letöltés mérete nem becsülhető meg';

  @override
  String get maps_regionDownload_estimating => 'Becslés...';

  @override
  String maps_regionDownload_tileCount(int count) {
    return '~$count csempe';
  }

  @override
  String get maps_regionDownload_estimateUnavailable => 'Nem becsülhető meg';

  @override
  String get maps_regionDownload_largeWarningSemantics =>
      'Figyelmeztetés: nagy letöltés. Fontold meg a nagyítási szintek csökkentését vagy egy kisebb régió kijelölését.';

  @override
  String get maps_regionDownload_largeWarning =>
      'Nagy letöltés. Fontold meg a nagyítási szintek csökkentését vagy egy kisebb régió kijelölését.';

  @override
  String get maps_regionDownload_downloadButton => 'Letöltés';

  @override
  String get diveLog_map_title => 'Merülési tevékenység';

  @override
  String diveLog_map_infoCard_minutes(int minutes) {
    return '$minutes perc';
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
      'Fotó indexkép. Koppints a teljes képernyős megtekintéshez';

  @override
  String get trips_gallery_thumbnail_video =>
      'Videó indexkép. Koppints a teljes képernyős megtekintéshez';

  @override
  String get trips_gallery_thumbnail_photoMissing =>
      'Fotó indexkép, hiányzik az eszközről. Koppints a teljes képernyős megtekintéshez';

  @override
  String get trips_gallery_thumbnail_videoMissing =>
      'Videó indexkép, hiányzik az eszközről. Koppints a teljes képernyős megtekintéshez';

  @override
  String get trips_photos_thumbnail_photo =>
      'Fotó indexkép. Koppints a galéria megnyitásához';

  @override
  String get trips_photos_thumbnail_video =>
      'Videó indexkép. Koppints a galéria megnyitásához';

  @override
  String trips_picker_suggestedSemantics(Object name) {
    return 'Javasolt út: $name. Koppints a használatához';
  }

  @override
  String trips_picker_tileSemantics(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, $startDate és $endDate között';
  }

  @override
  String trips_picker_tileSemanticsSelected(
    Object name,
    Object startDate,
    Object endDate,
  ) {
    return '$name, $startDate és $endDate között, kiválasztva';
  }

  @override
  String get divePlanner_quickPlan_subtitle =>
      'Hozz létre egy egyszerű, téglalap alakú merülési profilt';

  @override
  String get divePlanner_quickPlan_depthLabel => 'Mélység:';

  @override
  String divePlanner_quickPlan_depthSemantics(Object depth) {
    return 'Mélység: $depth';
  }

  @override
  String get divePlanner_quickPlan_timeLabel => 'Idő:';

  @override
  String divePlanner_quickPlan_bottomTimeSemantics(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Fenéken töltött idő: $minutes perc',
      one: 'Fenéken töltött idő: 1 perc',
    );
    return '$_temp0';
  }

  @override
  String divePlanner_quickPlan_minutes(int minutes) {
    return '$minutes perc';
  }

  @override
  String divePlanner_quickPlan_previewSemantics(Object depth, int minutes) {
    return 'Terv előnézete: leereszkedés $depth mélységig, $minutes perc fenéken töltött idő, felemelkedés biztonsági megállóval';
  }

  @override
  String get divePlanner_quickPlan_previewTitle => 'Terv előnézete:';

  @override
  String divePlanner_quickPlan_previewDescent(Object depth) {
    return 'Leereszkedés $depth mélységig';
  }

  @override
  String divePlanner_quickPlan_previewBottomTime(int minutes) {
    return 'Fenéken töltött idő: $minutes perc';
  }

  @override
  String get divePlanner_quickPlan_previewAscent =>
      'Felemelkedés biztonsági megállóval';

  @override
  String get divePlanner_quickPlan_create => 'Létrehozás';

  @override
  String divePlanner_semantics_sacRate(Object value, Object volumeSymbol) {
    return 'RMV: $value $volumeSymbol percenként';
  }

  @override
  String divePlanner_semantics_reservePressure(Object pressureSymbol) {
    return 'Tartaléknyomás $pressureSymbol egységben';
  }

  @override
  String divePlanner_semantics_altitudeGroup(Object group) {
    return 'Magassági csoport: $group';
  }

  @override
  String diveSites_import_detail_maxDepth(Object depth) {
    return 'Max. $depth';
  }

  @override
  String get autoUpdate_banner_download => 'Letöltés';

  @override
  String get settings_cloudSync_provider_icloud_subtitle =>
      'Szinkronizálás Apple iCloud segítségével';

  @override
  String get settings_debugLog_search_hint => 'Keresés a naplókban...';

  @override
  String get settings_debugLog_appBar_title => 'Hibakeresési naplók';

  @override
  String get settings_debugLog_disableDebugMode =>
      'Hibakeresési mód kikapcsolása';

  @override
  String get settings_debugLog_clearLogs => 'Naplók törlése';

  @override
  String get settings_debugLog_empty =>
      'Egyetlen naplóbejegyzés sem felel meg a jelenlegi szűrőknek';

  @override
  String settings_debugLog_loadError(Object error) {
    return 'Hiba a naplók betöltésekor: $error';
  }

  @override
  String get settings_debugLog_copiedSnack =>
      'A szűrt naplók a vágólapra másolva';

  @override
  String settings_debugLog_savedSnack(String path) {
    return 'A naplók mentve ide: $path';
  }

  @override
  String get common_action_copy => 'Másolás';

  @override
  String get settings_appearance_customGradient_title => 'Egyéni színátmenet';

  @override
  String get settings_appearance_customGradient_start => 'Kezdet';

  @override
  String get settings_appearance_customGradient_end => 'Vég';

  @override
  String get settings_appearance_customGradient_hue => 'Színárnyalat';

  @override
  String get settings_appearance_customGradient_saturation => 'Telítettség';

  @override
  String get settings_appearance_customGradient_brightness => 'Fényerő';

  @override
  String get settings_appearance_customGradient_preview => 'Előnézet';

  @override
  String get common_action_apply => 'Alkalmaz';

  @override
  String settings_cloudSync_message_loadStateFailed(Object error) {
    return 'Nem sikerült betölteni a szinkronizálási állapotot: $error';
  }

  @override
  String get settings_cloudSync_message_noProviderConfigured =>
      'Nincs felhőszolgáltató beállítva';

  @override
  String get settings_cloudSync_message_adopting =>
      'A visszaállított könyvtár átvétele...';

  @override
  String get settings_cloudSync_message_adoptFailed =>
      'Nem sikerült átvenni a visszaállított könyvtárat';

  @override
  String get settings_cloudSync_message_firstSyncNeedsConfirm =>
      'Az első szinkronizálás megerősítésre vár. Koppints a Szinkronizálás most gombra az áttekintéshez.';

  @override
  String get settings_cloudSync_message_startingSync =>
      'Szinkronizálás indítása...';

  @override
  String get settings_cloudSync_message_replacePaused =>
      'A szinkronizálás szünetel: a könyvtárat egy biztonsági mentésből cserélték le. Koppints a Szinkronizálás most gombra az áttekintéshez.';

  @override
  String get settings_cloudSync_message_encryptedPaused =>
      'A szinkronizálás szünetel: ez a könyvtár titkosítva van. A folytatáshoz add meg a jelmondatot.';

  @override
  String get settings_cloudSync_message_completedWithConflicts =>
      'A szinkronizálás ütközésekkel fejeződött be';

  @override
  String get settings_cloudSync_message_completedSuccessfully =>
      'A szinkronizálás sikeresen befejeződött';

  @override
  String get settings_cloudSync_message_syncFailed =>
      'A szinkronizálás sikertelen';

  @override
  String get settings_cloudSync_message_phaseDefault => 'szinkronizálás';

  @override
  String settings_cloudSync_message_syncErrorDuring(
    String phase,
    Object error,
  ) {
    return 'Szinkronizálási hiba a(z) $phase során: $error';
  }

  @override
  String get settings_section_debug_title => 'Hibakeresés';

  @override
  String get settings_section_debug_subtitle => 'Naplók és diagnosztika';

  @override
  String get settings_debugLog_minSeverityLabel => 'Min. súlyosság:';

  @override
  String get settings_debugLog_shareSubject => 'Submersion hibakeresési naplók';

  @override
  String get settings_debugLog_saveDialogTitle => 'Hibakeresési naplók mentése';

  @override
  String get universalImport_preset_saveTitle => 'Mentés előre beállításként';

  @override
  String get universalImport_preset_nameLabel => 'Előre beállítás neve';

  @override
  String get universalImport_preset_nameHint => 'pl. A merülésnaplóm CSV-je';

  @override
  String get universalImport_preset_nameRequired => 'A név megadása kötelező';

  @override
  String get universalImport_preset_sourceAppLabel => 'Forrásalkalmazás';

  @override
  String get universalImport_preset_sourceAppNone => 'Nincs';

  @override
  String get universalImport_preset_entityTypesLabel => 'Entitástípusok';

  @override
  String get universalImport_preset_matchThresholdLabel => 'Egyezési küszöb';

  @override
  String get universalImport_preset_matchThresholdHelp =>
      'Mennyire kell egyezniük a CSV fejléceknek az automatikus felismeréshez';

  @override
  String universalImport_preset_signatureHeaders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aláírásfejléc az aktuális fájlból',
      one: '1 aláírásfejléc az aktuális fájlból',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_preset_selectTitle =>
      'Előre beállítás kiválasztása';

  @override
  String universalImport_preset_loadFailed(String error) {
    return 'Nem sikerült betölteni az előre beállításokat: $error';
  }

  @override
  String get universalImport_preset_sectionSaved => 'Mentett előre beállítások';

  @override
  String get universalImport_preset_sectionBuiltIn =>
      'Beépített előre beállítások';

  @override
  String get universalImport_preset_deleteTitle => 'Előre beállítás törlése';

  @override
  String universalImport_preset_deleteConfirm(String name) {
    return 'Törlöd a következőt: \"$name\"? Ezt nem lehet visszavonni.';
  }

  @override
  String universalImport_preset_headersMatched(
    int matched,
    int total,
    int percent,
  ) {
    return '$matched/$total fejléc egyezik ($percent%)';
  }

  @override
  String get universalImport_preset_noSignatureHeaders =>
      'Nincsenek aláírásfejlécek';

  @override
  String get universalImport_preset_deleteTooltip => 'Előre beállítás törlése';

  @override
  String get universalImport_preset_presetsButton => 'Előre beállítások';

  @override
  String universalImport_preset_savedSnackbar(String name) {
    return 'A(z) \"$name\" előre beállítás mentve';
  }

  @override
  String get universalImport_step_done => 'Kész';

  @override
  String get universalImport_cancel_inProgressTitle => 'Megszakítás';

  @override
  String get universalImport_cancel_inProgressBody =>
      'Az aktuális merülés befejezése a leállítás előtt. A már importált merülések megmaradnak.';

  @override
  String get universalImport_cancel_confirmTitle =>
      'Megszakítod az importálást?';

  @override
  String get universalImport_cancel_confirmBody =>
      'Leállítás az aktuális merülés befejezése után. A már importált merülések megmaradnak.';

  @override
  String get universalImport_cancel_keepImporting => 'Importálás folytatása';

  @override
  String get universalImport_cancel_confirmAction => 'Importálás megszakítása';

  @override
  String get universalImport_cancel_discardSelections =>
      'Elveted a kijelöléseket és megszakítod?';

  @override
  String get universalImport_action_importSelected => 'Kijelöltek importálása';

  @override
  String get universalImport_action_next => 'Tovább';

  @override
  String get common_action_yes => 'Igen';

  @override
  String get common_action_no => 'Nem';

  @override
  String universalImport_counts_new(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count új',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_merging(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count összevonandó',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_replacing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cserélendő',
    );
    return '$_temp0';
  }

  @override
  String universalImport_counts_skipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kihagyandó',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_counts_nothingSelected => 'Semmi sincs kijelölve';

  @override
  String get universalImport_section_potentialDuplicates =>
      'Lehetséges duplikátumok';

  @override
  String get universalImport_section_possibleDuplicates =>
      'Esetleges duplikátumok';

  @override
  String universalImport_count_duplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplikátum',
      one: '1 duplikátum',
    );
    return '$_temp0';
  }

  @override
  String get universalImport_entityAction_importBadge => 'IMPORTÁLÁS';

  @override
  String get universalImport_entityAction_skipBadge => 'KIHAGYÁS';

  @override
  String get universalImport_compare_existing => 'Meglévő';

  @override
  String get universalImport_compare_incoming => 'Beérkező';

  @override
  String get universalImport_label_skipped => 'Kihagyva';

  @override
  String get universalImport_action_viewDives => 'Merülések megtekintése';

  @override
  String get diveImport_healthkit_accessGranted =>
      'HealthKit hozzáférés megadva';

  @override
  String get diveImport_healthkit_accessGrantedBody =>
      'Továbbléphetsz a következő lépésre.';

  @override
  String get diveImport_healthkit_requesting => 'Kérés folyamatban...';

  @override
  String get diveImport_healthkit_selectDateRange => 'Időszak kiválasztása';

  @override
  String get diveImport_healthkit_selectDateRangeBody =>
      'Válaszd ki az időszakot, amelyben merüléseket keresünk az Apple Health alkalmazásban.';

  @override
  String get diveImport_healthkit_fetchingDives =>
      'Merülések lekérése az Apple Health alkalmazásból...';

  @override
  String get diveImport_healthkit_fetchFailed => 'A lekérés sikertelen';

  @override
  String diveImport_healthkit_fetchFailedBody(String error) {
    return 'Nem sikerült lekérni a merüléseket: $error';
  }

  @override
  String diveImport_healthkit_foundDives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merülés található',
      one: '1 merülés található',
    );
    return '$_temp0';
  }

  @override
  String get diveImport_healthkit_proceedingToReview =>
      'Továbblépés az áttekintésre...';

  @override
  String get importWizard_dc_knownComputer => 'Ismert búvárszámítógép';

  @override
  String importWizard_dc_knownComputerBody(String name) {
    return 'Mentve mint \"$name\". Csak az új merülések töltődnek le.';
  }

  @override
  String get importWizard_dc_noNewDives => 'Nincs letöltendő új merülés';

  @override
  String get importWizard_dc_noNewDivesBody =>
      'Ennek a búvárszámítógépnek az összes merülése már importálva lett.';

  @override
  String get universalImport_compare_noDiveData =>
      'A merülési adatok nem érhetők el összehasonlításhoz.';

  @override
  String get universalImport_entityAction_consolidateBadge => 'ÖSSZEVONÁS';

  @override
  String get diveCenters_import_quickSearch_egypt => 'Egyiptom';

  @override
  String get diveCenters_import_quickSearch_mexico => 'Mexikó';

  @override
  String get accessibility_shortcut_switchDiver => 'Búvár váltása';

  @override
  String get lock_recoveryCode_title => 'Helyreállítási kód használata';

  @override
  String get lock_recoveryCode_body =>
      'Adja meg azt a 8 szavas helyreállítási kódot, amelyet az alkalmazásjelszó beállításakor elmentett.';

  @override
  String get lock_recoveryCode_error => 'Hibás helyreállítási kód.';

  @override
  String get lock_forcedReset_title => 'Adjon meg új jelszót';

  @override
  String get lock_forcedReset_body =>
      'A helyreállítási kóddal oldotta fel a zárolást, ezért a régi jelszava már nem megbízható. Válasszon most újat.';

  @override
  String get lock_forcedReset_submit => 'Jelszó beállítása';

  @override
  String get lock_forcedReset_error =>
      'Az új jelszót nem sikerült beállítani. Próbálja újra.';

  @override
  String get lock_sidecarRepair_title => 'Biztonsági kulcsfájl javítása';

  @override
  String get lock_sidecarRepair_body =>
      'A biztonsági kulcsfájl hiányzott, de az eszköz kulcstartója még tartalmazza a kulcsot. Erősítse meg a jelszavát egy új kulcsfájl írásához. Megjegyzés: az itt megadott jelszó lesz mostantól az alkalmazásjelszó, és új helyreállítási kódot fog kapni.';

  @override
  String get lock_sidecarRepair_submit => 'Javítás';

  @override
  String get lock_sidecarRepair_error => 'A javítás sikertelen. Próbálja újra.';

  @override
  String get lock_newRecoveryCode_title => 'Az új helyreállítási kódja';

  @override
  String get lock_startFresh_title => 'Másik adatbázis megnyitása';

  @override
  String lock_startFresh_body(Object token) {
    return 'A jelenlegi adatbázis a lemezen marad, .locked utótaggal átnevezve; semmi sem törlődik. Később helyreállíthatja a jelszavával, vagy az ügyfélszolgálathoz fordulva. A felhőszinkronizálás kikapcsol, hogy az új adatbázis ne keveredjen a régivel.\n\nAz alkalmazás egy új, üres adatbázissal indul. A beállítási varázslóban visszaállíthat egy biztonsági mentésből.\n\nA megerősítéshez írja be: $token.';
  }

  @override
  String get lock_startFresh_confirm => 'Félretétel és újrakezdés';

  @override
  String get lock_biometric_reason => 'Merülési napló feloldása';

  @override
  String startup_migrating_progress(Object currentStep, Object totalSteps) {
    return 'Adatbázis frissítése... $currentStep. lépés, összesen $totalSteps';
  }

  @override
  String get startup_error_title => 'A Submersion nem tudott elindulni';

  @override
  String get startup_error_body =>
      'Valami hiba történt, mielőtt a merülési naplód teljesen megnyílt volna. Az adataid továbbra is a lemezen vannak, és nincs szükség újratelepítésre. Próbáld újraindítani az alkalmazást; ha a probléma nem szűnik meg, fordulj az ügyfélszolgálathoz.';

  @override
  String get startup_engineUnavailable_title =>
      'Ez a build nem tud adatbázist megnyitni';

  @override
  String get startup_engineUnavailable_body =>
      'Ebből a buildből hiányzik a Submersion adatbázismotorja, ezért a merülési naplód meg sem nyílt. A lemezen semmi nem változott, és egyetlen adat sincs veszélyben.';

  @override
  String get startup_engineUnavailable_guidance =>
      'Az újratelepítés vagy egy biztonsági másolat visszaállítása itt nem segít. Telepítsd a Submersion egy működő buildjét, és kérjük, jelentsd ezt: az alkalmazáscsomag hibája, nem az adataidé.';

  @override
  String get startup_migrationFailed_title =>
      'Az adatbázis frissítése nem sikerült';

  @override
  String get startup_migrationFailed_body =>
      'A merülési naplódat nem sikerült az ehhez a verzióhoz szükséges formátumra frissíteni. A frissítés megkezdése előtt biztonsági másolat készült, így semmi nem veszett el.';

  @override
  String get startup_dataUnreadable_title =>
      'A merülési naplódat nem sikerült beolvasni';

  @override
  String get startup_dataUnreadable_body =>
      'Az adatbázisfájl megvan, de a Submersion nem tudja elolvasni. Ez általában azt jelenti, hogy a fájl sérült. Egy biztonsági másolat visszaállítása a leggyorsabb út vissza.';

  @override
  String get startup_databaseBusy_title => 'A merülési naplód foglalt volt';

  @override
  String get startup_databaseBusy_body =>
      'Valami más még használta az adatbázisfájlt, ezért a Submersion megállt ahelyett, hogy írt volna bele. Semmi nem változott és semmi nem sérült meg. Zárd be teljesen a Submersiont, majd nyisd meg újra.';

  @override
  String get startup_failure_technicalDetails => 'Technikai részletek';

  @override
  String get startup_failure_backupAvailable_title =>
      'Elérhető egy biztonsági másolat';

  @override
  String startup_failure_backupAvailable_taken(Object timestamp) {
    return 'Készült: $timestamp';
  }

  @override
  String startup_failure_backupAvailable_preMigration(
    Object fromVersion,
    Object toVersion,
  ) {
    return 'Biztonsági másolat a v$fromVersion sémáról v$toVersion sémára történő frissítés előtt.';
  }

  @override
  String get startup_failure_restoreAction =>
      'Ennek a másolatnak a visszaállítása';

  @override
  String get startup_failure_restoring => 'Merülési napló visszaállítása...';

  @override
  String get startup_failure_restoreFailed =>
      'A biztonsági másolatot nem sikerült visszaállítani. A merülési naplód pontosan úgy maradt, ahogy volt.';

  @override
  String get startup_failure_backupsFolder =>
      'A biztonsági másolataid itt vannak:';

  @override
  String get startup_failure_showBackupsFolder => 'Biztonsági mentések mappája';

  @override
  String get startup_failure_downgrade_title => 'Visszatérés az előző verzióra';

  @override
  String get startup_failure_downgrade_body =>
      'Ha a frissítés továbbra sem sikerül, telepítsd a Submersion korábban használt verzióját, majd abból a verzióból állítsd vissza a biztonsági másolatot. Itt visszaállítani csak ugyanazt a frissítést futtatná le újra. A Submersion soha nem vált magától régebbi verzióra: az automatikus visszaléptetés csendben ismert hibás verziókon tartana.';

  @override
  String get startup_failure_downgrade_action =>
      'Korábbi kiadások megtekintése';

  @override
  String get startup_recovering_title => 'Adatbázis helyreállítása...';

  @override
  String get startup_recovering_body =>
      'A megszakadt tranzakció visszagörgetése folyik. Ez általában néhány másodpercet vesz igénybe.';

  @override
  String get startup_recoveryFailed_title =>
      'A helyreállítás nem fejeződött be';

  @override
  String get startup_recoveryFailed_body =>
      'Az adatbázist nem sikerült automatikusan visszagörgetni. Az adatai továbbra is a lemezen vannak; újratelepítés előtt forduljon az ügyfélszolgálathoz, hogy segíthessünk a helyreállításukban.';

  @override
  String get startup_recoveryRequired_title =>
      'Az adatbázis helyreállításra szorul';

  @override
  String get startup_recoveryRequired_body =>
      'Egy korábbi munkamenet megszakadt az adatbázisba írás közben. Az adatai továbbra is a lemezen vannak; csak be kell fejeznünk a megszakított módosítás visszagörgetését, mielőtt az alkalmazás megnyílhat.';

  @override
  String startup_recovery_sqliteCode(Object code) {
    return 'SQLite kód: $code';
  }

  @override
  String get startup_recovery_action => 'Adatbázis helyreállítása';

  @override
  String get startup_recovery_closeWithoutRecovering =>
      'Bezárás helyreállítás nélkül';

  @override
  String get common_action_tryAgain => 'Próbálja újra';

  @override
  String get lock_screen_title => 'A Submersion zárolva van';

  @override
  String get lock_screen_forgotPassword => 'Elfelejtette a jelszavát?';

  @override
  String get lock_incorrectPassword => 'Hibás jelszó. Próbálja újra.';

  @override
  String get startup_backup_semanticsLabel => 'Biztonsági mentés folyamatban';

  @override
  String get startup_backup_title => 'Adatai biztonsági mentése';

  @override
  String get startup_backup_body =>
      'Másolatot készítünk a merülési naplójáról, mielőtt frissítenénk az adatbázist.';

  @override
  String get startup_backupFailed_title =>
      'Nem sikerült biztonsági mentést készíteni az adatairól';

  @override
  String get startup_backupFailed_body =>
      'A merülési naplója nem változott; nem frissítettük. Szabadítson fel helyet (vagy hárítsa el a hibát), és próbálja újra.';

  @override
  String get startup_backupFailed_quit => 'Kilépés';

  @override
  String get startup_backupFailed_technicalDetails => 'Technikai részletek';

  @override
  String get common_action_retry => 'Újra';

  @override
  String get startup_versionMismatch_title => 'Frissítés szükséges';

  @override
  String startup_versionMismatch_body(
    Object databaseVersion,
    Object appVersion,
  ) {
    return 'A merülési adatait a Submersion egy újabb verziója mentette (séma v$databaseVersion). Ez a verzió legfeljebb a v$appVersion sémát támogatja.';
  }

  @override
  String get startup_versionMismatch_instructions =>
      'Kérjük, frissítse a Submersiont a legújabb verzióra. Az adatai biztonságban vannak, és nem módosultak. Ha a frissítés előtt készült biztonsági mentés, az a Backups mappában található, és a frissítés után visszaállítható.';

  @override
  String get startup_versionMismatch_storeInstructions =>
      'Ezt az alkalmazást alkalmazásboltból telepítetted, és régebbi, mint az adataidat létrehozó verzió. Az adataid biztonságban vannak, nem módosultak. Frissítsd a Submersiont, amint az új verzió megjelenik a boltban, majd nyisd meg újra.';

  @override
  String get startup_versionMismatch_download => 'Legújabb verzió letöltése';

  @override
  String get startup_versionMismatch_manualLink =>
      'Ha ez nem nyit meg böngészőt, keresse fel:';

  @override
  String get universalImport_compare_downloaded => 'Letöltött';

  @override
  String get universalImport_compare_errorLoading =>
      'Hiba a merülési adatok betöltésekor';

  @override
  String get universalImport_compare_diveNotFound =>
      'A meglévő merülés nem található';

  @override
  String universalImport_compare_sameFields(Object fields) {
    return 'Azonos: $fields';
  }

  @override
  String get universalImport_compare_differences => 'ELTÉRÉSEK';

  @override
  String get universalImport_compare_notRecorded => 'nincs rögzítve';

  @override
  String universalImport_compare_serial(Object serial) {
    return 'S/N: $serial';
  }

  @override
  String get universalImport_compare_skipSubtitle => 'A letöltés elvetése';

  @override
  String get universalImport_compare_importAsNewSubtitle =>
      'Mentés külön merülésként';

  @override
  String get universalImport_compare_consolidateSubtitle =>
      'Hozzáadás 2. computer méréseként';

  @override
  String get diveLog_tooltip_ndlOverMax => '>60 min';

  @override
  String diveLog_tooltip_interpolated(String value) {
    return '$value (interpolált)';
  }

  @override
  String get enum_profileMetric_ascentRate_short => 'Sebesség';

  @override
  String get enum_profileMetric_cns_short => 'CNS';

  @override
  String get enum_profileMetric_otu_short => 'OTU';

  @override
  String get diveLog_profileEditor_rangeOperations => 'Tartományműveletek';

  @override
  String get diveLog_profileEditor_selectRangeHint =>
      'Jelöljön ki egy tartományt a grafikonon a műveletek engedélyezéséhez';

  @override
  String get diveLog_profileEditor_depthPlusOneMeter => 'Mélység +1m';

  @override
  String get diveLog_profileEditor_depthMinusOneMeter => 'Mélység -1m';

  @override
  String get diveLog_profileEditor_timePlusFiveSeconds => 'Idő +5s';

  @override
  String get diveLog_profileEditor_timeMinusFiveSeconds => 'Idő -5s';

  @override
  String get diveLog_profileEditor_smoothing => 'Simítás';

  @override
  String get diveLog_profileEditor_smoothLight => 'Enyhe';

  @override
  String get diveLog_profileEditor_smoothMedium => 'Közepes';

  @override
  String get diveLog_profileEditor_smoothHeavy => 'Erős';

  @override
  String get diveLog_profileEditor_applyToAll => 'Alkalmazás mindenre';

  @override
  String get diveLog_profileEditor_applyToSelection =>
      'Alkalmazás a kijelölésre';

  @override
  String get diveLog_profileEditor_outlierDetection =>
      'Kiugró értékek keresése';

  @override
  String get diveLog_profileEditor_detect => 'Keresés';

  @override
  String get diveLog_profileEditor_removeAll => 'Összes eltávolítása';

  @override
  String diveLog_profileEditor_outliersDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lehetséges kiugró érték található',
      one: '$count lehetséges kiugró érték található',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_profileEditor_manualDrawing => 'Kézi rajzolás';

  @override
  String get diveLog_profileEditor_drawHint =>
      'Koppintson a grafikonra útpontok elhelyezéséhez';

  @override
  String get diveLog_profileEditor_clearWaypoints => 'Törlés';

  @override
  String get diveLog_profileEditor_generateProfile => 'Profil létrehozása';

  @override
  String get diveLog_profileEditor_trimMode => 'Vágás mód';

  @override
  String get diveLog_profileEditor_trimHint =>
      'A profil végpontjainak levágása';

  @override
  String get diveLog_profileEditor_trimEnd => 'Vég levágása';

  @override
  String get diveLog_profileEditor_mode_smooth => 'Simítás';

  @override
  String get diveLog_profileEditor_title => 'Profil szerkesztése';

  @override
  String get diveLog_profileEditor_discardBody =>
      'Nem mentett módosításai vannak ezen a merülési profilon. Biztosan elveti őket?';

  @override
  String get diveLog_profileEditor_saveTitle => 'Menti a profilt?';

  @override
  String get diveLog_profileEditor_saveBody =>
      'Ezzel a szerkesztett profilt menti a merülés elsődleges profiljaként. Az eredeti profil megmarad, és később visszaállítható.';

  @override
  String diveLog_profileEditor_saveFailed(String error) {
    return 'A profil mentése sikertelen: $error';
  }

  @override
  String diveLog_profileEditor_errorLoadingDive(String error) {
    return 'Hiba a merülés betöltésekor: $error';
  }

  @override
  String get diveLog_profileEditor_noProfileData => 'Nincs elérhető profiladat';

  @override
  String get diveLog_profileEditor_undo => 'Visszavonás';

  @override
  String get diveLog_profileEditor_mode_select => 'Kijelölés';

  @override
  String get diveLog_profileEditor_mode_outlier => 'Kiugró érték';

  @override
  String get diveLog_profileEditor_mode_draw => 'Rajzolás';

  @override
  String get diveLog_profileEditor_mode_trim => 'Vágás';

  @override
  String diveLog_sources_sectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Adatforrások',
      one: 'Adatforrás',
      zero: 'Adatforrás',
    );
    return '$_temp0';
  }

  @override
  String get diveLog_sources_badge_manual => 'Kézi';

  @override
  String get diveLog_sources_badge_viewing => 'Megtekintve';

  @override
  String get diveLog_sources_badge_secondary => 'Másodlagos';

  @override
  String diveLog_sources_created(String date) {
    return 'Létrehozva: $date';
  }

  @override
  String get diveLog_sources_detail_serial => 'Sorozatszám';

  @override
  String get diveLog_sources_detail_format => 'Formátum';

  @override
  String get diveLog_sources_detail_imported => 'Importálva';

  @override
  String diveLog_detail_semantics_viewDiveComputer(String name) {
    return '$name búvárcomputer megtekintése';
  }

  @override
  String diveLog_detail_semantics_viewTrip(String name) {
    return '$name utazás megtekintése';
  }

  @override
  String diveLog_detail_semantics_viewDiveCenter(String name) {
    return '$name búvárközpont megtekintése';
  }

  @override
  String diveLog_detail_semantics_viewSpecies(String name) {
    return '$name faj megtekintése';
  }

  @override
  String diveLog_detail_semantics_viewCourse(String name) {
    return '$name tanfolyam megtekintése';
  }

  @override
  String diveLog_detail_serialNumber(String serial) {
    return 'S/N $serial';
  }

  @override
  String diveLog_detail_errorLoadingSignature(String error) {
    return 'Hiba az aláírás betöltésekor: $error';
  }

  @override
  String get diveLog_profilePanel_selectDive =>
      'Válasszon egy merülést a profil megtekintéséhez';

  @override
  String get diveLog_profilePanel_noProfileData =>
      'Ehhez a merüléshez nincs profiladat';

  @override
  String get settings_export_progress_divesCsv =>
      'Merülések exportálása CSV-be...';

  @override
  String get settings_export_progress_sitesCsv =>
      'Merülőhelyek exportálása CSV-be...';

  @override
  String get settings_export_progress_equipmentCsv =>
      'Felszerelés exportálása CSV-be...';

  @override
  String get settings_export_progress_pdf => 'PDF merülési napló készítése...';

  @override
  String get settings_export_progress_loadingSignatures =>
      'Aláírások betöltése...';

  @override
  String get settings_export_progress_loadingCertifications =>
      'Képesítések betöltése...';

  @override
  String get settings_export_progress_loadingFonts =>
      'Betűtípusok betöltése...';

  @override
  String settings_export_progress_templatePdf(String template) {
    return '$template PDF készítése...';
  }

  @override
  String get settings_export_progress_uddf => 'UDDF-fájl készítése...';

  @override
  String get settings_export_progress_collectingData =>
      'Az összes adat összegyűjtése...';

  @override
  String get settings_export_progress_excel => 'Excel-fájl készítése...';

  @override
  String get settings_export_progress_buildingExcel =>
      'Excel-munkafüzet összeállítása...';

  @override
  String get settings_export_progress_kml => 'KML-fájl készítése...';

  @override
  String get settings_export_progress_buildingKml =>
      'KML-fájl összeállítása...';

  @override
  String get settings_export_progress_preparingExcel =>
      'Excel-fájl előkészítése...';

  @override
  String get settings_export_progress_preparingKml =>
      'KML-fájl előkészítése...';

  @override
  String get settings_export_progress_chooseLocation =>
      'Válassza ki a mentés helyét...';

  @override
  String get settings_export_progress_preparingDivesCsv =>
      'Merülések CSV-fájljának előkészítése...';

  @override
  String get settings_export_progress_preparingSitesCsv =>
      'Merülőhelyek CSV-fájljának előkészítése...';

  @override
  String get settings_export_progress_preparingEquipmentCsv =>
      'Felszerelés CSV-fájljának előkészítése...';

  @override
  String get settings_export_progress_preparingUddf =>
      'UDDF-fájl előkészítése...';

  @override
  String get settings_export_progress_preparingPdf => 'PDF előkészítése...';

  @override
  String get settings_export_progress_selectingBackup =>
      'Biztonsági mentés fájljának kiválasztása...';

  @override
  String get settings_export_progress_restoringBackup =>
      'Visszaállítás biztonsági mentésből...';

  @override
  String get settings_export_empty_dives => 'Nincs exportálható merülés';

  @override
  String get settings_export_empty_sites => 'Nincs exportálható merülőhely';

  @override
  String get settings_export_empty_equipment =>
      'Nincs exportálható felszerelés';

  @override
  String get settings_export_empty_data => 'Nincs exportálható adat';

  @override
  String get settings_export_empty_diveSites => 'Nincs exportálható merülőhely';

  @override
  String settings_export_saveFailed(String error) {
    return 'A mentés nem sikerült: $error';
  }

  @override
  String settings_export_backupFailed(String error) {
    return 'A biztonsági mentés nem sikerült: $error';
  }

  @override
  String settings_export_restoreFailed(String error) {
    return 'A visszaállítás nem sikerült: $error';
  }

  @override
  String get settings_export_fileUnreadable => 'A fájl nem érhető el';

  @override
  String get settings_export_notADbFile =>
      'Válasszon egy .db kiterjesztésű mentésfájlt';

  @override
  String get settings_export_success_dives =>
      'A merülések exportálása sikerült';

  @override
  String get settings_export_success_sites =>
      'A merülőhelyek exportálása sikerült';

  @override
  String get settings_export_success_equipment =>
      'A felszerelés exportálása sikerült';

  @override
  String get settings_export_success_pdf =>
      'A PDF merülési napló sikeresen elkészült';

  @override
  String get settings_export_success_uddf => 'Az UDDF-fájl sikeresen elkészült';

  @override
  String get settings_export_success_excel =>
      'Az Excel-fájl exportálása sikerült';

  @override
  String settings_export_success_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'A KML-fájl exportálása sikerült ($count koordináták nélküli merülőhely kihagyva)',
      one:
          'A KML-fájl exportálása sikerült (1 koordináták nélküli merülőhely kihagyva)',
      zero: 'A KML-fájl exportálása sikerült',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_excel => 'Az Excel-fájl mentése sikerült';

  @override
  String settings_export_saved_kml(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'A KML-fájl mentése sikerült ($count koordináták nélküli merülőhely kihagyva)',
      one:
          'A KML-fájl mentése sikerült (1 koordináták nélküli merülőhely kihagyva)',
      zero: 'A KML-fájl mentése sikerült',
    );
    return '$_temp0';
  }

  @override
  String get settings_export_saved_divesCsv => 'A merülések CSV-fájlja mentve';

  @override
  String get settings_export_saved_sitesCsv =>
      'A merülőhelyek CSV-fájlja mentve';

  @override
  String get settings_export_saved_equipmentCsv =>
      'A felszerelés CSV-fájlja mentve';

  @override
  String get settings_export_saved_uddf => 'Az UDDF-fájl mentve';

  @override
  String get settings_export_saved_pdf => 'A PDF mentve';

  @override
  String get settings_export_saved_backup => 'A biztonsági mentés elmentve';

  @override
  String get settings_export_restoreComplete => 'A visszaállítás befejeződött';

  @override
  String get settings_export_cancelled_save => 'Mentés megszakítva';

  @override
  String get settings_export_cancelled_backup =>
      'Biztonsági mentés megszakítva';

  @override
  String get settings_export_cancelled_restore => 'Visszaállítás megszakítva';

  @override
  String get settings_export_pdfDocumentTitle => 'Merülési Napló';

  @override
  String get settings_export_saveBackupDialogTitle =>
      'Biztonsági mentés mentése';

  @override
  String backup_operation_created(String size) {
    return 'Biztonsági mentés elkészült: $size';
  }

  @override
  String backup_operation_backupFailed(String error) {
    return 'A biztonsági mentés nem sikerült: $error';
  }

  @override
  String get backup_operation_restoring =>
      'Biztonsági mentés visszaállítása...';

  @override
  String backup_operation_restoreFailed(String error) {
    return 'A visszaállítás nem sikerült: $error';
  }

  @override
  String get backup_operation_deleting => 'Biztonsági mentés törlése...';

  @override
  String get backup_operation_deleted => 'A biztonsági mentés törölve';

  @override
  String backup_operation_deleteFailed(String error) {
    return 'A törlés nem sikerült: $error';
  }

  @override
  String get backup_operation_exporting => 'Biztonsági mentés exportálása...';

  @override
  String backup_operation_exported(String size) {
    return 'Biztonsági mentés exportálva: $size';
  }

  @override
  String backup_operation_exportFailed(String error) {
    return 'Az exportálás nem sikerült: $error';
  }

  @override
  String get backup_operation_preparingShare =>
      'Biztonsági mentés előkészítése megosztásra...';

  @override
  String get backup_operation_shareReady =>
      'A biztonsági mentés készen áll a megosztásra';

  @override
  String backup_operation_upgrading(int step, int total) {
    return 'Adatbázis frissítése ($step. lépés, összesen $total)...';
  }

  @override
  String backup_restore_dialog_counts(int diveCount, int siteCount) {
    String _temp0 = intl.Intl.pluralLogic(
      diveCount,
      locale: localeName,
      other: '$diveCount merülés',
      one: '1 merülés',
    );
    String _temp1 = intl.Intl.pluralLogic(
      siteCount,
      locale: localeName,
      other: '$siteCount merülőhely',
      one: '1 merülőhely',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get backup_restore_preMigration_title =>
      'Migráció előtti mentés visszaállítása';

  @override
  String get backup_restore_preMigration_unknownVersion => 'ismeretlen verzió';

  @override
  String get backup_restore_preMigration_restoreAnyway =>
      'Visszaállítás mindenképp';

  @override
  String backup_restore_preMigration_incompleteMetadata(
    String timestamp,
    String appVersion,
  ) {
    return 'Ez a biztonsági mentés $timestamp időpontban készült a(z) $appVersion alkalmazásverzióval, de az adatbázis-migrációs metaadatai hiányosak.\n\nAz alkalmazás nem tudja ellenőrizni, hogy biztonságos-e visszaállítani ezt a mentést, ezért a visszaállítás le van tiltva.';
  }

  @override
  String backup_restore_preMigration_newerApp(
    String timestamp,
    String appVersion,
    int fromVersion,
  ) {
    return 'Ez a biztonsági mentés újabb, mint az alkalmazása. A visszaállításához telepítsen újabb alkalmazásverziót.\n\nA mentés $timestamp időpontban készült a(z) $appVersion alkalmazásverzióval (adatbázis v$fromVersion).';
  }

  @override
  String backup_restore_preMigration_safe(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
  ) {
    return 'Ez a biztonsági mentés $timestamp időpontban készült a(z) $appVersion alkalmazásverzióval, közvetlenül az adatbázis v$fromVersion verzióról v$toVersion verzióra való frissítése előtt.\n\nAz alkalmazása adatbázissémája megegyezik ezzel a mentéssel, ezért a visszaállítás biztonságos.';
  }

  @override
  String backup_restore_preMigration_warning(
    String timestamp,
    String appVersion,
    int fromVersion,
    int toVersion,
    int currentVersion,
  ) {
    return 'Ez a biztonsági mentés $timestamp időpontban készült a(z) $appVersion alkalmazásverzióval, közvetlenül az adatbázis v$fromVersion verzióról v$toVersion verzióra való frissítése előtt.\n\nÖn ennél újabb alkalmazást futtat (adatbázis v$currentVersion).\n\nA mostani visszaállítás újra lefuttatja a v$fromVersion → v$toVersion adatbázis-frissítést a visszaállított adatokon: pontosan ugyanazt a frissítést, amely eredetileg is futni készült. Ha az a frissítés okozta a problémát, ismét ugyanabba a hibába fog ütközni.\n\nA biztonságos visszaállításhoz: telepítse a(z) $appVersion vagy annál korábbi alkalmazásverziót, majd abból a régebbi alkalmazásból állítsa vissza ezt a mentést.';
  }

  @override
  String get settings_cloudSync_progress_preparing =>
      'Szinkronizálás előkészítése...';

  @override
  String get settings_cloudSync_progress_pulling => 'Változások letöltése...';

  @override
  String get settings_cloudSync_progress_publishing =>
      'Változások közzététele...';

  @override
  String settings_cloudSync_progress_uploadingLibrary(int uploaded, int total) {
    return 'Könyvtár feltöltése ($uploaded / $total)';
  }

  @override
  String get settings_cloudSync_result_noProvider =>
      'Nincs beállítva felhőszolgáltató';

  @override
  String get settings_cloudSync_result_notAuthenticated =>
      'Nincs hitelesítve a felhőszolgáltatónál';

  @override
  String get settings_cloudSync_result_timedOut =>
      'A szinkronizálás túllépte az időkorlátot';

  @override
  String get settings_cloudSync_result_epochMarkerUnreadable =>
      'A könyvtár epoch-jelölője nem olvasható';

  @override
  String get settings_cloudSync_result_epochMarkerEncrypted =>
      'A könyvtár epoch-jelölője titkosítva van';

  @override
  String get settings_cloudSync_result_libraryReplacedRemotely =>
      'A felhőkönyvtárat egy biztonsági mentésből cserélték le';

  @override
  String get settings_cloudSync_result_noReplacementToRebuild =>
      'Nincs olyan könyvtárcsere, amelyből újra lehetne építeni';

  @override
  String get settings_cloudSync_result_rebuiltFromThisDevice =>
      'Ez a szolgáltató újraépült ennek az eszköznek a könyvtárából';

  @override
  String settings_cloudSync_result_rebuildFailed(String error) {
    return 'Az újraépítés nem sikerült: $error';
  }

  @override
  String get settings_cloudSync_result_libraryReplaced =>
      'A könyvtár lecserélve';

  @override
  String settings_cloudSync_result_libraryReplaceFailed(String error) {
    return 'A könyvtár cseréje nem sikerült: $error';
  }

  @override
  String get settings_cloudSync_result_noReplacementMarker =>
      'Nem található könyvtárcsere-jelölő';

  @override
  String get settings_cloudSync_result_adoptedRestoredLibrary =>
      'A visszaállított könyvtár átvéve';

  @override
  String settings_cloudSync_result_adoptFailed(String error) {
    return 'Nem sikerült átvenni a visszaállított könyvtárat: $error';
  }

  @override
  String get settings_cloudSync_result_previousLibraryUnreadable =>
      'A korábbi könyvtár nem volt olvasható; ez a szolgáltató ennek az eszköznek a könyvtárából lett újra létrehozva.';

  @override
  String get settings_cloudSync_result_replacementStillUploading =>
      'A lecserélt könyvtár feltöltése még folyamatban van. Próbálja újra rövidesen.';

  @override
  String settings_cloudSync_result_recordsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rekordot nem sikerült alkalmazni',
      one: '1 rekordot nem sikerült alkalmazni',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_result_adoptedFreshIdentity =>
      'Egy másik eszköz ennek az eszköznek az azonosságával szinkronizált. Ez az eszköz új azonosságot vett fel, és egyesítette a felhőben lévő adatokat.';

  @override
  String settings_cloudSync_launchCheck_unavailable(String provider) {
    return 'A(z) $provider nem érhető el ezen az eszközön';
  }

  @override
  String settings_cloudSync_launchCheck_notSignedIn(String provider) {
    return 'Nincs bejelentkezve ide: $provider';
  }

  @override
  String settings_cloudSync_launchCheck_localChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count helyi módosítás vár feltöltésre',
      one: '1 helyi módosítás vár feltöltésre',
    );
    return '$_temp0';
  }

  @override
  String get settings_cloudSync_launchCheck_noRemoteData =>
      'Nem található szinkronizálási adat a felhőben';

  @override
  String get settings_cloudSync_launchCheck_cloudDataAvailable =>
      'Elérhetők felhőadatok';

  @override
  String get settings_cloudSync_launchCheck_updatesAvailable =>
      'Frissítések érhetők el a felhőből';

  @override
  String get settings_cloudSync_launchCheck_upToDate => 'Minden naprakész';

  @override
  String settings_cloudSync_launchCheck_failed(String error) {
    return 'A szinkronizálás ellenőrzése nem sikerült: $error';
  }

  @override
  String get diveLog_detail_viewMap => 'Térkép';

  @override
  String get diveLog_detail_view3d => '3D';

  @override
  String get setup_sync_icloudUnavailable =>
      'Az iCloud nem érhető el ezen az eszközön';

  @override
  String get media_info_title => 'Média infó';

  @override
  String get media_info_fileSection => 'Fájl';

  @override
  String get media_info_filename => 'Fájlnév';

  @override
  String get media_info_type => 'Típus';

  @override
  String get media_info_dimensions => 'Méretek';

  @override
  String get media_info_size => 'Méret';

  @override
  String get media_info_taken => 'Készült';

  @override
  String get media_info_coordinates => 'Koordináták';

  @override
  String get media_info_unknown => 'Ismeretlen';

  @override
  String get media_info_originSection => 'Eredet';

  @override
  String get media_info_source => 'Forrás';

  @override
  String get media_info_reference => 'Hivatkozás';

  @override
  String get media_info_linkedOn => 'Összekapcsolva';

  @override
  String get media_info_thisDevice => 'Ez az eszköz';

  @override
  String get media_info_otherDevice => 'Egy másik eszköz';

  @override
  String get media_info_status => 'Állapot';

  @override
  String get media_info_statusFound => 'Megtalálható ezen az eszközön';

  @override
  String get media_info_statusMissing => 'Hiányzik erről az eszközről';

  @override
  String get media_info_statusUnchecked => 'Még nincs ellenőrizve';

  @override
  String media_info_lastChecked(String date) {
    return 'Utoljára ellenőrizve $date';
  }

  @override
  String get media_timeInDive_label => 'Időpont a merülésben';

  @override
  String get media_timeInDive_unknown => 'Időpont a merülésben ismeretlen';

  @override
  String get media_timeInDive_setAction => 'Időpont beállítása a merülésben';

  @override
  String media_timeInDive_manual(String time) {
    return '$time (kézzel beállítva)';
  }

  @override
  String get media_timeInDive_fieldLabel => 'Idő a merülés kezdetétől';

  @override
  String get media_timeInDive_fieldHint => 'mm:ss';

  @override
  String media_timeInDive_range(String max) {
    return '0:00 és $max között';
  }

  @override
  String media_timeInDive_invalid(String max) {
    return 'Adj meg egy időt 0:00 és $max között';
  }

  @override
  String get media_timeInDive_save => 'Mentes';

  @override
  String get media_timeInDive_cancel => 'Megse';

  @override
  String get media_timeInDive_reset => 'Visszaállítás automatikusra';

  @override
  String get media_info_backupSection => 'Biztonsági mentés';

  @override
  String get media_info_store => 'Felhő tárhely';

  @override
  String get media_info_storeNotConnected =>
      'Nincs csatlakoztatott felhő tárhely';

  @override
  String get media_info_notEligible => 'Ez a forrás nem menthető';

  @override
  String get media_info_backupFull => 'Eredeti feltoltve';

  @override
  String get media_info_backupThumbOnly =>
      'Csak bélyegkép, az eredeti nincs elküldve';

  @override
  String get media_info_backupRenditionOnly => 'Tömörített változat feltöltve';

  @override
  String get media_info_backupNone => 'Nincs mentve';

  @override
  String media_info_uploadedOn(String date) {
    return 'Feltoltve $date';
  }

  @override
  String get media_info_queuePending => 'Feltoltesre var';

  @override
  String get media_info_queueTransferring => 'Feltoltes folyamatban';

  @override
  String media_info_queueFailed(Object error) {
    return 'A feltöltés sikertelen: $error';
  }

  @override
  String get media_info_servingSection => 'Jelenlegi forrás';

  @override
  String get media_info_servingUnobserved => 'Még nincs betöltve';

  @override
  String get media_info_servingFailed => 'Nem sikerült betölteni';

  @override
  String get media_info_servedLocalDisk => 'Helyi fájl ezen az eszközön';

  @override
  String get media_info_servedGallery => 'Fotókönyvtár';

  @override
  String get media_info_servedStoreCache =>
      'Helyi gyorsítótár, a felhő tárhelyről';

  @override
  String get media_info_servedStoreNetwork => 'Letöltve a felhő tárhelyről';

  @override
  String get media_info_servedNetworkUrl => 'Streamelés URL-címről';

  @override
  String get media_info_servedConnectorCache =>
      'Helyi gyorsítótár, a csatlakoztatott szolgáltatásból';

  @override
  String get media_info_servedConnectorNetwork =>
      'Letöltve a csatlakoztatott szolgáltatásból';

  @override
  String get media_info_servedEmbedded => 'Ebben a naplóban tárolva';

  @override
  String get media_info_servingFallbackNote =>
      'Az eredeti forrás nem volt elérhető, ezért a felhő tárhely szolgálta ki.';

  @override
  String get media_info_servingTierThumbnail => 'Bélyegkép';

  @override
  String get media_info_servingTierRendition => 'Tömörített változat';

  @override
  String get media_info_typePhoto => 'Fénykép';

  @override
  String get media_info_typeVideo => 'Videó';

  @override
  String get media_info_typeDocument => 'Dokumentum';

  @override
  String get media_info_typeSignature => 'Aláírás';

  @override
  String get media_info_actionCheckNow => 'Ellenőrzés most';

  @override
  String get media_info_actionLocate => 'Fájl keresése...';

  @override
  String get media_info_actionBackUpNow => 'Mentés most';

  @override
  String get media_info_actionRetryUpload => 'Feltöltés újra';

  @override
  String get media_info_actionReveal => 'Megjelenítés a fájlkezelőben';

  @override
  String get media_info_actionCopyPath => 'Hivatkozás másolása';

  @override
  String get media_info_referenceCopied => 'Hivatkozás másolva';

  @override
  String get media_info_checkFound => 'A forrás megtalálható';

  @override
  String get media_info_checkMissing => 'A forrás hiányzik';

  @override
  String get media_info_checkUnavailable => 'Most nem ellenőrizhető';

  @override
  String get media_info_backupQueued => 'Feltöltési sorban';

  @override
  String get enum_profileMetric_o2CellMv => 'O2-cellák';

  @override
  String get enum_profileMetric_o2CellMv_short => 'Cellák';

  @override
  String get diveLog_o2CellSpread_label => 'O2-cellák szórása';

  @override
  String get media_status_broken => 'Hiányzik és nincs mentve';

  @override
  String get media_servedFrom_localDisk => 'Ezen az eszközön';

  @override
  String get media_servedFrom_platformGallery => 'Fotókönyvtár';

  @override
  String get media_servedFrom_storeCache => 'Felhőtár, itt gyorsítótárazva';

  @override
  String get media_servedFrom_storeNetwork => 'Felhőtár';

  @override
  String get media_servedFrom_networkUrl => 'Webhivatkozás';

  @override
  String get media_servedFrom_connectorCache =>
      'Csatlakoztatott szolgáltatás, itt gyorsítótárazva';

  @override
  String get media_servedFrom_connectorNetwork =>
      'Csatlakoztatott szolgáltatás';

  @override
  String get media_servedFrom_embedded => 'Ebben a naplóban tárolva';

  @override
  String get settings_media_provenanceBadges =>
      'Forrásjelvények megjelenítése a bélyegképeken';

  @override
  String get settings_media_provenanceBadgesSubtitle =>
      'Kis ikon, amely megmutatja, honnan érkezik az egyes elemek tartalma. A problémajelvények mindig láthatók.';

  @override
  String get media_status_transferFailed => 'A feltöltés sikertelen';

  @override
  String get media_status_transferring => 'Feltöltés folyamatban';

  @override
  String get media_status_queued => 'Feltöltésre vár';

  @override
  String get media_status_cloudOnly => 'Csak a felhőben tárolva';

  @override
  String get media_status_notBackedUp => 'Nincs mentve';

  @override
  String get media_tile_infoMenuItem => 'Média infó';

  @override
  String get diveImport_healthkit_accessGrantedHint =>
      'Az Apple Health soha nem árulja el az alkalmazásoknak, hogy megkapta-e az olvasási hozzáférést. Ha nem jelenik meg merülés, nyisd meg a Health appot, majd a Megosztás, Appok, Submersion menüpontot, és kapcsold be az Edzések, Vízmélység, Vízhőmérséklet és Pulzus tételt.';

  @override
  String get diveImport_healthkit_foundNoDivesHint =>
      'Nincs merülés edzés ebben az időszakban. Ellenőrizd, hogy a dátumok lefedik-e a merülést, és hogy a Health, Megosztás, Appok, Submersion menüben be van-e kapcsolva az Edzések és a Vízmélység.';

  @override
  String get settings_dataSources_appleHealth_dataTypeDepth =>
      'Vízmélység - a merülések során rögzített mélységadatok';

  @override
  String get settings_dataSources_appleHealth_dataTypeWaterTemp =>
      'Vízhőmérséklet - a merülések során rögzített hőmérsékleti adatok';

  @override
  String get settings_dataSources_appleHealth_permissionManagedInHealth =>
      'A HealthKit hozzáférést a Health alkalmazásban kezelheted';

  @override
  String get settings_dataSources_appleHealth_permissionUnsupported =>
      'A HealthKit nem érhető el ezen az eszközön';
}
