import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';

void main() {
  test('everything is included by default', () {
    const options = UddfExportOptions();
    expect(options.includeRawData, isTrue);
    expect(options.includeParticipants, isTrue);
    expect(options.includeGear, isTrue);
  });

  test('copyWith changes only what it is given', () {
    final options = const UddfExportOptions().copyWith(
      includeParticipants: false,
    );
    expect(options.includeRawData, isTrue);
    expect(options.includeParticipants, isFalse);
    expect(options.includeGear, isTrue);
    expect(options.copyWith(includeGear: false).includeParticipants, isFalse);
  });
}
