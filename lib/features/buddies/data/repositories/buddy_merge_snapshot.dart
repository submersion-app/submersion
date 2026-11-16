import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/features/media/data/repositories/media_people_buddy_merge.dart';

/// Snapshot of a DiveBuddies junction row for undo.
class DiveBuddySnapshot {
  final String id;
  final String diveId;
  final String buddyId;
  final String role;
  final int createdAt;

  const DiveBuddySnapshot({
    required this.id,
    required this.diveId,
    required this.buddyId,
    required this.role,
    required this.createdAt,
  });
}

/// Snapshot of a certification's instructor link for undo.
class CertificationInstructorSnapshot {
  final String certificationId;
  final String instructorId;

  const CertificationInstructorSnapshot({
    required this.certificationId,
    required this.instructorId,
  });
}

/// Snapshot of a certification's buddy owner for undo (issue #553).
class CertificationOwnerSnapshot {
  final String certificationId;
  final String previousBuddyId;

  const CertificationOwnerSnapshot({
    required this.certificationId,
    required this.previousBuddyId,
  });
}

/// Snapshot captured before a buddy merge for undo.
class BuddyMergeSnapshot {
  final domain.Buddy originalSurvivor;
  final List<domain.Buddy> deletedBuddies;
  final List<DiveBuddySnapshot> deletedDiveBuddyEntries;
  final List<DiveBuddySnapshot> modifiedDiveBuddyEntries;
  final List<CertificationInstructorSnapshot> repointedCertifications;
  final List<CertificationOwnerSnapshot> repointedOwnerCerts;

  /// The merged buddies' role rows before the merge, and every dive they
  /// were linked to, so an undo can put the role sets back (issue #1221).
  final List<DiveBuddyRole> roleRows;
  final List<String> roleDiveIds;

  const BuddyMergeSnapshot({
    required this.originalSurvivor,
    required this.deletedBuddies,
    required this.deletedDiveBuddyEntries,
    required this.modifiedDiveBuddyEntries,
    this.repointedCertifications = const [],
    this.repointedOwnerCerts = const [],
    this.roleRows = const [],
    this.roleDiveIds = const [],
    this.documentOriginalBuddyIds = const {},
    this.mediaPeople = const MediaPeopleMergeSnapshot(),
    this.placeOriginalBuddyIds = const {},
  });

  /// Document id -> the buddy it was filed under before the merge
  /// (issue #2613).
  final Map<String, String> documentOriginalBuddyIds;

  /// The duplicates' people tags moved to the survivor (issue #1745).
  final MediaPeopleMergeSnapshot mediaPeople;

  /// Gear place id -> the buddy it stood for before the merge (issue #3790).
  final Map<String, String> placeOriginalBuddyIds;
}

/// Result from a buddy merge operation.
class BuddyMergeResult {
  final String survivorId;
  final BuddyMergeSnapshot? snapshot;

  const BuddyMergeResult({required this.survivorId, this.snapshot});
}
