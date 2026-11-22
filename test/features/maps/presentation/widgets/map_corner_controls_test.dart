import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/maps/presentation/widgets/map_corner_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/map_style_button.dart';
import 'package:submersion/features/maps/presentation/widgets/my_location_button.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  Future<void> pumpControls(
    WidgetTester tester, {
    MapController? controller,
    ValueChanged<LatLng>? onLocated,
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
              child: MapCornerControls(
                controller: controller,
                onLocated: onLocated,
              ),
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
    expect(find.byType(MyLocationButton), findsNothing);
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

  testWidgets(
    'with onLocated puts Show my location between style and compass',
    (tester) async {
      await pumpControls(
        tester,
        controller: MapController(),
        onLocated: (_) {},
      );

      expect(find.byType(MyLocationButton), findsOneWidget);
      // Always visible, so it sits right under the style button; the compass,
      // hidden while north-up, keeps the bottom slot (#4808).
      final style = tester.getRect(find.byType(MapStyleButton));
      final locate = tester.getRect(find.byType(MyLocationButton));
      final compass = tester.getRect(find.byType(MapCompassButton));
      expect(locate.top, greaterThan(style.bottom));
      expect(compass.top, greaterThan(locate.bottom));
      expect(locate.size, style.size);
    },
  );
}
