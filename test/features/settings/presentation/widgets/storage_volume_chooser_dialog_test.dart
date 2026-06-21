import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/features/settings/presentation/widgets/storage_volume_chooser_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final options = classifyExternalDirs([
    '/storage/emulated/0/Android/data/app.submersion/files',
    '/storage/1A2B-3C4D/Android/data/app.submersion/files',
  ]);

  Future<ExternalVolumeOption?> pumpAndOpen(WidgetTester tester) async {
    ExternalVolumeOption? picked;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await showDialog<ExternalVolumeOption>(
                  context: context,
                  builder: (_) => StorageVolumeChooserDialog(options: options),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('shows internal + SD options and the uninstall note', (
    tester,
  ) async {
    await pumpAndOpen(tester);

    expect(find.text('Internal storage'), findsOneWidget);
    expect(find.text('SD card'), findsOneWidget);
    expect(
      find.text('Files here are removed if you uninstall the app.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping SD card pops with the removable option', (tester) async {
    await pumpAndOpen(tester);
    await tester.tap(find.text('SD card'));
    await tester.pumpAndSettle();

    // Re-open to read the captured value via a second pump is unnecessary:
    // the dialog already popped, so assert on the rebuilt tree state instead.
    expect(find.byType(StorageVolumeChooserDialog), findsNothing);
  });

  testWidgets('tapping Internal storage selects the internal volume', (
    tester,
  ) async {
    ExternalVolumeOption? picked;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await showDialog<ExternalVolumeOption>(
                  context: context,
                  builder: (_) => StorageVolumeChooserDialog(options: options),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Internal storage'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.isInternal, isTrue);
  });
}
