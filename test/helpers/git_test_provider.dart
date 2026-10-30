import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_branch_files.dart';
import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/cloud_storage/git/git_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git_storage_provider.dart';

import '../support/fake_keychain_storage.dart';
import 'git_cli.dart';

const String gitTestDeviceId = '1234abcd-0000-4000-8000-000000000001';

/// A [GitStorageProvider] for [repoUrl] on a loopback test server, saved
/// with user `diver` and [token], with no push pacing unless asked for.
/// Disposed when the test ends.
Future<GitStorageProvider> gitTestProvider(
  Uri repoUrl, {
  bool encrypted = false,
  Future<bool> Function()? encryption,
  String token = 'tok',
  Duration deleteQuietPeriod = const Duration(minutes: 10),
  Duration uploadBudget = const Duration(seconds: 45),
  int? resetThresholdBytes,
  GitStoreFactory? storeFactory,
  GitTransportFactory? transportFactory,
  Duration minPushSpacing = Duration.zero,
  Duration maxPacingWait = const Duration(seconds: 10),
  String deviceName = "Eric's iPhone",
  GitDeviceSource? device,
}) async {
  final store = GitCredentialsStore(storage: InMemoryKeychain());
  await store.save(
    GitConfig(repoUrl: repoUrl.toString(), username: 'diver', token: token),
  );
  final provider = GitStorageProvider(
    store: store,
    storeFactory: storeFactory ?? (_) async => MemoryGitObjectStore(),
    transportFactory: transportFactory,
    device:
        device ??
        () async => (deviceId: gitTestDeviceId, deviceName: deviceName),
    encryptionEnabled: encryption ?? () async => encrypted,
    deleteQuietPeriod: deleteQuietPeriod,
    minPushSpacing: minPushSpacing,
    maxPacingWait: maxPacingWait,
    uploadBudget: uploadBudget,
    resetThresholdBytes: resetThresholdBytes ?? kGitHistoryResetThresholdBytes,
    // The tests' server is plain http on loopback.
    allowLoopbackHttp: true,
  );
  addTearDown(provider.dispose);
  return provider;
}

/// How many commits the sync branch of the bare repository [repo] holds.
Future<int> syncBranchCommits(Directory repo) async => int.parse(
  await runGit(repo, ['rev-list', '--count', 'refs/heads/$kDefaultGitBranch']),
);

/// The paths on the sync branch of [repo], one per line.
Future<String> syncBranchFiles(Directory repo) => runGit(repo, [
  'ls-tree',
  '-r',
  '--name-only',
  'refs/heads/$kDefaultGitBranch',
]);
