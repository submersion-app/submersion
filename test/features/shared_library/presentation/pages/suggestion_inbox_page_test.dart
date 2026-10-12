import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/shared_library/presentation/pages/suggestion_inbox_page.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('lists suggestions by site and opens the review sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          incomingSuggestionsProvider('L').overrideWith(
            (ref) async => [
              SharedSiteSuggestion(
                id: 'g',
                libraryId: 'L',
                siteId: 's',
                memberId: 'r',
                memberName: 'Ray',
                note: 'please',
                fields: const {'hazards': 'new'},
                createdAt: DateTime.utc(2026, 10, 1),
                direction: SharedSiteSuggestion.incoming,
              ),
            ],
          ),
          siteProvider('s').overrideWith(
            (ref) async => const DiveSite(
              id: 's',
              name: 'Blue',
              hazards: 'old',
              sharedLibraryId: 'L',
            ),
          ),
          suggestionDiffProvider(
            'g',
          ).overrideWith((ref) async => {'hazards': ('old', 'new')}),
        ],
        locale: const Locale('en'),
        child: const SuggestionInboxPage(libraryId: 'L'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Blue'), findsOneWidget);
    expect(find.textContaining('From Ray'), findsOneWidget);
    expect(find.text('please'), findsOneWidget);

    await tester.tap(find.textContaining('From Ray'));
    await tester.pumpAndSettle();
    expect(find.text('old'), findsOneWidget);
    expect(find.text('new'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
  });

  testWidgets('empty inbox', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          incomingSuggestionsProvider(
            'L',
          ).overrideWith((ref) async => const []),
        ],
        locale: const Locale('en'),
        child: const SuggestionInboxPage(libraryId: 'L'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No suggestions waiting.'), findsOneWidget);
  });
}
