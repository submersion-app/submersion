#!/usr/bin/env python3
"""Unit tests for serve_bundle.py."""

import importlib.util
import os
import tempfile
import threading
import unittest
import urllib.request

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "serve_bundle",
    os.path.join(_HERE, "serve_bundle.py"),
)
serve = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(serve)


class ServeBundleTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        with open(os.path.join(self._tmp.name, "index.html"), "w") as handle:
            handle.write("<!doctype html><title>t</title>")
        with open(os.path.join(self._tmp.name, "sqlite3.wasm"), "wb") as handle:
            handle.write(b"\0asm")
        self.server = serve.make_server(self._tmp.name, 0)
        self.addCleanup(self.server.server_close)
        thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(self.server.shutdown)
        self.base = "http://127.0.0.1:%d" % self.server.server_address[1]

    def _head(self, path):
        with urllib.request.urlopen(self.base + path) as response:
            return response.headers, response.read()

    def test_every_file_carries_the_isolation_headers(self):
        headers, body = self._head("/index.html")
        self.assertEqual(headers["Cross-Origin-Opener-Policy"], "same-origin")
        self.assertEqual(
            headers["Cross-Origin-Embedder-Policy"], "credentialless"
        )
        self.assertIn(b"<title>", body)

    def test_wasm_is_served_with_its_media_type(self):
        headers, _ = self._head("/sqlite3.wasm")
        self.assertEqual(headers["Content-Type"], "application/wasm")

    def test_the_root_is_the_index(self):
        headers, body = self._head("/")
        self.assertIn(b"<title>", body)
        self.assertEqual(headers["Cross-Origin-Opener-Policy"], "same-origin")


if __name__ == "__main__":
    unittest.main()
