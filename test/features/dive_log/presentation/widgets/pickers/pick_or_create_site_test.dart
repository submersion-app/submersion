import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _existingSite = DiveSite(id: 'existing', name: 'House Reef');
const _newSite = DiveSite(id: 'new-site', name: 'Brand New Site');

/// Device GPS that never has a fix. None of these tests pass a dive or
/// device location, so the sheet asks for one; without this it would reach
/// the real Geolocator platform channel.
class _NoFixLocationService implements LocationService {
  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('returns the picked site without touching the new-site form', (
    tester,
  ) async {
    DiveSite? result;
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) =>
              Scaffold(body: ConsumerButton(onResult: (site) => result = site)),
        ),
        GoRoute(
          path: '/sites/new',
          builder: (context, state) =>
              const Scaffold(body: Text('new site form should not open')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationServiceProvider.overrideWithValue(_NoFixLocationService()),
          sitesProvider.overrideWith((ref) async => [_existingSite]),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('House Reef'));
    await tester.pumpAndSettle();

    expect(result?.id, 'existing');
    expect(find.text('new site form should not open'), findsNothing);
  });

  testWidgets('returns null when the sheet is dismissed', (tester) async {
    DiveSite? result;
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) =>
              Scaffold(body: ConsumerButton(onResult: (site) => result = site)),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationServiceProvider.overrideWithValue(_NoFixLocationService()),
          sitesProvider.overrideWith((ref) async => [_existingSite]),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open picker'));
    await tester.pumpAndSettle();
    // Dismiss by tapping the barrier above the draggable sheet.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets(
    'tapping "New Dive Site" seeds the form and returns the saved site',
    (tester) async {
      DiveSite? result;
      Object? seededLocation = 'untouched';
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => Scaffold(
              body: ConsumerButton(
                onResult: (site) => result = site,
                newSiteSeedLocation: const GeoPoint(1, 2),
              ),
            ),
          ),
          GoRoute(
            path: '/sites/new',
            builder: (context, state) {
              seededLocation = state.extra;
              return Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(_newSite.id),
                  child: const Text('save new site'),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            locationServiceProvider.overrideWithValue(_NoFixLocationService()),
            sitesProvider.overrideWith((ref) async => const []),
            // Resolves only the id the form saved, so a helper that
            // loaded any other id would come back null.
            siteProvider.overrideWith(
              (ref, id) async => id == _newSite.id ? _newSite : null,
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open picker'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Dive Site'));
      await tester.pumpAndSettle();

      expect(seededLocation, const GeoPoint(1, 2));
      await tester.tap(find.text('save new site'));
      await tester.pumpAndSettle();

      expect(result?.id, 'new-site');
    },
  );

  testWidgets('cancelling the new-site form returns null', (tester) async {
    DiveSite? result;
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) =>
              Scaffold(body: ConsumerButton(onResult: (site) => result = site)),
        ),
        GoRoute(
          path: '/sites/new',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(),
              child: const Text('cancel'),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationServiceProvider.overrideWithValue(_NoFixLocationService()),
          sitesProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Dive Site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}

/// Button that calls [pickOrCreateSite] with the ambient [WidgetRef] and
/// reports the result back to the test via [onResult].
class ConsumerButton extends ConsumerWidget {
  const ConsumerButton({
    super.key,
    required this.onResult,
    this.newSiteSeedLocation,
  });

  final void Function(DiveSite?) onResult;
  final GeoPoint? newSiteSeedLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () async {
        final site = await pickOrCreateSite(
          context,
          ref,
          selectedSiteId: null,
          newSiteSeedLocation: newSiteSeedLocation,
        );
        onResult(site);
      },
      child: const Text('open picker'),
    );
  }
}
