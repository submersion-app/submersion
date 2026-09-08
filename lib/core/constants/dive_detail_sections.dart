import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';

/// Identifies each configurable section on the Dive Details page.
///
/// Declaration order defines the default display order. The header block is
/// the only fixed part of the page; every section below -- including the dive
/// profile chart -- can be hidden and reordered.
///
/// Sections that pair side by side on a wide pane are declared adjacently, in
/// left-then-right order (see `kDiveDetailSectionPairs`), so the default order
/// already reads the way the paired layout renders.
enum DiveDetailSectionId {
  profile,
  decoStatus,
  tissueLoading,
  safetyReview,
  sacSegments,
  details,
  environment,
  altitude,
  surfaceGps,
  tide,
  reefHealth,
  tanks,
  weights,
  buoyancy,
  buddies,
  signatures,
  equipment,
  sightings,
  media,
  tags,
  notes,
  customFields,
  dataSources;

  /// The pre-split id that carried both [decoStatus] and [tissueLoading].
  ///
  /// Saved orders written before the split still name it, so
  /// [DiveDetailSectionConfig.sectionsFromJson] expands it into the two
  /// sections that replaced it.
  static const String legacyDecoO2Id = 'decoO2';

  /// Human-readable name shown in the settings UI (English fallback).
  String get displayName {
    return switch (this) {
      profile => 'Dive Profile',
      decoStatus => 'Deco Status',
      tissueLoading => 'Tissue Loading',
      safetyReview => 'Safety Review',
      sacSegments => 'Gas consumption by segment',
      details => 'Details',
      environment => 'Environment',
      altitude => 'Altitude',
      tide => 'Tide',
      reefHealth => 'Water Conditions',
      surfaceGps => 'Surface GPS',
      weights => 'Weights',
      buoyancy => 'Buoyancy',
      tanks => 'Cylinders',
      buddies => 'Buddies',
      signatures => 'Signatures',
      equipment => 'Equipment',
      sightings => 'Species Sightings',
      media => 'Media',
      tags => 'Tags',
      notes => 'Notes',
      customFields => 'Custom Fields',
      dataSources => 'Data Sources',
    };
  }

  /// Short description shown below the name in the settings UI
  /// (English fallback).
  String get description {
    return switch (this) {
      profile => 'Depth/time chart, playback, range selection',
      decoStatus => 'NDL, ceiling, stops, O2 toxicity',
      tissueLoading => 'Per-compartment saturation and heat map',
      safetyReview => 'Automatic post-dive profile observations',
      sacSegments => 'SAC and RMV by phase or time',
      details => 'Type, location, trip, dive center, interval',
      environment => 'Air/water temp, visibility, current',
      altitude => 'Altitude value, category, deco requirement',
      tide => 'Tide cycle graph and timing',
      reefHealth => 'Satellite water conditions on the dive date',
      surfaceGps => 'GPS entry/exit points and surface drift',
      weights => 'Weight breakdown, total weight',
      buoyancy => 'Buoyancy through the dive, swing, ditchable weight',
      tanks =>
        'Cylinder list, gas mixes, pressures, MOD/MND, per-tank consumption',
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

  /// Icon standing in for the section in the properties menu and, in the list
  /// layout, on the section's folded header row.
  IconData get icon {
    return switch (this) {
      profile => Icons.show_chart,
      decoStatus => Icons.timer_outlined,
      tissueLoading => Icons.grid_view,
      safetyReview => Icons.health_and_safety_outlined,
      sacSegments => Icons.speed,
      details => Icons.info_outline,
      environment => Icons.thermostat,
      altitude => Icons.terrain,
      tide => Icons.waves,
      reefHealth => Icons.water,
      surfaceGps => Icons.gps_fixed,
      weights => Icons.fitness_center,
      buoyancy => Icons.bubble_chart_outlined,
      tanks => Icons.propane_tank_outlined,
      buddies => Icons.group_outlined,
      signatures => Icons.draw_outlined,
      equipment => Icons.backpack_outlined,
      sightings => Icons.pets,
      media => Icons.photo_library_outlined,
      tags => Icons.label_outline,
      notes => Icons.notes,
      customFields => Icons.tune,
      dataSources => Icons.watch_outlined,
    };
  }

  /// Localized display name resolved via [AppLocalizations].
  String localizedDisplayName(AppLocalizations l10n) {
    return switch (this) {
      profile => l10n.diveDetailSection_profile_name,
      decoStatus => l10n.diveDetailSection_decoStatus_name,
      tissueLoading => l10n.diveDetailSection_tissueLoading_name,
      safetyReview => l10n.diveDetailSection_safetyReview_name,
      sacSegments => l10n.diveDetailSection_sacSegments_name,
      details => l10n.diveDetailSection_details_name,
      environment => l10n.diveDetailSection_environment_name,
      altitude => l10n.diveDetailSection_altitude_name,
      tide => l10n.diveDetailSection_tide_name,
      reefHealth => l10n.diveDetailSection_reefHealth_name,
      surfaceGps => l10n.diveDetailSection_surfaceGps_name,
      weights => l10n.diveDetailSection_weights_name,
      buoyancy => l10n.diveDetailSection_buoyancy_name,
      tanks => l10n.diveDetailSection_tanks_name,
      buddies => l10n.diveDetailSection_buddies_name,
      signatures => l10n.diveDetailSection_signatures_name,
      equipment => l10n.diveDetailSection_equipment_name,
      sightings => l10n.diveDetailSection_sightings_name,
      media => l10n.diveDetailSection_media_name,
      tags => l10n.diveDetailSection_tags_name,
      notes => l10n.diveDetailSection_notes_name,
      customFields => l10n.diveDetailSection_customFields_name,
      dataSources => l10n.diveDetailSection_dataSources_name,
    };
  }

  /// Localized description resolved via [AppLocalizations].
  String localizedDescription(AppLocalizations l10n) {
    return switch (this) {
      profile => l10n.diveDetailSection_profile_description,
      decoStatus => l10n.diveDetailSection_decoStatus_description,
      tissueLoading => l10n.diveDetailSection_tissueLoading_description,
      safetyReview => l10n.diveDetailSection_safetyReview_description,
      sacSegments => l10n.diveDetailSection_sacSegments_description,
      details => l10n.diveDetailSection_details_description,
      environment => l10n.diveDetailSection_environment_description,
      altitude => l10n.diveDetailSection_altitude_description,
      tide => l10n.diveDetailSection_tide_description,
      reefHealth => l10n.diveDetailSection_reefHealth_description,
      surfaceGps => l10n.diveDetailSection_surfaceGps_description,
      weights => l10n.diveDetailSection_weights_description,
      buoyancy => l10n.diveDetailSection_buoyancy_description,
      tanks => l10n.diveDetailSection_tanks_description,
      buddies => l10n.diveDetailSection_buddies_description,
      signatures => l10n.diveDetailSection_signatures_description,
      equipment => l10n.diveDetailSection_equipment_description,
      sightings => l10n.diveDetailSection_sightings_description,
      media => l10n.diveDetailSection_media_description,
      tags => l10n.diveDetailSection_tags_description,
      notes => l10n.diveDetailSection_notes_description,
      customFields => l10n.diveDetailSection_customFields_description,
      dataSources => l10n.diveDetailSection_dataSources_description,
    };
  }

  /// Whether this section is hidden for gauge (bottom-timer) dives, which log
  /// depth and time only -- no gas, decompression, or O2-toxicity data.
  ///
  /// The profile chart itself stays: depth over time is exactly what a gauge
  /// dive does record.
  bool get hiddenInGaugeMode =>
      this == DiveDetailSectionId.decoStatus ||
      this == DiveDetailSectionId.tissueLoading ||
      this == DiveDetailSectionId.sacSegments ||
      this == DiveDetailSectionId.tanks;
}

/// Visibility and ordering configuration for a single dive detail section.
class DiveDetailSectionConfig {
  final DiveDetailSectionId id;
  final bool visible;

  /// Whether the list layout shows this section unfolded.
  ///
  /// Only the list layout folds sections, so this is ignored elsewhere. It
  /// lives here rather than in page state so a dive reopens the way the
  /// diver left it.
  final bool expanded;

  const DiveDetailSectionConfig({
    required this.id,
    required this.visible,
    this.expanded = false,
  });

  DiveDetailSectionConfig copyWith({bool? visible, bool? expanded}) {
    return DiveDetailSectionConfig(
      id: id,
      visible: visible ?? this.visible,
      expanded: expanded ?? this.expanded,
    );
  }

  /// Folded is the default, so the flag is written only when set: an order
  /// saved by a diver who never unfolds anything stays byte-identical, and
  /// syncs no changeset it would otherwise have to carry.
  Map<String, dynamic> toJson() => {
    'id': id.name,
    'visible': visible,
    if (expanded) 'expanded': true,
  };

  factory DiveDetailSectionConfig.fromJson(Map<String, dynamic> json) {
    final idStr = json['id'] as String;
    final id = DiveDetailSectionId.values.firstWhere((e) => e.name == idStr);
    return DiveDetailSectionConfig(
      id: id,
      visible: json['visible'] as bool? ?? true,
      expanded: json['expanded'] as bool? ?? false,
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
    DiveDetailSectionConfig(id: DiveDetailSectionId.profile, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.decoStatus, visible: true),
    DiveDetailSectionConfig(
      id: DiveDetailSectionId.tissueLoading,
      visible: true,
    ),
    DiveDetailSectionConfig(
      id: DiveDetailSectionId.safetyReview,
      visible: true,
    ),
    DiveDetailSectionConfig(id: DiveDetailSectionId.sacSegments, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.details, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.environment, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.altitude, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.surfaceGps, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.tide, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.reefHealth, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.tanks, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.weights, visible: true),
    DiveDetailSectionConfig(id: DiveDetailSectionId.buoyancy, visible: true),
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

  /// [sections] reordered as if [rendered] had its [oldIndex] entry dropped
  /// at [newIndex].
  ///
  /// The dive page renders only the sections that are visible and have
  /// content, so a drop index in that subset is not an index into the saved
  /// list. The moved section is re-anchored next to the rendered neighbour it
  /// was dropped against, which leaves every section outside [rendered] --
  /// hidden ones included -- where the diver left it.
  ///
  /// Indices follow [ReorderableListView.onReorderItem]: [newIndex] is the
  /// final resting index, already adjusted for the removal.
  static List<DiveDetailSectionConfig> moveRenderedSection(
    List<DiveDetailSectionConfig> sections,
    List<DiveDetailSectionId> rendered,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex == newIndex ||
        rendered.length < 2 ||
        oldIndex < 0 ||
        oldIndex >= rendered.length ||
        newIndex < 0 ||
        newIndex >= rendered.length) {
      return sections;
    }

    final movedId = rendered[oldIndex];
    final movedAt = sections.indexWhere((s) => s.id == movedId);
    if (movedAt < 0) return sections;
    final config = sections[movedAt];

    final reordered = List.of(rendered)..removeAt(oldIndex);
    reordered.insert(newIndex, movedId);

    final result = List.of(sections)..removeWhere((s) => s.id == movedId);

    // Anchor on the rendered section that now follows the moved one, so it
    // lands immediately before it; at the end of the list, anchor on the one
    // it now follows instead.
    final followingId = newIndex + 1 < reordered.length
        ? reordered[newIndex + 1]
        : null;
    if (followingId != null) {
      final at = result.indexWhere((s) => s.id == followingId);
      if (at >= 0) {
        result.insert(at, config);
        return result;
      }
    }
    final precedingId = newIndex > 0 ? reordered[newIndex - 1] : null;
    if (precedingId != null) {
      final at = result.indexWhere((s) => s.id == precedingId);
      if (at >= 0) {
        result.insert(at + 1, config);
        return result;
      }
    }
    result.insert(0, config);
    return result;
  }

  static String sectionsToJson(List<DiveDetailSectionConfig> sections) {
    return jsonEncode(sections.map((s) => s.toJson()).toList());
  }

  static List<DiveDetailSectionConfig> sectionsFromJson(String? json) {
    if (json == null || json.isEmpty) return List.of(defaultSections);
    try {
      final decoded = jsonDecode(json) as List;
      final sections = decoded
          .whereType<Map<String, dynamic>>()
          .expand(_configsForEntry)
          .toList();
      if (sections.isEmpty) return List.of(defaultSections);
      return ensureAllSections(sections);
    } catch (_) {
      return List.of(defaultSections);
    }
  }

  /// The configs one saved JSON entry stands for.
  ///
  /// One entry normally means one section. The retired `decoO2` id is the
  /// exception: it covered the deco/tissue panel as a whole, so it expands
  /// into both sections that replaced it, each inheriting the visibility and
  /// fold state the diver had chosen for the combined panel.
  static Iterable<DiveDetailSectionConfig> _configsForEntry(
    Map<String, dynamic> json,
  ) {
    if (json['id'] == DiveDetailSectionId.legacyDecoO2Id) {
      final visible = json['visible'] as bool? ?? true;
      final expanded = json['expanded'] as bool? ?? false;
      return [
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.decoStatus,
          visible: visible,
          expanded: expanded,
        ),
        DiveDetailSectionConfig(
          id: DiveDetailSectionId.tissueLoading,
          visible: visible,
          expanded: expanded,
        ),
      ];
    }
    final config = tryFromJson(json);
    return config == null ? const [] : [config];
  }

  /// [sections] with every missing section added, visible, at the place the
  /// default order puts it.
  ///
  /// A section added in a later release must not land at the bottom of an
  /// order saved before it existed -- the dive profile chart, appended, would
  /// follow the Data Sources card. Each missing id is instead inserted just
  /// after its nearest preceding sibling in the default order, or at the top
  /// when none of them is present.
  static List<DiveDetailSectionConfig> ensureAllSections(
    List<DiveDetailSectionConfig> sections,
  ) {
    final presentIds = sections.map((s) => s.id).toSet();
    if (presentIds.length == DiveDetailSectionId.values.length) {
      return sections;
    }

    final result = List.of(sections);
    for (final id in DiveDetailSectionId.values) {
      if (presentIds.contains(id)) continue;
      result.insert(
        _insertionIndex(result, id),
        DiveDetailSectionConfig(id: id, visible: true),
      );
      presentIds.add(id);
    }
    return result;
  }

  /// Where [id] belongs in [sections], by default-order adjacency.
  static int _insertionIndex(
    List<DiveDetailSectionConfig> sections,
    DiveDetailSectionId id,
  ) {
    final defaultIndex = DiveDetailSectionId.values.indexOf(id);
    for (var i = defaultIndex - 1; i >= 0; i--) {
      final position = sections.indexWhere(
        (s) => s.id == DiveDetailSectionId.values[i],
      );
      if (position >= 0) return position + 1;
    }
    return 0;
  }
}
