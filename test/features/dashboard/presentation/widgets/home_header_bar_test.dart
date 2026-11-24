import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_header_bar.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_light_chip.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_lights_scroller.dart';
import 'package:submersion/features/settings/presentation/widgets/submersion_about_dialog.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Backup age warns, last dive is quiet, insurance and no-fly are fine.
final _mixedGauges = DashboardGauges(
  hasGear: true,
  insurance: DiverInsurance(provider: 'DAN', expiryDate: DateTime(2099)),
  noFlyStatus: null,
  daysSinceLastDive: 3,
  lastBackupTime: DateTime.now().subtract(const Duration(days: 10)),
);

final _quietGauges = DashboardGauges(
  hasGear: true,
  insurance: DiverInsurance(provider: 'DAN', expiryDate: DateTime(2099)),
  noFlyStatus: null,
  daysSinceLastDive: 3,
  lastBackupTime: DateTime.now(),
);

Diver _diver(String name) => Diver(
  id: 'me',
  name: name,
  createdAt: DateTime(2020),
  updatedAt: DateTime(2020),
);

/// The switcher sheet's list, without a database behind it.
class _StubDiverListNotifier extends StateNotifier<AsyncValue<List<Diver>>>
    implements DiverListNotifier {
  _StubDiverListNotifier(List<Diver> divers) : super(AsyncValue.data(divers));

  @override
  Future<void> refresh() async {}
  @override
  Future<Diver> addDiver(Diver diver) async => diver;
  @override
  Future<void> updateDiver(Diver diver) async {}
  @override
  Future<DeleteDiverResult> deleteDiver(String id) async =>
      const DeleteDiverResult(reassignedTripsCount: 0, reassignedSitesCount: 0);
  @override
  Future<void> setAsDefault(String id) async {}
}

/// The app icon in the bar.
final _logo = find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == 'assets/icon/icon.png',
);

/// The + button that opens the quick actions.
final _plus = find.byKey(HomeHeaderBar.quickActionsKey);

int _gaugeBuilds = 0;

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  Future<Diver?> Function()? diver,
  String name = 'Eric',
  Future<DashboardGauges> Function()? gauges,
  Locale locale = const Locale('en'),
  double textScale = 1,
  Set<String> hiddenChips = const {},
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _gaugeBuilds = 0;
  final overrides = await getBaseOverrides(
    settingsNotifier: MockSettingsNotifier(
      AppSettings(hiddenHomeChips: hiddenChips),
    ),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          body: Column(children: [HomeHeaderBar(), HomeStatusStrip()]),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        dashboardGaugesProvider.overrideWith((ref) {
          _gaugeBuilds++;
          return (gauges ?? () async => _mixedGauges)();
        }),
        dashboardDiverProvider.overrideWith(
          (ref) => (diver ?? () async => _diver(name))(),
        ),
        diverListNotifierProvider.overrideWith(
          (ref) => _StubDiverListNotifier([_diver(name)]),
        ),
      ].cast(),
      child: MaterialApp.router(
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('a switcher with one diver', (tester) async {
    await _pump(tester, width: 1280);
    expect(find.byKey(HomeHeaderBar.switcherKey), findsOneWidget);
    expect(find.text('Eric'), findsOneWidget);
    expect(find.byTooltip('Switch Diver'), findsOneWidget);
  });

  // The divider's distance to the logo (its padding is inside its rect)
  // shows whether the switcher's slot is held: 2 + 6 = 8 without it, 52 with
  // a 44-point slot between.
  double dividerToLogo(WidgetTester tester) =>
      tester.getRect(_logo).left -
      tester.getRect(find.byKey(HomeHeaderBar.dividerKey)).right;

  testWidgets('the switcher holds its slot while the diver loads', (
    tester,
  ) async {
    final pending = Completer<Diver?>();
    await _pump(tester, width: 1280, diver: () => pending.future);
    expect(find.byKey(HomeHeaderBar.switcherKey), findsNothing);
    expect(dividerToLogo(tester), closeTo(52, 0.5));
  });

  // No diver to show: no empty, untappable slot left in the bar.
  for (final (label, diver) in [
    ('fails to load', () async => throw StateError('no database')),
    ('is missing', () async => null),
  ]) {
    testWidgets('no empty slot when the diver $label', (tester) async {
      await _pump(tester, width: 1280, diver: diver);
      expect(find.byKey(HomeHeaderBar.switcherKey), findsNothing);
      expect(dividerToLogo(tester), closeTo(8, 0.5));
    });
  }

  testWidgets('phone: one diver shows the avatar alone', (tester) async {
    await _pump(tester, width: 400);
    expect(find.byKey(HomeHeaderBar.switcherKey), findsOneWidget);
    expect(find.text('Eric'), findsNothing);
  });

  // The sheet is no dead end with a single profile: it offers a new one.
  testWidgets('one diver: the switcher opens the sheet with Add New Diver', (
    tester,
  ) async {
    await _pump(tester, width: 1280);
    await tester.tap(find.byKey(HomeHeaderBar.switcherKey));
    await tester.pumpAndSettle();
    expect(find.text('Switch Diver'), findsOneWidget);
    expect(find.text('Add New Diver'), findsOneWidget);
  });

  // The logo stands alone at the end of the bar, after every control, and
  // the lights start at the bar's leading edge.
  for (final (locale, rtl) in [
    (const Locale('en'), false),
    (const Locale('he'), true),
  ]) {
    testWidgets('+ starts the bar, the lights follow, the logo ends it '
        '(${locale.languageCode})', (tester) async {
      await _pump(tester, width: 1280, locale: locale);
      expect(find.text('Submersion'), findsNothing);
      final bar = tester.getRect(find.byType(HomeHeaderBar));
      final plus = tester.getRect(_plus);
      final logo = tester.getRect(_logo);
      final switcher = tester.getRect(find.byKey(HomeHeaderBar.switcherKey));
      final lights = [
        for (final e in find.byType(HomeLightChip).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
      if (rtl) {
        expect(bar.right - plus.right, lessThanOrEqualTo(12));
        expect(logo.left - bar.left, lessThanOrEqualTo(12));
        expect(logo.right, lessThanOrEqualTo(switcher.left));
        final lead = lights.map((r) => r.right).reduce((a, b) => a > b ? a : b);
        expect(lead, lessThanOrEqualTo(plus.left));
        expect(plus.left - lead, lessThanOrEqualTo(16));
      } else {
        expect(plus.left - bar.left, lessThanOrEqualTo(12));
        expect(bar.right - logo.right, lessThanOrEqualTo(12));
        expect(logo.left, greaterThanOrEqualTo(switcher.right));
        final lead = lights.map((r) => r.left).reduce((a, b) => a < b ? a : b);
        expect(lead, greaterThanOrEqualTo(plus.right));
        expect(lead - plus.right, lessThanOrEqualTo(16));
      }
    });
  }

  testWidgets('on a phone + starts the bar and the logo ends it', (
    tester,
  ) async {
    await _pump(tester, width: 400);
    final bar = tester.getRect(find.byType(HomeHeaderBar));
    expect(tester.getRect(_plus).left - bar.left, lessThanOrEqualTo(12));
    expect(bar.right - tester.getRect(_logo).right, lessThanOrEqualTo(12));
  });

  testWidgets('the logo opens About Submersion', (tester) async {
    await _pump(tester, width: 1280);
    await tester.tap(_logo);
    await tester.pumpAndSettle();
    expect(find.byType(SubmersionAboutDialog), findsOneWidget);
    expect(find.text('Log Dive'), findsNothing);
  });

  for (final width in [400.0, 1280.0]) {
    testWidgets('the logo is 32 points with room above and below at $width '
        'wide', (tester) async {
      await _pump(tester, width: width);
      expect(_logo, findsOneWidget);
      expect(tester.getSize(_logo), const Size(32, 32));
      final bar = tester.getRect(find.byType(HomeHeaderBar));
      final logo = tester.getRect(_logo);
      expect(logo.top - bar.top, greaterThanOrEqualTo(7));
      expect(bar.bottom - logo.bottom, greaterThanOrEqualTo(7));
    });
  }

  // Measured to the drawn tile, not its button: 12 from the bar's end and 8
  // from the switcher, mirrored in a right-to-left language. Material pads
  // tap targets to 48 on mobile and not on desktop, so both are checked.
  for (final (locale, rtl) in [
    (const Locale('en'), false),
    (const Locale('he'), true),
  ]) {
    testWidgets(
      'the logo sits 8 from the switcher and 12 from the end '
      '(${locale.languageCode})',
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.macOS,
      }),
      (tester) async {
        await _pump(tester, width: 1280, locale: locale);
        final bar = tester.getRect(find.byType(HomeHeaderBar));
        final logo = tester.getRect(_logo);
        final switcher = tester.getRect(find.byKey(HomeHeaderBar.switcherKey));
        if (rtl) {
          expect(logo.left - bar.left, closeTo(12, 0.5));
          expect(switcher.left - logo.right, closeTo(8, 0.5));
        } else {
          expect(bar.right - logo.right, closeTo(12, 0.5));
          expect(logo.left - switcher.right, closeTo(8, 0.5));
        }
      },
    );
  }

  // The actions live in the logo's menu: the bar itself holds no buttons
  // for them, and no separate More menu.
  testWidgets('desktop shows the lights and no action buttons', (tester) async {
    await _pump(tester, width: 1280);
    expect(find.text('Log Dive'), findsNothing);
    expect(find.text('Plan Dive'), findsNothing);
    expect(find.byTooltip('More'), findsNothing);
    expect(find.byTooltip('Log Dive'), findsNothing);
    expect(find.text('Insurance OK'), findsOneWidget);
    expect(find.byType(HomeStatusStrip), findsOneWidget);
    // The phone strip renders nothing at desktop width.
    expect(find.textContaining('all clear'), findsNothing);
  });

  testWidgets('every control in the header has an action', (tester) async {
    await _pump(tester, width: 1280);
    final wells = tester.widgetList<InkWell>(
      find.descendant(
        of: find.byType(HomeHeaderBar),
        matching: find.byType(InkWell),
      ),
    );
    expect(wells, isNotEmpty);
    for (final w in wells) {
      expect(w.onTap, isNotNull);
    }
  });

  testWidgets('phone: a warning is named and the rest are counted', (
    tester,
  ) async {
    await _pump(tester, width: 390);
    expect(find.textContaining('Backup'), findsOneWidget);
    expect(find.text('3 all clear'), findsOneWidget);
    expect(find.text('Insurance OK'), findsNothing);
  });

  testWidgets('phone: nothing amber or red shows one All clear pill', (
    tester,
  ) async {
    await _pump(tester, width: 390, gauges: () async => _quietGauges);
    expect(find.text('All clear'), findsOneWidget);
  });

  // The sheet's pills are drawn full size but, like the header's, each is
  // tappable across at least 44 points of height.
  testWidgets('phone: every light in the sheet is at least 44 high', (
    tester,
  ) async {
    await _pump(tester, width: 390);
    await tester.tap(find.text('3 all clear'));
    await tester.pumpAndSettle();
    final pills = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(HomeLightChip),
    );
    expect(pills, findsWidgets);
    for (final e in pills.evaluate()) {
      expect(
        tester.getSize(find.byWidget(e.widget)).height,
        greaterThanOrEqualTo(44),
      );
    }
  });

  testWidgets('phone: the count pill opens every light', (tester) async {
    await _pump(tester, width: 390);
    await tester.tap(find.text('3 all clear'));
    await tester.pumpAndSettle();
    expect(find.text('Insurance OK'), findsOneWidget);
  });

  for (final width in [390.0, 1280.0]) {
    testWidgets('the logo opens every quick action at $width wide', (
      tester,
    ) async {
      await _pump(tester, width: width);
      expect(find.byTooltip('Quick actions'), findsOneWidget);
      await tester.tap(_plus);
      await tester.pumpAndSettle();
      expect(find.text('Log Dive'), findsOneWidget);
      expect(find.text('Plan Dive'), findsOneWidget);
      expect(find.text('Emergency card'), findsOneWidget);
    });
  }

  testWidgets('Log dive in the logo menu offers the ways to add a dive', (
    tester,
  ) async {
    await _pump(tester, width: 1280);
    await tester.tap(_plus);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Dive'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('+ and the logo read as buttons with their own names', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, width: 1280);
    for (final tip in ['Quick actions', 'About Submersion']) {
      final data = tester.getSemantics(find.byTooltip(tip)).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue, reason: tip);
    }
    handle.dispose();
  });

  // With the action buttons in the + menu the bar has room to name the
  // diver at any width above a phone's.
  testWidgets('tablet: the switcher names the diver', (tester) async {
    await _pump(tester, width: 850);
    expect(
      find.descendant(
        of: find.byKey(HomeHeaderBar.switcherKey),
        matching: find.text('Eric'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a long diver name does not overflow the bar at 800 wide', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 800,
      name: 'Bartholomew Maximilian Featherstonehaugh-Cholmondeley',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('gauges error shows a retry that refetches', (tester) async {
    await _pump(
      tester,
      width: 1280,
      gauges: () async => throw StateError('boom'),
    );
    final before = _gaugeBuilds;
    await tester.tap(find.text('Status unavailable - tap to retry'));
    await tester.pump();
    await tester.pump();
    expect(_gaugeBuilds, greaterThan(before));
  });

  testWidgets('phone: every button is at least 44 by 44', (tester) async {
    await _pump(tester, width: 390);
    for (final finder in [
      find.byTooltip('Quick actions'),
      find.byTooltip('About Submersion'),
      find.byKey(HomeHeaderBar.switcherKey),
    ]) {
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(44), reason: '$finder');
      expect(size.height, greaterThanOrEqualTo(44), reason: '$finder');
    }
  });

  // Desktop platforms default to compact visual density, which shrinks a
  // button's minimum size; the header's buttons keep 44 points there too.
  testWidgets(
    'desktop: + and the logo are at least 44 by 44',
    (tester) async {
      await _pump(tester, width: 1280);
      for (final finder in [_plus, find.byTooltip('About Submersion')]) {
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(44), reason: '$finder');
        expect(size.height, greaterThanOrEqualTo(44), reason: '$finder');
      }
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

  testWidgets('a light can be tapped just above its pill', (tester) async {
    await _pump(
      tester,
      width: 1280,
      gauges: () async => throw StateError('boom'),
    );
    final before = _gaugeBuilds;
    final label = tester.getRect(
      find.text('Status unavailable - tap to retry'),
    );
    // Above the drawn pill, but inside the 44-point tap target.
    await tester.tapAt(Offset(label.center.dx, label.top - 8));
    await tester.pump();
    await tester.pump();
    expect(_gaugeBuilds, greaterThan(before));
  });

  testWidgets('every light is at least 44 high to tap', (tester) async {
    for (final width in [1280.0, 390.0]) {
      await _pump(tester, width: width);
      final chips = find.byType(HomeLightChip);
      expect(chips, findsWidgets, reason: '$width');
      for (final element in chips.evaluate()) {
        expect(
          element.size!.height,
          greaterThanOrEqualTo(44),
          reason: '$width',
        );
      }
    }
  });

  testWidgets('a mouse can drag the lights along when they overflow', (
    tester,
  ) async {
    await _pump(tester, width: 820, textScale: 2);
    final scrollable = find.descendant(
      of: find.byType(HomeHeaderBar),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.dragFrom(
      tester.getCenter(scrollable),
      const Offset(-200, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
  });

  // Issue #4920: the lights ran flush into the switcher, a pill clipped
  // against its border.
  for (final (locale, rtl) in [
    (const Locale('en'), false),
    (const Locale('he'), true),
  ]) {
    testWidgets('a divider with a gap each side parts the lights from the '
        'switcher (${locale.languageCode})', (tester) async {
      await _pump(tester, width: 820, locale: locale);
      // The rule itself, not the space either side of it.
      final divider = tester.getRect(
        find.descendant(
          of: find.byKey(HomeHeaderBar.dividerKey),
          matching: find.byType(VerticalDivider),
        ),
      );
      final switcher = tester.getRect(find.byKey(HomeHeaderBar.switcherKey));
      final lights = tester.getRect(
        find.descendant(
          of: find.byType(HomeHeaderBar),
          matching: find.byType(HomeLightsScroller),
        ),
      );
      if (rtl) {
        expect(switcher.right, lessThanOrEqualTo(divider.left - 6));
        expect(divider.right, lessThanOrEqualTo(lights.left - 6));
      } else {
        expect(lights.right, lessThanOrEqualTo(divider.left - 6));
        expect(divider.right, lessThanOrEqualTo(switcher.left - 6));
      }
    });
  }

  testWidgets('no stray divider with every light hidden', (tester) async {
    await _pump(
      tester,
      width: 1280,
      gauges: () async => const DashboardGauges(
        hasGear: true,
        insurance: null,
        noFlyStatus: null,
        daysSinceLastDive: null,
      ),
      hiddenChips: {for (final t in HomeChipType.values) t.name},
    );
    expect(find.byType(HomeLightChip), findsNothing);
    expect(find.byKey(HomeHeaderBar.dividerKey), findsNothing);
  });

  testWidgets('phone: no divider, the lights sit in the strip', (tester) async {
    await _pump(tester, width: 400);
    expect(find.byKey(HomeHeaderBar.dividerKey), findsNothing);
  });

  testWidgets('overflowing lights fade at the end, not clip', (tester) async {
    await _pump(tester, width: 820, textScale: 2);
    final scroller = find.descendant(
      of: find.byType(HomeHeaderBar),
      matching: find.byType(HomeLightsScroller),
    );
    final state = tester.state<HomeLightsScrollerState>(scroller);
    expect(state.fadesStart, isFalse);
    expect(state.fadesEnd, isTrue);
  });

  testWidgets('phone: overflowing lights in the strip fade too', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 360,
      textScale: 2,
      gauges: () async => DashboardGauges(
        hasGear: true,
        insurance: DiverInsurance(provider: 'DAN', expiryDate: DateTime(2000)),
        noFlyStatus: null,
        daysSinceLastDive: 400,
        lastBackupTime: DateTime.now().subtract(const Duration(days: 90)),
      ),
    );
    final scroller = find.descendant(
      of: find.byType(HomeStatusStrip),
      matching: find.byType(HomeLightsScroller),
    );
    expect(tester.state<HomeLightsScrollerState>(scroller).fadesEnd, isTrue);
  });

  testWidgets('German at text scale 2 fits the bar at 800 wide', (
    tester,
  ) async {
    await _pump(tester, width: 800, locale: const Locale('de'), textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: with every light hidden the strip claims nothing', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 390,
      gauges: () async => const DashboardGauges(
        hasGear: true,
        insurance: null,
        noFlyStatus: null,
        daysSinceLastDive: null,
      ),
      hiddenChips: {for (final t in HomeChipType.values) t.name},
    );
    expect(find.text('All clear'), findsNothing);
    // No empty, bordered bar is left behind under the header.
    expect(tester.getSize(find.byType(HomeStatusStrip)).height, 0);
  });

  testWidgets('phone: no empty strip while the lights load', (tester) async {
    final never = Completer<DashboardGauges>();
    await _pump(tester, width: 390, gauges: () => never.future);
    expect(tester.getSize(find.byType(HomeStatusStrip)).height, 0);
  });

  testWidgets('phone: the sheet lists warnings before quiet lights', (
    tester,
  ) async {
    await _pump(tester, width: 390);
    await tester.tap(find.text('3 all clear'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    final backup = tester.getTopLeft(
      find.descendant(of: sheet, matching: find.textContaining('Backup')),
    );
    final insurance = tester.getTopLeft(
      find.descendant(of: sheet, matching: find.text('Insurance OK')),
    );
    expect(
      backup.dy < insurance.dy ||
          (backup.dy == insurance.dy && backup.dx < insurance.dx),
      isTrue,
    );
  });
}
