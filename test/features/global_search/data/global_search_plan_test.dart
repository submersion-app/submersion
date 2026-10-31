import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/global_search/data/global_search_plan.dart';
import 'package:submersion/features/global_search/data/global_search_sources.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';

void main() {
  final context = ParseContext(
    prefs: kMetricPrefs,
    now: DateTime(2026, 10, 30),
    names: const MapNameResolver(<QuerySubject, Map<String, String>>{}),
  );

  GlobalSearchPlan plan(String text) =>
      planGlobalSearch(text, context: context, diverId: 'me');

  Set<GlobalSearchKind> kinds(GlobalSearchPlan p) => {
    for (final run in p.runs) run.source.kind,
  };

  test('every source has a run for a plain word', () {
    final result = plan('bonaire');
    expect(kinds(result), GlobalSearchKind.values.toSet());
    expect(result.refusal, isNull);
  });

  test('a field query runs only where the field exists', () {
    final result = plan('maxDepth > 30');
    expect(
      kinds(result),
      containsAll({GlobalSearchKind.dives, GlobalSearchKind.sites}),
    );
    expect(kinds(result), isNot(contains(GlobalSearchKind.buddies)));
    expect(result.refusal, isNull);
  });

  test('a record with no list answers a field query too', () {
    expect(
      kinds(plan('depth > 30m')),
      containsAll({
        GlobalSearchKind.dives,
        GlobalSearchKind.divePlans,
        GlobalSearchKind.underwaterRoutes,
      }),
    );
    expect(
      kinds(plan('expires < 2028')),
      containsAll({
        GlobalSearchKind.certifications,
        GlobalSearchKind.documents,
      }),
    );
    expect(
      kinds(plan('itemCount > 3')),
      contains(GlobalSearchKind.equipmentSets),
    );
    expect(kinds(plan('file ~ reef')), contains(GlobalSearchKind.gpsTracks));
  });

  test('a typo takes its suggestion from a type that knows the field', () {
    final refusal = plan('expirs < 2028').refusal;
    expect(refusal, isNotNull);
    expect(refusal!.suggestions, contains('expiryDate'));
  });

  group('globalSearchRefusal', () {
    test('agrees with the plan, without compiling anything', () {
      for (final text in ['bonaire', 'depth > 30m', 'expires < 2028', '500']) {
        expect(globalSearchRefusal(text, context: context), isNull);
      }
      expect(
        globalSearchRefusal('"unterminated', context: context)?.code,
        QueryErrorCode.unterminatedQuote,
      );
      expect(globalSearchRefusal('   ', context: context), isNull);
    });
  });

  test('blank text plans nothing and refuses nothing', () {
    final result = plan('   ');
    expect(result.runs, isEmpty);
    expect(result.refusal, isNull);
  });

  test('text no source can read is refused with the first error', () {
    final result = plan('"unterminated');
    expect(result.runs, isEmpty);
    expect(result.refusal?.code, QueryErrorCode.unterminatedQuote);
  });

  test('a bare number widens dives alone to the dive number', () {
    final result = plan('500');
    final dives = result.runs.firstWhere(
      (r) => r.source.kind == GlobalSearchKind.dives,
    );
    final sites = result.runs.firstWhere(
      (r) => r.source.kind == GlobalSearchKind.sites,
    );
    expect(dives.query, isA<OrNode>());
    expect(sites.query, isA<TextNode>());
  });

  test('a word that is not a number leaves dives alone', () {
    final dives = plan(
      'reef',
    ).runs.firstWhere((r) => r.source.kind == GlobalSearchKind.dives);
    expect(dives.query, isA<TextNode>());
  });

  test('a source that refuses is left out while another reads the text', () {
    final only = [
      kGlobalSearchSources.firstWhere(
        (s) => s.kind == GlobalSearchKind.buddies,
      ),
    ];
    final result = planGlobalSearch(
      'maxDepth > 30',
      context: context,
      sources: only,
    );
    expect(result.runs, isEmpty);
    expect(result.refusal, isNotNull);
  });
}
