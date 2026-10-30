import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/cloud_storage/git/git_branch_session.dart';
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';

import '../../../../helpers/git_cli.dart';
import '../../../../helpers/git_delegating_store.dart';
import '../../../../helpers/git_http_backend_server.dart';
import '../../../../helpers/git_test_session.dart';

const _path = 'Submersion Backups/backup.json';

/// A store whose first [open] of a blob finds it gone, as when another
/// store on the same directory evicts it between the check and the read.
final class _LosesFirstOpen extends DelegatingGitObjectStore {
  _LosesFirstOpen() : super(MemoryGitObjectStore());

  bool _lost = false;

  @override
  Future<GitObjectReader?> open(GitObjectId id) async {
    final reader = await inner.open(id);
    if (!_lost && reader?.type == GitObjectType.blob) {
      _lost = true;
      return null;
    }
    return reader;
  }
}

void main() {
  final skip = skipUnlessGit();

  Future<Uri> repoWithBackup() async {
    final server = await startGitTestServer();
    await server.createBareRepo('sync');
    final peer = gitTestSession(server.repoUrl('sync'));
    await peer.open();
    await peer.commit(
      GitChange(puts: {_path: gitText('{"dives": 3}')}),
      messagePrefix: 'Backup',
    );
    return server.repoUrl('sync');
  }

  test('writes the file and leaves no partial file', () async {
    final s = gitTestSession(await repoWithBackup());
    final dest = File(p.join(tempDirForTest('git_read_to_').path, 'b.json'));
    await s.readFileTo(_path, dest);
    expect(dest.readAsStringSync(), '{"dives": 3}');
    expect(File('${dest.path}.part').existsSync(), isFalse);
  }, skip: skip);

  test('a path not on the branch writes nothing', () async {
    final s = gitTestSession(await repoWithBackup());
    final dest = File(p.join(tempDirForTest('git_read_to_').path, 'b.json'));
    await expectLater(
      s.readFileTo('Submersion Backups/missing.json', dest),
      throwsA(
        isA<GitException>().having(
          (e) => e.code,
          'code',
          GitErrorCode.notFound,
        ),
      ),
    );
    expect(dest.existsSync(), isFalse);
    expect(File('${dest.path}.part').existsSync(), isFalse);
  }, skip: skip);

  test('a blob lost between the check and the read is fetched again', () async {
    final s = gitTestSession(await repoWithBackup(), store: _LosesFirstOpen());
    final dest = File(p.join(tempDirForTest('git_read_to_').path, 'b.json'));
    await s.readFileTo(_path, dest);
    expect(dest.readAsStringSync(), '{"dives": 3}');
  }, skip: skip);

  test('a destination that cannot be written leaves nothing behind', () async {
    final s = gitTestSession(await repoWithBackup());
    final dir = tempDirForTest('git_read_to_');
    final dest = File(p.join(dir.path, 'no such folder', 'b.json'));
    await expectLater(
      s.readFileTo(_path, dest),
      throwsA(isA<FileSystemException>()),
    );
    expect(dir.listSync(recursive: true), isEmpty);
  }, skip: skip);
}
