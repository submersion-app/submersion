import 'package:equatable/equatable.dart';

import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';

/// What the feed shows. Empty sets mean no restriction. A provider family
/// key, so it compares by value.
class ChangeLogFilter extends Equatable {
  const ChangeLogFilter({
    this.rootTables = const {},
    this.sources = const {},
    this.rootTable,
    this.rootId,
  });

  /// Entries about these kinds of record.
  final Set<String> rootTables;
  final Set<ChangeLogSource> sources;

  /// With [rootId], the one record a History item opened the log on.
  final String? rootTable;
  final String? rootId;

  bool get isRecord => rootTable != null && rootId != null;

  ChangeLogFilter copyWith({
    Set<String>? rootTables,
    Set<ChangeLogSource>? sources,
  }) => ChangeLogFilter(
    rootTables: rootTables ?? this.rootTables,
    sources: sources ?? this.sources,
    rootTable: rootTable,
    rootId: rootId,
  );

  @override
  List<Object?> get props => [rootTables, sources, rootTable, rootId];
}

/// Where the next page starts. The id breaks a tie: summaries written with
/// no events between them share a `last_event_id`.
class ChangeLogPageCursor extends Equatable {
  const ChangeLogPageCursor({required this.lastEventId, required this.id});

  ChangeLogPageCursor.after(ChangeLogOperation operation)
    : this(lastEventId: operation.lastEventId ?? 0, id: operation.id);

  final int lastEventId;
  final String id;

  @override
  List<Object?> get props => [lastEventId, id];
}
