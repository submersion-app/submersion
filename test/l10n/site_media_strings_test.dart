import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Every locale must carry the site-media and document-viewer strings added
/// for #211/#627: gen-l10n falls back to English silently, so a locale that
/// never got the keys would ship looking fine in CI and wrong to the user.
void main() {
  /// The 14 strings this feature introduced, resolved for [locale].
  List<String> siteMediaStrings(AppLocalizations l10n) => <String>[
    l10n.media_siteMediaSection_title,
    l10n.media_siteMediaSection_addPhotos,
    l10n.media_siteMediaSection_addDocument,
    l10n.media_siteMediaSection_emptyState,
    l10n.media_siteMediaSection_divePhotosGroup(3),
    l10n.media_siteMediaSection_divePhotoLabel,
    l10n.media_siteMediaSection_unlinkSelectedTitle(2),
    l10n.media_siteMediaSection_unlinkSelectedContent(2),
    l10n.media_siteMediaSection_unlinkSelectedSuccess(2),
    // The site surface owns its failure string rather than borrowing the
    // dive section's, so a locale that never got it fails here.
    l10n.media_siteMediaSection_unlinkError('boom'),
    l10n.media_documentViewer_title,
    l10n.media_documentViewer_unavailable,
    l10n.media_documentViewer_availableOnOriginDevice,
    l10n.media_documentViewer_attached(2),
  ];

  test('every supported locale resolves the site media strings', () {
    for (final locale in AppLocalizations.supportedLocales) {
      for (final value in siteMediaStrings(lookupAppLocalizations(locale))) {
        expect(value, isNotEmpty, reason: 'locale $locale');
      }
    }
  });

  test('no locale silently shipped the English source text', () {
    // The empty state is long and distinctive, so an untranslated locale
    // (a key copied over verbatim to satisfy gen-l10n) shows up here.
    final english = lookupAppLocalizations(
      const Locale('en'),
    ).media_siteMediaSection_emptyState;

    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      expect(
        lookupAppLocalizations(locale).media_siteMediaSection_emptyState,
        isNot(english),
        reason: 'locale $locale is still carrying the English string',
      );
    }
  });

  test('counted strings interpolate their count in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(
        l10n.media_siteMediaSection_divePhotosGroup(7),
        contains('7'),
        reason: 'locale $locale',
      );
      expect(
        l10n.media_siteMediaSection_unlinkSelectedTitle(7),
        contains('7'),
        reason: 'locale $locale',
      );
      expect(
        l10n.media_siteMediaSection_unlinkSelectedSuccess(7),
        contains('7'),
        reason: 'locale $locale',
      );
      expect(
        l10n.media_documentViewer_attached(7),
        contains('7'),
        reason: 'locale $locale',
      );
    }
  });

  test('English reads the way the UI expects', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.media_siteMediaSection_title, 'Site Media');
    expect(en.media_siteMediaSection_addDocument, 'Add document');
    expect(
      en.media_siteMediaSection_divePhotosGroup(4),
      'Photos from dives here (4)',
    );
    expect(en.media_documentViewer_title, 'Document');
  });

  test('a sampled locale is really translated, not transliterated', () {
    final de = lookupAppLocalizations(const Locale('de'));
    expect(de.media_siteMediaSection_addDocument, 'Dokument hinzufügen');
    expect(de.media_documentViewer_title, 'Dokument');

    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(fr.media_siteMediaSection_addPhotos, 'Ajouter des photos ou vidéos');
  });
}
