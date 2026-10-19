import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/maps/presentation/pages/region_picker_page.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_style_button.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: base,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RegionPickerPage(),
        ),
      ),
    );

    // Avoid pumpAndSettle: the FlutterMap tile layer animates indefinitely.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('renders the RegionPickerPage FlutterMap', (tester) async {
    await pumpPage(tester);

    expect(find.byType(FlutterMap), findsWidgets);
  });

  testWidgets('offers the Move / Select toggle, zoom buttons and style', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byType(MapStyleButton), findsOneWidget);
  });

  testWidgets('starts in Move mode and switches to Select', (tester) async {
    await pumpPage(tester);

    SegmentedButton<bool> toggle() =>
        tester.widget(find.byType(SegmentedButton<bool>));
    expect(toggle().selected, {false});

    await tester.tap(find.byIcon(Icons.crop_free));
    await tester.pump();

    expect(toggle().selected, {true});
  });

  testWidgets('the map style button is anchored to the top-right corner', (
    tester,
  ) async {
    await pumpPage(tester);

    final map = tester.getRect(find.byType(FlutterMap));
    final button = tester.getRect(find.byType(MapStyleButton));

    expect(map.right - button.right, 16);
    expect(button.top - map.top, 16);
  });

  testWidgets('the map stops at the poles instead of showing grey', (
    tester,
  ) async {
    await pumpPage(tester);

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.cameraConstraint, worldMapCameraConstraint);
  });

  MapCamera camera(WidgetTester tester) =>
      MapCamera.of(tester.element(find.byType(MapAttribution)));

  Future<void> typeKey(
    WidgetTester tester,
    LogicalKeyboardKey key,
    String character, {
    bool shift = false,
    PhysicalKeyboardKey? physicalKey,
  }) async {
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(
      key,
      character: character,
      physicalKey: physicalKey,
    );
    await tester.sendKeyUpEvent(key, physicalKey: physicalKey);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }

  testWidgets('typing + with Shift and = zooms in', (tester) async {
    await pumpPage(tester);
    final before = camera(tester).zoom;

    // A US layout types "+" as Shift and the = key.
    await typeKey(tester, LogicalKeyboardKey.equal, '+', shift: true);

    expect(camera(tester).zoom, before + 1);
  });

  testWidgets('the + key and the numpad + zoom in by one step each', (
    tester,
  ) async {
    await pumpPage(tester);
    final before = camera(tester).zoom;

    // A German layout has "+" on its own key, right of the P row.
    await typeKey(
      tester,
      LogicalKeyboardKey.add,
      '+',
      physicalKey: PhysicalKeyboardKey.bracketRight,
    );
    expect(camera(tester).zoom, before + 1);

    await typeKey(tester, LogicalKeyboardKey.numpadAdd, '+');
    expect(camera(tester).zoom, before + 2);

    await typeKey(tester, LogicalKeyboardKey.minus, '-');
    await typeKey(tester, LogicalKeyboardKey.numpadSubtract, '-');
    expect(camera(tester).zoom, before);
  });

  testWidgets('the arrow keys still pan the map', (tester) async {
    await pumpPage(tester);
    final before = camera(tester).center.longitude;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(seconds: 1));

    expect(camera(tester).center.longitude, greaterThan(before));
  });

  testWidgets('a drag in Select mode draws a box and leaves the map still', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byIcon(Icons.crop_free));
    await tester.pump();
    final before = camera(tester).center;

    final centre = tester.getCenter(find.byType(FlutterMap));
    await tester.dragFrom(centre, const Offset(120, 80));
    await tester.pump();

    final select = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(select.onPressed, isNotNull);
    expect(camera(tester).center, before);
  });
}
