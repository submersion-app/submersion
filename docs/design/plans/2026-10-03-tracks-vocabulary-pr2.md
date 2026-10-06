# Tracks Vocabulary (PR 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every user-facing string that calls an underwater track a "route" says "track" instead, in all 11 locales, with every changed key renamed.

**Architecture:** One data table (old key, new key, value per locale) drives a script that renames each key in all 11 ARB files (including the English `@key` metadata) and sets its new value; a second mechanical pass renames the getters at every call site; a third rewrites the old English literals tests assert. A guard test fails while any in-scope string still says "route" in the locales whose word for route differs from their word for track, and keeps it from coming back.

**Tech Stack:** Flutter gen-l10n (ARB), Dart tests, Python 3.14 helper scripts.

**Spec:** `docs/design/specs/2026-10-02-tracks-navigation-consolidation-design.md`, section "Vocabulary (PR 2)". Tracking issue #2833. Stacked on PR 1 (#2840).

## Decisions (from the user, 2026-10-03)

- **Wording:** the full term "underwater track" wherever a string can be seen outside an underwater-only screen (titles, entry points, the dive detail section, dive edit, import, the Tracks page hint, the 3D toggle, import errors, the post-save snackbar); plain "track" inside an underwater-only screen (detail, alignment, seascape and review pages, the dive section's own rows and menus).
- **3D captions:** "Show underwater track", "Recorded track", "Recorded track ({source})".
- **Keys:** every key whose value changes gets a new name; the old key is deleted from all 11 ARBs.
- **Out of scope** (a different meaning of "route", unchanged): `plannerMission_*` (dive plan route), `trips_detail_sectionTitle_voyageMap` (voyage route), `emergencyCard_chambersNoneNearby` ("route you to the nearest facility"), `startup_recovery_encryptedBackup_body` ("other routes"). Dart identifiers (`NavTrack`, `nav_track/`, `navTrack_*` key prefixes) and storage are untouched.

## Global Constraints

- Never write the em-dash character, nor en-dashes, double hyphens or spaced hyphens as prose punctuation, anywhere.
- No commit, PR or comment may mention Claude, Claude Code or Anthropic; no co-author or session trailers.
- All 11 ARB files (`ar de en es fr he hu it nl pt zh`) change together; `flutter gen-l10n` runs after every ARB holds its final value.
- A renamed key's `@` entry is renamed with it in every file that has one: `app_en.arb` carries full metadata, and the translated files carry empty `@` entries for the three `dive3d_*` keys.
- Each locale keeps its own term for track from PR 1: de Track / Unterwasser-Track, es track / track submarino, fr trace / trace sous-marine, it traccia / traccia subacquea, nl track / onderwatertrack, pt trilha / trilha subaquática, hu útvonal / víz alatti útvonal, he מסלול / מסלול תת-ימי, ar مسار / مسار تحت الماء, zh 轨迹 / 水下轨迹.
- Python helpers run as `PYTHONUTF8=1 python3.14`; the shell is zsh, so quote globs.
- Run `dart format .` before every commit; commit messages `i18n(tracks): ...` or `test(tracks): ...`, ending `Refs #2833`.
- Do not push or open the PR without asking the user.

## Review Focus

1. **A plural string losing a category.** Arabic and Hebrew plurals carry `one`, `two`, `few` branches; a rewrite that drops one falls back silently to `other` (guarded by the parity test in Task 1 and checked by rendering 1, 2 and 5 in Task 2).
2. **Placeholders moving.** `{error}`, `{source}` and `{count}` must survive in every locale, or gen-l10n emits a method that ignores its argument (Task 1's ARB parity test).
3. **A test that asserts absence passing vacuously.** `settings_manage_nav_routes_test.dart` and `quick_actions_card_test.dart` assert that "Underwater Routes" is absent; after the rename that text can never appear, so those assertions must keep guarding the removed tile and button by key, not only by the old text (Task 2).
4. **A call site keeping the old getter through a comment or string interpolation.** The rename pass must also catch doc comments naming a key, or they point at a key that no longer exists (Task 1's grep check).
5. **Hungarian spelling drift.** Existing route strings spell "vízalatti"; PR 1's Tracks strings spell "víz alatti". The new values use "víz alatti" throughout so the two features match (Task 1 table).

---

## Before Task 1: branch and workspace

PR 2 needs its own worktree and branch; this session's file tools cannot write into a second worktree, and the PR 1 worktree is under Auto-fix.

- If #2840 has merged: create the branch from `origin/main`.
- If #2840 is still open: create it from PR 1's head, and open PR 2 against `main` once PR 1 merges (rebase is not used; merge `main` in after PR 1 lands).

```bash
git fetch origin
git worktree add -b ericgriffin/tracks-vocabulary-pr2 /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/tracks-vocabulary-pr2 origin/ericgriffin/routes-navigation-consolidation-42940a
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/tracks-vocabulary-pr2
git branch --unset-upstream
git submodule update --init --recursive && flutter pub get && dart run build_runner build --delete-conflicting-outputs
```

Copy this plan into the new worktree's `docs/design/plans/` and commit it there first (`docs(tracks): plan the vocabulary pass, PR 2`).

---

### Task 1: Rename and reword the underwater track strings

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`
- Modify (getter rename only): every `lib/**/*.dart` and `test/**/*.dart` that references an old key
- Test: `test/l10n/underwater_track_vocabulary_test.dart`

**Interfaces:**
- Produces: the 30 new getters in the table below; the old 30 no longer exist.

**The table** (old key, new key, then values: en / ar / de / es / fr / he / hu / it / nl / pt / zh). This table is the single source of truth: Step 3's script embeds it verbatim.

| # | old key | new key |
| --- | --- | --- |
| 1 | `universalImport_summary_importAsRoute` | `universalImport_summary_importAsUnderwaterTrack` |
| 2 | `dive3d_seascape_showRoute` | `dive3d_seascape_showUnderwaterTrack` |
| 3 | `dive3d_spatial_recordedPath` | `dive3d_spatial_recordedTrack` |
| 4 | `dive3d_spatial_recordedPathWithSource` | `dive3d_spatial_recordedTrackWithSource` |
| 5 | `navTrack_common_loadError` | `navTrack_common_trackLoadError` |
| 6 | `navTrack_common_notFound` | `navTrack_common_trackNotFound` |
| 7 | `navTrack_detail_renameTitle` | `navTrack_detail_renameTrackTitle` |
| 8 | `navTrack_detail_deleteTitle` | `navTrack_detail_deleteTrackTitle` |
| 9 | `navTrack_detail_defaultTitle` | `navTrack_detail_defaultTrackTitle` |
| 10 | `navTrack_review_title` | `navTrack_review_importTrackTitle` |
| 11 | `navTrack_review_saveError` | `navTrack_review_trackSaveError` |
| 12 | `navTrack_review_warningDuplicate` | `navTrack_review_trackDuplicateWarning` |
| 13 | `navTrack_review_saveConfirmation` | `navTrack_review_trackSavedConfirmation` |
| 14 | `navTrack_list_pendingChoice` | `navTrack_list_pendingTrackChoice` |
| 15 | `navTrack_seascape_title` | `navTrack_seascape_trackTitle` |
| 16 | `navTrack_seascape_noScene` | `navTrack_seascape_trackNoScene` |
| 17 | `navTrack_handoff_description` | `navTrack_handoff_trackDescription` |
| 18 | `navTrack_handoff_reviewButton` | `navTrack_handoff_reviewTrackButton` |
| 19 | `navTrack_section_title` | `navTrack_section_trackTitle` |
| 20 | `navTrack_section_routeCount` | `navTrack_section_trackCount` |
| 21 | `navTrack_section_noRouteLinked` | `navTrack_section_noTrackLinked` |
| 22 | `navTrack_section_linkButton` | `navTrack_section_linkTrackButton` |
| 23 | `navTrack_section_menuOpen` | `navTrack_section_menuOpenTrack` |
| 24 | `navTrack_editRow_loadFailed` | `navTrack_editRow_tracksLoadFailed` |
| 25 | `navTrack_editSheet_removeTooltip` | `navTrack_editSheet_removeTrackTooltip` |
| 26 | `navTrack_editRow_saveFailed` | `navTrack_editRow_tracksSaveFailed` |
| 27 | `navTrack_importError_tooShort` | `navTrack_importError_trackTooShort` |
| 28 | `navTrack_importError_tooLarge` | `navTrack_importError_trackTooLarge` |
| 29 | `diveDetailSection_navTrack_name` | `diveDetailSection_navTrack_trackName` |
| 30 | `diveDetailSection_navTrack_description` | `diveDetailSection_navTrack_trackDescription` |

- [ ] **Step 1: Write the failing guard test**

`test/l10n/underwater_track_vocabulary_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Keys that name an underwater track (spec 2026-10-02, "Vocabulary
/// (PR 2)"). A key is in scope by prefix; the four listed exact keys are the
/// 3D and import strings that live outside the nav-track prefixes.
const _prefixes = ['navTrack_', 'diveDetailSection_navTrack_'];
const _exact = {
  'universalImport_summary_importAsUnderwaterTrack',
  'dive3d_seascape_showUnderwaterTrack',
  'dive3d_spatial_recordedTrack',
  'dive3d_spatial_recordedTrackWithSource',
};

/// Each locale's word for "route", where it differs from its word for
/// "track". Hungarian, Hebrew and Arabic use one word for both, so they
/// have nothing to guard.
final _routeWords = <String, RegExp>{
  'en': RegExp(r'\broutes?\b', caseSensitive: false),
  'de': RegExp(r'\bRouten?\b'),
  'es': RegExp(r'\brutas?\b', caseSensitive: false),
  'fr': RegExp(r'\btrajets?\b', caseSensitive: false),
  'it': RegExp(r'\bpercors[oi]\b', caseSensitive: false),
  'nl': RegExp(r'\broutes?\b', caseSensitive: false),
  'pt': RegExp(r'\brotas?\b', caseSensitive: false),
  'zh': RegExp('路线'),
};

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(
          File(p.join('lib', 'l10n', 'arb', 'app_$locale.arb')).readAsStringSync(),
        )
        as Map<String, dynamic>;

bool _inScope(String key) =>
    !key.startsWith('@') &&
    (_exact.contains(key) || _prefixes.any(key.startsWith));

void main() {
  for (final entry in _routeWords.entries) {
    test('${entry.key}: no underwater track string says route', () {
      final offenders = [
        for (final MapEntry(:key, :value) in _arb(entry.key).entries)
          if (_inScope(key) && entry.value.hasMatch('$value')) '$key: $value',
      ];
      expect(offenders, isEmpty);
    });
  }

  test('the renamed keys exist in every locale and the old ones are gone', () {
    const renamed = {
      'navTrack_section_title': 'navTrack_section_trackTitle',
      'navTrack_list_pendingChoice': 'navTrack_list_pendingTrackChoice',
      'dive3d_spatial_recordedPath': 'dive3d_spatial_recordedTrack',
      'universalImport_summary_importAsRoute':
          'universalImport_summary_importAsUnderwaterTrack',
    };
    for (final locale in ['ar', 'de', 'en', 'es', 'fr', 'he', 'hu', 'it', 'nl', 'pt', 'zh']) {
      final arb = _arb(locale);
      for (final MapEntry(key: old, value: renamedTo) in renamed.entries) {
        expect(arb.containsKey(old), isFalse, reason: '$locale still has $old');
        expect(arb.containsKey(renamedTo), isTrue, reason: '$locale lacks $renamedTo');
      }
    }
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/l10n/underwater_track_vocabulary_test.dart`
Expected: FAIL; the `en` case lists offenders such as `navTrack_section_title: Underwater Route`, and the rename case reports `en still has navTrack_section_title`.

- [ ] **Step 3: Rename and reword in all 11 ARBs**

```bash
PYTHONUTF8=1 python3.14 - <<'EOF'
import json, pathlib, re

LOCALES = ['en', 'ar', 'de', 'es', 'fr', 'he', 'hu', 'it', 'nl', 'pt', 'zh']
T = [
 ('universalImport_summary_importAsRoute', 'universalImport_summary_importAsUnderwaterTrack',
  ['Import as underwater track', 'استيراد كمسار تحت الماء', 'Als Unterwasser-Track importieren', 'Importar como track submarino', 'Importer comme trace sous-marine', 'ייבוא כמסלול תת-ימי', 'Importálás víz alatti útvonalként', 'Importa come traccia subacquea', 'Importeren als onderwatertrack', 'Importar como trilha subaquática', '作为水下轨迹导入']),
 ('dive3d_seascape_showRoute', 'dive3d_seascape_showUnderwaterTrack',
  ['Show underwater track', 'إظهار المسار تحت الماء', 'Unterwasser-Track anzeigen', 'Mostrar track submarino', 'Afficher la trace sous-marine', 'הצג מסלול תת-ימי', 'Víz alatti útvonal megjelenítése', 'Mostra traccia subacquea', 'Onderwatertrack tonen', 'Mostrar trilha subaquática', '显示水下轨迹']),
 ('dive3d_spatial_recordedPath', 'dive3d_spatial_recordedTrack',
  ['Recorded track', 'مسار مسجّل', 'Aufgezeichneter Track', 'Track grabado', 'Trace enregistrée', 'מסלול מוקלט', 'Rögzített útvonal', 'Traccia registrata', 'Opgenomen track', 'Trilha registrada', '记录的轨迹']),
 ('dive3d_spatial_recordedPathWithSource', 'dive3d_spatial_recordedTrackWithSource',
  ['Recorded track ({source})', 'مسار مسجّل ({source})', 'Aufgezeichneter Track ({source})', 'Track grabado ({source})', 'Trace enregistrée ({source})', 'מסלול מוקלט ({source})', 'Rögzített útvonal ({source})', 'Traccia registrata ({source})', 'Opgenomen track ({source})', 'Trilha registrada ({source})', '记录的轨迹（{source}）']),
 ('navTrack_common_loadError', 'navTrack_common_trackLoadError',
  ['Could not load this track.', 'تعذر تحميل هذا المسار.', 'Dieser Track konnte nicht geladen werden.', 'No se pudo cargar este track.', 'Impossible de charger cette trace.', 'לא ניתן היה לטעון את המסלול הזה.', 'Ezt az útvonalat nem sikerült betölteni.', 'Non è stato possibile caricare questa traccia.', 'Deze track kon niet worden geladen.', 'Não foi possível carregar esta trilha.', '无法加载此轨迹。']),
 ('navTrack_common_notFound', 'navTrack_common_trackNotFound',
  ['Track not found.', 'المسار غير موجود.', 'Track nicht gefunden.', 'Track no encontrado.', 'Trace introuvable.', 'המסלול לא נמצא.', 'Útvonal nem található.', 'Traccia non trovata.', 'Track niet gevonden.', 'Trilha não encontrada.', '未找到轨迹。']),
 ('navTrack_detail_renameTitle', 'navTrack_detail_renameTrackTitle',
  ['Rename track', 'إعادة تسمية المسار', 'Track umbenennen', 'Cambiar nombre del track', 'Renommer la trace', 'שינוי שם המסלול', 'Útvonal átnevezése', 'Rinomina traccia', 'Track hernoemen', 'Renomear trilha', '重命名轨迹']),
 ('navTrack_detail_deleteTitle', 'navTrack_detail_deleteTrackTitle',
  ['Delete track?', 'حذف المسار؟', 'Track löschen?', '¿Eliminar track?', 'Supprimer la trace ?', 'למחוק את המסלול?', 'Útvonal törlése?', 'Eliminare la traccia?', 'Track verwijderen?', 'Excluir trilha?', '删除轨迹？']),
 ('navTrack_detail_defaultTitle', 'navTrack_detail_defaultTrackTitle',
  ['Underwater track', 'مسار تحت الماء', 'Unterwasser-Track', 'Track submarino', 'Trace sous-marine', 'מסלול תת-ימי', 'Víz alatti útvonal', 'Traccia subacquea', 'Onderwatertrack', 'Trilha subaquática', '水下轨迹']),
 ('navTrack_review_title', 'navTrack_review_importTrackTitle',
  ['Import Underwater Track', 'استيراد مسار تحت الماء', 'Unterwasser-Track importieren', 'Importar track submarino', 'Importer une trace sous-marine', 'ייבוא מסלול תת-ימי', 'Víz alatti útvonal importálása', 'Importa traccia subacquea', 'Onderwatertrack importeren', 'Importar trilha subaquática', '导入水下轨迹']),
 ('navTrack_review_saveError', 'navTrack_review_trackSaveError',
  ['Could not save this track: {error}', 'تعذر حفظ هذا المسار: {error}', 'Dieser Track konnte nicht gespeichert werden: {error}', 'No se pudo guardar este track: {error}', "Impossible d'enregistrer cette trace : {error}", 'לא ניתן היה לשמור את המסלול הזה: {error}', 'Nem sikerült menteni ezt az útvonalat: {error}', 'Impossibile salvare questa traccia: {error}', 'Deze track kon niet worden opgeslagen: {error}', 'Não foi possível salvar esta trilha: {error}', '无法保存此轨迹：{error}']),
 ('navTrack_review_warningDuplicate', 'navTrack_review_trackDuplicateWarning',
  ['This looks like a track already imported from the same file.', 'يبدو هذا مسارًا تم استيراده مسبقًا من الملف نفسه.', 'Dies sieht nach einem bereits aus derselben Datei importierten Track aus.', 'Esto parece un track ya importado del mismo archivo.', 'Ceci ressemble à une trace déjà importée depuis le même fichier.', 'זה נראה כמו מסלול שכבר יובא מאותו קובץ.', 'Ez egy már ugyanabból a fájlból importált útvonalnak tűnik.', 'Questa sembra una traccia già importata dallo stesso file.', 'Dit lijkt op een track die al uit hetzelfde bestand is geïmporteerd.', 'Isso parece uma trilha já importada do mesmo arquivo.', '这看起来像是已从同一文件导入过的轨迹。']),
 ('navTrack_review_saveConfirmation', 'navTrack_review_trackSavedConfirmation',
  ['Underwater track saved.', 'تم حفظ المسار تحت الماء.', 'Unterwasser-Track gespeichert.', 'Track submarino guardado.', 'Trace sous-marine enregistrée.', 'המסלול התת-ימי נשמר.', 'Víz alatti útvonal mentve.', 'Traccia subacquea salvata.', 'Onderwatertrack opgeslagen.', 'Trilha subaquática salva.', '水下轨迹已保存。']),
 ('navTrack_list_pendingChoice', 'navTrack_list_pendingTrackChoice',
  ['{count, plural, one{{count} underwater track needs your choice} other{{count} underwater tracks need your choice}}',
   '{count, plural, one{مسار تحت الماء واحد ينتظر اختيارك} two{مساران تحت الماء ينتظران اختيارك} few{{count} مسارات تحت الماء تنتظر اختيارك} other{{count} مسار تحت الماء ينتظر اختيارك}}',
   '{count, plural, one{{count} Unterwasser-Track wartet auf deine Wahl} other{{count} Unterwasser-Tracks warten auf deine Wahl}}',
   '{count, plural, one{{count} track submarino espera tu elección} other{{count} tracks submarinos esperan tu elección}}',
   '{count, plural, one{{count} trace sous-marine attend votre choix} other{{count} traces sous-marines attendent votre choix}}',
   '{count, plural, one{מסלול תת-ימי אחד ממתין לבחירתך} two{שני מסלולים תת-ימיים ממתינים לבחירתך} other{{count} מסלולים תת-ימיים ממתינים לבחירתך}}',
   '{count, plural, one{{count} víz alatti útvonal vár a választásodra} other{{count} víz alatti útvonal vár a választásodra}}',
   '{count, plural, one{{count} traccia subacquea attende la tua scelta} other{{count} tracce subacquee attendono la tua scelta}}',
   '{count, plural, one{{count} onderwatertrack wacht op je keuze} other{{count} onderwatertracks wachten op je keuze}}',
   '{count, plural, one{{count} trilha subaquática aguarda sua escolha} other{{count} trilhas subaquáticas aguardam sua escolha}}',
   '{count, plural, other{{count} 条水下轨迹等待你的选择}}']),
 ('navTrack_seascape_title', 'navTrack_seascape_trackTitle',
  ['Track seascape', 'المشهد البحري للمسار', 'Track-Unterwasserwelt', 'Paisaje submarino del track', 'Paysage sous-marin de la trace', 'נוף תת-ימי של המסלול', 'Útvonal tengeri tája', 'Paesaggio subacqueo della traccia', 'Onderwaterlandschap van de track', 'Paisagem subaquática da trilha', '轨迹的海景']),
 ('navTrack_seascape_noScene', 'navTrack_seascape_trackNoScene',
  ['This track has no usable seascape.', 'لا يحتوي هذا المسار على مشهد بحري قابل للاستخدام.', 'Für diesen Track gibt es keine nutzbare Unterwasserwelt.', 'Este track no tiene un paisaje submarino disponible.', "Cette trace n'a pas de paysage sous-marin exploitable.", 'למסלול הזה אין נוף תת-ימי שמיש.', 'Ehhez az útvonalhoz nincs használható tengeri táj.', 'Questa traccia non ha un paesaggio subacqueo utilizzabile.', 'Deze track heeft geen bruikbaar onderwaterlandschap.', 'Esta trilha não tem uma paisagem subaquática utilizável.', '此轨迹没有可用的海景。']),
 ('navTrack_handoff_description', 'navTrack_handoff_trackDescription',
  ['This is an underwater track, not a dive log. It has its own place in Submersion, separate from your dive import.', 'هذا مسار تحت الماء، وليس سجل غطس. له مكانه الخاص في Submersion، منفصل عن استيراد غطساتك.', 'Dies ist ein Unterwasser-Track, kein Tauchprotokoll. Er hat seinen eigenen Platz in Submersion, getrennt von deinem Tauchgang-Import.', 'Esto es un track submarino, no un registro de inmersión. Tiene su propio lugar en Submersion, separado de tu importación de inmersiones.', 'Ceci est une trace sous-marine, pas un journal de plongée. Elle a sa propre place dans Submersion, séparée de votre import de plongées.', 'זהו מסלול תת-ימי, לא יומן צלילה. יש לו מקום משלו ב-Submersion, נפרד מייבוא הצלילות שלך.', 'Ez egy víz alatti útvonal, nem merülésnapló. Saját helye van a Submersionben, elkülönítve a merülés-importálástól.', "Questa è una traccia subacquea, non un registro di immersione. Ha un posto tutto suo in Submersion, separato dall'importazione delle tue immersioni.", 'Dit is een onderwatertrack, geen duiklog. Deze heeft een eigen plek in Submersion, los van je duikimport.', 'Esta é uma trilha subaquática, não um registro de mergulho. Ela tem seu próprio lugar no Submersion, separado da sua importação de mergulhos.', '这是一条水下轨迹，不是潜水日志。它在 Submersion 中有自己的位置，与你的潜水记录导入分开。']),
 ('navTrack_handoff_reviewButton', 'navTrack_handoff_reviewTrackButton',
  ['Review underwater track', 'مراجعة المسار تحت الماء', 'Unterwasser-Track prüfen', 'Revisar track submarino', 'Vérifier la trace sous-marine', 'בדיקת המסלול התת-ימי', 'Víz alatti útvonal áttekintése', 'Rivedi traccia subacquea', 'Onderwatertrack bekijken', 'Revisar trilha subaquática', '查看水下轨迹']),
 ('navTrack_section_title', 'navTrack_section_trackTitle',
  ['Underwater Track', 'مسار تحت الماء', 'Unterwasser-Track', 'Track submarino', 'Trace sous-marine', 'מסלול תת-ימי', 'Víz alatti útvonal', 'Traccia subacquea', 'Onderwatertrack', 'Trilha subaquática', '水下轨迹']),
 ('navTrack_section_routeCount', 'navTrack_section_trackCount',
  ['{count, plural, one{{count} track} other{{count} tracks}}',
   '{count, plural, one{مسار واحد} two{مساران} few{{count} مسارات} other{{count} مسار}}',
   '{count, plural, one{{count} Track} other{{count} Tracks}}',
   '{count, plural, one{{count} track} other{{count} tracks}}',
   '{count, plural, one{{count} trace} other{{count} traces}}',
   '{count, plural, one{מסלול אחד} two{שני מסלולים} other{{count} מסלולים}}',
   '{count, plural, one{{count} útvonal} other{{count} útvonal}}',
   '{count, plural, one{{count} traccia} other{{count} tracce}}',
   '{count, plural, one{{count} track} other{{count} tracks}}',
   '{count, plural, one{{count} trilha} other{{count} trilhas}}',
   '{count, plural, other{{count} 条轨迹}}']),
 ('navTrack_section_noRouteLinked', 'navTrack_section_noTrackLinked',
  ['No track linked', 'لا يوجد مسار مرتبط', 'Kein Track verknüpft', 'Ningún track vinculado', 'Aucune trace liée', 'אין מסלול מקושר', 'Nincs társított útvonal', 'Nessuna traccia collegata', 'Geen track gekoppeld', 'Nenhuma trilha vinculada', '未关联轨迹']),
 ('navTrack_section_linkButton', 'navTrack_section_linkTrackButton',
  ['Link track', 'ربط مسار', 'Track verknüpfen', 'Vincular track', 'Lier une trace', 'קישור מסלול', 'Útvonal társítása', 'Collega traccia', 'Track koppelen', 'Vincular trilha', '关联轨迹']),
 ('navTrack_section_menuOpen', 'navTrack_section_menuOpenTrack',
  ['Open track', 'فتح المسار', 'Track öffnen', 'Abrir track', 'Ouvrir la trace', 'פתיחת המסלול', 'Útvonal megnyitása', 'Apri traccia', 'Track openen', 'Abrir trilha', '打开轨迹']),
 ('navTrack_editRow_loadFailed', 'navTrack_editRow_tracksLoadFailed',
  ['Could not load underwater tracks', 'تعذر تحميل المسارات تحت الماء', 'Unterwasser-Tracks konnten nicht geladen werden', 'No se pudieron cargar los tracks submarinos', 'Impossible de charger les traces sous-marines', 'לא ניתן לטעון את המסלולים התת-ימיים', 'Nem sikerült betölteni a víz alatti útvonalakat', 'Impossibile caricare le tracce subacquee', 'Kan onderwatertracks niet laden', 'Não foi possível carregar as trilhas subaquáticas', '无法加载水下轨迹']),
 ('navTrack_editSheet_removeTooltip', 'navTrack_editSheet_removeTrackTooltip',
  ['Remove track', 'إزالة المسار', 'Track entfernen', 'Quitar track', 'Retirer la trace', 'הסרת מסלול', 'Útvonal eltávolítása', 'Rimuovi traccia', 'Track verwijderen', 'Remover trilha', '移除轨迹']),
 ('navTrack_editRow_saveFailed', 'navTrack_editRow_tracksSaveFailed',
  ["Could not update this dive's underwater tracks: {error}", 'تعذر تحديث مسارات هذه الغوصة تحت الماء: {error}', 'Unterwasser-Tracks dieses Tauchgangs konnten nicht aktualisiert werden: {error}', 'No se pudieron actualizar los tracks submarinos de esta inmersión: {error}', 'Impossible de mettre à jour les traces sous-marines de cette plongée : {error}', 'לא ניתן לעדכן את המסלולים התת-ימיים של צלילה זו: {error}', 'Nem sikerült frissíteni a merülés víz alatti útvonalait: {error}', 'Impossibile aggiornare le tracce subacquee di questa immersione: {error}', 'Kan de onderwatertracks van deze duik niet bijwerken: {error}', 'Não foi possível atualizar as trilhas subaquáticas deste mergulho: {error}', '无法更新此潜水的水下轨迹：{error}']),
 ('navTrack_importError_tooShort', 'navTrack_importError_trackTooShort',
  ['This recording has too few samples to be a usable underwater track.', 'يحتوي هذا التسجيل على عدد قليل جدًا من العينات ليكون مسارًا تحت الماء قابلاً للاستخدام.', 'Diese Aufzeichnung hat zu wenige Messpunkte für einen brauchbaren Unterwasser-Track.', 'Esta grabación tiene muy pocas muestras para ser un track submarino utilizable.', "Cet enregistrement a trop peu d'échantillons pour constituer une trace sous-marine utilisable.", 'בהקלטה זו יש מעט מדי דגימות כדי להיות מסלול תת-ימי שמיש.', 'Ez a felvétel túl kevés mintát tartalmaz ahhoz, hogy használható víz alatti útvonal legyen.', 'Questa registrazione ha troppo pochi campioni per essere una traccia subacquea utilizzabile.', 'Deze opname heeft te weinig metingen om een bruikbare onderwatertrack te zijn.', 'Esta gravação tem amostras insuficientes para ser uma trilha subaquática utilizável.', '此记录的样本太少，无法成为可用的水下轨迹。']),
 ('navTrack_importError_tooLarge', 'navTrack_importError_trackTooLarge',
  ['This recording has more samples than an underwater track can store.', 'يحتوي هذا التسجيل على عينات أكثر مما يمكن لمسار تحت الماء تخزينه.', 'Diese Aufzeichnung hat mehr Messpunkte, als ein Unterwasser-Track speichern kann.', 'Esta grabación tiene más muestras de las que un track submarino puede almacenar.', "Cet enregistrement contient plus d'échantillons qu'une trace sous-marine ne peut en stocker.", 'בהקלטה זו יש יותר דגימות ממה שמסלול תת-ימי יכול לאחסן.', 'Ez a felvétel több mintát tartalmaz, mint amennyit egy víz alatti útvonal tárolni tud.', 'Questa registrazione ha più campioni di quanti una traccia subacquea possa memorizzare.', 'Deze opname heeft meer metingen dan een onderwatertrack kan opslaan.', 'Esta gravação tem mais amostras do que uma trilha subaquática pode armazenar.', '此记录的样本数超过了水下轨迹可存储的上限。']),
 ('diveDetailSection_navTrack_name', 'diveDetailSection_navTrack_trackName',
  ['Underwater Track', 'مسار تحت الماء', 'Unterwasser-Track', 'Track submarino', 'Trace sous-marine', 'מסלול תת-ימי', 'Víz alatti útvonal', 'Traccia subacquea', 'Onderwatertrack', 'Trilha subaquática', '水下轨迹']),
 ('diveDetailSection_navTrack_description', 'diveDetailSection_navTrack_trackDescription',
  ['Measured underwater track from a navigation console', 'مسار تحت الماء تم قياسه من وحدة تحكم ملاحية', 'Gemessener Unterwasser-Track aus einer Navigationskonsole', 'Track submarino medido desde una consola de navegación', 'Trace sous-marine mesurée depuis une console de navigation', 'מסלול תת-ימי שנמדד ממסוף ניווט', 'Navigációs konzolról mért víz alatti útvonal', 'Traccia subacquea misurata da una consolle di navigazione', 'Gemeten onderwatertrack vanaf een navigatieconsole', 'Trilha subaquática medida a partir de um console de navegação', '通过导航控制台测量的水下轨迹']),
]
assert len(T) == 30
KEY = re.compile(r'^  "(@?)([^"]+)":')
for i, loc in enumerate(LOCALES):
    path = pathlib.Path(f'lib/l10n/arb/app_{loc}.arb')
    text = path.read_text(encoding='utf-8')
    existing = set(json.loads(text))
    lines = text.split('\n')
    for old, new, values in T:
        assert old in existing, (loc, old)
        assert new not in existing, (loc, new, 'already exists')
        assert values[i], (loc, old)
        idx = next(n for n, l in enumerate(lines) if l.startswith(f'  "{old}":'))
        lines[idx] = f'  {json.dumps(new)}: {json.dumps(values[i], ensure_ascii=False)},'
        meta = [n for n, l in enumerate(lines) if l.startswith(f'  "@{old}":')]
        for n in meta:
            lines[n] = lines[n].replace(f'"@{old}"', f'"@{new}"', 1)
    path.write_text('\n'.join(lines), encoding='utf-8')
    json.loads(path.read_text(encoding='utf-8'))
print('renamed', len(T), 'keys in', len(LOCALES), 'files')
EOF
```

Expected: `renamed 30 keys in 11 files`. Then `git diff --numstat -- lib/l10n/arb` shows every ARB with equal added and removed counts, 33 in each translated file (30 keys plus the three `dive3d_*` `@` entries) and 38 in English (its `@` metadata lines too). Verified by a dry run on 2026-10-03.

- [ ] **Step 4: Rename the getters at every call site**

```bash
PYTHONUTF8=1 python3.14 - <<'EOF'
import pathlib, re, subprocess
PAIRS = [line.split() for line in """
universalImport_summary_importAsRoute universalImport_summary_importAsUnderwaterTrack
dive3d_seascape_showRoute dive3d_seascape_showUnderwaterTrack
dive3d_spatial_recordedPathWithSource dive3d_spatial_recordedTrackWithSource
dive3d_spatial_recordedPath dive3d_spatial_recordedTrack
navTrack_common_loadError navTrack_common_trackLoadError
navTrack_common_notFound navTrack_common_trackNotFound
navTrack_detail_renameTitle navTrack_detail_renameTrackTitle
navTrack_detail_deleteTitle navTrack_detail_deleteTrackTitle
navTrack_detail_defaultTitle navTrack_detail_defaultTrackTitle
navTrack_review_title navTrack_review_importTrackTitle
navTrack_review_saveError navTrack_review_trackSaveError
navTrack_review_warningDuplicate navTrack_review_trackDuplicateWarning
navTrack_review_saveConfirmation navTrack_review_trackSavedConfirmation
navTrack_list_pendingChoice navTrack_list_pendingTrackChoice
navTrack_seascape_title navTrack_seascape_trackTitle
navTrack_seascape_noScene navTrack_seascape_trackNoScene
navTrack_handoff_description navTrack_handoff_trackDescription
navTrack_handoff_reviewButton navTrack_handoff_reviewTrackButton
navTrack_section_title navTrack_section_trackTitle
navTrack_section_routeCount navTrack_section_trackCount
navTrack_section_noRouteLinked navTrack_section_noTrackLinked
navTrack_section_linkButton navTrack_section_linkTrackButton
navTrack_section_menuOpen navTrack_section_menuOpenTrack
navTrack_editRow_loadFailed navTrack_editRow_tracksLoadFailed
navTrack_editSheet_removeTooltip navTrack_editSheet_removeTrackTooltip
navTrack_editRow_saveFailed navTrack_editRow_tracksSaveFailed
navTrack_importError_tooShort navTrack_importError_trackTooShort
navTrack_importError_tooLarge navTrack_importError_trackTooLarge
diveDetailSection_navTrack_name diveDetailSection_navTrack_trackName
diveDetailSection_navTrack_description diveDetailSection_navTrack_trackDescription
""".strip().split('\n')]
files = subprocess.run(['git', 'ls-files', 'lib/*.dart', 'test/*.dart'], capture_output=True, text=True).stdout.split()
changed = 0
for f in files:
    if f.startswith('lib/l10n/arb/'):
        continue
    p = pathlib.Path(f)
    raw = p.read_bytes(); crlf = b'\r\n' in raw
    s = raw.decode('utf-8').replace('\r\n', '\n')
    new = s
    for old, nw in PAIRS:
        new = re.sub(rf'\b{old}\b', nw, new)
    if new != s:
        if crlf: new = new.replace('\n', '\r\n')
        p.write_bytes(new.encode('utf-8')); changed += 1
print('updated', changed, 'files')
EOF
```

`recordedPathWithSource` is listed before `recordedPath` so the longer name is replaced first; `\b` keeps `recordedPath` from matching inside it either way.

Then regenerate and check nothing still names an old key:

```bash
flutter gen-l10n && dart format . && flutter analyze
grep -rnwE "universalImport_summary_importAsRoute|dive3d_seascape_showRoute|dive3d_spatial_recordedPath|navTrack_section_title|navTrack_list_pendingChoice|diveDetailSection_navTrack_name" lib test --include='*.dart' | grep -v "lib/l10n/arb/"
```

Expected: gen-l10n and analyze clean; the grep prints nothing.

- [ ] **Step 5: Run the guard and the l10n suite**

Run: `flutter test test/l10n/`
Expected: all PASS, including `underwater_track_vocabulary_test.dart` and the placeholder and plural parity tests.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/arb test/l10n/underwater_track_vocabulary_test.dart $(git diff --name-only -- lib test | grep -v '^lib/l10n/arb/') && git commit -m "i18n(tracks): call underwater routes tracks, in every locale

Every string that named an underwater route says track now, the full
\"underwater track\" wherever it can be seen outside an underwater-only
screen. Each changed key is renamed, so no stale translation survives.

Refs #2833"
```

---

### Task 2: Bring the tests' English expectations along

**Files:**
- Modify: the tests below that assert old English text (found in planning):
  `test/features/import_wizard/presentation/widgets/import_summary_step_test.dart`,
  `test/features/dive_3d/presentation/pages/spatial_site_page_test.dart`,
  `test/features/dive_3d/presentation/spatial_site_page_caption_test.dart`,
  `test/features/nav_track/domain/entities/nav_track_test.dart`,
  `test/features/site_scape/presentation/path_provenance_chip_test.dart`,
  `test/features/site_scape/presentation/site_terrain_pane_playback_test.dart`,
  `test/features/nav_track/presentation/pages/nav_track_align_page_test.dart`,
  `test/features/nav_track/presentation/pages/nav_track_detail_page_test.dart`,
  `test/features/nav_track/presentation/pages/nav_track_import_review_page_test.dart`,
  `test/features/nav_track/presentation/pages/nav_track_seascape_page_test.dart`,
  `test/features/nav_track/presentation/widgets/nav_track_handoff_card_test.dart`,
  `test/features/nav_track/presentation/widgets/nav_track_section_test.dart`,
  `test/features/tracks/presentation/pages/tracks_page_test.dart`,
  `test/features/dive_log/presentation/pages/dive_nav_track_section_visibility_test.dart`,
  `test/features/dive_log/presentation/pages/dive_edit_route_links_test.dart`,
  `test/features/dive_log/presentation/widgets/edit_sections/route_row_test.dart`,
  `test/features/dive_log/presentation/widgets/edit_sections/route_link_sheet_test.dart`

**Interfaces:**
- Consumes: the English values from Task 1's table.

- [ ] **Step 1: See which tests fail on the old wording**

Run: `flutter test test/features/nav_track test/features/tracks test/features/dive_log/presentation test/features/dive_3d test/features/site_scape test/features/import_wizard/presentation/widgets 2>&1 | tail -40`
Expected: FAIL; the failures are `find.text`/`findsOneWidget` expectations still naming route wording (for example `Expected: exactly one matching candidate ... "Link route"`). This is the red step for the tests' half of the rename.

- [ ] **Step 2: Rewrite the quoted English literals**

Only whole quoted literals change, so `'Underwater Routes'` (asserted absent by the tile and quick-action guards) is untouched:

```bash
PYTHONUTF8=1 python3.14 - <<'EOF'
import pathlib, subprocess
MAP = {
 'Import as route': 'Import as underwater track',
 'Show route': 'Show underwater track',
 'Recorded route': 'Recorded track',
 'Could not load this route.': 'Could not load this track.',
 'Route not found.': 'Track not found.',
 'Rename route': 'Rename track',
 'Delete route?': 'Delete track?',
 'Import Underwater Route': 'Import Underwater Track',
 'Route saved.': 'Underwater track saved.',
 '1 route needs your choice': '1 underwater track needs your choice',
 'Route seascape': 'Track seascape',
 'This route has no usable seascape.': 'This track has no usable seascape.',
 'Review route': 'Review underwater track',
 'Underwater Route': 'Underwater Track',
 'No route linked': 'No track linked',
 'Link route': 'Link track',
 'Open route': 'Open track',
 'Could not load routes': 'Could not load underwater tracks',
 'This recording has too few samples to be a usable route.': 'This recording has too few samples to be a usable underwater track.',
 'This recording has more samples than a route can store.': 'This recording has more samples than an underwater track can store.',
}
# Literal prefixes inside longer quoted strings (a source or error appended).
PREFIX = {
 'Recorded route (': 'Recorded track (',
 'Could not save this route: ': 'Could not save this track: ',
 "Could not update this dive's underwater routes: ": "Could not update this dive's underwater tracks: ",
}
files = subprocess.run(['git', 'ls-files', 'test/*.dart'], capture_output=True, text=True).stdout.split()
for f in files:
    p = pathlib.Path(f); raw = p.read_bytes(); crlf = b'\r\n' in raw
    s = raw.decode('utf-8').replace('\r\n', '\n'); new = s
    for old, nw in MAP.items():
        for q in ("'", '"'):
            new = new.replace(f'{q}{old}{q}', f'{q}{nw}{q}')
    for old, nw in PREFIX.items():
        for q in ("'", '"'):
            new = new.replace(f'{q}{old}', f'{q}{nw}')
    if new != s:
        if crlf: new = new.replace('\n', '\r\n')
        p.write_bytes(new.encode('utf-8')); print('updated', f)
EOF
```

- [ ] **Step 3: Keep the absence guards meaningful**

`settings_manage_nav_routes_test.dart` and `quick_actions_card_test.dart` assert "Underwater Routes" is absent. That text no longer exists in the app at all, so those assertions would pass even if the tile or button came back under the new wording. Add the new wording to each:

In `test/features/settings/presentation/pages/settings_manage_nav_routes_test.dart`, after `expect(find.text('Underwater Routes'), findsNothing);` add:

```dart
    expect(find.text('Underwater Track'), findsNothing);
```

In `test/features/dashboard/presentation/quick_actions_card_test.dart`, in `there is no Underwater Routes quick action`, add:

```dart
    expect(find.text('Underwater Track'), findsNothing);
    expect(find.textContaining('nderwater'), findsNothing);
```

- [ ] **Step 4: Render the plurals once**

Add to `test/l10n/underwater_track_vocabulary_test.dart`:

```dart
  test('plural counts render in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final n in [1, 2, 5]) {
        expect(l10n.navTrack_list_pendingTrackChoice(n), isNotEmpty, reason: '$locale $n');
        expect(l10n.navTrack_section_trackCount(n), isNotEmpty, reason: '$locale $n');
      }
    }
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.navTrack_list_pendingTrackChoice(1), '1 underwater track needs your choice');
    expect(en.navTrack_list_pendingTrackChoice(2), '2 underwater tracks need your choice');
    expect(en.navTrack_section_trackCount(2), '2 tracks');
  });
```

with imports `package:flutter/widgets.dart` and `package:submersion/l10n/arb/app_localizations.dart`.

- [ ] **Step 5: Run the affected suites**

Run: `flutter test test/features/nav_track test/features/tracks test/features/dive_log/presentation test/features/dive_3d test/features/site_scape test/features/import_wizard/presentation/widgets test/features/settings/presentation/pages/settings_manage_nav_routes_test.dart test/features/dashboard test/l10n`
Expected: all PASS. Any remaining failure names old wording the literal map missed; fix that literal by hand and add nothing else.

- [ ] **Step 6: Scan code for hard-coded route wording**

```bash
grep -rnE "['\"][^'\"]*\b[Rr]outes?\b[^'\"]*['\"]" lib/features/nav_track lib/features/tracks lib/features/dive_log/presentation/widgets/edit_sections lib/features/site_scape lib/features/dive_3d --include='*.dart' | grep -v "^\s*//" | grep -v "GoRoute\|routeId\|route\.\|routes:\|Route<\|_route\|routeRepository\|MaterialPageRoute\|PageRoute"
```

Expected: no user-visible literal. A hit that is visible text (a semantics label, a tooltip not from l10n) is a bug: move it into the ARBs with Task 1's script shape, or report it.

- [ ] **Step 7: Commit**

```bash
dart format . && git add test && git commit -m "test(tracks): expect track wording, keep the removed-tile guards honest

Refs #2833"
```

---

### Task 3: Verify, spec note, screenshots, PR

**Files:**
- Modify: `docs/design/specs/2026-10-02-tracks-navigation-consolidation-design.md`

- [ ] **Step 1: Note the wording rule in the spec**

Under "Vocabulary (PR 2)", replace the opening rule with: "User-facing "route" becomes "track": the full "underwater track" wherever a string can be seen outside an underwater-only screen, plain "track" inside one. Every key whose value changes is renamed, and the old key is deleted from all 11 locales. Out of scope: the dive planner's route, a trip's voyage route, the emergency card and the startup recovery text, which use "route" in another sense."

- [ ] **Step 2: Whole-project checks and one full suite run**

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test test/architecture test/l10n
df -h /Volumes/fltmp && bash scripts/run_all_tests.sh
```

Expected: clean; all PASS.

- [ ] **Step 3: Dash and attribution scan**

```bash
git diff origin/ericgriffin/routes-navigation-consolidation-42940a...HEAD | grep -nP "^\+.*\x{2014}"; git log origin/ericgriffin/routes-navigation-consolidation-42940a..HEAD --format=%B | grep -niE "claude|anthropic|co-authored"
```

Expected: no output.

- [ ] **Step 4: Screenshots**

With a throwaway golden test (fonts and icon fonts loaded in `setUpAll`, real theme), capture before and after, light, at phone width: the dive detail Underwater Track section with one linked track; the underwater track detail page; the Tracks page with the pending-choice hint; the import handoff card. Hand them to the user; delete the throwaway test.

- [ ] **Step 5: Commit the spec note and stop**

```bash
git add docs/design/specs/2026-10-02-tracks-navigation-consolidation-design.md && git commit -m "docs(tracks): record the track wording rule for PR 2

Refs #2833"
```

Then ask the user before pushing or opening the PR. The PR body says `Refs #2833` (PR 1 closes it), lists the 30 renamed keys, and states the out-of-scope uses of "route".
