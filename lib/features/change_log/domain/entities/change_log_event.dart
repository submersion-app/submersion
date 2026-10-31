import 'package:equatable/equatable.dart';

enum ChangeLogAction {
  insert('I'),
  update('U'),
  delete('D');

  const ChangeLogAction(this.code);

  /// The value in `change_log_events.action`.
  final String code;

  static ChangeLogAction fromCode(String code) =>
      values.firstWhere((action) => action.code == code);
}

/// One changed column. A value keeps the type SQLite stored it with, so it
/// can be text, a number, bytes or null.
class ChangeLogFieldChange extends Equatable {
  const ChangeLogFieldChange({
    required this.table,
    required this.column,
    this.oldValue,
    this.newValue,
  });

  final String table;
  final String column;
  final Object? oldValue;
  final Object? newValue;

  @override
  List<Object?> get props => [table, column, oldValue, newValue];
}

/// One changed record inside a change log entry.
class ChangeLogEvent extends Equatable {
  const ChangeLogEvent({
    required this.id,
    required this.operationId,
    required this.table,
    required this.recordId,
    required this.action,
    required this.changedAt,
    required this.schemaVersion,
    this.rootTable,
    this.rootId,
    this.fields = const [],
  });

  final int id;
  final String operationId;
  final String table;
  final String recordId;
  final ChangeLogAction action;
  final DateTime changedAt;

  /// The schema this was written under, which decides whether a later
  /// migration has made its values unsafe to restore.
  final int schemaVersion;
  final String? rootTable;
  final String? rootId;

  /// The changed columns of an update, or every non-null column of a delete.
  final List<ChangeLogFieldChange> fields;

  @override
  List<Object?> get props => [
    id,
    operationId,
    table,
    recordId,
    action,
    changedAt,
    schemaVersion,
    rootTable,
    rootId,
    fields,
  ];
}

/// What the feed shows of an entry: its first fields and how many there are.
class ChangeLogPreview extends Equatable {
  const ChangeLogPreview({required this.fields, required this.total});

  final List<ChangeLogFieldChange> fields;
  final int total;

  @override
  List<Object?> get props => [fields, total];
}
