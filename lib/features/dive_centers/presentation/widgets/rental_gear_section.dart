import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_gear_note_sheet.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_memory_card.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The dive center detail page's rental gear notes (issue #2075), grouped
/// by gear type in the canonical equipment order, with add on the header
/// and edit on tap. Matches the page's other sections: a titled column with
/// a 16 px gutter, no card.
class RentalGearSection extends ConsumerWidget {
  final String centerId;

  const RentalGearSection({super.key, required this.centerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final notes =
        ref.watch(diveCenterGearNotesProvider(centerId)).value ??
        const <DiveCenterGearNote>[];
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
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: l10n.diveCenters_rental_addNote,
                onPressed: () =>
                    showRentalGearNoteSheet(context, diveCenterId: centerId),
              ),
            ],
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
              RentalNoteTile(
                note: note,
                units: units,
                onTap: () => showRentalGearNoteSheet(
                  context,
                  diveCenterId: centerId,
                  editing: note,
                ),
              ),
        ],
      ),
    );
  }
}
