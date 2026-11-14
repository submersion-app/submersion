import 'package:submersion/l10n/arb/app_localizations.dart';

/// The speed group a Buhlmann tissue compartment belongs to, so the Tissue
/// Loading card can say what a compartment number stands for (issue #4503).
///
/// The tissue named in each label is a rough example, not an anatomical
/// mapping: the model's compartments are mathematical.
enum CompartmentGroup {
  /// Compartments 1-5: they limit short, deep dives.
  fast,

  /// Compartments 6-10.
  medium,

  /// Compartments 11-16: they limit long and repeat dives.
  slow;

  /// The group of the 1-based [compartmentNumber].
  static CompartmentGroup ofNumber(int compartmentNumber) {
    if (compartmentNumber <= 5) return CompartmentGroup.fast;
    if (compartmentNumber <= 10) return CompartmentGroup.medium;
    return CompartmentGroup.slow;
  }

  String label(AppLocalizations l10n) => switch (this) {
    CompartmentGroup.fast => l10n.diveLog_deco_groupFast,
    CompartmentGroup.medium => l10n.diveLog_deco_groupMedium,
    CompartmentGroup.slow => l10n.diveLog_deco_groupSlow,
  };
}
