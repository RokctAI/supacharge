/**
 * MTN MoMo adapter.
 *
 * The MoMo "mini app" is this partner-hosted PWA rendered inside MTN's
 * React Native WebView. The bridge is plain postMessage:
 *
 *   app -> container : window.ReactNativeWebView.postMessage(JSON string)
 *   container -> app : 'message' events on window/document (data = JSON)
 *
 * Container events handled here:
 *   START_JOURNEY          delivers { msisdn, micrositeToken } - the token
 *                          is valid for ~10 minutes.
 *   AWAITING_FOR_APPROVAL / APPROVED / REJECTED
 *                          payment approval lifecycle.
 *
 * App obligations:
 *   IS_STILL_ACTIVE        heartbeat roughly every 45s while the journey
 *                          is active, or the container ends the session.
 */
(function () {
  'use strict';

  var HEARTBEAT_MS = 45 * 1000;

  var session = null;         // { msisdn, micrositeToken, startedAt }
  var heartbeatTimer = null;
  var cb = null;
  var pendingPayment = null;  // { resolve, reject } of the in-flight pay()

  function send(message) {
    window.ReactNativeWebView.postMessage(JSON.stringify(message));
  }

  function startHeartbeat() {
    stopHeartbeat();
    heartbeatTimer = setInterval(function () {
      send({ type: 'IS_STILL_ACTIVE' });
    }, HEARTBEAT_MS);
  }

  function stopHeartbeat() {
    if (heartbeatTimer) {
      clearInterval(heartbeatTimer);
      heartbeatTimer = null;
    }
  }

  function onBridgeMessage(event) {
    var msg;
    try {
      msg = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
    } catch (ignore) {
      return; // Not a bridge payload (e.g. devtools noise) - ignore.
    }
    if (!msg || !msg.type) { return; }

    switch (msg.type) {
      case 'START_JOURNEY':
        // NOTE: micrositeToken expires after ~10 minutes; long journeys
        // must be prepared for the container to re-issue it.
        session = {
          msisdn: msg.data && msg.data.msisdn,
          micrositeToken: msg.data && msg.data.micrositeToken,
          startedAt: Date.now(),
          label: 'MoMo'
        };
        startHeartbeat();
        cb.onAuth(session);
        break;

      case 'AWAITING_FOR_APPROVAL':
        // User is approving the payment on the MoMo side - nothing to do.
        break;

      case 'APPROVED':
        if (pendingPayment) {
          pendingPayment.resolve(msg.data || {});
          pendingPayment = null;
        }
        break;

      case 'REJECTED':
        if (pendingPayment) {
          var err = new Error('MoMo payment rejected');
          err.friendly = 'The payment was not approved. Nothing was charged.';
          pendingPayment.reject(err);
          pendingPayment = null;
        }
        break;

      default:
        break; // Unknown bridge event - forward-compatible ignore.
    }
  }

  var adapter = {
    name: 'momo',

    init: function (callbacks) {
      cb = callbacks;
      // Android delivers WebView messages on document, iOS on window -
      // listen on both; onBridgeMessage safely ignores non-bridge data.
      window.addEventListener('message', onBridgeMessage);
      document.addEventListener('message', onBridgeMessage);
    },

    /** Auth is container-initiated (START_JOURNEY); resolves when it lands. */
    auth: function () {
      return new Promise(function (resolve) {
        if (session) { resolve(session); return; }
        var poll = setInterval(function () {
          if (session) { clearInterval(poll); resolve(session); }
        }, 200);
      });
    },

    /**
     * Payment: the actual charge is created server-side through the
     * platform gateway (SupaMiniApi.call with a manifest-confirmed cmd,
     * passing session.micrositeToken); the container then emits the
     * approval events handled above. Resolves on APPROVED.
     */
    pay: function () {
      return new Promise(function (resolve, reject) {
        pendingPayment = { resolve: resolve, reject: reject };
      });
    },

    session: function () { return session; },
    stop: stopHeartbeat
  };

  window.SupaMiniPlatform.register(adapter);
}());
