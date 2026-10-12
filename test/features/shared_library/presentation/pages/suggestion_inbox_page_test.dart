import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/shared_library/presentation/pages/suggestion_inbox_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/suggestion_review_sheet.dart';

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

  testWidgets('the review sheet names fields and shows the diver\'s units', (
    tester,
  ) async {
    final suggestion = SharedSiteSuggestion(
      id: 'g',
      libraryId: 'L',
      siteId: 's',
      memberId: 'r',
      memberName: 'Ray',
      fields: const {
        'maxDepth': 30.0,
        'tags': ['Wreck'],
      },
      createdAt: DateTime.utc(2026, 10, 1),
      direction: SharedSiteSuggestion.incoming,
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(
            settingsNotifier: MockSettingsNotifier(
              const AppSettings(depthUnit: DepthUnit.feet),
            ),
          ),
          suggestionDiffProvider('g').overrideWith(
            (ref) async => {
              'maxDepth': (18.0, 30.0),
              'tags': (const ['Reef'], const ['Wreck']),
            },
          ),
        ],
        locale: const Locale('en'),
        child: SuggestionReviewSheet(suggestion: suggestion, siteGone: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('maxDepth'), findsNothing);
    expect(find.text('tags'), findsNothing);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Max Depth'), findsOneWidget);
    expect(find.text('59.1ft'), findsOneWidget);
    expect(find.text('98.4ft'), findsOneWidget);
    expect(find.text('Wreck'), findsOneWidget);
  });
}
