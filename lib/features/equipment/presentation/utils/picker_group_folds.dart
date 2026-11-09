// How equipment pickers fold their groups (issue #3364): the equipment
// picker, the add-component sheet and the equipment set editor. Unlike the
// Equipment list, a picker saves nothing: its folds last as long as the
// sheet or page is open.
//
// Type groups use `typeFoldKey` from `equipment_fold_keys.dart`; an owner's
// shared gear is an outer group, `owner:<diverId>`, with its types nested as
// `owner:<diverId>/type:<typeName>`.

/// The key of the group holding gear another profile shares with the diver.
String ownerFoldKey(String diverId) => 'owner:$diverId';

/// The groups a picker opens with, worked out once when it first has gear:
/// those holding a ticked id, so nothing ticked starts hidden, or every
/// group when there is only one group of gear, since folding it hides
/// everything.
///
/// [itemIdsByGroup] maps each group's key to the ids in it. [containers]
/// are groups that only hold other groups (an owner's shared gear), which
/// do not count when deciding whether there is only one.
Set<String> initialOpenPickerGroups(
  Map<String, Iterable<String>> itemIdsByGroup,
  Set<String> ticked, {
  Set<String> containers = const {},
}) {
  final leaves = itemIdsByGroup.keys.where((k) => !containers.contains(k));
  if (leaves.length == 1) return itemIdsByGroup.keys.toSet();
  return {
    for (final MapEntry(:key, :value) in itemIdsByGroup.entries)
      if (value.any(ticked.contains)) key,
  };
}

/// How many of [itemIds] are ticked.
int tickedIn(Iterable<String> itemIds, Set<String> ticked) =>
    itemIds.where(ticked.contains).length;
