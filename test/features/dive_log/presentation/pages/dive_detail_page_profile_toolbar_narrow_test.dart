import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_3d/presentation/pages/dive_3d_page.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// On a narrow card the Profile toolbar folds its two 3D entries into a
/// More menu, so the title and, while unlocked, the pencil keep their place
/// (issue #4527, plan 11): the outliers button had tipped the row past a
/// 360 px phone.
void main() {
  late Dive profiled;

  setUp(() async {
    await setUpTestDatabase();
    profiled = dive.copyWith(
      profile: List.generate(
        20,
        (i) => DiveProfilePoint(timestamp: i * 4, depth: 10.0),
      ),
      runtime: const Duration(seconds: 80),
      maxDepth: 10,
    );
    await DiveRepository().createDive(profiled);
  });
  tearDown(tearDownTestDatabase);

  const sections = {DiveDetailSectionId.profile, DiveDetailSectionId.notes};

  Future<void> settleLong(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Finder inCard(Finder finder) => find.descendant(
    of: find.byType(DiveDetailProfileSection),
    matching: finder,
  );

  Finder more() => inCard(find.byTooltip('More'));

  testWidgets('at phone width 3D View and 3D Seascape fold into More', (
    tester,
  ) async {
    await pumpPage(
      tester,
      stored: profiled,
      visible: sections,
      size: const Size(360, 1600),
    );
    await settleLong(tester);
    tester.takeException();

    expect(inCard(find.byIcon(Icons.view_in_ar)), findsNothing);
    expect(inCard(find.byIcon(Icons.terrain)), findsNothing);
    expect(more(), findsOneWidget);

    await tester.tap(more());
    await settleLong(tester);
    expect(find.text('3D View'), findsOneWidget);
    expect(find.text('3D Seascape'), findsOneWidget);
  });

  testWidgets('3D View from More opens the dive scene', (tester) async {
    await pumpPage(
      tester,
      stored: profiled,
      visible: sections,
      size: const Size(360, 1600),
    );
    await settleLong(tester);
    tester.takeException();

    await tester.tap(more());
    await settleLong(tester);
    await tester.tap(find.text('3D View'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.widget<Dive3dPage>(find.byType(Dive3dPage)).diveId, dive.id);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wide enough, both 3D buttons show and there is no More', (
    tester,
  ) async {
    await pumpPage(
      tester,
      stored: profiled,
      visible: sections,
      size: const Size(412, 1600),
    );
    await settleLong(tester);
    // The hero header's stat row overflows in the test font at this width.
    tester.takeException();

    expect(inCard(find.byIcon(Icons.view_in_ar)), findsOneWidget);
    expect(inCard(find.byIcon(Icons.terrain)), findsOneWidget);
    expect(more(), findsNothing);
  });
}
