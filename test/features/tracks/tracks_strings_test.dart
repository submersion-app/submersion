import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('every locale carries a translated Tracks label', () {
    final english = lookupAppLocalizations(const Locale('en'));
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(l10n.nav_tracks, isNotEmpty, reason: '$locale');
      if (locale.languageCode != 'en') {
        expect(
          l10n.tracks_empty_body,
          isNot(english.tracks_empty_body),
          reason: '$locale fell back to English',
        );
      }
    }
  });

  test('the empty state promises auto-matching for GPS tracks only', () {
    // Underwater tracks are only ever suggested since #2819; the diver
    // picks the dive, so the copy must not promise otherwise.
    final body = lookupAppLocalizations(const Locale('en')).tracks_empty_body;
    expect(
      body,
      contains('GPS tracks are matched to your dives automatically'),
    );
    expect(body, contains('you choose the dive for each underwater track'));
  });
}
