part of 'dive_detail_page.dart';

/// In-place editing for the dive page (issue #4527).
///
/// The page opens locked. Unlocking starts a sitting: the top bar becomes
/// Cancel and Save, the cards that can be edited gain a pencil, and cards
/// the page leaves out are offered in a strip under the bar. Save writes
/// the whole sitting at once and locks again.
///
/// Offered on the full page and in the list pane alike.
mixin _DiveDetailPageEditing on ConsumerState<DiveDetailPage> {
  RecordEditController<Dive>? _editController;

  /// The dive the page shows ([_DiveDetailPageActions.diveId]).
  String get diveId;

  /// Whether the page is of a new dive not yet created, and what it does
  /// in place of a stored dive's save and cancel
  /// ([_DiveDetailPageCreating]).
  bool get isCreating;
  Future<void> _createSitting(EditSession<Dive> session);
  Future<void> _saveNewDive();
  Future<void> _cancelNewDive();

  /// The dive as a sitting just saved it, shown until the stored dive has
  /// been read back. Without it the page would show the old values, and
  /// drop a card that was only just filled in, for the moment between the
  /// lock returning and the reload landing.
  Dive? _justSaved;

  /// Created on first use.
  RecordEditController<Dive> get editController => _editController ??=
      _newEditController(ProviderScope.containerOf(context, listen: false));

  /// Set while a leave the app asked about (another row, a tab, a quit)
  /// discards the sitting: that end is the leave's, and the page is going
  /// ([_DiveDetailPageUnlockOpen] does not report it).
  bool _endedByLeave = false;

  /// Makes the sitting's unsaved changes work the app asks about before a
  /// tab, a pane row or a quit leaves them (issue #4527).
  RecordSittingExitBlocker<Dive>? _exitBlocker;

  RecordEditController<Dive> _newEditController(ProviderContainer container) {
    final controller = _newController(container);
    _exitBlocker = RecordSittingExitBlocker<Dive>(
      controller: controller,
      guard: container.read(appExitGuardProvider),
      confirm: () async {
        if (!mounted) return false;
        // Set first: a discard locks, and tells the page, before
        // cancelSitting returns.
        _endedByLeave = true;
        final left = await cancelSitting(context, controller);
        if (!left) _endedByLeave = false;
        return left;
      },
      // The route the page is on, so leaving another page asks nothing.
      page: () => mounted ? recordSittingPageOf(context) : null,
    );
    return controller;
  }

  RecordEditController<Dive> _newController(ProviderContainer container) =>
      RecordEditController<Dive>(
        onSave: _saveSitting,
        // A new dive's sitting creates it (issue #4527, plan 8).
        creating: isCreating,
        // After a whole-record operation: the dive as stored now, read
        // through the provider the page shows, so both agree.
        reread: (stored) {
          container.invalidate(diveProvider(stored.id));
          return container.read(diveProvider(stored.id).future);
        },
        // Each card's own check, asked at Save of open and closed cards.
        invalidCards: (session) => [
          for (final card in diveEditCards.values)
            if (card.isValid?.call(session) == false) card.id,
        ],
        // Whatever unlocked the page. The container's read, not the
        // page's: a held write can run after the page has gone.
        onStart: (session) => startDiveSitting(
          session,
          ProviderScope.containerOf(context, listen: false).read,
        ),
      )..addListener(_onEditChanged);

  /// Where a drop finds the open sitting, read with the controller so it
  /// can still be cleared once the page has gone.
  late final StateController<OpenDiveSitting?> _openSittingSlot = ref.read(
    openDiveSittingProvider.notifier,
  );

  /// The sitting this page last told [openDiveSittingProvider] about.
  EditSession<Dive>? _toldSitting;

  /// Whether a sitting is in progress.
  bool get isSittingOpen => _editController?.isUnlocked ?? false;

  /// Tells the page's owner when a sitting opened unlocked has ended
  /// ([_DiveDetailPageUnlockOpen]).
  void _noteSittingEnded();

  void _onEditChanged() {
    _tellOpenSitting(_editController?.session);
    _noteSittingEnded();
    if (mounted) setState(() {});
  }

  /// Tells a drop which sitting is open, or that this page's has ended.
  /// Set after the frame's work, since a lock can come while the page is
  /// being built (another dive handed to it); a drop in between finds the
  /// ended sitting disposed and is refused.
  void _tellOpenSitting(EditSession<Dive>? session) {
    if (session == _toldSitting) return;
    final told = _toldSitting;
    _toldSitting = session;
    final slot = _openSittingSlot;
    final open = session == null
        ? null
        : OpenDiveSitting(
            diveId: session.stored.id,
            session: session,
            showMediaCard: () =>
                _editController?.addCard(DiveDetailSectionId.media.name),
          );
    Future.microtask(() {
      // The app (its provider scope) may have gone with the page.
      if (!slot.mounted) return;
      // Only this page's own: another page may have unlocked since.
      if (open == null && slot.state?.session != told) return;
      slot.state = open;
    });
  }

  /// This page as the editing keys' target (Unlock, Save, Cancel), while
  /// it offers editing.
  RecordEditShortcutTarget? _shortcutTarget;
  RecordEditShortcutTargets? _shortcutTargets;

  @override
  void initState() {
    super.initState();
    final controller = editController;
    final target = _shortcutTarget = RecordEditShortcutTarget(
      controller: controller,
      unlock: () {
        // A new dive's page opens unlocked; there is nothing to unlock.
        if (isCreating) return;
        final stored = ref.read(diveProvider(diveId)).value;
        if (stored != null) controller.unlock(shownDive(stored));
      },
      save: _saveAndReport,
      cancel: () =>
          isCreating ? _cancelNewDive() : cancelSitting(context, controller),
      // The page in view: not under a page, sheet or menu, and in the list
      // pane not giving its place to a site.
      isCurrent: () =>
          mounted &&
          (ModalRoute.of(context)?.isCurrent ?? true) &&
          (widget.embeddedSiteId?.isEmpty ?? true),
    );
    final targets = ref.read(recordEditShortcutTargetsProvider);
    _shortcutTargets = targets;
    targets.add(target);
  }

  void disposeEditing() {
    final target = _shortcutTarget;
    if (target != null) _shortcutTargets?.remove(target);
    _tellOpenSitting(null);
    _exitBlocker?.dispose();
    _editController?.dispose();
  }

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
    // The pane showing a site in the dive's place ends the sitting: its
    // link asked first when there was anything to lose.
    final site = widget.embeddedSiteId;
    if (site != null && site.isNotEmpty && site != oldWidget.embeddedSiteId) {
      _editController?.lock();
    }
    if (oldWidget.diveId == widget.diveId) return;
    _justSaved = null;
    _editController?.lock();
  }

  /// Keeps the sitting on top of the dive as it is stored: a card the diver
  /// has not touched follows a change that arrives underneath. Call from
  /// `build`.
  void followStoredDive() {
    ref.listen(diveProvider(diveId), (_, next) {
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
    if (session.isNew) return _createSitting(session);
    // Read now: the write may finish after the page has gone.
    final service = ref.read(diveEditSaveServiceProvider);
    final list = ref.read(paginatedDiveListProvider.notifier);
    // The sitting's writes to other records all reach the site (an
    // altitude, a location); its gas switches and a reassign's readings are
    // the dive's own rows, and leave the site list as it is.
    final writesSites = session.heldKeys
        .difference(diveOwnHeldWriteKeys)
        .isNotEmpty;
    final sites = writesSites
        ? ref.read(siteListNotifierProvider.notifier)
        : null;
    final followUp = DiveSittingFollowUp.read(context, ref);
    // Read now: the sitting is disposed once the write has gone through.
    final changedCardIds = session.changedCardIds;
    // The buddies the dive had and has, whose counts and lists the save
    // changes; the list reads nothing once the sitting has ended.
    final buddyIds = {
      for (final b in [
        ...?diveBuddiesList.loaded(session),
        ...?diveBuddiesList.current(session),
      ])
        b.buddy.id,
    };
    // A save that did not commit may have noted sites it located.
    forgetSitesLocated(session);
    // A write that does not commit takes back what the sitting's media
    // write did outside the database (a relink's new bookmark).
    final result = await undoMediaOnFailure(
      session,
      () => service.save(
        // The dive the sitting was opened on, whatever the page shows by
        // the time the write is asked for.
        diveId: session.stored.id,
        // The changes, and the rebreather values a changed mode no longer
        // uses dropped.
        apply: (stored) => diveSittingApply(session, stored),
        changedCardIds: session.changedCardIds,
        writeFirst: session.hasHeldWritesBeforeRecord
            ? () => session.runHeldWrites(beforeRecord: true)
            : null,
        alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
        alsoWriteIsAChange: session.hasHeldChanges,
      ),
    );
    if (result == null) return;
    if (result.after.id == diveId) _justSaved = result.after;
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
      changedCardIds: changedCardIds,
      // What the sitting's own writes left for after the commit.
      mediaAfterCommit: mediaAfterCommit(session),
      buddyIds: buddyIds,
      skippedRouteIds:
          session.recall<List<String>>(routeLinksSkippedKey) ?? const [],
      planLinksAdopted:
          session.recall<List<(String, String?)>>(planLinkAdoptKey) ?? const [],
      sitesLocated: sitesLocatedInSave(session),
    );
  }

  Future<void> _saveAndReport() async {
    if (isCreating) return _saveNewDive();
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
    if (session != null && session.stored.id != diveId) {
      controller.lock();
    }
    if (error == null) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.recordEdit_saveFailed)));
  }

  /// The lock in the locked page's top bar. [dive] is the dive as the
  /// page shows it, which just after a save is ahead of the one last read:
  /// a sitting must start from what the diver is looking at.
  /// [compact] is the list pane's smaller header.
  Widget lockButton(Dive dive, {bool compact = false}) => IconButton(
    icon: Icon(Icons.lock_outline, size: compact ? 20 : null),
    visualDensity: compact ? VisualDensity.compact : null,
    tooltip: context.l10n.recordEdit_unlockTooltip,
    onPressed: () => editController.unlock(dive),
  );

  /// The unlocked bar's title: "Log Dive" for a new dive, as the form it
  /// replaces is titled (issue #4527, plan 8), else the dive's own.
  String _editingTitle(Dive dive) => isCreating
      ? context.l10n.diveLog_edit_appBarNew
      : context.l10n.recordEdit_editingTitle(diveTitle(context, dive));

  /// The list pane's header row while unlocked: Cancel, the title, [menu]
  /// and Save, laid over the locked row.
  Widget editingPaneRow(Dive dive, {required Widget menu}) {
    final controller = editController;
    return DiveDetailEmbeddedEditingHeader(
      title: _editingTitle(dive),
      canSave: controller.isDirty,
      isSaving: controller.isSaving,
      isBusy: controller.isOperating,
      onCancel: () =>
          isCreating ? _cancelNewDive() : cancelSitting(context, controller),
      onSave: _saveAndReport,
      menu: menu,
    );
  }

  /// The list pane with editing offered: [header] over the strip and
  /// [content], the whole of it in the sitting's scope, so the header's
  /// banners and suggestion follow the lock as the page's do.
  Widget editPane({
    required Widget header,
    required Dive shown,
    required Widget content,
  }) {
    final controller = editController;
    return RecordEditLeaveGuard<Dive>(
      controller: controller,
      child: RecordEditScope<Dive>(
        controller: controller,
        child: Column(
          children: [
            header,
            Expanded(
              child: AddStripLayout(
                strip: _editStrip(controller, shown),
                body: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What lies under the edit bar while the dive is unlocked: the cards it
  /// can add and, when the dive ends after the latest safe surfacing time
  /// for its trip's flight, that warning, pinned as the old edit form
  /// pinned it. Nothing while locked.
  Widget _editStrip(RecordEditController<Dive> controller, Dive shown) {
    final strip = AddStrip(
      entries: controller.isUnlocked ? _addStripEntries(shown) : const [],
      onAdd: controller.addCard,
    );
    if (!controller.isUnlocked) return strip;
    final runtime = shown.runtime;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        strip,
        FlightWindowWarningBanner(
          tripId: shown.tripId,
          // As the form read it: the exit, else entry plus runtime.
          diveEndTime:
              shown.exitTime ??
              (runtime == null ? null : shown.effectiveEntryTime.add(runtime)),
        ),
      ],
    );
  }

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
    // As the section list does: while an editor is open no card comes in,
    // so none leaves the strip. One emptied and closed has left the page,
    // and is offered here again.
    final presence = editController.layoutRecord ?? working;
    // Worked out once: the getter builds a new set each time it is read.
    final changed = editController.session?.changedCardIds ?? const {};
    return [
      for (final section in sections)
        if (diveEditCards[section.id] case final card?)
          // A gauge dive's Cylinders card is offered here too: its own
          // emptiness counts a gauge dive, and its editor is where the mode
          // is changed back (issue #4527, plan 5).
          if (!open.contains(card.id) &&
              ((!diveCardIsOnPage(
                        ref,
                        section.id,
                        layout: presence,
                        working: working,
                        stored: editController.session?.stored,
                        edit: editController,
                      ) &&
                      // A card with nothing to edit until something else
                      // exists stays out, unless the diver hid it.
                      (!section.visible ||
                          editController.session == null ||
                          card.isOfferedWhenEmpty(editController.session!))) ||
                  (!section.visible && !added.contains(card.id))))
            AddStripEntry(
              cardId: card.id,
              label: section.id.localizedDisplayName(l10n),
              hidden: !section.visible,
              changed: changed.contains(card.id),
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
    List<Widget> unlockedActions = const [],
  }) {
    final controller = editController;
    return RecordEditLeaveGuard<Dive>(
      controller: controller,
      child: Scaffold(
        appBar: controller.isUnlocked
            ? RecordEditBar(
                title: _editingTitle(dive),
                canSave: controller.isDirty,
                isSaving: controller.isSaving,
                isBusy: controller.isOperating,
                actions: unlockedActions,
                onCancel: () => isCreating
                    ? _cancelNewDive()
                    : cancelSitting(context, controller),
                onSave: _saveAndReport,
              )
            : lockedBar,
        // The strip comes and goes as the page unlocks and locks, and as
        // cards are added and closed; the page under it stays where it is.
        body: AddStripLayout(
          strip: _editStrip(controller, shown),
          body: RecordEditScope<Dive>(controller: controller, child: content),
        ),
      ),
    );
  }
}
