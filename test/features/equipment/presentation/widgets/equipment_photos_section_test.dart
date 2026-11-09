import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_photos_section.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';

import '../../../media/presentation/support/media_widget_harness.dart';

class _RecordingGearPhotos extends GearPhotoRepository {
  final covers = <(String, String?)>[];

  @override
  Future<void> setCover(String equipmentId, String? mediaId) async {
    covers.add((equipmentId, mediaId));
  }
}

class _RecordingUnlink extends MediaUnlinkService {
  _RecordingUnlink(this.calls)
    : super(repository: MediaRepository(), deleteMedia: (_) async {});

  final List<List<String>> calls;

  @override
  Future<EquipmentUnlinkOutcome> unlinkFromEquipment(
    List<String> mediaIds,
  ) async {
    calls.add(mediaIds);
    return EquipmentUnlinkOutcome(deleted: mediaIds.length, keptLinked: 0);
  }
}

/// The gear page's Photos card (issue #3355): reference shots of the item.
void main() {
  MediaItem photo(String id) => testMediaItem(
    id: id,
    originalFilename: '$id.jpg',
  ).copyWith(equipmentId: 'reg-1');

  EquipmentItem item({String? cover}) => EquipmentItem(
    id: 'reg-1',
    name: 'XTX50',
    type: EquipmentType.regulator,
    coverMediaId: cover,
  );

  Future<Widget> host({
    Object? error,
    List<MediaItem> photos = const [],
    String? cover,
    GearPhotoRepository? gearPhotos,
    List<List<String>>? unlinkCalls,
    DeviceCapabilities? capabilities,
  }) => mediaTestApp(
    overrides: [
      identificationPhotosProvider('reg-1').overrideWith((ref) async {
        if (error != null) throw error;
        return photos;
      }),
      if (gearPhotos != null)
        gearPhotoRepositoryProvider.overrideWithValue(gearPhotos),
      if (unlinkCalls != null)
        mediaUnlinkServiceProvider.overrideWithValue(
          _RecordingUnlink(unlinkCalls),
        ),
      if (capabilities != null)
        deviceCapabilitiesProvider.overrideWithValue(capabilities),
    ],
    home: Scaffold(
      body: SingleChildScrollView(
        child: EquipmentPhotosSection(equipment: item(cover: cover)),
      ),
    ),
  );

  testWidgets('shows identification photos', (tester) async {
    await tester.pumpWidget(await host(photos: [photo('m1'), photo('m2')]));
    await tester.pumpAndSettle();

    expect(find.text('Photos'), findsOneWidget);
    expect(find.byType(MediaThumbnailTile), findsNWidgets(2));
  });

  testWidgets('a failed read says so', (tester) async {
    await tester.pumpWidget(await host(error: StateError('disk gone')));
    await tester.pumpAndSettle();

    expect(find.text('Error loading media'), findsOneWidget);
    expect(find.byType(MediaThumbnailTile), findsNothing);
  });

  testWidgets('empty state text', (tester) async {
    await tester.pumpWidget(await host());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Add photos of this item, its serial number label or markings, '
        'for reference.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cover tile shows the badge', (tester) async {
    await tester.pumpWidget(
      await host(photos: [photo('m1'), photo('m2')], cover: 'm2'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cover_badge_m2')), findsOneWidget);
    expect(find.byKey(const ValueKey('cover_badge_m1')), findsNothing);
  });

  testWidgets('set cover from selection calls setCover', (tester) async {
    final gearPhotos = _RecordingGearPhotos();
    await tester.pumpWidget(
      await host(photos: [photo('m1'), photo('m2')], gearPhotos: gearPhotos),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnailTile).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_action_setCover')));
    await tester.pumpAndSettle();

    expect(gearPhotos.covers, [('reg-1', 'm2')]);
  });

  testWidgets('the cover photo offers to remove the cover', (tester) async {
    final gearPhotos = _RecordingGearPhotos();
    await tester.pumpWidget(
      await host(photos: [photo('m1')], cover: 'm1', gearPhotos: gearPhotos),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnailTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_action_setCover')));
    await tester.pumpAndSettle();

    expect(gearPhotos.covers, [('reg-1', null)]);
  });

  testWidgets('remove confirms then unlinks', (tester) async {
    final calls = <List<String>>[];
    await tester.pumpWidget(
      await host(photos: [photo('m1'), photo('m2')], unlinkCalls: calls),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnailTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_action_remove')));
    await tester.pumpAndSettle();
    expect(find.text('Remove 1 photo?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(calls, [
      ['m1'],
    ]);
  });

  testWidgets('no add or selection without mediaAttach', (tester) async {
    await tester.pumpWidget(
      await host(photos: [photo('m1')], capabilities: DeviceCapabilities.web),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MediaThumbnailTile), findsOneWidget);
    expect(find.byKey(const ValueKey('enter_selection')), findsNothing);
    expect(find.byKey(const ValueKey('equipment_photos_add')), findsNothing);
  });
}
