import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/gas_blender.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_formatting.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_table_style.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Splits [available] across columns that need at least [minimums], in the
/// same order.
///
/// Every column gets an even share unless it needs more. One that does keeps
/// its minimum and the others share what is left, so the widest are settled
/// first. The widths add up to [available] unless the minimums alone exceed
/// it, in which case the minimums come back as they are.
List<double> blenderColumnWidths(List<double> minimums, double available) {
  final order = List.generate(minimums.length, (i) => i)
    ..sort((a, b) => minimums[b].compareTo(minimums[a]));
  final widths = List.filled(minimums.length, 0.0);
  var remaining = available;
  for (var k = 0; k < order.length; k++) {
    final share = remaining / (order.length - k);
    final width = math.max(minimums[order[k]], share);
    widths[order[k]] = width;
    remaining -= width;
  }
  return widths;
}

/// The fill-order table: what to add, how much, the pressure to stop at, and
/// the mix that leaves in the cylinder.
///
/// The columns share the width evenly and a column that needs more gets it
/// from the others (issue #3796). So this measures the text first, the way
/// [Row] and `Expanded` cannot: a data row always stays on one line, and only
/// the header may wrap.
///
/// When the single-line rows cannot fit at all, on a very narrow screen or at
/// a large text scale, the whole table scales down to fit. A number that is
/// smaller still reads correctly, whereas an ellipsized pressure does not, and
/// a horizontal scroller would put the pressure and mix columns back off
/// screen (issue #1876 follow-up).
class BlenderStepTable extends StatelessWidget {
  final List<BlendStep> steps;
  final UnitFormatter units;
  final int decimals;

  const BlenderStepTable({
    super.key,
    required this.steps,
    required this.units,
    required this.decimals,
  });

  /// Keeps an end-aligned value clear of the column before it when that
  /// column is down to its minimum.
  static const double _columnGap = 8;

  /// Chemical symbols, the same in every locale.
  static const String _mixComponents = 'O₂/He';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onPrimaryContainer = Theme.of(context).colorScheme.onPrimaryContainer;
    final headerStyle = blenderTableHeaderStyle(
      context,
      color: onPrimaryContainer,
    );
    final valueStyle = blenderTableValueStyle(
      context,
      color: onPrimaryContainer,
    );
    final unitLine = '(${units.pressureSymbol})';
    final headers = [
      l10n.gasCalculators_blender_stepColumnAction,
      '${l10n.gasCalculators_blender_stepColumnTopUp}\n$unitLine',
      '${l10n.gasCalculators_blender_stepColumnPressure}\n$unitLine',
      '${l10n.gasCalculators_blender_stepColumnMix}\n$_mixComponents',
    ];
    final rows = [for (final step in steps) _cells(context, step)];
    final minimums = _minimumWidths(
      context,
      headers,
      headerStyle,
      rows,
      valueStyle,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = blenderColumnWidths(minimums, constraints.maxWidth);
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.topStart,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row(headers, widths, headerStyle),
              const SizedBox(height: 8),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _row(row, widths, valueStyle, softWrap: false),
                ),
            ],
          ),
        );
      },
    );
  }

  /// The text of one step's row, a cell per column.
  List<String> _cells(BuildContext context, BlendStep step) {
    final fillGas = step.fillGas;
    return [
      fillGas == null
          ? context.l10n.gasCalculators_blender_stepStartLabel
          : context.l10n.gasCalculators_blender_stepAdd(
              formatPreciseGasName(context, fillGas),
            ),
      fillGas == null
          ? ''
          : '+${units.formatPressureValue(step.addedBar, decimals: decimals)}',
      units.formatPressureValue(step.pressureBar, decimals: decimals),
      // The header says what the two numbers are, so no "Tx" here.
      formatPreciseMix(context, step.resultingMix, trimixPrefix: false),
    ];
  }

  /// The width each column cannot go below: its widest value on one line, or
  /// its longest header word, since a header may wrap but only between words.
  List<double> _minimumWidths(
    BuildContext context,
    List<String> headers,
    TextStyle? headerStyle,
    List<List<String>> rows,
    TextStyle? valueStyle,
  ) {
    final direction = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final boldText = MediaQuery.boldTextOf(context);

    double measure(String text, TextStyle? style, {required bool oneLine}) {
      final painter = TextPainter(
        // The bold weight and locale `Text` applies itself: a column measured
        // without them comes up short, and a cell that short clips its value.
        text: TextSpan(
          text: text,
          style: boldText
              ? style?.merge(const TextStyle(fontWeight: FontWeight.bold))
              : style,
        ),
        textDirection: direction,
        textScaler: textScaler,
        locale: locale,
      )..layout();
      final width = oneLine
          ? painter.maxIntrinsicWidth
          : painter.minIntrinsicWidth;
      painter.dispose();
      // Rounded up so a measured column never comes up a sub-pixel short of
      // the Text's own layout.
      return width.ceilToDouble();
    }

    return [
      for (var column = 0; column < headers.length; column++)
        (column == 0 ? 0.0 : _columnGap) +
            [
              measure(headers[column], headerStyle, oneLine: false),
              for (final row in rows)
                measure(row[column], valueStyle, oneLine: true),
            ].reduce(math.max),
    ];
  }

  Widget _row(
    List<String> cells,
    List<double> widths,
    TextStyle? style, {
    bool softWrap = true,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var column = 0; column < cells.length; column++)
          SizedBox(
            width: widths[column],
            child: Text(
              cells[column],
              style: style,
              softWrap: softWrap,
              textAlign: column == 0 ? TextAlign.start : TextAlign.end,
            ),
          ),
      ],
    );
  }
}
