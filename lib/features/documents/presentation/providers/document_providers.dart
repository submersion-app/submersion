import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DocumentRepository(),
);

/// The active diver's documents filed under [owner].
final documentsForOwnerProvider =
    FutureProvider.family<List<Document>, DocumentOwner>((ref, owner) async {
      final repo = ref.watch(documentRepositoryProvider);
      ref.invalidateSelfWhen(repo.watchChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      return repo.getForOwner(owner, diverId: diverId);
    });

/// Every document of the active diver, labelled with its owner.
final allDocumentsProvider = FutureProvider<List<DocumentListEntry>>((
  ref,
) async {
  final repo = ref.watch(documentRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchChanges());
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  if (diverId == null) return const [];
  return repo.getAllForDiver(diverId);
});

final documentByIdProvider = FutureProvider.family<Document?, String>((
  ref,
  id,
) async {
  final repo = ref.watch(documentRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchChanges());
  return repo.getById(id);
});

/// One document with the name of what it is filed under.
final documentEntryProvider = FutureProvider.family<DocumentListEntry?, String>(
  (ref, id) async {
    final repo = ref.watch(documentRepositoryProvider);
    ref.invalidateSelfWhen(repo.watchChanges());
    return repo.getEntryById(id);
  },
);

final documentPagesProvider = FutureProvider.family<List<DocumentPage>, String>(
  (ref, id) async {
    final repo = ref.watch(documentRepositoryProvider);
    ref.invalidateSelfWhen(repo.watchChanges());
    return repo.getPages(id);
  },
);

final documentFirstPageProvider = FutureProvider.family<DocumentPage?, String>((
  ref,
  id,
) async {
  final repo = ref.watch(documentRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchChanges());
  return repo.getFirstPage(id);
});

/// Non-insurance documents of the active diver that are expired or due,
/// expired first, then soonest. Insurance has its own home chip.
final attentionDocumentsProvider =
    FutureProvider<List<(Document, DocumentExpiryStatus)>>((ref) async {
      final repo = ref.watch(documentRepositoryProvider);
      ref.invalidateSelfWhen(repo.watchChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return const [];
      final now = DateTime.now();
      final out = [
        for (final d in await repo.getRemindingForDiver(diverId))
          if (d.type != DocumentType.insurance)
            (d, documentExpiryStatus(d, now)),
      ].where((e) => e.$2.needsAttention).toList();
      out.sort((a, b) => a.$2.daysLeft!.compareTo(b.$2.daysLeft!));
      return out;
    });

/// Writes from the documents UI, with the side effects every write needs.
class DocumentMutations {
  final Ref _ref;

  DocumentMutations(this._ref);

  DocumentRepository get _repo => _ref.read(documentRepositoryProvider);

  Future<Document> save(Document document, List<DocumentPage> pages) async {
    final saved = await _repo.save(document, pages);
    await _afterChange(saved: saved);
    return saved;
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await _afterChange(deletedId: id);
  }

  /// Keeps expiry reminders in step with each change.
  Future<void> _afterChange({Document? saved, String? deletedId}) async {}
}

final documentMutationsProvider = Provider<DocumentMutations>(
  (ref) => DocumentMutations(ref),
);
