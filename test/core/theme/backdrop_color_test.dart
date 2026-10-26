import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/backdrop_color.dart';
import 'package:submersion/core/theme/full_themes/submersion_theme.dart';

/// Pumps [child] under [theme] and returns what [backdropColorOf] resolves
/// at the probe inside it.
Future<Color> _backdrop(
  WidgetTester tester,
  ThemeData theme,
  Widget Function(Widget probe) wrap,
) async {
  late Color resolved;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: wrap(
          Builder(
            builder: (context) {
              resolved = backdropColorOf(context);
              return const SizedBox(width: 10, height: 10);
            },
          ),
        ),
      ),
    ),
  );
  return resolved;
}

void main() {
  final theme = submersionDark;

  testWidgets('outside a card it is the page surface', (tester) async {
    expect(await _backdrop(tester, theme, (p) => p), theme.colorScheme.surface);
  });

  testWidgets('inside a default card it is the card fill', (tester) async {
    expect(
      await _backdrop(tester, theme, (p) => Card(child: p)),
      theme.colorScheme.surfaceContainerLow,
    );
  });

  // The presets give cards their own colour (Console dark #1A2230 on a
  // #141A22 page).
  testWidgets('a themed card colour wins over the default', (tester) async {
    const card = Color(0xFF1A2230);
    expect(
      await _backdrop(
        tester,
        theme.copyWith(cardTheme: const CardThemeData(color: card)),
        (p) => Card(child: p),
      ),
      card,
    );
  });

  testWidgets('a card colour of its own wins over the theme', (tester) async {
    const own = Color(0xFF203040);
    expect(
      await _backdrop(
        tester,
        theme.copyWith(cardTheme: const CardThemeData(color: Colors.red)),
        (p) => Card(color: own, child: p),
      ),
      own,
    );
  });

  // Deep dark's cards are translucent over the page.
  testWidgets('a translucent card is composited over the page', (tester) async {
    const card = Color(0x80FFFFFF);
    expect(
      await _backdrop(
        tester,
        theme.copyWith(cardTheme: const CardThemeData(color: card)),
        (p) => Card(child: p),
      ),
      Color.alphaBlend(card, theme.colorScheme.surface),
    );
  });
}
