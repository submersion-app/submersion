import 'dart:io';

import 'package:xml/xml.dart';

const String kPropfindBody =
    '<?xml version="1.0" encoding="utf-8"?>'
    '<d:propfind xmlns:d="DAV:"><d:prop>'
    '<d:resourcetype/><d:getcontentlength/><d:getlastmodified/>'
    '</d:prop></d:propfind>';

/// One `<response>` of a PROPFIND reply.
class DavResource {
  /// Decoded, non-empty segments of the server path (`/a%20b/` gives
  /// `['a b']`), whatever form the server wrote the href in.
  final List<String> pathSegments;
  final bool isCollection;
  final int? contentLength;
  final DateTime? lastModified;

  const DavResource({
    required this.pathSegments,
    required this.isCollection,
    this.contentLength,
    this.lastModified,
  });
}

/// Parses a 207 Multi-Status body. Namespace prefixes differ by server
/// (`d:`, `D:`, a default namespace), so elements match by local name.
/// Only properties in a propstat whose status is 2xx are read.
List<DavResource> parseMultistatus(String body) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(body);
  } on XmlException catch (e) {
    throw FormatException('Not a WebDAV multistatus reply: ${e.message}');
  }
  if (doc.rootElement.name.local != 'multistatus') {
    throw const FormatException('Not a WebDAV multistatus reply');
  }
  return [
    for (final response in _children(doc.rootElement, 'response'))
      ?_resource(response),
  ];
}

DavResource? _resource(XmlElement response) {
  final href = _children(response, 'href').firstOrNull?.innerText.trim();
  if (href == null || href.isEmpty) return null;
  final segments = Uri.parse(
    href,
  ).pathSegments.where((s) => s.isNotEmpty).toList();

  var isCollection = false;
  int? length;
  DateTime? modified;
  for (final propstat in _children(response, 'propstat')) {
    final status = _children(propstat, 'status').firstOrNull?.innerText ?? '';
    if (!RegExp(r'\s2\d\d\s').hasMatch(' $status ')) continue;
    for (final prop in _children(propstat, 'prop')) {
      if (_descendants(prop, 'collection').isNotEmpty) isCollection = true;
      final len = _children(
        prop,
        'getcontentlength',
      ).firstOrNull?.innerText.trim();
      if (len != null && len.isNotEmpty) length = int.tryParse(len);
      final lm = _children(
        prop,
        'getlastmodified',
      ).firstOrNull?.innerText.trim();
      if (lm != null && lm.isNotEmpty) modified = _parseDate(lm);
    }
  }
  return DavResource(
    pathSegments: segments,
    isCollection: isCollection,
    contentLength: length,
    lastModified: modified,
  );
}

DateTime? _parseDate(String value) {
  try {
    return HttpDate.parse(value);
  } on HttpException {
    return DateTime.tryParse(value)?.toUtc();
  }
}

Iterable<XmlElement> _children(XmlElement parent, String local) =>
    parent.childElements.where((e) => e.name.local == local);

Iterable<XmlElement> _descendants(XmlElement parent, String local) =>
    parent.descendantElements.where((e) => e.name.local == local);
