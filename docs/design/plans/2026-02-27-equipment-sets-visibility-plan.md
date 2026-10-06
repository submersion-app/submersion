# Equipment Sets Visibility Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Surface Equipment Sets as a TabBar tab on the Equipment page so users can discover them without navigating to a hidden sub-route.

**Architecture:** Convert `EquipmentListPage` from a single-view `ConsumerWidget` into a tabbed `ConsumerStatefulWidget` with `TabController`. Extract `EquipmentSetListContent` from `EquipmentSetListPage` (mirroring the existing `EquipmentListContent` extraction pattern). Wire both tabs into master-detail on desktop.

**Tech Stack:** Flutter, Material 3 TabBar, Riverpod, go_router, MasterDetailScaffold

---

## Task 1: Add Localization Strings

**Files:**

- Modify: `lib/l10n/arb/app_en.arb` (add new keys near existing `equipment_` keys)

**Step 1: Add new l10n keys to app_en.arb**

Add these keys alphabetically within the `equipment_` section (near line 3753):

```json
"equipment_tab_equipment": "Equipment",
"equipment_tab_sets": "Sets",
"equipment_fab_addSet": "Add Set",
```text
**Step 2: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Build completes, generated `app_localizations_*.dart` files updated.

**Step 3: Verify the keys compile**

Run: `flutter analyze lib/l10n/`
Expected: No errors.

**Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat: add l10n keys for equipment tab bar"
```text
---

## Task 2: Extract EquipmentSetListContent Widget

Extract the list/empty/error content from `EquipmentSetListPage` into a reusable `EquipmentSetListContent` widget (exactly as `EquipmentListContent` was extracted from `EquipmentListPage`).

**Files:**

- Create: `lib/features/equipment/presentation/widgets/equipment_set_list_content.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_set_list_page.dart`

**Step 1: Create `equipment_set_list_content.dart`**

This widget contains the list body, empty state, and error state from `EquipmentSetListPage`, but without the `Scaffold`/`AppBar`/`FAB`. It accepts optional callbacks for master-detail integration.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';

/// Content widget for the equipment set list, used in tabbed and master-detail layouts.
class EquipmentSetListContent extends ConsumerWidget {
  final void Function(String?)? onItemSelected;
  final String? selectedId;
  final bool showAppBar;

  const EquipmentSetListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(equipmentSetListNotifierProvider);

    final content = setsAsync.when(
      data: (sets) => sets.isEmpty
          ? _buildEmptyState(context)
          : _buildSetsList(context, sets),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(context, ref, error),
    );

    if (showAppBar) {
      return Column(
        children: [
          _buildCompactAppBar(context),
          Expanded(child: content),
        ],
      );
    }

    return content;
  }

  Widget _buildCompactAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            context.l10n.equipment_sets_appBar_title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  void _handleItemTap(BuildContext context, EquipmentSet set) {
    if (onItemSelected != null) {
      onItemSelected!(set.id);
    } else {
      context.push('/equipment/sets/${set.id}');
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.folder_outlined,
                size: 80,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.equipment_sets_emptyState_title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.equipment_sets_emptyState_description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/equipment/sets/new'),
              icon: const Icon(Icons.add),
              label: Text(
                context.l10n.equipment_sets_emptyState_createFirstButton,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetsList(BuildContext context, List<EquipmentSet> sets) {
    return RefreshIndicator(
      onRefresh: () async {
        // Trigger refresh - the provider will handle reloading
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: sets.length,
        itemBuilder: (context, index) {
          final set = sets[index];
          final isSelected = selectedId == set.id;
          final itemCountText = set.itemCount == 1
              ? context.l10n.equipment_sets_itemCountSingular(set.itemCount)
              : context.l10n.equipment_sets_itemCountPlural(set.itemCount);
          return Semantics(
            label: listItemLabel(
              title: set.name,
              subtitle: set.description.isNotEmpty
                  ? set.description
                  : itemCountText,
            ),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: isSelected
                  ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.5)
                  : null,
              child: ListTile(
                onTap: () => _handleItemTap(context, set),
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.folder,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(set.name),
                subtitle: Text(
                  set.description.isNotEmpty ? set.description : itemCountText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: set.itemCount > 0
                    ? Semantics(
                        label:
                            context.l10n.equipment_sets_itemCountSemanticLabel(
                          '${set.itemCount}',
                        ),
                        child: Chip(
                          label: Text('${set.itemCount}'),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(context.l10n.equipment_sets_errorLoading('$error')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref
                .read(equipmentSetListNotifierProvider.notifier)
                .refresh(),
            child: Text(context.l10n.equipment_sets_retryButton),
          ),
        ],
      ),
    );
  }
}
```text
**Step 2: Update `EquipmentSetListPage` to use the extracted widget**

Replace the body of `EquipmentSetListPage.build()` to delegate to `EquipmentSetListContent`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_set_list_content.dart';

class EquipmentSetListPage extends ConsumerWidget {
  const EquipmentSetListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.equipment_sets_appBar_title)),
      body: const EquipmentSetListContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/equipment/sets/new'),
        tooltip: context.l10n.equipment_sets_fabTooltip,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.equipment_sets_fab_createSet),
      ),
    );
  }
}
```text
**Step 3: Verify compilation**

Run: `flutter analyze`
Expected: No errors.

**Step 4: Run tests**

Run: `flutter test`
Expected: All existing tests pass (no behavioral changes).

**Step 5: Commit**

```bash
git add lib/features/equipment/presentation/widgets/equipment_set_list_content.dart lib/features/equipment/presentation/pages/equipment_set_list_page.dart
git commit -m "refactor: extract EquipmentSetListContent widget from EquipmentSetListPage"
```dart
---

## Task 3: Convert EquipmentListPage to Tabbed Layout

This is the core change. Convert `EquipmentListPage` from `ConsumerWidget` to `ConsumerStatefulWidget` with `TabController`, add a `TabBar` to the `AppBar`, and use `TabBarView` to switch between equipment list and sets list.

**Files:**

- Modify: `lib/features/equipment/presentation/pages/equipment_list_page.dart`

**Step 1: Rewrite `EquipmentListPage` with TabBar**

The key structural changes:

1. `ConsumerWidget` -> `ConsumerStatefulWidget` + `SingleTickerProviderStateMixin`
2. Add `TabController` with 2 tabs
3. Move `TabBar` into `AppBar.bottom`
4. Wrap content in `TabBarView`
5. Listen to tab changes to toggle FAB and AppBar actions
6. Remove the folder icon button from AppBar actions (sets are now a tab)

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_set_list_content.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_summary_widget.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_edit_page.dart';

class EquipmentListPage extends ConsumerStatefulWidget {
  const EquipmentListPage({super.key});

  @override
  ConsumerState<EquipmentListPage> createState() => _EquipmentListPageState();
}

class _EquipmentListPageState extends ConsumerState<EquipmentListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isEquipmentTab => _tabController.index == 0;

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return _buildMasterDetailLayout(context);
    }
    return _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.equipment_appBar_title),
        actions: _isEquipmentTab
            ? [
                IconButton(
                  icon: const Icon(Icons.sort),
                  tooltip: context.l10n.equipment_list_sortTooltip,
                  onPressed: () {
                    // Sort is handled by EquipmentListContent internally
                    // We need to trigger it from outside - see note below
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: context.l10n.equipment_list_searchTooltip,
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: EquipmentSearchDelegate(),
                    );
                  },
                ),
              ]
            : [],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.backpack),
              text: context.l10n.equipment_tab_equipment,
            ),
            Tab(
              icon: const Icon(Icons.folder_special),
              text: context.l10n.equipment_tab_sets,
            ),
          ],
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          EquipmentListContent(showAppBar: false),
          const EquipmentSetListContent(),
        ],
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildFab(BuildContext context) {
    if (_isEquipmentTab) {
      return FloatingActionButton.extended(
        onPressed: () => _showAddEquipmentDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.equipment_fab_addEquipment),
      );
    } else {
      return FloatingActionButton.extended(
        onPressed: () => context.push('/equipment/sets/new'),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.equipment_fab_addSet),
      );
    }
  }

  Widget _buildMasterDetailLayout(BuildContext context) {
    // ... see Task 4 for master-detail implementation
  }

  void _showAddEquipmentDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddEquipmentSheet(ref: ref),
    );
  }
}
```text
**Important implementation notes:**

- The `EquipmentListContent` widget's `showAppBar: false` removes its internal AppBar since the parent now provides one with tabs.
- The sort and search actions only show on the Equipment tab. The `EquipmentListContent` already has sort/search built into its internal compact AppBar; since `showAppBar: false` hides it, we need to handle this. The simplest approach: pass `showAppBar: false` but keep the filter chips visible in `EquipmentListContent`. Sort can be triggered from `EquipmentListContent`'s own internal filter row, or we can keep `showAppBar: true` and remove the `AppBar` actions from the parent. **Decision: Keep `EquipmentListContent(showAppBar: false)` and rely on its built-in filter chips row. Remove sort/search from the parent AppBar actions since `EquipmentListContent` already handles them in its filter row when `showAppBar: false`.** Actually, looking at the code more carefully:
  - When `showAppBar: false`, `EquipmentListContent` shows `_buildCompactAppBar` which includes the folder icon, sort button, and search button.
  - We should keep this compact bar but remove the folder icon from it (since sets are now a tab).
  - The parent AppBar should NOT duplicate sort/search actions.

**Revised approach:** Use `EquipmentListContent(showAppBar: false)` which renders its own compact header with sort/search. Remove the folder icon from the compact header. Remove sort/search from the parent `AppBar.actions`.

**Step 2: Verify compilation**

Run: `flutter analyze`
Expected: No errors.

**Step 3: Run tests**

Run: `flutter test`
Expected: All existing tests pass.

**Step 4: Commit**

```bash
git add lib/features/equipment/presentation/pages/equipment_list_page.dart
git commit -m "feat: add TabBar to equipment page with Equipment and Sets tabs"
```text
---

## Task 4: Wire Up Master-Detail for Both Tabs

Add full master-detail support so that on tablet/desktop, switching tabs changes both the master list and the detail pane.

**Files:**

- Modify: `lib/features/equipment/presentation/pages/equipment_list_page.dart` (the `_buildMasterDetailLayout` method)

**Step 1: Implement `_buildMasterDetailLayout`**

Since `MasterDetailScaffold` doesn't natively support tab switching, we'll build a custom layout that uses the same visual pattern but switches content based on the active tab. The approach: wrap the entire layout in a `Scaffold` with a TabBar, and conditionally render one of two `MasterDetailScaffold` instances based on `_tabController.index`.

Using `IndexedStack` to preserve state when switching tabs:

```dart
Widget _buildMasterDetailLayout(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  final equipmentMasterDetail = MasterDetailScaffold(
    sectionId: 'equipment',
    masterBuilder: (context, onItemSelected, selectedId) =>
        EquipmentListContent(
          onItemSelected: onItemSelected,
          selectedId: selectedId,
          showAppBar: false,
        ),
    detailBuilder: (context, id) => EquipmentDetailPage(
      equipmentId: id,
      embedded: true,
      onDeleted: () => context.go('/equipment'),
    ),
    summaryBuilder: (context) => const EquipmentSummaryWidget(),
    editBuilder: (context, id, onSaved, onCancel) => EquipmentEditPage(
      equipmentId: id,
      embedded: true,
      onSaved: onSaved,
      onCancel: onCancel,
    ),
    createBuilder: (context, onSaved, onCancel) => EquipmentEditPage(
      embedded: true,
      onSaved: onSaved,
      onCancel: onCancel,
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () {},
      icon: const Icon(Icons.add),
      label: Text(context.l10n.equipment_fab_addEquipment),
    ),
  );

  final setsMasterDetail = MasterDetailScaffold(
    sectionId: 'equipment',
    masterBuilder: (context, onItemSelected, selectedId) =>
        EquipmentSetListContent(
          onItemSelected: onItemSelected,
          selectedId: selectedId,
          showAppBar: false,
        ),
    detailBuilder: (context, id) => EquipmentSetDetailPage(
      setId: id,
    ),
    summaryBuilder: (context) => const _EquipmentSetSummaryWidget(),
    mobileDetailRoute: (id) => '/equipment/sets/$id',
    mobileCreateRoute: '/equipment/sets/new',
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () {},
      icon: const Icon(Icons.add),
      label: Text(context.l10n.equipment_fab_addSet),
    ),
  );

  return Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.equipment_appBar_title),
      bottom: TabBar(
        controller: _tabController,
        tabs: [
          Tab(
            icon: const Icon(Icons.backpack),
            text: context.l10n.equipment_tab_equipment,
          ),
          Tab(
            icon: const Icon(Icons.folder_special),
            text: context.l10n.equipment_tab_sets,
          ),
        ],
        indicatorColor: colorScheme.primary,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: [
        equipmentMasterDetail,
        setsMasterDetail,
      ],
    ),
  );
}
```text
**Note:** The `EquipmentSetDetailPage` currently wraps itself in a `Scaffold`. For embedded master-detail usage, it may need an `embedded` parameter (similar to `EquipmentDetailPage`). If so, add a simple `embedded` flag that skips the outer `Scaffold`/`AppBar`. Evaluate at implementation time.

**Step 2: Add a simple `_EquipmentSetSummaryWidget`**

Add a private widget at the bottom of `equipment_list_page.dart` (or as a separate file if it grows) for the sets summary in master-detail:

```dart
class _EquipmentSetSummaryWidget extends ConsumerWidget {
  const _EquipmentSetSummaryWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_special,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.equipment_sets_appBar_title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.equipment_sets_emptyState_description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```text
**Step 3: Verify compilation and test**

Run: `flutter analyze && flutter test`
Expected: No errors, all tests pass.

**Step 4: Commit**

```bash
git add lib/features/equipment/presentation/pages/equipment_list_page.dart
git commit -m "feat: add master-detail support for equipment sets tab"
```text
---

## Task 5: Remove Folder Icon from EquipmentListContent

The folder icon button in `EquipmentListContent` (both in its AppBar and compact AppBar) is no longer needed since Sets are now accessible via the tab.

**Files:**

- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart`

**Step 1: Remove folder icon from `_buildCompactAppBar` (lines 215-219)**

Remove these lines:

```dart
IconButton(
  icon: const Icon(Icons.folder_outlined, size: 20),
  tooltip: context.l10n.equipment_list_setsTooltip,
  onPressed: () => context.push('/equipment/sets'),
),
```text
**Step 2: Remove folder icon from the Scaffold AppBar actions (lines 163-167)**

Remove these lines:

```dart
IconButton(
  icon: const Icon(Icons.folder_outlined),
  tooltip: context.l10n.equipment_list_setsTooltip,
  onPressed: () => context.push('/equipment/sets'),
),
```text
**Step 3: Verify compilation and test**

Run: `flutter analyze && flutter test`
Expected: No errors, all tests pass.

**Step 4: Commit**

```bash
git add lib/features/equipment/presentation/widgets/equipment_list_content.dart
git commit -m "refactor: remove equipment sets folder icon from equipment list"
```text
---

## Task 6: Update EquipmentSummaryWidget Quick Actions

The `EquipmentSummaryWidget` (shown in master-detail detail pane) has a "Equipment Sets" quick action button that navigates to `/equipment/sets`. This should be removed since sets are now a tab.

**Files:**

- Modify: `lib/features/equipment/presentation/widgets/equipment_summary_widget.dart`

**Step 1: Remove the "Equipment Sets" quick action button (lines 340-344)**

Remove this `OutlinedButton.icon` from `_buildQuickActions`:

```dart
OutlinedButton.icon(
  onPressed: () => context.push('/equipment/sets'),
  icon: const Icon(Icons.folder),
  label: Text(context.l10n.equipment_summary_equipmentSetsButton),
),
```text
**Step 2: Verify compilation and test**

Run: `flutter analyze && flutter test`
Expected: No errors, all tests pass.

**Step 3: Commit**

```bash
git add lib/features/equipment/presentation/widgets/equipment_summary_widget.dart
git commit -m "refactor: remove equipment sets button from summary quick actions"
```text
---

## Task 7: Update Router to Redirect /equipment/sets

The `/equipment/sets` route should redirect to the Equipment page with the Sets tab active (or be kept as-is for set CRUD sub-routes). Since `EquipmentSetListPage` is still a valid standalone page (used by the route), and the sub-routes `/equipment/sets/new`, `/equipment/sets/:setId`, and `/equipment/sets/:setId/edit` still need it as a parent, the simplest approach is to keep the routes as-is. The `EquipmentSetListPage` route still works for direct navigation from set detail "back" button.

**Files:**

- Modify: `lib/core/router/app_router.dart` (minimal change)

**Step 1: Update `EquipmentSetDetailPage` delete navigation**

In `equipment_set_detail_page.dart`, line 253, the delete handler navigates to `context.go('/equipment/sets')`. Update this to go back to `/equipment`:

```dart
// Change from:
context.go('/equipment/sets');
// To:
context.go('/equipment');
```text
**Step 2: Verify compilation and test**

Run: `flutter analyze && flutter test`
Expected: No errors, all tests pass.

**Step 3: Commit**

```bash
git add lib/features/equipment/presentation/pages/equipment_set_detail_page.dart
git commit -m "fix: navigate to equipment page after set deletion"
```diff
---

## Task 8: Format, Analyze, and Final Verification

**Step 1: Format all modified files**

Run: `dart format lib/features/equipment/ lib/core/router/ lib/l10n/`

**Step 2: Run full analysis**

Run: `flutter analyze`
Expected: No issues.

**Step 3: Run all tests**

Run: `flutter test`
Expected: All tests pass.

**Step 4: Manual smoke test**

Run: `flutter run -d macos`

Verify:

- Equipment page shows TabBar with "Equipment" and "Sets" tabs
- Equipment tab shows existing equipment list with filters, sort, search
- Sets tab shows equipment sets list
- FAB changes label based on active tab
- Tapping "Add Equipment" FAB on Equipment tab opens add sheet
- Tapping "Add Set" FAB on Sets tab navigates to set creation
- Folder icon is removed from AppBar
- On wide screen (resize window): master-detail layout works for both tabs
- Set detail page delete navigates back to equipment page
- Existing equipment set CRUD flows still work (create, view, edit, delete)

**Step 5: Final commit (if any formatting changes)**

```bash
git add -A
git commit -m "chore: format code for equipment sets visibility feature"
```
