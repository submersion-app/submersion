part of 'trip_detail_page.dart';

/// The trip page's overflow menu and what it runs: History and Open in
/// Connections, Export, and Delete, Remove or Unhide, which are
/// whole-record operations under the lock (issue #4527). The scans are on
/// the Dives and Photos cards.
extension _TripDetailMenu on _TripDetailContent {
  Widget _buildMoreMenu(BuildContext context, WidgetRef ref, Trip trip) {
    // Read this during build, not inside itemBuilder: itemBuilder runs when the
    // menu opens (outside this consumer's build phase), where ref.watch would
    // register a dependency outside Riverpod's build lifecycle.
    final canDestroy = canDestroySharedItemOnceKnown(
      ref.watch(validatedCurrentDiverIdProvider),
      ownerId: trip.diverId,
    );
    // A trip this profile already removed offers Unhide (issue #2679).
    final hidden = watchHiddenHere(
      ref,
      SharedItemKind.trip,
      trip.id,
      canDestroy: canDestroy != false,
    );
    // Remove only while the trip reaches this profile (issue #2151).
    final reachesHere = watchReachesHere(ref, SharedItemKind.trip, trip.id);
    final controller = host.editController;
    final operationsAvailable = recordOperationsAvailable(controller);
    return PopupMenuButton<String>(
      tooltip: context.l10n.trips_detail_tooltip_moreOptions,
      onSelected: (value) async {
        if (value == kOpenInConnectionsAction) {
          openInConnections(context, NodeRef(ConnectionKind.trip, trip.id));
        } else if (value == 'delete') {
          _runOperation(() => _delete(context, ref, trip));
        } else if (value == 'remove') {
          _runOperation(() => _removeFromProfile(context, ref, trip));
        } else if (value == 'unhide') {
          _runOperation(() async {
            // A failed unhide says so (issue #2677) and changed nothing.
            final unhidden = await runHideChange(
              ScaffoldMessenger.of(context),
              context.l10n,
              () => ref
                  .read(tripListNotifierProvider.notifier)
                  .unhideTrip(trip.id)
                  .then((_) => true),
            );
            return unhidden == true;
          });
        } else if (value == 'export') {
          _showExportOptions(context, ref);
        }
      },
      itemBuilder: (context) => [
        changeLogHistoryMenuItem(context, rootTable: 'trips', rootId: trip.id),
        openInConnectionsMenuItem(context),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              const Icon(Icons.file_download),
              const SizedBox(width: 8),
              Text(context.l10n.trips_detail_action_export),
            ],
          ),
        ),
        // Delete, Remove and Unhide are whole-record operations, under the
        // lock.
        if (canDestroy == true ||
            hidden ||
            (canDestroy == false && reachesHere))
          ...recordOperationMenuCaption<String>(context, controller),
        // Delete for the owner; another profile only removes the shared
        // trip from itself (issue #2594); neither while the profile is
        // unknown (issue #2682).
        if (canDestroy == true)
          PopupMenuItem(
            value: 'delete',
            enabled: operationsAvailable,
            child: Row(
              children: [
                Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  context.l10n.trips_detail_action_delete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
          )
        else if (hidden)
          PopupMenuItem(
            value: 'unhide',
            enabled: operationsAvailable,
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined),
                const SizedBox(width: 8),
                Flexible(child: Text(context.l10n.sharedItems_unhideAction)),
              ],
            ),
          )
        else if (canDestroy == false && reachesHere)
          PopupMenuItem(
            value: 'remove',
            enabled: operationsAvailable,
            child: Row(
              children: [
                const Icon(Icons.visibility_off_outlined),
                const SizedBox(width: 8),
                Flexible(child: Text(context.l10n.sharedItems_removeAction)),
              ],
            ),
          ),
      ],
    );
  }

  /// Runs a whole-record operation through the sitting.
  void _runOperation(Future<bool> Function() operation) {
    recordOperationRunnerOf(
      host.editController,
      record: 'trip ${tripWithStats.trip.id}',
    )(operation);
  }

  /// Asks, then deletes; whether it was deleted.
  Future<bool> _delete(BuildContext context, WidgetRef ref, Trip trip) async {
    final confirmed = await _showDeleteConfirmation(context, ref, trip);
    if (!confirmed || !context.mounted) return false;
    final deleted = await ref
        .read(tripListNotifierProvider.notifier)
        .deleteTrip(trip.id);
    if (!deleted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.sharedItems_notOwner_trip)),
        );
      }
      return false;
    }
    if (context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final message = context.l10n.trips_detail_snackBar_deleted;
      if (embedded) {
        onDeleted?.call();
      } else {
        context.pop();
      }
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
    return true;
  }

  Future<bool> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final divers = await ref.read(allDiversProvider.future);
    final diverCount = divers.length;
    if (!context.mounted) return false;
    // Shared with everyone or with chosen profiles (issue #2151).
    final shared = diverCount < 2
        ? false
        : await readSharedWithAnyone(
            ref,
            context,
            SharedItemKind.trip,
            trip.id,
          );
    if (shared == null) return false;
    final isSharedDelete = shared;
    // The other profiles' dives that lose the trip (issue #2594).
    final others = isSharedDelete
        ? (await readDiveLinkCounts(ref, SharedItemKind.trip, trip.id)).others
        : 0;
    if (!context.mounted) return false;
    // What the delete does to side trips and their dives (issue #3658).
    final activeDiverId = await ref.read(
      validatedCurrentDiverIdProvider.future,
    );
    if (!context.mounted) return false;
    final sideTripLines = await sideTripDeleteLines(
      context.l10n,
      ref.read(sideTripRepositoryProvider),
      [trip.id],
      diverId: activeDiverId,
    );
    if (!context.mounted) return false;

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              isSharedDelete
                  ? ctx.l10n.trips_deleteShared_title
                  : ctx.l10n.trips_detail_dialog_deleteTitle,
            ),
            content: Text(
              isSharedDelete
                  ? [
                      ctx.l10n.trips_deleteShared_body(trip.name),
                      ?otherProfilesDivesLine(
                        ctx.l10n,
                        SharedItemKind.trip,
                        others,
                      ),
                      ...sideTripLines,
                    ].join('\n\n')
                  : [
                      ctx.l10n.trips_detail_dialog_deleteContent(trip.name),
                      ...sideTripLines,
                    ].join('\n\n'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(ctx.l10n.trips_detail_dialog_cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: Text(ctx.l10n.trips_detail_dialog_deleteConfirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Hides another profile's shared trip from the active profile only
  /// (issue #2594), with Undo. Whether it was removed: a remove the diver
  /// cancelled, or one that failed, changed nothing.
  Future<bool> _removeFromProfile(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final notifier = ref.read(tripListNotifierProvider.notifier);
    var removed = false;
    await removeSharedItemFromProfile(
      context,
      ref,
      kind: SharedItemKind.trip,
      id: trip.id,
      name: trip.name,
      ownerId: trip.diverId,
      hide: () => notifier.hideTrip(trip.id),
      unhide: () => notifier.unhideTrip(trip.id),
      onRemoved: () {
        removed = true;
        embedded ? onDeleted?.call() : context.pop();
      },
    );
    return removed;
  }

  void _showExportOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label:
                  '${context.l10n.trips_detail_export_csv_title}. ${context.l10n.trips_detail_export_csv_subtitle}',
              child: ListTile(
                leading: const Icon(Icons.description),
                title: Text(context.l10n.trips_detail_export_csv_title),
                subtitle: Text(context.l10n.trips_detail_export_csv_subtitle),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.trips_detail_export_csv_comingSoon,
                      ),
                    ),
                  );
                },
              ),
            ),
            Semantics(
              button: true,
              label:
                  '${context.l10n.trips_detail_export_pdf_title}. ${context.l10n.trips_detail_export_pdf_subtitle}',
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(context.l10n.trips_detail_export_pdf_title),
                subtitle: Text(context.l10n.trips_detail_export_pdf_subtitle),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.trips_detail_export_pdf_comingSoon,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
