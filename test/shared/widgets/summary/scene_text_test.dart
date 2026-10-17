import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/summary/scene_text.dart';

const _ink = Color(0xFF123456);

Future<void> _pump(WidgetTester tester, Widget child, {ThemeData? theme}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SceneInk(color: _ink, child: child),
      ),
    ),
  );
}

TextStyle _styleOf(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)).first,
  );
  return rich.text.style!;
}

void main() {
  testWidgets('SceneLink is a button with the given label that calls onTap', (
    tester,
  ) async {
    var tapped = false;
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      SceneLink(
        text: '41.2 m',
        onTap: () => tapped = true,
        semanticsLabel: 'open deepest dive',
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('open deepest dive')),
      matchesSemantics(
        label: 'open deepest dive',
        isButton: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.text('41.2 m'));
    expect(tapped, isTrue);
    handle.dispose();
  });

  testWidgets('SceneLink underlines dotted in the ink colour at half opacity', (
    tester,
  ) async {
    await _pump(
      tester,
      SceneLink(text: 'Blue Hole', onTap: () {}, semanticsLabel: 'Blue Hole'),
    );

    final style = _styleOf(tester, 'Blue Hole');
    expect(style.decoration, TextDecoration.underline);
    expect(style.decorationStyle, TextDecorationStyle.dotted);
    expect(style.decorationColor, _ink.withValues(alpha: 0.5));
  });

  testWidgets('scene text takes the preset text family at weight 300', (
    tester,
  ) async {
    await _pump(
      tester,
      const SceneHeadline('214 dives'),
      theme: ThemeData(fontFamily: 'Nunito'),
    );

    final style = _styleOf(tester, '214 dives');
    expect(style.fontFamily, 'Nunito');
    expect(style.fontWeight, FontWeight.w300);
    expect(style.color, _ink);
  });

  testWidgets('scene text falls back to onSurface without a SceneInk', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SceneLabel('sites'))),
    );
    final context = tester.element(find.text('sites'));
    expect(
      _styleOf(tester, 'sites').color,
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
    );
  });

  testWidgets('SceneFooter is bodySmall in the ink at 60 percent', (
    tester,
  ) async {
    await _pump(tester, const SceneFooter('41 with GPS'));

    final style = _styleOf(tester, '41 with GPS');
    final context = tester.element(find.text('41 with GPS'));
    expect(style.fontSize, Theme.of(context).textTheme.bodySmall!.fontSize);
    expect(style.color, _ink.withValues(alpha: 0.6));
  });
}
