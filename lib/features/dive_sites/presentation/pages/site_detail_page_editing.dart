part of 'site_detail_page.dart';

const _editLog = LoggerService('SiteDetailPage');

/// What a reader's Save turns out to be once the stored role is read.
enum _ReaderSave { refused, edit, send }

/// In-place editing for the site page (issue #4527, phase 2): what is the
/// site's own on top of [RecordEditHost], which holds what every record page
/// shares (the lock, the bar, the strip, the leave check, the keys).
///
/// Offered on the full page and in both list panes, for a site this
/// profile may edit, and to a shared site library's reader, whose sitting
/// suggests changes (plan 5).
mixin _SiteDetailPageEditing
    on
        ConsumerState<_SiteDetailContent>,
        RecordEditHost<_SiteDetailContent, DiveSite> {
  /// Whether this profile may edit [site]: [watch] in `build`, a read
  /// anywhere else.
  bool _canEditSite(WidgetRef ref, DiveSite site, {bool watch = true});

  /// [site]'s library, whether it is connected here and the profile's role
  /// there, a role not read yet counting as a reader's: [watch] in
  /// `build`, a read anywhere else.
  ({bool isLibrary, bool connected, SharedLibraryRole role}) _libraryAccess(
    WidgetRef ref,
    DiveSite site, {
    bool watch = true,
  });

  @override
  String get hostRecordId => widget.siteId;

  @override
  String recordIdOf(DiveSite record) => record.id;

  /// For a site this profile may edit now, or suggest
  /// changes to as a library's reader. [watch] in `build`, a read anywhere
  /// else.
  bool _offersEditingNow({bool watch = false}) =>
      (_canEditSite(ref, widget.site, watch: watch) ||
      _readerMaySuggest(watch: watch));

  /// Whether this profile is a reader of the site's library, connected
  /// here, with the role settled: a role still loading offers nothing yet,
  /// rather than a reader's unlock to an editor.
  bool _readerMaySuggest({bool watch = false}) {
    if (!_libraryAccessSettled(watch: watch)) return false;
    final access = _libraryAccess(ref, widget.site, watch: watch);
    return access.isLibrary &&
        access.connected &&
        canSuggestOnLibrarySite(access.role);
  }

  /// Whether the page offers a reader's sitting now, not an editor's.
  bool _suggestsNow({bool watch = false}) =>
      !_canEditSite(ref, widget.site, watch: watch) &&
      _readerMaySuggest(watch: watch);

  /// Whether the page shows a reader's sitting now: the open sitting a
  /// reader's while this profile may not edit the site, or, while locked,
  /// a page that offers a reader's unlock. A reader's sitting that finds
  /// the profile an editor shows an editor's page (plan 5, Question 2).
  bool _readerPageNow({bool watch = false}) {
    final session = maybeEditController?.session;
    if (session == null) return _suggestsNow(watch: watch);
    return isReaderSitting(session) &&
        !_canEditSite(ref, widget.site, watch: watch);
  }

  /// Whether the open sitting may go on: an editor's while the profile may
  /// still edit, a reader's while the page offers any. An editor's sitting
  /// may hold what a reader cannot send (features, expected species), so
  /// a role that drops to reader withdraws it (plan 5, Question 2); so it
  /// does a reader's sitting that changed one of those while it could edit.
  bool _sittingAllowedNow({bool watch = false}) {
    final session = maybeEditController?.session;
    if (_canEditSite(ref, widget.site, watch: watch)) {
      return true;
    }
    return session != null &&
        isReaderSitting(session) &&
        !readerSittingHoldsLibraryChange(session) &&
        _offersEditingNow(watch: watch);
  }

  @override
  bool get offersEditing => _offersEditingNow();

  /// What `build` needs of the sitting: whether the page [offered] editing
  /// now, the [site] to show (the diver's working copy
  /// during a sitting, or the site just saved), the hidden sections the
  /// sitting brought onto the page, and the sections it holds unfolded.
  ///
  /// A sitting the page can no longer offer (the library role taken away,
  /// the library disconnected) is ended: nothing on the page could save it
  /// any more, and the app would still ask about it on the way out.
  ({
    bool offered,
    DiveSite site,
    Set<SiteDetailSectionId> shownForSitting,
    Set<SiteDetailSectionId> heldOpen,
    DiveSite? presence,
  })
  _editingInBuild() {
    final offered = _offersEditingNow(watch: true);
    if (isSittingOpen &&
        !_sittingAllowedNow(watch: true) &&
        _libraryAccessSettled(watch: true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _endWithdrawn());
    }
    if (_libraryCardsOpen().isNotEmpty &&
        _readerPageNow(watch: true) &&
        _libraryAccessSettled(watch: true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _closeLibraryCards());
    }
    followStored(siteProvider(widget.siteId));
    return (
      offered: offered,
      site: shownRecord(widget.site),
      shownForSitting: _sectionsShownForSitting(),
      heldOpen: _sectionsOpenForSitting(),
      // While an editor is open, the record the page lays itself out from.
      presence: maybeEditController?.layoutRecord,
    );
  }

  /// Whether what decides the right to edit has settled: a library's
  /// connection and this profile's role in it, read and not being read
  /// again. A reload, or one that fails, says nothing of a lost right, so
  /// it never ends a sitting; a settled answer that refuses does. [watch]
  /// in `build`, a read anywhere else.
  bool _libraryAccessSettled({bool watch = false}) {
    final id = widget.site.sharedLibraryId;
    if (id == null) return true;
    bool settled(AsyncValue<Object?> value) =>
        value.hasValue && !value.isLoading && !value.hasError;
    return settled(
          watch
              ? ref.watch(libraryConnectedHereProvider(id))
              : ref.read(libraryConnectedHereProvider(id)),
        ) &&
        settled(
          watch
              ? ref.watch(libraryRoleProvider(id))
              : ref.read(libraryRoleProvider(id)),
        );
  }

  /// Where a file dropped on the window finds this page (issue #4527),
  /// read in [initState] so it can still be cleared once the page has gone.
  StateController<SiteEditingPage?>? _dropSlot;

  /// What this page last told [siteEditingPageProvider].
  SiteEditingPage? _toldDrop;

  @override
  void initState() {
    super.initState();
    _dropSlot = ref.read(siteEditingPageProvider.notifier);
    _tellDrop();
  }

  @override
  void onEditChanged() {
    _tellDrop();
    super.onEditChanged();
  }

  @override
  void disposeEditing() {
    _tellDrop(gone: true);
    super.disposeEditing();
  }

  /// Tells a drop that this page edits [widget]'s site in place, with its
  /// sitting while unlocked, or that the page has gone. Set after the
  /// frame's work, since a lock can come while the page is being built.
  void _tellDrop({bool gone = false}) {
    final slot = _dropSlot;
    if (slot == null) return;
    final told = _toldDrop;
    final session = gone ? null : maybeEditController?.session;
    if (!gone &&
        told != null &&
        told.siteId == widget.siteId &&
        identical(told.session, session)) {
      return;
    }
    final page = gone
        ? null
        : SiteEditingPage(
            siteId: widget.siteId,
            session: session,
            showMediaCard: () =>
                maybeEditController?.addCard(SiteDetailSectionId.media.name),
          );
    _toldDrop = page;
    Future.microtask(() {
      // The app (its provider scope) may have gone with the page.
      if (!slot.mounted) return;
      // Only this page's own: another page may have told since.
      if (page == null && !identical(slot.state, told)) return;
      slot.state = page;
    });
  }

  /// Ends a sitting this profile may no longer save, and says so: the
  /// diver's typing goes with it. A save still running ends it once it
  /// returns, and the page is built, and asks, again then.
  void _endWithdrawn() {
    final controller = maybeEditController;
    if (!mounted || controller == null || _sittingAllowedNow()) return;
    if (!controller.isUnlocked || !_libraryAccessSettled()) return;
    controller.lock();
    if (controller.isUnlocked) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.diveSites_edit_editingWithdrawn)),
    );
  }

  /// The library's cards open in the sitting (features, expected species)
  /// that would close: one holding input that cannot be read stays open
  /// ([RecordEditController.closeCard]), and is not asked again each frame.
  Iterable<String> _libraryCardsOpen() {
    final controller = maybeEditController;
    if (controller == null) return const [];
    final invalid = controller.invalidCardIds;
    return controller.openCardIds.where(
      (id) =>
          siteReaderCardRule(id) == SiteReaderCard.library &&
          !invalid.contains(id),
    );
  }

  /// Closes the library's cards a reader's page has open: opened while the
  /// profile could edit, they are drawn with no editor now, and one left
  /// open would hold the page's layout for the rest of the sitting.
  void _closeLibraryCards() {
    final controller = maybeEditController;
    if (!mounted || controller == null) return;
    if (!_readerPageNow() || !_libraryAccessSettled()) return;
    for (final id in _libraryCardsOpen().toList()) {
      controller.closeCard(id);
    }
  }

  // The header block is a card too, though not a section: its check (a
  // name is required) is asked at Save like every other card's.
  @override
  Iterable<EditCard<DiveSite>> get hostEditCards => [
    siteHeaderCard,
    ...siteEditCards.values,
  ];

  @override
  void onSittingStart(
    EditSession<DiveSite> session,
    ProviderContainer container,
  ) {
    if (_suggestsNow()) markReaderSitting(session);
    startSiteSitting(session, container.read);
  }

  @override
  DiveSite? get storedForUnlock => ref.read(siteProvider(widget.siteId)).value;

  @override
  String editingTitle(DiveSite site) => _readerPageNow()
      ? context.l10n.sharedLibrary_suggest_title
      : context.l10n.recordEdit_editingTitle(site.name);

  @override
  String? get saveLabel =>
      _readerPageNow() ? context.l10n.sharedLibrary_suggest_send : null;

  // After a whole-record operation: the site as stored now, read through
  // the provider the page shows, so both agree.
  @override
  Future<DiveSite?> rereadStored(ProviderContainer container, DiveSite stored) {
    container.invalidate(siteProvider(stored.id));
    return container.read(siteProvider(stored.id).future);
  }

  /// A reader's sitting on a library site: the role as stored now decides,
  /// read again once a note is written ([_readerSaveNow]). An editor's role
  /// saves as an edit; anyone else's is a Send, held on the sitting for
  /// [saveSitting], which asks for a note only when something goes to the
  /// owner. An editor's sitting is never sent: one
  /// whose role has dropped is withdrawn, not sent (plan 5, Question 2). A
  /// demo profile, a role that cannot be read, or a library no longer
  /// connected here, saves nothing.
  ///
  /// The Send held by an attempt that did not go through stays held until
  /// this decides again, so its note is offered to the next one; a save
  /// decided not to be a Send clears it.
  @override
  Future<bool> beforeSave() async {
    final session = maybeEditController?.session;
    if (session == null) return true;
    final libraryId = session.stored.sharedLibraryId;
    if (libraryId == null || !isReaderSitting(session)) {
      clearReaderSend(session);
      return true;
    }
    // As the suggestion form did: a demo profile is told so.
    if (!demoSealGuard(context, DemoSealedFeature.sharedLibrary)) {
      return false;
    }
    var path = await _readerSaveNow(session, libraryId);
    if (!mounted) return false;
    var note = '';
    if (path == _ReaderSave.send && readerSendProposes(session)) {
      final asked = await askSuggestionNote(
        context,
        initial: readerSendNote(session) ?? '',
      );
      if (asked == null || !mounted) return false;
      note = asked;
      // The note is the diver's to take their time over: the role as
      // stored once it is written decides.
      path = await _readerSaveNow(session, libraryId);
      if (!mounted) return false;
    }
    switch (path) {
      case _ReaderSave.refused:
        // Kept for the next attempt, which decides again.
        if (note.isNotEmpty) holdReaderSend(session, note);
        return false;
      case _ReaderSave.edit:
        clearReaderSend(session);
        return true;
      case _ReaderSave.send:
        holdReaderSend(session, note);
        return true;
    }
  }

  /// What the role as stored now makes of a reader's Save on [libraryId]:
  /// an edit for an editor's role, a Send for anyone else's, or refused,
  /// and said so, when the role cannot be read or the library is no longer
  /// connected here (no role to save or suggest as).
  Future<_ReaderSave> _readerSaveNow(
    EditSession<DiveSite> session,
    String libraryId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final SharedLibraryRole? role;
    try {
      role = await libraryRoleNow(ref.read, libraryId);
    } catch (error, stackTrace) {
      _editLog.error(
        'Reading the library role at a reader\'s Send on '
        '${session.stored.id} failed',
        error: error,
        stackTrace: stackTrace,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.recordEdit_saveFailed)),
      );
      return _ReaderSave.refused;
    }
    if (role == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveSites_edit_saveRefused)),
      );
      return _ReaderSave.refused;
    }
    return canEditLibrarySite(role) ? _ReaderSave.edit : _ReaderSave.send;
  }

  @override
  Future<void> saveSitting(EditSession<DiveSite> session) async {
    final sendNote = readerSendNote(session);
    if (sendNote != null) return _sendReaderSitting(session, sendNote);
    // Read now: the write may finish after the page has gone.
    final service = ref.read(siteEditSaveServiceProvider);
    final sites = ref.read(siteListNotifierProvider.notifier);
    final actingDiver = ref.read(validatedCurrentDiverIdProvider.future);
    final siteId = session.stored.id;
    final shownId = widget.siteId;
    final result = await saveSiteSitting(
      session,
      service,
      actingDiverId: await actingDiver,
    );
    if (result == null) return;
    if (result.after.id == shownId) justSavedRecord = result.after;
    await _refreshSiteList(sites, siteId);
  }

  /// The site list read again once a write on [siteId] has committed. A
  /// refresh that fails must not read as a save that failed: the diver would
  /// be told nothing was changed and handed the sitting to save a second
  /// time.
  Future<void> _refreshSiteList(SiteListNotifier sites, String siteId) async {
    try {
      await sites.refresh();
    } catch (error, stackTrace) {
      _editLog.error(
        'Site list refresh after saving site $siteId failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// A library reader's Send: their own changes written, the rest proposed
  /// with [note], and the snack bar saying which.
  Future<void> _sendReaderSitting(
    EditSession<DiveSite> session,
    String note,
  ) async {
    // Read now: the write may finish after the page has gone.
    final service = ref.read(siteEditSaveServiceProvider);
    final suggestions = ref.read(suggestionServiceProvider);
    final sites = ref.read(siteListNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final shownId = widget.siteId;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) throw StateError('no profile to send as');
    final result = await sendReaderSitting(
      session,
      service: service,
      suggestions: suggestions,
      diverId: diverId,
      note: note,
    );
    final saved = result.saved;
    if (saved != null && saved.id == shownId) justSavedRecord = saved;
    if (saved != null) await _refreshSiteList(sites, saved.id);
    final message = switch (result.outcome) {
      SiteReaderSent.sent => l10n.sharedLibrary_suggest_sent,
      SiteReaderSent.savedPrivate => l10n.sharedLibrary_suggest_savedPrivate,
      SiteReaderSent.nothingChanged =>
        l10n.sharedLibrary_suggest_nothingChanged,
      // The sitting stays, holding the suggestion to send again; the save
      // says so, as it does any refusal.
      SiteReaderSent.savedPrivateNotSent => throw RecordSittingRefusal(
        (l10n) => l10n.sharedLibrary_suggest_savedNotSent,
      ),
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// The cards the page is not showing that can be edited, in section
  /// order: hidden by the diver, or with nothing to show. One brought in
  /// from the strip stays on the page while it is open or has something in
  /// it; emptied and closed, it is offered here again.
  @override
  List<AddStripEntry> addStripEntries(DiveSite working) {
    final sections = ref.watch(
      settingsProvider.select((s) => s.siteDetailSections),
    );
    final l10n = context.l10n;
    final controller = editController;
    final open = controller.openCardIds;
    final added = controller.addedCardIds;
    final changed = controller.session?.changedCardIds ?? const <String>{};
    final session = controller.session;
    // A reader's sitting changes none of the library's cards.
    final reader = _readerPageNow(watch: true);
    // As the page lays itself out: while an editor is open no card comes in,
    // so none leaves the strip either.
    final presence = controller.layoutRecord ?? working;
    return [
      for (final section in sections)
        if (siteEditCards[section.id] case final card?
            when !open.contains(card.id) &&
                !added.contains(card.id) &&
                !(reader &&
                    siteReaderCardRule(card.id) == SiteReaderCard.library) &&
                (!section.visible ||
                    // Neither open nor added (above): on a new site it
                    // waits here ([_waitsInStrip]).
                    ((card.isEmptyDuring(presence, session) || isCreating) &&
                        (session == null || card.isOfferedWhenEmpty(session)))))
          AddStripEntry(
            cardId: card.id,
            label: section.id.localizedDisplayName(l10n),
            hidden: !section.visible,
            changed: changed.contains(card.id),
          ),
    ];
  }

  /// Whether [cardId] waits in the strip on a new site: one the new site
  /// did not lay out and the diver has not added, even a card a stored
  /// site always shows (Description, Rating), since every card but the
  /// starter set is a chip there (plan 6).
  bool _waitsInStrip(String cardId) {
    if (!isCreating) return false;
    final controller = maybeEditController;
    if (controller == null) return true;
    return !controller.openCardIds.contains(cardId) &&
        !controller.addedCardIds.contains(cardId);
  }

  /// [list] as the sitting has it, once the diver has changed it; null
  /// while it is as stored, or with no sitting, so the card reads its own.
  List<E>? _heldList<E>(SittingList<DiveSite, E> list) {
    final session = maybeEditController?.session;
    if (session == null || !list.isChanged(session)) return null;
    return list.current(session);
  }

  /// "Shared with" under the header, for the owner of a site shared with
  /// other profiles (issue #4527, phase 2), offered where the header
  /// block's editor offers sharing: never on a library site, and only with
  /// two or more divers. While the header block is open its editor shows
  /// the field instead.
  Widget? _sharedWithLine(BuildContext context, DiveSite site) {
    if (site.isLibrarySite) return null;
    final controller = maybeEditController;
    if (controller?.openCardIds.contains(siteHeaderCardId) ?? false) {
      return null;
    }
    final divers = ref.watch(allDiversProvider).value ?? const [];
    if (divers.length < 2) return null;
    final isOwner = canDestroySharedItemOnceKnown(
      ref.watch(validatedCurrentDiverIdProvider),
      ownerId: site.diverId,
    );
    if (isOwner != true) return null;
    final session = controller?.session;
    final sharing =
        (session == null ? null : siteSharing.inSitting(session)) ??
        ref
            .watch(
              itemSharingProvider((kind: SharedItemKind.site, id: site.id)),
            )
            .value;
    if (sharing == null || !sharing.isShared) return null;
    return SharingTile(
      summary: sharingSummary(sharing, {
        for (final d in divers) d.id: d.name,
      }, context.l10n),
    );
  }

  /// Whether the sitting holds a Review of the catalogue offer.
  bool _catalogueReviewed() {
    final session = maybeEditController?.session;
    return session != null && siteCatalogueReviewed(session);
  }

  /// The sections whose cards are open, held unfolded in the list layout.
  Set<SiteDetailSectionId> _sectionsOpenForSitting() {
    final open = maybeEditController?.openCardIds ?? const <String>{};
    return {
      for (final id in SiteDetailSectionId.values)
        if (open.contains(id.name)) id,
    };
  }

  /// The pencil on [id]'s folded row in the list layout while the site is
  /// unlocked and its card can be edited and is not open; null otherwise,
  /// and for the library's cards on a reader's page.
  Widget? _foldPencil(SiteDetailSectionId id) {
    final controller = maybeEditController;
    final session = controller?.session;
    if (controller == null || session == null) return null;
    if (!siteEditCards.containsKey(id)) return null;
    if (controller.openCardIds.contains(id.name)) return null;
    if (siteReaderCardRule(id.name) == SiteReaderCard.library &&
        _readerPageNow()) {
      return null;
    }
    return RecordFoldPencil(
      title: id.localizedDisplayName(context.l10n),
      // Open, the card's own header carries the dot.
      isChanged: session.changedCardIds.contains(id.name),
      onOpen: () => controller.openCard(id.name),
    );
  }

  /// [build] for a card shown only when it has something, by its card's own
  /// rule ([EditCard.isEmpty]): left out when the record the page lays
  /// itself out from has nothing, and, while an editor is open, held as its
  /// title alone when the sitting has emptied it ([_heldEmptyCard]), so no
  /// card comes or goes above the editor.
  WidgetBuilder? _shownWhileLaidOut(
    SiteDetailSectionId id, {
    required DiveSite laidOut,
    required DiveSite site,
    required WidgetBuilder build,
  }) {
    final card = siteEditCards[id]!;
    if (card.isEmpty(laidOut)) return null;
    if (card.isEmpty(site)) return (context) => _heldEmptyCard(context, id);
    return build;
  }

  /// A card held on the page while an editor is open although the sitting
  /// has emptied it: its title alone, until the editors close and it leaves
  /// for the Add strip (issue #4527).
  Widget _heldEmptyCard(BuildContext context, SiteDetailSectionId id) {
    final card = siteEditCards[id]!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: RecordCardHeader(
          title: card.title(context),
          leading: card.leading?.call(context),
        ),
      ),
    );
  }

  /// The hidden sections the sitting has brought onto the page.
  Set<SiteDetailSectionId> _sectionsShownForSitting() {
    final controller = maybeEditController;
    if (controller == null || !controller.isUnlocked) return const {};
    final ids = {...controller.addedCardIds, ...controller.openCardIds};
    return {
      for (final id in SiteDetailSectionId.values)
        if (ids.contains(id.name)) id,
    };
  }

  /// [builder] framed as its card, so unlocking never remounts it; as it
  /// is for a section with no card.
  ///
  /// A card that can be edited is on the page while it is open, and
  /// otherwise when [builder] has something to show (decided from the
  /// record the page lays itself out from, `_sectionCards`'s `presence`).
  /// Open with nothing to show, it gets an empty body, which the frame
  /// replaces with its editor. A card worked out from other values fades
  /// while unlocked.
  ///
  /// [readerPage] is [_readerPageNow] for this build, asked once for all
  /// the cards.
  WidgetBuilder? _framed(
    SiteDetailSectionId id,
    WidgetBuilder? builder, {
    required bool readerPage,
  }) {
    final card = siteEditCards[id];
    if (card == null) {
      // Worked out from the site's dives and position: nothing until the
      // site exists (plan 6).
      if (isCreating) return null;
      if (builder == null || !kSiteCalculatedSections.contains(id)) {
        return builder;
      }
      return (context) => RecordCardFade<DiveSite>(
        reason: RecordCardFadeReason.calculated,
        child: builder(context),
      );
    }
    if (_waitsInStrip(card.id)) return null;
    // A library reader's page (plan 5): the library's cards fade with no
    // pencil, and the reader's own say so. While locked the page decides,
    // so unlocking never remounts a card; while unlocked the sitting does,
    // so a reload of the role keeps the reader's framing.
    final rule = readerPage
        ? siteReaderCardRule(card.id)
        : SiteReaderCard.suggested;
    if (rule == SiteReaderCard.library) {
      if (builder == null) return null;
      return (context) => RecordCardFade<DiveSite>(
        reason: RecordCardFadeReason.library,
        child: builder(context),
      );
    }
    final isOpen = maybeEditController?.openCardIds.contains(card.id) ?? false;
    if (!isOpen && builder == null) return null;
    final body = builder ?? (_) => const SizedBox.shrink();
    // The reader's own cards say so. Every card keeps the one shape, so a
    // role that changes mid-sitting never rebuilds an open card's editor.
    final private = rule == SiteReaderCard.private;
    return (context) => RecordCardEdgeLabel<DiveSite>(
      label: private ? context.l10n.recordEdit_onlyYou : null,
      child: RecordCardFrame<DiveSite>(card: card, child: body(context)),
    );
  }
}

/// The site cards worked out from other data (the dives logged here, the
/// tide and terrain at the position, the reef's state): nothing to edit, so
/// they fade while the page is unlocked.
const kSiteCalculatedSections = {
  SiteDetailSectionId.diveStatistics,
  SiteDetailSectionId.divePhotos,
  SiteDetailSectionId.tide,
  SiteDetailSectionId.seascape,
  SiteDetailSectionId.reefHealth,
};
