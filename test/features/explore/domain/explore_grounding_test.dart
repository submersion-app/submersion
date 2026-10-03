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
      );
      expect(g.clauses, hasLength(4));
    });

    test('a clause with no words of its own is dropped', () {
      final g = groundedIn(
        parse(clauses: [clause(''), clause(' - ')]),
        'deep dives',
      );
      expect(g.clauses, isEmpty);
    });

    test('words in a script without spaces are found', () {
      final g = groundedIn(
        parse(clauses: [clause('20メートル以上')]),
        '20メートル以上のダイブ',
      );
      expect(g.clauses, hasLength(1));
    });
  });

  group('time', () {
    test('a year the diver never typed is dropped', () {
      final g = groundedIn(parse(time: 'since 2022'), 'deep dives in Bonaire');
      expect(g.time, isNull);
    });

    test('a year the diver typed is kept', () {
      expect(
        groundedIn(parse(time: 'since 2022'), 'dives since 2022').time?.text,
        'since 2022',
      );
      expect(
        groundedIn(
          parse(time: '2023-05-01 to 2024-05-14'),
          'dives from May 2023 to May 2024',
        ).time,
        isNotNull,
      );
    });

    test('full-width digits count as the year', () {
      final g = groundedIn(parse(time: '2023'), '２０２３年のダイブ');
      expect(g.time?.text, '2023');
    });

    test('a period without a year is kept, whatever the language', () {
      // Nothing language-neutral can check "letztes Jahr" against
      // "last year"; the prompt's "none" keeps these honest.
      expect(
        groundedIn(parse(time: 'last year'), 'Tauchgänge letztes Jahr').time,
        isNotNull,
      );
      expect(
        groundedIn(parse(time: 'last 30 days'), 'dives this past month').time,
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
    final g = groundedIn(parsed, 'sites in Bonaire maybe');
    expect(g.subject, ParsedSubject.sites);
    expect(g.mentions.single.text, 'Bonaire');
    expect(g.unplaced, ['maybe']);
  });

  test('a grounded parse is returned as is', () {
    final parsed = parse(clauses: [clause('deep')], time: 'last year');
    expect(
      identical(groundedIn(parsed, 'deep dives last year'), parsed),
      isTrue,
    );
  });
}
