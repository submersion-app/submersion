import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/equipment_media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Files still linked to a piece of gear by the older attachment card
/// (issue #1517). Gear paperwork now lives in the Documents library, and
/// `EquipmentFileConverter` moves each linked file there once this device
/// can read it (issue #3333). What stays here is what Documents cannot hold
/// (a kind it does not accept, or a file over its page cap) or cannot read
/// yet, so the card shows only while something is left, with no way to add
/// more.
///
/// Opening is injected by the page rather than called here, mirroring
/// [SiteMediaSection]: it reaches the platform opener and the PDF viewer, so
/// keeping it out leaves this widget a pure function of its provider and
/// its callback.
class EquipmentDocumentsSection extends ConsumerWidget {
  final String equipmentId;

  /// Routes a tapped document (PDF viewer, or the platform opener).
  final void Function(MediaItem)? onOpenDocument;

  const EquipmentDocumentsSection({
    super.key,
    required this.equipmentId,
    this.onOpenDocument,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(mediaForEquipmentProvider(equipmentId));
    // Nothing left behind, or not known yet: no card at all. Almost every
    // item has nothing linked, so a card shown while loading would only
    // flash and vanish.
    final unknown = !documentsAsync.hasValue && !documentsAsync.hasError;
    if (unknown || (documentsAsync.value?.isEmpty ?? false)) {
      return const SizedBox.shrink();
    }

    // Brings its own gap above, so a hidden card leaves none.
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.equipment_documents_linkedTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            Text(
              context.l10n.equipment_documents_linkedSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            documentsAsync.when(
              data: (documents) => Column(
                children: [
                  for (final item in documents) _buildTile(context, ref, item),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  context.l10n.equipment_documents_loadError('$error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(padding: const EdgeInsets.only(top: 24), child: card);
  }

  Widget _buildTile(BuildContext context, WidgetRef ref, MediaItem item) {
    return ListTile(
      key: ValueKey('equipment-document-${item.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        item.isPdf ? Icons.picture_as_pdf : Icons.description,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        // Falls back to the id only when a row carries no filename at all,
        // which no import path produces; better than an empty tile.
        item.originalFilename ?? item.id,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      // Null, not a no-op closure: a non-null onTap gives the tile ripple
      // feedback and a tap target it cannot honour when no opener was wired.
      onTap: onOpenDocument == null ? null : () => onOpenDocument!(item),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: context.l10n.common_action_remove,
        onPressed: () => _confirmRemove(context, ref, item),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.equipment_documents_removeTitle),
        content: Text(ctx.l10n.equipment_documents_removeContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.common_action_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.common_action_remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Captured before the await so no BuildContext is dereferenced across the
    // async gap -- and then checked for mounted before showing, because that
    // capture does not make the ScaffoldMessengerState itself safe to use:
    // showSnackBar builds its AnimationController with `vsync: this`, so
    // firing it at a state disposed during the unlink throws.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      await unlinkEquipmentMedia(ref, equipmentId, [item.id]);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.equipment_documents_removed)),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.equipment_documents_removeError('$e')),
          backgroundColor: errorColor,
        ),
      );
    }
  }
}
