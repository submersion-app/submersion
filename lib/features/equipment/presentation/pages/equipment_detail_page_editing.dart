part of 'equipment_detail_page.dart';

/// The gear item page's use of the shared editing host (issue #4527, phase
/// 3, plan 6): what is its own about saving, reading back, its cards and the
/// frames its sections sit in.
mixin _EquipmentDetailPageEditing
    on
        ConsumerState<EquipmentDetailPage>,
        RecordEditHost<EquipmentDetailPage, EquipmentItem>,
        RecordOpenUnlocked<EquipmentDetailPage, EquipmentItem> {
  @override
  String get hostRecordId => widget.equipmentId;

  @override
  String recordIdOf(EquipmentItem record) => record.id;

  @override
  bool get hostsEditing => widget.unlockEditing;

  @override
  bool openUnlockedOf(EquipmentDetailPage widget) => widget.openUnlocked;

  @override
  VoidCallback? get onOpenedSittingEnded => widget.onSittingEnded;

  @override
  void onEditChanged() {
    noteOpenedSittingEnded();
    super.onEditChanged();
  }

  @override
  Iterable<EditCard<EquipmentItem>> get hostEditCards =>
      gearItemEditCards.values;

  @override
  EquipmentItem? get storedForUnlock =>
      ref.read(equipmentItemProvider(widget.equipmentId)).value;

  @override
  String editingTitle(EquipmentItem record) =>
      context.l10n.recordEdit_editingTitle(record.name);

  /// Reads what the cards hold beside the item's own values, so they show
  /// the sitting's rows once they change; the documents attached and
  /// detached in the sitting are filed under the item.
  @override
  void onSittingStart(
    EditSession<EquipmentItem> session,
    ProviderContainer container,
  ) {
    holdDocumentLinks(
      session,
      container.read,
      owner: DocumentOwner(DocumentOwnerKind.equipment, session.stored.id),
      cardId: GearItemCardId.documents.name,
    );
  }

  /// Writes the sitting through the item's save service: its changed values
  /// and its held writes, in one transaction and one History entry. Then
  /// what the list notifier does after a write today ([afterGearItemSave]).
  @override
  Future<void> saveSitting(EditSession<EquipmentItem> session) async {
    // Read before the write: the page can be gone by the time it is done.
    final service = ref.read(gearItemEditSaveServiceProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final result = await service.save(
      // The item the sitting was opened on, whatever the page shows by the
      // time the write is asked for.
      equipmentId: session.stored.id,
      apply: (stored) => gearItemToSave(stored, session.applyTo(stored)),
      changedCardIds: session.changedCardIds,
      alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
      alsoWriteIsAChange: session.hasHeldChanges,
    );
    justSavedRecord = result?.after ?? session.working;
    await afterGearItemSave(
      container,
      equipmentId: session.stored.id,
      before: result?.before,
      after: result?.after,
    );
  }

  @override
  Future<EquipmentItem?> rereadStored(
    ProviderContainer container,
    EquipmentItem stored,
  ) {
    container.invalidate(equipmentItemProvider(stored.id));
    return container.read(equipmentItemProvider(stored.id).future);
  }

  /// The cards the page leaves out while they are empty.
  @override
  List<AddStripEntry> addStripEntries(EquipmentItem working) {
    final session = maybeEditController?.session;
    if (session == null) return const [];
    return [
      for (final id in gearItemOptionalCards)
        if (gearItemEditCards[id]!.isEmpty(working) && !_showsWhileEmpty(id))
          AddStripEntry(
            cardId: id.name,
            label: gearItemEditCards[id]!.title(context),
            changed: session.changedCardIds.contains(id.name),
          ),
    ];
  }

  /// Whether [id] is shown though empty: open or brought in from the strip
  /// during the sitting.
  bool _showsWhileEmpty(GearItemCardId id) {
    final controller = maybeEditController;
    if (controller == null || !controller.isUnlocked) return false;
    return controller.openCardIds.contains(id.name) ||
        controller.addedCardIds.contains(id.name);
  }

  /// [child] as the card [id], framed for editing in place; [topGap] is the
  /// gap a card that places its own puts above itself.
  Widget _framed(GearItemCardId id, Widget child, {double topGap = 0}) =>
      RecordCardFrame<EquipmentItem>(
        card: gearItemEditCards[id]!,
        topGap: topGap,
        child: child,
      );
}

/// What the list notifier does after it writes an item today, done once a
/// sitting on item [equipmentId] has been saved (issue #4527, phase 3, plan
/// 6): the lists refreshed, and the dives a transmitter item's registry
/// entries match rescanned when its serial changed (best effort, as the
/// edit form). [before] and [after] are null when the row did not change.
Future<void> afterGearItemSave(
  ProviderContainer container, {
  required String equipmentId,
  EquipmentItem? before,
  EquipmentItem? after,
}) async {
  if (before != null &&
      after != null &&
      before.serialNumber != after.serialNumber) {
    logFailure(
      container
          .read(transmitterRepositoryProvider)
          .rescanDivesForTransmitterItem(equipmentId),
      EquipmentDetailPage,
      'rescan dives for the transmitter item',
    );
  }
  container.invalidate(equipmentItemProvider(equipmentId));
  // The sitting is saved: a list that fails to reload says nothing more
  // about it, so it is logged, not reported as the Save failing.
  logFailure(
    container.read(equipmentListNotifierProvider.notifier).refresh(),
    EquipmentDetailPage,
    'refresh the equipment lists after a save',
  );
}

/// [child], a section the page calculates, faded and labelled
/// "Calculated" while unlocked; untouched where the page does not edit in
/// place.
Widget _calculated(Widget child) => RecordCardFade<EquipmentItem>(
  reason: RecordCardFadeReason.calculated,
  child: child,
);
