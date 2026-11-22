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
    final every = ref.read(allEquipmentProvider).value;
    final allSets = ref.read(equipmentSetsProvider).value;
    final ({EquipmentSet before, EquipmentSet after})? result;
    try {
      result = await service.save(
        // The set the sitting was opened on, whatever the page shows by the
        // time the write is asked for.
        setId: session.stored.id,
        apply: session.applyTo,
        changedCardIds: session.changedCardIds,
        alsoLogged: session.recall<bool>(_alsoLoggedKey) ?? false,
        coveredSetIds: session.recall<Set<String>>(_coveredSetIdsKey),
      );
    } on SetHistoryNotConfirmed {
      // The sets including this one changed while the diver answered: the
      // sitting stays as it is, and the next Save asks again.
      throw const RecordSittingRefusal(_setHistoryChangedMessage);
    }
    // Shown until the page reads the set again, and a new sitting can start
    // from it: with its items, as the set the page reads has them, so the
    // count and the members no longer shared are right meanwhile.
    final saved = result?.after ?? session.working;
    justSavedRecord = saved.copyWith(
      items: setItemsShownFrom(
        saved,
        session.stored,
        every: every,
        sets: allSets,
      ),
    );
    // The sitting has committed: the lists that show it catch up without
    // holding the Save.
    if (result != null) unawaited(sets.afterSittingSaved(session.stored.id));
  }

  /// Asks "Update past dives?" when the sitting changes the gear the set
  /// applies (its members, counting the sets it includes) and logged dives
  /// carry it or a set that includes it (issues #4283, #4525), before
  /// anything is written, as the form did. Cancel leaves the sitting as it
  /// is. The answer goes to [saveSitting] through the session: planned
  /// dives follow the set always, logged ones when the diver says so.
  @override
  Future<bool> beforeSave() async {
    final session = maybeEditController?.session;
    if (session == null) return true;
    session.remember(_alsoLoggedKey, false);
    session.remember(_coveredSetIdsKey, <String>{});
    // A sitting that changes neither the members nor the included sets
    // changes no dive: nothing to ask, and nothing to read.
    final before = session.stored;
    final after = session.working;
    if (setEquals(before.equipmentIds.toSet(), after.equipmentIds.toSet()) &&
        listEquals(before.includedSetIds, after.includedSetIds)) {
      return true;
    }
    // Every set of the owner, as the save reads them: a set that includes
    // this one has dives to ask about too. Without them the question could
    // leave out dives the save then rewrites, so the Save stops.
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.recordEdit_saveFailed;
    final List<EquipmentSet> allSets;
    try {
      allSets = await ref
          .read(equipmentSetRepositoryProvider)
          .getAllSets(diverId: session.stored.diverId);
    } catch (e, st) {
      LoggerService.forClass(EquipmentSet).error(
        'Reading the sets before a save failed',
        error: e,
        stackTrace: st,
      );
      messenger.showSnackBar(SnackBar(content: Text(failed)));
      return false;
    }
    if (!mounted) return false;
    final planned = setHistoryRewrites(
      before: session.stored,
      after: session.working,
      allSets: allSets,
    );
    // The save checks that the dives it changes are the ones asked about.
    session.remember(_coveredSetIdsKey, {
      for (final change in planned) change.setId,
    });
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

  /// [child] as the card [id], framed for editing in place.
  Widget _framed(EquipmentSetCardId id, Widget child) =>
      RecordCardFrame<EquipmentSet>(
        card: equipmentSetEditCards[id]!,
        child: child,
      );
}

/// The session note holding the answer to "Update past dives?": whether
/// the logged dives that carry the set are rewritten too.
const _alsoLoggedKey = 'equipmentSet.alsoLogged';

/// The session note holding the sets whose dives the question covered.
const _coveredSetIdsKey = 'equipmentSet.coveredSetIds';

/// What a Save refused because the sets including this one changed says:
/// nothing was saved, and Save again asks about the dives afresh.
String _setHistoryChangedMessage(AppLocalizations l10n) =>
    l10n.recordEdit_saveFailed;
