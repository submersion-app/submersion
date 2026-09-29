import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/write_fill_to_tag.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_nfc.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  const id = 'eq-1';
  const pid = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  const tank = EquipmentItem(
    id: id,
    name: 'Faber 12',
    type: EquipmentType.tank,
  );
  final at = DateTime.utc(2026, 9, 28, 9, 30);
  final newest = CylinderFill(
    id: '3f0c2b8e-6a1d-4c47-9e2a-5b7d8c9e0f11',
    passportId: pid,
    equipmentId: id,
    filledAt: at,
    o2Percent: 32,
    pressureBar: 232,
    createdAt: at,
    updatedAt: at,
  );

  List<Override> payloadOverrides(
    CylinderFill? fill, {
    Future<EquipmentItem?> Function()? item,
  }) => [
    equipmentItemProvider(
      id,
    ).overrideWith((ref) => (item ?? () async => tank)()),
    passportIdProvider(id).overrideWith((ref) async => pid),
    serviceClockStatusesProvider(id).overrideWith((ref) async => const []),
    serviceRecordsForEquipmentProvider(
      id,
    ).overrideWith((ref) async => const []),
    newestFillProvider(id).overrideWith((ref) async => fill),
  ];

  ProviderContainer container({CylinderFill? fill}) {
    final c = ProviderContainer(
      overrides: [
        equipmentItemProvider(id).overrideWith((ref) async => tank),
        passportIdProvider(id).overrideWith((ref) async => pid),
        serviceClockStatusesProvider(id).overrideWith((ref) async => const []),
        serviceRecordsForEquipmentProvider(
          id,
        ).overrideWith((ref) async => const []),
        newestFillProvider(id).overrideWith((ref) async => fill),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('an NFC write carries the newest fill', () async {
    final c = container(fill: newest);
    final sub = c.listen(tagPayloadProvider(id), (_, _) {});
    addTearDown(sub.close);
    final payload = await c.read(tagPayloadProvider(id).future);
    expect(payload!.passportId, pid);
    expect(payload.fill?.id, newest.id);
  });

  test('with no fills, the payload has no fill', () async {
    final c = container();
    final sub = c.listen(tagPayloadProvider(id), (_, _) {});
    addTearDown(sub.close);
    expect((await c.read(tagPayloadProvider(id).future))!.fill, isNull);
  });

  group('offerWriteFillToTag', () {
    setUp(() async {
      await setUpTestDatabase();
    });
    tearDown(tearDownTestDatabase);

    Future<AppLocalizations> pumpOffer(
      WidgetTester tester, {
      required NfcTagService nfc,
      Future<EquipmentItem?> Function()? item,
    }) async {
      final overrides = await getBaseOverrides(nfcTagService: nfc);
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            ...payloadOverrides(newest, item: item),
          ],
          child: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => offerWriteFillToTag(
                context,
                ref,
                equipmentId: id,
                fill: newest,
              ),
              child: const Text('offer'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.text('offer')));
      await tester.tap(find.text('offer'));
      await tester.pumpAndSettle();
      return l10n;
    }

    testWidgets('offers the fill, and Write to tag writes it', (tester) async {
      final nfc = FakeNfcTagService(waitForCancel: true);
      final l10n = await pumpOffer(tester, nfc: nfc);
      expect(find.text(l10n.passport_fill_writeToTagTitle), findsOneWidget);
      expect(find.textContaining('EAN32'), findsOneWidget);
      expect(find.textContaining('232 bar'), findsOneWidget);
      await tester.tap(find.text(l10n.passport_fill_writeToTag));
      await tester.pumpAndSettle();
      final sheet = tester.widget<NfcWriteSheet>(find.byType(NfcWriteSheet));
      expect(sheet.payload.fill?.id, newest.id);
      expect(nfc.sessions, 1);
    });

    testWidgets('Not now closes the offer and writes nothing', (tester) async {
      final nfc = FakeNfcTagService(waitForCancel: true);
      final l10n = await pumpOffer(tester, nfc: nfc);
      await tester.tap(find.text(l10n.passport_fill_notNow));
      await tester.pumpAndSettle();
      expect(find.text(l10n.passport_fill_writeToTagTitle), findsNothing);
      expect(find.byType(NfcWriteSheet), findsNothing);
      expect(nfc.sessions, 0);
    });

    testWidgets('a payload that fails to build says the write failed', (
      tester,
    ) async {
      final nfc = FakeNfcTagService(waitForCancel: true);
      final l10n = await pumpOffer(
        tester,
        nfc: nfc,
        item: () async => throw StateError('database is locked'),
      );
      await tester.tap(find.text(l10n.passport_fill_writeToTag));
      await tester.pumpAndSettle();
      expect(find.text(l10n.passport_nfc_writeFailed), findsOneWidget);
      expect(nfc.sessions, 0);
    });

    for (final support in [NfcSupport.disabled, NfcSupport.unsupported]) {
      testWidgets('NFC ${support.name}: no offer', (tester) async {
        final l10n = await pumpOffer(
          tester,
          nfc: FakeNfcTagService(supportValue: support),
        );
        expect(find.text(l10n.passport_fill_writeToTagTitle), findsNothing);
      });
    }

    testWidgets('a desktop: no offer', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final l10n = await pumpOffer(tester, nfc: FakeNfcTagService());
        expect(find.text(l10n.passport_fill_writeToTagTitle), findsNothing);
      } finally {
        // flutter_test checks this is reset inside the test body.
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
