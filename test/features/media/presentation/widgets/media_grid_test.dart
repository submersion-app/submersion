import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/unavailable_media_placeholder.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../support/capturing_media_repository.dart';
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
      List<Override> overrides = const [],
      Size? targetSize,
      ValueChanged<Size>? onImageSize,
    }) async {
      await tester.pumpWidget(
        await mediaTestApp(
          resolverData: resolverData,
          overrides: overrides,
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
                  targetSize: targetSize ?? const Size(200, 200),
                  onImageSize: onImageSize,
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
      // No badges for an unselected, unenriched photo.
      expect(find.byIcon(Icons.videocam), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('decodes at 200 x 200 unless told otherwise', (tester) async {
      await pumpTile(tester, item: testMediaItem());
      final view = tester.widget<MediaItemView>(find.byType(MediaItemView));
      expect(view.targetSize, const Size(200, 200));
      expect(view.onImageSize, isNull);
    });

    testWidgets('forwards its decode size and size callback to the view', (
      tester,
    ) async {
      void onImageSize(Size _) {}
      await pumpTile(
        tester,
        item: testMediaItem(),
        targetSize: const Size(400, 400),
        onImageSize: onImageSize,
      );
      final view = tester.widget<MediaItemView>(find.byType(MediaItemView));
      expect(view.targetSize, const Size(400, 400));
      expect(view.onImageSize, same(onImageSize));
    });

    testWidgets('an orphaned item still renders through MediaItemView', (
      tester,
    ) async {
      // The persisted flag is a claim from an earlier verification, possibly
      // made on a device that never had the file. The tile lets the resolver
      // chain (origin, then media store) try anyway, so a photo the flag
      // calls missing draws its thumbnail whenever anything can serve it
      // (#1409).
      final repository = CapturingMediaRepository();
      await pumpTile(
        tester,
        item: testMediaItem(isOrphaned: true),
        overrides: [mediaRepositoryProvider.overrideWithValue(repository)],
      );
      expect(find.byType(MediaItemView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MediaItemView),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      expect(find.byType(UnavailableMediaPlaceholder), findsNothing);
      // Bytes came from the row's own source, so the stale flag is corrected
      // in place instead of staying red until the viewer happens to open.
      expect(repository.writes, [(id: 'm1', isOrphaned: false)]);
    });

    testWidgets('an orphaned item nothing can serve shows the missing tile', (
      tester,
    ) async {
      await pumpTile(
        tester,
        item: testMediaItem(isOrphaned: true),
        resolverData: const UnavailableData(kind: UnavailableKind.notFound),
      );
      expect(find.byType(MediaItemView), findsOneWidget);
      expect(find.byType(UnavailableMediaPlaceholder), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
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
