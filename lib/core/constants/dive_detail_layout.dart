import 'package:submersion/l10n/arb/app_localizations.dart';

/// How the Dive Details page arranges its sections.
///
/// The layout never changes *which* sections render -- that stays the diver's
/// per-section visibility choice -- only how much room each one gets.
enum DiveDetailLayout {
  /// Full-size cards, every visualization at its natural height.
  detailed,

  /// Every section folded behind a single-row header, unfolded on tap.
  list;

  /// Parse from a stored string, defaulting to [detailed].
  ///
  /// Also covers the removed `compact` layout: a diver who selected it before
  /// it was dropped reads back as [detailed].
  static DiveDetailLayout fromName(String? name) {
    if (name == null) return DiveDetailLayout.detailed;
    return DiveDetailLayout.values.firstWhere(
      (e) => e.name == name,
      orElse: () => DiveDetailLayout.detailed,
    );
  }

  /// Localized name shown in the display-options menu.
  String localizedName(AppLocalizations l10n) => switch (this) {
    detailed => l10n.diveDetailLayout_detailed,
    list => l10n.diveDetailLayout_list,
  };

  /// Vertical gap between two consecutive sections.
  ///
  /// [list] folds each section to a header row, so its sections sit close
  /// together the way rows of a list do.
  double get sectionGap => switch (this) {
    detailed => 24,
    list => 8,
  };

  /// Padding around the whole scrolling body.
  double get pagePadding => switch (this) {
    detailed => 16,
    list => 8,
  };

  /// Gap between the header block and the first section.
  double get headerGap => switch (this) {
    detailed => 24,
    list => 16,
  };

  /// Whether two sections that pair may render side by side.
  ///
  /// False in [list], where every section is one full-width folded row.
  bool get pairsSections => this != DiveDetailLayout.list;

  /// Whether each section is wrapped in a fold that starts collapsed.
  bool get foldsSections => this == DiveDetailLayout.list;
}
