import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_panel.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_panel_edge.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

void main() {
  const thumbHeight = 48.0;

  // 101 slots over a 500 px track: slot n sits at 5n px.
  Widget host({
    required List<ScrubberMarker> markers,
    required double thumbTop,
    TextScaler textScaler = TextScaler.noScaling,
    Brightness brightness = Brightness.light,
    String? currentLabel,
    double currentWidth = ListScrubberPanel.width,
  }) => MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: ListScrubberPanel.width,
            height: 600,
            child: ListScrubberPanel(
              markers: markers,
              slotCount: 101,
              trackExtent: 500,
              thumbHeight: thumbHeight,
              thumbTop: thumbTop,
              currentLabel: currentLabel,
              currentWidth: currentWidth,
            ),
          ),
        ),
      ),
    ),
  );

  BoxDecoration decoration(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find
                    .descendant(
                      of: find.byType(ListScrubberPanel),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              )
              .decoration
          as BoxDecoration;

  ListScrubberPanelEdge edge(WidgetTester tester) => tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(ListScrubberPanel),
          matching: find.byType(CustomPaint),
        ),
      )
      .map((paint) => paint.painter)
      .whereType<ListScrubberPanelEdge>()
      .single;

  testWidgets('a marker beside a hidden one is not thinned away', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        markers: const [
          ScrubberMarker(slot: 20, label: 'Under'),
          ScrubberMarker(slot: 24, label: 'Beside'),
        ],
        thumbTop: 80,
      ),
    );
    expect(find.text('Under'), findsNothing);
    expect(find.text('Beside'), findsOneWidget);
  });

  testWidgets('a freed marker too close to the next kept one stays hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        markers: const [
          ScrubberMarker(slot: 20, label: 'Under'),
          ScrubberMarker(slot: 24, label: 'Freed'),
          ScrubberMarker(slot: 28, label: 'Next'),
        ],
        thumbTop: 80,
      ),
    );
    expect(find.text('Under'), findsNothing);
    expect(find.text('Freed'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('nudging the handle leaves markers away from it alone', (
    tester,
  ) async {
    final dense = [
      for (var slot = 0; slot <= 100; slot++)
        ScrubberMarker(slot: slot, label: 'M$slot'),
    ];
    Set<int> shownAwayFromHandle() => {
      for (final text in tester.widgetList<Text>(
        find.descendant(
          of: find.byType(ListScrubberPanel),
          matching: find.byType(Text),
        ),
      ))
        int.parse(text.data!.substring(1)),
    }.where((slot) => (slot * 5 - 200).abs() > 100).toSet();

    await tester.pumpWidget(host(markers: dense, thumbTop: 200));
    final before = shownAwayFromHandle();
    await tester.pumpWidget(host(markers: dense, thumbTop: 204));
    final after = shownAwayFromHandle();

    expect(before, isNotEmpty);
    expect(after, before);
  });

  testWidgets('a label stays centred on its tick at a large text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        markers: const [ScrubberMarker(slot: 60, label: '2024')],
        thumbTop: 0,
        textScaler: const TextScaler.linear(2),
      ),
    );
    final panel = tester.getRect(find.byType(ListScrubberPanel));
    final label = tester.getRect(find.text('2024'));
    expect(label.height, greaterThan(20));
    expect(label.center.dy, closeTo(panel.top + 300 + thumbHeight / 2, 1));
  });

  testWidgets('each label sits in its own padded box', (tester) async {
    await tester.pumpWidget(
      host(
        markers: const [ScrubberMarker(slot: 60, label: '2024')],
        thumbTop: 0,
      ),
    );
    final backing = find.ancestor(
      of: find.text('2024'),
      matching: find.byKey(ListScrubberPanel.labelBackingKey),
    );
    expect(backing, findsOneWidget);
    final label = tester.getRect(find.text('2024'));
    expect(tester.getRect(backing).contains(label.center), isTrue);
    expect(tester.getRect(backing).left, closeTo(label.left - 6, 0.01));
    expect(tester.getRect(backing).right, closeTo(label.right + 6, 0.01));
  });

  testWidgets('a wide current band sticks out past the start edge', (
    tester,
  ) async {
    const markers = [ScrubberMarker(slot: 60, label: '2024')];
    await tester.pumpWidget(host(markers: markers, thumbTop: 0));
    final before = tester.getRect(find.text('2024'));
    await tester.pumpWidget(
      host(
        markers: markers,
        thumbTop: 0,
        currentLabel: 'Manta Point',
        currentWidth: 160,
      ),
    );
    final panel = tester.getRect(find.byType(ListScrubberPanel));
    final band = tester.getRect(find.byKey(ListScrubberPanel.currentBandKey));
    expect(panel.width, ListScrubberPanel.width);
    expect(band.width, 160);
    expect(band.right, panel.right);
    expect(band.left, panel.right - 160);
    expect(band.center.dy, closeTo(panel.top + thumbHeight / 2, 0.01));
    expect(tester.getRect(find.text('2024')), before);
    final tab = edge(tester).tab!;
    expect(tab.overhang, 160 - ListScrubberPanel.width);
    expect(tab.top, closeTo(band.top - panel.top, 0.01));
    expect(tab.bottom, closeTo(band.bottom - panel.top, 0.01));
  });

  testWidgets('the band is drawn like the panel, the value like a marker', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        markers: const [ScrubberMarker(slot: 60, label: '2024')],
        thumbTop: 0,
        currentLabel: 'Manta Point',
        currentWidth: 160,
      ),
    );
    expect(edge(tester).fill, decoration(tester).color);
    expect(
      find.descendant(
        of: find.byKey(ListScrubberPanel.currentBandKey),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
    final value = find.byKey(ListScrubberPanel.currentValueKey);
    final marker = find.text('2024');
    final valueStyle = tester.widget<Text>(value).style!;
    final markerStyle = tester.widget<Text>(marker).style!;
    expect(valueStyle.color, markerStyle.color);
    expect(valueStyle.fontSize, markerStyle.fontSize);
    expect(valueStyle.fontWeight, FontWeight.w700);
    // Labels have no fill of their own: the panel's fill is the only box
    // painted behind them.
    final panelBoxes = find.descendant(
      of: find.byType(ListScrubberPanel),
      matching: find.byType(DecoratedBox),
    );
    for (final text in [value, marker]) {
      expect(find.ancestor(of: text, matching: panelBoxes), findsOneWidget);
      expect(
        tester.widget<DecoratedBox>(
          find.ancestor(of: text, matching: panelBoxes),
        ),
        tester.widget<DecoratedBox>(panelBoxes.first),
      );
    }
    final line =
        tester
                .widget<Container>(
                  find.byKey(ListScrubberPanel.currentMarkerKey),
                )
                .decoration
            as BoxDecoration;
    expect(line.color, markerStyle.color);
  });

  testWidgets('a band that fits stays inside the panel', (tester) async {
    await tester.pumpWidget(
      host(
        markers: const [],
        thumbTop: 0,
        currentLabel: '7',
        currentWidth: ListScrubberPanel.width,
      ),
    );
    final panel = tester.getRect(find.byType(ListScrubberPanel));
    final band = tester.getRect(find.byKey(ListScrubberPanel.currentBandKey));
    expect(band.left, greaterThanOrEqualTo(panel.left));
    expect(band.right, panel.right);
    expect(edge(tester).tab, isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('a square, opaque panel ($brightness)', (tester) async {
      await tester.pumpWidget(
        host(markers: const [], thumbTop: 0, brightness: brightness),
      );
      final box = decoration(tester);
      expect(box.borderRadius, isNull);
      expect(box.color!.a, 1.0);
    });
  }
}
