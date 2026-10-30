import 'package:submersion/core/constants/enums.dart' hide Visibility;
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_fill_if_empty_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_journal_mapping.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

/// Brings the dive details a diver logged in the Suunto app (the workout
/// journal) onto the imported dive (issue #3491): dive center, visibility,
/// current, weight, marine life, and the rest as custom fields.
///
/// Each detail fills only what the dive does not have yet, so nothing
/// written in Submersion is overwritten and a re-import adds nothing. The
/// dive is already saved by now, so each detail is written on its own and a
/// failure is logged rather than thrown: one detail failing never costs the
/// dive the others or stops the import.
class SuuntoJournalWriter {
  SuuntoJournalWriter({
    DiveFillIfEmptyRepository? fill,
    DiveCenterRepository? centers,
    DiveRepository? dives,
    SpeciesRepository? species,
  }) : _fill = fill ?? DiveFillIfEmptyRepository(),
       _centers = centers ?? DiveCenterRepository(),
       _dives = dives ?? DiveRepository(),
       _species = species ?? SpeciesRepository();

  static final _log = LoggerService.forClass(SuuntoJournalWriter);

  final DiveFillIfEmptyRepository _fill;
  final DiveCenterRepository _centers;
  final DiveRepository _dives;
  final SpeciesRepository _species;

  /// Writes [parsed]'s journal onto [diveId] for [diverId]. A visibility
  /// band becomes that band's metres on [scale], the diver's chosen
  /// visibility scale, as a band pick in the edit form does.
  Future<void> attach(
    String diveId,
    SuuntoParsedDive parsed,
    String diverId, {
    required VisibilityScale scale,
  }) async {
    final journal = parsed.journal;
    if (journal.isEmpty) return;

    final centerName = journal.diveCenter;
    if (centerName != null) {
      await _try('dive center', diveId, () async {
        // Checked first so a dive that has a center never gains an unlinked
        // one in the diver's list; the link itself stays guarded.
        if (await _fill.hasDiveCenter(diveId)) return;
        final center = await _centers.findOrCreateByName(
          centerName,
          diverId: diverId,
        );
        await _fill.linkDiveCenterIfNone(diveId, center.id);
      });
    }

    final band = switch (journal.visibility) {
      final coded? => suuntoVisibilityBand(coded.id),
      null => null,
    };
    if (band != null) {
      await _try(
        'visibility',
        diveId,
        () => _fill.fillVisibilityRangeIfEmpty(diveId, scale.rangeFor(band)),
      );
    }

    final strength = switch (journal.current) {
      final coded? => suuntoCurrentStrength(coded.id),
      null => null,
    };
    if (strength != null) {
      await _try(
        'current',
        diveId,
        () => _fill.fillCurrentStrengthIfEmpty(diveId, strength),
      );
    }

    final weightKg = journal.weightKg;
    if (weightKg != null) {
      await _try(
        'weight',
        diveId,
        () => _dives.addWeightIfNone(
          diveId,
          // Suunto does not say what kind of weight it is; a belt is the
          // plainest reading, as for Garmin Connect, and the diver can change
          // it.
          DiveWeight(
            id: '',
            diveId: diveId,
            weightType: WeightType.belt,
            amountKg: weightKg,
          ),
        ),
      );
    }

    if (journal.marineLife.isNotEmpty) {
      final sighted = await _try('marine life', diveId, () async {
        return {
          for (final s in await _species.getSightingsForDive(diveId))
            s.speciesId,
        };
      });
      // Each animal on its own, so one failing does not cost the others.
      if (sighted != null) {
        for (final name in journal.marineLife) {
          await _try('sighting of $name', diveId, () async {
            final species = await _species.getOrCreateSpecies(
              commonName: name,
              category: SpeciesCategory.other,
            );
            if (!sighted.add(species.id)) return;
            await _species.addSighting(diveId: diveId, speciesId: species.id);
          });
        }
      }
    }

    final fields = suuntoCustomFields(journal);
    if (fields.isNotEmpty) {
      await _try(
        'custom fields',
        diveId,
        () => _fill.addCustomFieldsIfMissing(diveId, fields),
      );
    }
  }

  /// Runs [write], logging rather than throwing a failure; returns its
  /// result, or null when it failed.
  Future<T?> _try<T>(
    String what,
    String diveId,
    Future<T> Function() write,
  ) async {
    try {
      return await write();
    } catch (e, st) {
      _log.error(
        'Could not bring the Suunto $what onto dive $diveId',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
