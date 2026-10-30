import 'package:drift/drift.dart' show Variable;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_day_weather_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';

import 'dive_kit.dart';
import 'seed_context.dart';

/// Every planned trip with its itinerary, daily weather, liveaboard details,
/// rental cylinders and packing, and one upcoming trip being planned now, so
/// the checklists and countdown have something ahead of them.
class TripSeeder implements DemoSeeder {
  @override
  String get name => 'trips';

  static const upcomingTripId = 'demo-trip-upcoming';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final trips = TripRepository();
    final itinerary = ItineraryDayRepository();
    final weather = TripDayWeatherRepository();
    final liveaboards = LiveaboardDetailsRepository();
    final cylinders = TripCylinderRepository();
    final packing = TripEquipmentRepository();
    final sitesById = {for (final s in ctx.plan.sites) s.id: s};

    for (final t in ctx.plan.trips) {
      final type = t.destination.liveaboard
          ? TripType.liveaboard
          : TripType.resort;
      final dives = ctx.plan.dives.where((d) => d.tripId == t.id).length;
      await trips.createTrip(
        Trip(
          id: t.id,
          diverId: DemoSeedContext.diverId,
          name: t.name,
          startDate: t.start,
          endDate: t.end,
          location: t.destination.label,
          liveaboardName: t.boatName,
          resortName: t.resortName,
          tripType: type,
          expectedDives: dives,
          divesPerDayTarget: t.destination.liveaboard ? 3 : 2,
          notes: 'Trip ${ctx.plan.trips.indexOf(t) + 1} of the logbook.',
          createdAt: t.start.subtract(const Duration(days: 60)),
          updatedAt: t.end,
        ),
      );
      await itinerary.regenerateForTrip(t.id, t.start, t.end, tripType: type);
      // The site of the trip's first dive: a picked site may go undived.
      final site =
          sitesById[ctx.plan.dives.firstWhere((d) => d.tripId == t.id).siteId]!;
      for (
        var day = t.start;
        !day.isAfter(t.end);
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        final (_, hi) = t.destination.waterTempC;
        await weather.upsert(
          TripDayWeather(
            id: 'demo-trip-weather-${t.id}-${day.month}-${day.day}',
            tripId: t.id,
            date: day,
            latitude: site.latitude,
            longitude: site.longitude,
            airTemp: hi + ctx.between(0, 4),
            cloudCover: CloudCover.values[ctx.random.nextInt(3)],
            precipitation: ctx.random.nextDouble() < 0.15
                ? Precipitation.lightRain
                : Precipitation.none,
            windSpeed: ctx.between(2, 9),
            windDirection: CurrentDirection.values[ctx.random.nextInt(8)],
            humidity: ctx.between(55, 85),
            weatherCode: 1,
            fetchedAt: day,
            createdAt: day,
            updatedAt: day,
          ),
        );
      }
      if (t.destination.liveaboard) {
        await liveaboards.createOrUpdate(
          LiveaboardDetails(
            id: 'demo-liveaboard-${t.id}',
            tripId: t.id,
            vesselName: t.boatName!,
            operatorName: '${t.destination.label} Liveaboards',
            vesselType: 'Motor yacht',
            cabinType: 'Lower deck twin',
            capacity: 20,
            createdAt: t.start,
            updatedAt: t.start,
          ),
        );
      }
      // A trip away rents its cylinders; near home the diver brings theirs.
      final cylId = 'demo-trip-cyl-${t.id}';
      if (!t.destination.nearHome) {
        await cylinders.createCylinder(
          TripCylinder(
            id: cylId,
            tripId: t.id,
            label: t.destination.liveaboard
                ? 'Boat 12 L aluminium'
                : 'Rental 12 L aluminium',
            volume: 11.1,
            workingPressure: 207,
            material: TankMaterial.aluminum,
            presetName: 'al80',
            createdAt: t.start,
            updatedAt: t.start,
          ),
        );
        await cylinders.createEvent(
          TripCylinderEvent(
            id: 'demo-trip-cyl-fill-${t.id}',
            tripCylinderId: cylId,
            kind: TripCylinderEventKind.fill,
            occurredAt: t.start,
            pressure: 210,
            o2Percent: 32,
            analyzedO2: 31.8,
            cost: 8,
            currency: 'USD',
            createdAt: t.start,
            updatedAt: t.start,
          ),
        );
      }
      // Packed: everything the trip's dives were dived with.
      await packing.pack(t.id, [
        ...{
          for (final d in ctx.plan.dives.where((d) => d.tripId == t.id))
            for (final k in kitFor(
              d,
              ctx.timeline,
              photo: isPhotoDive(d, ctx.timeline),
            ).gearKeys)
              ctx.equipment[k]!,
        },
      ]);
    }

    // The trip being planned now: a liveaboard a few weeks out.
    final start = DateTime(
      ctx.anchor.year,
      ctx.anchor.month,
      ctx.anchor.day + 38,
    );
    final end = DateTime(start.year, start.month, start.day + 9);
    await trips.createTrip(
      Trip(
        id: upcomingTripId,
        diverId: DemoSeedContext.diverId,
        name: 'Maldives on the rebreather',
        startDate: start,
        endDate: end,
        location: 'Maldives',
        liveaboardName: 'MV Coral Spirit',
        tripType: TripType.liveaboard,
        expectedDives: 18,
        divesPerDayTarget: 3,
        notes: 'First trip with the rebreather.',
        createdAt: ctx.anchor,
        updatedAt: ctx.anchor,
      ),
    );
    await itinerary.regenerateForTrip(
      upcomingTripId,
      start,
      end,
      tripType: TripType.liveaboard,
    );
    await packing.pack(upcomingTripId, await _setItems(ctx, 'ccr'));
    final checklist = TripChecklistRepository();
    var order = 0;
    for (final (section, items) in [
      (
        'Paperwork',
        [
          'Passport',
          'Insurance card',
          'Rebreather certification card',
          'Logbook printout',
        ],
      ),
      (
        'Rebreather',
        [
          'Sofnolime for 18 dives',
          'Spare oxygen cells',
          'Cell checker',
          'O-ring kit',
        ],
      ),
      (
        'Bookings',
        ['Confirm nitrox and oxygen fills', 'Transfer to the harbour'],
      ),
    ]) {
      final sectionRow = await checklist.createSection(
        tripId: upcomingTripId,
        title: section,
      );
      for (final title in items) {
        final done = order % 3 == 0;
        await checklist.createItem(
          TripChecklistItem(
            id: 'demo-checklist-${order++}',
            tripId: upcomingTripId,
            sectionId: sectionRow.id,
            title: title,
            isDone: done,
            completedAt: done ? ctx.anchor : null,
            dueDate: DateTime(start.year, start.month, start.day - 7),
            sortOrder: order,
            createdAt: ctx.anchor,
            updatedAt: ctx.anchor,
          ),
        );
      }
    }

    // One trip shared with the partner profile, one shared to everyone and
    // hidden by them.
    final shares = ItemSharesRepository();
    await shares.setSharing(
      SharedItemKind.trip,
      ctx.plan.trips.first.id,
      const ItemSharing(
        everyone: false,
        profileIds: {DemoSeedContext.partnerId},
      ),
      actingDiverId: DemoSeedContext.diverId,
    );
    await shares.setSharing(
      SharedItemKind.trip,
      ctx.plan.trips[1].id,
      const ItemSharing(everyone: true, profileIds: {}),
      actingDiverId: DemoSeedContext.diverId,
    );
    await ProfileHidesRepository().hide(
      SharedItemKind.trip,
      ctx.plan.trips[1].id,
      DemoSeedContext.partnerId,
    );
  }

  static Future<List<String>> _setItems(DemoSeedContext ctx, String set) async {
    final rows = await ctx.db
        .customSelect(
          'SELECT equipment_id FROM equipment_set_items WHERE set_id = ?',
          variables: [Variable.withString(ctx.equipmentSets[set]!)],
        )
        .get();
    return [for (final r in rows) r.read<String>('equipment_id')];
  }
}
