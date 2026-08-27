import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/drag_select_grid_view.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/selection_contract.dart';
import '../../../../helpers/test_app.dart';

MediaItem _item(String id) => MediaItem(
  id: id,
  diveId: 'dive-1',
  filePath: '/tmp/$id.jpg',
  originalFilename: '$id.jpg',
  mediaType: MediaType.photo,
  takenAt: DateTime(2026, 3, 15),
  createdAt: DateTime(2026, 3, 15),
  updatedAt: DateTime(2026, 3, 15),
);

/// Mutable ordering source, so a test can reorder the media list the way a
/// re-sort or a sync would.
final _mediaProvider = StateProvider<List<MediaItem>>((ref) => const []);

/// Captures the ids an unlink actually acts on, which is the only place the
/// difference between id-based and index-based selection becomes observable.
///
/// Both entry points are captured on purpose. This surface's Unlink used to
/// call [deleteMultipleMedia] -- a hard delete behind copy that promised the
/// files were kept -- so recording the two separately lets a test assert not
/// just which ids were acted on but that the row was unlinked rather than
/// destroyed.
class _CapturingMediaListNotifier
    extends StateNotifier<AsyncValue<List<MediaItem>>>
    implements MediaListNotifier {
  _CapturingMediaListNotifier() : super(const AsyncValue.data(<MediaItem>[]));

  List<String>? unlinkedIds;
  List<String>? deletedIds;

  @override
  Future<UnlinkOutcome> unlinkMultipleMedia(List<String> ids) async {
    unlinkedIds = List<String>.from(ids);
    return UnlinkOutcome(deleted: ids.length, keptAsSiteMedia: 0);
  }

  @override
  Future<void> deleteMultipleMedia(List<String> ids) async {
    deletedIds = List<String>.from(ids);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget host(
    List<MediaItem> media, {
    _CapturingMediaListNotifier? listNotifier,
  }) {
    return testApp(
      locale: const Locale('en'),
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        _mediaProvider.overrideWith((ref) => media),
        mediaForDiveProvider(
          'dive-1',
        ).overrideWith((ref) async => ref.watch(_mediaProvider)),
        if (listNotifier != null)
          mediaListNotifierProvider(
            'dive-1',
          ).overrideWith((ref) => listNotifier),
      ],
      child: const SingleChildScrollView(
        child: DiveMediaSection(diveId: 'dive-1'),
      ),
    );
  }

  group('DiveMediaSection selection contract', () {
    testWidgets('satisfies the shared selection contract', (tester) async {
      final a = _item('a');
      final b = _item('b');
      final c = _item('c');

      await verifySelectionContract(
        tester,
        build: () => host([a, b, c]),
        selectButton: find.byKey(const ValueKey('enter_selection')),
        // The grid's own keyed detector for the first thumbnail.
        firstRow: find
            .descendant(
              of: find.byType(DragSelectGridView<MediaItem>),
              matching: find.byType(GestureDetector),
            )
            .first,
        // The grid draws a check badge over the thumbnail rather than a
        // Checkbox, so it opts out of that one assertion only.
        indicator: CheckedIndicator.custom,
        applyFilter: (tester) async {
          final container = ProviderScope.containerOf(
            tester.element(find.byType(DiveMediaSection)),
          );
          container.read(_mediaProvider.notifier).state = [a];
        },
        visibleAfterFilter: 1,
      );
    });
  });

  group('DiveMediaSection selection', () {
    testWidgets('exposes a visible Select affordance', (tester) async {
      await tester.pumpWidget(host([_item('a'), _item('b'), _item('c')]));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('enter_selection')),
        findsOneWidget,
        reason: 'selecting media must not require a hidden long-press',
      );
    });

    testWidgets('the Select button enters selection mode', (tester) async {
      await tester.pumpWidget(host([_item('a'), _item('b'), _item('c')]));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('selection_exit')), findsOneWidget);
      expect(find.text('0 selected'), findsOneWidget);
    });

    testWidgets('omits the delete control, since unlink is not a delete', (
      tester,
    ) async {
      await tester.pumpWidget(host([_item('a'), _item('b')]));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('selection_delete')), findsNothing);
      expect(
        find.byKey(const ValueKey('selection_action_unlink')),
        findsOneWidget,
      );
    });

    testWidgets('select all checks every media id', (tester) async {
      await tester.pumpWidget(host([_item('a'), _item('b'), _item('c')]));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();

      expect(find.text('3 selected'), findsOneWidget);
    });

    testWidgets('a partial selection survives a reorder, by id not position', (
      tester,
    ) async {
      final a = _item('a');
      final b = _item('b');
      final c = _item('c');
      final notifier = _CapturingMediaListNotifier();

      await tester.pumpWidget(host([a, b, c], listNotifier: notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      // Check only the third thumbnail, which is 'c' in this ordering.
      //
      // Each item carries two GestureDetectors -- the grid's own keyed one
      // and the section's right-click wrapper -- so the stride is derived
      // rather than assumed. Hard-coding .at(index) selects the wrong file.
      final items = find.descendant(
        of: find.byType(DragSelectGridView<MediaItem>),
        matching: find.byType(GestureDetector),
      );
      final stride = tester.widgetList<GestureDetector>(items).length ~/ 3;
      await tester.tap(items.at(2 * stride), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      // Reorder so position 2 now holds 'a'. Index-based selection would
      // follow the position and unlink the wrong file; id-based selection
      // must still be holding 'c'.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveMediaSection)),
      );
      container.read(_mediaProvider.notifier).state = [c, b, a];
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('selection_action_unlink')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unlink'));
      await tester.pumpAndSettle();

      expect(notifier.unlinkedIds, [
        'c',
      ], reason: 'unlink must act on the checked id, not the checked position');
      expect(
        notifier.deletedIds,
        isNull,
        reason: 'unlink must clear the link, never destroy the row',
      );
    });

    testWidgets('an explicit entry survives unchecking the last thumbnail', (
      tester,
    ) async {
      await tester.pumpWidget(host([_item('a'), _item('b')]));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      final thumb = find
          .descendant(
            of: find.byType(DragSelectGridView<MediaItem>),
            matching: find.byType(GestureDetector),
          )
          .first;

      await tester.tap(thumb, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(thumb, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('selection_exit')),
        findsOneWidget,
        reason: 'a mode the user asked for must survive at zero checked',
      );
      expect(find.text('0 selected'), findsOneWidget);
    });

    testWidgets('a long-press on a thumbnail does not enter selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(host([_item('a'), _item('b')]));
      await tester.pumpAndSettle();

      final thumb = find
          .descendant(
            of: find.byType(DragSelectGridView<MediaItem>),
            matching: find.byType(GestureDetector),
          )
          .first;

      await tester.longPress(thumb, warnIfMissed: false);
      await tester.pumpAndSettle();

      // The grid's long-press now only anchors a range drag inside an already
      // active selection, so from the normal header it cannot open the mode.
      // The hold falls through to the tile's tap, which opens the viewer.
      expect(find.byKey(const ValueKey('selection_exit')), findsNothing);
      expect(find.text('1 selected'), findsNothing);
    });

    testWidgets('removing an item prunes it from the selection', (
      tester,
    ) async {
      final a = _item('a');
      final b = _item('b');
      final c = _item('c');
      await tester.pumpWidget(host([a, b, c]));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveMediaSection)),
      );
      container.read(_mediaProvider.notifier).state = [a];
      await tester.pumpAndSettle();

      expect(
        find.text('1 selected'),
        findsOneWidget,
        reason: 'the selection must prune to what is still attached',
      );
    });
  });
}
