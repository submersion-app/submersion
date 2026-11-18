part of 'site_detail_page.dart';

const _editLog = LoggerService('SiteDetailPage');

/// In-place editing for the site page (issue #4527, phase 2): what is the
/// site's own on top of [RecordEditHost], which holds what every record page
/// shares (the lock, the bar, the strip, the leave check, the keys).
///
/// Offered behind [kUnlockSiteEditing], on the full page, for a site this
/// profile may edit. The list pane and a library reader's suggestions come
/// in later plans.
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

  /// The switch on, on the full page: the page keeps the editing shape
  /// for its whole life, so a role that loads or changes never remounts it.
  @override
  bool get hostsEditing => widget.unlockEditing && !widget.embedded;

  /// [hostsEditing], for a site this profile may edit now. [watch] in
  /// `build`, a read anywhere else.
  bool _offersEditingNow({bool watch = false}) =>
      hostsEditing && _canEditSite(ref, widget.site, watch: watch);

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
    if (!offered && isSittingOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !offersEditing) maybeEditController?.lock();
      });
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
  ) => startSiteSitting(session, container.read);

  @override
  DiveSite? get storedForUnlock => ref.read(siteProvider(widget.siteId)).value;

  @override
  String editingTitle(DiveSite site) =>
      context.l10n.recordEdit_editingTitle(site.name);

  // After a whole-record operation: the site as stored now, read through
  // the provider the page shows, so both agree.
  @override
  Future<DiveSite?> rereadStored(ProviderContainer container, DiveSite stored) {
    container.invalidate(siteProvider(stored.id));
    return container.read(siteProvider(stored.id).future);
  }

  @override
  Future<void> saveSitting(EditSession<DiveSite> session) async {
    // Read now: the write may finish after the page has gone.
    final service = ref.read(siteEditSaveServiceProvider);
    final sites = ref.read(siteListNotifierProvider.notifier);
    final actingDiver = ref.read(validatedCurrentDiverIdProvider.future);
    final siteId = session.stored.id;
    final shownId = widget.siteId;
    final diverId = await actingDiver;
    // Noted afresh by this attempt's held writes.
    clearSiteLibraryFields(session);
    // A write that does not commit takes back what the sitting's media
    // write did outside the database.
    final result = await undoMediaOnFailure(
      session,
      () => service.save(
        siteId: siteId,
        apply: session.applyTo,
        changedCardIds: session.changedCardIds,
        actingDiverId: diverId,
        writeFirst: session.hasHeldWritesBeforeRecord
            ? () => session.runHeldWrites(beforeRecord: true)
            : null,
        alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
        alsoWriteIsAChange: session.hasHeldChanges,
        heldLibraryFields: () => siteLibraryFields(session),
      ),
    );
    if (result == null) return;
    if (result.after.id == shownId) justSavedRecord = result.after;
    // What the sitting's media write left for after the commit: uploads,
    // the remote deletes its unlinks held. Each on its own, guarded.
    for (final step in mediaAfterCommit(session)) {
      try {
        await step();
      } catch (error, stackTrace) {
        _editLog.error(
          'Media follow-up after saving site $siteId failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
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
    // As the page lays itself out: while an editor is open no card comes in,
    // so none leaves the strip either.
    final presence = controller.layoutRecord ?? working;
    return [
      for (final section in sections)
        if (siteEditCards[section.id] case final card?
            when !open.contains(card.id) &&
                !added.contains(card.id) &&
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
    final isOpen = maybeEditController?.openCardIds.contains(card.id) ?? false;
    if (!isOpen && builder == null) return null;
    final body = builder ?? (_) => const SizedBox.shrink();
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
