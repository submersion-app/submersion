import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_seascape_section.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'site_terrain_pane_test_support.dart';

void main() {
  Future<void> pumpSection(
    WidgetTester tester,
    SiteSeascapeState state, {
    VoidCallback? onOpenFullscreen,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => TestSettingsNotifier()),
          siteSeascapeProvider.overrideWith((ref, id) async => state),
          siteFeaturesProvider(
            'site-1',
          ).overrideWith((ref) async => const <SiteFeature>[]),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SiteSeascapeSection(
                siteId: 'site-1',
                onOpenFullscreen: onOpenFullscreen ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<ScrollController> pumpInScrollingPage(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => TestSettingsNotifier()),
          siteSeascapeProvider.overrideWith((ref, id) async => readyState()),
          siteFeaturesProvider(
            'site-1',
          ).overrideWith((ref) async => const <SiteFeature>[]),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  SiteSeascapeSection(
                    siteId: 'site-1',
                    onOpenFullscreen: () {},
                  ),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return controller;
  }

  testWidgets('shows the site terrain under the card title', (tester) async {
    await pumpSection(tester, readyState());

    expect(find.text('Site Seascape'), findsOneWidget);
    final pane = tester.widget<SiteTerrainPane>(find.byType(SiteTerrainPane));
    expect(pane.siteId, 'site-1');
    expect(pane.playbackContext, isNull);
  });

  testWidgets('gives the terrain a fixed height inside a scrolling page', (
    tester,
  ) async {
    // The pane fills its slot, so inside an unbounded scroll view the card
    // has to bound it or layout throws.
    await pumpSection(tester, readyState());

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(SiteTerrainPane)).height,
      SiteSeascapeSection.terrainHeight,
    );
  });

  testWidgets('gives the terrain more height on a phone-width card', (
    tester,
  ) async {
    // The pane's overlay chips sit below the terrain and wrap onto several
    // rows at phone width, which would otherwise squeeze the terrain itself.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);
    await pumpSection(tester, readyState());

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(SiteTerrainPane)).height,
      SiteSeascapeSection.narrowTerrainHeight,
    );
    expect(
      SiteSeascapeSection.narrowTerrainHeight,
      greaterThan(SiteSeascapeSection.terrainHeight),
    );
  });

  testWidgets('the fullscreen action hands control back to the host', (
    tester,
  ) async {
    var opened = 0;
    await pumpSection(tester, readyState(), onOpenFullscreen: () => opened++);

    await tester.tap(find.byTooltip('View fullscreen'));
    await tester.pump();

    expect(opened, 1);
  });

  // Issue #3393: inline, plain wheel ticks and two-finger swipes belong to
  // the page; only a deliberate zoom (Ctrl/Cmd + wheel, a pinch) or a drag
  // reaches the terrain.
  Offset overTerrain(WidgetTester tester) {
    final pane = tester.getRect(find.byType(SiteTerrainPane));
    // Left of centre, clear of the zoom buttons on the right edge.
    return Offset(pane.left + pane.width * 0.3, pane.center.dy);
  }

  double terrainZoom(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((p) => p.painter)
      .whereType<Dive3dScenePainter>()
      .single
      .zoom;

  group('mouse wheel inside a scrolling page', () {
    Future<void> wheelAt(
      WidgetTester tester,
      Offset at, {
      double dy = 120,
    }) async {
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(at));
      await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
      await tester.pump();
    }

    testWidgets('over the terrain, the page scrolls and the camera stays', (
      tester,
    ) async {
      final controller = await pumpInScrollingPage(tester);
      final zoom = terrainZoom(tester);

      await wheelAt(tester, overTerrain(tester));

      expect(controller.offset, greaterThan(0));
      expect(terrainZoom(tester), zoom);
    });

    for (final key in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.metaLeft,
    ]) {
      testWidgets('with ${key.keyLabel} held over the terrain, the camera '
          'zooms and the page stays', (tester) async {
        final controller = await pumpInScrollingPage(tester);
        final zoom = terrainZoom(tester);

        await tester.sendKeyDownEvent(key);
        await wheelAt(tester, overTerrain(tester), dy: -120);
        await tester.sendKeyUpEvent(key);

        expect(controller.offset, 0);
        expect(terrainZoom(tester), greaterThan(zoom));
      });
    }

    testWidgets('over the card title, the page scrolls', (tester) async {
      final controller = await pumpInScrollingPage(tester);

      await wheelAt(tester, tester.getCenter(find.text('Site Seascape')));

      expect(controller.offset, greaterThan(0));
    });
  });

  group('trackpad inside a scrolling page', () {
    Future<void> swipeAt(
      WidgetTester tester,
      Offset at, {
      double scale = 1,
    }) async {
      final pad = TestPointer(2, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pad.panZoomStart(at));
      for (var i = 1; i <= 10; i++) {
        await tester.sendEventToBinding(
          pad.panZoomUpdate(
            at,
            pan: Offset(0, -12.0 * i),
            scale: 1 + (scale - 1) * i / 10,
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.sendEventToBinding(pad.panZoomEnd());
      await tester.pump();
    }

    double terrainPanY(WidgetTester tester) => tester
        .widget<Transform>(find.byKey(const ValueKey('dive3dViewportPan')))
        .transform
        .getTranslation()
        .y;

    testWidgets('a two-finger swipe over the terrain scrolls the page and '
        'leaves the camera', (tester) async {
      final controller = await pumpInScrollingPage(tester);
      final zoom = terrainZoom(tester);

      await swipeAt(tester, overTerrain(tester));

      expect(controller.offset, greaterThan(0));
      expect(terrainPanY(tester), 0);
      expect(terrainZoom(tester), zoom);
    });

    testWidgets('a pinch over the terrain zooms the camera', (tester) async {
      await pumpInScrollingPage(tester);
      final zoom = terrainZoom(tester);

      await swipeAt(tester, overTerrain(tester), scale: 1.5);

      expect(terrainZoom(tester), greaterThan(zoom));
      expect(terrainPanY(tester), 0);
    });

    testWidgets('a two-finger swipe over the card title scrolls the page', (
      tester,
    ) async {
      final controller = await pumpInScrollingPage(tester);

      await swipeAt(tester, tester.getCenter(find.text('Site Seascape')));

      expect(controller.offset, greaterThan(0));
      expect(terrainPanY(tester), 0);
    });
  });

  testWidgets('a site without depth data says so inside the card', (
    tester,
  ) async {
    await pumpSection(tester, const SiteSeascapeNoData());

    expect(find.text('Site Seascape'), findsOneWidget);
    expect(
      find.text('No bathymetry available for this location'),
      findsOneWidget,
    );
  });
}
