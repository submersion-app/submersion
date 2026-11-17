import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// Plan 6's cards on the page together (issue #4527).
void main() {
  final profile = List.generate(
    21,
    (i) => DiveProfilePoint(
      timestamp: i * 60,
      depth: i < 3 ? i * 6.0 : (i > 17 ? (20 - i) * 6.0 : 18.0),
    ),
  );
  late Dive profiled;

  setUp(() async {
    await setUpTestDatabase();
    profiled = dive.copyWith(
      profile: profile,
      runtime: const Duration(minutes: 20),
      maxDepth: 18,
    );
    await DiveRepository().createDive(profiled);
  });
  tearDown(tearDownTestDatabase);

  /// The ten cards plan 6 gave an editor.
  const cards = [
    DiveDetailSectionId.profile,
    DiveDetailSectionId.safetyReview,
    DiveDetailSectionId.navTrack,
    DiveDetailSectionId.buddies,
    DiveDetailSectionId.signatures,
    DiveDetailSectionId.sightings,
    DiveDetailSectionId.media,
    DiveDetailSectionId.documents,
    DiveDetailSectionId.diveLab,
    DiveDetailSectionId.customFields,
  ];
  const size = Size(1000, 6000);

  Future<void> settleLong(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Finder pencilOf(DiveDetailSectionId id) => find.descendant(
    of: find.byKey(ValueKey('diveSection_${id.name}')),
    matching: find.byType(RecordPencilIcon),
  );
  Finder chipOf(DiveDetailSectionId id) =>
      find.byKey(ValueKey('addStrip_${id.name}'));

  /// Opens [id] from its pencil, or from the strip when the page leaves it
  /// out; false when neither is offered.
  Future<bool> open(WidgetTester tester, DiveDetailSectionId id) async {
    if (pencilOf(id).evaluate().isNotEmpty) {
      await tester.ensureVisible(pencilOf(id));
      await tester.tap(pencilOf(id));
    } else if (chipOf(id).evaluate().isNotEmpty) {
      await tapStripChip(tester, id.name);
    } else {
      return false;
    }
    await settleLong(tester);
    return true;
  }

  testWidgets('locked: no pencil and no strip on any of the ten', (
    tester,
  ) async {
    await pumpPage(
      tester,
      stored: profiled,
      visible: cards.toSet(),
      size: size,
    );
    await settleLong(tester);
    for (final id in cards) {
      expect(pencilOf(id), findsNothing, reason: id.name);
      expect(chipOf(id), findsNothing, reason: id.name);
    }
  });

  testWidgets('unlocked: every card with something to edit opens, from its '
      'pencil or the strip', (tester) async {
    await pumpPage(
      tester,
      stored: profiled,
      visible: cards.toSet(),
      size: size,
    );
    await settleLong(tester);
    await unlock(tester);
    await settleLong(tester);

    final offered = <DiveDetailSectionId>{};
    for (final id in cards) {
      if (await open(tester, id)) offered.add(id);
      expect(pencilOf(id), findsNothing, reason: '${id.name} stays shut');
    }
    // Signatures needs a buddy or a course, and the safety review a
    // finding: this dive has neither.
    expect(
      offered,
      cards.toSet().difference({
        DiveDetailSectionId.signatures,
        DiveDetailSectionId.safetyReview,
      }),
    );
  });

  testWidgets('opening and closing every card in imperial units leaves the '
      'sitting clean', (tester) async {
    await pumpPage(
      tester,
      stored: profiled,
      visible: cards.toSet(),
      size: size,
      imperial: true,
    );
    await settleLong(tester);
    await unlock(tester);
    await settleLong(tester);

    for (final id in cards) {
      if (!await open(tester, id)) continue;
      final done = find.text('Done');
      await tester.ensureVisible(done.first);
      await tester.tap(done.first);
      await settleLong(tester);
      expect(action(tester, 'Save').onPressed, isNull, reason: id.name);
    }
  });
}
