import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

void main() {
  test('returns the right engine type for this host', () {
    final engine = engineForThisPlatform();
    if (Platform.isMacOS ||
        Platform.isIOS ||
        Platform.isAndroid ||
        Platform.isWindows) {
      expect(engine, isA<ChannelTranscodeEngine>());
    } else if (Platform.isLinux) {
      expect(engine, isA<LinuxFfmpegEngine>());
    } else {
      expect(engine, isNull);
    }
  });
}
