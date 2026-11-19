part of 'nav_track_detail_page.dart';

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
  bool get hostsEditing => widget.unlockEditing;

  @override
  Iterable<EditCard<NavTrack>> get hostEditCards => navTrackEditCards.values;

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

  /// [child] as the card [id], framed for editing in place while the page
  /// offers it; as it is otherwise.
  Widget _framed(NavTrackCardId id, Widget child) => hostsEditing
      ? RecordCardFrame<NavTrack>(card: navTrackEditCards[id]!, child: child)
      : child;

  /// The pencil of the card [id], where the page edits in place.
  Widget? _pencil(NavTrackCardId id) => hostsEditing
      ? RecordCardPencil(cardTitle: id.localizedDisplayName(context.l10n))
      : null;

  /// [child], a section the page calculates, faded and labelled
  /// "Calculated" while unlocked.
  Widget _calculated(Widget child) => hostsEditing
      ? RecordCardFade<NavTrack>(
          reason: RecordCardFadeReason.calculated,
          child: child,
        )
      : child;

  /// Whether the record's operations may run now, or why not.
  RecordOperationBlock? get _operationBlock =>
      recordOperationBlockOf(hostsEditing ? editController : null);

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
    if (!await _confirmDelete()) return false;
    await repository.delete(route.id);
    if (!mounted) return true;
    forgetDeletedTrack(ref, UnderwaterTrackItem(route));
    Navigator.of(context).pop();
    return true;
  }
}
