import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/explore/domain/compiled_query.dart';
import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/chip_labeler.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final metric = ChipLabeler(l10n, const UnitFormatter(AppSettings()));
  final imperial = ChipLabeler(
    l10n,
    const UnitFormatter(
      AppSettings(
        depthUnit: DepthUnit.feet,
        temperatureUnit: TemperatureUnit.fahrenheit,
      ),
    ),
  );

  test('numeric clauses show the value in the diver unit', () {
    const chip = ClauseChip(
      field: ExploreDiveField.depth,
      op: ClauseOp.gt,
      value: 20.0,
      dimension: FieldDimension.depth,
    );
    expect(metric.label(chip), 'Depth over 20m');
    expect(imperial.label(chip), 'Depth over 66ft');
  });

  ClauseChip chip(
    ExploreDiveField f,
    Object v, {
    FieldDimension d = FieldDimension.none,
    ClauseOp op = ClauseOp.gte,
  }) => ClauseChip(field: f, op: op, value: v, dimension: d);

  test('every catalog field has a label', () {
    for (final f in ExploreDiveField.values) {
      expect(metric.fieldName(f), isNotEmpty, reason: f.name);
    }
  });

  test('each dimension formats its own way', () {
    expect(
      metric.label(
        chip(ExploreDiveField.bottomTime, 45.0, d: FieldDimension.minutes),
      ),
      'Bottom time at least 45 min',
    );
    expect(
      metric.label(chip(ExploreDiveField.o2, 32.0, d: FieldDimension.percent)),
      'Oxygen at least 32%',
    );
    expect(
      metric.label(
        chip(ExploreDiveField.diveNumber, 7.0, d: FieldDimension.count),
      ),
      'Dive number at least 7',
    );
    // A non-integer count keeps its fraction rather than rounding silently.
    expect(
      metric.label(chip(ExploreDiveField.rating, 3.5, d: FieldDimension.count)),
      'Rating at least 3.5',
    );
  });

  test('each operator has its own word', () {
    for (final entry in {
      ClauseOp.gt: 'over',
      ClauseOp.gte: 'at least',
      ClauseOp.lt: 'under',
      ClauseOp.lte: 'at most',
      ClauseOp.eq: 'of',
    }.entries) {
      expect(
        metric.label(
          chip(
            ExploreDiveField.diveNumber,
            3.0,
            d: FieldDimension.count,
            op: entry.key,
          ),
        ),
        'Dive number ${entry.value} 3',
        reason: entry.key.name,
      );
    }
  });

  test('the no-buddy flag and a single enum value', () {
    expect(
      metric.label(chip(ExploreDiveField.noBuddy, true, op: ClauseOp.eq)),
      'No buddy',
    );
    expect(
      metric.label(chip(ExploreDiveField.diveMode, 'ccr', op: ClauseOp.eq)),
      'Dive mode: ccr',
    );
  });

  test('between, enum, not, flags and time', () {
    expect(
      metric.label(
        const ClauseChip(
          field: ExploreDiveField.waterTemp,
          op: ClauseOp.between,
          value: [10.0, 15.0],
          dimension: FieldDimension.temperature,
        ),
      ),
      'Water temperature 10°C to 15°C',
    );
    expect(
      metric.label(
        const ClauseChip(
          field: ExploreDiveField.waterType,
          op: ClauseOp.inList,
          value: ['salt', 'fresh'],
          dimension: FieldDimension.none,
        ),
      ),
      'Water type: salt, fresh',
    );
    expect(
      metric.label(
        const ClauseChip(
          field: ExploreDiveField.waterType,
          op: ClauseOp.not,
          value: ['salt'],
          dimension: FieldDimension.none,
        ),
      ),
      'Water type not salt',
    );
    expect(
      metric.label(
        const ClauseChip(
          field: ExploreDiveField.favorite,
          op: ClauseOp.eq,
          value: true,
          dimension: FieldDimension.none,
        ),
      ),
      'Favourite',
    );
    expect(
      metric.label(
        const ClauseChip(
          field: ExploreDiveField.deco,
          op: ClauseOp.eq,
          value: false,
          dimension: FieldDimension.none,
        ),
      ),
      'No decompression',
    );
    expect(
      metric.label(
        const MentionChip(
          kind: MentionKind.place,
          entry: NameEntry(
            kind: MentionKind.place,
            label: 'Bonaire',
            ids: ['s1'],
            target: NameTarget.sitePlace,
          ),
        ),
      ),
      'Bonaire',
    );
    expect(
      metric.label(TimeChip(start: DateTime(2025, 1, 1))),
      startsWith('Since '),
    );
    expect(
      metric.label(TimeChip(end: DateTime(2021, 12, 31))),
      startsWith('Before '),
    );
    expect(
      metric.label(
        TimeChip(start: DateTime(2025, 1, 1), end: DateTime(2025, 12, 31)),
      ),
      contains(' to '),
    );
  });
}
