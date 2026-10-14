import 'dart:convert';

import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// Example S3 IAM policies for the two kinds of keys a shared site library
/// hands out (issue #2567). The storage, not the app, is what stops a key
/// from writing, so these are the permissions that make roles real.

String _prefixOf(String folder) {
  final f = folder.trim().replaceAll(RegExp(r'^/+|/+$'), '').trim();
  return f.isEmpty ? 'submersion-sites/' : 'submersion-sites/$f/';
}

/// What a key may read or write in the library at [prefix]: everything
/// under its own folder, or, for a library at the top of
/// `submersion-sites`, its own files and subfolders by name. Other
/// libraries live in folders beside those, and `submersion-sites/*` would
/// hand this library's keys to every one of them.
List<String> _objects(String bucket, String prefix) {
  final base = 'arn:aws:s3:::$bucket/$prefix';
  if (prefix != 'submersion-sites/') return ['$base*'];
  return [
    for (final file in const [
      SharedLibraryLayout.manifestFile,
      SharedLibraryLayout.infoFile,
      SharedLibraryLayout.rolesFile,
      SharedLibraryLayout.keyslotsFile,
    ])
      '$base$file',
    '$base${SharedLibraryLayout.previousKeysPrefix}*.bin',
    for (final dir in const [
      SharedLibraryLayout.membersDir,
      SharedLibraryLayout.sitesDir,
      SharedLibraryLayout.suggestionsDir,
      SharedLibraryLayout.backupsDir,
    ])
      '$base$dir/*',
  ];
}

const _encoder = JsonEncoder.withIndent('  ');

/// [bucket] when a policy can name it as it is; a name holding a wildcard
/// (`*`, `?`), a policy variable (`$`) or a space is no bucket and would
/// grant more than one, so the placeholder stands in.
String _bucketOf(String bucket) {
  final b = bucket.trim();
  return b.isEmpty || b.contains(RegExp(r'[*?$\s]')) ? 'your-bucket' : b;
}

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
  bucket = _bucketOf(bucket);
  return _encoder.convert({
    'Version': '2012-10-17',
    'Statement': [
      _list(bucket, prefix),
      {
        'Effect': 'Allow',
        'Action': ['s3:GetObject', 's3:PutObject', 's3:DeleteObject'],
        'Resource': _objects(bucket, prefix),
      },
    ],
  });
}

/// Readers: read the library folder, write only their own card and their
/// suggestions.
String s3ReaderPolicy({required String bucket, required String folder}) {
  final prefix = _prefixOf(folder);
  bucket = _bucketOf(bucket);
  return _encoder.convert({
    'Version': '2012-10-17',
    'Statement': [
      _list(bucket, prefix),
      {
        'Effect': 'Allow',
        'Action': ['s3:GetObject'],
        'Resource': _objects(bucket, prefix),
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
