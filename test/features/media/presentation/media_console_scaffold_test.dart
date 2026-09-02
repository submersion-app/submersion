import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/media_console_scaffold.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host({
    required MediaConsoleSection selected,
    required ValueChanged<MediaConsoleSection> onSelect,
    Map<MediaConsoleSection, int> badgeCounts = const {},
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaConsoleScaffold(
          selected: selected,
          onSelect: onSelect,
          badgeCounts: badgeCounts,
          child: const Text('CONTENT'),
        ),
      ),
    );
  }

  void setWidth(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('the console has exactly four destinations', () {
    // Unlinked media no longer exists and Missing files is a Library chip,
    // so neither gets a sidebar entry.
    expect(MediaConsoleSection.values, [
      MediaConsoleSection.library,
      MediaConsoleSection.sources,
      MediaConsoleSection.transfers,
      MediaConsoleSection.importMedia,
    ]);
  });

  testWidgets('wide layout shows sidebar entries, no tabs', (tester) async {
    setWidth(tester, 1100);
    await tester.pumpWidget(
      host(selected: MediaConsoleSection.library, onSelect: (_) {}),
    );
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Transfers'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('CONTENT'), findsOneWidget);
  });

  testWidgets('narrow layout shows tabs instead of sidebar', (tester) async {
    setWidth(tester, 500);
    await tester.pumpWidget(
      host(selected: MediaConsoleSection.library, onSelect: (_) {}),
    );
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('CONTENT'), findsOneWidget);
  });

  testWidgets('tapping a sidebar entry fires onSelect', (tester) async {
    setWidth(tester, 1100);
    MediaConsoleSection? tapped;
    await tester.pumpWidget(
      host(selected: MediaConsoleSection.library, onSelect: (s) => tapped = s),
    );
    await tester.tap(find.text('Transfers'));
    expect(tapped, MediaConsoleSection.transfers);
  });

  testWidgets('tapping a tab fires onSelect', (tester) async {
    setWidth(tester, 500);
    MediaConsoleSection? tapped;
    await tester.pumpWidget(
      host(selected: MediaConsoleSection.library, onSelect: (s) => tapped = s),
    );
    // The tab strip scrolls at phone width -- later sections sit off-screen
    // until dragged into view.
    await tester.ensureVisible(find.text('Transfers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfers'));
    expect(tapped, MediaConsoleSection.transfers);
  });

  testWidgets('badge count renders when nonzero', (tester) async {
    setWidth(tester, 1100);
    await tester.pumpWidget(
      host(
        selected: MediaConsoleSection.library,
        onSelect: (_) {},
        badgeCounts: const {MediaConsoleSection.transfers: 3},
      ),
    );
    expect(find.text('3'), findsOneWidget);
  });
}
