part of 'gps_track_detail_page.dart';

final _operationLog = LoggerService.forClass(GpsTrackDetailPage);

/// The GPS track page's use of the shared editing host (issue #4527,
/// phase 3): what is its own about saving, reading back and its cards.
mixin _GpsTrackDetailPageEditing
    on
        ConsumerState<GpsTrackDetailPage>,
        RecordEditHost<GpsTrackDetailPage, GpsTrack> {
  @override
  String get hostRecordId => widget.trackId;

  @override
  String recordIdOf(GpsTrack record) => record.id;

  @override
  Iterable<EditCard<GpsTrack>> get hostEditCards => gpsTrackEditCards.values;

  @override
  GpsTrack? get storedForUnlock =>
      ref.read(gpsTrackDetailProvider(widget.trackId)).value;

  @override
  String editingTitle(GpsTrack record) => context.l10n.recordEdit_editingTitle(
    record.name ?? context.l10n.gpsTrack_detail_title,
  );

  /// Writes the sitting through the track's save service: its name and
  /// trim, in one transaction and one History entry. A changed trim then
  /// drops the track's cached geometry, so the map draws the saved trim.
  @override
  Future<void> saveSitting(EditSession<GpsTrack> session) async {
    // Read before the write: the page can be gone by the time it is done.
    final service = ref.read(gpsTrackEditSaveServiceProvider);
    final evict = ref.read(evictGpsTrackProvider);
    final trimChanged = session.changedCardIds.contains(
      GpsTrackCardId.trim.name,
    );
    await service.save(
      // The track the sitting was opened on, whatever the page shows by the
      // time the write is asked for.
      trackId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
    );
    // The save reads the track without its fixes; the sitting's own copy
    // has them, so the page goes on drawing it until the reread.
    justSavedRecord = session.working;
    if (!trimChanged) return;
    // Best effort, after the commit: the save has been written, and a cache
    // that cannot drop the old line must not report it as failed. The map
    // then catches up when the cache is next evicted.
    try {
      await evict(session.stored.id);
    } catch (e, stackTrace) {
      _operationLog.error(
        'Dropping the cached geometry of GPS track ${session.stored.id} '
        'failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Closes the split panel once a split could no longer run from it: the
  /// sitting ended, or holds changes. Its "Split here" would otherwise do
  /// nothing. A split running keeps it, so a refused split point can be
  /// moved.
  @override
  void onEditChanged() {
    final controller = maybeEditController;
    if (ref.read(trackEditModeProvider) != TrackEditMode.none &&
        !(controller?.isOperating ?? false) &&
        _operationBlock != RecordOperationBlock.none) {
      ref.read(trackEditModeProvider.notifier).state = TrackEditMode.none;
    }
    super.onEditChanged();
  }

  @override
  Future<GpsTrack?> rereadStored(ProviderContainer container, GpsTrack stored) {
    container.invalidate(gpsTrackDetailProvider(stored.id));
    return container.read(gpsTrackDetailProvider(stored.id).future);
  }

  /// The card the page leaves out while it is empty: Trim.
  @override
  List<AddStripEntry> addStripEntries(GpsTrack working) {
    final session = maybeEditController?.session;
    if (session == null) return const [];
    final card = gpsTrackEditCards[GpsTrackCardId.trim]!;
    if (!card.isEmpty(working) || _showsWhileEmpty(GpsTrackCardId.trim)) {
      return const [];
    }
    return [
      AddStripEntry(
        cardId: card.id,
        label: card.title(context),
        changed: session.changedCardIds.contains(card.id),
      ),
    ];
  }

  /// The colour mode, which lives in the locked bar's bottom row; the
  /// editing bar has none.
  @override
  Widget? belowStrip(GpsTrack shown) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Center(child: _ColorModeSelector()),
  );

  /// Whether [id] is shown though empty: open or brought in from the strip
  /// during the sitting.
  bool _showsWhileEmpty(GpsTrackCardId id) {
    final controller = maybeEditController;
    if (controller == null || !controller.isUnlocked) return false;
    return controller.openCardIds.contains(id.name) ||
        controller.addedCardIds.contains(id.name);
  }

  /// [child] as the card [id], framed for editing in place.
  Widget _framed(GpsTrackCardId id, Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: RecordCardFrame<GpsTrack>(
      card: gpsTrackEditCards[id]!,
      child: child,
    ),
  );

  /// [child], a section the page calculates, faded and labelled
  /// "Calculated" while unlocked.
  Widget _calculated(Widget child) => RecordCardFade<GpsTrack>(
    reason: RecordCardFadeReason.calculated,
    child: child,
  );

  /// The header block: the track's name. Locked, an unnamed track shows
  /// none; unlocked it always shows, so the name can be given.
  Widget _headerBlock(GpsTrack shown) {
    final name = shown.name;
    if (name == null && !isSittingOpen) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return _framed(
      GpsTrackCardId.header,
      Card(
        key: const ValueKey('gps-track-header-block'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name ?? l10n.gpsTrack_editCard_nameHint,
                  style: name == null
                      ? theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : theme.textTheme.titleMedium,
                ),
              ),
              RecordCardPencil(
                cardTitle: GpsTrackCardId.header.localizedDisplayName(l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The Trim card: the trim's start and end, shown while the track is
  /// trimmed, or while the sitting brought the card in.
  Widget _trimCard(GpsTrack shown) {
    final card = gpsTrackEditCards[GpsTrackCardId.trim]!;
    if (card.isEmpty(shown) && !_showsWhileEmpty(GpsTrackCardId.trim)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    String time(int ms) =>
        units.formatTime(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
    final start = shown.trimStartTime;
    final end = shown.trimEndTime;
    return _framed(
      GpsTrackCardId.trim,
      Card(
        key: const ValueKey('gps-track-trim-card'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecordCardHeader(title: card.title(context)),
              if (start != null)
                Text('${l10n.gpsTrack_legend_start}: ${time(start)}'),
              if (end != null)
                Text('${l10n.gpsTrack_legend_end}: ${time(end)}'),
            ],
          ),
        ),
      ),
    );
  }

  /// Whether the record's operations may run now, or why not.
  RecordOperationBlock? get _operationBlock =>
      recordOperationBlockOf(editController);

  /// The menu's whole-record operations, Split and Delete, under the
  /// caption that says why they are unavailable.
  List<PopupMenuEntry<_TrackAction>> _operationItems() {
    final l10n = context.l10n;
    final block = _operationBlock;
    final reason = recordOperationReason(l10n, block, plural: true);
    final available = block == null || block == RecordOperationBlock.none;
    return [
      if (reason != null) recordOperationCaption<_TrackAction>(context, reason),
      PopupMenuItem(
        value: _TrackAction.split,
        enabled: available,
        child: Text(l10n.gpsTrack_action_split),
      ),
      PopupMenuItem(
        key: const ValueKey('gps-track-delete'),
        value: _TrackAction.delete,
        enabled: available,
        child: Text(l10n.common_action_delete),
      ),
    ];
  }

  /// Runs [operation] through the sitting, as every whole-record operation
  /// does.
  Future<void> _runOperation(Future<bool> Function() operation) =>
      recordOperationRunnerOf(
        editController,
        record: 'GPS track ${widget.trackId}',
      )(operation);

  /// Splits [track] at [atMs] into two tracks, as the split panel always
  /// has, then leaves the page: the track it showed is gone. Answers
  /// whether it wrote.
  Future<bool> _splitTrack(GpsTrack track, int atMs) async {
    final split = ref.read(splitTrackProvider);
    final mode = ref.read(trackEditModeProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await split(track.id, atMs);
    } on ArgumentError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${e.message}')));
      return false;
    }
    if (!mounted) return true;
    mode.state = TrackEditMode.none;
    Navigator.of(context).pop();
    return true;
  }

  /// Deletes [track] after the Tracks list's confirmation, forgets it as
  /// the list does, and leaves the page. Answers whether it wrote.
  Future<bool> _deleteTrack(GpsTrack track) async {
    final item = GpsTrackItem(track);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final delete = ref.read(deleteTrackProvider);
    if (!await confirmDeleteTrack(context, item)) return false;
    try {
      await delete(track.id);
    } catch (e, stackTrace) {
      _operationLog.error(
        'GPS track delete failed',
        error: e,
        stackTrace: stackTrace,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.common_error_tryAgain)),
      );
      return false;
    }
    if (!mounted) return true;
    forgetDeletedTrack(ref, item);
    Navigator.of(context).pop();
    return true;
  }
}
