import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';
import 'package:submersion/features/dive_log/presentation/providers/outlier_suggestion_provider.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// The profile's outliers, found from the Profile card beside Edit profile:
/// the same whole-record operation, opening the editor in Outlier mode
/// (issue #4527, plan 11). The entry the old edit form's chip gave.
void main() {
  // A steady 10 m, sampled every 4 s, with one 45 m spike: going down to it
  // and back up are faster than a diver can move, so two outliers.
  final spiked = List.generate(
    20,
    (i) => DiveProfilePoint(timestamp: i * 4, depth: i == 10 ? 45.0 : 10.0),
  );
  late Dive profiled;

  setUp(() async {
    await setUpTestDatabase();
    // The fixture must hold an outlier, or every test below passes vacuously.
    expect(ProfileEditingService().detectOutliers(spiked), isNotEmpty);
    profiled = dive.copyWith(
      profile: spiked,
      runtime: const Duration(seconds: 80),
      maxDepth: 45,
    );
    await DiveRepository().createDive(profiled);
  });
  tearDown(tearDownTestDatabase);

  const sections = {DiveDetailSectionId.profile, DiveDetailSectionId.notes};
  const size = Size(1000, 1600);

  Future<void> settleLong(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Finder outliers() => find.byIcon(Icons.warning_amber);

  IconButton outliersButton(WidgetTester tester) => tester.widget<IconButton>(
    find.ancestor(of: outliers(), matching: find.byType(IconButton)),
  );

  testWidgets('locked, the outliers button is shown and disabled', (
    tester,
  ) async {
    await pumpPage(tester, stored: profiled, visible: sections, size: size);
    await settleLong(tester);

    expect(outliers(), findsOneWidget);
    expect(outliersButton(tester).onPressed, isNull);
    expect(outliersButton(tester).tooltip, 'Unlock to use this');
    expect(
      find.descendant(
        of: find.ancestor(of: outliers(), matching: find.byType(IconButton)),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('unlocked with nothing changed, it opens the editor in Outlier '
      'mode', (tester) async {
    await pumpPage(tester, stored: profiled, visible: sections, size: size);
    await settleLong(tester);
    await unlock(tester);
    await settleLong(tester);

    expect(outliersButton(tester).tooltip, '2 potential outliers detected');
    await tester.tap(outliers());
    await settleLong(tester);

    expect(find.text('PROFILE EDITOR outlier'), findsOneWidget);
  });

  testWidgets('with unsaved changes it is disabled', (tester) async {
    await pumpPage(tester, stored: profiled, visible: sections, size: size);
    await settleLong(tester);
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(find.byType(TextField).last, 'Changed');
    await settleLong(tester);

    expect(outliersButton(tester).onPressed, isNull);
    expect(outliersButton(tester).tooltip, 'Save or cancel your changes first');
  });

  // The button joins a row of icons: at phone width the row must still fit
  // on screen, locked and with the card's pencil on unlock.
  testWidgets('at phone width the toolbar with the button fits the screen', (
    tester,
  ) async {
    await pumpPage(
      tester,
      stored: profiled,
      visible: sections,
      size: const Size(360, 1600),
    );
    await settleLong(tester);
    // Something else on the page overflows at 360 wide; it is not this row.
    tester.takeException();

    double right(IconData icon) =>
        tester.getRect(find.byIcon(icon).first).right;
    expect(outliers(), findsOneWidget);
    expect(right(Icons.warning_amber), lessThanOrEqualTo(360));
    expect(right(Icons.fullscreen), lessThanOrEqualTo(360));

    await unlock(tester);
    await settleLong(tester);
    tester.takeException();
    expect(right(Icons.warning_amber), lessThanOrEqualTo(360));
    expect(right(Icons.fullscreen), lessThanOrEqualTo(360));
  });

  testWidgets('a profile of nine points shows no outliers button', (
    tester,
  ) async {
    final short = profiled.copyWith(profile: spiked.take(9).toList());
    await DiveRepository().updateDive(short);
    await pumpPage(tester, stored: short, visible: sections, size: size);
    await settleLong(tester);

    expect(outliers(), findsNothing);
  });

  testWidgets('while the outliers are being found nothing is shown', (
    tester,
  ) async {
    final never = Completer<List<OutlierResult>>();
    await pumpPage(
      tester,
      stored: profiled,
      visible: sections,
      size: size,
      extra: [
        outlierSuggestionProvider(
          profiled.id,
        ).overrideWith((_) => never.future),
      ],
    );
    await settleLong(tester);

    expect(outliers(), findsNothing);
  });
}
