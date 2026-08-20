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

  test('renders a chart carrying the deepest depth as an axis label', () async {
    final chart = PdfProfileChart.build(series: squareProfile, units: metric);
    expect(chart, isNotNull);

    final text = await render(chart!);
    expect(text, contains('18'), reason: 'max depth appears on the depth axis');
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
      contains('59'),
      reason: '18 m is 59 ft, so the axis must show converted depths',
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
