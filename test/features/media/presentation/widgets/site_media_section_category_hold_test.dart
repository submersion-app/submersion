import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/providers/media_learned_aspect_provider.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/site_media_section.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../support/media_widget_harness.dart';

/// The site page's bulk Set category in the open attachments card: held in
/// the site's sitting until Save, discarded by Cancel (issue #4527, media
/// library plan 2). A locked page offers none (site_media_section_test).
void main() {
  const site = DiveSite(id: 'site-1', name: 'Salt Pier');
  final photos = [
    testMediaItem(
      id: 'm1',
      siteId: 'site-1',
      originalFilename: 'entry.png',
      takenAt: DateTime(2026, 3, 1, 9),
    ),
    testMediaItem(
      id: 'm2',
      siteId: 'site-1',
      originalFilename: 'mooring.png',
      takenAt: DateTime(2026, 3, 1, 10),
    ),
  ];

  late List<String> written;
  late RecordEditController<DiveSite> controller;

  setUp(() {
    written = [];
    controller = RecordEditController<DiveSite>(onSave: (_) async {});
  });
  tearDown(() => controller.dispose());

  EditSession<DiveSite> openCard() {
    final session = EditSession<DiveSite>(site);
    addTearDown(() {
      if (!session.isDisposed) session.dispose();
    });
    holdSittingMedia(
      session,
      SittingMediaWriters(
        writeRows: (_) async => const [],
        insertNetwork: (_) async => const [],
        unlink: (_) async {},
        replace: (_, _, _) async {},
        drainDeletes: () async {},
        enqueueUpload: (_) {},
        setCategories: (categories) async => written.addAll([
          for (final e in categories.entries) '${e.key}:${e.value?.name}',
        ]),
      ),
      cardId: 'media',
    );
    return session;
  }

  /// The card on a page that edits in place; with [editing], the open card.
  /// No notifier is overridden: a held write must never reach one.
  Future<Widget> card({EditSession<DiveSite>? editing}) => mediaTestApp(
    overrides: [
      mediaAspectCacheRepositoryProvider.overrideWithValue(
        FakeAspectCacheRepository(),
      ),
      mediaForSiteProvider('site-1').overrideWith((ref) async => photos),
      mediaCountFromDivesAtSiteProvider(
        'site-1',
      ).overrideWith((ref) async => 0),
      flatMediaFromDivesAtSiteProvider(
        'site-1',
      ).overrideWith((ref) async => const <MediaItem>[]),
    ],
    home: Scaffold(
      body: SingleChildScrollView(
        child: RecordEditScope<DiveSite>(
          controller: controller,
          child: editing == null
              ? const SiteMediaSection(siteId: 'site-1')
              // The open card rebuilds with its sitting, as the page's does.
              : ListenableBuilder(
                  listenable: editing,
                  builder: (_, _) =>
                      SiteMediaSection(siteId: 'site-1', editing: editing),
                ),
        ),
      ),
    ),
  );

  Future<void> holdUnderwater(
    WidgetTester tester,
    EditSession<DiveSite> session,
  ) async {
    await tester.pumpWidget(await card(editing: session));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection_select_all')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('selection_action_setCategory')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Underwater'));
    await tester.pumpAndSettle();
  }

  testWidgets('is held until Save', (tester) async {
    final session = openCard();
    await holdUnderwater(tester, session);

    expect(session.changedCardIds, {'media'});
    expect(find.text('Underwater (2)'), findsOneWidget);
    expect(find.text('Updated 2 items'), findsNothing);
    expect(find.byKey(const ValueKey('selection_exit')), findsNothing);
    expect(written, isEmpty);

    await tester.runAsync(session.runHeldWrites);
    expect(written.toSet(), {'m1:underwater', 'm2:underwater'});
  });

  testWidgets('is discarded by Cancel', (tester) async {
    final session = openCard();
    await holdUnderwater(tester, session);
    expect(find.text('Underwater (2)'), findsOneWidget);

    session.dispose();
    // The card closes: the page shows the attachments as stored.
    await tester.pumpWidget(await card());
    await tester.pumpAndSettle();
    expect(find.byType(MediaThumbnailTile), findsNWidgets(2));
    expect(find.text('Underwater (2)'), findsNothing);
    expect(written, isEmpty);
  });
}
