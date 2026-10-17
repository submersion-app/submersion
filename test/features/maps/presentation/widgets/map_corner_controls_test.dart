import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/maps/presentation/widgets/map_corner_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/map_style_button.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  Future<void> pumpControls(
    WidgetTester tester, {
    MapController? controller,
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: Stack(
          children: [
            FlutterMap(
              mapController: controller,
              options: const MapOptions(
                initialCenter: LatLng(0, 0),
                initialZoom: 5,
              ),
              children: const [],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: MapCornerControls(controller: controller),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('without a controller shows only the map style button', (
    tester,
  ) async {
    await pumpControls(tester);

    expect(find.byType(MapStyleButton), findsOneWidget);
    expect(find.byType(MapCompassButton), findsNothing);
  });

  testWidgets('with a controller stacks the compass below the style button', (
    tester,
  ) async {
    await pumpControls(tester, controller: MapController());

    expect(find.byType(MapStyleButton), findsOneWidget);
    expect(find.byType(MapCompassButton), findsOneWidget);
    // The style button is always visible, so it takes the top slot; the
    // compass is hidden while north-up and must not leave a gap above it.
    expect(
      tester.getTopLeft(find.byType(MapStyleButton)).dy,
      lessThan(tester.getTopLeft(find.byType(MapCompassButton)).dy),
    );
  });
}
