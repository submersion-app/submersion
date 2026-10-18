# CCR Transmitter Role Gas-Timeline Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flag a CCR transmitter tank whose name-derived role conflicts with when it lost pressure, and let one repair make it the bailout on this dive, on every past dive with that transmitter, and on every future import.

**Architecture:** A pure open-circuit timeline function feeds two consumers: a new Data Quality detector (`transmitter_role`) on stored dives, and a "bailout gas claim" step on the import and reparse paths. The claim is what keeps a merged-away duplicate bailout cylinder from coming back on reparse. The repair writes through a new small repository, and an extended registry apply-to-existing fixes the mix on past dives. Reparse stops overwriting a stored mix with one the importer invented.

**Tech Stack:** Flutter, Dart, Drift, Riverpod, flutter_test, ARB l10n (23 locales).

**Spec:** `docs/design/specs/2026-10-17-ccr-transmitter-role-gas-timeline-design.md`

## Global Constraints

- CCR dives only (`dive.diveMode == DiveMode.ccr`); SCR, OC and gauge are never flagged or claimed.
- Only tanks with `roleSource == TankRoleSource.transmitterName` are flagged. A tank with `roleSource == null` is never flagged or re-roled by detection.
- Flag rule: open-circuit drop > 20 bar, open-circuit time >= 120 s, `ocRate >= 4 * loopRate` (bar per minute). New constants in `QualityThresholds` under `// transmitter_role`: `bailoutRoleMinOcDropBar = 20.0`, `bailoutRoleMinOcSeconds = 120`, `bailoutRoleMinRateRatio = 4.0`.
- Timeline: the dive starts on the loop. If the first switch targets a loop tank (`diluent` or `oxygenSupply`), skip. Clip to `lastTimeBelowSurfaceThreshold(...)`.
- "As imported" gas cylinder: `isComputerRecordedTank(t)`, no pressure series, `transmitterSerial == null`, `equipmentId == null`, `volume == null`, `name == null`.
- Gas comparison tolerance 0.5 percentage points (same as #3416).
- Reparse never writes a mix the importer invented; a mix the computer recorded still refreshes.
- Every tank and gas-switch write marks the row pending (`'diveTanks'`, `'gasSwitches'`); every delete is tombstoned with `logDeletion`. Then `SyncEventBus.notifyLocalChange()`.
- Strings: new keys in all 23 ARB files, keys `dataQuality_detector_transmitter_role`, `dataQuality_msg_transmitterRoleBailout`, `dataQuality_repairLabel_useAsBailout`, `dataQuality_useAsBailout_*`. Pressures go through `fmt.pressure` (diver unit settings).
- No new file over 800 lines. `dive_repository_impl.dart` (8922 lines) and `reparse_service.dart` (1198) only get small call-site edits; new logic goes in new files.
- No em-dashes anywhere. No tool attribution in commits or PR text. `dart format .` before each commit. Run `test/architecture/` and `test/shared/` before the PR.

## Review Focus

1. **Two flagged tanks pointing at the same open-circuit cylinder** (two transmitters, both "O"-named). The second repair must not merge a cylinder the first already deleted: it re-roles and takes the mix, no merge. Test in Task 5.
2. **Multi-computer dives.** A claim or merge must only use tanks and switches of the same `computerId`. Test in Task 3.
3. **Undo after a merge** restores the deleted cylinder *and* its switches (the FK cascades switches on delete). Test in Task 5.
4. **Imperial diver.** The finding message shows psi. Test in Task 4.
5. **Reparse of a repaired dive with no registry entry.** The stored diver-set bailout role must drive the claim, so the duplicate does not return. Test in Task 3.

---

### Task 1: Expose whether a parsed tank's mix was recorded

**Files:**
- Modify: `lib/features/dive_computer/domain/entities/downloaded_dive.dart` (`DownloadedTank`, ~:347)
- Modify: `lib/features/dive_computer/data/services/parsed_tank_resolver.dart:197-284`
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`TankData`, ~:2932)
- Modify: `lib/features/dive_computer/data/services/dive_parser.dart:74` (`tankDataFrom`)
- Test: `test/features/dive_computer/data/services/parsed_tank_resolver_test.dart`

**Interfaces:**
- Produces: `DownloadedTank.mixRecorded` (`bool`, default `true`); `TankData.mixRecorded` (`bool`, default `true`), copied by `tankDataFrom` and kept by `TankData.copyWith`.

- [ ] **Step 1: Write the failing tests**

`test('an O-named Shearwater CCR transmitter has no recorded mix')`: parse a Shearwater CCR fixture with one "OC" transmitter (usage 1). Expect that tank to have `o2Percent == 100`, `mixRecorded == false`. `test('a D-named transmitter that claims the breathed diluent has a recorded mix')`: expect `mixRecorded == true`. `test('sensorless cylinders carry a recorded mix')`: every tank built from an unclaimed gas has `mixRecorded == true`. `test('a dive with no gas list defaults to air, unrecorded')`: expect `o2Percent == 21`, `mixRecorded == false`.

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/features/dive_computer/data/services/parsed_tank_resolver_test.dart`
Expected: FAIL, `mixRecorded` not defined.

- [ ] **Step 3: Implement**

In the transmitter loop, set `mixRecorded: gas != null`. Sensorless cylinders get `true`. Add the field to both classes with default `true`, so every other constructor call stays valid.

- [ ] **Step 4: Run the tests and see them pass**

Run: the same command. Expected: PASS. Also run `flutter test test/features/dive_computer` and expect PASS.

- [ ] **Step 5: Commit**

`git commit -m "feat(dive-computer): record whether a parsed tank's mix came from the computer"`

### Task 2: Reparse never writes an invented mix

**Files:**
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart` (`_carryOverTanks`, existing-row update ~:934-935)
- Test: `test/features/dive_computer/data/services/reparse_service_test.dart`

**Interfaces:**
- Consumes: `TankData.mixRecorded` (Task 1).

- [ ] **Step 1: Write the failing tests**

`test('reparse keeps a stored mix when the computer recorded none')`: store a CCR dive whose O-named tank row has role `bailout`, `roleSource` null, mix 21/0. Reparse. Expect the row to still be 21/0 with role `bailout`. `test('reparse still refreshes a recorded mix')`: store a diluent row with 21/0 when the raw data's diluent is 10/50. Reparse. Expect 10/50.

- [ ] **Step 2: Run and see the first fail**

Run: `flutter test test/features/dive_computer/data/services/reparse_service_test.dart`
Expected: the first test FAILS (mix becomes 100/0).

- [ ] **Step 3: Implement**

Write `o2Percent`/`hePercent` as `Value(...)` only when `tank.mixRecorded`. Otherwise use `const Value.absent()`. New-row inserts are unchanged.

- [ ] **Step 4: Run and see them pass**

Run: the same command. Expected: PASS.

- [ ] **Step 5: Commit**

`git commit -m "fix(reparse): never overwrite a stored mix with an invented default"`

### Task 3: Open-circuit timeline and the bailout gas claim

**Files:**
- Create: `lib/features/dive_log/domain/services/ccr_bailout_timeline.dart`
- Create: `lib/features/dive_computer/data/services/bailout_gas_claim.dart`
- Modify: `lib/features/dive_computer/data/services/dive_import_service.dart:715-740` (after `applyTransmitterRegistry`)
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart` (`_carryOverTanks` ~:879 and `_insertGasSwitches` ~:829)
- Test: `test/features/dive_log/domain/services/ccr_bailout_timeline_test.dart`
- Test: `test/features/dive_computer/data/services/bailout_gas_claim_test.dart`
- Test: `test/features/dive_computer/data/services/reparse_service_test.dart`

**Interfaces:**
- Produces (timeline, pure, keyed by a generic tank key `K`):

```dart
typedef TimelineSwitch<K> = ({int t, K tankKey});
typedef TimelinePressure = ({int t, double bar});

class BailoutEvidence<K> {
  final K tankKey;
  final double ocDropBar, loopRate, ocRate; // rates in bar/min
  final K ocTankKey; // OC target active for the largest share of ocDrop
}

/// Null when the dive is skipped (no switches, first switch to the loop,
/// no OC time). Otherwise one entry per [candidates] key that passes the
/// flag rule.
List<BailoutEvidence<K>>? bailoutEvidence<K>({
  required List<TimelineSwitch<K>> switches,
  required bool Function(K tankKey) isLoopTank,
  required Map<K, List<TimelinePressure>> pressures,
  required Iterable<K> candidates,
  required int? inWaterEndSeconds,
});
```

- Produces (claim, pure):

```dart
typedef BailoutClaim = ({
  List<TankData> tanks,          // claimed cylinders removed, claimers updated
  Map<int, int> remappedIndices, // claimed index -> claimer index
});

BailoutClaim claimBailoutGases({
  required List<TankData> tanks,
  required List<GasSwitchEvent> switches,
  required Map<int, List<TimelinePressure>> pressuresByIndex,
  required int? inWaterEndSeconds,
});
```

A claimer is a tank with `role == 'bailout'`, `roleSource == null`, `transmitterSerial != null` and `mixRecorded == false`. The cylinder it claims is: the `ocTankKey` from `bailoutEvidence` with `isLoopTank` true for diluent and oxygenSupply roles. Otherwise, when there is exactly one bailout-role tank with no serial and a recorded mix, that one. The claimer takes the claimed mix (`mixRecorded: true`). The claimed tank is dropped, and switches to it are remapped. Each cylinder can be claimed once. Tanks are only claimed within one computer, because each call site passes one computer's tanks.

- [ ] **Step 1: Write the failing timeline tests**

In `ccr_bailout_timeline_test.dart`, with keys as strings and 10 s pressure steps:
- `'a bailout breathed after a switch to OC is flagged'`: 40 min on the loop flat at 200 bar, then a switch to `oc` at 2400 s, then 10 min dropping to 140 bar. Expect one entry, with `ocDropBar` 60, `ocTankKey == 'oc'` and `loopRate` about 0.
- `'a true O2 supply is not flagged'`: it drops 0.5 bar/min on the loop and is flat on OC. Expect empty.
- `'an mCCR O2 supply on a long OC deco is not flagged'`: 0.5 bar/min throughout, a switch to OC at 20 min of 60. Expect empty.
- `'topside bleed-down after a dive ends on OC does not count'`: OC from 2400 s, `inWaterEndSeconds` 3000, then a 50 bar drop after 3000. Expect empty.
- `'first switch to a loop tank skips the dive'`: expect `null`.
- `'no switches skips the dive'`: expect `null`.
- `'OC time under 120 s is not flagged'`: expect empty.

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/dive_log/domain/services/ccr_bailout_timeline_test.dart`
Expected: FAIL, file not found.

- [ ] **Step 3: Implement `bailoutEvidence`**

Ignore samples after `inWaterEndSeconds`. Loop and OC durations come from the switch times, clipped to `[0, inWaterEndSeconds ?? last sample t]`. For drops, count positive steps only, and give each step to the period its later sample falls in.

- [ ] **Step 4: Write the failing claim tests**

In `bailout_gas_claim_test.dart`:
- `'a registry bailout claims the OC cylinder it was breathed from'`: index 1 is the bailout claimer at 100/0 unrecorded, index 3 is a sensorless 18/45 bailout, and the switch goes to 3. Expect index 3 removed, index 1 at 18/45 with `mixRecorded` true, and `remappedIndices == {3: 1}`.
- `'without timeline evidence a single sensorless bailout is claimed'`: no switches. Expect the same result.
- `'two sensorless bailouts and no evidence claim nothing'`.
- `'a tank with a recorded mix never claims'`.
- `'a name-derived tank never claims'`: `roleSource` is transmitterName.

- [ ] **Step 5: Implement `claimBailoutGases`, then run both test files and see them pass**

Run: `flutter test test/features/dive_log/domain/services/ccr_bailout_timeline_test.dart test/features/dive_computer/data/services/bailout_gas_claim_test.dart`
Expected: PASS.

- [ ] **Step 6: Write the failing reparse tests**

- `'reparse of a repaired dive does not bring the merged cylinder back'`: store a dive as Task 5's repair leaves it (the O-named row is `bailout` with `roleSource` null, there is no sensorless row, and the switches point at the transmitter row). Reparse. Expect the same tank count, the transmitter row at the OC mix, and every OC switch pointing at the transmitter row.
- `'a claim uses one computer's tanks only'`: a two-computer dive. Only the computer that owns the switches and the claimer is changed.

- [ ] **Step 7: Wire the claim into reparse and import**

- In `_carryOverTanks`, after `applyTransmitterRegistry`, overlay stored roles. For each parsed tank that `matchStoredTanks` pairs with a row where `roleIsComputers` is false, set `role` to the stored `tankRole` and `roleSource` to null. Then call `claimBailoutGases`. Return `remappedIndices` along with the index-to-id map.
- `_insertGasSwitches` maps `sw.toTankIndex` through `remappedIndices` before looking up `tankIdsByIndex`.
- In `dive_import_service.dart`, call `claimBailoutGases` right after `applyTransmitterRegistry`, and remap the dive's gas switches the same way before they are persisted.
- At both sites, build `pressuresByIndex` from the per-tank samples the site already turns into tank pressure series, and `inWaterEndSeconds` from `lastTimeBelowSurfaceThreshold` over the profile.

- [ ] **Step 8: Run and see them pass**

Run: `flutter test test/features/dive_computer`
Expected: PASS.

- [ ] **Step 9: Commit**

`git commit -m "feat(dive-computer): a bailout transmitter claims the open-circuit gas it was breathed from"`

### Task 4: The `transmitter_role` detector

**Files:**
- Create: `lib/features/data_quality/domain/detectors/transmitter_role_detector.dart`
- Modify: `lib/features/data_quality/domain/quality_thresholds.dart` (new `// transmitter_role` group after `// tank_assignment`, ~:96)
- Modify: `lib/features/data_quality/domain/detectors/quality_detector_registry.dart:16`
- Modify: `lib/features/data_quality/data/services/quality_prefilters.dart:121-135` (use `withPressures`)
- Modify: `lib/features/data_quality/presentation/widgets/quality_finding_message.dart` (`detectorTitle` :54, `buildFindingMessage` :75)
- Modify: `lib/l10n/arb/app_*.arb` (23 files), then regenerate l10n
- Modify: `test/features/data_quality/helpers/quality_test_helpers.dart` (`makeTestDive` gains `DiveMode diveMode = DiveMode.oc`)
- Test: `test/features/data_quality/domain/detectors/transmitter_role_detector_test.dart`
- Test: `test/features/data_quality/data/quality_prefilters_test.dart:116` (count 13 becomes 14, plus the new id)
- Test: `test/features/data_quality/presentation/quality_finding_message_test.dart`

**Interfaces:**
- Consumes: `bailoutEvidence<String>` (Task 3), with `isLoopTank` true for tanks whose `role` is `diluent` or `oxygenSupply`.
- Produces: `TransmitterRoleDetector` with `id 'transmitter_role'`, `version 1`, `category QualityCategory.tank`, severity `warning`, and discriminator = tank id. The finding has params `{'tankId', 'tankOrder', 'ocTankId', 'ocDropBar', 'loopRate', 'ocRate', 'role'}`, where `role` is the current `TankRole.name`.

- [ ] **Step 1: Write the failing detector tests**

Build a CCR dive with `makeTestDive(diveMode: DiveMode.ccr, tanks: ...)` and `flatProfile(durationSeconds: 3600)`:
- `'flags an O-named tank breathed only on open circuit'`: same shape as Task 3's first timeline test. Expect one finding with `params['ocTankId'] == 'oc'` and `params['ocDropBar'] == 60`.
- `'ignores a role the diver set'`: `roleSource` is null. Expect none.
- `'ignores OC and SCR dives'`.
- `'ignores a tank with no pressure series'`.
- `'finding ids are stable across scans'`: run `detect` twice and expect the same id.

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/data_quality/domain/detectors/transmitter_role_detector_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the detector, thresholds, registration and prefilter**

Candidates are tanks with `roleSource == TankRoleSource.transmitterName` and a series in `pressuresByTankId`. `inWaterEndSeconds = lastTimeBelowSurfaceThreshold(ctx.primarySamples.map((s) => (t: s.t, depth: s.depth)))`.

- [ ] **Step 4: Add strings and the message**

`dataQuality_detector_transmitter_role`: "Transmitter role". `dataQuality_msg_transmitterRoleBailout(tankNumber, role, ocDrop)`: "Tank {tankNumber} is marked {role} from its transmitter's name, but it lost {ocDrop} after you switched to open circuit and almost none on the loop. It looks like your bailout. A bailout you never breathed, or a bailout without a gas switch on the computer, cannot be detected." In `buildFindingMessage`, add a `'transmitter_role'` case with `tankNumber = i('tankOrder') + 1`, the role display name, and `fmt.pressure(d('ocDropBar'))`. Translate into all 22 other locales. Regenerate with `flutter gen-l10n`.

- [ ] **Step 5: Write the message tests, then run them and see them pass**

`'transmitter_role message shows bar for a metric diver'` expects text containing "60 bar". `'transmitter_role message shows psi for an imperial diver'` expects text containing "870 psi".
Run: `flutter test test/features/data_quality`
Expected: PASS.

- [ ] **Step 6: Commit**

`git commit -m "feat(data-quality): flag a transmitter role that conflicts with when its tank was breathed"`

### Task 5: Repository write for "use as bailout"

**Files:**
- Create: `lib/features/dive_log/data/repositories/tank_role_repair_repository.dart`
- Create: `lib/features/dive_log/domain/services/as_imported_gas_cylinder.dart`
- Test: `test/features/dive_log/data/repositories/tank_role_repair_repository_test.dart`

**Interfaces:**
- Produces:

```dart
bool isAsImportedGasCylinder(DiveTank tank, {required bool hasPressureSeries});

typedef UseAsBailoutUndo = ({
  List<DiveTank> tankRows,          // rows before the change, for bulkRestoreTankRows
  List<GasSwitch> retargetedSwitches, // as they were before
});

class TankRoleRepairRepository {
  TankRoleRepairRepository({AppDatabase? db, SyncRepository? sync});

  /// Re-roles [tankId] to bailout, clears roleSource, takes [ocTankId]'s mix,
  /// and merges [ocTankId] in when it is an as-imported gas cylinder of the
  /// same computer. Null when [tankId] is gone or no longer name-derived.
  /// Caller owns the transaction and notify.
  Future<({bool merged, UseAsBailoutUndo undo})?> useAsBailout({
    required String diveId,
    required String tankId,
    required String ocTankId,
  });

  Future<void> undoUseAsBailout(UseAsBailoutUndo undo);
}
```

The merge retargets `gas_switches.tank_id` from `ocTankId` to `tankId` with an `update`, marking each pending as `'gasSwitches'`. It does this **before** deleting `ocTankId`, because the FK cascades. It then deletes the row and calls `logDeletion(entityType: 'diveTanks')`. The re-roled row is marked pending as `'diveTanks'`.

- [ ] **Step 1: Write the failing tests**

- `'re-roles, takes the OC mix and merges an as-imported cylinder'`: expect the role `bailout`, `roleSource` null, mix 18/45, `ocTankId` gone with a tombstone, and every former OC switch now on `tankId`.
- `'keeps an OC cylinder the diver edited'`: the OC row has `volume` 11.1. Expect it kept, with its switches unchanged.
- `'second repair after the cylinder was merged re-roles without merging'` (Review Focus 1): `ocTankId` was already deleted. Expect the role changed and `merged == false`.
- `'does not merge across computers'` (Review Focus 2).
- `'undo restores the cylinder and its switches'` (Review Focus 3).
- `'returns null for a tank whose role the diver set'`.

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/dive_log/data/repositories/tank_role_repair_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement both files**

When `ocTankId` is gone, take the mix from `ocTankId`'s row read before any write. If it is missing, keep the current mix and do not merge.

- [ ] **Step 4: Run and see them pass.** Expected: PASS.

- [ ] **Step 5: Commit**

`git commit -m "feat(dive-log): repository write to re-role a transmitter tank as bailout"`

### Task 6: Registry apply-to-existing fixes the bailout mix

**Files:**
- Modify: `lib/features/transmitters/data/repositories/transmitter_repository.dart:259-317`
- Test: `test/features/transmitters/data/repositories/transmitter_repository_test.dart`

**Interfaces:**
- Consumes: `bailoutEvidence<String>` (Task 3), `TankRoleRepairRepository.useAsBailout` (Task 5), `isAsImportedGasCylinder` (Task 5).
- Produces: `typedef ApplyToExistingResult = ({int tanksUpdated, int divesUpdated, int mixesKept});`. The new field means dives where a bailout role was applied but no mix source was found.

- [ ] **Step 1: Write the failing tests**

- `'applying a bailout entry fixes the mix from the OC cylinder that was breathed'`: a past CCR dive with this serial, name-derived O2 at 100/0, and an OC switch to a sensorless 18/45 cylinder. Expect bailout at 18/45, the cylinder merged, `mixesKept == 0`.
- `'falls back to the single sensorless bailout'`: no switches. Expect the same result.
- `'keeps the mix and counts it when there is no source'`: no sensorless bailout. Expect `mixesKept == 1` and the role changed.
- `'non-bailout entries behave as before'`: existing tests stay green.

- [ ] **Step 2: Run and see them fail.** Run: `flutter test test/features/transmitters/data/repositories/transmitter_repository_test.dart`. Expected: the new tests FAIL.

- [ ] **Step 3: Implement**

For each candidate row that was name-derived and whose new role is `bailout`, load that dive's tanks, switches and tank series, then compute `bailoutEvidence`. If it gives an `ocTankKey`, call `useAsBailout` with it. Otherwise, if exactly one tank on that dive has role bailout, no serial, and passes `isAsImportedGasCylinder`, use that one. Otherwise, keep the current write (role only) and count `mixesKept`. Everything runs inside the existing transaction.

- [ ] **Step 4: Run and see them pass.** Expected: PASS.

- [ ] **Step 5: Commit**

`git commit -m "feat(transmitters): applying a bailout entry also fixes each dive's mix"`

### Task 7: The repair action, its confirmation and registering the transmitter

**Files:**
- Modify: `lib/features/data_quality/domain/repairs/quality_repair_action.dart` (new class, and `repairOptionsFor` :202)
- Modify: `lib/features/data_quality/data/services/quality_repair_executor.dart` (new method)
- Create: `lib/features/data_quality/presentation/widgets/use_as_bailout_dialog.dart`
- Modify: `lib/features/data_quality/presentation/pages/data_quality_inbox_page.dart` (`_runAction` switch :173-413)
- Modify: `lib/features/data_quality/presentation/widgets/quality_finding_card.dart:74-105`
- Modify: `lib/l10n/arb/app_*.arb`
- Test: `test/features/data_quality/repairs/repair_mapping_test.dart`
- Test: `test/features/data_quality/repairs/quality_repair_executor_test.dart`
- Test: `test/features/data_quality/presentation/use_as_bailout_dialog_test.dart`

**Interfaces:**
- Consumes: Task 5 repository, Task 6 `ApplyToExistingResult`, `TransmitterRepository.create`/`update`/`getForDiver`.
- Produces:

```dart
class UseAsBailoutRepair extends QualityRepairAction {
  const UseAsBailoutRepair({required this.diveId, required this.tankId,
      required this.ocTankId});
  final String diveId, tankId, ocTankId;
}

// QualityRepairExecutor
Future<RepairResult> useAsBailout({
  required String diveId, required String tankId, required String ocTankId,
  required String findingId, required bool registerTransmitter,
  String? serial, String? diverId,
});
```

`repairOptionsFor` maps `'transmitter_role'` to `[UseAsBailoutRepair(...), GoToDiveRepair(diveId)]`.

- [ ] **Step 1: Write the failing tests**

- Mapping: a `'transmitter_role'` finding gives `UseAsBailoutRepair` first.
- Executor, `'useAsBailout without registering resolves the finding and undo restores'`.
- Executor, `'useAsBailout with registering creates a bailout registry entry and applies it to other dives'`: a second dive with the same serial ends up bailout with the OC mix.
- Executor, `'registering updates an existing channel-matched entry's role'`.
- Dialog (widget test): it shows "Role: O₂ Supply, read from the transmitter's name → Bailout" and "Gas mix: O2 → 18/45". The merge line appears only when merging. The checkbox "Also register this transmitter as a Bailout" is shown ticked only when the tank has a serial. Confirm returns `(confirmed: true, register: true)`.

- [ ] **Step 2: Run and see them fail.** Run: `flutter test test/features/data_quality`. Expected: the new tests FAIL.

- [ ] **Step 3: Implement**

- **Executor.** It follows the existing contract: transaction, notify, `_finish`, `RepairResult.applied(undo)`. It registers first: find an entry by normalized serial, `update` its role to `bailout` if found, otherwise `create` one with `label` = tank name or serial. It then calls `applyToExistingDives` and Task 5 for this dive. Undo reverts this dive only. The registry entry stays, and the snackbar says so.
- **Dialog.** It reuses #3416's change-line strings (`cylinderConfigs_fieldGasMix` and the role-from-name label). New strings: `dataQuality_repairLabel_useAsBailout` "Use as bailout", `dataQuality_useAsBailout_title` "Make this tank the bailout?", `dataQuality_useAsBailout_merge` "Removes the duplicate Bailout cylinder (switches move to Tank {tankNumber})", `dataQuality_useAsBailout_register` "Also register this transmitter as a Bailout", and `dataQuality_useAsBailout_mixesKept` "{count} other dives kept their gas mix. Check them." (plural form). All go in 23 locales.
- **Inbox.** The `_runAction` case awaits the dialog, then calls the executor inside `withUndo`. It shows `mixesKept` when it is above 0.

- [ ] **Step 4: Run and see them pass.** Run: `flutter test test/features/data_quality test/features/transmitters`. Expected: PASS.

- [ ] **Step 5: Commit**

`git commit -m "feat(data-quality): use-as-bailout repair with transmitter registration"`

### Task 8: Whole-branch checks and PR

- [ ] **Step 1:** Run `dart format .` and `flutter analyze`. Expected: no issues.
- [ ] **Step 2:** Run `flutter test test/architecture test/shared test/features/data_quality test/features/dive_computer test/features/transmitters test/features/dive_log/data test/features/cylinder_configs`. Expected: PASS.
- [ ] **Step 3:** Capture screenshots of the finding card and the confirm dialog, in light and dark mode and at phone and desktop widths.
- [ ] **Step 4:** Open the PR with `Closes #3307` and a Screenshots section listing each image.
