import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/explore/data/explore_repository.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/query/data/name_index_loader.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../helpers/test_database.dart';
import '../../dive_log/query/dive_query_fixture.dart';

QueryClause _c(String field, ClauseOp op, Object value, {ClauseUnit? unit}) =>
    QueryClause(field: field, op: op, value: value, unit: unit, text: field);
QueryMention _m(MentionKind kind, String text, {String? identity}) =>
    QueryMention(kind: kind, text: text, identity: identity);

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> ids(ParsedQuery q) async {
    // Explore's index: the shared names, then the legacy buddy texts.
    final shared = await NameIndexLoader(
      db,
    ).load(diverId: 'me', l10n: l10nForLocaleTag('en'));
    final names = shared.followedBy(
      await ExploreRepository(db: db).legacyBuddyNames(diverId: 'me'),
    );
    final compiled = ExploreCompiler.compile(
      q,
      ExploreCompilerContext(
        units: kMetricPrefs,
        names: names,
        now: DateTime(2026, 6, 1),
      ),
    );
    expect(compiled.unresolved, isEmpty);
    expect(compiled.unplaced, isEmpty);
    return DiveRepository().getDiveIdsMatching(
      _filterOf(compiled),
      diverId: 'me',
    );
  }

  ParsedQuery q({
    List<QueryClause> clauses = const [],
    List<QueryMention> mentions = const [],
    String? time,
  }) => ParsedQuery(
    subject: ParsedSubject.dives,
    clauses: clauses,
    mentions: mentions,
    time: time == null ? null : QueryTime(time),
    unplaced: const [],
  );

  final cases = <String, (ParsedQuery, Set<String>)>{
    'deeper than 20 m': (
      q(clauses: [_c('depth', ClauseOp.gt, 20, unit: ClauseUnit.m)]),
      {'d2', 'd3', 'd5'},
    ),
    'depth between 20 and 30': (
      q(
        clauses: [
          _c('depth', ClauseOp.between, [20, 30]),
        ],
      ),
      {'d2', 'd3'},
    ),
    'water colder than 20 c': (
      q(clauses: [_c('waterTemp', ClauseOp.lt, 20, unit: ClauseUnit.c)]),
      {'d3'},
    ),
    'bottom time at least 45': (
      q(clauses: [_c('bottomTime', ClauseOp.gte, 45)]),
      {'d1', 'd2'},
    ),
    'no buddy': (q(clauses: [_c('noBuddy', ClauseOp.eq, true)]), {'d3', 'd4'}),
    'place Bonaire': (
      q(mentions: [_m(MentionKind.place, 'Bonaire')]),
      {'d1', 'd2', 'd3'},
    ),
    'site Cenote or place Bonaire': (
      q(
        mentions: [
          _m(MentionKind.site, 'Cenote'),
          _m(MentionKind.place, 'Bonaire'),
        ],
      ),
      {'d1', 'd2', 'd3', 'd5'},
    ),
    'buddy Ana': (q(mentions: [_m(MentionKind.buddy, 'Ana')]), {'d1', 'd5'}),
    'buddies Ana and Cid': (
      q(mentions: [_m(MentionKind.buddy, 'Ana'), _m(MentionKind.buddy, 'Cid')]),
      {'d5'},
    ),
    'pinned buddy': (
      q(mentions: [_m(MentionKind.buddy, 'Ana', identity: 'buddyId:b1:::')]),
      {'d1', 'd5'},
    ),
    'legacy buddy Bob': (q(mentions: [_m(MentionKind.buddy, 'Bob')]), {'d2'}),
    'gear g_wet': (q(mentions: [_m(MentionKind.gear, 'g_wet')]), {'d1', 'd5'}),
    'in 2025': (q(time: '2025'), {'d1', 'd2', 'd3', 'd5'}),
    'deep in Bonaire in 2025': (
      q(
        clauses: [_c('depth', ClauseOp.gt, 20, unit: ClauseUnit.m)],
        mentions: [_m(MentionKind.place, 'Bonaire')],
        time: '2025',
      ),
      {'d2', 'd3'},
    ),
  };

  test('a merged place ORs its columns', () async {
    await db.customStatement(
      "UPDATE dive_sites SET region = 'Bonaire', "
      "country = 'Caribbean Netherlands' WHERE id = 's1'",
    );
    await db.customStatement(
      "UPDATE dive_sites SET island = 'Bonaire', "
      "country = 'Caribbean Netherlands' WHERE id = 's2'",
    );
    expect(await ids(q(mentions: [_m(MentionKind.place, 'Bonaire')])), {
      'd1',
      'd2',
      'd3',
    });
  });

  test('a place finds sites whose column has stray whitespace', () async {
    // Imported sites can carry a padded island or city; the place label is
    // trimmed, so the condition must compare trimmed text too.
    await db.customStatement(
      "UPDATE dive_sites SET island = 'Bonaire ', "
      "country = 'Caribbean Netherlands' WHERE id = 's1'",
    );
    await db.customStatement(
      "UPDATE dive_sites SET island = 'Bonaire', "
      "country = 'Caribbean Netherlands' WHERE id = 's2'",
    );
    expect(await ids(q(mentions: [_m(MentionKind.place, 'Bonaire')])), {
      'd1',
      'd2',
      'd3',
    });
  });

  test('a linked buddy wins over a legacy text with the same name', () async {
    // d4 has no linked buddy; its legacy text names Ana, who is linked on
    // d1 and d5. The linked buddy is tried first, so d4 is not found.
    await db.customStatement("UPDATE dives SET buddy = 'Ana' WHERE id = 'd4'");
    expect(await ids(q(mentions: [_m(MentionKind.buddy, 'Ana')])), {
      'd1',
      'd5',
    });
  });

  test('two centers OR together', () async {
    await db.customStatement(
      "INSERT INTO dive_centers (id, name, created_at, updated_at) VALUES "
      "('c1', 'Buddy Dive', 0, 0), ('c2', 'Dive Friends', 0, 0)",
    );
    await db.customStatement(
      "UPDATE dives SET dive_center_id = 'c1' WHERE id = 'd1'",
    );
    await db.customStatement(
      "UPDATE dives SET dive_center_id = 'c2' WHERE id = 'd3'",
    );
    expect(
      await ids(
        q(
          mentions: [
            _m(MentionKind.center, 'Buddy Dive'),
            _m(MentionKind.center, 'Dive Friends'),
          ],
        ),
      ),
      {'d1', 'd3'},
    );
  });

  for (final e in cases.entries) {
    test('finds the same dives: ${e.key}', () async {
      expect(await ids(e.value.$1), e.value.$2);
    });
  }
}

DiveFilterState _filterOf(ExploreCompilation c) =>
    DiveFilterState(query: c.query);
