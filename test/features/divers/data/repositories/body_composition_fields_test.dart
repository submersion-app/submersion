import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide Diver;
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_weight_entry_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';

import '../../../../helpers/test_database.dart';

/// The body composition inputs of the weight prediction (issue #4525): a
/// diver's sex and birth year, and a body fat percentage on a body-weight
/// entry. All optional.
void main() {
  late AppDatabase db;
  late DiverRepository divers;
  late DiverWeightEntryRepository entries;
  final now = DateTime(2026, 11, 1);

  Diver diver({DiverSex? sex, int? birthYear}) => Diver(
    id: '',
    name: 'Alex',
    sex: sex,
    birthYear: birthYear,
    createdAt: now,
    updatedAt: now,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    divers = DiverRepository();
    entries = DiverWeightEntryRepository();
  });
  tearDown(tearDownTestDatabase);

  group('Diver', () {
    test('copyWith sets and clears sex and birth year', () {
      final set = diver().copyWith(sex: DiverSex.female, birthYear: 1984);
      expect(set.sex, DiverSex.female);
      expect(set.birthYear, 1984);
      // An unrelated copy keeps them.
      expect(set.copyWith(name: 'Sam').sex, DiverSex.female);
      expect(set.copyWith(name: 'Sam').birthYear, 1984);
      final cleared = set.copyWith(sex: null, birthYear: null);
      expect(cleared.sex, isNull);
      expect(cleared.birthYear, isNull);
    });

    test('divers differing only by sex or birth year are not equal', () {
      expect(diver(sex: DiverSex.male), isNot(diver()));
      expect(diver(birthYear: 1990), isNot(diver()));
    });

    test('sex and birth year round-trip through the repository', () async {
      final created = await divers.createDiver(
        diver(sex: DiverSex.male, birthYear: 1979),
      );
      final stored = (await divers.getDiverById(created.id))!;
      expect(stored.sex, DiverSex.male);
      expect(stored.birthYear, 1979);

      await divers.updateDiver(stored.copyWith(sex: null, birthYear: null));
      final cleared = (await divers.getDiverById(created.id))!;
      expect(cleared.sex, isNull);
      expect(cleared.birthYear, isNull);
    });

    test('a diver saved without them reads null', () async {
      final created = await divers.createDiver(diver());
      final stored = (await divers.getDiverById(created.id))!;
      expect(stored.sex, isNull);
      expect(stored.birthYear, isNull);
    });

    test('a stored sex this build does not know reads as not given', () async {
      final created = await divers.createDiver(diver(sex: DiverSex.female));
      await db.customStatement(
        "UPDATE divers SET sex = 'somethingNew' WHERE id = ?",
        [created.id],
      );
      expect((await divers.getDiverById(created.id))!.sex, isNull);
    });
  });

  group('DiverWeightEntry', () {
    late String diverId;

    setUp(() async {
      diverId = (await divers.createDiver(diver())).id;
    });

    DiverWeightEntry entry({double? bodyFatPercent}) => DiverWeightEntry(
      id: '',
      diverId: diverId,
      measuredAt: now,
      weightKg: 80,
      heightCm: 175,
      bodyFatPercent: bodyFatPercent,
      createdAt: now,
      updatedAt: now,
    );

    test('body fat round-trips through create and update', () async {
      final created = await entries.createEntry(entry(bodyFatPercent: 18.5));
      expect((await entries.latestEntry(diverId))!.bodyFatPercent, 18.5);

      await entries.updateEntry(created.copyWith(bodyFatPercent: 21));
      expect((await entries.latestEntry(diverId))!.bodyFatPercent, 21);
    });

    test('an entry without body fat reads null', () async {
      await entries.createEntry(entry());
      expect((await entries.latestEntry(diverId))!.bodyFatPercent, isNull);
    });

    test('copyWith carries body fat, and it is part of equality', () {
      final withFat = entry(bodyFatPercent: 20);
      expect(withFat.copyWith(weightKg: 81).bodyFatPercent, 20);
      expect(withFat, isNot(entry()));
    });
  });
}
