import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/widgets/bulk_gear_sheet.dart';
import 'package:submersion/features/media/presentation/widgets/media_selection_bar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/selection/selection_controller.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The library selection bar offers Link to gear (issue #5046) after Edit
/// tags, for the photos and videos in the selection.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  MediaItem item(
    String id, {
    MediaType type = MediaType.photo,
    String? equipmentId,
  }) => MediaItem(
    id: id,
    equipmentId: equipmentId,
    mediaType: type,
    sourceType: MediaSourceType.platformGallery,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester, List<MediaItem> items) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = SelectionController()..enterExplicit();
    for (final i in items) {
      controller.toggle(i.id);
    }
    addTearDown(controller.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: MediaSelectionBar(
                controller: controller,
                selectableIds: [for (final i in items) i.id],
                selectedItems: items,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_overflow')));
    await tester.pumpAndSettle();
  }

  testWidgets('Link to gear sits after Edit tags and opens the bulk gear '
      'sheet', (tester) async {
    await pump(tester, [item('m1')]);

    final editTags = find.byKey(const ValueKey('selection_menu_edit_tags'));
    final linkGear = find.byKey(const ValueKey('selection_menu_link_gear'));
    expect(linkGear, findsOneWidget);
    expect(
      tester.getTopLeft(editTags).dy,
      lessThan(tester.getTopLeft(linkGear).dy),
    );

    await tester.tap(linkGear);
    await tester.pumpAndSettle();
    expect(find.byType(BulkGearSheet), findsOneWidget);
  });

  testWidgets('Link to gear is absent when the selection is only documents '
      'and gear photos', (tester) async {
    await pump(tester, [
      item('doc', type: MediaType.document),
      item('gear', equipmentId: 'e1'),
    ]);

    expect(
      find.byKey(const ValueKey('selection_menu_link_gear')),
      findsNothing,
    );
  });

  testWidgets('documents in a mixed selection are not linked', (tester) async {
    await pump(tester, [item('m1'), item('doc', type: MediaType.document)]);

    await tester.tap(find.byKey(const ValueKey('selection_menu_link_gear')));
    await tester.pumpAndSettle();

    expect(tester.widget<BulkGearSheet>(find.byType(BulkGearSheet)).mediaIds, [
      'm1',
    ]);
  });
}
