import 'package:drift/drift.dart';

/// A fragment of SQL and the values bound to its marks, in order.
typedef ChangeLogSql = ({String sql, List<Variable<Object>> variables});

/// `?, ?, ?`: one mark for each of [count] values.
String changeLogMarks(int count) => List.filled(count, '?').join(', ');
