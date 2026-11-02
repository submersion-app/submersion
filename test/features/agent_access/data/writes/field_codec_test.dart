import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';

enum _Mood { calm, rough }

Matcher _refused(String reasonPart) => throwsA(
  isA<FieldRefusal>().having((e) => e.reason, 'reason', contains(reasonPart)),
);

void main() {
  test('number outside its range is refused', () {
    final codec = FieldCodec.number(min: 0, max: 350);
    expect(codec.parse(40.5), 40.5);
    expect(codec.parse(40), 40.0);
    expect(() => codec.parse(351), _refused('350'));
    expect(() => codec.parse(-1), _refused('0'));
    expect(() => codec.parse('40'), _refused('number'));
  });

  test('null on a required field is refused', () {
    expect(() => FieldCodec.text().parse(null), _refused('required'));
    expect(() => FieldCodec.flag().parse(null), _refused('required'));
    expect(() => FieldCodec.wallClock().parse(null), _refused('required'));
  });

  test('null on a nullable field stays null', () {
    expect(FieldCodec.text(nullable: true).parse(null), isNull);
    expect(FieldCodec.number(nullable: true).parse(null), isNull);
    expect(FieldCodec.integer(nullable: true).parse(null), isNull);
    expect(
      FieldCodec.enumName(_Mood.values, nullable: true).parse(null),
      isNull,
    );
  });

  test('a blank required text is refused', () {
    expect(() => FieldCodec.text().parse('   '), _refused('blank'));
    expect(FieldCodec.text(nullable: true).parse(''), '');
  });

  test('text keeps inner whitespace', () {
    expect(FieldCodec.text().parse('Blue  Hole\n2'), 'Blue  Hole\n2');
  });

  test('text over its limit is refused', () {
    expect(() => FieldCodec.text(maxLength: 3).parse('abcd'), _refused('3'));
  });

  test('an integer refuses a fraction', () {
    final codec = FieldCodec.integer(min: 0, max: 5);
    expect(codec.parse(3), 3);
    expect(() => codec.parse(3.5), _refused('whole'));
    expect(() => codec.parse(6), _refused('5'));
  });

  test('a flag takes only a boolean', () {
    expect(FieldCodec.flag().parse(true), true);
    expect(() => FieldCodec.flag().parse(1), _refused('true or false'));
  });

  test('an enum refuses a name it does not have and lists the names', () {
    final codec = FieldCodec.enumName(_Mood.values);
    expect(codec.parse('calm'), 'calm');
    expect(() => codec.parse('wild'), _refused('calm, rough'));
  });

  test('a wall clock reads with a nominal Z', () {
    final codec = FieldCodec.wallClock();
    final value = codec.parse('2024-03-14T09:30:00.000Z');
    expect(value, DateTime.utc(2024, 3, 14, 9, 30));
    expect(codec.wire(value), '2024-03-14T09:30:00.000Z');
  });

  test('a wall clock with an offset is refused', () {
    expect(
      () => FieldCodec.wallClock().parse('2024-03-14T09:30:00+02:00'),
      _refused('Z'),
    );
    expect(
      () => FieldCodec.wallClock().parse('2024-03-14T09:30:00'),
      _refused('Z'),
    );
    expect(() => FieldCodec.wallClock().parse('yesterday'), _refused('Z'));
  });

  test('canonical makes a document value comparable with a parsed one', () {
    final number = FieldCodec.number();
    expect(number.canonical(24), number.parse(24.0));
    final clock = FieldCodec.wallClock();
    expect(
      clock.canonical('2024-03-14T09:30:00.000Z'),
      clock.parse('2024-03-14T09:30:00Z'),
    );
    expect(clock.canonical(null), isNull);
  });
}
