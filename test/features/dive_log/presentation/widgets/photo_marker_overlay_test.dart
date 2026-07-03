import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_overlay.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

PhotoChartMarker _marker({
  String id = 'm1',
  int seconds = 500,
  double depth = 25.0,
  MediaType type = MediaType.photo,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return PhotoChartMarker(
    item: MediaItem(
      id: id,
      diveId: 'dive-1',
      mediaType: type,
      takenAt: now,
      createdAt: now,
      updatedAt: now,
    ),
    elapsedSeconds: seconds,
    depthMeters: depth,
  );
}

Widget _overlay({
  required List<PhotoChartMarker> markers,
  double visibleMinSeconds = 0,
  double visibleMaxSeconds = 1000,
  void Function(MediaItem item)? onOpenPhoto,
}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: PhotoMarkerOverlay(
            markers: markers,
            visibleMinSeconds: visibleMinSeconds,
            visibleMaxSeconds: visibleMaxSeconds,
            visibleMinDepth: 0,
            visibleMaxDepth: 50,
            insets: (left: 30, top: 0, right: 30, bottom: 36),
            units: const UnitFormatter(AppSettings()),
            onOpenPhoto: onOpenPhoto,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders one chip per well-separated marker', (tester) async {
    await tester.pumpWidget(
      _overlay(
        markers: [
          _marker(id: 'a', seconds: 100),
          _marker(id: 'b', seconds: 800),
        ],
      ),
    );
    expect(find.byIcon(Icons.camera_alt), findsNWidgets(2));
  });

  testWidgets('shows a count badge for clustered markers', (tester) async {
    await tester.pumpWidget(
      _overlay(
        markers: [
          _marker(id: 'a', seconds: 500),
          _marker(id: 'b', seconds: 510),
          _marker(id: 'c', seconds: 520),
        ],
      ),
    );
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('tapping a chip opens the preview card; tapping away closes it', (
    tester,
  ) async {
    await tester.pumpWidget(_overlay(markers: [_marker()]));
    expect(find.byKey(const ValueKey('photoMarkerCard')), findsNothing);

    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pump();
    expect(find.byKey(const ValueKey('photoMarkerCard')), findsOneWidget);
    // Caption shows depth in the diver's units and runtime as m:ss.
    expect(find.textContaining('8:20'), findsOneWidget);

    await tester.tapAt(const Offset(390, 10));
    await tester.pump();
    expect(find.byKey(const ValueKey('photoMarkerCard')), findsNothing);
  });

  testWidgets('tapping the card thumbnail reports the photo', (tester) async {
    MediaItem? opened;
    await tester.pumpWidget(
      _overlay(markers: [_marker()], onOpenPhoto: (item) => opened = item),
    );
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('photoMarkerCardThumb-m1')));
    await tester.pump();
    expect(opened?.id, 'm1');
  });

  testWidgets('cluster card shows one thumbnail per member', (tester) async {
    await tester.pumpWidget(
      _overlay(
        markers: [
          _marker(id: 'a', seconds: 500),
          _marker(id: 'b', seconds: 510),
        ],
      ),
    );
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('photoMarkerCardThumb-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('photoMarkerCardThumb-b')),
      findsOneWidget,
    );
  });

  testWidgets('viewport change dismisses the preview card', (tester) async {
    await tester.pumpWidget(_overlay(markers: [_marker()]));
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pump();
    expect(find.byKey(const ValueKey('photoMarkerCard')), findsOneWidget);

    // Simulate a zoom: the visible window changes.
    await tester.pumpWidget(
      _overlay(
        markers: [_marker()],
        visibleMinSeconds: 200,
        visibleMaxSeconds: 900,
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('photoMarkerCard')), findsNothing);
  });

  testWidgets('video markers show a videocam icon', (tester) async {
    await tester.pumpWidget(
      _overlay(
        markers: [_marker(id: 'v1', type: MediaType.video)],
      ),
    );
    expect(find.byIcon(Icons.videocam), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsNothing);
  });

  testWidgets('all-video cluster shows the videocam icon with a count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _overlay(
        markers: [
          _marker(id: 'v1', seconds: 500, type: MediaType.video),
          _marker(id: 'v2', seconds: 510, type: MediaType.video),
        ],
      ),
    );
    expect(find.byIcon(Icons.videocam), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('mixed photo and video cluster shows the camera icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      _overlay(
        markers: [
          _marker(id: 'p1', seconds: 500),
          _marker(id: 'v1', seconds: 510, type: MediaType.video),
        ],
      ),
    );
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.byIcon(Icons.videocam), findsNothing);
  });

  testWidgets('markers outside the visible window render nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _overlay(
        markers: [_marker(seconds: 100)],
        visibleMinSeconds: 400,
        visibleMaxSeconds: 900,
      ),
    );
    expect(find.byIcon(Icons.camera_alt), findsNothing);
  });
}
