import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// The profile card pads its sides less than other cards, so the plot gets
/// the width; its top and bottom keep the usual 12 px (issue #5013).
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

  testWidgets('profile card pads its sides by 6 and top and bottom by 12', (
    tester,
  ) async {
    await pumpPage(
      tester,
      stored: profiled,
      visible: const {DiveDetailSectionId.profile},
      size: const Size(412, 1600),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    tester.takeException();

    final card = find.descendant(
      of: find.byType(DiveDetailProfileSection),
      matching: find.byType(Card),
    );
    final padding = tester.widget<Padding>(
      find
          .descendant(
            of: card,
            // The card's content: its margin is a Padding too, around this.
            matching: find.byWidgetPredicate(
              (w) => w is Padding && w.child is Column,
            ),
          )
          .first,
    );
    expect(padding.padding, const EdgeInsets.fromLTRB(6, 12, 6, 12));
  });
}
