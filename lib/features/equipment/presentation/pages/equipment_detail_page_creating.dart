part of 'equipment_detail_page.dart';

/// A new gear item, or a clone, on the item page (issue #4527, phase 3,
/// plan 11): the page's hooks for the shared [RecordCreating]. It opens
/// unlocked on a seed ([newGearItemSeed]) with the header block, Details
/// and Location laid out open, puts what the opener asked for (a type, a
/// serial, a part's host, or another item's copy) on as changes, and at
/// Save creates the item, its first place, its tags and a clone's extras
/// in one transaction. A clone then takes the place of the page it was
/// opened from, as the form did.
mixin _EquipmentDetailPageCreating
    on
        ConsumerState<EquipmentDetailPage>,
        RecordEditHost<EquipmentDetailPage, EquipmentItem>,
        RecordCreating<EquipmentDetailPage, EquipmentItem> {
  /// What a clone copies, once read.
  GearCloneSource? _clone;

  @override
  bool get isCreating => widget.newItem != null;

  bool get _isClone => widget.newItem?.isClone ?? false;

  @override
  Future<EquipmentItem?> makeNewRecordSeed(
    RecordSeedRead read,
    String id,
  ) async {
    final cloneFrom = widget.newItem?.cloneFromId;
    if (cloneFrom != null) {
      final copyName = context.l10n.equipment_clone_nameCopy;
      final clone = await readGearClone(read, cloneFrom, copyName: copyName);
      // Gone, or another profile's item it cannot see: not found.
      if (clone == null) return null;
      _clone = clone;
    }
    return newGearItemSeed(read, id: id);
  }

  @override
  List<String> newRecordLaidOut(EquipmentItem seed) => newGearItemLaidOut;

  @override
  Future<void> applyNewRecordPrefill(EditSession<EquipmentItem> session) =>
      applyNewGearItemPrefill(
        session,
        request: widget.newItem,
        clone: _clone,
        cloneService: ref.read(equipmentCloneServiceProvider),
      );

  /// The item and its held writes, in one transaction, with what the form
  /// decides at Save: the diver active now for a seed made with none, and
  /// the parent dropped when it cannot hold the item's type.
  @override
  Future<EquipmentItem> createRecord(EditSession<EquipmentItem> session) async {
    // Read before the first wait: the page can be gone by the end.
    final service = ref.read(gearItemEditSaveServiceProvider);
    final equipment = ref.read(equipmentRepositoryProvider);
    final read = ref.read;
    var item = gearItemToSave(session.stored, session.applyTo(session.stored));
    final diverId =
        item.diverId ?? await newRecordDiverId(read, record: 'gear item');
    item = item.copyWith(diverId: diverId);
    item = gearParentField.write(
      item,
      await gearParentToSave(
        equipment,
        type: item.type,
        parentId: item.parentEquipmentId,
        diverId: diverId,
      ),
    );
    final created = item;
    return undoMediaOnFailure(
      session,
      () => service.create(
        item: created,
        changedCardIds: session.changedCardIds,
        alsoWrite: heldWritesForCreate(session),
      ),
    );
  }

  /// What the list does after a write, and the offer of the list's view
  /// that shows the item when the current one hides it, as the form did.
  @override
  Future<void> Function(EquipmentItem created) captureAfterRecordCreated() {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final session = maybeEditController?.session;
    final afterCommit = session == null
        ? const <Future<void> Function()>[]
        : gearItemAfterCommit(session);
    final changedCards = session?.changedCardIds ?? const <String>{};
    return (created) async {
      afterGearItemSave(
        container,
        equipmentId: created.id,
        after: created,
        afterCommit: afterCommit,
        changedCardIds: changedCards,
      );
      await offerViewRevealingSavedItem(
        messenger: messenger,
        l10n: l10n,
        container: container,
        equipmentId: created.id,
        status: created.status,
      );
    };
  }

  /// A clone on a full page takes the place of the page it was opened from,
  /// shown locked, as the form did; anything else leaves as any new record.
  @override
  void leaveCreated(EquipmentItem created) {
    if (_isClone && !widget.embedded && GoRouter.maybeOf(context) != null) {
      context.pushReplacement('/equipment/${created.id}');
      return;
    }
    super.leaveCreated(created);
  }

  @override
  String newRecordTitle(BuildContext context) => _isClone
      ? context.l10n.equipment_edit_appBar_cloneTitle
      : context.l10n.equipment_edit_appBar_newTitle;

  @override
  String get newRecordLeaveLocation => '/equipment';

  @override
  bool get newRecordEmbedded => widget.embedded;

  @override
  void Function(String id)? get onNewRecordCreated => widget.onCreated;

  @override
  VoidCallback? get onNewRecordCancelled => widget.onCreateCancelled;

  @override
  ({String title, String body}) newRecordUnavailable(
    BuildContext context, {
    Object? error,
  }) => (
    title: context.l10n.equipment_detail_notFoundTitle,
    body: error == null
        ? context.l10n.equipment_detail_notFoundMessage
        : context.l10n.equipment_detail_errorMessage('$error'),
  );
}

/// The body of an item not yet created: the cards of its own values (the
/// header block, Details, Location, its service clocks and reminder,
/// Notes, Documents). What reads the stored item by its id (a dive
/// computer's controls, passports, twin sets, parts, photos, observations,
/// components, findings, history) waits until it exists (plan 11,
/// Question 9).
extension _EquipmentDetailNewItemBody on _EquipmentDetailContent {
  Widget _newItemBody(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) => SingleChildScrollView(
    controller: DetailScrollController.maybeOf(context),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _framed(
          GearItemCardId.header,
          _buildHeaderSection(context, equipment, false, null),
        ),
        const SizedBox(height: 24),
        _framed(
          GearItemCardId.details,
          _buildDetailsSection(context, ref, equipment, units),
        ),
        const SizedBox(height: 24),
        _framed(
          GearItemCardId.location,
          EquipmentLocationCard(equipment: equipment, shown: _session),
        ),
        if (!equipment.isWanted) ...[
          const SizedBox(height: 24),
          _framed(
            GearItemCardId.serviceClocks,
            ServiceClocksCard(
              equipmentId: equipmentId,
              customReminder: (
                enabled: equipment.customReminderEnabled,
                days: equipment.customReminderDays,
              ),
            ),
          ),
        ],
        if (equipment.notes.trim().isNotEmpty ||
            _shows(GearItemCardId.notes)) ...[
          const SizedBox(height: 24),
          _framed(GearItemCardId.notes, _buildNotesSection(context, equipment)),
        ],
        const SizedBox(height: 24),
        _framed(
          GearItemCardId.documents,
          DocumentsSection<EquipmentItem>(
            owner: DocumentOwner(DocumentOwnerKind.equipment, equipmentId),
          ),
        ),
      ],
    ),
  );
}
