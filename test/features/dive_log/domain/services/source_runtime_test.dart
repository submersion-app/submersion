import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/source_runtime.dart';

void main() {
  const entryMs = 1000000;
  const exitMs = entryMs + 3000 * 1000;

  test('the runtime a source reports wins over its timestamps', () {
    expect(
      sourceRuntimeSeconds(
        durationSeconds: 2900,
        entryTimeMs: entryMs,
        exitTimeMs: exitMs,
      ),
      2900,
    );
  });

  test(
    'a source reporting no runtime falls back to its entry-to-exit span',
    () {
      expect(
        sourceRuntimeSeconds(
          durationSeconds: null,
          entryTimeMs: entryMs,
          exitTimeMs: exitMs,
        ),
        3000,
      );
    },
  );

  test('a reported runtime of zero is not a measurement', () {
    expect(
      sourceRuntimeSeconds(
        durationSeconds: 0,
        entryTimeMs: entryMs,
        exitTimeMs: exitMs,
      ),
      3000,
    );
  });

  test('a partial second of span truncates like Duration.inSeconds', () {
    expect(
      sourceRuntimeSeconds(
        durationSeconds: null,
        entryTimeMs: entryMs,
        exitTimeMs: entryMs + 1999,
      ),
      1,
    );
  });

  test('is null with no runtime and a missing timestamp', () {
    expect(
      sourceRuntimeSeconds(
        durationSeconds: null,
        entryTimeMs: entryMs,
        exitTimeMs: null,
      ),
      isNull,
    );
    expect(
      sourceRuntimeSeconds(
        durationSeconds: null,
        entryTimeMs: null,
        exitTimeMs: exitMs,
      ),
      isNull,
    );
  });

  test('is null with no runtime and timestamps that are not increasing', () {
    expect(
      sourceRuntimeSeconds(
        durationSeconds: null,
        entryTimeMs: exitMs,
        exitTimeMs: entryMs,
      ),
      isNull,
    );
    expect(
      sourceRuntimeSeconds(
        durationSeconds: null,
        entryTimeMs: entryMs,
        exitTimeMs: entryMs,
      ),
      isNull,
    );
  });
}
