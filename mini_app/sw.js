/**
 * Minimal service worker: network-first for everything, with a small
 * same-origin fallback cache so a brief connection blip inside a wallet
 * WebView does not blank the shell. Deliberately NO aggressive caching -
 * containers (MoMo/VodaPay) manage their own WebView lifecycles and stale
 * shells are worse than a reload.
 */
'use strict';

var CACHE = 'supacharge-mini-v1';

self.addEventListener('install', function (event) {
  self.skipWaiting();
  event.waitUntil(Promise.resolve());
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.filter(function (k) {
        return k !== CACHE;
      }).map(function (k) {
        return caches.delete(k);
      }));
    }).then(function () {
      return self.clients.claim();
    })
  );
});

self.addEventListener('fetch', function (event) {
  var req = event.request;
  // Only same-origin GETs are eligible for the fallback cache; API calls
  // (POSTs to the platform gateway) always hit the network.
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) {
    return;
  }
  event.respondWith(
    fetch(req).then(function (res) {
      if (res && res.ok) {
        var copy = res.clone();
        caches.open(CACHE).then(function (c) { c.put(req, copy); });
      }
      return res;
    }).catch(function () {
      return caches.match(req).then(function (hit) {
        return hit || Response.error();
      });
    })
  );
});
