import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/presentation/depth_overlay_toggle_button.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        bathymetryGridProvider.overrideWith((ref, cell) async => null),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DepthOverlayToggleButton(siteLocation: GeoPoint(10, 20)),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('toggles the synced appearance flag', (tester) async {
    final container = await pump(tester);
    expect(
      container.read(settingsProvider).seascapeAppearance.mapDepthOverlay,
      isFalse,
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.mapDepthOverlay,
      isTrue,
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.mapDepthOverlay,
      isFalse,
    );
  });

  testWidgets('enabling with a known-null grid shows the no-data notice', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump(); // let the null grid future resolve
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(
      find.text('No bathymetry available for this location'),
      findsOneWidget,
    );
  });
}
