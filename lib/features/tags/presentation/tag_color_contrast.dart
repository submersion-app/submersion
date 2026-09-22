import 'package:flutter/material.dart';

/// The label colour for text written on [background] (issue #2254).
///
/// A tag chip is filled with the diver's own colour, so it cannot take its
/// label colour from the theme: the palette runs from a pale yellow to a
/// near-black slate, and either extreme swallows one of the two. The choice
/// is made on WCAG 2.1 contrast ratio rather than a luminance threshold,
/// because the crossover point between black and white sits at a luminance
/// of about 0.18 and a threshold picked by eye lands on the wrong side of
/// the palette's mid tones.
///
/// Both candidates are opaque, so nothing behind the chip shows through the
/// label.
Color tagForegroundColor(Color background) {
  return _contrast(Colors.black, background) >=
          _contrast(Colors.white, background)
      ? Colors.black
      : Colors.white;
}

/// WCAG 2.1 contrast ratio between two opaque colours, from 1 (identical) to
/// 21 (black on white).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
