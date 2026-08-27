import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/debounced_search_results.dart';

/// Picks the dive a completed checklist run should be attached to (#1066).
///
/// Recent dives are offered without typing, which covers "the dive I just
/// logged"; typing hands over to the shared dive search so a run recorded long
/// after the fact still reaches an older dive. Returns the chosen dive id, or
/// null when the diver dismissed the picker.
Future<String?> showLinkDivePicker(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _LinkDivePicker(),
  );
}

class _LinkDivePicker extends ConsumerStatefulWidget {
  const _LinkDivePicker();

  @override
  ConsumerState<_LinkDivePicker> createState() => _LinkDivePickerState();
}

class _LinkDivePickerState extends ConsumerState<_LinkDivePicker> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Dives that already carry a run are not candidates: ChecklistDiveLinker
    // keeps one run per dive, and getSessionForDive only surfaces the latest,
    // so a second hand-made link would hide the first.
    final takenAsync = ref.watch(preDiveLinkedDiveIdsProvider);

    return AlertDialog(
      title: Text(l10n.preDive_link_linkToDive),
      // A dialog sizes to its content, and the results list is unbounded, so
      // the body needs an explicit box for the ListView to scroll inside.
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: l10n.preDive_link_searchDives,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: takenAsync.when(
                // Gated rather than defaulted to an empty set: an unresolved
                // exclusion list would briefly offer dives that are taken.
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text(error.toString())),
                data: (taken) => DebouncedSearchResults<DiveSummary>(
                  query: _query,
                  watchProvider: (ref, query) =>
                      ref.watch(diveSearchProvider(query)),
                  emptyQueryBuilder: (context) => _RecentDives(taken: taken),
                  // A search whose every hit is already taken is, to the
                  // diver, a search with no results: say so rather than
                  // rendering an empty list under a query that matched.
                  dataBuilder: (context, dives) {
                    final offerable = _offerable(dives, taken);
                    return offerable.isEmpty
                        ? _noMatches(context, _query)
                        : _DiveList(dives: offerable);
                  },
                  emptyBuilder: _noMatches,
                  errorBuilder: (context, error) =>
                      Center(child: Text(error.toString())),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
      ],
    );
  }
}

List<DiveSummary> _offerable(List<DiveSummary> dives, Set<String> taken) => [
  for (final dive in dives)
    if (!taken.contains(dive.id)) dive,
];

Widget _noMatches(BuildContext context, String query) => Center(
  child: Text(
    context.l10n.preDive_link_noDivesMatch(query),
    textAlign: TextAlign.center,
  ),
);

/// The default list, shown until the diver types.
class _RecentDives extends ConsumerWidget {
  final Set<String> taken;

  const _RecentDives({required this.taken});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(preDiveLinkCandidateDivesProvider);

    return recent.when(
      data: (dives) {
        final offerable = _offerable(dives, taken);
        return offerable.isEmpty
            ? Center(child: Text(context.l10n.preDive_link_noDives))
            : _DiveList(dives: offerable);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
    );
  }
}

class _DiveList extends StatelessWidget {
  final List<DiveSummary> dives;

  const _DiveList({required this.dives});

  @override
  Widget build(BuildContext context) {
    final materialL10n = MaterialLocalizations.of(context);

    return ListView.builder(
      itemCount: dives.length,
      itemBuilder: (context, index) {
        final dive = dives[index];
        final date = materialL10n.formatMediumDate(
          dive.entryTime ?? dive.dateTime,
        );
        // Number and site identify the dive; the date is the fallback identity
        // for a dive that has neither, so it must not also be the title then.
        final parts = [
          if (dive.diveNumber != null) '#${dive.diveNumber}',
          ?dive.siteName,
        ].where((part) => part.isNotEmpty).toList();

        return ListTile(
          dense: true,
          leading: const Icon(Icons.scuba_diving),
          title: Text(parts.isEmpty ? date : parts.join(' - ')),
          subtitle: parts.isEmpty ? null : Text(date),
          onTap: () => Navigator.of(context).pop(dive.id),
        );
      },
    );
  }
}
