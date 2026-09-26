import 'package:meta/meta.dart';

/// Every string the builder shows, supplied by the caller: the core widgets
/// do not read AppLocalizations. `{name}` is replaced where documented.
@immutable
class QueryBuilderStrings {
  const QueryBuilderStrings({
    required this.allOf,
    required this.anyOf,
    required this.addCondition,
    required this.addGroup,
    required this.negate,
    required this.remove,
    required this.pickField,
    required this.pickFieldSearch,
    required this.useRelation,
    required this.fieldsOf,
    required this.pickRef,
    required this.pickRefSearch,
    required this.done,
    required this.unresolvedRef,
    required this.scopedRow,
    required this.textRow,
    required this.betweenAnd,
    required this.valueTrue,
    required this.valueFalse,
  });

  final String allOf;
  final String anyOf;
  final String addCondition;
  final String addGroup;
  final String negate;
  final String remove;
  final String pickField;
  final String pickFieldSearch;

  /// `{name}` is the relation label.
  final String useRelation;

  /// `{name}` is the entity or relation label.
  final String fieldsOf;

  /// `{name}` is the relation label.
  final String pickRef;
  final String pickRefSearch;
  final String done;
  final String unresolvedRef;

  /// `{name}` is the relation label.
  final String scopedRow;
  final String textRow;
  final String betweenAnd;
  final String valueTrue;
  final String valueFalse;
}
