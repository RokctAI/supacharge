/**
 * Single gateway client.
 *
 * HARD RULE (Ray): every backend call goes through the ONE platform gateway
 * endpoint below with a `cmd` field naming the manifest method. Never call
 * bare /api/method/ paths or invent per-method URLs.
 */
(function () {
  'use strict';

  var GATEWAY_URL = 'https://platform.rokct.ai/api/v1/method/rokct.platform.api';

  /**
   * PLACEHOLDER cmd names - DO NOT WIRE REAL CALLS against these.
   * Every cmd MUST be confirmed against the platform manifest before use;
   * these strings exist only so call sites have a named constant to swap.
   */
  var CMD = {
    UNCONFIRMED_PLACEHOLDER: 'CONFIRM_AGAINST_MANIFEST_BEFORE_USE'
  };

  /**
   * POST { cmd, ...payload } to the gateway. Returns the parsed JSON body.
   * Throws an Error whose `friendly` property is safe to show to users;
   * technical detail is sent to telemetry via reportError, never surfaced.
   */
  function call(cmd, payload) {
    var body = Object.assign({ cmd: cmd }, payload || {});
    return fetch(GATEWAY_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    }).then(function (res) {
      if (!res.ok) {
        var err = new Error('gateway ' + res.status + ' for cmd=' + cmd);
        err.friendly = 'We could not reach the service just now. ' +
          'Please try again in a moment.';
        throw err;
      }
      return res.json();
    });
  }

  /**
   * Telemetry hook. Admin-level detail belongs HERE, not on screen.
   * For now it logs to the console; once the telemetry cmd is confirmed
   * against the manifest, forward it through call(CMD.<telemetry>, ...).
   */
  function reportError(context, err) {
    try {
      // eslint-disable-next-line no-console
      console.error('[supacharge-mini]', context, err);
    } catch (ignore) {
      // Never let telemetry itself break the app.
    }
  }

  window.SupaMiniApi = { call: call, reportError: reportError, CMD: CMD };
}());
