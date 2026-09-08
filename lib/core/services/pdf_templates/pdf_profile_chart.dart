import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

/// Depth profile drawn as native PDF vector graphics.
///
/// Uses the pdf package's own chart widgets rather than rasterizing the
/// on-screen `DiveProfileChart`. That widget needs a live element tree, and
/// `buildPdf` has no BuildContext; `RenderRepaintBoundary.toImage()` also
/// hangs under `flutter test`, which would leave this untestable. Vector
/// output additionally stays sharp at print resolution and costs few bytes.
class PdfProfileChart {
  const PdfProfileChart._();

  /// Build the chart, or null when [series] carries no samples.
  ///
  /// Returning null lets callers drop the whole region, including its heading,
  /// so a manually logged dive does not print an empty frame.
  static pw.Widget? build({
    required PdfProfileSeries series,
    required UnitFormatter units,
    double height = 150,
    PdfColor color = PdfColors.blue700,
  }) {
    if (series.isEmpty) return null;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // The axis labels are bare numbers to keep them narrow, so the units
        // are stated once in the heading.
        pw.Text(
          'Depth Profile (${units.depthSymbol} vs min)',
          style: const pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.SizedBox(height: height, child: _chart(series, units, color)),
      ],
    );
  }

  /// Depth runs downward, so it is plotted as a negative value and the axis
  /// labels are negated back for display.
  static pw.Widget _chart(
    PdfProfileSeries series,
    UnitFormatter units,
    PdfColor color,
  ) {
    final data = series.points
        .map(
          (p) => pw.PointChartValue(
            p.timestamp / 60.0,
            -units.convertDepth(p.depth),
          ),
        )
        .toList();

    return pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis(
          _timeTicks(series),
          buildLabel: (value) => pw.Text(
            value.toStringAsFixed(0),
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ),
        yAxis: pw.FixedAxis(
          _depthTicks(series, units),
          buildLabel: (value) => pw.Text(
            // Negated back to a positive depth for the reader.
            (-value).toStringAsFixed(0),
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ),
      ),
      datasets: [
        pw.LineDataSet(
          data: data,
          drawPoints: false,
          drawSurface: true,
          surfaceOpacity: 0.2,
          color: color,
          lineWidth: 1.0,
        ),
      ],
    );
  }

  /// Minute ticks, ascending, as [pw.FixedAxis] requires.
  ///
  /// Every 5 minutes for a normal dive, every 10 for a long one, so a two hour
  /// dive does not crowd the axis with 24 labels.
  static List<double> _timeTicks(PdfProfileSeries series) {
    final totalMinutes = series.durationSeconds / 60.0;
    if (totalMinutes <= 0) return <double>[0, 1];

    final step = totalMinutes > 60 ? 10.0 : 5.0;
    final ticks = <double>[];
    for (var t = 0.0; t < totalMinutes; t += step) {
      ticks.add(t);
    }
    ticks.add(totalMinutes.ceilToDouble());
    return ticks;
  }

  /// Depth ticks from below the deepest sample up to the surface.
  ///
  /// Negated, so the list is built deepest-first to come out ascending, which
  /// [pw.FixedAxis] asserts on.
  ///
  /// The floor is deliberately deeper than the dive. Anchoring it exactly at
  /// max depth puts the whole bottom phase on the axis line, where the filled
  /// area has zero height and the flat part of the dive vanishes.
  static List<double> _depthTicks(
    PdfProfileSeries series,
    UnitFormatter units,
  ) {
    final maxConverted = units.convertDepth(series.maxDepth);
    if (maxConverted <= 0) return <double>[-1, 0];

    final step = _niceStep(maxConverted / 4);
    var divisions = (maxConverted / step).ceil();
    // Guarantee at least a quarter step of clearance under the deepest sample.
    if (step * divisions - maxConverted < step * 0.25) divisions++;

    return <double>[for (var i = divisions; i >= 0; i--) -(step * i)];
  }

  /// Round [raw] up to a readable axis increment (1, 2, 2.5 or 5 per decade).
  static double _niceStep(double raw) {
    if (raw <= 0) return 1;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final normalized = raw / magnitude;
    for (final candidate in const [1.0, 2.0, 2.5, 5.0]) {
      if (normalized <= candidate) return candidate * magnitude;
    }
    return 10 * magnitude;
  }
}
