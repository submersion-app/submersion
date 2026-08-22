import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_chart.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';

/// The depth profile is drawn with the pdf package's own vector chart widgets
/// rather than by rasterizing the on-screen fl_chart widget: `buildPdf` has no
/// BuildContext, and `toImage()` hangs under flutter test, which would make
/// this untestable.
void main() {
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(depthUnit: DepthUnit.feet, altitudeUnit: AltitudeUnit.feet),
  );

  DiveProfilePoint p(int t, double d) =>
      DiveProfilePoint(timestamp: t, depth: d);

  final squareProfile = PdfProfileSeries.downsampled([
    p(0, 0),
    p(300, 18.0),
    p(900, 18.0),
    p(1500, 0),
  ]);

  Future<String> render(pw.Widget chart) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(build: (context) => chart));
    return pdfVisibleText(await doc.save());
  }

  test('returns null for an empty series', () {
    expect(
      PdfProfileChart.build(series: const PdfProfileSeries([]), units: metric),
      isNull,
      reason: 'callers omit the region entirely rather than print an empty box',
    );
  });

  test('renders a depth axis that spans the dive', () async {
    final chart = PdfProfileChart.build(series: squareProfile, units: metric);
    expect(chart, isNotNull);

    final text = await render(chart!);
    // An 18 m dive rounds to a 0-20 m axis in 5 m steps.
    expect(text, contains('0'));
    expect(text, contains('20'));
  });

  test('labels the depth axis in the diver units', () async {
    final metricText = await render(
      PdfProfileChart.build(series: squareProfile, units: metric)!,
    );
    expect(metricText, contains('m'));

    final imperialText = await render(
      PdfProfileChart.build(series: squareProfile, units: imperial)!,
    );
    expect(imperialText, contains('ft'));
    expect(
      imperialText,
      contains('80'),
      reason:
          '18 m is 59 ft, which rounds to a 0-80 ft axis in 20 ft steps; '
          'a metric axis would never produce that label',
    );
  });

  test('leaves clearance under the deepest sample', () async {
    // Anchoring the axis floor exactly at max depth puts the bottom phase on
    // the axis line, where the filled area has zero height and the flat part
    // of the dive disappears. The deepest label must read deeper than the
    // dive itself.
    final text = await render(
      PdfProfileChart.build(series: squareProfile, units: metric)!,
    );
    final labels = text.split(' ').map(int.tryParse).whereType<int>().toList();

    expect(
      labels.any((value) => value > 18),
      isTrue,
      reason: 'an 18 m dive needs an axis floor deeper than 18 m, got $labels',
    );
  });

  test('handles a single-sample profile without throwing', () async {
    final series = PdfProfileSeries.downsampled([p(0, 5.0)]);
    final chart = PdfProfileChart.build(series: series, units: metric);
    expect(chart, isNotNull);
    await render(chart!);
  });

  test('handles an all-zero-depth profile without throwing', () async {
    final series = PdfProfileSeries.downsampled([p(0, 0), p(60, 0)]);
    final chart = PdfProfileChart.build(series: series, units: metric);
    expect(chart, isNotNull);
    await render(chart!);
  });

  test('renders a long profile that has been downsampled', () async {
    final raw = List.generate(4000, (i) => p(i * 2, (i % 40) * 1.0));
    final chart = PdfProfileChart.build(
      series: PdfProfileSeries.downsampled(raw),
      units: metric,
    );
    expect(chart, isNotNull);
    await render(chart!);
  });
}
