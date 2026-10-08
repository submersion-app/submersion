# HealthKit UI Visibility Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a "Data Sources" section to Settings that clearly identifies HealthKit integration, fixing App Store Guideline 2.5.1 rejection.

**Architecture:** New `dataSources` entry in the existing `settingsSections` list, with a corresponding `_DataSourcesSectionContent` widget. The section always appears in the list (since `settingsSections` is `const`), but the content widget conditionally shows HealthKit details only on iOS/macOS. Localization strings added to all 10 ARB files.

**Tech Stack:** Flutter, Dart (`dart:io` for Platform check), go_router (for navigation to existing HealthKit import page), ARB localization

---

## Context

- **Trigger:** App Store rejection v1.2.14 on iPad Air (Guideline 2.5.1)
- **Problem:** HealthKit usage buried 3 taps deep, no top-level indication
- **Settings sections** defined in `lib/features/settings/presentation/widgets/settings_list_content.dart` as `const settingsSections` list
- **Section content** rendered via switch statements in `settings_page.dart` at lines 81-100 and 157-176
- **Localized titles/subtitles** resolved in `_getLocalizedTitle`/`_getLocalizedSubtitle` switch methods (lines 198-242)
- **HealthKit import route:** `/settings/wearable-import` (already exists)

---

### Task 1: Add localization strings to app_en.arb

**Files:**
- Modify: `lib/l10n/arb/app_en.arb:9266` (before closing brace)

**Step 1: Add the new localization keys**

Insert before the final `}` in app_en.arb (after line 9266 `"tools_weight_yourWeight": "Your weight"`):

```json
  "tools_weight_yourWeight": "Your weight",
  "settings_section_dataSources_title": "Data Sources",
  "settings_section_dataSources_subtitle": "Connected services & integrations",
  "settings_dataSources_header": "Data Sources",
  "settings_dataSources_appleHealth_title": "Apple Health",
  "settings_dataSources_appleHealth_description": "Submersion reads underwater diving workout data from Apple Health, including depth, duration, water temperature, and heart rate, to create detailed dive logs.",
  "settings_dataSources_appleHealth_importAction": "Import from Apple Watch",
  "settings_dataSources_appleHealth_privacy": "Your health data is stored locally and is never shared with third parties.",
  "settings_dataSources_noSources": "No data source integrations are available on this platform."
```

Note: the existing last line `"tools_weight_yourWeight": "Your weight"` needs a trailing comma added.

**Step 2: Run codegen to verify ARB parses correctly**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5`
Expected: Build completes without ARB parse errors

---

### Task 2: Add localization strings to all other ARB files

**Files:**
- Modify: `lib/l10n/arb/app_ar.arb` (and de, es, fr, he, hu, it, nl, pt)

**Step 1: Add the same keys to each non-English ARB file**

For each of the 9 files (`app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`), insert before the final `}` (after the last existing key-value pair). Each file's last line currently ends with `"diveImport_healthkit_dataUsage": "..."` -- add a comma and append:

```json
  "settings_section_dataSources_title": "Data Sources",
  "settings_section_dataSources_subtitle": "Connected services & integrations",
  "settings_dataSources_header": "Data Sources",
  "settings_dataSources_appleHealth_title": "Apple Health",
  "settings_dataSources_appleHealth_description": "Submersion reads underwater diving workout data from Apple Health, including depth, duration, water temperature, and heart rate, to create detailed dive logs.",
  "settings_dataSources_appleHealth_importAction": "Import from Apple Watch",
  "settings_dataSources_appleHealth_privacy": "Your health data is stored locally and is never shared with third parties.",
  "settings_dataSources_noSources": "No data source integrations are available on this platform."
```

Use English values as placeholders (translations can be done later).

**Step 2: Run codegen again**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5`
Expected: Build completes successfully

---

### Task 3: Add dataSources section entry to settings_list_content.dart

**Files:**
- Modify: `lib/features/settings/presentation/widgets/settings_list_content.dart:22-79`

**Step 1: Add the new section to the list**

Insert a new `SettingsSection` entry into `settingsSections` after the `data` section (id `'data'`) and before `decompression`:

```dart
  SettingsSection(
    id: 'dataSources',
    icon: Icons.link,
    title: 'Data Sources',
    subtitle: 'Connected services & integrations',
    color: Colors.red,
  ),
```

The icon `Icons.link` and color `Colors.red` (evoking the Health app's red heart) make it visually distinct.

**Step 2: Add localized title/subtitle to _getLocalizedTitle and _getLocalizedSubtitle**

In `settings_list_content.dart`, the `_SettingsSectionTile` widget has `_getLocalizedTitle` and `_getLocalizedSubtitle` methods. Add a new case to each:

In `_getLocalizedTitle` (around line 198):
```dart
      case 'dataSources':
        return context.l10n.settings_section_dataSources_title;
```

In `_getLocalizedSubtitle` (around line 221):
```dart
      case 'dataSources':
        return context.l10n.settings_section_dataSources_subtitle;
```

---

### Task 4: Add _DataSourcesSectionContent widget and switch cases to settings_page.dart

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`

**Step 1: Add switch cases for 'dataSources' in both _buildSectionContent methods**

In `_buildSectionContent` (line 81 switch), add before `default`:
```dart
      case 'dataSources':
        return const _DataSourcesSectionContent();
```

In `_buildContent` (line 157 switch), add before `default`:
```dart
      case 'dataSources':
        return const _DataSourcesSectionContent();
```

**Step 2: Add the _DataSourcesSectionContent widget**

Add the widget class before the `_AboutSectionContent` class (around line 1780). The widget needs `import 'dart:io';` (already imported if not present) and `import 'package:go_router/go_router.dart';` (already imported).

```dart
/// Data Sources section - surfaces HealthKit integration for App Store compliance.
class _DataSourcesSectionContent extends StatelessWidget {
  const _DataSourcesSectionContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isApplePlatform = Platform.isIOS || Platform.isMacOS;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            context.l10n.settings_dataSources_header,
          ),
          const SizedBox(height: 8),
          if (isApplePlatform)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.l10n.settings_dataSources_appleHealth_title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n
                          .settings_dataSources_appleHealth_description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.watch),
                      title: Text(
                        context.l10n
                            .settings_dataSources_appleHealth_importAction,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('/settings/wearable-import'),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n
                                .settings_dataSources_appleHealth_privacy,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.settings_dataSources_noSources,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

**Step 3: Verify dart:io and go_router imports exist**

Check that the file has `import 'dart:io';` and `import 'package:go_router/go_router.dart';`. Both should already be present given other platform checks and navigation in the file.

---

### Task 5: Run codegen, format, analyze, and test

**Step 1: Run build_runner codegen**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5`
Expected: Build completes successfully

**Step 2: Format code**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && dart format lib/features/settings/presentation/pages/settings_page.dart lib/features/settings/presentation/widgets/settings_list_content.dart`
Expected: No formatting changes (or formats cleanly)

**Step 3: Run analyzer**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && flutter analyze lib/features/settings/`
Expected: No analysis issues

**Step 4: Run existing tests**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion && flutter test`
Expected: All tests pass
