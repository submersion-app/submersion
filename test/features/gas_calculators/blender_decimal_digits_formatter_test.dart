import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_decimal_digits_formatter.dart';

void main() {
  const formatter = BlenderDecimalDigitsFormatter();

  TextEditingValue value(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  test('allows digits up to the integer budget', () {
    final result = formatter.formatEditUpdate(value('12'), value('123'));
    expect(result.text, '123');
  });

  test('rejects a fourth integer digit', () {
    final old = value('123');
    final result = formatter.formatEditUpdate(old, value('1234'));
    expect(result.text, '123');
  });

  test('allows up to two fraction digits', () {
    final result = formatter.formatEditUpdate(value('1.2'), value('1.23'));
    expect(result.text, '1.23');
  });

  test('rejects a third fraction digit', () {
    final old = value('1.23');
    final result = formatter.formatEditUpdate(old, value('1.234'));
    expect(result.text, '1.23');
  });

  test('rejects a second separator', () {
    final old = value('1.2');
    final result = formatter.formatEditUpdate(old, value('1.2.3'));
    expect(result.text, '1.2');
  });

  test('accepts a comma separator the same as a dot', () {
    final result = formatter.formatEditUpdate(value('1'), value('1,23'));
    expect(result.text, '1,23');
  });

  test('a custom digit budget is honoured (e.g. psi pressure)', () {
    const psiFormatter = BlenderDecimalDigitsFormatter(maxIntDigits: 4);
    final result = psiFormatter.formatEditUpdate(value('344'), value('3442'));
    expect(result.text, '3442');
    final rejected = psiFormatter.formatEditUpdate(
      value('3442'),
      value('34420'),
    );
    expect(rejected.text, '3442');
  });
}
