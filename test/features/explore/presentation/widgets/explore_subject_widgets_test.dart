import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_query_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_subject_providers.dart';
import 'package:submersion/features/explore/presentation/widgets/explore_handoff_bar.dart';
import 'package:submersion/features/explore/presentation/widgets/explore_subject_results_list.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_query_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Every non-dive subject's answer: its rows drawn by its own list's tile,
/// each opening its own detail page, and the handoff writing the query into
/// that list's own filter before going there.
void main() {
  final t = DateTime(2026, 1, 1);
  final node = ConditionNode(
    FieldPath(const ['name']),
    QueryOp.contains,
    const StringValue('x'),
  );

  // The tiles date themselves against Intl.defaultLocale, a process global.
  late String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  final cases =
      <
        ({
          ParsedSubject subject,
          String route,
          Object item,
          Object? Function(ProviderContainer) written,
        })
      >[
        (
          subject: ParsedSubject.sites,
          route: '/sites',
          item: const SiteWithDiveCount(
            site: DiveSite(id: 'r1', name: 'Row one'),
            diveCount: 2,
          ),
          written: (c) => c.read(siteFilterProvider).query,
        ),
        (
          subject: ParsedSubject.equipment,
          route: '/equipment',
          item: const EquipmentItem(
            id: 'r1',
            name: 'Row one',
            type: EquipmentType.regulator,
          ),
          written: (c) => c.read(equipmentFilterProvider).query,
        ),
        (
          subject: ParsedSubject.buddies,
          route: '/buddies',
          item: BuddyWithDiveCount(
            buddy: Buddy(id: 'r1', name: 'Row one', createdAt: t, updatedAt: t),
            diveCount: 2,
          ),
          written: (c) => c.read(buddyQueryProvider),
        ),
        (
          subject: ParsedSubject.species,
          route: '/species',
          item: SeenSpecies(
            species: const Species(
              id: 'r1',
              commonName: 'Row one',
              category: SpeciesCategory.fish,
            ),
            totalSightings: 2,
            diveCount: 2,
            siteCount: 1,
            firstSeen: t,
            lastSeen: t,
          ),
          written: (c) => c.read(seenSpeciesQueryProvider),
        ),
        (
          subject: ParsedSubject.trips,
          route: '/trips',
          item: TripWithStats(
            trip: Trip(
              id: 'r1',
              name: 'Row one',
              startDate: t,
              endDate: t,
              createdAt: t,
              updatedAt: t,
            ),
            diveCount: 2,
          ),
          written: (c) => c.read(tripFilterProvider).query,
        ),
        (
          subject: ParsedSubject.centers,
          route: '/dive-centers',
          item: DiveCenter(
            id: 'r1',
            name: 'Row one',
            createdAt: t,
            updatedAt: t,
          ),
          written: (c) => c.read(diveCenterQueryProvider),
        ),
      ];

  Future<ProviderContainer> pump(
    WidgetTester tester,
    ParsedSubject subject,
    String route,
    AsyncValue<List<ExploreSubjectRow>> rows,
  ) async {
    final router = GoRouter(
      initialLocation: '/explore',
      routes: [
        GoRoute(
          path: '/explore',
          builder: (_, _) => Scaffold(
            body: ListView(
              children: [
                ExploreSubjectResultsList(subject: subject),
                ExploreHandoffBar(subject: subject),
              ],
            ),
          ),
        ),
        GoRoute(path: route, builder: (_, _) => const Text('the list')),
        GoRoute(
          path: '$route/:id',
          builder: (_, s) => Text('detail ${s.pathParameters['id']}'),
        ),
      ],
    );
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          ...base,
          exploreQueryNodeProvider.overrideWith((ref) => node),
          exploreSubjectRowsProvider.overrideWithValue(rows),
          speciesCoverMediaProvider.overrideWith((ref) async => const {}),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(ExploreSubjectResultsList)),
    );
  }

  for (final c in cases) {
    final row = ExploreSubjectRow(
      id: 'r1',
      name: 'Row one',
      dives: 2,
      item: c.item,
    );

    testWidgets('${c.subject.name}: a row opens its own detail page', (
      tester,
    ) async {
      await pump(tester, c.subject, c.route, AsyncValue.data([row]));
      expect(find.text('Row one'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('explore-row-r1')));
      await tester.pumpAndSettle();
      expect(find.text('detail r1'), findsOneWidget);
    });

    testWidgets('${c.subject.name}: the handoff writes the list query', (
      tester,
    ) async {
      final container = await pump(
        tester,
        c.subject,
        c.route,
        AsyncValue.data([row]),
      );
      await tester.tap(find.byKey(const ValueKey('explore-handoff-list')));
      await tester.pumpAndSettle();
      expect(c.written(container), node);
      expect(find.text('the list'), findsOneWidget);
    });
  }

  testWidgets('loading rows show a spinner', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: ExploreSubjectResultsList(subject: ParsedSubject.sites),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          ...await getBaseOverrides(),
          exploreSubjectRowsProvider.overrideWithValue(
            const AsyncValue<List<ExploreSubjectRow>>.loading(),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('failed rows show a sentence, not the error', (tester) async {
    await pump(
      tester,
      ParsedSubject.sites,
      '/sites',
      AsyncValue.error(StateError('boom'), StackTrace.empty),
    );
    expect(find.text('Something went wrong. Please try again.'), findsOne);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('more than a hundred rows say the list is cut short', (
    tester,
  ) async {
    final many = [
      for (var i = 0; i < 101; i++)
        ExploreSubjectRow(
          id: 's$i',
          name: 'Site $i',
          dives: 0,
          item: SiteWithDiveCount(
            site: DiveSite(id: 's$i', name: 'Site $i'),
            diveCount: 0,
          ),
        ),
    ];
    await pump(tester, ParsedSubject.sites, '/sites', AsyncValue.data(many));
    await tester.scrollUntilVisible(
      find.textContaining('100'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('100'), findsOneWidget);
    expect(find.byKey(const ValueKey('explore-row-s100')), findsNothing);
  });
}
