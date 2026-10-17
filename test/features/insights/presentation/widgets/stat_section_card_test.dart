import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('a tappable card shows a chevron and reports taps', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      StatSectionCard(
        title: 'Depth',
        subtitle: 'Deepest dives',
        onTap: () => taps++,
        child: const Text('body'),
      ),
    );
    expect(find.text('Deepest dives'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('body'));
    expect(taps, 1);
  });

  testWidgets('a trailing widget replaces the chevron', (tester) async {
    await pump(
      tester,
      StatSectionCard(
        title: 'Depth',
        onTap: () {},
        trailing: const Icon(Icons.info),
        child: const SizedBox(),
      ),
    );
    expect(find.byIcon(Icons.info), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('a plain card has no chevron', (tester) async {
    await pump(
      tester,
      const StatSectionCard(title: 'Depth', child: SizedBox()),
    );
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('a wide trailing control drops below a long title instead of '
      'squeezing it (#3358)', (tester) async {
    await pump(
      tester,
      const SizedBox(
        width: 320,
        child: StatSectionHeader(
          title: 'Belastung der Ausruestung nach Tauchgaengen',
          subtitle: 'Wie viel jedes Teil getaucht ist',
          trailing: SizedBox(key: Key('control'), width: 220, height: 40),
        ),
      ),
    );

    final title = tester.getRect(
      find.text('Belastung der Ausruestung nach Tauchgaengen'),
    );
    final control = tester.getRect(find.byKey(const Key('control')));
    // The title keeps the full width, so it breaks between words.
    expect(title.width, greaterThan(200));
    expect(control.top, greaterThanOrEqualTo(title.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a header with both a trailing control and a chevron keeps both',
    (tester) async {
      await pump(
        tester,
        const StatSectionHeader(
          title: 'Depth',
          trailing: Icon(Icons.info),
          showChevron: true,
        ),
      );
      expect(find.byIcon(Icons.info), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    },
  );
}
