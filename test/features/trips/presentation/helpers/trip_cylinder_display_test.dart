import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
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
}
