#!/usr/bin/env python3
"""Serves a built web bundle the way a configured host would.

A plain `http.server` sends none of the headers the hosting guide asks for,
so the smoke job (and anyone trying the bundle locally) would exercise the
slower storage path only. This server adds the two cross-origin isolation
headers to every response and serves `.wasm` with its media type, like the
nginx site, the Caddyfile and `_headers` that ship inside the bundle.

Usage: serve_bundle.py --dir build/web [--port 8080]
"""

import argparse
import functools
import os
import sys
from http import server


class BundleHandler(server.SimpleHTTPRequestHandler):
    """SimpleHTTPRequestHandler plus the isolation headers."""

    extensions_map = {
        **server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript",
        ".mjs": "text/javascript",
        ".json": "application/json",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "credentialless")
        super().end_headers()

    def log_message(self, format, *args):  # noqa: A002 (stdlib signature)
        # One line per request on stderr keeps the job log readable.
        sys.stderr.write("%s %s\n" % (self.address_string(), format % args))


def make_server(directory, port):
    """A server for [directory] on [port] (0 picks a free one), not started."""
    handler = functools.partial(BundleHandler, directory=directory)
    return server.ThreadingHTTPServer(("127.0.0.1", port), handler)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dir", required=True, help="the bundle folder")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args(argv)
    if not os.path.isfile(os.path.join(args.dir, "index.html")):
        parser.error("%s holds no index.html" % args.dir)
    httpd = make_server(args.dir, args.port)
    print(
        "serving %s at http://127.0.0.1:%d"
        % (args.dir, httpd.server_address[1]),
        flush=True,
    )
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
