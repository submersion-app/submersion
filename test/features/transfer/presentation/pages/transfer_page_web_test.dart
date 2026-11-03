import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/transfer/presentation/pages/transfer_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The phone-width transfer list in a browser (issue #4121): no dive
/// computers section, since a browser has no Bluetooth or USB to reach one.
void main() {
  Future<void> pumpList(WidgetTester tester, {bool browser = false}) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/transfer',
      routes: [
        GoRoute(
          path: '/transfer',
          builder: (context, state) => const TransferPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (browser)
            deviceCapabilitiesProvider.overrideWithValue(
              DeviceCapabilities.web,
            ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('natively the phone list offers dive computers', (tester) async {
    await pumpList(tester);
    expect(find.text('Dive Computers'), findsOneWidget);
  });

  testWidgets('a browser\'s phone list leaves dive computers out', (
    tester,
  ) async {
    await pumpList(tester, browser: true);
    expect(find.text('File Import'), findsOneWidget);
    expect(find.text('Dive Computers'), findsNothing);
  });
}
