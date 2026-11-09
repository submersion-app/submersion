// The media stream worker (issue #4162).
//
// A browser's video element fetches its file itself and cannot send the
// headers Google Drive and WebDAV need, so the app points the player at a
// same-site `media-stream/<ticket>` address under the page's base. This
// worker catches those requests and relays each one, with its Range header,
// to the page that made it. The page reads that byte range through the store
// it is already signed in to and answers; the worker builds the response.
//
// It holds no state and no credentials, so the browser stopping it while
// idle loses nothing. It caches nothing, and every other request goes to
// the network untouched, so a replaced deployment is never served stale.

'use strict';

// How long a page has to answer one relayed request.
const REPLY_TIMEOUT_MS = 30000;

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  // Controls the page that registered it at once, without a reload.
  event.waitUntil(self.clients.claim());
});

function streamPrefix() {
  return new URL(self.registration.scope).pathname + 'media-stream/';
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  const prefix = streamPrefix();
  if (!url.pathname.startsWith(prefix)) return;
  const ticket = decodeURIComponent(url.pathname.slice(prefix.length));
  event.respondWith(relay(event, ticket, request.headers.get('Range')));
});

// Asks [client] for one piece of [ticket]; null when it does not answer.
function ask(client, ticket, range) {
  const channel = new MessageChannel();
  const reply = new Promise((resolve) => {
    const timer = setTimeout(() => resolve(null), REPLY_TIMEOUT_MS);
    channel.port1.onmessage = (message) => {
      clearTimeout(timer);
      resolve(message.data);
    };
  });
  client.postMessage(
    {type: 'media-stream-request', ticket: ticket, range: range},
    [channel.port2],
  );
  return reply.finally(() => channel.port1.close());
}

// `bytes <start>-<end>/<total>` as numbers, or null.
function parseContentRange(value) {
  const match = /^bytes (\d+)-(\d+)\/(\d+)$/.exec(value || '');
  return match ? {start: Number(match[1]), end: Number(match[2]), total: Number(match[3])} : null;
}

// The end the browser asked for, or null for an open range or no Range.
function askedEnd(range) {
  const match = /^bytes=\d+-(\d+)$/.exec(range || '');
  return match ? Number(match[1]) : null;
}

function header(headers, name) {
  const wanted = name.toLowerCase();
  for (const key of Object.keys(headers || {})) {
    if (key.toLowerCase() === wanted) return headers[key];
  }
  return null;
}

// The page answers at most one chunk per request. A browser that asked for
// more is answered with the whole range it asked for, as one streamed body
// the worker fills by asking the page for each following chunk: WebKit
// takes a shorter 206 as the end of the file and never asks again.
async function relay(event, ticket, range) {
  const client = await self.clients.get(event.clientId);
  if (!client) {
    return new Response(null, {status: 503, statusText: 'No page to answer'});
  }
  const first = await ask(client, ticket, range);
  if (!first) {
    return new Response(null, {status: 504, statusText: 'The page did not answer'});
  }
  const piece = first.status === 206 ? parseContentRange(header(first.headers, 'Content-Range')) : null;
  if (!piece) {
    return new Response(first.body, {status: first.status, headers: first.headers || {}});
  }
  const asked = askedEnd(range);
  const end = Math.min(asked === null ? piece.total - 1 : asked, piece.total - 1);
  const headers = Object.assign({}, first.headers);
  for (const key of Object.keys(headers)) {
    const lower = key.toLowerCase();
    if (lower === 'content-range' || lower === 'content-length') delete headers[key];
  }
  headers['Content-Range'] = 'bytes ' + piece.start + '-' + end + '/' + piece.total;
  headers['Content-Length'] = String(end - piece.start + 1);

  let next = piece.end + 1;
  let firstBody = first.body;
  const body = new ReadableStream({
    async pull(controller) {
      if (firstBody) {
        controller.enqueue(new Uint8Array(firstBody));
        firstBody = null;
        if (next > end) controller.close();
        return;
      }
      const more = await ask(client, ticket, 'bytes=' + next + '-' + end);
      const got = more && more.status === 206 ? parseContentRange(header(more.headers, 'Content-Range')) : null;
      if (!got || got.start !== next || !more.body) {
        controller.error(new Error('The page stopped answering the stream'));
        return;
      }
      controller.enqueue(new Uint8Array(more.body));
      next = got.end + 1;
      if (next > end) controller.close();
    },
  });
  return new Response(body, {status: 206, headers: headers});
}
