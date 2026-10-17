import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/widgets/gradient_factor_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Opens the dialog from a button so Cancel and Save can pop it.
Future<List<(int, int)>> _open(
  WidgetTester tester, {
  required int low,
  required int high,
}) async {
  await tester.binding.setSurfaceSize(const Size(600, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final saved = <(int, int)>[];
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => GradientFactorDialog(
              initialGfLow: low,
              initialGfHigh: high,
              onSave: (l, h) => saved.add((l, h)),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return saved;
}

/// Whether the preset card labelled [name] is drawn as the selected one.
bool _highlighted(WidgetTester tester, String name) {
  final cards = tester.widgetList<Container>(
    find.ancestor(of: find.text(name), matching: find.byType(Container)),
  );
  return cards.any(
    (c) =>
        c.decoration is BoxDecoration &&
        (c.decoration! as BoxDecoration).border != null,
  );
}

Slider _slider(WidgetTester tester, int index) =>
    tester.widgetList<Slider>(find.byType(Slider)).elementAt(index);

void main() {
  group('GfPreset', () {
    test('fromValues matches presets and falls back to custom', () {
      expect(GfPreset.fromValues(50, 75), GfPreset.high);
      expect(GfPreset.fromValues(50, 85), GfPreset.medium);
      expect(GfPreset.fromValues(50, 95), GfPreset.low);
      expect(GfPreset.fromValues(30, 70), GfPreset.custom);
    });

    test('custom never matches', () {
      expect(GfPreset.custom.matches(0, 0), isFalse);
    });
  });

  testWidgets('shows the three presets and the current values', (tester) async {
    await _open(tester, low: 30, high: 70);

    expect(find.text('Gradient Factors'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(_slider(tester, 0).value, 30);
    expect(_slider(tester, 1).value, 70);
  });

  testWidgets('picking a preset sets both values and Save reports them', (
    tester,
  ) async {
    final saved = await _open(tester, low: 30, high: 70);

    await tester.tap(find.text('Medium'));
    await tester.pumpAndSettle();
    expect(_slider(tester, 0).value, 50);
    expect(_slider(tester, 1).value, 85);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, [(50, 85)]);
    expect(find.byType(GradientFactorDialog), findsNothing);
  });

  testWidgets('raising GF low above GF high pulls high up with it', (
    tester,
  ) async {
    final saved = await _open(tester, low: 30, high: 70);

    _slider(tester, 0).onChanged!(80);
    await tester.pumpAndSettle();
    expect(_slider(tester, 0).value, 80);
    expect(_slider(tester, 1).value, 80);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, [(80, 80)]);
  });

  testWidgets('lowering GF high below GF low pulls low down with it', (
    tester,
  ) async {
    final saved = await _open(tester, low: 50, high: 85);

    _slider(tester, 1).onChanged!(40);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, [(40, 40)]);
  });

  testWidgets('moving a slider onto a preset selects it', (tester) async {
    await _open(tester, low: 50, high: 70);
    expect(_highlighted(tester, 'High'), isFalse);

    _slider(tester, 1).onChanged!(75);
    await tester.pumpAndSettle();

    expect(_highlighted(tester, 'High'), isTrue);
    expect(_highlighted(tester, 'Medium'), isFalse);

    _slider(tester, 1).onChanged!(76);
    await tester.pumpAndSettle();
    expect(_highlighted(tester, 'High'), isFalse);
  });

  testWidgets('Cancel closes without saving', (tester) async {
    final saved = await _open(tester, low: 30, high: 70);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(saved, isEmpty);
    expect(find.byType(GradientFactorDialog), findsNothing);
  });
}
