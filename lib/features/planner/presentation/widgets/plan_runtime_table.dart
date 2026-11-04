import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/schedule_lines.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// A plan's deco schedule as the slate's runtime table: depth, duration,
/// runtime, gas, ppO2 and END for each line. In the editor a stop row opens
/// its minimum-time dialog; with [editable] false (a logged dive's plan,
/// shown as it was) it reads only, and [stopMinimums] marks the stops that
/// plan held to a minimum.
class PlanRuntimeTable extends ConsumerWidget {
  const PlanRuntimeTable({
    super.key,
    required this.outcome,
    required this.units,
    this.editable = true,
    this.stopMinimums,
  });

  final PlanOutcome outcome;
  final UnitFormatter units;
  final bool editable;

  /// The plan's stop minimums; null reads the editor's.
  final Map<int, int>? stopMinimums;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final lines = scheduleLines(outcome.schedule);
    final stopMinimums =
        this.stopMinimums ?? ref.watch(divePlanNotifierProvider).stopMinimums;
    final noDeco = Text(
      l10n.plannerCanvas_results_noDeco,
      style: theme.textTheme.bodyMedium,
    );
    if (lines.isEmpty) return noDeco;

    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
    );
    final glyphStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.outline,
    );
    // The gas column repeats on every line (not just the switch) so a diver
    // reading a single row never has to scroll up to see what they are
    // breathing; a switch still stands out via switchStyle below.
    final switchStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    Widget cell(String text, {TextStyle? style, int flex = 1}) => Expanded(
      flex: flex,
      child: Text(text, style: style ?? theme.textTheme.bodyMedium),
    );
    Widget glyph(String text) =>
        SizedBox(width: 20, child: Text(text, style: glyphStyle));

    return Column(
      children: [
        if (outcome.stops.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: noDeco,
            ),
          ),
        Row(
          children: [
            glyph(''),
            cell(l10n.plannerCanvas_table_depth, style: headerStyle),
            cell(l10n.plannerCanvas_table_duration, style: headerStyle),
            cell(l10n.plannerCanvas_table_runtime, style: headerStyle),
            cell(l10n.plannerCanvas_table_gas, style: headerStyle, flex: 2),
            cell(l10n.plannerCanvas_table_ppO2, style: headerStyle),
            cell(l10n.plannerCanvas_table_end, style: headerStyle),
          ],
        ),
        const Divider(height: 12),
        for (final line in lines)
          _buildLineRow(
            context,
            ref,
            line,
            stopMinimums,
            cell,
            glyph,
            switchStyle,
          ),
      ],
    );
  }

  Widget _buildLineRow(
    BuildContext context,
    WidgetRef ref,
    ScheduleLine line,
    Map<int, int> stopMinimums,
    Widget Function(String, {TextStyle? style, int flex}) cell,
    Widget Function(String) glyph,
    TextStyle? switchStyle,
  ) {
    final isStop = line.row.kind == PlanScheduleRowKind.stop;
    final stopDepth = line.row.depthMeters.round();
    final hasMinimum = isStop && (stopMinimums[stopDepth] ?? 0) > 0;
    final theme = Theme.of(context);

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          glyph(scheduleRowGlyph(line.row.kind)),
          cell(units.formatDepth(line.row.depthMeters, decimals: 0)),
          cell(
            line.durationLabel('′'),
            style: hasMinimum
                ? theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : null,
          ),
          cell('${line.runtimeMinutes}′'),
          if (hasMinimum)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.push_pin, size: 14),
            ),
          cell(
            GasMix(o2: line.row.gasFO2 * 100, he: line.row.gasFHe * 100).name,
            style: line.row.gasSwitch ? switchStyle : null,
            flex: 2,
          ),
          cell(line.row.ppO2.toStringAsFixed(2)),
          cell(units.formatDepth(line.row.endMeters, decimals: 0)),
        ],
      ),
    );

    if (!isStop || !editable) return row;

    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => _StopMinimumDialog(
          stopDepth: stopDepth,
          currentMinutes: (line.row.durationSeconds / 60).round(),
          currentMinimumSeconds: stopMinimums[stopDepth],
          depthLabel: units.formatDepth(stopDepth.toDouble(), decimals: 0),
        ),
      ),
      child: row,
    );
  }
}

/// Owns the minutes field so the controller is disposed with the route,
/// after the pop animation, not when [showDialog] first completes.
class _StopMinimumDialog extends ConsumerStatefulWidget {
  const _StopMinimumDialog({
    required this.stopDepth,
    required this.currentMinutes,
    required this.currentMinimumSeconds,
    required this.depthLabel,
  });

  final int stopDepth;
  final int currentMinutes;
  final int? currentMinimumSeconds;
  final String depthLabel;

  @override
  ConsumerState<_StopMinimumDialog> createState() => _StopMinimumDialogState();
}

class _StopMinimumDialogState extends ConsumerState<_StopMinimumDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final seed = widget.currentMinimumSeconds != null
        ? (widget.currentMinimumSeconds! / 60).round()
        : widget.currentMinutes;
    _controller = TextEditingController(text: seed.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        l10n.plannerCanvas_stopMinimum_dialogTitle(widget.depthLabel),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: numberInputFormatters(),
          validator: numberValidator(context, integer: true),
          decoration: InputDecoration(
            labelText: l10n.plannerCanvas_stopMinimum_minutesLabel,
          ),
        ),
      ),
      actions: [
        if (widget.currentMinimumSeconds != null)
          TextButton(
            onPressed: () {
              ref
                  .read(divePlanNotifierProvider.notifier)
                  .setStopMinimum(widget.stopDepth, null);
              Navigator.of(context).pop();
            },
            child: Text(l10n.plannerCanvas_stopMinimum_clear),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            // "5.5" used to close the dialog as if applied, leaving the deco
            // stop unchanged (#1900).
            if (!_formKey.currentState!.validate()) return;
            final minutes = switch (readNumber(
              _controller.text,
              integer: true,
            )) {
              NumberValue(:final value) => value.toInt(),
              // Blank closes with no change, as before.
              NumberBlank() || NumberInvalid() => null,
            };
            if (minutes != null) {
              // Non-positive is "no minimum": the engine ignores <= 0,
              // so persisting 0 would pin the row with no effect.
              ref
                  .read(divePlanNotifierProvider.notifier)
                  .setStopMinimum(
                    widget.stopDepth,
                    minutes <= 0 ? null : minutes * 60,
                  );
            }
            Navigator.of(context).pop();
          },
          child: Text(l10n.plannerCanvas_stopMinimum_apply),
        ),
      ],
    );
  }
}
