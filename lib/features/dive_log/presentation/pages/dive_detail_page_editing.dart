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
  /// sitting, or the dive as just saved, else [stored]. Either is used only
  /// when it is [stored]'s own dive.
  Dive shownDive(Dive stored) {
    final ours = _editController?.session?.working ?? _justSaved;
    return ours != null && ours.id == stored.id ? ours : stored;
  }

  /// The same page can be handed another dive, keeping its state (the list
  /// pane does this with its detail). A sitting, and the copy of a dive
  /// just saved, belong to the dive they were made for and do not follow.
  ///
  /// A sitting that is being written cannot be ended here. One that goes
  /// through ends itself; one that fails is ended by [_saveAndReport].
  @override
  void didUpdateWidget(DiveDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diveId == widget.diveId) return;
    _justSaved = null;
    _editController?.lock();
  }

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
      // Only the sitting's own dive. While a sitting is being written the
      // page can be handed another dive, and that sitting has not ended
      // yet: it must not be moved onto a dive it was not opened on.
      final controller = _editController;
      if (controller?.session?.stored.id != dive.id) return;
      controller?.storedChanged(dive);
    });
  }

  Future<void> _saveSitting(EditSession<Dive> session) async {
    // Read now: the write may finish after the page has gone.
    final service = ref.read(diveEditSaveServiceProvider);
    final list = ref.read(paginatedDiveListProvider.notifier);
    // The sitting's writes to other records are, so far, all to the site.
    final sites = session.hasHeldWrites
        ? ref.read(siteListNotifierProvider.notifier)
        : null;
    final followUp = DiveSittingFollowUp.read(context, ref);
    // The dive the sitting was opened on, whatever the page shows by the
    // time the write is asked for.
    final result = await service.save(
      diveId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
    );
    if (result == null) return;
    if (result.after.id == widget.diveId) _justSaved = result.after;
    // The write is committed. A refresh that fails from here on must not
    // read as a save that failed: the diver would be told nothing was
    // changed and handed the sitting to save a second time.
    try {
      await list.refreshAfterWrite(before: result.before, after: result.after);
    } catch (error, stackTrace) {
      _log.error(
        'Refresh after saving dive ${result.after.id} failed',
        error: error,
        stackTrace: stackTrace,
      );
      // The refresh may not have got as far as the dive itself, and the
      // page shows its own copy until the stored dive is read back.
      if (mounted) ref.invalidate(diveProvider(result.after.id));
    }
    // On its own, so that a dive list that could not be refreshed does not
    // leave the site list stale as well.
    try {
      await sites?.refresh();
    } catch (error, stackTrace) {
      _log.error(
        'Site refresh after saving dive ${result.after.id} failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    // What else the sitting owes: each step guards itself.
    await followUp.run(
      before: result.before,
      after: result.after,
      tripDateStretches: result.tripDateStretches,
    );
  }

  Future<void> _saveAndReport() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final controller = editController;
    final saved = await controller.save();
    if (saved || !mounted) return;
    // Refused for a field that holds text which is not a value: the card is
    // scrolled into view and its field says what is wrong with it.
    if (controller.refusedForInvalidInput) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.recordEdit_fixInvalid)),
      );
      return;
    }
    final error = controller.saveError;
    // The page was handed another dive while this was being written, when
    // the sitting could not be ended (see [didUpdateWidget]). It ends now,
    // or it would stay open over a dive it does not belong to.
    final session = controller.session;
    if (session != null && session.stored.id != widget.diveId) {
      controller.lock();
    }
    if (error == null) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.recordEdit_saveFailed)));
  }

  /// The lock in the locked page's top bar. [dive] is the dive as the
  /// page shows it, which just after a save is ahead of the one last read:
  /// a sitting must start from what the diver is looking at.
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
    // As the section list does: while an editor is open the cards on the
    // page, and so the chips here, stay as they were when it opened.
    final presence = editController.layoutRecord ?? working;
    return [
      for (final section in sections)
        if (diveEditCards[section.id] case final card?)
          if (!open.contains(card.id) &&
              !(working.isGauge && section.id.hiddenInGaugeMode) &&
              (!diveCardIsShown(ref, section.id, presence) ||
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
