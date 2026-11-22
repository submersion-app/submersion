import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
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
    Widget? section,
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
        child: section ?? EquipmentPhotosSection(equipment: item(cover: cover)),
      ),
    ),
  );

  /// The open Photos card's sitting (issue #4527, phase 3).
  EditSession<EquipmentItem> sitting({String? cover}) {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = EditSession(item(cover: cover));
    addTearDown(session.dispose);
    holdSittingMedia(
      session,
      SittingMediaWriters.forEquipment(container.read),
      cardId: 'photos',
    );
    return session;
  }

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

  testWidgets('a video is never offered as the cover', (tester) async {
    final video = testMediaItem(
      id: 'v1',
      originalFilename: 'v1.mov',
    ).copyWith(equipmentId: 'reg-1', mediaType: MediaType.video);
    await tester.pumpWidget(
      await host(
        photos: [photo('m1'), video],
        section: EquipmentPhotosSection(equipment: item(), editing: sitting()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnailTile).at(1));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('selection_action_setCover')),
      findsNothing,
    );
  });

  // Where the item page edits in place (issue #4527, phase 3).
  group('on a page that edits in place', () {
    testWidgets('locked, it offers no add and no selection', (tester) async {
      await tester.pumpWidget(
        await host(
          photos: [photo('m1')],
          section: EquipmentPhotosSection(equipment: item()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('equipment_photos_add')), findsNothing);
      expect(find.byKey(const ValueKey('enter_selection')), findsNothing);
    });

    testWidgets('removing the cover asks nothing, is held, and clears the '
        'cover in the sitting', (tester) async {
      final calls = <List<String>>[];
      final session = sitting(cover: 'm1');
      await tester.pumpWidget(
        await host(
          photos: [photo('m1'), photo('m2')],
          unlinkCalls: calls,
          section: EquipmentPhotosSection(
            equipment: item(cover: 'm1'),
            editing: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MediaThumbnailTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_action_remove')));
      await tester.pumpAndSettle();

      expect(find.text('Remove 1 photo?'), findsNothing);
      expect(calls, isEmpty);
      expect(sittingMedia(session).unlinked, {'m1'});
      expect(session.working.coverMediaId, isNull);
      expect(find.byType(MediaThumbnailTile), findsOneWidget);
    });

    testWidgets('a second cover choice in the sitting moves the badge, and '
        'choosing it again clears it', (tester) async {
      final session = sitting();
      await tester.pumpWidget(
        await host(
          photos: [photo('m1'), photo('m2')],
          section: EquipmentPhotosSection(equipment: item(), editing: session),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> toggleCover(int index) async {
        await tester.tap(find.byKey(const ValueKey('enter_selection')));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(MediaThumbnailTile).at(index));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('selection_action_setCover')),
        );
        await tester.pumpAndSettle();
      }

      await toggleCover(0);
      await toggleCover(1);
      expect(session.working.coverMediaId, 'm2');
      expect(find.byKey(const ValueKey('cover_badge_m2')), findsOneWidget);
      expect(find.byKey(const ValueKey('cover_badge_m1')), findsNothing);

      await toggleCover(1);
      expect(session.working.coverMediaId, isNull);
    });

    testWidgets('choosing the cover is held, not written', (tester) async {
      final gearPhotos = _RecordingGearPhotos();
      final session = sitting();
      await tester.pumpWidget(
        await host(
          photos: [photo('m1'), photo('m2')],
          gearPhotos: gearPhotos,
          section: EquipmentPhotosSection(equipment: item(), editing: session),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MediaThumbnailTile).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_action_setCover')));
      await tester.pumpAndSettle();

      expect(gearPhotos.covers, isEmpty);
      expect(session.working.coverMediaId, 'm2');
      expect(session.changedCardIds, {'photos'});
    });
  });

  testWidgets('the open card offers no add or selection without mediaAttach', (
    tester,
  ) async {
    await tester.pumpWidget(
      await host(
        photos: [photo('m1')],
        capabilities: DeviceCapabilities.web,
        section: EquipmentPhotosSection(equipment: item(), editing: sitting()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MediaThumbnailTile), findsOneWidget);
    expect(find.byKey(const ValueKey('enter_selection')), findsNothing);
    expect(find.byKey(const ValueKey('equipment_photos_add')), findsNothing);
  });
}
