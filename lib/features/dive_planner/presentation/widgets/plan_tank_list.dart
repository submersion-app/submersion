import 'package:flutter/material.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_saved_tanks_bar.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/tank_role_resolver.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

const _uuid = Uuid();

/// Widget for managing tanks in a dive plan.
class PlanTankList extends ConsumerWidget {
  const PlanTankList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(divePlanNotifierProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    MdiIcons.divingScubaTank,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.divePlanner_label_tanks,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: context.l10n.divePlanner_action_addTank,
                  onPressed: () => _showAddTankDialog(context, ref, units),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Saved tanks, collapsed by default: a bar that opens into the
            // diver's saved cylinders, each a tap away from joining the plan.
            const PlanSavedTanksBar(),

            // Tank chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: planState.tanks.map((tank) {
                return _TankChip(
                  tank: tank,
                  units: units,
                  onEdit: () => _showEditTankDialog(context, ref, tank, units),
                  onDelete: planState.tanks.length > 1
                      ? () => ref
                            .read(divePlanNotifierProvider.notifier)
                            .removeTank(tank.id)
                      : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTankDialog(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    showDialog(
      context: context,
      builder: (context) => _TankEditDialog(
        units: units,
        mode: ref.read(divePlanNotifierProvider).mode,
        bestMix: ref.read(planBestMixProvider),
        resolveRole: _roleResolverFor(ref),
        onSave: (tank) {
          ref.read(divePlanNotifierProvider.notifier).addTank(tank);
        },
      ),
    );
  }

  void _showEditTankDialog(
    BuildContext context,
    WidgetRef ref,
    DiveTank tank,
    UnitFormatter units,
  ) {
    showDialog(
      context: context,
      builder: (context) => _TankEditDialog(
        tank: tank,
        units: units,
        mode: ref.read(divePlanNotifierProvider).mode,
        bestMix: ref.read(planBestMixProvider),
        resolveRole: _roleResolverFor(ref),
        onSave: (updated) {
          ref
              .read(divePlanNotifierProvider.notifier)
              .updateTank(tank.id, updated);
        },
      ),
    );
  }
}

/// The role [TankRoleResolver] would give a cylinder, as the dialog has it
/// so far, once saved into the current plan: in place of the tank with its
/// id, or added to the end when it is new.
TankRole Function(DiveTank provisional) _roleResolverFor(WidgetRef ref) {
  final plan = divePlanFromState(ref.read(divePlanNotifierProvider));
  return (provisional) {
    final isNew = plan.tanks.every((t) => t.id != provisional.id);
    final tanks = [
      for (final t in plan.tanks) t.id == provisional.id ? provisional : t,
      if (isNew) provisional,
    ];
    return const TankRoleResolver().rolesFor(
      plan.copyWith(tanks: tanks),
    )[provisional.id]!;
  };
}

class _TankChip extends StatelessWidget {
  final DiveTank tank;
  final UnitFormatter units;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _TankChip({
    required this.tank,
    required this.units,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tankSize = units.formatTankVolume(tank.volume, tank.workingPressure);
    final tankLabel =
        '${tank.name ?? tank.gasMix.name}, '
        '${units.formatPressure(tank.startPressure)}, '
        '$tankSize';

    return Semantics(
      label: tankLabel,
      child: InputChip(
        avatar: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: ExcludeSemantics(
            child: Text(
              tank.gasMix.name.substring(0, 1),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tank.name ?? tank.gasMix.name),
            Text(
              '${units.formatPressure(tank.startPressure)} • $tankSize',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        onPressed: onEdit,
        deleteIcon: onDelete != null ? const Icon(Icons.close, size: 18) : null,
        onDeleted: onDelete,
      ),
    );
  }
}

class _TankEditDialog extends StatefulWidget {
  final DiveTank? tank;
  final UnitFormatter units;

  /// The plan's breathing mode. Only a loop plan can carry bailout gas, so
  /// the bailout flag is offered there and nowhere else.
  final PlanMode mode;

  /// The plan's best mixes at its deepest point, offered as a one-tap fill
  /// of the O2/He fields: [bestMix.diluent] on a CCR plan unless the
  /// cylinder is ticked as bailout, [bestMix.bottom] otherwise. Null hides
  /// the offer (a plan with no depth).
  final ({double depthMeters, GasMix bottom, GasMix? diluent})? bestMix;

  /// The role the plan would give this cylinder as currently filled in (see
  /// [_roleResolverFor]). Only a CCR diluent is offered [bestMix.diluent],
  /// and the oxygen supply is offered nothing.
  final TankRole Function(DiveTank provisional) resolveRole;
  final ValueChanged<DiveTank> onSave;

  const _TankEditDialog({
    this.tank,
    required this.units,
    required this.mode,
    this.bestMix,
    required this.resolveRole,
    required this.onSave,
  });

  @override
  State<_TankEditDialog> createState() => _TankEditDialogState();
}

class _TankEditDialogState extends State<_TankEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _volumeController;
  late TextEditingController _pressureController;
  late TextEditingController _o2Controller;
  late TextEditingController _heController;

  /// The saved tank's id: the original's, or one minted now for a new tank,
  /// so its provisional role is resolved under the id it will be saved with.
  late final String _tankId = widget.tank?.id ?? _uuid.v4();
  bool _isTravelGas = false;
  bool _isBailout = false;

  /// The volume field's seeded text, so [_save] can tell an untouched field
  /// from an edited one and keep the stored litres exactly (issue #2027).
  late String _initialVolumeText;

  /// Imperial divers name a cylinder by its rated gas capacity in cuft, not
  /// by its water volume, so the field must use the capacity conversion
  /// that [UnitFormatter.formatTankVolume] shows on the chip (issue #2027).
  bool get _isCuft => widget.units.settings.volumeUnit == VolumeUnit.cubicFeet;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tank?.name ?? '');
    // A new tank starts as an 11.1 L cylinder; an existing tank without a
    // volume seeds an empty field, so saving it untouched stores none.
    final volumeLiters = widget.tank == null ? 11.1 : widget.tank!.volume;
    _initialVolumeText = volumeLiters == null
        ? ''
        : formatRoundedForInput(
            _isCuft
                ? ratedCapacityCuft(volumeLiters, widget.tank?.workingPressure)
                : volumeLiters,
            1,
          );
    _volumeController = TextEditingController(text: _initialVolumeText);
    _pressureController = TextEditingController(
      text: formatRoundedForInput(
        widget.units.convertPressure(widget.tank?.startPressure ?? 200),
        0,
      ),
    );
    _o2Controller = TextEditingController(
      text: formatDecimalForInput(widget.tank?.gasMix.o2 ?? 21),
    );
    _heController = TextEditingController(
      text: formatDecimalForInput(widget.tank?.gasMix.he ?? 0),
    );
    _isTravelGas = widget.tank?.isTravelGas ?? false;
    // `role` is no longer a field the diver fills in. The only value that
    // still carries intent is `bailout`, which TankRoleResolver honours as an
    // override because a 100% cylinder on a loop plan could equally be the
    // oxygen supply or a bailout bottle.
    _isBailout = widget.tank?.role == TankRole.bailout;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _volumeController.dispose();
    _pressureController.dispose();
    _o2Controller.dispose();
    _heController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.tank == null;

    return AlertDialog(
      title: Text(
        isNew
            ? context.l10n.divePlanner_action_addTank
            : context.l10n.divePlanner_action_editTank,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.divePlanner_field_name,
                  hintText: context.l10n.divePlanner_hint_tankName,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: NumberField(
                      controller: _volumeController,
                      decoration: InputDecoration(
                        labelText: context.l10n.divePlanner_field_volume(
                          widget.units.volumeSymbol,
                        ),
                      ),
                      // Blocks save through the dialog's Form; the value is
                      // read in _save.
                      onChanged: (_) {},
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: NumberField(
                      controller: _pressureController,
                      decoration: InputDecoration(
                        labelText: context.l10n.divePlanner_field_startPressure(
                          widget.units.pressureSymbol,
                        ),
                      ),
                      onChanged: (_) {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _o2Controller,
                      decoration: InputDecoration(
                        labelText: context.l10n.divePlanner_field_o2Percent,
                      ),
                      keyboardType: TextInputType.number,
                      // The best-mix offer depends on the mix (#3093).
                      onChanged: (_) => setState(() {}),
                      validator: (value) => _validateGasPercent(
                        value,
                        _otherPercent(_heController),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _heController,
                      decoration: InputDecoration(
                        labelText: context.l10n.divePlanner_field_hePercent,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      validator: (value) => _validateGasPercent(
                        value,
                        _otherPercent(_o2Controller),
                      ),
                    ),
                  ),
                ],
              ),
              if ((widget.bestMix, _offeredMix) case (
                final bestMix?,
                final mix?,
              ))
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: Text(
                      context.l10n.divePlanner_action_fillBestMix(
                        widget.units.formatDepth(
                          bestMix.depthMeters,
                          decimals: 0,
                        ),
                        mix.name,
                      ),
                    ),
                    onPressed: () => _fillGas(mix),
                  ),
                ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _isTravelGas,
                title: Text(context.l10n.divePlanner_field_travelGas),
                onChanged: (value) {
                  setState(() => _isTravelGas = value ?? false);
                },
              ),
              if (widget.mode != PlanMode.oc)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _isBailout,
                  title: Text(context.l10n.divePlanner_field_bailoutGas),
                  subtitle: Text(
                    context.l10n.divePlanner_field_bailoutGasHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onChanged: (value) {
                    setState(() => _isBailout = value ?? false);
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.l10n.common_action_save),
        ),
      ],
    );
  }

  /// The best mix offered for this cylinder, by the role the plan would give
  /// it as currently filled in. A CCR diluent (a cylinder the segments
  /// breathe) gets the diluent mix. The oxygen supply (unbreathed pure O2,
  /// including one being typed into a new cylinder) gets nothing, since any
  /// mix would overwrite its O2. Everything else, a ticked or derived bailout
  /// or any open-circuit cylinder, is breathed open circuit and gets the
  /// bottom mix.
  GasMix? get _offeredMix {
    final bestMix = widget.bestMix;
    if (bestMix == null) return null;
    final provisional = DiveTank(
      id: _tankId,
      gasMix: GasMix(
        o2: _otherPercent(_o2Controller) ?? 21,
        he: _otherPercent(_heController) ?? 0,
      ),
      role: _isBailout ? TankRole.bailout : TankRole.backGas,
      isTravelGas: _isTravelGas,
    );
    return switch (widget.resolveRole(provisional)) {
      TankRole.oxygenSupply => null,
      TankRole.diluent => bestMix.diluent ?? bestMix.bottom,
      _ => bestMix.bottom,
    };
  }

  /// Writes [mix] into the O2/He fields; the diver still saves the dialog.
  /// Re-validates so an error left by an earlier save attempt on either
  /// field clears now that it holds a valid mix.
  void _fillGas(GasMix mix) {
    _o2Controller.text = formatDecimalForInput(mix.o2);
    _heController.text = formatDecimalForInput(mix.he);
    _formKey.currentState?.validate();
  }

  /// Empty is fine ([_save] defaults it); anything else must parse to a
  /// percentage in [0, 100] (#1900), and combined with [otherPercent] --
  /// the sibling O2/He field's own current value -- must not exceed 100.
  /// GasMix derives N2 as the remainder of the two, so an over-100 mix
  /// feeds a negative N2 fraction straight into gas-planning math.
  String? _validateGasPercent(String? value, double? otherPercent) =>
      numberValidator(
        context,
        check: (percent) {
          // One field out of range gets a range message; the combined
          // O2 + He message below is only for the sum.
          if (percent < 0 || percent > 100) {
            return context.l10n.numberInput_percentRange;
          }
          if (otherPercent != null && percent + otherPercent > 100) {
            return context.l10n.gasCalculators_blender_templateInvalid;
          }
          return null;
        },
      )(value);

  /// The sibling O2/He field's percentage for the sum check, or null when it
  /// is blank or unreadable (that field reports its own error).
  double? _otherPercent(TextEditingController controller) =>
      switch (readNumber(controller.text)) {
        NumberValue(:final value) => value,
        NumberBlank() || NumberInvalid() => null,
      };

  /// A field's number once [_formKey] has validated: blank is [blank], and
  /// unreadable text cannot reach here.
  double? _validated(TextEditingController controller, {double? blank}) =>
      switch (readNumber(controller.text)) {
        NumberValue(:final value) => value,
        NumberBlank() => blank,
        NumberInvalid() => blank, // unreachable: validate() blocked the save
      };

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final parsedPressure = _validated(_pressureController);
    final startPressureBar = parsedPressure != null
        ? widget.units.pressureToBar(parsedPressure)
        : null;
    final specs = _volumeSpecs(startPressureBar);
    final original = widget.tank;

    final tank = DiveTank(
      id: _tankId,
      name: _nameController.text.isNotEmpty ? _nameController.text : null,
      volume: specs.volumeLiters,
      workingPressure: specs.workingPressureBar,
      startPressure: startPressureBar,
      // Carried over rather than dropped: this dialog does not show them, so
      // a save must not erase them. A preset name only still describes the
      // cylinder while its size is untouched.
      endPressure: original?.endPressure,
      material: original?.material,
      presetName: specs.volumeEdited ? null : original?.presetName,
      computerId: original?.computerId,
      transmitterSerial: original?.transmitterSerial,
      sourceTankIndex: original?.sourceTankIndex,
      regulatorEquipmentId: original?.regulatorEquipmentId,
      equipmentId: original?.equipmentId,
      decoSwitchDepth: original?.decoSwitchDepth,
      gasMix: GasMix(
        o2: _validated(_o2Controller, blank: 21)!,
        he: _validated(_heController, blank: 0)!,
      ),
      // Everything except an explicit bailout is derived by
      // TankRoleResolver; backGas is the neutral "derive me" placeholder.
      role: _isBailout ? TankRole.bailout : TankRole.backGas,
      order: widget.tank?.order ?? 0,
      isTravelGas: _isTravelGas,
    );

    widget.onSave(tank);
    Navigator.pop(context);
  }

  /// The cylinder's physical volume and working pressure from the volume
  /// field (issue #2027).
  ///
  /// An existing tank's untouched field keeps its stored litres and working
  /// pressure exactly, so opening and saving it never drifts them through
  /// display rounding. Otherwise the field is read as typed. A new tank takes
  /// the start pressure entered as its working pressure. A cuft value is
  /// rated gas capacity: it resolves to litres at the tank's working
  /// pressure, falling back to the start pressure (which it then keeps) so
  /// the chip reads back the number in the field.
  ({double? volumeLiters, double? workingPressureBar, bool volumeEdited})
  _volumeSpecs(double? startPressureBar) {
    final original = widget.tank;
    if (original != null && _volumeController.text == _initialVolumeText) {
      return (
        volumeLiters: original.volume,
        workingPressureBar: original.workingPressure,
        volumeEdited: false,
      );
    }
    final parsed = _validated(_volumeController);
    if (!_isCuft) {
      return (
        volumeLiters: parsed,
        workingPressureBar: original == null
            ? startPressureBar
            : original.workingPressure,
        volumeEdited: true,
      );
    }
    final workingPressureBar = original?.workingPressure ?? startPressureBar;
    return (
      volumeLiters: parsed != null
          ? volumeLitersFromCapacity(parsed, workingPressureBar)
          : null,
      workingPressureBar: workingPressureBar,
      volumeEdited: true,
    );
  }
}
