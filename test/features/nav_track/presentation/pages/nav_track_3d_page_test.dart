import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_3d_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

NavTrackPoint _p(
  int timestamp,
  double depth, {
  double? speed,
  double? temperature,
}) => NavTrackPoint(
  timestamp: timestamp,
  north: 0,
  east: 0,
  depth: depth,
  speed: speed,
  temperature: temperature,
);

NavTrack _route() => NavTrack(
  id: 'r1',
  source: NavTrackSource.seacraftEnc,
  startTime: 0,
  endTime: 20000,
  pointCount: 3,
  points: [
    _p(0, 0, speed: 1.0, temperature: 20),
    _p(10, 5, speed: 1.2, temperature: 18),
    _p(20, 10, speed: 0.9, temperature: 16),
  ],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          navTrackByIdProvider('r1').overrideWith((ref) async => _route()),
        ],
        child: const NavTrack3dPage(trackId: 'r1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('shows scene chrome once providers resolve', (tester) async {
    await pumpPage(tester);
    expect(find.byType(TimeScrubBar), findsOneWidget);
    // Depth, speed and temperature have samples; battery does not, so
    // only their chips render in the metric picker.
    expect(find.text('Depth'), findsWidgets);
    expect(find.text('Speed'), findsWidgets);
    expect(find.text('Temp'), findsWidgets);
    expect(find.text('Battery'), findsNothing);
  });

  testWidgets('play toggles to pause and back', (tester) async {
    await pumpPage(tester);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets(
    'Z menu lists None plus Z-capable metrics, temperature is the default',
    (tester) async {
      await pumpPage(tester);
      expect(find.text('Z axis: Temp'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('navTrack3dZAxisMenu')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // None, temperature, speed -- battery has no samples at all.
      expect(find.byType(CheckedPopupMenuItem<String>), findsNWidgets(3));
      await tester.tap(
        find.ancestor(
          of: find.text('None'),
          matching: find.byType(CheckedPopupMenuItem<String>),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Z axis: None'), findsOneWidget);
    },
  );
}
