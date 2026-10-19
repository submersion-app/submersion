import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// A registry entry's linked transmitter gear item carries a different
/// serial than the one the entry matches on (issue #3367): a diver who
/// creates the transmitter as a gear item first (for battery/service
/// tracking) and links it afterward ends up with two serials that silently
/// drift apart. Informational: never auto-repaired, since either serial
/// could be the one the diver meant to keep.
class TransmitterGearSerialMismatchDetector extends QualityDetector {
  const TransmitterGearSerialMismatchDetector();

  @override
  String get id => 'transmitter_gear_serial_mismatch';

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
      if (serial == null ||
          !ctx.mismatchedTransmitterSerials.contains(serial)) {
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
