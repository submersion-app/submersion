import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The dive form's entry method, exit method, and link flag as one value, so
/// the flag can never drift out of step with the two methods it describes.
class EntryExitSelection {
  const EntryExitSelection({
    required this.entry,
    required this.exit,
    required this.linked,
  });

  final EntryMethod? entry;
  final EntryMethod? exit;

  /// True when exit is unset or equal to entry, matching the dive form's own
  /// definition of "the diver has not broken the mirror".
  final bool linked;
}

/// The dive's entry/exit selection after [site] is assigned to it.
///
/// Snap-on-assign, with three rules in priority order:
///
/// 1. A manual exit override is sticky. Once the diver has unlinked exit from
///    entry, no site value replaces it. The site knows the place; it does not
///    know how the diver got out that day.
/// 2. An explicit site exit method applies to a still-linked dive.
/// 3. A still-linked exit follows the new entry, but only when the entry
///    actually changed. Without that guard, clearing the site or assigning a
///    site with no entry method would write exit = entry and materialize an
///    exit method on a dive that had none.
EntryExitSelection entryExitAfterSiteAssign({
  required EntryMethod? currentEntry,
  required EntryMethod? currentExit,
  required bool currentLinked,
  required DiveSite? site,
}) {
  final entry = site?.entryMethod ?? currentEntry;
  final entryChanged = entry != currentEntry;

  final EntryMethod? exit;
  if (!currentLinked) {
    exit = currentExit;
  } else if (site?.exitMethod != null) {
    exit = site!.exitMethod;
  } else if (entryChanged) {
    exit = entry;
  } else {
    exit = currentExit;
  }

  return EntryExitSelection(
    entry: entry,
    exit: exit,
    linked: exit == null || exit == entry,
  );
}
