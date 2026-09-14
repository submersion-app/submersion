import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';
import 'package:submersion/features/buddies/domain/services/legacy_conversion_planner.dart';
import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_candidate_picker_sheet.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_buddy_review_row.dart';
import 'package:submersion/features/buddies/presentation/widgets/legacy_name_dialog.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Reviews [plan] before anything is written (#1831). Returns the edited
/// plan on Link, or null when cancelled.
Future<ConversionPlan?> showLegacyBuddyReviewSheet(
  BuildContext context, {
  required ConversionPlan plan,
  required BuddyNameMatcher matcher,
}) => showModalBottomSheet<ConversionPlan>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => LegacyBuddyReviewSheet(plan: plan, matcher: matcher),
);

class LegacyBuddyReviewSheet extends ConsumerStatefulWidget {
  const LegacyBuddyReviewSheet({
    super.key,
    required this.plan,
    required this.matcher,
  });

  final ConversionPlan plan;
  final BuddyNameMatcher matcher;

  @override
  ConsumerState<LegacyBuddyReviewSheet> createState() =>
      _LegacyBuddyReviewSheetState();
}

class _LegacyBuddyReviewSheetState
    extends ConsumerState<LegacyBuddyReviewSheet> {
  late List<PlannedLink> _links = widget.plan.links;

  void _update(List<PlannedLink> links) =>
      setState(() => _links = collapseLinks(links));

  List<PlannedLink> _replaced(int index, PlannedLink link) => [
    for (var i = 0; i < _links.length; i++) i == index ? link : _links[i],
  ];

  PlannedLink _existing(MatchCandidate buddy, String roleId) => PlannedLink(
    target: ExistingBuddyTarget(buddyId: buddy.id, name: buddy.name),
    roleId: roleId,
  );

  Future<void> _editName(int index) async {
    final name = await showLegacyNameDialog(
      context,
      initial: _links[index].name,
    );
    if (name == null || legacyNameKey(name).isEmpty) return;
    _update(
      _replaced(index, planLink(name, _links[index].roleId, widget.matcher)),
    );
  }

  Future<void> _addName() async {
    final name = await showLegacyNameDialog(context);
    if (name == null || legacyNameKey(name).isEmpty) return;
    _update([..._links, planLink(name, DiveRole.buddyId, widget.matcher)]);
  }

  Future<void> _chooseExisting(int index) async {
    final picked = await showBuddyCandidatePicker(
      context,
      candidates: widget.matcher.candidates,
    );
    if (picked == null) return;
    _update(_replaced(index, _existing(picked, _links[index].roleId)));
  }

  void _useSuggestion(int index) {
    final suggestion = _links[index].suggestion;
    if (suggestion == null) return;
    _update(_replaced(index, _existing(suggestion, _links[index].roleId)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final roles = ref.watch(allDiveRolesProvider).value ?? const <DiveRole>[];
    final buddyText = widget.plan.buddyText?.trim() ?? '';
    final diveMasterText = widget.plan.diveMasterText?.trim() ?? '';
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.buddies_linkText_sheetTitle,
              style: theme.textTheme.titleLarge,
            ),
            if (buddyText.isNotEmpty)
              Text(l10n.buddies_linkText_sourceBuddy(buddyText), style: muted),
            if (diveMasterText.isNotEmpty)
              Text(
                l10n.buddies_linkText_sourceDiveMaster(diveMasterText),
                style: muted,
              ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _links.length,
                itemBuilder: (context, i) => LegacyBuddyReviewRow(
                  key: ValueKey(_links[i].identity),
                  link: _links[i],
                  roles: roles,
                  onRoleChanged: (roleId) =>
                      _update(_replaced(i, _links[i].copyWith(roleId: roleId))),
                  onUseSuggestion: () => _useSuggestion(i),
                  onEditName: () => _editName(i),
                  onChooseExisting: () => _chooseExisting(i),
                  onRemove: () => _update([
                    for (var j = 0; j < _links.length; j++)
                      if (j != i) _links[j],
                  ]),
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _addName,
                icon: const Icon(Icons.add),
                label: Text(l10n.buddies_linkText_addName),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_action_cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _links.isEmpty
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(widget.plan.copyWith(links: _links)),
                  child: Text(l10n.buddies_linkText_linkCount(_links.length)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
