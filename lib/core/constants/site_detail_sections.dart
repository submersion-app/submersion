import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/detail_section_order.dart'
    as section_order;
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Identifies each configurable card on the Site Details page.
///
/// Declaration order is the default display order: the order the page had
/// before it became configurable. The map card and the name header above
/// these cards are pinned, so neither appears here; everything below them
/// is the diver's to arrange.
///
/// The two pairs in `kSiteDetailSectionPairs` are declared adjacently, in
/// left-then-right order, so the default order already reads the way the
/// paired layout renders.
enum SiteDetailSectionId {
  diveStatistics,
  description,
  location,
  depth,
  altitude,
  features,
  tide,
  reefHealth,
  marineLife,
  media,
  tags,
  difficulty,
  rating,
  hazards,
  access,
  notes;

  /// Icon standing in for the card in the display-options menu and, in the
  /// list layout, on the card's folded header row.
  IconData get icon {
    return switch (this) {
      diveStatistics => Icons.scuba_diving,
      description => Icons.description_outlined,
      location => Icons.public,
      depth => Icons.vertical_align_bottom,
      altitude => Icons.terrain,
      features => Icons.place_outlined,
      tide => Icons.waves,
      reefHealth => Icons.water_outlined,
      marineLife => Icons.pets,
      media => Icons.photo_library_outlined,
      tags => Icons.label_outline,
      difficulty => Icons.pool,
      rating => Icons.star_outline,
      hazards => Icons.warning_amber,
      access => Icons.directions,
      notes => Icons.notes,
    };
  }

  /// The title the card itself shows, so the menu and the page agree.
  String localizedDisplayName(AppLocalizations l10n) {
    return switch (this) {
      diveStatistics => l10n.diveSites_detail_section_divesAtSite,
      description => l10n.diveSites_detail_section_description,
      location => l10n.diveSites_detail_section_location,
      depth => l10n.diveSites_detail_section_depthRange,
      altitude => l10n.diveSites_detail_section_altitude,
      features => l10n.siteFeature_sectionTitle,
      tide => l10n.tides_title,
      reefHealth => l10n.reef_section_title,
      marineLife => l10n.marineLife_siteSection_title,
      media => l10n.media_siteMediaSection_title,
      tags => l10n.diveLog_detail_section_tags,
      difficulty => l10n.diveSites_detail_section_difficultyLevel,
      rating => l10n.diveSites_detail_section_rating,
      hazards => l10n.diveSites_detail_section_hazards,
      access => l10n.diveSites_detail_section_access,
      notes => l10n.diveSites_detail_section_notes,
    };
  }

  /// One-line description shown below the name on the settings page.
  String localizedDescription(AppLocalizations l10n) {
    return switch (this) {
      diveStatistics => l10n.siteDetailSection_diveStatistics_description,
      description => l10n.siteDetailSection_description_description,
      location => l10n.siteDetailSection_location_description,
      depth => l10n.siteDetailSection_depth_description,
      altitude => l10n.siteDetailSection_altitude_description,
      features => l10n.siteDetailSection_features_description,
      tide => l10n.siteDetailSection_tide_description,
      reefHealth => l10n.siteDetailSection_reefHealth_description,
      marineLife => l10n.siteDetailSection_marineLife_description,
      media => l10n.siteDetailSection_media_description,
      tags => l10n.siteDetailSection_tags_description,
      difficulty => l10n.siteDetailSection_difficulty_description,
      rating => l10n.siteDetailSection_rating_description,
      hazards => l10n.siteDetailSection_hazards_description,
      access => l10n.siteDetailSection_access_description,
      notes => l10n.siteDetailSection_notes_description,
    };
  }
}

/// Visibility, order and fold state for one Site Details card.
///
/// Stored as a JSON list in `diver_settings.site_detail_sections`, in the
/// same shape as the Dive Details list.
class SiteDetailSectionConfig {
  final SiteDetailSectionId id;
  final bool visible;

  /// Whether the list layout shows this card unfolded. Ignored by the
  /// detailed layout. Kept here rather than in page state so a site reopens
  /// the way the diver left it.
  final bool expanded;

  const SiteDetailSectionConfig({
    required this.id,
    required this.visible,
    this.expanded = false,
  });

  SiteDetailSectionConfig copyWith({bool? visible, bool? expanded}) {
    return SiteDetailSectionConfig(
      id: id,
      visible: visible ?? this.visible,
      expanded: expanded ?? this.expanded,
    );
  }

  /// Folded is the default, so the flag is written only when set: a diver
  /// who never unfolds anything stores, and syncs, no fold state at all.
  Map<String, dynamic> toJson() => {
    'id': id.name,
    'visible': visible,
    if (expanded) 'expanded': true,
  };

  factory SiteDetailSectionConfig.fromJson(Map<String, dynamic> json) {
    final idStr = json['id'] as String;
    final id = SiteDetailSectionId.values.firstWhere((e) => e.name == idStr);
    return SiteDetailSectionConfig(
      id: id,
      visible: json['visible'] as bool? ?? true,
      expanded: json['expanded'] as bool? ?? false,
    );
  }

  static SiteDetailSectionConfig? tryFromJson(Map<String, dynamic> json) {
    try {
      return SiteDetailSectionConfig.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static const List<SiteDetailSectionConfig> defaultSections = [
    SiteDetailSectionConfig(
      id: SiteDetailSectionId.diveStatistics,
      visible: true,
    ),
    SiteDetailSectionConfig(id: SiteDetailSectionId.description, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.location, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.depth, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.altitude, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.features, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.tide, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.reefHealth, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.marineLife, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.media, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.tags, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.difficulty, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.rating, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.hazards, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.access, visible: true),
    SiteDetailSectionConfig(id: SiteDetailSectionId.notes, visible: true),
  ];

  /// [sections] reordered as if [rendered] had its [oldIndex] entry dropped
  /// at [newIndex]; cards outside [rendered] keep their place. See
  /// `section_order.moveRenderedSection`.
  static List<SiteDetailSectionConfig> moveRenderedSection(
    List<SiteDetailSectionConfig> sections,
    List<SiteDetailSectionId> rendered,
    int oldIndex,
    int newIndex,
  ) => section_order
      .moveRenderedSection<SiteDetailSectionConfig, SiteDetailSectionId>(
        sections,
        (s) => s.id,
        rendered,
        oldIndex,
        newIndex,
      );

  /// [sections] with every missing card added, visible, where the default
  /// order puts it. See `section_order.ensureAllSections`.
  static List<SiteDetailSectionConfig> ensureAllSections(
    List<SiteDetailSectionConfig> sections,
  ) => section_order
      .ensureAllSections<SiteDetailSectionConfig, SiteDetailSectionId>(
        sections,
        (s) => s.id,
        SiteDetailSectionId.values,
        (id) => SiteDetailSectionConfig(id: id, visible: true),
      );

  static String sectionsToJson(List<SiteDetailSectionConfig> sections) {
    return jsonEncode(sections.map((s) => s.toJson()).toList());
  }

  /// The saved list, or the defaults when [json] is null, empty or
  /// unreadable. Unknown ids are dropped; missing ones are added.
  static List<SiteDetailSectionConfig> sectionsFromJson(String? json) {
    if (json == null || json.isEmpty) return List.of(defaultSections);
    try {
      final decoded = jsonDecode(json) as List;
      final sections = decoded
          .whereType<Map<String, dynamic>>()
          .map(tryFromJson)
          .whereType<SiteDetailSectionConfig>()
          .toList();
      if (sections.isEmpty) return List.of(defaultSections);
      return ensureAllSections(sections);
    } catch (_) {
      return List.of(defaultSections);
    }
  }
}
