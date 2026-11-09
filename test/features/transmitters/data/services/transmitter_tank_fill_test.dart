import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_tank_fill.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// The fill an apply writes is the fill its preview counts (issue #4347).
void main() {
  DiveTank row({
    double? volume,
    String role = 'backGas',
    String? roleSource,
    String? name,
    double? workingPressure,
    String? material,
  }) => DiveTank(
    id: 'k1',
    diveId: 'd1',
    o2Percent: 21,
    hePercent: 0,
    tankOrder: 0,
    tankRole: role,
    volume: volume,
    roleSource: roleSource,
    tankName: name,
    workingPressure: workingPressure,
    tankMaterial: material,
  );

  final entry = Transmitter(
    id: 't1',
    transmitterSerial: '4A21F',
    label: 'Sidemount left',
    role: TankRole.sidemountLeft,
    volumeL: 10,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  test('fills an empty size', () {
    final fill = transmitterFillFor(row(), entry)!;

    expect(fill.volume, const Value(10.0));
  });

  test('keeps a size the cylinder already has', () {
    final fill = transmitterFillFor(row(volume: 12), entry)!;

    expect(fill.volume, const Value<double?>.absent());
  });

  test('replaces the back gas default with the entry role', () {
    final fill = transmitterFillFor(row(volume: 12), entry)!;

    expect(fill.tankRole, const Value('sidemountLeft'));
  });

  test('keeps a role the diver set', () {
    final fill = transmitterFillFor(row(role: 'stage', name: 'Stage'), entry)!;

    expect(fill.tankRole, const Value<String>.absent());
  });

  test('replaces a role read off the transmitter name and drops that '
      'source', () {
    final fill = transmitterFillFor(
      row(
        volume: 12,
        role: 'stage',
        roleSource: TankRoleSource.transmitterName.name,
        name: 'Left',
      ),
      entry,
    )!;

    expect(fill.tankRole, const Value('sidemountLeft'));
    expect(fill.roleSource, const Value<String?>(null));
  });

  test('returns null when the cylinder already has everything', () {
    final fill = transmitterFillFor(
      row(volume: 12, role: 'sidemountLeft', name: 'Left'),
      entry,
    );

    expect(fill, isNull);
  });
}
