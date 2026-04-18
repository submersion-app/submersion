import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Represents an event marker on a dive profile.
///
/// Events can be auto-detected (safety stops, ascent rate violations)
/// or user-marked (bookmarks, notes).
class ProfileEvent extends Equatable {
  /// Unique identifier
  final String id;

  /// Dive this event belongs to
  final String diveId;

  /// Timestamp in seconds from dive start
  final int timestamp;

  /// Type of event
  final ProfileEventType eventType;

  /// Severity level
  final EventSeverity severity;

  /// Optional description or notes
  final String? description;

  /// Depth at which event occurred (meters)
  final double? depth;

  /// Associated value (e.g., ascent rate, ppO2 value)
  final double? value;

  /// Associated tank ID (for gas switches)
  final String? tankId;

  /// Provenance of this event (imported, computed, or user-authored).
  final EventSource source;

  /// When this event was created
  final DateTime createdAt;

  const ProfileEvent({
    required this.id,
    required this.diveId,
    required this.timestamp,
    required this.eventType,
    this.severity = EventSeverity.info,
    this.description,
    this.depth,
    this.value,
    this.tankId,
    // Default intentionally biased toward `imported` — the most common case
    // for direct-constructor callers is DB read-back, where the value is
    // being reconstituted from a persisted row. Callers that construct
    // events from in-app analysis MUST explicitly pass
    // `source: EventSource.computed`; user-authored events MUST pass
    // `source: EventSource.user`. Factories enforce the correct default per
    // event type — prefer factories over direct construction.
    this.source = EventSource.imported,
    required this.createdAt,
  });

  /// Timestamp formatted as MM:SS
  String get timestampFormatted {
    final minutes = timestamp ~/ 60;
    final seconds = timestamp % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get display name for this event
  String get displayName => eventType.displayName;

  /// Get icon name for this event type
  String get iconName => eventType.iconName;

  /// Whether this is a warning-level event
  bool get isWarning => severity == EventSeverity.warning;

  /// Whether this is an alert-level event
  bool get isAlert => severity == EventSeverity.alert;

  /// Whether this event has associated data value
  bool get hasValue => value != null;

  /// Get formatted value with appropriate units based on event type
  String? get formattedValue {
    if (value == null) return null;

    switch (eventType) {
      case ProfileEventType.ascentRateWarning:
      case ProfileEventType.ascentRateCritical:
        return '${value!.toStringAsFixed(1)} m/min';
      case ProfileEventType.ppO2High:
      case ProfileEventType.ppO2Low:
        return '${value!.toStringAsFixed(2)} bar';
      case ProfileEventType.cnsWarning:
      case ProfileEventType.cnsCritical:
        return '${value!.toStringAsFixed(0)}%';
      case ProfileEventType.setpointChange:
        return '${value!.toStringAsFixed(1)} bar';
      default:
        return value!.toStringAsFixed(1);
    }
  }

  /// Create an ascent start event
  factory ProfileEvent.ascentStart({
    required String id,
    required String diveId,
    required int timestamp,
    double? depth,
    required DateTime createdAt,
    EventSource source = EventSource.computed,
  }) {
    return ProfileEvent(
      id: id,
      diveId: diveId,
      timestamp: timestamp,
      eventType: ProfileEventType.ascentStart,
      depth: depth,
      createdAt: createdAt,
      source: source,
    );
  }

  /// Create a safety stop event
  factory ProfileEvent.safetyStop({
    required String id,
    required String diveId,
    required int timestamp,
    required double depth,
    required DateTime createdAt,
    bool isStart = true,
    EventSource source = EventSource.computed,
  }) {
    return ProfileEvent(
      id: id,
      diveId: diveId,
      timestamp: timestamp,
      eventType: isStart
          ? ProfileEventType.safetyStopStart
          : ProfileEventType.safetyStopEnd,
      depth: depth,
      createdAt: createdAt,
      source: source,
    );
  }

  /// Create a max depth event
  factory ProfileEvent.maxDepth({
    required String id,
    required String diveId,
    required int timestamp,
    required double depth,
    required DateTime createdAt,
    EventSource source = EventSource.computed,
  }) {
    return ProfileEvent(
      id: id,
      diveId: diveId,
      timestamp: timestamp,
      eventType: ProfileEventType.maxDepth,
      depth: depth,
      createdAt: createdAt,
      source: source,
    );
  }

  /// Create an ascent rate warning event
  factory ProfileEvent.ascentRateWarning({
    required String id,
    required String diveId,
    required int timestamp,
    required double depth,
    required double rate,
    required DateTime createdAt,
    bool isCritical = false,
    EventSource source = EventSource.computed,
  }) {
    return ProfileEvent(
      id: id,
      diveId: diveId,
      timestamp: timestamp,
      eventType: isCritical
          ? ProfileEventType.ascentRateCritical
          : ProfileEventType.ascentRateWarning,
      severity: isCritical ? EventSeverity.alert : EventSeverity.warning,
      depth: depth,
      value: rate,
      createdAt: createdAt,
      source: source,
    );
  }

  /// Create a gas switch event
  factory ProfileEvent.gasSwitch({
    required String id,
    required String diveId,
    required int timestamp,
    required double depth,
    required String tankId,
    String? gasName,
    required DateTime createdAt,
    EventSource source = EventSource.imported,
  }) {
    return ProfileEvent(
      id: id,
      diveId: diveId,
      timestamp: timestamp,
      eventType: ProfileEventType.gasSwitch,
      depth: depth,
      tankId: tankId,
      description: gasName,
      createdAt: createdAt,
      source: source,
    );
  }

  /// Create a bookmark event
  factory ProfileEvent.bookmark({
    required String id,
    required String diveId,
    required int timestamp,
    double? depth,
    String? note,
    required DateTime createdAt,
    EventSource source = EventSource.user,
  }) {
    return ProfileEvent(
      id: id,
      diveId: diveId,
      timestamp: timestamp,
      eventType: ProfileEventType.bookmark,
      depth: depth,
      description: note,
      createdAt: createdAt,
      source: source,
    );
  }

  /// Create a setpoint change event (CCR dives)
  factory ProfileEvent.setpointChange({
    required String id,
    required String diveId,
    required int timestamp,
    required double setpoint,
    double? depth,
    required DateTime createdAt,
    EventSource source = EventSource.imported,
  }) {
    return ProfileEvent(
      id: id,
      diveId: diveId,
      timestamp: timestamp,
      eventType: ProfileEventType.setpointChange,
      value: setpoint,
      depth: depth,
      createdAt: createdAt,
      source: source,
    );
  }

  /// Create a deco stop event (CCR/technical dives).
  factory ProfileEvent.decoStop({
    required String id,
    required String diveId,
    required int timestamp,
    required double depth,
    required DateTime createdAt,
    bool isStart = true,
    EventSource source = EventSource.imported,
  }) {
    return ProfileEvent(
      id: id,
      diveId: diveId,
      timestamp: timestamp,
      eventType: isStart
          ? ProfileEventType.decoStopStart
          : ProfileEventType.decoStopEnd,
      depth: depth,
      createdAt: createdAt,
      source: source,
    );
  }

  /// Create a deco violation event (ceiling exceeded, generic violation).
  factory ProfileEvent.decoViolation({
    required String id,
    required String diveId,
    required int timestamp,
    double? depth,
    double? value,
    String? description,
    required DateTime createdAt,
    EventSource source = EventSource.imported,
  }) {
    return ProfileEvent(
      id: id,
      diveId: diveId,
      timestamp: timestamp,
      eventType: ProfileEventType.decoViolation,
      severity: EventSeverity.alert,
      depth: depth,
      value: value,
      description: description,
      createdAt: createdAt,
      source: source,
    );
  }

  /// Create a high ppO2 warning event.
  factory ProfileEvent.ppO2High({
    required String id,
    required String diveId,
    required int timestamp,
    required double value,
    double? depth,
    required DateTime createdAt,
    EventSource source = EventSource.imported,
  }) {
    return ProfileEvent(
      id: id,
      diveId: diveId,
      timestamp: timestamp,
      eventType: ProfileEventType.ppO2High,
      severity: EventSeverity.warning,
      value: value,
      depth: depth,
      createdAt: createdAt,
      source: source,
    );
  }

  /// Create a low ppO2 warning event (hypoxia risk, typically CCR).
  factory ProfileEvent.ppO2Low({
    required String id,
    required String diveId,
    required int timestamp,
    required double value,
    double? depth,
    required DateTime createdAt,
    EventSource source = EventSource.imported,
  }) {
    return ProfileEvent(
      id: id,
      diveId: diveId,
      timestamp: timestamp,
      eventType: ProfileEventType.ppO2Low,
      severity: EventSeverity.warning,
      value: value,
      depth: depth,
      createdAt: createdAt,
      source: source,
    );
  }

  ProfileEvent copyWith({
    String? id,
    String? diveId,
    int? timestamp,
    ProfileEventType? eventType,
    EventSeverity? severity,
    String? description,
    double? depth,
    double? value,
    String? tankId,
    EventSource? source,
    DateTime? createdAt,
  }) {
    return ProfileEvent(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      timestamp: timestamp ?? this.timestamp,
      eventType: eventType ?? this.eventType,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      depth: depth ?? this.depth,
      value: value ?? this.value,
      tankId: tankId ?? this.tankId,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    timestamp,
    eventType,
    severity,
    description,
    depth,
    value,
    tankId,
    source,
    createdAt,
  ];
}
