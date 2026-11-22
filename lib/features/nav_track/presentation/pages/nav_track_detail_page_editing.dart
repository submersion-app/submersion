part of 'nav_track_detail_page.dart';

final _operationLog = LoggerService.forClass(NavTrackDetailPage);

/// The underwater track page's use of the shared editing host (issue
/// #4527, phase 3, plan 5): what is its own about saving, reading back and
/// its cards.
mixin _NavTrackDetailPageEditing
    on
        ConsumerState<NavTrackDetailPage>,
        RecordEditHost<NavTrackDetailPage, NavTrack> {
  @override
  String get hostRecordId => widget.trackId;

  @override
  String recordIdOf(NavTrack record) => record.id;

  @override
  Iterable<EditCard<NavTrack>> get hostEditCards => navTrackEditCards.values;

  /// The 3D views' preview of this route, read as the page opens: the
  /// provider cannot be read once the page is closing.
  late final StateController<NavTrack?> _preview = ref.read(
    navTrackPreviewProvider(widget.trackId).notifier,
  );

  @override
  void initState() {
    super.initState();
    _preview;
  }

  /// Drops the preview after this frame, as the page closes: a closing page
  /// must not rebuild a view mid-frame.
  void _dropPreviewLater() {
    final preview = _preview;
    Future.microtask(() => dropNavTrackPreview(preview));
  }

  /// Once the sitting has ended, nothing holds a correction for the 3D
  /// views to preview: a preview a view left behind goes with it.
  @override
  void onEditChanged() {
    if (!isSittingOpen) dropNavTrackPreview(_preview);
    super.onEditChanged();
  }

  @override
  NavTrack? get storedForUnlock =>
      ref.read(navTrackWithMarkersProvider(widget.trackId)).value;

  @override
  String editingTitle(NavTrack record) => context.l10n.recordEdit_editingTitle(
    record.name ??
        record.sourceRef ??
        context.l10n.navTrack_detail_defaultTrackTitle,
  );

  /// Writes the sitting through the route's save service: its changed
  /// values and its dive link, in one transaction and one History entry.
  @override
  Future<void> saveSitting(EditSession<NavTrack> session) async {
    // Read before the write: the page can be gone by the time it is done.
    final service = ref.read(navTrackEditSaveServiceProvider);
    await service.save(
      // The route the sitting was opened on, whatever the page shows by the
      // time the write is asked for.
      routeId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      anchorFromSite: navTrackAnchorFromSite(session),
    );
    // The save reads the route without its samples; the sitting's own copy
    // has them, so the page goes on drawing it until the reread.
    justSavedRecord = session.working;
  }

  @override
  Future<NavTrack?> rereadStored(ProviderContainer container, NavTrack stored) {
    container.invalidate(navTrackByIdProvider(stored.id));
    return container.read(navTrackWithMarkersProvider(stored.id).future);
  }

  /// Every card shows its "none" row, so the strip offers none.
  @override
  List<AddStripEntry> addStripEntries(NavTrack working) => const [];

  /// [child] as the card [id], framed for editing in place.
  Widget _framed(NavTrackCardId id, Widget child) =>
      RecordCardFrame<NavTrack>(card: navTrackEditCards[id]!, child: child);

  /// The pencil of the card [id].
  Widget _pencil(NavTrackCardId id) =>
      RecordCardPencil(cardTitle: id.localizedDisplayName(context.l10n));

  /// [child], a section the page calculates, faded and labelled
  /// "Calculated" while unlocked.
  Widget _calculated(Widget child) => RecordCardFade<NavTrack>(
    reason: RecordCardFadeReason.calculated,
    child: child,
  );

  /// Whether the record's operations may run now, or why not.
  RecordOperationBlock? get _operationBlock =>
      recordOperationBlockOf(editController);

  /// The menu's whole-record operations, Update from file (an ENC route
  /// only) and Delete, under the caption that says why they are
  /// unavailable.
  List<PopupMenuEntry<String>> _operationItems(NavTrack route) {
    final l10n = context.l10n;
    final block = _operationBlock;
    final reason = recordOperationReason(l10n, block, plural: true);
    final available = block == null || block == RecordOperationBlock.none;
    return [
      if (reason != null) recordOperationCaption<String>(context, reason),
      if (route.source == NavTrackSource.seacraftEnc)
        PopupMenuItem(
          key: const ValueKey('nav-track-update-from-file'),
          value: 'updateFromFile',
          enabled: available,
          child: Text(l10n.navTrack_detail_menuUpdateFromFile),
        ),
      PopupMenuItem(
        key: const ValueKey('nav-track-delete'),
        value: 'delete',
        enabled: available,
        child: Text(l10n.navTrack_common_delete),
      ),
    ];
  }

  /// Runs [operation] through the sitting, as every whole-record operation
  /// does.
  Future<void> _runOperation(Future<bool> Function() operation) =>
      recordOperationRunnerOf(
        editController,
        record: 'underwater track ${widget.trackId}',
      )(operation);

  /// Asks before the route is deleted. True once the diver confirms.
  Future<bool> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.navTrack_detail_deleteTrackTitle),
        content: Text(l10n.navTrack_detail_deleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.navTrack_common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.navTrack_common_delete),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Deletes the route after the page's confirmation (deleting promotes a
  /// sibling route on its dive, as it always has), forgets it as the
  /// Tracks list does, and leaves the page. Answers whether it wrote.
  Future<bool> _deleteInSitting(NavTrack route) async {
    final repository = ref.read(navTrackRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (!await _confirmDelete()) return false;
    try {
      await repository.delete(route.id);
    } catch (e, stackTrace) {
      _operationLog.error(
        'Underwater track delete failed',
        error: e,
        stackTrace: stackTrace,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.common_error_tryAgain)),
      );
      return false;
    }
    if (!mounted) return true;
    forgetDeletedTrack(ref, UnderwaterTrackItem(route));
    Navigator.of(context).pop();
    return true;
  }
}
