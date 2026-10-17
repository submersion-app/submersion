import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';
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

/// The record a document form's owner points at, described as the picker
/// lists it (a dive with its site and date, #3391).
// no-tick: autoDispose and watched only by an open document form, which
// reads it again for every owner it shows; a record renamed elsewhere while
// that one form stays open is the only stale case.
final documentOwnerLabelProvider = FutureProvider.autoDispose
    .family<DocumentOwnerOption?, DocumentOwner>(
      (ref, owner) =>
          ref.watch(documentOwnerOptionsRepositoryProvider).optionFor(owner),
    );

/// What a document form's owning certification is titled from. The stored
/// name [documentOwnerLabelProvider] reads is empty for a certification with
/// no custom title, so the form derives the title from these (#3366).
// no-tick: autoDispose and watched only by an open document form, like
// documentOwnerLabelProvider above.
final documentOwnerCertificationProvider = FutureProvider.autoDispose
    .family<CertificationTitleFields?, String>(
      (ref, id) => ref
          .watch(documentOwnerOptionsRepositoryProvider)
          .certificationFieldsFor(id),
    );
