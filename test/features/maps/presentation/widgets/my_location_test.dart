import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/maps/presentation/providers/device_location_provider.dart';
import 'package:submersion/features/maps/presentation/widgets/my_location_button.dart';
import 'package:submersion/features/maps/presentation/widgets/my_location_layer.dart';

import '../../../../helpers/test_app.dart';

/// A device that finds a fix at [latitude], [longitude] once [answer]
/// completes (at once by default), counting the requests.
class _FakeLocation implements LocationService {
  _FakeLocation({this.fix = true, Completer<void>? answer})
    : answer = answer ?? (Completer<void>()..complete());

  final bool fix;
  final Completer<void> answer;
  var requests = 0;
  var settingsOpened = 0;
  bool? geocodingAsked;

  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async {
    requests++;
    geocodingAsked = includeGeocoding;
    await answer.future;
    return fix
        ? const LocationResult(latitude: 17.3, longitude: -87.5, accuracy: 5)
        : null;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The blue dot, found by its accessible label.
final _dot = find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == 'Your location',
);

void main() {
  Future<List<LatLng>> pumpMap(
    WidgetTester tester,
    _FakeLocation location, {
    bool isPhone = true,
    bool askHost = false,
  }) async {
    final located = <LatLng>[];
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [locationServiceProvider.overrideWithValue(location)],
        child: Column(
          children: [
            MyLocationButton(
              onLocated: located.add,
              isPhone: askHost ? null : isPhone,
            ),
            const Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(15, -85),
                  initialZoom: 3,
                ),
                children: [MyLocationLayer()],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    return located;
  }

  testWidgets('shows no location dot before the button is pressed', (
    tester,
  ) async {
    await pumpMap(tester, _FakeLocation());

    expect(_dot, findsNothing);
    expect(find.byTooltip('Show my location'), findsOneWidget);
  });

  testWidgets('a fix moves the map to the device and drops the blue dot', (
    tester,
  ) async {
    final location = _FakeLocation();
    final located = await pumpMap(tester, location);

    await tester.tap(find.byTooltip('Show my location'));
    await tester.pumpAndSettle();

    expect(located, [const LatLng(17.3, -87.5)]);
    expect(location.geocodingAsked, isFalse);
    expect(_dot, findsOneWidget);
    // Display only: a site marker under the dot still takes the tap.
    expect(_dot.hitTestable(), findsNothing);
    final marker = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers
        .single;
    expect(marker.point, const LatLng(17.3, -87.5));
  });

  testWidgets('a second press while locating asks for no second fix', (
    tester,
  ) async {
    final answer = Completer<void>();
    final location = _FakeLocation(answer: answer);
    final located = await pumpMap(tester, location);

    await tester.tap(find.byTooltip('Show my location'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Says it is busy, so a screen reader announces more than the label.
    expect(find.byTooltip('Getting location...'), findsOneWidget);
    await tester.tap(find.byType(MyLocationButton));
    await tester.pump();

    answer.complete();
    await tester.pumpAndSettle();

    expect(location.requests, 1);
    expect(located, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byTooltip('Show my location'), findsOneWidget);
  });

  testWidgets('the dot lapses once the fix is too old to be where you are', (
    tester,
  ) async {
    await pumpMap(tester, _FakeLocation());

    await tester.tap(find.byTooltip('Show my location'));
    await tester.pumpAndSettle();
    expect(_dot, findsOneWidget);

    await tester.pump(
      DeviceLocationNotifier.maxAge - const Duration(seconds: 1),
    );
    expect(_dot, findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(_dot, findsNothing);
  });

  /// Brings the app back to the foreground at [now] on the wall clock.
  ///
  /// The app's timers stand still while it is suspended or the device
  /// sleeps, so only the wall clock shows how long it was away.
  void resumeAt(WidgetTester tester, DateTime now) {
    withClock(Clock.fixed(now), () {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  }

  testWidgets('a fix that went stale while the app slept is gone on return', (
    tester,
  ) async {
    await pumpMap(tester, _FakeLocation());
    await tester.tap(find.byTooltip('Show my location'));
    await tester.pumpAndSettle();
    expect(_dot, findsOneWidget);

    resumeAt(tester, clock.now().add(DeviceLocationNotifier.maxAge));
    await tester.pump();

    expect(_dot, findsNothing);
  });

  testWidgets('a short spell in the background keeps the dot', (tester) async {
    await pumpMap(tester, _FakeLocation());
    await tester.tap(find.byTooltip('Show my location'));
    await tester.pumpAndSettle();

    resumeAt(tester, clock.now().add(const Duration(minutes: 1)));
    await tester.pump();

    expect(_dot, findsOneWidget);
  });

  testWidgets('a fresh fix restarts the clock on the dot', (tester) async {
    await pumpMap(tester, _FakeLocation());

    await tester.tap(find.byTooltip('Show my location'));
    await tester.pumpAndSettle();
    await tester.pump(
      DeviceLocationNotifier.maxAge - const Duration(seconds: 1),
    );

    await tester.tap(find.byTooltip('Show my location'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    // The first fix's deadline has passed; the second's has not.
    expect(_dot, findsOneWidget);
  });

  testWidgets('no fix on a phone says so and offers the app settings', (
    tester,
  ) async {
    final location = _FakeLocation(fix: false);
    final located = await pumpMap(tester, location);

    await tester.tap(find.byTooltip('Show my location'));
    await tester.pumpAndSettle();

    expect(located, isEmpty);
    expect(_dot, findsNothing);
    expect(
      find.text('Unable to get location. Please check permissions.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(location.settingsOpened, 1);
  });

  testWidgets('no fix on a desktop says location may be unavailable', (
    tester,
  ) async {
    await pumpMap(tester, _FakeLocation(fix: false), isPhone: false);

    await tester.tap(find.byTooltip('Show my location'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to get location. Location services may not be available.',
      ),
      findsOneWidget,
    );
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('left to the host, a desktop test run gets the desktop message', (
    tester,
  ) async {
    // Tests run on a desktop host (Linux in CI, macOS locally), so the
    // button's own platform check must pick the desktop wording.
    await pumpMap(tester, _FakeLocation(fix: false), askHost: true);

    await tester.tap(find.byTooltip('Show my location'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unable to get location. Location services may not be available.',
      ),
      findsOneWidget,
    );
  });
}
