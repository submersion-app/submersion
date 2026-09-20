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
