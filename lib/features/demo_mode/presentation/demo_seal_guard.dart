import 'package:flutter/material.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The UI side of demo mode's seal for a button, picker or share that would
/// bring something in or send something out (issue #3708).
///
/// Returns true when the action may go ahead. While demo mode is on it shows
/// a short "not available in demo mode" note and returns false, so the
/// control stays visible and explains itself. The engine refuses the same
/// work regardless; this is the explanation.
bool demoSealGuard(BuildContext context, DemoSealedFeature feature) {
  if (!DemoModeGate.instance.isActive) return true;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(context.l10n.demo_sealed_note)));
  return false;
}
