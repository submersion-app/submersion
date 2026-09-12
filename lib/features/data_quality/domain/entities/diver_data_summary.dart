/// What one dive carries of the diver's own work: how many of each thing
/// they can add more than one of, and whether each of the single-valued ones
/// is set.
///
/// The same fourteen signals `DiveQualityContext.carriesDiverData` answers as
/// a bare boolean (#1720), counted rather than collapsed, so a confirmation
/// can say what a delete would take rather than only that it would take
/// something (#1729).
class DiverDataSummary {
  const DiverDataSummary({
    this.gear = 0,
    this.weights = 0,
    this.buddies = 0,
    this.tags = 0,
    this.sightings = 0,
    this.photosAndVideos = 0,
    this.attachments = 0,
    this.customFields = 0,
    this.hasNotes = false,
    this.hasRating = false,
    this.isFavorite = false,
    this.hasSite = false,
    this.hasTrip = false,
    this.hasDiveCenter = false,
    this.hasCourse = false,
  });

  /// Gear links, counting an assembly's parts alongside the assembly: each is
  /// a row the delete removes.
  final int gear;
  final int weights;
  final int buddies;
  final int tags;

  /// Marine life sightings.
  final int sightings;

  /// Photos and videos linked to the dive.
  final int photosAndVideos;

  /// Everything else in the dive's media: signatures, documents, maps.
  final int attachments;
  final int customFields;

  /// Notes with something other than whitespace in them.
  final bool hasNotes;
  final bool hasRating;
  final bool isFavorite;
  final bool hasSite;
  final bool hasTrip;
  final bool hasDiveCenter;
  final bool hasCourse;

  /// Whether the diver has left nothing of their own on the dive. True for a
  /// recording only a dive computer has ever touched.
  bool get isEmpty =>
      gear == 0 &&
      weights == 0 &&
      buddies == 0 &&
      tags == 0 &&
      sightings == 0 &&
      photosAndVideos == 0 &&
      attachments == 0 &&
      customFields == 0 &&
      !hasNotes &&
      !hasRating &&
      !isFavorite &&
      !hasSite &&
      !hasTrip &&
      !hasDiveCenter &&
      !hasCourse;
}
