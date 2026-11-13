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

  group('a Garmin whose watch is connected (issue #4223)', () {
    testWidgets('offers the connected watch first, the file second', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        localizedMaterialApp(
          locale: const Locale('en'),
          home: DcNoDirectDownloadView(
            computer: _computer('Garmin', 'Descent G2'),
            onImportFromFile: () => taps.add('file'),
            onDownloadFromWatch: () => taps.add('watch'),
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // It downloads, so the screen must not say it can't (issue #4223).
      expect(
        find.text('Download dives from Garmin Descent G2'),
        findsOneWidget,
      );
      expect(find.text("Can't download this computer directly"), findsNothing);
      expect(find.textContaining('Your watch is connected'), findsOneWidget);
      expect(find.textContaining('GARMIN/Activity'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Download from Watch'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Import from File'),
        findsOneWidget,
      );

      await tester.tap(find.text('Download from Watch'));
      await tester.tap(find.text('Import from File'));
      expect(taps, ['watch', 'file']);
    });

    testWidgets('is ignored for a computer that is not a Garmin', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          locale: const Locale('en'),
          home: DcNoDirectDownloadView(
            computer: _computer('Shearwater', 'Perdix'),
            onImportFromFile: () {},
            onDownloadFromWatch: () {},
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Download from Watch'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Import from File'), findsOne);
    });
  });

  group('a Garmin on a platform that reads watches, unplugged', () {
    Future<void> pump(WidgetTester tester, DiveComputer computer) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          locale: const Locale('en'),
          home: DcNoDirectDownloadView(
            computer: computer,
            readsConnectedWatches: true,
            onImportFromFile: () {},
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('asks for the watch instead of a manual copy', (tester) async {
      await pump(tester, _computer('Garmin', 'Descent G2'));

      expect(
        find.text('Connect Garmin Descent G2 to download its dives'),
        findsOneWidget,
      );
      expect(find.text("Can't download this computer directly"), findsNothing);
      expect(
        find.textContaining('choose Download Dives again'),
        findsOneWidget,
      );
      expect(find.textContaining('GARMIN/Activity'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Import from File'), findsOne);
    });

    testWidgets('changes nothing for a computer that is not a Garmin', (
      tester,
    ) async {
      await pump(tester, _computer('Shearwater', 'Perdix'));

      expect(
        find.text("Can't download this computer directly"),
        findsOneWidget,
      );
      expect(
        find.textContaining('no saved connection for Shearwater Perdix'),
        findsOneWidget,
      );
    });
  });
}
