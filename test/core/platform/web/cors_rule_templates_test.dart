import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/web/cors_diagnoser.dart';
import 'package:submersion/core/platform/web/cors_rule_templates.dart';

/// The rule the help sheet prints for each kind of store (issue #4121),
/// with the site's own address already filled in.
void main() {
  const origin = 'https://dives.example.com';

  test('every kind names the origin', () {
    for (final kind in StoreKind.values) {
      final rule = corsRuleTemplate(kind, origin: origin, writes: true);
      expect(rule, contains(origin), reason: kind.name);
      expect(rule.trim(), isNotEmpty, reason: kind.name);
    }
  });

  test('writes add PUT and DELETE; a read-only rule leaves them out', () {
    for (final kind in StoreKind.values) {
      final full = corsRuleTemplate(kind, origin: origin, writes: true);
      final readOnly = corsRuleTemplate(kind, origin: origin, writes: false);
      expect(full.toUpperCase(), contains('PUT'), reason: kind.name);
      expect(full.toUpperCase(), contains('DELETE'), reason: kind.name);
      expect(readOnly.toUpperCase(), isNot(contains('PUT')), reason: kind.name);
      expect(
        readOnly.toUpperCase(),
        isNot(contains('DELETE')),
        reason: kind.name,
      );
    }
  });

  test('each store gets the form its tooling takes', () {
    expect(
      corsRuleTemplate(StoreKind.awsS3, origin: origin, writes: true),
      contains('"AllowedOrigins"'),
    );
    expect(
      corsRuleTemplate(StoreKind.backblazeB2, origin: origin, writes: true),
      contains('b2 bucket update --cors-rules'),
    );
    expect(
      corsRuleTemplate(StoreKind.minio, origin: origin, writes: true),
      contains('mc admin config set'),
    );
    expect(
      corsRuleTemplate(StoreKind.nextcloud, origin: origin, writes: true),
      contains('add_header Access-Control-Allow-Origin'),
    );
    expect(
      corsRuleTemplate(StoreKind.genericWebDav, origin: origin, writes: true),
      contains('Header always set Access-Control-Allow-Origin'),
    );
    expect(
      corsRuleTemplate(StoreKind.genericWebDav, origin: origin, writes: true),
      contains('PROPFIND'),
    );
  });

  test('the S3 rule exposes the header region correction reads', () {
    final rule = corsRuleTemplate(
      StoreKind.awsS3,
      origin: 'https://dive.example.com',
      writes: true,
    );
    expect(rule, contains('x-amz-bucket-region'));
  });

  test('the WebDAV rules allow the Range header video streaming sends', () {
    // Issue #4162: Drive and WebDAV videos are read a range at a time.
    for (final kind in [StoreKind.nextcloud, StoreKind.genericWebDav]) {
      final rule = corsRuleTemplate(kind, origin: origin, writes: false);
      expect(
        rule,
        matches(RegExp(r'Allow-Headers[^\n]*\bRange\b')),
        reason: '$kind',
      );
    }
  });
}
