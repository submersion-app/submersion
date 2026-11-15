import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_info_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/recording_url_launcher.dart';

const _osm = CatalogueSource(
  key: 'osm',
  name: 'OpenStreetMap',
  licence: 'ODbL-1.0',
  credit: 'OpenStreetMap contributors',
);

const _full = CatalogueSite(
  id: 'osm_node_1',
  name: 'Salt Pier',
  location: GeoPoint(12.08, -68.28),
  country: 'Caribbean Netherlands',
  island: 'Bonaire',
  minDepth: 5,
  maxDepth: 15,
  typeIds: ['reef'],
  entryMethods: [EntryMethod.shore],
  hazards: 'Boat traffic',
  description: 'Pillars covered in sponges.',
  website: 'https://example.org/salt-pier',
  source: 'osm',
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  AppSettings settings = const AppSettings(),
  CatalogueSource? source = _osm,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        unitFormatterProvider.overrideWithValue(UnitFormatter(settings)),
        catalogueSourceProvider.overrideWith((ref, key) async => source),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _explanation =
    'Gathered from published sources, not from a survey. Check the '
    'position locally before you rely on it.';

void main() {
  group('a researched record', () {
    testWidgets('is marked Not verified with its explanation', (tester) async {
      await _pump(
        tester,
        BuiltInSiteInfoCard(
          site: const CatalogueSite(
            id: 'research_id_usat_liberty',
            name: 'USAT Liberty',
            source: 'research',
            trust: CatalogueTrust.researched,
          ),
          actionLabel: 'Add to my sites',
          onAction: () async {},
        ),
      );

      expect(find.text('Not verified'), findsOneWidget);
      expect(find.text(_explanation), findsOneWidget);
    });

    testWidgets('a verified record carries neither', (tester) async {
      await _pump(
        tester,
        BuiltInSiteInfoCard(
          site: _full,
          actionLabel: 'Add to my sites',
          onAction: () async {},
        ),
      );

      expect(find.text('Not verified'), findsNothing);
      expect(find.text(_explanation), findsNothing);
    });
  });

  testWidgets('shows what the catalogue knows about the site', (tester) async {
    await _pump(
      tester,
      BuiltInSiteInfoCard(
        site: _full,
        actionLabel: 'Add to my sites',
        onAction: () async {},
      ),
    );

    expect(find.text('Salt Pier'), findsOneWidget);
    expect(find.text('Bonaire, Caribbean Netherlands'), findsOneWidget);
    expect(find.text('5m–15m'), findsOneWidget);
    expect(find.text('Reef'), findsOneWidget);
    expect(find.text('Shore'), findsOneWidget);
    expect(find.text('Boat traffic'), findsOneWidget);
    expect(find.text('Pillars covered in sponges.'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('Source: OpenStreetMap contributors'), findsOneWidget);
    expect(find.text('Add to my sites'), findsOneWidget);
  });

  testWidgets('a long translated action label wraps instead of overflowing', (
    tester,
  ) async {
    // The German label beside a Website button is wider than a phone's
    // card. A layout that cannot shrink reports an overflow here.
    await _pump(
      tester,
      Center(
        child: SizedBox(
          width: 328,
          child: BuiltInSiteInfoCard(
            site: _full,
            actionLabel: 'Zu meinen Tauchplätzen hinzufügen',
            onAction: () async {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('Zu meinen Tauchplätzen hinzufügen'), findsOneWidget);
  });

  testWidgets('with no action the button is there but cannot be pressed', (
    tester,
  ) async {
    // The import page's sheet for a site the diver already has.
    await _pump(
      tester,
      const BuiltInSiteInfoCard(
        site: _full,
        actionLabel: 'Already Imported',
        onAction: null,
      ),
    );

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Already Imported'),
        matching: find.bySubtype<FilledButton>(),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('shows depths in the diver\'s unit', (tester) async {
    await _pump(
      tester,
      BuiltInSiteInfoCard(
        site: _full,
        actionLabel: 'Add to my sites',
        onAction: () async {},
      ),
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    );

    expect(find.text('16ft–49ft'), findsOneWidget);
    expect(find.text('5m–15m'), findsNothing);
  });

  testWidgets('a site with only a name shows only that and the action', (
    tester,
  ) async {
    await _pump(
      tester,
      BuiltInSiteInfoCard(
        site: const CatalogueSite(id: 'x', name: 'Blue Hole', source: 'osm'),
        actionLabel: 'Use this site',
        onAction: () async {},
      ),
      source: null,
    );

    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.text('Use this site'), findsOneWidget);
    expect(find.text('Website'), findsNothing);
    expect(find.textContaining('Source:'), findsNothing);
    expect(find.byIcon(Icons.warning_amber_outlined), findsNothing);
  });

  testWidgets('Website opens the site\'s website, outside the app', (
    tester,
  ) async {
    final launcher = useRecordingUrlLauncher();
    await _pump(
      tester,
      BuiltInSiteInfoCard(
        site: _full,
        actionLabel: 'Add to my sites',
        onAction: () async {},
      ),
    );

    await tester.tap(find.text('Website'));
    await tester.pump();

    expect(launcher.launched, ['https://example.org/salt-pier']);
    expect(launcher.modes, [PreferredLaunchMode.externalApplication]);
  });

  testWidgets('a website that is not a web address shows no button', (
    tester,
  ) async {
    await _pump(
      tester,
      BuiltInSiteInfoCard(
        site: const CatalogueSite(
          id: 'x',
          name: 'Blue Hole',
          website: 'tel:+15551234',
          source: 'osm',
        ),
        actionLabel: 'Use this site',
        onAction: () async {},
      ),
    );

    expect(find.text('Website'), findsNothing);
  });

  testWidgets('the action runs once while it is in flight', (tester) async {
    var calls = 0;
    final gate = Completer<void>();
    await _pump(
      tester,
      BuiltInSiteInfoCard(
        site: _full,
        actionLabel: 'Add to my sites',
        onAction: () {
          calls++;
          return gate.future;
        },
      ),
    );

    await tester.tap(find.text('Add to my sites'));
    await tester.pump();
    await tester.tap(find.text('Add to my sites'), warnIfMissed: false);
    await tester.pump();

    expect(calls, 1);

    gate.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to my sites'));
    await tester.pump();
    expect(calls, 2);
  });

  testWidgets('the action comes back after a failure', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      BuiltInSiteInfoCard(
        site: _full,
        actionLabel: 'Add to my sites',
        onAction: () async {
          calls++;
          if (calls == 1) throw StateError('offline');
        },
      ),
    );

    await tester.tap(find.text('Add to my sites'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isStateError);

    await tester.tap(find.text('Add to my sites'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  group('Details', () {
    testWidgets('with a details action the card offers the record\'s page', (
      tester,
    ) async {
      var opened = 0;
      await _pump(
        tester,
        BuiltInSiteInfoCard(
          site: _full,
          actionLabel: 'Add to my sites',
          onAction: () async {},
          onDetails: () => opened++,
        ),
      );

      await tester.tap(find.text('Details'));

      expect(opened, 1);
      // The action it sits beside is still there.
      expect(find.text('Add to my sites'), findsOneWidget);
    });

    testWidgets('without one there is no Details button', (tester) async {
      await _pump(
        tester,
        BuiltInSiteInfoCard(
          site: _full,
          actionLabel: 'Use this site',
          onAction: () async {},
        ),
      );

      expect(find.text('Details'), findsNothing);
    });

    testWidgets('the picker\'s sheet has no Details button', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showCatalogueSiteDetails(
              context,
              site: _full,
              actionLabel: 'Use this site',
              onAction: () async {},
            ),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Salt Pier'), findsOneWidget);
      expect(find.text('Details'), findsNothing);
    });

    testWidgets('Details, Website and a long action fit a narrow card: '
        'the action takes a line of its own and wraps inside its button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(
        tester,
        BuiltInSiteInfoCard(
          site: _full,
          actionLabel: 'Zu meinen Tauchplätzen hinzufügen',
          onAction: () async {},
          onDetails: () {},
        ),
      );

      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(Card));
      final details = tester.getRect(find.text('Details'));
      final action = tester.getRect(find.bySubtype<FilledButton>());
      expect(action.top, greaterThan(details.bottom));
      expect(action.right, lessThanOrEqualTo(card.right - 16));
      expect(action.left, greaterThanOrEqualTo(card.left + 16));
    });

    testWidgets('an action that drops to its own line stays at the card\'s '
        'end, where it sits on a wider card', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Too wide to share a line with the two links, narrower than the
      // card: where it lands shows which side it is aligned to.
      await _pump(
        tester,
        BuiltInSiteInfoCard(
          site: _full,
          actionLabel: 'Add to my sites',
          onAction: () async {},
          onDetails: () {},
        ),
      );

      final card = tester.getRect(find.byType(Card));
      final details = tester.getRect(find.text('Details'));
      final action = tester.getRect(find.bySubtype<FilledButton>());
      expect(action.top, greaterThan(details.bottom));
      // Its margin and padding in from the card's right edge, with the
      // room it does not need left over on the other side.
      final endGap = card.right - action.right;
      expect(endGap, closeTo(16, 1));
      expect(action.left - card.left, greaterThan(endGap + 4));
    });

    testWidgets('where they fit, the links sit at the start and the action '
        'at the end of one line', (tester) async {
      tester.view.physicalSize = const Size(600, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(
        tester,
        BuiltInSiteInfoCard(
          site: _full,
          actionLabel: 'Add to my sites',
          onAction: () async {},
          onDetails: () {},
        ),
      );

      final card = tester.getRect(find.byType(Card));
      final details = tester.getRect(find.text('Details'));
      final action = tester.getRect(find.bySubtype<FilledButton>());
      expect(details.center.dy, closeTo(action.center.dy, 1));
      expect(details.left - card.left, lessThan(40));
      expect(card.right - action.right, closeTo(16, 1));
    });
  });

  testWidgets('the details sheet closes, then runs the action', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showCatalogueSiteDetails(
            context,
            site: _full,
            actionLabel: 'Use this site',
            onAction: () async => calls++,
          ),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Salt Pier'), findsOneWidget);
    expect(find.text('Pillars covered in sponges.'), findsOneWidget);

    await tester.tap(find.text('Use this site'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Salt Pier'), findsNothing);
  });
}
