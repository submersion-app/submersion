import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/dive_log/presentation/widgets/bulk_gear_actions.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';

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

/// The bulk equipment editor's header holds the title, Use Set, Sort and
/// Add (#2274). On a narrow phone, in the languages with the longest labels,
/// it must still lay out: the actions move under the title rather than
/// overflowing.
void main() {
  // Real glyph widths: the test font draws every character a full em wide,
  // about twice a real font, so a fit check needs a real face. Named for
  // this file alone, since the engine cannot unload a font and CI runs many
  // test files in one isolate.
  const family = 'BulkGearActionsTestFont';
  setUpAll(() async {
    final bytes = await File(
      p.join(_materialFontsDir(), 'Roboto-Regular.ttf'),
    ).readAsBytes();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  final labels = BulkMembershipLabels(
    onAll: (total) => 'on all $total',
    onSome: (count, total) => 'on $count of $total',
    adding: (total) => 'adding to all $total',
    removing: 'removing from all',
    empty: 'Nothing here yet',
    // The longest translation of the dive editor's Add.
    add: 'Hozzáadás',
  );

  // The editor at 320 wide is a 352-wide phone once the form's margins are
  // taken off. The title is the longest translation of "Equipment".
  Future<void> pumpHeader(
    WidgetTester tester,
    String code,
    double width,
  ) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: family),
        locale: Locale(code),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BulkMembershipEditor(
            title: 'Equipamentos',
            total: 4,
            labels: labels,
            items: const [BulkMembershipItem(id: 'a', label: 'Fins')],
            counts: const {'a': 4},
            onAdd: () {},
            onChanged: (_) {},
            secondaryAction: BulkGearActions(onUseSet: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final code in ['fr', 'hu', 'de', 'en']) {
    testWidgets('the gear header fits a narrow phone in $code', (tester) async {
      await pumpHeader(tester, code, 320);

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.sort), findsOneWidget);
    });
  }

  // With room to spare the header keeps its one line: the wrap only takes
  // effect when the actions would not fit.
  testWidgets('on a wide screen the actions share the title line', (
    tester,
  ) async {
    await pumpHeader(tester, 'fr', 800);

    final titleCentre = tester.getCenter(find.text('Equipamentos')).dy;
    expect(tester.getCenter(find.byIcon(Icons.sort)).dy, titleCentre);
    expect(tester.getCenter(find.byIcon(Icons.add)).dy, titleCentre);
  });
}
