import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/shared_library/domain/storage_policy_examples.dart';

void main() {
  List<Map<String, dynamic>> statements(String policy) =>
      ((jsonDecode(policy) as Map)['Statement'] as List)
          .cast<Map<String, dynamic>>();

  Map<String, dynamic> withAction(String policy, String action) => statements(
    policy,
  ).firstWhere((s) => (s['Action'] as List).contains(action));

  test('the reader policy writes only members and suggestions', () {
    final policy = s3ReaderPolicy(bucket: 'b', folder: 'reef');
    expect(withAction(policy, 's3:PutObject')['Resource'], [
      'arn:aws:s3:::b/submersion-sites/reef/members/*',
      'arn:aws:s3:::b/submersion-sites/reef/suggestions/*',
    ]);
    expect(withAction(policy, 's3:GetObject')['Resource'], [
      'arn:aws:s3:::b/submersion-sites/reef/*',
    ]);
    expect(withAction(policy, 's3:ListBucket')['Condition'], {
      'StringLike': {
        's3:prefix': ['submersion-sites/reef/*'],
      },
    });
  });

  test('the full policy reads and writes the library folder', () {
    final policy = s3FullAccessPolicy(bucket: 'b', folder: 'reef');
    expect(withAction(policy, 's3:DeleteObject')['Resource'], [
      'arn:aws:s3:::b/submersion-sites/reef/*',
    ]);
    expect(withAction(policy, 's3:PutObject')['Resource'], [
      'arn:aws:s3:::b/submersion-sites/reef/*',
    ]);
  });

  test('a library at the top reaches only its own files', () {
    // Other libraries live in folders beside its own subfolders: a key for
    // this one must not reach into them.
    const own = [
      'arn:aws:s3:::b/submersion-sites/submersion-shared-library.json',
      'arn:aws:s3:::b/submersion-sites/info.json',
      'arn:aws:s3:::b/submersion-sites/roles.json',
      'arn:aws:s3:::b/submersion-sites/keyslots.json',
      'arn:aws:s3:::b/submersion-sites/previous-keys-*.bin',
      'arn:aws:s3:::b/submersion-sites/members/*',
      'arn:aws:s3:::b/submersion-sites/sites/*',
      'arn:aws:s3:::b/submersion-sites/suggestions/*',
      'arn:aws:s3:::b/submersion-sites/backups/*',
    ];
    final full = s3FullAccessPolicy(bucket: 'b', folder: ' / ');
    expect(withAction(full, 's3:PutObject')['Resource'], own);
    final reader = s3ReaderPolicy(bucket: 'b', folder: '');
    expect(withAction(reader, 's3:GetObject')['Resource'], own);
    expect(withAction(reader, 's3:PutObject')['Resource'], [
      'arn:aws:s3:::b/submersion-sites/members/*',
      'arn:aws:s3:::b/submersion-sites/suggestions/*',
    ]);
    for (final policy in [full, reader]) {
      for (final s in statements(policy)) {
        if ((s['Action'] as List).contains('s3:ListBucket')) continue;
        expect(
          s['Resource'],
          isNot(contains('arn:aws:s3:::b/submersion-sites/*')),
        );
      }
    }
  });

  test('a bucket name a policy would read as a wildcard is not used', () {
    for (final bucket in ['shared-*', 'a?b', r'my$bucket', 'two words']) {
      for (final policy in [
        s3FullAccessPolicy(bucket: bucket, folder: 'reef'),
        s3ReaderPolicy(bucket: bucket, folder: 'reef'),
      ]) {
        expect(policy, isNot(contains(bucket)), reason: bucket);
        expect(policy, contains('arn:aws:s3:::your-bucket'), reason: bucket);
      }
    }
  });
}
