import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/images/profile_photo_codec.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/data/services/document_page_capture.dart';
import 'package:submersion/features/documents/domain/document_file_gate.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/pages/document_edit_page.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

DocumentPageCapture _files(PickedBytes picked) => DocumentPageCapture(
  pickFile: (_) async => picked,
  pickImage: (_) async => (bytes: Uint8List(4), name: 'shot.jpg'),
  encode: (p) async =>
      (outcome: ImageEncodeOutcome.encoded, bytes: Uint8List.fromList([9])),
);

void main() {
  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpEditor(
    WidgetTester t, {
    String? documentId,
    DocumentType? initialType,
    DocumentOwner owner = const DocumentOwner.personal(),
    DocumentPageCapture? capture,
    VoidCallback? onCancel,
    DocumentOwner? pickedOwner,
  }) async {
    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final overrides = await getBaseOverrides();
    await t.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        ],
        child: DocumentEditPage(
          documentId: documentId,
          initialType: initialType,
          owner: owner,
          embedded: true,
          onSaved: (_) {},
          onCancel: onCancel ?? () {},
          capture: capture,
          pickOwner: (_, _) async => pickedOwner,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> addFilePage(WidgetTester t) async {
    await t.tap(find.text('Add page'));
    await t.pumpAndSettle();
    await t.tap(find.text('Choose file'));
    await t.pumpAndSettle();
  }

  testWidgets('insurance shows the phones and the primary toggle', (t) async {
    await pumpEditor(t, initialType: DocumentType.insurance);
    expect(find.text('24-hour emergency line'), findsOneWidget);
    expect(find.text('Office phone'), findsOneWidget);
    expect(find.text('Primary insurance'), findsOneWidget);
    expect(find.text('Insurer'), findsOneWidget);
  });

  testWidgets('a first insurance starts as the primary one', (t) async {
    await pumpEditor(t, initialType: DocumentType.insurance);
    final toggle = t.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Primary insurance'),
    );
    expect(toggle.value, isTrue);
    await t.enterText(find.byKey(const Key('document-title')), 'DAN');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    final saved = (await DocumentRepository().getAllForDiver('d1')).single;
    expect(saved.document.isPrimary, isTrue);
  });

  testWidgets('a second insurance does not take over the primary', (t) async {
    await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.insurance,
        isPrimary: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    );
    await pumpEditor(t, initialType: DocumentType.insurance);
    final toggle = t.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Primary insurance'),
    );
    expect(toggle.value, isFalse);
  });

  testWidgets('closing the pane with changes asks before discarding', (
    t,
  ) async {
    var cancelled = 0;
    await pumpEditor(
      t,
      initialType: DocumentType.permit,
      onCancel: () => cancelled++,
    );
    await t.enterText(find.byKey(const Key('document-title')), 'Draft');
    await t.tap(find.byIcon(Icons.close).first);
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(cancelled, 0);
  });

  testWidgets('a permit has no phones or primary toggle', (t) async {
    await pumpEditor(t, initialType: DocumentType.permit);
    expect(find.text('24-hour emergency line'), findsNothing);
    expect(find.text('Primary insurance'), findsNothing);
    expect(find.text('Issued by'), findsOneWidget);
  });

  testWidgets('a card shows Front and Back slots and no expiry', (t) async {
    await pumpEditor(t, initialType: DocumentType.certificationCard);
    expect(find.text('Front'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Expires'), findsNothing);
  });

  testWidgets('card faces are stored first, Front then Back, whatever order '
      'they were added in', (t) async {
    await pumpEditor(
      t,
      initialType: DocumentType.insurance,
      capture: _files((bytes: Uint8List.fromList([1]), name: 'scan.pdf')),
    );
    await addFilePage(t);
    for (final slot in ['Back', 'Front']) {
      await t.tap(find.text(slot));
      await t.pumpAndSettle();
      await t.tap(find.text('Choose file'));
      await t.pumpAndSettle();
    }
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    final saved = (await DocumentRepository().getAllForDiver('d1')).single;
    final pages = await DocumentRepository().getPages(saved.document.id);
    expect(pages.map((p) => p.side), [
      DocumentPageSide.front,
      DocumentPageSide.back,
      null,
    ]);
  });

  testWidgets('adding a file page and saving persists it', (t) async {
    await pumpEditor(
      t,
      initialType: DocumentType.permit,
      owner: const DocumentOwner.personal(),
      capture: _files((bytes: Uint8List.fromList([1, 2]), name: 'park.pdf')),
    );
    await addFilePage(t);
    await t.enterText(find.byKey(const Key('document-title')), 'Marine park');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    final all = await DocumentRepository().getAllForDiver('d1');
    expect(all.single.document.title, 'Marine park');
    expect(all.single.pageCount, 1);
    final page = (await DocumentRepository().getPages(
      all.single.document.id,
    )).single;
    expect(page.mimeType, 'application/pdf');
    expect(page.bytes, [1, 2]);
  });

  testWidgets('a file over the limit shows the limit and adds nothing', (
    t,
  ) async {
    await pumpEditor(
      t,
      capture: _files((
        bytes: Uint8List(kMaxDocumentPageBytes + 1),
        name: 'huge.pdf',
      )),
    );
    await addFilePage(t);
    expect(find.textContaining('10 MB'), findsOneWidget);
    expect(find.text('huge.pdf'), findsNothing);
  });

  testWidgets('an unsupported file names its type', (t) async {
    await pumpEditor(
      t,
      capture: _files((bytes: Uint8List(3), name: 'track.gpx')),
    );
    await addFilePage(t);
    expect(find.textContaining('gpx files are not supported'), findsOneWidget);
  });

  testWidgets('removing a page then saving deletes it', (t) async {
    final saved = await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.permit,
        title: 'Park',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      [
        DocumentPage(
          id: '',
          documentId: '',
          pageIndex: 0,
          fileName: 'a.txt',
          mimeType: 'text/plain',
          sizeBytes: 1,
          bytes: Uint8List.fromList([1]),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    await pumpEditor(t, documentId: saved.id);
    await t.tap(find.byTooltip('Remove page'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(await DocumentRepository().getPages(saved.id), isEmpty);
    expect((await DocumentRepository().getById(saved.id))!.title, 'Park');
  });

  testWidgets('editing keeps the owner it was filed under', (t) async {
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
      "created_at, updated_at) VALUES ('t1', 'd1', 'Bonaire', 0, 0, 0, 0)",
    );
    final saved = await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
        type: DocumentType.booking,
        title: 'Boat',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    );
    await pumpEditor(t, documentId: saved.id);
    await t.enterText(find.byKey(const Key('document-title')), 'Boat trip');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    final after = (await DocumentRepository().getById(saved.id))!;
    expect(after.title, 'Boat trip');
    expect(after.owner, const DocumentOwner(DocumentOwnerKind.trip, 't1'));
  });

  group('Filed under', () {
    Future<void> addTrip() => DatabaseService.instance.database.customStatement(
      'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
      "created_at, updated_at) VALUES ('t1', 'd1', 'Bonaire', 0, 0, 0, 0)",
    );

    Future<Document> saveDoc(DocumentType type, DocumentOwner owner) =>
        DocumentRepository().save(
          Document(
            id: '',
            diverId: 'd1',
            owner: owner,
            type: type,
            title: 'Boat',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          const [],
        );

    testWidgets('a personal document can be filed under a trip', (t) async {
      await addTrip();
      final doc = await saveDoc(
        DocumentType.booking,
        const DocumentOwner.personal(),
      );
      await pumpEditor(
        t,
        documentId: doc.id,
        pickedOwner: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
      );
      expect(find.text('Personal'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('document-owner-field')));
      await t.pumpAndSettle();
      expect(
        t.getSemantics(find.byKey(const ValueKey('document-owner-field'))),
        isSemantics(
          isButton: true,
          isEnabled: true,
          label: 'Filed under\nBonaire',
        ),
      );
      // The record's name, with its kind as the icon.
      expect(find.text('Bonaire'), findsOneWidget);
      expect(find.textContaining('Trips'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('document-owner-field')),
          matching: find.byIcon(Icons.luggage_outlined),
        ),
        findsOneWidget,
      );
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      final after = (await DocumentRepository().getById(doc.id))!;
      expect(after.owner, const DocumentOwner(DocumentOwnerKind.trip, 't1'));
    });

    testWidgets('moving to Personal clears the old owner column', (t) async {
      await addTrip();
      final doc = await saveDoc(
        DocumentType.booking,
        const DocumentOwner(DocumentOwnerKind.trip, 't1'),
      );
      await pumpEditor(
        t,
        documentId: doc.id,
        pickedOwner: const DocumentOwner.personal(),
      );
      await t.tap(find.byKey(const ValueKey('document-owner-field')));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      final db = DatabaseService.instance.database;
      final row = await (db.select(
        db.documents,
      )..where((d) => d.id.equals(doc.id))).getSingle();
      expect(row.tripId, isNull);
    });

    testWidgets('a new document starts where it was opened from', (t) async {
      await addTrip();
      await pumpEditor(
        t,
        owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
      );
      expect(find.textContaining('Bonaire'), findsOneWidget);
    });

    testWidgets('a card document cannot be moved', (t) async {
      await DatabaseService.instance.database.customStatement(
        'INSERT INTO certifications (id, diver_id, name, agency, created_at, '
        "updated_at) VALUES ('c1', 'd1', 'Nitrox', 'tdi', 0, 0)",
      );
      final doc = await saveDoc(
        DocumentType.certificationCard,
        const DocumentOwner(DocumentOwnerKind.certification, 'c1'),
      );
      await pumpEditor(
        t,
        documentId: doc.id,
        pickedOwner: const DocumentOwner.personal(),
      );
      expect(find.text('A card stays with its certification'), findsOneWidget);
      expect(
        t.getSemantics(find.byKey(const ValueKey('document-owner-field'))),
        isSemantics(isButton: true, isEnabled: false),
      );
      await t.tap(find.byKey(const ValueKey('document-owner-field')));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      final after = (await DocumentRepository().getById(doc.id))!;
      expect(
        after.owner,
        const DocumentOwner(DocumentOwnerKind.certification, 'c1'),
      );
    });
  });
}
