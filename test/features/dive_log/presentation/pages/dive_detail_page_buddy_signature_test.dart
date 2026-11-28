import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// A buddy signs a dive on the dive page, from unlocking it to Save
/// (issue #5061).
void main() {
  late AppDatabase db;
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final ana = Buddy(id: 'b1', name: 'Ana', createdAt: epoch, updatedAt: epoch);

  setUp(() async {
    db = await setUpTestDatabase();
    await DiveRepository().createDive(dive);
    await db.customStatement(
      'INSERT INTO buddies (id, name, created_at, updated_at) '
      "VALUES ('b1', 'Ana', 0, 0)",
    );
    await BuddyRepository().setBuddiesForDive(dive.id, [
      BuddyWithRole(buddy: ana, roles: [DiveRole.synthetic(DiveRole.buddyId)]),
    ]);
  });
  tearDown(tearDownTestDatabase);

  Future<void> settleLong(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  // Stacked below Buddies at 600, beside it at 1000 (the pair's row needs
  // 700).
  for (final size in const [Size(600, 2400), Size(1000, 2400)]) {
    testWidgets('a buddy signs the unlocked dive and Save keeps it '
        '(${size.width.toInt()} wide)', (tester) async {
      await pumpPage(
        tester,
        stored: dive,
        visible: const {
          DiveDetailSectionId.buddies,
          DiveDetailSectionId.signatures,
        },
        size: size,
      );
      await settleLong(tester);
      await unlock(tester);
      await settleLong(tester);

      // Request shows only in the open card, so the card must offer its
      // pencil once the dive is unlocked.
      final pencil = find.byTooltip('Edit Signatures');
      expect(pencil, findsOneWidget);
      await tester.ensureVisible(pencil);
      await tester.tap(pencil);
      await settleLong(tester);

      final request = find.text('Request');
      expect(request.hitTestable(), findsOneWidget);
      await tester.tap(request);
      await settleLong(tester);
      await tester.tap(find.text('Ready to Sign'));
      await settleLong(tester);

      final canvas = find.bySemanticsLabel('Draw signature');
      final origin = tester.getCenter(canvas);
      final gesture = await tester.startGesture(origin - const Offset(60, 20));
      await gesture.moveBy(const Offset(40, 10));
      await gesture.moveBy(const Offset(40, 10));
      await gesture.moveBy(const Offset(40, 10));
      await gesture.up();
      await tester.pump();

      await tester.tap(find.text('Done').last);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settleLong(tester);

      expect(find.text('Ready to Sign'), findsNothing);
      expect(
        find.text('Request').hitTestable(),
        findsNothing,
        reason: 'the held signature replaces Request',
      );

      await tester.tap(find.text('Save').last);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settleLong(tester);

      final stored = await tester.runAsync(
        () => SignatureStorageService().getAllSignaturesForDive(dive.id),
      );
      expect(stored, hasLength(1));
      expect(stored!.single.signerId, 'b1');
    });
  }
}
