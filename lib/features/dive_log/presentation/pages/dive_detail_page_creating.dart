part of 'dive_detail_page.dart';

/// A new dive on the dive page (issue #4527, plan 8).
///
/// There is no form: the page opens unlocked on a seed, a dive that exists
/// only in memory under the id it will be created with, holding today's
/// defaults ([newDiveSeed]). The Dive card and the starter cards are laid
/// out open, a prefill goes through the cards' own rules as a change, and
/// every other card waits in the Add strip. Save creates the dive in one
/// transaction ([DiveEditSaveService.create]), runs what a new dive is
/// owed, and moves on to the dive, locked. Cancel leaves, asking first
/// once something was entered.
///
/// The page reads nothing for the dive while it is being created: no
/// stored row, no safety review, no overlay sources. Each of those runs
/// on viewing a stored dive, and the first review writes.
mixin _DiveDetailPageCreating
    on
        ConsumerState<DiveDetailPage>,
        _DiveDetailPageActions,
        _DiveDetailPageEditing {
  /// The page's body for [dive] ([_DiveDetailPageState]).
  Widget _buildContent(BuildContext context, Dive dive);

  /// The dive the sitting starts from, once it has been made.
  Dive? _seed;

  /// The dive as Save created it, shown locked, taking no input, until the
  /// page moves on to it.
  Dive? _created;

  /// The page is leaving without a create (Cancel): nothing opens again.
  bool _leaving = false;

  /// A fresh sitting is asked for after this frame ([buildNewDive]).
  bool _reopenAsked = false;

  /// The scanned pages copied for the dive's sitting. Kept while the
  /// sitting may still write them; removed when it ends without a create.
  final List<String> _photoCopies = [];

  /// A new dive's page, for its whole life: once created, it only moves on.
  @override
  bool get isCreating => widget.newDiveRequest != null;

  @override
  void initState() {
    super.initState();
    if (widget.newDiveRequest != null) _openNewDive();
  }

  @override
  void dispose() {
    // Left without a create. A save still running owns its copies.
    if (_created == null && !(maybeEditController?.isSaving ?? false)) {
      _dropPhotoCopies();
    }
    super.dispose();
  }

  /// Makes the seed and opens the sitting on it, with the starter cards
  /// laid out, then puts the request's prefill on it.
  Future<void> _openNewDive() async {
    final request = widget.newDiveRequest!;
    final container = ProviderScope.containerOf(context, listen: false);
    final seed = await newDiveSeed(
      container.read,
      request,
      newId: () => diveId,
    );
    if (!mounted) return;
    final assignSite = readDiveSiteAssigner(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final photoFailed = context.l10n.ocrImport_newDive_photoHoldFailed;
    setState(() => _seed = seed);
    final controller = editController
      ..unlock(seed, laidOut: newDiveLaidOutCards(request));
    final session = controller.session;
    if (session == null) return;
    applyNewDivePrefill(
      session,
      request,
      assignSite: assignSite,
      readTrip: (id) => container.read(tripRepositoryProvider).getTripById(id),
      readSlots: tripSlotReader(container, seed.id),
      preparePhoto: (file, takenAt) async {
        final prepared = await container
            .read(mediaImportServiceProvider)
            .prepareLocalFileForDive(
              sourceFile: file,
              diveId: seed.id,
              takenAt: takenAt,
            );
        final copy = prepared.item.filePath;
        if (copy != null) {
          if (!mounted || session.isDisposed || session.isFrozen) {
            // Copied after the page or its sitting went, or once Save had
            // stopped waiting for it: the sitting does not take it, so
            // nothing holds it. Only this copy: a fresh sitting may hold
            // one of its own.
            File(copy).delete().ignore();
          } else {
            _photoCopies.add(copy);
          }
        }
        return prepared;
      },
      onPhotoFailed: () =>
          messenger?.showSnackBar(SnackBar(content: Text(photoFailed))),
    );
  }

  /// Removes the scanned pages copied for a sitting that ended without a
  /// create, best effort.
  void _dropPhotoCopies() {
    final copies = [..._photoCopies];
    _photoCopies.clear();
    for (final path in copies) {
      File(path).delete().ignore();
    }
  }

  /// The page of a new dive: loading while the seed is made, the sitting
  /// on it, and the dive once created, locked and taking no input until
  /// the page moves on to it.
  Widget buildNewDive(BuildContext context) {
    final created = _created;
    if (created != null) {
      return AbsorbPointer(
        child: ExcludeFocus(child: _buildContent(context, created)),
      );
    }
    final session = maybeEditController?.session;
    if (session != null) return _buildContent(context, session.stored);
    if (_seed != null && !_leaving) _askReopen();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(context.l10n.diveLog_edit_appBarNew),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  /// The sitting ended without a create while the page stays in view: the
  /// pane's new dive asked for again (the same address), or Back in the
  /// pane, which ends a sitting in place. The page is still a new dive, so
  /// a fresh one opens. A page that is leaving is no longer current by
  /// then, and opens nothing.
  void _askReopen() {
    if (_reopenAsked) return;
    _reopenAsked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reopenAsked = false;
      if (!mounted || _leaving || _created != null) return;
      if (maybeEditController?.isUnlocked ?? false) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      _dropPhotoCopies();
      setState(() => _seed = null);
      _openNewDive();
    });
  }

  /// Cancel, from the bar or Escape: asks when something was entered, then
  /// leaves without creating anything.
  @override
  Future<void> _cancelNewDive() async {
    if (_created != null) return;
    if (!await cancelSitting(context, editController)) return;
    _dropPhotoCopies();
    if (!mounted) return;
    _leaveNewDive();
  }

  void _leaveNewDive() {
    _leaving = true;
    if (widget.embedded) {
      widget.onCreateCancelled?.call();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dives');
    }
  }

  /// Save: creates the dive, runs what a new dive is owed, then moves on
  /// to it. A save that is refused or fails says so, as for any sitting,
  /// and the page stays with everything entered.
  @override
  Future<void> _saveNewDive() async {
    if (_created != null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final controller = editController;
    final afterCreate = NewDiveAfterCreate.read(context, ref);
    final saved = await controller.save();
    if (!saved) {
      if (!mounted) return;
      if (controller.refusedForInvalidInput) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.recordEdit_fixInvalid)),
        );
      } else if (controller.saveError != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.recordEdit_saveFailed)),
        );
      }
      return;
    }
    final created = _created;
    if (created == null) return;
    await afterCreate.run(created: created);
    if (!mounted) return;
    if (widget.embedded) {
      widget.onCreated?.call(created.id);
    } else {
      context.pushReplacement('/dives/${created.id}');
    }
  }

  /// The creating sitting's write: the dive, then everything the sitting
  /// held, in one transaction, then what the list, the site list and the
  /// cards owe a saved sitting ([DiveSittingFollowUp]).
  @override
  Future<void> _createSitting(EditSession<Dive> session) async {
    // Read now: the write may finish after the page has gone.
    final service = ref.read(diveEditSaveServiceProvider);
    final list = ref.read(paginatedDiveListProvider.notifier);
    final writesSites = session.heldKeys
        .difference(diveOwnHeldWriteKeys)
        .isNotEmpty;
    final sites = writesSites
        ? ref.read(siteListNotifierProvider.notifier)
        : null;
    final followUp = DiveSittingFollowUp.read(context, ref);
    // The diver active now, for a seed whose diver could not be read when
    // the page opened: the dive is theirs, and so is its numbering.
    final activeDiver = session.working.diverId == null
        ? ref.read(validatedCurrentDiverIdProvider.future)
        : null;
    final changedCardIds = session.changedCardIds;
    final buddyIds = {
      for (final b in [...?diveBuddiesList.current(session)]) b.buddy.id,
    };
    // A lookup that fails is not guessed past: the save fails, the page
    // stays with everything entered, and Save can be tried again.
    final activeDiverId = activeDiver == null ? null : await activeDiver;
    final result = await undoMediaOnFailure(
      session,
      () => service.create(
        dive: diveSittingApply(session, session.stored),
        changedCardIds: changedCardIds,
        alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
        activeDiverId: activeDiverId,
      ),
    );
    if (mounted) setState(() => _created = result.after);
    // The dive exists from here on. Nothing that follows may read as a
    // failed save: the diver would be handed the sitting to create it again.
    try {
      await list.refreshAfterCreate(result.after);
    } catch (error, stackTrace) {
      _log.error(
        'Refresh after creating dive ${result.after.id} failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    try {
      await sites?.refresh();
    } catch (error, stackTrace) {
      _log.error(
        'Site refresh after creating dive ${result.after.id} failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    try {
      await followUp.run(
        before: session.stored,
        after: result.after,
        tripDateStretches: result.tripDateStretches,
        // A new dive's quality scan, sensor summary and derived metrics have
        // never run: the gear refresh runs them whatever the sitting changed.
        changedCardIds: {...changedCardIds, DiveDetailSectionId.tanks.name},
        mediaAfterCommit: mediaAfterCommit(session),
        buddyIds: buddyIds,
        skippedRouteIds:
            session.recall<List<String>>(routeLinksSkippedKey) ?? const [],
        planLinksAdopted:
            session.recall<List<(String, String?)>>(planLinkAdoptKey) ??
            const [],
      );
    } catch (error, stackTrace) {
      _log.error(
        'Follow-up after creating dive ${result.after.id} failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
