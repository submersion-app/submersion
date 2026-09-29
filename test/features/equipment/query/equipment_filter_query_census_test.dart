import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Every EquipmentFilterState field is lowered: a field added to the state
/// and not named in equipment_filter_query.dart fails here (#2365).
void main() {
  test('every EquipmentFilterState field is lowered', () {
    final state = File(
      p.join(
        'lib',
        'features',
        'equipment',
        'domain',
        'models',
        'equipment_filter_state.dart',
      ),
    ).readAsStringSync();
    final start = state.indexOf('class EquipmentFilterState');
    expect(start, isNonNegative);
    final body = state.substring(start, state.indexOf('\n}\n', start));
    final fields = RegExp(
      r'^  final [\w<>?, .]+ (\w+);',
      multiLine: true,
    ).allMatches(body).map((m) => m.group(1)!).toList();
    expect(fields, contains('query'));
    final lowering = File(
      p.join(
        'lib',
        'features',
        'equipment',
        'query',
        'equipment_filter_query.dart',
      ),
    ).readAsStringSync();
    for (final f in fields) {
      expect(lowering, contains(RegExp('\\b$f\\b')), reason: f);
    }
  });
}
