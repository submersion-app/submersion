import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The media surfaces all name their one destructive action with the same
/// word, and that has to hold in every language, not just English.
///
/// The library's button and the dive/site sections' button are separate ARB
/// keys, so nothing but this test stops a translator from picking a second
/// verb for the second key. That is not hypothetical: German carried
/// "Loesen" in the library and "Trennen" on the dive, which put two verbs
/// for one action inside a single confirmation dialog.
void main() {
  test('every locale uses one verb for unlink across the media surfaces', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(
        l10n.media_library_unlinkSelected,
        l10n.media_diveMediaSection_unlinkButton,
        reason:
            'locale $locale names the same action two different ways: '
            'the library says "${l10n.media_library_unlinkSelected}" and the '
            'dive section says "${l10n.media_diveMediaSection_unlinkButton}"',
      );
    }
  });

  test('the confirmation titles agree across the media surfaces', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(
        l10n.media_library_unlinkConfirmTitle(3),
        l10n.media_diveMediaSection_unlinkSelectedTitle(3),
        reason: 'locale $locale',
      );
      expect(
        l10n.media_siteMediaSection_unlinkSelectedTitle(3),
        l10n.media_diveMediaSection_unlinkSelectedTitle(3),
        reason: 'locale $locale',
      );
    }
  });

  test('English says Unlink, not Delete or Remove', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.media_library_unlinkSelected, 'Unlink');
    expect(en.media_diveMediaSection_unlinkButton, 'Unlink');
    expect(en.media_library_unlinkConfirmTitle(2), 'Unlink 2 items?');
    expect(
      en.media_siteMediaSection_unlinkSelectedSuccess(2),
      'Unlinked 2 items',
    );
  });
}
