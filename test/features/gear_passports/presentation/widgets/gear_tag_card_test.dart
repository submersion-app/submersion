import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/gear_passports/presentation/widgets/gear_tag_card.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _item = EquipmentItem(
  id: 'reg',
  name: 'Primary',
  type: EquipmentType.regulator,
);

void main() {
  Future<OutlinedButton> pump(
    WidgetTester tester,
    Future<List<ServiceRecord>> records,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          passportIdProvider(
            _item.id,
          ).overrideWith((ref) async => '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab'),
          serviceRecordsForEquipmentProvider(
            _item.id,
          ).overrideWith((ref) => records),
          nfcSupportProvider.overrideWith((ref) async => NfcSupport.enabled),
        ],
        child: const SingleChildScrollView(
          child: GearTagCard(equipment: _item),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return tester.widget<OutlinedButton>(
      find.byKey(const Key('gearTag_writeNfc')),
    );
  }

  testWidgets('Write NFC tag waits for the service records', (tester) async {
    final button = await pump(tester, Completer<List<ServiceRecord>>().future);
    expect(button.onPressed, isNull);
  });

  testWidgets('Write NFC tag is ready once they load', (tester) async {
    final button = await pump(tester, Future.value(const <ServiceRecord>[]));
    expect(button.onPressed, isNotNull);
  });
}
