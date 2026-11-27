import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/util/maps_link.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/helpers/site_link_launcher.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_contact_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/mock_providers.dart';

/// The Contact card and the directions it offers (issue #5073).
void main() {
  final l = AppLocalizationsEn();
  const stoney = DiveSite(
    id: 's1',
    name: 'Stoney Cove',
    location: GeoPoint(52.5763, -1.2905),
    address: 'Stoney Cove\nLE9 4DW',
    phone: '+44 1455 273089',
    email: 'info@stoneycove.com',
    website: 'https://stoneycove.com',
  );

  late List<Uri> launched;
  late bool launchSucceeds;

  setUp(() {
    launched = [];
    launchSucceeds = true;
  });

  List<Override> overrides() => [
    siteLinkLauncherProvider.overrideWithValue((uri) async {
      launched.add(uri);
      return launchSucceeds;
    }),
    mapsPlatformProvider.overrideWithValue(MapsPlatform.android),
  ];

  Future<void> pumpCard(WidgetTester tester, DiveSite site) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SiteContactCard(site: site)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows only the rows that are set', (tester) async {
    await pumpCard(tester, const DiveSite(id: 's', name: 'X', phone: '123'));

    expect(find.byKey(const ValueKey('site_contact_phone')), findsOneWidget);
    expect(find.byKey(const ValueKey('site_contact_address')), findsNothing);
    expect(find.byKey(const ValueKey('site_contact_email')), findsNothing);
    expect(find.byKey(const ValueKey('site_contact_website')), findsNothing);
  });

  testWidgets('taps call, mail and open the website', (tester) async {
    await pumpCard(tester, stoney);

    await tester.tap(find.byKey(const ValueKey('site_contact_phone')));
    await tester.tap(find.byKey(const ValueKey('site_contact_email')));
    await tester.tap(find.byKey(const ValueKey('site_contact_website')));
    await tester.pumpAndSettle();

    expect(launched.map((u) => u.toString()), [
      'tel:+441455273089',
      'mailto:info@stoneycove.com',
      'https://stoneycove.com',
    ]);
    // Shown without the scheme.
    expect(find.text('stoneycove.com'), findsOneWidget);
  });

  testWidgets('a website that is not a web address never opens', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const DiveSite(id: 's', name: 'X', website: 'javascript:alert(1)'),
    );

    expect(find.text('javascript:alert(1)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('site_contact_website')));
    await tester.pumpAndSettle();
    expect(launched, isEmpty);
  });

  testWidgets('directions open the address in the maps app', (tester) async {
    await pumpCard(tester, stoney);

    await tester.tap(find.byKey(const ValueKey('site_contact_directions')));
    await tester.pumpAndSettle();

    expect(
      launched.single.toString(),
      'geo:0,0?q=Stoney%20Cove%2C%20LE9%204DW',
    );
  });

  testWidgets('a refused launch says maps could not open', (tester) async {
    launchSucceeds = false;
    await pumpCard(tester, stoney);

    await tester.tap(find.byKey(const ValueKey('site_contact_directions')));
    await tester.pumpAndSettle();

    expect(find.text(l.diveSites_contact_mapsFailed), findsOneWidget);
  });

  testWidgets('a long press copies the value', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpCard(tester, stoney);

    await tester.longPress(find.byKey(const ValueKey('site_contact_phone')));
    await tester.pumpAndSettle();

    expect(copied, '+44 1455 273089');
    expect(find.text(l.common_snackbar_copiedToClipboard), findsOneWidget);
  });

  group('on the site page', () {
    Future<void> pumpPage(WidgetTester tester, DiveSite site) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(600, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(),
            ...overrides(),
            siteProvider(site.id).overrideWith((_) async => site),
            siteDiveCountProvider(site.id).overrideWith((_) async => 0),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SiteDetailPage(siteId: site.id),
          ),
        ),
      );
      // A site with GPS keeps its map moving: pump, never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('a site with GPS and no address gets directions on the pin', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const DiveSite(
          id: 's2',
          name: 'Pier',
          location: GeoPoint(12.1, -68.9),
          waterType: WaterType.salt,
        ),
      );

      expect(find.byType(SiteContactCard), findsNothing);
      final button = find.byKey(const ValueKey('site_location_directions'));
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button);
      await tester.pump();
      expect(launched.single.toString(), 'geo:12.1,-68.9?q=12.1,-68.9(Pier)');
    });

    testWidgets('a site with an address shows the card, not the pin button', (
      tester,
    ) async {
      await pumpPage(tester, stoney);

      await tester.scrollUntilVisible(
        find.byType(SiteContactCard),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(SiteContactCard), findsOneWidget);
      expect(
        find.byKey(const ValueKey('site_location_directions')),
        findsNothing,
      );
    });
  });
}
