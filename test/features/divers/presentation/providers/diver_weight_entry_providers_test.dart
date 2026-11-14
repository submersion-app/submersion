import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';

void main() {
  DiverWeightEntry entry(
    String id,
    DateTime at, {
    double? heightCm,
    double? bodyFatPercent,
  }) => DiverWeightEntry(
    id: id,
    diverId: 'diver-1',
    measuredAt: at,
    weightKg: 80,
    heightCm: heightCm,
    bodyFatPercent: bodyFatPercent,
    createdAt: at,
    updatedAt: at,
  );

  ProviderContainer containerWith(List<DiverWeightEntry> entries) {
    final c = ProviderContainer(
      overrides: [
        diverWeightEntriesProvider.overrideWith((ref) async => entries),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'latestDiverHeightProvider skips newer entries without a height',
    () async {
      final c = containerWith([
        entry('w3', DateTime(2026, 8, 1)),
        entry('w2', DateTime(2026, 7, 1), heightCm: 180),
        entry('w1', DateTime(2026, 6, 1), heightCm: 170),
      ]);
      expect(await c.read(latestDiverHeightProvider.future), 180);
    },
  );

  test('latestDiverHeightProvider skips implausible stored heights', () async {
    final c = containerWith([
      entry('w2', DateTime(2026, 7, 1), heightCm: 1750),
      entry('w1', DateTime(2026, 6, 1), heightCm: 175),
    ]);
    expect(await c.read(latestDiverHeightProvider.future), 175);
  });

  test(
    'latestDiverHeightProvider is null when no entry records a height',
    () async {
      final c = containerWith([entry('w1', DateTime(2026, 6, 1))]);
      expect(await c.read(latestDiverHeightProvider.future), isNull);
    },
  );

  test('latestDiverWeightProvider still returns the newest entry', () async {
    final c = containerWith([
      entry('w2', DateTime(2026, 7, 1)),
      entry('w1', DateTime(2026, 6, 1), heightCm: 170),
    ]);
    expect((await c.read(latestDiverWeightProvider.future))?.id, 'w2');
  });

  group('body fat, sex and age (issue #4525)', () {
    test('the latest body fat carries forward past an entry without '
        'one', () async {
      final c = containerWith([
        entry('w3', DateTime(2026, 8, 1)),
        entry('w2', DateTime(2026, 7, 1), bodyFatPercent: 22.5),
        entry('w1', DateTime(2026, 6, 1), bodyFatPercent: 25),
      ]);
      expect(await c.read(latestDiverBodyFatProvider.future), 22.5);
    });

    test('an implausible stored body fat is skipped', () async {
      final c = containerWith([
        entry('w2', DateTime(2026, 7, 1), bodyFatPercent: 225),
        entry('w1', DateTime(2026, 6, 1), bodyFatPercent: 25),
      ]);
      expect(await c.read(latestDiverBodyFatProvider.future), 25);
    });

    test('the latest body fat is null when no entry has one', () async {
      final c = containerWith([entry('w1', DateTime(2026, 6, 1))]);
      expect(await c.read(latestDiverBodyFatProvider.future), isNull);
    });

    ProviderContainer containerFor(Diver? diver) {
      final c = ProviderContainer(
        overrides: [currentDiverProvider.overrideWith((ref) async => diver)],
      );
      addTearDown(c.dispose);
      return c;
    }

    Diver diver({DiverSex? sex, int? birthYear}) => Diver(
      id: 'diver-1',
      name: 'Tester',
      sex: sex,
      birthYear: birthYear,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('the body profile is the current diver\'s sex and age', () async {
      final birthYear = DateTime.now().year - 42;
      final c = containerFor(diver(sex: DiverSex.female, birthYear: birthYear));
      final profile = await c.read(diverBodyProfileProvider.future);
      expect(profile.sex, DiverSex.female);
      expect(profile.ageYears, 42);
    });

    test(
      'the body profile is empty without a diver or their details',
      () async {
        for (final d in [null, diver()]) {
          final profile = await containerFor(
            d,
          ).read(diverBodyProfileProvider.future);
          expect(profile.sex, isNull);
          expect(profile.ageYears, isNull);
        }
      },
    );

    test('a child\'s birth year gives no age', () async {
      final c = containerFor(diver(birthYear: DateTime.now().year - 10));
      expect((await c.read(diverBodyProfileProvider.future)).ageYears, isNull);
    });
  });
}
