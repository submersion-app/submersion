import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The default observed-at for a check-in on [dive]: the exit time when the
/// log has one, else the start plus the runtime, else the start.
DateTime defaultObservedAt(Dive dive) {
  final exit = dive.exitTime;
  if (exit != null) return exit;
  final runtime = dive.effectiveRuntime;
  if (runtime != null) return dive.dateTime.add(runtime);
  return dive.dateTime;
}
