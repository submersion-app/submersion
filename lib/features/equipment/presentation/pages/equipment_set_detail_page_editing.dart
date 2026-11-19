part of 'equipment_set_detail_page.dart';

/// The equipment set page's use of the shared editing host (issue #4527,
/// phase 3): what is its own about saving, reading back, its cards and the
/// frames its sections sit in.
mixin _EquipmentSetDetailPageEditing
    on
        ConsumerState<EquipmentSetDetailPage>,
        RecordEditHost<EquipmentSetDetailPage, EquipmentSet>,
        RecordOpenUnlocked<EquipmentSetDetailPage, EquipmentSet> {
  @override
  String get hostRecordId => widget.setId;

  @override
  String recordIdOf(EquipmentSet record) => record.id;

  @override
  bool get hostsEditing => widget.unlockEditing;

  @override
  bool openUnlockedOf(EquipmentSetDetailPage widget) => widget.openUnlocked;

  @override
  VoidCallback? get onOpenedSittingEnded => widget.onSittingEnded;

  @override
  void onEditChanged() {
    noteOpenedSittingEnded();
    super.onEditChanged();
  }

  @override
  Iterable<EditCard<EquipmentSet>> get hostEditCards =>
      equipmentSetEditCards.values;

  @override
  EquipmentSet? get storedForUnlock =>
      ref.read(equipmentSetProvider(widget.setId)).value;

  @override
  String editingTitle(EquipmentSet record) =>
      context.l10n.recordEdit_editingTitle(record.name);

  /// Writes the sitting through the set's save service: its changed values,
  /// the default it demotes and the dives that follow its gear, in one
  /// transaction and one History entry.
  @override
  Future<void> saveSitting(EditSession<EquipmentSet> session) async {
    // Read before the write: the page can be gone by the time it is done.
    final service = ref.read(equipmentSetEditSaveServiceProvider);
    final sets = ref.read(equipmentSetListNotifierProvider.notifier);
    final result = await service.save(
      // The set the sitting was opened on, whatever the page shows by the
      // time the write is asked for.
      setId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      alsoLogged: session.recall<bool>(_alsoLoggedKey) ?? false,
    );
    justSavedRecord = result?.after ?? session.working;
    if (result != null) await sets.afterSittingSaved(session.stored.id);
  }

  /// Asks "Update past dives?" when the sitting changes the gear the set
  /// applies (its members, counting the sets it includes) and logged dives
  /// carry it or a set that includes it (issues #4283, #4525), before
  /// anything is written, as the form does. Cancel leaves the sitting as it
  /// is. The answer goes to [saveSitting] through the session: planned
  /// dives follow the set always, logged ones when the diver says so.
  @override
  Future<bool> beforeSave() async {
    final session = maybeEditController?.session;
    if (session == null) return true;
    session.remember(_alsoLoggedKey, false);
    List<EquipmentSet> allSets;
    try {
      allSets = await ref.read(equipmentSetsProvider.future);
    } catch (_) {
      allSets = [session.stored];
    }
    if (!mounted) return false;
    final planned = setHistoryRewrites(
      before: session.stored,
      after: session.working,
      allSets: allSets,
    );
    if (planned.isEmpty) return true;
    final asked = await askSetHistory(
      context,
      ref,
      setId: session.stored.id,
      alsoSetIds: [
        for (final change in planned)
          if (change.setId != session.stored.id) change.setId,
      ],
    );
    if (asked == null || !mounted) return false;
    session.remember(_alsoLoggedKey, asked == AssemblyHistoryChoice.alsoPast);
    return true;
  }

  @override
  Future<EquipmentSet?> rereadStored(
    ProviderContainer container,
    EquipmentSet stored,
  ) {
    container.invalidate(equipmentSetProvider(stored.id));
    return container.read(equipmentSetProvider(stored.id).future);
  }

  /// The cards the page leaves out while they are empty (Question 3).
  @override
  List<AddStripEntry> addStripEntries(EquipmentSet working) {
    final session = maybeEditController?.session;
    if (session == null) return const [];
    return [
      for (final id in equipmentSetOptionalCards)
        if (equipmentSetEditCards[id]!.isEmpty(working) &&
            !_showsWhileEmpty(id))
          AddStripEntry(
            cardId: id.name,
            label: equipmentSetEditCards[id]!.title(context),
            changed: session.changedCardIds.contains(id.name),
          ),
    ];
  }

  /// Whether [id] is shown though empty: open or brought in from the strip
  /// during the sitting.
  bool _showsWhileEmpty(EquipmentSetCardId id) {
    final controller = maybeEditController;
    if (controller == null || !controller.isUnlocked) return false;
    return controller.openCardIds.contains(id.name) ||
        controller.addedCardIds.contains(id.name);
  }

  /// [child] as the card [id], framed for editing in place where the page
  /// does.
  Widget _framed(EquipmentSetCardId id, Widget child) => hostsEditing
      ? RecordCardFrame<EquipmentSet>(
          card: equipmentSetEditCards[id]!,
          child: child,
        )
      : child;
}

/// The session note holding the answer to "Update past dives?": whether
/// the logged dives that carry the set are rewritten too.
const _alsoLoggedKey = 'equipmentSet.alsoLogged';
