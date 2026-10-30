part of 'shared_library_store.dart';

/// The verified member removals of each library, cached for the Members
/// page and the removed member's own notice (issue #3481).
extension SharedLibraryStoreRemovals on SharedLibraryStore {
  /// Empty when none were cached or the cache does not parse.
  Future<List<MemberRemoval>> removals(String libraryId) async {
    final row = await (_db.select(
      _db.sharedLibraries,
    )..where((t) => t.id.equals(libraryId))).getSingleOrNull();
    final raw = row?.removalsJson;
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final r in decoded)
          if (MemberRemoval.fromJson(r) case final MemberRemoval removal)
            removal,
      ];
    } on FormatException {
      return const [];
    }
  }

  /// Replaces [libraryId]'s cached removals; writing the library row is
  /// what tells the library and member providers to read again.
  Future<void> setRemovals(
    String libraryId,
    List<MemberRemoval> removals,
  ) async {
    await (_db.update(
      _db.sharedLibraries,
    )..where((t) => t.id.equals(libraryId))).write(
      SharedLibrariesCompanion(
        removalsJson: Value(jsonEncode([for (final r in removals) r.toJson()])),
      ),
    );
  }
}
