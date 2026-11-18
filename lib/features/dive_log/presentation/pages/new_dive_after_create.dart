import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/mirror_dive_dialog.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/run_rules_flow.dart';
import 'package:submersion/features/tides/data/services/dive_tide_recorder.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

const _log = LoggerService('NewDiveAfterCreate');

/// What a new dive is owed once its sitting has created it (issue #4527, plan
/// 8), in the order the old new-dive form ran it after its write: the weather
/// fetch, the tide record, the logbook rules and the question whether to log it
/// for linked buddies. None of it is part of the sitting's History entry, and
/// each step is best effort: one that fails is logged and the next runs.
class NewDiveAfterCreate {
  NewDiveAfterCreate({
    required this.fetchWeather,
    required this.recordTide,
    required this.runRules,
    required this.offerMirror,
  });

  /// Everything read from [context] and [ref] now, before the write: the
  /// steps run after it, when the page may have gone.
  factory NewDiveAfterCreate.read(BuildContext context, WidgetRef ref) {
    final container = ProviderScope.containerOf(context, listen: false);
    final rules = captureRulesAfterCreate(context, ref);
    return NewDiveAfterCreate(
      // Not awaited, as the form does not: it needs the network.
      fetchWeather: (dive, location) => container
          .read(weatherRepositoryProvider)
          .fetchAndSaveWeather(
            diveId: dive.id,
            latitude: location.latitude,
            longitude: location.longitude,
            dateTime: dive.dateTime,
          ),
      recordTide: (dive, location) async {
        final resolved = await container.read(
          resolvedTideDataProvider(location).future,
        );
        if (resolved == null) return;
        // The entry is the dive's wall clock; the recorder works out the
        // real instant.
        await recordDiveTide(
          repository: container.read(tideRecordRepositoryProvider),
          calculator: resolved.calculator,
          diveId: dive.id,
          entryWallClock: dive.effectiveEntryTime,
          location: location,
          waterType: dive.waterType ?? dive.site?.waterType,
        );
      },
      runRules: (id) => rules(subject: RuleSubject.dives, ids: [id]),
      // Asked on the page that created the dive, while it is there.
      offerMirror: (id) async {
        final candidates = await container
            .read(diveMirrorServiceProvider)
            .candidates(id);
        if (candidates.isEmpty || !context.mounted) return;
        final chosen = await showMirrorDiveDialog(
          context,
          candidates: candidates,
        );
        if (chosen == null || chosen.isEmpty || !context.mounted) return;
        await runDiveMirror(
          context: context,
          container: container,
          sourceDiveId: id,
          chosen: [
            for (final c in candidates)
              if (chosen.contains(c.diver.id)) c,
          ],
        );
      },
    );
  }

  final void Function(Dive dive, GeoPoint location) fetchWeather;
  final Future<void> Function(Dive dive, GeoPoint location) recordTide;
  final Future<void> Function(String diveId) runRules;
  final Future<void> Function(String diveId) offerMirror;

  /// Runs the steps for [created]; the weather fetch and the tide record,
  /// which need the network, are started and not waited for. The weather is not fetched over weather
  /// the diver entered or fetched in the sitting: the fetch writes wind,
  /// sky, rain, humidity and the description over what the dive holds, and
  /// a new dive holds none of them unless the diver put them there. A
  /// planned dive runs no rules and is not offered to buddies: it is not
  /// logged yet.
  Future<void> run({required Dive created}) async {
    final location = created.site?.location;
    if (location != null && !hasWeather(created)) {
      await _guarded('weather', () async => fetchWeather(created, location));
    }
    // Not awaited: the tide needs the network, and the page waits for these
    // steps before it moves on to the dive.
    if (location != null) {
      unawaited(_guarded('tide', () => recordTide(created, location)));
    }
    if (created.isPlanned) return;
    await _guarded('rules', () => runRules(created.id));
    await _guarded('mirror', () => offerMirror(created.id));
  }

  /// Whether [dive] holds any of the weather a fetch writes.
  static bool hasWeather(Dive dive) =>
      dive.windSpeed != null ||
      dive.windDirection != null ||
      dive.cloudCover != null ||
      dive.precipitation != null ||
      dive.humidity != null ||
      (dive.weatherDescription?.isNotEmpty ?? false) ||
      dive.weatherCode != null ||
      dive.weatherFetchedAt != null;

  Future<void> _guarded(String step, Future<void> Function() body) async {
    try {
      await body();
    } catch (error, stackTrace) {
      _log.warning(
        'After creating a dive, the $step step failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
