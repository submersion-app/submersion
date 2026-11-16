import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/dive_types/presentation/widgets/dive_type_favourite_button.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Favourite dive types first in the dive type checklist (issue #4413).
void main() {
  DiveTypeEntity type(String id, String name) => DiveTypeEntity(
    id: id,
    name: name,
    isBuiltIn: true,
    createdAt: DateTime.utc(2024),
    updatedAt: DateTime.utc(2024),
  );

  Widget harness({
    required List<String> selected,
    required MockSettingsNotifier settings,
    ValueChanged<List<String>>? onChanged,
  }) => ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => settings),
      diveTypesProvider.overrideWith(
        (ref) async => [
          type('shore', 'Shore'),
          type('wreck', 'Wreck'),
          type('night', 'Night'),
        ],
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DiveTypeMultiSelectField(
          selectedTypeIds: selected,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    ),
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();
  }

  List<String> rowTitles(WidgetTester tester) => [
    for (final tile in tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    ))
      (tile.title! as Text).data!,
  ];

  testWidgets('favourites come first under a Favorites heading', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        selected: ['shore'],
        settings: MockSettingsNotifier(
          const AppSettings(favouriteDiveTypeIds: {'night'}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openSheet(tester);
    expect(rowTitles(tester), ['Night', 'Shore', 'Wreck']);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('the star is its own accessible button, apart from the row', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      harness(
        selected: ['shore'],
        settings: MockSettingsNotifier(
          const AppSettings(favouriteDiveTypeIds: {'night'}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openSheet(tester);

    // Not merged into the checkbox row: no checked state, its own label.
    expect(
      tester.getSemantics(find.byKey(diveTypeFavouriteButtonKey('wreck'))),
      isSemantics(
        isButton: true,
        hasCheckedState: false,
        tooltip: 'Add Wreck to favorites',
      ),
    );
    expect(
      tester.getSemantics(find.text('Favorites')),
      isSemantics(isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('with no favourites the checklist keeps its order', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(selected: ['shore'], settings: MockSettingsNotifier()),
    );
    await tester.pumpAndSettle();
    await openSheet(tester);
    expect(rowTitles(tester), ['Shore', 'Wreck', 'Night']);
    expect(find.text('Favorites'), findsNothing);
  });

  testWidgets('a starred id matching no type shows no heading', (tester) async {
    await tester.pumpWidget(
      harness(
        selected: ['shore'],
        settings: MockSettingsNotifier(
          const AppSettings(favouriteDiveTypeIds: {'deleted-type'}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openSheet(tester);
    expect(rowTitles(tester), ['Shore', 'Wreck', 'Night']);
    expect(find.text('Favorites'), findsNothing);
  });

  testWidgets('a hidden favourite stays out unless the dive has it', (
    tester,
  ) async {
    const hiddenStarred = AppSettings(
      favouriteDiveTypeIds: {'night'},
      hiddenBuiltInIds: {
        'diveTypes': {'night'},
      },
    );
    await tester.pumpWidget(
      harness(
        selected: ['shore'],
        settings: MockSettingsNotifier(hiddenStarred),
      ),
    );
    await tester.pumpAndSettle();
    await openSheet(tester);
    expect(rowTitles(tester), ['Shore', 'Wreck']);
    expect(find.text('Favorites'), findsNothing);
  });

  testWidgets('a hidden favourite the dive has sits under the heading', (
    tester,
  ) async {
    const hiddenStarred = AppSettings(
      favouriteDiveTypeIds: {'night'},
      hiddenBuiltInIds: {
        'diveTypes': {'night'},
      },
    );
    await tester.pumpWidget(
      harness(
        selected: ['night'],
        settings: MockSettingsNotifier(hiddenStarred),
      ),
    );
    await tester.pumpAndSettle();
    await openSheet(tester);
    expect(rowTitles(tester), ['Night', 'Shore', 'Wreck']);
    expect(find.text('Favorites'), findsOneWidget);
  });

  testWidgets(
    'starring in the open sheet saves at once without moving or ticking',
    (tester) async {
      final settings = MockSettingsNotifier();
      final changes = <List<String>>[];
      await tester.pumpWidget(
        harness(
          selected: ['shore'],
          settings: settings,
          onChanged: changes.add,
        ),
      );
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.tap(find.byKey(diveTypeFavouriteButtonKey('wreck')));
      await tester.pumpAndSettle();

      expect(settings.state.favouriteDiveTypeIds, {'wreck'});
      expect(
        find.descendant(
          of: find.byKey(diveTypeFavouriteButtonKey('wreck')),
          matching: find.byIcon(Icons.star),
        ),
        findsOneWidget,
      );
      expect(rowTitles(tester), ['Shore', 'Wreck', 'Night']);
      final wreck = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Wreck'),
      );
      expect(wreck.value, isFalse);
      expect(changes, isEmpty);

      // Reopened, the newly starred type leads under the heading.
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await openSheet(tester);
      expect(rowTitles(tester), ['Wreck', 'Shore', 'Night']);
      expect(find.text('Favorites'), findsOneWidget);
    },
  );
}
