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

  /// The dive as Save created it, shown locked until the page moves on.
  Dive? _created;

  @override
  bool get isCreating => widget.newDiveRequest != null && _created == null;

  @override
  void initState() {
    super.initState();
    if (widget.newDiveRequest != null && editingOffered) _openNewDive();
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
      preparePhoto: (file, takenAt) => container
          .read(mediaImportServiceProvider)
          .prepareLocalFileForDive(
            sourceFile: file,
            diveId: seed.id,
            takenAt: takenAt,
          ),
    );
  }

  /// The page of a new dive: loading while the seed is made, the sitting
  /// on it, the dive locked once created, and nothing while it leaves.
  Widget buildNewDive(BuildContext context) {
    final created = _created;
    if (created != null) return _buildContent(context, created);
    final session = _editController?.session;
    if (session != null) return _buildContent(context, session.stored);
    if (_seed != null || !editingOffered) {
      // The sitting has ended without a create: the page is leaving.
      return widget.embedded ? const SizedBox.shrink() : const Scaffold();
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(context.l10n.diveLog_edit_appBarNew),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  /// Cancel, from the bar or Escape: asks when something was entered, then
  /// leaves without creating anything.
  @override
  Future<void> _cancelNewDive() async {
    if (!await cancelSitting(context, editController)) return;
    if (!mounted) return;
    _leaveNewDive();
  }

  void _leaveNewDive() {
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
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final controller = editController;
    final changed = controller.session?.changedCardIds ?? const <String>{};
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
    await afterCreate.run(created: created, changedCardIds: changed);
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
    final changedCardIds = session.changedCardIds;
    final buddyIds = {
      for (final b in [...?diveBuddiesList.current(session)]) b.buddy.id,
    };
    final result = await undoMediaOnFailure(
      session,
      () => service.create(
        dive: diveSittingApply(session, session.stored),
        changedCardIds: changedCardIds,
        alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
      ),
    );
    if (mounted) setState(() => _created = result.after);
    // The dive exists. A refresh that fails from here on is not a failed
    // save: the diver would be handed the sitting to create it twice.
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
          session.recall<List<(String, String?)>>(planLinkAdoptKey) ?? const [],
    );
  }
}
