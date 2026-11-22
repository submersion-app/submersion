import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_rental_sitting.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_gear_note_sheet.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_memory_card.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';

/// The dive center detail page's rental gear notes (issue #2075), grouped
/// by gear type in the canonical equipment order, with add on the header
/// and edit on tap. Matches the page's other sections: a titled column with
/// a 16 px gutter, no card.
///
/// It offers nothing outside the open Rental gear card (issue #4527, phase
/// 3); in the page's sitting ([editing]) notes added, edited and removed are held until Save, a removal asking
/// nothing, and the notes the sitting holds show the changed dot.
class RentalGearSection extends ConsumerWidget {
  final String centerId;

  /// The sitting its notes are held in: it is the Rental gear card's
  /// editor, drawn inside the open card.
  final EditSession<DiveCenter>? editing;

  /// The sitting whose notes a closed card shows.
  final EditSession<DiveCenter>? shown;

  const RentalGearSection({
    super.key,
    required this.centerId,
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

  /// Opens the note sheet for [note], a new one when null, and holds what
  /// it returns in the open card's sitting.
  Future<void> _hold(BuildContext context, DiveCenterGearNote? note) async {
    final session = editing!;
    final edit = await showRentalGearNoteSheet(
      context,
      diveCenterId: centerId,
      editing: note,
      holdOnly: true,
    );
    if (edit == null || session.isDisposed) return;
    // Read first when the read had not answered, or failed.
    if (diveCenterRentalList.current(session) == null) {
      await diveCenterRentalList.load(session);
    }
    final current = diveCenterRentalList.current(session);
    if (current == null || session.isDisposed) return;
    diveCenterRentalList.set(session, rentalNotesAfter(current, edit));
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    EditSession<DiveCenter>? sitting,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final stored =
        ref.watch(diveCenterGearNotesProvider(centerId)).value ??
        const <DiveCenterGearNote>[];
    final notes = sitting == null
        ? stored
        : diveCenterRentalList.current(sitting) ?? stored;
    final loaded = sitting == null
        ? null
        : {
            for (final n in diveCenterRentalList.loaded(sitting) ?? stored)
              n.id: n,
          };
    final ordered = [...notes]
      ..sort((a, b) {
        final byType =
            equipmentTypeRank(a.gearType, kCanonicalTypeOrder) -
            equipmentTypeRank(b.gearType, kCanonicalTypeOrder);
        if (byType != 0) return byType;
        return b.notedAt.compareTo(a.notedAt);
      });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.diveCenters_rental_sectionTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (editing == null)
                RecordCardPencil(
                  cardTitle: l10n.diveCenters_rental_sectionTitle,
                )
              else
                IconButton(
                  key: const ValueKey('rental_gear_add'),
                  icon: const Icon(Icons.add),
                  tooltip: l10n.diveCenters_rental_addNote,
                  onPressed: () => _hold(context, null),
                ),
            ],
          ),
          if (editing != null && diveCenterRentalList.failed(editing!))
            SittingLoadFailed(
              onRetry: () => diveCenterRentalList.load(editing!),
            ),
          if (ordered.isEmpty)
            Text(
              l10n.diveCenters_rental_empty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final note in ordered)
              Row(
                children: [
                  Expanded(
                    child: RentalNoteTile(
                      note: note,
                      units: units,
                      onTap: editing == null
                          ? null
                          : () => _hold(context, note),
                    ),
                  ),
                  if (loaded != null && loaded[note.id] != note)
                    const RecordChangedDot(),
                ],
              ),
        ],
      ),
    );
  }
}
