# Honest iCloud Availability in Unsupported macOS Builds — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the iCloud cloud-sync tile reflect real runtime capability so the Developer ID / no-sandbox build shows iCloud disabled with an honest reason instead of a misleading "sign in to iCloud" error.

**Architecture:** A fast, non-blocking native call (`getICloudAvailability`) reports `available | signedOut | unsupported` using the process's real entitlements (`SecTaskCopyValueForEntitlement` on `ubiquity-container-identifiers`) plus `ubiquityIdentityToken`. A `FutureProvider` surfaces it to `CloudSyncPage`, which uses it as the single source of truth for the iCloud tile's enabled state and for status-accurate, localized failure messages.

**Tech Stack:** Flutter, Dart, Riverpod (`FutureProvider`), Flutter method channels, Swift (macOS + iOS, Security.framework), Flutter `gen-l10n` ARB localization.

**Spec:** `docs/superpowers/specs/2026-06-16-icloud-unsupported-build-ux-design.md`

**Branch:** `feat/icloud-unsupported-build-ux` (already created off `main`).

**Commit policy:** Per-task commits on this feature branch are pre-authorized by plan approval. Commit messages use Conventional Commits and MUST NOT include any `Co-Authored-By` line.

## File Structure

| File | Responsibility | Change |
| --- | --- | --- |
| `lib/core/services/cloud_storage/icloud_native_service.dart` | Platform-channel facade for iCloud | Add `ICloudAvailability` enum, pure `availabilityFromStatus`, async `getAvailability` |
| `lib/features/settings/presentation/providers/sync_providers.dart` | Riverpod sync providers | Add `iCloudAvailabilityProvider` |
| `macos/Runner/ICloudContainerHandler.swift` | macOS native iCloud handler | Add `getICloudAvailability` + `hasUbiquityEntitlement` |
| `ios/Runner/ICloudContainerHandler.swift` | iOS native iCloud handler | Mirror the same method |
| `lib/l10n/arb/app_*.arb` (×11) | Localized strings | Add 4 keys, all locales; regenerate |
| `lib/features/settings/presentation/pages/cloud_sync_page.dart` | Cloud Sync UI | Gate iCloud tile by capability; localize failure messages |
| `test/core/services/cloud_storage/icloud_native_service_test.dart` | Unit test | New — status mapping |
| `test/features/settings/presentation/pages/cloud_sync_page_test.dart` | Widget test | Extend — tile gating |

---

### Task 1: `ICloudAvailability` enum, pure mapping, and `getAvailability()`

**Files:**
- Modify: `lib/core/services/cloud_storage/icloud_native_service.dart`
- Test: `test/core/services/cloud_storage/icloud_native_service_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `test/core/services/cloud_storage/icloud_native_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';

void main() {
  group('ICloudNativeService.availabilityFromStatus', () {
    test('maps "available"', () {
      expect(
        ICloudNativeService.availabilityFromStatus('available'),
        ICloudAvailability.available,
      );
    });

    test('maps "signedOut"', () {
      expect(
        ICloudNativeService.availabilityFromStatus('signedOut'),
        ICloudAvailability.signedOut,
      );
    });

    test('maps "unsupported"', () {
      expect(
        ICloudNativeService.availabilityFromStatus('unsupported'),
        ICloudAvailability.unsupported,
      );
    });

    test('maps an unrecognized string to unknown', () {
      expect(
        ICloudNativeService.availabilityFromStatus('wat'),
        ICloudAvailability.unknown,
      );
    });

    test('maps null to unknown', () {
      expect(
        ICloudNativeService.availabilityFromStatus(null),
        ICloudAvailability.unknown,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/cloud_storage/icloud_native_service_test.dart`
Expected: FAIL to compile — `ICloudAvailability` and `availabilityFromStatus` are undefined.

- [ ] **Step 3: Add the enum and methods**

In `lib/core/services/cloud_storage/icloud_native_service.dart`, add the enum at top level immediately after the imports (before `class ICloudNativeService`):

```dart
/// Runtime iCloud availability for the current build/device.
///
/// `unsupported` means this build lacks the iCloud (ubiquity-container)
/// entitlement — e.g. a Developer ID / no-sandbox distribution build — so
/// iCloud can never work here regardless of the user's iCloud account.
enum ICloudAvailability { available, signedOut, unsupported, unknown }
```

Then inside `class ICloudNativeService`, immediately after the `getContainerPath()` method, add:

```dart
  /// Pure mapping from the native status string to [ICloudAvailability].
  /// Extracted so it can be unit-tested independently of `dart:io` Platform.
  static ICloudAvailability availabilityFromStatus(String? status) {
    return switch (status) {
      'available' => ICloudAvailability.available,
      'signedOut' => ICloudAvailability.signedOut,
      'unsupported' => ICloudAvailability.unsupported,
      _ => ICloudAvailability.unknown,
    };
  }

  /// Reports iCloud availability for the current build/device.
  ///
  /// Non-blocking on the native side (it does not resolve the container URL),
  /// so it cannot hang. Returns [ICloudAvailability.unknown] on any channel
  /// error or unmirrored platform, which the UI treats optimistically.
  static Future<ICloudAvailability> getAvailability() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return ICloudAvailability.unsupported;
    }
    try {
      final status = await _channel.invokeMethod<String>(
        'getICloudAvailability',
      );
      return availabilityFromStatus(status);
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to get iCloud availability: $e',
        stackTrace: stackTrace,
      );
      return ICloudAvailability.unknown;
    }
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/services/cloud_storage/icloud_native_service_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/cloud_storage/icloud_native_service.dart test/core/services/cloud_storage/icloud_native_service_test.dart
git commit -m "feat(sync): add ICloudAvailability status to ICloudNativeService"
```

---

### Task 2: `iCloudAvailabilityProvider`

**Files:**
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart`

- [ ] **Step 1: Add the import**

In `lib/features/settings/presentation/providers/sync_providers.dart`, add this import alongside the other `cloud_storage` imports (after the existing `icloud_storage_provider.dart` import):

```dart
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
```

- [ ] **Step 2: Add the provider**

Immediately after `syncDataSerializerProvider` (the `Provider<SyncDataSerializer>` near the top of the file), add:

```dart
/// Runtime iCloud availability for the current build/device. Drives the iCloud
/// provider tile's enabled state and its connection-failure messaging.
final iCloudAvailabilityProvider = FutureProvider<ICloudAvailability>((
  ref,
) async {
  return ICloudNativeService.getAvailability();
});
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/features/settings/presentation/providers/sync_providers.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/presentation/providers/sync_providers.dart
git commit -m "feat(sync): expose iCloudAvailabilityProvider"
```

---

### Task 3: Native macOS `getICloudAvailability`

**Files:**
- Modify: `macos/Runner/ICloudContainerHandler.swift`

- [ ] **Step 1: Add the Security import**

At the top of `macos/Runner/ICloudContainerHandler.swift`, after `import FlutterMacOS`, add:

```swift
import Security
```

- [ ] **Step 2: Add the method-channel case**

In the `handle(_:result:)` switch, add this case immediately before `default:`:

```swift
        case "getICloudAvailability":
            getICloudAvailability(result: result)
```

- [ ] **Step 3: Add the implementation**

Immediately after the `getContainerPath(identifier:result:)` method, add:

```swift
    /// Reports iCloud availability without resolving the container URL (which
    /// can block). Distinguishes a build lacking the iCloud entitlement
    /// ("unsupported") from a signed-out iCloud account ("signedOut").
    private func getICloudAvailability(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let status: String
            if !self.hasUbiquityEntitlement() {
                status = "unsupported"
            } else if FileManager.default.ubiquityIdentityToken == nil {
                status = "signedOut"
            } else {
                status = "available"
            }
            DispatchQueue.main.async { result(status) }
        }
    }

    /// Whether this process carries the iCloud ubiquity-container entitlement.
    /// Developer ID / no-sandbox builds do not, so iCloud can never work there.
    private func hasUbiquityEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let key = "com.apple.developer.ubiquity-container-identifiers" as CFString
        let value = SecTaskCopyValueForEntitlement(task, key, nil)
        if let identifiers = value as? [String] {
            return !identifiers.isEmpty
        }
        return value != nil
    }
```

- [ ] **Step 4: Verify the macOS app compiles**

Run: `flutter build macos --debug`
Expected: Build succeeds (Swift compiles; no signing required for a local debug build).

- [ ] **Step 5: Commit**

```bash
git add macos/Runner/ICloudContainerHandler.swift
git commit -m "feat(sync): add native getICloudAvailability on macOS"
```

---

### Task 4: Native iOS `getICloudAvailability`

**Files:**
- Modify: `ios/Runner/ICloudContainerHandler.swift`

- [ ] **Step 1: Add the Security import**

At the top of `ios/Runner/ICloudContainerHandler.swift`, after `import UIKit`, add:

```swift
import Security
```

- [ ] **Step 2: Add the method-channel case**

In the `handle(_:result:)` switch, add this case immediately before `default:`:

```swift
        case "getICloudAvailability":
            getICloudAvailability(result: result)
```

- [ ] **Step 3: Add the implementation**

Immediately after the iOS handler's `getContainerPath(identifier:result:)` method, add the identical implementation:

```swift
    /// Reports iCloud availability without resolving the container URL (which
    /// can block). Distinguishes a build lacking the iCloud entitlement
    /// ("unsupported") from a signed-out iCloud account ("signedOut").
    private func getICloudAvailability(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let status: String
            if !self.hasUbiquityEntitlement() {
                status = "unsupported"
            } else if FileManager.default.ubiquityIdentityToken == nil {
                status = "signedOut"
            } else {
                status = "available"
            }
            DispatchQueue.main.async { result(status) }
        }
    }

    /// Whether this process carries the iCloud ubiquity-container entitlement.
    private func hasUbiquityEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let key = "com.apple.developer.ubiquity-container-identifiers" as CFString
        let value = SecTaskCopyValueForEntitlement(task, key, nil)
        if let identifiers = value as? [String] {
            return !identifiers.isEmpty
        }
        return value != nil
    }
```

- [ ] **Step 4: Commit**

(iOS compilation requires a macOS+Xcode iOS toolchain; if unavailable in the execution environment, rely on the macOS build from Task 3 for Swift-syntax confidence and verify iOS in the manual pass. Do not skip the file change.)

```bash
git add ios/Runner/ICloudContainerHandler.swift
git commit -m "feat(sync): add native getICloudAvailability on iOS"
```

---

### Task 5: Localized strings (all locales) + regenerate

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (+ `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`)
- Generated (do not hand-edit): `lib/l10n/arb/app_localizations*.dart`

The four new keys have no placeholders, so they need no `@`-metadata blocks. In each ARB file, insert the four key/value lines into the JSON object (placement is free as long as JSON stays valid; inserting just after the existing `"settings_cloudSync_provider_connectionFailed": ...,` line — present in every locale — is a safe anchor).

- [ ] **Step 1: Add keys to `app_en.arb`**

```json
  "settings_cloudSync_error_icloudSignedOut": "iCloud is not available. Please sign in to iCloud in System Settings.",
  "settings_cloudSync_error_icloudUnknown": "Couldn't reach iCloud. Please try again.",
  "settings_cloudSync_error_icloudUnsupported": "iCloud sync isn't available in this build of Submersion. Use S3 sync, or the App Store version.",
  "settings_cloudSync_provider_icloud_unsupportedSubtitle": "Not available in this build — use S3 or the App Store version",
```

- [ ] **Step 2: Add the translated keys to each non-`en` ARB**

`app_ar.arb`:
```json
  "settings_cloudSync_error_icloudSignedOut": "iCloud غير متوفر. يُرجى تسجيل الدخول إلى iCloud من إعدادات النظام.",
  "settings_cloudSync_error_icloudUnknown": "تعذّر الوصول إلى iCloud. حاول مرة أخرى.",
  "settings_cloudSync_error_icloudUnsupported": "مزامنة iCloud غير متوفرة في هذا الإصدار من Submersion. استخدم مزامنة S3 أو نسخة App Store.",
  "settings_cloudSync_provider_icloud_unsupportedSubtitle": "غير متوفر في هذا الإصدار — استخدم S3 أو نسخة App Store",
```

`app_de.arb`:
```json
  "settings_cloudSync_error_icloudSignedOut": "iCloud ist nicht verfügbar. Bitte melde dich in den Systemeinstellungen bei iCloud an.",
  "settings_cloudSync_error_icloudUnknown": "iCloud konnte nicht erreicht werden. Bitte versuche es erneut.",
  "settings_cloudSync_error_icloudUnsupported": "iCloud-Synchronisierung ist in diesem Build von Submersion nicht verfügbar. Verwende die S3-Synchronisierung oder die App-Store-Version.",
  "settings_cloudSync_provider_icloud_unsupportedSubtitle": "In diesem Build nicht verfügbar – verwende S3 oder die App-Store-Version",
```

`app_es.arb`:
```json
  "settings_cloudSync_error_icloudSignedOut": "iCloud no está disponible. Inicia sesión en iCloud en Ajustes del Sistema.",
  "settings_cloudSync_error_icloudUnknown": "No se pudo conectar con iCloud. Inténtalo de nuevo.",
  "settings_cloudSync_error_icloudUnsupported": "La sincronización con iCloud no está disponible en esta versión de Submersion. Usa la sincronización S3 o la versión de la App Store.",
  "settings_cloudSync_provider_icloud_unsupportedSubtitle": "No disponible en esta versión: usa S3 o la versión de la App Store",
```

`app_fr.arb`:
```json
  "settings_cloudSync_error_icloudSignedOut": "iCloud n'est pas disponible. Connectez-vous à iCloud dans les Réglages Système.",
  "settings_cloudSync_error_icloudUnknown": "Impossible de joindre iCloud. Veuillez réessayer.",
  "settings_cloudSync_error_icloudUnsupported": "La synchronisation iCloud n'est pas disponible dans cette version de Submersion. Utilisez la synchronisation S3 ou la version de l'App Store.",
  "settings_cloudSync_provider_icloud_unsupportedSubtitle": "Indisponible dans cette version — utilisez S3 ou la version de l'App Store",
```

`app_he.arb`:
```json
  "settings_cloudSync_error_icloudSignedOut": "iCloud אינו זמין. היכנס ל-iCloud דרך הגדרות המערכת.",
  "settings_cloudSync_error_icloudUnknown": "לא ניתן היה להגיע ל-iCloud. נסה שוב.",
  "settings_cloudSync_error_icloudUnsupported": "סנכרון iCloud אינו זמין בגרסה זו של Submersion. השתמש בסנכרון S3 או בגרסת App Store.",
  "settings_cloudSync_provider_icloud_unsupportedSubtitle": "לא זמין בגרסה זו — השתמש ב-S3 או בגרסת App Store",
```

`app_hu.arb`:
```json
  "settings_cloudSync_error_icloudSignedOut": "Az iCloud nem érhető el. Jelentkezz be az iCloudba a Rendszerbeállításokban.",
  "settings_cloudSync_error_icloudUnknown": "Nem sikerült elérni az iCloudot. Próbáld újra.",
  "settings_cloudSync_error_icloudUnsupported": "Az iCloud-szinkronizálás nem érhető el a Submersion ezen buildjében. Használd az S3-szinkronizálást vagy az App Store-verziót.",
  "settings_cloudSync_provider_icloud_unsupportedSubtitle": "Ebben a buildben nem érhető el – használj S3-at vagy az App Store-verziót",
```

`app_it.arb`:
```json
  "settings_cloudSync_error_icloudSignedOut": "iCloud non è disponibile. Accedi a iCloud nelle Impostazioni di Sistema.",
  "settings_cloudSync_error_icloudUnknown": "Impossibile raggiungere iCloud. Riprova.",
  "settings_cloudSync_error_icloudUnsupported": "La sincronizzazione iCloud non è disponibile in questa build di Submersion. Usa la sincronizzazione S3 o la versione dell'App Store.",
  "settings_cloudSync_provider_icloud_unsupportedSubtitle": "Non disponibile in questa build: usa S3 o la versione dell'App Store",
```

`app_nl.arb`:
```json
  "settings_cloudSync_error_icloudSignedOut": "iCloud is niet beschikbaar. Log in bij iCloud in Systeeminstellingen.",
  "settings_cloudSync_error_icloudUnknown": "Kan iCloud niet bereiken. Probeer het opnieuw.",
  "settings_cloudSync_error_icloudUnsupported": "iCloud-synchronisatie is niet beschikbaar in deze build van Submersion. Gebruik S3-synchronisatie of de App Store-versie.",
  "settings_cloudSync_provider_icloud_unsupportedSubtitle": "Niet beschikbaar in deze build — gebruik S3 of de App Store-versie",
```

`app_pt.arb`:
```json
  "settings_cloudSync_error_icloudSignedOut": "O iCloud não está disponível. Inicie sessão no iCloud nas Definições do Sistema.",
  "settings_cloudSync_error_icloudUnknown": "Não foi possível aceder ao iCloud. Tente novamente.",
  "settings_cloudSync_error_icloudUnsupported": "A sincronização do iCloud não está disponível nesta versão do Submersion. Use a sincronização S3 ou a versão da App Store.",
  "settings_cloudSync_provider_icloud_unsupportedSubtitle": "Indisponível nesta versão — use o S3 ou a versão da App Store",
```

`app_zh.arb`:
```json
  "settings_cloudSync_error_icloudSignedOut": "iCloud 不可用。请在“系统设置”中登录 iCloud。",
  "settings_cloudSync_error_icloudUnknown": "无法连接 iCloud。请重试。",
  "settings_cloudSync_error_icloudUnsupported": "此 Submersion 版本不支持 iCloud 同步。请使用 S3 同步或 App Store 版本。",
  "settings_cloudSync_provider_icloud_unsupportedSubtitle": "此版本不可用 — 请使用 S3 或 App Store 版本",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: Regenerates `lib/l10n/arb/app_localizations*.dart` with the four new getters, no errors. (If any locale is missing a key, gen-l10n prints an "untranslated message" warning — add the missing key.)

- [ ] **Step 4: Verify analyze is clean**

Run: `flutter analyze`
Expected: No issues (the generated getters now exist).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb/
git commit -m "feat(l10n): add iCloud availability strings for all locales"
```

---

### Task 6: Gate the iCloud tile and localize failure messages

**Files:**
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart`
- Test: `test/features/settings/presentation/pages/cloud_sync_page_test.dart` (extend)

- [ ] **Step 1: Add the failing widget tests**

In `test/features/settings/presentation/pages/cloud_sync_page_test.dart`:

(a) Add the import near the other `submersion` imports:

```dart
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
```

(b) Add an `iCloudAvailability` parameter to the `pumpPage` helper signature (default keeps existing tests enabled and host-independent):

```dart
    ICloudAvailability iCloudAvailability = ICloudAvailability.available,
```

(c) Add this override inside the `ProviderScope(overrides: [...])` list in `pumpPage` (e.g. right after the `selectedCloudProviderTypeProvider` override):

```dart
          iCloudAvailabilityProvider.overrideWith(
            (ref) async => iCloudAvailability,
          ),
```

(d) Add this test group at the end of `main()`:

```dart
  group('CloudSyncPage - iCloud availability', () {
    testWidgets('disables the iCloud tile when the build is unsupported', (
      tester,
    ) async {
      await pumpPage(
        tester,
        iCloudAvailability: ICloudAvailability.unsupported,
      );

      final tile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('iCloud'),
          matching: find.byType(ListTile),
        ),
      );
      expect(tile.enabled, isFalse);
    });

    testWidgets('enables the iCloud tile when available', (tester) async {
      await pumpPage(tester, iCloudAvailability: ICloudAvailability.available);

      final tile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('iCloud'),
          matching: find.byType(ListTile),
        ),
      );
      expect(tile.enabled, isTrue);
    });

    testWidgets(
      'shows the build-specific subtitle when unsupported',
      (tester) async {
        await pumpPage(
          tester,
          iCloudAvailability: ICloudAvailability.unsupported,
        );

        expect(
          find.text(
            'Not available in this build — use S3 or the App Store version',
          ),
          findsOneWidget,
        );
      },
      // The build-vs-platform subtitle wording depends on dart:io Platform,
      // so the exact text is only asserted on Apple hosts.
      skip: !(Platform.isIOS || Platform.isMacOS),
    );
  });
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `flutter test test/features/settings/presentation/pages/cloud_sync_page_test.dart --plain-name "iCloud availability"`
Expected: FAIL — the tile is still gated by `Platform.isIOS || Platform.isMacOS`, so `tile.enabled` is `false` on a non-Apple host even for `available`, and the unsupported subtitle text is absent.

- [ ] **Step 3: Add the enum import to the page**

In `lib/features/settings/presentation/pages/cloud_sync_page.dart`, add alongside the other `core/services/cloud_storage` imports:

```dart
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
```

- [ ] **Step 4: Gate the iCloud tile by capability**

In `_buildProviderSection`, replace the iCloud `_buildProviderTile(...)` call (currently passing `isAvailable: Platform.isIOS || Platform.isMacOS`) with capability-driven logic. Insert the computed values at the top of `_buildProviderSection` (before the `return Column(`):

```dart
    final l10n = context.l10n;
    final iCloudAvailability = ref
        .watch(iCloudAvailabilityProvider)
        .valueOrNull;
    final iCloudUnsupported =
        iCloudAvailability == ICloudAvailability.unsupported;
    final iCloudDisabledSubtitle = (Platform.isIOS || Platform.isMacOS)
        ? l10n.settings_cloudSync_provider_icloud_unsupportedSubtitle
        : l10n.settings_cloudSync_provider_notAvailable;
```

Then change the iCloud tile call to:

```dart
        _buildProviderTile(
          context,
          ref,
          provider: CloudProviderType.icloud,
          title: 'iCloud',
          subtitle: 'Sync via Apple iCloud',
          icon: Icons.cloud,
          isSelected: selectedProvider == CloudProviderType.icloud,
          isAvailable: !iCloudUnsupported,
          disabledSubtitle: iCloudDisabledSubtitle,
        ),
```

- [ ] **Step 5: Add `disabledSubtitle` to `_buildProviderTile` and localize its subtitle**

Change the `_buildProviderTile` signature to add the new optional named parameter:

```dart
  Widget _buildProviderTile(
    BuildContext context,
    WidgetRef ref, {
    required CloudProviderType provider,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isAvailable,
    String? disabledSubtitle,
  }) {
```

Inside `_buildProviderTile`, add `final l10n = context.l10n;` as the first line of the method body, and replace the subtitle `Text(...)` (currently `isAvailable ? subtitle : 'Not available on this platform'`) with:

```dart
        subtitle: Text(
          isAvailable
              ? subtitle
              : (disabledSubtitle ??
                    l10n.settings_cloudSync_provider_notAvailable),
        ),
```

- [ ] **Step 6: Localize the connection-failure message by status**

In `_selectProvider`, replace the `catch (e)` block's snackbar content (currently `'${cloudProvider.providerName} connection failed: $e'`) so it calls a new helper:

```dart
    } catch (e) {
      // Clear the provider selection on failure
      ref.read(selectedCloudProviderTypeProvider.notifier).state = null;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _connectionErrorMessage(
                context,
                ref,
                provider,
                cloudProvider.providerName,
                e,
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
```

Then add this helper method immediately after `_selectProvider`:

```dart
  /// Localized connection-failure message. For iCloud, picks wording that
  /// matches the real availability state instead of leaking the raw exception.
  String _connectionErrorMessage(
    BuildContext context,
    WidgetRef ref,
    CloudProviderType provider,
    String providerName,
    Object error,
  ) {
    final l10n = context.l10n;
    if (provider == CloudProviderType.icloud) {
      final availability = ref.read(iCloudAvailabilityProvider).valueOrNull;
      switch (availability) {
        case ICloudAvailability.unsupported:
          return l10n.settings_cloudSync_error_icloudUnsupported;
        case ICloudAvailability.signedOut:
          return l10n.settings_cloudSync_error_icloudSignedOut;
        case ICloudAvailability.unknown:
        case null:
          return l10n.settings_cloudSync_error_icloudUnknown;
        case ICloudAvailability.available:
          break; // genuine failure despite availability — fall through
      }
    }
    return l10n.settings_cloudSync_provider_connectionFailed(
      providerName,
      error.toString(),
    );
  }
```

- [ ] **Step 7: Run the new tests to verify they pass**

Run: `flutter test test/features/settings/presentation/pages/cloud_sync_page_test.dart`
Expected: PASS (the new group passes; the Apple-only subtitle test runs on macOS, skips on Linux; all pre-existing tests still pass).

- [ ] **Step 8: Commit**

```bash
git add lib/features/settings/presentation/pages/cloud_sync_page.dart test/features/settings/presentation/pages/cloud_sync_page_test.dart
git commit -m "feat(sync): gate iCloud tile by capability and localize failures"
```

---

### Task 7: Whole-project verification + manual device pass

**Files:** none (verification only)

- [ ] **Step 1: Format**

Run: `dart format lib/ test/ macos/ ios/`
Expected: Reformats nothing of substance, or restages formatted files. If it changes files, `git add -A && git commit -m "style: dart format"`.

- [ ] **Step 2: Whole-project analyze (do NOT pipe to tail)**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Run the directly-affected test files**

Run: `flutter test test/core/services/cloud_storage/icloud_native_service_test.dart test/features/settings/presentation/pages/cloud_sync_page_test.dart`
Expected: All pass.

- [ ] **Step 4: Build the sandboxed macOS app (Swift compile + smoke)**

Run: `flutter build macos --debug`
Expected: Succeeds.

- [ ] **Step 5: Manual verification (record results in the PR/commit)**

1. **No-sandbox build** (`./scripts/release/build_nosandbox_macos.sh`, then run the produced `.app`): the iCloud tile is **disabled** with subtitle "Not available in this build — use S3 or the App Store version"; S3 still selectable.
2. **Sandboxed dev build** (`flutter run -d macos`): iCloud tile **enabled**; with iCloud signed in it connects; signed out of iCloud in System Settings → tap shows "Please sign in to iCloud in System Settings."
3. **iPhone** (`flutter run -d <ios>`): iCloud tile enabled and connects (regression check).

---

## Self-Review

**Spec coverage:**
- Three-state behavior (available/signedOut/unsupported) → Tasks 1, 3, 4, 6. ✓
- Non-blocking native status via entitlement + token → Tasks 3, 4. ✓
- `unknown` graceful-degradation bucket → Task 1 (`getAvailability` catch), Task 6 (treated optimistically / unknown message). ✓
- Disabled tile + honest subtitle for unsupported → Task 6 Steps 4-5. ✓
- Localized, status-accurate failure messages → Task 6 Step 6 + Task 5. ✓
- l10n across en + 10 locales, regenerated → Task 5. ✓
- TDD unit + widget tests; native paths manual → Tasks 1, 6, 7. ✓
- iOS mirror → Task 4. ✓

**Placeholder scan:** No TBD/TODO; every code and command step is concrete. ✓

**Type consistency:** `ICloudAvailability { available, signedOut, unsupported, unknown }` and the status strings `"available"/"signedOut"/"unsupported"` are identical across Dart (Task 1), Swift (Tasks 3-4), provider (Task 2), and UI/tests (Task 6). `iCloudAvailabilityProvider`, `availabilityFromStatus`, `getAvailability`, `_connectionErrorMessage`, and `disabledSubtitle` names match across tasks. l10n keys (`settings_cloudSync_error_icloudSignedOut/Unknown/Unsupported`, `settings_cloudSync_provider_icloud_unsupportedSubtitle`) match between Task 5 and Task 6. ✓
