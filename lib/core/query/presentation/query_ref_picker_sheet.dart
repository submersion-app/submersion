import 'package:flutter/material.dart';

import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';

/// The rows a ref picker can offer: the resolver's entries when it can list
/// them, otherwise nothing (the text tab still resolves typed names).
List<RefValue> _entriesOf(QueryEditorContext editor, QuerySubject kind) {
  final names = editor.names;
  if (names case final NameEntries entries) {
    return [
      for (final label in entries.entryLabels(kind))
        ?names.resolve(kind, label),
    ];
  }
  return const [];
}

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
  builder: (_) => _RefPickerSheet(
    entries: _entriesOf(editor, kind),
    title: title,
    searchHint: searchHint,
    selected: selected == null ? const {} : {selected.id},
    multi: false,
    doneLabel: null,
  ),
);

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
  });

  final List<RefValue> entries;
  final String title;
  final String searchHint;
  final Set<String> selected;
  final bool multi;
  final String? doneLabel;

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
    return DraggableScrollableSheet(
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
            trailing: widget.multi
                ? FilledButton(
                    onPressed: () => Navigator.of(context).pop([
                      for (final r in widget.entries)
                        if (_selected.contains(r.id)) r,
                    ]),
                    child: Text(widget.doneLabel!),
                  )
                : null,
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
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final r = shown[i];
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
        ],
      ),
    );
  }
}
