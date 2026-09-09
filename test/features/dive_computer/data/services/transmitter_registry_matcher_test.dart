import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_computer/data/services/transmitter_registry_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

Transmitter _entry({
  String id = 'e1',
  String? serial = '180777',
  String? computerId,
  int? channel,
  TankRole role = TankRole.oxygenSupply,
  double? volumeL = 2.0,
  double? workingPressureBar = 232,
  TankMaterial? material = TankMaterial.steel,
  String? presetName,
  String? equipmentId = 'g1',
  String label = 'O2',
  DateTime? updatedAt,
}) => Transmitter(
  id: id,
  transmitterSerial: serial,
  diveComputerId: computerId,
  channelIndex: channel,
  label: label,
  role: role,
  volumeL: volumeL,
  workingPressureBar: workingPressureBar,
  material: material,
  presetName: presetName,
  equipmentId: equipmentId,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: updatedAt ?? DateTime.utc(2026, 9, 1),
);

void main() {
  test('a serial match applies role, gear, name and fills empty specs', () {
    final matcher = TransmitterMatcher.fromEntries([_entry()]);
    const tank = TankData(
      index: 0,
      o2Percent: 100,
      startPressure: 200,
      endPressure: 170,
      transmitterSerial: '180777',
      role: 'backGas',
    );

    final out = applyTransmitterRegistry([tank], matcher, computerId: 'c1');

    expect(out.single.role, 'oxygenSupply');
    expect(out.single.equipmentId, 'g1');
    expect(out.single.tankName, 'O2');
    expect(out.single.volumeLiters, 2.0);
    expect(out.single.workingPressure, 232);
    expect(out.single.material, 'steel');
    expect(out.single.startPressure, 200, reason: 'pressures untouched');
    expect(out.single.o2Percent, 100, reason: 'gas untouched');
  });

  test('a serial padded with whitespace still matches', () {
    final matcher = TransmitterMatcher.fromEntries([_entry()]);
    const tank = TankData(
      index: 0,
      o2Percent: 21,
      transmitterSerial: ' 180777 ',
    );

    final out = applyTransmitterRegistry([tank], matcher, computerId: null);

    expect(out.single.role, 'oxygenSupply');
  });

  test('a computer-reported volume is kept over the entry', () {
    final matcher = TransmitterMatcher.fromEntries([_entry()]);
    const tank = TankData(
      index: 0,
      o2Percent: 21,
      volumeLiters: 12,
      transmitterSerial: '180777',
    );

    final out = applyTransmitterRegistry([tank], matcher, computerId: null);

    expect(out.single.volumeLiters, 12);
    expect(out.single.role, 'oxygenSupply');
  });

  test('the (computer, channel) fallback matches only that computer', () {
    final matcher = TransmitterMatcher.fromEntries([
      _entry(
        serial: null,
        computerId: 'c1',
        channel: 1,
        role: TankRole.diluent,
      ),
    ]);
    const tank = TankData(index: 1, o2Percent: 21);

    expect(
      applyTransmitterRegistry([tank], matcher, computerId: 'c1').single.role,
      'diluent',
    );
    expect(
      applyTransmitterRegistry([tank], matcher, computerId: 'c2').single.role,
      isNull,
    );
  });

  test('the serial wins over a conflicting channel entry', () {
    final matcher = TransmitterMatcher.fromEntries([
      _entry(id: 'a', serial: '180777', role: TankRole.oxygenSupply),
      _entry(
        id: 'b',
        serial: null,
        computerId: 'c1',
        channel: 0,
        role: TankRole.deco,
      ),
    ]);
    const tank = TankData(index: 0, o2Percent: 21, transmitterSerial: '180777');

    final out = applyTransmitterRegistry([tank], matcher, computerId: 'c1');

    expect(out.single.role, 'oxygenSupply');
  });

  test('two tanks on one serial (Teric twins) both get the entry', () {
    final matcher = TransmitterMatcher.fromEntries([_entry()]);
    const tanks = [
      TankData(index: 0, o2Percent: 31, transmitterSerial: '180777'),
      TankData(index: 1, o2Percent: 32, transmitterSerial: '180777'),
    ];

    final out = applyTransmitterRegistry(tanks, matcher, computerId: null);

    expect(out.map((t) => t.role), ['oxygenSupply', 'oxygenSupply']);
  });

  test('an unmatched tank is returned unchanged', () {
    final matcher = TransmitterMatcher.fromEntries([_entry()]);
    const tank = TankData(index: 0, o2Percent: 21, transmitterSerial: '999');

    final out = applyTransmitterRegistry([tank], matcher, computerId: null);

    expect(out.single, same(tank));
  });

  test('the most recently updated duplicate wins', () {
    final matcher = TransmitterMatcher.fromEntries([
      _entry(
        id: 'old',
        role: TankRole.deco,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      _entry(
        id: 'new',
        role: TankRole.stage,
        updatedAt: DateTime.utc(2026, 2, 1),
      ),
    ]);

    expect(
      matcher.match(serial: '180777', computerId: null, index: 0)!.id,
      'new',
    );
  });

  test('equal timestamps break the tie on id, whatever the input order', () {
    final same = DateTime.utc(2026, 3, 1);
    final a = _entry(id: 'a', role: TankRole.deco, updatedAt: same);
    final b = _entry(id: 'b', role: TankRole.stage, updatedAt: same);

    expect(
      TransmitterMatcher.fromEntries([
        a,
        b,
      ]).match(serial: '180777', computerId: null, index: 0)!.id,
      'b',
    );
    expect(
      TransmitterMatcher.fromEntries([
        b,
        a,
      ]).match(serial: '180777', computerId: null, index: 0)!.id,
      'b',
    );
  });

  test('an empty matcher is a no-op', () {
    const tank = TankData(index: 0, o2Percent: 21, transmitterSerial: '180777');
    final out = applyTransmitterRegistry(
      [tank],
      const TransmitterMatcher.empty(),
      computerId: null,
    );
    expect(out.single, same(tank));
  });
}
