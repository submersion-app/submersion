/// Result class for comprehensive UDDF import.
///
/// Contains all parsed entities from a UDDF file, organized by type.
/// Each entity is represented as a `Map<String, dynamic>` for flexibility
/// during the import pipeline before conversion to domain entities.
class UddfImportResult {
  final List<Map<String, dynamic>> dives;
  final List<Map<String, dynamic>> sites;
  final List<Map<String, dynamic>> equipment;
  final List<Map<String, dynamic>> buddies;
  final List<Map<String, dynamic>> certifications;
  final List<Map<String, dynamic>> diveCenters;
  final List<Map<String, dynamic>> species;
  final List<Map<String, dynamic>> sightings;
  final List<Map<String, dynamic>> serviceRecords;
  final Map<String, String> settings;
  final Map<String, dynamic>? owner;
  final List<Map<String, dynamic>> trips;
  final List<Map<String, dynamic>> tags;
  final List<Map<String, dynamic>> customDiveTypes;
  final List<Map<String, dynamic>> customDiveRoles;

  /// Custom site type definitions (`id`, `name`, `sortOrder`), issue #1765.
  final List<Map<String, dynamic>> customSiteTypes;
  final List<Map<String, dynamic>> diveComputers;
  final List<Map<String, dynamic>> equipmentSets;
  final List<Map<String, dynamic>> courses;

  /// The original filename of the imported file (e.g. "my_dives.uddf").
  ///
  /// Set by the caller after parsing so that downstream consumers (such as
  /// [UddfEntityImporter]) can record it on [DiveDataSource] records.
  final String? sourceFileName;

  /// Per-source provenance records, keyed by the `<source diveref>` value
  /// (for example `dive_7f3a...`), each list sorted by ordinal.
  ///
  /// Carries every `dive_data_sources` column the exporter wrote, plus
  /// `rawData` where a `<divecomputerdump>` paired with the entry. Empty for
  /// any file that was not written by Submersion with raw data enabled.
  final Map<String, List<Map<String, dynamic>>> dataSourcesByDiveRef;

  /// Dumps that could not be attached to a source record: no resolvable dive
  /// link, an unreadable payload, or a payload over the size ceiling.
  ///
  /// Counted rather than thrown, because one bad dump in someone else's file
  /// must not cost the user the rest of the import.
  final int unpairedDumps;

  const UddfImportResult({
    this.dives = const [],
    this.sites = const [],
    this.equipment = const [],
    this.buddies = const [],
    this.certifications = const [],
    this.diveCenters = const [],
    this.species = const [],
    this.sightings = const [],
    this.serviceRecords = const [],
    this.settings = const {},
    this.owner,
    this.trips = const [],
    this.tags = const [],
    this.customDiveTypes = const [],
    this.customDiveRoles = const [],
    this.customSiteTypes = const [],
    this.diveComputers = const [],
    this.equipmentSets = const [],
    this.courses = const [],
    this.sourceFileName,
    this.dataSourcesByDiveRef = const {},
    this.unpairedDumps = 0,
  });

  /// Check if any data was imported
  bool get isEmpty =>
      dives.isEmpty &&
      sites.isEmpty &&
      equipment.isEmpty &&
      buddies.isEmpty &&
      certifications.isEmpty &&
      diveCenters.isEmpty &&
      species.isEmpty &&
      serviceRecords.isEmpty &&
      settings.isEmpty &&
      owner == null &&
      trips.isEmpty &&
      tags.isEmpty &&
      customDiveTypes.isEmpty &&
      customDiveRoles.isEmpty &&
      customSiteTypes.isEmpty &&
      diveComputers.isEmpty &&
      equipmentSets.isEmpty &&
      courses.isEmpty;

  /// Get total count of all items
  int get totalItems =>
      dives.length +
      sites.length +
      equipment.length +
      buddies.length +
      certifications.length +
      diveCenters.length +
      species.length +
      serviceRecords.length +
      settings.length +
      (owner != null ? 1 : 0) +
      trips.length +
      tags.length +
      customDiveTypes.length +
      customDiveRoles.length +
      diveComputers.length +
      equipmentSets.length +
      courses.length;

  /// Summary string for display
  String get summary {
    final parts = <String>[];
    if (owner != null) parts.add('1 diver profile');
    if (dives.isNotEmpty) parts.add('${dives.length} dives');
    if (sites.isNotEmpty) parts.add('${sites.length} sites');
    if (trips.isNotEmpty) parts.add('${trips.length} trips');
    if (equipment.isNotEmpty) parts.add('${equipment.length} equipment');
    if (equipmentSets.isNotEmpty) {
      parts.add('${equipmentSets.length} equipment sets');
    }
    if (buddies.isNotEmpty) parts.add('${buddies.length} buddies');
    if (certifications.isNotEmpty) {
      parts.add('${certifications.length} certifications');
    }
    if (diveCenters.isNotEmpty) parts.add('${diveCenters.length} dive centers');
    if (diveComputers.isNotEmpty) {
      parts.add('${diveComputers.length} dive computers');
    }
    if (tags.isNotEmpty) parts.add('${tags.length} tags');
    if (customDiveTypes.isNotEmpty) {
      parts.add('${customDiveTypes.length} custom dive types');
    }
    if (customDiveRoles.isNotEmpty) {
      parts.add('${customDiveRoles.length} custom dive roles');
    }
    if (species.isNotEmpty) parts.add('${species.length} species');
    if (serviceRecords.isNotEmpty) {
      parts.add('${serviceRecords.length} service records');
    }
    if (courses.isNotEmpty) parts.add('${courses.length} courses');
    if (settings.isNotEmpty) parts.add('${settings.length} settings');
    return parts.isEmpty ? 'No data' : parts.join(', ');
  }

  /// The entries in [byDiveRef] belonging to the dive whose `<dive id>` the
  /// parser kept as [diveRef] (its `sourceUuid`).
  ///
  /// Submersion's own export writes `<dive id="dive_<uuid>">` and the parser
  /// keeps that attribute verbatim, so the ref is already prefixed. A file
  /// whose dive ids are bare needs the prefix added. Both shapes are tried
  /// rather than assuming either, and in one place, so the parser attaching
  /// entries to a dive and the importer reading them cannot resolve a dive
  /// differently.
  static List<Map<String, dynamic>> sourcesForDive(
    Map<String, List<Map<String, dynamic>>> byDiveRef,
    String? diveRef,
  ) {
    if (diveRef == null) return const [];
    return byDiveRef[diveRef] ?? byDiveRef['dive_$diveRef'] ?? const [];
  }

  /// Returns a copy with [sourceFileName] replaced.
  UddfImportResult copyWithSourceFileName(String? sourceFileName) {
    return UddfImportResult(
      dives: dives,
      sites: sites,
      equipment: equipment,
      buddies: buddies,
      certifications: certifications,
      diveCenters: diveCenters,
      species: species,
      sightings: sightings,
      serviceRecords: serviceRecords,
      settings: settings,
      owner: owner,
      trips: trips,
      tags: tags,
      customDiveTypes: customDiveTypes,
      customDiveRoles: customDiveRoles,
      customSiteTypes: customSiteTypes,
      diveComputers: diveComputers,
      equipmentSets: equipmentSets,
      courses: courses,
      sourceFileName: sourceFileName,
      dataSourcesByDiveRef: dataSourcesByDiveRef,
      unpairedDumps: unpairedDumps,
    );
  }
}
