import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/document_archive_layout.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

const _names = ArchiveNames(front: 'front', back: 'back', page: _page);
String _page(int n) => 'page $n';

int _ids = 0;

DocumentPage _p(
  String fileName, {
  String mime = 'application/pdf',
  int index = 0,
  DocumentPageSide? side,
}) => DocumentPage(
  id: 'p${_ids++}',
  documentId: 'd',
  pageIndex: index,
  side: side,
  fileName: fileName,
  mimeType: mime,
  sizeBytes: 1,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ArchiveDocumentInput _in(
  String title,
  List<DocumentPage> pages, {
  String kindFolder = 'Personal',
  String? recordFolder,
}) => ArchiveDocumentInput(
  document: Document(
    id: 'doc-$title-${_ids++}',
    diverId: 'd1',
    owner: const DocumentOwner.personal(),
    type: DocumentType.other,
    title: title,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  displayTitle: title,
  kindFolder: kindFolder,
  recordFolder: recordFolder,
  pages: pages,
);

List<String> _paths(List<ArchiveDocumentInput> docs) =>
    planDocumentArchive(docs, _names).files.map((f) => f.path).toList();

void main() {
  group('sanitizeArchiveSegment', () {
    test('replaces characters no file system accepts', () {
      expect(
        sanitizeArchiveSegment('a<b>c:d"e/f\\g|h?i*j'),
        'a_b_c_d_e_f_g_h_i_j',
      );
      expect(sanitizeArchiveSegment('tab\there\u0001'), 'tab_here_');
    });

    test('trims trailing dots and spaces', () {
      expect(sanitizeArchiveSegment('Notes. '), 'Notes');
      expect(sanitizeArchiveSegment('  padded  '), 'padded');
    });

    test('suffixes Windows reserved names', () {
      expect(sanitizeArchiveSegment('CON'), 'CON_');
      expect(sanitizeArchiveSegment('nul'), 'nul_');
      expect(sanitizeArchiveSegment('com1'), 'com1_');
      expect(sanitizeArchiveSegment('Console'), 'Console');
    });

    test('never gives an empty segment', () {
      expect(sanitizeArchiveSegment('???'), '___');
      expect(sanitizeArchiveSegment('...'), '_');
      expect(sanitizeArchiveSegment(''), '_');
    });

    test('caps the length in UTF-8 bytes, not characters', () {
      expect(sanitizeArchiveSegment('x' * 300).length, 100);
      // 3 bytes each: 120 of them would be 360 bytes, over the 255-byte
      // name limit once a suffix and extension are added.
      final cjk = sanitizeArchiveSegment(String.fromCharCode(0x53F0) * 120);
      expect(utf8.encode(cjk).length, lessThanOrEqualTo(100));
      expect(cjk.runes.length, 33);
    });

    test('never cuts a letter from its combining accent', () {
      final decomposed = '${'x' * 99}e${String.fromCharCode(0x301)}';
      expect(sanitizeArchiveSegment(decomposed), 'x' * 99);
    });

    test('suffixes the superscript device names too', () {
      final com1 = 'COM${String.fromCharCode(0xB9)}';
      expect(sanitizeArchiveSegment(com1), '${com1}_');
    });
  });

  group('archiveExtension', () {
    test('keeps the stored extension', () {
      expect(archiveExtension(_p('IMG_1.HEIC', mime: 'image/heic')), '.HEIC');
    });

    test('falls back to the MIME type', () {
      expect(archiveExtension(_p('scan', mime: 'image/jpeg')), '.jpg');
      expect(archiveExtension(_p('scan', mime: 'application/pdf')), '.pdf');
      expect(archiveExtension(_p('scan', mime: 'application/x-foo')), '.bin');
    });
  });

  group('planDocumentArchive', () {
    test('a one-page personal document sits in the kind folder', () {
      expect(
        _paths([
          _in('DAN insurance 2026', [_p('policy.pdf')]),
        ]),
        ['Personal/DAN insurance 2026.pdf'],
      );
    });

    test('card faces are named front and back', () {
      expect(
        _paths([
          _in(
            'PADI AOW card',
            [
              _p('a.jpg', mime: 'image/jpeg', side: DocumentPageSide.front),
              _p(
                'b.jpg',
                mime: 'image/jpeg',
                index: 1,
                side: DocumentPageSide.back,
              ),
            ],
            kindFolder: 'Certifications',
            recordFolder: 'PADI Advanced Open Water',
          ),
        ]),
        [
          'Certifications/PADI Advanced Open Water/PADI AOW card - front.jpg',
          'Certifications/PADI Advanced Open Water/PADI AOW card - back.jpg',
        ],
      );
    });

    test('other multi-page documents number their pages in order', () {
      expect(
        _paths([
          _in('Booking', [
            _p('3.pdf', index: 2),
            _p('1.pdf'),
            _p('2.pdf', index: 1),
          ]),
        ]),
        [
          'Personal/Booking - page 1.pdf',
          'Personal/Booking - page 2.pdf',
          'Personal/Booking - page 3.pdf',
        ],
      );
    });

    test('same names in one folder get a number, ignoring case', () {
      expect(
        _paths([
          _in('Permit', [_p('x.pdf')]),
          _in('Permit', [_p('y.pdf')]),
          _in('permit', [_p('z.pdf')]),
        ]),
        [
          'Personal/Permit.pdf',
          'Personal/Permit (2).pdf',
          'Personal/permit (3).pdf',
        ],
      );
    });

    test('a record that is gone keeps its documents under Unknown', () {
      expect(
        _paths([
          _in(
            'Boat booking',
            [_p('b.pdf')],
            kindFolder: 'Dives',
            recordFolder: 'Unknown',
          ),
        ]),
        ['Dives/Unknown/Boat booking.pdf'],
      );
    });

    test('folder and file names are sanitized', () {
      expect(
        _paths([
          _in(
            'Card: 1/2',
            [_p('c.pdf')],
            kindFolder: 'Dives',
            recordFolder: '#142 Blue/Hole 2026-10-12',
          ),
        ]),
        ['Dives/#142 Blue_Hole 2026-10-12/Card_ 1_2.pdf'],
      );
    });

    test('a document with no pages adds no file', () {
      final plan = planDocumentArchive([_in('Notes only', [])], _names);
      expect(plan.files, isEmpty);
    });

    test('maps each page to its path', () {
      final page = _p('x.pdf');
      final plan = planDocumentArchive([
        _in('DAN', [page]),
      ], _names);
      expect(plan.pathsByPageId, {page.id: 'Personal/DAN.pdf'});
      expect(plan.files.single.pageId, page.id);
    });
  });
}
