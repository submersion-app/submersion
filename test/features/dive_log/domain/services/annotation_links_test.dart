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

  group('renameAnnotationLinks', () {
    test('points each named link at its new id', () {
      expect(
        renameAnnotationLinks(
          'I [felt sick](annotation:a) then [recovered](annotation:b).',
          {'a': 'fresh'},
        ),
        'I [felt sick](annotation:fresh) then [recovered](annotation:b).',
      );
    });

    test('renames every link to an id, and a hand-edited scheme', () {
      expect(
        renameAnnotationLinks('[one](annotation:a) [two](Annotation:a)', {
          'a': 'fresh',
        }),
        '[one](annotation:fresh) [two](Annotation:fresh)',
      );
    });

    test('keeps escaped brackets in the words', () {
      expect(
        renameAnnotationLinks(r'[the \[left\] leg](annotation:a)', {'a': 'b'}),
        r'[the \[left\] leg](annotation:b)',
      );
    });

    test('leaves other text alone, and an empty map changes nothing', () {
      const notes = 'See [site](https://example.com/annotation:a).';
      expect(renameAnnotationLinks(notes, {'a': 'b'}), notes);
      expect(
        renameAnnotationLinks('[x](annotation:a)', const {}),
        '[x](annotation:a)',
      );
    });
  });

  test('annotationTimesOf formats m:ss per id', () {
    expect(annotationTimesOf([_ann('a', 1290), _ann('b', 65)]), {
      'a': '21:30',
      'b': '1:05',
    });
  });

  group('annotationLinkMarkdown escapes', () {
    test('a trailing backslash cannot eat the closing bracket', () {
      final link = annotationLinkMarkdown(r'C:\', 'x');
      expect(annotationWordsInNotes(link), {'x': r'C:\'});
    });

    test('a bracket the words already escape is not escaped again', () {
      expect(
        annotationLinkMarkdown(r'see \[1\] here', 'x'),
        r'[see \[1\] here](annotation:x)',
      );
    });

    test('unlinking keeps the words the backslash escaped', () {
      final link = annotationLinkMarkdown(r'C:\', 'x');
      expect(unlinkAnnotation(link, 'x'), r'C:\\');
    });
  });

  group('link patterns on text full of backslashes', () {
    // The escaped pair and the plain character used to overlap, so a failed
    // match tried both readings of every backslash: 2^64 steps here.
    final bracketed = '[${r'\a' * 64}] and on';

    test('renameAnnotationLinks finishes', () {
      expect(renameAnnotationLinks(bracketed, {'a': 'b'}), bracketed);
    });

    test('unlinkAnnotation finishes', () {
      expect(unlinkAnnotation(bracketed, 'a'), bracketed);
    });

    test('a backslash before a line break stays inside the link', () {
      const notes = 'a [one\\\ntwo](annotation:x) b';
      expect(
        renameAnnotationLinks(notes, {'x': 'y'}),
        contains('annotation:y'),
      );
    });
  });

  group('mayLinkAnnotations', () {
    test('is true for any spelling of the scheme', () {
      expect(mayLinkAnnotations('[w](annotation:a)'), isTrue);
      expect(mayLinkAnnotations('[w](Annotation:a)'), isTrue);
    });

    test('is false for notes with no link', () {
      expect(mayLinkAnnotations('plain words'), isFalse);
    });
  });

  // An address left behind by link markup the diver broke (#4815): Save
  // reads the annotation as removed, so the sitting counts these.
  group('strayAnnotationAddresses', () {
    const id = '1170e3dc-5a6d-43d6-9d68-410d4280845e';

    test('is zero for intact links and plain words', () {
      expect(strayAnnotationAddresses(''), isEmpty);
      expect(strayAnnotationAddresses('Calm. My annotation: none.'), isEmpty);
      expect(
        strayAnnotationAddresses(
          '[Vomit](annotation:$id) and [b](annotation:x)',
        ),
        isEmpty,
      );
    });

    test('counts an address whose link lost a bracket or parenthesis', () {
      expect(strayAnnotationAddresses('[Vomit](annotation:$id'), hasLength(1));
      expect(strayAnnotationAddresses('Vomit](annotation:$id)'), hasLength(1));
      expect(strayAnnotationAddresses('[Vomit]annotation:$id)'), hasLength(1));
      expect(
        strayAnnotationAddresses('[Vomit] (annotation:$id)'),
        hasLength(1),
      );
    });

    test('counts an address whose id was cut short', () {
      expect(
        strayAnnotationAddresses('Vomit annotation:1170e3dc'),
        hasLength(1),
      );
    });

    test('the nested shape a pin left on a phone: one stray, one link', () {
      const notes =
          '[Vomit buggy](annotation:$id\n'
          '[Fff](annotation:84baa0c1-f949-41b1-a117-994304f15de2))';
      expect(strayAnnotationAddresses(notes), hasLength(1));
      expect(annotationIdsInNotes(notes), {
        '84baa0c1-f949-41b1-a117-994304f15de2',
      });
    });

    test('ignores the case of the scheme, as links do', () {
      expect(strayAnnotationAddresses('[a](Annotation:$id)'), isEmpty);
      expect(strayAnnotationAddresses('[a](Annotation:$id'), hasLength(1));
    });

    test('ends the id where an id can end, not at punctuation after it', () {
      expect(strayAnnotationAddresses('[a](annotation:abc-12.'), [
        'annotation:abc-12',
      ]);
    });

    test('keeps the id as written: ids are compared case and all', () {
      expect(strayAnnotationAddresses('[a](Annotation:ABC'), [
        'annotation:ABC',
      ]);
    });

    test('counts a link whose id was deleted whole, but not prose', () {
      expect(strayAnnotationAddresses('[Vomit](annotation:)'), ['annotation:']);
      expect(strayAnnotationAddresses('Calm (annotation: see below)'), isEmpty);
    });
  });

  // Where a pin from the Notes toolbar may not land (#4815): the markup of
  // a link the diver broke, from its opening bracket to its address.
  group('brokenAnnotationLinkSpans', () {
    String marked(String notes) {
      final spans = brokenAnnotationLinkSpans(notes);
      final out = StringBuffer();
      var at = 0;
      for (final span in spans) {
        out
          ..write(notes.substring(at, span.start))
          ..write('<')
          ..write(notes.substring(span.start, span.end))
          ..write('>');
        at = span.end;
      }
      out.write(notes.substring(at));
      return out.toString();
    }

    test('is empty for intact links and plain words', () {
      expect(brokenAnnotationLinkSpans(''), isEmpty);
      expect(brokenAnnotationLinkSpans('Calm. annotation: none.'), isEmpty);
      expect(brokenAnnotationLinkSpans('[Vomit](annotation:a1) ok'), isEmpty);
    });

    test('a link that lost its closing parenthesis, from its bracket', () {
      expect(
        marked('Calm\n\n[Vomit buggy](annotation:a1'),
        'Calm\n\n<[Vomit buggy](annotation:a1>',
      );
    });

    test('takes in a parenthesis still after the address', () {
      expect(
        marked('Calm [Vomit]annotation:a1) end'),
        'Calm <[Vomit]annotation:a1)> end',
      );
      expect(marked('[Vomit](annotation:)'), '<[Vomit](annotation:)>');
    });

    test('with its opening bracket gone, from what is left of the markup', () {
      expect(
        marked('Calm Vomit](annotation:a1) end'),
        'Calm Vomit<](annotation:a1)> end',
      );
      expect(
        marked('[Vomit] (annotation:a1) end'),
        '[Vomit] <(annotation:a1)> end',
      );
    });

    test('a bare address is the address alone', () {
      expect(marked('Vomit annotation:a1 end'), 'Vomit <annotation:a1> end');
    });

    test('a bracket earlier in the paragraph with no markup after it is '
        'not the link', () {
      expect(
        marked('Saw [reef shark today. Vomit annotation:a1'),
        'Saw [reef shark today. Vomit <annotation:a1>',
      );
    });

    test('a link that lost its closing bracket, from its opening one', () {
      expect(
        marked('Calm [Vomit(annotation:a1) end'),
        'Calm <[Vomit(annotation:a1)> end',
      );
    });

    test('looks for the bracket in its own paragraph only', () {
      expect(
        marked('[Calm\n\nVomit](annotation:a1'),
        '[Calm\n\nVomit<](annotation:a1>',
      );
      expect(
        marked('[Calm\r\n\r\nVomit](annotation:a1'),
        '[Calm\r\n\r\nVomit<](annotation:a1>',
      );
    });

    test('the shape the report left: the broken link, not the pin', () {
      expect(
        marked('[Vomit buggy](annotation:a1\n[Fff](annotation:b2))'),
        '<[Vomit buggy](annotation:a1>\n[Fff](annotation:b2))',
      );
    });
  });

  // The rule the dive page and agent writes share (#4815).
  group('AnnotationLinkBaseline.damagedBy', () {
    const stored = '[Turtle](annotation:t1)\n\n[Ray](annotation:r1)';
    final baseline = AnnotationLinkBaseline.of(stored);
    const holding = {'t1', 'r1'};

    test('names the annotation whose link lost its parenthesis', () {
      expect(
        baseline.damagedBy(
          '[Turtle](annotation:t1\n\n[Ray](annotation:r1)',
          holding,
        ),
        {'t1'},
      );
    });

    test('a link deleted whole is a removal, not damage', () {
      expect(baseline.damagedBy('[Ray](annotation:r1)', holding), isEmpty);
    });

    test('an id edited inside a whole link names the annotation lost', () {
      expect(
        baseline.damagedBy(
          '[Turtle](annotation:t2)\n\n[Ray](annotation:r1)',
          holding,
        ),
        {'t1'},
      );
    });

    test('an id edited into another annotation\'s id names the one lost', () {
      expect(
        baseline.damagedBy(
          '[Turtle](annotation:r1)\n\n[Ray](annotation:r1)',
          holding,
        ),
        {'t1'},
      );
    });

    test('a link deleted whole beside another left as it was is a removal', () {
      expect(
        baseline.damagedBy('[Ray](annotation:r1) and again', holding),
        isEmpty,
      );
    });

    test('an id edited into a held annotation the stored Notes never linked '
        'names the one lost', () {
      expect(
        baseline.damagedBy('[Turtle](annotation:o1)\n\n[Ray](annotation:r1)', {
          ...holding,
          'o1',
        }),
        {'t1'},
      );
    });

    test('a pin placed in the sitting links its id once, as written', () {
      expect(
        baseline.damagedBy(
          '[Ray](annotation:r1)\n\n[Manta](annotation:p1)',
          {...holding, 'p1'},
          placed: {'p1'},
        ),
        isEmpty,
      );
    });

    test('an id differing only in case is another id', () {
      final mixed = AnnotationLinkBaseline.of(
        '[A](annotation:ABC)\n\n[a](annotation:abc)',
      );
      expect(mixed.damagedBy('[a](annotation:abc)', {'ABC', 'abc'}), isEmpty);
    });

    test('a link to an annotation not held loses nothing', () {
      expect(
        baseline.damagedBy('$stored\n\n[Shark](annotation:s9)', holding),
        isEmpty,
      );
    });
  });
}
