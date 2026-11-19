part of 'site_detail_page.dart';

const _editLog = LoggerService('SiteDetailPage');

/// In-place editing for the site page (issue #4527, phase 2): what is the
/// site's own on top of [RecordEditHost], which holds what every record page
/// shares (the lock, the bar, the strip, the leave check, the keys).
///
/// Offered behind [kUnlockSiteEditing], on the full page and in both list
/// panes, for a site this profile may edit, and to a shared site library's
/// reader, whose sitting suggests changes (plan 5).
mixin _SiteDetailPageEditing
    on
        ConsumerState<_SiteDetailContent>,
        RecordEditHost<_SiteDetailContent, DiveSite> {
  /// Whether this profile may edit [site]: [watch] in `build`, a read
  /// anywhere else.
  bool _canEditSite(WidgetRef ref, DiveSite site, {bool watch = true});

  @override
  String get hostRecordId => widget.siteId;

  @override
  String recordIdOf(DiveSite record) => record.id;

  /// The switch on, on the full page and in a pane alike: the page keeps
  /// the editing shape for its whole life, so a role that loads or changes
  /// never remounts it.
  @override
  bool get hostsEditing => widget.unlockEditing;

  /// [hostsEditing], for a site this profile may edit now, or suggest
  /// changes to as a library's reader. [watch] in `build`, a read anywhere
  /// else.
  bool _offersEditingNow({bool watch = false}) =>
      hostsEditing &&
      (_canEditSite(ref, widget.site, watch: watch) ||
          _readerMaySuggest(watch: watch));

  /// Whether this profile is a reader of the site's library, connected
  /// here, with the role settled: a role still loading offers nothing yet,
  /// rather than a reader's unlock to an editor.
  bool _readerMaySuggest({bool watch = false}) {
    final id = widget.site.sharedLibraryId;
    if (id == null || !_libraryAccessSettled(watch: watch)) return false;
    final connected =
        (watch
                ? ref.watch(libraryConnectedHereProvider(id))
                : ref.read(libraryConnectedHereProvider(id)))
            .value ??
        false;
    final role =
        (watch
                ? ref.watch(libraryRoleProvider(id))
                : ref.read(libraryRoleProvider(id)))
            .value;
    return connected && role != null && canSuggestOnLibrarySite(role);
  }

  /// Whether the page offers a reader's sitting now, not an editor's.
  bool _suggestsNow({bool watch = false}) =>
      hostsEditing &&
      !_canEditSite(ref, widget.site, watch: watch) &&
      _readerMaySuggest(watch: watch);

  /// Whether the open sitting may go on: a reader's while the page offers
  /// any, an editor's while the profile may still edit. An editor's sitting
  /// may hold what a reader cannot send (features, expected species), so
  /// a role that drops to reader withdraws it (plan 5, Question 2).
  bool _sittingAllowedNow({bool watch = false}) =>
      isReaderSitting(maybeEditController?.session)
      ? _offersEditingNow(watch: watch)
      : hostsEditing && _canEditSite(ref, widget.site, watch: watch);

  @override
  bool get offersEditing => _offersEditingNow();

  /// What `build` needs of the sitting: whether the page [hosts] editing
  /// and [offered] it now, the [site] to show (the diver's working copy
  /// during a sitting, or the site just saved), the hidden sections the
  /// sitting brought onto the page, and the sections it holds unfolded.
  ///
  /// A sitting the page can no longer offer (the library role taken away,
  /// the library disconnected) is ended: nothing on the page could save it
  /// any more, and the app would still ask about it on the way out.
  ({
    bool hosts,
    bool offered,
    DiveSite site,
    Set<SiteDetailSectionId> shownForSitting,
    Set<SiteDetailSectionId> heldOpen,
    DiveSite? presence,
  })
  _editingInBuild() {
    if (!hostsEditing) {
      return (
        hosts: false,
        offered: false,
        site: widget.site,
        shownForSitting: const {},
        heldOpen: const {},
        presence: null,
      );
    }
    final offered = _offersEditingNow(watch: true);
    if (isSittingOpen &&
        !_sittingAllowedNow(watch: true) &&
        _libraryAccessSettled(watch: true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _endWithdrawn());
    }
    followStored(siteProvider(widget.siteId));
    return (
      hosts: true,
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
    if (!hostsEditing) return;
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
  String editingTitle(DiveSite site) =>
      isReaderSitting(maybeEditController?.session)
      ? context.l10n.sharedLibrary_suggest_title
      : context.l10n.recordEdit_editingTitle(site.name);

  @override
  String? get saveLabel => isReaderSitting(maybeEditController?.session)
      ? context.l10n.sharedLibrary_suggest_send
      : null;

  // After a whole-record operation: the site as stored now, read through
  // the provider the page shows, so both agree.
  @override
  Future<DiveSite?> rereadStored(ProviderContainer container, DiveSite stored) {
    container.invalidate(siteProvider(stored.id));
    return container.read(siteProvider(stored.id).future);
  }

  /// Whether the next save is a library reader's Send, and the note it
  /// carries to the owner, decided by [beforeSave] (plan 5).
  bool _sendAtSave = false;
  String _sendNote = '';

  /// On a library site the role as stored now decides, however the sitting
  /// was opened: an editor's save edits, anyone else's is a Send, which
  /// asks for a note only when something goes to the owner.
  @override
  Future<bool> beforeSave() async {
    _sendAtSave = false;
    _sendNote = '';
    final session = maybeEditController?.session;
    final libraryId = widget.site.sharedLibraryId;
    if (session == null || libraryId == null) return true;
    final role = await libraryRoleNow(ref.read, libraryId);
    if (!mounted) return false;
    if (role != null && canEditLibrarySite(role)) return true;
    if (readerSendProposes(session)) {
      final note = await askSuggestionNote(context);
      if (note == null || !mounted) return false;
      _sendNote = note;
    }
    _sendAtSave = true;
    return true;
  }

  @override
  Future<void> saveSitting(EditSession<DiveSite> session) async {
    if (_sendAtSave) return _sendReaderSitting(session);
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
    // The write is committed. A refresh that fails from here on must not
    // read as a save that failed: the diver would be told nothing was
    // changed and handed the sitting to save a second time.
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

  /// A library reader's Send: their own changes written, the rest proposed,
  /// and the snack bar saying which.
  Future<void> _sendReaderSitting(EditSession<DiveSite> session) async {
    // Read now: the write may finish after the page has gone.
    final service = ref.read(siteEditSaveServiceProvider);
    final suggestions = ref.read(suggestionServiceProvider);
    final sites = ref.read(siteListNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) throw StateError('no profile to send as');
    final note = _sendNote;
    _sendAtSave = false;
    final result = await sendReaderSitting(
      session,
      service: service,
      suggestions: suggestions,
      diverId: diverId,
      note: note,
    );
    final saved = result.saved;
    if (saved != null && saved.id == widget.siteId) justSavedRecord = saved;
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (result.outcome) {
          SiteReaderSent.sent => l10n.sharedLibrary_suggest_sent,
          SiteReaderSent.savedPrivate =>
            l10n.sharedLibrary_suggest_savedPrivate,
          SiteReaderSent.nothingChanged =>
            l10n.sharedLibrary_suggest_nothingChanged,
        }),
      ),
    );
    if (saved == null) return;
    // Committed: a refresh that fails must not read as a failed Send.
    try {
      await sites.refresh();
    } catch (error, stackTrace) {
      _editLog.error(
        'Site list refresh after a reader\'s Send on ${session.stored.id} '
        'failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
    final reader = isReaderSitting(session);
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
                    (card.isEmptyDuring(presence, session) &&
                        (session == null || card.isOfferedWhenEmpty(session)))))
          AddStripEntry(
            cardId: card.id,
            label: section.id.localizedDisplayName(l10n),
            hidden: !section.visible,
            changed: changed.contains(card.id),
          ),
    ];
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
        (session == null ? null : siteSharingInSitting(session)) ??
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
  /// unlocked and its card can be edited and is not open; null otherwise.
  Widget? _foldPencil(SiteDetailSectionId id) {
    final controller = maybeEditController;
    final session = controller?.session;
    if (controller == null || session == null) return null;
    if (!siteEditCards.containsKey(id)) return null;
    if (controller.openCardIds.contains(id.name)) return null;
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

  /// [builder] framed as its card while the page offers editing, so
  /// unlocking never remounts it; as it is otherwise, and for a section
  /// with no card.
  ///
  /// A card that can be edited is on the page while it is open, and
  /// otherwise when [builder] has something to show (decided from the
  /// record the page lays itself out from, `_sectionCards`'s `presence`).
  /// Open with nothing to show, it gets an empty body, which the frame
  /// replaces with its editor. A card worked out from other values fades
  /// while unlocked.
  WidgetBuilder? _framed(
    SiteDetailSectionId id,
    WidgetBuilder? builder, {
    required bool editing,
  }) {
    if (!editing) return builder;
    final card = siteEditCards[id];
    if (card == null) {
      if (builder == null || !kSiteCalculatedSections.contains(id)) {
        return builder;
      }
      return (context) => RecordCardFade<DiveSite>(
        reason: RecordCardFadeReason.calculated,
        child: builder(context),
      );
    }
    // A library reader's page (plan 5): the library's cards fade with no
    // pencil, and the reader's own say so. Decided by the page, not the
    // sitting, so unlocking never remounts a card.
    final rule = _suggestsNow(watch: true)
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
    if (rule == SiteReaderCard.private) {
      return (context) => RecordCardEdgeLabel<DiveSite>(
        label: context.l10n.recordEdit_onlyYou,
        child: RecordCardFrame<DiveSite>(card: card, child: body(context)),
      );
    }
    return (context) =>
        RecordCardFrame<DiveSite>(card: card, child: body(context));
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
