import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_caption.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_caption_text.dart';

const _text = ConnectionsCaptionText(
  title: 'Who dives where',
  sentence:
      'A line means you dived at that site with that buddy. Thicker lines '
      'mean more dives.',
);

Future<List<double>> _pump(WidgetTester tester, {double scale = 1}) async {
  final heights = <double>[];
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 360,
            child: ConnectionsCaption(text: _text, onHeight: heights.add),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return heights;
}

void main() {
  testWidgets('shows the title and the whole sentence', (tester) async {
    final heights = await _pump(tester);
    expect(find.text('Who dives where'), findsOneWidget);
    expect(find.text(_text.sentence), findsOneWidget);
    final box = tester.getSize(
      find.byKey(const ValueKey('connections-caption')),
    );
    expect(heights.last, box.height);
  });

  testWidgets('large text wraps the sentence instead of cutting it', (
    tester,
  ) async {
    final heights = await _pump(tester, scale: 2);
    final sentence = tester.widget<Text>(find.text(_text.sentence));
    expect(sentence.maxLines, isNull);
    expect(sentence.overflow, isNot(TextOverflow.ellipsis));
    final small = (await _pump(tester)).last;
    expect(heights.last, greaterThan(small));
  });

  testWidgets('touches on the caption reach the canvas below it', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 8,
              child: ConnectionsCaption(text: _text, onHeight: (_) {}),
            ),
          ],
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('connections-caption')),
      warnIfMissed: false,
    );
    expect(taps, 1);
  });
}
