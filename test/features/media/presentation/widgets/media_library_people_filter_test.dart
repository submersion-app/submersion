import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_active_filter_chips.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_sheet.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// People in the library filter (issue #1745): one People row in the sheet
/// that opens a searchable picker (issue #4148), and a removable chip for
/// each person in the strip.
void main() {
  final now = DateTime(2026);
  final alex = Buddy(id: 'alex', name: 'Alex', createdAt: now, updatedAt: now);
  final bea = Buddy(id: 'bea', name: 'Bea', createdAt: now, updatedAt: now);
  final cal = Buddy(id: 'cal', name: 'Cal', createdAt: now, updatedAt: now);

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        sitesProvider.overrideWith((ref) async => []),
        allTripsProvider.overrideWith((ref) async => []),
        allSpeciesProvider.overrideWith((ref) async => []),
        tagsProvider.overrideWith((ref) async => []),
        missingCountProvider.overrideWith((ref) async => 0),
        allBuddiesProvider.overrideWith((ref) async => [bea, alex, cal]),
        // Cal is a buddy nobody has tagged.
        taggedBuddyIdsProvider.overrideWith((ref) async => {'alex', 'bea'}),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: home),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showMediaLibraryFilterSheet(context),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final peopleRow = find.byKey(const ValueKey('media_filter_people'));

  String subtitle(WidgetTester tester) =>
      ((tester.widget<ListTile>(peopleRow).subtitle! as Text).data)!;

  /// Ticks [keys] in the People picker and closes it with Done.
  Future<void> pickPeople(WidgetTester tester, List<String> keys) async {
    await tester.tap(peopleRow);
    await tester.pumpAndSettle();
    for (final key in keys) {
      await tester.tap(find.byKey(ValueKey('media_people_pick_$key')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }

  testWidgets('People is one row that reads Any', (tester) async {
    await openSheet(tester);
    expect(find.text('People'), findsOneWidget);
    expect(subtitle(tester), 'Any');
    // No buddy is drawn in the sheet itself, however many are tagged.
    expect(find.text('Alex'), findsNothing);
  });

  testWidgets('selecting Me and a buddy applies both', (tester) async {
    await openSheet(tester);
    await pickPeople(tester, ['me', 'alex']);
    expect(subtitle(tester), 'Me, Alex');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final filter = container.read(mediaLibraryFilterProvider);
    expect(filter.includeMe, isTrue);
    expect(filter.buddyIds, {'alex'});
  });

  testWidgets('the row names two people and counts the rest', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(includeMe: true, buddyIds: {'bea', 'alex'});
    await openSheet(tester);
    expect(subtitle(tester), 'Me, Alex +1');
  });

  testWidgets('one buddy reads as their name', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(buddyIds: {'bea'});
    await openSheet(tester);
    expect(subtitle(tester), 'Bea');
  });

  testWidgets('dismissing the picker keeps the draft', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(buddyIds: {'bea'});
    await openSheet(tester);
    await tester.tap(peopleRow);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media_people_pick_alex')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(subtitle(tester), 'Bea');
  });

  testWidgets('the clear button empties the people', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(includeMe: true, buddyIds: {'alex'});
    await openSheet(tester);
    final clear = find.byKey(const ValueKey('media_filter_people_clear'));
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(subtitle(tester), 'Any');
    expect(clear, findsNothing);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).hasPeople, isFalse);
  });

  testWidgets('Clear All clears people too', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(includeMe: true, buddyIds: {'alex'});
    await openSheet(tester);
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).hasPeople, isFalse);
  });

  testWidgets('the strip shows a chip per person, each clearing itself', (
    tester,
  ) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(includeMe: true, buddyIds: {'alex'});
    await pump(tester, const MediaLibraryActiveFilterChips());

    expect(find.widgetWithText(InputChip, 'Me'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Alex'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Me'),
        matching: find.byIcon(Icons.clear),
      ),
    );
    await tester.pumpAndSettle();
    var filter = container.read(mediaLibraryFilterProvider);
    expect(filter.includeMe, isFalse);
    expect(filter.buddyIds, {'alex'});

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Alex'),
        matching: find.byIcon(Icons.clear),
      ),
    );
    await tester.pumpAndSettle();
    filter = container.read(mediaLibraryFilterProvider);
    expect(filter.buddyIds, isEmpty);
  });

  testWidgets('a selected buddy no longer listed reads as removed', (
    tester,
  ) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(buddyIds: {'gone'});
    await pump(tester, const MediaLibraryActiveFilterChips());

    expect(find.widgetWithText(InputChip, 'Removed buddy'), findsOneWidget);
  });

  group('while the buddies are still loading', () {
    setUp(() {
      final pending = Completer<List<Buddy>>();
      container = ProviderContainer(
        overrides: [
          sitesProvider.overrideWith((ref) async => []),
          allTripsProvider.overrideWith((ref) async => []),
          allSpeciesProvider.overrideWith((ref) async => []),
          tagsProvider.overrideWith((ref) async => []),
          missingCountProvider.overrideWith((ref) async => 0),
          allBuddiesProvider.overrideWith((ref) => pending.future),
          taggedBuddyIdsProvider.overrideWith((ref) async => {'alex'}),
        ],
      );
      addTearDown(container.dispose);
      container.read(mediaLibraryFilterProvider.notifier).state =
          const MediaLibraryFilter(buddyIds: {'alex'});
    });

    testWidgets('the strip shows no buddy as removed', (tester) async {
      await pump(tester, const MediaLibraryActiveFilterChips());
      expect(find.text('Removed buddy'), findsNothing);
    });

    testWidgets('the sheet shows no buddy as removed', (tester) async {
      await openSheet(tester);
      expect(find.text('Removed buddy'), findsNothing);
      expect(find.text('1 person'), findsOneWidget);
    });
  });
}
