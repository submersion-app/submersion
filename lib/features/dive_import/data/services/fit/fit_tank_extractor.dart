import 'package:fit_tool/fit_tool.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_constants.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_message_access.dart';

/// One air-integration tank, from a FIT `tank_summary` message.
class FitTank {
  const FitTank({
    required this.sensorId,
    required this.order,
    this.startPressureBar,
    this.endPressureBar,
    this.volumeUsedLiters,
    this.cylinderVolumeLiters,
  });

  final int sensorId;
  final int order;
  final double? startPressureBar;
  final double? endPressureBar;
  final double? volumeUsedLiters;

  /// Configured cylinder volume in liters, DERIVED from gas consumption (Garmin
  /// does not transmit size). Null when not reliably derivable, in which case
  /// the tank still imports with pressure/gas but no volume.
  final double? cylinderVolumeLiters;
}

/// A single tank-pressure reading, from a FIT `tank_update` message.
class FitTankPressureSample {
  const FitTankPressureSample({
    required this.sensorId,
    required this.timestampMs,
    required this.pressureBar,
  });

  final int sensorId;
  final int timestampMs; // Unix milliseconds (normalized from FIT epoch).
  final double pressureBar;
}

/// Result of tank extraction: the tanks and the raw pressure series. The
/// orchestrator merges [pressures] onto profile samples by timestamp.
class FitTankData {
  FitTankData(this.tanks, this.pressures);

  final List<FitTank> tanks;
  final List<FitTankPressureSample> pressures;

  /// The tank order (index) for a transmitter sensor id, or null if no tank
  /// summary declared that sensor.
  int? orderForSensor(int sensorId) {
    for (final t in tanks) {
      if (t.sensorId == sensorId) return t.order;
    }
    return null;
  }
}

/// Extracts air-integration tanks (`tank_summary`, msg 323) and the pressure
/// time-series (`tank_update`, msg 319). fit_tool has no named class for these,
/// so they are read off [GenericMessage] by field number and scaled manually.
class FitTankExtractor {
  const FitTankExtractor._();

  static FitTankData extract(List<Message> messages) {
    final summaries = FitMessageAccess.messagesWithGlobalId(
      messages,
      FitConstants.tankSummaryMsg,
    );
    final updates = FitMessageAccess.messagesWithGlobalId(
      messages,
      FitConstants.tankUpdateMsg,
    );

    // One tank per sensor, in first-seen order across the summaries.
    final orderBySensor = <int, int>{};
    final tanks = <FitTank>[];
    for (final m in summaries) {
      final sensor = FitMessageAccess.rawNum(m, FitConstants.tsSensor)?.toInt();
      // One tank per sensor; ignore repeated summaries for a sensor already seen.
      if (sensor == null || orderBySensor.containsKey(sensor)) continue;
      final order = orderBySensor.length;
      orderBySensor[sensor] = order;
      final startBar = _scaled(
        m,
        FitConstants.tsStartPressure,
        FitConstants.pressureScaleBar,
      );
      final endBar = _scaled(
        m,
        FitConstants.tsEndPressure,
        FitConstants.pressureScaleBar,
      );
      final usedLiters = _scaled(
        m,
        FitConstants.tsVolumeUsed,
        FitConstants.volumeScaleLiters,
      );
      tanks.add(
        FitTank(
          sensorId: sensor,
          order: order,
          startPressureBar: startBar,
          endPressureBar: endBar,
          volumeUsedLiters: usedLiters,
          cylinderVolumeLiters: _deriveCylinderVolumeLiters(
            startBar,
            endBar,
            usedLiters,
          ),
        ),
      );
    }

    final pressures = <FitTankPressureSample>[];
    for (final m in updates) {
      final sensor = FitMessageAccess.rawNum(m, FitConstants.tuSensor)?.toInt();
      final pressure = _scaled(
        m,
        FitConstants.tuPressure,
        FitConstants.pressureScaleBar,
      );
      final tsFitSec = FitMessageAccess.rawNum(
        m,
        FitConstants.tuTimestamp,
      )?.toInt();
      if (sensor == null || pressure == null || tsFitSec == null) continue;
      pressures.add(
        FitTankPressureSample(
          sensorId: sensor,
          timestampMs: (tsFitSec + FitConstants.fitEpochToUnixSeconds) * 1000,
          pressureBar: pressure,
        ),
      );
    }

    return FitTankData(tanks, pressures);
  }

  static double? _scaled(DataMessage m, int fieldId, double scale) {
    final raw = FitMessageAccess.rawNum(m, fieldId);
    return raw == null ? null : raw.toDouble() / scale;
  }

  /// Derives the configured cylinder volume (liters) by reversing Garmin's
  /// gas-consumption computation: `size = volumeUsed / (startBar - endBar)`.
  /// Returns null (no volume) when inputs are missing or the result is
  /// unreliable: see [FitConstants.minDeriveDropBar] /
  /// [FitConstants.maxPlausibleVolumeLiters]. Rounded to 0.1 L because the value
  /// is reconstructed, not measured.
  static double? _deriveCylinderVolumeLiters(
    double? startBar,
    double? endBar,
    double? usedLiters,
  ) {
    if (usedLiters == null || usedLiters <= 0) return null;
    if (startBar == null || endBar == null) return null;
    final drop = startBar - endBar;
    if (drop < FitConstants.minDeriveDropBar) return null;
    final size = usedLiters / drop;
    if (size <= 0 || size > FitConstants.maxPlausibleVolumeLiters) return null;
    return double.parse(size.toStringAsFixed(1));
  }
}
