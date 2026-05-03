import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';

void main() {
  test('ManifestParseResult exposes entries, format, title, warnings', () {
    const r = ManifestParseResult(
      format: ManifestFormat.json,
      title: 'My Feed',
      entries: [ManifestEntry(entryKey: 'a', url: 'https://x/a.jpg')],
      warnings: ['skipped row 7: missing url'],
    );
    expect(r.entries, hasLength(1));
    expect(r.title, 'My Feed');
    expect(r.warnings, hasLength(1));
    expect(r.format, ManifestFormat.json);
  });
}
