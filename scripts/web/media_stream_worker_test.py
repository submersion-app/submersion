"""The media stream worker (web/media_stream_worker.js) in three browsers.

The worker relays a page's `media-stream/<ticket>` requests back to the
page that made them, which answers from its store (issue #4162). Here a
fixture page (scripts/web/fixtures/media_stream/index.html) stands in for
the app's side and answers from a small WebM file in 16 KiB pieces, so each
browser has to play, and seek, from many short 206 responses. It runs at the
site root and under a sub-path, the two ways the bundle is hosted, with the
hosting guide's isolation headers.

When MINIO_ENDPOINT is set (the web smoke job), it also plays a presigned
MinIO URL under those headers, the direct link S3 stores give the player.

Run: python3 -m pytest scripts/web/media_stream_worker_test.py -v
Environment: STREAM_BROWSERS (default chromium,firefox,webkit) and the
MINIO_* variables the smoke uses.
"""

import os
import shutil
import threading
import uuid

import pytest
from playwright.sync_api import sync_playwright

import serve_bundle

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
FIXTURE = os.path.join(HERE, "fixtures", "media_stream")
WORKER = os.path.join(REPO, "web", "media_stream_worker.js")
BROWSERS = os.environ.get("STREAM_BROWSERS", "chromium,firefox,webkit").split(",")
TIMEOUT_MS = 30000

ENDPOINT = os.environ.get("MINIO_ENDPOINT")
BUCKET = os.environ.get("MINIO_BUCKET", "submersion-test")
ACCESS_KEY = os.environ.get("MINIO_ACCESS_KEY")
SECRET_KEY = os.environ.get("MINIO_SECRET_KEY")


def _stage(folder, base):
    os.makedirs(folder, exist_ok=True)
    for name in ("sample.webm", "index.html"):
        shutil.copy(os.path.join(FIXTURE, name), folder)
    shutil.copy(WORKER, folder)
    page = os.path.join(folder, "index.html")
    with open(page, encoding="utf-8") as handle:
        html = handle.read()
    with open(page, "w", encoding="utf-8") as handle:
        handle.write(html.replace('<base href="/">', '<base href="%s">' % base))


@pytest.fixture(scope="module")
def site(tmp_path_factory):
    """The fixture at / and again under /sub/, served with the headers."""
    root = str(tmp_path_factory.mktemp("stream-site"))
    _stage(root, "/")
    _stage(os.path.join(root, "sub"), "/sub/")
    httpd = serve_bundle.make_server(root, 0)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    yield "http://127.0.0.1:%d" % httpd.server_address[1]
    httpd.shutdown()


@pytest.fixture(params=BROWSERS)
def page(request):
    with sync_playwright() as playwright:
        browser = getattr(playwright, request.param).launch()
        # A context per test: each starts with no worker registered.
        context = browser.new_context()
        page = context.new_page()
        page.set_default_timeout(TIMEOUT_MS)
        try:
            yield page
        finally:
            context.close()
            browser.close()


def _open(page, url):
    page.goto(url)
    assert page.evaluate("window.workerReady")


def test_plays_through_relay(page, site):
    _open(page, site + "/index.html")
    assert page.evaluate("playTicket('t1')") > 1
    assert page.evaluate("seekTo(3.0)") >= 2.9


def test_plays_under_sub_path(page, site):
    _open(page, site + "/sub/index.html")
    assert page.evaluate("playTicket('t1')") > 1
    assert page.evaluate("seekTo(3.0)") >= 2.9


def test_answers_the_whole_requested_range(page, site):
    # WebKit takes a 206 shorter than the range it asked for as the end of
    # the file, so the worker stitches the page's pieces into one answer.
    _open(page, site + "/index.html")
    total = os.path.getsize(os.path.join(FIXTURE, "sample.webm"))
    got = page.evaluate(
        """async () => {
          const r = await fetch('media-stream/t1', {headers: {Range: 'bytes=100-'}});
          const body = await r.arrayBuffer();
          return [r.status, r.headers.get('Content-Range'),
                  r.headers.get('Content-Length'), body.byteLength];
        }"""
    )
    assert got == [206, "bytes 100-%d/%d" % (total - 1, total), str(total - 100), total - 100]


def test_an_empty_piece_ends_the_stream(page, site):
    # A page that answers with no bytes must not keep the worker asking
    # for the same range forever.
    _open(page, site + "/index.html")
    outcome = page.evaluate(
        """async () => {
          try {
            const r = await fetch('media-stream/empty', {headers: {Range: 'bytes=0-'}});
            await Promise.race([
              r.arrayBuffer(),
              new Promise((_, reject) => setTimeout(() => reject(new Error('hung')), 10000)),
            ]);
            return 'completed';
          } catch (e) {
            return e.message === 'hung' ? 'hung' : 'failed';
          }
        }"""
    )
    assert outcome == "failed"
    assert page.evaluate("window.asks['empty']") <= 3


def test_a_page_can_ask_the_worker_to_take_control(page, site):
    # After a hard reload the page is not controlled; the app asks the
    # active worker to claim it rather than wait for a reload.
    _open(page, site + "/index.html")
    reply = page.evaluate(
        """async () => {
          const registration = await navigator.serviceWorker.ready;
          const channel = new MessageChannel();
          const answered = new Promise((resolve) => { channel.port1.onmessage = (m) => resolve(m.data); });
          registration.active.postMessage({type: 'media-stream-claim'}, [channel.port2]);
          return Promise.race([answered, new Promise((r) => setTimeout(() => r('no answer'), 5000))]);
        }"""
    )
    assert reply == "claimed"


def test_a_request_without_range_gets_the_whole_file(page, site):
    _open(page, site + "/index.html")
    total = os.path.getsize(os.path.join(FIXTURE, "sample.webm"))
    got = page.evaluate(
        """async () => {
          const r = await fetch('media-stream/t1');
          const body = await r.arrayBuffer();
          return [r.status, r.headers.get('Content-Range'),
                  r.headers.get('Content-Length'), body.byteLength];
        }"""
    )
    assert got == [200, None, str(total), total]


def test_a_piece_for_the_wrong_offset_is_refused(page, site):
    _open(page, site + "/index.html")
    status = page.evaluate(
        "fetch('media-stream/shifted', {headers: {Range: 'bytes=10-'}}).then(r => r.status)"
    )
    assert status == 502


def test_unknown_ticket_answers_404(page, site):
    _open(page, site + "/index.html")
    assert page.evaluate("fetch('media-stream/nope').then(r => r.status)") == 404


def test_other_requests_pass_through(page, site):
    _open(page, site + "/index.html")
    size = os.path.getsize(os.path.join(FIXTURE, "sample.webm"))
    fetched = page.evaluate(
        "fetch('sample.webm').then(r => r.arrayBuffer()).then(b => b.byteLength)"
    )
    assert fetched == size


@pytest.mark.skipif(not ENDPOINT, reason="MINIO_ENDPOINT is not set")
def test_presigned_minio_url_plays(page, site):
    import boto3

    s3 = boto3.client(
        "s3",
        endpoint_url=ENDPOINT,
        aws_access_key_id=ACCESS_KEY,
        aws_secret_access_key=SECRET_KEY,
        region_name="us-east-1",
    )
    key = "stream-test/%s.webm" % uuid.uuid4().hex
    s3.upload_file(
        os.path.join(FIXTURE, "sample.webm"),
        BUCKET,
        key,
        ExtraArgs={"ContentType": "video/webm"},
    )
    try:
        url = s3.generate_presigned_url(
            "get_object", Params={"Bucket": BUCKET, "Key": key}, ExpiresIn=600
        )
        _open(page, site + "/index.html")
        assert page.evaluate("(url) => playSource(url)", url) > 1
    finally:
        s3.delete_object(Bucket=BUCKET, Key=key)
