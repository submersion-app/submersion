import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<({List<String> visited, List<bool> manualTaps})> pumpSheet(
    WidgetTester tester,
  ) async {
    final visited = <String>[];
    final manualTaps = <bool>[];
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showAddDiveBottomSheet(
                    context: context,
                    onLogManually: () => manualTaps.add(true),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/dive-computers',
          builder: (context, state) {
            visited.add('/dive-computers');
            return const Scaffold(body: Text('computers'));
          },
        ),
        GoRoute(
          path: '/dives/scan',
          builder: (context, state) {
            visited.add('/dives/scan');
            return const Scaffold(body: Text('scan'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (visited: visited, manualTaps: manualTaps);
  }

  testWidgets('shows all three add-dive options', (tester) async {
    await pumpSheet(tester);
    expect(find.text('Log Dive Manually'), findsOneWidget);
    expect(find.text('Import from Computer'), findsOneWidget);
    expect(find.text('Scan Paper Log'), findsOneWidget);
  });

  testWidgets('log manually invokes the callback', (tester) async {
    final harness = await pumpSheet(tester);
    await tester.tap(find.text('Log Dive Manually'));
    await tester.pumpAndSettle();
    expect(harness.manualTaps, [true]);
  });

  testWidgets('import from computer navigates', (tester) async {
    final harness = await pumpSheet(tester);
    await tester.tap(find.text('Import from Computer'));
    await tester.pumpAndSettle();
    expect(harness.visited, ['/dive-computers']);
  });

  testWidgets('scan paper log navigates', (tester) async {
    final harness = await pumpSheet(tester);
    await tester.tap(find.text('Scan Paper Log'));
    await tester.pumpAndSettle();
    expect(harness.visited, ['/dives/scan']);
  });
}
