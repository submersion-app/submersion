import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_field_table.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

/// The v1 field table, frozen. It used to be cross-checked against the
/// `dive_profiles` Drift columns; v183 dropped that table, and a frozen list
/// is what the invariant actually needs: every blob already on disk (and on
/// every peer) was written against this exact order, so an entry may never be
/// reordered, renamed, or removed. A new sample field is appended under a NEW
/// codec version, never here.
const frozenFieldTableV1 = <(String, ProfileFieldKind)>[
  ('timestamp', ProfileFieldKind.deltaInt),
  ('depth', ProfileFieldKind.float64),
  ('pressure', ProfileFieldKind.float64),
  ('temperature', ProfileFieldKind.float64),
  ('heart_rate', ProfileFieldKind.deltaInt),
  ('ascent_rate', ProfileFieldKind.float64),
  ('ceiling', ProfileFieldKind.float64),
  ('ndl', ProfileFieldKind.deltaInt),
  ('setpoint', ProfileFieldKind.float64),
  ('pp_o2', ProfileFieldKind.float64),
  ('o2_sensor1', ProfileFieldKind.float64),
  ('o2_sensor2', ProfileFieldKind.float64),
  ('o2_sensor3', ProfileFieldKind.float64),
  ('o2_sensor4', ProfileFieldKind.float64),
  ('o2_sensor5', ProfileFieldKind.float64),
  ('o2_sensor6', ProfileFieldKind.float64),
  ('cns', ProfileFieldKind.float64),
  ('tts', ProfileFieldKind.deltaInt),
  ('rbt', ProfileFieldKind.deltaInt),
  ('deco_type', ProfileFieldKind.deltaInt),
  ('heart_rate_source', ProfileFieldKind.runLengthString),
  ('heading', ProfileFieldKind.float64),
  ('o2_sensor_mv1', ProfileFieldKind.deltaInt),
  ('o2_sensor_mv2', ProfileFieldKind.deltaInt),
  ('o2_sensor_mv3', ProfileFieldKind.deltaInt),
  ('o2_sensor_mv4', ProfileFieldKind.deltaInt),
  ('o2_sensor_mv5', ProfileFieldKind.deltaInt),
  ('o2_sensor_mv6', ProfileFieldKind.deltaInt),
];

void main() {
  test('codec v1 carries exactly the frozen field table, in order', () {
    expect(
      [for (final f in ProfileSeriesCodec.fieldTableV1) (f.name, f.kind)],
      frozenFieldTableV1,
      reason:
          'fieldTableV1 changed. Every blob already written (here and on '
          'every peer) decodes against this exact order. Append the new '
          'field under a NEW version in ProfileSeriesCodec; never edit '
          'fieldTableV1.',
    );
  });

  test('the field table covers every ProfileSample field', () {
    // Anchored on the live type, not a second copy of the list above: a
    // sample field added without a matching field-table entry would be
    // silently dropped on encode, and this is what says so.
    expect(
      kProfileFieldTableV1.length,
      const ProfileSample(timestamp: 0, depth: 0.0).props.length,
    );
  });

  test('the tank codec covers every TankPressureSample field', () {
    const sample = TankPressureSample(timestamp: 30, pressure: 180.0);
    // The tank codec has no field table: it writes the two columns inline.
    // Anchor that count on the live type the same way, so a third field
    // cannot be added without this failing.
    expect(sample.props, hasLength(2));
    const codec = TankPressureSeriesCodec();
    final decoded = codec.decode(codec.encode(const [sample]).bytes);
    expect(decoded.single.props, sample.props);
  });
}
