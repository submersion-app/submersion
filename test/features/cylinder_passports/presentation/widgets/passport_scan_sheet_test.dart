import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:submersion/features/cylinder_passports/presentation/services/recent_passport_tags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_nfc.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  const tag =
      'https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

  /// Opens the sheet from a button and records what it returned.
  Future<List<String?>> openSheet(
    WidgetTester tester, {
    required PassportCameraBuilder? camera,
    FakeNfcTagService? nfc,
  }) async {
    final results = <String?>[];
    final overrides = await getBaseOverrides(nfcTagService: nfc);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          passportCameraProvider.overrideWithValue(camera),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                results.add(await showPassportScanSheet(context)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('the sheet closes once when the camera reports twice', (
    tester,
  ) async {
    final results = await openSheet(
      tester,
      camera: (context, onDetected) => TextButton(
        key: const Key('fakeDetect'),
        onPressed: () {
          onDetected(tag);
          onDetected(tag);
        },
        child: const Text('detect'),
      ),
    );
    await tester.tap(find.byKey(const Key('fakeDetect')));
    await tester.pumpAndSettle();
    expect(results, [tag]);
    // The host is still there: a second pop would have closed it too.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('without a camera the sheet says so and still takes a link', (
    tester,
  ) async {
    final results = await openSheet(tester, camera: null);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportScanSheet)),
    );
    expect(find.text(l10n.passport_scan_cameraUnavailable), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('passportScan_link')),
      '  $tag ',
    );
    await tester.tap(find.text(l10n.passport_scan_open));
    await tester.pumpAndSettle();
    expect(results, [tag]);
  });

  testWidgets('paste fills the link from the clipboard', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': tag};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final results = await openSheet(tester, camera: null);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportScanSheet)),
    );
    await tester.tap(find.byTooltip(l10n.passport_scan_paste));
    await tester.pumpAndSettle();
    expect(find.text(tag), findsOneWidget);
    await tester.tap(find.text(l10n.passport_scan_open));
    await tester.pumpAndSettle();
    expect(results, [tag]);
  });

  testWidgets('an empty link does not close the sheet', (tester) async {
    final results = await openSheet(tester, camera: null);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportScanSheet)),
    );
    await tester.tap(find.text(l10n.passport_scan_open));
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(find.byType(PassportScanSheet), findsOneWidget);
  });

  testWidgets('a clipboard that cannot be read leaves the sheet usable', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            throw PlatformException(code: 'clipboard_denied');
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await openSheet(tester, camera: null);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportScanSheet)),
    );
    await tester.tap(find.byTooltip(l10n.passport_scan_paste));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PassportScanSheet), findsOneWidget);
  });

  testWidgets('an NFC tap opens the tag it reads', (tester) async {
    final nfc = FakeNfcTagService(
      tag: FakeTagHandle(stored: NdefMessage(records: [uriRecord(tag)])),
    );
    final results = await openSheet(tester, camera: null, nfc: nfc);
    await tester.tap(find.byKey(const Key('passportScan_nfc')));
    await tester.pumpAndSettle();
    expect(results, [tag]);
  });

  testWidgets('a tag with no passport says so', (tester) async {
    final nfc = FakeNfcTagService(
      tag: FakeTagHandle(
        stored: NdefMessage(records: [uriRecord('https://example.com/')]),
      ),
    );
    final results = await openSheet(tester, camera: null, nfc: nfc);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportScanSheet)),
    );
    await tester.tap(find.byKey(const Key('passportScan_nfc')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_tag_linkInvalid), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('NFC turned off explains itself', (tester) async {
    await openSheet(
      tester,
      camera: null,
      nfc: FakeNfcTagService(supportValue: NfcSupport.disabled),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportScanSheet)),
    );
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text(l10n.passport_nfc_tap),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.text(l10n.passport_nfc_disabled), findsOneWidget);
  });

  testWidgets('closing the iOS sheet is quiet', (tester) async {
    final results = await openSheet(
      tester,
      camera: null,
      nfc: FakeNfcTagService(cancelled: true),
    );
    await tester.tap(find.byKey(const Key('passportScan_nfc')));
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(find.byType(PassportScanSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop offers no NFC', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await openSheet(tester, camera: null, nfc: FakeNfcTagService());
    expect(find.byKey(const Key('passportScan_nfc')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the iOS sheet closes as a failure for a tag with no passport', (
    tester,
  ) async {
    final nfc = FakeNfcTagService(
      tag: FakeTagHandle(
        stored: NdefMessage(records: [uriRecord('https://example.com/')]),
      ),
    );
    await openSheet(tester, camera: null, nfc: nfc);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportScanSheet)),
    );
    await tester.tap(find.byKey(const Key('passportScan_nfc')));
    await tester.pumpAndSettle();
    expect(nfc.lastIosEnd?.error, l10n.passport_tag_linkInvalid);
  });

  testWidgets('a tag read here is remembered, so its re-dispatch is dropped', (
    tester,
  ) async {
    final nfc = FakeNfcTagService(
      tag: FakeTagHandle(stored: NdefMessage(records: [uriRecord(tag)])),
    );
    await openSheet(tester, camera: null, nfc: nfc);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PassportScanSheet)),
    );
    await tester.tap(find.byKey(const Key('passportScan_nfc')));
    await tester.pumpAndSettle();
    expect(
      container.read(recentPassportTagsProvider).wasJustHandled(tag),
      isTrue,
    );
  });

  testWidgets('a tag that cannot be read says so', (tester) async {
    final nfc = FakeNfcTagService(
      tag: FakeTagHandle(readError: StateError('tag lost')),
    );
    final results = await openSheet(tester, camera: null, nfc: nfc);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportScanSheet)),
    );
    await tester.tap(find.byKey(const Key('passportScan_nfc')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_nfc_readFailed), findsOneWidget);
    expect(nfc.lastIosEnd?.error, l10n.passport_nfc_readFailed);
    expect(results, isEmpty);
  });

  testWidgets('a session that fails outright says the read failed', (
    tester,
  ) async {
    final nfc = FakeNfcTagService(sessionError: StateError('no session'));
    final results = await openSheet(tester, camera: null, nfc: nfc);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportScanSheet)),
    );
    await tester.tap(find.byKey(const Key('passportScan_nfc')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_nfc_readFailed), findsOneWidget);
    expect(results, isEmpty);
    // The button is usable again.
    expect(find.text(l10n.passport_nfc_tap), findsOneWidget);
  });

  testWidgets('the NFC button says to hold the tag near while it waits', (
    tester,
  ) async {
    final nfc = FakeNfcTagService(waitForCancel: true);
    await openSheet(tester, camera: null, nfc: nfc);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportScanSheet)),
    );
    await tester.tap(find.byKey(const Key('passportScan_nfc')));
    await tester.pump();
    expect(find.text(l10n.passport_nfc_holdNear), findsOneWidget);
    await nfc.cancel();
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_nfc_tap), findsOneWidget);
  });
}
