import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, TagsCompanion;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_custom_fields_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_location_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_organization_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_people_group.dart';
import 'package:submersion/features/dive_log/presentation/widgets/searchable_filter_dropdown.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_field.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../../helpers/test_database.dart';
import 'group_test_host.dart';

void main() {
  final now = DateTime(2026, 6, 1);
  Finder fieldShowing(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  Future<void> pick(
    WidgetTester tester,
    String all,
    String typed,
    String hit,
  ) async {
    await tester.tap(fieldShowing(all));
    await tester.pumpAndSettle();
    await tester.enterText(fieldShowing(all), typed);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(searchableFilterOptionsKey),
        matching: find.text(hit),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Location', () {
    Future<GroupHarness> pump(WidgetTester tester) => pumpGroup(
      tester,
      (d, on) => RefineLocationGroup(draft: d, onChanged: on),
      overrides: [
        sitesProvider.overrideWith(
          (ref) async => const [
            DiveSite(id: 's1', name: 'Blue Hole', country: 'Egypt'),
            DiveSite(id: 's2', name: 'Coral Garden', country: 'Mexico'),
          ],
        ),
        allTripsProvider.overrideWith(
          (ref) async => [
            Trip(
              id: 't1',
              name: 'Summer week',
              location: 'Sharm el-Sheikh',
              startDate: now,
              endDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
        allDiveCentersProvider.overrideWith(
          (ref) async => [
            DiveCenter(
              id: 'c1',
              name: 'Blue Planet',
              city: 'Cozumel',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      ],
    );

    testWidgets('site by country, trip by place, center by city', (
      tester,
    ) async {
      final h = await pump(tester);
      // The site field opens the shared site picker sheet (#1080).
      await tester.tap(find.byKey(sitePickerFieldKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'mexico',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(sitePickerListKey),
          matching: find.text('Coral Garden'),
        ),
      );
      await tester.pumpAndSettle();
      expect(h.draft.siteId, 's2');
      await pick(tester, 'All trips', 'sharm', 'Summer week');
      expect(h.draft.tripId, 't1');
      await pick(tester, 'All centers', 'cozumel', 'Blue Planet');
      expect(h.draft.diveCenterId, 'c1');
    });
  });

  group('People and life', () {
    final roles = allDiveRolesProvider.overrideWith(
      (ref) async => [
        DiveRole(
          id: 'instructor',
          name: 'Instructor',
          isBuiltIn: true,
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
        DiveRole(
          id: 'r1',
          diverId: 'me',
          name: 'Cave Guide',
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
      ],
    );
    Future<GroupHarness> pump(
      WidgetTester tester, [
      DiveFilterState initial = const DiveFilterState(),
    ]) => pumpGroup(
      tester,
      (d, on) => RefinePeopleGroup(draft: d, onChanged: on),
      initial: initial,
      overrides: [
        roles,
        allBuddiesProvider.overrideWith(
          (ref) async => [
            Buddy(id: 'b1', name: 'Ana', createdAt: now, updatedAt: now),
            Buddy(id: 'b2', name: 'Cid', createdAt: now, updatedAt: now),
          ],
        ),
        allSpeciesProvider.overrideWith(
          (ref) async => [
            const Species(
              id: 'sp1',
              commonName: 'Manta ray',
              scientificName: 'Mobula birostris',
              category: SpeciesCategory.ray,
            ),
          ],
        ),
      ],
    );

    testWidgets('typed buddy names write; no-buddy clears them', (
      tester,
    ) async {
      final h = await pump(tester);
      await tester.enterText(find.byKey(kRefineBuddyFieldKey), 'Ana, Cid');
      await tester.pump();
      expect(h.draft.buddyNameFilter, 'Ana, Cid');
      // Close the suggestions, which open over the switch.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kRefineNoBuddySwitchKey));
      await tester.pump();
      expect(h.draft.noBuddyOnly, isTrue);
      expect(h.draft.buddyNameFilter, isNull);
    });

    // The diver's own role (#4409): a chip per role and Not set, which ORs
    // with the roles listed (it was the No Role Assigned switch, #3622).
    testWidgets('my role chips pick roles and Not set', (tester) async {
      final h = await pump(tester);
      expect(find.text('Instructor'), findsOneWidget);
      expect(find.text('Cave Guide'), findsOneWidget);
      await tester.tap(find.byKey(refineRoleChipKey('instructor')));
      await tester.pump();
      expect(h.draft.diverRoleIds, ['instructor']);
      await tester.tap(find.byKey(kRefineRoleNotSetChipKey));
      await tester.pump();
      expect(h.draft.noRoleOnly, isTrue);
      expect(h.draft.diverRoleIds, ['instructor']);
      expect(h.draft.noBuddyOnly, isNull, reason: 'the buddy axis is apart');
      await tester.tap(find.byKey(refineRoleChipKey('instructor')));
      await tester.pump();
      expect(h.draft.diverRoleIds, isEmpty);
      await tester.tap(find.byKey(kRefineRoleNotSetChipKey));
      await tester.pump();
      expect(h.draft.noRoleOnly, isNull);
    });

    // A divers write (a diver edited, a sync) reloads the role list through
    // its diver id dependency; the unpicked role chips stay until the new
    // list lands rather than vanishing for the reload.
    testWidgets('a role list reload keeps the role chips', (tester) async {
      final trigger = NotifierProvider<_Trigger, int>(_Trigger.new);
      final list = [
        DiveRole(
          id: 'instructor',
          name: 'Instructor',
          isBuiltIn: true,
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
        DiveRole(
          id: 'r1',
          diverId: 'me',
          name: 'Cave Guide',
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
      ];
      var next = Completer<List<DiveRole>>()..complete(list);
      await pumpGroup(
        tester,
        (d, on) => RefinePeopleGroup(draft: d, onChanged: on),
        initial: const DiveFilterState(diverRoleIds: ['instructor']),
        overrides: [
          allDiveRolesProvider.overrideWith((ref) {
            ref.watch(trigger);
            return next.future;
          }),
          allBuddiesProvider.overrideWith((ref) async => const <Buddy>[]),
          allSpeciesProvider.overrideWith((ref) async => const <Species>[]),
        ],
      );
      expect(find.byKey(refineRoleChipKey('r1')), findsOneWidget);

      next = Completer<List<DiveRole>>();
      ProviderScope.containerOf(
        tester.element(find.byType(RefinePeopleGroup)),
      ).read(trigger.notifier).bump();
      await tester.pump();
      expect(find.byKey(refineRoleChipKey('r1')), findsOneWidget);
      expect(find.text('Cave Guide'), findsOneWidget);
      next.complete(list);
    });

    testWidgets('built-in role chips are in the diver\'s language', (
      tester,
    ) async {
      final de = lookupAppLocalizations(const Locale('de'));
      await pumpGroup(
        tester,
        (d, on) => RefinePeopleGroup(draft: d, onChanged: on),
        locale: const Locale('de'),
        overrides: [roles],
      );
      expect(find.text(de.diveRole_builtin_instructor), findsOneWidget);
      expect(find.text('Cave Guide'), findsOneWidget);
    });

    testWidgets('a buddy suggestion completes the name', (tester) async {
      final h = await pump(tester);
      await tester.enterText(find.byKey(kRefineBuddyFieldKey), 'an');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana').last);
      await tester.pumpAndSettle();
      expect(h.draft.buddyNameFilter, 'Ana');
    });

    testWidgets('a second buddy is suggested after a comma and appended', (
      tester,
    ) async {
      final h = await pump(tester);
      await tester.enterText(find.byKey(kRefineBuddyFieldKey), 'Ana, ');
      await tester.pumpAndSettle();
      // Names already chosen are not offered again.
      expect(find.text('Cid'), findsWidgets);
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text('Ana')),
        findsNothing,
      );
      await tester.tap(find.text('Cid').last);
      await tester.pumpAndSettle();
      expect(h.draft.buddyNameFilter, 'Ana, Cid');
    });

    testWidgets('a species is found by scientific name and removable', (
      tester,
    ) async {
      final h = await pump(tester);
      await tester.enterText(find.byKey(kRefineSpeciesFieldKey), 'mobula');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manta ray').last);
      await tester.pumpAndSettle();
      expect(h.draft.speciesIds, ['sp1']);
      // The search empties for the next pick.
      expect(
        tester
            .widget<TextField>(find.byKey(kRefineSpeciesFieldKey))
            .controller!
            .text,
        isEmpty,
      );
      tester.widget<InputChip>(find.byType(InputChip)).onDeleted!();
      await tester.pump();
      expect(h.draft.speciesIds, isEmpty);
    });
  });

  group('Organization', () {
    // Tags load from the database.
    late AppDatabase db;
    setUp(() async => db = await setUpTestDatabase());
    tearDown(tearDownTestDatabase);

    testWidgets('a tag chip toggles its id', (tester) async {
      final stamp = now.millisecondsSinceEpoch;
      await db
          .into(db.tags)
          .insert(
            TagsCompanion(
              id: const Value('t1'),
              name: const Value('Night'),
              createdAt: Value(stamp),
              updatedAt: Value(stamp),
            ),
          );
      final h = await pumpGroup(
        tester,
        (d, on) => RefineOrganizationGroup(draft: d, onChanged: on),
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Night'));
      await tester.pump();
      expect(h.draft.tagIds, ['t1']);
      await tester.tap(find.widgetWithText(FilterChip, 'Night'));
      await tester.pump();
      expect(h.draft.tagIds, isEmpty);
    });

    testWidgets('stars, switches; the same star clears', (tester) async {
      final h = await pumpGroup(
        tester,
        (d, on) => RefineOrganizationGroup(draft: d, onChanged: on),
      );
      await tester.tap(find.byIcon(Icons.star_border).at(3));
      await tester.pump();
      expect(h.draft.minRating, 4);
      await tester.tap(find.byIcon(Icons.star).at(3));
      await tester.pump();
      expect(h.draft.minRating, isNull);
      await tester.tap(find.byKey(const Key('filter-favorites-only')));
      await tester.pump();
      expect(h.draft.favoritesOnly, isTrue);
      await tester.tap(find.byKey(const Key('filter-favorites-only')));
      await tester.pump();
      expect(h.draft.favoritesOnly, isNull);
      await tester.tap(
        find.byKey(const Key('filter-excluded-from-stats-only')),
      );
      await tester.pump();
      expect(h.draft.excludedFromStatsOnly, isTrue);
    });
  });

  group('Custom fields', () {
    testWidgets('a key narrows, a value writes, clearing the key clears both', (
      tester,
    ) async {
      final h = await pumpGroup(
        tester,
        (d, on) => RefineCustomFieldsGroup(draft: d, onChanged: on),
        initial: const DiveFilterState(
          customFieldKey: 'Guide',
          customFieldValue: 'Sam',
        ),
        overrides: [
          customFieldKeySuggestionsProvider(
            'diver-1',
          ).overrideWith((ref) async => const ['Boat name', 'Guide']),
        ],
      );
      await h.container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver('diver-1');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(kRefineCustomValueKey), 'Lee');
      await tester.pump();
      expect(h.draft.customFieldValue, 'Lee');
      // Picking the "all keys" entry clears the key, and the value with it.
      await tester.tap(fieldShowing('Guide'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(searchableFilterOptionsKey),
          matching: find.text('Custom Field Key'),
        ),
      );
      await tester.pumpAndSettle();
      expect(h.draft.customFieldKey, isNull);
      expect(h.draft.customFieldValue, isNull);
    });

    testWidgets('the keys stay while they reload, and when a reload fails', (
      tester,
    ) async {
      var calls = 0;
      final pending = Completer<List<String>>();
      final h = await pumpGroup(
        tester,
        (d, on) => RefineCustomFieldsGroup(draft: d, onChanged: on),
        initial: const DiveFilterState(customFieldKey: 'Guide'),
        overrides: [
          customFieldKeySuggestionsProvider('diver-1').overrideWith((ref) {
            calls++;
            if (calls == 1) return Future.value(const ['Guide']);
            if (calls == 2) return pending.future;
            return Future.error(StateError('read failed'));
          }),
        ],
      );
      await h.container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver('diver-1');
      await tester.pumpAndSettle();
      expect(find.byKey(kRefineCustomValueKey), findsOneWidget);

      // A custom field write reloads the keys; the controls must not blink
      // out to the "no custom fields" text meanwhile.
      h.container.invalidate(customFieldKeySuggestionsProvider('diver-1'));
      await tester.pump();
      expect(find.byKey(kRefineCustomValueKey), findsOneWidget);
      pending.complete(const ['Guide']);
      await tester.pumpAndSettle();

      h.container.invalidate(customFieldKeySuggestionsProvider('diver-1'));
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.byKey(kRefineCustomValueKey), findsOneWidget);
    });
  });

  test('the role axis counts once in the People group badge (#4409)', () {
    expect(
      RefinePeopleGroup.activeCount(
        const DiveFilterState(
          diverRoleIds: ['instructor', 'student'],
          noRoleOnly: true,
        ),
      ),
      1,
    );
    expect(
      RefinePeopleGroup.activeCount(
        const DiveFilterState(diverRoleIds: ['instructor']),
      ),
      1,
    );
  });

  test('the four groups declare their fields', () {
    expect(RefineLocationGroup.fields, {'siteId', 'tripId', 'diveCenterId'});
    expect(RefinePeopleGroup.fields, {
      'buddyNameFilter',
      'noBuddyOnly',
      'noRoleOnly',
      'diverRoleIds',
      'speciesIds',
    });
    expect(RefineOrganizationGroup.fields, {
      'tagIds',
      'minRating',
      'favoritesOnly',
      'excludedFromStatsOnly',
    });
    expect(RefineCustomFieldsGroup.fields, {
      'customFieldKey',
      'customFieldValue',
    });
  });
}

class _Trigger extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}
