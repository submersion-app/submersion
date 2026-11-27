part of 'equipment_detail_page.dart';

/// The gap above every section of the page.
const _sectionGap = SizedBox(height: 24);

/// The page's body: the pinned header, then the sections the diver shows, in
/// the diver's order (issue #4975).
///
/// Every section brings its own top gap. The cards that hide themselves
/// after loading (a dive computer's controls, the condition findings and
/// trends, the linked files) keep theirs inside, so a hidden or empty card
/// leaves no gap behind. In the default order this is the layout the page
/// always had.
extension _EquipmentDetailBody on _EquipmentDetailContent {
  Widget _body(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units, {
    required Widget header,
  }) => SingleChildScrollView(
    controller: DetailScrollController.maybeOf(context),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        for (final id in _shownSections(ref))
          ..._section(context, ref, id, units),
      ],
    ),
  );

  /// The sections this item's page builds, in the diver's order: the ones
  /// that belong on the item and are switched on, and a switched-off one
  /// with a card the sitting has open or brought in from the strip.
  List<EquipmentDetailSectionId> _shownSections(WidgetRef ref) {
    final sections = ref.watch(
      settingsProvider.select((s) => s.equipmentDetailSections),
    );
    final multipleDivers = ref.watch(hasMultipleDiversProvider);
    return [
      for (final section in sections)
        if (equipmentDetailSectionApplies(
              section.id,
              equipment,
              creating: _creating,
              multipleDivers: multipleDivers,
            ) &&
            (section.visible || _showsHidden(section.id)))
          section.id,
    ];
  }

  /// Whether the switched-off section [id] is shown all the same: its card
  /// is open, or was brought in from the strip, in the sitting.
  bool _showsHidden(EquipmentDetailSectionId id) {
    final card = equipmentDetailSectionCards[id];
    return card != null && _shows(card);
  }

  /// Section [id]'s widgets, its top gap first.
  List<Widget> _section(
    BuildContext context,
    WidgetRef ref,
    EquipmentDetailSectionId id,
    UnitFormatter units,
  ) => switch (id) {
    // The device's controls (issue #3676): this item is its one entry.
    // Brings its own top gap: it takes no room while it loads or fails.
    EquipmentDetailSectionId.diveComputer => [
      _framed(
        GearItemCardId.diveComputer,
        DiveComputerSection(equipmentId: equipmentId),
        topGap: 24,
      ),
    ],
    EquipmentDetailSectionId.details => [
      _sectionGap,
      _framed(
        GearItemCardId.details,
        _buildDetailsSection(context, ref, equipment, units),
      ),
    ],
    EquipmentDetailSectionId.transmitter => [
      _sectionGap,
      TransmitterSection(equipmentId: equipmentId),
    ],
    EquipmentDetailSectionId.location => [
      _sectionGap,
      _framed(
        GearItemCardId.location,
        EquipmentLocationCard(equipment: equipment, shown: _session),
      ),
    ],
    // A cylinder's passport, or any other gear's tag (issue #2652).
    EquipmentDetailSectionId.passport => [
      _sectionGap,
      _calculated(
        equipment.type == EquipmentType.tank
            ? PassportEntryCard(equipment: equipment)
            : GearPassportEntryCard(equipment: equipment),
      ),
    ],
    // Twin set pairing (issue #4242). It hides as Worn as says, as the
    // sitting has it.
    EquipmentDetailSectionId.twinSet => [
      _sectionGap,
      _framed(
        GearItemCardId.twinSet,
        TwinSetCard(equipmentId: equipmentId, working: equipment),
      ),
    ],
    EquipmentDetailSectionId.serviceClocks => [
      _sectionGap,
      _framed(
        GearItemCardId.serviceClocks,
        ServiceClocksCard(
          equipmentId: equipmentId,
          customReminder: (
            enabled: equipment.customReminderEnabled,
            days: equipment.customReminderDays,
          ),
          shown: _session,
        ),
      ),
    ],
    EquipmentDetailSectionId.exposure => [
      _sectionGap,
      _calculated(ExposureCard(equipmentId: equipmentId)),
    ],
    // The findings and trend cards carry their own top gap and render
    // nothing when they have nothing to say, so the page never shows a
    // blank slot for a rule engine.
    EquipmentDetailSectionId.condition => [
      _framed(
        GearItemCardId.conditionFindings,
        ConditionFindingsCard(equipment: equipment),
        topGap: 24,
      ),
      _calculated(ConditionTrendCard(equipment: equipment)),
      if (equipment.type == EquipmentType.rebreather)
        _calculated(
          ConditionTrendCard(
            equipment: equipment,
            kind: ConditionTrendKind.scrubberMinutes,
          ),
        ),
    ],
    EquipmentDetailSectionId.childItems => [
      _sectionGap,
      ChildrenCard(equipment: equipment),
    ],
    // Reference photos of the item (issue #3355).
    EquipmentDetailSectionId.photos => [
      _sectionGap,
      _framed(
        GearItemCardId.photos,
        EquipmentPhotosSection(equipment: equipment, shown: _session),
      ),
    ],
    EquipmentDetailSectionId.observations => [
      _sectionGap,
      _framed(
        GearItemCardId.observations,
        ObservationsCard(equipment: equipment, shown: _session),
      ),
    ],
    EquipmentDetailSectionId.components => [
      _sectionGap,
      _framed(
        GearItemCardId.components,
        ComponentsCard(equipmentId: equipmentId),
      ),
    ],
    EquipmentDetailSectionId.unitConfigurations => [
      _sectionGap,
      UnitConfigurationsCard(equipmentId: equipmentId),
    ],
    // Brings its own top gap: it hides itself once every linked file has
    // moved into Documents.
    EquipmentDetailSectionId.linkedFiles => [
      _framed(
        GearItemCardId.legacyFiles,
        EquipmentDocumentsSection(
          equipmentId: equipmentId,
          onOpenDocument: (item) => DocumentOpenHelper.open(context, ref, item),
          shown: _session,
        ),
        topGap: 24,
      ),
    ],
    // Who used it and every share (issue #2046).
    EquipmentDetailSectionId.sharingHistory => [
      _sectionGap,
      _calculated(EquipmentHistoryCard(equipmentId: equipmentId)),
    ],
    EquipmentDetailSectionId.serviceHistory => [
      _sectionGap,
      _framed(
        GearItemCardId.serviceHistory,
        ServiceHistorySection(equipmentId: equipmentId, shown: _session),
      ),
    ],
    // Notes of only spaces are empty, as the card counts them.
    EquipmentDetailSectionId.notes =>
      equipment.notes.trim().isNotEmpty || _shows(GearItemCardId.notes)
          ? [
              _sectionGap,
              _framed(
                GearItemCardId.notes,
                _buildNotesSection(context, equipment),
              ),
            ]
          : const [],
    EquipmentDetailSectionId.documents => [
      _sectionGap,
      _framed(
        GearItemCardId.documents,
        DocumentsSection<EquipmentItem>(
          owner: DocumentOwner(DocumentOwnerKind.equipment, equipmentId),
        ),
      ),
    ],
  };
}
