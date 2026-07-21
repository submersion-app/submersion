import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

const _ffprobeJson = '''
{
  "streams": [
    {"codec_type": "audio", "codec_name": "aac"},
    {"codec_type": "video", "codec_name": "h264", "width": 1920, "height": 1080}
  ],
  "format": {"duration": "12.480000", "bit_rate": "9600000"}
}
''';

void main() {
  test('parses dimensions, duration, and overall bitrate', () {
    final probe = parseFfprobeJson(_ffprobeJson)!;
    expect(probe.width, 1920);
    expect(probe.height, 1080);
    expect(probe.durationMs, 12480);
    expect(probe.overallBitrateKbps, 9600);
  });

  test('derives bitrate from size and duration when bit_rate is N/A', () {
    // ffprobe emits bit_rate "N/A" for some containers; a 0 here would make
    // the ceiling rule skip transcoding a high-bitrate clip.
    final probe = parseFfprobeJson(
      '{"streams": [{"codec_type": "video", "width": 1920, "height": 1080}], '
      '"format": {"duration": "10", "bit_rate": "N/A", "size": "12500000"}}',
    )!;
    // 12500000 bytes * 8 / 10s = 10_000_000 bps = 10000 kbps.
    expect(probe.overallBitrateKbps, 10000);
  });

  test('returns null when no video stream exists', () {
    expect(
      parseFfprobeJson('{"streams": [], "format": {"duration": "1"}}'),
      isNull,
    );
  });

  test('returns null on malformed json', () {
    expect(parseFfprobeJson('not json'), isNull);
  });

  test('returns null on an unexpected json shape rather than throwing', () {
    // Valid JSON, wrong shapes: each must fall back (upload original), never
    // throw a TypeError/CastError.
    expect(parseFfprobeJson('[]'), isNull, reason: 'root is a list');
    expect(parseFfprobeJson('42'), isNull, reason: 'root is a scalar');
    expect(
      parseFfprobeJson('{"streams": {"0": {}}}'),
      isNull,
      reason: 'streams is an object, not a list',
    );
    expect(
      parseFfprobeJson('{"streams": ["not-an-object"]}'),
      isNull,
      reason: 'stream entry is not a map',
    );
    expect(
      parseFfprobeJson(
        '{"streams": [{"codec_type": "video", "width": "1920", "height": 1080}]}',
      ),
      isNull,
      reason: 'width is a string, not an int',
    );
    expect(
      parseFfprobeJson(
        '{"streams": [{"codec_type": "video", "width": 1920, "height": 1080}], '
        '"format": "not-a-map"}',
      ),
      isNotNull,
      reason: 'a non-map format degrades to zero duration/bitrate, not a throw',
    );
  });
}
