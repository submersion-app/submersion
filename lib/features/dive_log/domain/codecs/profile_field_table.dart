/// How a field's column block is written.
enum ProfileFieldKind {
  /// Zigzag varint of the difference from the previous present value; the
  /// previous value starts at 0 for each block.
  deltaInt,

  /// IEEE-754 binary64, little-endian.
  float64,

  /// Runs of identical strings: run count, then (length, UTF-8 length,
  /// UTF-8 bytes) per run, covering the present values only.
  runLengthString,
}

/// One entry of a field table. [name] is the column name the v181
/// `dive_profiles` table used.
class ProfileField {
  const ProfileField(this.name, this.kind);

  final String name;
  final ProfileFieldKind kind;
}

/// Codec v1: every sample column the v181 `dive_profiles` table stored (the
/// codec's column order). Never reorder or remove an entry; append under a
/// new version instead.
const List<ProfileField> kProfileFieldTableV1 = [
  ProfileField('timestamp', ProfileFieldKind.deltaInt),
  ProfileField('depth', ProfileFieldKind.float64),
  ProfileField('pressure', ProfileFieldKind.float64),
  ProfileField('temperature', ProfileFieldKind.float64),
  ProfileField('heart_rate', ProfileFieldKind.deltaInt),
  ProfileField('ascent_rate', ProfileFieldKind.float64),
  ProfileField('ceiling', ProfileFieldKind.float64),
  ProfileField('ndl', ProfileFieldKind.deltaInt),
  ProfileField('setpoint', ProfileFieldKind.float64),
  ProfileField('pp_o2', ProfileFieldKind.float64),
  ProfileField('o2_sensor1', ProfileFieldKind.float64),
  ProfileField('o2_sensor2', ProfileFieldKind.float64),
  ProfileField('o2_sensor3', ProfileFieldKind.float64),
  ProfileField('o2_sensor4', ProfileFieldKind.float64),
  ProfileField('o2_sensor5', ProfileFieldKind.float64),
  ProfileField('o2_sensor6', ProfileFieldKind.float64),
  ProfileField('cns', ProfileFieldKind.float64),
  ProfileField('tts', ProfileFieldKind.deltaInt),
  ProfileField('rbt', ProfileFieldKind.deltaInt),
  ProfileField('deco_type', ProfileFieldKind.deltaInt),
  ProfileField('heart_rate_source', ProfileFieldKind.runLengthString),
  ProfileField('heading', ProfileFieldKind.float64),
  ProfileField('o2_sensor_mv1', ProfileFieldKind.deltaInt),
  ProfileField('o2_sensor_mv2', ProfileFieldKind.deltaInt),
  ProfileField('o2_sensor_mv3', ProfileFieldKind.deltaInt),
  ProfileField('o2_sensor_mv4', ProfileFieldKind.deltaInt),
  ProfileField('o2_sensor_mv5', ProfileFieldKind.deltaInt),
  ProfileField('o2_sensor_mv6', ProfileFieldKind.deltaInt),
];
