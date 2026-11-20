import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/editing/course_requirements_sitting.dart';

/// One requirement row: a checkbox for checklist items, a progress count
/// plus expandable credited-dive list for dive requirements. Unsatisfied
/// dive requirements offer suggestion chips (one tap credits the dive) and
/// a picker that reaches every other dive.
///
/// What a tap does is [actions]'s, held in a course page's sitting (issue
/// #4527, phase 3). With none (the page is locked, or the card is closed) it
/// offers no action and shows the tick as it is.
class RequirementTile extends StatelessWidget {
  const RequirementTile({
    super.key,
    required this.progress,
    required this.suggestions,
    this.actions,
  });

  final CourseRequirementProgress progress;
  final List<RequirementDiveSummary> suggestions;

  /// Null where the tile offers no action.
  final RequirementActions? actions;

  @override
  Widget build(BuildContext context) {
    final requirement = progress.requirement;
    final actions = this.actions;
    if (requirement.kind == RequirementKind.checklist) {
      return CheckboxListTile(
        value: requirement.completedAt != null,
        onChanged: actions == null
            ? null
            : (checked) => logFailure(
                actions.tick(requirement, checked ?? false),
                RequirementTile,
                'tick the requirement',
              ),
        title: Text(requirement.name),
        secondary: actions == null
            ? null
            : RequirementMenuButton(requirement: requirement, actions: actions),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      );
    }
    return _DiveRequirementTile(
      progress: progress,
      suggestions: suggestions,
      actions: actions,
    );
  }
}

/// Edit/delete menu shared by both tile variants. Delete is immediate:
/// requirement rows are cheap to recreate, so no confirm dialog.
class RequirementMenuButton extends StatelessWidget {
  const RequirementMenuButton({
    super.key,
    required this.requirement,
    required this.actions,
  });

  final CourseRequirement requirement;
  final RequirementActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      iconSize: 18,
      onSelected: (action) async {
        switch (action) {
          case 'edit':
            await actions.edit(context, requirement);
          case 'delete':
            await actions.remove(requirement);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Text(l10n.courses_action_editRequirement),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(l10n.courses_action_deleteRequirement),
        ),
      ],
    );
  }
}

class _DiveRequirementTile extends ConsumerWidget {
  const _DiveRequirementTile({
    required this.progress,
    required this.suggestions,
    required this.actions,
  });

  final CourseRequirementProgress progress;
  final List<RequirementDiveSummary> suggestions;

  /// Null where the tile offers no action.
  final RequirementActions? actions;

  String _diveLabel(RequirementDiveSummary dive, UnitFormatter units) {
    final number = dive.diveNumber != null ? '#${dive.diveNumber}' : '';
    // Year included: a course can credit dives from any year of the logbook.
    final date = units.formatMonthDayWithYear(dive.dateTime);
    final site = dive.siteName;
    return [number, date, ?site].where((part) => part.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requirement = progress.requirement;
    final theme = Theme.of(context);
    final satisfied = progress.isSatisfied;
    final units = ref.watch(unitFormatterProvider);
    final actions = this.actions;

    return ExpansionTile(
      leading: satisfied
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : Icon(
              Icons.radio_button_unchecked,
              color: theme.colorScheme.outline,
            ),
      title: Text(requirement.name),
      subtitle: Text(
        context.l10n.courses_requirement_diveProgress(
          progress.creditCount,
          requirement.targetCount,
        ),
        style: theme.textTheme.bodySmall,
      ),
      trailing: actions == null
          ? null
          : RequirementMenuButton(requirement: requirement, actions: actions),
      dense: true,
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final dive in progress.linkedDives)
          ListTile(
            dense: true,
            leading: const Icon(Icons.link, size: 18),
            title: Text(_diveLabel(dive, units)),
            trailing: actions == null
                ? null
                : IconButton(
                    tooltip: context.l10n.courses_action_unlinkDive,
                    icon: const Icon(Icons.link_off, size: 18),
                    onPressed: () => logFailure(
                      actions.uncredit(requirement, dive.diveId),
                      _DiveRequirementTile,
                      'unlink the dive',
                    ),
                  ),
          ),
        if (!satisfied && actions != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (suggestions.isNotEmpty) ...[
                  Text(
                    context.l10n.courses_requirement_suggestions,
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final dive in suggestions)
                        ActionChip(
                          label: Text(_diveLabel(dive, units)),
                          onPressed: () => logFailure(
                            actions.credit(context, requirement, dive),
                            _DiveRequirementTile,
                            'credit the suggested dive',
                          ),
                        ),
                    ],
                  ),
                ],
                TextButton.icon(
                  icon: const Icon(Icons.search, size: 18),
                  label: Text(context.l10n.courses_action_chooseDive),
                  onPressed: () => logFailure(
                    actions.credit(context, requirement, null),
                    _DiveRequirementTile,
                    'credit the chosen dive',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
