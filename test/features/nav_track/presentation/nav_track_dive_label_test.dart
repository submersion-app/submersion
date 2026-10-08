import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_dive_label.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('navTrackDiveLabel', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('a numbered dive is labelled by its number', () {
      final dive = Dive(
        id: 'dive-1',
        diveNumber: 412,
        dateTime: DateTime(2026),
      );

      expect(navTrackDiveLabel(l10n, 'dive-1', dive), 'Dive #412');
    });

    test('a dive without a number is labelled by its id, never as #<id>', () {
      final dive = Dive(id: 'dive-1', dateTime: DateTime(2026));

      expect(navTrackDiveLabel(l10n, 'dive-1', dive), 'Dive dive-1');
    });

    test('a dive still loading (or missing) is labelled by its id', () {
      expect(navTrackDiveLabel(l10n, 'dive-1', null), 'Dive dive-1');
    });
  });
}
