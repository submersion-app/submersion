import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('the match result names each count in its own slot', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    // Generated methods take placeholders alphabetically: linked, positioned.
    expect(
      l10n.tracks_match_result(1, 2),
      'Dives positioned: 2 · Underwater tracks linked: 1',
    );
  });

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
}
