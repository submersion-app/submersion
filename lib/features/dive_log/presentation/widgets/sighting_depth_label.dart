import 'dart:math' as math;

import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/services/species_profile_positions.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// How deep a species was seen, for its Marine life row (issue #5092):
/// `27 m`, or `16 to 18 m` from the shallowest to the deepest. Whole
/// display units, converted before rounding, so the chip stays short on a
/// phone; ends that round to the same value read as one depth.
String sightingDepthLabel(
  SpeciesProfilePositions positions,
  UnitFormatter units,
  AppLocalizations l10n,
) {
  final unit = units.settings.depthUnit;
  // A sensor that reads a little above the surface reads as 0.
  int whole(double meters) =>
      DepthUnit.meters.convert(math.max(meters, 0), unit).round();
  final shallow = whole(positions.minDepthMeters);
  final deep = whole(positions.maxDepthMeters);
  final deepest = units.formatDepthWhole(math.max(positions.maxDepthMeters, 0));
  if (shallow == deep) return deepest;
  return l10n.diveLog_detail_sightingDepthRange(
    NumberFormat('#,##0').format(shallow),
    deepest,
  );
}
