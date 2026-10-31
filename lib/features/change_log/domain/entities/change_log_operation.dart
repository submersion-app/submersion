import 'package:equatable/equatable.dart';

import 'package:submersion/core/services/change_log/change_log_scope.dart';

/// One entry in the change log: a save, an import, a sync, a revert.
class ChangeLogOperation extends Equatable {
  const ChangeLogOperation({
    required this.id,
    required this.source,
    this.label,
    this.deviceId,
    this.diverId,
    this.rootTable,
    this.rootId,
    this.rootLabel,
    this.rootOrdinal,
    required this.startedAt,
    required this.endedAt,
    this.lastEventId,
    this.eventCount = 0,
    this.summaryCount,
    this.revertOfId,
    this.revertedById,
  });

  final String id;
  final ChangeLogSource source;
  final String? label;

  /// The peer a sync came from. Null means this device.
  final String? deviceId;

  /// The owner. Null when the root record has none, such as a species.
  final String? diverId;

  /// The one record this entry is about. Null when it touched several.
  final String? rootTable;
  final String? rootId;

  /// The root's name, stored so an entry still reads after it is deleted.
  final String? rootLabel;

  /// A dive's number.
  final int? rootOrdinal;
  final DateTime startedAt;
  final DateTime endedAt;
  final int? lastEventId;
  final int eventCount;

  /// Set on an entry that stands for writes that were not recorded, such as
  /// adopting a library on a new device.
  final int? summaryCount;
  final String? revertOfId;
  final String? revertedById;

  bool get isSummary => summaryCount != null;
  bool get isReverted => revertedById != null;
  bool get isBulk => rootId == null;

  ChangeLogOperation copyWith({String? revertedById}) => ChangeLogOperation(
    id: id,
    source: source,
    label: label,
    deviceId: deviceId,
    diverId: diverId,
    rootTable: rootTable,
    rootId: rootId,
    rootLabel: rootLabel,
    rootOrdinal: rootOrdinal,
    startedAt: startedAt,
    endedAt: endedAt,
    lastEventId: lastEventId,
    eventCount: eventCount,
    summaryCount: summaryCount,
    revertOfId: revertOfId,
    revertedById: revertedById ?? this.revertedById,
  );

  @override
  List<Object?> get props => [
    id,
    source,
    label,
    deviceId,
    diverId,
    rootTable,
    rootId,
    rootLabel,
    rootOrdinal,
    startedAt,
    endedAt,
    lastEventId,
    eventCount,
    summaryCount,
    revertOfId,
    revertedById,
  ];
}
