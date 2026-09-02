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
 * Telegram Mini App adapter - STUB / EXPERIMENTAL.
 *
 * Status: scaffolding only. Auth wiring is sketched; the payment path is
 * intentionally NOT implemented (marked below) because Telegram's rails
 * (bot invoices / Telegram Stars) differ fundamentally from the MoMo and
 * VodaPay wallet bridges. Do not ship this adapter without finishing and
 * testing both paths.
 *
 * How Telegram Mini Apps work here:
 * - The app is registered with BotFather as a web_app URL.
 * - Telegram loads the page with launch params in the URL fragment and
 *   expects the page to include telegram-web-app.js, which exposes
 *   window.Telegram.WebApp.
 * - WebApp.initData is a signed query string; it MUST be sent to the
 *   backend for HMAC validation (secret derived from the bot token) via a
 *   platform-gateway cmd before trusting any user identity in it.
 */
(function () {
  'use strict';

  var TELEGRAM_SDK = 'https://telegram.org/js/telegram-web-app.js';

  var session = null;
  var cb = null;

  function onSdkReady() {
    var webApp = window.Telegram && window.Telegram.WebApp;
    if (!webApp || !webApp.initData) {
      cb.onError('telegram-init', new Error('Telegram.WebApp unavailable after SDK load'));
      return;
    }
    webApp.ready();

    // initData is only a CLAIM until the backend HMAC-validates it.
    // Once the validation cmd is confirmed against the manifest:
    // SupaMiniApi.call(<validate cmd>, { init_data: webApp.initData })
    session = { initData: webApp.initData, label: 'Telegram (unverified)' };
    cb.onAuth(session);
  }

  var adapter = {
    name: 'telegram',

    init: function (callbacks) {
      cb = callbacks;
      var s = document.createElement('script');
      s.src = TELEGRAM_SDK;
      s.onload = onSdkReady;
      s.onerror = function () {
        cb.onError('telegram-sdk', new Error('failed to load telegram-web-app.js'));
      };
      document.head.appendChild(s);
    },

    auth: function () {
      return session
        ? Promise.resolve(session)
        : Promise.reject(new Error('telegram session not established'));
    },

    /**
     * TODO: Telegram payments are NOT implemented. They run over bot
     * invoices (sendInvoice / WebApp.openInvoice) and Telegram Stars for
     * digital goods - a different model from the MoMo/VodaPay wallet
     * bridges - and need their own gateway cmds and server-side webhook
     * handling before this can be designed.
     */
    pay: function () {
      var err = new Error('telegram payments not implemented (stub adapter)');
      err.friendly = 'Payments are not available in Telegram yet.';
      return Promise.reject(err);
    },

    session: function () { return session; }
  };

  window.SupaMiniPlatform.register(adapter);
}());
