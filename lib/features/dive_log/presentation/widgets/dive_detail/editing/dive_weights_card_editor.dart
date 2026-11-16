import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_weight_entry_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gear_lead_note.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/services/equipment_lead.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/features/weight_presets/presentation/widgets/name_prompt_dialog.dart';
import 'package:submersion/features/weight_presets/presentation/widgets/weight_preset_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_append_row.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_form.dart';
import 'package:submersion/shared/widgets/record_editing/record_number_row.dart';
import 'package:submersion/shared/widgets/record_editing/stored_follow.dart';

const _log = LoggerService('DiveWeightsCardEditor');

/// The Weight card's editor (issue #4527): the weights with their total, a
/// saved preset, and how the weighting felt.
///
/// The rows are the dive form's own ([DiveWeightEntryRow]), which validate
/// their amounts themselves; they report through a [RecordCardForm], so an
/// amount that cannot be read keeps the card open.
class DiveWeightsCardEditor extends ConsumerStatefulWidget {
  const DiveWeightsCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  ConsumerState<DiveWeightsCardEditor> createState() =>
      _DiveWeightsCardEditorState();
}

class _DiveWeightsCardEditorState extends ConsumerState<DiveWeightsCardEditor> {
  /// Moves when the stored weights change underneath (a sync), so the rows
  /// show the new amounts. Rows replaced from outside them (a preset, a set,
  /// the last dive at a center) are fresh rows with ids of their own.
  final _followed = StoredFollow<Dive, List<DiveWeight>>(diveWeightsField);

  EditSession<Dive> get _session => widget.session;

  void _setRows(List<DiveWeight> rows) => _session.set(diveWeightsField, rows);

  void _replace(DiveWeight updated) => _setRows([
    for (final w in _session.valueOf(diveWeightsField))
      w.id == updated.id ? updated : w,
  ]);

  Future<void> _usePreset() async {
    final messenger = ScaffoldMessenger.of(context);
    final applied = context.l10n.diveLog_edit_weightPreset_applied;
    final preset = await showModalBottomSheet<WeightPreset>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scrollController) =>
            WeightPresetPickerSheet(scrollController: scrollController),
      ),
    );
    if (preset == null || !mounted) return;
    if (_session.isDisposed || _session.isFrozen) return;
    applyWeightPresetInSitting(_session, preset);
    messenger.showSnackBar(SnackBar(content: Text(applied)));
  }

  /// Saves the weights as a named preset, at once: a preset is a record of
  /// its own, made from a picker as a new buddy is, and it outlives a
  /// cancelled sitting (issue #1609).
  Future<void> _saveAsPreset() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(weightPresetRepositoryProvider);
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null || !mounted) return;
    final name = await NamePromptDialog.show(
      context,
      title: l10n.diveLog_edit_weightPreset_saveTitle,
      label: l10n.diveLog_edit_weightPreset_nameLabel,
      confirmLabel: l10n.common_action_save,
    );
    if (name == null || !mounted) return;
    final weights = [
      for (final w in _session.valueOf(diveWeightsField))
        if (w.amountKg > 0) w,
    ];
    if (weights.isEmpty) return;
    try {
      await repository.createFromWeights(
        diverId: diverId,
        displayName: name,
        weights: weights,
      );
    } catch (error, stackTrace) {
      _log.error(
        'Saving the weights as a preset failed',
        error: error,
        stackTrace: stackTrace,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.common_label_error}: $error')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.diveLog_edit_weightPreset_saved(name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitFormatterProvider);
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._weightRows(context, units),
          ..._feedbackRows(context, units),
        ],
      ),
    );
  }

  List<Widget> _weightRows(BuildContext context, UnitFormatter units) {
    final l10n = context.l10n;
    final rows = _session.valueOf(diveWeightsField);
    final generation = _followed.generationOf(_session);
    // The gear is the dive's as the sitting has it, so a change made on the
    // Equipment card in the same sitting shows here too. Its lead is in the
    // total, as on the read card (issue #4442).
    final leadGear = EquipmentLead.carriers(_session.valueOf(diveGearField));
    final total = editorWeightTotalKg(rows, leadGear);
    return [
      FormOverline(
        label: l10n.diveLog_edit_section_weight,
        trailingText: total == null
            ? null
            : l10n.diveLog_edit_weightTotal(units.formatWeight(total)),
        actions: [
          FormOverlineAction(
            label: l10n.diveLog_edit_weightPreset_use,
            icon: Icons.fitness_center,
            onPressed: _usePreset,
          ),
          if (rows.any((w) => w.amountKg > 0))
            FormOverlineAction(
              label: l10n.diveLog_edit_weightPreset_save,
              icon: Icons.bookmark_add_outlined,
              onPressed: _saveAsPreset,
            ),
        ],
      ),
      if (rows.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: RecordCardForm<Dive>(
            cardId: diveWeightsCardId,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final weight in rows)
                  DiveWeightEntryRow(
                    key: ValueKey((weight.id, generation)),
                    weight: weight,
                    units: units,
                    onChanged: _replace,
                    onRemove: () => _setRows([
                      for (final w in _session.valueOf(diveWeightsField))
                        if (w.id != weight.id) w,
                    ]),
                  ),
              ],
            ),
          ),
        ),
      GearLeadNote(items: leadGear, units: units),
      FormAppendRow(
        label: l10n.diveLog_edit_addWeightEntry,
        onTap: () => _setRows([...rows, newSittingWeight(_session)]),
      ),
    ];
  }

  List<Widget> _feedbackRows(BuildContext context, UnitFormatter units) {
    final l10n = context.l10n;
    final feedback = _session.valueOf(diveWeightingFeedbackField);
    // Labels like "Overweighted" are wider than a third of the row on a
    // phone; they scale down to stay on one line.
    ButtonSegment<WeightingFeedback> segment(
      WeightingFeedback value,
      String label,
    ) => ButtonSegment(
      value: value,
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
    );
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.diveLog_edit_weightFeedback_label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            SegmentedButton<WeightingFeedback>(
              emptySelectionAllowed: true,
              segments: [
                segment(
                  WeightingFeedback.correct,
                  l10n.diveLog_edit_weightFeedback_correct,
                ),
                segment(
                  WeightingFeedback.overweighted,
                  l10n.diveLog_edit_weightFeedback_over,
                ),
                segment(
                  WeightingFeedback.underweighted,
                  l10n.diveLog_edit_weightFeedback_under,
                ),
              ],
              selected: {?feedback},
              onSelectionChanged: (selection) => setWeightingFeedback(
                _session,
                selection.isEmpty ? null : selection.first,
              ),
            ),
          ],
        ),
      ),
      if (feedback == WeightingFeedback.overweighted ||
          feedback == WeightingFeedback.underweighted)
        RecordNumberRow<Dive>(
          session: _session,
          field: diveWeightingFeedbackKgField,
          label: l10n.diveLog_edit_weightFeedback_amount(units.weightSymbol),
          suffixText: units.weightSymbol,
          fractionDigits: 1,
          trimZeros: true,
          allowNegative: false,
          toDisplay: units.convertWeight,
          fromDisplay: units.weightToKg,
        ),
    ];
  }
}
