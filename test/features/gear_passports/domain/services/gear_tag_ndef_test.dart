import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_fit.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_ndef.dart';

const _id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

/// The NDEF message size a phone reports for each NTAG: user memory minus
/// the TLV wrapper and terminator.
int _reported(int bytes) => bytes - 3;

GearTagPayload _full({String name = 'Apeks XTX50 primary'}) => GearTagPayload(
  passportId: _id,
  typeCode: 'firstStage',
  writtenOn: DateTime(2026, 10, 10),
  name: name,
  brand: 'Apeks',
  model: 'XTX50',
  serial: 'AB12345',
  lastService: DateTime(2026, 3, 2),
);

void main() {
  test('drop order is ls, mo, b, sn, n', () {
    expect(GearTagFit.dropOrder, ['ls', 'mo', 'b', 'sn', 'n']);
    final p = _full();
    expect(GearTagFit.drop(p, 'ls').lastService, isNull);
    expect(GearTagFit.drop(p, 'mo').model, isNull);
    expect(GearTagFit.drop(p, 'b').brand, isNull);
    expect(GearTagFit.drop(p, 'sn').serial, isNull);
    expect(GearTagFit.drop(p, 'n').name, isNull);
    expect(GearTagFit.drop(p, 'zz'), p);
  });

  test('NTAG215 and NTAG216 keep everything, with the Android record', () {
    for (final size in [NdefFit.ntag215Bytes, NdefFit.ntag216Bytes]) {
      final plan = planGearMessage(_full(), maxMessageBytes: _reported(size))!;
      expect(plan.payload, _full());
      expect(plan.droppedKeys, isEmpty);
      expect(plan.includesAndroidRecord, isTrue);
      expect(plan.url, GearTagCodec.httpsUrl(_full()));
      expect(plan.includesFill, isFalse);
      expect(uriOf(plan.message.records.first), plan.url);
    }
  });

  test('NTAG213 keeps identity, type and name, dropping in order', () {
    final plan = planGearMessage(
      _full(),
      maxMessageBytes: _reported(NdefFit.ntag213Bytes),
    )!;
    expect(plan.payload.passportId, _id);
    expect(plan.payload.typeCode, 'firstStage');
    expect(plan.payload.writtenOn, DateTime(2026, 10, 10));
    expect(plan.payload.name, isNotNull);
    expect(plan.droppedKeys.first, 'ls');
    const order = GearTagFit.dropOrder;
    expect(
      plan.droppedKeys,
      order.sublist(0, plan.droppedKeys.length),
      reason: 'drops follow the fixed order',
    );
  });

  test('a long non-ASCII name still leaves identity and type on NTAG213', () {
    // Hebrew letters percent-encode to six characters each.
    final name = String.fromCharCodes(List.filled(40, 0x05D0));
    final plan = planGearMessage(
      _full(name: name),
      maxMessageBytes: _reported(NdefFit.ntag213Bytes),
    )!;
    expect(plan.payload.passportId, _id);
    expect(plan.payload.typeCode, 'firstStage');
    expect(plan.droppedKeys, contains('n'));
  });

  test('null when even the identity does not fit', () {
    expect(planGearMessage(_full(), maxMessageBytes: 40), isNull);
  });

  test('firstPassportUri finds a gear link', () {
    final plan = planGearMessage(_full(), maxMessageBytes: 500)!;
    expect(firstPassportUri(plan.message), plan.url);
  });

  group('labels (issue #2652)', () {
    test('a typical payload prints whole', () {
      expect(GearTagFit.fitForLabel(_full()), _full());
    });

    test('a long non-ASCII name drops keys until the link fits a label', () {
      final name = String.fromCharCodes(List.filled(40, 0x05D0));
      final fitted = GearTagFit.fitForLabel(_full(name: name));
      expect(
        GearTagCodec.httpsUrl(fitted).length,
        lessThanOrEqualTo(NdefFit.labelMaxUrlLength),
      );
      expect(fitted.passportId, _id);
      expect(fitted.typeCode, 'firstStage');
    });
  });

  test('the documented NTAG213 example drops ls and mo (137 bytes)', () {
    // Android reports 137 bytes of NDEF message for an NTAG213; the format
    // doc's worked example is computed at that size.
    final plan = planGearMessage(_full(), maxMessageBytes: 137)!;
    expect(plan.droppedKeys, ['ls', 'mo']);
    expect(plan.includesAndroidRecord, isFalse);
  });
}
