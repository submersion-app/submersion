part of 'site_detail_page.dart';

final _editLog = LoggerService.forClass(SiteEditSaveService);

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

  @override
  bool get offersEditing =>
      widget.unlockEditing &&
      !widget.embedded &&
      _canEditSite(ref, widget.site, watch: false);

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
