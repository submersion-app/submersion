import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/widgets/settings_value_tile.dart';

void main() {
  Widget host(Widget tile, {double width = 400}) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: tile),
      ),
    ),
  );

  testWidgets('a short value keeps its natural width on one line', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(SettingsValueTile(title: 'Depth', value: 'm', onTap: () {})),
    );

    final value = tester.renderObject<RenderParagraph>(find.text('m'));
    expect(value.didExceedMaxLines, isFalse);
    expect(tester.getSize(find.text('m')).width, lessThan(40));
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('a long value is capped so the subtitle keeps its room', (
    tester,
  ) async {
    const description =
        'How dive details and statistics describe the visibility you '
        'measured';
    await tester.pumpWidget(
      host(
        SettingsValueTile(
          title: 'Visibility scale',
          subtitle: description,
          value: 'A very long preset name that would starve the subtitle',
          onTap: () {},
        ),
      ),
    );

    final tileWidth = tester.getSize(find.byType(ListTile)).width;
    final trailingWidth = tester.getSize(find.byType(Row)).width;
    expect(
      trailingWidth,
      lessThanOrEqualTo(tileWidth * SettingsValueTile.maxValueWidthFraction),
    );
    expect(
      tester.getSize(find.text(description)).width,
      greaterThan(tileWidth * 0.45),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the row calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(SettingsValueTile(title: 'Depth', value: 'm', onTap: () => taps++)),
    );

    await tester.tap(find.text('Depth'));
    expect(taps, 1);
  });

  // ListTile caps `trailing` at 56 px tall. At a large text scale two lines
  // of the value no longer fit, so the value drops to the lines that do
  // instead of painting over the next row.
  testWidgets('at a large text scale the value stays inside its box', (
    tester,
  ) async {
    const value = 'DD.MM.YYYY HH:MM';
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: host(
          SettingsValueTile(title: 'Date format', value: value, onTap: () {}),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(find.text(value));
    expect(paragraph.textSize.height, lessThanOrEqualTo(paragraph.size.height));
    expect(paragraph.size.height, lessThanOrEqualTo(56));
    expect(tester.takeException(), isNull);
  });
}
