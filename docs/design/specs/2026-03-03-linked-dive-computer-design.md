# Linked Dive Computer Navigation

## Problem

The "Dive Computer" field on the dive detail page displays as static text, even when the dive is linked to a managed `DiveComputer` record. Users cannot navigate from a dive to the computer that recorded it.

## Solution

Make the dive computer row tappable when a linked `DiveComputer` record exists, navigating to the Device Detail Page (`/dive-computers/:computerId`). Unlinked dives (string-only metadata) remain static text.

## Behavior Matrix

| Dive has... | Display |
|---|---|
| Linked `DiveComputer` record (via `dive_profiles.computer_id`) | Tappable row with displayName, serial subtitle, chevron. Navigates to `/dive-computers/:computerId` |
| Only string fields (`diveComputerModel`, etc.) | Static text rows, unchanged |
| Neither | Nothing shown, unchanged |

## Implementation

**File:** `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

### New method: `_buildLinkedComputerRow`

Follows the existing `_buildTripRow` pattern:

- `Semantics(button: true)` + `InkWell` wrapper
- Primary text: `computer.displayName`
- Subtitle: serial number (if present)
- Trailing: `Icons.chevron_right`
- `onTap`: `context.push('/dive-computers/${computer.id}')`

### Modified method: `_buildDiveComputerRows`

When `computers.isNotEmpty`, delegates to `_buildLinkedComputerRow(context, computers.first)` instead of building static `_buildDetailRow` calls. Fallback paths (loading, error, empty) remain unchanged.

## What's NOT changing

- No database columns, tables, or migrations
- No new providers or routes
- No "link to computer" feature for unlinked dives
- No changes to the Device Detail Page
- No changes to the fallback string-field display
