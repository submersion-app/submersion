import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/presentation/pages/media_library_view.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_subscription_error_banner.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _EmptyLibraryNotifier extends StateNotifier<MediaLibraryState>
    implements MediaLibraryNotifier {
  _EmptyLibraryNotifier() : super(const MediaLibraryState());

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

ManifestSubscription _failing() {
  final epoch = DateTime.utc(2026, 4, 28);
  return ManifestSubscription(
    id: 's1',
    manifestUrl: 'https://example.com/feed',
    format: ManifestFormat.json,
    displayName: 'Album',
    pollIntervalSeconds: 86400,
    isActive: true,
    createdAt: epoch,
    updatedAt: epoch,
    lastError: 'This share needs its password',
  );
}

void main() {
  // At desktop widths the media page moves the library's toolbar into its
  // header and builds the view with showToolbar: false; the failing
  // subscription banner must not go with it.
  for (final showToolbar in [true, false]) {
    testWidgets('shows a failing subscription with showToolbar: $showToolbar', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mediaLibraryNotifierProvider.overrideWith(
              (ref) => _EmptyLibraryNotifier(),
            ),
            failingManifestSubscriptionsProvider.overrideWith(
              (ref) async => [_failing()],
            ),
            missingOfflineCountProvider.overrideWith((ref) async => 0),
            missingCountProvider.overrideWith((ref) async => 0),
            appSettingsRepositoryProvider.overrideWithValue(
              _FakeSettingsRepo(),
            ),
            sitesProvider.overrideWith((ref) async => const []),
            allTripsProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: MediaLibraryView(showToolbar: showToolbar)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mediaSubscriptionErrorBanner')),
        findsOneWidget,
      );
    });
  }
}
