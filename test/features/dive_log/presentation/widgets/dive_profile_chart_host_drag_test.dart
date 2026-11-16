import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart_host.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #4611: the host wraps the chart in a MouseRegion of its own that
/// clears the shared cursor when the mouse leaves. A drag that strays off the
/// chart with the button held reports that exit too, and it must not drop
/// the cursor (and the buoyancy line following it) mid-scrub.
void main() {
  final profile = List.generate(
    40,
    (i) =>
        DiveProfilePoint(timestamp: i * 15, depth: i < 20 ? i * 1.0 : 40.0 - i),
  );

  testWidgets('a mouse drag off the host keeps the shared cursor', (
    tester,
  ) async {
    final dive = createTestDiveWithBottomTime().copyWith(profile: profile);
    final base = await getBaseOverrides();

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
          sourceProfileAnalysisProvider((
            diveId: dive.id,
            sourceId: null,
          )).overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 800,
                height: 400,
                child: DiveProfileChartHost(dive: dive),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveProfileChartHost)),
    );
    final writes = <int?>[];
    final sub = container.listen<int?>(
      profileTrackingIndexProvider(dive.id),
      (_, next) => writes.add(next),
    );
    addTearDown(sub.close);

    final rect = tester.getRect(find.byType(LineChart).first);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(rect.center);
    await tester.pump();
    await mouse.down(rect.center);
    await tester.pump();
    await mouse.moveTo(rect.center + const Offset(60, 0));
    await tester.pump();
    expect(writes.last, isNotNull);

    // Below the host (400 px tall in a 600 px view), button still held.
    writes.clear();
    await mouse.moveTo(Offset(rect.center.dx + 60, 520));
    await tester.pump();
    expect(writes.where((w) => w == null), isEmpty);

    await mouse.up();
    await tester.pump();
    expect(
      container.read(profileTrackingIndexProvider(dive.id)),
      isNull,
      reason: 'releasing ends the scrub',
    );
  });
}
