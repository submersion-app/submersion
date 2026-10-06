# Cylinder Passports 2: NFC Read and Write Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A diver can write a cylinder's passport to an NFC tag from the Tag card (with a report of the tag type, its capacity and which fields fit), read a tag from the scan sheet on a phone, launch the app by tapping a tag with nothing running, and rewrite or reprint a stale tag from the stale hint.

**Architecture:** A pure-Dart layer builds and reads NDEF messages (URI records, the Android Application Record, the fitted plan) over the `ndef_record` types. A small service seam (`NfcTagService`, `NdefTagHandle`) wraps `nfc_manager` and `nfc_manager_ndef`; the write and read logic runs against that seam, so every outcome is tested with fake tags. The Tag card, a new write sheet and 1b's scan sheet use it through Riverpod providers that resolve to an unsupported service off phones.

**Tech Stack:** Flutter 3.47, Riverpod 3 (hand-written providers), `nfc_manager` 4.2.1, `nfc_manager_ndef` 1.1.0, `ndef_record` 1.5.0, `flutter gen-l10n` (11 locales).

**Spec:** `docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md` (sections 6.4, 6.6, 7.1, 8 Tag row, 13.1, 13.3, 15, 16, and the "2 NFC" row of section 17).

## Global Constraints

- No schema rung. Nothing is stored when a tag is written or read.
- Dependencies, exactly: `nfc_manager: ^4.2.1`, `nfc_manager_ndef: ^1.1.0`, `ndef_record: ^1.5.0` (direct, because `lib/` imports it and `depend_on_referenced_packages` is on).
- Platform floors stay as they are: iOS 15.0, Android minSdk 26 (the package needs iOS 13 and minSdk 24).
- NFC runs on iOS and Android only. Everywhere else `nfcTagServiceProvider` is `UnsupportedNfcTagService`, and NFC actions show disabled with a reason (spec 13.3).
- Capacity is the NDEF message size the phone reports (`Ndef.maxSize`), never the Type 2 TLV-inclusive figure `NdefFit.fit` uses. Ruling, recorded in the spec by Task 8.
- The iOS entitlement lists both `NDEF` and `TAG`: `nfc_manager` 4 reads and writes through `NFCTagReaderSession`, which needs `TAG`. Ruling, recorded in the spec by Task 8.
- NFC off is explained in text ("Turn it on in the system settings"), with no settings link. Spec 15 asks for a link, but `permission_handler`'s `openAppSettings` opens the app's own page, which has no NFC switch; the switch is Android's system NFC page, and iOS cannot turn NFC off at all. Ruling; the cost is one extra step for the diver.
- A written message is the identity URI record, then the Android Application Record for `app.submersion` when room remains. The signed fill record (spec 6.4's second record) is phase 3.
- Every write is confirmed by reading it back; a write that fails read-back is reported as not written, and Retry writes the whole message again (spec 15).
- Release prerequisite: enable NFC Tag Reading for `app.submersion` in the Apple developer portal and regenerate the provisioning profiles before a signed iOS build.
- PR body: `Closes #2336` and `Refs #2333`. No attribution lines anywhere. No em or en dashes in any text.
- Work in `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/peptides-vs-proteins-c0dbc6` on branch `ericgriffin/cylinder-passports-2-2336`. Stage explicit paths, never `git add -A` or `-u`.

## Review Focus

Inputs the spec implies and no obvious test covers, most likely to bite first. Each has its test pinned to the owning task.

1. The tag leaves the field mid-write (the write throws): the diver must see "not written" with Try again, never success, and Try again must write the whole message again (Task 4 "a tag lost mid-write reports the failure", Task 5 "a failed write retries from the start").
2. A locked tag, or a tag that cannot hold NDEF at all: a specific message, nothing written, nothing claimed (Task 4 "a locked tag is refused without writing", Task 5 "a locked tag says so").
3. A tag that reports the write but reads back different content: it was not written (Task 4 "a tag that reads back differently was not written").
4. A tag whose first record is the Android record, another app's link or a future fill record: the reader must still find the passport; a tag with only foreign data is "not a cylinder tag" (Task 3 "skips the AAR, another app and a fill record", Task 6 "a tag with no passport says so").
5. NFC off, NFC unsupported (desktop, an iPad), or the diver dismissing the iOS system sheet: disabled with a reason, or a quiet close, never an error (Task 5 "closing the system sheet closes quietly", Task 6 "NFC turned off explains itself", Task 7 "Write NFC tag explains why it is off").

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/cylinder_passports/domain/services/passport_ndef.dart` (create) | URI record encode and decode (NFC Forum prefix table), the Android Application Record, the fitted message plan, the first passport URI in a message |
| `lib/features/cylinder_passports/data/services/nfc_tag_service.dart` (create) | `NfcSupport`, `NdefTagHandle`, `NfcTagService`, `NfcSessionCancelled`, `UnsupportedNfcTagService` |
| `lib/features/cylinder_passports/data/services/nfc_manager_tag_service.dart` (create) | The `nfc_manager` glue: availability, one-tag sessions, the handle adapter |
| `lib/features/cylinder_passports/data/services/passport_tag_io.dart` (create) | Write and read outcomes, `writePassportTo`, `readPassportFrom`, `friendlyTagType` |
| `lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart` (modify) | `nfcPlatform`, `nfcTagServiceProvider`, `nfcSupportProvider` |
| `lib/features/cylinder_passports/presentation/utils/nfc_availability_text.dart` (create) | The reason text for NFC off or unsupported |
| `lib/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart` (create) | The write sheet and `tagFieldLabel` |
| `lib/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart` (modify) | Tap an NFC tag on phones |
| `lib/features/cylinder_passports/presentation/widgets/passport_tag_card.dart` (modify) | `fullPayloadFor`, Write NFC tag, Rewrite and Reprint on the stale hint |
| `test/helpers/fake_nfc.dart` (create) | `FakeTagHandle`, `FakeNfcTagService` |
| `test/helpers/mock_providers.dart` (modify) | `getBaseOverrides(nfcTagService:)`, defaulting to unsupported |
| platform files, `pubspec.yaml`, ARBs, docs | as each task lists |

---

### Task 1: Dependencies and platform wiring

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`, `ios/Podfile.lock`, `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`, `android/app/src/main/AndroidManifest.xml`
- Modify: `test/platform/passport_links_config_test.dart`

**Interfaces:**
- Produces: `nfc_manager`, `nfc_manager_ndef` and `ndef_record` importable; the NFC usage string and reader-session entitlement on iOS; the NFC permission, optional feature and `NDEF_DISCOVERED` launch filter on Android.

- [ ] **Step 1: Write the failing platform tests**

In `test/platform/passport_links_config_test.dart`, inside `group('iOS', ...)` after the existing tests, add:

```dart
    test('explains NFC use', () {
      expect(
        plistValue(info, 'NFCReaderUsageDescription')?.innerText,
        contains('cylinder'),
      );
    });

    test('may read and write NDEF tags through a tag session', () {
      // nfc_manager 4 uses NFCTagReaderSession, which needs TAG as well.
      final formats = plistValue(
        entitlements,
        'com.apple.developer.nfc.readersession.formats',
      );
      expect(
        formats?.findElements('string').map((e) => e.innerText.trim()),
        containsAll(['NDEF', 'TAG']),
      );
    });
```

In `group('Android', ...)`, replace the `viewFiltersWithScheme` helper so it only looks at `VIEW` filters (the new `NDEF_DISCOVERED` filter also uses https and would break the existing `.single`):

```dart
    Iterable<XmlElement> viewFiltersWithScheme(String scheme) => activity
        .findElements('intent-filter')
        .where(
          (f) => f
              .findElements('action')
              .any(
                (a) =>
                    a.getAttribute('name', namespaceUri: android) ==
                    'android.intent.action.VIEW',
              ),
        )
        .where(
          (f) => f
              .findElements('data')
              .any(
                (d) =>
                    d.getAttribute('scheme', namespaceUri: android) == scheme,
              ),
        );
```

and add after the camera test:

```dart
    test('uses NFC without requiring it', () {
      expect(
        manifest
            .findElements('uses-permission')
            .map((e) => e.getAttribute('name', namespaceUri: android)),
        contains('android.permission.NFC'),
      );
      final feature = manifest
          .findElements('uses-feature')
          .firstWhere(
            (e) =>
                e.getAttribute('name', namespaceUri: android) ==
                'android.hardware.nfc',
          );
      expect(feature.getAttribute('required', namespaceUri: android), 'false');
    });

    test('a tapped passport tag launches the app', () {
      final filter = activity
          .findElements('intent-filter')
          .singleWhere(
            (f) => f
                .findElements('action')
                .any(
                  (a) =>
                      a.getAttribute('name', namespaceUri: android) ==
                      'android.nfc.action.NDEF_DISCOVERED',
                ),
          );
      expect(
        filter
            .findElements('category')
            .map((c) => c.getAttribute('name', namespaceUri: android)),
        contains('android.intent.category.DEFAULT'),
      );
      final data = filter.findElements('data').single;
      expect(data.getAttribute('scheme', namespaceUri: android), 'https');
      expect(
        data.getAttribute('host', namespaceUri: android),
        'submersion.app',
      );
      expect(data.getAttribute('path', namespaceUri: android), '/c');
    });
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/platform/passport_links_config_test.dart`
Expected: the four new tests fail (keys, permission, feature and filter absent); the existing tests still pass.

- [ ] **Step 3: Add the packages**

Run: `flutter pub add nfc_manager:^4.2.1 nfc_manager_ndef:^1.1.0 ndef_record:^1.5.0`
Expected: all three resolve. If resolution fails on an SDK constraint, stop and report; do not loosen other constraints.

In `pubspec.yaml`, give the three lines a comment in the style of their neighbours:

```yaml
  # NFC tags on cylinders (issue #2336): sessions, the cross-platform NDEF
  # tag, and the NDEF message types the passport layer builds and reads.
  nfc_manager: ^4.2.1
  nfc_manager_ndef: ^1.1.0
  ndef_record: ^1.5.0
```

- [ ] **Step 4: Edit the iOS files**

In `ios/Runner/Info.plist`, inside the top-level `<dict>`, beside the other usage descriptions, add:

```xml
	<key>NFCReaderUsageDescription</key>
	<string>Submersion reads and writes the NFC tags on your cylinders.</string>
```

In `ios/Runner/Runner.entitlements`, inside the `<dict>`, add:

```xml
	<key>com.apple.developer.nfc.readersession.formats</key>
	<array>
		<string>NDEF</string>
		<string>TAG</string>
	</array>
```

- [ ] **Step 5: Edit the Android manifest**

In `android/app/src/main/AndroidManifest.xml`, after the camera `uses-feature` lines, add:

```xml
    <!-- NFC tags on cylinders (issue #2336). Optional: devices without NFC
         must still install the app. NFC is a normal permission. -->
    <uses-permission android:name="android.permission.NFC" />
    <uses-feature android:name="android.hardware.nfc" android:required="false" />
```

Inside the `.MainActivity` `<activity>`, after the `submersion://c` intent filter, add:

```xml
            <!-- A tapped cylinder tag opens the app directly (spec 13.3). -->
            <intent-filter>
                <action android:name="android.nfc.action.NDEF_DISCOVERED"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:scheme="https" android:host="submersion.app" android:path="/c"/>
            </intent-filter>
```

`app_links` forwards any intent's data URI (`AppLinksHelper.getUrl`), so a tag tap reaches 1b's `PassportLinkDispatcher` with no further code.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/platform/passport_links_config_test.dart test/macos_entitlements_test.dart`
Expected: all pass.

- [ ] **Step 7: Prove the iOS build still links**

Write `scratch_ios.sh` in the session scratchpad containing:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/peptides-vs-proteins-c0dbc6
flutter build ios --simulator --debug --no-codesign
```

Run: `bash <scratchpad>/scratch_ios.sh`
Expected: success. A bare `build` word in a Bash command is refused by a deny rule, hence the script. If pods are stale, run `pod install` in `ios/` and retry once.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add pubspec.yaml pubspec.lock ios/Podfile.lock ios/Runner/Info.plist ios/Runner/Runner.entitlements android/app/src/main/AndroidManifest.xml test/platform/passport_links_config_test.dart
git commit -m "feat(passports): NFC packages and platform wiring for cylinder tags

Refs #2336"
```

Stage any other tracked file the build step changed (a generated plugin registrant) only after checking its diff is the NFC plugin's registration.

---

### Task 2: Strings

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb` and the generated `lib/l10n/arb/app_localizations*.dart`
- Test: `test/l10n/` (existing guards)

**Interfaces:**
- Produces these getters, used by later tasks by exactly these names: `passport_nfc_tap`, `passport_nfc_holdNear`, `passport_nfc_write`, `passport_nfc_rewrite`, `passport_nfc_reprint`, `passport_nfc_unsupported`, `passport_nfc_disabled`, `passport_nfc_written`, `passport_nfc_tagInfo(String type, int capacity)`, `passport_nfc_capacity(int capacity)`, `passport_nfc_allFields`, `passport_nfc_fieldsDropped(String fields)`, `passport_nfc_notNdef`, `passport_nfc_readOnly`, `passport_nfc_tooSmall(int capacity)`, `passport_nfc_readBackFailed`, `passport_nfc_writeFailed`, `passport_nfc_readFailed`, `passport_nfc_retry`, `passport_nfc_fieldName`, `passport_nfc_fieldSerial`, `passport_nfc_fieldO2Clean`.
- Reused, not added: `common_action_cancel`, `common_action_close`, `common_action_done`, `passport_tag_linkInvalid`, `attrLabel_*`.

Anchor: insert each locale's block directly after that file's `"passport_foreign_defaultName"` line (a single line in every locale). Placeholder keys carry `@` blocks in English only.

- [ ] **Step 1: English (`app_en.arb`)**

```json
  "passport_nfc_tap": "Tap an NFC tag",
  "passport_nfc_holdNear": "Hold the tag against the back of the phone.",
  "passport_nfc_write": "Write NFC tag",
  "passport_nfc_rewrite": "Rewrite tag",
  "passport_nfc_reprint": "Reprint label",
  "passport_nfc_unsupported": "This device cannot read or write NFC tags.",
  "passport_nfc_disabled": "NFC is turned off. Turn it on in the system settings.",
  "passport_nfc_written": "Tag written and checked",
  "passport_nfc_tagInfo": "{type}, {capacity} bytes",
  "@passport_nfc_tagInfo": {
    "placeholders": {
      "type": {"type": "String"},
      "capacity": {"type": "int"}
    }
  },
  "passport_nfc_capacity": "{capacity} bytes",
  "@passport_nfc_capacity": {
    "placeholders": {
      "capacity": {"type": "int"}
    }
  },
  "passport_nfc_allFields": "Everything fits on this tag.",
  "passport_nfc_fieldsDropped": "Left off to fit: {fields}",
  "@passport_nfc_fieldsDropped": {
    "placeholders": {
      "fields": {"type": "String"}
    }
  },
  "passport_nfc_notNdef": "This tag cannot hold a link. Use an NTAG215 or NTAG216 tag.",
  "passport_nfc_readOnly": "This tag is locked and cannot be written.",
  "passport_nfc_tooSmall": "This tag is too small ({capacity} bytes), even for the cylinder's identity.",
  "@passport_nfc_tooSmall": {
    "placeholders": {
      "capacity": {"type": "int"}
    }
  },
  "passport_nfc_readBackFailed": "The tag did not read back as written, so it was not written.",
  "passport_nfc_writeFailed": "The tag was not written. Hold it still and try again.",
  "passport_nfc_readFailed": "Could not read the tag. Hold it still and try again.",
  "passport_nfc_retry": "Try again",
  "passport_nfc_fieldName": "Name",
  "passport_nfc_fieldSerial": "Serial number",
  "passport_nfc_fieldO2Clean": "O2 clean",
```

- [ ] **Step 2: The other ten locales**

Insert, in the same key order, after each file's `"passport_foreign_defaultName"` line (no `@` blocks):

`app_de.arb`
```json
  "passport_nfc_tap": "NFC-Tag antippen",
  "passport_nfc_holdNear": "Den Tag an die Rückseite des Telefons halten.",
  "passport_nfc_write": "NFC-Tag beschreiben",
  "passport_nfc_rewrite": "Tag neu beschreiben",
  "passport_nfc_reprint": "Etikett neu drucken",
  "passport_nfc_unsupported": "Dieses Gerät kann keine NFC-Tags lesen oder beschreiben.",
  "passport_nfc_disabled": "NFC ist ausgeschaltet. In den Systemeinstellungen einschalten.",
  "passport_nfc_written": "Tag beschrieben und geprüft",
  "passport_nfc_tagInfo": "{type}, {capacity} Byte",
  "passport_nfc_capacity": "{capacity} Byte",
  "passport_nfc_allFields": "Alles passt auf diesen Tag.",
  "passport_nfc_fieldsDropped": "Aus Platzgründen weggelassen: {fields}",
  "passport_nfc_notNdef": "Dieser Tag kann keinen Link speichern. Einen NTAG215- oder NTAG216-Tag verwenden.",
  "passport_nfc_readOnly": "Dieser Tag ist gesperrt und kann nicht beschrieben werden.",
  "passport_nfc_tooSmall": "Dieser Tag ist zu klein ({capacity} Byte), selbst für die Kennung der Flasche.",
  "passport_nfc_readBackFailed": "Der Tag ließ sich nicht wie geschrieben zurücklesen und wurde daher nicht beschrieben.",
  "passport_nfc_writeFailed": "Der Tag wurde nicht beschrieben. Ruhig halten und erneut versuchen.",
  "passport_nfc_readFailed": "Der Tag konnte nicht gelesen werden. Ruhig halten und erneut versuchen.",
  "passport_nfc_retry": "Erneut versuchen",
  "passport_nfc_fieldName": "Name",
  "passport_nfc_fieldSerial": "Seriennummer",
  "passport_nfc_fieldO2Clean": "O2-rein",
```

`app_es.arb`
```json
  "passport_nfc_tap": "Acercar una etiqueta NFC",
  "passport_nfc_holdNear": "Acerca la etiqueta a la parte trasera del teléfono.",
  "passport_nfc_write": "Escribir etiqueta NFC",
  "passport_nfc_rewrite": "Reescribir etiqueta",
  "passport_nfc_reprint": "Reimprimir etiqueta",
  "passport_nfc_unsupported": "Este dispositivo no puede leer ni escribir etiquetas NFC.",
  "passport_nfc_disabled": "El NFC está desactivado. Actívalo en los ajustes del sistema.",
  "passport_nfc_written": "Etiqueta escrita y comprobada",
  "passport_nfc_tagInfo": "{type}, {capacity} bytes",
  "passport_nfc_capacity": "{capacity} bytes",
  "passport_nfc_allFields": "Todo cabe en esta etiqueta.",
  "passport_nfc_fieldsDropped": "Omitido para que quepa: {fields}",
  "passport_nfc_notNdef": "Esta etiqueta no puede guardar un enlace. Usa una etiqueta NTAG215 o NTAG216.",
  "passport_nfc_readOnly": "Esta etiqueta está bloqueada y no se puede escribir.",
  "passport_nfc_tooSmall": "Esta etiqueta es demasiado pequeña ({capacity} bytes), incluso para la identidad de la botella.",
  "passport_nfc_readBackFailed": "La etiqueta no se leyó tal como se escribió, así que no se escribió.",
  "passport_nfc_writeFailed": "La etiqueta no se escribió. Mantenla quieta e inténtalo de nuevo.",
  "passport_nfc_readFailed": "No se pudo leer la etiqueta. Mantenla quieta e inténtalo de nuevo.",
  "passport_nfc_retry": "Reintentar",
  "passport_nfc_fieldName": "Nombre",
  "passport_nfc_fieldSerial": "Número de serie",
  "passport_nfc_fieldO2Clean": "Limpia para O2",
```

`app_fr.arb`
```json
  "passport_nfc_tap": "Approcher une étiquette NFC",
  "passport_nfc_holdNear": "Tenez l'étiquette contre le dos du téléphone.",
  "passport_nfc_write": "Écrire l'étiquette NFC",
  "passport_nfc_rewrite": "Réécrire l'étiquette",
  "passport_nfc_reprint": "Réimprimer l'étiquette",
  "passport_nfc_unsupported": "Cet appareil ne peut ni lire ni écrire d'étiquettes NFC.",
  "passport_nfc_disabled": "Le NFC est désactivé. Activez-le dans les réglages du système.",
  "passport_nfc_written": "Étiquette écrite et vérifiée",
  "passport_nfc_tagInfo": "{type}, {capacity} octets",
  "passport_nfc_capacity": "{capacity} octets",
  "passport_nfc_allFields": "Tout tient sur cette étiquette.",
  "passport_nfc_fieldsDropped": "Omis faute de place : {fields}",
  "passport_nfc_notNdef": "Cette étiquette ne peut pas contenir de lien. Utilisez une étiquette NTAG215 ou NTAG216.",
  "passport_nfc_readOnly": "Cette étiquette est verrouillée et ne peut pas être écrite.",
  "passport_nfc_tooSmall": "Cette étiquette est trop petite ({capacity} octets), même pour l'identité de la bouteille.",
  "passport_nfc_readBackFailed": "L'étiquette ne s'est pas relue telle qu'écrite ; elle n'a donc pas été écrite.",
  "passport_nfc_writeFailed": "L'étiquette n'a pas été écrite. Tenez-la immobile et réessayez.",
  "passport_nfc_readFailed": "Impossible de lire l'étiquette. Tenez-la immobile et réessayez.",
  "passport_nfc_retry": "Réessayer",
  "passport_nfc_fieldName": "Nom",
  "passport_nfc_fieldSerial": "Numéro de série",
  "passport_nfc_fieldO2Clean": "Compatible O2",
```

`app_it.arb`
```json
  "passport_nfc_tap": "Avvicina un tag NFC",
  "passport_nfc_holdNear": "Tieni il tag contro il retro del telefono.",
  "passport_nfc_write": "Scrivi tag NFC",
  "passport_nfc_rewrite": "Riscrivi tag",
  "passport_nfc_reprint": "Ristampa etichetta",
  "passport_nfc_unsupported": "Questo dispositivo non può leggere né scrivere tag NFC.",
  "passport_nfc_disabled": "L'NFC è disattivato. Attivalo nelle impostazioni di sistema.",
  "passport_nfc_written": "Tag scritto e verificato",
  "passport_nfc_tagInfo": "{type}, {capacity} byte",
  "passport_nfc_capacity": "{capacity} byte",
  "passport_nfc_allFields": "Tutto entra in questo tag.",
  "passport_nfc_fieldsDropped": "Omesso per spazio: {fields}",
  "passport_nfc_notNdef": "Questo tag non può contenere un link. Usa un tag NTAG215 o NTAG216.",
  "passport_nfc_readOnly": "Questo tag è bloccato e non può essere scritto.",
  "passport_nfc_tooSmall": "Questo tag è troppo piccolo ({capacity} byte), anche per l'identità della bombola.",
  "passport_nfc_readBackFailed": "Il tag non è stato riletto come scritto, quindi non è stato scritto.",
  "passport_nfc_writeFailed": "Il tag non è stato scritto. Tienilo fermo e riprova.",
  "passport_nfc_readFailed": "Impossibile leggere il tag. Tienilo fermo e riprova.",
  "passport_nfc_retry": "Riprova",
  "passport_nfc_fieldName": "Nome",
  "passport_nfc_fieldSerial": "Numero di serie",
  "passport_nfc_fieldO2Clean": "Pulita per O2",
```

`app_nl.arb`
```json
  "passport_nfc_tap": "Een NFC-tag aantikken",
  "passport_nfc_holdNear": "Houd de tag tegen de achterkant van de telefoon.",
  "passport_nfc_write": "NFC-tag schrijven",
  "passport_nfc_rewrite": "Tag opnieuw schrijven",
  "passport_nfc_reprint": "Label opnieuw afdrukken",
  "passport_nfc_unsupported": "Dit apparaat kan geen NFC-tags lezen of schrijven.",
  "passport_nfc_disabled": "NFC staat uit. Zet het aan in de systeeminstellingen.",
  "passport_nfc_written": "Tag geschreven en gecontroleerd",
  "passport_nfc_tagInfo": "{type}, {capacity} bytes",
  "passport_nfc_capacity": "{capacity} bytes",
  "passport_nfc_allFields": "Alles past op deze tag.",
  "passport_nfc_fieldsDropped": "Weggelaten om te passen: {fields}",
  "passport_nfc_notNdef": "Deze tag kan geen link bevatten. Gebruik een NTAG215- of NTAG216-tag.",
  "passport_nfc_readOnly": "Deze tag is vergrendeld en kan niet worden beschreven.",
  "passport_nfc_tooSmall": "Deze tag is te klein ({capacity} bytes), zelfs voor de identiteit van de fles.",
  "passport_nfc_readBackFailed": "De tag las niet terug zoals geschreven, dus hij is niet geschreven.",
  "passport_nfc_writeFailed": "De tag is niet geschreven. Houd hem stil en probeer het opnieuw.",
  "passport_nfc_readFailed": "De tag kon niet worden gelezen. Houd hem stil en probeer het opnieuw.",
  "passport_nfc_retry": "Opnieuw proberen",
  "passport_nfc_fieldName": "Naam",
  "passport_nfc_fieldSerial": "Serienummer",
  "passport_nfc_fieldO2Clean": "O2-schoon",
```

`app_pt.arb`
```json
  "passport_nfc_tap": "Aproximar uma etiqueta NFC",
  "passport_nfc_holdNear": "Segure a etiqueta contra a parte de trás do telefone.",
  "passport_nfc_write": "Gravar etiqueta NFC",
  "passport_nfc_rewrite": "Regravar etiqueta",
  "passport_nfc_reprint": "Reimprimir etiqueta",
  "passport_nfc_unsupported": "Este dispositivo não consegue ler nem gravar etiquetas NFC.",
  "passport_nfc_disabled": "O NFC está desativado. Ative-o nas configurações do sistema.",
  "passport_nfc_written": "Etiqueta gravada e verificada",
  "passport_nfc_tagInfo": "{type}, {capacity} bytes",
  "passport_nfc_capacity": "{capacity} bytes",
  "passport_nfc_allFields": "Tudo cabe nesta etiqueta.",
  "passport_nfc_fieldsDropped": "Omitido para caber: {fields}",
  "passport_nfc_notNdef": "Esta etiqueta não consegue guardar um link. Use uma etiqueta NTAG215 ou NTAG216.",
  "passport_nfc_readOnly": "Esta etiqueta está bloqueada e não pode ser gravada.",
  "passport_nfc_tooSmall": "Esta etiqueta é pequena demais ({capacity} bytes), até para a identificação do cilindro.",
  "passport_nfc_readBackFailed": "A etiqueta não foi lida de volta como gravada, então não foi gravada.",
  "passport_nfc_writeFailed": "A etiqueta não foi gravada. Segure-a parada e tente novamente.",
  "passport_nfc_readFailed": "Não foi possível ler a etiqueta. Segure-a parada e tente novamente.",
  "passport_nfc_retry": "Tentar novamente",
  "passport_nfc_fieldName": "Nome",
  "passport_nfc_fieldSerial": "Número de série",
  "passport_nfc_fieldO2Clean": "Limpo para O2",
```

`app_hu.arb`
```json
  "passport_nfc_tap": "NFC-címke érintése",
  "passport_nfc_holdNear": "Tartsa a címkét a telefon hátlapjához.",
  "passport_nfc_write": "NFC-címke írása",
  "passport_nfc_rewrite": "Címke újraírása",
  "passport_nfc_reprint": "Címke újranyomtatása",
  "passport_nfc_unsupported": "Ez az eszköz nem tud NFC-címkéket olvasni vagy írni.",
  "passport_nfc_disabled": "Az NFC ki van kapcsolva. Kapcsolja be a rendszerbeállításokban.",
  "passport_nfc_written": "A címke megírva és ellenőrizve",
  "passport_nfc_tagInfo": "{type}, {capacity} bájt",
  "passport_nfc_capacity": "{capacity} bájt",
  "passport_nfc_allFields": "Minden elfér ezen a címkén.",
  "passport_nfc_fieldsDropped": "Helyhiány miatt kimaradt: {fields}",
  "passport_nfc_notNdef": "Ez a címke nem tud hivatkozást tárolni. Használjon NTAG215 vagy NTAG216 címkét.",
  "passport_nfc_readOnly": "Ez a címke zárolva van, nem írható.",
  "passport_nfc_tooSmall": "Ez a címke túl kicsi ({capacity} bájt), még a palack azonosítójához is.",
  "passport_nfc_readBackFailed": "A címke visszaolvasása nem egyezett az írottal, így nem lett megírva.",
  "passport_nfc_writeFailed": "A címke nem lett megírva. Tartsa mozdulatlanul, és próbálja újra.",
  "passport_nfc_readFailed": "A címkét nem sikerült beolvasni. Tartsa mozdulatlanul, és próbálja újra.",
  "passport_nfc_retry": "Újra",
  "passport_nfc_fieldName": "Név",
  "passport_nfc_fieldSerial": "Sorozatszám",
  "passport_nfc_fieldO2Clean": "O2-tiszta",
```

`app_ar.arb`
```json
  "passport_nfc_tap": "المس بطاقة NFC",
  "passport_nfc_holdNear": "ثبّت البطاقة على ظهر الهاتف.",
  "passport_nfc_write": "كتابة بطاقة NFC",
  "passport_nfc_rewrite": "إعادة كتابة البطاقة",
  "passport_nfc_reprint": "إعادة طباعة الملصق",
  "passport_nfc_unsupported": "لا يستطيع هذا الجهاز قراءة بطاقات NFC أو الكتابة عليها.",
  "passport_nfc_disabled": "تقنية NFC متوقفة. شغّلها من إعدادات النظام.",
  "passport_nfc_written": "تمت كتابة البطاقة والتحقق منها",
  "passport_nfc_tagInfo": "{type}، {capacity} بايت",
  "passport_nfc_capacity": "{capacity} بايت",
  "passport_nfc_allFields": "كل البيانات تتسع لهذه البطاقة.",
  "passport_nfc_fieldsDropped": "حُذف لتتسع البطاقة: {fields}",
  "passport_nfc_notNdef": "لا تستطيع هذه البطاقة حفظ رابط. استخدم بطاقة NTAG215 أو NTAG216.",
  "passport_nfc_readOnly": "هذه البطاقة مقفلة ولا يمكن الكتابة عليها.",
  "passport_nfc_tooSmall": "هذه البطاقة صغيرة جدًا ({capacity} بايت)، حتى لمعرّف الأسطوانة.",
  "passport_nfc_readBackFailed": "لم تُقرأ البطاقة كما كُتبت، لذلك لم تُكتب.",
  "passport_nfc_writeFailed": "لم تُكتب البطاقة. ثبّتها وحاول مرة أخرى.",
  "passport_nfc_readFailed": "تعذّرت قراءة البطاقة. ثبّتها وحاول مرة أخرى.",
  "passport_nfc_retry": "إعادة المحاولة",
  "passport_nfc_fieldName": "الاسم",
  "passport_nfc_fieldSerial": "الرقم التسلسلي",
  "passport_nfc_fieldO2Clean": "نظيفة للأكسجين",
```

`app_he.arb`
```json
  "passport_nfc_tap": "הצמדת תג NFC",
  "passport_nfc_holdNear": "הצמידו את התג לגב הטלפון.",
  "passport_nfc_write": "כתיבת תג NFC",
  "passport_nfc_rewrite": "כתיבה מחדש של התג",
  "passport_nfc_reprint": "הדפסה מחדש של התווית",
  "passport_nfc_unsupported": "המכשיר הזה אינו יכול לקרוא או לכתוב תגי NFC.",
  "passport_nfc_disabled": "NFC כבוי. הפעילו אותו בהגדרות המערכת.",
  "passport_nfc_written": "התג נכתב ונבדק",
  "passport_nfc_tagInfo": "{type}, {capacity} בייטים",
  "passport_nfc_capacity": "{capacity} בייטים",
  "passport_nfc_allFields": "הכול נכנס לתג הזה.",
  "passport_nfc_fieldsDropped": "הושמט כדי שייכנס: {fields}",
  "passport_nfc_notNdef": "התג הזה אינו יכול לשמור קישור. השתמשו בתג NTAG215 או NTAG216.",
  "passport_nfc_readOnly": "התג הזה נעול ולא ניתן לכתוב עליו.",
  "passport_nfc_tooSmall": "התג הזה קטן מדי ({capacity} בייטים), אפילו למזהה המיכל.",
  "passport_nfc_readBackFailed": "התג לא נקרא בחזרה כפי שנכתב, ולכן לא נכתב.",
  "passport_nfc_writeFailed": "התג לא נכתב. החזיקו אותו יציב ונסו שוב.",
  "passport_nfc_readFailed": "לא ניתן היה לקרוא את התג. החזיקו אותו יציב ונסו שוב.",
  "passport_nfc_retry": "ניסיון חוזר",
  "passport_nfc_fieldName": "שם",
  "passport_nfc_fieldSerial": "מספר סידורי",
  "passport_nfc_fieldO2Clean": "נקי ל-O2",
```

`app_zh.arb`
```json
  "passport_nfc_tap": "轻触 NFC 标签",
  "passport_nfc_holdNear": "将标签贴近手机背面。",
  "passport_nfc_write": "写入 NFC 标签",
  "passport_nfc_rewrite": "重写标签",
  "passport_nfc_reprint": "重新打印标签",
  "passport_nfc_unsupported": "此设备无法读取或写入 NFC 标签。",
  "passport_nfc_disabled": "NFC 已关闭。请在系统设置中开启。",
  "passport_nfc_written": "标签已写入并校验",
  "passport_nfc_tagInfo": "{type}，{capacity} 字节",
  "passport_nfc_capacity": "{capacity} 字节",
  "passport_nfc_allFields": "所有信息都能写入此标签。",
  "passport_nfc_fieldsDropped": "为适应容量而省略：{fields}",
  "passport_nfc_notNdef": "此标签无法保存链接。请使用 NTAG215 或 NTAG216 标签。",
  "passport_nfc_readOnly": "此标签已锁定，无法写入。",
  "passport_nfc_tooSmall": "此标签太小（{capacity} 字节），连气瓶标识都放不下。",
  "passport_nfc_readBackFailed": "标签回读内容与写入不一致，因此未写入。",
  "passport_nfc_writeFailed": "标签未写入。请保持稳定后重试。",
  "passport_nfc_readFailed": "无法读取标签。请保持稳定后重试。",
  "passport_nfc_retry": "重试",
  "passport_nfc_fieldName": "名称",
  "passport_nfc_fieldSerial": "序列号",
  "passport_nfc_fieldO2Clean": "氧气清洁",
```

- [ ] **Step 3: Regenerate and run the guards**

Run: `flutter gen-l10n` then `flutter test test/l10n/`
Expected: generation succeeds; all l10n guards pass.

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/l10n/
git commit -m "feat(l10n): NFC tag reading and writing strings

Refs #2336"
```

---

### Task 3: NDEF messages for a passport

**Files:**
- Create: `lib/features/cylinder_passports/domain/services/passport_ndef.dart`
- Test: `test/features/cylinder_passports/domain/services/passport_ndef_test.dart`

**Interfaces:**
- Consumes (1a): `PassportPayloadCodec.httpsUrl`, `PassportPayloadCodec.extractQuery`, `NdefFit.dropOrder`, `NdefFit.drop`, `NdefFit.uriRecordMessageBytes`, `CylinderPassportPayload` (Equatable).
- Produces: `const String passportAndroidPackage`; `NdefRecord uriRecord(String url)`; `String? uriOf(NdefRecord record)`; `NdefRecord androidApplicationRecord()`; `String? firstPassportUri(NdefMessage message)`; `class PassportNdefPlan { NdefMessage message; CylinderPassportPayload payload; List<String> droppedKeys; bool includesAndroidRecord; }`; `PassportNdefPlan? planPassportMessage(CylinderPassportPayload payload, {required int maxMessageBytes})`.

- [ ] **Step 1: Write the failing test**

Create `test/features/cylinder_passports/domain/services/passport_ndef_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
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

  group('URI records', () {
    test('https uses the one-byte prefix code 4', () {
      final record = uriRecord('https://submersion.app/c#f=1');
      expect(record.typeNameFormat, TypeNameFormat.wellKnown);
      expect(record.type, [0x55]);
      expect(record.payload.first, 0x04);
      expect(utf8.decode(record.payload.sublist(1)), 'submersion.app/c#f=1');
    });

    test('round trips through the prefix table', () {
      for (final url in [
        'https://submersion.app/c#f=1&p=$id',
        'http://www.example.com/x',
        'submersion://c?f=1',
        'tel:+15551234',
      ]) {
        expect(uriOf(uriRecord(url)), url);
      }
    });

    test("matches NdefFit's size model", () {
      // NdefFit counts the Type 2 TLV (2 bytes, 4 from 255) and the
      // terminator around the record; the phone reports the message alone.
      final url = PassportPayloadCodec.httpsUrl(full);
      final bytes = uriRecord(url).byteLength;
      expect(
        NdefFit.uriRecordMessageBytes(url),
        bytes + (bytes < 255 ? 3 : 5),
      );
    });

    test('any other record carries no URI', () {
      expect(uriOf(androidApplicationRecord()), isNull);
    });

    test('an unknown prefix code or bad UTF-8 carries no URI', () {
      NdefRecord raw(List<int> payload) => NdefRecord(
        typeNameFormat: TypeNameFormat.wellKnown,
        type: Uint8List.fromList(const [0x55]),
        identifier: Uint8List(0),
        payload: Uint8List.fromList(payload),
      );
      expect(uriOf(raw(const [0x40, 0x61])), isNull);
      expect(uriOf(raw(const [0x04, 0xff, 0xfe])), isNull);
      expect(uriOf(raw(const [])), isNull);
    });
  });

  test('the Android record names the app', () {
    final record = androidApplicationRecord();
    expect(record.typeNameFormat, TypeNameFormat.external);
    expect(utf8.decode(record.type), 'android.com:pkg');
    expect(utf8.decode(record.payload), passportAndroidPackage);
  });

  group('firstPassportUri', () {
    test('skips the AAR, another app and a fill record', () {
      final tag = PassportPayloadCodec.httpsUrl(full);
      final message = NdefMessage(
        records: [
          androidApplicationRecord(),
          uriRecord('https://example.com/menu'),
          uriRecord('https://submersion.app/f#token'),
          uriRecord(tag),
        ],
      );
      expect(firstPassportUri(message), tag);
    });

    test('a tag with no passport has none', () {
      final message = NdefMessage(
        records: [uriRecord('https://example.com/c#f=1')],
      );
      expect(firstPassportUri(message), isNull);
      expect(firstPassportUri(const NdefMessage(records: [])), isNull);
    });
  });

  group('planPassportMessage', () {
    test('a roomy tag gets everything and the Android record', () {
      final plan = planPassportMessage(full, maxMessageBytes: 496)!;
      expect(plan.payload, full);
      expect(plan.droppedKeys, isEmpty);
      expect(plan.includesAndroidRecord, isTrue);
      expect(
        plan.message.records.first,
        uriRecord(PassportPayloadCodec.httpsUrl(full)),
      );
      expect(plan.message.records.last, androidApplicationRecord());
      expect(plan.message.byteLength, lessThanOrEqualTo(496));
    });

    test('a small tag drops keys in the fixed order and keeps the identity', () {
      final plan = planPassportMessage(full, maxMessageBytes: 100)!;
      expect(plan.message.byteLength, lessThanOrEqualTo(100));
      expect(plan.payload.passportId, id);
      expect(plan.payload.writtenOn, full.writtenOn);
      expect(plan.droppedKeys, isNotEmpty);
      expect(
        plan.droppedKeys,
        NdefFit.dropOrder.take(plan.droppedKeys.length).toList(),
      );
    });

    test('the Android record goes only where room remains', () {
      final fitted = planPassportMessage(full, maxMessageBytes: 100)!.payload;
      final tight = uriRecord(PassportPayloadCodec.httpsUrl(fitted)).byteLength;
      final plan = planPassportMessage(fitted, maxMessageBytes: tight)!;
      expect(plan.includesAndroidRecord, isFalse);
      expect(plan.message.records, hasLength(1));
    });

    test('null when even the identity does not fit', () {
      expect(planPassportMessage(full, maxMessageBytes: 40), isNull);
    });

    test('keys the payload never had are not reported as dropped', () {
      final bare = CylinderPassportPayload(
        passportId: id,
        writtenOn: DateTime(2026, 9, 25),
      );
      expect(planPassportMessage(bare, maxMessageBytes: 496)!.droppedKeys, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/cylinder_passports/domain/services/passport_ndef_test.dart`
Expected: compile error, the file does not exist.

- [ ] **Step 3: Implement**

Create `lib/features/cylinder_passports/domain/services/passport_ndef.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:ndef_record/ndef_record.dart';

import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

/// The package an Android Application Record names, so a tap opens
/// Submersion rather than asking which app should (spec 6.4).
const String passportAndroidPackage = 'app.submersion';

/// URI identifier codes from the NFC Forum URI record type definition; the
/// index is the code.
const List<String> _uriPrefixes = [
  '',
  'http://www.',
  'https://www.',
  'http://',
  'https://',
  'tel:',
  'mailto:',
  'ftp://anonymous:anonymous@',
  'ftp://ftp.',
  'ftps://',
  'sftp://',
  'smb://',
  'nfs://',
  'ftp://',
  'dav://',
  'news:',
  'telnet://',
  'imap:',
  'rtsp://',
  'urn:',
  'pop:',
  'sip:',
  'sips:',
  'tftp:',
  'btspp://',
  'btl2cap://',
  'btgoep://',
  'tcpobex://',
  'irdaobex://',
  'file://',
  'urn:epc:id:',
  'urn:epc:tag:',
  'urn:epc:pat:',
  'urn:epc:raw:',
  'urn:epc:',
  'urn:nfc:',
];

/// A well-known URI record for [url], abbreviated by the longest matching
/// prefix code (`https://` is code 4, the size [NdefFit] assumes).
NdefRecord uriRecord(String url) {
  var code = 0;
  for (var i = 1; i < _uriPrefixes.length; i++) {
    final prefix = _uriPrefixes[i];
    if (url.startsWith(prefix) &&
        prefix.length > _uriPrefixes[code].length) {
      code = i;
    }
  }
  final rest = url.substring(_uriPrefixes[code].length);
  return NdefRecord(
    typeNameFormat: TypeNameFormat.wellKnown,
    type: Uint8List.fromList(const [0x55]),
    identifier: Uint8List(0),
    payload: Uint8List.fromList([code, ...utf8.encode(rest)]),
  );
}

/// The URI a well-known URI record carries; null for any other record, an
/// unknown prefix code, or text that is not UTF-8.
String? uriOf(NdefRecord record) {
  if (record.typeNameFormat != TypeNameFormat.wellKnown) return null;
  if (record.type.length != 1 || record.type[0] != 0x55) return null;
  if (record.payload.isEmpty) return null;
  final code = record.payload[0];
  if (code >= _uriPrefixes.length) return null;
  try {
    return _uriPrefixes[code] + utf8.decode(record.payload.sublist(1));
  } on FormatException {
    return null;
  }
}

/// An Android Application Record naming [passportAndroidPackage].
NdefRecord androidApplicationRecord() => NdefRecord(
  typeNameFormat: TypeNameFormat.external,
  type: Uint8List.fromList(utf8.encode('android.com:pkg')),
  identifier: Uint8List(0),
  payload: Uint8List.fromList(utf8.encode(passportAndroidPackage)),
);

/// The first passport tag URI in [message], in record order. The Android
/// record, a fill record and another app's data are skipped (spec 6.4:
/// readers ignore records they do not know).
String? firstPassportUri(NdefMessage message) {
  for (final record in message.records) {
    final uri = uriOf(record);
    if (uri != null && PassportPayloadCodec.extractQuery(uri) != null) {
      return uri;
    }
  }
  return null;
}

/// What a write puts on a tag.
class PassportNdefPlan {
  const PassportNdefPlan({
    required this.message,
    required this.payload,
    required this.droppedKeys,
    required this.includesAndroidRecord,
  });

  final NdefMessage message;

  /// The payload the identity record carries, after any drops.
  final CylinderPassportPayload payload;

  /// Keys the full payload had and the tag could not hold, in drop order.
  final List<String> droppedKeys;

  final bool includesAndroidRecord;
}

/// The message for [payload] on a tag whose NDEF message may take
/// [maxMessageBytes], as the phone reports it: the identity URI record with
/// optional keys dropped in [NdefFit.dropOrder] until it fits, then the
/// Android Application Record when room remains. Null when even the
/// identity (`f`, `p`, `w`) does not fit.
PassportNdefPlan? planPassportMessage(
  CylinderPassportPayload payload, {
  required int maxMessageBytes,
}) {
  var current = payload;
  final dropped = <String>[];
  var i = 0;
  while (true) {
    final identity = uriRecord(PassportPayloadCodec.httpsUrl(current));
    if (identity.byteLength <= maxMessageBytes) {
      final aar = androidApplicationRecord();
      final withAar = identity.byteLength + aar.byteLength <= maxMessageBytes;
      return PassportNdefPlan(
        message: NdefMessage(records: [identity, if (withAar) aar]),
        payload: current,
        droppedKeys: List.unmodifiable(dropped),
        includesAndroidRecord: withAar,
      );
    }
    if (i >= NdefFit.dropOrder.length) return null;
    final key = NdefFit.dropOrder[i++];
    final next = NdefFit.drop(current, key);
    if (next != current) dropped.add(key);
    current = next;
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/cylinder_passports/domain/services/passport_ndef_test.dart`
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/domain/services/passport_ndef.dart test/features/cylinder_passports/domain/services/passport_ndef_test.dart
git commit -m "feat(passports): build and read the NDEF message a cylinder tag carries

Refs #2336"
```

---

### Task 4: The NFC service seam

**Files:**
- Create: `lib/features/cylinder_passports/data/services/nfc_tag_service.dart`
- Create: `lib/features/cylinder_passports/data/services/passport_tag_io.dart`
- Create: `lib/features/cylinder_passports/data/services/nfc_manager_tag_service.dart`
- Modify: `lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart`
- Create: `test/helpers/fake_nfc.dart`
- Modify: `test/helpers/mock_providers.dart` (`getBaseOverrides`)
- Test: `test/features/cylinder_passports/data/services/passport_tag_io_test.dart`, `test/features/cylinder_passports/presentation/providers/nfc_providers_test.dart`

**Interfaces:**
- Consumes: Task 3 `planPassportMessage`, `firstPassportUri`, `PassportNdefPlan`.
- Produces:
  - `enum NfcSupport { enabled, disabled, unsupported }`
  - `abstract interface class NdefTagHandle { bool get isWritable; int get maxMessageBytes; String? get typeLabel; Future<NdefMessage?> read(); Future<void> write(NdefMessage message); }`
  - `abstract interface class NfcTagService { Future<NfcSupport> support(); Future<T> withTag<T>({required String promptIos, required Future<T> Function(NdefTagHandle? tag) onTag}); Future<void> cancel(); }` where a null tag is one that cannot hold NDEF, and `withTag` throws `NfcSessionCancelled` when the diver dismisses the iOS sheet or `cancel()` is called.
  - `class NfcSessionCancelled implements Exception`; `class UnsupportedNfcTagService implements NfcTagService`; `class NfcManagerTagService implements NfcTagService`.
  - `sealed class PassportTagWrite` with `TagWritten(plan, capacity, typeLabel)`, `TagNotNdef`, `TagReadOnly`, `TagTooSmall(capacity)`, `TagReadBackMismatch`, `TagWriteFailed(error)`; `Future<PassportTagWrite> writePassportTo(NdefTagHandle? tag, CylinderPassportPayload payload)`.
  - `sealed class PassportTagRead` with `TagReadText(text)`, `TagHasNoPassport`, `TagReadFailed(error)`; `Future<PassportTagRead> readPassportFrom(NdefTagHandle? tag)`.
  - `String? friendlyTagType(String? platformType)`.
  - `bool nfcPlatform()`; `final nfcTagServiceProvider = Provider<NfcTagService>`; `final nfcSupportProvider = FutureProvider.autoDispose<NfcSupport>`.
  - Test helpers `FakeTagHandle`, `FakeNfcTagService`; `getBaseOverrides({..., NfcTagService? nfcTagService})`, defaulting to `UnsupportedNfcTagService()`.

The write and read logic run against `NdefTagHandle`, so every outcome is tested with fake tags. `NfcManagerTagService` is the thin plugin glue; it cannot run off a device and is covered by the device checklist (Task 8).

- [ ] **Step 1: Write the test helpers**

Create `test/helpers/fake_nfc.dart`:

```dart
import 'package:ndef_record/ndef_record.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';

/// A tag that stores what is written and reads it back, unless told to
/// fail or to read back something else.
class FakeTagHandle implements NdefTagHandle {
  FakeTagHandle({
    this.isWritable = true,
    this.maxMessageBytes = 496,
    this.typeLabel = 'org.nfcforum.ndef.type2',
    this.stored,
    this.writeError,
    this.readError,
    this.readBackOverride,
  });

  @override
  final bool isWritable;

  @override
  final int maxMessageBytes;

  @override
  final String? typeLabel;

  NdefMessage? stored;
  Object? writeError;
  Object? readError;
  NdefMessage? readBackOverride;
  int writes = 0;

  @override
  Future<NdefMessage?> read() async {
    if (readError case final error?) throw error;
    return readBackOverride ?? stored;
  }

  @override
  Future<void> write(NdefMessage message) async {
    writes++;
    if (writeError case final error?) throw error;
    stored = message;
  }
}

/// A session that hands [tag] (null: a tag that cannot hold NDEF) straight
/// to the caller, or reports the diver closing it when [cancelled].
class FakeNfcTagService implements NfcTagService {
  FakeNfcTagService({
    this.supportValue = NfcSupport.enabled,
    this.tag,
    this.cancelled = false,
  });

  NfcSupport supportValue;
  NdefTagHandle? tag;
  bool cancelled;
  int sessions = 0;
  int cancels = 0;

  @override
  Future<NfcSupport> support() async => supportValue;

  @override
  Future<T> withTag<T>({
    required String promptIos,
    required Future<T> Function(NdefTagHandle? tag) onTag,
  }) async {
    sessions++;
    if (cancelled) throw const NfcSessionCancelled();
    return onTag(tag);
  }

  @override
  Future<void> cancel() async => cancels++;
}
```

- [ ] **Step 2: Write the failing tests**

Create `test/features/cylinder_passports/data/services/passport_tag_io_test.dart`:

```dart
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/data/services/passport_tag_io.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

import '../../../../helpers/fake_nfc.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final payload = CylinderPassportPayload(
    passportId: id,
    writtenOn: DateTime(2026, 9, 25),
    name: 'Club 10',
    volumeL: 10,
    workingPressureBar: 300,
    material: TankMaterial.steel,
  );

  group('writePassportTo', () {
    test('writes the plan and confirms it by reading back', () async {
      final tag = FakeTagHandle();
      final result = await writePassportTo(tag, payload);
      expect(result, isA<TagWritten>());
      final written = result as TagWritten;
      expect(tag.stored, written.plan.message);
      expect(written.capacity, 496);
      expect(written.typeLabel, 'org.nfcforum.ndef.type2');
      expect(firstPassportUri(tag.stored!), PassportPayloadCodec.httpsUrl(payload));
    });

    test('a tag that cannot hold NDEF is refused', () async {
      expect(await writePassportTo(null, payload), isA<TagNotNdef>());
    });

    test('a locked tag is refused without writing', () async {
      final tag = FakeTagHandle(isWritable: false);
      expect(await writePassportTo(tag, payload), isA<TagReadOnly>());
      expect(tag.writes, 0);
    });

    test('a tag too small for the identity is refused with its capacity', () async {
      final tag = FakeTagHandle(maxMessageBytes: 40);
      final result = await writePassportTo(tag, payload);
      expect((result as TagTooSmall).capacity, 40);
      expect(tag.writes, 0);
    });

    test('a tag that reads back differently was not written', () async {
      final tag = FakeTagHandle(
        readBackOverride: NdefMessage(
          records: [uriRecord('https://example.com/')],
        ),
      );
      expect(await writePassportTo(tag, payload), isA<TagReadBackMismatch>());
    });

    test('a tag lost mid-write reports the failure', () async {
      final tag = FakeTagHandle(
        writeError: PlatformException(code: 'io_exception'),
      );
      final result = await writePassportTo(tag, payload);
      expect((result as TagWriteFailed).error, isA<PlatformException>());
    });

    test('a failed read-back reports the failure', () async {
      final tag = FakeTagHandle(
        readError: PlatformException(code: 'io_exception'),
      );
      expect(await writePassportTo(tag, payload), isA<TagWriteFailed>());
    });
  });

  group('readPassportFrom', () {
    final text = PassportPayloadCodec.httpsUrl(payload);

    test('returns the passport link the tag holds', () async {
      final tag = FakeTagHandle(
        stored: NdefMessage(records: [androidApplicationRecord(), uriRecord(text)]),
      );
      expect((await readPassportFrom(tag) as TagReadText).text, text);
    });

    test('a tag with no passport, or none at all, has none', () async {
      expect(await readPassportFrom(null), isA<TagHasNoPassport>());
      expect(await readPassportFrom(FakeTagHandle()), isA<TagHasNoPassport>());
      final other = FakeTagHandle(
        stored: NdefMessage(records: [uriRecord('https://example.com/')]),
      );
      expect(await readPassportFrom(other), isA<TagHasNoPassport>());
    });

    test('a read that fails reports it', () async {
      final tag = FakeTagHandle(readError: PlatformException(code: 'io'));
      expect(await readPassportFrom(tag), isA<TagReadFailed>());
    });
  });

  test('friendlyTagType names the NFC Forum types', () {
    expect(friendlyTagType('org.nfcforum.ndef.type2'), 'NFC Forum Type 2');
    expect(friendlyTagType('com.nxp.ndef.mifareclassic'), 'MIFARE Classic');
    expect(friendlyTagType('something.else'), 'something.else');
    expect(friendlyTagType(null), isNull);
  });
}
```

Create `test/features/cylinder_passports/presentation/providers/nfc_providers_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_manager_tag_service.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';

import '../../../../helpers/fake_nfc.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  NfcTagService serviceOn(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(nfcTagServiceProvider);
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test('${platform.name} uses the phone NFC reader', () {
      expect(serviceOn(platform), isA<NfcManagerTagService>());
    });
  }

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    test('${platform.name} has no NFC', () async {
      final service = serviceOn(platform);
      expect(service, isA<UnsupportedNfcTagService>());
      expect(await service.support(), NfcSupport.unsupported);
    });
  }

  test('support comes from the service', () async {
    final container = ProviderContainer(
      overrides: [
        nfcTagServiceProvider.overrideWithValue(
          FakeNfcTagService(supportValue: NfcSupport.disabled),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(nfcSupportProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(nfcSupportProvider.future), NfcSupport.disabled);
  });
}
```

- [ ] **Step 3: Run them to see them fail**

Run: `flutter test test/features/cylinder_passports/data/services/passport_tag_io_test.dart test/features/cylinder_passports/presentation/providers/nfc_providers_test.dart`
Expected: compile errors, the files do not exist.

- [ ] **Step 4: Implement the seam**

Create `lib/features/cylinder_passports/data/services/nfc_tag_service.dart`:

```dart
import 'package:ndef_record/ndef_record.dart';

/// Whether this device can read and write NFC tags right now.
enum NfcSupport { enabled, disabled, unsupported }

/// One NFC tag that can hold NDEF, as the passport write and read need it.
abstract interface class NdefTagHandle {
  bool get isWritable;

  /// The largest NDEF message the tag takes, in bytes, as the phone
  /// reports it (the TLV wrapper is not counted).
  int get maxMessageBytes;

  /// The platform's name for the tag type, when it gives one.
  String? get typeLabel;

  Future<NdefMessage?> read();

  Future<void> write(NdefMessage message);
}

/// The diver closed the system NFC sheet, or [NfcTagService.cancel] ran.
class NfcSessionCancelled implements Exception {
  const NfcSessionCancelled();
}

/// NFC sessions, one tag at a time.
abstract interface class NfcTagService {
  Future<NfcSupport> support();

  /// Waits for a tag, runs [onTag] with it (null when it cannot hold NDEF),
  /// ends the session and returns [onTag]'s result. [promptIos] is shown on
  /// the iOS system sheet. Throws [NfcSessionCancelled] when the diver
  /// dismisses that sheet or [cancel] is called.
  Future<T> withTag<T>({
    required String promptIos,
    required Future<T> Function(NdefTagHandle? tag) onTag,
  });

  /// Ends a waiting session.
  Future<void> cancel();
}

/// Where there is no NFC: desktop, web, and tests by default.
class UnsupportedNfcTagService implements NfcTagService {
  const UnsupportedNfcTagService();

  @override
  Future<NfcSupport> support() async => NfcSupport.unsupported;

  @override
  Future<T> withTag<T>({
    required String promptIos,
    required Future<T> Function(NdefTagHandle? tag) onTag,
  }) => Future<T>.error(StateError('NFC is not supported on this device'));

  @override
  Future<void> cancel() async {}
}
```

Create `lib/features/cylinder_passports/data/services/passport_tag_io.dart`:

```dart
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';

/// How a passport write ended.
sealed class PassportTagWrite {
  const PassportTagWrite();
}

/// Written and confirmed by reading it back.
class TagWritten extends PassportTagWrite {
  const TagWritten({
    required this.plan,
    required this.capacity,
    required this.typeLabel,
  });

  final PassportNdefPlan plan;
  final int capacity;
  final String? typeLabel;
}

/// The tag cannot hold NDEF at all.
class TagNotNdef extends PassportTagWrite {
  const TagNotNdef();
}

/// The tag is locked.
class TagReadOnly extends PassportTagWrite {
  const TagReadOnly();
}

/// Too small even for the identity.
class TagTooSmall extends PassportTagWrite {
  const TagTooSmall(this.capacity);

  final int capacity;
}

/// The tag took the write but reads back something else.
class TagReadBackMismatch extends PassportTagWrite {
  const TagReadBackMismatch();
}

/// The write or the read-back threw: usually the tag left the field.
class TagWriteFailed extends PassportTagWrite {
  const TagWriteFailed(this.error);

  final Object error;
}

/// Writes [payload] to [tag] (spec 13.3): fits it to the tag, writes the
/// whole message, and reads it back to confirm. Never throws. A partial
/// write is not resumed; the caller's Retry writes the whole message again.
Future<PassportTagWrite> writePassportTo(
  NdefTagHandle? tag,
  CylinderPassportPayload payload,
) async {
  if (tag == null) return const TagNotNdef();
  if (!tag.isWritable) return const TagReadOnly();
  final plan = planPassportMessage(
    payload,
    maxMessageBytes: tag.maxMessageBytes,
  );
  if (plan == null) return TagTooSmall(tag.maxMessageBytes);
  try {
    await tag.write(plan.message);
    final back = await tag.read();
    if (back != plan.message) return const TagReadBackMismatch();
    return TagWritten(
      plan: plan,
      capacity: tag.maxMessageBytes,
      typeLabel: tag.typeLabel,
    );
  } catch (e) {
    return TagWriteFailed(e);
  }
}

/// How a passport read ended.
sealed class PassportTagRead {
  const PassportTagRead();
}

class TagReadText extends PassportTagRead {
  const TagReadText(this.text);

  final String text;
}

/// No passport link on the tag (or no NDEF at all).
class TagHasNoPassport extends PassportTagRead {
  const TagHasNoPassport();
}

class TagReadFailed extends PassportTagRead {
  const TagReadFailed(this.error);

  final Object error;
}

/// The passport link on [tag], if it holds one. Never throws.
Future<PassportTagRead> readPassportFrom(NdefTagHandle? tag) async {
  if (tag == null) return const TagHasNoPassport();
  try {
    final message = await tag.read();
    final uri = message == null ? null : firstPassportUri(message);
    return uri == null ? const TagHasNoPassport() : TagReadText(uri);
  } catch (e) {
    return TagReadFailed(e);
  }
}

/// A readable name for a platform tag type (Android reports
/// `org.nfcforum.ndef.type2` and the like); other values pass through.
String? friendlyTagType(String? platformType) {
  if (platformType == null) return null;
  const forum = 'org.nfcforum.ndef.type';
  if (platformType.startsWith(forum)) {
    return 'NFC Forum Type ${platformType.substring(forum.length)}';
  }
  if (platformType == 'com.nxp.ndef.mifareclassic') return 'MIFARE Classic';
  return platformType;
}
```

Create `lib/features/cylinder_passports/data/services/nfc_manager_tag_service.dart`:

```dart
import 'dart:async';

import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';

final _log = LoggerService.forClass(NfcManagerTagService);

/// [NfcTagService] over `nfc_manager` on iOS and Android. Runs on a device
/// only; the device checklist covers it.
class NfcManagerTagService implements NfcTagService {
  void Function()? _cancelPending;

  @override
  Future<NfcSupport> support() async {
    try {
      return switch (await NfcManager.instance.checkAvailability()) {
        NfcAvailability.enabled => NfcSupport.enabled,
        NfcAvailability.disabled => NfcSupport.disabled,
        NfcAvailability.unsupported => NfcSupport.unsupported,
      };
    } catch (e, stackTrace) {
      _log.warning(
        'NFC availability check failed',
        error: e,
        stackTrace: stackTrace,
      );
      return NfcSupport.unsupported;
    }
  }

  @override
  Future<T> withTag<T>({
    required String promptIos,
    required Future<T> Function(NdefTagHandle? tag) onTag,
  }) async {
    final result = Completer<T>();
    void cancelled() {
      if (!result.isCompleted) result.completeError(const NfcSessionCancelled());
    }

    _cancelPending = cancelled;
    try {
      await NfcManager.instance.startSession(
        // NTAG21x and most cylinder tags are ISO 14443 type A.
        pollingOptions: const {NfcPollingOption.iso14443},
        alertMessageIos: promptIos,
        // The write reads back in the same session, so keep it open.
        invalidateAfterFirstReadIos: false,
        onDiscovered: (tag) async {
          if (result.isCompleted) return;
          try {
            final ndef = Ndef.from(tag);
            final value = await onTag(ndef == null ? null : _NdefHandle(ndef));
            if (!result.isCompleted) result.complete(value);
          } catch (e, stackTrace) {
            if (!result.isCompleted) result.completeError(e, stackTrace);
          }
        },
        onSessionErrorIos: (_) => cancelled(),
      );
      return await result.future;
    } finally {
      _cancelPending = null;
      try {
        await NfcManager.instance.stopSession();
      } catch (e, stackTrace) {
        // Already ended by the system sheet or an error: nothing to stop.
        _log.info(
          'NFC session was already closed',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  @override
  Future<void> cancel() async {
    final cancel = _cancelPending;
    _cancelPending = null;
    cancel?.call();
  }
}

class _NdefHandle implements NdefTagHandle {
  _NdefHandle(this._ndef);

  final Ndef _ndef;

  @override
  bool get isWritable => _ndef.isWritable;

  @override
  int get maxMessageBytes => _ndef.maxSize;

  @override
  String? get typeLabel => _ndef.additionalData['type'] as String?;

  @override
  Future<NdefMessage?> read() => _ndef.read();

  @override
  Future<void> write(NdefMessage message) => _ndef.write(message: message);
}
```

In `cylinder_passport_providers.dart`, add (with imports for `package:flutter/foundation.dart`, `nfc_tag_service.dart` and `nfc_manager_tag_service.dart`):

```dart
/// Whether this platform has NFC tag reading at all: phones only
/// (spec 13.3). An iPad reports itself unsupported through the service.
bool nfcPlatform() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

final nfcTagServiceProvider = Provider<NfcTagService>(
  (ref) => nfcPlatform()
      ? NfcManagerTagService()
      : const UnsupportedNfcTagService(),
);

/// Re-checked each time a screen asks, since the diver can turn NFC on and
/// off in the system settings.
final nfcSupportProvider = FutureProvider.autoDispose<NfcSupport>(
  (ref) => ref.watch(nfcTagServiceProvider).support(),
);
```

In `test/helpers/mock_providers.dart`, add the parameter `NfcTagService? nfcTagService,` to `getBaseOverrides`, the override beside the `incomingLinkSourceProvider` one:

```dart
    // Widget tests never reach the NFC plugin.
    nfcTagServiceProvider.overrideWithValue(
      nfcTagService ?? const UnsupportedNfcTagService(),
    ),
```

and the imports of `nfc_tag_service.dart` and `cylinder_passport_providers.dart` if missing.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/cylinder_passports/data/services/passport_tag_io_test.dart test/features/cylinder_passports/presentation/providers/nfc_providers_test.dart test/architecture/`
Expected: all pass.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/data/services/nfc_tag_service.dart lib/features/cylinder_passports/data/services/passport_tag_io.dart lib/features/cylinder_passports/data/services/nfc_manager_tag_service.dart lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart test/helpers/fake_nfc.dart test/helpers/mock_providers.dart test/features/cylinder_passports/data/services/passport_tag_io_test.dart test/features/cylinder_passports/presentation/providers/nfc_providers_test.dart
git commit -m "feat(passports): NFC tag service with fitted writes and read-back

Refs #2336"
```

---

### Task 5: The write sheet

**Files:**
- Create: `lib/features/cylinder_passports/presentation/utils/nfc_availability_text.dart`
- Create: `lib/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart`
- Test: `test/features/cylinder_passports/presentation/widgets/nfc_write_sheet_test.dart`

**Interfaces:**
- Consumes: Task 4 `nfcTagServiceProvider`, `writePassportTo`, the outcomes, `friendlyTagType`, `NfcSessionCancelled`; Task 3 `planPassportMessage`; Task 2 strings.
- Produces: `String? nfcUnavailableReason(AppLocalizations l10n, NfcSupport? support)`; `String tagFieldLabel(AppLocalizations l10n, String key)`; `Future<void> showNfcWriteSheet(BuildContext context, {required CylinderPassportPayload payload})`; `class NfcWriteSheet`.

- [ ] **Step 1: Write the failing test**

Create `test/features/cylinder_passports/presentation/widgets/nfc_write_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_nfc.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  final payload = CylinderPassportPayload(
    passportId: id,
    writtenOn: DateTime(2026, 9, 25),
    name: 'Club 10',
    serial: 'AB12345',
    volumeL: 10,
    workingPressureBar: 300,
    material: TankMaterial.steel,
  );

  /// Opens the sheet from a button; returns the strings.
  Future<AppLocalizations> open(
    WidgetTester tester,
    FakeNfcTagService nfc,
  ) async {
    final overrides = await getBaseOverrides(nfcTagService: nfc);
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNfcWriteSheet(context, payload: payload),
            child: const Text('open'),
          ),
        ),
      ),
    );
    final l10n = AppLocalizations.of(tester.element(find.text('open')));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('a written tag reports its type, capacity and what fit', (
    tester,
  ) async {
    final tag = FakeTagHandle();
    final l10n = await open(tester, FakeNfcTagService(tag: tag));
    expect(find.text(l10n.passport_nfc_written), findsOneWidget);
    expect(
      find.text(l10n.passport_nfc_tagInfo('NFC Forum Type 2', 496)),
      findsOneWidget,
    );
    expect(find.text(l10n.passport_nfc_allFields), findsOneWidget);
    expect(firstPassportUri(tag.stored!), PassportPayloadCodec.httpsUrl(payload));
  });

  testWidgets('a small tag names what was left off', (tester) async {
    final tag = FakeTagHandle(maxMessageBytes: 100, typeLabel: null);
    final l10n = await open(tester, FakeNfcTagService(tag: tag));
    final plan = planPassportMessage(payload, maxMessageBytes: 100)!;
    final names = plan.droppedKeys.map((k) => tagFieldLabel(l10n, k)).join(', ');
    expect(find.text(l10n.passport_nfc_fieldsDropped(names)), findsOneWidget);
    expect(find.text(l10n.passport_nfc_capacity(100)), findsOneWidget);
  });

  testWidgets('a locked tag says so', (tester) async {
    final l10n = await open(
      tester,
      FakeNfcTagService(tag: FakeTagHandle(isWritable: false)),
    );
    expect(find.text(l10n.passport_nfc_readOnly), findsOneWidget);
    expect(find.text(l10n.passport_nfc_retry), findsOneWidget);
  });

  testWidgets('a tag that cannot hold a link says so', (tester) async {
    final l10n = await open(tester, FakeNfcTagService());
    expect(find.text(l10n.passport_nfc_notNdef), findsOneWidget);
  });

  testWidgets('a tag too small for the identity says so', (tester) async {
    final l10n = await open(
      tester,
      FakeNfcTagService(tag: FakeTagHandle(maxMessageBytes: 40)),
    );
    expect(find.text(l10n.passport_nfc_tooSmall(40)), findsOneWidget);
  });

  testWidgets('a failed write retries from the start', (tester) async {
    final tag = FakeTagHandle(writeError: PlatformException(code: 'io'));
    final nfc = FakeNfcTagService(tag: tag);
    final l10n = await open(tester, nfc);
    expect(find.text(l10n.passport_nfc_writeFailed), findsOneWidget);
    tag.writeError = null;
    await tester.tap(find.text(l10n.passport_nfc_retry));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_nfc_written), findsOneWidget);
    expect(nfc.sessions, 2);
    expect(tag.writes, 2);
  });

  testWidgets('closing the system sheet closes quietly', (tester) async {
    await open(tester, FakeNfcTagService(cancelled: true));
    expect(find.byType(NfcWriteSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/cylinder_passports/presentation/widgets/nfc_write_sheet_test.dart`
Expected: compile error, the widget does not exist.

- [ ] **Step 3: Implement**

Create `lib/features/cylinder_passports/presentation/utils/nfc_availability_text.dart`:

```dart
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Why NFC actions are off (spec 13.3), or null when they are available or
/// the check has not finished.
String? nfcUnavailableReason(AppLocalizations l10n, NfcSupport? support) =>
    switch (support) {
      NfcSupport.disabled => l10n.passport_nfc_disabled,
      NfcSupport.unsupported => l10n.passport_nfc_unsupported,
      NfcSupport.enabled || null => null,
    };
```

Create `lib/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/data/services/passport_tag_io.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(NfcWriteSheet);

/// A readable name for a tag key left off a small tag.
String tagFieldLabel(AppLocalizations l10n, String key) => switch (key) {
  'n' => l10n.passport_nfc_fieldName,
  'sn' => l10n.passport_nfc_fieldSerial,
  'vi' => attributeLabel(l10n, 'last_visual_inspection'),
  'h' => attributeLabel(l10n, 'last_hydro_test'),
  'oc' => l10n.passport_nfc_fieldO2Clean,
  'vt' => attributeLabel(l10n, 'valve_type'),
  'm' => attributeLabel(l10n, 'tank_material'),
  'wp' => attributeLabel(l10n, 'working_pressure_bar'),
  'v' => attributeLabel(l10n, 'volume_l'),
  _ => key,
};

/// Writes [payload] to an NFC tag (spec 13.3) and reports the tag type, its
/// capacity and which fields fit.
Future<void> showNfcWriteSheet(
  BuildContext context, {
  required CylinderPassportPayload payload,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  builder: (_) => NfcWriteSheet(payload: payload),
);

class NfcWriteSheet extends ConsumerStatefulWidget {
  const NfcWriteSheet({super.key, required this.payload});

  /// The full payload, never the label-bounded one: the tag's own capacity
  /// decides what is left off.
  final CylinderPassportPayload payload;

  @override
  ConsumerState<NfcWriteSheet> createState() => _NfcWriteSheetState();
}

class _NfcWriteSheetState extends ConsumerState<NfcWriteSheet> {
  late final NfcTagService _service = ref.read(nfcTagServiceProvider);
  PassportTagWrite? _result;
  bool _waiting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_write());
    });
  }

  @override
  void dispose() {
    if (_waiting) unawaited(_service.cancel());
    super.dispose();
  }

  Future<void> _write() async {
    final l10n = context.l10n;
    setState(() {
      _waiting = true;
      _result = null;
    });
    PassportTagWrite result;
    try {
      result = await _service.withTag(
        promptIos: l10n.passport_nfc_holdNear,
        onTag: (tag) => writePassportTo(tag, widget.payload),
      );
    } on NfcSessionCancelled {
      _waiting = false;
      if (mounted) Navigator.of(context).pop();
      return;
    } catch (e, stackTrace) {
      _log.error('NFC write session failed', error: e, stackTrace: stackTrace);
      result = TagWriteFailed(e);
    }
    if (!mounted) return;
    setState(() {
      _waiting = false;
      _result = result;
    });
  }

  void _cancel() {
    _waiting = false;
    unawaited(_service.cancel());
    Navigator.of(context).pop();
  }

  String _tagInfo(AppLocalizations l10n, TagWritten written) {
    final type = friendlyTagType(written.typeLabel);
    return type == null
        ? l10n.passport_nfc_capacity(written.capacity)
        : l10n.passport_nfc_tagInfo(type, written.capacity);
  }

  String _failure(AppLocalizations l10n, PassportTagWrite result) =>
      switch (result) {
        TagNotNdef() => l10n.passport_nfc_notNdef,
        TagReadOnly() => l10n.passport_nfc_readOnly,
        TagTooSmall(:final capacity) => l10n.passport_nfc_tooSmall(capacity),
        TagReadBackMismatch() => l10n.passport_nfc_readBackFailed,
        TagWriteFailed() || TagWritten() => l10n.passport_nfc_writeFailed,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final result = _result;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.passport_nfc_write, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          if (result == null) ...[
            const Icon(Icons.nfc, size: 48),
            const SizedBox(height: 12),
            Text(l10n.passport_nfc_holdNear, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _cancel,
                child: Text(l10n.common_action_cancel),
              ),
            ),
          ] else if (result case final TagWritten written) ...[
            Icon(Icons.check_circle, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              l10n.passport_nfc_written,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(_tagInfo(l10n, written), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              written.plan.droppedKeys.isEmpty
                  ? l10n.passport_nfc_allFields
                  : l10n.passport_nfc_fieldsDropped(
                      written.plan.droppedKeys
                          .map((k) => tagFieldLabel(l10n, k))
                          .join(', '),
                    ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.common_action_done),
              ),
            ),
          ] else ...[
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(_failure(l10n, result), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_action_close),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _write,
                  child: Text(l10n.passport_nfc_retry),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/cylinder_passports/presentation/widgets/nfc_write_sheet_test.dart`
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/presentation/utils/nfc_availability_text.dart lib/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart test/features/cylinder_passports/presentation/widgets/nfc_write_sheet_test.dart
git commit -m "feat(passports): write a cylinder's passport to an NFC tag

Refs #2336"
```

---

### Task 6: Read a tag from the scan sheet

**Files:**
- Modify: `lib/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart`
- Test: `test/features/cylinder_passports/presentation/widgets/passport_scan_sheet_test.dart` (append; give `openSheet` an `nfc` parameter)

**Interfaces:**
- Consumes: Task 4 `nfcPlatform`, `nfcTagServiceProvider`, `nfcSupportProvider`, `readPassportFrom`, read outcomes, `NfcSessionCancelled`; Task 5 `nfcUnavailableReason`.
- Produces: the scan sheet button keyed `Key('passportScan_nfc')`, shown on iOS and Android only.

- [ ] **Step 1: Write the failing tests**

In `passport_scan_sheet_test.dart`, give `openSheet` a parameter `FakeNfcTagService? nfc,` and pass it on: `final overrides = await getBaseOverrides(nfcTagService: nfc);`. Import `package:flutter/foundation.dart`, `package:ndef_record/ndef_record.dart`, `passport_ndef.dart`, `nfc_tag_service.dart` and `'../../../../helpers/fake_nfc.dart'`. Append:

```dart
  testWidgets('an NFC tap opens the tag it reads', (tester) async {
    final nfc = FakeNfcTagService(
      tag: FakeTagHandle(stored: NdefMessage(records: [uriRecord(tag)])),
    );
    final results = await openSheet(tester, camera: null, nfc: nfc);
    await tester.tap(find.byKey(const Key('passportScan_nfc')));
    await tester.pumpAndSettle();
    expect(results, [tag]);
  });

  testWidgets('a tag with no passport says so', (tester) async {
    final nfc = FakeNfcTagService(
      tag: FakeTagHandle(
        stored: NdefMessage(records: [uriRecord('https://example.com/')]),
      ),
    );
    final results = await openSheet(tester, camera: null, nfc: nfc);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportScanSheet)),
    );
    await tester.tap(find.byKey(const Key('passportScan_nfc')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_tag_linkInvalid), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('NFC turned off explains itself', (tester) async {
    await openSheet(
      tester,
      camera: null,
      nfc: FakeNfcTagService(supportValue: NfcSupport.disabled),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PassportScanSheet)),
    );
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text(l10n.passport_nfc_tap),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.text(l10n.passport_nfc_disabled), findsOneWidget);
  });

  testWidgets('closing the iOS sheet is quiet', (tester) async {
    final results = await openSheet(
      tester,
      camera: null,
      nfc: FakeNfcTagService(cancelled: true),
    );
    await tester.tap(find.byKey(const Key('passportScan_nfc')));
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(find.byType(PassportScanSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop offers no NFC', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await openSheet(tester, camera: null, nfc: FakeNfcTagService());
    expect(find.byKey(const Key('passportScan_nfc')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
```

(`OutlinedButton.icon` builds a private subclass of `OutlinedButton`, which `find.byType(OutlinedButton)` does not match by exact type; if the ancestor finder finds nothing, use `find.byWidgetPredicate((w) => w is OutlinedButton)` instead.)

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/cylinder_passports/presentation/widgets/passport_scan_sheet_test.dart`
Expected: the new tests fail (no `passportScan_nfc` button); the existing tests pass.

- [ ] **Step 3: Implement**

In `passport_scan_sheet.dart`, add imports for `package:flutter/foundation.dart` (if absent), `nfc_tag_service.dart`, `passport_tag_io.dart`, `cylinder_passport_providers.dart` and `nfc_availability_text.dart`. Add to the state:

```dart
  late final NfcTagService _nfc = ref.read(nfcTagServiceProvider);
  bool _nfcReading = false;
  String? _nfcError;

  Future<void> _readNfc() async {
    final l10n = context.l10n;
    setState(() {
      _nfcReading = true;
      _nfcError = null;
    });
    try {
      final result = await _nfc.withTag(
        promptIos: l10n.passport_nfc_holdNear,
        onTag: readPassportFrom,
      );
      if (!mounted) return;
      switch (result) {
        case TagReadText(:final text):
          _finish(text);
        case TagHasNoPassport():
          setState(() => _nfcError = l10n.passport_tag_linkInvalid);
        case TagReadFailed():
          setState(() => _nfcError = l10n.passport_nfc_readFailed);
      }
    } on NfcSessionCancelled {
      // The diver closed the system sheet: nothing to report.
    } catch (e, stackTrace) {
      _log.error('NFC read session failed', error: e, stackTrace: stackTrace);
      if (mounted) setState(() => _nfcError = l10n.passport_nfc_readFailed);
    } finally {
      if (mounted) setState(() => _nfcReading = false);
    }
  }
```

In `dispose`, before `_link.dispose()`:

```dart
    if (_nfcReading) unawaited(_nfc.cancel());
```

(import `dart:async` for `unawaited` if absent). In `build`, read `final nfc = ref.watch(nfcSupportProvider).value;` beside `camera`, and after the camera block (before the `SizedBox(height: 12)` above the link field) add:

```dart
          if (nfcPlatform()) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('passportScan_nfc'),
              icon: const Icon(Icons.nfc),
              label: Text(
                _nfcReading ? l10n.passport_nfc_holdNear : l10n.passport_nfc_tap,
              ),
              onPressed: nfc == NfcSupport.enabled && !_nfcReading
                  ? _readNfc
                  : null,
            ),
            if (nfcUnavailableReason(l10n, nfc) case final reason?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  reason,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_nfcError case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/cylinder_passports/presentation/widgets/passport_scan_sheet_test.dart test/features/cylinder_passports/presentation/utils/scan_cylinder_tag_test.dart test/features/equipment/presentation/`
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart test/features/cylinder_passports/presentation/widgets/passport_scan_sheet_test.dart
git commit -m "feat(passports): read a cylinder tag by NFC from the scan sheet

Refs #2336"
```

---

### Task 7: Write, rewrite and reprint on the Tag card

**Files:**
- Modify: `lib/features/cylinder_passports/presentation/widgets/passport_tag_card.dart`
- Test: `test/features/cylinder_passports/presentation/widgets/passport_tag_card_test.dart` (append; give `pump` `nfc` and `onPrintLabel` parameters)

**Interfaces:**
- Consumes: Task 4 `nfcSupportProvider`, `NfcSupport`; Task 5 `showNfcWriteSheet`, `NfcWriteSheet`, `nfcUnavailableReason`; 1a `payloadForItem`, `NdefFit.fitForLabel`, `tagIsStale`.
- Produces: `CylinderPassportPayload? fullPayloadFor(EquipmentItem item, {required String? passportId, required List<ServiceClockStatus> clocks, required Iterable<ServiceRecord> records, required DateTime now})`; `currentPayloadFor` becomes `fullPayloadFor` bounded by `NdefFit.fitForLabel`; buttons keyed `Key('passportTag_writeNfc')`, `Key('passportTag_rewrite')`, `Key('passportTag_reprint')`.

The QR and printed label stay bounded at 160 characters; an NFC write starts from the full payload and lets the tag's capacity decide what is left off (spec 6.4).

- [ ] **Step 1: Write the failing tests**

In `passport_tag_card_test.dart`, give `pump` the parameters `FakeNfcTagService? nfc,` and `Future<void> Function(BuildContext)? onPrintLabel,`; pass `getBaseOverrides(nfcTagService: nfc)` and `PassportTagCard(equipment: tank, scannedTag: scanned, onPrintLabel: onPrintLabel)`. Import `nfc_tag_service.dart`, `nfc_write_sheet.dart`, `ndef_fit.dart` and `'../../../../helpers/fake_nfc.dart'`. Append:

```dart
  test('an NFC write starts from the full payload, the label from 160', () {
    // A long name in a script that percent-encodes to several characters
    // per glyph runs the label past its 160; the tag decides for itself.
    final longName = List.filled(30, 'Ω').join();
    final named = EquipmentItem(
      id: id,
      name: 'Faber 12',
      type: EquipmentType.tank,
      attributes: [
        ...tank.attributes,
        EquipmentAttribute(
          id: 'a4',
          equipmentId: id,
          key: EquipmentAttrKeys.identifier,
          valueText: longName,
        ),
      ],
    );
    final full = fullPayloadFor(
      named,
      passportId: pid,
      clocks: const [],
      records: const [],
      now: now,
    )!;
    final label = currentPayloadFor(
      named,
      passportId: pid,
      clocks: const [],
      records: const [],
      now: now,
    )!;
    expect(full.name, longName);
    expect(label, NdefFit.fitForLabel(full));
    expect(label.name, isNull);
  });

  testWidgets('Write NFC tag explains why it is off', (tester) async {
    final l10n = await pump(tester);
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(l10n.passport_nfc_write),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.text(l10n.passport_nfc_unsupported), findsOneWidget);
  });

  testWidgets('Write NFC tag writes the passport', (tester) async {
    final tag = FakeTagHandle();
    final l10n = await pump(tester, nfc: FakeNfcTagService(tag: tag));
    await tester.ensureVisible(find.byKey(const Key('passportTag_writeNfc')));
    await tester.tap(find.byKey(const Key('passportTag_writeNfc')));
    await tester.pumpAndSettle();
    expect(find.byType(NfcWriteSheet), findsOneWidget);
    expect(find.text(l10n.passport_nfc_written), findsOneWidget);
    expect(tag.writes, 1);
  });

  testWidgets('a stale tag offers Rewrite and Reprint', (tester) async {
    var printed = 0;
    final tag = FakeTagHandle();
    // Written for a 10 L cylinder; the row says 12 L, so the tag is stale.
    final l10n = await pump(
      tester,
      scanned: CylinderPassportPayload(
        passportId: pid,
        writtenOn: DateTime(2026, 1, 1),
        volumeL: 10,
      ),
      nfc: FakeNfcTagService(tag: tag),
      onPrintLabel: (_) async => printed++,
    );
    expect(find.text(l10n.passport_tag_stale), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('passportTag_reprint')));
    await tester.tap(find.byKey(const Key('passportTag_reprint')));
    await tester.pumpAndSettle();
    expect(printed, 1);
    await tester.tap(find.byKey(const Key('passportTag_rewrite')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_nfc_written), findsOneWidget);
    expect(tag.writes, 1);
  });
```

`payloadForItem` takes the name from `item.identifier`, the `EquipmentAttrKeys.identifier` attribute (`tank_identifier`).

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/cylinder_passports/presentation/widgets/passport_tag_card_test.dart`
Expected: compile error on `fullPayloadFor`; after it exists, the button tests fail.

- [ ] **Step 3: Implement**

In `passport_tag_card.dart`:

1. Rename the body of `currentPayloadFor` into a new `fullPayloadFor` with the same parameters, returning `payloadForItem(...)` without `NdefFit.fitForLabel`, and make `currentPayloadFor` call it:

```dart
/// The payload a tag written right now carries in full: the row's spec, the
/// recorded hydro and VIP dates (never a clock's fallback anchor), and O2
/// clean only when a cleaning is on record and its clock is not overdue.
/// Null until the passport id exists. An NFC write starts here and lets the
/// tag's capacity decide what is left off.
CylinderPassportPayload? fullPayloadFor(
  EquipmentItem item, {
  required String? passportId,
  required List<ServiceClockStatus> clocks,
  required Iterable<ServiceRecord> records,
  required DateTime now,
}) {
  if (passportId == null) return null;
  ServiceClockStatus? clock(String kindId) =>
      clocks.where((c) => c.kind.id == kindId).firstOrNull;
  final o2 = clock('o2-clean');
  return payloadForItem(
    item: item,
    passportId: passportId,
    writtenOn: DateTime(now.year, now.month, now.day),
    hydroAnchor: recordedServiceDate(clock: clock('hydro'), records: records),
    vipAnchor: recordedServiceDate(clock: clock('vip'), records: records),
    o2Clean:
        o2 != null &&
        o2.severity != ServiceClockSeverity.overdue &&
        recordedServiceDate(clock: o2, records: records) != null,
  );
}

/// [fullPayloadFor], bounded so every QR drawn from it (on screen and on
/// the printed label) stays inside the label's designed density.
CylinderPassportPayload? currentPayloadFor(
  EquipmentItem item, {
  required String? passportId,
  required List<ServiceClockStatus> clocks,
  required Iterable<ServiceRecord> records,
  required DateTime now,
}) {
  final full = fullPayloadFor(
    item,
    passportId: passportId,
    clocks: clocks,
    records: records,
    now: now,
  );
  return full == null ? null : NdefFit.fitForLabel(full);
}
```

2. In `build`, replace the `final payload = currentPayloadFor(...)` call with:

```dart
    final full = fullPayloadFor(
      equipment,
      passportId: passportId,
      clocks: clocks,
      records: records,
      now: DateTime.now(),
    );
    final payload = full == null ? null : NdefFit.fitForLabel(full);
    final nfc = ref.watch(nfcSupportProvider).value;
    final canWriteNfc = full != null && nfc == NfcSupport.enabled;
```

3. Replace the stale box's child `Row(...)` with:

```dart
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, color: warn.onContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.passport_tag_stale,
                            style: TextStyle(color: warn.onContainer),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          key: const Key('passportTag_rewrite'),
                          onPressed: canWriteNfc
                              ? () => showNfcWriteSheet(context, payload: full)
                              : null,
                          child: Text(l10n.passport_nfc_rewrite),
                        ),
                        Builder(
                          builder: (buttonContext) => TextButton(
                            key: const Key('passportTag_reprint'),
                            onPressed: payload == null || onPrintLabel == null
                                ? null
                                : () => onPrintLabel!(buttonContext),
                            child: Text(l10n.passport_nfc_reprint),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
```

4. In the action `Wrap`, after the Link an existing tag button, add:

```dart
                OutlinedButton.icon(
                  key: const Key('passportTag_writeNfc'),
                  onPressed: canWriteNfc
                      ? () => showNfcWriteSheet(context, payload: full)
                      : null,
                  icon: const Icon(Icons.nfc),
                  label: Text(l10n.passport_nfc_write),
                ),
```

and after the `Wrap`:

```dart
            if (nfcUnavailableReason(l10n, nfc) case final reason?) ...[
              const SizedBox(height: 4),
              Text(reason, style: Theme.of(context).textTheme.bodySmall),
            ],
```

Add imports for `nfc_tag_service.dart`, `nfc_availability_text.dart` and `nfc_write_sheet.dart`. `full` is promoted to non-null inside the `canWriteNfc` closures only if the analyzer can see it; if it cannot, write `payload: full!` there (safe: `canWriteNfc` implies `full != null`).

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/cylinder_passports/presentation/ test/features/cylinder_passports/domain/`
Expected: all pass, the existing Tag card and passport page tests unchanged.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/cylinder_passports/presentation/widgets/passport_tag_card.dart test/features/cylinder_passports/presentation/widgets/passport_tag_card_test.dart
git commit -m "feat(passports): write NFC tags from the Tag card, rewrite or reprint a stale tag

Refs #2336"
```

---

### Task 8: Docs, rulings and the device checklist

**Files:**
- Modify: `docs/import-formats/cylinder-passport-tag.md` ("NFC layout")
- Modify: `docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md` (sections 6.4 and 13.3)
- Create: `docs/superpowers/specs/2026-09-27-cylinder-passports-2-nfc-device-checklist.md`

**Interfaces:** none.

- [ ] **Step 1: Update the tag format page**

In `docs/import-formats/cylinder-passport-tag.md`, replace the second paragraph of "NFC layout" (the one beginning "When a tag is too small") with:

```markdown
When a tag is too small, optional keys are dropped in this fixed order until
the identity record fits: `n`, `sn`, `vi`, `h`, `oc`, `vt`, `m`, `wp`, `v`.
`f`, `p` and `w` are never dropped. Submersion fits the message to the NDEF
capacity the phone reports for the tag (about 137 bytes on an NTAG213, 496
on an NTAG215 and 868 on an NTAG216), and adds the Android Application
Record only when it still fits. An NTAG213 therefore loses the name and
some dates on a full cylinder; NTAG215 and NTAG216 hold everything, and are
the tags to buy. Every write is read back before Submersion reports it as
written. Names and serials are cut by whole characters, never mid-glyph.
```

- [ ] **Step 2: Record the two rulings in the spec**

In section 6.4, after the paragraph beginning "The writer (`NdefFit`)", add:

```markdown
On a phone the capacity is the NDEF message size the platform reports for
the tag (`Ndef.maxSize`), which already excludes the Type 2 TLV wrapper
that `NdefFit.fit` counts for a bare tag (decided 2026-09-27).
```

In section 13.3, replace the iOS bullet with:

```markdown
- iOS: `NFCReaderUsageDescription`; entitlement
  `com.apple.developer.nfc.readersession.formats` with `NDEF` and `TAG`
  (`nfc_manager` 4 reads and writes through `NFCTagReaderSession`, which
  needs `TAG`; decided 2026-09-27). With the associated domain verified,
  background tag reading opens the app on a tap with nothing running.
  NFC Tag Reading must be enabled for the app id in the Apple developer
  portal before a signed build.
```

- [ ] **Step 3: Write the device checklist**

Create `docs/superpowers/specs/2026-09-27-cylinder-passports-2-nfc-device-checklist.md`:

```markdown
# Cylinder passports 2: NFC device checklist

**Issue:** #2336
**Spec:** `docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md`

Everything here needs real hardware; CI runs none of it. Record the device,
OS version, build and tag model for each line.

## Prerequisites

- Apple developer portal: NFC Tag Reading enabled for `app.submersion`,
  provisioning profiles regenerated.
- One each of NTAG213, NTAG215 and NTAG216, blank; one locked tag; one tag
  holding another app's link.

## Write

- [ ] iPhone: Passport, Tag card, Write NFC tag, hold an NTAG216: "Tag
      written and checked", the type and capacity, "Everything fits".
- [ ] Android: the same.
- [ ] NTAG213: written, with "Left off to fit" naming the dropped fields.
- [ ] Locked tag: "This tag is locked", nothing written.
- [ ] Lift the tag mid-write: "The tag was not written", Try again writes
      it cleanly.
- [ ] iPhone: dismiss the system sheet: the write sheet closes, no error.

## Read

- [ ] iPhone and Android: Equipment, Scan a cylinder tag, Tap an NFC tag:
      the passport opens.
- [ ] The other app's tag: "That is not a cylinder tag", the sheet stays.
- [ ] Android with NFC off: the button is disabled with "NFC is turned off".
- [ ] iPad without NFC: disabled with "This device cannot read or write".

## Background launch

- [ ] Android, app closed: tap a written tag: Submersion opens on that
      cylinder's passport.
- [ ] Android, app open on another screen: tap: the passport opens once.
- [ ] iPhone, app closed, website app-link files live: tap: the passport
      opens.
- [ ] Fresh install with no diver: tap: the passport opens after setup.

## Stale tag

- [ ] Log a hydro after writing a tag, then scan it: the stale hint shows
      Rewrite and Reprint; Rewrite writes the new dates, Reprint opens the
      label.
```

- [ ] **Step 4: Scan and commit**

Run: `grep -nP "\x{2014}|\x{2013}" docs/import-formats/cylinder-passport-tag.md docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md docs/superpowers/specs/2026-09-27-cylinder-passports-2-nfc-device-checklist.md`
Expected: no output.

```bash
git add docs/import-formats/cylinder-passport-tag.md docs/superpowers/specs/2026-09-25-smart-cylinder-passports-design.md docs/superpowers/specs/2026-09-27-cylinder-passports-2-nfc-device-checklist.md
git commit -m "docs: NFC tag capacity and entitlement rulings, NFC device checklist

Refs #2336"
```

---

### Task 9: Whole-project verification and the PR

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format . && flutter analyze`
Expected: `No issues found!`; `git status --short` clean after the format.

- [ ] **Step 2: Generated l10n is current**

Run: `flutter gen-l10n && git status --porcelain -- 'lib/l10n/arb/app_localizations*.dart'`
Expected: no output.

- [ ] **Step 3: Guards**

Run: `flutter test test/architecture/ test/l10n/ test/platform/ test/macos_entitlements_test.dart`
Expected: all pass.

- [ ] **Step 4: Full suite, once**

Check `df -h /Volumes/fltmp` first (a full RAM-disk TMPDIR makes `flutter test` hang silently). Run: `flutter test`
Expected: all pass. Read the exit status directly, never through a pipe. A failure in a file this branch never touched: rerun that file alone and check `origin/main` before blaming the branch.

- [ ] **Step 5: Push and open the PR**

The executing skill holds this step for the maintainer's choice (merge, PR or keep). When a PR is chosen, merge `origin/main` first if it moved, then:

```bash
git push -u origin HEAD:refs/heads/ericgriffin/cylinder-passports-2-2336
```

Title: `Cylinder passports 2: NFC read and write`. Body, with no attribution lines:

```
## Related Issue

Closes #2336
Refs #2333

## Summary

A diver can write a cylinder's passport to an NFC tag from the Tag card,
read a tag from the scan sheet on a phone, and open the app by tapping a tag
with nothing running. The write fits the passport to the tag, reads it back
to confirm, and reports the tag type, its capacity and what was left off to
fit. A stale tag's hint now offers Rewrite and Reprint.

## Changes

- `nfc_manager`, `nfc_manager_ndef` and `ndef_record`; NFC on iOS and
  Android only, with the actions disabled and explained elsewhere.
- NDEF building and reading in pure Dart: URI records with the NFC Forum
  prefix table, the Android Application Record, and a message plan that
  drops optional keys in the spec's order until the tag fits.
- An NFC service seam, so every write and read outcome (locked, too small,
  not NDEF, lost mid-write, read back different) is tested with fake tags.
- Write sheet; Tap an NFC tag in the scan sheet; Write NFC tag on the Tag
  card; Rewrite and Reprint on the stale hint.
- Platform: NFC permission, optional feature and an `NDEF_DISCOVERED`
  filter on Android; the NFC usage string and reader-session entitlement on
  iOS.

## Before a signed iOS release

Enable NFC Tag Reading for `app.submersion` in the Apple developer portal
and regenerate the provisioning profiles.

## Test Plan

- [x] `flutter test` passes
- [x] `flutter analyze` passes
- [x] iOS simulator build links with the NFC plugin
- [ ] Device checklist: `docs/superpowers/specs/2026-09-27-cylinder-passports-2-nfc-device-checklist.md`

## Screenshots

Images to be added by the maintainer (captured separately):

1. Tag card, before and after: Write NFC tag, and the disabled reason where NFC is unavailable.
2. Write sheet (new): waiting, written with the tag report, and a failure with Try again.
3. Scan sheet, before and after: Tap an NFC tag.
4. Stale hint, before and after: Rewrite and Reprint.
```

Then bind the PR in the desktop app (`get_status`, then `bind_pr` if not reported). Do not poll CI.
