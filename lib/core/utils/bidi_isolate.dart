import 'package:flutter/widgets.dart';

/// [text] kept left to right inside right-to-left text. Without the
/// isolate, bidi reordering can move a signed number's sign to its far end
/// ("0.12-") in Hebrew or Arabic.
String isolateForDirection(String text, TextDirection direction) =>
    direction == TextDirection.rtl ? '\u2066$text\u2069' : text;
