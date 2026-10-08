# Offline Emergency Card (Safety Phase 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans.

**Goal:** A single offline screen readable by a stranger under stress: Call-DAN primary action, local EMS number, the diver's emergency/medical/insurance data, and a dated hyperbaric chamber directory with user additions/hiding.

**Architecture:** Bundled JSON assets (`assets/data/emergency_numbers.json`, `assets/data/chambers.json`) loaded by a cached `EmergencyDataService` (mirrors `SpeciesSeedService`). User-added chambers persist in a new HLC parent table `emergency_chambers` (schema v126 (renumbered from v118 at the main merge)); hidden built-in ids + a manual region override live on `DiverSettings`. Region resolves from the most recent dive's site country, else the override. Branch `safety-phase3-emergency-card` stacked on phase 2.

## Global Constraints

Same as phases 1–2. Schema **v126** (renumbered from v118 at the main merge). Spec deviations (documented): built-in chambers stay asset-resident (versioned with app releases, each entry dated) instead of a re-seeded reference table — identical offline behavior, no export/reseed machinery; "edit built-in" is modeled as hide + add-your-own; app-icon shortcut (stretch) deferred. The starter chamber directory is deliberately small (well-established facilities only) with `lastVerified` shown and "Call DAN first" always primary; expanding it is a data-curation follow-up.

## Tasks

1. **Bundled data + loader.** `assets/data/emergency_numbers.json`: `regions` (DAN/DES hotlines: name, phone, countries[]) + `ems` (ISO-country → number). `assets/data/chambers.json`: id, name, country, city, phone, lat/lon, lastVerified. `EmergencyDataService.loadNumbers()/loadChambers()` with static cache + tests (asset loading via `TestWidgetsFlutterBinding` + `rootBundle`).
2. **Schema v126 + user chambers.** Table `EmergencyChambers` (id PK, diverId nullable FK, name, country, city?, phone, latitude?, longitude?, notes?, createdAt, updatedAt, hlc) — HLC parent: `_hlcTargets`, mergeOrder (`hasUpdatedAt: true`), serializer sites, `entityHasUpdatedAt`, parity-test seed. DiverSettings columns: `hiddenChamberIds` TEXT (JSON list), `emergencyRegion` TEXT nullable. Migration + backstop + tripwire (125→126) + `migrationVersions`. Repository `EmergencyChamberRepository` (create/update/delete with markRecordPending/logDeletion) + tests.
3. **Settings wiring.** `AppSettings.hiddenChamberIds` (Set<String>), `emergencyRegion` (String?); notifier setters (`setChamberHidden(id, hidden)`, `setEmergencyRegion`); row mapping; mock stubs; notifier tests.
4. **Region + card providers.** `emergencyRegionProvider` (settings override → most recent dive siteCountry → null); `emergencyCardDataProvider` assembling: DAN hotline for region, EMS number for country, visible chambers (built-ins for region country + all user chambers, hidden filtered, distance-sorted when last dive site GPS known), current diver. Unit tests with fakes.
5. **UI.** `EmergencyCardPage` (`/safety/emergency-card`): large-type sections — Call DAN (tel: via url_launcher, biggest button), EMS, diver identity/medical, contacts (tap-to-call), insurance, chambers (phone, city, lastVerified date, hide action; add-chamber form page `/safety/emergency-card/add-chamber`). Hub tile + dashboard quick action. Widget tests.
6. **l10n sweep + verification.** en + 10 locales; format/analyze; affected tests.
