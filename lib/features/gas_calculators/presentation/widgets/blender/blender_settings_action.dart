import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The gear that opens the Trimix Mixer's settings page, placed on the
/// surrounding chrome (the `AppBar`'s actions as a full page, or
/// `PlanningToolPane`'s actions in the split view) rather than inside
/// [GasBlenderCalculator]'s own scrollable body, so it sits level with the
/// page title instead of one field lower than it (issue #1876 follow-up).
class BlenderSettingsAction extends StatelessWidget {
  const BlenderSettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('blender-settings'),
      icon: const Icon(Icons.settings_outlined),
      tooltip: context.l10n.settings_section_trimixMixer_title,
      // Through the router, not Navigator.push: this widget sits inside the
      // app's ShellRoute, so an imperative route lands on the shell's own
      // navigator, under a bottom bar that can still change the location out
      // from under it. The archive icon and the Settings entry both reach
      // their pages this way (PR #1359 review).
      onPressed: () => context.push(kTrimixMixerSettingsRoute),
    );
  }
}
