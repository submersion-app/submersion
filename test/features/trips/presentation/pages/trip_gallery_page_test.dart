import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/trips/presentation/pages/trip_gallery_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';

void main() {
  group('TripGalleryPage', () {
    testWidgets('shows app bar with title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaForTripProvider('test-trip').overrideWith((ref) {
              return Future.value(<Dive, List<MediaItem>>{});
            }),
          ],
          child: const MaterialApp(home: TripGalleryPage(tripId: 'test-trip')),
        ),
      );

      expect(find.text('Trip Photos'), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (tester) async {
      // Use a Completer to create a never-completing future without a timer
      final completer = Completer<Map<Dive, List<MediaItem>>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaForTripProvider('test-trip').overrideWith((ref) {
              return completer.future;
            }),
          ],
          child: const MaterialApp(home: TripGalleryPage(tripId: 'test-trip')),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the completer to clean up the test properly
      completer.complete(<Dive, List<MediaItem>>{});
    });

    testWidgets('shows error message when loading fails', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaForTripProvider('test-trip').overrideWith((ref) {
              throw Exception('Network error');
            }),
          ],
          child: const MaterialApp(home: TripGalleryPage(tripId: 'test-trip')),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Error loading photos'), findsOneWidget);
    });

    testWidgets('shows empty state when no photos', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaForTripProvider('test-trip').overrideWith((ref) {
              return Future.value(<Dive, List<MediaItem>>{});
            }),
          ],
          child: const MaterialApp(home: TripGalleryPage(tripId: 'test-trip')),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No photos in this trip'), findsOneWidget);
      expect(
        find.text('Tap the camera icon to scan your gallery'),
        findsOneWidget,
      );
    });

    testWidgets('shows camera icon button in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaForTripProvider('test-trip').overrideWith((ref) {
              return Future.value(<Dive, List<MediaItem>>{});
            }),
          ],
          child: const MaterialApp(home: TripGalleryPage(tripId: 'test-trip')),
        ),
      );

      expect(find.byIcon(Icons.photo_camera), findsOneWidget);
    });

    testWidgets('shows dive sections with photos', (tester) async {
      const testSite = DiveSite(id: 'site-1', name: 'Blue Corner');

      final testDive = Dive(
        id: 'dive-1',
        dateTime: DateTime(2024, 1, 15, 10, 30),
        diveNumber: 3,
        site: testSite,
      );

      final testMedia = MediaItem(
        id: 'media-1',
        diveId: 'dive-1',
        mediaType: MediaType.photo,
        takenAt: DateTime(2024, 1, 15, 10, 45),
        platformAssetId: 'asset-1',
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaForTripProvider('test-trip').overrideWith((ref) {
              return Future.value({
                testDive: [testMedia],
              });
            }),
            // Mock thumbnail provider to return empty bytes immediately
            assetThumbnailProvider('asset-1').overrideWith((ref) {
              return Future.value(Uint8List(0));
            }),
          ],
          child: const MaterialApp(home: TripGalleryPage(tripId: 'test-trip')),
        ),
      );

      await tester.pumpAndSettle();

      // Check for dive section title (dive number + site name)
      expect(find.text('Dive #3 - Blue Corner'), findsOneWidget);
      // Check for subtitle with date and photo count
      expect(find.textContaining('Jan 15'), findsOneWidget);
      expect(find.textContaining('1 photo'), findsOneWidget);
    });

    testWidgets('shows plural photos in subtitle when multiple', (
      tester,
    ) async {
      final testDive = Dive(
        id: 'dive-1',
        dateTime: DateTime(2024, 1, 15, 10, 30),
        diveNumber: 5,
      );

      final testMedia1 = MediaItem(
        id: 'media-1',
        diveId: 'dive-1',
        mediaType: MediaType.photo,
        takenAt: DateTime(2024, 1, 15, 10, 45),
        platformAssetId: 'asset-1',
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );

      final testMedia2 = MediaItem(
        id: 'media-2',
        diveId: 'dive-1',
        mediaType: MediaType.photo,
        takenAt: DateTime(2024, 1, 15, 10, 50),
        platformAssetId: 'asset-2',
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaForTripProvider('test-trip').overrideWith((ref) {
              return Future.value({
                testDive: [testMedia1, testMedia2],
              });
            }),
            // Mock thumbnail providers
            assetThumbnailProvider('asset-1').overrideWith((ref) {
              return Future.value(Uint8List(0));
            }),
            assetThumbnailProvider('asset-2').overrideWith((ref) {
              return Future.value(Uint8List(0));
            }),
          ],
          child: const MaterialApp(home: TripGalleryPage(tripId: 'test-trip')),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('2 photos'), findsOneWidget);
    });

    testWidgets('shows Unknown Site when dive has no site', (tester) async {
      final testDive = Dive(
        id: 'dive-1',
        dateTime: DateTime(2024, 1, 15, 10, 30),
        diveNumber: 1,
        // No site
      );

      final testMedia = MediaItem(
        id: 'media-1',
        diveId: 'dive-1',
        mediaType: MediaType.photo,
        takenAt: DateTime(2024, 1, 15, 10, 45),
        platformAssetId: 'asset-1',
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaForTripProvider('test-trip').overrideWith((ref) {
              return Future.value({
                testDive: [testMedia],
              });
            }),
            assetThumbnailProvider('asset-1').overrideWith((ref) {
              return Future.value(Uint8List(0));
            }),
          ],
          child: const MaterialApp(home: TripGalleryPage(tripId: 'test-trip')),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dive #1 - Unknown Site'), findsOneWidget);
    });

    testWidgets('uses GridView with 4 columns for thumbnails', (tester) async {
      final testDive = Dive(
        id: 'dive-1',
        dateTime: DateTime(2024, 1, 15, 10, 30),
        diveNumber: 1,
      );

      final testMedia = MediaItem(
        id: 'media-1',
        diveId: 'dive-1',
        mediaType: MediaType.photo,
        takenAt: DateTime(2024, 1, 15, 10, 45),
        platformAssetId: 'asset-1',
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaForTripProvider('test-trip').overrideWith((ref) {
              return Future.value({
                testDive: [testMedia],
              });
            }),
            assetThumbnailProvider('asset-1').overrideWith((ref) {
              return Future.value(Uint8List(0));
            }),
          ],
          child: const MaterialApp(home: TripGalleryPage(tripId: 'test-trip')),
        ),
      );

      await tester.pumpAndSettle();

      // Find the GridView and verify it uses a 4-column layout
      final gridView = find.byType(GridView);
      expect(gridView, findsOneWidget);

      final gridViewWidget = tester.widget<GridView>(gridView);
      final delegate =
          gridViewWidget.gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 4);
    });
  });
}
