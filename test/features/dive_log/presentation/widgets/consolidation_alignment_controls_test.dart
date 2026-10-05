import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/consolidation_alignment_controls.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The English locale is pinned: flutter_test forwards the host machine's
/// locale list, and a translated UI would make every find.text miss.
Future<void> _pump(WidgetTester tester, Widget child, {double width = 400}) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

void main() {
  group('CombineModeSelector', () {
    testWidgets('reports the tapped mode', (tester) async {
      CombineMode? picked;
      await _pump(
        tester,
        CombineModeSelector(
          mode: CombineMode.join,
          onChanged: (m) => picked = m,
        ),
      );
      await tester.tap(find.text('Merge as another computer'));
      expect(picked, CombineMode.merge);
    });

    testWidgets('shows the same-dive hint only when asked', (tester) async {
      const hint =
          'These profiles look like the same dive recorded by two computers.';
      await _pump(
        tester,
        CombineModeSelector(mode: CombineMode.merge, onChanged: (_) {}),
      );
      expect(find.text(hint), findsNothing);
      await _pump(
        tester,
        CombineModeSelector(
          mode: CombineMode.merge,
          onChanged: (_) {},
          showSameDiveHint: true,
        ),
      );
      expect(find.text(hint), findsOneWidget);
    });

    testWidgets('fits a phone-width dialog without overflowing', (
      tester,
    ) async {
      await _pump(
        tester,
        CombineModeSelector(mode: CombineMode.join, onChanged: (_) {}),
        width: 262,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('compact (phone-width) layout', () {
    testWidgets('the mode selector shortens its labels', (tester) async {
      await _pump(
        tester,
        CombineModeSelector(mode: CombineMode.join, onChanged: (_) {}),
        width: 262,
      );
      expect(find.text('Join'), findsOneWidget);
      expect(find.text('Merge'), findsOneWidget);
      expect(find.text('Join into one dive'), findsNothing);
    });

    testWidgets('the alignment controls shorten the toggle, drop the label '
        'and fold the clock note into one line', (tester) async {
      ConsolidationAlignment? picked;
      await _pump(
        tester,
        ConsolidationAlignmentControls(
          alignment: ConsolidationAlignment.bestFit,
          onChanged: (a) => picked = a,
        ),
        width: 262,
      );
      expect(find.text('Best fit'), findsOneWidget);
      expect(find.text('Starts'), findsOneWidget);
      expect(find.text('Line up the records by'), findsNothing);
      expect(
        find.text("One computer's clock is probably off."),
        findsOneWidget,
      );
      expect(find.textContaining('keeps the primary'), findsNothing);

      await tester.tap(find.text('Starts'));
      expect(picked, ConsolidationAlignment.starts);
    });

    testWidgets('tapping the short clock note shows the full text', (
      tester,
    ) async {
      await _pump(
        tester,
        ConsolidationAlignmentControls(
          alignment: ConsolidationAlignment.bestFit,
          onChanged: (_) {},
        ),
        width: 262,
      );
      await tester.tap(find.text("One computer's clock is probably off."));
      await tester.pumpAndSettle();
      expect(find.textContaining('keeps the primary'), findsOneWidget);
    });

    testWidgets('a desktop-width dialog keeps the full labels', (tester) async {
      await _pump(
        tester,
        ConsolidationAlignmentControls(
          alignment: ConsolidationAlignment.bestFit,
          onChanged: (_) {},
        ),
        width: 472,
      );
      expect(find.text('Align starts'), findsOneWidget);
      expect(find.text('Line up the records by'), findsOneWidget);
    });
  });

  group('ConsolidationAlignmentControls', () {
    testWidgets('shows the clock note and reports the tapped alignment', (
      tester,
    ) async {
      ConsolidationAlignment? picked;
      await _pump(
        tester,
        ConsolidationAlignmentControls(
          alignment: ConsolidationAlignment.bestFit,
          onChanged: (a) => picked = a,
        ),
      );
      expect(find.textContaining("don't overlap in time"), findsOneWidget);
      expect(find.text('Line up the records by'), findsOneWidget);
      await tester.tap(find.text('Align starts'));
      expect(picked, ConsolidationAlignment.starts);
    });

    testWidgets('shows the no-profile note only when asked', (tester) async {
      const note =
          'A record has no depth profile to match, so its start is lined up '
          "with the primary's.";
      await _pump(
        tester,
        ConsolidationAlignmentControls(
          alignment: ConsolidationAlignment.bestFit,
          onChanged: (_) {},
        ),
      );
      expect(find.text(note), findsNothing);
      await _pump(
        tester,
        ConsolidationAlignmentControls(
          alignment: ConsolidationAlignment.bestFit,
          onChanged: (_) {},
          showFallbackNote: true,
        ),
      );
      expect(find.text(note), findsOneWidget);
    });

    testWidgets('fits a phone-width dialog without overflowing', (
      tester,
    ) async {
      await _pump(
        tester,
        ConsolidationAlignmentControls(
          alignment: ConsolidationAlignment.starts,
          onChanged: (_) {},
          showFallbackNote: true,
        ),
        width: 262,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
