import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_sheet.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  const site = DiveSite(id: 'site-1', name: 'Blue Hole');
  final trip = Trip(
    id: 'trip-1',
    name: 'Red Sea 2026',
    startDate: DateTime(2026, 6, 1),
    endDate: DateTime(2026, 6, 14),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  const species = Species(
    id: 'sp1',
    commonName: 'Blue Grouper',
    category: SpeciesCategory.fish,
    isBuiltIn: false,
  );

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        sitesProvider.overrideWith((ref) async => [site]),
        allTripsProvider.overrideWith((ref) async => [trip]),
        allSpeciesProvider.overrideWith((ref) async => [species]),
        missingCountProvider.overrideWith((ref) async => 3),
        sourceCountsProvider.overrideWith(
          (ref) async => {
            MediaSourceType.platformGallery: 12,
            MediaSourceType.localFile: 4,
          },
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  // The sheet is opened from a host button so the test exercises the real
  // modal route, which is where the sheet's own Navigator context lives.
  Widget host() {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMediaLibraryFilterSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('drafts a type and writes it only on Apply', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();

    // Nothing is committed until Apply.
    expect(container.read(mediaLibraryFilterProvider).mediaType, isNull);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(
      container.read(mediaLibraryFilterProvider).mediaType,
      MediaType.photo,
    );
  });

  group('Attached to (issue #4224)', () {
    FilterChip chip(WidgetTester tester, String kind) =>
        tester.widget<FilterChip>(
          find.byKey(ValueKey('media_filter_attached_$kind')),
        );

    testWidgets('opens on the current selection and applies a change', (
      tester,
    ) async {
      container.read(mediaLibraryFilterProvider.notifier).state =
          const MediaLibraryFilter(attachedTo: {MediaAttachmentKind.dive});
      await openSheet(tester);

      expect(chip(tester, 'dive').selected, isTrue);
      expect(chip(tester, 'site').selected, isFalse);

      await tester.tap(
        find.byKey(const ValueKey('media_filter_attached_site')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(container.read(mediaLibraryFilterProvider).attachedTo, {
        MediaAttachmentKind.dive,
        MediaAttachmentKind.site,
      });
    });

    testWidgets('Clear all clears it', (tester) async {
      container.read(mediaLibraryFilterProvider.notifier).state =
          const MediaLibraryFilter(attachedTo: {MediaAttachmentKind.site});
      await openSheet(tester);

      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();
      expect(chip(tester, 'site').selected, isFalse);
    });
  });

  testWidgets('dismissing without Apply leaves the filter untouched', (
    tester,
  ) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(mediaType: MediaType.video);
    await openSheet(tester);

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
    // Tap the barrier above the sheet to dismiss it.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(
      container.read(mediaLibraryFilterProvider).mediaType,
      MediaType.video,
    );
  });

  testWidgets('picking a site drafts it and Apply commits the id', (
    tester,
  ) async {
    await openSheet(tester);

    // The picker row, not the Attached to section's Site chip.
    await tester.tap(find.widgetWithText(ListTile, 'Site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Hole'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).siteId, 'site-1');
  });

  testWidgets('picking a species drafts it and Apply commits the id', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Species'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Grouper'));
    await tester.pumpAndSettle();
    expect(container.read(mediaLibraryFilterProvider).speciesId, isNull);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).speciesId, 'sp1');
  });

  testWidgets('Apply keeps a source set from the Sources tab', (tester) async {
    // The Sources view writes a sourceType into this same provider when the
    // user browses a source. Applying a type filter must not discard it.
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(sourceType: MediaSourceType.networkUrl);
    await openSheet(tester);

    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final filter = container.read(mediaLibraryFilterProvider);
    expect(filter.mediaType, MediaType.photo);
    expect(filter.sourceType, MediaSourceType.networkUrl);
  });

  testWidgets('Clear All resets the drafted facets', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(mediaType: MediaType.video, siteId: 'site-1');
    await openSheet(tester);

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final filter = container.read(mediaLibraryFilterProvider);
    expect(filter.mediaType, isNull);
    expect(filter.siteId, isNull);
  });

  testWidgets('Missing files drafts the health facet and writes it on Apply', (
    tester,
  ) async {
    await openSheet(tester);

    // The count rides in the title, where the Missing section's sidebar
    // badge used to be.
    expect(find.text('Missing files (3)'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(container.read(mediaLibraryFilterProvider).health, isNull);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(
      container.read(mediaLibraryFilterProvider).health,
      MediaHealthFilter.missing,
    );
  });

  testWidgets('Clear All also drops the health facet', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(health: MediaHealthFilter.missing);
    await openSheet(tester);

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).health, isNull);
  });

  // Issue #4149: browsing a source from the Sources tab lit the filter badge,
  // and the sheet behind it showed nothing to explain or clear it.
  group('source facet (#4149)', () {
    testWidgets('shows a source set from the Sources tab', (tester) async {
      container.read(mediaLibraryFilterProvider.notifier).state =
          const MediaLibraryFilter(sourceType: MediaSourceType.platformGallery);
      await openSheet(tester);

      final row = find.widgetWithText(ListTile, 'Source');
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Photo library')),
        findsOneWidget,
      );
    });

    testWidgets('reads Any with no source set', (tester) async {
      await openSheet(tester);

      final row = find.widgetWithText(ListTile, 'Source');
      expect(
        find.descendant(of: row, matching: find.text('Any')),
        findsOneWidget,
      );
    });

    testWidgets('Clear All drops the source', (tester) async {
      container.read(mediaLibraryFilterProvider.notifier).state =
          const MediaLibraryFilter(sourceType: MediaSourceType.platformGallery);
      await openSheet(tester);

      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(container.read(mediaLibraryFilterProvider).isEmpty, isTrue);
    });

    testWidgets('picking a source drafts it and Apply commits it', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      // Only sources that hold media are offered, as on the Sources tab.
      expect(find.text('Web links'), findsNothing);
      await tester.tap(find.text('Local files'));
      await tester.pumpAndSettle();
      expect(container.read(mediaLibraryFilterProvider).sourceType, isNull);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(
        container.read(mediaLibraryFilterProvider).sourceType,
        MediaSourceType.localFile,
      );
    });

    testWidgets('picking Any clears the source on Apply', (tester) async {
      container.read(mediaLibraryFilterProvider.notifier).state =
          const MediaLibraryFilter(sourceType: MediaSourceType.platformGallery);
      await openSheet(tester);

      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Any').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(container.read(mediaLibraryFilterProvider).sourceType, isNull);
    });

    testWidgets('a source with no media left still shows while selected', (
      tester,
    ) async {
      // A smart album or a stale browse can name a source that has since
      // emptied out. It must still read in the row, or the badge is lit
      // again with nothing on screen saying why.
      container.read(mediaLibraryFilterProvider.notifier).state =
          const MediaLibraryFilter(sourceType: MediaSourceType.networkUrl);
      await openSheet(tester);

      await tester.tap(find.text('Source'));
      await tester.pumpAndSettle();

      // Once as the row's subtitle, once as an option in the picker.
      expect(find.text('Web links'), findsNWidgets(2));
    });
  });
}
