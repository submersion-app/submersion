import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/equipment/presentation/editing/gear_item_list_pending.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_check_ins_sitting.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/observation_tag_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_observation_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/observation_near_miss_action.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The item page's check-in list: every observation on the item, newest
/// first, with the dive it was made on (or "Bench"). Adding and editing go
/// through the same sheet the dive page uses, in its no-dive mode so a new
/// row may pick a dive or stay a bench note.
///
/// It offers nothing outside the open Observations card (issue #4527, phase
/// 3); in the page's sitting ([editing]) check-ins added, edited and
/// deleted, with their photos, are held until Save, a delete asking
/// nothing, and a closed card shows what a sitting holds ([shown]).
class ObservationsCard extends ConsumerWidget {
  final EquipmentItem equipment;

  /// The sitting check-ins are held in: the Observations card's editor.
  final EditSession<EquipmentItem>? editing;

  /// The sitting whose check-ins a closed card shows.
  final EditSession<EquipmentItem>? shown;

  const ObservationsCard({
    super.key,
    required this.equipment,
    this.editing,
    this.shown,
  });

  /// The open card's sitting once it has read its check-ins: an action
  /// before then would have no list to go into. Null offers no action.
  EditSession<EquipmentItem>? get _acting => switch (editing) {
    final session? when gearItemCheckInsList.current(session) != null =>
      session,
    _ => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitting = editing ?? shown;
    if (sitting == null) return _build(context, ref, null);
    return ListenableBuilder(
      listenable: gearItemCheckInsList.changes(sitting),
      builder: (context, _) => _build(context, ref, sitting),
    );
  }

  Future<void> _add(BuildContext context, EditSession<EquipmentItem> session) =>
      showEquipmentObservationSheet(
        context,
        equipment: equipment,
        onHold: (held) => holdCheckIn(session, held),
        elsewhere: photosHeldOutside(session),
      );

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    EditSession<EquipmentItem>? sitting,
  ) {
    final l10n = context.l10n;
    final stored = ref.watch(observationsForEquipmentProvider(equipment.id));
    final held = sitting == null ? null : gearItemCheckInsList.current(sitting);
    final loaded = {
      for (final c
          in (sitting == null ? null : gearItemCheckInsList.loaded(sitting)) ??
              const <HeldCheckIn>[])
        c.observation.id: c,
    };
    final observationsAsync = held == null
        ? stored
        : AsyncValue<List<EquipmentObservation>>.data(
            [
              for (final c in held)
                if (!c.deleted) c.observation,
            ]..sort((a, b) => b.observedAt.compareTo(a.observedAt)),
          );
    final heldById = {
      for (final c in held ?? const <HeldCheckIn>[]) c.observation.id: c,
    };
    final acting = _acting;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.equipmentObservation_card_title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                RecordCardPencil(
                  cardTitle: l10n.equipmentObservation_card_title,
                ),
                if (acting != null)
                  TextButton.icon(
                    onPressed: () => _add(context, acting),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.equipmentObservation_card_add),
                  ),
              ],
            ),
            const Divider(),
            if (editing case final session?)
              ?gearItemListPending(gearItemCheckInsList, session),
            observationsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  Padding(padding: const EdgeInsets.all(8), child: Text('$e')),
              data: (observations) {
                if (observations.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.equipmentObservation_card_empty,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final o in observations)
                      _ObservationRow(
                        equipment: equipment,
                        observation: o,
                        held: heldById[o.id],
                        // A check-in the sitting made or changed is not
                        // stored yet: no near-miss can stand behind it.
                        stored:
                            sitting == null || loaded[o.id] == heldById[o.id],
                        onEdit: acting == null
                            ? null
                            : () => showEquipmentObservationSheet(
                                context,
                                equipment: equipment,
                                held: heldById[o.id],
                                onHold: (next) => holdCheckIn(acting, next),
                                elsewhere: photosHeldOutside(
                                  acting,
                                  checkIn: o.id,
                                ),
                              ),
                        // A delete asks nothing: Cancel brings it back.
                        onDelete: acting == null
                            ? null
                            : () => deleteHeldCheckIn(acting, o.id),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ObservationRow extends ConsumerWidget {
  final EquipmentItem equipment;
  final EquipmentObservation observation;

  /// The check-in as a sitting holds it, with its photo changes.
  final HeldCheckIn? held;

  /// Whether the check-in is as stored, so it may offer a near-miss.
  final bool stored;

  /// Null offers no edit or delete.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ObservationRow({
    required this.equipment,
    required this.observation,
    this.held,
    this.stored = true,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final scheme = Theme.of(context).colorScheme;
    final title = observation.displayTitle(l10n);
    final note = observation.noteSummary;
    final when = units.formatDate(observation.observedAt);
    final diveId = observation.diveId;
    // From the card's one batched read, not a dive detail per row.
    final diveNumber = diveId == null
        ? null
        : ref
              .watch(observationDiveNumbersProvider(equipment.id))
              .value?[diveId];
    final where = diveId == null
        ? l10n.equipmentObservation_card_bench
        // Until the dive resolves, a plain label: the id is internal.
        : diveNumber == null
        ? l10n.equipmentObservation_sheet_diveLabel
        : l10n.equipmentObservation_card_onDive(diveNumber);
    final detail = '$when, $where';
    // From the card's one batched read (issue #3355).
    final storedPhotos =
        ref.watch(checkInPhotosProvider(equipment.id)).value?[observation.id] ??
        const <MediaItem>[];
    final held = this.held;
    final photos = held == null
        ? storedPhotos
        : [
            for (final m in storedPhotos)
              if (!held.removedPhotoIds.contains(m.id)) m,
            for (final a in held.added) a.preview,
          ];
    final settings = units.settings;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        observation.isIssue ? Icons.warning_amber : Icons.check_circle_outline,
        color: observation.isIssue ? scheme.error : scheme.tertiary,
      ),
      title: Row(
        children: [
          Flexible(child: Text(title)),
          if (!stored) ...[const SizedBox(width: 6), const RecordChangedDot()],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note.isNotEmpty)
            Text(note, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(detail),
          if (photos.isNotEmpty)
            Padding(
              key: ValueKey('checkin_strip_${observation.id}'),
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final photo in photos)
                    SizedBox.square(
                      dimension: 44,
                      child: GestureDetector(
                        onTap: () => openMediaViewer(context, photos, photo.id),
                        child: MediaThumbnailTile(
                          item: photo,
                          settings: settings,
                          isSelectionMode: false,
                          isSelected: false,
                          semanticsLabel: l10n.equipment_photos_photoLabel,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (stored) ObservationNearMissAction(observation: observation),
        ],
      ),
      isThreeLine: note.isNotEmpty || observation.isIssue,
      trailing: onEdit == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.equipmentObservation_sheet_edit,
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.equipmentObservation_sheet_delete,
                  onPressed: onDelete,
                ),
              ],
            ),
    );
  }
}
