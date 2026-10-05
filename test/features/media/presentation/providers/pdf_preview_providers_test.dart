import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/presentation/providers/pdf_preview_providers.dart';

void main() {
  test('rounds the physical width up to a cache bucket, capped at 2048', () {
    expect(pdfPreviewBucket(360, 2), 1024);
    expect(pdfPreviewBucket(600, 2), 1536);
    expect(pdfPreviewBucket(700, 2), 1536);
    expect(pdfPreviewBucket(800, 2), 2048);
    expect(pdfPreviewBucket(1400, 3), 2048);
    expect(pdfPreviewBucket(0, 1), 1024);
  });
}
