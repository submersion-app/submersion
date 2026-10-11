import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels_settings.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/test_database.dart';

void main() {
  test('the threshold defaults to a year and copyWith carries it', () {
    const settings = AppSettings();
    expect(settings.trendGapThreshold, TrendGapThreshold.year1);
    expect(
      settings
          .copyWith(trendGapThreshold: TrendGapThreshold.off)
          .trendGapThreshold,
      TrendGapThreshold.off,
    );
  });

  test('the conflict labeler names a stored month count', () {
    final en = AppLocalizationsEn();
    expect(trendGapThresholdLabeler(en, '24'), '2 years');
    expect(trendGapThresholdLabeler(en, '7'), isNull);
  });

  group('DiverSettingsRepository trend gap persistence', () {
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

    test('new settings start at one year', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.trendGapThreshold, TrendGapThreshold.year1);
    });

    test('every choice round-trips', () async {
      await repository.createSettingsForDiver('d1');
      for (final t in TrendGapThreshold.values) {
        await repository.updateSettingsForDiver(
          'd1',
          AppSettings(trendGapThreshold: t),
        );
        final loaded = await repository.getSettingsForDiver('d1');
        expect(loaded!.trendGapThreshold, t);
      }
    });

    test('an out-of-range stored value reads as one year', () async {
      await repository.createSettingsForDiver('d1');
      await db.customStatement(
        'UPDATE diver_settings SET trend_gap_collapse_months = 7 '
        "WHERE diver_id = 'd1'",
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.trendGapThreshold, TrendGapThreshold.year1);
    });
  });
}
