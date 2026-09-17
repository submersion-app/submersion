import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The profile image export lives in the overflow menu's Export sheet, beside
/// the other single-dive exports, instead of behind a share icon buried in the
/// profile chart's own header row.
///
/// The capture itself is unchanged: it still reads the `RepaintBoundary` the
/// chart is wrapped in. That boundary stays resolvable from the sheet because
/// the page body is a `SingleChildScrollView` over a `Column`, so every
/// section is laid out whatever the scroll offset. A lazy list would have
/// disposed the off-screen chart and the capture would fail.
void main() {
  Dive diveWithProfile() => createTestDiveWithBottomTime().copyWith(
    profile: List.generate(
      6,
      (i) => DiveProfilePoint(
        timestamp: i * 60,
        depth: i < 3 ? i * 8.0 : (5 - i) * 8.0,
      ),
    ),
  );

  Future<void> pumpDetail(WidgetTester tester, Dive dive) async {
    final base = await getBaseOverrides();

    // A tall surface so neither the page nor the export sheet is clipped by
    // the default 800x600 test viewport.
    tester.view.physicalSize = const Size(1600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The page overflows this viewport; those layout warnings are noise here.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      originalOnError?.call(d);
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          gasSwitchesProvider(
            dive.id,
          ).overrideWith((ref) async => <GasSwitchWithTank>[]),
          tankPressuresProvider(
            dive.id,
          ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
          sourceProfilesProvider(
            dive.id,
          ).overrideWith((ref) async => <String, SourceProfile>{}),
          weeklyOtuProvider(dive.id).overrideWith((ref) async => 0.0),
        ],
        child: MaterialApp(
          // Pinned: the finders below are English, and the host machine's
          // locale would otherwise pick one of the 11 supported languages.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveDetailPage(diveId: dive.id, embedded: true)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    FlutterError.onError = originalOnError;
  }

  Future<void> openExportSheet(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
  }

  testWidgets('the profile chart header no longer carries an export button', (
    tester,
  ) async {
    await pumpDetail(tester, diveWithProfile());

    expect(
      find.byTooltip('Export profile as image'),
      findsNothing,
      reason: 'the action moved into the overflow menu\'s Export sheet',
    );
  });

  testWidgets('the export sheet offers the profile image', (tester) async {
    await pumpDetail(tester, diveWithProfile());
    await openExportSheet(tester);

    expect(find.text('Profile as Image'), findsOneWidget);
    expect(
      find.text('Page as Image'),
      findsOneWidget,
      reason: 'the new entry sits beside the existing page capture',
    );
  });

  testWidgets('the chart stays capturable while the export sheet is up', (
    tester,
  ) async {
    // The whole move rests on this: the sheet is a modal route over the page,
    // and the page lays its sections out eagerly, so the boundary
    // _exportProfileChart resolves is still painted underneath. This repeats
    // that lookup and the capture it feeds.
    await pumpDetail(tester, diveWithProfile());
    await openExportSheet(tester);

    final chart = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    final boundary =
        chart.exportKey?.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    expect(boundary, isNotNull);

    final image = await boundary!.toImage(pixelRatio: 2.0);
    addTearDown(image.dispose);
    expect(image.width, greaterThan(0));
    expect(image.height, greaterThan(0));
  });

  testWidgets('choosing it opens the profile image destination sheet', (
    tester,
  ) async {
    await pumpDetail(tester, diveWithProfile());
    await openExportSheet(tester);

    await tester.tap(find.text('Profile as Image'));
    await tester.pumpAndSettle();

    expect(find.text('Export Profile Image'), findsOneWidget);
    expect(find.text('Save to Photos'), findsOneWidget);
  });

  testWidgets('a dive with no profile is not offered the profile image', (
    tester,
  ) async {
    // The profile section itself does not build for an empty profile, so the
    // RepaintBoundary the capture reads would not exist: offering the entry
    // would promise an export that can only fail.
    await pumpDetail(tester, createTestDiveWithBottomTime());
    await openExportSheet(tester);

    expect(find.text('Profile as Image'), findsNothing);
    expect(find.text('Page as Image'), findsOneWidget);
  });
}
