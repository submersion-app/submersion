import 'package:flutter/material.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';

/// The rows a ref picker can offer: the resolver's rows when it can list
/// them, otherwise nothing (the text tab still resolves typed names). Rows
/// keep their own ids, so two sites with one name are both pickable.
List<RefValue> _entriesOf(QueryEditorContext editor, QuerySubject kind) =>
    switch (editor.names) {
      final NameEntries entries => entries.refEntries(kind).toList(),
      _ => const [],
    };

/// Pick one row of [kind] by name (spec Unit 6, "a ref type-ahead").
Future<RefValue?> showQueryRefPicker(
  BuildContext context, {
  required QueryEditorContext editor,
  required QuerySubject kind,
  required String title,
  required String searchHint,
  RefValue? selected,
}) => showModalBottomSheet<RefValue>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _RefPickerSheet(
    entries: _entriesOf(editor, kind),
    title: title,
    searchHint: searchHint,
    selected: selected == null ? const {} : {selected.id},
    multi: false,
    doneLabel: null,
  ),
);

/// Pick what a new condition on [relation] at [path] says: a row of its
/// target under [op], or that the relation holds nothing or something
/// (#3810). A presence test names no row, so it cannot wait behind the pick:
/// a diver with no trips has nothing to pick at all. Returns null when
/// dismissed.
Future<ConditionNode?> showQueryConditionPicker(
  BuildContext context, {
  required QueryEditorContext editor,
  required FieldPath path,
  required QueryRelation relation,
  required QueryOp op,
  required String title,
  required String searchHint,
}) async {
  final picked = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RefPickerSheet(
      entries: _entriesOf(editor, relation.target),
      title: title,
      searchHint: searchHint,
      selected: const {},
      multi: false,
      doneLabel: null,
      presence: {
        for (final presence in const [QueryOp.isEmpty, QueryOp.isSet])
          presence:
              '${editor.labels.relation(relation)} '
              '${editor.labels.op(presence)}',
      },
    ),
  );
  return switch (picked) {
    final RefValue ref => ConditionNode(path, op, ref),
    final QueryOp presence => ConditionNode(path, presence, null),
    _ => null,
  };
}

/// Pick several rows of [kind]; returns null when dismissed.
Future<List<RefValue>?> showQueryRefMultiPicker(
  BuildContext context, {
  required QueryEditorContext editor,
  required QuerySubject kind,
  required String title,
  required String searchHint,
  required String doneLabel,
  List<RefValue> selected = const [],
}) => showModalBottomSheet<List<RefValue>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _RefPickerSheet(
    entries: _entriesOf(editor, kind),
    title: title,
    searchHint: searchHint,
    selected: {for (final r in selected) r.id},
    multi: true,
    doneLabel: doneLabel,
  ),
);

class _RefPickerSheet extends StatefulWidget {
  const _RefPickerSheet({
    required this.entries,
    required this.title,
    required this.searchHint,
    required this.selected,
    required this.multi,
    required this.doneLabel,
    this.presence = const {},
  });

  final List<RefValue> entries;
  final String title;
  final String searchHint;
  final Set<String> selected;
  final bool multi;
  final String? doneLabel;

  /// Rows above the entries, by the operator each pops instead of a row. A
  /// search leaves them in place: they are not among the names it filters.
  final Map<QueryOp, String> presence;

  @override
  State<_RefPickerSheet> createState() => _RefPickerSheetState();
}

class _RefPickerSheetState extends State<_RefPickerSheet> {
  late final Set<String> _selected = {...widget.selected};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final search = _search.toLowerCase();
    final shown = [
      for (final r in widget.entries)
        if (search.isEmpty || r.label.toLowerCase().contains(search)) r,
    ];
    final presence = widget.presence.entries.toList();
    // Lifted by the keyboard inset: the search field autofocuses, and the
    // multi picker's Done bar sits at the bottom of the sheet.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            ListTile(
              title: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _search = v.trim()),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: presence.length + shown.length,
                itemBuilder: (context, i) {
                  if (i < presence.length) {
                    final row = ListTile(
                      title: Text(presence[i].value),
                      onTap: () => Navigator.of(context).pop(presence[i].key),
                    );
                    return i == presence.length - 1
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [row, const Divider(height: 1)],
                          )
                        : row;
                  }
                  final r = shown[i - presence.length];
                  final on = _selected.contains(r.id);
                  return widget.multi
                      ? CheckboxListTile(
                          value: on,
                          title: Text(r.label),
                          onChanged: (_) => setState(() {
                            if (!_selected.remove(r.id)) _selected.add(r.id);
                          }),
                        )
                      : ListTile(
                          title: Text(r.label),
                          trailing: on ? const Icon(Icons.check) : null,
                          onTap: () => Navigator.of(context).pop(r),
                        );
                },
              ),
            ),
            // Done is pinned under the list rather than in the header tile's
            // trailing: a ListTile measures trailing before the title, so a
            // text button there squeezes the sheet title in a longer
            // translation (issue #2717). Matches the confirm bar of
            // QueryFilterSheet.
            if (widget.multi)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop([
                        for (final r in widget.entries)
                          if (_selected.contains(r.id)) r,
                      ]),
                      child: Text(widget.doneLabel!),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
