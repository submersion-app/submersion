# SAC and RMV Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Represent SAC (tank-pressure rate, bar/min or psi/min) and RMV (surface gas volume rate, L/min or cuft/min) as two named quantities, replace the `SacUnit` unit preference with a `GasConsumptionDisplay { sac, rmv, both }` display preference (default `both`), and give the dive table independent `sac` and `rmv` columns.

**Architecture:** The two values are already computed separately (`Dive.sacPressure` and `Dive.sacFor`); the preference is a display selector forked at roughly fifteen call sites. The plan introduces the new enum and settings field first while keeping a derived `sacUnit` shim so every surface still compiles, migrates the database column and the sync wire key, then converts one surface per task to render each lane behind `display.showsSac` / `display.showsRmv`, and finally deletes the shim, the old enum, and the old l10n keys. Formatting collapses into `UnitFormatter.formatSac` / `formatRmv`.

**Tech Stack:** Flutter, Riverpod (legacy `StateProvider` / `StateNotifier` via `package:submersion/core/providers/provider.dart`), Drift (schema migration at v170), `flutter gen-l10n`, `flutter test`.

**Spec:** `docs/superpowers/specs/2026-08-26-sac-rmv-split-design.md`. Every task below cites the spec section it implements.

## Global Constraints

- No em-dashes or en-dashes anywhere (code, comments, commits, ARB values, PR text).
- No emojis in code, comments, or documentation.
- Immutability: never mutate a `Dive`, `AppSettings`, or list in place; use `copyWith` and new collections.
- Schema rung: **v170** (`currentSchemaVersion`, `migrationVersions`, `onUpgrade`, `beforeOpen` backstop). Re-verify before Task 5 with the scan in that task; if another PR has since claimed 170 on `origin/main`, take the next free number everywhere the plan says 170.
- `minimumCompatibleSchemaVersion` rises to the same rung (spec D5; the `#1089` rules in `database.dart` classify a synced-column rename and a value-set change as breaking).
- Persisted planner fields (`DivePlan.sacBottom` and siblings), plan-file keys, and calculator provider names are NOT renamed (spec D1).
- `flutter gen-l10n` runs LAST in any task that edits ARB files, after all eleven locales carry the value; never json-round-trip an ARB file (edit lines in place).
- Locale ARBs carry `@meta` only for keys with placeholders; `app_en.arb` carries a compact one-line `@key` entry for placeholder keys (see the existing `@diveLog_detail_sacVolumeHint` line as the model).
- German: `AMV` for every RMV label, `Druckverbrauch` for every SAC label, no "SAC" in `app_de.arb` outside `enum_certificationAgency_bsac` (spec D8).
- Every task ends with `dart format` on the touched files, `flutter analyze` on the touched directories, and the listed tests green before its commit.
- Commit messages carry no `Co-Authored-By` trailer and no session URL. PR body carries no attribution line and no session URL.
- Widget tests pin `locale: const Locale('en')` where the pump helper allows it, and match English strings.

## Worktree

This plan runs in `.claude/worktrees/sac-rmv-split` (branch `worktree-sac-rmv-split`, cut from `origin/main` at 80f07e66f2f, schema v164, PR #1298 included). Submodules, `flutter pub get`, and `dart run build_runner build --delete-conflicting-outputs` have already been run there. Every path below is relative to that worktree. Use worktree-absolute paths for every Read/Edit/Write (`/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/sac-rmv-split/...`); the Bash cwd can silently revert to the main checkout between turns, and edits made through main-checkout paths land on `main`.

If `origin/main` has moved when work starts, merge it first (`git merge --ff-only origin/main` fails if the branch has commits; use `git merge origin/main`), then rerun `dart run build_runner build --delete-conflicting-outputs`, because the generated Drift code is git-ignored and goes stale when `database.dart` changes upstream.

## File structure

Created:
- `lib/core/constants/gas_consumption_display.dart`: `GasConsumptionLane`, `GasConsumptionDisplay` (spec D2).
- `lib/features/dive_log/presentation/utils/gas_consumption_tooltip.dart`: pure helper that picks the chart tooltip lane and formats it (spec D9, profile chart row).
- `lib/features/statistics/presentation/providers/statistics_gas_lane_provider.dart`: page-level lane for the gas statistics page (spec D9, statistics row).
- `test/core/constants/gas_consumption_display_test.dart`
- `test/core/database/migration_v170_gas_consumption_display_test.dart`
- `test/core/services/sync/legacy_sac_unit_key_test.dart`
- `test/features/dive_log/presentation/utils/gas_consumption_tooltip_test.dart`
- `test/features/statistics/presentation/providers/statistics_gas_lane_provider_test.dart`
- `test/features/statistics/presentation/pages/statistics_gas_page_widget_test.dart`
- `test/features/settings/presentation/pages/settings_page_gas_consumption_test.dart`

Modified (grouped by task): `units.dart`, `settings_providers.dart`, `diver_settings_repository.dart`, `database.dart`, `sync_data_serializer.dart`, `unit_formatter.dart`, `dive.dart`, `cylinder_sac.dart`, `dive_field.dart`, `dive_field_extractor.dart`, `dive_field_formatter.dart`, `dive_field_column_sizing.dart`, `dive_field_adapter.dart`, `view_field_config.dart`, `dive_table_view.dart`, `dive_list_page.dart`, `dive_detail_page.dart`, `dive_detail_ui_providers.dart`, `sac_normalization.dart`, `cylinders_card.dart`, `range_stats_panel.dart`, `dive_profile_chart.dart`, `statistics_gas_page.dart`, `statistics_providers.dart`, `settings_page.dart`, `units_step.dart`, `setup_apply_service.dart`, all eleven ARBs and the twelve generated `app_localizations*.dart`, and the tests named in each task.

Deleted: `test/features/statistics/presentation/pages/statistics_gas_page_test.dart` (a unit test that mirrored the old `SacUnit` fork; replaced by the widget test above).

---

### Task 1: Add the new l10n keys and re-word the lane-neutral ones

Spec: D8. Old keys stay in place until Task 14, so every commit in between compiles.

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`
- Test: `test/l10n/arb_parity_test.dart`, `test/l10n/german_sac_terminology_test.dart` (both must stay green; the German test is extended in Task 14)

**Interfaces:**
- Produces these `AppLocalizations` getters, used by every later task: `gasConsumption_sac`, `gasConsumption_rmv`, `enum_diveField_sac`, `enum_diveField_sac_short`, `enum_diveField_rmv`, `enum_diveField_rmv_short`, `diveLog_detail_label_sac`, `diveLog_detail_label_rmv`, `settings_units_gasConsumption`, `settings_units_dialog_gasConsumption`, `settings_units_gasConsumption_sac_subtitle(String unit)`, `settings_units_gasConsumption_rmv_subtitle(String unit)`, `settings_units_gasConsumption_both`, `settings_units_gasConsumption_both_subtitle`, `setup_units_gasConsumption`, `statistics_gas_sacRecords_bestSac`, `statistics_gas_sacRecords_bestRmv`, `statistics_gas_sacRecords_highestSac`, `statistics_gas_sacRecords_highestRmv`.

- [ ] **Step 1: Add the nineteen new keys to `app_en.arb`**

Insert each line next to the existing key it relates to (alphabetical block order does not matter to gen-l10n; keep related keys adjacent for readers). The two subtitle keys take a `{unit}` placeholder and need a one-line `@` entry, written in the same compact style as `@diveLog_detail_sacVolumeHint` at the end of the file:

```json
  "gasConsumption_sac": "SAC",
  "gasConsumption_rmv": "RMV",
  "enum_diveField_sac": "SAC (pressure rate)",
  "enum_diveField_sac_short": "SAC",
  "enum_diveField_rmv": "RMV (volume rate)",
  "enum_diveField_rmv_short": "RMV",
  "diveLog_detail_label_sac": "SAC",
  "diveLog_detail_label_rmv": "RMV",
  "settings_units_gasConsumption": "Gas consumption",
  "settings_units_dialog_gasConsumption": "Gas consumption display",
  "settings_units_gasConsumption_sac_subtitle": "Tank pressure drop per minute ({unit}). Works with any logged pressures.",
  "settings_units_gasConsumption_rmv_subtitle": "Gas volume breathed per minute at the surface ({unit}). Needs a tank volume.",
  "settings_units_gasConsumption_both": "Both",
  "settings_units_gasConsumption_both_subtitle": "Show SAC and RMV side by side.",
  "setup_units_gasConsumption": "Gas consumption",
  "statistics_gas_sacRecords_bestSac": "Best SAC",
  "statistics_gas_sacRecords_bestRmv": "Best RMV",
  "statistics_gas_sacRecords_highestSac": "Highest SAC",
  "statistics_gas_sacRecords_highestRmv": "Highest RMV",
```

and, next to `@diveLog_detail_sacVolumeHint`:

```json
  "@settings_units_gasConsumption_sac_subtitle": {"placeholders": {"unit": {"type": "String"}}},
  "@settings_units_gasConsumption_rmv_subtitle": {"placeholders": {"unit": {"type": "String"}}},
```

- [ ] **Step 2: Add the same nineteen keys to the ten locale ARBs**

Locale files carry no `@` entries for simple placeholder keys. Values per key:

`gasConsumption_sac`: `SAC` in ar, es, fr, he, hu, it, nl, pt, zh; de `Druckverbrauch`.
`gasConsumption_rmv`: `RMV` in ar, es, fr, he, hu, it, nl, pt, zh; de `AMV`.
`enum_diveField_sac_short`: `SAC` in ar, es, fr, he, hu, it, nl, pt, zh; de `Druckverbr.`.
`enum_diveField_rmv_short`: `RMV` in ar, es, fr, he, hu, it, nl, pt, zh; de `AMV`.
`diveLog_detail_label_sac`: same values as `gasConsumption_sac`.
`diveLog_detail_label_rmv`: same values as `gasConsumption_rmv`.
`setup_units_gasConsumption`: same values as `settings_units_gasConsumption` below.

`enum_diveField_sac`
| locale | value |
| --- | --- |
| ar | `SAC (معدل الضغط)` |
| de | `Druckverbrauch` |
| es | `SAC (tasa de presión)` |
| fr | `SAC (taux de pression)` |
| he | `SAC (קצב לחץ)` |
| hu | `SAC (nyomásráta)` |
| it | `SAC (tasso di pressione)` |
| nl | `SAC (druksnelheid)` |
| pt | `SAC (taxa de pressão)` |
| zh | `SAC（压力速率）` |

`enum_diveField_rmv`
| locale | value |
| --- | --- |
| ar | `RMV (معدل الحجم)` |
| de | `AMV` |
| es | `RMV (tasa de volumen)` |
| fr | `RMV (taux de volume)` |
| he | `RMV (קצב נפח)` |
| hu | `RMV (térfogatráta)` |
| it | `RMV (tasso di volume)` |
| nl | `RMV (volumesnelheid)` |
| pt | `RMV (taxa de volume)` |
| zh | `RMV（容量速率）` |

`settings_units_gasConsumption`
| locale | value |
| --- | --- |
| ar | `استهلاك الغاز` |
| de | `Gasverbrauch` |
| es | `Consumo de gas` |
| fr | `Consommation de gaz` |
| he | `צריכת גז` |
| hu | `Gázfogyasztás` |
| it | `Consumo di gas` |
| nl | `Gasverbruik` |
| pt | `Consumo de gás` |
| zh | `气体消耗` |

`settings_units_dialog_gasConsumption`
| locale | value |
| --- | --- |
| ar | `عرض استهلاك الغاز` |
| de | `Anzeige des Gasverbrauchs` |
| es | `Visualización del consumo de gas` |
| fr | `Affichage de la consommation de gaz` |
| he | `תצוגת צריכת גז` |
| hu | `Gázfogyasztás megjelenítése` |
| it | `Visualizzazione del consumo di gas` |
| nl | `Weergave gasverbruik` |
| pt | `Exibição do consumo de gás` |
| zh | `气体消耗显示` |

`settings_units_gasConsumption_sac_subtitle`
| locale | value |
| --- | --- |
| ar | `انخفاض ضغط الأسطوانة في الدقيقة ({unit}). يعمل مع أي ضغوط مسجلة.` |
| de | `Flaschendruckabfall pro Minute ({unit}). Funktioniert mit allen protokollierten Drücken.` |
| es | `Caída de presión del tanque por minuto ({unit}). Funciona con cualquier presión registrada.` |
| fr | `Baisse de pression du bloc par minute ({unit}). Fonctionne avec toutes les pressions enregistrées.` |
| he | `ירידת לחץ בבלון לדקה ({unit}). עובד עם כל לחץ מתועד.` |
| hu | `Palacknyomás-csökkenés percenként ({unit}). Bármely naplózott nyomással működik.` |
| it | `Calo di pressione della bombola al minuto ({unit}). Funziona con qualsiasi pressione registrata.` |
| nl | `Drukdaling van de fles per minuut ({unit}). Werkt met alle gelogde drukken.` |
| pt | `Queda de pressão do cilindro por minuto ({unit}). Funciona com qualquer pressão registrada.` |
| zh | `每分钟气瓶压力下降（{unit}）。适用于任何已记录的压力。` |

`settings_units_gasConsumption_rmv_subtitle`
| locale | value |
| --- | --- |
| ar | `حجم الغاز المتنفس في الدقيقة عند السطح ({unit}). يتطلب حجم الأسطوانة.` |
| de | `An der Oberfläche geatmetes Gasvolumen pro Minute ({unit}). Erfordert ein Flaschenvolumen.` |
| es | `Volumen de gas respirado por minuto en superficie ({unit}). Requiere el volumen del tanque.` |
| fr | `Volume de gaz respiré par minute en surface ({unit}). Nécessite le volume du bloc.` |
| he | `נפח גז שנושם לדקה על פני השטח ({unit}). דורש נפח בלון.` |
| hu | `Felszínen belélegzett gáztérfogat percenként ({unit}). Palacktérfogat szükséges.` |
| it | `Volume di gas respirato al minuto in superficie ({unit}). Richiede il volume della bombola.` |
| nl | `Ingeademd gasvolume per minuut aan de oppervlakte ({unit}). Vereist een flesvolume.` |
| pt | `Volume de gás respirado por minuto à superfície ({unit}). Requer o volume do cilindro.` |
| zh | `水面每分钟呼吸的气体容量（{unit}）。需要气瓶容量。` |

`settings_units_gasConsumption_both`
| locale | value |
| --- | --- |
| ar | `كلاهما` |
| de | `Beide` |
| es | `Ambos` |
| fr | `Les deux` |
| he | `שניהם` |
| hu | `Mindkettő` |
| it | `Entrambi` |
| nl | `Beide` |
| pt | `Ambos` |
| zh | `两者` |

`settings_units_gasConsumption_both_subtitle`
| locale | value |
| --- | --- |
| ar | `عرض SAC و RMV جنبًا إلى جنب.` |
| de | `Druckverbrauch und AMV nebeneinander anzeigen.` |
| es | `Mostrar SAC y RMV uno junto al otro.` |
| fr | `Afficher SAC et RMV côte à côte.` |
| he | `הצג SAC ו-RMV זה לצד זה.` |
| hu | `SAC és RMV megjelenítése egymás mellett.` |
| it | `Mostra SAC e RMV affiancati.` |
| nl | `Toon SAC en RMV naast elkaar.` |
| pt | `Mostrar SAC e RMV lado a lado.` |
| zh | `并排显示 SAC 和 RMV。` |

`statistics_gas_sacRecords_bestSac` / `_bestRmv` / `_highestSac` / `_highestRmv`
| locale | bestSac | bestRmv | highestSac | highestRmv |
| --- | --- | --- | --- | --- |
| ar | `أفضل SAC` | `أفضل RMV` | `أعلى SAC` | `أعلى RMV` |
| de | `Niedrigster Druckverbrauch` | `Bestes AMV` | `Höchster Druckverbrauch` | `Höchstes AMV` |
| es | `Mejor SAC` | `Mejor RMV` | `SAC más alto` | `RMV más alto` |
| fr | `Meilleur SAC` | `Meilleur RMV` | `SAC le plus élevé` | `RMV le plus élevé` |
| he | `SAC הטוב ביותר` | `RMV הטוב ביותר` | `SAC הגבוה ביותר` | `RMV הגבוה ביותר` |
| hu | `Legjobb SAC` | `Legjobb RMV` | `Legmagasabb SAC` | `Legmagasabb RMV` |
| it | `Miglior SAC` | `Miglior RMV` | `SAC più alto` | `RMV più alto` |
| nl | `Beste SAC` | `Beste RMV` | `Hoogste SAC` | `Hoogste RMV` |
| pt | `Melhor SAC` | `Melhor RMV` | `Maior SAC` | `Maior RMV` |
| zh | `最佳 SAC` | `最佳 RMV` | `最高 SAC` | `最高 RMV` |

- [ ] **Step 3: Re-word the lane-neutral existing keys (values only, keys unchanged) in all eleven ARBs**

`diveLog_detail_section_sacRateBySegment` and `diveDetailSection_sacSegments_name` (same value in both):
| locale | value |
| --- | --- |
| en | `Gas consumption by segment` |
| ar | `استهلاك الغاز حسب المقطع` |
| de | `Gasverbrauch nach Segment` |
| es | `Consumo de gas por segmento` |
| fr | `Consommation de gaz par segment` |
| he | `צריכת גז לפי מקטע` |
| hu | `Gázfogyasztás szakaszonként` |
| it | `Consumo di gas per segmento` |
| nl | `Gasverbruik per segment` |
| pt | `Consumo de gás por segmento` |
| zh | `按分段的气体消耗` |

`diveDetailSection_sacSegments_description`:
| locale | value |
| --- | --- |
| en | `SAC and RMV by phase or time` |
| ar | `SAC و RMV حسب المرحلة أو الوقت` |
| de | `Druckverbrauch und AMV nach Phase oder Zeit` |
| es | `SAC y RMV por fase o tiempo` |
| fr | `SAC et RMV par phase ou temps` |
| he | `SAC ו-RMV לפי שלב או זמן` |
| hu | `SAC és RMV fázis vagy idő szerint` |
| it | `SAC e RMV per fase o tempo` |
| nl | `SAC en RMV per fase of tijd` |
| pt | `SAC e RMV por fase ou tempo` |
| zh | `按阶段或时间的 SAC 和 RMV` |

`diveLog_legend_label_sacRate`, `enum_profileMetric_sacRate`, `settings_appearance_metric_sacRate`: the chart has one curve, computed in bar/min and shown as SAC or RMV by the tooltip lane, so these three name the curve neutrally. Use the `settings_units_gasConsumption` value for the locale (en `Gas consumption`, de `Gasverbrauch`, and so on).

`enum_profileMetric_sacRate_short`:
| locale | value |
| --- | --- |
| en | `Consumption` |
| ar | `الاستهلاك` |
| de | `Verbrauch` |
| es | `Consumo` |
| fr | `Conso.` |
| he | `צריכה` |
| hu | `Fogyasztás` |
| it | `Consumo` |
| nl | `Verbruik` |
| pt | `Consumo` |
| zh | `消耗` |

`statistics_gas_sacTrend_title`:
| locale | value |
| --- | --- |
| en | `Gas consumption trend` |
| ar | `اتجاه استهلاك الغاز` |
| de | `Gasverbrauchstrend` |
| es | `Tendencia del consumo de gas` |
| fr | `Tendance de la consommation de gaz` |
| he | `מגמת צריכת גז` |
| hu | `Gázfogyasztási trend` |
| it | `Tendenza del consumo di gas` |
| nl | `Gasverbruikstrend` |
| pt | `Tendência do consumo de gás` |
| zh | `气体消耗趋势` |

`statistics_gas_sacTrend_error`:
| locale | value |
| --- | --- |
| en | `Failed to load consumption trend` |
| ar | `فشل تحميل اتجاه الاستهلاك` |
| de | `Verbrauchstrend konnte nicht geladen werden` |
| es | `Error al cargar la tendencia de consumo` |
| fr | `Echec du chargement de la tendance de consommation` |
| he | `שגיאה בטעינת מגמת הצריכה` |
| hu | `Nem sikerult a fogyasztasi trend betoltese` |
| it | `Impossibile caricare la tendenza del consumo` |
| nl | `Kan verbruikstrend niet laden` |
| pt | `Falha ao carregar tendencia de consumo` |
| zh | `加载消耗趋势失败` |

`statistics_gas_sacRecords_title`:
| locale | value |
| --- | --- |
| en | `Gas consumption records` |
| ar | `سجلات استهلاك الغاز` |
| de | `Gasverbrauchsrekorde` |
| es | `Records de consumo de gas` |
| fr | `Records de consommation de gaz` |
| he | `שיאי צריכת גז` |
| hu | `Gázfogyasztási rekordok` |
| it | `Record di consumo di gas` |
| nl | `Gasverbruiksrecords` |
| pt | `Registros de consumo de gás` |
| zh | `气体消耗记录` |

`statistics_gas_sacRecords_empty`:
| locale | value |
| --- | --- |
| en | `No consumption data yet` |
| ar | `لا توجد بيانات استهلاك بعد` |
| de | `Noch keine Verbrauchsdaten verfügbar` |
| es | `Aun no hay datos de consumo` |
| fr | `Aucune donnee de consommation` |
| he | `אין עדיין נתוני צריכה` |
| hu | `Meg nincsenek fogyasztasi adatok` |
| it | `Nessun dato di consumo disponibile` |
| nl | `Nog geen verbruiksgegevens` |
| pt | `Nenhum dado de consumo ainda` |
| zh | `暂无消耗数据` |

`statistics_gas_sacRecords_error`:
| locale | value |
| --- | --- |
| en | `Failed to load consumption records` |
| ar | `فشل تحميل سجلات الاستهلاك` |
| de | `Verbrauchsrekorde konnten nicht geladen werden` |
| es | `Error al cargar los records de consumo` |
| fr | `Echec du chargement des records de consommation` |
| he | `שגיאה בטעינת שיאי הצריכה` |
| hu | `Nem sikerult a fogyasztasi rekordok betoltese` |
| it | `Impossibile caricare i record di consumo` |
| nl | `Kan verbruiksrecords niet laden` |
| pt | `Falha ao carregar registros de consumo` |
| zh | `加载消耗记录失败` |

`statistics_gas_sacByRole_title`:
| locale | value |
| --- | --- |
| en | `Gas consumption by tank role` |
| ar | `استهلاك الغاز حسب دور الأسطوانة` |
| de | `Gasverbrauch nach Flaschenrolle` |
| es | `Consumo de gas por funcion del tanque` |
| fr | `Consommation de gaz par role du bloc` |
| he | `צריכת גז לפי תפקיד בלון` |
| hu | `Gázfogyasztás palack szerep szerint` |
| it | `Consumo di gas per ruolo bombola` |
| nl | `Gasverbruik per flesrol` |
| pt | `Consumo de gás por função do cilindro` |
| zh | `按气瓶用途的气体消耗` |

`statistics_gas_sacByRole_error`:
| locale | value |
| --- | --- |
| en | `Failed to load consumption by role` |
| ar | `فشل تحميل الاستهلاك حسب الدور` |
| de | `Verbrauch nach Rolle konnte nicht geladen werden` |
| es | `Error al cargar el consumo por funcion` |
| fr | `Echec du chargement de la consommation par role` |
| he | `שגיאה בטעינת צריכה לפי תפקיד` |
| hu | `Nem sikerult a szerep szerinti fogyasztas betoltese` |
| it | `Impossibile caricare il consumo per ruolo` |
| nl | `Kan verbruik per rol niet laden` |
| pt | `Falha ao carregar consumo por funcao` |
| zh | `加载按用途分类的消耗失败` |

`statistics_category_gas_subtitle`:
| locale | value |
| --- | --- |
| en | `Gas consumption & gas mixes` |
| ar | `استهلاك الغاز وخلطات الغاز` |
| de | `Gasverbrauch & Gasgemische` |
| es | `Consumo de gas y mezclas` |
| fr | `Consommation de gaz et melanges` |
| he | `צריכת גז ותערובות גז` |
| hu | `Gázfogyasztás és gázkeverékek` |
| it | `Consumo di gas e miscele` |
| nl | `Gasverbruik en gasmengsels` |
| pt | `Consumo de gás e misturas` |
| zh | `气体消耗和气体混合` |

`diveLog_detail_sacVolumeHint` (keep the `{unit}` placeholder; de is unchanged, it already says AMV):
| locale | value |
| --- | --- |
| en | `Add a cylinder volume to show RMV in {unit}/min` |
| ar | `أضف حجم الأسطوانة لعرض RMV بوحدة {unit}/min` |
| es | `Añade el volumen del cilindro para mostrar el RMV en {unit}/min` |
| fr | `Ajoutez le volume du bloc pour afficher le RMV en {unit}/min` |
| he | `הוסף נפח בלון כדי להציג RMV ב-{unit}/min` |
| hu | `Add meg a palack térfogatát, hogy az RMV {unit}/min-ben jelenjen meg` |
| it | `Aggiungi il volume della bombola per mostrare l'RMV in {unit}/min` |
| nl | `Voeg een flesvolume toe om de RMV in {unit}/min te tonen` |
| pt | `Adicione o volume do cilindro para mostrar o RMV em {unit}/min` |
| zh | `添加气瓶容积以按 {unit}/min 显示 RMV` |

`diveDetailSection_tanks_description` ends with a per-tank consumption phrase. Replace the final token of the value in each locale with a line-based script (the rest of each sentence is locale prose that must not move):

```bash
python3 - <<'EOF'
import json, pathlib
key = 'diveDetailSection_tanks_description'
replacements = {
    'en': ('per-tank SAC', 'per-tank consumption'),
    'ar': ('SAC', 'الاستهلاك'), 'de': ('AMV', 'Verbrauch'), 'es': ('SAC', 'consumo'),
    'fr': ('SAC', 'consommation'), 'he': ('SAC', 'צריכה'), 'hu': ('SAC', 'fogyasztás'),
    'it': ('SAC', 'consumo'), 'nl': ('SAC', 'verbruik'), 'pt': ('SAC', 'consumo'),
    'zh': ('SAC', '消耗'),
}
for code, (old, new) in replacements.items():
    path = pathlib.Path(f'lib/l10n/arb/app_{code}.arb')
    lines = path.read_text(encoding='utf-8').splitlines(keepends=True)
    hit = [i for i, l in enumerate(lines) if l.lstrip().startswith(f'"{key}"')]
    assert len(hit) == 1, (code, hit)
    i = hit[0]
    assert old in lines[i], (code, lines[i])
    lines[i] = lines[i].replace(old, new, 1)
    new_src = ''.join(lines)
    json.loads(new_src)
    path.write_text(new_src, encoding='utf-8')
    print(code, lines[i].strip())
EOF
```

If a locale's assertion fails because its value never contained the token, print the line, keep the value as it is, and move on; the point is only that no locale still says SAC or AMV for a card that now shows both lanes.

- [ ] **Step 4: Prove every ARB parses, then regenerate**

```bash
for f in lib/l10n/arb/app_*.arb; do python3 -c "import json; json.load(open('$f', encoding='utf-8'))" && echo "$f ok"; done
flutter gen-l10n
grep -A1 "get gasConsumption_sac" lib/l10n/arb/app_localizations_de.dart
```

Expected: every file `ok`; the German getter body reads `'Druckverbrauch'`, proving the locale value (not the English fallback) was baked in.

- [ ] **Step 5: Run the l10n tests**

Run: `flutter test test/l10n/arb_parity_test.dart test/l10n/german_sac_terminology_test.dart`
Expected: both pass (the German test still finds `AMV` on the old keys, which are untouched here).

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/arb/
git commit -m "i18n: add SAC and RMV labels and lane-neutral consumption wording"
```

---

### Task 2: Rename the lane getters on the domain entities

Spec: D1 code naming. `Dive.sacPressure` becomes `Dive.sac`, `Dive.sacFor` becomes `Dive.rmvFor`, `CylinderSac.sacVolume` becomes `CylinderSac.rmv`. Pure rename; every assertion stays numerically identical.

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart:355-456`
- Modify: `lib/features/dive_log/domain/entities/cylinder_sac.dart:31-38`
- Modify (call sites): `lib/core/constants/dive_field_extractor.dart:14,217,220`, `lib/core/utils/unit_formatter.dart:267`, `lib/features/dive_log/presentation/pages/dive_detail_page.dart:4068-4105`, `lib/features/dive_log/presentation/utils/sac_normalization.dart:5,12`, `lib/features/dive_log/presentation/widgets/cylinders_card.dart:222-223`
- Test: `test/features/dive_log/domain/entities/dive_sac_fix_test.dart`, `dive_sac_gas_model_test.dart`, `cylinder_sac_volume_test.dart`, `test/features/dive_log/data/services/gas_analysis_service_segment_sac_test.dart`, `test/core/constants/dive_field_extractor_test.dart:614`, `test/features/statistics/data/repositories/statistics_repository_sac_test.dart:259,446`, `test/features/dive_log/presentation/widgets/dive_table_view_test.dart:66`, `test/features/dive_log/presentation/pages/dive_detail_page_test.dart:1331`

**Interfaces:**
- Produces: `double? get sac` (bar/min at the surface, reference tank), `double? rmvFor(GasModel model)` (L/min at the surface, all tanks), `double? get rmv` on `CylinderSac` (L/min). `Dive.sacReferenceTank` keeps its name.

- [ ] **Step 1: Rename in the tests first**

Run the rename over `test/` only, then confirm the suite fails to compile:

```bash
perl -pi -e 's/\.sacFor\(/.rmvFor(/g; s/\bDive\.sacFor\b/Dive.rmvFor/g; s/\.sacPressure\b/.sac/g; s/\bDive\.sacPressure\b/Dive.sac/g; s/\.sacVolume\b/.rmv/g; s/\bCylinderSac\.sacVolume\b/CylinderSac.rmv/g' \
  $(grep -rl "sacFor\|sacPressure\|sacVolume" test/)
grep -rn "sacFor\|sacPressure\|sacVolume" test/ || echo "no stale references in test/"
```

In `dive_sac_fix_test.dart`, also change the group label `group('Dive.sac', () {` (the L/min group, line 42) to `group('Dive.rmvFor', () {` and the banner comment above it from `Dive.sac (L/min at surface)` to `Dive.rmvFor (L/min at surface)`; change `group('Dive.sacPressure', () {` (line 228) to `group('Dive.sac', () {` and its banner comment `Dive.sacPressure (bar/min at surface)` to `Dive.sac (bar/min at surface)`. In `dive_sac_gas_model_test.dart:84` change `group('Dive.sacPressure', () {` to `group('Dive.sac', () {`. In `cylinder_sac_volume_test.dart` change the doc comment `[CylinderSac.sacVolume]` to `[CylinderSac.rmv]` and `group('CylinderSac.sacVolume', () {` to `group('CylinderSac.rmv', () {`.

- [ ] **Step 2: Run one renamed test file to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/dive_sac_fix_test.dart`
Expected: compile error, `The method 'rmvFor' isn't defined for the type 'Dive'`.

- [ ] **Step 3: Rename the getters**

In `dive.dart`, replace the `sacFor` doc comment and signature (lines 355-365):

```dart
  /// Air consumption rate in L/min at surface (Surface Air Consumption)
  /// under [model], summing gas consumed across all tanks with valid data.
  ///
  /// Takes the model as a parameter rather than reading a provider so the
  /// entity stays free of container dependencies, mirroring how
  /// `extractDiveFieldValue` threads the SAC unit preference. Callers source
  /// it from `gasModelProvider`.
  ///
  /// The runtime is used verbatim: nothing is added for a safety stop
  /// (issue #828).
  double? sacFor(GasModel model) {
```

with:

```dart
  /// RMV: respiratory minute volume in L/min at the surface under [model],
  /// summing gas consumed across every tank that has pressures and a volume.
  ///
  /// This is the diver's property (how much gas their lungs move), so every
  /// cylinder counts. Its pressure-lane sibling [sac] reads one reference
  /// cylinder instead, because a pressure drop is a property of that
  /// cylinder's size (discussions #354, #803).
  ///
  /// Takes the model as a parameter rather than reading a provider so the
  /// entity stays free of container dependencies. Callers source it from
  /// `gasModelProvider`. The runtime is used verbatim: nothing is added for
  /// a safety stop (issue #828).
  double? rmvFor(GasModel model) {
```

Replace the `sacPressure` doc comment and signature (lines 432-435):

```dart
  /// Air consumption rate in pressure units per minute (bar/min or psi/min)
  /// This is a simpler calculation that doesn't require tank volume.
  /// It calculates the average pressure drop per minute adjusted for depth.
  double? get sacPressure {
```

with:

```dart
  /// SAC: surface air consumption as a tank-pressure drop rate, in bar/min
  /// at the surface, read from [sacReferenceTank] only.
  ///
  /// Needs no cylinder volume, so it exists for every dive-computer download
  /// that carries pressure. Not a unit conversion of [rmvFor] on multi-tank
  /// dives: bar/min from a 12 L back gas and a 7 L stage cannot be averaged.
  double? get sac {
```

Update the `sacReferenceTank` doc comment's first line from `/// The cylinder the pressure lane ([sacPressure]) reads, and the one whose` to `/// The cylinder the pressure lane ([sac]) reads, and the one whose`.

In `cylinder_sac.dart`, replace lines 31-38:

```dart
  /// SAC rate in L/min at surface (computed if tankVolume available).
  ///
  /// [sacRate] is bar/min against a 1 bar reference, so scaling it by the
  /// cylinder's size is the whole conversion. Dividing by the standard
  /// atmosphere as well shaved 1.3% off this readout while the dive's
  /// headline SAC used a different reference (issue #828).
  double? get sacVolume =>
      sacRate != null && tankVolume != null ? sacRate! * tankVolume! : null;
```

with:

```dart
  /// RMV for this cylinder in L/min at surface (computed if tankVolume
  /// available).
  ///
  /// [sacRate] is bar/min against a 1 bar reference, so scaling it by the
  /// cylinder's size is the whole conversion. Dividing by the standard
  /// atmosphere as well shaved 1.3% off this readout while the dive's
  /// headline value used a different reference (issue #828).
  double? get rmv =>
      sacRate != null && tankVolume != null ? sacRate! * tankVolume! : null;
```

- [ ] **Step 4: Rename the call sites in `lib/`**

```bash
perl -pi -e 's/\.sacFor\(/.rmvFor(/g; s/\bDive\.sacFor\b/Dive.rmvFor/g; s/\.sacPressure\b/.sac/g; s/\bDive\.sacPressure\b/Dive.sac/g; s/\.sacVolume\b/.rmv/g' \
  lib/core/constants/dive_field_extractor.dart lib/core/utils/unit_formatter.dart \
  lib/features/dive_log/presentation/pages/dive_detail_page.dart \
  lib/features/dive_log/presentation/utils/sac_normalization.dart \
  lib/features/dive_log/presentation/widgets/cylinders_card.dart
grep -rn "sacFor\|sacPressure\|sacVolume" lib/ || echo "no stale references in lib/"
```

In `sac_normalization.dart` the local variable `diveSacPressure` is untouched by the regex (it has no leading dot); rename it by hand to `diveSac` in its three uses so the file reads consistently.

- [ ] **Step 5: Run the renamed tests and analyze**

Run: `flutter test test/features/dive_log/domain/entities/ test/features/dive_log/data/services/gas_analysis_service_segment_sac_test.dart test/core/constants/dive_field_extractor_test.dart test/features/dive_log/presentation/widgets/cylinders_card_test.dart test/features/dive_log/presentation/pages/dive_detail_sac_row_test.dart`
Expected: all pass with unchanged numbers.

Run: `flutter analyze lib/features/dive_log lib/core/constants lib/core/utils`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
dart format lib/features/dive_log lib/core/constants/dive_field_extractor.dart lib/core/utils/unit_formatter.dart test/
git add -A lib/ test/
git commit -m "refactor(dive): name the lanes Dive.sac, Dive.rmvFor, CylinderSac.rmv"
```

---

### Task 3: The `GasConsumptionDisplay` and `GasConsumptionLane` enums

Spec: D2.

**Files:**
- Create: `lib/core/constants/gas_consumption_display.dart`
- Test: `test/core/constants/gas_consumption_display_test.dart`

**Interfaces:**
- Produces:

```dart
enum GasConsumptionLane { sac, rmv }
enum GasConsumptionDisplay {
  sac, rmv, both;
  bool get showsSac;
  bool get showsRmv;
  List<GasConsumptionLane> get lanes;         // render order, SAC first
  static GasConsumptionDisplay fromName(String? name);  // legacy-aware, unknown -> both
}
```

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';

void main() {
  group('GasConsumptionDisplay', () {
    test('sac shows only the pressure lane', () {
      expect(GasConsumptionDisplay.sac.showsSac, isTrue);
      expect(GasConsumptionDisplay.sac.showsRmv, isFalse);
      expect(GasConsumptionDisplay.sac.lanes, [GasConsumptionLane.sac]);
    });

    test('rmv shows only the volume lane', () {
      expect(GasConsumptionDisplay.rmv.showsSac, isFalse);
      expect(GasConsumptionDisplay.rmv.showsRmv, isTrue);
      expect(GasConsumptionDisplay.rmv.lanes, [GasConsumptionLane.rmv]);
    });

    test('both shows both lanes, SAC first', () {
      expect(GasConsumptionDisplay.both.showsSac, isTrue);
      expect(GasConsumptionDisplay.both.showsRmv, isTrue);
      expect(GasConsumptionDisplay.both.lanes, [
        GasConsumptionLane.sac,
        GasConsumptionLane.rmv,
      ]);
    });

    test('fromName resolves current names', () {
      for (final value in GasConsumptionDisplay.values) {
        expect(GasConsumptionDisplay.fromName(value.name), value);
      }
    });

    test('fromName maps the retired SacUnit spellings onto their lane', () {
      // A stored 'litersPerMin' was the volume lane; 'pressurePerMin' the
      // pressure lane. Both can still arrive from a peer on an older build.
      expect(
        GasConsumptionDisplay.fromName('litersPerMin'),
        GasConsumptionDisplay.rmv,
      );
      expect(
        GasConsumptionDisplay.fromName('pressurePerMin'),
        GasConsumptionDisplay.sac,
      );
    });

    test('fromName falls back to both for anything else', () {
      expect(GasConsumptionDisplay.fromName(null), GasConsumptionDisplay.both);
      expect(GasConsumptionDisplay.fromName(''), GasConsumptionDisplay.both);
      expect(
        GasConsumptionDisplay.fromName('nonsense'),
        GasConsumptionDisplay.both,
      );
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/constants/gas_consumption_display_test.dart`
Expected: compile error, the import target does not exist.

- [ ] **Step 3: Write the enums**

`lib/core/constants/gas_consumption_display.dart`:

```dart
/// Which gas-consumption lane a value belongs to.
///
/// SAC is a tank-pressure drop rate (bar/min or psi/min) read from one
/// reference cylinder. RMV is the surface gas volume breathed per minute
/// (L/min or cuft/min) summed across every cylinder with a volume. They are
/// not unit conversions of each other on multi-tank dives (discussions #354
/// and #803).
enum GasConsumptionLane { sac, rmv }

/// Which lanes the single-value surfaces (detail summary, list cards, chart
/// tooltip, statistics) show. Replaces the retired SacUnit preference, which
/// treated the two lanes as one value with a unit toggle.
enum GasConsumptionDisplay {
  sac,
  rmv,
  both;

  bool get showsSac => this != rmv;
  bool get showsRmv => this != sac;

  /// Lanes in render order; SAC first when both are shown.
  List<GasConsumptionLane> get lanes => [
    if (showsSac) GasConsumptionLane.sac,
    if (showsRmv) GasConsumptionLane.rmv,
  ];

  /// Resolves a stored or synced name. The two retired SacUnit spellings map
  /// onto the lane they meant so a value written by an older build keeps the
  /// diver on the lane they were seeing; anything else lands on [both].
  static GasConsumptionDisplay fromName(String? name) => switch (name) {
    'sac' || 'pressurePerMin' => sac,
    'rmv' || 'litersPerMin' => rmv,
    _ => both,
  };
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/core/constants/gas_consumption_display_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/core/constants/gas_consumption_display.dart test/core/constants/gas_consumption_display_test.dart
git add lib/core/constants/gas_consumption_display.dart test/core/constants/gas_consumption_display_test.dart
git commit -m "feat(units): add GasConsumptionDisplay and GasConsumptionLane"
```

---

### Task 4: The preference in `AppSettings`, with a transitional `sacUnit` shim

Spec: D3 and D6 (wizard half). The `SacUnit` enum and every reader of `settings.sacUnit` / `sacUnitProvider` / `setSacUnit` keep compiling through a derived shim; Tasks 6-13 move each surface onto the new API and Task 14 deletes the shim.

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart:57,127,478,639,766,1284-1287,1991-1993`
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart:85,248,453,624-629`
- Modify: `lib/features/setup_wizard/presentation/widgets/steps/units_step.dart:152-160`
- Modify: `lib/features/setup_wizard/data/setup_apply_service.dart:67`
- Modify (tests that construct `AppSettings(sacUnit:)` or override `setSacUnit`): `test/helpers/mock_providers.dart:61`, `test/features/settings/presentation/pages/settings_page_test.dart:112`, `test/features/settings/presentation/pages/settings_page_shared_data_test.dart:246`, `test/features/statistics/presentation/pages/records_page_test.dart:101`, `test/core/utils/unit_formatter_sac_test.dart`, `test/core/constants/dive_field_formatter_test.dart`, `test/features/dive_log/presentation/widgets/dive_table_view_test.dart`, `test/features/dive_log/presentation/pages/dive_list_tile_sac_test.dart`, `test/features/dive_log/presentation/pages/dive_detail_sac_row_test.dart`, `test/features/dive_log/presentation/pages/dive_detail_sac_segments_hint_test.dart`, `test/features/setup_wizard/presentation/widgets/steps/units_step_test.dart`, `test/features/setup_wizard/domain/setup_wizard_models_test.dart`, `test/features/settings/gas_model_notifier_test.dart`
- Test (new): `test/features/settings/app_settings_gas_consumption_test.dart`

**Interfaces:**
- Produces: `AppSettings.gasConsumptionDisplay` (default `GasConsumptionDisplay.both`), `AppSettings.copyWith({GasConsumptionDisplay? gasConsumptionDisplay})`, `SettingsNotifier.setGasConsumptionDisplay(GasConsumptionDisplay)`, `gasConsumptionDisplayProvider` (`Provider<GasConsumptionDisplay>`).
- Transitional (deleted in Task 14): `AppSettings.sacUnit` getter derived from the display (`rmv -> litersPerMin`, otherwise `pressurePerMin`), `SettingsNotifier.setSacUnit` forwarding to `setGasConsumptionDisplay`, `sacUnitProvider` selecting the derived getter.
- Consumes: `GasConsumptionDisplay.fromName` (Task 3).

- [ ] **Step 1: Write the failing test**

`test/features/settings/app_settings_gas_consumption_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The gas-consumption display preference replaces the SAC unit toggle
/// (spec D3). New installs show both lanes.
void main() {
  test('defaults to both', () {
    expect(
      const AppSettings().gasConsumptionDisplay,
      GasConsumptionDisplay.both,
    );
  });

  test('copyWith replaces the display and leaves the rest alone', () {
    const before = AppSettings(volumeUnit: VolumeUnit.cubicFeet);
    final after = before.copyWith(
      gasConsumptionDisplay: GasConsumptionDisplay.rmv,
    );
    expect(after.gasConsumptionDisplay, GasConsumptionDisplay.rmv);
    expect(after.volumeUnit, VolumeUnit.cubicFeet);
    expect(before.gasConsumptionDisplay, GasConsumptionDisplay.both);
  });

  test('the transitional sacUnit shim mirrors the display', () {
    // Removed in the last task of the split; until then every surface that
    // still reads sacUnit must see the lane the diver chose.
    expect(
      const AppSettings(gasConsumptionDisplay: GasConsumptionDisplay.rmv)
          .sacUnit,
      SacUnit.litersPerMin,
    );
    expect(
      const AppSettings(gasConsumptionDisplay: GasConsumptionDisplay.sac)
          .sacUnit,
      SacUnit.pressurePerMin,
    );
    expect(
      const AppSettings(gasConsumptionDisplay: GasConsumptionDisplay.both)
          .sacUnit,
      SacUnit.pressurePerMin,
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/settings/app_settings_gas_consumption_test.dart`
Expected: compile error, `No named parameter with the name 'gasConsumptionDisplay'`.

- [ ] **Step 3: Change `AppSettings`**

In `settings_providers.dart` add the import `import 'package:submersion/core/constants/gas_consumption_display.dart';` next to the `units.dart` import.

Line 57: delete `static const String sacUnit = 'sac_unit';` (never referenced).

Line 127, replace `final SacUnit sacUnit;` with:

```dart
  /// Which gas-consumption lanes the single-value surfaces show: SAC
  /// (tank-pressure rate), RMV (surface volume rate), or both. Replaces the
  /// SAC unit toggle; each lane now has a fixed unit family.
  final GasConsumptionDisplay gasConsumptionDisplay;

  /// Transitional: the lane a surface that still forks on [SacUnit] should
  /// read. Removed once every surface renders through [gasConsumptionDisplay].
  SacUnit get sacUnit => gasConsumptionDisplay == GasConsumptionDisplay.rmv
      ? SacUnit.litersPerMin
      : SacUnit.pressurePerMin;
```

Line 478, replace `this.sacUnit = SacUnit.pressurePerMin,` with `this.gasConsumptionDisplay = GasConsumptionDisplay.both,`.

Line 639 (copyWith parameters), replace `SacUnit? sacUnit,` with `GasConsumptionDisplay? gasConsumptionDisplay,`.

Line 766 (copyWith body), replace `sacUnit: sacUnit ?? this.sacUnit,` with `gasConsumptionDisplay: gasConsumptionDisplay ?? this.gasConsumptionDisplay,`.

Lines 1284-1287, replace the `setSacUnit` method with:

```dart
  Future<void> setGasConsumptionDisplay(GasConsumptionDisplay display) async {
    state = state.copyWith(gasConsumptionDisplay: display);
    await _saveSettings();
  }

  /// Transitional forwarder for surfaces not yet moved off [SacUnit].
  Future<void> setSacUnit(SacUnit unit) => setGasConsumptionDisplay(
    unit == SacUnit.litersPerMin
        ? GasConsumptionDisplay.rmv
        : GasConsumptionDisplay.sac,
  );
```

Lines 1991-1993, replace the `sacUnitProvider` block with:

```dart
final gasConsumptionDisplayProvider = Provider<GasConsumptionDisplay>((ref) {
  return ref.watch(settingsProvider.select((s) => s.gasConsumptionDisplay));
});

/// Transitional; removed with the SacUnit shim.
final sacUnitProvider = Provider<SacUnit>((ref) {
  return ref.watch(settingsProvider.select((s) => s.sacUnit));
});
```

- [ ] **Step 4: Change the repository**

In `diver_settings_repository.dart` add `import 'package:submersion/core/constants/gas_consumption_display.dart';`.

Lines 85 and 248: replace `sacUnit: Value(s.sacUnit.name),` with `sacUnit: Value(s.gasConsumptionDisplay.name),` and `sacUnit: Value(settings.sacUnit.name),` with `sacUnit: Value(settings.gasConsumptionDisplay.name),`. (The Drift column is still `sacUnit` until Task 5 renames it; the stored strings become `sac` / `rmv` / `both`.)

Line 453: replace `sacUnit: _parseSacUnit(row.sacUnit),` with `gasConsumptionDisplay: GasConsumptionDisplay.fromName(row.sacUnit),`.

Delete the `_parseSacUnit` method (lines 624-629). `fromName` already maps the two legacy spellings and falls back to `both`.

- [ ] **Step 5: Change the setup wizard**

`units_step.dart:152-160`, replace the `_unitRow<SacUnit>` block with:

```dart
              _unitRow<GasConsumptionDisplay>(
                label: l10n.setup_units_gasConsumption,
                keyPrefix: 'setup-unit-gasconsumption',
                values: GasConsumptionDisplay.values,
                selected: s.gasConsumptionDisplay,
                symbol: (d) => switch (d) {
                  GasConsumptionDisplay.sac => l10n.gasConsumption_sac,
                  GasConsumptionDisplay.rmv => l10n.gasConsumption_rmv,
                  GasConsumptionDisplay.both =>
                    l10n.settings_units_gasConsumption_both,
                },
                onChanged: (d) => notifier.updateSettings(
                  s.copyWith(gasConsumptionDisplay: d),
                ),
              ),
```

and add `import 'package:submersion/core/constants/gas_consumption_display.dart';`. The segment keys derived by `_segmentKey` become `setup-unit-gasconsumption-sac`, `-rmv`, `-both` in English.

`setup_apply_service.dart:67`: replace `await notifier.setSacUnit(s.sacUnit);` with `await notifier.setGasConsumptionDisplay(s.gasConsumptionDisplay);`.

- [ ] **Step 6: Update the tests that construct or mock the old field**

In every file listed under Files above, apply these mechanical edits (read each file first; the named argument `sacUnit:` also appears on `extractFromDive`, `CylindersCard`, and `RangeStatsPanel` calls, which must NOT change in this task):

1. Inside `AppSettings(...)` constructors only: `sacUnit: SacUnit.litersPerMin` becomes `gasConsumptionDisplay: GasConsumptionDisplay.rmv`; `sacUnit: SacUnit.pressurePerMin` becomes `gasConsumptionDisplay: GasConsumptionDisplay.sac`. Add the `gas_consumption_display.dart` import to each file.
2. In the four mock notifiers (`mock_providers.dart`, `settings_page_test.dart`, `settings_page_shared_data_test.dart`, `records_page_test.dart`), replace the `setSacUnit` override with:

```dart
  @override
  Future<void> setGasConsumptionDisplay(GasConsumptionDisplay display) async =>
      state = state.copyWith(gasConsumptionDisplay: display);
  @override
  Future<void> setSacUnit(SacUnit unit) => setGasConsumptionDisplay(
    unit == SacUnit.litersPerMin
        ? GasConsumptionDisplay.rmv
        : GasConsumptionDisplay.sac,
  );
```

3. `units_step_test.dart:143-153`: `await tapUnit('setup-unit-sac-pressuremin');` becomes `await tapUnit('setup-unit-gasconsumption-sac');` and `expect(s.sacUnit, SacUnit.pressurePerMin);` becomes `expect(s.gasConsumptionDisplay, GasConsumptionDisplay.sac);`.
4. `gas_model_notifier_test.dart:100-101`: `.sacUnit` becomes `.gasConsumptionDisplay` on both lines.
5. `setup_wizard_models_test.dart`: `grep -n "sacUnit\|SacUnit"` and convert each hit by rules 1 and 4.
6. Widget tests whose *expectations* assert lane text (`'1.0 bar/min'`, `'9.3 L/min'`, and so on) keep those expectations: the shim reproduces the old rendering until each surface's own task changes it.

Then confirm nothing in `test/` still names the constructor parameter:

```bash
grep -rn "AppSettings(" test/ | grep -c "sacUnit" ; grep -rn "sacUnit: SacUnit" test/ | grep -v "extractFromDive\|CylindersCard\|RangeStatsPanel\|_buildCard\|sacUnit: sacUnit" || echo "only widget-parameter uses remain"
```

- [ ] **Step 7: Run the affected tests and analyze**

Run: `flutter test test/features/settings/ test/core/utils/unit_formatter_sac_test.dart test/core/constants/dive_field_formatter_test.dart test/features/dive_log/presentation/widgets/dive_table_view_test.dart test/features/dive_log/presentation/pages/dive_list_tile_sac_test.dart test/features/dive_log/presentation/pages/dive_detail_sac_row_test.dart test/features/dive_log/presentation/pages/dive_detail_sac_segments_hint_test.dart test/features/setup_wizard/ test/features/statistics/presentation/pages/records_page_test.dart`
Expected: all pass.

Run: `flutter analyze lib/features/settings lib/features/setup_wizard`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
dart format lib/features/settings lib/features/setup_wizard test/
git add -A lib/ test/
git commit -m "feat(settings): gas consumption display preference with a transitional SacUnit shim"
```

---

### Task 5: Schema v170, the compatibility floor, and the sync wire key

Spec: D4 and D5.

**Files:**
- Modify: `lib/core/database/database.dart:1611-1612` (column), `:3183` (`currentSchemaVersion`), `:3211` (`minimumCompatibleSchemaVersion` and its doc), `:3479` (end of `migrationVersions`), `:8611-8615` (`onUpgrade` tail), `:8823` (end of the `beforeOpen` backstops), plus two new helpers next to `_assertServiceCategoryRename` (`:5021`)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart:85,248,453`
- Modify: `lib/core/services/sync/sync_data_serializer.dart:5470-5472` (`_renamedWireKeys`), `:5576` (defaults map), `:5713` (defaults return)
- Modify: `test/core/database/migration_v160_service_category_test.dart:196`
- Create: `test/core/database/migration_v170_gas_consumption_display_test.dart`, `test/core/services/sync/legacy_sac_unit_key_test.dart`
- Test: `test/core/services/sync/sync_schema_defaults_replay_test.dart`, `test/core/services/sync/cross_version_roundtrip_test.dart`, `test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart`

**Interfaces:**
- Produces: Drift column `DiverSettings.gasConsumptionDisplay` (SQL `gas_consumption_display TEXT NOT NULL DEFAULT 'both'`), `AppDatabase.currentSchemaVersion == 170`, `AppDatabase.minimumCompatibleSchemaVersion == 170`, helpers `_assertGasConsumptionDisplayColumn()` and `_rewriteLegacySacRateLayouts()`.
- Wire: outbound diver-settings rows carry `gasConsumptionDisplay`; inbound `sacUnit` is renamed and its two legacy values mapped.

- [ ] **Step 1: Re-verify the rung**

```bash
git fetch -q origin
git grep -h -o 'currentSchemaVersion = [0-9]*' origin/main -- lib/core/database/database.dart
for n in $(gh pr list --state open --json number --jq '.[].number'); do v=$(gh pr diff $n 2>/dev/null | grep -E '^\+\s*static const int currentSchemaVersion' | grep -o '[0-9]*;' | tr -d ';'); [ -n "$v" ] && echo "PR #$n -> v$v"; done
```

As of 2026-08-26: main 164; open PRs claim 165, 166, 167, 168 (#1237, pushed); the dive-computer-gear-twin worktree took 169 the same evening. If anything now claims 170, use the next free number everywhere below and in the test filename.

- [ ] **Step 2: Write the failing migration test**

`test/core/database/migration_v170_gas_consumption_display_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v170 renames diver_settings.sac_unit to gas_consumption_display, maps its
/// unit spellings onto lanes, and points saved dive-table layouts that named
/// the old sacRate column at the lane the diver was seeing (spec D4).
///
/// Stamped at 169 so only this rung runs; 165-169 belong to other branches.
NativeDatabase _dbAt169() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 169');
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT NOT NULL,
          sac_unit TEXT NOT NULL DEFAULT 'litersPerMin',
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');
      rawDb.execute('''
        CREATE TABLE view_configs (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT NOT NULL,
          view_mode TEXT NOT NULL,
          config_json TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          hlc TEXT
        )
      ''');
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id, sac_unit) VALUES "
        "('ds-vol', 'd-vol', 'litersPerMin'), "
        "('ds-prs', 'd-prs', 'pressurePerMin'), "
        "('ds-odd', 'd-odd', 'furlongs')",
      );
      const layout =
          '{"columns":[{"field":"diveNumber"},{"field":"sacRate"}],'
          '"sortField":"sacRate"}';
      rawDb.execute(
        "INSERT INTO view_configs (id, diver_id, view_mode, config_json, "
        "updated_at, hlc) VALUES "
        "('vc-vol', 'd-vol', 'table', '$layout', 1, 'h-vol'), "
        "('vc-prs', 'd-prs', 'table', '$layout', 1, 'h-prs'), "
        "('vc-odd', 'd-odd', 'table', '$layout', 1, 'h-odd')",
      );
    },
  );
}

Future<String> _display(AppDatabase db, String id) async {
  final row = await db
      .customSelect(
        "SELECT gas_consumption_display AS d FROM diver_settings "
        "WHERE id = '$id'",
      )
      .getSingle();
  return row.read<String>('d');
}

Future<({String json, String? hlc})> _layout(AppDatabase db, String id) async {
  final row = await db
      .customSelect(
        "SELECT config_json, hlc FROM view_configs WHERE id = '$id'",
      )
      .getSingle();
  return (json: row.read<String>('config_json'), hlc: row.read<String?>('hlc'));
}

void main() {
  test('v170 is in the migration ladder and is the compatibility floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(170));
    expect(AppDatabase.migrationVersions, contains(170));
    // Renaming a synced column and changing its value set are both breaking
    // under the #1089 rules, so peers below 170 are held until they update.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 170);
  });

  test('a fresh database has gas_consumption_display defaulting to both', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final byName = {for (final c in cols) c.read<String>('name'): c};
    expect(byName.containsKey('gas_consumption_display'), isTrue);
    expect(byName.containsKey('sac_unit'), isFalse);
    expect(byName['gas_consumption_display']!.read<String?>('dflt_value'),
        contains('both'));
  });

  test('the 169 -> 170 upgrade renames the column and maps the values', () async {
    final db = AppDatabase(_dbAt169());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('gas_consumption_display'));
    expect(names, isNot(contains('sac_unit')));

    expect(await _display(db, 'ds-vol'), 'rmv');
    expect(await _display(db, 'ds-prs'), 'sac');
    // An unrecognized value cannot fail the migration; it lands on both.
    expect(await _display(db, 'ds-odd'), 'both');
  });

  test('saved layouts follow the lane the diver was on, without an HLC bump', () async {
    final db = AppDatabase(_dbAt169());
    addTearDown(db.close);

    final vol = await _layout(db, 'vc-vol');
    expect(vol.json, '{"columns":[{"field":"diveNumber"},{"field":"rmv"}],'
        '"sortField":"rmv"}');
    expect(vol.hlc, 'h-vol');

    final prs = await _layout(db, 'vc-prs');
    expect(prs.json, contains('"field":"sac"'));
    expect(prs.json, contains('"sortField":"sac"'));
    expect(prs.json, isNot(contains('sacRate')));
    expect(prs.hlc, 'h-prs');

    // The unknown-value diver landed on both; their old column shows SAC.
    final odd = await _layout(db, 'vc-odd');
    expect(odd.json, contains('"field":"sac"'));
    expect(odd.hlc, 'h-odd');
  });

  test('the column assert is idempotent and heals a stranded database', () async {
    // A database that reached 170 by restore or sync-adopt never runs
    // onUpgrade; beforeOpen re-asserts the rename. Opening twice proves the
    // assert does not try to rename or add twice.
    final native = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('''
          CREATE TABLE diver_settings (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT NOT NULL,
            sac_unit TEXT NOT NULL DEFAULT 'litersPerMin',
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
        rawDb.execute(
          "INSERT INTO diver_settings (id, diver_id, sac_unit) "
          "VALUES ('ds1', 'd1', 'litersPerMin')",
        );
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    expect(await _display(db, 'ds1'), 'rmv');
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toList();
    expect(names.where((n) => n == 'gas_consumption_display').length, 1);
  });

  test('the asserts no-op when the tables are absent', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('CREATE TABLE unrelated (id TEXT)'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v170_gas_consumption_display_test.dart`
Expected: the ladder test fails (`currentSchemaVersion` is 164), and the fresh-database test fails on `sac_unit` still existing.

- [ ] **Step 4: Change the Drift table**

`database.dart:1611-1612`, replace:

```dart
  TextColumn get sacUnit =>
      text().withDefault(const Constant('litersPerMin'))();
```

with:

```dart
  /// v170: renamed from sacUnit. Holds a GasConsumptionDisplay name (sac,
  /// rmv, both). The Drift getter name is also the sync wire key, so this
  /// rename raises minimumCompatibleSchemaVersion; see
  /// SyncDataSerializer._renamedWireKeys for the receiving-side tolerance.
  TextColumn get gasConsumptionDisplay =>
      text().withDefault(const Constant('both'))();
```

Run `dart run build_runner build --delete-conflicting-outputs` (the generated row class gains `gasConsumptionDisplay` and loses `sacUnit`).

- [ ] **Step 5: Point the repository at the renamed column**

`diver_settings_repository.dart`: lines 85 and 248 become `gasConsumptionDisplay: Value(s.gasConsumptionDisplay.name),` and `gasConsumptionDisplay: Value(settings.gasConsumptionDisplay.name),`; line 453 becomes `gasConsumptionDisplay: GasConsumptionDisplay.fromName(row.gasConsumptionDisplay),`.

- [ ] **Step 6: Bump the ladder and the floor**

`database.dart:3183`: `static const int currentSchemaVersion = 170;`

`database.dart:3211`: `static const int minimumCompatibleSchemaVersion = 170;` and append to its doc comment, after the "Raised 137 -> 160" paragraph:

```dart
  ///
  /// Raised 160 -> 170 by the SAC/RMV split: v170 renames the synced column
  /// diver_settings.sac_unit to gas_consumption_display and replaces its
  /// unit spellings with lane names, which the first two rules classify as
  /// breaking. Peers below 170 are held until they update. Their payloads
  /// still arrive here; _renamedWireKeys plus the value map in
  /// _applyDiverSettingDefaults carry the receiving-side tolerance.
```

`database.dart:3479`, after the `164,` entry and before `];`:

```dart
    // v170: diver_settings.sac_unit -> gas_consumption_display (a lane
    // choice: sac, rmv, both) plus the rewrite of saved dive-table layouts
    // that named the old sacRate column (discussions #354, #803). 165-169
    // are deliberately absent, not missing: they were claimed by open PRs
    // when this branch was cut.
    170,
```

- [ ] **Step 7: Add the two helpers**

Directly after `_assertServiceCategoryRename` (ends near `database.dart:5036`):

```dart
  /// v170: diver_settings.sac_unit becomes gas_consumption_display and its
  /// values move from a unit choice to a lane choice (discussions #354 and
  /// #803). Guarded like the v160 rename, so a database that reaches 170 by
  /// restore or sync-adopt (neither runs onUpgrade) heals in beforeOpen. The
  /// value rewrite is idempotent: it only touches the two retired spellings
  /// and anything that is not a known lane name.
  Future<void> _assertGasConsumptionDisplayColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('sac_unit') &&
        !names.contains('gas_consumption_display')) {
      await customStatement(
        'ALTER TABLE diver_settings '
        'RENAME COLUMN sac_unit TO gas_consumption_display',
      );
    } else if (!names.contains('gas_consumption_display')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN gas_consumption_display '
        "TEXT NOT NULL DEFAULT 'both'",
      );
      return;
    }
    await customStatement(
      'UPDATE diver_settings SET gas_consumption_display = '
      'CASE gas_consumption_display '
      "WHEN 'litersPerMin' THEN 'rmv' "
      "WHEN 'pressurePerMin' THEN 'sac' "
      "WHEN 'sac' THEN 'sac' WHEN 'rmv' THEN 'rmv' WHEN 'both' THEN 'both' "
      "ELSE 'both' END "
      "WHERE gas_consumption_display NOT IN ('sac', 'rmv', 'both')",
    );
  }

  /// v170, rung only: a saved dive-table layout names its columns by enum
  /// value, and the sacRate column split into sac and rmv. Point each
  /// diver's layout at the lane they were seeing. Runs after
  /// [_assertGasConsumptionDisplayColumn] so the lane names are final.
  ///
  /// Never called from beforeOpen: DiveFieldAdapter.fieldFromName aliases
  /// sacRate to sac for layouts that arrive later by sync, and re-running
  /// this on every open would rewrite rows the diver has since changed. No
  /// HLC bump: every device applies the same deterministic rewrite to its
  /// own rows, so there is nothing to push.
  Future<void> _rewriteLegacySacRateLayouts() async {
    final tables = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name IN ('view_configs', 'diver_settings')",
    ).get();
    if (tables.length < 2) return;
    await customStatement('''
      UPDATE view_configs
        SET config_json = REPLACE(config_json, '"sacRate"', '"rmv"')
        WHERE config_json LIKE '%"sacRate"%'
          AND diver_id IN (SELECT diver_id FROM diver_settings
                           WHERE gas_consumption_display = 'rmv')
    ''');
    await customStatement('''
      UPDATE view_configs
        SET config_json = REPLACE(config_json, '"sacRate"', '"sac"')
        WHERE config_json LIKE '%"sacRate"%'
    ''');
  }
```

- [ ] **Step 8: Wire the rung and the backstop**

`database.dart` `onUpgrade`, after the `if (from < 164) await reportProgress();` line:

```dart
        // v170: diver_settings.sac_unit -> gas_consumption_display and the
        // saved dive-table layouts that named the old sacRate column
        // (discussions #354, #803).
        if (from < 170) {
          await _assertGasConsumptionDisplayColumn();
          await _rewriteLegacySacRateLayouts();
        }
        if (from < 170) await reportProgress();
```

`beforeOpen`, after the v164 backstop (`await _assertMediaManualElapsedColumn();`):

```dart
        // v170 backstop: re-assert the diver_settings.sac_unit rename and
        // value map (discussions #354, #803; same restore / sync-adopt
        // self-heal as v160). The layout rewrite deliberately stays rung-only.
        await _assertGasConsumptionDisplayColumn();
```

- [ ] **Step 9: Sync serializer**

`sync_data_serializer.dart:5470-5472`, replace the `_renamedWireKeys` map with:

```dart
  static const Map<String, Map<String, String>> _renamedWireKeys = {
    'serviceRecords': {'serviceType': 'serviceCategory'},
    // v170: the SAC unit toggle became the gas-consumption display. The value
    // is remapped in _applyDiverSettingDefaults.
    'diverSettings': {'sacUnit': 'gasConsumptionDisplay'},
  };
```

Line 5576: replace `'sacUnit': 'litersPerMin',` with `'gasConsumptionDisplay': 'both',`.

Line 5713: replace `return merged;` with:

```dart
    // A pre-170 peer spells the value as a unit. _withRenamedKeys moved the
    // key; the value still needs the lane it meant.
    const legacyLanes = {'litersPerMin': 'rmv', 'pressurePerMin': 'sac'};
    final display = merged['gasConsumptionDisplay'];
    if (display is String && legacyLanes.containsKey(display)) {
      merged['gasConsumptionDisplay'] = legacyLanes[display];
    }
    return merged;
```

(`merged` is the local map literal the method builds; check that it is not `const` where you insert, and if the method assigns into it elsewhere keep that style.)

- [ ] **Step 10: Write the legacy-key sync test**

`test/core/services/sync/legacy_sac_unit_key_test.dart`:

```dart
// A peer or backup written before v170 keys the consumption preference as
// 'sacUnit' with a unit spelling. Raising minimumCompatibleSchemaVersion
// stops OLD readers applying OUR payloads, but the gate is one-directional,
// so their payloads still arrive here and must land on the lane they meant.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    // FK enforcement off so a placeholder diver_id needn't reference a real
    // diver; this only exercises the settings serialization path.
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// A wire-format settings row as this build exports it, minus the new key.
  Future<Map<String, dynamic>> legacyRecord(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: id,
            diverId: 'diver-$id',
            createdAt: now,
            updatedAt: now,
            gasConsumptionDisplay: const Value('both'),
          ),
        );
    final exported = await serializer.fetchRecord('diverSettings', id);
    expect(exported, isNotNull);
    await (db.delete(db.diverSettings)..where((t) => t.id.equals(id))).go();
    return Map<String, dynamic>.from(exported!)..remove('gasConsumptionDisplay');
  }

  Future<String> displayOf(String id) async {
    final row = await (db.select(
      db.diverSettings,
    )..where((t) => t.id.equals(id))).getSingle();
    return row.gasConsumptionDisplay;
  }

  test('an old peer on L/min lands on the RMV lane', () async {
    await serializer.upsertRecord('diverSettings', {
      ...await legacyRecord('ds-vol'),
      'sacUnit': 'litersPerMin',
    });
    expect(await displayOf('ds-vol'), 'rmv');
  });

  test('an old peer on pressure/min lands on the SAC lane', () async {
    await serializer.upsertRecord('diverSettings', {
      ...await legacyRecord('ds-prs'),
      'sacUnit': 'pressurePerMin',
    });
    expect(await displayOf('ds-prs'), 'sac');
  });

  test('the batched path maps the value too', () async {
    await serializer.upsertRecords('diverSettings', [
      {...await legacyRecord('ds-batch'), 'sacUnit': 'litersPerMin'},
    ]);
    expect(await displayOf('ds-batch'), 'rmv');
  });

  test('a current payload keyed gasConsumptionDisplay applies as is', () async {
    await serializer.upsertRecord('diverSettings', {
      ...await legacyRecord('ds-new'),
      'gasConsumptionDisplay': 'sac',
    });
    expect(await displayOf('ds-new'), 'sac');
  });

  test('a payload with neither key hydrates to both', () async {
    await serializer.upsertRecord('diverSettings', await legacyRecord('ds-none'));
    expect(await displayOf('ds-none'), 'both');
  });

  test('a payload carrying both keys prefers the current spelling', () async {
    await serializer.upsertRecord('diverSettings', {
      ...await legacyRecord('ds-both'),
      'sacUnit': 'litersPerMin',
      'gasConsumptionDisplay': 'sac',
    });
    expect(await displayOf('ds-both'), 'sac');
  });
}
```

- [ ] **Step 11: Update the v160 floor pin and run the database and sync tests**

`test/core/database/migration_v160_service_category_test.dart:196`: the test `'the compatibility floor records the rename'` pins the floor to exactly 160. Change the matcher to `greaterThanOrEqualTo(160)` and its reason to `'renaming a synced column is breaking under the #1089 rules; later renames may raise it further'`.

Run: `flutter test test/core/database/ test/core/services/sync/legacy_sac_unit_key_test.dart test/core/services/sync/legacy_service_key_test.dart test/core/services/sync/sync_schema_defaults_replay_test.dart test/core/services/sync/sync_diver_settings_fallback_test.dart test/core/services/sync/cross_version_roundtrip_test.dart test/core/services/sync/changeset_log/ test/features/settings/`
Expected: all pass. If `cross_version_roundtrip_test.dart` or any test enumerates diver-settings wire keys and now finds `gasConsumptionDisplay` where it expected `sacUnit`, update that expectation; the header comment of the round-trip test asks for a projection note when the floor moves, so add one sentence there: `The floor moved 160 -> 170 with the SAC/RMV split (diver_settings.sac_unit -> gas_consumption_display); legacy_sac_unit_key_test.dart covers the inbound direction.`

Run: `flutter analyze lib/core/database lib/core/services/sync lib/features/settings`
Expected: `No issues found!`

- [ ] **Step 12: Commit**

```bash
dart format lib/core/database/database.dart lib/core/services/sync/sync_data_serializer.dart lib/features/settings test/core
git add lib/core/database/database.dart lib/core/services/sync/sync_data_serializer.dart lib/features/settings/data/repositories/diver_settings_repository.dart test/core/database/ test/core/services/sync/
git commit -m "feat(db): v170 renames diver_settings.sac_unit to gas_consumption_display"
```

---

### Task 6: The formatting layer and the dive-table lane split

Spec: D7 and D9 (dive table, list cards). One task because `DiveFieldFormatter` depends on the formatter members and the intermediate state (pressure-only `convertSac` feeding an L/min column) would render wrong.

**Files:**
- Modify: `lib/core/utils/unit_formatter.dart:248-270`
- Modify: `lib/core/constants/dive_field.dart:65,179,293-294,415-416,507,570,653-654`
- Modify: `lib/core/constants/dive_field_extractor.dart:1-40,97-98,212-220`
- Modify: `lib/core/constants/dive_field_formatter.dart:37-44`
- Modify: `lib/core/constants/dive_field_column_sizing.dart:67-68,189-190`
- Modify: `lib/features/dive_log/domain/constants/dive_field_adapter.dart:60,127-130`
- Modify: `lib/features/dive_log/domain/entities/view_field_config.dart:76,303`
- Modify: `lib/features/dive_log/presentation/widgets/dive_table_view.dart:138-147,217,247-251`
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart:1079-1083,1231-1236`
- Test: `test/core/utils/unit_formatter_sac_test.dart` (rewrite), `test/core/constants/dive_field_test.dart`, `test/core/constants/dive_field_extractor_test.dart`, `test/core/constants/dive_field_extractor_gas_model_test.dart` (rewrite), `test/core/constants/dive_field_formatter_test.dart`, `test/features/dive_log/domain/constants/dive_field_adapter_test.dart`, `test/features/dive_log/domain/entities/view_field_config_test.dart`, `test/features/dive_log/presentation/widgets/dive_table_view_test.dart`, `test/features/dive_log/presentation/pages/dive_list_tile_sac_test.dart` (rewrite)

**Interfaces:**
- Produces on `UnitFormatter`: `String get sacSymbol` (`bar/min` | `psi/min`), `String get rmvSymbol` (`L/min` | `cuft/min`), `double convertSac(double barPerMin)`, `double convertRmv(double litersPerMin)`, `String formatSac(double barPerMin)` (1 decimal for bar, 0 for psi), `String formatRmv(double litersPerMin)` (1 decimal for L, 2 for cuft). Removes `UnitFormatter.sacUnit`.
- Produces `DiveField.sac` and `DiveField.rmv` (replacing `DiveField.sacRate`); `extractFromDive` loses its `sacUnit` parameter; `DiveFieldAdapter.fieldFromName('sacRate')` resolves to `DiveField.sac`.
- Consumes: `Dive.sac`, `Dive.rmvFor` (Task 2); `GasConsumptionDisplay` (Task 3, only in tests).

- [ ] **Step 1: Rewrite the formatter test**

Replace the whole of `test/core/utils/unit_formatter_sac_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Each consumption lane has a fixed unit family (spec D7): SAC follows the
/// pressure unit, RMV follows the volume unit, and neither reads the display
/// preference.
void main() {
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
    ),
  );

  group('SAC lane', () {
    test('sacSymbol follows the pressure unit', () {
      expect(metric.sacSymbol, 'bar/min');
      expect(imperial.sacSymbol, 'psi/min');
    });

    test('convertSac converts bar/min to the pressure unit', () {
      expect(metric.convertSac(1.5), closeTo(1.5, 1e-4));
      expect(imperial.convertSac(1.5), closeTo(21.7557, 1e-3));
    });

    test('formatSac uses one decimal for bar and none for psi', () {
      // psi/min values run in the hundreds; a decimal there is noise.
      expect(metric.formatSac(1.47), '1.5 bar/min');
      expect(imperial.formatSac(1.47), '21 psi/min');
    });
  });

  group('RMV lane', () {
    test('rmvSymbol follows the volume unit', () {
      expect(metric.rmvSymbol, 'L/min');
      expect(imperial.rmvSymbol, 'cuft/min');
    });

    test('convertRmv converts L/min to the volume unit', () {
      expect(metric.convertRmv(15.0), closeTo(15.0, 1e-4));
      expect(imperial.convertRmv(15.0), closeTo(0.5297, 1e-3));
    });

    test('formatRmv uses one decimal for liters and two for cubic feet', () {
      // cuft/min values sit below 1; one decimal renders every imperial
      // RMV as 0.5 or 0.6 (the unit_axis lesson).
      expect(metric.formatRmv(16.77), '16.8 L/min');
      expect(imperial.formatRmv(16.77), '0.59 cuft/min');
    });
  });

  test('the lanes ignore the display preference', () {
    const rmvOnly = UnitFormatter(
      AppSettings(gasConsumptionDisplay: GasConsumptionDisplay.rmv),
    );
    expect(rmvOnly.sacSymbol, 'bar/min');
    expect(rmvOnly.rmvSymbol, 'L/min');
  });
}
```

Run: `flutter test test/core/utils/unit_formatter_sac_test.dart`
Expected: compile error (`rmvSymbol`, `convertRmv`, `formatSac`, `formatRmv` undefined).

- [ ] **Step 2: Replace the formatter's SAC region**

`unit_formatter.dart:248-270` becomes:

```dart
  // ============================================================================
  // Gas consumption: SAC (pressure lane) and RMV (volume lane)
  // ============================================================================

  /// SAC display suffix: "bar/min" or "psi/min".
  String get sacSymbol => '$pressureSymbol/min';

  /// RMV display suffix: "L/min" or "cuft/min".
  String get rmvSymbol => '$volumeSymbol/min';

  /// Convert a SAC in bar/min (from [Dive.sac]) to the pressure unit.
  double convertSac(double barPerMin) => convertPressure(barPerMin);

  /// Convert an RMV in L/min (from [Dive.rmvFor]) to the volume unit.
  double convertRmv(double litersPerMin) => convertVolume(litersPerMin);

  /// "1.5 bar/min" or "21 psi/min". psi/min values run in the hundreds, so
  /// a decimal there is noise.
  String formatSac(double barPerMin) {
    final decimals = settings.pressureUnit == PressureUnit.bar ? 1 : 0;
    return '${convertSac(barPerMin).toStringAsFixed(decimals)} $sacSymbol';
  }

  /// "16.8 L/min" or "0.59 cuft/min". cuft/min values sit below 1, so one
  /// decimal would render every imperial RMV as 0.5 or 0.6.
  String formatRmv(double litersPerMin) {
    final decimals = settings.volumeUnit == VolumeUnit.liters ? 1 : 2;
    return '${convertRmv(litersPerMin).toStringAsFixed(decimals)} $rmvSymbol';
  }
```

The `sacUnit` getter is gone. Anything in `lib/` still calling `units.sacUnit` (the table view and list page, both changed below) fails to compile until Step 6.

Run: `flutter test test/core/utils/unit_formatter_sac_test.dart`
Expected: PASS.

- [ ] **Step 3: Split the field**

`dive_field.dart:65`: replace `  sacRate,` with two lines `  sac,` and `  rmv,`.

`:179`: replace `      case DiveField.sacRate:` with `      case DiveField.sac:` and `      case DiveField.rmv:` (both fall through to `DiveFieldCategory.tank`).

`:293-294`: replace

```dart
      case DiveField.sacRate:
        return 'SAC Rate';
```

with

```dart
      case DiveField.sac:
        return 'SAC (pressure rate)';
      case DiveField.rmv:
        return 'RMV (volume rate)';
```

`:415-416`: replace the `shortLabel` case with `case DiveField.sac: return 'SAC';` and `case DiveField.rmv: return 'RMV';` (two cases, formatted over four lines).

`:507`: replace `DiveField.sacRate => l10n.enum_diveField_sacRate,` with `DiveField.sac => l10n.enum_diveField_sac,` and `DiveField.rmv => l10n.enum_diveField_rmv,`.

`:570`: replace `DiveField.sacRate => l10n.enum_diveField_sacRate_short,` with `DiveField.sac => l10n.enum_diveField_sac_short,` and `DiveField.rmv => l10n.enum_diveField_rmv_short,`.

`:653-654`: replace `case DiveField.sacRate: return null;` with cases for `sac` and `rmv`, both returning `null`.

`dive_field_column_sizing.dart:67-68` and `:189-190`: replace each `case DiveField.sacRate:` with `case DiveField.sac:` followed by `case DiveField.rmv:` (both keep 80 default, 60 minimum).

`dive_field_adapter.dart:60`: replace `case DiveField.sacRate:` with `case DiveField.sac:` and `case DiveField.rmv:` in `isRightAligned`. `:127-130`: replace `fieldFromName` with:

```dart
  /// Field names that saved layouts may still carry, mapped to the field
  /// that replaced them.
  ///
  /// Saved layouts store [DiveField.name] verbatim, and an unresolved name
  /// throws out of `EntityTableViewConfig.fromJson`, so dropping an old name
  /// would break the dives table for anyone who had customized it. The v170
  /// migration rewrites local layouts, but a layout synced from an older
  /// build arrives after that, so this alias is permanent.
  static const Map<String, DiveField> _legacyNames = {
    // Split into sac and rmv (discussions #354, #803).
    'sacRate': DiveField.sac,
  };

  @override
  DiveEntityField fieldFromName(String name) {
    final legacy = _legacyNames[name];
    if (legacy != null) return DiveEntityField(legacy);
    return DiveEntityField(DiveField.values.firstWhere((e) => e.name == name));
  }
```

`view_field_config.dart:76` and `:303`: replace `        TableColumnConfig(field: DiveField.sacRate),` with

```dart
        TableColumnConfig(field: DiveField.sac),
        TableColumnConfig(field: DiveField.rmv),
```

`dive_table_view.dart:217`: replace `case DiveField.sacRate:` with `case DiveField.sac:` and `case DiveField.rmv:`.

- [ ] **Step 4: Extractor and formatter**

`dive_field_extractor.dart`: delete the `units.dart` import (line 3). Replace the doc comment and signature of `extractFromDive` (lines 11-35) with:

```dart
  /// Extract the raw value for this field from a full [Dive] entity.
  ///
  /// [DiveField.sac] yields bar/min from [Dive.sac] (one reference tank, no
  /// volume needed); [DiveField.rmv] yields L/min from [Dive.rmvFor] under
  /// [gasModel] (every tank with a volume). The two are separate columns, so
  /// there is no unit preference to thread through here.
  ///
  /// [diveTypeLabel] resolves a dive-type slug to its display label for
  /// [DiveField.diveTypeName]. On-screen callers pass the localizing resolver
  /// (`diveTypeLabel` in `dive_log/presentation/formatters/`) so the column
  /// honors the active locale (issue #643). Omitting it keeps the English slug
  /// capitalization, which is what locale-independent consumers want.
  /// [gasModel] selects the equation of state behind the RMV value and is
  /// ignored for every other field. Defaults to [GasModel.real] to match the
  /// AppSettings default (issue #828).
  dynamic extractFromDive(
    Dive dive, {
    GasModel gasModel = GasModel.real,
    String Function(String id)? diveTypeLabel,
  }) {
```

Replace lines 97-98:

```dart
      case DiveField.sacRate:
        return _computeSacRate(dive, sacUnit, gasModel);
```

with:

```dart
      case DiveField.sac:
        return dive.sac;
      case DiveField.rmv:
        return dive.rmvFor(gasModel);
```

Delete `_computeSacRate` and its doc comment (lines 212-220).

`dive_field_formatter.dart:37-44`: replace the `sacRate` case with:

```dart
      case DiveField.sac:
        return value is double ? units.formatSac(value) : '--';

      case DiveField.rmv:
        return value is double ? units.formatRmv(value) : '--';
```

- [ ] **Step 5: Table view and list cards**

`dive_table_view.dart:138-147`: both `extractFromDive` calls in the comparator drop `sacUnit: units.sacUnit,` and keep `gasModel: units.settings.gasModel,`. `:247-251`: the cell's `extractFromDive` call likewise drops the `sacUnit:` argument.

`dive_list_page.dart:1079-1083` and `:1231-1236`: drop the `sacUnit: units.sacUnit,` argument from both `extractFromDive` calls.

```bash
grep -rn "sacUnit: units.sacUnit\|DiveField.sacRate\|_computeSacRate" lib/ || echo "clean"
```

- [ ] **Step 6: Update the field and formatter tests**

`test/core/constants/dive_field_test.dart`:
- `:67`: `expect(DiveField.sacRate.icon, isNull);` becomes two lines for `DiveField.sac` and `DiveField.rmv`.
- `:84`: `expect(summaryFields, isNot(contains(DiveField.sacRate)));` becomes two lines for `sac` and `rmv`.
- `:137`: `expect(DiveField.sacRate.displayName, equals('SAC Rate'));` becomes `expect(DiveField.sac.displayName, equals('SAC (pressure rate)'));` and `expect(DiveField.rmv.displayName, equals('RMV (volume rate)'));`.
- `:215`: replace `DiveField.sacRate,` in `nullIconFields` with `DiveField.sac,` and `DiveField.rmv,`.
- `:292-296`: replace the `sacRate` block with:

```dart
      expect(DiveField.sac.displayName, equals('SAC (pressure rate)'));
      expect(DiveField.sac.shortLabel, equals('SAC'));
      expect(DiveField.rmv.displayName, equals('RMV (volume rate)'));
      expect(DiveField.rmv.shortLabel, equals('RMV'));
```

`test/core/constants/dive_field_extractor_test.dart`, group at `:491`:
- Delete the `units.dart` import.
- `'sacRate defaults to pressurePerMin to match AppSettings default'` becomes `'sac yields bar/min from the reference tank'` with body `final result = DiveField.sac.extractFromDive(testDive); expect(result, isA<double>()); expect(result as double, closeTo(1.02, 0.05));`.
- `'sacRate returns null for dive with no tanks'`: use `DiveField.sac` and add `expect(DiveField.rmv.extractFromDive(noTankDive), isNull);`.
- `'sacRate returns null when tank has no volume'`: becomes `'rmv returns null when the tank has no volume'` with `expect(DiveField.rmv.extractFromDive(dive), isNull);`.
- `'sacRate returns null when no avgDepth'` and `'... no runtime'`: assert both `DiveField.sac` and `DiveField.rmv` are null.
- `'sacRate sums all tanks on multi-tank dive'`: becomes `'rmv sums all tanks on a multi-tank dive'`; `final result = DiveField.rmv.extractFromDive(dive);`; expectation `closeTo(9.70, 0.1)` unchanged.
- `'sacRate volume mode returns L/min from Dive.sacFor'`: becomes `'rmv returns L/min from Dive.rmvFor'`, `DiveField.rmv.extractFromDive(testDive)`, `closeTo(11.83, 0.1)`.
- `'sacRate pressure mode returns bar/min from dive.sacPressure'`: becomes `'sac returns bar/min from Dive.sac'`, `DiveField.sac.extractFromDive(testDive)`, `closeTo(1.02, 0.05)`.
- `'sacRate pressure mode works without tank volume'`: becomes `'sac works without a tank volume where rmv cannot'`: `expect(DiveField.rmv.extractFromDive(dive), isNull); expect(DiveField.sac.extractFromDive(dive), isA<double>());`.
- `:865`: `expect(DiveField.sacRate.extractFromSummary(testSummary), isNull);` becomes two lines for `sac` and `rmv`.

Replace the whole of `test/core/constants/dive_field_extractor_gas_model_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The RMV column honors the gas model preference (issue #828). SAC is a
/// pressure drop and carries no equation of state.
void main() {
  final dive = Dive(
    id: 'dive-828',
    dateTime: DateTime(2026, 8, 4, 10),
    runtime: const Duration(minutes: 44),
    avgDepth: 13.2,
    tanks: const [
      DiveTank(
        id: 'tank-1',
        volume: 12.0,
        startPressure: 200.0,
        endPressure: 50.0,
        gasMix: GasMix(o2: 21.0, he: 0.0),
        role: TankRole.backGas,
      ),
    ],
  );

  group('DiveField.rmv under each gas model', () {
    test('follows the ideal model when selected', () {
      final value = DiveField.rmv.extractFromDive(
        dive,
        gasModel: GasModel.ideal,
      );
      expect(value as double, closeTo(17.63, 0.01));
    });

    test('follows the real model when selected', () {
      final value = DiveField.rmv.extractFromDive(
        dive,
        gasModel: GasModel.real,
      );
      expect(value as double, closeTo(16.77, 0.01));
    });
  });

  group('DiveField.sac', () {
    test('is identical under both models', () {
      final ideal = DiveField.sac.extractFromDive(
        dive,
        gasModel: GasModel.ideal,
      );
      final real = DiveField.sac.extractFromDive(dive, gasModel: GasModel.real);
      expect(ideal as double, closeTo(real as double, 1e-12));
    });

    test('the model does not leak into unrelated fields', () {
      for (final model in GasModel.values) {
        expect(DiveField.avgDepth.extractFromDive(dive, gasModel: model), 13.2);
      }
    });
  });
}
```

`test/core/constants/dive_field_formatter_test.dart`: delete the `units.dart` import if it is then unused, and replace the five tests in the `'DiveFieldFormatter - gas fields'` group that mention `sacRate` (lines 128-175) with:

```dart
    test('sac formats bar/min in metric', () {
      expect(DiveField.sac.formatValue(1.23, units), '1.2 bar/min');
    });

    test('sac formats psi/min without a decimal in imperial', () {
      const psiUnits = UnitFormatter(
        AppSettings(pressureUnit: PressureUnit.psi),
      );
      // 1.23 bar/min * 14.5038 = 17.8 psi/min
      expect(DiveField.sac.formatValue(1.23, psiUnits), '18 psi/min');
    });

    test('rmv formats L/min in metric', () {
      expect(DiveField.rmv.formatValue(12.3, units), '12.3 L/min');
    });

    test('rmv formats cuft/min with two decimals in imperial', () {
      const cuftUnits = UnitFormatter(
        AppSettings(volumeUnit: VolumeUnit.cubicFeet),
      );
      // 12.3 L/min * 0.0353147 = 0.434 cuft/min
      expect(DiveField.rmv.formatValue(12.3, cuftUnits), '0.43 cuft/min');
    });

    test('sac and rmv return "--" for non-double', () {
      expect(DiveField.sac.formatValue('invalid', units), '--');
      expect(DiveField.rmv.formatValue(null, units), '--');
    });
```

and in the per-field value map near line 444 replace `DiveField.sacRate: 15.0,` with `DiveField.sac: 1.5,` and `DiveField.rmv: 15.0,`.

`test/features/dive_log/domain/constants/dive_field_adapter_test.dart`, inside the `'DiveFieldAdapter - fieldFromName'` group, add:

```dart
    test('resolves the legacy sacRate name to sac', () {
      // Saved dive-table layouts persist field names verbatim. A layout
      // written before the SAC/RMV split, or synced from a build that
      // predates it, still names the column sacRate; an unresolved name
      // throws out of EntityTableViewConfig.fromJson.
      final adapter = DiveFieldAdapter.instance;
      expect(adapter.fieldFromName('sacRate').field, DiveField.sac);
    });
```

`test/features/dive_log/domain/entities/view_field_config_test.dart:81-98`: the default set gained one column. `expect(config.columns.length, equals(24));`, `columns[12]` is `DiveField.sac`, add `expect(config.columns[13].field, equals(DiveField.rmv));`, and shift the later indices: waterTemp is `[14]`, buddy `[18]`, notes `[23]`.

- [ ] **Step 7: Update the table and list-card widget tests**

`test/features/dive_log/presentation/widgets/dive_table_view_test.dart`: in `_sacConfig` replace `TableColumnConfig(field: DiveField.sacRate),` with `TableColumnConfig(field: DiveField.sac),` and `TableColumnConfig(field: DiveField.rmv),`. Replace the four SAC tests at the end of the file with:

```dart
    // -----------------------------------------------------------------------
    // SAC and RMV are independent columns (discussions #354, #803); the
    // display preference never drives the table.
    // -----------------------------------------------------------------------

    testWidgets('sac and rmv columns render both lanes in metric', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTable(dives: [_makeSacDive()], config: _sacConfig),
      );
      await tester.pumpAndSettle();

      expect(find.text('1.0 bar/min'), findsOneWidget);
      expect(find.text('9.3 L/min'), findsOneWidget);
    });

    testWidgets('sac and rmv columns convert to imperial units', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTable(
          dives: [_makeSacDive()],
          config: _sacConfig,
          settings: const AppSettings(
            pressureUnit: PressureUnit.psi,
            volumeUnit: VolumeUnit.cubicFeet,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1.0 bar/min * 14.5038 = 14.5, shown without a decimal.
      expect(find.text('15 psi/min'), findsOneWidget);
      // 9.3 L/min * 0.0353147 = 0.33 cuft/min, two decimals.
      expect(find.text('0.33 cuft/min'), findsOneWidget);
    });

    testWidgets('the columns ignore the display preference', (tester) async {
      await tester.pumpWidget(
        _buildTable(
          dives: [_makeSacDive()],
          config: _sacConfig,
          settings: const AppSettings(
            gasConsumptionDisplay: GasConsumptionDisplay.rmv,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1.0 bar/min'), findsOneWidget);
      expect(find.text('9.3 L/min'), findsOneWidget);
    });

    testWidgets('sorting by rmv orders rows by the volume lane', (
      tester,
    ) async {
      // Same tank, double the runtime: half the RMV.
      final slow = _makeSacDive().copyWith(
        id: 'sac-2',
        diveNumber: 2,
        runtime: const Duration(minutes: 100),
      );
      await tester.pumpWidget(
        _buildTable(
          dives: [_makeSacDive(), slow],
          config: TableViewConfig(
            columns: _sacConfig.columns,
            sortField: DiveField.rmv,
            sortAscending: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dive 2 (the lower RMV) sorts above dive 1.
      expect(
        tester.getTopLeft(find.text('2')).dy,
        lessThan(tester.getTopLeft(find.text('1')).dy),
      );
    });
```

Add `import 'package:submersion/core/constants/gas_consumption_display.dart';` to the file. If `TableViewConfig`'s sort parameters are named differently from `sortField` / `sortAscending`, match the existing sort tests earlier in the same file.

Replace the whole of `test/features/dive_log/presentation/pages/dive_list_tile_sac_test.dart` with the same header (imports, `_TestSettingsNotifier`, `_TestCardConfigNotifier`, `sacDive`) and this body, where `buildTile` sets `extraFields: [DiveField.sac, DiveField.rmv]`:

```dart
  group('DiveListTile consumption extra fields', () {
    testWidgets('renders both lanes in metric', (tester) async {
      await tester.pumpWidget(buildTile(const AppSettings()));
      await tester.pumpAndSettle();

      expect(find.text('1.0 bar/min'), findsOneWidget);
      expect(find.text('9.3 L/min'), findsOneWidget);
    });

    testWidgets('renders both lanes in imperial', (tester) async {
      await tester.pumpWidget(
        buildTile(
          const AppSettings(
            pressureUnit: PressureUnit.psi,
            volumeUnit: VolumeUnit.cubicFeet,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('15 psi/min'), findsOneWidget);
      expect(find.text('0.33 cuft/min'), findsOneWidget);
    });
  });
```

Drop the now-unused `units.dart` import from that file.

- [ ] **Step 8: Run the tests and analyze**

Run: `flutter test test/core/utils/unit_formatter_sac_test.dart test/core/constants/ test/features/dive_log/domain/ test/features/dive_log/presentation/widgets/dive_table_view_test.dart test/features/dive_log/presentation/pages/dive_list_tile_sac_test.dart test/features/dive_log/presentation/widgets/cylinders_card_test.dart`
Expected: all pass. (`cylinders_card_test` still asserts `'29.0 psi/min'` through its own `_formatSac`; that widget changes in Task 9.)

Run: `flutter analyze lib/core lib/features/dive_log`
Expected: `No issues found!` (in particular no unused-import info in `dive_field_extractor.dart`).

- [ ] **Step 9: Commit**

```bash
dart format lib/core lib/features/dive_log test/
git add -A lib/ test/
git commit -m "feat(table): independent SAC and RMV columns with lane formatters"
```

---

### Task 7: Detail summary rows

Spec: D9 (detail summary row). Two rows under Both, SAC first; a wanted-but-missing RMV shows the volume hint (PR #1298 behavior kept).

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:3119` (call site), `:4057-4110` (`_buildSacRow` and `_formatPressureSac`)
- Test: `test/features/dive_log/presentation/pages/dive_detail_sac_row_test.dart`

**Interfaces:**
- Produces: `Widget _buildGasConsumptionRows(BuildContext, WidgetRef, Dive, UnitFormatter)` replacing `_buildSacRow`.
- Consumes: `gasConsumptionDisplayProvider` (Task 4), `units.formatSac` / `formatRmv` (Task 6), l10n `diveLog_detail_label_sac` / `_rmv` (Task 1), `SacVolumeHint` (existing).

- [ ] **Step 1: Rewrite the tests**

In `dive_detail_sac_row_test.dart`: import `package:submersion/core/constants/gas_consumption_display.dart` and the file that declares `DiveDetailRow` (the widget `_buildDetailRow` returns; take the import path from `dive_detail_page.dart`). Every `AppSettings(sacUnit: SacUnit.litersPerMin ...)` is already `gasConsumptionDisplay: GasConsumptionDisplay.rmv` after Task 4 and every `pressurePerMin` is `.sac`. Now change the expectations so each lane is found by its labeled row, not by bare text (the segment-card chip added in Task 8 also renders the words SAC and RMV):

```dart
  Finder laneRow(String label) => find.widgetWithText(DiveDetailRow, label);
```

- `'volumetric SAC reads the ideal value when ideal is selected'` becomes `'RMV reads the ideal value when ideal is selected'`: keep `find.text('17.6 L/min')`, add `expect(laneRow('RMV'), findsOneWidget);` and `expect(laneRow('SAC'), findsNothing);`.
- `'... real value ...'`: keep `'16.8 L/min'`.
- `'the pressure lane ignores the gas model'`: keep `'1.5 bar/min'`, add `expect(laneRow('SAC'), findsOneWidget);`.
- Add, before the `group(...)`:

```dart
  testWidgets('both shows SAC above RMV with no hint', (tester) async {
    await pumpWith(tester, const AppSettings());

    expect(laneRow('SAC'), findsOneWidget);
    expect(laneRow('RMV'), findsOneWidget);
    expect(find.text('1.5 bar/min'), findsOneWidget);
    expect(find.text('16.8 L/min'), findsOneWidget);
    expect(find.byType(SacVolumeHint), findsNothing);
    expect(
      tester.getTopLeft(laneRow('SAC')).dy,
      lessThan(tester.getTopLeft(laneRow('RMV')).dy),
    );
  });
```

- In the `'volumetric SAC without a cylinder volume (issue #386)'` group (rename it `'RMV without a cylinder volume (issue #386)'`): the four existing RMV-mode tests keep their assertions; `'shows no hint in the pressure lane'` becomes `'shows no hint in SAC-only mode'`; `'hides the row when there is no pressure data either'` asserts both `laneRow('SAC')` and `laneRow('RMV')` are `findsNothing` (replacing the `diveLog_detail_label_sacRate` lookup). Add:

```dart
    testWidgets('both mode shows the SAC row and one hint', (tester) async {
      await pumpWith(
        tester,
        const AppSettings(),
        dive: reportedDive(volume: null),
      );

      expect(laneRow('SAC'), findsOneWidget);
      expect(find.text('1.5 bar/min'), findsOneWidget);
      expect(laneRow('RMV'), findsNothing);
      expect(find.byType(SacVolumeHint), findsOneWidget);
    });
```

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_sac_row_test.dart`
Expected: the new and relabeled tests fail (`laneRow('RMV')` finds nothing; the row is still labeled "SAC Rate").

- [ ] **Step 2: Replace the row builder**

`dive_detail_page.dart:4057-4110`: replace `_buildSacRow` and `_formatPressureSac` with:

```dart
  /// The consumption rows of the summary: SAC (pressure lane) and RMV
  /// (volume lane) behind the diver's display preference. A lane that
  /// cannot be computed is omitted. A wanted-but-missing RMV shows the
  /// volume hint instead of vanishing (issue #386), and RMV-only mode falls
  /// back to the SAC row so the diver still sees a number.
  Widget _buildGasConsumptionRows(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
    UnitFormatter units,
  ) {
    final display = ref.watch(gasConsumptionDisplayProvider);
    final sac = dive.sac;
    final rmv = display.showsRmv
        ? dive.rmvFor(ref.watch(gasModelProvider))
        : null;
    final l10n = context.l10n;

    Widget sacRow() => _buildDetailRow(
      context,
      l10n.diveLog_detail_label_sac,
      units.formatSac(sac!),
    );

    final rows = <Widget>[
      if (display.showsSac && sac != null) sacRow(),
      if (rmv != null)
        _buildDetailRow(
          context,
          l10n.diveLog_detail_label_rmv,
          units.formatRmv(rmv),
        ),
      if (display.showsRmv && rmv == null && sac != null) ...[
        if (!display.showsSac) sacRow(),
        SacVolumeHint(
          volumeSymbol: units.volumeSymbol,
          onTap: () => context.push('/dives/${dive.id}/edit'),
        ),
      ],
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
```

Line 3119: `_buildSacRow(context, ref, dive, units),` becomes `_buildGasConsumptionRows(context, ref, dive, units),`.

- [ ] **Step 3: Run the tests and analyze**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_sac_row_test.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart`
Expected: all pass.

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
dart format lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/pages/dive_detail_sac_row_test.dart
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/pages/dive_detail_sac_row_test.dart
git commit -m "feat(dive-detail): SAC and RMV summary rows behind the display preference"
```

---

### Task 8: The segment card's lane chip

Spec: D9 (segment card). One lane at a time, chosen by a `SAC | RMV` chip that appears only under Both; seeded from `display.lanes.first`.

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/dive_detail_ui_providers.dart` (append)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:2244` (`sacUnit` read), `:2298-2312` (`formatSacValue`), `:2365-2372` (content column head), `:2477` (hint condition), plus a new `_buildLaneSelector` helper
- Test: `test/features/dive_log/presentation/providers/dive_detail_ui_providers_test.dart` (append), `test/features/dive_log/presentation/pages/dive_detail_sac_segments_hint_test.dart` (extend)

**Interfaces:**
- Produces: `sacSegmentsLaneOverrideProvider` (`StateProvider<GasConsumptionLane?>`, session only), `sacSegmentsLaneProvider` (`Provider<GasConsumptionLane>`).
- Consumes: `gasConsumptionDisplayProvider`, `units.formatSac` / `formatRmv`, l10n `gasConsumption_sac` / `_rmv`.

- [ ] **Step 1: Write the failing provider test**

Append to `dive_detail_ui_providers_test.dart` (add imports for `package:flutter_riverpod/flutter_riverpod.dart`, `package:submersion/core/constants/gas_consumption_display.dart`, and `package:submersion/features/settings/presentation/providers/settings_providers.dart`):

```dart
  group('sacSegmentsLaneProvider', () {
    ProviderContainer containerFor(GasConsumptionDisplay display) {
      final container = ProviderContainer(
        overrides: [
          gasConsumptionDisplayProvider.overrideWithValue(display),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('follows the preference when there is no override', () {
      expect(
        containerFor(GasConsumptionDisplay.rmv).read(sacSegmentsLaneProvider),
        GasConsumptionLane.rmv,
      );
      expect(
        containerFor(GasConsumptionDisplay.both).read(sacSegmentsLaneProvider),
        GasConsumptionLane.sac,
      );
    });

    test('honors an override the preference allows', () {
      final container = containerFor(GasConsumptionDisplay.both);
      container.read(sacSegmentsLaneOverrideProvider.notifier).state =
          GasConsumptionLane.rmv;
      expect(container.read(sacSegmentsLaneProvider), GasConsumptionLane.rmv);
    });

    test('ignores an override the preference forbids', () {
      // SAC-only mode has no chip; a stale override from an earlier session
      // state must not resurrect the other lane.
      final container = containerFor(GasConsumptionDisplay.sac);
      container.read(sacSegmentsLaneOverrideProvider.notifier).state =
          GasConsumptionLane.rmv;
      expect(container.read(sacSegmentsLaneProvider), GasConsumptionLane.sac);
    });
  });
```

Run: `flutter test test/features/dive_log/presentation/providers/dive_detail_ui_providers_test.dart`
Expected: compile error, providers undefined.

- [ ] **Step 2: Add the providers**

Append to `dive_detail_ui_providers.dart` (add `import 'package:submersion/core/constants/gas_consumption_display.dart';`):

```dart
/// The lane the consumption-by-segment card renders when the display
/// preference shows both. Session only: null follows the preference.
final sacSegmentsLaneOverrideProvider = StateProvider<GasConsumptionLane?>(
  (ref) => null,
);

/// The lane the card renders. An override only counts while the preference
/// still allows that lane, so switching to SAC-only never shows RMV.
final sacSegmentsLaneProvider = Provider<GasConsumptionLane>((ref) {
  final display = ref.watch(gasConsumptionDisplayProvider);
  final override = ref.watch(sacSegmentsLaneOverrideProvider);
  if (override != null && display.lanes.contains(override)) return override;
  return display.lanes.first;
});
```

Run the provider test: PASS (3 tests).

- [ ] **Step 3: Extend the segment hint test**

`dive_detail_sac_segments_hint_test.dart` already exercises the card with a dive whose profile yields segments (its `AppSettings` constructions were moved to `gasConsumptionDisplay` in Task 4). Reuse its pump helper and dive fixture to add, at the end of `main`:

```dart
  testWidgets('both mode shows the lane chip and RMV is a tap away', (
    tester,
  ) async {
    // Same fixture and pump as the tests above, display left at its default.
    await pumpSegmentCard(tester, const AppSettings());

    final chip = find.byType(SegmentedButton<GasConsumptionLane>);
    expect(chip, findsOneWidget);
    // Seeded from lanes.first: SAC, so the values carry the pressure unit.
    expect(find.textContaining('bar/min'), findsWidgets);

    await tester.tap(
      find.descendant(of: chip, matching: find.text('RMV')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('L/min'), findsWidgets);
  });

  testWidgets('single-lane modes show no chip', (tester) async {
    await pumpSegmentCard(
      tester,
      const AppSettings(gasConsumptionDisplay: GasConsumptionDisplay.rmv),
    );
    expect(find.byType(SegmentedButton<GasConsumptionLane>), findsNothing);
  });
```

`pumpSegmentCard` stands for that file's existing pump helper; use its real name and argument order (it takes the settings and, where relevant, the dive). If the fixture the RMV tests use has no cylinder volume, use the one the "converts by its own cylinder" test uses so `L/min` values can render.

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_sac_segments_hint_test.dart`
Expected: the two new tests fail (no chip yet).

- [ ] **Step 4: Change the card**

`dive_detail_page.dart:2244`: replace `final sacUnit = ref.watch(sacUnitProvider);` with:

```dart
    final display = ref.watch(gasConsumptionDisplayProvider);
    final lane = ref.watch(sacSegmentsLaneProvider);
```

`:2298-2312`, replace `formatSacValue` with:

```dart
    // Format a segment for the lane the card shows, applying normalization.
    String formatSacValue(double sacBarPerMin, {String? segmentTankId}) {
      final normalizedSac = sacBarPerMin * normalizationFactor;
      final volume = volumeForSegment(segmentTankId);
      if (lane == GasConsumptionLane.rmv && volume != null) {
        return units.formatRmv(normalizedSac * volume);
      }
      return units.formatSac(normalizedSac);
    }
```

`:2365-2372`, inside the content column, before `_buildSegmentationSelector(`:

```dart
                if (display == GasConsumptionDisplay.both) ...[
                  _buildLaneSelector(context, ref, lane),
                  const SizedBox(height: 8),
                ],
```

`:2477`: `if (sacUnit == SacUnit.litersPerMin &&` becomes `if (lane == GasConsumptionLane.rmv &&`.

Add the helper next to `_buildSegmentationSelector`:

```dart
  /// SAC | RMV chip for the segment card, shown only when the preference
  /// displays both lanes (a single-lane preference has nothing to choose).
  Widget _buildLaneSelector(
    BuildContext context,
    WidgetRef ref,
    GasConsumptionLane lane,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<GasConsumptionLane>(
        segments: [
          ButtonSegment(
            value: GasConsumptionLane.sac,
            label: Text(context.l10n.gasConsumption_sac),
          ),
          ButtonSegment(
            value: GasConsumptionLane.rmv,
            label: Text(context.l10n.gasConsumption_rmv),
          ),
        ],
        selected: {lane},
        showSelectedIcon: false,
        onSelectionChanged: (selection) =>
            ref.read(sacSegmentsLaneOverrideProvider.notifier).state =
                selection.first,
      ),
    );
  }
```

Add `import 'package:submersion/core/constants/gas_consumption_display.dart';` to the page.

- [ ] **Step 5: Run the tests and analyze**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_sac_segments_hint_test.dart test/features/dive_log/presentation/pages/dive_detail_sac_row_test.dart test/features/dive_log/presentation/providers/`
Expected: all pass.

Run: `flutter analyze lib/features/dive_log/presentation`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
dart format lib/features/dive_log/presentation test/features/dive_log/presentation
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/features/dive_log/presentation/providers/dive_detail_ui_providers.dart test/features/dive_log/presentation/
git commit -m "feat(dive-detail): lane chip on the consumption-by-segment card"
```

---

### Task 9: Cylinders card, one line per lane

Spec: D9 (cylinders card). SAC and RMV per cylinder; RMV omitted for a cylinder without a volume. Two stacked lines rather than one joined line, because the trailing column is narrow and right-aligned.

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart:5,27-38,181-228`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:461-466` (call site)
- Test: `test/features/dive_log/presentation/widgets/cylinders_card_test.dart`

**Interfaces:**
- Produces: `CylindersCard({required Dive dive, required UnitFormatter units, required AppSettings settings, required GasConsumptionDisplay display})` replacing the `sacUnit` parameter.

- [ ] **Step 1: Update the tests**

In `cylinders_card_test.dart`: import `gas_consumption_display.dart`; in `_buildCard` replace `SacUnit sacUnit = SacUnit.pressurePerMin,` with `GasConsumptionDisplay display = GasConsumptionDisplay.sac,` and `sacUnit: sacUnit,` with `display: display,`. Then:

- `'shows SAC and gas used on a single-tank dive'`: `find.text('2.0 bar/min')` becomes `find.text('SAC 2.0 bar/min')`.
- `'shows one row with distinct SAC per tank on multi-tank dive'`: `'SAC 2.0 bar/min'` and `'SAC 1.2 bar/min'`.
- `'formats SAC as L/min when unit is litersPerMin'` becomes `'formats RMV when the display is rmv'`: `display: GasConsumptionDisplay.rmv`, expect `'RMV 22.2 L/min'` and `find.textContaining('bar/min')` `findsNothing`.
- `'formats pressures and SAC in imperial units'`: `'29.0 psi/min'` becomes `'SAC 29 psi/min'`.
- Add:

```dart
    testWidgets('both shows a SAC line and an RMV line', (tester) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank()]),
          cylinderSacs: [_makeSac()],
          display: GasConsumptionDisplay.both,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SAC 2.0 bar/min'), findsOneWidget);
      expect(find.text('RMV 22.2 L/min'), findsOneWidget);
    });

    testWidgets('both omits the RMV line for a cylinder without a volume', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(
          dive: _makeDive([_makeTank(volume: null)]),
          cylinderSacs: [_makeSac(tankVolume: null)],
          display: GasConsumptionDisplay.both,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SAC 2.0 bar/min'), findsOneWidget);
      expect(find.textContaining('RMV'), findsNothing);
    });
```

(`_makeTank` and `_makeSac` already accept `volume:` / `tankVolume:` as optional named parameters; if either has a non-nullable type, make it nullable with a null default in the helper.)

Run: `flutter test test/features/dive_log/presentation/widgets/cylinders_card_test.dart`
Expected: compile error (`display` is not a `CylindersCard` parameter).

- [ ] **Step 2: Change the widget**

`cylinders_card.dart`: replace the `units.dart` import (line 5) with `import 'package:submersion/core/constants/gas_consumption_display.dart';` and add `import 'package:submersion/l10n/arb/app_localizations.dart';`. In the constructor and fields replace `required this.sacUnit,` / `final SacUnit sacUnit;` with `required this.display,` / `final GasConsumptionDisplay display;`.

Where `_trailingBlock(theme, ...)` is called in `build`, pass `context.l10n` as a new first argument. Replace lines 181-228 with:

```dart
  /// Trailing column: attribution badge, one consumption line per visible
  /// lane, gas used (converted to the diver's volume unit). Returns null
  /// when there is nothing to show so the tile keeps its natural width.
  Widget? _trailingBlock(
    AppLocalizations l10n,
    ThemeData theme,
    CylinderSac? cylinderSac,
    String? sourceName,
  ) {
    final hasSac = cylinderSac != null && cylinderSac.hasValidSac;
    if (!hasSac && sourceName == null) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (sourceName != null) FieldAttributionBadge(sourceName: sourceName),
        if (hasSac) ...[
          for (final line in _consumptionLines(l10n, cylinderSac))
            Text(
              line,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          if (cylinderSac.gasUsedLiters != null)
            Text(
              '${units.convertVolume(cylinderSac.gasUsedLiters!).round()} '
              '${units.volumeSymbol} used',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }

  /// One labeled line per lane the diver displays. RMV needs this
  /// cylinder's own volume; without one the RMV line is omitted here (the
  /// summary row carries the volume hint, not every cylinder). Only called
  /// when [CylinderSac.hasValidSac] is true.
  List<String> _consumptionLines(AppLocalizations l10n, CylinderSac cylinder) {
    final rmv = cylinder.rmv;
    return [
      if (display.showsSac)
        '${l10n.gasConsumption_sac} ${units.formatSac(cylinder.sacRate!)}',
      if (display.showsRmv && rmv != null)
        '${l10n.gasConsumption_rmv} ${units.formatRmv(rmv)}',
    ];
  }
```

Update the class doc comment's "per-tank SAC" wording to "per-tank SAC and RMV". `dive_detail_page.dart:465`: `sacUnit: ref.watch(sacUnitProvider),` becomes `display: ref.watch(gasConsumptionDisplayProvider),`.

- [ ] **Step 3: Run the tests and analyze**

Run: `flutter test test/features/dive_log/presentation/widgets/cylinders_card_test.dart test/features/dive_log/presentation/pages/dive_detail_page_test.dart`
Expected: all pass.

Run: `flutter analyze lib/features/dive_log/presentation`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
dart format lib/features/dive_log/presentation test/features/dive_log/presentation/widgets/cylinders_card_test.dart
git add lib/features/dive_log/presentation/widgets/cylinders_card.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/widgets/cylinders_card_test.dart
git commit -m "feat(dive-detail): per-cylinder SAC and RMV lines"
```

---

### Task 10: Remove the dead `sacUnit` parameter from the range-stats panel

Spec deviation, recorded here: D9 lists a range-stats row, but the panel never rendered a consumption rate. Its `sacUnit` field is declared and required yet never read (the only other mention is a stale comment). The correct change is to delete the dead parameter, not to add lanes to a panel that computes none.

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/range_stats_panel.dart:5,29-30,40,199`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:2044-2050` (call site)

- [ ] **Step 1: Delete the parameter**

In `range_stats_panel.dart`: delete the `units.dart` import (line 5), the field and its doc (lines 29-30, `/// SAC unit preference from settings` and `final SacUnit sacUnit;`), the constructor line `required this.sacUnit,`, and change the comment at line 199 from `// Conditional: Temp | Temp | Gas | SAC (flows into same row)` to `// Conditional: Temp | Temp | Gas (flows into same row)`.

In `dive_detail_page.dart:2049` delete `sacUnit: ref.watch(sacUnitProvider),`.

- [ ] **Step 2: Analyze and run the detail page tests**

Run: `flutter analyze lib/features/dive_log/presentation`
Expected: `No issues found!`

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_page_test.dart`
Expected: pass.

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/range_stats_panel.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart
git commit -m "refactor(dive-detail): drop the unused sacUnit parameter from RangeStatsPanel"
```

---

### Task 11: Profile chart tooltip lane

Spec: D9 (profile chart). One curve, computed in bar/min; the tooltip row is labeled SAC and shows bar/min, except in RMV-only mode with a tank volume, where it converts and is labeled RMV. The axis title and ticks stay bar/min (unchanged behavior). The legend, options dialog, and appearance-settings names became lane-neutral in Task 1 through their existing keys.

**Files:**
- Create: `lib/features/dive_log/presentation/utils/gas_consumption_tooltip.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:1326-1350` (tooltip site 1), `:1775-1783` (repaint signature), `:2378` (`sacUnit` read), `:3170-3195` (tooltip site 2)
- Test (new): `test/features/dive_log/presentation/utils/gas_consumption_tooltip_test.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart` (must stay green)

**Interfaces:**
- Produces: `({String label, String value}) gasConsumptionTooltipRow({required AppLocalizations l10n, required UnitFormatter units, required GasConsumptionDisplay display, required double sacBarPerMin, required double? tankVolume})`.

- [ ] **Step 1: Write the failing helper test**

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/utils/gas_consumption_tooltip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The profile chart has one consumption curve, computed in bar/min. The
/// tooltip shows RMV only when the diver displays that lane alone and a
/// cylinder volume exists to convert with; otherwise the native SAC lane.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  ({String label, String value}) row(
    GasConsumptionDisplay display, {
    double? tankVolume = 12.0,
  }) => gasConsumptionTooltipRow(
    l10n: l10n,
    units: units,
    display: display,
    sacBarPerMin: 1.47,
    tankVolume: tankVolume,
  );

  test('SAC-only shows the pressure lane', () {
    expect(row(GasConsumptionDisplay.sac), (label: 'SAC', value: '1.5 bar/min'));
  });

  test('both shows the native pressure lane (one curve, one lane)', () {
    expect(row(GasConsumptionDisplay.both), (label: 'SAC', value: '1.5 bar/min'));
  });

  test('RMV-only converts by the tank volume', () {
    // 1.47 bar/min * 12 L = 17.64 L/min
    expect(row(GasConsumptionDisplay.rmv), (label: 'RMV', value: '17.6 L/min'));
  });

  test('RMV-only without a volume falls back to SAC', () {
    expect(
      row(GasConsumptionDisplay.rmv, tankVolume: null),
      (label: 'SAC', value: '1.5 bar/min'),
    );
  });
}
```

Run: `flutter test test/features/dive_log/presentation/utils/gas_consumption_tooltip_test.dart`
Expected: compile error (import target missing).

- [ ] **Step 2: Write the helper**

`lib/features/dive_log/presentation/utils/gas_consumption_tooltip.dart`:

```dart
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A labeled, formatted tooltip row for the profile chart's consumption
/// curve.
///
/// The curve is computed in bar/min. The tooltip shows RMV only when the
/// diver displays the volume lane alone and [tankVolume] exists to convert
/// with; under Both the native SAC lane wins, because one curve carries one
/// lane and the axis stays in pressure units.
({String label, String value}) gasConsumptionTooltipRow({
  required AppLocalizations l10n,
  required UnitFormatter units,
  required GasConsumptionDisplay display,
  required double sacBarPerMin,
  required double? tankVolume,
}) {
  if (display == GasConsumptionDisplay.rmv && tankVolume != null) {
    return (
      label: l10n.gasConsumption_rmv,
      value: units.formatRmv(sacBarPerMin * tankVolume),
    );
  }
  return (label: l10n.gasConsumption_sac, value: units.formatSac(sacBarPerMin));
}
```

Run the helper test: PASS (4 tests).

- [ ] **Step 3: Use it in the chart**

Add to `dive_profile_chart.dart` the imports `package:submersion/core/constants/gas_consumption_display.dart` and `package:submersion/features/dive_log/presentation/utils/gas_consumption_tooltip.dart`.

Site 1 (`:1326-1350`), replace the whole `// SAC` block with:

```dart
    // Gas consumption: SAC, or RMV when the diver shows only that lane.
    if (_showSac &&
        widget.sacCurve != null &&
        spot.spotIndex < widget.sacCurve!.length) {
      final sacBarPerMin = widget.sacCurve![spot.spotIndex];
      var row = (label: context.l10n.gasConsumption_sac, value: '-');
      if (sacBarPerMin > 0) {
        row = gasConsumptionTooltipRow(
          l10n: context.l10n,
          units: units,
          display: ref.read(gasConsumptionDisplayProvider),
          sacBarPerMin: sacBarPerMin * widget.sacNormalizationFactor,
          tankVolume: widget.tankVolume,
        );
      }
      rows.add(
        TooltipRow(label: row.label, value: row.value, bulletColor: Colors.teal),
      );
    }
```

Signature (`:1775-1783`): keep `units.sacSymbol,` and add two entries after it, `units.rmvSymbol,` and `units.settings.gasConsumptionDisplay.name,`, so a preference flip repaints.

`:2378`: `final sacUnit = ref.read(sacUnitProvider);` becomes `final display = ref.read(gasConsumptionDisplayProvider);`.

Site 2 (`:3170-3195`): keep line 3172 (`String sacValue = ...;`, whose existing sentinel literal stays as it is) and add directly below it `String sacLabel = context.l10n.gasConsumption_sac;`. Replace the inner block from `if (widget.sacCurve != null &&` through the closing brace of `if (sacBarPerMin > 0) { ... }` with:

```dart
                      if (widget.sacCurve != null &&
                          spot.spotIndex < widget.sacCurve!.length) {
                        final sacBarPerMin = widget.sacCurve![spot.spotIndex];
                        if (sacBarPerMin > 0) {
                          final row = gasConsumptionTooltipRow(
                            l10n: context.l10n,
                            units: units,
                            display: display,
                            sacBarPerMin:
                                sacBarPerMin * widget.sacNormalizationFactor,
                            tankVolume: widget.tankVolume,
                          );
                          sacLabel = row.label;
                          sacValue = row.value;
                        }
                      }
```

and change `addRow(context.l10n.diveLog_tooltip_sac, sacValue, Colors.teal);` to `addRow(sacLabel, sacValue, Colors.teal);`. Update the comment above from `// SAC (if enabled - always show row)` to `// Gas consumption (if enabled, always show the row)`.

```bash
grep -n "sacUnitProvider\|SacUnit\|diveLog_tooltip_sac" lib/features/dive_log/presentation/widgets/dive_profile_chart.dart || echo "chart clean"
```

If `units.dart` is now imported only for `SacUnit`, remove that import.

- [ ] **Step 4: Run the tests and analyze**

Run: `flutter test test/features/dive_log/presentation/utils/ test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart`
Expected: all pass. `dive_profile_legend_test.dart:222,765,790` assert `find.text('SAC Rate')`; the legend key's value is now `Gas consumption` (Task 1), so change those three assertions to `find.text('Gas consumption')`.

Run: `flutter analyze lib/features/dive_log/presentation`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/presentation test/features/dive_log/presentation
git add lib/features/dive_log/presentation/utils/gas_consumption_tooltip.dart lib/features/dive_log/presentation/widgets/dive_profile_chart.dart test/features/dive_log/presentation/utils/ test/features/dive_log/presentation/widgets/dive_profile_legend_test.dart
git commit -m "feat(profile-chart): consumption tooltip names its lane"
```

---

### Task 12: Statistics gas page lane

Spec: D9 (statistics). A page-level lane provider seeded from the preference; a `SAC | RMV` segmented control at the top of the page under Both drives all three sections; the providers read the lane instead of the settings.

**Files:**
- Create: `lib/features/statistics/presentation/providers/statistics_gas_lane_provider.dart`
- Modify: `lib/features/statistics/presentation/providers/statistics_providers.dart:5,9,80-97,114-133,136-152`
- Modify: `lib/features/statistics/presentation/pages/statistics_gas_page.dart` (all four `sacUnit` sites, the records titles, and the page header)
- Test (new): `test/features/statistics/presentation/providers/statistics_gas_lane_provider_test.dart`, `test/features/statistics/presentation/pages/statistics_gas_page_widget_test.dart`
- Test: `test/features/statistics/presentation/providers/statistics_providers_all_test.dart:28-42,108-125`
- Delete: `test/features/statistics/presentation/pages/statistics_gas_page_test.dart`

**Interfaces:**
- Produces: `statisticsGasLaneOverrideProvider` (`StateProvider<GasConsumptionLane?>`), `statisticsGasLaneProvider` (`Provider<GasConsumptionLane>`). `sacTrendProvider`, `sacRecordsProvider`, `sacByTankRoleProvider` keep their names and return types but select the repository pair member by `statisticsGasLaneProvider`.

- [ ] **Step 1: Write the failing provider test**

`test/features/statistics/presentation/providers/statistics_gas_lane_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_gas_lane_provider.dart';

void main() {
  ProviderContainer containerFor(GasConsumptionDisplay display) {
    final container = ProviderContainer(
      overrides: [gasConsumptionDisplayProvider.overrideWithValue(display)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('follows the preference when there is no override', () {
    expect(
      containerFor(GasConsumptionDisplay.rmv).read(statisticsGasLaneProvider),
      GasConsumptionLane.rmv,
    );
    expect(
      containerFor(GasConsumptionDisplay.both).read(statisticsGasLaneProvider),
      GasConsumptionLane.sac,
    );
  });

  test('honors an override the preference allows', () {
    final container = containerFor(GasConsumptionDisplay.both);
    container.read(statisticsGasLaneOverrideProvider.notifier).state =
        GasConsumptionLane.rmv;
    expect(container.read(statisticsGasLaneProvider), GasConsumptionLane.rmv);
  });

  test('ignores an override the preference forbids', () {
    final container = containerFor(GasConsumptionDisplay.sac);
    container.read(statisticsGasLaneOverrideProvider.notifier).state =
        GasConsumptionLane.rmv;
    expect(container.read(statisticsGasLaneProvider), GasConsumptionLane.sac);
  });
}
```

Run it: compile error (import target missing).

- [ ] **Step 2: Write the provider**

`lib/features/statistics/presentation/providers/statistics_gas_lane_provider.dart`:

```dart
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The lane the gas statistics page shows when the preference displays
/// both. Session only; null follows the preference.
final statisticsGasLaneOverrideProvider = StateProvider<GasConsumptionLane?>(
  (ref) => null,
);

/// The lane every section of the gas statistics page reads, and the one
/// source of truth for which repository pair member the providers call. An
/// override only counts while the preference still allows that lane.
final statisticsGasLaneProvider = Provider<GasConsumptionLane>((ref) {
  final display = ref.watch(gasConsumptionDisplayProvider);
  final override = ref.watch(statisticsGasLaneOverrideProvider);
  if (override != null && display.lanes.contains(override)) return override;
  return display.lanes.first;
});
```

Run the provider test: PASS (3 tests).

- [ ] **Step 3: Point the three providers at the lane**

`statistics_providers.dart`: add imports for `gas_consumption_display.dart` and `statistics_gas_lane_provider.dart`. In each of `sacTrendProvider`, `sacRecordsProvider`, `sacByTankRoleProvider`: replace `final sacUnit = ref.watch(sacUnitProvider);` with `final lane = ref.watch(statisticsGasLaneProvider);` and `if (sacUnit == SacUnit.litersPerMin) {` with `if (lane == GasConsumptionLane.rmv) {`. Replace the three doc comments (`/// SAC trend provider that uses the appropriate calculation based on sacUnit setting`, `/// SAC records provider ...`, `/// Average SAC by tank role ...`) with `/// Consumption trend for the lane the gas page shows (SAC or RMV).`, `/// Best and highest consumption for the lane the gas page shows.`, and `/// Average consumption by tank role for the lane the gas page shows.`. Remove the `units.dart` import if it is then unused.

- [ ] **Step 4: Update the providers test**

`statistics_providers_all_test.dart`: replace the `SacUnit? sacUnit` parameter of `makeContainer` with `GasConsumptionLane? lane`, and the override line with `if (lane != null) statisticsGasLaneProvider.overrideWithValue(lane),`. Replace the two SAC tests at lines 108-125 with:

```dart
  test('the consumption providers read the SAC lane by default', () async {
    // The default display is both, whose first lane is SAC.
    final container = await makeContainer();
    expect(await container.read(sacTrendProvider.future), isEmpty);
    final records = await container.read(sacRecordsProvider.future);
    expect(records.best, isNull);
    expect(await container.read(sacByTankRoleProvider.future), isEmpty);
  });

  test('the consumption providers read the RMV lane when selected', () async {
    final container = await makeContainer(lane: GasConsumptionLane.rmv);
    expect(await container.read(sacTrendProvider.future), isEmpty);
    final records = await container.read(sacRecordsProvider.future);
    expect(records.best, isNull);
    expect(await container.read(sacByTankRoleProvider.future), isEmpty);
  });
```

Fix the imports (`gas_consumption_display.dart`, `statistics_gas_lane_provider.dart`; drop `units.dart` if unused).

- [ ] **Step 5: Write the failing page widget test**

`test/features/statistics/presentation/pages/statistics_gas_page_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_gas_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_gas_lane_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Under Both the gas page carries a SAC | RMV control that drives every
/// section; a single-lane preference shows no control (spec D9).
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<void> pumpPage(WidgetTester tester, AppSettings settings) async {
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: StatisticsGasPage(embedded: true)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  final chip = find.byType(SegmentedButton<GasConsumptionLane>);

  testWidgets('both shows the lane control seeded on SAC', (tester) async {
    await pumpPage(tester, const AppSettings());

    expect(chip, findsOneWidget);
    expect(find.text('Gas consumption trend'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StatisticsGasPage)),
    );
    expect(container.read(statisticsGasLaneProvider), GasConsumptionLane.sac);

    await tester.tap(find.descendant(of: chip, matching: find.text('RMV')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(container.read(statisticsGasLaneProvider), GasConsumptionLane.rmv);
  });

  testWidgets('a single-lane preference shows no control', (tester) async {
    await pumpPage(
      tester,
      const AppSettings(gasConsumptionDisplay: GasConsumptionDisplay.rmv),
    );
    expect(chip, findsNothing);
  });
}
```

`getBaseOverrides` and `MockSettingsNotifier` are the helpers the sac-row test already uses (`test/helpers/mock_providers.dart`). Delete `test/features/statistics/presentation/pages/statistics_gas_page_test.dart` (it mirrored the old `SacUnit` fork in a private helper and asserted nothing about the page).

Run: `flutter test test/features/statistics/presentation/pages/statistics_gas_page_widget_test.dart`
Expected: FAIL, no `SegmentedButton<GasConsumptionLane>` on the page.

- [ ] **Step 6: Change the page**

`statistics_gas_page.dart`: replace the `units.dart` import with `gas_consumption_display.dart` and add `statistics_gas_lane_provider.dart`. In `build`, read the display and put the control first when both lanes are on:

```dart
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final display = settings.gasConsumptionDisplay;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (display == GasConsumptionDisplay.both) ...[
            _buildLaneSelector(context, ref),
            const SizedBox(height: 16),
          ],
          _buildSacTrendSection(context, ref, units),
```

Add the selector:

```dart
  /// SAC | RMV for the whole page, shown only when the preference displays
  /// both lanes. Three sections with two lanes each would be six charts.
  Widget _buildLaneSelector(BuildContext context, WidgetRef ref) {
    final lane = ref.watch(statisticsGasLaneProvider);
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<GasConsumptionLane>(
        segments: [
          ButtonSegment(
            value: GasConsumptionLane.sac,
            label: Text(context.l10n.gasConsumption_sac),
          ),
          ButtonSegment(
            value: GasConsumptionLane.rmv,
            label: Text(context.l10n.gasConsumption_rmv),
          ),
        ],
        selected: {lane},
        showSelectedIcon: false,
        onSelectionChanged: (selection) =>
            ref.read(statisticsGasLaneOverrideProvider.notifier).state =
                selection.first,
      ),
    );
  }
```

In each of the three sections, replace the `sacUnit` read and its unit-symbol/convert derivations with lane-based ones. Trend section:

```dart
    final sacTrendAsync = ref.watch(sacTrendProvider);
    final lane = ref.watch(statisticsGasLaneProvider);
    final isRmv = lane == GasConsumptionLane.rmv;
    final unitSymbol = isRmv ? units.rmvSymbol : units.sacSymbol;
    String format(double v) => isRmv ? units.formatRmv(v) : units.formatSac(v);
    double convert(double v) => isRmv ? units.convertRmv(v) : units.convertSac(v);
```

with `valueFormatter: (value) => format(value)` and `yAxisFormatter: (value) => convert(value).toStringAsFixed(1)` (the `convert` local inside `data:` is removed). By-role section: same three locals; `final sacValue = format(sac);` replaces the `convertedSac` pair. Records section: same locals; `formatSacRecord` becomes

```dart
          String formatSacRecord(double? value) =>
              value == null ? '-- $unitSymbol' : format(value);
```

and the two `ValueRankingCard` titles become

```dart
                  title: isRmv
                      ? context.l10n.statistics_gas_sacRecords_bestRmv
                      : context.l10n.statistics_gas_sacRecords_bestSac,
```

and

```dart
                  title: isRmv
                      ? context.l10n.statistics_gas_sacRecords_highestRmv
                      : context.l10n.statistics_gas_sacRecords_highestSac,
```

```bash
grep -n "sacUnit\|SacUnit\|sacRecords_best\b\|sacRecords_highest\b" lib/features/statistics/ || echo "statistics clean"
```

- [ ] **Step 7: Run the tests and analyze**

Run: `flutter test test/features/statistics/`
Expected: all pass (including `records_page_test.dart` and `stat_charts_axis_test.dart`, which do not read the lane).

Run: `flutter analyze lib/features/statistics`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
dart format lib/features/statistics test/features/statistics
git add -A lib/features/statistics test/features/statistics
git commit -m "feat(statistics): SAC | RMV lane control on the gas page"
```

---

### Task 13: Settings tile and picker

Spec: D6 (settings half). The tile stays under Settings > Units, retitled Gas consumption; the picker offers SAC, RMV, Both with the subtitles from Task 1.

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart:506-513` (tile), `:850-905` (`_showSacUnitPicker`)
- Test: `test/features/settings/presentation/pages/settings_page_test.dart` (append)

**Interfaces:**
- Produces: `void _showGasConsumptionPicker(BuildContext context, WidgetRef ref, AppSettings settings)` replacing `_showSacUnitPicker`.
- Consumes: `setGasConsumptionDisplay` (Task 4), l10n keys (Task 1).

- [ ] **Step 1: Write the failing test**

Append to `settings_page_test.dart`, using that file's `buildTestWidget` and the mock notifier (which gained `setGasConsumptionDisplay` in Task 4). If the Units tiles live on a sub-page in this build, open it the way the existing unit-picker tests in the same file do before tapping the tile.

```dart
  group('gas consumption picker', () {
    testWidgets('offers SAC, RMV, and Both, and saves the choice', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(const SettingsPage()));
      await tester.pumpAndSettle();

      final tile = find.text('Gas consumption');
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.text('Gas consumption display'), findsOneWidget);
      expect(
        find.text(
          'Tank pressure drop per minute (bar/min). Works with any logged pressures.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Gas volume breathed per minute at the surface (L/min). Needs a tank volume.',
        ),
        findsOneWidget,
      );
      expect(find.text('Show SAC and RMV side by side.'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'RMV'));
      await tester.pumpAndSettle();

      // The dialog closed and the tile now names the lane with its unit.
      expect(find.text('Gas consumption display'), findsNothing);
      expect(find.text('RMV (L/min)'), findsOneWidget);
    });
  });
```

Run: `flutter test test/features/settings/presentation/pages/settings_page_test.dart`
Expected: the new test fails at `find.text('Gas consumption')` (the tile still says SAC Rate).

- [ ] **Step 2: Change the tile and the picker**

`settings_page.dart:506-513`, replace the SAC tile with:

```dart
                _buildUnitTile(
                  context,
                  title: context.l10n.settings_units_gasConsumption,
                  value: switch (settings.gasConsumptionDisplay) {
                    GasConsumptionDisplay.sac =>
                      '${context.l10n.gasConsumption_sac} '
                          '(${settings.pressureUnit.symbol}/min)',
                    GasConsumptionDisplay.rmv =>
                      '${context.l10n.gasConsumption_rmv} '
                          '(${settings.volumeUnit.symbol}/min)',
                    GasConsumptionDisplay.both =>
                      context.l10n.settings_units_gasConsumption_both,
                  },
                  onTap: () =>
                      _showGasConsumptionPicker(context, ref, settings),
                ),
```

Replace `_showSacUnitPicker` (`:850-905`) with:

```dart
  void _showGasConsumptionPicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final l10n = context.l10n;
    final current = settings.gasConsumptionDisplay;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        Widget option(
          GasConsumptionDisplay value,
          String title,
          String subtitle,
        ) {
          return ListTile(
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: current == value
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () {
              ref
                  .read(settingsProvider.notifier)
                  .setGasConsumptionDisplay(value);
              Navigator.of(dialogContext).pop();
            },
          );
        }

        return AlertDialog(
          title: Text(l10n.settings_units_dialog_gasConsumption),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              option(
                GasConsumptionDisplay.sac,
                l10n.gasConsumption_sac,
                l10n.settings_units_gasConsumption_sac_subtitle(
                  '${settings.pressureUnit.symbol}/min',
                ),
              ),
              option(
                GasConsumptionDisplay.rmv,
                l10n.gasConsumption_rmv,
                l10n.settings_units_gasConsumption_rmv_subtitle(
                  '${settings.volumeUnit.symbol}/min',
                ),
              ),
              option(
                GasConsumptionDisplay.both,
                l10n.settings_units_gasConsumption_both,
                l10n.settings_units_gasConsumption_both_subtitle,
              ),
            ],
          ),
        );
      },
    );
  }
```

Add `import 'package:submersion/core/constants/gas_consumption_display.dart';` and drop the `units.dart` import if `SacUnit` was its only use.

- [ ] **Step 3: Run the tests and analyze**

Run: `flutter test test/features/settings/presentation/pages/`
Expected: all pass.

Run: `flutter analyze lib/features/settings`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
dart format lib/features/settings test/features/settings
git add lib/features/settings/presentation/pages/settings_page.dart test/features/settings/presentation/pages/settings_page_test.dart
git commit -m "feat(settings): gas consumption display picker"
```

---

### Task 14: Delete the shim, `SacUnit`, and the retired l10n keys

Spec: D2 (SacUnit deleted), D8 (old keys deleted, German test extended).

**Files:**
- Modify: `lib/core/constants/units.dart:107-116` (delete `SacUnit`)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (delete the `sacUnit` getter, `setSacUnit`, `sacUnitProvider`)
- Modify: `test/helpers/mock_providers.dart`, `test/features/settings/presentation/pages/settings_page_test.dart`, `test/features/settings/presentation/pages/settings_page_shared_data_test.dart`, `test/features/statistics/presentation/pages/records_page_test.dart` (delete the `setSacUnit` overrides), `test/features/dive_log/presentation/pages/dive_detail_page_test.dart:1368`, `test/features/settings/app_settings_gas_consumption_test.dart` (delete the shim test)
- Modify: all eleven ARBs (delete keys), `test/l10n/german_sac_terminology_test.dart`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

- [ ] **Step 1: Delete the Dart shim**

`units.dart`: delete the `SacUnit` enum and its doc comment (lines 107-116).

`settings_providers.dart`: delete the transitional `sacUnit` getter (with its comment) from `AppSettings`, the `setSacUnit` forwarder from the notifier, and the `sacUnitProvider` block.

Tests: delete the `setSacUnit` override from the four mock notifiers (keep `setGasConsumptionDisplay`); in `dive_detail_page_test.dart:1368` change `await settings.setSacUnit(SacUnit.litersPerMin);` to `await settings.setGasConsumptionDisplay(GasConsumptionDisplay.rmv);` (and its import); in `app_settings_gas_consumption_test.dart` delete the `'the transitional sacUnit shim mirrors the display'` test and the now-unused `units.dart` import.

```bash
grep -rn "SacUnit\|sacUnit" lib/ test/ || echo "no SacUnit left"
flutter analyze
```

Expected: no matches; `No issues found!`. Any remaining reference is a surface that was missed; fix it through `gasConsumptionDisplayProvider` rather than restoring the shim.

- [ ] **Step 2: Delete the retired l10n keys from all eleven ARBs**

Keys: `diveLog_detail_label_sacRate`, `enum_diveField_sacRate`, `enum_diveField_sacRate_short`, `settings_units_sacRate`, `settings_units_dialog_sacRateUnit`, `settings_units_sac_pressurePerMinute`, `settings_units_sac_pressurePerMinute_subtitle`, `settings_units_sac_volumePerMinute`, `settings_units_sac_volumePerMinute_subtitle`, `setup_units_sac`, `statistics_gas_sacRecords_best`, `statistics_gas_sacRecords_highest`, `diveLog_tooltip_sac`, `diveLog_rangeStats_label_sacRate`, `units_sac_litersPerMin`, `units_sac_pressurePerMin`.

```bash
python3 - <<'PY'
import json, pathlib
keys = [
    'diveLog_detail_label_sacRate', 'enum_diveField_sacRate', 'enum_diveField_sacRate_short',
    'settings_units_sacRate', 'settings_units_dialog_sacRateUnit',
    'settings_units_sac_pressurePerMinute', 'settings_units_sac_pressurePerMinute_subtitle',
    'settings_units_sac_volumePerMinute', 'settings_units_sac_volumePerMinute_subtitle',
    'setup_units_sac', 'statistics_gas_sacRecords_best', 'statistics_gas_sacRecords_highest',
    'diveLog_tooltip_sac', 'diveLog_rangeStats_label_sacRate',
    'units_sac_litersPerMin', 'units_sac_pressurePerMin',
]
prefixes = tuple(f'"{k}":' for k in keys)
for path in sorted(pathlib.Path('lib/l10n/arb').glob('app_*.arb')):
    lines = path.read_text(encoding='utf-8').splitlines(keepends=True)
    kept = [l for l in lines if not l.lstrip().startswith(prefixes)]
    removed = len(lines) - len(kept)
    new_src = ''.join(kept)
    json.loads(new_src)
    path.write_text(new_src, encoding='utf-8')
    print(path.name, 'removed', removed)
PY
```

Then, in `app_en.arb` only, delete by hand the two three-line `@units_sac_litersPerMin` and `@units_sac_pressurePerMin` metadata blocks (they sit together near the old line 11811). Confirm:

```bash
grep -n "units_sac_\|sacRate\"\|sacRateUnit\|sac_pressurePerMinute\|sac_volumePerMinute\|setup_units_sac\|sacRecords_best\"\|sacRecords_highest\"\|tooltip_sac\|rangeStats_label_sac" lib/l10n/arb/app_*.arb || echo "keys gone"
for f in lib/l10n/arb/app_*.arb; do python3 -c "import json; json.load(open('$f', encoding='utf-8'))" && echo "$f ok"; done
```

Expected: `keys gone` and every file `ok`. If a deleted key was the final entry of a file, the preceding line's trailing comma now breaks the JSON; the loop above catches it, and the fix is to remove that comma.

- [ ] **Step 3: Extend the German terminology test**

In `german_sac_terminology_test.dart`, replace the test `'the key surfaces from the issue report read AMV'` with:

```dart
  test('the volume lane reads AMV and the pressure lane Druckverbrauch', () {
    // AMV (Atemminutenvolumen) is literally the volume rate, so it names
    // RMV. The tank-pressure rate needs its own word; SAC is not one in
    // German (discussion #803).
    expect(de.gasConsumption_rmv, 'AMV');
    expect(de.gasConsumption_sac, 'Druckverbrauch');
    expect(de.diveLog_detail_label_rmv, 'AMV');
    expect(de.diveLog_detail_label_sac, 'Druckverbrauch');
    expect(de.enum_diveField_rmv_short, 'AMV');
    expect(de.enum_diveField_sac, 'Druckverbrauch');
    expect(de.statistics_gas_sacRecords_bestRmv, contains('AMV'));
    expect(de.statistics_gas_sacRecords_bestSac, contains('Druckverbrauch'));
    expect(de.settings_units_gasConsumption, 'Gasverbrauch');
  });
```

and delete the last test (`'the profile chart tooltip label is localized'`, whose key is gone). The two ARB-scanning tests (`'no German string still says SAC'` and `'AMV is not pleonastically suffixed with Rate'`) stay as they are and must pass.

- [ ] **Step 4: Regenerate and run**

```bash
flutter gen-l10n
flutter analyze
flutter test test/l10n/ test/features/settings/ test/core/constants/ test/features/dive_log/presentation/pages/dive_detail_page_test.dart test/features/statistics/presentation/pages/records_page_test.dart
```

Expected: `No issues found!` and all pass. A compile error naming a deleted getter means a surface still reads an old key; route it to the new key from Task 1.

- [ ] **Step 5: Commit**

```bash
dart format lib/ test/
git add -A lib/ test/
git commit -m "refactor: retire SacUnit, its shim, and the single-lane l10n keys"
```

---

### Task 15: Full verification and the PR

**Files:** `docs/superpowers/specs/2026-08-26-sac-rmv-split-design.md`, `docs/superpowers/plans/2026-08-26-sac-rmv-split.md`, `docs/superpowers/plans/2026-08-26-sac-rmv-relabel.md` (all three sit uncommitted in this worktree until this task).

- [ ] **Step 1: Codegen, format, analyze**

```bash
dart run build_runner build --delete-conflicting-outputs
git status --short lib/l10n/arb/
dart format .
flutter analyze
```

Expected: the `git status` line prints nothing (generated l10n is committed); `No issues found!` (CI treats infos as failures). Modified `.g.dart` or `.mocks.dart` files elsewhere are git-ignored and expected.

- [ ] **Step 2: Run the full suite once**

Run: `flutter test`
Expected: all pass. A lone failure in an unrelated file (media share helper, sync round trip, zip temp dir, recovery-code dialog) is a known full-suite flake; rerun that one file alone before treating it as real. Do not run a second full suite concurrently with anything else.

- [ ] **Step 3: Commit the docs, push, open the PR**

Write the PR body to a scratch file first so the heredoc cannot collide with anything in the shell:

```bash
git add docs/superpowers/specs/2026-08-26-sac-rmv-split-design.md docs/superpowers/plans/2026-08-26-sac-rmv-split.md docs/superpowers/plans/2026-08-26-sac-rmv-relabel.md
git commit -m "docs: SAC and RMV split design and plans"
git push -u origin worktree-sac-rmv-split
cat > /tmp/sac-rmv-pr-body.md <<'PR'
## Summary

SAC (tank-pressure drop per minute, bar/min or psi/min) and RMV (surface gas volume per minute, L/min or cuft/min) measure different things: SAC is a property of one cylinder, RMV of the diver. The app treated them as one value with a unit toggle, which forced an asymmetric rule (volume sums all tanks, pressure reads back gas only) and a label that was wrong in one mode. Discussions #354 and #803.

This PR names the two lanes, the way MacDive does, and replaces the SAC unit toggle with a display preference.

## What changes for divers

- **Settings > Units > Gas consumption**: SAC, RMV, or Both (new installs default to Both). Existing users land on the lane they were seeing: L/min becomes RMV, pressure/min becomes SAC.
- **Dive detail**: a SAC row and an RMV row (or one of them). RMV without a cylinder volume keeps the "add a cylinder volume" hint from #1298.
- **Consumption by segment** and the **gas statistics page**: a SAC | RMV control when both lanes are on.
- **Cylinders card**: one line per lane per cylinder.
- **Dive table**: independent SAC and RMV columns, both sortable. Saved layouts that named the old column are migrated to the lane the diver was on; layouts synced from older builds resolve through a permanent alias.
- **German**: AMV stays for the volume rate; the pressure rate is Druckverbrauch.

## Under the hood

- `GasConsumptionDisplay { sac, rmv, both }` replaces `SacUnit`; surfaces render each lane behind `showsSac` / `showsRmv`.
- `UnitFormatter.formatSac` / `formatRmv` replace ten hand-rolled `/min` strings, with unit-aware decimals (no decimal for psi/min, two for cuft/min).
- `Dive.sac`, `Dive.rmvFor`, `CylinderSac.rmv` name the lanes; the math is unchanged and the existing SAC tests pass with the same numbers.
- Schema v170 renames `diver_settings.sac_unit` to `gas_consumption_display`, maps the values, and rewrites saved dive-table layouts per diver without an HLC bump. The sync compatibility floor rises to 170 (a synced column rename), with receiving-side tolerance for the old key and values.

## Testing

- New: migration test at the 169 -> 170 rung, legacy sync-key test, formatter lane tests, table column and sort tests, detail-row tests across all three modes with and without volume, segment-card and statistics lane-control tests, settings picker test, German terminology assertions for both lanes.
- `flutter test` full suite green; `flutter analyze` clean.

Follows the relabel PR (planner and calculators now say RMV).
PR
gh pr create --title "feat: represent SAC and RMV as separate quantities" --body-file /tmp/sac-rmv-pr-body.md
```

---

## Self-review notes

**Spec coverage.** D1 naming: Task 2 (entities), relabel plan (UnitAxis). D2 enums: Task 3. D3 settings state: Task 4. D4 migration: Task 5. D5 sync and floor: Task 5. D6 settings UI and wizard: Tasks 4 (wizard) and 13 (tile and picker). D7 formatter: Task 6. D8 labels: Tasks 1 and 14. D9 surfaces: detail summary Task 7, segment card Task 8, cylinders card Task 9, range stats Task 10 (dead parameter removed; see the deviation note there), profile chart Task 11, list cards and dive table Task 6, statistics Task 12, planner and calculators in the relabel plan, appearance settings via the Task 1 key values. Error handling: null lanes (Tasks 7 and 9), migration robustness (Task 5 tests), cross-version sync (Task 5 legacy-key test), layout width (Task 9 stacked lines). Testing section: every bullet has a task. Sequencing: the relabel plan is the first PR; this plan is the second.

**Deviations from the spec, each recorded in the task that makes it.** (1) The range-stats panel never rendered a consumption rate; its `sacUnit` parameter was dead, so Task 10 removes it instead of adding lanes. (2) The cylinders card shows two stacked lines under Both rather than one joined line, because its trailing column is narrow and right-aligned. (3) The chart's legend and metric names are lane-neutral ("Gas consumption") rather than switching between SAC and RMV, because the chart draws one bar/min curve and only its tooltip converts; the tooltip row carries the lane. (4) The records section uses four keys (`bestSac`, `bestRmv`, `highestSac`, `highestRmv`) instead of a placeholder, because German grammar differs by lane (Bestes AMV, Niedrigster Druckverbrauch). (5) The spec expected an older peer to ignore the unknown wire key; on inspection it fills its own `sacUnit` default instead, which is exactly the case the compatibility-floor rules cover, so the floor rises to 170 (Task 5). (6) The spec's "release notes" step is not a task: this repo writes release notes at release time from the merged PR list.

**Type consistency.** `GasConsumptionDisplay` / `GasConsumptionLane` (Task 3) are the names used in Tasks 4-14. `formatSac` / `formatRmv` / `sacSymbol` / `rmvSymbol` / `convertSac` / `convertRmv` (Task 6) are the names used in Tasks 7-13. `sacSegmentsLaneProvider` / `sacSegmentsLaneOverrideProvider` (Task 8) and `statisticsGasLaneProvider` / `statisticsGasLaneOverrideProvider` (Task 12) are each defined before use. `gasConsumptionTooltipRow` returns a `({String label, String value})` record and both chart sites read `.label` / `.value`. The l10n getters named in Task 1's Interfaces block are the only new keys any later task reads.

**Known soft spots for the executor.** Task 8's segment-card widget test depends on the pump helper and fixture inside `dive_detail_sac_segments_hint_test.dart`, which this plan did not reproduce; read that file first. Task 13's settings test assumes the Units tiles are reachable from `SettingsPage` the way the file's other unit-picker tests reach them. Task 5's `_applyDiverSettingDefaults` edit assumes the local map is named `merged` and is returned at the end of the method (verified at lines 5569 and 5713 when this plan was written).
