@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/database/scratch_database.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/data/demo_state_store.dart';
import 'package:submersion/features/demo_mode/domain/demo_state.dart';

import '../web_test_assets.dart';

/// A browser keeps demo mode's state and preferences snapshot in local
/// storage and the sample logbook as one of drift's databases (issue #4121).
void main() {
  const paths = DemoPaths('/opfs/support');
  const store = DemoStateStore(paths);

  final previousAssetBase = BackgroundDatabaseConnection.assetBase;
  setUpAll(() {
    BackgroundDatabaseConnection.assetBase = kWebTestAssetBase;
  });
  tearDownAll(() {
    BackgroundDatabaseConnection.assetBase = previousAssetBase;
  });
  // Local storage outlives the test; nothing of demo mode is left in it.
  tearDown(store.deleteAll);

  final state = DemoState(
    phase: DemoPhase.active,
    fromFirstRun: true,
    enteredAt: DateTime.utc(2026, 11, 2, 9),
  );

  test('the state survives in local storage and is cleared', () async {
    expect(store.hasAnything, isFalse);
    expect(await store.read(), isNull);

    await store.write(state);

    expect(store.hasAnything, isTrue);
    expect(await store.read(), state);
    await store.deleteAll();
    expect(store.hasAnything, isFalse);
  });

  test('the preferences snapshot is kept and put back', () async {
    SharedPreferences.setMockInitialValues({'current_diver_id': 'real'});
    final prefs = await SharedPreferences.getInstance();
    expect(await store.restorePrefs(prefs), isFalse);

    await store.capturePrefs(prefs);
    await prefs.setString('current_diver_id', 'sample-diver');

    expect(await store.restorePrefs(prefs), isTrue);
    expect(prefs.getString('current_diver_id'), 'real');
  });

  test(
    'the sample logbook is a browser database, and goes with the rest',
    () async {
      expect(await store.hasDatabase(), isFalse);
      final image = await withScratchDatabase((db) async {
        db.execute('CREATE TABLE dives (id TEXT)');
        db.execute('PRAGMA user_version = 327');
      });
      await BackgroundDatabaseConnection.installImage(
        paths.databaseFile,
        image,
      );

      expect(await store.hasDatabase(), isTrue);
      await store.deleteAll();
      expect(await store.hasDatabase(), isFalse);
    },
  );
}
