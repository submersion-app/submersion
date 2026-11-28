#!/usr/bin/env python3
"""Takes an equipment catalogue release into the app.

    python3.14 scripts/equipment_catalogue_intake.py RELEASE_DIR --tag TAG
        [--notes PATH] [--body PATH] [--allow-older]

The built-in equipment catalogue is built and released by
https://github.com/submersion-app/equipment-catalogue (issue #5118). A
release's asset is downloaded into RELEASE_DIR (the workflow uses
`gh release download`), and this copies it to assets/data/ and records the
release tag beside it. The app's tests then read the new file in the PR.
"""

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ASSET = "equipment-catalogue.json"
CATALOGUE = "assets/data/equipment_catalogue.json"
VERSION = "assets/data/equipment_catalogue.version"
_TAG = re.compile(r"^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?$")


def _generated_at(path: Path) -> str | None:
    """A catalogue file's build stamp (ISO UTC, so it orders as text)."""
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text("utf-8")).get("generatedAt")
    except json.JSONDecodeError as error:
        raise ValueError(f"{path} is not a catalogue: {error}") from error


def take(release_dir: Path, tag: str, repo: Path = REPO, *, allow_older: bool = False) -> list[str]:
    """Copies the release's catalogue into [repo] and writes its tag; returns
    the repository paths written. Raises ValueError, changing nothing, when
    the tag is not a release tag, the asset is missing, or the release was
    built before the shipped catalogue unless [allow_older] says the
    rollback is meant."""
    if not _TAG.match(tag):
        raise ValueError(f"not a catalogue release tag: {tag!r}")
    source = release_dir / ASSET
    if not source.is_file():
        raise ValueError(f"the release is missing {ASSET}")
    shipped = _generated_at(repo / CATALOGUE)
    built = _generated_at(source)
    if not allow_older and shipped and (not built or built < shipped):
        raise ValueError(
            f"the release (built {built}) is older than the shipped catalogue "
            f"(built {shipped}); take it with --allow-older only to roll back on purpose"
        )
    (repo / CATALOGUE).parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, repo / CATALOGUE)
    (repo / VERSION).write_text(f"{tag}\n", encoding="utf-8")
    return [CATALOGUE, VERSION]


def pr_body(tag: str, notes: str) -> str:
    """The intake PR's description."""
    return "\n".join([
        f"Takes equipment catalogue release [{tag}]"
        f"(https://github.com/submersion-app/equipment-catalogue/releases/tag/{tag}) "
        "into the app.",
        "",
        notes.rstrip(),
        "",
        "This PR changes catalogue data only; no screen changes.",
        "",
        "CI does not start on a PR opened by a workflow: close and reopen this "
        "PR to run it.",
        "",
        "Refs #5118",
        "",
    ])


def main(argv=None, *, repo: Path = REPO) -> int:
    """The command line; [repo] stands in for this repository in tests."""
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("release_dir", type=Path)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--notes", type=Path, default=None)
    parser.add_argument("--body", type=Path, default=None)
    parser.add_argument("--allow-older", action="store_true",
                        help="take a release built before the shipped catalogue (a rollback)")
    arguments = parser.parse_args(argv)
    try:
        for path in take(arguments.release_dir, arguments.tag, repo,
                         allow_older=arguments.allow_older):
            print(path)
    except ValueError as error:
        print(error)
        return 1
    if arguments.body:
        notes = arguments.notes.read_text("utf-8") if arguments.notes else ""
        arguments.body.write_text(pr_body(arguments.tag, notes), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
