import 'package:flutter/material.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_registry.dart';

/// What the picker hands back: a dotted path ending in a field, or ending in
/// a relation the row will compare as a ref (`site = X`, `buddies:none`).
typedef FieldPick = ({FieldPath path, bool isRelation});

/// The picker's strings, supplied by the caller (the core widgets do not
/// read AppLocalizations). `{name}` in [useRelation] and [fieldsOf] is
/// replaced with the entity or relation label.
class QueryFieldPickerStrings {
  const QueryFieldPickerStrings({
    required this.title,
    required this.searchHint,
    required this.useRelation,
    required this.fieldsOf,
  });

  final String title;
  final String searchHint;
  final String useRelation;
  final String fieldsOf;
}

/// The searchable field tree of spec Unit 6: the root entity's fields and
/// relations, a chevron on each relation walking into its entity
/// (Dives > Buddies > Certifications > Level), a back arrow up. Depth is
/// capped at [kMaxPathHops] minus [hopsUsed] (hops already spent by an
/// enclosing scoped group).
Future<FieldPick?> showQueryFieldPicker(
  BuildContext context, {
  required QueryEditorContext editor,
  required QueryFieldPickerStrings strings,
  int hopsUsed = 0,
}) => showModalBottomSheet<FieldPick>(
  context: context,
  isScrollControlled: true,
  builder: (_) =>
      _FieldPickerSheet(editor: editor, strings: strings, hopsUsed: hopsUsed),
);

class _FieldPickerSheet extends StatefulWidget {
  const _FieldPickerSheet({
    required this.editor,
    required this.strings,
    required this.hopsUsed,
  });

  final QueryEditorContext editor;
  final QueryFieldPickerStrings strings;
  final int hopsUsed;

  @override
  State<_FieldPickerSheet> createState() => _FieldPickerSheetState();
}

class _FieldPickerSheetState extends State<_FieldPickerSheet> {
  /// The relation keys walked so far.
  final List<String> _segments = [];
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  QueryEntity get _entity => _segments.isEmpty
      ? widget.editor.root
      : resolvePath(
          widget.editor.registry,
          widget.editor.root,
          FieldPath(_segments),
        ).entities.last;

  bool get _canDescend => widget.hopsUsed + _segments.length + 1 < kMaxPathHops;

  bool _matches(String key, String label) {
    final s = _search.text.trim().toLowerCase();
    if (s.isEmpty) return true;
    return key.toLowerCase().contains(s) || label.toLowerCase().contains(s);
  }

  void _descend(String key) => setState(() {
    _segments.add(key);
    _search.clear();
  });

  @override
  Widget build(BuildContext context) {
    final entity = _entity;
    final labels = widget.editor.labels;
    final theme = Theme.of(context);
    final title = _segments.isEmpty
        ? widget.strings.title
        : widget.strings.fieldsOf.replaceAll(
            '{name}',
            labels.entity(entity.subject),
          );
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          ListTile(
            leading: _segments.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _segments.removeLast()),
                  ),
            title: Text(title, style: theme.textTheme.titleMedium),
            subtitle: _segments.isEmpty ? null : Text(_segments.join(' > ')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.strings.searchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                for (final f in entity.fields)
                  if (_matches(f.key, labels.field(f)))
                    ListTile(
                      leading: const Icon(Icons.short_text),
                      title: Text(labels.field(f)),
                      subtitle: Text(f.key),
                      onTap: () => Navigator.of(context).pop((
                        path: FieldPath([..._segments, f.key]),
                        isRelation: false,
                      )),
                    ),
                for (final r in entity.relations)
                  if (_matches(r.key, labels.relation(r)))
                    ListTile(
                      leading: const Icon(Icons.link),
                      title: Text(labels.relation(r)),
                      subtitle: Text(
                        widget.strings.useRelation.replaceAll(
                          '{name}',
                          labels.relation(r),
                        ),
                      ),
                      trailing: _canDescend
                          ? IconButton(
                              key: ValueKey('descend-${r.key}'),
                              icon: const Icon(Icons.chevron_right),
                              tooltip: widget.strings.fieldsOf.replaceAll(
                                '{name}',
                                labels.relation(r),
                              ),
                              onPressed: () => _descend(r.key),
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop((
                        path: FieldPath([..._segments, r.key]),
                        isRelation: true,
                      )),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
