part of 'dive_detail_page.dart';

/// In-place editing for the dive page (issue #4527).
///
/// The page opens locked. Unlocking starts a sitting: the top bar becomes
/// Cancel and Save, the cards that can be edited gain a pencil, and cards
/// the page leaves out are offered in a strip under the bar. Save writes
/// the whole sitting at once and locks again.
///
/// Offered only when [DiveDetailPage.unlockEditing] is on, and not yet in
/// the list pane. With it off, the page builds none of this.
mixin _DiveDetailPageEditing on ConsumerState<DiveDetailPage> {
  RecordEditController<Dive>? _editController;

  /// The dive as a sitting just saved it, shown until the stored dive has
  /// been read back. Without it the page would show the old values, and
  /// drop a card that was only just filled in, for the moment between the
  /// lock returning and the reload landing.
  Dive? _justSaved;

  /// Whether this page offers unlock-to-edit.
  bool get editingOffered => widget.unlockEditing && !widget.embedded;

  /// Created on first use, so a page that never offers editing has none.
  RecordEditController<Dive> get editController =>
      _editController ??= RecordEditController<Dive>(onSave: _saveSitting)
        ..addListener(_onEditChanged);

  /// Whether a sitting is in progress.
  bool get isSittingOpen => _editController?.isUnlocked ?? false;

  void _onEditChanged() {
    if (mounted) setState(() {});
  }

  void disposeEditing() => _editController?.dispose();

  /// The dive the cards display: the diver's working copy during a
  /// sitting, else [stored].
  Dive shownDive(Dive stored) =>
      _editController?.session?.working ?? _justSaved ?? stored;

  /// Keeps the sitting on top of the dive as it is stored: a card the diver
  /// has not touched follows a change that arrives underneath. Call from
  /// `build`.
  void followStoredDive() {
    if (!editingOffered) return;
    ref.listen(diveProvider(widget.diveId), (_, next) {
      // A reload in flight still carries the dive it started from.
      if (next.isLoading) return;
      final dive = next.valueOrNull;
      if (dive == null) return;
      if (_justSaved != null) setState(() => _justSaved = null);
      _editController?.storedChanged(dive);
    });
  }

  Future<void> _saveSitting(EditSession<Dive> session) async {
    // Read now: the write may finish after the page has gone.
    final service = ref.read(diveEditSaveServiceProvider);
    final list = ref.read(paginatedDiveListProvider.notifier);
    final result = await service.save(
      diveId: widget.diveId,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
    );
    if (result == null) return;
    _justSaved = result.after;
    await list.refreshAfterWrite(before: result.before, after: result.after);
  }

  Future<void> _saveAndReport() async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.recordEdit_saveFailed;
    final saved = await editController.save();
    if (saved || !mounted || editController.saveError == null) return;
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  /// The lock in the locked page's top bar.
  Widget lockButton(Dive dive) => IconButton(
    icon: const Icon(Icons.lock_outline),
    tooltip: context.l10n.recordEdit_unlockTooltip,
    onPressed: () => editController.unlock(dive),
  );

  /// The cards the page is not showing for [working], in section order:
  /// hidden by the diver, or with nothing to show. A card brought in from
  /// the strip counts as shown while it is open or has something in it;
  /// emptied and closed, it is offered again.
  List<AddStripEntry> _addStripEntries(Dive working) {
    final sections = ref.watch(
      settingsProvider.select((s) => s.diveDetailSections),
    );
    final l10n = context.l10n;
    final added = editController.addedCardIds;
    final open = editController.openCardIds;
    return [
      for (final section in sections)
        if (diveEditCards[section.id] case final card?)
          if (!open.contains(card.id) &&
              !(working.isGauge && section.id.hiddenInGaugeMode) &&
              (card.isEmpty(working) ||
                  (!section.visible && !added.contains(card.id))))
            AddStripEntry(
              cardId: card.id,
              label: section.id.localizedDisplayName(l10n),
              hidden: !section.visible,
            ),
    ];
  }

  /// The full page with editing offered. [lockedBar] is the page's usual
  /// top bar and [content] its body; [shown] is the dive the cards display.
  ///
  /// The body keeps one shape whether locked or unlocked, so unlocking does
  /// not rebuild the page beneath it or lose its scroll position.
  Widget editScaffold({
    required Dive dive,
    required Dive shown,
    required PreferredSizeWidget lockedBar,
    required Widget content,
  }) {
    final controller = editController;
    return RecordEditLeaveGuard<Dive>(
      controller: controller,
      child: Scaffold(
        appBar: controller.isUnlocked
            ? RecordEditBar(
                title: context.l10n.recordEdit_editingTitle(
                  diveTitle(context, dive),
                ),
                canSave: controller.isDirty,
                isSaving: controller.isSaving,
                onCancel: () => cancelSitting(context, controller),
                onSave: _saveAndReport,
              )
            : lockedBar,
        body: Column(
          children: [
            AddStrip(
              entries: controller.isUnlocked
                  ? _addStripEntries(shown)
                  : const [],
              onAdd: controller.addCard,
            ),
            Expanded(
              child: RecordEditScope<Dive>(
                controller: controller,
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
