# Pinned Strip Shadow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the pinned dive profile strip a deeper custom shadow, stronger in dark mode, plus a faint light rim in dark mode (issue #4554).

**Architecture:** Two pure helpers in a new file compute the strip's shadows and its edge line from the theme brightness and a 0 to 1 strength. The strip drops `Material.elevation`, paints the shadows from a `DecoratedBox` behind its `Material`, clipped so they never rise above the strip's top, and feeds the edge line to the existing `PinnedStripOutlinePainter`.

**Tech Stack:** Flutter, `flutter_test`.

**Spec:** `docs/design/specs/2026-11-14-pinned-strip-shadow-design.md`

## Global Constraints

- Light shadows: black 18% at offset (0, 2), blur 4; black 24% at offset (0, 10), blur 22.
- Dark shadows: black 65% at offset (0, 2), blur 6; black 70% at offset (0, 12), blur 28.
- Dark rim: 1 px, white at 12%, sides and bottom only. A theme card outline, where there is one, is drawn instead of the rim.
- No shadow and no rim while the surface is see-through (`backgroundOpacity < 1`); once opaque, strength = `condense`.
- Same look in every theme preset; brightness comes from `Theme.of(context).brightness`.

## Review Focus

- Mid-condense the strip's top crosses the profile card; a blurred shadow spilling upward would grey the card header above it (and the app bar once pinned). Expect the shadow clipped at the strip's top edge. Pinned by `shadow is clipped at the strip top` in Task 2.
- Condense near 0 with an opaque surface: a full-opacity shadow with a tiny blur would show as a hard dark line. Expect opacity and size to shrink together. Pinned by `strength scales opacity, offset and blur` in Task 1.
- A dark preset whose cards have an outline (Console, Minimalist dark): expect one line, the theme's, not the rim on top of it. Pinned by `theme outline wins over the rim` in Task 1.
- The surface fading in at `backgroundOpacity` 0.5: the theme outline keeps fading with the surface as it does today; the rim stays off. Pinned in Task 1 and by the existing outline fade test.
- Switching light and dark at runtime: everything is derived in `build`, so no cached state; covered by the dark widget test in Task 2.

---

### Task 1: Shadow and edge helpers

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_lift.dart`
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_lift_test.dart`

**Interfaces:**
- Produces:
  - `List<BoxShadow> pinnedStripShadows(Brightness brightness, {required double strength})`: the spec's list for `brightness` with each shadow's colour alpha, offset and blur multiplied by `strength` clamped to 0..1; empty when strength is 0.
  - `BorderSide pinnedStripEdge({required Brightness brightness, required BorderSide themeSide, required double surfaceOpacity, required double strength})`: `themeSide` with its alpha multiplied by `surfaceOpacity` when the theme side is drawn (style not none, width > 0); otherwise, in dark, `BorderSide(color: white at 0.12 * strength, width: 1)`, or `BorderSide.none` when strength is 0; in light, `BorderSide.none`.
  - `const double kPinnedStripRimAlpha = 0.12;`

- [ ] **Step 1: Write the failing tests**

```dart
test('light shadows at full strength', () {
  final s = pinnedStripShadows(Brightness.light, strength: 1);
  expect(s, hasLength(2));
  // Colours are float alpha (0.18, 0.24), so compare alpha with closeTo.
  expect(s[0].color.a, closeTo(0.18, 1e-6));
  expect(s[0].offset, const Offset(0, 2));
  expect(s[0].blurRadius, 4);
  expect(s[1].color.a, closeTo(0.24, 1e-6));
  expect(s[1].offset, const Offset(0, 10));
  expect(s[1].blurRadius, 22);
});
test('dark shadows at full strength', () {
  // 0.65 and 0.70 alpha; compare alpha with closeTo, offset and blur exactly.
});
test('strength scales opacity, offset and blur', () {
  final half = pinnedStripShadows(Brightness.dark, strength: 0.5);
  expect(half[1].color.a, closeTo(0.35, 1e-3));
  expect(half[1].offset, const Offset(0, 6));
  expect(half[1].blurRadius, 14);
});
test('no shadows at strength 0', () {
  expect(pinnedStripShadows(Brightness.light, strength: 0), isEmpty);
});
test('dark rim when the theme has no outline', () {
  final rim = pinnedStripEdge(brightness: Brightness.dark,
      themeSide: BorderSide.none, surfaceOpacity: 1, strength: 1);
  expect(rim.width, 1);
  expect(rim.color.a, closeTo(0.12, 1e-6));
  expect(rim.color.r, 1);
});
test('rim follows strength and is off at 0', () { /* 0.5 -> 0.06; 0 -> BorderSide.none */ });
test('no rim in light mode', () { /* BorderSide.none */ });
test('theme outline wins over the rim', () {
  const side = BorderSide(color: Color(0xFF336699), width: 1.5);
  final edge = pinnedStripEdge(brightness: Brightness.dark,
      themeSide: side, surfaceOpacity: 0.5, strength: 0);
  expect(edge.width, 1.5);
  expect(edge.color.a, closeTo(0.5, 1e-6));
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_lift_test.dart`
Expected: FAIL, `pinned_strip_lift.dart` does not exist.

- [ ] **Step 3: Implement the helpers in `pinned_strip_lift.dart`**

- [ ] **Step 4: Run to verify they pass** (same command, all PASS)

- [ ] **Step 5: Commit** `feat(dive-log): shadow and rim helpers for the pinned profile strip`

### Task 2: Wire them into the strip

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip.dart` (remove `kPinnedStripElevation` and its doc; the `Material` around line 213)
- Test: `test/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip_test.dart` (replace `its shadow grows with the condense`)

**Interfaces:**
- Consumes: `pinnedStripShadows`, `pinnedStripEdge` from Task 1.
- Produces: `class PinnedStripShadowClip extends CustomClipper<Rect>` in `pinned_strip_lift.dart`, clipping to `Rect.fromLTRB(-kPinnedStripShadowReach, 0, size.width + kPinnedStripShadowReach, size.height + kPinnedStripShadowReach)` with `const double kPinnedStripShadowReach = 64;` (covers the dark shadow's offset 12 plus blur 28).

- [ ] **Step 1: Write the failing widget tests** (in the strip test, using `pumpMorphing`)

```dart
testWidgets('its shadow grows with the condense', (tester) async {
  // Material never casts its own: elevation 0 at condense 0, 0.5, 1.
  // The DecoratedBox shadow under the strip equals
  // pinnedStripShadows(Brightness.light, strength: condense) for each,
  // and is empty at condense 1 with background 0.5.
});
testWidgets('dark mode draws the deeper shadow and the rim', (tester) async {
  // theme: ThemeData(brightness: Brightness.dark, useMaterial3: true)
  // shadows == pinnedStripShadows(Brightness.dark, strength: 1)
  // outline(tester).side == pinnedStripEdge(brightness: dark,
  //   themeSide: BorderSide.none, surfaceOpacity: 1, strength: 1)
});
test('shadow is clipped at the strip top', () {
  final clip = PinnedStripShadowClip().getClip(const Size(400, 56));
  expect(clip.top, 0);
  expect(clip.bottom, greaterThan(56 + 12 + 28));
  expect(clip.left, lessThan(-28));
});
```

The existing `it takes its corners, outline and fill from the card theme` stays green unchanged (light theme with an outline: the outline wins).

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/pinned_profile/pinned_profile_strip_test.dart`
Expected: FAIL (no `DecoratedBox` shadows; `PinnedStripShadowClip` undefined).

- [ ] **Step 3: Implement**

In `build`: `strength = background >= 1 ? condense : 0`. Wrap the `Material` in `ClipRect(clipper: const PinnedStripShadowClip(), child: DecoratedBox(decoration: BoxDecoration(borderRadius: card.corners, boxShadow: pinnedStripShadows(theme.brightness, strength: strength)), child: Material(...)))`, keeping it inside `CompositedTransformTarget`. Set `elevation: 0` on the `Material` (drop the comment about growing elevation; move its point to the shadow). Pass `pinnedStripEdge(...)` as the outline painter's `side`. `PinnedStripShadowClip.shouldReclip` returns false.

- [ ] **Step 4: Run the pinned profile tests**

Run: `flutter test test/features/dive_log/presentation/widgets/pinned_profile/`
Expected: all PASS.

- [ ] **Step 5: Format, analyze, architecture guards**

Run: `dart format . && flutter analyze && flutter test test/architecture/`
Expected: no changes needed after format, "No issues found!", all PASS.

- [ ] **Step 6: Commit** `feat(dive-log): deeper shadow and dark rim under the pinned profile strip`
