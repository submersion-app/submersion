import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/pop_out/domain/pop_out_frame.dart';

void main() {
  const laptop = PopOutFrame(x: 0, y: 0, width: 1728, height: 1117);
  const external = PopOutFrame(x: 1728, y: -200, width: 2560, height: 1440);
  const mainOnLaptop = PopOutFrame(x: 100, y: 50, width: 1280, height: 900);

  test('saved frame on a display is kept', () {
    const saved = PopOutFrame(x: 2000, y: 0, width: 1000, height: 700);
    expect(
      resolvePopOutFrame(
        saved: saved,
        displays: const [laptop, external],
        mainWindow: mainOnLaptop,
      ),
      saved,
    );
  });

  test("frame off every display falls back to main window's display", () {
    // The external monitor that held it has been unplugged.
    const saved = PopOutFrame(x: 2000, y: 0, width: 1000, height: 700);
    final frame = resolvePopOutFrame(
      saved: saved,
      displays: const [laptop],
      mainWindow: mainOnLaptop,
    );
    expect(frame.width, 900);
    expect(frame.height, 600);
    expect(frame.x, (1728 - 900) / 2);
    expect(frame.y, (1117 - 600) / 2);
  });

  test('no saved frame opens at the default size on the main display', () {
    const mainOnExternal = PopOutFrame(x: 2000, y: 0, width: 1280, height: 900);
    final frame = resolvePopOutFrame(
      saved: null,
      displays: const [laptop, external],
      mainWindow: mainOnExternal,
    );
    expect(frame.x, 1728 + (2560 - 900) / 2);
    expect(frame.y, -200 + (1440 - 600) / 2);
  });

  test('frame below the minimum is clamped', () {
    const saved = PopOutFrame(x: 10, y: 10, width: 100, height: 50);
    final frame = resolvePopOutFrame(
      saved: saved,
      displays: const [laptop],
      mainWindow: mainOnLaptop,
    );
    expect(frame.x, 10);
    expect(frame.y, 10);
    expect(frame.width, 480);
    expect(frame.height, 320);
  });

  test('a frame whose title strip is off screen is not kept', () {
    // Body overlaps the laptop, but the title bar sits above the top edge,
    // so the diver could not drag it back.
    const saved = PopOutFrame(x: 100, y: -500, width: 900, height: 600);
    final frame = resolvePopOutFrame(
      saved: saved,
      displays: const [laptop],
      mainWindow: mainOnLaptop,
    );
    expect(frame.y, isNot(-500));
  });

  test('no displays at all keeps the default size near the main window', () {
    final frame = resolvePopOutFrame(
      saved: null,
      displays: const [],
      mainWindow: mainOnLaptop,
    );
    expect(frame.width, 900);
    expect(frame.height, 600);
    expect(frame.x, 100 + (1280 - 900) / 2);
    expect(frame.y, 50 + (900 - 600) / 2);
  });

  test('frame map round-trips and rejects junk', () {
    const frame = PopOutFrame(x: 1.5, y: 2, width: 3, height: 4);
    expect(PopOutFrame.fromMap(frame.toMap()), frame);
    expect(PopOutFrame.fromMap(null), isNull);
    expect(PopOutFrame.fromMap({'x': 'a'}), isNull);
  });
}
