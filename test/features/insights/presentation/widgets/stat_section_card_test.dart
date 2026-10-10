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
}
