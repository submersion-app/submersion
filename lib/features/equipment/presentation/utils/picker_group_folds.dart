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
/// group when there is only one, since folding the only group hides
/// everything.
///
/// [itemIdsByGroup] maps each group's key to the ids in it.
Set<String> initialOpenPickerGroups(
  Map<String, Iterable<String>> itemIdsByGroup,
  Set<String> ticked,
) {
  if (itemIdsByGroup.length == 1) return {itemIdsByGroup.keys.single};
  return {
    for (final MapEntry(:key, :value) in itemIdsByGroup.entries)
      if (value.any(ticked.contains)) key,
  };
}

/// How many of [itemIds] are ticked.
int tickedIn(Iterable<String> itemIds, Set<String> ticked) =>
    itemIds.where(ticked.contains).length;
