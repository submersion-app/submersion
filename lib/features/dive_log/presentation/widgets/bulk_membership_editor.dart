import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Initial presence of an item across the selected dives.
enum MembershipPresence { all, some, none }

/// The desired end-state the user picked for an item in a bulk edit.
///
/// - [ensureOn]: the item must end up on ALL selected dives.
/// - [ensureOff]: the item must end up on NONE of the selected dives.
/// - [leaveAsIs]: do not change membership (the safe default for "on some").
enum MembershipChoice { ensureOn, ensureOff, leaveAsIs }

/// One row in the bulk membership editor: a display label + optional icon.
class BulkMembershipItem {
  final String id;
  final String label;
  final IconData? icon;
  const BulkMembershipItem({required this.id, required this.label, this.icon});
}

/// Pure derivation of the (addIds, removeIds) to apply, given each item's
/// initial presence across the selection and the user's chosen end-state.
///
/// A checked item that was not already on all dives becomes an add; an
/// unchecked item that was on some/all becomes a remove; "leave as-is" (and
/// no-op cases like checking an already-on-all item) produce nothing.
class MembershipDelta {
  final List<String> addIds;
  final List<String> removeIds;
  const MembershipDelta(this.addIds, this.removeIds);

  static const empty = MembershipDelta([], []);

  bool get isEmpty => addIds.isEmpty && removeIds.isEmpty;

  static MembershipDelta from(
    Map<String, MembershipPresence> initial,
    Map<String, MembershipChoice> choices,
  ) {
    final add = <String>[];
    final remove = <String>[];
    for (final entry in choices.entries) {
      final presence = initial[entry.key] ?? MembershipPresence.none;
      switch (entry.value) {
        case MembershipChoice.ensureOn:
          if (presence != MembershipPresence.all) add.add(entry.key);
        case MembershipChoice.ensureOff:
          if (presence != MembershipPresence.none) remove.add(entry.key);
        case MembershipChoice.leaveAsIs:
          break;
      }
    }
    return MembershipDelta(add, remove);
  }
}

/// A tri-state membership editor for one id-based collection in bulk mode.
///
/// Shows every [items] row with a tri-state checkbox reflecting how many of
/// the [totalDives] selected dives currently have it (from [counts]):
/// checked = on all, dash = on some (leave as-is), and lets the user ensure
/// an item onto all or off all dives. Reports the resulting add/remove sets
/// via [onChanged]. The parent owns the [items] list and handles [onAdd]
/// (opening the collection's picker to bring in new items).
class BulkMembershipEditor extends StatefulWidget {
  const BulkMembershipEditor({
    super.key,
    required this.title,
    required this.totalDives,
    required this.items,
    required this.counts,
    required this.onAdd,
    required this.onChanged,
    this.addLabel,
    this.secondaryAction,
  });

  final String title;
  final int totalDives;
  final List<BulkMembershipItem> items;
  final Map<String, int> counts;
  final VoidCallback onAdd;
  final ValueChanged<MembershipDelta> onChanged;
  final String? addLabel;
  final Widget? secondaryAction;

  @override
  State<BulkMembershipEditor> createState() => _BulkMembershipEditorState();
}

class _BulkMembershipEditorState extends State<BulkMembershipEditor> {
  final Map<String, MembershipChoice> _choices = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      _choices[item.id] = _defaultChoice(_presenceOf(item.id));
    }
    // Emit the baseline so the parent has a delta before any interaction.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(_delta());
    });
  }

  @override
  void didUpdateWidget(BulkMembershipEditor old) {
    super.didUpdateWidget(old);
    final ids = widget.items.map((e) => e.id).toSet();
    var changed = false;
    for (final item in widget.items) {
      if (!_choices.containsKey(item.id)) {
        _choices[item.id] = _defaultChoice(_presenceOf(item.id));
        changed = true;
      }
    }
    final before = _choices.length;
    _choices.removeWhere((id, _) => !ids.contains(id));
    changed = changed || _choices.length != before;
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(_delta());
      });
    }
  }

  MembershipPresence _presenceOf(String id) {
    final c = widget.counts[id] ?? 0;
    if (widget.totalDives > 0 && c >= widget.totalDives) {
      return MembershipPresence.all;
    }
    if (c <= 0) return MembershipPresence.none;
    return MembershipPresence.some;
  }

  MembershipChoice _defaultChoice(MembershipPresence p) => switch (p) {
    MembershipPresence.all => MembershipChoice.ensureOn,
    MembershipPresence.none => MembershipChoice.ensureOn,
    MembershipPresence.some => MembershipChoice.leaveAsIs,
  };

  MembershipDelta _delta() => MembershipDelta.from({
    for (final item in widget.items) item.id: _presenceOf(item.id),
  }, _choices);

  void _cycle(String id) {
    final presence = _presenceOf(id);
    final current = _choices[id] ?? _defaultChoice(presence);
    setState(() => _choices[id] = _next(presence, current));
    widget.onChanged(_delta());
  }

  // "some" items cycle through all three states so the user can add-to-all,
  // remove-from-all, or leave the mix untouched; "all"/"none" items toggle.
  MembershipChoice _next(MembershipPresence p, MembershipChoice c) {
    if (p == MembershipPresence.some) {
      return switch (c) {
        MembershipChoice.leaveAsIs => MembershipChoice.ensureOn,
        MembershipChoice.ensureOn => MembershipChoice.ensureOff,
        MembershipChoice.ensureOff => MembershipChoice.leaveAsIs,
      };
    }
    return c == MembershipChoice.ensureOn
        ? MembershipChoice.ensureOff
        : MembershipChoice.ensureOn;
  }

  bool? _checkboxValue(MembershipChoice c) => switch (c) {
    MembershipChoice.ensureOn => true,
    MembershipChoice.ensureOff => false,
    MembershipChoice.leaveAsIs => null,
  };

  /// The status line for a row, or null when the choice is a no-op for this
  /// item (e.g. a just-added "none" item toggled back off) so the subtitle
  /// never claims a change the delta won't actually make.
  String? _subtitle(BuildContext context, String id) {
    final l10n = context.l10n;
    final presence = _presenceOf(id);
    final choice = _choices[id] ?? _defaultChoice(presence);
    final count = widget.counts[id] ?? 0;
    return switch (choice) {
      MembershipChoice.ensureOn =>
        presence == MembershipPresence.all
            ? l10n.diveLog_bulkEdit_membership_onAll(widget.totalDives)
            : l10n.diveLog_bulkEdit_membership_adding(widget.totalDives),
      // "off" on an item that's on no dives changes nothing -> no status line.
      MembershipChoice.ensureOff =>
        presence == MembershipPresence.none
            ? null
            : l10n.diveLog_bulkEdit_membership_removing,
      // leaveAsIs only arises for a "some" item (all/none default to a
      // definite choice), so any other presence is a no-op -> no status line.
      MembershipChoice.leaveAsIs =>
        presence == MembershipPresence.some
            ? l10n.diveLog_bulkEdit_membership_onSome(count, widget.totalDives)
            : null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(widget.title, style: theme.textTheme.titleMedium),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?widget.secondaryAction,
                  TextButton.icon(
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(widget.addLabel ?? l10n.diveLog_edit_add),
                  ),
                ],
              ),
            ],
          ),
          if (widget.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.diveLog_bulkEdit_membership_empty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final item in widget.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Checkbox(
                  key: ValueKey('membership-toggle-${item.id}'),
                  tristate: true,
                  value: _checkboxValue(
                    _choices[item.id] ?? _defaultChoice(_presenceOf(item.id)),
                  ),
                  onChanged: (_) => _cycle(item.id),
                ),
                title: Row(
                  children: [
                    if (item.icon != null) ...[
                      Icon(item.icon, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: Text(item.label)),
                  ],
                ),
                subtitle: switch (_subtitle(context, item.id)) {
                  final s? => Text(s),
                  _ => null,
                },
                onTap: () => _cycle(item.id),
              ),
        ],
      ),
    );
  }
}
