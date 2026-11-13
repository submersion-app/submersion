import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';

/// One kind of exposure suit, for the Insights Suit Type chart and the Focus
/// "Suit" factor (issues #1824, #4490): a drysuit, or a wetsuit with the
/// curated primary thickness and suit style it records, either of which may
/// be missing.
///
/// A drysuit carries neither. It keeps a diver warm through its undersuit
/// rather than its shell, so every drysuit shares one bucket.
class SuitType implements Comparable<SuitType> {
  const SuitType.drysuit() : isDrysuit = true, mm = null, style = null;

  const SuitType.wetsuit({this.mm, this.style}) : isDrysuit = false;

  final bool isDrysuit;

  /// Primary thickness in millimetres; null when the wetsuit records none.
  final double? mm;

  /// The `suit_style` choice key (`full`, `shorty`, ...) as stored; null
  /// when the wetsuit records none.
  final String? style;

  /// [mm] as shown: "5" for a whole number, "6.5" otherwise.
  String? get thicknessText {
    final value = mm;
    if (value == null) return null;
    return value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
  }

  /// `drysuit`, or `wetsuit:<mm>:<style>` with a missing part left empty.
  String get key =>
      isDrysuit ? 'drysuit' : 'wetsuit:${thicknessText ?? ''}:${style ?? ''}';

  /// The suit type a [key] names, or null when it names none. Accepts the
  /// thickness as SQLite renders a REAL ("5.0"), so `fromKey(raw).key` is
  /// the canonical key.
  static SuitType? fromKey(String key) {
    if (key == 'drysuit') return const SuitType.drysuit();
    const prefix = 'wetsuit:';
    if (!key.startsWith(prefix)) return null;
    final rest = key.substring(prefix.length);
    final split = rest.indexOf(':');
    final mmText = split < 0 ? rest : rest.substring(0, split);
    final style = split < 0 ? '' : rest.substring(split + 1);
    return SuitType.wetsuit(
      mm: double.tryParse(mmText),
      style: style.isEmpty ? null : style,
    );
  }

  static final List<String> _styleOrder =
      EquipmentAttributeCatalog.defFor(
        EquipmentAttrKeys.suitStyle,
      )?.choiceKeys ??
      const [];

  /// Wetsuits by thickness ascending, then style in catalog order (a style
  /// outside the catalog after the known ones), each missing part last; the
  /// drysuit after every wetsuit.
  @override
  int compareTo(SuitType other) {
    if (isDrysuit != other.isDrysuit) return isDrysuit ? 1 : -1;
    final byMm = _compareNullsLast(mm, other.mm, (a, b) => a.compareTo(b));
    if (byMm != 0) return byMm;
    return _compareNullsLast(style, other.style, _compareStyles);
  }

  static int _compareStyles(String a, String b) {
    final ia = _styleOrder.indexOf(a);
    final ib = _styleOrder.indexOf(b);
    if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
    if (ia >= 0) return -1;
    if (ib >= 0) return 1;
    return a.compareTo(b);
  }

  static int _compareNullsLast<T>(T? a, T? b, int Function(T, T) compare) {
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return compare(a, b);
  }

  @override
  bool operator ==(Object other) =>
      other is SuitType &&
      other.isDrysuit == isDrysuit &&
      other.mm == mm &&
      other.style == style;

  @override
  int get hashCode => Object.hash(isDrysuit, mm, style);

  @override
  String toString() => 'SuitType($key)';
}

/// Dives per suit type, in [SuitType] order. Each count is a number of
/// distinct dives, but a dive linked to suits of more than one type is
/// counted once under each.
typedef SuitTypeStats = List<({SuitType type, int count})>;
