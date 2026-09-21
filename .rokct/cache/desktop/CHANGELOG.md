## 1.2.2

* Flag, not fix: the `app_type.pos` block (macOS/Linux runners) now carries a
  `_comment_pos_profile_retired` note. The `pos` composer profile is being
  retired in favour of `manager`, which leaves this the only `app_type.pos`
  block in any SDK manifest, but the owner has not ruled on re-keying it and
  the two templates are still hardcoded to `admin_desktop`, so the block is
  kept as-is and inert rather than renamed or deleted (2026-09-02 fix wave,
  item H2).
* Align `pubspec.yaml` with the manifest version (it had been left at 1.1.0
  while the manifest advanced to 1.2.1).

## 1.2.1 and earlier

* Predate this changelog; see the git history of `desktop/dart/manifest.json`.
