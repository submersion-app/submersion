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
    // Who it is shared with, for an item with an owner. Read whether or not
    // the profiles are known yet: the sharing row shows once they are, and
    // a choice made there must find the sharing read.
    if (session.stored.diverId != null) {
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
    // The photos, the older linked files and the check-ins' photos are
    // written with the container's readers, which outlive the page.
    final writers = SittingMediaWriters.forEquipment(container.read);
    holdSittingMedia(session, writers, cardId: GearItemCardId.photos.name);
    holdLegacyFiles(session, writers);
    holdCheckIns(session, writers);
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
    final changedCards = session.changedCardIds;
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
          messenger: ScaffoldMessenger.of(context),
          l10n: context.l10n,
          container: container,
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
      changedCardIds: changedCards,
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
  Set<String> changedCardIds = const {},
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
  // The item, its computer, clocks, photos, files and check-ins need no
  // invalidation here: each of their providers refreshes itself when its
  // table changes, so one here would only read it twice.
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
  // The service reminders follow the clocks, the records, the item's own
  // reminder days and its dates (Details): rescheduled when one of those
  // cards changed, not on every Save.
  if (changedCardIds.any(_serviceCards.contains)) {
    bestEffort(
      () => container
          .read(serviceRecordNotifierProvider(equipmentId).notifier)
          .refresh(),
      'reschedule service reminders after a save',
    );
  }
  bestEffort(
    () => container.read(equipmentListNotifierProvider.notifier).refresh(),
    'refresh the equipment lists after a save',
  );
}

/// The cards whose changes move the item's service reminders.
final Set<String> _serviceCards = {
  GearItemCardId.serviceClocks.name,
  GearItemCardId.serviceHistory.name,
  GearItemCardId.details.name,
};

/// [child], a section the page calculates, faded and labelled
/// "Calculated" while unlocked; untouched where the page does not edit in
/// place.
Widget _calculated(Widget child) => RecordCardFade<EquipmentItem>(
  reason: RecordCardFadeReason.calculated,
  child: child,
);
