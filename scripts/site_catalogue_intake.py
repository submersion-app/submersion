#!/usr/bin/env python3
"""Takes a site catalogue release into the app.

    python3.14 scripts/site_catalogue_intake.py RELEASE_DIR [--tag TAG]
        [--notes PATH] [--body PATH]

The built-in dive site catalogue is built and released by
https://github.com/submersion-app/site-catalogue. A release's files are
downloaded into RELEASE_DIR (the workflow uses `gh release download`), and
this copies each one the app ships, or tests against, to its place in the
repository. A release missing any of them changes nothing. The open-only
build is not taken: the app ships the full catalogue.

The app's tests then check the release in its PR: the catalogue tests read
the new file, and the contract test fails a release whose format or
vocabularies the app cannot read.
"""

import argparse
import json
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Release file name to its place in the repository.
INTAKE_FILES = {
    "site_catalogue.json": "assets/data/site_catalogue.json",
    "site_catalogue.version": "assets/data/site_catalogue.version",
    "site_catalogue_njdep_metadata.xml": "assets/data/site_catalogue_njdep_metadata.xml",
    "site_catalogue_md_dnr_metadata.xml": "assets/data/site_catalogue_md_dnr_metadata.xml",
    "format.json": "test/features/dive_sites/data/catalogue/contract/format.json",
    "countries.json": "test/features/dive_sites/data/catalogue/contract/countries.json",
}


def _generated_at(path: Path) -> str | None:
    """A catalogue file's build stamp (ISO UTC, so it orders as text)."""
    if not path.is_file():
        return None
    try:
        doc = json.loads(path.read_text("utf-8"))
    except json.JSONDecodeError as error:
        raise ValueError(f"{path} is not a catalogue: {error}") from error
    return (doc.get("metadata") or {}).get("generated_at")


def take(release_dir: Path, repo: Path = REPO, *, allow_older: bool = False) -> list[str]:
    """Copies the release's files into [repo] and returns the repository
    paths written. Raises ValueError, changing nothing, when any is missing,
    or when the release was built before the shipped catalogue (a downgrade)
    unless [allow_older] says the rollback is meant. A release built from
    the same snapshots as the shipped one has the same stamp and is taken."""
    missing = sorted(name for name in INTAKE_FILES if not (release_dir / name).is_file())
    if missing:
        raise ValueError(f"the release is missing {', '.join(missing)}")
    shipped = _generated_at(repo / INTAKE_FILES["site_catalogue.json"])
    built = _generated_at(release_dir / "site_catalogue.json")
    if not allow_older and shipped and (not built or built < shipped):
        raise ValueError(
            f"the release (built {built}) is older than the shipped catalogue "
            f"(built {shipped}); take it with --allow-older only to roll back on purpose"
        )
    for name, relative in INTAKE_FILES.items():
        target = repo / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(release_dir / name, target)
    return list(INTAKE_FILES.values())


def pr_body(tag: str, notes: str) -> str:
    """The intake PR's description."""
    return "\n".join([
        f"Takes site catalogue release [{tag}]"
        f"(https://github.com/submersion-app/site-catalogue/releases/tag/{tag}) "
        "into the app.",
        "",
        notes.rstrip(),
        "",
        "This PR changes catalogue data only; no screen changes.",
        "",
        "CI does not start on a PR opened by a workflow: close and reopen this "
        "PR to run it.",
        "",
        "Refs #4514",
        "",
    ])


def main(argv=None, *, repo: Path = REPO) -> int:
    """The command line; [repo] stands in for this repository in tests."""
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("release_dir", type=Path)
    parser.add_argument("--tag", default="")
    parser.add_argument("--notes", type=Path, default=None)
    parser.add_argument("--body", type=Path, default=None)
    parser.add_argument("--allow-older", action="store_true",
                        help="take a release built before the shipped catalogue (a rollback)")
    arguments = parser.parse_args(argv)
    try:
        for path in take(arguments.release_dir, repo, allow_older=arguments.allow_older):
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
