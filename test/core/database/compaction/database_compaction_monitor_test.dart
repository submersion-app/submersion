import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/compaction/database_compaction_monitor.dart';
import 'package:submersion/core/database/compaction/database_compaction_prefs.dart';
import 'package:submersion/core/database/compaction/database_space.dart';

const _mb = 1024 * 1024;

DatabaseSpace _space(int fileMb, int freeMb) => DatabaseSpace(
  pageSize: 4096,
  pageCount: fileMb * _mb ~/ 4096,
  freePages: freeMb * _mb ~/ 4096,
);

void main() {
  late DatabaseCompactionPrefs prefs;
  var reads = 0;

  setUp(() async {
    reads = 0;
    SharedPreferences.setMockInitialValues({});
    prefs = DatabaseCompactionPrefs(await SharedPreferences.getInstance());
  });

  DatabaseCompactionMonitor monitor(DatabaseSpace space) =>
      DatabaseCompactionMonitor(
        readSpace: () async {
          reads++;
          return space;
        },
        prefs: prefs,
      );

  test('asks for a compaction when enough space is free', () async {
    expect(await monitor(_space(200, 60)).check(), isTrue);
    expect(prefs.isRequested, isTrue);
  });

  test('does not ask below the threshold', () async {
    expect(await monitor(_space(400, 60)).check(), isFalse);
    expect(prefs.isRequested, isFalse);
  });

  test('does not ask during a backoff, nor measure', () async {
    await prefs.recordFailure();
    expect(await monitor(_space(200, 60)).check(), isFalse);
    expect(prefs.isRequested, isFalse);
    expect(reads, 0);
  });

  test('a Cancel while measuring wins', () async {
    final racing = DatabaseCompactionMonitor(
      readSpace: () async {
        // The diver taps Cancel on the Storage page mid-measurement.
        await prefs.decline();
        return _space(200, 60);
      },
      prefs: prefs,
    );
    expect(await racing.check(), isFalse);
    expect(prefs.isRequested, isFalse);
  });

  test('does not measure again once asked', () async {
    await prefs.request();
    expect(await monitor(_space(200, 60)).check(), isFalse);
    expect(reads, 0);
  });
}
