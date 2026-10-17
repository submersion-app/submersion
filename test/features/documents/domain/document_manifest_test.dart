import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/documents/domain/document_archive_layout.dart';
import 'package:submersion/features/documents/domain/document_manifest.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

const _headers = [
  'Title',
  'Type',
  'Filed under (kind)',
  'Filed under',
  'Issuer',
  'Reference number',
  'Issue date',
  'Expiry date',
  'Notes',
  'Emergency phone',
  'Phone',
  'Page',
  'Side',
  'Path in ZIP',
];

final _labels = ManifestLabels(
  headers: _headers,
  type: (t) => 'T:${t.name}',
  kind: (k) => 'K:${k.name}',
  front: 'front',
  back: 'back',
);

DocumentPage _p(String id, int index, {DocumentPageSide? side}) => DocumentPage(
  id: id,
  documentId: 'd',
  pageIndex: index,
  side: side,
  fileName: '$id.jpg',
  mimeType: 'image/jpeg',
  sizeBytes: 1,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ArchiveDocumentInput _in(
  Document doc,
  List<DocumentPage> pages, {
  String? record,
}) => ArchiveDocumentInput(
  document: doc,
  displayTitle: doc.title,
  kindFolder: 'Folder',
  recordFolder: record,
  pages: pages,
);

Document _doc({
  String title = 'Doc',
  DocumentType type = DocumentType.permit,
  DocumentOwner owner = const DocumentOwner.personal(),
  DateTime? issue,
  DateTime? expiry,
  String notes = '',
  String? emergencyPhone,
  String? phone,
}) => Document(
  id: title,
  diverId: 'd1',
  owner: owner,
  type: type,
  title: title,
  issuer: 'Issuer',
  referenceNumber: 'R-1',
  issueDate: issue,
  expiryDate: expiry,
  notes: notes,
  emergencyPhone: emergencyPhone,
  phone: phone,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

List<List<dynamic>> _rows(String csv) {
  expect(csv.codeUnitAt(0), 0xFEFF, reason: 'starts with a BOM');
  return const CsvToListConverter(
    shouldParseNumbers: false,
    eol: '\r\n',
  ).convert(csv.substring(1));
}

void main() {
  test('one row per page, with the plan paths and card sides', () {
    final card = _doc(
      title: 'AOW card',
      type: DocumentType.certificationCard,
      owner: const DocumentOwner(DocumentOwnerKind.certification, 'c1'),
    );
    final inputs = [
      _in(card, [
        _p('f', 0, side: DocumentPageSide.front),
        _p('b', 1, side: DocumentPageSide.back),
      ], record: 'PADI AOW'),
    ];
    final plan = planDocumentArchive(
      inputs,
      ArchiveNames(front: 'front', back: 'back', page: (n) => 'page $n'),
    );
    final rows = _rows(buildDocumentManifestCsv(inputs, plan, _labels));
    expect(rows.first, _headers);
    expect(rows.length, 3);
    expect(rows[1], [
      'AOW card',
      'T:certificationCard',
      'K:certification',
      'PADI AOW',
      'Issuer',
      'R-1',
      '',
      '',
      '',
      '',
      '',
      '1',
      'front',
      plan.pathsByPageId['f'],
    ]);
    expect(rows[2][11], '2');
    expect(rows[2][12], 'back');
  });

  test('a document with no pages gets one row with no path', () {
    final inputs = [_in(_doc(title: 'Notes only'), const [])];
    final plan = planDocumentArchive(
      inputs,
      ArchiveNames(front: 'f', back: 'b', page: (n) => '$n'),
    );
    final rows = _rows(buildDocumentManifestCsv(inputs, plan, _labels));
    expect(rows.length, 2);
    expect(rows[1].sublist(11), ['', '', '']);
    expect(rows[1][3], '', reason: 'personal has no record name');
  });

  test('dates are ISO and notes survive commas, quotes and newlines', () {
    final inputs = [
      _in(
        _doc(
          issue: DateTime(2026, 10, 12),
          expiry: DateTime(2027, 1, 5),
          notes: 'Call "Ana", then\nbook',
        ),
        [_p('x', 0)],
      ),
    ];
    final plan = planDocumentArchive(
      inputs,
      ArchiveNames(front: 'f', back: 'b', page: (n) => '$n'),
    );
    final row = _rows(buildDocumentManifestCsv(inputs, plan, _labels))[1];
    expect(row[6], '2026-10-12');
    expect(row[7], '2027-01-05');
    expect(row[8], 'Call "Ana", then\nbook');
  });

  test('phones are filled for insurance only', () {
    final inputs = [
      _in(
        _doc(
          title: 'DAN',
          type: DocumentType.insurance,
          emergencyPhone: '+1 919',
          phone: '+1 800',
        ),
        [_p('i', 0)],
      ),
      _in(_doc(title: 'Permit', emergencyPhone: 'stale', phone: 'stale'), [
        _p('q', 0),
      ]),
    ];
    final plan = planDocumentArchive(
      inputs,
      ArchiveNames(front: 'f', back: 'b', page: (n) => '$n'),
    );
    final rows = _rows(buildDocumentManifestCsv(inputs, plan, _labels));
    expect(rows[1].sublist(9, 11), ['+1 919', '+1 800']);
    expect(rows[2].sublist(9, 11), ['', '']);
  });

  test('dates stay ASCII ISO whatever the app locale', () {
    final previous = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = previous);
    Intl.defaultLocale = 'ar';
    final inputs = [
      _in(_doc(issue: DateTime(2026, 10, 12)), [_p('x', 0)]),
    ];
    final plan = planDocumentArchive(
      inputs,
      ArchiveNames(front: 'f', back: 'b', page: (n) => '$n'),
    );
    final row = _rows(buildDocumentManifestCsv(inputs, plan, _labels))[1];
    expect(row[6], '2026-10-12');
  });
}
