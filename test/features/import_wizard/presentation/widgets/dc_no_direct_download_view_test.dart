import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/dc_no_direct_download_view.dart';

import '../../../../helpers/l10n_test_helpers.dart';

DiveComputer _computer(String? manufacturer, String model) {
  final now = DateTime(2026, 10, 2);
  return DiveComputer(
    id: 'dc-1',
    name: manufacturer == null ? model : '$manufacturer $model',
    manufacturer: manufacturer,
    model: model,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('a Garmin computer gets the FIT-file guidance', (tester) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: DcNoDirectDownloadView(
          computer: _computer(' garmin ', 'Descent G2'),
          onImportFromFile: () {},
          onDone: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Can't download this computer directly"), findsOneWidget);
    expect(find.textContaining('GARMIN/Activity'), findsOneWidget);
    expect(find.textContaining('no saved connection'), findsNothing);
  });

  testWidgets('any other computer gets the generic explanation by name', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: DcNoDirectDownloadView(
          computer: _computer('Shearwater', 'Perdix'),
          onImportFromFile: () {},
          onDone: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no saved connection for Shearwater Perdix'),
      findsOneWidget,
    );
    expect(find.textContaining('GARMIN/Activity'), findsNothing);
  });

  testWidgets('the buttons invoke their callbacks', (tester) async {
    var imports = 0;
    var dones = 0;
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: DcNoDirectDownloadView(
          computer: _computer(null, 'Unknown'),
          onImportFromFile: () => imports++,
          onDone: () => dones++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import from File'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(imports, 1);
    expect(dones, 1);
  });
}
