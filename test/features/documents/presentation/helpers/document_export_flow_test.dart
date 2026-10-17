import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/helpers/document_export_flow.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_file_picker_platform.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

const _password = 'correct horse';

DocumentPage _page(int index, List<int> bytes, {DocumentPageSide? side}) =>
    DocumentPage(
      id: '',
      documentId: '',
      pageIndex: index,
      side: side,
      fileName: 'p$index.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: bytes.length,
      bytes: Uint8List.fromList(bytes),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Future<void> _save(String title, DocumentOwner owner, List<DocumentPage> p) =>
    DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: owner,
        type: DocumentType.booking,
        title: title,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      p,
    );

Set<String> _exportTemps() => {
  for (final e in Directory.systemTemp.listSync())
    if (e.path.contains('submersion_documents_export_')) e.path,
};

void main() {
  late MockFilePickerPlatform picker;
  late FilePickerPlatform originalPicker;
  late Directory chosen;

  setUp(() async {
    final db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
    await sql(
      'INSERT INTO dive_sites (id, diver_id, name, created_at, updated_at) '
      "VALUES ('s1', 'd1', 'Blue Hole', 0, 0)",
    );
    final when = DateTime.utc(2026, 10, 12, 9).millisecondsSinceEpoch;
    await sql(
      'INSERT INTO dives (id, diver_id, dive_number, dive_date_time, site_id, '
      "created_at, updated_at) VALUES ('v1', 'd1', 142, $when, 's1', 0, 0)",
    );
    originalPicker = FilePickerPlatform.instance;
    picker = MockFilePickerPlatform();
    FilePickerPlatform.instance = picker;
    chosen = Directory.systemTemp.createTempSync('document_export_flow_');
  });
  tearDown(() async {
    FilePickerPlatform.instance = originalPicker;
    chosen.deleteSync(recursive: true);
    await tearDownTestDatabase();
  });

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final overrides = await getBaseOverrides();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => exportAllDocuments(context, ref),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  // Real file and isolate work only advances outside the fake clock.
  Future<void> settleReal(WidgetTester t, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pumpAndSettle();
  }

  testWidgets('with no documents it says so and asks nothing', (t) async {
    await pump(t);
    await t.tap(find.text('go'));
    await settleReal(
      t,
      () => find.text('There are no documents to export').evaluate().isNotEmpty,
    );
    expect(find.text('There are no documents to export'), findsOneWidget);
    expect(find.text('Save to File'), findsNothing);
  });

  testWidgets('saves a ZIP that opens with the password', (t) async {
    await t.runAsync(() async {
      await _save(
        'Boat booking',
        const DocumentOwner(DocumentOwnerKind.dive, 'v1'),
        [
          _page(0, [1, 2]),
        ],
      );
      await _save('DAN', const DocumentOwner.personal(), [
        _page(0, [3]),
      ]);
    });
    final target = '${chosen.path}${Platform.pathSeparator}out.zip';
    picker.saveFileResult = Uri.file(target);
    final tempsBefore = _exportTemps();

    await pump(t);
    await t.tap(find.text('go'));
    await settleReal(t, () => find.text('Save to File').evaluate().isNotEmpty);
    await t.tap(find.text('Save to File'));
    await settleReal(
      t,
      () => find.text('Confirm password').evaluate().isNotEmpty,
    );
    expect(find.text('Documents: 2, files: 2'), findsOneWidget);
    await t.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      _password,
    );
    await t.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      _password,
    );
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Export'));
    await settleReal(
      t,
      () => find.text('Documents exported').evaluate().isNotEmpty,
    );

    expect(find.text('Documents exported'), findsOneWidget);
    expect(
      picker.lastSavedFileName,
      matches(RegExp(r'^Submersion documents \d{4}-\d{2}-\d{2}\.zip$')),
    );
    final archive = ZipDecoder().decodeBytes(
      picker.lastSavedBytes!,
      password: _password,
    );
    expect(archive.files.map((f) => f.name), [
      'manifest.csv',
      'Dives/#142 Blue Hole 2026-10-12/Boat booking.jpg',
      'Personal/DAN.jpg',
    ]);
    expect(_exportTemps(), tempsBefore, reason: 'temp space cleaned up');
  });
}
