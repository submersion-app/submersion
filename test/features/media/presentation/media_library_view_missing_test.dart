import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/pages/media_library_view.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_missing_banner.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _SeededLibraryNotifier extends StateNotifier<MediaLibraryState>
    implements MediaLibraryNotifier {
  _SeededLibraryNotifier() : super(const MediaLibraryState());

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

void main() {
  testWidgets(
    'the Missing files facet shows the repair banner and its empty state',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaLibraryNotifierProvider.overrideWith(
              (ref) => _SeededLibraryNotifier(),
            ),
            mediaLibraryFilterProvider.overrideWith(
              (ref) =>
                  const MediaLibraryFilter(health: MediaHealthFilter.missing),
            ),
            missingOfflineCountProvider.overrideWith((ref) async => 2),
            missingCountProvider.overrideWith((ref) async => 2),
            appSettingsRepositoryProvider.overrideWithValue(
              _FakeSettingsRepo(),
            ),
            sitesProvider.overrideWith((ref) async => const []),
            allTripsProvider.overrideWith((ref) async => const []),
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

      expect(find.byType(MediaMissingBanner), findsOneWidget);
      expect(find.text('2 on offline volumes'), findsOneWidget);
      // Empty state names missing files, not the generic library copy.
      expect(find.text('No missing files'), findsOneWidget);
      // The facet also gets its removable chip in the strip.
      expect(find.text('Missing files'), findsOneWidget);
    },
  );
}
