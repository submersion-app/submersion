/// The customizable home screen cards. Declaration order is the default
/// display order and must match the pre-customization dashboard layout.
/// Every card here is hideable, with one override: DashboardPage forces
/// [HomeCardType.gaugeStrip] back on while a dive-safety alert is live, so
/// GaugeStrip's hardened chips cannot be hidden by hiding their host card.
enum HomeCardType {
  hero,
  gaugeStrip,
  preDive,
  recentDives,
  quickActions,
  milestones,
  yearInReview,
  // photoRibbon and recentSitesMap are declared adjacent so the default
  // layout pairs them side by side at desktop widths (see home_layout.dart).
  photoRibbon,
  recentSitesMap,
  onThisDay,
  activeCourses,
}

/// Turns a stored order (HomeCardType.name strings from SharedPreferences)
/// into the effective card order:
/// - unknown names are dropped (card removed in a later app version),
/// - duplicates keep the first occurrence,
/// - missing types (card added in a later app version) are inserted
///   immediately after their closest preceding default-order neighbor
///   present in the result, or at the front if none is.
List<HomeCardType> reconcileHomeCardOrder(List<String> stored) {
  final byName = {for (final c in HomeCardType.values) c.name: c};
  final seen = <HomeCardType>{};
  final result = <HomeCardType>[
    for (final name in stored)
      if (byName[name] != null && seen.add(byName[name]!)) byName[name]!,
  ];
  for (var i = 0; i < HomeCardType.values.length; i++) {
    final card = HomeCardType.values[i];
    if (seen.contains(card)) continue;
    var insertAt = 0;
    for (var j = i - 1; j >= 0; j--) {
      final neighborIndex = result.indexOf(HomeCardType.values[j]);
      if (neighborIndex != -1) {
        insertAt = neighborIndex + 1;
        break;
      }
    }
    result.insert(insertAt, card);
    seen.add(card);
  }
  return result;
}
