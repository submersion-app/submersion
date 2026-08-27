import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/utils/byte_format.dart';

void main() {
  test('renders bytes below a kilobyte verbatim', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1023), '1023 B');
  });

  test('renders kilobytes and megabytes to one decimal', () {
    expect(formatBytes(1024), '1.0 KB');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(1024 * 1024), '1.0 MB');
    expect(formatBytes(3 * 1024 * 1024 + 512 * 1024), '3.5 MB');
  });

  test('renders gigabytes to two decimals', () {
    expect(formatBytes(1024 * 1024 * 1024), '1.00 GB');
    expect(formatBytes(5 * 1024 * 1024 * 1024), '5.00 GB');
  });

  test('treats a negative size as zero rather than rendering it', () {
    expect(formatBytes(-1), '0 B');
  });
}
