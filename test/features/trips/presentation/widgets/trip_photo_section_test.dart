import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_photo_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('TripPhotoSection', () {
    testWidgets('shows empty state when no photos', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaCountForTripProvider('empty-trip').overrideWith((ref) {
              return Future.value(0);
            }),
            flatMediaListForTripProvider('empty-trip').overrideWith((ref) {
              return Future.value(<MediaItem>[]);
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: TripPhotoSection(tripId: 'empty-trip')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No photos yet'), findsOneWidget);
    });

    testWidgets('shows photo count in header', (tester) async {
      final testMedia = [
        _createTestMedia('1'),
        _createTestMedia('2'),
        _createTestMedia('3'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaCountForTripProvider('test-trip').overrideWith((ref) {
              return Future.value(3);
            }),
            flatMediaListForTripProvider('test-trip').overrideWith((ref) {
              return Future.value(testMedia);
            }),
            // Mock thumbnail provider to return placeholder bytes
            assetThumbnailProvider('asset-1').overrideWith((ref) {
              return Future.value(_createPlaceholderImage());
            }),
            assetThumbnailProvider('asset-2').overrideWith((ref) {
              return Future.value(_createPlaceholderImage());
            }),
            assetThumbnailProvider('asset-3').overrideWith((ref) {
              return Future.value(_createPlaceholderImage());
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: TripPhotoSection(tripId: 'test-trip')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show Photos header with count badge
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows scan button in empty state', (tester) async {
      bool scanPressed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaCountForTripProvider('empty-trip').overrideWith((ref) {
              return Future.value(0);
            }),
            flatMediaListForTripProvider('empty-trip').overrideWith((ref) {
              return Future.value(<MediaItem>[]);
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TripPhotoSection(
                tripId: 'empty-trip',
                onScanPressed: () => scanPressed = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the scan button
      final scanButton = find.text('Scan device gallery');
      expect(scanButton, findsOneWidget);

      await tester.tap(scanButton);
      expect(scanPressed, isTrue);
    });

    testWidgets('shows camera icon button in header when photos exist', (
      tester,
    ) async {
      final testMedia = [_createTestMedia('1')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaCountForTripProvider('test-trip').overrideWith((ref) {
              return Future.value(1);
            }),
            flatMediaListForTripProvider('test-trip').overrideWith((ref) {
              return Future.value(testMedia);
            }),
            assetThumbnailProvider('asset-1').overrideWith((ref) {
              return Future.value(_createPlaceholderImage());
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: TripPhotoSection(tripId: 'test-trip')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show camera icon in header
      expect(find.byIcon(Icons.photo_camera), findsOneWidget);
    });

    testWidgets('shows View All button when photos exist', (tester) async {
      final testMedia = [_createTestMedia('1')];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaCountForTripProvider('test-trip').overrideWith((ref) {
              return Future.value(1);
            }),
            flatMediaListForTripProvider('test-trip').overrideWith((ref) {
              return Future.value(testMedia);
            }),
            assetThumbnailProvider('asset-1').overrideWith((ref) {
              return Future.value(_createPlaceholderImage());
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: TripPhotoSection(tripId: 'test-trip')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('View All'), findsOneWidget);
    });

    testWidgets('shows +N indicator when more than 5 photos', (tester) async {
      final testMedia = List.generate(8, (i) => _createTestMedia('${i + 1}'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaCountForTripProvider('test-trip').overrideWith((ref) {
              return Future.value(8);
            }),
            flatMediaListForTripProvider('test-trip').overrideWith((ref) {
              return Future.value(testMedia);
            }),
            // Override thumbnail provider for first 5 assets
            assetThumbnailProvider('asset-1').overrideWith((ref) {
              return Future.value(_createPlaceholderImage());
            }),
            assetThumbnailProvider('asset-2').overrideWith((ref) {
              return Future.value(_createPlaceholderImage());
            }),
            assetThumbnailProvider('asset-3').overrideWith((ref) {
              return Future.value(_createPlaceholderImage());
            }),
            assetThumbnailProvider('asset-4').overrideWith((ref) {
              return Future.value(_createPlaceholderImage());
            }),
            assetThumbnailProvider('asset-5').overrideWith((ref) {
              return Future.value(_createPlaceholderImage());
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: TripPhotoSection(tripId: 'test-trip')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show +3 indicator for remaining photos
      expect(find.text('+3'), findsOneWidget);
    });

    testWidgets('shows loading indicator while fetching', (tester) async {
      // Use Completers that never complete to keep the providers in loading state
      final countCompleter = Completer<int>();
      final listCompleter = Completer<List<MediaItem>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaCountForTripProvider('test-trip').overrideWith((ref) {
              return countCompleter.future;
            }),
            flatMediaListForTripProvider('test-trip').overrideWith((ref) {
              return listCompleter.future;
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: TripPhotoSection(tripId: 'test-trip')),
          ),
        ),
      );

      // Don't settle - check immediately for loading state
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

MediaItem _createTestMedia(String id) {
  return MediaItem(
    id: 'media-$id',
    platformAssetId: 'asset-$id',
    mediaType: MediaType.photo,
    takenAt: DateTime(2024, 1, 15, 10, 0),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

Uint8List _createPlaceholderImage() {
  // Minimal valid 1x1 PNG image
  return Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A, // PNG signature
    0x00,
    0x00,
    0x00,
    0x0D, // IHDR chunk length
    0x49,
    0x48,
    0x44,
    0x52, // IHDR
    0x00,
    0x00,
    0x00,
    0x01, // width: 1
    0x00,
    0x00,
    0x00,
    0x01, // height: 1
    0x08,
    0x02, // bit depth: 8, color type: 2 (RGB)
    0x00,
    0x00,
    0x00, // compression, filter, interlace
    0x90,
    0x77,
    0x53,
    0xDE, // CRC
    0x00,
    0x00,
    0x00,
    0x0C, // IDAT chunk length
    0x49,
    0x44,
    0x41,
    0x54, // IDAT
    0x08,
    0xD7,
    0x63,
    0xF8,
    0xCF,
    0xC0,
    0x00,
    0x00, // compressed data
    0x00,
    0x03,
    0x00,
    0x01, // compressed data
    0x00,
    0x18,
    0xDD,
    0x8D,
    0xB4, // CRC
    0x00,
    0x00,
    0x00,
    0x00, // IEND chunk length
    0x49,
    0x45,
    0x4E,
    0x44, // IEND
    0xAE,
    0x42,
    0x60,
    0x82, // CRC
  ]);
}
