import 'package:submersion/core/utils/number_display.dart';

/// Label for one condition band: "<10", "10-20" or "30+", in the unit the
/// bands were defined in (issue #3118). A whole edge prints without decimals
/// and a fractional one keeps its single decimal, in the locale's separator.
/// The unit symbol is left to the caller, which puts it on the axis.
String conditionBandLabel({required double? lower, required double? upper}) {
  String edge(double value) => localiseDecimalText(
    value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1),
  );
  if (lower == null) return '<${edge(upper!)}';
  if (upper == null) return '${edge(lower)}+';
  return '${edge(lower)}-${edge(upper)}';
}
