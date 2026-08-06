import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/full_themes/tropical_theme.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    ThemeData theme,
    Widget action, {
    Color? appBarForeground,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          appBar: AppBar(
            foregroundColor: appBarForeground,
            title: const Text('Title'),
            actions: [action],
          ),
        ),
      ),
    );
  }

  Color renderedColor(WidgetTester tester, String label) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
    final style = paragraph.text.style;
    expect(
      style,
      isNotNull,
      reason: 'the rendered span for "$label" carries no TextStyle',
    );
    final color = style!.color;
    expect(
      color,
      isNotNull,
      reason: 'the TextStyle for "$label" resolved to a null color',
    );
    return color!;
  }

  testWidgets('bare TextButton is invisible on the tropical app bar '
      '(the #736 defect this widget exists to avoid)', (tester) async {
    await pump(
      tester,
      tropicalLight,
      TextButton(onPressed: () {}, child: const Text('Save')),
    );
    expect(
      renderedColor(tester, 'Save'),
      tropicalLight.appBarTheme.backgroundColor,
      reason:
          'colorScheme.primary equals the app bar background in the '
          'tropical theme, so a bare TextButton renders invisibly',
    );
  });

  testWidgets('AppBarTextAction stays visible against the tropical app bar', (
    tester,
  ) async {
    await pump(
      tester,
      tropicalLight,
      AppBarTextAction(label: 'Save', onPressed: () {}),
    );
    final color = renderedColor(tester, 'Save');
    expect(color, tropicalLight.appBarTheme.foregroundColor);
    expect(color, isNot(tropicalLight.appBarTheme.backgroundColor));
  });

  testWidgets(
    'AppBarTextAction honors a per-app-bar foregroundColor override',
    (tester) async {
      const override = Color(0xFFAA0000);
      await pump(
        tester,
        tropicalLight,
        AppBarTextAction(label: 'Save', onPressed: () {}),
        appBarForeground: override,
      );
      expect(
        renderedColor(tester, 'Save'),
        override,
        reason:
            'an AppBar.foregroundColor override sits ahead of '
            'AppBarTheme.foregroundColor in the app bar resolution chain',
      );
    },
  );

  testWidgets(
    'AppBarTextAction uses the emphasized foreground when a theme sets no '
    'app bar foreground color',
    (tester) async {
      final theme = ThemeData(useMaterial3: true);
      await pump(
        tester,
        theme,
        AppBarTextAction(label: 'Save', onPressed: () {}),
      );
      expect(theme.appBarTheme.foregroundColor, isNull);
      expect(renderedColor(tester, 'Save'), theme.colorScheme.onSurface);
      expect(
        renderedColor(tester, 'Save'),
        isNot(theme.colorScheme.onSurfaceVariant),
        reason:
            'the actions IconTheme resolves to the de-emphasized '
            'onSurfaceVariant under Material 3, which is wrong for a text '
            'action and must not be used as the color source',
      );
    },
  );

  testWidgets('AppBarTextAction invokes onPressed', (tester) async {
    var tapped = false;
    await pump(
      tester,
      tropicalLight,
      AppBarTextAction(label: 'Save', onPressed: () => tapped = true),
    );
    await tester.tap(find.text('Save'));
    expect(tapped, isTrue);
  });
}
