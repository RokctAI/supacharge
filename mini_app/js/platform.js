// Copyright (c) 2026 ROKCT INTELLIGENCE (PTY) LTD
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, version 3.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

/**
 * Platform detection + adapter loader.
 *
 * Each adapter file (js/adapters/*.js) registers itself by calling
 * SupaMiniPlatform.register(adapter). An adapter implements:
 *
 *   name        string   human-readable platform name
 *   init(cb)    void     wire bridge listeners; call cb.onAuth / cb.onError
 *   auth()      Promise  resolve a session (adapter-specific shape)
 *   pay(order)  Promise  run the platform payment flow
 *
 * Adapter scripts are injected on demand - only the one matching the
 * detected platform is ever loaded (the VodaPay/mPaaS adapter, for example,
 * is fetched only when the mPaaS bridge is present).
 */
(function () {
  'use strict';

  var ADAPTER_SRC = {
    momo: 'js/adapters/momo.js',
    vodapay: 'js/adapters/vodapay.js',
    telegram: 'js/adapters/telegram.js'
  };

  var current = null;
  var bootCallbacks = null;

  /**
   * Detect which container we are running inside.
   *
   * - MoMo: partner PWA inside MTN's React Native WebView, which injects
   *   window.ReactNativeWebView (postMessage bridge).
   * - VodaPay: Alipay/mPaaS container injects the `my` JSAPI object; the
   *   user agent also carries an AlipayClient marker.
   * - Telegram: Mini Apps launch with tgWebAppData in the URL fragment
   *   (window.Telegram only exists after telegram-web-app.js is loaded,
   *   so the fragment is the reliable pre-load signal).
   * - browser: plain fallback for local development.
   */
  function detect() {
    if (window.ReactNativeWebView &&
        typeof window.ReactNativeWebView.postMessage === 'function') {
      return 'momo';
    }
    if (typeof window.my !== 'undefined' ||
        /AlipayClient|mPaaS/i.test(navigator.userAgent)) {
      return 'vodapay';
    }
    if (/tgWebAppData/.test(window.location.hash)) {
      return 'telegram';
    }
    return 'browser';
  }

  function loadScript(src, onload, onerror) {
    var s = document.createElement('script');
    s.src = src;
    s.onload = onload;
    s.onerror = onerror;
    document.head.appendChild(s);
  }

  /** Called by each adapter script once it has evaluated. */
  function register(adapter) {
    current = adapter;
    adapter.init(bootCallbacks);
  }

  /** Entry point, called once from index.html. */
  function boot(callbacks) {
    bootCallbacks = callbacks;
    var platform = detect();
    callbacks.onPlatform(
      { momo: 'MTN MoMo', vodapay: 'VodaPay', telegram: 'Telegram (stub)', browser: 'Browser (no bridge)' }[platform]
    );
    if (platform === 'browser') {
      // Local development: no container bridge, nothing to initialise.
      return;
    }
    callbacks.onAuthPending();
    loadScript(ADAPTER_SRC[platform], null, function () {
      callbacks.onError('adapter-load', new Error('failed to load adapter: ' + platform));
    });
  }

  window.SupaMiniPlatform = {
    boot: boot,
    register: register,
    detect: detect,
    /** The active adapter (null until its script has registered). */
    adapter: function () { return current; }
  };
}());
