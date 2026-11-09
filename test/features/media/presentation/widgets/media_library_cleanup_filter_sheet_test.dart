import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_smart_album.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_smart_album_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_active_filter_chips.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_sheet.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The two cleanup facets in the library filter (issue #4148): "No one
/// tagged" at the head of the People picker, excluding everyone else, and a
/// "Not placed in the dive" switch beside Missing files.
void main() {
  final now = DateTime(2026);
  final alex = Buddy(id: 'alex', name: 'Alex', createdAt: now, updatedAt: now);
  final album = MediaSmartAlbum(
    id: 'cleanup',
    name: 'Cleanup',
    filter: const MediaLibraryFilter(noPeople: true, notPlacedInDive: true),
    createdAt: now,
    updatedAt: now,
  );

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        sitesProvider.overrideWith((ref) async => []),
        allTripsProvider.overrideWith((ref) async => []),
        allSpeciesProvider.overrideWith((ref) async => []),
        tagsProvider.overrideWith((ref) async => []),
        missingCountProvider.overrideWith((ref) async => 0),
        allBuddiesProvider.overrideWith((ref) async => [alex]),
        taggedBuddyIdsProvider.overrideWith((ref) async => {'alex'}),
        mediaSmartAlbumsProvider.overrideWith((ref) async => [album]),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 2400);
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

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
  }

  final peopleRow = find.byKey(const ValueKey('media_filter_people'));
  final notPlaced = find.byKey(const ValueKey('media_filter_not_placed'));

  String peopleSubtitle(WidgetTester tester) =>
      ((tester.widget<ListTile>(peopleRow).subtitle! as Text).data)!;

  /// Ticks [keys] in the People picker and closes it with Done.
  Future<void> pickPeople(WidgetTester tester, List<String> keys) async {
    await tester.tap(peopleRow);
    await tester.pumpAndSettle();
    for (final key in keys) {
      await tester.tap(
        find.byKey(
          ValueKey(
            key == 'none' || key == 'me'
                ? 'media_people_pick_$key'
                : 'media_people_pick_buddy_$key',
          ),
        ),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }

  testWidgets('the People row reads "No one tagged" when picked', (
    tester,
  ) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(noPeople: true);
    await openSheet(tester);
    expect(peopleSubtitle(tester), 'No one tagged');
  });

  testWidgets('picking "No one tagged" applies it alone', (tester) async {
    await openSheet(tester);
    await pickPeople(tester, ['none']);
    await apply(tester);

    final filter = container.read(mediaLibraryFilterProvider);
    expect(filter.noPeople, isTrue);
    expect(filter.hasPeople, isFalse);
  });

  testWidgets('picking "No one tagged" clears the people picked', (
    tester,
  ) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(includeMe: true, buddyIds: {'alex'});
    await openSheet(tester);
    await pickPeople(tester, ['none']);
    expect(peopleSubtitle(tester), 'No one tagged');

    await apply(tester);
    final filter = container.read(mediaLibraryFilterProvider);
    expect(filter.noPeople, isTrue);
    expect(filter.includeMe, isFalse);
    expect(filter.buddyIds, isEmpty);
  });

  testWidgets('picking a person clears "No one tagged"', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(noPeople: true);
    await openSheet(tester);
    await pickPeople(tester, ['alex']);
    expect(peopleSubtitle(tester), 'Alex');

    await apply(tester);
    final filter = container.read(mediaLibraryFilterProvider);
    expect(filter.noPeople, isFalse);
    expect(filter.buddyIds, {'alex'});
  });

  testWidgets('the "Not placed in the dive" switch applies', (tester) async {
    await openSheet(tester);
    expect(find.text('Not placed in the dive'), findsOneWidget);
    await tester.tap(notPlaced);
    await tester.pumpAndSettle();
    await apply(tester);

    expect(container.read(mediaLibraryFilterProvider).notPlacedInDive, isTrue);
  });

  testWidgets('Clear All clears both facets', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(noPeople: true, notPlacedInDive: true);
    await openSheet(tester);
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    await apply(tester);

    expect(container.read(mediaLibraryFilterProvider).isEmpty, isTrue);
  });

  testWidgets('loading an album restores both facets', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Load album'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cleanup'));
    await tester.pumpAndSettle();
    await apply(tester);

    final filter = container.read(mediaLibraryFilterProvider);
    expect(filter.noPeople, isTrue);
    expect(filter.notPlacedInDive, isTrue);
  });

  testWidgets('the strip shows a chip for each, each clearing itself', (
    tester,
  ) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(noPeople: true, notPlacedInDive: true);
    await pump(tester, const MediaLibraryActiveFilterChips());

    Finder clear(String label) => find.descendant(
      of: find.widgetWithText(InputChip, label),
      matching: find.byIcon(Icons.clear),
    );
    expect(find.widgetWithText(InputChip, 'No one tagged'), findsOneWidget);
    expect(
      find.widgetWithText(InputChip, 'Not placed in the dive'),
      findsOneWidget,
    );

    await tester.tap(clear('No one tagged'));
    await tester.pumpAndSettle();
    var filter = container.read(mediaLibraryFilterProvider);
    expect(filter.noPeople, isFalse);
    expect(filter.notPlacedInDive, isTrue);

    await tester.tap(clear('Not placed in the dive'));
    await tester.pumpAndSettle();
    filter = container.read(mediaLibraryFilterProvider);
    expect(filter.isEmpty, isTrue);
  });
}
