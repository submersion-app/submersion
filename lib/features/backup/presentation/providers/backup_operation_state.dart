import 'package:submersion/features/backup/domain/entities/backup_record.dart';

/// Status of a backup operation
enum BackupOperationStatus { idle, inProgress, success, restoreComplete, error }

/// Progress of the whole-library safety review sweep that runs at the end of a
/// restore. Structured rather than a pre-formatted string so the restore
/// barrier can render it in the user's language.
class SafetyReviewSweepProgress {
  final int done;
  final int total;

  const SafetyReviewSweepProgress({required this.done, required this.total});
}

/// State for backup/restore operations
class BackupOperationState {
  final BackupOperationStatus status;
  final String? message;
  final BackupRecord? lastRecord;

  /// True only while a database *restore* is running (a subset of the
  /// [BackupOperationStatus.inProgress] states). Restore briefly closes and
  /// reopens the database, so the whole app must be blocked from interaction
  /// until it finishes. Routine backups/exports/deletes, which also use
  /// `inProgress`, must NOT block the app. The global restore barrier keys off
  /// this flag, not `status`.
  final bool isRestoring;

  /// Non-null only while the post-restore safety sweep is running.
  final SafetyReviewSweepProgress? sweepProgress;

  const BackupOperationState({
    this.status = BackupOperationStatus.idle,
    this.message,
    this.lastRecord,
    this.isRestoring = false,
    this.sweepProgress,
  });

  /// [clearSweepProgress] separates "leave the sweep progress alone" from
  /// "clear it". Omitting [sweepProgress] means unchanged, matching every other
  /// field, so an unrelated `copyWith` cannot silently blank an in-flight
  /// sweep; pass `clearSweepProgress: true` to actually null it out.
  BackupOperationState copyWith({
    BackupOperationStatus? status,
    String? message,
    BackupRecord? lastRecord,
    bool? isRestoring,
    SafetyReviewSweepProgress? sweepProgress,
    bool clearSweepProgress = false,
  }) {
    return BackupOperationState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastRecord: lastRecord ?? this.lastRecord,
      isRestoring: isRestoring ?? this.isRestoring,
      sweepProgress: clearSweepProgress
          ? null
          : (sweepProgress ?? this.sweepProgress),
    );
  }
}
