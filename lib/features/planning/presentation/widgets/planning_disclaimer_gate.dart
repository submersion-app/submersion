import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart'
    show launchReportIssue;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Wraps every route under /planning (installed by a ShellRoute in
/// app_router.dart, so a deep link straight to a leaf tool is covered too)
/// so that each diver confirms the planning safety disclaimer once before
/// using any tool there (issue #3120). Non-dismissible: there is no way to
/// reach the tools without confirming.
///
/// The confirmation is stored per diver in
/// [AppSettings.hasAcceptedPlanningDisclaimer].
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
    // Read up front: the dialog sits on the root navigator and can outlive
    // this gate (a deep link replacing /planning while it is up), and a
    // disposed gate's ref throws, which would leave this non-dismissible
    // dialog on screen for good.
    final settings = ref.read(settingsProvider.notifier);
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
                Navigator.of(context).pop();
                settings.acceptPlanningDisclaimer();
              },
              child: Text(context.l10n.planning_disclaimer_dialog_confirm),
            ),
          ],
        ),
      ),
    );
  }
}
