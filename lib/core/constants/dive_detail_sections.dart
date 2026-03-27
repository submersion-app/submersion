import 'dart:convert';

/// Identifies each configurable section on the Dive Details page.
///
/// Declaration order defines the default display order. The two fixed sections
/// (Header and Dive Profile Chart) are not included — they always render first.
enum DiveDetailSectionId {
  decoO2,
  sacSegments,
  details,
  environment,
  altitude,
  tide,
  weights,
  tanks,
  buddies,
  signatures,
  equipment,
  sightings,
  media,
  tags,
  notes,
  customFields,
  dataSources;

  /// Human-readable name shown in the settings UI.
  String get displayName {
    return switch (this) {
      decoO2 => 'Deco Status / Tissue Loading',
      sacSegments => 'SAC Rate by Segment',
      details => 'Details',
      environment => 'Environment',
      altitude => 'Altitude',
      tide => 'Tide',
      weights => 'Weights',
      tanks => 'Tanks',
      buddies => 'Buddies',
      signatures => 'Signatures',
      equipment => 'Equipment',
      sightings => 'Marine Life Sightings',
      media => 'Media',
      tags => 'Tags',
      notes => 'Notes',
      customFields => 'Custom Fields',
      dataSources => 'Data Sources',
    };
  }

  /// Short description shown below the name in the settings UI.
  String get description {
    return switch (this) {
      decoO2 => 'NDL, ceiling, tissue heat map, O2 toxicity',
      sacSegments => 'Phase/time segmentation, cylinder breakdown',
      details => 'Type, location, trip, dive center, interval',
      environment => 'Air/water temp, visibility, current',
      altitude => 'Altitude value, category, deco requirement',
      tide => 'Tide cycle graph and timing',
      weights => 'Weight breakdown, total weight',
      tanks => 'Tank list, gas mixes, pressures, per-tank SAC',
      buddies => 'Buddy list with roles',
      signatures => 'Buddy/instructor signature display and capture',
      equipment => 'Equipment used in dive',
      sightings => 'Species spotted, sighting details',
      media => 'Photos/videos gallery',
      tags => 'Dive tags',
      notes => 'Dive notes/description',
      customFields => 'User-defined custom fields',
      dataSources => 'Connected dive computers, source management',
    };
  }
}

/// Visibility and ordering configuration for a single dive detail section.
class DiveDetailSectionConfig {
  final DiveDetailSectionId id;
  final bool visible;

  const DiveDetailSectionConfig({required this.id, required this.visible});

  DiveDetailSectionConfig copyWith({bool? visible}) {
    return DiveDetailSectionConfig(id: id, visible: visible ?? this.visible);
  }

  Map<String, dynamic> toJson() => {'id': id.name, 'visible': visible};

  factory DiveDetailSectionConfig.fromJson(Map<String, dynamic> json) {
    final idStr = json['id'] as String;
    final id = DiveDetailSectionId.values.firstWhere((e) => e.name == idStr);
    return DiveDetailSectionConfig(
      id: id,
      visible: json['visible'] as bool? ?? true,
    );
  }

  static DiveDetailSectionConfig? tryFromJson(Map<String, dynamic> json) {
    try {
      return DiveDetailSectionConfig.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static const List<DiveDetailSectionConfig> defaultSections = [
    DiveDetailSectionConfig(id: DiveDetailSectionId.decoO2, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.sacSegments, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.details, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.environment, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.altitude, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.tide, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.weights, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.tanks, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.buddies, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.signatures, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.equipment, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.sightings, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.media, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.tags, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.notes, visible: true),
    DiveDetailSectionConfig(
      id: DiveDetailSectionId.customFields,
      visible: true,
    ),
    DiveDetailSectionConfig(id: DiveDetailSectionId.dataSources, visible: true),
  ];

  static String sectionsToJson(List<DiveDetailSectionConfig> sections) {
    return jsonEncode(sections.map((s) => s.toJson()).toList());
  }

  static List<DiveDetailSectionConfig> sectionsFromJson(String? json) {
    if (json == null || json.isEmpty) return List.of(defaultSections);
    try {
      final decoded = jsonDecode(json) as List;
      final sections = decoded
          .map((e) => tryFromJson(e as Map<String, dynamic>))
          .whereType<DiveDetailSectionConfig>()
          .toList();
      if (sections.isEmpty) return List.of(defaultSections);
      return ensureAllSections(sections);
    } catch (_) {
      return List.of(defaultSections);
    }
  }

  static List<DiveDetailSectionConfig> ensureAllSections(
    List<DiveDetailSectionConfig> sections,
  ) {
    final presentIds = sections.map((s) => s.id).toSet();
    final missing = DiveDetailSectionId.values
        .where((id) => !presentIds.contains(id))
        .map((id) => DiveDetailSectionConfig(id: id, visible: true));
    if (missing.isEmpty) return sections;
    return [...sections, ...missing];
  }
}
