import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart'
    show launchReportIssue;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Wraps the Planning hub and the Gas Calculators page so that each diver
/// confirms the planning safety disclaimer once before using any tool
/// underneath (issue #3120). Non-dismissible: there is no way to reach the
/// tools without confirming.
///
/// One flag covers both entry points: confirming from either one satisfies
/// the other, since they share [AppSettings.hasAcceptedPlanningDisclaimer].
class PlanningDisclaimerGate extends ConsumerStatefulWidget {
  const PlanningDisclaimerGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PlanningDisclaimerGate> createState() =>
      _PlanningDisclaimerGateState();
}

class _PlanningDisclaimerGateState
    extends ConsumerState<PlanningDisclaimerGate> {
  // Guards against showing the dialog a second time while one check is
  // already in flight or its dialog is already up. Not a one-shot latch:
  // cleared once that dialog resolves, so a later diver switch (the
  // switcher opens over this gate rather than replacing it, so this State
  // survives it) can still raise the dialog again for a diver who has not
  // confirmed it.
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _checkDisclaimer();
  }

  @override
  Widget build(BuildContext context) {
    // The diver switcher opens over Planning/Gas Calculators rather than
    // replacing them, so this State survives a switch; re-check whenever
    // the active diver changes instead of only once at mount.
    ref.listen(currentDiverIdProvider, (_, _) => _checkDisclaimer());
    return widget.child;
  }

  /// Waits for the active diver's settings to load before deciding: at
  /// startup, or right after a diver switch, [settingsProvider] briefly
  /// holds the previous or placeholder defaults
  /// (hasAcceptedPlanningDisclaimer: false), and showing the dialog on that
  /// would flash it for a diver who already confirmed it.
  Future<void> _checkDisclaimer() async {
    if (_checking) return;
    _checking = true;
    try {
      await ref.read(settingsProvider.notifier).settingsLoaded;
    } catch (_) {
      // Already logged by the notifier; proceed on whatever state holds.
    }
    if (!mounted) return;
    if (ref.read(settingsProvider).hasAcceptedPlanningDisclaimer) {
      _checking = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await _showDialog();
      _checking = false;
    });
  }

  Future<void> _showDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        // Non-dismissible: the system back gesture must not be a way around
        // confirming, same as tapping the barrier is not.
        canPop: false,
        child: AlertDialog(
          title: Text(context.l10n.planning_disclaimer_dialog_title),
          content: Text(context.l10n.planning_disclaimer_dialog_body),
          actions: [
            TextButton(
              onPressed: () => launchReportIssue(context),
              child: Text(context.l10n.settings_about_reportIssue),
            ),
            FilledButton(
              onPressed: () {
                ref.read(settingsProvider.notifier).acceptPlanningDisclaimer();
                Navigator.of(context).pop();
              },
              child: Text(context.l10n.planning_disclaimer_dialog_confirm),
            ),
          ],
        ),
      ),
    );
  }
}
