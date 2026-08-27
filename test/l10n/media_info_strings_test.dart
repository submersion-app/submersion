import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Every locale must carry the media info panel strings. gen-l10n falls back
/// to English silently, so a locale that never got the keys would ship
/// looking fine in CI and wrong to the user.
void main() {
  /// The 68 strings this feature introduced, resolved for one locale.
  List<String> mediaInfoStrings(AppLocalizations l10n) => <String>[
    l10n.media_info_title,
    l10n.media_info_fileSection,
    l10n.media_info_filename,
    l10n.media_info_type,
    l10n.media_info_dimensions,
    l10n.media_info_size,
    l10n.media_info_taken,
    l10n.media_info_coordinates,
    l10n.media_info_unknown,
    l10n.media_info_typePhoto,
    l10n.media_info_typeVideo,
    l10n.media_info_typeDocument,
    l10n.media_info_typeSignature,
    l10n.media_info_originSection,
    l10n.media_info_source,
    l10n.media_info_reference,
    l10n.media_info_linkedOn,
    l10n.media_info_thisDevice,
    l10n.media_info_otherDevice,
    l10n.media_info_status,
    l10n.media_info_statusFound,
    l10n.media_info_statusMissing,
    l10n.media_info_statusUnchecked,
    l10n.media_info_lastChecked('1 Jan 2026'),
    l10n.media_info_backupSection,
    l10n.media_info_store,
    l10n.media_info_storeNotConnected,
    l10n.media_info_notEligible,
    l10n.media_info_backupFull,
    l10n.media_info_backupThumbOnly,
    l10n.media_info_backupRenditionOnly,
    l10n.media_info_backupNone,
    l10n.media_info_uploadedOn('1 Jan 2026'),
    l10n.media_info_queuePending,
    l10n.media_info_queueTransferring,
    l10n.media_info_queueFailed('network down'),
    l10n.media_info_servingSection,
    l10n.media_info_servingUnobserved,
    l10n.media_info_servingFailed,
    l10n.media_info_servedLocalDisk,
    l10n.media_info_servedGallery,
    l10n.media_info_servedStoreCache,
    l10n.media_info_servedStoreNetwork,
    l10n.media_info_servedNetworkUrl,
    l10n.media_info_servedConnectorCache,
    l10n.media_info_servedConnectorNetwork,
    l10n.media_info_servedEmbedded,
    l10n.media_info_servingFallbackNote,
    l10n.media_info_servingTierThumbnail,
    l10n.media_info_servingTierRendition,
    l10n.media_info_actionCheckNow,
    l10n.media_info_actionLocate,
    l10n.media_info_actionBackUpNow,
    l10n.media_info_actionRetryUpload,
    l10n.media_info_actionReveal,
    l10n.media_info_actionCopyPath,
    l10n.media_info_referenceCopied,
    l10n.media_info_checkFound,
    l10n.media_info_checkMissing,
    l10n.media_info_checkUnavailable,
    l10n.media_info_backupQueued,
    l10n.media_status_broken,
    l10n.media_status_transferFailed,
    l10n.media_status_transferring,
    l10n.media_status_queued,
    l10n.media_status_cloudOnly,
    l10n.media_status_notBackedUp,
    l10n.media_tile_infoMenuItem,
  ];

  test('every supported locale resolves the media info strings', () {
    for (final locale in AppLocalizations.supportedLocales) {
      for (final value in mediaInfoStrings(lookupAppLocalizations(locale))) {
        expect(value, isNotEmpty, reason: 'locale $locale');
      }
    }
  });

  test('no locale ships the English source text verbatim', () {
    final english = mediaInfoStrings(
      lookupAppLocalizations(const Locale('en')),
    );

    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final translated = mediaInfoStrings(lookupAppLocalizations(locale));
      // A handful of terms are legitimately identical across languages
      // (for example "Backup" and "Status" in German and Dutch), so this
      // asserts the catalog was translated as a whole rather than demanding
      // every single string differ.
      var identical = 0;
      for (var i = 0; i < english.length; i++) {
        if (english[i] == translated[i]) identical++;
      }
      expect(
        identical,
        lessThan(english.length ~/ 3),
        reason:
            'locale $locale looks untranslated: $identical of '
            '${english.length} strings match the English source',
      );
    }
  });

  test('placeholders survive translation in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(
        l10n.media_info_lastChecked('SENTINEL'),
        contains('SENTINEL'),
        reason: 'locale $locale dropped the date placeholder',
      );
      expect(
        l10n.media_info_uploadedOn('SENTINEL'),
        contains('SENTINEL'),
        reason: 'locale $locale dropped the date placeholder',
      );
      expect(
        l10n.media_info_queueFailed('SENTINEL'),
        contains('SENTINEL'),
        reason: 'locale $locale dropped the error placeholder',
      );
    }
  });
}
