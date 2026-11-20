part of 'equipment_set_detail_page.dart';

/// A new equipment set, or a clone, on the set page (issue #4527, phase 3,
/// plan 11): the page's hooks for the shared [RecordCreating]. It opens
/// unlocked on a seed ([newEquipmentSetSeed]) with the header block and
/// Members laid out open, puts a clone's copy on as changes, and at Save
/// creates the set, its default and its geofences in one transaction. A
/// clone pops its id to the set page's Clone, which shows it in the
/// source's place, as today.
mixin _EquipmentSetDetailPageCreating
    on
        ConsumerState<EquipmentSetDetailPage>,
        RecordEditHost<EquipmentSetDetailPage, EquipmentSet>,
        RecordCreating<EquipmentSetDetailPage, EquipmentSet> {
  /// What a clone copies, once read.
  EquipmentSet? _clone;

  @override
  bool get isCreating => widget.newSet != null;

  bool get _isClone => widget.newSet?.cloneFromId != null;

  @override
  Future<EquipmentSet?> makeNewRecordSeed(
    RecordSeedRead read,
    String id,
  ) async {
    final cloneFrom = widget.newSet?.cloneFromId;
    if (cloneFrom != null) {
      final copyName = context.l10n.equipment_clone_nameCopy;
      final clone = await readSetClone(read, cloneFrom, copyName: copyName);
      if (clone == null) return null;
      _clone = clone;
    }
    return newEquipmentSetSeed(read, id: id);
  }

  @override
  List<String> newRecordLaidOut(EquipmentSet seed) =>
      newEquipmentSetLaidOut(clone: _clone);

  @override
  Future<void> applyNewRecordPrefill(EditSession<EquipmentSet> session) async =>
      applyNewEquipmentSetPrefill(session, _clone);

  /// A profile switched before Save drops a clone, as the form does: a set
  /// is its owner's alone, and the clone was read for the profile before.
  void _dropCloneOnProfileSwitch() {
    ref.listen(validatedCurrentDiverIdProvider, (previous, next) {
      final seed = newRecordSeed;
      final diverId = next.value;
      if (!_isClone || seed == null || next.isLoading) return;
      if (diverId != seed.diverId) maybeEditController?.lock();
    });
  }

  @override
  Future<EquipmentSet> createRecord(EditSession<EquipmentSet> session) {
    // Read before the write: the page can be gone by the time it is done.
    final service = ref.read(equipmentSetEditSaveServiceProvider);
    return service.create(
      set: session.applyTo(session.stored),
      changedCardIds: session.changedCardIds,
      alsoWrite: heldWritesForCreate(session),
    );
  }

  /// The set lists read again, as a saved sitting's are.
  @override
  Future<void> Function(EquipmentSet created) captureAfterRecordCreated() {
    final sets = ref.read(equipmentSetListNotifierProvider.notifier);
    return (created) => sets.afterSittingSaved(created.id);
  }

  @override
  String newRecordTitle(BuildContext context) => _isClone
      ? context.l10n.equipment_setEdit_appBar_cloneTitle
      : context.l10n.equipment_setEdit_appBar_newTitle;

  @override
  String get newRecordLeaveLocation => '/equipment/sets';

  @override
  ({String title, String body}) newRecordUnavailable(
    BuildContext context, {
    Object? error,
  }) => (
    title: context.l10n.equipment_setDetail_notFoundTitle,
    body: error == null
        ? context.l10n.equipment_setDetail_notFoundMessage
        : context.l10n.equipment_setDetail_errorMessage('$error'),
  );
}
