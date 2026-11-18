import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/repairs/gas_mix_scale_rules.dart';

/// Flags each cylinder whose stored mix no gas can have: a share over 100%,
/// below 0%, or shares adding up to more than 100% (issue #4714). Earlier
/// UDDF (#4705) and MacDive (#1493) imports stored mixes 100 times too high,
/// such as 3200% O2, which every MOD, ppO2, CNS/OTU and deco figure for the
/// dive then reads.
///
/// One finding per cylinder. When dividing by 100 gives a breathable mix,
/// the finding carries it as `correctedO2Percent` / `correctedHePercent`
/// for the one-tap repair; otherwise the diver corrects the mix by hand.
/// Every dive mode and role: the stored value is wrong whatever breathed it.
class ImpossibleGasMixDetector extends QualityDetector {
  const ImpossibleGasMixDetector();

  @override
  String get id => 'impossible_gas_mix';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.gas;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final ordered = [...ctx.tanks]..sort((a, b) => a.order.compareTo(b.order));
    return [
      for (final (position, tank) in ordered.indexed)
        if (!tank.gasMix.isPossible)
          make(
            ctx,
            discriminator: 'tank:${tank.id}',
            severity: QualitySeverity.warning,
            params: {
              'tankId': tank.id,
              // The number the dive page shows, as the other cylinder
              // findings store it: a merge leaves gaps in the stored order.
              'tankPosition': position,
              'o2Percent': tank.gasMix.o2,
              'hePercent': tank.gasMix.he,
              if (hundredfoldCorrection(tank.gasMix) case final corrected?) ...{
                'correctedO2Percent': corrected.o2,
                'correctedHePercent': corrected.he,
              },
            },
          ),
    ];
  }
}
