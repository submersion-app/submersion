# Certification Wallet Card Photos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the certification wallet show a diver's uploaded card photo on the
front of the card, and rebuild the generated fallback card so it carries every
field a dive operator checks instead of a third of blank space.

**Architecture:** `certification_ecard.dart` splits into four focused widget
files. A new shared `CertificationCardPhoto` renders photographed cards as a
contained image over a blurred copy of itself, so nothing is cropped and nothing
is letterboxed against flat bars. Both card faces use it. The generated front
face replaces its two `Spacer()` widgets with a header / hero / field-grid column
whose empty cells collapse.

**Tech Stack:** Flutter 3.x, Material 3, `intl` for date formatting, ARB-based
localisation across 11 locales, `flutter_test` for widget tests.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-09-certification-wallet-card-photos-design.md`
- No emojis in code, comments, or documentation.
- All Dart must pass `dart format .` with no changes.
- `flutter analyze` must report no new issues. Infos are fatal in CI.
- Every user-visible string goes through `context.l10n`. New ARB keys must be
  added to all 11 locales: `en, ar, de, es, fr, he, hu, it, nl, pt, zh`.
- ARB files are sorted by key in ASCII order. Insert new keys in sorted position.
- Files stay in the 200-400 line range; 800 is the hard maximum.
- The public API of `CertificationEcard` must not change, so
  `certification_ecard_stack.dart` and `certification_wallet_page.dart` need no
  edits.
- Widget tests that assert English labels must pin `locale: const Locale('en')`.
- Run all commands from the worktree root, `<repo>/.claude/worktrees/cert-wallet-card-photos`.
  Pass paths rooted at that worktree to Read/Edit/Write; an absolute path rooted
  at the main checkout silently edits the wrong tree, so tests keep passing
  against files you did not change.

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/certifications/presentation/widgets/certification_card_photo.dart` | New. Blurred-backdrop contain treatment for a photographed card, plus optional badge and info strip. |
| `lib/features/certifications/presentation/widgets/certification_ecard_back.dart` | New. Back face: uploaded photo or generated magstripe design. |
| `lib/features/certifications/presentation/widgets/certification_ecard_front.dart` | New. Front face: uploaded photo or generated field-grid card. Owns the status badge and the wave-pattern painter. |
| `lib/features/certifications/presentation/widgets/certification_ecard.dart` | Modified. Keeps only the public widget: aspect ratio, semantics, gestures, flip. |
| `lib/l10n/arb/app_*.arb` | Modified. Three new label keys in all 11 locales. |
| `test/features/certifications/presentation/widgets/certification_card_photo_test.dart` | New. |
| `test/features/certifications/presentation/widgets/certification_ecard_test.dart` | New. |

---

### Task 1: CertificationCardPhoto

The shared photo treatment. Nothing else depends on it yet, so it is built and
tested standalone first.

**Files:**
- Create: `lib/features/certifications/presentation/widgets/certification_card_photo.dart`
- Test: `test/features/certifications/presentation/widgets/certification_card_photo_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `class CertificationCardPhoto extends StatelessWidget` with named
  constructor parameters `{Key? key, required Uint8List bytes, Widget? badge,
  List<String> infoLines = const []}` and static `const double borderRadius = 16`.
  Tasks 2, 3 and 4 construct it.

- [ ] **Step 1: Write the failing test**

Create `test/features/certifications/presentation/widgets/certification_card_photo_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_card_photo.dart';

import '../../../../helpers/l10n_test_helpers.dart';

/// A valid 1x1 transparent PNG, so the image decoder has real bytes.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

Future<void> _pumpPhoto(
  WidgetTester tester, {
  Widget? badge,
  List<String> infoLines = const [],
}) async {
  await tester.pumpWidget(
    localizedMaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 202,
            child: CertificationCardPhoto(
              bytes: _onePixelPng,
              badge: badge,
              infoLines: infoLines,
            ),
          ),
        ),
      ),
    ),
  );
  // pump(), not pumpAndSettle(): these assertions only inspect the widget tree,
  // and image decoding is asynchronous work we do not need to await.
  await tester.pump();
}

void main() {
  group('CertificationCardPhoto', () {
    testWidgets('renders a blurred cover backdrop under a contained photo', (
      tester,
    ) async {
      await _pumpPhoto(tester);

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(2));
      expect(images[0].fit, BoxFit.cover);
      expect(images[1].fit, BoxFit.contain);
      expect(find.byType(ImageFiltered), findsOneWidget);
    });

    testWidgets('omits the info strip when no lines are given', (tester) async {
      await _pumpPhoto(tester);

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders each info line in the strip', (tester) async {
      await _pumpPhoto(
        tester,
        infoLines: const ['PADI  -  Open Water Diver', 'ERIC GRIFFIN'],
      );

      expect(find.text('PADI  -  Open Water Diver'), findsOneWidget);
      expect(find.text('ERIC GRIFFIN'), findsOneWidget);
    });

    testWidgets('renders the badge when one is supplied', (tester) async {
      await _pumpPhoto(
        tester,
        badge: const Text('EXPIRED', key: Key('test-badge')),
      );

      expect(find.byKey(const Key('test-badge')), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/certifications/presentation/widgets/certification_card_photo_test.dart`

Expected: FAIL at compile time, `Error: Couldn't resolve the package import` or
`Type 'CertificationCardPhoto' not found`, because the widget does not exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/features/certifications/presentation/widgets/certification_card_photo.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Renders a photographed certification card so the whole image stays visible.
///
/// The photo is contained rather than cropped, and a blurred, dimmed copy of
/// the same bytes fills whatever space the photo does not cover. That avoids
/// both losing the edges of a card to a cover crop and letterboxing it against
/// flat bars.
class CertificationCardPhoto extends StatelessWidget {
  /// Encoded image bytes for the photographed card.
  final Uint8List bytes;

  /// Optional widget pinned to the top-right corner, used for expiry status.
  final Widget? badge;

  /// Lines rendered in the scrim along the bottom edge, first line emphasised.
  ///
  /// An empty list suppresses the strip entirely.
  final List<String> infoLines;

  /// Corner radius, matched to the generated card faces.
  static const double borderRadius = 16;

  /// Decode width for the blurred backdrop. Deliberately tiny: decoding small
  /// is cheaper than blurring a full-resolution image, and it yields a smoother
  /// result.
  static const int backdropCacheWidth = 64;

  /// Upper bound on the foreground decode width, so an oversized source image
  /// cannot blow past a sensible texture size.
  static const int maxPhotoCacheWidth = 4096;

  const CertificationCardPhoto({
    super.key,
    required this.bytes,
    this.badge,
    this.infoLines = const [],
  });

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // An unbounded width makes the decode size meaningless, so fall back
          // to the image's native resolution in that case.
          final photoCacheWidth = width.isFinite
              ? (width * devicePixelRatio).round().clamp(1, maxPhotoCacheWidth)
              : null;

          return Stack(
            fit: StackFit.expand,
            children: [
              _buildBackdrop(),
              Image.memory(
                bytes,
                fit: BoxFit.contain,
                cacheWidth: photoCacheWidth,
              ),
              if (infoLines.isNotEmpty) _buildInfoStrip(),
              if (badge != null) Positioned(top: 12, right: 12, child: badge!),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackdrop() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            cacheWidth: backdropCacheWidth,
          ),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
      ],
    );
  }

  Widget _buildInfoStrip() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < infoLines.length; i++) ...[
              if (i > 0) const SizedBox(height: 2),
              Text(
                infoLines[i],
                style: TextStyle(
                  color: i == 0
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.85),
                  fontSize: i == 0 ? 15 : 12,
                  fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: i == 0 ? 0.3 : 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/certifications/presentation/widgets/certification_card_photo_test.dart`

Expected: PASS, 4 tests.

- [ ] **Step 5: Format and analyze**

```bash
dart format .
flutter analyze
```

Expected: `flutter analyze` reports "No issues found!". Re-running `dart format .`
reports 0 changed files.

- [ ] **Step 6: Commit**

```bash
git add lib/features/certifications/presentation/widgets/certification_card_photo.dart \
        test/features/certifications/presentation/widgets/certification_card_photo_test.dart
git commit -m "Add CertificationCardPhoto blurred-backdrop card photo widget"
```

---

### Task 2: Move the back face into its own file and give it the photo treatment

Extracts `_CardBack` from `certification_ecard.dart` and switches its photo
branch from a bare `BoxFit.cover` to `CertificationCardPhoto`. The generated
magstripe design moves verbatim.

**Files:**
- Create: `lib/features/certifications/presentation/widgets/certification_ecard_back.dart`
- Modify: `lib/features/certifications/presentation/widgets/certification_ecard.dart` (delete `_CardBack`, currently lines 291-400; update the `AnimatedSwitcher` child at lines 62-66)
- Test: `test/features/certifications/presentation/widgets/certification_ecard_test.dart`

**Interfaces:**
- Consumes: `CertificationCardPhoto({required Uint8List bytes, Widget? badge, List<String> infoLines})` from Task 1.
- Produces: `class CertificationEcardBack extends StatelessWidget` with
  `{Key? key, required Certification certification}`. Task 3 leaves it untouched.

- [ ] **Step 1: Write the failing test**

Create `test/features/certifications/presentation/widgets/certification_ecard_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_card_photo.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard.dart';

import '../../../../helpers/l10n_test_helpers.dart';

/// A valid 1x1 transparent PNG, so the image decoder has real bytes.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

final _now = DateTime(2026, 8, 9);

Certification _makeCert({
  String name = 'Open Water Diver',
  CertificationAgency agency = CertificationAgency.padi,
  String? cardNumber,
  DateTime? issueDate,
  DateTime? expiryDate,
  String? instructorName,
  Uint8List? photoFront,
  Uint8List? photoBack,
}) {
  return Certification(
    id: 'cert-1',
    name: name,
    agency: agency,
    cardNumber: cardNumber,
    issueDate: issueDate,
    expiryDate: expiryDate,
    instructorName: instructorName,
    photoFront: photoFront,
    photoBack: photoBack,
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required Certification certification,
  String diverName = 'Eric Griffin',
  bool showBack = false,
}) async {
  await tester.pumpWidget(
    localizedMaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: CertificationEcard(
              certification: certification,
              diverName: diverName,
              showBack: showBack,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('CertificationEcard back face', () {
    testWidgets('renders the uploaded photo when photoBack is set', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        certification: _makeCert(photoBack: _onePixelPng),
        showBack: true,
      );

      expect(find.byType(CertificationCardPhoto), findsOneWidget);
    });

    testWidgets('renders the generated back when photoBack is null', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        certification: _makeCert(instructorName: 'Jane Doe'),
        showBack: true,
      );

      expect(find.byType(CertificationCardPhoto), findsNothing);
      expect(find.text('INSTRUCTOR'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/certifications/presentation/widgets/certification_ecard_test.dart`

Expected: the first test FAILS with
`Expected: exactly one matching candidate / Actual: _TypeWidgetFinder:<zero widgets with type "CertificationCardPhoto">`,
because `_CardBack` still uses a bare `Image.memory`. The second test passes.

- [ ] **Step 3: Create the back-face file**

Create `lib/features/certifications/presentation/widgets/certification_ecard_back.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_card_photo.dart';

/// The back face of the certification card.
///
/// Shows the uploaded rear photo when the diver captured one, otherwise a
/// generated design carrying the instructor details.
class CertificationEcardBack extends StatelessWidget {
  /// The certification to display.
  final Certification certification;

  const CertificationEcardBack({super.key, required this.certification});

  @override
  Widget build(BuildContext context) {
    final photo = certification.photoBack;
    if (photo != null) {
      return CertificationCardPhoto(bytes: photo);
    }
    return _buildGeneratedBack(context);
  }

  Widget _buildGeneratedBack(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          CertificationCardPhoto.borderRadius,
        ),
        color: const Color(0xFFE0E0E0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Magnetic stripe
          const SizedBox(height: 24),
          Container(height: 40, color: const Color(0xFF424242)),
          const SizedBox(height: 16),
          // Card content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instructor info
                  if (certification.instructorName != null &&
                      certification.instructorName!.isNotEmpty) ...[
                    Text(
                      context.l10n.certifications_ecard_label_instructor,
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      certification.instructorName!,
                      style: const TextStyle(
                        color: Color(0xFF424242),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (certification.instructorNumber != null &&
                      certification.instructorNumber!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '#${certification.instructorNumber}',
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Certified by agency
                  Center(
                    child: Text(
                      context.l10n.certifications_ecard_label_certifiedBy(
                        certification.agency.displayName,
                      ),
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Delete `_CardBack` from `certification_ecard.dart` and wire the new widget**

In `lib/features/certifications/presentation/widgets/certification_ecard.dart`:

Delete the entire `class _CardBack extends StatelessWidget { ... }` block, from
the `/// The back face of the certification card.` doc comment through its
closing brace.

Add this import alongside the existing ones:

```dart
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard_back.dart';
```

Replace the `showBack` branch of the `AnimatedSwitcher` child:

```dart
            child: showBack
                ? CertificationEcardBack(
                    key: const ValueKey('back'),
                    certification: certification,
                  )
                : _CardFront(
                    key: const ValueKey('front'),
                    certification: certification,
                    diverName: diverName,
                  ),
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/certifications/presentation/widgets/certification_ecard_test.dart`

Expected: PASS, 2 tests.

- [ ] **Step 6: Run the whole certification suite for regressions**

Run: `flutter test test/features/certifications/`

Expected: PASS. The count rises from the 167 baseline to 173 (4 from Task 1,
2 from this task).

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/certifications/presentation/widgets/certification_ecard.dart \
        lib/features/certifications/presentation/widgets/certification_ecard_back.dart \
        test/features/certifications/presentation/widgets/certification_ecard_test.dart
git commit -m "Extract certification e-card back face and stop cropping its photo"
```

---

### Task 3: Move the front face into its own file and render photoFront

Extracts `_CardFront` and `_WavePatternPainter`, then adds the missing photo
branch. The generated layout is carried over unchanged here; Task 4 rebuilds it.

**Files:**
- Create: `lib/features/certifications/presentation/widgets/certification_ecard_front.dart`
- Modify: `lib/features/certifications/presentation/widgets/certification_ecard.dart` (delete `_CardFront` and `_WavePatternPainter`; update the `AnimatedSwitcher` child)
- Test: `test/features/certifications/presentation/widgets/certification_ecard_test.dart` (add a group)

**Interfaces:**
- Consumes: `CertificationCardPhoto({required Uint8List bytes, Widget? badge, List<String> infoLines})` from Task 1.
- Produces: `class CertificationEcardFront extends StatelessWidget` with
  `{Key? key, required Certification certification, required String diverName}`,
  plus the private members `Widget? _buildStatusBadge(BuildContext)` and
  `Widget _buildGeneratedFront(BuildContext)`. Task 4 rewrites
  `_buildGeneratedFront` and reuses `_buildStatusBadge`.

- [ ] **Step 1: Write the failing test**

Append this group inside `main()` in
`test/features/certifications/presentation/widgets/certification_ecard_test.dart`,
after the existing `CertificationEcard back face` group:

```dart
  group('CertificationEcard front face', () {
    testWidgets('renders the uploaded photo when photoFront is set', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        certification: _makeCert(photoFront: _onePixelPng),
      );

      expect(find.byType(CertificationCardPhoto), findsOneWidget);
    });

    testWidgets('photo card repeats agency, name and diver in the strip', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        certification: _makeCert(
          photoFront: _onePixelPng,
          cardNumber: '1802G4921',
        ),
      );

      expect(find.textContaining('PADI'), findsOneWidget);
      expect(find.textContaining('Open Water Diver'), findsOneWidget);
      expect(find.textContaining('ERIC GRIFFIN'), findsOneWidget);
      expect(find.textContaining('1802G4921'), findsOneWidget);
    });

    testWidgets('photo card strip omits a missing card number', (tester) async {
      await _pumpCard(
        tester,
        certification: _makeCert(photoFront: _onePixelPng),
      );

      expect(find.textContaining('ERIC GRIFFIN'), findsOneWidget);
      // The detail line is the diver name alone, with no trailing separator.
      expect(find.text('ERIC GRIFFIN'), findsOneWidget);
    });

    testWidgets('photo card still shows the expired badge', (tester) async {
      await _pumpCard(
        tester,
        certification: _makeCert(
          photoFront: _onePixelPng,
          expiryDate: DateTime(2020, 1, 1),
        ),
      );

      expect(find.text('EXPIRED'), findsOneWidget);
    });

    testWidgets('renders the generated front when photoFront is null', (
      tester,
    ) async {
      await _pumpCard(tester, certification: _makeCert());

      expect(find.byType(CertificationCardPhoto), findsNothing);
      expect(find.text('Open Water Diver'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/certifications/presentation/widgets/certification_ecard_test.dart`

Expected: the three photo tests FAIL, the first reporting
`zero widgets with type "CertificationCardPhoto"`, because `_CardFront` never
looks at `photoFront`. The fourth test passes.

- [ ] **Step 3: Create the front-face file**

Create `lib/features/certifications/presentation/widgets/certification_ecard_front.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_card_photo.dart';

/// The front face of the certification card.
///
/// Shows the uploaded front photo when the diver captured one, otherwise a
/// generated card in the issuing agency's colours.
class CertificationEcardFront extends StatelessWidget {
  /// The certification to display.
  final Certification certification;

  /// The name of the diver holding this certification.
  final String diverName;

  const CertificationEcardFront({
    super.key,
    required this.certification,
    required this.diverName,
  });

  @override
  Widget build(BuildContext context) {
    final photo = certification.photoFront;
    if (photo != null) {
      return CertificationCardPhoto(
        bytes: photo,
        badge: _buildStatusBadge(context),
        infoLines: _buildInfoLines(),
      );
    }
    return _buildGeneratedFront(context);
  }

  /// Lines repeated over a photographed card.
  ///
  /// The scrim covers the part of a physical card that prints the holder's name
  /// and number, so repeating them here loses nothing and keeps the text legible
  /// when the photo is dim or blurry.
  List<String> _buildInfoLines() {
    final cardNumber = certification.cardNumber;

    final headline = [
      certification.agency.displayName,
      certification.name,
    ].where((value) => value.isNotEmpty).join('  -  ');

    final detail = [
      diverName.toUpperCase(),
      if (cardNumber != null && cardNumber.isNotEmpty) cardNumber,
    ].where((value) => value.isNotEmpty).join('  -  ');

    return [
      if (headline.isNotEmpty) headline,
      if (detail.isNotEmpty) detail,
    ];
  }

  Widget _buildGeneratedFront(BuildContext context) {
    final agency = certification.agency;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          CertificationCardPhoto.borderRadius,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [agency.primaryColor, agency.secondaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: agency.primaryColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative wave pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _WavePatternPainter(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Card content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: agency name and status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        agency.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    _buildStatusBadge(context) ?? const SizedBox.shrink(),
                  ],
                ),
                const Spacer(),
                // Center: certification name
                Text(
                  certification.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Level display if present
                if (certification.level != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    certification.level!.displayName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                const Spacer(),
                // Bottom row: diver info and issue date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            diverName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (certification.cardNumber != null &&
                              certification.cardNumber!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              certification.cardNumber!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                letterSpacing: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (certification.issueDate != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l10n.certifications_ecard_label_issued,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MM/yy').format(certification.issueDate!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The expiry status chip, or null when the certification is current.
  ///
  /// Returns null rather than an empty box so the photo branch can decide
  /// whether to position anything at all.
  Widget? _buildStatusBadge(BuildContext context) {
    if (certification.isExpired) {
      return _badge(
        context.l10n.certifications_ecard_statusBadge_expired,
        Colors.red,
      );
    }

    if (certification.expiresWithin(90)) {
      return _badge(
        context.l10n.certifications_ecard_statusBadge_expiring,
        Colors.orange,
      );
    }

    return null;
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Custom painter for decorative wave pattern on the card.
class _WavePatternPainter extends CustomPainter {
  final Color color;

  _WavePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw decorative circles at various positions
    final circles = [
      (Offset(size.width * 0.85, size.height * 0.2), size.width * 0.25),
      (Offset(size.width * 0.95, size.height * 0.6), size.width * 0.18),
      (Offset(size.width * 0.1, size.height * 0.9), size.width * 0.15),
      (Offset(size.width * 0.75, size.height * 0.85), size.width * 0.12),
    ];

    for (final (offset, radius) in circles) {
      canvas.drawCircle(offset, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
```

- [ ] **Step 4: Strip `certification_ecard.dart` down to the public widget**

Replace the entire contents of
`lib/features/certifications/presentation/widgets/certification_ecard.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard_back.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard_front.dart';

/// A credit card-style widget displaying a certification with agency branding.
///
/// Supports both front and back views with an animated flip transition. Each
/// face shows the diver's uploaded photo of that side when one exists, and a
/// generated design otherwise.
class CertificationEcard extends StatelessWidget {
  /// The certification to display.
  final Certification certification;

  /// The name of the diver holding this certification.
  final String diverName;

  /// Whether to show the back of the card (default: false).
  final bool showBack;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Callback when the card is long-pressed.
  final VoidCallback? onLongPress;

  /// Standard credit card aspect ratio (CR80 format).
  static const double aspectRatio = 1.586;

  const CertificationEcard({
    super.key,
    required this.certification,
    required this.diverName,
    this.showBack = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final issueDateStr = certification.issueDate != null
        ? ', issued ${DateFormat('MM/yy').format(certification.issueDate!)}'
        : '';
    final statusStr = certification.isExpired
        ? ', Expired'
        : certification.expiresWithin(90)
        ? ', Expiring soon'
        : '';

    return Semantics(
      label:
          '${certification.agency.displayName} ${certification.name} certification for $diverName$issueDateStr$statusStr. ${showBack ? 'Showing back' : 'Showing front'}. Tap to flip',
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: showBack
                ? CertificationEcardBack(
                    key: const ValueKey('back'),
                    certification: certification,
                  )
                : CertificationEcardFront(
                    key: const ValueKey('front'),
                    certification: certification,
                    diverName: diverName,
                  ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/certifications/presentation/widgets/certification_ecard_test.dart`

Expected: PASS, 7 tests.

- [ ] **Step 6: Run the whole certification suite for regressions**

Run: `flutter test test/features/certifications/`

Expected: PASS, 178 tests (167 baseline + 4 from Task 1 + 7 in this file).

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/certifications/presentation/widgets/certification_ecard.dart \
        lib/features/certifications/presentation/widgets/certification_ecard_front.dart \
        test/features/certifications/presentation/widgets/certification_ecard_test.dart
git commit -m "Show the uploaded front photo on certification wallet cards"
```

---

### Task 4: Rebuild the generated front as a labelled field grid

Replaces the two `Spacer()` widgets that leave the card's middle third blank, and
surfaces the expiry date, which never appeared on the front before. Adds the
three ARB keys the grid labels need.

**Files:**
- Modify: `lib/features/certifications/presentation/widgets/certification_ecard_front.dart` (`_buildGeneratedFront`, plus new helpers and a private value type)
- Modify: `lib/l10n/arb/app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Test: `test/features/certifications/presentation/widgets/certification_ecard_test.dart` (add a group)

**Interfaces:**
- Consumes: `CertificationEcardFront({required Certification certification, required String diverName})` and its private `_buildStatusBadge(BuildContext)` from Task 3.
- Produces: nothing for later tasks; this is the final task.

- [ ] **Step 1: Add the ARB keys to the English template**

In `lib/l10n/arb/app_en.arb`, insert three keys in ASCII-sorted position. They
land around the existing `certifications_ecard_label_*` block, which afterwards
reads:

```json
  "certifications_ecard_label_cardNumber": "CARD NO.",
  "certifications_ecard_label_certifiedBy": "Certified by {agency}",
  "certifications_ecard_label_diver": "DIVER",
  "certifications_ecard_label_instructor": "INSTRUCTOR",
  "certifications_ecard_label_issued": "ISSUED",
  "certifications_ecard_label_validUntil": "VALID UNTIL",
```

Then add matching `@` metadata entries in sorted position among the other
`@certifications_ecard_*` entries:

```json
  "@certifications_ecard_label_cardNumber": {
    "description": "Uppercase field label above the certification card number on the generated wallet card"
  },
  "@certifications_ecard_label_diver": {
    "description": "Uppercase field label above the diver's name on the generated wallet card"
  },
  "@certifications_ecard_label_validUntil": {
    "description": "Uppercase field label above the certification expiry date on the generated wallet card"
  },
```

- [ ] **Step 2: Add the translations to the other ten locales**

Insert the same three keys, in sorted position, into each remaining ARB file.
Only the ten non-English files get values; `@` metadata lives in the template
alone.

`app_ar.arb`:
```json
  "certifications_ecard_label_cardNumber": "رقم البطاقة",
  "certifications_ecard_label_diver": "الغواص",
  "certifications_ecard_label_validUntil": "صالحة حتى",
```

`app_de.arb`:
```json
  "certifications_ecard_label_cardNumber": "KARTEN-NR.",
  "certifications_ecard_label_diver": "TAUCHER",
  "certifications_ecard_label_validUntil": "GÜLTIG BIS",
```

`app_es.arb`:
```json
  "certifications_ecard_label_cardNumber": "N.º DE TARJETA",
  "certifications_ecard_label_diver": "BUCEADOR",
  "certifications_ecard_label_validUntil": "VÁLIDA HASTA",
```

`app_fr.arb`:
```json
  "certifications_ecard_label_cardNumber": "N° DE CARTE",
  "certifications_ecard_label_diver": "PLONGEUR",
  "certifications_ecard_label_validUntil": "VALABLE JUSQU'AU",
```

`app_he.arb`:
```json
  "certifications_ecard_label_cardNumber": "מספר כרטיס",
  "certifications_ecard_label_diver": "צוללן",
  "certifications_ecard_label_validUntil": "בתוקף עד",
```

`app_hu.arb`:
```json
  "certifications_ecard_label_cardNumber": "KÁRTYASZÁM",
  "certifications_ecard_label_diver": "BÚVÁR",
  "certifications_ecard_label_validUntil": "LEJÁRAT",
```

`app_it.arb`:
```json
  "certifications_ecard_label_cardNumber": "N. TESSERA",
  "certifications_ecard_label_diver": "SUBACQUEO",
  "certifications_ecard_label_validUntil": "VALIDA FINO AL",
```

`app_nl.arb`:
```json
  "certifications_ecard_label_cardNumber": "KAARTNR.",
  "certifications_ecard_label_diver": "DUIKER",
  "certifications_ecard_label_validUntil": "GELDIG TOT",
```

`app_pt.arb`:
```json
  "certifications_ecard_label_cardNumber": "N.º DO CARTÃO",
  "certifications_ecard_label_diver": "MERGULHADOR",
  "certifications_ecard_label_validUntil": "VÁLIDA ATÉ",
```

`app_zh.arb`:
```json
  "certifications_ecard_label_cardNumber": "卡号",
  "certifications_ecard_label_diver": "潜水员",
  "certifications_ecard_label_validUntil": "有效期至",
```

Arabic, Hebrew and Chinese have no letter case, so those values are written in
their normal form rather than uppercased. Hungarian uses "LEJÁRAT" (expiry)
rather than a literal rendering of "valid until", which is the idiomatic label on
a Hungarian card.

- [ ] **Step 3: Regenerate the localisation classes**

Run: `flutter gen-l10n`

Expected: regenerates `lib/l10n/arb/app_localizations*.dart` with three new
getters. Verify:

```bash
grep -c "certifications_ecard_label_validUntil" lib/l10n/arb/app_localizations_en.dart
```

Expected: at least `1`.

- [ ] **Step 4: Write the failing test**

Append this group inside `main()` in
`test/features/certifications/presentation/widgets/certification_ecard_test.dart`:

```dart
  group('CertificationEcard generated front field grid', () {
    testWidgets('shows labelled diver, card number, issue and expiry cells', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        certification: _makeCert(
          cardNumber: '1802G4921',
          issueDate: DateTime(2018, 3, 14),
          expiryDate: DateTime(2030, 3, 14),
        ),
      );

      expect(find.text('DIVER'), findsOneWidget);
      expect(find.text('ERIC GRIFFIN'), findsOneWidget);
      expect(find.text('CARD NO.'), findsOneWidget);
      expect(find.text('1802G4921'), findsOneWidget);
      expect(find.text('ISSUED'), findsOneWidget);
      expect(find.text('VALID UNTIL'), findsOneWidget);
    });

    testWidgets('omits the expiry cell when the certification never expires', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        certification: _makeCert(issueDate: DateTime(2018, 3, 14)),
      );

      expect(find.text('ISSUED'), findsOneWidget);
      expect(find.text('VALID UNTIL'), findsNothing);
    });

    testWidgets('omits the card number cell when the card number is empty', (
      tester,
    ) async {
      await _pumpCard(tester, certification: _makeCert(cardNumber: ''));

      expect(find.text('DIVER'), findsOneWidget);
      expect(find.text('CARD NO.'), findsNothing);
    });

    testWidgets('omits the card number cell when the card number is null', (
      tester,
    ) async {
      await _pumpCard(tester, certification: _makeCert());

      expect(find.text('DIVER'), findsOneWidget);
      expect(find.text('CARD NO.'), findsNothing);
    });

    testWidgets('renders no Spacer, so the card centre is not left blank', (
      tester,
    ) async {
      await _pumpCard(tester, certification: _makeCert());

      expect(find.byType(Spacer), findsNothing);
    });
  });
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `flutter test test/features/certifications/presentation/widgets/certification_ecard_test.dart`

Expected: the field-grid tests FAIL. The first reports zero widgets for
`find.text('DIVER')`; the last reports `Found 2 widgets` for `find.byType(Spacer)`.

- [ ] **Step 6: Rebuild `_buildGeneratedFront`**

In `lib/features/certifications/presentation/widgets/certification_ecard_front.dart`,
replace the `Padding` child of the `Stack` (the whole `Column` currently holding
the header row, two `Spacer()`s, the name and the bottom row) with three blocks:

```dart
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeader(context),
                _buildHero(),
                _buildFieldGrid(context),
              ],
            ),
          ),
```

`MainAxisAlignment.spaceBetween` distributes the three blocks across the card, so
the dead centre disappears without any `Spacer`.

Add these methods to `CertificationEcardFront`:

```dart
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            certification.agency.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        _buildStatusBadge(context) ?? const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          certification.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (certification.level != null) ...[
          const SizedBox(height: 4),
          Text(
            certification.level!.displayName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  /// The labelled facts a dive operator checks at check-in.
  ///
  /// Cells with no value are dropped rather than rendered blank, and the
  /// remaining cells reflow two per row, so a bare certification produces a
  /// tighter card instead of a grid of holes.
  Widget _buildFieldGrid(BuildContext context) {
    final cells = _buildFieldCells(context);
    if (cells.isEmpty) return const SizedBox.shrink();

    final rows = <List<_CardField>>[];
    for (var i = 0; i < cells.length; i += 2) {
      rows.add(cells.sublist(i, (i + 2).clamp(0, cells.length)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white.withValues(alpha: 0.25),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final cell in rows[i]) Expanded(child: _buildFieldCell(cell)),
              // Keep a lone cell in the left column instead of stretching it.
              if (rows[i].length == 1) const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      ],
    );
  }

  List<_CardField> _buildFieldCells(BuildContext context) {
    final l10n = context.l10n;
    final dateFormat = DateFormat.yMMM();
    final cardNumber = certification.cardNumber;

    return [
      if (diverName.trim().isNotEmpty)
        _CardField(
          label: l10n.certifications_ecard_label_diver,
          value: diverName.toUpperCase(),
        ),
      if (cardNumber != null && cardNumber.isNotEmpty)
        _CardField(
          label: l10n.certifications_ecard_label_cardNumber,
          value: cardNumber,
        ),
      if (certification.issueDate != null)
        _CardField(
          label: l10n.certifications_ecard_label_issued,
          value: dateFormat.format(certification.issueDate!),
        ),
      if (certification.expiryDate != null)
        _CardField(
          label: l10n.certifications_ecard_label_validUntil,
          value: dateFormat.format(certification.expiryDate!),
          valueColor: _expiryColor(),
        ),
    ];
  }

  /// Tints the expiry value to match the status badge.
  ///
  /// These are the badge's literal colours rather than [ColorScheme] roles,
  /// because the card sits on an agency gradient, not on a theme surface. The
  /// lighter shades keep the text legible against a dark gradient.
  Color _expiryColor() {
    if (certification.isExpired) return Colors.red.shade200;
    if (certification.expiresWithin(90)) return Colors.orange.shade200;
    return Colors.white;
  }

  Widget _buildFieldCell(_CardField field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          field.label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          field.value,
          style: TextStyle(
            color: field.valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
```

Add this value type at the bottom of the file, above `_WavePatternPainter`:

```dart
/// One labelled fact on the generated card front.
class _CardField {
  final String label;
  final String value;
  final Color valueColor;

  const _CardField({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/certifications/presentation/widgets/certification_ecard_test.dart`

Expected: PASS, 12 tests.

- [ ] **Step 8: Run the whole certification suite for regressions**

Run: `flutter test test/features/certifications/`

Expected: PASS, 183 tests.

- [ ] **Step 9: Format, analyze, and run the full suite**

```bash
dart format .
flutter analyze
flutter test
```

Expected: `flutter analyze` reports "No issues found!"; the full suite passes. If
a known-flaky suite fails (backup, media-upload drain, OCR scan), re-run that
file individually to confirm it is unrelated to this change, and say so
explicitly rather than treating it as passing.

- [ ] **Step 10: Commit**

```bash
git add lib/features/certifications/presentation/widgets/certification_ecard_front.dart \
        lib/l10n/arb/ \
        test/features/certifications/presentation/widgets/certification_ecard_test.dart
git commit -m "Rebuild the generated certification card as a labelled field grid"
```

---

## Verification

After Task 4, confirm against the spec:

- The wallet shows the uploaded front photo. Manual check: `flutter run -d macos`,
  add a certification with a front photo, open `/certifications/wallet`.
- The photo is contained, not cropped, with a blurred backdrop filling the rest.
- The badge and info strip render over the photo.
- Flipping shows the back photo with the same treatment.
- A certification with no photo shows the field grid with no blank middle band.
- A certification with an expiry date shows `VALID UNTIL`, tinted when expiring
  or expired.
