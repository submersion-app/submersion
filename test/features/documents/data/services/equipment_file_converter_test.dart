import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/data/services/equipment_file_converter.dart';
import 'package:submersion/features/documents/domain/document_ids.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/test_database.dart';

/// Gear attachments from the older card (#1517) move into the library
/// (issue #3333), once, and only when this device can hold them.
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  final reads = <String>[];
  final kb = Uint8List.fromList(List.filled(1024, 7));
  final huge = Uint8List(11 * 1024 * 1024);

  Future<Uint8List?> reader(MediaItem item) async {
    reads.add(item.id);
    return switch (item.id) {
      'm1' || 'm5' => kb,
      'm4' => huge,
      _ => null,
    };
  }

  EquipmentFileConverter converter() =>
      EquipmentFileConverter(readBytes: reader, prefs: prefs);

  Future<List<String>> mediaIds() async => [
    for (final r in await db.customSelect('SELECT id FROM media').get())
      r.read<String>('id'),
  ];

  Future<List<String>> tombstones(String entity) async => [
    for (final r
        in await db
            .customSelect(
              'SELECT record_id FROM deletion_log WHERE entity_type = ?',
              variables: [Variable.withString(entity)],
            )
            .get())
      r.read<String>('record_id'),
  ];

  setUp(() async {
    reads.clear();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
    await sql(
      'INSERT INTO equipment (id, diver_id, name, type, created_at, '
      "updated_at) VALUES ('e1', 'd1', 'Perdix', 'computer', 0, 0), "
      "('e2', NULL, 'Old reg', 'regulator', 0, 0)",
    );
    final created = DateTime(2025, 4, 2).millisecondsSinceEpoch;
    await sql(
      'INSERT INTO media (id, equipment_id, file_path, original_filename, '
      'file_type, caption, created_at, updated_at) VALUES '
      "('m1', 'e1', '/x/Invoice.pdf', 'Invoice.pdf', 'document', "
      "'Bought in Kona', $created, 0), "
      "('m2', 'e1', '/x/Track.gpx', 'Track.gpx', 'document', NULL, 0, 0), "
      "('m3', 'e1', '/x/Manual.pdf', 'Manual.pdf', 'document', NULL, 0, 0), "
      "('m4', 'e1', '/x/Huge.pdf', 'Huge.pdf', 'document', NULL, 0, 0), "
      "('m5', 'e2', '/x/Orphan.pdf', 'Orphan.pdf', 'document', NULL, 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  test(
    'converts a readable file into a receipt filed under the gear',
    () async {
      final result = await converter().run();
      final id = documentEquipmentFileId('m1');
      final doc = (await DocumentRepository().getById(id))!;
      expect(doc.owner, const DocumentOwner(DocumentOwnerKind.equipment, 'e1'));
      expect(doc.diverId, 'd1');
      expect(doc.type, DocumentType.receipt);
      expect(doc.title, 'Invoice');
      expect(doc.notes, 'Bought in Kona');
      expect(doc.createdAt, DateTime(2025, 4, 2));
      final page = (await DocumentRepository().getPages(id)).single;
      expect(page.id, documentEquipmentFilePageId(id));
      expect(page.mimeType, 'application/pdf');
      expect(page.fileName, 'Invoice.pdf');
      expect(page.bytes, kb);
      expect(await mediaIds(), isNot(contains('m1')));
      expect(await tombstones('media'), contains('m1'));
      expect(result.converted, 1);
      expect(result.remaining, 4);
    },
  );

  test('leaves what it cannot convert', () async {
    await converter().run();
    expect(await mediaIds(), containsAll(['m2', 'm3', 'm4', 'm5']));
    expect(reads, isNot(contains('m2')));
  });

  test('an oversize file is remembered so it is not read again', () async {
    await converter().run();
    expect(prefs.getStringList(EquipmentFileConverter.skippedKey), ['m4']);
    reads.clear();
    await converter().run();
    expect(reads, isNot(contains('m4')));
    expect(reads, contains('m3'));
  });

  test('gear with no diver is skipped, not crashed', () async {
    await converter().run();
    expect(reads, isNot(contains('m5')));
    expect(await mediaIds(), contains('m5'));
  });

  test('a file a peer already converted only drops the link', () async {
    await DocumentRepository().save(
      Document(
        id: documentEquipmentFileId('m1'),
        diverId: 'd1',
        owner: const DocumentOwner(DocumentOwnerKind.equipment, 'e1'),
        type: DocumentType.receipt,
        title: 'Peer',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    );
    await converter().run();
    final doc = await DocumentRepository().getById(
      documentEquipmentFileId('m1'),
    );
    expect(doc!.title, 'Peer');
    expect(reads, isNot(contains('m1')));
    expect(await mediaIds(), isNot(contains('m1')));
  });

  test('a file known to be too large is skipped without reading it', () async {
    await db.customStatement(
      'INSERT INTO media (id, equipment_id, file_path, original_filename, '
      'file_type, content_size_bytes, created_at, updated_at) VALUES '
      "('m6', 'e1', '/x/Big.pdf', 'Big.pdf', 'document', ${50 * 1024 * 1024}, 0, 0)",
    );
    await converter().run();
    expect(reads, isNot(contains('m6')));
    expect(
      prefs.getStringList(EquipmentFileConverter.skippedKey),
      containsAll(['m4', 'm6']),
    );
  });

  test('a large local file is skipped from its size on disk', () async {
    final dir = await Directory.systemTemp.createTemp('gear_file_');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'Manual.pdf');
    final raf = await File(path).open(mode: FileMode.write);
    await raf.setPosition(11 * 1024 * 1024);
    await raf.writeByte(0);
    await raf.close();
    await db.customStatement(
      'INSERT INTO media (id, equipment_id, file_path, original_filename, '
      'file_type, created_at, updated_at) VALUES '
      "('m7', 'e1', ?, 'Manual.pdf', 'document', 0, 0)",
      [path],
    );
    await converter().run();
    expect(reads, isNot(contains('m7')));
    expect(
      prefs.getStringList(EquipmentFileConverter.skippedKey),
      contains('m7'),
    );
  });

  test('the skip list forgets files that are gone', () async {
    await prefs.setStringList(EquipmentFileConverter.skippedKey, [
      'deleted-long-ago',
    ]);
    await converter().run();
    expect(prefs.getStringList(EquipmentFileConverter.skippedKey), ['m4']);
  });

  test(
    'a file a dive also uses keeps its row, losing only the gear link',
    () async {
      await db.customStatement(
        'INSERT INTO dives (id, diver_id, dive_date_time, created_at, '
        "updated_at) VALUES ('v1', 'd1', 0, 0, 0)",
      );
      await db.customStatement(
        "UPDATE media SET dive_id = 'v1' WHERE id = 'm1'",
      );
      await converter().run();
      expect(
        await DocumentRepository().getById(documentEquipmentFileId('m1')),
        isNotNull,
      );
      final row = await db
          .customSelect(
            "SELECT dive_id, equipment_id FROM media WHERE id = 'm1'",
          )
          .getSingle();
      expect(row.read<String?>('dive_id'), 'v1');
      expect(row.read<String?>('equipment_id'), isNull);
    },
  );

  test('links are dropped through the injected unlink', () async {
    final unlinked = <String>[];
    await EquipmentFileConverter(
      readBytes: reader,
      prefs: prefs,
      unlink: (id) async => unlinked.add(id),
    ).run();
    expect(unlinked, ['m1']);
  });

  test('a second run is a no-op', () async {
    await converter().run();
    final second = await converter().run();
    expect(second.converted, 0);
    expect((await DocumentRepository().getAllForDiver('d1')).length, 1);
  });
}
