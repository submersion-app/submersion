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
    gearItemTagsList.load(session);
    gearItemMovesList.load(session);
    gearItemClocksList.load(session);
    gearItemServiceRecordsList.load(session);
    // Who it is shared with, where it can be: an item with an owner, among
    // two or more profiles.
    if (session.stored.diverId != null &&
        container.read(hasMultipleDiversProvider)) {
      gearItemSharing.load(
        session,
        EquipmentSharesSharingAdapter(
          container.read(equipmentShareRepositoryProvider),
        ),
        actingDiverId: container.read(validatedCurrentDiverIdProvider).value,
      );
    }
    holdDocumentLinks(
      session,
      container.read,
      owner: DocumentOwner(DocumentOwnerKind.equipment, session.stored.id),
      cardId: GearItemCardId.documents.name,
    );
    // The photos and the older linked files are written with the
    // container's readers, which outlive the page.
    holdSittingMedia(
      session,
      SittingMediaWriters.forEquipment(container.read),
      cardId: GearItemCardId.photos.name,
    );
    holdLegacyFiles(session, SittingMediaWriters.forEquipment(container.read));
    holdCheckIns(session, SittingMediaWriters.forEquipment(container.read));
    gearItemCheckInsList.load(session);
  }

  /// Writes the sitting through the item's save service: its changed values
  /// and its held writes, in one transaction and one History entry. Then
  /// what the list notifier does after a write today ([afterGearItemSave]).
  @override
  Future<void> saveSitting(EditSession<EquipmentItem> session) async {
    // Read before the write: the page can be gone by the time it is done.
    final service = ref.read(gearItemEditSaveServiceProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    // Read now: the sitting ends with the Save.
    final clockSync = heldClockSync(session);
    // A failed write takes back what the media write did outside the
    // database.
    final result = await undoMediaOnFailure(
      session,
      () => service.save(
        // The item the sitting was opened on, whatever the page shows by
        // the time the write is asked for.
        equipmentId: session.stored.id,
        apply: (stored) => gearItemToSave(stored, session.applyTo(stored)),
        changedCardIds: session.changedCardIds,
        alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
        alsoWriteIsAChange: session.hasHeldChanges,
      ),
    );
    justSavedRecord = result?.after ?? session.working;
    // In the list's pane, an item the list's view no longer shows (its
    // status, its tags) is offered the view that does, as the form did.
    final after = result?.after;
    if (after != null && widget.embedded && mounted) {
      unawaited(
        offerViewRevealingSavedItem(
          context,
          ref,
          equipmentId: after.id,
          status: after.status,
        ),
      );
    }
    // Uploads and the remote deletes the unlinks held, once committed.
    final afterCommit = [
      ...mediaAfterCommit(session),
      ...legacyFilesAfterCommit(session),
      ...checkInsAfterCommit(session),
    ];
    afterGearItemSave(
      container,
      equipmentId: session.stored.id,
      before: result?.before,
      after: result?.after,
      clockSync: clockSync,
      afterCommit: afterCommit,
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
/// 6): the lists and the clocks refreshed, the service reminders
/// rescheduled, and the dives a transmitter item's registry entries match
/// rescanned when its serial changed. [before] and [after] are null when the
/// row did not change.
///
/// [clockSync], a dive computer's clock sync choice the sitting held, is
/// written here, once the sitting has committed: it lives in this
/// installation's preferences, outside the database and its History.
///
/// The sitting is saved by now, so each step is best effort: one that fails
/// is logged, never reported as the Save failing.
void afterGearItemSave(
  ProviderContainer container, {
  required String equipmentId,
  EquipmentItem? before,
  EquipmentItem? after,
  HeldClockSync? clockSync,
  List<Future<void> Function()> afterCommit = const [],
}) {
  void bestEffort(Future<void> Function() work, String task) =>
      logFailure(Future.sync(work), EquipmentDetailPage, task);

  for (final step in afterCommit) {
    bestEffort(step, 'a media follow-up after a save');
  }

  if (clockSync != null) {
    bestEffort(
      () => container
          .read(clockSyncSettingsNotifierProvider.notifier)
          .setOverride(clockSync.computerId, clockSync.value),
      'write the held clock sync choice',
    );
  }
  // The computer's own settings may have been written with the item.
  for (final computer
      in container.read(computersForEquipmentProvider(equipmentId)).value ??
          const <DiveComputer>[]) {
    container.invalidate(diveComputerByIdProvider(computer.id));
  }
  container
    ..invalidate(computersForEquipmentProvider(equipmentId))
    ..invalidate(allDiveComputersProvider)
    ..invalidate(favoriteDiveComputerProvider)
    ..invalidate(equipmentItemProvider(equipmentId))
    // Clocks and service records may have changed: re-evaluate them.
    ..invalidate(serviceClockStatusesProvider(equipmentId))
    ..invalidate(serviceSchedulesForEquipmentProvider(equipmentId))
    ..invalidate(activeEquipmentClocksProvider)
    // Photos, check-in photos and linked files may have changed.
    ..invalidate(identificationPhotosProvider(equipmentId))
    ..invalidate(checkInPhotosProvider(equipmentId))
    ..invalidate(mediaForEquipmentProvider(equipmentId))
    ..invalidate(observationsForEquipmentProvider(equipmentId));
  if (before != null &&
      after != null &&
      before.serialNumber != after.serialNumber) {
    bestEffort(
      () => container
          .read(transmitterRepositoryProvider)
          .rescanDivesForTransmitterItem(equipmentId),
      'rescan dives for the transmitter item',
    );
  }
  // The service reminders follow the clocks, the records and the item's
  // own reminder days.
  bestEffort(
    () => container
        .read(serviceRecordNotifierProvider(equipmentId).notifier)
        .refresh(),
    'reschedule service reminders after a save',
  );
  bestEffort(
    () => container.read(equipmentListNotifierProvider.notifier).refresh(),
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
