import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DivesCompanion, MediaCompanion;

import '../../../../helpers/mock_file_picker_platform.dart';
import '../../../../helpers/pdf_text.dart';
import '../../../../helpers/test_database.dart';

/// A valid 1x1 transparent PNG, so the PDF image decoder has real bytes.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

/// Writes an instructor-signature media row the way a signed dive carries one.
///
/// Inserted directly rather than through `SignatureStorageService.saveSignature`
/// because that method omits the non-nullable `media.filePath` column and
/// throws before it ever reaches the database.
Future<void> _storeSignature(
  AppDatabase db, {
  required String diveId,
  required String signerName,
}) async {
  final now = DateTime(2026, 1, 20).millisecondsSinceEpoch;
  // media.diveId is a foreign key, so the dive row has to exist first.
  await db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(diveId),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
  await db
      .into(db.media)
      .insert(
        MediaCompanion(
          id: Value('sig-$diveId'),
          diveId: Value(diveId),
          filePath: const Value(''),
          fileType: const Value('instructor_signature'),
          imageData: Value(_onePixelPng),
          signerName: Value(signerName),
          takenAt: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

/// Records the name the save dialog was offered so tests can prove the
/// selected template reaches the suggested file name.
class _RecordingPicker extends MockFilePickerPlatform {
  String? requestedFileName;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    requestedFileName = fileName;
    return super.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
    );
  }
}

/// Both PDF logbook paths - share and save-to-file - must run through the same
/// template-aware builder, so the chosen detail level, page size, certification
/// cards and diver personalization survive (#644).
/// Pins the diver's settings so the export path cannot fall back to defaults.
class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory workDir;
  late _RecordingPicker picker;
  late FilePickerPlatform originalPicker;
  late AppDatabase db;

  setUpAll(() async {
    workDir = await Directory.systemTemp.createTemp('export_pdf_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => call.method == 'getApplicationDocumentsDirectory'
              ? workDir.path
              : null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async => null,
        );
  });

  tearDownAll(() async {
    if (await workDir.exists()) await workDir.delete(recursive: true);
  });

  setUp(() async {
    db = await setUpTestDatabase();
    originalPicker = FilePickerPlatform.instance;
    picker = _RecordingPicker();
    FilePickerPlatform.instance = picker;
  });

  tearDown(() async {
    FilePickerPlatform.instance = originalPicker;
    await tearDownTestDatabase();
  });

  final diver = Diver(
    id: 'diver-1',
    name: 'Nauticus Testerson',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final certifications = [
    Certification(
      id: 'cert-1',
      diverId: 'diver-1',
      name: 'Rescue Diver',
      agency: CertificationAgency.padi,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  ];

  final dives = [
    Dive(
      id: 'd1',
      diveNumber: 2,
      dateTime: DateTime(2026, 1, 16, 9),
      runtime: const Duration(minutes: 62),
      bottomTime: const Duration(minutes: 50),
      maxDepth: 25.0,
      avgDepth: 18.0,
      waterTemp: 22.0,
    ),
    Dive(
      id: 'd2',
      diveNumber: 1,
      dateTime: DateTime(2026, 1, 15, 9),
      bottomTime: const Duration(minutes: 40),
      maxDepth: 18.0,
      avgDepth: 12.0,
      waterTemp: 24.0,
    ),
  ];

  ProviderContainer makeContainer({
    List<Dive>? divesOverride,
    AppSettings? settings,
  }) {
    final container = ProviderContainer(
      overrides: [
        divesProvider.overrideWith((ref) async => divesOverride ?? dives),
        currentDiverProvider.overrideWith((ref) async => diver),
        allCertificationsProvider.overrideWith((ref) async => certifications),
        // The PDF path reads the diver's date and time preferences (#964), and
        // the real notifier needs SharedPreferences, so pin it here.
        settingsProvider.overrideWith(
          (ref) => _FixedSettings(settings ?? const AppSettings()),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  ExportNotifier notifierOf(ProviderContainer c) =>
      c.read(exportNotifierProvider.notifier);

  Future<String> textAt(String path) async =>
      pdfVisibleText(await File(path).readAsBytes());

  group('exportDivesToPdf (share)', () {
    test(
      'honors the selected template and personalizes with the diver',
      () async {
        final container = makeContainer();
        await notifierOf(container).exportDivesToPdf(
          const PdfExportOptions(template: PdfTemplate.detailed),
        );

        final state = container.read(exportNotifierProvider);
        expect(state.status, ExportStatus.success);
        expect(state.filePath, isNotNull);
        expect(
          state.filePath,
          contains('dive_logbook_detailed_'),
          reason: 'the shared file name must carry the chosen template',
        );

        final text = await textAt(state.filePath!);
        expect(text, contains('Nauticus Testerson'));
        expect(text, contains('Summary'));
        expect(
          text,
          contains('Total Dive Time 1h 42m'),
          reason: 'runtime 62 + bottomTime fallback 40 = 102 minutes (#644)',
        );
      },
    );

    test(
      'the simple template produces a different, table-only layout',
      () async {
        final container = makeContainer();
        await notifierOf(container).exportDivesToPdf(
          const PdfExportOptions(template: PdfTemplate.simple),
        );

        final state = container.read(exportNotifierProvider);
        expect(state.status, ExportStatus.success);
        expect(state.filePath, contains('dive_logbook_simple_'));

        final text = await textAt(state.filePath!);
        expect(text, contains('Nauticus Testerson'));
        expect(text, contains('2 dives'));
        expect(
          text,
          isNot(contains('Summary')),
          reason: 'the simple template is a compact table with no summary page',
        );
      },
    );

    test('includeCertificationCards adds the certifications page', () async {
      final container = makeContainer();
      await notifierOf(container).exportDivesToPdf(
        const PdfExportOptions(includeCertificationCards: true),
      );

      final withCards = await textAt(
        container.read(exportNotifierProvider).filePath!,
      );
      expect(withCards, contains('Certifications'));
      expect(withCards, contains('Rescue Diver'));

      final plain = makeContainer();
      await notifierOf(plain).exportDivesToPdf(const PdfExportOptions());
      final withoutCards = await textAt(
        plain.read(exportNotifierProvider).filePath!,
      );
      expect(withoutCards, isNot(contains('Rescue Diver')));
    });

    test('carries a captured signature into the logbook', () async {
      await _storeSignature(db, diveId: 'd1', signerName: 'Ida Instructor');

      final container = makeContainer();
      await notifierOf(container).exportDivesToPdf(
        const PdfExportOptions(template: PdfTemplate.detailed),
      );

      final text = await textAt(
        container.read(exportNotifierProvider).filePath!,
      );
      expect(
        text,
        contains('Ida Instructor'),
        reason: 'signatures stored for a dive must reach the exported PDF',
      );
    });

    test('renders dates and times the way the diver reads them', () async {
      // #964: the logbook is a printed document, so it follows the diver's
      // DateFormatPreference and TimeFormat instead of ISO. Only the file name
      // stays ISO, so a folder of exports still sorts chronologically.
      final container = makeContainer(
        settings: const AppSettings(
          dateFormat: DateFormatPreference.ddmmyyyy,
          timeFormat: TimeFormat.twelveHour,
        ),
      );
      await notifierOf(container).exportDivesToPdf(
        const PdfExportOptions(template: PdfTemplate.detailed),
      );

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.success);

      final text = await textAt(state.filePath!);
      expect(text, contains('16/01/2026'));
      expect(text, contains('9:00'));
      expect(text, contains('AM'));
      expect(text, isNot(contains('2026-01-16')));
      expect(
        state.filePath,
        contains(DateFormat('yyyy-MM-dd').format(DateTime.now())),
        reason: 'the shared file name stays sortable ISO',
      );
    });

    test('reports an error when there is nothing to export', () async {
      final container = makeContainer(divesOverride: const []);
      await notifierOf(container).exportDivesToPdf();

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.error);
      expect(state.message, 'No dives to export');
    });
  });

  group('savePdfToFile', () {
    test('saves the template the user picked, not the legacy layout', () async {
      final target = '${workDir.path}/saved_simple.pdf';
      picker.saveFileResult = Uri.file(target);

      final container = makeContainer();
      await notifierOf(
        container,
      ).savePdfToFile(const PdfExportOptions(template: PdfTemplate.simple));

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.success);
      expect(state.filePath, target);
      expect(
        picker.requestedFileName,
        startsWith('dive_logbook_simple_'),
        reason: 'the suggested save name must carry the chosen template',
      );

      final text = await textAt(target);
      expect(text, contains('Nauticus Testerson'));
      expect(text, contains('2 dives'));
      expect(
        text,
        isNot(contains('Summary')),
        reason:
            'the legacy single-layout builder always emitted a summary page; '
            'saving must use the selected simple template instead (#644)',
      );
    });

    test('the detailed template saves a different document', () async {
      final target = '${workDir.path}/saved_detailed.pdf';
      picker.saveFileResult = Uri.file(target);

      final container = makeContainer();
      await notifierOf(
        container,
      ).savePdfToFile(const PdfExportOptions(template: PdfTemplate.detailed));

      expect(picker.requestedFileName, startsWith('dive_logbook_detailed_'));
      final text = await textAt(target);
      expect(text, contains('Summary'));
      expect(text, contains('Total Dive Time 1h 42m'));
    });

    test(
      'goes idle with a cancel message when the picker is dismissed',
      () async {
        picker.saveFileResult = null;

        final container = makeContainer();
        await notifierOf(container).savePdfToFile(const PdfExportOptions());

        final state = container.read(exportNotifierProvider);
        expect(state.status, ExportStatus.idle);
        expect(state.message, 'Save cancelled');
      },
    );

    test('reports an error when there is nothing to save', () async {
      final container = makeContainer(divesOverride: const []);
      await notifierOf(container).savePdfToFile(const PdfExportOptions());

      final state = container.read(exportNotifierProvider);
      expect(state.status, ExportStatus.error);
      expect(state.message, 'No dives to export');
    });
  });
}
