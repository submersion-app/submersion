import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_data_retention.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// A visited dive's analysis, and the earlier dive its residual chain read,
/// are held by `retainDiveData` once nothing uses them, for
/// [diveDataRetention] rather than the whole session (#4254).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final start = DateTime.utc(2026, 6, 1, 9).millisecondsSinceEpoch;
    // Two dives an hour apart, so the second's analysis reads the first's.
    for (final (id, entry) in [
      ('first', start),
      ('second', start + const Duration(hours: 2).inMilliseconds),
    ]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: Value(id),
              diveDateTime: Value(entry),
              entryTime: Value(entry),
              exitTime: Value(
                entry + const Duration(minutes: 13).inMilliseconds,
              ),
              maxDepth: const Value(30.0),
              avgDepth: const Value(18.0),
              bottomTime: const Value(780),
              createdAt: Value(entry),
              updatedAt: Value(entry),
            ),
          );
      final depths = <double>[
        0,
        10,
        20,
        30,
        30,
        30,
        30,
        30,
        20,
        10,
        6,
        6,
        3,
        0,
      ];
      await ProfileSeriesRepository().insertSeries(
        diveId: id,
        samples: [
          for (var i = 0; i < depths.length; i++)
            ProfileSample(timestamp: i * 60, depth: depths[i]),
        ],
      );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('a left dive and its lookback dive stay warm after leaving', () async {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final sub = container.listen(profileAnalysisProvider('second'), (_, _) {});
    final analysis = await container.read(
      profileAnalysisProvider('second').future,
    );
    expect(analysis, isNotNull);
    expect(
      analysis!.o2Exposure.cnsStart,
      greaterThan(0),
      reason: 'the residual chain read the first dive',
    );

    sub.close();
    // Plain auto-disposal would drop every entry on the next scheduler pass.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    for (final id in ['first', 'second']) {
      expect(container.exists(profileAnalysisProvider(id)), isTrue);
      expect(container.exists(analysisDiveProvider(id)), isTrue);
    }
    // Freed once diveDataRetention passes with nothing using them: the timing
    // is covered with fake time in test/core/providers/retain_until_idle_test.
    expect(diveDataRetention, const Duration(minutes: 5));
  });
}
