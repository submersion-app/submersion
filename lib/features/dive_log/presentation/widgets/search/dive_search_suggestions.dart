import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/explore/data/recent_query_repository.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/recent_query_providers.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/query/presentation/widgets/saved_query_chip_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const kDiveSearchSuggestionsKey = ValueKey('dive-search-suggestions');
const kDiveSearchManageSavedKey = ValueKey('dive-search-manage-saved');

/// What the empty search field offers (#2773, spec 4.1 state 2): saved
/// searches with a Manage link, recent searches (typed and asked, marked),
/// and syntax hints in the diver's units.
class DiveSearchSuggestions extends ConsumerWidget {
  const DiveSearchSuggestions({
    super.key,
    required this.onSaved,
    required this.onRecent,
    required this.onHint,
  });

  final ValueChanged<SavedQueryLoad> onSaved;
  final ValueChanged<RecentQuery> onRecent;
  final ValueChanged<String> onHint;

  static const _recentShown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final askEnabled = ref.watch(exploreEnabledProvider);
    final recents = [
      for (final r in ref.watch(recentQueriesProvider).value ?? const [])
        if (r.kind == RecentQueryKind.typed || askEnabled) r,
    ].take(_recentShown).toList();
    final metric = ref.watch(queryUnitPrefsProvider).depth == DepthUnit.meters;
    final buddy = ref.watch(allBuddiesProvider).value?.firstOrNull?.name;
    final hints = [
      'manta',
      '"blue hole"',
      metric ? 'depth > 30m' : 'depth > 100ft',
      if (buddy != null) 'buddy = "$buddy"',
    ];
    // Inside the field's tap region, like the jump rows: a desktop mouse
    // press elsewhere unfocuses the field before the tap lands.
    return TextFieldTapRegion(
      child: Padding(
        key: kDiveSearchSuggestionsKey,
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SavedQueryChipRow(
                    subject: QuerySubject.dives,
                    onApply: onSaved,
                  ),
                ),
                TextButton(
                  key: kDiveSearchManageSavedKey,
                  onPressed: () => context.push('/saved-queries'),
                  child: Text(l10n.diveLog_search_manageSaved),
                ),
              ],
            ),
            if (recents.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                l10n.diveLog_search_recentTitle,
                style: theme.textTheme.labelLarge,
              ),
              for (final r in recents)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Tooltip(
                    message: r.kind == RecentQueryKind.typed
                        ? l10n.diveLog_search_recentTyped
                        : l10n.diveLog_search_recentAsked,
                    child: Icon(
                      r.kind == RecentQueryKind.typed
                          ? Icons.history
                          : Icons.auto_awesome,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    r.sentence,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onRecent(r),
                ),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.diveLog_search_hintsTitle,
                  style: theme.textTheme.labelLarge,
                ),
                for (final h in hints)
                  ActionChip(
                    label: Text(
                      h,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onHint(h),
                  ),
                if (askEnabled)
                  Text(
                    l10n.diveLog_search_hintAsk,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
