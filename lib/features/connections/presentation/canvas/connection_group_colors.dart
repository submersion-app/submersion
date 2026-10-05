import 'package:flutter/painting.dart';

/// Group fills for the Groups highlight mode, largest group first. Mid tones
/// that carry the white node glyphs and read on light, dark and the share
/// image's navy.
const List<Color> kConnectionGroupColors = [
  Color(0xFFEF6C00),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFF8E24AA),
  Color(0xFFE53935),
  Color(0xFF00838F),
  Color(0xFF827717),
  Color(0xFFD81B60),
];

/// Nodes in no group, or in a group past the palette.
const Color kConnectionUngroupedColor = Color(0xFF9E9E9E);
