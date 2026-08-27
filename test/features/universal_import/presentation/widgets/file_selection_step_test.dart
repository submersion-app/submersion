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
        GarminDevice(
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
}
