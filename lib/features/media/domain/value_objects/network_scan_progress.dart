import 'package:equatable/equatable.dart';

/// Phase of the user-triggered network media scan.
enum NetworkScanPhase {
  /// The scan has been kicked off; the row enumeration is still running.
  starting,

  /// HTTP requests are in flight.
  scanning,

  /// All rows processed; the dialog should display the final report.
  finished,
}

/// Streamed progress event from [NetworkScanService.scanAll].
///
/// The dialog watches the stream and rebuilds when any field changes.
class NetworkScanProgress extends Equatable {
  final NetworkScanPhase phase;
  final int total;
  final int done;
  final int available;
  final int unreachable;

  const NetworkScanProgress({
    required this.phase,
    required this.total,
    required this.done,
    required this.available,
    required this.unreachable,
  });

  factory NetworkScanProgress.starting({required int total}) =>
      NetworkScanProgress(
        phase: NetworkScanPhase.starting,
        total: total,
        done: 0,
        available: 0,
        unreachable: 0,
      );

  /// `done / total`, clamped to `[0, 1]`. Returns 0 when `total == 0`.
  double get fractionDone {
    if (total <= 0) return 0;
    return (done / total).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [phase, total, done, available, unreachable];
}

/// Final summary shown when the scan completes.
class NetworkScanReport extends Equatable {
  final int total;
  final int available;
  final int unreachable;

  /// Rows whose `url` was null (data integrity issue) — counted but skipped.
  final int skippedNoUrl;

  final int durationMs;

  const NetworkScanReport({
    required this.total,
    required this.available,
    required this.unreachable,
    required this.skippedNoUrl,
    required this.durationMs,
  });

  factory NetworkScanReport.fromProgress(
    NetworkScanProgress progress, {
    required int skippedNoUrl,
    required int durationMs,
  }) {
    return NetworkScanReport(
      total: progress.total,
      available: progress.available,
      unreachable: progress.unreachable,
      skippedNoUrl: skippedNoUrl,
      durationMs: durationMs,
    );
  }

  @override
  List<Object?> get props => [
    total,
    available,
    unreachable,
    skippedNoUrl,
    durationMs,
  ];
}
