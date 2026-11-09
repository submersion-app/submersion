// pre-push: scans lib/l10n/arb/
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Regression coverage for issue #4331: the German UI addressed the user with
/// the formal "Sie", while newer strings already used "du". Leisure apps and
/// divers talking to each other use the informal form, so every string now
/// does.
///
/// A capitalised "Sie", "Ihnen" or "Ihr..." in the middle of a sentence can
/// only be the formal address: the third-person "sie" (she, they, it) and
/// "ihr" (her, their, its) are lowercase there. At the start of a sentence
/// the capital is ambiguous ("Sie wird gespeichert" means "it is saved"), so
/// those positions are not checked.
void main() {
  late AppLocalizations de;
  late Map<String, dynamic> arb;

  setUpAll(() {
    de = lookupAppLocalizations(const Locale('de'));
    arb =
        json.decode(File('lib/l10n/arb/app_de.arb').readAsStringSync())
            as Map<String, dynamic>;
  });

  final formal = RegExp(r'\b(Sie|Ihnen|Ihr|Ihre|Ihren|Ihrem|Ihrer|Ihres)\b');

  /// Characters after which a new sentence (or a plural branch, or a quoted
  /// phrase) begins, so a capital there says nothing about formality.
  const sentenceStarts = {'.', '!', '?', ':', '\n', '{', '"', '„', '“'};

  bool atSentenceStart(String value, int index) {
    final before = value.substring(0, index).trimRight();
    if (before.isEmpty) return true;
    return sentenceStarts.contains(before[before.length - 1]);
  }

  test('no German string addresses the user formally', () {
    final offenders = <String>[];
    arb.forEach((key, value) {
      if (key.startsWith('@') || value is! String) return;
      for (final match in formal.allMatches(value)) {
        if (!atSentenceStart(value, match.start)) {
          offenders.add('$key = $value');
          break;
        }
      }
    });

    expect(
      offenders,
      isEmpty,
      reason:
          'German strings must use "du", not "Sie". Offending keys:\n'
          '${offenders.join('\n')}',
    );
  });

  /// Keys whose sentence-initial "Sie" or "Ihr..." was checked against the
  /// English source and means "it", "they", "its" or "their" (or, in
  /// buddySwap_nearby_hint, the informal plural "ihr"). A new key with a
  /// sentence-initial capital needs the same check before it joins this list.
  const thirdPersonKeys = {
    'backup_copySheet_deviceLocked',
    'backup_operation_createdLocalOnlyLocked',
    'backup_quarantined_status_unreadable',
    'buddySwap_nearby_hint',
    'changeLog_clear_body',
    'changeLog_revert_note',
    'checklists_delete_content',
    'dataQuality_msg_transmitterRoleBailout',
    'diveLab_link_unlinkBody',
    'diveLog_deco_info_body',
    'emergencyCard_chambersNoneNearby',
    'equipment_transfer_keepAccessHint',
    'gasCalculators_mod_aboutModesBody',
    'gpsTrack_importError_unreadable',
    'insights_empty_allExcluded_subtitle',
    'insights_gas_twinSetReview_body',
    'maps_offline_deleteRegionLegacyMessage',
    'media_library_unlinkConfirmBody',
    'planning_disclaimer_dialog_body',
    'preDive_runner_abortConfirm',
    'safetyHub_tissueLoading_clear_body',
    'settings_cloudSync_cleanup_banner',
    'settings_cloudSync_peerRequiresUpdate_stableAction',
    'settings_cloudSync_peerRequiresUpdate_storeAction',
    'settings_connectedAccounts_signOutConfirmBody',
    'settings_mediaSources_checkAllBlocked',
    'settings_photos_reconnect_heldOnly',
    'settings_syncDevices_removeDialog_bodySafe',
    'sharedLibrary_library_removedBanner',
    'sites_unshareConfirm_body',
    'startup_versionMismatch_restore_warning',
    'trips_cylinders_deleteConfirmUsed',
    'trips_delete_divesReturnToParent',
    'trips_delete_sideTripsStandalone',
    'trips_unshareConfirm_body',
    'universalImport_summary_noticeMacdiveDeviceTimeZoneBody',
    'web_googleClientId_body',
    'web_googleClientId_invalid',
  };

  test('a sentence-initial Sie or Ihr appears only in reviewed keys', () {
    // The mid-sentence check above cannot tell "Sie haben" (you have) from
    // "Sie haben" (they have), so every sentence-initial capital must be in
    // a key a person has read.
    final unreviewed = <String>[];
    arb.forEach((key, value) {
      if (key.startsWith('@') || value is! String) return;
      if (thirdPersonKeys.contains(key)) return;
      if (formal.hasMatch(value)) unreviewed.add('$key = $value');
    });

    expect(
      unreviewed,
      isEmpty,
      reason:
          'Use "du" here, or if "Sie"/"Ihr" means it, they or its, add the '
          'key to thirdPersonKeys:\n${unreviewed.join('\n')}',
    );
  });

  test('the generated German localizations use the informal form', () {
    expect(de.setup_profile_title, 'Erstelle dein Profil');
    expect(
      de.buddies_dialog_discardMessage,
      'Du hast nicht gespeicherte Änderungen. '
      'Möchtest du diese wirklich verwerfen?',
    );
    expect(
      de.insights_observations_diveCountMilestone('100', '1.1.2026'),
      'Du hast am 1.1.2026 100 Tauchgänge erreicht',
    );
  });
}
