## 1.2.0

* Saved-card payment no longer handles the gateway reuse credential.
  `get_saved_cards` and `tokenize_card` stopped returning it, so
  `processTokenPayment` names the card by its docname and sends it on
  `saved_card`, and `tokenizeCard` returns the new card's docname. The
  credential is resolved server-side. Requires the matching wallet
  backend: an older backend reads `token` and will reject the charge
  rather than charge the wrong thing.

## 1.1.1

* Baseline: first CHANGELOG entry for this SDK. Earlier versions
  predate the file.
