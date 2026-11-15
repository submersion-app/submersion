import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

/// A whole number grouped in the active locale, then its unit symbol:
/// "6,380 m". Shared by the long-distance formats.
String wholeWithSymbol(int value, String symbol) =>
    '${NumberFormat('#,##0').format(value)} $symbol';

/// Long distances in whole display units (issue #4569), kept beside
/// [UnitFormatter] so the class itself does not grow further. Exported from
/// `unit_formatter.dart`, so every caller already has it.
extension UnitFormatterWhole on UnitFormatter {
  /// A long vertical distance given in metres, in whole display units with
  /// grouped digits: "6,380 m" or "20,932 ft". Converted before rounding,
  /// and grouped in the active locale like [UnitFormatter.formatAltitude].
  ///
  /// [roundUp] is for a distance still to go, which must never read 0 while
  /// any of it is left.
  String formatDepthWhole(double? meters, {bool roundUp = false}) {
    if (meters == null) return '--';
    final converted = DepthUnit.meters.convert(meters, settings.depthUnit);
    final whole = roundUp ? _ceilToGo(converted) : converted.round();
    return wholeWithSymbol(whole, settings.depthUnit.symbol);
  }
}

/// A distance still to go, rounded up to a whole unit. The epsilon keeps
/// float noise just above a whole number (581.0000000001) from adding one;
/// any positive distance still reads at least 1, however small.
int _ceilToGo(double value) {
  final whole = (value - 1e-9).ceil();
  return value > 0 && whole < 1 ? 1 : whole;
}
