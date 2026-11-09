import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/pages/media_library_view.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _EmptyLibraryNotifier extends StateNotifier<MediaLibraryState>
    implements MediaLibraryNotifier {
  _EmptyLibraryNotifier([super.state = const MediaLibraryState()]);

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadMore() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsRepo extends AppSettingsRepository {
  @override
  Future<String?> getRawSetting(String key) async => null;

  @override
  Future<void> setRawSetting(String key, String value) async {}
}

/// An empty gallery under a filter means nothing matches it, not that the
/// library is empty (issue #4148): with the cleanup filters, an emptied
/// view is the finished state.
void main() {
  Future<void> pumpEmpty(
    WidgetTester tester,
    MediaLibraryFilter filter, {
    MediaLibraryState state = const MediaLibraryState(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaLibraryNotifierProvider.overrideWith(
            (ref) => _EmptyLibraryNotifier(state),
          ),
          mediaLibraryFilterProvider.overrideWith((ref) => filter),
          appSettingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
          sitesProvider.overrideWith((ref) async => const []),
          allTripsProvider.overrideWith((ref) async => const []),
          allSpeciesProvider.overrideWith((ref) async => const []),
          tagsProvider.overrideWith((ref) async => const []),
          allBuddiesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MediaLibraryView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('with no filter, an empty library says so', (tester) async {
    await pumpEmpty(tester, MediaLibraryFilter.none);
    expect(find.text('No media yet'), findsOneWidget);
    expect(find.text('No media matches these filters'), findsNothing);
  });

  for (final (label, filter) in const [
    ('no one tagged', MediaLibraryFilter(noPeople: true)),
    ('not placed in the dive', MediaLibraryFilter(notPlacedInDive: true)),
    ('a site', MediaLibraryFilter(siteId: 's1')),
  ]) {
    testWidgets('under $label, the empty state names the filters', (
      tester,
    ) async {
      await pumpEmpty(tester, filter);
      expect(find.text('No media matches these filters'), findsOneWidget);
      expect(find.text('No media yet'), findsNothing);
    });
  }

  testWidgets('a failed load says so, never that nothing matches', (
    tester,
  ) async {
    // An emptied cleanup filter means "done", so a read that failed must
    // not pass for one.
    await pumpEmpty(
      tester,
      const MediaLibraryFilter(noPeople: true),
      state: MediaLibraryState(error: StateError('disk')),
    );
    expect(find.text('Error loading media'), findsOneWidget);
    expect(find.text('No media matches these filters'), findsNothing);
  });
}
