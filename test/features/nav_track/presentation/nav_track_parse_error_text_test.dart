import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_parse_error_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('navTrackParseErrorText', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('every reason maps to a distinct localized message', () {
      final texts = {
        for (final reason in NavTrackParseReason.values)
          navTrackParseErrorText(
            l10n,
            NavTrackParseException('detail', reason: reason),
          ),
      };
      expect(texts.length, NavTrackParseReason.values.length);
    });

    test('the English technical detail never reaches the message', () {
      final text = navTrackParseErrorText(
        l10n,
        const NavTrackParseException(
          'row 42: unparsable Pos3Dx "abc"',
          reason: NavTrackParseReason.badData,
        ),
      );
      expect(text, isNot(contains('row 42')));
      expect(text, isNot(contains('Pos3Dx')));
    });
  });
}
