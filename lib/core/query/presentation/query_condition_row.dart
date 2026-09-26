import 'package:flutter/material.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_builder_strings.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_field_picker_sheet.dart';
import 'package:submersion/core/query/presentation/query_ref_picker_sheet.dart';
import 'package:submersion/core/query/presentation/query_value_editor.dart';
import 'package:submersion/core/query/registry/query_registry.dart';

/// Opens the field picker and, for a relation, the ref picker, and returns
/// a complete default condition, or null when the diver backed out. Shared
/// by "Add condition", "Add group" and a row's field button.
Future<ConditionNode?> pickCondition(
  BuildContext buildContext, {
  required QueryEditorContext context,
  required QueryBuilderStrings strings,
  int hopsUsed = 0,
}) async {
  final pick = await showQueryFieldPicker(
    buildContext,
    editor: context,
    strings: QueryFieldPickerStrings(
      title: strings.pickField,
      searchHint: strings.pickFieldSearch,
      useRelation: strings.useRelation,
      fieldsOf: strings.fieldsOf,
    ),
    hopsUsed: hopsUsed,
  );
  if (pick == null || !buildContext.mounted) return null;
  final target = resolvePath(context.registry, context.root, pick.path);
  final op = opsFor(target).first;
  if (pick.isRelation) {
    final rel = target.terminalRelation!;
    final ref = await showQueryRefPicker(
      buildContext,
      editor: context,
      kind: rel.target,
      title: strings.pickRef.replaceAll('{name}', context.labels.relation(rel)),
      searchHint: strings.pickRefSearch,
    );
    if (ref == null) return null;
    return ConditionNode(pick.path, op, ref);
  }
  return ConditionNode(pick.path, op, defaultValueFor(target, op, context));
}

/// One condition: the field button (reopens the picker), the operator menu
/// and the value editor. Negation and removal are the group's affordances.
class QueryConditionRow extends StatelessWidget {
  const QueryConditionRow({
    super.key,
    required this.context,
    required this.condition,
    required this.onChanged,
    required this.strings,
    this.hopsUsed = 0,
  });

  final QueryEditorContext context;
  final ConditionNode condition;
  final ValueChanged<ConditionNode> onChanged;
  final QueryBuilderStrings strings;
  final int hopsUsed;

  @override
  Widget build(BuildContext buildContext) {
    final target = resolvePath(context.registry, context.root, condition.path);
    final field = target.field;
    final rel = target.terminalRelation;
    final label = field != null
        ? context.labels.field(field)
        : rel != null
        ? context.labels.relation(rel)
        : condition.path.toString();
    // The relations walked before the terminal field or relation.
    final crumbHops = field != null || target.hops.isEmpty
        ? target.hops
        : target.hops.sublist(0, target.hops.length - 1);
    final crumbs = [for (final h in crumbHops) context.labels.relation(h)];
    final ops = opsFor(target);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          onPressed: () async {
            final next = await pickCondition(
              buildContext,
              context: context,
              strings: strings,
              hopsUsed: hopsUsed,
            );
            if (next != null) onChanged(next);
          },
          child: Text(
            crumbs.isEmpty ? label : '${crumbs.join(' > ')} > $label',
          ),
        ),
        DropdownButton<QueryOp>(
          value: ops.contains(condition.op) ? condition.op : ops.first,
          items: [
            for (final op in ops)
              DropdownMenuItem(value: op, child: Text(context.labels.op(op))),
          ],
          onChanged: (op) {
            if (op == null || op == condition.op) return;
            final next = _valueFor(op, target);
            // A relation needs a pick the diver has not made: keep the row.
            if (op.takesValue && next == null) return;
            onChanged(ConditionNode(condition.path, op, next));
          },
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 120, maxWidth: 320),
          child: QueryValueEditor(
            context: context,
            target: target,
            op: condition.op,
            value: condition.value,
            onChanged: (v) =>
                onChanged(ConditionNode(condition.path, condition.op, v)),
            strings: strings,
          ),
        ),
      ],
    );
  }

  /// The value the row keeps when its operator changes to [op]: the same
  /// value across scalar comparisons, a ref carried into or out of a list,
  /// otherwise the type's default. Null when [op] takes none, or when a
  /// relation would need a pick the diver has not made.
  QueryValue? _valueFor(QueryOp op, PathResolution target) {
    if (!op.takesValue) return null;
    final current = condition.value;
    if (condition.op.takesValue && sameValueShape(condition.op, op)) {
      return current;
    }
    if (target.terminalRelation != null) {
      return switch ((op, current)) {
        (QueryOp.inList, final RefValue r) => ListValue([r]),
        (QueryOp.inList, final ListValue l) when l.items.isNotEmpty => l,
        (_, final ListValue l) when l.items.isNotEmpty => l.items.first,
        (_, final RefValue r) => r,
        _ => null,
      };
    }
    return defaultValueFor(target, op, context);
  }
}
