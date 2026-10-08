/// A header subtitle, with an optional shorter form for when the full one
/// does not fit, such as "34 of 812 dives" and "34 of 812".
///
/// The title above it names the list, so a compact form can drop the noun
/// without losing meaning; ellipsising the full one instead can cut the very
/// number it exists to show.
class SubtitleText {
  const SubtitleText(this.full, {this.compact});

  final String full;

  /// Shown in place of [full] when [full] would not fit on one line. Null
  /// leaves [full] to ellipsise.
  final String? compact;

  @override
  bool operator ==(Object other) =>
      other is SubtitleText && other.full == full && other.compact == compact;

  @override
  int get hashCode => Object.hash(full, compact);

  @override
  String toString() => 'SubtitleText($full, compact: $compact)';
}
