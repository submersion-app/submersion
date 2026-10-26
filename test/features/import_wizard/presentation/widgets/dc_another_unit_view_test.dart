import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_another_unit_view.dart';

import '../../../../helpers/l10n_test_helpers.dart';

DiveComputer _computer() => DiveComputer(
  id: 'dc-1',
  name: 'My Petrel',
  manufacturer: 'Shearwater',
  model: 'Petrel 3',
  serialNumber: '12345',
  createdAt: DateTime(2026, 10, 26),
  updatedAt: DateTime(2026, 10, 26),
);

void main() {
  // Issue #3710: a same-model stand-in that turns out to be another unit.
  testWidgets('names both serials in the right places, and Done calls back', (
    tester,
  ) async {
    var dones = 0;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: DcAnotherUnitView(
            computer: _computer(),
            reportedSerial: '99999',
            onDone: () => dones++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('That was not My Petrel'), findsOneWidget);
    // Placeholders are passed in @placeholders order, not sentence order;
    // pin the rendered sentence so swapped serials cannot pass.
    expect(
      find.textContaining('reported serial number 99999, not 12345'),
      findsOneWidget,
    );
    await tester.tap(find.text('Done'));
    expect(dones, 1);
  });
}
