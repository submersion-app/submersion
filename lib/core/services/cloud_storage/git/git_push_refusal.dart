import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';

/// Turns a refused push into a typed [GitException].
///
/// [reason] is the host's `ng` (or failed `unpack`) text, which for a policy
/// check is often only "pre-receive hook declined". [remoteLines] are the
/// progress lines the host sent alongside (shown as `remote:` by stock Git):
/// that is where GitHub, GitLab and Gitea explain a size limit or a
/// protected branch, so both are read. Size and protection are checked
/// before staleness, because a policy message can also mention a ref
/// update. Warnings are left out: GitHub warns about any file over 50 MB on
/// every push, so one says nothing about why this push was refused.
GitException classifyPushRefusal(String reason, List<String> remoteLines) {
  final text = [
    reason,
    ...remoteLines.where(
      (l) => !l.trimLeft().toLowerCase().startsWith('warning:'),
    ),
  ].join('\n').toLowerCase();
  final GitErrorCode code;
  // GitHub: "GH001: Large files detected"; GitLab: "files which exceed the
  // 100MiB limit", "is larger than the allowed size", "has exceeded its size
  // limit".
  if (text.contains('gh001') ||
      text.contains('large files detected') ||
      text.contains('too large') ||
      text.contains('larger than') ||
      text.contains('size limit') ||
      text.contains('exceed')) {
    code = GitErrorCode.tooLarge;
  } else if (text.contains('protected branch') ||
      text.contains('protected ref') ||
      text.contains('force push') ||
      text.contains('force-push') ||
      (text.contains('denied') && text.contains('force'))) {
    code = GitErrorCode.protectedBranch;
  } else if (text.contains('fetch first') ||
      text.contains('non-fast-forward') ||
      text.contains('stale info') ||
      text.contains('failed to lock') ||
      text.contains('cannot lock') ||
      text.contains('failed to update ref') ||
      text.contains('already exists') ||
      text.contains('incorrect old value')) {
    code = GitErrorCode.staleTip;
  } else {
    code = GitErrorCode.server;
  }
  final explained = remoteLines.where((l) => l.trim().isNotEmpty).join(' ');
  return GitException(
    'The Git host refused the push.',
    code: code,
    serverReason: explained.isEmpty ? reason : '$reason: $explained',
  );
}
