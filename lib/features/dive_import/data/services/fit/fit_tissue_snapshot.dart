import 'package:submersion/features/dive_import/data/services/fit/fit_summary_extractor.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';

/// The computer-reported tissue state a Garmin `dive_summary` carries:
/// aggregate N2 loading (percent) at dive start and end. The CNS readings
/// beside it and the configured deco model are the dive's own columns
/// (`cnsStart`, `cnsEnd`, `decoModel` on the parsed dive, issue #2555).
///
/// Null when the summary has no N2 loading on either side, so dives from
/// devices that do not record it keep `computerTissue` unset. A side whose
/// N2 value is missing is left null.
ComputerTissueSnapshot? fitTissueSnapshot(FitSummary summary) {
  final startN2 = summary.startN2;
  final endN2 = summary.endN2;
  if (startN2 == null && endN2 == null) return null;

  return ComputerTissueSnapshot(
    start: startN2 == null
        ? null
        : ComputerTissueState(n2LoadPercent: startN2.toDouble()),
    end: endN2 == null
        ? null
        : ComputerTissueState(n2LoadPercent: endN2.toDouble()),
  );
}
