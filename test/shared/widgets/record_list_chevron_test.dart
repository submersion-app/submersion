import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/record_list_chevron.dart';

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 300, child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('RecordListChevron', () {
    for (final size in [
      RecordListChevron.detailedSize,
      RecordListChevron.compactSize,
      RecordListChevron.denseSize,
    ]) {
      testWidgets('ends at the tip of the glyph ink at size $size', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            Align(
              alignment: Alignment.centerRight,
              child: RecordListChevron(size: size),
            ),
          ),
        );

        final box = tester.getRect(find.byType(RecordListChevron));
        final icon = tester.getRect(find.byIcon(Icons.chevron_right));

        // The glyph's ink stops a third of the icon box short of its end, so
        // the icon overflows the layout box by exactly that blank margin and
        // the visible tip lands on the box's edge.
        expect(icon.width, size);
        expect(icon.right - box.right, closeTo(size / 3, 0.01));
        expect(box.right, 300);
      });
    }

    testWidgets('mirrors in right-to-left text', (tester) async {
      await tester.pumpWidget(
        _host(
          const Align(
            alignment: Alignment.centerLeft,
            child: RecordListChevron(),
          ),
          direction: TextDirection.rtl,
        ),
      );

      final box = tester.getRect(find.byType(RecordListChevron));
      final icon = tester.getRect(find.byIcon(Icons.chevron_right));

      expect(box.left, 0);
      expect(box.left - icon.left, closeTo(24 / 3, 0.01));
    });

    testWidgets('is hidden from semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const RecordListChevron()));

      expect(
        find.descendant(
          of: find.byType(RecordListChevron),
          matching: find.byType(ExcludeSemantics),
          matchRoot: true,
        ),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('RecordListChevronRow', () {
    testWidgets('pins the chevron to the end and centres it on the content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RecordListChevronRow(
            child: SizedBox(key: Key('content'), height: 80),
          ),
        ),
      );

      final content = tester.getRect(find.byKey(const Key('content')));
      final chevron = tester.getRect(find.byType(RecordListChevron));

      expect(chevron.right, 300);
      expect(chevron.center.dy, closeTo(content.center.dy, 0.01));
      expect(content.left, 0);
      expect(content.right, lessThanOrEqualTo(chevron.left));
    });

    testWidgets('gives the content the full width without a chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RecordListChevronRow(
            showChevron: false,
            child: SizedBox(key: Key('content'), height: 20),
          ),
        ),
      );

      expect(find.byType(RecordListChevron), findsNothing);
      expect(tester.getRect(find.byKey(const Key('content'))).width, 300);
    });

    testWidgets('passes size and colour to the chevron', (tester) async {
      await tester.pumpWidget(
        _host(
          const RecordListChevronRow(
            chevronSize: RecordListChevron.compactSize,
            chevronColor: Colors.red,
            child: SizedBox(height: 20),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
      expect(icon.size, RecordListChevron.compactSize);
      expect(icon.color, Colors.red);
    });
  });

  group('RecordListChevronOverlay', () {
    testWidgets('centres the chevron one card padding from the end', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RecordListChevronOverlay(
            child: SizedBox(
              key: Key('tile'),
              width: double.infinity,
              height: 96,
            ),
          ),
        ),
      );

      final tile = tester.getRect(find.byKey(const Key('tile')));
      final chevron = tester.getRect(find.byType(RecordListChevron));

      expect(tile.right - chevron.right, kRecordCardDetailedPadding);
      expect(chevron.center.dy, closeTo(tile.center.dy, 0.01));
      expect(
        chevron.left,
        closeTo(tile.right - kRecordListTileContentPadding.end, 0.01),
        reason: 'the tile reserves exactly the room the chevron takes',
      );
    });

    testWidgets('lets a tap on the chevron reach the tile', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          Material(
            child: RecordListChevronOverlay(
              child: ListTile(
                contentPadding: kRecordListTileContentPadding,
                title: const Text('Trip'),
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(RecordListChevron));
      expect(taps, 1);
    });

    testWidgets('takes the ListTile icon colour by default', (tester) async {
      await tester.pumpWidget(
        _host(
          const RecordListChevronOverlay(
            child: SizedBox(width: double.infinity, height: 40),
          ),
        ),
      );

      final context = tester.element(find.byType(RecordListChevronOverlay));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.chevron_right)).color,
        Theme.of(context).colorScheme.onSurfaceVariant,
      );
    });

    testWidgets('shows only the child without a chevron', (tester) async {
      await tester.pumpWidget(
        _host(
          const RecordListChevronOverlay(
            showChevron: false,
            child: SizedBox(height: 20),
          ),
        ),
      );

      expect(find.byType(RecordListChevron), findsNothing);
    });
  });
}
