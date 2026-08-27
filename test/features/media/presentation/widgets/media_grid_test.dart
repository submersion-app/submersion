import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_media_placeholder.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../support/media_widget_harness.dart';

void main() {
  testWidgets('MediaEmptyState renders icon and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaEmptyState(icon: Icons.map_outlined, message: 'No media'),
        ),
      ),
    );
    expect(find.text('No media'), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
  });

  group('MediaThumbnailTile', () {
    Future<void> pumpTile(
      WidgetTester tester, {
      required MediaItem item,
      bool isSelectionMode = false,
      bool isSelected = false,
      MediaSourceData? resolverData,
    }) async {
      await tester.pumpWidget(
        await mediaTestApp(
          resolverData: resolverData,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: MediaThumbnailTile(
                  item: item,
                  settings: const AppSettings(),
                  isSelectionMode: isSelectionMode,
                  isSelected: isSelected,
                  semanticsLabel: 'Tile',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a plain photo renders through MediaItemView', (tester) async {
      await pumpTile(tester, item: testMediaItem());
      expect(find.byType(MediaItemView), findsOneWidget);
      expect(find.byType(OrphanedMediaPlaceholder), findsNothing);
      // No badges for an unselected, unenriched photo.
      expect(find.byIcon(Icons.videocam), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('an orphaned item shows the broken-image placeholder', (
      tester,
    ) async {
      await pumpTile(tester, item: testMediaItem(isOrphaned: true));
      expect(find.byType(OrphanedMediaPlaceholder), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      // The resolver is never consulted for an orphaned row.
      expect(find.byType(MediaItemView), findsNothing);
    });

    testWidgets('selection puts a checkmark on the tile', (tester) async {
      await pumpTile(
        tester,
        item: testMediaItem(),
        isSelectionMode: true,
        isSelected: true,
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('a video shows the videocam badge unless selected', (
      tester,
    ) async {
      final video = testMediaItem(
        mediaType: MediaType.video,
        originalFilename: 'dive.mp4',
      );
      await pumpTile(tester, item: video);
      expect(find.byIcon(Icons.videocam), findsOneWidget);

      // Selected: the checkmark owns the top-right slot instead.
      await pumpTile(
        tester,
        item: video,
        isSelectionMode: true,
        isSelected: true,
      );
      expect(find.byIcon(Icons.videocam), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('a document shows its uppercased extension badge', (
      tester,
    ) async {
      await pumpTile(
        tester,
        item: testMediaItem(
          mediaType: MediaType.document,
          originalFilename: 'reef-map.pdf',
        ),
      );
      expect(find.text('PDF'), findsOneWidget);
    });

    testWidgets('an extensionless document draws no empty badge', (
      tester,
    ) async {
      await pumpTile(
        tester,
        item: testMediaItem(
          mediaType: MediaType.document,
          originalFilename: 'README',
        ),
      );
      // Regression guard: the badge used to render as an empty black chip.
      expect(find.text(''), findsNothing);
    });

    testWidgets('an enriched photo shows the depth badge', (tester) async {
      const settings = AppSettings();
      final expected = const UnitFormatter(
        settings,
      ).formatDepth(18.0, decimals: 0);
      await pumpTile(
        tester,
        item: testMediaItem(
          enrichment: MediaEnrichment(
            id: 'e1',
            mediaId: 'm1',
            diveId: 'd1',
            depthMeters: 18.0,
            matchConfidence: MatchConfidence.exact,
            createdAt: DateTime(2026),
          ),
        ),
      );
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('an unresolvable item falls back to the placeholder', (
      tester,
    ) async {
      await pumpTile(
        tester,
        item: testMediaItem(),
        resolverData: const UnavailableData(kind: UnavailableKind.notFound),
      );
      expect(find.byType(UnavailableMediaPlaceholder), findsOneWidget);
    });
  });
}
