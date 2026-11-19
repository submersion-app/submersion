import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

/// Writes a species page's editing sitting (issue #4527, phase 3): the
/// species' changed values and every held write, in one transaction and one
/// History entry labelled with the cards it changed.
class SpeciesEditSaveService {
  SpeciesEditSaveService(this._species);

  final SpeciesRepository _species;

  /// Saves [apply] onto species [speciesId] as stored now, so a value
  /// changed underneath on a card the diver never touched is kept.
  /// [alsoWrite] makes the held writes (photos tagged, photos added) after
  /// the species row; with [alsoWriteIsAChange] they are written even when
  /// the species row itself is unchanged. Returns the species before and
  /// after, or null when nothing changed. Throws [StateError] when the
  /// species no longer exists.
  Future<({Species before, Species after})?> save({
    required String speciesId,
    required Species Function(Species stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) => writeRecordSitting<Species>(
    table: 'species',
    recordId: speciesId,
    changedCardIds: changedCardIds,
    read: () => _species.getSpeciesById(speciesId),
    apply: apply,
    write: (_, merged) => _species.updateSpecies(merged),
    alsoWrite: alsoWrite,
    alsoWriteIsAChange: alsoWriteIsAChange,
  );
}

final speciesEditSaveServiceProvider = Provider<SpeciesEditSaveService>(
  (ref) => SpeciesEditSaveService(ref.watch(speciesRepositoryProvider)),
);
