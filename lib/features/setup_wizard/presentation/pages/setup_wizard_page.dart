import 'package:flutter/material.dart';

import 'package:submersion/core/presentation/widgets/ocean_background.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/setup_wizard/domain/setup_wizard_models.dart';
import 'package:submersion/features/setup_wizard/presentation/providers/setup_wizard_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/placeholder_step.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/profile_step.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/welcome_fork_step.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_indicator.dart';

/// Multi-step setup wizard for new databases (first run) and Settings
/// re-entry. See docs/superpowers/specs/2026-07-10-setup-wizard-design.md.
class SetupWizardPage extends ConsumerStatefulWidget {
  final SetupWizardMode mode;

  const SetupWizardPage({super.key, required this.mode});

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

/// Steps that show the progress indicator and the shared Next/Back bar.
const _formZone = {
  SetupStepId.profile,
  SetupStepId.units,
  SetupStepId.appearance,
  SetupStepId.backupSync,
};

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  final _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _animateTo(int index) async {
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
      case SetupStepId.appearance:
        return l10n.setup_step_appearance;
      case SetupStepId.backupSync:
        return l10n.setup_step_backup;
      case SetupStepId.finish:
        return l10n.setup_step_finish;
      default:
        return '';
    }
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
          builder: (_) => WelcomeForkStep(
            onStartFresh: () =>
                _chooseAndAdvance(() => notifier.choosePath(SetupPath.fresh)),
            onExistingData: () => _chooseAndAdvance(
              () => notifier.choosePath(SetupPath.existingData),
            ),
            onSkipSetup: () => _chooseAndAdvance(notifier.requestSkip),
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
          builder: (_) => const PlaceholderStep(title: 'Units'),
        );
      case SetupStepId.appearance:
        return WizardStepDef(
          label: _stepLabel(id),
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: 'Appearance'),
        );
      case SetupStepId.backupSync:
        return WizardStepDef(
          label: _stepLabel(id),
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: 'Backups & Sync'),
        );
      case SetupStepId.finish:
        return WizardStepDef(
          label: _stepLabel(id),
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: "You're all set"),
        );
      case SetupStepId.existingChoice:
        return WizardStepDef(
          label: '',
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: 'Bring your data'),
        );
      case SetupStepId.restore:
        return WizardStepDef(
          label: '',
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: 'Restore backup'),
        );
      case SetupStepId.syncConnect:
        return WizardStepDef(
          label: '',
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: 'Connect and pull'),
        );
      case SetupStepId.openFolder:
        return WizardStepDef(
          label: '',
          hideBottomBar: true,
          canAdvance: setupWizardProvider(mode).select((_) => true),
          builder: (_) => const PlaceholderStep(title: 'Open existing folder'),
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
    final steps = computeSteps(draft);
    if (_currentIndex >= steps.length) {
      _currentIndex = steps.length - 1;
    }
    final defs = steps.map(_defFor).toList();
    final currentId = steps[_currentIndex];
    final inFormZone = _formZone.contains(currentId);

    // Indicator covers the contiguous labelled tail of the flow (profile or
    // units onward, plus finish); choice steps stay indicator-free.
    final labelledIds = steps
        .where((s) => _formZone.contains(s) || s == SetupStepId.finish)
        .toList();
    final labelledIndex = labelledIds.indexOf(currentId);

    return Scaffold(
      body: OceanBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox.expand(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        if (labelledIndex >= 0)
                          WizardStepIndicator(
                            labels: labelledIds.map(_stepLabel).toList(),
                            currentStep: labelledIndex,
                          ),
                        // Keyed so the PageView survives the indicator and
                        // bottom bar toggling in and out of the Column (a
                        // slot shift would otherwise remount it at page 0).
                        Expanded(
                          key: const ValueKey('setup_wizard_pages'),
                          child: PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              for (final def in defs)
                                Builder(builder: def.builder),
                            ],
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
            const Spacer(),
            if (_currentIndex < _stepCount() - 1 &&
                _skippable(_currentStepId()))
              TextButton(
                onPressed: _advance,
                child: Text(l10n.setup_common_skip),
              ),
            const SizedBox(width: 8),
            _NextButton(def: def, onNext: _advance),
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
