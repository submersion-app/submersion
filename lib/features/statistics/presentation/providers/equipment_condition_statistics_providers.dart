import 'dart:ui' show Locale;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/condition_finding_text.dart';
import 'package:submersion/features/equipment/presentation/utils/observation_tag_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The ids of the dives the statistics filter keeps, or null when no
/// filter is on. The exposure and reported-issue rankings narrow to it;
/// the findings ranking cannot, since a finding is the gear's state now
/// rather than a set of dives, and the page says so under the filter.
final statisticsFilteredDiveIdsProvider = FutureProvider<Set<String>?>((
  ref,
) async {
  final filter = ref.watch(statisticsFilterProvider);
  final statistics = ref.watch(statisticsRepositoryProvider);
  // The filter reads far more than `dives`: the gear and tank links, tags,
  // dive types, buddies, sites and trips, and equipment attributes. Linking
  // gear to an existing dive changes no dive row, yet changes the set.
  ref.invalidateSelfWhen(statistics.watchStatisticsChanges());
  ref.invalidateSelfWhen(
    ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
  );
  ref.invalidateSelfWhen(
    ref.watch(equipmentRepositoryProvider).watchAttributeChanges(),
  );
  return statistics.filteredDiveIds(filter);
});

/// The unit the exposure ranking card is showing.
final exposureRankingUnitProvider = StateProvider<ExposureUnit>(
  (ref) => ExposureUnit.hours,
);

/// Active items ranked by their total in the chosen unit, through the
/// same samples and classifier the item page uses, so the two never
/// disagree. `count` is the rounded total (what the row prints), `value`
/// the exact one, and `subtitle` states the dive count behind it, since a
/// total means little without the n it was gathered over.
///
/// Each ranking is keyed by the [Locale] the page renders in
/// (`Localizations.localeOf(context)`), because a row holds a finished
/// label and cannot rename itself at render time. The stored language
/// setting is not enough: on "system" the platform language can change
/// without the setting moving, and the app picks the system language
/// from the whole preference list, which the setting cannot reproduce.
final exposureRankingProvider =
    FutureProvider.family<List<RankingItem>, Locale>((ref, locale) async {
      final unit = ref.watch(exposureRankingUnitProvider);
      final repository = ref.watch(equipmentRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchEquipmentChanges());
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final l10n = lookupAppLocalizations(locale);
      final items = await repository.getActiveEquipment(diverId: diverId);
      // Every item's inputs are asked for before any is awaited: watching in
      // a sync loop registers each dependency, and awaiting them together
      // stops a locker of gear turning into a queue of round trips.
      final pending = [
        for (final item in items)
          ref.watch(equipmentExposureInputsProvider(item.id).future),
      ];
      final loaded = await Future.wait(pending);
      final keep = await ref.watch(statisticsFilteredDiveIdsProvider.future);
      final out = <RankingItem>[];
      for (final (index, item) in items.indexed) {
        final inputs = loaded[index];
        if (inputs == null) continue;
        // The page's filter narrows this card like every other one on it.
        final samples = keep == null
            ? inputs.samples
            : [
                for (final sample in inputs.samples)
                  if (keep.contains(sample.diveId)) sample,
              ];
        if (samples.isEmpty) continue;
        var total = 0.0;
        for (final sample in samples) {
          total += inputs.classifier.contribution(sample, unit);
        }
        // Filter on what the row will SHOW, not on the raw total: a tenth of
        // an hour is real exposure but renders as "0 hours" with an empty
        // bar, and the bar scales off the same count, so one such row also
        // flattens every other.
        final count = total.round();
        if (count <= 0) continue;
        out.add(
          RankingItem(
            id: item.id,
            name: item.name,
            count: count,
            value: total,
            subtitle: l10n.equipmentCondition_exposure_dives(samples.length),
          ),
        );
      }
      out.sort((a, b) => b.value!.compareTo(a.value!));
      return out;
    });

/// Undismissed findings per rule after the display filters, worst-first
/// by count. The id is the rule's dbValue so a row can be traced.
///
/// Scoped to the diver's own active gear: `equipment_findings` carries no
/// diver of its own, so an unscoped read would count another profile's
/// items, and retired gear would report findings nobody is going to act
/// on.
final findingsByRuleProvider = FutureProvider.family<List<RankingItem>, Locale>(
  (ref, locale) async {
    final (enabled, disabled) = ref.watch(
      settingsProvider.select(
        (s) => (s.conditionEngineEnabled, s.conditionDisabledRules),
      ),
    );
    final findings = ref.watch(equipmentFindingsRepositoryProvider);
    final repository = ref.watch(equipmentRepositoryProvider);
    ref.invalidateSelfWhen(findings.watchChanges());
    ref.invalidateSelfWhen(repository.watchEquipmentChanges());
    if (!enabled) return const [];
    final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
    final mine = {
      for (final e in await repository.getActiveEquipment(diverId: diverId))
        e.id,
    };
    final l10n = lookupAppLocalizations(locale);
    final counts = <ConditionRuleId, int>{};
    for (final f in await findings.getAllUndismissed()) {
      if (!mine.contains(f.equipmentId)) continue;
      if (disabled.contains(f.ruleId.dbValue)) continue;
      counts[f.ruleId] = (counts[f.ruleId] ?? 0) + 1;
    }
    final out = [
      for (final e in counts.entries)
        RankingItem(
          id: e.key.dbValue,
          name: conditionFindingShortLabel(e.key, l10n),
          count: e.value,
        ),
    ];
    out.sort((a, b) => b.count.compareTo(a.count));
    return out;
  },
);

/// Issue check-in tags by how often the diver reported them.
final issueTagRankingProvider =
    FutureProvider.family<List<RankingItem>, Locale>((ref, locale) async {
      final observations = ref.watch(equipmentObservationRepositoryProvider);
      ref.invalidateSelfWhen(observations.watchChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final l10n = lookupAppLocalizations(locale);
      final keep = await ref.watch(statisticsFilteredDiveIdsProvider.future);
      final counts = <ObservationTag, int>{};
      for (final o in await observations.getAll(diverId: diverId)) {
        if (o.status != ObservationStatus.issue) continue;
        // Under the page filter only check-ins on the dives it keeps
        // count; a bench check-in belongs to no dive, so none keeps it.
        if (keep != null && !keep.contains(o.diveId)) continue;
        for (final tag in o.issueTags) {
          counts[tag] = (counts[tag] ?? 0) + 1;
        }
      }
      final out = [
        for (final e in counts.entries)
          RankingItem(
            id: e.key.dbValue,
            name: e.key.localizedName(l10n),
            count: e.value,
          ),
      ];
      out.sort((a, b) => b.count.compareTo(a.count));
      return out;
    });
