import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/annotation_links.dart';

/// The pure module behind annotations (#4109): the `annotation:<id>` link
/// scheme in a dive's Notes, read and rewritten without touching any other
/// text the diver typed.
ProfileEvent _ann(String id, int timestamp) => ProfileEvent.annotation(
  id: id,
  diveId: 'd1',
  timestamp: timestamp,
  words: 'w',
  createdAt: DateTime(2026),
);

void main() {
  test('reads the id from an annotation href', () {
    expect(annotationIdFromHref('annotation:4f1c'), '4f1c');
    expect(annotationIdFromHref('Annotation:4f1c'), '4f1c');
    expect(annotationIdFromHref('https://x.test'), isNull);
    expect(annotationIdFromHref('annotation:'), isNull);
    expect(annotationIdFromHref(null), isNull);
  });

  test('collects ids and words, first occurrence wins', () {
    const notes =
        'I [felt sick](annotation:a) then [calm](annotation:b) and '
        '[again sick](annotation:a).';
    expect(annotationWordsInNotes(notes), {'a': 'felt sick', 'b': 'calm'});
    expect(annotationIdsInNotes(notes), {'a', 'b'});
  });

  test('words of a link with inline emphasis are the plain text', () {
    expect(annotationWordsInNotes('[**free** flow](annotation:a)'), {
      'a': 'free flow',
    });
  });

  test('other links and plain text yield nothing', () {
    expect(annotationWordsInNotes('see [site](https://s.test) and text'), {});
    expect(annotationWordsInNotes(''), {});
  });

  test('unlink keeps the words and leaves other links alone', () {
    expect(
      unlinkAnnotation(
        'x [a b](annotation:1) y [c](annotation:2) [w](https://s.test)',
        '1',
      ),
      'x a b y [c](annotation:2) [w](https://s.test)',
    );
    expect(unlinkAnnotation('plain', 'zzz'), 'plain');
  });

  test('unlink matches the scheme case-insensitively, like the reader', () {
    expect(unlinkAnnotation('x [w](Annotation:1) y', '1'), 'x w y');
  });

  test('unlink unescapes a bracket inside the words', () {
    expect(unlinkAnnotation(r'[a\]b](annotation:i)', 'i'), 'a]b');
  });

  test('append puts the link in its own paragraph', () {
    expect(
      appendAnnotationParagraph('First.', 'Octo free-flowed', 'id9'),
      'First.\n\n[Octo free-flowed](annotation:id9)',
    );
    expect(
      appendAnnotationParagraph('', 'Octo', 'id9'),
      '[Octo](annotation:id9)',
    );
  });

  test('link markdown escapes both brackets and unlink restores them', () {
    final md = annotationLinkMarkdown('tank [left] low', 'i');
    expect(md, r'[tank \[left\] low](annotation:i)');
    expect(annotationWordsInNotes(md), {'i': 'tank [left] low'});
    expect(unlinkAnnotation(md, 'i'), 'tank [left] low');
  });

  test('link markdown escapes a closing bracket in the words', () {
    expect(annotationLinkMarkdown('a]b', 'i'), r'[a\]b](annotation:i)');
    expect(annotationLinkMarkdown('plain', 'i'), '[plain](annotation:i)');
  });

  test(
    'dropOrphanAnnotations keeps computer events and linked annotations only',
    () {
      final gas = ProfileEvent.gasSwitch(
        id: 'g',
        diveId: 'd1',
        timestamp: 5,
        depth: 10,
        tankId: 't',
        createdAt: DateTime(2026),
      );
      final events = [gas, _ann('a', 10), _ann('b', 20)];
      final kept = dropOrphanAnnotations(events, 'only [x](annotation:b)');
      expect(kept, [gas, events[2]]);
      expect(dropOrphanAnnotations(events, ''), [gas]);
    },
  );

  test('annotationTimesOf formats m:ss per id', () {
    expect(annotationTimesOf([_ann('a', 1290), _ann('b', 65)]), {
      'a': '21:30',
      'b': '1:05',
    });
  });
}
