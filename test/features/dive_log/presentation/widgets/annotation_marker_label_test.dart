import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_marker_label.dart';

ProfileEvent _ann(String words) => ProfileEvent.annotation(
  id: 'a',
  diveId: 'd',
  timestamp: 10,
  words: words,
  createdAt: DateTime(2026),
);

/// The words a profile marker shows for an annotation (#4109).
void main() {
  test('the marker label cuts at a word and adds an ellipsis', () {
    expect(
      annotationMarkerLabel(
        _ann('started feeling nauseous, probably the breakfast'),
      ),
      'started feeling nauseous…',
    );
    expect(annotationMarkerLabel(_ann('Octo free-flow')), 'Octo free-flow');
  });

  test('whitespace is trimmed and an empty description gives nothing', () {
    expect(annotationMarkerLabel(_ann('  calm  ')), 'calm');
    expect(annotationMarkerLabel(_ann('')), '');
  });

  test('one long word is cut hard', () {
    expect(annotationMarkerLabel(_ann('a' * 40), maxChars: 10), '${'a' * 10}…');
  });
}
