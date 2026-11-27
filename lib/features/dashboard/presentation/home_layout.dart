import 'package:flutter/widgets.dart';

import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// The three widths Home lays out for.
enum HomeWidthTier { phone, tablet, desktop }

/// Every row is this many units wide; a panel's width class maps to units.
const int homeRowUnits = 12;

HomeWidthTier homeWidthTierForWidth(double width) {
  if (width >= ResponsiveBreakpoints.desktopExtended) {
    return HomeWidthTier.desktop;
  }
  if (width >= ResponsiveBreakpoints.desktop) return HomeWidthTier.tablet;
  return HomeWidthTier.phone;
}

/// The tier for the current screen, using the same width the rest of the
/// app's breakpoints read.
HomeWidthTier homeWidthTierOf(BuildContext context) =>
    homeWidthTierForWidth(ResponsiveBreakpoints.screenWidth(context));

int homePanelUnits(HomePanelWidth width, HomeWidthTier tier) =>
    switch ((width, tier)) {
      (HomePanelWidth.xl, _) => 12,
      (HomePanelWidth.l, HomeWidthTier.desktop) => 8,
      (HomePanelWidth.l, _) => 12,
      (HomePanelWidth.m, HomeWidthTier.phone) => 12,
      (HomePanelWidth.m, _) => 6,
      (HomePanelWidth.sChart, HomeWidthTier.desktop) => 4,
      (HomePanelWidth.sChart, _) => 6,
      (HomePanelWidth.sList, HomeWidthTier.desktop) => 4,
      (HomePanelWidth.sList, HomeWidthTier.tablet) => 6,
      (HomePanelWidth.sList, HomeWidthTier.phone) => 12,
    };

/// One row of the grid: its panels in order, each with its share of the row
/// in units, and the height every panel in it is given.
@immutable
class HomeRow {
  final List<HomePanelType> panels;

  /// Raw units per panel. They may sum to less than [homeRowUnits]; the grid
  /// uses them as flex weights, which stretches the row to the full width.
  final List<int> units;
  final HomePanelHeight height;

  const HomeRow({
    required this.panels,
    required this.units,
    required this.height,
  });
}

/// Packs the diver's visible panels, in their order, into rows that never
/// exceed [homeRowUnits].
///
/// A panel starts a new row when it does not fit, and also whenever it
/// differs from the panel before it in being conditional. So a run of
/// "only when relevant" panels always forms a row of its own: one of them
/// arriving late changes that one row, never which panels share the rows
/// below it (which would remount them, the sites map included).
///
/// The diver's order is never changed to make rows fit.
List<HomeRow> packHomeRows(List<HomePanelType> visible, HomeWidthTier tier) {
  final rows = <HomeRow>[];
  var panels = <HomePanelType>[];
  var units = <int>[];
  var used = 0;

  void close() {
    if (panels.isEmpty) return;
    final height = panels
        .map((p) => homePanelSpec(p).height)
        .reduce((a, b) => a.index >= b.index ? a : b);
    rows.add(HomeRow(panels: panels, units: units, height: height));
    panels = <HomePanelType>[];
    units = <int>[];
    used = 0;
  }

  for (final panel in visible) {
    final spec = homePanelSpec(panel);
    final u = homePanelUnits(spec.width, tier);
    if (panels.isNotEmpty &&
        (used + u > homeRowUnits ||
            spec.conditional != homePanelSpec(panels.last).conditional)) {
      close();
    }
    panels.add(panel);
    units.add(u);
    used += u;
  }
  close();
  return rows;
}
