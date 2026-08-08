import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_bar.dart';
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

  Widget host() {
    return ProviderScope(
      overrides: [
        sitesProvider.overrideWith((ref) async => [site]),
        allTripsProvider.overrideWith((ref) async => [trip]),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MediaLibraryFilterBar()),
      ),
    );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(MediaLibraryFilterBar)),
      );

  testWidgets('site chip opens picker and writes siteId to the filter', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Hole'));
    await tester.pumpAndSettle();

    expect(
      containerOf(tester).read(mediaLibraryFilterProvider).siteId,
      'site-1',
    );
    // The chip now shows the chosen site name.
    expect(find.text('Blue Hole'), findsOneWidget);
  });

  testWidgets('trip chip opens picker and writes tripId to the filter', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Red Sea 2026'));
    await tester.pumpAndSettle();

    expect(
      containerOf(tester).read(mediaLibraryFilterProvider).tripId,
      'trip-1',
    );
  });

  testWidgets('clearing an active chip resets just that field', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue Hole'));
    await tester.pumpAndSettle();

    // The active chip renders a per-chip clear (delete) affordance.
    await tester.tap(find.byIcon(Icons.clear).first);
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(mediaLibraryFilterProvider).siteId, isNull);
  });

  testWidgets('clear-filters chip appears when filtered and resets all', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Clear filters'), findsNothing);

    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Red Sea 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Clear filters'), findsOneWidget);

    await tester.ensureVisible(find.text('Clear filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(
      containerOf(tester).read(mediaLibraryFilterProvider),
      MediaLibraryFilter.none,
    );
  });

  group('date range', () {
    testWidgets('dismissing the range picker leaves the filter alone', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dates'));
      await tester.pumpAndSettle();
      // The picker is up.
      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      final filter = containerOf(tester).read(mediaLibraryFilterProvider);
      expect(filter.fromDate, isNull);
      expect(filter.toDate, isNull);
    });

    testWidgets('a chosen range extends the end bound to end-of-day', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dates'));
      await tester.pumpAndSettle();

      // Two day cells in the visible month, then confirm.
      await tester.tap(find.text('10').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('12').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final filter = containerOf(tester).read(mediaLibraryFilterProvider);
      expect(filter.fromDate, isNotNull);
      expect(filter.toDate, isNotNull);
      // A single-day range would otherwise exclude everything shot after
      // midnight, so the end bound is pushed to the last millisecond.
      expect(filter.toDate!.hour, 23);
      expect(filter.toDate!.minute, 59);
      expect(filter.toDate!.second, 59);
      expect(filter.toDate!.millisecond, 999);
    });

    testWidgets('clearing the dates chip drops both bounds', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final notifier = containerOf(
        tester,
      ).read(mediaLibraryFilterProvider.notifier);
      notifier.state = MediaLibraryFilter(
        fromDate: DateTime(2026, 6, 1),
        toDate: DateTime(2026, 6, 30),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.clear).first);
      await tester.pumpAndSettle();

      final filter = containerOf(tester).read(mediaLibraryFilterProvider);
      expect(filter.fromDate, isNull);
      expect(filter.toDate, isNull);
    });
  });
}
