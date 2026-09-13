import 'package:submersion/core/constants/enums.dart';

/// An exposure suit read from free text: its type, and the thickness
/// designation when the text states exactly one (wetsuits only).
typedef SuitClassification = ({EquipmentType type, String? thickness});

/// Classifies a suit as written in an imported log's suit field (issue
/// #1824), so an imported suit can reach the Suit Thickness statistic.
///
/// Returns null when the text does not say which suit it is: the caller then
/// keeps whatever it did before, rather than the classifier guessing. Rules,
/// first match wins:
///
/// 1. A garment worn under or instead of a suit (undersuit, base layer, rash
///    guard, skin suit) is not a suit: null. "Dry undersuit" is a real
///    product and must not read as a drysuit.
/// 2. A semi-dry is a wetsuit (the attribute catalog lists it as a wetsuit
///    style), even though it contains "dry".
/// 3. Text naming both wet and dry is ambiguous: null.
/// 4. The word "dry" or "drysuit", or a membrane or trilaminate suit:
///    drysuit. Neoprene drysuits are sold by thickness, so "dry" beats "mm",
///    and a drysuit records no thickness because the catalog gives it none.
/// 5. The word "wet" or "wetsuit", a shorty, or a thickness token: wetsuit.
///
/// Text that names an accessory (hood, gloves, boots, vest, ...) classifies
/// only through an explicit suit word ("drysuit", "wet suit"): "Dry gloves"
/// and "5mm hood" describe the accessory, not the suit.
///
/// A thickness token is a number with `mm` ("7mm", "6.5 mm") or a slash
/// designation ("5/4", "7/5/3mm") whose panels are each above 0 and at most
/// 15 mm and are written thickest first, as suits are labelled; "1/4" is a
/// fraction, not a suit. A bare number is not one: in "Bare 5" it could be a
/// size or a model. The thickness is recorded only when the text holds
/// exactly one token and names no accessory, because in "Wetsuit, 5mm hood"
/// the 5 mm is the hood's.
SuitClassification? classifySuit(String? text) {
  final s = text?.trim().toLowerCase();
  if (s == null || s.isEmpty) return null;

  if (_notASuit.hasMatch(s)) return null;

  final hasAccessory = _accessory.hasMatch(s);
  final thickness = hasAccessory ? null : _singleThickness(s);

  if (_semiDry.hasMatch(s)) {
    return (type: EquipmentType.wetsuit, thickness: thickness);
  }

  final saysDry = hasAccessory
      ? _drysuitWord.hasMatch(s)
      : _dryWord.hasMatch(s) || _drysuitStyle.hasMatch(s);
  final saysWet = hasAccessory
      ? _wetsuitWord.hasMatch(s)
      : _wetWord.hasMatch(s) || _wetsuitStyle.hasMatch(s);
  if (saysDry && saysWet) return null;
  if (saysDry) return (type: EquipmentType.drysuit, thickness: null);
  // A token alone names a wetsuit only here, after nothing said dry, and it
  // is already null when an accessory is named.
  if (saysWet || thickness != null) {
    return (type: EquipmentType.wetsuit, thickness: thickness);
  }
  return null;
}

final RegExp _notASuit = RegExp(
  r'under\s?suit|under\s?garment|base[\s-]?layer|rash[\s-]?guard|skin\s?suit',
);

/// Whole words only, forms spelled out: "hooded" describes a suit ("7mm
/// hooded wetsuit"), while "hoodie" and "booties" are accessories.
final RegExp _accessory = RegExp(
  r'\b(?:hoods?|hoodies?|gloves?|boots?|booties?|mitts?|mittens?|socks?'
  r'|vests?|jackets?)\b',
);
final RegExp _semiDry = RegExp(r'\bsemi[\s-]?dry');
final RegExp _dryWord = RegExp(r'\bdry(?:[\s-]?suits?)?\b');
final RegExp _wetWord = RegExp(r'\bwet(?:[\s-]?suits?)?\b');
final RegExp _drysuitWord = RegExp(r'\bdry[\s-]?suits?\b');
final RegExp _wetsuitWord = RegExp(r'\bwet[\s-]?suits?\b');
final RegExp _drysuitStyle = RegExp(r'\b(?:membrane|trilam)');
final RegExp _wetsuitStyle = RegExp(r'\bshort(?:y|ie)');

const String _panel = r'\d+(?:\.\d+)?';

/// A slash designation ("5/4", "5mm/4mm", "7/5/3mm") or a single panel with
/// `mm`. The guards keep a token from starting or ending inside a longer
/// number or word: a hyphen or slash beside it means it is only part of a
/// designation ("5-4mm"), and a comma or period only joins digits, as a
/// decimal. "6,5mm" is therefore none and "5/4,5" is not cut to "5/4", while
/// "7mm, 3mm" and "7mm,3mm" are two tokens: nothing numeric continues past
/// "mm".
final RegExp _thicknessToken = RegExp(
  '(?<![\\w/\\-]|\\d[.,])'
  '(?:$_panel(?:\\s*mm)?(?:\\s*/\\s*$_panel(?:\\s*mm)?)+|$_panel\\s*mm)'
  '(?![\\w/\\-])(?!(?<=\\d)[.,]\\d)',
);
final RegExp _panelNumber = RegExp(_panel);

/// The one thickness token in [s], or null when there is none, more than one
/// distinct token, or a token whose panels are outside (0, 15] mm or not
/// written thickest first.
String? _singleThickness(String s) {
  final tokens = {for (final m in _thicknessToken.allMatches(s)) m.group(0)!};
  if (tokens.length != 1) return null;
  final token = tokens.single;
  final panels = [
    for (final m in _panelNumber.allMatches(token)) double.parse(m.group(0)!),
  ];
  final inRange = panels.every((mm) => mm > 0 && mm <= 15);
  final thickestFirst = [
    for (var i = 1; i < panels.length; i++) panels[i] <= panels[i - 1],
  ].every((ok) => ok);
  return inRange && thickestFirst ? token : null;
}
