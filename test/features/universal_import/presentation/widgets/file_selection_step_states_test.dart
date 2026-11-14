import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_handoff_card.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_detector.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_importer.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/file_selection_step.dart';
import 'package:submersion/features/universal_import/presentation/widgets/suunto_json_handoff_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A notifier that starts in the state [seed] makes of the initial one, and
/// counts Garmin downloads instead of running them.
class _SeededNotifier extends UniversalImportNotifier {
  _SeededNotifier(
    super.ref,
    UniversalImportState Function(UniversalImportState) seed,
  ) {
    state = seed(state);
  }

  var garminImportCalls = 0;

  @override
  Future<void> importFromGarminDevice([
    GarminImportRequest request = const GarminImportRequest(),
  ]) async => garminImportCalls++;
}

const _watch = GarminVolume(
  volumeName: 'GARMIN',
  volumeRootPath: '/Volumes/GARMIN',
  activityDirPath: '/Volumes/GARMIN/GARMIN/Activity',
  fitFileCount: 3,
);

late _SeededNotifier _notifier;

Widget _harness(
  UniversalImportState Function(UniversalImportState) seed, {
  List<GarminDevice> garminDevices = const [],
}) {
  return ProviderScope(
    overrides: [
      garminDevicesProvider.overrideWith((ref) async => garminDevices),
      universalImportNotifierProvider.overrideWith(
        (ref) => _notifier = _SeededNotifier(ref, seed),
      ),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: FileSelectionStep()),
    ),
  );
}

/// One picked file of [format] with [bytes] already read.
UniversalImportState Function(UniversalImportState) _pickedHandoff(
  ImportFormat format,
  String name,
  Uint8List bytes,
) {
  return (state) => state.copyWith(
    files: [
      PickedImportFile(
        name: name,
        bytes: bytes,
        detection: DetectionResult(format: format, confidence: 1),
        status: ImportFileStatus.pending,
      ),
    ],
    detectionResult: DetectionResult(format: format, confidence: 1),
  );
}

void main() {
  testWidgets('an error is shown in a banner', (tester) async {
    await tester.pumpWidget(
      _harness((state) => state.copyWith(error: 'The file could not be read')),
    );

    expect(find.text('The file could not be read'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('no error banner without an error', (tester) async {
    await tester.pumpWidget(_harness((state) => state));

    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('detecting files labels and disables the Select Files button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness((state) => state.copyWith(isLoading: true)),
    );

    expect(find.text('Detecting...'), findsOneWidget);
    expect(find.text('Select Files'), findsNothing);
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Detecting...'),
        matching: find.byWidgetPredicate((w) => w is OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('tapping Import from Garmin Device starts a Garmin download', (
    tester,
  ) async {
    // flutter_test checks the platform override before teardowns run, so it
    // is put back in the body.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        _harness((state) => state, garminDevices: const [_watch]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import from Garmin Device'));
      await tester.pump();

      expect(_notifier.garminImportCalls, 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a picked Suunto JSON export shows the Suunto hand-off card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _pickedHandoff(
          ImportFormat.suuntoJson,
          'nautic.json',
          Uint8List.fromList([1, 2, 3]),
        ),
      ),
    );

    expect(find.byType(SuuntoJsonHandoffCard), findsOneWidget);
    expect(find.byType(NavTrackHandoffCard), findsNothing);
    expect(find.text('Select Files'), findsNothing);
  });

  testWidgets('a picked navigation track shows the track hand-off card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _pickedHandoff(
          ImportFormat.navTrack,
          'route.enc',
          Uint8List.fromList([4, 5, 6]),
        ),
      ),
    );

    expect(find.byType(NavTrackHandoffCard), findsOneWidget);
    expect(find.byType(SuuntoJsonHandoffCard), findsNothing);
  });
}
