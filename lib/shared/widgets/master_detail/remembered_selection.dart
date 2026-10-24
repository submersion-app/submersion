import 'package:submersion/core/providers/provider.dart';

/// The record a list should come back to, resolved against what it shows.
///
/// Each list remembers the record the diver last opened in its own
/// `highlighted<X>IdProvider`, which outlives the list page. Returning to the
/// list brings that record back into view, and on a wide window reopens it
/// in the details pane (#3301), but only while [items], the list as it is
/// currently filtered, still holds it. A record since deleted, hidden by the
/// filter, or from another diver's log resolves to null, so the list starts
/// at the top. The memory itself is left alone: relaxing the filter later
/// brings it back.
///
/// Loading while [items] load or reload, so a caller can wait rather than
/// settle on the top of a list that has not arrived yet, or match the rows a
/// reload is replacing. A failed load resolves to null.
AsyncValue<String?> rememberedListedId<T>({
  required AsyncValue<List<T>> items,
  required String? rememberedId,
  required String Function(T item) idOf,
}) {
  if (rememberedId == null) return const AsyncData(null);
  if (items.hasError) return const AsyncData(null);
  // A reload (a filter or diver change) still carries the rows it replaces;
  // only the rows it lands are the list the diver will see.
  if (items.isLoading) return const AsyncLoading();
  final list = items.value;
  if (list == null) return const AsyncLoading();
  return AsyncData(
    list.any((item) => idOf(item) == rememberedId) ? rememberedId : null,
  );
}

/// The section ids of the record lists that come back to the record last
/// opened (#3301): each list's `MasterDetailScaffold.sectionId`, and the
/// keys of [closedPaneRecordProvider]. Named once, so the scaffold, its table
/// and every place that clears a list's memory agree on the key.
abstract final class RecordListSection {
  static const dives = 'dives';
  static const sites = 'sites';
  static const equipment = 'equipment';
  static const buddies = 'buddies';
  static const trips = 'trips';
  static const diveCenters = 'dive-centers';
  static const certifications = 'certifications';
  static const courses = 'courses';
}

/// Per list section, the record the details pane showed when the diver
/// closed it.
///
/// Closing the pane leaves the list's highlight in place, so without this a
/// list returned to would reopen the pane the diver had shut on purpose. The
/// pane stays closed while the remembered record is still this one; opening
/// any record in the pane drops the entry (#3301). Keyed by the
/// `MasterDetailScaffold.sectionId`.
final closedPaneRecordProvider = StateProvider<Map<String, String>>(
  (ref) => const {},
);

/// Drops [sectionId]'s closed-pane entry because the diver opened a record
/// in that list, on any width: the pane is no longer one they emptied.
void forgetClosedPane(WidgetRef ref, String sectionId) {
  final closed = ref.read(closedPaneRecordProvider);
  if (!closed.containsKey(sectionId)) return;
  ref.read(closedPaneRecordProvider.notifier).state = {...closed}
    ..remove(sectionId);
}
