import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/features/equipment/data/services/equipment_item_fold.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_auto_registrar.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_key_adoption.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import '../../../../helpers/test_database.dart';

/// A fold that fails, as a closed database would.
class _FailingFold extends EquipmentItemFold {
  @override
  Future<bool> fold({required String fromId, required String intoId}) =>
      Future.error(StateError('database closed'));
}

/// A diver who set a transmitter up by hand, then downloaded before its
/// serial was on the item, has the serial on a placeholder the download made.
/// Giving the serial to their own item moves it there (issue #3367).
void main() {
  late AppDatabase db;
  late TransmitterRepository repo;

  const serial = '76287';
  final at = DateTime.utc(2026, 11, 2);

  Future<void> insertItem(String id, {String name = 'Mine'}) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          diverId: const Value('d1'),
          name: name,
          type: 'transmitter',
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  /// What the download leaves behind for [serial], through the real path.
  Future<String> registerFromDownload() async {
    await TransmitterAutoRegistrar(
      nameFor: (s) => 'Transmitter $s',
    ).registerNewSerials([serial], diverId: 'd1');
    final row = (await repo.getForDiver(
      'd1',
    )).singleWhere((t) => t.transmitterSerial == serial);
    return row.transmitterEquipmentId!;
  }

  Transmitter keyOn(
    String itemId, {
    String id = 'new-key',
    String? transmitterSerial = serial,
    String? diveComputerId,
    int? channelIndex,
  }) => Transmitter(
    id: id,
    diverId: 'd1',
    transmitterSerial: transmitterSerial,
    diveComputerId: diveComputerId,
    channelIndex: channelIndex,
    label: 'Mine',
    role: TankRole.sidemountLeft,
    volumeL: 10,
    transmitterEquipmentId: itemId,
    isConfigured: true,
    createdAt: at,
    updatedAt: at,
  );

  Future<Transmitter> holderOfSerial() async => (await repo.getForDiver(
    'd1',
  )).singleWhere((t) => t.transmitterSerial == serial);

  Future<bool> itemExists(String id) async =>
      await (db.select(
        db.equipment,
      )..where((t) => t.id.equals(id))).getSingleOrNull() !=
      null;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = TransmitterRepository();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await insertItem('mine');
  });
  tearDown(tearDownTestDatabase);

  group('isUnclaimedKeyFor', () {
    Transmitter holder({
      String id = 'holder',
      String? transmitterSerial = serial,
      String? item = 'placeholder',
      bool isConfigured = false,
      String? diveComputerId,
      int? channelIndex,
    }) => Transmitter(
      id: id,
      diverId: 'd1',
      transmitterSerial: transmitterSerial,
      diveComputerId: diveComputerId,
      channelIndex: channelIndex,
      label: 'Transmitter 76287',
      transmitterEquipmentId: item,
      isConfigured: isConfigured,
      createdAt: at,
      updatedAt: at,
    );

    test('a serial a download registered on another item is unclaimed', () {
      expect(isUnclaimedKeyFor(keyOn('mine'), holder()), isTrue);
    });

    test('compares canonical serials, as the conflict check does', () {
      expect(
        isUnclaimedKeyFor(
          keyOn('mine', transmitterSerial: ' 76287 '),
          holder(),
        ),
        isTrue,
      );
    });

    test('a serial the diver set up elsewhere is theirs to keep', () {
      expect(
        isUnclaimedKeyFor(keyOn('mine'), holder(isConfigured: true)),
        isFalse,
      );
    });

    test('a key already behind this item is not moved to it', () {
      expect(isUnclaimedKeyFor(keyOn('mine'), holder(item: 'mine')), isFalse);
    });

    test('an entry behind no item has nothing to fold', () {
      expect(isUnclaimedKeyFor(keyOn('mine'), holder(item: null)), isFalse);
    });

    test('a clash on the channel alone is a real conflict', () {
      expect(
        isUnclaimedKeyFor(
          keyOn(
            'mine',
            transmitterSerial: null,
            diveComputerId: 'dc',
            channelIndex: 0,
          ),
          holder(
            transmitterSerial: null,
            diveComputerId: 'dc',
            channelIndex: 0,
          ),
        ),
        isFalse,
      );
    });
  });

  group('adoptTransmitterKey', () {
    test('moves the serial onto the item with the setup just saved', () async {
      await registerFromDownload();

      await adoptTransmitterKey(
        keyOn('mine'),
        await holderOfSerial(),
        repository: repo,
      );

      final key = (await repo.getForEquipment('mine')).single;
      expect(key.transmitterSerial, serial);
      expect(key.isConfigured, isTrue);
      expect(key.role, TankRole.sidemountLeft);
      expect(key.volumeL, 10);
      expect(key.label, 'Mine');
      expect(await repo.getForDiver('d1'), hasLength(1));
    });

    test('removes the placeholder item, so the diver sees one', () async {
      final placeholder = await registerFromDownload();

      await adoptTransmitterKey(
        keyOn('mine'),
        await holderOfSerial(),
        repository: repo,
      );

      expect(await itemExists(placeholder), isFalse);
      expect(await itemExists('mine'), isTrue);
    });

    test('keeps the derived row id, so devices still converge', () async {
      await registerFromDownload();

      final saved = await adoptTransmitterKey(
        keyOn('mine'),
        await holderOfSerial(),
        repository: repo,
      );

      expect(saved.id, autoTransmitterRowId('d1', serial));
      expect(
        (await repo.getForEquipment('mine')).single.id,
        autoTransmitterRowId('d1', serial),
      );
    });

    test('logs no deletion for a key that was never stored', () async {
      await registerFromDownload();

      await adoptTransmitterKey(
        keyOn('mine'),
        await holderOfSerial(),
        repository: repo,
      );

      final logged = await (db.select(
        db.deletionLog,
      )..where((t) => t.recordId.equals('new-key'))).get();
      expect(logged, isEmpty);
    });

    test('what the diver kept on the placeholder moves with it', () async {
      final placeholder = await registerFromDownload();
      await (db.update(db.equipment)..where((t) => t.id.equals(placeholder)))
          .write(const EquipmentCompanion(brand: Value('Oceanic')));
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'dive1',
              diverId: const Value('d1'),
              diveDateTime: 0,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(
              diveId: 'dive1',
              equipmentId: placeholder,
            ),
          );

      await adoptTransmitterKey(
        keyOn('mine'),
        await holderOfSerial(),
        repository: repo,
      );

      final item = await (db.select(
        db.equipment,
      )..where((t) => t.id.equals('mine'))).getSingle();
      expect(item.brand, 'Oceanic');
      expect(item.serialNumber, serial);
      final links = await (db.select(
        db.diveEquipment,
      )..where((t) => t.diveId.equals('dive1'))).get();
      expect(links.map((l) => l.equipmentId), ['mine']);
    });

    test('editing a key to the serial replaces the key edited', () async {
      await registerFromDownload();
      await repo.create(
        keyOn('mine', id: 'typed-key', transmitterSerial: '076287'),
      );
      final editing = await repo.getById('typed-key');

      await adoptTransmitterKey(
        editing!.copyWith(transmitterSerial: serial),
        await holderOfSerial(),
        repository: repo,
      );

      final key = (await repo.getForEquipment('mine')).single;
      expect(key.transmitterSerial, serial);
      expect(await repo.getById('typed-key'), isNull);
    });

    test('the key being edited does not clash with itself', () async {
      await registerFromDownload();
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: 'dc',
              name: 'dc',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await repo.create(
        keyOn(
          'mine',
          id: 'typed-key',
          transmitterSerial: '076287',
          diveComputerId: 'dc',
          channelIndex: 3,
        ),
      );
      final editing = await repo.getById('typed-key');

      await adoptTransmitterKey(
        editing!.copyWith(transmitterSerial: serial),
        await holderOfSerial(),
        repository: repo,
      );

      final key = (await repo.getForEquipment('mine')).single;
      expect(key.transmitterSerial, serial);
      expect(key.channelIndex, 3);
    });

    test('a fold that fails still saves the key', () async {
      await registerFromDownload();

      await adoptTransmitterKey(
        keyOn('mine'),
        await holderOfSerial(),
        repository: repo,
        itemFold: _FailingFold(),
      );

      expect(
        (await repo.getForEquipment('mine')).single.transmitterSerial,
        serial,
      );
    });

    test('a placeholder that still has another key stays', () async {
      final placeholder = await registerFromDownload();
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: 'dc',
              name: 'dc',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await repo.create(
        keyOn(
          placeholder,
          id: 'channel-key',
          transmitterSerial: null,
          diveComputerId: 'dc',
          channelIndex: 1,
        ),
      );

      await adoptTransmitterKey(
        keyOn('mine'),
        await holderOfSerial(),
        repository: repo,
      );

      expect(await itemExists(placeholder), isTrue);
      expect((await repo.getForEquipment(placeholder)).map((k) => k.id), [
        'channel-key',
      ]);
    });

    test('a clash with a third entry refuses before anything moves', () async {
      final placeholder = await registerFromDownload();
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: 'dc',
              name: 'dc',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await insertItem('third', name: 'Third');
      await repo.create(
        keyOn(
          'third',
          id: 'third-key',
          transmitterSerial: null,
          diveComputerId: 'dc',
          channelIndex: 2,
        ),
      );

      await expectLater(
        adoptTransmitterKey(
          keyOn('mine', diveComputerId: 'dc', channelIndex: 2),
          await holderOfSerial(),
          repository: repo,
        ),
        throwsA(
          isA<TransmitterConflictException>().having(
            (e) => e.existing.id,
            'existing',
            'third-key',
          ),
        ),
      );

      expect(await itemExists(placeholder), isTrue);
      expect((await holderOfSerial()).transmitterEquipmentId, placeholder);
      expect(await repo.getForEquipment('mine'), isEmpty);
    });
  });
}
