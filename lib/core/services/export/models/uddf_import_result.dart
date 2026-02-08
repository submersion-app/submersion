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
  final List<Map<String, dynamic>> diveComputers;
  final List<Map<String, dynamic>> equipmentSets;
  final List<Map<String, dynamic>> courses;

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
    this.diveComputers = const [],
    this.equipmentSets = const [],
    this.courses = const [],
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
    if (species.isNotEmpty) parts.add('${species.length} species');
    if (serviceRecords.isNotEmpty) {
      parts.add('${serviceRecords.length} service records');
    }
    if (courses.isNotEmpty) parts.add('${courses.length} courses');
    if (settings.isNotEmpty) parts.add('${settings.length} settings');
    return parts.isEmpty ? 'No data' : parts.join(', ');
  }
}
