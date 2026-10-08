# Linked Dive Computer Navigation - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the dive computer row on the dive detail page tappable when a linked DiveComputer record exists, navigating to the Device Detail Page.

**Architecture:** Adds a single new method `_buildLinkedComputerRow` that mirrors the existing `_buildTripRow` pattern (Semantics + InkWell + chevron), and updates `_buildDiveComputerRows` to use it instead of static `_buildDetailRow` calls when a DiveComputer record is present. Fallback to string fields is unchanged.

**Tech Stack:** Flutter, go_router (`context.push`), Riverpod (existing `computersForDiveProvider`)

---

### Task 1: Add `_buildLinkedComputerRow` method

**Files:**

- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:2907` (insert new method after `_buildDiveComputerStringRows`)

**Step 1: Add the new method**

Insert this method immediately after `_buildDiveComputerStringRows` (after line 2907) and before `_buildTripRow`:

```dart
  /// Build a tappable row for a linked dive computer that navigates to
  /// the device detail page.
  Widget _buildLinkedComputerRow(
    BuildContext context,
    DiveComputer computer,
  ) {
    return Semantics(
      button: true,
      label: 'View dive computer ${computer.displayName}',
      child: InkWell(
        onTap: () => context.push('/dive-computers/${computer.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.diveLog_detail_label_diveComputer,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            computer.displayName,
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (computer.serialNumber != null &&
                              computer.serialNumber!.isNotEmpty)
                            Text(
                              'S/N ${computer.serialNumber}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    ExcludeSemantics(
                      child: Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
```text
**Notes for implementer:**

- `DiveComputer` is the domain entity from `lib/features/dive_log/domain/entities/dive_computer.dart`. Check that it is already imported at the top of the file (it should be, since `computersForDiveProvider` already returns `List<DiveComputer>`).
- `context.push` comes from `go_router`, already imported at line 9.
- `context.l10n.diveLog_detail_label_diveComputer` is the existing localization key used for the "Dive Computer" label.
- The route `/dive-computers/:computerId` is already defined in `app_router.dart:850-878`.

**Step 2: Run dart format**

Run: `dart format lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: No formatting changes (code above is pre-formatted).

---

### Task 2: Update `_buildDiveComputerRows` to use the new method

**Files:**

- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:2848-2871`

**Step 1: Replace the `data` branch**

Replace lines 2848-2871 (the `data:` callback inside `computersAsync.when`):

**Before:**

```dart
      data: (computers) {
        if (computers.isNotEmpty) {
          final computer = computers.first;
          return [
            _buildDetailRow(
              context,
              context.l10n.diveLog_detail_label_diveComputer,
              computer.displayName,
            ),
            if (computer.serialNumber != null &&
                computer.serialNumber!.isNotEmpty)
              _buildDetailRow(
                context,
                context.l10n.diveLog_detail_label_serialNumber,
                computer.serialNumber!,
              ),
            if (computer.firmwareVersion != null &&
                computer.firmwareVersion!.isNotEmpty)
              _buildDetailRow(
                context,
                context.l10n.diveLog_detail_label_firmwareVersion,
                computer.firmwareVersion!,
              ),
          ];
        }
        // Fall back to string fields on Dive entity
        return _buildDiveComputerStringRows(context, dive);
      },
```text
**After:**

```dart
      data: (computers) {
        if (computers.isNotEmpty) {
          return [_buildLinkedComputerRow(context, computers.first)];
        }
        // Fall back to string fields on Dive entity
        return _buildDiveComputerStringRows(context, dive);
      },
```text
**Step 2: Run dart format**

Run: `dart format lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: No formatting changes.

**Step 3: Run flutter analyze**

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: No issues found.

---

### Task 3: Manual verification

**Step 1: Run tests**

Run: `flutter test`
Expected: All existing tests pass. No test changes needed since this is a UI-only change to an existing method.

**Step 2: Visual verification**

Run: `flutter run -d macos`

Verify these scenarios:

1. Open a dive that was downloaded from a saved dive computer. The "Dive Computer" row should show the computer name, serial number subtitle, and a chevron. Tapping it should navigate to the Device Detail Page for that computer.
2. Open a manually-entered dive that has `diveComputerModel` set but no linked `DiveComputer` record. The row should show as static text with no chevron (same as before).
3. Open a dive with no computer info at all. No computer row should appear (same as before).

**Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart
git commit -m "feat: make dive computer row tappable with link to device detail page"
```
