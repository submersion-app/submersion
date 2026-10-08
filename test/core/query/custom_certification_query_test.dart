import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_completions.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/syntax/query_printer.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/certifications/query/certification_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// Issue #690: custom certification agencies and levels are valid values for
/// a certification query's `agency` and `level`.
void main() {
  const clubId = '2b1f7c3e-9d8a-4c55-8e21-0f6a1b2c3d4e';
  const names = MapNameResolver({
    QuerySubject.certificationAgencies: {'Club X': clubId},
  });
  final parser = QueryParser(
    appQueryRegistry,
    certificationQueryEntity,
    ParseContext(prefs: kMetricPrefs, now: DateTime(2026, 10, 5), names: names),
  );

  ConditionNode parsed(String text) {
    final r = parser.parse(text);
    expect(r, isA<ParseOk>(), reason: '$r');
    return (r as ParseOk).node! as ConditionNode;
  }

  test('a custom agency name parses to its id with the label kept', () {
    final node = parsed('agency = "Club X"');
    final value = node.value! as EnumValue;
    expect(value, const EnumValue(clubId));
    expect(value.label, 'Club X');
  });

  test('a built-in still parses by name', () {
    expect(parsed('agency = padi').value, const EnumValue('padi'));
  });

  test('an unknown name is still an error', () {
    expect(parser.parse('agency = "Nobody"'), isA<ParseFailure>());
  });

  test('a custom id validates for the agency field', () {
    final node = parsed('agency = "Club X"');
    expect(
      validateQuery(node, certificationQueryEntity, appQueryRegistry),
      isEmpty,
    );
  });

  test('the label round-trips through JSON and prints quoted', () {
    final node = parsed('agency = "Club X"');
    final back = queryNodeFromJson(queryNodeToJson(node)) as ConditionNode;
    expect((back.value! as EnumValue).label, 'Club X');
    final printed = QueryPrinter(
      appQueryRegistry,
      certificationQueryEntity,
      kMetricPrefs,
    ).print(node);
    expect(printed, 'agency = "Club X"');
  });

  test('completions offer custom agencies, quoted, after the built-ins', () {
    final context = QueryEditorContext(
      registry: appQueryRegistry,
      root: certificationQueryEntity,
      prefs: kMetricPrefs,
      names: names,
      labels: const MapQueryLabels(),
      now: () => DateTime(2026, 10, 5),
    );
    final offered = completionsAt(
      'agency = ',
      'agency = '.length,
      context,
    ).map((c) => c.text).toList();
    expect(offered, contains('padi'));
    expect(offered, contains('"Club X"'));
    final typed = completionsAt(
      'agency = Cl',
      'agency = Cl'.length,
      context,
    ).map((c) => c.text).toList();
    expect(typed, ['"Club X"']);
  });
}
