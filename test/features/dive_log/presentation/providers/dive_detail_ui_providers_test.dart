import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';

void main() {
  test('CollapsibleSectionState defaults surfaceGps to collapsed', () {
    const s = CollapsibleSectionState();
    expect(s.surfaceGpsExpanded, false);
  });

  test('copyWith updates surfaceGpsExpanded', () {
    const s = CollapsibleSectionState();
    expect(s.copyWith(surfaceGpsExpanded: true).surfaceGpsExpanded, true);
  });
}
