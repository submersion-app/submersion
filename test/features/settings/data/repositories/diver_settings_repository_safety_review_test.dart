import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('DiverSettingsRepository safety review settings persistence', () {
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

    test('defaults: review enabled, no rules disabled', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded, isNotNull);
      expect(loaded!.safetyReviewEnabled, isTrue);
      expect(loaded.safetyReviewDisabledRules, isEmpty);
    });

    test('round-trips disabled rules through update', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(
          safetyReviewEnabled: false,
          safetyReviewDisabledRules: {'sawtoothProfile', 'highSurfaceGf'},
        ),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded, isNotNull);
      expect(loaded!.safetyReviewEnabled, isFalse);
      expect(loaded.safetyReviewDisabledRules, {
        'sawtoothProfile',
        'highSurfaceGf',
      });
    });

    test('corrupted disabled-rules column falls back to empty set', () async {
      await repository.createSettingsForDiver('d1');

      Future<AppSettings?> loadWithRaw(String raw) async {
        await db.customStatement(
          'UPDATE diver_settings SET safety_review_disabled_rules = ? '
          'WHERE diver_id = ?',
          [raw, 'd1'],
        );
        return repository.getSettingsForDiver('d1');
      }

      // Non-list JSON (TypeError territory, not FormatException).
      var loaded = await loadWithRaw('{"a": 1}');
      expect(loaded, isNotNull);
      expect(loaded!.safetyReviewDisabledRules, isEmpty);

      // List with non-string elements: strings kept, junk dropped.
      loaded = await loadWithRaw('["rapidAscent", 42, null]');
      expect(loaded, isNotNull);
      expect(loaded!.safetyReviewDisabledRules, {'rapidAscent'});

      // Unparseable JSON.
      loaded = await loadWithRaw('not json');
      expect(loaded, isNotNull);
      expect(loaded!.safetyReviewDisabledRules, isEmpty);
    });
  });
}
