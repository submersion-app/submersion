import 'package:flutter/material.dart';

/// Initial presence of an item across the selected entities.
enum MembershipPresence { all, some, none }

/// The desired end-state the user picked for an item in a bulk edit.
///
/// - [ensureOn]: the item must end up on ALL selected entities.
/// - [ensureOff]: the item must end up on NONE of the selected entities.
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
/// A checked item that was not already on every selected entity becomes an
/// add; an unchecked item that was on some/all becomes a remove; "leave
/// as-is" (and no-op cases like checking an already-on-all item) produce
/// nothing.
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

/// Every word a [BulkMembershipEditor] shows. Each caller supplies its own,
/// because several translations agree with the noun being edited (Spanish
/// "en todas las 3" is feminine for dives), so one set of strings cannot
/// serve dives and equipment items alike (issue #1942).
@immutable
class BulkMembershipLabels {
  const BulkMembershipLabels({
    required this.onAll,
    required this.onSome,
    required this.adding,
    required this.removing,
    required this.empty,
    required this.add,
  });

  /// Status line of a row already on every selected entity ("on all 3").
  final String Function(int total) onAll;

  /// Status line of a row on some of them, left as is ("on 2 of 3").
  final String Function(int count, int total) onSome;

  /// Status line of a row being put on all of them ("adding to all 3").
  final String Function(int total) adding;

  /// Status line of a row being taken off all of them.
  final String removing;

  /// Shown in place of the rows when there are none.
  final String empty;

  /// Label of the add button beside the title.
  final String add;
}

/// A tri-state membership editor for one id-based collection in bulk mode,
/// shared by the dive bulk editor and the equipment bulk tag sheet (#1942).
///
/// Shows every [items] row with a tri-state checkbox reflecting how many of
/// the [total] selected entities currently have it (from [counts]):
/// checked = on all, dash = on some (leave as-is), and lets the user ensure
/// an item onto all or off all of them. Reports the resulting add/remove
/// sets via [onChanged]. The parent owns the [items] list, handles [onAdd]
/// (opening the collection's picker to bring in new items), and supplies
/// every visible word through [labels].
class BulkMembershipEditor extends StatefulWidget {
  const BulkMembershipEditor({
    super.key,
    required this.title,
    required this.total,
    required this.labels,
    required this.items,
    required this.counts,
    required this.onAdd,
    required this.onChanged,
    this.secondaryAction,
    this.trailingBuilder,
    this.ensureOn,
    this.absentStartsChecked = true,
  });

  final String title;

  /// How many entities are selected; each value in [counts] is out of this.
  final int total;
  final BulkMembershipLabels labels;
  final List<BulkMembershipItem> items;
  final Map<String, int> counts;
  final VoidCallback onAdd;
  final ValueChanged<MembershipDelta> onChanged;
  final Widget? secondaryAction;

  /// Optional per-row control rendered at the trailing edge, for collections
  /// whose links carry an attribute beyond membership. Buddies use it for the
  /// role on each dive_buddies link (#1220); the attribute-free collections
  /// (tags, dive types, equipment) leave it null.
  final Widget Function(BulkMembershipItem item)? trailingBuilder;

  /// A one-shot instruction to put [ids] on every selected entity, whatever
  /// their rows currently say. An update carrying the same [serial] changes
  /// nothing, so a row the user unchecks afterwards stays unchecked; a fresh
  /// State (a remount) starts from the defaults and applies it again.
  /// Applying an equipment set sends one, because the set's items must end up
  /// on all the dives, including rows the user had already unchecked (#1754).
  /// The equipment tag sheet sends one for the tags picked through its Add
  /// button (#1942).
  final ({int serial, Set<String> ids})? ensureOn;

  /// Whether a row on none of the selected entities starts checked, as an
  /// add. The dive editor lists only rows already on some dive or just
  /// picked, so there an absent row is a pick and starts checked. A caller
  /// that lists a whole vocabulary (the equipment tag sheet lists every
  /// equipment tag) passes false: an absent row is then only an offer that
  /// changes nothing until ticked, and [ensureOn] switches picked rows on.
  final bool absentStartsChecked;

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
    _applyEnsureOn();
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
    if (widget.ensureOn?.serial != old.ensureOn?.serial) {
      changed = _applyEnsureOn() || changed;
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

  /// Sets every listed row named by [BulkMembershipEditor.ensureOn] to
  /// [MembershipChoice.ensureOn]. Returns whether any choice changed.
  bool _applyEnsureOn() {
    final request = widget.ensureOn;
    if (request == null) return false;
    var changed = false;
    for (final item in widget.items) {
      if (!request.ids.contains(item.id)) continue;
      if (_choices[item.id] == MembershipChoice.ensureOn) continue;
      _choices[item.id] = MembershipChoice.ensureOn;
      changed = true;
    }
    return changed;
  }

  MembershipPresence _presenceOf(String id) {
    final c = widget.counts[id] ?? 0;
    if (widget.total > 0 && c >= widget.total) {
      return MembershipPresence.all;
    }
    if (c <= 0) return MembershipPresence.none;
    return MembershipPresence.some;
  }

  MembershipChoice _defaultChoice(MembershipPresence p) => switch (p) {
    MembershipPresence.all => MembershipChoice.ensureOn,
    MembershipPresence.none =>
      widget.absentStartsChecked
          ? MembershipChoice.ensureOn
          : MembershipChoice.ensureOff,
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
  String? _subtitle(String id) {
    final labels = widget.labels;
    final presence = _presenceOf(id);
    final choice = _choices[id] ?? _defaultChoice(presence);
    final count = widget.counts[id] ?? 0;
    return switch (choice) {
      MembershipChoice.ensureOn =>
        presence == MembershipPresence.all
            ? labels.onAll(widget.total)
            : labels.adding(widget.total),
      // "off" on an item that is on none of them changes nothing, so there
      // is no status line.
      MembershipChoice.ensureOff =>
        presence == MembershipPresence.none ? null : labels.removing,
      // leaveAsIs only arises for a "some" item (all/none default to a
      // definite choice), so any other presence is a no-op with no line.
      MembershipChoice.leaveAsIs =>
        presence == MembershipPresence.some
            ? labels.onSome(count, widget.total)
            : null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    label: Text(widget.labels.add),
                  ),
                ],
              ),
            ],
          ),
          if (widget.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                widget.labels.empty,
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
                subtitle: switch (_subtitle(item.id)) {
                  final s? => Text(s),
                  _ => null,
                },
                trailing: widget.trailingBuilder?.call(item),
                onTap: () => _cycle(item.id),
              ),
        ],
      ),
    );
  }
}
