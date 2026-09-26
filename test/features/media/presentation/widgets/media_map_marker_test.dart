import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_map_marker.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_providers.dart';

MediaItem _item({MediaType type = MediaType.photo}) => MediaItem(
  id: 'm1',
  mediaType: type,
  sourceType: MediaSourceType.platformGallery,
  platformAssetId: 'asset-1',
  takenAt: DateTime(2026, 3, 12),
  createdAt: DateTime(2026, 3, 12),
  updatedAt: DateTime(2026, 3, 12),
);

Future<void> _pump(WidgetTester tester, Widget marker) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaStoreAttachedProvider.overrideWith((ref) async => true),
        mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
        mediaStoreIdentityProvider.overrideWith((ref) async => null),
        currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
        mediaServingRecorderProvider.overrideWithValue(MediaServingRecorder()),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: localizedMaterialApp(
        locale: const Locale('en'),
        home: Scaffold(body: Center(child: marker)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a plain marker is a 56dp thumbnail with no badge', (
    tester,
  ) async {
    await _pump(tester, MediaMapMarker(item: _item()));

    expect(find.byType(MediaItemView), findsOneWidget);
    expect(
      tester.getSize(find.byType(MediaMapMarker)),
      const Size(kMediaMapMarkerSize, kMediaMapMarkerSize),
    );
    expect(find.byKey(const ValueKey('media-map-cluster-badge')), findsNothing);
    expect(find.byIcon(Icons.play_circle_fill), findsNothing);
  });

  testWidgets('a cluster marker shows the count badge', (tester) async {
    await _pump(tester, MediaMapMarker(item: _item(), count: 12));

    expect(
      find.byKey(const ValueKey('media-map-cluster-badge')),
      findsOneWidget,
    );
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('a video marker carries the play glyph', (tester) async {
    await _pump(tester, MediaMapMarker(item: _item(type: MediaType.video)));

    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
  });
}
