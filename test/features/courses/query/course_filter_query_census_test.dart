import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Every CourseFilterState field is lowered: a field added to the state and
/// not named in course_filter_query.dart fails here (#2365).
void main() {
  test('every CourseFilterState field is lowered', () {
    final state = File(
      p.join(
        'lib',
        'features',
        'courses',
        'domain',
        'models',
        'course_filter_state.dart',
      ),
    ).readAsStringSync();
    final start = state.indexOf('class CourseFilterState');
    expect(start, isNonNegative);
    final openBrace = state.indexOf('{', start);
    expect(openBrace, isNonNegative);
    var depth = 0;
    var closeBrace = -1;
    for (var i = openBrace; i < state.length; i++) {
      final char = state[i];
      if (char == '{') depth++;
      if (char == '}') {
        depth--;
        if (depth == 0) {
          closeBrace = i;
          break;
        }
      }
    }
    expect(closeBrace, greaterThan(openBrace));
    final body = state.substring(start, closeBrace);
    final fields = RegExp(
      r'^  final [\w<>?, .]+ (\w+);',
      multiLine: true,
    ).allMatches(body).map((m) => m.group(1)!).toList();
    expect(fields, containsAll(['status', 'query']));
    final lowering = File(
      p.join('lib', 'features', 'courses', 'query', 'course_filter_query.dart'),
    ).readAsStringSync();
    for (final f in fields) {
      expect(lowering, contains(RegExp('\\b$f\\b')), reason: f);
    }
  });
}
