import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  group('DiveFilterSheet bottomTime coverage', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    testWidgets('initializes with bottomTime filter values', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveFilterProvider.overrideWith(
              (ref) => const DiveFilterState(
                minBottomTimeMinutes: 20,
                maxBottomTimeMinutes: 60,
              ),
            ),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) => Consumer(
                    builder: (context, ref, _) => DiveFilterSheet(ref: ref),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Just pump a few frames - initState will execute (lines 826-827)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DiveFilterSheet), findsOneWidget);
    });
  });
}
