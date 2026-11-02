import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_date_chip_label.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  const units = UnitFormatter(AppSettings());

  setUpAll(() async {
    await initializeDateFormatting();
  });

  String? label(QueryNode node, {String language = 'en'}) => diveDateChipLabel(
    node,
    l10n: lookupAppLocalizations(Locale(language)),
    units: units,
  );

  ConditionNode range(DateTime start, DateTime end) => ConditionNode(
    FieldPath(['date']),
    QueryOp.inList,
    DateRangeValue(start, end),
  );
  ConditionNode day(QueryOp op, DateTime date) =>
      ConditionNode(FieldPath(['date']), op, DateValue(date));

  test('a whole year', () {
    expect(label(range(DateTime(2018, 1, 1), DateTime(2018, 12, 31))), '2018');
  });

  test('a whole month', () {
    expect(
      label(range(DateTime(2018, 10, 1), DateTime(2018, 10, 31))),
      'October 2018',
    );
    expect(
      label(range(DateTime(2024, 2, 1), DateTime(2024, 2, 29))),
      'February 2024',
    );
  });

  test('a month in the diver language', () {
    expect(
      label(
        range(DateTime(2018, 10, 1), DateTime(2018, 10, 31)),
        language: 'fr',
      ),
      'octobre 2018',
    );
  });

  test('a single day', () {
    final date = DateTime(2018, 10, 14);
    expect(label(day(QueryOp.eq, date)), units.formatMonthDayWithYear(date));
  });

  test('any other range uses the range wording', () {
    final start = DateTime(2018, 1, 1);
    final end = DateTime(2020, 12, 31);
    expect(
      label(range(start, end)),
      '${units.formatMonthDayWithYear(start)} - '
      '${units.formatMonthDayWithYear(end)}',
    );
  });

  test('a lower bound uses the from wording', () {
    final date = DateTime(2020, 1, 1);
    expect(
      label(day(QueryOp.gte, date)),
      'From ${units.formatMonthDayWithYear(date)}',
    );
  });

  test('an upper bound uses the until wording', () {
    final date = DateTime(2019, 12, 31);
    expect(
      label(day(QueryOp.lte, date)),
      'Until ${units.formatMonthDayWithYear(date)}',
    );
  });

  test('a strict bound keeps its printed text', () {
    expect(label(day(QueryOp.gt, DateTime(2020))), isNull);
    expect(label(day(QueryOp.lt, DateTime(2020))), isNull);
  });

  test('a negated date keeps its printed text', () {
    expect(
      label(NotNode(range(DateTime(2018, 1, 1), DateTime(2018, 12, 31)))),
      isNull,
    );
  });

  test('a word or another field keeps its printed text', () {
    expect(label(TextNode(['2018'])), isNull);
    expect(
      label(
        ConditionNode(
          FieldPath(['year']),
          QueryOp.eq,
          const NumberValue(2018, null),
        ),
      ),
      isNull,
    );
  });
}
