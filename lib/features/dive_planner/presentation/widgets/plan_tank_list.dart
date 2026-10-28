import 'package:flutter/material.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/deco/deco_ppo2_limits.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_saved_tanks_bar.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/plan_tank_chip.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/tank_mod.dart';
import 'package:submersion/features/planner/domain/services/tank_role_resolver.dart';
import 'package:submersion/features/planner/presentation/widgets/tank_mod_field.dart';
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
    // The planner derives roles rather than storing them, so each chip's
    // glyph follows the plan as the diver edits it (issue #2901).
    final roles = const TankRoleResolver().rolesFor(
      divePlanFromState(planState),
    );

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

            // A CCR plan groups its two mandatory loop slots -- the
            // diluent(s) and the oxygen supply -- apart from the open-circuit
            // bailout cylinders, which is what every other cylinder is
            // (#3220). Neither slot is ever bailout gas; a diver who wants
            // oxygen on bailout adds a separate cylinder below.
            if (planState.mode == PlanMode.ccr) ...[
              _groupHeading(theme, context.l10n.divePlanner_label_loopGases),
              _chips(
                context,
                ref,
                units,
                planState,
                roles,
                _loopTanks(planState),
              ),
              const SizedBox(height: 12),
              _groupHeading(theme, context.l10n.divePlanner_label_bailoutGases),
              if (_bailoutTanks(planState).isEmpty)
                Text(
                  context.l10n.divePlanner_label_noBailout,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                )
              else
                _chips(
                  context,
                  ref,
                  units,
                  planState,
                  roles,
                  _bailoutTanks(planState),
                ),
            ] else
              _chips(context, ref, units, planState, roles, planState.tanks),
          ],
        ),
      ),
    );
  }

  /// Diluent(s) first, then the oxygen slot.
  static List<DiveTank> _loopTanks(DivePlanState s) => [
    ...s.tanks.where((t) => t.role == TankRole.diluent),
    ...s.tanks.where((t) => t.role == TankRole.oxygenSupply),
  ];

  static List<DiveTank> _bailoutTanks(DivePlanState s) => s.tanks
      .where(
        (t) => t.role != TankRole.diluent && t.role != TankRole.oxygenSupply,
      )
      .toList();

  /// Whether the chip offers a delete: never the last cylinder, and on a CCR
  /// plan never the oxygen slot or the last diluent (#3220).
  static bool _canDelete(DivePlanState s, DiveTank tank) {
    if (s.tanks.length <= 1) return false;
    if (s.mode != PlanMode.ccr) return true;
    if (tank.role == TankRole.oxygenSupply) return false;
    if (tank.role == TankRole.diluent) {
      return s.tanks.where((t) => t.role == TankRole.diluent).length > 1;
    }
    return true;
  }

  Widget _groupHeading(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.outline,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _chips(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
    DivePlanState planState,
    Map<String, TankRole> roles,
    List<DiveTank> tanks,
  ) {
    final isCcr = planState.mode == PlanMode.ccr;
    final limits = _modLimits(planState, units);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tanks.map((tank) {
        final isLoopSlot =
            isCcr &&
            (tank.role == TankRole.diluent ||
                tank.role == TankRole.oxygenSupply);
        final role = roles[tank.id] ?? tank.role;
        final modCheck = modOverrideCheck(
          tank.copyWith(role: role),
          bottomPpO2: limits.bottom,
          decoPpO2: limits.deco,
          diluentPpO2: limits.diluent,
        );
        return PlanTankChip(
          tank: tank,
          role: role,
          units: units,
          modLabel: switch (tank.decoSwitchDepth) {
            final depth? => context.l10n.tankMod_chip(
              units.formatDepth(depth, decimals: 0),
            ),
            null => null,
          },
          modExceedsLimit: modCheck?.exceedsLimit ?? false,
          roleBadge: isLoopSlot ? tank.role.localizedName(context.l10n) : null,
          onEdit: () => _showEditTankDialog(context, ref, tank, units),
          onDelete: _canDelete(planState, tank)
              ? () => ref
                    .read(divePlanNotifierProvider.notifier)
                    .removeTank(tank.id)
              : null,
        );
      }).toList(),
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
        modLimits: _modLimits(ref.read(divePlanNotifierProvider), units),
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
    final planState = ref.read(divePlanNotifierProvider);
    final isCcr = planState.mode == PlanMode.ccr;
    showDialog(
      context: context,
      builder: (context) => _TankEditDialog(
        tank: tank,
        units: units,
        modLimits: _modLimits(planState, units),
        mode: planState.mode,
        lockedOxygenSlot: isCcr && tank.role == TankRole.oxygenSupply,
        isOnlyDiluent:
            isCcr &&
            tank.role == TankRole.diluent &&
            planState.tanks.where((t) => t.role == TankRole.diluent).length ==
                1,
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

/// The ppO2 limits each tank's default MOD is worked out at (issue #3567):
/// the plan's own, falling back to the diver's settings, as the plan engine
/// resolves them. [deco] carries the per-O2-band limits too (issue #3580),
/// including this plan's own Off/Custom choice (issue #3580 follow-up,
/// caught by a Copilot review): a plan that turned bands/explicit-depth off
/// must size a tank's default MOD the same way the plan engine itself
/// would, not fall back to the Settings toggle as if the plan had no say.
({double bottom, DecoPpO2Limits deco, double diluent}) _modLimits(
  DivePlanState state,
  UnitFormatter units,
) => (
  bottom: state.ppO2Bottom ?? units.settings.ppO2MaxWorking,
  deco: DecoPpO2Limits.forPlan(
    flat: state.ppO2Deco ?? units.settings.ppO2MaxDeco,
    settingsBandsEnabled: units.settings.ppO2DecoBandsEnabled,
    settingsBand1: units.settings.ppO2DecoBand1,
    settingsBand2: units.settings.ppO2DecoBand2,
    settingsBand3: units.settings.ppO2DecoBand3,
    settingsMaxO2DepthEnabled: units.settings.maxO2DepthEnabled,
    settingsMaxO2DepthMeters: units.settings.maxO2DepthMeters,
    band1: state.ppO2DecoBand1,
    band2: state.ppO2DecoBand2,
    band3: state.ppO2DecoBand3,
    bandsExplicitlyOff: state.ppO2DecoBandsExplicitlyOff,
    maxO2DepthMeters: state.maxO2DepthMeters,
    maxO2DepthExplicitlyOff: state.maxO2DepthExplicitlyOff,
  ),
  diluent: units.settings.ccrDiluentModPpO2,
);

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

class _TankEditDialog extends StatefulWidget {
  final DiveTank? tank;
  final UnitFormatter units;

  /// The ppO2 limits the tank's default MOD is worked out at (#3567).
  final ({double bottom, DecoPpO2Limits deco, double diluent}) modLimits;

  /// The plan's breathing mode. Only a loop plan can carry bailout gas, so
  /// the diluent flag is offered there and nowhere else.
  final PlanMode mode;

  /// Editing a CCR plan's oxygen slot: the mix is fixed at 100 % and the
  /// role at oxygen supply, so neither field nor the diluent tile is shown
  /// (#3220). Name, size and pressure stay editable.
  final bool lockedOxygenSlot;

  /// Editing a CCR plan's only diluent: the tile shows ticked and cannot be
  /// unticked, since the plan always keeps at least one (#3220).
  final bool isOnlyDiluent;

  /// The plan's best mixes at its deepest point, offered as a one-tap fill
  /// of the O2/He fields: [bestMix.diluent] on a CCR plan if the cylinder
  /// would resolve to the diluent, [bestMix.bottom] otherwise. Null hides
  /// the offer (a plan with no depth). Never offered on the oxygen slot,
  /// whose fields are not even shown (#3220).
  final ({double depthMeters, GasMix bottom, GasMix? diluent})? bestMix;

  /// The role the plan would give this cylinder as currently filled in (see
  /// [_roleResolverFor]). Only a CCR diluent is offered [bestMix.diluent],
  /// and the oxygen supply is offered nothing.
  final TankRole Function(DiveTank provisional) resolveRole;
  final ValueChanged<DiveTank> onSave;

  const _TankEditDialog({
    this.tank,
    required this.units,
    required this.modLimits,
    required this.mode,
    this.lockedOxygenSlot = false,
    this.isOnlyDiluent = false,
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
  bool _isDiluent = false;

  /// The MOD set by hand in metres, or null for the default (#3567).
  late double? _modOverride = widget.tank?.decoSwitchDepth;

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
        widget.units.convertPressure(
          widget.tank?.startPressure ?? TankPresets.planFillPressureBar,
        ),
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
    // `role` is no longer a field the diver fills in, except on a loop plan:
    // diluent is the one explicit choice there, which TankRoleResolver
    // honours and never re-derives from anything else (#3135).
    _isDiluent = widget.tank?.role == TankRole.diluent;
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
              if (!widget.lockedOxygenSlot) ...[
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
                const SizedBox(height: 16),
                TankModField(
                  gas: _provisionalGas,
                  role: widget.resolveRole(_provisionalTank),
                  overrideMeters: _modOverride,
                  bottomPpO2: widget.modLimits.bottom,
                  decoPpO2: widget.modLimits.deco,
                  diluentPpO2: widget.modLimits.diluent,
                  units: widget.units,
                  onChanged: (meters) => setState(() => _modOverride = meters),
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
                // CCR has no travel-gas concept: TankRoleResolver's loop branch
                // never consults isTravelGas, so the option is meaningless
                // there and only confuses a diluent/bailout choice (#3131).
                if (widget.mode != PlanMode.ccr)
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
                    value: _isDiluent,
                    title: Text(context.l10n.divePlanner_field_diluentGas),
                    subtitle: Text(
                      context.l10n.divePlanner_field_diluentGasHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onChanged: widget.isOnlyDiluent
                        ? null
                        : (value) {
                            setState(() => _isDiluent = value ?? false);
                          },
                  ),
              ],
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

  /// The mix as the O2/He fields hold it so far.
  GasMix get _provisionalGas => GasMix(
    o2: _otherPercent(_o2Controller) ?? 21,
    he: _otherPercent(_heController) ?? 0,
  );

  /// The tank as the dialog has it so far, for the role the plan would give
  /// it: the best-mix offer and the default MOD both follow that role.
  DiveTank get _provisionalTank => DiveTank(
    id: _tankId,
    gasMix: _provisionalGas,
    // Mirrors _save()'s own role construction exactly, so both are worked
    // out against the same provisional role the save would actually produce.
    role: widget.lockedOxygenSlot
        ? TankRole.oxygenSupply
        : _isDiluent
        ? TankRole.diluent
        : TankRole.backGas,
    isTravelGas: _isTravelGas,
  );

  /// The best mix offered for this cylinder, by the role the plan would give
  /// it as currently filled in. The explicit diluent tile (#3220) gets the
  /// diluent mix; the locked oxygen slot never reaches here, since its
  /// fields -- and this button -- are not shown at all. Everything else,
  /// ticked or not, resolves through [TankRoleResolver] like any other
  /// cylinder and gets the bottom mix.
  GasMix? get _offeredMix {
    final bestMix = widget.bestMix;
    if (bestMix == null) return null;
    return switch (widget.resolveRole(_provisionalTank)) {
      TankRole.oxygenSupply => null,
      TankRole.diluent => bestMix.diluent ?? bestMix.bottom,
      _ => bestMix.bottom,
    };
  }

  /// Writes [mix] into the O2/He fields; the diver still saves the dialog.
  /// A programmatic write fires no onChanged, so this rebuilds itself: the
  /// offer follows the mix (a fill can make the cylinder the oxygen supply).
  /// Re-validates so an error left by an earlier save attempt on either
  /// field clears now that it holds a valid mix.
  void _fillGas(GasMix mix) {
    setState(() {
      _o2Controller.text = formatDecimalForInput(mix.o2);
      _heController.text = formatDecimalForInput(mix.he);
    });
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
      extraRegulatorIds: original?.extraRegulatorIds ?? const [],
      equipmentId: original?.equipmentId,
      decoSwitchDepth: _modOverride,
      gasMix: widget.lockedOxygenSlot
          ? const GasMix(o2: 100)
          : GasMix(
              o2: _validated(_o2Controller, blank: 21)!,
              he: _validated(_heController, blank: 0)!,
            ),
      // Everything except an explicit loop slot (CCR: diluent or the oxygen
      // supply) is derived by TankRoleResolver; backGas is the neutral
      // "derive me" placeholder.
      role: widget.lockedOxygenSlot
          ? TankRole.oxygenSupply
          : _isDiluent
          ? TankRole.diluent
          : TankRole.backGas,
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
