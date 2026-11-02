import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
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
      expect(
        read('site between 2018 and 2020'),
        AndNode([word('site'), expected]),
      );
      expect(
        read('favorite between 2018 and 2020'),
        AndNode([word('favorite'), expected]),
      );
    });

    group('a full date', () {
      final day = ConditionNode(
        FieldPath(['date']),
        QueryOp.eq,
        DateValue(DateTime(2018, 10, 14)),
      );

      test('is one day, however it is written', () {
        expect(read('14 october 2018'), day);
        expect(read('14th of oct 2018'), day);
        expect(read('october 14 2018'), day);
        expect(read('October 14, 2018'), day);
        expect(read('Oct 14th, 2018'), day);
      });

      test('sits among other terms', () {
        expect(
          read('ressel on 14 october 2018 with mike'),
          AndNode([word('ressel'), day, word('mike')]),
        );
        expect(
          read('ressel, october 14, 2018, mike'),
          AndNode([word('ressel'), day, word('mike')]),
        );
        expect(read('on the 14th of october 2018'), day);
      });

      test('reads as a range of two days', () {
        expect(
          read('october 14, 2018 to october 20, 2018'),
          range(DateTime(2018, 10, 14), DateTime(2018, 10, 20)),
        );
        expect(
          read('between 14th of october 2018 and 20th of october 2018'),
          range(DateTime(2018, 10, 14), DateTime(2018, 10, 20)),
        );
      });

      test('a day the month lacks stays words beside the month', () {
        expect(read('31 april 2018'), AndNode([word('31'), month(2018, 4)]));
      });

      test('a comma only joins a date before its year', () {
        expect(
          read('october 2018, 14'),
          AndNode([month(2018, 10), word('14')]),
        );
        expect(read('10, may 2018'), AndNode([word('10'), month(2018, 5)]));
      });

      test('a dotted month reads the same', () {
        expect(read('Oct. 14, 2018'), day);
        expect(read('14 oct. 2018'), day);
      });

      test('a month and day with no year stay words', () {
        expect(read('14 october'), AndNode([word('14'), word('october')]));
      });
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

  group('a date in the app language', () {
    final october14 = ConditionNode(
      FieldPath(['date']),
      QueryOp.eq,
      DateValue(DateTime(2018, 10, 14)),
    );

    test('reads among the words around it', () {
      expect(
        read('ressel 14 octubre 2018 con mike', language: 'es'),
        AndNode([word('ressel'), october14, word('mike')]),
      );
      expect(
        read('ressel octobre 2018', language: 'fr'),
        AndNode([word('ressel'), month(2018, 10)]),
      );
    });

    test('stays plain words in any other language', () {
      expect(
        read('14 octubre 2018', language: 'fr'),
        AndNode([word('14'), word('octubre'), word('2018')]),
      );
      expect(read('octubre 2018'), AndNode([word('octubre'), word('2018')]));
    });

    test('a filler of the language can join its parts', () {
      expect(read('14 de octubre de 2018', language: 'es'), october14);
      expect(read('octubre de 2018', language: 'es'), month(2018, 10));
      expect(read('14 de outubro de 2018', language: 'pt'), october14);
      expect(read('14 ottobre del 2018', language: 'it'), october14);
      expect(
        read('ressel de octubre de 2018', language: 'es'),
        AndNode([word('ressel'), month(2018, 10)]),
      );
    });

    test('a filler only joins a date', () {
      expect(
        read('octubre de mike', language: 'es'),
        AndNode([word('octubre'), word('mike')]),
      );
      expect(
        read('octubre 2018 de mike', language: 'es'),
        AndNode([month(2018, 10), word('mike')]),
      );
    });

    test('a filler that means "in" or "with" does not join a date', () {
      for (final (text, language) in [
        ('30 en octubre 2018', 'es'),
        ('30 em outubro 2018', 'pt'),
        ('30 en octobre 2018', 'fr'),
      ]) {
        expect(
          read(text, language: language),
          AndNode([word('30'), month(2018, 10)]),
          reason: text,
        );
      }
    });

    test('the ordinal mark on the first of a month reads', () {
      final may1 = ConditionNode(
        FieldPath(['date']),
        QueryOp.eq,
        DateValue(DateTime(2018, 5, 1)),
      );
      expect(read('1º de maio de 2018', language: 'pt'), may1);
      expect(read('1º de mayo de 2018', language: 'es'), may1);
      expect(read('1° maggio 2018', language: 'it'), may1);
    });

    test('a mark on any other number is not an ordinal', () {
      expect(
        read('28° october 2018'),
        AndNode([word('28'), word('°'), month(2018, 10)]),
      );
      expect(
        read('2° maggio 2018', language: 'it'),
        AndNode([word('2'), word('°'), month(2018, 5)]),
      );
    });

    test('a comma before a year reads in any digits', () {
      expect(read('أكتوبر 14, ٢٠١٨', language: 'ar'), october14);
    });

    test('a date field reads any digits', () {
      expect(read('date in ٢٠١٨', language: 'ar'), year(2018));
      expect(read('date = ٢٠١٨-١٠-١٤', language: 'ar'), october14);
    });

    test('an English filler does not join a date', () {
      expect(
        read('october with 2018'),
        AndNode([word('october'), word('2018')]),
      );
      expect(
        read('october with 2018', language: 'es'),
        AndNode([word('october'), word('2018')]),
      );
    });

    test('German writes a dot after the day', () {
      expect(read('14. Oktober 2018', language: 'de'), october14);
      expect(
        read('am 14. Oktober 2018 mit mike', language: 'de'),
        AndNode([october14, word('mike')]),
      );
    });

    test('Hungarian writes the year first, with dots', () {
      expect(read('2018. október 14.', language: 'hu'), october14);
      expect(read('2018. október', language: 'hu'), month(2018, 10));
      expect(read('2018 október 14', language: 'hu'), october14);
      expect(
        read('2018. október 14. ressel', language: 'hu'),
        AndNode([october14, word('ressel')]),
      );
    });

    test('Chinese marks the year, month and day', () {
      expect(read('2018年10月14日', language: 'zh'), october14);
      expect(read('2018 年 10 月 14 日', language: 'zh'), october14);
      expect(
        read('ressel 2018年10月', language: 'zh'),
        AndNode([word('ressel'), month(2018, 10)]),
      );
      expect(read('２０１８年１０月１４日', language: 'zh'), october14);
    });

    test('Hebrew and French forms read', () {
      expect(read('14 באוקטובר 2018', language: 'he'), october14);
      expect(read('14 fevrier 2018', language: 'fr'), isA<ConditionNode>());
      expect(read('1er mai 2018', language: 'fr'), isA<ConditionNode>());
    });

    test('Arabic-Indic digits read', () {
      expect(read('١٤ أكتوبر ٢٠١٨', language: 'ar'), october14);
      expect(read('أكتوبر ٢٠١٨', language: 'ar'), month(2018, 10));
    });

    test('a lone year in any digits stays a word', () {
      expect(read('٢٠١٨', language: 'ar'), word('٢٠١٨'));
      expect(read('in ٢٠١٨', language: 'ar'), year(2018));
    });

    test('a dot closing a date belongs to it', () {
      expect(
        read('october 2018. ressel'),
        AndNode([month(2018, 10), word('ressel')]),
      );
      expect(
        read('october 2018 . ressel'),
        AndNode([month(2018, 10), word('.'), word('ressel')]),
      );
    });

    test('validates, prints and reads back the same tree', () {
      for (final (text, language) in [
        ('14 de octubre de 2018', 'es'),
        ('ressel 14. Oktober 2018', 'de'),
        ('2018. október 14. ressel', 'hu'),
        ('2018年10月14日', 'zh'),
        ('since marzo 2020', 'es'),
      ]) {
        final node = read(text, language: language);
        expect(
          validateQuery(node, plainDives, fixtureRegistry),
          isEmpty,
          reason: text,
        );
        final printed = QueryPrinter(
          fixtureRegistry,
          plainDives,
          kMetricPrefs,
          language: language,
        ).print(node);
        expect(read(printed, language: language), node, reason: printed);
      }
    });

    test('a date field reads one too', () {
      expect(read('date in octubre 2018', language: 'es'), month(2018, 10));
      expect(read('date in 14 de octubre de 2018', language: 'es'), october14);
    });
  });

  group('filler words', () {
    test('drop beside another term', () {
      expect(read('ressel with mike'), AndNode([word('ressel'), word('mike')]));
      expect(read('with mike'), word('mike'));
    });

    test('short joining words drop too', () {
      expect(read('trip to egypt'), AndNode([word('trip'), word('egypt')]));
      expect(read('my dives at ressel'), word('ressel'));
      expect(read('a wreck for fun'), AndNode([word('wreck'), word('fun')]));
    });

    test('to still joins two periods', () {
      expect(
        read('2018 to 2020'),
        range(DateTime(2018, 1, 1), DateTime(2020, 12, 31)),
      );
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

  group('commas', () {
    test('a comma between terms is ignored', () {
      expect(
        read('ressel, october 2018'),
        AndNode([word('ressel'), month(2018, 10)]),
      );
      expect(read('ressel, mike'), AndNode([word('ressel'), word('mike')]));
    });

    test('a trailing comma is half way to another term', () {
      expect(read('ressel,'), word('ressel'));
    });

    test('an entity without plainWords still refuses a comma', () {
      expect(parse('ressel, mike', root: fixtureDives), isA<ParseFailure>());
    });
  });

  group('a phrase after a date field', () {
    test('reads the whole phrase', () {
      expect(read('date in october 2018'), month(2018, 10));
      expect(read('date in last year'), year(2025));
      expect(read('date:october 2018'), month(2018, 10));
    });

    test('stops at the next term', () {
      expect(
        read('date in 2018 ressel'),
        AndNode([year(2018), word('ressel')]),
      );
    });

    test('what the grammar refuses stays an error', () {
      expect(parse('date in sometime'), isA<ParseFailure>());
    });

    test('between reads two periods', () {
      expect(
        read('date between 2018 and 2020'),
        range(DateTime(2018, 1, 1), DateTime(2020, 12, 31)),
      );
      expect(
        read('date between march 2018 and june 2019'),
        range(DateTime(2018, 3, 1), DateTime(2019, 6, 30)),
      );
    });

    test('between reads two full dates in either order', () {
      expect(
        read('date between 20 october 2018 and 14 october 2018'),
        range(DateTime(2018, 10, 14), DateTime(2018, 10, 20)),
      );
    });

    test('between two days keeps its own form', () {
      expect(
        read('date between 2025-03-14 and 2025-03-15'),
        isA<ConditionNode>().having((c) => c.op, 'op', QueryOp.between),
      );
    });

    test('reads a full date', () {
      final day = ConditionNode(
        FieldPath(['date']),
        QueryOp.eq,
        DateValue(DateTime(2018, 10, 14)),
      );
      expect(read('date in 14 october 2018'), day);
      expect(read('date:october 14, 2018'), day);
    });

    test('one iso day under in is plain equality, so it validates', () {
      expect(
        read('date in 2018-10-14'),
        ConditionNode(
          FieldPath(['date']),
          QueryOp.eq,
          DateValue(DateTime(2018, 10, 14)),
        ),
      );
      expect(
        validateQuery(read('date in 2018-10-14'), plainDives, fixtureRegistry),
        isEmpty,
      );
    });

    test('between reads full dates, alone or beside an iso day', () {
      final expected = range(DateTime(2018, 10, 14), DateTime(2018, 10, 20));
      expect(
        read('date between 14 october 2018 and 20 october 2018'),
        expected,
      );
      expect(read('date between 2018-10-14 and 20 october 2018'), expected);
      expect(read('date between 14 october 2018 and 2018-10-20'), expected);
    });
  });

  group('the editor context', () {
    final context = QueryEditorContext(
      registry: fixtureRegistry,
      root: plainDives,
      prefs: kMetricPrefs,
      names: names,
      labels: const MapQueryLabels(),
      now: () => now,
      language: 'fr',
    );

    test('reads filler words in its language', () {
      final node = context.parser.parse('ressel avec mike') as ParseOk;
      expect(node.node, AndNode([word('ressel'), word('mike')]));
    });

    test('prints them so they read back', () {
      expect(context.printer.print(word('avec')), '"avec"');
    });

    test('keeps its language through copyWith', () {
      expect(context.copyWith(prefs: kMetricPrefs).language, 'fr');
    });
  });

  group('printing keeps a filler word that was asked for', () {
    final printer = QueryPrinter(
      fixtureRegistry,
      plainDives,
      kMetricPrefs,
      language: 'fr',
    );

    test('a quoted filler survives a print and a parse', () {
      final node = read('"with" mike');
      expect(read(printer.print(node)), node);
    });

    test('a filler in the app language does too', () {
      final node = read('"avec" mike', language: 'fr');
      expect(read(printer.print(node), language: 'fr'), node);
    });

    test('a word that spells a date stays text', () {
      for (final text in ['"2018年"', '"2018年10月"', '"２０１８年１０月"']) {
        final node = read(text, language: 'zh');
        expect(node, isA<TextNode>(), reason: text);
        expect(read(printer.print(node), language: 'zh'), node, reason: text);
      }
    });

    test('an entity without plainWords prints the word bare', () {
      final bare = QueryPrinter(fixtureRegistry, fixtureDives, kMetricPrefs);
      expect(bare.print(word('with')), 'with');
    });

    test('other words stay bare', () {
      expect(printer.print(word('ressel')), 'ressel');
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
      'ressel,',
      'oct',
      'in',
      '2018 to',
      '14 october',
      'october 14',
      'october 14,',
      'october 14, 2018,',
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
      '14 october 2018',
      'october 14, 2018',
      '14 october 2018 to 20 october 2018',
    ]) {
      final node = read(text);
      expect(read(printer.print(node)), node, reason: text);
    }
  });
}
