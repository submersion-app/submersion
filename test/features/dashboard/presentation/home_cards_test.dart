import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/home_cards.dart';

void main() {
  group('reconcileHomeCardOrder', () {
    test('empty stored list returns the default order', () {
      expect(reconcileHomeCardOrder(const []), HomeCardType.values);
    });

    test('complete stored list is returned as stored', () {
      final reversed = HomeCardType.values.reversed.toList();
      expect(
        reconcileHomeCardOrder([for (final c in reversed) c.name]),
        reversed,
      );
    });

    test('unknown names are dropped', () {
      final stored = [
        'notACard',
        for (final c in HomeCardType.values) c.name,
        'alsoNotACard',
      ];
      expect(reconcileHomeCardOrder(stored), HomeCardType.values);
    });

    test('duplicate names keep the first occurrence', () {
      final stored = [
        for (final c in HomeCardType.values) c.name,
        HomeCardType.hero.name,
      ];
      expect(reconcileHomeCardOrder(stored), HomeCardType.values);
    });

    test('missing card is inserted after its closest preceding default '
        'neighbor present in the stored order', () {
      // Default order: ..., recentDives, quickActions, milestones, ...
      // Store everything except quickActions, with milestones moved first.
      final stored = [
        HomeCardType.milestones.name,
        for (final c in HomeCardType.values)
          if (c != HomeCardType.quickActions && c != HomeCardType.milestones)
            c.name,
      ];
      final result = reconcileHomeCardOrder(stored);
      // quickActions' closest preceding default neighbor is recentDives,
      // so it lands immediately after recentDives (NOT after milestones,
      // which the user moved away).
      final recentDivesIndex = result.indexOf(HomeCardType.recentDives);
      expect(result[recentDivesIndex + 1], HomeCardType.quickActions);
      expect(result.toSet(), HomeCardType.values.toSet());
    });

    test(
      'missing card with no preceding neighbor present goes to the front',
      () {
        // Store only the LAST default card; hero (default index 0) has no
        // preceding neighbor, so it is inserted at the front.
        final stored = [HomeCardType.recentSitesMap.name];
        final result = reconcileHomeCardOrder(stored);
        expect(result.first, HomeCardType.hero);
        expect(result.toSet(), HomeCardType.values.toSet());
      },
    );
  });
}
