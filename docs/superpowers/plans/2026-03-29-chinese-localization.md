# Chinese (Simplified) Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Simplified Chinese (`zh`) as the 11th supported language, translating all 4,378 keys with full Chinese character dive terminology.

**Architecture:** Create `app_zh.arb` with all translations following the same pattern as existing language files (e.g., `app_de.arb`). Add locale option to the language settings page. Run Flutter codegen to regenerate localization delegates.

**Tech Stack:** Flutter l10n (ARB files), `intl` package, `flutter_localizations`

**Spec:** `docs/superpowers/specs/2026-03-29-chinese-localization-design.md`

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `lib/l10n/arb/app_zh.arb` | All 4,378 Simplified Chinese translations |
| Modify | `lib/features/settings/presentation/pages/language_settings_page.dart` | Add `zh` locale option |
| Regenerated | `lib/l10n/arb/app_localizations.dart` | Localization delegate (auto-generated) |
| Regenerated | `lib/l10n/arb/app_localizations_zh.dart` | Chinese locale class (auto-generated) |

## Translation Conventions (Reference for All Translation Tasks)

### General rules

- Translate ALL text to Simplified Chinese characters. No English loanwords for dive terminology.
- Preserve all ICU message syntax exactly: `{placeholder}` names, `{count, plural, =1{...} other{...}}` structure, etc.
- Only translate the human-readable text INSIDE the ICU structures, never the placeholder names or ICU keywords.
- Keys are alphabetically sorted in the output file.

### ARB file structure for translation files

Translation ARB files follow this structure (based on `app_de.arb` pattern):

```json
{
  "@@locale": "zh",
  "@@last_modified": "2026-03-29",
  "@key_with_placeholders": {
    "placeholders": {
      "paramName": { "type": "int" }
    }
  },
  "translated_key": "中文翻译"
}
```

- Include `@@locale` and `@@last_modified` headers.
- Include `@`-prefixed metadata entries ONLY for keys where the German ARB (`app_de.arb`) includes them (15 entries with placeholder type definitions). These are keys where the placeholder types need explicit definition in the translation file.
- Do NOT copy the 769 description-only metadata entries from `app_en.arb`.

### Dive terminology reference

| English | Chinese | Context |
|---------|---------|---------|
| BCD / Buoyancy Control Device | 浮力控制装置 | Equipment |
| Nitrox | 高氧空气 | Gas mix |
| Trimix | 三混气 | Gas mix |
| Dive buddy | 潜伴 | Social |
| Regulator | 调节器 | Equipment |
| Wetsuit | 湿衣 | Equipment |
| Drysuit | 干衣 | Equipment |
| Logbook / Dive log | 潜水日志 | Core feature |
| Dive site | 潜水点 | Location |
| Dive computer | 潜水电脑 | Equipment |
| Surface interval | 水面间隔 | Timing |
| Decompression | 减压 | Safety |
| No-decompression limit (NDL) | 免减压极限 | Safety |
| Safety stop | 安全停留 | Safety |
| Air | 空气 | Gas |
| Oxygen (O2) | 氧气 | Gas |
| Helium (He) | 氦气 | Gas |
| Certification | 证书 | Training |
| Marine life | 海洋生物 | Biology |
| Visibility | 能见度 | Conditions |
| Current | 水流 | Conditions |
| Depth | 深度 | Measurement |
| Duration / Bottom time | 潜水时间 / 底部时间 | Measurement |
| Tank / Cylinder | 气瓶 | Equipment |
| Pressure | 压力 | Measurement |
| Altitude | 海拔 | Location |
| Gear / Equipment | 装备 | Equipment |
| Fins | 脚蹼 | Equipment |
| Mask | 面镜 | Equipment |
| Snorkel | 呼吸管 | Equipment |
| Weight belt | 配重带 | Equipment |
| Dive center | 潜水中心 | Location |
| Instructor | 教练 | Training |
| Open water | 开放水域 | Dive type |
| Night dive | 夜潜 | Dive type |
| Drift dive | 放流潜水 | Dive type |
| Wreck dive | 沉船潜水 | Dive type |
| Cave dive | 洞穴潜水 | Dive type |
| Shore dive | 岸潜 | Dive type |
| Boat dive | 船潜 | Dive type |
| Ascent rate | 上升速率 | Safety |
| Descent rate | 下降速率 | Safety |
| CNS (Central Nervous System toxicity) | 中枢神经系统毒性 | Safety |
| PPO2 (Partial Pressure of Oxygen) | 氧分压 | Safety |
| MOD (Maximum Operating Depth) | 最大作业深度 | Safety |
| EAD (Equivalent Air Depth) | 等效空气深度 | Safety |
| END (Equivalent Narcotic Depth) | 等效麻醉深度 | Safety |
| Trip | 旅行 | Organization |
| Tag | 标签 | Organization |
| Statistics | 统计 | Feature |
| Dashboard | 仪表盘 | Feature |
| Settings | 设置 | Feature |
| Backup | 备份 | Feature |
| Import | 导入 | Feature |
| Export | 导出 | Feature |
| Profile | 轮廓 / 档案 | Context-dependent: dive profile vs user profile |
| Tide | 潮汐 | Conditions |
| Service record | 维护记录 | Equipment maintenance |

### ICU plural translation pattern

English:
```
{count, plural, =1{1 dive} other{{count} dives}}
```

Chinese (no plural form distinction, but preserve the ICU structure):
```
{count, plural, =1{1 次潜水} other{{count} 次潜水}}
```

Note: Chinese does not have grammatical plurals, but the ICU `plural` syntax must be preserved for Flutter's parser. Use the same text for `=1` and `other` forms, varying only the count value.

### UI text conventions

| Pattern | Chinese convention |
|---------|-------------------|
| "Save" / "Cancel" / "Delete" buttons | 保存 / 取消 / 删除 |
| "Edit {name}" | 编辑 {name} |
| "Are you sure?" confirmations | 确定要...吗？ |
| "No {items} found" | 未找到{items} |
| "Loading..." | 加载中... |
| "Search {items}" | 搜索{items} |
| "{count} items selected" | 已选择 {count} 个项目 |

---

## Task 1: Create app_zh.arb with all Chinese translations

**Files:**
- Read: `lib/l10n/arb/app_en.arb` (source - 9,567 lines, 4,378 translatable keys)
- Read: `lib/l10n/arb/app_de.arb` (structure reference - shows which metadata entries to include)
- Create: `lib/l10n/arb/app_zh.arb`

This task is the bulk of the work. The implementing agent reads the English ARB in chunks (~2,000 lines at a time), translates all non-metadata keys to Simplified Chinese, and writes the complete Chinese ARB file.

**Key counts by feature area (for verification):**

| Prefix | Count | | Prefix | Count |
|--------|-------|-|--------|-------|
| accessibility | 43 | | importWizard | 1 |
| backup | 58 | | maps | 43 |
| buddies | 113 | | marineLife | 75 |
| certifications | 168 | | media | 114 |
| common | 11 | | nav | 19 |
| courses | 80 | | onboarding | 10 |
| dashboard | 77 | | planning | 36 |
| decoCalculator | 26 | | settings | 441 |
| diveCenters | 130 | | signatures | 29 |
| diveComputer | 113 | | statistics | 256 |
| diveDetailSection | 34 | | surfaceInterval | 44 |
| diveImport | 93 | | tags | 28 |
| diveLog | 675 | | tank | 24 |
| divePlanner | 112 | | tankPresets | 44 |
| diveSites | 278 | | theme | 5 |
| diveTypes | 19 | | tides | 37 |
| divers | 104 | | tools | 32 |
| enum | 263 | | transfer | 88 |
| equipment | 259 | | trips | 206 |
| formatter | 4 | | units | 27 |
| gas | 32 | | universalImport | 45 |
| gasCalculators | 68 | | weightCalc | 14 |
| **Total** | **4,378** | | | |

- [ ] **Step 1: Study the translation file structure**

Read `lib/l10n/arb/app_de.arb` (first 30 lines) to understand:
- The `@@locale` and `@@last_modified` header entries
- Which `@`-prefixed metadata entries are included (only 15 entries with placeholder type definitions)
- The alphabetical key ordering

The German file has this structure:
```json
{
  "@@last_modified": "2026-02-10",
  "@@locale": "de",
  "@trips_itinerary_dayLabel": {
    "placeholders": { "dayNumber": { "type": "int" } }
  },
  ... (14 more metadata entries)
  "accessibility_dialog_keyboardShortcutsTitle": "Tastenkombinationen",
  ... (4,378 translated keys alphabetically)
}
```

- [ ] **Step 2: Read app_en.arb lines 1-2000**

Read `lib/l10n/arb/app_en.arb` offset 0, limit 2000. Extract all non-metadata keys (lines that do NOT start with `"@`). These are the translatable keys. Note the key names and English values. Begin building the Chinese translations.

- [ ] **Step 3: Read app_en.arb lines 2001-4000**

Read `lib/l10n/arb/app_en.arb` offset 2000, limit 2000. Continue extracting and translating keys.

- [ ] **Step 4: Read app_en.arb lines 4001-6000**

Read `lib/l10n/arb/app_en.arb` offset 4000, limit 2000. Continue extracting and translating keys.

- [ ] **Step 5: Read app_en.arb lines 6001-8000**

Read `lib/l10n/arb/app_en.arb` offset 6000, limit 2000. Continue extracting and translating keys.

- [ ] **Step 6: Read app_en.arb lines 8001-9567**

Read `lib/l10n/arb/app_en.arb` offset 8000, limit 2000. Continue extracting and translating remaining keys.

- [ ] **Step 7: Write complete app_zh.arb**

Write the file `lib/l10n/arb/app_zh.arb` containing:
1. `"@@locale": "zh"` and `"@@last_modified": "2026-03-29"` headers
2. The 15 metadata entries (copy from `app_de.arb` - these define placeholder types for keys that need them in translation files)
3. All 4,378 translated keys in alphabetical order

Follow all translation conventions from the reference section above.

- [ ] **Step 8: Verify translation count**

Run:
```bash
python3 -c "
import json
with open('lib/l10n/arb/app_zh.arb') as f:
    data = json.load(f)
keys = [k for k in data if not k.startswith('@')]
print(f'Translated keys: {len(keys)}')
assert len(keys) == 4378, f'Expected 4378, got {len(keys)}'
print('Key count verified.')
"
```

Expected: `Translated keys: 4378` and `Key count verified.`

- [ ] **Step 9: Validate JSON syntax**

Run:
```bash
python3 -c "
import json
with open('lib/l10n/arb/app_zh.arb') as f:
    json.load(f)
print('JSON is valid.')
"
```

Expected: `JSON is valid.`

---

## Task 2: Add Chinese locale to language settings page

**Files:**
- Modify: `lib/features/settings/presentation/pages/language_settings_page.dart:10-38`

- [ ] **Step 1: Read the current file**

Read `lib/features/settings/presentation/pages/language_settings_page.dart`.

- [ ] **Step 2: Add Chinese locale option**

The existing list is ordered as: system, en, es, fr, de, it, nl, pt, hu, ar, he. Add `zh` after `he` (Hebrew), keeping non-Latin scripts grouped at the end.

Use the Edit tool to insert after the Hebrew entry:
```dart
    _LocaleOption(
      code: 'he',
      nativeName: '\u05E2\u05D1\u05E8\u05D9\u05EA',
      englishName: 'Hebrew',
    ),
```

Replace with:
```dart
    _LocaleOption(
      code: 'he',
      nativeName: '\u05E2\u05D1\u05E8\u05D9\u05EA',
      englishName: 'Hebrew',
    ),
    _LocaleOption(
      code: 'zh',
      nativeName: '\u4E2D\u6587',
      englishName: 'Chinese',
    ),
```

- [ ] **Step 3: Format**

Run:
```bash
dart format lib/features/settings/presentation/pages/language_settings_page.dart
```

Expected: No formatting changes (or minor formatting applied).

---

## Task 3: Run codegen and verification

**Files:**
- Regenerated: `lib/l10n/arb/app_localizations.dart`
- Regenerated: `lib/l10n/arb/app_localizations_zh.dart`

- [ ] **Step 1: Run flutter gen-l10n**

Run:
```bash
flutter gen-l10n
```

Expected: Completes without errors. Generates `app_localizations_zh.dart`.

- [ ] **Step 2: Verify generated file exists**

Run:
```bash
ls -la lib/l10n/arb/app_localizations_zh.dart
```

Expected: File exists.

- [ ] **Step 3: Run flutter analyze**

Run:
```bash
flutter analyze
```

Expected: No issues found.

- [ ] **Step 4: Run flutter test**

Run:
```bash
flutter test
```

Expected: All tests pass.

---

## Task 4: Commit

- [ ] **Step 1: Stage files**

Run:
```bash
git add lib/l10n/arb/app_zh.arb lib/l10n/arb/app_localizations.dart lib/l10n/arb/app_localizations_zh.dart lib/features/settings/presentation/pages/language_settings_page.dart
```

- [ ] **Step 2: Commit**

Run:
```bash
git commit -m "feat: add Simplified Chinese (zh) localization

Translate all 4,378 keys to Simplified Chinese with full Chinese
character dive terminology. Add zh locale option to language settings.

Closes #104"
```

Expected: Commit succeeds.
