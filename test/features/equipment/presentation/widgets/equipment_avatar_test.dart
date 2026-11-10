import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_avatar.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';

import '../../../media/presentation/support/media_widget_harness.dart';

/// The chosen cover photo stands for a gear item (issue #3355); without one,
/// or when it cannot be shown, the type icon does.
void main() {
  EquipmentItem reg({String? cover}) => EquipmentItem(
    id: 'reg-1',
    name: 'XTX50',
    type: EquipmentType.regulator,
    coverMediaId: cover,
  );

  final cover = testMediaItem(id: 'm1').copyWith(equipmentId: 'reg-1');

  Future<void> pump(
    WidgetTester tester,
    EquipmentItem item, {
    MediaItem? resolved,
  }) async {
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          if (item.coverMediaId case final coverId?)
            equipmentCoverProvider((
              equipmentId: 'reg-1',
              coverMediaId: coverId,
            )).overrideWith((ref) async => resolved),
        ],
        home: Scaffold(
          body: Center(child: EquipmentAvatar(item: item, radius: 20)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('no cover shows the type icon', (tester) async {
    await pump(tester, reg());

    expect(find.byIcon(equipmentTypeIcon(EquipmentType.regulator)), findsOne);
    expect(find.byType(MediaItemView), findsNothing);
  });

  testWidgets('cover shows the photo', (tester) async {
    await pump(tester, reg(cover: 'm1'), resolved: cover);

    expect(find.byType(MediaItemView), findsOneWidget);
    expect(
      find.byIcon(equipmentTypeIcon(EquipmentType.regulator)),
      findsNothing,
    );
  });

  testWidgets('dangling cover falls back to icon', (tester) async {
    await pump(tester, reg(cover: 'gone'));

    expect(find.byIcon(equipmentTypeIcon(EquipmentType.regulator)), findsOne);
    expect(find.byType(MediaItemView), findsNothing);
  });

  testWidgets('cover that fails to load falls back to icon', (tester) async {
    await pump(tester, reg(cover: 'm1'), resolved: cover);

    tester.widget<MediaItemView>(find.byType(MediaItemView)).onImageFailed!();
    await tester.pump();

    expect(find.byIcon(equipmentTypeIcon(EquipmentType.regulator)), findsOne);
    expect(find.byType(MediaItemView), findsNothing);
  });
}
