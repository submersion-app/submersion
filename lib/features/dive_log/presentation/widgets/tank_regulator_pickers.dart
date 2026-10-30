import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_dropdown_label.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The regulators breathed from one cylinder (v202, and from v312 more than
/// one, issue #3375): a "Regulator" picker, then "Regulator 2", "Regulator
/// 3" and so on, each removable, added through "Add regulator" once the
/// first is chosen. A twin valve or a manifolded twin set carries two or
/// more, and each one's service clocks need the dive.
///
/// [regulatorIds] is the first, then the extras; [onChanged] reports the
/// whole list. Setting the first to None moves the next one up.
class TankRegulatorPickers extends ConsumerStatefulWidget {
  const TankRegulatorPickers({
    super.key,
    required this.regulatorIds,
    required this.onChanged,
  });

  final List<String> regulatorIds;
  final ValueChanged<List<String>> onChanged;

  @override
  ConsumerState<TankRegulatorPickers> createState() =>
      _TankRegulatorPickersState();
}

class _TankRegulatorPickersState extends ConsumerState<TankRegulatorPickers> {
  /// Whether the pickers also list retired and sold regulators, which only
  /// the last item of a picker turns on (#3210).
  bool _showLeftKit = false;

  /// An added picker nothing has been chosen in yet. It reports nothing, so
  /// a tank saved with it empty keeps the regulators it had.
  bool _adding = false;

  /// The value of that last item. Not a regulator: choosing it changes the
  /// list instead.
  static const _showLeftKitValue = '__show-left-kit-regulators__';

  @override
  void didUpdateWidget(TankRegulatorPickers oldWidget) {
    super.didUpdateWidget(oldWidget);
    // With no regulator left there is nothing to add to: an empty picker
    // added before must not reappear when a prefill fills the list.
    if (widget.regulatorIds.isEmpty) _adding = false;
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.regulatorIds;
    final regs =
        // `value`, not `valueOrNull`: it keeps the previous list while the
        // provider reloads, so the tank's regulators do not flicker to None.
        (ref.watch(activeEquipmentProvider).value ?? const <EquipmentItem>[])
            .where((e) => e.type == EquipmentType.regulator)
            // Spare regulators are not offered (#1803), except one this tank
            // already uses, so an existing dive never reads "None".
            .where(
              (e) => e.status != EquipmentStatus.spare || ids.contains(e.id),
            )
            .toList();
    final leftKit =
        (ref.watch(leftKitEquipmentProvider).value ?? const <EquipmentItem>[])
            .where((e) => e.type == EquipmentType.regulator)
            .toList();
    // Retired and sold regulators only on request (#3210), except one this
    // tank already uses, so a dive breathing from a regulator since retired
    // never reads "None".
    final all = [
      ...regs,
      for (final r in leftKit)
        if (_showLeftKit || ids.contains(r.id)) r,
    ];
    final offerShowLeftKit = all.length < regs.length + leftKit.length;
    // Labelled as one list, so regulators sharing a name show their ID and,
    // if that is not enough, the next detail that differs (#1549, #3191).
    final labels = equipmentRowLabelsOf(context, ref, all);
    // Retired and sold ones count too: the added picker offers them through
    // its show item, so a dive logged with one can still list it.
    final canAdd =
        ids.isNotEmpty &&
        !_adding &&
        [...regs, ...leftKit].any((r) => !ids.contains(r.id));

    Widget picker(int index) {
      final value = index < ids.length ? ids[index] : null;
      // Each regulator once per tank: the others' choices are not offered.
      final options = [
        for (final r in all)
          if (r.id == value || !ids.contains(r.id)) r,
      ];
      final known = options.any((r) => r.id == value);
      final number = index + 1;
      final field = DropdownButtonFormField<String?>(
        key: Key(
          index == 0
              ? 'tank-regulator-picker'
              : 'tank-regulator-picker-$number',
        ),
        initialValue: known ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: index == 0
              ? context.l10n.diveLog_tank_regulatorLabel
              : context.l10n.diveLog_tank_regulatorNumbered(number),
          isDense: true,
        ),
        items: [
          // Extras are removed with their button, not set to None.
          if (index == 0)
            DropdownMenuItem<String?>(
              value: null,
              child: Text(context.l10n.diveLog_tank_regulatorNone),
            ),
          for (final r in options)
            DropdownMenuItem<String?>(
              value: r.id,
              child: EquipmentDropdownLabel(
                item: r,
                label: labels[r.id],
                note: r.hasLeftKit
                    ? r.effectiveStatus.localizedName(context.l10n)
                    : null,
              ),
            ),
          if (offerShowLeftKit)
            DropdownMenuItem<String?>(
              value: _showLeftKitValue,
              child: Text(
                context.l10n.diveLog_tank_regulatorShowLeftKit,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
        onChanged: (chosen) {
          if (chosen == _showLeftKitValue) {
            setState(() => _showLeftKit = true);
            return;
          }
          if (index >= ids.length) {
            setState(() => _adding = false);
            if (chosen != null) widget.onChanged([...ids, chosen]);
            return;
          }
          widget.onChanged([
            for (var i = 0; i < ids.length; i++)
              if (i != index) ids[i] else ?chosen,
          ]);
        },
      );
      // Keyed on what it shows: the field holds its value internally, so a
      // list that changed outside it (a removal, a move up, a prefill) or
      // the show choice starts a fresh field from the new value.
      final keyed = KeyedSubtree(
        key: ValueKey((number, value, _showLeftKit)),
        child: field,
      );
      if (index == 0) return keyed;
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(child: keyed),
            IconButton(
              key: Key('tank-remove-regulator-$number'),
              icon: const Icon(Icons.close),
              tooltip: context.l10n.diveLog_tank_removeRegulator,
              onPressed: () {
                if (index >= ids.length) {
                  setState(() => _adding = false);
                  return;
                }
                widget.onChanged([...ids]..removeAt(index));
              },
            ),
          ],
        ),
      );
    }

    final count = ids.isEmpty ? 1 : ids.length + (_adding ? 1 : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < count; i++) picker(i),
        if (canAdd)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('tank-add-regulator'),
              onPressed: () => setState(() => _adding = true),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.l10n.diveLog_tank_addRegulator),
            ),
          ),
      ],
    );
  }
}
