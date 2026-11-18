import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_toolbar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

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
      bool browser = false,
      bool unlockable = false,
      bool writeControls = true,
      String? writeMetadataDisabledReason,
      bool editing = false,
      bool canSave = false,
      double dockedPanel = 0,
    }) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final calls = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            if (browser)
              deviceCapabilitiesProvider.overrideWithValue(
                DeviceCapabilities.web,
              ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            // [dockedPanel] takes the right of the window, as Adjust color
            // does from the desktop breakpoint.
            home: Scaffold(
              body: Row(
                children: [
                  Expanded(
                    child: Stack(
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
                          onAdjustColor: () => calls.add('adjust_color'),
                          onUnlock: unlockable
                              ? () => calls.add('unlock')
                              : null,
                          writeControls: writeControls,
                          writeMetadataDisabledReason:
                              writeMetadataDisabledReason,
                          editBar: editing
                              ? MediaViewerEditBar(
                                  title: 'Editing photo',
                                  canSave: canSave,
                                  isSaving: false,
                                  onCancel: () => calls.add('cancel'),
                                  onSave: () => calls.add('save'),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  if (dockedPanel > 0) SizedBox(width: dockedPanel),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return calls;
    }

    testWidgets('a browser keeps only the viewing actions (#4121)', (
      tester,
    ) async {
      await pumpFull(tester, 1024, browser: true);
      for (final id in ['go_to_dive', 'perdix', 'info', 'share']) {
        expect(find.byKey(ValueKey('viewer_$id')), findsOneWidget, reason: id);
      }
      for (final id in [
        'write_metadata',
        'lightroom',
        'species',
        'adjust_color',
        'reupload',
      ]) {
        expect(find.byKey(ValueKey('viewer_$id')), findsNothing, reason: id);
      }
      expect(find.byKey(const ValueKey('viewer_overflow')), findsNothing);
    });

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
        'adjust_color',
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
        'adjust_color',
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
        'adjust_color',
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
    group('the lock (issue #4527)', () {
      testWidgets('defaults: no lock, and the same actions as today', (
        tester,
      ) async {
        await pumpFull(tester, 1024);
        expect(find.byKey(const ValueKey('viewer_unlock')), findsNothing);
        expect(find.byType(RecordEditBar), findsNothing);
      });

      testWidgets('onUnlock: a lock action that calls back', (tester) async {
        final calls = await pumpFull(tester, 1024, unlockable: true);
        await tester.tap(find.byKey(const ValueKey('viewer_unlock')));
        expect(calls, ['unlock']);
        expect(find.byTooltip('Unlock to edit'), findsOneWidget);
      });

      testWidgets('the lock stays visible at phone width', (tester) async {
        await pumpFull(tester, 360, unlockable: true);
        expect(find.byKey(const ValueKey('viewer_unlock')), findsOneWidget);
      });

      testWidgets('writeControls false: no species, people or adjust colour', (
        tester,
      ) async {
        await pumpFull(tester, 1024, writeControls: false);
        for (final id in ['species', 'people', 'adjust_color']) {
          expect(find.byKey(ValueKey('viewer_$id')), findsNothing, reason: id);
        }
        expect(find.byKey(const ValueKey('viewer_info')), findsOneWidget);
      });

      testWidgets('write data with a reason: disabled, the reason as tooltip', (
        tester,
      ) async {
        final calls = await pumpFull(
          tester,
          1024,
          writeMetadataDisabledReason: 'Unlock to use this',
        );
        final button = tester.widget<IconButton>(
          find.descendant(
            of: find.byKey(const ValueKey('viewer_write_metadata')),
            matching: find.byType(IconButton),
          ),
        );
        expect(button.onPressed, isNull);
        expect(find.byTooltip('Unlock to use this'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('viewer_write_metadata')),
          warnIfMissed: false,
        );
        expect(calls, isEmpty);
      });

      testWidgets('write data with a reason, in the menu: disabled, with the '
          'reason', (tester) async {
        await pumpFull(
          tester,
          360,
          writeMetadataDisabledReason: 'Unlock to use this',
        );
        await tester.tap(find.byKey(const ValueKey('viewer_overflow')));
        await tester.pumpAndSettle();
        final item = tester.widget<PopupMenuItem<MediaViewerAction>>(
          find.byKey(const ValueKey('viewer_menu_write_metadata')),
        );
        expect(item.enabled, isFalse);
        expect(find.text('Unlock to use this'), findsOneWidget);
      });

      testWidgets('editBar: Cancel, the title, the actions and Save; no close, '
          'fullscreen or lock', (tester) async {
        final calls = await pumpFull(
          tester,
          1024,
          unlockable: true,
          editing: true,
          canSave: true,
        );
        expect(find.byType(RecordEditBar), findsOneWidget);
        expect(find.text('Editing photo'), findsOneWidget);
        expect(find.byTooltip('Close photo viewer'), findsNothing);
        expect(find.byTooltip('Full screen'), findsNothing);
        expect(find.byKey(const ValueKey('viewer_unlock')), findsNothing);
        expect(find.byKey(const ValueKey('viewer_species')), findsOneWidget);
        await tester.tap(find.text('Save'));
        await tester.tap(find.text('Cancel'));
        expect(calls, ['save', 'cancel']);
      });

      testWidgets('editBar: the band is the toolbar\'s 64 px', (tester) async {
        await pumpFull(tester, 1024, editing: true);
        expect(
          tester.getSize(find.byType(RecordEditBar)).height,
          kMediaViewerToolbarHeight,
        );
      });

      testWidgets('editBar at 360 px wide: what does not fit is in the menu', (
        tester,
      ) async {
        await pumpFull(tester, 360, editing: true);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('viewer_overflow')), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('editBar at a 390 px phone leaves the title room: two icons '
          'and the menu', (tester) async {
        await pumpFull(tester, 390, editing: true);
        final icons = find.descendant(
          of: find.byType(RecordEditBar),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Builder &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('viewer_'),
          ),
        );
        expect(icons, findsNWidgets(2));
        expect(find.byKey(const ValueKey('viewer_overflow')), findsOneWidget);
      });

      testWidgets(
        'editBar beside a docked panel fits the bar, not the window',
        (tester) async {
          // 800 px wide with Adjust color docked: the bar is 480 px.
          await pumpFull(tester, 800, editing: true, dockedPanel: 320);
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('viewer_overflow')), findsOneWidget);
          expect(find.text('Save'), findsOneWidget);
        },
      );

      test('the actions get what Cancel, Save and the title leave, up to '
          'half the bar, and one button however narrow', () {
        expect(editBarActionsWidth(1280), 640);
        expect(editBarActionsWidth(480), 240);
        expect(editBarActionsWidth(300), 60);
        expect(editBarActionsWidth(260), kToolbarButtonExtent);
        // Under two buttons wide, half the bar is less than one button.
        expect(editBarActionsWidth(90), kToolbarButtonExtent);
      });

      testWidgets('a read-only device offers no lock', (tester) async {
        await pumpFull(tester, 1024, browser: true, unlockable: true);
        expect(find.byKey(const ValueKey('viewer_unlock')), findsNothing);
      });
    });
  });
}
