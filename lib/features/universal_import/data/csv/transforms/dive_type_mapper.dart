import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';

/// The ids of the built-in dive types, mirroring `kSeedBuiltInDiveTypesSql`
/// in lib/core/database/database.dart.
///
/// The seed is raw SQL, so this list cannot be derived from it the way
/// `kBuiltInSiteTypeIds` derives from `kBuiltInSiteTypes`. A test asserts the
/// two agree, so a new built-in added to the seed fails the build rather than
/// silently leaving this set short.
const Set<String> kBuiltInDiveTypeIds = {
  'recreational',
  'technical',
  'freedive',
  'training',
  'wreck',
  'cave',
  'ice',
  'night',
  'drift',
  'deep',
  'altitude',
  'shore',
  'boat',
  'liveaboard',
  'cavern',
};

/// Values that name a dive mode or a recording mode rather than a dive type.
///
/// Compared against the whole trimmed, lower-cased cell, never as a
/// substring. See the note in [mapDiveType] for why these exist.
const Set<String> kNonDiveTypeModes = {
  'oc',
  'open circuit',
  'ccr',
  'pscr',
  'scr',
  'closed circuit',
  'gauge',
  'gauge dive',
  'single-gas dive',
  'multi-gas dive',
};

final RegExp _minesOrSumps = RegExp(r'\b(mines?|sumps?)\b');
final RegExp _technical = RegExp(r'\btec');
final RegExp _fun = RegExp(r'\bfun\b');

/// Maps a free-text dive type string to a dive type id (issue #2203).
///
/// Shared by every importer that reads a single free-text dive type cell:
/// `ValueConverter.parseDiveType`, `ValueTransformService.parseDiveType` and
/// `UddfFullImportService._parseDiveType`. The three used to carry their own
/// copy of this ladder and had drifted apart, so a term one recognised
/// another did not.
///
/// A value that matches no keyword is preserved as its slug rather than
/// collapsed to 'recreational'. Collapsing it recorded an overhead dive as a
/// recreational one and gave the diver no warning, which is the bug this
/// function exists to prevent: "Cenote" and "Sidemount" now survive import as
/// themselves. `DiveTypeExtractor` turns the preserved slug into a real
/// custom dive type, so the id is never left dangling.
///
/// Only a null, blank, or punctuation-only cell yields 'recreational'; a slug
/// of nothing is not a usable id.
///
/// ## Ordering
///
/// The ladder is substring matching, so a keyword containing another must be
/// tested first. Three orderings are load-bearing and have regression tests:
///
/// - `cavern` before `cave`, since "cavern" contains "cave". Reversing them
///   misclassifies every cavern dive as a cave dive.
/// - `wreck` before the recreational synonyms, since "wreck" contains "rec".
/// - `open water diver` before the recreational synonyms, since it contains
///   "open water", which those claim.
///
/// ## Terms deliberately not mapped
///
/// `overhead` is the category containing cave, cavern, ice and wreck
/// penetration, so no single member is a correct target. `penetration` is
/// ambiguous between wreck and cave ("wreck penetration" already matches
/// `wreck`). `cenote` and `spring` are site types, not dive types (see
/// lib/core/database/site_type_seed.dart). `sidemount` is a cylinder
/// configuration: a sidemount dive can be a 12m reef dive. All five are
/// preserved verbatim instead of being guessed at.
String mapDiveType(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'recreational';
  final s = raw.trim().toLowerCase();

  // "Open Water Diver" is the entry-level certification, so a dive logged
  // under that name is a training dive, as is "Advanced Open Water Diver".
  // Tested here rather than with the recreational synonyms below, which
  // still claim a bare "Open water": that is how many logbooks say "an
  // ordinary dive in open water" rather than naming a course.
  if (s.contains('training') ||
      s.contains('student') ||
      s.contains('course') ||
      s.contains('open water diver')) {
    return 'training';
  }
  if (s.contains('night')) return 'night';
  if (s.contains('deep')) return 'deep';
  // Before the recreational synonyms: "wreck" contains "rec".
  if (s.contains('wreck')) return 'wreck';
  if (s.contains('drift')) return 'drift';
  // Before 'cave': "cavern" contains "cave".
  if (s.contains('cavern')) return 'cavern';
  // A sump is a flooded cave passage and a flooded mine is dived under the
  // same overhead rules, so both are cave dives.
  //
  // Matched as words: "mine" also sits inside "mineral" and "examine", and
  // "sump" inside "consumption". A mineral spring is open water, so claiming
  // it as a cave dive would be the over-claiming this mapper exists to stop.
  if (s.contains('cave') || _minesOrSumps.hasMatch(s)) {
    return 'cave';
  }
  // Anchored to a word start so it still covers "tec", "tech",
  // "technical" and "tecrec" without claiming "protected" or
  // "detected", which a bare contains('tec') did.
  if (_technical.hasMatch(s)) return 'technical';
  // The stems cover "freedive", "freediving", "free dive", "free diving" and
  // the hyphenated forms; the bare "free" two of the merged ladders used also
  // matched "freeflow".
  if (s.contains('freediv') ||
      s.contains('free div') ||
      s.contains('free-div') ||
      s.contains('apnea')) {
    return 'freedive';
  }
  if (s.contains('ice')) return 'ice';
  if (s.contains('altitude')) return 'altitude';
  if (s.contains('shore') || s.contains('beach')) return 'shore';
  if (s.contains('boat')) return 'boat';
  if (s.contains('liveaboard')) return 'liveaboard';
  // Last, so a keyword containing "rec" has already been taken.
  if (s.contains('recreational') ||
      // As a word: "fun" also sits inside "Fundamentals", which is a course.
      _fun.hasMatch(s) ||
      s.contains('vacation') ||
      s.contains('pleasure') ||
      s.contains('leisure') ||
      s.contains('open water')) {
    return 'recreational';
  }

  // Two built-in presets point this field at a column that is not a dive
  // type: Subsurface maps its `mode` column and Garmin its `Activity Type`.
  // Those describe the breathing loop or the recording mode, not the
  // environment, so preserving them would give every Subsurface import a
  // custom dive type called "Oc". Matched whole, since "oc" sits inside
  // "ocean" and "scr" inside "pscr".
  if (kNonDiveTypeModes.contains(s)) return 'recreational';

  final slug = DiveTypeEntity.generateSlug(s);
  return slug.isEmpty ? 'recreational' : slug;
}
