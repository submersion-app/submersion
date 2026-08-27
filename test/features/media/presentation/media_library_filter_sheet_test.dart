import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
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

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        sitesProvider.overrideWith((ref) async => [site]),
        allTripsProvider.overrideWith((ref) async => [trip]),
        missingCountProvider.overrideWith((ref) async => 3),
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

    await tester.tap(find.text('Site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Hole'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).siteId, 'site-1');
  });

  testWidgets('Apply preserves facets the sheet does not own', (tester) async {
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
}
