import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// The dive's signatures, the instructor's and its buddies', edited on the
/// Signatures card.
///
/// A signature captured in the sitting is held with its image, under an id
/// no stored signature has, and written at Save; a loaded one missing then
/// is deleted. A signature cannot be changed, only captured or deleted.
final diveSignaturesList = SittingList<Dive, Signature>(
  key: 'signatures',
  cardId: DiveDetailSectionId.signatures.name,
  read: (dive) => SignatureStorageService().getAllSignaturesForDive(dive.id),
  write: (dive, loaded, current) async {
    final service = SignatureStorageService();
    final currentIds = {for (final s in current) s.id};
    final loadedIds = {for (final s in loaded) s.id};
    // Only ones still on this dive: a signature a sync moved to another
    // dive since the sitting read it is that dive's now (issue #4527).
    final onDive = {
      for (final s in await service.getAllSignaturesForDive(dive.id)) s.id,
    };
    for (final signature in loaded) {
      if (!currentIds.contains(signature.id) && onDive.contains(signature.id)) {
        await service.deleteSignature(signature.id);
      }
    }
    for (final signature in current) {
      if (loadedIds.contains(signature.id)) continue;
      final bytes = signature.imageData;
      if (bytes == null) continue;
      final buddyId = signature.signerId;
      if (signature.isBuddySignature && buddyId != null) {
        await service.saveBuddySignature(
          diveId: dive.id,
          imageBytes: bytes,
          buddyId: buddyId,
          buddyName: signature.signerName,
          role: signature.role ?? '',
          signedAt: signature.signedAt,
        );
      } else {
        await service.saveSignature(
          diveId: dive.id,
          imageBytes: bytes,
          signerName: signature.signerName,
          signerId: signature.signerId,
          signedAt: signature.signedAt,
        );
      }
    }
    // Whether it changed anything is not asked of a dive's rows.
    return null;
  },
  same: (a, b) =>
      setEquals({for (final s in a) s.id}, {for (final s in b) s.id}),
);

/// Adds [signature], just captured, to the sitting. A capture replaces the
/// one held before it for the same signer: the training signature, or the
/// same buddy's.
void addCapturedSignature(EditSession<Dive> session, Signature signature) {
  final current = diveSignaturesList.current(session);
  if (current == null) return;
  bool sameSigner(Signature s) => signature.isBuddySignature
      ? s.isBuddySignature && s.signerId == signature.signerId
      : s.isInstructorSignature;
  diveSignaturesList.set(session, [
    for (final s in current)
      if (!sameSigner(s)) s,
    signature,
  ]);
}

/// Deletes the signature [id] in the sitting; one captured in it is simply
/// dropped.
void removeSignature(EditSession<Dive> session, String id) {
  final current = diveSignaturesList.current(session);
  if (current == null) return;
  diveSignaturesList.set(session, [
    for (final s in current)
      if (s.id != id) s,
  ]);
}

/// Drops the signatures captured in this sitting for buddies the sitting no
/// longer has on the dive, so none is written for someone who was not
/// there. A stored signature stays, as removing a buddy has always left it.
/// Called whenever the Buddies card changes the buddies.
void dropSignaturesOfRemovedBuddies(EditSession<Dive> session) {
  final current = diveSignaturesList.current(session);
  final buddies = diveBuddiesList.current(session);
  if (current == null || buddies == null) return;
  final loadedIds = {
    for (final s in diveSignaturesList.loaded(session) ?? const <Signature>[])
      s.id,
  };
  final onDive = {for (final b in buddies) b.buddy.id};
  final kept = [
    for (final s in current)
      if (loadedIds.contains(s.id) ||
          !s.isBuddySignature ||
          onDive.contains(s.signerId))
        s,
  ];
  if (kept.length != current.length) diveSignaturesList.set(session, kept);
}
