import 'dart:convert';
import 'dart:isolate';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shearwater_test_helpers.dart';

final _sqliteHeader = ascii.encode('SQLite format 3');

/// Builds [count] fixtures back to back and checks that each one is a
/// SQLite database.
///
/// Top level so that `Isolate.run` can send it without capturing test state.
int _buildFixtures(int count) {
  var built = 0;
  for (var i = 0; i < count; i++) {
    final bytes = createShearwaterTestDb(
      dives: const [ShearwaterTestDive(diveId: 'dive-1')],
    );
    final header = bytes.take(_sqliteHeader.length).toList();
    if (!const ListEquality<int>().equals(header, _sqliteHeader)) {
      throw StateError('fixture $i is not a SQLite database');
    }
    built++;
  }
  return built;
}

void main() {
  group('createShearwaterTestDb', () {
    // CI bundles test files into several processes that share one system
    // temp directory. A fixture named after the current millisecond then
    // collides with one built at the same moment elsewhere, and the second
    // fails with "database is locked". Parallel isolates reproduce that.
    test(
      'fixtures built at the same moment in parallel do not collide',
      () async {
        const isolates = 4;
        const perIsolate = 150;

        final results = await Future.wait([
          for (var i = 0; i < isolates; i++)
            Isolate.run(() => _buildFixtures(perIsolate)),
        ]);

        expect(results, everyElement(perIsolate));
      },
    );
  });
}
