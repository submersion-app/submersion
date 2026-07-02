import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

final _testStatsFilter = StateProvider<DiveFilterState>(
  (ref) => const DiveFilterState(),
);

void main() {
  group('DiveFilterSheet filterProvider parameterization', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    testWidgets('sheet writes the provider passed to filterProvider', (
      tester,
    ) async {
      late WidgetRef capturedRef;
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return Center(
                    child: ElevatedButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => DiveFilterSheet(
                          ref: ref,
                          filterProvider: _testStatsFilter,
                        ),
                      ),
                      child: const Text('Open filter'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open filter'));
      await tester.pumpAndSettle();

      // The sheet's ListView is taller than the modal viewport, so scroll
      // each target into view before interacting with it.
      final scrollable = find.byType(Scrollable).first;

      // Toggle "Favorites Only" and apply.
      await tester.scrollUntilVisible(
        find.text('Favorites Only'),
        50.0,
        scrollable: scrollable,
      );
      await tester.ensureVisible(find.text('Favorites Only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favorites Only'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Apply Filters'),
        50.0,
        scrollable: scrollable,
      );
      await tester.ensureVisible(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(capturedRef.read(_testStatsFilter).favoritesOnly, true);
    });

    testWidgets('Last 12 months preset sets a start date and applies', (
      tester,
    ) async {
      late WidgetRef capturedRef;
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return Center(
                    child: ElevatedButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => DiveFilterSheet(
                          ref: ref,
                          filterProvider: _testStatsFilter,
                        ),
                      ),
                      child: const Text('Open filter'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open filter'));
      await tester.pumpAndSettle();

      // The sheet's ListView is taller than the modal viewport, so scroll
      // each target into view before interacting with it.
      final scrollable = find.byType(Scrollable).first;

      await tester.scrollUntilVisible(
        find.text('Last 12 months'),
        50.0,
        scrollable: scrollable,
      );
      await tester.ensureVisible(find.text('Last 12 months'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last 12 months'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Apply Filters'),
        50.0,
        scrollable: scrollable,
      );
      await tester.ensureVisible(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(capturedRef.read(_testStatsFilter).startDate, isNotNull);
    });
  });
}
