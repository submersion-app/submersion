import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/fake_path_provider.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';
import '../../helpers/fake_hosts.dart';

/// Sharing writes the plan to getApplicationDocumentsDirectory() first, a
/// platform channel with no implementation under flutter_test.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

/// Records what reached the platform so the iPad popover anchor can be
/// asserted without a real share sheet.
class _FakeSharePlatform extends SharePlatform {
  final List<ShareParams> calls = [];

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // PdfFonts downloads Roboto on first use. The font host answers as
  // offline, so the PDF falls back to Helvetica, as it would on a device
  // without a network, and its text stays readable for the assertions.
  setUp(() {
    serveFakeHost('fonts.gstatic.com');
  });

  late Directory documents;
  final sharePlatform = _FakeSharePlatform();

  // The harness pins a forwarder that looks the platform up on every share
  // (test/helpers/late_bound_share_platform.dart), so the fake comes out
  // again when this file is done.
  late SharePlatform originalSharePlatform;

  setUpAll(() {
    originalSharePlatform = SharePlatform.instance;
    SharePlatform.instance = sharePlatform;
  });
  tearDownAll(() => SharePlatform.instance = originalSharePlatform);

  setUp(() async {
    await setUpTestDatabase();
    documents = Directory.systemTemp.createTempSync('plan_canvas_share_test');
    useFakePathProvider(_FakePathProvider(documents.path));
    sharePlatform.calls.clear();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
    documents.deleteSync(recursive: true);
  });

  Widget harness() => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    locale: const Locale('en'),
    child: const PlanCanvasPage(),
  );

  /// Sharing writes with real dart:io, which parks under the FakeAsync zone
  /// testWidgets runs in. runAsync turns the real event loop so the write
  /// lands; the pump after it drains the continuation FakeAsync then queues.
  /// Neither alone gets as far as the share sheet.
  Future<void> settleRealIo(WidgetTester tester) async {
    for (var i = 0; i < 50 && sharePlatform.calls.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  Future<void> chooseFromOverflow(WidgetTester tester, String label) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
    await settleRealIo(tester);
  }

  testWidgets('sharing the plan file anchors to the app bar overflow button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // The overflow button is still mounted when the share sheet opens; the
    // menu item that was tapped is not.
    final overflowRect = tester.getRect(find.byType(PopupMenuButton<String>));

    await chooseFromOverflow(tester, 'Share plan file');

    expect(sharePlatform.calls.single.sharePositionOrigin, overflowRect);
  });

  testWidgets('exporting the slate PDF anchors to the same overflow button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final overflowRect = tester.getRect(find.byType(PopupMenuButton<String>));

    // The slate goes out through sharePdfBytes rather than saveAndShareFile,
    // a separate helper with its own optional anchor, so it needs its own
    // coverage.
    await chooseFromOverflow(tester, 'Export slate (PDF)');

    expect(sharePlatform.calls.single.sharePositionOrigin, overflowRect);
  });
}
