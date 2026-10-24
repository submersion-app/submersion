import 'package:flutter/widgets.dart';

/// How a Set up this device step leaves itself (issue #3482). The step
/// widgets call these and never push or pop routes themselves, so the
/// Settings page and, later, the first-run wizard can each host them in
/// their own shell.
class SetUpStepNavigation {
  const SetUpStepNavigation({
    required this.onNext,
    required this.onBack,
    required this.onNotNow,
    this.onSkip,
  });

  /// The step is done: on to the next one, or the done view after the last.
  final VoidCallback onNext;

  /// The previous step; from the first, the flow closes.
  final VoidCallback onBack;

  /// Leaves the flow, changing nothing the step had not already written.
  final VoidCallback onNotNow;

  /// Settles the step without doing it; only the photo step has one.
  final VoidCallback? onSkip;
}
