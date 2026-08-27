import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_active_filter_chips.dart';
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
      ],
    );
    addTearDown(container.dispose);
  });

  Widget host() => UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: MediaLibraryActiveFilterChips()),
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
  }

  testWidgets('renders nothing when the filter is empty', (tester) async {
    await pump(tester);

    expect(find.byType(InputChip), findsNothing);
    expect(find.text('Clear filters'), findsNothing);
  });

  testWidgets('shows one chip per active facet', (tester) async {
    container
        .read(mediaLibraryFilterProvider.notifier)
        .state = const MediaLibraryFilter(
      mediaType: MediaType.photo,
      siteId: 'site-1',
      tripId: 'trip-1',
    );
    await pump(tester);

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.text('Red Sea 2026'), findsOneWidget);
  });

  testWidgets('deleting a chip clears only its own facet', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(mediaType: MediaType.photo, siteId: 'site-1');
    await pump(tester);

    final siteChip = find.ancestor(
      of: find.text('Blue Hole'),
      matching: find.byType(InputChip),
    );
    await tester.tap(
      find.descendant(of: siteChip, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();

    final filter = container.read(mediaLibraryFilterProvider);
    expect(filter.siteId, isNull);
    expect(filter.mediaType, MediaType.photo);
  });

  testWidgets('the source chip shows the localized label, not the enum', (
    tester,
  ) async {
    // The Sources section writes this facet when the user taps "browse this
    // source". The chip has to name the source the way that row did, not
    // leak the enum identifier.
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(sourceType: MediaSourceType.networkUrl);
    await pump(tester);

    expect(find.text('Web links'), findsOneWidget);
    expect(find.text('networkUrl'), findsNothing);
  });

  testWidgets('Clear filters empties the whole filter', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(mediaType: MediaType.photo, siteId: 'site-1');
    await pump(tester);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).isEmpty, isTrue);
  });

  testWidgets('the missing files facet gets a removable chip', (tester) async {
    container.read(mediaLibraryFilterProvider.notifier).state =
        const MediaLibraryFilter(health: MediaHealthFilter.missing);
    await pump(tester);

    expect(find.text('Missing files'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear).first);
    await tester.pumpAndSettle();

    expect(container.read(mediaLibraryFilterProvider).health, isNull);
  });
}
