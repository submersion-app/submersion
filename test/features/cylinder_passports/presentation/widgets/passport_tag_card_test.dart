import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart';
import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
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
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_nfc.dart';
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
    List<ServiceRecord> records = const [],
    FakeNfcTagService? nfc,
    Future<void> Function(BuildContext)? onPrintLabel,
  }) async {
    final overrides = await getBaseOverrides(nfcTagService: nfc);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          passportIdProvider(id).overrideWith((ref) async => pid),
          serviceClockStatusesProvider(id).overrideWith((ref) async => clocks),
          serviceRecordsForEquipmentProvider(
            id,
          ).overrideWith((ref) async => records),
        ],
        child: SingleChildScrollView(
          child: PassportTagCard(
            equipment: tank,
            scannedTag: scanned,
            onPrintLabel: onPrintLabel,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(PassportTagCard)));
  }

  ServiceRecord record(String kindId, DateTime date) => ServiceRecord(
    id: 'r-$kindId-${date.millisecondsSinceEpoch}',
    equipmentId: 'eq',
    serviceCategory: ServiceCategory.inspection,
    serviceKindId: kindId,
    serviceDate: date,
    createdAt: date,
    updatedAt: date,
  );

  test('currentPayloadFor never prints a clock fallback as a service', () {
    // Hydro and VIP auto-attach and anchor on the creation date when nothing
    // was ever recorded; the tag must say nothing rather than claim a test.
    final payload = currentPayloadFor(
      tank,
      passportId: pid,
      clocks: [hydro(DateTime(2026, 9, 1))],
      records: const [],
      now: now,
    );
    expect(payload!.lastHydro, isNull);
    expect(payload.lastVip, isNull);
    expect(payload.o2Clean, isFalse);
    expect(payload.writtenOn, now);
    expect(payload.volumeL, 12);
  });

  test('currentPayloadFor takes dates from service records', () {
    final payload = currentPayloadFor(
      tank,
      passportId: pid,
      clocks: [hydro(DateTime(2024, 6, 14))],
      records: [record('hydro', DateTime(2024, 6, 14))],
      now: now,
    );
    expect(payload!.lastHydro, DateTime(2024, 6, 14));
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

  testWidgets('a clock fallback never makes a tag stale', (tester) async {
    final l10n = await pump(
      tester,
      scanned: CylinderPassportPayload(
        passportId: pid,
        writtenOn: DateTime(2024, 1, 1),
      ),
      clocks: [hydro(DateTime(2026, 9, 1))],
    );
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
      records: [record('hydro', DateTime(2024, 6, 14))],
    );
    expect(find.text(l10n.passport_tag_stale), findsOneWidget);
    expect(find.text(l10n.passport_tag_written('Jan 1, 2024')), findsOneWidget);
  });

  testWidgets('Print label hands over the button, not the whole card', (
    tester,
  ) async {
    BuildContext? anchor;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          passportIdProvider(id).overrideWith((ref) async => pid),
          serviceClockStatusesProvider(id).overrideWith((ref) async => []),
        ],
        child: SingleChildScrollView(
          child: PassportTagCard(
            equipment: tank,
            onPrintLabel: (context) async => anchor = context,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportTagCard)),
    );
    final button = find.widgetWithText(
      FilledButton,
      l10n.passport_tag_printLabel,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    final box = anchor!.findRenderObject()! as RenderBox;
    expect(box.size, tester.getSize(button));
  });

  test('an NFC write starts from the full payload, the label from 160', () {
    // A long name in a script that percent-encodes to several characters
    // per glyph runs the label past its 160; the tag decides for itself.
    final longName = List.filled(30, 'Ω').join();
    final named = EquipmentItem(
      id: id,
      name: 'Faber 12',
      type: EquipmentType.tank,
      attributes: [
        ...tank.attributes,
        EquipmentAttribute(
          id: 'a4',
          equipmentId: id,
          key: EquipmentAttrKeys.identifier,
          valueText: longName,
        ),
      ],
    );
    final full = fullPayloadFor(
      named,
      passportId: pid,
      clocks: const [],
      records: const [],
      now: now,
    )!;
    final label = currentPayloadFor(
      named,
      passportId: pid,
      clocks: const [],
      records: const [],
      now: now,
    )!;
    expect(full.name, longName);
    expect(label, NdefFit.fitForLabel(full));
    expect(label.name, isNull);
  });

  testWidgets('Write NFC tag explains why it is off', (tester) async {
    final l10n = await pump(tester);
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(l10n.passport_nfc_write),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.text(l10n.passport_nfc_unsupported), findsOneWidget);
  });

  testWidgets('Write NFC tag writes the passport', (tester) async {
    final tag = FakeTagHandle();
    final l10n = await pump(tester, nfc: FakeNfcTagService(tag: tag));
    await tester.ensureVisible(find.byKey(const Key('passportTag_writeNfc')));
    await tester.tap(find.byKey(const Key('passportTag_writeNfc')));
    await tester.pumpAndSettle();
    expect(find.byType(NfcWriteSheet), findsOneWidget);
    expect(find.text(l10n.passport_nfc_written), findsOneWidget);
    expect(tag.writes, 1);
  });

  testWidgets('a stale tag offers Rewrite and Reprint', (tester) async {
    var printed = 0;
    final tag = FakeTagHandle();
    // Written for a 10 L cylinder; the row says 12 L, so the tag is stale.
    final l10n = await pump(
      tester,
      scanned: CylinderPassportPayload(
        passportId: pid,
        writtenOn: DateTime(2026, 1, 1),
        volumeL: 10,
      ),
      nfc: FakeNfcTagService(tag: tag),
      onPrintLabel: (_) async => printed++,
    );
    expect(find.text(l10n.passport_tag_stale), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('passportTag_reprint')));
    await tester.tap(find.byKey(const Key('passportTag_reprint')));
    await tester.pumpAndSettle();
    expect(printed, 1);
    await tester.tap(find.byKey(const Key('passportTag_rewrite')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_nfc_written), findsOneWidget);
    expect(tag.writes, 1);
  });
}
