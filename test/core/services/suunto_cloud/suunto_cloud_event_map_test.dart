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

    test(
      'the native code is (sub-group << 8) | type, keyed to its sub-group',
      () {
        for (final entry in const [
          ('Alarm', 'Ascent Speed', 0x18),
          ('Warning', 'CNS80%', 0x19),
          ('Notify', 'Gas Switch', 0x1A),
          ('State', 'At Deco Stop', 0x1B),
          ('Ooam', 'Ceiling broken', 0x1D),
        ]) {
          final code = suuntoCloudEvent(entry.$1, entry.$2)!.nativeCode!;
          expect(code >> 8, entry.$3, reason: '${entry.$1}/${entry.$2}');
        }
      },
    );

    test(
      'a legacy string with no Nautic type number carries no native code',
      () {
        // "Safety Stop" via Notify is a pre-Nautic string; the Nautic descriptor
        // announces the stop through State "At Safety Stop".
        final e = suuntoCloudEvent('Notify', 'Safety Stop')!;
        expect(e.downloadedType, 'safetystop');
        expect(e.nativeCode, isNull);
      },
    );

    test('returns null for an unknown or deliberately-dropped event', () {
      expect(suuntoCloudEvent('Alarm', 'Battery'), isNull);
      expect(suuntoCloudEvent('State', 'Deco Stop Ahead'), isNull);
      expect(suuntoCloudEvent('Notify', 'Bearing set'), isNull);
      expect(suuntoCloudEvent('Nope', 'Ascent Speed'), isNull);
      expect(suuntoCloudEvent('Alarm', null), isNull);
    });
  });
}
