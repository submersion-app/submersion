import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../../helpers/test_database.dart';

/// A search word that is a whole number finds the dive with that number,
/// not only dives with the number in their text (#3653).
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    for (final (id, number, notes) in [
      ('numbered', 500, ''),
      ('text', 212, 'Anchored 500 m off the point'),
      ('contains', 1500, ''),
      ('other', 212, 'manta at the wall'),
      ('both', 501, 'cozumel'),
      ('unnumbered', null, ''),
    ]) {
      await repository.createDive(
        domain.Dive(
          id: id,
          diveNumber: number,
          dateTime: DateTime(2026, 1, 1),
          notes: notes,
        ),
      );
    }
  });
  tearDown(() async => tearDownTestDatabase());

  Future<Set<String>> list(QueryNode node) async {
    final filter = DiveFilterState(query: node);
    final rows = await repository.getDiveSummaries(filter: filter, limit: 50);
    expect(
      await repository.getDiveCount(filter: filter),
      rows.length,
      reason: 'the count follows the rows',
    );
    return {for (final d in rows) d.id};
  }

  test('a number finds its dive and the text, not dive 1500', () async {
    expect(await list(TextNode(const ['500'])), {'numbered', 'text'});
  });

  test('a number no dive has leaves the text matches', () async {
    await repository.createDive(
      domain.Dive(
        id: 'psi',
        diveNumber: 7,
        dateTime: DateTime(2026, 1, 1),
        notes: 'filled to 9000 psi',
      ),
    );
    expect(await list(TextNode(const ['9000'])), {'psi'});
  });

  test('the forms the jump row reads work here too', () async {
    for (final word in ['#500', '٥٠٠', '۵۰۰', '５００', '0500']) {
      expect(await list(TextNode([word])), contains('numbered'), reason: word);
    }
  });

  test('the words the search bar parses reach the number', () async {
    for (final typed in ['500', '#500', '"500"']) {
      final parsed = QueryParser(
        appQueryRegistry,
        diveQueryEntity,
        ParseContext(
          prefs: kMetricPrefs,
          now: DateTime(2026, 1, 1),
          names: const MapNameResolver({}),
        ),
      ).parse(typed);
      expect(
        await list((parsed as ParseOk).node!),
        contains('numbered'),
        reason: typed,
      );
    }
  });

  test('words that are not a whole number never match a number', () async {
    await repository.createDive(
      domain.Dive(id: 'five', diveNumber: 5, dateTime: DateTime(2026, 1, 1)),
    );
    expect(await list(TextNode(const ['5.5'])), isEmpty);
    expect(await list(TextNode(const ['-5'])), isEmpty);
    expect(await list(TextNode(const ['manta'])), {'other'});
  });

  test('a quoted phrase of two numbers stays a phrase', () async {
    expect(await list(TextNode(const ['500', '501'])), isEmpty);
  });

  test('beside another word, each word must match', () async {
    final both = AndNode([
      TextNode(const ['501']),
      TextNode(const ['cozumel']),
    ]);
    expect(await list(both), {'both'});
    final neither = AndNode([
      TextNode(const ['500']),
      TextNode(const ['cozumel']),
    ]);
    expect(await list(neither), isEmpty);
  });

  test('NOT drops the numbered dive with the text matches', () async {
    final found = await list(NotNode(TextNode(const ['500'])));
    expect(found, {'contains', 'other', 'both', 'unnumbered'});
  });

  test('the search every other surface uses agrees', () async {
    final rows = await repository.searchDiveSummaries('500');
    expect(rows.map((d) => d.id).toSet(), {'numbered', 'text'});
  });
}
