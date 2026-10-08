import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_cloud_event_map.dart';
import 'package:submersion/features/dive_log/domain/entities/suunto_native_event.dart';

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

    test('a low-ppO2 alarm is imported as low ppO2, not high (#1523)', () {
      final e = suuntoCloudEvent('Alarm', 'PO2 Low')!;
      expect(e.downloadedType, 'ppO2Low');
      expect(e.nativeCode, (0x18 << 8) | 1);
      expect(suuntoCloudEvent('Alarm', 'PO2 High')?.downloadedType, 'PO2');
    });

    test('a broken deep stop is a violation, not a stop start (#1523)', () {
      // 'deepstop' would map to decoStopStart and read "Deco Stop Start".
      final e = suuntoCloudEvent('Alarm', 'Deep Stop Broken')!;
      expect(e.downloadedType, 'violation');
      expect(e.nativeCode, (0x18 << 8) | 12);
    });

    test('imports low no-deco time and became-a-deco-dive (#1523)', () {
      final lowNdl = suuntoCloudEvent('Warning', 'NoDecoTime')!;
      expect(lowNdl.downloadedType, 'lowNoDecoTime');
      expect(lowNdl.nativeCode, (0x19 << 8) | 20);

      final decoDive = suuntoCloudEvent('State', 'Ndl exceeded')!;
      expect(decoDive.downloadedType, 'decompressionDive');
      expect(decoDive.nativeCode, (0x1B << 8) | 19);
    });

    test('every alarm, warning and stop code decodes to an exact Suunto '
        'label (#1523)', () {
      // The types whose own ProfileEventType already is the exact wording
      // carry no separate label.
      const ownLabel = {
        ('Notify', 'Gas Switch'),
        ('Warning', 'NoDecoTime'),
        ('State', 'Ndl exceeded'),
      };
      for (final (subgroup, type) in suuntoCloudEventKeys) {
        final code = suuntoCloudEvent(subgroup, type)!.nativeCode;
        if (code == null || ownLabel.contains((subgroup, type))) continue;
        expect(
          SuuntoNativeEvent.fromCode(code),
          isNotNull,
          reason: '$subgroup/$type (0x${code.toRadixString(16)})',
        );
      }
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
