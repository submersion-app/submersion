# Cylinder Passports 1b: Scanning, Links and the Foreign Passport Implementation Plan (PR 2 of 6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A diver can scan a cylinder's QR label (or paste or open its link) and land on that cylinder's passport, or on a read-only passport for a tank they do not own, from which they can use it on a dive or add it to their gear; the dive editor can fill a tank by scanning its tag.

**Architecture:** One domain service resolves a tag string to an own cylinder, a foreign one, or not-a-tag. Three entry points feed it: a scan sheet (camera through `mobile_scanner` on iOS, Android and macOS, a paste field everywhere), the dive editor's tank card, and incoming links delivered by `app_links`. Own tags open the 1a passport page; foreign tags open a new restorable route whose actions build a dive tank prefill or adopt the cylinder into the diver's gear in one transaction.

**Tech Stack:** Flutter 3.47 (CI pin), Riverpod 3 (hand-written providers), go_router 17, Drift, `mobile_scanner` ^7.4.2, `app_links` ^7.2.1, `flutter gen-l10n`, `xml` for platform-file tests, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md`, sections 7, 9, 13.1, 13.2, 13.4, 13.5, 16, 19 and the "1b Scan and links" row of section 17. Phase 1a (PR #2364) is merged; its code under `lib/features/cylinder_passports/` is the base.

**Decisions made while planning (2026-09-26, by the maintainer):**
- Scanning a tag in the dive editor fills the tank's spec and gas mix and adds the cylinder to the dive's **gear list** (`_addGear`). It never writes `dive_tanks.equipment_id`, which stays owned by the transmitter registry. This replaces the spec's "a hit sets the tank's equipmentId" (section 7.2).
- Incoming links arrive through the **`app_links`** package, with Flutter's built-in deep linking switched off on iOS and Android. Flutter's built-in handler passes only path, query and fragment, so `submersion://c?...` (host `c`, empty path) became `?...` on iOS and was dropped on Android. This replaces the spec's "go_router `/c` routes reading the fragment" (section 13.2). No `/c` go_router route is added.

## Global Constraints

- No schema rung and no sync change in this PR.
- New dependencies, exactly: `mobile_scanner: ^7.4.2` and `app_links: ^7.2.1`. Nothing else.
- Tag strings: written form `https://submersion.app/c#<payload>`; accepted also `submersion://c?<payload>`, `http`, a `www.` host and any case, per `PassportPayloadCodec.extractQuery` from 1a. Only `/c` links are passport tags in this PR; `/f` (signed records) is PR 3 and is ignored here.
- The custom scheme is `submersion`, host `c`. The verified app-link host is `submersion.app` with path `/c`.
- Every value with a unit is displayed through `UnitFormatter`; dates through `UnitFormatter.formatDate` (guard: `test/architecture/preference_aware_date_format_test.dart`). Date pickers only through `showAppDatePicker` (guard: `test/shared/widgets/app_date_picker_adoption_test.dart`).
- New user-visible strings in all 11 locales (ar, de, en, es, fr, he, hu, it, nl, pt, zh). Non-English ARB files are not alphabetical: insert beside the anchor key each task names.
- Never use em-dashes, en-dashes as punctuation, double hyphens or spaced hyphens as punctuation, anywhere: code, comments, tests, ARB strings, commits, PR text.
- No mention of Claude, Claude Code or Anthropic in any commit, PR text, comment or file. No `Co-Authored-By` trailer.
- No emojis. Immutability. TDD: failing test first, watch it fail, then implement.
- `dart format .` before each commit. `flutter analyze` run on its own, never piped; infos are fatal in CI.
- Run specific test files per task; the full suite once, in Task 12. Never overlap two `flutter test` runs.
- Work in `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/github-issue-1797-4117fb` on branch `ericgriffin/cylinder-passports-1b-2335`. Stage explicit paths, never `git add -A` or `-u`.
- A bare `build` word in a Bash command is refused by the harness: put `flutter build ...` or `dart run build_runner build ...` in a script under the session scratchpad and run the script.
- Release prerequisite, not code: the Apple developer portal must have **Associated Domains** enabled for `app.submersion` and the iOS provisioning profiles regenerated before a signed iOS release carries the new entitlement. The PR body says so.
- The PR body must contain `Closes #2335` and `Refs #2333`.

## Review Focus

Inputs the spec implies and no obvious test covers, most likely to bite first. Each has its test pinned to the owning task.

1. `app_links` delivers the cold-start link through its stream as well as on request, and the camera reports the same code many times a second: a tag must open **once**, not stack two passports (Task 5 "the sheet closes once", Task 10 "a repeated link opens once").
2. A link arrives before any diver exists (fresh install, tapped from a label): it must wait and open after setup, not be lost and not open over the setup wizard (Task 10 "a link before setup waits and opens once ready").
3. A link that is not a passport tag reaches the app (an OAuth callback on the same scheme set, a future `/f` record link, another page on submersion.app): it must be ignored, never navigate or show an error (Task 10 "other links are ignored").
4. An identity-only tag (an NTAG213 keeps only `f`, `p`, `w` when the name is long): the foreign passport must say it carries no details, and "Use on a dive" must keep the dive's default tank spec rather than blanking it (Task 4 "an identity-only tag", Task 6 "an identity-only tag keeps the default tank").
5. Adopting a tag whose id a live cylinder already holds (a family member's, or a race with another device): nothing may be created, no orphan tank row, and the diver is told which cylinder holds it (Task 7 "a held tag creates nothing").

---

## File Structure

| File | Responsibility |
| --- | --- |
| `pubspec.yaml`, `pubspec.lock` (modify) | `mobile_scanner`, `app_links` |
| `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements` (modify) | deep linking off, `submersion` scheme, camera string, associated domain |
| `macos/Runner/Info.plist`, `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements` (modify) | `submersion` scheme, camera string, camera entitlement |
| `android/app/src/main/AndroidManifest.xml` (modify) | deep linking off, verified `/c` app link, `submersion://c`, camera permission, camera not required |
| `test/platform/passport_links_config_test.dart` (create) | file assertions for all of the above |
| `lib/l10n/arb/app_*.arb` (modify, 11) | new strings |
| `lib/features/cylinder_passports/domain/services/passport_resolver.dart` (create) | `PassportResolution`, `PassportResolver` |
| `lib/features/cylinder_passports/domain/services/passport_attribute_keys.dart` (create) | tag enum to equipment attribute choice keys |
| `lib/features/cylinder_passports/presentation/pages/foreign_passport_page.dart` (create) | read-only passport, its route helper, its actions |
| `lib/core/router/app_router.dart` (modify) | `/equipment/tag` route |
| `lib/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart` (create) | scan sheet, camera seam, launcher provider |
| `lib/features/cylinder_passports/presentation/widgets/passport_mobile_scanner.dart` (create) | the `mobile_scanner` camera view |
| `lib/features/cylinder_passports/presentation/utils/scan_cylinder_tag.dart` (create) | `resolveScannedTag`, `openScannedTag`, `scanAndOpenCylinderTag` |
| `lib/features/cylinder_passports/domain/services/passport_dive_tank.dart` (create) | `tankFromPassport` |
| `lib/features/dive_log/domain/entities/dive_prefill.dart`, `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (modify) | `DivePrefill.tank`, applied on create; gear from a tank scan |
| `lib/features/cylinder_passports/data/services/passport_adoption_service.dart` (create) | "Add to my gear" in one transaction |
| `lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart` (modify) | `passportAdoptionServiceProvider` |
| `lib/features/equipment/presentation/pages/equipment_list_page.dart`, `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (modify) | "Scan a cylinder tag" in the three overflow menus |
| `lib/features/dive_log/presentation/widgets/tank_editor.dart`, `lib/features/dive_log/presentation/widgets/edit_sections/tank_row.dart` (modify) | tank card Scan |
| `lib/features/cylinder_passports/presentation/services/passport_link_dispatcher.dart` (create) | link source seam, filtering, dedupe, queue-until-ready |
| `lib/app.dart` (modify) | wires the dispatcher |
| `docs/import-formats/cylinder-passport-tag.md`, the spec, `docs/superpowers/specs/2026-09-26-cylinder-passports-1b-device-checklist.md` (modify, create) | docs and the device checklist |

---

### Task 1: Dependencies and platform wiring

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`, `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`, `macos/Runner/Info.plist`, `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements`, `android/app/src/main/AndroidManifest.xml`
- Create: `test/platform/passport_links_config_test.dart`

**Interfaces:**
- Produces: packages `mobile_scanner` and `app_links` importable; platform files that route `submersion://c` and verified `https://submersion.app/c` links to the app, allow the camera, and turn Flutter's own deep linking off.

- [ ] **Step 1: Write the failing platform-file test**

Create `test/platform/passport_links_config_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Guards the platform wiring for cylinder passport links and camera scanning
/// (issue #2335). File assertions, because CI never runs a signed build that
/// could exercise them: a missing key is invisible until a diver taps a label.

/// The value element that follows [key] in a plist's top-level dict.
XmlElement? plistValue(String path, String key) {
  final dict = XmlDocument.parse(
    File(path).readAsStringSync(),
  ).rootElement.getElement('dict')!;
  final children = dict.childElements.toList();
  for (var i = 0; i + 1 < children.length; i++) {
    if (children[i].name.local == 'key' &&
        children[i].innerText.trim() == key) {
      return children[i + 1];
    }
  }
  return null;
}

/// Every URL scheme a plist's CFBundleURLTypes registers.
Set<String> urlSchemes(String path) {
  final types = plistValue(path, 'CFBundleURLTypes');
  if (types == null) return const {};
  final schemes = <String>{};
  for (final dict in types.findElements('dict')) {
    final children = dict.childElements.toList();
    for (var i = 0; i + 1 < children.length; i++) {
      if (children[i].innerText.trim() == 'CFBundleURLSchemes') {
        schemes.addAll(
          children[i + 1].findElements('string').map((e) => e.innerText.trim()),
        );
      }
    }
  }
  return schemes;
}

void main() {
  group('iOS', () {
    const info = 'ios/Runner/Info.plist';
    const entitlements = 'ios/Runner/Runner.entitlements';

    test('Flutter deep linking is off, app_links owns links', () {
      expect(plistValue(info, 'FlutterDeepLinkingEnabled')?.name.local, 'false');
    });

    test('registers the submersion scheme', () {
      expect(urlSchemes(info), contains('submersion'));
    });

    test('the camera string mentions scanning cylinder labels', () {
      expect(
        plistValue(info, 'NSCameraUsageDescription')?.innerText,
        contains('cylinder'),
      );
    });

    test('claims submersion.app for universal links', () {
      final domains = plistValue(
        entitlements,
        'com.apple.developer.associated-domains',
      );
      expect(
        domains?.findElements('string').map((e) => e.innerText.trim()),
        contains('applinks:submersion.app'),
      );
    });
  });

  group('macOS', () {
    const info = 'macos/Runner/Info.plist';

    test('registers the submersion scheme', () {
      expect(urlSchemes(info), contains('submersion'));
    });

    test('explains camera use', () {
      expect(
        plistValue(info, 'NSCameraUsageDescription')?.innerText,
        contains('cylinder'),
      );
    });

    for (final file in [
      'macos/Runner/DebugProfile.entitlements',
      'macos/Runner/Release.entitlements',
    ]) {
      test('$file allows the camera', () {
        expect(
          plistValue(file, 'com.apple.security.device.camera')?.name.local,
          'true',
        );
      });
    }
  });

  group('Android', () {
    late XmlElement activity;
    late XmlElement manifest;
    const android = 'http://schemas.android.com/apk/res/android';

    setUpAll(() {
      manifest = XmlDocument.parse(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      ).rootElement;
      activity = manifest
          .findAllElements('activity')
          .firstWhere(
            (a) => a.getAttribute('name', namespace: android) == '.MainActivity',
          );
    });

    Iterable<XmlElement> viewFiltersWithScheme(String scheme) => activity
        .findElements('intent-filter')
        .where(
          (f) => f
              .findElements('data')
              .any((d) => d.getAttribute('scheme', namespace: android) == scheme),
        );

    test('Flutter deep linking is off, app_links owns links', () {
      final meta = activity.findElements('meta-data').firstWhere(
        (m) =>
            m.getAttribute('name', namespace: android) ==
            'flutter_deeplinking_enabled',
      );
      expect(meta.getAttribute('value', namespace: android), 'false');
    });

    test('verifies https://submersion.app/c as an app link', () {
      final filter = viewFiltersWithScheme('https').single;
      expect(filter.getAttribute('autoVerify', namespace: android), 'true');
      final data = filter.findElements('data').single;
      expect(data.getAttribute('host', namespace: android), 'submersion.app');
      expect(data.getAttribute('path', namespace: android), '/c');
    });

    test('opens submersion://c links', () {
      final data = viewFiltersWithScheme('submersion').single.findElements('data').single;
      expect(data.getAttribute('host', namespace: android), 'c');
    });

    test('asks for the camera without requiring one', () {
      expect(
        manifest.findElements('uses-permission').map(
          (e) => e.getAttribute('name', namespace: android),
        ),
        contains('android.permission.CAMERA'),
      );
      final feature = manifest.findElements('uses-feature').firstWhere(
        (e) =>
            e.getAttribute('name', namespace: android) ==
            'android.hardware.camera',
      );
      expect(feature.getAttribute('required', namespace: android), 'false');
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/platform/passport_links_config_test.dart`
Expected: every test fails (keys and filters absent).

- [ ] **Step 3: Add the packages**

Run: `flutter pub add mobile_scanner:^7.4.2 app_links:^7.2.1`
Expected: both resolve; `git diff pubspec.yaml` shows the two lines. If resolution fails on the SDK constraint, stop and report; do not loosen other constraints.

- [ ] **Step 4: Edit the iOS files**

In `ios/Runner/Info.plist`, inside the top-level `<dict>`, add:

```xml
	<key>FlutterDeepLinkingEnabled</key>
	<false/>
```

Append this dict to the `CFBundleURLTypes` array:

```xml
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Viewer</string>
			<key>CFBundleURLName</key>
			<string>app.submersion.passport</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>submersion</string>
			</array>
		</dict>
```

Replace the `NSCameraUsageDescription` string with:

```xml
	<string>Submersion uses the camera to take photos of dive sites and marine life, and to scan cylinder labels.</string>
```

In `ios/Runner/Runner.entitlements`, inside the `<dict>`, add:

```xml
	<key>com.apple.developer.associated-domains</key>
	<array>
		<string>applinks:submersion.app</string>
	</array>
```

- [ ] **Step 5: Edit the macOS files**

In `macos/Runner/Info.plist`, append the same `app.submersion.passport` dict to `CFBundleURLTypes`, and inside the top-level `<dict>` add:

```xml
	<key>NSCameraUsageDescription</key>
	<string>Submersion uses the camera to scan cylinder labels.</string>
```

In both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`, inside the `<dict>`, add:

```xml
	<key>com.apple.security.device.camera</key>
	<true/>
```

- [ ] **Step 6: Edit the Android manifest**

In `android/app/src/main/AndroidManifest.xml`, beside the existing `<uses-permission>` entries at the top of `<manifest>`, add:

```xml
    <uses-permission android:name="android.permission.CAMERA" />
    <!-- Scanning cylinder labels is optional; devices without a camera
         must still install the app. -->
    <uses-feature android:name="android.hardware.camera" android:required="false" />
```

Inside the `.MainActivity` `<activity>`, after the `NormalTheme` meta-data, add:

```xml
            <!-- app_links delivers passport links; Flutter's own deep linking
                 would push the same link to the router a second time. -->
            <meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
```

After the last existing intent-filter of `.MainActivity`, add:

```xml
            <!-- Cylinder passport tags printed as https links (issue #2335). -->
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="https" android:host="submersion.app" android:path="/c"/>
            </intent-filter>
            <!-- The accepted custom-scheme form, submersion://c?<payload>. -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="submersion" android:host="c"/>
            </intent-filter>
```

- [ ] **Step 7: Run the test**

Run: `flutter test test/platform/passport_links_config_test.dart test/macos_entitlements_test.dart`
Expected: all pass.

- [ ] **Step 8: Prove the native builds still link**

Write `scratch_native.sh` in the session scratchpad containing:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/github-issue-1797-4117fb
flutter build macos --debug && flutter build ios --simulator --debug --no-codesign
```

Run: `bash <scratchpad>/scratch_native.sh`
Expected: both succeed. If CocoaPods reports a deployment-target conflict for `mobile_scanner` (iOS 15.0 and macOS 12.0 are the current floors), stop and report the required minimum instead of raising it. If pods are stale, run `pod install` in `ios/` and `macos/` and retry once.

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add pubspec.yaml pubspec.lock ios/Runner/Info.plist ios/Runner/Runner.entitlements macos/Runner/Info.plist macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements android/app/src/main/AndroidManifest.xml test/platform/passport_links_config_test.dart
git commit -m "feat(passports): scanner and link packages, platform wiring for tags

Refs #2335"
```

If `flutter pub add` changed `ios/Podfile.lock` or `macos/Podfile.lock` through the build step, stage those too.

---

### Task 2: Localized strings

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/l10n/` (existing guards)

**Interfaces:**
- Produces these getters, used by later tasks by exactly these names: `passport_scan_title`, `passport_scan_hint`, `passport_scan_cameraUnavailable`, `passport_scan_linkLabel`, `passport_scan_paste`, `passport_scan_open`, `passport_scan_openFailed`, `passport_scan_newerFormat`, `passport_scan_filledFrom(String name)`, `passport_foreign_title`, `passport_foreign_notInGear`, `passport_foreign_writtenOn(String date)`, `passport_foreign_noDetails`, `passport_foreign_o2Clean`, `passport_foreign_useOnDive`, `passport_foreign_addToGear`, `passport_foreign_addFailed`, `passport_foreign_defaultName`, `passport_foreign_serial(String serial)`.
- Reused from 1a, not re-added: `passport_tag_linkInvalid`, `passport_tag_linkInUse(name)`, `attrLabel_*`, `attrChoice_*`.

Anchor: insert each locale's block directly after that file's `"passport_tag_linked"` line (in `app_en.arb`, directly after it too; the three placeholder keys carry `@` blocks in English only).

- [ ] **Step 1: English (`app_en.arb`)**

```json
  "passport_scan_title": "Scan a cylinder tag",
  "passport_scan_hint": "Point the camera at the label, or paste the tag's link.",
  "passport_scan_cameraUnavailable": "The camera is not available here. Paste the tag's link instead.",
  "passport_scan_linkLabel": "Tag link",
  "passport_scan_paste": "Paste",
  "passport_scan_open": "Open",
  "passport_scan_openFailed": "Could not open the tag. Try again.",
  "passport_scan_newerFormat": "This tag was written by a newer version of Submersion. Some details may be missing.",
  "passport_scan_filledFrom": "Filled from {name}",
  "@passport_scan_filledFrom": {
    "placeholders": {
      "name": {"type": "String"}
    }
  },
  "passport_foreign_title": "Cylinder tag",
  "passport_foreign_notInGear": "This cylinder is not in your gear.",
  "passport_foreign_writtenOn": "As written on the tag on {date}",
  "@passport_foreign_writtenOn": {
    "placeholders": {
      "date": {"type": "String"}
    }
  },
  "passport_foreign_noDetails": "The tag carries no details beyond its identity.",
  "passport_foreign_o2Clean": "O2 clean when the tag was written",
  "passport_foreign_useOnDive": "Use on a dive",
  "passport_foreign_addToGear": "Add to my gear",
  "passport_foreign_addFailed": "Could not add the cylinder. Try again.",
  "passport_foreign_defaultName": "Cylinder",
  "passport_foreign_serial": "Serial {serial}",
  "@passport_foreign_serial": {
    "placeholders": {
      "serial": {"type": "String"}
    }
  },
```

- [ ] **Step 2: The other ten locales**

Insert, in the same key order, after each file's `"passport_tag_linked"` line (no `@` blocks):

`app_de.arb`
```json
  "passport_scan_title": "Flaschen-Tag scannen",
  "passport_scan_hint": "Kamera auf das Etikett richten oder den Link des Tags einfügen.",
  "passport_scan_cameraUnavailable": "Die Kamera ist hier nicht verfügbar. Stattdessen den Link des Tags einfügen.",
  "passport_scan_linkLabel": "Tag-Link",
  "passport_scan_paste": "Einfügen",
  "passport_scan_open": "Öffnen",
  "passport_scan_openFailed": "Der Tag konnte nicht geöffnet werden. Bitte erneut versuchen.",
  "passport_scan_newerFormat": "Dieser Tag wurde von einer neueren Submersion-Version geschrieben. Einige Angaben fehlen möglicherweise.",
  "passport_scan_filledFrom": "Übernommen von {name}",
  "passport_foreign_title": "Flaschen-Tag",
  "passport_foreign_notInGear": "Diese Flasche gehört nicht zur eigenen Ausrüstung.",
  "passport_foreign_writtenOn": "Laut Tag, geschrieben am {date}",
  "passport_foreign_noDetails": "Der Tag enthält außer seiner Kennung keine Angaben.",
  "passport_foreign_o2Clean": "O2-rein, als der Tag geschrieben wurde",
  "passport_foreign_useOnDive": "Für einen Tauchgang verwenden",
  "passport_foreign_addToGear": "Zu meiner Ausrüstung hinzufügen",
  "passport_foreign_addFailed": "Die Flasche konnte nicht hinzugefügt werden. Bitte erneut versuchen.",
  "passport_foreign_defaultName": "Flasche",
  "passport_foreign_serial": "Seriennummer {serial}",
```

`app_es.arb`
```json
  "passport_scan_title": "Escanear etiqueta de botella",
  "passport_scan_hint": "Apunta la cámara a la etiqueta o pega el enlace de la etiqueta.",
  "passport_scan_cameraUnavailable": "La cámara no está disponible aquí. Pega el enlace de la etiqueta.",
  "passport_scan_linkLabel": "Enlace de la etiqueta",
  "passport_scan_paste": "Pegar",
  "passport_scan_open": "Abrir",
  "passport_scan_openFailed": "No se pudo abrir la etiqueta. Inténtalo de nuevo.",
  "passport_scan_newerFormat": "Esta etiqueta la escribió una versión más reciente de Submersion. Puede que falten algunos datos.",
  "passport_scan_filledFrom": "Completado desde {name}",
  "passport_foreign_title": "Etiqueta de botella",
  "passport_foreign_notInGear": "Esta botella no está en tu equipo.",
  "passport_foreign_writtenOn": "Según la etiqueta escrita el {date}",
  "passport_foreign_noDetails": "La etiqueta no incluye datos aparte de su identificador.",
  "passport_foreign_o2Clean": "Limpia para O2 cuando se escribió la etiqueta",
  "passport_foreign_useOnDive": "Usar en una inmersión",
  "passport_foreign_addToGear": "Añadir a mi equipo",
  "passport_foreign_addFailed": "No se pudo añadir la botella. Inténtalo de nuevo.",
  "passport_foreign_defaultName": "Botella",
  "passport_foreign_serial": "N.º de serie {serial}",
```

`app_fr.arb`
```json
  "passport_scan_title": "Scanner l'étiquette d'une bouteille",
  "passport_scan_hint": "Pointez l'appareil photo vers l'étiquette ou collez le lien de l'étiquette.",
  "passport_scan_cameraUnavailable": "L'appareil photo n'est pas disponible ici. Collez plutôt le lien de l'étiquette.",
  "passport_scan_linkLabel": "Lien de l'étiquette",
  "passport_scan_paste": "Coller",
  "passport_scan_open": "Ouvrir",
  "passport_scan_openFailed": "Impossible d'ouvrir l'étiquette. Réessayez.",
  "passport_scan_newerFormat": "Cette étiquette a été écrite par une version plus récente de Submersion. Certains détails peuvent manquer.",
  "passport_scan_filledFrom": "Rempli depuis {name}",
  "passport_foreign_title": "Étiquette de bouteille",
  "passport_foreign_notInGear": "Cette bouteille ne fait pas partie de votre équipement.",
  "passport_foreign_writtenOn": "Selon l'étiquette écrite le {date}",
  "passport_foreign_noDetails": "L'étiquette ne contient aucun détail en dehors de son identifiant.",
  "passport_foreign_o2Clean": "Compatible O2 lors de l'écriture de l'étiquette",
  "passport_foreign_useOnDive": "Utiliser pour une plongée",
  "passport_foreign_addToGear": "Ajouter à mon équipement",
  "passport_foreign_addFailed": "Impossible d'ajouter la bouteille. Réessayez.",
  "passport_foreign_defaultName": "Bouteille",
  "passport_foreign_serial": "N° de série {serial}",
```

`app_it.arb`
```json
  "passport_scan_title": "Scansiona il tag della bombola",
  "passport_scan_hint": "Inquadra l'etichetta con la fotocamera o incolla il link del tag.",
  "passport_scan_cameraUnavailable": "La fotocamera non è disponibile qui. Incolla invece il link del tag.",
  "passport_scan_linkLabel": "Link del tag",
  "passport_scan_paste": "Incolla",
  "passport_scan_open": "Apri",
  "passport_scan_openFailed": "Impossibile aprire il tag. Riprova.",
  "passport_scan_newerFormat": "Questo tag è stato scritto da una versione più recente di Submersion. Alcuni dettagli potrebbero mancare.",
  "passport_scan_filledFrom": "Compilato da {name}",
  "passport_foreign_title": "Tag della bombola",
  "passport_foreign_notInGear": "Questa bombola non fa parte della tua attrezzatura.",
  "passport_foreign_writtenOn": "Come scritto sul tag il {date}",
  "passport_foreign_noDetails": "Il tag non contiene dettagli oltre al suo identificativo.",
  "passport_foreign_o2Clean": "Pulita per O2 quando il tag è stato scritto",
  "passport_foreign_useOnDive": "Usa in un'immersione",
  "passport_foreign_addToGear": "Aggiungi alla mia attrezzatura",
  "passport_foreign_addFailed": "Impossibile aggiungere la bombola. Riprova.",
  "passport_foreign_defaultName": "Bombola",
  "passport_foreign_serial": "N. di serie {serial}",
```

`app_nl.arb`
```json
  "passport_scan_title": "Flessentag scannen",
  "passport_scan_hint": "Richt de camera op het label of plak de link van de tag.",
  "passport_scan_cameraUnavailable": "De camera is hier niet beschikbaar. Plak in plaats daarvan de link van de tag.",
  "passport_scan_linkLabel": "Taglink",
  "passport_scan_paste": "Plakken",
  "passport_scan_open": "Openen",
  "passport_scan_openFailed": "De tag kon niet worden geopend. Probeer het opnieuw.",
  "passport_scan_newerFormat": "Deze tag is geschreven door een nieuwere versie van Submersion. Sommige gegevens kunnen ontbreken.",
  "passport_scan_filledFrom": "Ingevuld vanuit {name}",
  "passport_foreign_title": "Flessentag",
  "passport_foreign_notInGear": "Deze fles hoort niet bij je uitrusting.",
  "passport_foreign_writtenOn": "Zoals op de tag geschreven op {date}",
  "passport_foreign_noDetails": "De tag bevat geen gegevens behalve zijn identiteit.",
  "passport_foreign_o2Clean": "O2-schoon toen de tag werd geschreven",
  "passport_foreign_useOnDive": "Gebruiken bij een duik",
  "passport_foreign_addToGear": "Toevoegen aan mijn uitrusting",
  "passport_foreign_addFailed": "De fles kon niet worden toegevoegd. Probeer het opnieuw.",
  "passport_foreign_defaultName": "Fles",
  "passport_foreign_serial": "Serienummer {serial}",
```

`app_pt.arb`
```json
  "passport_scan_title": "Ler etiqueta do cilindro",
  "passport_scan_hint": "Aponte a câmera para a etiqueta ou cole o link da etiqueta.",
  "passport_scan_cameraUnavailable": "A câmera não está disponível aqui. Cole o link da etiqueta.",
  "passport_scan_linkLabel": "Link da etiqueta",
  "passport_scan_paste": "Colar",
  "passport_scan_open": "Abrir",
  "passport_scan_openFailed": "Não foi possível abrir a etiqueta. Tente novamente.",
  "passport_scan_newerFormat": "Esta etiqueta foi escrita por uma versão mais recente do Submersion. Alguns detalhes podem estar faltando.",
  "passport_scan_filledFrom": "Preenchido a partir de {name}",
  "passport_foreign_title": "Etiqueta do cilindro",
  "passport_foreign_notInGear": "Este cilindro não está no seu equipamento.",
  "passport_foreign_writtenOn": "Conforme escrito na etiqueta em {date}",
  "passport_foreign_noDetails": "A etiqueta não traz detalhes além da sua identificação.",
  "passport_foreign_o2Clean": "Limpo para O2 quando a etiqueta foi escrita",
  "passport_foreign_useOnDive": "Usar em um mergulho",
  "passport_foreign_addToGear": "Adicionar ao meu equipamento",
  "passport_foreign_addFailed": "Não foi possível adicionar o cilindro. Tente novamente.",
  "passport_foreign_defaultName": "Cilindro",
  "passport_foreign_serial": "Nº de série {serial}",
```

`app_hu.arb`
```json
  "passport_scan_title": "Palackcímke beolvasása",
  "passport_scan_hint": "Irányítsa a kamerát a címkére, vagy illessze be a címke hivatkozását.",
  "passport_scan_cameraUnavailable": "A kamera itt nem érhető el. Illessze be inkább a címke hivatkozását.",
  "passport_scan_linkLabel": "Címke hivatkozása",
  "passport_scan_paste": "Beillesztés",
  "passport_scan_open": "Megnyitás",
  "passport_scan_openFailed": "A címkét nem sikerült megnyitni. Próbálja újra.",
  "passport_scan_newerFormat": "Ezt a címkét a Submersion egy újabb verziója írta. Egyes adatok hiányozhatnak.",
  "passport_scan_filledFrom": "Kitöltve innen: {name}",
  "passport_foreign_title": "Palackcímke",
  "passport_foreign_notInGear": "Ez a palack nem szerepel a felszerelésében.",
  "passport_foreign_writtenOn": "A címke adatai szerint, írva: {date}",
  "passport_foreign_noDetails": "A címke az azonosítóján kívül nem tartalmaz adatot.",
  "passport_foreign_o2Clean": "O2-tiszta volt a címke írásakor",
  "passport_foreign_useOnDive": "Használat egy merüléshez",
  "passport_foreign_addToGear": "Hozzáadás a felszerelésemhez",
  "passport_foreign_addFailed": "A palack hozzáadása nem sikerült. Próbálja újra.",
  "passport_foreign_defaultName": "Palack",
  "passport_foreign_serial": "Sorozatszám: {serial}",
```

`app_ar.arb`
```json
  "passport_scan_title": "مسح بطاقة الأسطوانة",
  "passport_scan_hint": "وجّه الكاميرا نحو الملصق، أو الصق رابط البطاقة.",
  "passport_scan_cameraUnavailable": "الكاميرا غير متاحة هنا. الصق رابط البطاقة بدلًا من ذلك.",
  "passport_scan_linkLabel": "رابط البطاقة",
  "passport_scan_paste": "لصق",
  "passport_scan_open": "فتح",
  "passport_scan_openFailed": "تعذّر فتح البطاقة. حاول مرة أخرى.",
  "passport_scan_newerFormat": "كتب هذه البطاقة إصدار أحدث من Submersion. قد تنقص بعض التفاصيل.",
  "passport_scan_filledFrom": "مُلئ من {name}",
  "passport_foreign_title": "بطاقة الأسطوانة",
  "passport_foreign_notInGear": "هذه الأسطوانة ليست ضمن معداتك.",
  "passport_foreign_writtenOn": "كما كُتب على البطاقة في {date}",
  "passport_foreign_noDetails": "لا تحمل البطاقة تفاصيل غير معرّفها.",
  "passport_foreign_o2Clean": "نظيفة للأكسجين عند كتابة البطاقة",
  "passport_foreign_useOnDive": "استخدام في غطسة",
  "passport_foreign_addToGear": "إضافة إلى معداتي",
  "passport_foreign_addFailed": "تعذّر إضافة الأسطوانة. حاول مرة أخرى.",
  "passport_foreign_defaultName": "أسطوانة",
  "passport_foreign_serial": "الرقم التسلسلي {serial}",
```

`app_he.arb`
```json
  "passport_scan_title": "סריקת תג מיכל",
  "passport_scan_hint": "כוונו את המצלמה אל התווית, או הדביקו את הקישור מהתג.",
  "passport_scan_cameraUnavailable": "המצלמה אינה זמינה כאן. הדביקו במקום זאת את הקישור מהתג.",
  "passport_scan_linkLabel": "קישור התג",
  "passport_scan_paste": "הדבקה",
  "passport_scan_open": "פתיחה",
  "passport_scan_openFailed": "לא ניתן היה לפתוח את התג. נסו שוב.",
  "passport_scan_newerFormat": "התג נכתב בגרסה חדשה יותר של Submersion. ייתכן שחלק מהפרטים חסרים.",
  "passport_scan_filledFrom": "מולא מתוך {name}",
  "passport_foreign_title": "תג מיכל",
  "passport_foreign_notInGear": "המיכל הזה אינו חלק מהציוד שלך.",
  "passport_foreign_writtenOn": "כפי שנכתב בתג ב-{date}",
  "passport_foreign_noDetails": "התג אינו נושא פרטים מלבד המזהה שלו.",
  "passport_foreign_o2Clean": "נקי ל-O2 בזמן כתיבת התג",
  "passport_foreign_useOnDive": "שימוש בצלילה",
  "passport_foreign_addToGear": "הוספה לציוד שלי",
  "passport_foreign_addFailed": "לא ניתן היה להוסיף את המיכל. נסו שוב.",
  "passport_foreign_defaultName": "מיכל",
  "passport_foreign_serial": "מספר סידורי {serial}",
```

`app_zh.arb`
```json
  "passport_scan_title": "扫描气瓶标签",
  "passport_scan_hint": "将相机对准标签，或粘贴标签链接。",
  "passport_scan_cameraUnavailable": "此处无法使用相机。请改为粘贴标签链接。",
  "passport_scan_linkLabel": "标签链接",
  "passport_scan_paste": "粘贴",
  "passport_scan_open": "打开",
  "passport_scan_openFailed": "无法打开标签。请重试。",
  "passport_scan_newerFormat": "此标签由较新版本的 Submersion 写入，部分信息可能缺失。",
  "passport_scan_filledFrom": "已从 {name} 填入",
  "passport_foreign_title": "气瓶标签",
  "passport_foreign_notInGear": "此气瓶不在您的装备中。",
  "passport_foreign_writtenOn": "标签于 {date} 写入时的内容",
  "passport_foreign_noDetails": "该标签除标识外不含其他信息。",
  "passport_foreign_o2Clean": "写入标签时为氧清洁",
  "passport_foreign_useOnDive": "用于一次潜水",
  "passport_foreign_addToGear": "添加到我的装备",
  "passport_foreign_addFailed": "无法添加气瓶。请重试。",
  "passport_foreign_defaultName": "气瓶",
  "passport_foreign_serial": "序列号 {serial}",
```

- [ ] **Step 3: Regenerate and run the guards**

Run: `flutter gen-l10n` then `flutter test test/l10n/`
Expected: generation succeeds; all l10n guards pass (parity, duplicates, diacritics, plural interpolation).

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/l10n/
git commit -m "feat(l10n): cylinder tag scanning and foreign passport strings

Refs #2335"
```

---

### Task 3: The tag resolver

**Files:**
- Create: `lib/features/cylinder_passports/domain/services/passport_resolver.dart`
- Test: `test/features/cylinder_passports/domain/services/passport_resolver_test.dart`

**Interfaces:**
- Consumes (1a): `PassportPayloadCodec.decode(String) -> PassportDecodeResult`, `PassportDecoded(payload, newerFormat)`, `PassportRejected(reason)`, `PassportRejectReason`, `CylinderPassportPayload`.
- Produces: `sealed class PassportResolution`; `OwnCylinder(equipmentId, tag, newerFormat)`; `ForeignCylinder(tag, newerFormat)`; `NotACylinderTag(reason)`; `class PassportResolver { const PassportResolver({required Future<String?> Function(String passportId) findEquipmentId}); Future<PassportResolution> resolve(String text); }`.

- [ ] **Step 1: Write the failing test**

Create `test/features/cylinder_passports/domain/services/passport_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_resolver.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  const tag = 'https://submersion.app/c#f=1&p=$id&w=2026-09-25&v=12';

  PassportResolver resolverWith(Map<String, String> held) => PassportResolver(
    findEquipmentId: (passportId) async => held[passportId],
  );

  test('a tag the diver holds resolves to that cylinder', () async {
    final r = await resolverWith({id: 'eq-1'}).resolve(tag);
    expect(r, isA<OwnCylinder>());
    r as OwnCylinder;
    expect(r.equipmentId, 'eq-1');
    expect(r.tag.passportId, id);
    expect(r.tag.volumeL, 12);
    expect(r.newerFormat, isFalse);
  });

  test('a tag nobody holds resolves to a foreign cylinder', () async {
    final r = await resolverWith(const {}).resolve(tag);
    expect(r, isA<ForeignCylinder>());
    expect((r as ForeignCylinder).tag.passportId, id);
  });

  test('text that is not a tag says why', () async {
    final r = await resolverWith(const {}).resolve('https://example.com');
    expect((r as NotACylinderTag).reason, PassportRejectReason.notATag);
  });

  test('a newer format is reported, not refused', () async {
    final r = await resolverWith(const {}).resolve(
      'https://submersion.app/c#f=2&p=$id',
    );
    expect((r as ForeignCylinder).newerFormat, isTrue);
  });

  test('the lookup is never called for text that is not a tag', () async {
    var calls = 0;
    final resolver = PassportResolver(
      findEquipmentId: (_) async {
        calls++;
        return null;
      },
    );
    await resolver.resolve('not a tag');
    expect(calls, 0);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/cylinder_passports/domain/services/passport_resolver_test.dart`
Expected: compile error, the file does not exist.

- [ ] **Step 3: Implement**

Create `lib/features/cylinder_passports/domain/services/passport_resolver.dart`:

```dart
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

/// What a scanned, pasted or opened tag string turns out to be (spec 7.2).
sealed class PassportResolution {
  const PassportResolution();
}

/// A tag for one of the diver's own cylinders.
class OwnCylinder extends PassportResolution {
  const OwnCylinder({
    required this.equipmentId,
    required this.tag,
    this.newerFormat = false,
  });

  final String equipmentId;
  final CylinderPassportPayload tag;
  final bool newerFormat;
}

/// A tag for a cylinder the diver does not hold: a rental, a club tank.
class ForeignCylinder extends PassportResolution {
  const ForeignCylinder({required this.tag, this.newerFormat = false});

  final CylinderPassportPayload tag;
  final bool newerFormat;
}

/// Text that is not a cylinder tag.
class NotACylinderTag extends PassportResolution {
  const NotACylinderTag(this.reason);

  final PassportRejectReason reason;
}

/// Decodes a tag string and looks its passport id up among the diver's
/// cylinders. The lookup is injected so the domain stays free of the
/// database; callers pass the passport repository scoped to the diver.
class PassportResolver {
  const PassportResolver({required this.findEquipmentId});

  final Future<String?> Function(String passportId) findEquipmentId;

  Future<PassportResolution> resolve(String text) async {
    final decoded = PassportPayloadCodec.decode(text);
    switch (decoded) {
      case PassportRejected(:final reason):
        return NotACylinderTag(reason);
      case PassportDecoded(:final payload, :final newerFormat):
        final equipmentId = await findEquipmentId(payload.passportId);
        return equipmentId == null
            ? ForeignCylinder(tag: payload, newerFormat: newerFormat)
            : OwnCylinder(
                equipmentId: equipmentId,
                tag: payload,
                newerFormat: newerFormat,
              );
    }
  }
}
```

- [ ] **Step 4: Run the test, format, analyze, commit**

Run: `flutter test test/features/cylinder_passports/domain/services/passport_resolver_test.dart`
Expected: all pass.

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/domain/services/passport_resolver.dart test/features/cylinder_passports/domain/services/passport_resolver_test.dart
git commit -m "feat(passports): resolve a tag to an own cylinder, a foreign one, or neither

Refs #2335"
```

---

### Task 4: The foreign passport page and its route

**Files:**
- Create: `lib/features/cylinder_passports/domain/services/passport_attribute_keys.dart`
- Create: `lib/features/cylinder_passports/presentation/pages/foreign_passport_page.dart`
- Modify: `lib/core/router/app_router.dart` (inside the `/equipment` route's `routes:`, directly after the `cylinder-configs` route and before `:equipmentId`)
- Test: `test/features/cylinder_passports/domain/services/passport_attribute_keys_test.dart`, `test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart`, `test/core/router/app_router_test.dart` (append)

**Interfaces:**
- Consumes: `CylinderPassportPayload`, `PassportValve`, `PassportPayloadCodec.httpsUrl`, `PassportPayloadCodec.decode`, `attributeLabel`, `attributeChoiceLabel`, `EquipmentAttrKeys`, `UnitFormatter`, Task 2 strings.
- Produces:
  - `String tankMaterialChoiceKey(TankMaterial m)` (`aluminum`, `steel`, `carbon_composite`) and `String valveChoiceKey(PassportValve v)` (`din`, `yoke`, `convertible`).
  - `String foreignPassportLocation(CylinderPassportPayload tag)`: `/equipment/tag?t=<https tag, query-encoded>`.
  - `CylinderPassportPayload? foreignTagFromQuery(String? t)`.
  - `class ForeignPassportPage extends ConsumerStatefulWidget { const ForeignPassportPage({super.key, required CylinderPassportPayload? tag}); }` whose state has a `List<Widget> _actions()` method returning the action buttons (empty in this task; Tasks 6 and 7 fill it).
  - Route name `foreignPassport`, path `/equipment/tag`.

The tag travels in the query so the route survives a restart and a pasted location reproduces the page; the payload is public data by design.

- [ ] **Step 1: Write the failing tests**

Create `test/features/cylinder_passports/domain/services/passport_attribute_keys_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_attribute_keys.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';

void main() {
  test('every material maps to a tank catalog choice', () {
    final choices = EquipmentAttributeCatalog.defFor(
      EquipmentAttrKeys.tankMaterial,
    )!.choiceKeys;
    for (final m in TankMaterial.values) {
      expect(choices, contains(tankMaterialChoiceKey(m)), reason: m.name);
    }
    expect(tankMaterialChoiceKey(TankMaterial.carbonFiber), 'carbon_composite');
  });

  test('every valve maps to a tank catalog choice', () {
    final choices = EquipmentAttributeCatalog.defFor('valve_type')!.choiceKeys;
    for (final v in PassportValve.values) {
      expect(choices, contains(valveChoiceKey(v)), reason: v.name);
    }
    expect(valveChoiceKey(PassportValve.convertible), 'convertible');
  });
}
```

Create `test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/foreign_passport_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  late String? savedIntlLocale;
  setUp(() {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  final full = CylinderPassportPayload(
    passportId: id,
    writtenOn: DateTime(2026, 9, 25),
    name: 'Club 10',
    serial: 'AB12345',
    volumeL: 10,
    workingPressureBar: 300,
    material: TankMaterial.steel,
    valve: PassportValve.din,
    lastHydro: DateTime(2024, 6, 14),
    lastVip: DateTime(2026, 3, 2),
    o2Clean: true,
  );

  Future<AppLocalizations> pump(
    WidgetTester tester,
    CylinderPassportPayload? tag,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 2000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(overrides: overrides, child: ForeignPassportPage(tag: tag)),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(ForeignPassportPage)));
  }

  testWidgets('shows the snapshot the tag carries', (tester) async {
    final l10n = await pump(tester, full);
    expect(find.text('Club 10'), findsOneWidget);
    expect(find.text(l10n.passport_foreign_serial('AB12345')), findsOneWidget);
    expect(find.text(l10n.passport_foreign_notInGear), findsOneWidget);
    expect(find.text('10 L'), findsOneWidget);
    expect(find.text('300 bar'), findsOneWidget);
    expect(find.text('Steel'), findsOneWidget);
    expect(find.text(l10n.passport_foreign_o2Clean), findsOneWidget);
    expect(find.textContaining('2024'), findsWidgets);
    expect(find.text(l10n.passport_foreign_noDetails), findsNothing);
  });

  testWidgets('an identity-only tag says it carries no details', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      CylinderPassportPayload(passportId: id, writtenOn: DateTime(2026, 9, 25)),
    );
    expect(find.text(l10n.passport_foreign_defaultName), findsOneWidget);
    expect(find.text(l10n.passport_foreign_noDetails), findsOneWidget);
  });

  testWidgets('a newer format is noted', (tester) async {
    final l10n = await pump(
      tester,
      const CylinderPassportPayload(passportId: id, formatVersion: 2),
    );
    expect(find.text(l10n.passport_scan_newerFormat), findsOneWidget);
  });

  testWidgets('a route with no readable tag says so', (tester) async {
    final l10n = await pump(tester, null);
    expect(find.text(l10n.passport_tag_linkInvalid), findsOneWidget);
  });

  test('the location round trips the tag', () {
    final location = foreignPassportLocation(full);
    expect(location, startsWith('/equipment/tag?t='));
    final t = Uri.parse(location).queryParameters['t'];
    expect(foreignTagFromQuery(t), full);
    expect(foreignTagFromQuery(null), isNull);
    expect(foreignTagFromQuery('nonsense'), isNull);
  });
}
```

Append to the `'app_router route configuration'` group in `test/core/router/app_router_test.dart`:

```dart
    test('a scanned foreign tag has its own route, not an equipment id', () {
      final match = router.configuration.findMatch(
        Uri.parse('/equipment/tag?t=x'),
      );
      expect(match.isError, isFalse);
      expect((match.last.route as GoRoute).name, 'foreignPassport');
    });
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/cylinder_passports/domain/services/passport_attribute_keys_test.dart test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart test/core/router/app_router_test.dart`
Expected: compile errors for the first two; the router test fails (the location matches `equipmentDetail` with id `tag`).

- [ ] **Step 3: Create the key mapping**

Create `lib/features/cylinder_passports/domain/services/passport_attribute_keys.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';

/// The tank catalog's choice key for a material (spec 6.2 `m`).
String tankMaterialChoiceKey(TankMaterial material) => switch (material) {
  TankMaterial.aluminum => 'aluminum',
  TankMaterial.steel => 'steel',
  TankMaterial.carbonFiber => 'carbon_composite',
};

/// The tank catalog's choice key for a valve (spec 6.2 `vt`).
String valveChoiceKey(PassportValve valve) => switch (valve) {
  PassportValve.din => 'din',
  PassportValve.yoke => 'yoke',
  PassportValve.convertible => 'convertible',
};
```

- [ ] **Step 4: Create the page**

Create `lib/features/cylinder_passports/presentation/pages/foreign_passport_page.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_attribute_keys.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where a scanned tag the diver does not hold opens. The tag rides in the
/// query so the page survives a restart; its payload is public by design.
String foreignPassportLocation(CylinderPassportPayload tag) => Uri(
  path: '/equipment/tag',
  queryParameters: {'t': PassportPayloadCodec.httpsUrl(tag)},
).toString();

/// The tag a foreign passport route carried, or null when it is not one.
CylinderPassportPayload? foreignTagFromQuery(String? t) {
  if (t == null) return null;
  final decoded = PassportPayloadCodec.decode(t);
  return decoded is PassportDecoded ? decoded.payload : null;
}

/// A read-only passport built from a tag alone (spec section 9): what the
/// label said when it was written, for a cylinder that is not the diver's.
class ForeignPassportPage extends ConsumerStatefulWidget {
  const ForeignPassportPage({super.key, required this.tag});

  final CylinderPassportPayload? tag;

  @override
  ConsumerState<ForeignPassportPage> createState() =>
      _ForeignPassportPageState();
}

class _ForeignPassportPageState extends ConsumerState<ForeignPassportPage> {
  /// The page's actions (Use on a dive, Add to my gear).
  List<Widget> _actions(CylinderPassportPayload tag) => const [];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tag = widget.tag;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.passport_foreign_title)),
      body: tag == null
          ? Center(child: Text(l10n.passport_tag_linkInvalid))
          : _body(context, tag),
    );
  }

  Widget _body(BuildContext context, CylinderPassportPayload tag) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final rows = <(String, String)>[
      if (tag.volumeL != null)
        (
          attributeLabel(l10n, EquipmentAttrKeys.volumeL),
          units.formatVolume(tag.volumeL),
        ),
      if (tag.workingPressureBar != null)
        (
          attributeLabel(l10n, EquipmentAttrKeys.workingPressureBar),
          units.formatPressure(tag.workingPressureBar!.toDouble()),
        ),
      if (tag.material case final m?)
        (
          attributeLabel(l10n, EquipmentAttrKeys.tankMaterial),
          attributeChoiceLabel(
            l10n,
            EquipmentAttrKeys.tankMaterial,
            tankMaterialChoiceKey(m),
          ),
        ),
      if (tag.valve case final v?)
        (
          attributeLabel(l10n, 'valve_type'),
          attributeChoiceLabel(l10n, 'valve_type', valveChoiceKey(v)),
        ),
      if (tag.lastHydro case final d?)
        (attributeLabel(l10n, 'last_hydro_test'), units.formatDate(d)),
      if (tag.lastVip case final d?)
        (attributeLabel(l10n, 'last_visual_inspection'), units.formatDate(d)),
    ];
    final hasDetails = rows.isNotEmpty || tag.name != null || tag.o2Clean;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tag.name ?? l10n.passport_foreign_defaultName,
          style: theme.textTheme.headlineMedium,
        ),
        if (tag.serial case final serial?)
          Text(l10n.passport_foreign_serial(serial)),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.passport_foreign_notInGear),
          ),
        ),
        if (tag.formatVersion > CylinderPassportPayload.currentFormatVersion)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.passport_scan_newerFormat),
          ),
        if (tag.writtenOn case final written?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.passport_foreign_writtenOn(units.formatDate(written)),
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(label)),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (tag.o2Clean)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.passport_foreign_o2Clean),
          ),
        if (!hasDetails)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.passport_foreign_noDetails),
          ),
        const SizedBox(height: 24),
        ..._actions(tag),
      ],
    );
  }
}
```

- [ ] **Step 5: Add the route**

In `lib/core/router/app_router.dart`, inside the `/equipment` route's `routes:` list, directly after the `cylinder-configs` route and before the `':equipmentId'` route (static paths must come before the parameter), add:

```dart
              // A scanned cylinder tag the diver does not hold (issue #2335).
              // Before ':equipmentId' so 'tag' is never read as an id.
              GoRoute(
                path: 'tag',
                name: 'foreignPassport',
                builder: (context, state) => ForeignPassportPage(
                  tag: foreignTagFromQuery(state.uri.queryParameters['t']),
                ),
              ),
```

with the import of `foreign_passport_page.dart`.

- [ ] **Step 6: Run the tests, format, analyze, commit**

Run: `flutter test test/features/cylinder_passports/domain/services/passport_attribute_keys_test.dart test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart test/core/router/app_router_test.dart test/architecture/preference_aware_date_format_test.dart`
Expected: all pass.

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/domain/services/passport_attribute_keys.dart lib/features/cylinder_passports/presentation/pages/foreign_passport_page.dart lib/core/router/app_router.dart test/features/cylinder_passports/domain/services/passport_attribute_keys_test.dart test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart test/core/router/app_router_test.dart
git commit -m "feat(passports): a read-only passport for a tag the diver does not hold

Refs #2335"
```

---

### Task 5: The scan sheet and opening a scanned tag

**Files:**
- Create: `lib/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart`
- Create: `lib/features/cylinder_passports/presentation/widgets/passport_mobile_scanner.dart`
- Create: `lib/features/cylinder_passports/presentation/utils/scan_cylinder_tag.dart`
- Test: `test/features/cylinder_passports/presentation/widgets/passport_scan_sheet_test.dart`, `test/features/cylinder_passports/presentation/utils/scan_cylinder_tag_test.dart`

**Interfaces:**
- Consumes: Task 3 `PassportResolver` and results, Task 4 `foreignPassportLocation`, 1a `cylinderPassportRepositoryProvider`, `validatedCurrentDiverIdProvider`.
- Produces:
  - `typedef PassportCameraBuilder = Widget Function(BuildContext context, ValueChanged<String> onDetected);`
  - `final passportCameraProvider = Provider<PassportCameraBuilder?>` (null where there is no camera support: web, Windows, Linux).
  - `Future<String?> showPassportScanSheet(BuildContext context)`; `class PassportScanSheet`.
  - `final passportScanLauncherProvider = Provider<Future<String?> Function(BuildContext)>` (the seam every entry point uses, so tests never open a real camera).
  - `Future<PassportResolution> resolveScannedTag(WidgetRef ref, String text)`.
  - `Future<void> openScannedTag(BuildContext context, WidgetRef ref, String text)`.
  - `Future<void> scanAndOpenCylinderTag(BuildContext context, WidgetRef ref)`.

- [ ] **Step 1: Write the failing sheet test**

Create `test/features/cylinder_passports/presentation/widgets/passport_scan_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  const tag =
      'https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

  /// Opens the sheet from a button and records what it returned.
  Future<List<String?>> openSheet(
    WidgetTester tester, {
    required PassportCameraBuilder? camera,
  }) async {
    final results = <String?>[];
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          passportCameraProvider.overrideWithValue(camera),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(await showPassportScanSheet(context)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('the sheet closes once when the camera reports twice', (
    tester,
  ) async {
    final results = await openSheet(
      tester,
      camera: (context, onDetected) => TextButton(
        key: const Key('fakeDetect'),
        onPressed: () {
          onDetected(tag);
          onDetected(tag);
        },
        child: const Text('detect'),
      ),
    );
    await tester.tap(find.byKey(const Key('fakeDetect')));
    await tester.pumpAndSettle();
    expect(results, [tag]);
    // The host is still there: a second pop would have closed it too.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('without a camera the sheet says so and still takes a link', (
    tester,
  ) async {
    final results = await openSheet(tester, camera: null);
    final l10n = AppLocalizations.of(tester.element(find.byType(PassportScanSheet)));
    expect(find.text(l10n.passport_scan_cameraUnavailable), findsOneWidget);
    await tester.enterText(find.byKey(const Key('passportScan_link')), '  $tag ');
    await tester.tap(find.text(l10n.passport_scan_open));
    await tester.pumpAndSettle();
    expect(results, [tag]);
  });

  testWidgets('paste fills the link from the clipboard', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': tag};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final results = await openSheet(tester, camera: null);
    final l10n = AppLocalizations.of(tester.element(find.byType(PassportScanSheet)));
    await tester.tap(find.byTooltip(l10n.passport_scan_paste));
    await tester.pumpAndSettle();
    expect(find.text(tag), findsOneWidget);
    await tester.tap(find.text(l10n.passport_scan_open));
    await tester.pumpAndSettle();
    expect(results, [tag]);
  });

  testWidgets('an empty link does not close the sheet', (tester) async {
    final results = await openSheet(tester, camera: null);
    final l10n = AppLocalizations.of(tester.element(find.byType(PassportScanSheet)));
    await tester.tap(find.text(l10n.passport_scan_open));
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(find.byType(PassportScanSheet), findsOneWidget);
  });
}
```

- [ ] **Step 2: Write the failing open test**

Create `test/features/cylinder_passports/presentation/utils/scan_cylinder_tag_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/scan_cylinder_tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  const tag = 'https://submersion.app/c#f=1&p=$id&v=10';
  late AppDatabase db;
  Object? passportExtra;

  setUp(() async {
    db = await setUpTestDatabase();
    passportExtra = null;
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'eq-1',
            name: 'Faber 12',
            type: 'tank',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    required String text,
    List<dynamic> extraOverrides = const [],
  }) async {
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => openScannedTag(context, ref, text),
                child: const Text('go'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/equipment/tag',
          builder: (context, state) => const Text('foreign page'),
        ),
        GoRoute(
          path: '/equipment/:id/passport',
          builder: (context, state) {
            passportExtra = state.extra;
            return Text('passport ${state.pathParameters['id']}');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides, ...extraOverrides].cast(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.text('go')));
    await tester.tap(find.text('go'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('an own tag opens that cylinder with the scanned tag', (
    tester,
  ) async {
    await tester.runAsync(
      () => CylinderPassportRepository().assignPassportId(
        equipmentId: 'eq-1',
        passportId: id,
      ),
    );
    await pump(tester, text: tag);
    expect(find.text('passport eq-1'), findsOneWidget);
    expect(passportExtra, isA<CylinderPassportPayload>());
    expect((passportExtra! as CylinderPassportPayload).volumeL, 10);
  });

  testWidgets('a tag nobody holds opens the foreign passport', (tester) async {
    await pump(tester, text: tag);
    expect(find.text('foreign page'), findsOneWidget);
  });

  testWidgets('text that is not a tag says so and stays put', (tester) async {
    final l10n = await pump(tester, text: 'hello');
    expect(find.text(l10n.passport_tag_linkInvalid), findsOneWidget);
    expect(find.text('go'), findsOneWidget);
  });

  testWidgets('a failing lookup reports it', (tester) async {
    final l10n = await pump(
      tester,
      text: tag,
      extraOverrides: [
        cylinderPassportRepositoryProvider.overrideWithValue(_BrokenRepo()),
      ],
    );
    expect(find.text(l10n.passport_scan_openFailed), findsOneWidget);
  });
}

class _BrokenRepo extends CylinderPassportRepository {
  @override
  Future<String?> findEquipmentIdByPassportId(
    String passportId, {
    String? diverId,
  }) async => throw StateError('database is locked');
}
```

- [ ] **Step 3: Run both to see them fail**

Run: `flutter test test/features/cylinder_passports/presentation/widgets/passport_scan_sheet_test.dart test/features/cylinder_passports/presentation/utils/scan_cylinder_tag_test.dart`
Expected: compile errors, the files do not exist.

- [ ] **Step 4: Create the camera view**

Create `lib/features/cylinder_passports/presentation/widgets/passport_mobile_scanner.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The live camera for the scan sheet: QR codes only, the first readable
/// value reported. The sheet guards against repeated reports.
class PassportMobileScanner extends StatefulWidget {
  const PassportMobileScanner({super.key, required this.onDetected});

  final ValueChanged<String> onDetected;

  @override
  State<PassportMobileScanner> createState() => _PassportMobileScannerState();
}

class _PassportMobileScannerState extends State<PassportMobileScanner> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          final raw = barcode.rawValue;
          if (raw != null && raw.isNotEmpty) {
            widget.onDetected(raw);
            return;
          }
        }
      },
      // A denied permission or a missing camera lands here; the sheet's
      // paste field stays usable below it.
      errorBuilder: (context, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.l10n.passport_scan_cameraUnavailable,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
```

If the resolved `mobile_scanner` version's `errorBuilder` takes a third `child` argument (older releases did), add it as an ignored parameter; the analyzer names the expected signature.

- [ ] **Step 5: Create the sheet**

Create `lib/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_mobile_scanner.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Builds the live camera for the scan sheet; [onDetected] receives each
/// decoded QR value.
typedef PassportCameraBuilder =
    Widget Function(BuildContext context, ValueChanged<String> onDetected);

/// The camera where `mobile_scanner` supports one (iOS, Android, macOS);
/// null elsewhere, where the sheet offers the paste field alone. Tests
/// override it so no real camera is ever opened.
final passportCameraProvider = Provider<PassportCameraBuilder?>((ref) {
  if (kIsWeb) return null;
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android || TargetPlatform.macOS =>
      (context, onDetected) => PassportMobileScanner(onDetected: onDetected),
    _ => null,
  };
});

/// Opens the scan sheet; resolves with the scanned or pasted text, or null
/// when the diver closed it.
Future<String?> showPassportScanSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: const PassportScanSheet(),
      ),
    );

/// How every entry point opens the scan sheet. Overridden in tests.
final passportScanLauncherProvider =
    Provider<Future<String?> Function(BuildContext)>(
      (ref) => showPassportScanSheet,
    );

class PassportScanSheet extends ConsumerStatefulWidget {
  const PassportScanSheet({super.key});

  @override
  ConsumerState<PassportScanSheet> createState() => _PassportScanSheetState();
}

class _PassportScanSheetState extends ConsumerState<PassportScanSheet> {
  final _link = TextEditingController();

  /// The camera reports the same code many times a second; only the first
  /// may close the sheet, or a second pop would close the page under it.
  bool _done = false;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _finish(String text) {
    final value = text.trim();
    if (_done || value.isEmpty || !mounted) return;
    _done = true;
    Navigator.of(context).pop(value);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted || text == null || text.isEmpty) return;
    setState(() => _link.text = text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final camera = ref.watch(passportCameraProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.passport_scan_title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (camera != null) ...[
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: camera(context, _finish),
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.passport_scan_hint),
          ] else
            Text(l10n.passport_scan_cameraUnavailable),
          const SizedBox(height: 12),
          TextField(
            key: const Key('passportScan_link'),
            controller: _link,
            keyboardType: TextInputType.url,
            onSubmitted: _finish,
            decoration: InputDecoration(
              labelText: l10n.passport_scan_linkLabel,
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste),
                tooltip: l10n.passport_scan_paste,
                onPressed: _paste,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => _finish(_link.text),
              child: Text(l10n.passport_scan_open),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Create the open helpers**

Create `lib/features/cylinder_passports/presentation/utils/scan_cylinder_tag.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_resolver.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/foreign_passport_page.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(PassportResolver);

/// Resolves [text] against the active diver's cylinders.
Future<PassportResolution> resolveScannedTag(WidgetRef ref, String text) async {
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  final repository = ref.read(cylinderPassportRepositoryProvider);
  return PassportResolver(
    findEquipmentId: (passportId) =>
        repository.findEquipmentIdByPassportId(passportId, diverId: diverId),
  ).resolve(text);
}

/// Opens what [text] points at: the diver's own passport (carrying the
/// scanned tag, for the stale-tag hint), the foreign passport, or a message.
Future<void> openScannedTag(
  BuildContext context,
  WidgetRef ref,
  String text,
) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    switch (await resolveScannedTag(ref, text)) {
      case OwnCylinder(:final equipmentId, :final tag):
        router.push('/equipment/$equipmentId/passport', extra: tag);
      case ForeignCylinder(:final tag):
        router.push(foreignPassportLocation(tag));
      case NotACylinderTag():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.passport_tag_linkInvalid)),
        );
    }
  } catch (e, stackTrace) {
    _log.error('Failed to open a scanned tag', error: e, stackTrace: stackTrace);
    messenger.showSnackBar(SnackBar(content: Text(l10n.passport_scan_openFailed)));
  }
}

/// The scan button's whole flow: open the sheet, then open the result.
Future<void> scanAndOpenCylinderTag(BuildContext context, WidgetRef ref) async {
  final text = await ref.read(passportScanLauncherProvider)(context);
  if (text == null || !context.mounted) return;
  await openScannedTag(context, ref, text);
}
```

- [ ] **Step 7: Run the tests, format, analyze, commit**

Run: `flutter test test/features/cylinder_passports/presentation/widgets/passport_scan_sheet_test.dart test/features/cylinder_passports/presentation/utils/scan_cylinder_tag_test.dart test/architecture/`
Expected: all pass.

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart lib/features/cylinder_passports/presentation/widgets/passport_mobile_scanner.dart lib/features/cylinder_passports/presentation/utils/scan_cylinder_tag.dart test/features/cylinder_passports/presentation/widgets/passport_scan_sheet_test.dart test/features/cylinder_passports/presentation/utils/scan_cylinder_tag_test.dart
git commit -m "feat(passports): scan sheet with camera and paste, and opening a scanned tag

Refs #2335"
```

---

### Task 6: Use on a dive

**Files:**
- Create: `lib/features/cylinder_passports/domain/services/passport_dive_tank.dart`
- Modify: `lib/features/dive_log/domain/entities/dive_prefill.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_applyPrefill`, the tank block at its end)
- Modify: `lib/features/cylinder_passports/presentation/pages/foreign_passport_page.dart` (`_actions`)
- Test: `test/features/cylinder_passports/domain/services/passport_dive_tank_test.dart`, `test/features/dive_log/presentation/pages/dive_edit_prefill_test.dart` (append), `test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart` (append)

**Interfaces:**
- Consumes: `DiveTank`, `GasMix`, `TankPresets.matchBySpecs`, Task 4 page.
- Produces: `DiveTank tankFromPassport(CylinderPassportPayload tag, {GasMix mix = const GasMix()})`; `DivePrefill.tank` (`DiveTank?`), which a new dive applies as its first cylinder.

- [ ] **Step 1: Write the failing tests**

Create `test/features/cylinder_passports/domain/services/passport_dive_tank_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_dive_tank.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

  test('copies the tag spec and names the matching preset', () {
    final tank = tankFromPassport(
      const CylinderPassportPayload(
        passportId: id,
        name: 'Club AL80',
        volumeL: 11.1,
        workingPressureBar: 207,
        material: TankMaterial.aluminum,
      ),
      mix: const GasMix(o2: 32),
    );
    expect(tank.name, 'Club AL80');
    expect(tank.volume, 11.1);
    expect(tank.workingPressure, 207);
    expect(tank.material, TankMaterial.aluminum);
    expect(tank.presetName, 'al80');
    expect(tank.gasMix.o2, 32);
    expect(tank.role, TankRole.backGas);
  });

  test('an identity-only tag leaves every spec open, air by default', () {
    final tank = tankFromPassport(const CylinderPassportPayload(passportId: id));
    expect(tank.volume, isNull);
    expect(tank.workingPressure, isNull);
    expect(tank.material, isNull);
    expect(tank.presetName, isNull);
    expect(tank.gasMix, const GasMix());
  });
}
```

Append inside the `'DiveEditPage prefill'` group of `test/features/dive_log/presentation/pages/dive_edit_prefill_test.dart` (add imports for `enums.dart` and `dive.dart` if missing):

```dart
    testWidgets('a cylinder prefill becomes the first tank', (tester) async {
      String? savedId;
      await pumpEditPage(
        tester,
        prefill: const DivePrefill(
          tank: DiveTank(
            id: '',
            name: 'Club 10',
            volume: 10,
            workingPressure: 300,
            material: TankMaterial.steel,
            gasMix: GasMix(o2: 32),
          ),
        ),
        onSaved: (id) => savedId = id,
      );
      await tester.tap(find.text('Save'));
      for (var i = 0; i < 100 && savedId == null; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final dive = await tester.runAsync(
        () => repository.getDiveById(savedId!),
      );
      final tank = dive!.tanks.first;
      expect(tank.name, 'Club 10');
      expect(tank.volume, 10);
      expect(tank.workingPressure, 300);
      expect(tank.material, TankMaterial.steel);
      expect(tank.gasMix.o2, 32);
    });

    testWidgets('an identity-only tag keeps the default tank', (tester) async {
      String? savedId;
      await pumpEditPage(
        tester,
        prefill: const DivePrefill(tank: DiveTank(id: '')),
        onSaved: (id) => savedId = id,
      );
      await tester.tap(find.text('Save'));
      for (var i = 0; i < 100 && savedId == null; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final dive = await tester.runAsync(
        () => repository.getDiveById(savedId!),
      );
      // The settings default (12 L in the test settings), not a blank tank.
      expect(dive!.tanks.first.volume, 12);
    });
```

Append to `test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart` (add imports for `go_router`, `provider.dart`, `dive_prefill.dart`):

```dart
  testWidgets('Use on a dive opens a new dive with the cylinder', (
    tester,
  ) async {
    Object? extra;
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: foreignPassportLocation(full),
      routes: [
        GoRoute(
          path: '/equipment/tag',
          builder: (context, state) => ForeignPassportPage(
            tag: foreignTagFromQuery(state.uri.queryParameters['t']),
          ),
        ),
        GoRoute(
          path: '/dives/new',
          builder: (context, state) {
            extra = state.extra;
            return const Text('new dive');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('foreign_useOnDive')));
    await tester.pumpAndSettle();
    expect(find.text('new dive'), findsOneWidget);
    final tank = (extra! as DivePrefill).tank!;
    expect(tank.volume, 10);
    expect(tank.workingPressure, 300);
  });
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/cylinder_passports/domain/services/passport_dive_tank_test.dart test/features/dive_log/presentation/pages/dive_edit_prefill_test.dart test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart`
Expected: compile errors (`tankFromPassport`, `DivePrefill.tank`, `foreign_useOnDive`).

- [ ] **Step 3: Implement the tank builder**

Create `lib/features/cylinder_passports/domain/services/passport_dive_tank.dart`:

```dart
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A dive tank describing the cylinder a tag names (spec section 9, "Use on
/// a dive"). A copy, never a link: the dive records what was breathed, and
/// nothing on the tank points back at the tag. The id is left for the dive
/// edit page to assign.
DiveTank tankFromPassport(
  CylinderPassportPayload tag, {
  GasMix mix = const GasMix(),
}) {
  final volume = tag.volumeL;
  final workingPressure = tag.workingPressureBar?.toDouble();
  final preset = volume != null && workingPressure != null
      ? TankPresets.matchBySpecs(volume, workingPressure)
      : null;
  return DiveTank(
    id: '',
    name: tag.name,
    volume: volume,
    workingPressure: workingPressure,
    gasMix: mix,
    material: tag.material,
    presetName: preset?.name,
  );
}
```

- [ ] **Step 4: Add `DivePrefill.tank`**

In `lib/features/dive_log/domain/entities/dive_prefill.dart`, add the import `package:submersion/features/dive_log/domain/entities/dive.dart`, the field after `cylinderVolumeLiters`:

```dart
  /// A whole cylinder for the first tank, from a scanned cylinder tag
  /// (issue #2335). Takes precedence over [o2Percent] and
  /// [cylinderVolumeLiters]; any spec it leaves null keeps the default.
  final DiveTank? tank;
```

and `this.tank,` to the constructor after `this.cylinderVolumeLiters,`.

- [ ] **Step 5: Apply it in the dive edit page**

In `_applyPrefill` of `dive_edit_page.dart`, the tank block currently starts `if (p.startPressureBar != null ||`. Insert before it, and turn that `if` into `else if`:

```dart
    if (p.tank case final t?) {
      final base = _tanks.isNotEmpty ? _tanks.first : null;
      _tanks = [
        DiveTank(
          id: base?.id ?? _uuid.v4(),
          name: t.name,
          volume: t.volume ?? base?.volume,
          workingPressure: t.workingPressure ?? base?.workingPressure,
          startPressure: t.startPressure ?? base?.startPressure,
          endPressure: t.endPressure ?? base?.endPressure,
          gasMix: t.gasMix,
          role: t.role,
          material: t.material ?? base?.material,
          order: 0,
          // A tag without a volume keeps the default cylinder, preset and all.
          presetName: t.volume == null ? base?.presetName : t.presetName,
        ),
        ..._tanks.skip(1),
      ];
      // The default preset loads asynchronously and replaces an untouched
      // first tank; a cylinder chosen from a tag must survive that.
      _tanksDirty = true;
    } else if (p.startPressureBar != null ||
```

- [ ] **Step 6: Add the button**

In `foreign_passport_page.dart`, replace `_actions` with:

```dart
  /// The page's actions (Use on a dive, Add to my gear).
  List<Widget> _actions(CylinderPassportPayload tag) => [
    FilledButton.icon(
      key: const Key('foreign_useOnDive'),
      icon: const Icon(Icons.scuba_diving),
      label: Text(context.l10n.passport_foreign_useOnDive),
      onPressed: () => context.push(
        '/dives/new',
        extra: DivePrefill(tank: tankFromPassport(tag)),
      ),
    ),
  ];
```

with imports for `go_router`, `dive_prefill.dart` and `passport_dive_tank.dart`.

- [ ] **Step 7: Run the tests, format, analyze, commit**

Run: `flutter test test/features/cylinder_passports/domain/services/passport_dive_tank_test.dart test/features/dive_log/presentation/pages/dive_edit_prefill_test.dart test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart`
Expected: all pass.

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/domain/services/passport_dive_tank.dart lib/features/dive_log/domain/entities/dive_prefill.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/cylinder_passports/presentation/pages/foreign_passport_page.dart test/features/cylinder_passports/domain/services/passport_dive_tank_test.dart test/features/dive_log/presentation/pages/dive_edit_prefill_test.dart test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart
git commit -m "feat(passports): use a scanned cylinder on a new dive

Refs #2335"
```

---

### Task 7: Add to my gear

**Files:**
- Create: `lib/features/cylinder_passports/data/services/passport_adoption_service.dart`
- Modify: `lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart`
- Modify: `lib/features/cylinder_passports/presentation/pages/foreign_passport_page.dart`
- Test: `test/features/cylinder_passports/data/services/passport_adoption_service_test.dart`, `test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart` (append)

**Interfaces:**
- Consumes: `EquipmentRepository.createEquipment` (auto-attaches the `hydro` and `vip` schedules as `auto-hydro-<id>` and `auto-vip-<id>`), `EquipmentRepository.transaction`, 1a `CylinderPassportRepository.assignPassportId` (throws `PassportIdInUse`; relinks fills), `ServiceScheduleRepository.getSchedulesForEquipment`, `updateSchedule`, `createSchedule`, `ServiceSchedule.withBaseline`, Task 4 key mapping.
- Produces: `class PassportAdoptionService { PassportAdoptionService({EquipmentRepository? equipment, CylinderPassportRepository? passports, ServiceScheduleRepository? schedules}); Future<EquipmentItem> adopt(CylinderPassportPayload tag, {required String? diverId, required String fallbackName, DateTime? now}); }`; `final passportAdoptionServiceProvider = Provider<PassportAdoptionService>`.

Clock baselines, never service records (spec section 9): a label says when the last hydro and VIP were, which is what a baseline means. O2 clean has no date on the tag, so an O2 clean schedule is attached with the tag's written date as its baseline: the tag attests the cylinder was clean as of then, and the passport shows it as a baseline, not a cleaning.

- [ ] **Step 1: Write the failing service test**

Create `test/features/cylinder_passports/data/services/passport_adoption_service_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/passport_adoption_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';

import '../../../../helpers/test_database.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final now = DateTime(2026, 9, 26, 10);
  late AppDatabase db;
  late PassportAdoptionService service;

  final full = CylinderPassportPayload(
    passportId: id,
    writtenOn: DateTime(2026, 9, 1),
    name: 'Club 10',
    serial: 'AB12345',
    volumeL: 10,
    workingPressureBar: 300,
    material: TankMaterial.steel,
    valve: PassportValve.din,
    lastHydro: DateTime(2024, 6, 14),
    lastVip: DateTime(2026, 3, 2),
    o2Clean: true,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    service = PassportAdoptionService();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(id: 'd1', name: 'd1', createdAt: t, updatedAt: t),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<int> tankCount() async =>
      (await (db.select(db.equipment)..where((e) => e.type.equals('tank'))).get())
          .length;

  test('creates a tank with the tag spec and its passport id', () async {
    final item = await service.adopt(
      full,
      diverId: 'd1',
      fallbackName: 'Cylinder',
      now: now,
    );
    expect(item.type, EquipmentType.tank);
    expect(item.name, 'Club 10');
    expect(item.serialNumber, 'AB12345');
    expect(item.diverId, 'd1');
    expect(item.volumeL, 10);
    expect(item.workingPressureBar, 300);
    expect(item.tankMaterial, TankMaterial.steel);
    expect(item.attrText('valve_type'), 'din');
    expect(await CylinderPassportRepository().getPassportId(item.id), id);
  });

  test('sets clock baselines from the tag, never service records', () async {
    final item = await service.adopt(
      full,
      diverId: 'd1',
      fallbackName: 'Cylinder',
      now: now,
    );
    final schedules = {
      for (final s in await ServiceScheduleRepository().getSchedulesForEquipment(
        item.id,
      ))
        s.serviceKindId: s,
    };
    expect(schedules['hydro']!.anchorDate, DateTime(2024, 6, 14));
    expect(schedules['hydro']!.anchorSetAt, now);
    expect(schedules['vip']!.anchorDate, DateTime(2026, 3, 2));
    expect(schedules['o2-clean']!.anchorDate, DateTime(2026, 9, 1));
    expect(await db.select(db.serviceRecords).get(), isEmpty);
  });

  test('fills already logged under the tag follow the new cylinder', () async {
    await CylinderFillRepository().create(
      CylinderFill(
        id: 'f1',
        passportId: id,
        filledAt: now,
        o2Percent: 32,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final item = await service.adopt(
      full,
      diverId: 'd1',
      fallbackName: 'Cylinder',
      now: now,
    );
    expect((await CylinderFillRepository().getById('f1'))!.equipmentId, item.id);
  });

  test('an identity-only tag makes a named tank with open clocks', () async {
    final item = await service.adopt(
      const CylinderPassportPayload(passportId: id),
      diverId: 'd1',
      fallbackName: 'Cylinder',
      now: now,
    );
    expect(item.name, 'Cylinder');
    expect(item.volumeL, isNull);
    final schedules = await ServiceScheduleRepository().getSchedulesForEquipment(
      item.id,
    );
    expect(schedules.every((s) => s.anchorDate == null), isTrue);
    expect(schedules.any((s) => s.serviceKindId == 'o2-clean'), isFalse);
  });

  test('a held tag creates nothing', () async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'eq-held',
            name: 'Dad 12',
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d1'),
          ),
        );
    await CylinderPassportRepository().assignPassportId(
      equipmentId: 'eq-held',
      passportId: id,
      diverId: 'd1',
    );
    final before = await tankCount();
    await expectLater(
      service.adopt(full, diverId: 'd1', fallbackName: 'Cylinder', now: now),
      throwsA(
        isA<PassportIdInUse>().having((e) => e.equipmentId, 'holder', 'eq-held'),
      ),
    );
    expect(await tankCount(), before);
    expect(
      (await db.select(db.equipmentAttributes).get()).where(
        (a) => a.attrKey == EquipmentAttrKeys.volumeL,
      ),
      isEmpty,
    );
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/cylinder_passports/data/services/passport_adoption_service_test.dart`
Expected: compile error, the service does not exist.

- [ ] **Step 3: Implement the service**

Create `lib/features/cylinder_passports/data/services/passport_adoption_service.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_attribute_keys.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

/// "Add to my gear" for a scanned tag (spec section 9): a tank row with the
/// tag's spec, the tag's passport id, and clock baselines from its dates,
/// all in one transaction. If the id turns out to be held by a cylinder in
/// service, [CylinderPassportRepository.assignPassportId] throws and the
/// whole adoption rolls back, so no half-made tank is left behind.
class PassportAdoptionService {
  PassportAdoptionService({
    EquipmentRepository? equipment,
    CylinderPassportRepository? passports,
    ServiceScheduleRepository? schedules,
  }) : _equipment = equipment ?? EquipmentRepository(),
       _passports = passports ?? CylinderPassportRepository(),
       _schedules = schedules ?? ServiceScheduleRepository();

  final EquipmentRepository _equipment;
  final CylinderPassportRepository _passports;
  final ServiceScheduleRepository _schedules;

  Future<EquipmentItem> adopt(
    CylinderPassportPayload tag, {
    required String? diverId,
    required String fallbackName,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final item = await _equipment.transaction(() async {
      final created = await _equipment.createEquipment(
        EquipmentItem(
          id: '',
          diverId: diverId,
          name: tag.name ?? fallbackName,
          type: EquipmentType.tank,
          serialNumber: tag.serial,
          attributes: _specAttributes(tag),
        ),
        notify: false,
      );
      await _passports.assignPassportId(
        equipmentId: created.id,
        passportId: tag.passportId,
        diverId: diverId,
      );
      await _applyBaselines(created.id, tag, at);
      return created;
    });
    SyncEventBus.notifyLocalChange();
    return (await _equipment.getEquipmentById(item.id)) ?? item;
  }

  List<EquipmentAttribute> _specAttributes(CylinderPassportPayload tag) => [
    if (tag.volumeL case final v?)
      EquipmentAttribute.curated(
        equipmentId: '',
        key: EquipmentAttrKeys.volumeL,
        valueNum: v,
      ),
    if (tag.workingPressureBar case final wp?)
      EquipmentAttribute.curated(
        equipmentId: '',
        key: EquipmentAttrKeys.workingPressureBar,
        valueNum: wp.toDouble(),
      ),
    if (tag.material case final m?)
      EquipmentAttribute.curated(
        equipmentId: '',
        key: EquipmentAttrKeys.tankMaterial,
        valueText: tankMaterialChoiceKey(m),
      ),
    if (tag.valve case final v?)
      EquipmentAttribute.curated(
        equipmentId: '',
        key: 'valve_type',
        valueText: valveChoiceKey(v),
      ),
  ];

  Future<void> _applyBaselines(
    String equipmentId,
    CylinderPassportPayload tag,
    DateTime at,
  ) async {
    for (final schedule in await _schedules.getSchedulesForEquipment(
      equipmentId,
    )) {
      final date = switch (schedule.serviceKindId) {
        'hydro' => tag.lastHydro,
        'vip' => tag.lastVip,
        _ => null,
      };
      if (date == null) continue;
      await _schedules.updateSchedule(
        schedule.withBaseline(date, now: at, picked: true),
      );
    }
    if (tag.o2Clean) {
      final schedule = ServiceSchedule(
        id: 'auto-o2-clean-$equipmentId',
        equipmentId: equipmentId,
        serviceKindId: 'o2-clean',
        createdAt: at,
        updatedAt: at,
      );
      await _schedules.createSchedule(
        tag.writtenOn == null
            ? schedule
            : schedule.withBaseline(tag.writtenOn, now: at, picked: true),
        notify: false,
      );
    }
  }
}
```

In `cylinder_passport_providers.dart`, add:

```dart
final passportAdoptionServiceProvider = Provider<PassportAdoptionService>(
  (ref) => PassportAdoptionService(),
);
```

with its import.

- [ ] **Step 4: Run the service test**

Run: `flutter test test/features/cylinder_passports/data/services/passport_adoption_service_test.dart`
Expected: all pass. If the hydro and VIP schedules are missing, check that the fresh test database seeds the built-in service kinds (`kSeedBuiltInServiceKindsSql`); do not create them in the service.

- [ ] **Step 5: Write the failing page test**

Append to `foreign_passport_page_test.dart` (add imports for `test_database.dart`, `equipment_repository_impl.dart` is not needed):

```dart
  testWidgets('Add to my gear creates the cylinder and opens its passport', (
    tester,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: foreignPassportLocation(full),
      routes: [
        GoRoute(
          path: '/equipment/tag',
          builder: (context, state) => ForeignPassportPage(
            tag: foreignTagFromQuery(state.uri.queryParameters['t']),
          ),
        ),
        GoRoute(
          path: '/equipment/:id/passport',
          builder: (context, state) => Text('passport ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('foreign_addToGear')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('passport '), findsOneWidget);
  });
```

Run: `flutter test test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart`
Expected: fails, no `foreign_addToGear` button.

- [ ] **Step 6: Add the button**

In `foreign_passport_page.dart`, add a `bool _busy = false;` field to the state, the method:

```dart
  Future<void> _addToGear(CylinderPassportPayload tag) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final item = await ref
          .read(passportAdoptionServiceProvider)
          .adopt(
            tag,
            diverId: diverId,
            fallbackName: l10n.passport_foreign_defaultName,
          );
      if (!mounted) return;
      router.pushReplacement('/equipment/${item.id}/passport');
    } on PassportIdInUse catch (e) {
      final holder = await ref
          .read(equipmentRepositoryProvider)
          .getEquipmentById(e.equipmentId);
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.passport_tag_linkInUse(holder?.name ?? e.equipmentId)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.passport_foreign_addFailed)),
      );
    }
  }
```

and append to the list `_actions` returns:

```dart
    const SizedBox(height: 8),
    OutlinedButton.icon(
      key: const Key('foreign_addToGear'),
      icon: const Icon(Icons.add),
      label: Text(context.l10n.passport_foreign_addToGear),
      onPressed: _busy ? null : () => _addToGear(tag),
    ),
```

with imports for `cylinder_passport_repository.dart`, `cylinder_passport_providers.dart`, `diver_providers.dart` and `equipment_providers.dart`.

- [ ] **Step 7: Run the tests, format, analyze, commit**

Run: `flutter test test/features/cylinder_passports/data/services/passport_adoption_service_test.dart test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart test/architecture/provider_change_tick_test.dart`
Expected: all pass.

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/data/services/passport_adoption_service.dart lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart lib/features/cylinder_passports/presentation/pages/foreign_passport_page.dart test/features/cylinder_passports/data/services/passport_adoption_service_test.dart test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart
git commit -m "feat(passports): add a scanned cylinder to my gear in one transaction

Refs #2335"
```

---

### Task 8: Scan from the equipment list

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_list_page.dart` (`_buildListActions`)
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (`_buildHeaderActions` popup, and the standalone `AppBar` popup of the `showAppBar: true` path)
- Test: `test/features/equipment/presentation/pages/equipment_list_page_test.dart` (append), `test/features/equipment/presentation/widgets/equipment_list_content_test.dart` (append), `test/features/equipment/presentation/pages/equipment_list_header_layout_test.dart` (existing, must stay green)

**Interfaces:**
- Consumes: Task 5 `scanAndOpenCylinderTag`, `passportScanLauncherProvider`; Task 2 `passport_scan_title`.
- Produces: an overflow menu item keyed `ValueKey('equipment_menu_scanTag')`, value `'scan_tag'`, on every equipment list layout.

The item goes in the overflow menus rather than as a new icon: the phone header's one-row fit and the pane header's width budget are sized for the current icons (`equipment_list_header_layout_test.dart` pins them), and "Select items" already lives in the same menu for the same reason.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/equipment/presentation/pages/equipment_list_page_test.dart` (import `passport_scan_sheet.dart`):

```dart
  testWidgets('the overflow menu offers scanning a cylinder tag', (
    tester,
  ) async {
    var launched = 0;
    final overrides = await _buildOverrides();
    await tester.pumpWidget(
      _buildTestWidget(
        child: const EquipmentListPage(),
        overrides: [
          ...overrides,
          passportScanLauncherProvider.overrideWithValue((context) async {
            launched++;
            return null;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment_menu_scanTag')));
    await tester.pumpAndSettle();
    expect(launched, 1);
  });
```

Append inside the `'bulk actions'` group of `test/features/equipment/presentation/widgets/equipment_list_content_test.dart` (import `passport_scan_sheet.dart`):

```dart
    for (final showAppBar in [true, false]) {
      testWidgets('scan a cylinder tag is in the menu (appBar: $showAppBar)', (
        tester,
      ) async {
        var launched = 0;
        await tester.pumpWidget(
          await host(
            [_makeEquipment(id: 'e1', name: 'Aaa Reg')],
            showAppBar: showAppBar,
            extraOverrides: [
              passportScanLauncherProvider.overrideWithValue((context) async {
                launched++;
                return null;
              }),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_vert).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('equipment_menu_scanTag')));
        await tester.pumpAndSettle();
        expect(launched, 1);
      });
    }
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/equipment/presentation/pages/equipment_list_page_test.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart`
Expected: the new tests fail, no `equipment_menu_scanTag`.

- [ ] **Step 3: Add the item to all three menus**

The menu item, the same in all three places, placed first in each `itemBuilder` list:

```dart
                PopupMenuItem<String>(
                  key: const ValueKey('equipment_menu_scanTag'),
                  value: _scanTagMenuValue,
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_scanner, size: 20),
                      const SizedBox(width: 12),
                      Text(context.l10n.passport_scan_title),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
```

In each menu's `onSelected`, before the existing branches:

```dart
                if (value == _scanTagMenuValue) {
                  scanAndOpenCylinderTag(context, ref);
                  return;
                }
```

Declare `static const String _scanTagMenuValue = 'scan_tag';` in `_EquipmentListPageState` (beside `_selectMenuValue`) and in the `EquipmentListContent` state class, and import `scan_cylinder_tag.dart` in both files. In `equipment_list_page.dart` the `itemBuilder` list starts with the select item block; put the scan item before it. In `equipment_list_content.dart` both popups' `itemBuilder` return `[...ListViewModeToggle.menuItems(...)]`; put the scan item and divider before the spread.

- [ ] **Step 4: Run the tests and the header layout guard**

Run: `flutter test test/features/equipment/presentation/pages/equipment_list_page_test.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart test/features/equipment/presentation/pages/equipment_list_header_layout_test.dart`
Expected: all pass, the layout test unchanged.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/equipment/presentation/pages/equipment_list_page.dart lib/features/equipment/presentation/widgets/equipment_list_content.dart test/features/equipment/presentation/pages/equipment_list_page_test.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart
git commit -m "feat(passports): scan a cylinder tag from the equipment list menu

Refs #2335"
```

---

### Task 9: Scan in the dive editor's tank card

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart` (constructor, `_buildHeader`, new `_scanCylinder` and `_applyScannedSpec`)
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/tank_row.dart` (pass-through)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (the single-dive `TankRow` call, around line 2990)
- Test: `test/features/dive_log/presentation/widgets/tank_editor_scan_test.dart` (create), `test/features/dive_log/presentation/pages/dive_edit_prefill_test.dart` (append)

**Interfaces:**
- Consumes: Task 5 `passportScanLauncherProvider`, `resolveScannedTag`, results from Task 3; `equipmentRepositoryProvider.getEquipmentById`; 1a `cylinderFillRepositoryProvider.getForCylinder(passportId:, equipmentId:)` (newest first); `TankPresets.matchBySpecs`, `TankPresetEntity.fromBuiltIn`.
- Produces: `TankEditor({..., ValueChanged<EquipmentItem>? onCylinderScanned})`; `TankRow({..., ValueChanged<EquipmentItem>? onCylinderScanned})`; the header `IconButton` keyed `Key('tank-scan-tag')`.

An own cylinder fills the spec and the newest fill's mix, and is reported through `onCylinderScanned`, which the dive edit page turns into `_addGear([item])`. A foreign cylinder fills the spec only. The tank's `equipmentId` is never touched.

- [ ] **Step 1: Write the failing editor test**

Create `test/features/dive_log/presentation/widgets/tank_editor_scan_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

class _PresetListNotifier
    extends StateNotifier<AsyncValue<List<TankPresetEntity>>>
    implements TankPresetListNotifier {
  _PresetListNotifier(List<TankPresetEntity> presets)
    : super(AsyncValue.data(presets));

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  const own = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  const stranger = '11111111-2222-4333-8444-555555555555';
  late String ownId;

  setUp(() async {
    await setUpTestDatabase();
    final item = await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: '',
        name: 'Faber 12',
        type: EquipmentType.tank,
        attributes: [
          EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: EquipmentAttrKeys.volumeL,
            valueNum: 12,
          ),
          EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: EquipmentAttrKeys.workingPressureBar,
            valueNum: 232,
          ),
          EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: EquipmentAttrKeys.tankMaterial,
            valueText: 'steel',
          ),
        ],
      ),
    );
    ownId = item.id;
    await CylinderPassportRepository().assignPassportId(
      equipmentId: ownId,
      passportId: own,
    );
    final t = DateTime(2026, 9, 20);
    await CylinderFillRepository().create(
      CylinderFill(
        id: '',
        passportId: own,
        equipmentId: ownId,
        filledAt: t,
        o2Percent: 32,
        createdAt: t,
        updatedAt: t,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    required String? scanned,
    required void Function(DiveTank) onChanged,
    void Function(EquipmentItem)? onCylinderScanned,
    MockSettingsNotifier? settings,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final presets = TankPresets.all.map(TankPresetEntity.fromBuiltIn).toList();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => settings ?? MockSettingsNotifier(),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          tankPresetListNotifierProvider.overrideWith(
            (ref) => _PresetListNotifier(presets),
          ),
          tankPresetsProvider.overrideWith((ref) => Future.value(presets)),
          activeEquipmentProvider.overrideWith((ref) async => const []),
          passportScanLauncherProvider.overrideWithValue(
            (context) async => scanned,
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TankEditor(
                tank: const DiveTank(id: 'tank-1'),
                tankNumber: 1,
                onChanged: onChanged,
                onCylinderScanned: onCylinderScanned,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(TankEditor)));
  }

  Future<void> scan(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('tank-scan-tag')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an own cylinder fills spec and mix and joins the dive gear', (
    tester,
  ) async {
    DiveTank? changed;
    EquipmentItem? scannedItem;
    await pump(
      tester,
      scanned: 'https://submersion.app/c#f=1&p=$own',
      onChanged: (t) => changed = t,
      onCylinderScanned: (item) => scannedItem = item,
    );
    await scan(tester);
    expect(changed!.volume, 12);
    expect(changed!.workingPressure, 232);
    expect(changed!.material, TankMaterial.steel);
    expect(changed!.gasMix.o2, 32);
    expect(changed!.equipmentId, isNull);
    expect(scannedItem!.id, ownId);
  });

  testWidgets('a foreign cylinder fills the spec only', (tester) async {
    DiveTank? changed;
    EquipmentItem? scannedItem;
    await pump(
      tester,
      scanned: 'https://submersion.app/c#f=1&p=$stranger&v=10&wp=300&m=al',
      onChanged: (t) => changed = t,
      onCylinderScanned: (item) => scannedItem = item,
    );
    await scan(tester);
    expect(changed!.volume, 10);
    expect(changed!.workingPressure, 300);
    expect(changed!.material, TankMaterial.aluminum);
    expect(changed!.gasMix.o2, 21);
    expect(scannedItem, isNull);
  });

  testWidgets('text that is not a tag changes nothing', (tester) async {
    DiveTank? changed;
    final l10n = await pump(
      tester,
      scanned: 'hello',
      onChanged: (t) => changed = t,
    );
    await scan(tester);
    expect(changed, isNull);
    expect(find.text(l10n.passport_tag_linkInvalid), findsOneWidget);
  });

  testWidgets('imperial units round trip to the same metric spec', (
    tester,
  ) async {
    final settings = MockSettingsNotifier()
      ..setPressureUnit(PressureUnit.psi)
      ..setVolumeUnit(VolumeUnit.cubicFeet);
    DiveTank? changed;
    await pump(
      tester,
      scanned: 'https://submersion.app/c#f=1&p=$own',
      onChanged: (t) => changed = t,
      settings: settings,
    );
    await scan(tester);
    expect(changed!.volume, closeTo(12, 0.1));
    expect(changed!.workingPressure, closeTo(232, 0.5));
  });
}
```

If `MockSettingsNotifier` sets units through other method names, use the ones `tank_editor_test.dart` uses for its imperial test.

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/dive_log/presentation/widgets/tank_editor_scan_test.dart`
Expected: compile error (`onCylinderScanned`), then no `tank-scan-tag` key.

- [ ] **Step 3: Implement in the editor**

In `tank_editor.dart`, add the field and constructor parameter:

```dart
  /// Called with the diver's own cylinder when its tag is scanned, so the
  /// host can add it to the dive's gear (issue #2335). The tank itself never
  /// records the link: `DiveTank.equipmentId` belongs to the transmitter
  /// registry.
  final ValueChanged<EquipmentItem>? onCylinderScanned;
```

(`this.onCylinderScanned,` in the constructor). In `_buildHeader`, before the remove button, add:

```dart
          IconButton(
            key: const Key('tank-scan-tag'),
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: context.l10n.passport_scan_title,
            onPressed: _scanCylinder,
          ),
```

Add the two methods to the state:

```dart
  Future<void> _scanCylinder() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final text = await ref.read(passportScanLauncherProvider)(context);
    if (text == null || !mounted) return;
    try {
      switch (await resolveScannedTag(ref, text)) {
        case OwnCylinder(:final equipmentId, :final tag):
          final item = await ref
              .read(equipmentRepositoryProvider)
              .getEquipmentById(equipmentId);
          final fills = await ref
              .read(cylinderFillRepositoryProvider)
              .getForCylinder(
                passportId: tag.passportId,
                equipmentId: equipmentId,
              );
          if (!mounted || item == null) return;
          _applyScannedSpec(
            volumeL: item.volumeL,
            workingPressureBar: item.workingPressureBar,
            material: item.tankMaterial,
            mix: fills.isEmpty ? null : fills.first.gasMix,
          );
          widget.onCylinderScanned?.call(item);
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.passport_scan_filledFrom(item.name))),
          );
        case ForeignCylinder(:final tag):
          if (!mounted) return;
          _applyScannedSpec(
            volumeL: tag.volumeL,
            workingPressureBar: tag.workingPressureBar?.toDouble(),
            material: tag.material,
            mix: null,
          );
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                l10n.passport_scan_filledFrom(
                  tag.name ?? l10n.passport_foreign_defaultName,
                ),
              ),
            ),
          );
        case NotACylinderTag():
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.passport_tag_linkInvalid)),
          );
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.passport_scan_openFailed)));
    }
  }

  /// Fills the spec fields (and the mix, when given) the way choosing a
  /// preset does, in the diver's units, then reports the tank.
  void _applyScannedSpec({
    double? volumeL,
    double? workingPressureBar,
    TankMaterial? material,
    GasMix? mix,
  }) {
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    final match = volumeL != null && workingPressureBar != null
        ? TankPresets.matchBySpecs(volumeL, workingPressureBar)
        : null;
    setState(() {
      _selectedPreset = match == null ? null : TankPresetEntity.fromBuiltIn(match);
      if (volumeL != null) {
        if (settings.volumeUnit == VolumeUnit.cubicFeet) {
          final cuft =
              match?.volumeCuft ??
              (workingPressureBar == null
                  ? null
                  : volumeL * workingPressureBar / 28.3168);
          if (cuft != null) {
            _volumeController.text = formatRoundedForInput(cuft, 1);
          }
        } else {
          _volumeController.text = formatRoundedForInput(volumeL, 1);
        }
      }
      if (workingPressureBar != null) {
        _workingPressureController.text = formatRoundedForInput(
          units.convertPressure(workingPressureBar),
          0,
        );
      }
      if (material != null) _material = material;
      if (mix != null) {
        _mndDriven = false;
        _o2Controller.text = formatDecimalForInput(mix.o2);
        _heController.text = formatDecimalForInput(mix.he);
        _lastValidO2 = mix.o2;
        _lastValidHe = mix.he;
      }
    });
    _notifyChange();
  }
```

Add the imports the editor lacks: `cylinder_passport_providers.dart`, `passport_resolver.dart`, `passport_scan_sheet.dart`, `scan_cylinder_tag.dart` (and `tank_presets.dart`, `units.dart` if not already imported).

- [ ] **Step 4: Pass it through the row and the page**

In `tank_row.dart`, add `final ValueChanged<EquipmentItem>? onCylinderScanned;` with constructor parameter `this.onCylinderScanned,` and pass `onCylinderScanned: widget.onCylinderScanned,` to the `TankEditor`. In `dive_edit_page.dart`, in the single-dive `TankRow` (the one with `_tanksDirty = true` in its `onChanged`), add:

```dart
              onCylinderScanned: (item) => _addGear([item]),
```

Leave the bulk-add `TankRow` and `BulkTankSpecsEditor` without it: bulk edits describe a cylinder, not one dive's gear.

- [ ] **Step 5: Write the page test**

Append inside the `'DiveEditPage prefill'` group of `dive_edit_prefill_test.dart` (imports: `passport_scan_sheet.dart`, `cylinder_passport_repository.dart`, `equipment_repository_impl.dart`, `equipment_item.dart`, `enums.dart`):

```dart
    testWidgets('scanning an own cylinder in the tank card adds it to the gear', (
      tester,
    ) async {
      const passportId = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
      final item = (await tester.runAsync(
        () => EquipmentRepository().createEquipment(
          const EquipmentItem(id: '', name: 'Faber 12', type: EquipmentType.tank),
        ),
      ))!;
      await tester.runAsync(
        () => CylinderPassportRepository().assignPassportId(
          equipmentId: item.id,
          passportId: passportId,
        ),
      );
      String? savedId;
      await pumpEditPage(
        tester,
        onSaved: (id) => savedId = id,
        extraOverrides: [
          passportScanLauncherProvider.overrideWithValue(
            (context) async => 'https://submersion.app/c#f=1&p=$passportId',
          ),
        ],
      );
      await tester.tap(find.textContaining('Tank 1').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.byKey(const Key('tank-scan-tag')));
      await tester.tap(find.byKey(const Key('tank-scan-tag')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Save'));
      for (var i = 0; i < 100 && savedId == null; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final dive = await tester.runAsync(() => repository.getDiveById(savedId!));
      expect(dive!.equipment.map((e) => e.id), contains(item.id));
    });
```

If the collapsed tank row shows its summary without the word "Tank 1", tap the `TankRow` widget instead: `await tester.tap(find.byType(TankRow).first);`.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/dive_log/presentation/widgets/tank_editor_scan_test.dart test/features/dive_log/presentation/widgets/tank_editor_test.dart test/features/dive_log/presentation/widgets/tank_editor_regulator_test.dart test/features/dive_log/presentation/pages/dive_edit_prefill_test.dart`
Expected: all pass, the existing editor tests unchanged.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/dive_log/presentation/widgets/tank_editor.dart lib/features/dive_log/presentation/widgets/edit_sections/tank_row.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/widgets/tank_editor_scan_test.dart test/features/dive_log/presentation/pages/dive_edit_prefill_test.dart
git commit -m "feat(passports): scan a cylinder tag into a dive's tank and gear

Refs #2335"
```

---

### Task 10: Incoming links

**Files:**
- Create: `lib/features/cylinder_passports/presentation/services/passport_link_dispatcher.dart`
- Modify: `lib/app.dart` (state fields, `initState`, `dispose`, a new `_openPassportLink`)
- Modify: `test/helpers/mock_providers.dart` (`getBaseOverrides` silences the link source)
- Test: `test/features/cylinder_passports/presentation/services/passport_link_dispatcher_test.dart`, `test/app_test.dart` (existing, must stay green)

**Interfaces:**
- Consumes: `PassportPayloadCodec.extractQuery` (null for anything that is not a `/c` tag on the tag hosts or the `submersion://c` scheme), Task 5 `openScannedTag`, `hasAnyDiversProvider`, `rootNavigatorKey`.
- Produces: `abstract interface class IncomingLinkSource { Stream<Uri> get links; }`; `class AppLinksSource implements IncomingLinkSource`; `final incomingLinkSourceProvider = Provider<IncomingLinkSource>`; `class PassportLinkDispatcher { PassportLinkDispatcher({required IncomingLinkSource source, required Future<void> Function(String tagText) open, DateTime Function()? clock, Duration repeatWindow}); void start(); void setReady(bool ready); Future<void> dispose(); }`.

`app_links` reports the link that launched the app through `uriLinkStream` as well as later ones, so the dispatcher listens to the stream only and drops a repeat of the same link inside a short window. `SubmersionApp` exists only after startup (migration, services) finishes, so "not ready" means one thing here: no diver yet, with the setup wizard on screen.

- [ ] **Step 1: Write the failing test**

Create `test/features/cylinder_passports/presentation/services/passport_link_dispatcher_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/presentation/services/passport_link_dispatcher.dart';

class _FakeSource implements IncomingLinkSource {
  final controller = StreamController<Uri>.broadcast();

  @override
  Stream<Uri> get links => controller.stream;
}

void main() {
  const tag =
      'https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  late _FakeSource source;
  late List<String> opened;
  late DateTime now;
  late PassportLinkDispatcher dispatcher;

  setUp(() {
    source = _FakeSource();
    opened = [];
    now = DateTime(2026, 9, 26, 10);
    dispatcher = PassportLinkDispatcher(
      source: source,
      open: (text) async => opened.add(text),
      clock: () => now,
    )..start();
  });
  tearDown(() async {
    await dispatcher.dispose();
    await source.controller.close();
  });

  Future<void> send(String link) async {
    source.controller.add(Uri.parse(link));
    await Future<void>.delayed(Duration.zero);
  }

  test('a tag opens once the app is ready', () async {
    dispatcher.setReady(true);
    await send(tag);
    expect(opened, [tag]);
  });

  test('a link before setup waits and opens once ready', () async {
    dispatcher.setReady(false);
    await send(tag);
    expect(opened, isEmpty);
    dispatcher.setReady(true);
    expect(opened, [tag]);
    // Becoming ready again does not replay it.
    dispatcher.setReady(false);
    dispatcher.setReady(true);
    expect(opened, [tag]);
  });

  test('a repeated link opens once', () async {
    dispatcher.setReady(true);
    await send(tag);
    await send(tag);
    expect(opened, [tag]);
    // The same tag scanned again later is a new request.
    now = now.add(const Duration(seconds: 5));
    await send(tag);
    expect(opened, [tag, tag]);
  });

  test('other links are ignored', () async {
    dispatcher.setReady(true);
    for (final link in [
      'https://submersion.app/f#abc',
      'https://submersion.app/community',
      'https://example.com/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab',
      'com.googleusercontent.apps.123:/oauth2redirect?code=x',
      'adobe+66776bfb6c08aeff345bb6435bf88a06f406d90d://callback?code=x',
    ]) {
      await send(link);
    }
    expect(opened, isEmpty);
  });

  test('the custom scheme form is a tag', () async {
    dispatcher.setReady(true);
    await send(
      'submersion://c?f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab',
    );
    expect(opened, hasLength(1));
  });

  test('a stream error does not stop later links', () async {
    dispatcher.setReady(true);
    source.controller.addError(StateError('boom'));
    await Future<void>.delayed(Duration.zero);
    await send(tag);
    expect(opened, [tag]);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/cylinder_passports/presentation/services/passport_link_dispatcher_test.dart`
Expected: compile error, the file does not exist.

- [ ] **Step 3: Implement the dispatcher**

Create `lib/features/cylinder_passports/presentation/services/passport_link_dispatcher.dart`:

```dart
import 'dart:async';

import 'package:app_links/app_links.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

/// Where incoming links come from. An interface so tests, and the app's own
/// widget tests, never open the platform channel.
abstract interface class IncomingLinkSource {
  Stream<Uri> get links;
}

/// `app_links`: the link that launched the app arrives through the same
/// stream as later ones, on iOS, Android and macOS.
class AppLinksSource implements IncomingLinkSource {
  AppLinksSource([AppLinks? appLinks]) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Stream<Uri> get links => _appLinks.uriLinkStream;
}

final incomingLinkSourceProvider = Provider<IncomingLinkSource>(
  (ref) => AppLinksSource(),
);

/// Turns incoming links into opened passports (spec 13.2): passport tags
/// only, each once, and none before the app can show one.
class PassportLinkDispatcher {
  PassportLinkDispatcher({
    required IncomingLinkSource source,
    required Future<void> Function(String tagText) open,
    DateTime Function()? clock,
    Duration repeatWindow = const Duration(seconds: 2),
  }) : _source = source,
       _open = open,
       _clock = clock ?? DateTime.now,
       _repeatWindow = repeatWindow;

  final IncomingLinkSource _source;
  final Future<void> Function(String tagText) _open;
  final DateTime Function() _clock;
  final Duration _repeatWindow;

  StreamSubscription<Uri>? _subscription;
  bool _ready = false;
  String? _pending;
  String? _lastText;
  DateTime? _lastAt;

  void start() {
    _subscription ??= _source.links.listen(
      _onLink,
      // One unreadable link must not end the subscription.
      onError: (Object _) {},
    );
  }

  /// Ready once a diver exists; a link that arrived before then opens now.
  void setReady(bool ready) {
    _ready = ready;
    final pending = _pending;
    if (!ready || pending == null) return;
    _pending = null;
    unawaited(_open(pending));
  }

  void _onLink(Uri uri) {
    final text = uri.toString();
    // An OAuth callback, a future /f record link, any other page: not ours.
    if (PassportPayloadCodec.extractQuery(text) == null) return;
    final now = _clock();
    final last = _lastAt;
    if (text == _lastText && last != null && now.difference(last) < _repeatWindow) {
      return;
    }
    _lastText = text;
    _lastAt = now;
    if (_ready) {
      unawaited(_open(text));
    } else {
      _pending = text;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/cylinder_passports/presentation/services/passport_link_dispatcher_test.dart`
Expected: all pass.

- [ ] **Step 5: Wire it into the app**

In `lib/app.dart`, add the field beside `_fileShareHandler`:

```dart
  late final PassportLinkDispatcher _passportLinks;
```

In `initState`, after `_fileShareHandler` is created:

```dart
    _passportLinks = PassportLinkDispatcher(
      source: ref.read(incomingLinkSourceProvider),
      open: _openPassportLink,
    );
    // Before a diver exists the setup wizard owns the screen; a tag tapped
    // on a fresh install waits for it.
    ref.listenManual<AsyncValue<bool>>(
      hasAnyDiversProvider,
      (_, next) => _passportLinks.setReady(next.value ?? false),
      fireImmediately: true,
    );
```

In the existing `addPostFrameCallback`, after `_fileShareHandler.initialize();`:

```dart
      _passportLinks.start();
```

In `dispose`, before `_fileShareHandler.dispose();`:

```dart
    _passportLinks.dispose();
```

Add the method:

```dart
  /// Opens a passport tag that arrived as a link. The root navigator's
  /// context sits under the router and the scaffold messenger, which is all
  /// [openScannedTag] needs.
  Future<void> _openPassportLink(String text) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await openScannedTag(context, ref, text);
  }
```

Import `passport_link_dispatcher.dart`, `scan_cylinder_tag.dart` and `diver_providers.dart` (if not already imported).

- [ ] **Step 6: Silence the source in tests**

In `test/helpers/mock_providers.dart`, add:

```dart
/// An incoming-link source with no links, so widget tests of the app root
/// never touch the app_links platform channel.
class NoIncomingLinks implements IncomingLinkSource {
  const NoIncomingLinks();

  @override
  Stream<Uri> get links => const Stream<Uri>.empty();
}
```

and add `incomingLinkSourceProvider.overrideWithValue(const NoIncomingLinks()),` to the list `getBaseOverrides` returns, with the import of `passport_link_dispatcher.dart`.

- [ ] **Step 7: Run the app tests**

Run: `flutter test test/app_test.dart test/features/cylinder_passports/presentation/services/passport_link_dispatcher_test.dart test/architecture/`
Expected: all pass, with no "MissingPluginException" output.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/presentation/services/passport_link_dispatcher.dart lib/app.dart test/helpers/mock_providers.dart test/features/cylinder_passports/presentation/services/passport_link_dispatcher_test.dart
git commit -m "feat(passports): open cylinder tags that arrive as links

Refs #2335"
```

---

### Task 11: Docs and the device checklist

**Files:**
- Modify: `docs/import-formats/cylinder-passport-tag.md`
- Modify: `docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md` (sections 7.2 and 13.2)
- Create: `docs/superpowers/specs/2026-09-26-cylinder-passports-1b-device-checklist.md`

**Interfaces:** none.

- [ ] **Step 1: Update the tag format page**

In `docs/import-formats/cylinder-passport-tag.md`, replace the paragraph that begins "Write the https form. From the release that adds scanning" with:

```markdown
Write the https form. It opens Submersion directly where the app is
installed, once the website's app-link files are published, and a browser
page that shows the snapshot otherwise. Submersion's own scanner (the
Equipment list's menu, and each tank in the dive editor) and pasting the link
work without the website.
```

- [ ] **Step 2: Record the two decisions in the spec**

In section 7.2 of the spec, replace "From the tank editor a hit sets the tank's `equipmentId`, copies the spec and prefills the gas mix from the newest fill" with:

```markdown
From the tank editor a hit copies the spec, prefills the gas mix from the
newest fill, and adds the cylinder to the dive's gear list. It never writes
`dive_tanks.equipment_id`, which the transmitter registry owns (decided
2026-09-26).
```

In section 13.2, replace the bullet that begins "go_router: top-level `/c` and `/f` routes" with:

```markdown
- Links arrive through the `app_links` package; Flutter's own deep linking is
  off on iOS (`FlutterDeepLinkingEnabled` false) and Android
  (`flutter_deeplinking_enabled` false), because it passes only path, query
  and fragment and so dropped the `submersion://c` host (decided 2026-09-26).
  A dispatcher accepts passport tags only, drops a repeat of the same link
  within two seconds, and holds a link that arrives before any diver exists
  until setup finishes.
```

and delete the bullet that begins "Whether Flutter hands the fragment through intact" (the device checklist covers it).

- [ ] **Step 3: Write the device checklist**

Create `docs/superpowers/specs/2026-09-26-cylinder-passports-1b-device-checklist.md`:

```markdown
# Cylinder passports 1b: device checklist

**Issue:** #2335
**Spec:** `docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md`

Everything here needs real hardware; CI runs none of it. Record the device,
OS version and build for each line.

## Prerequisites

- Apple developer portal: Associated Domains enabled for `app.submersion`,
  provisioning profiles regenerated.
- submersion.app serves `/.well-known/apple-app-site-association` (paths
  `/c`, `/c/*`) and `/.well-known/assetlinks.json` (release and debug
  signing fingerprints).
- A printed passport label and its link copied to the clipboard.

## Camera scanning

- [ ] iPhone: Equipment, menu, "Scan a cylinder tag", allow the camera, point
      at an own cylinder's label: its passport opens, once.
- [ ] Android: the same.
- [ ] macOS: the same with the built-in camera.
- [ ] Deny the camera permission: the sheet shows the unavailable message and
      the paste field still opens a tag.
- [ ] A label at 25 mm scans from about 15 cm.

## Links

- [ ] iPhone, app closed: tap `https://submersion.app/c#...` in Notes: the app
      launches on that cylinder's passport.
- [ ] iPhone, app open: the same link opens the passport once.
- [ ] Android, app closed and open: the same two checks.
- [ ] `submersion://c?...` from Notes (iOS) and a messaging app (Android).
- [ ] macOS: open `submersion://c?...` from a browser address bar.
- [ ] Fresh install with no diver: tap a label link; finish setup; the
      passport opens after the wizard, not over it.
- [ ] Google sign-in and the Lightroom connection still complete (their
      callbacks must not be caught by the passport link handling).

## Foreign passport

- [ ] Scan a tag that is not in your gear: the read-only passport shows the
      snapshot and "As written on the tag on <date>".
- [ ] "Use on a dive": a new dive opens with that cylinder as tank 1.
- [ ] "Add to my gear": the cylinder appears in Equipment with hydro and VIP
      baselines from the tag, and its passport opens.

## Dive editor

- [ ] Edit a dive, open tank 1, tap the scan icon, scan an own cylinder: the
      spec and newest mix fill in and the cylinder appears in the dive's gear.
- [ ] Imperial units: the filled volume and pressure show in cuft and psi.
```

- [ ] **Step 4: Scan and commit**

Run: `grep -nP "\x{2014}|\x{2013}" docs/import-formats/cylinder-passport-tag.md docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md docs/superpowers/specs/2026-09-26-cylinder-passports-1b-device-checklist.md`
Expected: no output.

```bash
git add docs/import-formats/cylinder-passport-tag.md docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md docs/superpowers/specs/2026-09-26-cylinder-passports-1b-device-checklist.md
git commit -m "docs: cylinder passport scanning, link intake decisions, device checklist

Refs #2335"
```

---

### Task 12: Whole-project verification and the PR

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format . && flutter analyze`
Expected: `No issues found!`; `git status --short` clean after the format.

- [ ] **Step 2: Generated l10n is current**

Run: `flutter gen-l10n && git status --porcelain -- 'lib/l10n/arb/app_localizations*.dart'`
Expected: no output.

- [ ] **Step 3: Guards**

Run: `flutter test test/architecture/ test/l10n/ test/platform/ test/macos_entitlements_test.dart test/shared/widgets/app_date_picker_adoption_test.dart`
Expected: all pass.

- [ ] **Step 4: Full suite, once**

Run: `flutter test`
Expected: all pass (about 15 minutes). Read the exit status directly, never through a pipe. If a failure lands in a file this branch never touched, rerun that file alone before blaming the branch, and check `origin/main`.

- [ ] **Step 5: Push and open the PR**

The executing skill holds this step for the maintainer's choice (merge, PR or keep). When a PR is chosen:

```bash
git push -u origin HEAD:refs/heads/ericgriffin/cylinder-passports-1b-2335
```

Title: `Cylinder passports 1b: scanning, links and the foreign passport`. Body, with no attribution lines:

```
## Related Issue

Closes #2335
Refs #2333

## Summary

A diver can now scan a cylinder's QR label, paste its link, or open the link
from anywhere, and land on that cylinder's passport. A tank they do not own
opens a read-only passport from the tag alone, with "Use on a dive" and "Add
to my gear". The dive editor's tank card can fill a tank by scanning its tag,
and adds the diver's own cylinder to the dive's gear.

## Changes

- `mobile_scanner` for camera QR on iOS, Android and macOS; paste works
  everywhere.
- `app_links` for incoming links, with Flutter's own deep linking switched
  off: it dropped the `submersion://c` host. Links are filtered to passport
  tags, deduplicated, and held until a diver exists.
- A resolver turns any tag string into an own cylinder, a foreign one, or a
  refusal.
- Foreign passport at `/equipment/tag`, restorable from its location.
- "Use on a dive" prefills a new dive's first tank; "Add to my gear" creates
  the tank, its passport id and clock baselines from the tag in one
  transaction, and refuses cleanly when a cylinder in service holds the id.
- Scan in the Equipment list's menu and on each tank in the dive editor. The
  dive tank's registry-owned equipment link is never written.
- Platform: `submersion` URL scheme, verified `https://submersion.app/c` app
  link, associated domain on iOS, camera strings and entitlements.

## Before a signed iOS release

Enable Associated Domains for `app.submersion` in the Apple developer portal
and regenerate the provisioning profiles. The website must serve the
app-site-association and assetlinks files for links to open the app.

## Test Plan

- [x] `flutter test` passes
- [x] `flutter analyze` passes
- [ ] Device checklist: `docs/superpowers/specs/2026-09-26-cylinder-passports-1b-device-checklist.md`
```

Then bind the PR in the desktop app (`get_status`, then `bind_pr` if not reported). Do not poll CI.
