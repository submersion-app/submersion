import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';

void main() {
  test('every panel has a spec', () {
    for (final type in HomePanelType.values) {
      expect(() => homePanelSpec(type), returnsNormally);
    }
  });

  test('names shared with the old card enum are unchanged', () {
    // The upgrade reads the old hidden-card set by these names.
    expect(
      HomePanelType.values.map((t) => t.name),
      containsAll(<String>[
        'waitingForDownload',
        'preDive',
        'activeCourses',
        'recentDives',
        'photoRibbon',
        'recentSitesMap',
        'onThisDay',
      ]),
    );
  });

  test('key numbers is the only full-width panel', () {
    final xl = HomePanelType.values.where(
      (t) => homePanelSpec(t).width == HomePanelWidth.xl,
    );
    expect(xl, [HomePanelType.keyNumbers]);
  });

  test('only the four chart panels are S chart', () {
    final charts = HomePanelType.values
        .where((t) => homePanelSpec(t).width == HomePanelWidth.sChart)
        .toSet();
    expect(charts, {
      HomePanelType.depthMix,
      HomePanelType.divesPerMonth,
      HomePanelType.gasMix,
      HomePanelType.diveTypes,
    });
  });

  test('recent photos is a third of a desktop row', () {
    expect(
      homePanelSpec(HomePanelType.photoRibbon).width,
      HomePanelWidth.sList,
    );
  });

  test('conditional panels are exactly the ones that need content', () {
    final conditional = HomePanelType.values
        .where((t) => homePanelSpec(t).conditional)
        .toSet();
    expect(conditional, {
      HomePanelType.waitingForDownload,
      HomePanelType.preDive,
      HomePanelType.activeCourses,
      HomePanelType.nextTrip,
      HomePanelType.speciesSeen,
      HomePanelType.photoRibbon,
      HomePanelType.recentSitesMap,
      HomePanelType.onThisDay,
    });
  });

  test('the deepest and average depth tiles are off by default', () {
    expect(defaultHiddenKeyNumbers, {
      HomeKeyNumber.deepestThisYear,
      HomeKeyNumber.avgDepth,
    });
  });

  // Species takes the deepest tile's old place, between the gas tile and
  // the next trip.
  test('species comes after the gas tile and before the next trip', () {
    const order = HomeKeyNumber.values;
    expect(
      order.indexOf(HomeKeyNumber.species),
      order.indexOf(HomeKeyNumber.avgSac) + 1,
    );
    expect(
      order.indexOf(HomeKeyNumber.nextTrip),
      order.indexOf(HomeKeyNumber.species) + 1,
    );
  });
}
