# Isobaric counterdiffusion on the dive profile: implementation plan

Spec: [2026-11-14-icd-profile-markers-design.md](../specs/2026-11-14-icd-profile-markers-design.md)
Issue: #4530

Each step is one commit, tests first.

1. **Ranges.** `lib/features/dive_log/domain/entities/counterdiffusion_analysis.dart`
   (`CounterdiffusionKind`, `CounterdiffusionRange`, `IcdSwitchMarker`,
   `CounterdiffusionAnalysis`) and
   `lib/features/dive_log/domain/services/counterdiffusion_ranges.dart`:
   per sample and compartment, classify opposing / ICD-relevant from
   `DecoStatus.n2Exchange` / `heExchange`, the Haldane net rate (ln 2,
   bar/min) and the total-tension condition; group samples into runs, merge
   short gaps, drop short runs. Kept in `features/dive_log/domain` because
   `lib/core/deco` imports nothing from `features`.
2. **Switch markers.** `lib/features/dive_log/domain/services/icd_switch_markers.dart`:
   consecutive `ProfileGasSegment`s through `computeIcd()`; OC to OC with the
   segment fractions, loop to open circuit (bailout) with the loop's
   fractions at the switch depth; caution and violation kept.
3. **Analysis field.** `ProfileAnalysis.counterdiffusion`, built in
   `ProfileAnalysisService` after the deco statuses, empty when tissue
   loading is withheld; `copyWith` and `empty()` carry it.
4. **Settings.** `defaultShowCounterdiffusion` and `counterdiffusionShowAll`
   on the diver settings: table column + migration rung, repository mapping,
   sync conflict fields, `AppSettings` + notifier setters, "Default visible
   metrics" tile.
5. **Chart.** Legend state (`showCounterdiffusion`, `counterdiffusionShowAll`),
   legend config (`hasCounterdiffusion` from `heliumPresent`), chart options
   entry with `ICD | All` segments, active legend entry, bands and switch
   markers in `DiveProfileChart`, wiring in the chart host, fullscreen page
   and panel, cursor tooltip line.
6. **Safety rule.** `SafetyRuleId.isobaricCounterdiffusion`, findings from ICD
   ranges and violation markers, `engineVersion` 12, rule labels and
   settings tile, finding texts.
7. **Localisation and polish.** All ARB files, `flutter gen-l10n`,
   `dart format`, `flutter analyze`.
