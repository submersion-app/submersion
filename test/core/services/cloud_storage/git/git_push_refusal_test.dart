import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/git_push_refusal.dart';

void main() {
  test('a size limit in the remote lines is too large', () {
    final e = classifyPushRefusal('pre-receive hook declined', [
      "error: File b.db is 120.00 MB; this exceeds GitHub's file size limit "
          'of 100.00 MB',
    ]);
    expect(e.code, GitErrorCode.tooLarge);
  });

  test('a size warning does not hide why the push was refused', () {
    // GitHub warns about files over 50 MB on every push, refused or not.
    const warning =
        'warning: File b.db is 60.00 MB; this is larger than GitHub\'s '
        'recommended maximum file size of 50.00 MB';
    expect(
      classifyPushRefusal('fetch first', [warning]).code,
      GitErrorCode.staleTip,
    );
    expect(
      classifyPushRefusal('protected branch hook declined', [warning]).code,
      GitErrorCode.protectedBranch,
    );
  });
}
