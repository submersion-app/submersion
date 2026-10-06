# Equipment Sets Visibility Design

## Problem

Equipment Sets are currently buried two navigation levels deep (Equipment page > folder icon > Sets list). Most users never discover they exist. The goal is to surface Equipment Sets as a first-class feature alongside individual equipment items.

## Decision: TabBar at AppBar Bottom

Add a Material 3 TabBar to the Equipment page AppBar with two tabs: "Equipment" and "Sets". This matches the existing pattern used in gas_calculators_page.dart and makes Sets immediately discoverable.

### Rejected Alternatives

- **SegmentedButton toggle**: Less standard for content-type switching; better suited for modes/filters
- **Two-section scrollable list**: Gets crowded with many sets; harder to manage CRUD inline

## Design

### Page Structure

The EquipmentListPage becomes a tabbed container page hosting two child views:

- **Tab 1 (Equipment)**: Existing EquipmentListContent widget (filters, sort, search, equipment list) -- unchanged
- **Tab 2 (Sets)**: New EquipmentSetListContent widget extracted from EquipmentSetListPage

```text
Mobile Layout:
+------------------------------+
| AppBar: "Equipment"          |
|                 [Sort][Search]|
| +------------+-----------+   |
| | Equipment  |   Sets    |   | <- TabBar
| +------------+-----------+   |
+------------------------------+
|                              |
|  [Active tab content]        |
|                              |
|                        [FAB] | <- Context-aware
+------------------------------+
```

### Context-Aware FAB

- Equipment tab: FAB shows "Add Equipment" and opens the add equipment sheet
- Sets tab: FAB shows "Add Set" and navigates to the set creation page

### AppBar Actions

- Remove the folder icon button (no longer needed since Sets is a tab)
- Sort and Search actions remain on Equipment tab only
- Sets tab manages its own actions if needed

### Master-Detail (Tablet/Desktop)

Full master-detail support for both tabs:

- Equipment tab: Equipment list in master pane, equipment detail in detail pane (unchanged from today)
- Sets tab: Equipment sets list in master pane, set detail in detail pane

Tab switching changes both the master list content and the detail pane builders. The TabBar appears in the master panel header area.

### Routing

- `/equipment` -- Equipment page, defaults to Equipment tab (index 0)
- `/equipment?tab=sets` -- Equipment page, opens to Sets tab (index 1)
- `/equipment/:equipmentId` -- Equipment detail (unchanged)
- `/equipment/:equipmentId/edit` -- Equipment edit (unchanged)
- `/equipment/sets` -- Redirects to `/equipment?tab=sets` (backwards compat)
- `/equipment/sets/new` -- Create new set (unchanged)
- `/equipment/sets/:setId` -- Set detail (unchanged)
- `/equipment/sets/:setId/edit` -- Edit set (unchanged)

Tab state is managed by TabController in the widget, not by routing.

### Widget Extraction

Extract EquipmentSetListContent from EquipmentSetListPage, mirroring the existing pattern where EquipmentListContent is extracted from EquipmentListPage. This allows embedding the set list content in both the tab view and the master-detail master pane.

## Scope

### In Scope

- Add TabBar with "Equipment" and "Sets" tabs to Equipment page
- Context-aware FAB based on active tab
- Remove folder icon button from AppBar actions
- Full master-detail support for Sets tab on tablet/desktop
- Extract EquipmentSetListContent widget from EquipmentSetListPage

### Out of Scope

- Equipment Set entity, repository, or providers (no changes)
- Set detail page, set edit page (no changes)
- Dive edit page "Apply Set" integration (unchanged)
- Equipment list content, filters, sort, search (unchanged)
- No new features -- this is purely repositioning existing UI

## Technical Notes

- Convert EquipmentListPage from ConsumerWidget to ConsumerStatefulWidget with SingleTickerProviderStateMixin (required for TabController)
- Follow existing TabBar pattern from GasCalculatorsPage
- TabBar should use isScrollable: false since there are only 2 tabs
- Tab icons: backpack for Equipment, folder_special for Sets
