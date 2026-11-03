import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/features/table_editor/domain/table_editor_entity.dart';
import 'package:submersion/features/table_editor/entities/center_table_editor_entity.dart';
import 'package:submersion/features/table_editor/entities/dive_table_editor_entity.dart';
import 'package:submersion/features/table_editor/entities/site_table_editor_entity.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/constants/entity_field.dart';

import '../../../helpers/test_database.dart';

/// Every editable column of every tab round-trips (#3422): the text a cell
/// opens with parses back to the value it came from, list columns offer
/// their choices, and number columns name their unit. One loop per entity,
/// so a column added later cannot ship without this contract.
void main() {
  final l10n = AppLocalizationsEn();
  const units = UnitFormatter(AppSettings());

  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  void checkColumns<T, F extends EntityField>(
    TableEditorEntity<T, F> entity,
    T row,
  ) {
    expect(entity.columns, isNotEmpty);
    for (final column in entity.columns) {
      final reason = column.field.name;
      expect(column.isEditable(row), isTrue, reason: reason);
      expect(column.readOnlyReason(row, l10n), isNull, reason: reason);
      switch (column.kind) {
        case CellEditorKind.text:
        case CellEditorKind.number:
        case CellEditorKind.integer:
          final text = column.editText(row, units);
          final result = column.parse(text, units, l10n);
          expect(result, isA<CellParsed>(), reason: '$reason "$text"');
          final value = (result as CellParsed).value;
          final stored = column.valueOf(row);
          if (stored is double && value is double) {
            expect(value, closeTo(stored, 1e-6), reason: reason);
          } else {
            expect(value, stored, reason: reason);
          }
          // A rating is the one number with no unit to name.
          if (column.kind == CellEditorKind.number && reason != 'rating') {
            expect(column.unitSymbol(units), isNotNull, reason: reason);
          }
          // A blank clears every column but the record's name.
          expect(
            column.parse('', units, l10n),
            column.field == entity.keyField
                ? isA<CellRejected>()
                : isA<CellParsed>(),
            reason: reason,
          );
        case CellEditorKind.choice:
        case CellEditorKind.multiChoice:
        case CellEditorKind.reference:
          final choices = column.choices(l10n);
          expect(choices, isNotEmpty, reason: reason);
          final result = column.parse(choices.first.label, units, l10n);
          expect(result, isA<CellParsed>(), reason: reason);
          expect(
            column.parse('no such entry', units, l10n),
            isA<CellRejected>(),
          );
        case CellEditorKind.toggle:
          expect(column.parse('yes', units, l10n), isA<CellParsed>());
      }
    }
  }

  test('every dive column round-trips', () {
    final repo = DiveRepository();
    final entity = DiveTableEditorEntity(
      diveRepo: repo,
      bulk: BulkDiveEditService(repo, BuddyRepository(), SpeciesRepository()),
      sites: const [ChoiceOption('s1', 'Reef')],
      centers: const [ChoiceOption('c1', 'Blue Divers')],
      trips: const [ChoiceOption('t1', 'Red Sea 2026')],
      computers: const [ChoiceOption('Perdix', 'Perdix')],
    );
    final dive = Dive(
      id: 'd1',
      diveNumber: 7,
      dateTime: DateTime(2026, 1, 1),
      diveOperator: 'Boat Co',
      boatName: 'Sea Dog',
      boatCaptain: 'Ann',
      rating: 4,
      isFavorite: true,
      waterType: WaterType.salt,
      visibilityMeters: 15,
      currentDirection: CurrentDirection.north,
      currentStrength: CurrentStrength.light,
      swellHeight: 0.5,
      surfaceConditions: 'Calm',
      entryMethod: EntryMethod.shore,
      exitMethod: EntryMethod.boat,
      altitude: 300,
      surfacePressure: 1.013,
      surfaceInterval: const Duration(minutes: 90),
      gradientFactorLow: 30,
      gradientFactorHigh: 85,
      decoAlgorithm: 'buhlmann',
      decoConservatism: 1,
      diveComputerModel: 'Perdix',
      windSpeed: 4,
      windDirection: CurrentDirection.east,
      cloudCover: CloudCover.values.first,
      precipitation: Precipitation.values.first,
      humidity: 60,
      weatherDescription: 'Sunny',
      diveMode: DiveMode.ccr,
      setpointLow: 0.7,
      setpointHigh: 1.3,
      setpointDeco: 1.4,
      diluentGas: const GasMix(o2: 18, he: 45),
      scrubber: const ScrubberInfo(type: 'Sofnolime', ratedMinutes: 180),
      notes: 'A note',
      weights: const [
        DiveWeight(
          id: 'w1',
          diveId: 'd1',
          weightType: WeightType.belt,
          amountKg: 6,
        ),
      ],
    );
    checkColumns(entity, dive);
    expect(entity.keyField, DiveField.diveNumber);
  });

  test('every site column round-trips', () {
    final entity = SiteTableEditorEntity(
      repo: SiteRepository(),
      editableLibrarySites: const {},
    );
    const site = DiveSite(
      id: 's1',
      name: 'Reef',
      country: 'Mexico',
      region: 'Quintana Roo',
      city: 'Tulum',
      island: 'None',
      bodyOfWater: 'Caribbean',
      location: GeoPoint(20.2, -87.4),
      maxDepth: 30,
      minDepth: 5,
      altitude: 0,
      waterType: WaterType.salt,
      difficulty: SiteDifficulty.intermediate,
      entryMethods: [EntryMethod.shore],
      exitMethods: [EntryMethod.shore],
      mooringNumber: '12',
      hazards: 'Boats',
      rating: 4,
      notes: 'Nice',
    );
    checkColumns(entity, const SiteWithDiveCount(site: site, diveCount: 2));
    expect(entity.keyField, SiteField.siteName);
    expect(
      entity.nameOf(const SiteWithDiveCount(site: site, diveCount: 0)),
      'Reef',
    );
  });

  test('every center column round-trips', () {
    final entity = CenterTableEditorEntity(repo: DiveCenterRepository());
    final center = DiveCenter(
      id: 'c1',
      name: 'Blue Divers',
      street: '1 Beach Rd',
      city: 'Tulum',
      stateProvince: 'QR',
      postalCode: '77780',
      latitude: 20.2,
      longitude: -87.4,
      country: 'Mexico',
      phone: '123',
      email: 'a@b.c',
      website: 'https://example.com',
      rating: 5,
      notes: 'Friendly',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    checkColumns(entity, (center: center, diveCount: 1));
    expect(entity.numberOf((center: center, diveCount: 1)), isNull);
  });
}
