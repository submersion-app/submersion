import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/editor_toolbar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _labels = ['Select', 'Smooth', 'Cleanup', 'Draw'];

Future<List<EditorMode>> _pump(
  WidgetTester tester, {
  required double width,
  double textScale = 1.0,
}) async {
  final changes = <EditorMode>[];
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: EditorToolbar(
                mode: EditorMode.select,
                onModeChanged: changes.add,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return changes;
}

void main() {
  // A phone in portrait gave each label a third of a word per line
  // (issue #5056).
  group('EditorToolbar on a phone', () {
    testWidgets('shows icons only, each named by a tooltip', (tester) async {
      final changes = await _pump(tester, width: 400);

      for (final label in _labels) {
        expect(find.text(label), findsNothing);
        expect(find.byTooltip(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Draw'));
      await tester.pumpAndSettle();
      expect(changes, [EditorMode.draw]);
    });

    testWidgets('a large text size drops the labels on a wide screen too', (
      tester,
    ) async {
      await _pump(tester, width: 900, textScale: 2.0);

      for (final label in _labels) {
        expect(find.text(label), findsNothing);
        expect(find.byTooltip(label), findsOneWidget);
      }
    });
  });

  testWidgets('shows the labels when they fit', (tester) async {
    await _pump(tester, width: 900);

    for (final label in _labels) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
