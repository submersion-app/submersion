import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';

/// Expects the one [FlutterMap] on screen to zoom and scroll the way the
/// app's other maps do (issue #3664): the same zoom range, a stop at the
/// poles with endless east-west scrolling, pinches that do not twist the
/// map, and trackpad zoom.
void expectZoomsAndScrollsLikeOtherMaps(WidgetTester tester) {
  final mapFinder = find.byType(FlutterMap);
  final options = tester.widget<FlutterMap>(mapFinder).options;
  expect(options.minZoom, 2.0, reason: 'zooms out no further than the world');
  expect(options.maxZoom, 18.0, reason: 'zooms in no further than the tiles');
  expect(options.cameraConstraint, worldMapCameraConstraint);
  expect(options.interactionOptions, rotatableMapInteraction);
  final trackpad = find.ancestor(
    of: mapFinder,
    matching: find.byType(TrackpadZoomMap),
  );
  expect(
    trackpad,
    findsOneWidget,
    reason: 'a two-finger trackpad gesture zooms the map',
  );
  // The wrapper clamps on its own before moving the camera. Wider bounds
  // than the map's let it pivot toward a zoom the map then refuses, which
  // slides the map sideways at either end of its range.
  final wrapper = tester.widget<TrackpadZoomMap>(trackpad);
  expect(wrapper.minZoom, options.minZoom);
  expect(wrapper.maxZoom, options.maxZoom);
}
