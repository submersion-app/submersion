import 'package:equatable/equatable.dart';

/// Where demo mode stands, persisted so a killed app resumes or finishes it.
///
/// - [entering]: the sample logbook is downloading or being unpacked; the
///   user's own database is still open. A relaunch in this phase discards the
///   partial download.
/// - [active]: the demo database is the open database and every sealed
///   feature refuses to run.
/// - [exiting]: the user chose to leave; a relaunch in this phase finishes the
///   exit before the user's logbook opens.
enum DemoPhase { entering, active, exiting }

/// The persisted state of demo mode, stored as `state.json` in the demo
/// directory. Its absence means demo mode is off.
class DemoState extends Equatable {
  const DemoState({
    required this.phase,
    required this.fromFirstRun,
    required this.enteredAt,
  });

  final DemoPhase phase;

  /// True when demo mode was entered from the first-run welcome screen, so
  /// exiting returns there rather than to an existing logbook.
  final bool fromFirstRun;

  final DateTime enteredAt;

  DemoState copyWith({DemoPhase? phase}) => DemoState(
    phase: phase ?? this.phase,
    fromFirstRun: fromFirstRun,
    enteredAt: enteredAt,
  );

  Map<String, Object?> toJson() => {
    'phase': phase.name,
    'fromFirstRun': fromFirstRun,
    'enteredAt': enteredAt.toUtc().toIso8601String(),
  };

  /// Throws [FormatException] when [json] is not a valid state.
  factory DemoState.fromJson(Map<String, Object?> json) {
    final phaseName = json['phase'];
    final phase = DemoPhase.values.where((p) => p.name == phaseName);
    final fromFirstRun = json['fromFirstRun'];
    final rawEnteredAt = json['enteredAt'];
    final enteredAt = rawEnteredAt is String
        ? DateTime.tryParse(rawEnteredAt)
        : null;
    if (phase.isEmpty || fromFirstRun is! bool || enteredAt == null) {
      throw FormatException('Invalid demo state: $json');
    }
    return DemoState(
      phase: phase.single,
      fromFirstRun: fromFirstRun,
      enteredAt: enteredAt,
    );
  }

  @override
  List<Object?> get props => [phase, fromFirstRun, enteredAt];
}
