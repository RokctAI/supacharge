# Changelog

## 1.0.2

- `lesson_progress_table` is owner-scoped. It gains an `owner` column
  (NOT NULL, defaulting to the empty string) which joins the primary key
  alongside `session_id`, so two accounts on one device no longer resume
  each other's lessons - each keeps its own position in the same session
  instead of one overwriting the other. Reads filter with base_sdk's
  `ownerVisible(owner, me)`; writes stamp `OwnerScope.instance.current`.
- Scoping is a VISIBILITY rule, never a deletion: signing out writes
  nothing and removes nothing.
- Migration version 23 (shared fleetwide namespace, declared in
  `manifest.json`). The step rebuilds the table the long way round -
  rename aside, recreate, copy the shared columns, drop - because SQLite
  cannot alter a primary key in place. Carried rows take the `''` default
  and stay visible to everyone. `ensureReplayOwnerScopeColumns` is
  idempotent and self-checking.
- `downloaded_assets_table` is deliberately NOT scoped: it indexes files
  on the device's own disk. The files are shared, so the index of them has
  to be - scoping it would re-download bytes already present and leave the
  first account's files unreferenced and never purged.
- Version aligned with `manifest.json`, which had run ahead at 1.0.1.
- Requires base_sdk 1.67.0 (`OwnerScope`, `kUnownedOwner`, `ownerVisible`).

## 1.0.0

- Initial release of ReplaySDK.
