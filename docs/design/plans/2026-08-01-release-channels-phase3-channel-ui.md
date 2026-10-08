# Release Channels Phase 3: In-App Channel Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give users a Stable/Beta update-channel setting: desktop builds switch their update feed live (Sparkle beta appcast on macOS/Windows, `beta-builds` repo polling on Linux), store builds get "Join the beta" signposts (activated in Phase 4), the About row shows the channel, and the sync page surfaces "a peer runs a newer version". Also fixes the confirmed Linux perpetual-update-banner bug.

**Architecture:** A new `ReleaseChannel` enum (distinct from the existing compile-time distribution `UpdateChannel`) persisted in `UpdatePreferences`. `updateServiceProvider` starts watching the channel and constructs the service against channel-dependent coordinates (feed URL / repo). `SparkleUpdateService` re-applies `setFeedURL` per instance, so invalidation is the switch mechanism. All new user-facing strings go through l10n (11 ARB files + `flutter gen-l10n`); the Updates card's existing hardcoded strings get localized in passing since we are rebuilding that card anyway.

**Tech Stack:** Flutter, Riverpod (legacy providers via `core/providers/provider.dart` barrel), SharedPreferences, `auto_updater`, `url_launcher`, `flutter gen-l10n`.

## Global Constraints

- `dart format .` clean; `flutter analyze` clean (infos fatal). Full test suite at the end; new provider dependencies can break consumer tests in ways analyze cannot catch — run the FULL suite, not just touched files.
- Every new user-visible string is localized: add to `lib/l10n/arb/app_en.arb` (alphabetically sorted, `settings_updates_*` / `settings_cloudSync_*` prefixes) AND translated into all 10 non-English ARBs (`ar de es fr he hu it nl pt zh`), then run `flutter gen-l10n` (generated files are checked in).
- Name collision: the new enum is `ReleaseChannel { stable, beta }` — never `UpdateChannel` (taken by the compile-time distribution channel).
- Widget tests touching the updates card need the two documented workarounds: seed `SharedPreferences.setMockInitialValues({'auto_update_enabled': false})` and drain the 5s startup timer with `await tester.pump(const Duration(seconds: 6))`.
- Dialog conventions: `showDialog<bool>`, cancel via `MaterialLocalizations.of(context).cancelButtonLabel`, affirmative `FilledButton`, `if (confirmed == true)`.
- Work on branch `release-channels-phase3` (stacked on phase1-2); commit per task.

---

### Task 1: `ReleaseChannel` + preference

**Files:**
- Create: `lib/features/auto_update/domain/entities/release_channel.dart`
- Modify: `lib/features/auto_update/data/repositories/update_preferences.dart`
- Test: `test/features/auto_update/data/repositories/update_preferences_test.dart`

**Interfaces:**
- Produces: `enum ReleaseChannel { stable, beta }` with `static ReleaseChannel fromName(String? name)` (unknown/null → stable); `UpdatePreferences.releaseChannel` getter (default `ReleaseChannel.stable`) and `Future<void> setReleaseChannel(ReleaseChannel value)` storing `value.name` under key `'update_release_channel'`. Tasks 3-5 depend on these names.

- [ ] **Step 1: Write failing tests** (extend the existing file's pattern — `SharedPreferences.setMockInitialValues({})` then `UpdatePreferences(await SharedPreferences.getInstance())`):

```dart
  test('releaseChannel defaults to stable', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = UpdatePreferences(await SharedPreferences.getInstance());
    expect(prefs.releaseChannel, ReleaseChannel.stable);
  });

  test('setReleaseChannel round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = UpdatePreferences(await SharedPreferences.getInstance());
    await prefs.setReleaseChannel(ReleaseChannel.beta);
    expect(prefs.releaseChannel, ReleaseChannel.beta);
  });

  test('releaseChannel tolerates an unknown stored value', () async {
    SharedPreferences.setMockInitialValues({
      'update_release_channel': 'nightly',
    });
    final prefs = UpdatePreferences(await SharedPreferences.getInstance());
    expect(prefs.releaseChannel, ReleaseChannel.stable);
  });
```

Add `import 'package:submersion/features/auto_update/domain/entities/release_channel.dart';`.

- [ ] **Step 2: Run to verify failure** — `flutter test test/features/auto_update/data/repositories/update_preferences_test.dart` fails to compile.

- [ ] **Step 3: Implement.** New file `release_channel.dart`:

```dart
/// The user-selected update channel: stable releases only, or per-merge
/// beta builds. Distinct from [UpdateChannel], which is the compile-time
/// distribution channel (github/appstore/playstore/...).
enum ReleaseChannel {
  stable,
  beta;

  /// Parses a stored name, falling back to [stable] for null/unknown values
  /// so downgraded or corrupted preferences never strand a user on beta.
  static ReleaseChannel fromName(String? name) {
    for (final channel in ReleaseChannel.values) {
      if (channel.name == name) return channel;
    }
    return ReleaseChannel.stable;
  }
}
```

In `update_preferences.dart`: add `import '../../domain/entities/release_channel.dart';` (match the file's existing relative/absolute import style — it uses package imports, so `package:submersion/features/auto_update/domain/entities/release_channel.dart`), a key `static const _keyReleaseChannel = 'update_release_channel';`, and:

```dart
  ReleaseChannel get releaseChannel =>
      ReleaseChannel.fromName(_prefs.getString(_keyReleaseChannel));

  Future<void> setReleaseChannel(ReleaseChannel value) =>
      _prefs.setString(_keyReleaseChannel, value.name);
```

- [ ] **Step 4: Run to verify pass**, then commit:

```bash
git add lib/features/auto_update/domain/entities/release_channel.dart lib/features/auto_update/data/repositories/update_preferences.dart test/features/auto_update/data/repositories/update_preferences_test.dart
git commit -m "feat(auto-update): add a persisted stable/beta release channel preference"
```

---

### Task 2: Fix the Linux perpetual-update-banner bug

`packageInfo.version` is 3-segment (`1.7.1`) while release tags are 4-segment (`v1.7.1.118`); `isNewer('1.7.1.118','1.7.1')` is true, so Linux shows "update available" forever on a current install.

**Files:**
- Modify: `lib/features/auto_update/presentation/providers/update_providers.dart:45`
- Test: `test/features/auto_update/data/services/github_update_service_test.dart`

- [ ] **Step 1: Write the failing-shaped service test** (documents the fix contract at the service level):

```dart
    test('4-segment current version equal to the release tag is up to date',
        () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode(makeRelease(tagName: 'v1.7.1.118')), 200);
      });

      final service = GithubUpdateService(
        owner: owner,
        repo: repo,
        currentVersion: '1.7.1.118',
        platformSuffix: 'Linux.tar.gz',
        httpClient: client,
      );

      expect(await service.checkForUpdate(), isA<UpToDate>());
    });
```

(This passes immediately — it pins the contract the provider fix relies on. The provider-side change is not directly unit-testable because `PackageInfo.fromPlatform` and `Platform` checks live inline; the contract test plus Step 2's one-liner carry the fix.)

- [ ] **Step 2: Fix the provider** — in `update_providers.dart`, replace:

```dart
  final currentVersion = packageInfo.version;
```

with:

```dart
  // Release tags are 4-segment (vX.Y.Z.N) while packageInfo.version is the
  // 3-segment marketing version; without the build number appended, a
  // current install always compares as older than its own release tag.
  final currentVersion = packageInfo.version.endsWith(
        '.${packageInfo.buildNumber}',
      )
      ? packageInfo.version
      : '${packageInfo.version}.${packageInfo.buildNumber}';
```

- [ ] **Step 3: Run module tests + commit:**

```bash
flutter test test/features/auto_update/
git add lib/features/auto_update/presentation/providers/update_providers.dart test/features/auto_update/data/services/github_update_service_test.dart
git commit -m "fix(auto-update): compare 4-segment versions so current installs read as up to date"
```

---

### Task 3: Channel-aware update service selection

**Files:**
- Modify: `lib/features/auto_update/presentation/providers/update_providers.dart`
- Test: `test/features/auto_update/presentation/providers/update_feed_selection_test.dart` (new)

**Interfaces:**
- Consumes: `UpdatePreferences.releaseChannel` (Task 1).
- Produces: `releaseChannelProvider` (`Provider<ReleaseChannel>`); pure helpers `appcastUrlFor(ReleaseChannel)` and `githubRepoFor(ReleaseChannel)` (top-level, exported from `update_providers.dart`); `updateServiceProvider` now watches `releaseChannelProvider`. Task 4's toggle relies on `ref.invalidate(updatePreferencesProvider)` cascading through these.

- [ ] **Step 1: Write failing tests** in the new test file:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/auto_update/domain/entities/release_channel.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';

void main() {
  test('stable channel uses the main repo appcast', () {
    expect(
      appcastUrlFor(ReleaseChannel.stable),
      'https://github.com/submersion-app/submersion/releases/latest/download/appcast.xml',
    );
    expect(githubRepoFor(ReleaseChannel.stable), 'submersion');
  });

  test('beta channel uses the beta-builds superset feed and repo', () {
    expect(
      appcastUrlFor(ReleaseChannel.beta),
      'https://github.com/submersion-app/beta-builds/releases/latest/download/appcast-beta.xml',
    );
    expect(githubRepoFor(ReleaseChannel.beta), 'beta-builds');
  });
}
```

- [ ] **Step 2: Run to verify failure** (functions undefined).

- [ ] **Step 3: Implement** in `update_providers.dart`. Replace the `_appcastUrl` const block with:

```dart
/// Repository holding per-merge beta releases (superset appcast + artifacts).
const _betaRepo = 'beta-builds';

/// Appcast feed URL for Sparkle/WinSparkle (macOS + Windows) per channel.
/// The beta feed is a superset (beta items first, stable items appended), so
/// a device switched back to stable still walks forward onto the next stable.
String appcastUrlFor(ReleaseChannel channel) => switch (channel) {
  ReleaseChannel.stable =>
    'https://github.com/$_githubOwner/$_githubRepo/releases/latest/download/appcast.xml',
  ReleaseChannel.beta =>
    'https://github.com/$_githubOwner/$_betaRepo/releases/latest/download/appcast-beta.xml',
};

/// GitHub repo polled by the non-Sparkle updater (Linux/Android) per channel.
String githubRepoFor(ReleaseChannel channel) => switch (channel) {
  ReleaseChannel.stable => _githubRepo,
  ReleaseChannel.beta => _betaRepo,
};

/// The user-selected release channel, re-evaluated when preferences reload.
final releaseChannelProvider = Provider<ReleaseChannel>((ref) {
  return ref.watch(updatePreferencesProvider).releaseChannel;
});
```

and change `updateServiceProvider`'s body to consume it:

```dart
final updateServiceProvider = FutureProvider<UpdateService?>((ref) async {
  if (!UpdateChannelConfig.isAutoUpdateEnabled) return null;

  final channel = ref.watch(releaseChannelProvider);
  final packageInfo = await PackageInfo.fromPlatform();
  // (currentVersion block from Task 2 stays as-is)

  if (_useSparkleEngine) {
    return SparkleUpdateService(feedUrl: appcastUrlFor(channel));
  }

  return GithubUpdateService(
    owner: _githubOwner,
    repo: githubRepoFor(channel),
    currentVersion: currentVersion,
    platformSuffix: _platformSuffix,
  );
});
```

Add the `release_channel.dart` import. No `SparkleUpdateService` changes needed: `_initialized` is per-instance, so the fresh instance created after invalidation re-calls `autoUpdater.setFeedURL` with the new URL on its next check.

- [ ] **Step 4: Run tests + the whole module, commit:**

```bash
flutter test test/features/auto_update/
git add lib/features/auto_update/presentation/providers/update_providers.dart test/features/auto_update/presentation/providers/update_feed_selection_test.dart
git commit -m "feat(auto-update): select the update feed by release channel"
```

---

### Task 4: Updates card — channel selector, opt-in dialog, localization

Rebuilds `_buildUpdatesCard` (settings_page.dart:2795) with a channel row and localizes the card's existing hardcoded strings in the same pass.

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (`_buildUpdatesCard`, `_AboutSectionContentState`, the `'Updates'` header at :2742)
- Modify: `lib/l10n/arb/app_en.arb` + the 10 non-English ARBs; run `flutter gen-l10n`
- Test: `test/features/settings/presentation/pages/settings_page_test.dart`

**Interfaces:**
- Consumes: `releaseChannelProvider`, `UpdatePreferences.setReleaseChannel`, `updateStatusProvider.notifier.checkForUpdate()`.

- [ ] **Step 1: Add ARB entries** to `app_en.arb` (alphabetical position among `settings_*`; placeholder metadata entries follow the file's existing `@key` pattern):

```json
  "settings_updates_automaticUpdates": "Automatic updates",
  "settings_updates_automaticUpdatesSubtitle": "Check for updates periodically",
  "settings_updates_betaDialogBody": "Beta builds are published from every change and may upgrade your dive log's database before the stable release does. Switching back to stable later will not downgrade the app, and all devices that sync together should use the same channel. A backup is taken automatically before any database upgrade.",
  "settings_updates_betaDialogConfirm": "Switch to Beta",
  "settings_updates_betaDialogTitle": "Receive beta updates?",
  "settings_updates_channel": "Update channel",
  "settings_updates_channelBeta": "Beta",
  "settings_updates_channelBetaSubtitle": "New builds from every change, ahead of stable",
  "settings_updates_channelStable": "Stable",
  "settings_updates_channelStableSubtitle": "Tested releases only",
  "settings_updates_checkForUpdates": "Check for Updates",
  "settings_updates_checking": "Checking...",
  "settings_updates_downloading": "Downloading... {progress}%",
  "settings_updates_error": "Error: {message}",
  "settings_updates_header": "Updates",
  "settings_updates_lastChecked": "Last checked",
  "settings_updates_never": "Never",
  "settings_updates_readyToInstall": "Version {version} ready to install",
  "settings_updates_stableSwitchNotice": "You will stay on this beta until the next stable release is newer than it.",
  "settings_updates_upToDate": "Up to date",
  "settings_updates_versionAvailable": "Version {version} available",
```

with `@`-metadata for `downloading` (`progress`, `int`... use `String` to match preformatted int: pass `(progress * 100).toInt().toString()`; declare type `String`), `error`, `readyToInstall`, `versionAvailable` (all `String` placeholders). Translate all keys into the 10 other ARBs (match each file's tone; `he`/`ar` are RTL — plain text, no directional characters needed). Run `flutter gen-l10n`.

- [ ] **Step 2: Write failing widget tests** (extend `settings_page_test.dart` using its `buildTestWidget`/`getOverrides` helpers plus the update-banner workarounds; the Updates card renders on the test host because `isAutoUpdateEnabled` is true off-store on desktop VMs):

```dart
    testWidgets('updates card shows the channel selector on stable', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 6));
      await tester.scrollUntilVisible(find.text('Update channel'), 300);
      expect(find.text('Update channel'), findsOneWidget);
      expect(find.text('Stable'), findsOneWidget);
    });

    testWidgets('switching to beta asks for confirmation first', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 6));
      await tester.scrollUntilVisible(find.text('Update channel'), 300);
      await tester.tap(find.text('Update channel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta').last);
      await tester.pumpAndSettle();
      expect(find.text('Receive beta updates?'), findsOneWidget);
    });
```

(Adapt the scroll target/velocity to the file's existing `scrollUntilVisible` idiom; check `getOverrides` seeds `sharedPreferencesProvider` — add `'auto_update_enabled': false` to its mock initial values for these tests.)

- [ ] **Step 3: Implement.** In `_AboutSectionContentState`:
- Header: `'Updates'` → `context.l10n.settings_updates_header`.
- Rewrite `_buildUpdatesCard`'s `statusText` arms and tiles to the new l10n keys (`Up to date` → `context.l10n.settings_updates_upToDate`, etc.; `lastCheckText` `'Never'` → `settings_updates_never`).
- Insert the channel tile after the automatic-updates `SwitchListTile` (before the last-checked tile), using the file's picker idiom (`_showTimeFormatPicker` at :816 is the model):

```dart
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.alt_route),
            title: Text(context.l10n.settings_updates_channel),
            subtitle: Text(
              channel == ReleaseChannel.beta
                  ? context.l10n.settings_updates_channelBeta
                  : context.l10n.settings_updates_channelStable,
            ),
            onTap: () => _showChannelPicker(context),
          ),
```

where `channel` comes from `ref.watch(releaseChannelProvider)` at the top of `_buildUpdatesCard`, and:

```dart
  Future<void> _showChannelPicker(BuildContext context) async {
    final current = ref.read(releaseChannelProvider);
    final selected = await showDialog<ReleaseChannel>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.settings_updates_channel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final channel in ReleaseChannel.values)
              ListTile(
                title: Text(switch (channel) {
                  ReleaseChannel.stable =>
                    ctx.l10n.settings_updates_channelStable,
                  ReleaseChannel.beta => ctx.l10n.settings_updates_channelBeta,
                }),
                subtitle: Text(switch (channel) {
                  ReleaseChannel.stable =>
                    ctx.l10n.settings_updates_channelStableSubtitle,
                  ReleaseChannel.beta =>
                    ctx.l10n.settings_updates_channelBetaSubtitle,
                }),
                trailing: channel == current
                    ? Icon(
                        Icons.check,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(channel),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == current || !context.mounted) return;

    if (selected == ReleaseChannel.beta) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.settings_updates_betaDialogTitle),
          content: Text(ctx.l10n.settings_updates_betaDialogBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.settings_updates_betaDialogConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final prefs = ref.read(updatePreferencesProvider);
    await prefs.setReleaseChannel(selected);
    ref.invalidate(updatePreferencesProvider);
    // releaseChannelProvider and updateServiceProvider re-derive from the
    // invalidated preferences; the fresh service applies the new feed.
    if (!mounted) return;
    if (selected == ReleaseChannel.stable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.settings_updates_stableSwitchNotice),
        ),
      );
    }
    await ref.read(updateStatusProvider.notifier).checkForUpdate();
  }
```

Add imports for `release_channel.dart` (the providers import already exists).

- [ ] **Step 4: Run** `flutter gen-l10n && flutter test test/features/settings/presentation/pages/settings_page_test.dart && flutter test test/features/auto_update/`, fix fallout, then commit everything (lib + ARBs + generated l10n + tests):

```bash
git add -A lib/l10n lib/features/settings test/features/settings
git commit -m "feat(settings): add the stable/beta update channel selector"
```

---

### Task 5: Channel badge + store-build beta signposts

**Files:**
- Create: `lib/features/auto_update/domain/beta_program_links.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (version row :2681-2691 area; About card)
- Modify: ARBs (3 keys) + gen-l10n
- Test: `test/features/settings/presentation/pages/settings_page_test.dart`

- [ ] **Step 1: ARB keys:**

```json
  "settings_updates_channelBadgeBeta": "{version} (Beta)",
  "settings_updates_joinBeta": "Join the Beta",
  "settings_updates_joinBetaSubtitle": "Get new features early through the beta program",
```

(`channelBadgeBeta` has a `version` String placeholder.) Translate into all 10 locales; `flutter gen-l10n`.

- [ ] **Step 2: `beta_program_links.dart`** — empty constants until Phase 4 creates the store artifacts; empty string hides the UI:

```dart
/// Public enrollment links for the beta program. Empty until the TestFlight
/// public link and Play open-testing track exist (release-channels Phase 4);
/// the Join-the-Beta tiles hide themselves while these are empty.
const kTestFlightBetaUrl = '';
const kPlayBetaOptInUrl = '';
```

- [ ] **Step 3: Version row badge** — in the `versionString` computation (settings_page.dart:2682-2691), after building `version`, wrap:

```dart
        final base = context.l10n.settings_about_version(version);
        final isBeta =
            UpdateChannelConfig.isAutoUpdateEnabled &&
            ref.read(releaseChannelProvider) == ReleaseChannel.beta;
        return isBeta
            ? context.l10n.settings_updates_channelBadgeBeta(base)
            : base;
```

(Change `ref.read` to a `ref.watch` hoisted above the `when` if the analyzer flags read-in-build; watching is correct here.)

- [ ] **Step 4: Signpost tiles** — in the About card's `Column`, after the license tile, add (visible only on store builds with a link configured):

```dart
                if (!UpdateChannelConfig.isAutoUpdateEnabled &&
                    _betaEnrollUrl.isNotEmpty) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.science_outlined),
                    title: Text(context.l10n.settings_updates_joinBeta),
                    subtitle: Text(
                      context.l10n.settings_updates_joinBetaSubtitle,
                    ),
                    onTap: () => launchUrl(
                      Uri.parse(_betaEnrollUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
```

with a small getter on the state class:

```dart
  String get _betaEnrollUrl {
    if (Platform.isIOS || Platform.isMacOS) return kTestFlightBetaUrl;
    if (Platform.isAndroid) return kPlayBetaOptInUrl;
    return '';
  }
```

Imports: `dart:io` (already imported in settings_page? verify), `beta_program_links.dart`, `url_launcher` (already used at :66).

- [ ] **Step 5: Widget test** — badge only (signposts are invisible until Phase 4 fills the constants, and store-build gating cannot flip in a test VM):

```dart
    testWidgets('version row shows a beta badge when on the beta channel', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'auto_update_enabled': false,
        'update_release_channel': 'beta',
      });
      // rebuild overrides from these prefs per the file's helper pattern
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(seconds: 6));
      await tester.scrollUntilVisible(find.textContaining('(Beta)'), 300);
      expect(find.textContaining('(Beta)'), findsOneWidget);
    });
```

(Adapt to how `getOverrides` builds `sharedPreferencesProvider` — seed via its mechanism.)

- [ ] **Step 6: Run, commit:**

```bash
flutter gen-l10n && flutter test test/features/settings/presentation/pages/settings_page_test.dart
git add -A lib/l10n lib/features/settings lib/features/auto_update/domain/beta_program_links.dart test/features/settings
git commit -m "feat(settings): show the beta badge and store beta signposts"
```

---

### Task 6: "Peer requires update" sync banner

Completes Plan A's deferred item: `SyncResult.newerSchemaPeerDeviceIds` currently reaches the UI only as prose in `result.message`.

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (SyncState + result mapping ~:1064)
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (banner stack in `_buildSyncActions`, model: the `replaceAwaitingAdoption` card at :899-924)
- Modify: ARBs (1 key) + gen-l10n
- Test: `test/features/settings/presentation/pages/cloud_sync_page_test.dart`

- [ ] **Step 1: ARB key** (plural via placeholder count):

```json
  "settings_cloudSync_peerRequiresUpdate_banner": "{count, plural, =1{1 device syncs from a newer version of Submersion. Update this device to receive its latest changes.} other{{count} devices sync from a newer version of Submersion. Update this device to receive their latest changes.}}",
```

with `@` metadata (`count`, `num`, plural). Translate all 10 locales; `flutter gen-l10n`.

- [ ] **Step 2: Failing widget test** in `cloud_sync_page_test.dart`, following that file's existing pattern for seeding a `SyncState` (find its state-override helper; assert):

```dart
    expect(
      find.textContaining('newer version of Submersion'),
      findsOneWidget,
    );
```

for a state with `newerSchemaPeerCount: 2`, and `findsNothing` for the default state.

- [ ] **Step 3: Implement.**
- `SyncState`: add `final int newerSchemaPeerCount;` default `0` in the const constructor, plain `int? newerSchemaPeerCount` in `copyWith` (`?? this.newerSchemaPeerCount` — non-nullable field needs no sentinel).
- Result mapping: in the `result.isSuccess` branch (sync_providers.dart:1064-1072, the one that already maps `conflicts: result.conflictsFound`), add `newerSchemaPeerCount: result.newerSchemaPeerDeviceIds.length,`. Also reset to `0` where a fresh sync starts (the `copyWith(status: SyncStatus.syncing...)` transition) so a resolved peer clears the banner on the next clean sync.
- Banner in `_buildSyncActions`, inserted after the `firstSyncAwaitingConfirmation` banner:

```dart
          if (syncState.newerSchemaPeerCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.system_update_alt,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.settings_cloudSync_peerRequiresUpdate_banner(
                            syncState.newerSchemaPeerCount,
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
```

- [ ] **Step 4: Run + commit:**

```bash
flutter gen-l10n && flutter test test/features/settings/
git add -A lib/l10n lib/features/settings test/features/settings
git commit -m "feat(sync): banner when a peer publishes from a newer app version"
```

---

### Task 7: Full verification

- [ ] **Step 1:** `dart format . && flutter analyze && flutter test` — FULL suite (the new `updateServiceProvider` dependency on preferences is exactly the class of change that breaks distant consumer tests without an analyze warning). Known full-suite-only flaky backup tests: rerun the failing file in isolation once before blaming this work.
- [ ] **Step 2:** Manual smoke on macOS (`flutter run -d macos`): switch to Beta → confirm dialog → Sparkle offers the current beta from the `beta-builds` feed (a real `v1.7.2.4951` beta exists); switch back → snackbar; About row shows the badge.
- [ ] **Step 3:** Commit stragglers, if any.

## Deferred

- Filling `kTestFlightBetaUrl` / `kPlayBetaOptInUrl` (Phase 4, when the TestFlight public link and Play open-testing track exist).
- iOS TestFlight-receipt channel detection (needs native code; revisit in Phase 4 if wanted).
- Localizing the rest of settings_page's stray hardcoded strings (only the Updates card is in scope).

## Risks

- The updates card was fully hardcoded English; localizing it changes existing UI strings — any test asserting `'Check for Updates'` etc. must be updated in the same commit (Task 4 Step 4 catches these).
- `updateStatusProvider` holds a `Checking`/`UpdateAvailable` state from the OLD channel across a switch; the immediate `checkForUpdate()` after switching refreshes it, and `UpdateStatusNotifier` reads the service fresh via `ref.read(...future)` each check, so no stale service is retained.
