import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_map_point.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_place_strip.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_providers.dart';

MediaMapPoint _point(String id) => MediaMapPoint(
  entry: MediaLibraryEntry(
    item: MediaItem(
      id: id,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      platformAssetId: 'asset-$id',
      takenAt: DateTime(2026, 3, 12),
      createdAt: DateTime(2026, 3, 12),
      updatedAt: DateTime(2026, 3, 12),
    ),
  ),
  point: const LatLng(1, 2),
  placement: MediaPlacement.diveSite,
  placeLabel: 'Blue Hole',
);

void main() {
  testWidgets('shows the title, the count, and one tile per point; tapping '
      'a tile and the close button reach their callbacks', (tester) async {
    MediaMapPoint? tapped;
    var closed = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaStoreAttachedProvider.overrideWith((ref) async => true),
          mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
          mediaStoreIdentityProvider.overrideWith((ref) async => null),
          currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
          mediaServingRecorderProvider.overrideWithValue(
            MediaServingRecorder(),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: MediaPlaceStrip(
              title: 'Blue Hole',
              points: [_point('a'), _point('b'), _point('c')],
              onClose: () => closed++,
              onItemTap: (p) => tapped = p,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
    expect(find.byType(MediaItemView), findsNWidgets(3));

    await tester.tap(find.byKey(const ValueKey('media-place-strip-tile-b')));
    await tester.pumpAndSettle();
    expect(tapped?.item.id, 'b');

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(closed, 1);
  });

  testWidgets('a single item uses the singular count', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaStoreAttachedProvider.overrideWith((ref) async => true),
          mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
          mediaStoreIdentityProvider.overrideWith((ref) async => null),
          currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
          mediaServingRecorderProvider.overrideWithValue(
            MediaServingRecorder(),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: MediaPlaceStrip(
              title: '1.000000, 2.000000',
              points: [_point('a')],
              onClose: () {},
              onItemTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 item'), findsOneWidget);
  });
}
