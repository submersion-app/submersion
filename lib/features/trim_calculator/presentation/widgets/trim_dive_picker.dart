import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/trim_calculator/presentation/providers/trim_calculator_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/debounced_search_results.dart';

/// Picks the dive the trim calculator shows (issue #5028): recent dives
/// without typing, the shared dive search once the diver types. Returns the
/// chosen dive id, or null when the picker was dismissed.
Future<String?> showTrimDivePicker(BuildContext context) => showDialog<String>(
  context: context,
  builder: (_) => const _TrimDivePicker(),
);

/// A dive's name in a list: its number and site, or its date when it has
/// neither, with the date as the subtitle otherwise.
({String title, String? subtitle}) trimDiveLabel({
  required int? number,
  required String? site,
  required DateTime when,
  required UnitFormatter units,
}) {
  final date = units.formatDate(when);
  final parts = [
    if (number != null) '#$number',
    if (site != null && site.isNotEmpty) site,
  ];
  return parts.isEmpty
      ? (title: date, subtitle: null)
      : (title: parts.join(' - '), subtitle: date);
}

class _TrimDivePicker extends ConsumerStatefulWidget {
  const _TrimDivePicker();

  @override
  ConsumerState<_TrimDivePicker> createState() => _TrimDivePickerState();
}

class _TrimDivePickerState extends ConsumerState<_TrimDivePicker> {
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
    return AlertDialog(
      title: Text(l10n.trim_calculator_pickDive),
      // A dialog sizes to its content and the list is unbounded, so the body
      // needs an explicit box for the list to scroll inside.
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: l10n.trim_calculator_searchDives,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DebouncedSearchResults<DiveSummary>(
                query: _query,
                watchProvider: (ref, query) =>
                    ref.watch(diveSearchProvider(query)),
                emptyQueryBuilder: (context) => const _RecentDives(),
                dataBuilder: (context, dives) => _DiveList(dives: dives),
                emptyBuilder: (context, query) => Center(
                  child: Text(
                    l10n.trim_calculator_noMatches(query),
                    textAlign: TextAlign.center,
                  ),
                ),
                errorBuilder: (context, error) =>
                    Center(child: Text(error.toString())),
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

class _RecentDives extends ConsumerWidget {
  const _RecentDives();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(trimCalculatorRecentDivesProvider)
      .when(
        data: (dives) => _DiveList(dives: dives),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      );
}

class _DiveList extends ConsumerWidget {
  const _DiveList({required this.dives});

  final List<DiveSummary> dives;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitFormatterProvider);
    return ListView.builder(
      itemCount: dives.length,
      itemBuilder: (context, index) {
        final dive = dives[index];
        final label = trimDiveLabel(
          number: dive.diveNumber,
          site: dive.siteName,
          when: dive.entryTime ?? dive.dateTime,
          units: units,
        );
        return ListTile(
          dense: true,
          leading: const Icon(Icons.scuba_diving),
          title: Text(label.title),
          subtitle: label.subtitle == null ? null : Text(label.subtitle!),
          onTap: () => Navigator.of(context).pop(dive.id),
        );
      },
    );
  }
}
