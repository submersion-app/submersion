import 'dart:convert';

/// Example S3 IAM policies for the two kinds of keys a shared site library
/// hands out (issue #2567). The storage, not the app, is what stops a key
/// from writing, so these are the permissions that make roles real.

String _prefixOf(String folder) {
  final f = folder.trim().replaceAll(RegExp(r'^/+|/+$'), '').trim();
  return f.isEmpty ? 'submersion-sites/' : 'submersion-sites/$f/';
}

const _encoder = JsonEncoder.withIndent('  ');

Map<String, dynamic> _list(String bucket, String prefix) => {
  'Effect': 'Allow',
  'Action': ['s3:ListBucket'],
  'Resource': ['arn:aws:s3:::$bucket'],
  'Condition': {
    'StringLike': {
      's3:prefix': ['$prefix*'],
    },
  },
};

/// Owners and editors: read and write everything in the library folder.
String s3FullAccessPolicy({required String bucket, required String folder}) {
  final prefix = _prefixOf(folder);
  return _encoder.convert({
    'Version': '2012-10-17',
    'Statement': [
      _list(bucket, prefix),
      {
        'Effect': 'Allow',
        'Action': ['s3:GetObject', 's3:PutObject', 's3:DeleteObject'],
        'Resource': ['arn:aws:s3:::$bucket/$prefix*'],
      },
    ],
  });
}

/// Readers: read the library folder, write only their own card and their
/// suggestions.
String s3ReaderPolicy({required String bucket, required String folder}) {
  final prefix = _prefixOf(folder);
  return _encoder.convert({
    'Version': '2012-10-17',
    'Statement': [
      _list(bucket, prefix),
      {
        'Effect': 'Allow',
        'Action': ['s3:GetObject'],
        'Resource': ['arn:aws:s3:::$bucket/$prefix*'],
      },
      {
        'Effect': 'Allow',
        'Action': ['s3:PutObject', 's3:DeleteObject'],
        'Resource': [
          'arn:aws:s3:::$bucket/${prefix}members/*',
          'arn:aws:s3:::$bucket/${prefix}suggestions/*',
        ],
      },
    ],
  });
}
