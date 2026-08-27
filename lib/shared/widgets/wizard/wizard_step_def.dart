import 'package:flutter/foundation.dart' show AsyncCallback;
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
/// - An optional [onBeforeAdvance] callback that the wizard invokes just
///   before transitioning to the next step (e.g. to persist pending state).
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
  /// [canAutoAdvance] (or [canAdvance] if [canAutoAdvance] is null) emits true.
  final bool autoAdvance;

  /// When non-null, used instead of [canAdvance] for auto-advance decisions.
  /// This allows auto-advance to require stricter conditions than the Next
  /// button (e.g., auto-advance only for preset-detected CSVs while still
  /// enabling Next for manual mapping).
  final ProviderListenable<bool>? canAutoAdvance;

  /// Optional callback invoked by the wizard just before advancing past this
  /// step. Adapters use this to commit pending user choices (e.g. confirming
  /// a source selection or finalising a field mapping) so the wizard itself
  /// stays generic. May be async — the wizard awaits its completion before
  /// proceeding.
  final AsyncCallback? onBeforeAdvance;

  /// When true, the wizard hides the standard bottom bar (Back/Next) for this
  /// step. The step widget is responsible for its own navigation controls.
  final bool hideBottomBar;

  const WizardStepDef({
    required this.label,
    this.icon,
    required this.builder,
    required this.canAdvance,
    this.autoAdvance = false,
    this.canAutoAdvance,
    this.onBeforeAdvance,
    this.hideBottomBar = false,
  });
}
