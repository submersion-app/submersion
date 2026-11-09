import 'package:flutter/material.dart';

/// The one color ramp the deco views use for a percentage that grows toward
/// a limit at 100%: a compartment's loading against its M-value, or a
/// gradient factor. Green below 60%, amber from 60%, orange from 80%, red
/// from 100%.
///
/// Shared by the tissue bar chart, the compartment detail and the deco
/// calculator's panel, so changing a threshold or a color happens once.
Color loadingSeverityColor(double percent) {
  if (percent >= 100) return Colors.red;
  if (percent >= 80) return Colors.orange;
  if (percent >= 60) return Colors.amber;
  return Colors.green;
}
