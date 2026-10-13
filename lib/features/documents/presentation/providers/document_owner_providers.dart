import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_owner_options_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

final documentOwnerOptionsRepositoryProvider =
    Provider<DocumentOwnerOptionsRepository>(
      (ref) => DocumentOwnerOptionsRepository(),
    );

/// The active diver's records of one kind, for the owner picker.
// no-tick: autoDispose and read only while the picker sheet is open; the
// sheet is released on every pick or dismiss, so reopening it reads afresh.
final documentOwnerOptionsProvider = FutureProvider.autoDispose
    .family<List<DocumentOwnerOption>, DocumentOwnerKind>((ref, kind) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return const [];
      return ref
          .watch(documentOwnerOptionsRepositoryProvider)
          .optionsFor(kind, diverId: diverId);
    });

/// The name of the record a document form's owner points at.
// no-tick: autoDispose and watched only by an open document form, which
// reads it again for every owner it shows; a record renamed elsewhere while
// that one form stays open is the only stale case.
final documentOwnerLabelProvider = FutureProvider.autoDispose
    .family<String?, DocumentOwner>(
      (ref, owner) =>
          ref.watch(documentOwnerOptionsRepositoryProvider).labelFor(owner),
    );
