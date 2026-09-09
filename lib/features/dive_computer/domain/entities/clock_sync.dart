import 'package:equatable/equatable.dart';

/// Per-computer choice for the clock sync after a download (issue #1216).
enum ClockSyncOverride { inherit, always, never }

/// What this installation has learned about a computer's model.
enum ClockSyncSupport { unknown, supported, unsupported }

/// Outcome of the clock sync reported on download completion.
enum ClockSyncStatus {
  notRequested,
  synced,
  unsupported,
  failed;

  /// Parses the wire name from the native layer. Null (an older binding that
  /// set nothing) and any unknown name read as [notRequested], so the UI
  /// shows nothing rather than a wrong line.
  static ClockSyncStatus fromWireName(String? name) {
    return switch (name) {
      'synced' => ClockSyncStatus.synced,
      'unsupported' => ClockSyncStatus.unsupported,
      'failed' => ClockSyncStatus.failed,
      _ => ClockSyncStatus.notRequested,
    };
  }
}

/// Installation-local clock sync settings: a global switch, per-computer
/// overrides, and what each computer answered last time.
///
/// Immutable; every setter returns a new value. Maps only hold explicit
/// entries: an absent override means [ClockSyncOverride.inherit] and an
/// absent support entry means [ClockSyncSupport.unknown].
class ClockSyncSettings extends Equatable {
  final bool globalEnabled;
  final Map<String, ClockSyncOverride> overrides;
  final Map<String, ClockSyncSupport> support;

  const ClockSyncSettings({
    this.globalEnabled = false,
    this.overrides = const {},
    this.support = const {},
  });

  ClockSyncOverride overrideFor(String computerId) =>
      overrides[computerId] ?? ClockSyncOverride.inherit;

  ClockSyncSupport supportFor(String computerId) =>
      support[computerId] ?? ClockSyncSupport.unknown;

  /// Whether a download of [computerId] should sync the clock. A device that
  /// is not saved yet (null id) follows the global switch alone. A recorded
  /// unsupported model does not change the answer: the flag is still sent and
  /// the device answers unsupported again, which keeps "Check again" simple.
  bool resolve(String? computerId) {
    if (computerId == null) return globalEnabled;
    return switch (overrideFor(computerId)) {
      ClockSyncOverride.always => true,
      ClockSyncOverride.never => false,
      ClockSyncOverride.inherit => globalEnabled,
    };
  }

  ClockSyncSettings withGlobalEnabled(bool value) => ClockSyncSettings(
    globalEnabled: value,
    overrides: overrides,
    support: support,
  );

  ClockSyncSettings withOverride(String computerId, ClockSyncOverride value) {
    final next = Map<String, ClockSyncOverride>.from(overrides);
    if (value == ClockSyncOverride.inherit) {
      next.remove(computerId);
    } else {
      next[computerId] = value;
    }
    return ClockSyncSettings(
      globalEnabled: globalEnabled,
      overrides: Map.unmodifiable(next),
      support: support,
    );
  }

  ClockSyncSettings withSupport(String computerId, ClockSyncSupport value) {
    final next = Map<String, ClockSyncSupport>.from(support);
    if (value == ClockSyncSupport.unknown) {
      next.remove(computerId);
    } else {
      next[computerId] = value;
    }
    return ClockSyncSettings(
      globalEnabled: globalEnabled,
      overrides: overrides,
      support: Map.unmodifiable(next),
    );
  }

  /// Learns support from a completion status. Only a definite answer counts:
  /// a failed sync says nothing about the model, and returns this instance
  /// unchanged so callers can skip the write.
  ClockSyncSettings withSupportFromStatus(
    String computerId,
    ClockSyncStatus status,
  ) {
    return switch (status) {
      ClockSyncStatus.synced => withSupport(
        computerId,
        ClockSyncSupport.supported,
      ),
      ClockSyncStatus.unsupported => withSupport(
        computerId,
        ClockSyncSupport.unsupported,
      ),
      ClockSyncStatus.failed || ClockSyncStatus.notRequested => this,
    };
  }

  /// Drops every entry for [computerId], for when it is deleted.
  ClockSyncSettings without(String computerId) => withOverride(
    computerId,
    ClockSyncOverride.inherit,
  ).withSupport(computerId, ClockSyncSupport.unknown);

  @override
  List<Object?> get props => [globalEnabled, overrides, support];
}
