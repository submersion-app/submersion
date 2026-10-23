import 'package:flutter/material.dart';

import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The card's name for [step].
String setUpStepName(AppLocalizations l10n, SetUpStep step) => switch (step) {
  SetUpStep.account => l10n.settings_setUpDevice_step_account,
  SetUpStep.sync => l10n.settings_setUpDevice_step_sync,
  SetUpStep.backups => l10n.settings_setUpDevice_step_backups,
  SetUpStep.photos => l10n.settings_setUpDevice_step_photos,
};

String _markLabel(AppLocalizations l10n, SetUpMark mark) => switch (mark) {
  SetUpMark.done => l10n.settings_setUpDevice_mark_done,
  SetUpMark.next => l10n.settings_setUpDevice_mark_next,
  SetUpMark.notYet => l10n.settings_setUpDevice_mark_notYet,
  SetUpMark.skipped => l10n.settings_setUpDevice_mark_skipped,
};

/// The four steps, one line each with its mark.
class SetUpStepMarks extends StatelessWidget {
  const SetUpStepMarks({super.key, required this.marks});

  final Map<SetUpStep, SetUpMark> marks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in SetUpStep.values)
          _StepLine(
            name: setUpStepName(l10n, step),
            mark: marks[step]!,
            semanticsLabel: l10n.settings_setUpDevice_stepSemantics(
              setUpStepName(l10n, step),
              _markLabel(l10n, marks[step]!),
            ),
            scheme: scheme,
          ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({
    required this.name,
    required this.mark,
    required this.semanticsLabel,
    required this.scheme,
  });

  final String name;
  final SetUpMark mark;
  final String semanticsLabel;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (mark) {
      SetUpMark.done => (Icons.check_circle, scheme.primary),
      SetUpMark.next => (Icons.radio_button_checked, scheme.primary),
      SetUpMark.notYet => (Icons.radio_button_unchecked, scheme.outline),
      SetUpMark.skipped => (Icons.remove_circle_outline, scheme.outline),
    };
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    return MergeSemantics(
      child: Semantics(
        label: semanticsLabel,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: mark == SetUpMark.next
                      ? textStyle?.copyWith(fontWeight: FontWeight.w600)
                      : textStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
