import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field_format.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('an unknown column falls back to a humanized label', () {
    final field = conflictFieldFor('dives', 'someFutureColumn');
    expect(field.label(l10n), 'Some Future Column');
    expect(field.kind, FieldKind.unknown);
  });

  test('bookkeeping and foreign keys are covered without an entry', () {
    expect(isConflictFieldCovered('dives', 'hlc'), isTrue);
    expect(isConflictFieldCovered('dives', 'siteId'), isTrue);
    expect(isConflictFieldCovered('dives', 'someFutureColumn'), isFalse);
  });

  test('dive fields reuse the dive field labels and units', () {
    const imperial = UnitFormatter(
      AppSettings(
        depthUnit: DepthUnit.feet,
        temperatureUnit: TemperatureUnit.fahrenheit,
      ),
    );
    final temp = conflictFieldFor('dives', 'waterTemp');
    expect(temp.label(l10n), DiveField.waterTemp.localizedDisplayName(l10n));
    expect(
      formatConflictValue(
        l10n: l10n,
        units: imperial,
        field: temp,
        value: 26.0,
      ),
      imperial.formatTemperature(26.0),
    );
    expect(conflictFieldFor('dives', 'maxDepth').kind, FieldKind.depth);
    expect(
      conflictFieldFor('dives', 'visibilityMeters').kind,
      FieldKind.distance,
    );
    expect(conflictFieldFor('dives', 'notes').kind, FieldKind.longText);
    expect(conflictFieldFor('dives', 'diveDateTime').kind, FieldKind.wallClock);
    expect(conflictFieldFor('dives', 'entryTime').kind, FieldKind.wallClock);
  });

  test('dive enum columns render localized values', () {
    final entry = conflictFieldFor('dives', 'entryMethod');
    expect(
      formatConflictValue(
        l10n: l10n,
        units: const UnitFormatter(AppSettings()),
        field: entry,
        value: 'boat',
      ),
      l10n.enum_entryMethod_boat,
    );
  });

  test('site attachment columns render their localized values', () {
    String value(String field, String stored) => formatConflictValue(
      l10n: l10n,
      units: const UnitFormatter(AppSettings()),
      field: conflictFieldFor('media', field),
      value: stored,
    );
    // Issue #1039: a conflict names the category and size, not the stored
    // keys, under the same labels the Edit details sheet uses.
    expect(value('siteCategory', 'siteMap'), 'Site map');
    expect(value('displaySize', 'tile'), 'Tile');
    expect(conflictFieldFor('media', 'siteCategory').label(l10n), 'Category');
    expect(
      conflictFieldFor('media', 'displaySize').label(l10n),
      'Display size',
    );
  });

  test('a severity reads with the enum of its own entity', () {
    String severity(String entity, String stored) => formatConflictValue(
      l10n: l10n,
      units: const UnitFormatter(AppSettings()),
      field: conflictFieldFor(entity, 'severity'),
      value: stored,
    );
    expect(severity('qualityFindings', 'critical'), 'Critical');
    expect(severity('diveSafetyFindings', 'caution'), 'Caution');
    expect(
      severity('incidents', 'serious'),
      l10n.incidentEdit_severity_serious,
    );
  });

  test('site and trip fields', () {
    expect(conflictFieldFor('diveSites', 'latitude').kind, FieldKind.latitude);
    expect(
      conflictFieldFor('diveSites', 'difficulty').kind,
      FieldKind.enumValue,
    );
    expect(
      conflictFieldFor('tideRecords', 'tideState').kind,
      FieldKind.enumValue,
    );
    expect(conflictFieldFor('trips', 'tripType').kind, FieldKind.enumValue);
    expect(
      conflictFieldFor('navTracks', 'totalDistance').kind,
      FieldKind.geoDistance,
    );
    expect(conflictFieldFor('trips', 'startDate').kind, FieldKind.date);
    expect(
      conflictFieldFor('gpsTracks', 'startTime').kind,
      FieldKind.wallClock,
    );
    expect(
      conflictFieldFor('diveCenters', 'fillOpensAt').kind,
      FieldKind.timeOfDay,
    );
    // A species category and a checklist category are different things.
    expect(conflictFieldFor('species', 'category').kind, FieldKind.enumValue);
    expect(
      conflictFieldFor('tripChecklistItems', 'category').kind,
      FieldKind.shortText,
    );
  });

  test('equipment fields', () {
    expect(conflictFieldFor('equipment', 'status').kind, FieldKind.enumValue);
    expect(conflictFieldFor('equipment', 'status').enumLabel, isNotNull);
    expect(
      conflictFieldFor('equipmentOwnershipEvents', 'kind').kind,
      FieldKind.enumValue,
    );
    expect(
      conflictFieldFor('cylinderFills', 'source').kind,
      FieldKind.enumValue,
    );
    // The same column name on a track is free text.
    expect(conflictFieldFor('gpsTracks', 'source').kind, FieldKind.shortText);
    expect(
      conflictFieldFor('tankPresets', 'workingPressureBar').kind,
      FieldKind.pressure,
    );
    expect(conflictFieldFor('equipment', 'purchaseDate').kind, FieldKind.date);
  });

  test('people and planning fields', () {
    expect(
      conflictFieldFor('diverWeightEntries', 'heightCm').kind,
      FieldKind.heightCm,
    );
    expect(
      conflictFieldFor('certifications', 'level').kind,
      FieldKind.enumValue,
    );
    expect(
      conflictFieldFor('certifications', 'agency').kind,
      FieldKind.enumValue,
    );
    expect(
      conflictFieldFor('preDiveSessions', 'status').kind,
      FieldKind.enumValue,
    );
    expect(
      conflictFieldFor('courseRequirements', 'kind').kind,
      FieldKind.enumValue,
    );
    expect(
      conflictFieldFor('divePlans', 'startDateTime').kind,
      FieldKind.epochSeconds,
    );
    expect(conflictFieldFor('divePlans', 'sacBottom').kind, FieldKind.rmv);
  });

  test('diver settings render unit choices the way settings shows them', () {
    final depthUnit = conflictFieldFor('diverSettings', 'depthUnit');
    expect(depthUnit.kind, FieldKind.enumValue);
    expect(
      formatConflictValue(
        l10n: l10n,
        units: const UnitFormatter(AppSettings()),
        field: depthUnit,
        value: 'feet',
      ),
      'ft',
    );
    expect(conflictFieldFor('settings', 'value').kind, FieldKind.shortText);
    expect(conflictFieldFor('media', 'takenAt').kind, FieldKind.wallClock);
  });

  test('no synced entity is left out of the coverage guard', () {
    // Guards against reintroducing a skip list.
    final guard = File(
      p.join(
        'test',
        'features',
        'settings',
        'presentation',
        'conflicts',
        'conflict_field_catalogue_coverage_test.dart',
      ),
    ).readAsStringSync();
    expect(guard, isNot(contains('skip:')));
    expect(guard, isNot(contains('_pending')));
  });

  test('day and clock columns use the frame their repository decodes', () {
    expect(conflictFieldFor('trips', 'startDate').kind, FieldKind.date);
    expect(
      conflictFieldFor('certifications', 'expiryDate').kind,
      FieldKind.date,
    );
    expect(conflictFieldFor('tripDayWeather', 'date').kind, FieldKind.utcDate);
    expect(conflictFieldFor('itineraryDays', 'date').kind, FieldKind.date);
    expect(conflictFieldFor('incidents', 'occurredAt').kind, FieldKind.utcDate);
    expect(
      conflictFieldFor('tripCylinderEvents', 'occurredAt').kind,
      FieldKind.wallClock,
    );
    expect(
      conflictFieldFor('equipmentOwnershipEvents', 'occurredAt').kind,
      FieldKind.dateTime,
    );
  });

  test('an SCR injection rate follows the volume unit', () {
    expect(conflictFieldFor('dives', 'scrInjectionRate').kind, FieldKind.rmv);
  });
}
