/// Every table a query can root at or reach through a relation.
///
/// The first nine are list subjects (they get a query entry point on their
/// list page, PRs 1 to 4 of #2365). The rest are child tables reachable only
/// through a relation.
enum QuerySubject {
  dives,
  sites,
  equipment,
  trips,
  buddies,
  centers,
  certifications,
  courses,
  species,
  tags,
  diveTypes,
  computers,
  tanks,
  weights,
  customFields,
  sightings,
  media,
  equipmentAttributes,

  /// Site classification types (#1765), a relation target of sites.
  siteTypes,

  /// A dive's safety review findings (#2195), a relation target of dives.
  findings,
}
