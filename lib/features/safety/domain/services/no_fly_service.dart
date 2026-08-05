/// Conservatism preset for the flying-after-diving countdown.
enum NoFlyPreset {
  standard,
  strict;

  String get dbValue => name;

  static NoFlyPreset fromDbValue(String? value) {
    for (final preset in NoFlyPreset.values) {
      if (preset.name == value) return preset;
    }
    return NoFlyPreset.standard;
  }
}

/// DAN/UHMS guideline category for the trailing dive window.
enum NoFlyCategory { single, repetitive, deco }

/// Minimal dive facts the classifier needs.
class NoFlyDiveInput {
  final DateTime endTime;
  final bool hadDecoObligation;

  const NoFlyDiveInput({
    required this.endTime,
    required this.hadDecoObligation,
  });
}

/// An active flying restriction.
class NoFlyStatus {
  final DateTime until;
  final NoFlyCategory category;

  /// The guideline interval that produced [until] (preset-scaled).
  final Duration interval;

  const NoFlyStatus({
    required this.until,
    required this.category,
    required this.interval,
  });

  Duration remaining(DateTime now) =>
      until.isAfter(now) ? until.difference(now) : Duration.zero;

  /// Whether the restriction is still in effect at [now]. A [NoFlyStatus] is a
  /// snapshot: once computed it can be cached past its deadline (e.g. on the
  /// dashboard), so consumers must re-check against the clock rather than
  /// treating a non-null status as active.
  bool isActiveAt(DateTime now) => until.isAfter(now);
}

/// Classifies the trailing dive window per DAN/UHMS flying-after-diving
/// guidance and computes the countdown anchor. The fixed guideline intervals
/// are authoritative here by design -- no agency endorses computed
/// (tissue-model) no-fly times, so the Buhlmann engine is never consulted.
class NoFlyService {
  /// How far back to look for dives that still influence the restriction.
  /// 48 h covers the longest (strict deco) interval.
  static const Duration lookback = Duration(hours: 48);

  const NoFlyService();

  /// Returns the active restriction, or null when there is none (no recent
  /// dives, or the interval has already elapsed).
  NoFlyStatus? evaluate({
    required List<NoFlyDiveInput> dives,
    required NoFlyPreset preset,
    required DateTime now,
  }) {
    final windowStart = now.subtract(lookback);
    final recent = dives
        .where((d) => d.endTime.isAfter(windowStart) && !d.endTime.isAfter(now))
        .toList();
    if (recent.isEmpty) return null;

    final category = recent.any((d) => d.hadDecoObligation)
        ? NoFlyCategory.deco
        : recent.length > 1
        ? NoFlyCategory.repetitive
        : NoFlyCategory.single;

    final lastEnd = recent
        .map((d) => d.endTime)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    final interval = switch ((preset, category)) {
      (NoFlyPreset.standard, NoFlyCategory.single) => const Duration(hours: 12),
      (NoFlyPreset.standard, NoFlyCategory.repetitive) => const Duration(
        hours: 18,
      ),
      (NoFlyPreset.standard, NoFlyCategory.deco) => const Duration(hours: 24),
      (NoFlyPreset.strict, NoFlyCategory.single) => const Duration(hours: 18),
      (NoFlyPreset.strict, NoFlyCategory.repetitive) => const Duration(
        hours: 24,
      ),
      (NoFlyPreset.strict, NoFlyCategory.deco) => const Duration(hours: 48),
    };

    final until = lastEnd.add(interval);
    if (!until.isAfter(now)) return null;
    return NoFlyStatus(until: until, category: category, interval: interval);
  }
}
