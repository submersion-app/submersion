import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_weight_entry_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

import '../story/story_plan.dart';
import 'seed_context.dart';

/// The demo diver, a second profile (their regular buddy, so the profile
/// switcher and sharing have something to show), the buddies and dive roles.
class DiverSeeder implements DemoSeeder {
  @override
  String get name => 'divers and buddies';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final firstDive = ctx.plan.dives.first.start;
    final created = DateTime(
      firstDive.year,
      firstDive.month,
      firstDive.day - 30,
    );
    final divers = DiverRepository();
    await divers.createDiver(
      Diver(
        id: DemoSeedContext.diverId,
        name: 'Alex Rivera',
        email: 'alex.rivera@example.com',
        phone: '+1 555 0100',
        isDefault: true,
        notes:
            'Learned in the Caribbean, hooked on Jersey wrecks, now on a '
            'rebreather.',
        emergencyContact: const EmergencyContact(
          name: 'Robin Rivera',
          phone: '+1 555 0199',
          relation: 'Partner',
        ),
        insurance: DiverInsurance(
          provider: 'Divers Alert Network',
          policyNumber: 'DEMO-0042-7731',
          expiryDate: _days(ctx.anchor, 160),
        ),
        medicalClearanceExpiryDate: _days(ctx.anchor, 240),
        divingSince: firstDive,
        createdAt: created,
        updatedAt: ctx.anchor,
      ),
    );
    await divers.createDiver(
      Diver(
        id: DemoSeedContext.partnerId,
        name: 'Mara Lindqvist',
        email: 'mara.lindqvist@example.com',
        notes: "Alex's regular buddy, logging on the same device.",
        createdAt: created,
        updatedAt: ctx.anchor,
      ),
    );
    await divers.setDefaultDiver(DemoSeedContext.diverId);
    await divers.setActiveDiverIdInSettings(DemoSeedContext.diverId);

    // A New Jersey diver logs in feet, Fahrenheit, psi, pounds and cubic
    // feet, with 12-hour times and month-first dates.
    final settings = DiverSettingsRepository();
    final current = await settings.getOrCreateSettingsForDiver(
      DemoSeedContext.diverId,
    );
    await settings.updateSettingsForDiver(
      DemoSeedContext.diverId,
      current.copyWith(
        depthUnit: DepthUnit.feet,
        temperatureUnit: TemperatureUnit.fahrenheit,
        pressureUnit: PressureUnit.psi,
        volumeUnit: VolumeUnit.cubicFeet,
        weightUnit: WeightUnit.pounds,
        altitudeUnit: AltitudeUnit.feet,
        distanceUnit: DistanceUnit.miles,
        timeFormat: TimeFormat.twelveHour,
        dateFormat: DateFormatPreference.mmmDYYYY,
      ),
      previous: current,
    );

    final weights = DiverWeightEntryRepository();
    for (var i = 0; i < 6; i++) {
      final at = DateTime(firstDive.year + i, firstDive.month, 3);
      await weights.createEntry(
        DiverWeightEntry(
          id: 'demo-weight-$i',
          diverId: DemoSeedContext.diverId,
          measuredAt: at,
          weightKg: 78.0 - i * 0.6,
          heightCm: 178,
          createdAt: at,
          updatedAt: at,
        ),
      );
    }

    final buddies = BuddyRepository();
    for (final person in ctx.plan.people) {
      await buddies.createBuddy(
        Buddy(
          id: ctx.buddyId(person.id),
          diverId: DemoSeedContext.diverId,
          name: person.name,
          email:
              '${_local(person.firstName)}.${_local(person.lastName)}@example.com',
          certificationLevel: switch (person.role) {
            PersonRole.instructor => 'Instructor',
            PersonRole.guide => 'Divemaster',
            PersonRole.techTeam => 'Normoxic Trimix',
            PersonRole.regular || PersonRole.boatBuddy => 'Advanced Open Water',
          },
          isFavorite: person.id == 'p-mara',
          linkedDiverId: person.id == 'p-mara'
              ? DemoSeedContext.partnerId
              : null,
          notes: switch (person.role) {
            PersonRole.instructor => 'Taught one of the courses.',
            PersonRole.guide => 'Guided a trip.',
            PersonRole.techTeam => 'Technical team.',
            PersonRole.boatBuddy => 'Met on a trip.',
            PersonRole.regular => '',
          },
          createdAt: created,
          updatedAt: ctx.anchor,
        ),
      );
    }

    await DiveRoleRepository().createDiveRole(
      name: 'Videographer',
      diverId: DemoSeedContext.diverId,
    );
  }

  /// A name as the local part of an email address: lower case, letters only.
  static String _local(String name) =>
      name.toLowerCase().replaceAll(RegExp('[^a-z]'), '');

  static DateTime _days(DateTime from, int days) =>
      DateTime(from.year, from.month, from.day + days);
}
