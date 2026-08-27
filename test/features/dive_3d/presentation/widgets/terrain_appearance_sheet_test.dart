import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// `show Intl`: intl also exports a TextDirection that shadows dart:ui's enum.
import 'package:intl/intl.dart' show Intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/terrain_appearance_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  /// The custom-level rows own their controllers, so the on-screen text is
  /// read from the controller rather than from a one-shot `initialValue`.
  String levelFieldText(WidgetTester tester, int index) => tester
      .widget<TextField>(find.byKey(ValueKey('seascapeLevelField$index')))
      .controller!
      .text;

  String? levelFieldSuffix(WidgetTester tester, int index) => tester
      .widget<TextField>(find.byKey(ValueKey('seascapeLevelField$index')))
      .decoration
      ?.suffixText;

  const twoLevels = AppSettings(
    seascapeAppearance: SeascapeAppearance(
      contourMode: SeascapeContourMode.custom,
      customLevels: [
        SeascapeContourLevel(depthMeters: 20),
        SeascapeContourLevel(depthMeters: 30),
      ],
    ),
  );

  /// The reporter's list: enough rows that the sheet has to scroll.
  final manyLevels = AppSettings(
    seascapeAppearance: SeascapeAppearance(
      contourMode: SeascapeContourMode.custom,
      customLevels: [
        for (var d = 10; d <= 100; d += 10)
          SeascapeContourLevel(depthMeters: d.toDouble()),
      ],
    ),
  );

  Future<ProviderContainer> pumpSheet(
    WidgetTester tester, {
    AppSettings initial = const AppSettings(),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(initial)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: TerrainAppearanceSheet()),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  /// Pumps the sheet through its real modal route, which is where the
  /// keyboard inset and the dismissal commit live.
  Future<ProviderContainer> pumpSheetRoute(
    WidgetTester tester, {
    AppSettings initial = const AppSettings(),
    EdgeInsets systemPadding = EdgeInsets.zero,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(initial)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // MaterialApp.builder wraps the Navigator, so padding stated here is
          // what the modal route's own SafeArea sees.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: systemPadding),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTerrainAppearanceSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return container;
  }

  // Issue #1188: the scroll-controlled sheet grew until it touched the top
  // edge of the screen. Its drag handle then sat inside Android's
  // notification-shade swipe zone, and with no close action the sheet became
  // impossible to dismiss.
  testWidgets('the sheet stops short of the top edge on a phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSheetRoute(tester);
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(sheet.top, greaterThan(0));
  });

  testWidgets('the Close action dismisses the sheet', (tester) async {
    await pumpSheetRoute(tester);
    expect(find.byType(TerrainAppearanceSheet), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('terrainAppearanceCloseButton')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TerrainAppearanceSheet), findsNothing);
  });

  testWidgets('the Close action stays reachable when the body scrolls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSheetRoute(tester);
    final closeButton = find.byKey(
      const ValueKey('terrainAppearanceCloseButton'),
    );
    final before = tester.getRect(closeButton);
    await tester.drag(
      find.byKey(const ValueKey('seascapeBandedSwitch')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(closeButton), before);
  });

  // `useSafeArea: true` inserts `SafeArea(bottom: false)`, so it covers top,
  // left and right and deliberately lets the sheet run to the bottom edge --
  // the SDK doc says so outright. The SafeArea in the builder is what applies
  // the bottom inset, and it is not a double application: SafeArea strips the
  // padding it consumes out of the MediaQuery, so each inset lands once.
  testWidgets('every system inset is applied exactly once', (tester) async {
    const insets = EdgeInsets.only(top: 44, left: 30, right: 30, bottom: 34);
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSheetRoute(tester, systemPadding: insets);

    final screen = tester.getRect(find.byType(MaterialApp));
    final sheet = tester.getRect(find.byType(BottomSheet));
    final body = tester.getRect(
      find.byKey(const ValueKey('terrainAppearanceSheetInsets')),
    );

    // Outer SafeArea: horizontal insets once, and no bottom inset at all.
    expect(sheet.left, insets.left);
    expect(sheet.right, screen.right - insets.right);
    expect(sheet.bottom, screen.bottom);
    // Inner SafeArea: the bottom inset the outer one skipped, and nothing
    // horizontal on top of what the outer one already applied.
    expect(body.bottom, screen.bottom - insets.bottom);
    expect(body.left, sheet.left);
    expect(body.right, sheet.right);
  });

  testWidgets('banded switch writes through to settings', (tester) async {
    final container = await pumpSheet(tester);
    expect(
      container.read(settingsProvider).seascapeAppearance.rampBanded,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('seascapeBandedSwitch')));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.rampBanded,
      isTrue,
    );
  });

  testWidgets('ramp range toggle seeds a default max and clears it', (
    tester,
  ) async {
    final container = await pumpSheet(tester);
    await tester.tap(find.byKey(const ValueKey('seascapeRampRangeSwitch')));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.rampMaxDepthMeters,
      40.0,
    );
    await tester.tap(find.byKey(const ValueKey('seascapeRampRangeSwitch')));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.rampMaxDepthMeters,
      isNull,
    );
  });

  testWidgets('custom mode adds a level via the add button', (tester) async {
    final container = await pumpSheet(tester);
    await tester.tap(find.text('Custom'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('seascapeAddLevelButton')));
    await tester.pump();
    final appearance = container.read(settingsProvider).seascapeAppearance;
    expect(appearance.contourMode, SeascapeContourMode.custom);
    expect(appearance.customLevels, hasLength(1));
    expect(appearance.customLevels.single.depthMeters, 10.0);
  });

  testWidgets('a feet diver gets a round seed in their own unit', (
    tester,
  ) async {
    // The editor shows display units, so seeding a fixed 10 m would read as
    // 32.8 ft. The seed is 10 DISPLAY units, stored as meters underneath.
    final container = await pumpSheet(
      tester,
      initial: const AppSettings(depthUnit: DepthUnit.feet),
    );
    await tester.tap(find.text('Custom'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('seascapeAddLevelButton')));
    await tester.pump();
    final level = container
        .read(settingsProvider)
        .seascapeAppearance
        .customLevels
        .single;
    expect(level.depthMeters, closeTo(3.048, 1e-9)); // 10 ft
    // The row's field reads the round display value, not 32.8.
    expect(levelFieldText(tester, 0), '10');
  });

  testWidgets('surface mode segmented control writes through', (tester) async {
    final container = await pumpSheet(tester);
    expect(
      container.read(settingsProvider).seascapeAppearance.surfaceMode,
      SeascapeSurfaceMode.blend,
    );
    await tester.tap(find.text('Map imagery'));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.surfaceMode,
      SeascapeSurfaceMode.imagery,
    );
    await tester.tap(find.text('Depth colors'));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.surfaceMode,
      SeascapeSurfaceMode.depth,
    );
  });

  testWidgets('wall angle slider persists its value', (tester) async {
    final container = await pumpSheet(tester);
    final slider = find.byKey(const ValueKey('seascapeWallAngleSlider'));
    await tester.drag(slider, const Offset(200, 0));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.wallAngleDeg,
      greaterThan(22.0),
    );
  });

  // Issue #1094: a decimal keypad has no submit key, so requiring
  // onFieldSubmitted meant every typed level was silently discarded.
  group('custom level editing (issue #1094)', () {
    List<SeascapeContourLevel> levelsOf(ProviderContainer c) =>
        c.read(settingsProvider).seascapeAppearance.customLevels;

    testWidgets('a typed level is adopted when the field loses focus', (
      tester,
    ) async {
      final container = await pumpSheet(tester, initial: twoLevels);
      await tester.enterText(
        find.byKey(const ValueKey('seascapeLevelField0')),
        '35',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(levelsOf(container).first.depthMeters, 35.0);
    });

    testWidgets('a feet diver has the typed level stored as meters', (
      tester,
    ) async {
      final container = await pumpSheet(
        tester,
        initial: twoLevels.copyWith(depthUnit: DepthUnit.feet),
      );
      await tester.enterText(
        find.byKey(const ValueKey('seascapeLevelField0')),
        '100',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(levelsOf(container).first.depthMeters, closeTo(30.48, 1e-9));
    });

    testWidgets('unparseable text reverts to the stored level', (tester) async {
      final container = await pumpSheet(tester, initial: twoLevels);
      await tester.enterText(
        find.byKey(const ValueKey('seascapeLevelField0')),
        'abc',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(levelsOf(container).first.depthMeters, 20.0);
      expect(levelFieldText(tester, 0), '20');
    });

    testWidgets('a pending edit is adopted when the sheet is dismissed', (
      tester,
    ) async {
      // Closing the keyboard with the system back gesture leaves the field
      // focused, so dismissal is the last chance to keep the diver's number.
      final container = await pumpSheetRoute(tester, initial: twoLevels);
      await tester.enterText(
        find.byKey(const ValueKey('seascapeLevelField0')),
        '45',
      );
      await tester.pump();
      Navigator.of(tester.element(find.byType(TerrainAppearanceSheet))).pop();
      await tester.pumpAndSettle();
      expect(levelsOf(container).first.depthMeters, 45.0);
    });

    testWidgets('deleting a row re-seeds the rows that shift up', (
      tester,
    ) async {
      // The rows are keyed by index, so without a re-seed row 0 would keep
      // showing the deleted level's number.
      final container = await pumpSheet(tester, initial: twoLevels);
      await tester.tap(find.byKey(const ValueKey('seascapeLevelRemove0')));
      await tester.pump();
      expect(levelsOf(container).single.depthMeters, 30.0);
      expect(levelFieldText(tester, 0), '30');
    });

    testWidgets('switching depth unit re-seeds the row text', (tester) async {
      final container = await pumpSheet(tester, initial: twoLevels);
      await container
          .read(settingsProvider.notifier)
          .setDepthUnit(DepthUnit.feet);
      await tester.pump();
      expect(levelFieldText(tester, 0), '65.6'); // 20 m
    });

    testWidgets('moving to the next row commits the one being left', (
      tester,
    ) async {
      final container = await pumpSheet(tester, initial: twoLevels);
      await tester.enterText(
        find.byKey(const ValueKey('seascapeLevelField0')),
        '25',
      );
      await tester.tap(find.byKey(const ValueKey('seascapeLevelField1')));
      await tester.pump();
      expect(levelsOf(container).first.depthMeters, 25.0);
    });

    testWidgets('the tap-outside hook drops focus and commits', (tester) async {
      // On mobile a TextField does NOT give up focus when the diver taps the
      // sheet's own chrome, so the row wires onTapOutside itself. TapRegion's
      // pointer routing is framework behaviour and does not reproduce under
      // the test harness, so this drives the wired callback directly and
      // asserts the chain it is responsible for: unfocus, then commit.
      final container = await pumpSheet(tester, initial: twoLevels);
      final field = find.byKey(const ValueKey('seascapeLevelField0'));
      await tester.enterText(field, '27');
      expect(levelsOf(container).first.depthMeters, 20.0, reason: 'not yet');

      final onTapOutside = tester.widget<TextField>(field).onTapOutside;
      expect(onTapOutside, isNotNull);
      onTapOutside!(PointerDownEvent(position: tester.getCenter(field)));
      await tester.pump();

      expect(levelsOf(container).first.depthMeters, 27.0);
      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isFalse);
    });

    testWidgets('the keyboard done action commits the level', (tester) async {
      final container = await pumpSheet(tester, initial: twoLevels);
      await tester.enterText(
        find.byKey(const ValueKey('seascapeLevelField0')),
        '28',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(levelsOf(container).first.depthMeters, 28.0);
    });

    testWidgets('choosing a colour keeps the level depth', (tester) async {
      const blue = Color(0xFF3B82F6);
      final container = await pumpSheet(tester, initial: twoLevels);
      await tester.tap(find.byKey(const ValueKey('seascapeLevelColor0')));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) => w is CircleAvatar && w.backgroundColor == blue,
            )
            .last,
      );
      await tester.pumpAndSettle();
      final level = levelsOf(container).first;
      expect(level.colorArgb, blue.toARGB32());
      expect(level.depthMeters, 20.0);
    });

    testWidgets('an edit pending when the rows unmount is still adopted', (
      tester,
    ) async {
      // Dismissing the sheet unfocuses first, so the focus path handles it.
      // This is the case that path cannot see: the rows leave the tree with
      // no focus change at all, which is what the dispose commit is for.
      final container = await pumpSheet(tester, initial: twoLevels);
      await tester.enterText(
        find.byKey(const ValueKey('seascapeLevelField0')),
        '55',
      );
      final notifier = container.read(settingsProvider.notifier);
      await notifier.setSeascapeAppearance(
        container
            .read(settingsProvider)
            .seascapeAppearance
            .copyWith(contourMode: SeascapeContourMode.auto),
      );
      await tester.pump(); // unmounts the rows
      await tester.pump(); // lets the deferred commit land
      expect(levelsOf(container).first.depthMeters, 55.0);
    });

    testWidgets('a de diver dismissing an untouched sheet changes nothing', (
      tester,
    ) async {
      // The reporter is on a comma-decimal locale, and the new commit-on-
      // dismissal path is where a seed/parse mismatch would silently rescale
      // an untouched level. Feet display puts a fraction in every box.
      final previous = Intl.defaultLocale;
      Intl.defaultLocale = 'de';
      addTearDown(() => Intl.defaultLocale = previous);
      final container = await pumpSheetRoute(
        tester,
        initial: twoLevels.copyWith(depthUnit: DepthUnit.feet),
      );
      // Seeded with the diver's own decimal separator, as every other numeric
      // field now is (#1091). Showing a de diver "65.6" is the mismatch that
      // made them type a comma the app could not read back.
      expect(levelFieldText(tester, 0), '65,6'); // 20 m in feet
      Navigator.of(tester.element(find.byType(TerrainAppearanceSheet))).pop();
      await tester.pumpAndSettle();
      expect(levelsOf(container).map((l) => l.depthMeters), [
        closeTo(20.0, 1e-9),
        closeTo(30.0, 1e-9),
      ]);
    });

    testWidgets('rows are separated rather than stacked flush', (tester) async {
      // The rows read as one dense block when they touch; the boxes already
      // carry their own border, so they need real air between them.
      await pumpSheet(tester, initial: twoLevels);
      final first = tester.getRect(
        find.byKey(const ValueKey('seascapeLevelField0')),
      );
      final second = tester.getRect(
        find.byKey(const ValueKey('seascapeLevelField1')),
      );
      expect(second.top - first.bottom, greaterThanOrEqualTo(12.0));
    });

    testWidgets('a row lays out on a narrow phone without overflowing', (
      tester,
    ) async {
      // The unit suffix widened the depth box, and the colour dropdown shows a
      // translated "default ink" phrase, so the row has to be able to give.
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpSheet(tester, initial: twoLevels);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each row is labelled with the diver depth unit', (
      tester,
    ) async {
      await pumpSheet(tester, initial: twoLevels);
      expect(levelFieldSuffix(tester, 0), 'm');
      await pumpSheet(
        tester,
        initial: twoLevels.copyWith(depthUnit: DepthUnit.feet),
      );
      expect(levelFieldSuffix(tester, 0), 'ft');
    });
  });

  testWidgets('the sheet keeps its content clear of the keyboard', (
    tester,
  ) async {
    // Issue #1094: without a viewInsets pad the lower rows and the add
    // button sit behind the keypad with no scroll extent to reach them.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);
    await pumpSheetRoute(tester, initial: twoLevels);
    final padding = tester.widget<Padding>(
      find.byKey(const ValueKey('terrainAppearanceSheetInsets')),
    );
    expect(padding.padding.resolve(TextDirection.ltr).bottom, 280);
  });

  testWidgets('with the keypad open a long level list still scrolls fully', (
    tester,
  ) async {
    // The reporter's actual complaint: with many rows the bottom of the sheet
    // could not be brought into view while the keypad was up.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.reset);
    await pumpSheetRoute(tester, initial: manyLevels);

    // Every TextField nests its own Scrollable, so take the outermost.
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();

    // Scrolled to the end, the last control clears the keypad rather than
    // sitting underneath it.
    expect(
      tester
          .getRect(find.byKey(const ValueKey('seascapeWallAngleSlider')))
          .bottom,
      lessThanOrEqualTo(800 - 320),
    );
  });
}
