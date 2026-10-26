import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_slots.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

String diveScrubberValue(
  DiveScrubberEntry e,
  DiveSortField field, {
  required UnitFormatter units,
  required AppLocalizations l10n,
}) {
  switch (field) {
    case DiveSortField.date:
      return units.formatMonthYear(e.dateTime);
    case DiveSortField.diveNumber:
      return e.diveNumber == null ? '--' : '#${e.diveNumber}';
    case DiveSortField.site:
      return e.siteName ?? l10n.diveLog_listPage_unknownSite;
    case DiveSortField.depth:
      return units.formatDepth(e.maxDepth, decimals: 0);
    case DiveSortField.bottomTime:
      final time = e.bottomTime;
      return time == null ? '--' : l10n.common_elapsed_minutes(time.inMinutes);
    case DiveSortField.rating:
      return _ratingLabel(e.rating, l10n);
  }
}

String _ratingLabel(int? rating, AppLocalizations l10n) =>
    (rating ?? 0) == 0 ? l10n.diveLog_scrubber_unrated : '$rating★';

/// [repeat], when set, labels the bucket's later runs: a month marker
/// carries its year only the first time.
typedef _Bucket = ({Object key, String label, String? repeat});

/// A marker per bucket of the active sort, at the bucket's first slot when
/// ascending and its last slot when descending, so each marks a boundary.
List<ScrubberMarker> diveScrubberMarkers(
  List<DiveScrubberSlot> slots,
  DiveSortField field, {
  required SortDirection direction,
  required UnitFormatter units,
  required AppLocalizations l10n,
}) {
  if (slots.isEmpty) return const [];
  final entries = [for (final s in slots) s.entry];
  final bucketOf = _bucketer(entries, field, units, l10n);
  final atEnd = direction == SortDirection.descending;
  final markers = <ScrubberMarker>[];
  final emitted = <Object>{};
  _Bucket? run;
  var runStart = 0;
  var runEnd = 0;
  void close() {
    if (run == null) return;
    final first = emitted.add(run.key);
    markers.add(
      ScrubberMarker(
        slot: atEnd ? runEnd : runStart,
        label: first ? run.label : run.repeat ?? run.label,
      ),
    );
  }

  for (var i = 0; i < entries.length; i++) {
    final bucket = bucketOf(entries[i]);
    if (bucket == null) continue;
    if (bucket.key != run?.key) {
      close();
      run = bucket;
      runStart = i;
    }
    runEnd = i;
  }
  close();
  return markers;
}

_Bucket? Function(DiveScrubberEntry) _bucketer(
  List<DiveScrubberEntry> entries,
  DiveSortField field,
  UnitFormatter units,
  AppLocalizations l10n,
) {
  switch (field) {
    case DiveSortField.date:
      final years = entries.map((e) => e.dateTime.year);
      final span = years.reduce(math.max) - years.reduce(math.min);
      if (span <= 1) {
        final earliestMonth = <int, int>{};
        for (final e in entries) {
          final d = e.dateTime;
          final seen = earliestMonth[d.year];
          if (seen == null || d.month < seen) earliestMonth[d.year] = d.month;
        }
        // Formatted once per month: every entry asks, but a month's labels
        // are the same for all of its dives.
        final byMonth = <int, _Bucket>{};
        return (e) {
          final d = e.dateTime;
          final key = d.year * 12 + d.month;
          return byMonth.putIfAbsent(key, () {
            final month = units.formatMonthOnly(d);
            return (
              key: key,
              label: earliestMonth[d.year] == d.month
                  ? units.formatMonthYear(d)
                  : month,
              repeat: month,
            );
          });
        };
      }
      return (e) =>
          (key: e.dateTime.year, label: '${e.dateTime.year}', repeat: null);
    case DiveSortField.diveNumber:
      final step = _diveNumberStep(entries);
      return (e) => _stepBucket(e.diveNumber?.toDouble(), step, (v) => '$v');
    case DiveSortField.site:
      return (e) {
        final letter = _siteLetter(e);
        if (letter == null) return null;
        return (key: letter, label: letter, repeat: null);
      };
    case DiveSortField.depth:
      final depth = _depthIn(units);
      final step = _depthStep(entries, units);
      return (e) =>
          _stepBucket(depth(e), step, (v) => '$v${units.depthSymbol}');
    case DiveSortField.bottomTime:
      final step = _stepFor(entries.map(_minutes), const [
        (60, 10),
        (120, 15),
      ], 30);
      return (e) => _stepBucket(_minutes(e), step, l10n.common_elapsed_minutes);
    case DiveSortField.rating:
      return (e) => (
        key: e.rating ?? 0,
        label: _ratingLabel(e.rating, l10n),
        repeat: null,
      );
  }
}

int _stepFor(
  Iterable<double?> values,
  List<(num, int)> rangeSteps,
  int fallback,
) {
  final present = values.whereType<double>();
  if (present.isEmpty) return fallback;
  final range = present.reduce(math.max) - present.reduce(math.min);
  for (final (limit, step) in rangeSteps) {
    if (range <= limit) return step;
  }
  return fallback;
}

_Bucket? _stepBucket(double? value, int step, String Function(int) label) {
  if (value == null) return null;
  final bucket = (value / step).floor();
  return (key: bucket, label: label(bucket * step), repeat: null);
}

int _diveNumberStep(List<DiveScrubberEntry> entries) => _stepFor(
  entries.map((e) => e.diveNumber?.toDouble()),
  const [(100, 10), (500, 50), (5000, 100)],
  500,
);

/// Folds ASCII letters only, the way the site sort's `COLLATE NOCASE` does.
/// The sort orders the name as stored, so a name starting with whitespace
/// gets no letter rather than one far from where it sorts.
String? _siteLetter(DiveScrubberEntry e) {
  final name = e.siteName;
  if (name == null || name.isEmpty) return null;
  final first = name.characters.first;
  if (first.trim().isEmpty) return null;
  final unit = first.codeUnitAt(0);
  final asciiLower = first.length == 1 && unit >= 0x61 && unit <= 0x7A;
  return asciiLower ? first.toUpperCase() : first;
}

double? Function(DiveScrubberEntry) _depthIn(UnitFormatter units) => (e) {
  final depth = e.maxDepth;
  return depth == null ? null : units.convertDepth(depth);
};

int _depthStep(List<DiveScrubberEntry> entries, UnitFormatter units) {
  final feet = units.settings.depthUnit == DepthUnit.feet;
  return _stepFor(
    entries.map(_depthIn(units)),
    feet ? const [(60, 10), (200, 20)] : const [(40, 5)],
    feet ? 50 : 10,
  );
}

double? _minutes(DiveScrubberEntry e) => e.bottomTime?.inMinutes.toDouble();
