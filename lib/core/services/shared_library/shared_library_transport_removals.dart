part of 'shared_library_transport.dart';

/// The owners' removal records beside the member cards (issue #3481), as
/// `removed-<memberId>.json`. Devices on v1.8.2 list the members folder by
/// the `member-` prefix only, so they never read these.
extension SharedLibraryTransportRemovals on SharedLibraryTransport {
  /// Every record that reads as one; a file that does not, or that names
  /// another member than its file name (a copy under another name), is
  /// skipped. Whether an owner signed it is the caller's to check.
  Future<List<MemberRemoval>> listRemovals() async {
    final files = await _listKind(
      await _membersId(),
      SharedLibraryTransport._removalPrefix,
    );
    final removals = <MemberRemoval>[];
    for (final f in files) {
      final base = SharedLibraryTransport._base(f.id);
      try {
        final record = MemberRemoval.fromJson(
          jsonDecode(
            utf8.decode(
              await _open(
                '${SharedLibraryLayout.membersDir}/$base',
                f.id,
                await _provider.downloadFile(f.id),
              ),
            ),
          ),
        );
        if (record != null &&
            SharedLibraryTransport.removalFileName(record.memberId) == base) {
          removals.add(record);
        }
      } catch (e) {
        if (!SharedLibraryTransport.isUnreadable(e)) rethrow;
      }
    }
    return removals;
  }

  Future<void> writeRemoval(MemberRemoval r) async {
    final name = SharedLibraryTransport.removalFileName(r.memberId);
    await _writeJson(
      await _membersId(),
      name,
      r.toJson(),
      path: '${SharedLibraryLayout.membersDir}/$name',
    );
  }

  Future<void> deleteRemoval(String memberId) async {
    final f = await _find(
      await _membersId(),
      SharedLibraryTransport.removalFileName(memberId),
    );
    if (f != null) await _provider.deleteFile(f.id);
  }
}
