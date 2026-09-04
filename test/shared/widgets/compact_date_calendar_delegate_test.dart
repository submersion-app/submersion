import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:submersion/shared/widgets/compact_date_calendar_delegate.dart';

/// The delegate is exercised through the pickers in app_date_picker_test.dart;
/// these cover the answers a dialog cannot easily provoke, namely the rejected
/// input and the locales `intl` has no data for.
void main() {
  // A pure unit test has to initialize date formatting itself; widget tests
  // get it from GlobalMaterialLocalizations.
  setUpAll(initializeDateFormatting);

  // Every method takes a MaterialLocalizations it does not consult, since the
  // whole point is that the format comes from the diver's preference instead.
  const unused = DefaultMaterialLocalizations();

  CompactDateCalendarDelegate delegate({
    String pattern = 'dd.MM.yyyy',
    Locale locale = const Locale('en'),
  }) => CompactDateCalendarDelegate(pattern: pattern, locale: locale);

  test('formats and parses with the diver pattern, not the locale default', () {
    final subject = delegate();

    expect(
      subject.formatCompactDate(DateTime(2026, 1, 31), unused),
      '31.01.2026',
    );
    expect(
      subject.parseCompactDate('31.01.2026', unused),
      DateTime(2026, 1, 31),
    );
  });

  test('rejects input that does not match the pattern', () {
    final subject = delegate();

    // Right date, wrong separators: the field is not a free-form parser.
    expect(subject.parseCompactDate('31/01/2026', unused), isNull);
    expect(subject.parseCompactDate('not a date', unused), isNull);
    // 31 is not a month, so day-first is genuinely being enforced.
    expect(subject.parseCompactDate('01.31.2026', unused), isNull);
  });

  test('an empty field parses to no date rather than throwing', () {
    expect(delegate().parseCompactDate(null, unused), isNull);
  });

  test('the help text is the pattern the field actually parses', () {
    expect(delegate().dateHelpText(unused), 'dd.mm.yyyy');
    expect(delegate(pattern: 'yyyy-MM-dd').dateHelpText(unused), 'yyyy-mm-dd');
  });

  test('an unknown region falls back to the language', () {
    // intl has no de_XX, but the German digits it does have are what matters.
    final subject = delegate(locale: const Locale('de', 'XX'));

    expect(
      subject.formatCompactDate(DateTime(2026, 1, 31), unused),
      '31.01.2026',
    );
  });

  test('an unknown language still yields a usable format', () {
    final subject = delegate(locale: const Locale('zz'));

    expect(
      subject.formatCompactDate(DateTime(2026, 1, 31), unused),
      '31.01.2026',
    );
    expect(
      subject.parseCompactDate('31.01.2026', unused),
      DateTime(2026, 1, 31),
    );
  });
}
