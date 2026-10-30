import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_panel.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

import 'scrubber_hover.dart';

void main() {
  late ScrollController controller;
  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  Widget host(ThemeData theme, {TextDirection? direction}) => MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Directionality(
        textDirection: direction ?? TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 600,
            width: 800,
            child: ListScrubber(
              controller: controller,
              slotCount: 200,
              loadedSlotCount: 200,
              labelFor: (slot) => 'Slot $slot',
              markers: const [ScrubberMarker(slot: 0, label: 'Top')],
              onScrubEnd: (_) {},
              child: ListView.builder(
                controller: controller,
                itemCount: 200,
                itemExtent: 50,
                itemBuilder: (_, i) => Text('Row $i'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> showIdleThumb(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  }

  Finder handle() => find.descendant(
    of: find.byKey(ListScrubber.thumbKey),
    matching: find.byType(ListScrubberHandle),
  );

  BoxDecoration decoration(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: handle(), matching: find.byType(DecoratedBox)),
    );
    return box.decoration as BoxDecoration;
  }

  Future<TestGesture> hover(WidgetTester tester) => hoverScrubberThumb(tester);

  Color onSurfaceAlpha(ThemeData theme, double opacity) =>
      theme.colorScheme.onSurface.withAlpha((255.0 * opacity).round());

  group('themed scrollbar', () {
    testWidgets('idle thumb takes thickness, colour and radius from theme', (
      tester,
    ) async {
      final theme = ThemeData(
        scrollbarTheme: const ScrollbarThemeData(
          thickness: WidgetStatePropertyAll(10),
          thumbColor: WidgetStatePropertyAll(Colors.red),
          radius: Radius.circular(3),
        ),
      );
      await tester.pumpWidget(host(theme));
      await showIdleThumb(tester);
      expect(tester.getRect(handle()).width, 10);
      final deco = decoration(tester);
      expect(deco.color, Colors.red);
      expect(deco.borderRadius, BorderRadius.circular(3));
      await tester.pump(ListScrubber.idleHide);
    });

    testWidgets('cross axis margin sets the gap to the edge', (tester) async {
      final theme = ThemeData(
        scrollbarTheme: const ScrollbarThemeData(crossAxisMargin: 5),
      );
      await tester.pumpWidget(host(theme));
      await showIdleThumb(tester);
      final area = tester.getRect(find.byType(ListScrubber));
      expect(tester.getRect(handle()).right, area.right - 5);
      await tester.pump(ListScrubber.idleHide);
    });

    testWidgets('right-to-left keeps the gap on the start edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ThemeData(platform: TargetPlatform.windows),
          direction: TextDirection.rtl,
        ),
      );
      await showIdleThumb(tester);
      final area = tester.getRect(find.byType(ListScrubber));
      expect(tester.getRect(handle()).left, area.left + 2);
      await tester.pump(ListScrubber.idleHide);
    });

    for (final brightness in Brightness.values) {
      testWidgets('windows default matches Material Scrollbar, $brightness', (
        tester,
      ) async {
        final theme = ThemeData(
          brightness: brightness,
          platform: TargetPlatform.windows,
        );
        await tester.pumpWidget(host(theme));
        await showIdleThumb(tester);
        expect(tester.getRect(handle()).width, 8.0);
        final idle = brightness == Brightness.light ? 0.1 : 0.3;
        final deco = decoration(tester);
        expect(deco.color, onSurfaceAlpha(theme, idle));
        expect(deco.borderRadius, BorderRadius.circular(8));
        await tester.pump(ListScrubber.idleHide);

        final controller2 = ScrollController();
        addTearDown(controller2.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Scrollbar(
                controller: controller2,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: controller2,
                  itemCount: 200,
                  itemBuilder: (_, i) => Text('Row $i'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final painter = tester
            .widgetList<CustomPaint>(
              find.descendant(
                of: find.byType(Scrollbar),
                matching: find.byType(CustomPaint),
              ),
            )
            .map((p) => p.foregroundPainter)
            .whereType<ScrollbarPainter>()
            .first;
        expect(deco.color, painter.color);
        expect(painter.thickness, 8.0);
      });
    }

    testWidgets('hover and drag use the hovered and dragged look', (
      tester,
    ) async {
      final theme = ThemeData(
        platform: TargetPlatform.windows,
        scrollbarTheme: ScrollbarThemeData(
          thickness: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.dragged)
                ? 14.0
                : s.contains(WidgetState.hovered)
                ? 12.0
                : 9.0,
          ),
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.dragged)
                ? Colors.blue
                : s.contains(WidgetState.hovered)
                ? Colors.green
                : Colors.red,
          ),
        ),
      );
      await tester.pumpWidget(host(theme));
      await showIdleThumb(tester);
      expect(tester.getRect(handle()).width, 9);
      final mouse = await hover(tester);
      expect(tester.getRect(handle()).width, 12);
      expect(decoration(tester).color, Colors.green);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ListScrubber.thumbKey)),
      );
      await gesture.moveBy(const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(tester.getRect(handle()).width, 14);
      expect(decoration(tester).color, Colors.blue);
      await gesture.up();
      await mouse.removePointer();
      await tester.pumpAndSettle(ListScrubber.idleHide);
    });

    testWidgets('windows default hover and drag use Material colours', (
      tester,
    ) async {
      final theme = ThemeData(platform: TargetPlatform.windows);
      await tester.pumpWidget(host(theme));
      await showIdleThumb(tester);
      final mouse = await hover(tester);
      expect(decoration(tester).color, onSurfaceAlpha(theme, 0.5));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(ListScrubber.thumbKey)),
      );
      await gesture.moveBy(const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(decoration(tester).color, onSurfaceAlpha(theme, 0.6));
      await gesture.up();
      await mouse.removePointer();
      await tester.pumpAndSettle(ListScrubber.idleHide);
    });
  });

  testWidgets('a wide themed handle can be hovered across its width', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ThemeData(
          scrollbarTheme: const ScrollbarThemeData(
            thickness: WidgetStatePropertyAll(14),
            crossAxisMargin: 3,
          ),
        ),
      ),
    );
    await tester.pump();
    final area = tester.getRect(find.byType(ListScrubber));
    final thumb = tester.getRect(find.byKey(ListScrubber.thumbKey));
    // On the handle (3 px in, 14 px wide), past the default grip width.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset(area.right - 16, thumb.center.dy));
    await tester.pumpAndSettle();
    expect(find.byKey(ListScrubber.panelKey), findsOneWidget);
    await mouse.removePointer();
    await tester.pumpAndSettle();
    await tester.pump(ListScrubber.idleHide);
  });
}
