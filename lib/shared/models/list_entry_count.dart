import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/models/subtitle_text.dart';

/// How many entries a list shows, against how many it holds with no filter.
///
/// Rendered under a list's title as "812 dives", or "34 of 812 dives" while a
/// filter is active. A filter matching every entry still reads "812 of 812",
/// so the diver can tell the list is narrowed.
class ListEntryCount {
  /// A list with no active filter: it shows every entry it holds.
  const ListEntryCount.unfiltered(int count)
    : shown = count,
      total = count,
      isFiltered = false;

  /// A list narrowed by a filter to [shown] of its [total] entries.
  const ListEntryCount.filtered({required this.shown, required this.total})
    : isFiltered = true;

  final int shown;

  /// The entries the list shows with its default, empty filter.
  final int total;

  final bool isFiltered;

  /// The subtitle text. Takes the feature's pre-localized builders, since
  /// each list names its own entities ("dives", "sites", ...).
  String label({
    required String Function(int count) all,
    required String Function(int shown, int total) filtered,
  }) => isFiltered ? filtered(shown, total) : all(shown);

  /// [label] as a header subtitle, with a compact form for narrow headers:
  /// [compactFiltered] ("34 of 812") while filtered, else the bare count.
  SubtitleText subtitle({
    required String Function(int count) all,
    required String Function(int shown, int total) filtered,
    required String Function(int shown, int total) compactFiltered,
  }) => SubtitleText(
    label(all: all, filtered: filtered),
    compact: isFiltered ? compactFiltered(shown, total) : '$shown',
  );

  @override
  bool operator ==(Object other) =>
      other is ListEntryCount &&
      other.shown == shown &&
      other.total == total &&
      other.isFiltered == isFiltered;

  @override
  int get hashCode => Object.hash(shown, total, isFiltered);

  @override
  String toString() =>
      'ListEntryCount(shown: $shown, total: $total, filtered: $isFiltered)';
}

/// The count for a list whose visible entries are [shown], or null until
/// they (and, while [isFiltered], the unfiltered [total]) have loaded.
///
/// [total] is only called while a filter is active, so a provider passing
/// `() => ref.watch(...)` subscribes to the unfiltered list, and runs its
/// query, only when there is a filter to compare against.
ListEntryCount? listEntryCount<T>({
  required AsyncValue<List<T>> shown,
  required bool isFiltered,
  required AsyncValue<List<T>> Function() total,
}) {
  final shownList = shown.value;
  if (shownList == null) return null;
  if (!isFiltered) return ListEntryCount.unfiltered(shownList.length);
  final totalList = total().value;
  if (totalList == null) return null;
  return ListEntryCount.filtered(
    shown: shownList.length,
    total: totalList.length,
  );
}
