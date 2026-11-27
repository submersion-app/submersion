import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_media_sitting.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
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
///
/// It offers no remove outside the open Legacy files card (issue #4527,
/// phase 3); in the page's sitting ([editing]) a remove asks nothing and is
/// held until Save, and a closed card shows what a sitting holds ([shown]).
class EquipmentDocumentsSection extends ConsumerWidget {
  final String equipmentId;

  /// Routes a tapped document (PDF viewer, or the platform opener).
  final void Function(MediaItem)? onOpenDocument;

  /// The sitting removes are held in: the Legacy files card's editor.
  final EditSession<EquipmentItem>? editing;

  /// The sitting whose removes a closed card shows.
  final EditSession<EquipmentItem>? shown;

  const EquipmentDocumentsSection({
    super.key,
    required this.equipmentId,
    this.onOpenDocument,
    this.editing,
    this.shown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitting = editing ?? shown;
    if (sitting == null) return _build(context, ref, null);
    return ListenableBuilder(
      listenable: sitting,
      builder: (context, _) => _build(context, ref, sitting),
    );
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    EditSession<EquipmentItem>? sitting,
  ) {
    // Gear photos (issue #3355) belong to the Photos card and the check-ins;
    // what is left here is the paperwork Documents could not take.
    final documentsAsync = ref.watch(mediaForEquipmentProvider(equipmentId));
    final stored = [
      for (final m in documentsAsync.value ?? const <MediaItem>[])
        if (!m.isGearPhoto) m,
    ];
    final leftovers = sitting == null
        ? stored
        : legacyFilesInSitting(sitting, stored);
    // Nothing left behind, or not known yet: no card at all. Almost every
    // item has nothing linked, so a card shown while loading would only
    // flash and vanish.
    final unknown = !documentsAsync.hasValue && !documentsAsync.hasError;
    // A card the sitting emptied stays while open, to say so at Save.
    if (unknown ||
        (documentsAsync.hasValue && stored.isEmpty) ||
        (documentsAsync.hasValue && leftovers.isEmpty && editing == null)) {
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
                RecordCardPencil(
                  cardTitle: context.l10n.equipment_documents_linkedTitle,
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
              data: (_) => Column(
                children: [
                  for (final item in leftovers) _buildTile(context, item),
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

  Widget _buildTile(BuildContext context, MediaItem item) {
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
      trailing: switch (editing) {
        null => null,
        // A remove asks nothing: Cancel brings it back.
        final session => IconButton(
          icon: const Icon(Icons.close),
          tooltip: context.l10n.common_action_remove,
          onPressed: () => unlinkLegacyFileInSitting(session, item.id),
        ),
      },
    );
  }
}
