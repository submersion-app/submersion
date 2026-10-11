import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide EquipmentSet;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_clone_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/test_database.dart';

/// Copying a clone's clocks, sets and documents from its source (#3184).
void main() {
  late AppDatabase db;
  late EquipmentRepository equipment;
  late ServiceScheduleRepository schedules;
  late EquipmentSetRepository sets;
  late MediaRepository media;
  late EquipmentCloneService service;

  final t0 = DateTime(2026, 1, 1);

  setUp(() async {
    db = await setUpTestDatabase();
    equipment = EquipmentRepository();
    schedules = ServiceScheduleRepository();
    sets = EquipmentSetRepository();
    media = MediaRepository();
    service = EquipmentCloneService();
    final t = t0.millisecondsSinceEpoch;
    for (final id in ['owner', 'sharee']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  Future<EquipmentItem> make(
    String name,
    EquipmentType type, {
    String? diverId,
  }) => equipment.createEquipment(
    EquipmentItem(id: '', name: name, type: type, diverId: diverId),
  );

  Future<ServiceSchedule> addClock(
    String equipmentId,
    String kindId, {
    int? intervalDays,
    bool enabled = true,
  }) => schedules.createSchedule(
    ServiceSchedule(
      id: '',
      equipmentId: equipmentId,
      serviceKindId: kindId,
      intervalDays: intervalDays,
      enabled: enabled,
      createdAt: t0,
      updatedAt: t0,
    ),
  );

  Future<ServiceKind> customKind(String name, {String? diverId}) =>
      ServiceKindRepository().createKind(
        ServiceKind(
          id: '',
          diverId: diverId,
          name: name,
          createdAt: t0,
          updatedAt: t0,
        ),
      );

  group('service clocks', () {
    test(
      'a customised auto-attached clock merges into the clone\'s own',
      () async {
        final source = await make('Reg A', EquipmentType.regulator);
        final sourceClock = (await schedules.getSchedulesForEquipment(
          source.id,
        )).single;
        await schedules.updateSchedule(
          sourceClock.copyWith(
            intervalDays: 400,
            intervalDives: 150,
            defaultCost: 90.0,
            defaultCurrency: 'EUR',
            anchorDate: DateTime(2026, 1, 5),
            anchorSetAt: DateTime(2026, 1, 6),
          ),
        );
        final clone = await make('Reg A (copy)', EquipmentType.regulator);

        final failed = await service.copyExtras(
          sourceId: source.id,
          cloneId: clone.id,
          cloneType: clone.type,
          diverId: null,
        );

        expect(failed, isEmpty);
        final cloneClocks = await schedules.getSchedulesForEquipment(clone.id);
        expect(cloneClocks, hasLength(1));
        final c = cloneClocks.single;
        expect(c.serviceKindId, sourceClock.serviceKindId);
        expect(
          (c.intervalDays, c.intervalDives, c.defaultCost, c.defaultCurrency),
          (400, 150, 90.0, 'EUR'),
        );
        expect(c.anchorDate, isNull);
        expect(c.anchorSetAt, isNull);
      },
    );

    test(
      'a clock the source was given by hand is created on the clone',
      () async {
        // Fins auto-attach nothing.
        final source = await make('Fins', EquipmentType.fins);
        final kind = await customKind('Strap check');
        await addClock(source.id, kind.id, intervalDays: 30, enabled: false);
        final clone = await make('Fins (copy)', EquipmentType.fins);

        await service.copyExtras(
          sourceId: source.id,
          cloneId: clone.id,
          cloneType: clone.type,
          diverId: null,
        );

        final c = (await schedules.getSchedulesForEquipment(clone.id)).single;
        expect(
          (c.serviceKindId, c.intervalDays, c.enabled),
          (kind.id, 30, false),
        );
        expect(c.anchorDate, isNull);
      },
    );

    test(
      'a clock whose kind does not fit the clone\'s type stays behind',
      () async {
        // The diver changed Type on the clone form: a fins-only check has no
        // place on a hood.
        final source = await make('Fins', EquipmentType.fins);
        final finsOnly = await ServiceKindRepository().createKind(
          ServiceKind(
            id: '',
            name: 'Strap check',
            applicableTypes: const [EquipmentType.fins],
            createdAt: t0,
            updatedAt: t0,
          ),
        );
        await addClock(source.id, finsOnly.id, intervalDays: 30);
        final clone = await make('Fins (copy)', EquipmentType.hood);

        await service.copyExtras(
          sourceId: source.id,
          cloneId: clone.id,
          cloneType: clone.type,
          diverId: null,
        );

        expect(await schedules.getSchedulesForEquipment(clone.id), isEmpty);
      },
    );

    test('another diver\'s custom kind stays with the owner', () async {
      final source = await make('Fins', EquipmentType.fins, diverId: 'owner');
      final ownersKind = await customKind('Owner check', diverId: 'owner');
      await addClock(source.id, ownersKind.id, intervalDays: 30);

      final shareeClone = await make(
        'Fins (copy)',
        EquipmentType.fins,
        diverId: 'sharee',
      );
      await service.copyExtras(
        sourceId: source.id,
        cloneId: shareeClone.id,
        cloneType: shareeClone.type,
        diverId: 'sharee',
      );
      expect(await schedules.getSchedulesForEquipment(shareeClone.id), isEmpty);

      final ownerClone = await make(
        'Fins (copy)',
        EquipmentType.fins,
        diverId: 'owner',
      );
      await service.copyExtras(
        sourceId: source.id,
        cloneId: ownerClone.id,
        cloneType: ownerClone.type,
        diverId: 'owner',
      );
      expect(
        [
          for (final s in await schedules.getSchedulesForEquipment(
            ownerClone.id,
          ))
            s.serviceKindId,
        ],
        [ownersKind.id],
      );
    });
  });

  group('sets', () {
    late EquipmentItem source;

    setUp(() async {
      source = await make('Wing', EquipmentType.bcd, diverId: 'owner');
      for (final (id, diver) in [
        ('s-sharee', 'sharee'),
        ('s-owner', 'owner'),
      ]) {
        await sets.createSet(
          EquipmentSet(
            id: id,
            diverId: diver,
            name: id,
            equipmentIds: [source.id],
            createdAt: t0,
            updatedAt: t0,
          ),
        );
      }
    });

    test('a sharee\'s clone joins only the sharee\'s sets', () async {
      final clone = await make(
        'Wing (copy)',
        EquipmentType.bcd,
        diverId: 'sharee',
      );

      await service.copyExtras(
        sourceId: source.id,
        cloneId: clone.id,
        cloneType: clone.type,
        diverId: 'sharee',
      );

      expect(await sets.getSetIdsContaining(clone.id), ['s-sharee']);
      expect(await sets.getEquipmentIdsInSet('s-owner'), [source.id]);
    });

    test('with no active diver, the clone joins every set', () async {
      final clone = await make('Wing (copy)', EquipmentType.bcd);

      await service.copyExtras(
        sourceId: source.id,
        cloneId: clone.id,
        cloneType: clone.type,
        diverId: null,
      );

      expect((await sets.getSetIdsContaining(clone.id)).toSet(), {
        's-sharee',
        's-owner',
      });
    });
  });

  group('documents', () {
    test(
      'each document gets its own row on the clone, sharing the file',
      () async {
        final source = await make('Drysuit', EquipmentType.drysuit);
        final clone = await make('Drysuit (copy)', EquipmentType.drysuit);
        final t = t0.millisecondsSinceEpoch;
        await db
            .into(db.dives)
            .insert(
              DivesCompanion.insert(
                id: 'dive-1',
                diveDateTime: t,
                createdAt: t,
                updatedAt: t,
              ),
            );
        final original = await media.createMedia(
          MediaItem(
            id: '',
            equipmentId: source.id,
            diveId: 'dive-1',
            mediaType: MediaType.document,
            originalFilename: 'invoice.pdf',
            filePath: '/docs/invoice.pdf',
            contentHash: 'hash-1',
            caption: 'Receipt',
            takenAt: t0,
            createdAt: t0,
            updatedAt: t0,
          ),
        );

        await service.copyExtras(
          sourceId: source.id,
          cloneId: clone.id,
          cloneType: clone.type,
          diverId: null,
        );

        final copy = (await media.getMediaForEquipment(clone.id)).single;
        expect(copy.id, isNot(original.id));
        expect(
          (
            copy.originalFilename,
            copy.filePath,
            copy.contentHash,
            copy.caption,
          ),
          ('invoice.pdf', '/docs/invoice.pdf', 'hash-1', 'Receipt'),
        );
        expect(copy.diveId, isNull);
        expect(copy.siteId, isNull);
        // The original keeps its row and its dive link, and the dive still
        // has the one row: the copy belongs to the clone only.
        final kept = (await media.getMediaForEquipment(source.id)).single;
        expect((kept.id, kept.diveId), (original.id, 'dive-1'));
        expect(await media.countRowsWithHash('hash-1'), 2);
      },
    );
  });

  test('a failing step is reported and does not skip the others', () async {
    final source = await make('Hood', EquipmentType.hood);
    await media.createMedia(
      MediaItem(
        id: '',
        equipmentId: source.id,
        mediaType: MediaType.document,
        originalFilename: 'warranty.pdf',
        takenAt: t0,
        createdAt: t0,
        updatedAt: t0,
      ),
    );
    final kind = await customKind('Seal check');
    await addClock(source.id, kind.id, intervalDays: 90);
    final clone = await make('Hood (copy)', EquipmentType.hood);

    final failed = await EquipmentCloneService(sets: _ThrowingSetRepository())
        .copyExtras(
          sourceId: source.id,
          cloneId: clone.id,
          cloneType: clone.type,
          diverId: null,
        );

    expect(failed, {CloneExtrasStep.sets});
    expect(await schedules.getSchedulesForEquipment(clone.id), hasLength(1));
    expect(await media.getMediaForEquipment(clone.id), hasLength(1));
  });
}

class _ThrowingSetRepository extends EquipmentSetRepository {
  @override
  Future<List<String>> getSetIdsContaining(
    String equipmentId, {
    String? diverId,
  }) => Future.error(StateError('set read failed'));
}
