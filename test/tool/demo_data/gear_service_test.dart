import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';

import '../../../tool/demo_data/src/seeders/demo_seeding.dart';
import '../../../tool/demo_data/src/seeders/gear_service_seeder.dart';
import '../../../tool/demo_data/src/seeders/seed_context.dart';
import '../../helpers/test_database.dart';
import 'seed_harness.dart';

void main() {
  late DemoSeedContext ctx;

  setUpAll(() async {
    ctx = await seedContext();
    await seedAll(ctx);
  });

  tearDownAll(tearDownTestDatabase);

  bool insideTrip(DateTime when) => ctx.plan.trips.any(
    (t) =>
        !when.isBefore(DateTime(t.start.year, t.start.month, t.start.day)) &&
        when.isBefore(DateTime(t.end.year, t.end.month, t.end.day + 1)),
  );

  test('every built-in service kind has a clock or a record', () async {
    final rows = await ctx.db
        .customSelect(
          'SELECT service_kind_id AS k FROM service_schedules '
          'UNION SELECT service_kind_id FROM service_records',
        )
        .get();
    final used = {for (final r in rows) r.read<String?>('k')};
    expect(
      used,
      containsAll([
        'hydro',
        'vip',
        'o2-clean',
        'regulator-service',
        'computer-battery',
        'transmitter-battery',
        'bcd-inspection',
        'drysuit-seals',
        'scrubber-repack',
        'o2-cell-replacement',
        'rebreather-annual',
        'general-service',
      ]),
    );
  });

  test('every clock has a history of several services', () async {
    final n =
        (await ctx.db
                .customSelect('SELECT COUNT(*) AS n FROM service_records')
                .getSingle())
            .read<int>('n');
    expect(n, greaterThan(150));
  });

  test(
    'exactly two clocks are overdue and at least two due soon at the anchor',
    () async {
      // The explorer's today lands from the anchor to 13 days after it: the
      // newest dive is in the week before the anchor, and the demo shift
      // puts it one to two weeks before the explorer's today.
      for (final days in [0, 13]) {
        final at = ctx.anchor.add(Duration(days: days));
        final statuses = await demoClockStatuses(ctx, at);
        final overdue = {
          for (final (key, s) in statuses)
            if (s.severity == ServiceClockSeverity.overdue) (key, s.kind.id),
        };
        final dueSoon = {
          for (final (key, s) in statuses)
            if (s.severity == ServiceClockSeverity.dueSoon) (key, s.kind.id),
        };
        expect(overdue, overdueClocks, reason: 'anchor + $days days');
        expect(dueSoon, containsAll(dueSoonClocks), reason: 'anchor + $days');
      }
    },
  );

  test('no purchase, service record or fill falls inside a trip', () async {
    for (final table in [
      ('service_records', 'service_date'),
      ('cylinder_fills', 'filled_at'),
      ('equipment', 'purchase_date'),
    ]) {
      final rows = await ctx.db
          .customSelect(
            'SELECT ${table.$2} AS d FROM ${table.$1} WHERE ${table.$2} IS NOT NULL',
          )
          .get();
      for (final r in rows) {
        final at = DateTime.fromMillisecondsSinceEpoch(r.read<int>('d'));
        expect(insideTrip(at), isFalse, reason: '${table.$1} at $at');
      }
    }
  });
}
