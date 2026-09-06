import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_cloud_event_map.dart';

void main() {
  group('suuntoCloudEvent', () {
    test('maps a known event to a libdc type + native code', () {
      final e = suuntoCloudEvent('Alarm', 'Ascent Speed')!;
      expect(e.downloadedType, 'ascent');
      expect(e.nativeCode, (0x18 << 8) | 5);
    });

    test('covers every sub-group', () {
      expect(
        suuntoCloudEvent('Alarm', 'Tank Pressure')?.downloadedType,
        'airtime',
      );
      expect(
        suuntoCloudEvent('Warning', 'CNS80%')?.downloadedType,
        'cnsWarning',
      );
      expect(
        suuntoCloudEvent('Notify', 'Gas Switch')?.downloadedType,
        'gaschange',
      );
      expect(suuntoCloudEvent('State', 'At Deco Stop')?.downloadedType, 'deco');
      expect(
        suuntoCloudEvent('State', 'At Safety Stop')?.downloadedType,
        'safetystop',
      );
      expect(
        suuntoCloudEvent('Ooam', 'Ceiling broken')?.downloadedType,
        'ceiling',
      );
    });

    test('the native code is (sub-group << 8) | type', () {
      expect(
        suuntoCloudEvent('State', 'At Deco Stop')!.nativeCode,
        (0x1B << 8) | 35,
      );
      expect(
        suuntoCloudEvent('Ooam', 'Ceiling broken')!.nativeCode,
        (0x1D << 8) | 2,
      );
    });

    test('returns null for an unknown or deliberately-dropped event', () {
      expect(suuntoCloudEvent('Alarm', 'Battery'), isNull);
      expect(suuntoCloudEvent('State', 'Deco Stop Ahead'), isNull);
      expect(suuntoCloudEvent('Notify', 'Bearing set'), isNull);
      expect(suuntoCloudEvent('Nope', 'Ascent Speed'), isNull);
      expect(suuntoCloudEvent('Alarm', null), isNull);
    });
  });
}
