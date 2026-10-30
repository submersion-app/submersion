import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/universal_import/data/models/import_tag_scopes.dart';
import 'package:xml/xml.dart';

/// A tag's media and document scopes survive a UDDF round trip (#1970).
/// The links themselves do not travel: UDDF carries no media or documents.
void main() {
  final now = DateTime.utc(2026, 3, 1);
  final tag = Tag(
    id: 't1',
    name: 'Wreck',
    createdAt: now,
    updatedAt: now,
    scopes: const {TagScope.dives, TagScope.media, TagScope.documents},
  );

  test('a tag definition round-trips its media and document scopes', () async {
    final doc = XmlDocument.parse(
      await UddfFullExportService().generateAllDataXmlForTest(
        dives: const [],
        tags: [tag],
      ),
    );
    final element = doc
        .findAllElements('tag')
        .singleWhere((e) => e.getAttribute('id') == 'tag_t1');

    final parsed = UddfImportParsers.parseTag(element);

    expect(importedTagScopes(parsed), tag.scopes);
  });

  test('a file without the flags imports neither scope', () {
    final element = XmlDocument.parse(
      '<tag id="tag_t1"><name>Wreck</name></tag>',
    ).rootElement;

    expect(importedTagScopes(UddfImportParsers.parseTag(element)), {
      TagScope.dives,
    });
  });
}
