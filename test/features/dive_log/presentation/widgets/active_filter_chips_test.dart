import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/active_filter_chips.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _otherFilterProvider = StateProvider<DiveFilterState>(
  (ref) => DiveFilterState(
    startDate: DateTime(2021),
    endDate: DateTime(2024, 12, 31),
    favoritesOnly: true,
  ),
);

void main() {
  testWidgets('chips edit the provider they are given, not the dive list', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Wrap(
                children: activeDiveFilterChips(
                  context,
                  ref,
                  _otherFilterProvider,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Chip), findsNWidgets(2));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    final after = container.read(_otherFilterProvider);
    expect(after.startDate, isNull);
    expect(after.endDate, isNull);
    expect(after.favoritesOnly, isTrue);
    expect(container.read(diveFilterProvider).hasActiveFilters, isFalse);
  });

  testWidgets('a closed date range reads start first, with its years', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final range = StateProvider<DiveFilterState>(
      (ref) => DiveFilterState(
        startDate: DateTime(2023),
        endDate: DateTime(2025, 12, 31),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) =>
                  Wrap(children: activeDiveFilterChips(context, ref, range)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final label = tester
        .widget<Text>(
          find.descendant(of: find.byType(Chip), matching: find.byType(Text)),
        )
        .data!;
    expect(label.indexOf('2023'), isNonNegative, reason: label);
    expect(label.indexOf('2025'), greaterThan(label.indexOf('2023')));
    expect(label.indexOf('Jan'), lessThan(label.indexOf('Dec')));
  });

  group('every axis renders one chip that clears only that axis', () {
    final axes = <String, DiveFilterState>{
      'dates': DiveFilterState(startDate: DateTime(2023)),
      'until': DiveFilterState(endDate: DateTime(2023, 6, 30)),
      'range': DiveFilterState(
        startDate: DateTime(2023),
        endDate: DateTime(2023, 6, 30),
      ),
      'dive type': const DiveFilterState(diveTypeId: 'wreck'),
      'site': const DiveFilterState(siteId: 's1'),
      'trip': const DiveFilterState(tripId: 't1'),
      'dive center': const DiveFilterState(diveCenterId: 'c1'),
      'one gear item': const DiveFilterState(equipmentIds: ['e1']),
      'several gear items': const DiveFilterState(equipmentIds: ['e1', 'e2']),
      'min depth': const DiveFilterState(minDepth: 10),
      'max depth': const DiveFilterState(maxDepth: 30),
      'depth range': const DiveFilterState(minDepth: 10, maxDepth: 30),
      'favourites': const DiveFilterState(favoritesOnly: true),
      'no buddy': const DiveFilterState(noBuddyOnly: true),
      'tags': const DiveFilterState(tagIds: ['a', 'b']),
      'buddy name': const DiveFilterState(buddyNameFilter: 'Jane'),
    };
    for (final MapEntry(key: name, value: filter) in axes.entries) {
      testWidgets(name, (tester) async {
        final provider = StateProvider<DiveFilterState>((ref) => filter);
        final overrides = await getBaseOverrides();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              diveTypeProvider.overrideWith((ref, id) async => null),
              siteProvider.overrideWith((ref, id) async => null),
              tripByIdProvider.overrideWith((ref, id) async => null),
              diveCenterByIdProvider.overrideWith((ref, id) async => null),
              equipmentItemProvider.overrideWith((ref, id) async => null),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => Wrap(
                    children: activeDiveFilterChips(context, ref, provider),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(Chip), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold)),
        );
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        expect(container.read(provider).hasActiveFilters, isFalse);
      });
    }
  });

  testWidgets('an advanced query shows one chip per part, each removable', (
    tester,
  ) async {
    // The Connections Filter tab shares these chips, and its graph honours
    // the query, so a query must never be active without a chip.
    final depth = ConditionNode(
      FieldPath(['depth']),
      QueryOp.gt,
      const NumberValue(30, null),
    );
    final noWeights = ConditionNode(
      FieldPath(['weights']),
      QueryOp.isEmpty,
      null,
    );
    final queryFilterProvider = StateProvider<DiveFilterState>(
      (ref) => DiveFilterState(query: AndNode([depth, noWeights])),
    );
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Wrap(
                children: activeDiveFilterChips(
                  context,
                  ref,
                  queryFilterProvider,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Chip), findsNWidgets(2));
    expect(find.text('weights:none'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    expect(find.byType(Chip), findsOneWidget);
    expect(find.text('weights:none'), findsOneWidget);
    expect(container.read(diveFilterProvider).hasActiveFilters, isFalse);
  });
}
