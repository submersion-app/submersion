import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_template_display.dart';
import 'package:submersion/core/constants/gas_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/deco_ppo2_limits.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_mnd_field.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_preset_dropdown.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_role_option.dart';
import 'package:submersion/features/planner/domain/services/tank_mod.dart';
import 'package:submersion/features/planner/presentation/widgets/tank_mod_field.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// One editable cylinder inside a configuration, laid out like the dive
/// log's tank card (issue #3576): the label and gas name, then preset and
/// role, size, then the mix.
///
/// Only what a saved cylinder needs: no material, regulator or pressures,
/// and in place of N2 (which follows from O2 and He) the cylinder's MOD,
/// which the diver can set by hand (issue #3567). Fields not shown here,
/// material and default start pressure among them, are kept as they are.
///
/// Spec fields are plain editable values, not a live preset reference: the
/// preset picker only seeds them. A configuration records what the diver
/// actually dives, so a later preset edit must not rewrite it.
class CylinderConfigItemEditor extends StatefulWidget {
  const CylinderConfigItemEditor({
    super.key,
    required this.item,
    required this.number,
    required this.units,
    required this.onChanged,
    required this.onRemove,
    this.reserveDragHandle = false,
  });

  /// The label field, for tests that check the header's alignment.
  static const labelFieldKey = ValueKey('cylinderConfigItem.label');

  /// End padding that keeps the fields clear of a reorderable list's
  /// default drag handle, which is drawn over the card's end edge: 24 for
  /// the icon, 8 the list leaves outside it, and 8 between it and a field.
  static const double dragHandleInset = 40;

  final CylinderConfigItem item;

  /// The cylinder's position in the configuration, from 1: the label's hint
  /// while it has none.
  final int number;

  /// Whether the card sits under a visible drag handle, so its fields stop
  /// short of it. See [dragHandleInset].
  final bool reserveDragHandle;

  /// The diver's units, and through them the ppO2 limits and MND settings
  /// the MOD and MND are worked out with.
  final UnitFormatter units;
  final ValueChanged<CylinderConfigItem> onChanged;
  final VoidCallback onRemove;

  @override
  State<CylinderConfigItemEditor> createState() =>
      _CylinderConfigItemEditorState();
}

class _CylinderConfigItemEditorState extends State<CylinderConfigItemEditor> {
  late final TextEditingController _label;
  late final TextEditingController _volume;
  late final TextEditingController _workingPressure;
  late final TextEditingController _o2;
  late final TextEditingController _he;

  /// The preset last picked this session, so the dropdown shows it. A saved
  /// cylinder records its size, not the preset it came from.
  String? _presetName;

  /// MODs set by hand that a role or mix change put aside this session,
  /// keyed by which limit they were set against (issue #3567). A cylinder
  /// moved onto a different limit takes its default; changing back restores
  /// the MOD, so a slip of the dropdown loses nothing. The mix counts too: a
  /// bailout richer than air follows the deco limit, leaner the bottom one. What is saved is only the MOD in effect, so
  /// this goes with the page.
  final Map<ModLimitClass, double> _setAsideMods = {};

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _label = TextEditingController(text: item.label ?? '');
    _volume = TextEditingController(
      text: _volumeText(item.volumeL, item.workingPressureBar),
    );
    _workingPressure = TextEditingController(
      text: _pressureText(item.workingPressureBar),
    );
    _o2 = TextEditingController(text: _trim(item.o2Percent));
    _he = TextEditingController(text: _trim(item.hePercent));
  }

  @override
  void dispose() {
    _label.dispose();
    _volume.dispose();
    _workingPressure.dispose();
    _o2.dispose();
    _he.dispose();
    super.dispose();
  }

  CylinderConfigItem get _item => widget.item;
  UnitFormatter get _units => widget.units;

  /// Imperial divers name a cylinder by its rated gas capacity, not its
  /// water volume, so the field reads and writes cuft as capacity at the
  /// working pressure, as the dive log and planner tank fields do.
  bool get _isCuft => _units.settings.volumeUnit == VolumeUnit.cubicFeet;

  /// A gas fraction as the diver's locale writes it: 21 stays "21", 32.5
  /// becomes "32,5" for a comma-decimal diver (#1091).
  static String _trim(double value) => formatDecimalForInput(value);

  String _volumeText(double? liters, double? workingPressureBar) {
    if (liters == null) return '';
    return _isCuft
        ? formatRoundedForInput(
            ratedCapacityCuft(liters, workingPressureBar),
            0,
          )
        : formatRoundedForInput(liters, 1);
  }

  String _pressureText(double? bar) =>
      bar == null ? '' : formatRoundedForInput(_units.convertPressure(bar), 0);

  GasMix get _gas => GasMix(o2: _item.o2Percent, he: _item.hePercent);

  void _emit(CylinderConfigItem item) => widget.onChanged(item);

  // ---------------------------------------------------------------- size

  /// Litres for the volume field's text at [workingPressureBar], or null
  /// for a blank or unreadable field.
  double? _litersFrom(String text, double? workingPressureBar) {
    if (readNumber(text) case NumberValue(:final value)) {
      return _isCuft
          ? volumeLitersFromCapacity(value, workingPressureBar)
          : value;
    }
    return null;
  }

  void _onVolume(NumberRead read) {
    switch (read) {
      case NumberValue():
        _emit(
          _item.copyWith(
            volumeL: _litersFrom(_volume.text, _item.workingPressureBar),
          ),
        );
      case NumberBlank():
        _emit(_item.copyWith(clearVolumeL: true));
      case NumberInvalid():
        break;
    }
  }

  void _onWorkingPressure(NumberRead read) {
    switch (read) {
      case NumberValue(:final value):
        final bar = _units.pressureToBar(value);
        // A cuft size is capacity at the working pressure, so the litres it
        // stands for move with it.
        final liters = _isCuft ? _litersFrom(_volume.text, bar) : null;
        _emit(
          _item.copyWith(
            workingPressureBar: bar,
            volumeL: liters ?? _item.volumeL,
          ),
        );
      case NumberBlank():
        _emit(_item.copyWith(clearWorkingPressureBar: true));
      case NumberInvalid():
        break;
    }
  }

  void _applyPreset(TankPresetEntity preset) {
    final keepLabel = _item.label != null;
    _emit(
      _item.copyWith(
        volumeL: preset.volumeLiters,
        workingPressureBar: preset.workingPressureBar,
        tankMaterial: preset.material,
        label: _item.label ?? preset.displayName,
      ),
    );
    setState(() {
      _presetName = preset.name;
      _volume.text = _volumeText(
        preset.volumeLiters,
        preset.workingPressureBar,
      );
      _workingPressure.text = _pressureText(preset.workingPressureBar);
      if (!keepLabel) _label.text = preset.displayName;
    });
  }

  // ---------------------------------------------------------------- role

  void _onRole(TankRole role) => _emitOnLimit(_item.copyWith(tankRole: role));

  /// Emits [next], a role or mix change, with the MOD for the limit it
  /// follows: a MOD set by hand moves to [_setAsideMods] when [next] is on a
  /// different limit, and one set aside for [next]'s limit comes back.
  void _emitOnLimit(CylinderConfigItem next) {
    final fromClass = modLimitClassFor(_item.tankRole, _gas);
    final toClass = modLimitClassFor(
      next.tankRole,
      GasMix(o2: next.o2Percent, he: next.hePercent),
    );
    if (fromClass == toClass) {
      _emit(next);
      return;
    }
    if (_item.decoSwitchDepth case final mod?) _setAsideMods[fromClass] = mod;
    _emit(switch (_setAsideMods.remove(toClass)) {
      final restored? => next.copyWith(decoSwitchDepth: restored),
      null => next.copyWith(clearDecoSwitchDepth: true),
    });
  }

  // ----------------------------------------------------------------- gas

  void _setGas(double o2, double he) {
    _emitOnLimit(_item.copyWith(o2Percent: o2, hePercent: he));
    setState(() {
      _o2.text = _trim(o2);
      _he.text = _trim(he);
    });
  }

  /// Puts the He an MND worked out on the cylinder and in the He field.
  void _setHeFromMnd(double he) {
    _emit(_item.copyWith(hePercent: he));
    _he.text = _trim(he);
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = _item;
    final gas = _gas;
    final settings = _units.settings;
    // No plan context here (this is the saved-cylinder-config editor, not
    // the planner), so always the diver's full Settings resolution,
    // issue #3580.
    final decoPpO2Limits = DecoPpO2Limits.forPlan(
      flat: settings.ppO2MaxDeco,
      settingsBandsEnabled: settings.ppO2DecoBandsEnabled,
      settingsBand1: settings.ppO2DecoBand1,
      settingsBand2: settings.ppO2DecoBand2,
      settingsBand3: settings.ppO2DecoBand3,
      settingsMaxO2DepthEnabled: settings.maxO2DepthEnabled,
      settingsMaxO2DepthMeters: settings.maxO2DepthMeters,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          16,
          16,
          widget.reserveDragHandle
              ? CylinderConfigItemEditor.dragHandleInset
              : 16,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label with delete, centred on the field, then the gas.
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: CylinderConfigItemEditor.labelFieldKey,
                    controller: _label,
                    decoration: InputDecoration(
                      labelText: l10n.cylinderConfigs_label,
                      hintText: l10n.diveLog_tank_title(widget.number),
                      isDense: true,
                    ),
                    onChanged: (text) => _emit(
                      text.trim().isEmpty
                          ? item.copyWith(clearLabel: true)
                          : item.copyWith(label: text),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline),
                  color: scheme.error,
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).deleteButtonTooltip,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              gas.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Preset and role.
            Row(
              children: [
                Expanded(
                  child: TankPresetDropdown(
                    presetName: _presetName,
                    // A saved cylinder is not dive gear: the diver's own
                    // cylinders are not offered here.
                    cylinders: const [],
                    onPresetChanged: (preset) {
                      if (preset != null) {
                        _applyPreset(preset);
                      } else {
                        setState(() => _presetName = null);
                      }
                    },
                    onCylinderChosen: (_) {},
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<TankRole>(
                    initialValue: item.tankRole,
                    // Lets a long role name ellipsize beside its glyph
                    // instead of overflowing a narrow field.
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.cylinderConfigs_role,
                      isDense: true,
                    ),
                    items: [
                      for (final role in TankRole.values)
                        DropdownMenuItem(
                          value: role,
                          child: TankRoleOption(role: role),
                        ),
                    ],
                    onChanged: (role) {
                      if (role != null) _onRole(role);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Size.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NumberField(
                    controller: _volume,
                    decoration: InputDecoration(
                      labelText: l10n.diveLog_tank_label_volume,
                      suffixText: _units.volumeSymbol,
                      isDense: true,
                    ),
                    onChanged: _onVolume,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NumberField(
                    controller: _workingPressure,
                    decoration: InputDecoration(
                      labelText: l10n.diveLog_tank_label_workingPressure,
                      suffixText: _units.pressureSymbol,
                      isDense: true,
                    ),
                    onChanged: _onWorkingPressure,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Gas.
            Text(
              l10n.diveLog_tank_section_gasMix,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final template in [
                  ...GasTemplates.recreational,
                  ...GasTemplates.deco,
                  ...GasTemplates.technical.take(2),
                ])
                  FilterChip(
                    label: Text(template.localizedDisplayName(l10n)),
                    selected:
                        item.o2Percent == template.o2 &&
                        item.hePercent == template.he,
                    onSelected: (_) => _setGas(template.o2, template.he),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NumberField(
                    controller: _o2,
                    decoration: InputDecoration(
                      labelText: l10n.diveLog_tank_label_o2,
                      suffixText: '%',
                      isDense: true,
                    ),
                    // Only a readable value updates the model: blank, and
                    // transient or mistyped text such as a lone ".", must
                    // not clobber the stored mix; the field says why.
                    onChanged: (read) {
                      if (read case NumberValue(:final value)) {
                        _emitOnLimit(item.copyWith(o2Percent: value));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NumberField(
                    controller: _he,
                    decoration: InputDecoration(
                      labelText: l10n.diveLog_tank_label_he,
                      suffixText: '%',
                      isDense: true,
                    ),
                    onChanged: (read) {
                      if (read case NumberValue(:final value)) {
                        _emit(item.copyWith(hePercent: value));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TankModField(
                    // Its details go on a line of their own below: this
                    // column is a third of the card.
                    showDetails: false,
                    gas: gas,
                    role: item.tankRole,
                    overrideMeters: item.decoSwitchDepth,
                    bottomPpO2: settings.ppO2MaxWorking,
                    decoPpO2: decoPpO2Limits,
                    diluentPpO2: settings.ccrDiluentModPpO2,
                    units: _units,
                    onChanged: (meters) => _emit(
                      meters == null
                          ? item.copyWith(clearDecoSwitchDepth: true)
                          : item.copyWith(decoSwitchDepth: meters),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TankModDetails(
              gas: gas,
              role: item.tankRole,
              overrideMeters: item.decoSwitchDepth,
              bottomPpO2: settings.ppO2MaxWorking,
              decoPpO2: decoPpO2Limits,
              diluentPpO2: settings.ccrDiluentModPpO2,
              units: _units,
              onReset: () => _emit(item.copyWith(clearDecoSwitchDepth: true)),
            ),

            // MND, for a mix with helium: setting it works out the He.
            if (gas.he > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TankMndField(
                      gas: gas,
                      units: _units,
                      onHeChanged: _setHeFromMnd,
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
