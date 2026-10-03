import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/domain/explore_grounding.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// The on-device model copies example filters and periods into sentences
/// that never asked for them (#2838). Whatever it claims to have read must
/// be in the sentence the diver typed.
void main() {
  QueryClause clause(String text) =>
      QueryClause(field: 'depth', op: ClauseOp.gt, value: 20, text: text);

  ParsedQuery parse({
    List<QueryClause> clauses = const [],
    String? time,
    List<QueryMention> mentions = const [],
    List<String> unplaced = const [],
  }) => ParsedQuery(
    subject: ParsedSubject.dives,
    clauses: clauses,
    mentions: mentions,
    time: time == null ? null : QueryTime(time),
    unplaced: unplaced,
  );

  group('clauses', () {
    test('a clause whose words are not in the sentence is dropped', () {
      final g = groundedIn(
        parse(clauses: [clause('deep'), clause('cold-water')]),
        'deep dives in Bonaire',
        locale: 'en',
      );
      expect(g.clauses.map((c) => c.text), ['deep']);
    });

    test('case, accents, punctuation and spacing do not matter', () {
      final g = groundedIn(
        parse(
          clauses: [
            clause('Favourite'),
            clause('epave'),
            clause('cold-water'),
            clause('below  20m'),
          ],
        ),
        'favourite épave dives in cold water below 20m',
        locale: 'en',
      );
      expect(g.clauses, hasLength(4));
    });

    test('a clause with no words of its own is dropped', () {
      final g = groundedIn(
        parse(clauses: [clause(''), clause(' - ')]),
        'deep dives',
        locale: 'en',
      );
      expect(g.clauses, isEmpty);
    });
  });

  group('a year in a clause value', () {
    // Example 4's clause, which the model copied into a German sentence.
    const lastDived = QueryClause(
      field: 'lastDived',
      op: ClauseOp.lt,
      value: '2022',
      text: 'not dived since 2022',
    );

    test('is dropped in any language when the sentence lacks it', () {
      final g = groundedIn(
        parse(clauses: [lastDived]),
        'Tauchplätze in Bonaire',
        locale: 'de',
      );
      expect(g.clauses, isEmpty);
    });

    test('is kept when the sentence names it', () {
      final g = groundedIn(
        parse(clauses: [lastDived]),
        'Tauchplätze, die ich seit 2022 nicht betaucht habe',
        locale: 'de',
      );
      expect(g.clauses, hasLength(1));
    });
  });

  group('other languages', () {
    // The model often quotes a non-English sentence's clause in English
    // ("deeper than 30" for "tiefer als 30m"), so only English is checked.
    test('a clause quoted in English from a German sentence is kept', () {
      final g = groundedIn(
        parse(clauses: [clause('deeper than 30')]),
        'Tauchgänge tiefer als 30m in Bonaire',
        locale: 'de',
      );
      expect(g.clauses, hasLength(1));
    });

    test('a regional English locale is still checked', () {
      final g = groundedIn(
        parse(clauses: [clause('cold-water')]),
        'deep dives in Bonaire',
        locale: 'en_GB',
      );
      expect(g.clauses, isEmpty);
    });

    test('a year the diver never typed is dropped in any language', () {
      final g = groundedIn(
        parse(time: 'since 2022'),
        'Tauchgänge in Bonaire',
        locale: 'de',
      );
      expect(g.time, isNull);
    });
  });

  group('time', () {
    test('a year the diver never typed is dropped', () {
      final g = groundedIn(
        parse(time: 'since 2022'),
        'deep dives in Bonaire',
        locale: 'en',
      );
      expect(g.time, isNull);
    });

    test('a year the diver typed is kept', () {
      expect(
        groundedIn(
          parse(time: 'since 2022'),
          'dives since 2022',
          locale: 'en',
        ).time?.text,
        'since 2022',
      );
      expect(
        groundedIn(
          parse(time: '2023-05-01 to 2024-05-14'),
          'dives from May 2023 to May 2024',
          locale: 'en',
        ).time,
        isNotNull,
      );
    });

    // Periods the model gave English sentences that never named them; each
    // names a unit the sentence lacks.
    test('in English, a period whose unit the sentence never names is '
        'dropped', () {
      for (final (time, sentence) in [
        ('this year', 'dives with Sarah'),
        ('this year', 'recent dives'),
        ('this month', 'dives in March'),
        ('last 30 days', 'dives from last summer'),
        // A weekday names no unit, though it ends in "day".
        ('this month', 'dives on Sunday'),
        ('last 30 days', 'holiday dives'),
      ]) {
        expect(
          groundedIn(parse(time: time), sentence, locale: 'en').time,
          isNull,
          reason: '$time / $sentence',
        );
      }
    });

    test('in English, a period whose unit the sentence names is kept', () {
      for (final (time, sentence) in [
        ('this week', 'dives this week'),
        ('last 2 weeks', 'dives in the past two weeks'),
        ('last 2 weeks', 'dives over the last fortnight'),
        ('last 30 days', 'dives this past month'),
        ('last 7 days', 'dives since yesterday'),
        ('this week', 'dives this weekend'),
        ('last 7 days', 'dives today'),
        ('last year', 'deep dives last year'),
        ('2019 to 2021', 'my dives from 2019 to 2021'),
      ]) {
        expect(
          groundedIn(parse(time: time), sentence, locale: 'en').time,
          isNotNull,
          reason: '$time / $sentence',
        );
      }
    });

    test('in English, a month the sentence never names is dropped', () {
      // What the model answered for "dives in March", and the same in the
      // abbreviated form the date grammar also reads as a month.
      for (final time in ['May 2023', 'Sep 2023']) {
        expect(
          groundedIn(
            parse(time: time),
            'dives in March 2023',
            locale: 'en',
          ).time,
          isNull,
          reason: time,
        );
      }
    });

    test('in English, a month named in full or abbreviated is kept', () {
      for (final (time, sentence) in [
        ('May 2023', 'dives in May 2023'),
        ('March 2023', 'dives in Mar 2023'),
        ('September 2023', 'dives in Sept 2023'),
        ('Sep 2023', 'dives in September 2023'),
        ('May 2023', 'dives in 2023-05'),
        ('2023-05-01 to 2023-05-14', 'dives from 1 to 14 May 2023'),
      ]) {
        expect(
          groundedIn(parse(time: time), sentence, locale: 'en').time,
          isNotNull,
          reason: '$time / $sentence',
        );
      }
      // Other languages name their months in their own words.
      expect(
        groundedIn(
          parse(time: 'March 2023'),
          'Tauchgänge im März 2023',
          locale: 'de',
        ).time,
        isNotNull,
      );
    });

    test('full-width digits count as the year', () {
      final g = groundedIn(parse(time: '2023'), '２０２３年のダイブ', locale: 'ja');
      expect(g.time?.text, '2023');
    });

    test('a period without a year is kept, whatever the language', () {
      // Nothing language-neutral can check "letztes Jahr" against
      // "last year"; the prompt's "none" keeps these honest.
      expect(
        groundedIn(
          parse(time: 'last year'),
          'Tauchgänge letztes Jahr',
          locale: 'de',
        ).time,
        isNotNull,
      );
      expect(
        groundedIn(
          parse(time: 'last 30 days'),
          'dives this past month',
          locale: 'en',
        ).time,
        isNotNull,
      );
    });
  });

  test('subject, mentions and unplaced words pass through untouched', () {
    const parsed = ParsedQuery(
      subject: ParsedSubject.sites,
      mentions: [QueryMention(kind: MentionKind.place, text: 'Bonaire')],
      unplaced: ['maybe'],
    );
    final g = groundedIn(parsed, 'sites in Bonaire maybe', locale: 'en');
    expect(g.subject, ParsedSubject.sites);
    expect(g.mentions.single.text, 'Bonaire');
    expect(g.unplaced, ['maybe']);
  });

  test('a grounded parse is returned as is', () {
    final parsed = parse(clauses: [clause('deep')], time: 'last year');
    expect(
      identical(
        groundedIn(parsed, 'deep dives last year', locale: 'en'),
        parsed,
      ),
      isTrue,
    );
  });
}
