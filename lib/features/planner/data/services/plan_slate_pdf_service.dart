import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/contingency_service.dart';
import 'package:submersion/features/planner/domain/services/range_table_service.dart';

/// Localized strings the slate needs (assembled from context.l10n at the
/// call site so the service stays context-free).
class PlanSlateLabels {
  final String runtimeTable;
  final String gasPlan;
  final String contingencies;
  final String Function(String gas) lostGasLabel;
  final String rangeTable;
  final String bailout;
  final String stop;
  final String depth;
  final String runtime;
  final String gas;
  final String turnAt;
  final String minGas;
  final String base;

  const PlanSlateLabels({
    required this.runtimeTable,
    required this.gasPlan,
    required this.contingencies,
    required this.lostGasLabel,
    required this.rangeTable,
    required this.bailout,
    required this.stop,
    required this.depth,
    required this.runtime,
    required this.gas,
    required this.turnAt,
    required this.minGas,
    required this.base,
  });
}

/// Renders a plan as a high-contrast printable dive slate: runtime table,
/// gas plan, contingency tables, bailout summary, and range table. Pure
/// consumer of engine outputs — no deco math of its own.
class PlanSlatePdfService {
  const PlanSlatePdfService();

  Future<List<int>> buildSlate({
    required domain.DivePlan plan,
    required PlanOutcome outcome,
    required List<DeviationOutcome> deviations,
    required List<LostGasOutcome> lostGas,
    required RangeTable? rangeTable,
    required BailoutOutcome? bailout,
    required UnitFormatter units,
    required PlanSlateLabels labels,
  }) async {
    await PdfFonts.instance.initialize();
    final pdf = pw.Document(theme: PdfFonts.instance.theme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _header(plan, outcome, units),
          pw.SizedBox(height: 10),
          _sectionTitle(labels.runtimeTable),
          _runtimeTable(outcome, units, labels),
          pw.SizedBox(height: 10),
          _sectionTitle(labels.gasPlan),
          _gasTable(plan, outcome, units, labels),
          if (bailout != null) ...[
            pw.SizedBox(height: 10),
            _sectionTitle(labels.bailout),
            _bailoutSummary(bailout, units),
          ],
          if (deviations.isNotEmpty || lostGas.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _sectionTitle(labels.contingencies),
            for (final deviation in deviations) ...[
              _subTitle(_deviationLabel(deviation, plan, units)),
              _runtimeTable(deviation.outcome, units, labels),
              pw.SizedBox(height: 6),
            ],
            for (final lost in lostGas) ...[
              _subTitle(labels.lostGasLabel(lost.tank.gasMix.name)),
              _runtimeTable(lost.outcome, units, labels),
              pw.SizedBox(height: 6),
            ],
          ],
          if (rangeTable != null && !rangeTable.isEmpty) ...[
            pw.SizedBox(height: 10),
            _sectionTitle(labels.rangeTable),
            _rangeGrid(rangeTable, units, labels),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  String _deviationLabel(
    DeviationOutcome deviation,
    domain.DivePlan plan,
    UnitFormatter units,
  ) {
    final depth =
        '+${units.formatDepth(plan.deviationDepthDelta, decimals: 0)}';
    final time = '+${plan.deviationTimeMinutes} min';
    return switch (deviation.key) {
      'deeper' => depth,
      'longer' => time,
      _ => '$depth $time',
    };
  }

  pw.Widget _header(
    domain.DivePlan plan,
    PlanOutcome outcome,
    UnitFormatter units,
  ) {
    final mode = plan.mode == domain.PlanMode.ccr ? 'CCR' : 'OC';
    final date =
        '${plan.updatedAt.year}-${plan.updatedAt.month.toString().padLeft(2, '0')}-${plan.updatedAt.day.toString().padLeft(2, '0')}';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          plan.name,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '$date   $mode   GF ${plan.gfLow}/${plan.gfHigh}   '
          'max ${units.formatDepth(outcome.maxDepth)}   '
          'RT ${_minutes(outcome.runtimeSeconds)}   '
          'CNS ${outcome.cnsEnd.toStringAsFixed(0)}%',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Divider(thickness: 1.2),
      ],
    );
  }

  pw.Widget _sectionTitle(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Text(
      text.toUpperCase(),
      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget _subTitle(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 3, bottom: 2),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
    ),
  );

  String _minutes(int seconds) => '${(seconds / 60).ceil()} min';

  pw.Widget _runtimeTable(
    PlanOutcome outcome,
    UnitFormatter units,
    PlanSlateLabels labels,
  ) {
    pw.Widget cell(String text, {bool header = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: header ? pw.FontWeight.bold : null,
        ),
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          children: [
            cell(labels.depth, header: true),
            cell(labels.stop, header: true),
            cell(labels.runtime, header: true),
            cell(labels.gas, header: true),
          ],
        ),
        for (final stop in outcome.stops)
          pw.TableRow(
            children: [
              cell(units.formatDepth(stop.depthMeters, decimals: 0)),
              cell('${(stop.durationSeconds / 60).ceil()}'),
              cell(
                '${((stop.arrivalRuntimeSeconds + stop.durationSeconds) / 60).ceil()}',
              ),
              cell(
                GasMix(o2: stop.gasFO2 * 100.0, he: stop.gasFHe * 100.0).name,
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _gasTable(
    domain.DivePlan plan,
    PlanOutcome outcome,
    UnitFormatter units,
    PlanSlateLabels labels,
  ) {
    String tankLabel(String tankId) {
      final tank = plan.tanks.where((t) => t.id == tankId).firstOrNull;
      if (tank == null) return '--';
      return tank.name ?? tank.gasMix.name;
    }

    pw.Widget cell(String text, {bool header = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: header ? pw.FontWeight.bold : null,
        ),
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(width: 0.4),
      children: [
        pw.TableRow(
          children: [
            cell(labels.gas, header: true),
            cell('L', header: true),
            cell('%', header: true),
            cell(labels.turnAt, header: true),
            cell(labels.minGas, header: true),
          ],
        ),
        for (final usage in outcome.tankUsages)
          pw.TableRow(
            children: [
              cell(tankLabel(usage.tankId)),
              cell(usage.litersUsed.toStringAsFixed(0)),
              cell('${usage.percentUsed.toStringAsFixed(0)}%'),
              cell(
                usage.turnPressureBar != null
                    ? units.formatPressure(usage.turnPressureBar!, decimals: 0)
                    : '--',
              ),
              cell(
                usage.minGasBar != null
                    ? units.formatPressure(usage.minGasBar!, decimals: 0)
                    : '--',
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _bailoutSummary(BailoutOutcome bailout, UnitFormatter units) {
    final worst = bailout.worstCase;
    return pw.Text(
      'TTS ${_minutes(worst.ttsSeconds)} @ ${units.formatDepth(worst.depthMeters)} '
      '(${worst.litersRequired.toStringAsFixed(0)} L / '
      '${bailout.availableLiters.toStringAsFixed(0)} L)',
      style: const pw.TextStyle(fontSize: 10),
    );
  }

  pw.Widget _rangeGrid(
    RangeTable table,
    UnitFormatter units,
    PlanSlateLabels labels,
  ) {
    pw.Widget cell(String text, {bool header = false, bool flag = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: header || flag ? pw.FontWeight.bold : null,
              color: flag ? PdfColors.red900 : null,
            ),
          ),
        );

    String depthLabel(double delta) => delta == 0
        ? labels.base
        : '${delta > 0 ? '+' : '-'}${units.formatDepth(delta.abs(), decimals: 0)}';
    String timeLabel(int delta) =>
        delta == 0 ? labels.base : '${delta > 0 ? '+' : '-'}${delta.abs()} min';

    return pw.Table(
      border: pw.TableBorder.all(width: 0.4),
      children: [
        pw.TableRow(
          children: [
            cell('', header: true),
            for (final timeDelta in table.timeDeltas)
              cell(timeLabel(timeDelta), header: true),
          ],
        ),
        for (var d = 0; d < table.depthDeltas.length; d++)
          pw.TableRow(
            children: [
              cell(depthLabel(table.depthDeltas[d]), header: true),
              for (final rangeCell in table.cells[d])
                if (rangeCell == null)
                  cell('--')
                else
                  cell(
                    '${(rangeCell.outcome.ttsAtBottom / 60).ceil()}',
                    flag: !rangeCell.outcome.isDiveable,
                  ),
            ],
          ),
      ],
    );
  }
}
