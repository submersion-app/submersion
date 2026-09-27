import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Every DiveFilterState field must be lowered by toQuery(), or the axis
/// silently filters nothing. Source-level, like dive_edit_save_field_census.
void main() {
  test('toQuery() names every DiveFilterState field', () {
    final state = File(
      p.join(
        'lib',
        'features',
        'dive_log',
        'domain',
        'models',
        'dive_filter_state.dart',
      ),
    ).readAsStringSync();
    final lowering = File(
      p.join('lib', 'features', 'dive_log', 'query', 'dive_filter_query.dart'),
    ).readAsStringSync();
    final fields = RegExp(
      r'^  final [\w<>?, ]+ (\w+);',
      multiLine: true,
    ).allMatches(state).map((m) => m[1]!).toSet();
    expect(fields, contains('query'));
    final missing = fields
        .where((f) => !RegExp('\\b$f\\b').hasMatch(lowering))
        .toList();
    expect(missing, isEmpty, reason: 'not lowered by toQuery(): $missing');
  });
}
