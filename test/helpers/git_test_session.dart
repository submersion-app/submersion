import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_branch_files.dart';
import 'package:submersion/core/services/cloud_storage/git/git_branch_session.dart';
import 'package:submersion/core/services/cloud_storage/git/git_http_transport.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_remote.dart';

const String gitTestBranch = 'submersion-sync';

/// A [GitBranchSession] on [url] for one test, with no retry delay and a
/// fixed clock unless given one. Its transport closes when the test ends.
GitBranchSession gitTestSession(
  Uri url, {
  String branch = gitTestBranch,
  GitHttpTransport? transport,
  GitObjectStore? store,
  int resetThresholdBytes = kGitHistoryResetThresholdBytes,
  DateTime Function()? clock,
}) {
  final t =
      transport ??
      GitHttpTransport(GitRemote(cloneUrl: url, username: 'u', token: 't'));
  addTearDown(t.close);
  return GitBranchSession(
    transport: t,
    store: store ?? MemoryGitObjectStore(),
    branch: branch,
    identity: () async => const GitCommitIdentity(
      name: 'Submersion 1234abcd',
      messageLabel: 'Submersion 1234abcd',
    ),
    clock: clock ?? () => DateTime.utc(2026, 10, 18, 12),
    retryDelay: (_) => Duration.zero,
    resetThresholdBytes: resetThresholdBytes,
  );
}

GitPut gitText(String s) => GitPut.bytes(Uint8List.fromList(utf8.encode(s)));
