import 'dart:io';

import 'package:xml/xml.dart';

/// The value element that follows [key] in [dict].
XmlElement? dictValue(XmlElement dict, String key) {
  final children = dict.childElements.toList();
  for (var i = 0; i + 1 < children.length; i++) {
    if (children[i].name.local == 'key' &&
        children[i].innerText.trim() == key) {
      return children[i + 1];
    }
  }
  return null;
}

/// The value element that follows [key] in a plist's top-level dict.
XmlElement? plistValue(String path, String key) => dictValue(
  XmlDocument.parse(
    File(path).readAsStringSync(),
  ).rootElement.getElement('dict')!,
  key,
);
