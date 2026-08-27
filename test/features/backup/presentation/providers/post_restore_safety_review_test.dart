import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/backup/presentation/providers/post_restore_safety_review.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  final ts = DateTime.utc(2026, 8, 8).millisecondsSinceEpoch;

  Future<void> insertDiver(String id, {bool isDefault = false}) async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value('Diver $id'),
            isDefault: Value(isDefault),
            createdAt: Value(ts),
            updatedAt: Value(ts),
          ),
        );
  }

  Future<void> insertDive(String id, String? diverId) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: Value(ts),
            createdAt: Value(ts),
            updatedAt: Value(ts),
          ),
        );
  }

  Future<void> insertSettings(
    String rowId,
    String diverId, {
    required bool safetyReviewEnabled,
  }) async {
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion(
            id: Value(rowId),
            diverId: Value(diverId),
            safetyReviewEnabled: Value(safetyReviewEnabled),
            createdAt: Value(ts),
            updatedAt: Value(ts),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // Foreign keys are enforced, so the owning diver must exist first.
    // Default diver: with no id in SharedPreferences, SettingsNotifier falls
    // back to getDefaultDiver() to decide whose settings to load.
    await insertDiver('diver-a', isDefault: true);
    await insertDive('d1', 'diver-a');
  });

  tearDown(() => tearDownTestDatabase());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Never initialized, so no directory is created.
        logFileServiceProvider.overrideWithValue(
          LogFileService(logDirectory: '/tmp/submersion-test'),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('runs a whole-library sweep and reports progress', () async {
    final seen = <(int, int)>[];

    final result = await makeContainer()
        .read(postRestoreSafetyReviewProvider)
        .run(onProgress: (done, total) => seen.add((done, total)));

    // The dive has no profile, so nothing is persisted -- but it is visited,
    // which is what proves the scratch container reached the restored data.
    expect(result.swept, 1);
    expect(result.cancelled, isFalse);
    expect(seen.first, (0, 1));
    expect(seen.last, (1, 1));
  });

  // The whole point of the throwaway container: it must grade against the
  // RESTORED database's settings, not the process-wide defaults. Turning the
  // master toggle off in the restored diver's row is the cheapest observable
  // proof -- the sweep can only no-op if it actually read that row, since the
  // default for safetyReviewEnabled is on.
  test('reads settings from the restored database, not the defaults', () async {
    await insertSettings('s1', 'diver-a', safetyReviewEnabled: false);

    final result = await makeContainer()
        .read(postRestoreSafetyReviewProvider)
        .run();

    expect(
      result.swept,
      0,
      reason: 'the restored diver has the safety review switched off',
    );
  });

  // Regression for PR #916 review: a single all-divers pass graded every
  // non-active diver's dives with the ACTIVE diver's settings and persisted the
  // result. Decompression settings are per-diver, so each diver must be swept
  // in a container pinned to their own row. Opposite master toggles are the
  // cheapest observable proof that the pinning happens.
  test(
    'grades each diver with their own settings, not the active one',
    () async {
      await insertSettings('s1', 'diver-a', safetyReviewEnabled: true);
      await insertDiver('diver-b');
      await insertDive('d2', 'diver-b');
      await insertSettings('s2', 'diver-b', safetyReviewEnabled: false);

      final result = await makeContainer()
          .read(postRestoreSafetyReviewProvider)
          .run();

      expect(
        result.swept,
        1,
        reason:
            "only diver-a's dive is swept; diver-b has the review switched off, "
            'which a single active-diver-scoped pass would have ignored',
      );
    },
  );

  test('sweeps dives that have no owning diver', () async {
    await insertDive('d-orphan', null);

    final result = await makeContainer()
        .read(postRestoreSafetyReviewProvider)
        .run();

    expect(result.swept, 2, reason: 'the owner-less dive gets its own pass');
  });

  test('honours cancellation', () async {
    final result = await makeContainer()
        .read(postRestoreSafetyReviewProvider)
        .run(isCancelled: () => true);

    expect(result.cancelled, isTrue);
    expect(result.swept, 0);
  });
}
