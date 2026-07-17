import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';

/// Pure rules for running a pre-dive checklist session. No I/O; the
/// repository enforces persistence-level immutability, this class answers
/// "what may the diver do right now".
class ChecklistSessionEngine {
  const ChecklistSessionEngine._();

  /// Items must be passed sorted by [PreDiveSessionItem.sortOrder].
  static PreDiveSessionItem? nextActionableItem(
    PreDiveSession session,
    List<PreDiveSessionItem> sortedItems,
  ) {
    if (session.isLocked) return null;
    for (final item in sortedItems) {
      if (item.state == PreDiveItemState.pending) return item;
    }
    return null;
  }

  static bool isItemActionable(
    PreDiveSession session,
    List<PreDiveSessionItem> sortedItems,
    PreDiveSessionItem item,
  ) {
    if (session.isLocked) return false;
    if (item.state != PreDiveItemState.pending) return false;
    if (!session.strictOrder) return true;
    return nextActionableItem(session, sortedItems)?.id == item.id;
  }

  /// Required items must end Done or Flagged. Optional items never block.
  static bool canComplete(List<PreDiveSessionItem> items) {
    return items.every(
      (i) =>
          !i.isRequired ||
          i.state == PreDiveItemState.done ||
          i.state == PreDiveItemState.flagged,
    );
  }

  static int flaggedCount(List<PreDiveSessionItem> items) =>
      items.where((i) => i.state == PreDiveItemState.flagged).length;

  static int resolvedCount(List<PreDiveSessionItem> items) =>
      items.where((i) => i.isResolved).length;
}
