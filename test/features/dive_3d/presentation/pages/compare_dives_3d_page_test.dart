import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/compare_providers.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/presentation/pages/compare_dives_3d_page.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/compare_profile_3d_view.dart';

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
          diveComparisonProfilesProvider(
            const DiveIdSet(['a', 'b']),
          ).overrideWith(
            (ref) async => [
              prof('a', const Color(0xFF00D4FF)),
              prof('b', const Color(0xFFFF9500)),
            ],
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
}
