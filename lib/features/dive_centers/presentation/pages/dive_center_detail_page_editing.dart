part of 'dive_center_detail_page.dart';

/// The dive centre page's use of the shared editing host (issue #4527,
/// phase 3): what is its own about saving, reading back, its cards, its
/// menu and its whole-record operations.
mixin _DiveCenterDetailPageEditing
    on
        ConsumerState<DiveCenterDetailPage>,
        RecordEditHost<DiveCenterDetailPage, DiveCenter>,
        RecordOpenUnlocked<DiveCenterDetailPage, DiveCenter> {
  @override
  String get hostRecordId => widget.centerId;

  @override
  String recordIdOf(DiveCenter record) => record.id;

  @override
  bool openUnlockedOf(DiveCenterDetailPage widget) => widget.openUnlocked;

  @override
  VoidCallback? get onOpenedSittingEnded => widget.onSittingEnded;

  @override
  void onEditChanged() {
    noteOpenedSittingEnded();
    super.onEditChanged();
  }

  @override
  Iterable<EditCard<DiveCenter>> get hostEditCards =>
      diveCenterEditCards.values;

  @override
  DiveCenter? get storedForUnlock =>
      ref.read(diveCenterByIdProvider(widget.centerId)).value;

  @override
  String editingTitle(DiveCenter record) =>
      context.l10n.recordEdit_editingTitle(record.name);

  @override
  void onSittingStart(
    EditSession<DiveCenter> session,
    ProviderContainer container,
  ) {
    // Read now, so the Rental gear card shows the sitting's list once it
    // changes.
    diveCenterRentalList.load(session);
    holdDocumentLinks(
      session,
      container.read,
      owner: DocumentOwner(DocumentOwnerKind.diveCenter, session.stored.id),
      cardId: DiveCenterCardId.documents.name,
    );
  }

  /// Writes the sitting through the centre's save service: its changed
  /// values and its held writes, in one transaction and one History entry.
  @override
  Future<void> saveSitting(EditSession<DiveCenter> session) async {
    // Read before the write: the page can be gone by the time it is done.
    final service = ref.read(diveCenterEditSaveServiceProvider);
    final result = await service.save(
      centerId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
      alsoWriteIsAChange: session.hasHeldChanges,
    );
    justSavedRecord = result?.after ?? session.working;
  }

  @override
  Future<DiveCenter?> rereadStored(
    ProviderContainer container,
    DiveCenter stored,
  ) {
    container.invalidate(diveCenterByIdProvider(stored.id));
    return container.read(diveCenterByIdProvider(stored.id).future);
  }

  /// The cards the page leaves out while they are empty: Map, Contact and
  /// Notes.
  @override
  List<AddStripEntry> addStripEntries(DiveCenter working) {
    final session = maybeEditController?.session;
    if (session == null) return const [];
    return [
      for (final id in diveCenterOptionalCards)
        if (diveCenterEditCards[id]!.isEmpty(working) && !_showsWhileEmpty(id))
          AddStripEntry(
            cardId: id.name,
            label: diveCenterEditCards[id]!.title(context),
            changed: session.changedCardIds.contains(id.name),
          ),
    ];
  }

  /// Whether [id] is shown though empty: open or brought in from the strip
  /// during the sitting.
  bool _showsWhileEmpty(DiveCenterCardId id) {
    final controller = maybeEditController;
    if (controller == null || !controller.isUnlocked) return false;
    return controller.openCardIds.contains(id.name) ||
        controller.addedCardIds.contains(id.name);
  }

  /// [child] as the card [id], framed for editing in place.
  Widget _framed(DiveCenterCardId id, Widget child) =>
      RecordCardFrame<DiveCenter>(card: diveCenterEditCards[id]!, child: child);

  /// The pencil of the card [id].
  Widget _pencil(DiveCenterCardId id) =>
      RecordCardPencil(cardTitle: id.localizedDisplayName(context.l10n));

  /// [child], a section the page calculates, faded while unlocked.
  Widget _calculated(Widget child) => RecordCardFade<DiveCenter>(
    reason: RecordCardFadeReason.calculated,
    child: child,
  );

  /// The list pane's header row; while unlocked the shared pane header
  /// (Cancel, the title, the menu and Save) is laid over it. [stored] is
  /// the centre as stored, [center] as shown.
  Widget _buildEmbeddedHeader(
    BuildContext context,
    DiveCenter center, {
    required DiveCenter stored,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final locked = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          DiveCenterAvatar(
            logo: center.logo,
            shape: DiveCenterAvatarShape.roundedSquare,
            iconSize: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  center.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (center.fullLocationString != null)
                  Text(
                    center.fullLocationString!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (center.rating != null) ...[
            Icon(Icons.star, size: 16, color: Colors.amber.shade700),
            const SizedBox(width: 4),
            Text(
              formatRatingForDisplay(center.rating!),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
          ],
          lockButton(center, compact: true),
          _buildMoreMenu(context, center),
        ],
      ),
    );
    return RecordPaneRow(
      locked: locked,
      unlocked: isSittingOpen
          ? editingPaneRow(stored, menu: _buildMoreMenu(context, center))
          : null,
    );
  }

  Widget _buildMoreMenu(BuildContext context, DiveCenter center) {
    // Nothing acts on a centre not yet created (plan 11, call 3).
    if (isCreating) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == kOpenInConnectionsAction) {
          openInConnections(
            context,
            NodeRef(ConnectionKind.diveCenter, center.id),
          );
          return;
        }
        if (value == 'delete') _requestDelete(context, center);
      },
      itemBuilder: (context) => [
        changeLogHistoryMenuItem(
          context,
          rootTable: 'dive_centers',
          rootId: center.id,
        ),
        openInConnectionsMenuItem(context),
        // Delete is a whole-record operation, under the lock.
        ...recordOperationMenuCaption<String>(context, editController),
        PopupMenuItem(
          value: 'delete',
          enabled: recordOperationsAvailable(editController),
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.common_action_delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Delete, through the sitting.
  void _requestDelete(BuildContext context, DiveCenter center) {
    recordOperationRunnerOf(editController, record: 'dive centre ${center.id}')(
      () => _delete(context, center),
    );
  }

  /// Asks, with what the centre is used by, then deletes; whether it was
  /// deleted.
  Future<bool> _delete(BuildContext context, DiveCenter center) async {
    final usage = await readDiveCenterDeleteUsage(ref, [center.id]);
    if (!context.mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.diveCenters_dialog_deleteTitle),
        content: Text(
          withDiveCenterDeleteUsage(
            context.l10n,
            context.l10n.diveCenters_dialog_deleteMessage(center.name),
            usage,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_action_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.common_action_delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return false;
    await ref
        .read(diveCenterListNotifierProvider.notifier)
        .deleteDiveCenter(widget.centerId);
    if (context.mounted) {
      if (widget.embedded) {
        widget.onDeleted?.call();
      } else {
        context.pop();
      }
    }
    return true;
  }
}
