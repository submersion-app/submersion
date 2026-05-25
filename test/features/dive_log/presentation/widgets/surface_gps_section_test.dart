import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_locations_map_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/surface_gps_section.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Dive _dive() => Dive(
  id: 'sgps',
  diveNumber: 1,
  dateTime: DateTime(2026, 5, 22, 9, 14),
  maxDepth: 30.0,
  entryLocation: const GeoPoint(12.34567, 98.76543),
  exitLocation: const GeoPoint(12.34612, 98.76489),
  site: const DiveSite(
    id: 'site-1',
    name: 'Blue Hole',
    location: GeoPoint(12.34000, 98.76000),
  ),
);

Future<void> _pump(WidgetTester tester, {MapController? controller}) async {
  final overrides = await getBaseOverrides();
  await tester.binding.setSurfaceSize(const Size(600, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    originalOnError?.call(d);
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        surfaceGpsSectionExpandedProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SurfaceGpsSection(dive: _dive(), controller: controller),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  FlutterError.onError = originalOnError;
}

void main() {
  testWidgets(
    'renders an interactive map and entry/exit/site coordinate rows',
    (tester) async {
      await _pump(tester);

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('12.34567, 98.76543'), findsOneWidget); // entry, 5 dp
      expect(find.text('12.34612, 98.76489'), findsOneWidget); // exit, 5 dp
      expect(find.text('12.34000, 98.76000'), findsOneWidget); // site, 5 dp
      expect(find.text('Open in Maps'), findsNothing);
    },
  );

  testWidgets('copy icon copies the coordinate at full (6-dp) precision', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('gps-copy-entry')));
    await tester.pump();

    final setData = calls.firstWhere((c) => c.method == 'Clipboard.setData');
    final text = (setData.arguments as Map)['text'] as String;
    expect(text, '12.345670, 98.765430');
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('tapping a coordinate recenters the map on that point', (
    tester,
  ) async {
    final controller = MapController();
    await _pump(tester, controller: controller);

    await tester.tap(find.byKey(const ValueKey('gps-coord-exit')));
    await tester.pump();

    expect(controller.camera.center.latitude, closeTo(12.34612, 1e-4));
    expect(controller.camera.center.longitude, closeTo(98.76489, 1e-4));
  });

  testWidgets('expand button opens the fullscreen locations page', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('gps-expand')));
    await tester.pumpAndSettle();

    expect(find.byType(DiveLocationsMapPage), findsOneWidget);
  });
}
