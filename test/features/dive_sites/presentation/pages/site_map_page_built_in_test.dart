import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_map_page.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

const _builtInA = ExternalDiveSite(
  externalId: 'a',
  name: 'A',
  // At the page's default center so it is within the zoom-3 viewport (the
  // marker cluster layer culls off-screen markers).
  latitude: 20,
  longitude: -157,
  source: 't',
);

/// A repository whose createSite always fails, to exercise the add-error path.
class _ThrowingSiteRepository extends SiteRepository {
  @override
  Future<List<DiveSite>> getAllSites({String? diverId}) async => [];

  @override
  Future<DiveSite> createSite(DiveSite site) async =>
      throw Exception('write failed');
}

void _usePhoneSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(600, 900);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Invokes the marker's onTap via its semantics action. The cluster plugin
/// keeps markers behind an IgnorePointer during its fade-in, so a pointer tap
/// never lands; the semantics tap drives the same GestureDetector.onTap.
Future<void> _semanticsTap(WidgetTester tester, String label) async {
  tester.semantics.tap(find.semantics.byLabel(label));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<ProviderContainer> _pumpMap(
  WidgetTester tester, {
  required List<Override> extraOverrides,
}) async {
  final base = await getBaseOverrides();
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        sitesWithCountsProvider.overrideWith((ref) async => []),
        siteCoverageHeatMapProvider.overrideWith(
          (ref) async => <HeatMapPoint>[],
        ),
        ...extraOverrides,
      ],
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteMapPage(),
          );
        },
      ),
    ),
  );
  // Avoid pumpAndSettle: the FlutterMap tile layer animates indefinitely.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return container;
}

void main() {
  testWidgets('built-in pins appear only when the toggle is on', (
    tester,
  ) async {
    _usePhoneSurface(tester);

    final container = await _pumpMap(
      tester,
      extraOverrides: [
        visibleBuiltInSitesProvider.overrideWith(
          (ref) async => const [_builtInA],
        ),
      ],
    );

    expect(find.byKey(const Key('builtInPin_a')), findsNothing);

    container.read(showBuiltInSitesProvider.notifier).state = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('builtInPin_a')), findsOneWidget);
  });

  group('built-in selection and import', () {
    setUp(() async {
      await setUpTestDatabase();
    });
    tearDown(() async {
      await tearDownTestDatabase();
    });

    testWidgets('selecting a pin shows its info card and adding imports it', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      final handle = tester.ensureSemantics();

      await _pumpMap(
        tester,
        extraOverrides: [
          heatMapSettingsProvider.overrideWith(
            (ref) => const HeatMapSettings(isVisible: false),
          ),
          showBuiltInSitesProvider.overrideWith((ref) => true),
          siteRepositoryProvider.overrideWithValue(SiteRepository()),
          visibleBuiltInSitesProvider.overrideWith(
            (ref) async => const [_builtInA],
          ),
        ],
      );

      // Selecting the pin shows the built-in info card with its add action.
      await _semanticsTap(tester, 'Built-in dive site: A');
      expect(find.text('Add to my sites'), findsOneWidget);

      // Adding imports the site and confirms via a snackbar, clearing the card.
      await tester.tap(find.text('Add to my sites'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Added to your sites'), findsOneWidget);
      expect(find.text('Add to my sites'), findsNothing);

      handle.dispose();
    });

    testWidgets('shows an error snackbar when adding a built-in site fails', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      final handle = tester.ensureSemantics();

      await _pumpMap(
        tester,
        extraOverrides: [
          heatMapSettingsProvider.overrideWith(
            (ref) => const HeatMapSettings(isVisible: false),
          ),
          showBuiltInSitesProvider.overrideWith((ref) => true),
          siteRepositoryProvider.overrideWithValue(_ThrowingSiteRepository()),
          visibleBuiltInSitesProvider.overrideWith(
            (ref) async => const [_builtInA],
          ),
        ],
      );

      await _semanticsTap(tester, 'Built-in dive site: A');
      await tester.tap(find.text('Add to my sites'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text("Couldn't add site. Please try again."), findsOneWidget);
      // The card stays so the user can retry.
      expect(find.text('Add to my sites'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('hiding built-in sites clears the selected info card', (
      tester,
    ) async {
      _usePhoneSurface(tester);
      final handle = tester.ensureSemantics();

      final container = await _pumpMap(
        tester,
        extraOverrides: [
          heatMapSettingsProvider.overrideWith(
            (ref) => const HeatMapSettings(isVisible: false),
          ),
          showBuiltInSitesProvider.overrideWith((ref) => true),
          siteRepositoryProvider.overrideWithValue(SiteRepository()),
          visibleBuiltInSitesProvider.overrideWith(
            (ref) async => const [_builtInA],
          ),
        ],
      );

      await _semanticsTap(tester, 'Built-in dive site: A');
      expect(find.text('Add to my sites'), findsOneWidget);

      container.read(showBuiltInSitesProvider.notifier).state = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Add to my sites'), findsNothing);

      handle.dispose();
    });
  });
}
