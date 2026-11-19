import 'package:submersion/l10n/arb/app_localizations.dart';

/// The cards of the species page that can be edited in place (issue #4527,
/// phase 3), in page order. Cards that only show what is calculated or imported
/// have none: they never change.
///
/// A value's name is the card's id. It is stored in the History label of
/// every sitting that changed the card, so it must never be renamed.
enum SpeciesCardId { header, description, photos }

/// What each card of the species page is called.
extension SpeciesCardIdNames on SpeciesCardId {
  /// The card's title, also its name in History. A header block is named
  /// by its record's kind, as History names the record.
  String localizedDisplayName(AppLocalizations l) => switch (this) {
    SpeciesCardId.header => l.settings_conflict_ref_species,
    SpeciesCardId.description => l.marineLife_speciesDetail_descriptionTitle,
    SpeciesCardId.photos => l.marineLife_editCard_photos,
  };
}
