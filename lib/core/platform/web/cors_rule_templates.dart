import 'package:submersion/core/platform/web/cors_diagnoser.dart';

/// The CORS rule to add to a store so a page at [origin] may use it, in the
/// form that store's tooling takes (issue #4121). [writes] adds the methods
/// sync needs beyond reading.
String corsRuleTemplate(
  StoreKind kind, {
  required String origin,
  required bool writes,
}) => switch (kind) {
  StoreKind.awsS3 ||
  StoreKind.genericS3 ||
  StoreKind.cloudflareR2 => _s3Json(origin, writes),
  StoreKind.backblazeB2 => _b2(origin, writes),
  StoreKind.minio => _minio(origin, writes),
  StoreKind.nextcloud => _nginx(origin, writes),
  StoreKind.genericWebDav => _apache(origin, writes),
};

List<String> _s3Methods(bool writes) => [
  'GET',
  'HEAD',
  if (writes) ...['PUT', 'POST', 'DELETE'],
];

List<String> _davMethods(bool writes) => [
  'GET',
  'HEAD',
  'OPTIONS',
  'PROPFIND',
  if (writes) ...['PUT', 'DELETE', 'MKCOL', 'MOVE'],
];

String _quoted(Iterable<String> values) => values.map((v) => '"$v"').join(', ');

/// The S3 CORS configuration JSON, which AWS, Cloudflare R2 and MinIO's
/// bucket setting all take.
String _s3Json(String origin, bool writes) =>
    '''
[
  {
    "AllowedOrigins": ["$origin"],
    "AllowedMethods": [${_quoted(_s3Methods(writes))}],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag", "x-amz-request-id", "x-amz-version-id", "x-amz-bucket-region"],
    "MaxAgeSeconds": 3000
  }
]
''';

String _b2(String origin, bool writes) {
  final operations = [
    's3_get',
    's3_head',
    if (writes) ...['s3_put', 's3_post', 's3_delete'],
  ];
  return '''
b2 bucket update --cors-rules '[
  {
    "corsRuleName": "submersion-web",
    "allowedOrigins": ["$origin"],
    "allowedOperations": [${_quoted(operations)}],
    "allowedHeaders": ["*"],
    "exposeHeaders": ["etag", "x-amz-request-id", "x-amz-bucket-region"],
    "maxAgeSeconds": 3600
  }
]' <bucket-name>
''';
}

/// MinIO takes the S3 JSON per bucket through `mc cors` on recent
/// releases; older ones allow origins server-wide, every method included.
String _minio(String origin, bool writes) =>
    '''
# Recent MinIO, per bucket:
mc cors set <alias>/<bucket> cors.json
# cors.json:
${_s3Json(origin, writes).trimRight()}

# Older MinIO, server-wide:
mc admin config set <alias> api cors_allow_origin="$origin"
mc admin service restart <alias>
''';

String _nginx(String origin, bool writes) =>
    '''
location /remote.php/dav {
    add_header Access-Control-Allow-Origin "$origin" always;
    add_header Access-Control-Allow-Methods "${_davMethods(writes).join(', ')}" always;
    add_header Access-Control-Allow-Headers "Authorization, Content-Type, Depth, Destination, Overwrite, If-Match, If-None-Match" always;
    add_header Access-Control-Expose-Headers "ETag" always;
    if (\$request_method = OPTIONS) {
        return 204;
    }
}
''';

String _apache(String origin, bool writes) =>
    '''
<Location "/">
    Header always set Access-Control-Allow-Origin "$origin"
    Header always set Access-Control-Allow-Methods "${_davMethods(writes).join(', ')}"
    Header always set Access-Control-Allow-Headers "Authorization, Content-Type, Depth, Destination, Overwrite, If-Match, If-None-Match"
    Header always set Access-Control-Expose-Headers "ETag"
    RewriteEngine On
    RewriteCond %{REQUEST_METHOD} OPTIONS
    RewriteRule ^(.*)\$ \$1 [R=204,L]
</Location>
''';
