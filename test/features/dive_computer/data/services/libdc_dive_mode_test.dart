import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/data/services/libdc_dive_mode.dart';

void main() {
  test('maps libdivecomputer dive-mode strings to app codes', () {
    expect(mapLibdcDiveModeCode('gauge'), 'gauge');
    expect(mapLibdcDiveModeCode('open_circuit'), 'oc');
    expect(mapLibdcDiveModeCode('ccr'), 'ccr');
    expect(mapLibdcDiveModeCode('scr'), 'scr');
    expect(mapLibdcDiveModeCode('freedive'), 'oc'); // deferred: freedive -> oc
    expect(mapLibdcDiveModeCode(null), 'oc');
  });
}
