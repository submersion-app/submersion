import 'dart:async';

import 'package:submersion/core/database/compaction/database_compaction_monitor.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/notifications/presentation/providers/notification_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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
  ref.invalidateSelfWhen(repo.watchOwnerChanges());
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
    ref.invalidateSelfWhen(repo.watchOwnerChanges());
    return repo.getEntryById(id);
  },
);

/// Every page of a document with its content (up to 10 MB each), so it is
/// released once no page shows the document.
final documentPagesProvider = FutureProvider.autoDispose
    .family<List<DocumentPage>, String>((ref, id) async {
      final repo = ref.watch(documentRepositoryProvider);
      ref.invalidateSelfWhen(repo.watchChanges());
      return repo.getPages(id);
    });

/// A thumbnail's first page; released with the tile that shows it.
final documentFirstPageProvider = FutureProvider.autoDispose
    .family<DocumentPage?, String>((ref, id) async {
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
    await _rearm(saved);
    return saved;
  }

  /// Deletes [id]; the repository cancels its reminders on every delete.
  /// A document can hold tens of MB of pages, so a delete is when the next
  /// launch may be worth a compaction.
  Future<void> delete(String id) async {
    await _repo.delete(id);
    unawaited(_ref.read(databaseCompactionMonitorProvider)());
  }

  /// Puts documents an undone delete removed back, with the reminders the
  /// delete cancelled.
  Future<void> restoreSnapshot(List<DocumentSnapshotEntry> snapshot) async {
    await _repo.restoreSnapshot(snapshot);
    await rearmReminders([for (final entry in snapshot) entry.document]);
  }

  /// Re-arms the reminders of [documents] that came back without going
  /// through [save] (a restore inside another feature's undo).
  Future<void> rearmReminders(Iterable<Document> documents) async {
    for (final document in documents) {
      await _rearm(document);
    }
  }

  /// Keeps [document]'s expiry reminders in step with it. A reminder
  /// failure never fails the write: the next full reschedule repairs it.
  Future<void> _rearm(Document document) async {
    try {
      await _ref
          .read(notificationSchedulerProvider)
          .updateForDocument(document, _ref.read(settingsProvider));
    } catch (e, stackTrace) {
      _log.warning(
        'Document reminder update failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static final _log = LoggerService.forClass(DocumentMutations);
}

final documentMutationsProvider = Provider<DocumentMutations>(
  (ref) => DocumentMutations(ref),
);
