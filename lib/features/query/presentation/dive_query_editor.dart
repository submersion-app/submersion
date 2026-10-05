import 'package:flutter/material.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/query/presentation/entity_query_editor.dart';

export 'package:submersion/features/query/presentation/entity_query_editor.dart';

/// The dive query editor: [EntityQueryEditor] rooted at dives.
class DiveQueryEditor extends StatelessWidget {
  const DiveQueryEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.onSave,
    this.canSave,
  });

  final QueryNode? value;
  final ValueChanged<QueryNode?> onChanged;
  final VoidCallback? onSave;
  final bool? canSave;

  @override
  Widget build(BuildContext context) => EntityQueryEditor(
    root: diveQueryEntity,
    value: value,
    onChanged: onChanged,
    onSave: onSave,
    canSave: canSave,
  );
}
