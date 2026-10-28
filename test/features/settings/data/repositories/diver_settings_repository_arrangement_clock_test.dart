import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Which clock a settings save stamps (issue #3748): an arrangement-only
/// change stamps only the list arrangement clock, so it never republishes
/// this device's copy of the diver's other settings; any other change
/// stamps the row clock as before.
void main() {
  late AppDatabase db;
  final repository = DiverSettingsRepository();

  Future<({String? hlc, String? group, String? status})> clocks() async {
    final row = await db
        .customSelect(
          'SELECT s.hlc, s.list_arrangement_hlc, r.sync_status '
          'FROM diver_settings s LEFT JOIN sync_records r '
          "ON r.entity_type = 'diverSettings' AND r.record_id = s.id "
          "WHERE s.diver_id = 'd1'",
        )
        .getSingle();
    return (
      hlc: row.read<String?>('hlc'),
      group: row.read<String?>('list_arrangement_hlc'),
      status: row.read<String?>('sync_status'),
    );
  }

  bool isNewer(String? after, String? before) =>
      after != null && (before == null || after.compareTo(before) > 0);

  Future<void> save(AppSettings Function(AppSettings) change) async {
    final current = (await repository.getSettingsForDiver('d1'))!;
    await repository.updateSettingsForDiver(
      'd1',
      change(current),
      previous: current,
    );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'Test Diver',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await repository.createSettingsForDiver('d1');
    await db.customStatement(
      "UPDATE sync_records SET sync_status = 'synced' "
      "WHERE entity_type = 'diverSettings'",
    );
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('a new row starts with no arrangement clock', () async {
    // Nothing was arranged yet: the row's arrangement must lose to any a
    // peer makes, so its clock stays unset rather than borrowing the row
    // clock (SyncFactGroup.nullClockIsUnset).
    final c = await clocks();
    expect(c.hlc, isNotNull);
    expect(c.group, isNull);
  });

  test(
    'an arrangement-only change stamps the group clock and leaves hlc',
    () async {
      final before = await clocks();
      await save(
        (s) => s.copyWith(
          listArrangements: s.listArrangements.copyWith(
            diveSort: 'maxDepth:ascending',
          ),
        ),
      );
      final after = await clocks();
      expect(after.hlc, before.hlc);
      expect(isNewer(after.group, before.group), isTrue);
      expect(after.status, 'pending');
    },
  );

  test('a view mode change is an arrangement change', () async {
    final before = await clocks();
    await save((s) => s.copyWith(siteListViewMode: ListViewMode.table));
    final after = await clocks();
    expect(after.hlc, before.hlc);
    expect(isNewer(after.group, before.group), isTrue);
  });

  test('a units change stamps hlc and leaves a set group clock', () async {
    final before = await clocks();
    await save((s) => s.copyWith(depthUnit: DepthUnit.feet));
    final after = await clocks();
    expect(after.hlc!.compareTo(before.hlc!), greaterThan(0));
    expect(after.group, before.group);
    expect(after.status, 'pending');
  });

  test(
    'a row with no row clock gets one with its first arrangement change',
    () async {
      // A row from before the HLC rollout, never edited since: without a row
      // clock it cannot be ordered against a peer, whose updatedAt fallback
      // would then take this device's whole row, stale settings included,
      // because a sort tap moved updatedAt.
      await db.customStatement(
        "UPDATE diver_settings SET hlc = NULL, list_arrangement_hlc = NULL "
        "WHERE diver_id = 'd1'",
      );
      await save(
        (s) => s.copyWith(
          listArrangements: s.listArrangements.copyWith(
            diveSort: 'depth:ascending',
          ),
        ),
      );
      final after = await clocks();
      expect(after.hlc, isNotNull);
      expect(after.group, isNotNull);
    },
  );

  test('a mixed change stamps both', () async {
    final before = await clocks();
    await save(
      (s) => s.copyWith(
        depthUnit: DepthUnit.feet,
        listArrangements: s.listArrangements.copyWith(siteGroupBy: 'country'),
      ),
    );
    final after = await clocks();
    expect(after.hlc!.compareTo(before.hlc!), greaterThan(0));
    expect(isNewer(after.group, before.group), isTrue);
    expect(after.status, 'pending');
  });
}
