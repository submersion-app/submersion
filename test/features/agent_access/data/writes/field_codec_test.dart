import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';

enum _Mood { calm, rough }

Matcher _refused(String reasonPart) => throwsA(
  isA<FieldRefusal>().having((e) => e.reason, 'reason', contains(reasonPart)),
);

void main() {
  test('number outside its range is refused', () {
    const codec = FieldCodec.number(min: 0, max: 350);
    expect(codec.parse(40.5), 40.5);
    expect(codec.parse(40), 40.0);
    expect(() => codec.parse(351), _refused('350'));
    expect(() => codec.parse(-1), _refused('0'));
    expect(() => codec.parse('40'), _refused('number'));
  });

  test('null on a required field is refused', () {
    expect(() => const FieldCodec.text().parse(null), _refused('required'));
    expect(() => const FieldCodec.flag().parse(null), _refused('required'));
    expect(
      () => const FieldCodec.wallClock().parse(null),
      _refused('required'),
    );
  });

  test('null on a nullable field stays null', () {
    expect(const FieldCodec.text(nullable: true).parse(null), isNull);
    expect(const FieldCodec.number(nullable: true).parse(null), isNull);
    expect(const FieldCodec.integer(nullable: true).parse(null), isNull);
    expect(
      FieldCodec.enumName(_Mood.values, nullable: true).parse(null),
      isNull,
    );
  });

  test('a reference takes an id and names what it points at', () {
    const codec = FieldCodec.reference('dives');
    expect(codec.parse('d1'), 'd1');
    expect(codec, isA<ReferenceCodec>());
    expect((codec as ReferenceCodec).refEntity, 'dives');
    expect(() => codec.parse(''), _refused('id'));
    expect(() => codec.parse('  '), _refused('id'));
    expect(() => codec.parse(7), _refused('id'));
    expect(() => codec.parse(null), _refused('required'));
    expect(
      const FieldCodec.reference('species', nullable: true).parse(null),
      isNull,
    );
  });

  test('a blank required text is refused', () {
    expect(() => const FieldCodec.text().parse('   '), _refused('blank'));
    expect(const FieldCodec.text(nullable: true).parse(''), '');
  });

  test('a required text may allow a blank but not a clear', () {
    const codec = FieldCodec.text(allowBlank: true);
    expect(codec.parse(''), '');
    expect(() => codec.parse(null), _refused('required'));
  });

  test('text keeps inner whitespace', () {
    expect(const FieldCodec.text().parse('Blue  Hole\n2'), 'Blue  Hole\n2');
  });

  // A repository that trims a name stores it trimmed, so the plan shows it so.
  test('a trimming text parses to the trimmed value', () {
    const codec = FieldCodec.text(trim: true);
    expect(codec.parse('  Wreck '), 'Wreck');
    expect(const FieldCodec.text().parse(' Wreck '), ' Wreck ');
  });

  // What is stored is the trimmed text, so that is what must fit.
  test('a trimming text measures its length after trimming', () {
    expect(
      const FieldCodec.text(maxLength: 3, trim: true).parse('  abc '),
      'abc',
    );
    const list = FieldCodec.textList(maxLength: 3);
    expect(list.wire(list.parse([' abc '])), ['abc']);
  });

  // A repository that trims a nullable text stores a blank one as null.
  test('a trimming nullable text reads a blank as null', () {
    const codec = FieldCodec.text(nullable: true, trim: true);
    expect(codec.parse('   '), isNull);
    expect(codec.parse(' L '), 'L');
  });

  // A table that keeps a tenth of a percent cannot hold a finer fraction.
  test('a number with fraction digits parses rounded', () {
    const codec = FieldCodec.number(min: 0, max: 1, fractionDigits: 3);
    expect(codec.parse(0.3214), 0.321);
    expect(codec.parse(0.3216), 0.322);
    expect(codec.canonical(0.052000000000000005), 0.052);
  });

  test('text over its limit is refused', () {
    expect(
      () => const FieldCodec.text(maxLength: 3).parse('abcd'),
      _refused('3'),
    );
  });

  test('an integer refuses a fraction', () {
    const codec = FieldCodec.integer(min: 0, max: 5);
    expect(codec.parse(3), 3);
    expect(() => codec.parse(3.5), _refused('whole'));
    expect(() => codec.parse(6), _refused('5'));
  });

  test('a flag takes only a boolean', () {
    expect(const FieldCodec.flag().parse(true), true);
    expect(() => const FieldCodec.flag().parse(1), _refused('true or false'));
  });

  test('an enum refuses a name it does not have and lists the names', () {
    final codec = FieldCodec.enumName(_Mood.values);
    expect(codec.parse('calm'), 'calm');
    expect(() => codec.parse('wild'), _refused('calm, rough'));
  });

  test('a wall clock reads with a nominal Z', () {
    const codec = FieldCodec.wallClock();
    final value = codec.parse('2024-03-14T09:30:00.000Z');
    expect(value, DateTime.utc(2024, 3, 14, 9, 30));
    expect(codec.wire(value), '2024-03-14T09:30:00.000Z');
  });

  test('a wall clock with an offset is refused', () {
    expect(
      () => const FieldCodec.wallClock().parse('2024-03-14T09:30:00+02:00'),
      _refused('Z'),
    );
    expect(
      () => const FieldCodec.wallClock().parse('2024-03-14T09:30:00'),
      _refused('Z'),
    );
    expect(
      () => const FieldCodec.wallClock().parse('yesterday'),
      _refused('Z'),
    );
    // DateTime rolls a minute or second past 59 into the next one, which
    // keeps the date, so only the whole clock read back catches it.
    expect(
      () => const FieldCodec.wallClock().parse('2024-03-14T10:75:00Z'),
      _refused('Z'),
    );
    expect(
      () => const FieldCodec.wallClock().parse('2024-03-14T10:15:99Z'),
      _refused('Z'),
    );
    expect(
      () => const FieldCodec.wallClock().parse('2024-03-14T10:75Z'),
      _refused('Z'),
    );
  });

  test('a date that does not exist is refused', () {
    expect(
      () => const FieldCodec.wallClock().parse('2024-02-31T10:00:00Z'),
      _refused('Z'),
    );
  });

  test('canonical makes a document value comparable with a parsed one', () {
    const number = FieldCodec.number();
    expect(number.canonical(24), number.parse(24.0));
    const clock = FieldCodec.wallClock();
    expect(
      clock.canonical('2024-03-14T09:30:00.000Z'),
      clock.parse('2024-03-14T09:30:00Z'),
    );
    expect(clock.canonical(null), isNull);
  });

  // A set compares by its members, whatever order a document lists them in.
  test('enumSet parses names into a sorted list', () {
    final codec = FieldCodec.enumSet(_Mood.values);
    final parsed = codec.parse(['rough', 'calm']);
    expect(codec.wire(parsed), ['calm', 'rough']);
    expect(parsed, codec.canonical(['calm', 'rough']));
    expect(parsed, codec.canonical(['rough', 'calm']));
    expect(codec.wire(codec.parse(<String>[])), isEmpty);
  });

  test('textList keeps the order and compares with a document list', () {
    const codec = FieldCodec.textList(maxItems: 3, maxLength: 10);
    final parsed = codec.parse(['PADI', 'SSI']);
    expect(codec.wire(parsed), ['PADI', 'SSI']);
    expect(parsed, codec.canonical(['PADI', 'SSI']));
    expect(parsed, isNot(codec.canonical(['SSI', 'PADI'])));
  });

  // A column keeping the list joined by a separator splits an item holding
  // it, and its reader trims each item.
  test('textList trims items and refuses its separator inside one', () {
    const codec = FieldCodec.textList(maxLength: 20, separator: ',');
    expect(codec.wire(codec.parse([' PADI ', 'SSI'])), ['PADI', 'SSI']);
    expect(() => codec.parse(['PADI, Inc']), _refused(','));
  });

  test('textList refuses a blank, a long item or too many', () {
    const codec = FieldCodec.textList(maxItems: 2, maxLength: 5);
    expect(() => codec.parse(['PADI', ' ']), _refused('blank'));
    expect(() => codec.parse(['TOOLONG']), _refused('5'));
    expect(() => codec.parse(['A', 'B', 'C']), _refused('2'));
    expect(() => codec.parse('PADI'), _refused('list'));
  });

  test('enumSet refuses an unknown name, a repeat or too few', () {
    final codec = FieldCodec.enumSet(_Mood.values, min: 1);
    expect(() => codec.parse(['calm', 'stormy']), _refused('calm, rough'));
    expect(() => codec.parse(['calm', 'calm']), _refused('more than once'));
    expect(() => codec.parse(<String>[]), _refused('at least 1'));
    expect(() => codec.parse('calm'), _refused('list'));
  });
}
