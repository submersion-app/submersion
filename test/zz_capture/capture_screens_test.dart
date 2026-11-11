// Throwaway capture harness for PR screenshots. Not committed.
//
// Run: CAPTURE_DIR=<dir> CAPTURE_STATE=before flutter test test/zz_capture
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/theme/full_themes/submersion_theme.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/pages/section_appearance_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

import '../features/dive_log/presentation/widgets/buoyancy_outcome_fixture.dart';
import '../helpers/mock_providers.dart';

final _outDir = Platform.environment['CAPTURE_DIR'] ?? '/tmp';
final _state = Platform.environment['CAPTURE_STATE'] ?? 'before';
const _fontsDir =
    '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';

List<DiveProfilePoint> _profile() {
  final pts = <DiveProfilePoint>[];
  double depthAt(int t) {
    final m = t / 60.0;
    if (m < 2.5) return m / 2.5 * 30;
    if (m < 26) return 28 + 2 * math.sin(m / 2.3);
    if (m < 29) return 28 - (m - 26) / 3 * 10;
    if (m < 38) return 18 - (m - 29) / 9 * 3 + 0.8 * math.sin(m);
    if (m < 42) return 15 - (m - 38) / 4 * 10;
    if (m < 45) return 5;
    if (m < 46) return 5 - (m - 45) * 5;
    return 0;
  }

  for (var t = 0; t <= 46 * 60; t += 10) {
    pts.add(DiveProfilePoint(timestamp: t, depth: depthAt(t), temperature: 24));
  }
  return pts;
}

Future<void> _loadFonts() async {
  Future<ByteData> f(String name) async =>
      ByteData.sublistView(await File(p.join(_fontsDir, name)).readAsBytes());
  await (FontLoader('Roboto')
        ..addFont(f('Roboto-Regular.ttf'))
        ..addFont(f('Roboto-Medium.ttf'))
        ..addFont(f('Roboto-Bold.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(f('MaterialIcons-Regular.otf'))).load();
}

Future<void> _save(WidgetTester tester, Key key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      p.join(_outDir, '$name-$_state.png'),
    ).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  final profile = _profile();
  final dive = createTestDiveWithBottomTime(maxDepth: 30, avgDepth: 21)
      .copyWith(
        profile: profile,
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'AL80',
            volume: 11.1,
            workingPressure: 207,
            startPressure: 200,
            endPressure: 60,
            gasMix: GasMix(o2: 32),
          ),
        ],
      );
  final pressures = {
    't1': [
      for (final pt in profile)
        TankPressurePoint(
          tankId: 't1',
          timestamp: pt.timestamp,
          pressure: 200 - 140 * pt.timestamp / profile.last.timestamp,
        ),
    ],
  };
  final analysis = ProfileAnalysisService().analyze(
    diveId: dive.id,
    depths: [for (final pt in profile) pt.depth],
    timestamps: [for (final pt in profile) pt.timestamp],
  );

  final repaintKey = GlobalKey();

  final fixture = buoyancyOutcome();
  final buoyancy = BuoyancyTwinOutcome(
    result: BuoyancyTwinResult(
      samples: [
        for (final pt in profile)
          TwinSample(
            timestamp: pt.timestamp,
            depthM: pt.depth,
            suitKg: 3 - pt.depth * 0.06,
            tanksKg: -2 + 1.6 * pt.timestamp / profile.last.timestamp,
            netKg: 1.2 - pt.depth * 0.06 + 1.6 * pt.timestamp / profile.last.timestamp,
          ),
      ],
      staticKg: fixture.result.staticKg,
      suitSurfaceKg: fixture.result.suitSurfaceKg,
      drysuitGasLiters: 0,
      pressuresEstimated: false,
      input: fixture.result.input,
    ),
    outputs: fixture.outputs,
  );

  Future<void> pumpDetail(
    WidgetTester tester,
    Size size,
    bool embedded, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides();
    final original = FlutterError.onError;
    addTearDown(() => FlutterError.onError = original);
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      original?.call(d);
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          sourceProfilesProvider(
            dive.id,
          ).overrideWith((ref) async => <String, SourceProfile>{}),
          gasSwitchesProvider(
            dive.id,
          ).overrideWith((ref) async => <GasSwitchWithTank>[]),
          tankPressuresProvider(dive.id).overrideWith((ref) async => pressures),
          sourceProfileAnalysisProvider((
            diveId: dive.id,
            sourceId: null,
          )).overrideWith((ref) async => analysis),
          if (_state == 'after')
            buoyancyTwinProvider(dive.id).overrideWith((ref) async => buoyancy),
        ],
        child: RepaintBoundary(
          key: repaintKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? submersionDark : submersionLight,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: embedded
                ? Scaffold(
                    body: DiveDetailPage(diveId: dive.id, embedded: true),
                  )
                : DiveDetailPage(diveId: dive.id),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> scrollTo(WidgetTester tester, double offset) async {
    final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
    state.position.jumpTo(offset.clamp(0, state.position.maxScrollExtent));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  for (final (label, size, embedded) in [
    ('desktop', const Size(900, 900), true),
    ('phone', const Size(390, 844), false),
  ]) {
    testWidgets('capture dive details $label', (tester) async {
      await pumpDetail(tester, size, embedded);
      await _save(tester, repaintKey, '01-dive-detail-top-$label');
      await scrollTo(tester, label == 'phone' ? 900 : 700);
      await _save(tester, repaintKey, '02-dive-detail-scrolled-$label');
    });
  }

  /// The profile card's bottom edge, relative to the scroll viewport's top,
  /// with the page at offset 0.
  double cardBottomAtRest(WidgetTester tester) {
    final viewportTop = tester.getTopLeft(find.byType(Scrollable).first).dy;
    return tester.getBottomLeft(find.byType(DiveDetailProfileSection)).dy -
        viewportTop;
  }

  if (_state == 'after') {
    for (final (label, size, embedded) in [
      ('desktop', const Size(900, 900), true),
      ('phone', const Size(390, 844), false),
    ]) {
      testWidgets('capture condense sequence $label', (tester) async {
        await pumpDetail(tester, size, embedded);
        final bottom = cardBottomAtRest(tester);
        final height = tester
            .getSize(find.byType(DiveDetailProfileSection))
            .height;
        final top = bottom - height;
        for (final (n, t) in [(1, 0.05), (2, 0.12), (3, 0.3), (4, 0.6), (5, 0.9)]) {
          await scrollTo(tester, top + t * (height - kPinnedStripHeight));
          await _save(tester, repaintKey, '04-condense-$n-$label');
        }
      });

      for (final dark in [false, true]) {
        final theme = dark ? '-dark' : '';
        testWidgets('capture pinned strip $label$theme', (tester) async {
          await pumpDetail(tester, size, embedded, dark: dark);
          await scrollTo(tester, label == 'phone' ? 900 : 700);
          await _save(tester, repaintKey, '05-pinned-hint-$label$theme');
          final container = ProviderScope.containerOf(
            tester.element(find.byType(DiveDetailPage)),
          );
          container.read(profileTrackingIndexProvider(dive.id).notifier).state =
              140;
          for (var i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          await _save(tester, repaintKey, '06-pinned-cursor-$label$theme');
        });
      }

      testWidgets('capture buoyancy cursor $label', (tester) async {
        await pumpDetail(tester, size, embedded);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DiveDetailPage)),
        );
        container.read(profileTrackingIndexProvider(dive.id).notifier).state =
            140;
        await tester.pump();
        final card = find.byType(BuoyancyChart);
        if (card.evaluate().isEmpty) return;
        await tester.ensureVisible(card);
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        await _save(tester, repaintKey, '07-buoyancy-cursor-$label');
      });
    }
  }

  testWidgets('capture appearance settings', (tester) async {
    tester.view.physicalSize = const Size(900, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: RepaintBoundary(
          key: repaintKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: submersionLight,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SectionAppearancePage(sectionKey: 'dives'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = find.text('Max depth marker');
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
    }
    await _save(tester, repaintKey, '03-appearance-dive-profile-desktop');
  });
}
