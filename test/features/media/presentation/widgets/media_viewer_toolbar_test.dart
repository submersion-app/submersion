import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_toolbar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

MediaViewerAction action(String id, int priority) => MediaViewerAction(
  id: id,
  icon: Icons.circle,
  label: id,
  priority: priority,
  onPressed: (_) {},
);

void main() {
  group('splitToolbarActions', () {
    final a = action('a', 2);
    final b = action('b', 0);
    final c = action('c', 1);

    test('everything fits: no overflow', () {
      final split = splitToolbarActions([a, b, c], 3 * 48);
      expect(split.visible, [a, b, c]);
      expect(split.overflow, isEmpty);
    });

    test('short of room: keeps by priority, leaves a slot for the menu', () {
      // 3 * 48 = 144 needed; 140 leaves (140 - 48) / 48 = 1 icon slot.
      final split = splitToolbarActions([a, b, c], 140);
      expect(split.visible, [b]);
      expect(split.overflow, [a, c]);
    });

    test('both lists keep toolbar order, not priority order', () {
      final x = action('x', 1);
      final y = action('y', 0);
      final z = action('z', 3);
      final w = action('w', 2);
      // 4 * 48 = 192 needed; 144 leaves (144 - 48) / 48 = 2 icon slots,
      // which go to y and x (priorities 0 and 1).
      final split = splitToolbarActions([x, y, z, w], 144);
      expect(split.visible, [x, y]);
      expect(split.overflow, [z, w]);
    });

    test('no room at all: everything in the menu', () {
      final split = splitToolbarActions([a, b, c], 20);
      expect(split.visible, isEmpty);
      expect(split.overflow, [a, b, c]);
    });
  });

  group('MediaViewerToolbar', () {
    final item = MediaItem(
      id: 'm1',
      mediaType: MediaType.photo,
      takenAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    Future<List<String>> pumpFull(
      WidgetTester tester,
      double width, {
      double textScale = 1.0,
    }) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Stack(
              children: [
                MediaViewerToolbar(
                  item: item,
                  currentIndex: 11,
                  totalCount: 345,
                  onClose: () => calls.add('close'),
                  onEnterFullscreen: () => calls.add('fullscreen'),
                  onShare: (_) => calls.add('share'),
                  onShowInfo: () => calls.add('info'),
                  onWriteMetadata: () => calls.add('write_metadata'),
                  onTagSpecies: () => calls.add('species'),
                  canWriteMetadata: true,
                  showPerdixToggle: true,
                  perdixEnabled: false,
                  onTogglePerdix: () => calls.add('perdix'),
                  onOpenInLightroom: () => calls.add('lightroom'),
                  onGoToDive: () => calls.add('go_to_dive'),
                  onReupload: (_) => calls.add('reupload'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      return calls;
    }

    testWidgets('a 360 px phone fits the full set without overflowing', (
      tester,
    ) async {
      await pumpFull(tester, 360);
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Full screen'), findsOneWidget);
      expect(find.text('12 / 345'), findsOneWidget);
      // 360 - 8 padding - 96 fixed - 72 indicator = 184: (184 - 48) / 48
      // = 2 icon slots, the two highest priorities.
      expect(find.byKey(const ValueKey('viewer_go_to_dive')), findsOneWidget);
      expect(find.byKey(const ValueKey('viewer_share')), findsOneWidget);
      expect(find.byKey(const ValueKey('viewer_info')), findsNothing);
      expect(find.byKey(const ValueKey('viewer_overflow')), findsOneWidget);
    });

    testWidgets('a 412 px phone shows three icons and the menu', (
      tester,
    ) async {
      await pumpFull(tester, 412);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('viewer_info')), findsOneWidget);
      expect(find.byKey(const ValueKey('viewer_perdix')), findsNothing);
      expect(find.byKey(const ValueKey('viewer_overflow')), findsOneWidget);
    });

    testWidgets('large text keeps room for the whole page indicator', (
      tester,
    ) async {
      await pumpFull(tester, 412, textScale: 2.0);
      expect(tester.takeException(), isNull);
      // At 2x text the indicator needs about twice its 72 px, so one icon
      // fewer fits than at 1x (where Info still shows).
      expect(find.byKey(const ValueKey('viewer_share')), findsOneWidget);
      expect(find.byKey(const ValueKey('viewer_info')), findsNothing);
    });

    testWidgets('a desktop width shows every icon and no menu', (tester) async {
      await pumpFull(tester, 1024);
      for (final id in [
        'go_to_dive',
        'share',
        'info',
        'perdix',
        'species',
        'write_metadata',
        'lightroom',
        'reupload',
      ]) {
        expect(find.byKey(ValueKey('viewer_$id')), findsOneWidget, reason: id);
      }
      expect(find.byKey(const ValueKey('viewer_overflow')), findsNothing);
    });

    testWidgets('every visible icon fires its own callback', (tester) async {
      final calls = await pumpFull(tester, 1024);
      const ids = [
        'go_to_dive',
        'write_metadata',
        'perdix',
        'lightroom',
        'species',
        'info',
        'share',
        'reupload',
      ];
      for (final id in ids) {
        await tester.tap(find.byKey(ValueKey('viewer_$id')));
        await tester.pump();
      }
      expect(calls, ids);
    });

    testWidgets('actions in the menu still fire, in toolbar order', (
      tester,
    ) async {
      final calls = await pumpFull(tester, 360);
      await tester.tap(find.byKey(const ValueKey('viewer_overflow')));
      await tester.pumpAndSettle();

      final menuIds = tester
          .widgetList<PopupMenuItem<MediaViewerAction>>(
            find.byType(PopupMenuItem<MediaViewerAction>),
          )
          .map((w) => w.value!.id)
          .toList();
      expect(menuIds, [
        'write_metadata',
        'perdix',
        'lightroom',
        'species',
        'info',
        'reupload',
      ]);

      await tester.tap(find.byKey(const ValueKey('viewer_menu_info')));
      await tester.pumpAndSettle();
      expect(calls, ['info']);
    });

    testWidgets('the fullscreen and close buttons call back', (tester) async {
      final calls = await pumpFull(tester, 1024);
      await tester.tap(find.byTooltip('Full screen'));
      await tester.tap(find.byTooltip('Close photo viewer'));
      expect(calls, ['fullscreen', 'close']);
    });
  });
}
