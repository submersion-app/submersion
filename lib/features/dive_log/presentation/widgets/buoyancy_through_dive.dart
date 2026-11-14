import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/buoyancy/twin_balance.dart';
import 'package:submersion/core/utils/minutes_seconds.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_balance_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What buoyancy did through the dive, as one instrument: a readout, the
/// net-buoyancy chart, and under it the parts pulling the diver down and
/// holding them up at the moment under the cursor.
///
/// At rest everything describes the final stop, where weighting is judged.
/// With [onCursorSeconds] the host owns the cursor (the dive profile's);
/// without it the section follows the chart's own touch.
class BuoyancyThroughDive extends StatefulWidget {
  final BuoyancyTwinOutcome outcome;
  final UnitFormatter units;
  final int? cursorSeconds;
  final ValueChanged<int?>? onCursorSeconds;

  const BuoyancyThroughDive({
    super.key,
    required this.outcome,
    required this.units,
    this.cursorSeconds,
    this.onCursorSeconds,
  });

  @override
  State<BuoyancyThroughDive> createState() => _BuoyancyThroughDiveState();
}

class _BuoyancyThroughDiveState extends State<BuoyancyThroughDive> {
  int? _ownCursor;

  // Derived from the outcome once, not on every scrub frame.
  late double _scaleKg;
  late TwinMoments _moments;
  late List<TwinSample> _plotted;

  @override
  void initState() {
    super.initState();
    _derive();
  }

  @override
  void didUpdateWidget(BuoyancyThroughDive oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newOutcome = !identical(oldWidget.outcome, widget.outcome);
    if (newOutcome || !identical(oldWidget.units, widget.units)) _derive();
    // A scrub position belongs to the dive it was made on.
    if (newOutcome) _ownCursor = null;
  }

  void _derive() {
    final outcome = widget.outcome;
    _scaleKg = TwinBalance.scaleKg(outcome.result, outcome.outputs.verdict);
    _moments = TwinMoments.of(outcome.result, outcome.outputs.verdict);
    _plotted = BuoyancyChart.plottableSamples(
      outcome.result.samples,
      widget.units,
    );
  }

  int? get _cursor =>
      widget.onCursorSeconds != null ? widget.cursorSeconds : _ownCursor;

  @override
  Widget build(BuildContext context) {
    final result = widget.outcome.result;
    final verdict = widget.outcome.outputs.verdict;
    final units = widget.units;

    final plotted = _plotted;
    final hasChart = plotted.length >= 2;
    final cursor = _cursor;
    final sample = hasChart && cursor != null
        ? _nearest(plotted, cursor)
        : null;
    final balance = sample != null
        ? TwinBalance.atSample(result, sample)
        : TwinBalance.atRest(result, verdict);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _readout(context, balance.netKg, sample, verdict.anchor),
        if (hasChart) ...[
          const SizedBox(height: 8),
          BuoyancyChart(
            result: result,
            units: units,
            cursorSeconds: cursor,
            onCursorSeconds:
                widget.onCursorSeconds ??
                (seconds) => setState(() => _ownCursor = seconds),
            markers: _markers(context.l10n),
            restSeconds: _moments.finalStopSeconds,
          ),
        ],
        const SizedBox(height: 8),
        BuoyancyBalanceBar(balance: balance, scaleKg: _scaleKg, units: units),
        ..._causeNotes(context),
      ],
    );
  }

  static TwinSample _nearest(List<TwinSample> samples, int seconds) =>
      samples.reduce(
        (a, b) => (b.timestamp - seconds).abs() < (a.timestamp - seconds).abs()
            ? b
            : a,
      );

  Widget _readout(
    BuildContext context,
    double netKg,
    TwinSample? sample,
    TwinAnchor anchor,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final units = widget.units;
    final amount = units.formatWeight(netKg.abs());
    final String figure;
    if (netKg.abs() <= TwinBalance.neutralBandKg) {
      figure = l10n.buoyancy_readoutNeutral;
    } else if (netKg > 0) {
      figure = l10n.buoyancy_readoutBuoyant(amount);
    } else {
      figure = l10n.buoyancy_readoutHeavy(amount);
    }

    final String qualifier;
    if (sample != null) {
      qualifier = l10n.buoyancy_readoutAtMoment(
        units.formatDepth(sample.depthM, decimals: 0),
        formatMinutesSeconds(sample.timestamp),
      );
    } else if (anchor.kind == TwinAnchorKind.convention) {
      qualifier = l10n.buoyancy_readoutConvention(
        units.formatDepth(anchor.depthM, decimals: 0),
      );
    } else {
      qualifier = l10n.buoyancy_readoutAtFinalStop(
        units.formatDepth(anchor.depthM, decimals: 0),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      runSpacing: 2,
      children: [
        Text(figure, style: theme.textTheme.headlineSmall),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            qualifier,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  List<BuoyancyChartMarker> _markers(AppLocalizations l10n) {
    final start = _moments.start;
    final deepest = _moments.deepest;
    final stop = _moments.finalStopSeconds;
    final taken = <int>{};
    return [
      if (start != null && taken.add(start.timestamp))
        BuoyancyChartMarker(
          seconds: start.timestamp,
          label: l10n.buoyancy_markerStart,
        ),
      // The stop claims its moment before the deepest point does: on a dive
      // whose deepest sample is the stop, the stop is the label worth keeping.
      if (stop != null && taken.add(stop))
        BuoyancyChartMarker(
          seconds: stop,
          label: l10n.buoyancy_markerFinalStop,
        ),
      if (deepest != null && taken.add(deepest.timestamp))
        BuoyancyChartMarker(
          seconds: deepest.timestamp,
          label: l10n.buoyancy_markerDeepest,
          optional: true,
        ),
    ]..sort((a, b) => a.seconds.compareTo(b.seconds));
  }

  List<Widget> _causeNotes(BuildContext context) {
    final l10n = context.l10n;
    final units = widget.units;
    final squeeze = _moments.suitSqueezeKg;
    final deepest = _moments.deepest;
    final lighter = _moments.gasLighterKg;
    return [
      if (squeeze != null && deepest != null)
        _note(
          context,
          Icons.compress,
          l10n.buoyancy_causeSuit(
            units.formatWeight(squeeze),
            units.formatDepth(deepest.depthM, decimals: 0),
          ),
        ),
      if (lighter != null)
        _note(
          context,
          Icons.air,
          l10n.buoyancy_causeGas(units.formatWeight(lighter)),
        ),
    ];
  }

  Widget _note(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
