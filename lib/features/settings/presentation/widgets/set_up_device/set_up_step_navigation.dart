import 'package:flutter/widgets.dart';

/// What runs the Set up this device steps (issue #3482, spec 6.6): the
/// Settings page, the first-run wizard, or Settings > Manage > Setup
/// assistant (the wizard's shell, re-entered).
enum SetUpHost {
  settingsPage,
  firstRun,
  assistant;

  /// Hosted by the wizard's shell, which has no page to return to: Not now
  /// moves on to the next step instead of closing the flow.
  bool get inWizard => this != settingsPage;
}

/// How a Set up this device step leaves itself (issue #3482). The step
/// widgets call these and never push or pop routes themselves, so the
/// Settings page and the first-run wizard can each host them in their own
/// shell.
class SetUpStepNavigation {
  const SetUpStepNavigation({
    required this.onNext,
    required this.onBack,
    required this.onNotNow,
    this.onSkip,
    this.onNoLibrary,
    this.host = SetUpHost.settingsPage,
  });

  /// The step is done: on to the next one, or the done view after the last.
  final VoidCallback onNext;

  /// The previous step; from the first, the flow closes.
  final VoidCallback onBack;

  /// Leaves the step without doing it, changing nothing it had not already
  /// written: on the Settings page the flow closes, in the wizard it moves
  /// on.
  final VoidCallback onNotNow;

  /// Settles the step without doing it; only the photo step has one.
  final VoidCallback? onSkip;

  /// The account holds no library, and the host would rather start a new
  /// logbook than upload one: the wizard's existing-data path falls back to
  /// its fresh path. Null keeps step 2's own "Turn on sync".
  final VoidCallback? onNoLibrary;

  final SetUpHost host;
}
