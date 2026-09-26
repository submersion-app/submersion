import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blend_billing.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_gas_role.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_formatting.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_volume_conversion.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The two kinds of line "Add a line" can put on the bill (issue #2302).
enum BlenderLineKind {
  /// One gas filled by hand, priced from the cylinder, the pressure filled
  /// and that gas's configured price.
  gas,

  /// A lump sum typed in by hand, e.g. an O2 analyser cell.
  amount,
}

/// What [BlenderLineEditSheet] hands back.
class BlenderLineEdit {
  const BlenderLineEdit({
    required this.label,
    required this.amount,
    this.lines,
  });

  final String label;
  final double? amount;

  /// The line's itemisation: empty for a free amount, the single gas line of
  /// a gas fill. Null leaves the edited fill's own lines untouched, which is
  /// what a fill the blender computed needs.
  final List<BilledGasLine>? lines;
}

/// Adds a line to the running bill, or edits one already on it.
///
/// Owns its own controllers, and disposes them in its own State.
///
/// Creating them in the caller and disposing on the sheet's future looks
/// equivalent and is not: the future completes when the route is popped, while
/// the exit transition keeps rebuilding these fields for several more frames
/// against a controller that is already gone.
///
/// A scrollable, keyboard-aware bottom sheet rather than a fixed-size
/// `AlertDialog`: the gas fill needs a cylinder row and two pressure fields,
/// and a taller fixed dialog risks overflow once the keyboard is up on the
/// narrowest phone the app supports (issue #1335).
class BlenderLineEditSheet extends ConsumerStatefulWidget {
  const BlenderLineEditSheet({super.key, required this.fill});

  /// Null to add a new line.
  final BilledFill? fill;

  @override
  ConsumerState<BlenderLineEditSheet> createState() =>
      _BlenderLineEditSheetState();
}

class _BlenderLineEditSheetState extends ConsumerState<BlenderLineEditSheet> {
  late final TextEditingController _label;
  late final TextEditingController _amount;
  late final TextEditingController _cylinder;
  late final TextEditingController _startPressure;
  late final TextEditingController _endPressure;

  late BlenderLineKind _kind;
  late BlenderGasRole _role;

  /// The exact water volume of the cylinder preset last picked, until the
  /// field is typed into. The field shows it rounded, which in cubic feet
  /// loses enough to misprice the fill if it were read back from the text.
  double? _presetLiters;

  /// The gas fill fields as the sheet opened them, to tell an edit of the
  /// description alone from a changed fill.
  late final String _seedCylinder;
  late final String _seedStart;
  late final String _seedEnd;

  String? _error;

  /// Only a new line or one entered by hand may pick its kind. A fill the
  /// blender computed is already itemised in [BilledFill.lines]; offering a
  /// gas or an amount here would let the label and the itemisation disagree.
  bool get _kindEditable {
    final fill = widget.fill;
    return fill == null || fill.isManual || fill.manualGasLine != null;
  }

  @override
  void initState() {
    super.initState();
    final fill = widget.fill;
    final gasLine = fill?.manualGasLine;
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);

    _kind = fill == null || gasLine != null
        ? BlenderLineKind.gas
        : BlenderLineKind.amount;
    _role = gasLine?.role ?? BlenderGasRole.o2;

    // A label this sheet generated is left blank rather than kept as typed
    // text, so changing the pressure or the gas regenerates it. Checked in
    // every unit combination and app language: the diver may have switched
    // either since.
    final generated =
        gasLine != null && _isGeneratedLabel(fill!.label, gasLine, settings);
    _label = TextEditingController(
      text: fill == null || generated ? '' : fill.label,
    );
    // Seeded for a gas fill too: switching it to a free amount starts from
    // what it cost rather than from a blank that would leave it unpriced.
    _amount = TextEditingController(
      text: fill?.total == null ? '' : formatRoundedForInput(fill!.total!, 2),
    );
    final double cylinderLiters =
        gasLine?.cylinderLiters ?? ref.read(blenderCylinderLitersProvider);
    _seedCylinder = formatRoundedForInput(
      litersToDisplayVolume(cylinderLiters, settings),
      2,
    );
    _cylinder = TextEditingController(text: _seedCylinder);
    final double startBar = gasLine?.startBar ?? 0;
    final double endBar =
        gasLine?.endBar ?? ref.read(blenderTargetPressureProvider);
    // Two decimals rather than whole numbers, so reopening a fill and saving
    // it untouched cannot move its pressures.
    _seedStart = formatRoundedForInput(units.convertPressure(startBar), 2);
    _seedEnd = formatRoundedForInput(units.convertPressure(endBar), 2);
    _startPressure = TextEditingController(text: _seedStart);
    _endPressure = TextEditingController(text: _seedEnd);
  }

  /// The saved gas fill being edited, when none of its fill fields has
  /// changed. It then keeps the amount and gas name it was billed with: a
  /// price or topup gas changed since must not reprice a line reopened only
  /// to fix its description.
  BilledGasLine? get _unchangedGasLine {
    final line = widget.fill?.manualGasLine;
    if (line == null || line.role != _role || _presetLiters != null) {
      return null;
    }
    if (_cylinder.text != _seedCylinder ||
        _startPressure.text != _seedStart ||
        _endPressure.text != _seedEnd) {
      return null;
    }
    return line;
  }

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _cylinder.dispose();
    _startPressure.dispose();
    _endPressure.dispose();
    super.dispose();
  }

  /// Whether [label] is what [_generatedLabel] made for [line], in any
  /// pressure and volume unit and under any of the app's languages.
  ///
  /// The language matters because the label's numbers carry that locale's
  /// decimal separator: "12,5 L" written under de is not "12.5 L" read back
  /// under en.
  bool _isGeneratedLabel(
    String label,
    BilledGasLine line,
    AppSettings settings,
  ) {
    for (final locale in AppLocalizations.supportedLocales) {
      for (final pressure in PressureUnit.values) {
        for (final volume in VolumeUnit.values) {
          final units = UnitFormatter(
            settings.copyWith(pressureUnit: pressure, volumeUnit: volume),
          );
          final candidate = Intl.withLocale(
            locale.toLanguageTag(),
            () => _generatedLabel(
              line.gas,
              line.cylinderLiters,
              line.addedBar,
              units,
            ),
          );
          if (label == candidate) return true;
        }
      }
    }
    return false;
  }

  String _generatedLabel(
    String gasName,
    double? cylinderLiters,
    double addedBar,
    UnitFormatter units,
  ) => [
    gasName,
    if (cylinderLiters != null) units.formatTankVolume(cylinderLiters, null),
    // The blender's own pressure precision, so a label reads the fill that
    // was billed rather than a rounded one.
    units.formatPressure(
      addedBar,
      decimals: pressureDecimalsFor(units.settings.pressureUnit),
    ),
  ].join(' · ');

  /// The name the chosen gas is stored and printed under, the same one a
  /// computed fill's line would carry for it.
  String _gasName(BlenderGasRole role) => formatPreciseGasName(
    context,
    gasForRole(role, ref.read(blenderTopupO2PercentProvider)),
  );

  /// The dropdown entry for [role]. The topup gas names what it currently
  /// holds, since that is configurable and not always air.
  String _roleOption(BlenderGasRole role, double topupO2) {
    final label = blenderGasRoleLabel(context, role);
    if (role != BlenderGasRole.topup) return label;
    return '$label (${formatPreciseMix(context, gasForRole(role, topupO2))})';
  }

  double? _priceFor(BlenderGasRole role, List<double?> prices) =>
      role.index < prices.length ? prices[role.index] : null;

  double? _cylinderLiters(AppSettings settings) {
    if (_presetLiters != null) return _presetLiters;
    // An untouched field still holds the saved fill's exact volume, which
    // its rounded text would lose in cubic feet.
    final saved = widget.fill?.manualGasLine?.cylinderLiters;
    if (saved != null && _cylinder.text == _seedCylinder) return saved;
    final shown = smartParseUserDecimal(_cylinder.text);
    if (shown == null || shown <= 0) return null;
    return displayVolumeToLiters(shown, settings);
  }

  /// The gas fill as currently entered, or null while it cannot be priced.
  ManualGasFillCost? _gasCost(
    AppSettings settings,
    UnitFormatter units,
    List<double?> prices,
  ) {
    final liters = _cylinderLiters(settings);
    final start = smartParseUserDecimal(_startPressure.text);
    final end = smartParseUserDecimal(_endPressure.text);
    if (liters == null || start == null || end == null) return null;
    return manualGasFillCost(
      waterLiters: liters,
      startBar: units.pressureToBar(start),
      endBar: units.pressureToBar(end),
      pricePer100: _priceFor(_role, prices),
    );
  }

  void _submit() {
    final label = _label.text.trim();
    if (!_kindEditable || _kind == BlenderLineKind.amount) {
      if (label.isEmpty) {
        setState(
          () =>
              _error = context.l10n.gasCalculators_blender_lineNeedsDescription,
        );
        return;
      }
      Navigator.of(context).pop(
        BlenderLineEdit(
          label: label,
          amount: smartParseUserDecimal(_amount.text),
          lines: _kindEditable ? const [] : null,
        ),
      );
      return;
    }

    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    final unchanged = _unchangedGasLine;
    if (unchanged != null) {
      final fill = widget.fill!;
      Navigator.of(context).pop(
        BlenderLineEdit(
          // A blank description here means the saved one was generated, so
          // it is kept as saved: the fill did not change, and regenerating
          // it would only restate it in whatever unit is active now.
          label: label.isNotEmpty ? label : fill.label,
          amount: fill.total,
          lines: [unchanged],
        ),
      );
      return;
    }
    final liters = _cylinderLiters(settings);
    if (liters == null) {
      setState(
        () => _error = context.l10n.gasCalculators_blender_lineNeedsCylinder,
      );
      return;
    }
    if (smartParseUserDecimal(_startPressure.text) == null ||
        smartParseUserDecimal(_endPressure.text) == null) {
      setState(
        () => _error = context.l10n.gasCalculators_blender_lineNeedsPressure,
      );
      return;
    }
    final cost = _gasCost(settings, units, ref.read(blenderGasPricesProvider));
    if (cost == null) {
      setState(
        () => _error = context.l10n.gasCalculators_blender_lineInvalidPressure,
      );
      return;
    }
    final gasName = _gasName(_role);
    final startBar = units.pressureToBar(
      smartParseUserDecimal(_startPressure.text)!,
    );
    Navigator.of(context).pop(
      BlenderLineEdit(
        label: label.isNotEmpty
            ? label
            : _generatedLabel(gasName, liters, cost.addedBar, units),
        amount: cost.cost,
        lines: [
          BilledGasLine(
            gas: gasName,
            addedBar: cost.addedBar,
            cost: cost.cost,
            freeGasLiters: cost.freeGasLiters,
            cylinderLiters: liters,
            role: _role,
            startBar: startBar,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.fill;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final isGas = _kindEditable && _kind == BlenderLineKind.gas;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              fill == null
                  ? context.l10n.gasCalculators_blender_addManualLine
                  : context.l10n.gasCalculators_blender_editLine(fill.label),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (_kindEditable) ...[
              SegmentedButton<BlenderLineKind>(
                key: const Key('blender-line-kind'),
                segments: [
                  ButtonSegment(
                    value: BlenderLineKind.gas,
                    label: Text(
                      context.l10n.gasCalculators_blender_lineKindGas,
                    ),
                  ),
                  ButtonSegment(
                    value: BlenderLineKind.amount,
                    label: Text(
                      context.l10n.gasCalculators_blender_lineKindAmount,
                    ),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (selection) => setState(() {
                  _kind = selection.single;
                  _error = null;
                  // A free amount needs a description, and a generated one
                  // was left blank: carry the line's label over rather than
                  // make the diver retype it.
                  final fill = widget.fill;
                  if (_kind == BlenderLineKind.amount &&
                      _label.text.trim().isEmpty &&
                      fill != null) {
                    _label.text = fill.label;
                  }
                }),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const Key('blender-line-description'),
              controller: _label,
              autofocus: !isGas,
              decoration: InputDecoration(
                labelText: context.l10n.gasCalculators_blender_lineDescription,
                helperText: isGas
                    ? context
                          .l10n
                          .gasCalculators_blender_lineDescriptionOptional
                    : null,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (isGas)
              ..._gasFields(context, settings, units)
            else
              TextField(
                key: const Key('blender-line-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: context.l10n.gasCalculators_blender_lineAmount,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(context.l10n.common_action_save),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _gasFields(
    BuildContext context,
    AppSettings settings,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);
    final prices = ref.watch(blenderGasPricesProvider);
    final topupO2 = ref.watch(blenderTopupO2PercentProvider);
    final currency = ref.watch(blenderCurrencyProvider);
    // An untouched saved fill shows what it was billed at, the same amount
    // saving it will keep.
    final unchanged = _unchangedGasLine;
    final cost = unchanged == null ? _gasCost(settings, units, prices) : null;
    final addedBar = unchanged?.addedBar ?? cost?.addedBar;
    final amount = unchanged != null ? widget.fill!.total : cost?.cost;
    final unpriced = unchanged == null && _priceFor(_role, prices) == null;
    final resultStyle = theme.textTheme.titleSmall;
    return [
      DropdownButtonFormField<BlenderGasRole>(
        key: const Key('blender-line-gas'),
        initialValue: _role,
        decoration: InputDecoration(
          labelText: context.l10n.gasCalculators_blender_lineGas,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final role in BlenderGasRole.values)
            DropdownMenuItem(
              value: role,
              child: Text(_roleOption(role, topupO2)),
            ),
        ],
        onChanged: (role) {
          if (role != null) setState(() => _role = role);
        },
      ),
      const SizedBox(height: 12),
      _cylinderRow(context, settings, units),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _numberField(
              const Key('blender-line-start-pressure'),
              _startPressure,
              '${context.l10n.gasCalculators_blender_lineStartPressure} '
              '(${units.pressureSymbol})',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _numberField(
              const Key('blender-line-end-pressure'),
              _endPressure,
              '${context.l10n.gasCalculators_blender_lineEndPressure} '
              '(${units.pressureSymbol})',
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        context.l10n.gasCalculators_blender_lineFillPressure(
          addedBar == null
              ? '--'
              : units.formatPressure(
                  addedBar,
                  decimals: pressureDecimalsFor(settings.pressureUnit),
                ),
        ),
        key: const Key('blender-line-fill-pressure'),
        style: resultStyle,
      ),
      const SizedBox(height: 4),
      Text(
        context.l10n.gasCalculators_blender_lineComputedAmount(
          amount == null ? '--' : formatMoney(amount, currency),
        ),
        key: const Key('blender-line-computed-amount'),
        style: resultStyle?.copyWith(fontWeight: FontWeight.w700),
      ),
      if (unpriced)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            context.l10n.gasCalculators_blender_lineNoPrice,
            key: const Key('blender-line-no-price'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
    ];
  }

  Widget _cylinderRow(
    BuildContext context,
    AppSettings settings,
    UnitFormatter units,
  ) {
    // Sourced from the diver's global tank presets (issue #1335 follow-up),
    // same as BlenderBillingCard._cylinderRow: the blender keeps no cylinder
    // vault of its own, so this sheet's picker reads the same list.
    final presetsAsync = ref.watch(tankPresetsProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _numberField(
            const Key('blender-line-cylinder'),
            _cylinder,
            '${context.l10n.gasCalculators_blender_cylinderVolume} '
            '(${units.volumeSymbol})',
            // Typing a size replaces the preset's exact one.
            onChanged: () => _presetLiters = null,
          ),
        ),
        const SizedBox(width: 8),
        presetsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (error, stackTrace) => IconButton(
            icon: const Icon(Icons.error_outline),
            tooltip: context.l10n.gasCalculators_blender_cylinderPresets,
            onPressed: null,
          ),
          data: (presets) => PopupMenuButton<TankPresetEntity>(
            key: const Key('blender-line-cylinder-presets'),
            tooltip: context.l10n.gasCalculators_blender_cylinderPresets,
            position: PopupMenuPosition.under,
            itemBuilder: (context) => [
              for (final preset in presets)
                PopupMenuItem<TankPresetEntity>(
                  value: preset,
                  child: Text(
                    '${preset.displayName} '
                    '(${units.formatTankVolume(preset.volumeLiters, null)})',
                  ),
                ),
            ],
            // A preset sets the end pressure too: its working pressure is
            // what the cylinder is filled to (issue #2302). Still editable
            // afterwards, since only the last gas of a blend reaches it.
            onSelected: (preset) => setState(() {
              _presetLiters = preset.volumeLiters;
              _cylinder.text = formatRoundedForInput(
                litersToDisplayVolume(preset.volumeLiters, settings),
                2,
              );
              _endPressure.text = formatRoundedForInput(
                units.convertPressure(preset.workingPressureBar),
                2,
              );
              _error = null;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.gasCalculators_blender_cylinderPresets),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _numberField(
    Key key,
    TextEditingController controller,
    String label, {
    VoidCallback? onChanged,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (_) => setState(() {
        onChanged?.call();
        _error = null;
      }),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
