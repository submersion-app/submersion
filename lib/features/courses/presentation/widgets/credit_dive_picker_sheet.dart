import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/debounced_search_results.dart';

/// Picks the dive to credit toward a requirement of [courseId] (#3792).
///
/// The dives nearest the course lead, then every other dive, so a course taken
/// years ago still reaches its dives; typing hands over to the shared dive
/// search. Resolves to the chosen dive id, or null on dismiss.
Future<String?> showCreditDivePickerSheet(
  BuildContext context, {
  required String courseId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CreditDivePickerSheet(courseId: courseId),
  );
}

class _CreditDivePickerSheet extends ConsumerStatefulWidget {
  const _CreditDivePickerSheet({required this.courseId});

  final String courseId;

  @override
  ConsumerState<_CreditDivePickerSheet> createState() =>
      _CreditDivePickerSheetState();
}

class _CreditDivePickerSheetState
    extends ConsumerState<_CreditDivePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _query.trim();
    final creditableAsync = ref.watch(creditableDivesProvider(widget.courseId));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  l10n.courses_action_chooseDive,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.courses_requirement_searchDives,
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: creditableAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text(error.toString())),
                  data: (creditable) => DebouncedSearchResults<DiveSummary>(
                    query: query,
                    watchProvider: (ref, query) =>
                        ref.watch(diveSearchProvider(query)),
                    emptyQueryBuilder: (context) => _Candidates(
                      courseId: widget.courseId,
                      creditable: creditable,
                    ),
                    // A search whose every hit is uncreditable is, to the
                    // diver, a search with no results.
                    dataBuilder: (context, dives) {
                      final offerable = _offerable(dives, creditable);
                      return offerable.isEmpty
                          ? _noMatches(context, query)
                          : CustomScrollView(
                              slivers: [_DiveSliver(dives: offerable)],
                            );
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
      ),
    );
  }
}

/// Search knows nothing of courses, so a hit counts only if the course can
/// take it: linkDive ignores a dive already credited, and the search follows
/// the current diver rather than the course's.
List<RequirementDiveSummary> _offerable(
  List<DiveSummary> hits,
  List<RequirementDiveSummary> creditable,
) {
  final creditableById = {for (final dive in creditable) dive.diveId: dive};
  return [for (final hit in hits) ?creditableById[hit.id]];
}

Widget _noMatches(BuildContext context, String query) => Center(
  child: Text(
    context.l10n.courses_requirement_noDivesMatch(query),
    textAlign: TextAlign.center,
  ),
);

/// The default list, shown until the diver types.
class _Candidates extends ConsumerWidget {
  const _Candidates({required this.courseId, required this.creditable});

  final String courseId;
  final List<RequirementDiveSummary> creditable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (creditable.isEmpty) {
      return Center(child: Text(l10n.courses_requirement_noDives));
    }

    final suggested =
        ref.watch(suggestedDivesProvider(courseId)).value ?? const [];
    final creditableIds = {for (final dive in creditable) dive.diveId};
    // Checked against the list: the two providers refresh separately, and a
    // suggestion credited meanwhile would be a tap that does nothing.
    final nearby = [
      for (final dive in suggested)
        if (creditableIds.contains(dive.diveId)) dive,
    ];
    final nearbyIds = {for (final dive in nearby) dive.diveId};
    final others = [
      for (final dive in creditable)
        if (!nearbyIds.contains(dive.diveId)) dive,
    ];

    return CustomScrollView(
      slivers: [
        if (nearby.isNotEmpty) ...[
          _SectionHeader(title: l10n.courses_requirement_suggestions),
          _DiveSliver(dives: nearby),
        ],
        if (others.isNotEmpty) ...[
          _SectionHeader(title: l10n.courses_requirement_allDives),
          _DiveSliver(dives: others),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
    );
  }
}

class _DiveSliver extends ConsumerWidget {
  const _DiveSliver({required this.dives});

  final List<RequirementDiveSummary> dives;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitFormatterProvider);

    return SliverList.builder(
      itemCount: dives.length,
      itemBuilder: (context, index) {
        final dive = dives[index];
        final date = units.formatDate(dive.dateTime);
        // Number and site identify the dive; the date is the fallback identity
        // for a dive that has neither, so it must not also be the title then.
        final parts = [
          if (dive.diveNumber != null) '#${dive.diveNumber}',
          ?dive.siteName,
        ].where((part) => part.isNotEmpty).toList();

        return ListTile(
          dense: true,
          leading: const Icon(Icons.scuba_diving),
          title: Text(parts.isEmpty ? date : parts.join(' · ')),
          subtitle: parts.isEmpty ? null : Text(date),
          onTap: () => Navigator.of(context).pop(dive.diveId),
        );
      },
    );
  }
}
