import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_pane_header.dart';

import 'site_detail_page_unlock_harness.dart';

/// The site page's pane header at a narrow pane (issue #4928): nothing
/// overflows and every control stays reachable when the header also
/// carries a shared library's button. Below the compact width, Connect on
/// this device moves to the top of the menu and a reader's Suggest changes
/// shows as an icon.
void main() {
  final l = AppLocalizationsEn();
  const suggestKey = ValueKey('site_suggest_unlock');
  final librarySite = harnessSite.copyWith(
    diverId: 'other',
    sharedLibraryId: 'L',
    location: const GeoPoint(12.08, -68.28),
  );

  List<Override> library({
    required bool connected,
    bool membershipFails = false,
  }) => [
    libraryRoleProvider(
      'L',
    ).overrideWith((ref) async => SharedLibraryRole.reader),
    libraryConnectedHereProvider('L').overrideWith((ref) async => connected),
    siteLibraryStateProvider('s1').overrideWith((ref) async => null),
    libraryMemberNamesProvider('L').overrideWith((ref) async => const {}),
    currentMembershipProvider('L').overrideWith(
      (ref) async => membershipFails
          ? throw StateError('no database')
          : const SharedLibraryMembership(
              id: 'm1',
              diverId: 'me',
              libraryId: 'L',
              memberId: 'mem1',
              displayName: 'Me',
              libraryName: 'Club',
              backendKind: 'folder',
              locationHint: 'Drive: club/',
            ),
    ),
  ];

  /// The cards that only a located site shows, the map among them,
  /// switched off: the site has coordinates for its Site Seascape button,
  /// and these cards would never settle here.
  List<SiteDetailSectionConfig> withoutLocatedCards() => [
    for (final s in SiteDetailSectionConfig.defaultSections)
      if (const {
        SiteDetailSectionId.location,
        SiteDetailSectionId.tide,
        SiteDetailSectionId.reefHealth,
        SiteDetailSectionId.features,
      }.contains(s.id))
        s.copyWith(visible: false)
      else
        s,
  ];

  Future<SiteUnlockHarness> pumpPane(
    WidgetTester tester, {
    required bool connected,
    double width = 390,
    String? initialLocation,
    bool membershipFails = false,
    TransitionBuilder? appBuilder,
  }) => pumpSitePage(
    tester,
    site: librarySite,
    settings: AppSettings(siteDetailSections: withoutLocatedCards()),
    embedded: true,
    onClose: () {},
    size: Size(width, 1400),
    initialLocation: initialLocation,
    appBuilder: appBuilder,
    extraRoutes: [
      GoRoute(
        path: '/settings/shared-libraries/connect',
        builder: (_, state) => Scaffold(body: Text('connect ${state.uri}')),
      ),
    ],
    extra: library(connected: connected, membershipFails: membershipFails),
  );

  /// The pane header's menu button.
  Finder menuButton() => find.byIcon(Icons.more_vert);

  group('at a 390 px pane', () {
    testWidgets('a library not connected here fits, with Connect first in '
        'the menu', (tester) async {
      await pumpPane(tester, connected: false);

      expect(tester.takeException(), isNull);
      expect(find.text(l.sharedLibrary_site_connectHere), findsNothing);

      await tester.tap(menuButton());
      await tester.pumpAndSettle();
      final connect = find.text(l.sharedLibrary_site_connectHere);
      expect(connect, findsOneWidget);
      // First in the menu: above every other entry.
      final items = find.byType(PopupMenuItem<String>);
      expect(
        tester.getTopLeft(connect).dy,
        lessThan(tester.getTopLeft(items.at(1)).dy),
      );
    });

    testWidgets('Connect from the menu opens the connect page', (tester) async {
      await pumpPane(tester, connected: false, initialLocation: '/sites/s1');
      await tester.tap(menuButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.sharedLibrary_site_connectHere));
      await tester.pumpAndSettle();

      // With the library's folder prefix, to prefill the connect form.
      expect(
        find.text('connect /settings/shared-libraries/connect?prefix=club%2F'),
        findsOneWidget,
      );
    });

    testWidgets('a membership that cannot be read opens connect unfilled', (
      tester,
    ) async {
      await pumpPane(
        tester,
        connected: false,
        initialLocation: '/sites/s1',
        membershipFails: true,
      );
      await tester.tap(menuButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.sharedLibrary_site_connectHere));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('connect /settings/shared-libraries/connect?prefix='),
        findsOneWidget,
      );
    });

    testWidgets('a reader\'s Suggest changes is an icon that unlocks', (
      tester,
    ) async {
      await pumpPane(tester, connected: true);

      expect(tester.takeException(), isNull);
      expect(find.text(l.sharedLibrary_suggest_title), findsNothing);
      final suggest = find.byKey(suggestKey);
      expect(suggest, findsOneWidget);
      expect(find.byTooltip(l.sharedLibrary_suggest_title), findsOneWidget);

      // A connected library has nothing to connect: the menu offers none.
      await tester.tap(menuButton());
      await tester.pumpAndSettle();
      expect(find.text(l.sharedLibrary_site_connectHere), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await tester.tap(suggest);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(RecordEditPaneHeader), findsOneWidget);
    });

    testWidgets('the site name stays on one line', (tester) async {
      await pumpPane(tester, connected: false);

      final name = tester.widget<Text>(find.text(librarySite.name).first);
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
    });
  });

  group('at a wide pane', () {
    testWidgets('Connect on this device stays a button in the row', (
      tester,
    ) async {
      await pumpPane(tester, connected: false, width: 900);

      expect(tester.takeException(), isNull);
      expect(
        find.widgetWithText(TextButton, l.sharedLibrary_site_connectHere),
        findsOneWidget,
      );
      await tester.tap(menuButton());
      await tester.pumpAndSettle();
      // Not also in the menu.
      expect(find.text(l.sharedLibrary_site_connectHere), findsOneWidget);
    });

    testWidgets('a reader\'s Suggest changes keeps its words', (tester) async {
      await pumpPane(tester, connected: true, width: 900);

      expect(tester.takeException(), isNull);
      expect(find.text(l.sharedLibrary_suggest_title), findsOneWidget);
    });

    testWidgets('large text folds Connect into the menu on a wider pane', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPane(tester, connected: false, width: 640);

      expect(tester.takeException(), isNull);
      expect(find.text(l.sharedLibrary_site_connectHere), findsNothing);
      await tester.tap(menuButton());
      await tester.pumpAndSettle();
      expect(find.text(l.sharedLibrary_site_connectHere), findsOneWidget);
    });

    testWidgets('a nonlinear text scaler folds Connect as its label grows', (
      tester,
    ) async {
      // As Android 14's: small text doubles, large sizes barely grow.
      await pumpPane(
        tester,
        connected: false,
        width: 640,
        appBuilder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const _SmallTextDoubles()),
          child: child!,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(l.sharedLibrary_site_connectHere), findsNothing);
    });
  });
}

/// Doubles sizes up to 20 and leaves larger ones as they are, the shape of
/// a platform's nonlinear font scaling.
class _SmallTextDoubles extends TextScaler {
  const _SmallTextDoubles();

  @override
  double scale(double fontSize) => fontSize <= 20 ? fontSize * 2 : fontSize;

  @override
  double get textScaleFactor => 2;
}
