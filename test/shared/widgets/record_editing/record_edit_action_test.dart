import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_action.dart';

// The pencil's amber (RecordPencilColors), written out so a change to the
// button's colour source cannot pass by changing both sides at once.
const _lightFill = Color(0xFFFFC107);
const _lightOutline = Color(0xFF7A5200);
const _darkFill = Color(0xFFFFCA28);
const _onFill = Color(0xFF3A2A00);

Widget _host(Widget action, {ThemeData? theme, bool inAppBar = false}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(),
    home: inAppBar
        ? Scaffold(appBar: AppBar(actions: [action]))
        : Scaffold(body: Center(child: action)),
  );
}

Material _material(WidgetTester tester) => tester.widget<Material>(
  find
      .descendant(
        of: find.byType(RecordEditAction),
        matching: find.byType(Material),
      )
      .first,
);

Color _side(WidgetTester tester) =>
    (_material(tester).shape! as OutlinedBorder).side.color;

Color _label(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style!.color!;

void main() {
  for (final (name, theme, fill, outline) in [
    ('light', ThemeData.light(), _lightFill, _lightOutline),
    ('dark', ThemeData.dark(), _darkFill, _darkFill),
  ]) {
    testWidgets("filled draws the pencil's fill, ring and glyph colour "
        '($name)', (tester) async {
      await tester.pumpWidget(
        _host(
          RecordEditAction(label: 'Save', onPressed: () {}),
          theme: theme,
        ),
      );

      expect(_material(tester).color, fill);
      expect(_side(tester), outline);
      expect(_label(tester, 'Save'), _onFill);
    });

    testWidgets("ring draws a transparent ground with the pencil's ring and "
        'its label in that colour ($name)', (tester) async {
      await tester.pumpWidget(
        _host(
          RecordEditAction(
            label: 'Cancel',
            onPressed: () {},
            style: RecordEditActionStyle.ring,
          ),
          theme: theme,
        ),
      );

      expect(_material(tester).color!.a, 0);
      expect(_side(tester), outline);
      expect(_label(tester, 'Cancel'), outline);
    });
  }

  testWidgets('a disabled filled action fades its colours', (tester) async {
    await tester.pumpWidget(
      _host(const RecordEditAction(label: 'Save', onPressed: null)),
    );

    expect(_material(tester).color, _lightFill.withValues(alpha: 0.38));
    expect(_label(tester, 'Save'), _onFill.withValues(alpha: 0.38));
    expect(_side(tester), _lightOutline.withValues(alpha: 0.38));
  });

  testWidgets('a disabled ring fades its colours', (tester) async {
    await tester.pumpWidget(
      _host(
        const RecordEditAction(
          label: 'Cancel',
          onPressed: null,
          style: RecordEditActionStyle.ring,
        ),
      ),
    );

    expect(_label(tester, 'Cancel'), _lightOutline.withValues(alpha: 0.38));
    expect(_side(tester), _lightOutline.withValues(alpha: 0.38));
  });

  testWidgets('busy swaps the label for a spinner in the glyph colour', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const RecordEditAction(label: 'Save', onPressed: null, busy: true)),
    );

    expect(find.text('Save'), findsNothing);
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.color, _onFill);
    // Saving is not "nothing to save": the fill keeps its full strength.
    expect(_material(tester).color, _lightFill);
    expect(find.bySemanticsLabel('Save'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a tap calls onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(RecordEditAction(label: 'Save', onPressed: () => taps++)),
    );

    await tester.tap(find.text('Save'));

    expect(taps, 1);
  });

  testWidgets('a disabled action is a disabled button', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const RecordEditAction(label: 'Save', onPressed: null)),
    );

    expect(
      tester.getSemantics(find.byType(RecordEditAction)),
      isSemantics(
        label: 'Save',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    semantics.dispose();
  });

  // Tropical's primary is its app bar's background, which made a bare
  // TextButton's label vanish (#736, #1231). These bring their own colours.
  testWidgets("the labels keep the pencil's colours in Tropical's app bar", (
    tester,
  ) async {
    final tropical = AppThemeRegistry.presets
        .firstWhere((p) => p.id == 'tropical')
        .lightTheme;
    await tester.pumpWidget(
      MaterialApp(
        theme: tropical,
        home: Scaffold(
          appBar: AppBar(
            actions: [
              RecordEditAction(
                label: 'Cancel',
                onPressed: () {},
                style: RecordEditActionStyle.ring,
              ),
              RecordEditAction(label: 'Save', onPressed: () {}),
            ],
          ),
        ),
      ),
    );

    expect(_label(tester, 'Save'), _onFill);
    expect(_label(tester, 'Cancel'), _lightOutline);
  });
}
