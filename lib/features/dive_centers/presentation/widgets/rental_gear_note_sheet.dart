import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the rental gear note editor (issue #2075) for a center. With
/// [editing], the sheet edits that note; otherwise it creates one for
/// [diveCenterId], remembering [diveId] as where it was noticed.
Future<void> showRentalGearNoteSheet(
  BuildContext context, {
  required String diveCenterId,
  String? diveId,
  DiveCenterGearNote? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RentalGearNoteSheet(
      diveCenterId: diveCenterId,
      diveId: diveId,
      editing: editing,
    ),
  );
}

/// Asks before deleting [note], then deletes it. Returns true when the
/// note is gone. Shared by the sheet and the detail page section.
Future<bool> confirmDeleteRentalGearNote(
  BuildContext context,
  WidgetRef ref,
  DiveCenterGearNote note,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(l10n.diveCenters_rental_deleteConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.common_action_delete),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  await ref.read(diveCenterGearNoteRepositoryProvider).delete(note.id);
  return true;
}

class _RentalGearNoteSheet extends ConsumerStatefulWidget {
  final String diveCenterId;
  final String? diveId;
  final DiveCenterGearNote? editing;

  const _RentalGearNoteSheet({
    required this.diveCenterId,
    this.diveId,
    this.editing,
  });

  @override
  ConsumerState<_RentalGearNoteSheet> createState() =>
      _RentalGearNoteSheetState();
}

class _RentalGearNoteSheetState extends ConsumerState<_RentalGearNoteSheet> {
  late EquipmentType _gearType;
  late RentalVerdict _verdict;
  late final TextEditingController _label;
  late final TextEditingController _size;
  late final TextEditingController _lead;
  late final TextEditingController _volume;
  late final TextEditingController _note;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.editing;
    final units = UnitFormatter(ref.read(settingsProvider));
    _gearType = existing?.gearType ?? EquipmentType.other;
    _verdict = existing?.verdict ?? RentalVerdict.worked;
    _label = TextEditingController(text: existing?.label ?? '');
    _size = TextEditingController(text: existing?.size ?? '');
    _lead = TextEditingController(
      text: existing?.leadAdjustmentKg == null
          ? ''
          : formatRoundedForInput(
              units.convertWeight(existing!.leadAdjustmentKg!),
              2,
            ),
    );
    _volume = TextEditingController(
      text: existing?.volumeLiters == null
          ? ''
          : formatRoundedForInput(
              units.convertVolume(existing!.volumeLiters!),
              2,
            ),
    );
    _note = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    _size.dispose();
    _lead.dispose();
    _volume.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final units = UnitFormatter(ref.read(settingsProvider));
    final leadText = _lead.text.trim();
    final volumeText = _volume.text.trim();
    final lead = leadText.isEmpty ? null : parseUserDecimal(leadText);
    final volume = volumeText.isEmpty ? null : parseUserDecimal(volumeText);
    // Unreadable text is refused rather than silently dropped.
    if ((leadText.isNotEmpty && lead == null) ||
        (_gearType == EquipmentType.tank &&
            volumeText.isNotEmpty &&
            volume == null)) {
      setState(() => _error = l10n.numberInput_invalidValue);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(diveCenterGearNoteRepositoryProvider);
      final existing = widget.editing;
      final leadKg = lead == null ? null : units.weightToKg(lead);
      final volumeL = _gearType == EquipmentType.tank && volume != null
          ? units.volumeToLiters(volume)
          : null;
      if (existing == null) {
        final now = DateTime.now().toUtc();
        await repo.create(
          DiveCenterGearNote(
            id: '',
            diveCenterId: widget.diveCenterId,
            gearType: _gearType,
            label: _label.text,
            size: _size.text,
            verdict: _verdict,
            leadAdjustmentKg: leadKg,
            volumeLiters: volumeL,
            note: _note.text,
            diveId: widget.diveId,
            notedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await repo.update(
          existing.copyWith(
            gearType: _gearType,
            label: _label.text,
            clearLabel: _label.text.trim().isEmpty,
            size: _size.text,
            clearSize: _size.text.trim().isEmpty,
            verdict: _verdict,
            leadAdjustmentKg: leadKg,
            clearLeadAdjustment: leadKg == null,
            volumeLiters: volumeL,
            clearVolume: volumeL == null,
            note: _note.text,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // A concurrent sync can delete the center mid-save. Say so and keep
      // the editor open to try again.
      if (mounted) setState(() => _error = l10n.common_error_tryAgain);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final note = widget.editing;
    if (note == null) return;
    final deleted = await confirmDeleteRentalGearNote(context, ref, note);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.editing == null
                  ? l10n.diveCenters_rental_sheetTitleNew
                  : l10n.diveCenters_rental_sheetTitleEdit,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EquipmentType>(
              initialValue: _gearType,
              decoration: InputDecoration(
                labelText: l10n.diveCenters_rental_gearTypeLabel,
              ),
              isExpanded: true,
              items: [
                for (final type in kCanonicalTypeOrder)
                  DropdownMenuItem(
                    value: type,
                    child: Text(type.localizedName(l10n)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _gearType = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              decoration: InputDecoration(
                labelText: l10n.diveCenters_rental_labelLabel,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _size,
              decoration: InputDecoration(
                labelText: l10n.diveCenters_rental_sizeLabel,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<RentalVerdict>(
              segments: [
                ButtonSegment(
                  value: RentalVerdict.worked,
                  label: Text(l10n.diveCenters_rental_verdictWorked),
                ),
                ButtonSegment(
                  value: RentalVerdict.avoid,
                  label: Text(l10n.diveCenters_rental_verdictAvoid),
                ),
              ],
              selected: {_verdict},
              onSelectionChanged: (selection) =>
                  setState(() => _verdict = selection.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lead,
              decoration: InputDecoration(
                labelText: l10n.diveCenters_rental_leadAdjustmentLabel(
                  units.weightSymbol,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            if (_gearType == EquipmentType.tank) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _volume,
                decoration: InputDecoration(
                  labelText: l10n.diveCenters_rental_volumeLabel(
                    units.volumeSymbol,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: l10n.diveCenters_rental_noteLabel,
              ),
              maxLines: 3,
            ),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.editing != null)
                  TextButton(
                    onPressed: _saving ? null : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: Text(l10n.common_action_delete),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_action_cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.common_action_save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
