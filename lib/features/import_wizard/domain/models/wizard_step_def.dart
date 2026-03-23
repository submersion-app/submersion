import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// Defines a single step in the unified import wizard.
///
/// Each step declares:
/// - The [label] shown in the step indicator.
/// - An optional [icon] shown alongside the label.
/// - A [builder] that produces the step's widget.
/// - A [canAdvance] provider that the wizard reads to decide whether the
///   "Next" button should be enabled.
/// - An [autoAdvance] flag that causes the wizard to move to the next step
///   automatically as soon as [canAdvance] becomes true.
class WizardStepDef {
  /// Short label displayed in the wizard step indicator.
  final String label;

  /// Optional icon shown in the step indicator alongside [label].
  final IconData? icon;

  /// Builds the content widget for this step.
  final Widget Function(BuildContext) builder;

  /// A Riverpod provider that resolves to true when the user may advance past
  /// this step.
  final ProviderListenable<bool> canAdvance;

  /// When true, the wizard automatically advances to the next step as soon as
  /// [canAdvance] emits true.
  final bool autoAdvance;

  const WizardStepDef({
    required this.label,
    this.icon,
    required this.builder,
    required this.canAdvance,
    this.autoAdvance = false,
  });
}
