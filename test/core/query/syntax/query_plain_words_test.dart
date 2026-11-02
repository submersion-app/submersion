import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

import '../fixtures/fixture_registry.dart';

void main() {
  final now = DateTime(2026, 9, 25);
  const names = MapNameResolver({});

  final plainDives = QueryEntity(
    subject: QuerySubject.dives,
    table: 'dives',
    fields: fixtureDives.fields,
    relations: fixtureDives.relations,
    textSearchSql: fixtureDives.textSearchSql,
    plainWords: PlainWordReading(
      dateField: 'date',
      isPhrase: (words) => words.join(' ') == 'salt water',
    ),
  );

  ParseResult parse(String text, {QueryEntity? root, String? language}) =>
      QueryParser(
        fixtureRegistry,
        root ?? plainDives,
        ParseContext(
          prefs: kMetricPrefs,
          now: now,
          names: names,
          language: language,
        ),
      ).parse(text);
  QueryNode read(String text, {String? language}) =>
      (parse(text, language: language) as ParseOk).node!;

  TextNode word(String w) => TextNode([w]);
  ConditionNode range(DateTime start, DateTime end) => ConditionNode(
    FieldPath(['date']),
    QueryOp.inList,
    DateRangeValue(start, end),
  );
  ConditionNode month(int y, int m) =>
      range(DateTime(y, m, 1), DateTime(y, m + 1, 0));
  ConditionNode year(int y) => range(DateTime(y, 1, 1), DateTime(y, 12, 31));

  group('date phrases', () {
    test('month and year is one date condition', () {
      expect(
        read('ressel october 2018'),
        AndNode([word('ressel'), month(2018, 10)]),
      );
      expect(read('oct 2018'), month(2018, 10));
      expect(read('sept 2021'), month(2021, 9));
    });

    test('capitals read the same', () {
      expect(read('October 2018'), month(2018, 10));
      expect(read('OCT 2018'), month(2018, 10));
      expect(read('LAST YEAR'), year(2025));
    });

    test('a lone year stays a word', () {
      expect(read('ressel 2018'), AndNode([word('ressel'), word('2018')]));
      expect(read('2018'), word('2018'));
    });

    test('a year after in or during is a date', () {
      expect(read('ressel in 2018'), AndNode([word('ressel'), year(2018)]));
      expect(read('during 2018'), year(2018));
      expect(read('in october 2018'), month(2018, 10));
    });

    test('iso months and days', () {
      expect(read('2018-10'), month(2018, 10));
      expect(
        read('2018-10-14'),
        ConditionNode(
          FieldPath(['date']),
          QueryOp.eq,
          DateValue(DateTime(2018, 10, 14)),
        ),
      );
    });

    test('relative periods', () {
      expect(read('last year'), year(2025));
      expect(read('this year'), year(2026));
      expect(read('last month'), month(2026, 8));
      expect(read('last 90 days'), isA<ConditionNode>());
      expect(read('past 2 years'), isA<ConditionNode>());
    });

    test('open-ended periods are one bound', () {
      expect(
        read('since 2020'),
        ConditionNode(
          FieldPath(['date']),
          QueryOp.gte,
          DateValue(DateTime(2020, 1, 1)),
        ),
      );
      expect(
        read('before 2020'),
        ConditionNode(
          FieldPath(['date']),
          QueryOp.lte,
          DateValue(DateTime(2019, 12, 31)),
        ),
      );
    });

    test('two periods are one range', () {
      final expected = range(DateTime(2018, 1, 1), DateTime(2020, 12, 31));
      expect(read('2018 to 2020'), expected);
      expect(read('between 2018 and 2020'), expected);
      expect(read('ressel between 2018 and 2020'), isA<AndNode>());
    });

    test('a phrase beside a condition keeps both', () {
      expect(read('last year depth > 30'), isA<AndNode>());
    });

    test('quoted phrases stay text', () {
      expect(read('"last year"'), TextNode(['last', 'year']));
      expect(read('"october 2018"'), TextNode(['october', '2018']));
    });

    test('a negated phrase is a negated date', () {
      expect(read('not last year'), NotNode(year(2025)));
      expect(read('-2018-10'), NotNode(month(2018, 10)));
    });

    test('anything the grammar refuses stays plain words', () {
      expect(read('2018-13'), word('2018-13'));
      expect(read('2020 to 2018'), isA<AndNode>());
      expect(read('smarch 2018'), AndNode([word('smarch'), word('2018')]));
    });
  });

  group('filler words', () {
    test('drop beside another term', () {
      expect(read('ressel with mike'), AndNode([word('ressel'), word('mike')]));
      expect(read('with mike'), word('mike'));
    });

    test('the word dive only names what is being searched', () {
      expect(read('dives in the ressel'), word('ressel'));
      expect(read('dive'), word('dive'));
    });

    test('stay when every term is filler', () {
      expect(read('the'), word('the'));
      expect(read('with the'), AndNode([word('with'), word('the')]));
    });

    test('stay when quoted or negated', () {
      expect(read('"with" mike'), AndNode([word('with'), word('mike')]));
      expect(
        read('-with mike'),
        AndNode([NotNode(word('with')), word('mike')]),
      );
      expect(
        read('not with mike'),
        AndNode([NotNode(word('with')), word('mike')]),
      );
    });

    test('match any case', () {
      expect(read('ressel WITH mike'), AndNode([word('ressel'), word('mike')]));
    });

    test('a filler in the app language drops, a foreign one does not', () {
      expect(
        read('ressel avec mike', language: 'fr'),
        AndNode([word('ressel'), word('mike')]),
      );
      expect(
        read('ressel avec mike'),
        AndNode([word('ressel'), word('avec'), word('mike')]),
      );
    });

    test('English applies in every app language', () {
      expect(
        read('ressel with mike', language: 'fr'),
        AndNode([word('ressel'), word('mike')]),
      );
    });
  });

  group('label phrases', () {
    test('adjacent words spelling a label are one term', () {
      expect(read('salt water'), TextNode(['salt', 'water']));
      expect(read('SALT WATER'), TextNode(['SALT', 'WATER']));
      expect(
        read('ressel salt water'),
        AndNode([
          word('ressel'),
          TextNode(['salt', 'water']),
        ]),
      );
    });

    test('words that spell no label stay apart', () {
      expect(read('salt mine'), AndNode([word('salt'), word('mine')]));
    });
  });

  test('half-typed text never fails', () {
    for (final text in [
      'ressel in',
      'ressel between',
      'last',
      'since',
      'before',
      'between 2018',
      'between 2018 and',
      'ressel and',
      'oct',
      'in',
      '2018 to',
    ]) {
      expect(parse(text), isA<ParseOk>(), reason: text);
    }
  });

  test('an entity without plainWords reads the same text as words', () {
    final node =
        (parse('october 2018 with', root: fixtureDives) as ParseOk).node;
    expect(node, AndNode([word('october'), word('2018'), word('with')]));
  });

  test('each phrase survives a print and a parse', () {
    final printer = QueryPrinter(fixtureRegistry, plainDives, kMetricPrefs);
    for (final text in [
      'october 2018',
      'last year',
      'since 2020',
      'before 2020',
      '2018 to 2020',
      '2018-10-14',
      'in 2018',
    ]) {
      final node = read(text);
      expect(read(printer.print(node)), node, reason: text);
    }
  });
}
