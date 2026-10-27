import 'package:flutter/material.dart';

import 'package:submersion/core/presentation/startup_brightness.dart';
import 'package:submersion/core/presentation/widgets/ocean_background.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_flow_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_account_step.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_backups_step.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_photos_step.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_sync_step.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/existing_choice_step.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/finish_step.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/open_folder_step.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/restore_step.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/profile_step.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/units_step.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/welcome_fork_step.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/wizard_surface_style.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_indicator.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_enter_dialog.dart';
import 'package:submersion/features/setup_wizard/domain/unit_preset_detector.dart';

/// Multi-step setup wizard for new databases (first run) and Settings
/// re-entry. See docs/design/specs/2026-07-10-setup-wizard-design.md.
class SetupWizardPage extends ConsumerStatefulWidget {
  final SetupWizardMode mode;

  /// Stands in for the shared Set up this device steps in tests.
  final Widget Function(SetUpStep step, SetUpStepNavigation navigation)?
  setUpStepBody;

  const SetupWizardPage({
    super.key,
    required this.mode,
    @visibleForTesting this.setUpStepBody,
  });

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

/// Steps that show the shared Next/Back bar. The Set up this device steps
/// keep their own buttons (spec 6.6).
const _barZone = {SetupStepId.profile, SetupStepId.units};

/// Steps that show the progress indicator, with Finish.
const _indicatorZone = {..._barZone, ...kSetUpWizardSteps};

/// The indicator dot a step lights: the four Set up this device steps share
/// one, "Data", so the row fits a phone.
SetupStepId _indicatorDot(SetupStepId id) =>
    kSetUpWizardSteps.contains(id) ? SetupStepId.setUpAccount : id;

/// The shared step each wizard step id runs.
const _setUpSteps = {
  SetupStepId.setUpAccount: SetUpStep.account,
  SetupStepId.setUpSync: SetUpStep.sync,
  SetupStepId.setUpBackups: SetUpStep.backups,
  SetupStepId.setUpPhotos: SetUpStep.photos,
};

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  int _currentIndex = 0;

  void _animateTo(int index) {
    if (mounted) setState(() => _currentIndex = index);
  }

  void _advance() {
    final steps = computeSteps(ref.read(setupWizardProvider(widget.mode)));
    if (_currentIndex < steps.length - 1) {
      _animateTo(_currentIndex + 1);
    }
  }

  void _back() {
    if (_currentIndex > 0) _animateTo(_currentIndex - 1);
  }

  /// Moves to [id] once the rebuild that changes the step list has run.
  void _goToAfterRebuild(SetupStepId id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = computeSteps(
        ref.read(setupWizardProvider(widget.mode)),
      ).indexOf(id);
      if (index >= 0) _animateTo(index);
    });
  }

  void _goTo(SetupStepId id) {
    final index = computeSteps(
      ref.read(setupWizardProvider(widget.mode)),
    ).indexOf(id);
    if (index >= 0) _animateTo(index);
  }

  /// How a shared step leaves itself in the wizard: Not now moves on (step
  /// 1's skips step 2, which has nothing to sync without an account), and on
  /// the existing-data path an empty account starts a new logbook instead.
  SetUpStepNavigation _navigationFor(SetupStepId id) {
    final notifier = ref.read(setupWizardProvider(widget.mode).notifier);
    final existingData =
        ref.read(setupWizardProvider(widget.mode)).path ==
        SetupPath.existingData;
    return SetUpStepNavigation(
      host: widget.mode == SetupWizardMode.firstRun
          ? SetUpHost.firstRun
          : SetUpHost.assistant,
      onNext: _advance,
      onBack: _back,
      onNotNow: id == SetupStepId.setUpAccount
          ? () => _goTo(SetupStepId.setUpBackups)
          : _advance,
      onSkip: id == SetupStepId.setUpPhotos ? _advance : null,
      onNoLibrary: existingData && id == SetupStepId.setUpSync
          ? () {
              notifier.choosePath(SetupPath.fresh);
              _goToAfterRebuild(SetupStepId.profile);
            }
          : null,
    );
  }

  Widget _setUpStep(SetUpStep step, SetUpStepNavigation navigation) =>
      switch (step) {
        SetUpStep.account => SetUpAccountStep(navigation: navigation),
        SetUpStep.sync => SetUpSyncStep(navigation: navigation),
        SetUpStep.backups => SetUpBackupsStep(navigation: navigation),
        SetUpStep.photos => SetUpPhotosStep(navigation: navigation),
      };

  /// Choice steps mutate the draft (growing the step list), then advance
  /// after the rebuild that adds the next page.
  void _chooseAndAdvance(void Function() mutate) {
    mutate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _advance();
    });
  }

  String _stepLabel(SetupStepId id) {
    final l10n = context.l10n;
    switch (id) {
      case SetupStepId.profile:
        return l10n.setup_step_profile;
      case SetupStepId.units:
        return l10n.setup_step_units;
      // The dot the four Set up this device steps share.
      case SetupStepId.setUpAccount ||
          SetupStepId.setUpSync ||
          SetupStepId.setUpBackups ||
          SetupStepId.setUpPhotos:
        return l10n.settings_section_data_title;
      case SetupStepId.finish:
        return l10n.setup_step_finish;
      default:
        return '';
    }
  }

  /// Demo mode from the first-run welcome screen (issue #3708), offered only
  /// when a sample logbook this app can open is reachable. It leaves the
  /// wizard rather than adding a step: entering restarts the app.
  VoidCallback? _tryDemo(SetupWizardMode mode, DemoPackage? package) {
    if (mode != SetupWizardMode.firstRun || package == null) return null;
    return () => askAndEnterDemo(
      context,
      fromFirstRun: true,
      package: package,
      units: demoUnitsForPreset(
        presetForLocale(WidgetsBinding.instance.platformDispatcher.locale),
      ),
    );
  }

  WizardStepDef _defFor(SetupStepId id) {
    final mode = widget.mode;
    final notifier = ref.read(setupWizardProvider(mode).notifier);
    switch (id) {
      case SetupStepId.welcomeFork:
        return WizardStepDef(
          label: '',
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => Consumer(
            builder: (context, ref, _) => WelcomeForkStep(
              onStartFresh: () =>
                  _chooseAndAdvance(() => notifier.choosePath(SetupPath.fresh)),
              onExistingData: () => _chooseAndAdvance(
                () => notifier.choosePath(SetupPath.existingData),
              ),
              onSkipSetup: () => _chooseAndAdvance(notifier.requestSkip),
              onTryDemo: _tryDemo(
                mode,
                ref.watch(demoAvailabilityProvider).value,
              ),
            ),
          ),
        );
      case SetupStepId.profile:
        return WizardStepDef(
          label: _stepLabel(id),
          canAdvance: setupWizardProvider(
            mode,
          ).select((d) => d.name.trim().isNotEmpty),
          builder: (_) => ProfileStep(mode: mode),
        );
      case SetupStepId.units:
        return WizardStepDef(
          label: _stepLabel(id),
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => UnitsStep(mode: mode),
        );
      case SetupStepId.setUpAccount ||
          SetupStepId.setUpSync ||
          SetupStepId.setUpBackups ||
          SetupStepId.setUpPhotos:
        final step = _setUpSteps[id]!;
        return WizardStepDef(
          label: _stepLabel(id),
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) =>
              (widget.setUpStepBody ?? _setUpStep)(step, _navigationFor(id)),
        );
      case SetupStepId.finish:
        return WizardStepDef(
          label: _stepLabel(id),
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => FinishStep(
            mode: mode,
            onNeedsName: () {
              notifier.requireProfile();
              _goToAfterRebuild(SetupStepId.profile);
            },
          ),
        );
      case SetupStepId.existingChoice:
        return WizardStepDef(
          label: '',
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => ExistingChoiceStep(
            mode: mode,
            onChosen: () => _chooseAndAdvance(() {}),
          ),
        );
      case SetupStepId.restore:
        return WizardStepDef(
          label: '',
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const RestoreStep(),
        );
      case SetupStepId.openFolder:
        return WizardStepDef(
          label: '',
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const OpenFolderStep(),
        );
    }
  }

  SetupStepId _currentStepId() {
    final steps = computeSteps(ref.read(setupWizardProvider(widget.mode)));
    return steps[_currentIndex.clamp(0, steps.length - 1)];
  }

  int _stepCount() {
    return computeSteps(ref.read(setupWizardProvider(widget.mode))).length;
  }

  bool _skippable(SetupStepId id) => id != SetupStepId.profile;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(setupWizardProvider(widget.mode));
    // The account chosen in step 1 outlives the pages between it and the
    // steps that read it (the fall back to Profile and Units).
    ref.watch(setUpFlowProvider);
    final theme = Theme.of(context);
    final steps = computeSteps(draft);
    if (_currentIndex >= steps.length) {
      // The step list shrank under us (e.g. the adopt pivot from the fresh
      // path to the shorter existing-data path). Clamp to the last page.
      _currentIndex = steps.length - 1;
    }
    final defs = steps.map(_defFor).toList();
    final currentId = steps[_currentIndex];
    final inFormZone = _barZone.contains(currentId);

    // Indicator covers the contiguous labelled tail of the flow (profile or
    // units onward, plus finish); choice steps stay indicator-free.
    final labelledIds = steps
        .where((s) => _indicatorZone.contains(s) || s == SetupStepId.finish)
        .map(_indicatorDot)
        .toSet()
        .toList();
    final labelledIndex = labelledIds.indexOf(_indicatorDot(currentId));

    final oceanBrightness = resolveStartupBrightness(
      ref.watch(sharedPreferencesProvider),
      MediaQuery.platformBrightnessOf(context),
    );

    return Scaffold(
      body: OceanBackground(
        // Resolve brightness the same way the startup splash does, so the
        // background does not visibly shift when the splash dissolves into
        // the wizard.
        brightness: oceanBrightness,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  key: const ValueKey('setup_wizard_card'),
                  color: WizardSurfaceStyle.panel(theme),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (labelledIndex >= 0)
                        WizardStepIndicator(
                          labels: labelledIds.map(_stepLabel).toList(),
                          currentStep: labelledIndex,
                        )
                      // Choice/existing-data steps have no bottom bar, so a
                      // slim top back bar keeps every step past the fork
                      // reversible.
                      else if (_currentIndex > 0)
                        _buildBackBar(),
                      // Keyed so the switcher survives the indicator and bottom
                      // bar toggling in and out of the Column (a slot shift
                      // would otherwise remount it and restart the transition).
                      // Flexible (loose) inside a min-height Column lets the
                      // card hug the current step's content and only scroll
                      // when a step is taller than the available space.
                      Flexible(
                        key: const ValueKey('setup_wizard_pages'),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          alignment: Alignment.topCenter,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            switchInCurve: Curves.easeInOut,
                            switchOutCurve: Curves.easeInOut,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.03),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            layoutBuilder: (currentChild, previousChildren) =>
                                Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                ),
                            child: KeyedSubtree(
                              key: ValueKey(_currentIndex),
                              child: Builder(
                                builder: defs[_currentIndex].builder,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (inFormZone) _buildBottomBar(defs[_currentIndex]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackBar() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: context.l10n.setup_common_back,
          onPressed: _back,
        ),
      ),
    );
  }

  Widget _buildBottomBar(WizardStepDef def) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (_currentIndex > 0)
              OutlinedButton(
                onPressed: _back,
                child: Text(l10n.setup_common_back),
              ),
            const SizedBox(width: 8),
            // On a narrow phone Skip and Next stack rather than overflow.
            Expanded(
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  if (_currentIndex < _stepCount() - 1 &&
                      _skippable(_currentStepId()))
                    TextButton(
                      onPressed: _advance,
                      child: Text(l10n.setup_common_skip),
                    ),
                  _NextButton(def: def, onNext: _advance),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextButton extends ConsumerWidget {
  final WizardStepDef def;
  final VoidCallback onNext;

  const _NextButton({required this.def, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAdvance = ref.watch(def.canAdvance);
    return FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
      onPressed: canAdvance ? onNext : null,
      child: Text(context.l10n.setup_common_next),
    );
  }
}
