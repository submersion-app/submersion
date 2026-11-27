import 'dart:convert';

import 'package:submersion/core/constants/detail_section_order.dart'
    as section_order;
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Identifies each configurable card on a gear item's page (issue #4975).
///
/// Declaration order is the default display order: the order the page
/// shipped with before the diver could arrange it, so an existing diver sees
/// no change. The header (name, photo, status) is pinned above these cards,
/// so it does not appear here.
///
/// One order serves every type of gear. A card a type does not have (a dive
/// computer's controls, a cylinder's twin set) is skipped where it sits.
///
/// An order a diver has saved is kept as saved. This order also decides
/// where a card missing from a saved order joins it: right after its
/// nearest preceding card here (see `section_order.ensureAllSections`).
enum EquipmentDetailSectionId {
  /// A dive computer's download and connection controls.
  diveComputer,
  details,

  /// A transmitter's serial, channel and cylinder.
  transmitter,
  location,

  /// The cylinder passport of a tank, or the gear passport of other gear:
  /// one block, the passport page has its own layout.
  passport,
  twinSet,
  serviceClocks,
  exposure,

  /// The condition findings and the condition trend charts.
  condition,

  /// The cells and batteries installed in a host item.
  childItems,
  photos,
  observations,
  components,

  /// A rebreather's saved configurations.
  unitConfigurations,

  /// Files linked before Documents existed; hides once all have moved.
  linkedFiles,

  /// Who used the item and every share, with two or more profiles.
  sharingHistory,
  serviceHistory,
  notes,
  documents;

  /// The title the card itself shows, so the settings list and the page
  /// agree.
  String localizedDisplayName(AppLocalizations l10n) {
    return switch (this) {
      diveComputer => l10n.diveComputer_title,
      details => l10n.equipment_detail_detailsTitle,
      transmitter => l10n.equipmentDetailSection_transmitter_name,
      location => l10n.equipment_location_card_title,
      passport => l10n.equipmentDetailSection_passport_name,
      twinSet => l10n.twinSet_title,
      serviceClocks => l10n.equipment_serviceClocks_title,
      exposure => l10n.equipmentCondition_exposure_title,
      condition => l10n.equipmentDetailSection_condition_name,
      childItems => l10n.equipmentCondition_children_title,
      photos => l10n.equipment_photos_title,
      observations => l10n.equipmentObservation_card_title,
      components => l10n.equipment_components_title,
      unitConfigurations => l10n.cylinderConfigs_sectionTitle,
      linkedFiles => l10n.equipment_documents_linkedTitle,
      sharingHistory => l10n.equipmentDetailSection_sharingHistory_name,
      serviceHistory => l10n.equipment_service_historyTitle,
      notes => l10n.equipment_detail_notesTitle,
      documents => l10n.documents_section_title,
    };
  }

  /// One-line description shown below the name on the settings page.
  String localizedDescription(AppLocalizations l10n) {
    return switch (this) {
      diveComputer => l10n.equipmentDetailSection_diveComputer_description,
      details => l10n.equipmentDetailSection_details_description,
      transmitter => l10n.equipmentDetailSection_transmitter_description,
      location => l10n.equipmentDetailSection_location_description,
      passport => l10n.equipmentDetailSection_passport_description,
      twinSet => l10n.equipmentDetailSection_twinSet_description,
      serviceClocks => l10n.equipmentDetailSection_serviceClocks_description,
      exposure => l10n.equipmentDetailSection_exposure_description,
      condition => l10n.equipmentDetailSection_condition_description,
      childItems => l10n.equipmentDetailSection_childItems_description,
      photos => l10n.equipmentDetailSection_photos_description,
      observations => l10n.equipmentDetailSection_observations_description,
      components => l10n.equipmentDetailSection_components_description,
      unitConfigurations =>
        l10n.equipmentDetailSection_unitConfigurations_description,
      linkedFiles => l10n.equipmentDetailSection_linkedFiles_description,
      sharingHistory => l10n.equipmentDetailSection_sharingHistory_description,
      serviceHistory => l10n.equipmentDetailSection_serviceHistory_description,
      notes => l10n.equipmentDetailSection_notes_description,
      documents => l10n.equipmentDetailSection_documents_description,
    };
  }
}

/// Visibility and order of one card on a gear item's page.
///
/// Stored as a JSON list in `diver_settings.equipment_detail_sections`, in
/// the shape of the Site Details list without its fold state: the page has
/// no folded layout.
class EquipmentDetailSectionConfig {
  final EquipmentDetailSectionId id;
  final bool visible;

  const EquipmentDetailSectionConfig({required this.id, required this.visible});

  EquipmentDetailSectionConfig copyWith({bool? visible}) =>
      EquipmentDetailSectionConfig(id: id, visible: visible ?? this.visible);

  Map<String, dynamic> toJson() => {'id': id.name, 'visible': visible};

  /// Null for an entry this build cannot read: an unknown id (from a newer
  /// release, or a removed card) or a malformed entry.
  static EquipmentDetailSectionConfig? tryFromJson(Map<String, dynamic> json) {
    final idStr = json['id'];
    if (idStr is! String) return null;
    final id = EquipmentDetailSectionId.values
        .where((e) => e.name == idStr)
        .firstOrNull;
    if (id == null) return null;
    final visible = json['visible'];
    return EquipmentDetailSectionConfig(
      id: id,
      visible: visible is bool ? visible : true,
    );
  }

  /// Every card, visible, in declaration order. Const so it can be the
  /// settings' default; a test holds it to [EquipmentDetailSectionId.values].
  static const List<EquipmentDetailSectionConfig> defaultSections = [
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.diveComputer,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.details,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.transmitter,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.location,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.passport,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.twinSet,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.serviceClocks,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.exposure,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.condition,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.childItems,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.photos,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.observations,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.components,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.unitConfigurations,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.linkedFiles,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.sharingHistory,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.serviceHistory,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.notes,
      visible: true,
    ),
    EquipmentDetailSectionConfig(
      id: EquipmentDetailSectionId.documents,
      visible: true,
    ),
  ];

  /// [sections] reordered as if [rendered] had its [oldIndex] entry dropped
  /// at [newIndex]; cards outside [rendered] keep their place. See
  /// `section_order.moveRenderedSection`.
  static List<EquipmentDetailSectionConfig> moveRenderedSection(
    List<EquipmentDetailSectionConfig> sections,
    List<EquipmentDetailSectionId> rendered,
    int oldIndex,
    int newIndex,
  ) =>
      section_order.moveRenderedSection<
        EquipmentDetailSectionConfig,
        EquipmentDetailSectionId
      >(sections, (s) => s.id, rendered, oldIndex, newIndex);

  /// [sections] with every missing card added, visible, where the default
  /// order puts it. See `section_order.ensureAllSections`.
  static List<EquipmentDetailSectionConfig> ensureAllSections(
    List<EquipmentDetailSectionConfig> sections,
  ) =>
      section_order.ensureAllSections<
        EquipmentDetailSectionConfig,
        EquipmentDetailSectionId
      >(
        sections,
        (s) => s.id,
        EquipmentDetailSectionId.values,
        (id) => EquipmentDetailSectionConfig(id: id, visible: true),
      );

  static String sectionsToJson(List<EquipmentDetailSectionConfig> sections) {
    return jsonEncode(sections.map((s) => s.toJson()).toList());
  }

  /// The saved list, or the defaults when [json] is null, empty or
  /// unreadable. Unknown ids and repeated ids are dropped; missing ones are
  /// added.
  static List<EquipmentDetailSectionConfig> sectionsFromJson(String? json) {
    if (json == null || json.isEmpty) return defaultSections;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return defaultSections;
      final seen = <EquipmentDetailSectionId>{};
      final sections = [
        for (final entry in decoded.whereType<Map<String, dynamic>>())
          if (tryFromJson(entry) case final config? when seen.add(config.id))
            config,
      ];
      if (sections.isEmpty) return defaultSections;
      return ensureAllSections(sections);
    } on FormatException {
      return defaultSections;
    }
  }
}
