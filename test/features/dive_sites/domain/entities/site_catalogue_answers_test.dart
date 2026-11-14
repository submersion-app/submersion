import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';

void main() {
  group('reading', () {
    test('nothing stored is no answers', () {
      expect(SiteCatalogueAnswers.decode(null), SiteCatalogueAnswers.empty);
      expect(SiteCatalogueAnswers.decode(''), SiteCatalogueAnswers.empty);
      expect(SiteCatalogueAnswers.decode('   '), SiteCatalogueAnswers.empty);
    });

    test('text that is not JSON is no answers', () {
      expect(
        SiteCatalogueAnswers.decode('not json'),
        SiteCatalogueAnswers.empty,
      );
    });

    test('JSON of the wrong shape is no answers', () {
      expect(SiteCatalogueAnswers.decode('[1,2]'), SiteCatalogueAnswers.empty);
      expect(SiteCatalogueAnswers.decode('7'), SiteCatalogueAnswers.empty);
      expect(SiteCatalogueAnswers.decode('"r1"'), SiteCatalogueAnswers.empty);
    });

    test('a part of the wrong shape is skipped, the rest is read', () {
      final answers = SiteCatalogueAnswers.decode(
        '{"also":"r9","not":["r1",7],"declined":{"r1":"depth","r2":["depth",3]}}',
      );
      expect(answers.also, isEmpty);
      expect(answers.notSame, {'r1'});
      expect(answers.declined, {
        'r2': {'depth'},
      });
    });

    test('all three parts are read', () {
      final answers = SiteCatalogueAnswers.decode(
        '{"also":["r2"],"not":["r3","r4"],"declined":{"r1":["depth","entry"]}}',
      );
      expect(answers.also, {'r2'});
      expect(answers.notSame, {'r3', 'r4'});
      expect(answers.declined, {
        'r1': {'depth', 'entry'},
      });
      expect(answers.isEmpty, isFalse);
    });
  });

  group('writing', () {
    test('no answers are stored as nothing', () {
      expect(SiteCatalogueAnswers.empty.encode(), isNull);
      expect(const SiteCatalogueAnswers(declined: {'r1': {}}).encode(), isNull);
    });

    test('what is written reads back the same', () {
      const answers = SiteCatalogueAnswers(
        also: {'r2'},
        notSame: {'r3'},
        declined: {
          'r1': {'depth'},
        },
      );
      expect(SiteCatalogueAnswers.decode(answers.encode()), answers);
    });

    test('equal answers are written the same way whatever their order', () {
      const one = SiteCatalogueAnswers(
        notSame: {'b', 'a'},
        declined: {
          'r2': {'entry', 'depth'},
          'r1': {'depth'},
        },
      );
      const other = SiteCatalogueAnswers(
        notSame: {'a', 'b'},
        declined: {
          'r1': {'depth'},
          'r2': {'depth', 'entry'},
        },
      );
      expect(one.encode(), other.encode());
    });

    test('a key this build does not know is kept when the value changes', () {
      final answers = SiteCatalogueAnswers.decode(
        '{"future":[1],"not":["r1"]}',
      ).withNotSame('r2');
      final written = jsonDecode(answers.encode()!) as Map<String, dynamic>;
      expect(written['future'], [1]);
      expect(written['not'], ['r1', 'r2']);
    });

    test('only an unknown key is still worth storing', () {
      final answers = SiteCatalogueAnswers.decode('{"future":[1]}');
      expect(answers.isEmpty, isFalse);
      expect(answers.encode(), '{"future":[1]}');
    });
  });

  group('changing', () {
    test('a record said not to be this site is remembered', () {
      final answers = SiteCatalogueAnswers.empty.withNotSame('r1');
      expect(answers.notSame, {'r1'});
    });

    test('fields turned down for one record add up', () {
      final answers = SiteCatalogueAnswers.empty
          .withDeclined('r1', ['depth'])
          .withDeclined('r1', ['entry'])
          .withDeclined('r2', ['depth']);
      expect(answers.declined, {
        'r1': {'depth', 'entry'},
        'r2': {'depth'},
      });
    });

    test('turning down no fields changes nothing', () {
      expect(
        SiteCatalogueAnswers.empty.withDeclined('r1', const []),
        SiteCatalogueAnswers.empty,
      );
    });

    test('copyWith replaces only what is named', () {
      const answers = SiteCatalogueAnswers(also: {'r2'}, notSame: {'r3'});
      final changed = answers.copyWith(also: {'r5'});
      expect(changed.also, {'r5'});
      expect(changed.notSame, {'r3'});
    });
  });
}
