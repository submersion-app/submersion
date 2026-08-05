import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('FormSection v2', () {
    testWidgets('expanded: title, icon, children and up-chevron; no summary', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormSection(
            label: 'Gas & Gear',
            icon: Icons.waves,
            expanded: true,
            onToggle: () {},
            summary: 'the summary',
            children: const [Text('row one'), Text('row two')],
          ),
        ),
      );
      expect(find.text('Gas & Gear'), findsOneWidget);
      expect(find.byIcon(Icons.waves), findsOneWidget);
      expect(find.text('row one'), findsOneWidget);
      expect(find.text('row two'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.text('the summary'), findsNothing);
    });

    testWidgets('collapsed with data: summary + down-chevron, no children', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormSection(
            label: 'Conditions',
            expanded: false,
            onToggle: () {},
            summary: 'Salt water',
            children: const [Text('row one')],
          ),
        ),
      );
      expect(find.text('Conditions'), findsOneWidget);
      expect(find.text('Salt water'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.text('row one'), findsNothing);
    });

    testWidgets('collapsed empty: invitation shown in header', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormSection(
            label: 'Buddies',
            expanded: false,
            onToggle: () {},
            isEmpty: true,
            emptyInvitation: 'Add buddies',
            children: const [Text('row one')],
          ),
        ),
      );
      expect(find.text('Add buddies'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.text('row one'), findsNothing);
    });

    testWidgets('collapsed with errors: issue badge replaces summary', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormSection(
            label: 'Location',
            expanded: false,
            onToggle: () {},
            summary: '12.0, -68.2',
            errorCount: 2,
            children: const [Text('row one')],
          ),
        ),
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('2 issues'), findsOneWidget);
      expect(find.text('12.0, -68.2'), findsNothing);
    });

    testWidgets('no badge when errorCount is zero', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormSection(
            label: 'Gas & Gear',
            expanded: false,
            onToggle: () {},
            summary: '2x AL80',
            children: const [Text('row one')],
          ),
        ),
      );
      expect(find.textContaining('issue'), findsNothing);
    });

    testWidgets('tapping the header title toggles', (tester) async {
      var toggled = 0;
      await tester.pumpWidget(
        _wrap(
          FormSection(
            label: 'Trip',
            expanded: false,
            onToggle: () => toggled++,
            summary: 'Bonaire',
            children: const [Text('row one')],
          ),
        ),
      );
      await tester.tap(find.text('Trip'));
      expect(toggled, 1);
    });

    testWidgets('tapping the summary also toggles (same header target)', (
      tester,
    ) async {
      var toggled = 0;
      await tester.pumpWidget(
        _wrap(
          FormSection(
            label: 'Conditions',
            expanded: false,
            onToggle: () => toggled++,
            summary: 'Salt - 24 C',
            children: const [Text('row one')],
          ),
        ),
      );
      await tester.tap(find.text('Salt - 24 C'));
      expect(toggled, 1);
    });

    testWidgets('always-open section: no chevron, header not tappable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FormSection(
            label: 'The Dive',
            expanded: true,
            onToggle: null,
            children: [Text('row one')],
          ),
        ),
      );
      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      expect(
        find.descendant(
          of: find.byType(FormSection),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('header semantics: button labeled with title', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          FormSection(
            label: 'Experience',
            expanded: false,
            onToggle: () {},
            summary: 'stars',
            children: const [Text('row one')],
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Experience'))),
        isSemantics(isButton: true),
      );
      handle.dispose();
    });
  });
}
