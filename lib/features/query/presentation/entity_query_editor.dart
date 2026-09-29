import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_builder_strings.dart';
import 'package:submersion/core/query/presentation/query_editor.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/query/presentation/app_query_labels.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/query/presentation/query_error_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The placeholder strings pass a literal `{name}` through the ARB getter
/// so the core widgets substitute the label themselves.
QueryBuilderStrings queryBuilderStringsOf(AppLocalizations l10n) =>
    QueryBuilderStrings(
      allOf: l10n.query_editor_allOf,
      anyOf: l10n.query_editor_anyOf,
      addCondition: l10n.query_editor_addCondition,
      addGroup: l10n.query_editor_addGroup,
      negate: l10n.query_editor_negate,
      remove: l10n.query_editor_remove,
      pickField: l10n.query_editor_pickField,
      pickFieldSearch: l10n.query_editor_pickFieldSearch,
      useRelation: l10n.query_editor_useRelation('{name}'),
      fieldsOf: l10n.query_editor_fieldsOf('{name}'),
      pickRef: l10n.query_editor_pickRef('{name}'),
      pickRefSearch: l10n.query_editor_pickRefSearch,
      done: l10n.query_editor_done,
      unresolvedRef: l10n.query_editor_unresolvedRef,
      needsText: l10n.query_editor_needsText,
      scopedRow: l10n.query_editor_scopedRow('{name}'),
      textRow: l10n.query_editor_textRow,
      betweenAnd: l10n.query_editor_betweenAnd,
      valueTrue: l10n.query_editor_valueTrue,
      valueFalse: l10n.query_editor_valueFalse,
    );

QueryEditorStrings queryEditorStringsOf(AppLocalizations l10n) =>
    QueryEditorStrings(
      tabText: l10n.query_editor_tabText,
      tabBuilder: l10n.query_editor_tabBuilder,
      hint: l10n.query_editor_hint,
      save: l10n.query_editor_save,
      builder: queryBuilderStringsOf(l10n),
    );

/// A query editor for any list: [QueryEditor] over the app registry rooted
/// at [root], the diver's units, the live name index and the ARB labels
/// (#2365). Until the name index arrives the editor parses against an empty
/// index, so a typed ref name fails with suggestions rather than blocking
/// the field.
class EntityQueryEditor extends ConsumerWidget {
  const EntityQueryEditor({
    super.key,
    required this.root,
    required this.value,
    required this.onChanged,
    this.onSave,
  });

  final QueryEntity root;
  final QueryNode? value;
  final ValueChanged<QueryNode?> onChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(queryUnitPrefsProvider);
    final names = ref.watch(queryNameIndexProvider).value ?? NameIndex.empty;
    final editorContext = QueryEditorContext(
      registry: appQueryRegistry,
      root: root,
      prefs: prefs,
      names: names,
      labels: AppQueryLabels(context),
      now: DateTime.now,
    );
    return QueryEditor(
      context: editorContext,
      value: value,
      onChanged: onChanged,
      strings: queryEditorStringsOf(context.l10n),
      onSave: onSave,
      describeError: (e) => describeQueryError(context.l10n, e),
    );
  }
}
