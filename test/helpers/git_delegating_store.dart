import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';

/// A [GitObjectStore] that passes every call to [inner], for a test store
/// that changes only one or two of them.
class DelegatingGitObjectStore implements GitObjectStore {
  DelegatingGitObjectStore(this.inner);

  final GitObjectStore inner;

  @override
  Future<GitStoredObject?> get(GitObjectId id) => inner.get(id);

  @override
  Future<void> put(GitStoredObject object) => inner.put(object);

  @override
  Future<bool> has(GitObjectId id) => inner.has(id);

  @override
  Future<GitObjectReader?> open(GitObjectId id) => inner.open(id);

  @override
  GitObjectWriter create(GitObjectType type, int size) =>
      inner.create(type, size);

  @override
  Future<void> trim({Future<Set<GitObjectId>> Function()? keep}) =>
      inner.trim(keep: keep);
}
