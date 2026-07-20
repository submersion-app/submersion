import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the ephemeral what-if sheet: tweak lead, water type, or suit
/// buoyancy and watch the final-stop verdict recompute. Nothing persists.
Future<void> showBuoyancyWhatIfSheet(
  BuildContext context, {
  required TwinInput baseInput,
  required UnitFormatter units,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BuoyancyWhatIfSheet(baseInput: baseInput, units: units),
  );
}

class _BuoyancyWhatIfSheet extends StatefulWidget {
  final TwinInput baseInput;
  final UnitFormatter units;
  const _BuoyancyWhatIfSheet({required this.baseInput, required this.units});

  @override
  State<_BuoyancyWhatIfSheet> createState() => _BuoyancyWhatIfSheetState();
}

class _BuoyancyWhatIfSheetState extends State<_BuoyancyWhatIfSheet> {
  late double _leadKg;
  late WaterType _waterType;
  late double _suitAnchor;
  late final TwinOutputs _baseOutputs;
  late TwinOutputs _outputs;

  @override
  void initState() {
    super.initState();
    _reset();
    _baseOutputs = TwinAnalyzer.analyze(runBuoyancyTwin(widget.baseInput));
    _outputs = TwinAnalyzer.analyze(runBuoyancyTwin(_current()));
  }

  void _reset() {
    _leadKg = widget.baseInput.leadKg;
    _waterType = _waterTypeOf(widget.baseInput.environment);
    _suitAnchor = widget.baseInput.suit.anchorKg;
  }

  /// Re-runs the (potentially dense-profile) twin and refreshes the verdict.
  /// Called only on committed changes -- discrete lead/water taps and the suit
  /// slider's drag-end -- so a continuous drag does not re-simulate per frame.
  void _recompute() {
    setState(() {
      _outputs = TwinAnalyzer.analyze(runBuoyancyTwin(_current()));
    });
  }

  double get _incrementKg =>
      widget.units.weightSymbol.toLowerCase().startsWith('kg')
      ? 0.5
      : 0.45359237;

  TwinInput _current() {
    final env = DiveEnvironment.forConditions(
      waterType: _waterType,
      surfacePressureBar: widget.baseInput.environment.surfacePressureBar,
    );
    final staticTerms = [
      for (final t in widget.baseInput.staticTerms)
        if (t.label == 'water')
          TwinStaticTerm(
            label: 'water',
            kg: BuoyancyPhysics.waterTermKg(
              waterType: _waterType,
              totalMassKg: widget.baseInput.totalMassKg,
            ),
            source: t.source,
          )
        else
          t,
    ];
    return widget.baseInput.copyWith(
      leadKg: _leadKg,
      suit: TwinSuitInput(
        kind: widget.baseInput.suit.kind,
        anchorKg: _suitAnchor,
        source: widget.baseInput.suit.source,
      ),
      staticTerms: staticTerms,
      environment: env,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = widget.units;
    final outputs = _outputs;
    final deltaNet = outputs.verdict.netKg - _baseOutputs.verdict.netKg;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.buoyancy_whatIfTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          _leadRow(context),
          const SizedBox(height: 16),
          SegmentedButton<WaterType>(
            segments: [
              ButtonSegment(
                value: WaterType.salt,
                label: Text(l10n.enum_waterType_salt),
              ),
              ButtonSegment(
                value: WaterType.brackish,
                label: Text(l10n.enum_waterType_brackish),
              ),
              ButtonSegment(
                value: WaterType.fresh,
                label: Text(l10n.enum_waterType_fresh),
              ),
            ],
            selected: {_waterType},
            onSelectionChanged: (s) {
              _waterType = s.first;
              _recompute();
            },
          ),
          if (widget.baseInput.suit.kind != TwinSuitKind.none) ...[
            const SizedBox(height: 16),
            Text(
              '${l10n.buoyancy_whatIfSuit}: ${units.formatWeight(_suitAnchor)}',
              style: theme.textTheme.bodySmall,
            ),
            Slider(
              value: _suitAnchor.clamp(0.0, 12.0),
              max: 12,
              divisions: 24,
              // Live value keeps the label/thumb responsive during the drag;
              // the twin only re-simulates once the drag settles.
              onChanged: (v) => setState(() => _suitAnchor = v),
              onChangeEnd: (_) => _recompute(),
            ),
          ],
          const Divider(height: 32),
          Text(
            _verdictText(context, outputs),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Chip(
            label: Text(
              l10n.buoyancy_whatIfDelta(units.formatWeight(deltaNet)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.buoyancy_minDitchable}: '
            '${units.formatWeight(outputs.minDitchableKg)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                _reset();
                _recompute();
              },
              child: Text(l10n.buoyancy_whatIfReset),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leadRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(context.l10n.buoyancy_whatIfLead)),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: () {
            _leadKg = (_leadKg - _incrementKg).clamp(0.0, 100.0);
            _recompute();
          },
        ),
        SizedBox(
          width: 72,
          child: Text(
            widget.units.formatWeight(_leadKg),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            _leadKg = (_leadKg + _incrementKg).clamp(0.0, 100.0);
            _recompute();
          },
        ),
      ],
    );
  }

  String _verdictText(BuildContext context, TwinOutputs o) {
    final l10n = context.l10n;
    final net = o.verdict.netKg;
    final amount = widget.units.formatWeight(net.abs());
    final depth = widget.units.formatDepth(o.verdict.anchor.depthM);
    if (net.abs() <= 0.5) return l10n.buoyancy_verdictNeutral;
    return net > 0
        ? l10n.buoyancy_verdictBuoyant(depth, amount)
        : l10n.buoyancy_verdictHeavy(depth, amount);
  }

  static WaterType _waterTypeOf(DiveEnvironment env) {
    final d = env.waterDensityKgM3;
    if (d >= 1017.5) return WaterType.salt;
    if (d >= 1005) return WaterType.brackish;
    return WaterType.fresh;
  }
}
