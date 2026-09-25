import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_qr_view.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_tag_card.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  const id = 'eq-1';
  const pid = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final now = DateTime(2026, 9, 25);
  const tank = EquipmentItem(
    id: id,
    name: 'Faber 12',
    type: EquipmentType.tank,
    attributes: [
      EquipmentAttribute(
        id: 'a2',
        equipmentId: id,
        key: EquipmentAttrKeys.volumeL,
        valueNum: 12,
      ),
      EquipmentAttribute(
        id: 'a3',
        equipmentId: id,
        key: EquipmentAttrKeys.workingPressureBar,
        valueNum: 232,
      ),
    ],
  );

  ServiceClockStatus hydro(DateTime anchor) => ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's',
      equipmentId: id,
      serviceKindId: 'hydro',
      createdAt: now,
      updatedAt: now,
    ),
    kind: ServiceKind(
      id: 'hydro',
      name: 'Hydro',
      createdAt: now,
      updatedAt: now,
    ),
    anchor: anchor,
    severity: ServiceClockSeverity.ok,
    now: now,
  );

  setUp(() async => setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    CylinderPassportPayload? scanned,
    List<ServiceClockStatus> clocks = const [],
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          passportIdProvider(id).overrideWith((ref) async => pid),
          serviceClockStatusesProvider(id).overrideWith((ref) async => clocks),
        ],
        child: SingleChildScrollView(
          child: PassportTagCard(equipment: tank, scannedTag: scanned),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(PassportTagCard)));
  }

  test('currentPayloadFor takes dates from the clock anchors', () {
    final payload = currentPayloadFor(
      tank,
      passportId: pid,
      clocks: [hydro(DateTime(2024, 6, 14))],
      now: now,
    );
    expect(payload!.lastHydro, DateTime(2024, 6, 14));
    expect(payload.lastVip, isNull);
    expect(payload.o2Clean, isFalse);
    expect(payload.writtenOn, now);
    expect(payload.volumeL, 12);
  });

  testWidgets('shows the QR of the current payload and the actions', (
    tester,
  ) async {
    final l10n = await pump(tester);
    expect(find.byType(PassportQrView), findsOneWidget);
    expect(find.text(l10n.passport_tag_printLabel), findsOneWidget);
    expect(find.text(l10n.passport_tag_linkExisting), findsOneWidget);
    expect(find.text(l10n.passport_tag_stale), findsNothing);
  });

  testWidgets('a scanned tag older than the hydro is called stale', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      scanned: CylinderPassportPayload(
        passportId: pid,
        writtenOn: DateTime(2024, 1, 1),
      ),
      clocks: [hydro(DateTime(2024, 6, 14))],
    );
    expect(find.text(l10n.passport_tag_stale), findsOneWidget);
    expect(find.text(l10n.passport_tag_written('Jan 1, 2024')), findsOneWidget);
  });
}
