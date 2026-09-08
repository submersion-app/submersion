import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A dive computer records a sample every few seconds, so a 60 minute dive can
/// carry well over a thousand points. A chart a few inches wide cannot resolve
/// that many, and a 500 dive logbook would hold them all in memory at once, so
/// the series is downsampled before it reaches a template.
void main() {
  DiveProfilePoint p(int t, double d) =>
      DiveProfilePoint(timestamp: t, depth: d);

  test('leaves a short profile untouched', () {
    final raw = [p(0, 0), p(10, 5), p(20, 0)];
    final series = PdfProfileSeries.downsampled(raw);
    expect(series.points, hasLength(3));
    expect(series.points.map((e) => e.depth), [0, 5, 0]);
  });

  test('caps a long profile at maxPoints', () {
    final raw = List.generate(5000, (i) => p(i * 10, (i % 30) + 1.0));
    final series = PdfProfileSeries.downsampled(raw);
    expect(series.points.length, lessThanOrEqualTo(PdfProfileSeries.maxPoints));
    expect(series.points.length, greaterThan(1));
  });

  test('preserves the first sample, the last sample and the deepest', () {
    final raw = List.generate(5000, (i) => p(i * 10, i == 3111 ? 42.5 : 5.0));
    final series = PdfProfileSeries.downsampled(raw);

    expect(series.points.first.timestamp, 0);
    expect(series.points.last.timestamp, 49990);
    expect(series.maxDepth, 42.5);
    expect(
      series.points.map((e) => e.depth),
      contains(42.5),
      reason:
          'a plain every-Nth downsample can drop the deepest sample, which '
          'would make the chart contradict the max depth field',
    );
  });

  test('keeps the samples in chronological order', () {
    final raw = List.generate(5000, (i) => p(i * 10, (i % 47) + 1.0));
    final series = PdfProfileSeries.downsampled(raw);
    final stamps = series.points.map((e) => e.timestamp).toList();
    expect(stamps, orderedEquals(List.of(stamps)..sort()));
  });

  test('an empty profile reports isEmpty', () {
    final series = PdfProfileSeries.downsampled(const []);
    expect(series.isEmpty, isTrue);
    expect(series.points, isEmpty);
    expect(series.maxDepth, 0);
  });

  test('reports the dive duration from the sample stamps', () {
    final series = PdfProfileSeries.downsampled([p(0, 0), p(1800, 10)]);
    expect(series.durationSeconds, 1800);
  });
}
