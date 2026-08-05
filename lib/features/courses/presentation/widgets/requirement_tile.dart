import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/add_requirement_sheet.dart';

/// One requirement row: a checkbox for checklist items, a progress count
/// plus expandable credited-dive list for dive requirements. Unsatisfied
/// dive requirements offer suggestion chips (one tap credits the dive).
class RequirementTile extends ConsumerWidget {
  const RequirementTile({
    super.key,
    required this.progress,
    required this.suggestions,
  });

  final CourseRequirementProgress progress;
  final List<RequirementDiveSummary> suggestions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requirement = progress.requirement;
    if (requirement.kind == RequirementKind.checklist) {
      return CheckboxListTile(
        value: requirement.completedAt != null,
        onChanged: (checked) async {
          await ref
              .read(courseRequirementRepositoryProvider)
              .setChecklistComplete(requirement.id, checked ?? false);
        },
        title: Text(requirement.name),
        secondary: RequirementMenuButton(requirement: requirement),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      );
    }
    return _DiveRequirementTile(progress: progress, suggestions: suggestions);
  }
}

/// Edit/delete menu shared by both tile variants. Delete is immediate:
/// requirement rows are cheap to recreate, so no confirm dialog.
class RequirementMenuButton extends ConsumerWidget {
  const RequirementMenuButton({super.key, required this.requirement});

  final CourseRequirement requirement;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final draft = await showAddRequirementSheet(context, existing: requirement);
    if (draft == null) return;
    await ref
        .read(courseRequirementRepositoryProvider)
        .updateRequirement(
          requirement.copyWith(
            name: draft.name,
            kind: draft.kind,
            targetCount: draft.targetCount,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      iconSize: 18,
      onSelected: (action) async {
        switch (action) {
          case 'edit':
            await _edit(context, ref);
          case 'delete':
            await ref
                .read(courseRequirementRepositoryProvider)
                .deleteRequirement(requirement.id);
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
  });

  final CourseRequirementProgress progress;
  final List<RequirementDiveSummary> suggestions;

  String _diveLabel(RequirementDiveSummary dive) {
    final number = dive.diveNumber != null ? '#${dive.diveNumber}' : '';
    final date = DateFormat.MMMd().format(dive.dateTime);
    final site = dive.siteName;
    return [number, date, ?site].where((part) => part.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requirement = progress.requirement;
    final theme = Theme.of(context);
    final satisfied = progress.isSatisfied;

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
      trailing: RequirementMenuButton(requirement: requirement),
      dense: true,
      children: [
        for (final dive in progress.linkedDives)
          ListTile(
            dense: true,
            leading: const Icon(Icons.link, size: 18),
            title: Text(_diveLabel(dive)),
            trailing: IconButton(
              tooltip: context.l10n.courses_action_unlinkDive,
              icon: const Icon(Icons.link_off, size: 18),
              onPressed: () async {
                await ref
                    .read(courseRequirementRepositoryProvider)
                    .unlinkDive(
                      requirementId: requirement.id,
                      diveId: dive.diveId,
                    );
              },
            ),
          ),
        if (!satisfied && suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        label: Text(_diveLabel(dive)),
                        onPressed: () async {
                          await ref
                              .read(courseRequirementRepositoryProvider)
                              .linkDive(
                                requirementId: requirement.id,
                                diveId: dive.diveId,
                              );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
