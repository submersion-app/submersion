import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Regression coverage for the legend's [ProfileLegendState.decoStopSource]
/// actually reaching [overlayComputerDecoData] through [profileAnalysisProvider].
///
/// Task 3 added the decoStopSource parameter to overlayComputerDecoData, but
/// nothing passed it through the provider layer until this wiring landed --
/// so the computer-vs-calculated switch was silently dead code even though
/// [profile_legend_deco_stop_test.dart] and [deco_stop_source_test.dart]
/// both passed. Those tests exercise the state object and the pure function
/// in isolation; this test exercises the wire between them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// A shallow, no-deco-obligation profile carrying a computer-reported
  /// ceiling of 4.5 m at two samples. 4.5 m is not a multiple of the 3 m
  /// stop spacing the calculated curve quantizes to, and the dive is far too
  /// short/shallow to owe any calculated decompression -- so 4.5 can only
  /// appear in the result's decoStopCurve if the raw DC value passed through
  /// untouched, which only happens when decoStopSource resolves to computer.
  Future<void> seedDiveWithComputerCeiling(String diveId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(now),
            maxDepth: const Value(20.0),
            avgDepth: const Value(15.0),
            bottomTime: const Value(90),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    const depths = [0.0, 20.0, 20.0, 0.0];
    const ceilings = [null, 4.5, 4.5, null];
    await db.batch((batch) {
      for (var i = 0; i < depths.length; i++) {
        batch.insert(
          db.diveProfiles,
          DiveProfilesCompanion(
            id: Value('$diveId-p$i'),
            diveId: Value(diveId),
            isPrimary: const Value(true),
            timestamp: Value(i * 30),
            depth: Value(depths[i]),
            ceiling: Value(ceilings[i]),
          ),
        );
      }
    });
  }

  test(
    'legend decoStopSource=computer reaches overlayComputerDecoData through '
    'profileAnalysisProvider, independently of the default calculated source',
    () async {
      const diveId = 'wiring-dive';
      await seedDiveWithComputerCeiling(diveId);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      // Default legend state (calculated): the DC ceiling must not leak into
      // decoStopCurve, and the published source info must say so.
      final calculated = await container.read(
        profileAnalysisProvider(diveId).future,
      );
      expect(calculated, isNotNull);
      expect(
        calculated!.decoStopCurve,
        isNot(contains(4.5)),
        reason:
            'calculated (default) decoStopSource must not carry the raw DC '
            'ceiling through -- if it does, decoStopSource is not wired',
      );
      expect(
        container.read(metricSourceInfoProvider)?.decoStopActual,
        MetricDataSource.calculated,
      );

      // Flip the legend's deco stop source to computer and re-read. The
      // FutureProvider watches profileLegendProvider.select((s) =>
      // s.decoStopSource), so this must trigger a recompute.
      container
          .read(profileLegendProvider.notifier)
          .setDecoStopSource(MetricDataSource.computer);

      final overlaid = await container.read(
        profileAnalysisProvider(diveId).future,
      );
      expect(overlaid, isNotNull);
      expect(
        overlaid!.decoStopCurve,
        [0.0, 4.5, 4.5, 0.0],
        reason:
            'legend decoStopSource=computer must reach overlayComputerDecoData '
            'and surface the raw DC ceiling values verbatim (unquantized)',
      );
      expect(
        container.read(metricSourceInfoProvider)?.decoStopActual,
        MetricDataSource.computer,
      );
    },
  );
}
