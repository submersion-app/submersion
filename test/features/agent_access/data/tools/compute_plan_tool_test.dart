import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/tools/compute_plan_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../../planner/series/series_fixtures.dart';

/// `compute_plan`: the planner's schedule for a dive or series an agent
/// describes, with the diver's planner settings (issue #4203).
void main() {
  late AppDatabase db;
  const active = 'active-diver';
  const other = 'other-diver';
  const t = 1700000000000;
  final now = DateTime.utc(2026, 11, 14, 12);
  final followed = <String, SeriesFollow>{};

  setUp(() async {
    db = await setUpTestDatabase();
    followed.clear();
    for (final (id, isDefault) in [(active, true), (other, false)]) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: 'Name of $id',
              createdAt: t,
              updatedAt: t,
              isDefault: Value(isDefault),
            ),
          );
    }
    await DiverSettingsRepository().createSettingsForDiver(
      other,
      settings: const AppSettings(gfLow: 40, gfHigh: 85),
    );
  });
  tearDown(tearDownTestDatabase);

  ComputePlanTool tool() {
    final divers = DiverRepository();
    final settings = DiverSettingsRepository();
    return ComputePlanTool(
      loader: DiverContextLoader(
        db: () => db,
        divers: divers,
        settings: settings,
        localeTag: 'en',
        activeDiverId: () async => active,
      ),
      settings: settings,
      followOf: (id) async => followed[id],
      caveat: () => 'Check every number yourself.',
      now: () => now,
    );
  }

  AgentToolContext ctx() => AgentToolContext(db: db, clientName: 'test');

  final dive = {
    'tanks': [
      {'volume_l': 24, 'start_pressure_bar': 200},
      {
        'volume_l': 7,
        'start_pressure_bar': 200,
        'o2_fraction': 0.5,
        'role': 'deco',
      },
    ],
    'bottom': {'depth_m': 40, 'time_s': 1500},
  };

  test('is named compute_plan and describes its arguments', () {
    final t = tool();
    expect(t.name, 'compute_plan');
    expect(t.description, contains('issues'));
    final properties = t.inputSchema['properties']! as Map;
    expect(
      properties.keys,
      containsAll(['diver_id', 'dives', 'follow_dive_id']),
    );
  });

  test('computes a dive with the active diver\'s settings', () async {
    final out = await tool().call({
      'dives': [dive],
    }, ctx());
    expect(out['diver_id'], active);
    expect(out['caveat'], 'Check every number yourself.');
    expect(out['followed_dive_id'], isNull);
    final result = (out['dives']! as List).single as Map;
    expect(result['index'], 0);
    expect(result['stops'], isNotEmpty);
    final gf = (result['effective_settings']! as Map)['gf_low'];
    expect(gf, {'value': const AppSettings().gfLow, 'source': 'settings'});
  });

  test('computes with the named diver\'s settings', () async {
    final out = await tool().call({
      'diver_id': other,
      'dives': [dive],
    }, ctx());
    expect(out['diver_id'], other);
    final result = (out['dives']! as List).single as Map;
    final settings = result['effective_settings']! as Map;
    expect(settings['gf_low'], {'value': 40, 'source': 'settings'});
    expect(settings['gf_high'], {'value': 85, 'source': 'settings'});
  });

  test('a later dive of a series carries in from the one before', () async {
    final out = await tool().call({
      'dives': [
        dive,
        {
          'surface_interval_s': 5400,
          'bottom': {'depth_m': 18, 'time_s': 2700},
        },
      ],
    }, ctx());
    final results = (out['dives']! as List).cast<Map>();
    expect(results.map((r) => r['index']), [0, 1]);
    expect((results[1]['carried_in']! as Map)['tissues_loaded'], isTrue);
    final inputs = results[1]['resolved_inputs']! as Map;
    expect(inputs['carries_from_tank'], [0, 1]);
  });

  test('following a logged dive starts with what it left', () async {
    followed['logged'] = SeriesFollow(
      loggedDives: [
        seriesLoggedDive('logged', now.subtract(const Duration(hours: 2))),
      ],
      endCns: 25,
    );
    final out = await tool().call({
      'follow_dive_id': 'logged',
      'dives': [dive],
    }, ctx());
    expect(out['followed_dive_id'], 'logged');
    final result = (out['dives']! as List).single as Map;
    final carried = result['carried_in']! as Map;
    expect(carried['surface_interval_s'], 2 * 3600);
    expect(carried['cns_percent'], greaterThan(0));
  });

  test('following a dive that is not there is refused', () async {
    await expectLater(
      tool().call({
        'follow_dive_id': 'gone',
        'dives': [dive],
      }, ctx()),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.code,
          'code',
          AgentToolErrorCode.notFound,
        ),
      ),
    );
  });

  test('a bad dive is refused before anything is computed', () async {
    await expectLater(
      tool().call({
        'dives': [
          {...dive, 'gf_low': 0},
        ],
      }, ctx()),
      throwsA(
        isA<AgentToolException>()
            .having((e) => e.code, 'code', AgentToolErrorCode.invalidArgument)
            .having((e) => e.details?['field'], 'field', 'dives[0].gf_low'),
      ),
    );
  });

  test('an unknown diver is refused', () async {
    await expectLater(
      tool().call({
        'diver_id': 'nobody',
        'dives': [dive],
      }, ctx()),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.code,
          'code',
          AgentToolErrorCode.unknownDiver,
        ),
      ),
    );
  });
}
