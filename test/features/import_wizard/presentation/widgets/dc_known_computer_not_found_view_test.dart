import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_known_computer_not_found_view.dart';

import '../../../../helpers/l10n_test_helpers.dart';

DiveComputer _computer() => DiveComputer(
  id: 'dc-1',
  name: 'My Petrel',
  manufacturer: 'Shearwater',
  model: 'Petrel 3',
  createdAt: DateTime(2026, 10, 26),
  updatedAt: DateTime(2026, 10, 26),
);

Widget _view({
  DcSearchProblem? problem,
  VoidCallback? onRetry,
  VoidCallback? onDone,
}) => localizedMaterialApp(
  home: Scaffold(
    body: DcKnownComputerNotFoundView(
      computer: _computer(),
      problem: problem,
      onRetry: onRetry ?? () {},
      onDone: onDone ?? () {},
    ),
  ),
);

void main() {
  // Issue #3710: what the download step shows when a search by make and
  // model for a computer saved on another device finds no single match.
  group('DcKnownComputerNotFoundView', () {
    testWidgets('says the computer was not found nearby', (tester) async {
      await tester.pumpWidget(_view());
      await tester.pumpAndSettle();

      expect(find.text("Couldn't find My Petrel"), findsOneWidget);
      expect(find.textContaining('found no My Petrel nearby'), findsOneWidget);
    });

    testWidgets('Bluetooth off says so, and names only this screen\'s button', (
      tester,
    ) async {
      await tester.pumpWidget(_view(problem: DcSearchProblem.bluetoothOff));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bluetooth is off'), findsOneWidget);
      expect(find.textContaining('nearby'), findsNothing);
      expect(find.textContaining('USB Cable'), findsNothing);
      expect(find.textContaining('tap Try Again'), findsOneWidget);
    });

    testWidgets('a scan that could not start says so in the diver\'s '
        'language, not the scanner\'s raw error', (tester) async {
      await tester.pumpWidget(_view(problem: DcSearchProblem.couldNotScan));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('could not search over Bluetooth'),
        findsOneWidget,
      );
      expect(find.textContaining('nearby'), findsNothing);
    });

    testWidgets('Try Again and Done call back', (tester) async {
      var retries = 0;
      var dones = 0;
      await tester.pumpWidget(
        _view(onRetry: () => retries++, onDone: () => dones++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Try Again'));
      await tester.tap(find.text('Done'));
      expect(retries, 1);
      expect(dones, 1);
    });
  });
}
