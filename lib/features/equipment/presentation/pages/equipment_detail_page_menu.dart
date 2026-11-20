part of 'equipment_detail_page.dart';

/// The gear item page's menu (issue #4527, phase 3, plan 6): History, Open
/// in Connections and Clone work locked; Transfer and Delete are
/// whole-record operations, under the lock.
extension _EquipmentDetailMenu on _EquipmentDetailContent {
  /// The overflow menu shared by the standalone and embedded headers.
  Widget _buildMenu(BuildContext context, WidgetRef ref) {
    // Nothing acts on an item not yet created (plan 11, call 3).
    if (_creating) return const SizedBox.shrink();
    final canDelete = _isOwner(ref);
    final canTransfer = _canTransfer(ref);
    return PopupMenuButton<String>(
      key: const ValueKey('equipment-detail-overflow'),
      icon: embedded ? const Icon(Icons.more_vert, size: 20) : null,
      onSelected: (value) => _handleMenuAction(context, ref, value),
      itemBuilder: (context) => _buildMenuItems(
        context,
        canDelete: canDelete,
        canTransfer: canTransfer,
      ),
    );
  }

  /// Open in Connections is for everyone who can see the item, a sharee
  /// included: shared gear sits on their own dives. So is Clone (#3184): the
  /// clone is the viewer's own item. Delete needs the owner.
  List<PopupMenuEntry<String>> _buildMenuItems(
    BuildContext context, {
    required bool canDelete,
    required bool canTransfer,
  }) {
    final operationsAvailable = recordOperationsAvailable(host.editController);
    return [
      changeLogHistoryMenuItem(
        context,
        rootTable: 'equipment',
        rootId: equipmentId,
      ),
      openInConnectionsMenuItem(context),
      PopupMenuItem(
        value: 'clone',
        child: ListTile(
          leading: const Icon(Icons.copy),
          title: Text(context.l10n.equipment_menu_clone),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      // Transfer and Delete are whole-record operations, under the lock.
      if (canTransfer || canDelete)
        ...recordOperationMenuCaption<String>(context, host.editController),
      if (canTransfer)
        PopupMenuItem(
          value: 'transfer',
          enabled: operationsAvailable,
          child: ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(context.l10n.equipment_transfer_action),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (canDelete)
        PopupMenuItem(
          value: 'delete',
          enabled: operationsAvailable,
          child: ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: Text(
              context.l10n.equipment_menu_delete,
              style: const TextStyle(color: Colors.red),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
    ];
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case kOpenInConnectionsAction:
        openInConnections(
          context,
          NodeRef(ConnectionKind.equipment, equipmentId),
        );
      case 'clone':
        context.push('/equipment/new?cloneFrom=$equipmentId');
      case 'transfer':
        await _operation(() => _transfer(context, ref));
      case 'delete':
        await _operation(() => _delete(context, ref));
    }
  }

  /// Runs [operation] through the sitting.
  Future<void> _operation(Future<bool> Function() operation) async {
    await recordOperationRunnerOf(
      host.editController,
      record: 'equipment $equipmentId',
    )(operation);
  }

  /// Transfers the item to another profile; whether it moved.
  Future<bool> _transfer(BuildContext context, WidgetRef ref) async {
    final activeDiverId = await ref.read(
      validatedCurrentDiverIdProvider.future,
    );
    if (!context.mounted) return false;
    final done = await transferEquipmentToProfile(
      context,
      ref,
      equipmentIds: [equipmentId],
      activeDiverId: activeDiverId,
    );
    final moved = done.outcome == BulkActionOutcome.completed;
    // Without kept access the item is no longer this profile's to see, so
    // leave it as after a delete.
    if (moved && !done.keptAccess && context.mounted) {
      if (embedded) {
        onDeleted?.call();
      } else {
        context.go('/equipment');
      }
    }
    return moved;
  }

  /// Asks, then deletes the item; whether it was deleted.
  Future<bool> _delete(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(equipmentListNotifierProvider.notifier);
    // The item as stored, not a re-read: a reload in flight would drop the
    // device warning a computer or transmitter needs.
    final confirmed = await confirmEquipmentDelete(context, stored.type);
    if (!confirmed) return false;
    final deleted = await notifier.deleteEquipment(equipmentId);
    if (!deleted) {
      // Delete is owner-only (issue #2046): the item was kept, so stay on
      // it and say why.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.equipment_delete_notOwner)),
        );
      }
      return false;
    }
    if (context.mounted) {
      if (embedded) {
        onDeleted?.call();
      } else {
        context.go('/equipment');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.equipment_snackbar_deleted)),
      );
    }
    return true;
  }
}
