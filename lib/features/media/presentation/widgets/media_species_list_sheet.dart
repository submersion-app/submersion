import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_chips_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/features/species_id/presentation/providers/recorded_nearby_providers.dart';

/// Every species on a locked photo or video, from its "+N" chip (issue
/// #4825): the one line under the viewer shows only what fits. A tag opens
/// its species page; a suggestion is shown and waits for the unlock.
Future<void> showMediaSpeciesListSheet(
  BuildContext context,
  MediaItem item, {
  EditSession<PhotoRecord>? sitting,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => _MediaSpeciesList(item: item, sitting: sitting),
);

class _MediaSpeciesList extends ConsumerWidget {
  const _MediaSpeciesList({required this.item, this.sitting});

  final MediaItem item;
  final EditSession<PhotoRecord>? sitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      key: const ValueKey('media_species_list_sheet'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.isVideo
                ? l10n.media_species_sheetTitleVideo
                : l10n.media_species_sheetTitle,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  l10n.media_species_listLocked,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: speciesChipWidgets(
              context,
              ref,
              item.id,
              sitting,
              openUnconfirmed: true,
              nearbyRequest: nearbyRequestForMedia(item),
            ),
          ),
        ],
      ),
    );
  }
}
