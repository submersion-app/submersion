/// Every panel the Home dashboard can show.
///
/// [name] is the stable id stored in the diver's panel order and hidden set,
/// so a value is never renamed. The seven names shared with the retired
/// `HomeCardType` (waitingForDownload, preDive, activeCourses, recentDives,
/// photoRibbon, recentSitesMap, onThisDay) are kept exactly: the first run of
/// the new Home reads the old hidden-card set by these names.
enum HomePanelType {
  keyNumbers,
  waitingForDownload,
  preDive,
  activeCourses,
  activityCalendar,
  recentOutings,
  gearService,
  comingDue,
  nextTrip,
  latestProfile,
  latestVsAverage,
  recentDives,
  sacTrend,
  depthMix,
  divesPerMonth,
  gasMix,
  diveTypes,
  topSites,
  topBuddies,
  speciesSeen,
  photoRibbon,
  recentSitesMap,
  onThisDay,
}

/// The tiles inside the key numbers panel, in the order they show. [name]
/// is stored in the hidden tile set, so a value is never renamed; the order
/// is free to change.
enum HomeKeyNumber {
  dives,
  timeUnder,
  lastDive,
  avgSac,
  species,
  nextTrip,
  deepestThisYear,
  avgDepth,
}

/// Tiles a diver sees switched off until they turn them on. Neither depth
/// tile is a headline by default: depth is not a score to chase.
const Set<HomeKeyNumber> defaultHiddenKeyNumbers = {
  HomeKeyNumber.deepestThisYear,
  HomeKeyNumber.avgDepth,
};

/// How wide a panel is, as a share of a desktop row. The units each class
/// takes at each width tier live in `home_layout.dart`.
///
/// The two small classes differ only on a phone: a small chart can sit two
/// across there, while a small list of named items needs the full width.
enum HomePanelWidth { sChart, sList, m, l, xl }

/// How tall a panel's row is. Fixed per class rather than measured, so rows
/// can be built lazily and panels in a row always line up.
enum HomePanelHeight { short, medium, tall }

class HomePanelSpec {
  final HomePanelWidth width;
  final HomePanelHeight height;

  /// Shown only once its data resolves to something worth showing; such
  /// panels always form a row of their own (see `packHomeRows`).
  final bool conditional;

  const HomePanelSpec(this.width, this.height, {this.conditional = false});
}

HomePanelSpec homePanelSpec(HomePanelType type) => switch (type) {
  HomePanelType.keyNumbers => const HomePanelSpec(
    HomePanelWidth.xl,
    HomePanelHeight.short,
  ),
  HomePanelType.waitingForDownload => const HomePanelSpec(
    HomePanelWidth.sList,
    HomePanelHeight.short,
    conditional: true,
  ),
  HomePanelType.preDive => const HomePanelSpec(
    HomePanelWidth.sList,
    HomePanelHeight.short,
    conditional: true,
  ),
  HomePanelType.activeCourses => const HomePanelSpec(
    HomePanelWidth.sList,
    HomePanelHeight.short,
    conditional: true,
  ),
  HomePanelType.activityCalendar => const HomePanelSpec(
    HomePanelWidth.l,
    HomePanelHeight.medium,
  ),
  HomePanelType.recentOutings => const HomePanelSpec(
    HomePanelWidth.l,
    HomePanelHeight.tall,
  ),
  HomePanelType.gearService => const HomePanelSpec(
    HomePanelWidth.sList,
    HomePanelHeight.medium,
  ),
  HomePanelType.comingDue => const HomePanelSpec(
    HomePanelWidth.sList,
    HomePanelHeight.medium,
  ),
  HomePanelType.nextTrip => const HomePanelSpec(
    HomePanelWidth.sList,
    HomePanelHeight.medium,
    conditional: true,
  ),
  HomePanelType.latestProfile => const HomePanelSpec(
    HomePanelWidth.m,
    HomePanelHeight.medium,
  ),
  HomePanelType.latestVsAverage => const HomePanelSpec(
    HomePanelWidth.sList,
    HomePanelHeight.medium,
  ),
  HomePanelType.recentDives => const HomePanelSpec(
    HomePanelWidth.m,
    HomePanelHeight.medium,
  ),
  HomePanelType.sacTrend => const HomePanelSpec(
    HomePanelWidth.m,
    HomePanelHeight.medium,
  ),
  HomePanelType.depthMix => const HomePanelSpec(
    HomePanelWidth.sChart,
    HomePanelHeight.medium,
  ),
  HomePanelType.divesPerMonth => const HomePanelSpec(
    HomePanelWidth.sChart,
    HomePanelHeight.medium,
  ),
  HomePanelType.gasMix => const HomePanelSpec(
    HomePanelWidth.sChart,
    HomePanelHeight.medium,
  ),
  HomePanelType.diveTypes => const HomePanelSpec(
    HomePanelWidth.sChart,
    HomePanelHeight.medium,
  ),
  HomePanelType.topSites => const HomePanelSpec(
    HomePanelWidth.sList,
    HomePanelHeight.medium,
  ),
  HomePanelType.topBuddies => const HomePanelSpec(
    HomePanelWidth.sList,
    HomePanelHeight.medium,
  ),
  HomePanelType.speciesSeen => const HomePanelSpec(
    HomePanelWidth.sList,
    HomePanelHeight.medium,
    conditional: true,
  ),
  HomePanelType.photoRibbon => const HomePanelSpec(
    HomePanelWidth.sList,
    HomePanelHeight.medium,
    conditional: true,
  ),
  HomePanelType.recentSitesMap => const HomePanelSpec(
    HomePanelWidth.sList,
    HomePanelHeight.medium,
    conditional: true,
  ),
  HomePanelType.onThisDay => const HomePanelSpec(
    HomePanelWidth.sList,
    HomePanelHeight.medium,
    conditional: true,
  ),
};
