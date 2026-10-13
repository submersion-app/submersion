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

  test('an empty folder is submersion-sites itself', () {
    final policy = s3FullAccessPolicy(bucket: 'b', folder: ' / ');
    expect(withAction(policy, 's3:GetObject')['Resource'], [
      'arn:aws:s3:::b/submersion-sites/*',
    ]);
  });
}
