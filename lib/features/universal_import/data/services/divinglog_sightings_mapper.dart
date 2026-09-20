import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

/// Maps Diving Log's `Fish` and `FishRel` tables into dive sightings, and
/// its `Pictures` table into media entries.
///
/// Neither needs a new `ImportEntityType`. `UddfEntityImporter` builds a
/// `MarineSighting` from each entry of `dive['sightings']`, and the photo
/// pipeline the Subsurface and MacDive parsers feed takes media entries
/// whose `filename` is the path exactly as the source recorded it, resolved
/// later against a folder the user picks in the wizard's Photos step.
class DivingLogSightingsMapper {
  const DivingLogSightingsMapper._();

  /// The importer recovers the display name by stripping `species_`,
  /// splitting on underscores and title casing, so the ref has to be the
  /// name in that shape and nothing else.
  static String speciesRef(String commonName) {
    final slug = commonName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'species_$slug';
  }

  static List<Map<String, dynamic>> sightingsFor(
    DivingLogLogbook book,
    DivingLogRawDive dive,
  ) {
    final ids = book.speciesIdsByLogId[dive.id];
    if (ids == null || ids.isEmpty) return const [];
    final out = <Map<String, dynamic>>[];
    for (final id in ids) {
      final species = book.speciesById[id];
      final common = species?.commonName?.trim();
      if (common == null || common.isEmpty) continue;
      out.add(<String, dynamic>{
        'speciesRef': speciesRef(common),
        'count': 1,
        // The sighting record holds only a name, so the scientific name has
        // nowhere else to go and would otherwise be dropped.
        'notes': species!.scientificName ?? '',
      });
    }
    return out;
  }

  static List<Map<String, dynamic>> mediaFor(
    DivingLogLogbook book,
    DivingLogRawDive dive,
    int diveIndex,
  ) {
    final pictures = book.picturesByLogId[dive.id];
    if (pictures == null || pictures.isEmpty) return const [];
    return [
      for (final picture in pictures)
        if (picture.path case final String path when path.trim().isNotEmpty)
          <String, dynamic>{
            'filename': path,
            'caption': picture.description,
            '_diveIndex': diveIndex,
            'offsetSeconds': null,
            'latitude': null,
            'longitude': null,
          },
    ];
  }
}
