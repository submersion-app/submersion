import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_active_path_overlay_builder.dart';
import 'package:submersion/features/site_scape/presentation/path_provenance_chip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _host(SiteActivePathOverlay overlay) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: PathProvenanceChip(overlay: overlay)),
);

SiteActivePathOverlay _overlay(PathProvenance provenance, {String? label}) =>
    SiteActivePathOverlay(
      scrubPath: const ScrubPath(normalizedTimes: [], xs: [], ys: [], zs: []),
      provenance: provenance,
      pathSourceLabel: label,
    );

void main() {
  testWidgets(
    'measured without a source label reads as a plain recorded route',
    (tester) async {
      await tester.pumpWidget(_host(_overlay(PathProvenance.measured)));
      expect(find.text('Recorded route'), findsOneWidget);
    },
  );

  testWidgets('measured with a source label names it', (tester) async {
    await tester.pumpWidget(
      _host(_overlay(PathProvenance.measured, label: 'Suunto')),
    );
    expect(find.text('Recorded route (Suunto)'), findsOneWidget);
  });

  testWidgets('dead reckoning reads as estimated', (tester) async {
    await tester.pumpWidget(_host(_overlay(PathProvenance.deadReckoned)));
    expect(find.text('Estimated path (dead reckoning)'), findsOneWidget);
  });

  testWidgets('straight line also reads as estimated', (tester) async {
    await tester.pumpWidget(_host(_overlay(PathProvenance.straightLine)));
    expect(find.text('Estimated path (dead reckoning)'), findsOneWidget);
  });

  testWidgets('a long source label wraps instead of overflowing on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        _overlay(
          PathProvenance.measured,
          label:
              'Seacraft Ghost ENC export 2026-07-28 Salt Pier north wall '
              'drift, second attempt, corrected heading',
        ),
      ),
    );

    // A RenderFlex overflow is reported through FlutterError, which the
    // test binding surfaces as a takeException().
    expect(tester.takeException(), isNull);
  });
}
