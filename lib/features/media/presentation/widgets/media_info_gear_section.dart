import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_sitting_shown.dart';
import 'package:submersion/features/media/presentation/media_tag_navigation.dart';
import 'package:submersion/features/media/presentation/providers/media_gear_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_gear_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The info panel's Gear card (issue #5046): the gear shown in the photo as
/// chips, each opening its item's page, and Edit gear while the photo's
/// sitting is over it. Shown even with no gear, as the Tags card is, so the
/// panel is a way in to linking on every width.
///
/// Only gear the active diver can see is drawn: a link to another diver's
/// gear stays stored and is never removed from here.
class MediaInfoGearSection extends ConsumerWidget {
  const MediaInfoGearSection({
    super.key,
    required this.item,
    this.readOnly = false,
    this.sitting,
  });

  final MediaItem item;

  /// No Edit gear: the photo is locked, or shown where it has no lock of
  /// its own.
  final bool readOnly;

  /// The photo's sitting: its held gear is shown, and Edit gear holds.
  final EditSession<PhotoRecord>? sitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The info sheet is a route of its own, which the viewer's redraws do
    // not reach: the card follows the sitting itself.
    final session = sitting;
    if (session == null || session.isDisposed) return _card(context, ref);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _card(context, ref),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final held = sittingIsOver(sitting, item.id) ? sitting : null;
    final canEdit = !readOnly && held != null;
    final ids = held != null
        ? held.working.gearIds
        : ref.watch(gearIdsForMediaProvider(item.id)).value ?? const <String>[];
    final visible = {
      for (final g
          in ref.watch(allEquipmentProvider).value ?? const <EquipmentItem>[])
        g.id: g,
    };
    final gear = sortedByText([
      for (final id in ids) ?visible[id],
    ], (g) => g.name);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.media_info_gear, style: theme.textTheme.titleMedium),
            const Divider(),
            if (gear.isEmpty)
              Text(
                l10n.media_info_noGear,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in gear)
                    ActionChip(
                      avatar: Icon(equipmentItemIcon(g), size: 18),
                      label: Text(g.name, overflow: TextOverflow.ellipsis),
                      tooltip: l10n.media_info_openGear(g.name),
                      onPressed: () => openGearItem(context, g.id),
                    ),
                ],
              ),
            if (canEdit) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('media_info_editGear'),
                  icon: const Icon(Icons.backpack_outlined, size: 18),
                  label: Text(l10n.media_info_editGear),
                  onPressed: () =>
                      showMediaGearSheet(context, item, sitting: held),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
