import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/settings/data/repositories/profile_metric_color_columns.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  setUp(() async => db = await setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  test('round-trips every metric through its own column', () async {
    var overrides = ProfileMetricColorOverrides.none;
    final values = <ProfileMetric, int>{};
    for (var i = 0; i < ProfileMetric.values.length; i++) {
      final metric = ProfileMetric.values[i];
      // Distinct, opaque, outside the palette so no swap rule interferes.
      values[metric] = 0xFF000000 | (0x010101 * (i + 1));
    }
    overrides = ProfileMetricColorOverrides.fromArgb(values);

    await db.customStatement('PRAGMA foreign_keys = OFF');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          withProfileMetricColors(
            DiverSettingsCompanion.insert(
              id: 'ds-pc',
              diverId: 'diver-pc',
              createdAt: now,
              updatedAt: now,
            ),
            overrides,
          ),
        );
    final row = await (db.select(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-pc'))).getSingle();
    expect(profileMetricColorsFromRow(row), overrides);
    for (final metric in ProfileMetric.values) {
      expect(
        row.toJson()[metric.settingsKey],
        values[metric],
        reason: metric.name,
      );
    }
  });

  test(
    'reads a sync clash deduped, so the next save stores the repair',
    () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.diverSettings)
          .insert(
            DiverSettingsCompanion.insert(
              id: 'ds-clash',
              diverId: 'diver-clash',
              createdAt: now,
              updatedAt: now,
              profileColorPpO2: const Value(0xFFE040FB),
              profileColorPpN2: const Value(0xFFE040FB),
            ),
          );
      final row = await (db.select(
        db.diverSettings,
      )..where((t) => t.id.equals('ds-clash'))).getSingle();
      final read = profileMetricColorsFromRow(row);
      expect(read.effectiveArgb(ProfileMetric.ppO2), 0xFFE040FB);
      expect(read.effectiveArgb(ProfileMetric.ppN2), isNot(0xFFE040FB));
    },
  );

  test('an empty override set writes null to every column', () {
    final c = withProfileMetricColors(
      const DiverSettingsCompanion(),
      ProfileMetricColorOverrides.none,
    );
    final cols = c.toColumns(false);
    expect(
      cols.keys.where((k) => k.startsWith('profile_color_')),
      hasLength(20),
    );
  });
}
