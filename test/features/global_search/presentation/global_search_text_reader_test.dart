import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_completions.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/global_search/presentation/global_search_text_reader.dart';
import 'package:submersion/features/query/app_query_registry.dart';

void main() {
  final reader = GlobalSearchTextReader(
    QueryEditorContext(
      registry: appQueryRegistry,
      root: diveQueryEntity,
      prefs: kMetricPrefs,
      names: const MapNameResolver({
        QuerySubject.sites: {'Salt Pier': 's1'},
      }),
      labels: const MapQueryLabels(),
      now: () => DateTime(2026, 10, 30),
    ),
  );

  List<String> offers(String text) => [
    for (final c in reader.completionsAt(text, text.length)) c.text,
  ];

  group('check', () {
    test('accepts what any record type reads', () {
      expect(reader.check('reef'), isNull);
      expect(reader.check('depth > 30m'), isNull);
      expect(reader.check('expires < 2028'), isNull);
      expect(reader.check('site = "Salt Pier"'), isNull);
    });

    test('refuses what none does', () {
      expect(
        reader.check('"unterminated')?.code,
        QueryErrorCode.unterminatedQuote,
      );
    });
  });

  group('completions', () {
    test('reach a field only one record type has', () {
      expect(offers('expir'), contains('expiryDate'));
      expect(offers('deviceN'), ['deviceName']);
    });

    test('name the fields of several types for one word', () {
      expect(offers('de'), containsAll(['depth', 'description', 'default']));
    });

    test('are capped', () {
      expect(offers('s').length, lessThanOrEqualTo(kMaxQueryCompletions));
    });

    test('complete an enum value of the type that has it', () {
      expect(offers('type = ins'), contains('insurance'));
    });
  });

  group('poolCompletions', () {
    Completion c(String text) =>
        Completion(text, replaceStart: 0, replaceLength: 0);
    List<String> texts(List<Completion> list) => [for (final o in list) o.text];

    test('takes each list in turn', () {
      expect(
        texts(
          poolCompletions([
            [c('a1'), c('a2'), c('a3')],
            [c('b1')],
          ]),
        ),
        ['a1', 'b1', 'a2', 'a3'],
      );
    });

    test('shows an offer two lists share once', () {
      expect(
        texts(
          poolCompletions([
            [c('name')],
            [c('name'), c('notes')],
          ]),
        ),
        ['name', 'notes'],
      );
    });

    test('stops at the cap', () {
      final long = [for (var i = 0; i < 20; i++) c('x$i')];
      expect(poolCompletions([long]), hasLength(kMaxQueryCompletions));
    });
  });
}
