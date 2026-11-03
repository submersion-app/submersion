#!/usr/bin/env python3
"""Stages a release's web bundle as Submersion's own site, and guards its age.

`.github/workflows/deploy-web.yml` publishes each stable release's
`Submersion-<tag>-Web.zip` to GitHub Pages at https://web.submersion.app
(issue #4161). This script does the parts worth testing:

`stage` unzips the bundle into an empty folder, refusing any entry that
would land outside it, runs `scripts/check_web_bundle.py` on the result,
and adds the two files Pages needs: `CNAME`, which keeps the custom domain
across a force-pushed deploy, and `.nojekyll`, which serves the files as
they are. It also looks for Submersion's Google web client and the site's
address in `main.dart.js` (dart2js keeps both as string constants). The
client is built in when the beta is built, so a release whose beta came
before the client was configured carries none; that bundle still deploys
(spec decision 7), with a warning, and Google Drive on the site asks for a
client id until the next release.

`check-newer` compares the staged bundle's `version.json` with the one the
site serves and refuses an older bundle unless `--force` (spec decision 8):
every visitor's library lives in their browser on the one origin, already
moved to the newer schema, and an older release cannot open it. A deployed
version that cannot be read (an empty Pages repository, the first deploy)
lets the deploy go ahead.

Usage:
  stage_hosted_site.py stage ZIP OUT --domain DOMAIN [--client-id ID] [--lock LOCK]
  stage_hosted_site.py check-newer STAGED_VERSION_JSON CURRENT_VERSION_JSON [--force]
Prints OK lines and ::warning:: or ::error:: annotations; exits 1 when the
deploy must stop.
"""

import argparse
import importlib.util
import json
import os
import sys
import zipfile

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "check_web_bundle",
    os.path.join(os.path.dirname(_HERE), "check_web_bundle.py"),
)
check_web_bundle = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(check_web_bundle)


class StageError(Exception):
    """The bundle cannot be staged; the message says why."""


def _extract(zip_path, out_dir):
    try:
        archive = zipfile.ZipFile(zip_path)
    except (OSError, zipfile.BadZipFile) as exc:
        raise StageError(f"cannot open {zip_path}: {exc}") from exc
    root = os.path.realpath(out_dir)
    with archive:
        for name in archive.namelist():
            target = os.path.realpath(os.path.join(root, name))
            if os.path.isabs(name) or os.path.commonpath([root, target]) != root:
                raise StageError(f"{name} would land outside {out_dir}")
        archive.extractall(root)


def client_warnings(bundle_dir, client_id, origin):
    """Warnings when the bundle lacks Submersion's client or the site's origin."""
    if not client_id:
        return [
            "GOOGLE_WEB_CLIENT_ID is not set, so the site's Google Drive "
            "sign-in cannot be checked; visitors may be asked for a client id"
        ]
    try:
        with open(
            os.path.join(bundle_dir, "main.dart.js"), encoding="utf-8", errors="replace"
        ) as handle:
            compiled = handle.read()
    except OSError:
        return ["main.dart.js cannot be read, so the Google client cannot be checked"]
    if client_id not in compiled:
        return [
            f"the bundle was built without the Google client {client_id}; "
            "Google Drive on the site asks for a client id until a release "
            "built with it is deployed"
        ]
    # A plain substring: the origin is the GOOGLE_WEB_CLIENT_ORIGINS define,
    # and nothing else in lib/ spells the site's address today. A literal of
    # it added elsewhere would let a bundle built for another origin pass.
    if origin not in compiled:
        return [
            f"the bundle's Google client is not authorised for {origin}; "
            "Google Drive on the site asks for a client id"
        ]
    return []


def stage_site(zip_path, out_dir, domain, client_id, lock_path):
    """Stages the bundle in out_dir and returns its warnings."""
    if os.path.exists(out_dir) and (
        not os.path.isdir(out_dir) or os.listdir(out_dir)
    ):
        raise StageError(f"{out_dir} is not empty; stage into a new folder")
    os.makedirs(out_dir, exist_ok=True)
    _extract(zip_path, out_dir)
    failures = check_web_bundle.check_bundle(
        out_dir, lock_path
    ) + check_web_bundle.check_sample_logbook(out_dir)
    if failures:
        raise StageError("; ".join(failures))
    with open(os.path.join(out_dir, "CNAME"), "w", encoding="utf-8") as handle:
        handle.write(f"{domain}\n")
    with open(os.path.join(out_dir, ".nojekyll"), "w", encoding="utf-8"):
        pass
    return client_warnings(out_dir, client_id, f"https://{domain}")


def read_version(path):
    """The version and build number in a Flutter version.json, or None."""
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
        parts = str(data["version"]).split(".") + [str(data["build_number"])]
        return tuple(int(part) for part in parts)
    except (OSError, ValueError, KeyError, TypeError):
        return None


def may_deploy(staged, current, force):
    """Whether the staged version may replace the deployed one."""
    return force or current is None or staged >= current


def _label(version):
    return ".".join(str(part) for part in version)


def _check_newer(staged_path, current_path, force):
    staged = read_version(staged_path)
    if staged is None:
        print(f"::error::{staged_path} does not hold a version and build number")
        return 1
    current = read_version(current_path)
    if current is None:
        print(f"OK: no deployed version to compare; deploying {_label(staged)}")
        return 0
    if may_deploy(staged, current, force):
        note = " (forced)" if force and staged < current else ""
        print(f"OK: deploying {_label(staged)} over {_label(current)}{note}")
        return 0
    print(
        f"::error::The site serves {_label(current)}, newer than {_label(staged)}. "
        "Visitors' libraries are already on the newer release's schema, which "
        "an older release cannot open. Rerun with force only when both "
        "releases share a schema."
    )
    return 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    commands = parser.add_subparsers(dest="command", required=True)
    stage = commands.add_parser("stage")
    stage.add_argument("zip")
    stage.add_argument("out")
    stage.add_argument("--domain", required=True)
    stage.add_argument("--client-id", default="")
    stage.add_argument("--lock", default=check_web_bundle.DEFAULT_LOCK)
    newer = commands.add_parser("check-newer")
    newer.add_argument("staged")
    newer.add_argument("current")
    newer.add_argument("--force", action="store_true")
    args = parser.parse_args(sys.argv[1:] if argv is None else list(argv))

    if args.command == "check-newer":
        return _check_newer(args.staged, args.current, args.force)
    try:
        warnings = stage_site(args.zip, args.out, args.domain, args.client_id, args.lock)
    except StageError as exc:
        print(f"::error::{exc}")
        return 1
    for warning in warnings:
        print(f"::warning::{warning}")
    print(f"OK: staged {args.out} for https://{args.domain}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
