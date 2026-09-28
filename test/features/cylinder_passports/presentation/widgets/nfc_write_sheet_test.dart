import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_nfc.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final payload = CylinderPassportPayload(
    passportId: id,
    writtenOn: DateTime(2026, 9, 25),
    name: 'Club 10',
    serial: 'AB12345',
    volumeL: 10,
    workingPressureBar: 300,
    material: TankMaterial.steel,
  );

  /// Opens the sheet from a button; returns the strings.
  Future<AppLocalizations> open(
    WidgetTester tester,
    FakeNfcTagService nfc,
  ) async {
    final overrides = await getBaseOverrides(nfcTagService: nfc);
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNfcWriteSheet(context, payload: payload),
            child: const Text('open'),
          ),
        ),
      ),
    );
    final l10n = AppLocalizations.of(tester.element(find.text('open')));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('a written tag reports its type, capacity and what fit', (
    tester,
  ) async {
    final tag = FakeTagHandle();
    final l10n = await open(tester, FakeNfcTagService(tag: tag));
    expect(find.text(l10n.passport_nfc_written), findsOneWidget);
    expect(
      find.text(l10n.passport_nfc_tagInfo('NFC Forum Type 2', 496)),
      findsOneWidget,
    );
    expect(find.text(l10n.passport_nfc_allFields), findsOneWidget);
    expect(
      firstPassportUri(tag.stored!),
      PassportPayloadCodec.httpsUrl(payload),
    );
  });

  testWidgets('a small tag names what was left off', (tester) async {
    final tag = FakeTagHandle(maxMessageBytes: 100, typeLabel: null);
    final l10n = await open(tester, FakeNfcTagService(tag: tag));
    final plan = planPassportMessage(payload, maxMessageBytes: 100)!;
    final names = plan.droppedKeys
        .map((k) => tagFieldLabel(l10n, k))
        .join(', ');
    expect(find.text(l10n.passport_nfc_fieldsDropped(names)), findsOneWidget);
    expect(find.text(l10n.passport_nfc_capacity(100)), findsOneWidget);
  });

  testWidgets('a locked tag says so', (tester) async {
    final l10n = await open(
      tester,
      FakeNfcTagService(tag: FakeTagHandle(isWritable: false)),
    );
    expect(find.text(l10n.passport_nfc_readOnly), findsOneWidget);
    expect(find.text(l10n.passport_nfc_retry), findsOneWidget);
  });

  testWidgets('a tag that cannot hold a link says so', (tester) async {
    final l10n = await open(tester, FakeNfcTagService());
    expect(find.text(l10n.passport_nfc_notNdef), findsOneWidget);
  });

  testWidgets('a tag too small for the identity says so', (tester) async {
    final l10n = await open(
      tester,
      FakeNfcTagService(tag: FakeTagHandle(maxMessageBytes: 40)),
    );
    expect(find.text(l10n.passport_nfc_tooSmall(40)), findsOneWidget);
  });

  testWidgets('a failed write retries from the start', (tester) async {
    final tag = FakeTagHandle(writeError: PlatformException(code: 'io'));
    final nfc = FakeNfcTagService(tag: tag);
    final l10n = await open(tester, nfc);
    expect(find.text(l10n.passport_nfc_writeFailed), findsOneWidget);
    tag.writeError = null;
    await tester.tap(find.text(l10n.passport_nfc_retry));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_nfc_written), findsOneWidget);
    expect(nfc.sessions, 2);
    expect(tag.writes, 2);
  });

  testWidgets('closing the system sheet closes quietly', (tester) async {
    await open(tester, FakeNfcTagService(cancelled: true));
    expect(find.byType(NfcWriteSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
