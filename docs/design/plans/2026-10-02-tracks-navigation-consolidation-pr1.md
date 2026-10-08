# Tracks Navigation Consolidation (PR 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the GPS Log nav destination with a Tracks destination whose landing page lists and maps GPS tracks and underwater tracks together, with every page under `/tracks`.

**Architecture:** A new `lib/features/tracks/` module composes the existing `gps_log` and `nav_track` features: a sealed `TrackListItem` wraps either entity, pure functions merge, filter, cap and summarise them, and one page renders the merged list beside one overview map. `gps_log` and `nav_track` keep their data layers and detail pages; neither depends on `tracks`. Paths live in `lib/core/router/track_locations.dart` so every caller and the router share them.

**Tech Stack:** Flutter, Riverpod 3 (`flutter_riverpod`, legacy `StateProvider` via `core/providers/provider.dart`), go_router 17, flutter_map, gen-l10n ARB files (11 locales).

**Spec:** `docs/design/specs/2026-10-02-tracks-navigation-consolidation-design.md` (tracking issue #2833)

## Global Constraints

- Never write the em-dash character, nor en-dashes, double hyphens or spaced hyphens as prose punctuation, in code, comments, strings, commit messages or PR text.
- No commit, PR or comment may mention Claude, Claude Code or Anthropic; no `Co-Authored-By` or session trailers.
- Commit messages use the repo style `type(scope): summary`; new-string commits use `i18n(tracks): ...`.
- Every new user-facing string is added to all 11 ARB files (`ar de en es fr he hu it nl pt zh`) with real translations; `flutter gen-l10n` runs only after every ARB holds its translation.
- Only `app_en.arb` is alphabetical and only it carries `@key` metadata; the ten translated files are feature-grouped, so new keys are inserted after an anchor key.
- Generated l10n methods take placeholders in ALPHABETICAL order; test the rendered text.
- Paths come from `lib/core/router/track_locations.dart`; never hand-write `/tracks/...` strings outside that file and the router tests.
- Paths in tests are built with `p.join(...)`; no literal `/tmp`.
- A test that replaces process-wide state (`GeolocatorPlatform.instance`, `FilePickerPlatform.instance`, surface size) restores it with `addTearDown`.
- Anything showing units goes through `UnitFormatter(ref.watch(settingsProvider))`.
- Files stay under 800 lines (200 to 400 typical); imports grouped dart, flutter, packages, local.
- Run `dart format .` before every commit.
- Python helpers run as `PYTHONUTF8=1 python3.14 - <<'EOF'` (system python3 is 3.9).
- The shell is zsh: do not rely on unquoted word splitting; quote globs such as `--include='*.dart'`.
- Branch: `ericgriffin/routes-navigation-consolidation-42940a`. PR body links `Closes #2833, closes #2397`. Do not push or open the PR without asking the user.

## Review Focus

1. **Equal start times.** A GPS track and an underwater track (or two GPS tracks) starting at the same millisecond must keep a stable order across rebuilds; `List.sort` is not stable, so the merge needs an explicit tie-breaker (test in Task 3, with ties arriving in non-tie-break order).
2. **A synced nav order holding both `gps-log` and `tracks`.** An order written by this build (`tracks, gps-log`) and read back, or a mix from two devices, must collapse to one Tracks slot (test in Task 12).
3. **A selection the kind filter hides.** Selecting a GPS track on desktop and then filtering to Underwater must remove the info card rather than show a card for a row the list no longer has (test in Task 9).
4. **ENC files named `.CSV` or starting with a byte order mark.** Import detection must lower-case the extension and tolerate the BOM, or the file falls into the GPS column-mapping form (test in Task 5).
5. **Deleting the selected track.** Deleting the track whose info card is open must clear the selection so no card points at a deleted row (test in Task 9).

## File Map

Create:

| File | Responsibility |
| --- | --- |
| `lib/core/router/track_locations.dart` | Every Tracks path, shared by router and callers |
| `lib/features/tracks/domain/track_kind.dart` | `TrackKind`, `TrackKindFilter` |
| `lib/features/tracks/domain/track_list_item.dart` | Sealed `TrackListItem` and its two variants |
| `lib/features/tracks/domain/tracks_query.dart` | Pure merge, date bound, overview cap |
| `lib/features/tracks/domain/tracks_summary.dart` | Pure summary figures |
| `lib/features/tracks/presentation/providers/tracks_providers.dart` | Filter, list, overview, summary providers |
| `lib/features/tracks/application/tracks_match_controller.dart` | Runs both sweeps, returns one outcome |
| `lib/features/tracks/presentation/widgets/tracks_match_snackbar.dart` | Turns an outcome into a snackbar |
| `lib/features/tracks/presentation/tracks_import.dart` | One Import action with ENC detection |
| `lib/features/tracks/presentation/track_item_location.dart` | Detail path for a `TrackListItem` |
| `lib/features/tracks/presentation/widgets/track_kind_badge.dart` | "GPS" / "Underwater" chip |
| `lib/features/tracks/presentation/widgets/tracks_overview_map.dart` | One map drawing both kinds |
| `lib/features/tracks/presentation/widgets/tracks_map_pane.dart` | Loading/error/empty/map switch and info card |
| `lib/features/tracks/presentation/widgets/tracks_list_pane.dart` | Header plus merged rows |
| `lib/features/tracks/presentation/widgets/tracks_list_header.dart` | Record card, summary, filters, match, notices |
| `lib/features/tracks/presentation/widgets/track_kind_filter_control.dart` | Segmented All / GPS / Underwater |
| `lib/features/tracks/presentation/widgets/tracks_summary_strip.dart` | Summary figures card |
| `lib/features/tracks/presentation/widgets/tracks_empty_state.dart` | Empty and filtered-empty states |
| `lib/features/tracks/presentation/pages/tracks_page.dart` | Landing page |
| `lib/features/tracks/presentation/pages/tracks_map_page.dart` | Phone full-screen map |
| `lib/features/gps_log/presentation/widgets/gps_record_card.dart` | Extracted record card and `canRecordGpsTracks` |
| `lib/features/nav_track/presentation/widgets/nav_track_list_row.dart` | Extracted row and `formatNavTrackDetailLine` |
| `lib/features/nav_track/presentation/widgets/nav_track_info_card.dart` | Map info card for an underwater track |

Delete (Task 13): `gps_logger_page.dart`, `gps_track_map_page.dart`, `gps_log_list_pane.dart`, `gps_log_empty_state.dart`, `gps_log_summary_strip.dart`, `gps_track_overview_map.dart`, `nav_track_list_page.dart`, plus dead providers and their tests.

## Before Task 1

- [ ] Confirm the worktree is initialised (already true for this worktree; rerun if a fresh one is used):

```bash
git submodule update --init --recursive && flutter pub get && dart run build_runner build --delete-conflicting-outputs
```

Expected: completes without errors; `lib/core/database/database.g.dart` exists.

---

### Task 1: New strings in all locales

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`
- Test: `test/features/tracks/tracks_strings_test.dart`

**Interfaces:**
- Produces getters on `AppLocalizations`: `nav_tracks`, `nav_tracksSubtitle`, `tracks_kind_all`, `tracks_kind_gps`, `tracks_kind_underwater`, `tracks_match_button`, `tracks_match_none`, `tracks_match_partialError`, `tracks_empty_title`, `tracks_empty_body`, `tracks_empty_filtered`, `tracks_empty_clearFilters`, `tracks_map_noMappable`, and the method `tracks_match_result(int linked, int positioned)` (alphabetical argument order).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('the match result names each count in its own slot', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    // Generated methods take placeholders alphabetically: linked, positioned.
    expect(
      l10n.tracks_match_result(1, 2),
      'Dives positioned: 2 · Underwater tracks linked: 1',
    );
  });

  test('every locale carries a translated Tracks label', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(l10n.nav_tracks, isNotEmpty, reason: '$locale');
      if (locale.languageCode != 'en') {
        expect(
          l10n.tracks_empty_body,
          isNot(lookupAppLocalizations(const Locale('en')).tracks_empty_body),
          reason: '$locale fell back to English',
        );
      }
    }
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/tracks/tracks_strings_test.dart`
Expected: compile error, `The method 'tracks_match_result' isn't defined`.

- [ ] **Step 3: Insert the strings into every ARB**

Run from the worktree root:

```bash
PYTHONUTF8=1 python3.14 - <<'EOF'
import json, pathlib, re

ARB_DIR = pathlib.Path('lib/l10n/arb')
LOCALES = ['en', 'ar', 'de', 'es', 'fr', 'he', 'hu', 'it', 'nl', 'pt', 'zh']
S = {
  'nav_tracks': {'en': 'Tracks', 'ar': 'المسارات', 'de': 'Tracks', 'es': 'Tracks', 'fr': 'Traces', 'he': 'מסלולים', 'hu': 'Útvonalak', 'it': 'Tracce', 'nl': 'Tracks', 'pt': 'Trilhas', 'zh': '轨迹'},
  'nav_tracksSubtitle': {'en': 'GPS and underwater tracks', 'ar': 'مسارات GPS والمسارات تحت الماء', 'de': 'GPS- und Unterwasser-Tracks', 'es': 'Tracks GPS y submarinos', 'fr': 'Traces GPS et sous-marines', 'he': 'מסלולי GPS ומסלולים תת-ימיים', 'hu': 'GPS- és víz alatti útvonalak', 'it': 'Tracce GPS e subacquee', 'nl': 'GPS- en onderwatertracks', 'pt': 'Trilhas GPS e subaquáticas', 'zh': 'GPS 与水下轨迹'},
  'tracks_kind_all': {'en': 'All', 'ar': 'الكل', 'de': 'Alle', 'es': 'Todos', 'fr': 'Toutes', 'he': 'הכול', 'hu': 'Mind', 'it': 'Tutte', 'nl': 'Alle', 'pt': 'Todas', 'zh': '全部'},
  'tracks_kind_gps': {'en': 'GPS', 'ar': 'GPS', 'de': 'GPS', 'es': 'GPS', 'fr': 'GPS', 'he': 'GPS', 'hu': 'GPS', 'it': 'GPS', 'nl': 'GPS', 'pt': 'GPS', 'zh': 'GPS'},
  'tracks_kind_underwater': {'en': 'Underwater', 'ar': 'تحت الماء', 'de': 'Unterwasser', 'es': 'Submarinos', 'fr': 'Sous-marines', 'he': 'תת-ימיים', 'hu': 'Víz alatti', 'it': 'Subacquee', 'nl': 'Onderwater', 'pt': 'Subaquáticas', 'zh': '水下'},
  'tracks_match_button': {'en': 'Match tracks to dives', 'ar': 'مطابقة المسارات مع الغطسات', 'de': 'Tracks mit Tauchgängen abgleichen', 'es': 'Asociar tracks a inmersiones', 'fr': 'Associer les traces aux plongées', 'he': 'התאמת מסלולים לצלילות', 'hu': 'Útvonalak párosítása merülésekkel', 'it': 'Associa le tracce alle immersioni', 'nl': 'Tracks aan duiken koppelen', 'pt': 'Associar trilhas a mergulhos', 'zh': '将轨迹匹配到潜水'},
  'tracks_match_result': {'en': 'Dives positioned: {positioned} · Underwater tracks linked: {linked}', 'ar': 'الغطسات المحددة مواقعها: {positioned} · المسارات تحت الماء المرتبطة: {linked}', 'de': 'Positionierte Tauchgänge: {positioned} · Verknüpfte Unterwasser-Tracks: {linked}', 'es': 'Inmersiones posicionadas: {positioned} · Tracks submarinos vinculados: {linked}', 'fr': 'Plongées positionnées : {positioned} · Traces sous-marines liées : {linked}', 'he': 'צלילות שמוקמו: {positioned} · מסלולים תת-ימיים שקושרו: {linked}', 'hu': 'Pozicionált merülések: {positioned} · Összekapcsolt víz alatti útvonalak: {linked}', 'it': 'Immersioni posizionate: {positioned} · Tracce subacquee collegate: {linked}', 'nl': 'Gepositioneerde duiken: {positioned} · Gekoppelde onderwatertracks: {linked}', 'pt': 'Mergulhos posicionados: {positioned} · Trilhas subaquáticas vinculadas: {linked}', 'zh': '已定位潜水：{positioned} · 已关联水下轨迹：{linked}'},
  'tracks_match_none': {'en': 'No new matches', 'ar': 'لا توجد مطابقات جديدة', 'de': 'Keine neuen Zuordnungen', 'es': 'No hay nuevas coincidencias', 'fr': 'Aucune nouvelle correspondance', 'he': 'אין התאמות חדשות', 'hu': 'Nincs új egyezés', 'it': 'Nessuna nuova corrispondenza', 'nl': 'Geen nieuwe koppelingen', 'pt': 'Nenhuma nova correspondência', 'zh': '没有新的匹配'},
  'tracks_match_partialError': {'en': 'Some tracks could not be matched. Try again.', 'ar': 'تعذّرت مطابقة بعض المسارات. يُرجى المحاولة مرة أخرى.', 'de': 'Einige Tracks konnten nicht zugeordnet werden. Bitte erneut versuchen.', 'es': 'No se pudieron asociar algunos tracks. Inténtalo de nuevo.', 'fr': "Certaines traces n'ont pas pu être associées. Veuillez réessayer.", 'he': 'לא ניתן היה להתאים חלק מהמסלולים. יש לנסות שוב.', 'hu': 'Néhány útvonalat nem sikerült párosítani. Kérjük, próbáld újra.', 'it': 'Non è stato possibile associare alcune tracce. Riprova.', 'nl': 'Sommige tracks konden niet worden gekoppeld. Probeer het opnieuw.', 'pt': 'Não foi possível associar algumas trilhas. Tente novamente.', 'zh': '部分轨迹无法匹配，请重试。'},
  'tracks_empty_title': {'en': 'No tracks yet', 'ar': 'لا توجد مسارات بعد', 'de': 'Noch keine Tracks', 'es': 'Aún no hay tracks', 'fr': "Aucune trace pour l'instant", 'he': 'אין עדיין מסלולים', 'hu': 'Még nincsenek útvonalak', 'it': 'Nessuna traccia per ora', 'nl': 'Nog geen tracks', 'pt': 'Ainda não há trilhas', 'zh': '暂无轨迹'},
  'tracks_empty_body': {'en': 'Record a GPS track on your phone during a dive day, or import GPX, KML, CSV or FIT files and Seacraft ENC navigation logs. Tracks are matched to your dives automatically.', 'ar': 'سجّل مسار GPS على هاتفك خلال يوم الغطس، أو استورد ملفات GPX أو KML أو CSV أو FIT وسجلات الملاحة من Seacraft ENC. تتم مطابقة المسارات مع غطساتك تلقائيًا.', 'de': 'Zeichne an einem Tauchtag einen GPS-Track mit deinem Telefon auf oder importiere GPX-, KML-, CSV- oder FIT-Dateien und Seacraft-ENC-Navigationsprotokolle. Tracks werden deinen Tauchgängen automatisch zugeordnet.', 'es': 'Graba un track GPS con tu teléfono durante un día de buceo o importa archivos GPX, KML, CSV o FIT y registros de navegación de Seacraft ENC. Los tracks se asocian automáticamente a tus inmersiones.', 'fr': 'Enregistrez une trace GPS avec votre téléphone pendant une journée de plongée, ou importez des fichiers GPX, KML, CSV ou FIT et des journaux de navigation Seacraft ENC. Les traces sont associées automatiquement à vos plongées.', 'he': 'הקלט מסלול GPS בטלפון במהלך יום צלילה, או ייבא קובצי GPX, KML, CSV או FIT ויומני ניווט של Seacraft ENC. המסלולים מותאמים לצלילות שלך באופן אוטומטי.', 'hu': 'Rögzíts GPS-útvonalat a telefonoddal egy merülőnapon, vagy importálj GPX, KML, CSV vagy FIT fájlokat és Seacraft ENC navigációs naplókat. Az útvonalak automatikusan párosulnak a merüléseiddel.', 'it': 'Registra una traccia GPS con il telefono durante una giornata di immersioni, oppure importa file GPX, KML, CSV o FIT e registri di navigazione Seacraft ENC. Le tracce vengono associate automaticamente alle tue immersioni.', 'nl': 'Neem tijdens een duikdag een GPS-track op met je telefoon, of importeer GPX-, KML-, CSV- of FIT-bestanden en Seacraft ENC-navigatielogs. Tracks worden automatisch aan je duiken gekoppeld.', 'pt': 'Grave uma trilha GPS com seu celular durante um dia de mergulho ou importe arquivos GPX, KML, CSV ou FIT e registros de navegação Seacraft ENC. As trilhas são associadas automaticamente aos seus mergulhos.', 'zh': '在潜水日用手机记录 GPS 轨迹，或导入 GPX、KML、CSV、FIT 文件以及 Seacraft ENC 导航日志。轨迹会自动匹配到你的潜水。'},
  'tracks_empty_filtered': {'en': 'No tracks match these filters', 'ar': 'لا توجد مسارات تطابق عوامل التصفية هذه', 'de': 'Keine Tracks entsprechen diesen Filtern', 'es': 'Ningún track coincide con estos filtros', 'fr': 'Aucune trace ne correspond à ces filtres', 'he': 'אין מסלולים שתואמים למסננים האלה', 'hu': 'Egy útvonal sem felel meg ezeknek a szűrőknek', 'it': 'Nessuna traccia corrisponde a questi filtri', 'nl': 'Geen tracks voldoen aan deze filters', 'pt': 'Nenhuma trilha corresponde a estes filtros', 'zh': '没有符合这些筛选条件的轨迹'},
  'tracks_empty_clearFilters': {'en': 'Clear filters', 'ar': 'مسح عوامل التصفية', 'de': 'Filter zurücksetzen', 'es': 'Borrar filtros', 'fr': 'Effacer les filtres', 'he': 'ניקוי מסננים', 'hu': 'Szűrők törlése', 'it': 'Cancella filtri', 'nl': 'Filters wissen', 'pt': 'Limpar filtros', 'zh': '清除筛选'},
  'tracks_map_noMappable': {'en': 'None of these tracks has a position on the map yet.', 'ar': 'لا يملك أي من هذه المسارات موقعًا على الخريطة بعد.', 'de': 'Keiner dieser Tracks hat bisher eine Position auf der Karte.', 'es': 'Ninguno de estos tracks tiene todavía una posición en el mapa.', 'fr': "Aucune de ces traces n'a encore de position sur la carte.", 'he': 'לאף אחד מהמסלולים האלה אין עדיין מיקום על המפה.', 'hu': 'Ezen útvonalak egyikének sincs még helye a térképen.', 'it': 'Nessuna di queste tracce ha ancora una posizione sulla mappa.', 'nl': 'Geen van deze tracks heeft al een positie op de kaart.', 'pt': 'Nenhuma destas trilhas tem ainda uma posição no mapa.', 'zh': '这些轨迹在地图上都还没有位置。'},
}
EN_META = {'tracks_match_result': ['linked', 'positioned']}
# The ten translated files are feature grouped: each block follows an anchor
# key that exists in all of them.
ANCHORS = {'nav_': 'nav_gpsLog', 'tracks_': 'gpsLogger_matchButton'}
KEY_RE = re.compile(r'^  "([^"@][^"]*)":')

def entry(key, value):
    return f'  {json.dumps(key)}: {json.dumps(value, ensure_ascii=False)},'

def meta(key, names):
    out = [f'  "@{key}": {{', '    "placeholders": {']
    for i, name in enumerate(names):
        out += [f'      "{name}": {{', '        "type": "int"',
                '      }' + (',' if i < len(names) - 1 else '')]
    return out + ['    }', '  },']

for loc in LOCALES:
    path = ARB_DIR / f'app_{loc}.arb'
    text = path.read_text(encoding='utf-8')
    assert '\r\n' not in text, path
    lines = text.split('\n')
    existing = {m.group(1) for line in lines if (m := KEY_RE.match(line))}
    assert not existing & S.keys(), (path, existing & S.keys())
    if loc == 'en':
        for key in sorted(S):
            new = [entry(key, S[key]['en'])] + (meta(key, EN_META[key]) if key in EN_META else [])
            at = next(i for i, line in enumerate(lines)
                      if (m := KEY_RE.match(line)) and m.group(1) > key)
            lines[at:at] = new
    else:
        for prefix, anchor in ANCHORS.items():
            block = [entry(k, S[k][loc]) for k in S if k.startswith(prefix)]
            at = next(i for i, line in enumerate(lines) if line.startswith(f'  "{anchor}":'))
            lines[at + 1:at + 1] = block
    path.write_text('\n'.join(lines), encoding='utf-8')
    json.loads(path.read_text(encoding='utf-8'))
print('inserted', len(S), 'keys into', len(LOCALES), 'files')
EOF
```

Expected: `inserted 14 keys into 11 files`.

- [ ] **Step 4: Check the ARB diff, then regenerate**

Run: `git diff --numstat -- lib/l10n/arb`
Expected: `app_en.arb` shows 21 added (14 keys plus 7 metadata lines), each other ARB shows 14 added, every file 0 removed.

Run: `flutter gen-l10n`
Expected: exits 0; `lib/l10n/arb/app_localizations_de.dart` contains `Positionierte Tauchgänge`.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/tracks/tracks_strings_test.dart test/l10n/`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
dart format . && git add lib/l10n/arb test/features/tracks/tracks_strings_test.dart && git commit -m "i18n(tracks): add the Tracks area strings in every locale

Refs #2833"
```

---

### Task 2: Track kinds, list items and locations

**Files:**
- Create: `lib/features/tracks/domain/track_kind.dart`
- Create: `lib/features/tracks/domain/track_list_item.dart`
- Create: `lib/core/router/track_locations.dart`
- Test: `test/features/tracks/domain/track_list_item_test.dart`
- Test: `test/core/router/track_locations_test.dart`

**Interfaces:**
- Produces: `enum TrackKind { gps, underwater }`; `enum TrackKindFilter { all, gps, underwater }` with `static TrackKindFilter? fromQuery(String?)` and `bool admits(TrackKind)`.
- Produces: `sealed class TrackListItem` with getters `String id`, `TrackKind kind`, `int startTime`, `int? endTime`, `bool isMappable`, `Duration? recordedTime`, `String selectionKey`; `final class GpsTrackItem(GpsTrack track)`; `final class UnderwaterTrackItem(NavTrack track)`.
- Produces: `kTracksLocation`, `kTracksMapLocation`, `kUnderwaterTracksLocation`, `gpsTrackLocation(String)`, `underwaterTrackLocation(String)`, `underwaterTrackAlignLocation(String)`, `underwaterTrackSeascapeLocation(String)`.

- [ ] **Step 1: Write the failing tests**

`test/features/tracks/domain/track_list_item_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';

NavTrack _route({
  String id = 'r1',
  int start = 1755856800000,
  int end = 1755860400000,
  int? durationSeconds,
  double? lat,
  double? lon,
}) => NavTrack(
  id: id,
  source: NavTrackSource.seacraftEnc,
  startTime: start,
  endTime: end,
  durationSeconds: durationSeconds,
  pointCount: 5,
  anchorLatitude: lat,
  anchorLongitude: lon,
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

void main() {
  group('TrackKindFilter', () {
    test('reads the kind query value', () {
      expect(TrackKindFilter.fromQuery('gps'), TrackKindFilter.gps);
      expect(TrackKindFilter.fromQuery('underwater'), TrackKindFilter.underwater);
      expect(TrackKindFilter.fromQuery('all'), TrackKindFilter.all);
    });

    test('an absent or unknown value leaves the filter alone', () {
      expect(TrackKindFilter.fromQuery(null), isNull);
      expect(TrackKindFilter.fromQuery('bogus'), isNull);
    });

    test('admits only its own kind, or both for all', () {
      expect(TrackKindFilter.all.admits(TrackKind.gps), isTrue);
      expect(TrackKindFilter.all.admits(TrackKind.underwater), isTrue);
      expect(TrackKindFilter.gps.admits(TrackKind.underwater), isFalse);
      expect(TrackKindFilter.underwater.admits(TrackKind.gps), isFalse);
    });
  });

  group('GpsTrackItem', () {
    test('reads the trimmed window, always maps, and keys by kind', () {
      const track = GpsTrack(
        id: 't1',
        startTime: 1000,
        endTime: 9000,
        trimStartTime: 2000,
        trimEndTime: 5000,
      );
      const item = GpsTrackItem(track);
      expect(item.kind, TrackKind.gps);
      expect(item.startTime, 2000);
      expect(item.endTime, 5000);
      expect(item.isMappable, isTrue);
      expect(item.recordedTime, const Duration(seconds: 3));
      expect(item.selectionKey, 'gps:t1');
    });

    test('a track still recording has no recorded time', () {
      const item = GpsTrackItem(GpsTrack(id: 't1', startTime: 1000));
      expect(item.recordedTime, isNull);
    });
  });

  group('UnderwaterTrackItem', () {
    test('maps only when anchored', () {
      expect(UnderwaterTrackItem(_route()).isMappable, isFalse);
      expect(UnderwaterTrackItem(_route(lat: 47.1, lon: 8.3)).isMappable, isTrue);
    });

    test('recorded time prefers the stored duration', () {
      final item = UnderwaterTrackItem(_route(durationSeconds: 600));
      expect(item.recordedTime, const Duration(minutes: 10));
    });

    test('recorded time falls back to the raw span, never negative', () {
      expect(
        UnderwaterTrackItem(_route(start: 0, end: 90000)).recordedTime,
        const Duration(seconds: 90),
      );
      expect(
        UnderwaterTrackItem(_route(start: 5000, end: 1000)).recordedTime,
        Duration.zero,
      );
    });

    test('keys by kind so ids from two tables cannot collide', () {
      final item = UnderwaterTrackItem(_route(id: 'x'));
      expect(item.kind, TrackKind.underwater);
      expect(item.selectionKey, 'underwater:x');
      expect(item.selectionKey, isNot(const GpsTrackItem(GpsTrack(id: 'x', startTime: 0)).selectionKey));
    });
  });
}
```

`test/core/router/track_locations_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/router/track_locations.dart';

void main() {
  test('every tracks page lives under /tracks', () {
    expect(kTracksLocation, '/tracks');
    expect(kTracksMapLocation, '/tracks/map');
    expect(kUnderwaterTracksLocation, '/tracks?kind=underwater');
    expect(gpsTrackLocation('a'), '/tracks/gps/a');
    expect(underwaterTrackLocation('b'), '/tracks/underwater/b');
    expect(underwaterTrackAlignLocation('b'), '/tracks/underwater/b/align');
    expect(underwaterTrackSeascapeLocation('b'), '/tracks/underwater/b/3d');
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/tracks/domain/track_list_item_test.dart test/core/router/track_locations_test.dart`
Expected: compile errors, the imported files do not exist.

- [ ] **Step 3: Implement**

`lib/core/router/track_locations.dart`:

```dart
/// Where the Tracks area's pages live (spec
/// 2026-10-02-tracks-navigation-consolidation-design.md).
///
/// The router, the nav destination and every feature that links into the
/// area build their paths here, so a hand-written path cannot drift from the
/// route table. Every page is a top-level sibling of [kTracksLocation]; see
/// the router for why.
const kTracksLocation = '/tracks';

/// Full-screen overview map, for phones where the landing page is one
/// column.
const kTracksMapLocation = '$kTracksLocation/map';

/// The landing page with the kind filter set to underwater tracks.
const kUnderwaterTracksLocation = '$kTracksLocation?kind=underwater';

String gpsTrackLocation(String id) => '$kTracksLocation/gps/$id';

String underwaterTrackLocation(String id) => '$kTracksLocation/underwater/$id';

String underwaterTrackAlignLocation(String id) =>
    '${underwaterTrackLocation(id)}/align';

String underwaterTrackSeascapeLocation(String id) =>
    '${underwaterTrackLocation(id)}/3d';
```

`lib/features/tracks/domain/track_kind.dart`:

```dart
/// The two kinds of track the Tracks area lists together.
enum TrackKind { gps, underwater }

/// The Tracks page's kind filter; [all] shows both kinds.
enum TrackKindFilter {
  all,
  gps,
  underwater;

  /// Reads a `?kind=` query value. Null for an absent or unknown value, so
  /// a link without a usable kind leaves the current filter alone.
  static TrackKindFilter? fromQuery(String? value) => switch (value) {
    'all' => TrackKindFilter.all,
    'gps' => TrackKindFilter.gps,
    'underwater' => TrackKindFilter.underwater,
    _ => null,
  };

  bool admits(TrackKind kind) => switch (this) {
    TrackKindFilter.all => true,
    TrackKindFilter.gps => kind == TrackKind.gps,
    TrackKindFilter.underwater => kind == TrackKind.underwater,
  };
}
```

`lib/features/tracks/domain/track_list_item.dart`:

```dart
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';

/// One row of the Tracks area: a GPS surface track or an underwater track.
///
/// Each variant wraps its own entity unchanged, so the existing rows, info
/// cards and polyline layers render it; this type only carries what the
/// merged list, the map and the summary need to treat both alike.
sealed class TrackListItem {
  const TrackListItem();

  String get id;

  TrackKind get kind;

  /// Wall-clock-as-UTC epoch milliseconds, the dives.entryTime convention.
  int get startTime;

  /// Null for a GPS track still recording.
  int? get endTime;

  /// Whether the overview map can place it. Underwater tracks without an
  /// anchor have no position on Earth and show only in the list.
  bool get isMappable;

  /// Time the summary counts; null when there is nothing to count yet.
  Duration? get recordedTime;

  /// Selection identity, qualified by kind so ids from the two tables can
  /// never resolve to the wrong one.
  String get selectionKey => '${kind.name}:$id';
}

final class GpsTrackItem extends TrackListItem {
  const GpsTrackItem(this.track);

  final GpsTrack track;

  @override
  String get id => track.id;

  @override
  TrackKind get kind => TrackKind.gps;

  /// Trim-aware, matching what the track's own detail page shows.
  @override
  int get startTime => track.effectiveStartTime;

  @override
  int? get endTime => track.effectiveEndTime;

  @override
  bool get isMappable => true;

  @override
  Duration? get recordedTime {
    final end = endTime;
    if (end == null) return null;
    return Duration(milliseconds: end - startTime);
  }
}

final class UnderwaterTrackItem extends TrackListItem {
  const UnderwaterTrackItem(this.track);

  final NavTrack track;

  @override
  String get id => track.id;

  @override
  TrackKind get kind => TrackKind.underwater;

  @override
  int get startTime => track.startTime;

  @override
  int? get endTime => track.endTime;

  @override
  bool get isMappable => track.anchor != null;

  /// The stored dive duration (up to the last dead-reckoned sample), with
  /// the raw recording span only for a row stored before it was.
  @override
  Duration? get recordedTime {
    final seconds =
        track.durationSeconds ??
        ((track.endTime - track.startTime) / 1000).round();
    return Duration(seconds: seconds < 0 ? 0 : seconds);
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/tracks/domain/track_list_item_test.dart test/core/router/track_locations_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format . && git add lib/core/router/track_locations.dart lib/features/tracks/domain test/features/tracks/domain test/core/router/track_locations_test.dart && git commit -m "feat(tracks): add track list items, kinds and the tracks locations

Refs #2833"
```

---

### Task 3: Merge, overview cap, summary and providers

**Files:**
- Create: `lib/features/tracks/domain/tracks_query.dart`
- Create: `lib/features/tracks/domain/tracks_summary.dart`
- Create: `lib/features/tracks/presentation/providers/tracks_providers.dart`
- Test: `test/features/tracks/domain/tracks_query_test.dart`
- Test: `test/features/tracks/domain/tracks_summary_test.dart`
- Test: `test/features/tracks/presentation/providers/tracks_providers_test.dart`

**Interfaces:**
- Consumes: `TrackListItem`, `GpsTrackItem`, `UnderwaterTrackItem`, `TrackKindFilter` (Task 2); `gpsTracksProvider` (`gps_log_providers.dart`); `trackDateFilterProvider` (`gps_track_map_providers.dart`); `allNavTracksProvider` (`nav_track_providers.dart`); `divesProvider` (`dive_providers.dart`).
- Produces: `const int kTracksOverviewLimit = 40`; `bool startsWithin(int startMs, DateTimeRange range)`; `List<TrackListItem> mergeTracks({required List<GpsTrack> gps, required List<NavTrack> underwater, required TrackKindFilter kind, required DateTimeRange? range})`; `({List<TrackListItem> items, bool truncated}) capOverview(List<TrackListItem> items, {int limit})`; `class TracksSummary { int trackCount; Duration recordedTime; int divesCovered; }`; `TracksSummary summarizeTracks(List<TrackListItem> items, List<Dive> dives)`; providers `trackKindFilterProvider` (`StateProvider<TrackKindFilter>`), `tracksListProvider`, `tracksOverviewProvider` (`FutureProvider<List<TrackListItem>>`), `tracksOverviewTruncatedProvider` (`Provider<bool>`), `tracksSummaryProvider` (`FutureProvider<TracksSummary>`).

- [ ] **Step 1: Write the failing tests**

`test/features/tracks/domain/tracks_query_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/domain/tracks_query.dart';

GpsTrack _gps(String id, DateTime start, {DateTime? trimStart}) => GpsTrack(
  id: id,
  startTime: start.millisecondsSinceEpoch,
  endTime: start.add(const Duration(hours: 4)).millisecondsSinceEpoch,
  trimStartTime: trimStart?.millisecondsSinceEpoch,
);

NavTrack _uw(String id, DateTime start, {bool anchored = false}) => NavTrack(
  id: id,
  source: NavTrackSource.seacraftEnc,
  startTime: start.millisecondsSinceEpoch,
  endTime: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
  pointCount: 5,
  anchorLatitude: anchored ? 47.1 : null,
  anchorLongitude: anchored ? 8.3 : null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

List<String> _keys(List<TrackListItem> items) =>
    [for (final i in items) i.selectionKey];

void main() {
  final may = DateTime.utc(2026, 5, 10);
  final june = DateTime.utc(2026, 6, 15);
  final july = DateTime.utc(2026, 7, 20);

  group('mergeTracks', () {
    test('lists both kinds newest first', () {
      final items = mergeTracks(
        gps: [_gps('g-july', july), _gps('g-may', may)],
        underwater: [_uw('u-june', june)],
        kind: TrackKindFilter.all,
        range: null,
      );
      expect(_keys(items), ['gps:g-july', 'underwater:u-june', 'gps:g-may']);
    });

    test('the kind filter keeps one kind', () {
      final gps = [_gps('g', may)];
      final uw = [_uw('u', june)];
      expect(
        _keys(mergeTracks(gps: gps, underwater: uw, kind: TrackKindFilter.gps, range: null)),
        ['gps:g'],
      );
      expect(
        _keys(mergeTracks(gps: gps, underwater: uw, kind: TrackKindFilter.underwater, range: null)),
        ['underwater:u'],
      );
    });

    test('the date filter bounds both kinds, inclusive of the end day', () {
      final items = mergeTracks(
        gps: [_gps('g-may', may), _gps('g-july', july)],
        underwater: [_uw('u-june', june), _uw('u-may', may)],
        kind: TrackKindFilter.all,
        range: DateTimeRange(start: DateTime.utc(2026, 5, 1), end: DateTime.utc(2026, 6, 15)),
      );
      expect(_keys(items), ['underwater:u-june', 'gps:g-may', 'underwater:u-may']);
    });

    test('a range matching nothing returns nothing', () {
      expect(
        mergeTracks(
          gps: [_gps('g', may)],
          underwater: [_uw('u', june)],
          kind: TrackKindFilter.all,
          range: DateTimeRange(start: DateTime.utc(2025, 1, 1), end: DateTime.utc(2025, 12, 31)),
        ),
        isEmpty,
      );
    });

    test('a GPS track sorts by its trimmed start', () {
      // Recorded from 08:00 but trimmed to start at 11:00, so it sorts after
      // an underwater track at 10:00 even though it started first.
      final day = DateTime.utc(2026, 6, 1);
      final items = mergeTracks(
        gps: [_gps('g', day.add(const Duration(hours: 8)), trimStart: day.add(const Duration(hours: 11)))],
        underwater: [_uw('u', day.add(const Duration(hours: 10)))],
        kind: TrackKindFilter.all,
        range: null,
      );
      expect(_keys(items), ['gps:g', 'underwater:u']);
    });

    test('equal start times break ties by selection key, whatever the '
        'input order', () {
      // Inputs arrive in the reverse of the tie-break order, so this fails
      // without the tie-breaker.
      final items = mergeTracks(
        gps: [_gps('b', may), _gps('a', may)],
        underwater: [_uw('a', may)],
        kind: TrackKindFilter.all,
        range: null,
      );
      expect(_keys(items), ['gps:a', 'gps:b', 'underwater:a']);
    });
  });

  group('capOverview', () {
    test('keeps the newest mappable items and drops unanchored ones', () {
      final items = mergeTracks(
        gps: [_gps('g', may)],
        underwater: [_uw('u-anchored', june, anchored: true), _uw('u-loose', july)],
        kind: TrackKindFilter.all,
        range: null,
      );
      final capped = capOverview(items);
      expect(_keys(capped.items), ['underwater:u-anchored', 'gps:g']);
      expect(capped.truncated, isFalse);
    });

    test('the cap is shared across kinds', () {
      final start = DateTime.utc(2026, 1, 1);
      final items = mergeTracks(
        gps: [for (var i = 0; i < 30; i++) _gps('g$i', start.add(Duration(days: -2 * i)))],
        underwater: [for (var i = 0; i < 30; i++) _uw('u$i', start.add(Duration(days: -2 * i - 1)), anchored: true)],
        kind: TrackKindFilter.all,
        range: null,
      );
      final capped = capOverview(items);
      expect(capped.items.length, kTracksOverviewLimit);
      expect(capped.items.first.selectionKey, 'gps:g0');
      expect(capped.truncated, isTrue);
    });
  });
}
```

`test/features/tracks/domain/tracks_summary_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/domain/tracks_summary.dart';

final _day = DateTime.utc(2026, 5, 22);

GpsTrack _gps(String id, int fromHour, int toHour, {int? trimFromHour}) => GpsTrack(
  id: id,
  startTime: _day.add(Duration(hours: fromHour)).millisecondsSinceEpoch,
  endTime: _day.add(Duration(hours: toHour)).millisecondsSinceEpoch,
  trimStartTime: trimFromHour == null
      ? null
      : _day.add(Duration(hours: trimFromHour)).millisecondsSinceEpoch,
);

NavTrack _uw(String id, {String? diveId, int? durationSeconds}) => NavTrack(
  id: id,
  diveId: diveId,
  source: NavTrackSource.seacraftEnc,
  startTime: _day.add(const Duration(hours: 20)).millisecondsSinceEpoch,
  endTime: _day.add(const Duration(hours: 21)).millisecondsSinceEpoch,
  durationSeconds: durationSeconds,
  pointCount: 5,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Dive _dive(String id, int hour) =>
    Dive(id: id, diveNumber: 1, dateTime: _day.add(Duration(hours: hour)), maxDepth: 20);

void main() {
  test('an empty list reports zero everything', () {
    final summary = summarizeTracks(const [], const []);
    expect(summary.trackCount, 0);
    expect(summary.recordedTime, Duration.zero);
    expect(summary.divesCovered, 0);
  });

  test('recorded time adds trimmed GPS time and underwater duration', () {
    final summary = summarizeTracks([
      // Four hours recorded, trimmed to the last two.
      GpsTrackItem(_gps('g', 8, 12, trimFromHour: 10)),
      UnderwaterTrackItem(_uw('u', durationSeconds: 600)),
      // No stored duration: the one-hour raw span counts.
      UnderwaterTrackItem(_uw('v')),
    ], const []);
    expect(summary.trackCount, 3);
    expect(summary.recordedTime, const Duration(hours: 3, minutes: 10));
  });

  test('a dive covered by a GPS window and linked to an underwater track '
      'counts once', () {
    final summary = summarizeTracks(
      [GpsTrackItem(_gps('g', 8, 12)), UnderwaterTrackItem(_uw('u', diveId: 'd1'))],
      [_dive('d1', 10), _dive('d2', 11)],
    );
    expect(summary.divesCovered, 2);
  });

  test('a link to a dive outside the dive list is not counted', () {
    final summary = summarizeTracks(
      [UnderwaterTrackItem(_uw('u', diveId: 'someone-elses-dive'))],
      [_dive('d1', 3)],
    );
    expect(summary.divesCovered, 0);
  });
}
```

`test/features/tracks/presentation/providers/tracks_providers_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/domain/tracks_query.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';

GpsTrack _gps(String id, DateTime start) => GpsTrack(
  id: id,
  startTime: start.millisecondsSinceEpoch,
  endTime: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
);

NavTrack _uw(String id, DateTime start, {String? diveId}) => NavTrack(
  id: id,
  diveId: diveId,
  source: NavTrackSource.seacraftEnc,
  startTime: start.millisecondsSinceEpoch,
  endTime: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
  durationSeconds: 600,
  pointCount: 5,
  anchorLatitude: 47.1,
  anchorLongitude: 8.3,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ProviderContainer _container({
  required List<GpsTrack> gps,
  required List<NavTrack> underwater,
  List<Dive> dives = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      gpsTracksProvider.overrideWith((ref) async => gps),
      allNavTracksProvider.overrideWith((ref) async => underwater),
      divesProvider.overrideWith((ref) async => dives),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  final june = DateTime.utc(2026, 6, 15);
  final july = DateTime.utc(2026, 7, 20);

  test('the list follows the kind and date filters', () async {
    final container = _container(gps: [_gps('g', july)], underwater: [_uw('u', june)]);
    expect((await container.read(tracksListProvider.future)).length, 2);

    container.read(trackKindFilterProvider.notifier).state = TrackKindFilter.underwater;
    expect(
      [for (final i in await container.read(tracksListProvider.future)) i.selectionKey],
      ['underwater:u'],
    );

    container.read(trackKindFilterProvider.notifier).state = TrackKindFilter.all;
    container.read(trackDateFilterProvider.notifier).state = DateTimeRange(
      start: DateTime.utc(2026, 7, 1),
      end: DateTime.utc(2026, 7, 31),
    );
    expect(
      [for (final i in await container.read(tracksListProvider.future)) i.selectionKey],
      ['gps:g'],
    );

    // Clearing the date filter restores every track.
    container.read(trackDateFilterProvider.notifier).state = null;
    expect((await container.read(tracksListProvider.future)).length, 2);
  });

  test('narrowing the filter below the cap clears the truncation notice', () async {
    final start = DateTime.utc(2026, 1, 1);
    final container = _container(
      gps: [for (var i = 0; i < kTracksOverviewLimit + 5; i++) _gps('g$i', start.add(Duration(days: -i)))],
      underwater: const [],
    );
    expect((await container.read(tracksOverviewProvider.future)).length, kTracksOverviewLimit);
    expect(container.read(tracksOverviewTruncatedProvider), isTrue);

    container.read(trackDateFilterProvider.notifier).state = DateTimeRange(
      start: DateTime.utc(2025, 12, 29),
      end: DateTime.utc(2026, 1, 1),
    );
    expect((await container.read(tracksOverviewProvider.future)).length, 4);
    expect(container.read(tracksOverviewTruncatedProvider), isFalse);
  });

  test('the summary follows the kind filter', () async {
    final container = _container(
      gps: [_gps('g', july)],
      underwater: [_uw('u', june, diveId: 'd1')],
      dives: [Dive(id: 'd1', diveNumber: 1, dateTime: june, maxDepth: 20)],
    );
    expect((await container.read(tracksSummaryProvider.future)).divesCovered, 1);

    container.read(trackKindFilterProvider.notifier).state = TrackKindFilter.gps;
    final summary = await container.read(tracksSummaryProvider.future);
    expect(summary.trackCount, 1);
    expect(summary.divesCovered, 0);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/tracks/domain/tracks_query_test.dart test/features/tracks/domain/tracks_summary_test.dart test/features/tracks/presentation/providers/tracks_providers_test.dart`
Expected: compile errors, the imported files do not exist.

- [ ] **Step 3: Implement the pure functions**

`lib/features/tracks/domain/tracks_query.dart`:

```dart
import 'package:flutter/material.dart' show DateTimeRange;

import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';

/// Most tracks the overview map draws at once, across both kinds.
///
/// Every track drawn hydrates a full point blob and, for GPS on a cold
/// cache, spawns its own simplification isolate; the date filter defaults
/// to unbounded, so without a cap a large library would do that for every
/// track in one frame. Newest first, because that is what a diver looks for.
const int kTracksOverviewLimit = 40;

/// Whether [startMs] falls inside [range], inclusive of the end date's whole
/// day. Track start times are wall-clock-as-UTC, so the range's values
/// compare against them directly.
bool startsWithin(int startMs, DateTimeRange range) {
  final from = range.start.millisecondsSinceEpoch;
  final to = range.end
      .add(const Duration(days: 1))
      .subtract(const Duration(milliseconds: 1))
      .millisecondsSinceEpoch;
  return startMs >= from && startMs <= to;
}

/// Both kinds as one list: filtered by [kind] and [range], newest first.
///
/// Ties on start time break by selection key: `List.sort` is not stable,
/// and without a tie-breaker two tracks starting together could swap places
/// between rebuilds.
List<TrackListItem> mergeTracks({
  required List<GpsTrack> gps,
  required List<NavTrack> underwater,
  required TrackKindFilter kind,
  required DateTimeRange? range,
}) {
  final items = <TrackListItem>[
    if (kind.admits(TrackKind.gps))
      for (final track in gps) GpsTrackItem(track),
    if (kind.admits(TrackKind.underwater))
      for (final track in underwater) UnderwaterTrackItem(track),
  ];
  final bounded = range == null
      ? items
      : [
          for (final item in items)
            if (startsWithin(item.startTime, range)) item,
        ];
  final sorted = [...bounded]
    ..sort((a, b) {
      final byTime = b.startTime.compareTo(a.startTime);
      return byTime != 0 ? byTime : a.selectionKey.compareTo(b.selectionKey);
    });
  return List.unmodifiable(sorted);
}

/// What the overview map draws: the newest [limit] mappable items, and
/// whether the cap dropped any the filters allowed.
({List<TrackListItem> items, bool truncated}) capOverview(
  List<TrackListItem> items, {
  int limit = kTracksOverviewLimit,
}) {
  final mappable = [
    for (final item in items)
      if (item.isMappable) item,
  ];
  return (
    items: List.unmodifiable(mappable.take(limit)),
    truncated: mappable.length > limit,
  );
}
```

`lib/features/tracks/domain/tracks_summary.dart`:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gps_log/domain/gps_track_matcher.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';

/// Figures for the Tracks page's summary strip.
///
/// Everything comes from stored scalars and the in-memory dive list; no
/// point blob is decoded.
class TracksSummary {
  const TracksSummary({
    required this.trackCount,
    required this.recordedTime,
    required this.divesCovered,
  });

  final int trackCount;
  final Duration recordedTime;

  /// Dives with a GPS track around their entry or an underwater track
  /// linked to them, each counted once.
  final int divesCovered;
}

/// Summarises [items] (already filtered) against the diver's [dives].
///
/// The two kinds answer "which dive" differently: GPS coverage is by time
/// window, with the matcher's own tolerance; underwater coverage is by the
/// stored link. A link to a dive outside [dives] (another diver's, or one
/// not loaded) is not counted.
TracksSummary summarizeTracks(List<TrackListItem> items, List<Dive> dives) {
  final recorded = items.fold<Duration>(
    Duration.zero,
    (total, item) => total + (item.recordedTime ?? Duration.zero),
  );
  final gpsTracks = [
    for (final item in items)
      if (item is GpsTrackItem) item.track,
  ];
  final diveIds = {for (final dive in dives) dive.id};
  final covered = <String>{
    for (final dive in dives)
      // millisecondsSinceEpoch is absolute regardless of the utc flag, so it
      // compares directly against the wall-clock-as-UTC track window.
      if (GpsTrackMatcher.trackCovering(
            gpsTracks,
            dive.effectiveEntryTime.millisecondsSinceEpoch,
          ) !=
          null)
        dive.id,
    for (final item in items)
      if (item is UnderwaterTrackItem && diveIds.contains(item.track.diveId))
        item.track.diveId!,
  };
  return TracksSummary(
    trackCount: items.length,
    recordedTime: recorded,
    divesCovered: covered.length,
  );
}
```

- [ ] **Step 4: Implement the providers**

`lib/features/tracks/presentation/providers/tracks_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/domain/tracks_query.dart';
import 'package:submersion/features/tracks/domain/tracks_summary.dart';

/// The Tracks page's kind filter. Lives as long as the app, like the date
/// filter it sits beside, so the map page and the list agree.
final trackKindFilterProvider = StateProvider<TrackKindFilter>(
  (ref) => TrackKindFilter.all,
);

/// GPS and underwater tracks as one filtered list, newest first.
///
/// `allNavTracksProvider` reads without points, so no row decodes a blob to
/// appear here.
final tracksListProvider = FutureProvider<List<TrackListItem>>((ref) async {
  final kind = ref.watch(trackKindFilterProvider);
  final range = ref.watch(trackDateFilterProvider);
  final gps = await ref.watch(gpsTracksProvider.future);
  final underwater = await ref.watch(allNavTracksProvider.future);
  return mergeTracks(gps: gps, underwater: underwater, kind: kind, range: range);
});

/// What the overview map draws; see [capOverview].
final tracksOverviewProvider = FutureProvider<List<TrackListItem>>((
  ref,
) async {
  final items = await ref.watch(tracksListProvider.future);
  return capOverview(items).items;
});

/// True when the overview cap dropped mappable tracks the filters allowed.
final tracksOverviewTruncatedProvider = Provider<bool>((ref) {
  final items = ref.watch(tracksListProvider).value ?? const <TrackListItem>[];
  return capOverview(items).truncated;
});

/// The summary strip's figures, following the active filters.
final tracksSummaryProvider = FutureProvider<TracksSummary>((ref) async {
  final items = await ref.watch(tracksListProvider.future);
  final dives = await ref.watch(divesProvider.future);
  return summarizeTracks(items, dives);
});
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/tracks/`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
dart format . && git add lib/features/tracks test/features/tracks && git commit -m "feat(tracks): merge, cap and summarise GPS and underwater tracks

Refs #2833"
```

---

### Task 4: One Match action for both kinds

**Files:**
- Create: `lib/features/tracks/application/tracks_match_controller.dart`
- Create: `lib/features/tracks/presentation/widgets/tracks_match_snackbar.dart`
- Test: `test/features/tracks/application/tracks_match_controller_test.dart`
- Test: `test/features/tracks/presentation/widgets/tracks_match_snackbar_test.dart`

**Interfaces:**
- Consumes: `GpsTrackMatchService.sweep()` returning `Future<List<String>>` of positioned dive ids; `NavTrackMatchService.sweep()` returning `Future<({List<String> linked, List<String> needsChoice})>`; providers `gpsTrackMatchServiceProvider`, `navTrackMatchServiceProvider`; l10n from Task 1.
- Produces: `class TracksMatchOutcome { List<String> positionedDiveIds; List<String> linkedUnderwaterIds; bool anyFailed; bool get matchedAnything; }`; `class TracksMatchController { Future<TracksMatchOutcome> matchAll(); }`; `tracksMatchControllerProvider`; `void showTracksMatchOutcome({required ScaffoldMessengerState messenger, required AppLocalizations l10n, required GoRouter router, required TracksMatchOutcome outcome})`.

- [ ] **Step 1: Write the failing tests**

`test/features/tracks/application/tracks_match_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_match_service.dart';
import 'package:submersion/features/tracks/application/tracks_match_controller.dart';

class _Gps extends GpsTrackMatchService {
  _Gps(this.calls, {this.result = const [], this.fail = false})
    : super(trackRepository: GpsTrackRepository(), diveRepository: DiveRepository());
  final List<String> calls;
  final List<String> result;
  final bool fail;

  @override
  Future<List<String>> sweep({List<String>? limitToIds}) async {
    calls.add('gps');
    if (fail) throw StateError('gps failed');
    return result;
  }
}

class _Underwater extends NavTrackMatchService {
  _Underwater(this.calls, {this.linked = const [], this.fail = false})
    : super(routeRepository: NavTrackRepository(), diveRepository: DiveRepository());
  final List<String> calls;
  final List<String> linked;
  final bool fail;

  @override
  Future<({List<String> linked, List<String> needsChoice})> sweep({
    List<String>? limitToRouteIds,
    List<String>? limitToDiveIds,
  }) async {
    calls.add('underwater');
    if (fail) throw StateError('underwater failed');
    return (linked: linked, needsChoice: const <String>[]);
  }
}

void main() {
  test('runs the GPS sweep, then the underwater sweep', () async {
    final calls = <String>[];
    final outcome = await TracksMatchController(
      gps: _Gps(calls, result: const ['d1', 'd2']),
      underwater: _Underwater(calls, linked: const ['r1']),
    ).matchAll();
    expect(calls, ['gps', 'underwater']);
    expect(outcome.positionedDiveIds, ['d1', 'd2']);
    expect(outcome.linkedUnderwaterIds, ['r1']);
    expect(outcome.anyFailed, isFalse);
    expect(outcome.matchedAnything, isTrue);
  });

  test('a failing GPS sweep still runs the underwater sweep', () async {
    final calls = <String>[];
    final outcome = await TracksMatchController(
      gps: _Gps(calls, fail: true),
      underwater: _Underwater(calls, linked: const ['r1']),
    ).matchAll();
    expect(calls, ['gps', 'underwater']);
    expect(outcome.anyFailed, isTrue);
    expect(outcome.linkedUnderwaterIds, ['r1']);
  });

  test('a failing underwater sweep keeps the GPS result', () async {
    final calls = <String>[];
    final outcome = await TracksMatchController(
      gps: _Gps(calls, result: const ['d1']),
      underwater: _Underwater(calls, fail: true),
    ).matchAll();
    expect(outcome.anyFailed, isTrue);
    expect(outcome.positionedDiveIds, ['d1']);
  });

  test('nothing new is reported as such', () async {
    final calls = <String>[];
    final outcome = await TracksMatchController(
      gps: _Gps(calls),
      underwater: _Underwater(calls),
    ).matchAll();
    expect(outcome.matchedAnything, isFalse);
    expect(outcome.anyFailed, isFalse);
  });
}
```

`test/features/tracks/presentation/widgets/tracks_match_snackbar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/tracks/application/tracks_match_controller.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_match_snackbar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../../helpers/test_app.dart';

Future<void> _show(WidgetTester tester, TracksMatchOutcome outcome) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTracksMatchOutcome(
                messenger: ScaffoldMessenger.of(context),
                l10n: context.l10n,
                router: GoRouter.of(context),
                outcome: outcome,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/dives/match-sites',
        builder: (context, state) =>
            Scaffold(body: Text('MATCH-SITES ${state.extra}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(testAppRouter(router: router, locale: const Locale('en')));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reports both counts and offers the site review', (tester) async {
    await _show(
      tester,
      const TracksMatchOutcome(
        positionedDiveIds: ['d1', 'd2'],
        linkedUnderwaterIds: ['r1'],
        anyFailed: false,
      ),
    );
    expect(find.text('Dives positioned: 2 · Underwater tracks linked: 1'), findsOneWidget);

    await tester.tap(find.text('Review site matches'));
    await tester.pumpAndSettle();
    expect(find.text('MATCH-SITES [d1, d2]'), findsOneWidget);
  });

  testWidgets('underwater links alone offer no site review', (tester) async {
    await _show(
      tester,
      const TracksMatchOutcome(
        positionedDiveIds: [],
        linkedUnderwaterIds: ['r1'],
        anyFailed: false,
      ),
    );
    expect(find.text('Dives positioned: 0 · Underwater tracks linked: 1'), findsOneWidget);
    expect(find.text('Review site matches'), findsNothing);
  });

  testWidgets('nothing new says so', (tester) async {
    await _show(
      tester,
      const TracksMatchOutcome(positionedDiveIds: [], linkedUnderwaterIds: [], anyFailed: false),
    );
    expect(find.text('No new matches'), findsOneWidget);
  });

  testWidgets('a failure says so even when the other sweep matched', (tester) async {
    await _show(
      tester,
      const TracksMatchOutcome(positionedDiveIds: [], linkedUnderwaterIds: ['r1'], anyFailed: true),
    );
    expect(find.text('Some tracks could not be matched. Try again.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/tracks/application test/features/tracks/presentation/widgets/tracks_match_snackbar_test.dart`
Expected: compile errors, the imported files do not exist.

- [ ] **Step 3: Implement**

`lib/features/tracks/application/tracks_match_controller.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_match_service.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_service_providers.dart';

const _log = LoggerService('TracksMatchController');

/// What one press of the Tracks page's Match action did.
class TracksMatchOutcome {
  const TracksMatchOutcome({
    required this.positionedDiveIds,
    required this.linkedUnderwaterIds,
    required this.anyFailed,
  });

  /// Dives the GPS sweep gave coordinates to; the site review takes these.
  final List<String> positionedDiveIds;

  /// Underwater tracks the sweep linked to a dive.
  final List<String> linkedUnderwaterIds;

  /// Either sweep threw. The other one still ran.
  final bool anyFailed;

  bool get matchedAnything =>
      positionedDiveIds.isNotEmpty || linkedUnderwaterIds.isNotEmpty;
}

/// Runs both dive-matching sweeps for the Tracks page.
///
/// Sequential, not parallel: both write dive links, and the GPS sweep also
/// writes dive coordinates. Each sweep is guarded on its own so a failure in
/// one never skips the other.
class TracksMatchController {
  const TracksMatchController({
    required GpsTrackMatchService gps,
    required NavTrackMatchService underwater,
  }) : _gps = gps,
       _underwater = underwater;

  final GpsTrackMatchService _gps;
  final NavTrackMatchService _underwater;

  Future<TracksMatchOutcome> matchAll() async {
    var anyFailed = false;

    var positioned = const <String>[];
    try {
      positioned = await _gps.sweep();
    } catch (e, stackTrace) {
      _log.error('GPS match sweep failed', error: e, stackTrace: stackTrace);
      anyFailed = true;
    }

    var linked = const <String>[];
    try {
      linked = (await _underwater.sweep()).linked;
    } catch (e, stackTrace) {
      _log.error(
        'Underwater match sweep failed',
        error: e,
        stackTrace: stackTrace,
      );
      anyFailed = true;
    }

    return TracksMatchOutcome(
      positionedDiveIds: positioned,
      linkedUnderwaterIds: linked,
      anyFailed: anyFailed,
    );
  }
}

final tracksMatchControllerProvider = Provider<TracksMatchController>(
  (ref) => TracksMatchController(
    gps: ref.watch(gpsTrackMatchServiceProvider),
    underwater: ref.watch(navTrackMatchServiceProvider),
  ),
);
```

`lib/features/tracks/presentation/widgets/tracks_match_snackbar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/tracks/application/tracks_match_controller.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Reports a Match press. Positioned dives keep the GPS log's "Review site
/// matches" action, which hands their ids to the site review.
void showTracksMatchOutcome({
  required ScaffoldMessengerState messenger,
  required AppLocalizations l10n,
  required GoRouter router,
  required TracksMatchOutcome outcome,
}) {
  final positioned = outcome.positionedDiveIds;
  final message = outcome.anyFailed
      ? l10n.tracks_match_partialError
      : !outcome.matchedAnything
      ? l10n.tracks_match_none
      : l10n.tracks_match_result(
          outcome.linkedUnderwaterIds.length,
          positioned.length,
        );
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        // #406: an action defaults to persist: true; force auto-dismiss.
        persist: false,
        showCloseIcon: true,
        action: positioned.isEmpty
            ? null
            : SnackBarAction(
                label: l10n.gpsLogger_reviewSites,
                onPressed: () =>
                    router.push('/dives/match-sites', extra: positioned),
              ),
      ),
    );
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/tracks/application test/features/tracks/presentation/widgets/tracks_match_snackbar_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format . && git add lib/features/tracks test/features/tracks && git commit -m "feat(tracks): match GPS and underwater tracks to dives in one action

Refs #2833"
```

---

### Task 5: One Import action with ENC detection

**Files:**
- Create: `lib/features/tracks/presentation/tracks_import.dart`
- Test: `test/features/tracks/presentation/tracks_import_test.dart`

**Interfaces:**
- Consumes: `readCsvHeaders(Uint8List)` (`gps_log/data/services/track_import/csv_track_parser.dart`); `looksLikeSeacraftEnc(List<String>)` (`nav_track/data/services/parsers/seacraft_enc_signature.dart`); `trackImportServiceProvider`, `navTrackImportServiceProvider`; `navigateToNavTrackReview(context, bytes, fileName:, preview:)`; `TrackImportReviewPage(candidate:, bytes:)`; `trackParseErrorText`, `navTrackParseErrorText`.
- Produces: `bool isSeacraftEncFile(String fileName, Uint8List bytes)`; `Future<void> importTrackFile(BuildContext context, WidgetRef ref)`.

- [ ] **Step 1: Write the failing tests**

`test/features/tracks/presentation/tracks_import_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';
import 'package:submersion/features/gps_log/data/services/track_import/track_import_service.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/track_parse_error_text.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';
import 'package:submersion/features/nav_track/domain/nav_track_stats.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/tracks/presentation/tracks_import.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_file_picker_platform.dart';
import '../../../helpers/mock_providers.dart';

Uint8List _fixture(String name) => File(
  p.join('test', 'fixtures', 'nav_tracks', name),
).readAsBytesSync();

/// Hands back a fixed preview so the flow can be followed past the picker.
class _PreparedNavImport implements NavTrackImportService {
  int prepareCount = 0;

  @override
  Future<NavTrackImportPreview> prepare(Uint8List bytes, {String? fileName}) async {
    prepareCount++;
    const points = [
      NavTrackPoint(timestamp: 1755856800, north: 0, east: 0, depth: 5, distance: 0, speed: 0.3),
      NavTrackPoint(timestamp: 1755857400, north: 40, east: 0, depth: 5, distance: 40, speed: 0.3),
    ];
    return NavTrackImportPreview(
      parsed: const ParsedNavTrack(points: points),
      stats: NavTrackStats.of(points),
      segmentation: NavTrackSegmenter.classify(points),
      candidateDives: const [],
      nearbyDives: const [],
      duplicateOfRouteId: null,
      sourceRef: fileName ?? '',
    );
  }

  @override
  Future<String> commit({
    required ParsedNavTrack parsed,
    required String sourceRef,
    required String? diverId,
    Dive? dive,
    String? siteId,
    String? name,
    String? deviceName,
    String? equipmentId,
    String? replacingRouteId,
  }) async => throw UnimplementedError();
}

/// Rejects every file, so the GPS branch's error path is reachable.
class _RejectingTrackImport extends TrackImportService {
  @override
  Future<TrackImportCandidate> prepare({
    required String fileName,
    required Uint8List bytes,
  }) async => throw const TrackParseException(
    'no fixes',
    reason: TrackParseReason.noPositions,
  );
}

Future<void> _pumpImporter(WidgetTester tester, List<Override> overrides) async {
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...base, ...overrides],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => importTrackFile(context, ref),
              child: const Text('import'),
            ),
          ),
        ),
      ),
    ),
  );
}

void _pick(String name, Uint8List bytes) {
  final original = FilePickerPlatform.instance;
  addTearDown(() => FilePickerPlatform.instance = original);
  FilePickerPlatform.instance = MockFilePickerPlatform()
    ..pickFilesResult = [
      FakePlatformFile.contentUri(Uri.parse('content://picked/$name'), name: name, bytes: bytes),
    ];
}

void main() {
  group('isSeacraftEncFile', () {
    final enc = _fixture('seacraft_enc3_short.csv');

    test('an ENC CSV is recognised', () {
      expect(isSeacraftEncFile('005.DAT.csv', enc), isTrue);
    });

    test('the extension is read case-insensitively, and a BOM is tolerated', () {
      final withBom = Uint8List.fromList([...utf8.encode('\u{FEFF}'), ...enc]);
      expect(isSeacraftEncFile('005.DAT.CSV', withBom), isTrue);
    });

    test('an ordinary GPS CSV and a GPX file are not ENC', () {
      expect(isSeacraftEncFile('track.csv', utf8.encode('time,lat,lon\n1,2,3\n')), isFalse);
      expect(isSeacraftEncFile('track.gpx', enc), isFalse);
    });

    test('unreadable bytes are not ENC', () {
      expect(isSeacraftEncFile('x.csv', Uint8List.fromList([0xff, 0xfe, 0x00])), isFalse);
    });
  });

  testWidgets('an ENC file opens the underwater review with its preview', (tester) async {
    _pick('005.DAT.csv', _fixture('seacraft_enc3_short.csv'));
    final service = _PreparedNavImport();
    await _pumpImporter(tester, [navTrackImportServiceProvider.overrideWithValue(service)]);

    await tester.tap(find.text('import'));
    await tester.pumpAndSettle();

    final review = tester.widget<NavTrackImportReviewPage>(find.byType(NavTrackImportReviewPage));
    expect(review.fileName, '005.DAT.csv');
    expect(review.preview, isNotNull);
    expect(service.prepareCount, 1);
  });

  testWidgets('a GPS file the parser rejects shows the localized reason', (tester) async {
    _pick('track.gpx', Uint8List.fromList(utf8.encode('<gpx/>')));
    await _pumpImporter(tester, [trackImportServiceProvider.overrideWithValue(_RejectingTrackImport())]);

    await tester.tap(find.text('import'));
    await tester.pumpAndSettle();

    final expected = trackParseErrorText(
      lookupAppLocalizations(const Locale('en')),
      const TrackParseException('no fixes', reason: TrackParseReason.noPositions),
    );
    expect(find.text(expected), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/tracks/presentation/tracks_import_test.dart`
Expected: compile error, `tracks_import.dart` does not exist.

- [ ] **Step 3: Implement**

`lib/features/tracks/presentation/tracks_import.dart`:

```dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/gps_log/data/services/track_import/csv_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';
import 'package:submersion/features/gps_log/data/services/track_import/track_import_service.dart';
import 'package:submersion/features/gps_log/presentation/pages/track_import_review_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/track_parse_error_text.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/data/services/parsers/seacraft_enc_signature.dart';
import 'package:submersion/features/nav_track/presentation/nav_track_parse_error_text.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('TracksImport');

/// Whether a picked file is a Seacraft ENC navigation log rather than a GPS
/// track. Only a CSV can be one; its headers decide.
bool isSeacraftEncFile(String fileName, Uint8List bytes) {
  if (!fileName.toLowerCase().endsWith('.csv')) return false;
  try {
    return looksLikeSeacraftEnc(readCsvHeaders(bytes));
  } catch (_) {
    // Unreadable as CSV: not an ENC log, and the GPS parser reports why.
    return false;
  }
}

/// The Tracks page's Import action: picks one file and sends it to the
/// review page for its kind (spec 2026-10-02, "Import").
Future<void> importTrackFile(BuildContext context, WidgetRef ref) async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['gpx', 'kml', 'csv', 'fit'],
  );
  if (file == null) return;
  // FIT is binary, so read the bytes through the handle rather than via a
  // path: file_picker 12 retired `withData`, and on Android SAF there may be
  // no local path at all.
  final bytes = await file.readAsBytes();
  if (!context.mounted) return;

  if (isSeacraftEncFile(file.name, bytes)) {
    await _importUnderwater(context, ref, bytes, file.name);
  } else {
    await _importGps(context, ref, bytes, file.name);
  }
}

Future<void> _importUnderwater(
  BuildContext context,
  WidgetRef ref,
  Uint8List bytes,
  String fileName,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final NavTrackImportPreview preview;
  try {
    preview = await ref
        .read(navTrackImportServiceProvider)
        .prepare(bytes, fileName: fileName);
  } on NavTrackParseException catch (e) {
    _log.warning('Underwater track import rejected: ${e.message}');
    messenger.showSnackBar(
      SnackBar(content: Text(navTrackParseErrorText(l10n, e))),
    );
    return;
  } catch (e, stackTrace) {
    _log.error(
      'Underwater track import failed',
      error: e,
      stackTrace: stackTrace,
    );
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.navTrack_list_importFailed(e.toString()))),
    );
    return;
  }
  if (!context.mounted) return;
  await navigateToNavTrackReview(
    context,
    bytes,
    fileName: fileName,
    preview: preview,
  );
}

Future<void> _importGps(
  BuildContext context,
  WidgetRef ref,
  Uint8List bytes,
  String fileName,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final TrackImportCandidate candidate;
  try {
    candidate = await ref
        .read(trackImportServiceProvider)
        .prepare(fileName: fileName, bytes: bytes);
  } on TrackParseException catch (e) {
    // e.message names the offending element or row, in English. It belongs
    // in the log; the SnackBar gets the localized reason.
    _log.warning('Track import rejected: ${e.message}');
    messenger.showSnackBar(
      SnackBar(content: Text(trackParseErrorText(l10n, e))),
    );
    return;
  } catch (e, stackTrace) {
    _log.error('Track import failed', error: e, stackTrace: stackTrace);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.gpsTrack_import_failed('$e'))),
    );
    return;
  }
  await navigator.push<bool>(
    MaterialPageRoute(
      builder: (_) => TrackImportReviewPage(candidate: candidate, bytes: bytes),
    ),
  );
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/tracks/presentation/tracks_import_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format . && git add lib/features/tracks test/features/tracks && git commit -m "feat(tracks): one import action that tells ENC logs from GPS tracks

Refs #2833"
```

---

### Task 6: Extract the GPS record card

**Files:**
- Create: `lib/features/gps_log/presentation/widgets/gps_record_card.dart`
- Modify: `lib/features/gps_log/presentation/pages/gps_logger_page.dart` (delete `_RecordCard`, `_startLogging`, `_formatAge`, `_canRecord`; place `const GpsRecordCard()` where `_RecordCard(...)` was, guarded by `canRecordGpsTracks`)
- Test: `test/features/gps_log/gps_record_card_test.dart`

**Interfaces:**
- Produces: `bool get canRecordGpsTracks`; `class GpsRecordCard extends ConsumerWidget` (`const GpsRecordCard()`), owning start (with location-service and permission checks) and stop.

- [ ] **Step 1: Write the failing test**

`test/features/gps_log/gps_record_card_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_record_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

class _FakeGeolocator extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  _FakeGeolocator({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestResult = LocationPermission.whileInUse,
  });

  final bool serviceEnabled;
  LocationPermission permission;
  final LocationPermission requestResult;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permission = requestResult;
    return requestResult;
  }
}

/// Records start() without timers or database writes.
class _SpyRecorder extends GpsTrackRecorder {
  _SpyRecorder() : super(repository: GpsTrackRepository());

  bool started = false;

  @override
  bool get isRecording => started;

  @override
  Future<void> start({required String notificationTitle, required String notificationText}) async {
    started = true;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  GpsTrackRecorder? recorder,
  Stream<GpsRecorderState>? state,
}) async {
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        gpsTrackRecorderProvider.overrideWithValue(recorder ?? _SpyRecorder()),
        if (state != null) gpsRecorderStateProvider.overrideWith((ref) => state),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: GpsRecordCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final defaultGeolocator = GeolocatorPlatform.instance;
  tearDown(() => GeolocatorPlatform.instance = defaultGeolocator);

  test('only phones and tablets can record', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(canRecordGpsTracks, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(canRecordGpsTracks, isFalse);
  });

  testWidgets('idle shows the start button', (tester) async {
    await _pump(tester);
    expect(find.text('Start logging'), findsOneWidget);
  });

  testWidgets('recording shows points, last fix and stop', (tester) async {
    await _pump(
      tester,
      state: Stream.value(
        GpsRecorderState(
          status: GpsRecorderStatus.recording,
          trackId: 't1',
          pointCount: 4,
          startedAt: DateTime.now().toUtc(),
          lastFixAt: DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
          lastFixAccuracy: 8,
        ),
      ),
    );
    expect(find.text('Recording - 4 points'), findsOneWidget);
    expect(find.textContaining('Last fix'), findsOneWidget);
    expect(find.text('Stop logging'), findsOneWidget);
  });

  testWidgets('warns when location services are disabled', (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator(serviceEnabled: false);
    await _pump(tester);
    await tester.tap(find.text('Start logging'));
    await tester.pumpAndSettle();
    expect(find.text('Location services are turned off.'), findsOneWidget);
  });

  testWidgets('warns when permission is denied', (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator(
      permission: LocationPermission.denied,
      requestResult: LocationPermission.denied,
    );
    await _pump(tester);
    await tester.tap(find.text('Start logging'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Location permission is required to record a GPS track. '
        'Enable it in system settings.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('starts recording once permission is granted', (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator(
      permission: LocationPermission.denied,
      requestResult: LocationPermission.whileInUse,
    );
    final recorder = _SpyRecorder();
    await _pump(tester, recorder: recorder);
    await tester.tap(find.text('Start logging'));
    await tester.pumpAndSettle();
    expect(recorder.started, isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/gps_log/gps_record_card_test.dart`
Expected: compile error, `gps_record_card.dart` does not exist.

- [ ] **Step 3: Implement the card**

`lib/features/gps_log/presentation/widgets/gps_record_card.dart` (the body of `build` is `_RecordCard.build` from `gps_logger_page.dart`, with the start and stop handlers inlined):

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_row_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Recording only makes sense on the device that goes on the boat.
/// defaultTargetPlatform (not dart:io) so widget tests can override it.
bool get canRecordGpsTracks =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Starts and stops the surface GPS logger (discussion #289), with the live
/// point count and last-fix age while a recording runs.
class GpsRecordCard extends ConsumerWidget {
  const GpsRecordCard({super.key});

  static String _formatAge(DateTime lastFixAt) {
    final age = DateTime.now().toUtc().difference(lastFixAt);
    if (age.inMinutes < 1) return '<1min';
    return formatCompactDuration(age);
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    // Read before any await: the card may rebuild or leave the tree while
    // the permission prompt is up.
    final recorder = ref.read(gpsTrackRecorderProvider);
    if (!await Geolocator.isLocationServiceEnabled()) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gpsLogger_locationOff)),
      );
      return;
    }
    var permission = await LocationService.instance.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await LocationService.instance.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gpsLogger_permissionDenied)),
      );
      return;
    }
    await recorder.start(
      notificationTitle: l10n.gpsLogger_androidNotificationTitle,
      notificationText: l10n.gpsLogger_androidNotificationText,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final recorder = ref.watch(gpsTrackRecorderProvider);
    final state = ref.watch(gpsRecorderStateProvider).value ?? recorder.state;
    final recording = state.status == GpsRecorderStatus.recording;
    final units = UnitFormatter(ref.watch(settingsProvider));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (recording) ...[
              Text(
                l10n.gpsLogger_recordingStatus(state.pointCount),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                state.lastFixAt != null
                    ? l10n.gpsLogger_lastFix(
                        _formatAge(state.lastFixAt!),
                        units.formatDistance(state.lastFixAccuracy ?? 0),
                      )
                    : l10n.gpsLogger_noFixYet,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.stop),
                label: Text(l10n.gpsLogger_stopButton),
                onPressed: recorder.stop,
              ),
            ] else
              FilledButton.icon(
                icon: const Icon(Icons.gps_fixed),
                label: Text(l10n.gpsLogger_startButton),
                onPressed: () => _start(context, ref),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Use the card in the GPS logger page**

In `gps_logger_page.dart`: delete the `_canRecord` getter, `_startLogging`, `_formatAge` and the `_RecordCard` class. In `_buildSplit` replace the `leading:` argument with `leading: canRecordGpsTracks ? const GpsRecordCard() : null,`; in `_buildColumn` replace the `if (_canRecord) ...[ _RecordCard(...), const SizedBox(height: 16) ]` block with `if (canRecordGpsTracks) ...[const GpsRecordCard(), const SizedBox(height: 16)],`. Drop the `recorder` and `state` locals those blocks no longer read, add the `gps_record_card.dart` import, and remove every import `flutter analyze` then reports as unused.

- [ ] **Step 5: Run the tests**

Run: `flutter analyze lib/features/gps_log && flutter test test/features/gps_log/gps_record_card_test.dart test/features/gps_log/gps_logger_page_test.dart`
Expected: no analyzer issues; all PASS (the logger page tests are the safety net for the extraction).

- [ ] **Step 6: Commit**

```bash
dart format . && git add lib/features/gps_log test/features/gps_log/gps_record_card_test.dart && git commit -m "refactor(gps-log): extract the record card from the GPS logger page

Refs #2833"
```

---

### Task 7: Rows, badge and info card for both kinds

**Files:**
- Create: `lib/features/nav_track/presentation/widgets/nav_track_list_row.dart` (move `NavTrackListRow` out of `nav_track_list_page.dart`)
- Create: `lib/features/nav_track/presentation/widgets/nav_track_info_card.dart`
- Create: `lib/features/tracks/presentation/widgets/track_kind_badge.dart`
- Modify: `lib/features/nav_track/presentation/pages/nav_track_list_page.dart` (delete the moved class, import the new file)
- Modify: `lib/features/gps_log/presentation/widgets/gps_track_list_tile.dart` (add `kindBadge`)
- Test: `test/features/nav_track/presentation/widgets/nav_track_list_row_test.dart`
- Test: `test/features/nav_track/presentation/widgets/nav_track_info_card_test.dart`
- Test: `test/features/tracks/presentation/widgets/track_kind_badge_test.dart`
- Test: `test/features/gps_log/gps_track_list_tile_badge_test.dart`

**Interfaces:**
- Produces: `String formatNavTrackDetailLine(AppLocalizations l10n, UnitFormatter units, NavTrack route)`; `NavTrackListRow({required NavTrack route, required UnitFormatter units, required VoidCallback onTap, VoidCallback? onDelete, bool selected = false, Widget? kindBadge})` (`onDelete` is now optional; no trailing delete button when null); `NavTrackInfoCard({required NavTrack route, required VoidCallback onDetailsTap, required VoidCallback onClose})`; `TrackKindBadge(TrackKind kind)` keyed `ValueKey('track-kind-badge-${kind.name}')`; `GpsTrackListTile(..., Widget? kindBadge)`.

- [ ] **Step 1: Write the failing tests**

`test/features/tracks/presentation/widgets/track_kind_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/presentation/widgets/track_kind_badge.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('labels each kind', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Column(
          children: [TrackKindBadge(TrackKind.gps), TrackKindBadge(TrackKind.underwater)],
        ),
      ),
    );
    expect(find.text('GPS'), findsOneWidget);
    expect(find.text('Underwater'), findsOneWidget);
    expect(find.byKey(const ValueKey('track-kind-badge-gps')), findsOneWidget);
    expect(find.byKey(const ValueKey('track-kind-badge-underwater')), findsOneWidget);
  });
}
```

`test/features/gps_log/gps_track_list_tile_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_list_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('a kind badge sits under the detail line, which stays a Text', (tester) async {
    const track = GpsTrack(id: 't1', startTime: 1700000000000, endTime: 1700005400000, pointCount: 1);
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          gpsTrackGeometryProvider(('t1', TrackLod.thumbnail)).overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: [
                GpsTrackListTile(
                  track: track,
                  onTap: () {},
                  kindBadge: const SizedBox(key: ValueKey('badge'), width: 10, height: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final detail = tester.getRect(find.text('1 point, 1h 30m'));
    final badge = tester.getRect(find.byKey(const ValueKey('badge')));
    expect(badge.top, greaterThanOrEqualTo(detail.bottom));
  });
}
```

`test/features/nav_track/presentation/widgets/nav_track_info_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_info_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('shows the track and wires details and close', (tester) async {
    var opened = 0;
    var closed = 0;
    final route = NavTrack(
      id: 'r1',
      name: 'Wreck dive',
      source: NavTrackSource.seacraftEnc,
      startTime: 1755856800000,
      endTime: 1755860400000,
      durationSeconds: 600,
      pointCount: 5,
      totalDistance: 1050,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: base,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NavTrackInfoCard(
              route: route,
              onDetailsTap: () => opened++,
              onClose: () => closed++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wreck dive'), findsOneWidget);
    expect(find.textContaining('10min'), findsOneWidget);
    await tester.tap(find.byTooltip('View details'));
    await tester.tap(find.byIcon(Icons.close));
    expect(opened, 1);
    expect(closed, 1);
  });
}
```

`test/features/nav_track/presentation/widgets/nav_track_list_row_test.dart`: create it with this harness, then move the row test cases from `test/features/nav_track/presentation/pages/nav_track_list_page_test.dart` into it (see Step 2).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_list_row.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_shape_thumbnail.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

List<NavTrackPoint> _hydratedPoints() => [
  for (var i = 0; i < 5; i++)
    NavTrackPoint(timestamp: 1755856800 + i * 10, north: i * 10.0, east: 0, depth: 5),
];

NavTrack _route({
  required String id,
  String? diveId,
  String? name,
  String? deviceName,
  double? distance,
  double? maxDepth,
  double? anchorLatitude,
  double? anchorLongitude,
}) => NavTrack(
  id: id,
  diveId: diveId,
  linkMode: diveId == null ? null : NavTrackLinkMode.auto,
  name: name,
  deviceName: deviceName,
  source: NavTrackSource.seacraftEnc,
  sourceRef: '$id.csv',
  startTime: 1755856800000,
  endTime: 1755860400000,
  pointCount: 5,
  totalDistance: distance,
  maxDepth: maxDepth,
  anchorLatitude: anchorLatitude,
  anchorLongitude: anchorLongitude,
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

Widget _row(NavTrack route, {Widget? kindBadge}) => Consumer(
  builder: (context, ref, _) => ListView(
    children: [
      NavTrackListRow(
        route: route,
        units: UnitFormatter(ref.watch(settingsProvider)),
        onTap: () {},
        onDelete: () {},
        kindBadge: kindBadge,
      ),
    ],
  ),
);

Future<void> _pumpRow(
  WidgetTester tester, {
  required NavTrack route,
  Dive? linkedDive,
  Map<String, NavTrack>? hydrated,
  MockSettingsNotifier? settingsNotifier,
  List<Override> extraOverrides = const [],
  Locale? locale,
  Widget? kindBadge,
}) async {
  final overrides = await getBaseOverrides(settingsNotifier: settingsNotifier);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        if (linkedDive != null)
          diveProvider(linkedDive.id).overrideWith((ref) async => linkedDive),
        if (hydrated != null)
          for (final entry in hydrated.entries)
            navTrackByIdProvider(entry.key).overrideWith((ref) async => entry.value),
        ...extraOverrides,
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _row(route, kindBadge: kindBadge)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the detail line joins device and the stored duration', () {
    final line = formatNavTrackDetailLine(
      lookupAppLocalizations(const Locale('en')),
      const UnitFormatter(AppSettings()),
      _route(id: 'r1', deviceName: 'Seacraft ENC3').copyWith(durationSeconds: 600),
    );
    expect(line, contains('Seacraft ENC3'));
    expect(line, endsWith('10min'));
  });

  testWidgets('a kind badge sits on the chip line, below the status line', (tester) async {
    await _pumpRow(
      tester,
      route: _route(id: 'r1', name: 'Wreck dive', distance: 1050, maxDepth: 38),
      kindBadge: const SizedBox(key: ValueKey('badge'), width: 10, height: 10),
    );
    final status = tester.getRect(find.textContaining(' · '));
    final badge = tester.getRect(find.byKey(const ValueKey('badge')));
    expect(badge.top, greaterThanOrEqualTo(status.bottom));
  });

  testWidgets('no delete button without a delete callback', (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ListView(
                children: [
                  NavTrackListRow(
                    route: _route(id: 'r1', name: 'Wreck dive', anchorLatitude: 1, anchorLongitude: 2),
                    units: UnitFormatter(ref.watch(settingsProvider)),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('tapping a linked row\'s chip opens the linked dive', (tester) async {
    final dive = Dive(id: 'dive-1', diveNumber: 412, dateTime: DateTime(2026, 8, 22, 10, 8));
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: _row(_route(id: 'r1', name: 'Wreck', diveId: 'dive-1'))),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (_, state) => Text('dive page ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides, diveProvider('dive-1').overrideWith((ref) async => dive)],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-track-link-chip')));
    await tester.pumpAndSettle();

    expect(find.text('dive page dive-1'), findsOneWidget);
  });
}
```

`AppSettings` comes from the `settings_providers.dart` import already in that file.

- [ ] **Step 2: Move the row cases**

From `test/features/nav_track/presentation/pages/nav_track_list_page_test.dart`, cut these test cases and paste them into `main()` of `nav_track_list_row_test.dart`, changing each `_pump(tester, routes: [X], ...)` call to `_pumpRow(tester, route: X, ...)` and nothing else:

- `renders route rows with distance, depth and an unlinked chip`
- `a linked route shows a Dive # chip instead of unlinked`
- `a linked row keeps its name and status line readable on a narrow phone in German (#2692)`
- `the list row's date uses the wall-clock-as-UTC convention, ...`
- `an unanchored route's shape thumbnail renders the actual route, ...`
- `the list row shows the stored dive duration, not the raw recording span, ...`

Leave `tapping a linked row's chip opens the linked dive` in the old file for now (Step 1 already has its row-level twin); Task 13 deletes the old file.

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/tracks/presentation/widgets/track_kind_badge_test.dart test/features/gps_log/gps_track_list_tile_badge_test.dart test/features/nav_track/presentation/widgets/`
Expected: compile errors for the missing files and the unknown `kindBadge` parameter.

- [ ] **Step 4: Implement**

`lib/features/tracks/presentation/widgets/track_kind_badge.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "GPS" or "Underwater", so rows of both kinds read as one list.
class TrackKindBadge extends StatelessWidget {
  TrackKindBadge(this.kind) : super(key: ValueKey('track-kind-badge-${kind.name}'));

  final TrackKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final (label, background, foreground) = switch (kind) {
      TrackKind.gps => (
        l10n.tracks_kind_gps,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      TrackKind.underwater => (
        l10n.tracks_kind_underwater,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground),
        ),
      ),
    );
  }
}
```

The constructor computes its key, so it cannot be `const`; call sites write `TrackKindBadge(TrackKind.gps)` without `const`.

`gps_track_list_tile.dart`: add the field and parameter, and wrap the subtitle only when a badge is given:

```dart
    this.kindBadge,
  });
  ...
  /// Shown under the detail line, so the title keeps the full row width.
  final Widget? kindBadge;
  ...
      subtitle: kindBadge == null
          ? Text(formatTrackDetailLine(l10n, units, track))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatTrackDetailLine(l10n, units, track)),
                const SizedBox(height: 4),
                kindBadge!,
              ],
            ),
```

`nav_track_list_row.dart`: move the `NavTrackListRow` class out of `nav_track_list_page.dart` unchanged, then make these edits:

```dart
/// Date, device, distance, max depth and duration of one underwater track,
/// as the row and the map info card show it.
///
/// `route.startTime` is wall-clock-as-UTC epoch milliseconds, the same
/// convention as dives.entryTime: constructing a local DateTime would let
/// the date shift across midnight on a device outside UTC.
String formatNavTrackDetailLine(
  AppLocalizations l10n,
  UnitFormatter units,
  NavTrack route,
) {
  final startedAt = DateTime.fromMillisecondsSinceEpoch(
    route.startTime,
    isUtc: true,
  );
  return [
    units.formatDate(startedAt),
    if (route.deviceName != null) route.deviceName!,
    if (route.totalDistance != null) units.formatDistance(route.totalDistance!),
    if (route.maxDepth != null) units.formatDepth(route.maxDepth),
    _formatNavTrackDuration(l10n, route),
  ].join(' · ');
}

/// Duration up to the last dead-reckoned sample, as stored at import, with
/// the raw span only as the fallback for a row stored before it was.
String _formatNavTrackDuration(AppLocalizations l10n, NavTrack route) {
  final seconds =
      route.durationSeconds ??
      ((route.endTime - route.startTime) / 1000).round();
  final d = Duration(seconds: seconds < 0 ? 0 : seconds);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return h > 0
      ? l10n.navTrack_list_durationHours(h, m)
      : l10n.navTrack_list_durationMinutes(m);
}
```

Delete the row's own `_formatDuration` method and `startedAt` local (the doc comments they carried now sit on the functions above). In the row: make `onDelete` a nullable `final VoidCallback? onDelete;` with `this.onDelete` (not `required`), add `this.kindBadge` and `final Widget? kindBadge;`, change the first subtitle child to `Text(formatNavTrackDetailLine(l10n, units, route)),`, replace the second subtitle child `_linkChip(context, l10n, ref)` with

```dart
          kindBadge == null
              ? _linkChip(context, l10n, ref)
              : Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [kindBadge!, _linkChip(context, l10n, ref)],
                ),
```

and the trailing with `trailing: onDelete == null ? null : IconButton(icon: const Icon(Icons.delete_outline), tooltip: l10n.navTrack_common_delete, onPressed: onDelete),`. Keep the #2692 comment about why the chip sits below the status line.

In `nav_track_list_page.dart` add `import 'package:submersion/features/nav_track/presentation/widgets/nav_track_list_row.dart';` and remove imports the analyzer reports unused.

`lib/features/nav_track/presentation/widgets/nav_track_info_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_list_row.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';

/// The overview map's card for a selected underwater track, the twin of
/// GpsTrackInfoCard.
class NavTrackInfoCard extends ConsumerWidget {
  const NavTrackInfoCard({
    super.key,
    required this.route,
    required this.onDetailsTap,
    required this.onClose,
  });

  final NavTrack route;
  final VoidCallback onDetailsTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final scheme = Theme.of(context).colorScheme;
    return MapInfoCard(
      title: route.name ?? route.sourceRef ?? route.id,
      subtitle: formatNavTrackDetailLine(context.l10n, units, route),
      leading: CircleAvatar(
        backgroundColor: scheme.tertiaryContainer,
        child: Icon(Icons.route, color: scheme.tertiary),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: onClose,
      ),
      onDetailsTap: onDetailsTap,
    );
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter analyze lib/features/nav_track lib/features/gps_log lib/features/tracks && flutter test test/features/nav_track/presentation test/features/gps_log/gps_track_list_tile_badge_test.dart test/features/tracks/presentation/widgets/track_kind_badge_test.dart test/architecture/list_tile_trailing_width_test.dart`
Expected: no analyzer issues; all PASS, including the remaining `nav_track_list_page_test.dart` cases.

- [ ] **Step 6: Commit**

```bash
dart format . && git add lib/features/nav_track lib/features/gps_log lib/features/tracks test/features/nav_track test/features/gps_log/gps_track_list_tile_badge_test.dart test/features/tracks && git commit -m "feat(tracks): kind badges, an underwater info card and a reusable track row

Refs #2833"
```

---

### Task 8: One overview map for both kinds

**Files:**
- Create: `lib/features/tracks/presentation/track_item_location.dart`
- Create: `lib/features/tracks/presentation/widgets/tracks_overview_map.dart`
- Create: `lib/features/tracks/presentation/widgets/tracks_map_pane.dart`
- Test: `test/features/tracks/presentation/widgets/tracks_overview_map_test.dart`

**Interfaces:**
- Consumes: `TrackListItem` and variants; `gpsTrackGeometryProvider((String, TrackLod))`; `navTrackByIdProvider(String)`; `NavTrackPolylineLayer(route:)`; `TrackCamera.forPoints`; `tracksOverviewProvider`, `tracksListProvider`; `GpsTrackEmptyMap(message:)`; `GpsTrackInfoCard`, `NavTrackInfoCard`.
- Produces: `const String kTracksSectionKey = 'tracks'`; `String trackLocationOf(TrackListItem)`; `String tracksMapFramingSignature({required List<TrackListItem> items, required int pointCount, required String? selectedKey})`; `TracksOverviewMap({required List<TrackListItem> items, required String? selectedKey, required MapController controller})`; `TracksMapPane({required MapController controller})`; `Widget? tracksInfoCard({required WidgetRef ref, required ValueChanged<TrackListItem> onOpen})`.

- [ ] **Step 1: Write the failing tests**

`test/features/tracks/presentation/widgets/tracks_overview_map_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/track_item_location.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_overview_map.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

GpsTrackPoint _p(int t, double base) =>
    GpsTrackPoint(timestamp: t, latitude: base + t * 0.001, longitude: -87.0 + t * 0.001);

GpsTrack _gps(String id, double base) => GpsTrack(
  id: id,
  startTime: 1700000000000,
  endTime: 1700003600000,
  pointCount: 3,
  points: [_p(0, base), _p(1, base), _p(2, base)],
);

NavTrack _uw(String id, {double? lat, double? lon, List<NavTrackPoint> points = const []}) => NavTrack(
  id: id,
  source: NavTrackSource.seacraftEnc,
  startTime: 1755856800000,
  endTime: 1755860400000,
  pointCount: points.length,
  anchorLatitude: lat,
  anchorLongitude: lon,
  points: points,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _points = [
  for (var i = 0; i < 5; i++)
    NavTrackPoint(timestamp: 1755856800 + i * 10, north: i * 10.0, east: 0, depth: 5),
];

Future<MapController> _pump(
  WidgetTester tester, {
  required List<TrackListItem> items,
  String? selectedKey,
}) async {
  final controller = MapController();
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        for (final item in items)
          if (item is GpsTrackItem)
            gpsTrackGeometryProvider((item.id, TrackLod.thumbnail)).overrideWith((ref) async => item.track.points),
        for (final item in items)
          if (item is UnderwaterTrackItem)
            navTrackByIdProvider(item.id).overrideWith((ref) async => item.track.copyWith(points: _points)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TracksOverviewMap(items: items, selectedKey: selectedKey, controller: controller),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  group('tracksMapFramingSignature', () {
    test('changes when an anchored underwater track is realigned', () {
      String sig(double lat) => tracksMapFramingSignature(
        items: [UnderwaterTrackItem(_uw('a', lat: lat, lon: 8.3))],
        pointCount: 1,
        selectedKey: null,
      );
      expect(sig(46.9), isNot(sig(47.1)));
    });

    test('stays the same for the same tracks at the same anchors', () {
      String sig() => tracksMapFramingSignature(
        items: [UnderwaterTrackItem(_uw('a', lat: 47.1, lon: 8.3)), GpsTrackItem(_gps('g', 20))],
        pointCount: 4,
        selectedKey: 'gps:g',
      );
      expect(sig(), sig());
    });
  });

  test('a list item resolves to its own detail location', () {
    expect(trackLocationOf(GpsTrackItem(_gps('g', 20))), '/tracks/gps/g');
    expect(trackLocationOf(UnderwaterTrackItem(_uw('u'))), '/tracks/underwater/u');
  });

  testWidgets('draws GPS polylines and hydrated underwater tracks on one map', (tester) async {
    await _pump(tester, items: [
      GpsTrackItem(_gps('t1', 20)),
      GpsTrackItem(_gps('t2', 25)),
      UnderwaterTrackItem(_uw('u1', lat: 20.5, lon: -87.0)),
    ]);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsOneWidget);
    final gps = tester.widget<PolylineLayer<String>>(find.byType(PolylineLayer<String>));
    expect(gps.polylines.length, 2);
    final underwater = tester.widget<NavTrackPolylineLayer>(find.byType(NavTrackPolylineLayer));
    expect(underwater.route.points, isNotEmpty);
  });

  testWidgets('a selected GPS track is drawn last with a thicker stroke', (tester) async {
    await _pump(
      tester,
      items: [GpsTrackItem(_gps('t1', 20)), GpsTrackItem(_gps('t2', 25))],
      selectedKey: 'gps:t1',
    );
    final layer = tester.widget<PolylineLayer<String>>(find.byType(PolylineLayer<String>));
    expect(layer.polylines.last.hitValue, 'gps:t1');
    expect(layer.polylines.last.strokeWidth, 4.0);
  });

  testWidgets('an underwater-only map has no GPS layer', (tester) async {
    await _pump(tester, items: [UnderwaterTrackItem(_uw('u1', lat: 47.1, lon: 8.3))]);
    expect(find.byType(PolylineLayer<String>), findsNothing);
    expect(find.byType(NavTrackPolylineLayer), findsOneWidget);
  });

  testWidgets('selecting an underwater track frames its anchor', (tester) async {
    final controller = await _pump(
      tester,
      items: [GpsTrackItem(_gps('t1', 20)), UnderwaterTrackItem(_uw('u1', lat: 47.1, lon: 8.3))],
      selectedKey: 'underwater:u1',
    );
    expect(controller.camera.center.latitude, closeTo(47.1, 0.01));
    expect(controller.camera.center.longitude, closeTo(8.3, 0.01));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/tracks/presentation/widgets/tracks_overview_map_test.dart`
Expected: compile errors, the imported files do not exist.

- [ ] **Step 3: Implement**

`lib/features/tracks/presentation/track_item_location.dart`:

```dart
import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';

/// The detail page a list item opens.
String trackLocationOf(TrackListItem item) => switch (item) {
  GpsTrackItem() => gpsTrackLocation(item.id),
  UnderwaterTrackItem() => underwaterTrackLocation(item.id),
};
```

`lib/features/tracks/presentation/widgets/tracks_overview_map.dart` (ported from `gps_track_overview_map.dart`; keep its comments on framing, which still apply):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_camera.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';

/// Selection section shared by every Tracks surface that pairs the list
/// with the overview map, so a track picked on one stays picked on the
/// other. Holds a [TrackListItem.selectionKey].
const String kTracksSectionKey = 'tracks';

/// What the map's framing depends on: how many items and points it frames,
/// the selection, and where each underwater track is anchored, so a
/// realigned track is brought back into view, not only one arriving.
String tracksMapFramingSignature({
  required List<TrackListItem> items,
  required int pointCount,
  required String? selectedKey,
}) {
  final anchors = [
    for (final item in items)
      if (item is UnderwaterTrackItem)
        '${item.id}@${item.track.anchorLatitude},${item.track.anchorLongitude}',
  ].join(';');
  return '${items.length}:$pointCount:$selectedKey:$anchors';
}

/// Every given track on one map: GPS tracks as polylines (the selected one
/// on top), underwater tracks through their own layer.
class TracksOverviewMap extends ConsumerStatefulWidget {
  const TracksOverviewMap({
    super.key,
    required this.items,
    required this.selectedKey,
    required this.controller,
  });

  /// Mappable items only (tracksOverviewProvider).
  final List<TrackListItem> items;
  final String? selectedKey;
  final MapController controller;

  @override
  ConsumerState<TracksOverviewMap> createState() => _TracksOverviewMapState();
}

class _TracksOverviewMapState extends ConsumerState<TracksOverviewMap> {
  bool _mapReady = false;

  /// Signature of the framing currently applied, so a filter change or a
  /// late-arriving simplify re-frames but an unrelated rebuild does not.
  String? _framedOn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedKey = widget.selectedKey;

    final unselected = <Polyline<String>>[];
    Polyline<String>? selected;
    List<GpsTrackPoint>? selectedPoints;
    final allPoints = <GpsTrackPoint>[];
    final anchored = <UnderwaterTrackItem>[];

    for (final item in widget.items) {
      final isSelected = item.selectionKey == selectedKey;
      switch (item) {
        case GpsTrackItem():
          final geometry =
              ref
                  .watch(gpsTrackGeometryProvider((item.id, TrackLod.thumbnail)))
                  .value ??
              const <GpsTrackPoint>[];
          if (geometry.length >= 2) {
            allPoints.addAll(geometry);
            final line = Polyline<String>(
              points: [for (final p in geometry) LatLng(p.latitude, p.longitude)],
              color: isSelected ? scheme.primary : scheme.outline,
              strokeWidth: isSelected ? 4.0 : 2.0,
              strokeCap: StrokeCap.round,
              hitValue: item.selectionKey,
            );
            if (isSelected) {
              selected = line;
              selectedPoints = geometry;
            } else {
              unselected.add(line);
            }
          }
        case UnderwaterTrackItem(:final track):
          final anchor = track.anchor;
          if (anchor != null) {
            anchored.add(item);
            // Framing reads the anchor alone: hydrating every underwater
            // track's points just to frame the map would cost a blob decode
            // per track before anything is drawn.
            final point = GpsTrackPoint(
              timestamp: 0,
              latitude: anchor.latitude,
              longitude: anchor.longitude,
            );
            allPoints.add(point);
            if (isSelected) selectedPoints = [point];
          }
      }
    }

    // A selection frames that track alone; clearing it frames the library
    // again. Null while nothing can be framed yet.
    final camera = TrackCamera.forPoints(selectedPoints ?? allPoints);

    final signature = tracksMapFramingSignature(
      items: widget.items,
      pointCount: allPoints.length,
      selectedKey: selectedKey,
    );
    if (_mapReady && _framedOn != signature) {
      _framedOn = signature;
      if (camera != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) camera.applyTo(widget.controller);
        });
      }
    }

    return TrackpadZoomMap(
      controller: widget.controller,
      child: FlutterMap(
        mapController: widget.controller,
        options: MapOptions(
          onMapReady: () {
            _mapReady = true;
            _framedOn = signature;
            // Geometry that arrived between the first build and the map
            // becoming ready would otherwise never be framed.
            camera?.applyTo(widget.controller);
          },
          initialCameraFit: camera?.fit,
          initialCenter: camera?.center ?? const LatLng(20, 0),
          initialZoom: camera?.zoom ?? 2.0,
          interactionOptions: rotatableMapInteraction,
        ),
        children: [
          submersionTileLayer(ref),
          if (unselected.isNotEmpty || selected != null)
            PolylineLayer<String>(
              // Selected drawn last so it sits above any track it overlaps.
              polylines: [...unselected, ?selected],
            ),
          for (final item in anchored)
            _HydratedUnderwaterPolyline(
              key: ValueKey(item.selectionKey),
              trackId: item.id,
            ),
          const MapAttribution(),
          MapCompassButton(controller: widget.controller),
        ],
      ),
    );
  }
}

/// Hydrates one anchored underwater track's points before drawing it: the
/// list reads without points, so only tracks actually on the map pay for a
/// blob decode.
class _HydratedUnderwaterPolyline extends ConsumerWidget {
  const _HydratedUnderwaterPolyline({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hydrated = ref.watch(navTrackByIdProvider(trackId)).value;
    if (hydrated == null) return const SizedBox.shrink();
    return NavTrackPolylineLayer(route: hydrated);
  }
}
```

`lib/features/tracks/presentation/widgets/tracks_map_pane.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/gps_log/presentation/widgets/gps_track_empty_map.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_info_card.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_info_card.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_overview_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';

/// The map side of the Tracks split and the phone map page.
///
/// A loading library must not flash the empty message, and a failed query
/// must not claim there are no tracks.
class TracksMapPane extends ConsumerWidget {
  const TracksMapPane({super.key, required this.controller});

  final MapController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overviewAsync = ref.watch(tracksOverviewProvider);
    final overview = overviewAsync.value ?? const <TrackListItem>[];
    final listed = ref.watch(tracksListProvider).value ?? const <TrackListItem>[];
    final selection = ref.watch(mapListSelectionProvider(kTracksSectionKey));
    return switch (overviewAsync) {
      AsyncLoading() when overview.isEmpty => const Center(
        child: CircularProgressIndicator(),
      ),
      AsyncError() => Center(child: Text(l10n.common_error_tryAgain)),
      // Tracks exist but none can be placed: say so rather than "no tracks".
      _ when overview.isEmpty => GpsTrackEmptyMap(
        message: listed.isEmpty
            ? l10n.gpsTrack_map_noTracks
            : l10n.tracks_map_noMappable,
      ),
      _ => TracksOverviewMap(
        items: overview,
        selectedKey: selection.selectedId,
        controller: controller,
      ),
    };
  }
}

/// The info card for the selected track, or null when nothing listed is
/// selected (including a selection the filters now hide). Call from build.
Widget? tracksInfoCard({
  required WidgetRef ref,
  required ValueChanged<TrackListItem> onOpen,
}) {
  final items = ref.watch(tracksListProvider).value ?? const <TrackListItem>[];
  final section = mapListSelectionProvider(kTracksSectionKey);
  final selectedKey = ref.watch(section).selectedId;
  final selected = items
      .where((item) => item.selectionKey == selectedKey)
      .firstOrNull;
  if (selected == null) return null;
  void close() => ref.read(section.notifier).deselect();
  return switch (selected) {
    GpsTrackItem(:final track) => GpsTrackInfoCard(
      track: track,
      onDetailsTap: () => onOpen(selected),
      onClose: close,
    ),
    UnderwaterTrackItem(:final track) => NavTrackInfoCard(
      route: track,
      onDetailsTap: () => onOpen(selected),
      onClose: close,
    ),
  };
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/tracks/presentation/widgets/tracks_overview_map_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format . && git add lib/features/tracks test/features/tracks && git commit -m "feat(tracks): one overview map for GPS and underwater tracks

Refs #2833"
```

---

### Task 9: The Tracks landing page

**Files:**
- Create: `lib/features/tracks/presentation/widgets/track_kind_filter_control.dart`
- Create: `lib/features/tracks/presentation/widgets/tracks_summary_strip.dart`
- Create: `lib/features/tracks/presentation/widgets/tracks_empty_state.dart`
- Create: `lib/features/tracks/presentation/widgets/tracks_list_header.dart`
- Create: `lib/features/tracks/presentation/widgets/tracks_list_pane.dart`
- Create: `lib/features/tracks/presentation/pages/tracks_page.dart`
- Modify: `lib/core/theme/feature_accent_colors.dart` (add a `'tracks'` entry beside `'gps-log'` in both palettes, same colours: light `Color(0xFFD32F2F)`, dark `Color(0xFFE57373)`)
- Test: `test/features/tracks/presentation/pages/tracks_page_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 2 to 8; `GpsTrackDateFilterAction`; `deleteTrackProvider`; `navTrackRepositoryProvider`; `gpsTrackRepositoryProvider.recoverOrphanedTracks()`; `MapListScaffold`; `FeatureAppBarTitle`.
- Produces: `TracksPage({TrackKindFilter? initialKind})`; `TracksListPane({required String? selectedKey, required ValueChanged<TrackListItem> onTap, VoidCallback? onMatch, ValueChanged<TrackListItem>? onDelete, bool showControls = true})`.

- [ ] **Step 1: Write the failing tests**

`test/features/tracks/presentation/pages/tracks_page_test.dart`:

```dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_thumbnail.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_match_service.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_service_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/presentation/pages/tracks_page.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_overview_map.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_summary_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';

import '../../../../helpers/test_database.dart';

class _GpsMatch extends GpsTrackMatchService {
  _GpsMatch({this.result = const [], this.fail = false})
    : super(trackRepository: GpsTrackRepository(), diveRepository: DiveRepository());
  final List<String> result;
  final bool fail;

  @override
  Future<List<String>> sweep({List<String>? limitToIds}) async {
    if (fail) throw StateError('sweep failed');
    return result;
  }
}

class _UnderwaterMatch extends NavTrackMatchService {
  _UnderwaterMatch({this.linked = const []})
    : super(routeRepository: NavTrackRepository(), diveRepository: DiveRepository());
  final List<String> linked;
  int calls = 0;

  @override
  Future<({List<String> linked, List<String> needsChoice})> sweep({
    List<String>? limitToRouteIds,
    List<String>? limitToDiveIds,
  }) async {
    calls++;
    return (linked: linked, needsChoice: const <String>[]);
  }
}

/// Records deletes instead of touching the nav table.
class _RecordingNavRepository extends NavTrackRepository {
  String? deletedId;

  @override
  Future<void> delete(String routeId) async => deletedId = routeId;
}

final _points = [
  for (var i = 0; i < 5; i++)
    NavTrackPoint(timestamp: 1755856800 + i * 10, north: i * 10.0, east: 0, depth: 5),
];

NavTrack _uw({bool anchored = false}) => NavTrack(
  id: 'r1',
  name: 'Wreck dive',
  source: NavTrackSource.seacraftEnc,
  sourceRef: 'r1.csv',
  startTime: 1755856800000,
  endTime: 1755860400000,
  durationSeconds: 600,
  pointCount: 5,
  anchorLatitude: anchored ? 1.002 : null,
  anchorLongitude: anchored ? 2.002 : null,
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

const _twoFixes = [
  GpsTrackPoint(timestamp: 1700000000, latitude: 1, longitude: 2),
  GpsTrackPoint(timestamp: 1700000600, latitude: 1.003, longitude: 2.003),
];
const _desktop = Size(1400, 900);

void main() {
  late GpsTrackRepository repo;
  late _RecordingNavRepository navRepo;

  setUp(() async {
    await setUpTestDatabase();
    repo = GpsTrackRepository();
    navRepo = _RecordingNavRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<String> seedGps() async {
    final id = await repo.startTrack(startTimeMs: 1700000000000, tzOffsetMinutes: 0);
    await repo.appendBufferPoint(
      id,
      const GpsTrackPoint(timestamp: 1700000000, latitude: 1, longitude: 2),
    );
    await repo.finalizeTrack(id, endTimeMs: 1700005400000);
    return id;
  }

  Future<Widget> app({
    List<NavTrack> underwater = const [],
    GpsTrackMatchService? gpsMatch,
    NavTrackMatchService? underwaterMatch,
    Size? size,
    String initialLocation = '/tracks',
    Map<String, List<GpsTrackPoint>> geometry = const {},
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/tracks',
          builder: (context, state) => TracksPage(
            initialKind: TrackKindFilter.fromQuery(state.uri.queryParameters['kind']),
          ),
        ),
        GoRoute(path: '/tracks/map', builder: (_, _) => const Scaffold(body: Text('MAP-PAGE'))),
        GoRoute(path: '/tracks/gps/:id', builder: (_, _) => const Scaffold(body: Text('GPS-DETAIL'))),
        GoRoute(
          path: '/tracks/underwater/:id',
          builder: (_, state) => Scaffold(body: Text('UNDERWATER-DETAIL ${state.pathParameters['id']}')),
        ),
        GoRoute(path: '/dives/match-sites', builder: (_, _) => const Scaffold(body: Text('MATCH-SITES-PAGE'))),
      ],
    );
    addTearDown(router.dispose);
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        allNavTracksProvider.overrideWith((ref) async => underwater),
        navTrackRepositoryProvider.overrideWithValue(navRepo),
        navTrackMatchServiceProvider.overrideWithValue(underwaterMatch ?? _UnderwaterMatch()),
        for (final track in underwater)
          navTrackByIdProvider(track.id).overrideWith((ref) async => track.copyWith(points: _points)),
        if (gpsMatch != null) gpsTrackMatchServiceProvider.overrideWithValue(gpsMatch),
        for (final entry in geometry.entries)
          gpsTrackGeometryProvider((entry.key, TrackLod.thumbnail)).overrideWith((ref) async => entry.value),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The breakpoint reads MediaQuery; setSurfaceSize alone is not what
        // the page sees.
        builder: size == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(size: size),
                child: child!,
              ),
      ),
    );
  }

  Finder row(String key) => find.byKey(ValueKey(key));
  Finder kindSegment(String label) => find.descendant(
    of: find.byKey(const ValueKey('tracks-kind-filter')),
    matching: find.text(label),
  );

  testWidgets('a desktop platform hides record controls; an empty library '
      'explains both kinds', (tester) async {
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();
    expect(find.text('Start logging'), findsNothing);
    expect(find.text('No tracks yet'), findsOneWidget);
    expect(find.text('Match tracks to dives'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a phone shows the record card', (tester) async {
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();
    expect(find.text('Start logging'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('both kinds share one list, newest first, each badged', (tester) async {
    final gpsId = await seedGps();
    await tester.pumpWidget(await app(underwater: [_uw()]));
    await tester.pumpAndSettle();

    final underwaterTop = tester.getTopLeft(row('underwater:r1')).dy;
    final gpsTop = tester.getTopLeft(row('gps:$gpsId')).dy;
    expect(underwaterTop, lessThan(gpsTop), reason: 'the 2025 underwater track is newer');
    expect(find.byKey(const ValueKey('track-kind-badge-gps')), findsOneWidget);
    expect(find.byKey(const ValueKey('track-kind-badge-underwater')), findsOneWidget);
  });

  testWidgets('the kind filter narrows the list', (tester) async {
    final gpsId = await seedGps();
    await tester.pumpWidget(await app(underwater: [_uw()]));
    await tester.pumpAndSettle();

    await tester.tap(kindSegment('Underwater'));
    await tester.pumpAndSettle();
    expect(row('gps:$gpsId'), findsNothing);
    expect(row('underwater:r1'), findsOneWidget);
  });

  testWidgets('a kind link seeds the filter', (tester) async {
    final gpsId = await seedGps();
    await tester.pumpWidget(await app(underwater: [_uw()], initialLocation: '/tracks?kind=underwater'));
    await tester.pumpAndSettle();
    expect(row('gps:$gpsId'), findsNothing);
    expect(row('underwater:r1'), findsOneWidget);
  });

  testWidgets('filters that hide everything say so, and clearing them '
      'restores the list', (tester) async {
    final gpsId = await seedGps();
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();

    await tester.tap(kindSegment('Underwater'));
    await tester.pumpAndSettle();
    expect(find.text('No tracks match these filters'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(row('gps:$gpsId'), findsOneWidget);
  });

  testWidgets('on a phone a row opens its track', (tester) async {
    await tester.pumpWidget(await app(underwater: [_uw()]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wreck dive'));
    await tester.pumpAndSettle();
    expect(find.text('UNDERWATER-DETAIL r1'), findsOneWidget);
  });

  testWidgets('match reports both sweeps and links to the site review', (tester) async {
    await tester.pumpWidget(
      await app(
        gpsMatch: _GpsMatch(result: const ['d1', 'd2']),
        underwaterMatch: _UnderwaterMatch(linked: const ['r1']),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match tracks to dives'));
    await tester.pumpAndSettle();
    expect(find.text('Dives positioned: 2 · Underwater tracks linked: 1'), findsOneWidget);

    await tester.tap(find.text('Review site matches'));
    await tester.pumpAndSettle();
    expect(find.text('MATCH-SITES-PAGE'), findsOneWidget);
  });

  testWidgets('a failing GPS sweep still runs the underwater one', (tester) async {
    final underwaterMatch = _UnderwaterMatch();
    await tester.pumpWidget(await app(gpsMatch: _GpsMatch(fail: true), underwaterMatch: underwaterMatch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match tracks to dives'));
    await tester.pumpAndSettle();
    expect(underwaterMatch.calls, 1);
    expect(find.text('Some tracks could not be matched. Try again.'), findsOneWidget);
  });

  testWidgets('deleting a GPS track confirms, then removes it', (tester) async {
    final id = await seedGps();
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete track?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(await repo.getTrack(id), isNull);
  });

  testWidgets('deleting an underwater track goes through its repository', (tester) async {
    await tester.pumpWidget(await app(underwater: [_uw()]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Wreck dive"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(navRepo.deletedId, 'r1');
  });

  testWidgets('an interrupted recording surfaces a recovery notice', (tester) async {
    final id = await repo.startTrack(startTimeMs: 1700000000000, tzOffsetMinutes: 0);
    await repo.appendBufferPoint(
      id,
      const GpsTrackPoint(timestamp: 1700000000, latitude: 1, longitude: 2),
    );
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();
    expect(find.text('A previous recording was interrupted. The track was saved.'), findsOneWidget);
    expect(find.byType(GpsTrackThumbnail), findsOneWidget);
  });

  testWidgets('the summary counts both kinds', (tester) async {
    await seedGps();
    await tester.pumpWidget(await app(underwater: [_uw()]));
    await tester.pumpAndSettle();
    final strip = find.byType(TracksSummaryStrip);
    // 1h 30m of GPS plus the 10-minute underwater dive.
    expect(find.descendant(of: strip, matching: find.text('1h 40m')), findsOneWidget);
    expect(find.descendant(of: strip, matching: find.text('2')), findsOneWidget);
  });

  group('desktop split', () {
    testWidgets('the list sits beside one map drawing both kinds', (tester) async {
      final id = await seedGps();
      await tester.pumpWidget(
        await app(size: _desktop, underwater: [_uw(anchored: true)], geometry: {id: _twoFixes}),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PolylineLayer<String>), findsOneWidget);
      expect(find.byType(NavTrackPolylineLayer), findsOneWidget);
      expect(find.byTooltip('Show map'), findsNothing);
    });

    testWidgets('a phone-width surface keeps the single column', (tester) async {
      final id = await seedGps();
      await tester.pumpWidget(await app(size: const Size(390, 844), geometry: {id: _twoFixes}));
      await tester.pumpAndSettle();
      expect(find.byType(PolylineLayer<String>), findsNothing);
      expect(find.byTooltip('Show map'), findsOneWidget);
    });

    testWidgets('a row selects its track; the info card opens it', (tester) async {
      final id = await seedGps();
      await tester.pumpWidget(await app(size: _desktop, geometry: {id: _twoFixes}));
      await tester.pumpAndSettle();
      expect(find.byType(MapInfoCard), findsNothing);

      await tester.tap(find.text('1 point, 1h 30m'));
      await tester.pumpAndSettle();
      expect(find.byType(MapInfoCard), findsOneWidget);
      expect(find.text('GPS-DETAIL'), findsNothing);

      await tester.tap(find.byTooltip('View details'));
      await tester.pumpAndSettle();
      expect(find.text('GPS-DETAIL'), findsOneWidget);
    });

    testWidgets('an underwater row shows its own info card', (tester) async {
      await tester.pumpWidget(await app(size: _desktop, underwater: [_uw(anchored: true)]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wreck dive'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('View details'));
      await tester.pumpAndSettle();
      expect(find.text('UNDERWATER-DETAIL r1'), findsOneWidget);
    });

    testWidgets('a selection the kind filter hides loses its info card', (tester) async {
      final id = await seedGps();
      await tester.pumpWidget(
        await app(size: _desktop, underwater: [_uw(anchored: true)], geometry: {id: _twoFixes}),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 point, 1h 30m'));
      await tester.pumpAndSettle();
      expect(find.byType(MapInfoCard), findsOneWidget);

      await tester.tap(kindSegment('Underwater'));
      await tester.pumpAndSettle();
      expect(find.byType(MapInfoCard), findsNothing);
    });

    testWidgets('deleting the selected track clears its info card', (tester) async {
      final id = await seedGps();
      await tester.pumpWidget(await app(size: _desktop, geometry: {id: _twoFixes}));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 point, 1h 30m'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(MapInfoCard), findsNothing);
      expect(find.text('No tracks yet'), findsOneWidget);
      // The row is gone either way; the selection itself must be cleared too,
      // or a later track reusing the key would open preselected.
      final container = ProviderScope.containerOf(tester.element(find.byType(TracksPage)));
      expect(container.read(mapListSelectionProvider(kTracksSectionKey)).selectedId, isNull);
    });

    testWidgets('unanchored-only tracks say they have no map position', (tester) async {
      await tester.pumpWidget(await app(size: _desktop, underwater: [_uw()]));
      await tester.pumpAndSettle();
      expect(find.text('None of these tracks has a position on the map yet.'), findsOneWidget);
    });

    testWidgets('an empty library shows an empty basemap', (tester) async {
      await tester.pumpWidget(await app(size: _desktop));
      await tester.pumpAndSettle();
      expect(find.text('No recorded tracks to show.'), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('a tablet wide enough for the split still records', (tester) async {
      await tester.pumpWidget(await app(size: _desktop));
      await tester.pumpAndSettle();
      expect(find.text('Start logging'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
```

`p` and `Uint8List`/`FilePicker` imports above are used by Task 13's ported cases; drop any the analyzer reports unused at this step.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/tracks/presentation/pages/tracks_page_test.dart`
Expected: compile errors, `tracks_page.dart` and the widgets do not exist.

- [ ] **Step 3: Implement the widgets**

`lib/features/tracks/presentation/widgets/track_kind_filter_control.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// All / GPS / Underwater, at the top of the Tracks list.
class TrackKindFilterControl extends ConsumerWidget {
  const TrackKindFilterControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final kind = ref.watch(trackKindFilterProvider);
    return SegmentedButton<TrackKindFilter>(
      key: const ValueKey('tracks-kind-filter'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: TrackKindFilter.all, label: Text(l10n.tracks_kind_all)),
        ButtonSegment(value: TrackKindFilter.gps, label: Text(l10n.tracks_kind_gps)),
        ButtonSegment(
          value: TrackKindFilter.underwater,
          label: Text(l10n.tracks_kind_underwater),
        ),
      ],
      selected: {kind},
      onSelectionChanged: (selection) =>
          ref.read(trackKindFilterProvider.notifier).state = selection.single,
    );
  }
}
```

`lib/features/tracks/presentation/widgets/tracks_summary_strip.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/gps_log/presentation/widgets/track_row_labels.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_stat_tile.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Tracks, recorded time and dives covered for what the filters show.
///
/// Placeholders rather than zeros while the figures load, so a cold open
/// never flashes "0 tracks" over a full library.
class TracksSummaryStrip extends ConsumerWidget {
  const TracksSummaryStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(tracksSummaryProvider).value;
    final tiles = <(String, String)>[
      (l10n.gpsLogger_summary_tracks, summary?.trackCount.toString() ?? '--'),
      (
        l10n.gpsLogger_summary_recordedTime,
        summary == null ? '--' : formatCompactDuration(summary.recordedTime),
      ),
      (l10n.gpsLogger_summary_divesCovered, summary?.divesCovered.toString() ?? '--'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            for (final (label, value) in tiles)
              Expanded(child: TrackStatTile(label: label, value: value)),
          ],
        ),
      ),
    );
  }
}
```

`lib/features/tracks/presentation/widgets/tracks_empty_state.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the list shows with no rows: why the area exists, or, when filters
/// are active, that the filters hid everything and a way to clear them.
class TracksEmptyState extends ConsumerWidget {
  const TracksEmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final filtered =
        ref.watch(trackKindFilterProvider) != TrackKindFilter.all ||
        ref.watch(trackDateFilterProvider) != null;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtered ? Icons.filter_alt_off_outlined : Icons.route_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            filtered ? l10n.tracks_empty_filtered : l10n.tracks_empty_title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (filtered)
            TextButton(
              key: const ValueKey('tracks-clear-filters'),
              onPressed: () {
                ref.read(trackKindFilterProvider.notifier).state = TrackKindFilter.all;
                ref.read(trackDateFilterProvider.notifier).state = null;
              },
              child: Text(l10n.tracks_empty_clearFilters),
            )
          else
            Text(l10n.tracks_empty_body, style: muted, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
```

`lib/features/tracks/presentation/widgets/tracks_list_header.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/gps_log/presentation/widgets/gps_record_card.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_date_filter_action.dart';
import 'package:submersion/features/tracks/domain/tracks_query.dart';
import 'package:submersion/features/tracks/presentation/widgets/track_kind_filter_control.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_empty_state.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_summary_strip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Everything above the rows. Scrolls with them, so it never steals height
/// from a narrow pane.
class TracksListHeader extends StatelessWidget {
  const TracksListHeader({
    super.key,
    required this.showControls,
    required this.truncated,
    required this.isEmpty,
    this.onMatch,
  });

  /// The landing page shows the record card, summary, filters and Match;
  /// the map page shows rows and the cap notice only.
  final bool showControls;
  final bool truncated;
  final bool isEmpty;
  final VoidCallback? onMatch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final match = onMatch;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showControls) ...[
            if (canRecordGpsTracks) ...[
              const GpsRecordCard(),
              const SizedBox(height: 16),
            ],
            const TracksSummaryStrip(),
            const SizedBox(height: 12),
            const TrackKindFilterControl(),
            const SizedBox(height: 8),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: GpsTrackDateFilterAction(),
            ),
            if (match != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('tracks-match'),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(l10n.tracks_match_button),
                onPressed: match,
              ),
            ],
          ],
          if (truncated) ...[
            const SizedBox(height: 12),
            Text(
              l10n.gpsTrack_map_truncated(kTracksOverviewLimit),
              key: const ValueKey('tracks-truncated-notice'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (isEmpty) const TracksEmptyState(),
        ],
      ),
    );
  }
}
```

`lib/features/tracks/presentation/widgets/tracks_list_pane.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_list_tile.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_list_row.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';
import 'package:submersion/features/tracks/presentation/widgets/track_kind_badge.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_list_header.dart';

/// The merged list: header first, then one row per track, each the row its
/// own feature already draws, badged with its kind.
///
/// A builder list, never a plain one: GPS rows carry live map thumbnails,
/// and a non-builder list would build one per track on first paint.
class TracksListPane extends ConsumerWidget {
  const TracksListPane({
    super.key,
    required this.selectedKey,
    required this.onTap,
    this.onMatch,
    this.onDelete,
    this.showControls = true,
  });

  final String? selectedKey;
  final ValueChanged<TrackListItem> onTap;
  final VoidCallback? onMatch;
  final ValueChanged<TrackListItem>? onDelete;
  final bool showControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(tracksListProvider);
    final items = itemsAsync.value ?? const <TrackListItem>[];
    final truncated = ref.watch(tracksOverviewTruncatedProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final delete = onDelete;

    return ListView.builder(
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return TracksListHeader(
            showControls: showControls,
            truncated: truncated,
            // Only once loaded: a cold open must not flash the empty state.
            isEmpty: itemsAsync.hasValue && items.isEmpty,
            onMatch: onMatch,
          );
        }
        final item = items[index - 1];
        final selected = item.selectionKey == selectedKey;
        // Keyed by selection key: a recycled unkeyed GPS row keeps the
        // previous track's thumbnail camera.
        return switch (item) {
          GpsTrackItem(:final track) => GpsTrackListTile(
            key: ValueKey(item.selectionKey),
            track: track,
            selected: selected,
            onTap: () => onTap(item),
            onDelete: delete == null ? null : () => delete(item),
            kindBadge: TrackKindBadge(TrackKind.gps),
          ),
          UnderwaterTrackItem(:final track) => NavTrackListRow(
            key: ValueKey(item.selectionKey),
            route: track,
            units: units,
            selected: selected,
            onTap: () => onTap(item),
            onDelete: delete == null ? null : () => delete(item),
            kindBadge: TrackKindBadge(TrackKind.underwater),
          ),
        };
      },
    );
  }
}
```

- [ ] **Step 4: Implement the page**

`lib/features/tracks/presentation/pages/tracks_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/tracks/application/tracks_match_controller.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';
import 'package:submersion/features/tracks/presentation/track_item_location.dart';
import 'package:submersion/features/tracks/presentation/tracks_import.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_list_pane.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_map_pane.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_match_snackbar.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_overview_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// The Tracks area (spec 2026-10-02-tracks-navigation-consolidation-design):
/// GPS surface tracks and underwater tracks in one list and one map.
///
/// Below the master-detail breakpoint it is one column and a row opens its
/// track. At desktop width the list sits beside the overview map, a row
/// selects its track, and the map's info card opens it.
class TracksPage extends ConsumerStatefulWidget {
  const TracksPage({super.key, this.initialKind});

  /// The kind a link asked for (`/tracks?kind=...`); null leaves the
  /// current filter alone.
  final TrackKindFilter? initialKind;

  @override
  ConsumerState<TracksPage> createState() => _TracksPageState();
}

class _TracksPageState extends ConsumerState<TracksPage> {
  final _log = LoggerService.forClass(TracksPage);
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Riverpod 3 forbids provider mutation inside lifecycle callbacks; defer
    // the filter seed and the orphan recovery to a microtask.
    Future.microtask(() async {
      if (!mounted) return;
      _seedKind(widget.initialKind);
      await _recoverOrphanedTracks();
    });
  }

  @override
  void didUpdateWidget(TracksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final kind = widget.initialKind;
    if (kind != oldWidget.initialKind) {
      Future.microtask(() {
        if (mounted) _seedKind(kind);
      });
    }
  }

  void _seedKind(TrackKindFilter? kind) {
    if (kind == null) return;
    ref.read(trackKindFilterProvider.notifier).state = kind;
  }

  /// Surfaces tracks a crash left open.
  Future<void> _recoverOrphanedTracks() async {
    if (ref.read(gpsTrackRecorderProvider).isRecording) return;
    try {
      final recovered = await ref
          .read(gpsTrackRepositoryProvider)
          .recoverOrphanedTracks();
      if (recovered.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gpsLogger_interruptedNotice)),
        );
      }
    } catch (e, stackTrace) {
      // Recovery is best-effort; the page must render regardless.
      _log.error(
        'Orphan track recovery failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _matchNow() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final outcome = await ref.read(tracksMatchControllerProvider).matchAll();
    if (!mounted) return;
    showTracksMatchOutcome(
      messenger: messenger,
      l10n: l10n,
      router: router,
      outcome: outcome,
    );
  }

  Future<void> _delete(TrackListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteTrackDialog(item: item),
    );
    if (confirmed != true || !mounted) return;
    switch (item) {
      case GpsTrackItem():
        await ref.read(deleteTrackProvider)(item.id);
      case UnderwaterTrackItem():
        await ref.read(navTrackRepositoryProvider).delete(item.id);
    }
    if (!mounted) return;
    // A deleted track must not stay picked on the map.
    final section = mapListSelectionProvider(kTracksSectionKey);
    if (ref.read(section).selectedId == item.selectionKey) {
      ref.read(section.notifier).deselect();
    }
  }

  void _open(TrackListItem item) => context.push(trackLocationOf(item));

  void _select(TrackListItem item) => ref
      .read(mapListSelectionProvider(kTracksSectionKey).notifier)
      .select(item.selectionKey);

  Widget _title() =>
      FeatureAppBarTitle(featureId: 'tracks', title: context.l10n.nav_tracks);

  Widget _importAction() => IconButton(
    key: const ValueKey('tracks-import'),
    icon: const Icon(Icons.file_open_outlined),
    tooltip: context.l10n.gpsTrack_import_action,
    onPressed: () => importTrackFile(context, ref),
  );

  @override
  Widget build(BuildContext context) {
    return ResponsiveBreakpoints.isMasterDetail(context)
        ? _buildSplit(context)
        : _buildColumn(context);
  }

  Widget _buildSplit(BuildContext context) {
    final selection = ref.watch(mapListSelectionProvider(kTracksSectionKey));
    return MapListScaffold(
      sectionKey: kTracksSectionKey,
      title: context.l10n.nav_tracks,
      titleWidget: _title(),
      actions: [_importAction()],
      listPane: TracksListPane(
        selectedKey: selection.selectedId,
        onTap: _select,
        onMatch: _matchNow,
        onDelete: _delete,
      ),
      mapPane: TracksMapPane(controller: _mapController),
      infoCard: tracksInfoCard(ref: ref, onOpen: _open),
    );
  }

  Widget _buildColumn(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: _title(),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: l10n.gpsTrack_map_showMap,
            onPressed: () => context.push(kTracksMapLocation),
          ),
          _importAction(),
        ],
      ),
      body: TracksListPane(
        selectedKey: null,
        onTap: _open,
        onMatch: _matchNow,
        onDelete: _delete,
      ),
    );
  }
}

/// Confirms a delete in the wording of the track's own feature.
class _DeleteTrackDialog extends StatelessWidget {
  const _DeleteTrackDialog({required this.item});

  final TrackListItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, message) = switch (item) {
      GpsTrackItem() => (
        l10n.gpsLogger_deleteTrackTitle,
        l10n.gpsLogger_deleteTrackMessage,
      ),
      UnderwaterTrackItem(:final track) => (
        l10n.navTrack_detail_deleteTitle,
        l10n.navTrack_list_deleteMessage(
          track.name ?? track.sourceRef ?? track.id,
        ),
      ),
    };
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.common_action_delete),
        ),
      ],
    );
  }
}
```

Add the `'tracks'` accent entries to `feature_accent_colors.dart` (both palettes, next to `'gps-log'`, same colour values) so `FeatureAppBarTitle(featureId: 'tracks')` resolves before Task 12 retires `'gps-log'`.

- [ ] **Step 5: Run the tests**

Run: `flutter analyze lib/features/tracks && flutter test test/features/tracks/ test/architecture/list_tile_trailing_width_test.dart`
Expected: no analyzer issues; all PASS.

- [ ] **Step 6: Commit**

```bash
dart format . && git add lib/features/tracks lib/core/theme/feature_accent_colors.dart test/features/tracks && git commit -m "feat(tracks): Tracks page listing GPS and underwater tracks together

Refs #2833"
```

---

### Task 10: The phone map page

**Files:**
- Create: `lib/features/tracks/presentation/pages/tracks_map_page.dart`
- Test: `test/features/tracks/presentation/pages/tracks_map_page_test.dart`

**Interfaces:**
- Consumes: `TracksListPane(showControls: false)`, `TracksMapPane`, `tracksInfoCard`, `kTracksSectionKey`, `kTracksLocation`, `GpsTrackDateFilterAction`.
- Produces: `TracksMapPage()`.

- [ ] **Step 1: Write the failing test**

`test/features/tracks/presentation/pages/tracks_map_page_test.dart` (ported from `gps_track_map_page_test.dart`, which Task 13 deletes):

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/tracks/presentation/pages/tracks_map_page.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_overview_map.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';

import '../../../../helpers/mock_providers.dart';

GpsTrackPoint _p(int t, double base) =>
    GpsTrackPoint(timestamp: t, latitude: base + t * 0.001, longitude: -87.0 + t * 0.001);

GpsTrack _track(String id, double base) => GpsTrack(
  id: id,
  startTime: 1700000000000,
  endTime: 1700003600000,
  pointCount: 3,
  points: [_p(0, base), _p(1, base), _p(2, base)],
);

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1400, 900),
  Future<List<GpsTrack>> Function()? tracks,
}) async {
  final base = await getBaseOverrides();
  final data = [_track('t1', 20.0), _track('t2', 25.0)];
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        gpsTracksProvider.overrideWith((ref) => tracks?.call() ?? Future.value(data)),
        allNavTracksProvider.overrideWith((ref) async => const []),
        for (final t in data)
          gpsTrackGeometryProvider((t.id, TrackLod.thumbnail)).overrideWith((ref) async => t.points),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(data: MediaQueryData(size: size), child: const TracksMapPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('draws every track on one map with a list beside it', (tester) async {
    await _pump(tester);
    expect(find.text('Track Map'), findsOneWidget);
    final layer = tester.widget<PolylineLayer<String>>(find.byType(PolylineLayer<String>));
    expect(layer.polylines.length, 2);
    // The map page lists rows only: no record card, summary or match action.
    expect(find.text('Match tracks to dives'), findsNothing);
  });

  testWidgets('a phone-width surface shows only the map', (tester) async {
    await _pump(tester, size: const Size(390, 844));
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const ValueKey('gps:t1')), findsNothing);
  });

  testWidgets('selecting a row promotes its track', (tester) async {
    await _pump(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(TracksMapPage)));
    container.read(mapListSelectionProvider(kTracksSectionKey).notifier).select('gps:t1');
    await tester.pumpAndSettle();
    final layer = tester.widget<PolylineLayer<String>>(find.byType(PolylineLayer<String>));
    expect(layer.polylines.last.hitValue, 'gps:t1');
  });

  testWidgets('shows a spinner while loading, not the empty state', (tester) async {
    final pending = Completer<List<GpsTrack>>();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          gpsTracksProvider.overrideWith((ref) => pending.future),
          allNavTracksProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(data: MediaQueryData(size: Size(1400, 900)), child: TracksMapPage()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No recorded tracks to show.'), findsNothing);
    pending.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('a failed query says so instead of claiming there are none', (tester) async {
    await _pump(tester, tracks: () => Future.error(StateError('boom')));
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.text('No recorded tracks to show.'), findsNothing);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/tracks/presentation/pages/tracks_map_page_test.dart`
Expected: compile error, `tracks_map_page.dart` does not exist.

- [ ] **Step 3: Implement**

`lib/features/tracks/presentation/pages/tracks_map_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_date_filter_action.dart';
import 'package:submersion/features/tracks/presentation/track_item_location.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_list_pane.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_map_pane.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_overview_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';

/// Every mappable track on one map. At desktop width the Tracks page hosts
/// this same map itself; this page stays for phones, where the landing page
/// is one column, and for deep links.
class TracksMapPage extends ConsumerStatefulWidget {
  const TracksMapPage({super.key});

  @override
  ConsumerState<TracksMapPage> createState() => _TracksMapPageState();
}

class _TracksMapPageState extends ConsumerState<TracksMapPage> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final section = mapListSelectionProvider(kTracksSectionKey);
    final selection = ref.watch(section);
    return MapListScaffold(
      sectionKey: kTracksSectionKey,
      title: context.l10n.gpsTrack_map_title,
      onBackPressed: () => context.go(kTracksLocation),
      actions: const [GpsTrackDateFilterAction()],
      listPane: TracksListPane(
        selectedKey: selection.selectedId,
        showControls: false,
        onTap: (item) => ref.read(section.notifier).select(item.selectionKey),
      ),
      mapPane: TracksMapPane(controller: _mapController),
      infoCard: tracksInfoCard(
        ref: ref,
        onOpen: (item) => context.push(trackLocationOf(item)),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/tracks/presentation/pages/tracks_map_page_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format . && git add lib/features/tracks test/features/tracks && git commit -m "feat(tracks): full-screen tracks map for phones

Refs #2833"
```

---

### Task 11: Routes, redirects and call sites

**Files:**
- Modify: `lib/core/router/app_router.dart` (lines 161 to 167 imports; 362 to 367 `gps-logger` redirect; 1019 to 1082 GPS and nav-route blocks)
- Modify: `lib/features/gps_log/presentation/widgets/gps_recording_strip.dart:29`
- Modify: `lib/features/dashboard/presentation/widgets/quick_actions_card.dart:74`
- Modify: `lib/features/dive_log/presentation/widgets/surface_gps_section.dart:273`
- Modify: `lib/features/nav_track/presentation/widgets/nav_track_section.dart:212,214,237`
- Modify: `lib/features/nav_track/presentation/pages/nav_track_detail_page.dart:242,248`
- Modify: `lib/features/nav_track/presentation/pages/nav_track_align_page.dart:232`
- Modify: `lib/features/nav_track/presentation/pages/nav_track_import_review_page.dart:351`
- Test: `test/core/router/app_router_test.dart` (replace the `gps-log relocation` group)
- Test updates: `test/features/gps_log/gps_recording_strip_test.dart`, `test/features/dashboard/presentation/quick_actions_card_test.dart`, `test/features/dashboard/presentation/widgets/dashboard_cards_test.dart`, `test/features/nav_track/presentation/pages/nav_track_align_page_test.dart`, `test/features/nav_track/presentation/pages/nav_track_detail_page_test.dart`, `test/features/nav_track/presentation/pages/nav_track_import_review_page_test.dart`, `test/features/nav_track/presentation/widgets/nav_track_section_test.dart`

**Interfaces:**
- Consumes: `track_locations.dart` (Task 2); `TracksPage`, `TracksMapPage` (Tasks 9, 10); `TrackKindFilter.fromQuery`.
- Produces: route names `tracks`, `tracksMap`, `gpsTrackDetail`, `underwaterTrackDetail`, `underwaterTrackAlign`, `underwaterTrackSeascape`; unnamed redirect routes for `/gps-log`, `/gps-log/map`, `/gps-log/:id`, `/nav-routes`, `/nav-routes/:id`, `/nav-routes/:id/align`, `/nav-routes/:id/3d`.

- [ ] **Step 1: Write the failing router tests**

In `test/core/router/app_router_test.dart`, add beside the other helpers:

```dart
/// Finds a [GoRoute] by its own path segment in a route tree recursively.
GoRoute? _findRouteByPath(List<RouteBase> routes, String path) {
  for (final route in routes) {
    if (route is GoRoute) {
      if (route.path == path) return route;
      final found = _findRouteByPath(route.routes, path);
      if (found != null) return found;
    }
    if (route is ShellRoute) {
      final found = _findRouteByPath(route.routes, path);
      if (found != null) return found;
    }
  }
  return null;
}
```

Add `import 'package:submersion/core/router/track_locations.dart';`. Replace the whole `group('gps-log relocation', ...)` with:

```dart
  group('tracks area', () {
    test('every tracks page is a top-level sibling of /tracks', () {
      // go_router builds one page per matched segment and /tracks has its
      // own pageBuilder, so a nested detail would stack the landing page
      // under it: two Back presses from a dive's track link.
      final routes = router.configuration.routes;
      final tracks = _findRouteByName(routes, 'tracks');
      expect(tracks?.path, kTracksLocation);
      expect(tracks!.routes, isEmpty);
      for (final (name, path) in const [
        ('tracksMap', '/tracks/map'),
        ('gpsTrackDetail', '/tracks/gps/:id'),
        ('underwaterTrackDetail', '/tracks/underwater/:id'),
        ('underwaterTrackAlign', '/tracks/underwater/:id/align'),
        ('underwaterTrackSeascape', '/tracks/underwater/:id/3d'),
      ]) {
        expect(_findRouteByName(routes, name)?.path, path, reason: name);
      }
    });

    test('the location helpers match the route table', () {
      final config = router.configuration;
      for (final (location, fullPath) in [
        (kTracksMapLocation, '/tracks/map'),
        (gpsTrackLocation('abc'), '/tracks/gps/:id'),
        (underwaterTrackLocation('abc'), '/tracks/underwater/:id'),
        (underwaterTrackAlignLocation('abc'), '/tracks/underwater/:id/align'),
        (underwaterTrackSeascapeLocation('abc'), '/tracks/underwater/:id/3d'),
      ]) {
        expect(config.findMatch(Uri.parse(location)).fullPath, fullPath, reason: location);
      }
    });

    test('static paths are declared before parameterised siblings', () {
      // ':id' matches any single segment, so a static sibling declared after
      // it would never match.
      final paths = _orderedRoutePaths(router.configuration.routes);
      expect(paths.indexOf('/tracks/map'), lessThan(paths.indexOf('/tracks/gps/:id')));
      expect(paths.indexOf('/gps-log/map'), isNot(-1));
      expect(paths.indexOf('/gps-log/map'), lessThan(paths.indexOf('/gps-log/:id')));
    });

    testWidgets('old GPS log and underwater route locations redirect into '
        '/tracks', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      Future<String?> redirect(
        String path,
        String location, [
        Map<String, String> params = const {},
      ]) async {
        final route = _findRouteByPath(router.configuration.routes, path);
        expect(route?.redirect, isNotNull, reason: path);
        return route!.redirect!(
          capturedContext,
          GoRouterState(
            router.configuration,
            uri: Uri.parse(location),
            matchedLocation: location,
            fullPath: path,
            pathParameters: params,
            pageKey: ValueKey(location),
          ),
        );
      }

      expect(await redirect('/gps-log', '/gps-log'), '/tracks');
      expect(await redirect('/gps-log/map', '/gps-log/map'), '/tracks/map');
      expect(await redirect('/gps-log/:id', '/gps-log/abc', {'id': 'abc'}), '/tracks/gps/abc');
      expect(await redirect('/nav-routes', '/nav-routes'), '/tracks?kind=underwater');
      expect(await redirect('/nav-routes/:id', '/nav-routes/r1', {'id': 'r1'}), '/tracks/underwater/r1');
      expect(
        await redirect('/nav-routes/:id/align', '/nav-routes/r1/align', {'id': 'r1'}),
        '/tracks/underwater/r1/align',
      );
      expect(
        await redirect('/nav-routes/:id/3d', '/nav-routes/r1/3d', {'id': 'r1'}),
        '/tracks/underwater/r1/3d',
      );
      expect(await redirect('gps-logger', '/planning/gps-logger'), '/tracks');
    });
  });
```

Keep the existing `old planning gps-logger path is a redirect` test, moved into this group unchanged.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/router/app_router_test.dart`
Expected: FAIL; `tracks` route not found, redirects missing.

- [ ] **Step 3: Rewrite the routes**

In `app_router.dart`:

1. Replace the imports of `gps_logger_page.dart`, `nav_track_list_page.dart` and `gps_track_map_page.dart` with imports of `core/router/track_locations.dart`, `features/tracks/domain/track_kind.dart`, `features/tracks/presentation/pages/tracks_page.dart` and `features/tracks/presentation/pages/tracks_map_page.dart`. Keep the detail, align and seascape page imports.
2. Change the `gps-logger` redirect to `redirect: (context, state) => kTracksLocation,` and its comment to `// The GPS logger moved into the Tracks area; keep old deep links working.`
3. Replace everything from `// GPS surface track logger` through the `navRouteSeascape` route with:

```dart
          // Tracks: GPS surface tracks and underwater tracks in one area
          // (spec 2026-10-02-tracks-navigation-consolidation-design.md).
          // Every page is a top-level SIBLING of /tracks, never a child:
          // go_router builds one page per matched segment, and /tracks has
          // its own pageBuilder, so nesting stacked the landing page under a
          // detail pushed from a dive and needed two Back presses. Static
          // paths are declared before parameterised ones so 'map' is not
          // swallowed by ':id'.
          GoRoute(
            path: kTracksLocation,
            name: 'tracks',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: TracksPage(
                initialKind: TrackKindFilter.fromQuery(
                  state.uri.queryParameters['kind'],
                ),
              ),
            ),
          ),
          GoRoute(
            path: kTracksMapLocation,
            name: 'tracksMap',
            builder: (context, state) => const TracksMapPage(),
          ),
          GoRoute(
            path: '$kTracksLocation/gps/:id',
            name: 'gpsTrackDetail',
            builder: (context, state) =>
                GpsTrackDetailPage(trackId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '$kTracksLocation/underwater/:id',
            name: 'underwaterTrackDetail',
            builder: (context, state) =>
                NavTrackDetailPage(trackId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '$kTracksLocation/underwater/:id/align',
            name: 'underwaterTrackAlign',
            builder: (context, state) =>
                NavTrackAlignPage(routeId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '$kTracksLocation/underwater/:id/3d',
            name: 'underwaterTrackSeascape',
            builder: (context, state) =>
                NavTrackSeascapePage(trackId: state.pathParameters['id']!),
          ),

          // Locations from before the Tracks area, kept so stale links (a
          // bookmark, an older synced build's deep link) still land.
          GoRoute(
            path: '/gps-log',
            redirect: (context, state) => kTracksLocation,
          ),
          GoRoute(
            path: '/gps-log/map',
            redirect: (context, state) => kTracksMapLocation,
          ),
          GoRoute(
            path: '/gps-log/:id',
            redirect: (context, state) =>
                gpsTrackLocation(state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/nav-routes',
            redirect: (context, state) => kUnderwaterTracksLocation,
          ),
          GoRoute(
            path: '/nav-routes/:id',
            redirect: (context, state) =>
                underwaterTrackLocation(state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/nav-routes/:id/align',
            redirect: (context, state) =>
                underwaterTrackAlignLocation(state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/nav-routes/:id/3d',
            redirect: (context, state) =>
                underwaterTrackSeascapeLocation(state.pathParameters['id']!),
          ),
```

- [ ] **Step 4: Move every caller to the helpers**

Each file gains `import 'package:submersion/core/router/track_locations.dart';`:

| File | Old | New |
| --- | --- | --- |
| `gps_recording_strip.dart` | `context.go('/gps-log')` | `context.go(kTracksLocation)` |
| `quick_actions_card.dart` | `context.go('/gps-log')` | `context.go(kTracksLocation)` |
| `surface_gps_section.dart` | `context.push('/gps-log/${track.id}')` | `context.push(gpsTrackLocation(track.id))` |
| `nav_track_section.dart` (open, both) | `context.push('/nav-routes/${route.id}')` | `context.push(underwaterTrackLocation(route.id))` |
| `nav_track_section.dart` (3d) | `context.push('/nav-routes/${route.id}/3d')` | `context.push(underwaterTrackSeascapeLocation(route.id))` |
| `nav_track_detail_page.dart` (align) | `context.push('/nav-routes/${route.id}/align')` | `context.push(underwaterTrackAlignLocation(route.id))` |
| `nav_track_detail_page.dart` (3d) | `context.push('/nav-routes/${route.id}/3d')` | `context.push(underwaterTrackSeascapeLocation(route.id))` |
| `nav_track_align_page.dart` | `context.push('/nav-routes/${route.id}/3d')` | `context.push(underwaterTrackSeascapeLocation(route.id))` |
| `nav_track_import_review_page.dart` | `router.push('/nav-routes/$id')` | `router.push(underwaterTrackLocation(id))` |

Leave `quick_actions_card.dart`'s `/nav-routes` button for Task 12; it still works through the redirect.

- [ ] **Step 5: Update the tests that host their own routers**

In each file below, rewrite the stub routes and expectations to the new paths, nothing else:

- `gps_recording_strip_test.dart`: route `path: '/tracks'` with body `Text('TRACKS-PAGE')`; test name `tap navigates to the Tracks page`; expect `TRACKS-PAGE`.
- `quick_actions_card_test.dart`: route `path: '/tracks'` with body `Text('TRACKS-PAGE')`; test name `GPS Logger quick action navigates to /tracks`; expect `TRACKS-PAGE`.
- `dashboard_cards_test.dart`: in the stub path list `'/gps-log'` becomes `'/tracks'`; the case `('GPS Logger', '/gps-log')` becomes `('GPS Logger', '/tracks')`.
- `nav_track_align_page_test.dart`, `nav_track_detail_page_test.dart`, `nav_track_section_test.dart`: every `'/nav-routes/:id'`, `'/nav-routes/:id/align'`, `'/nav-routes/:id/3d'` route path becomes `'/tracks/underwater/:id'`, `'/tracks/underwater/:id/align'`, `'/tracks/underwater/:id/3d'`; every `initialLocation: '/nav-routes/${route.id}'` and `push('/nav-routes/...')` follows the same mapping.
- `nav_track_import_review_page_test.dart`: the sibling route `path: '/nav-routes/:id'` becomes `'/tracks/underwater/:id'`; `expect(router.state.uri.path, '/nav-routes/new-route-id')` becomes `'/tracks/underwater/new-route-id'`; update the doc comment at line 155 to name `/tracks/underwater/:id`.

Find any remaining old path with:

```bash
grep -rn "nav-routes\|gps-log" lib test --include='*.dart' | grep -v "app_router.dart\|nav_destinations.dart\|feature_accent_colors.dart\|nav_id_aliases.dart\|gps_logger_page\|gps_track_map_page\|nav_track_list_page\|test/shared/widgets\|test/features/settings\|test/core/router"
```

Expected: no output.

- [ ] **Step 6: Run the tests**

Run: `flutter analyze && flutter test test/core/router test/features/gps_log/gps_recording_strip_test.dart test/features/dashboard test/features/nav_track test/features/dive_log/presentation/widgets`
Expected: no analyzer issues; all PASS.

- [ ] **Step 7: Commit**

```bash
dart format . && git add lib test && git commit -m "feat(tracks): route every GPS and underwater track page under /tracks

The old /gps-log and /nav-routes locations redirect, keeping their ids.

Refs #2833"
```

---

### Task 12: Tracks nav destination, alias and quick actions

**Files:**
- Modify: `lib/shared/widgets/nav/nav_destinations.dart` (the `gps-log` entry; the species comment; the `subtitle` doc)
- Modify: `lib/shared/widgets/nav/nav_id_aliases.dart`
- Modify: `lib/core/theme/feature_accent_colors.dart` (remove both `'gps-log'` entries)
- Modify: `lib/features/dashboard/presentation/widgets/quick_actions_card.dart` (remove the underwater button)
- Test updates: `test/shared/widgets/nav/nav_destinations_test.dart`, `nav_id_alias_test.dart`, `nav_normalize_test.dart`, `nav_order_provider_test.dart`, `rail_destination_order_test.dart`, `test/shared/widgets/main_scaffold_test.dart`, `test/features/settings/presentation/pages/nav_customization_page_test.dart`, `test/features/settings/presentation/pages/settings_page_test.dart`, `test/features/settings/presentation/widgets/nav_customization_tile_test.dart`, `test/features/dashboard/presentation/quick_actions_card_test.dart`

**Interfaces:**
- Consumes: `kTracksLocation`; l10n `nav_tracks`, `nav_tracksSubtitle`.
- Produces: nav id `tracks`; `kRenamedNavIds['gps-log'] == 'tracks'`.

- [ ] **Step 1: Write the failing tests**

In `nav_id_alias_test.dart`, group `renamed nav ids against the real destinations`, add:

```dart
    test('a stored GPS Log id keeps its slot as Tracks', () {
      expect(
        normalizeNavOrder(
          stored: const ['settings', 'gps-log', 'dives'],
          movableIds: movableNavIds,
        ).take(3).toList(),
        ['settings', 'tracks', 'dives'],
      );
    });

    test('an order holding both gps-log and tracks keeps one Tracks slot', () {
      for (final stored in const [
        ['tracks', 'gps-log', 'dives'],
        ['gps-log', 'dives', 'tracks'],
      ]) {
        final order = normalizeNavOrder(stored: stored, movableIds: movableNavIds);
        expect(order.where((id) => id == 'tracks').length, 1, reason: '$stored');
        expect(order, isNot(contains('gps-log')));
        expect(order.first, 'tracks', reason: '$stored');
      }
    });

    test('a save writes gps-log right after tracks for older builds', () {
      expect(
        withLegacyNavIds(const ['tracks', 'insights']),
        ['tracks', 'gps-log', 'insights', 'statistics'],
      );
    });
```

and change the existing `a rail order saved before the rename keeps Insights in its slot` expectation from `['insights', 'gps-log']` to `['insights', 'tracks']`.

In `nav_destinations_test.dart` replace `'gps-log'` with `'tracks'` in both expected id lists, and add to the first group:

```dart
    test('Tracks takes GPS Log\'s place and route', () {
      final tracks = kNavDestinations.firstWhere((d) => d.id == 'tracks');
      expect(tracks.route, '/tracks');
      expect(kNavDestinations.map((d) => d.id), isNot(contains('gps-log')));
    });
```

In `quick_actions_card_test.dart` add:

```dart
  testWidgets('there is no Underwater Routes quick action', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.route), findsNothing);
  });
```

In `main_scaffold_test.dart`: rename the stub route to `path: '/tracks'` with body `Text('Tracks Page')`; add a stub `GoRoute(path: '/tracks/underwater/:id/3d', builder: (context, state) => const Text('Seascape Page'))` next to it; rename the test `desktop rail navigates to the Tracks destination`, expect `Tracks Page`, and change the comment to `// Tracks is rail index 14 (after Transfer, before Settings).`; in the label list replace `'GPS Log'` with `'Tracks'`; in the sync-race test replace `'gps-log'` with `'tracks'`. Add:

```dart
    testWidgets('the Tracks destination stays selected on a nested tracks '
        'page', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        await _buildTestApp(initialLocation: '/tracks/underwater/r1/3d'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Seascape Page'), findsOneWidget);
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
        14,
      );
    });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/shared/widgets test/features/dashboard/presentation/quick_actions_card_test.dart`
Expected: FAIL; ids are still `gps-log`, the alias is missing, the underwater action is present.

- [ ] **Step 3: Implement**

`nav_destinations.dart`: replace the `gps-log` entry with

```dart
  NavDestination(
    id: 'tracks',
    route: kTracksLocation,
    icon: Icons.route_outlined,
    selectedIcon: Icons.route,
    label: (l10n) => l10n.nav_tracks,
    subtitle: (l10n) => l10n.nav_tracksSubtitle,
  ),
```

add `import 'package:submersion/core/router/track_locations.dart';`, change the `subtitle` field doc to `/// Optional localized subtitle, used for Courses, Planning, and Tracks.`, and end the species comment at `...borrows MDI's and reuses it for the selected state.` (the `gps-log` comparison no longer holds).

`nav_id_aliases.dart`:

```dart
const Map<String, String> kRenamedNavIds = {
  // The Statistics section became Insights.
  'statistics': 'insights',
  // GPS Log became Tracks, which also holds underwater tracks (#2833).
  'gps-log': 'tracks',
};
```

`feature_accent_colors.dart`: delete both `'gps-log'` lines (the `'tracks'` lines from Task 9 stay).

`quick_actions_card.dart`: delete the `SizedBox(height: 8)` and `SizedBox(... OutlinedButton.icon(... '/nav-routes' ...))` pair for the underwater action.

- [ ] **Step 4: Update the remaining tests to the new id**

- `nav_normalize_test.dart`: in the input list `['gps-log', 'settings', 'species', 'dives']` keep `'gps-log'` (it now also exercises the alias); no change needed if the test still passes.
- `nav_order_provider_test.dart`: `navRailIds = ['gps-log', 'planning']` becomes `['tracks', 'planning']` with expectation `['tracks', 'planning']`; `['insights', 'gps-log']` becomes `['insights', 'tracks']` with expectation `['dashboard', 'insights', 'tracks']`.
- `rail_destination_order_test.dart`: `('gps-log', '/gps-log')` becomes `('tracks', '/tracks')`.
- `nav_customization_page_test.dart`: `navRailIds = ['gps-log', 'planning']` becomes `['tracks', 'planning']` and `_firstRowId(tester), 'gps-log'` becomes `'tracks'`; tooltip `'Move GPS Log up'` becomes `'Move Tracks up'`; `order.indexOf('gps-log')` becomes `order.indexOf('tracks')` and the comment names `'tracks'`.
- `settings_page_test.dart`: keep `navRailIds = ['insights', 'gps-log', 'planning']` (it exercises the alias end to end) and change the expected text to `'Insights · Tracks · Planning'`.
- `nav_customization_tile_test.dart`: both `['gps-log', 'planning', 'transfer']` become `['tracks', 'planning', 'transfer']`; expected `'Tracks · Planning · Transfer'`.

- [ ] **Step 5: Run the tests**

Run: `flutter analyze && flutter test test/shared test/features/settings test/features/dashboard test/core/theme`
Expected: no analyzer issues; all PASS.

- [ ] **Step 6: Commit**

```bash
dart format . && git add lib test && git commit -m "feat(tracks): Tracks replaces GPS Log in the navigation

A stored or synced gps-log id keeps its slot as tracks, and saves keep
writing gps-log after it for older builds. The Underwater Routes quick
action is gone; the GPS quick action opens Tracks.

Refs #2833"
```

---

### Task 13: Remove the replaced pages, providers and strings

**Files:**
- Delete (lib): `gps_log/presentation/pages/gps_logger_page.dart`, `gps_log/presentation/pages/gps_track_map_page.dart`, `gps_log/presentation/widgets/gps_log_list_pane.dart`, `gps_log/presentation/widgets/gps_log_empty_state.dart`, `gps_log/presentation/widgets/gps_log_summary_strip.dart`, `gps_log/presentation/widgets/gps_track_overview_map.dart`, `nav_track/presentation/pages/nav_track_list_page.dart`
- Modify: `gps_log/presentation/providers/gps_track_map_providers.dart` (delete `kOverviewTrackLimit`, `filteredTracksProvider`, `overviewTracksProvider`, `overviewTracksTruncatedProvider`); `gps_log/presentation/providers/gps_log_providers.dart` (delete `GpsLogSummary`, `gpsLogSummaryProvider`)
- Delete (test): `test/features/gps_log/gps_logger_page_test.dart`, `gps_track_map_page_test.dart`, `gps_track_date_filter_test.dart`, `gps_log_summary_provider_test.dart`, `gps_track_list_scroll_perf_test.dart`, `test/features/nav_track/presentation/pages/nav_track_list_page_test.dart`
- Create: `test/features/tracks/presentation/pages/tracks_list_scroll_perf_test.dart`
- Modify: every ARB, regenerate l10n
- Modify: `test/features/tracks/presentation/pages/tracks_page_test.dart` (add the import case)

**Interfaces:**
- Consumes: everything above. Produces nothing new.

- [ ] **Step 1: Confirm every deleted test case has a home**

| Deleted case | Now covered in |
| --- | --- |
| logger: record card states, start-logging group | `gps_record_card_test.dart` (Task 6) |
| logger: rows, open, match, delete, recovery, summary, empty, desktop split | `tracks_page_test.dart` (Task 9) |
| map page: draws, desktop/phone, selection, spinner, error | `tracks_map_page_test.dart` (Task 10), `tracks_overview_map_test.dart` (Task 8) |
| map page: date filter starts unbounded | `tracks_providers_test.dart` (Task 3, "clearing restores") |
| date filter and cap provider cases | `tracks_query_test.dart`, `tracks_providers_test.dart` (Task 3) |
| summary provider cases | `tracks_summary_test.dart` (Task 3); the matcher tolerance case stays covered by `gps_track_matcher_test.dart` |
| nav list: framing signature | `tracks_overview_map_test.dart` (Task 8) |
| nav list: row cases | `nav_track_list_row_test.dart` (Task 7) |
| nav list: delete, match, wide map, no-map message, import | `tracks_page_test.dart` (Task 9 plus Step 2 below) |
| scroll perf | `tracks_list_scroll_perf_test.dart` (Step 3 below) |

- [ ] **Step 2: Port the import case into the page test**

Append to `tracks_page_test.dart`, reusing the `_PreparedNavImport` class copied verbatim from `test/features/tracks/presentation/tracks_import_test.dart` (paste it above `main`, with the imports it needs):

```dart
  testWidgets('the Import action sends an ENC log to the underwater review', (tester) async {
    final original = FilePickerPlatform.instance;
    addTearDown(() => FilePickerPlatform.instance = original);
    FilePickerPlatform.instance = MockFilePickerPlatform()
      ..pickFilesResult = [
        FakePlatformFile.contentUri(
          Uri.parse('content://picked/005.DAT.csv'),
          name: '005.DAT.csv',
          bytes: File(p.join('test', 'fixtures', 'nav_tracks', 'seacraft_enc3_short.csv')).readAsBytesSync(),
        ),
      ];
    // app() takes extra overrides through a new optional parameter
    // `List<Override> extraOverrides = const []`, appended last.
    await tester.pumpWidget(
      await app(extraOverrides: [navTrackImportServiceProvider.overrideWithValue(_PreparedNavImport())]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tracks-import')));
    await tester.pumpAndSettle();

    expect(find.byType(NavTrackImportReviewPage), findsOneWidget);
  });
```

Add the `extraOverrides` parameter to `app()` and spread it at the end of its `overrides` list; add imports for `dart:io`, `mock_file_picker_platform.dart`, `nav_track_import_flow_providers.dart` and `nav_track_import_review_page.dart`.

- [ ] **Step 3: Port the scroll performance test**

Create `test/features/tracks/presentation/pages/tracks_list_scroll_perf_test.dart` by copying `test/features/gps_log/gps_track_list_scroll_perf_test.dart` and changing only: the `GpsLoggerPage` import becomes `package:submersion/features/tracks/presentation/pages/tracks_page.dart`; `home: GpsLoggerPage()` becomes `home: TracksPage()`; the override list gains `allNavTracksProvider.overrideWith((ref) async => const [])` and `divesProvider.overrideWith((ref) async => const [])` (with their imports); the relative helper import gains one more `../` level (`'../../../../helpers/mock_providers.dart'`).

Run: `flutter test test/features/tracks/presentation/pages/`
Expected: all PASS.

- [ ] **Step 4: Delete the replaced code and tests**

```bash
git rm lib/features/gps_log/presentation/pages/gps_logger_page.dart lib/features/gps_log/presentation/pages/gps_track_map_page.dart lib/features/gps_log/presentation/widgets/gps_log_list_pane.dart lib/features/gps_log/presentation/widgets/gps_log_empty_state.dart lib/features/gps_log/presentation/widgets/gps_log_summary_strip.dart lib/features/gps_log/presentation/widgets/gps_track_overview_map.dart lib/features/nav_track/presentation/pages/nav_track_list_page.dart test/features/gps_log/gps_logger_page_test.dart test/features/gps_log/gps_track_map_page_test.dart test/features/gps_log/gps_track_date_filter_test.dart test/features/gps_log/gps_log_summary_provider_test.dart test/features/gps_log/gps_track_list_scroll_perf_test.dart test/features/nav_track/presentation/pages/nav_track_list_page_test.dart
```

Then delete from `gps_track_map_providers.dart` the declarations of `kOverviewTrackLimit`, `filteredTracksProvider`, `overviewTracksProvider` and `overviewTracksTruncatedProvider` with their doc comments, and from `gps_log_providers.dart` the `GpsLogSummary` class and `gpsLogSummaryProvider` with their doc comments. Remove imports the analyzer then reports unused (`gps_track_matcher.dart` and `dive_providers.dart` in `gps_log_providers.dart` are likely).

Run: `flutter analyze`
Expected: no issues. Any remaining reference to a deleted symbol is a missed port: fix it by moving the caller to the `tracks` equivalent, not by restoring the symbol.

- [ ] **Step 5: Remove the orphaned strings**

First prove they are orphans:

```bash
for k in nav_gpsLog tools_gpsLogger_subtitle tools_gpsLogger_description dashboard_quickActions_navRoutes gpsLogger_matchButton gpsLogger_matchResult gpsLogger_matchResultNone gpsLogger_tracksHeader gpsLogger_noTracks navTrack_list_title navTrack_list_matchTooltip navTrack_list_matchSuccess navTrack_list_matchError navTrack_list_importTooltip navTrack_list_empty navTrack_list_noMapRoutes; do grep -rlw "$k" lib test --include='*.dart' | grep -v "lib/l10n/arb/" | sed "s|^|$k: |"; done
```

Expected: no output. Any line printed names a live user; keep that key and drop it from the list below.

Then remove them from all 11 ARBs:

```bash
PYTHONUTF8=1 python3.14 - <<'EOF'
import json, pathlib, re

REMOVE = {
  'nav_gpsLog', 'tools_gpsLogger_subtitle', 'tools_gpsLogger_description',
  'dashboard_quickActions_navRoutes', 'gpsLogger_matchButton',
  'gpsLogger_matchResult', 'gpsLogger_matchResultNone',
  'gpsLogger_tracksHeader', 'gpsLogger_noTracks', 'navTrack_list_title',
  'navTrack_list_matchTooltip', 'navTrack_list_matchSuccess',
  'navTrack_list_matchError', 'navTrack_list_importTooltip',
  'navTrack_list_empty', 'navTrack_list_noMapRoutes',
}
KEY_RE = re.compile(r'^  "(@?)([^"]+)":')
for path in sorted(pathlib.Path('lib/l10n/arb').glob('app_*.arb')):
    lines = path.read_text(encoding='utf-8').split('\n')
    out, i, removed = [], 0, 0
    while i < len(lines):
        m = KEY_RE.match(lines[i])
        if m and m.group(2) in REMOVE:
            removed += 1
            if m.group(1) == '@':
                # A metadata block: skip to the line that closes it.
                depth = lines[i].count('{') - lines[i].count('}')
                i += 1
                while depth > 0:
                    depth += lines[i].count('{') - lines[i].count('}')
                    i += 1
                continue
            i += 1
            continue
        out.append(lines[i])
        i += 1
    path.write_text('\n'.join(out), encoding='utf-8')
    json.loads(path.read_text(encoding='utf-8'))
    print(path.name, removed)
EOF
```

Expected: every file reports `16` except `app_en.arb`, which also counts the `@` blocks of keys that had metadata (for example `@gpsLogger_matchResult`), so its number is higher.

Run: `git diff --numstat -- lib/l10n/arb` then `flutter gen-l10n`
Expected: only deletions in the ARBs; gen-l10n exits 0.

- [ ] **Step 6: Run the affected suites**

Run: `flutter analyze && flutter test test/features/tracks test/features/gps_log test/features/nav_track test/features/dashboard test/shared test/core test/l10n`
Expected: no analyzer issues; all PASS.

- [ ] **Step 7: Commit**

```bash
dart format . && git add -A lib/features/gps_log lib/features/nav_track lib/l10n test/features && git status --short && git commit -m "refactor(tracks): remove the GPS log and routes pages Tracks replaced

Their tests moved with the behaviour into the tracks feature; strings
no longer used anywhere are removed from every locale.

Refs #2833"
```

Before committing, confirm `git status --short` lists only the paths this task touched (memory: stage explicit paths; `git add -A` here is scoped to those directories).

---

### Task 14: Verification, spec sync and screenshots

**Files:**
- Modify: `docs/design/specs/2026-10-02-tracks-navigation-consolidation-design.md`

- [ ] **Step 1: Check the spec still matches what was built**

Edit the spec so it matches the code: the `TrackListItem` interface (no `displayName` or `tzOffsetMinutes`; adds `recordedTime`); the kind filter, date filter and Match button sit in the list header on both widths, and the app bar holds Import (plus the map button on phones); the badge sits on the subtitle line; the cap constant is `kTracksOverviewLimit` in `tracks_query.dart`; the redirect is `/planning/gps-logger`, not `/tools/gps-logger`; orphaned strings are found by grep in Task 13, since there is no automated unused-key check.

- [ ] **Step 2: Whole-project checks**

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test test/architecture
```

Expected: no formatting changes, no analyzer issues, architecture tests PASS.

- [ ] **Step 3: One full test run**

Check the RAM-disk temp volume first (`df -h /Volumes/fltmp`), then run the suite once, with nothing else running:

```bash
bash scripts/run_all_tests.sh
```

Expected: all PASS. If a failure is in a file this branch never touched, run that file alone on `main` before concluding it is inherited.

- [ ] **Step 4: Em-dash and attribution scan of the branch**

```bash
git diff main...HEAD | grep -nP "\x{2014}" ; git log main..HEAD --format=%B | grep -niE "claude|anthropic|co-authored"
```

Expected: no output from either.

- [ ] **Step 5: Screenshots**

Run the app on macOS (and a phone simulator) and capture, light and dark: the nav rail and bottom bar before (from `main`) and after; the Tracks page at phone and desktop width with both kinds listed; the Quick Actions card before and after. Save them under the scratchpad, list each file and what it shows, and hand them to the user for the PR description (gh cannot upload images).

- [ ] **Step 6: Commit the spec sync and stop**

```bash
dart format . && git add docs/design/specs/2026-10-02-tracks-navigation-consolidation-design.md && git commit -m "docs(tracks): bring the Tracks spec in line with the implementation

Refs #2833"
```

Then ask the user before pushing or opening the PR. The PR body must say `Closes #2833, closes #2397`, follow the repo template, and list the screenshots.
