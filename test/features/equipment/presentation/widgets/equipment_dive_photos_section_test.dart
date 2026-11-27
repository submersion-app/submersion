import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_dive_photos_list.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_dive_photos_page.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_dive_photos_section.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_gear_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../media/presentation/support/media_widget_harness.dart';

/// The gear page's In dive photos card (issue #5046): dive photos linked to
/// the item as showing it, apart from its own reference photos.
void main() {
  const drysuit = EquipmentItem(
    id: 'e1',
    name: 'Drysuit',
    type: EquipmentType.drysuit,
  );

  List<MediaItem> photos(int n) => [
    for (var i = 0; i < n; i++) testMediaItem(id: 'm$i', diveId: 'd1'),
  ];

  Future<void> pump(
    WidgetTester tester, {
    List<MediaItem> linked = const [],
    EditSession<EquipmentItem>? editing,
  }) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          linkedMediaForEquipmentProvider(
            'e1',
          ).overrideWith((ref) async => linked),
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: EquipmentDivePhotosSection(
              equipment: drysuit,
              editing: editing,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('card shows the empty invitation with no links', (tester) async {
    await pump(tester);
    expect(find.text('In dive photos'), findsOneWidget);
    expect(
      find.text('Link photos from your dives that show this item.'),
      findsOneWidget,
    );
    expect(find.byType(MediaThumbnailTile), findsNothing);
  });

  testWidgets('card shows at most eight tiles and Show all past that', (
    tester,
  ) async {
    await pump(tester, linked: photos(12));
    expect(find.byType(MediaThumbnailTile), findsNWidgets(8));
    await tester.tap(find.text('Show all (12)'));
    await tester.pumpAndSettle();
    expect(find.byType(EquipmentDivePhotosPage), findsOneWidget);
    expect(find.byType(MediaThumbnailTile), findsNWidgets(12));
  });

  testWidgets('Link photos and Unlink are offered only while the card is '
      'open', (tester) async {
    await pump(tester, linked: photos(2));
    expect(
      find.byKey(const ValueKey('equipment_divePhotos_link')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('equipment_divePhotos_unlink_m0')),
      findsNothing,
    );

    final session = EditSession<EquipmentItem>(drysuit);
    addTearDown(session.dispose);
    await pump(tester, linked: photos(2), editing: session);
    expect(
      find.byKey(const ValueKey('equipment_divePhotos_link')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('equipment_divePhotos_unlink_m0')),
      findsOneWidget,
    );
  });

  testWidgets('an unlink in the sitting hides the photo before Save', (
    tester,
  ) async {
    final session = EditSession<EquipmentItem>(drysuit);
    addTearDown(session.dispose);
    // The list as read from the store: both photos linked.
    gearItemDivePhotosList.loadNone(session);
    gearItemDivePhotosList.set(session, photos(2));
    await pump(tester, linked: photos(2), editing: session);

    await tester.tap(
      find.byKey(const ValueKey('equipment_divePhotos_unlink_m0')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MediaThumbnailTile), findsOneWidget);
    expect(
      [for (final m in gearItemDivePhotosList.current(session)!) m.id],
      ['m1'],
    );
  });
}
