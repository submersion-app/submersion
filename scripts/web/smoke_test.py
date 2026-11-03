#!/usr/bin/env python3
"""Three-browser smoke of the built web bundle against an S3 store.

For each of Chromium, Firefox and WebKit: open the bundle with semantics on
(`?a11y=1`), connect to the S3 store the environment names, let the first
sync pull the seeded library, reach the dive list with its seeded dives,
edit one dive, sync, and check in the bucket that this browser published
its own changes. Then, from a fresh first run each time, open the sample logbook
the bundle ships, and restore that same database as a backup file, which is
older than the app's schema and so runs the upgrade ladder in the browser.
Every page asks for English, except one first run whose browser reports a
language that is not a language tag, as Linux does under LANG=C.UTF-8.
A browser that never renders fails on the wait for the semantics tree
rather than passing on nothing.

Environment: SMOKE_BASE_URL (default http://127.0.0.1:8080), SMOKE_BUNDLE_DIR
(default build/web), MINIO_ENDPOINT, MINIO_BUCKET, MINIO_ACCESS_KEY,
MINIO_SECRET_KEY. Run with
`python -m pytest scripts/web/smoke_test.py -v`, after
`python -m playwright install --with-deps chromium firefox webkit`.
"""

import gzip
import os
import re
import sqlite3
import time

import boto3
import pytest
from botocore.config import Config
from playwright.sync_api import TimeoutError as PlaywrightTimeout
from playwright.sync_api import sync_playwright

BASE_URL = os.environ.get("SMOKE_BASE_URL", "http://127.0.0.1:8080")
# The store settings are read when a test needs the store, so the first-run
# test runs against a bare bundle; the round trip fails, never skips, if
# one is missing.
ENDPOINT = os.environ.get("MINIO_ENDPOINT")
BUCKET = os.environ.get("MINIO_BUCKET")
ACCESS_KEY = os.environ.get("MINIO_ACCESS_KEY")
SECRET_KEY = os.environ.get("MINIO_SECRET_KEY")

# The sync log layout (lib/core/services/sync/changeset_log): every object
# under the prefix starts with ssv1.<device id>. and a changeset carries .cs.
SYNC_PREFIX = "submersion-sync/"
SEED_DEVICE = "seed-device"
OBJECT = re.compile(r"^ssv1\.(?P<device>[^.]+)\.")

RENDER_TIMEOUT_MS = 60_000
STEP_TIMEOUT_MS = 30_000
# The seed files three of its five dives under the diver the app opens on.
SEEDED_DIVES = 3
SEED_SITE = "Seed Reef"

_REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BUNDLE_DIR = os.environ.get("SMOKE_BUNDLE_DIR", os.path.join(_REPO, "build", "web"))
SAMPLE_TIMEOUT_MS = 120_000
# The tests find controls by their English names, so the page asks for
# English rather than whatever the runner's LANG gives the browser.
TEST_LOCALE = "en-US"
# What Chromium and Firefox report on Linux when LANG is C.UTF-8, as on
# GitHub's runners: not a language tag, which Flutter's engine cannot parse.
UNPARSEABLE_LOCALE = "C"

# The wizard's later steps (backups, photos, finish) each move on with one of
# these; Not now and Skip are left out on purpose, since they skip steps
# that matter (the sync step's Not now would skip the download).
STEP_ACTIONS = ["Next", "Get started", "Done", "Finish"]
# The actions that leave the wizard for the app.
FINISH_ACTIONS = ("Get started", "Done", "Finish")
# A first run with no store moves off the connect step with Not now.
FRESH_ACTIONS = STEP_ACTIONS + ["Not now"]


def s3():
    missing = [
        name
        for name, value in (
            ("MINIO_ENDPOINT", ENDPOINT),
            ("MINIO_BUCKET", BUCKET),
            ("MINIO_ACCESS_KEY", ACCESS_KEY),
            ("MINIO_SECRET_KEY", SECRET_KEY),
        )
        if not value
    ]
    assert not missing, "the store needs %s" % ", ".join(missing)
    return boto3.client(
        "s3",
        endpoint_url=ENDPOINT,
        aws_access_key_id=ACCESS_KEY,
        aws_secret_access_key=SECRET_KEY,
        region_name="us-east-1",
        config=Config(s3={"addressing_style": "path"}),
    )


def browser_objects():
    """Keys under the sync prefix published by a device other than the seed."""
    client = s3()
    keys = []
    paginator = client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=BUCKET, Prefix=SYNC_PREFIX):
        for entry in page.get("Contents", []):
            name = entry["Key"][len(SYNC_PREFIX) :]
            match = OBJECT.match(name)
            if match and match.group("device") != SEED_DEVICE:
                keys.append(entry["Key"])
    return keys


def delete_browser_objects():
    client = s3()
    keys = browser_objects()
    for start in range(0, len(keys), 1000):
        chunk = keys[start : start + 1000]
        client.delete_objects(
            Bucket=BUCKET,
            Delete={"Objects": [{"Key": key} for key in chunk]},
        )


def wait_for_browser_object(marker, timeout_s=90, besides=frozenset()):
    """Keys of the browser's objects whose name holds [marker], or any of
    them when it is a tuple, leaving out [besides]."""
    markers = (marker,) if isinstance(marker, str) else marker
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        published = [
            key
            for key in browser_objects()
            if key not in besides and any(m in key for m in markers)
        ]
        if published:
            return published
        time.sleep(3)
    raise AssertionError(
        "no %s object from a browser device appeared under %s/%s within %ss"
        % (marker, BUCKET, SYNC_PREFIX, timeout_s)
    )


def exact(text):
    """A whole-name match: Flutter composes a tile's name from its texts."""
    return re.compile(r"^%s$" % re.escape(text))


def button(page, name):
    return page.get_by_role("button", name=name).first


def by_text(page, text):
    """A node that reads exactly [text], or a tile whose name starts with it."""
    return page.get_by_text(exact(text)).or_(
        page.get_by_role("button", name=re.compile(r"^%s\b" % re.escape(text)))
    ).first


def click_text(page, text, timeout=STEP_TIMEOUT_MS):
    by_text(page, text).click(timeout=timeout)


def fill_field(page, label, value):
    """Material merges the label into the field's node, so the textbox is
    found by its label. Typed keys, never `fill`: Flutter's text field is
    a DOM input only while it holds focus, and a value set on it directly
    was dropped for every other field of the connect form."""
    field = page.get_by_role("textbox", name=re.compile(re.escape(label))).first
    field.click(timeout=STEP_TIMEOUT_MS)
    page.wait_for_timeout(300)
    field.press_sequentially(value)
    page.wait_for_timeout(300)


def wait_for_flutter(page):
    """The semantics tree is the sign that Flutter rendered."""
    page.goto(BASE_URL + "/?a11y=1", wait_until="load")
    page.locator("flt-semantics-host, [role=application]").first.wait_for(
        state="attached", timeout=RENDER_TIMEOUT_MS
    )
    page.locator("flt-semantics").first.wait_for(
        state="attached", timeout=RENDER_TIMEOUT_MS
    )



def continue_without_store(page):
    """The connect step's offer on a browser's first run."""
    button(page, exact("Continue without a sync store")).click(
        timeout=STEP_TIMEOUT_MS
    )


def finish_first_run(page, max_steps=12):
    """Clicks through the remaining steps and waits for the dashboard once
    the last one is taken."""
    dashboard = re.compile(r"#/dashboard")
    for _ in range(max_steps):
        for action in FRESH_ACTIONS:
            candidate = button(page, exact(action))
            if (
                candidate.count()
                and candidate.is_visible()
                and candidate.is_enabled()
            ):
                candidate.click()
                if action in FINISH_ACTIONS:
                    page.wait_for_url(dashboard, timeout=STEP_TIMEOUT_MS)
                    return
                page.wait_for_timeout(1500)
                break
        else:
            page.wait_for_timeout(1500)
    raise AssertionError("the wizard never reached its last step")


def connect_to_store(page):
    click_text(page, "My own server")
    fill_field(page, "Endpoint URL", ENDPOINT)
    fill_field(page, "Bucket", BUCKET)
    fill_field(page, "Access Key ID", ACCESS_KEY)
    fill_field(page, "Secret Access Key", SECRET_KEY)
    button(page, exact("Check connection")).click()
    page.wait_for_timeout(3000)
    button(page, exact("Save")).click()
    page.wait_for_timeout(500)


def download_library(page):
    """The sync step offers the seeded library; an empty browser downloads
    it, which runs the first sync."""
    button(page, exact("Download library")).click(timeout=STEP_TIMEOUT_MS)


def open_dive_list(page):
    button(page, exact("Get started")).click(timeout=STEP_TIMEOUT_MS)
    page.wait_for_url(re.compile(r"#/dashboard"), timeout=STEP_TIMEOUT_MS)
    page.goto(BASE_URL + "/?a11y=1#/dives", wait_until="load")
    rows = page.get_by_text(re.compile(SEED_SITE)).or_(
        page.get_by_role("button", name=re.compile(SEED_SITE))
    )
    deadline = time.monotonic() + STEP_TIMEOUT_MS / 1000
    while rows.count() < SEEDED_DIVES and time.monotonic() < deadline:
        page.wait_for_timeout(1000)
    assert rows.count() >= SEEDED_DIVES, (
        "expected %d seeded dives, saw %d rows naming %s"
        % (SEEDED_DIVES, rows.count(), SEED_SITE)
    )
    return rows


def edit_first_dive(page, rows):
    """A saved edit, through a switch: a text row collapses again when it is
    tapped through the semantics layer, as the page's only pointer here."""
    rows.first.click()
    button(page, re.compile(r"^Edit\b", re.I)).click(timeout=STEP_TIMEOUT_MS)
    page.get_by_role("switch", name=re.compile(r"^Planned dive")).first.click(
        timeout=STEP_TIMEOUT_MS
    )
    page.wait_for_timeout(500)
    button(page, exact("Save")).click()
    page.wait_for_timeout(2000)


def sync_now(page):
    """The app routes by URL fragment, so the query stays ahead of the
    hash. Only the hash changes here, so this navigates without a reload."""
    page.goto(BASE_URL + "/?a11y=1#/settings/cloud-sync", wait_until="load")
    button(page, exact("Sync Now")).click(timeout=STEP_TIMEOUT_MS)


def sample_database(folder):
    """The bundle's sample logbook as a plain database file in [folder], and
    the site of its newest dive, which the dive list must show."""
    with gzip.open(os.path.join(BUNDLE_DIR, "demo", "submersion_demo.db.gz")) as src:
        data = src.read()
    path = os.path.join(folder, "submersion-sample-backup.db")
    with open(path, "wb") as out:
        out.write(data)
    db = sqlite3.connect(path)
    try:
        (site,) = db.execute(
            "SELECT s.name FROM dives d JOIN dive_sites s ON s.id = d.site_id "
            "ORDER BY d.dive_date_time DESC LIMIT 1"
        ).fetchone()
    finally:
        db.close()
    return path, site


def continue_past_safety_review(page):
    """A restore reviews every dive before it hands off, which takes minutes
    for the sample logbook on a two-core runner. Skipping it loses nothing
    (a dive is reviewed when it is opened), so Skip is taken whenever it
    shows; the restore is done once Continue appears."""
    proceed = button(page, exact("Continue"))
    skip = button(page, exact("Skip"))
    deadline = time.monotonic() + SAMPLE_TIMEOUT_MS / 1000
    while time.monotonic() < deadline:
        if proceed.count() and proceed.is_visible():
            proceed.click()
            return
        if skip.count() and skip.is_visible():
            try:
                skip.click(timeout=2000)
            except PlaywrightTimeout:
                pass  # the review finished between the check and the click
        page.wait_for_timeout(1000)
    raise AssertionError("the restore never offered Continue")


def wait_for_dives_at(page, site):
    """The dive list shows a dive at [site]: the library opened."""
    page.goto(BASE_URL + "/?a11y=1#/dives", wait_until="load")
    by_text(page, site).or_(
        page.get_by_role("button", name=re.compile(re.escape(site)))
    ).first.wait_for(timeout=SAMPLE_TIMEOUT_MS)


def report_failure(page, request, heard):
    """What a failed run saw: printed, since a browser in a runner cannot be
    watched, with a screenshot under SMOKE_ARTIFACT_DIR when that is set."""
    print("\n--- what the page reported (%s) ---" % request.node.name)
    print("url: %s" % page.url)
    print("\n".join(heard[-40:]) or "(nothing)")
    folder = os.environ.get("SMOKE_ARTIFACT_DIR")
    if folder:
        os.makedirs(folder, exist_ok=True)
        name = re.sub(r"[^a-z0-9]+", "-", request.node.name.lower())
        page.screenshot(path=os.path.join(folder, name + ".png"))


def open_page(request, locale):
    with sync_playwright() as playwright:
        browser = getattr(playwright, request.param).launch()
        context = browser.new_context(
            viewport={"width": 1280, "height": 900}, locale=locale
        )
        page = context.new_page()
        page.set_default_timeout(STEP_TIMEOUT_MS)
        heard = []
        page.on("console", lambda m: heard.append("%s: %s" % (m.type, m.text)))
        page.on("pageerror", lambda e: heard.append("pageerror: %s" % e))
        page.on(
            "requestfailed",
            lambda r: heard.append("failed: %s %s" % (r.url, r.failure)),
        )
        try:
            yield page
            if getattr(request.node, "call_failed", False):
                report_failure(page, request, heard)
        finally:
            context.close()
            browser.close()


@pytest.fixture(params=["chromium", "firefox", "webkit"])
def page(request):
    yield from open_page(request, TEST_LOCALE)


@pytest.fixture(params=["chromium", "firefox", "webkit"])
def unparseable_locale_page(request):
    yield from open_page(request, UNPARSEABLE_LOCALE)


@pytest.fixture
def clean_store():
    """A bucket holding only the seed before the test, and again after it
    so the next browser starts from the same place."""
    delete_browser_objects()
    yield
    delete_browser_objects()


def test_fresh_first_run(page):
    """No store: the offer on the connect step, a name, the remaining steps,
    then the first write (the diver) landing on the dashboard. drift 2.34.3
    hung that commit on the locked OPFS mode, which is what an isolated page
    gets in Chromium (drift issue #3870)."""
    wait_for_flutter(page)
    continue_without_store(page)
    fill_field(page, "Your Name", "Smoke Diver")
    finish_first_run(page)


def test_unparseable_browser_locale(unparseable_locale_page):
    """A browser whose language list holds something that is not a language
    tag still starts, in English: the engine threw on it before the first
    frame, a blank page in Chromium and Firefox."""
    page = unparseable_locale_page
    wait_for_flutter(page)
    button(page, exact("Continue without a sync store")).wait_for(
        timeout=STEP_TIMEOUT_MS
    )


def test_round_trip(page, clean_store):
    wait_for_flutter(page)
    connect_to_store(page)
    download_library(page)
    rows = open_dive_list(page)
    # The browser's first publish is a base. Waiting for it means the edit
    # below has to travel in something new: a changeset, or a fresh base
    # where compaction judges the library small enough to rewrite.
    wait_for_browser_object(".manifest.")
    first_publish = frozenset(browser_objects())
    edit_first_dive(page, rows)
    sync_now(page)
    published = wait_for_browser_object(
        (".cs.", ".base."), besides=first_publish
    )
    assert published, "the browser published nothing"


def test_sample_logbook(page, tmp_path):
    """The connect step offers the sample logbook the bundle ships; it opens
    on the dashboard with its newest dive, and its dives are in the list."""
    _, site = sample_database(str(tmp_path))
    wait_for_flutter(page)
    button(page, exact("Explore with sample data")).click()
    button(page, exact("Download")).click()
    # The dashboard's recent dives, newest first: the sample logbook is the
    # open one. (The demo strip is not in a browser's semantics tree.)
    page.get_by_role(
        "button", name=re.compile(r"^Dive \d+ at %s\b" % re.escape(site))
    ).first.wait_for(timeout=SAMPLE_TIMEOUT_MS)
    wait_for_dives_at(page, site)


def test_restore_backup(page, tmp_path):
    """The connect step restores a backup file the picker reads; the bundle's
    sample database stands in for one, a few schema versions old."""
    path, site = sample_database(str(tmp_path))
    wait_for_flutter(page)
    with page.expect_file_chooser() as chooser:
        button(page, exact("Restore a backup file")).click()
    chooser.value.set_files(path)
    button(page, exact("Restore")).click()
    continue_past_safety_review(page)
    wait_for_dives_at(page, site)
