import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/demo_mode/data/demo_database_preparer.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/equipment_findings_pass.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';

import '../../../tool/demo_data/src/seeders/demo_seeding.dart';
import '../../../tool/demo_data/src/seeders/fault_signals.dart';
import '../../../tool/demo_data/src/seeders/seed_context.dart';
import '../../helpers/test_database.dart';
import 'seed_harness.dart';

const _planned = {
  'issueRecurring',
  'issueColdCorrelated',
  'issueDeepCorrelated',
  'incidentLinked',
  'transmitterDropoutHigh',
  'cellDivergent',
};

void main() {
  group('the seeded logbook', () {
    late DemoSeedContext ctx;

    setUpAll(() async {
      ctx = await seedContext();
      await seedAll(ctx);
    });

    tearDownAll(tearDownTestDatabase);

    Future<Set<String>> ruleIds() async => {
      for (final r
          in await ctx.db
              .customSelect(
                'SELECT DISTINCT rule_id AS r FROM equipment_findings '
                'WHERE dismissed_at IS NULL',
              )
              .get())
        r.read<String>('r'),
    };

    test('the findings pass raises every planned finding', () async {
      expect(await ruleIds(), containsAll(_planned));
    });

    test('findings are still raised after the demo date shift', () async {
      final now = ctx.anchor.add(const Duration(days: 23));
      await DemoDatabasePreparer().prepare(
        ctx.db,
        now: now,
        photosDir: ctx.photosDir,
        deviceId: null,
      );
      await ctx.db.customStatement('DELETE FROM equipment_findings');
      final dives = await ctx.db.customSelect('SELECT id FROM dives').get();
      final sensors = DiveSensorSummaryRepository();
      for (final d in dives) {
        await sensors.ensureCurrent(d.read<String>('id'));
      }
      await EquipmentFindingsPass().run(
        items: await EquipmentRepository().getAllEquipment(
          diverId: DemoSeedContext.diverId,
        ),
        thresholds: ExposureThresholds.defaults,
      );

      expect(await ruleIds(), containsAll(_planned));
    });
  });

  test('withDropouts gaps exceed three cadences and total the fraction', () {
    final pressures = [for (var t = 0; t <= 3600; t += 10) (t, 200.0 - t / 30)];

    final cut = withDropouts(pressures, gapFraction: 0.15, random: Random(3));

    var gapSeconds = 0;
    for (var i = 1; i < cut.length; i++) {
      final dt = cut[i].$1 - cut[i - 1].$1;
      if (dt > 30) gapSeconds += dt;
    }
    expect(gapSeconds / 3600, inInclusiveRange(0.12, 0.2));
    expect(cut.first.$1, 0);
    expect(cut.last.$1, 3600);
  });

  test('cell millivolts follow the gain', () {
    expect(cellMv(1.3, 50), 65);
    expect(cellMv(0.21, 48), 10);
  });
}
