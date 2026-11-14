#!/usr/bin/env python3
"""Snapshots: one downloaded catalogue source, parsed, kept outside git.

Each source is fetched on its own into `scripts/.site_catalogue_cache/`,
so a failed download costs one source and the merge runs with no network.
A snapshot holds the source's rows under the source's own column names;
gates and naming are applied later, by the merge, so they can change
without downloading anything again.

Every request carries one fixed client name and nothing that identifies a
person or the project.
"""

import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

CACHE_DIR = Path(__file__).resolve().parent.parent / ".site_catalogue_cache"

USER_AGENT = "dive-site-harvester/1.0"


def http_get(
    url: str, *, params: dict | None = None, timeout: int = 120
) -> bytes:
    """The body at [url]. Raises RuntimeError, naming the status, on
    anything but a 200: a refusal stops the fetch, it is never worked
    around."""
    if params:
        url = url + "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            status = getattr(response, "status", 200)
            if status != 200:
                raise RuntimeError(f"{url} answered {status}")
            return response.read()
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"{url} answered {error.code}") from error


def require_fields(row: dict, fields: tuple[str, ...], source: str) -> None:
    """Raises ValueError when [row] lacks a column the source's gate reads:
    a register that renamed a column must stop the harvest, not pass every
    row."""
    for field in fields:
        if field not in row:
            raise ValueError(f"{source}: missing column {field}")


def write_snapshot(
    key: str, url: str, rows: list[dict], cache: Path = CACHE_DIR
) -> Path:
    """Writes [rows] as the snapshot of source [key]. An empty answer is a
    failed download and is refused."""
    if not rows:
        raise ValueError(f"{key}: the source answered with no rows")
    cache.mkdir(parents=True, exist_ok=True)
    path = cache / f"{key}.json"
    path.write_text(
        json.dumps(
            {
                "source": key,
                "url": url,
                "fetched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "rows": rows,
            },
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    return path


def read_snapshot(key: str, cache: Path = CACHE_DIR) -> dict:
    """The snapshot of source [key]. Raises FileNotFoundError naming it."""
    path = cache / f"{key}.json"
    if not path.exists():
        raise FileNotFoundError(
            f"No snapshot for {key} in {cache}. Run its fetch first."
        )
    return json.loads(path.read_text(encoding="utf-8"))
