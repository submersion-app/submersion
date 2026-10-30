import 'derived_seeder.dart';
import 'dive_seeder.dart';
import 'diver_seeder.dart';
import 'gear_cylinder_seeder.dart';
import 'gear_faults.dart';
import 'gear_life_seeder.dart';
import 'gear_seeder.dart';
import 'gear_service_seeder.dart';
import 'media_seeder.dart';
import 'misc_seeder.dart';
import 'places_seeder.dart';
import 'planning_seeder.dart';
import 'seed_context.dart';
import 'track_seeder.dart';
import 'training_seeder.dart';
import 'trip_seeder.dart';

/// Every seeder, in the order their rows depend on each other.
List<DemoSeeder> demoSeeders() => [
  DiverSeeder(),
  PlacesSeeder(),
  TrainingSeeder(),
  GearSeeder(),
  GearCylinderSeeder(),
  TripSeeder(),
  DiveSeeder(),
  GearServiceSeeder(),
  FaultSeeder(),
  GearLifeSeeder(),
  TrainingLinksSeeder(),
  MediaSeeder(),
  PlanningSeeder(),
  TrackSeeder(),
  MiscSeeder(),
  DerivedSeeder(),
];

Future<void> seedAll(DemoSeedContext ctx) async {
  for (final seeder in demoSeeders()) {
    await seeder.seed(ctx);
  }
}
