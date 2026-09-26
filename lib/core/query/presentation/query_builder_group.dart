import 'package:flutter/material.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_builder_strings.dart';
import 'package:submersion/core/query/presentation/query_condition_row.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';
import 'package:submersion/core/query/registry/query_registry.dart';

/// The rule builder of spec Unit 6: a group is a card with an AND/OR
/// toggle; rows are field, operator, value; a row can be negated; "Add
/// group" nests. Renders [root] and reports every edit as a new, normalised
/// tree through [onChanged]. A null root is an empty AND card.
class QueryBuilderGroup extends StatelessWidget {
  const QueryBuilderGroup({
    super.key,
    required this.context,
    required this.root,
    required this.onChanged,
    required this.strings,
  });

  final QueryEditorContext context;
  final QueryNode? root;
  final ValueChanged<QueryNode?> onChanged;
  final QueryBuilderStrings strings;

  @override
  Widget build(BuildContext buildContext) {
    final tree = root ?? AndNode(const []);
    // A bare condition or NOT at the root is shown inside an AND card so
    // the add buttons and the negate toggle have a home.
    final shown = tree is AndNode || tree is OrNode ? tree : AndNode([tree]);
    return _Group(
      context: context,
      strings: strings,
      root: shown,
      path: const [],
      hopsUsed: 0,
      onTree: (next) => onChanged(normalizeQuery(next)),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.context,
    required this.strings,
    required this.root,
    required this.path,
    required this.hopsUsed,
    required this.onTree,
  });

  final QueryEditorContext context;
  final QueryBuilderStrings strings;
  final QueryNode root;
  final NodePath path;
  final int hopsUsed;
  final ValueChanged<QueryNode> onTree;

  Future<void> _add(BuildContext buildContext, {required bool asGroup}) async {
    final cond = await pickCondition(
      buildContext,
      context: context,
      strings: strings,
      hopsUsed: hopsUsed,
    );
    if (cond == null) return;
    final group = nodeAt(root, path);
    // A new group starts with the opposite op, the usual reason to nest.
    final child = !asGroup
        ? cond
        : group is AndNode
        ? OrNode([cond])
        : AndNode([cond]);
    onTree(appendChild(root, path, child));
  }

  @override
  Widget build(BuildContext buildContext) {
    final group = nodeAt(root, path)!;
    final isAnd = group is AndNode;
    final children = switch (group) {
      AndNode(:final children) => children,
      OrNode(:final children) => children,
      _ => throw StateError('not a group at $path'),
    };
    final theme = Theme.of(buildContext);
    return Card(
      key: ValueKey('group-${path.join('.')}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(strings.allOf)),
                    ButtonSegment(value: false, label: Text(strings.anyOf)),
                  ],
                  selected: {isAnd},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      onTree(setGroupOp(root, path, and: s.single)),
                ),
                const Spacer(),
                if (path.isNotEmpty)
                  IconButton(
                    key: ValueKey('remove-${path.join('.')}'),
                    icon: const Icon(Icons.close),
                    tooltip: strings.remove,
                    onPressed: () =>
                        onTree(removeAt(root, path) ?? AndNode(const [])),
                  ),
              ],
            ),
            for (var i = 0; i < children.length; i++)
              _child(buildContext, children[i], [...path, i], theme),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(strings.addCondition),
                  onPressed: () => _add(buildContext, asGroup: false),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.account_tree_outlined),
                  label: Text(strings.addGroup),
                  onPressed: () => _add(buildContext, asGroup: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _child(
    BuildContext buildContext,
    QueryNode node,
    NodePath at,
    ThemeData theme,
  ) {
    final negated = node is NotNode;
    final inner = negated ? node.child : node;
    final innerPath = negated ? [...at, 0] : at;
    final key = at.join('.');
    final Widget body;
    switch (inner) {
      case AndNode() || OrNode():
        body = _Group(
          context: context,
          strings: strings,
          root: root,
          path: innerPath,
          hopsUsed: hopsUsed,
          onTree: onTree,
        );
      case ConditionNode():
        body = QueryConditionRow(
          context: context,
          condition: inner,
          strings: strings,
          hopsUsed: hopsUsed,
          onChanged: (c) => onTree(replaceAt(root, innerPath, c)),
        );
      case TextNode(:final words):
        body = _TextRow(
          label: strings.textRow,
          initial: words.join(' '),
          onChanged: (t) {
            final w = t
                .trim()
                .split(RegExp(r'\s+'))
                .where((s) => s.isNotEmpty)
                .toList();
            if (w.isNotEmpty) onTree(replaceAt(root, innerPath, TextNode(w)));
          },
        );
      case ScopedNode(:final path):
        final rel = resolvePath(
          context.registry,
          context.root,
          path,
        ).terminalRelation;
        body = ListTile(
          dense: true,
          leading: const Icon(Icons.lock_outline),
          title: Text(
            context.printer.print(inner),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          subtitle: Text(
            strings.scopedRow.replaceAll(
              '{name}',
              rel == null ? path.toString() : context.labels.relation(rel),
            ),
          ),
        );
      case NotNode():
        // NOT NOT is normalised away before it gets here.
        body = _child(buildContext, inner, innerPath, theme);
    }
    final isGroup = inner is AndNode || inner is OrNode;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A labelled toggle rather than an icon: an off "no entry" icon
          // on every row read as "this row is disabled".
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4, top: 4),
            child: FilterChip(
              key: ValueKey('negate-$key'),
              label: Text(strings.negate),
              selected: negated,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              selectedColor: theme.colorScheme.errorContainer,
              labelStyle: negated
                  ? TextStyle(color: theme.colorScheme.onErrorContainer)
                  : null,
              onSelected: (_) => onTree(toggleNegation(root, at)),
            ),
          ),
          Expanded(child: body),
          if (!isGroup)
            IconButton(
              key: ValueKey('remove-$key'),
              icon: const Icon(Icons.close),
              tooltip: strings.remove,
              onPressed: () => onTree(removeAt(root, at) ?? AndNode(const [])),
            ),
        ],
      ),
    );
  }
}

class _TextRow extends StatefulWidget {
  const _TextRow({
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  final String label;
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_TextRow> createState() => _TextRowState();
}

class _TextRowState extends State<_TextRow> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: InputDecoration(labelText: widget.label, isDense: true),
    onChanged: widget.onChanged,
  );
}
