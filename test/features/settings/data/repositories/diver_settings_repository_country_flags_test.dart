import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The country flags switch (issue #4426) must survive a real write and read
/// through SQLite: a missing companion or row mapping would leave "off"
/// working only in memory, and the flags would come back at the next load.
void main() {
  group('DiverSettingsRepository showCountryFlags persistence', () {
    late DiverSettingsRepository repository;

    setUp(() async {
      final db = await setUpTestDatabase();
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

    test('flags default to on', () async {
      expect(const AppSettings().showCountryFlags, isTrue);
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.showCountryFlags, isTrue);
    });

    test('update round-trips off, then back on', () async {
      await repository.createSettingsForDiver('d1');

      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(showCountryFlags: false),
      );
      expect(
        (await repository.getSettingsForDiver('d1'))!.showCountryFlags,
        isFalse,
      );

      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(showCountryFlags: true),
      );
      expect(
        (await repository.getSettingsForDiver('d1'))!.showCountryFlags,
        isTrue,
      );
    });

    test('copyWith carries the switch', () {
      const settings = AppSettings();
      expect(
        settings.copyWith(showCountryFlags: false).showCountryFlags,
        isFalse,
      );
      expect(
        settings.copyWith(showCountryFlags: false).copyWith().showCountryFlags,
        isFalse,
      );
    });
  });

  /// The Dives, Buddies and Trips switches (issue #5001) go through the same
  /// write and read as the Sites one.
  group('DiverSettingsRepository section flag switches persistence', () {
    late DiverSettingsRepository repository;

    setUp(() async {
      final db = await setUpTestDatabase();
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

    final switches = <String, bool Function(AppSettings)>{
      'dives': (s) => s.showDiveCountryFlags,
      'buddies': (s) => s.showBuddyCountryFlags,
      'trips': (s) => s.showTripCountryFlags,
    };
    AppSettings withOnly(String name, bool value) => switch (name) {
      'dives' => AppSettings(showDiveCountryFlags: value),
      'buddies' => AppSettings(showBuddyCountryFlags: value),
      _ => AppSettings(showTripCountryFlags: value),
    };

    for (final entry in switches.entries) {
      test('${entry.key} defaults to on', () async {
        expect(entry.value(const AppSettings()), isTrue);
        await repository.createSettingsForDiver('d1');
        expect(
          entry.value((await repository.getSettingsForDiver('d1'))!),
          isTrue,
        );
      });

      test('${entry.key} round-trips off, then back on', () async {
        await repository.createSettingsForDiver('d1');
        await repository.updateSettingsForDiver(
          'd1',
          withOnly(entry.key, false),
        );
        final off = (await repository.getSettingsForDiver('d1'))!;
        expect(entry.value(off), isFalse);
        // Only this section's switch moved.
        for (final other in switches.entries) {
          if (other.key != entry.key) expect(other.value(off), isTrue);
        }
        expect(off.showCountryFlags, isTrue);
        await repository.updateSettingsForDiver(
          'd1',
          withOnly(entry.key, true),
        );
        expect(
          entry.value((await repository.getSettingsForDiver('d1'))!),
          isTrue,
        );
      });

      test('copyWith carries the ${entry.key} switch', () {
        final off = withOnly(entry.key, false);
        expect(entry.value(off.copyWith()), isFalse);
      });
    }
  });
}
