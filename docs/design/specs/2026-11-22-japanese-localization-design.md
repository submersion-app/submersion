# Japanese localization (issue #4833)

## Intent

A Japanese diver asked for Submersion in Japanese. Japanese becomes the 12th
app language on the same footing as the other 11: every string translated,
offered in the language picker, used for stored place names, printed in PDFs
with Japanese glyph shapes, and formatted with Japanese dates and numbers.

## Goals

- `lib/l10n/arb/app_ja.arb` with all 17,060 keys translated, placeholders and
  ICU plural and select forms intact, passing the existing guards in
  `test/l10n/` (parity, placeholders, untranslated English values).
- 日本語 in the language picker, after 简体中文.
- `ja` in `PlaceNameLanguage.supportedCodes`, so reverse-geocoded place names
  can be stored in Japanese.
- PDF export in Japanese uses Noto Sans JP (regular and bold) as the base font,
  so kanji print in Japanese shapes, not the Chinese ones Noto Sans SC draws.
- Japanese sea names in `assets/data/sea_areas.json`, from Wikidata, through
  `scripts/sea_area_harvester.py`.
- The UI shows Japanese glyph shapes when the app language is Japanese (on
  web, when the browser language is Japanese too; see UI glyphs).
- Dates and numbers come from `intl`'s `ja` locale; a test pins one of each.

## Non-goals

- Review by a native speaker before merge. The PR invites the issue author to
  review; corrections land as follow-up issues, as for other languages.
- Any change to the wording of the existing 11 languages. Two shared fixes
  that Japanese needed do touch them, without changing what they say:
  open-ended date ranges (`formatter_dateRange_from` / `_until`) take the date
  as a placeholder, so each language places it in its own word order (every
  language but Japanese keeps its connector-then-date wording); and
  `joinSentences` joins multi-sentence messages, which also ends Chinese
  sentences with 。 instead of a Latin ". ".
- Machine translation inside the app.

## Anti-goals

- Chinese glyph shapes anywhere a Japanese reader sees kanji.
- A translation that reads as a word-for-word calque of English, or that uses
  Chinese dive terms where Japanese divers use katakana loanwords.

## Approaches

Translation is almost all of the work (about 500,000 characters of English).

1. **Parallel shards against one glossary (chosen).** A glossary and style guide
   (below) is written first. The keys are split by prefix into slices; one
   agent translates each slice. This session merges, validates every key,
   placeholder and plural form, scans for glossary drift and spot-reads each
   slice. Fastest, and the glossary keeps the slices consistent.
2. All in one session, batch by batch. The most consistent voice, but many
   hours of work and many context compactions.
3. Shards with a human glossary review first. Better terminology, but it waits
   on a reviewer the project does not have.

The maintainer chose 1.

## Design

### Wiring

- `LanguageSettingsPage.supportedLocales`: `LocaleOption(code: 'ja',
  nativeName: '日本語', englishName: 'Japanese')` after `zh`.
- `PlaceNameLanguage.supportedCodes`: `ja` after `zh`.
- `PdfFonts._scriptFontsFor`: `'ja' => (regular:
  PdfGoogleFonts.notoSansJPRegular, bold: PdfGoogleFonts.notoSansJPBold)`.
  Noto Sans JP covers Latin, so it is the base font like Noto Sans SC.
- `scripts/sea_area_harvester.py`: `ja` joins the translation languages; the
  table is regenerated.
- Tests that list the languages gain `ja`.

### UI glyphs

Flutter's `Text` passes the app locale to the text engine, which picks
Japanese CJK fallback glyphs on iOS, macOS, Android and Windows.

On web, the engine's fallback manager ranks its Noto fonts by
`navigator.language` (`font_fallback_service.dart`, `_selectBestFont`), not
by the app locale. A browser set to Japanese gets Noto Sans JP. Japanese
chosen in the app inside a browser set to another language was checked on a
web build: it loads Noto Sans SC and TC subsets, so kanji take Chinese
shapes. A Noto Sans JP fallback through `google_fonts` would fix that case
but costs about 5.3 MB per weight (about 16 MB for the three weights the app
uses). The maintainer chose to leave it as a known limitation: the case
needs a Japanese reader using a non-Japanese browser, and every native
platform is unaffected.

## Glossary and style guide

This section is the reference for every Japanese string, now and in later
features.

### Style

- Sentences (messages, descriptions, help text, dialogs) use です/ます.
- Labels, buttons, menu items, column headers and titles are short noun
  phrases without a final 。: 保存, 削除, 最大水深, ダイブを追加.
- Questions in confirm dialogs: 「このダイブを削除しますか？」 style.
- Full-width Japanese punctuation in Japanese text: 、。「」（）？！：
  Quotation marks around names and terms use 「」. Keep ASCII punctuation
  inside code, formats, units and English names.
- No space between Japanese text and numbers or placeholders
  (`{count}本のダイブ`). Keep the space between a number and a Latin unit
  (`{depth} m`) when English has it.
- ASCII digits everywhere.
- Count dives with 本 (`{count}本`, `1本目`), the way Japanese divers do.
  Other counters: 件 for records and items, 回 for occurrences, 日 for days,
  枚 for photos, 人 for people, 個 for things.
- Placeholders (`{name}`) stay exactly as in English, never translated, and
  each one English uses appears in the translation.
- ICU `plural` and `select`: keep the variable, the keyword and every
  selector English has (`=0`, `=1`, `other`, select cases) with the same
  placeholders inside. Japanese has no grammatical plural, so the branches
  often read the same; that is fine.
- Brand names, product names, file formats, agency names (PADI, SSI, NAUI,
  GUE, TDI, BSAC), agency course names and model names stay as written.
- Abbreviations divers read as-is stay in Latin letters: BCD, SAC, RMV, NDL,
  GF, MOD, END, CNS, OTU, ppO2, CCR, SCR, OC, DPV, SMB, EANx, GPS, PDF, CSV.

### Terms

| English | Japanese |
| --- | --- |
| dive (noun) | ダイブ (activity in general: ダイビング) |
| dive log, logbook | ダイブログ, ログブック |
| log a dive | ダイブを記録 |
| dive site | ダイブサイト (short: サイト) |
| dive centre, dive shop | ダイブセンター |
| trip | トリップ |
| buddy | バディ |
| diver | ダイバー |
| equipment, gear | 器材 |
| cylinder, tank | タンク (シリンダー only where text contrasts the two) |
| twin set | ツインタンク |
| regulator | レギュレーター |
| wetsuit, drysuit | ウェットスーツ, ドライスーツ |
| weights, weight belt | ウェイト, ウェイトベルト |
| mask, fins, hood, gloves, boots | マスク, フィン, フード, グローブ, ブーツ |
| dive computer | ダイブコンピューター |
| rebreather | リブリーザー |
| setpoint, diluent, bailout | セットポイント, ディリュエント, ベイルアウト |
| reel, spool | リール, スプール |
| service (gear) | メンテナンス |
| gas, air, oxygen, nitrogen, helium | ガス, 空気, 酸素, 窒素, ヘリウム |
| nitrox, trimix, heliox | ナイトロックス, トライミックス, ヘリオックス |
| gas mix | 混合ガス |
| decompression, deco stop | 減圧, 減圧停止 |
| safety stop | 安全停止 |
| no-decompression limit | 無減圧限界 (NDL) |
| gradient factors | グラディエントファクター (GF) |
| ceiling | シーリング |
| tissue, tissue loading | 組織, 組織負荷 |
| descent, ascent, ascent rate | 潜降, 浮上, 浮上速度 |
| surface interval | 水面休息時間 |
| bottom time, runtime | ボトムタイム, ランタイム |
| depth, max depth, average depth | 水深, 最大水深, 平均水深 |
| water temperature | 水温 |
| visibility | 透明度 |
| current | 流れ |
| entry, exit | エントリー, エキジット |
| shore dive, boat dive | ビーチダイブ, ボートダイブ |
| night dive, drift dive | ナイトダイブ, ドリフトダイブ |
| gas consumption | ガス消費 |
| partial pressure of oxygen | 酸素分圧 (ppO2) |
| maximum operating depth | 最大運用水深 (MOD) |
| oxygen toxicity | 酸素中毒 |
| altitude dive | 高所ダイビング |
| fresh water, salt water | 淡水, 海水 |
| dive planner, plan | ダイブプランナー, プラン |
| profile | プロファイル |
| waypoint | ウェイポイント |
| certification, certification card | 認定, Cカード |
| certification agency | 指導団体 |
| course, instructor | コース, インストラクター |
| species (the app's Species pages and sections) | 生物; 種 only inside compounds such as 種のカタログ. The app no longer says "marine life", so avoid 海洋生物 in labels |
| sighting | 観察記録 |
| species common name | the standard Japanese name (標準和名) in katakana when known with confidence; otherwise a katakana rendering of the English common name. Scientific names stay in Latin. |
| statistics, insights, dashboard | 統計, インサイト, ダッシュボード |
| tag, media, photo, video, document | タグ, メディア, 写真, 動画, ドキュメント |
| checklist | チェックリスト |
| signature | 署名 |
| emergency card | 緊急カード |
| settings, units | 設定, 単位 |
| import, export | インポート, エクスポート |
| sync, backup, restore | 同期, バックアップ, 復元 |
| save, cancel, delete, edit, add | 保存, キャンセル, 削除, 編集, 追加 |
| close, done, undo, retry | 閉じる, 完了, 元に戻す, 再試行 |
| sign in, sign out | サインイン, サインアウト |
| search, filter, sort | 検索, フィルター, 並べ替え |

### Terms settled during translation

These recurred across slices and were made consistent after the merge.

| English | Japanese |
| --- | --- |
| finding (safety review, gear condition) | 所見 |
| liveaboard | クルーズ船 (dive type: クルーズ) |
| no-fly | 飛行機搭乗禁止 |
| working pressure | 使用圧力 |
| tissue compartment, leading compartment | 組織コンパートメント, 支配コンパートメント |
| M-value | M値 |
| isobaric counterdiffusion | 等圧逆拡散 |
| turn pressure, rock bottom, minimum gas | ターンプレッシャー, ロックボトム, ミニマムガス |
| contingency | コンティンジェンシー |
| transmitter | トランスミッター |
| near-miss | ヒヤリハット |
| surface conditions | 海況 |
| wreck | 沈船 |
| fill station | 充填所 |
| seascape (3D view) | 海中景観 |
| draft dive | 下書き |
| recovery code, passphrase | リカバリーコード, パスフレーズ |
| sync conflict | 競合 |
| rule, query | ルール, クエリ |
| type-to-confirm words | translated, like other locales: 削除, 置き換え, 削除 {name} |

## Left to the builder

- Shard boundaries, merge tooling and validation scripts (scratch only; the
  committed checks are the existing `test/l10n/` guards).
- Which `ja` values legitimately stay English and need a `keptEnglishValues`
  entry with a reason.
- Terms not in the glossary, chosen in the same spirit and added here when
  they recur.
