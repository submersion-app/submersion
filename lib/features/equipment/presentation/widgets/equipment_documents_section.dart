import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/equipment_media_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The paperwork filed against a piece of gear (issue #1517): invoices,
/// receipts and warranty documents, which is what an insurer asks for after
/// lost luggage, theft or fire.
///
/// A list rather than the photo grid the dive and site sections use: an item
/// carries a handful of documents whose filenames are the whole point, and a
/// thumbnail of a PDF invoice tells the diver nothing a name does not.
///
/// Documents are linked by reference, never copied -- the media store upload
/// is what makes them durable, exactly as on the dive and site sections.
///
/// Attaching and opening are injected by the page rather than called here,
/// mirroring [SiteMediaSection]: both reach the file picker, the platform
/// opener and the PDF viewer, so keeping them out leaves this widget a pure
/// function of its provider and its callbacks.
class EquipmentDocumentsSection extends ConsumerWidget {
  final String equipmentId;

  /// Opens the document picker. Null hides the attach action.
  final VoidCallback? onAttachPressed;

  /// Routes a tapped document (PDF viewer, or the platform opener).
  final void Function(MediaItem)? onOpenDocument;

  const EquipmentDocumentsSection({
    super.key,
    required this.equipmentId,
    this.onAttachPressed,
    this.onOpenDocument,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(mediaForEquipmentProvider(equipmentId));

    return Card(
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
                    context.l10n.equipment_documents_title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onAttachPressed != null)
                  TextButton.icon(
                    key: const ValueKey('equipment-documents-attach'),
                    onPressed: onAttachPressed,
                    icon: const Icon(Icons.attach_file),
                    label: Text(context.l10n.equipment_documents_attachButton),
                  ),
              ],
            ),
            Text(
              context.l10n.equipment_documents_subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            documentsAsync.when(
              data: (documents) => documents.isEmpty
                  ? _buildEmpty(context)
                  : Column(
                      children: [
                        for (final item in documents)
                          _buildTile(context, ref, item),
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
  }

  Widget _buildEmpty(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      context.l10n.equipment_documents_empty,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

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

    // Captured before the await: the snackbar and its error colour must not
    // reach for a BuildContext across the async gap.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      await unlinkEquipmentMedia(ref, [item.id]);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.equipment_documents_removed)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.equipment_documents_removeError('$e')),
          backgroundColor: errorColor,
        ),
      );
    }
  }
}
