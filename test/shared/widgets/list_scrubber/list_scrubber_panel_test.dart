import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_context_painter.dart';
import 'package:submersion/shared/widgets/list_scrubber/list_scrubber_density_painter.dart';
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
    String? currentDetail,
    double currentWidth = ListScrubberPanel.width,
    double labelColumn = ListScrubberPanel.width,
    double reveal = 1,
    List<ScrubberSegment> segments = const [],
  }) => MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: labelColumn,
            height: 600,
            child: ListScrubberPanel(
              markers: markers,
              slotCount: 101,
              trackExtent: 500,
              thumbHeight: thumbHeight,
              thumbTop: thumbTop,
              currentLabel: currentLabel,
              currentDetail: currentDetail,
              currentWidth: currentWidth,
              labelColumn: labelColumn,
              reveal: reveal,
              segments: segments,
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

  List<BackdropFilter> blurs(WidgetTester tester) => tester
      .widgetList<BackdropFilter>(
        find.descendant(
          of: find.byType(ListScrubberPanel),
          matching: find.byType(BackdropFilter),
        ),
      )
      .toList();

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
    expect(tester.getRect(backing).left, closeTo(label.left - 2, 0.01));
    expect(tester.getRect(backing).right, closeTo(label.right + 2, 0.01));
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
    testWidgets('a square, frosted panel at 60% ($brightness)', (tester) async {
      await tester.pumpWidget(
        host(markers: const [], thumbTop: 0, brightness: brightness),
      );
      final box = decoration(tester);
      expect(box.borderRadius, isNull);
      expect(box.color!.a, closeTo(ListScrubberPanel.fillAlpha, 0.01));
      expect(ListScrubberPanel.fillAlpha, 0.6);
      final blur = blurs(tester);
      expect(blur, hasLength(1));
      expect(
        blur.single.filter,
        ImageFilter.blur(
          sigmaX: ListScrubberPanel.blurSigma,
          sigmaY: ListScrubberPanel.blurSigma,
        ),
      );
      expect(
        tester.getRect(find.byWidget(blur.single)),
        tester.getRect(find.byType(ListScrubberPanel)),
      );
    });
  }

  testWidgets('a band sticking out is frosted over its tab too', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        markers: const [],
        thumbTop: 100,
        currentLabel: 'Manta Point',
        currentWidth: 160,
      ),
    );
    final panel = tester.getRect(find.byType(ListScrubberPanel));
    final band = tester.getRect(find.byKey(ListScrubberPanel.currentBandKey));
    final blur = blurs(tester);
    expect(blur, hasLength(2));
    final tab = tester.getRect(find.byWidget(blur.last));
    expect(tab.right, closeTo(panel.left, 0.01));
    expect(tab.left, closeTo(band.left, 0.01));
    expect(tab.top, closeTo(band.top, 0.01));
    expect(tab.bottom, closeTo(band.bottom, 0.01));
  });

  testWidgets('a partial reveal fades the contents and thins the frost', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        markers: const [ScrubberMarker(slot: 60, label: '2024')],
        thumbTop: 0,
        reveal: 0.5,
      ),
    );
    final fade = tester.widget<Opacity>(
      find.ancestor(of: find.text('2024'), matching: find.byType(Opacity)),
    );
    expect(fade.opacity, 0.5);
    expect(
      blurs(tester).single.filter,
      ImageFilter.blur(
        sigmaX: ListScrubberPanel.blurSigma / 2,
        sigmaY: ListScrubberPanel.blurSigma / 2,
      ),
    );
    // The frost is outside the fade, so it blurs the list behind it rather
    // than the fade's own empty layer.
    expect(
      find.ancestor(
        of: find.byType(BackdropFilter),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  group('label column', () {
    testWidgets('fits the widest marker beside the thumb', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      const thumbInset = 10.0;
      final style = ListScrubberPanel.markerStyle(Theme.of(context));
      double textWidth(String s) {
        final painter = TextPainter(
          text: TextSpan(text: s, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        final w = painter.width;
        painter.dispose();
        return w;
      }

      final column = ListScrubberPanel.labelColumnFor(context, const [
        ScrubberMarker(slot: 0, label: '2024'),
        ScrubberMarker(slot: 9, label: '1999'),
        ScrubberMarker(slot: 5, label: '7'),
      ], thumbInset: thumbInset);
      final widest = [
        '2024',
        '1999',
      ].map(textWidth).reduce((a, b) => a > b ? a : b);
      expect(column, widest.ceilToDouble() + 2 * 2 + thumbInset);
      expect(column, lessThan(ListScrubberPanel.width));

      final capped = ListScrubberPanel.labelColumnFor(context, const [
        ScrubberMarker(slot: 0, label: 'A very long marker label indeed'),
      ], thumbInset: thumbInset);
      expect(capped, ListScrubberPanel.width);

      expect(
        ListScrubberPanel.labelColumnFor(
          context,
          const [],
          thumbInset: thumbInset,
        ),
        greaterThanOrEqualTo(thumbInset),
      );
    });

    testWidgets('markers centre in the column clear of the thumb', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          markers: const [ScrubberMarker(slot: 60, label: '2024')],
          thumbTop: 0,
          labelColumn: 40,
        ),
      );
      final panel = tester.getRect(find.byType(ListScrubberPanel));
      final label = tester.getRect(find.text('2024'));
      expect(panel.width, 40);
      expect(label.left, greaterThanOrEqualTo(panel.left));
      expect(label.right, lessThanOrEqualTo(panel.right));
    });

    test('the panel adds the density column to the label column', () {
      expect(ListScrubberPanel.widthFor(labelColumn: 40, density: false), 40);
      expect(
        ListScrubberPanel.widthFor(labelColumn: 40, density: true),
        40 + ListScrubberPanel.densityColumn,
      );
      // A gap keeps the bars off the markers.
      expect(
        ListScrubberPanel.densityColumn,
        greaterThan(ListScrubberDensityPainter.columnEnd),
      );
    });
  });

  group('two-line band', () {
    // Ahem, the test font, draws every glyph as a square as wide as it is
    // tall, so this wraps once in a band at its cap and no further.
    const trip = 'Red Sea Brothers Daedalus';

    testWidgets('the detail sits under the value in the marker style', (
      tester,
    ) async {
      late Size size;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              size = ListScrubberPanel.bandSize(
                context,
                value: 'Mar 2024',
                detail: trip,
                hostWidth: 800,
                panelWidth: 64,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(size.width, lessThanOrEqualTo(ListScrubberPanel.maxBandWidth));
      expect(ListScrubberPanel.maxBandWidth, 230);
      await tester.pumpWidget(
        host(
          markers: const [],
          thumbTop: 200,
          currentLabel: 'Mar 2024',
          currentDetail: trip,
          currentWidth: size.width,
        ),
      );
      final band = tester.getRect(find.byKey(ListScrubberPanel.currentBandKey));
      final value = find.byKey(ListScrubberPanel.currentValueKey);
      final detail = find.byKey(ListScrubberPanel.currentDetailKey);
      expect(tester.widget<Text>(detail).data, trip);
      expect(tester.widget<Text>(detail).maxLines, 2);
      expect(
        tester.widget<Text>(detail).style!.fontWeight,
        isNot(FontWeight.w700),
      );
      expect(tester.widget<Text>(value).style!.fontWeight, FontWeight.w700);
      final v = tester.getRect(value);
      final d = tester.getRect(detail);
      expect(d.top, greaterThanOrEqualTo(v.bottom - 0.01));
      expect(band.top, lessThanOrEqualTo(v.top));
      expect(band.bottom, greaterThanOrEqualTo(d.bottom));
      expect(band.height, closeTo(size.height, 0.5));
      // Long enough to wrap: two lines, and no "..." at this length.
      expect(d.height, greaterThan(v.height * 1.5));
      final painter = TextPainter(
        text: TextSpan(text: trip, style: tester.widget<Text>(detail).style),
        maxLines: 2,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: d.width + 0.5);
      expect(painter.didExceedMaxLines, isFalse);
      painter.dispose();
    });

    testWidgets('a short detail keeps the band on its natural width', (
      tester,
    ) async {
      late Size twoLines;
      late Size oneLine;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              twoLines = ListScrubberPanel.bandSize(
                context,
                value: 'Jul 2025',
                detail: 'Bonaire',
                hostWidth: 800,
                panelWidth: 64,
              );
              oneLine = ListScrubberPanel.bandSize(
                context,
                value: 'Jul 2025',
                hostWidth: 800,
                panelWidth: 64,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(twoLines.width, lessThan(ListScrubberPanel.maxBandWidth));
      expect(twoLines.height, greaterThan(oneLine.height));
    });

    testWidgets('a narrow host caps the band', (tester) async {
      late Size size;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              size = ListScrubberPanel.bandSize(
                context,
                value: 'Mar 2024',
                detail: trip * 3,
                hostWidth: 120,
                panelWidth: 64,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(size.width, 120 - 16);
    });

    testWidgets('the trip stripe and bars leave out the band', (tester) async {
      await tester.pumpWidget(
        host(
          markers: const [],
          thumbTop: 200,
          currentLabel: 'Mar 2024',
          currentDetail: 'Bonaire',
          currentWidth: 120,
          segments: const [
            ScrubberSegment(firstSlot: 0, lastSlot: 100, color: Colors.purple),
          ],
        ),
      );
      final band = tester.getRect(find.byKey(ListScrubberPanel.currentBandKey));
      final panel = tester.getRect(find.byType(ListScrubberPanel));
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) =>
                          w is CustomPaint &&
                          w.painter is ListScrubberContextPainter,
                    ),
                  )
                  .painter!
              as ListScrubberContextPainter;
      expect(painter.clear, isNotNull);
      expect(painter.clear!.top, closeTo(band.top - panel.top, 0.01));
      expect(painter.clear!.bottom, closeTo(band.bottom - panel.top, 0.01));
    });
  });
}
