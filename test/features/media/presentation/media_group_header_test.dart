import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/media_group_header.dart';

import '../../../helpers/test_app.dart';

const _long =
    'A dive site with a very long name that has to wrap onto more than one '
    'line when the pane is narrow, as any long site name does';

void main() {
  /// Lays [spec] out for real, and returns that height beside the measured one.
  Future<(double drawn, double measured)> compare(
    WidgetTester tester,
    MediaGroupHeaderSpec spec, {
    double width = 320,
    TextScaler textScaler = TextScaler.noScaling,
    TextDirection direction = TextDirection.ltr,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    late MediaGroupHeaderMeasurer measurer;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Directionality(
          textDirection: direction,
          child: MediaQuery(
            data: MediaQueryData(textScaler: textScaler),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  child: Builder(
                    builder: (context) {
                      measurer = MediaGroupHeaderMeasurer.of(context);
                      return MediaGroupHeader(spec: spec, onTap: () {});
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return (
      tester.getSize(find.byType(MediaGroupHeader)).height,
      measurer.extentOf(spec, width),
    );
  }

  const specs = {
    'month': MediaGroupHeaderSpec(
      kind: MediaGroupHeaderKind.month,
      label: 'June 2026',
    ),
    'day': MediaGroupHeaderSpec(
      kind: MediaGroupHeaderKind.day,
      label: 'Friday, June 12',
    ),
    'inert dive': MediaGroupHeaderSpec(
      kind: MediaGroupHeaderKind.dive,
      label: '#9 · Blue Hole',
    ),
    'navigable dive': MediaGroupHeaderSpec(
      kind: MediaGroupHeaderKind.dive,
      label: '#9 · Blue Hole',
      diveId: 'd1',
    ),
    'long inert dive': MediaGroupHeaderSpec(
      kind: MediaGroupHeaderKind.dive,
      label: _long,
    ),
    'long navigable dive': MediaGroupHeaderSpec(
      kind: MediaGroupHeaderKind.dive,
      label: _long,
      diveId: 'd1',
    ),
    'long day': MediaGroupHeaderSpec(
      kind: MediaGroupHeaderKind.day,
      label: _long,
    ),
  };

  for (final MapEntry(key: name, value: spec) in specs.entries) {
    group('a $name header measures what it draws', () {
      testWidgets('at a phone width', (tester) async {
        final (drawn, measured) = await compare(tester, spec);
        expect(measured, drawn);
      });

      testWidgets('at a desktop width', (tester) async {
        final (drawn, measured) = await compare(tester, spec, width: 1200);
        expect(measured, drawn);
      });

      testWidgets('with large text', (tester) async {
        final (drawn, measured) = await compare(
          tester,
          spec,
          textScaler: const TextScaler.linear(2),
        );
        expect(measured, drawn);
      });

      testWidgets('right to left', (tester) async {
        final (drawn, measured) = await compare(
          tester,
          spec,
          direction: TextDirection.rtl,
        );
        expect(measured, drawn);
      });
    });
  }

  testWidgets(
    'a long label really does wrap, and to more lines when narrower',
    (tester) async {
      final spec = specs['long inert dive']!;
      final (wide, _) = await compare(tester, spec, width: 1200);
      final (phone, _) = await compare(tester, spec);
      final (narrow, _) = await compare(tester, spec, width: 160);

      expect(phone, greaterThan(wide));
      expect(narrow, greaterThan(phone));
    },
  );

  testWidgets('a navigable dive header keeps the tap target floor', (
    tester,
  ) async {
    final (drawn, _) = await compare(tester, specs['navigable dive']!);
    final (inert, _) = await compare(tester, specs['inert dive']!);

    expect(drawn, 48);
    expect(inert, lessThan(48));
  });

  testWidgets('only wrapped labels are laid out again for a new width', (
    tester,
  ) async {
    late MediaGroupHeaderMeasurer measurer;
    await tester.pumpWidget(
      testApp(
        child: Builder(
          builder: (context) {
            measurer = MediaGroupHeaderMeasurer.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    final short = specs['inert dive']!;
    final long = specs['long inert dive']!;

    measurer.extentOf(short, 320);
    measurer.extentOf(long, 320);
    final afterFirst = measurer.layouts;

    // Nothing changed: all of it comes from the cache.
    measurer.extentOf(short, 320);
    measurer.extentOf(long, 320);
    expect(measurer.layouts, afterFirst);

    // A new width: only the label that wraps needs its lines worked out.
    measurer.extentOf(short, 321);
    measurer.extentOf(long, 321);
    expect(measurer.layouts, afterFirst + 1);
  });

  testWidgets('measurers match when what they measure with does', (
    tester,
  ) async {
    late MediaGroupHeaderMeasurer first;
    late MediaGroupHeaderMeasurer second;
    late MediaGroupHeaderMeasurer scaled;
    await tester.pumpWidget(
      testApp(
        child: Builder(
          builder: (context) {
            first = MediaGroupHeaderMeasurer.of(context);
            second = MediaGroupHeaderMeasurer.of(context);
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: Builder(
                builder: (context) {
                  scaled = MediaGroupHeaderMeasurer.of(context);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );

    expect(first.matches(second), isTrue);
    expect(first.matches(scaled), isFalse);
  });

  testWidgets('tapping a navigable header calls back; an inert one has no '
      'tap target', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Column(
          children: [
            MediaGroupHeader(
              spec: specs['navigable dive']!,
              onTap: () => taps++,
            ),
            MediaGroupHeader(spec: specs['inert dive']!, onTap: () => taps++),
          ],
        ),
      ),
    );

    expect(find.byType(InkWell), findsOneWidget);
    await tester.tap(find.text('#9 · Blue Hole').first);
    expect(taps, 1);
  });
}
