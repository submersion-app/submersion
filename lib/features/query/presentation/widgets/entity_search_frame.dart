import 'package:flutter/material.dart';

import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/query/presentation/widgets/entity_search_header.dart';
import 'package:submersion/features/query/presentation/widgets/query_chips_frame.dart';

/// A list body under its search row and its query's chips (#3882): the
/// [EntitySearchHeader] and the [QueryChipsFrame] over one query, for the
/// lists whose whole filter is that query.
class EntitySearchFrame extends StatelessWidget {
  const EntitySearchFrame({
    super.key,
    required this.subject,
    required this.root,
    required this.query,
    required this.onChanged,
    required this.child,
    this.hintText,
    this.onEscape,
  });

  final QuerySubject subject;
  final QueryEntity root;
  final QueryNode? query;
  final ValueChanged<QueryNode?> onChanged;
  final Widget child;
  final String? hintText;

  /// See [EntitySearchHeader.onEscape].
  final VoidCallback? onEscape;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      EntitySearchHeader(
        subject: subject,
        root: root,
        query: query,
        onChanged: onChanged,
        hintText: hintText,
        onEscape: onEscape,
      ),
      Expanded(
        child: QueryChipsFrame(
          root: root,
          query: query,
          onChanged: onChanged,
          child: child,
        ),
      ),
    ],
  );
}
