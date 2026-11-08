import 'package:submersion/features/data_quality/domain/detectors/missing_gas_switches.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';

/// Gas switches the cylinder pressures show on an open-circuit dive that
/// logged none (issue #165): a diver who changes regulators without telling
/// the computer, or a computer that records no switches at all.
///
/// One finding per dive. Its `missingSwitches` can be written in one tap;
/// its `deepStarts` started deeper than their gas's MOD and are only named,
/// since a 50% bottle losing pressure at 40 m is worth seeing but is not a
/// switch to add on the diver's behalf. Dives that logged a switch are left
/// to the tank assignment detector's idle-tank check.
class MissingGasSwitchDetector extends QualityDetector {
  const MissingGasSwitchDetector();

  @override
  String get id => 'missing_gas_switch';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.tank;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final missed = missedGasSwitches(ctx);
    if (missed.addable.isEmpty && missed.deep.isEmpty) return const [];
    return [
      make(
        ctx,
        severity: QualitySeverity.warning,
        params: {
          'missingSwitches': [
            for (final m in missed.addable) missedSwitchParams(m),
          ],
          'deepStarts': [
            for (var i = 0; i < missed.deep.length; i++)
              missedSwitchParams(missed.deep[i], mod: missed.deepModMeters[i]),
          ],
        },
      ),
    ];
  }
}
