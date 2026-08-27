/// One pressure reading in a tank's time series, in seconds from dive start.
typedef TankPressurePoint = ({int timestamp, double pressure});

/// The pressure fields of one dive-computer sample.
///
/// [tankPressuresBar] is the complete record: libdivecomputer reports one
/// pressure per air-integrated transmitter, so a single sample can carry
/// several. [pressureBar]/[tankIndex] hold only the last of them, and are the
/// fallback for sources that never report more than one tank per sample (UDDF
/// and FIT imports, and native builds predating issue #1223).
typedef TankPressureSampleView = ({
  int timeSeconds,
  double? pressureBar,
  int? tankIndex,
  List<double?>? tankPressuresBar,
});

/// Splits per-sample transmitter readings into one time series per tank index.
///
/// Samples are read in order, so each series comes out in sample order. Tanks
/// that reported nothing at a sample are simply absent from that timestamp: a
/// transmitter that loses comms leaves a hole rather than a stale or zero
/// reading.
Map<int, List<TankPressurePoint>> groupPressuresByTank(
  Iterable<TankPressureSampleView> samples,
) {
  final byTank = <int, List<TankPressurePoint>>{};

  void add(int tankIndex, int timeSeconds, double pressure) {
    byTank.putIfAbsent(tankIndex, () => []).add((
      timestamp: timeSeconds,
      pressure: pressure,
    ));
  }

  for (final sample in samples) {
    final perTank = sample.tankPressuresBar;
    if (perTank != null) {
      // The per-tank list supersedes pressureBar, which is one of its entries.
      for (var index = 0; index < perTank.length; index++) {
        final pressure = perTank[index];
        if (pressure != null) add(index, sample.timeSeconds, pressure);
      }
      continue;
    }
    final pressure = sample.pressureBar;
    if (pressure != null) {
      add(sample.tankIndex ?? 0, sample.timeSeconds, pressure);
    }
  }

  return byTank;
}
