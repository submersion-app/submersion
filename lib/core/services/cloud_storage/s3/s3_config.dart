/// Connection settings for an S3-compatible sync backend.
///
/// Immutable. The public factory normalizes its inputs so every instance
/// holds the invariants: trimmed endpoint without trailing slash, prefix
/// either empty or `segment/` shaped (no leading slash, single trailing
/// slash). An empty [endpoint] means AWS S3 proper, with the host derived
/// from [region].
class S3Config {
  final String endpoint;
  final String region;
  final String bucket;
  final String prefix;
  final bool pathStyle;
  final String accessKeyId;
  final String secretAccessKey;

  const S3Config._({
    required this.endpoint,
    required this.region,
    required this.bucket,
    required this.prefix,
    required this.pathStyle,
    required this.accessKeyId,
    required this.secretAccessKey,
  });

  factory S3Config({
    required String endpoint,
    String region = 'us-east-1',
    required String bucket,
    String prefix = 'submersion-sync/',
    bool? pathStyle,
    required String accessKeyId,
    required String secretAccessKey,
  }) {
    final normalizedEndpoint = _normalizeEndpoint(endpoint);
    final trimmedRegion = region.trim();
    return S3Config._(
      endpoint: normalizedEndpoint,
      region: trimmedRegion.isEmpty ? 'us-east-1' : trimmedRegion,
      bucket: bucket.trim(),
      prefix: _normalizePrefix(prefix),
      pathStyle: pathStyle ?? normalizedEndpoint.isNotEmpty,
      accessKeyId: accessKeyId.trim(),
      secretAccessKey: secretAccessKey.trim(),
    );
  }

  static String _normalizeEndpoint(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static String _normalizePrefix(String raw) {
    var value = raw.trim();
    while (value.startsWith('/')) {
      value = value.substring(1);
    }
    if (value.isEmpty) return '';
    if (!value.endsWith('/')) value = '$value/';
    return value;
  }

  /// AWS S3 proper (host derived from [region]) vs a custom endpoint.
  bool get isAws => endpoint.isEmpty;

  /// Host shown in account labels and used as the AWS base host. Total:
  /// falls back to the raw endpoint string when it does not parse as a URI.
  String get displayHost {
    if (isAws) return 's3.$region.amazonaws.com';
    final host = Uri.tryParse(endpoint)?.host;
    return (host == null || host.isEmpty) ? endpoint : host;
  }

  /// Plain-HTTP custom endpoint (credentials travel unencrypted).
  bool get isInsecureEndpoint =>
      !isAws && Uri.tryParse(endpoint)?.scheme == 'http';

  /// Whether requests travel over TLS. AWS S3 proper is always HTTPS; a
  /// custom endpoint follows its own scheme.
  bool get _usesTls => isAws || Uri.tryParse(endpoint)?.scheme == 'https';

  /// Path-style addressing actually used on the wire, which may diverge from
  /// the stored [pathStyle] flag.
  ///
  /// A bucket whose name contains a dot cannot be reached virtual-hosted-style
  /// over HTTPS: the wildcard certificate (`*.s3.<region>.amazonaws.com`, or
  /// the custom endpoint's equivalent) matches only a single DNS label, so
  /// `my.bucket.s3...` fails the TLS handshake. AWS recommends path-style for
  /// such buckets. Forcing it here repairs already-saved configs without a
  /// migration, and only when TLS is in play (plain HTTP has no cert to break,
  /// so the stored choice is honored). See issue #335.
  bool get effectivePathStyle =>
      pathStyle || (bucket.contains('.') && _usesTls);

  /// First validation problem, or null when the config is usable.
  /// UI-facing field errors live in the form; this is the entity-level guard.
  String? validate() {
    if (bucket.isEmpty) return 'Bucket is required';
    if (accessKeyId.isEmpty) return 'Access Key ID is required';
    if (secretAccessKey.isEmpty) return 'Secret Access Key is required';
    if (endpoint.isNotEmpty) {
      final uri = Uri.tryParse(endpoint);
      if (uri == null ||
          !(uri.scheme == 'http' || uri.scheme == 'https') ||
          uri.host.isEmpty) {
        return 'Endpoint must be a valid http:// or https:// URL';
      }
      if (uri.path.isNotEmpty && uri.path != '/') {
        return 'Endpoint must not include a path';
      }
    }
    return null;
  }

  S3Config copyWith({
    String? endpoint,
    String? region,
    String? bucket,
    String? prefix,
    bool? pathStyle,
    String? accessKeyId,
    String? secretAccessKey,
  }) {
    return S3Config(
      endpoint: endpoint ?? this.endpoint,
      region: region ?? this.region,
      bucket: bucket ?? this.bucket,
      prefix: prefix ?? this.prefix,
      pathStyle: pathStyle ?? this.pathStyle,
      accessKeyId: accessKeyId ?? this.accessKeyId,
      secretAccessKey: secretAccessKey ?? this.secretAccessKey,
    );
  }

  /// Contains the plaintext secret. Route the result only to
  /// FlutterSecureStorage (see S3CredentialsStore); toString is the
  /// redacted form for logs.
  Map<String, Object?> toJson() => {
    'endpoint': endpoint,
    'region': region,
    'bucket': bucket,
    'prefix': prefix,
    'pathStyle': pathStyle,
    'accessKeyId': accessKeyId,
    'secretAccessKey': secretAccessKey,
  };

  factory S3Config.fromJson(Map<String, Object?> json) => S3Config(
    endpoint: json['endpoint'] as String? ?? '',
    region: json['region'] as String? ?? 'us-east-1',
    bucket: json['bucket'] as String? ?? '',
    prefix: json['prefix'] as String? ?? '',
    pathStyle: json['pathStyle'] as bool?,
    accessKeyId: json['accessKeyId'] as String? ?? '',
    secretAccessKey: json['secretAccessKey'] as String? ?? '',
  );

  @override
  String toString() =>
      'S3Config(endpoint: $endpoint, region: $region, bucket: $bucket, '
      'prefix: $prefix, pathStyle: $pathStyle, accessKeyId: $accessKeyId, '
      'secretAccessKey: <redacted>)';
}
