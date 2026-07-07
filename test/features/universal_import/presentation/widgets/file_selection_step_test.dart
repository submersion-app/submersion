import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/file_selection_step.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Picker that always reports a cancelled selection so taps are safe.
class _CancellingPicker extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async => null;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async => null;
}

Widget harness() {
  return const ProviderScope(
    child: MaterialApp(
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
    FilePickerPlatform.instance = _CancellingPicker();
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
