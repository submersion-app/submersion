import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// A downloaded tank reports a transmitter serial the diver has not assigned
/// to a cylinder, so its size and role came from the default preset (issue
/// #1365). Informational: the repair is to register the transmitter.
class UnknownTransmitterDetector extends QualityDetector {
  const UnknownTransmitterDetector();

  @override
  String get id => 'unknown_transmitter';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.tank;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final out = <QualityFinding>[];
    final seen = <String>{};
    final ordered = [...ctx.tanks]..sort((a, b) => a.order.compareTo(b.order));
    for (final tank in ordered) {
      final serial = normalizeTransmitterSerial(tank.transmitterSerial);
      if (serial == null || ctx.knownTransmitterSerials.contains(serial)) {
        continue;
      }
      if (!seen.add(serial)) continue;
      out.add(
        make(
          ctx,
          discriminator: serial,
          severity: QualitySeverity.info,
          params: {'serial': serial, 'tankId': tank.id},
        ),
      );
    }
    return out;
  }
}
