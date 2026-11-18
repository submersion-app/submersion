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
  })
  _editingInBuild() {
    if (!hostsEditing) {
      return (
        hosts: false,
        offered: false,
        site: widget.site,
        shownForSitting: const {},
        heldOpen: const {},
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
    );
  }

  @override
  Iterable<EditCard<DiveSite>> get hostEditCards => siteEditCards.values;

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
    final result = await service.save(
      siteId: siteId,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
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

  /// The cards the diver hid that can be edited, in section order: a card
  /// with nothing to show is never left out (Description and Notes say so).
  /// One brought in from the strip stays on the page while it is open or
  /// has something in it.
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
    return [
      for (final section in sections)
        if (siteEditCards[section.id] case final card?
            when !section.visible &&
                !open.contains(card.id) &&
                !added.contains(card.id))
          AddStripEntry(
            cardId: card.id,
            label: section.id.localizedDisplayName(l10n),
            hidden: true,
            changed: changed.contains(card.id),
          ),
    ];
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
  WidgetBuilder? _framed(
    SiteDetailSectionId id,
    WidgetBuilder? builder, {
    required bool editing,
  }) {
    final card = siteEditCards[id];
    if (!editing || builder == null || card == null) return builder;
    return (context) =>
        RecordCardFrame<DiveSite>(card: card, child: builder(context));
  }
}
