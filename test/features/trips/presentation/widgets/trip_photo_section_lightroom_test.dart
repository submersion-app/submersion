import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_photo_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
    // Enabled so the scan-button wiring can be verified; the flag defaults to
    // false while Lightroom is pending Adobe review.
    lightroomUiEnabled = true;
  });
  tearDown(() async {
    lightroomUiEnabled = false;
    await tearDownTestDatabase();
  });

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onLightroomScanPressed,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TripPhotoSection(
                tripId: 't1',
                onScanPressed: () {},
                onLightroomScanPressed: onLightroomScanPressed,
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
  }

  testWidgets('shows the Lightroom scan button only when a handler is '
      'provided, and taps reach it', (tester) async {
    var taps = 0;
    await pump(tester, onLightroomScanPressed: () => taps++);

    final button = find.byTooltip('Scan Lightroom');
    expect(button, findsOneWidget);
    await tester.tap(button);
    expect(taps, 1);
  });

  testWidgets('hides the Lightroom scan button without a handler', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byTooltip('Scan Lightroom'), findsNothing);
  });

  testWidgets('hides the Lightroom scan button when lightroomUiEnabled is '
      'false even with a handler (pending Adobe review)', (tester) async {
    lightroomUiEnabled = false;
    await pump(tester, onLightroomScanPressed: () {});
    expect(find.byTooltip('Scan Lightroom'), findsNothing);
  });
}
