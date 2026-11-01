import 'dart:math';

import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

/// The helium left once [o2] is taken as written, or null when [he] already
/// fits. An export from before issue #4007 rounded each gas to a whole percent
/// on its own, so a 10.5/89.5 mix reads 11/90, a gas with negative nitrogen.
/// Oxygen stays put, the same way the export now resolves an overflow, which
/// also means oxygen alone over 100 has no helium to give. Binary noise on a
/// total of 100 is no overflow.
double? cappedHelium(double o2, double he) =>
    he <= 0 || 100 - o2 - he >= -1e-9 ? null : max(0.0, 100 - o2);

/// The warning for a row whose helium was reduced to [keptHe].
ImportWarning gasMixCappedWarning({
  required double o2,
  required double he,
  required double keptHe,
  required int sourceRow,
  required int itemIndex,
  required String field,
}) => ImportWarning(
  severity: ImportWarningSeverity.warning,
  code: ImportWarningCode.gasMixesCapped,
  message:
      'Row $sourceRow has O2 ${trimFixed(o2, 1)} % and He ${trimFixed(he, 1)} '
      '%, over 100 % together; He was reduced to ${trimFixed(keptHe, 1)} %',
  entityType: ImportEntityType.dives,
  itemIndex: itemIndex,
  field: field,
  sourceRow: sourceRow,
);
