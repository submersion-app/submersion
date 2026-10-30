import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The published sample logbook's photos (issue #3708): each is recorded
/// with where it came from and under which licence, so the package can be
/// audited and rebuilt.
void main() {
  final file = File(p.join('tool', 'demo_data', 'photos', 'credits.json'));

  test('every published photo is credited, openly licensed and sourced', () {
    final credits = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

    expect(credits, isNotEmpty);
    for (final c in credits) {
      final name = c['fileName'] as String;
      expect(
        c['credit'],
        matches(RegExp(r'(CC0|Public domain)$')),
        reason: name,
      );
      expect(
        c['sourceUrl'],
        startsWith('https://commons.wikimedia.org/wiki/File:'),
        reason: name,
      );
      expect(c['subject'], isA<String>(), reason: name);
    }
    expect(
      credits.map((c) => c['fileName']).toSet(),
      hasLength(credits.length),
    );
  });
}
