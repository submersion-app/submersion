import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3012: a diver's profile metric colours persist through the
/// repository's create, update and read paths.
void main() {
  late AppDatabase db;
  late DiverSettingsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiverSettingsRepository();
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
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  final swapped = ProfileMetricColorOverrides.none.withColor(
    ProfileMetric.ppO2,
    ProfileMetricColors.tts,
  );

  test('new settings carry no colours', () async {
    await repository.createSettingsForDiver('d1');
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.profileMetricColors, ProfileMetricColorOverrides.none);
  });

  test('settings created with colours keep them', () async {
    await repository.createSettingsForDiver(
      'd1',
      settings: AppSettings(profileMetricColors: swapped),
    );
    final loaded = await repository.getSettingsForDiver('d1');
    expect(loaded!.profileMetricColors, swapped);
  });

  test(
    'an update stores both swapped metrics, and a reset clears them',
    () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        AppSettings(profileMetricColors: swapped),
      );
      expect(
        (await repository.getSettingsForDiver('d1'))!.profileMetricColors,
        swapped,
      );

      await repository.updateSettingsForDiver('d1', const AppSettings());
      expect(
        (await repository.getSettingsForDiver('d1'))!.profileMetricColors,
        ProfileMetricColorOverrides.none,
      );
    },
  );

  test('copyWith carries the colours', () {
    final s = const AppSettings().copyWith(
      profileMetricColors: ProfileMetricColorOverrides.none.withColor(
        ProfileMetric.gf,
        const Color(0xFF00E676),
      ),
    );
    expect(s.profileMetricColors.count, 1);
  });
}
