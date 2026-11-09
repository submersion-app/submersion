import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The localized name of [abundance], as its chip in the "How many" picker
/// shows it.
String sightingAbundanceName(
  AppLocalizations l10n,
  SightingAbundance abundance,
) => switch (abundance) {
  SightingAbundance.seen => l10n.marineLife_abundance_seen,
  SightingAbundance.single => l10n.marineLife_abundance_single,
  SightingAbundance.few => l10n.marineLife_abundance_few,
  SightingAbundance.many => l10n.marineLife_abundance_many,
  SightingAbundance.abundant => l10n.marineLife_abundance_abundant,
  SightingAbundance.exact => l10n.marineLife_abundance_exact,
};

/// The badge text for a sighting: none for Seen (the diver gave no number),
/// `x<n>` for an exact count (`x1` included, since a 1 is deliberate), and
/// the REEF group's name otherwise.
String? sightingAmountLabel(AppLocalizations l10n, SightingAmount amount) =>
    switch (amount.abundance) {
      SightingAbundance.seen => null,
      SightingAbundance.exact => 'x${amount.count}',
      final group => sightingAbundanceName(l10n, group),
    };
