import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import 'site_marine_life_section_harness.dart';

/// The SDK's bundled Roboto fonts: under FLUTTER_ROOT when it is set,
/// otherwise found by walking up from the test binary to the SDK root.
String _materialFontsDir() {
  String fontsUnder(String root) =>
      p.join(root, 'bin', 'cache', 'artifacts', 'material_fonts');
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) return fontsUnder(root);
  var dir = p.dirname(Platform.resolvedExecutable);
  while (p.dirname(dir) != dir) {
    if (Directory(fontsUnder(dir)).existsSync()) return fontsUnder(dir);
    dir = p.dirname(dir);
  }
  throw StateError('No Flutter SDK above ${Platform.resolvedExecutable}');
}

/// The Marine life card's category names at the diver's text size and with
/// the system's Bold Text on: never broken mid-word (issue #5128).
void main() {
  final l = AppLocalizationsEn();
  final invertebrate = SpeciesCategory.invertebrate.localizedName(l);

  // Regular and bold faces of one family, so bold text really is wider,
  // which the test font's square glyphs are not. The engine cannot unload a
  // font, so the family is named for this file alone. Read here: file reads
  // in a testWidgets body deadlock under its fake clock.
  const family = 'SiteMarineLifeCardRoboto';
  setUpAll(() async {
    final fonts = _materialFontsDir();
    Future<ByteData> font(String name) async => ByteData.sublistView(
      await File(p.join(fonts, '$name.ttf')).readAsBytes(),
    );
    await (FontLoader(family)
          ..addFont(font('Roboto-Regular'))
          ..addFont(font('Roboto-Medium'))
          ..addFont(font('Roboto-Bold')))
        .load();
  });

  testWidgets('at a large text size the names stack above their chips', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpCard(
      tester,
      spotted: [
        spottedSummary(
          'a',
          'Caribbean Reef Squid',
          SpeciesCategory.invertebrate,
        ),
        spottedSummary('b', 'Blue Tang', SpeciesCategory.fish),
      ],
      textScaler: const TextScaler.linear(2),
    );

    // Whole, not "Invertebrat" over "e" in a column too narrow for it.
    expect(isOneLine(tester, invertebrate), isTrue);
    final label = tester.getRect(find.text(invertebrate));
    final chip = chipRect(tester, 'Caribbean Reef Squid (1)');
    expect(label.bottom, lessThanOrEqualTo(chip.top));
    expect(label.left, chip.left);
    expect(tester.takeException(), isNull);
  });

  testWidgets('at the default size on a wide card they stay beside them', (
    tester,
  ) async {
    await pumpCard(
      tester,
      spotted: [
        spottedSummary(
          'a',
          'Caribbean Reef Squid',
          SpeciesCategory.invertebrate,
        ),
      ],
    );

    final label = tester.getRect(find.text(invertebrate));
    final chip = chipRect(tester, 'Caribbean Reef Squid (1)');
    expect(label.right, lessThanOrEqualTo(chip.left));
    expect(label.center.dy, closeTo(chip.center.dy, 4));
  });

  testWidgets('with Bold Text on, the widest name keeps to one line', (
    tester,
  ) async {
    await pumpCard(
      tester,
      spotted: [
        spottedSummary(
          'a',
          'Caribbean Reef Squid',
          SpeciesCategory.invertebrate,
        ),
      ],
      theme: ThemeData(fontFamily: family),
      boldText: true,
      // Large enough that the bold face's extra width outgrows the
      // rounding in the column, and still beside the chips on a wide card.
      textScaler: const TextScaler.linear(3),
    );

    expect(isOneLine(tester, invertebrate), isTrue);
    final label = tester.getRect(find.text(invertebrate));
    expect(
      label.right,
      lessThanOrEqualTo(chipRect(tester, 'Caribbean Reef Squid (1)').left),
    );
  });

  // Chip sizes its height from the label measured at the chip's whole
  // width, then lays it out beside the icon: a name between the two widths
  // wrapped onto a line the chip had no room for, and lost its count. At
  // the default size two lines fit the chip's least height, so it shows at
  // a larger text size.
  testWidgets('a name of any length keeps every line inside its chip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final names = [for (var n = 4; n <= 16; n++) 'S' * n];

    await pumpCard(
      tester,
      spotted: [
        for (final name in names)
          spottedSummary(name, name, SpeciesCategory.fish),
      ],
      textScaler: const TextScaler.linear(2),
    );
    final showAll = find.text(l.marineLife_speciesDetail_showAll(names.length));
    await tester.ensureVisible(showAll);
    await tester.tap(showAll);
    await tester.pumpAndSettle();

    for (final name in names) {
      // The label's box is clamped to the chip, so a lost line shows as text
      // needing more height at its width than the box it was given.
      final label = tester.renderObject<RenderParagraph>(
        find.text('$name (1)'),
      );
      expect(
        label.getMinIntrinsicHeight(label.size.width),
        lessThanOrEqualTo(label.size.height),
        reason: '$name (1) loses a line in its chip',
      );
    }
  });
}
