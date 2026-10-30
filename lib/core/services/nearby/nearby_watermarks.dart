/// For each device whose writes a library holds, the highest clock held
/// from it. Exchanged at the start of every nearby sync direction.
class NearbyWatermarks {
  const NearbyWatermarks(this.highByWriter);

  final Map<String, String> highByWriter;

  bool get isEmpty => highByWriter.isEmpty;

  Map<String, Object?> toJson() => {'high': highByWriter};

  /// Throws [FormatException] on anything but a map of strings.
  factory NearbyWatermarks.fromJson(Map<String, Object?> json) {
    final high = json['high'];
    if (high is! Map) throw const FormatException('watermarks.high');
    for (final e in high.entries) {
      if (e.key is! String || e.value is! String) {
        throw const FormatException('watermarks entry');
      }
    }
    return NearbyWatermarks({
      for (final e in high.entries) e.key as String: e.value as String,
    });
  }

  /// The device that issued [hlc]: the node id after the packed form's two
  /// fixed-width fields, or null when [hlc] is not in that form.
  static String? writerOf(String hlc) {
    if (hlc.length <= 23 || hlc[15] != ':' || hlc[22] != ':') return null;
    return hlc.substring(23);
  }
}
