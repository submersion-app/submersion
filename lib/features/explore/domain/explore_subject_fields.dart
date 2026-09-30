import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// The registry entity a subject's query roots at.
QuerySubject rootOf(ParsedSubject subject) => switch (subject) {
  ParsedSubject.dives => QuerySubject.dives,
  ParsedSubject.sites => QuerySubject.sites,
  ParsedSubject.equipment => QuerySubject.equipment,
  ParsedSubject.buddies => QuerySubject.buddies,
  ParsedSubject.species => QuerySubject.species,
  ParsedSubject.trips => QuerySubject.trips,
  ParsedSubject.centers => QuerySubject.centers,
};

ExploreField _diveCount(QuerySubject root) => ExploreField(
  'diveCount',
  const ['diveCount'],
  ExploreValueKind.number,
  labelKey: 'query_${root.name}_diveCount',
  root: root,
  wholeNumbers: true,
  strictCount: true,
  aggregate: true,
);

ExploreField _lastDived(QuerySubject root) => ExploreField(
  'lastDived',
  const ['lastDived'],
  ExploreValueKind.date,
  labelKey: 'query_${root.name}_lastDived',
  root: root,
  aggregate: true,
);

/// Each non-dive subject's own fields, in the prompt's order (phase 3).
/// A word that is also a dive field (depth, rating, favorite) means the
/// subject's own field under that subject.
final Map<ParsedSubject, List<ExploreField>> kExploreSubjectFields = {
  ParsedSubject.sites: [
    const ExploreField(
      'depth',
      ['maxDepth'],
      ExploreValueKind.number,
      labelKey: 'query_sites_maxDepth',
      root: QuerySubject.sites,
    ),
    const ExploreField(
      'rating',
      ['rating'],
      ExploreValueKind.number,
      labelKey: 'query_sites_rating',
      root: QuerySubject.sites,
      wholeNumbers: true,
    ),
    const ExploreField(
      'difficulty',
      ['difficulty'],
      ExploreValueKind.enumName,
      labelKey: 'query_sites_difficulty',
      root: QuerySubject.sites,
    ),
    _diveCount(QuerySubject.sites),
    _lastDived(QuerySubject.sites),
  ],
  ParsedSubject.equipment: [
    const ExploreField(
      'gearType',
      ['type'],
      ExploreValueKind.enumName,
      labelKey: 'query_equipment_type',
      root: QuerySubject.equipment,
    ),
    const ExploreField(
      'gearStatus',
      ['status'],
      ExploreValueKind.enumName,
      labelKey: 'query_equipment_status',
      root: QuerySubject.equipment,
    ),
    const ExploreField(
      'serviceDue',
      ['serviceDue'],
      ExploreValueKind.enumName,
      labelKey: 'query_equipment_serviceDue',
      root: QuerySubject.equipment,
    ),
    const ExploreField(
      'serviceDueWithin',
      ['nextServiceDue'],
      ExploreValueKind.days,
      labelKey: 'query_equipment_nextServiceDue',
      root: QuerySubject.equipment,
    ),
    _diveCount(QuerySubject.equipment),
    _lastDived(QuerySubject.equipment),
  ],
  ParsedSubject.buddies: [
    const ExploreField(
      'favorite',
      ['favorite'],
      ExploreValueKind.flag,
      labelKey: 'query_buddies_favorite',
      root: QuerySubject.buddies,
    ),
    _diveCount(QuerySubject.buddies),
    _lastDived(QuerySubject.buddies),
  ],
  ParsedSubject.species: [
    const ExploreField(
      'speciesCategory',
      ['category'],
      ExploreValueKind.enumName,
      labelKey: 'query_species_category',
      root: QuerySubject.species,
    ),
    _diveCount(QuerySubject.species),
    const ExploreField(
      'firstSeen',
      ['firstSeen'],
      ExploreValueKind.date,
      labelKey: 'query_species_firstSeen',
      root: QuerySubject.species,
      aggregate: true,
    ),
    const ExploreField(
      'lastSeen',
      ['lastSeen'],
      ExploreValueKind.date,
      labelKey: 'query_species_lastSeen',
      root: QuerySubject.species,
      aggregate: true,
    ),
  ],
  ParsedSubject.trips: [
    const ExploreField(
      'tripType',
      ['tripType'],
      ExploreValueKind.enumName,
      labelKey: 'query_trips_tripType',
      root: QuerySubject.trips,
    ),
    _diveCount(QuerySubject.trips),
  ],
  ParsedSubject.centers: [
    const ExploreField(
      'rating',
      ['rating'],
      ExploreValueKind.number,
      labelKey: 'query_centers_rating',
      root: QuerySubject.centers,
      wholeNumbers: true,
    ),
    _diveCount(QuerySubject.centers),
    _lastDived(QuerySubject.centers),
  ],
};

/// The field [name] means under [subject]: the subject's own field first,
/// else a dive field, which a non-dive subject reads through its dives.
/// Another subject's own word is unknown here.
({ExploreField field, bool viaDives})? exploreFieldFor(
  ParsedSubject subject,
  String name,
) {
  if (subject != ParsedSubject.dives) {
    for (final f in kExploreSubjectFields[subject]!) {
      if (f.name == name) return (field: f, viaDives: false);
    }
  }
  final dive = exploreField(name);
  if (dive == null) return null;
  return (field: dive, viaDives: subject != ParsedSubject.dives);
}

/// Every field word the model may write, dive fields first, each once.
List<String> exploreFieldNames() {
  final seen = <String>{};
  return [
    for (final f in kExploreFields)
      if (seen.add(f.name)) f.name,
    for (final list in kExploreSubjectFields.values)
      for (final f in list)
        if (seen.add(f.name)) f.name,
  ];
}
