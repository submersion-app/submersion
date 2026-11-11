import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_service_status_providers.dart';
import 'package:submersion/features/insights/presentation/providers/dive_deco_status_providers.dart';

/// Waits for every local cache of engine verdicts a compiled query reads
/// (its `tablesTouched`): the service-due verdicts `serviceDue` reads and
/// the computed deco verdicts `deco` reads (#4461). Each is mirrored from a
/// Dart engine the SQL cannot run, so a query that reads one before it is
/// written would answer from an empty or stale cache. A query that reads
/// neither returns at once. See [awaitServiceStatusIfRead] for [hold].
Future<void> awaitQueryCachesIfRead(
  Ref ref,
  Set<String> tablesTouched, {
  bool hold = true,
}) async {
  await awaitServiceStatusIfRead(ref, tablesTouched, hold: hold);
  await awaitDiveDecoStatusIfRead(ref, tablesTouched, hold: hold);
}

/// [awaitQueryCachesIfRead] for a query run outside a provider's build on
/// behalf of [diverId]: a rule run, an agent's query. The caches hold the
/// active profile's verdicts only, so a query for another profile has none
/// to prepare. One-off waits: the caller's ref outlives each query, so no
/// listener is kept.
Future<void> prepareQueryCachesFor(
  Ref ref,
  String diverId,
  Set<String> tables,
) async {
  final active = await ref.read(validatedCurrentDiverIdProvider.future);
  if (diverId != active) return;
  await awaitQueryCachesIfRead(ref, tables, hold: false);
}

/// [awaitQueryCachesIfRead] for a widget, which has a [WidgetRef] rather
/// than a provider's [Ref].
Future<void> awaitQueryCachesIfReadFromWidget(
  WidgetRef ref,
  Set<String> tablesTouched,
) async {
  await awaitServiceStatusIfReadFromWidget(ref, tablesTouched);
  await awaitDiveDecoStatusIfReadFromWidget(ref, tablesTouched);
}
