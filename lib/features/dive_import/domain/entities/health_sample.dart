/// One numeric reading from Apple Health (heart rate in bpm, heart rate
/// variability in ms), at a true UTC instant (issue #637).
class HealthSample {
  const HealthSample({required this.at, required this.value});

  final DateTime at;
  final double value;
}

/// A stretch Apple Health records as asleep, in true UTC instants.
class SleepInterval {
  const SleepInterval({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}
