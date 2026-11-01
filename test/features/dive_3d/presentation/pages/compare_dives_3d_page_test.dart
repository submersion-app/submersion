import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/compare_providers.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/presentation/pages/compare_dives_3d_page.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/compare_profile_3d_view.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/mock_providers.dart';

ComparisonProfile prof(String id, Color c) => ComparisonProfile(
  id: id,
  label: id,
  color: c,
  times: const [0, 60, 120],
  depths: const [0, 30, 0],
  maxDepthMeters: 30,
);

void main() {
  testWidgets('renders the compare view for the selected dives', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          diveComparisonProfilesProvider(DiveIdSet(['a', 'b'])).overrideWith(
            (ref) async => DiveComparison(
              profiles: [
                prof('a', const Color(0xFF00D4FF)),
                prof('b', const Color(0xFFFF9500)),
              ],
              comparableCount: 2,
            ),
          ),
        ],
        child: const CompareDives3dPage(diveIds: ['a', 'b']),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CompareProfile3dView), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('keeps the scene on screen while a change reloads it', (
    tester,
  ) async {
    final reload = Completer<void>();
    late Ref providerRef;
    var builds = 0;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          diveComparisonProfilesProvider(DiveIdSet(['a', 'b'])).overrideWith((
            ref,
          ) async {
            providerRef = ref;
            if (++builds > 1) await reload.future;
            return DiveComparison(
              profiles: [
                prof('a', const Color(0xFF00D4FF)),
                prof('b', const Color(0xFFFF9500)),
              ],
              comparableCount: 2,
            );
          }),
        ],
        child: const CompareDives3dPage(diveIds: ['a', 'b']),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Dive3dInteractiveViewport), findsOneWidget);

    providerRef.invalidateSelf();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(builds, 2);
    expect(find.byType(Dive3dInteractiveViewport), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    reload.complete();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('counts every comparable dive, not only the loaded ones', (
    tester,
  ) async {
    final ids = [for (var i = 0; i < 12; i++) 'd$i'];
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          diveComparisonProfilesProvider(DiveIdSet(ids)).overrideWith(
            (ref) async => DiveComparison(
              profiles: [
                for (final id in ids.take(kMaxComparisonProfiles))
                  prof(id, const Color(0xFF00D4FF)),
              ],
              comparableCount: ids.length,
            ),
          ),
        ],
        child: CompareDives3dPage(diveIds: ids),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Showing 8 of 12'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
