import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';

void main() {
  test('surfaceGps is a known section and present in defaults', () {
    expect(
      DiveDetailSectionId.values.contains(DiveDetailSectionId.surfaceGps),
      true,
    );
    expect(
      DiveDetailSectionConfig.defaultSections.any(
        (c) => c.id == DiveDetailSectionId.surfaceGps,
      ),
      true,
    );
  });
}
