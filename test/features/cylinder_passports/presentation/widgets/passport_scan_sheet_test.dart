import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  const tag =
      'https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

  /// Opens the sheet from a button and records what it returned.
  Future<List<String?>> openSheet(
    WidgetTester tester, {
    required PassportCameraBuilder? camera,
  }) async {
    final results = <String?>[];
    final overrides = await getBaseOverrides();
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
}
