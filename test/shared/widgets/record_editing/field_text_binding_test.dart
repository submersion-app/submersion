import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// A record with an altitude held in metres and shown in feet, so the tests
/// cross a unit conversion that does not round-trip exactly.
@immutable
class _Rec {
  const _Rec({this.altitude, this.note = ''});

  final double? altitude;
  final String note;

  @override
  bool operator ==(Object other) =>
      other is _Rec && other.altitude == altitude && other.note == note;

  @override
  int get hashCode => Object.hash(altitude, note);
}

const _metresPerFoot = 0.3048;

String _feet(double? metres) =>
    metres == null ? '' : (metres / _metresPerFoot).toStringAsFixed(0);

String _metres(double? metres) =>
    metres == null ? '' : metres.toStringAsFixed(0);

/// Two altitudes are the same when the diver sees the same number.
final _altitude = EditField<_Rec, double?>(
  id: 'altitude',
  cardId: 'altitude',
  read: (r) => r.altitude,
  write: (r, v) => _Rec(altitude: v, note: r.note),
  equals: (a, b) => _feet(a) == _feet(b),
);

final _note = EditField<_Rec, String>(
  id: 'note',
  cardId: 'notes',
  read: (r) => r.note,
  write: (r, v) => _Rec(altitude: r.altitude, note: v),
);

FieldInput<double?> _parseFeet(String text) => switch (readNumber(text)) {
  NumberBlank() => const FieldValue(null),
  NumberValue(:final value) => FieldValue(value * _metresPerFoot),
  NumberInvalid() => const FieldUnreadable(),
};

void main() {
  late EditSession<_Rec> session;
  late List<bool> seen;

  FieldTextBinding<_Rec, double?> bind({
    String Function(double? metres) format = _feet,
    FieldInput<double?> Function(String text) parse = _parseFeet,
  }) {
    final binding = FieldTextBinding<_Rec, double?>(
      session: session,
      field: _altitude,
      format: format,
      parse: parse,
      onUnreadableChanged: seen.add,
    );
    addTearDown(binding.dispose);
    return binding;
  }

  setUp(() {
    session = EditSession(const _Rec(altitude: 1234.5));
    addTearDown(session.dispose);
    seen = [];
  });

  test('starts with the formatted value and does not dirty the session', () {
    final binding = bind();

    expect(binding.controller.text, '4050');
    expect(session.isDirty, isFalse);
    expect(binding.isUnreadable, isFalse);
    expect(seen, isEmpty);
  });

  test('moving the caret is not an edit', () {
    final binding = bind();

    binding.controller.selection = const TextSelection.collapsed(offset: 1);

    expect(session.isDirty, isFalse);
  });

  test('typing a readable value sets the field in canonical units', () {
    final binding = bind();

    binding.controller.text = '100';

    expect(session.valueOf(_altitude), closeTo(30.48, 0.001));
    expect(session.changedCardIds, {'altitude'});
  });

  test('emptying the text sets the field to null', () {
    final binding = bind();

    binding.controller.text = '';

    expect(session.valueOf(_altitude), isNull);
    expect(session.isDirty, isTrue);
  });

  test('unreadable text leaves the session alone and is reported once', () {
    final binding = bind();

    binding.controller.text = '1.2.3';
    binding.controller.text = '1.2.3.4';

    expect(session.isDirty, isFalse);
    expect(binding.isUnreadable, isTrue);
    expect(seen, [true]);

    binding.controller.text = '12';

    expect(seen, [true, false]);
    expect(binding.isUnreadable, isFalse);
    expect(session.valueOf(_altitude), closeTo(12 * _metresPerFoot, 0.001));
  });

  // 4050 ft reads back as 1,234.44 m, not the 1,234.5 m that is stored. The
  // field's own equality is what makes that the same altitude.
  test('typing the shown value back clears the change', () {
    final binding = bind();

    binding.controller.text = '100';
    expect(session.isDirty, isTrue);

    binding.controller.text = '4050';

    expect(session.isDirty, isFalse);
    expect(session.valueOf(_altitude), 1234.5);
  });

  test('an untouched field follows a change to the stored record', () {
    final binding = bind();

    session.rebase(const _Rec(altitude: 2000));

    expect(binding.controller.text, '6562');
    expect(session.isDirty, isFalse);
  });

  // The diver can be in the field when its value is replaced underneath: a
  // lookup returns, or the stored record changes. The caret stays where it
  // was, as it does in Notes.
  test('text replaced from the session keeps the caret', () {
    final binding = bind();
    binding.controller.selection = const TextSelection.collapsed(offset: 2);

    session.rebase(const _Rec(altitude: 2000));
    expect(binding.controller.text, '6562');
    expect(
      binding.controller.selection,
      const TextSelection.collapsed(offset: 2),
    );

    // Shorter than where the caret was: it goes to the end.
    session.rebase(const _Rec(altitude: 2));
    expect(binding.controller.text, '7');
    expect(
      binding.controller.selection,
      const TextSelection.collapsed(offset: 1),
    );
  });

  test('text replaced in a field the diver is not in has no caret', () {
    final binding = bind();

    session.rebase(const _Rec(altitude: 2000));

    expect(binding.controller.selection.isValid, isFalse);
  });

  test('text the diver edited is kept when the stored record changes', () {
    final binding = bind();
    binding.controller.text = '100';

    session.rebase(const _Rec(altitude: 2000));

    expect(binding.controller.text, '100');
    expect(session.valueOf(_altitude), closeTo(30.48, 0.001));
  });

  test('a value set from elsewhere replaces the text', () {
    final binding = bind();

    session.set(_altitude, 304.8);

    expect(binding.controller.text, '1000');
    expect(session.valueOf(_altitude), 304.8);
  });

  test('text mid-edit that reads the same as the session is left alone', () {
    final binding = bind();
    binding.controller.text = '100.';

    session.set(_note, 'x');

    expect(binding.controller.text, '100.');
  });

  test('unreadable text is left alone when the session changes', () {
    final binding = bind();
    binding.controller.text = '1.2.3';

    session
      ..set(_note, 'x')
      ..set(_altitude, 304.8);

    expect(binding.controller.text, '1.2.3');
    expect(binding.isUnreadable, isTrue);
  });

  test('resync shows an untouched value again after its format changed', () {
    var inFeet = true;
    final binding = bind(
      format: (metres) => inFeet ? _feet(metres) : _metres(metres),
      parse: (text) => switch (readNumber(text)) {
        NumberBlank() => const FieldValue(null),
        NumberValue(:final value) => FieldValue(
          inFeet ? value * _metresPerFoot : value,
        ),
        NumberInvalid() => const FieldUnreadable(),
      },
    );
    session.rebase(const _Rec(altitude: 1200));
    expect(binding.controller.text, '3937');

    inFeet = false;
    binding.resync();

    expect(binding.controller.text, '1200');
    expect(session.isDirty, isFalse);
  });

  test('resync leaves text that still reads as the value alone', () {
    final binding = bind();
    binding.controller.text = '100.';

    binding.resync();

    expect(binding.controller.text, '100.');
  });

  // For a rule that follows from the diver's own edit, and must not run
  // when the text was put there from the sitting.
  test('onEdited is told of what the diver typed, not of what arrives', () {
    var edits = 0;
    final binding = FieldTextBinding<_Rec, double?>(
      session: session,
      field: _altitude,
      format: _feet,
      parse: _parseFeet,
      onEdited: () => edits++,
    );
    addTearDown(binding.dispose);

    session.rebase(const _Rec(altitude: 2000));
    expect(edits, 0);

    binding.controller.text = '100';
    expect(edits, 1);

    binding.controller.text = '1.2.3';
    expect(edits, 1);
  });

  test('dispose stops following the session', () {
    final binding = FieldTextBinding<_Rec, double?>(
      session: session,
      field: _altitude,
      format: _feet,
      parse: _parseFeet,
    )..dispose();

    // A binding still listening would write to its disposed controller.
    expect(() => session.set(_altitude, 304.8), returnsNormally);
    expect(binding.isUnreadable, isFalse);
  });

  test('disposing after the session has gone is quiet', () {
    final own = EditSession(const _Rec(altitude: 10));
    final binding = FieldTextBinding<_Rec, double?>(
      session: own,
      field: _altitude,
      format: _feet,
      parse: _parseFeet,
    );
    own.dispose();

    expect(binding.dispose, returnsNormally);
  });
}
