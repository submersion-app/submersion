import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Every SiteFilterState field is lowered: a field added to the state and
/// not named in site_filter_query.dart fails here (#2365).
void main() {
  test('every SiteFilterState field is lowered', () {
    final state = File(
      p.join(
        'lib',
        'features',
        'dive_sites',
        'presentation',
        'providers',
        'site_providers.dart',
      ),
    ).readAsStringSync();
    final start = state.indexOf('class SiteFilterState');
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
        'dive_sites',
        'query',
        'site_filter_query.dart',
      ),
    ).readAsStringSync();
    for (final f in fields) {
      expect(lowering, contains(RegExp('\\b$f\\b')), reason: f);
    }
  });
}
