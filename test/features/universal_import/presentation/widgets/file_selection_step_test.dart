import 'package:file_picker/file_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_detector.dart';
import 'package:submersion/features/universal_import/data/models/garmin_import_progress.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/file_selection_step.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Picker that always reports a cancelled selection so taps are safe.
class _CancellingPicker extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => const [];

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => null;
}

Widget harness() {
  return const ProviderScope(
    child: MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: FileSelectionStep()),
    ),
  );
}

/// FileSelectionStep under a scope with [garminDevices] as the detected list.
Widget harnessWithGarmin(List<GarminDevice> garminDevices) {
  return ProviderScope(
    overrides: [
      garminDevicesProvider.overrideWith((ref) async => garminDevices),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: FileSelectionStep()),
    ),
  );
}

/// A notifier caught part way through an import from a Garmin watch.
class _GarminImportingNotifier extends UniversalImportNotifier {
  _GarminImportingNotifier(super.ref, GarminImportProgress progress) {
    state = state.copyWith(isLoading: true, garminProgress: progress);
  }
}

/// FileSelectionStep while a Garmin import is at [progress].
Widget harnessImportingFromGarmin(GarminImportProgress progress) {
  return ProviderScope(
    overrides: [
      universalImportNotifierProvider.overrideWith(
        (ref) => _GarminImportingNotifier(ref, progress),
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

/// A notifier whose last Garmin download found nothing new (issue #4223).
class _NothingNewNotifier extends UniversalImportNotifier {
  _NothingNewNotifier(super.ref) {
    state = state.copyWith(garminNothingNew: true);
  }

  var readAllCalls = 0;

  @override
  Future<void> importAllFromGarminDevice() async => readAllCalls++;
}

PickedImportFile _file(String name) => PickedImportFile(
  name: name,
  path: '/tmp/$name',
  detection: const DetectionResult(format: ImportFormat.uddf, confidence: 1),
  status: ImportFileStatus.pending,
);

void main() {
  testWidgets('desktop shows Choose Folder button', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(harness());
    expect(find.text('Choose Folder'), findsOneWidget);
    expect(find.text('Select Files'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('mobile hides Choose Folder button', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(harness());
    expect(find.text('Choose Folder'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop hides the Garmin button when no device is connected', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(harnessWithGarmin(const []));
    await tester.pumpAndSettle();
    expect(find.text('Choose Folder'), findsOneWidget);
    expect(find.text('Import from Garmin Device'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop shows the Garmin button when a device is detected', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(
      harnessWithGarmin(const [
        GarminVolume(
          volumeName: 'GARMIN',
          volumeRootPath: '/Volumes/GARMIN',
          activityDirPath: '/Volumes/GARMIN/GARMIN/Activity',
          fitFileCount: 3,
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Import from Garmin Device'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('batch selection renders a localized file count', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(universalImportNotifierProvider.notifier)
        .debugSetFilesForTest([
          _file('a.uddf'),
          _file('b.fit'),
          _file('c.fit'),
        ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FileSelectionStep()),
        ),
      ),
    );

    expect(find.text('3 files selected'), findsOneWidget);
  });

  testWidgets('tapping the pick and folder buttons invokes the picker', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final originalPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _CancellingPicker();
    addTearDown(() => FilePickerPlatform.instance = originalPicker);
    await tester.pumpWidget(harness());

    // Both buttons run their onPressed closures; the picker cancels, so no
    // state change and no exception.
    await tester.tap(find.text('Select Files'));
    await tester.pump();
    await tester.tap(find.text('Choose Folder'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  group('Garmin import progress', () {
    const name = 'Garmin Descent G2';

    LinearProgressIndicator bar(WidgetTester tester) =>
        tester.widget(find.byType(LinearProgressIndicator));

    testWidgets('looking for the watch', (tester) async {
      await tester.pumpWidget(
        harnessImportingFromGarmin(
          const GarminImportProgress(GarminImportPhase.lookingForWatch),
        ),
      );

      expect(find.text('Looking for the watch...'), findsOneWidget);
      expect(bar(tester).value, isNull);
      expect(find.text('Detecting...'), findsNothing);
    });

    testWidgets('scanning the activity folder has no count', (tester) async {
      await tester.pumpWidget(
        harnessImportingFromGarmin(
          const GarminImportProgress(
            GarminImportPhase.scanning,
            deviceName: name,
          ),
        ),
      );

      expect(
        find.text('Scanning Garmin Descent G2 activity...'),
        findsOneWidget,
      );
      expect(bar(tester).value, isNull);
    });

    testWidgets('copying shows files read so far', (tester) async {
      await tester.pumpWidget(
        harnessImportingFromGarmin(
          const GarminImportProgress(
            GarminImportPhase.copying,
            current: 3,
            total: 10,
            deviceName: name,
          ),
        ),
      );

      expect(find.text('Reading watch files (3 of 10)...'), findsOneWidget);
      expect(bar(tester).value, closeTo(0.3, 1e-9));
    });

    testWidgets('checking shows files checked so far', (tester) async {
      await tester.pumpWidget(
        harnessImportingFromGarmin(
          const GarminImportProgress(
            GarminImportPhase.checking,
            current: 50,
            total: 200,
            deviceName: name,
          ),
        ),
      );

      expect(find.text('Checking for dives (50 of 200)...'), findsOneWidget);
      expect(bar(tester).value, closeTo(0.25, 1e-9));
    });

    testWidgets('no progress panel when no Garmin import runs', (tester) async {
      await tester.pumpWidget(harness());

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('a Garmin download with nothing new (issue #4223)', () {
    testWidgets('says so and offers to read every activity', (tester) async {
      late _NothingNewNotifier notifier;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            universalImportNotifierProvider.overrideWith(
              (ref) => notifier = _NothingNewNotifier(ref),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: FileSelectionStep()),
          ),
        ),
      );

      expect(
        find.text('No new dives on the watch since your last download.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Download All Again'));
      await tester.pump();

      expect(notifier.readAllCalls, 1);
    });

    testWidgets('is not shown otherwise', (tester) async {
      await tester.pumpWidget(harness());

      expect(find.text('Download All Again'), findsNothing);
    });
  });
}
