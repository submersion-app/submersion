import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/gear_gallery_view.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';

import '../support/media_widget_harness.dart';

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

/// Media's Gear gallery (issue #3355): every gear photo, grouped by item.
void main() {
  MediaItem photo(String id, {String? observationId}) => testMediaItem(
    id: id,
    originalFilename: '$id.jpg',
  ).copyWith(equipmentId: 'reg-1', observationId: observationId);

  final groups = [
    GearPhotoGroup(
      equipmentId: 'reg-1',
      name: 'XTX50 regulator',
      items: [
        photo('m1'),
        photo('m2', observationId: 'obs-1'),
      ],
    ),
  ];

  Future<Widget> host({
    List<GearPhotoGroup> data = const [],
    List<List<String>>? unlinkCalls,
    void Function(String)? onOpenItem,
  }) => mediaTestApp(
    overrides: [
      gearGalleryProvider.overrideWith((ref) async => data),
      if (unlinkCalls != null)
        mediaUnlinkServiceProvider.overrideWithValue(
          _RecordingUnlink(unlinkCalls),
        ),
    ],
    home: Scaffold(body: GearGalleryView(onOpenItem: onOpenItem)),
  );

  testWidgets('gear tab is offered and shows groups', (tester) async {
    await tester.pumpWidget(await host(data: groups));
    await tester.pumpAndSettle();

    expect(find.text('XTX50 regulator'), findsOneWidget);
    expect(find.text('2 photos'), findsOneWidget);
    expect(find.byType(MediaThumbnailTile), findsNWidgets(2));
  });

  testWidgets('check-in photos carry the badge', (tester) async {
    await tester.pumpWidget(await host(data: groups));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('checkin_badge_m2')), findsOneWidget);
    expect(find.byKey(const ValueKey('checkin_badge_m1')), findsNothing);
  });

  testWidgets('header tap navigates to the item', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(await host(data: groups, onOpenItem: opened.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('XTX50 regulator'));
    await tester.pumpAndSettle();

    expect(opened, ['reg-1']);
  });

  testWidgets('remove unlinks selected photos', (tester) async {
    final calls = <List<String>>[];
    await tester.pumpWidget(await host(data: groups, unlinkCalls: calls));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnailTile).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_action_remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(calls, [
      ['m2'],
    ]);
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(await host());
    await tester.pumpAndSettle();

    expect(
      find.text('Photos you add to your gear and its check-ins show up here.'),
      findsOneWidget,
    );
  });
}
