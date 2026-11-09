import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_prefs_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_layers_button.dart';

import 'species_map_harness.dart';

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(SpeciesMapLayersButton)),
);

void main() {
  testWidgets('the public switch reads off by default and turns on', (
    tester,
  ) async {
    await tester.pumpWidget(
      await speciesMapHarness(child: const SpeciesMapLayersButton()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SpeciesMapLayersButton));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('species_map_public_toggle'));
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(
      find.text(
        "Sends the picked species, or the tapped site's location, to GBIF.",
      ),
      findsOneWidget,
    );

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(_container(tester).read(speciesMapPublicLayerProvider), isTrue);
  });

  testWidgets('the scope choice changes the expected scope', (tester) async {
    await tester.pumpWidget(
      await speciesMapHarness(child: const SpeciesMapLayersButton()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SpeciesMapLayersButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('species_map_scope_allVisible')),
    );
    await tester.pumpAndSettle();

    expect(
      _container(tester).read(speciesMapExpectedScopeProvider),
      ExpectedSiteScope.allVisible,
    );
  });

  testWidgets('the menu fits a 320 point wide phone', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      await speciesMapHarness(
        child: const Align(
          alignment: Alignment.topRight,
          child: SpeciesMapLayersButton(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SpeciesMapLayersButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final toggle = find.byKey(const ValueKey('species_map_public_toggle'));
    expect(tester.getRect(toggle).left, greaterThanOrEqualTo(0));
    expect(tester.getRect(toggle).right, lessThanOrEqualTo(320));
  });
}
