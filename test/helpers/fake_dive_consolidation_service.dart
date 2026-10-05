import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';

/// Records calls made to [DiveConsolidationService.apply] and
/// [DiveConsolidationService.undo] so tests can assert on the wiring contract
/// without touching a real database.
///
/// Shared by combine_dives_dialog_test.dart (which drives the success path
/// through the real dialog) and run_dive_consolidation_test.dart (which owns
/// the undo and apply-failure branches of `runDiveConsolidation`).
///
/// [outcomeSnapshot] is built from the `mergedDiveId` argument rather than
/// being a `const` literal on purpose: const instances are canonicalized, so
/// two fakes sharing a literal would share one object and an identity
/// assertion against it would silently weaken into a structural-equality
/// check.
class FakeDiveConsolidationService extends DiveConsolidationService {
  FakeDiveConsolidationService({
    String mergedDiveId = 'target-dive',
    this.applyError,
    this.undoError,
  }) : outcomeSnapshot = DiveMergeSnapshot(
         mergedDiveId: mergedDiveId,
         diveRows: const [],
         tankRows: const [],
         weightRows: const [],
         customFieldRows: const [],
         equipmentRows: const [],
         diveTypeRows: const [],
         tagRows: const [],
         buddyRows: const [],
         sightingRows: const [],
         eventRows: const [],
         gasSwitchRows: const [],
         dataSourceRows: const [],
         tideRows: const [],
         mediaDiveIds: const {},
       ),
       super(DiveRepository());

  /// When set, [apply] throws this instead of returning an outcome.
  final Object? applyError;

  /// When set, [undo] throws this instead of recording the snapshot.
  final Object? undoError;

  String? capturedTargetDiveId;
  List<String>? capturedSecondaryDiveIds;
  ConsolidationAlignment? capturedAlignment;

  /// The snapshot [undo] was last called with, or null if it never completed.
  DiveMergeSnapshot? undoneSnapshot;

  /// Incremented before [undoError] is thrown, so a test can tell "undo was
  /// attempted and failed" apart from "undo was never called".
  int undoCallCount = 0;

  /// The snapshot handed back inside [apply]'s outcome, exposed so tests can
  /// assert Undo is invoked with this exact instance.
  final DiveMergeSnapshot outcomeSnapshot;

  @override
  Future<DiveConsolidationOutcome> apply({
    required String targetDiveId,
    required List<String> secondaryDiveIds,
    ConsolidationAlignment? alignment,
  }) async {
    capturedTargetDiveId = targetDiveId;
    capturedSecondaryDiveIds = secondaryDiveIds;
    capturedAlignment = alignment;
    final error = applyError;
    if (error != null) throw error;
    return DiveConsolidationOutcome(
      targetDiveId: targetDiveId,
      snapshot: outcomeSnapshot,
    );
  }

  @override
  Future<void> undo(DiveMergeSnapshot snapshot) async {
    undoCallCount++;
    final error = undoError;
    if (error != null) throw error;
    undoneSnapshot = snapshot;
  }
}
