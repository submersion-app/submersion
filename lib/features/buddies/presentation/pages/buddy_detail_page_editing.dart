part of 'buddy_detail_page.dart';

/// The buddy page's use of the shared editing host (issue #4527, phase 3):
/// what is its own about saving, reading back, its cards and the frames its
/// sections sit in.
mixin _BuddyDetailPageEditing
    on
        ConsumerState<BuddyDetailPage>,
        RecordEditHost<BuddyDetailPage, Buddy>,
        RecordOpenUnlocked<BuddyDetailPage, Buddy> {
  @override
  String get hostRecordId => widget.buddyId;

  @override
  String recordIdOf(Buddy record) => record.id;

  @override
  bool get hostsEditing => widget.unlockEditing;

  @override
  bool openUnlockedOf(BuddyDetailPage widget) => widget.openUnlocked;

  @override
  VoidCallback? get onOpenedSittingEnded => widget.onSittingEnded;

  @override
  void onEditChanged() {
    noteOpenedSittingEnded();
    super.onEditChanged();
  }

  @override
  Iterable<EditCard<Buddy>> get hostEditCards => buddyEditCards.values;

  @override
  Buddy? get storedForUnlock =>
      ref.read(buddyByIdProvider(widget.buddyId)).value;

  @override
  String editingTitle(Buddy record) =>
      context.l10n.recordEdit_editingTitle(record.name);

  @override
  void onSittingStart(EditSession<Buddy> session, ProviderContainer container) {
    // Read now, so the Certifications card shows the sitting's list once
    // it changes.
    buddyCertificationsList.load(session);
    holdDocumentLinks(
      session,
      container.read,
      owner: DocumentOwner(DocumentOwnerKind.buddy, session.stored.id),
      cardId: BuddyCardId.documents.name,
    );
  }

  /// Writes the sitting through the buddy's save service: its changed
  /// values and its held writes, in one transaction and one History entry.
  /// A profile link refused there leaves the page unlocked with the
  /// message (`RecordSittingRefusal`).
  @override
  Future<void> saveSitting(EditSession<Buddy> session) async {
    // Read before the write: the page can be gone by the time it is done.
    final service = ref.read(buddyEditSaveServiceProvider);
    final result = await service.save(
      // The buddy the sitting was opened on, whatever the page shows by the
      // time the write is asked for.
      buddyId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
      alsoWriteIsAChange: session.hasHeldChanges,
    );
    justSavedRecord = result?.after ?? session.working;
  }

  @override
  Future<Buddy?> rereadStored(ProviderContainer container, Buddy stored) {
    container.invalidate(buddyByIdProvider(stored.id));
    return container.read(buddyByIdProvider(stored.id).future);
  }

  /// The cards the page leaves out while they are empty: Contact and Notes.
  @override
  List<AddStripEntry> addStripEntries(Buddy working) {
    final session = maybeEditController?.session;
    if (session == null) return const [];
    return [
      for (final id in buddyOptionalCards)
        if (buddyEditCards[id]!.isEmptyDuring(working, session) &&
            !_showsWhileEmpty(id))
          AddStripEntry(
            cardId: id.name,
            label: buddyEditCards[id]!.title(context),
            changed: session.changedCardIds.contains(id.name),
          ),
    ];
  }

  /// Whether [id] is shown though empty: open or brought in from the strip
  /// during the sitting.
  bool _showsWhileEmpty(BuddyCardId id) {
    final controller = maybeEditController;
    if (controller == null || !controller.isUnlocked) return false;
    return controller.openCardIds.contains(id.name) ||
        controller.addedCardIds.contains(id.name);
  }

  /// [child] as the card [id], framed for editing in place.
  Widget _framed(BuddyCardId id, Widget child) =>
      RecordCardFrame<Buddy>(card: buddyEditCards[id]!, child: child);

  /// Whether the record's operations may run now, or why not.
  RecordOperationBlock? get _operationBlock =>
      recordOperationBlockOf(editController);

  bool get _operationsAvailable {
    final block = _operationBlock;
    return block == null || block == RecordOperationBlock.none;
  }

  /// The caption over the menu's operations while they are unavailable.
  List<PopupMenuEntry<String>> _operationCaption() {
    final reason = recordOperationReason(
      context.l10n,
      _operationBlock,
      plural: true,
    );
    return [
      if (reason != null) recordOperationCaption<String>(context, reason),
    ];
  }
}

/// A section's title row: its title, and the card's pencil where the page
/// edits in place ([editing]).
Widget _sectionTitle(
  BuildContext context,
  String title, {
  required bool editing,
}) {
  final text = Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
  );
  if (!editing) return text;
  return Row(
    children: [
      Expanded(child: text),
      RecordCardPencil(cardTitle: title),
    ],
  );
}

/// [child], faded and labelled for [reason] while unlocked.
Widget _faded(RecordCardFadeReason reason, Widget child) =>
    RecordCardFade<Buddy>(reason: reason, child: child);

/// The buddy page's menu and its whole-record operations.
extension _BuddyDetailMenus on _BuddyDetailContent {
  /// History, Open in Connections, Lend gear (where the page does not edit
  /// in place: lending is on the Gear card there), Share dives and Delete.
  Widget _menu(BuildContext context, WidgetRef ref, {bool compact = false}) {
    final host = this.host;
    final size = compact ? 20.0 : null;
    return PopupMenuButton<String>(
      icon: compact ? const Icon(Icons.more_vert, size: 20) : null,
      onSelected: (value) async {
        if (value == kOpenInConnectionsAction) {
          openInConnections(context, NodeRef(ConnectionKind.buddy, buddy.id));
        } else if (value == 'lend') {
          await showLendGearFlow(context, ref, buddy);
        } else if (value == 'share') {
          await shareDivesWithBuddy(context, ref, buddy.id);
        } else if (value == 'delete') {
          _requestDelete(context, ref);
        }
      },
      itemBuilder: (context) => [
        changeLogHistoryMenuItem(
          context,
          rootTable: 'buddies',
          rootId: buddy.id,
        ),
        openInConnectionsMenuItem(context),
        if (host == null)
          PopupMenuItem(
            value: 'lend',
            child: Row(
              children: [
                Icon(Icons.volunteer_activism_outlined, size: size),
                const SizedBox(width: 8),
                Text(context.l10n.buddies_action_lendGear),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share, size: size),
              const SizedBox(width: 8),
              Text(context.l10n.buddies_action_shareDives),
            ],
          ),
        ),
        // Delete is a whole-record operation, under the lock.
        ...?host?._operationCaption(),
        PopupMenuItem(
          value: 'delete',
          enabled: host?._operationsAvailable ?? true,
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red, size: size),
              const SizedBox(width: 8),
              Text(
                context.l10n.common_action_delete,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Delete, through the sitting where the page edits in place.
  void _requestDelete(BuildContext context, WidgetRef ref) {
    final host = this.host;
    if (host == null) {
      _handleDelete(context, ref);
      return;
    }
    recordOperationRunnerOf(host.editController, record: 'buddy ${buddy.id}')(
      () => _handleDelete(context, ref),
    );
  }

  /// Asks, then deletes; whether it was deleted.
  Future<bool> _handleDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final deleted = context.l10n.buddies_message_deleted;
    final confirmed = await _showDeleteConfirmation(context);
    if (!confirmed || !context.mounted) return false;
    await ref.read(buddyListNotifierProvider.notifier).deleteBuddy(buddy.id);
    if (context.mounted) {
      if (embedded) {
        onDeleted?.call();
      } else {
        context.pop();
      }
    }
    messenger.showSnackBar(SnackBar(content: Text(deleted)));
    return true;
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.buddies_dialog_deleteTitle),
            content: Text(
              context.l10n.buddies_dialog_deleteMessage(buddy.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.common_action_cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(context.l10n.common_action_delete),
              ),
            ],
          ),
        ) ??
        false;
  }
}
