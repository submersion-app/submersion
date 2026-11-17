import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_signatures_sitting.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../helpers/test_database.dart';

/// Signatures captured and deleted in a sitting, written at Save (issue
/// #4527, plan 6).
void main() {
  late AppDatabase db;
  late SignatureStorageService service;
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final ana = Buddy(id: 'b1', name: 'Ana', createdAt: epoch, updatedAt: epoch);
  final dive = Dive(id: 'd1', dateTime: epoch, courseIds: const ['c1']);
  final png = Uint8List.fromList(const [1, 2, 3]);

  setUp(() async {
    db = await setUpTestDatabase();
    service = SignatureStorageService();
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO buddies (id, name, created_at, updated_at) '
      "VALUES ('b1', 'Ana', 0, 0)",
    );
    await BuddyRepository().setBuddiesForDive('d1', [
      BuddyWithRole(buddy: ana, roles: [DiveRole.synthetic(DiveRole.buddyId)]),
    ]);
  });
  tearDown(tearDownTestDatabase);

  Future<EditSession<Dive>> started() async {
    final session = EditSession<Dive>(dive);
    addTearDown(() {
      if (!session.isDisposed) session.dispose();
    });
    await diveBuddiesList.load(session);
    await diveSignaturesList.load(session);
    return session;
  }

  Signature instructor() => Signature(
    id: 'held-1',
    diveId: 'd1',
    imageData: png,
    signerName: 'Ines',
    signedAt: epoch,
    type: SignatureType.instructor,
  );

  Signature fromAna() => Signature(
    id: 'held-2',
    diveId: 'd1',
    imageData: png,
    signerId: 'b1',
    signerName: 'Ana',
    signedAt: epoch,
    type: SignatureType.buddy,
    role: DiveRole.buddyId,
  );

  test('a captured signature is written at Save with its bytes; Cancel writes '
      'nothing', () async {
    final session = await started();
    addCapturedSignature(session, instructor());
    expect(session.changedCardIds, {'signatures'});
    expect(await service.getAllSignaturesForDive('d1'), isEmpty);

    await session.runHeldWrites();
    final stored = await service.getSignatureForDive('d1');
    expect(stored?.signerName, 'Ines');
    expect(stored?.imageData, png);
    expect(stored?.id, isNot('held-1'));
    // Signed when it was captured, however long before Save.
    expect(stored?.signedAt, epoch);

    final other = await started();
    addCapturedSignature(other, fromAna());
    other.dispose();
    expect(await service.getBuddySignaturesForDive('d1'), isEmpty);
  });

  test('a deleted signature is deleted at Save', () async {
    await service.saveSignature(
      diveId: 'd1',
      imageBytes: png,
      signerName: 'Ines',
    );
    final session = await started();
    final stored = diveSignaturesList.current(session)!.single;
    removeSignature(session, stored.id);
    expect(session.isDirty, isTrue);

    await session.runHeldWrites();
    expect(await service.getAllSignaturesForDive('d1'), isEmpty);
  });

  test('a buddy signature is written as one', () async {
    final session = await started();
    addCapturedSignature(session, fromAna());
    await session.runHeldWrites();

    final buddySignatures = await service.getBuddySignaturesForDive('d1');
    expect(buddySignatures.single.signerId, 'b1');
    expect(buddySignatures.single.signedAt, epoch);
  });

  test('a buddy removed after signing: the signature is not written', () async {
    final session = await started();
    addCapturedSignature(session, fromAna());
    diveBuddiesList.set(session, const []);
    dropSignaturesOfRemovedBuddies(session);

    expect(diveSignaturesList.isChanged(session), isFalse);
    await session.runHeldWrites();
    expect(await service.getBuddySignaturesForDive('d1'), isEmpty);
  });

  // Code review (#4527): a signature sync moved to another dive while the
  // sitting was open is that dive's now.
  test('a signature sync moved to another dive before Save is not deleted '
      'by a Save that removed it', () async {
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d2', 0, 0, 0)",
    );
    await service.saveSignature(
      diveId: 'd1',
      imageBytes: png,
      signerName: 'Ines',
    );
    final session = await started();
    final stored = diveSignaturesList.current(session)!.single;
    removeSignature(session, stored.id);
    await db.customStatement("UPDATE media SET dive_id = 'd2' WHERE id = ?", [
      stored.id,
    ]);

    await session.runHeldWrites();
    expect((await service.getAllSignaturesForDive('d2')).map((s) => s.id), [
      stored.id,
    ]);
  });
}
