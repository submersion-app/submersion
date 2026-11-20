import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';

const _balanced = [
  HomePanelType.keyNumbers,
  HomePanelType.waitingForDownload,
  HomePanelType.preDive,
  HomePanelType.activeCourses,
  HomePanelType.activityCalendar,
  HomePanelType.gearService,
  HomePanelType.latestProfile,
  HomePanelType.recentDives,
  HomePanelType.depthMix,
  HomePanelType.divesPerMonth,
  HomePanelType.gasMix,
  HomePanelType.photoRibbon,
  HomePanelType.recentSitesMap,
  HomePanelType.onThisDay,
];

int _sum(HomeRow r) => r.units.reduce((a, b) => a + b);

void main() {
  test('desktop Balanced rows match the approved mockup', () {
    final rows = packHomeRows(_balanced, HomeWidthTier.desktop);
    expect(rows.map((r) => r.panels).toList(), [
      [HomePanelType.keyNumbers],
      [
        HomePanelType.waitingForDownload,
        HomePanelType.preDive,
        HomePanelType.activeCourses,
      ],
      [HomePanelType.activityCalendar, HomePanelType.gearService],
      [HomePanelType.latestProfile, HomePanelType.recentDives],
      [
        HomePanelType.depthMix,
        HomePanelType.divesPerMonth,
        HomePanelType.gasMix,
      ],
      [
        HomePanelType.photoRibbon,
        HomePanelType.recentSitesMap,
        HomePanelType.onThisDay,
      ],
    ]);
    for (final r in rows) {
      expect(_sum(r), 12);
    }
  });

  test('a row takes the tallest height in it', () {
    final rows = packHomeRows([
      HomePanelType.keyNumbers,
      HomePanelType.recentDives,
    ], HomeWidthTier.desktop);
    expect(rows[0].height, HomePanelHeight.short);
    expect(rows[1].height, HomePanelHeight.medium);
  });

  test('no row exceeds 12 units and order is kept, at any tier', () {
    final random = Random(1);
    for (var i = 0; i < 500; i++) {
      final panels = [...HomePanelType.values]..shuffle(random);
      final subset = panels.take(random.nextInt(panels.length) + 1).toList();
      for (final tier in HomeWidthTier.values) {
        final rows = packHomeRows(subset, tier);
        expect(rows.expand((r) => r.panels).toList(), subset);
        for (final r in rows) {
          expect(r.panels, isNotEmpty);
          expect(r.units.length, r.panels.length);
          expect(_sum(r), lessThanOrEqualTo(12));
        }
      }
    }
  });

  test('conditional panels never share a row with other panels', () {
    final random = Random(2);
    for (var i = 0; i < 200; i++) {
      final panels = [...HomePanelType.values]..shuffle(random);
      for (final tier in HomeWidthTier.values) {
        for (final r in packHomeRows(panels, tier)) {
          final flags = r.panels.map((p) => homePanelSpec(p).conditional);
          expect(flags.toSet().length, 1, reason: '${r.panels}');
        }
      }
    }
  });

  test('a conditional panel arriving changes only its own row', () {
    final withAll = packHomeRows(_balanced, HomeWidthTier.desktop);
    final withOne = packHomeRows(
      _balanced
          .where(
            (p) =>
                p != HomePanelType.preDive && p != HomePanelType.activeCourses,
          )
          .toList(),
      HomeWidthTier.desktop,
    );
    List<List<HomePanelType>> others(List<HomeRow> rows) => [
      for (final r in rows)
        if (!r.panels.contains(HomePanelType.waitingForDownload)) r.panels,
    ];
    expect(others(withOne), others(withAll));
  });

  test('phone: small charts pair, small lists take a whole row', () {
    final rows = packHomeRows([
      HomePanelType.depthMix,
      HomePanelType.divesPerMonth,
      HomePanelType.gearService,
      HomePanelType.topSites,
    ], HomeWidthTier.phone);
    expect(rows.map((r) => r.panels).toList(), [
      [HomePanelType.depthMix, HomePanelType.divesPerMonth],
      [HomePanelType.gearService],
      [HomePanelType.topSites],
    ]);
  });

  test('tablet: large panels take a whole row', () {
    final rows = packHomeRows([
      HomePanelType.activityCalendar,
      HomePanelType.gearService,
      HomePanelType.recentDives,
    ], HomeWidthTier.tablet);
    expect(rows.map((r) => r.panels).toList(), [
      [HomePanelType.activityCalendar],
      [HomePanelType.gearService, HomePanelType.recentDives],
    ]);
  });

  test('an empty list gives no rows', () {
    expect(packHomeRows(const [], HomeWidthTier.desktop), isEmpty);
  });

  test('tier boundaries follow the app breakpoints', () {
    expect(homeWidthTierForWidth(320), HomeWidthTier.phone);
    expect(homeWidthTierForWidth(799), HomeWidthTier.phone);
    expect(homeWidthTierForWidth(800), HomeWidthTier.tablet);
    expect(homeWidthTierForWidth(1199), HomeWidthTier.tablet);
    expect(homeWidthTierForWidth(1200), HomeWidthTier.desktop);
  });
}
