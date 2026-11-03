#!/usr/bin/env python3
"""Times the web bundle's first start in Chromium under several launch
settings, for issue #4186: on GitHub's runners Chromium stays on the splash
while drift creates the database, at about a twentieth of the speed seen
elsewhere, and Firefox and WebKit start normally.

For each setting: a fresh browser opens the bundle with semantics on, and
every few seconds the main database's size in the origin private file
system, whether drift's lock on it is held, the route, and the frames the
page got are printed, until the welcome screen's first button shows or the
time runs out. Once per setting, the busiest processes on the machine are
printed too, to tell the browser's rendering from its storage.

Run with `python3 scripts/web/startup_probe.py [setting ...]` once the
bundle is served (SMOKE_BASE_URL, default http://127.0.0.1:8080). It never
fails the job: it reports.
"""

import os
import re
import subprocess
import sys
import time

from playwright.sync_api import sync_playwright

BASE_URL = os.environ.get("SMOKE_BASE_URL", "http://127.0.0.1:8080")
LIMIT_S = int(os.environ.get("STARTUP_PROBE_LIMIT_S", "180"))
SAMPLE_S = 5
WELCOME = re.compile(r"^Continue without a sync store$")

# Each setting changes one thing from the smoke's Chromium.
VARIANTS = {
    "as-smoke": {},
    "reduced-motion": {"context": {"reduced_motion": "reduce"}},
    "no-webgl": {"launch": {"args": ["--disable-gpu", "--disable-webgl"]}},
    "headed": {"launch": {"headless": False}},
}

SAMPLE = """async () => {
  const size = async () => {
    try {
      const root = await navigator.storage.getDirectory();
      const dir = await (await root.getDirectoryHandle('drift_db'))
        .getDirectoryHandle('submersion');
      const file = await (await dir.getFileHandle('database')).getFile();
      return file.size;
    } catch (error) {
      return 'none';
    }
  };
  const locks = navigator.locks ? await navigator.locks.query() : null;
  const named = (list) => (list || [])
    .filter((lock) => lock.name.startsWith('drift-db-')).length;
  let frames = 0;
  const count = () => { frames += 1; requestAnimationFrame(count); };
  requestAnimationFrame(count);
  await new Promise((resolve) => setTimeout(resolve, 1000));
  return {
    size: await size(),
    dbLockHeld: locks ? named(locks.held) : 'n/a',
    dbLockPending: locks ? named(locks.pending) : 'n/a',
    framesIn1s: frames,
    route: location.hash || '(none)',
  };
}"""

WEBGL = """() => {
  const gl = document.createElement('canvas').getContext('webgl2')
    || document.createElement('canvas').getContext('webgl');
  if (!gl) return 'none';
  const info = gl.getExtension('WEBGL_debug_renderer_info');
  return String(gl.getParameter(info ? info.UNMASKED_RENDERER_WEBGL : gl.RENDERER));
}"""


def busiest_processes():
    """The machine's top CPU users, where `top` can say (Linux)."""
    try:
        out = subprocess.run(
            ["top", "-b", "-n", "1", "-o", "%CPU", "-w", "160"],
            capture_output=True,
            text=True,
            timeout=10,
        ).stdout
    except (OSError, subprocess.SubprocessError) as error:
        return "top unavailable: %s" % error
    return "\n".join(out.splitlines()[:20])


def probe(playwright, name, variant):
    launch = {"headless": True, **variant.get("launch", {})}
    if not launch["headless"] and not os.environ.get("DISPLAY"):
        print("[%s] skipped: no display" % name, flush=True)
        return
    browser = playwright.chromium.launch(**launch)
    context = browser.new_context(
        viewport={"width": 1280, "height": 900},
        locale="en-US",
        **variant.get("context", {}),
    )
    page = context.new_page()
    started = time.monotonic()
    page.goto(BASE_URL + "/?a11y=1", wait_until="load")
    print("[%s] webgl: %s" % (name, page.evaluate(WEBGL)), flush=True)
    welcome = page.get_by_role("button", name=WELCOME).first
    reported_top = False
    outcome = "still on the splash after %ds" % LIMIT_S
    while time.monotonic() - started < LIMIT_S:
        try:
            welcome.wait_for(timeout=SAMPLE_S * 1000)
            outcome = "welcome after %.1fs" % (time.monotonic() - started)
            break
        except Exception:
            pass
        elapsed = time.monotonic() - started
        print("[%s] %5.1fs %s" % (name, elapsed, page.evaluate(SAMPLE)), flush=True)
        if not reported_top and elapsed > 30:
            print("[%s] busiest processes:\n%s" % (name, busiest_processes()), flush=True)
            reported_top = True
    print("[%s] RESULT: %s" % (name, outcome), flush=True)
    context.close()
    browser.close()


def main(names):
    with sync_playwright() as playwright:
        for name in names or VARIANTS:
            try:
                probe(playwright, name, VARIANTS[name])
            except Exception as error:  # a report, never a failure
                print("[%s] probe failed: %s" % (name, error), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
