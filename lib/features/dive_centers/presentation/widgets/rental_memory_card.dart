import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/domain/services/rental_memory_resolver.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_gear_note_sheet.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Last time at {center}" (issue #2075): the diver's most recent other
/// dive at the selected center (lead, how it felt, cylinders) and their
/// rental gear notes, with a way to add a note and to copy that dive's
/// weights and tanks into the form.
///
/// Shown under the dive center row of the dive edit form. The card only
/// reports; [onApplyLastDive] hands the last dive to the page, which owns
/// the form state and the confirm dialog.
class RentalMemoryCard extends ConsumerWidget {
  final DiveCenter center;

  /// The dive being edited, left out of the "last dive" lookup. Null while
  /// creating a dive.
  final String? currentDiveId;
  final void Function(LastDiveAtCenter last) onApplyLastDive;

  const RentalMemoryCard({
    super.key,
    required this.center,
    this.currentDiveId,
    required this.onApplyLastDive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final notes =
        ref.watch(diveCenterGearNotesProvider(center.id)).value ??
        const <DiveCenterGearNote>[];
    final lastAsync = ref.watch(
      lastDiveAtCenterProvider((
        centerId: center.id,
        excludingDiveId: currentDiveId,
      )),
    );
    final last = lastAsync.value;

    void addNote() => showRentalGearNoteSheet(
      context,
      diveCenterId: center.id,
      diveId: currentDiveId,
    );

    if (last == null && notes.isEmpty) {
      if (lastAsync.isLoading) return const SizedBox.shrink();
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: addNote,
          icon: const Icon(Icons.note_add_outlined),
          label: Text(l10n.diveCenters_rental_addNote),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.diveCenters_rental_lastTimeAt(center.name),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            if (last == null)
              Text(
                l10n.diveCenters_rental_noHistory,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              _LastDiveRows(last: last, units: units),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final note in notes)
                RentalNoteTile(
                  note: note,
                  units: units,
                  onTap: () => showRentalGearNoteSheet(
                    context,
                    diveCenterId: center.id,
                    diveId: currentDiveId,
                    editing: note,
                  ),
                ),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: addNote,
                  icon: const Icon(Icons.note_add_outlined),
                  label: Text(l10n.diveCenters_rental_addNote),
                ),
                if (last != null)
                  FilledButton.tonalIcon(
                    onPressed: () => onApplyLastDive(last),
                    icon: const Icon(Icons.history),
                    label: Text(l10n.diveCenters_rental_applyLastDive),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LastDiveRows extends StatelessWidget {
  final LastDiveAtCenter last;
  final UnitFormatter units;

  const _LastDiveRows({required this.last, required this.units});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final feedback = feedbackLabel(l10n, units);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.diveCenters_rental_lastDiveOn(units.formatDate(last.dateTime)),
          style: muted,
        ),
        if (last.weights.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.diveCenters_rental_leadTotal(
                  units.formatWeight(last.totalLeadKg),
                ),
                style: theme.textTheme.bodyMedium,
              ),
              for (final w in last.weights)
                Text(
                  '${w.weightType.localizedName(l10n)} '
                  '${units.formatWeight(w.amountKg)}',
                  style: muted,
                ),
              if (feedback != null)
                Chip(
                  label: Text(feedback),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
        if (last.tanks.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(l10n.diveCenters_rental_tanksLabel, style: muted),
          for (final t in last.tanks)
            Text(
              [
                ?(t.presetName?.toUpperCase() ?? t.name),
                if (t.volume case final v?) units.formatVolume(v),
                if (t.workingPressure case final p?) units.formatPressure(p),
              ].join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ],
    );
  }

  String? feedbackLabel(AppLocalizations l10n, UnitFormatter units) {
    final kg = last.weightingFeedbackKg;
    return switch (last.weightingFeedback) {
      null => null,
      WeightingFeedback.correct => l10n.diveLog_edit_weightFeedback_correct,
      WeightingFeedback.overweighted =>
        kg == null
            ? l10n.diveLog_edit_weightFeedback_over
            : l10n.diveCenters_rental_feedbackOver(units.formatWeight(kg)),
      WeightingFeedback.underweighted =>
        kg == null
            ? l10n.diveLog_edit_weightFeedback_under
            : l10n.diveCenters_rental_feedbackUnder(units.formatWeight(kg)),
    };
  }
}

/// One rental note: icon, label and size, verdict, its number, its text.
/// Public because the dive center detail page section reuses it.
class RentalNoteTile extends StatelessWidget {
  final DiveCenterGearNote note;
  final UnitFormatter units;
  final VoidCallback onTap;

  const RentalNoteTile({
    super.key,
    required this.note,
    required this.units,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final avoid = note.verdict == RentalVerdict.avoid;
    final details = <String>[
      if (note.leadAdjustmentKg case final kg? when kg != 0)
        kg > 0
            ? l10n.diveCenters_rental_extraLead(units.formatWeight(kg))
            : l10n.diveCenters_rental_lessLead(units.formatWeight(-kg)),
      if (note.volumeLiters case final v?)
        l10n.diveCenters_rental_actualCapacity(
          units.formatVolume(v, decimals: 1),
        ),
    ];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(equipmentTypeIcon(note.gearType)),
      title: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(note.gearType.localizedName(l10n)),
          if (note.label case final label?) Text(label),
          if (note.size case final size?) Text(size),
          Chip(
            label: Text(
              avoid
                  ? l10n.diveCenters_rental_verdictAvoid
                  : l10n.diveCenters_rental_verdictWorked,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: avoid
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.secondaryContainer,
          ),
        ],
      ),
      subtitle: details.isEmpty && note.note.isEmpty
          ? null
          : Text([...details, if (note.note.isNotEmpty) note.note].join('\n')),
      onTap: onTap,
    );
  }
}
