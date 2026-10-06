import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/services/site_attachment_layout.dart';
import 'package:submersion/features/media/presentation/providers/pdf_preview_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/site_attachment_groups.dart';
import 'package:submersion/features/media/presentation/widgets/site_attachment_large_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';

import '../support/media_widget_harness.dart';

/// Issue #1039: a site's attachments in category groups.
void main() {
  late SelectionController selection;
  late List<String> opened;
  late List<String> edited;

  setUp(() {
    selection = SelectionController();
    opened = [];
    edited = [];
  });

  tearDown(() => selection.dispose());

  MediaItem m(String id, int minute, {SiteAttachmentCategory? category}) =>
      testMediaItem(
        id: id,
        siteId: 's1',
        originalFilename: '$id.png',
        takenAt: DateTime(2026, 3, 1, 9, minute),
      ).copyWith(siteCategory: category);

  Future<void> pump(WidgetTester tester, List<MediaItem> items) async {
    // Tall enough that a large card and the tiles under it are all on
    // screen, so taps land.
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          pdfLargePreviewProvider.overrideWith((ref, req) async => null),
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            // The section rebuilds on every selection change; so does this
            // host, as the section's ValueListenableBuilder does.
            child: ValueListenableBuilder<SelectionState>(
              valueListenable: selection,
              builder: (context, state, _) => SiteAttachmentGroups(
                layout: layoutSiteAttachments(items),
                selection: selection,
                isSelectionMode: state.isActive,
                settings: const AppSettings(),
                onOpen: (item) => opened.add(item.id),
                onEditDetails: (item) => edited.add(item.id),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uncategorized-only shows tiles and no headings', (tester) async {
    await pump(tester, [m('a', 1), m('b', 2)]);
    expect(find.byType(MediaThumbnailTile), findsNWidgets(2));
    expect(find.byType(SiteAttachmentLargeCard), findsNothing);
    expect(find.textContaining('Uncategorized'), findsNothing);
  });

  testWidgets('headings follow category order with counts', (tester) async {
    await pump(tester, [
      m('u', 1),
      m('w', 2, category: SiteAttachmentCategory.underwater),
      m('s', 3, category: SiteAttachmentCategory.siteMap),
    ]);
    final siteMap = tester.getTopLeft(find.text('Site map (1)')).dy;
    final underwater = tester.getTopLeft(find.text('Underwater (1)')).dy;
    final none = tester.getTopLeft(find.text('Uncategorized (1)')).dy;
    expect(siteMap, lessThan(underwater));
    expect(underwater, lessThan(none));
  });

  testWidgets('a site map renders large, underwater as a tile', (tester) async {
    await pump(tester, [
      m('s', 1, category: SiteAttachmentCategory.siteMap),
      m('w', 2, category: SiteAttachmentCategory.underwater),
    ]);
    expect(find.byType(SiteAttachmentLargeCard), findsOneWidget);
    expect(find.byType(MediaThumbnailTile), findsOneWidget);
  });

  testWidgets('outside selection, taps open and the menu edits', (
    tester,
  ) async {
    await pump(tester, [
      m('s', 1, category: SiteAttachmentCategory.siteMap),
      m('w', 2, category: SiteAttachmentCategory.underwater),
    ]);
    await tester.tap(find.byType(SiteAttachmentLargeCard));
    await tester.tap(find.byType(MediaThumbnailTile));
    expect(opened, ['s', 'w']);
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    expect(edited, ['s']);
  });

  testWidgets('selection can span a large card and a tile', (tester) async {
    await pump(tester, [
      m('s', 1, category: SiteAttachmentCategory.siteMap),
      m('w', 2, category: SiteAttachmentCategory.underwater),
    ]);
    selection.enterExplicit();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SiteAttachmentLargeCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnailTile));
    await tester.pumpAndSettle();
    expect(selection.value.checkedIds, {'s', 'w'});
    expect(opened, isEmpty);
  });

  testWidgets('a tile tap keeps the checks made in another group', (
    tester,
  ) async {
    await pump(tester, [
      m('w1', 1, category: SiteAttachmentCategory.underwater),
      m('u1', 2),
    ]);
    selection.enterExplicit();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnailTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MediaThumbnailTile).last);
    await tester.pumpAndSettle();
    expect(selection.value.checkedIds, {'w1', 'u1'});
  });
}
