import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

void main() {
  final downloaded = GasSwitch(
    id: 'sw',
    diveId: 'd',
    timestamp: 600,
    tankId: 't',
    createdAt: DateTime.utc(2026, 10, 3),
    computerId: 'garmin',
  );

  group('appliesTo', () {
    test('a computer\'s own switch applies to it and to no other', () {
      expect(downloaded.appliesTo('garmin'), isTrue);
      expect(downloaded.appliesTo('suunto'), isFalse);
    });

    test('an unattributed switch applies to every computer', () {
      final entered = downloaded.copyWith(clearComputerId: true);
      expect(entered.appliesTo('garmin'), isTrue);
      expect(entered.appliesTo('suunto'), isTrue);
    });
  });

  group('copyWith', () {
    test('keeps the computer when none is given', () {
      expect(downloaded.copyWith(timestamp: 660).computerId, 'garmin');
    });

    test('clearComputerId makes the switch unattributed', () {
      expect(downloaded.copyWith(clearComputerId: true).computerId, isNull);
    });
  });
}
