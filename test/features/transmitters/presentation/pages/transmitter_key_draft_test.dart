import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_key_draft.dart';

/// The transmitter key editor's draft, and the key its Save writes (issue
/// #4527, phase 4): a stored key keeps every value whose text the diver
/// left alone, as stored at Save.
void main() {
  const metric = AppSettings();
  const imperial = AppSettings(
    volumeUnit: VolumeUnit.cubicFeet,
    pressureUnit: PressureUnit.psi,
  );
  final then = DateTime.utc(2026, 9, 1);
  final now = DateTime.utc(2026, 11, 22);

  TransmitterKeyDraft draft({
    String serial = '804512',
    String? computerId,
    String channel = '',
    TankRole role = TankRole.backGas,
    String? cylinderId = 'cyl-1',
    String? presetName,
    String volume = '12',
    String pressure = '232',
    TankMaterial? material,
  }) => (
    serial: serial,
    computerId: computerId,
    channel: channel,
    role: role,
    cylinderId: cylinderId,
    presetName: presetName,
    volume: volume,
    pressure: pressure,
    material: material,
    configured: true,
  );

  final stored = Transmitter(
    id: 'k1',
    diverId: 'diver-1',
    transmitterSerial: '804512',
    label: 'Old label',
    role: TankRole.backGas,
    volumeL: 11.1,
    workingPressureBar: 207,
    equipmentId: 'cyl-1',
    transmitterEquipmentId: 'tx-gear',
    isConfigured: false,
    createdAt: then,
    updatedAt: then,
  );

  Transmitter save({
    required TransmitterKeyDraft form,
    TransmitterKeyDraft? start,
    Transmitter? from,
    AppSettings settings = metric,
  }) => transmitterKeyToSave(
    draft: form,
    start: start,
    stored: from,
    id: 'new-id',
    diverId: 'diver-1',
    itemId: 'tx-gear',
    itemName: 'Back gas tx',
    settings: settings,
    now: now,
  );

  test('a new key takes every field from the draft', () {
    final key = save(
      form: draft(
        serial: ' 804512 ',
        role: TankRole.stage,
        presetName: 'al80',
        material: TankMaterial.aluminum,
      ),
    );

    expect(key.id, 'new-id');
    expect(key.diverId, 'diver-1');
    expect(key.transmitterSerial, '804512');
    expect(key.role, TankRole.stage);
    expect(key.equipmentId, 'cyl-1');
    expect(key.presetName, 'al80');
    expect(key.volumeL, 12);
    expect(key.workingPressureBar, 232);
    expect(key.material, TankMaterial.aluminum);
    expect(key.transmitterEquipmentId, 'tx-gear');
    expect(key.createdAt, now);
  });

  test('an untouched volume in cuft keeps the stored litres', () {
    // 11.1 L at 207 bar shows as 77 cuft at 3002 psi.
    final start = draft(volume: '77.1', pressure: '3002');
    final key = save(
      form: draft(volume: '77.1', pressure: '3002', role: TankRole.stage),
      start: start,
      from: stored,
      settings: imperial,
    );

    expect(key.volumeL, 11.1);
    expect(key.workingPressureBar, 207);
    expect(key.role, TankRole.stage);
  });

  test('a pressure change in cuft recomputes the volume', () {
    final start = draft(volume: '77.1', pressure: '3002');
    final key = save(
      form: draft(volume: '77.1', pressure: '3442'),
      start: start,
      from: stored,
      settings: imperial,
    );

    final bar = key.workingPressureBar!;
    expect(bar, closeTo(237.3, 0.1));
    expect(key.volumeL, closeTo(77.1 * 28.3168 / bar, 1e-9));
  });

  test('a cuft size with no working pressure is read at the assumed one', () {
    // As the app shows a tank with no pressure: at 200 bar.
    final key = save(
      form: draft(volume: '80', pressure: ''),
      settings: imperial,
    );

    expect(key.workingPressureBar, isNull);
    expect(key.volumeL, closeTo(80 * 28.3168 / 200, 1e-9));
  });

  test('a changed role keeps a serial changed in storage meanwhile', () {
    final start = draft();
    final key = save(
      form: draft(role: TankRole.sidemountLeft),
      start: start,
      from: stored.copyWith(transmitterSerial: '999999'),
    );

    expect(key.transmitterSerial, '999999');
    expect(key.role, TankRole.sidemountLeft);
    expect(key.volumeL, 11.1);
    expect(key.id, 'k1');
    expect(key.createdAt, then);
  });

  test('a channel with no computer is no channel', () {
    final key = save(form: draft(channel: '2'));

    expect(key.diveComputerId, isNull);
    expect(key.channelIndex, isNull);
  });

  test('a channel with a computer is stored from zero', () {
    final key = save(
      form: draft(serial: '', computerId: 'dc', channel: '2'),
    );

    expect(key.transmitterSerial, isNull);
    expect(key.diveComputerId, 'dc');
    expect(key.channelIndex, 1);
  });

  test('the saved key is labelled with the item name and configured', () {
    final key = save(form: draft(), start: draft(), from: stored);

    expect(key.label, 'Back gas tx');
    expect(key.isConfigured, isTrue);
    expect(key.updatedAt, now);
  });

  test('a draft names a key by its serial, or a computer and channel', () {
    expect(transmitterDraftNamesKey(draft()), isTrue);
    expect(transmitterDraftNamesKey(draft(serial: '  ')), isFalse);
    expect(
      transmitterDraftNamesKey(
        draft(serial: '', computerId: 'dc', channel: '1'),
      ),
      isTrue,
    );
    expect(
      transmitterDraftNamesKey(
        draft(serial: '', computerId: 'dc', channel: '0'),
      ),
      isFalse,
    );
    expect(transmitterDraftNamesKey(draft(serial: '', channel: '1')), isFalse);
  });
}
