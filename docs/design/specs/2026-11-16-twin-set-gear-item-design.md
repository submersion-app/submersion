# A tank gear item worn as a twin set (issue #4641)

Status: approved 2026-11-16. Target release: v1.8.5.

## Intent

Many divers keep manifolded doubles as one gear item (for example "D12")
and never track the two cylinders on their own. Since v1.8.4 a dive tank can
carry the Twin Set role (#3374), and #4242 lets two separate cylinders be
linked as a twin set. What is missing is a way to say, once, on the gear item
itself, that this item is a twin set, so that:

- its Equipment list icon is the twin set icon (`SubmersionIcons.tankTwinSet`),
- an Equipment Set's diver figure draws it as doubles,
- picking it for a dive sets that dive tank's role to Twin Set.

This reverses the "A twin set equipment item" non-goal of the #4242 spec
(`2026-11-06-twin-set-cylinder-link-design.md`), which was scoped to #4242.

## Goals

- Mark a tank item as a twin set from its edit form.
- The icon, the Equipment Set figure and the role picked for a new dive all
  follow from that mark.

## Non-goals

- Rewriting existing dives. The Insights "Mark as twin sets" review already
  finds older twin set dives by volume.
- Changing tank configuration classification. It keeps reading dive tank
  roles only (`backmountRoles`), never names, sizes or gear marks.

## Anti-goals

- A mark that silently overrides a role the diver chose on a dive.
- Two fields that can disagree about how a tank is carried.

## Approaches considered

1. **A Twin set choice in the existing Worn as field (chosen).** Worn as
   (#4493) already says where a cylinder is carried and already feeds the
   figure. Twin set implies back mount, so one field cannot contradict
   itself. Stored in the attribute rows that already sync: no schema change.
2. **A separate Twin set flag.** Easy to spot, but Worn as Sidemount plus
   Twin set on is a nonsense combination that needs a precedence rule.
3. **A default dive role on the item.** Most general, but it overlaps Worn
   as and Cylinder use (#4243), so three fields could disagree.

Eric picked approach 1.

## Design

1. **Data.** A new choice key `twin_set` on `worn_as`
   (`EquipmentAttrKeys.wornAs`), listed after `back`. The item keeps the
   pair's combined volume (24 L for a D12), matching how a Twin Set dive
   tank is logged today. `EquipmentItem.isWornAsTwinSet` reads it.
2. **Icon.** `equipmentItemIcon(item)` returns `SubmersionIcons.tankTwinSet`
   for a tank worn as a twin set and `equipmentTypeIcon(item.type)`
   otherwise. Every place that shows one specific item uses it (Equipment
   list and avatar, detail header, Equipment Set rows, gear pickers, the
   dive gear tree, trip packing, the figure's tray). Places that show a type
   (filters, type pickers) keep the type icon.
3. **Figure.** `wornAsZones('twin_set')` is the back tank zone. In
   `_mergeDoubles`, a single back tank draws the doubles piece when its dive
   role is Twin Set, or when it has no dive role and is worn as a twin set.
   This covers Equipment Set figures and dives whose tank is not linked to
   the item.
4. **Picking it for a dive.** The tank editor sets the tank's role to Twin
   Set when the picked item is worn as a twin set, exactly as Suit inflation
   does: a default for the pick, leaving a tank already in that role alone
   and rewriting no other dive. The transmitter editor does the same when no
   role was chosen by hand.
5. **A cylinder linked in a #4242 pair.** When the picked item is paired on
   the dive's date, the existing "twin set or this cylinder?" question
   decides; choosing the cylinder alone is Back Gas even if the item is worn
   as a twin set, since the pairing is the more specific record.
6. **Making a cylinder from a dive tank.** "Make a cylinder from this tank"
   on a Twin Set dive tank creates the item already worn as a twin set,
   mirroring Suit inflation.
7. **The cylinder pairing card.** A tank's detail page hides the "Twin set"
   pairing card (#4242) while the item is worn as a twin set and has no
   pairing: an item that already is the doubles is not paired with another
   cylinder. A pairing it already has, open or past, still shows (Eric,
   2026-11-16).

## Left to the builder

- Exact wording of the new choice label ("Twin set") and its translations.
- Test layout, following the existing worn_as and suit inflation tests.
