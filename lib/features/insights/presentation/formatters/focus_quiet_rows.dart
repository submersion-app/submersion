import 'package:submersion/features/insights/domain/focus/focus_factor.dart';

/// A categorical top value whose share gap is under this says nothing.
const double focusQuietSharePoints = 0.05;

/// Whether a comparison row says nothing worth a diver's glance: not a
/// standout, and either unrecorded, a numeric difference that rounds to
/// zero in the diver's display units ([formattedDifference], as the table
/// renders it), or a category lead under [focusQuietSharePoints].
bool focusFactorIsQuiet(
  FocusFactor factor, {
  required String? formattedDifference,
}) {
  if (factor.standsOut) return false;
  return switch (factor) {
    NumericFactor(:final groupMean, :final baselineMean) =>
      groupMean == null ||
          baselineMean == null ||
          formattedDifference == null ||
          !formattedDifference.contains(RegExp('[1-9]')),
    CategoricalFactor(:final top) =>
      top.isEmpty ||
          (top.first.groupShare - top.first.baselineShare).abs() <
              focusQuietSharePoints,
  };
}
