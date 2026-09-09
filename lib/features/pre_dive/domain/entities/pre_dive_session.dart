import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/overdue_service_entry.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/services/cell_linearity.dart';

/// Lifecycle of a pre-dive checklist run.
enum PreDiveSessionStatus {
  inProgress,
  completed,
  aborted;

  static PreDiveSessionStatus parse(String raw) =>
      PreDiveSessionStatus.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => PreDiveSessionStatus.inProgress,
      );
}

/// Outcome state of a single item during a run.
enum PreDiveItemState {
  pending,
  done,
  skipped,
  flagged;

  static PreDiveItemState parse(String raw) => PreDiveItemState.values
      .firstWhere((e) => e.name == raw, orElse: () => PreDiveItemState.pending);
}

/// Item tallies for one session, aggregated in SQL so a list of sessions can
/// render progress and flag badges without loading every item row.
class PreDiveSessionStats extends Equatable {
  final int total;
  final int resolved;
  final int flagged;

  const PreDiveSessionStats({
    this.total = 0,
    this.resolved = 0,
    this.flagged = 0,
  });

  bool get hasFlagged => flagged > 0;

  @override
  List<Object?> get props => [total, resolved, flagged];
}

/// A pre-dive checklist run. Completed/aborted sessions are immutable.
class PreDiveSession extends Equatable {
  final String id;
  final String? diverId;
  final String? templateId;
  final String templateName;
  final bool strictOrder;
  final String? diveId;
  final String? tripId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final PreDiveSessionStatus status;
  final String? equipmentSetId;
  final String? equipmentSetName;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PreDiveSession({
    required this.id,
    this.diverId,
    this.templateId,
    required this.templateName,
    this.strictOrder = false,
    this.diveId,
    this.tripId,
    required this.startedAt,
    this.completedAt,
    this.status = PreDiveSessionStatus.inProgress,
    this.equipmentSetId,
    this.equipmentSetName,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLocked => status != PreDiveSessionStatus.inProgress;

  PreDiveSession copyWith({
    String? id,
    Object? diverId = _undefined,
    Object? templateId = _undefined,
    String? templateName,
    bool? strictOrder,
    Object? diveId = _undefined,
    Object? tripId = _undefined,
    DateTime? startedAt,
    Object? completedAt = _undefined,
    PreDiveSessionStatus? status,
    Object? equipmentSetId = _undefined,
    Object? equipmentSetName = _undefined,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PreDiveSession(
      id: id ?? this.id,
      diverId: diverId == _undefined ? this.diverId : diverId as String?,
      templateId: templateId == _undefined
          ? this.templateId
          : templateId as String?,
      templateName: templateName ?? this.templateName,
      strictOrder: strictOrder ?? this.strictOrder,
      diveId: diveId == _undefined ? this.diveId : diveId as String?,
      tripId: tripId == _undefined ? this.tripId : tripId as String?,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt == _undefined
          ? this.completedAt
          : completedAt as DateTime?,
      status: status ?? this.status,
      equipmentSetId: equipmentSetId == _undefined
          ? this.equipmentSetId
          : equipmentSetId as String?,
      equipmentSetName: equipmentSetName == _undefined
          ? this.equipmentSetName
          : equipmentSetName as String?,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    templateId,
    templateName,
    strictOrder,
    diveId,
    tripId,
    startedAt,
    completedAt,
    status,
    equipmentSetId,
    equipmentSetName,
    notes,
    createdAt,
    updatedAt,
  ];
}

/// Snapshot of one template item plus its run state.
class PreDiveSessionItem extends Equatable {
  final String id;
  final String sessionId;
  final String? section;
  final String title;
  final String notes;
  final int sortOrder;
  final PreDiveItemType itemType;
  final String? valueLabel;
  final String? valueUnit;
  final double? valueMin;
  final double? valueMax;
  final bool isRequired;
  final PreDiveItemState state;
  final double? valueNumber;
  final String? valueText;
  final String note;
  final DateTime? completedAt;
  final String? equipmentId;

  /// Snapshot of the linked equipment's overdue-service list, frozen the
  /// moment the diver last moved this item away from pending (done, skipped
  /// or flagged). Null while pending -- the runner UI computes the live
  /// overdue list from [equipmentId] instead -- and cleared back to null on
  /// reset. An empty (non-null) list means "resolved with nothing overdue at
  /// the time", distinct from "never computed" (e.g. rows resolved before
  /// this field existed).
  final List<OverdueServiceEntry>? overdueServices;

  /// For a [PreDiveItemType.cellLinearity] item, the id of the session item
  /// holding this cell's air reading, remapped from the template item id by
  /// SessionItemComposer. Tolerated as dangling.
  final String? sourceItemId;

  /// The air millivolts, frozen the moment the diver resolved this item.
  ///
  /// Frozen rather than re-read for the same reason [overdueServices] is: a
  /// completed run is an audit record, and a later correction to the air
  /// reading must not silently rewrite what the diver saw when they made the
  /// call. Cleared back to null on reset.
  final double? sourceValueNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PreDiveSessionItem({
    required this.id,
    required this.sessionId,
    this.section,
    required this.title,
    this.notes = '',
    this.sortOrder = 0,
    this.itemType = PreDiveItemType.check,
    this.valueLabel,
    this.valueUnit,
    this.valueMin,
    this.valueMax,
    this.isRequired = false,
    this.state = PreDiveItemState.pending,
    this.valueNumber,
    this.valueText,
    this.note = '',
    this.completedAt,
    this.equipmentId,
    this.overdueServices,
    this.sourceItemId,
    this.sourceValueNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isResolved => state != PreDiveItemState.pending;

  bool get isCellLinearity => itemType == PreDiveItemType.cellLinearity;

  /// Millivolts this cell should produce at a ppO2 of 1.0, derived from the
  /// frozen air reading. Null on any other item type, and before the air
  /// reading is known.
  double? get expectedO2Millivolts => isCellLinearity
      ? CellLinearity.expectedO2Millivolts(sourceValueNumber)
      : null;

  /// This cell's linearity as a percentage, or null when it cannot be
  /// derived yet.
  double? get linearityPercent => isCellLinearity
      ? CellLinearity.percent(
          airMillivolts: sourceValueNumber,
          o2Millivolts: valueNumber,
        )
      : null;

  /// Advisory range warning for recorded values (never blocking).
  ///
  /// [valueMin] and [valueMax] mean millivolts on a `value` item but a
  /// percentage on a `cellLinearity` item, so the figure they are compared
  /// against differs by type. Comparing a 95% floor against a 48 mV reading
  /// would light the warning on every healthy cell.
  bool get valueOutOfRange {
    final v = isCellLinearity ? linearityPercent : valueNumber;
    if (v == null) return false;
    final belowMin = valueMin != null && v < valueMin!;
    final aboveMax = valueMax != null && v > valueMax!;
    return belowMin || aboveMax;
  }

  PreDiveSessionItem copyWith({
    String? id,
    String? sessionId,
    Object? section = _undefined,
    String? title,
    String? notes,
    int? sortOrder,
    PreDiveItemType? itemType,
    Object? valueLabel = _undefined,
    Object? valueUnit = _undefined,
    Object? valueMin = _undefined,
    Object? valueMax = _undefined,
    bool? isRequired,
    PreDiveItemState? state,
    Object? valueNumber = _undefined,
    Object? valueText = _undefined,
    String? note,
    Object? completedAt = _undefined,
    Object? equipmentId = _undefined,
    Object? overdueServices = _undefined,
    Object? sourceItemId = _undefined,
    Object? sourceValueNumber = _undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PreDiveSessionItem(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      section: section == _undefined ? this.section : section as String?,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      itemType: itemType ?? this.itemType,
      valueLabel: valueLabel == _undefined
          ? this.valueLabel
          : valueLabel as String?,
      valueUnit: valueUnit == _undefined
          ? this.valueUnit
          : valueUnit as String?,
      valueMin: valueMin == _undefined ? this.valueMin : valueMin as double?,
      valueMax: valueMax == _undefined ? this.valueMax : valueMax as double?,
      isRequired: isRequired ?? this.isRequired,
      state: state ?? this.state,
      valueNumber: valueNumber == _undefined
          ? this.valueNumber
          : valueNumber as double?,
      valueText: valueText == _undefined
          ? this.valueText
          : valueText as String?,
      note: note ?? this.note,
      completedAt: completedAt == _undefined
          ? this.completedAt
          : completedAt as DateTime?,
      equipmentId: equipmentId == _undefined
          ? this.equipmentId
          : equipmentId as String?,
      overdueServices: overdueServices == _undefined
          ? this.overdueServices
          : overdueServices as List<OverdueServiceEntry>?,
      sourceItemId: sourceItemId == _undefined
          ? this.sourceItemId
          : sourceItemId as String?,
      sourceValueNumber: sourceValueNumber == _undefined
          ? this.sourceValueNumber
          : sourceValueNumber as double?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    sessionId,
    section,
    title,
    notes,
    sortOrder,
    itemType,
    valueLabel,
    valueUnit,
    valueMin,
    valueMax,
    isRequired,
    state,
    valueNumber,
    valueText,
    note,
    completedAt,
    equipmentId,
    overdueServices,
    sourceItemId,
    sourceValueNumber,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
