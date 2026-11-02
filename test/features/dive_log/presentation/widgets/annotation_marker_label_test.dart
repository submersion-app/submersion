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

  test('a line break inside the passage reads as a space', () {
    expect(
      annotationMarkerLabel(_ann('tank one\nlow  on\n\tgas')),
      'tank one low on gas',
    );
    expect(cutAtWord('Annotate\nthis', maxChars: 40), 'Annotate this');
  });

  test('the cut never splits an emoji or a combined character', () {
    final label = annotationMarkerLabel(
      _ann('Saw a turtle \u{1F422}\u{1F422}\u{1F422} and then a shark'),
      maxChars: 16,
    );
    expect(label, 'Saw a turtle \u{1F422}\u{1F422}\u{1F422}\u2026');
    expect(cutAtWord('e\u0301' * 10, maxChars: 4), '${'e\u0301' * 4}\u2026');
  });

  test('one long word is cut hard', () {
    expect(annotationMarkerLabel(_ann('a' * 40), maxChars: 10), '${'a' * 10}…');
  });
}
