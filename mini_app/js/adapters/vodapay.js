// Copyright (c) 2026 RokctAI
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

/**
 * VodaPay adapter.
 *
 * VodaPay mini programs run on Vodacom's rebadged Alipay/mPaaS stack.
 * This app registers as the "PWA (HTML5)" mini-program type - plain web
 * content registered by Entrance URL, no aXML/aCSS rewrite, no IDE - and
 * talks to the container through the injected `my.*` JSAPI bridge:
 *
 *   my.getAuthCode  login: returns an authCode the BACKEND exchanges for
 *                   the user identity (server-to-server via the platform
 *                   gateway; the code itself is useless client-side).
 *   my.tradePay     payment: opens the native cashier for an order the
 *                   backend created through the gateway.
 *
 * This script is only loaded when platform.js has already detected the
 * mPaaS bridge, so `my` is assumed present.
 */
(function () {
  'use strict';

  var session = null; // { authCode, label }
  var cb = null;

  var adapter = {
    name: 'vodapay',

    init: function (callbacks) {
      cb = callbacks;
      // VodaPay requires the Login integration up front: fetch the auth
      // code immediately so the backend can establish the session.
      adapter.auth().then(function (s) {
        cb.onAuth(s);
      }).catch(function (err) {
        cb.onError('vodapay-auth', err);
      });
    },

    auth: function () {
      return new Promise(function (resolve, reject) {
        my.getAuthCode({
          scopes: ['auth_base'],
          success: function (res) {
            session = { authCode: res.authCode, label: 'VodaPay' };
            // Next step (once the cmd is confirmed against the manifest):
            // SupaMiniApi.call(<login cmd>, { auth_code: res.authCode })
            // so the backend can exchange the code for the user identity.
            resolve(session);
          },
          fail: function (res) {
            var err = new Error('my.getAuthCode failed: ' + JSON.stringify(res));
            err.friendly = 'We could not sign you in with VodaPay. ' +
              'Please close and reopen the mini app.';
            reject(err);
          }
        });
      });
    },

    /**
     * Payment: the backend creates the order through the platform gateway
     * and returns the cashier parameter; my.tradePay opens the native
     * cashier. resultCode 9000 means the payment succeeded.
     */
    pay: function (order) {
      return new Promise(function (resolve, reject) {
        my.tradePay({
          // Field name per mPaaS cashier docs; the value comes from the
          // gateway order-creation response (cmd to be confirmed against
          // the manifest before wiring).
          tradeNO: order && order.tradeNo,
          success: function (res) {
            if (res && String(res.resultCode) === '9000') {
              resolve(res);
            } else {
              var err = new Error('my.tradePay resultCode ' +
                (res && res.resultCode));
              err.friendly = 'The payment did not complete. ' +
                'You have not been charged.';
              reject(err);
            }
          },
          fail: function (res) {
            var err = new Error('my.tradePay failed: ' + JSON.stringify(res));
            err.friendly = 'The payment did not complete. ' +
              'You have not been charged.';
            reject(err);
          }
        });
      });
    },

    session: function () { return session; }
  };

  window.SupaMiniPlatform.register(adapter);
}());
