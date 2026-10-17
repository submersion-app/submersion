import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/data/services/document_archive_exporter.dart';
import 'package:submersion/features/documents/domain/document_archive_layout.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

import '../../../../helpers/test_database.dart';

const _password = 'correct horse';
const _names = ArchiveNames(front: 'front', back: 'back', page: _page);
String _page(int n) => 'page $n';

DocumentPage _newPage(
  int index,
  List<int> bytes, {
  DocumentPageSide? side,
  String mime = 'image/jpeg',
}) => DocumentPage(
  id: '',
  documentId: '',
  pageIndex: index,
  side: side,
  fileName: 'f$index${mime == 'application/pdf' ? '.pdf' : '.jpg'}',
  mimeType: mime,
  sizeBytes: bytes.length,
  bytes: Uint8List.fromList(bytes),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Document _newDoc(String title, DocumentType type) => Document(
  id: '',
  diverId: 'd1',
  owner: const DocumentOwner.personal(),
  type: type,
  title: title,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _ThrowingRepository extends DocumentRepository {
  @override
  Future<List<DocumentPage>> getPages(
    String documentId, {
    bool withBytes = true,
  }) async => throw StateError('disk gone');
}

void main() {
  late Directory dir;
  late String out;
  late DocumentRepository repo;
  late DocumentArchivePlan plan;

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
    dir = await Directory.systemTemp.createTemp('document_archive_test_');
    out = p.join(dir.path, 'out.zip');
    repo = DocumentRepository();
    final card = await repo.save(
      _newDoc('AOW card', DocumentType.certificationCard),
      [
        _newPage(0, [1, 2, 3], side: DocumentPageSide.front),
        _newPage(1, [4, 5, 6], side: DocumentPageSide.back),
      ],
    );
    final pdf = await repo.save(_newDoc('DAN', DocumentType.insurance), [
      _newPage(0, List.filled(2000, 7), mime: 'application/pdf'),
    ]);
    final inputs = [
      for (final d in [card, pdf])
        ArchiveDocumentInput(
          document: d,
          displayTitle: d.title,
          kindFolder: 'Personal',
          recordFolder: null,
          pages: await repo.getPages(d.id, withBytes: false),
        ),
    ];
    plan = planDocumentArchive(inputs, _names);
  });
  tearDown(() async {
    await tearDownTestDatabase();
    await dir.delete(recursive: true);
  });

  Future<void> write(
    DocumentRepository r, {
    void Function(int, int)? onProgress,
    bool Function()? isCancelled,
  }) => DocumentArchiveExporter(r).write(
    plan: plan,
    manifestCsv: 'title\r\nAOW card\r\n',
    password: _password,
    outputPath: out,
    now: DateTime(2026, 10, 17),
    onProgress: onProgress,
    isCancelled: isCancelled,
  );

  test('writes the manifest and every page, readable with the '
      'password', () async {
    await write(repo);
    final archive = ZipDecoder().decodeBytes(
      await File(out).readAsBytes(),
      password: _password,
    );
    final byName = {for (final f in archive.files) f.name: f.content};
    expect(byName.keys, [
      'manifest.csv',
      'Personal/AOW card - front.jpg',
      'Personal/AOW card - back.jpg',
      'Personal/DAN.pdf',
    ]);
    expect(String.fromCharCodes(byName['manifest.csv']!), contains('AOW'));
    expect(byName['Personal/AOW card - back.jpg'], [4, 5, 6]);
    expect(byName['Personal/DAN.pdf'], List.filled(2000, 7));
  });

  test('reports progress after each file', () async {
    final calls = <(int, int)>[];
    await write(repo, onProgress: (done, total) => calls.add((done, total)));
    expect(calls, [(1, 4), (2, 4), (3, 4), (4, 4)]);
  });

  test('cancelling stops and leaves no file behind', () async {
    var written = 0;
    await expectLater(
      write(
        repo,
        onProgress: (done, _) => written = done,
        isCancelled: () => written >= 1,
      ),
      throwsA(isA<DocumentExportCancelled>()),
    );
    expect(File(out).existsSync(), isFalse);
  });

  test('a failed page read leaves no file behind', () async {
    await expectLater(write(_ThrowingRepository()), throwsStateError);
    expect(File(out).existsSync(), isFalse);
  });

  test('a refused password leaves no file behind', () async {
    await expectLater(
      DocumentArchiveExporter(repo).write(
        plan: plan,
        manifestCsv: '',
        password: 'pässwörd1',
        outputPath: out,
        now: DateTime(2026, 10, 17),
      ),
      throwsArgumentError,
    );
    expect(File(out).existsSync(), isFalse);
  });

  test('a cancel during the last file still cancels', () async {
    var written = 0;
    await expectLater(
      write(
        repo,
        onProgress: (done, _) => written = done,
        // Only true once every entry is written: nothing is left to check
        // the flag before, so it must be checked before finishing.
        isCancelled: () => written >= 4,
      ),
      throwsA(isA<DocumentExportCancelled>()),
    );
    expect(File(out).existsSync(), isFalse);
  });
}
