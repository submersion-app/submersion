import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('DiveDetailLayout.fromName', () {
    test('round-trips every layout', () {
      for (final layout in DiveDetailLayout.values) {
        expect(DiveDetailLayout.fromName(layout.name), layout);
      }
    });

    // The column is nullable, so every diver who predates it reads back null.
    test('null and unknown names fall back to detailed', () {
      expect(DiveDetailLayout.fromName(null), DiveDetailLayout.detailed);
      expect(DiveDetailLayout.fromName(''), DiveDetailLayout.detailed);
      expect(DiveDetailLayout.fromName('spacious'), DiveDetailLayout.detailed);
      // 'compact' was a layout that shipped in an earlier revision.
      expect(DiveDetailLayout.fromName('compact'), DiveDetailLayout.detailed);
    });
  });

  group('spacing', () {
    test('detailed keeps the spacing the page shipped with', () {
      expect(DiveDetailLayout.detailed.sectionGap, 24);
      expect(DiveDetailLayout.detailed.pagePadding, 16);
      expect(DiveDetailLayout.detailed.headerGap, 24);
    });

    test('the list layout is tighter than detailed', () {
      const order = [DiveDetailLayout.detailed, DiveDetailLayout.list];
      for (var i = 1; i < order.length; i++) {
        expect(order[i].sectionGap, lessThan(order[i - 1].sectionGap));
        expect(order[i].pagePadding, lessThan(order[i - 1].pagePadding));
      }
    });
  });

  group('section arrangement', () {
    test('only the list layout folds its sections', () {
      expect(DiveDetailLayout.detailed.foldsSections, isFalse);
      expect(DiveDetailLayout.list.foldsSections, isTrue);
    });

    // A folded section is one full-width row; pairing it would put two
    // headers on a line and hide which content belongs to which.
    test('the list layout does not pair sections side by side', () {
      expect(DiveDetailLayout.detailed.pairsSections, isTrue);
      expect(DiveDetailLayout.list.pairsSections, isFalse);
    });
  });

  group('localizedName', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('names every layout', () {
      expect(DiveDetailLayout.detailed.localizedName(l10n), 'Detailed');
      expect(DiveDetailLayout.list.localizedName(l10n), 'List');
    });
  });
}
