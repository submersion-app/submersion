part of 'dive_detail_page.dart';

/// In-place editing for the dive page (issue #4527): what is the dive's own
/// on top of [RecordEditHost], which holds what every record page shares
/// (the lock, the bar, the strip, the leave check, the keys).
///
/// Offered on the full page and in the list pane alike.
mixin _DiveDetailPageEditing
    on ConsumerState<DiveDetailPage>, RecordEditHost<DiveDetailPage, Dive> {
  /// The dive the page shows ([_DiveDetailPageActions.diveId]).
  String get diveId;

  /// What a new dive's page does in place of a stored dive's save and
  /// cancel ([_DiveDetailPageCreating]).
  Future<void> _createSitting(EditSession<Dive> session);
  Future<void> _saveNewDive();
  Future<void> _cancelNewDive();

  /// Tells the page's owner when a sitting opened unlocked has ended
  /// ([_DiveDetailPageUnlockOpen]).
  void _noteSittingEnded();

  @override
  String get hostRecordId => diveId;

  @override
  String recordIdOf(Dive record) => record.id;

  @override
  Iterable<EditCard<Dive>> get hostEditCards => diveEditCards.values;

  // After a whole-record operation: the dive as stored now, read through
  // the provider the page shows, so both agree.
  @override
  Future<Dive?> rereadStored(ProviderContainer container, Dive stored) {
    container.invalidate(diveProvider(stored.id));
    return container.read(diveProvider(stored.id).future);
  }

  @override
  void onSittingStart(EditSession<Dive> session, ProviderContainer container) =>
      startDiveSitting(session, container.read);

  @override
  Dive? get storedForUnlock => ref.read(diveProvider(diveId)).value;

  /// "Log Dive" for a new dive, as the form it replaces is titled (issue
  /// #4527, plan 8), else the dive's own.
  @override
  String editingTitle(Dive dive) => isCreating
      ? context.l10n.diveLog_edit_appBarNew
      : context.l10n.recordEdit_editingTitle(diveTitle(context, dive));

  // In the list pane, not while it gives its place to a site.
  @override
  bool get isShortcutTargetInView => widget.embeddedSiteId?.isEmpty ?? true;

  @override
  Future<void> saveNewRecord() => _saveNewDive();

  @override
  Future<void> cancelNewRecord() => _cancelNewDive();

  /// Where a drop finds the open sitting, read with the controller so it
  /// can still be cleared once the page has gone.
  late final StateController<OpenDiveSitting?> _openSittingSlot = ref.read(
    openDiveSittingProvider.notifier,
  );

  /// The sitting this page last told [openDiveSittingProvider] about.
  EditSession<Dive>? _toldSitting;

  @override
  void onEditChanged() {
    _tellOpenSitting(maybeEditController?.session);
    _noteSittingEnded();
    super.onEditChanged();
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
                maybeEditController?.addCard(DiveDetailSectionId.media.name),
          );
    Future.microtask(() {
      // The app (its provider scope) may have gone with the page.
      if (!slot.mounted) return;
      // Only this page's own: another page may have unlocked since.
      if (open == null && slot.state?.session != told) return;
      slot.state = open;
    });
  }

  @override
  void disposeEditing() {
    _tellOpenSitting(null);
    super.disposeEditing();
  }

  /// The pane showing a site in the dive's place ends the sitting: its link
  /// asked first when there was anything to lose. Another dive ends it too
  /// ([RecordEditHost.didUpdateWidget]).
  @override
  void didUpdateWidget(DiveDetailPage oldWidget) {
    final site = widget.embeddedSiteId;
    if (site != null && site.isNotEmpty && site != oldWidget.embeddedSiteId) {
      maybeEditController?.lock();
    }
    super.didUpdateWidget(oldWidget);
  }

  /// Keeps the sitting on top of the dive as it is stored. Call from
  /// `build`.
  void followStoredDive() => followStored(diveProvider(diveId));

  @override
  Future<void> saveSitting(EditSession<Dive> session) async {
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
    if (result.after.id == diveId) justSavedRecord = result.after;
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

  /// Pinned under the strip while the dive is unlocked: when the dive ends
  /// after the latest safe surfacing time for its trip's flight, that
  /// warning, pinned as the old edit form pinned it.
  @override
  Widget? belowStrip(Dive shown) {
    final runtime = shown.runtime;
    return FlightWindowWarningBanner(
      tripId: shown.tripId,
      // As the form read it: the exit, else entry plus runtime.
      diveEndTime:
          shown.exitTime ??
          (runtime == null ? null : shown.effectiveEntryTime.add(runtime)),
    );
  }

  /// The cards the page is not showing for [working], in section order:
  /// hidden by the diver, or with nothing to show. A card brought in from
  /// the strip counts as shown while it is open or has something in it;
  /// emptied and closed, it is offered again.
  @override
  List<AddStripEntry> addStripEntries(Dive working) {
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
}
