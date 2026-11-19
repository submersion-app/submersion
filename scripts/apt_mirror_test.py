#!/usr/bin/env python3
"""Unit tests for apt_mirror.py."""

import contextlib
import importlib.util
import io
import os
import shutil
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name):
    spec = importlib.util.spec_from_file_location(
        name, os.path.join(_HERE, f"{name}.py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


mirror = _load("apt_mirror")

AZURE = "http://azure.archive.ubuntu.com/ubuntu/"


class RewriteTest(unittest.TestCase):
    def test_regional_ec2_mirror_becomes_azure(self):
        text = (
            "http://us-east-2.ec2.archive.ubuntu.com/ubuntu/\tpriority:1\n"
            "https://archive.ubuntu.com/ubuntu/\tpriority:2\n"
        )
        self.assertEqual(
            mirror.rewrite(text),
            f"{AZURE}\tpriority:1\nhttps://archive.ubuntu.com/ubuntu/\tpriority:2\n",
        )

    def test_https_and_other_regions_are_rewritten(self):
        for url in (
            "https://us-east-2.ec2.archive.ubuntu.com/ubuntu/",
            "http://eu-west-1.ec2.archive.ubuntu.com/ubuntu",
        ):
            with self.subTest(url=url):
                self.assertEqual(mirror.rewrite(f"URIs: {url}\n"), f"URIs: {AZURE}\n")

    def test_one_line_sources_list_is_rewritten(self):
        line = "deb http://us-west-2.ec2.archive.ubuntu.com/ubuntu/ noble main\n"
        self.assertEqual(mirror.rewrite(line), f"deb {AZURE} noble main\n")

    def test_a_mirror_list_keeps_its_first_entry_per_url(self):
        # The ec2 image may already list azure further down. Rewriting the
        # ec2 line to azure must not leave azure in the list twice.
        text = (
            "http://us-east-2.ec2.archive.ubuntu.com/ubuntu/\tpriority:1\n"
            f"{AZURE}\tpriority:2\n"
            "https://archive.ubuntu.com/ubuntu/\tpriority:3\n"
        )
        self.assertEqual(
            mirror.rewrite_mirror_list(text),
            f"{AZURE}\tpriority:1\nhttps://archive.ubuntu.com/ubuntu/\tpriority:3\n",
        )

    def test_other_hosts_are_untouched(self):
        text = (
            f"{AZURE}\tpriority:1\n"
            "http://security.ubuntu.com/ubuntu/\tpriority:3\n"
            "URIs: https://packages.microsoft.com/ubuntu/24.04/prod\n"
            "deb http://ports.ubuntu.com/ubuntu-ports noble main\n"
        )
        self.assertEqual(mirror.rewrite(text), text)
        self.assertEqual(mirror.rewrite_mirror_list(text), text)


class MainTest(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root)
        os.makedirs(os.path.join(self.root, "etc", "apt", "sources.list.d"))

    def path(self, *parts):
        return os.path.join(self.root, "etc", "apt", *parts)

    def write(self, rel, text):
        with open(self.path(*rel), "w", encoding="utf-8") as fh:
            fh.write(text)

    def read(self, rel):
        with open(self.path(*rel), encoding="utf-8") as fh:
            return fh.read()

    def run_main(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = mirror.main(self.root)
        return code, out.getvalue()

    def test_rewrites_every_apt_source_file(self):
        ec2 = "http://us-east-2.ec2.archive.ubuntu.com/ubuntu/"
        self.write(("apt-mirrors.txt",), f"{ec2}\tpriority:1\n")
        self.write(("sources.list",), f"deb {ec2} noble main\n")
        self.write(("sources.list.d", "ubuntu.sources"), f"URIs: {ec2}\n")
        self.write(("sources.list.d", "extra.list"), f"deb {ec2} noble universe\n")
        code, out = self.run_main()
        self.assertEqual(code, 0, out)
        self.assertEqual(self.read(("apt-mirrors.txt",)), f"{AZURE}\tpriority:1\n")
        self.assertEqual(self.read(("sources.list",)), f"deb {AZURE} noble main\n")
        self.assertEqual(
            self.read(("sources.list.d", "ubuntu.sources")), f"URIs: {AZURE}\n"
        )
        self.assertEqual(
            self.read(("sources.list.d", "extra.list")), f"deb {AZURE} noble universe\n"
        )
        self.assertIn("apt-mirrors.txt", out)

    def test_an_azure_runner_is_left_alone(self):
        text = f"{AZURE}\tpriority:1\nhttps://archive.ubuntu.com/ubuntu/\tpriority:2\n"
        self.write(("apt-mirrors.txt",), text)
        code, out = self.run_main()
        self.assertEqual(code, 0, out)
        self.assertEqual(self.read(("apt-mirrors.txt",)), text)
        self.assertIn("no regional EC2 mirror", out)

    def test_missing_files_are_not_an_error(self):
        code, out = self.run_main()
        self.assertEqual(code, 0, out)


if __name__ == "__main__":
    unittest.main()
