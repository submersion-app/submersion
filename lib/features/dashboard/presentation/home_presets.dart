import 'package:flutter/foundation.dart';

import 'package:submersion/features/dashboard/presentation/home_panels.dart';

/// Ready-made Home layouts. A preset is only a starting point: the diver can
/// show, hide and reorder panels afterwards, which makes the layout Custom.
enum HomeLayoutPreset { balanced, ready, trends, logbook }

/// The "only when relevant" panels every preset opens with, under the key
/// numbers: things waiting on the diver come before anything to read.
const _waitingOnYou = [
  HomePanelType.waitingForDownload,
  HomePanelType.preDive,
  HomePanelType.activeCourses,
];

/// The panels a preset shows, in order. Every other panel is hidden.
List<HomePanelType> homePresetPanels(HomeLayoutPreset preset) =>
    switch (preset) {
      // Recent outings in the calendar's place (issue #4898): most divers dive
      // in a few trips a year, so a fixed window of days is mostly empty.
      HomeLayoutPreset.balanced => const [
        HomePanelType.keyNumbers,
        ..._waitingOnYou,
        HomePanelType.recentOutings,
        HomePanelType.gearService,
        HomePanelType.latestProfile,
        HomePanelType.recentDives,
        HomePanelType.depthMix,
        HomePanelType.divesPerMonth,
        HomePanelType.gasMix,
        HomePanelType.photoRibbon,
        HomePanelType.recentSitesMap,
        HomePanelType.onThisDay,
      ],
      // Next trip is conditional, so it joins the run at the top: placed
      // between gear service and coming due it would split them apart.
      HomeLayoutPreset.ready => const [
        HomePanelType.keyNumbers,
        ..._waitingOnYou,
        HomePanelType.nextTrip,
        HomePanelType.gearService,
        HomePanelType.comingDue,
        HomePanelType.recentDives,
        HomePanelType.photoRibbon,
        HomePanelType.recentSitesMap,
      ],
      HomeLayoutPreset.trends => const [
        HomePanelType.keyNumbers,
        ..._waitingOnYou,
        HomePanelType.activityCalendar,
        HomePanelType.divesPerMonth,
        HomePanelType.sacTrend,
        HomePanelType.depthMix,
        HomePanelType.gasMix,
        HomePanelType.topSites,
        HomePanelType.topBuddies,
        HomePanelType.diveTypes,
      ],
      // Latest vs average follows the outings so a desktop row is full.
      HomeLayoutPreset.logbook => const [
        HomePanelType.keyNumbers,
        ..._waitingOnYou,
        HomePanelType.recentOutings,
        HomePanelType.latestVsAverage,
        HomePanelType.latestProfile,
        HomePanelType.recentDives,
        HomePanelType.photoRibbon,
        HomePanelType.recentSitesMap,
        HomePanelType.speciesSeen,
        HomePanelType.onThisDay,
      ],
    };

/// A diver's Home layout: every panel exactly once, in display order, and
/// the ones switched off.
@immutable
class HomeLayout {
  final List<HomePanelType> order;
  final Set<HomePanelType> hidden;

  const HomeLayout({required this.order, required this.hidden});

  List<HomePanelType> get visible => [
    for (final p in order)
      if (!hidden.contains(p)) p,
  ];

  HomeLayout withPanelEnabled(HomePanelType panel, bool enabled) => HomeLayout(
    order: order,
    hidden: enabled ? ({...hidden}..remove(panel)) : {...hidden, panel},
  );

  /// [newOrder] must hold every panel exactly once.
  HomeLayout withOrder(List<HomePanelType> newOrder) =>
      HomeLayout(order: List.unmodifiable(newOrder), hidden: hidden);

  List<String> get orderNames => [for (final p in order) p.name];
  Set<String> get hiddenNames => {for (final p in hidden) p.name};
}

HomeLayout homeLayoutForPreset(HomeLayoutPreset preset) {
  final shown = homePresetPanels(preset);
  final rest = [
    for (final p in HomePanelType.values)
      if (!shown.contains(p)) p,
  ];
  return HomeLayout(
    order: List.unmodifiable([...shown, ...rest]),
    hidden: rest.toSet(),
  );
}

/// The diver's layout from what is stored.
///
/// With nothing stored yet (the first run of this Home), the layout is
/// Balanced, with any Balanced panel the diver had hidden as a card before
/// the upgrade kept hidden. Otherwise the stored order is cleaned (unknown
/// names dropped, duplicates collapsed) and any panel it lacks, added in a
/// later version, is slotted in hidden after its nearest earlier neighbour.
/// An order with no known panel left is treated as nothing stored.
HomeLayout resolveHomeLayout({
  required List<String>? storedOrder,
  required Set<String>? storedHidden,
  required Set<String> legacyHiddenCards,
}) {
  final byName = {for (final p in HomePanelType.values) p.name: p};

  if (storedOrder == null && storedHidden == null) {
    final balanced = homeLayoutForPreset(HomeLayoutPreset.balanced);
    return HomeLayout(
      order: balanced.order,
      hidden: {
        ...balanced.hidden,
        for (final name in legacyHiddenCards)
          if (byName[name] != null) byName[name]!,
      },
    );
  }

  final order = <HomePanelType>[];
  final seen = <HomePanelType>{};
  for (final name in storedOrder ?? const <String>[]) {
    final panel = byName[name];
    if (panel != null && seen.add(panel)) order.add(panel);
  }
  final hidden = <HomePanelType>{
    for (final name in storedHidden ?? const <String>{})
      if (byName[name] != null) byName[name]!,
  };
  // Nothing usable survived (a corrupt or foreign value): start from
  // Balanced rather than hide every panel.
  if (order.isEmpty) return homeLayoutForPreset(HomeLayoutPreset.balanced);
  for (var i = 0; i < HomePanelType.values.length; i++) {
    final panel = HomePanelType.values[i];
    if (seen.contains(panel)) continue;
    var insertAt = 0;
    for (var j = i - 1; j >= 0; j--) {
      final at = order.indexOf(HomePanelType.values[j]);
      if (at != -1) {
        insertAt = at + 1;
        break;
      }
    }
    order.insert(insertAt, panel);
    seen.add(panel);
    hidden.add(panel);
  }
  return HomeLayout(order: List.unmodifiable(order), hidden: hidden);
}

/// The preset whose panels are exactly the layout's visible ones, in order,
/// or null when the diver has made it their own. Worked out rather than
/// stored, so a preset changed in a later version cannot leave a stale name.
HomeLayoutPreset? matchingPreset(HomeLayout layout) {
  final visible = layout.visible;
  for (final preset in HomeLayoutPreset.values) {
    if (listEquals(homePresetPanels(preset), visible)) return preset;
  }
  return null;
}
