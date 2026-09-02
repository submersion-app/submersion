import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          // Pinned: the assertions match English strings.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) => Consumer(
                  builder: (context, ref, _) => DiveFilterSheet(
                    ref: ref,
                    filterProvider: statisticsFilterProvider,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('offers the two new long-range presets', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Last 5 years'), findsOneWidget);
    expect(find.text('Last 10 years'), findsOneWidget);
  });

  testWidgets('Last 5 Years sets a start date five years back', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Last 5 years'));
    await tester.pumpAndSettle();

    // The chip sets local sheet state; read it back off the rendered
    // start-date button rather than the provider, which only sees Apply.
    final now = DateTime.now();
    expect(find.textContaining('${now.year - 5}'), findsWidgets);
  });

  testWidgets('Last 10 Years reaches ten years back', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Last 10 years'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(find.textContaining('${now.year - 10}'), findsWidgets);
  });

  testWidgets('All Time still clears both dates', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Last 5 years'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(find.textContaining('${now.year - 5}'), findsNothing);
  });
}
