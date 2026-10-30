import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/widgets/hypercapnia_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

typedef _SavedCall = ({bool enabled, double factor, int minutes});

Widget _app({
  bool initialEnabled = false,
  double initialFactor = 4.0,
  int initialMinutes = 5,
  required void Function(_SavedCall) onSave,
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => HypercapniaDialog(
            initialEnabled: initialEnabled,
            initialFactor: initialFactor,
            initialMinutes: initialMinutes,
            onSave: (enabled, factor, minutes) =>
                onSave((enabled: enabled, factor: factor, minutes: minutes)),
          ),
        ),
        child: const Text('open'),
      ),
    ),
  ),
);

Slider _slider(WidgetTester tester, int index) =>
    tester.widgetList<Slider>(find.byType(Slider)).elementAt(index);

/// The Settings dialog for the hypercapnia-bailout phase (issue #3743).
void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the sliders are disabled until the toggle is on', (
    tester,
  ) async {
    await tester.pumpWidget(_app(onSave: (_) {}));
    await open(tester);

    expect(_slider(tester, 0).onChanged, isNull);
    expect(_slider(tester, 1).onChanged, isNull);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(_slider(tester, 0).onChanged, isNotNull);
    expect(_slider(tester, 1).onChanged, isNotNull);
  });

  testWidgets('Save reports the toggle and the current values', (tester) async {
    final saved = <_SavedCall>[];
    await tester.pumpWidget(
      _app(initialFactor: 3.0, initialMinutes: 7, onSave: saved.add),
    );
    await open(tester);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, [(enabled: true, factor: 3.0, minutes: 7)]);
    expect(find.byType(HypercapniaDialog), findsNothing);
  });

  testWidgets('Cancel saves nothing', (tester) async {
    final saved = <_SavedCall>[];
    await tester.pumpWidget(_app(onSave: saved.add));
    await open(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(saved, isEmpty);
  });

  testWidgets('out-of-range initial values open clamped to the slider '
      'range', (tester) async {
    final saved = <_SavedCall>[];
    await tester.pumpWidget(
      _app(
        initialEnabled: true,
        initialFactor: 20,
        initialMinutes: 0,
        onSave: saved.add,
      ),
    );
    await open(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, [(enabled: true, factor: 10.0, minutes: 1)]);
  });
}
