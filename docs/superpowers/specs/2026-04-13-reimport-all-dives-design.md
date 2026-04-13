# Re-import All Dives from Dive Computer

**Issue:** [#206](https://github.com/submersion-app/submersion/issues/206) — Allow Re-Import from computer.

## Problem

Once a dive computer has a stored fingerprint, the incremental download path (March 12 spec) silently skips every dive older than the high-water mark. Users who deleted a dive by accident, or who aborted a prior import before all dives were saved, have no way to pull those dives back through the UI. They are told "No new dives to download" and given only a **Done** button.

The `newDivesOnly` flag in `DownloadState` was designed to provide this escape hatch, but the setter `setNewDivesOnly()` has no call sites — the toggle was never wired into any visible control.

## Goal

Add a first-class "Re-import all dives" entry point on the dive computer detail page. It bypasses the fingerprint filter and routes the full set of dives through the existing unified-import-wizard review step, where every already-logged dive is flagged as a pending duplicate and the user must explicitly choose **Skip**, **Import as New**, or **Consolidate** for each.

The design does not introduce a new import path or a new toggle. It adds a second entry into the existing `DiveComputerAdapter` flow with the fingerprint-bypass flag flipped on from the start.

## Scope

- Applies only to the known-computer download flow (`/dive-computers/:computerId/download`). The discovery flow has no stored fingerprint for a newly-paired device and already downloads all dives.
- Applies only to the `DiveComputerAdapter`. File-based imports (UDDF, FIT) and HealthKit do not have the fingerprint-skip optimization — re-running them already produces the full dataset.
- Button is visible only when `computer.lastDiveFingerprint != null`. For computers that have never been downloaded, the existing "Download Dives" button already performs a full download; a second button in that state would be a confusing no-op.

## Out of Scope

- No changes to duplicate-detection scoring, `DiveMatcher`, or `DiveImportService`.
- No changes to the Pigeon bridge or native platform downloaders.
- No date-range or per-dive selective re-import (user selects "all" up front; the Review step is where per-dive decisions happen).
- No changes to the fingerprint-update rule from the March 12 spec. Post-re-import, the fingerprint advances to the newest **actually-imported** dive, same as any other import.
- No persisted "re-import mode" on the `DiveComputer` record — the flag is transient per import session.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Entry-point surface | Dedicated button on DC detail page | User mental model is "I want to re-import," not "change a download setting." A toggle is easy to leave in the wrong state; a distinct button is honest about what it does. |
| Flag transport | `forceFullDownload: bool` on `DiveComputerAdapter` + `?forceFull=true` query param on the route | Uses existing route; survives deep-linking; `state.uri.queryParameters` is go_router's natural plumbing. No new routes needed. |
| Underlying mechanism | Call existing `setNewDivesOnly(false)` before `startDownload` | `DownloadNotifier` already computes `fingerprint = null` when `newDivesOnly == false`. No native changes. |
| Confirmation before download | Lightweight `AlertDialog` | Sets expectations on duration + upcoming review step. Rare action, so the one-time friction is cheap vs. the cost of an accidental tap. |
| Terminal-screen discoverability | Tertiary `TextButton` on `DcNoNewDivesView` that closes the wizard | Addresses the exact user journey in the issue. Navigation lands users back on the detail page; they still tap the deliberate "Re-import all dives" button there — no auto-opening dialogs. |
| Visibility gating | Hide button when `lastDiveFingerprint == null` | Prevents a confusing no-op for freshly-paired or reset computers. |

## Architecture

### 1. `DiveComputerAdapter` — add `forceFullDownload` flag

`lib/features/import_wizard/data/adapters/dive_computer_adapter.dart`

Add a constructor parameter and field:

```dart
DiveComputerAdapter({
  // ... existing params ...
  bool forceFullDownload = false,
}) : _forceFullDownload = forceFullDownload,
     // ... existing initializers ...

final bool _forceFullDownload;
bool get forceFullDownload => _forceFullDownload;
```

The adapter exposes `forceFullDownload` so the download step widget can read it (or `dc_adapter_steps.dart` can call a method that applies the flag).

### 2. Download step applies the flag

`lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart` — in `_DcAdapterDownloadStepState`.

In `_DcAdapterDownloadStepState.initState()`, immediately after the existing `_resolveComputer()` scheduling, apply the flag if the adapter asked for a full download:

```dart
if (widget.adapter.forceFullDownload) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(downloadNotifierProvider.notifier).setNewDivesOnly(false);
  });
}
```

The post-frame callback ensures the notifier is stable before the mutation. The existing logic at `download_providers.dart:157` then selects `fingerprint = null` when `startDownload` runs, and libdivecomputer downloads every dive on the device.

The call must precede `DownloadStepWidget`'s internal `startDownload()` trigger. `DownloadStepWidget` resolves the device and invokes the notifier reactively once mounted, so the `initState` post-frame scheduling runs first.

### 3. Route forwards the query param

`lib/core/router/app_router.dart` — `computerDownload` route (around line 970):

```dart
GoRoute(
  path: 'download',
  name: 'computerDownload',
  builder: (context, state) => _DiveComputerDownloadWizardRoute(
    computerId: state.pathParameters['computerId']!,
    forceFullDownload: state.uri.queryParameters['forceFull'] == 'true',
  ),
),
```

`_DiveComputerDownloadWizardRoute` accepts the new parameter and forwards it:

```dart
DiveComputerAdapter(
  // ... existing params ...
  forceFullDownload: forceFullDownload,
)
```

Malformed or absent values default to `false` (strict string equality against `'true'`).

### 4. DC detail page — button + confirmation dialog

`lib/features/dive_computer/presentation/pages/device_detail_page.dart` — in the actions card (around line 291-302).

Add a conditional tertiary action:

```dart
if (computer.lastDiveFingerprint != null) ...[
  const SizedBox(height: 12),
  OutlinedButton.icon(
    onPressed: () => _confirmReimportAll(context, computer),
    icon: const Icon(Icons.refresh),
    label: Text(context.l10n.diveComputer_detail_reimportAllButton),
  ),
],
```

The confirmation helper:

```dart
Future<void> _confirmReimportAll(
  BuildContext context,
  DiveComputer computer,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.diveComputer_detail_reimportDialogTitle),
      content: Text(
        l10n.diveComputer_detail_reimportDialogBody(computer.displayName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.common_continue),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    context.push('/dive-computers/${computer.id}/download?forceFull=true');
  }
}
```

### 5. `DcNoNewDivesView` — discoverability breadcrumb

`lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart` (around line 434).

Current view: icon + title + subtitle + single "Done" FilledButton.

Add a tertiary `TextButton` below "Done":

```dart
TextButton(
  onPressed: onDone,
  child: Text(context.l10n.diveComputer_download_reimportHint),
),
```

`onDone` already pops the wizard; the known-computer flow was pushed onto the detail page, so popping returns the user there. No explicit deep-link navigation is needed. The discovery flow pops to the device list instead — an extra tap to drill into the computer, but acceptable for a rare edge case.

No auto-opening of the confirmation dialog from this breadcrumb. The user must deliberately tap "Re-import all dives" on the detail page. This prevents accidental re-imports triggered by reflexive tapping on the terminal screen.

## Data Flow

```
DC detail page
  └─ User taps "Re-import all dives"
      └─ Confirmation dialog → user taps Continue
          └─ context.push('/dive-computers/:id/download?forceFull=true')
              └─ _DiveComputerDownloadWizardRoute(forceFullDownload: true)
                  └─ UnifiedImportWizard(
                       adapter: DiveComputerAdapter(forceFullDownload: true))
                      └─ DcAdapterDownloadStep builds
                          └─ If adapter.forceFullDownload:
                               setNewDivesOnly(false)
                              └─ DownloadNotifier sends fingerprint=null
                                  └─ libdivecomputer returns ALL dives
                                      └─ Wizard advances to Review step
                                          └─ Already-logged dives flagged
                                             as pending duplicates
                                              └─ User resolves each
                                                 (Skip / Import as New /
                                                  Consolidate)
                                                  └─ Import runs →
                                                     fingerprint advances
                                                     per existing rule
```

## Edge Cases

| Scenario | Behavior |
|---|---|
| User cancels confirmation dialog | Nothing happens; user stays on detail page. |
| User cancels mid-download | Existing `cancelDownload()` path; fingerprint unchanged. |
| Download errors mid-transfer | Existing `DownloadErrorEvent` path; fingerprint unchanged. |
| User skips every duplicate | `importResult.importedDives` empty; `selectNewestFingerprint` returns null; `updateLastFingerprint` not called; stored fingerprint unchanged. Already handled by March 12 spec. |
| User imports only some dives as new | Fingerprint advances to newest persisted dive. This is the intended high-water-mark invariant. |
| User consolidates everything | Consolidation does not create new `dives` rows, so `importResult.importedDives` contains only "importAsNew" actions. Fingerprint advances only if any were imported as new. |
| Computer memory wiped since last sync | Stored fingerprint no longer matches any on-device dive. libdivecomputer downloads everything (same as fingerprint-null). Re-import button is redundant but harmless in this state. |
| User pastes the `?forceFull=true` URL directly | The full download proceeds as requested. The URL parameter is a capability, not an auth-gated action; this is acceptable. |
| Discovery flow (new computer) | `_DiveComputerDiscoveryWizardRoute` does not accept or forward the flag. Not applicable. |

## Localization

Four new keys in `lib/l10n/arb/app_en.arb`:

| Key | Value |
|---|---|
| `diveComputer_detail_reimportAllButton` | "Re-import all dives" |
| `diveComputer_detail_reimportDialogTitle` | "Re-import all dives?" |
| `diveComputer_detail_reimportDialogBody` | "Download every dive from {computerName} and review them against your log. This may take several minutes." (placeholder: `computerName`) |
| `diveComputer_download_reimportHint` | "Looking for older or deleted dives? Re-import all" |

Also adds `common_action_continue` ("Continue"); reuses existing `common_action_cancel`.

Other locale `.arb` files are not updated in this change; the existing codegen fallback will serve the English strings until translations land. This matches the project's pattern for in-progress features.

## Testing

### Adapter unit test

`test/features/import_wizard/data/adapters/dive_computer_adapter_reimport_test.dart` (new):

- With `forceFullDownload: true`, invoking the download-step flow calls `setNewDivesOnly(false)` on the `DownloadNotifier`.
- With `forceFullDownload: false` (default), `setNewDivesOnly` is not called — default behavior preserved.

### Detail page widget test

`test/features/dive_computer/presentation/pages/device_detail_page_reimport_test.dart` (new):

- Re-import button is hidden when `computer.lastDiveFingerprint == null`.
- Re-import button is visible when `lastDiveFingerprint` is non-null.
- Tapping the button shows the confirmation dialog with title, body (including computer name), Cancel, and Continue.
- Cancel dismisses without navigation.
- Continue pushes `/dive-computers/:id/download?forceFull=true` (verified via `MockGoRouter` or equivalent).

### Router test

`test/core/router/app_router_reimport_test.dart` (new or extend existing router tests):

- `forceFull=true` query param produces a `_DiveComputerDownloadWizardRoute` with `forceFullDownload: true`.
- Absence, `forceFull=false`, and malformed values default to `false`.

### `DcNoNewDivesView` widget test

Extend or add `test/features/import_wizard/presentation/widgets/dc_no_new_dives_view_test.dart`:

- Breadcrumb `TextButton` is present with the `diveComputer_download_reimportHint` text.
- Tapping the breadcrumb invokes the `onDone` callback.

### Regression test (issue #206)

`test/features/dive_computer/issue_206_reimport_regression_test.dart` (new):

Self-contained regression guard: seed a computer with a fingerprint and some existing dives in the database, simulate the re-import flow, and assert that every previously-logged dive appears in the Review step as a **pending** duplicate requiring explicit action. This enforces the invariant the issue asked for: "let the user decide what needs to be re-imported."

### Unchanged

- `download_notifier_fingerprint_test.dart` — fingerprint selection logic unchanged.
- `import_duplicate_checker_test.dart` — detection unchanged.
- `DiveComputerAdapter`'s existing acquisition-step tests — unchanged.

## Files Affected

**Modified:**

| File | Change |
|------|--------|
| `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` | Add `forceFullDownload` constructor param and getter |
| `lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart` | Download step calls `setNewDivesOnly(false)` when adapter has `forceFullDownload: true`; `DcNoNewDivesView` gets tertiary breadcrumb button |
| `lib/features/dive_computer/presentation/pages/device_detail_page.dart` | Conditional "Re-import all dives" button + `_confirmReimportAll` helper |
| `lib/core/router/app_router.dart` | `computerDownload` route reads `forceFull` query param; `_DiveComputerDownloadWizardRoute` accepts and forwards the flag |
| `lib/l10n/arb/app_en.arb` | Four new keys |

**Unchanged:**

- `lib/features/dive_computer/presentation/providers/download_providers.dart`
- `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`
- `lib/core/database/database.dart`
- `packages/libdivecomputer_plugin/**`
- All duplicate-detection / Review-step code in `import_wizard/`

## Risks and Tradeoffs

- **Button adds UI surface to a commonly-visited page.** Mitigation: hidden for computers without a fingerprint, so first-time users never see it. It is a tertiary `OutlinedButton` below the existing two actions, not competing for primary attention.
- **Users may re-import and then be surprised by the long duplicate-review list.** Mitigation: confirmation dialog explicitly mentions "review which dives to keep" and "several minutes."
- **Breadcrumb on `DcNoNewDivesView` adds a small discoverability touch but costs a reconnection if used.** Accepted: the reconnection is unavoidable because the original download session's connection is already closed. The breadcrumb is a navigation aid, not a magic resume.
- **Query-parameter flag is a capability, not auth-gated.** A user who constructs the URL manually can force a full download without the confirmation dialog. Acceptable — the URL is only accessible from within the app, and the Review step is the real safety gate against accidental double-import.

## Dependencies

- No new packages.
- No schema migration.
- No Pigeon regeneration.
- Relies on the already-merged March 12 (incremental download) and April 12 (explicit duplicate selection) changes.
