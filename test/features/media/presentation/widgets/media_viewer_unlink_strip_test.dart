import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_unlink_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The strip over an item whose Unlink is held (issue #5126).
void main() {
  Future<void> pump(WidgetTester tester, {VoidCallback? onUndo}) =>
      tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MediaViewerUnlinkStrip(
              message: 'Will be unlinked from this dive when you save',
              onUndo: onUndo,
            ),
          ),
        ),
      );

  testWidgets('Undo is drawn disabled with no callback (a save running)', (
    tester,
  ) async {
    await pump(tester);
    final undo = tester.widget<TextButton>(
      find.byKey(const ValueKey('viewer_unlink_undo')),
    );
    expect(undo.onPressed, isNull);
  });

  testWidgets('Undo calls back when it can', (tester) async {
    var undone = 0;
    await pump(tester, onUndo: () => undone++);
    await tester.tap(find.byKey(const ValueKey('viewer_unlink_undo')));
    expect(undone, 1);
  });

  testWidgets('its message is announced when it appears', (tester) async {
    await pump(tester, onUndo: () {});
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      ),
      findsOneWidget,
    );
  });
}
