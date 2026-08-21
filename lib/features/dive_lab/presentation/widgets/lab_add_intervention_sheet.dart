import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/presentation/lab_format.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the "add an intervention" sheet for the lab draft of [diveId].
Future<void> showLabAddInterventionSheet(
  BuildContext context, {
  required String diveId,
  required LabRequestInputs inputs,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => LabAddInterventionSheet(diveId: diveId, inputs: inputs),
  );
}

/// Kinds the lab offers in this phase, in display order.
const List<InterventionKind> kLabPhase2Kinds = [
  InterventionKind.switchGas,
  InterventionKind.loseTank,
  InterventionKind.shiftAscent,
  InterventionKind.ascendNow,
  InterventionKind.changeGf,
  InterventionKind.shareGas,
];

bool _isLosable(DiveTank t) =>
    t.role == TankRole.deco ||
    t.role == TankRole.stage ||
    t.role == TankRole.bailout ||
    t.role == TankRole.pony ||
    t.isTravelGas;

/// The marker value for "a hypothetical cylinder" in the switch-gas picker.
const String _kHypothetical = '__hypothetical__';

class LabAddInterventionSheet extends ConsumerStatefulWidget {
  const LabAddInterventionSheet({
    super.key,
    required this.diveId,
    required this.inputs,
  });

  final String diveId;
  final LabRequestInputs inputs;

  @override
  ConsumerState<LabAddInterventionSheet> createState() =>
      _LabAddInterventionSheetState();
}

class _LabAddInterventionSheetState
    extends ConsumerState<LabAddInterventionSheet> {
  InterventionKind? _selected;

  // switchGas
  String? _switchTankId;
  final _o2 = TextEditingController(text: '50');
  final _he = TextEditingController(text: '0');
  late final TextEditingController _volume;
  late final TextEditingController _pressure;

  // loseTank
  String? _loseTankId;

  // shiftAscent
  int _shiftMinutes = 5;
  bool _earlier = true;

  // changeGf
  late int _gfLow;
  late int _gfHigh;

  // shareGas
  double _buddyFactor = 2.0;

  @override
  void initState() {
    super.initState();
    final units = UnitFormatter(ref.read(settingsProvider));
    _volume = TextEditingController(
      text: formatDecimalForInput(units.convertVolume(11.1)),
    );
    _pressure = TextEditingController(
      text: formatDecimalForInput(units.convertPressure(200)),
    );
    _gfLow = widget.inputs.settings.gfLowPercent;
    _gfHigh = widget.inputs.settings.gfHighPercent;
    _buddyFactor = widget.inputs.settings.buddyFactor;
    final tanks = widget.inputs.tanks;
    _switchTankId = tanks.isEmpty ? _kHypothetical : tanks.first.id;
    final losable = tanks.where(_isLosable).toList();
    _loseTankId = losable.isEmpty ? null : losable.first.id;
  }

  @override
  void dispose() {
    _o2.dispose();
    _he.dispose();
    _volume.dispose();
    _pressure.dispose();
    super.dispose();
  }

  List<InterventionKind> _available() {
    final draft = ref.read(labDraftProvider(widget.diveId));
    final present = draft.interventions.map((i) => i.kind).toSet();
    final isOc = widget.inputs.diveMode == DiveMode.oc;
    final losable = widget.inputs.tanks.any(_isLosable);
    return [
      for (final k in kLabPhase2Kinds)
        if (!present.contains(k) &&
            (k != InterventionKind.switchGas || isOc) &&
            (k != InterventionKind.loseTank || losable))
          k,
    ];
  }

  ScenarioIntervention? _build(UnitFormatter units) {
    switch (_selected) {
      case InterventionKind.switchGas:
        if (_switchTankId == _kHypothetical) {
          final o2 = parseUserDecimal(_o2.text) ?? 21;
          final he = parseUserDecimal(_he.text) ?? 0;
          final volume = parseUserDecimal(_volume.text);
          final pressure = parseUserDecimal(_pressure.text);
          return SwitchGasIntervention(
            tank: HypotheticalTankRef(
              gasMix: GasMix(
                o2: o2.clamp(1, 100).toDouble(),
                he: he.clamp(0, 99).toDouble(),
              ),
              volumeLiters: volume == null
                  ? 11.1
                  : units.volumeToLiters(volume),
              startPressureBar: pressure == null
                  ? 200
                  : units.pressureToBar(pressure),
            ),
          );
        }
        final id = _switchTankId;
        return id == null
            ? null
            : SwitchGasIntervention(tank: ExistingTankRef(id));
      case InterventionKind.loseTank:
        final id = _loseTankId;
        return id == null ? null : LoseTankIntervention(tankId: id);
      case InterventionKind.shiftAscent:
        return ShiftAscentIntervention(
          deltaSeconds: (_earlier ? -1 : 1) * _shiftMinutes * 60,
        );
      case InterventionKind.ascendNow:
        return const AscendNowIntervention();
      case InterventionKind.changeGf:
        return ChangeGfIntervention(
          gfLow: _gfLow,
          gfHigh: _gfHigh < _gfLow ? _gfLow : _gfHigh,
        );
      case InterventionKind.shareGas:
        return ShareGasIntervention(buddyFactor: _buddyFactor);
      case InterventionKind.bailOut:
      case InterventionKind.ascentPolicy:
      case null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final available = _available();
    final selected = _selected;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.diveLab_sheet_title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (available.isEmpty)
              Text(l10n.diveLab_sheet_allAdded)
            else
              for (final kind in available)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_iconFor(kind)),
                  title: Text(labKindName(l10n, kind)),
                  subtitle: Text(labKindDescription(l10n, kind)),
                  selected: kind == selected,
                  onTap: () => setState(() => _selected = kind),
                ),
            if (selected != null) ...[
              const Divider(),
              _editorFor(selected, units, l10n, theme),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final i = _build(units);
                  if (i == null) return;
                  ref
                      .read(labDraftProvider(widget.diveId).notifier)
                      .addIntervention(i);
                  Navigator.of(context).pop();
                },
                child: Text(l10n.diveLab_sheet_add),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(InterventionKind kind) => switch (kind) {
    InterventionKind.switchGas => Icons.swap_horiz,
    InterventionKind.loseTank => Icons.remove_circle_outline,
    InterventionKind.shiftAscent => Icons.schedule,
    InterventionKind.ascendNow => Icons.arrow_upward,
    InterventionKind.changeGf => Icons.tune,
    InterventionKind.shareGas => Icons.people_outline,
    InterventionKind.bailOut => Icons.emergency_share,
    InterventionKind.ascentPolicy => Icons.rule,
  };

  Widget _editorFor(
    InterventionKind kind,
    UnitFormatter units,
    dynamic l10n,
    ThemeData theme,
  ) {
    switch (kind) {
      case InterventionKind.switchGas:
        return _switchGasEditor(units, l10n);
      case InterventionKind.loseTank:
        return _loseTankEditor(l10n);
      case InterventionKind.shiftAscent:
        return _shiftAscentEditor(l10n, theme);
      case InterventionKind.ascendNow:
        return const SizedBox.shrink();
      case InterventionKind.changeGf:
        return _gfEditor(l10n);
      case InterventionKind.shareGas:
        return _shareGasEditor(l10n, theme);
      case InterventionKind.bailOut:
      case InterventionKind.ascentPolicy:
        return const SizedBox.shrink();
    }
  }

  Widget _switchGasEditor(UnitFormatter units, dynamic l10n) {
    final tanks = widget.inputs.tanks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _switchTankId,
          decoration: InputDecoration(labelText: l10n.diveLab_sheet_cylinder),
          items: [
            for (final t in tanks)
              DropdownMenuItem(
                value: t.id,
                child: Text(labTankName(tanks, t.id)),
              ),
            DropdownMenuItem(
              value: _kHypothetical,
              child: Text(l10n.diveLab_sheet_hypothetical),
            ),
          ],
          onChanged: (v) => setState(() => _switchTankId = v),
        ),
        if (_switchTankId == _kHypothetical) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _o2,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.diveLab_sheet_o2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _he,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.diveLab_sheet_he),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _volume,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.diveLab_sheet_volume(units.volumeSymbol),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _pressure,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.diveLab_sheet_startPressure(
                      units.pressureSymbol,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _loseTankEditor(dynamic l10n) {
    final tanks = widget.inputs.tanks;
    final losable = tanks.where(_isLosable).toList();
    if (losable.isEmpty) return Text(l10n.diveLab_sheet_noCandidates);
    return DropdownButtonFormField<String>(
      initialValue: _loseTankId,
      decoration: InputDecoration(labelText: l10n.diveLab_sheet_cylinder),
      items: [
        for (final t in losable)
          DropdownMenuItem(value: t.id, child: Text(labTankName(tanks, t.id))),
      ],
      onChanged: (v) => setState(() => _loseTankId = v),
    );
  }

  Widget _shiftAscentEditor(dynamic l10n, ThemeData theme) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: _shiftMinutes > 1
              ? () => setState(() => _shiftMinutes--)
              : null,
        ),
        Text(
          '$_shiftMinutes ${l10n.diveLab_sheet_minutes}',
          style: theme.textTheme.titleMedium,
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => setState(() => _shiftMinutes++),
        ),
        const SizedBox(width: 12),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(l10n.diveLab_sheet_earlier)),
            ButtonSegment(value: false, label: Text(l10n.diveLab_sheet_later)),
          ],
          selected: {_earlier},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _earlier = s.first),
        ),
      ],
    );
  }

  Widget _gfEditor(dynamic l10n) {
    Widget slider(String label, int value, ValueChanged<int> onChanged) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label: $value%'),
              Slider(
                value: value.toDouble(),
                min: 10,
                max: 100,
                divisions: 18,
                onChanged: (v) => onChanged(v.round()),
              ),
            ],
          ),
        );
    return Row(
      children: [
        slider(
          l10n.divePlanner_label_gfLow,
          _gfLow,
          (v) => setState(() => _gfLow = v),
        ),
        const SizedBox(width: 16),
        slider(
          l10n.divePlanner_label_gfHigh,
          _gfHigh,
          (v) => setState(() => _gfHigh = v),
        ),
      ],
    );
  }

  Widget _shareGasEditor(dynamic l10n, ThemeData theme) {
    return Row(
      children: [
        Text(l10n.diveLab_sheet_buddyFactor),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: _buddyFactor > 1.0
              ? () => setState(() => _buddyFactor -= 0.5)
              : null,
        ),
        Text(
          'x${_buddyFactor.toStringAsFixed(1)}',
          style: theme.textTheme.titleMedium,
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _buddyFactor < 3.0
              ? () => setState(() => _buddyFactor += 0.5)
              : null,
        ),
      ],
    );
  }
}
