#!/usr/bin/env python3
"""Three-browser smoke of the built web bundle against an S3 store.

For each of Chromium, Firefox and WebKit: open the bundle with semantics on
(`?a11y=1`), connect to the S3 store the environment names, let the first
sync pull the seeded library, reach the dive list with its five dives, edit
one dive's notes, sync, and check in the bucket that this browser published
a changeset of its own. A browser that never renders fails on the wait for
the semantics tree rather than passing on nothing.

Environment: SMOKE_BASE_URL (default http://127.0.0.1:8080), MINIO_ENDPOINT,
MINIO_BUCKET, MINIO_ACCESS_KEY, MINIO_SECRET_KEY. Run with
`python -m pytest scripts/web/smoke_test.py -v`, after
`python -m playwright install --with-deps chromium firefox webkit`.
"""

import os
import re
import time

import boto3
import pytest
from botocore.config import Config
from playwright.sync_api import TimeoutError as PlaywrightTimeout
from playwright.sync_api import sync_playwright

BASE_URL = os.environ.get("SMOKE_BASE_URL", "http://127.0.0.1:8080")
ENDPOINT = os.environ["MINIO_ENDPOINT"]
BUCKET = os.environ["MINIO_BUCKET"]
ACCESS_KEY = os.environ["MINIO_ACCESS_KEY"]
SECRET_KEY = os.environ["MINIO_SECRET_KEY"]

# The sync log layout (lib/core/services/sync/changeset_log): every object
# under the prefix starts with ssv1.<device id>. and a changeset carries .cs.
SYNC_PREFIX = "submersion-sync/"
SEED_DEVICE = "seed-device"
OBJECT = re.compile(r"^ssv1\.(?P<device>[^.]+)\.")

RENDER_TIMEOUT_MS = 60_000
STEP_TIMEOUT_MS = 30_000
SEEDED_DIVES = 5
SEED_SITE = "Seed Reef"

# The wizard's own step actions, whichever its later steps show.
STEP_ACTIONS = ["Next", "Skip", "Not now", "Done", "Finish", "Get started"]


def s3():
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


def wait_for_browser_changeset(timeout_s=90):
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        published = [key for key in browser_objects() if ".cs." in key]
        if published:
            return published
        time.sleep(3)
    raise AssertionError(
        "no changeset from a browser device appeared under %s%s within %ss"
        % (BUCKET, SYNC_PREFIX, timeout_s)
    )


def by_text(page, text):
    """A locator for a Flutter semantics node that reads [text]."""
    pattern = re.compile(re.escape(text))
    return page.get_by_text(pattern).or_(page.get_by_label(pattern))


def click(page, text, timeout=STEP_TIMEOUT_MS):
    by_text(page, text).first.click(timeout=timeout)


def fill(page, label, value):
    field = page.get_by_label(re.compile(re.escape(label))).first
    field.click(timeout=STEP_TIMEOUT_MS)
    field.fill(value)


def wait_for_flutter(page):
    """The semantics tree is the sign that Flutter rendered."""
    page.goto(BASE_URL + "/?a11y=1", wait_until="load")
    page.locator("flt-semantics-host, [role=application]").first.wait_for(
        state="attached", timeout=RENDER_TIMEOUT_MS
    )
    page.locator("flt-semantics").first.wait_for(
        state="attached", timeout=RENDER_TIMEOUT_MS
    )


def advance_until(page, text, max_steps=12):
    """Clicks whatever wizard action is showing until [text] is on screen."""
    for _ in range(max_steps):
        if by_text(page, text).first.is_visible():
            return
        for action in STEP_ACTIONS:
            button = page.get_by_role("button", name=re.compile(r"^%s$" % re.escape(action)))
            if button.count() and button.first.is_visible():
                button.first.click()
                page.wait_for_timeout(1500)
                break
        else:
            page.wait_for_timeout(1500)
    by_text(page, text).first.wait_for(state="visible", timeout=STEP_TIMEOUT_MS)


def connect_to_store(page):
    click(page, "My own server")
    fill(page, "Endpoint URL", ENDPOINT)
    fill(page, "Bucket", BUCKET)
    fill(page, "Access Key ID", ACCESS_KEY)
    fill(page, "Secret Access Key", SECRET_KEY)
    click(page, "Check connection")
    page.wait_for_timeout(3000)
    click(page, "Save")


def open_dive_list(page):
    advance_until(page, "Dives")
    click(page, "Dives")
    rows = by_text(page, SEED_SITE)
    deadline = time.monotonic() + STEP_TIMEOUT_MS / 1000
    while rows.count() < SEEDED_DIVES and time.monotonic() < deadline:
        page.wait_for_timeout(1000)
    assert rows.count() >= SEEDED_DIVES, (
        "expected %d seeded dives, saw %d rows naming %s"
        % (SEEDED_DIVES, rows.count(), SEED_SITE)
    )
    return rows


def edit_first_dive(page, rows, note):
    rows.first.click()
    page.get_by_role("button", name=re.compile("edit", re.I)).first.click(
        timeout=STEP_TIMEOUT_MS
    )
    fill(page, "Notes", note)
    click(page, "Save")
    page.wait_for_timeout(2000)


def sync_now(page):
    for route in ("/settings/cloud-sync?a11y=1", "/#/settings/cloud-sync?a11y=1"):
        page.goto(BASE_URL + route, wait_until="load")
        try:
            click(page, "Sync Now", timeout=20_000)
            return
        except PlaywrightTimeout:
            continue
    raise AssertionError("the Cloud Sync page with its Sync Now button was not reached")


@pytest.fixture(params=["chromium", "firefox", "webkit"])
def page(request):
    with sync_playwright() as playwright:
        browser = getattr(playwright, request.param).launch()
        context = browser.new_context(viewport={"width": 1280, "height": 900})
        page = context.new_page()
        page.set_default_timeout(STEP_TIMEOUT_MS)
        try:
            yield page
        finally:
            context.close()
            browser.close()
            # The next browser starts from a bucket holding only the seed.
            delete_browser_objects()


def test_round_trip(page):
    delete_browser_objects()
    wait_for_flutter(page)
    connect_to_store(page)
    rows = open_dive_list(page)
    note = "Smoke edit from %s at %s" % (
        page.context.browser.browser_type.name,
        time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    )
    edit_first_dive(page, rows, note)
    sync_now(page)
    published = wait_for_browser_changeset()
    assert published, "the browser published nothing"
