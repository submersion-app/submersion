import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

/// The Explore derived fields (#2195) typed, parsed, validated, compiled and
/// run against a seeded database.
///
/// d1: back-gas 200 to 140 bar over 50 min at 15 m average, so SAC is
///     60 / 50 / 2.5 = 0.48 bar/min; rising SAC (+30%); a stable 4 min stop.
/// d2: no tank; steady SAC (+2%); an unstable 3 min stop 1.4 m off.
/// d3: swept, but a gauge dive: every derived field empty.
/// d4: not swept yet: no row at all.
void main() {
  late AppDatabase db;
  final now = DateTime(2026, 9, 28).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: const Value('me'),
            name: const Value('Me'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    Future<void> dive(String id, {int? runtime, double? avgDepth}) => db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: const Value('me'),
            diveDateTime: now,
            runtime: Value(runtime),
            avgDepth: Value(avgDepth),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await dive('d1', runtime: 3000, avgDepth: 15);
    await dive('d2', runtime: 2400, avgDepth: 12);
    await dive('d3');
    await dive('d4');
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 't1',
            diveId: 'd1',
            startPressure: const Value(200),
            endPressure: const Value(140),
          ),
        );
    Future<void> metrics(
      String diveId, {
      String? trend,
      double? change,
      String? stop,
      double? excursion,
      int? stopSeconds,
      String? unsupported,
    }) => db
        .into(db.diveDerivedMetricsRows)
        .insert(
          DiveDerivedMetricsRowsCompanion.insert(
            diveId: diveId,
            engineVersion: 1,
            sourceUpdatedAt: now,
            computedAt: now,
            sacTrend: Value(trend),
            sacChangePct: Value(change),
            finalStopState: Value(stop),
            finalStopMaxExcursionM: Value(excursion),
            finalStopDurationS: Value(stopSeconds),
            unsupportedReason: Value(unsupported),
          ),
        );
    await metrics(
      'd1',
      trend: 'rising',
      change: 30,
      stop: 'stable',
      excursion: 0.3,
      stopSeconds: 240,
    );
    await metrics(
      'd2',
      trend: 'steady',
      change: 2,
      stop: 'unstable',
      excursion: 1.4,
      stopSeconds: 180,
    );
    await metrics('d3', unsupported: 'gaugeMode');
  });
  tearDown(tearDownTestDatabase);

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);
  const imperial = UnitPrefs(
    depth: DepthUnit.feet,
    temperature: TemperatureUnit.fahrenheit,
    pressure: PressureUnit.psi,
    weight: WeightUnit.pounds,
    volume: VolumeUnit.cubicFeet,
  );

  Future<Set<String>> ids(String text, {UnitPrefs prefs = kMetricPrefs}) async {
    final parser = QueryParser(
      appQueryRegistry,
      dives,
      ParseContext(
        prefs: prefs,
        now: DateTime(2026, 9, 28),
        names: const MapNameResolver({}),
      ),
    );
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, dives, appQueryRegistry), isEmpty);
    final q = compileQuery(node, dives, appQueryRegistry, rootAlias: 'd');
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE d.diver_id = ? AND ${q.where}',
          variables: [
            const Variable<String>('me'),
            ...q.params.map((p) => Variable(p)),
          ],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('the SAC trend and change', () async {
    expect(await ids('sacTrend = rising'), {'d1'});
    expect(await ids('sacChange > 20'), {'d1'});
    expect(await ids('sacChange < 5'), {'d2'});
  });

  test('a dive the sweep has not reached is empty, never a match', () async {
    expect(await ids('sacTrend:none'), {'d3', 'd4'});
    // NOT keeps an unknown: an unswept dive is not known to be rising.
    expect(await ids('NOT sacTrend = rising'), {'d2', 'd3', 'd4'});
  });

  test('the final stop state, excursion and length', () async {
    expect(await ids('finalStop = unstable'), {'d2'});
    expect(await ids('finalStop:none'), {'d3', 'd4'});
    expect(await ids('finalStopExcursion > 1'), {'d2'});
    expect(await ids('finalStopDuration >= 4'), {'d1'});
  });

  test('the excursion is a depth in the diver unit', () async {
    // 3 ft is 0.91 m: d2 strayed 1.4 m, d1 0.3 m.
    expect(await ids('finalStopExcursion > 3', prefs: imperial), {'d2'});
    expect(await ids('finalStopExcursion > 3ft'), {'d2'});
  });

  test('SAC uses the Insights formula and the diver pressure unit', () async {
    expect(await ids('sac > 0.47'), {'d1'});
    expect(await ids('sac < 0.49'), {'d1'});
    // 0.48 bar/min is 6.96 psi/min.
    expect(await ids('sac > 6', prefs: imperial), {'d1'});
    expect(await ids('sac > 7', prefs: imperial), isEmpty);
    expect(await ids('sac > 6psimin'), {'d1'});
    // No back-gas drop, no runtime or no average depth: no SAC.
    expect(await ids('sac:none'), {'d2', 'd3', 'd4'});
  });

  test('SAC agrees with the Insights SAC chart', () async {
    final points = await InsightsRepository().getSacPressurePerDive(
      diverId: 'me',
    );
    expect(points.map((p) => p.diveId).toSet(), await ids('sac:any'));
    expect(points.single.value, closeTo(0.48, 0.001));
  });

  test('a filter on a derived field follows its table', () {
    DiveFilterState on(String key, QueryValue value) => DiveFilterState(
      query: ConditionNode(FieldPath([key]), QueryOp.eq, value),
    );
    expect(
      diveFilterTablesTouched(on('sacTrend', const EnumValue('rising'))),
      contains('dive_derived_metrics'),
    );
    expect(
      diveFilterTablesTouched(on('sac', const NumberValue(1, null))),
      contains('dive_tanks'),
    );
  });
}
