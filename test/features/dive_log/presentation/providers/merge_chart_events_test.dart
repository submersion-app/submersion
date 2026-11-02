import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_annotations_provider.dart';

ProfileEvent _ann(String id) => ProfileEvent.annotation(
  id: id,
  diveId: 'd',
  timestamp: 10,
  words: 'w',
  createdAt: DateTime(2026),
);

ProfileEvent _bookmark(String id) => ProfileEvent.bookmark(
  id: id,
  diveId: 'd',
  timestamp: 5,
  createdAt: DateTime(2026),
);

/// The chart's events list (#4109): the analysis's non-annotation events
/// plus the annotations, with a stable identity while the inputs are, so a
/// hover move does not look like a new events list to the chart.
void main() {
  test(
    'drops annotation rows the analysis carried and appends the live ones',
    () {
      final analysis = [_bookmark('b'), _ann('stale')];
      final annotations = [_ann('a')];
      expect(mergeChartEvents(analysis, annotations)!.map((e) => e.id), [
        'b',
        'a',
      ]);
    },
  );

  test('keeps its identity while both inputs keep theirs', () {
    final analysis = [_bookmark('b')];
    final annotations = [_ann('a')];
    final first = mergeChartEvents(analysis, annotations);
    expect(identical(first, mergeChartEvents(analysis, annotations)), isTrue);
    expect(identical(first, mergeChartEvents(analysis, [_ann('a')])), isFalse);
  });

  test('nothing to draw is null; annotations alone are passed through', () {
    expect(mergeChartEvents(null, const []), isNull);
    final annotations = [_ann('a')];
    expect(identical(mergeChartEvents(null, annotations), annotations), isTrue);
  });
}
