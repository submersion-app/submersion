import 'package:xml/xml.dart';

/// UDDF writer for tag references, shared by every record that carries
/// tags outside a dive: dive sites (issue #1765) and equipment items (issue
/// #1942). Each reference names a `<tag id="tag_ID">` definition under
/// `<applicationdata><submersion><tags>`, which the full importer resolves.
class UddfTagWriters {
  const UddfTagWriters._();

  /// `<tags><tagref>tag_ID</tagref>...</tags>` for [tagIds], or nothing
  /// when there are none.
  static void writeTagRefs(XmlBuilder builder, List<String> tagIds) {
    if (tagIds.isEmpty) return;
    builder.element(
      'tags',
      nest: () {
        for (final id in tagIds) {
          builder.element('tagref', nest: 'tag_$id');
        }
      },
    );
  }
}
