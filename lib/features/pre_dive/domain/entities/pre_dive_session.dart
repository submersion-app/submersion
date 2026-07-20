import 'package:equatable/equatable.dart';

import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';

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
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isResolved => state != PreDiveItemState.pending;

  /// Advisory range warning for recorded values (never blocking).
  bool get valueOutOfRange {
    final v = valueNumber;
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
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
