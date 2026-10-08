# Media Viewer Fullscreen Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in fullscreen mode to the media viewer that hides the app shell's navigation and every viewer overlay, plus a priority-based overflow menu for the viewer toolbar.

**Architecture:** `MainScaffold` owns a `ShellChromeController` (a `ChangeNotifier` of hide tokens) and exposes it to the page through a `ShellChromeScope` InheritedWidget; while any token is held it renders the page alone (go_router's GlobalKey on the shell navigator keeps its pages alive across the layout change). The viewer gains `_isFullscreen` state that hides its overlays and the Perdix face, requests a hidden shell, and reveals a corner exit button (plus video controls) on tap with a 3-second auto-hide. The toolbar moves into its own file and splits its actions into visible icons and an overflow menu by measured width.

**Tech Stack:** Flutter, go_router (`ShellRoute`), Riverpod 3, `photo_view`, `video_player`, flutter_test, ARB l10n (`flutter gen-l10n`).

**Spec:** `docs/design/specs/2026-10-05-media-viewer-fullscreen-design.md`

## Global Constraints

- Never use the em-dash character, nor en-dashes, `--` or spaced hyphens as prose punctuation, anywhere: code, comments, ARB values, commits.
- No mention of Claude, Claude Code or Anthropic in any commit, comment, file, PR text or trailer.
- Default viewer behaviour must stay exactly as today; fullscreen is opt-in via the new button and resets every time a viewer opens. No new setting, no schema change.
- Fullscreen hides: bottom `NavigationBar`, `NavigationRail` and its divider, `UpdateBanner`, `GpsRecordingStrip`, the wide layout's `SafeArea`, the viewer toolbar, previous/next arrows, mini dive profile, bottom metadata, video controls, the centre play indicator, and the Perdix face.
- Revealed fullscreen controls hide 3 seconds after the last tap; on a paused video they stay up.
- Back and Esc leave fullscreen; they close the viewer only outside fullscreen. Swipe-down still closes the viewer in either mode.
- Toolbar priority (first stays visible longest): Go to dive, Share, Info, Perdix, Species tag, Write dive data, Open in Lightroom, Re-upload. Visible icons keep toolbar order.
- New strings go in `app_en.arb` and all 10 locale ARBs (ar, de, es, fr, he, hu, it, nl, pt, zh); run `flutter gen-l10n` only after every ARB has its translation.
- Tests that replace process-wide state (`VideoPlayerPlatform.instance`, `tester.view`) restore it in `addTearDown`.
- New `lib/` files stay under 400 lines; run `test/architecture/` after adding them.
- Run `dart format .` before every commit.

## Review Focus

1. **Shell page state across the hide toggle:** hiding or restoring the chrome must not rebuild the shell navigator, or the viewer (and everything under it) is destroyed. go_router's GlobalKey on the shell navigator is what preserves it today; Task 3's "page keeps its state" test guards against that ever changing.
2. **Closing the viewer while fullscreen** (swipe-down): the shell chrome must come back. Pinned by Task 7's integration test.
3. **Resizing across the 800 px rail breakpoint while hidden** (phone rotation, desktop window drag): the chrome stays hidden and the page keeps its state. Pinned by Task 3's resize test.
4. **A viewer with no shell above it** (the dashboard ribbon pushes on the root navigator; tests pump it as `home`): fullscreen must work and not throw. Pinned by Task 5, whose harness has no scope.
5. **The gallery empties while fullscreen** (a sync deletes the last item): with nothing to tap there is no exit button, so the viewer must leave fullscreen by itself. Pinned by Task 5's "empty gallery" test.

---

### Task 0: Before screenshots

**Files:** none (scratchpad only)

- [ ] **Step 1: Capture before screenshots**

Launch the app with the `run` skill at phone width, open a dive's photo, and capture into the scratchpad:
`01-viewer-phone-before.png` (viewer, overlays showing, bottom nav visible), `02-viewer-overlays-hidden-phone-before.png` (after one tap: overlays gone, bottom nav still visible), and at desktop width `03-viewer-desktop-before.png` (rail visible beside the viewer).

---

### Task 1: Strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (after the `@media_viewer_goToDive` block, line ~10925)
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` (after each `media_viewer_goToDive` line)
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces: `context.l10n.media_viewer_enterFullscreen` ("Full screen"), `context.l10n.media_viewer_exitFullscreen` ("Exit full screen"), `context.l10n.media_viewer_moreOptions` ("More options").

- [ ] **Step 1: Insert the keys with a script**

Save as `$SCRATCH/insert_fullscreen_keys.py` (the session scratchpad) and run with `python3.14` from the worktree root. It inserts by anchor line (never a JSON round-trip, which would reformat the files) and proves every file still parses.

```python
import json
from pathlib import Path

ARB = Path("lib/l10n/arb")
EN_BLOCK = '''  "media_viewer_enterFullscreen": "Full screen",
  "@media_viewer_enterFullscreen": {
    "description": "Viewer toolbar action: hide all app and viewer chrome so only the photo or video shows"
  },
  "media_viewer_exitFullscreen": "Exit full screen",
  "@media_viewer_exitFullscreen": {
    "description": "Button revealed by a tap in fullscreen mode: return to the normal viewer"
  },
  "media_viewer_moreOptions": "More options",
  "@media_viewer_moreOptions": {
    "description": "Viewer toolbar overflow menu holding the actions that do not fit"
  },
'''
TRANSLATIONS = {
    "ar": ("ملء الشاشة", "الخروج من ملء الشاشة"),
    "de": ("Vollbild", "Vollbild beenden"),
    "es": ("Pantalla completa", "Salir de pantalla completa"),
    "fr": ("Plein écran", "Quitter le plein écran"),
    "he": ("מסך מלא", "יציאה ממסך מלא"),
    "hu": ("Teljes képernyő", "Kilépés a teljes képernyőből"),
    "it": ("Schermo intero", "Esci da schermo intero"),
    "nl": ("Volledig scherm", "Volledig scherm verlaten"),
    "pt": ("Tela cheia", "Sair da tela cheia"),
    "zh": ("全屏", "退出全屏"),
}


def line(key, value):
    return '  "%s": %s,\n' % (key, json.dumps(value, ensure_ascii=False))


en = ARB / "app_en.arb"
src = en.read_text(encoding="utf-8").splitlines(keepends=True)
meta = next(i for i, l in enumerate(src) if l.startswith('  "@media_viewer_goToDive"'))
close = next(i for i in range(meta, len(src)) if src[i] == "  },\n")
src[close + 1:close + 1] = [EN_BLOCK]
out = "".join(src)
json.loads(out)
en.write_text(out, encoding="utf-8")

for loc, (enter, exit_) in TRANSLATIONS.items():
    path = ARB / f"app_{loc}.arb"
    text = path.read_text(encoding="utf-8")
    more = json.loads(text)["diveCenters_tooltip_moreOptions"]
    lines = text.splitlines(keepends=True)
    anchor = next(i for i, l in enumerate(lines) if l.startswith('  "media_viewer_goToDive"'))
    lines[anchor + 1:anchor + 1] = [
        line("media_viewer_enterFullscreen", enter),
        line("media_viewer_exitFullscreen", exit_),
        line("media_viewer_moreOptions", more),
    ]
    out = "".join(lines)
    json.loads(out)
    path.write_text(out, encoding="utf-8")
    print("OK", loc, more)
```

- [ ] **Step 2: Check the diff is even across locales**

Run: `git diff --numstat lib/l10n/arb/`
Expected: `12 0` for `app_en.arb`, `3 0` for each of the ten locale ARBs. Any uneven row means a locale was skipped.

- [ ] **Step 3: Generate and verify a non-English getter**

Run: `flutter gen-l10n && grep -A1 "get media_viewer_exitFullscreen" lib/l10n/arb/app_localizations_de.dart`
Expected: the German body `'Vollbild beenden'`, not English.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb/ && git commit -m "i18n(media): add viewer fullscreen and overflow strings"
```

---

### Task 2: ShellChromeController and ShellChromeScope

**Files:**
- Create: `lib/shared/widgets/shell_chrome_scope.dart`
- Test: `test/shared/widgets/shell_chrome_scope_test.dart`

**Interfaces:**
- Produces:
  - `class ShellChromeController extends ChangeNotifier` with `bool get isHidden`, `void requestHidden(Object token)`, `void releaseHidden(Object token)`.
  - `class ShellChromeScope extends InheritedWidget` with `const ShellChromeScope({Key? key, required ShellChromeController controller, required Widget child})` and `static ShellChromeController? maybeOf(BuildContext context)`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/shell_chrome_scope.dart';

/// Requests a hidden shell for as long as it is mounted: from initState and
/// dispose, which both run while the tree is locked.
class _Holder extends StatefulWidget {
  const _Holder();

  @override
  State<_Holder> createState() => _HolderState();
}

class _HolderState extends State<_Holder> {
  ShellChromeController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = ShellChromeScope.maybeOf(context);
    _controller?.requestHidden(this);
  }

  @override
  void dispose() {
    _controller?.releaseHidden(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Rebuilds on every controller change and reports the state as text.
class _Host extends StatefulWidget {
  const _Host({required this.controller, required this.child});

  final ShellChromeController controller;
  final Widget child;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  void _changed() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShellChromeScope(
    controller: widget.controller,
    child: Column(
      children: [
        Text(widget.controller.isHidden ? 'hidden' : 'shown'),
        widget.child,
      ],
    ),
  );
}

void main() {
  late ShellChromeController controller;

  setUp(() => controller = ShellChromeController());
  tearDown(() => controller.dispose());

  Widget app(Widget child) => MaterialApp(
    home: Scaffold(
      body: _Host(controller: controller, child: child),
    ),
  );

  testWidgets('a request hides and its release restores', (tester) async {
    await tester.pumpWidget(app(const SizedBox()));
    expect(find.text('shown'), findsOneWidget);

    final token = Object();
    controller.requestHidden(token);
    await tester.pump();
    expect(find.text('hidden'), findsOneWidget);

    controller.releaseHidden(token);
    await tester.pump();
    expect(find.text('shown'), findsOneWidget);
  });

  testWidgets('two holders do not release each other', (tester) async {
    await tester.pumpWidget(app(const SizedBox()));
    final a = Object();
    final b = Object();
    controller
      ..requestHidden(a)
      ..requestHidden(b);
    await tester.pump();

    controller.releaseHidden(a);
    await tester.pump();
    expect(find.text('hidden'), findsOneWidget);

    controller.releaseHidden(b);
    await tester.pump();
    expect(find.text('shown'), findsOneWidget);
  });

  testWidgets('releasing a token that was never requested is a no-op', (
    tester,
  ) async {
    await tester.pumpWidget(app(const SizedBox()));
    final held = Object();
    controller.requestHidden(held);
    await tester.pump();

    controller.releaseHidden(Object());
    await tester.pump();
    expect(find.text('hidden'), findsOneWidget);
  });

  testWidgets('requests made while the tree is locked apply after the frame', (
    tester,
  ) async {
    await tester.pumpWidget(app(const _Holder()));
    await tester.pump();
    expect(find.text('hidden'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(app(const SizedBox()));
    await tester.pump();
    expect(find.text('shown'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('maybeOf is null outside a scope', (tester) async {
    ShellChromeController? found = controller;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            found = ShellChromeScope.maybeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found, isNull);
  });

  test('calls after dispose are ignored', () {
    final disposed = ShellChromeController()..dispose();
    expect(() => disposed.releaseHidden(Object()), returnsNormally);
    expect(() => disposed.requestHidden(Object()), returnsNormally);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/shared/widgets/shell_chrome_scope_test.dart`
Expected: compile failure, `shell_chrome_scope.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Hide requests for the app shell's own chrome: its navigation rail or
/// bottom bar, the update banner and the GPS-recording strip.
///
/// A page asks with any token it owns (its State is the usual one) and the
/// chrome stays hidden until every token is released, so two pages can never
/// cancel each other's request. The shell knows nothing about who asks.
class ShellChromeController extends ChangeNotifier {
  final Set<Object> _tokens = {};
  bool _disposed = false;

  bool get isHidden => _tokens.isNotEmpty;

  void requestHidden(Object token) {
    if (_disposed) return;
    final wasHidden = isHidden;
    if (_tokens.add(token) && !wasHidden) _notify();
  }

  void releaseHidden(Object token) {
    if (_disposed) return;
    if (_tokens.remove(token) && !isHidden) _notify();
  }

  /// Holders request from didChangeDependencies and release from dispose,
  /// both of which run while the tree is locked; a listener calling setState
  /// then would throw, so the notification waits for the end of the frame.
  void _notify() {
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Hands the shell's [ShellChromeController] to the page below it.
class ShellChromeScope extends InheritedWidget {
  const ShellChromeScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final ShellChromeController controller;

  /// The nearest shell's controller, or null when the caller sits outside
  /// the shell (a route pushed on the root navigator, or a test pumping the
  /// page as home). Registers no dependency, so it is safe from
  /// didChangeDependencies and callbacks; cache the result for dispose.
  static ShellChromeController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellChromeScope>()?.controller;

  @override
  bool updateShouldNotify(ShellChromeScope oldWidget) =>
      controller != oldWidget.controller;
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/shared/widgets/shell_chrome_scope_test.dart`
Expected: all 6 pass.

- [ ] **Step 5: Commit**

```bash
dart format lib/shared/widgets/shell_chrome_scope.dart test/shared/widgets/shell_chrome_scope_test.dart
git add lib/shared/widgets/shell_chrome_scope.dart test/shared/widgets/shell_chrome_scope_test.dart
git commit -m "feat(shell): add a scope for pages to hide the shell chrome"
```

---

### Task 3: MainScaffold honours hide requests

**Files:**
- Modify: `lib/shared/widgets/main_scaffold.dart` (state fields near line 34; `build` at 206-230; `_buildScaffold` at 232-380)
- Test: `test/shared/widgets/main_scaffold_test.dart` (new group at the end of `main()`)

**Interfaces:**
- Consumes: `ShellChromeController`, `ShellChromeScope` (Task 2).
- Produces: every page inside the shell can call `ShellChromeScope.maybeOf(context)` and get a non-null controller.

- [ ] **Step 1: Write the failing tests**

Add near the other test-only classes in `main_scaffold_test.dart`:

```dart
/// A shell page with state of its own, so a test can tell whether hiding the
/// chrome rebuilt the shell navigator (the count would reset to 0).
class _CounterPage extends StatefulWidget {
  const _CounterPage();

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => _count++),
    child: Text('count $_count'),
  );
}
```

Give `_buildTestApp` a `Widget dashboard = const Text('Dashboard')` parameter and use it as the `/dashboard` builder's return value, so existing callers are unchanged. Add the import
`import 'package:submersion/features/auto_update/presentation/widgets/update_banner.dart';`,
`import 'package:submersion/features/gps_log/presentation/widgets/gps_recording_strip.dart';` and
`import 'package:submersion/shared/widgets/shell_chrome_scope.dart';`. Then add this group at the end of `main()`:

```dart
  group('MainScaffold chrome hide requests (#1087)', () {
    ShellChromeController controllerOf(WidgetTester tester) =>
        ShellChromeScope.maybeOf(tester.element(find.byType(_CounterPage)))!;

    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        await _buildTestApp(dashboard: const _CounterPage()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a phone hides its bottom bar and strips while requested', (
      tester,
    ) async {
      await pumpAt(tester, const Size(390, 844));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(UpdateBanner), findsOneWidget);
      expect(find.byType(GpsRecordingStrip), findsOneWidget);

      final token = Object();
      controllerOf(tester).requestHidden(token);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(UpdateBanner), findsNothing);
      expect(find.byType(GpsRecordingStrip), findsNothing);

      controllerOf(tester).releaseHidden(token);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('a wide screen hides its rail and divider while requested', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1024, 800));
      expect(find.byType(NavigationRail), findsOneWidget);

      controllerOf(tester).requestHidden(Object());
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(VerticalDivider), findsNothing);
      expect(find.byType(SafeArea), findsNothing);
    });

    testWidgets('the page keeps its state across hide and restore', (
      tester,
    ) async {
      await pumpAt(tester, const Size(390, 844));
      await tester.tap(find.text('count 0'));
      await tester.pump();

      final token = Object();
      controllerOf(tester).requestHidden(token);
      await tester.pumpAndSettle();
      expect(find.text('count 1'), findsOneWidget);

      controllerOf(tester).releaseHidden(token);
      await tester.pumpAndSettle();
      expect(find.text('count 1'), findsOneWidget);
    });

    testWidgets('crossing the rail breakpoint while hidden stays hidden', (
      tester,
    ) async {
      await pumpAt(tester, const Size(390, 844));
      await tester.tap(find.text('count 0'));
      await tester.pump();
      controllerOf(tester).requestHidden(Object());
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(1024, 800);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('count 1'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/shared/widgets/main_scaffold_test.dart --plain-name "chrome hide requests"`
Expected: FAIL, `controllerOf` hits a null check (no scope above the page).

- [ ] **Step 3: Implement**

In `_MainScaffoldState`, add the import `import 'package:submersion/shared/widgets/shell_chrome_scope.dart';` and these members at the top of the class:

```dart
  /// Hide requests from pages inside the shell, such as the media viewer's
  /// fullscreen mode (#1087).
  final ShellChromeController _chromeController = ShellChromeController();

  void _onChromeChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _chromeController.addListener(_onChromeChanged);
  }

  @override
  void dispose() {
    _chromeController
      ..removeListener(_onChromeChanged)
      ..dispose();
    super.dispose();
  }

  /// The layout while a page holds a hide request: the page alone, edge to
  /// edge, with no rail, bottom bar, banner, strip or SafeArea inset.
  ///
  /// Moving [MainScaffold.child] between this and the chromed layout keeps
  /// every page on the shell navigator alive: go_router builds that
  /// navigator with a GlobalKey (ShellRoute.navigatorKey), so the element is
  /// reparented rather than rebuilt.
  Widget _buildChromelessScaffold() =>
      Scaffold(body: GlobalDropTarget(child: widget.child));
```

In `build`, replace `child: _buildScaffold(context),` with:

```dart
      child: ShellChromeScope(
        controller: _chromeController,
        child: _chromeController.isHidden
            ? _buildChromelessScaffold()
            : _buildScaffold(context),
      ),
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/shared/widgets/main_scaffold_test.dart test/shared/widgets/main_scaffold_back_navigation_test.dart`
Expected: all pass, including the 4 new tests.

- [ ] **Step 5: Commit**

```bash
dart format lib/shared/widgets/main_scaffold.dart test/shared/widgets/main_scaffold_test.dart
git add lib/shared/widgets/main_scaffold.dart test/shared/widgets/main_scaffold_test.dart
git commit -m "feat(shell): hide the shell chrome while a page requests it"
```

---

### Task 4: Toolbar with overflow menu, and the re-upload menu as a function

**Files:**
- Create: `lib/features/media/presentation/widgets/media_viewer_toolbar.dart`
- Rename: `lib/features/media_store/presentation/widgets/media_reupload_button.dart` to `media_reupload_menu.dart` (contents replaced)
- Rename: `test/features/media_store/media_reupload_button_test.dart` to `media_reupload_menu_test.dart` (contents replaced)
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart` (delete `_TopOverlay` and `_topChromeHeight`, lines ~1333-1488; replace the `_TopOverlay(...)` call at ~484; replace the import of `media_reupload_button.dart`)
- Test: `test/features/media/presentation/widgets/media_viewer_toolbar_test.dart`

**Interfaces:**
- Produces:
  - `bool mediaReuploadAvailable(WidgetRef ref)` and `Future<void> showMediaReuploadMenu(BuildContext anchorContext, WidgetRef ref, MediaItem item)` in `media_reupload_menu.dart`.
  - `const double kMediaViewerToolbarHeight = 64;`
  - `class MediaViewerAction` (`id`, `icon`, `label`, `priority`, `onPressed: void Function(BuildContext anchorContext)`, `iconColor`).
  - `class ToolbarActionSplit` (`visible`, `overflow`) and `ToolbarActionSplit splitToolbarActions(List<MediaViewerAction> actions, double availableWidth)`.
  - `class MediaViewerToolbar extends StatelessWidget`, a `Positioned` for a `Stack`, with the same parameters `_TopOverlay` had plus `required VoidCallback onEnterFullscreen` and `void Function(BuildContext anchorContext)? onReupload` (null hides re-upload).
  - Widget keys: `ValueKey('viewer_<id>')` on each visible action (`go_to_dive`, `share`, `info`, `perdix`, `species`, `write_metadata`, `lightroom`, `reupload`), `ValueKey('viewer_enter_fullscreen')`, `ValueKey('viewer_overflow')`, `ValueKey('viewer_menu_<id>')` on overflow items.

- [ ] **Step 1: Rewrite the re-upload test against the function**

`git mv test/features/media_store/media_reupload_button_test.dart test/features/media_store/media_reupload_menu_test.dart`, then in it replace the import of `media_reupload_button.dart` with `media_reupload_menu.dart`, and replace `home: Scaffold(body: MediaReuploadButton(item: item)),` with:

```dart
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => mediaReuploadAvailable(ref)
                  ? Builder(
                      builder: (anchor) => IconButton(
                        key: const Key('media-reupload-button'),
                        icon: const Icon(Icons.tune),
                        onPressed: () =>
                            showMediaReuploadMenu(anchor, ref, item),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
```

The two existing test bodies stay as they are.

- [ ] **Step 2: Write the failing toolbar tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_toolbar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

MediaViewerAction action(String id, int priority) => MediaViewerAction(
  id: id,
  icon: Icons.circle,
  label: id,
  priority: priority,
  onPressed: (_) {},
);

void main() {
  group('splitToolbarActions', () {
    final a = action('a', 2);
    final b = action('b', 0);
    final c = action('c', 1);

    test('everything fits: no overflow', () {
      final split = splitToolbarActions([a, b, c], 3 * 48);
      expect(split.visible, [a, b, c]);
      expect(split.overflow, isEmpty);
    });

    test('short of room: keeps by priority, leaves a slot for the menu', () {
      // 3 * 48 = 144 needed; 140 leaves (140 - 48) / 48 = 1 icon slot.
      final split = splitToolbarActions([a, b, c], 140);
      expect(split.visible, [b]);
      expect(split.overflow, [a, c]);
    });

    test('both lists keep toolbar order, not priority order', () {
      final x = action('x', 1);
      final y = action('y', 0);
      final z = action('z', 3);
      final w = action('w', 2);
      // 4 * 48 = 192 needed; 144 leaves (144 - 48) / 48 = 2 icon slots,
      // which go to y and x (priorities 0 and 1).
      final split = splitToolbarActions([x, y, z, w], 144);
      expect(split.visible, [x, y]);
      expect(split.overflow, [z, w]);
    });

    test('no room at all: everything in the menu', () {
      final split = splitToolbarActions([a, b, c], 20);
      expect(split.visible, isEmpty);
      expect(split.overflow, [a, b, c]);
    });
  });

  group('MediaViewerToolbar', () {
    final item = MediaItem(
      id: 'm1',
      mediaType: MediaType.photo,
      takenAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    Future<List<String>> pumpFull(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                MediaViewerToolbar(
                  item: item,
                  currentIndex: 11,
                  totalCount: 345,
                  onClose: () => calls.add('close'),
                  onEnterFullscreen: () => calls.add('fullscreen'),
                  onShare: (_) => calls.add('share'),
                  onShowInfo: () => calls.add('info'),
                  onWriteMetadata: () => calls.add('write_metadata'),
                  onTagSpecies: () => calls.add('species'),
                  canWriteMetadata: true,
                  showPerdixToggle: true,
                  perdixEnabled: false,
                  onTogglePerdix: () => calls.add('perdix'),
                  onOpenInLightroom: () => calls.add('lightroom'),
                  onGoToDive: () => calls.add('go_to_dive'),
                  onReupload: (_) => calls.add('reupload'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      return calls;
    }

    testWidgets('a 360 px phone fits the full set without overflowing', (
      tester,
    ) async {
      await pumpFull(tester, 360);
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Full screen'), findsOneWidget);
      expect(find.text('12 / 345'), findsOneWidget);
      // 360 - 8 padding - 96 fixed - 72 indicator = 184: (184 - 48) / 48
      // = 2 icon slots, the two highest priorities.
      expect(find.byKey(const ValueKey('viewer_go_to_dive')), findsOneWidget);
      expect(find.byKey(const ValueKey('viewer_share')), findsOneWidget);
      expect(find.byKey(const ValueKey('viewer_info')), findsNothing);
      expect(find.byKey(const ValueKey('viewer_overflow')), findsOneWidget);
    });

    testWidgets('a 412 px phone shows three icons and the menu', (
      tester,
    ) async {
      await pumpFull(tester, 412);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('viewer_info')), findsOneWidget);
      expect(find.byKey(const ValueKey('viewer_perdix')), findsNothing);
      expect(find.byKey(const ValueKey('viewer_overflow')), findsOneWidget);
    });

    testWidgets('a desktop width shows every icon and no menu', (
      tester,
    ) async {
      await pumpFull(tester, 1024);
      for (final id in [
        'go_to_dive',
        'share',
        'info',
        'perdix',
        'species',
        'write_metadata',
        'lightroom',
        'reupload',
      ]) {
        expect(find.byKey(ValueKey('viewer_$id')), findsOneWidget, reason: id);
      }
      expect(find.byKey(const ValueKey('viewer_overflow')), findsNothing);
    });

    testWidgets('actions in the menu still fire, in toolbar order', (
      tester,
    ) async {
      final calls = await pumpFull(tester, 360);
      await tester.tap(find.byKey(const ValueKey('viewer_overflow')));
      await tester.pumpAndSettle();

      final menuIds = tester
          .widgetList<PopupMenuItem<MediaViewerAction>>(
            find.byType(PopupMenuItem<MediaViewerAction>),
          )
          .map((w) => w.value!.id)
          .toList();
      expect(menuIds, [
        'write_metadata',
        'perdix',
        'lightroom',
        'species',
        'info',
        'reupload',
      ]);

      await tester.tap(find.byKey(const ValueKey('viewer_menu_info')));
      await tester.pumpAndSettle();
      expect(calls, ['info']);
    });

    testWidgets('the fullscreen and close buttons call back', (tester) async {
      final calls = await pumpFull(tester, 1024);
      await tester.tap(find.byTooltip('Full screen'));
      await tester.tap(find.byTooltip('Close photo viewer'));
      expect(calls, ['fullscreen', 'close']);
    });
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/media/presentation/widgets/media_viewer_toolbar_test.dart test/features/media_store/media_reupload_menu_test.dart`
Expected: compile failures, neither new file exists yet.

- [ ] **Step 4: Implement the re-upload menu**

`git mv lib/features/media_store/presentation/widgets/media_reupload_button.dart lib/features/media_store/presentation/widgets/media_reupload_menu.dart`, then replace its contents:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Whether a per-item re-upload can be offered: only when a media store is
/// connected on this device, since otherwise there is nothing to re-upload
/// to.
bool mediaReuploadAvailable(WidgetRef ref) =>
    ref.watch(mediaStoreResolverProvider) != null;

String _qualityLabel(AppLocalizations l10n, MediaUploadQuality q) =>
    switch (q) {
      MediaUploadQuality.original =>
        l10n.settings_mediaStorage_quality_original,
      MediaUploadQuality.high => l10n.settings_mediaStorage_quality_high,
      MediaUploadQuality.balanced =>
        l10n.settings_mediaStorage_quality_balanced,
      MediaUploadQuality.small => l10n.settings_mediaStorage_quality_small,
    };

/// Opens the upload-quality picker for [item], anchored to the widget
/// [anchorContext] belongs to (the toolbar icon, or the overflow button when
/// picked from the menu), and queues a re-upload at the chosen level,
/// replacing what the store holds.
Future<void> showMediaReuploadMenu(
  BuildContext anchorContext,
  WidgetRef ref,
  MediaItem item,
) async {
  final l10n = anchorContext.l10n;
  final button = anchorContext.findRenderObject()! as RenderBox;
  final overlay =
      Navigator.of(anchorContext).overlay!.context.findRenderObject()!
          as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(
        button.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );
  final level = await showMenu<MediaUploadQuality>(
    context: anchorContext,
    position: position,
    items: [
      for (final q in MediaUploadQuality.values)
        PopupMenuItem(value: q, child: Text(_qualityLabel(l10n, q))),
    ],
  );
  if (level == null || !anchorContext.mounted) return;
  await ref.read(mediaStoreReuploadProvider)(item.id, level);
  if (!anchorContext.mounted) return;
  ScaffoldMessenger.of(anchorContext).showSnackBar(
    SnackBar(content: Text(l10n.settings_mediaStorage_quality_reuploadQueued)),
  );
}
```

- [ ] **Step 5: Implement the toolbar**

Create `lib/features/media/presentation/widgets/media_viewer_toolbar.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/share_anchor.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Height of [MediaViewerToolbar]'s content below the status bar: its 8 px
/// vertical padding either side of a default 48 px [IconButton]. The Perdix
/// overlay reserves this band so the face can never sit on top of the
/// toolbar's buttons; keep the two in step if the padding changes.
const double kMediaViewerToolbarHeight = 64;

/// Width of one toolbar icon button (the default [IconButton] extent).
const double kToolbarButtonExtent = 48;

/// Room kept for the "12 / 345" page indicator before any action icon.
const double _indicatorMinWidth = 72;

/// One toolbar action, described as data so the toolbar can show it as an
/// icon or move it into the overflow menu without knowing what it does.
@immutable
class MediaViewerAction {
  const MediaViewerAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.priority,
    required this.onPressed,
    this.iconColor,
  });

  /// Stable id; also names the widget key (`viewer_<id>`).
  final String id;
  final IconData icon;

  /// Tooltip on the icon, and the text of its overflow-menu entry.
  final String label;

  /// Lower stays visible longer when the toolbar runs out of room.
  final int priority;

  /// Receives the context of whatever was tapped (the icon, or the overflow
  /// button when picked from the menu) for anchoring popovers and menus.
  final void Function(BuildContext anchorContext) onPressed;

  /// Tint for state (the Perdix toggle when on); null uses the default.
  final Color? iconColor;
}

/// The result of [splitToolbarActions]: both lists in toolbar order.
@immutable
class ToolbarActionSplit {
  const ToolbarActionSplit(this.visible, this.overflow);

  final List<MediaViewerAction> visible;
  final List<MediaViewerAction> overflow;
}

/// Splits [actions] (in toolbar order) into the icons that fit in
/// [availableWidth] and the rest. When everything fits there is no menu;
/// otherwise one slot goes to the overflow button and the remaining slots go
/// to the lowest [MediaViewerAction.priority] values.
ToolbarActionSplit splitToolbarActions(
  List<MediaViewerAction> actions,
  double availableWidth,
) {
  if (actions.length * kToolbarButtonExtent <= availableWidth) {
    return ToolbarActionSplit(List.unmodifiable(actions), const []);
  }
  final slots = ((availableWidth - kToolbarButtonExtent) /
          kToolbarButtonExtent)
      .floor()
      .clamp(0, actions.length);
  final keep = (List.of(actions)
        ..sort((a, b) => a.priority.compareTo(b.priority)))
      .take(slots)
      .toSet();
  return ToolbarActionSplit(
    List.unmodifiable(actions.where(keep.contains)),
    List.unmodifiable(actions.where((a) => !keep.contains(a))),
  );
}

/// The viewer's top bar: close, fullscreen, the page indicator, and the
/// actions, with whatever does not fit in an overflow menu. A [Positioned],
/// so it goes straight into the viewer's [Stack].
class MediaViewerToolbar extends StatelessWidget {
  const MediaViewerToolbar({
    super.key,
    required this.item,
    required this.currentIndex,
    required this.totalCount,
    required this.onClose,
    required this.onEnterFullscreen,
    required this.onShare,
    required this.onShowInfo,
    required this.onWriteMetadata,
    required this.onTagSpecies,
    required this.canWriteMetadata,
    required this.showPerdixToggle,
    required this.perdixEnabled,
    required this.onTogglePerdix,
    this.onOpenInLightroom,
    this.onGoToDive,
    this.onReupload,
  });

  final MediaItem item;
  final int currentIndex;
  final int totalCount;
  final VoidCallback onClose;
  final VoidCallback onEnterFullscreen;
  final void Function(Rect? anchor) onShare;
  final VoidCallback onShowInfo;
  final VoidCallback onWriteMetadata;
  final VoidCallback onTagSpecies;

  /// Whether the write-dive-data action is offered. Needs enrichment depth to
  /// have anything to write, and a photo to write it to: videos cannot be
  /// edited in place, and replacing one would destroy the original
  /// (issue #1472).
  final bool canWriteMetadata;

  /// Whether the Perdix overlay toggle is shown (media synced to a profile).
  final bool showPerdixToggle;

  /// Whether the Perdix overlay is currently enabled (tints the icon).
  final bool perdixEnabled;
  final VoidCallback onTogglePerdix;

  /// Non-null only for Lightroom-linked items on the connected device.
  final VoidCallback? onOpenInLightroom;

  /// Non-null when the viewer is cross-dive and the item has a dive link.
  final VoidCallback? onGoToDive;

  /// Non-null when a media store is connected on this device.
  final void Function(BuildContext anchorContext)? onReupload;

  List<MediaViewerAction> _actions(BuildContext context) {
    final l10n = context.l10n;
    return [
      if (onGoToDive != null)
        MediaViewerAction(
          id: 'go_to_dive',
          icon: Icons.scuba_diving,
          label: l10n.media_viewer_goToDive,
          priority: 0,
          onPressed: (_) => onGoToDive!(),
        ),
      if (canWriteMetadata)
        MediaViewerAction(
          id: 'write_metadata',
          icon: Icons.edit_note,
          label: l10n.media_photoViewer_writeDiveDataTooltip,
          priority: 5,
          onPressed: (_) => onWriteMetadata(),
        ),
      if (showPerdixToggle)
        MediaViewerAction(
          id: 'perdix',
          icon: Icons.watch,
          label: l10n.media_perdixOverlay_toggleTooltip,
          priority: 3,
          iconColor: perdixEnabled
              ? Theme.of(context).colorScheme.primary
              : null,
          onPressed: (_) => onTogglePerdix(),
        ),
      if (onOpenInLightroom != null)
        MediaViewerAction(
          id: 'lightroom',
          icon: Icons.open_in_new,
          label: l10n.media_lightroom_openInLightroom,
          priority: 6,
          onPressed: (_) => onOpenInLightroom!(),
        ),
      MediaViewerAction(
        id: 'species',
        icon: Icons.sell_outlined,
        label: l10n.media_species_actionTooltip,
        priority: 4,
        onPressed: (_) => onTagSpecies(),
      ),
      MediaViewerAction(
        id: 'info',
        icon: Icons.info_outline,
        label: l10n.media_info_title,
        priority: 2,
        onPressed: (_) => onShowInfo(),
      ),
      MediaViewerAction(
        id: 'share',
        icon: Icons.share,
        label: l10n.media_photoViewer_shareTooltip,
        priority: 1,
        // The anchor is the tapped button's context, so the iPad popover
        // points at it (or at the overflow button when shared from the menu).
        onPressed: (anchor) => onShare(shareAnchorFrom(anchor)),
      ),
      if (onReupload != null)
        MediaViewerAction(
          id: 'reupload',
          icon: Icons.tune,
          label: l10n.settings_mediaStorage_quality_section,
          priority: 7,
          onPressed: (anchor) => onReupload!(anchor),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = _actions(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final split = splitToolbarActions(
                  actions,
                  constraints.maxWidth -
                      2 * kToolbarButtonExtent -
                      _indicatorMinWidth,
                );
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: l10n.media_photoViewer_closeTooltip,
                      onPressed: onClose,
                    ),
                    IconButton(
                      key: const ValueKey('viewer_enter_fullscreen'),
                      icon: const Icon(Icons.fullscreen, color: Colors.white),
                      tooltip: l10n.media_viewer_enterFullscreen,
                      onPressed: onEnterFullscreen,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          l10n.media_photoViewer_pageIndicator(
                            currentIndex + 1,
                            totalCount,
                          ),
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    for (final action in split.visible)
                      // Builder so the anchor context is the button itself:
                      // findRenderObject from it descends to the IconButton.
                      Builder(
                        key: ValueKey('viewer_${action.id}'),
                        builder: (anchor) => IconButton(
                          icon: Icon(
                            action.icon,
                            color: action.iconColor ?? Colors.white,
                          ),
                          tooltip: action.label,
                          onPressed: () => action.onPressed(anchor),
                        ),
                      ),
                    if (split.overflow.isNotEmpty)
                      Builder(
                        builder: (anchor) =>
                            PopupMenuButton<MediaViewerAction>(
                              key: const ValueKey('viewer_overflow'),
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                              ),
                              tooltip: l10n.media_viewer_moreOptions,
                              onSelected: (action) => action.onPressed(anchor),
                              itemBuilder: (_) => [
                                for (final action in split.overflow)
                                  PopupMenuItem<MediaViewerAction>(
                                    key: ValueKey('viewer_menu_${action.id}'),
                                    value: action,
                                    child: Row(
                                      children: [
                                        Icon(
                                          action.icon,
                                          color: action.iconColor,
                                        ),
                                        const SizedBox(width: 12),
                                        Flexible(child: Text(action.label)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Switch the page to the toolbar**

In `media_viewer_page.dart`:
- Replace the import of `media_reupload_button.dart` with `import 'package:submersion/features/media_store/presentation/widgets/media_reupload_menu.dart';` and add `import 'package:submersion/features/media/presentation/widgets/media_viewer_toolbar.dart';`.
- Delete the `_topChromeHeight` constant with its doc comment, and the whole `_TopOverlay` class.
- In the Perdix mount, replace `_topChromeHeight` with `kMediaViewerToolbarHeight`.
- Replace `_TopOverlay(` with `MediaViewerToolbar(` and add these arguments to the call (keep all existing ones):

```dart
                    onEnterFullscreen: _enterFullscreen,
                    onShowInfo: () => showMediaInfoSheet(context, currentItem),
                    onReupload: mediaReuploadAvailable(ref)
                        ? (anchor) =>
                              showMediaReuploadMenu(anchor, ref, currentItem)
                        : null,
```

- Add a temporary stub method to `_MediaViewerPageState`, which Task 5 replaces:

```dart
  void _enterFullscreen() {}
```

- [ ] **Step 7: Run to verify pass**

Run: `flutter test test/features/media/presentation/widgets/media_viewer_toolbar_test.dart test/features/media_store/media_reupload_menu_test.dart test/features/media/presentation/pages/`
Expected: all pass. If a viewer test looked up the share or species button by tooltip and the 800 px default test view now overflows them into the menu, widen that test's view to 1024 px rather than changing the assertion.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/media lib/features/media_store test/features/media test/features/media_store
git add -A lib/features/media/presentation lib/features/media_store/presentation/widgets test/features/media/presentation test/features/media_store
git commit -m "feat(media): move the viewer toolbar out and add an overflow menu"
```

---

### Task 5: Fullscreen mode for photos

**Files:**
- Create: `lib/features/media/presentation/widgets/media_fullscreen_controls.dart`
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart` (state fields after `_showOverlay` at line 99; `dispose` at ~221; `_handleKeyEvent` at ~263; `build` at ~306-635)
- Test: `test/features/media/presentation/pages/media_viewer_fullscreen_test.dart`

**Interfaces:**
- Consumes: `ShellChromeScope.maybeOf`, `ShellChromeController.requestHidden/releaseHidden` (Task 2); `MediaViewerToolbar.onEnterFullscreen` (Task 4); `context.l10n.media_viewer_exitFullscreen` (Task 1).
- Produces: `class MediaFullscreenExitButton extends StatelessWidget` (`required VoidCallback onExit`, key `ValueKey('viewer_exit_fullscreen')`, a top-left `Positioned`); viewer state `_isFullscreen`, `_fullscreenControlsVisible`, and methods `_enterFullscreen()`, `_exitFullscreen()`, `_revealFullscreenControls({required bool autoHide})`, `_onSetOverlay(bool value)` used by Task 6.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

class _UnavailableResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.notFound);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

MediaItem item(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2026, 7, 1, 10),
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  /// The viewer pushed over a host page, so Back and Esc have somewhere to
  /// go. No runAsync: pumpAndSettle drives the fake clock the 3 s fade uses.
  Future<void> pumpViewer(
    WidgetTester tester, {
    List<MediaItem>? media,
  }) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.platformGallery: _UnavailableResolver(),
            }),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MediaViewerPage(
                    mediaList: media ?? [item('a'), item('b')],
                    initialMediaId: 'a',
                  ),
                ),
              ),
              child: const Text('Open viewer'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open viewer'));
    await tester.pumpAndSettle();
  }

  /// A tap on the photo. The wait lets PhotoView's double-tap recognizer
  /// time out and release the gesture arena to the tap target.
  Future<void> tapPhoto(WidgetTester tester) async {
    await tester.tapAt(tester.getCenter(find.byType(MediaViewerPage)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  Future<void> enterFullscreen(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Full screen'));
    await tester.pump();
  }

  final exitButton = find.byTooltip('Exit full screen');

  testWidgets('opens in normal mode with the Full screen button', (
    tester,
  ) async {
    await pumpViewer(tester);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byTooltip('Full screen'), findsOneWidget);
    expect(exitButton, findsNothing);
  });

  testWidgets('fullscreen hides every overlay', (tester) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);
    expect(find.text('1 / 2'), findsNothing);
    expect(find.byTooltip('Next media'), findsNothing);
    expect(find.byTooltip('Full screen'), findsNothing);
    expect(exitButton, findsNothing);
  });

  testWidgets('a tap reveals the exit button, which hides after 3 s', (
    tester,
  ) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);
    await tapPhoto(tester);
    expect(exitButton, findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(exitButton, findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(exitButton, findsNothing);
    expect(find.text('1 / 2'), findsNothing);
  });

  testWidgets('a second tap hides the exit button straight away', (
    tester,
  ) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);
    await tapPhoto(tester);
    await tapPhoto(tester);
    expect(exitButton, findsNothing);
  });

  testWidgets('the exit button returns to the normal viewer', (tester) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);
    await tapPhoto(tester);
    await tester.tap(exitButton);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byType(MediaViewerPage), findsOneWidget);
  });

  testWidgets('Esc leaves fullscreen first, then closes the viewer', (
    tester,
  ) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsNothing);
  });

  testWidgets('Back leaves fullscreen first, then closes the viewer', (
    tester,
  ) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsNothing);
  });

  testWidgets('arrow keys still page and fullscreen stays on', (tester) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('a viewer opened again starts in normal mode', (tester) async {
    await pumpViewer(tester);
    await enterFullscreen(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open viewer'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('an emptied gallery leaves fullscreen by itself', (
    tester,
  ) async {
    final media = ValueNotifier<List<MediaItem>>([item('a')]);
    addTearDown(media.dispose);
    await pumpViewer(tester);
    // Re-host the viewer on a list that can change under it, as the
    // provider-backed wrappers do.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ValueListenableBuilder<List<MediaItem>>(
          valueListenable: media,
          builder: (context, list, child) =>
              MediaViewerPage(mediaList: list, initialMediaId: 'a'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterFullscreen(tester);

    media.value = const [];
    await tester.pumpAndSettle();
    expect(find.text('No photos available'), findsOneWidget);

    // Out of fullscreen, so one Back closes the viewer.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsNothing);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/pages/media_viewer_fullscreen_test.dart`
Expected: the first test passes; the rest fail (the stub does nothing, so overlays stay up).

- [ ] **Step 3: Create the exit button**

`lib/features/media/presentation/widgets/media_fullscreen_controls.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The corner button a tap reveals in the viewer's fullscreen mode (#1087).
/// A [Positioned] for the viewer's [Stack], kept inside the safe area.
class MediaFullscreenExitButton extends StatelessWidget {
  const MediaFullscreenExitButton({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      child: SafeArea(
        right: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              key: const ValueKey('viewer_exit_fullscreen'),
              icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
              tooltip: context.l10n.media_viewer_exitFullscreen,
              onPressed: onExit,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add the fullscreen state to the viewer**

Add imports: `import 'package:submersion/features/media/presentation/widgets/media_fullscreen_controls.dart';` and `import 'package:submersion/shared/widgets/shell_chrome_scope.dart';`.

Directly after `bool _showOverlay = true;` add:

```dart
  /// Fullscreen mode (#1087): every overlay, the Perdix face and the app
  /// shell's chrome hidden, the media alone on screen. Never persisted, so
  /// every viewer opens in normal mode.
  bool _isFullscreen = false;

  /// Whether a tap has revealed the exit button (and, on a video, its
  /// controls bar) while in fullscreen.
  bool _fullscreenControlsVisible = false;

  Timer? _fullscreenControlsTimer;

  static const _fullscreenControlsTimeout = Duration(seconds: 3);

  /// The shell's chrome controller, cached because dispose cannot look up
  /// ancestors. Null when the viewer sits above the shell (pushed on the root
  /// navigator), where there is no shell chrome to hide.
  ShellChromeController? _shellChrome;
```

Replace the Task 4 stub `void _enterFullscreen() {}` with:

```dart
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shellChrome = ShellChromeScope.maybeOf(context);
  }

  void _enterFullscreen() {
    setState(() {
      _isFullscreen = true;
      _fullscreenControlsVisible = false;
    });
    _shellChrome?.requestHidden(this);
  }

  void _exitFullscreen() {
    _fullscreenControlsTimer?.cancel();
    setState(() {
      _isFullscreen = false;
      _fullscreenControlsVisible = false;
      _showOverlay = true;
    });
    _shellChrome?.releaseHidden(this);
  }

  /// Shows the fullscreen controls; with [autoHide] they go again after
  /// [_fullscreenControlsTimeout] unless another tap restarts the clock.
  void _revealFullscreenControls({required bool autoHide}) {
    _fullscreenControlsTimer?.cancel();
    setState(() => _fullscreenControlsVisible = true);
    if (!autoHide) return;
    _fullscreenControlsTimer = Timer(_fullscreenControlsTimeout, () {
      if (mounted) setState(() => _fullscreenControlsVisible = false);
    });
  }

  void _onFullscreenPhotoTap() {
    if (!_fullscreenControlsVisible) {
      _revealFullscreenControls(autoHide: true);
      return;
    }
    _fullscreenControlsTimer?.cancel();
    setState(() => _fullscreenControlsVisible = false);
  }

  /// Video play/pause reports here: [show] is true when the video just
  /// paused. Outside fullscreen that drives the overlays as before; inside
  /// it reveals the fullscreen controls, which stay up while paused.
  void _onSetOverlay(bool show) {
    if (_isFullscreen) {
      _revealFullscreenControls(autoHide: !show);
      return;
    }
    setState(() => _showOverlay = show);
  }
```

In `dispose`, before `super.dispose();`, add:

```dart
    _fullscreenControlsTimer?.cancel();
    // A viewer closed while fullscreen (swipe-down) gives the chrome back.
    _shellChrome?.releaseHidden(this);
```

In `_handleKeyEvent`, replace the Esc branch with:

```dart
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_isFullscreen) {
        _exitFullscreen();
      } else {
        Navigator.of(context).maybePop();
      }
      return KeyEventResult.handled;
    }
```

- [ ] **Step 5: Wire it into build**

1. Wrap the returned `Scaffold(` in a `PopScope`:

```dart
    return PopScope(
      // Back leaves fullscreen first; only the next press closes the viewer.
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFullscreen) _exitFullscreen();
      },
      child: Scaffold(
        // ...existing body unchanged...
      ),
    );
```

2. In the `if (mediaList.isEmpty)` branch, before `return Center(`, add:

```dart
            // Nothing left to tap means no exit button: leave fullscreen so
            // the shell's navigation comes back (a sync can empty the list).
            if (_isFullscreen) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _isFullscreen) _exitFullscreen();
              });
            }
```

3. In `_PhotoGallery(...)`, change `onSetOverlay: (value) => setState(() => _showOverlay = value),` to `onSetOverlay: _onSetOverlay,` and `showOverlay: _showOverlay,` to `showOverlay: _isFullscreen ? _fullscreenControlsVisible : _showOverlay,`.

4. In the photo tap target, change `onTap: () => setState(() => _showOverlay = !_showOverlay),` to:

```dart
                        onTap: _isFullscreen
                            ? _onFullscreenPhotoTap
                            : () =>
                                  setState(() => _showOverlay = !_showOverlay),
```

5. Change `if (_showOverlay) ...[` to `if (_showOverlay && !_isFullscreen) ...[`.

6. Change the Perdix condition `if (settings.perdixOverlayEnabled &&` to `if (!_isFullscreen && settings.perdixOverlayEnabled &&`.

7. As the last child of the `Stack`, after the Perdix block, add:

```dart
                if (_isFullscreen && _fullscreenControlsVisible)
                  MediaFullscreenExitButton(onExit: _exitFullscreen),
```

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/media/presentation/pages/`
Expected: all pass, including the 10 new tests.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/media test/features/media
git add lib/features/media/presentation test/features/media/presentation
git commit -m "feat(media): add a fullscreen mode to the media viewer"
```

---

### Task 6: Fullscreen for videos

**Files:**
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart` (`_PhotoGallery` at ~798-870, `_VideoItem` at ~958-1170)
- Test: `test/features/media/presentation/pages/media_viewer_video_test.dart` (append)

**Interfaces:**
- Consumes: `_onSetOverlay`, `_isFullscreen`, `_fullscreenControlsVisible` (Task 5).
- Produces: `_PhotoGallery` and `_VideoItem` take `final bool fullscreen` (default `false` on `_VideoItem`).

- [ ] **Step 1: Write the failing test**

Append inside `main()` of `media_viewer_video_test.dart`:

```dart
  testWidgets('in fullscreen a tap plays, reveals the controls, and they '
      'stay while paused', (tester) async {
    final platform = _FakeVideoPlatform();
    final originalPlatform = VideoPlayerPlatform.instance;
    addTearDown(() => VideoPlayerPlatform.instance = originalPlatform);
    VideoPlayerPlatform.instance = platform;

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaSourceResolverRegistryProvider.overrideWithValue(
              MediaSourceResolverRegistry({
                MediaSourceType.localFile: _UnavailableResolver(),
              }),
            ),
            resolvedFilePathProvider.overrideWith(
              (ref, MediaItem arg) async => '/tmp/v1.mp4',
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerPage(
              mediaList: [video('v1')],
              initialMediaId: 'v1',
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      platform.completeInitialization();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    // Matched on the Semantics widgets the player wraps its controls in,
    // which does not depend on how the semantics tree merges them.
    Finder semanticsWidget(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
    );
    final seekBar = semanticsWidget('Seek video position');
    final playPause = semanticsWidget('Play or pause video');
    final exitButton = find.byTooltip('Exit full screen');

    await tester.tap(find.byTooltip('Full screen'));
    await tester.pump();
    expect(seekBar, findsNothing);
    expect(exitButton, findsNothing);

    // Tap: plays, and reveals the exit button and controls bar.
    await tester.tap(playPause);
    await tester.pump();
    expect(platform.playing, isTrue);
    expect(exitButton, findsOneWidget);
    expect(seekBar, findsOneWidget);

    // Playing: hidden again after 3 s.
    await tester.pump(const Duration(seconds: 3));
    expect(exitButton, findsNothing);
    expect(seekBar, findsNothing);

    // Tap: pauses, reveals, and stays while paused.
    await tester.tap(playPause);
    await tester.pump();
    expect(platform.playing, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(exitButton, findsOneWidget);
    expect(seekBar, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/presentation/pages/media_viewer_video_test.dart`
Expected: the new test FAILS at `expect(seekBar, findsNothing)` right after entering fullscreen, because a paused video already has its controls showing and `_VideoItem` still draws them.

- [ ] **Step 3: Implement**

In `_PhotoGallery`: add the field `final bool fullscreen;`, the constructor parameter `required this.fullscreen,`, and pass `fullscreen: fullscreen,` to `_VideoItem(...)`. In the page's `_PhotoGallery(...)` call add `fullscreen: _isFullscreen,`.

In `_VideoItem`: add the field and doc

```dart
  /// The viewer's fullscreen mode: the centre play indicator follows the
  /// controls' visibility, and the controls bar sits at the bottom edge
  /// because no metadata panel is drawn under it.
  final bool fullscreen;
```

and the constructor parameter `this.fullscreen = false,`.

In `_VideoItemState.build`, change the centre indicator condition `if (!controller.value.isPlaying)` to:

```dart
          if (!controller.value.isPlaying &&
              (!widget.fullscreen || widget.showOverlay))
```

and the controls bar `bottom: 160, // Above the metadata overlay and mini profile` to:

```dart
              // Above the metadata overlay and mini profile; at the edge in
              // fullscreen, where neither is drawn.
              bottom: widget.fullscreen
                  ? MediaQuery.paddingOf(context).bottom + 24
                  : 160,
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/media/presentation/pages/`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media test/features/media
git add lib/features/media/presentation/pages/media_viewer_page.dart test/features/media/presentation/pages/media_viewer_video_test.dart
git commit -m "feat(media): reveal video controls on tap in fullscreen"
```

---

### Task 7: Viewer and shell together

**Files:**
- Test: `test/features/media/presentation/pages/media_viewer_shell_chrome_test.dart`

**Interfaces:**
- Consumes: `ShellChromeController`, `ShellChromeScope` (Task 2); the viewer's fullscreen (Task 5).

This pins the viewer's half of the contract against a minimal shell (`MainScaffold`'s half is pinned in Task 3), so the test needs none of `MainScaffold`'s provider stubs.

- [ ] **Step 1: Write the test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/shell_chrome_scope.dart';

import '../../../../helpers/test_database.dart';

class _UnavailableResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.notFound);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

/// The smallest shell honouring hide requests: a 'NAV' label in place of
/// MainScaffold's navigation.
class _Shell extends StatefulWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  final _controller = ShellChromeController();

  void _changed() => setState(() {});

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShellChromeScope(
    controller: _controller,
    child: Scaffold(
      body: widget.child,
      bottomNavigationBar: _controller.isHidden ? null : const Text('NAV'),
    ),
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/media',
      routes: [
        ShellRoute(
          builder: (context, state, child) => _Shell(child: child),
          routes: [
            GoRoute(
              path: '/media',
              builder: (context, state) => Builder(
                builder: (inner) => TextButton(
                  onPressed: () => Navigator.of(inner).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => MediaViewerPage(
                        mediaList: [
                          MediaItem(
                            id: 'a',
                            mediaType: MediaType.photo,
                            sourceType: MediaSourceType.platformGallery,
                            takenAt: DateTime.utc(2026, 7, 1, 10),
                            createdAt: DateTime.utc(2026, 7, 1),
                            updatedAt: DateTime.utc(2026, 7, 1),
                          ),
                        ],
                        initialMediaId: 'a',
                      ),
                    ),
                  ),
                  child: const Text('Media Section'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.platformGallery: _UnavailableResolver(),
            }),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Media Section'));
    await tester.pumpAndSettle();
  }

  testWidgets('the shell nav stays up in normal mode', (tester) async {
    await pumpShell(tester);
    expect(find.byType(MediaViewerPage), findsOneWidget);
    expect(find.text('NAV'), findsOneWidget);
  });

  testWidgets('fullscreen hides the shell nav and leaving restores it', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('Full screen'));
    await tester.pumpAndSettle();
    expect(find.text('NAV'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsOneWidget);
    expect(find.text('NAV'), findsOneWidget);
  });

  testWidgets('closing the viewer while fullscreen restores the nav', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('Full screen'));
    await tester.pumpAndSettle();

    // Swipe-down closes with a plain Navigator.pop, which bypasses the
    // fullscreen PopScope; call the same pop directly so the test does not
    // depend on PhotoView's gesture arena.
    Navigator.of(tester.element(find.byType(MediaViewerPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerPage), findsNothing);
    expect(find.text('NAV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/features/media/presentation/pages/media_viewer_shell_chrome_test.dart`
Expected: 3 pass. These pass on Task 5's code; if one fails, the bug is in Task 5's request/release wiring. Fix it there, not in the test.

- [ ] **Step 3: Commit**

```bash
dart format test/features/media
git add test/features/media/presentation/pages/media_viewer_shell_chrome_test.dart
git commit -m "test(media): pin the viewer's fullscreen contract with the shell"
```

---

### Task 8: Verification and after screenshots

**Files:** none in the repo (scratchpad screenshots)

- [ ] **Step 1: Whole-project checks**

Run, in order (analyze before tests):

```bash
dart format .
flutter analyze
flutter test test/architecture/
flutter test test/shared/widgets/ test/features/media/ test/features/media_store/ test/features/dashboard/ test/features/trips/ test/features/dive_log/presentation/
```

Expected: no format changes, no analyzer issues (infos included), all tests pass. Then `git status` must be clean apart from intended changes; commit any formatting fixes as `style: format`.

- [ ] **Step 2: Check the viewer file shrank**

Run: `wc -l lib/features/media/presentation/pages/media_viewer_page.dart lib/features/media/presentation/widgets/media_viewer_toolbar.dart lib/features/media/presentation/widgets/media_fullscreen_controls.dart lib/shared/widgets/shell_chrome_scope.dart`
Expected: the page below its starting 1,726 lines; each new file under 400.

- [ ] **Step 3: After screenshots**

With the `run` skill, capture the same screens as Task 0 plus the new states, into the scratchpad:
`01-viewer-phone-after.png` (normal mode with the Full screen button), `04-viewer-fullscreen-phone-after.png` (nothing but the photo), `05-viewer-fullscreen-exit-revealed-phone-after.png`, `06-viewer-overflow-menu-phone-after.png` (360 px, menu open), `07-viewer-fullscreen-desktop-after.png` (rail gone), and `08-viewer-fullscreen-video-revealed-phone-after.png` (exit button and controls bar at the bottom edge).
