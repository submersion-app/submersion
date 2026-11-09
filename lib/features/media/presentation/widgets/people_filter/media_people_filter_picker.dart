import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/widgets/people_filter/media_people_selection.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the People picker of the library filter on [initial] and returns
/// the ticks on Done, or null when dismissed.
///
/// Built for hundreds of tagged buddies (issue #4148): a search field over a
/// lazily built list, rather than one chip per person.
Future<MediaPeopleSelection?> showMediaPeopleFilterPicker(
  BuildContext context, {
  required MediaPeopleSelection initial,
}) {
  return showModalBottomSheet<MediaPeopleSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MediaPeopleFilterPicker(initial: initial),
  );
}

/// One row of the list: [key] is `none`, `me` or a buddy id.
typedef _Row = ({String key, String label, IconData? icon});

class _MediaPeopleFilterPicker extends ConsumerStatefulWidget {
  final MediaPeopleSelection initial;

  const _MediaPeopleFilterPicker({required this.initial});

  @override
  ConsumerState<_MediaPeopleFilterPicker> createState() =>
      _MediaPeopleFilterPickerState();
}

class _MediaPeopleFilterPickerState
    extends ConsumerState<_MediaPeopleFilterPicker> {
  late MediaPeopleSelection _selection = widget.initial;
  String _query = '';

  bool _matches(String label) =>
      _query.isEmpty || label.toLowerCase().contains(_query.toLowerCase());

  bool _ticked(String key) => switch (key) {
    'none' => _selection.noPeople,
    'me' => _selection.includeMe,
    _ => _selection.buddyIds.contains(key),
  };

  void _toggle(String key, bool picked) => setState(() {
    _selection = switch (key) {
      'none' => _selection.withNoPeople(picked),
      'me' => _selection.withMe(picked),
      _ => _selection.withBuddy(key, picked),
    };
  });

  /// "No one tagged" and Me, then the people picked when the picker opened
  /// (so they can be unticked without scrolling), then every other buddy
  /// tagged somewhere, each group by name. The groups are fixed at open, so
  /// a row never jumps when it is ticked. A picked buddy no longer listed
  /// (deleted since an album was saved) reads as removed, but only once the
  /// buddies have loaded: before that every picked id is unlisted.
  List<_Row> _rows() {
    final l10n = context.l10n;
    final all = ref.watch(allBuddiesProvider).value;
    final tagged = ref.watch(taggedBuddyIdsProvider).value ?? const <String>{};
    final picked = widget.initial.buddyIds;

    int byName(Buddy a, Buddy b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    final known = {for (final b in all ?? const <Buddy>[]) b.id};
    final first = [
      for (final b in all ?? const <Buddy>[])
        if (picked.contains(b.id)) b,
    ]..sort(byName);
    final rest = [
      for (final b in all ?? const <Buddy>[])
        if (!picked.contains(b.id) && tagged.contains(b.id)) b,
    ]..sort(byName);

    return [
      (
        key: 'none',
        label: l10n.media_library_filter_noPeople,
        icon: Icons.person_off_outlined,
      ),
      (key: 'me', label: l10n.media_people_me, icon: Icons.person),
      if (all != null)
        for (final id in picked)
          if (!known.contains(id))
            (key: id, label: l10n.media_people_removedBuddy, icon: null),
      for (final b in first) (key: b.id, label: b.name, icon: null),
      for (final b in rest) (key: b.id, label: b.name, icon: null),
    ].where((r) => _matches(r.label)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rows = _rows();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.media_people_filterSection,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.media_library_filter_peopleSearchHint,
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: rows.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.media_library_filter_peopleNoMatch,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        return CheckboxListTile(
                          key: ValueKey('media_people_pick_${row.key}'),
                          // An avatar on every row, as in the tagging
                          // picker, so the names line up under Me.
                          secondary: CircleAvatar(
                            radius: 16,
                            child: row.icon != null
                                ? Icon(row.icon, size: 18)
                                : Text(
                                    row.label.isEmpty
                                        ? '?'
                                        : row.label.characters.first,
                                  ),
                          ),
                          title: Text(row.label),
                          value: _ticked(row.key),
                          onChanged: (v) => _toggle(row.key, v ?? false),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selection),
                  child: Text(l10n.common_action_done),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
