import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/presentation/services/recent_passport_tags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
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

  testWidgets('the iOS sheet closes as the write ended', (tester) async {
    final locked = FakeNfcTagService(tag: FakeTagHandle(isWritable: false));
    final l10n = await open(tester, locked);
    expect(locked.lastIosEnd?.error, l10n.passport_nfc_readOnly);
    await tester.tap(find.text(l10n.common_action_close));
    await tester.pumpAndSettle();

    final good = FakeNfcTagService(tag: FakeTagHandle());
    await open(tester, good);
    expect(good.lastIosEnd?.alert, l10n.passport_nfc_written);
    expect(good.lastIosEnd?.error, isNull);
  });

  testWidgets('Cancel closes only the sheet', (tester) async {
    final nfc = FakeNfcTagService(tag: FakeTagHandle(), waitForCancel: true);
    final overrides = await getBaseOverrides(nfcTagService: nfc);
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Builder(
                    builder: (pageContext) => TextButton(
                      onPressed: () =>
                          showNfcWriteSheet(pageContext, payload: payload),
                      child: const Text('write'),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('passport'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('passport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('write'));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.text('write')));
    await tester.tap(find.text(l10n.common_action_cancel));
    await tester.pumpAndSettle();
    expect(find.byType(NfcWriteSheet), findsNothing);
    // The page under the sheet is still there.
    expect(find.text('write'), findsOneWidget);
    expect(nfc.cancels, 1);
  });

  testWidgets(
    'a tag written here is remembered, so its re-dispatch is dropped',
    (tester) async {
      await open(tester, FakeNfcTagService(tag: FakeTagHandle()));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NfcWriteSheet)),
      );
      expect(
        container
            .read(recentPassportTagsProvider)
            .wasJustHandled(PassportPayloadCodec.httpsUrl(payload)),
        isTrue,
      );
    },
  );

  testWidgets('a session that fails outright says the write failed', (
    tester,
  ) async {
    final nfc = FakeNfcTagService(
      tag: FakeTagHandle(),
      sessionError: PlatformException(code: 'session_already_exists'),
    );
    final l10n = await open(tester, nfc);
    expect(find.text(l10n.passport_nfc_writeFailed), findsOneWidget);
    expect(find.text(l10n.passport_nfc_retry), findsOneWidget);
  });

  testWidgets('Done closes the sheet after a write', (tester) async {
    final l10n = await open(tester, FakeNfcTagService(tag: FakeTagHandle()));
    await tester.tap(find.text(l10n.common_action_done));
    await tester.pumpAndSettle();
    expect(find.byType(NfcWriteSheet), findsNothing);
  });

  test('every key a small tag can drop has a readable name', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    for (final key in NdefFit.dropOrder) {
      final label = tagFieldLabel(l10n, key);
      expect(label, isNot(key), reason: key);
      expect(label, isNotEmpty, reason: key);
    }
  });
}
