import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/fill_forecast.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  const units = UnitFormatter(AppSettings());
  final at = DateTime.utc(2026, 3, 9, 8, 15);
  final slot = TripCylinder(
    id: 'c1',
    tripId: 't1',
    label: 'Truck 1',
    createdAt: at,
    updatedAt: at,
  );

  TripCylinderState state({
    TripCylinderStatus status = TripCylinderStatus.full,
    TripCylinderEvent? lastEvent,
    TripCylinderTankUse? lastUse,
  }) => TripCylinderState(
    cylinder: slot,
    bottleLabel: 'Truck 1',
    status: status,
    lastEventAt: lastEvent?.occurredAt ?? lastUse?.entryTime,
    lastEvent: lastEvent,
    lastUse: lastUse,
  );

  TripCylinderEvent event(TripCylinderEventKind kind, {String? center}) =>
      TripCylinderEvent(
        id: 'e1',
        tripCylinderId: 'c1',
        kind: kind,
        occurredAt: at,
        diveCenterId: center,
        createdAt: at,
        updatedAt: at,
      );

  final when = units.formatDateTime(at, l10n: l10n);

  test('air reads as the localized word, other mixes by their notation', () {
    expect(tripCylinderMixLabel(l10n, const GasMix()), 'Air');
    expect(tripCylinderMixLabel(l10n, const GasMix(o2: 32)), 'EAN32');
    expect(
      tripCylinderMixLabel(l10n, const GasMix(o2: 21, he: 35)),
      'Tx 21/35',
    );
  });

  test('each status has a label and a distinct colour', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    final labels = {
      for (final s in TripCylinderStatus.values)
        tripCylinderStatusLabel(l10n, s),
    };
    final colours = {
      for (final s in TripCylinderStatus.values)
        tripCylinderStatusColor(scheme, s),
    };
    expect(labels, {'Full', 'Partial', 'Empty', 'Not filled yet'});
    expect(colours, hasLength(4));
  });

  test('counts every status', () {
    final counts = tripCylinderCounts([
      state(),
      state(),
      state(status: TripCylinderStatus.partial),
      state(status: TripCylinderStatus.unknown),
    ]);
    expect(counts, (full: 2, partial: 1, empty: 0, unknown: 1));
  });

  group('last item sentence', () {
    test('a fill names its station when it has one', () {
      expect(
        tripCylinderLastItemText(
          l10n,
          units,
          state(lastEvent: event(TripCylinderEventKind.fill, center: 'dc1')),
          centerNames: const {'dc1': 'Dive Friends'},
        ),
        'Filled at Dive Friends, $when',
      );
    });

    test('a fill with no known station says when only', () {
      expect(
        tripCylinderLastItemText(
          l10n,
          units,
          state(lastEvent: event(TripCylinderEventKind.fill, center: 'gone')),
        ),
        'Filled $when',
      );
    });

    test('an adjustment says when', () {
      expect(
        tripCylinderLastItemText(
          l10n,
          units,
          state(lastEvent: event(TripCylinderEventKind.adjustment)),
        ),
        'Adjusted $when',
      );
    });

    test('a dive names its site when it has one', () {
      final use = TripCylinderTankUse(
        tankId: 'k1',
        diveId: 'd1',
        entryTime: at,
        siteName: 'Salt Pier',
      );
      expect(
        tripCylinderLastItemText(l10n, units, state(lastUse: use)),
        'Dived at Salt Pier, $when',
      );
      final bare = TripCylinderTankUse(
        tankId: 'k1',
        diveId: 'd1',
        entryTime: at,
      );
      expect(
        tripCylinderLastItemText(l10n, units, state(lastUse: bare)),
        'Dived $when',
      );
    });

    test('an untouched slot has no sentence', () {
      expect(
        tripCylinderLastItemText(
          l10n,
          units,
          state(status: TripCylinderStatus.unknown),
        ),
        isNull,
      );
    });
  });

  group('tank line', () {
    test('names the slot and the bottle', () {
      expect(
        tripCylinderTankLine(l10n, (label: 'Truck 2', bottle: '14')),
        'Truck 2 · Bottle 14',
      );
    });

    test('leaves out an unknown or repeated bottle', () {
      expect(
        tripCylinderTankLine(l10n, (label: 'Truck 2', bottle: null)),
        'Truck 2',
      );
      expect(
        tripCylinderTankLine(l10n, (label: 'My HP100', bottle: 'My HP100')),
        'My HP100',
      );
    });
  });

  test('the picker label names status, mix, pressure and bottle', () {
    final t0 = DateTime.utc(2026, 3, 9);
    final state = foldCylinderState(
      cylinder: TripCylinder(
        id: 'a',
        tripId: 't1',
        label: 'Truck 2',
        workingPressure: 207,
        createdAt: t0,
        updatedAt: t0,
      ),
      events: [
        TripCylinderEvent(
          id: 'f',
          tripCylinderId: 'a',
          kind: TripCylinderEventKind.fill,
          occurredAt: t0,
          bottleLabel: '14',
          pressure: 200,
          o2Percent: 32,
          createdAt: t0,
          updatedAt: t0,
        ),
      ],
      uses: const [],
    );
    expect(
      tripCylinderPickerLabel(l10n, units, state),
      // The status leads, so a narrow picker cuts the bottle, not the status.
      'Truck 2 · Full · EAN32 · ${units.formatPressure(200)} · Bottle 14',
    );
  });

  test('the dive link strings exist in English', () {
    expect(l10n.diveLog_tank_tripCylinderLabel, 'Trip cylinder');
    expect(l10n.diveLog_tank_tripCylinderNone, 'None');
    expect(
      l10n.diveLog_tank_tripCylinderSuggested,
      "Suggested from the trip's full cylinders",
    );
    expect(l10n.trips_cylinders_action_logDive, 'Log dive');
  });

  test('the forecast strings exist in English', () {
    expect(
      l10n.trips_cylinders_forecast_todayShort(4, 2),
      'Today needs 4, you have 2 full.',
    );
    expect(
      l10n.trips_cylinders_forecast_tomorrowShort(6, 1),
      "Tomorrow needs 6, you'll have 1 full.",
    );
    expect(
      l10n.trips_cylinders_forecast_fillBefore('5:00 PM'),
      'Fill before 5:00 PM.',
    );
    expect(
      l10n.trips_cylinders_forecast_enough,
      'Enough full cylinders through tomorrow.',
    );
    expect(l10n.trips_cylinders_forecast_plannedDives(1), '1 dive');
    expect(l10n.trips_cylinders_forecast_plannedDives(0), '0 dives');
    expect(l10n.trips_edit_label_diversSharing, 'Divers sharing cylinders');
    expect(l10n.diveCenters_section_fillHours, 'Fill hours');
    expect(
      l10n.diveCenters_fillHours_errorOrder,
      'Closing time must be after opening time.',
    );
  });

  FillForecast forecastOf({
    int todayShortfall = 0,
    int tomorrowShortfall = 0,
    int? deadline,
  }) => FillForecast(
    fullCount: 2,
    partialCount: 0,
    todayDemand: 4,
    tomorrowDemand: 6,
    tomorrowSupply: 1,
    todayShortfall: todayShortfall,
    tomorrowShortfall: tomorrowShortfall,
    deadlineMinutes: deadline,
    remainingDemand: 10,
    days: const [],
  );

  test('a time of day in the diver\'s format', () {
    expect(units.formatMinutesOfDay(1020), '5:00 PM');
    expect(
      const UnitFormatter(
        AppSettings(timeFormat: TimeFormat.twentyFourHour),
      ).formatMinutesOfDay(1020),
      '17:00',
    );
  });

  test('forecast lines: both shortfalls, today first, with the deadline', () {
    final r = tripFillForecastLines(
      l10n,
      units,
      forecastOf(todayShortfall: 2, tomorrowShortfall: 5, deadline: 1020),
    );
    expect(r.short, isTrue);
    expect(r.lines, [
      'Today needs 4, you have 2 full. Fill before 5:00 PM.',
      "Tomorrow needs 6, you'll have 1 full.",
    ]);
  });

  test('forecast lines: tomorrow alone, no deadline', () {
    final r = tripFillForecastLines(
      l10n,
      units,
      forecastOf(tomorrowShortfall: 5),
    );
    expect(r.lines, ["Tomorrow needs 6, you'll have 1 full."]);
  });

  test('forecast lines: enough', () {
    final r = tripFillForecastLines(l10n, units, forecastOf(deadline: 1020));
    expect(r.short, isFalse);
    expect(r.lines, ['Enough full cylinders through tomorrow.']);
  });

  test('the gas record strings exist in English', () {
    expect(l10n.trips_cylinders_segment_record, 'Record');
    expect(
      l10n.trips_cylinders_recordEmpty,
      'No dives breathed from these cylinders yet.',
    );
    expect(l10n.trips_cylinders_record_fillsLogged(1), '1 fill logged');
    expect(l10n.trips_cylinders_record_fillsLogged(3), '3 fills logged');
    expect(l10n.trips_cylinders_record_leftOut(1), '1 dive left out');
    expect(l10n.trips_cylinders_record_packageFills(2), '2 package fills');
    expect(
      l10n.trips_cylinders_record_unlinked(3),
      '3 dive tanks not linked to a cylinder',
    );
    expect(l10n.trips_cylinders_record_tank(2), 'Tank 2');
    expect(l10n.trips_cylinders_record_filled('200 bar'), 'Filled to 200 bar');
    expect(l10n.trips_cylinders_record_analyzed('31.8%'), 'Analyzed 31.8%');
  });

  test('the board segment labels differ in every locale', () async {
    // Board, Ledger and Record side by side: two with one word leave the
    // diver guessing which is the gas record.
    for (final locale in AppLocalizations.supportedLocales) {
      final l = await AppLocalizations.delegate.load(locale);
      expect(
        {
          l.trips_cylinders_segment_board,
          l.trips_cylinders_segment_ledger,
          l.trips_cylinders_segment_record,
        },
        hasLength(3),
        reason: '$locale',
      );
    }
  });
}
