part of 'gps_track_detail_page.dart';

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
  bool get hostsEditing => widget.unlockEditing;

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
    if (trimChanged) await evict(session.stored.id);
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
  Widget _calculated(Widget child) => hostsEditing
      ? RecordCardFade<GpsTrack>(
          reason: RecordCardFadeReason.calculated,
          child: child,
        )
      : child;

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
}
